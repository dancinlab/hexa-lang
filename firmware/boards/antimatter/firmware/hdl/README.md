# `firmware/hdl/` — Phase D Verilog skeletons

> §A.6.1 Phase D scope.  Synthesizable HDL skeletons for the 4 Stage-1
> benchtop FPGAs (Xilinx UltraScale+ family).  **Compiles** with Vivado
> 2024.1+ but **not flashable** until physical boards arrive.

**Status**: skeleton (2026-05-08) · **Toolchain**: Vivado Design Edition 2024.1 · **Boards**: ✗ (Phase D awaits funding)

---

## §1 Module inventory

### Verilog tops

| File | Target board | FPGA | Package | Sim source |
|:-----|:-------------|:-----|:--------|:-----------|
| `cyclotron_trigger.v` | board_v0_pet_cyclotron | (n/a — STM32) | LQFP-100 | sim/cyclotron_trigger.hexa |
| `penning_rf.v` | board_v0_tabletop_penning | XCZU9EG | FFVC900-1 | sim/penning_rf.hexa |
| `atomic_clock.v` | board_v0_atomic_clock | XCKU040 | FFVA1156-1 | sim/atomic_clock_counter.hexa |
| `thrust_acq.v` | board_v0_thrust_acquisition | XCVU13P | FLGA2577-1 | sim/thrust_acquisition.hexa |

### Vivado constraints (.xdc)

| File | Pin LOC | Clocks | Max-delay constraints |
|:-----|:-------:|:------:|:---------------------:|
| `penning_rf.xdc` | 16 LVDS DAC + 14 LVDS ADC + RS-485 + cryo interlock + UART + LEDs | 100 MHz ref + 156.25 MHz DAC + 312.5 MHz sys | safety-interlock < 5 ns to sys_clk |
| `atomic_clock.xdc` | TDC SPI + LVDS start/stop pairs + 24-bit ADC + ADF4356 SPI + photodiode + UART | 10 MHz Cs ref + 1 GHz DDS + 250 MHz sys + 30 MHz ADC | TDC start↔stop pair ≤ 1 ns |
| `thrust_acq.xdc` | 16 GTYE4 ADC lanes + JESD204C SYSREF + 16-way trigger fan-out + Watt-balance LVDS + BGO/ToF + DDR4 + PCIe + NIM | 10 MHz ref + 1 GHz sys + 32 Gbps adc_jesd_clk | trigger fan-out skew ≤ 1 ns; BGO↔ToF coincidence ≤ 50 ns |

(`cyclotron_trigger` is MCU-only — STM32H7 controller, no FPGA.  See
`firmware/mcu/pet_cyclotron.rs` for that board's logic.  No `.xdc` for it.)

## §2 Build (Vivado)

```bash
cd firmware/hdl
vivado -mode batch -source build.tcl
```

`build.tcl` per-target sets:
- target FPGA part
- timing constraints (.xdc)
- IP catalog (clock wizards, MIG, JESD204C, PCIe)
- synthesis + implementation + bitstream

## §3 Out of scope (this skeleton)

- Vivado IP customizations (DDR controller params, JESD204C SerDes
  config) — needs board-specific `.xdc` constraints
- Timing closure for highest-speed paths (32 Gbps GTYE4) — only viable
  with real-board signal integrity data
- Bitstream encryption / DPA countermeasures
- ChipScope / ILA debug instances
- Hardware test benches (board-required)

## §4 Verification

Each module has a Verilator testbench under `tb/` (skeleton, not yet
runnable in repo because Verilator setup is per-host):

```
firmware/hdl/
├─ README.md             (this file)
├─ cyclotron_trigger.v   (pure-Verilog spec; STM32-target board)
├─ penning_rf.v          (UltraScale+ MPSoC PL skeleton)
├─ atomic_clock.v        (Kintex UltraScale skeleton)
├─ thrust_acq.v          (Virtex UltraScale+ skeleton)
└─ build.tcl             (Vivado entry — placeholder)
```

## §5 Cross-link

- `firmware/sim/*.hexa` — golden behavioral sim (PASS criterion)
- `firmware/doc/board_v0_*.md` — pinout + BOM source (4 boards)
- `firmware/doc/schematic_v0_*.md` — block diagram + net list + PCB stackup hints (4 boards, KiCad-ready)
- `firmware/doc/PHASE_E_HARDWARE_PATH.md` — KiCad → fab → bring-up roadmap + vendor matrix + funding ladder
- `firmware/mcu/*.rs` — MCU companion code (PS-side on MPSoC; full STM32 controller for PET board)
- `verify/firmware_phase_d_lint.hexa` — paper-spec drift catcher (audits .v + .xdc + .md cross-links)
- `.roadmap §A.6 step 4` — actual board build (Phase E1 onward)
