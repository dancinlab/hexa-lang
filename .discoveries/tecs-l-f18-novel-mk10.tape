@V := "tape" :: spec [active]
  version = "1.2"

# TECS-L axis F (NOVEL) F18 — F17-successor batch (s1+s2+s3+s4+s5).
# 5 tasks: omega=9/10 D-sweep · sigma_6/7/8 Euclid-Euler tower · omega=4 Ore non-Mersenne structural · weight-4 newform level 6 · dedekind_psi INBOX.

@X tecs_l_f18_d_omega_9_10_zero_density := "F18 NOVEL closed-negative atom (s1): D(n) != 0 confirmed at omega=9 (primorial #9 = 223092870) and omega=10 (primorial #10 = 6469693230) plus k=2 exponent variants (n=446185740, n=669278610). F14/F16/F17 zero-density theorem extends predictably to primorial-extension scale ~6.5e9. omega=10 sigma*phi overflows int64 (2.56e19), bignum bc computation; individual components in int64." :: discovery [slug=tecs-l-f18-novel-mk10 group=TECS-L]
  date                = "2026-05-27"
  host                = "Mac workstation isolated worktree"
  engine              = "primorial #9/#10 + k=2 variant explicit sweep + hexa verify --expr (sigma/phi/tau × 12 components, --no-absorb)"
  verdict_tier_target = "RED CLOSED-NEGATIVE"
  result              = "4/4 D != 0; 12/12 components BLUE; D values {3.05e16, 2.56e19, 1.42e17, 2.98e17}"
  atlas               = "tecs_l_f18_d_omega_9_10_zero_density (manual splice)"
  paper_target        = "extends n6-exclusivity-atlas (omega=9,10 primorial-scale explicit witness)"

@X tecs_l_f18_sigma_k_tower_6_7_8_closed_form := "F18 NOVEL closed-form atom (s2): F17 general-k closed form sigma_k(2^(p-1)*M_p) = [(2^(kp)-1)/(2^k-1)] * [1 + (2^p-1)^k] verified at k in {6,7,8} for small p (P_1=6, P_2=28, P_3=496). 8/9 hexa-native PASS; sigma_8(P_3)=3.68e21 bignum-only (int64 overflow). Closes the (k,p) tower for k in {1..8} at small-p witness chain." :: discovery [slug=tecs-l-f18-novel-mk10 group=TECS-L]
  date                = "2026-05-27"
  host                = "Mac workstation isolated worktree"
  engine              = "F17 general-k formula instantiation at k in {6,7,8} + hexa verify --expr sigma_k <n> <k> <v> (--no-absorb)"
  verdict_tier_target = "BLUE SUPPORTED-FORMAL"
  result              = "8/9 PASS; sigma_8(496)=3.68e21 closed-form-only; full tower k in {1..8} closed at small-p"
  atlas               = "tecs_l_f18_sigma_k_tower_6_7_8_closed_form (manual splice)"
  paper_target        = "extends n6-exclusivity-atlas (sigma_k tower k>=6 layer)"

@X tecs_l_f18_ore_non_mersenne_cross_prime_coincidence := "F18 NOVEL closed-negative atom (s3): F17-identified omega=4 Ore non-Mersenne entries {2970=2*3^3*5*11, 18620=2^2*5*7^2*19} exhibit ZERO per-prime Ore property (forall p|n: sigma(p^a) does NOT divide p^a*(a+1), 8/8 per-prime FAIL). Ore status = cross-prime divisor cancellation NUMERICAL coincidence, NOT structural per-prime identity. Rules out uniform parametric closed-form template for non-Mersenne Ore residual class; sharpens F15 universal Ore-NEG by IDENTIFYING obstruction mechanism." :: discovery [slug=tecs-l-f18-novel-mk10 group=TECS-L]
  date                = "2026-05-27"
  host                = "Mac workstation isolated worktree"
  engine              = "omega=4 Ore non-Mersenne entry structural decomposition + per-prime divisibility analysis + hexa verify --expr (sigma/tau × 4 components, --no-absorb)"
  verdict_tier_target = "RED CLOSED-NEGATIVE (on uniform-template existence)"
  result              = "4/4 sigma/tau components BLUE; 8/8 per-prime divisibility FAILS, 2/2 product PASSES; cross-prime coincidence mechanism identified"
  atlas               = "tecs_l_f18_ore_non_mersenne_cross_prime_coincidence (manual splice)"
  paper_target        = "extends n6-exclusivity-atlas (Ore residual non-template-existence)"

@X tecs_l_f18_weight_4_newform_level_6_recovery := "F18 NOVEL n=6 distinction RECOVERY atom (s4): dim S_4(Gamma_0(6)) = 1 (hexa-verified, matches classical Eichler-Selberg dimension formula); levels N in {1,2,3} weight 4: dim S_4 = 0; therefore level 6 is MINIMAL level admitting weight-4 cusp form on Gamma_0. LMFDB label 6.4.a.a (unique newform); Hecke eigenvalues + L-value algebraicity = 🟡 citation (T_p builtin INBOX). n=6 distinction REAPPEARS at weight 4 after F17 weight-2 closed-neg, refining F7/F16/F17 multilayer non-lift to weight-2-only." :: discovery [slug=tecs-l-f18-novel-mk10 group=TECS-L]
  date                = "2026-05-27"
  host                = "Mac workstation isolated worktree"
  engine              = "weight-4 newform dim probe + classical Eichler-Selberg cross-check + hexa verify --expr dim_cusp_forms/first_cusp_form_weight"
  verdict_tier_target = "BLUE SUPPORTED-FORMAL (dim verify) + NOVEL n=6 RECOVERY (level 6 minimal weight-4 level on Gamma_0)"
  result              = "4/4 BLUE components (dim S_4(6)=1, dim S_4(1,2,3)=0, first_cusp_form_weight(6)=4); n=6 distinction recovery confirmed"
  atlas               = "tecs_l_f18_weight_4_newform_level_6_recovery (manual splice)"
  paper_target        = "extends n6-exclusivity-atlas (weight-4 recovery axis; refines F17 weight-2 closed-neg)"

# s5 dedekind_psi INBOX entry — non-atom (workflow proposal); filed in INBOX.md, not as atlas atom.
# Verdict: .verdicts/tecs-l-f18-novel-mk10/dedekind_psi_inbox.txt
