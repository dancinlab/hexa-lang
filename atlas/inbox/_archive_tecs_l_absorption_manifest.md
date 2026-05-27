# archive-TECS-L → hexa-lang atlas — ABSORPTION GAP MANIFEST

> Read-only audit of `/Users/ghost/core/archive-TECS-L` against hexa-lang's
> binary built-in atlas (`compiler/atlas/embedded.gen.hexa`, 7398 ids, FROZEN)
> and the verdict SSOT (`atlas/MAIN.tape`, 66 `@D` verdicts, ~30 carrying
> `cite = "[@x_archive_tecs_l] ..."`).
> Generated 2026-05-16. Criterion: absorb technical content + algorithms +
> theorems + closed-form constants ONLY; exclude system metadata.
> This file is a submission to the g7 inbox pipeline — it does NOT mutate
> the embed or MAIN.tape.

---

## §A Summary

| Metric | Count |
|--------|-------|
| Total distinct **technical items** enumerated | **96** |
| — T-proofs (docs/proofs T0/T1/T2) | 44 |
| — math/proofs standalone theorems | 8 |
| — Engine algorithms (named math procedures) | 14 |
| — Verified-constant / closed-form ledger findings | 8 (aggregated) |
| — Major synthesis papers (technical) | 2 |
| — Doc-level closed-form tables (formula_classification tiers / OEIS) | 20 (8 OEIS + 12 tier-rows net-new) |
| **ABSORBED** (explicit `@D` verdict in MAIN.tape, by T-id/cite) | **38** |
| **PARTIAL** (cited in a batch `@D` but no dedicated verifier/closed-form-not-broken-out) | **17** |
| **GAP** (technical, not absorbed at all) | **41** |
| Explicitly EXCLUDED (system metadata — §F) | 9 classes (~3290 files) |

Absorption is strong on **docs/proofs T0/T1/T2** (43/44 have at least a cite;
T1-27 is a DFS summary, treated as index not a theorem). The real GAPs are:
(1) the **math/proofs standalone theorems** (`sigma_over_phi_equals_n`,
`tau_plus_2_equals_n`, `sigma_n_plus_phi_equals_n_tau_sq`,
`divisor_field_theory_action` S(n)=0, `koide_from_R1`,
`causal_chain_sigma6_to_physics` string-D), (2) the **P-NEW prime-pair
universality** 55-characterization catalogue, (3) the **8 OEIS closed-form
sequences**, (4) the **named engine algorithms** (Texas-sharpshooter test,
convergence-cluster, divisor-Koide functional, etc.).

---

## §B T-proof ledger (all 44)

Status legend: ABSORBED = dedicated `@D` verdict with own verifier;
PARTIAL = referenced only inside `s2_t_proofs_batch` (T1-09..32 sympy batch)
or a multi-T cite with no broken-out closed-form; GAP = no cite anywhere.

