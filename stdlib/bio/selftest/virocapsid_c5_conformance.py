#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
virocapsid_c5_conformance.py — 4-cell conformance witness validator for the
GATE-26-V-R1 (C5) cage_output_v1.schema.json lock (AXIS_CLOSURE_PLAN.md §5).

Validates the four locked example fixtures against the (now field-set-frozen)
cage_output_v1.schema.json using the project's own stdlib JSON Schema
validator (`selftest/json_schema_validator.py`). Sentinel:
`__VIROCAPSID_C5_CONFORMANCE__ PASS` on full PASS, FAIL otherwise.

Scope (honest C3): this script proves *schema conformance* of the four
example instances. It does NOT run the Zlotnick ODE, does NOT compute live
yield curves, and does NOT validate the rate constants against any wet-lab
or RCSB target. Live witness emission (running simulator → registry.jsonl
rows) remains out-of-repo per R5 sunset (~/core/nexus/sim_bridge/). This
script closes the in-repo portion of C5 (schema lock + 4-cell example
validation); the out-of-repo portion (live emission across the 4 cells) is
tracked separately.
"""

from __future__ import annotations
import json
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent
SCHEMA_PATH = REPO_ROOT / "virocapsid" / "spec" / "cage_output_v1.schema.json"
FIXTURES_DIR = REPO_ROOT / "virocapsid" / "spec" / "examples"

# Load the project's own validator (stdlib-only, draft-07 subset).
sys.path.insert(0, str(HERE))
from json_schema_validator import validate  # type: ignore  # noqa: E402

EXPECTED_CELLS = ("aml", "scd", "pancov", "senolytic")


def main() -> int:
    print("virocapsid_c5_conformance — 4-cell cage_output_v0 schema conformance")
    print(f"  schema:  {SCHEMA_PATH.relative_to(REPO_ROOT)}")
    print(f"  fixtures: {FIXTURES_DIR.relative_to(REPO_ROOT)}/")
    print()

    if not SCHEMA_PATH.exists():
        print(f"  [FAIL] schema not found at {SCHEMA_PATH}")
        print("__VIROCAPSID_C5_CONFORMANCE__ FAIL")
        return 1

    with open(SCHEMA_PATH, "r", encoding="utf-8") as fh:
        schema = json.load(fh)

    # Confirm lock metadata is present (the C5 deliverable is schema-lock + 4 fixtures).
    lock_meta = schema.get("lock_metadata")
    if not lock_meta or not lock_meta.get("field_set_frozen"):
        print("  [FAIL] schema missing lock_metadata.field_set_frozen=true (C5 lock not declared)")
        print("__VIROCAPSID_C5_CONFORMANCE__ FAIL")
        return 1
    print(f"  [PASS] lock_metadata.field_set_frozen=true  ({lock_meta['locked_date']}, "
          f"ahead of {lock_meta['deadline_original']} by {lock_meta['ahead_of_deadline_by_days']} days)")

    # Validate each fixture.
    fails = 0
    for cell in EXPECTED_CELLS:
        path = FIXTURES_DIR / f"cage_output_v0__{cell}.json"
        if not path.exists():
            print(f"  [FAIL] {cell}: fixture missing at {path.relative_to(REPO_ROOT)}")
            fails += 1
            continue
        with open(path, "r", encoding="utf-8") as fh:
            instance = json.load(fh)
        errors = validate(instance, schema)
        if errors:
            fails += 1
            print(f"  [FAIL] {cell}: {len(errors)} error(s)")
            for e in errors[:5]:
                print(f"         ✗ {e}")
            continue
        # Per-cell sanity (deductive only — no claim about therapeutic efficacy):
        last_y = instance["yield_curve"]["y_closed"][-1]
        assert last_y >= 0.85, f"{cell}: y_closed[-1]={last_y} < 0.85"
        v = instance["vertex_count"]
        T = instance["t_number"]
        subs = instance["subunit_count"]
        assert v == 12, f"{cell}: vertex_count {v} != 12 (Euler V−E+F=2)"
        assert subs == 60 * T, f"{cell}: subunit_count {subs} != 60*T={60 * T}"
        print(f"  [PASS] {cell:<10} T={T}  subunits={subs}  vertices={v}  "
              f"y_closed[-1]={last_y:.3f}  k_constants={list(instance['assembly_kinetics']['rate_constants'])}")

    print()
    total = len(EXPECTED_CELLS) + 1  # 4 cells + 1 lock-metadata check
    passed = total - fails
    if fails == 0:
        print(f"  --- summary --- {passed} / {total} PASS → verdict: PASS")
        print("  scope (C3): schema-conformance only. Live witness emission")
        print("        (running simulator → registry.jsonl) remains out-of-repo")
        print("        (R5 sunset → ~/core/nexus/sim_bridge/). C5 in-repo portion")
        print("        (schema lock + 4-cell example validation) is CLOSED.")
        print("__VIROCAPSID_C5_CONFORMANCE__ PASS")
        return 0
    else:
        print(f"  --- summary --- {fails} FAIL → verdict: FAIL")
        print("__VIROCAPSID_C5_CONFORMANCE__ FAIL")
        return 1


if __name__ == "__main__":
    sys.exit(main())
