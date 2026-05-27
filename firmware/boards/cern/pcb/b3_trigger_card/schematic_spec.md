# B3 trigger card — schematic spec

> §A.6.1 step E2.1 — net list and component placement, transcribable to KiCad.

## §1 Block diagram

```
                         +12V                 +12V
                          │                    │
                          ▼                    ▼
                       ┌────┐  ┌──┐  ┌──┐  ┌──────┐
                  POWER│ F1 │──│L1│──│U8│──│C_BULK│ → 5V0
                  IN J1└────┘  └──┘  └──┘  └──────┘ → 3V3 (U9)
                                                    → 1V8 (U10)
                                                    → 1V0 (U11)
                                                    → 2V5_REF (U5)
   100 MHz OCXO ┌────┐                ┌──────────────┐
   J5 USB-C ───>│ U7 │────► 100 MHz ──┤U6  CLK BUFFER├──► 4× LVDS
                └────┘                └──────────────┘    (FPGA / MCU / ext)
                          ┌─────────────────┐
   J3 INTERLOCK ─────────►│  STM32H743ZIT6  ├────► SPI ─►┌─────┐
   ×4 (active-high)       │  U1 (LQFP-144)   │            │ U3  │ → DAC ch0..3
                          │                 │            │LTC2668│  HV/coil/
                          │                 │            └─────┘   pump/valve
                          │                 │            ┌─────┐
                          │                 │◄──── SPI ──┤ U4  │ ← BPM analog
                          │                 │            │LTC2208│ (sample 1MS/s)
                          │                 │            └─────┘
                          │                 │
                          │                 │────► SMA J2-tick
                          │  + Wishbone via │────► SMA J2-trigger
                          │    parallel bus │────► SMA J2-gate
                          │    to U2 (FPGA) │
                          │                 │   ┌──────────────┐
                          │  JTAG/SWD ──────┼──►│  J4 SAM 10-pin│  → probe-rs
                          │                 │   └──────────────┘
                          └─────────────────┘
                          ┌────┐
                          │ U2 │ ← FPGA implements timing_ctrl_top.v
                          │XC7A│   (synth post-§A.6 step 2 funding;
                          │35T │    initially shorted with MCU-only path)
                          └────┘
```

## §2 Net list

### §2.1 Power
| Net      | Source              | Sinks                                   | Notes                |
|:---------|:-------------------|:----------------------------------------|:---------------------|
| +12V     | J1 → F1 → TVS1      | U8 (Vin), C_BULK1                       | 12V input           |
| +5V0     | U8 (Vout)           | U9 / U10 / U11 (Vin)                    | 5V intermediate     |
| +3V3     | U9 (Vout)           | U1 / U2 (VCCIO35) / U3 / U4 / U6        | digital + analog 3V3|
| +1V8     | U10 (Vout)          | U2 (VCCAUX) / U1 (VDDA optional)        | FPGA aux            |
| +1V0     | U11 (Vout)          | U2 (VCCINT)                              | FPGA core           |
| +2V5_REF | U5 (Vout)           | U3 (VREF) / U4 (VREF)                    | DAC + ADC reference |
| GND      | J1 GND              | all IC GND pins                          | star-grounded at U1 |

### §2.2 Clock
| Net          | Source              | Sinks                                | Notes                |
|:-------------|:-------------------|:-------------------------------------|:---------------------|
| OCXO_OUT     | U7                  | U6 input                             | 100 MHz, ±1 ppm      |
| CLK_FPGA     | U6 OUT0             | U2 (MRCC pin H4)                      | LVDS, length-matched |
| CLK_MCU      | U6 OUT1             | U1 PH0 (HSE)                         | single-ended fall-back|
| CLK_DAC      | U6 OUT2             | U3 SCK_REF                            | DAC update timing   |
| CLK_AUX      | U6 OUT3             | front-panel test point + J2-mon       | for scope sync      |

### §2.3 Interlock chain
| Net           | Source                | Sinks                | Notes                 |
|:--------------|:---------------------|:---------------------|:----------------------|
| HV_OK         | J3 pin1 → R_PULL→3V3  | U1 PD0 + LED2 cathode| active-high           |
| VACUUM_OK     | J3 pin2 → R_PULL→3V3  | U1 PD1 + LED2 cathode| ditto                 |
| WATER_OK      | J3 pin3 → R_PULL→3V3  | U1 PD2 + LED2 cathode| ditto                 |
| SHUTTER_OK    | J3 pin4 → R_PULL→3V3  | U1 PD3 + LED2 cathode| door-interlock signal |

LED2 anodes via 1 kΩ to +3V3 — LEDs light when interlock is **NOT** OK
(visual fault indicator).

### §2.4 SPI to DAC
| Net    | Source       | Sinks      | Direction      | Speed       |
|:-------|:------------|:----------|:--------------|:------------|
| SPI1_SCK | U1 PA5    | U3 SCK    | MCU → DAC     | 25 MHz      |
| SPI1_MOSI | U1 PA7   | U3 SDI    | MCU → DAC     | 25 MHz      |
| SPI1_MISO | U1 PA6   | U3 SDO    | DAC → MCU (read-back) | 25 MHz |
| DAC_CS_N | U1 PA4    | U3 CS     | MCU → DAC     | LOW = active |
| DAC_LDAC_N | U1 PA3  | U3 LDAC   | MCU → DAC     | sync update |
| DAC_CLR_N | U1 PA2   | U3 CLR    | MCU → DAC     | global clear |

