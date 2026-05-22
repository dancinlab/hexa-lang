#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
sources_audit.py — validity check for SOURCES.md files.

Status: FUNCTIONAL (stdlib only). Air-gap safe.

Phase F (2026-05-13): validates that `arxiv/SOURCES.md` and `web/SOURCES.md`:
  1. Exist and are non-empty.
  2. List the expected arxiv categories (cond-mat.mtrl-sci primary).
  3. List a non-empty vendor set (Wacker, Wolfspeed, etc.).
  4. List USPTO + EPO patent endpoints.
  6. The speculative-claim trip list is consistent (named in arxiv + web SOURCES).

This audit does NOT make network calls — it validates that the bridge
configuration is self-consistent and the SOURCES files have the expected
structure.

Sentinel: __HEXA_MATTER_SOURCES_AUDIT__ PASS / FAIL

License: MIT (hexa-matter Phase F).
"""

from __future__ import annotations
import os
import sys


def _bridge_dir() -> str:
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.normpath(os.path.join(here, ".."))


def _check(path: str, must_contain: list, label: str) -> list:
    """Return list of failures (strings)."""
    failures = []
    if not os.path.isfile(path):
        return [f"{label}: missing file {path}"]
    with open(path, encoding="utf-8") as f:
        text = f.read()
    if not text.strip():
        return [f"{label}: empty file {path}"]
    for token in must_contain:
        if token.lower() not in text.lower():
            failures.append(f"{label}: missing token '{token}'")
    return failures


def main() -> int:
    bridge = _bridge_dir()

    arxiv_required = [
        "cond-mat.mtrl-sci",
        "cond-mat.supr-con",
        "User-Agent",
        "3-second",     # backoff discipline
        "@arxiv-informed",
    ]
    web_required = [
        "Wacker",
        "Wolfspeed",
        "USPTO",
        "EPO",
        "robots.txt",
        "Climeworks",   # honest baseline for MOF DAC
    ]

    failures = []
    failures += _check(os.path.join(bridge, "arxiv", "SOURCES.md"),
                       arxiv_required, "arxiv/SOURCES.md")
    failures += _check(os.path.join(bridge, "web", "SOURCES.md"),
                       web_required, "web/SOURCES.md")

    # Cross-check: the speculative-trip-list tokens used in arxiv_digest.py +
    # materials_news_feed.py + patent_search.py should each name at least one
    # canonical speculative claim (LK-99 + 25-year + $100/t).
    for module_name in ("arxiv/arxiv_digest.py",
                        "web/materials_news_feed.py",
                        "web/patent_search.py"):
        mod_path = os.path.join(bridge, module_name)
        if not os.path.isfile(mod_path):
            failures.append(f"{module_name}: missing module file")
            continue
        with open(mod_path, encoding="utf-8") as f:
            src = f.read().lower()
        # Each must reference UNPROVEN_FLAGS-style discipline
        if "unproven" not in src:
            failures.append(f"{module_name}: missing UNPROVEN discipline reference")
        if "25-year" not in src and "$100/t" not in src and "lk-99" not in src:
            failures.append(f"{module_name}: missing speculative-trip-list anchor")

    if failures:
        for f_ in failures:
            print(f"  FAIL: {f_}")
        print(f"__HEXA_MATTER_SOURCES_AUDIT__ FAIL  ({len(failures)} issues)")
        return 1

    print("  PASS: arxiv/SOURCES.md has all required tokens")
    print("  PASS: web/SOURCES.md has all required tokens")
    print("  PASS: speculative-trip-list discipline present in all 3 verb-tagging modules")
    print("__HEXA_MATTER_SOURCES_AUDIT__ PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
