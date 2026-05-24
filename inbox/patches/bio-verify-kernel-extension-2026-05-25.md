# bio-verify-kernel-extension — `hexa verify --expr` _recompute_float gap (Phases 1-3)

**status**: RESOLVED 2026-05-25 — three-phase landing.
- Phase 1 (PR #707, MERGED): float-arg parser + 3 identities (`exp_release` · `ldl_pct` · `beer_lambert`).
- Phase 2 (PR #711, MERGED): 5 more 3-arg identities (`hill` · `cheng_prusoff` · `fick1` · `laplace` · `stokes_einstein`).
- Phase 3 (this PR): 3 final identities (`higuchi` 2-arg simple form · `tafel` 3-arg log10 · `hagen_poiseuille` 4-arg via new `a3` dispatch lane). Closes the inbox list.

**discovered**: 2026-05-25 (demiurge cross-domain V2 milestone push — 🔵 SUPPORTED-FORMAL
fanout)
**affected domains** (demiurge): ISR · DAPTPGX · LPA · NOREFLOW · TTR · HERPES (6 domains)

## Symptom

```
$ hexa verify --expr hill 3 5
verify --expr hill(3)=5
  tier   = 🟠 INSUFFICIENT
  reason = calculator system has NO path for 'hill'
  gap    = extend tool/verify_cli.hexa::_recompute
```

`hexa verify --expr` _recompute kernel only registers number-theoretic functions
(sigma · phi · mu · tau · ssh_winding · tknn_chern · …) and a small float-NUMERICAL
set (welch_t_crit · wilson_hilferty_p · CHSH / Hardy / MABK / VQE / QFI / shadow / Page /
Qdrift). Demiurge's bio domains (drug delivery · LDL change · OCT signal · pharmacology)
need closed-form identities (`M_t = M_0(1 - exp(-k*t))` · `ΔLDL%` · `I = I_0 exp(-μx)` ·
Hill · Cheng-Prusoff · Higuchi · Fick · Tafel · …) that the current kernel cannot recompute.

## Phase 1 fix (this PR, ~150 LOC)

Extends `tool/verify_cli.hexa::_recompute_float` with 3 bio-physical closed-form
identities + 3-arg float dispatch:

| fn | identity | source |
|----|----------|--------|
| `exp_release(M_0, k, t)` | `M_t = M_0 (1 - exp(-k*t))` first-order release / Bateman | drug delivery, FDA SUPAC-IR |
| `ldl_pct(baseline, final)` | `(final - baseline) / baseline * 100` | FOURIER / GLAGOV / SELECT trial Δ% |
| `beer_lambert(I_0, mu, x)` | `I = I_0 * exp(-mu*x)` | OCT signal attenuation, Beer-Lambert law |

Float arg parser (`_parse_float`) already supports decimals + scientific notation
(`0.5`, `330e-9`, `1.0e-6`, `-1.5`). 3-arg dispatch is added by extending
`_recompute_float(fnm, a0, a1, a2, argc)`.

## Phase 2 follow-up (next stacked PR)

Additional bio identities to add:
- **Hill equation** — `E = E_max * x^n / (K^n + x^n)` (pharmacology dose-response)
- **Cheng-Prusoff** — `K_i = IC_50 / (1 + [S]/K_m)` (enzyme inhibition)
- **Higuchi** — `M_t = k_H * sqrt(t)` (matrix-controlled release, sustained drug delivery)
- **Fick's first law** — `J = -D * dC/dx` (diffusion flux)
- **Tafel equation** — `η = a + b * log(j)` (electrochemistry overpotential)
- **LaPlace pressure** — `ΔP = 2σ/r` (capillary, membrane tension)
- **Hagen-Poiseuille** — `Q = π r^4 ΔP / (8μL)` (laminar flow, blood viscosity)

## Cross-domain unlock

Phase 1 lands → 6 demiurge domain × 3 identity = **18 🔵 SUPPORTED-FORMAL nodes**
immediately recomputable. Phase 2 extends to ~50-90 🔵 total across the bio domain
sweep.

## Provenance

inbox patch — demiurge V2 milestone (cross-domain 🔵 push, 2026-05-25).
