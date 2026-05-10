# board_v0 — thrust acquisition (HEXA-PROPULSION-FW-01)

> Phase C.5 board-spec doc for **F-AM-4**.  16-channel waveform digitizer
> + Watt-balance ADC + BGO calorimeter trigger + pion ToF gate.  Sub-ns
> trigger fan-out for coincidence-class p̄ annihilation events.

**Status**: paper board v0 (2026-05-08) · **Sim-firmware**: `firmware/sim/thrust_acquisition.hexa` (10/10 PASS) · **PCB**: TBD (Phase D)

---

## §1 Target chip

| Role | Chip | Package | Datasheet | Lead time |
|:-----|:-----|:--------|:----------|:----------|
| FPGA (capture + trigger) | Xilinx XCVU13P-FLGA2577 (Virtex UltraScale+) | FCBGA-2577 | UG573 | 16 wk |
| 12-bit ADC × 16 | TI ADC32RF45 (3 GS/s, dual) × 8 | LFCSP-100 | SBAS847 | 8 wk |
| Watt-balance precision ADC | LTC2387-24 (15 MSPS, 24-bit) | LFCSP-32 | LT4480 | 6 wk |
| BGO calorimeter pre-amp | TI OPA858 (1 GHz GBW) | DSC-10 | OPA858 | stock |
| ToF discriminator | LeCroy MVL407 (mezzanine card) | (CAMAC) | datasheet | 4 wk |
| Trigger fan-out clock buffer | TI LMK01000 (zero-delay clock) | LFCSP-32 | LMK01000 | stock |
| Reference oscillator | shared with atomic_clock board (Cs 10 MHz IN) | (J3) | — | — |
| MCU companion | STM32H743VIT6 (config/telemetry) | LQFP-100 | RM0433 | stock |

## §2 Pinout — XCVU13P (capture-side highlights)

| Bank | Ball | Net | Function | Spec |
|:----:|:----:|:----|:---------|:-----|
| 224 | A1   | ADC0_LANE0_P (GTYE4 SerDes) | IN  (CDR 32 Gbps) | 12-bit ADC ×16 over JESD204C |
| 224 | A2   | ADC0_LANE0_N | IN  | diff |
| ⋮   | (8 ADCs × 4 lanes) | ADCx_LANEy | IN | 32 Gbps each |
| 225 | B5   | ADC_SYSREF_P | OUT | JESD204C SYSREF (alignment) |
| 226 | C9   | TRIGGER_FANOUT[0] | OUT (LVDS) | trigger to ADC0 |
| 226 | C10  | TRIGGER_FANOUT[1..15] | OUT (LVDS) | trigger to ADC1..15 |
| 227 | D14  | WATT_BALANCE_SDO_P (LVDS) | IN  | LTC2387 24-bit data |
| 227 | D15  | WATT_BALANCE_SDO_N | IN  | diff |
| 227 | D16  | WATT_BALANCE_CNV | OUT | start conversion |
| 228 | E20  | BGO_TRIGGER_IN | IN (low-skew LVDS) | BGO discriminator output |
| 228 | E21  | TOF_TRIGGER_IN | IN (low-skew LVDS) | pion ToF discriminator |
| 228 | E22  | COINCIDENCE_OUT | OUT | global trigger to all ADCs |
| 229 | F25  | NIM_IN[0..7] | IN  (LVCMOS33 with diff pad) | NIM/CAMAC trigger inputs |
| 229 | F26..F32 | NIM_IN[1..7] | IN  | per-channel triggers |
| 230 | G30  | DDR4_BANK0_DQ[0..63] | I/O (HSTL 1.2 V) | DDR4 burst capture buffer |
| 231 | H35  | PCIE_GEN4_TX_LANE0 | OUT | PCIe Gen4 ×16 to host |
| 231 | H36  | PCIE_GEN4_TX_LANE1..15 | OUT | data dump (~64 GB/s sustained) |
| 232 | J40  | UART_HOST_TX | OUT | telemetry |

