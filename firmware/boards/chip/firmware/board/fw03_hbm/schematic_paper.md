# HEXA-CHIP-FW-03 — Paper schematic (block level)

> ASCII block-level schematic for the HBM thermal controller board.
> Falsifier: F-CHIP-3. Phase E iter 1, paper-tier only.
> Sources: `firmware/doc/board_v0_spec.md §3`, `firmware/hdl/hbm_thermal_top.v`,
> `firmware/mcu/thermal_coord.hexa`.

## 1. Block-level diagram

```
  +-------------------+        +----------------------------+
  |   USB-C (host)    |<------>|  STM32H7 (host MCU)        |
  |  data + 5V aux    |        |  Cortex-M7 @ 480 MHz       |
  +-------------------+        |  Thermal coordinator       |
                               |  - thermal_coord.hexa      |
                               +----------------------------+
                                  |  I2C/SMBus (SDA/SCL)
                                  |  → ADS1115 + HBM TEMP reg
                                  v
                               +----------------------------+
                               |  TI ADS1115 16-bit ADC     |
                               |  4-ch, I2C @ 400 kHz       |
                               |  (per-layer T sensor mux)  |
                               +----------------------------+
                                  |  THERMAL_SENSE_BUS[15:0]
                                  v
                          +---------------------------------+
                          |  SK Hynix HBM4 16-Hi 48 GB      |
                          |  (vendor-NDA sample part)       |
                          |  2048-bit DQ wide bus           |
                          |  16 layers × thermal sensor     |
                          +---------------------------------+
                                  |  (atop)
                                  v
                          +---------------------------------+
                          |  Si interposer (CoWoS-class)    |
                          |  custom Samsung Foundry partner |
                          |  routes HBM4 PHY ↔ host SoC     |
                          +---------------------------------+
                                  |  HBM4_DQ[2047:0] etc.
                                  v
                          +---------------------------------+
                          |  DDR4 SODIMM 16 GB              |
                          |  HBM emulator (Phase D-1 only)  |
                          |  Lattice ECP5 wide-bus bridge   |
                          +---------------------------------+

                          +---------------------------------+
                          |  Renesas RAA489204 PMU          |
                          |  multi-rail DVFS controller     |
                          |  drives 1.10/0.85/0.40/1.80V    |
                          +---------------------------------+
                                  |  DVFS_CTRL[7:0]
                                  +-> from STM32H7

  CATTRIP latch: open-drain comparator (TLV3702) on T_max line, latches
                 TRIP_LATCH high when any T_layer > 105°C.

  +-------------------+    +-----------+      +-----------+
  | RJ45 100Base-TX   |    | JTAG 20p  |      | SWD 4p    |
  | log Ethernet      |    | bnd-scan  |      | SWD debug |
  +-------------------+    +-----------+      +-----------+
```

## 2. Power rail tree

```
  24V DC barrel jack (or 4-pin Molex from PSU)
        |
        v
  [Renesas RAA489204 PMU]  (multi-output, sequencer-aware)
        ├── 3.30 V ──>  STM32H7, ADS1115, ECP5 aux
        ├── 1.80 V ──>  HBM4 DRAM peripheral, ECP5 I/O
        ├── 1.10 V ──>  HBM4 DRAM core (HBM4 spec)
        ├── 0.85 V ──>  LBD logic / interposer bridge
        └── 0.40 V ──>  HBM4 DDR I/O (HBM3-class compat)

  Sequencer order (per HBM4 spec):
    1.10V → 0.85V → 0.40V → 1.80V → 3.30V (last)
  CATTRIP override: any TRIP_LATCH high → instant 0V on all rails.
```

## 3. Net list (paper)

