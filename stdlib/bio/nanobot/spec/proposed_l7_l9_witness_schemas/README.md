# proposed_l7_l9_witness_schemas — CONSUMER-PROPOSED L7-L9 acceptance schemas (hexa-bio → canon)

The canon-side handoff JSON
(`canon@mk1:domains/life/therapeutic-nanobot/handoff/2026-05-28_hexa-nanobot-therapeutic-nanobot-boundary.json`,
`raw_77_therapeutic_nanobot_l7_acceptance_v1`, `DECLARED v1.0.0-stub`) *names* three per-layer witness
schemas as **placeholder names** — "actual schema files do not yet exist in either repo":

| schema | layer | consumes_from_l6 | this file |
|--------|-------|------------------|-----------|
| `raw_77_therapeutic_nanobot_l7_drug_load_v1` | L7 drug load | `work_per_cycle_kT`, `vertex_decorations` | `raw_77_therapeutic_nanobot_l7_drug_load_v1.schema.json` |
| `raw_77_therapeutic_nanobot_l8_immune_evasion_v1` | L8 immune evasion | `pose_canonical_form` | `raw_77_therapeutic_nanobot_l8_immune_evasion_v1.schema.json` |
| `raw_77_therapeutic_nanobot_l9_biodistribution_v1` | L9 biodistribution | `actuator_id` | `raw_77_therapeutic_nanobot_l9_biodistribution_v1.schema.json` |

These are hexa-bio's **consumer-proposed** field-sets (the §12-research consumer-driven / Pact-style contract
pattern), derived from the canon handoff JSON's per-layer `responsibility` + `primitives` + `consumes_from_l6`.
Field sets per the handoff JSON's `primitives` strings:
- L7: `L7_drug_payload:lipid_shell:k_release_s_inv:payload_mass_amu` + `L7_surface_coating:peg_density_per_nm2:zeta_potential_mV`
- L8: `L8_complement_evasion:c3b_deposition_rate_per_s:macrophage_clearance_t_half_h` + `L8_opsonization_shield:igg_binding_kd_M:fc_receptor_avidity`
- L9: `L9_clearance_kinetics:renal_hepatic_ratio:residence_time_h` + `L9_tissue_targeting:organ_uptake_percent_id_per_g:active_targeting_ligand_kd_M` + `L9_excretion_pathway:eGFR_threshold_ml_min:bile_clearance_fraction`

`_python_bridge/module/nanobot_l6_l7_contract_test.py` checks that the hexa-bio L6 emitter
(`raw_77_nanobot_actuation_v2` / `raw_77_nanobot_l6_handoff_v1`) provides everything every L7-L9 schema's
`consumed_from_l6` declares — a consumer-driven contract test (run_all.sh-wired).

**Source of truth**: once the canon side adopts/edits these, the canonical copy lives at
`canon/domains/life/therapeutic-nanobot/spec/`. raw_91 C3: contract drafts — boundary-acknowledgment level;
NO wet-lab / clinical claim; wet-lab + IP/contract review = canon cycle-30+.
