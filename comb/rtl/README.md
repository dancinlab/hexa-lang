# comb/rtl — synthesizable architectural RTL (T2 RTL side)

> 2026-05-18 · degree-4 mesh router + degree-6 hex axial router.
> Synthesizable Verilog subset, externally validated by `iverilog -g2012`
> (only sensitivity-list warnings for array `@*`, benign and standard).
> **NOT tapeout-ready**: Yosys synth + OpenROAD P&R + SKY130/SG13G2 PDK
> mapping + DRC/STA = hexa-arch[chip] absorption track.

## Files

- `router_d4.v` — 5-port (4 cardinal + local) baseline. XY dimension-
  order routing, round-robin arbiter, 4-deep input FIFOs, crossbar,
  output register. ~126 lines.
- `router_d6.v` — 7-port (6 axial + local) target. Hex dimension-order
  routing on axial (q,r,s=-q-r) — picks max-|Δ| axis, then direction.
  Port name convention `pq/nq/pr/nr/ps/ns + LL` matches `axis_b_topology.md`.
  ~137 lines.
- `emit_routers.hexa` + `routers.v` — earlier hexa→Verilog port-skeleton
  emitter (commit cf01eaca). Superseded as RTL by the hand-written files
  here; kept as the hexa-native generator pattern reference.

## What's done (T2 RTL first-pass)

- Both modules have **filled-in datapath**: FIFO buffers (param-depth),
  RR arbiter, routing logic (XY for mesh, hex-axial dim-order for hex),
  crossbar, output register. Single-issue per cycle (one packet/cycle
  per router).
- **External tool validation**: `iverilog -g2012 -Wall` exits 0 on both
  (only `@*` array-sensitivity warnings, benign).
- Both modules have **identical structure** for clean 1:1 metric
  comparison (only port count, routing function, and arbiter width differ).

## What's missing (still T2 / T3)

- **Synthesis**: `yosys -p "synth_xilinx"` or `yosys -p "read_verilog
  router_d6.v; synth"` not run yet (yosys not in this dev env).
- **Place & route**: `openroad` flow (hexa-arch[chip] absorption).
- **PDK mapping**: SkyWater SKY130 or IHP SG13G2 standard cells.
- **DRC/STA**: full physical signoff.
- **Testbench**: cocotb / SymbiYosys formal — sim correctness check pending.
- **Multi-cycle / multi-issue / virtual channels** — single-issue baseline
  here; real NoCs commonly add VCs for deadlock avoidance + throughput.

All of the above are `~/core/hexa-arch[chip]` territory (it absorbs the
external EDA stack: Yosys/OpenROAD/Verilator/SKY130/...). comb's RTL
contribution = the architectural Verilog spec (this folder); hexa-arch
takes it through tapeout flow.

## Status

- T2 RTL side: **synthesizable architectural RTL exists, iverilog PASS**
  (was: port skeleton only).
- T2 sim side: F1 non-contention verdict (8/8 sweep degree-6 wins) —
  `comb/sim/f1_parametric.hexa`.
- T2 strict full (real-workload cycle-accurate + tapeout-ready): pending
  hexa-arch[chip] absorption track.
- T3: still 0% (depends on hexa-arch[chip] RTL→GDSII).
