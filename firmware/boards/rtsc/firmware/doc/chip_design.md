# Chip Design — hexa-rtsc Phase D+ silicon selection + pinout

> §A.6.1 Phase D+ deliverable per `.roadmap.hexa_rtsc`. **Verified-design
> only** — no physical board, no flash. Skeleton-traceable to
> `doc/{synthesis_bench, 48t_rebco_coil, calorimetry_rig}_v0.md`
> (Stage A specs).

## §1 Silicon inventory

| Subsystem | IC | Package | Vendor | Cost (per unit) | Notes |
|:---------|:---|:--------|:------|:---------------:|:------|
| Synthesis chamber MCU | STM32F407VGT6 | LQFP-100 | ST | $12 | Cortex-M4F @ 168 MHz, 1 MiB FLASH, 192 KiB SRAM |
| Quench-detect FPGA    | XC7A35T-1CSG324C | CSG-324 | Xilinx (AMD) | $30 | Artix-7, 33k LUTs, 50 BRAM |
| Calorimetry FPGA      | XC7A35T-1CSG324C | CSG-324 | Xilinx | $30 | shared family for toolchain reuse |
| Calorimetry MCU       | STM32F407VGT6 | LQFP-100 | ST | $12 | shared family for chamber MCU |
| Heat-pulse DAC        | AD5660BRMZ-1 | MSOP-10 | Analog Devices | $13 | 16-bit, 1.25 µs settle, SPI |
| Pt-RTD ΣΔ ADC         | LTC2400CS8    | SOIC-8  | Linear Technology | $11 | 24-bit, 7.5 Hz, 4 ppm INL |
| REBCO voltage tap ADC | LTC2378-20    | DFN-16  | Linear Technology | $48 | 20-bit, 1 MS/s, ±5V differential |
| Hall probe (B + dB/dt)| Group3 LPT-141 | enclosure | Group3 (NZ) | $1.8k | 0–50 T, 1 ppm linearity |
| Cernox sensor         | CX-1080-CU    | bare die  | Lake Shore | $440 | 1.5–325 K, 1 mK accuracy below 5 K |
| Cs frequency ref      | Cs 5071A      | 1U rack   | Microsemi | $50k | 10 MHz reference, 5×10⁻¹³ stability |
| Power supply (PSU)    | American Magnetics 4Q | 4U rack | American Magnetics | $85k | 0–600 A, 4-quadrant, EtherCAT |

**Subtotal silicon (excluding rack instruments)**: ≈ $4.6k for 4 main boards.
**Subtotal full electronics (with rack)**: ≈ $140k (Cs ref + PSU dominate).

## §2 Pin assignments — Synthesis chamber MCU (STM32F407VGT6)

| Pin | Net | Direction | Notes |
|:---:|:----|:--------:|:------|
| PA0 | FURNACE_TEMP_PT100_1 | analog in | RTD #1 (4-wire) |
| PA1 | FURNACE_TEMP_PT100_2 | analog in | RTD #2 |
| PA2 | UART_TX | digital out | host link, 1 Mbaud |
| PA3 | UART_RX | digital in  | host link |
| PA4 | DAC_FURNACE_PWR | analog out | 12-bit DAC, 0–10 V via op-amp |
| PA5 | DAC_PRESSURE_CMD | analog out | 12-bit, control to high-P PSU |
| PA6 | LOAD_CELL_HIGH_P | analog in | strain gauge bridge |
| PA7 | O2_GLOVEBOX | analog in  | 0–5 V O₂ sensor |
| PA8 | H2S_SENSOR | digital in | open-collector alarm at 5 ppm |
| PA9 | EXTRACTOR_OK | digital in | dry-contact, low = fault |
| PA10| LED_STATUS_GREEN | digital out | normal operation |
| PA11| LED_STATUS_RED | digital out | fault / abort |
| PB0 | I2C1_SCL | open-drain | EBSD camera bus |
| PB1 | I2C1_SDA | open-drain | EBSD camera bus |
| PB2 | EMERGENCY_STOP | digital in | pull-up, NC contact |
| PB6 | SPI1_SCK | digital out | XRD detector clock |
| PB7 | SPI1_MISO | digital in | XRD detector data |
| PD8 | TIM4_CH1 | timer out | PWM → SSR for furnace heater |
| PD9 | TIM4_CH2 | timer out | PWM → high-P pump motor |
| PE0..7 | GPIO debug bus | digital out | logic analyzer pins |

Reserved: PB3, PB4 (SWO/SWCLK debug), PA13/PA14 (SWDIO/SWCLK).