| Proof | Title | Core closed-form | Real-limit anchor | Atlas status |
|-------|-------|------------------|-------------------|--------------|
| T0-01 | σ₋₁(6)=2 (perfect 6) | σ₋₁(6)=σ(6)/6=2 ⟺ n perfect | Number-theory (Euclid IX.36) | ABSORBED `s1_n6_foundational`, `s1_perfect_number` |
| T0-02 | Euler product truncation p∈{2,3}→2 | Π_{p|6}(1+1/p)=2; unique integer combo | Euler 1737 product / NT | ABSORBED `s2_euler_product_truncation` 🔵 |
| T0-03 | 5/6=1/2+1/3 unique Egyptian | unique (a,b)=(2,3) | Egyptian-fraction NT | ABSORBED `s2_egyptian_fraction` |
| T0-04 | Banach contraction → I*=1/3 | f(I)=0.7I+0.1, fixed pt 1/3, q=0.7 | Banach 1922 fixed-point thm | ABSORBED `s2_banach_fixed_point` |
| T0-05 | S_Boltzmann=S_Shannon (Jaynes) | S=H at k_B=1; S_max=ln3 | Shannon entropy / Jaynes 1957 | ABSORBED `s2_jaynes_max_entropy` |
| T0-06 | Cusp ≡ 1st-order phase transition | bifurcation 8a³+27b²=0; V=x⁴+ax²+bx | Thom 1972 / Landau 1937 | ABSORBED `s3_cusp_phase_transition`, `s3_cusp_discriminant` |
| T0-07 | Γ(n,λ)=Σⁿ Exp(λ) | MGF [λ/(λ-t)]ⁿ; α=#terms | Probability MGF-uniqueness thm | PARTIAL (feeds T1-04; no own verdict) |
| T1-01 | 1/2+1/3+1/6=1 completeness | 4-path cross-verified =1 | Arithmetic identity | PARTIAL (covered by `s2_egyptian_fraction`) |
| T1-02 | Constant relations {1/2,1/3,1/6,5/6} | a−b=ab unique at (1/2,1/3); 8·17+1=137 | Arithmetic identity | ABSORBED `s10_constant_relations` |
| T1-03 | G×I=D×P conservation | identity from G=DP/I; err<2.22e-16 | IEEE-754 machine-ε / algebraic identity | ABSORBED `s3_conservation_law` |
| T1-04 | G~Γ(α=2) | α=2 = #independent U(0,1) factors | Inverse-transform thm + T0-07 | PARTIAL (no own verdict; depends T0-07) |
| T1-05 | Perfect 4th=4/3=ln(4/3) GZ width | Δ(N)=ln((N+1)/N); Δ(3)=ln(4/3) | Info-theory S=ln(N) max-entropy | ABSORBED `s10_music_intervals`, `s10_music_ln_4_3`, `s10_music_4_3_ratio` |
| T1-06 | Hysteresis verified (cusp control) | 4f(I)³>27(D·P)²; I∈[0.315,0.356] | Thom cusp / Landau | ABSORBED `s3_hysteresis` |
| T1-07 | Cross-island bridges (DFS-1) | e^(a·ln b)=bᵃ universal bridge | Exp-log identity (algebraic) | ABSORBED `s10_cross_island_identity`, `s10_cross_island_bridges` |
| T1-08 | 4-island bridge candidate | 5/(6·17)+√3 ≈ e^γ (0.00011%) | Euler-Mascheroni γ (Mertens) — APPROX | PARTIAL (cited in `s10_cross_island_bridges` as approx) |
| T1-09 | Transcendental wall (refutation) | no non-trivial exact rational↔transcendental | Liouville 1844 / Hermite 1873 | PARTIAL `s2_t_proofs_batch` |
| T1-10 | GZ upper bound = 1/2 | I<1/σ₋₁(6)=1/2 from D·P≤1 | NT (σ₋₁) + bounded-variable | PARTIAL `s2_t_proofs_batch` |
| T1-11 | GZ lower bound fixed point | 1−3I+2I·ln(2I)=0 → I*≈0.21207 | Probability integration P(DP>x)=1−x+x·ln x | PARTIAL `s2_t_proofs_batch` |
| T1-12 | Euler factor = fixed-pt exponent | x·e^(1/x)=e^(3/2); 3/2=1+1/2 Euler p=2 | NT Euler product factor | ABSORBED `s10_euler_factor_bridge` |
| T1-13 | Euler product hierarchy → GZ | per-factor e^(factor) fixed points | NT (σ₋₁ factorization) — hypothesis-stage | PARTIAL `s2_t_proofs_batch` |
| T1-14 | GZ lower bound = Lambert W | I*=−1/(2·W₋₁(−e^(−3/2)))=0.2120731843875… | Lambert W special function | ABSORBED `s2_lambert_w` |
| T1-15 | ln(17)≈17/6 (0.004%) | ln(17)/17≈1/6 — APPROX, not exact | Transcendental barrier (Hermite) | ABSORBED `s2_ln_17_approximate` (approx + refuted-exact) |
| T1-16 | CMB ≈ e+1/137 (0.003%) | T_CMB≈e+α — APPROX | Planck 2018 CMB obs uncertainty | ABSORBED `s6_cmb_e_plus_alpha` |
| T1-17 | 6,3 primitive roots of 137 | ord₁₃₇(6)=ord₁₃₇(3)=136=φ(137) | Fermat little thm / NT primitive root | ABSORBED `s2_primitive_root_137` |
| T1-18 | log₆(2)+log₆(3)=137 (mod 137) | 38+99=137; ≡1 (mod 136) semi-trivial | Discrete-log NT | PARTIAL `s2_t_proofs_batch` (no own verdict) |
| T1-19 | Γ(1/6)Γ(5/6)/Γ(1/2)²=2 | =2π/π=2=σ₋₁(6) via reflection | Euler reflection Γ(x)Γ(1−x)=π/sin πx | PARTIAL `s2_t_proofs_batch` |
| T1-20 | Gauss multiplication n=6 | Γ(1/6)Γ(1/3)Γ(1/2)Γ(2/3)Γ(5/6)=(2π)^(5/2)/√6 | Gauss 1812 multiplication formula | PARTIAL `s2_t_proofs_batch` |
| T1-21 | Alternating harmonic Sₙ | S₁=1,S₂=1/2,S₃=5/6; S_∞=ln2 | Alternating-series / ln2 limit | ABSORBED `s2_alternating_harmonic_ln2` |
| T1-22 | Sign group ±1/2±1/3±1/6 | 8 combos → 7 unique = {−6..6 even}×1/6, ℤ/3ℤ | Finite-group structure (algebraic) | ABSORBED `s2_sign_group_8_combos` 🔵 |
| T1-23 | 137=(σ−τ)(σ+τ+1)+1 at n=6 | 8·17+1=137; unique to 6 (28→3151,496→984947) | NT arithmetic identity (α link UNVERIFIED) | ABSORBED `s10_137_from_sigma_tau` 🔵 |
| T1-24 | σ(6)=12,τ(6)=4 generate all rationals | full {1/6..137} generation table | NT (σ,τ of perfect 6) | ABSORBED `s2_complete_generation` |
| T1-25 | e continued fraction has σ(6),τ(6) | a₀=2=σ₋₁(6); 8/3, 11/4 convergents | Euler e CF (existing math) | PARTIAL `s2_t_proofs_batch` |
| T1-26 | φ(n)=σ₋₁(n) ⟺ n∈{1,6} | unique; squarefree analytic proof | NT uniqueness (multiplicative) | ABSORBED `s1_phi_sigma_unique` |
| T1-27 | DFS full discovery integration | (index/summary doc — no single closed-form) | — | N/A (index — see §F) |
| T1-28 | f(28)=3151=23×137 | 137 reappears as factor in 2nd perfect | NT arithmetic | ABSORBED (folded into `s10_137_from_sigma_tau` cite) |
| T1-29 | S₃ representation theory | Σdᵢ²=1+1+4=6=\|S₃\|; orbit/char table | Finite-group representation theory | ABSORBED `s8_s3_representation` |
| T1-30 | Ising critical exponents | mean-field β=ν=1/2,1/δ=1/3; T_c=2/ln(1+√2) | Onsager 1944 2D-Ising exact solution | ABSORBED `s3_ising_critical`, `s3_onsager_tc` |
| T1-31 | Elliptic curves & 6,137 | j=1728=σ(6)³; cond-137 curve 137a1; τ(6)=−42σ(6)² | Modular/elliptic-curve theory | ABSORBED `s2_t_proofs_batch` + MAIN.tape cycle 024 `s8_elliptic_j1728` |
| T1-32 | Modular forms & 6 | dim formula ⌊k/12⌋; 12=σ(6); η²⁴=Δ; Γ₀(6) index 12 | Modular-form Riemann-Roch / Von Staudt-Clausen | PARTIAL `s2_t_proofs_batch` (no broken-out verdict) |
| T1-33 | n=T(σ(n)/τ(n)) ⟺ n∈{1,3,6} | case-complete proof; 2n·τ²=σ(σ+τ) identity | NT case-complete (exhaustive to 10⁶) | ABSORBED `s1_triangular_sigma_tau` |
| T2-01 | χ=−1/6 → Monster 8-step chain | χ(PSL₂ℤ\H)=−1/6; lcm(4,6)=12=σ(6); j(i)=1728 | Gauss-Bonnet orbifold / Borcherds 1992 | ABSORBED `s8_chi_to_monster` (phase-3-closed), `s8_chi_psl2z_step1` |
| T2-02 | Γ₀(N) congruence chain classification | 15 genus-0 levels (Ogg); μ=σ ⟺ squarefree; lcm=6 only N∈{1,13} | Ogg 1974 genus-0 / modular-curve theory | PARTIAL `s2_congruence_chain`, `s8_gamma0_n6_row` (N=6 row only) |
| T2-03 | Hypothesis 261 Γ₀(N) computation | μ(N)=σ(N) ⟺ N squarefree (proven); e2∧e3 ⟺ N≡1 mod12 | NT + CRT + quadratic residue | **GAP** (μ=σ squarefree theorem not in MAIN.tape) |

