# board_v0_spec — Phase C.5 unified board specification

> Phase C.5 paper-board specs for the 3 sim-firmware controllers
> (`firmware/sim/{process_corner_monitor, npu_dispatcher,
> hbm_thermal_controller}.hexa`). Bridges Phase A datasheets
> (`<verb>/doc/datasheet_*.md`) and Phase D HDL/MCU skeletons
> (`firmware/{hdl,mcu}/`). **Paper specification only — no PCB exists.**
>
> Foundry baseline (per `foundry_baseline.md` project memory):
> Samsung Foundry (logic) + SK Hynix (HBM). Canon SSOT:
> `~/core/canon/domains/compute/<topic>/<topic>.md`.
>
> Status: paper board v0 (2026-05-08). PCB / KiCad: TBD (Phase D + foundry MOU).

## 0. Scope

3 boards, each anchored to one measurable falsifier:

| board ID | falsifier | sim-firmware | Phase D HW target                      |
|:--------|:----------|:-------------|:---------------------------------------|
| HEXA-CHIP-FW-01 | F-CHIP-1 | process_corner_monitor.hexa | Samsung Foundry FPGA SoC (Lattice/Microchip equiv.) |
| HEXA-CHIP-FW-02 | F-CHIP-2 | npu_dispatcher.hexa | STM32H7 (Cortex-M7 480 MHz) + Samsung Exynos NPU IP |
| HEXA-CHIP-FW-03 | F-CHIP-3 | hbm_thermal_controller.hexa | SK Hynix HBM4 stack + Samsung Exynos host PMU |

## 1. HEXA-CHIP-FW-01 — Wafer-test corner monitor

### 1.1 Pinmap (paper)

| pin group   | width | function                              | net                |
|:------------|:------|:--------------------------------------|:-------------------|
| ADC_IN      | 8     | per-die analog leak/freq sensors      | DAC_VREF, AGND     |
| DAC_OUT     | 16    | corner-bias drivers                   | VDDQ_TUNE, VPP_DRV |
| BIST_CTRL   | 32    | wafer-test BIST chain                 | TCK, TMS, TDI, TDO |
| THERMAL_TRIP| 1     | HBM_CATTRIP equivalent                | TRIP_OUT           |
| AXI_BUS     | 64    | host SoC handshake (status / log)     | AXI4-Lite          |
| RESET_n     | 1     | global reset                          | nRST               |
| CLK_50MHZ   | 1     | sample clock                          | CLK_IN             |

### 1.2 BOM (paper)

| line item                        | candidate part            | qty | unit cost   |
|:---------------------------------|:--------------------------|:----|:------------|
| FPGA SoC (Samsung-licensable)    | Lattice ECP5 LFE5UM-85F   | 1   | ~$80        |
| 8-channel ADC                    | TI ADS131M08              | 1   | ~$25        |
| 16-channel DAC                   | AD5676R                   | 1   | ~$22        |
| Host MCU (BIST orchestrator)     | STM32G474 (Cortex-M4 170MHz)| 1 | ~$8         |
| Power: 3.3V buck                 | TPS62082                  | 1   | ~$1.20      |
| Power: 1.8V LDO                  | LM317                     | 1   | ~$0.50      |
| Misc passives + PCB (4-layer)    | -                         | -   | ~$15        |
| **Total per board**              |                           |     | **~$155**   |

Lead times: 8-12 weeks @ small qty (Digi-Key/Mouser); Samsung-licensable FPGA path adds NDA wait.

### 1.3 Power budget

| rail   | use                                 | typ mA  | peak mA |
|:-------|:------------------------------------|:--------|:--------|
| 5.0 V  | DAC + analog reference              | 80      | 200     |
| 3.3 V  | FPGA core + MCU + ADC               | 250     | 600     |
| 1.8 V  | FPGA I/O bank                       | 50      | 120     |
| 1.2 V  | FPGA core (high-perf)               | 150     | 400     |
| **PSU** | 24V → 5V/3.3V/1.8V/1.2V buck chain | -       | ~5 W peak |

### 1.4 Bring-up checklist

- [ ] Power-on (24V supply, sequencer verifies 5V/3.3V/1.8V/1.2V order)
- [ ] BIST self-test (32-bit boundary scan; expect TDO match)
- [ ] DAC ramp test (-3σ to +3σ corner-bias range)
- [ ] ADC ZERO check (no analog input → digital output ≈ midscale ± 1 LSB)
- [ ] Thermal trip simulation (force >105°C input → TRIP_OUT asserts in ≤ 100 µs)
- [ ] AXI handshake (host MCU reads status reg = expected pattern)
- [ ] Sim-firmware replay (load `firmware/sim/process_corner_monitor.hexa`
      synthesized to FPGA, verify 12-die batch produces expected bin counts)

