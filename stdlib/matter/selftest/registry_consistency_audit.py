#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/registry_consistency_audit.py — cross-source verb-count consistency.

For hexa-matter (a spec-first repo with no registry.jsonl), this audit ensures
the FIVE authoritative verb sources agree on the 36-verb scoreboard:

  (1) cli/hexa-matter.hexa     VERBS literal
  (2) hexa.toml                [verbs] group flatten
  (3) verify/spec_presence.hexa VERBS literal
  (4) README.md                 verb-count badge
  (5) AXIS.md                   group-sum claim

Per raw#9 hexa-only: Python stdlib only.

Exit 0 PASS / 1 FAIL.
"""
from __future__ import annotations

import os
import re
import sys

REPO_ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)

EXPECTED_VERB_COUNT = 36


def extract_cli_verbs() -> list[str]:
    path = os.path.join(REPO_ROOT, "cli", "hexa-matter.hexa")
    with open(path, "r", encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(r"let VERBS = \[(.*?)\]\s*\n", text, re.DOTALL)
    if not m:
        return []
    block = m.group(1)
    return re.findall(r'\["([^"]+)",', block)


def extract_toml_verbs() -> list[str]:
    path = os.path.join(REPO_ROOT, "hexa.toml")
    with open(path, "r", encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(r"\[verbs\]\n(.*?)(?=\n\[|\Z)", text, re.DOTALL)
    if not m:
        return []
    block = m.group(1)
    verbs: list[str] = []
    for line in block.splitlines():
        # group = ["verb1", "verb2", ...]
        mm = re.search(r"=\s*\[(.*?)\]", line)
        if not mm:
            continue
        verbs.extend(re.findall(r'"([^"]+)"', mm.group(1)))
    return verbs


def extract_verify_verbs() -> list[str]:
    path = os.path.join(REPO_ROOT, "verify", "spec_presence.hexa")
    with open(path, "r", encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(r"let VERBS = \[(.*?)\]\s*\n", text, re.DOTALL)
    if not m:
        return []
    return re.findall(r'\["([^"]+)",', m.group(1))


def extract_readme_count() -> int | None:
    path = os.path.join(REPO_ROOT, "README.md")
    with open(path, "r", encoding="utf-8") as fh:
        text = fh.read()
    # Badge: shields.io `badge/verbs-NN-<color>` (e.g. verbs-36-informational)
    # or legacy `verbs-NN_spec`; or prose "NN-verb" (optionally bold-wrapped).
    m = re.search(r"verbs-([0-9]+)[-_]", text)
    if m:
        return int(m.group(1))
    m = re.search(r"\*{0,2}([0-9]+)-verb", text)
    if m:
        return int(m.group(1))
    return None


def extract_axis_total() -> int | None:
    """AXIS.md §0 — claims '29 dispatchable verbs' as the total."""
    path = os.path.join(REPO_ROOT, "AXIS.md")
    with open(path, "r", encoding="utf-8") as fh:
        text = fh.read()
    # Look for "29 dispatchable verbs" or "= 29"
    m = re.search(r"\*\*([0-9]+) dispatchable verbs\*\*", text)
    if m:
        return int(m.group(1))
    m = re.search(r"=\s*\*\*([0-9]+)\*\*", text)
    if m:
        return int(m.group(1))
    return None


def main() -> int:
    print("hexa-matter/selftest/registry_consistency_audit — 5-source verb-count cross-check")
    print(f"  root: {REPO_ROOT}\n")

    cli = extract_cli_verbs()
    toml_verbs = extract_toml_verbs()
    ver = extract_verify_verbs()
    readme_n = extract_readme_count()
    axis_n = extract_axis_total()

    print(f"  cli/hexa-matter.hexa VERBS:      {len(cli)} verbs")
    print(f"  hexa.toml [verbs]:               {len(toml_verbs)} verbs")
    print(f"  verify/spec_presence.hexa VERBS: {len(ver)} verbs")
    print(f"  README.md verb badge:            {readme_n}")
    print(f"  AXIS.md '... dispatchable verbs':{axis_n}")
    print()

    fail = 0

    # Count parity
    counts = [
        ("cli", len(cli)),
        ("toml", len(toml_verbs)),
        ("verify", len(ver)),
        ("readme", readme_n if readme_n is not None else -1),
        ("axis", axis_n if axis_n is not None else -1),
    ]
    for src, n in counts:
        if n != EXPECTED_VERB_COUNT:
            print(f"  [FAIL] {src} count = {n} (expected {EXPECTED_VERB_COUNT})")
            fail += 1
        else:
            print(f"  [PASS] {src} count = {EXPECTED_VERB_COUNT}")

    # Set parity between CLI / toml / verify (the only 3 that list verb names)
    s_cli = set(cli)
    s_toml = set(toml_verbs)
    s_ver = set(ver)
    if s_cli != s_toml:
        diff = (s_cli ^ s_toml)
        print(f"  [FAIL] cli != toml set-diff: {sorted(diff)}")
        fail += 1
    else:
        print("  [PASS] cli set == toml set")
    if s_cli != s_ver:
        diff = (s_cli ^ s_ver)
        print(f"  [FAIL] cli != verify set-diff: {sorted(diff)}")
        fail += 1
    else:
        print("  [PASS] cli set == verify set")

    print()
    if fail > 0:
        print(f"__HEXA_MATTER_REGISTRY_CONSISTENCY__ FAIL  ({fail} mismatch)")
        return 1
    print("__HEXA_MATTER_REGISTRY_CONSISTENCY__ PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
