#!/usr/bin/env python3
"""Score an audit of a known-vulnerable fixture against its expected findings.

Usage:
    eval_fixture.py FINDINGS.jsonl EXPECTED.json [--min 0.8]

For every expected item:
  - detected: at least one of its `expect_fail_any` checks is FAIL;
  - located:  such a FAIL also cites a file under the item's `path` (a string or a list of
              alternatives; case-insensitive substring, "*" allowed), so one broad finding can't
              count for many different weaknesses;
  - flagged:  not located, but one of its checks is UNCERTAIN at the right place — the audit
              surfaced it for runtime verification (reported separately, not counted as located).
Prints per-item results and recall, and exits 1 when located recall is below --min (default 0).
"""

import argparse
import fnmatch
import json
import sys
from pathlib import Path


def load_findings(path):
    rows = []
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        if line.strip():
            rows.append(json.loads(line))
    return rows


def cites(finding, pattern):
    pattern = pattern.lower()
    for e in finding.get("evidence") or []:
        f = str(e.get("file") or "").lower()
        if not f:
            continue
        if "*" in pattern:
            if fnmatch.fnmatch(f, "*" + pattern) or fnmatch.fnmatch(f, pattern):
                return True
        elif pattern in f:
            return True
    return False


def cites_any(finding, paths):
    paths = paths if isinstance(paths, list) else [paths]
    return any(cites(finding, p) for p in paths)


def score(findings, expected):
    fails = [f for f in findings if f.get("status") == "FAIL"]
    uncertain = [f for f in findings if f.get("status") == "UNCERTAIN"]
    results = []
    for item in expected["items"]:
        ids = set(item["expect_fail_any"])
        matching = [f for f in fails if f.get("id") in ids]
        located = [f["id"] for f in matching if cites_any(f, item["path"])]
        flagged = [f["id"] for f in uncertain if f.get("id") in ids and cites_any(f, item["path"])]
        results.append({
            "exercise": item["exercise"],
            "detected": bool(matching),
            "located": bool(located),
            "flagged": bool(flagged) and not located,
            "by": sorted(set(located or flagged or [f["id"] for f in matching])),
        })
    return results


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("findings")
    ap.add_argument("expected")
    ap.add_argument("--min", type=float, default=0.0, help="minimum located recall (0-1) to exit 0")
    args = ap.parse_args(argv)

    expected = json.loads(Path(args.expected).read_text(encoding="utf-8"))
    results = score(load_findings(args.findings), expected)
    n = len(results)
    det = sum(r["detected"] for r in results)
    loc = sum(r["located"] for r in results)

    print(f"Fixture: {expected.get('fixture')} @ {expected.get('commit')}")
    fl = sum(r["flagged"] for r in results)
    print(f"{'Exercise':42} {'Detected':9} {'Located':8} By")
    for r in results:
        where = "yes" if r["located"] else ("flagged" if r["flagged"] else "NO")
        print(f"{r['exercise'][:42]:42} {'yes' if r['detected'] else 'NO':9} {where:8} "
              f"{', '.join(r['by']) or '-'}")
    print(f"\nDetected: {det}/{n} ({det / n:.0%})   Located: {loc}/{n} ({loc / n:.0%})   "
          f"Flagged UNCERTAIN at the right place: {fl}")
    oos = expected.get("out_of_scope") or []
    if oos:
        print(f"Out of scope ({len(oos)}): " + "; ".join(f"{o['exercise']} - {o['reason']}" for o in oos))
    missed = [r["exercise"] for r in results if not r["located"] and not r["flagged"]]
    if missed:
        print("Not located: " + ", ".join(missed))
    return 0 if (loc / n if n else 1) >= args.min else 1


if __name__ == "__main__":
    sys.exit(main())
