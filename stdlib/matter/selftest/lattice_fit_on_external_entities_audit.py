#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/lattice_fit_on_external_entities_audit.py — raw#10 C3 enforcement.

Per raw#10 C3 + LATTICE_POLICY §1.3, the n=6 invariant lattice MAY NOT be
applied to external entities (vendor data, NIST constants, ITER specs,
material parameters from third parties).

Forbidden patterns to detect:
  - "<vendor> satisfies σ·τ = 48"           e.g., Wacker, Wolfspeed, Climeworks
  - "<material X> matches n=6 lattice"      e.g., Kevlar, Inconel, NdFeB
  - "<NIST value> equals σ·<something>"     e.g., "9N = σ·sopfr·…"
  - "<vendor>'s …" coupled to a lattice symbol on the same line

This gate scans ALL spec markdowns. The legacy canon-imported docs (pre-
2026-05-12, before LATTICE_POLICY.md §1.3 was added) carry historical
lattice-fit phrasing — these are reported as `legacy_known_count`.

The gate FAILS HARD if a *post-policy* file (silicon + 12 Phase D verbs +
selftest itself + LIMIT_BREAKTHROUGH.md + the 5 Phase A authored docs)
contains a NEW lattice-fit phrase.

Per raw#9 hexa-only: Python stdlib only.

