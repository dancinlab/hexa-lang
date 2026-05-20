# kernels/graph/ — ①a graph kernel (demiurge design.md D72)

Domain-agnostic graph-theoretic computation kernel. First kernel
extracted under the D72 2-layer STDLIB restructure.

| file | role |
|---|---|
| `networkx_kernel.py` | `topology_metrics(graph, top_n)` · `edges_sha256_16` · `networkx_version` — given any networkx graph, compute the deterministic facts about it. |

## 2-layer (ABSORPTION.md ①)

- **①a kernel** (here) — domain-independent. No IEEE 14-bus, no
  Manhattan grid. Pure "graph in -> metrics out".
- **①b adapter** — `stdlib/grid/networkx_basics.py`,
  `stdlib/mobility/road_network.py`. Each owns its domain topology
  (geometry / parameters / honesty caveats) and calls this kernel
  for the math.

## Why

Both the `grid` and `mobility` producers re-implemented the same
networkx wrapping. Extracting the shared kernel means N domains
share 1 kernel (N×M -> N+M). The day a hexa-native graph kernel
lands, `absorbed=true` flips HERE — once — instead of in every
domain adapter.

## Callers

- `stdlib/grid/networkx_basics.py` — IEEE 14-bus power-grid topology
- `stdlib/mobility/road_network.py` — synthetic Manhattan road grid

Adapters locate this kernel by path relative to their own file
(`../kernels/graph/`), so the `python3 <script> <output_dir>` spawn
from demiurge works regardless of cwd.
