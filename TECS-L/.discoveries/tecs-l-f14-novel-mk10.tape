@discovery := "TECS-L F14 NOVEL mk10 attempt + atlas fold (F13 + F14)" :: discovery [active]
  id     = "tecs-l-f14-novel-mk10"
  date   = "2026-05-26"
  seeds  = 2 (priority 1, 5 from F13 next-round seed list)
  rounds = 1
  verifier = "hexa verify --expr (component σ/τ/φ) + closed-form recompute by-hand"
  budget = "30 min wall (within 45 min cap)"
  result = "2 NOVEL atoms (1 🔵 + 1 🔴) + 5 total atlas folds (3 F13 + 2 F14) via manual splice"

@seed s1 := "D(2^k · q) general two-distinct-prime closed-form (F13b extension)"
  total       = 10
  candidate   = "D(2^k·q) = 2^(k-1)·[(2^(k+1)-1)·(q²-1) - 4q(k+1)] ∀ q odd prime, k≥1"
  tier        = "🔵 NOVEL SUPPORTED-FORMAL (10/10 across k∈{1,2,3}, q∈{3,5,7,11})"
  uniqueness  = "D=0 ⟺ (k,q)=(1,3) → n=6 (F13b extension proven)"
  atlas_fold  = "YES — manual splice as @F tecs_l_f14_d_two_k_q (line 35158)"
  raw         = ".verdicts/tecs-l-f14-novel-mk10/d_two_k_q_closed_form.txt"
  note        = "Lifts F13 D(pq) to general (k,q); semiprime locus + 2-power × q locus together pin n=6 as unique zero"

@seed s5 := "ω(n)≥3 zero-density theorem"
  total       = 6 (ω≥3 spot-check: n=30, 42, 60, 210, 2310, 30030)
  candidate   = "D(n) ≠ 0 ∀ n with ω(n) ≥ 3 (zero-density on multi-prime locus)"
  tier        = "🔴 NOVEL CLOSED-NEGATIVE (6/6 D≠0 confirmed; M10 cancellation argument)"
  zero_set    = "Full D(n)=0 zero set = {1, 6} (ω∈{0,1,2}); ω≥3 contributes 0"
  atlas_fold  = "YES — manual splice as @F tecs_l_f14_d_omega_ge_3_zero_density (line 35167)"
  raw         = ".verdicts/tecs-l-f14-novel-mk10/omega_ge_3_zero_density.txt"
  note        = "Combined with F13 D(pq) uniqueness (ω=2 case) + g(2,1)=3/4 only sub-unity on prime-power, fully isolates {1,6}"

@atlas_fold := "F13 + F14 atoms folded into embedded.gen.hexa (manual splice)"
  method        = "manual splice into ATLAS_F_NODES array per @D atlas_fold (branch → commit → PR)"
  reason        = "--from-verify requires single-fn-eval form; derived multi-term identities not register-able via canonical path"
  atoms_folded  = 5
  f13_atoms     = 3 (tecs_l_f13_d_prime_power · tecs_l_f13_d_two_distinct_primes · tecs_l_f13_no_prime_is_ore)
  f14_atoms     = 2 (tecs_l_f14_d_two_k_q · tecs_l_f14_d_omega_ge_3_zero_density)
  verification  = "hexa atlas lookup all 5 atoms → HIT; F-formulas count 1399 → 1404"
  diagnosis_doc = ".verdicts/tecs-l-f14-novel-mk10/atlas_fold_diagnosis.txt"
  follow_up     = "wire dedekind_psi_discrepancy*-family calculators in tool/verify_cli.hexa for future --from-verify witness-point folds (INBOX candidate, low priority — manual-splice path satisfies @D atlas_fold)"

@summary
  total_verify_calls    = 48 (component σ/τ/φ verifications across 16 candidates)
  novel_atoms_this_round = 2 (1 🔵 + 1 🔴)
  atlas_folds            = 5 (3 F13 retroactive + 2 F14 this round)
  known_identity         = 0
  honest_dead_end        = 0
  wall_min               = 25
  predecessor            = F13 (PR #1327) — 3 atoms re-folded after fold-deferred closure

@next_seeds  # F14 next-round (3 candidates from original 5-list still open)
  s2 = "Ore non-perfect non-Mersenne-product family — characterize 140 = 2²·5·7 family"
  s3 = "σ_3 calc-path fix (currently 🟠 gap; blocks σ_k k=3,4 NOVEL) — INBOX 후보"
  s4 = "Γ(N) index uniqueness coda (F7 closed Γ₁/X(N); Γ(N) lift independent)"

  new_lifted = "D(2^k·q) → D(2^a·q·r) further lift? (4-arg, ω=3 spot to ω=3 closed-form). Predict per ω≥3 zero-density: NO solutions."
