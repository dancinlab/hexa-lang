# kernels/neural/ — ①a neural kernel (demiurge design.md D72)

Domain-agnostic leaky-integrate-and-fire (LIF) neuron-simulation
kernel. Extracted under the D72 2-layer STDLIB restructure, alongside
`kernels/graph/`, `kernels/fem/`, `kernels/mc_transport/`,
`kernels/circuit/`, and `kernels/plasma/`.

| file | role |
|---|---|
| `lif_kernel.py` | `simulate_lif(...)` — integrate one LIF neuron with constant DC drive via brian2; `equation_hash(...)` for drift detection; `brian2_version()` probe. Given any LIF parameter set, returns the deterministic spike statistics (count, firing rate, mean ISI, CV). |

## 2-layer (ABSORPTION.md ①)

- **①a kernel** (here) — domain-independent. No textbook neuron
  parameter values, no `GEOMETRY_ID`, no meta.json schema — only
  "given an LIF parameter set, integrate it and return the spike
  statistics".
- **①b adapter** — `stdlib/brain/lif_brian2.py`. Owns the textbook
  neuron parameters (`tau_m = 10 ms`, `v_thr = 1`, `I = 2.0`), the
  producer I/O (`meta.json` / `spikes.json` / the `BRAIN_LIF_RESULT`
  stderr line), the `GEOMETRY_ID`, and the honesty caveats. demiurge's
  `BrainAnalyzeProducer.swift` spawns the ADAPTER by absolute path,
  never this kernel.

## `.py` SUBSTRATE — hexa-native porting is the future target (g3)

This kernel is a **`.py` substrate**, NOT hexa-native. brian2 is an
EXTERNAL Python library. Per wilson principle #2 (**hexa-first**), a
hexa-native re-derivation of the LIF integrator is the FUTURE PORTING
TARGET:

- The LIF model is a single linear ODE — `dv/dt = (I − v) / tau` —
  with an analytic exact per-timestep solution. It is small,
  well-bounded, and a natural candidate for a clean-room `.hexa`
  kernel (mirror of `kernels/plasma/plasma_metrics.hexa`).
- When that hexa-native LIF kernel lands and passes a parity round
  against this brian2 substrate, `absorbed=true` flips HERE — once —
  in the kernel, not in the brain adapter.
- Until then, this `.py` kernel is the honest substrate and
  `absorbed = false` ALWAYS at the record layer.

## Why

Currently only one domain (brain) consumes this kernel, so the N×M →
N+M sharing win is latent. Extraction is done now for D72 structural
consistency — every domain is `①a kernel + ①b adapter`. The future
hexa-native LIF port flips `absorbed` in one place.

## Callers

- `stdlib/brain/lif_brian2.py` — ①b brain adapter. Imports this kernel
  by path relative to its own `__file__` (`../kernels/neural/`), so
  the `python3 <script> <output_dir>` spawn from demiurge works
  regardless of cwd. The adapter path/name is unchanged, so no
  demiurge `BrainAnalyzeProducer.swift` change is needed.