### §2.5 SPI to ADC (BPM)
| Net    | Source       | Sinks      | Direction      | Speed       |
|:-------|:------------|:----------|:--------------|:------------|
| SPI2_SCK | U1 PB13   | U4 SCK    | MCU → ADC     | 50 MHz      |
| SPI2_MOSI | U1 PB15  | U4 SDI    | MCU → ADC     | 50 MHz      |
| SPI2_MISO | U1 PB14  | U4 SDO    | ADC → MCU      | 50 MHz      |
| ADC_CS_N | U1 PB12   | U4 CS     | MCU → ADC     | LOW = active |
| ADC_DRDY_N | U1 PB11 | U4 DRDY   | ADC → MCU IRQ  | falling edge |

### §2.6 Trigger outputs (SMA)
| Net         | Source                   | Sinks               | Termination |
|:------------|:------------------------|:--------------------|:------------|
| TICK_OUT    | U1 PE5 (or U2 IO_L1P)    | J2-tick (SMA)        | 51 Ω → GND  |
| TRIGGER_OUT | U1 PE6 (or U2 IO_L1N)    | J2-trigger (SMA)     | 51 Ω → GND  |
| GATE_OUT    | U1 PE7 (or U2 IO_L2P)    | J2-gate (SMA)        | 51 Ω → GND  |

All three SMA nets length-matched to ±0.5 mm. 50 Ω microstrip on
top layer, GND-referenced to layer 2.

### §2.7 JTAG/SWD
| Net      | J4 pin | Sinks                    | Notes        |
|:---------|:------|:-------------------------|:-------------|
| SWDIO    | 2     | U1 PA13                  | SWD data     |
| SWCLK    | 4     | U1 PA14 + U2 TCK          | SWD clock    |
| SWO      | 6     | U1 PB3                   | RTT trace    |
| nRST     | 10    | U1 NRST + SW1            | manual reset |
| TDI      | 5     | U2 TDI                   | FPGA-only   |
| TMS      | 7     | U2 TMS                   | FPGA-only   |
| GND      | 3,9   | GND                       |              |
| VTREF    | 1     | +3V3                     | I/O voltage  |

### §2.8 USB-C boot/log link (J5)
| Net    | J5 pin     | Sinks         | Notes                    |
|:-------|:-----------|:--------------|:-------------------------|
| USB_DP | A6 / B6    | U1 PA12       | USB device + ROM bootloader |
| USB_DM | A7 / B7    | U1 PA11       | USB device               |
| VBUS   | A4 / B4    | (unused — local 12V powers board) | |
| GND    | A1/A12/B1/B12 | GND        |                          |

## §3 Component placement guidance

| component         | placement                     | orientation         |
|:------------------|:------------------------------|:--------------------|
| U1 (STM32)        | board centre, layer 1         | pin 1 toward J4     |
| U2 (FPGA)         | left of U1, layer 1           | pin 1 toward U1      |
| U3 (DAC)          | right of U1                    | SPI pins toward U1   |
| U4 (ADC)          | far right                      | analog input toward edge |
| U5 (REF)          | between U3 and U4              | shared shielding cage  |
| U6 (clock buf)    | top edge (next to U7)          | output close to U2   |
| U7 (OCXO)         | top edge — heat-isolated      | metal-can shield     |
| U8 (buck)         | bottom edge — separate plane   | inductor next to it  |
| U9-U11 (LDOs)     | between U8 and IC supply pins  | small footprint      |
| C_DEC1/2/3        | within 5 mm of supply pin       | one per pin          |
| J1 (DC barrel)    | top-left corner                | toward edge          |
| J2 ×3 (SMA)       | bottom edge                    | edge-mount, 90°      |
| J3 (interlock)    | left edge                      | front-panel          |
| J4 (JTAG/SWD)     | top-right corner                | front-panel          |
| J5 (USB-C)        | top-centre                      | flush with edge      |

## §4 Stack-up (4-layer, 1.6 mm finished)

| layer | thickness | content                                    |
|:------|:---------|:------------------------------------------|
| L1    | 35 µm     | components + signal (top)                 |
| dielectric | 0.21 mm | FR-4 ε_r 4.5                            |
| L2    | 35 µm     | GND plane (continuous, hatch under U7)    |
| dielectric | 1.04 mm | FR-4 (mid-board core)                    |
| L3    | 35 µm     | power planes (3V3 / 1V0 / 1V8 split)      |
| dielectric | 0.21 mm | FR-4                                     |
| L4    | 35 µm     | components + signal (bottom)              |

50 Ω single-ended impedance: 0.30 mm trace on L1 (or L4) with 0.21 mm
dielectric to L2.  100 Ω LVDS differential: 0.20 mm trace, 0.13 mm
spacing, same dielectric.

## §5 Cross-references

- `pcb/b3_trigger_card/BOM.csv` — full sortable BOM
- `pcb/b3_trigger_card/io_map.md` — STM32 alt-function pin assignment
- `pcb/b3_trigger_card/power_tree.md` — supply analysis
- `pcb/b3_trigger_card/fabrication_notes.md` — assembly + test plan
- `firmware/hdl/timing_ctrl_top.v` — RTL implemented on U2
- `firmware/mcu/src/main.rs` — MCU firmware on U1
- `mini/doc/benchtop_v0_design.md §3 F1+F2` — BOM source
