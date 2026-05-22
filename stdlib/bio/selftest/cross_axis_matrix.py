#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/cross_axis_matrix.py — cross-axis bridge matrix REPORTER.

WHAT THIS IS
------------
A deterministic visual reporter that scans every cross-axis bridge file
discovered under `_python_bridge/module/*_cross.py`, extracts the two (or
three) axes each bridge spans by parsing its docstring header + canonical
module-name aliases, and renders an axis x axis ASCII matrix:

  rows : the 24 axes registered by the repo
         (5 core-5 + 4 expansion-main + 15 sub-axes)
  cols : the same 24 axes
  cell : '.' empty (no cross)
         'X' exactly one cross spans this pair
         '*' two or more crosses span this pair

It also reports a coverage summary: # of axis-pair cells covered out of the
total upper-triangle pair count (C(24,2) = 276).

REPORTER, NOT ENFORCER (governance honesty)
-------------------------------------------
This script REPORTS the cross-axis topology that EXISTS on the host. It does
NOT claim every cell should be filled. Most pairs of axes are NOT meaningfully
crossable — e.g. NANOBOT x AUTAC, PEPTIDE x METALLODRUG share no common real-
limit anchor. Empty cells are HONEST. A bridge is added only when shared
mathematical structure or a shared real-limit anchor makes the cross
meaningful (AGENTS.tape g1 real-limits-first). The output explicitly states
this, so no reader can infer "100% would be better" from the coverage ratio.

GOVERNANCE (hexa-bio AGENTS.tape)
---------------------------------
  g1 real-limits-first  — coverage is reported HONESTLY (cells x cross-count),
     never inflated to a "should be 100%" target. A bridge counts only if its
     `_cross.py` file exists on disk; missing bridges are honest empty cells.
  g8 in-silico-only     — the matrix indexes axes that operate IN-SILICO. A
     cell mark verifies a bridge file exists and parses; it is NOT a
     therapeutic, clinical, regulatory, or efficacy claim about the axis
     intersection.
  reporter != enforcer  — this gate's sentinel PASSES iff at least one cross
     bridge is discoverable on the host. It never FAILs on "not enough cells".

DETERMINISM
-----------
Pure stdlib (no third-party imports). Pure file-system scan + string parsing
(no network / no random / no wall-clock). Re-running on the same repo state
produces byte-identical output.

No raw#N / own#N tokens. The matrix's reach is the cross files on disk; the
ceiling on cross-axis bridges is set by which axis pairs share a real-limit
anchor, not by any n=6 lattice scalar.

Usage:
    python3 selftest/cross_axis_matrix.py
    # exit 0 = at least one cross bridge discoverable on the host
    # exit 1 = no cross bridges discoverable (likely a misconfigured checkout)
