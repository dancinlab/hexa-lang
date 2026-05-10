# HEXA-CHIP-FW-02 — Power chain detail

> Phase E iter 2 detailed power chain spec for the NPU dispatcher board.
> Falsifier: F-CHIP-2. Builds on `schematic_paper.md §2` and
> `firmware/doc/board_v0_spec.md §2.3`. Heavier than FW-01: PCIe Gen5 +
> Zynq UltraScale+ + DDR4 SODIMM all on the same board.

## 1. Rail tree (current-budgeted)

```
  12 V ATX-style (or USB-C 20 V PD via buck → 12 V)
        │  ≤ 1.0 A typ (12 W) / 1.5 A peak (18 W)
        ▼
  ┌─────────────────────────────────────────────────────────────────────┐
  │ U1: TI LMZ31707  12V→3.3V  µModule                                  │
  │   • V_in: 6–17 V        • I_out (max): 7 A                          │
  │   • η ≈ 90 % @ 200 mA   • f_sw: 480 kHz (selectable)                │
  │   • Integrated inductor + control loop; minimal external BOM        │
  │   • Decoup: C_in 47 µF + 22 µF + 100 nF, C_out 47 µF + 100 nF       │
  └─────────────────────────────────────────────────────────────────────┘
        │  +3V3   typ 200 mA / peak 500 mA  (MCU + Zynq aux + PEX8732 aux)
        ▼
  ┌─────────────────────────────────────────────────────────────────────┐
  │ U2: TI LMZ31506  12V→1.8V  µModule  (DDR4 + Zynq HP I/O bank)       │
  │   • V_in: 6–17 V        • I_out (max): 6 A                          │
  │   • η ≈ 88 % @ 800 mA   • f_sw: 480 kHz                             │
  │   • Sense pin Kelvin to DDR4 socket VDDIO pin                       │
  │   • Decoup: C_in 47 µF, C_out 100 µF + 22 µF + 4×100 nF             │
  └─────────────────────────────────────────────────────────────────────┘
        │  +1V8   typ 300 mA / peak 800 mA  (NPU IP I/O + DDR4 VDDQ)
        ▼
  ┌─────────────────────────────────────────────────────────────────────┐
  │ U3: ADI/LT LTM4638  12V→0.85V  µModule  (Zynq core / NPU IP core)   │
  │   • V_in: 4.5–20 V      • I_out (max): 15 A (sized for 3 A peak)    │
  │   • η ≈ 86 % @ 1 A      • f_sw: 1 MHz (low ripple Zynq core)        │
  │   • Decoup: C_in 47 µF, C_out 220 µF POSCAP + 8×22 µF + 16×100 nF   │
  │   • Remote sense: VOSNS+/VOSNS- Kelvin to Zynq VCCINT sense ball    │
  └─────────────────────────────────────────────────────────────────────┘
        │  +0V85  typ 1.0 A / peak 3.0 A  (Zynq US+ VCCINT / VCCBRAM)
        ▼
  ┌─────────────────────────────────────────────────────────────────────┐
  │ U4: ADI/LT LTM4624  12V→0.40V  µModule  (HBM4-emu I/O, HBM3-class)  │
  │   • V_in: 4–14 V        • I_out (max): 4 A                          │
  │   • η ≈ 75 % @ 500 mA (low V_out → η penalty)                       │
  │   • f_sw: 1 MHz                                                     │
  │   • Decoup: C_in 22 µF, C_out 100 µF + 4×22 µF + 8×100 nF           │
  └─────────────────────────────────────────────────────────────────────┘
        │  +0V40  typ 500 mA / peak 1.5 A  (HBM4-emu I/O via DDR4 SODIMM)
```

PMIC overlay: **TI TPS65094** governs all four µModules' EN pins via
its `SLOT_<n>_VOUT_EN` outputs. SLOT mapping per Samsung NPU IP spec:

| SLOT | rail   | t_delay (after SLOT_n-1 PG = 1) | PG threshold |
|:----:|:-------|:--------------------------------|:-------------|
| 1    | +3V3   | 0 ms                            | 90 % × 3.30 V = 2.97 V |
| 2    | +1V8   | 5 ms                            | 90 % × 1.80 V = 1.62 V |
| 3    | +0V85  | 10 ms                           | 90 % × 0.85 V = 0.77 V |
| 4    | +0V40  | 20 ms                           | 90 % × 0.40 V = 0.36 V |

Total board input load:
- Typ:  12 V × 720 mA ≈ **8.6 W**
- Peak: 12 V × 1.0 A  ≈ **12 W** (Zynq stress + PCIe Gen5 link active + DDR4 read burst)
- PSU sizing: 12 V / 2 A (24 W) brick — 2× headroom.

## 2. Decoupling network (per IC)

| IC                  | rail    | bulk             | bypass count                                  |
|:--------------------|:--------|:-----------------|:----------------------------------------------|
| Zynq XCZU7EV (PL)   | 0.85 V  | 220 µF POSCAP    | 100 nF × ≈ 80 + 1 nF × ≈ 80 (per VCCINT ball) |
| Zynq XCZU7EV (PS)   | 0.85 V  | (shared bulk)    | 100 nF × ≈ 30 (PS_VCC ball)                   |
| Zynq XCZU7EV I/O    | 1.8 V   | 22 µF X7R        | 100 nF × ≈ 50 (HP/HD I/O banks)               |
| Zynq XCZU7EV aux    | 3.3 V   | 10 µF X7R        | 100 nF × ≈ 12 (VCCAUX_IO + MIO)               |
| DDR4 SODIMM         | 1.8 V   | 100 µF + 22 µF   | 100 nF × ≈ 16 (per VDDQ pin)                  |
| DDR4 SODIMM         | 0.4 V   | (VTT, derived)   | 22 µF × 4 (VTT termination)                   |
| STM32H723           | 3.3 V   | 4.7 µF + 4.7 µF  | 100 nF × ≈ 8 (VDD_MCU + VDDA)                 |
| PEX8732 (PCIe Gen5) | 1.0 V*  | 47 µF            | 100 nF × ≈ 12                                 |
| PEX8732             | 1.8 V   | 22 µF            | 100 nF × 4                                    |
| PEX8732             | 3.3 V   | 10 µF            | 100 nF × 4                                    |
| **Total decoups**   |         |                  | **~280** (ties to schematic_paper.md §5 "~400") |