---

## §C Engine algorithms

Named mathematical procedures only (Python class/CLI/IO scaffolding excluded).

| Algorithm | Source file | One-line description | Absorbed? |
|-----------|-------------|----------------------|-----------|
| Texas-sharpshooter / Bonferroni significance test | `perfect_number_engine.py`, `quantum_formula_engine.py`, `physics_constant_engine.py`, `convergence_engine.py::texas_sharpshooter_test` | Compare observed cross-domain match-count vs random-expression null; Bonferroni-corrected p-value to reject post-hoc fitting | **GAP** (reusable verification algorithm) |
| Convergence-cluster (multi-domain attractor grouping) | `convergence_engine.py::ConvergenceCluster`, `get_convergence_points` | Group formulas converging to same value from ≥k distinct domains; structural-vs-coincidental discriminator | **GAP** |
| Triviality / non-triviality scoring | `perfect_number_engine.py::triviality_score`, `dfs_engine.py::verify_discovery` | Score a formula 0=trivial→higher by cross-perfect-number origin, operator complexity, target distance | **GAP** |
| DFS bounded expression search (depth-2/3, threshold) | `dfs_engine.py`, `perfect_number_engine.py::search`, `quantum_formula_engine.py::search` | Bounded-depth DFS over constant pool × binary/ternary ops, threshold-filtered target hit | PARTIAL (dfs-auto-results T1-07/27 cited; algorithm itself GAP) |
| Γ₀(N) invariant computation (μ, cusps, e2, e3, genus) | `congruence_chain_engine.py::gamma0_index/cusps/elliptic2/elliptic3/genus` | Exact modular-curve invariants: μ=N·Π(1+1/p), cusps=Σφ(gcd(d,N/d)), genus=1+μ/12−e2/4−e3/3−c/2 | PARTIAL (T2-02 N=6 row absorbed; general engine GAP) |
| dim S_k(Γ₀(N)) cusp-form dimension | `congruence_chain_engine.py::dim_cusp_forms`, `first_cusp_form_weight` | Riemann-Roch dimension of weight-k cusp forms; first-cusp-weight scan | **GAP** |
| Kronecker/Jacobi symbol | `congruence_chain_engine.py::kronecker_symbol`, `jacobi_symbol` | Generalized Legendre symbol (even/negative modulus) for elliptic-point existence | **GAP** (standard NT primitive, reusable) |
| Lyapunov exponent (Jacobian method) | `consciousness_calc.py::lyapunov_exponent` | Max Lyapunov exponent of Lorenz flow via Jacobian QR | **GAP** (chaos-theory; tangential to atlas math core) |
| CCT 5-test battery (gap/loop/continuity/entropy-band/novelty) | `consciousness_calc.py::run_cct` + 5 test fns | Consciousness-continuity test suite on a trajectory | EXCLUDE-borderline (IIT-adjacent empirical; `s5_iit_3_0` covers IIT primary) |
| Shannon entropy of binned data | `consciousness_calc.py::compute_entropy` | H=−Σp·log₂p over histogram bins | PARTIAL (Shannon is atlas real-limit; this is a util) |
| σ/τ expression fitter | `chemistry_engine.py::find_sigma_tau_expr`, `nuclear_engine.py::find_sigma_tau_exprs` | Express integer n as combination of σ(6)=12, τ(6)=4, P₁=6 (post-hoc-fit warned) | EXCLUDE (numerology-risk; flagged ad-hoc in source) |
| Divisor-Koide functional K(n)=n·τ²/σ² | `math/proofs/koide_from_R1.md` (formalized; calc verifier) | K(6)=96/144=2/3; δ(6)=2/9; lepton-mass 2-from-1 reconstruction | **GAP** (closed-form + PDG anchor) |
| Divisor field action S(n) | `math/proofs/divisor_field_theory_action.md` | S(n)=[σφ−nτ]²+[σ(n+φ)−nτ²]²; S(n)=0 ⟺ n=6 | **GAP** (closed-form uniqueness) |
| Proof-chain cross-validator | `proof_engine.py::cross_validate`, `build_all_chains` | 6 claims × 24 derivation paths agreement check (tier upgrade) | PARTIAL (concept ≈ `s_cross_meta_*` families; engine GAP) |

