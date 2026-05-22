#!/usr/bin/env bash
# selftest/run_all.sh — wraps the four hexa-bio selftests into one pre-merge gate.
#
# Per `.roadmap.hexa_bio` §A.10 (R1 symlink audit) + §A.9 (F-*-REGRESSION
# preregister) + cycle-26-closure session iter 26-29 (registry consistency).
#
# Exit 0 = all selftests PASS, exit 1 = any FAIL.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"

passes=0
fails=0
results=()

run() {
  local label="$1"; shift
  echo "▶ $label"
  # hexa-native port (T3 union): if _hexa_bridge/selftest/<label>.hexa
  # exists, run THAT instead of the .py/.sh gate. Per-gate auto-migrate;
  # the original command stays the fallback until its hexa port lands —
  # union, safe for incremental porting (NOT all-or-nothing). A hexa
  # port that must SKIP exits 0 (→ PASS bucket) exactly like the .py.
  local hx="$REPO_ROOT/_hexa_bridge/selftest/$label.hexa"
  if [[ -f "$hx" ]] && command -v hexa >/dev/null 2>&1; then
    # Compiler backend: `hexa build` links the fixed runtime.c (json
    # float-repr shortest + json_parse loop non-lossy), so the compiled
    # binary is byte-parity with CPython where `hexa run` (interpreter)
    # is not. Interpreter is kept only as a build-failure fallback.
    local hxbin; hxbin="$(mktemp -u "/tmp/hxg_${label}.XXXXXX")"
    if ( cd "$REPO_ROOT" && hexa build "$hx" -o "$hxbin" >/dev/null 2>&1 ) && [[ -x "$hxbin" ]]; then
      if ( cd "$REPO_ROOT" && "$hxbin" ); then
        echo "  ✓ PASS [hexa-c]"
        passes=$((passes + 1))
        results+=("PASS  $label [hexa-c]")
      else
        echo "  ✗ FAIL [hexa-c]"
        fails=$((fails + 1))
        results+=("FAIL  $label [hexa-c]")
      fi
      rm -f "$hxbin"
      echo
      return
    fi
    rm -f "$hxbin"
    if ( cd "$REPO_ROOT" && hexa run "$hx" ); then
      echo "  ✓ PASS [hexa]"
      passes=$((passes + 1))
      results+=("PASS  $label [hexa]")
    else
      echo "  ✗ FAIL [hexa]"
      fails=$((fails + 1))
      results+=("FAIL  $label [hexa]")
    fi
    echo
    return
  fi
  if "$@"; then
    echo "  ✓ PASS"
    passes=$((passes + 1))
    results+=("PASS  $label")
  else
    echo "  ✗ FAIL"
    fails=$((fails + 1))
    results+=("FAIL  $label")
  fi
  echo
}

