# firmware/ — sim · HDL · MCU (§A.6.1 step C + D)

> hexa-cern firmware tree, organized by hardware-layer scope.
>
> **All targets except `firmware/sim/*.hexa` are skeleton-only** and
> only become real binaries when §A.6 step 1 (collab) + step 2 (funding)
> + a target board land. See each subdirectory's `README.md` for the
> path-to-running-silicon.

## Tree

```
firmware/
├── Makefile             — top-level build scaffolding (status-aware)
├── README.md            — (you are here)
│
├── sim/                 — §A.6.1 step C: numerical sim, all .hexa
│   ├── timing_chain.hexa     — clock + trigger pipeline (B1 + B3)
│   ├── dac_chain.hexa        — 16-bit DAC × 4 channels (HV/coil/pump/valve)
│   ├── adc_chain.hexa        — BPM 16-bit 1 GS/s + diamond 14-bit 100 MS/s
│   └── control_loop.hexa     — closed PI loop, setpoint + disturbance
│
├── hdl/                 — §A.6.1 step D 1/3: Verilog FPGA skeleton
│   ├── README.md
│   ├── timing_ctrl.v         — synthesizable RTL counterpart of timing_chain
│   └── testbench/
│       └── timing_ctrl_tb.v  — Icarus Verilog testbench
│
└── mcu/                 — §A.6.1 step D 2/3: Rust embedded MCU skeleton
    ├── README.md
    ├── Cargo.toml             — STM32H7 / Cortex-M7 + FPU
    ├── .cargo/config.toml     — target = thumbv7em-none-eabihf
    └── src/
        └── main.rs             — typestate-safe interlock + state machines
```

## Single-source-of-truth

The constants `CLK_HZ`, `TICK_HZ`, `D_TRIG_CYCLES`, `GATE_CYCLES` (and
their .hexa-side equivalents) appear in **all three layers** with
identical values:

| layer    | file                                    | constants                             |
|:---------|:---------------------------------------|:--------------------------------------|
| .hexa sim | `firmware/sim/timing_chain.hexa`        | `TICK_RATE_HZ = 4.0`, `D_TRIG_S = 1e-6`, `GATE_WIDTH_S = 200e-9` |
| Verilog  | `firmware/hdl/timing_ctrl.v`            | `TICK_HZ = 4`, `D_TRIG_CYCLES = 100`, `GATE_CYCLES = 20` |
| Rust     | `firmware/mcu/src/main.rs`              | `TICK_HZ: u32 = 4`, `D_TRIG_CYCLES: u32 = 100`, `GATE_CYCLES: u32 = 20` |

`verify/cross_doc_audit.hexa` audits the second + third for skeleton-tag
presence + structural correctness; the .hexa side is audited by
`verify/lint_numerics.hexa`.

When any constant changes, all three layers must be updated in lock-step.

## Quick reference

```sh
# from this directory
make help                  # list targets + buildable-now status

make sim-hexa              # ✓ run all 4 .hexa numerical sims
make sim-iverilog          # ⚠  needs icarus-verilog
make cargo-check           # ⚠  needs cargo + thumbv7em target
make lint                  # ✓ basic syntax sweep across all .hexa/.v/.rs

make build-bitstream       # ✗ blocked on §A.6 step 1 + 2
make flash-mcu             # ✗ blocked on §A.6 step 1 + 2
```

## Cross-references

- `mini/doc/benchtop_v0_design.md`  — paper design (BOM/IF/budget/safety)
- `.roadmap.hexa_cern §A.6.1`        — A→B→C→D ladder context
- `verify/cross_doc_audit.hexa`      — checks 13 (HDL) + 14 (MCU) skeleton structural correctness
- `cli/hexa-cern.hexa verify all`    — runs the .hexa sims via the CLI dispatcher