## §3 Pin assignments — Quench-detect FPGA (XC7A35T on Arty A7-35T)

See `firmware/hdl/constraints.xdc` for full pin map.

Summary:

| Net | FPGA pin | Function |
|:----|:--------:|:---------|
| clk_100mhz_i | E3 | onboard 100 MHz oscillator |
| rst_n_i | A8 | SW0 (active-low via inverter) |
| v_rebco_i[15:0] | F4..J8 | 16-bit ADC LVDS to PMOD JA/JB |
| v_bitter_i[15:0] | (PMOD JC) | 16-bit ADC, mirror layout |
| dbdt_hall_i[15:0] | (PMOD JD) | Hall probe digitized output |
| t_cernox_i[15:0] | (PMOD JD high) | Cernox temperature delta |
| igbt_gate_o | D4 | IGBT gate signal (3.3 V → opto-isolator) |
| channel_trip_o[3:0] | H5/J5/T9/T10 | onboard LD0..LD3 |
| confirm_cernox_o | F6 | onboard LD7 |

## §4 ASCII schematic — Quench-detect signal path

```
                       MAGNET ROOM (cold)                          QUENCH RACK (warm)
  ┌─────────────────────────────────────────┐            ┌──────────────────────────────────┐
  │                                         │            │                                  │
  │  REBCO coil ─┬─[v_tap+]──┐              │            │                                  │
  │              ├─[v_tap-]──┤  diff. amp   │ shielded   │  LTC2378-20  ┌──────────────┐   │
  │              │           │ (×100, AD8429)│ twisted    │  20-bit ADC  │              │   │
  │              │           └───→  isolator ├─pair, SMA──→  1 MS/s    →─→  XC7A35T    │   │
  │              │           (TI ISO224)    │            │              │  Artix-7     │   │
  │              │                          │            │              │  Quench      │   │
  │              │                          │            │              │  detect      │   │
  │  Bitter coil ┤                          │            │              │              │   │
  │              ├──────────────────────────┼────────────┤  LTC2378-20 →┤              │   │
  │              │                          │            │              │              │   │
  │  Hall probe  ┴──[B-field]→ Group3       │            │  on-probe    │              │   │
  │  (Group3)                  amplifier    │            │  16-bit out →┤              │   │
  │                                         │            │              │              │   │
  │  Cernox sensor ─[T(t)]─┐ Lake Shore     │            │              │              │   │
  │                        │ 218 monitor    │            │  16-bit RS232→┤              │   │
  │                        │ (slow, 1 ms)   │            │              └──────┬───────┘   │
  │                        │                │            │                     │           │
  └────────────────────────┼────────────────┘            │                     │ 50 ns prop│
                           │                             │                     ▼           │
                           │ CRYOGEN BOUNDARY            │              ┌──────────────┐  │
                           │                             │              │ IGBT gate    │  │
                           │                             │              │ (TLP358 opto)│  │
                           │                             │              └──────┬───────┘  │
                           │                             │                     │ 3.3V→24V │
                           │                             │                     ▼          │
                           │                             │              ┌──────────────┐  │
                           │                             │              │ IGBT module  │  │
                           │                             │              │ Infineon     │  │
                           │                             │              │ FF1400R12IP4 │  │
                           │                             │              │ 1.4 kA peak  │  │
                           │                             │              └──────┬───────┘  │
                           │                             │                     │ dump     │
                           │                             │                     ▼          │
                           │                             │              ┌──────────────┐  │
                           │                             │              │ Dump resistor│  │
                           │                             │              │ 0.5 Ω, water │  │
                           │                             │              │ -cooled, 30  │  │
                           │                             │              │ MJ rating    │  │
                           │                             │              └──────────────┘  │
                           │                             └──────────────────────────────────┘
                           │
                           ▼ (mechanical: dump cools coil)
```

Key timing path (worst-case quench):

```
  REBCO v_tap rises  ──→  AD8429 diff amp     →   ~50 ns
                     ──→  ISO224 isolator      →  ~100 ns
                     ──→  LTC2378-20 ADC       →  300 ns (1 MS/s, 1 cycle)
                     ──→  FPGA threshold cmp   →   10 ns (1 cycle @ 100 MHz)
                     ──→  IGBT gate output     →   10 ns (1 cycle)
                     ──→  TLP358 opto isolator → ~250 ns
                     ──→  IGBT switching       → ~500 ns
                     ──────────────────────────────────────
                                   total       ≈ 1.2 µs   (well under 4 µs spec)
```

## §5 ASCII schematic — Synthesis chamber control