"""
from __future__ import annotations

import glob
import os
import re
import sys

# ── repo layout ─────────────────────────────────────────────────────────
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PY_BRIDGE_MODULE = os.path.join(REPO_ROOT, "_python_bridge", "module")
CROSS_GLOB = os.path.join(PY_BRIDGE_MODULE, "*_cross.py")

# ── canonical axis registry (24 axes) ────────────────────────────────────
# Source of truth: AGENTS.tape core-5 + AXIS/HIERARCHY.tape expansion-main
# and sub-axes. Order is grouping-stable (core, then expansion-main, then
# subs grouped by parent) for predictable column headers in the matrix.
CORE_AXES = [
    "QUANTUM",
    "WEAVE",
    "NANOBOT",
    "RIBOZYME",
    "VIROCAPSID",
]

EXPANSION_MAIN_AXES = [
    "COVALENT",
    "BIFUNCTIONAL",
    "METALLODRUG",
    "OLIGONUCLEOTIDE",
]

# sub-axes (15) — grouped by parent for matrix readability
SUB_AXES = [
    # :> BIFUNCTIONAL (6)
    "PROTAC",
    "LYTAC",
    "AUTAC",
    "RIBOTAC",
    "COVALENT-DEGRADER",
    "MOLECULAR-GLUE",
    # :> QUANTUM (3) — placement-honesty tension flagged (HIERARCHY §2.6)
    "ALLOSTERIC",
    "CRYPTIC-POCKET",
    "PPI",
    # :> WEAVE (2)
    "PEPTIDE",
    "MACROCYCLE",
    # :> COVALENT (1)
    "REVERSIBLE-COVALENT",
    # :> RIBOZYME (2)
    "RNA-TARGETING-SMALL-MOLECULE",
    "APTAMER",
    # :> VIROCAPSID (1)
    "CAPSID-ASSEMBLY-MODULATOR",
]

AXES = CORE_AXES + EXPANSION_MAIN_AXES + SUB_AXES  # 5 + 4 + 15 = 24
AXIS_INDEX = {name: i for i, name in enumerate(AXES)}

# ── filename token -> canonical axis aliases ─────────────────────────────
# Map filename fragments (lowercased, underscore-joined) to a canonical axis
# id. Order matters for the longest-match tokenizer below — longer tokens
# come first so e.g. "capsid_modulator" wins over "modulator".
NAME_ALIASES = [
    # The longest-match list contains ONLY tokens that map to a SINGLE axis
    # whose canonical name itself spans multiple underscored words; we must
    # NOT lump cross-spanning composites here (e.g. "aptamer_nanobot") or
    # they'd consume two axes' worth of stem in a single substitution and
    # the second axis would never be detected. Order = longest token first.
    ("rna_targeting_small_molecule", "RNA-TARGETING-SMALL-MOLECULE"),
    ("rna_modality_comparison_smn2", "RNA-TARGETING-SMALL-MOLECULE"),
    ("capsid_assembly_modulator", "CAPSID-ASSEMBLY-MODULATOR"),
    # in cross filenames the sub-axis CAPSID-ASSEMBLY-MODULATOR is sometimes
    # abbreviated to "capsid_modulator" — register that abbreviation too.
    ("capsid_modulator", "CAPSID-ASSEMBLY-MODULATOR"),
    ("covalent_degrader", "COVALENT-DEGRADER"),
    ("reversible_covalent", "REVERSIBLE-COVALENT"),
    ("molecular_glue", "MOLECULAR-GLUE"),
    ("cryptic_pocket", "CRYPTIC-POCKET"),
    # single-token aliases (each maps to its own axis)
    ("quantum_vqe", "QUANTUM"),
    ("quantum", "QUANTUM"),
    ("weave", "WEAVE"),
    ("nanobot", "NANOBOT"),
    ("ribozyme", "RIBOZYME"),
    ("ribotac", "RIBOTAC"),
    ("virocapsid", "VIROCAPSID"),
    ("covalent", "COVALENT"),
    ("bifunctional", "BIFUNCTIONAL"),
    ("metallodrug", "METALLODRUG"),
    ("oligonucleotide", "OLIGONUCLEOTIDE"),
    ("protac", "PROTAC"),
    ("lytac", "LYTAC"),
    ("autac", "AUTAC"),
    ("allosteric", "ALLOSTERIC"),
    ("ppi", "PPI"),
    ("peptide", "PEPTIDE"),
    ("macrocycle", "MACROCYCLE"),
    ("aptamer", "APTAMER"),
]

# Docstring-axis hints — canonical (case-sensitive) axis names that appear
# inside cross-file docstrings. The filename-based extractor sometimes can't
# see one half of the cross (e.g. A4 capsid_modulator_pdb_anchor mentions
# VIROCAPSID only in prose; A2 oligonucleotide_offtarget_gencode mentions
# RIBOZYME only in prose; A5 reversible_covalent_mpro_vqe mentions QUANTUM
# only in prose). We union filename axes with docstring axes for full
# coverage. Order = longest first to avoid substring shadowing
# (e.g. CRYPTIC-POCKET would be a substring of "CRYPTIC POCKET sub-axis").
DOCSTRING_AXIS_TOKENS = sorted(
    AXES + [
        # explicit prose variants commonly used in headers
        "QUANTUM VQE",
        "QUANTUM-AXIS",
        "GENCODE",
    ],
    key=len,
    reverse=True,
)
# tokens that look like an axis name but are corpus / sister-module hints
# rather than the second axis of a cross — they must map back to a real axis.
DOCSTRING_ALIASES = {
    "QUANTUM VQE": "QUANTUM",
    "QUANTUM-AXIS": "QUANTUM",
    # GENCODE = RIBOZYME's vendored transcript corpus (per A2 cross prose)
    "GENCODE": "RIBOZYME",
}

# ── docstring "CROSS:" sniffer ───────────────────────────────────────────
# Used as a sanity cross-check: each cross file's docstring should mention
# both axes by canonical name. Empty docstrings are tolerated (filename rules).
def docstring_head(path):
    """Return the first ~8 KB of the file (lowercased) — enough to catch the
    `CROSS:` block of every cross file's header docstring."""
    try:
        with open(path, "r", encoding="utf-8") as fh:
            text = fh.read(8192)
    except OSError:
        return ""
    return text.lower()


