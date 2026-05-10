# firmware/hdl — Verilog skeletons (Step D 1/3)

> **Status**: skeleton only — synthesizes to bitstream **only with vendor toolchain + target board**.
> See `.roadmap.hexa_cern §A.6.1 step D` for scope contract.

## What's here

| file              | role                                           | sim-buildable? | bitstream-buildable? |
|:------------------|:-----------------------------------------------|:--------------:|:---------------------:|
| `timing_ctrl.v`   | FPGA timing controller (B3 block, B1 ↔ B2 path) | ✓ icarus       | ✗ needs Vivado/etc + board |

## Architecture (commitment, not yet built)

`timing_ctrl.v` realises `firmware/sim/timing_chain.hexa` in synthesizable
RTL. Same state machine, same parameters:

| `firmware/sim/timing_chain.hexa`         | `firmware/hdl/timing_ctrl.v`                  |
|:----------------------------------------|:---------------------------------------------|
| `TICK_RATE_HZ = 4.0` (Hz)               | `parameter TICK_HZ = 4`                       |
| `TICK_PERIOD_S = 0.25`                   | derived: `CLK_HZ / TICK_HZ = 25,000,000`     |
| `D_TRIG_S = 1.0e-6`                       | `parameter D_TRIG_CYCLES = 100` (= 1 µs @ 100 MHz) |
| `GATE_WIDTH_S = 200e-9`                   | `parameter GATE_CYCLES = 20`                  |
| (jitter handled in numerical sim only)    | sub-cycle jitter handled by FPGA + clock buffer |

## How to simulate (icarus, no board needed)

```sh
# install Icarus Verilog (apt / brew)
iverilog -g2012 -o /tmp/timing_sim timing_ctrl.v testbench/timing_ctrl_tb.v
vvp /tmp/timing_sim
```

Note: a testbench (`testbench/timing_ctrl_tb.v`) is intentionally **not** in
this commit yet — it lands as part of Step D 3/3 (build scaffolding) once
the structure is full.

## Path to bitstream (when funded)

Step D progresses to a real bitstream when:

1. §A.6 step 1 (external collab decision: DESY / SLAC / KEK) picks a host
   facility — this fixes the target FPGA family they have in stock.
2. §A.6 step 2 (funding) acquires the dev-board and tooling.
3. Constraints file (`*.xdc` for Xilinx / `*.sdc` for Altera) is added,
   pinning `clk_i / rstn_i / hv_ok_i / …` to actual board pads.
4. `vivado` / `quartus` / `diamond` synth + place-and-route + bitgen runs.

Until then, this directory is an **architectural commitment**, not a build
target.

## Cross-references

- `firmware/sim/timing_chain.hexa` — numerical model the HDL must match
- `mini/doc/benchtop_v0_design.md §2` — block diagram (B1 → B3 path)
- `mini/doc/benchtop_v0_design.md §3` — F1 (FPGA timing controller, ~$4.5k)
- `mini/doc/benchtop_v0_design.md §4` — interface table signals 1, 2, 3
- `.roadmap.hexa_cern §A.6.1 step D` — scope contract
