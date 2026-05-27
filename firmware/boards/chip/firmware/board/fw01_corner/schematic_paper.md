# HEXA-CHIP-FW-01 — Paper schematic (block level)

> ASCII block-level schematic for the process corner monitor board.
> Falsifier: F-CHIP-1. Phase E iter 1, paper-tier only.
> Sources: `firmware/doc/board_v0_spec.md §1`, `firmware/hdl/process_corner_top.v`,
> `firmware/mcu/corner_seq.hexa`.

## 1. Block-level diagram

```
  +-------------------+        +----------------------------+
  |   USB-C (host)    |<------>|  STM32G474 (host MCU)      |
  |  + power-aux 5V   |        |  Cortex-M4 @ 170 MHz       |
  +-------------------+        |  BIST orchestrator         |
                               |  - corner_seq.hexa         |
                               +----------------------------+
                                  |  SPI1 (MCU↔FPGA, 25 MHz)
                                  |  IRQ_FPGA → MCU EXTI
                                  v
                               +----------------------------+
                               |  Lattice ECP5 LFE5UM-85F   |
                               |  FPGA, 84 K LUT            |
                               |  - process_corner_top.v    |
                               |  - 32-bit boundary scan    |
                               |  - DAC ramp + ADC capture  |
                               +----------------------------+
                                |  SPI2 (FPGA↔ADC)          | SPI3 (FPGA↔DAC)
                                v                            v
                          +-----------+              +-----------------+
                          | TI ADS131M08 |           | AD5676R         |
                          | 8-ch ADC     |           | 16-ch DAC       |
                          | 24-bit Δ-Σ   |           | 16-bit          |
                          +-----------+              +-----------------+
                                |                            |
                                v                            v
                          ADC_IN[7:0]                  DAC_OUT[15:0]
                          (per-die leak                (corner-bias drv,
                           + freq sense)                VDDQ_TUNE/VPP_DRV)

  +-------------------+    +-----------+      +-----------+
  | RJ45 100Base-TX   |    | JTAG 20p  |      | SWD 4p    |
  | log Ethernet      |    | bnd-scan  |      | SWD debug |
  +-------------------+    +-----------+      +-----------+
        |                       |                  |
        +-> MCU MAC RMII        +-> FPGA + MCU     +-> MCU SWD
```

## 2. Power rail tree

```
  24V DC barrel jack (or USB-C 20V PD)
        |
        v
  [LMR16030 buck] ── 5.0 V ──>  AD5676R analog ref (VDD_DAC)
        |                       ADS131M08 analog (AVDD)
        v
  [TPS62082 buck] ── 3.3 V ──>  STM32G474 (VDD)
        |                       FPGA aux I/O bank
        |                       ADC digital (DVDD)
        v
  [LM317 LDO]    ── 1.8 V ──>  ECP5 I/O bank (VCCIO)
        |
        v
  [LP3878 LDO]   ── 1.2 V ──>  ECP5 core (VCCINT)

  Sequencer: TPS3823 supervises 3.3V/1.8V/1.2V order; nRST released only
             after all rails > 90% of nominal.
```

## 3. Net list (paper)

| net           | width | from               | to                       | electrical               |
|:--------------|:------|:-------------------|:-------------------------|:-------------------------|
| SPI1_*        | 4     | STM32G474          | ECP5 (CFG)               | 3.3V LVCMOS, 25 MHz      |
| SPI2_*        | 4     | ECP5               | ADS131M08                | 3.3V LVCMOS, 8 MHz       |
| SPI3_*        | 4     | ECP5               | AD5676R                  | 3.3V LVCMOS, 25 MHz      |
| ADC_IN[7:0]   | 8     | DUT die            | ADS131M08 inputs         | diff ±2.5V               |
| DAC_OUT[15:0] | 16    | AD5676R outputs    | corner-bias drivers      | 0–5V analog              |
| BIST_CTRL     | 32    | ECP5 (TAP ctrl)    | DUT JTAG chain           | 3.3V LVCMOS              |
| THERMAL_TRIP  | 1     | ECP5 (latch)       | TRIP_OUT pin header      | 3.3V LVCMOS, async       |
| AXI_BUS       | 64    | ECP5               | STM32G474 (FMC bridge)   | 3.3V LVCMOS, 50 MHz      |
| RESET_n       | 1     | TPS3823            | all (global)             | 3.3V LVCMOS, async       |
| CLK_50MHZ     | 1     | 50 MHz xtal osc    | ECP5 + STM32G474         | LVCMOS                   |
| JTAG_*        | 4     | JTAG 20p header    | ECP5 + STM32G474         | TCK/TMS/TDI/TDO          |
| SWD_*         | 2     | SWD 4p header      | STM32G474 SWD            | SWDIO/SWCLK              |

## 4. Connector table

| connector | function                  | pin count | std        | notes                          |
|:----------|:--------------------------|:----------|:-----------|:-------------------------------|
| J1 USB-C  | host link + power-aux     | 24        | USB 3.2    | 5V@3A power, USB 2.0 data link |
| J2 RJ45   | log Ethernet              | 8         | 100Base-TX | streams `corner_seq` log       |
| J3 JTAG   | debug + boundary scan     | 20        | ARM JTAG   | covers FPGA + MCU              |
| J4 SWD    | Cortex-M4 debug           | 4         | SWD        | STM32G474 only                 |
| J5 PWR    | 24V DC barrel jack        | 2         | 2.1mm coax | alt to USB-C                   |
| J6 DUT    | DUT die test connector    | 80        | custom     | ADC_IN + DAC_OUT + BIST_CTRL   |

## 5. Component count summary

| category                 | count | notes                          |
|:-------------------------|:------|:-------------------------------|
| Active ICs (FPGA/MCU/etc)| 4     | ECP5, STM32G474, ADS131M08, AD5676R |
| Power rails (buck+LDO)   | 4     | 24V→5V, 5V→3.3V, 3.3V→1.8V, 3.3V→1.2V |
| Connectors               | 6     | USB-C, RJ45, JTAG, SWD, PWR, DUT |
| Passives (R/C/L est.)    | ~150  | decoupling + signal term + filter |
| Crystals / oscillators   | 2     | 50 MHz main + 32.768 kHz RTC   |

## 6. PCB footprint estimate

- **Target:** 100 × 80 mm, 4-layer FR-4, 1.6 mm thickness.
- **Stack-up:** Sig / GND / PWR / Sig.
- **Impedance:** 50 Ω single-ended, 100 Ω diff (USB / Ethernet).
- **Test points:** 12 (one per power rail, plus SPI clk/data).
- **Mounting:** 4× M3 corners.

## 7. Cross-references

- Pinmap (full): `firmware/doc/board_v0_spec.md §1.1`.
- Power budget: `firmware/doc/board_v0_spec.md §1.3`.
- Bringup: `firmware/doc/board_v0_spec.md §1.4`.
- Verilog top: `firmware/hdl/process_corner_top.v`.
- MCU host: `firmware/mcu/corner_seq.hexa`.
- BOM aggregate: `firmware/board/bom_master.csv` (rows board=fw01_corner).
