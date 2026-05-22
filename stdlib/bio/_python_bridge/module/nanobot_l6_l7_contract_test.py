#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
nanobot_l6_l7_contract_test.py — consumer-driven (Pact-style) contract test for the
N-R2 nanobot L6 → therapeutic-nanobot L7-L9 boundary.

Checks that hexa-bio's **L6 emission contract** (`raw_77_nanobot_l6_handoff_v1`,
`nanobot/spec/handoff_l6_emission_v0.schema.json` — now LOCKED v1.0.0) provides
every field that the **L7-L9 acceptance schemas** declare they consume from L6,
and that those declarations agree with the canon-side handoff JSON
(`raw_77_therapeutic_nanobot_l7_acceptance_v1`, vendored ref
`nanobot/spec/canon_l7_acceptance_handoff_ref.json` ← canon@mk1, DECLARED v1.0.0-stub).
The L7-L9 schemas themselves are hexa-bio's **consumer-proposed drafts** in
`nanobot/spec/proposed_l7_l9_witness_schemas/` (the §12-research consumer-driven /
Pact-style contract pattern) — the canon side adopts/edits, after which the
canonical copy lives at `canon/domains/life/therapeutic-nanobot/spec/`.

Closes the consumer-side of N-R2's contract verification:
  • L6 producer schema (hexa-bio) — LOCKED v1.0.0, `emission_blocked_until_schema_lock=false`.
  • L7-L9 consumer schemas — drafted in-repo; each `consumed_from_l6` ⊆ {L6 emission fields}.
  • canon handoff JSON `consumes_from_l6` — matches the drafted `consumed_from_l6` per layer.
  • F-NB-1-c collision_overlap_ratio = 0.0 (L0-L6 vs L7-L9 string-disjoint) — cross-checked.
Wired into `selftest/run_all.sh`. Pure stdlib; deterministic.