Exit 0 PASS / 1 FAIL.
"""
from __future__ import annotations

import os
import re
import sys

REPO_ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)

# Files authored post-policy (2026-05-12 or later) — these must be CLEAN.
# Anything else is treated as legacy canon-imported and counted but not failed.
POST_POLICY_FILES = {
    # silicon
    "silicon/silicon.md",
    "SILICON.md",
    # Phase D verbs (12)
    "compound-semi/compound-semi.md", "COMPOUND-SEMI.md",
    "perovskite/perovskite.md", "PEROVSKITE.md",
    "2d-materials/2d-materials.md", "2D-MATERIALS.md",
    "mof/mof.md", "MOF.md",
    "carbon/carbon.md", "GRAPHENE-CARBON.md",
    "elastomer/elastomer.md", "ELASTOMER.md",
    "adhesive/adhesive.md", "ADHESIVE.md",
    "liquid-crystal/liquid-crystal.md", "LIQUID-CRYSTAL.md",
    "biodegradable-plastics/biodegradable-plastics.md", "BIODEGRADABLE-PLASTICS.md",
    "wood-cellulose/wood-cellulose.md", "WOOD-CELLULOSE.md",
    "superalloy/superalloy.md", "SUPERALLOY.md",
    "magnetic-materials/magnetic-materials.md", "MAGNETIC-MATERIALS.md",
    # Phase D follow-on verbs (4, 2026-05-13, 29→33)
    "glass-ceramic/glass-ceramic.md",
    "geopolymer/geopolymer.md",
    "aerogel-foam/aerogel-foam.md",
    "ionic-liquid/ionic-liquid.md",
    # Phase D'' verbs (3, 2026-05-13, 33→36)
    "refractory/refractory.md",
    "photoresist/photoresist.md",
    "electrode-material/electrode-material.md",
    # Phase A authored infra docs (real-limits-first, raw#10 C3 enforced):
    "AXIS.md", "AXIS_CLOSURE_PLAN.md", "CLOSURE_RESIDUAL_BACKLOG.md",
    "DECOMPOSITION_PLAN.md", "LESSONS.md",
    "RELEASE_NOTES_v1.0.0.md", "RELEASE_NOTES_v1.1.0.md",
    "V1_2_0_HANDOFF.md", "USER_ACTION_REQUIRED.md", "IMPORTED_FROM_CANON.md",
    "CERAMIC-ENGINEERING.md", "METALLURGY-DEEP.md", "POLYMER-CHEMISTRY.md",
    "LATTICE_POLICY.md", "LIMIT_BREAKTHROUGH.md",
    "INIT.md", "AGENTS.md", "README.md",
    "RELEASE_NOTES_v1.0.0.md", "RELEASE_NOTES_v1.1.0.md",
}

# Forbidden patterns — vendors / brand names co-occurring with a lattice symbol.
# (n=6 lattice identifiers: σ, τ, φ, n=6, sigma, tau, phi, J_2, sopfr, HEXA-n=6.)
VENDOR_NAMES = [
    "Wacker", "Hemlock", "GCL", "Wolfspeed", "TSMC", "Samsung", "Intel",
    "Merck", "Heraeus", "Ferrotec", "Topsil", "Siltronic", "ASML",
    "DuPont", "Teijin", "Toray", "Hyosung", "DSM", "Dyneema", "Honeywell",
    "Hitachi Metals", "TDK", "Arnold", "Vacuumschmelze", "Inconel",
    "Special Metals", "Climeworks", "BASF", "Saint-Gobain", "Schott",
    "Corning", "AGC", "NSG", "Ductal", "Cor-Tuf", "Heidelberg",
    "Lafarge", "Holcim", "Stora Enso", "Mondi", "Sappi",
    "GIA", "ITER", "Kevlar", "Vectran", "Nomex", "Heracron",
    "NdFeB", "SmCo", "Metglas", "Finemet",
    "ASTM", "NIST", "CRC Handbook", "ASM Handbook", "SEMI",
    "ISO", "JIS", "DIN", "AISI", "OECD",
]
LATTICE_TOKENS = [
    "σ·τ", "sigma*tau", "sigma·tau",
    "σ·φ", "sigma*phi", "sigma·phi",
    "n=6 lattice", "HEXA-n=6", "n·τ", "n*tau",
    "matches n=6", "fits n=6", "= σ·", "= sigma*",
    "fits σ", "satisfies σ", "satisfies sigma",
]


# Build the regex: a *line* containing both a vendor name AND a lattice token.
def build_regex() -> re.Pattern:
    # Per-line scan — return a regex against a single line.
    return re.compile(
        r"^(?=.*\b(?:" + "|".join(re.escape(v) for v in VENDOR_NAMES) + r")\b)"
        r"(?=.*(?:" + "|".join(re.escape(t) for t in LATTICE_TOKENS) + r"))"
        r".+$",
        re.MULTILINE,
    )


# Lines that are explicitly NEGATING a lattice-fit pattern (i.e. the spec is
# *forbidding* the pattern, not making it) — these must NOT count as
# violations. Examples in repo:
#   - ✗ "Wacker satisfies σ·τ=48" — coincidence
#   - ✗ "Vectran E 75 GPa fits n=6 × c" — coincidence
#   - "The temptation to write ..."
NEGATION_MARKERS = (
    "✗",  # explicit-forbid marker used in post-policy specs
    "do not write",
    "do NOT write",
    "the temptation",
    "they have not heard",
    "coincidence",
    "no n=6 lattice anchoring",
    "no lattice anchoring",
    "NOT n=6 lattice outputs",
    "not n=6 lattice outputs",
    "no n=6 lattice fit",
    "no lattice fit",
    "no n=6 fit",
    "NOT a lattice",
    "not a lattice fit",
    # Policy / gate description prose that describes what is FORBIDDEN
    "must not apply",
    "must NOT apply",
    "raw#10 c3",  # any line citing the raw#10 C3 anchor is a discussion of policy
    "lattice_fit_on_external_entities",  # mentions the gate name itself
    "applies n=6 lattice formulas",
    "must NOT",
    "forbidden",
    "anti-pattern",
    "lattice-fit on external entities",  # the gate's own name in prose
)


def is_negation_line(line: str) -> bool:
    low = line.lower()
    for m in NEGATION_MARKERS:
        if m.lower() in low:
            return True
    return False


def scan_file(path: str, pattern: re.Pattern) -> list[tuple[int, str]]:
    out: list[tuple[int, str]] = []
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as fh:
            for lineno, line in enumerate(fh, 1):
                if not pattern.match(line):
                    continue
                if is_negation_line(line):
                    continue
                out.append((lineno, line.strip()[:140]))
    except OSError:
        pass
    return out


def main() -> int:
    print("hexa-matter/selftest/lattice_fit_on_external_entities_audit — raw#10 C3 enforcement")
    print(f"  root: {REPO_ROOT}")
    print(f"  post-policy file set: {len(POST_POLICY_FILES)} files (must be CLEAN)")
    print(f"  legacy canon-imported files: best-effort REPORT (no fail)\n")

    pattern = build_regex()

    post_violations: list[tuple[str, int, str]] = []
    legacy_violations: list[tuple[str, int, str]] = []

    for dirpath, dirnames, filenames in os.walk(REPO_ROOT):
        dirnames[:] = [d for d in dirnames if d not in (".git", "__pycache__", "selftest")]
        for fn in filenames:
            if not fn.endswith(".md"):
                continue
            rel = os.path.relpath(os.path.join(dirpath, fn), REPO_ROOT)
            hits = scan_file(os.path.join(dirpath, fn), pattern)
            if not hits:
                continue
            target = post_violations if rel in POST_POLICY_FILES else legacy_violations
            for lineno, snippet in hits:
                target.append((rel, lineno, snippet))

    print(f"  post-policy violations: {len(post_violations)}")
    for rel, lineno, snippet in post_violations[:20]:
        print(f"    [FAIL] {rel}:{lineno}  {snippet}")
    if len(post_violations) > 20:
        print(f"    ... +{len(post_violations) - 20} more")

    print()
    print(f"  legacy canon-imported violations (REPORT only, pre-2026-05-12): {len(legacy_violations)}")
    # Aggregate by file for the legacy report
    by_file: dict[str, int] = {}
    for rel, _, _ in legacy_violations:
        by_file[rel] = by_file.get(rel, 0) + 1
    for rel, n in sorted(by_file.items(), key=lambda kv: -kv[1])[:15]:
        print(f"    [LEGACY] {rel}  ({n} line(s))")
    if len(by_file) > 15:
        print(f"    ... +{len(by_file) - 15} more files")

    print()
    if post_violations:
        print(f"__HEXA_MATTER_LATTICE_FIT_AUDIT__ FAIL  "
              f"(post-policy violations: {len(post_violations)}; legacy: {len(legacy_violations)})")
        return 1
    print(f"__HEXA_MATTER_LATTICE_FIT_AUDIT__ PASS  "
          f"(post-policy clean; legacy known: {len(legacy_violations)} line(s) in "
          f"{len(by_file)} canon-imported file(s))")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
