@V := "tape" :: spec [active]
  version = "1.2"

# TECS-L axis F (NOVEL) F16 — F15-successor batch (s1+s2+s3+s4).
# 4 tasks: sigma_3 calc-gap CLOSED-by-2-op · omega=4/5 D-sweep · A001599 Ore subfamily · Hecke/Galois layer probe.

@X tecs_l_f16_sigma_3_euclid_euler_closed_form := "F16 NOVEL closed-form atom (s1): sigma_3(2^(p-1)*M_p) = [(2^(3p)-1)/7] * [1 + (2^p-1)^3], M_p Mersenne prime. F15 sigma_3 INBOX entry CLOSED-by-design — 2-op sigma_k <n> 3 <v> path bypasses single-arg _recompute gap (no verify_cli code change). 4/4 PASS on Euclid-Euler perfects: sigma_3(6)=252, sigma_3(28)=25112, sigma_3(496)=139456352, sigma_3(8128)=613681507712." :: discovery [slug=tecs-l-f16-novel-mk10 group=TECS-L]
  date                = "2026-05-27"
  host                = "Mac workstation isolated worktree"
  engine              = "2-op sigma_k path discovery + closed-form derivation + hexa verify --expr (--no-absorb)"
  verdict_tier_target = "BLUE SUPPORTED-FORMAL"
  result              = "4/4 PASS on in-int64-range perfects; closed-form bignum extrapolation to P_5..P_7"
  atlas               = "tecs_l_f16_sigma_3_euclid_euler_closed_form (manual splice)"
  paper_target        = "extends n6-exclusivity-atlas (sigma_3 layer Euclid-Euler closed-form)"

@X tecs_l_f16_d_omega_4_5_zero_density := "F16 NOVEL closed-negative atom (s2): D(n) != 0 for ALL 8 tested omega=4 (n in {210,330,420,1155}) and omega=5 (n in {2310,2730,4620,9240}) candidates. F14 omega>=3 zero-density theorem confirmed predictably beyond F15 explicit omega=3 witness." :: discovery [slug=tecs-l-f16-novel-mk10 group=TECS-L]
  date                = "2026-05-27"
  host                = "Mac workstation isolated worktree"
  engine              = "explicit omega=4/5 sample sweep + hexa verify --expr (sigma/phi/tau × 24 components)"
  verdict_tier_target = "RED CLOSED-NEGATIVE"
  result              = "8/8 PASS (D != 0); 24/24 components BLUE; D values {24288,63840,118944,1087440,3243840,4557504,15261120,65763840}"
  atlas               = "tecs_l_f16_d_omega_4_5_zero_density (manual splice)"
  paper_target        = "extends n6-exclusivity-atlas (omega=4/5 explicit witness)"

@X tecs_l_f16_ore_mersenne_extended_subfamily := "F16 NOVEL partial closed-form atom + counterexample (s3): for n = 2^a * b * M_p (b coprime to 2*M_p), H(n) = [2^(a+1) * b * M_p * (a+1) * tau(b)] / [(2^(a+1)-1) * sigma(b) * 2^p] from H-multiplicativity. 4 witnesses (140, 672, 6200, 105664) integer-divisibility verified. Counterexample n=270=2*3^3*5 Ore but NO Mersenne factor — universality FALSIFIED; subfamily PROPER subset, F15 universal Ore-NEG holds at outer level." :: discovery [slug=tecs-l-f16-novel-mk10 group=TECS-L]
  date                = "2026-05-27"
  host                = "Mac workstation isolated worktree"
  engine              = "A001599 next-50 family structure scan + multiplicativity derivation + hexa verify --expr (--no-absorb)"
  verdict_tier_target = "BLUE SUPPORTED-FORMAL (subfamily) + RED CLOSED-NEGATIVE (universality)"
  result              = "4/4 Mersenne-extended witnesses verified; n=270 universality counterexample identified; F15 universal-NEG sharpened"
  atlas               = "tecs_l_f16_ore_mersenne_extended_subfamily (manual splice)"
  paper_target        = "extends n6-exclusivity-atlas (Ore subfamily structure + universality NEG)"

@X tecs_l_f16_hecke_galois_arithmetic_layer := "F16 NOVEL closed-negative atom (s4): n=6 sigma*phi=n*tau identity does NOT lift to Hecke eigenvalue or Galois representation layer; remains arithmetic-layer phenomenon. F7/F15 modular non-lift program CLOSED through Hecke (S_k(Gamma_0(6)) generic oldform decomposition, no n=6 peak) + Galois (Gal(Q(zeta_6)/Q)=Z/2Z=Gal(Q(zeta_3)/Q), pure phi-degeneracy not sigma*phi=n*tau driven)." :: discovery [slug=tecs-l-f16-novel-mk10 group=TECS-L]
  date                = "2026-05-27"
  host                = "Mac workstation isolated worktree"
  engine              = "Hecke layer probe (dim_cusp_forms hexa-native) + Galois cyclotomic structure derivation + hexa verify --expr phi"
  verdict_tier_target = "RED CLOSED-NEGATIVE"
  result              = "4/4 phi components BLUE; T_p builtin gap honest-fenced (calc-gap family with resolved sigma_3)"
  atlas               = "tecs_l_f16_hecke_galois_arithmetic_layer (manual splice)"
  paper_target        = "extends n6-exclusivity-atlas (multilayer non-lift coda completing F7/F15 program)"
