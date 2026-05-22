#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
universal_ff_smoke.py — selftest wrapper invoking all 5 universal-FF adapters.

Aggregates SchNet / MACE / ALIGNN / CHGNet / M3GNet offline fixture replays.
Emits sentinel: __HEXA_MATTER_UNIVERSAL_FF_SMOKE__ PASS / FAIL.
"""

from __future__ import annotations
import argparse
import subprocess
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
UFF_DIR = HERE.parent / "universal_ff"
ADAPTERS = [
    UFF_DIR / "schnet_call.py",
    UFF_DIR / "mace_call.py",
    UFF_DIR / "alignn_call.py",
    UFF_DIR / "chgnet_call.py",
    UFF_DIR / "m3gnet_call.py",
]
EXPECTED_SENTINELS = [
    "__HEXA_MATTER_SCHNET_CALL__",
    "__HEXA_MATTER_MACE_CALL__",
    "__HEXA_MATTER_ALIGNN_CALL__",
    "__HEXA_MATTER_CHGNET_CALL__",
    "__HEXA_MATTER_M3GNET_CALL__",
]
SENTINEL = "__HEXA_MATTER_UNIVERSAL_FF_SMOKE__"


def _selftest() -> int:
    fails = 0
    skips = 0
    passes = 0
    for adapter, sentinel in zip(ADAPTERS, EXPECTED_SENTINELS):
        if not adapter.exists():
            print(f"  FAIL: adapter not found at {adapter}")
            fails += 1
            continue
        res = subprocess.run(
            [sys.executable, str(adapter), "--selftest"],
            capture_output=True, text=True,
        )
        if res.returncode != 0:
            print(f"  FAIL: {adapter.name} (exit {res.returncode})")
            fails += 1
            continue
        if "SKIP mode" in res.stdout:
            print(f"  SKIP: {adapter.name} (optional dep missing)")
            skips += 1
            passes += 1
        elif f"{sentinel} PASS" in res.stdout:
            print(f"  PASS: {adapter.name}")
            passes += 1
        else:
            print(f"  FAIL: {adapter.name} (sentinel missing)")
            fails += 1

    total = len(ADAPTERS)
    print(f"  summary: {passes}/{total} PASS ({skips} SKIP), {fails} FAIL")
    if fails == 0:
        print(f"{SENTINEL} PASS ({passes}/{total} adapters, {skips} skipped)")
        return 0
    print(f"{SENTINEL} FAIL ({fails} of {total} adapters failed)")
    return 1


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
