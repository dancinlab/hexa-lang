# kernels/solar/ — ①a solar clear-sky + PV kernel (demiurge design.md D72)

Domain-agnostic solar clear-sky + PV-system computation kernel.
Extracted under the D72 2-layer STDLIB restructure alongside the
aura/bot/energy domain recovery.

| file | role |
|---|---|
| `pvlib_kernel.py` | `run_clearsky_modelchain(site, system, sim, csv_path)` · `pvlib_version` — given a site + PV-system spec + time window, run the Ineichen clear-sky model + CEC SAPM ModelChain and reduce to energy facts. |

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
