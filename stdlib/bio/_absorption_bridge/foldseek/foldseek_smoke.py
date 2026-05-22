#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
foldseek_smoke.py — Foldseek structural-search adapter (smoke, offline replay).

Status: PARTIAL (offline fixture replay PASS; live foldseek CLI SKIPs).

Foldseek (van Kempen et al. 2024 Nat Biotech) is the de-facto structural
search engine — orders of magnitude faster than TM-align / DALI by
encoding 3D structure into a 20-letter "3Di" alphabet and running MMseqs2
on the resulting sequences.

Offline (`--selftest`): load `cache/sample_alignment.json`, validate
M8-style schema (query, target, fident, alnlen, evalue, lddt, tm_score),
emit sentinel.

Live: Foldseek is a CLI binary, not a Python package. Live use requires
`foldseek` on PATH; not exercised in selftest.

C3: NO n=6 lattice-fit applied. Foldseek carries OWN metrics —
fident, lDDT (0-1), TM-score (0-1), E-value.

License: Apache-2.0 (hexa-bio cycle-30++++++++).
"""

from __future__ import annotations
import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path
from typing import Any


HERE = Path(__file__).resolve().parent
CACHE_DIR = HERE / "cache"
SAMPLE_FIXTURE = CACHE_DIR / "sample_alignment.json"
SENTINEL = "__HEXA_BIO_FOLDSEEK_SMOKE__"


def _have_foldseek_cli() -> bool:
    return shutil.which("foldseek") is not None


def load_fixture(path: Path = SAMPLE_FIXTURE) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def validate_foldseek_alignment(rec: dict) -> tuple[bool, str]:
    required = ["tool_name", "alphabet", "query", "database", "n_hits", "hits", "license"]
    for k in required:
        if k not in rec:
            return False, f"missing required field: {k}"

    if rec["tool_name"] != "Foldseek":
        return False, f"tool_name not Foldseek: {rec['tool_name']!r}"

    if "3Di" not in str(rec["alphabet"]):
        return False, f"alphabet must contain 3Di marker: {rec['alphabet']!r}"

    if not isinstance(rec["hits"], list) or len(rec["hits"]) == 0:
        return False, "hits must be a non-empty list"

    if rec["n_hits"] != len(rec["hits"]):
        return False, f"n_hits ({rec['n_hits']}) != len(hits) ({len(rec['hits'])})"

    for i, h in enumerate(rec["hits"]):
        for hk in ("target", "fident", "alnlen", "evalue", "lddt", "tm_score"):
            if hk not in h:
                return False, f"hits[{i}] missing field: {hk}"
        if not (0.0 <= float(h["lddt"]) <= 1.0):
            return False, f"hits[{i}].lddt out of [0,1]: {h['lddt']!r}"
        if not (0.0 <= float(h["tm_score"]) <= 1.0):
            return False, f"hits[{i}].tm_score out of [0,1]: {h['tm_score']!r}"
        if float(h["evalue"]) < 0.0:
            return False, f"hits[{i}].evalue negative: {h['evalue']!r}"

    lic = str(rec["license"]).lower()
    if "gpl" not in lic:
        return False, f"Foldseek license must be GPLv3: {rec['license']!r}"

    return True, "ok"


def md5_stamp(payload: Any) -> str:
    blob = json.dumps(payload, sort_keys=True).encode("utf-8")
    return hashlib.md5(blob).hexdigest()[:12]


def _selftest() -> int:
    if not SAMPLE_FIXTURE.exists():
        print(f"  FAIL: fixture not found at {SAMPLE_FIXTURE}")
        print(f"{SENTINEL} FAIL")
        return 1

    try:
        rec = load_fixture()
    except Exception as e:
        print(f"  FAIL: fixture load raised {type(e).__name__}: {e}")
        print(f"{SENTINEL} FAIL")
        return 1

    ok, reason = validate_foldseek_alignment(rec)
    if not ok:
        print(f"  FAIL: schema check: {reason}")
        print(f"{SENTINEL} FAIL")
        return 1
    top = rec["hits"][0]
    print(f"  PASS: fixture schema OK (query={rec['query']}, n_hits={rec['n_hits']}, "
          f"top_hit={top['target']} lddt={top['lddt']} tm={top['tm_score']})")
    print("  PASS: 3Di alphabet marker preserved (Foldseek's defining feature)")
    print("  PASS: GPLv3 license confirmed")

    stamp = md5_stamp(rec)
    print(f"  PASS: md5 cache stamp = {stamp}")
    if _have_foldseek_cli():
        print("  NOTE: foldseek CLI on PATH; live search OUT-OF-SCOPE for selftest (offline determinism)")
    else:
        print("  NOTE: foldseek CLI not on PATH; live path SKIPPED (per NO LIVE TOOL rule)")
    print(f"{SENTINEL} PASS")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument("--selftest", action="store_true")
    args = p.parse_args()
    if args.selftest:
        return _selftest()
    p.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
