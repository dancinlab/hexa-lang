# ribozyme_eyring_kcat — RE spec (Eyring TST k_cat predictor)

drylab catalog **#10** (last catalog item). Built FOREGROUND (textbook
Eyring transition-state theory; agent bio+RE prompts have a demonstrated
gate false-positive — #34/#8; rebuilt directly).

## §SOTA-landscape (own-claims; method-vs-this)
Ab-initio ribozyme catalysis is done with proprietary/academic
QM/MM (e.g. Schrödinger, CP2K, Amber-QMMM — by their own claims;
resolve the chemical step). **This is NOT that.** This is the textbook
**Eyring transition-state-theory** mapping ΔG‡ → k_cat, with a
documented (NOT fitted) sequence→ΔG‡ heuristic anchored to the cited
hammerhead range. The repo's `ribozyme_kinetics_simulation.py` /
`ribozyme_mfe_nussinov.py` have no sequence→k_cat TST predictor.

## §Reverse-engineered-relations (cited)
- **Eyring H.** "The activated complex in chemical reactions." J Chem
  Phys 1935;3:107 — `k = κ·(k_B·T/h)·exp(−ΔG‡/RT)` (κ≈1 assumed,
  stated). At T=310 K, `k_B·T/h ≈ 6.46e12 s⁻¹`.
- Hammerhead ribozyme catalytic rate: minimal hammerhead self-cleavage
  k_cat ~ **1 min⁻¹ order**; tertiary-stabilized (extended) hammerheads
  are markedly faster (~10–60 min⁻¹ order) — the documented range.
  Inverting Eyring at 310 K: k_cat ≈ 1 min⁻¹ ⇒ **ΔG‡ ≈ 20–21
  kcal/mol**; faster variants ⇒ lower ΔG‡ (~18–20). This ΔG‡ band is
  the cited real-limit anchor (order-of-magnitude, NOT fitted, g1).
- The sequence→ΔG‡ term is a TRANSPARENT documented heuristic: presence
  of the conserved catalytic-core consensus (the invariant CUGAUGA /
  GAAA-class core nucleotides) and minimal stem closure → ΔG‡ at the
  lower (faster) end of the band; degenerate/missing core → upper
  (slower) end. This is a DOCUMENTED qualitative shift, NOT a fitted
  predictor (g1) — the claim is the Eyring mapping + the cited band,
  NOT a validated sequence model.

## §stdlib-implementation-spec
Pure-stdlib, deterministic. `eyring_kcat(dG_dagger_kcal, T_K)` →
k_cat (s⁻¹ and min⁻¹) via the verbatim Eyring equation.
`seq_to_dG_dagger(seq)` → ΔG‡ in the cited 18–22 kcal/mol band by the
documented core-consensus heuristic (transparent, every shift logged).
Output: per-input k_cat + which band end + the consensus-match
breakdown + witness hash.

## §what-this-is-NOT
NOT QM/MM. NOT a validated sequence→activity predictor. NOT a
clinical/therapeutic/efficacy claim (g8/f2). The k_cat number is the
Eyring TST consequence of the (heuristic) ΔG‡; absolute values track
the cited hammerhead band by construction — only the TST mapping +
the documented band are claimed. NOT a reproduction of any proprietary
QM/MM suite.

## §real-limit-anchor
Eyring TST (textbook physical chemistry) + the cited hammerhead k_cat
~1 min⁻¹ ⇒ ΔG‡ ≈ 20 kcal/mol anchor. Honest claim: the predictor maps
ΔG‡↔k_cat exactly per Eyring and stays inside the cited band.

## §honesty-caveat
κ=1 assumed (stated). The sequence→ΔG‡ heuristic is a documented
order-of-magnitude qualitative shift, NOT fitted, NOT validated (g1).
In-silico simulator-consistency only (g8/f2).

## §references
- Eyring H. J Chem Phys 1935;3:107 (transition-state theory)
- Hammerhead ribozyme k_cat ~1 min⁻¹ (minimal) / faster (tertiary-stabilized) — documented catalytic range