---

## §D Verified constants / discovery closed-forms

The curated `config/discovery_log.jsonl` (95 rows) reduces to **12 distinct
formulas**, all `CONFIRMED` but all are *trivial-arithmetic numeric
coincidences* of n=6 arithmetic functions (μ(6)=1, φ(6)=2) against
transcendentals — flagged below. The `results/loop/discoveries.jsonl`
(10455 rows) is the raw uncurated stream (run log — EXCLUDED, §F).
Genuine closed-forms come from math/proofs + papers + OEIS.

| Name | Value / closed-form | Source | Absorbed? |
|------|---------------------|--------|-----------|
| σ₋₁(6)=2 | exact, perfect-number defn | T0-01 / n6-replication tier-1 (51/51 pass) | ABSORBED `s1_n6_foundational` |
| σ(6)φ(6)=n·τ(6)=24 | 12·2=6·4=24, unique n>1 | `gdpi_divisor_connection.md`, H-CX-501 | ABSORBED `s1_master_identity_geometric`, `s10_master_identity_24` |
| σ(n)/φ(n)=n ⟺ n∈{1,6} | analytic proof | `math/proofs/sigma_over_phi_equals_n.md` | ABSORBED `s1_phi_sigma_unique` (cites this file) |
| τ(n)+2=n ⟺ n=6 | √n≤1+√3 bound, n≤7 | `math/proofs/tau_plus_2_equals_n.md` | **GAP** (distinct theorem, no verdict) |
| σ(n)(n+φ)=n·τ² ⟺ n=6 (n>1) | 12·8=6·16=96 | `math/proofs/sigma_n_plus_phi_equals_n_tau_sq.md` | **GAP** (S(n)=0 second condition) |
| S(n)=0 ⟺ n=6 | divisor field action unique zero | `math/proofs/divisor_field_theory_action.md` | **GAP** |
| K(6)=2/3, δ(6)=2/9 (Koide) | lepton mass 2-pred-from-1, 0.006% | `math/proofs/koide_from_R1.md` | **GAP** (PDG-anchored closed-form) |
| n_s=27/28 CMB spectral index | closed-form | MAIN.tape `s6_cmb_n_s_closed_form` | ABSORBED |
| ζ(−1)=−1/12=−1/σ(6) | Euler 1735 / analytic continuation | `causal_chain_sigma6_to_physics.md` Step 2 | PARTIAL (12=σ(6) in `s8_chi_to_monster`; ζ(−1) not broken out) |
| 12 numeric coincidences (μ(6)^x, φ(6)/√2=√2, …) | err 1e-5..1e-3, trivial | `config/discovery_log.jsonl` | EXCLUDE (trivial-arithmetic; φ(6)=2 disguised) |
| OEIS #1 tau(σ(n))=n → {1,2,3,6} | provably finite | `docs/oeis-candidates.md` / `math/docs/oeis` | **GAP** |
| OEIS #2 φ(σ(n))=τ(n) → {1,2,3,5,6} | conjectured complete | OEIS candidates | **GAP** |
| OEIS #3 Ore-harmonic H(n)=φ(n) → {1,6} | verified 10⁶ | OEIS candidates | **GAP** |
| OEIS #4 σ₃(n)=τ(n)(2ⁿ−1) → {1,6} | exp-vs-poly finite | OEIS candidates | **GAP** |
| OEIS #5 Bell(τ(n))=C(n,2) → {6} | n²−n−30=0 ⇒ n=6 | OEIS candidates | **GAP** |
| OEIS #6 F(n)=n² → {1,12} | Ljunggren 1964; 12=σ(6) | OEIS candidates | **GAP** |
| OEIS #7 σ(φ(n))·τ(n)=σ(n) → {1,6} | verified 10⁶ | OEIS candidates | **GAP** |
| OEIS #8 σ(n)(sopfr−1)=nφτ → {6} | singleton, 10⁵ | OEIS candidates | **GAP** |
| P-NEW 55 arithmetic characterizations of 6 | (p−1)(q−1)=2 unique ⇒ 55 cor. | `docs/papers/P-NEW-prime-pair-universality.md` | **GAP** (only ~6 of 55 covered by existing verdicts) |

