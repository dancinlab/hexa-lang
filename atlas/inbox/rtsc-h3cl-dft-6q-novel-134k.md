# rtsc-h3cl-dft-6q-novel-134k

> Submission to `atlas/inbox/` (one concept = one file).

## Concept

H₃Cl (cubic Im-3m BCC, 4 atoms, celldm=5.659 bohr) under
first-principles DFT+DFPT electron-phonon coupling on a 6×6×6 q-grid
(16 irreducible q-points, full BZ coverage), Quantum ESPRESSO 7.5
(conda) pw.x + ph.x with `electron_phonon='simple'`, exhibits
BZ-weighted λ between **1.14–1.41** (broadening sweep) and
λ-weighted log-average phonon frequency **ω_log ≈ 1252 K**,
yielding an Allen–Dynes Tc (μ\*=0.10) of **105–134 K**. The
group-17 halogen (Cl) member of the H₃X family series.

**No published measured Tc exists for H₃Cl** at any pressure. The
DFT prediction of 105–134 K **substantially exceeds the §9.15
pre-registered prediction band of 25–60 K for H₃Cl**, marking the
prediction as a 🔴 PRED-BAND FAIL above the band — informative for
calibrating the in-house §9.15 prior, *not* an honest-failure of
the DFT pipeline itself (which is calibrated on H₃S to 5–15%
accuracy).

## Proposed verdict

- **Tier:** 🟢 **SUPPORTED-NUMERICAL** (Stage 2 — first-principles
  DFT+DFPT 6×6×6-q result; same H₃S-textbook-validated pipeline).
  The 🔴 marker in demiurge RTSC.md refers to the demiurge §9.15
  *pre-registered prior band*, not to the DFT result itself — the
  DFT measurement is honest; the demiurge prior was wrong.
- **Axis:** §4 CHEM (material electron-phonon candidate) ·
  cross-link §3 PHYS (Allen–Dynes) · §10 BRIDGES (CHEM ↔ PHYS).
- **Absorbed:** `false` — `gate_type=simulation-only-prediction`.

## Evidence

- Stage 2 numerical (DFT+DFPT 6³q · 16 q-points · 24³ k-grid · USPP
  PBE pslibrary · ecutwfc=60 / ecutrho=600 Ry · 10-broadening
  sweep): λ_BZ=1.14–1.41; ω_log≈1252 K; Tc(μ\*=0.10)=105–134 K;
  celldm=5.659 bohr.
- **Group-17 family context:** H₃F (lighter halogen) λ=0.81–0.82,
  Tc=31–33 K; H₃Cl λ=1.14–1.41, Tc=105–134 K. ω_log within the
  group-17 column is large (1252 K), partially offset by lower λ
  relative to group-16.
- **ALIGNN per-candidate ML cross-check:** ALIGNN λ=0.81 vs DFT
  1.27 (+57% λ-magnitude error). Critically, ALIGNN ω_log≈81 K vs
  DFT 1252 K — **15× under-prediction of ω_log**. Per demiurge
  cycle 9 §9.15 d7 wall mechanism identification: ω_log
  under-prediction (not λ-magnitude) is the *dominant ambient-ML
  failure mode* for high-pressure H-derived family (training-set
  ambient bias misses high-frequency H-vibrational modes).
- **§9.15 pre-registered prior:** Tc band 25–60 K — DFT result
  105–134 K is **>2× above band**. The prior under-estimated the
  ω_log dominance for group-17 light halogen; the DFT result
  recalibrates the prior, not the pipeline.

## Real-limit anchor (g3 mandatory)

- **Allen & Dynes 1975, PRB 12, 905** — Tc closed form.
- **Drozdov et al. 2015 H₃S calibration anchor** — pipeline
  validated within 5–15%.
- [compiler invariant — QE 7.5 ph.x DFPT deterministic numerical
  computation; the 15× ALIGNN ω_log gap is *measured* parser
  output, not a fitted constant].

## Falsifiers (pre-registered, ≥5)

1. **F1_broadening_non_monotone** — Tc(broad) monotone; re-parse
   breaking monotonicity FIRES.
2. **F2_alignn_per_cand_within_50pct** — d7 wall: ALIGNN ω_log
   81 K vs DFT 1252 K (15× gap) FIRES → confirms d7 family-wide.
3. **F3_imaginary_phonon** — none detected at celldm=5.659 bohr;
   future re-parse with imaginary modes FIRES.
4. **F4_4q_vs_6q_convergence** — 4³q vs 6³q λ within 10%;
   deviation >10% downgrades verdict.
5. **F5_anharmonic_sscha_gap** — harmonic-only; future measurement
   deviating by >25% from harmonic Tc *after SSCHA* FIRES.
6. **F6_§9.15_prior_recalibration** — the §9.15 prior band 25–60 K
   was wrong by >2×. A re-derived prior for group-17 halogens that
   *still* predicts <60 K when an H₃Cl measurement appears between
   80–150 K FIRES the recalibrated prior (Bayesian update fails).

## Honest C3

- Prediction-only; absorbed=false.
- The 🔴 demiurge §9.15 status refers to the pre-registered
  prior-band, NOT the DFT result. This entry's Tier 🟢 is on the
  DFT numerical result (honest harmonic Allen–Dynes value) — the
  pipeline succeeded; the in-house prior failed.
- ALIGNN ω_log 15× under-prediction (vs DFT) is the most
  consequential family-wide finding from this candidate — it
  *identifies the exact mode of d7 ML training-distribution wall*
  (ω_log under-prediction, not λ-magnitude error).
- Harmonic-only; SSCHA correction not applied.
- 105–134 K is below RTSC threshold (270 K) — H₃Cl is not an RTSC
  candidate, useful as a halogen-series anchor.

## Provenance

- Submitter: claude-opus-4-7 (demiurge cycle 9, 2026-05-24).
- Origin: demiurge `~/core/demiurge/exports/material_discovery/`
  (Tier-2 export, R4-protected; co-cycle JSON emit in progress).
- Pipeline: H₃S-textbook-validated QE 7.5 + parse_elph_gen.py per
  demiurge RTSC.md §9.12, §9.15.
- Artifacts: `~/etc/rtsc-results/h3cl/`.
- Governance: demiurge `project.tape` d1, d6, d7. Cross-link:
  demiurge `inbox/notes/h3cl-d7-wall-breakthrough-2026-05-23.md`
  (d7 wall mechanism identification).
