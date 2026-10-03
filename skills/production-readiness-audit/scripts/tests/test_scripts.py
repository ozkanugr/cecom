"""Focused tests for catalog.py, render_report.py and detect_profile.sh.

Run from the skill directory:
    python3 -m unittest discover -s scripts/tests -v
Everything runs in temporary directories; no project files are touched.
"""

import io
import json
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SCRIPTS))

import catalog  # noqa: E402
import render_report  # noqa: E402


def quiet(fn, *args):
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        code = fn(*args)
    return code, out.getvalue(), err.getvalue()


class CatalogTests(unittest.TestCase):
    def test_real_catalog_is_valid(self):
        checks, errors = catalog.load()
        self.assertEqual(errors, [])
        self.assertGreater(len(checks), 250)
        ids = [c["id"] for c in checks]
        self.assertEqual(len(ids), len(set(ids)))

    def test_lint_reports_bad_rows(self):
        with tempfile.TemporaryDirectory() as d:
            Path(d, "x.md").write_text(
                "| ID | Check | Look at | Sev | Scope |\n|---|---|---|---|---|\n"
                "| X-001 | ok | here | P1 | all |\n"
                "| X-001 | duplicate | here | P1 | all |\n"
                "| X-002 | bad sev | here | P9 | all |\n"
                "| X-003 | bad scope | here | P2 | desktop |\n"
                "| X-004 | unescaped | a|b | P2 | all |\n"
                "| X-005 | escaped \\| pipe | `a\\|b` | P2 | api, db |\n", encoding="utf-8")
            checks, errors = catalog.load(d)
        text = "\n".join(errors)
        self.assertIn("duplicate id X-001", text)
        self.assertIn("X-002 has invalid severity", text)
        self.assertIn("X-003 has invalid scope", text)
        self.assertIn("expected 5 columns, got 6", text)
        x5 = next(c for c in checks if c["id"] == "X-005")
        self.assertEqual(x5["scope"], ["api", "db"])
        self.assertEqual(x5["look"], "`a|b`")

    def test_applies(self):
        self.assertTrue(catalog.applies(["all"], ["api"]))
        self.assertTrue(catalog.applies(["client"], ["web"]))
        self.assertFalse(catalog.applies(["client"], ["api", "db"]))
        self.assertTrue(catalog.applies(["api", "db"], ["db"]))
        self.assertFalse(catalog.applies(["mobile"], ["web"]))

    def test_plan_marks_profile_mismatches(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d, "plan.jsonl")
            code, _, err = quiet(catalog.main, ["plan", "--profile", "web", "--areas", "lifecycle", "--out", str(out)])
            self.assertEqual(code, 0)
            rows = [json.loads(line) for line in out.read_text().splitlines()]
        by_id = {r["id"]: r for r in rows}
        self.assertEqual(by_id["LIFE-002"]["status"], "NOT_APPLICABLE")  # mobile-only
        self.assertTrue(by_id["LIFE-002"]["reason"].startswith("profile"))
        self.assertEqual(by_id["LIFE-001"]["status"], "PENDING")  # client → web
        self.assertEqual(by_id["LIFE-012"]["status"], "PENDING")  # web
        self.assertTrue(all(r["area"] == "lifecycle" for r in rows))
        self.assertIn("to audit", err)

    def test_plan_rejects_unknown_tags(self):
        with self.assertRaises(SystemExit):
            quiet(catalog.main, ["plan", "--profile", "desktop"])


def finding(fid, status, **kw):
    row = {"id": fid, "status": status}
    if status == "PASS":
        row["evidence"] = [{"file": "src/a.ts", "line": 1, "note": "ok"}]
    if status == "FAIL":
        row.update(severity="P2", evidence=[{"file": "src/b.ts", "line": 2, "note": "bad"}], finding="broken")
    if status == "UNCERTAIN":
        row.update(severity="P2", finding="needs device test")
    if status == "NOT_APPLICABLE":
        row["reason"] = "profile"
    row.update(kw)
    return row


def write_jsonl(path, rows):
    Path(path).write_text("\n".join(json.dumps(r) for r in rows) + "\n", encoding="utf-8")


class RenderTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.d = Path(self.tmp.name)
        self.cat, _ = catalog.load()

    def tearDown(self):
        self.tmp.cleanup()

    def run_render(self, rows, *extra, out="r.md"):
        write_jsonl(self.d / "f.jsonl", rows)
        return quiet(render_report.main, [str(self.d / "f.jsonl"), "--out", str(self.d / out),
                                          "--project", "demo", "--date", "2026-10-03", *extra])

    def problems(self, rows, plan=None):
        for i, r in enumerate(rows):
            r["_where"] = f"f:{i + 1}"
        return render_report.validate(rows, self.cat, plan)

    def test_valid_findings_render(self):
        rows = [finding("NET-002", "FAIL", severity="P1"), finding("NET-001", "PASS"),
                finding("LIFE-002", "UNCERTAIN"), finding("LIFE-012", "NOT_APPLICABLE")]
        code, out, err = self.run_render(rows)
        self.assertEqual(code, 0, err)
        report = (self.d / "r.md").read_text()
        self.assertIn("## Verdict: AT RISK", report)
        self.assertIn("### NET-002 — FAIL (P1)", report)
        self.assertIn("`src/b.ts:2` — bad", report)
        self.assertIn("Every request has an explicit timeout", report)  # check text filled from catalog
        self.assertIn("| LIFE-012 | NOT_APPLICABLE |", report)
        self.assertIn("verdict: AT RISK", out)

    def test_verdicts(self):
        v = render_report.verdict
        self.assertEqual(v([{"status": "FAIL", "severity": "P0"}]), "BLOCKED")
        self.assertEqual(v([{"status": "FAIL", "severity": "P1"}]), "AT RISK")
        self.assertEqual(v([{"status": "UNCERTAIN", "severity": "P0"}]), "AT RISK")
        self.assertEqual(v([{"status": "FAIL", "severity": "P2"}, {"status": "UNCERTAIN", "severity": "P1"}]),
                         "READY WITH CAVEATS")

    def test_validation_rules(self):
        cases = {
            "PASS needs evidence or a search record": finding("NET-001", "PASS", evidence=[]),
            "FAIL needs at least one file evidence": finding("NET-002", "FAIL", evidence=[{"cmd": "rg x", "note": ""}]),
            "FAIL needs a severity": {k: v for k, v in finding("NET-003", "FAIL").items() if k != "severity"},
            "FAIL needs a finding": finding("NET-004", "FAIL", finding=" "),
            "UNCERTAIN needs a finding": finding("NET-005", "UNCERTAIN", finding=""),
            "NOT_APPLICABLE needs a reason": finding("NET-006", "NOT_APPLICABLE", reason=""),
            "still PENDING": {"id": "NET-007", "status": "PENDING"},
            "invalid status": {"id": "NET-008", "status": "OK"},
            "invalid severity": finding("NET-009", "FAIL", severity="HIGH"),
            "marked fixed but has no test": finding("NET-010", "FAIL", fix={"status": "fixed", "summary": "x"}),
            "fix.status must be one of": finding("NET-011", "FAIL", fix={"status": "done"}),
            "evidence[0] needs a 'file' or 'cmd'": finding("NET-012", "PASS", evidence=[{"note": "x"}]),
            "unknown check id": finding("NOPE-001", "PASS"),
        }
        for expected, row in cases.items():
            with self.subTest(expected=expected):
                self.assertTrue(any(expected in p for p in self.problems([row])),
                                f"expected problem containing {expected!r}")

    def test_secrets_in_findings_are_rejected(self):
        leaks = {
            "Stripe key": "sk_live_" + "a1B2c3D4e5F6g7H8i9",
            "AWS access key": "AKIA" + "ABCDEFGHIJKLMNOP",
            "GitHub token": "ghp_" + "a" * 36,
            "private key": "-----BEGIN RSA PRIVATE KEY-----",
        }
        for kind, value in leaks.items():
            with self.subTest(kind=kind):
                row = finding("SEC-002", "FAIL", severity="P0",
                              evidence=[{"file": ".env", "line": 3, "note": f"STRIPE_KEY={value}"}])
                self.assertTrue(any(kind in p for p in self.problems([row])))
        redacted = finding("SEC-002", "FAIL", severity="P0",
                           evidence=[{"file": ".env", "line": 3, "note": "live Stripe secret key (sk_l…) committed"}])
        self.assertEqual(self.problems([redacted]), [])

    def test_pass_with_search_record_only_is_valid(self):
        row = finding("SEC-002", "PASS", evidence=[], searched=["gitleaks detect --no-banner"])
        self.assertEqual(self.problems([row]), [])

    def test_duplicates_and_plan_coverage(self):
        rows = [finding("NET-001", "PASS"), finding("NET-001", "PASS")]
        self.assertTrue(any("duplicate finding" in p for p in self.problems(rows)))
        plan = [{"id": "NET-001"}, {"id": "NET-002"}]
        probs = self.problems([finding("NET-001", "PASS")], plan)
        self.assertTrue(any("have no finding: NET-002" in p for p in probs))

    def test_invalid_findings_write_no_report(self):
        code, _, err = self.run_render([finding("NET-001", "PASS", evidence=[])])
        self.assertEqual(code, 2)
        self.assertIn("no report written", err)
        self.assertFalse((self.d / "r.md").exists())

    def test_never_overwrites_a_report(self):
        (self.d / "r.md").write_text("keep me")
        code, _, err = self.run_render([finding("NET-001", "PASS")])
        self.assertEqual(code, 2)
        self.assertIn("already exists", err)
        self.assertEqual((self.d / "r.md").read_text(), "keep me")

    def test_compare_with_previous(self):
        write_jsonl(self.d / "prev.jsonl", [finding("NET-001", "FAIL"), finding("NET-002", "PASS"),
                                             finding("NET-003", "FAIL")])
        rows = [finding("NET-001", "PASS"), finding("NET-002", "FAIL"), finding("NET-003", "FAIL"),
                finding("NET-004", "FAIL")]
        code, _, err = self.run_render(rows, "--previous", str(self.d / "prev.jsonl"))
        self.assertEqual(code, 0, err)
        report = (self.d / "r.md").read_text()
        self.assertIn("- Fixed: 1 — NET-001", report)
        self.assertIn("- Regressed (PASS → FAIL): 1 — NET-002", report)
        self.assertIn("- Still failing: 1 — NET-003", report)
        self.assertIn("- New failures (not in the previous audit): 1 — NET-004", report)

    def test_pipes_in_text_are_escaped(self):
        rows = [finding("NET-002", "FAIL", finding="a | b", evidence=[{"file": "x|y.ts", "note": "p|q"}])]
        code, _, err = self.run_render(rows)
        self.assertEqual(code, 0, err)
        self.assertIn("`x\\|y.ts` — p\\|q", (self.d / "r.md").read_text())