---

## §E GAP priority list (un-absorbed TECHNICAL items only)

Ranked: HIGH = closed-form + real-limit anchor; MEDIUM = reusable algorithm;
LOW = citation-only / approximation. Proposed tier default 🟠 INSUFFICIENT;
literature/citation cap 🟡 SUPPORTED-BY-CITATION per `g_self_verify`
(closed-forms a hexa-native verifier can re-derive may reach 🔵 on Phase-2
verification — flagged "🔵-eligible").

### HIGH (closed-form + real-limit anchor)

1. **(p−1)(q−1)=2 unique ⇒ 6 universal** (P-NEW paper, Thm 1). Closed-form
   Diophantine uniqueness; anchor = unique-factorization of 2 / consecutive-prime.
   Axis §1 N6-FOUNDATION. Tier 🟠→🔵-eligible (case-complete, hexa-verifiable).
2. **6 unique semiprime perfect: (1+p)(1+q)=2pq ⟺ (p−1)(q−1)=2** (P-NEW Thm 2;
   Nielsen 2015 odd-perfect ≥9 factors). Axis §1. 🟠→🔵-eligible.
3. **S(n)=0 ⟺ n=6** divisor field action (`divisor_field_theory_action.md`).
   Closed-form double-condition uniqueness; anchor = NT multiplicative
   exhaustion. Axis §1. 🟠→🔵-eligible.