```
                  HOST PC (USB-C)
                        │
                        │ FT232H bridge (USB → 1 Mbaud UART)
                        ▼
   ┌───────────────────────────────────────────────────────────┐
   │  STM32F407VGT6 (synthesis chamber MCU)                    │
   │                                                            │
   │   PA0 ────────[Pt100 RTD #1]                              │
   │   PA1 ────────[Pt100 RTD #2]                              │
   │   PA4 ──→[12-bit DAC]→[op-amp 0–10 V]→[SSR]→[furnace coil]│
   │   PA5 ──→[12-bit DAC]→[high-P PSU EtherCAT]               │
   │   PA6 ←──[strain gauge bridge ×4]                         │
   │   PA7 ←──[O₂ sensor 0–5 V]                                │
   │   PA8 ←──[H₂S monitor open-coll]                          │
   │   PA9 ←──[Pb extractor flow contact]                      │
   │   PA10→[GREEN LED]                                         │
   │   PA11→[RED LED]                                           │
   │   PB2 ←──[E-stop NC switch]                               │
   │   PB6/7──[SPI ←→ XRD detector]                            │
   │   PB0/1──[I²C ←→ EBSD camera]                             │
   │   PD8 ──[TIM4 PWM → furnace SSR]                          │
   │   PD9 ──[TIM4 PWM → high-P pump]                          │
   └───────────────────────────────────────────────────────────┘
                        │
                        │ EtherCAT (Beckhoff EL3xxx slice cards)
                        ▼
              FACILITY SAFETY PANEL
              (interlock OR with software interlocks)
```

## §6 Power budget

| Subsystem | Voltage | Current (avg) | Power |
|:---------|:-------:|:-------------:|:-----:|
| STM32F4 + ancillaries | 3.3 V | 200 mA | 0.66 W |
| Artix-7 FPGA | 1.0 V core + 3.3 V I/O | 1 A + 100 mA | 1.33 W |
| AD8429 diff amps ×4 | ±15 V | 80 mA | 2.4 W |
| ISO224 isolators ×4 | ±15 V | 50 mA | 1.5 W |
| LTC2378-20 ADCs ×4 | 5 V + 3 V ref | 80 mA + 30 mA | 0.49 W |
| Cernox bias current | 1 mV @ 10 µA | 0.01 µA | nW (negligible) |
| TLP358 opto + IGBT gate | 24 V | 50 mA | 1.2 W |
| **Total board** |  |  | **~ 7.6 W** |
| (add IGBT dump events: peak 30 MW for ~1 s, avg negligible) | | | |

Linear regulators: TPS7A (low-noise 3.3 V/5 V/15 V).
Reverse-protection: TI LM5060 hot-swap controllers on all rails.

## §7 PCB stackup (planned)

4-layer FR-4, 1.6 mm:

```
  TOP   (signal + analog) ────────── 35 µm Cu, soldermask
  GND   (continuous plane)
  PWR   (split: 3.3 / 5 / 15 V planes)
  BOT   (signal, ground stitching)
```

Impedance control: 50 Ω SE / 100 Ω diff for ADC LVDS pairs.
Class-2 IPC standard. ENIG finish for cryogenic thermal cycling
robustness. SMA connectors for all rack-bound signals.

PCB fab cost: ~$1k for 5-board pilot run (PCBWay 2-week lead).
Population (PCBA): ~$2k assembly per board (JLCPCB).

## §8 Cross-references

- `doc/synthesis_bench_v0.md`     — Stage A spec, BOM #1–14
- `doc/48t_rebco_coil_v0.md`      — Stage A spec, BOM #1–15
- `doc/calorimetry_rig_v0.md`     — Stage A spec, BOM #1–8
- `firmware/sim/synthesis_ctrl.hexa` (7/7 PASS) — Stage C sim
- `firmware/sim/quench_logic.hexa` (15/15 PASS) — Stage C sim
- `firmware/hdl/quench_detect.v` + `tb_quench_detect.v` (12/12 PASS via iverilog) — Phase D+
- `firmware/hdl/calorimetry_daq.v` — Phase D+ FPGA skeleton
- `firmware/mcu/{chamber_drv, calorimetry_drv}.rs` (15/15 PASS via cargo test) — Phase D+ host

## §9 Honesty contract

This document is **paper design**. No PCB has been fabricated, no
silicon has been procured, no firmware has been flashed. All pin
assignments and schematic topology are spec-traceable to Stage A docs
and Phase C/D code, but only the silicon/PCB build (§A.6 Step 4) can
validate them physically.

Build path: §A.6 Step 1 (collab) → Step 2 (funding) → Step 4 (PCB
+ procurement + cold-test). Years out, not in code-layer scope.