\* PEX8732 1.0 V derived from a tiny on-board LDO off 1.8 V (out of scope here).

## 3. Power-on sequencer (TPS65094 PMIC)

Order is **mandatory** per Samsung Exynos / NPU IP spec — VCCINT (0.85 V) must rise after I/O (1.8 V) is stable, and HBM-class I/O (0.40 V) is the very last to enable, otherwise DDR I/O cells can latch up.

```
   t   ┌─ +3V3  PG = 1  (TPS65094 SLOT 1 → SLOT 2 enable)
       │  ┌─ +1V8  PG = 1  (SLOT 2 → SLOT 3)
       │  │  ┌─ +0V85 PG = 1  (SLOT 3 → SLOT 4)
       │  │  │  ┌─ +0V40 PG = 1  (PMIC asserts PG_ALL → nRST_NPU released)
   0───┴──┴──┴──┴────────────────────────────────────────────────
       0  5  15 35 ms

   Power-down (graceful):
   reverse order: +0V40 → +0V85 → +1V8 → +3V3, each within 1 ms.
```

If PG_ALL fails to assert within 100 ms of EN_PMIC, the host MCU
(STM32H723) reads PMIC fault registers via I2C and logs which SLOT failed.

## 4. Estimated rail noise / Z_target (paper-tier)

| rail   | regulator     | est. ripple   | Z_target (1 kHz–200 MHz) | margin to spec     |
|:-------|:--------------|:--------------|:-------------------------|:-------------------|
| +3V3   | LMZ31707      | ~15 mV (0.5%) | < 50 mΩ                  | ~3× (Zynq aux)     |
| +1V8   | LMZ31506      | ~10 mV (0.6%) | < 25 mΩ                  | ~2× (DDR4 VDDQ)    |
| +0V85  | LTM4638       | ~5 mV (0.6%)  | < 10 mΩ (per Xilinx UG583)| ~1.5× — TIGHT     |
| +0V40  | LTM4624       | ~3 mV (0.75%) | < 15 mΩ                  | ~2× (HBM3-class)   |

**Critical:** +0V85 Zynq core is the tightest budget. Decoupling network
(220 µF POSCAP + 8×22 µF + 16×100 nF + 1 nF/ball) is sized to meet
~10 mΩ flat from 1 kHz to 200 MHz; HyperLynx PI sweep deferred to G2.

## 5. Failure modes (FMEA-lite)

| failure                                | detection                            | response                              |
|:---------------------------------------|:-------------------------------------|:--------------------------------------|
| 12 V brick over-current trip           | board black; MCU log lost            | replug; LED indicator on PSU          |
| LMZ31707 thermal shutdown              | +3V3 drops; PMIC PG_3V3 = 0          | TPS65094 cascades reset, holds nRST   |
| LMZ31506 (1V8) UV                      | DDR4 link unrecoverable; AXI hang    | MCU watchdog fires → board reset      |
| LTM4638 (0V85) over-current (> 4 A)    | µModule auto-foldback                | Zynq core resets; nRST cascade        |
| LTM4624 (0V40) UV during HBM4 emu init | DDR4 controller fails training       | host MCU re-issues init after PMIC OK |
| TPS65094 PMIC I2C dead                 | host can't read fault regs           | hard-reset via PMIC nRESET pin        |
| Sequence violation (slot 2 enables before slot 1 PG) | PG_ALL never asserts        | timeout 100 ms → MCU logs error       |
| PCIe Gen5 link train fail at 1V0       | PEX8732 LTSSM stuck Polling          | renegotiate at Gen4 (downgrade fallback) |

## 6. PI verification path (Phase E iter ≥ 3)

- [ ] HyperLynx PI Z_target sweep across +0V85 plane (target: ≤ 10 mΩ flat)
- [ ] HyperLynx SI: PCIe Gen5 lanes — eye height ≥ 30 mV at 32 GT/s
- [ ] HyperLynx SI: DDR4 SODIMM byte lane — write/read margin ≥ 0.4 UI
- [ ] HBM4-emu (DDR4) link training at 0.40 V VDDQ → measure I/O eye
- [ ] Stress: Zynq core full clk gating off, DSP/BRAM 100% util, monitor 0V85 sag
- [ ] PMIC fault injection: pull SLOT_n_PG low → verify next slot does NOT enable
- [ ] Power-cycle 1000× → confirm sequencer always meets 35 ms total ramp

(Deferred to physical-procurement gate G5; HyperLynx licence required for G2.)

## 7. Cross-references

- Block schematic: `schematic_paper.md`
- KiCad project (skeleton): `fw02_npu.kicad_pro`
- Power budget: `firmware/doc/board_v0_spec.md §2.3`
- Cross-board PI: `firmware/board/POWER_INTEGRITY.md`
- BOM rows: `firmware/board/bom_master.csv` (board=fw02_npu, group=power)
