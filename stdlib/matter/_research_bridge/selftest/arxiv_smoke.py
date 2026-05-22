#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
arxiv_smoke.py — offline aggregator for the arxiv subsystem.

Status: FUNCTIONAL (stdlib only). Air-gap safe.

Phase F (2026-05-13): runs both arxiv modules (`arxiv_pull.py --selftest` and
`arxiv_digest.py --selftest`) under subprocess, aggregates PASS/FAIL/SKIP.

This is the per-subsystem aggregator. The top-level Phase F gate is
`selftest/research_bridge_smoke.sh` at the repo root.

Sentinel: __HEXA_MATTER_ARXIV_SMOKE__ PASS / FAIL

License: MIT (hexa-matter Phase F).
"""

from __future__ import annotations
import os
import subprocess
import sys


def _arxiv_dir() -> str:
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.normpath(os.path.join(here, "..", "arxiv"))


def _run_module(path: str) -> int:
    """Run `python3 path --selftest`; return exit code (0 = PASS/SKIP, !=0 = FAIL)."""
    if not os.path.isfile(path):
        print(f"  FAIL: module missing: {path}")
        return 1
    print(f"  ─── running {os.path.basename(path)} --selftest ───")
    rc = subprocess.call([sys.executable, path, "--selftest"])
    return rc


def main() -> int:
    # `--selftest` is the default-and-only mode for this aggregator
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        # tolerate other args, but warn
        print("  INFO: arxiv_smoke only supports --selftest", file=sys.stderr)

    modules = [
        os.path.join(_arxiv_dir(), "arxiv_pull.py"),
        os.path.join(_arxiv_dir(), "arxiv_digest.py"),
    ]
    fails = 0
    for m in modules:
        rc = _run_module(m)
        if rc != 0:
            fails += 1

    if fails == 0:
        print(f"__HEXA_MATTER_ARXIV_SMOKE__ PASS  ({len(modules)}/{len(modules)} modules)")
        return 0
    print(f"__HEXA_MATTER_ARXIV_SMOKE__ FAIL  ({fails} of {len(modules)} modules failed)")
    return 1


if __name__ == "__main__":
    sys.exit(main())
