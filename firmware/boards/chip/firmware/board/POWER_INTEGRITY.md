# Power Integrity (cross-board summary)

> Phase E iter 2 cross-board PI summary across all 3 HEXA-CHIP firmware
> boards. Roll-up of `fw0{1,2,3}/power_chain.md`. **Paper-tier**:
> all numbers are budgeted from the schematic, not measured.
>
> Status: paper only (2026-05-08, Phase E iter 2). Roadmap: `.roadmap.hexa_chip §A.6`.

## 1. Aggregate power budget (single-set run)

| board           | input rail | typ load | peak load | PSU recommended       |
|:----------------|:-----------|:---------|:----------|:----------------------|
| HEXA-CHIP-FW-01 | 24 V DC    | 5.5 W    | 8.4 W     | 24 V / 1.5 A (36 W)   |
| HEXA-CHIP-FW-02 | 12 V DC    | 8.6 W    | 12.0 W    | 12 V / 2.0 A (24 W)   |
| HEXA-CHIP-FW-03 | 24 V DC    | 25.0 W   | 44.0 W    | 24 V / 2.5 A (60 W)   |
| **3-board lab rack** | mixed   | **39 W** | **64 W**  | 120 W bench supply    |

A 1U lab rack (e.g. Rigol DP832 triple-output 195 W) covers the full
3-board run; FW-03 is the sizing constraint.

## 2. Per-board regulator stack

| board   | input | rails (V_set)               | regulator types                          | sequencer       |
|:--------|:------|:----------------------------|:-----------------------------------------|:----------------|
| FW-01   | 24 V  | 5.0 / 3.3 / 1.8 / 1.2       | LMR16030 buck → TPS62082 buck → LM317 LDO → LP3878 LDO | TPS3823 supervisor |
| FW-02   | 12 V  | 3.3 / 1.8 / 0.85 / 0.40     | 4× TI µModule (LMZ31707, LMZ31506, LTM4638, LTM4624) | TPS65094 PMIC   |
| FW-03   | 24 V  | 1.10 / 0.85 / 0.40 / 1.80 / 3.30 | Renesas RAA489204 multi-output PMU  | RAA489204 internal |

FW-03 is the only board with **5 simultaneous output rails**, all from
a single multi-channel PMU; FW-02 uses 4 µModules + a dedicated PMIC
supervisor; FW-01 is fully discrete.

## 3. Critical Z_target rails

The tightest impedance budgets across all 3 boards:

| board | rail   | role                  | Z_target (target band) | margin to spec |
|:------|:-------|:----------------------|:------------------------|:---------------|
| FW-03 | +1V10  | HBM4 DRAM core        | < 5 mΩ DC–500 MHz       | 1.4×  TIGHT    |
| FW-02 | +0V85  | Zynq US+ VCCINT       | < 10 mΩ 1 kHz–200 MHz   | 1.5×  TIGHT    |
| FW-03 | +0V40  | HBM4 DDR I/O          | < 8 mΩ DC–500 MHz       | 1.5×           |
| FW-02 | +1V8   | DDR4 SODIMM VDDQ      | < 25 mΩ 1 kHz–200 MHz   | 2×             |
| FW-03 | +0V85  | HBM LBD logic         | < 12 mΩ DC–500 MHz      | 2×             |
| FW-01 | +1V2   | ECP5 VCCINT           | < 50 mΩ 1 kHz–100 MHz   | 3×             |

**Phase E iter ≥ 3 priority:** HyperLynx PI sweep on FW-03 +1V10 plane
(highest power density, tightest margin). HBM4 spec compliance gates the
entire FW-03 board.

## 4. Decoupling network rollup

| board | bulk caps (≥ 10 µF) | mid (1–10 µF) | bypass (≤ 100 nF) | total |
|:------|:--------------------|:--------------|:-------------------|:------|
| FW-01 | ~6                  | ~10           | ~99                | ~115  |
| FW-02 | ~12                 | ~30           | ~240               | ~280  |
| FW-03 | ~10                 | ~50           | ~560               | ~620  |
| **Total** | ~28              | ~90           | ~899               | **~1015** decoups across the 3 boards |

Pricing impact: 1015 × $0.05 average = **~$50** of bypass + 28 × $1.20
average bulk = **~$33**. Negligible vs PMU/regulator BOM.

## 5. Common sequencing principles (HBM-class + FPGA)

All 3 boards share these power-up rules (encoded in their respective sequencers):

1. **I/O rails before core rails** — VCCAUX → VCCIO → VCCINT
   (FPGA spec rule; HBM4 reverses for DRAM core, which is independent).
2. **PG-gated cascade** — each rail's enable depends on the prior rail's
   PG_n (Power-Good) signal asserting + a programmable delay (≥ 5 ms).
3. **Monotonic ramp** — no rail may oscillate, dip, or overshoot during
   ramp; sequencer holds nRST until the slowest rail is at 90 % nominal.
4. **Brownout cascade** — any rail dropping below 85 % for > 50 µs →
   sequencer re-asserts nRST and logs which rail tripped.
5. **CATTRIP override** (FW-03 only) — thermal latch overrides everything,
   collapsing all rails within 100 µs of T_max ≥ 105 °C.
6. **Graceful power-down** — reverse of power-up order, each within 1 ms.

## 6. Cross-board lessons

- **FW-03 is HBM4-bound:** sequencer order, decoup density, and Z_target
  are dictated by HBM4 spec, not by the host MCU/FPGA. Phase E iter ≥ 3
  must do HyperLynx PI sweep on FW-03 first.
- **FW-02 PCIe Gen5 + DDR4** force tight PI on +0V85 (Zynq core) and
  SI on PCIe lanes (eye height ≥ 30 mV at 32 GT/s). HyperLynx licence
  is the gating purchase for G2.
- **FW-01 is the easy one:** all rails > 1 V, no high-speed serial,
  PSRR is the only critical metric (LP3878 covers it). Yosys/nextpnr
  open path means no Vivado licence needed for FW-01.
- **Procurement choke-points:** FW-03 RAA489204 (Renesas, 12-week lead)
  and FW-02 LTM4638 (ADI, 8-12 weeks) dominate the timeline. FW-01
  parts are all stocked at Digi-Key/Mouser.

## 7. Phase E gates affected by PI

| gate | PI-related deliverable                              | board priority   | status   |
|:----:|:---------------------------------------------------|:-----------------|:---------|
| G1   | KiCad schematic with netclasses applied             | all 3            | started  |
| G2   | HyperLynx PI / SI sweeps (target Z + eye height)    | FW-03 → FW-02    | input-deck spec'd (`HYPERLYNX_PI_DECK.md` — Phase E iter 4) |
| G3   | Gerber DRC clean + Stack-up sign-off                | all 3            | pending  |
| G4   | Final PMIC/regulator BOM lock + lifecycle check     | FW-03 (PMU lead) | pending  |
| G5   | Physical board: PI bench measurement (VNA + scope)  | all 3            | pending  |

G2 (HyperLynx) is the largest licence-and-engineer cost ahead;
estimated $5–8 K licence + 2 engineer-weeks per board.

## 8. Cross-references

- Per-board detail: `fw01_corner/power_chain.md`, `fw02_npu/power_chain.md`, `fw03_hbm/power_chain.md`
- Block schematics: `fw0{1,2,3}/schematic_paper.md`
- Pinmap + budget table: `firmware/doc/board_v0_spec.md`
- BOM aggregate: `bom_master.csv`
- HyperLynx PI/SI input deck: `HYPERLYNX_PI_DECK.md` (Phase E iter 4)
- Roadmap: `.roadmap.hexa_chip §A.6`
