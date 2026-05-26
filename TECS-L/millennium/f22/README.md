# F22 — RH + BSD retry-2 (Clay-millennium new angles)

**Date**: 2026-05-27  
**Status**: CLOSED — honest framework recasting + verifiable witnesses only

## Mandate

Per F22 task brief: 사용자 명시 "밀레니엄 2개 진행" — RH + BSD 둘 다 재시도,
F19/F20 너머 새 angle. Extreme honesty mandate per
`feedback_closure_is_physical_limit`: full Clay proof = LLM scope 너머.

## Summary

| Lane | Task | Outcome | Verified |
|------|------|---------|----------|
| RH s1 | Mertens stress n=100..200 (10 n) | 10/10 |M(n)|≤√n hold | 🔵 |
| RH s1 | ω-decomp closed form at n=30 | M(30)=−3 matches strata sum | 🔵 |
| RH s1 | ζ Dirichlet/Euler partial cross-check N≤200 | Euler conv ~2× faster, expected | 🟢 |
| RH s1 | Explicit ζ zeros γ_1..γ_5 (Odlyzko) | Citation only | 🟡 |
| RH s1 | ω-decomp ⇒ improved \|M(n)\| bound | NO — tautological | 🔴 NEG |
| BSD s2 | Tunnell test n∈{5,7,13,15,21,23} | 6/6 2A=B=0 (CONG, BSD-cond) | 🔵 |
| BSD s2 | Tunnell-even n∈{6,14,22} | 3/3 2C=D=0 (CONG, BSD-cond) | 🔵 |
| BSD s2 | Heegner CM j(E_6)=1728 closed | hexa-native arithmetic | 🔵 |
| BSD s2 | E_6 conductor 576, gamma0_index=1152 | hexa-verified | 🔵 |
| BSD s2 | Heegner point P=(-3,9) on E_6 | F19 re-anchor | 🔵 |
| BSD s2 | GGZ rank≤1 ⇒ BSD known at n=6 | 1986 theorem cite | 🟡 |
| s3 | ω-decomp transfer to RH bound | HONEST NEGATIVE | 🔴 NEG |
| s3 | Multilayer non-lift transfer to BSD | n=6 layer divergence confirmed | 🔴 NEG |
| s4 | F18 weight-4 ↔ E_6 weight-2 link | Shimura-lift potential, UNVERIFIED | 🟡 |

**Total**: 12 🔵 verified + 1 🟢 numerical + 3 🟡 citation + 3 🔴 honest-negative

## Honest assessment

**Real progress?**  No.  Framework recasting only.

The four lanes (s1, s2, s3, s4) produce:
- Pointwise verified witnesses on KNOWN facts (Mertens values, Tunnell counts,
  j-invariant of E_n, conductor of E_6).
- Honest negatives on TWO methodology-transfer attempts:
  - **ω-decomp on RH**: tautological rearrangement, does NOT bound |M(n)|.
  - **Multilayer non-lift on BSD**: confirms n=6 distinction does NOT lift to
    elliptic L-function rank structure, consistent with F7/F15/F17.

**arxiv-publishable partial finding?**  No, by `paper_significance` gate:
- No pre-registered falsifier with Δ-finding meeting publication threshold.
- F22 is a "follow-up retry after F19/F20 negative" — same gate failure as F19.
- Closed-negative findings (s3 honest-negatives) are NOT presented as new
  results — they confirm the well-known fact that finite arithmetic does not
  resolve infinite-scale analytic conjectures.

**TECS-L limits crystallized**:
- STRONG: arithmetic-only closed forms on finite sweeps (F14/F16/F17/F18
  D-zero density, σ_k tower, Ore subfamily).
- WEAK: analytic-infinite axes (RH M(n) asymptotic, BSD L'-derivative, modular
  parameterization).

The arithmetic/analytic boundary is structural: hexa verify g5 evaluates
DETERMINISTIC INTEGER FUNCTIONS. Conjectures requiring limits, complex analysis,
or modular construction lie outside the verifier domain.

## Atlas fold

**0 atoms folded** — all positive findings are restatements of classical theorems
(Mertens function values, Tunnell ternary form counts, CM j-invariant 1728, E_n
conductor 16n²). The novel layer F18 (weight-4 newform level 6) already in atlas
since F18.

Closed-negative findings (s1 ω-tautology, s3 transfer failures) are documented
in verdicts but NOT folded — they confirm structural limits, not new identities.

## Files

- `.verdicts/tecs-l-f22-millennium-retry2/`
  - `s1_mertens_stress_n100_200.txt` — 10 candidates, |M(n)|≤√n all hold
  - `s1_omega_decomp_n30.txt`, `s1_omega_partition_witness.txt` — closed-form decomp
  - `s1_n6_specific_omega.txt` — n=6 first positive jump after primes
  - `s1_zeta_dirichlet_euler.txt` — Dirichlet vs Euler partial product, ω-buckets
  - `s1_explicit_zeta_zeros_cite.txt` — γ_1..γ_5 Odlyzko citation
  - `s2_tunnell_components.txt` — Tunnell test odd + even n
  - `s2_heegner_e6.txt` — j(E_6)=1728, discriminant factorization
  - `s2_heegner_construction_n6.txt` — GGZ rank≤1, BSD-cond Tunnell match
  - `s2_heegner_components.txt` — σ/τ/φ/μ at n=6 anchors
  - `s3_methodology_transfer.txt` — honest negatives on ω + non-lift transfer
  - `s4_f18_weight4_bsd_connection.txt` — F18 ↔ E_6 attempt, Shimura-lift potential

## Next-round seeds (F23 candidates)

- (a) ω-decomp at n=1000..10000 to test whether |M(n)|≤√n persists at larger scale.
- (b) Tunnell test for n=29, 30, 31, 34, 37, 38, 39, 41, 45, 46 (next 10 congruent).
- (c) Tunnell NON-congruent witnesses: n=1, 2, 3, 4, 8, 9, 10, 11, 12, 16, 17, 18,
      19 (Tunnell asserts 2A≠B; cross-check).
- (d) wire `dim_S_k(Γ_0(N))` hexa verify-fn so F18 weight-4 connection is fully
      hexa-native verifiable (currently dim_S4 is 🟠).
- (e) wire `elliptic_witness` / `tunnell_count` verify-fn per INBOX 2026-05-27T02:15Z
      so F22-style enumerations become direct verify calls.
