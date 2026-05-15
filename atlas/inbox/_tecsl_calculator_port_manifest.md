# TECS-L Calculator → hexa-native PORT MANIFEST

> Scope-narrow companion to `_archive_tecs_l_absorption_manifest.md`.
> That file is the **content/verdict** absorption audit. THIS file is the
> **executable-calculator port plan**: which Python calculators become
> hexa-native source under `compiler/atlas/symbolic/`, `compiler/atlas/verify/`,
> or `stdlib/core/math*`.
>
> Sources: (1) 26 ROOT engines `/Users/ghost/core/archive-TECS-L/*.py`
> (2) 199 `.shared/calc/*.py` recovered from `archive-TECS-L` git history
> (commit `4ee05c39`, the last commit with `.shared/calc` present;
> later 5 files added at `ecf0462b`/`d8b8fa4e`/`2362285a`/`045aac34`).
>
> Generated 2026-05-16. g5 hexa-native-only: every PORT row is a
> re-implemented algorithm, ZERO external Python/sympy/numpy/torch.
> Anti-bloat: an "algorithm" = a named math procedure with a closed-form /
> iterative numeric core. Class scaffolding, argparse, file IO, plotting,
> logging are NOT ported.

---

## §A Summary

| Metric | Count |
|--------|-------|
| Total source files enumerated (26 root + 199 calc) | **225** |
| **PORT-BUILTIN** (verdict-gating → `compiler/atlas/symbolic/` or `verify/`) | **34** |
| **PORT-STDLIB** (general reusable math → `stdlib/core/math*`) | **6** |
| **EXCLUDE** (ML / orchestration / IO / metadata / numerology-risk) | **185** |
| of which: ML training (torch/moe/cnn/bitnet/conscious_lm) | 11 |
| of which: LLM orchestration / loop-IO harness / briefing | 9 |
| of which: heuristic-nav / compass / scan-wave run-logs | 22 |
| of which: numerology-risk post-hoc σ/τ fitters (source self-flagged) | ~30 |
| of which: duplicate/superseded by a kept sibling | ~24 |
| of which: pure metadata / CSV / display-only | ~89 |
| **WAVE 1 executed this session** | **6 ported (5 PASS · 1 DEFERRED)** |
| **§Backlog (prioritized PORT items not in Wave 1)** | **34** |

Wave-1 PASS: `perfect_number_engine`, `nstate_calculator`,
`vortex_math_verifier`, `ftl_n6_constants`, `congruence_chain_engine`.
Wave-1 DEFERRED: `physics_constant_engine` (combinatorial expression
generator — 3-fix budget hit on array-of-tuple idiom; backlog'd as a
trimmed deterministic core).

---

## §B ROOT engines (26) — port classification

