# QFORGE PBE-SCF ground-state functional alignment → CaH6 λ vs QE 4.376

**Date**: 2026-06-11 · **Cost**: $0 (0-pod local-CPU) · **Engine**: QFORGE (hexa-native PW SCF·DFPT·λ)
**d6/@L5 VERBATIM — 4.376 NOT forced.** **GATE: NOT MET. @L5 FINAL-WALL: the PBE-SCF lever is CLOSED-NEGATIVE.**

## TL;DR (honest)

The task's premise — *"PBE-XC ground-state SCF alignment is memory's last un-tried lever
(ALDA-negative did not predict it)"* — is **STALE**. That was the state at the memory's
2026-06-09 `f_xc-in-χ` snapshot. In the **1-2 days after** that snapshot, **all three**
levers the snapshot named as un-tried were pursued to terminal and are each
**CLOSED-NEGATIVE**:

| lever named un-tried @2026-06-09 | pursued | verdict | CaH6 λ (VERBATIM) | vs QE 4.376 |
|---|---|---|---|---|
| **PBE-XC from-scratch SCF** (V_xc[ρ,∇ρ] in the ground-state SCF) | 2026-06-09 | 🔴 CLOSED-NEG | regresses: n=16 LDA 0.609302→PBE **0.081270**; n=64 0.008329→**0.003351**; n=645 PBE blocked (pow2 wall → LDA fallback ≡ 4.13647) | WORSE (moves away) |
| **GGA(PBE) f_xc-in-χ** (∂²e_xc^PBE/∂ρ² Dyson kernel) | 2026-06-09 | 🔴 CLOSED-NEG | **3.41256** (n=645, full ε, GGA engaged ‖f_xc‖/‖v_c‖=1.60) | **22.02%** (≈ ALDA 21.96%) |
| **3-D real-space SCF ρ(r)** (the named root of PBE-SCF: replace (1,1,n) line, pow2-pad n=645) | 2026-06-10 (hexa-lang PR#3003) | 🔴 CLOSED-NEG | **1.43e-88 ≈ 0** (n=645, 32³ cube, PBE engages at converged basis for the FIRST time) | collapse |

This round did NOT re-run a fresh CaH6 campaign (that would re-derive an already-recorded
closed-negative number, d6). It **independently re-verified the PBE-SCF machinery is real,
correct, and engages** on the live install (`~/.hx/src`), then issues the @L5 final-wall
judgment.

## Independent g5 re-verification (this round, live install `~/.hx/src`, VERBATIM)

- `qforge_correlation_pbe_selftest` → **PASS** (PBE GGA correlation: t→0 ⇒ PW92 reduction
  exact; closed-form H(r_s,t); saturation t→∞ ⇒ −ε_c^LDA; monotone). [`correlation_pbe_selftest.txt`]
- `qforge_scf_pw_realspace_selftest` → **10/10 PASS** [`scf_pw_realspace_selftest_10of10.txt`]:
  - **case D** — cos(G·x) ⇒ peak |∇ρ| = A·|G| = **0.0785398** == ref 0.0785398 (a genuine
    3-D spectral ∇ρ — the (1,1,n) line cannot produce this).
  - **case G** — PBE V_xc[cos ρ] ≠ LDA, max|V_PBE−V_LDA| = **8.85729e-05** (the GGA gradient
    term is provably LIVE, not a silent LDA fallback).
  - case C — PBE V_xc[uniform ρ] ≡ LDA V_xc = −0.728542 (GGA→LDA reduction exact).
  - case F — ∫ρ dr = 8 == nelec (physical normalization). case H — F_x(∞)=1.80355 (Lieb-Oxford bound).

So the PBE ground-state functional is correctly implemented (F_x(s) PBE exchange enhancement
+ PBE correlation H(r_s,t) + true 3-D spectral ∇ρ + the GGA divergence V_xc = ∂e/∂ρ −
∇·(∂e/∂g·∇ρ/g)) and it **engages** at the physical n=645 basis. The lever is not blocked by
a bug — it is genuinely exhausted.

## @L5 FINAL-WALL judgment (d6 — 4.376 NOT forced, faking forbidden)

**PBE-SCF does NOT recover QE λ. It is the WRONG lever, twice over:**

1. **Where PBE engages on a pow2 basis, λ REGRESSES** (0.609→0.081 @ n=16) — the same
   over-screening SIGN as the f_xc-in-χ ALDA/GGA results. A GGA ground-state functional swap
   on the from-scratch SCF moves λ *away* from QE, not toward it.

2. **The 3-D real-space SCF (the named root of PBE-SCF) breaks the pow2-FFT wall** — PBE V_xc
   engages at the converged n=645 basis for the first time — **and in doing so RE-LOCATES the
   true wall**: with a *physically correct* 3-D ρ(r) projected as a *correct* local potential,
   λ → 0 (1.43e-88), because the production **assembler is DIAGONAL-ONLY** (`assembler.hexa`
   adds only V̄ = V(G=0), the spatial average, to H[a][a]). The el-ph-relevant screening lives
   entirely in the OFF-diagonal V_scr(G_a−G_b) the assembler discards (off-diagonal RMS/|V̄| =
   0.69 for V_xc, 5.56 for V_scr at n=645). The (1,1,n) path's old λ=0.609 was an ARTIFACT of
   feeding a per-G-varying diagonal that is NOT what a real local potential contributes.

**The wall is therefore NOT a DFT-functional-level wall (LDA vs PBE/GGA) at all** — both the
SCF functional and the χ-kernel functional have been walked to terminal at LDA→ALDA→PBE/GGA,
all closed-negative. The genuinely-open lever is **architectural, not functional**: the
**off-diagonal local-potential assembler** (`elph_vscr_realspace.hexa`, n²-scaling dense
⟨G_a|V_scr|G_b⟩ = V_scr(G_a−G_b) matrix). A WIP checkpoint exists
(`.verdicts/qforge-offdiag-vscr-assembler/PROGRESS.md`, STARTED 2026-06-09) with **no
implementation yet** — that is the true current frontier, and it is a separate large piece,
NOT a PBE-SCF / XC-functional task.

## Conclusion

- **GATE: NOT MET.** PBE-SCF λ at every computable basis is WORSE than or collapses relative
  to QE 4.376. The closest-to-QE number remains the **BARE vertex λ=4.13647 (5.47%)**, never
  forced.
- **PBE-SCF lever = CLOSED-NEGATIVE (this is the genuine final-wall for the functional axis).**
  No code fix is shipped because there is nothing left to fix on this lever — the machinery is
  implemented, g5-verified, engages, and the physics says PBE does not close the gap.
- **Hybrid (QE |g|² → QFORGE L3 assembler, rel-ε 1.65e-7) remains production. `absorbed` stays
  HELD. dispatch default = qe.**
- **Next lever (d2, NOT this task, NOT functional)**: implement the off-diagonal
  V_scr(G_a−G_b) el-ph vertex assembler on the 3-D real-space ρ(r) cube the realspace SCF
  already supplies.

## Cross-references (existing closed-negative verdicts)
- `.verdicts/qforge-pbe-scf-cah6/` — A1 PBE-XC from-scratch SCF (2026-06-09)
- `.verdicts/qforge-cah6-gga-fxc-in-chi/` — GGA(PBE) f_xc-in-χ (2026-06-09)
- `.verdicts/qforge-3d-realspace-scf/` — 3-D real-space SCF ρ(r) rebuild, hexa-lang PR#3003 (2026-06-10)
- `.verdicts/qforge-offdiag-vscr-assembler/PROGRESS.md` — the open off-diagonal frontier (WIP, no impl)

## Artifacts
- `correlation_pbe_selftest.txt` — PBE GGA correlation g5 PASS (this round, live install)
- `scf_pw_realspace_selftest_10of10.txt` — 3-D real-space PBE SCF g5 10/10 PASS (this round, live install)
