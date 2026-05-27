# B3 trigger card — IO map (STM32H743ZIT6 LQFP-144)

> §A.6.1 step E2.1 — pin-by-pin assignment for the STM32H743ZIT6 MCU
> on the B3 trigger card. Cross-references: `firmware/mcu/src/main.rs`
> RTIC `init` GPIO setup must match this table exactly.

## §1 Power pins

| pin    | name        | net     | notes                                      |
|:------:|:-----------|:--------|:-------------------------------------------|
| 6      | VBAT       | +3V3   | RTC backup; tied to main 3V3 (no battery) |
| 19,32,49,73,93,118,131 | VDD | +3V3 | digital + IO supply (×7)               |
| 22,35,50,74,94,119,132 | VSS | GND  | (×7)                                       |
| 100    | VREF+      | +2V5_REF | ADC reference (LTC6655 OUT)             |
| 21     | VDDA       | +3V3   | ADC analog supply                          |
| 20     | VSSA       | GND     | analog ground                              |
| 144    | VDDLDO_USB | +3V3   | USB internal LDO                           |

## §2 Clock pins

| pin    | name      | net      | notes                                    |
|:------:|:---------|:---------|:----------------------------------------|
| 25     | PH0/OSC_IN | CLK_MCU | from U6 (single-ended fall-back)         |
| 26     | PH1/OSC_OUT | (NC)   | OCXO drives PH0 directly                 |
| 8      | PC14/OSC32_IN | (NC) | LSE not used (no RTC requirement)       |
| 9      | PC15/OSC32_OUT | (NC)|                                          |

## §3 Reset + boot

| pin | name | net          | notes                                  |
|:---:|:-----|:-------------|:---------------------------------------|
| 14  | NRST | nRST → SW1 + J4 pin10 | manual reset + SWD reset      |
| 138 | BOOT0 | GND          | pulled low (no system bootloader)     |

## §4 SWD/JTAG (J4 connector)

| pin | name | net          | direction         |
|:---:|:-----|:-------------|:------------------|
| 109 | PA13/SWDIO | SWDIO → J4#2  | bidirectional      |
| 110 | PA14/SWCLK | SWCLK → J4#4  | input              |
| 89  | PB3/SWO   | SWO → J4#6    | output (RTT trace) |

## §5 Interlock GPIO (PD0..PD3)

| pin | name | net           | direction | notes                       |
|:---:|:-----|:--------------|:---------|:----------------------------|
| 81  | PD0  | HV_OK         | input PU  | active-high; LED2 fault     |
| 82  | PD1  | VACUUM_OK     | input PU  |                             |
| 83  | PD2  | WATER_OK      | input PU  |                             |
| 84  | PD3  | SHUTTER_OK    | input PU  | door-interlock              |

These map to `firmware/mcu/src/interlock.rs` `InterlockOk::from_pins()`
in pin order: hv / vacuum / water / shutter.

## §6 Trigger outputs (SMA fan-out PE5..PE7)

| pin | name | net          | alt fn            | notes                |
|:---:|:-----|:-------------|:------------------|:---------------------|
| 1   | PE5  | TICK_OUT     | TIM15 CH1, AF4    | drives J2-tick SMA   |
| 2   | PE6  | TRIGGER_OUT  | TIM15 CH2, AF4    | drives J2-trigger SMA |
| 3   | PE7  | GATE_OUT     | FMC_D4 (unused)   | direct GPIO drive    |

For higher-precision triggering, U2 (FPGA) takes over these signals
post-§A.6 step 2 funding (FPGA implements timing_ctrl_top.v).

## §7 SPI to DAC (U3 LTC2668-16)

| pin | name | net         | alt fn            | notes               |
|:---:|:-----|:-----------|:------------------|:--------------------|
| 41  | PA4  | DAC_CS_N   | GPIO_OUT          | LOW = active        |
| 42  | PA5  | SPI1_SCK   | SPI1_SCK, AF5     | up to 25 MHz        |
| 43  | PA6  | SPI1_MISO  | SPI1_MISO, AF5    | DAC read-back       |
| 44  | PA7  | SPI1_MOSI  | SPI1_MOSI, AF5    |                     |
| 39  | PA2  | DAC_CLR_N  | GPIO_OUT          | global clear        |
| 40  | PA3  | DAC_LDAC_N | GPIO_OUT          | sync update         |

## §8 SPI to ADC (U4 LTC2208)

| pin | name | net         | alt fn            | notes                |
|:---:|:-----|:-----------|:------------------|:---------------------|
| 67  | PB12 | ADC_CS_N   | GPIO_OUT          | LOW = active         |
| 68  | PB13 | SPI2_SCK   | SPI2_SCK, AF5     | up to 50 MHz         |
| 69  | PB14 | SPI2_MISO  | SPI2_MISO, AF5    |                      |
| 70  | PB15 | SPI2_MOSI  | SPI2_MOSI, AF5    |                      |
| 66  | PB11 | ADC_DRDY_N | EXTI11 → IRQ       | data-ready interrupt |

## §9 USB device (J5 USB-C)

| pin | name | net    | alt fn       | notes                |
|:---:|:-----|:-------|:-------------|:---------------------|
| 102 | PA11 | USB_DM | OTG_FS_DM    | full-speed USB        |
| 103 | PA12 | USB_DP | OTG_FS_DP    | for boot ROM + RTT/log |
| 104 | PA10 | (NC)   |              |                       |

## §10 Power-good indicator (LED1)

| pin | name | net   | notes                                |
|:---:|:-----|:------|:-------------------------------------|
| 5   | PE3  | LED_PG | drives green LED1; firmware idle blink |

`firmware/mcu/src/main.rs` `idle()` task toggles PE3 at ~1 Hz to
indicate firmware-alive.

## §11 Reserved / future-expansion pins

PI0..PI11 + PG10..PG15: routed to mezzanine connector (JM1, future
revision) for additional ADC channels (diamond detector / EOS).
Currently NC.

## §12 Cross-references

- STM32H743 datasheet RM0433 §1.5 (pinout)
- `firmware/mcu/src/main.rs` — `init()` function GPIO setup
- `pcb/b3_trigger_card/schematic_spec.md` — full netlist