## 2. HEXA-CHIP-FW-02 — NPU dispatcher

### 2.1 Pinmap (paper)

| pin group         | width | function                              | net                |
|:------------------|:------|:--------------------------------------|:-------------------|
| AXI4_HBM          | 256   | data path to HBM4 stack               | DQ[255:0]          |
| AXI4_INST         | 64    | layer descriptor cache                | INST[63:0]         |
| APB_CSR           | 32    | host CSR config                       | APB_*              |
| IRQ               | 1     | layer-done / fault                    | IRQ_NPU            |
| PMU_CLK           | 1     | DVFS-driven core clock                | CLK_NPU            |
| PMU_RST           | 1     | reset                                 | nRST_NPU           |
| BOOT_ROM_SEL      | 4     | boot config straps                    | BOOT[3:0]          |

### 2.2 BOM (paper)

| line item                        | candidate part                        | qty | unit cost  |
|:---------------------------------|:--------------------------------------|:----|:-----------|
| Host MCU (descriptor cache)      | STM32H723 (Cortex-M7 550 MHz, 1MB SRAM) | 1 | ~$15       |
| NPU IP target                    | Samsung Exynos NPU IP block (license) | -   | foundry NDA|
| Eval substitute (Phase D-1 only) | Coral Edge TPU dev board              | 1   | ~$60       |
| HBM emulator (DRAM + bridge)     | Lattice ECP5 + DDR4 SODIMM 8 GB       | 1   | ~$120      |
| PCIe 5.0 endpoint (host link)    | Microchip PEX8732                     | 1   | ~$45       |
| Power chain (12V → 3.3V/1.8V/0.85V) | -                                  | -   | ~$25       |
| Misc passives + PCB (8-layer)    | -                                     | -   | ~$80       |
| **Total per board**              |                                       |     | **~$345**  |

### 2.3 Power budget

| rail   | use                                  | typ mA  | peak mA |
|:-------|:-------------------------------------|:--------|:--------|
| 12.0 V | PCIe + HBM emulator                  | 200     | 400     |
| 3.3 V  | MCU + I/O                            | 200     | 500     |
| 1.8 V  | NPU IP I/O                           | 300     | 800     |
| 0.85 V | NPU IP core                          | 1000    | 3000    |
| 0.40 V | HBM4 emulator I/O (HBM3-class)       | 500     | 1500    |
| **PSU** | 12V input, ~10 W peak              | -       | ~10 W   |

### 2.4 Bring-up checklist

- [ ] Power sequencing 12 → 3.3 → 1.8 → 0.85 → 0.40 V (per Samsung NPU spec)
- [ ] PCIe link training (Gen5 x4 expected)
- [ ] AXI4 mem path latency probe (target: < 200 ns load-to-use)
- [ ] APB CSR write/read round-trip
- [ ] Boot ROM strap verification
- [ ] IRQ latency measurement (target: < 1 µs from layer-done assert)
- [ ] Sim-firmware replay (24-instr ISA n=6 layer dispatched, observe
      effective IPS ≥ 1.7 GIPS)

## 3. HEXA-CHIP-FW-03 — HBM thermal controller

### 3.1 Pinmap (paper)

| pin group         | width | function                                  | net           |
|:------------------|:------|:------------------------------------------|:--------------|
| THERMAL_SENSE_BUS | 16    | per-layer T sensor readout (16-Hi)        | TSENSE[15:0]  |
| DVFS_CTRL         | 8     | DVFS state out to host PMU                | DVFS_OUT[7:0] |
| CATTRIP           | 1     | thermal trip output (latch)               | TRIP_LATCH    |
| I2C_SMBUS         | 2     | SMBus to host SoC (HBM_TEMP register)     | SDA, SCL      |
| HBM4_DQ           | 2048  | data path (HBM4 wide bus)                 | DQ[2047:0]    |
| HBM4_DQS          | 32    | strobe                                    | DQS[31:0]     |
| HBM4_RESET_n      | 1     | reset                                     | nRST_HBM      |
| HBM4_CK           | 16    | diff clocks                               | CK_p, CK_n    |

### 3.2 BOM (paper)