def _extract_cross_block(text_lower):
    """Return ONLY the explicit `CROSS:` declaration block of the docstring.

    Most cross files start their header docstring with a literal
        CROSS:  AXIS_A  ===unify===  AXIS_B
                more prose on the next indented continuation line.
    We capture every such block — the CROSS: line plus any indented
    continuation lines that immediately follow — and return it
    concatenated. This is load-bearing: only the explicit declaration
    counts toward axis identification, NEVER governance / sister-module
    mentions elsewhere in the docstring (which would over-detect).

    Returns "" if no `cross:` line is found. The caller falls back to
    filename extraction and the manual override table below.
    """
    lines = text_lower.splitlines()
    block = []
    in_block = False
    for line in lines:
        stripped = line.lstrip()
        if not in_block:
            if stripped.startswith("cross:"):
                in_block = True
                block.append(stripped)
            continue
        if stripped == "":
            break
        if not line.startswith((" ", "\t")):
            break
        block.append(stripped)
    return "\n".join(block)


# Manual axis-pair override table — used when neither the filename nor the
# explicit `CROSS:` block names both axes. Source of truth: AXIS/HIERARCHY.tape
# §2.5 (A1-A5), §2.6 (F1-F3), §2.8 (G1-G5), §2.11 (J1-J3). We list ONLY the
# axes that the file's filename + CROSS: block fails to discover, so this
# table augments (never overrides) the auto-detected set.
MANUAL_AXIS_HINTS = {
    # filename basename -> additional canonical axes implied by HIERARCHY.tape
    # but not literally present in the filename / CROSS: block.
    "capsid_modulator_pdb_anchor_cross.py": ["VIROCAPSID"],
    "oligonucleotide_offtarget_gencode_cross.py": ["RIBOZYME"],
    "reversible_covalent_mpro_vqe_cross.py": ["QUANTUM"],
    "rna_modality_comparison_smn2_cross.py": ["OLIGONUCLEOTIDE"],
}


def docstring_axes(text_lower):
    """Scan ONLY the explicit `CROSS:` declaration block for canonical axis
    tokens and return the deduplicated list of axes in first-occurrence order.
    Tokens are matched word-bounded; longest-first walk avoids substring
    shadowing. If no `CROSS:` block is present (legacy bridge), returns []
    and the caller falls back to filename extraction."""
    block = _extract_cross_block(text_lower)
    if not block:
        return []
    found = []
    seen = set()
    for tok in DOCSTRING_AXIS_TOKENS:
        needle = tok.lower()
        pattern = r"(?<![A-Za-z0-9-])" + re.escape(needle) + r"(?![A-Za-z0-9-])"
        m = re.search(pattern, block)
        if m:
            axis = DOCSTRING_ALIASES.get(tok, tok)
            if axis in AXIS_INDEX and axis not in seen:
                found.append((m.start(), axis))
                seen.add(axis)
    found.sort(key=lambda p: p[0])
    return [a for _, a in found]


# ── cross-label sniffer ──────────────────────────────────────────────────
# Each cross file declares a project label in its docstring (e.g.
# "CROSS-AXIS integration G2", "CROSS-AXIS A4", "Project A3", "Project G4").
# Pull it out for the matrix legend; never load-bearing — pure annotation.
LABEL_RE = re.compile(
    r"(?:cross[- ]axis(?:\s+integration)?\s+|project\s+)([A-Z]\d+)",
    re.IGNORECASE,
)

def sniff_label(text_lower):
    m = LABEL_RE.search(text_lower)
    if not m:
        return ""
    return m.group(1).upper()


# ── axis extractor (filename longest-match) ──────────────────────────────
def extract_axes(filename):
    """Return the ordered, de-duplicated list of canonical axes that the
    filename indicates. Strategy: walk NAME_ALIASES in declared order
    (longest fragments first) and, on each hit, consume that fragment from a
    working copy of the stem so a longer alias eats a substring before the
    shorter alias matches it. Output preserves discovery order."""
    stem = os.path.basename(filename)
    if stem.endswith("_cross.py"):
        stem = stem[: -len("_cross.py")]
    elif stem.endswith(".py"):
        stem = stem[:-3]
    working = "_" + stem.lower() + "_"

    found = []
    for token, axis in NAME_ALIASES:
        needle = "_" + token + "_"
        # repeatedly consume occurrences so an alias appearing twice is OK
        while needle in working:
            working = working.replace(needle, "_", 1)
            if axis not in found:
                found.append(axis)
    return found