| Source file | Core ALGORITHM (the math, not the plumbing) | Class | Target hexa path | Rationale |
|-------------|---------------------------------------------|-------|------------------|-----------|
| `perfect_number_engine.py` | Divisor-function atom pool over even perfect numbers {6,28,496,8128}; bounded binary/ternary op search vs physics targets; triviality score; Bonferroni texas-sharpshooter | **PORT-BUILTIN** | `compiler/atlas/symbolic/perfect_number_engine.hexa` | Closed-form σ/τ/φ atoms + deterministic triviality scorer = verdict-gating; **DONE Wave 1** |
| `nstate_calculator.py` | golden-zone width = ln((N+1)/N), upper=1/2, lower=1/2−width; inverse N = 1/(e^w−1) | **PORT-BUILTIN** | `compiler/atlas/symbolic/nstate_calculator.hexa` | 2 closed-form transcendental formulas, exact reference table; **DONE Wave 1** |
| `congruence_chain_engine.py` | Γ₀(N) invariants: μ=N·Π(1+1/p), cusps=Σφ(gcd(d,N/d)), e2/e3 via Kronecker, genus=1+μ/12−e2/4−e3/3−c/2; isotropy-lcm forcing-chain | **PORT-BUILTIN** | `compiler/atlas/symbolic/congruence_chain_engine.hexa` | Exact modular-curve invariants (Ogg genus-0); PARTIAL in absorption manifest → now full engine; **DONE Wave 1** |
| `physics_constant_engine.py` | σ=12,τ=4 derived-constant table; unary/binary/ternary expression gen; closest-match vs CODATA; texas-sharpshooter | **PORT-BUILTIN (DEFERRED→backlog)** | `compiler/atlas/symbolic/physics_constant_engine.hexa` | Combinatorial generator; deterministic core extractable but 3-fix budget hit — see §Backlog #1 |
| `proof_engine.py` | ProofChain DAG: steps tagged established/axiom/definition/derivation/assumption; tier promotion (Tier0/1/2-3) from step rigor + numerical closure | **PORT-BUILTIN** | `compiler/atlas/verify/proof_tier.hexa` | Tier-classification logic is verdict-gating, but kernels are scattered closures — §Backlog #2 |
| `chemistry_engine.py` | Element Z/A via σ/τ representation; triple-alpha 3·He4=C12=3τ=σ | EXCLUDE | — | source self-flags post-hoc σ/τ-fit numerology (absorption §C row) |
| `nuclear_engine.py` | magic numbers / binding-E via σ/τ; triple-alpha | EXCLUDE | — | same post-hoc-fit class as chemistry_engine |
| `quantum_formula_engine.py` | 18 project consts × 9 QM dimensionless DFS; texas-sharpshooter | EXCLUDE | — | duplicate of perfect_number_engine search core; texas-sharpshooter ported there |
| `texas_quantum.py` | Bonferroni multiple-comparison p-value over discovery parameter space | **PORT-BUILTIN** | fold into `symbolic/texas_sharpshooter.hexa` | reusable verification algorithm — §Backlog #3 (canonical extract) |
| `convergence_engine.py` | 8-domain × ~80-const adaptive convergence-cluster; 3-strategy budget | **PORT-BUILTIN** | `compiler/atlas/symbolic/convergence_cluster.hexa` | convergence-cluster is a named verification algorithm — §Backlog #4 |
| `dfs_engine.py` | Bounded-depth DFS over const pool × binary/ternary ops, cross-island bridge detect, verify_discovery scorer | **PORT-BUILTIN** | `compiler/atlas/symbolic/dfs_search.hexa` | bounded DFS search kernel — §Backlog #5 |
| `brain_analyzer.py` | GABA/deficit/plasticity → (D,P,I) linear map → golden-zone band | EXCLUDE | — | empirical heuristic mapping, not closed-form theorem |
| `brain_cct_analyzer.py` | brain-profile × Lorenz CCT continuity | EXCLUDE | — | Lorenz-sim empirical (IIT-adjacent; `s5_iit_3_0` covers IIT) |
| `brain_singularity.py` | atypical-structure statistical singularity sim | EXCLUDE | — | Monte-Carlo statistical sim, no closed form |
| `consciousness_bridge.py` | Anima Ψ-constants vs n=6 arithmetic, EXACT/APPROX/NO_RELATION grader | **PORT-BUILTIN** | fold into `ftl_n6_constants.hexa` grader | grader is the same n=6 grade ladder — covered by Wave-1 ftl_n6 grade_match |
| `consciousness_calc.py` | Lorenz attractor integrator + 5-test CCT battery | EXCLUDE | — | ODE integrator + empirical battery (absorption EXCLUDE-borderline) |
| `consciousness_fps.py` | dt=1/fps Lorenz CCT sweep for continuity-threshold fps | EXCLUDE | — | sweep over consciousness_calc — same exclude class |
| `model_meta_engine.py` | MoE-style engine-of-engines ML composition | EXCLUDE | — | ML training/composition (g5: lives in engines/, do not port) |
| `model_pure_field.py` | repulsion-field-only judgment (H334) | EXCLUDE | — | ML model variant |
| `model_utils.py` | shared ML components Expert/Gates/MoE/train-loop | EXCLUDE | — | ML scaffolding |
| `llm_expert_analyzer.py` | LLM-orchestration expert routing | EXCLUDE | — | LLM orchestration (explicitly excluded by directive) |
| `discovery_loop.py` (122 KB) | discovery ralph-loop IO/run harness | EXCLUDE | — | loop/IO harness (explicitly excluded) |
| `session_briefing.py` | session metadata briefing | EXCLUDE | — | pure metadata |
| `timeline.py` | event-timeline IO | EXCLUDE | — | IO harness / metadata |
| `compass.py` (34 KB) | heuristic discovery navigation | EXCLUDE | — | heuristic nav (explicitly excluded) |
| `complex_compass.py` | complex-plane heuristic nav | EXCLUDE | — | heuristic nav |

## §C `.shared/calc` (199, git-recovered) — port classification

Only rows that are **PORT** or **notable EXCLUDE** are broken out; the
~165 remaining are EXCLUDE under one of: scan-wave run-logs
(`deep_scan_wave*`, `dfs_ralph_deep*`, `pure_math_deep_scan`), post-hoc
σ/τ numerology fitters (source self-flagged), domain-classifier /
confidence / calibration / anomaly **display-only** scorers,
verify_H_CX_/verify_new_major_hypotheses_* one-off hypothesis harnesses
(empirical, no reusable closed form), or pure CSV/metadata.

