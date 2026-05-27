#!/usr/bin/env python3
"""
SSCB mk1 — BOM σ(6)=12 lattice reduction (atlas-anchored, circular-trap-free).

REWRITE 2026-05-07: pulls per-class BOM totals from atlas.append.hsscb-mk1-
vendor-anchors-2026-05-06.n6 (Section 7) instead of replicated 19-row table.
Compare to 2026-05-06 legacy: ENGPACK_BOM was inlined (circular-trap pattern,
ABOLISHED per hive/spec/no_self_referential_verification).

The σ(6)=12 lattice mapping is project-policy (9 active classes + 3 reserved
slots) and STAYS in this file — that's a structural assertion, not a value.
The values themselves come from the atlas anchor lookup.

Run:
    python3 verify/bom_lattice.py        # exit 0 = total ≤ $35 and 12 slots

Authority: own 1 (n=6 lattice identity); atlas.n6 @P sigma = 12 [11*]
master identity; atlas.append.hsscb-mk1-vendor-anchors §7 BOM-class entries.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from atlas_anchors import value_of  # noqa: E402

# σ(6)=12 lattice classes (atlas.n6 @P sigma=12 [11*] derived structure).
# This mapping is the design contract: 9 active + 3 reserved (sigma slack).
SIGMA_LATTICE = {
    "1.  SiC MOSFET die (matched 4-die set)":       "SiC",
    "2.  Gate driver BCD 180 nm":                   "Driver",
    "3.  Σ-Δ ADC + comparator":                     "ADC",
    "4.  MCU Cortex-M4 (commercial fallback)":      "MCU",
    "5.  TVS network":                              "TVS",
    "6.  RC snubber":                               "Snubber",
    "7.  DBC ceramic substrate":                    "DBC",
    "8.  Sintered die-attach + wirebond + mold":    "Package",
    "9.  Shunt + sense + passives + connector":     "Sense",
    "10. Reserved (sigma slack #1)":                "Reserved",
    "11. Reserved (sigma slack #2)":                "Reserved",
    "12. Reserved (sigma slack #3)":                "Reserved",
}

# Active class → atlas anchor id (BOM totals live in atlas, not here).
CLASS_TO_ANCHOR = {
    "SiC":     "HSSCB-bom-class-SiC",
    "Driver":  "HSSCB-bom-class-Driver",
    "ADC":     "HSSCB-bom-class-ADC",
    "MCU":     "HSSCB-bom-class-MCU",
    "TVS":     "HSSCB-bom-class-TVS",
    "Snubber": "HSSCB-bom-class-Snubber",
    "DBC":     "HSSCB-bom-class-DBC",
    "Package": "HSSCB-bom-class-Package",
    "Sense":   "HSSCB-bom-class-Sense",
}

ACTIVE_CLASSES = tuple(CLASS_TO_ANCHOR.keys())


def reduce_to_lattice():
    """Return (per-class total USD, errors)."""
    errors = []
    if len(SIGMA_LATTICE) != 12:
        errors.append(f"σ(6) lattice has {len(SIGMA_LATTICE)} slots, expected 12")
    reserved = [s for s in SIGMA_LATTICE.values() if s == "Reserved"]
    if len(reserved) != 3:
        errors.append(f"reserved slots = {len(reserved)}, expected 3")
    active = [s for s in SIGMA_LATTICE.values() if s != "Reserved"]
    if len(active) != 9:
        errors.append(f"active classes = {len(active)}, expected 9")

    totals = {}
    for cls, anchor_id in CLASS_TO_ANCHOR.items():
        try:
            totals[cls] = value_of(anchor_id)
        except KeyError as e:
            errors.append(f"{cls}: missing atlas anchor {anchor_id} ({e})")
            totals[cls] = 0.0
    return totals, errors


def main() -> int:
    print("=" * 72)
    print("  SSCB mk1 — BOM σ(6)=12 lattice (atlas-anchored, circular-trap-free)")
    print("=" * 72)
    totals, errors = reduce_to_lattice()
    grand = sum(totals.values())

    print()
    print("  σ(6)=12 lattice slots (spec.md §17 + atlas BOM-class anchors):")
    for slot in SIGMA_LATTICE:
        cls = SIGMA_LATTICE[slot]
        cost = totals.get(cls, 0.0) if cls != "Reserved" else 0.0
        marker = "  " if cls == "Reserved" else "→ "
        print(f"    {slot:<48} {marker}${cost:6.2f}")

    bom_ceiling = value_of("HSSCB-bom-ceiling")
    print()
    print(f"  Active 9-class subtotal : ${grand:6.2f}")
    print(f"  Reserved 3-slot budget  : $ 0.00 (mk1 ships empty)")
    print(f"  σ(6)=12 grand total     : ${grand:6.2f}")
    print(f"  Ceiling (atlas anchor)  : ${bom_ceiling:6.2f}")
    print()

    if grand > bom_ceiling:
        errors.append(f"BOM total ${grand:.2f} > ceiling ${bom_ceiling:.2f}")

    # Cross-check: atlas grand-total anchor must equal sum of class anchors.
    declared_total = value_of("HSSCB-bom-grand-total")
    if abs(declared_total - grand) > 0.01:
        errors.append(
            f"atlas HSSCB-bom-grand-total ${declared_total:.2f} != "
            f"sum of class anchors ${grand:.2f} (atlas internal drift)"
        )

    if errors:
        print("  FAILURES:")
        for e in errors:
            print(f"    ✗ {e}")
        return 1
    print(f"  PASS — σ(6)=12 atlas BOM lattice closes ${grand:.2f} ≤ ${bom_ceiling:.2f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