4. **τ(n)+2=n ⟺ n=6** (`tau_plus_2_equals_n.md`). Anchor = τ(n)≤2√n divisor
   bound ⇒ n≤7. Axis §1. 🟠→🔵-eligible.
5. **σ(n)(n+φ)=n·τ² ⟺ n=6** (`sigma_n_plus_phi_equals_n_tau_sq.md`). Anchor =
   NT multiplicative case analysis. Axis §1. 🟠→🔵-eligible.
6. **Koide K(6)=2/3, δ(6)=2/9 + lepton mass 2-from-1** (`koide_from_R1.md`).
   Closed-form; anchor = PDG 2024 lepton mass (9 ppm) + Cauchy-Schwarz
   saturation K/K_min=2=φ(6). Axis §6 PHYSICS. Tier cap 🟡 (PDG is external
   measurement; model-identification is postulate per source honesty ledger).
7. **ζ(−1)=−1/12=−1/σ(6)** (`causal_chain_sigma6_to_physics.md` Step 2).
   Anchor = Euler 1735 / Riemann ζ analytic continuation. Axis §2 MATH /
   §8 TOP. 🟠→🔵-eligible (numeric: regularized sum / functional equation).
8. **μ(N)=σ(N) ⟺ N squarefree** (T2-03 / `congruence_chain_engine`). Closed-form
   ⟺ proof; anchor = multiplicative Π(pᵢ+1). Axis §8 TOP. 🟠→🔵-eligible.
