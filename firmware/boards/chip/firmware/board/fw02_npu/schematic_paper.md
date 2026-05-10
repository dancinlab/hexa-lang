# HEXA-CHIP-FW-02 — Paper schematic (block level)

> ASCII block-level schematic for the NPU dispatcher board.
> Falsifier: F-CHIP-2. Phase E iter 1, paper-tier only.
> Sources: `firmware/doc/board_v0_spec.md §2`, `firmware/hdl/isa_n6_top.v`,
> `firmware/mcu/npu_host.hexa`.

## 1. Block-level diagram

```
  +-------------------+        +----------------------------+
  |   USB-C (host)    |<------>|  STM32H723 (host MCU)      |
  |  data + 5V aux    |        |  Cortex-M7 @ 550 MHz       |
  +-------------------+        |  1 MB SRAM                 |
                               |  Descriptor cache + APB    |
                               |  - npu_host.hexa           |
                               +----------------------------+
                                  |  FMC parallel bus
                                  |  IRQ_NPU → MCU EXTI
                                  |  APB CSR config bus
                                  v
                               +----------------------------+
                               |  Xilinx Zynq UltraScale+   |
                               |  XCZU7EV (NPU emulator)    |
                               |  504 K LUT + 4× A53 + R5   |
                               |  - isa_n6_top.v            |
                               |  - 24-instr ISA dispatch   |
                               +----------------------------+
                                |  AXI4 256-bit               | AXI4 PCIe
                                v                              v
                          +-------------+              +------------------+
                          | DDR4 SODIMM |              | Microchip PEX8732 |
                          | 8 GB        |              | PCIe Gen5 x4     |
                          | (HBM4 emul) |              | endpoint         |
                          | 3200 MT/s   |              +------------------+
                          +-------------+                      |
                                                              v
                                                       PCIe edge x4
                                                       (host server link)

  +-------------------+    +-----------+      +-----------+
  | RJ45 100Base-TX   |    | JTAG 20p  |      | SWD 4p    |
  | log Ethernet      |    | bnd-scan  |      | SWD debug |
  +-------------------+    +-----------+      +-----------+
        |                       |                  |
        +-> MCU MAC RMII        +-> Zynq + MCU     +-> MCU SWD
```

## 2. Power rail tree

```
  12V ATX-style (or USB-C 20V PD)
        |
        v
  [LMZ31707 buck] ── 3.3 V ──>  STM32H723, MCU I/O, PEX8732 aux
        |                       Zynq aux supply
        v
  [LMZ31506 buck] ── 1.8 V ──>  Zynq I/O bank, DDR4 VDDIO
        |                       NPU IP I/O (per Samsung Exynos spec)
        v
  [LTM4638 buck] ── 0.85 V ──>  Zynq core (VCCINT) — NPU IP core
        |
        v
  [LTM4624 buck] ── 0.40 V ──>  HBM4 emulator I/O (HBM3-class compat)

  Sequencer: TI TPS65094 PMIC governs 3.3 → 1.8 → 0.85 → 0.40 V order
             per Samsung NPU IP spec; nRST_NPU released after all-good.
```

## 3. Net list (paper)

| net               | width | from           | to                  | electrical               |
|:------------------|:------|:---------------|:--------------------|:-------------------------|
| AXI4_HBM_DQ       | 256   | Zynq           | DDR4 SODIMM         | 1.2V SSTL, 3200 MT/s     |
| AXI4_HBM_ADDR     | 18    | Zynq           | DDR4 SODIMM         | 1.2V SSTL                |
| AXI4_HBM_CTL      | 12    | Zynq           | DDR4 SODIMM         | 1.2V SSTL                |
| AXI4_INST         | 64    | STM32H723 FMC  | Zynq                | 3.3V LVCMOS, 100 MHz     |
| APB_CSR           | 32    | STM32H723      | Zynq APB target     | 3.3V LVCMOS, 50 MHz      |
| IRQ_NPU           | 1     | Zynq           | STM32H723 EXTI      | 3.3V LVCMOS, async       |
| PCIE_TX/RX        | 8     | Zynq           | PEX8732             | PCIe Gen5 differential   |
| PCIE_REFCLK       | 1     | 100 MHz osc    | Zynq + PEX8732      | HCSL diff                |
| PMU_CLK           | 1     | Si5341 osc     | Zynq DVFS PLL ref   | LVDS                     |
| PMU_RST           | 1     | TPS65094       | all                 | 3.3V LVCMOS              |
| BOOT_ROM_SEL      | 4     | DIP switch     | Zynq boot mode      | 3.3V LVCMOS              |
| JTAG_*            | 4     | JTAG 20p       | Zynq + STM32H723    | TCK/TMS/TDI/TDO          |
| SWD_*             | 2     | SWD 4p         | STM32H723 SWD       | SWDIO/SWCLK              |

## 4. Connector table

| connector | function                  | pin count | std        | notes                          |
|:----------|:--------------------------|:----------|:-----------|:-------------------------------|
| J1 USB-C  | host link + power-aux     | 24        | USB 3.2    | 5V@3A aux                      |
| J2 RJ45   | log Ethernet              | 8         | 100Base-TX | streams `npu_host` log         |
| J3 JTAG   | debug + boundary scan     | 20        | ARM JTAG   | covers Zynq + MCU              |
| J4 SWD    | Cortex-M7 debug           | 4         | SWD        | STM32H723 only                 |
| J5 PCIE   | PCIe Gen5 x4 edge fingers | 64        | PCIe CEM   | host server attach             |
| J6 ATX    | 12V ATX-style 6-pin       | 6         | EPS        | main power input               |
| J7 SODIMM | DDR4 SODIMM 260-pin       | 260       | JEDEC      | 8 GB HBM emul (DDR4 3200)      |

## 5. Component count summary

| category                 | count | notes                          |
|:-------------------------|:------|:-------------------------------|
| Active ICs               | 4     | Zynq, STM32H723, PEX8732, PMIC |
| Memory modules           | 1     | DDR4 SODIMM 8 GB               |
| Power rails (buck)       | 4     | 12V→3.3V/1.8V/0.85V/0.40V      |
| Connectors               | 7     | USB-C, RJ45, JTAG, SWD, PCIE, ATX, SODIMM |
| Passives (R/C/L est.)    | ~400  | DDR4 + PCIe Gen5 = many decouplers |
| Crystals / oscillators   | 3     | 100 MHz PCIe ref, 50 MHz main, 32.768 kHz RTC |

## 6. PCB footprint estimate

- **Target:** 160 × 120 mm, 8-layer FR-4 + Megtron, 1.6 mm thickness.
- **Stack-up:** Sig / GND / Sig / PWR / PWR / Sig / GND / Sig.
- **Impedance:** 50 Ω single-ended, 85 Ω diff (PCIe Gen5), 100 Ω diff (USB).
- **Length matching:** DDR4 byte-lane ± 5 mil; PCIe lane skew ± 1 mil.
- **Test points:** 24 (per power rail × 2, plus SPI/APB/AXI taps).
- **Mounting:** 4× M3 corners, 1× extra under Zynq for thermal anchor.

## 7. Cross-references

- Pinmap (full): `firmware/doc/board_v0_spec.md §2.1`.
- Power budget: `firmware/doc/board_v0_spec.md §2.3`.
- Bringup: `firmware/doc/board_v0_spec.md §2.4`.
- Verilog top: `firmware/hdl/isa_n6_top.v`.
- MCU host: `firmware/mcu/npu_host.hexa`.
- BOM aggregate: `firmware/board/bom_master.csv` (rows board=fw02_npu).