## §3 Connectors

| ID | Type | Use |
|:--:|:----|:----|
| J1 | ATX 24-pin | main power |
| J2 | EPS-12V × 2 (8-pin each) | aux for FPGA core |
| J3 | BNC | 10 MHz Cs reference IN (from atomic_clock board) |
| J4 | LEMO 00B × 16 | ADC input × 16 (BGO + ToF + Watt + 13 spare) |
| J5 | LEMO 00B × 8 | NIM/CAMAC trigger IN |
| J6 | SMA × 2 | global trigger OUT (50 Ω) for scope/storage |
| J7 | PCIe Gen4 ×16 edge | data dump to host (NVMe storage) |
| J8 | RJ45 (1 GbE) | control/telemetry |
| J9 | USB-C | console |
| J10 | 14-pin Xilinx JTAG | Vivado |
| J11 | 10-pin Cortex SWD | STM32 debug |
| J12 | DB-9 (RS-485) | external trigger handshake |
| J13 | OCXO header | optional aux Wenzel ULN-OCXO |

## §4 BOM — catalog SKUs

| # | Item | Vendor | SKU | Qty | $/unit | Lead |
|:-:|:-----|:-------|:----|:---:|-------:|:----:|
| 1 | XCVU13P-1FLGA2577E | Xilinx / Avnet | XCVU13P-1FLGA2577E | 1 | $9,840 | 16 wk |
| 2 | ADC32RF45IRMP | TI / Mouser | 595-ADC32RF45IRMPR | 8 | $620 | 8 wk |
| 3 | LTC2387ILX-24 | ADI | LTC2387ILX-24 | 1 | $52 | 6 wk |
| 4 | OPA858IRWMR | TI / Mouser | 595-OPA858IRWMRDR | 4 | $7.20 | stock |
| 5 | LMK01000ISQX | TI / Mouser | 595-LMK01000ISQX | 1 | $24 | stock |
| 6 | DDR4 (16 Gb / 1.2 V) | Micron | MT40A2G16RB-062E | 8 | $14 | stock |
| 7 | STM32H743VIT6 | ST | 511-STM32H743VIT6 | 1 | $19.20 | stock |
| 8 | TPS6594-Q1 PMIC × 2 | TI | 595-TPS6594QFNRDQQ1 | 2 | $26 | 6 wk |
| 9 | LM5170-Q1 × 4 | TI | 595-LM5170QFTRRQ1 | 4 | $9 | 6 wk |
| 10 | KSZ9031RNX | Microchip | KSZ9031RNX-CT | 1 | $4.80 | stock |
| 11 | FT4232HQ | FTDI | 768-1098-ND | 1 | $7 | stock |
| 12 | LEMO 00B × 24 | LEMO | EPL.00.250.NTN | 24 | $42 | 4 wk |
| 13 | BNC bulkhead | Pomona | 5697 | 1 | $14.20 | stock |
| 14 | SMA edge × 2 | Amphenol | 132134 | 2 | $4.60 | stock |
| 15 | PCIe edge connector | Samtec | PCIE-064-02-F-D-EMS2-A | 1 | $9 | stock |
| 16 | DB-9 right-angle | TE | 5747842-3 | 1 | $1.40 | stock |
| 17 | RJ45 magjack | Bel | SI-50140-F | 1 | $4.20 | stock |
| 18 | 14-layer PCB (300 × 250 mm, controlled-Z + back-drilled vias) | PCBWay HDI | 14L-HDI-back-drill | 3 | $1,400 | 28 d |
| 19 | SMT assembly (BGA × 9) | PCBWay Pro | — | 3 | $4,800 | 35 d |
| 20 | Aluminum chassis (3U EATX) | Hammond / Schroff | 24555-150 | 3 | $280 | stock |
| 21 | Heatsink + fan stack (FPGA) | Wakefield TF-W120 | TF-W120 | 1 | $48 | stock |
| **Total (3-piece run)** |   |   |   |   | **~$28,000 / unit** | **20 wk worst-case** |

