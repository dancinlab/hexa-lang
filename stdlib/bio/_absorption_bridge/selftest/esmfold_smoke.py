#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
esmfold_smoke.py — selftest wrapper invoking the esmfold adapter
offline fixture replay.

Emits sentinel: __HEXA_BIO_ESMFOLD_SMOKE__ PASS / FAIL.

Per hexa-bio cycle-30++++++++ absorption-bridge wiring; aggregated by
_absorption_bridge/selftest/run_all.sh.
"""

from __future__ import annotations
import argparse
import subprocess
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
ADAPTER = HERE.parent / "esmfold/esmfold_smoke.py"
SENTINEL = "__HEXA_BIO_ESMFOLD_SMOKE__"
INNER_SENTINEL = "__HEXA_BIO_ESMFOLD_SMOKE__"


def _selftest() -> int:
    if not ADAPTER.exists():
        print(f"  FAIL: adapter not found at {ADAPTER}")
        print(f"{SENTINEL} FAIL")
        return 1
    res = subprocess.run(
        [sys.executable, str(ADAPTER), "--selftest"],
        capture_output=True, text=True,
    )
    sys.stdout.write(res.stdout)
    if res.returncode != 0:
        sys.stderr.write(res.stderr)
        print(f"{SENTINEL} FAIL (adapter exit {res.returncode})")
        return 1
    if f"{INNER_SENTINEL} PASS" not in res.stdout:
        print(f"{SENTINEL} FAIL (adapter sentinel missing)")
        return 1
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