run "r1_symlink_audit"          "$HERE/r1_symlink_audit.sh"
run "tape_lattice_honesty_cohort" bash "$HERE/tape_lattice_honesty_cohort.sh"
run "f_tp5_e_uptake_enumerator" python3 "$HERE/f_tp5_e_uptake_enumerator.py" --root "$REPO_ROOT"
run "regression_audit"          python3 "$HERE/regression_audit.py"
run "registry_consistency_audit" python3 "$HERE/registry_consistency_audit.py"
run "n6_axis_computational_verification" python3 "$HERE/n6_axis_computational_verification.py"
run "ribozyme_mfe_nussinov"     python3 "$REPO_ROOT/_python_bridge/module/ribozyme_mfe_nussinov.py"
run "virocapsid_c5_conformance" python3 "$HERE/virocapsid_c5_conformance.py"
run "nanobot_actuator_v2_reference_emit" python3 "$REPO_ROOT/_python_bridge/module/nanobot_actuator_v2_reference_emit.py"
run "ribozyme_off_target_screen" python3 "$REPO_ROOT/_python_bridge/module/ribozyme_off_target_screen.py"
run "ribozyme_reaction_coordinate_quotient" python3 "$REPO_ROOT/_python_bridge/module/ribozyme_reaction_coordinate_quotient.py"
run "ribozyme_kinetics_simulation" python3 "$REPO_ROOT/_python_bridge/module/ribozyme_kinetics_simulation.py"
run "ribozyme_a1_1_kinetics_perturbation_sweep" python3 "$HERE/ribozyme_a1_1_kinetics_perturbation_sweep.py"
run "ribozyme_a1_2_offtarget_threshold_replay" python3 "$HERE/ribozyme_a1_2_offtarget_threshold_replay.py"
run "ribozyme_a1_3_nussinov_determinism_stress" python3 "$HERE/ribozyme_a1_3_nussinov_determinism_stress.py"
run "nanobot_actuation_simulation" python3 "$REPO_ROOT/_python_bridge/module/nanobot_actuation_simulation.py"
run "virocapsid_pdb_corpus" python3 "$REPO_ROOT/_python_bridge/module/virocapsid_pdb_corpus.py"
run "virocapsid_f_virocapsid_1c_1d_audit" python3 "$HERE/virocapsid_f_virocapsid_1c_1d_audit.py"
run "virocapsid_zlotnick_ode" python3 "$REPO_ROOT/virocapsid/module/zlotnick_ode.py" --selftest
run "lean4_proof_witness_emit" python3 "$REPO_ROOT/_python_bridge/module/lean4_proof_witness_emit.py"
run "nanobot_l6_l7_contract_test" python3 "$REPO_ROOT/_python_bridge/module/nanobot_l6_l7_contract_test.py"
# expansion-layer axes (AXIS/HIERARCHY.tape — NOT core-5; in-silico scope only)
run "metallodrug_coordination_sim"       python3 "$REPO_ROOT/_python_bridge/module/metallodrug_coordination_sim.py"
run "oligonucleotide_hybridization_sim"  python3 "$REPO_ROOT/_python_bridge/module/oligonucleotide_hybridization_sim.py"
run "capsid_assembly_modulator_sim"      python3 "$REPO_ROOT/_python_bridge/module/capsid_assembly_modulator_sim.py"
run "rna_targeting_small_molecule_sim"   python3 "$REPO_ROOT/_python_bridge/module/rna_targeting_small_molecule_sim.py"
run "aptamer_affinity_sim"               python3 "$REPO_ROOT/_python_bridge/module/aptamer_affinity_sim.py"
run "reversible_covalent_sim"            python3 "$REPO_ROOT/_python_bridge/module/reversible_covalent_sim.py"
# cross-axis integrations (expansion-layer × core / × expansion; in-silico scope only)
run "metallodrug_quantum_vqe_cross"          python3 "$REPO_ROOT/_python_bridge/module/metallodrug_quantum_vqe_cross.py"
run "oligonucleotide_offtarget_gencode_cross" python3 "$REPO_ROOT/_python_bridge/module/oligonucleotide_offtarget_gencode_cross.py"
run "rna_modality_comparison_smn2_cross"     python3 "$REPO_ROOT/_python_bridge/module/rna_modality_comparison_smn2_cross.py"
run "capsid_modulator_pdb_anchor_cross"      python3 "$REPO_ROOT/_python_bridge/module/capsid_modulator_pdb_anchor_cross.py"
run "reversible_covalent_mpro_vqe_cross"     python3 "$REPO_ROOT/_python_bridge/module/reversible_covalent_mpro_vqe_cross.py"
# expansion-layer parity (1st USER DIRECTION axes brought to code)
run "covalent_inhibition_sim"            python3 "$REPO_ROOT/_python_bridge/module/covalent_inhibition_sim.py"
run "bifunctional_ternary_complex_sim"   python3 "$REPO_ROOT/_python_bridge/module/bifunctional_ternary_complex_sim.py"
# sub-axes :> BIFUNCTIONAL
run "protac_sim"                         python3 "$REPO_ROOT/_python_bridge/module/protac_sim.py"
run "lytac_sim"                          python3 "$REPO_ROOT/_python_bridge/module/lytac_sim.py"
run "autac_sim"                          python3 "$REPO_ROOT/_python_bridge/module/autac_sim.py"
run "ribotac_sim"                        python3 "$REPO_ROOT/_python_bridge/module/ribotac_sim.py"
run "covalent_degrader_sim"              python3 "$REPO_ROOT/_python_bridge/module/covalent_degrader_sim.py"
run "molecular_glue_sim"                 python3 "$REPO_ROOT/_python_bridge/module/molecular_glue_sim.py"
# sub-axes :> QUANTUM
run "allosteric_sim"                     python3 "$REPO_ROOT/_python_bridge/module/allosteric_sim.py"
run "cryptic_pocket_sim"                 python3 "$REPO_ROOT/_python_bridge/module/cryptic_pocket_sim.py"
run "ppi_sim"                            python3 "$REPO_ROOT/_python_bridge/module/ppi_sim.py"
# sub-axes :> WEAVE
run "peptide_sim"                        python3 "$REPO_ROOT/_python_bridge/module/peptide_sim.py"
run "macrocycle_sim"                     python3 "$REPO_ROOT/_python_bridge/module/macrocycle_sim.py"
# 2nd-round cross-axis (F1-F3)
run "oligonucleotide_nanobot_cross"      python3 "$REPO_ROOT/_python_bridge/module/oligonucleotide_nanobot_cross.py"
run "aptamer_nanobot_cross"              python3 "$REPO_ROOT/_python_bridge/module/aptamer_nanobot_cross.py"
run "capsid_modulator_weave_cross"       python3 "$REPO_ROOT/_python_bridge/module/capsid_modulator_weave_cross.py"
# round-3 cross-axis (G1-G5; expansion-layer × expansion-layer unifications)
run "protac_capsid_modulator_cross"      python3 "$REPO_ROOT/_python_bridge/module/protac_capsid_modulator_cross.py"
run "allosteric_cryptic_pocket_cross"    python3 "$REPO_ROOT/_python_bridge/module/allosteric_cryptic_pocket_cross.py"
run "ppi_molecular_glue_cross"           python3 "$REPO_ROOT/_python_bridge/module/ppi_molecular_glue_cross.py"
run "peptide_macrocycle_cross"           python3 "$REPO_ROOT/_python_bridge/module/peptide_macrocycle_cross.py"
run "aptamer_oligonucleotide_cross"      python3 "$REPO_ROOT/_python_bridge/module/aptamer_oligonucleotide_cross.py"
# sub-axis hexa axis-verb parity (15 sub-axes — announce/status only, sim is source of truth)
run "hexa_verb_protac"                   hexa run "$REPO_ROOT/protac/module/protac.hexa"
run "hexa_verb_lytac"                    hexa run "$REPO_ROOT/lytac/module/lytac.hexa"
run "hexa_verb_autac"                    hexa run "$REPO_ROOT/autac/module/autac.hexa"
run "hexa_verb_ribotac"                  hexa run "$REPO_ROOT/ribotac/module/ribotac.hexa"
run "hexa_verb_covalent_degrader"        hexa run "$REPO_ROOT/covalent_degrader/module/covalent_degrader.hexa"
run "hexa_verb_molecular_glue"           hexa run "$REPO_ROOT/molecular_glue/module/molecular_glue.hexa"
run "hexa_verb_allosteric"               hexa run "$REPO_ROOT/allosteric/module/allosteric.hexa"
run "hexa_verb_cryptic_pocket"           hexa run "$REPO_ROOT/cryptic_pocket/module/cryptic_pocket.hexa"
run "hexa_verb_ppi"                      hexa run "$REPO_ROOT/ppi/module/ppi.hexa"
run "hexa_verb_peptide"                  hexa run "$REPO_ROOT/peptide/module/peptide.hexa"
run "hexa_verb_macrocycle"               hexa run "$REPO_ROOT/macrocycle/module/macrocycle.hexa"
run "hexa_verb_rna_targeting_sm"         hexa run "$REPO_ROOT/rna_targeting_small_molecule/module/rna_targeting_small_molecule.hexa"
run "hexa_verb_aptamer"                  hexa run "$REPO_ROOT/aptamer/module/aptamer.hexa"
run "hexa_verb_capsid_modulator"         hexa run "$REPO_ROOT/capsid_assembly_modulator/module/capsid_assembly_modulator.hexa"
run "hexa_verb_reversible_covalent"      hexa run "$REPO_ROOT/reversible_covalent/module/reversible_covalent.hexa"
# falsifier execution gate (expanded to METALLODRUG+OLIGO+COVALENT+BIFUNCTIONAL — 12 falsifiers)
run "falsifier_execution_gate"           python3 "$HERE/falsifier_execution_gate.py"
# round-4 cross-axis (J1-J3)
run "metallodrug_ribotac_cross"          python3 "$REPO_ROOT/_python_bridge/module/metallodrug_ribotac_cross.py"
run "autac_cryptic_pocket_cross"         python3 "$REPO_ROOT/_python_bridge/module/autac_cryptic_pocket_cross.py"
run "molecular_glue_allosteric_cross"    python3 "$REPO_ROOT/_python_bridge/module/molecular_glue_allosteric_cross.py"
# infrastructure / quality gates (I2 + I3 + K2)
run "determinism_regression_gate"        python3 "$HERE/determinism_regression_gate.py"
run "hexa_verify_tier_batch"             python3 "$HERE/hexa_verify_tier_batch.py"
run "external_governance_cross_check"    python3 "$HERE/external_governance_cross_check.py"
# disease case studies (L1 HIV-1 + L2 SMA — one-disease pilots)
run "hiv1_portfolio"                     python3 "$REPO_ROOT/case_studies/hiv1_portfolio/hiv1_portfolio_runner.py"
run "sma_portfolio"                      python3 "$REPO_ROOT/case_studies/sma_portfolio/sma_portfolio_runner.py"
# round-5 cross-axis (G/J expansion) + 3-axis cross
run "metallodrug_covalent_quantum_3way_cross" python3 "$REPO_ROOT/_python_bridge/module/metallodrug_covalent_quantum_3way_cross.py"
run "protac_capsid_modulator_cross"      python3 "$REPO_ROOT/_python_bridge/module/protac_capsid_modulator_cross.py"
run "autac_cryptic_pocket_cross"         python3 "$REPO_ROOT/_python_bridge/module/autac_cryptic_pocket_cross.py"
run "molecular_glue_allosteric_cross"    python3 "$REPO_ROOT/_python_bridge/module/molecular_glue_allosteric_cross.py"
run "peptide_nanobot_cross"              python3 "$REPO_ROOT/_python_bridge/module/peptide_nanobot_cross.py"
run "macrocycle_nanobot_cross"           python3 "$REPO_ROOT/_python_bridge/module/macrocycle_nanobot_cross.py"
run "oligonucleotide_ribotac_cross"      python3 "$REPO_ROOT/_python_bridge/module/oligonucleotide_ribotac_cross.py"
run "protac_ppi_cross"                   python3 "$REPO_ROOT/_python_bridge/module/protac_ppi_cross.py"
# phase-8 cross-axis (BB1 + BB2 + BB3)
run "aptamer_capsid_modulator_cross"     python3 "$REPO_ROOT/_python_bridge/module/aptamer_capsid_modulator_cross.py"
run "metallodrug_cryptic_pocket_cross"   python3 "$REPO_ROOT/_python_bridge/module/metallodrug_cryptic_pocket_cross.py"
run "peptide_allosteric_cross"           python3 "$REPO_ROOT/_python_bridge/module/peptide_allosteric_cross.py"
# additional case studies (M1 + M3)
run "kras_g12c_portfolio"                python3 "$REPO_ROOT/case_studies/kras_g12c_portfolio/kras_g12c_portfolio_runner.py"
run "mpro_covid_portfolio"               python3 "$REPO_ROOT/case_studies/mpro_covid_portfolio/mpro_covid_portfolio_runner.py"
run "bcl2_portfolio"                     python3 "$REPO_ROOT/case_studies/bcl2_portfolio/bcl2_portfolio_runner.py"
run "drug_redesign_sandbox"              python3 "$REPO_ROOT/case_studies/drug_redesign_sandbox/drug_redesign_runner.py"
run "landscape_generator"                python3 "$REPO_ROOT/case_studies/landscape/landscape_generator.py"
# phase-8 case studies (CC1 + CC2 + CC3 + Parkinson + Sickle Cell)
run "alzheimer_portfolio"                python3 "$REPO_ROOT/case_studies/alzheimer_portfolio/alzheimer_portfolio_runner.py"
run "migraine_portfolio"                 python3 "$REPO_ROOT/case_studies/migraine_portfolio/migraine_portfolio_runner.py"
run "type2_diabetes_portfolio"           python3 "$REPO_ROOT/case_studies/type2_diabetes_portfolio/type2_diabetes_portfolio_runner.py"
run "parkinson_portfolio"                python3 "$REPO_ROOT/case_studies/parkinson_portfolio/parkinson_portfolio_runner.py"
run "sickle_cell_portfolio"              python3 "$REPO_ROOT/case_studies/sickle_cell_portfolio/sickle_cell_portfolio_runner.py"
# infrastructure gates (P1 + R1 + N2 + O2 + O3 + S-new + X1)
run "atlas_atom_proofs"                  python3 "$HERE/atlas_atom_proofs.py"
run "atlas_atom_tier_upgrade_gate"       python3 "$HERE/atlas_atom_tier_upgrade_gate.py"
run "portfolio_fitness_function"         python3 "$HERE/portfolio_fitness_function.py"
run "cross_axis_matrix"                  python3 "$HERE/cross_axis_matrix.py"
run "status_md_generator"                python3 "$HERE/status_md_generator.py"
run "schema_const_audit"                 python3 "$HERE/schema_const_audit.py"
run "deferred_items_tracking_gate"       python3 "$HERE/deferred_items_tracking_gate.py"
# phase-8 infrastructure gates (DD2 + DD3)
run "provenance_pipeline_gate"           python3 "$HERE/provenance_pipeline_gate.py"
run "case_studies_export"                python3 "$HERE/case_studies_export.py"
# root dispatcher (O1 + T-new)
run "hexa_bio_root_dispatcher"           hexa run "$REPO_ROOT/hexa_bio.hexa"
run "qmirror_chemistry_vqe_gate" bash "$HERE/qmirror_chemistry_vqe_gate.sh"
run "xeno_substrate_gate" bash "$HERE/xeno_substrate_gate.sh"
run "cmt_side_effect_avoidance_audit" python3 "$HERE/cmt_side_effect_avoidance_audit.py"
run "cmt_library_ranking" python3 "$HERE/cmt_library_ranking.py"
run "cmt_vqe_ladder_readiness" bash "$HERE/cmt_vqe_ladder_readiness.sh"
run "cmt_vqe_ladder_4e4o_readiness" bash "$HERE/cmt_vqe_ladder_4e4o_readiness.sh"
run "cmt_uccsd_lih_4e4o_ansatz_readiness" bash "$HERE/cmt_uccsd_lih_4e4o_ansatz_readiness.sh"
run "cmt_uccsd_lih_4e4o_external_nm_readiness" bash "$HERE/cmt_uccsd_lih_4e4o_external_nm_readiness.sh"
run "cmt_uccsd_inproc_nm_readiness" bash "$HERE/cmt_uccsd_inproc_nm_readiness.sh"
run "cmt_uccsd_lih_4e5o_readiness" bash "$HERE/cmt_uccsd_lih_4e5o_readiness.sh"
run "cmt_uccsd_4e5o_readiness" bash "$HERE/cmt_uccsd_4e5o_readiness.sh"
run "adapt_vqe_4e5o_readiness" bash "$HERE/adapt_vqe_4e5o_readiness.sh"
run "cmt_uccsd_4e6o_readiness" bash "$HERE/cmt_uccsd_4e6o_readiness.sh"
run "adapt_vqe_4e6o_readiness" bash "$HERE/adapt_vqe_4e6o_readiness.sh"
run "compute_substrate_routing" python3 "$HERE/compute_substrate_routing.py"
run "akida_workload_readiness" bash "$HERE/akida_workload_readiness.sh"
run "cmt_axis_and_cross_design_audit" python3 "$HERE/cmt_axis_and_cross_design_audit.py"
run "cmt_smiles_validation" python3 "$HERE/cmt_smiles_validation.py"
run "absorption_bridge_smoke" bash "$REPO_ROOT/_absorption_bridge/selftest/run_all.sh"