## §5 Power budget

| Rail | Sinks | Total |
|:-----|:------|:-----:|
| 12 V (ATX) | board input | 1100 W max |
| 5 V | ADCs analog (8 × 1.4 W = 11 W), STM32, USB, GbE | 14 W |
| 3.3 V | I/O banks, OPA858 × 4, misc digital | 18 W |
| 1.8 V | DDR4 VDDIO | 8 W |
| 1.2 V | DDR4 VDD, LVDS | 12 W |
| 1.0 V (VCCINT) | XCVU13P core (140 W typical, 220 W peak) | 220 W |
| 0.85 V (VCCBRAM) | BRAM rails | 8 W |
| 0.9 V (MGTAVCC) | GT transceivers (×16 lanes JESD + ×16 PCIe) | 12 W |
| 1.2 V (MGTAVTT) | GT transceivers | 12 W |
| ±5 V (analog) | ADC analog supplies, OPA858 | 6 W |
| **Total** |   | **~310 W steady, 400 W peak** |

PSU: 1000 W ATX (Corsair RM1000x) — used at ~30% load with thermal margin.

## §6 Mechanical / cable

- **PCB**: 300 × 250 mm 14-layer HDI controlled-Z (50 Ω LVDS, 100 Ω diff CML), back-drilled vias for high-speed.
- **Enclosure**: Schroff 24555-150 3U EATX rack with active cooling (×3 Noctua NF-A12x25 PWM).
- **Cables**:
  - J4 ADC inputs × 16: LEMO 00B → BNC adapter at lab-side detector array, 1.5 m each
  - J5 NIM/CAMAC: LEMO → NIM bin (CAEN N625), 0.5 m
  - J7 PCIe: PCIe x16 riser → host server (Supermicro 2U with RAID NVMe)
  - J3 Cs ref: BNC daisy-chain from atomic_clock board (passive splitter), 1 m

## §7 Bring-up checklist

| Step | Action | Pass criterion |
|:----:|:------|:---------------|
| 1 | PCB X-ray (BGA × 9) | no opens/shorts |
| 2 | Power sequenced bring-up (rails) | within ±2% (tighter for VCCINT) |
| 3 | Thermal: 30 min idle, FPGA T_j | < 50 °C |
| 4 | Vivado JTAG | XCVU13P + STM32 ID'd |
| 5 | DDR4 cal (8 chips) | Vivado IP wizard PASS |
| 6 | JESD204C link to ADC0 | sync_n stable, lane errors 0 |
| 7 | All 8 ADCs JESD link train | all 16 channels present |
| 8 | ADC noise floor (terminated) | < 1 LSB RMS |
| 9 | LTC2387 24-bit Watt-balance | DC accuracy ± 1 LSB |
| 10 | PCIe Gen4 ×16 link train | 64 GB/s sustained iperf-like |
| 11 | NIM/CAMAC trigger latency | < 100 ns (J5 → J6) |
| 12 | BGO + ToF coincidence | sub-ns timing alignment |
| 13 | Trigger fan-out skew (J6 vs all ADCs) | < 1 ns spread |
| 14 | 1 hr capture stress test | no dropped events at 1 kHz trigger rate |
| 15 | Full sim parity | matches `firmware/sim/thrust_acquisition.hexa` |

## §8 Cross-link

- Sim-firmware: `firmware/sim/thrust_acquisition.hexa`
- Phase A BOM: `factory/doc/benchtop_v0_design.md` (propulsion bench section)
- Phase D HDL: `firmware/hdl/thrust_acq.v`
- Phase D MCU: `firmware/mcu/thrust_bench.rs`
- Falsifier: `.roadmap §A.4 F-AM-4`
- Cross-board dep: 10 MHz Cs ref from atomic_clock board (J3)
