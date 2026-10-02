#!/usr/bin/env python3
"""Check catalog for the production-readiness-audit skill.

Parses the check tables in references/checks/*.md:

    | ID | Check | Look at | Sev | Scope |

Usage:
    catalog.py lint
        Validate every check file (unique IDs, 5 columns, valid severity and scope tags).
    catalog.py areas
        List area files with their check counts.
    catalog.py plan --profile mobile,api,db [--areas network,auth] [--out plan.jsonl]
        Write one JSON line per check: NOT_APPLICABLE (reason "profile") when the check's
        scope doesn't match the profile, otherwise PENDING. Every PENDING line must be
        replaced by a real finding before render_report.py will accept the audit.
"""

import argparse
import json
import re
import sys
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent.parent
CHECKS_DIR = SKILL_DIR / "references" / "checks"

SEVERITIES = ("P0", "P1", "P2", "P3")
SCOPES = ("all", "client", "mobile", "web", "api", "db", "push", "pay", "llm")
PROFILE_TAGS = ("mobile", "web", "api", "db", "push", "pay", "llm")
ROW_RE = re.compile(r"^\|\s*([A-Z][A-Z0-9]*-\d{3})\s*\|")


def split_row(line):
    """Split a Markdown table row into cells, honouring escaped pipes (\\|)."""
    body = line.strip()
    if body.startswith("|"):
        body = body[1:]
    if body.endswith("|"):
        body = body[:-1]
    cells = re.split(r"(?<!\\)\|", body)
    return [c.strip().replace("\\|", "|") for c in cells]


def load(checks_dir=CHECKS_DIR):
    """Return (checks, errors). Each check: id, area, check, look, severity, scope (list)."""
    checks, errors, seen = [], [], {}
    files = sorted(Path(checks_dir).glob("*.md"))
    if not files:
        errors.append(f"no check files in {checks_dir}")
    for path in files:
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if not ROW_RE.match(line):
                continue
            where = f"{path.name}:{lineno}"
            cells = split_row(line)
            if len(cells) != 5:
                errors.append(f"{where}: expected 5 columns, got {len(cells)}")
                continue
            cid, text, look, sev, scope_cell = cells
            scope = [s.strip() for s in scope_cell.split(",") if s.strip()]
            if cid in seen:
                errors.append(f"{where}: duplicate id {cid} (first in {seen[cid]})")
                continue
            seen[cid] = where
            if sev not in SEVERITIES:
                errors.append(f"{where}: {cid} has invalid severity {sev!r}")
            bad = [s for s in scope if s not in SCOPES]
            if not scope or bad:
                errors.append(f"{where}: {cid} has invalid scope {scope_cell!r}")
            if not text:
                errors.append(f"{where}: {cid} has an empty check text")
            checks.append({
                "id": cid, "area": path.stem, "check": text, "look": look,
                "severity": sev, "scope": scope,
            })
    return checks, errors


def applies(scope, profile):
    """True if a check with these scope tags applies to a project with these profile tags."""
    profile = set(profile)
    for tag in scope:
        if tag == "all":
            return True
        if tag == "client" and profile & {"mobile", "web"}:
            return True
        if tag in profile:
            return True
    return False


def parse_tags(value, allowed, name):
    tags = [t.strip() for t in (value or "").split(",") if t.strip()]
    bad = [t for t in tags if t not in allowed]
    if bad:
        raise SystemExit(f"error: unknown {name}: {', '.join(bad)} (allowed: {', '.join(allowed)})")
    return tags


def _fail(errors):
    for e in errors:
        print(f"error: {e}", file=sys.stderr)
    return 1


def cmd_lint(_args):
    checks, errors = load()
    if errors:
        return _fail(errors)
    print(f"ok: {len(checks)} checks in {len({c['area'] for c in checks})} files")
    return 0


def cmd_areas(_args):
    checks, errors = load()
    if errors:
        return _fail(errors)
    counts = {}
    for c in checks:
        counts[c["area"]] = counts.get(c["area"], 0) + 1
    for area, n in sorted(counts.items()):
        print(f"{area}\t{n}")
    return 0


def cmd_plan(args):
    checks, errors = load()
    if errors:
        return _fail(errors)
    profile = parse_tags(args.profile, PROFILE_TAGS, "profile tag")
    if not profile:
        raise SystemExit("error: --profile needs at least one tag")
    known_areas = sorted({c["area"] for c in checks})
    areas = parse_tags(args.areas, known_areas, "area") or known_areas
    lines, pending = [], 0
    for c in checks:
        if c["area"] not in areas:
            continue
        row = {"id": c["id"], "check": c["check"], "area": c["area"],
               "severity": c["severity"], "scope": c["scope"]}
        if applies(c["scope"], profile):
            row["status"] = "PENDING"
            pending += 1
        else:
            row["status"] = "NOT_APPLICABLE"
            row["reason"] = f"profile: scope {','.join(c['scope'])} not in {','.join(profile)}"
        lines.append(json.dumps(row, ensure_ascii=False))
    text = "\n".join(lines) + "\n"
    if args.out:
        Path(args.out).write_text(text, encoding="utf-8")
    else:
        sys.stdout.write(text)
    print(f"plan: {len(lines)} checks, {pending} to audit, {len(lines) - pending} not applicable",
          file=sys.stderr)
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("lint")
    sub.add_parser("areas")
    p = sub.add_parser("plan")
    p.add_argument("--profile", required=True, help="comma-separated: " + ",".join(PROFILE_TAGS))
    p.add_argument("--areas", help="comma-separated area file names (default: all)")
    p.add_argument("--out", help="write the plan here instead of stdout")
    args = parser.parse_args(argv)
    return {"lint": cmd_lint, "areas": cmd_areas, "plan": cmd_plan}[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
