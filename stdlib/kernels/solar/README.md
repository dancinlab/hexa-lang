# kernels/solar/ — ①a solar clear-sky + PV kernel (demiurge design.md D72)

Domain-agnostic solar clear-sky + PV-system computation kernel.
Extracted under the D72 2-layer STDLIB restructure alongside the
aura/bot/energy domain recovery.

| file | role |
|---|---|
| `pvlib_kernel.py` | `run_clearsky_modelchain(site, system, sim, csv_path)` · `pvlib_version` — given a site + PV-system spec + time window, run the Ineichen clear-sky model + CEC SAPM ModelChain and reduce to energy facts. |
| `solar_kernel.hexa` | D80 g_hexa_only pilot — clean-room hexa-native port of pvlib `solarposition.ephemeris` (Hughes 1985) + `clearsky.haurwitz` (1945). Substrate parity vs pvlib 0.13.0 to ≤1e-13 relative across 6 timestamps (test below). Heavier substrates (SPA / CEC-SAPM / ModelChain) still live in `pvlib_kernel.py` until follow-on ports land. See `inbox/notes/hexa-native-port-pattern-pilot.md` for the port pattern. |
| `solar_kernel_test.hexa` | Substrate parity check for `solar_kernel.hexa` — 21 assertions across 6 Phoenix-AZ timestamps spanning low/high/horizon/below-horizon sun. Run: `hexa run stdlib/kernels/solar/solar_kernel_test.hexa`. |

## 2-layer (ABSORPTION.md ①)

- **①a kernel** (here) — domain-independent. No Phoenix site, no
  Canadian Solar module, no 2024 calendar. Pure "site + system +
  window in -> energy facts out".
- **①b adapter** — `stdlib/energy/pvlib_clearsky.py`. It owns the
  Phoenix AZ site / module + inverter picks / year horizon / honesty
  caveats and calls this kernel for the simulation.

## Why

`energy + analyze` re-implemented the pvlib + pandas ModelChain
wrapping inline. Extracting the shared kernel means any future solar
domain (rooftop, utility-scale, tracker) shares 1 kernel
(N×M -> N+M). The day a hexa-native clear-sky kernel lands,
`absorbed=true` flips HERE — once — instead of in every domain
adapter.

## Callers

- `stdlib/energy/pvlib_clearsky.py` — Phoenix AZ fixed-tilt 1-module
  reference PV system

Adapters locate this kernel by path relative to their own file
(`../kernels/solar/`), so the `python3 <script> <output_dir>` spawn
from demiurge works regardless of cwd.
