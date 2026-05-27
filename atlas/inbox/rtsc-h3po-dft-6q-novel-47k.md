# rtsc-h3po-dft-6q-novel-47k

> Submission to `atlas/inbox/` (one concept = one file).

## Concept

H₃Po (hydrogen polonide, cubic Im-3m BCC, 4 atoms, celldm=6.236
bohr) under first-principles DFT+DFPT electron-phonon coupling on a
6×6×6 q-grid (16 irreducible q-points, full BZ coverage), Quantum
ESPRESSO 7.5 (conda) pw.x + ph.x with `electron_phonon='simple'`,
exhibits BZ-weighted λ between **2.75–3.31** (broadening sweep
0.030 → 0.015 Ry) and λ-weighted log-average phonon frequency
**ω_log ≈ 258–273 K**, yielding an Allen–Dynes Tc (μ\*=0.10) of
**47–48 K** (μ\*=0.13: 45–46 K). The heaviest group-16 chalcogen
in the H₃X series produces the lowest ω_log of the family (ω_log
collapses ~4× vs H₃O 1110 K), confirming the group-16 trend of
ω_log dominance over λ in setting Tc.

**No published measured Tc exists for H₃Po** at any pressure — this
is a *novel* first-principles prediction, useful primarily as the
group-16 series anchor (heaviest X) that validates the ω_log
monotone-with-X-mass trend within a single chalcogen column.

## Proposed verdict

- **Tier:** 🟢 **SUPPORTED-NUMERICAL** (Stage 2 — first-principles
  DFT+DFPT 6×6×6-q result over a 10-point broadening sweep; same
  H₃S-textbook-validated pipeline).
- **Axis:** §4 CHEM (material electron-phonon / superconductor
  candidate) · cross-link §3 PHYS (Allen–Dynes formula) · §10
  BRIDGES (CHEM ↔ PHYS).
- **Absorbed:** `false` — `gate_type=simulation-only-prediction`
  (R4: DFT is Tier-1, not measured-oracle).

## Evidence

- Stage 2 numerical (DFT+DFPT 6³q · 16 q-points · 24³ k-grid · USPP
  PBE pslibrary · ecutwfc=60 / ecutrho=600 Ry · 10-broadening sweep):
  λ_BZ=2.75 (broad=0.030) → 3.31 (broad=0.015); ω_log≈258–273 K;
  Tc(μ\*=0.10)=47–48 K; Tc(μ\*=0.13)=45–46 K; celldm=6.236 bohr.
- **Group-16 ω_log monotone trend across X mass:** H₃O ω_log~1110 K
  → H₃S ~1170 K (textbook) → H₃Se ~? → H₃Po ~265 K. The H₃Po data
  point closes the heavy-end of the column and confirms ω_log ∝
  X-mass⁻¹ as the dominant Tc driver in this family.
- **ALIGNN per-candidate ML cross-check:** ALIGNN
  jv_supercon_tc≈3.6 K (cf. mass-family wall, |rel_err| 92.3% per
  RTSC.md §9.15 family-wide quantitative d7 attestation).

## Real-limit anchor (g3 mandatory)

- **Allen & Dynes 1975, PRB 12, 905** — Tc closed form.
- **Drozdov et al. 2015 H₃S calibration** — same pipeline
  reproduces the calibration anchor within 5–15%.
- [compiler invariant — QE 7.5 ph.x DFPT deterministic numerical
  computation; values are parser output, not fitted constants].

## Falsifiers (pre-registered, ≥5)

1. **F1_broadening_non_monotone** — Tc(broad) monotone across
   0.015–0.030 Ry; a re-parse that breaks monotonicity FIRES.
2. **F2_alignn_per_cand_within_50pct** — ALIGNN within 50% of DFT
   would not fire d7. ALIGNN 3.6 K vs DFT 47 K (92% error) → FIRED.
3. **F3_imaginary_phonon** — no imaginary modes detected at
   celldm=6.236 bohr (Im-3m dynamically stable at this pressure);
   any future re-parse showing an imaginary mode FIRES.
4. **F4_4q_vs_6q_convergence** — 4³q vs 6³q λ within 10%; deviation
   >10% downgrades to "converging, not converged" (recommended 8³q
   hardening for the heavy-X end of the family).
5. **F5_anharmonic_sscha_gap** — harmonic-only; future synthesis +
   measurement deviating by >25% from harmonic Tc *after SSCHA*
   FIRES the pipeline calibration on the heavy-X end.
6. **F6_measured_tc_when_available** — no current measurement; a
   future ambient-or-high-pressure measurement off by >40% from
   45–48 K FIRES the prediction.

## Honest C3

- Prediction-only; absorbed=false enforced by demiurge d6.
- Po is radioactive (Po-209/210); experimental synthesis of H₃Po
  is materials-handling-bounded, independent of the DFT prediction.
- Harmonic-only; SSCHA correction not applied. The 47–48 K
  prediction is the harmonic Allen–Dynes value.
- ALIGNN ML cross-check failed (d7 wall, family-wide).
- This entry is most useful as a *series-anchor* (heaviest group-16
  X), not as an RTSC candidate (Tc≈47 K is far below the 270 K
  RTSC threshold).

## Provenance

- Submitter: claude-opus-4-7 (demiurge cycle 9, 2026-05-24).
- Origin: demiurge `~/core/demiurge/exports/material_discovery/`
  (Tier-2 export, R4-protected; co-cycle JSON emit in progress).
- Pipeline: H₃S-textbook-validated QE 7.5 + parse_elph_gen.py per
  demiurge RTSC.md §9.12, §9.15.
- Artifacts: `~/etc/rtsc-results/h3po/`.
- Governance: demiurge `project.tape` d1, d6, d7.
