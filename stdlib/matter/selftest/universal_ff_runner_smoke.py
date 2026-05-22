#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
universal_ff_runner_smoke.py — Phase K.1 selftest wrapper.

Invokes `_python_bridge/universal_ff_runner.py --selftest` in mock mode
and validates:
  1. Runner module loads cleanly (no import-time crash).
  2. All 5 supported models (MACE / CHGNet / ALIGNN / SchNet / M3GNet)
     emit the correct SKIP sentinel when their optional dep is absent.
  3. No live model is loaded in selftest path (raw#10 C3 — no live
     compute in CI; runner's `--selftest` flag force-SKIPs every dep).

Sentinel emitted (read by `selftest/universal_ff_runner_smoke.sh`):
  __HEXA_MATTER_UFF_RUNNER_SMOKE__ PASS / FAIL

License: MIT (hexa-matter Phase K).
"""

from __future__ import annotations
import argparse
import subprocess
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent
RUNNER = REPO_ROOT / "_python_bridge" / "universal_ff_runner.py"
SENTINEL = "__HEXA_MATTER_UFF_RUNNER_SMOKE__"
INNER_SENTINEL = "__HEXA_MATTER_UFF_RUNNER__"

# Required SKIP-path coverage per Phase K.1: all 5 models must be reached.
EXPECTED_MODELS = ("mace", "chgnet", "alignn", "schnet", "m3gnet")


def _selftest() -> int:
    print(f"  runner: {RUNNER}")
    if not RUNNER.exists():
        print(f"  FAIL: runner not found at {RUNNER}")
        print(f"{SENTINEL} FAIL")
        return 1

    res = subprocess.run(
        [sys.executable, str(RUNNER), "--selftest"],
        capture_output=True, text=True,
    )
    sys.stdout.write(res.stdout)
    if res.stderr:
        sys.stderr.write(res.stderr)

    if res.returncode != 0:
        print(f"  FAIL: runner exit {res.returncode}")
        print(f"{SENTINEL} FAIL")
        return 1

    # Validate the 5 SKIP sentinels are reachable.
    missing_models = [m for m in EXPECTED_MODELS
                      if f"SKIP {m} " not in res.stdout]
    if missing_models:
        print(f"  FAIL: missing SKIP sentinels for: {missing_models}")
        print(f"{SENTINEL} FAIL")
        return 1

    # Validate the inner PASS sentinel.
    if f"{INNER_SENTINEL} PASS" not in res.stdout:
        print(f"  FAIL: inner sentinel '{INNER_SENTINEL} PASS' missing")
        print(f"{SENTINEL} FAIL")
        return 1

    # Validate no live compute leaked (5 skipped / 0 run).
    if "5 skipped, 0 run" not in res.stdout:
        print(f"  FAIL: expected '5 skipped, 0 run' in selftest output")
        print(f"{SENTINEL} FAIL")
        return 1

    print(f"{SENTINEL} PASS (5/5 models SKIP cleanly when deps missing)")
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
