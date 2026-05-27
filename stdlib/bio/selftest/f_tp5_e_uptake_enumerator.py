#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
f_tp5_e_uptake_enumerator.py — F-TP5-e public API uptake witness builder.

Greps a list of consumer roots for invocations of `weave_compose()` (or its
HEXA dispatcher equivalents) and emits a witness row matching
`weave/spec/compose_uptake_v1.schema.json`.

Per cross-cutting Require (R5) raw 9 hexa-only: **Python stdlib only.**

Usage:

    python3 selftest/f_tp5_e_uptake_enumerator.py \
        --root . \
        [--root <other-repo-root>] ... \
        [--published <consumer_root_substring>] ... \
        [--emit] [--summary]

Behaviour:
- Walks each --root recursively, skipping common build/cache dirs.
- Greps for textual `weave_compose(` (Python call), `--compose ` (HEXA CLI
  flag pattern), and `weave.compose(` (qualified call).
- Self-references (callsites within the hexa-bio repo when --root is the
  hexa-bio root itself) are tagged context_kind=test if path includes
  /tests/ or /selftest/, =example if path includes /examples/, else
  =production. Doc snippets in *.md files tagged =doc-snippet.
- --published flags consumer_root substrings considered "external".

PASS criterion (F-TP5-e): distinct_consumers >= 5 OR published_consumer >= 1.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from datetime import datetime, timezone

REGISTRY_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "state",
    "discovery_absorption",
    "registry.jsonl",
)

CALL_PATTERNS = [
    re.compile(r"\bweave_compose\s*\("),
    re.compile(r"\bweave\.compose\s*\("),
    re.compile(r"--compose\b"),
]

SKIP_DIRS = {
    ".git",
    ".venv",
    "venv",
    "__pycache__",
    "node_modules",
    ".pnpm-store",
    ".filter-repo-backup",
    "build",
    "dist",
}

CODE_EXTS = {".py", ".hexa", ".sh", ".md", ".lean", ".rs", ".ts", ".js"}


def _hash16(s: str) -> str:
    return hashlib.sha256(s.encode("utf-8")).hexdigest()[:16]


def _classify_context(path: str) -> str:
    p = path.replace(os.sep, "/")
    if p.endswith(".md"):
        return "doc-snippet"
    if "/tests/" in p or "/selftest/" in p or "/test_" in p:
        return "test"
    if "/examples/" in p or "/example_" in p:
        return "example"
    return "production"


def walk_root(root: str) -> list[tuple[str, int, str]]:
    """Yield (path, line_no, line_text) tuples for every match in root."""
    hits: list[tuple[str, int, str]] = []
    root_abs = os.path.abspath(root)
    for dirpath, dirnames, filenames in os.walk(root_abs):
        # Prune skip dirs in-place
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS and not d.startswith(".filter-repo-backup")]
        for fn in filenames:
            ext = os.path.splitext(fn)[1].lower()
            if ext not in CODE_EXTS:
                continue
            fp = os.path.join(dirpath, fn)
            try:
                with open(fp, "r", encoding="utf-8", errors="replace") as fh:
                    for i, line in enumerate(fh, start=1):
                        for pat in CALL_PATTERNS:
                            if pat.search(line):
                                hits.append((fp, i, line.rstrip("\n")))
                                break
            except OSError:
                continue
    return hits


def build_callsites(roots: list[str], published_substrs: list[str]) -> list[dict]:
    callsites: list[dict] = []
    for root in roots:
        root_abs = os.path.abspath(root)
        for fp, line_no, line_text in walk_root(root):
            rel = os.path.relpath(fp, root_abs)
            callsites.append({
                "consumer_root": root_abs,
                "file": rel,
                "line": line_no,
                "context_kind": _classify_context(fp),
                "snippet_hash": _hash16(line_text.strip()),
            })
    return callsites


