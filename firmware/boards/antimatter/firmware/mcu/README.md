# `firmware/mcu/` — Phase D Rust embedded skeletons

> §A.6.1 Phase D scope.  `no_std` Rust skeletons for 4 board MCUs.
> Cross-compilable with `cargo build --target thumbv7em-none-eabihf`
> (STM32H7) or `aarch64-unknown-none-softfloat` (Cortex-A53 in MPSoC PS).
>
> **Compiles** but **not flashable** until physical boards arrive.

**Status**: skeleton (2026-05-08) · **Toolchain**: Rust nightly + `cargo-embed` · **Boards**: ✗

---

## §1 Module inventory

| File | Target board | MCU | Sim source |
|:-----|:-------------|:----|:-----------|
| `pet_cyclotron.rs` | board_v0_pet_cyclotron | STM32H743VIT6 (Cortex-M7) | sim/cyclotron_trigger.hexa |
| `tabletop.rs` | board_v0_tabletop_penning | XCZU9EG PS (4× Cortex-A53) | sim/penning_rf.hexa |
| `cpt_bench.rs` | board_v0_atomic_clock | XCKU040 + STM32H723 (companion) | sim/atomic_clock_counter.hexa |
| `thrust_bench.rs` | board_v0_thrust_acquisition | XCVU13P + STM32H743 (companion) | sim/thrust_acquisition.hexa |

## §2 Build (per target)

### STM32H7 (Cortex-M7)
```bash
rustup target add thumbv7em-none-eabihf
cargo build --target thumbv7em-none-eabihf --release --bin pet_cyclotron
# Flash: cargo embed --bin pet_cyclotron     (requires probe-rs + ST-LINK V3)
```

### MPSoC PS (Cortex-A53)
```bash
rustup target add aarch64-unknown-none-softfloat
cargo build --target aarch64-unknown-none-softfloat --release --bin tabletop
# Flash via Xilinx XSDB or U-Boot (board-required)
```

## §3 Cargo.toml structure

A real `Cargo.toml` would specify:
- `embedded-hal` traits (HAL abstraction)
- `stm32h7xx-hal` (STM32H7 vendor crate) for pet_cyclotron / cpt_bench / thrust_bench companion
- `xilinx-zynqmp-hal` (community crate, less mature) for tabletop PS-side
- `cortex-m-rt` runtime (M7) / custom for A53
- `defmt` + `defmt-rtt` for printf-debug
- `panic-probe` for panic handler

The skeletons here are **single-file** illustrations, not full Cargo
workspaces.  Phase D will scaffold full workspace per board.

## §4 Out of scope (this skeleton)

- Real HAL initialization (clock tree, DMA, interrupts) — needs board defs
- Vendor PAC (peripheral access crate) bindings — auto-generated from SVD
- USB-CDC / Ethernet stack (smoltcp) — heavy dependencies
- RTOS (Zephyr / Embassy / RTIC) — choice deferred to Phase D
- Defmt-based RTT logging — needs probe-rs setup

## §5 Cross-link

- `firmware/sim/*.hexa` — golden behavioral spec (PASS criterion)
- `firmware/doc/board_v0_*.md` — pinout source-of-truth
- `firmware/hdl/*.v` — FPGA-side companion (where applicable)
- `.roadmap §A.6 step 4` — actual board bring-up
