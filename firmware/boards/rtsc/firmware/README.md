# firmware/ — hexa-rtsc Phase A → D+ HW prototype layer

> **Status (2026-05-08)**: Phase D+ COMPLETE. 70/70 tests PASS across
> 8 firmware components in 3 toolchains (hexa / iverilog / cargo).
> No PCB, no flash, no cold-test — those are §A.6 Step 4 deliverables.

Per `.roadmap.hexa_rtsc §A.6.1` recommended A → B → C → D → D+ ordering:

| Subdir | Stage | Language | Toolchain | Files | Tests |
|:------|:-----:|:--------|:--------|:-----:|:------:|
| `sim/` | C + D+ | hexa | hexa runtime | 4 | 43/43 PASS |
| `hdl/` | D + D+ | Verilog 2001 | iverilog 11.0 + Vivado 2024.2 | 4 + tb + Makefile + tcl + xdc | 12/12 PASS |
| `mcu/` | D + D+ | Rust no_std (dual-mode) | cargo 1.94 + thumbv7em-none-eabihf | 2 bins + lib + Cargo.toml + memory.x | 15/15 PASS |
| `doc/` | D+ | Markdown | (paper) | 3 | spec-traceable |
| `eda/` | E1+ | KiCad 7+ S-expr | kicad-cli (skip-clean if absent) | 4 sch + power_tree + .kicad_pcb skel + .kicad_pro + bom.csv + build_kicad.py + README | verified-parse |
| `build/` | D+ | Make + CSV | make | Makefile + bom.csv + matrix | aggregator |

`make test` from this directory runs the entire chain end-to-end.

## sim/  (Stage C + D+ extension — sim-only, runs in CI)

| File | Purpose | Sentinel | Result |
|:-----|:--------|:--------|:------:|
| `synthesis_ctrl.hexa`   | Synthesis-chamber PID + 6 interlocks         | `__HEXA_RTSC_FW_SIM_SYNTHESIS_CTRL__`   | **7/7 PASS** |
| `quench_logic.hexa`     | 48 T magnet 1-of-4 quench-detection          | `__HEXA_RTSC_FW_SIM_QUENCH_LOGIC__`     | **15/15 PASS** |
| `calorimetry_ctrl.hexa` | Bachmann 1972 relaxation method controller   | `__HEXA_RTSC_FW_SIM_CALORIMETRY_CTRL__` | **12/12 PASS** |
| `squid_daq.hexa`        | QD MPMS-3 GPIB acquisition + Tc extraction   | `__HEXA_RTSC_FW_SIM_SQUID_DAQ__`        | **9/9 PASS** |

Run individually:
```bash
hexa run firmware/sim/synthesis_ctrl.hexa
hexa run firmware/sim/quench_logic.hexa
hexa run firmware/sim/calorimetry_ctrl.hexa
hexa run firmware/sim/squid_daq.hexa
```

## hdl/  (Stage D + D+ — verified-compile + iverilog testbench)

| File | Purpose | Toolchain | Status |
|:-----|:--------|:--------|:------:|
| `quench_detect.v`   | Quench-detect FPGA (Artix-7 XC7A35T)        | iverilog ✓ + Vivado | **compiles** |
| `tb_quench_detect.v`| RTL testbench, 8 sub-tests                  | iverilog 11.0       | **12/12 PASS** |
| `calorimetry_daq.v` | Calorimetry FPGA (AD5660 DAC + LTC2400 ADC) | iverilog ✓ + Vivado | **parses**     |
| `build.tcl`         | Vivado batch synth/impl/bitstream           | Vivado 2024.2+      | (Vivado required) |
| `constraints.xdc`   | Arty A7-35T pinout + timing                 | Vivado              | — |
| `Makefile`          | iverilog wrapper + Vivado dispatch          | make                | `make sim` works today |

Build:
```bash
cd firmware/hdl
make sim                            # → 12/12 testbench PASS (works today)
make synth                          # Vivado-required, $0 commercial license tier
make flash                          # REFUSES per honesty contract (no board)
```

## mcu/  (Stage D + D+ — Rust workspace, host + embedded dual-mode)

