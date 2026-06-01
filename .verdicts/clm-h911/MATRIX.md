# CLM-KOSMOS H_911 on-chip recovery — 7-hypothesis deterministic CPU matrix
slug=clm-h911 · group=CLM-KOSMOS · method=hexa run (deterministic, paired, bootstrap CI) · g63 honest (no cherry-pick, every tier recorded incl 🔴)

Corpus: stdlib/flame/testdata/clm_semantic_{parallel,concat}.txt — 5 concept × 5 lang (en·zh·ru·ja·ko), IDENTICAL bytes, only ORDER differs (parallel=concept-major adjacency, concat=language-major).
Paired statistic convention: positive = parallel recovers the H_911 signal vs concat. 🟢 iff bootstrap 95% CI_lo > 0; 🔴 iff CI straddles/≤0 (closed-negative).

| id | mechanism | paired stat (parallel-favoring) | 95% CI | tier |
|----|-----------|--------------------------------|--------|------|
| F-CLM-H911-CPU-CAPACITY | A · full-capacity int4-QAT backprop, per-window paired CE | concat-parallel mean diff = +0.0723 (point: par CE 1.98176 < con 2.05405) | [-0.0755, +0.2239] | 🔴 |
| F-CLM-H911-STDP | B1 · spike-timing plasticity (vs rate-Hebbian control) | parallel-concat mean = +3.5871 (rate-Hebbian control gap ~0.0039, null) | [+3.5334, +3.6439] | 🟢 |
| F-CLM-H911-NEUROMOD | B2 · salience/third-factor gated update (vs ungated control) | parallel-concat mean = +9.5769 (ungated control gap = 0.0, null) | [+9.4478, +9.7060] | 🟢 |
| F-CLM-H911-HUB | B3 · Φ-proxy at HIDDEN recurrent convergence hub (vs last-layer) | parallel-concat mean = +2.6475 (last-layer locus null per #1652/#1653) | [+2.5586, +2.7425] | 🟢 |
| F-CLM-H911-REPLAY | B4 · offline interleaved replay/consolidation (R=64, vs single-pass) | parallel-concat mean = +3.7518 (consolidation tightens per-pass noise to ~0 on concat) | [+3.6591, +3.8358] | 🟢 |
| F-CLM-H911-SPARSE | B5 · k-WTA sparse readout (k=4, vs dense control) | parallel-concat mean = +0.3023 (1/5 concepts drives it; dense control gap +2.91 — sparsity HURTS) | [-0.1167, +1.0566] | 🔴 |
| F-CLM-H911-MI | C · direct cross-lingual MI (sign-agreement over leaky hub) | parallel-concat mean = -1.28 (estimator order-insensitive; does not detect timing) | [-3.3569, 0.0] | 🔴 |

## ADJUDICATION (construct-validity, 2026-06-01)
The four 🟢 above (STDP · NEUROMOD · HUB · REPLAY) are **CONSTRUCT-INVALID — byte-proximity artifacts**. Their features were fixed raw-UTF-8-byte projections (clm_h911_bc_mechanisms.hexa `build_feats`), so cross-lingual same-concept similarity ≈ 0.5 constant: the mechanisms measured **presentation-ORDER proximity** (parallel adjacent, concat scattered), NOT learned meaning. The large gaps (+3 to +9) are order-adjacency magnitudes, not semantic integration.
Only **F-CLM-H911-CPU-CAPACITY (A)** was construct-valid — a real learned-embedding CLM with full backprop — and it was 🔴 (paired CI straddles 0). It stands.
This bio line is **superseded** by the construct-valid LEARNED-embedding line `slug=clm-kosmos-h911-edu-neuro` (`.verdicts/clm-h911-edu-neuro/`), which measures all 20 EDU+NEU hypotheses on the CLM's own learned cross-lingual vectors with a mandatory within-concept-shuffle NULL probe. Raw verdict `.txt` files here are kept verbatim (g5); only the interpretation is retracted.
