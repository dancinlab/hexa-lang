# kernels/plasma/ — ①a plasma kernel (demiurge design.md D72)

Domain-agnostic plasma-physics computation kernel. Extracted under the
D72 2-layer STDLIB restructure, alongside `kernels/circuit/`,
`kernels/graph/`, `kernels/fem/`, `kernels/mc_transport/`, and
`kernels/neural/`.

Like `circuit`, `noc_sim`, and `logic_synth`, `plasma` is a
**hexa-native** kernel: a clean-room `.hexa` module (no `.py`
wrapper). It implements the standard plasma-physics algebra directly
from physics first principles.

| file | role |
|---|---|
| `plasma_metrics.hexa` | Broad-surface kernel: Debye length · electron/ion plasma frequency · electron/ion cyclotron frequency · thermal speeds · Alfvén speed · gyroradii. CODATA-2022 SI constants. Pure functions — given `n_e`, `T`, `B`, ion species, returns the derived parameters that such a plasma would have. Consumed by `stdlib/fusion/plasma_metrics.hexa` adapter. |
| `plasma_metrics_kernel.hexa` | D80 `g_hexa_only` pilot — slimmer-surface (4 primary params: λ_D, ω_p, r_L, ln Λ) sibling kernel following the `solar_kernel.hexa` naming convention. Same constants + same closed-form as `plasma_metrics.hexa`; adds the NRL-Formulary high-T Coulomb log. Parity-tested at machine epsilon (≤1e-12 rel) on 8 sample points across 19 orders of n_e and 5 orders of T_e — see `plasma_metrics_kernel_test.hexa`. |

## 2-layer (ABSORPTION.md ①)

- **①a kernel** (here) — domain-independent. No ITER operating point,
  no device caveats — only "given a plasma's `n_e` / `T` / `B`,
  compute its standard derived parameters". Reusable by any
  plasma-physics study.
- **①b adapter** — `stdlib/fusion/plasma_metrics.hexa`. Owns the
  textbook ITER core reference scenario (`n_e = 1e20 m⁻³`,
  `T_e = T_i = 10 keV`, `B = 5.3 T`, majority D⁺) and the honesty
  caveat that those inputs are NOT a device measurement.

## Why

Currently only one domain (fusion) consumes this kernel, so the N×M →
N+M sharing win is latent. Extraction is done now for D72 structural
consistency — every domain is `①a kernel + ①b adapter`. The day a
second plasma-domain producer lands (or a Stage 3 parity round
passes), `absorbed=true` flips HERE — once — instead of in every
domain adapter.

## Honesty (g3)

The `.hexa` module carries its own clean-room provenance header: the
formulae are 1920–1950s textbook plasma physics (Krall & Trivelpiece,
Stix — mathematical facts only); the constants are CODATA 2022. NO
plasmapy code is copied. The measurement-gate honesty
(`measurement_gate`, `absorbed`, `scope_caveats`) lives in the ①b
adapter `stdlib/fusion/`, NOT here.

## Callers

- `stdlib/fusion/plasma_metrics.hexa` — ①b fusion adapter (ITER
  scenario aggregator).
- `stdlib/fusion/plasma_metrics_test.hexa` — Stage 3 parity selftest
  (kept beside the fusion adapter it also imports).
- `stdlib/kernels/plasma/plasma_metrics_kernel_test.hexa` — D80 pilot
  in-kernel parity selftest (8 samples, ≤1e-12 rel vs hand-mirrored
  Python `math` reference). Validates that the `_kernel.hexa` slim
  surface holds bit-exact parity over a 19-orders-of-magnitude
  operating envelope.

Callers import the kernel via `use "stdlib/kernels/plasma/
plasma_metrics"` (repo-root-relative). The plasmapy substrate producer
`stdlib/fusion/plasma_metrics.py` (spawned by demiurge's
`FusionAnalyzeProducer.swift`) is a separate `.py` script and is
unchanged — no demiurge Producer change is needed.
