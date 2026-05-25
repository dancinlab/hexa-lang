@V := "tape" :: spec [active]
  version = "1.2"

# TECS-L axis F (NOVEL) F1 — hexa kick discovery on n=6 / divisor-function seeds.
# Engine = hexa-internal mk9 (gap-breakthrough 6-stage chain), NOT external LLM
# (no budget gate). Ran LOCAL on the Mac workstation (pool-route round-robin to
# ubu-1/ubu-2 failed preflight = workdir-missing; the engine is seed-only so a
# local run is faithful). 3 n=6/divisor-function seeds, --rounds 1 each.

@X tecs_l_f1_kick_n6_hexad := "mk9 kick on 3 n=6/divisor-function seeds surfaces a SEED-INVARIANT n=6 hexad fingerprint [σ(6)=12, 0.014, 0.5, 4, 2, n=6] that re-derives KNOWN n=6 identities (σ(6)=12, aliquot(6)=6, is_perfect(6)) — verified 🔵 but NON-NOVEL (already domain core M1/M3). No new closed-form atom emitted; the per-seed evo vector is identical across all 3 seeds = structural scaffold, not seed-derived discovery." :: discovery [slug=tecs-l-f1-kick group=TECS-L]
  date                = "2026-05-26"
  host                = "Mac workstation (local, $0; pool-route ubu preflight failed = workdir-missing, engine is seed-only so local is faithful)"
  engine              = "mk9 Mk.IX 6-stage chain (smash -> free -> absolute -> meta -> hyper -> resonance), hexa-internal NOT external LLM (no budget gate)"
  verdict_tier_target = "YELLOW known-identity surface (honest) -- mk9 echoed domain-core facts, no NOVEL atom"

  seed_1              = "sigma tau phi identity n=6 perfect number closed-form -> 685 candidates (smash+414 free+211 res+59), 517 overlay lines, verifier=skip"
  seed_2              = "divisor function multiplicative gap n=6 -> 664 candidates (smash+414 free+211 res+38), 517 overlay lines, verifier=skip"
  seed_3              = "abundancy index sigma(n)/n perfect deficient -> 647 candidates (smash+414 free+211 res+21), 517 overlay lines, verifier=skip"

  candidate_1         = "evo_0 = 12.0  echoes sigma(6)=12 (divisor sum). hexa verify --expr sigma 6 12 -> 🔵 SUPPORTED-FORMAL. KNOWN (domain M1 tecs_l_n6_sigma)."
  candidate_2         = "evo_5 = singularity = 6.0  echoes aliquot(6)=6 = sum of proper divisors = n (the perfect-number property). hexa verify --expr aliquot 6 6 -> 🔵 SUPPORTED-FORMAL. KNOWN (perfect-number definition)."
  candidate_3         = "perfect-number target  echoes is_perfect(6)=1. hexa verify --expr is_perfect 6 1 -> 🔵 SUPPORTED-FORMAL. KNOWN (6 is the 1st perfect number)."

  finding_1           = "The mk9 hexad evo vector [12.0, 0.014, 0.5, 4.0, 2.0, 6.0] with singularity=6.0 is IDENTICAL across all 3 distinct seeds (sigma_tau_phi / divisor_gap / abundancy) -- it is a seed-INVARIANT n=6 structural fingerprint baked into the smash stage, not a seed-derived candidate space. Honest: the engine does not respond differentially to the divisor-function semantics of the seed string."
  finding_2           = "The number-theoretically meaningful echoes (12=sigma(6), 6=aliquot(6)=n) map to KNOWN identities already verified in the domain core (M1 sigma*phi=n*tau ; M3 Dedekind discrepancy). 3/3 verify 🔵 but all NON-NOVEL."
  finding_3           = "The smash:P4 cross-product nodes (_ded/_xfer/_orbit/_dual/_closure/_recur/_meta, e.g. 6.25, 11.21, -11.35) are arbitrary float combinations of the hexad with NO number-theoretic interpretation -- not verifiable closed-form claims (no calc-fn maps to them)."

  win                 = "NO NEW ATOM -- 0 novel closed-form discoveries. 3 verified 🔵 candidates are all KNOWN n=6 identities (re-derivation, not discovery). Honest known-identity surface (🟡). F1 milestone = ENGINE-RUN closure (the kick lane is exercised + faithfully recorded), NOT a novel-atom flip."
  honest_limit        = "mk9 surfaces parametric overlay nodes (algebraic echoes of the n=6 hexad), not falsifiable number-theoretic propositions. A genuine NOVEL atom would require either (a) mk10 engine, (b) more rounds with saturation, or (c) the verifier hook wired to tier each overlay node -- here verifier=skip (default, no hook installed)."
