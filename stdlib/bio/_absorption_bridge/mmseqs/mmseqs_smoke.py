#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
mmseqs_smoke.py — MMseqs2 sequence-search adapter (smoke, offline replay).

Status: PARTIAL (offline fixture replay PASS; live mmseqs CLI SKIPs).

MMseqs2 (Steinegger & Söding 2017) is the fast sequence search/clustering
engine that powers ColabFold's MSA pipeline and many downstream tools.
Orders of magnitude faster than BLAST + PSI-BLAST at similar sensitivity.

Offline (`--selftest`): load `cache/sample_alignment.json`, validate
M8-style schema (query, target, fident, alnlen, evalue, bits), emit
sentinel.

Live: MMseqs2 is a CLI binary. Live use requires `mmseqs` on PATH +
target database (UniRef / NR / ColabFoldDB / etc). OUT-OF-SCOPE for
selftest.

C3: NO n=6 lattice-fit applied. MMseqs2 carries OWN metrics —
fident, alnlen, E-value, bits score.

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
SENTINEL = "__HEXA_BIO_MMSEQS_SMOKE__"


def _have_mmseqs_cli() -> bool:
    return shutil.which("mmseqs") is not None


def load_fixture(path: Path = SAMPLE_FIXTURE) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def validate_mmseqs_alignment(rec: dict) -> tuple[bool, str]:
    required = ["tool_name", "query", "database", "n_hits", "hits", "license"]
    for k in required:
        if k not in rec:
            return False, f"missing required field: {k}"

    if rec["tool_name"] != "MMseqs2":
        return False, f"tool_name not MMseqs2: {rec['tool_name']!r}"

    if not isinstance(rec["hits"], list) or len(rec["hits"]) == 0:
        return False, "hits must be a non-empty list"

    if rec["n_hits"] != len(rec["hits"]):
        return False, f"n_hits ({rec['n_hits']}) != len(hits) ({len(rec['hits'])})"

    for i, h in enumerate(rec["hits"]):
        for hk in ("target", "fident", "alnlen", "evalue", "bits"):
            if hk not in h:
                return False, f"hits[{i}] missing field: {hk}"
        if not (0.0 <= float(h["fident"]) <= 1.0):
            return False, f"hits[{i}].fident out of [0,1]: {h['fident']!r}"
        if float(h["evalue"]) < 0.0:
            return False, f"hits[{i}].evalue negative: {h['evalue']!r}"

    lic = str(rec["license"]).lower()
    if "gpl" not in lic:
        return False, f"MMseqs2 license must be GPLv3: {rec['license']!r}"

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

    ok, reason = validate_mmseqs_alignment(rec)
    if not ok:
        print(f"  FAIL: schema check: {reason}")
        print(f"{SENTINEL} FAIL")
        return 1
    top = rec["hits"][0]
    print(f"  PASS: fixture schema OK (query={rec['query']}, n_hits={rec['n_hits']}, "
          f"top_hit={top['target']} fident={top['fident']} evalue={top['evalue']})")
    print("  PASS: GPLv3 license confirmed")

    stamp = md5_stamp(rec)
    print(f"  PASS: md5 cache stamp = {stamp}")
    if _have_mmseqs_cli():
        print("  NOTE: mmseqs CLI on PATH; live search OUT-OF-SCOPE for selftest (offline determinism)")
    else:
        print("  NOTE: mmseqs CLI not on PATH; live path SKIPPED (per NO LIVE TOOL rule)")
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
