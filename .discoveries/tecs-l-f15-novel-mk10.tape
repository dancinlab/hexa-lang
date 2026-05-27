@V := "tape" :: spec [active]
  version = "1.2"

# TECS-L axis F (NOVEL) F15 — F14-successor batch (s1+s2+s3+s4).
# 4 tasks: D(2^a·q·r) omega=3 lift · Ore non-perfect family · sigma_3 INBOX · Gamma(N) coda.

@X tecs_l_f15_d_two_a_q_r := "F15 NOVEL closed-form atom (s1): D(2^a·q·r) = 2^(a-1) · [(2^(a+1)-1)(q^2-1)(r^2-1) - 8qr(a+1)], distinct odd primes q!=r, a>=1; D != 0 for all 10 sampled triples (336..16048). omega=3 explicit-form witness of F14 zero-density theorem." :: discovery [slug=tecs-l-f15-novel-mk10 group=TECS-L]
  date                = "2026-05-27"
  host                = "Mac workstation isolated worktree"
  engine              = "closed-form derivation + hexa verify --expr (sigma/euler_phi/tau × 30 components × 10 triples)"
  verdict_tier_target = "BLUE SUPPORTED-FORMAL"
  result              = "10/10 PASS; F14 omega>=3 zero-density confirmed on explicit-form locus"
  atlas               = "tecs_l_f15_d_two_a_q_r (manual splice, F-formulas 1404->1405)"
  paper_target        = "extends n6-exclusivity-atlas (paper_significance via pre-registered F14 theorem)"

@X tecs_l_f15_ore_non_perfect_no_closed_form := "F15 NOVEL closed-negative atom (s2): Ore-but-not-perfect family has NO uniform closed-form generator. 5 witnesses {270,672,1638,2970,6200} span heterogeneous omega in {3,4} + exponent multisets. Analogous to F7 modular-curve non-lift." :: discovery [slug=tecs-l-f15-novel-mk10 group=TECS-L]
  date                = "2026-05-27"
  host                = "Mac workstation isolated worktree"
  engine              = "OEIS A001599 minus perfect + hexa verify --expr (sigma/tau × 10 components × 5 candidates)"
  verdict_tier_target = "RED CLOSED-NEGATIVE"
  result              = "5/5 Ore + 5/5 non-perfect; H values {6,8,9,11,10}; family-closed-form non-existence"
  atlas               = "tecs_l_f15_ore_non_perfect_no_closed_form (manual splice, F-formulas 1405->1406)"
  paper_target        = "paper_negative_ok eligible — Ore-shape closed-form lift ruled out"

@X tecs_l_f15_sigma_3_calc_gap := "F15 honest INSUFFICIENT atom (s3): hexa verify --expr sigma_3 6 252 returned 'calculator system has NO path for sigma_3'. stdlib/core/math.hexa lacks sigma_3 def. INBOX filed (calc-gap family #1230 extension)." :: discovery [slug=tecs-l-f15-novel-mk10 group=TECS-L]
  date                = "2026-05-27"
  host                = "Mac workstation isolated worktree"
  engine              = "hexa verify --expr sigma_3 6 252 --no-absorb + stdlib grep"
  verdict_tier_target = "ORANGE INSUFFICIENT (paper-ineligible by gate)"
  result              = "sigma_3 path absent; F11 OEIS provenance present in atlas but verify-calc path absent"
  atlas               = "no fold (honest gap)"
  paper_target        = "none — INBOX item for tool/verify_cli.hexa::_recompute extension"

@X tecs_l_f15_gamma_full_level_smooth := "F15 NOVEL closed-negative atom (s4): [SL_2(Z):Gamma(N)] = N^3 * prod(1-1/p^2) smooth/multiplicative in N; n=6 NOT distinguished at full-level X(N). F7 coda confirmed at full level — {1,6} uniqueness is arithmetic-function-layer property." :: discovery [slug=tecs-l-f15-novel-mk10 group=TECS-L]
  date                = "2026-05-27"
  host                = "Mac workstation isolated worktree"
  engine              = "10-sample N component verify (gamma0_index + euler_phi × 20 components) + ratio analysis"
  verdict_tier_target = "RED CLOSED-NEGATIVE"
  result              = "10/10 component PASS; ratio Gamma(N)/Gamma_0(N) = N*phi/2 smooth (N=3 ratio 3 < N=6 ratio 6); n=6 NOT a peak at full level"
  atlas               = "tecs_l_f15_gamma_full_level_smooth (manual splice, F-formulas 1406->1407)"
  paper_target        = "paper_negative_ok eligible — Gamma(N) lift ruled out (extends F7 paper)"