class DetectProfileTests(unittest.TestCase):
    SCRIPT = SCRIPTS / "detect_profile.sh"

    def detect(self, files):
        with tempfile.TemporaryDirectory() as d:
            for rel, content in files.items():
                p = Path(d, rel)
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text(content, encoding="utf-8")
            res = subprocess.run(["/bin/bash", str(self.SCRIPT), d], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, res.stderr)
        line = [x for x in res.stdout.splitlines() if x.startswith("PROFILE=")][-1]
        tags = line.split("=", 1)[1]
        return set(tags.split(",")) if tags else set()

    def test_expo_app_with_payments_push_and_llm(self):
        pkg = json.dumps({"dependencies": {"expo": "51", "react-native": "0.74", "expo-notifications": "1",
                                            "react-native-purchases": "7", "openai": "4",
                                            "@supabase/supabase-js": "2"}})
        self.assertEqual(self.detect({"package.json": pkg}), {"mobile", "push", "pay", "llm", "db"})

    def test_next_app_is_web_and_api(self):
        pkg = json.dumps({"dependencies": {"next": "14", "react-dom": "18", "prisma": "5"}})
        self.assertEqual(self.detect({"package.json": pkg}), {"web", "api", "db"})

    def test_django_backend(self):
        self.assertEqual(self.detect({"requirements.txt": "Django==5.0\npsycopg==3.1\n"}), {"api", "db"})

    def test_native_ios_with_storekit_and_swiftdata(self):
        files = {"App.xcodeproj/project.pbxproj": "",
                 "App/Store.swift": "import StoreKit\n",
                 "App/Model.swift": "import SwiftData\n@Model final class Item {}\n",
                 "App/Push.swift": "UNUserNotificationCenter.current()\n"}
        self.assertEqual(self.detect(files), {"mobile", "pay", "db", "push"})

    def test_supabase_project_is_api(self):
        self.assertIn("api", self.detect({"supabase/config.toml": ""}))

    def test_substring_names_do_not_match(self):
        pkg = json.dumps({"dependencies": {"archiver": "6", "description-parser": "1"}})
        self.assertEqual(self.detect({"package.json": pkg}), set())

    def test_empty_directory(self):
        self.assertEqual(self.detect({"README.md": "hi"}), set())


if __name__ == "__main__":
    unittest.main()
