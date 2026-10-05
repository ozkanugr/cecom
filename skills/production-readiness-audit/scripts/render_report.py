#!/usr/bin/env python3
"""Validate audit findings and render the production-readiness report.

Usage:
    render_report.py FINDINGS.jsonl --out REPORT.md [--plan PLAN.jsonl] [--previous PREV.jsonl]
                     [--project NAME] [--profile TAGS] [--tier T2] [--scope TEXT] [--date YYYY-MM-DD]

Exits 2 and lists every problem if the findings are invalid (see references/method.md):
unknown or duplicate IDs, PENDING entries, missing evidence/severity/finding/reason, a fixed
finding without a test, or (with --plan) planned checks that have no finding.
"""

import argparse
import datetime
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from catalog import SEVERITIES, load  # noqa: E402

STATUSES = ("PASS", "FAIL", "UNCERTAIN", "NOT_APPLICABLE")

# Provider-specific credential shapes. Findings must cite *where* a secret is, never the secret:
# reports are often committed or shared, which would leak it a second time.
SECRET_PATTERNS = (
    ("AWS access key", re.compile(r"\b(AKIA|ASIA)[0-9A-Z]{16}\b")),
    ("GitHub token", re.compile(r"\bgh[pousr]_[A-Za-z0-9]{30,}")),
    ("GitHub fine-grained token", re.compile(r"\bgithub_pat_[A-Za-z0-9_]{30,}")),
    ("Stripe key", re.compile(r"\b(sk|rk)_(live|test)_[A-Za-z0-9]{16,}")),
    ("Anthropic key", re.compile(r"\bsk-ant-[A-Za-z0-9_-]{20,}")),
    ("OpenAI key", re.compile(r"\bsk-(proj-)?[A-Za-z0-9_-]{32,}")),
    ("Slack token", re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}")),
    ("Google API key", re.compile(r"\bAIza[0-9A-Za-z_-]{35}")),
    ("private key", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("JWT", re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}")),
)


def secret_kind(text):
    for kind, rx in SECRET_PATTERNS:
        if rx.search(text or ""):
            return kind
    return None


def texts_of(f):
    """Every free-text value in a finding that ends up in the report."""
    out = [f.get("finding"), f.get("reason"), f.get("test"), f.get("check")]
    out += [s for s in f.get("searched") or [] if isinstance(s, str)]
    for e in f.get("evidence") or []:
        if isinstance(e, dict):
            out += [e.get("note"), e.get("cmd"), e.get("file")]
    fix = f.get("fix")
    if isinstance(fix, dict):
        out += [fix.get("summary"), fix.get("reference")] + [x for x in fix.get("files") or [] if isinstance(x, str)]
    return [str(t) for t in out if t]
FIX_STATUSES = ("none", "proposed", "fixed")
SEV_RANK = {s: i for i, s in enumerate(SEVERITIES)}


def read_jsonl(path):
    rows, errors = [], []
    for lineno, line in enumerate(Path(path).read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError as e:
            errors.append(f"{path}:{lineno}: invalid JSON ({e.msg})")
            continue
        if not isinstance(obj, dict):
            errors.append(f"{path}:{lineno}: each line must be a JSON object")
            continue
        obj["_where"] = f"{Path(path).name}:{lineno}"
        rows.append(obj)
    return rows, errors


def validate(findings, catalog, plan=None):
    """Return a list of human-readable problems; empty when the findings are valid."""
    problems, seen = [], {}
    by_id = {c["id"]: c for c in catalog}
    for f in findings:
        w, fid = f["_where"], f.get("id")
        if not isinstance(fid, str) or fid not in by_id:
            problems.append(f"{w}: unknown check id {fid!r}")
            continue
        if fid in seen:
            problems.append(f"{w}: duplicate finding for {fid} (first at {seen[fid]})")
            continue
        seen[fid] = w
        status = f.get("status")
        if status == "PENDING":
            problems.append(f"{w}: {fid} is still PENDING — the audit is incomplete")
            continue
        if status not in STATUSES:
            problems.append(f"{w}: {fid} has invalid status {status!r}")
            continue
        sev = f.get("severity")
        if sev is not None and sev not in SEVERITIES:
            problems.append(f"{w}: {fid} has invalid severity {sev!r}")
        evidence = f.get("evidence") or []
        searched = f.get("searched") or []
        if not isinstance(evidence, list) or not isinstance(searched, list):
            problems.append(f"{w}: {fid} evidence and searched must be lists")
            continue
        for i, e in enumerate(evidence):
            if not isinstance(e, dict) or not (e.get("file") or e.get("cmd")):
                problems.append(f"{w}: {fid} evidence[{i}] needs a 'file' or 'cmd'")
        if status == "PASS" and not evidence and not searched:
            problems.append(f"{w}: {fid} PASS needs evidence or a search record")
        if status == "FAIL":
            if sev is None:
                problems.append(f"{w}: {fid} FAIL needs a severity")
            if not any(isinstance(e, dict) and e.get("file") for e in evidence):
                problems.append(f"{w}: {fid} FAIL needs at least one file evidence")
            if not (f.get("finding") or "").strip():
                problems.append(f"{w}: {fid} FAIL needs a finding")
        if status == "UNCERTAIN":
            if sev is None:
                problems.append(f"{w}: {fid} UNCERTAIN needs a severity")
            if not (f.get("finding") or "").strip():
                problems.append(f"{w}: {fid} UNCERTAIN needs a finding saying what is unknown")
        if status == "NOT_APPLICABLE" and not (f.get("reason") or "").strip():
            problems.append(f"{w}: {fid} NOT_APPLICABLE needs a reason")
        for text in texts_of(f):
            kind = secret_kind(text)
            if kind:
                problems.append(f"{w}: {fid} appears to contain a {kind}; redact it "
                                "(keep at most the first 4 characters, e.g. 'sk_l…') and cite file:line instead")
                break
        fix = f.get("fix")
        if fix is not None:
            if not isinstance(fix, dict) or fix.get("status") not in FIX_STATUSES:
                problems.append(f"{w}: {fid} fix.status must be one of {', '.join(FIX_STATUSES)}")
            else:
                if fix["status"] in ("proposed", "fixed") and not (fix.get("reference") or "").strip():
                    problems.append(f"{w}: {fid} fix needs a reference: the current official doc or standard it follows")
                if fix["status"] == "fixed" and not (f.get("test") or "").strip():
                    problems.append(f"{w}: {fid} is marked fixed but has no test/verification")
    if plan is not None:
        missing = [p["id"] for p in plan if p.get("id") not in seen]
        if missing:
            problems.append(f"{len(missing)} planned check(s) have no finding: {', '.join(missing[:20])}"
                            + (" …" if len(missing) > 20 else ""))
    return problems


def verdict(findings):
    fails = {f.get("severity") for f in findings if f["status"] == "FAIL"}
    unc = {f.get("severity") for f in findings if f["status"] == "UNCERTAIN"}
    if "P0" in fails:
        return "BLOCKED"
    if "P1" in fails or "P0" in unc:
        return "AT RISK"
    return "READY WITH CAVEATS"


def cell(text, limit=160):
    text = re.sub(r"\s+", " ", str(text or "")).strip()
    if len(text) > limit:
        text = text[: limit - 1] + "…"
    return text.replace("|", "\\|")


def ev_str(e):
    note = f" — {e['note']}" if e.get("note") else ""
    if e.get("file"):
        loc = e["file"] + (f":{e['line']}" if e.get("line") else "")
        return f"`{loc}`{note}"
    return f"`{e.get('cmd')}`{note}"


def sort_key(f):
    return (SEV_RANK.get(f.get("severity"), 9), f["id"])


def id_list(rows):
    return (" — " + ", ".join(f["id"] for f in rows)) if rows else ""


def render(findings, catalog, meta, previous=None):
    by_id = {c["id"]: c for c in catalog}
    for f in findings:
        c = by_id[f["id"]]
        if not f.get("check"):
            f["check"] = c["check"]
        f["area"] = c["area"]
    out = []
    w = out.append
    w(f"# Production readiness audit — {meta['project']}")
    w("")
    w(f"**Date:** {meta['date']}  ")
    w(f"**Profile:** {meta['profile'] or '—'}  ")
    w(f"**Tier:** {meta['tier'] or '—'}  ")
    w(f"**Scope:** {meta['scope'] or 'all areas'}")
    w("")
    v = verdict(findings)
    w(f"## Verdict: {v}")
    w("")
    w({"BLOCKED": "At least one P0 check fails. Do not release until it is fixed.",
       "AT RISK": "No P0 failures, but P1 failures or unresolved P0 uncertainties remain.",
       "READY WITH CAVEATS": "No P0/P1 failures and no P0 uncertainties. Review the remaining items below."}[v])
    w("")

    w("## Summary")
    w("")
    w("| Status | P0 | P1 | P2 | P3 | Total |")
    w("|---|---|---|---|---|---|")
    for st in STATUSES:
        rows = [f for f in findings if f["status"] == st]
        counts = [sum(1 for f in rows if f.get("severity") == s) for s in SEVERITIES]
        w(f"| {st} | " + " | ".join(str(n) for n in counts) + f" | {len(rows)} |")
    w(f"| **All** | | | | | **{len(findings)}** |")
    w("")

    w("| Area | PASS | FAIL | UNCERTAIN | N/A |")
    w("|---|---|---|---|---|")
    for a in sorted({f["area"] for f in findings}):
        rows = [f for f in findings if f["area"] == a]
        counts = [sum(1 for f in rows if f["status"] == st) for st in STATUSES]
        w(f"| {a} | " + " | ".join(str(n) for n in counts) + " |")
    w("")

    if previous is not None:
        prev = {p.get("id"): p.get("status") for p in previous}
        fixed = [f for f in findings if prev.get(f["id"]) == "FAIL" and f["status"] == "PASS"]
        regressed = [f for f in findings if prev.get(f["id"]) == "PASS" and f["status"] == "FAIL"]
        still = [f for f in findings if prev.get(f["id"]) == "FAIL" and f["status"] == "FAIL"]
        new = [f for f in findings if f["status"] == "FAIL" and f["id"] not in prev]
        w("## Changes since the previous audit")
        w("")
        w(f"- Fixed: {len(fixed)}{id_list(fixed)}")
        w(f"- Regressed (PASS → FAIL): {len(regressed)}{id_list(regressed)}")
        w(f"- Still failing: {len(still)}{id_list(still)}")
        w(f"- New failures (not in the previous audit): {len(new)}{id_list(new)}")
        w("")

    fails = sorted([f for f in findings if f["status"] == "FAIL"], key=sort_key)
    w("## Failures")
    w("")
    if fails:
        w("| ID | Sev | Check | Where | Fix |")
        w("|---|---|---|---|---|")
        for f in fails:
            where = next((ev_str(e) for e in f.get("evidence") or [] if e.get("file")), "")
            fix = (f.get("fix") or {}).get("status", "none")
            w(f"| {f['id']} | {f['severity']} | {cell(f['check'], 90)} | {cell(where, 90)} | {fix} |")
    else:
        w("None.")
    w("")

    unc = sorted([f for f in findings if f["status"] == "UNCERTAIN"], key=sort_key)
    w("## Uncertain — needs runtime verification or more information")
    w("")
    if unc:
        w("| ID | Sev | Check | What would settle it |")
        w("|---|---|---|---|")
        for f in unc:
            w(f"| {f['id']} | {f['severity']} | {cell(f['check'], 80)} | {cell(f.get('finding'), 120)} |")
    else:
        w("None.")
    w("")

    w("## Details")
    w("")
    if not fails and not unc:
        w("No failures or uncertainties.")
        w("")
    for f in fails + unc:
        w(f"### {f['id']} — {f['status']} ({f.get('severity')})")
        w("")
        w(f"**Check:** {f['check']}")
        w("")
        w(f"**Finding:** {(f.get('finding') or '').strip()}")
        w("")
        if f.get("evidence"):
            w("**Evidence:**")
            for e in f["evidence"]:
                w(f"- {ev_str(e)}")
            w("")
        if f.get("searched"):
            w("**Searched:**")
            for s in f["searched"]:
                w(f"- `{s}`")
            w("")
        fix = f.get("fix")
        if fix and fix.get("status") != "none":
            files = ", ".join(f"`{x}`" for x in fix.get("files") or [])
            w(f"**Fix ({fix['status']}):** {fix.get('summary', '')}" + (f" — {files}" if files else ""))
            w("")
            if fix.get("reference"):
                w(f"**Source:** {fix['reference']}")
                w("")
        if f.get("test"):
            w(f"**Test:** {f['test']}")
            w("")

    w("## All checks")
    w("")
    w("| ID | Status | Sev | Check | Evidence / reason |")
    w("|---|---|---|---|---|")
    for f in sorted(findings, key=lambda x: (x["area"], x["id"])):
        if f["status"] == "NOT_APPLICABLE":
            detail = f.get("reason", "")
        elif f.get("evidence"):
            detail = ev_str(f["evidence"][0])
        else:
            detail = "searched: " + "; ".join(f.get("searched") or [])
        w(f"| {f['id']} | {f['status']} | {f.get('severity') or ''} | {cell(f['check'], 80)} | {cell(detail, 110)} |")
    w("")
    return "\n".join(out)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("findings")
    ap.add_argument("--out", required=True)
    ap.add_argument("--plan")
    ap.add_argument("--previous")
    ap.add_argument("--project", default=Path.cwd().name)
    ap.add_argument("--profile", default="")
    ap.add_argument("--tier", default="")
    ap.add_argument("--scope", default="")
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    args = ap.parse_args(argv)

    catalog, errors = load()
    findings, ferr = read_jsonl(args.findings)
    errors += ferr
    plan = previous = None
    if args.plan:
        plan, perr = read_jsonl(args.plan)
        errors += perr
    if args.previous:
        previous, perr = read_jsonl(args.previous)
        errors += perr
    if not errors and not findings:
        errors.append("no findings")
    if not errors:
        errors = validate(findings, catalog, plan)
    if errors:
        for e in errors:
            print(f"error: {e}", file=sys.stderr)
        print(f"{len(errors)} problem(s); no report written.", file=sys.stderr)
        return 2

    meta = {"project": args.project, "profile": args.profile, "tier": args.tier,
            "scope": args.scope, "date": args.date}
    report = render(findings, catalog, meta, previous)
    out = Path(args.out)
    if out.exists():
        print(f"error: {out} already exists; choose another --out (reports are never overwritten)",
              file=sys.stderr)
        return 2
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(report, encoding="utf-8")
    counts = ", ".join(f"{st}={sum(1 for f in findings if f['status'] == st)}" for st in STATUSES)
    print(f"verdict: {verdict(findings)}; {counts}; report: {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