C3: a contract test at the boundary-acknowledgment level — it verifies
schema *shape* consistency (the L6 emitter provides what the L7-L9 layers consume), NOT
any wet-lab / clinical fact. Wet-lab integration + IP/contract review = canon cycle-30+
(per the canon handoff JSON's raw_91 disclosure). hexa-bio holds no canon source-of-truth:
the L7-L9 schemas here are *proposed*; the canonical copies will live in canon.
"""
from __future__ import annotations
import io
import json
import os
import sys

_L6_SCHEMA = "nanobot/spec/handoff_l6_emission_v0.schema.json"
_CANON_HANDOFF_REF = "nanobot/spec/canon_l7_acceptance_handoff_ref.json"
_L7L9_DIR = "nanobot/spec/proposed_l7_l9_witness_schemas"
_L7L9_SCHEMAS = [
    ("L7_drug_load",       "raw_77_therapeutic_nanobot_l7_drug_load_v1.schema.json",       "raw_77_therapeutic_nanobot_l7_drug_load_v1"),
    ("L8_immune_evasion",  "raw_77_therapeutic_nanobot_l8_immune_evasion_v1.schema.json",  "raw_77_therapeutic_nanobot_l8_immune_evasion_v1"),
    ("L9_biodistribution", "raw_77_therapeutic_nanobot_l9_biodistribution_v1.schema.json", "raw_77_therapeutic_nanobot_l9_biodistribution_v1"),
]
# the L6 fields the hexa-bio emitter actually produces (raw_77_nanobot_actuation_v2 + the L6-handoff schema):
_L6_EMITTED_FIELDS = {"actuator_id", "n6_invariant", "work_per_cycle_kT", "vertex_decorations",
                      "pose_canonical_form", "brownian_collapse_detected", "l6_layer",
                      "expected_consumer_layers", "joint_witness_path"}


def _root() -> str:
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def _load(rel):
    return json.loads(io.open(os.path.join(_root(), rel), encoding="utf-8").read())


def main() -> int:
    print("nanobot_l6_l7_contract_test — N-R2 L6 → L7-L9 consumer-driven contract test\n", flush=True)
    fails = []

    # 1. L6 producer schema present + LOCKED v1.0.0 + emission unblocked
    l6 = _load(_L6_SCHEMA)
    lock = l6.get("lock_metadata", {})
    l6_props = set(l6.get("properties", {}).keys())
    locked = lock.get("version") == "v1.0.0" and l6.get("properties", {}).get("emission_blocked_until_schema_lock", {}).get("default") is False
    print(f"  [{'PASS' if locked else 'FAIL'}] L6 producer schema ({_L6_SCHEMA}) LOCKED v1.0.0, emission unblocked  "
          f"(lock_metadata.version={lock.get('version')!r}, emission_blocked default={l6.get('properties',{}).get('emission_blocked_until_schema_lock',{}).get('default')})")
    if not locked: fails.append("L6 not locked v1.0.0")
    # the L6 schema's enumerated properties should cover the fields the emitter produces
    missing_in_schema = _L6_EMITTED_FIELDS - l6_props
    print(f"  [{'PASS' if not missing_in_schema else 'FAIL'}] L6 schema enumerates all emitter fields  ({len(_L6_EMITTED_FIELDS)} fields; missing in schema: {missing_in_schema or 'none'})")
    if missing_in_schema: fails.append(f"L6 schema missing {missing_in_schema}")

    # 2. canon handoff ref present + DECLARED + consumes_from_l6 per layer
    canon = _load(_CANON_HANDOFF_REF)
    canon_ok = (canon.get("schema") == "raw_77_therapeutic_nanobot_l7_acceptance_v1" and canon.get("acceptance_status") == "DECLARED")
    print(f"  [{'PASS' if canon_ok else 'FAIL'}] canon handoff ref ({_CANON_HANDOFF_REF}) — schema={canon.get('schema')!r} status={canon.get('acceptance_status')!r} version={canon.get('version')!r}")
    if not canon_ok: fails.append("canon handoff ref bad")
    canon_consumes = {lay["name"] if lay.get("name") else lay["layer"]: list(lay.get("consumes_from_l6", [])) for lay in canon.get("therapeutic_nanobot_l7_to_l9_layers", [])}
    # normalise canon keys: handoff uses {layer:'L7', name:'drug_load'} → our keys are 'L7_drug_load'
    canon_consumes_norm = {}
    for lay in canon.get("therapeutic_nanobot_l7_to_l9_layers", []):
        canon_consumes_norm[f"{lay['layer']}_{lay['name']}"] = list(lay.get("consumes_from_l6", []))
    # canon's work_per_cycle_kT_units ↔ hexa-bio's work_per_cycle_kT — accept the alias
    def _norm_field(f): return "work_per_cycle_kT" if f == "work_per_cycle_kT_units" else f

    # 3. each L7-L9 draft schema: consumed_from_l6 ⊆ L6 emitted fields, and == canon's consumes_from_l6 (modulo alias)
    for layer_key, fname, schema_const in _L7L9_SCHEMAS:
        sch = _load(os.path.join(_L7L9_DIR, fname))
        if sch.get("properties", {}).get("schema", {}).get("const") != schema_const:
            fails.append(f"{layer_key} schema const mismatch"); print(f"  [FAIL] {layer_key}: schema const != {schema_const}"); continue
        # the consumed_from_l6 enum (from the items.enum of the consumed_from_l6 property)
        cf6_prop = sch.get("properties", {}).get("consumed_from_l6", {})
        cf6 = set(cf6_prop.get("items", {}).get("enum", []))
        canon_cf6 = set(_norm_field(f) for f in canon_consumes_norm.get(layer_key, []))
        subset_ok = cf6 <= (_L6_EMITTED_FIELDS)
        match_canon = cf6 == canon_cf6
        ok = subset_ok and match_canon and cf6
        if not ok: fails.append(f"{layer_key} consumed_from_l6 contract")
        print(f"  [{'PASS' if ok else 'FAIL'}] {layer_key}: consumed_from_l6 = {sorted(cf6)}  ⊆ L6-emitted? {subset_ok}  == canon consumes_from_l6 {sorted(canon_cf6)}? {match_canon}")

    # 4. F-NB-1-c collision_overlap_ratio cross-check (L0-L6 vs L7-L9 string-disjoint → 0.0)
    cot = canon.get("collision_overlap_target", {})
    ratio0 = cot.get("expected_jaccard_ratio") == 0.0 and cot.get("pass_threshold", "").strip().startswith("<")
    print(f"  [{'PASS' if ratio0 else 'FAIL'}] F-NB-1-c collision_overlap_target — expected jaccard {cot.get('expected_jaccard_ratio')}, pass_threshold {cot.get('pass_threshold')!r}  (L0-L6 vs L7-L9 string-disjoint)")
    if not ratio0: fails.append("collision_overlap_target")

    n_checks = 4 + 1 + len(_L7L9_SCHEMAS)   # L6-lock, L6-fields, canon-ref, collision; + 3 L7-L9
    print(f"\n  --- {n_checks - len(fails)}/{n_checks} PASS → verdict: {'PASS' if not fails else 'FAIL'} ---")
    print("  C3: contract-shape test (boundary-acknowledgment level) — verifies the L6 emitter provides what")
    print("        the L7-L9 layers consume; the L7-L9 schemas are hexa-bio CONSUMER-PROPOSED drafts (canon adopts → canonical copy")
    print("        moves to canon/domains/life/therapeutic-nanobot/spec/); wet-lab + IP/contract review = canon cycle-30+.")
    if not fails:
        print("__NANOBOT_L6_L7_CONTRACT__ PASS")
        return 0
    print(f"  FAILS: {fails}")
    print("__NANOBOT_L6_L7_CONTRACT__ FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(main())