| File | Purpose | Tests |
|:-----|:--------|:------:|
| `Cargo.toml`           | workspace + 2 bins + dev/embedded features    | — |
| `memory.x`             | STM32F407VGT6 linker (1 MiB FLASH, 192 KiB SRAM) | — |
| `lib.rs`               | shared `anchors` + `pid` + `telemetry` modules | **4/4 PASS** |
| `chamber_drv.rs`       | Synthesis chamber MCU (PID + 6 interlocks + state machine) | **5/5 PASS** |
| `calorimetry_drv.rs`   | Calorimetry MCU (relaxation method + ΔC/γTc check) | **6/6 PASS** |

Both binaries compile on host (macOS aarch64) AND embedded target via
dual-mode `#[cfg_attr(target_os="none", no_std)]`.

Build:
```bash
cd firmware/mcu
cargo build                                                # host (works today)
cargo test                                                  # → 15/15 PASS
cargo build --release --target thumbv7em-none-eabihf        # embedded cross-compile
                                                            # (no flash — no board)
```

## doc/  (Stage D+ — chip design + schematics + pinout)

| File | Purpose |
|:-----|:--------|
| `chip_design.md` | 11-row silicon BOM, full STM32F4 + Artix-7 pin assignments, ASCII schematic for quench-detect signal path (1.2 µs total << 4 µs spec), synthesis chamber control flow, 7.6 W power budget, 4-layer FR-4 PCB stackup |
| `pinout_summary.md` | Quick-ref pinouts, datasheet links for 11 ICs, spec-traceability matrix |
| `README.md` | Stage A → B → C → D → D+ layered relationship + Phase D+ status table |

## build/  (Stage D+ — master infrastructure)

| File | Purpose |
|:-----|:--------|
| `bom.csv` | 53-line master Bill of Materials (~$7.2M total over 14-20 mo to first flashed firmware) |
| `verification_matrix.md` | Single-page status board: 4 benches × 4 layers, per-component test count, toolchain status, bridge-to-physical-hardware path |

## Coverage matrix (4 benches × 4 layers)

| Bench               | Stage A spec                  | sim ✓                       | HDL                       | MCU                          | Status |
|:--------------------|:------------------------------|:---------------------------:|:-------------------------:|:----------------------------:|:------:|
| Synthesis chamber   | `doc/synthesis_bench_v0.md`   | `synthesis_ctrl.hexa` ✓     | —                         | `chamber_drv.rs` ✓           | **3/4** |
| 48 T REBCO coil     | `doc/48t_rebco_coil_v0.md`    | `quench_logic.hexa` ✓       | `quench_detect.v` + tb ✓  | —                            | **3/4** |
| Calorimetry rig     | `doc/calorimetry_rig_v0.md`   | `calorimetry_ctrl.hexa` ✓   | `calorimetry_daq.v` ✓     | `calorimetry_drv.rs` ✓       | **4/4** |
| SQUID DAQ pipeline  | `doc/synthesis_bench_v0.md §6`| `squid_daq.hexa` ✓          | —                         | (host-side via PyVISA TBD)   | **2/4** |

## Honesty contract

Per `.roadmap §A.6` and recipe `~/core/bedrock/docs/runnable_surface_recipe.md §9`:

- **Stages A → C** (paper docs + sim layers) close today + run in CI alongside `verify/*.hexa`.
- **Stage D + D+** (HDL/MCU + chip design + build infra) compile via toolchain
  + pass simulation tests, but cannot validate against physical hardware.
- All file outputs are **spec-traceable** to Stage A docs (`doc/*_v0.md`),
  Phase B sim-parity scripts (`verify/numerics_*.hexa`), and Phase C
  test cases (`firmware/sim/*.hexa`).

Real-hardware flash + cold-test → `.roadmap §A.6 Step 4` (Stage-2/3,
~$225k + 14-20 mo from funding release).

## Reproducibility

```bash
git clone https://github.com/dancinlab/hexa-rtsc
cd hexa-rtsc/firmware
brew install icarus-verilog            # iverilog 11.0+ for HDL testbench
make test                               # → 39/39 verified-build + tested
```

For per-toolchain detail see `firmware/build/verification_matrix.md`.