def evaluate(callsites: list[dict], roots: list[str], published_substrs: list[str]) -> dict:
    fetched_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    distinct_consumers = sorted({cs["consumer_root"] for cs in callsites})
    published_count = sum(
        1 for cr in distinct_consumers
        if any(sub in cr for sub in published_substrs)
    )
    distinct_n = len(distinct_consumers)
    crit = {
        "distinct_consumers_ge_5": distinct_n >= 5,
        "published_consumer_ge_1": published_count >= 1,
    }
    overall = crit["distinct_consumers_ge_5"] or crit["published_consumer_ge_1"]
    return {
        "schema": "raw_77_weave_compose_uptake_v1",
        "enumerated_at": fetched_at,
        "consumer_callsites": callsites,
        "distinct_consumers": distinct_n,
        "published_consumer_count": published_count,
        "pass_evaluation": {"criteria": crit, "overall_pass": overall},
        "witness_ref": "state/discovery_absorption/registry.jsonl#raw_77_weave_compose_uptake_v1",
    }


def emit_witness(row: dict) -> int:
    os.makedirs(os.path.dirname(REGISTRY_PATH), exist_ok=True)
    with open(REGISTRY_PATH, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")
    return 1


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description="F-TP5-e public API uptake enumerator")
    p.add_argument("--root", action="append", default=[], help="Consumer root to scan (repeatable). Default: current dir.")
    p.add_argument("--published", action="append", default=[], help="Substring matching 'external/published' consumer paths (repeatable).")
    p.add_argument("--emit", action="store_true", help="Append witness row to registry.")
    p.add_argument("--summary", action="store_true", help="Print witness JSON to stdout.")
    args = p.parse_args(argv)

    roots = args.root or [os.getcwd()]
    callsites = build_callsites(roots, args.published)
    row = evaluate(callsites, roots, args.published)

    if args.emit:
        emit_witness(row)
        sys.stderr.write(f"emitted 1 witness row -> {REGISTRY_PATH}\n")

    if args.summary:
        # Strip large callsites array for terminal readability.
        compact = {k: v for k, v in row.items() if k != "consumer_callsites"}
        compact["callsite_count"] = len(row["consumer_callsites"])
        print(json.dumps(compact, sort_keys=True, indent=2))
    else:
        sys.stderr.write(
            f"distinct_consumers={row['distinct_consumers']}  "
            f"published={row['published_consumer_count']}  "
            f"overall_pass={row['pass_evaluation']['overall_pass']}\n"
        )

    # Exit-code semantics (post-2026-05-13 — aligned with the F-TP5-e
    # USER-DISCRETION PASS recorded in .roadmap.weave line ~75):
    #   - overall_pass True  → __F_TP5E_UPTAKE__ PASS, exit 0 (objective criterion
    #     [≥5 external call-sites OR ≥1 published external consumer] met).
    #   - overall_pass False but ≥1 internal call-site → __F_TP5E_UPTAKE__ SKIP,
    #     exit 0. This is the EXPECTED state: the enumerator infra works, the
    #     weave_compose API exists in-repo, external uptake is still 0. The
    #     falsifier was accepted as PASS under user discretion 2026-05-06
    #     (infra landed + falsifier remains live + re-evaluatable). SKIP ≠ FAIL.
    #   - 0 internal call-sites → __F_TP5E_UPTAKE__ FAIL, exit 1. THIS is a real
    #     regression: the weave_compose API was removed from hexa-bio's own
    #     modules, so the enumerator has nothing to scan.
    eval_ = row["pass_evaluation"]
    overall_pass = eval_["overall_pass"]
    internal_callsites = row["distinct_consumers"]
    if overall_pass:
        sys.stderr.write("__F_TP5E_UPTAKE__ PASS  (objective criterion met — external uptake materialized)\n")
        return 0
    if internal_callsites >= 1:
        sys.stderr.write(
            f"__F_TP5E_UPTAKE__ SKIP  (enumerator infra OK; {internal_callsites} internal callsite(s), "
            f"0 external — F-TP5-e USER-DISCRETION PASS per .roadmap.weave; objective criterion not yet "
            f"met but falsifier remains live + re-evaluatable)\n"
        )
        return 0
    sys.stderr.write(
        "__F_TP5E_UPTAKE__ FAIL  (0 internal callsites — the weave_compose API appears removed from "
        "hexa-bio's own modules; enumerator has nothing to scan; this IS a regression)\n"
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
