# firmware/mcu — Rust embedded MCU skeleton (Step D 2/3)

> **Status**: skeleton only — flashes to silicon **only with target board + memory.x + HAL crate**.
> See `.roadmap.hexa_cern §A.6.1 step D` for scope contract.

## What's here

| file                 | role                                              | buildable now? |
|:---------------------|:--------------------------------------------------|:--------------:|
| `Cargo.toml`         | crate manifest + dependencies                     | ✓ `cargo check` |
| `.cargo/config.toml` | target = thumbv7em-none-eabihf (Cortex-M7 + FPU)  | ✓              |
| `src/main.rs`        | skeleton entry + state machines + DAC/PI/Trigger  | ✓ `cargo check` |
| `memory.x`           | linker script (vendor-supplied)                   | ✗ MISSING — needs board |

## Architecture (commitment, not yet built)

`src/main.rs` mirrors the .hexa sims in real Rust:

| `firmware/sim/*.hexa`            | `firmware/mcu/src/main.rs`                  |
|:--------------------------------|:-------------------------------------------|
| `timing_chain.hexa`              | `TriggerSm` state machine                   |
| `dac_chain.hexa`                  | `dac_code_for_mv()` + DAC_BITS / DAC_VFS_MV |
| `control_loop.hexa::pid_step`    | `PiCtrl` struct + `step()` method           |
| `interlock_now` (HDL)            | `InterlockOk` newtype  (typestate enforces) |

Same constants (`CLK_HZ`, `TICK_HZ`, `D_TRIG_CYCLES`, `GATE_CYCLES`)
appear in all three layers (.hexa sim / Verilog HDL / Rust MCU). When
one moves, the cross-doc audit should catch divergence.

## Type-level safety

The `InterlockOk` newtype is constructed *only* via `from_pins(...)`
which requires all 4 interlock booleans to be true. Driver code can
require `&InterlockOk` to arm a trigger:

```rust
fn arm_trigger(_ok: InterlockOk) {
    // safe to fire — the type-system witnessed that interlocks were OK
    // at the moment InterlockOk was constructed
}
```

This pushes the interlock check from "remember to do it" to "compiler
won't let you forget."  Same property as the HDL `interlock_now`
gating in `firmware/hdl/timing_ctrl.v`.

## How to compile (no board needed)

```sh
# install nightly + target (one-time)
rustup target add thumbv7em-none-eabihf

# from this directory
cargo check --target thumbv7em-none-eabihf
# ❌ will fail at link step without memory.x — that's expected.
# ✓  but the rust-checker will complete (errors only at link).
```

Real board build path:

```sh
# step 1: drop a vendor memory.x into this dir (e.g. 2 MB flash, 512 KB RAM
#         for STM32H743ZIT6)
# step 2: pull in stm32h7xx-hal in Cargo.toml
# step 3: replace src/main.rs entry body with peripheral init + RTIC tasks
# step 4:
cargo build --release
probe-rs run --chip STM32H743ZITx target/thumbv7em-none-eabihf/release/hexa-cern-laser-mcu
```

## Path to running silicon

Step D progresses to a flashable binary when:

1. §A.6 step 1 (collab decision) picks host facility — fixes MCU stock.
2. §A.6 step 2 (funding) acquires dev-board.
3. `memory.x` lands (vendor-supplied).
4. HAL crate added (`stm32h7xx-hal` etc.).
5. Peripheral drivers fill in `entry()` body's TODO.

Until then, this directory is an **architectural commitment**.

## Cross-references

- `firmware/sim/timing_chain.hexa`   — `TriggerSm` numerical model
- `firmware/sim/dac_chain.hexa`       — `dac_code_for_mv` reference
- `firmware/sim/control_loop.hexa`    — `PiCtrl` reference
- `firmware/hdl/timing_ctrl.v`        — `interlock_now` HDL counterpart
- `mini/doc/benchtop_v0_design.md §3 F2` — STM32H7 BOM line ($800, 1 mo)
- `.roadmap.hexa_cern §A.6.1 step D`  — scope contract
