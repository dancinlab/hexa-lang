# Pinout Summary — quick reference

## STM32F407VGT6 (synthesis chamber MCU + calorimetry MCU)

LQFP-100, 168 MHz, 1 MiB FLASH, 192 KiB SRAM (112 main + 64 CCM + 16 backup).

### chamber_drv pinout (firmware/mcu/chamber_drv.rs)

```
       ┌───────────────────────────────────────────────────────────────┐
       │                                                                │
  PA0 ─┤ PT100 #1     furnace temperature (4-wire RTD bridge)           │
  PA1 ─┤ PT100 #2     furnace temperature (redundant RTD)               │
  PA2 ─┤ UART_TX      host telemetry, 1 Mbaud 8N1                       │
  PA3 ─┤ UART_RX      host commands                                     │
  PA4 ─┤ DAC1 OUT     furnace power 0..1.0 → 0..10 V via op-amp         │
  PA5 ─┤ DAC2 OUT     pressure command 0..1.0 → high-P PSU CV/CC        │
  PA6 ─┤ ADC IN1      load cell strain bridge (high-P cell)             │
  PA7 ─┤ ADC IN2      O₂ sensor 0..0.5 ppm range                        │
  PA8 ─┤ EXTI IN      H₂S monitor alarm contact (open-coll)             │
  PA9 ─┤ EXTI IN      Pb extractor flow OK contact                      │
  PA10─┤ GPIO OUT     LED green (normal)                                │
  PA11─┤ GPIO OUT     LED red (fault/abort)                             │
  PB0/1┤ I²C1         EBSD camera bus                                   │
  PB2 ─┤ EXTI IN      emergency stop (NC switch, pull-up)               │
  PB6/7┤ SPI1         XRD detector serial                               │
  PD8 ─┤ TIM4 PWM     furnace SSR drive (10 Hz duty cycle)              │
  PD9 ─┤ TIM4 PWM     high-P pump motor drive                           │
  PE0..7  GPIO debug  logic analyzer pins (dev only)                    │
  PA13┤ SWDIO         debug                                             │
  PA14┤ SWCLK         debug                                             │
       │                                                                │
       └───────────────────────────────────────────────────────────────┘
```

### calorimetry_drv pinout (firmware/mcu/calorimetry_drv.rs)

```
  PA0 ─ Cernox sensor differential ADC in (4-wire, low-noise)
  PA1 ─ Pt-RTD reference channel
  PA2 ─ UART_TX (host link, 1 Mbaud)
  PA3 ─ UART_RX
  PB6/7 SPI1 → AD5660 DAC SCLK + SDI + SYNC (heat-pulse driver)
  PB13/14/15 SPI2 → LTC2400 ADC CS + SCLK + SDO (24-bit ΣΔ)
  PA8 ─ LHe level monitor (analog 0..5 V from Lake Shore 218)
  PA9 ─ μ-metal field probe (residual nT monitor)
  PA10─ LED green / red (status)
  PA13/14  SWDIO/SWCLK (debug)
```

## XC7A35T-1CSG324C (Quench-detect + Calorimetry FPGAs)

Artix-7, 33,280 LUT6, 41,600 FFs, 50 BRAM 36 K, 5 CMTs, 90 DSP slices.

### Quench-detect (firmware/hdl/quench_detect.v + constraints.xdc)

Target board: **Digilent Arty A7-35T** ($129 commodity dev board).

```
  100 MHz osc → E3
  SW0 reset   → A8
  PMOD JA  (REBCO ADC LVDS) → 16 pins F4..J8
  PMOD JB  (Bitter ADC)     → 16 pins (mirror layout)
  PMOD JC  (Hall + Cernox)  → 32 pins
  PMOD JD  (IGBT gate out)  → 1 pin D4 + reset back
  LED  LD0..LD3 → channel_trip[3:0] H5/J5/T9/T10
  LED  LD7      → confirm_cernox F6
  USB-UART (FT2232H onboard) → debug console
```

### Calorimetry-DAQ (firmware/hdl/calorimetry_daq.v)

Same Arty A7-35T board, separate bitstream.

```
  50 MHz derived from 100 MHz/2 (MMCM)
  PMOD JA → AD5660 SPI: SCLK + SDI + SYNC
  PMOD JB → LTC2400 SPI: CS + SCLK + SDO
  USB-UART → 1 Mbaud sample stream to host
  LED LD7 → pulse_active_o
```

## Datasheet quick links (vendor-published, accessible offline via PDF)

| IC | Datasheet doc | Critical params |
|:---|:--------------|:----------------|
| STM32F407VGT6 | RM0090, DS8626 | 168 MHz, 1 MB FLASH, FPU |
| XC7A35T | DS181 | 33k LUT, 50 BRAM, 6.5 GHz max GTX |
| AD5660 | data sheet rev D | 16-bit DAC, 1.25 µs settle, ±2 LSB INL |
| LTC2400 | LTC2400 ds | 24-bit ΣΔ, 7.5 Hz, 4 ppm INL, autocal |
| LTC2378-20 | LTC2378-20 ds | 20-bit, 1 MS/s, ±5 V differential |
| AD8429 | AD8429 ds | low-noise instrumentation amp, 1 nV/√Hz |
| ISO224 | ISO224 ds | reinforced isolation, ±125 V VIOWM |
| TLP358 | TLP358 ds | gate driver opto, 250 ns prop, 30 kV/µs CMR |
| FF1400R12IP4 | Infineon ds | 1.4 kA / 1.2 kV IGBT module |
| Group3 LPT-141 | LPT user manual | 0..50 T Hall probe, 1 ppm linearity |
| Cernox CX-1080-CU | Lake Shore tech note | 1.5..325 K, 1 mK below 5 K |

## Spec traceability

Every pin / IC choice traces to a Stage A doc requirement or Phase C/D
test case:

| Pin / IC | Spec req | Test |
|:--------|:--------|:-----|
| PA4 furnace DAC | doc/synthesis_bench_v0.md §3 BOM #2 | firmware/sim/synthesis_ctrl.hexa furnace ramp |
| FPGA channel_trip[3:0] | doc/48t_rebco_coil_v0.md §4 quench-detect | firmware/sim/quench_logic.hexa 1-of-4 voting |
| AD5660 + LTC2400 | doc/calorimetry_rig_v0.md §3 BOM #4, 1 | firmware/sim/calorimetry_ctrl.hexa (Phase D+ extension) |
| Group3 Hall + Cernox | doc/48t_rebco_coil_v0.md §3 BOM #9, 11 | tb_quench_detect.v 12/12 PASS |
