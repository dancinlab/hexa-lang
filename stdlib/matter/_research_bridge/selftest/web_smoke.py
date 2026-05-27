#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
web_smoke.py — offline aggregator for the web subsystem.

Status: FUNCTIONAL (stdlib only). Air-gap safe.

Phase F (2026-05-13): runs all three web modules under subprocess
(`vendor_datasheet_pull.py`, `materials_news_feed.py`, `patent_search.py`)
with `--selftest`, aggregates PASS/FAIL/SKIP.

Sentinel: __HEXA_MATTER_WEB_SMOKE__ PASS / FAIL

License: MIT (hexa-matter Phase F).
"""

from __future__ import annotations
import os
import subprocess
import sys


def _web_dir() -> str:
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.normpath(os.path.join(here, "..", "web"))


def _run_module(path: str) -> int:
    if not os.path.isfile(path):
        print(f"  FAIL: module missing: {path}")
        return 1
    print(f"  ─── running {os.path.basename(path)} --selftest ───")
    rc = subprocess.call([sys.executable, path, "--selftest"])
    return rc


def main() -> int:
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("  INFO: web_smoke only supports --selftest", file=sys.stderr)

    modules = [
        os.path.join(_web_dir(), "vendor_datasheet_pull.py"),
        os.path.join(_web_dir(), "materials_news_feed.py"),
        os.path.join(_web_dir(), "patent_search.py"),
    ]
    fails = 0
    for m in modules:
        rc = _run_module(m)
        if rc != 0:
            fails += 1

    if fails == 0:
        print(f"__HEXA_MATTER_WEB_SMOKE__ PASS  ({len(modules)}/{len(modules)} modules)")
        return 0
    print(f"__HEXA_MATTER_WEB_SMOKE__ FAIL  ({fails} of {len(modules)} modules failed)")
    return 1


if __name__ == "__main__":
    sys.exit(main())
