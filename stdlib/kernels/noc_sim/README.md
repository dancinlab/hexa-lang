# kernels/noc_sim/ — ①a NoC-simulation kernel (demiurge design.md D72)

Domain-agnostic Network-on-Chip simulation kernel. The SIXTH kernel
extracted under the D72 2-layer STDLIB restructure (after
`kernels/graph/`, `kernels/fem/`, `kernels/orbital/`,
`kernels/wave_optics/` and `kernels/mc_transport/`).

Unlike the first five kernels (single-file `.py` extractions of
external-library wrappers), `noc_sim` is a **hexa-native** kernel:
six interdependent `.hexa` modules that were absorbed clean-room
under rfc_003 from BookSim2. The 2-layer restructure relocates the
domain-independent simulation engine here; the chip-domain CLI
surface stays in `stdlib/booksim/` as the ①b adapter.

| file | role |
|---|---|
| `anynet.hexa` | clean-room `anynet` topology loader — parse a router/channel netlist into a typed graph; mesh / hex builders; BFS diameter + bisection surrogate. |
| `iq_router.hexa` | input-queued virtual-channel router pipeline model — per-hop critical-path cycles, credit/VC-alloc delays, analytic area/energy estimate. |
| `traffic.hexa` | traffic-pattern generators — uniform / tornado / transpose destination maps over a `k`-ary `n`-cube. |
| `wire_delay.hexa` | RC wire-delay model — per-mm picosecond delay → cycle-quantised link latency at a process node / clock. |
| `sweep.hexa` | injection-rate sweep — mean-field latency curve + saturation-knee detection over a topology + router + traffic config. |
| `leighton.hexa` | Leighton bisection/diameter lower-bound oracle — the no-over-claim cross-floor (`@x_leighton_1992`). |

## 2-layer (ABSORPTION.md ①)

- **①a kernel** (here) — domain-independent. No chip F1F2-record
  schema, no rfc_001/rfc_003 measurement-gate vocabulary — pure
  "topology + router + traffic in → latency curve / oracle verdict
  out". Reusable by any NoC study, not just `chip+verify/analyze`.
- **①b adapter** — `stdlib/booksim/booksim.hexa` (the `hexa-arch
  booksim` CLI: `topology` / `sweep` / `wire-delay` / `oracle` /
  `measure`, F1F2-record serialization, rfc_001 §8 gate vocabulary)
  and `stdlib/booksim/sweep_oracle_parity.hexa` (the chip-domain
  §B+§D parity orchestrator that demiurge `chip+verify` spawns).
  Each owns the chip record schema + honesty caveats and calls this
  kernel for the simulation math.

## Why

`chip+verify` (sweep_oracle_parity) and `chip+analyze` (booksim
oracle dispatch) both ride the same six NoC-sim engine modules.
Extracting the shared kernel means N studies share 1 engine
(N×M → N+M). The day the hexa-native engine passes a BookSim2
cycle-accurate parity round, `absorbed=true` flips HERE — once —
instead of in every domain adapter.

## Honesty (g3)

Every engine module carries its own clean-room provenance header
naming the BookSim2 file/line-range it was re-derived from by
inspection only — no upstream code copied. `sweep.hexa` is an
analytic mean-field model, NOT an event-driven flit simulator;
`leighton.hexa` is an exact graph-theoretic lower bound. The
measurement-gate honesty (`measurement_gate`, `absorbed`,
`scope_caveats`) lives in the ①b adapter, NOT here.

## Callers

- `stdlib/booksim/booksim.hexa` — `hexa-arch booksim` CLI dispatcher
  (demiurge `chip+analyze`).
- `stdlib/booksim/sweep_oracle_parity.hexa` — §B+§D oracle-parity
  orchestrator (demiurge `chip+verify`).

Both adapters import the kernel via `use "stdlib/kernels/noc_sim/
<module>"` (repo-root-relative), so the demiurge `hexa run
<adapter>.hexa` spawn resolves regardless of cwd — the adapter
paths are unchanged, so no Producer/Loader change is needed.
