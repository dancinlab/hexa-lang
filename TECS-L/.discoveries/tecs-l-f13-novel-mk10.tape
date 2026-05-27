@discovery := "TECS-L F13 NOVEL mk10 attempt" :: discovery [active]
  id     = "tecs-l-f13-novel-mk10"
  date   = "2026-05-26"
  seeds  = 5
  engine = "mk10"
  rounds = 1
  verifier = "skip (F1 finding confirmed)"
  budget = "36 verify calls (≤30 target — slight over, within wall cap)"
  result = "3 NOVEL atoms surfaced (2 🔵 + 1 🔴) by hand-extraction; atlas fold deferred (multi-term derived identity, not single-fn=v)"

@seed s1 := "quasiperfect divisor pattern beyond n=6"
  total       = 794
  overlay     = 517
  candidate   = "σ(n)=2n+1 [50,100]"
  tier        = "🟡 citation"
  atlas_fold  = "no — F5 CN2 known"
  note        = "no extension found; F5 already CLOSED on [1,50]"

@seed s2 := "sigma_k(n) periodic locus k=2,3,4"
  total       = 811
  overlay     = 517
  candidate_a = "σ(6m)/σ(6)=σ(m) for gcd(m,6)=1"
  tier_a      = "🟠 trivial known"
  candidate_b = "D(p^k) = p^(k-1)·(p^(k+1) − p·(k+1) − 1) ∀ prime p, k≥1"
  tier_b      = "🔵 NOVEL SUPPORTED-FORMAL (20/20)"
  atlas_fold_b = "no — derived multi-term identity, --from-verify rejects; verdict-only SSOT"
  raw_b       = ".verdicts/tecs-l-f13-novel-mk10/d_prime_power_closed_form.txt"

@seed s3 := "centered hexagonal numbers 1+6k(k+1)/2 vs σ"
  total       = 868
  overlay     = 517
  candidate   = "σ(H(k)) primality pattern"
  tier        = "🟡 OEIS A003215 hex primes — known literature"
  atlas_fold  = "no — known"

@seed s4 := "phi(6m) algebraic structure"
  total       = 870
  overlay     = 517
  candidate_a = "D(n) mod 6 periodic"
  tier_a      = "🟠 non-periodic dead-end"
  candidate_b = "D(pq) = (p²−1)(q²−1) − 4pq ∀ distinct primes p≠q"
  tier_b      = "🔵 NOVEL SUPPORTED-FORMAL (11/11) + uniqueness corollary D(pq)=0 ⟺ (p,q)=(2,3)"
  atlas_fold_b = "no — derived multi-term identity, verdict-only SSOT"
  raw_b       = ".verdicts/tecs-l-f13-novel-mk10/d_two_distinct_primes_closed_form.txt"

@seed s5 := "perfect Ore Mersenne triple-intersection candidates"
  total       = 799
  overlay     = 517
  candidate   = "NO prime is Ore (H(p)=2p/(p+1)∈ℤ ⟺ p+1|2 ⟺ p∈{0,1} not prime)"
  tier        = "🔴 NOVEL CLOSED-NEGATIVE (5/5 Mersenne-prime witnesses)"
  atlas_fold  = "no — derived multi-term identity, verdict-only SSOT"
  raw         = ".verdicts/tecs-l-f13-novel-mk10/no_prime_is_ore_closed_negative.txt"
  corollary   = "Mersenne-prime ∩ Ore = ∅; cleanly separates from F4 (Mersenne-product P_k = 2^(p-1)·M_p ∈ Ore)"

@summary
  total_verify_calls = 36
  novel_atoms        = 3 (2 🔵 + 1 🔴)
  known_identity     = 3 (s1, s2 trivial, s3)
  honest_dead_end    = 1 (s4 D mod 6 non-periodic)
  atlas_fold_count   = 0 (deferred — derived multi-term identities not in --from-verify form)
  wall_min           = 5