| Source file (`.shared/calc/`) | Core ALGORITHM | Class | Target hexa path | Rationale |
|-------------------------------|----------------|-------|------------------|-----------|
| `vortex_math_verifier.py` | 10 Tesla-3,6,9 claims each → deterministic verdict {PROVEN/TRIVIAL/CHERRY-PICK/COINCIDENCE/OVER-INTERPRETED/MIXED/NON-SCI}; digit-root, 2^n mod 9 unit-group, doubling-orbit mod 9, Pisano π(9)=24, n-gon tiling | **PORT-BUILTIN** | `compiler/atlas/symbolic/vortex_math_verifier.hexa` | every claim has a closed-form/iterative kernel + fixed verdict = verdict-gating; **DONE Wave 1** |
| `ftl_n6_constants.py` | n=6 arithmetic-function value table (σ,τ,φ,sopfr,rad,μ,ψ,J2 + ratios); grade ladder EXACT/STRONG/APPROX/WEAK/NO-MATCH by %err; best-match search | **PORT-BUILTIN** | `compiler/atlas/symbolic/ftl_n6_constants.hexa` | exact n=6 ledger + deterministic grade ladder = verdict-gating; **DONE Wave 1** |
| `ftl_tribunal.py` | 15 FTL mechanisms × 3 physics axes → 3-axis verdict (POSSIBLE/CONDITIONAL/IMPOSSIBLE) from energy-condition / causality / known-physics gates | **PORT-BUILTIN** | `compiler/atlas/symbolic/ftl_tribunal.hexa` | fixed 15×3 verdict table, deterministic gating — §Backlog #6 |
| `tesla_369_dfs.py` | DFS {3,6,9} identity miner over σ/τ/φ/sopfr/rad/Ω of n=6; identity emit | **PORT-BUILTIN** | fold into `symbolic/dfs_search.hexa` | same bounded-DFS kernel as dfs_engine — §Backlog #5 |
| `tesla_369_crossdomain.py` | cross-domain catalog {3,6,9}-match count + derivable-from-n6 count + texas-sharpshooter | **PORT-BUILTIN** | fold into `symbolic/texas_sharpshooter.hexa` | texas-sharpshooter reuse — §Backlog #3 |
| `verify_sigma_phi_n.py` | THEOREM σ(n)=n·φ(n) ⟺ n∈{1,6}; multiplicative f(pᵃ)=σ/(pᵃφ) bound proof | **PORT-BUILTIN** | `compiler/atlas/verify/modular.hexa` (extend) | clean uniqueness theorem, verdict-gating — §Backlog #7 |
| `verify_tau_plus_2.py` | THEOREM τ(n)+2=n unique n=6 via τ(n)≤2√n ⇒ n≤7 + exhaustive | **PORT-BUILTIN** | `compiler/atlas/verify/modular.hexa` (extend) | closed-form bound + finite check — §Backlog #7 |
| `verify_sigma_n_phi_tau.py` | THEOREM σ(n)(n+φ(n))=n·τ(n)² unique n=6 (n>1) | **PORT-BUILTIN** | `compiler/atlas/verify/modular.hexa` (extend) | uniqueness theorem — §Backlog #7 |
| `verify_sigma_phi_ntau_proof.py` / `sigma_phi_ntau_proof.py` | THEOREM σ(n)·φ(n)=n·τ(n) ⟺ n∈{1,6} | **PORT-BUILTIN** | `compiler/atlas/verify/modular.hexa` (extend) | uniqueness theorem — §Backlog #7 |
| `verify_sigma_n_phi_tau.py`/`verify_sigma_phi_n.py`/`verify_tau_plus_2.py` group | (the σ/φ/τ "n=6 unique" theorem family) | **PORT-BUILTIN** | `compiler/atlas/verify/modular.hexa` | absorption manifest §D GAP #1 — §Backlog #7 (single combined verifier) |
| `prove_3root_theorem.py` | THEOREM n=6 unique with rad(n)=n ∧ σ(n)=nφ(n) ∧ τ(n)=φ(n)²; squarefree⇒product-form proof | **PORT-BUILTIN** | `compiler/atlas/symbolic/three_root_theorem.hexa` | 3-condition simultaneous uniqueness, closed-form — §Backlog #8 |
| `divisor_field_theory.py` | Action S(n)=σ(n)−2n; S(n)=0 ⟺ n perfect; divisor-lattice spacetime signature | **PORT-BUILTIN** | `compiler/atlas/symbolic/divisor_field_theory.hexa` | S(n)=0 perfect-number characterization closed-form — §Backlog #9 |
| `egyptian_fraction.py` | unit-fraction decomposition of 5/6=1/2+1/3 uniqueness | **PORT-STDLIB** | already `verify/math.hexa::s2_egyptian_fraction` | already absorbed — EXCLUDE (dup of existing verifier) |
| `riemann_zeta_n6.py` | ζ(2)=π²/6 Basel / ζ at n=6 | **PORT-STDLIB** | already `verify/transcendental.hexa` | Basel already in transcendental.hexa — EXCLUDE (dup) |
| `catalan_combinatorial_n6.py` | Catalan number Cₙ=C(2n,n)/(n+1) | **PORT-STDLIB** | `stdlib/core/math.hexa` (add `catalan`) | general reusable combinatorial primitive — §Backlog #10 |
| `pascal_perfect.py` | binomial C(n,k) / Pascal row sums vs perfect numbers | **PORT-STDLIB** | `stdlib/core/math.hexa` (add `binomial`) | C(n,k) is a missing general primitive — §Backlog #11 |
| `symmetric_group_s6.py` | \|S₆\|=720=6!, conjugacy-class / outer-automorphism count | **PORT-STDLIB** | `stdlib/core/math.hexa` (factorial exists) | factorial exists; partition-count is the only net-new — §Backlog #12 |
| `platonic_solids_n6.py` | Euler V−E+F=2; 5 Platonic solids enumeration | **PORT-BUILTIN** | `compiler/atlas/verify/geo.hexa` (extend) | Euler-characteristic closed form, verdict-gating — §Backlog #13 |
| `music_consonance_calculator.py` | small-integer frequency-ratio consonance (2:3, 3:4 …) | EXCLUDE | — | display ranking, ratio table is trivial; no theorem |
| `koide_systematic.py` / `quark_koide_search.py` | Koide Q=(Σm)/(Σ√m)²=2/3 lepton-mass relation | EXCLUDE | — | post-hoc mass-fit; absorption manifest flags numerology-risk |
| `n6_uniqueness_tester.py` | brute n-scan for "n=6 unique" predicates | **PORT-BUILTIN** | fold into combined `verify/modular.hexa` n=6 verifier | subsumed by §Backlog #7 combined verifier |
| `small_n_validator.py` | small-n exhaustive predicate validator | EXCLUDE | — | generic harness, subsumed by §Backlog #7 |
| `prime_pair_verifier.py` | twin/cousin prime-pair n=6 spacing characterization | **PORT-BUILTIN** | `compiler/atlas/symbolic/prime_pair.hexa` | absorption §D GAP #2 (P-NEW 55-char) — §Backlog #14 |
| `generator_finder.py` | primitive-root / multiplicative generator of (Z/nZ)* | **PORT-STDLIB** | `stdlib/core/math.hexa` (add `mult_order`) | reusable NT primitive — §Backlog #15 |
| `validate_calculators.py` | meta self-test runner for the calc suite | EXCLUDE | — | test harness / metadata |
| `apply_grades.py`, `auto_grade_n6.py`, `auto_grade_results.csv`, `nobel_scorer.py`, `confidence_analyzer.py`, `calibration_analyzer.py`, `anomaly_scorer.py`, `cherry_pick_detector.py`, `statistical_tester.py`, `family_fdr_corrector.py`, `spurious_trend_detector.py` | grade/confidence/FDR display scorers | EXCLUDE | — | display/statistical-report only; texas-sharpshooter (the one reusable kernel) ported separately |
| `deep_scan_wave2..15`, `dfs_ralph_deep1..7`, `pure_math_deep_scan.py`, `sequence_scanner.py` | run-log scan iterations | EXCLUDE | — | uncurated run-logs (absorption §F) |
| `verify_H_CX_416/417/418`, `verify_new_major_hypotheses_2..12`, `verify_h309/h413/h414/h415/h437/h438/h439`, `verify_action_principle`, `verify_causal_chain`, `verify_composition_identities`, `verify_gdpi_mapping`, `verify_rob7_*`, `verify_rob8_*` | one-off hypothesis harnesses | EXCLUDE | — | empirical single-shot, no reusable closed-form kernel; verdicts already cited in MAIN.tape batch @D |
| (~30 physics/topology `*_n6.py`: `calabi_yau_n6`, `connes_ncg_n6`, `bott_periodicity_p6`, `feynman_diagrams_n6`, `knot_theory_n6`, `gw_quadrupole_p6`, `riemann_zeta_n6` dup, `thermodynamics_n6`, `information_theory_n6`, `entanglement_n6_analysis`, `quantum_ecc_n6`, `ramsey_n6`, `langlands_perfect`, `monster_moonshine_perfect`, `sporadic_groups_perfect`, `exotic_spheres_perfect`, `elliptic_curves_perfect`, `sphere_packing_perfect`, …) | domain-specific σ/τ/perfect-number "appears here too" probes | EXCLUDE | — | post-hoc σ/τ-fit numerology-risk class; source self-warns; absorption manifest already cites the genuine ones in batch @D |
| (~89 remaining: `*_explorer`, `*_analyzer`, `*_classifier`, `*_mapper`, `sync_*`, `sim_*`, `data_type_explorer`, `direction_analyzer`, `domain_distance`, CSV) | exploration / metadata / display | EXCLUDE | — | system metadata + display-only (absorption §F EXCLUDED classes) |