| line item                        | candidate part                        | qty | unit cost  |
|:---------------------------------|:--------------------------------------|:----|:-----------|
| HBM4 stack                       | SK Hynix HBM4 16-Hi 48 GB             | 1   | ~$1500 (sample qty) |
| Si interposer (2.5D, CoWoS-class)| custom (Samsung Foundry partner)      | 1   | foundry MOU|
| Host MCU (thermal coordinator)   | STM32H7 + ADS1115 16-bit ADC          | 1+1 | ~$22       |
| DVFS controller (analog)         | Renesas RAA489204 multi-rail PMU      | 1   | ~$8        |
| Eval substitute (Phase D-1 only) | DDR4 SODIMM 16 GB + thermal phantom   | 1   | ~$80       |
| Power chain (24V → multi-rail)   | -                                     | -   | ~$60       |
| Misc passives + PCB (10-layer HDI) | -                                   | -   | ~$200      |
| **Total per board (sample qty)** |                                       |     | **~$1870** |

### 3.3 Power budget

| rail    | use                                     | typ mA  | peak mA |
|:--------|:----------------------------------------|:--------|:--------|
| 24.0 V  | input rail                              | -       | -       |
| 1.10 V  | DRAM core (HBM4 spec)                   | 4000    | 9000    |
| 0.85 V  | LBD logic                               | 1000    | 2500    |
| 0.40 V  | DDR I/O (HBM3-class compat)             | 2000    | 5500    |
| 1.80 V  | DRAM peripheral                         | 200     | 500     |
| 3.30 V  | Host MCU + I2C + ADC                    | 150     | 300     |
| **PSU** | total HBM stack budget ~35 W peak       | -       | ~35 W   |

### 3.4 Bring-up checklist

- [ ] Power sequencing per HBM4 spec (1.1V → 0.85V → 0.40V → 1.8V order)
- [ ] HBM4 stack reset + initialization (training pattern)
- [ ] Per-layer thermal sensor readout (16 sensors via I2C SMBus)
- [ ] DVFS engagement at 90°C threshold (synthetic heater test)
- [ ] CATTRIP latch test (force >105°C input → TRIP_LATCH asserts < 100 µs)
- [ ] HBM4 wide-bus link training (2048-bit DQ + 32-bit DQS)
- [ ] Sim-firmware replay (Jacobi 50-iter convergence to linear profile)
- [ ] Stress test: 35W full-load, monitor T_J max < 105°C for 24h

## 4. Cross-board common (all 3)

### 4.1 Test connectors

| connector | purpose                    | std        |
|:----------|:---------------------------|:-----------|
| JTAG 20-pin | debug + boundary scan    | ARM JTAG   |
| SWD 4-pin   | Cortex-M debug           | SWD        |
| USB-C       | host link + power-aux    | USB 3.2    |
| Ethernet RJ45 | log streaming          | 100Base-TX |

### 4.2 EMI / shielding

- 4-layer PCBs minimum; HBM controller board uses 10-layer HDI for impedance control.
- All HBM-side traces length-matched ± 5 mil within byte-lane.
- Conducted-EMI per FCC Class B, AEC-Q100 grade-3 path optional.
- Shielded enclosure required for HBM4 high-speed signaling.

### 4.3 Provenance

- Phase A datasheets: `<verb>/doc/datasheet_{hbm,npu_n6,process}.md`
- Phase B numerics:   `verify/numerics_{spice_corner,rtl_isa_n6,power_thermal}.hexa`
- Phase C sim-firmware: `firmware/sim/*.hexa`
- Phase D HDL/MCU:    `firmware/{hdl,mcu}/` (next iter)
- Roadmap:            `.roadmap.hexa_chip §A.6 / §A.6.1`
- Canon SSOT:         `~/core/canon/domains/compute/<topic>/<topic>.md`

## 5. Open issues / next-step gates

| gate | needs                                              | resolves       |
|:-----|:---------------------------------------------------|:---------------|
| G1   | Samsung Foundry MOU (PDK + RTL libs + NPU IP)      | F-CHIP-1/2 D   |
| G2   | SK Hynix sample-qty HBM4 16-Hi (sample $$)         | F-CHIP-3 D     |
| G3   | Si interposer fab partner (CoWoS-class)            | F-CHIP-3 board |
| G4   | KiCad schematic + Gerber for all 3 boards          | PCB qty=10     |
| G5   | Funding for 10-board run + lab equipment           | actual builds  |
| G6   | EMI compliance test cycle                          | qual           |

v0.1 freeze: 2026-05-08. v0.2 after Phase D HDL/MCU skeletons land.