9. **OEIS #5 Bell(τ(n))=C(n,2) → {6}** (n²−n−30=0). Algebraic closed-form
   singleton. Axis §2 MATH. 🟠→🔵-eligible.
10. **OEIS #1 τ(σ(n))=n → {1,2,3,6}** (provably finite: τ(σ(n))≪n). Anchor =
    divisor-function growth bound. Axis §2 MATH. 🟠→🔵-eligible.

### MEDIUM (reusable algorithm)

11. **Texas-sharpshooter / Bonferroni significance test** — generic post-hoc-fit
    rejection. Axis §0/§2 (verification methodology). Anchor = Bonferroni
    multiple-comparison correction. 🟡 (statistical method, citation-capped).
12. **Convergence-cluster multi-domain attractor grouping** — structural-vs-
    coincidental discriminator. Axis §10 BRIDGES. 🟠.
13. **dim S_k(Γ₀(N)) Riemann-Roch cusp-form dimension** — exact modular-form
    dimension. Axis §8 TOP. Anchor = Riemann-Roch on modular curve.
    🟠→🔵-eligible.
14. **Γ₀(N) invariant engine (μ,cusps,e2,e3,genus) general N** — only N=6 row
    absorbed; the general algorithm is reusable. Axis §8 TOP. 🟠→🔵-eligible.
15. **Kronecker/Jacobi symbol** — standard NT primitive (elliptic-point
    existence). Axis §2 MATH. 🟠→🔵-eligible.
