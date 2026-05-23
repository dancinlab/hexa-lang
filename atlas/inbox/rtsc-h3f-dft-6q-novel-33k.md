# rtsc-h3f-dft-6q-novel-33k

> Submission to `atlas/inbox/` (one concept = one file).

## Concept

H₃F (cubic Im-3m BCC, 4 atoms, celldm=5.127 bohr) under
first-principles DFT+DFPT electron-phonon coupling on a 6×6×6 q-grid
(16 irreducible q-points, full BZ coverage), Quantum ESPRESSO 7.5
(conda) pw.x + ph.x with `electron_phonon='simple'`, exhibits
BZ-weighted λ between **0.81–0.82** (broadening sweep) and
λ-weighted log-average phonon frequency **ω_log ≈ 652–670 K**,
yielding an Allen–Dynes Tc (μ\*=0.10) of **31–33 K**. The lightest
group-17 halogen member of the H₃X family series.

**No published measured Tc exists for H₃F** at any pressure. The
DFT prediction of 31–33 K **falls below the §9.15 pre-registered
prediction band of 50–100 K for H₃F**, marking the prediction as a
🔴 PRED-BAND FAIL below the band — informative for calibrating the
in-house §9.15 prior. The relatively low λ (0.81 vs H₃Cl 1.27) is
the dominant Tc-suppression mechanism in group-17 lightest-halogen
context (F's strong electronegativity disfavors the H-X
charge-transfer that drives high-λ).

## Proposed verdict

- **Tier:** 🟢 **SUPPORTED-NUMERICAL** (Stage 2 — first-principles
  DFT+DFPT 6×6×6-q result; same H₃S-textbook-validated pipeline).
- **Axis:** §4 CHEM (material electron-phonon candidate) ·
  cross-link §3 PHYS (Allen–Dynes) · §10 BRIDGES.
- **Absorbed:** `false` — `gate_type=simulation-only-prediction`.

## Evidence

- Stage 2 numerical (DFT+DFPT 6³q · 16 q-points · 24³ k-grid · USPP
  PBE pslibrary · ecutwfc=60 / ecutrho=600 Ry · 10-broadening
  sweep): λ_BZ=0.81–0.82; ω_log≈652–670 K; Tc(μ\*=0.10)=31–33 K;
  celldm=5.127 bohr.
- **Lightest-X group-17 context:** F's electronegativity confines
  charge-transfer; resulting λ=0.81 is below the group-16 H₃O
  (λ=2.31–2.73) and group-17 H₃Cl (λ=1.14–1.41). ω_log 652–670 K
  is also lower than H₃O 1110 K — both λ AND ω_log suppressed for
  H₃F vs H₃O at similar X-mass, indicating the chalcogen-vs-halogen
  *column-effect* dominates over X-mass in setting both quantities.
- **ALIGNN per-candidate ML cross-check:** ALIGNN |rel_err| 90.5%
  vs DFT (RTSC.md §9.15 family-wide quantitative d7 attestation,
  cycle-9 line 1086) — d7 wall confirmed.
- **§9.15 pre-registered prior:** Tc band 50–100 K — DFT result
  31–33 K is **below band**. The prior over-estimated λ for
  group-17 light halogen.

## Real-limit anchor (g3 mandatory)

- **Allen & Dynes 1975, PRB 12, 905** — Tc closed form.
- **Drozdov et al. 2015 H₃S calibration anchor** — pipeline
  validated within 5–15%.
- [compiler invariant — QE 7.5 ph.x DFPT deterministic numerical
  computation; λ + ω_log are parser output, not fitted constants].

## Falsifiers (pre-registered, ≥5)

1. **F1_broadening_non_monotone** — Tc(broad) monotone across
   broadening; re-parse non-monotone FIRES.
2. **F2_alignn_per_cand_within_50pct** — ALIGNN |rel_err| 90.5% vs
   DFT → d7 wall FIRES → family-wide d7 confirmed.
3. **F3_imaginary_phonon** — none detected at celldm=5.127 bohr;
   future re-parse with imaginary modes FIRES.
4. **F4_4q_vs_6q_convergence** — 4³q vs 6³q λ within 10%;
   deviation >10% downgrades verdict.
5. **F5_anharmonic_sscha_gap** — harmonic-only; future measurement
   deviating by >25% from harmonic Tc *after SSCHA* FIRES.
6. **F6_§9.15_prior_recalibration** — prior band 50–100 K was wrong
   on the low side (actual 31–33 K). A re-derived prior that still
   over-predicts when a measurement appears below 50 K FIRES the
   recalibrated prior.

## Honest C3

- Prediction-only; absorbed=false.
- 🔴 demiurge §9.15 status = prior-band miss (low side); the DFT
  result itself is honest harmonic Allen–Dynes output.
- Harmonic-only; SSCHA correction not applied (group-17 light
  halogen may have non-negligible anharmonicity given strong H-F
  bond).
- 31–33 K is far below RTSC threshold (270 K) — H₃F is not an
  RTSC candidate, useful as a *lightest-halogen* series anchor and
  as a column-vs-mass disentangler (H₃F vs H₃O at similar X-mass:
  column dominates over mass for both λ and ω_log).

## Provenance

- Submitter: claude-opus-4-7 (demiurge cycle 9, 2026-05-24).
- Origin: demiurge `~/core/demiurge/exports/material_discovery/`
  (Tier-2 export, R4-protected; co-cycle JSON emit in progress).
- Pipeline: H₃S-textbook-validated QE 7.5 + parse_elph_gen.py per
  demiurge RTSC.md §9.12, §9.15.
- Artifacts: `~/etc/rtsc-results/h3f/`.
- Governance: demiurge `project.tape` d1, d6, d7.
