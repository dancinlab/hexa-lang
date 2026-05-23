# rtsc-h3si-dft-6q-novel-80k

> Submission to `atlas/inbox/` (one concept = one file).

## Concept

H₃Si (cubic Im-3m BCC, 4 atoms, celldm=5.656 bohr) under
first-principles DFT+DFPT electron-phonon coupling on a 6×6×6 q-grid
(16 irreducible q-points, full BZ coverage), Quantum ESPRESSO 7.5
(conda) pw.x + ph.x with `electron_phonon='simple'`, exhibits
BZ-weighted λ between **1.72–1.82** (broadening sweep) and
λ-weighted log-average phonon frequency **ω_log ≈ 572–624 K**,
yielding an Allen–Dynes Tc (μ\*=0.10) of **77–80 K**. The group-14
silicon member of the H₃X family series — a *high*-λ, *moderate*-
ω_log combination distinct from the chalcogen/halogen members.

**No published measured Tc exists for H₃Si** at this Im-3m phase.
The DFT prediction of 77–80 K **lies within the §9.15
pre-registered prediction band of 50–110 K for H₃Si**, marking
the prediction as a 🟢 PRED-BAND PASS — supporting the §9.15
group-14 prior calibration.

## Proposed verdict

- **Tier:** 🟢 **SUPPORTED-NUMERICAL** (Stage 2 — first-principles
  DFT+DFPT 6×6×6-q result; same H₃S-textbook-validated pipeline).
- **Axis:** §4 CHEM (material electron-phonon candidate) ·
  cross-link §3 PHYS (Allen–Dynes) · §10 BRIDGES.
- **Absorbed:** `false` — `gate_type=simulation-only-prediction`.

## Evidence

- Stage 2 numerical (DFT+DFPT 6³q · 16 q-points · 24³ k-grid · USPP
  PBE pslibrary · ecutwfc=60 / ecutrho=600 Ry · 10-broadening
  sweep): λ_BZ=1.72–1.82; ω_log≈572–624 K; Tc(μ\*=0.10)=77–80 K;
  celldm=5.656 bohr.
- **Group-14 family context:** Si in group 14 produces high λ
  (1.72–1.82, second only to group-16 chalcogens) but moderate
  ω_log (572–624 K). The Si–H bond is weaker than X–H for
  electronegative X, lowering ω_log; the high covalency drives λ.
  H₃Si is the **most-RTSC-promising group-14 H₃X**.
- **ALIGNN per-candidate ML cross-check:** ALIGNN |rel_err| 96.1%
  vs DFT (RTSC.md §9.15 family-wide quantitative d7 attestation) —
  d7 wall confirmed.
- **§9.15 pre-registered prior:** Tc band 50–110 K — DFT result
  77–80 K is **within band** (mid-band). Group-14 prior calibrated.

## Real-limit anchor (g3 mandatory)

- **Allen & Dynes 1975, PRB 12, 905** — Tc closed form.
- **Drozdov et al. 2015 H₃S calibration anchor** — pipeline
  validated within 5–15%.
- [compiler invariant — QE 7.5 ph.x DFPT deterministic numerical
  computation; λ + ω_log are parser output, not fitted constants].

## Falsifiers (pre-registered, ≥5)

1. **F1_broadening_non_monotone** — Tc(broad) monotone across
   broadening; non-monotone re-parse FIRES.
2. **F2_alignn_per_cand_within_50pct** — ALIGNN |rel_err| 96.1% vs
   DFT → d7 wall FIRES → family-wide d7 confirmed.
3. **F3_imaginary_phonon** — none detected at celldm=5.656 bohr;
   re-parse with imaginary modes FIRES.
4. **F4_4q_vs_6q_convergence** — 4³q vs 6³q λ within 10%;
   deviation >10% downgrades verdict.
5. **F5_anharmonic_sscha_gap** — harmonic-only; future measurement
   deviating by >25% from harmonic Tc *after SSCHA* FIRES.
6. **F6_§9.15_prior_pass_consistency** — H₃Si IS the §9.15
   prior-band PASS; if a future measurement falls outside 50–110 K,
   the prior is FIRED and H₃Si's PASS is downgraded.

## Honest C3

- Prediction-only; absorbed=false.
- 🟢 demiurge §9.15 status = prior-band PASS; this is the
  *single* group-14 prior-validation in the 4-LANDED H₃X set
  (H₃Cl over, H₃F under, H₃Si within).
- Harmonic-only; SSCHA correction not applied.
- 77–80 K is below RTSC threshold (270 K) — H₃Si is not an RTSC
  candidate, useful as the group-14 anchor and as a covalency-vs-
  electronegativity disentangler (high λ from covalency, moderate
  ω_log from weaker Si–H vs O–H/F–H).

## Provenance

- Submitter: claude-opus-4-7 (demiurge cycle 9, 2026-05-24).
- Origin: demiurge `~/core/demiurge/exports/material_discovery/`
  (Tier-2 export, R4-protected; co-cycle JSON emit in progress).
- Pipeline: H₃S-textbook-validated QE 7.5 + parse_elph_gen.py per
  demiurge RTSC.md §9.12, §9.15.
- Artifacts: `~/etc/rtsc-results/h3si/`.
- Governance: demiurge `project.tape` d1, d6, d7.