# ── matrix renderer ──────────────────────────────────────────────────────
def abbreviate(name, width=8):
    """Trim axis name to `width` chars for column / row headers."""
    if len(name) <= width:
        return name.ljust(width)
    return name[:width]


def render_matrix(cells, axes):
    """Render the axis x axis matrix as a list of text rows.

    `cells[(i, j)]` is a list of bridge labels (e.g. ["G2"]) for the pair.
    Symbol legend:
      .  empty (no cross)
      X  one cross
      *  two or more crosses
    The diagonal is shown as '-' (a self-cross is not meaningful).
    """
    width = 8
    out = []

    # column header rows — print each column name vertically (8 chars stacked)
    name_pad = [abbreviate(a, width) for a in axes]
    # we print the matrix with row labels left, then each column as 2-char
    # cells (symbol + space). Print column abbreviations as a horizontal
    # header above the matrix.
    out.append("Row/Col axis legend (index : full name):")
    for i, a in enumerate(axes):
        kind = (
            "core" if a in CORE_AXES
            else "main" if a in EXPANSION_MAIN_AXES
            else "sub"
        )
        out.append(f"  {i:2d} [{kind:4s}]  {a}")
    out.append("")

    # header row: column indices (2-digit, right-aligned, space-separated)
    header_indices = "         " + " ".join(f"{j:2d}" for j in range(len(axes)))
    out.append(header_indices)
    out.append("         " + "-" * (3 * len(axes) - 1))

    for i, row_axis in enumerate(axes):
        row_label = f"{i:2d} {abbreviate(row_axis, width)} |"
        cells_row = []
        for j in range(len(axes)):
            if i == j:
                cells_row.append("- ")
                continue
            key = (min(i, j), max(i, j))
            labels = cells.get(key, [])
            if not labels:
                cells_row.append(". ")
            elif len(labels) == 1:
                cells_row.append("X ")
            else:
                cells_row.append("* ")
        out.append(row_label + " " + "".join(cells_row).rstrip())

    return out


