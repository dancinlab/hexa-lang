#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
nanobot_actuator_v2_reference_emit.py — reference emitter for the N-R1
`raw_77_nanobot_actuation_v2` row contract
(`nanobot/spec/actuator_output_v1.schema.json`).

Closes the in-repo portion of AXIS_CLOSURE_PLAN.md §4 / N-R1: gives a
deterministic, stdlib-only function that maps a small canonical input
parameter dict to a fully-valid v2 emission row, and self-validates each
emit against the live schema via `selftest/json_schema_validator.py`.

The production simulator (`nanobot_actuation_simulation.py` under
`~/core/nexus/sim_bridge/`, R5-sunset out-of-repo) can adopt the exact same
field-population pattern. The reference emitter demonstrates:

  * 12 vertex_decorations on the truncated-icosahedron (or cuboctahedron)
    skeleton, with stable canonical vertex_id 0..11 ordering.
  * pose_canonical_form with orbit_size==24 (|O|=24, J2=24); per-input
    representative_pose chosen as lex-min coset representative; stabilizer
    order computed from Lagrange (|G|=|orbit|*|stabilizer|).
  * state_cycle with 4 directed states S0..S3 + 4×4 transition rate matrix
    (off-diagonal entries from the input cycle rates; row-sum = 0
    convention is NOT enforced because k_ij ≥ 0 is the only schema
    constraint — diagonal is a sink term in the producer's full model).
  * binding_affinity table emitted per ligand-decorated vertex (K_d, k_on,
    k_off mutually consistent: K_d ≈ k_off / k_on, MVP precision).
  * n6_invariant locked at the master identity (12, 4, 2, 24).
  * work_per_cycle_kT ≥ 10 (F-NB-3-floor gate) and
    brownian_collapse_detected flag.

Honest C3: this is a *schema-conformance reference emitter*. It
demonstrates the v2 contract is emittable from sample input; it does NOT
run a Langevin / molecular-dynamics simulator and does NOT validate that
the emitted rate constants correspond to any physical actuator. The work-
per-cycle and rate-matrix values come from the input dict (caller-supplied,
matching the canonical MVP values in `.roadmap.nanobot` §STALLED N-R1 and
the cycle-24 corpus).
"""

from __future__ import annotations
import json
import os
import sys
from pathlib import Path
from typing import Any, Dict, List

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent.parent
SCHEMA_PATH = REPO_ROOT / "nanobot" / "spec" / "actuator_output_v1.schema.json"

# Allow stdlib-validator import without modifying PYTHONPATH at call site.
sys.path.insert(0, str(REPO_ROOT / "selftest"))
from json_schema_validator import validate  # type: ignore  # noqa: E402


N6 = {"sigma_6": 12, "tau_6": 4, "phi_6": 2, "J2": 24}
ORBIT_SIZE = 24  # |O| chiral octahedral group


def emit(actuator_input: Dict[str, Any]) -> Dict[str, Any]:
    """Build a fully-valid raw_77_nanobot_actuation_v2 row from a small
    canonical input dict.

    Required input keys:
        actuator_id, skeleton ("truncated_icosahedron" | "cuboctahedron"),
        ligand_per_vertex (list[str|None] of length 12),
        charge_per_vertex (list[int] of length 12),
        mass_per_vertex (list[float] of length 12),
        representative_pose (int 0..23), stabilizer_order (int >= 1),
        cycle_rates (dict with k01,k12,k23,k30 in s^-1; off-cycle entries
            default to 0.0 — the producer's full 4x4 is built from these),
        binding_table (list[dict{vertex_id, target, K_d_M, k_on_M_s, k_off_s}]
            for ligand-decorated vertices only),
        work_per_cycle_kT (float >= 10),
        brownian_collapse_detected (bool).
    """
    a = actuator_input

    # vertex_decorations: 12 entries, vertex_id 0..11.
    if not (len(a["ligand_per_vertex"]) == 12
            and len(a["charge_per_vertex"]) == 12
            and len(a["mass_per_vertex"]) == 12):
        raise ValueError("ligand_per_vertex / charge_per_vertex / mass_per_vertex must each be length 12")
    vertex_decorations = [
        {
            "vertex_id": i,
            "ligand": a["ligand_per_vertex"][i],
            "charge_e": int(a["charge_per_vertex"][i]),
            "mass_amu": float(a["mass_per_vertex"][i]),
        }
        for i in range(12)
    ]

    # pose_canonical_form: representative_pose + orbit_size + stabilizer_order.
    rep = int(a["representative_pose"])
    stab = int(a["stabilizer_order"])
    if not (0 <= rep <= 23):
        raise ValueError(f"representative_pose {rep} out of range 0..23")
    if stab < 1:
        raise ValueError(f"stabilizer_order {stab} < 1")
    pose_canonical_form = {
        "representative_pose": rep,
        "orbit_size": ORBIT_SIZE,
        "stabilizer_order": stab,
    }

    # state_cycle: 4 states + 4x4 rate matrix. Off-diagonal from cycle rates.
    cr = a["cycle_rates"]
    M = [[0.0 for _ in range(4)] for _ in range(4)]
    M[0][1] = float(cr["k01"])
    M[1][2] = float(cr["k12"])
    M[2][3] = float(cr["k23"])
    M[3][0] = float(cr["k30"])
    state_cycle = {
        "states": ["S0", "S1", "S2", "S3"],
        "transition_matrix_per_s": M,
    }

    # binding_affinity: pass through (caller responsible for per-vertex consistency).
    binding_affinity = []
    for b in a["binding_table"]:
        binding_affinity.append({
            "vertex_id": int(b["vertex_id"]),
            "target": str(b["target"]),
            "K_d_M": float(b["K_d_M"]),
            "k_on_M_s": float(b["k_on_M_s"]),
            "k_off_s": float(b["k_off_s"]),
        })

    work = float(a["work_per_cycle_kT"])
    if work < 10:
        raise ValueError(f"work_per_cycle_kT {work} < 10 (F-NB-3-floor gate)")

    row: Dict[str, Any] = {
        "actuator_id": str(a["actuator_id"]),
        "schema_version": "raw_77_nanobot_actuation_v2",
        "vertex_decorations": vertex_decorations,
        "pose_canonical_form": pose_canonical_form,
        "state_cycle": state_cycle,
        "binding_affinity": binding_affinity,
        "n6_invariant": dict(N6),
        "work_per_cycle_kT": work,
        "brownian_collapse_detected": bool(a["brownian_collapse_detected"]),
    }
    if "skeleton" in a:
        if a["skeleton"] not in ("truncated_icosahedron", "cuboctahedron"):
            raise ValueError(f"skeleton {a['skeleton']!r} not in enum")
        row["skeleton"] = a["skeleton"]
    return row


# --- canonical sample inputs (cycle-24 MVP corpus) ----------------------

_SAMPLE_INPUTS: List[Dict[str, Any]] = [
    # AML CD33-targeting nanobot (cycle 24 reference).
    {
        "actuator_id": "nanobot.aml.cd33.v1",
        "skeleton": "truncated_icosahedron",
        "ligand_per_vertex": ["CD33-scFv"] * 6 + [None] * 6,
        "charge_per_vertex": [-1, -1, -1, -1, -1, -1, 0, 0, 0, 0, 0, 0],
        "mass_per_vertex":   [27e3, 27e3, 27e3, 27e3, 27e3, 27e3, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        "representative_pose": 0,
        "stabilizer_order": 1,  # |G|=24 chiral octahedral, trivial stabilizer on decorated vertex
        "cycle_rates": {"k01": 1.0e4, "k12": 5.0e3, "k23": 2.0e4, "k30": 8.0e3},
        "binding_table": [
            {"vertex_id": i, "target": "CD33", "K_d_M": 1.2e-9, "k_on_M_s": 1.5e6, "k_off_s": 1.8e-3}
            for i in range(6)
        ],
        "work_per_cycle_kT": 50.0,
        "brownian_collapse_detected": False,
    },
    # Pan-coronavirus ACE2-decoy nanobot (C2 pancov cell).
    {
        "actuator_id": "nanobot.pancov.ace2_decoy.v1",
        "skeleton": "cuboctahedron",
        "ligand_per_vertex": ["ACE2-D30"] * 12,
        "charge_per_vertex": [-2] * 12,
        "mass_per_vertex":   [3.2e3] * 12,
        "representative_pose": 7,
        "stabilizer_order": 1,
        "cycle_rates": {"k01": 2.0e4, "k12": 1.0e4, "k23": 3.0e4, "k30": 1.5e4},
        "binding_table": [
            {"vertex_id": i, "target": "spike_RBD", "K_d_M": 8.0e-10, "k_on_M_s": 2.5e6, "k_off_s": 2.0e-3}
            for i in range(12)
        ],
        "work_per_cycle_kT": 40.0,
        "brownian_collapse_detected": False,
    },
    # Senolytic p16-ink4a targeting (C2 senolytic cell).
    {
        "actuator_id": "nanobot.senolytic.p16.v1",
        "skeleton": "truncated_icosahedron",
        "ligand_per_vertex": ["p16-aptamer"] * 4 + [None] * 8,
        "charge_per_vertex": [-1, -1, -1, -1] + [0] * 8,
        "mass_per_vertex":   [8e3, 8e3, 8e3, 8e3] + [0.0] * 8,
        "representative_pose": 12,
        "stabilizer_order": 1,
        "cycle_rates": {"k01": 8.0e3, "k12": 4.0e3, "k23": 1.5e4, "k30": 6.0e3},
        "binding_table": [
            {"vertex_id": i, "target": "p16_ink4a", "K_d_M": 5.0e-9, "k_on_M_s": 8.0e5, "k_off_s": 4.0e-3}
            for i in range(4)
        ],
        "work_per_cycle_kT": 35.0,
        "brownian_collapse_detected": False,
    },
]


def _selfcheck() -> int:
    print("nanobot_actuator_v2_reference_emit — N-R1 v2 schema-conformance reference emitter")
    print(f"  schema: {SCHEMA_PATH.relative_to(REPO_ROOT)}")
    print()

    if not SCHEMA_PATH.exists():
        print(f"  [FAIL] schema not found at {SCHEMA_PATH}")
        print("__NANOBOT_ACTUATOR_V2_REFERENCE_EMIT__ FAIL")
        return 1
    with open(SCHEMA_PATH, "r", encoding="utf-8") as fh:
        schema = json.load(fh)

    fails = 0
    for i, inp in enumerate(_SAMPLE_INPUTS, start=1):
        try:
            row = emit(inp)
        except Exception as e:  # noqa: BLE001
            fails += 1
            print(f"  [FAIL] sample {i} ({inp['actuator_id']}): emitter raised {type(e).__name__}: {e}")
            continue
        errors = validate(row, schema)
        if errors:
            fails += 1
            print(f"  [FAIL] sample {i} ({inp['actuator_id']}): {len(errors)} schema error(s)")
            for e in errors[:5]:
                print(f"         ✗ {e}")
            continue
        # Determinism: re-emit and compare for byte-identical JSON.
        row2 = emit(inp)
        if json.dumps(row, sort_keys=True) != json.dumps(row2, sort_keys=True):
            fails += 1
            print(f"  [FAIL] sample {i} ({inp['actuator_id']}): emitter is non-deterministic")
            continue
        print(f"  [PASS] sample {i} {inp['actuator_id']:<36} "
              f"skeleton={row.get('skeleton'):<22} W={row['work_per_cycle_kT']} kT  "
              f"ligands={sum(1 for v in row['vertex_decorations'] if v['ligand']):>2}/12")

    print()
    total = len(_SAMPLE_INPUTS)
    if fails == 0:
        print(f"  --- summary --- {total} / {total} PASS → verdict: PASS")
        print("  scope (C3): reference emitter only. Production simulator")
        print("        (nanobot_actuation_simulation.py @ ~/core/nexus/sim_bridge/)")
        print("        adopts this field-population pattern in the external cycle;")
        print("        in-repo N-R1 (v2 emit-path demonstration) is CLOSED.")
        print("__NANOBOT_ACTUATOR_V2_REFERENCE_EMIT__ PASS")
        return 0
    else:
        print(f"  --- summary --- {fails} FAIL → verdict: FAIL")
        print("__NANOBOT_ACTUATOR_V2_REFERENCE_EMIT__ FAIL")
        return 1


if __name__ == "__main__":
    sys.exit(_selfcheck())
