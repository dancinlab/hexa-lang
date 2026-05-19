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
| `plasma_metrics.hexa` | Debye length · electron/ion plasma frequency · electron/ion cyclotron frequency · thermal speeds · Alfvén speed · gyroradii. CODATA-2022 SI constants. Pure functions — given `n_e`, `T`, `B`, ion species, returns the derived parameters that such a plasma would have. |

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

Callers import the kernel via `use "stdlib/kernels/plasma/
plasma_metrics"` (repo-root-relative). The plasmapy substrate producer
`stdlib/fusion/plasma_metrics.py` (spawned by demiurge's
`FusionAnalyzeProducer.swift`) is a separate `.py` script and is
unchanged — no demiurge Producer change is needed.