---

## §D Wave 1 execution log

| Engine | hexa path | smoke test | Result |
|--------|-----------|------------|--------|
| perfect_number_engine | `compiler/atlas/symbolic/perfect_number_engine.hexa` | `test/perfect_number_engine_smoke.hexa` | **PASS** |
| nstate_calculator | `compiler/atlas/symbolic/nstate_calculator.hexa` | `test/nstate_calculator_smoke.hexa` | **PASS** |
| vortex_math_verifier | `compiler/atlas/symbolic/vortex_math_verifier.hexa` | `test/vortex_math_verifier_smoke.hexa` | **PASS** |
| ftl_n6_constants | `compiler/atlas/symbolic/ftl_n6_constants.hexa` | `test/ftl_n6_constants_smoke.hexa` | **PASS** |
| congruence_chain_engine | `compiler/atlas/symbolic/congruence_chain_engine.hexa` | `test/congruence_chain_engine_smoke.hexa` | **PASS** |
| physics_constant_engine | (deferred) | — | **DEFERRED** → §Backlog #1 |

---

## §Backlog (prioritized PORT items for follow-up waves)

Priority order = (closed-form clarity × verdict-gating value), highest first.

1. **physics_constant_engine** — trim to deterministic σ/τ derived-const table
   + best-match-by-%err (drop the random texas-sharpshooter; that ports once
   as #3). Target `symbolic/physics_constant_engine.hexa`.
2. **proof_engine** — ProofChain tier classifier (Tier0/1/2-3 from step-rigor
   + numeric closure). Target `verify/proof_tier.hexa`.
3. **texas_sharpshooter (canonical)** — single Bonferroni multiple-comparison
   p-value kernel. Consumers: texas_quantum, tesla_369_crossdomain,
   perfect_number_engine. Target `symbolic/texas_sharpshooter.hexa`.
4. **convergence_engine** — convergence-cluster (≥3-domain agreement) detector.
   Target `symbolic/convergence_cluster.hexa`.
5. **dfs_engine + tesla_369_dfs** — bounded-depth DFS expression search kernel.
   Target `symbolic/dfs_search.hexa`.
6. **ftl_tribunal** — 15-mechanism × 3-axis FTL verdict table.
   Target `symbolic/ftl_tribunal.hexa`.
7. **σ/φ/τ n=6-uniqueness theorem family** — combined verifier for
   verify_sigma_phi_n / verify_tau_plus_2 / verify_sigma_n_phi_tau /
   sigma_phi_ntau_proof / n6_uniqueness_tester. Closes absorption-manifest
   §D GAP #1. Target: extend `compiler/atlas/verify/modular.hexa`.
8. **prove_3root_theorem** — rad=n ∧ σ=nφ ∧ τ=φ² simultaneous uniqueness.
   Target `symbolic/three_root_theorem.hexa`.
9. **divisor_field_theory** — Action S(n)=σ(n)−2n, S(n)=0 ⟺ perfect.
   Target `symbolic/divisor_field_theory.hexa`.
10. **catalan** → add to `stdlib/core/math.hexa` (Cₙ=binomial(2n,n)/(n+1)).
11. **binomial** → add `binomial(n,k)` to `stdlib/core/math.hexa`.
12. **partition_count** → add integer-partition count to `stdlib/core/math.hexa`.
13. **platonic / Euler-characteristic** — extend `compiler/atlas/verify/geo.hexa`.
14. **prime_pair_verifier** — P-NEW prime-pair n=6 characterization
    (absorption §D GAP #2). Target `symbolic/prime_pair.hexa`.
15. **mult_order / primitive_root** → add to `stdlib/core/math.hexa`.

(Items 7,8,9,14 also close GAPs flagged in
`_archive_tecs_l_absorption_manifest.md` §D — porting them upgrades those
rows from GAP/PARTIAL to ABSORBED-with-verifier.)