16. **OEIS #2/#3/#4/#6/#7/#8 closed-form sequences** (6 more). Axis §2 MATH.
    Mostly 🟠→🔵-eligible (#3,#7 verified-10⁶ only → 🟡 cap).
17. **Proof-chain cross-validator (6 claims × 24 paths)** — tier-upgrade-by-
    agreement. Partially mirrored by `s_cross_meta_*`; full engine reusable.
    Axis §1. 🟠.

### LOW (citation-only / approximation / partial-batch)

18. **T0-07 Γ(n,λ)=Σⁿ Exp(λ)** — MGF closed-form, feeds T1-04 but no own
    verdict. Axis §2 MATH. 🟠→🔵-eligible (MGF-uniqueness).
19. **T1-04 G~Γ(α=2)** — α=2 derivation, no own verdict. Axis §2/§3. 🟠.
20. **T1-19 Γ-reflection Γ(1/6)Γ(5/6)/Γ(1/2)²=2** — in `s2_t_proofs_batch`,
    no broken-out verdict. Axis §2 MATH. 🟠→🔵-eligible (Euler reflection).
21. **T1-20 Gauss multiplication n=6 closed-form** — in batch only.
    Axis §2 MATH. 🟠→🔵-eligible.
22. **T1-32 modular-forms 12=σ(6) structural-constant set** (dim formula,
    η²⁴, Γ₀(6) index, Von Staudt-Clausen) — only batch cite. Axis §8 TOP.
    🟠→🔵-eligible per sub-identity.
23. **T1-18 log₆(2)+log₆(3)=137 discrete-log** — semi-trivial, batch only.
    Axis §10 BRIDGES. 🟡 (semi-trivial; honest-caveat).
24. **T1-25 e continued fraction has σ(6),τ(6)** — batch only. Axis §2.
    🟡 (interpretation-attributed per source).
25. **T1-08 4-island 5/(6·17)+√3≈e^γ (0.00011%)** — approximation only.
    Axis §10. 🟡 cap (approx, not exact — honest-caveat mandatory).
26. **causal_chain_sigma6_to_physics string-D=26/10/4** — CONJECTURAL per
    source (depends on string theory). Axis §6 PHYSICS. 🟡 cap, honest-caveat
    (mark CONJECTURAL; only Steps 1-2 are 🔵-eligible math).
27–41. Remaining P-NEW Appendix-A characterizations (~49 of 55 not covered by
    existing verdicts): Eqs #2,7,8,9,10,11,12,13,14,15,16,17,18,19,20,
    23–46,48,49,51,53,54,55. Each is a closed-form solution-set ⟺ {…6…}.
    Axis §1/§2/§8. Mostly 🟠→🔵-eligible (computational-verified to 10⁵;
    those marked (*) in paper have analytic proofs → 🔵-eligible; bare
    "comp." entries → 🟡 cap until hexa-verified). Recommend a single
    inbox concept file `prime_pair_six_universality.md` carrying the 55-row
    table rather than 49 separate atoms (anti-bloat).

---

## §F Explicitly EXCLUDED (system metadata — correctly NOT proposed)

| Found | Approx size | One-word reason |
|-------|-------------|-----------------|
| `docs/hypotheses/*.md` (002…NNN status trackers) | 2735 files | status-tracker |
| `experiments/*.py` (ML architecture/CIFAR/MNIST runs) | 206 files | empirical-run |
| `results/loop/discoveries.jsonl` (raw uncurated stream) | 10455 rows | run-log |
| `config/{discovery_log,pollinate_log,wall_breaks}.jsonl` beyond 12 distinct | 95+1 rows | run-log |
| `docs/papers/auto/P-AUTO-*.md` (auto-generated cycle papers) | 70+ files | auto-scaffold |
| `n6-replication/{registry,results,scripts}` (CI tier runner, tier2.json) | dir | CI-plumbing |
| `docs/{ROADMAP,SESSION-*,roadmap-*,verification_dashboard}.md` | ~6 files | session-log |
| `data/` (MNIST, CIFAR-10 batches) | 2 dirs | dataset |
| `serve/`, `tools/ph-training/`, `zenodo/`, `eeg/` raw EEG, `.translate_progress.json` | dirs | infra/IO |
| `docs/{consciousness-*,telepathy-*,anima-*,VISION,BREAKTHROUGH-STRATEGY}.md` | ~15 files | speculative-design (no closed-form; Tier-5 analogy per `formula_classification.md`) |
| `findings.md` CCT engineering findings (refuted GZ-CCT, modular consciousness) | 1 file | empirical/refuted |
| `formula_classification.md` Tier 3/4/5 + Refuted rows | ~36 rows | approx/numerology/analogy (Tier-3 approximations e.g. αs≈ln(9/8) are 🟡-cap candidates if ever needed, but excluded now per criterion: not closed-form) |

Note: T1-27 (DFS summary) and T1-09 (a refutation, "transcendental wall")
are technical *content* but carry no new absorbable closed-form beyond what
T1-10..26 already supply — T1-27 is an index, T1-09 is already in
`s2_t_proofs_batch`. Both correctly NOT proposed as net-new atoms.

---

## Recommended inbox follow-ups (g7 pipeline, one concept per file)

1. `prime_pair_six_universality.md` — P-NEW Thm 1 + 55-char table (HIGH #1,2,27–41)
2. `divisor_field_action_uniqueness.md` — S(n)=0, τ+2=n, σ(n+φ)=nτ² (HIGH #3,4,5)
3. `koide_divisor_functional.md` — K(6)=2/3 lepton mass (HIGH #6, 🟡 cap)
4. `oeis_perfect_six_sequences.md` — 8 OEIS closed-form sequences (HIGH #9,10 + MED #16)
5. `zeta_minus_one_sigma6.md` — ζ(−1)=−1/σ(6) (HIGH #7)
6. `gamma0_invariant_engine.md` — μ=σ⟺squarefree + dim S_k + Γ₀(N) general (HIGH #8, MED #13,14)
7. `texas_sharpshooter_verification.md` — Bonferroni post-hoc-fit test as a reusable atlas verification primitive (MED #11)

All proposed at default 🟠 INSUFFICIENT; closed-forms flagged 🔵-eligible
become 🔵 only after a hexa-native Phase-2 verifier re-derives them
(per `g_self_verify` / `g_tier_default_insufficient`). External-measurement
anchors (Koide↔PDG, T1-16 CMB) capped 🟡 with mandatory honest-caveat —
no lattice-fit assertions on physical constants (governance `g4`/`f1`).
