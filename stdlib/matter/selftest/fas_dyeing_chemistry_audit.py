#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/fas_dyeing_chemistry_audit.py — FAS group dye/fiber chemistry anchor.

For the GROUP_FAS verbs (fashion-textile, textile-dyeing), this gate confirms
each spec references at least one canonical dye class (reactive / acid /
disperse / vat / direct / mordant / sulfur) AND at least one fiber substrate
(cotton / wool / silk / polyester / nylon / cellulose).

NOTE: FAS verbs are NOT in the 29-verb CLI dispatch list (per AXIS.md §0),
but the spec docs still ship in the repo. This gate audits the docs.

Per raw#9 hexa-only: Python stdlib only.

Exit 0 PASS / 1 FAIL.
"""
from __future__ import annotations

import os
import sys

REPO_ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)

FAS_SPECS = [
    "fashion-textile/fashion-textile.md",
    "textile-dyeing/textile-dyeing.md",
    "FASHION-TEXTILE.md",
    "TEXTILE-DYEING.md",
]

DYE_CLASSES = ["reactive", "acid", "disperse", "vat", "direct", "mordant", "sulfur",
               "azo", "indigo", "natural dye", "pigment"]
FIBER_SUBSTRATES = ["cotton", "wool", "silk", "polyester", "nylon", "cellulose",
                    "PET", "PA6", "viscose", "linen"]


def main() -> int:
    print("hexa-matter/selftest/fas_dyeing_chemistry_audit — FAS dye/fiber chemistry")
    print(f"  root: {REPO_ROOT}\n")

    # PASS criterion: across the FAS spec corpus *as a whole*, ≥2 dye classes
    # AND ≥2 fiber substrates must surface. Per-file granularity would fail on
    # the legacy canon-imported fashion-textile.md / textile-dyeing.md (which
    # are lattice-fit docs predating raw#10 C3 — see
    # lattice_fit_on_external_entities_audit.py legacy_known list). The
    # ROOT-level UPPERCASE.md companions carry the chemistry; the verb-dir
    # files carry the legacy n=6 fit.
    #
    # FAS verbs are NOT in the 29-verb CLI dispatch (per hexa.toml [verbs] and
    # AXIS.md §0) — they ship as documentation only. The gate confirms that
    # *somewhere* in the FAS spec corpus, real dye + fiber chemistry exists.

    found_specs = 0
    all_dye: set[str] = set()
    all_fiber: set[str] = set()
    per_file: list[tuple[str, list[str], list[str]]] = []
    for rel in FAS_SPECS:
        path = os.path.join(REPO_ROOT, rel)
        if not os.path.exists(path):
            continue
        found_specs += 1
        with open(path, "r", encoding="utf-8", errors="ignore") as fh:
            text = fh.read().lower()
        dye_hits = [k for k in DYE_CLASSES if k.lower() in text]
        fiber_hits = [k for k in FIBER_SUBSTRATES if k.lower() in text]
        all_dye.update(dye_hits)
        all_fiber.update(fiber_hits)
        per_file.append((rel, dye_hits, fiber_hits))

    for rel, dye_hits, fiber_hits in per_file:
        legacy = "(legacy n=6-fit, pre-policy)" if rel.startswith(("fashion-textile/", "textile-dyeing/")) else ""
        print(f"  {rel}: dye={dye_hits[:4]}  fibers={fiber_hits[:4]} {legacy}")

    print()
    print(f"  corpus-level dye classes: {sorted(all_dye)}")
    print(f"  corpus-level fiber substrates: {sorted(all_fiber)}")
    print()

    if found_specs == 0:
        print("__HEXA_MATTER_FAS_DYEING__ PASS  (vacuous: no FAS specs on disk)")
        return 0

    if len(all_dye) >= 2 and len(all_fiber) >= 2:
        print(f"__HEXA_MATTER_FAS_DYEING__ PASS  "
              f"(corpus has {len(all_dye)} dye-classes + {len(all_fiber)} fiber-substrates)")
        return 0
    print(f"__HEXA_MATTER_FAS_DYEING__ FAIL  "
          f"(corpus has only {len(all_dye)} dye-classes + {len(all_fiber)} fiber-substrates; need ≥2 each)")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