# ── main ─────────────────────────────────────────────────────────────────
def main():
    print("cross_axis_matrix — hexa-bio cross-axis bridge REPORTER")
    print("  scans _python_bridge/module/*_cross.py, builds an axis x axis")
    print("  visual matrix, reports coverage. REPORTER, NOT ENFORCER.")
    print("  governance: g1 honest-coverage · g8 in-silico-only")
    print()

    files = sorted(glob.glob(CROSS_GLOB))
    print(f"discovered {len(files)} cross file(s) under "
          f"_python_bridge/module/*_cross.py")
    if not files:
        print()
        print("  [SKIP] no cross files on host — nothing to report.")
        print()
        print("__CROSS_AXIS_MATRIX__ FAIL")
        return 1

    # Build the (i, j) -> [labels] map; also collect per-file parse rows.
    cells = {}
    rows = []
    unrecognized_axes = []
    multi_axis_bridges = []
    for path in files:
        text_lower = docstring_head(path)
        label = sniff_label(text_lower) or "?"
        fn_axes = extract_axes(path)
        ds_axes = docstring_axes(text_lower)
        manual = MANUAL_AXIS_HINTS.get(os.path.basename(path), [])
        # union in stable order: filename first (most reliable), then
        # explicit-CROSS-block docstring axes, then manual HIERARCHY.tape
        # overrides for files whose second axis is not in either.
        axes_found = list(fn_axes)
        for a in ds_axes:
            if a not in axes_found:
                axes_found.append(a)
        for a in manual:
            if a not in axes_found:
                axes_found.append(a)
        rows.append({
            "file": os.path.basename(path),
            "label": label,
            "axes": axes_found,
            "from_filename": fn_axes,
            "from_docstring": ds_axes,
            "from_manual": manual,
        })
        # validate
        bad = [a for a in axes_found if a not in AXIS_INDEX]
        if bad:
            unrecognized_axes.append((os.path.basename(path), bad))
            continue
        if len(axes_found) >= 3:
            multi_axis_bridges.append((os.path.basename(path), axes_found))
        if len(axes_found) < 2:
            # honest: bridge file present but axis pair unparseable
            continue
        # mark every unordered pair the bridge spans (handles 3-axis case)
        for a in range(len(axes_found)):
            for b in range(a + 1, len(axes_found)):
                ia = AXIS_INDEX[axes_found[a]]
                ib = AXIS_INDEX[axes_found[b]]
                key = (min(ia, ib), max(ia, ib))
                cells.setdefault(key, []).append(
                    f"{label}:{os.path.basename(path)}")

    # ── per-file parse report ────────────────────────────────────────────
    print()
    print("── per-file cross parse " + "─" * 60)
    for r in rows:
        axes_str = " x ".join(r["axes"]) if r["axes"] else "(unparsed)"
        print(f"  [{r['label']:<3}]  {r['file']:<54}  ->  {axes_str}")

    if unrecognized_axes:
        print()
        print("  honest parse-warning — unrecognized axis token(s):")
        for fname, bad in unrecognized_axes:
            print(f"    {fname}: {bad}")

    if multi_axis_bridges:
        print()
        print("  multi-axis bridges (>2 axes — each pair marked):")
        for fname, ax in multi_axis_bridges:
            print(f"    {fname}: {ax}")

    # ── matrix ───────────────────────────────────────────────────────────
    print()
    print("── axis x axis matrix " + "─" * 60)
    print("  symbols:  .  empty (no cross)   X  one cross   "
          "*  two or more crosses   -  self (diagonal)")
    print()
    for line in render_matrix(cells, AXES):
        print(line)

    # ── per-cell roster (which file fills which pair) ────────────────────
    print()
    print("── per-cell bridge roster " + "─" * 60)
    if not cells:
        print("  (no pairs marked — no bridges parsed successfully)")
    else:
        for (ia, ib), labels in sorted(cells.items()):
            a_name = AXES[ia]
            b_name = AXES[ib]
            label_str = ", ".join(labels)
            print(f"  {a_name}  x  {b_name}")
            for lab in labels:
                print(f"      {lab}")

    # ── coverage summary ─────────────────────────────────────────────────
    n_axes = len(AXES)
    n_possible = n_axes * (n_axes - 1) // 2   # upper-triangle pairs
    n_covered = len(cells)
    n_bridges = sum(len(v) for v in cells.values())
    coverage_pct = (100.0 * n_covered / n_possible) if n_possible else 0.0

    print()
    print("── coverage summary " + "─" * 60)
    print(f"  axes registered      : {n_axes} "
          f"(5 core + 4 expansion-main + 15 sub)")
    print(f"  possible axis pairs  : {n_possible} "
          f"(upper triangle, diagonal excluded)")
    print(f"  cross files on host  : {len(files)}")
    print(f"  pair-cells covered   : {n_covered}")
    print(f"  total pair-marks     : {n_bridges} "
          f"(may exceed cells if a pair has > 1 bridge or a 3-axis bridge "
          f"contributes 3 pairs)")
    print(f"  coverage ratio       : {n_covered}/{n_possible} "
          f"= {coverage_pct:.1f}%")
    print()
    print("  HONESTY (g1, reporter != enforcer): coverage is a DESCRIPTIVE")
    print("  count of which axis pairs currently have a bridge file on disk.")
    print("  It is NOT a target. Most of the 276 axis pairs are NOT")
    print("  meaningfully crossable — e.g. NANOBOT x AUTAC, PEPTIDE x")
    print("  METALLODRUG share no common real-limit anchor. A bridge is")
    print("  added only when shared mathematical structure or a shared")
    print("  real-limit anchor makes the cross honest. Empty cells are")
    print("  HONEST; this script never claims '100% would be better'.")
    print()
    print("  HONESTY (g8, in-silico scope): a marked cell verifies a bridge")
    print("  file exists and its axis pair parses. It is NOT a therapeutic,")
    print("  clinical, regulatory, immunogenic, or efficacy claim about the")
    print("  axis intersection. No n=6 lattice arithmetic is invoked.")
    print()

    # sentinel: PASS iff at least one cross file is discoverable AND at
    # least one pair-cell was successfully parsed.
    ok = n_bridges >= 1
    if ok:
        print("__CROSS_AXIS_MATRIX__ PASS")
        return 0
    print("__CROSS_AXIS_MATRIX__ FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(main())
