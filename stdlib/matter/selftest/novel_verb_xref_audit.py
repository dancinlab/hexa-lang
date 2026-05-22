#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/novel_verb_xref_audit.py — Phase J.5 NOVEL ↔ verb spec xref + Tier-2 extension (2026-05-14).

For each of the 7 Tier-1 NOVEL candidates (per NOVEL_ROADMAP.md §5 Tier-1
promotion list), enforces bidirectional cross-link discipline:

  (forward)  NOVEL.md subsection contains `Verb spec link:` line that points
             to the candidate's primary verb-spec home (markdown link form).
  (back)     The linked verb-spec file contains a `Related NOVEL candidate`
             line and the candidate's `hxm-*` ID.

Tier-2 wave (2026-05-14): same bidirectional check is applied to 10 Tier-2
candidates as a SOFT-FLOOR group — up to K = 2 broken links tolerated to
allow a transitional state if a verb spec is mid-migration. The Tier-1 gate
remains hard (0 broken).

Per LATTICE_POLICY §1.2 / §1.3 / raw#10 C3 + SPEC_FIRST: cross-link
annotations are nav links, NOT promotion to EXTERNAL-VERIFIED. UNPROVEN /
UNVERIFIED markers stay untouched. Gate is purely structural.

stdlib-only. Exit 0 PASS / 1 FAIL.

Sentinel on success:
  `__HEXA_MATTER_NOVEL_VERB_XREF__ PASS (7/7 Tier-1 linked, N/10 Tier-2 linked, 0 broken)`