echo "─────────────────────────────────────────────"
echo "selftest summary: $passes PASS / $fails FAIL"
for r in "${results[@]}"; do echo "  $r"; done

# All gates now self-report SKIP (exit 0) for expected non-applicable states:
#   - f_tp5_e_uptake_enumerator: SKIP when infra OK + external uptake == 0
#     (F-TP5-e USER-DISCRETION PASS per .roadmap.weave); FAIL only if the
#     weave_compose API is removed from hexa-bio's own modules.
#   - regression_audit: SKIP for R5-sunset-relocated scripts (weave_composition.py,
#     virocapsid_calibration.py → ~/core/nexus/sim_bridge/); FAIL only on a real
#     run failure of a present script.
#   - r1_symlink_audit: docs/n6/ symlinks repointed to in-repo self-contained
#     content post-canon-retirement; PASS.
#   - tape_lattice_honesty_cohort: STRICT cohort gate added 2026-05-16 after
#     all 65 root .tape reached PASS (Pilot+6 batches; see TAPE-AUDIT.md §F +
#     AGENTS.tape @D g_meta_mode_optin). FAIL if any root .tape regresses on
#     the LATTICE_POLICY honesty contract (guard + stance + grounded). A new
#     root tape that opts into meta-mode (`tape-class = "meta..."`) gets the
#     widened grounding clause automatically.
#   - qmirror / xeno / cmt_vqe_ladder / akida gates: SKIP cleanly when the
#     substrate isn't reachable on this host (sister-repo CLI absent / runtime
#     dispatch down) — SKIP ≠ regression.
# So the gate is now STRICT: any FAIL fails the sweep.
if [ "$fails" -eq 0 ]; then
  exit 0
else
  exit 1
fi