| net                | width | from              | to                       | electrical               |
|:-------------------|:------|:------------------|:-------------------------|:-------------------------|
| THERMAL_SENSE_BUS  | 16    | HBM4 layer mux    | ADS1115 inputs           | 0–3.3V analog, mux'd     |
| DVFS_CTRL          | 8     | STM32H7           | RAA489204 PMU            | 3.3V LVCMOS, 1 MHz       |
| CATTRIP / TRIP_LATCH | 1   | TLV3702 latch     | host SoC + PMU shutdown  | 3.3V LVCMOS, async       |
| I2C_SMBUS          | 2     | STM32H7           | host SoC + ADS1115       | 3.3V open-drain, 400 kHz |
| HBM4_DQ            | 2048  | HBM4 PHY          | interposer → host        | HBM4 PHY (1.1V)          |
| HBM4_DQS           | 32    | HBM4 PHY          | interposer → host        | HBM4 PHY diff strobe     |
| HBM4_RESET_n       | 1     | RAA489204 seq     | HBM4 stack               | 3.3V LVCMOS              |
| HBM4_CK            | 16    | clock tree        | HBM4 stack               | HBM4 PHY diff clk        |
| RESET_n            | 1     | RAA489204 seq     | all                      | 3.3V LVCMOS              |
| JTAG_*             | 4     | JTAG 20p          | ECP5 + STM32H7           | TCK/TMS/TDI/TDO          |
| SWD_*              | 2     | SWD 4p            | STM32H7 SWD              | SWDIO/SWCLK              |

## 4. Connector table

| connector | function                  | pin count | std        | notes                          |
|:----------|:--------------------------|:----------|:-----------|:-------------------------------|
| J1 USB-C  | host link + power-aux     | 24        | USB 3.2    | 5V@3A aux                      |
| J2 RJ45   | log Ethernet              | 8         | 100Base-TX | streams `thermal_coord` log    |
| J3 JTAG   | debug + boundary scan     | 20        | ARM JTAG   | covers ECP5 + MCU              |
| J4 SWD    | Cortex-M7 debug           | 4         | SWD        | STM32H7 only                   |
| J5 PWR    | 24V 4-pin Molex           | 4         | Molex      | main power input               |
| J6 SODIMM | DDR4 SODIMM 260-pin       | 260       | JEDEC      | 16 GB HBM emul                 |
| J7 SMBUS  | SMBus to host SoC         | 4         | 2x2 0.1"   | external HBM_TEMP register read|
| J8 TRIP   | CATTRIP fan-out           | 2         | 0.1"       | external thermal trip relay    |

## 5. Component count summary

| category                 | count | notes                          |
|:-------------------------|:------|:-------------------------------|
| Active ICs               | 5     | HBM4, STM32H7, ADS1115, ECP5, RAA489204 |
| Si interposer            | 1     | custom (foundry MOU)           |
| Memory modules           | 1     | DDR4 SODIMM 16 GB              |
| Power rails (PMU output) | 5     | 1.10/0.85/0.40/1.80/3.30 V     |
| Connectors               | 8     | USB-C, RJ45, JTAG, SWD, PWR, SODIMM, SMBUS, TRIP |
| Passives (R/C/L est.)    | ~600  | HBM4 needs >400 decouplers     |
| Crystals / oscillators   | 3     | 50 MHz main, 32.768 kHz RTC, HBM4 PHY ref |

## 6. PCB footprint estimate

- **Target:** 200 × 160 mm, 10-layer HDI, 1.6 mm thickness.
- **Stack-up:** Sig / GND / Sig / PWR / GND / GND / PWR / Sig / GND / Sig.
- **Impedance:** 50 Ω SE, 100 Ω diff (USB), HBM4 PHY 40 Ω SE per spec.
- **Length matching:** HBM4 byte-lane ± 5 mil; CK/DQS ± 2 mil.
- **Buried/blind vias:** required for Si interposer fan-out.
- **Test points:** 36 (5 power rails × 4 + sense + I2C + JTAG).
- **Mounting:** 6× M3, plus 4× M2 under HBM4 stack for thermal interposer.

## 7. Cross-references

- Pinmap (full): `firmware/doc/board_v0_spec.md §3.1`.
- Power budget: `firmware/doc/board_v0_spec.md §3.3`.
- Bringup: `firmware/doc/board_v0_spec.md §3.4`.
- Verilog top: `firmware/hdl/hbm_thermal_top.v`.
- MCU host: `firmware/mcu/thermal_coord.hexa`.
- BOM aggregate: `firmware/board/bom_master.csv` (rows board=fw03_hbm).