"""
from __future__ import annotations

import os
import re
import sys

REPO_ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)

# 7 Tier-1 candidates with their primary verb-spec home(s).
# Each entry: candidate_id -> tuple of verb-spec relative paths.
# Multi-home (pv-tandem) lists both primary and secondary.
TIER1: dict[str, tuple[str, ...]] = {
    "hxm-pv-tandem-002": (
        "perovskite/perovskite.md",
        "silicon/silicon.md",
    ),
    "hxm-bat-cath-drx-001": ("electrode-material/electrode-material.md",),
    "hxm-bat-anode-li-metal-001": ("electrode-material/electrode-material.md",),
    "hxm-co2-cap-mof-mfm-002": ("mof/mof.md",),
    "hxm-te-half-zrnisn-001": ("metallurgy/swordsmithing.md",),
    "hxm-cement-mgo-co2neg-001": ("concrete_tech/concrete-technology.md",),
    "hxm-h2-elec-iro2-doped-001": ("electrode-material/electrode-material.md",),
}

# Tier-2 candidates with their primary verb-spec home(s). Soft-floor group:
# K ≤ 2 broken links tolerated for transitional state.
# 2026-05-18: +11 hxm-mag-* (RARE-EARTH+ALTERNATIVE.tape roster, NOVEL §3.5).
TIER2: dict[str, tuple[str, ...]] = {
    "hxm-quantum-si-donor-001": ("silicon/silicon.md",),
    "hxm-quantum-hbn-vb-001": ("2d-materials/2d-materials.md",),
    "hxm-ni-4gen-re-free-001": ("superalloy/superalloy.md",),
    "hxm-mycel-composite-001": ("wood-cellulose/wood-cellulose.md",),
    "hxm-algae-plastic-001": ("biodegradable-plastics/biodegradable-plastics.md",),
    "hxm-weyl-tas-001": ("compound-semi/compound-semi.md",),
    "hxm-flatband-tbg-001": ("2d-materials/2d-materials.md",),
    "hxm-aero-polyimide-001": ("aerogel-foam/aerogel-foam.md",),
    "hxm-mof-h2o-stable-uio66-001": ("mof/mof.md",),
    "hxm-bat-cath-naion-001": ("electrode-material/electrode-material.md",),
    "hxm-mag-refree-001": ("magnetic-materials/magnetic-materials.md",),
    "hxm-mag-mnbi-001": ("magnetic-materials/magnetic-materials.md",),
    "hxm-mag-tetra-001": ("magnetic-materials/magnetic-materials.md",),
    "hxm-mag-boride-001": ("magnetic-materials/magnetic-materials.md",),
    "hxm-mag-mn2sb-001": ("magnetic-materials/magnetic-materials.md",),
    "hxm-mag-mnalc-001": ("magnetic-materials/magnetic-materials.md",),
    "hxm-mag-ferrhd-001": ("magnetic-materials/magnetic-materials.md",),
    "hxm-mag-lowdy-001": ("magnetic-materials/magnetic-materials.md",),
    "hxm-mag-aifound-001": ("magnetic-materials/magnetic-materials.md",),
    "hxm-mag-gfcs-001": ("magnetic-materials/magnetic-materials.md",),
    "hxm-mag-znfe-001": ("magnetic-materials/magnetic-materials.md",),
}

TIER2_SOFT_FLOOR_K = 2

NOVEL = os.path.join(REPO_ROOT, "NOVEL.md")

# Section header pattern within NOVEL.md (e.g., `### 4.A.1 Title` or
# `#### 4.B.1 Title` or `### 3.7 Title`).
SECTION_RE = re.compile(r"^#{2,4}\s+(\d+\.[A-Z]?(?:\.\d+)?)\s+")


def read(path: str) -> str:
    with open(path, "r", encoding="utf-8", errors="ignore") as fh:
        return fh.read()


def find_candidate_section(text: str, cid: str) -> tuple[str, int, int] | None:
    """Return (section_id, start_line, end_line) of the subsection containing cid.

    Walks NOVEL.md top-down, tracking the most recent section header. When the
    line containing `cid` (in a row) is hit, returns the enclosing section.
    """
    lines = text.splitlines()
    cur_section = None
    cur_start = None
    cid_line = None
    next_section_line = None
    for idx, line in enumerate(lines):
        sm = SECTION_RE.match(line)
        if sm:
            if cid_line is not None and cur_section is not None:
                # We previously found cid; now this is the next section header.
                next_section_line = idx
                return (cur_section, cur_start or 0, next_section_line)
            cur_section = sm.group(1)
            cur_start = idx
        # Look for the row that introduces the candidate ID. The token must
        # appear inside backticks as a leading-row identifier (avoid matching
        # cross-references in body prose).
        if cid_line is None and f"`{cid}`" in line:
            # Confirm we found the table row, not a parenthetical mention —
            # the candidate row always starts with `| `<id>` |`.
            stripped = line.lstrip()
            if stripped.startswith("|") and f"`{cid}`" in stripped:
                cid_line = idx
    # If we hit EOF after finding cid, return up to end-of-file.
    if cid_line is not None and cur_section is not None:
        return (cur_section, cur_start or 0, len(lines))
    return None


def audit_group(
    novel_text: str,
    group: dict[str, tuple[str, ...]],
    group_label: str,
) -> tuple[int, int, list[str]]:
    """Return (linked_ok, broken_count, log_lines) for a given xref group."""
    linked_ok = 0
    broken = 0
    log: list[str] = []
    for cid, verb_paths in group.items():
        # (forward) find the candidate's subsection and verify Verb spec link line.
        sect = find_candidate_section(novel_text, cid)
        if sect is None:
            log.append(f"  [FAIL] {cid} ({group_label}): NOT FOUND in NOVEL.md")
            broken += 1
            continue
        section_id, s, e = sect
        sub = "\n".join(novel_text.splitlines()[s:e])
        if "Verb spec link" not in sub:
            log.append(
                f"  [FAIL] {cid} (§{section_id}, {group_label}): missing `Verb spec link:` line"
            )
            broken += 1
            continue
        # Confirm each expected verb-spec path is linked (forward direction).
        forward_ok = True
        for vp in verb_paths:
            if vp not in sub:
                log.append(
                    f"  [FAIL] {cid} (§{section_id}, {group_label}): forward link to `{vp}` missing"
                )
                broken += 1
                forward_ok = False
        if not forward_ok:
            continue

        # (back) verify each verb-spec file mentions this cid + has 'Related NOVEL candidate'
        back_ok = True
        for vp in verb_paths:
            vp_abs = os.path.join(REPO_ROOT, vp)
            if not os.path.exists(vp_abs):
                log.append(
                    f"  [FAIL] {cid} ({group_label}): verb spec `{vp}` does not exist on disk"
                )
                broken += 1
                back_ok = False
                continue
            vtext = read(vp_abs)
            if "Related NOVEL candidate" not in vtext:
                log.append(
                    f"  [FAIL] {cid} ({group_label}): `{vp}` missing `Related NOVEL candidate` line"
                )
                broken += 1
                back_ok = False
                continue
            if cid not in vtext:
                log.append(
                    f"  [FAIL] {cid} ({group_label}): `{vp}` does NOT mention this candidate ID"
                )
                broken += 1
                back_ok = False
        if back_ok:
            log.append(
                f"  [PASS] {cid} (§{section_id}, {group_label}) ↔ {', '.join(verb_paths)}"
            )
            linked_ok += 1

    return linked_ok, broken, log


def main() -> int:
    print("hexa-matter/selftest/novel_verb_xref_audit — NOVEL ↔ verb spec xref")
    print(f"  root: {REPO_ROOT}\n")

    if not os.path.exists(NOVEL):
        print("  [FAIL] NOVEL.md missing")
        print("__HEXA_MATTER_NOVEL_VERB_XREF__ FAIL  (NOVEL.md missing)")
        return 1

    novel_text = read(NOVEL)

    # Group A: Tier-1 — hard gate (0 broken allowed).
    t1_ok, t1_broken, t1_log = audit_group(novel_text, TIER1, "Tier-1")
    for line in t1_log:
        print(line)

    # Group B: Tier-2 — soft floor (K ≤ 2 broken tolerated).
    print()
    t2_ok, t2_broken, t2_log = audit_group(novel_text, TIER2, "Tier-2")
    for line in t2_log:
        print(line)

    print()
    n1 = len(TIER1)
    n2 = len(TIER2)
    fatal = False
    if t1_broken > 0:
        fatal = True
    if t2_broken > TIER2_SOFT_FLOOR_K:
        fatal = True

    total_broken = t1_broken + t2_broken
    if fatal:
        print(
            f"__HEXA_MATTER_NOVEL_VERB_XREF__ FAIL  "
            f"({t1_ok}/{n1} Tier-1 linked, {t2_ok}/{n2} Tier-2 linked, "
            f"{total_broken} broken; Tier-1 hard gate=0, Tier-2 soft floor K={TIER2_SOFT_FLOOR_K})"
        )
        return 1
    print(
        f"__HEXA_MATTER_NOVEL_VERB_XREF__ PASS  "
        f"({t1_ok}/{n1} Tier-1 linked, {t2_ok}/{n2} Tier-2 linked, {total_broken} broken)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
