# kernels/neural/ — ①a neural kernel (demiurge design.md D72)

Domain-agnostic leaky-integrate-and-fire (LIF) neuron-simulation
kernel. Extracted under the D72 2-layer STDLIB restructure, alongside
`kernels/graph/`, `kernels/fem/`, `kernels/mc_transport/`,
`kernels/circuit/`, and `kernels/plasma/`.

| file | role |
|---|---|
| `lif_kernel.py` | `simulate_lif(...)` — integrate one LIF neuron with constant DC drive via brian2; `equation_hash(...)` for drift detection; `brian2_version()` probe. Given any LIF parameter set, returns the deterministic spike statistics (count, firing rate, mean ISI, CV). |
| `lif_kernel.hexa` | D80 g_hexa_only port (3/N after `kernels/solar/solar_kernel.hexa` and `kernels/mc_transport/`). Clean-room hexa-native exact-update integrator — `v_step`, `v_step_general` (general SI form with V_rest / R), `decay_factor`, `isi_period`, `firing_rate`, `simulate`. The per-step update IS the closed-form ODE solution (brian2 method='exact'); no numerical integration error. |
| `lif_kernel_test.hexa` | Stage 3 parity check — closed-form V(t) checkpoints (sub-threshold + general SI form), analytic ISI period, `simulate()` spike counts vs numpy 2.x reference captured 2026-05-20 (darwin-arm64). 23/23 PASS at ≤1e-12 relative (actual ≤2e-15, machine epsilon). |

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

## hexa-native port (D80 g_hexa_only) — LANDED 2026-05-20

A clean-room hexa-native re-derivation of the LIF integrator
(`lif_kernel.hexa`) now sits alongside the brian2 substrate. The
per-step exact update is the analytic ODE solution

```
v(t+dt) = I + (v(t) - I) · exp(-dt/τ)             (dimensionless)
V(t+dt) = V∞ + (V(t) - V∞) · exp(-dt/τ_m),  V∞ = V_rest + R·I  (SI form)
```

and produces machine-epsilon agreement (≤2e-15 relative) with the
numpy / brian2 method='exact' reference. Substrate parity is
verified by `lif_kernel_test.hexa` (23/23 PASS, 6 reference samples
spanning super-threshold tonic firing, sub-threshold trajectory,
patch-clamp-shaped SI form, and at-threshold edge case).

The `.py` substrate is RETAINED, not deleted — `stdlib/brain/lif_brian2.py`
still spawns it via the demiurge Producer ABI. Re-pointing the
adapter at the hexa-native kernel is a follow-on milestone gated on
a hexa-native producer spawn ABI (or a thin Python shim that loads a
hexa-compiled binding). The same Stage-2 → Stage-4 ladder as
`plasma_metrics.hexa` applies: **`absorbed=true` does NOT flip yet** —
that requires the demiurge HexaNativeParityRef schema + a measured
patch-clamp oracle (Sim4Life MDDT / Allen Brain Atlas), which is out
of scope for this pilot. See inbox note
`2026-05-20-d80-lif-kernel-hexa-native-port-landed.md`.

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
