# HEXA-CHIP-FW-01 — Power chain detail

> Phase E iter 2 detailed power chain spec for the process-corner monitor
> board. Builds on the rail tree in `schematic_paper.md §2` and the
> per-rail current budget in `firmware/doc/board_v0_spec.md §1.3`.
> **Paper-tier** — no SPICE simulation, no measured load lines.
> Falsifier: F-CHIP-1.

## 1. Rail tree (current-budgeted)

```
  24 V DC barrel jack
        │  ≤ 1.0 A typ / 1.5 A peak  (24 V × 1.5 A = 36 W headroom; 5 W typ load)
        ▼
  ┌─────────────────────────────────────────────────────────────────────┐
  │ U1: TI LMR16030  24V→5.0V  buck                                    │
  │   • V_in: 4–60 V                                                   │
  │   • I_out (max): 3.0 A   • efficiency η ≈ 89 % @ 200 mA (typ load) │
  │   • f_sw: 400 kHz (default RT/CLK)                                 │
  │   • Decoup: C_in 22 µF X7R + 100 nF, C_out 47 µF X7R + 22 µF X7R   │
  └─────────────────────────────────────────────────────────────────────┘
        │  +5V0   typ 80 mA / peak 200 mA (DAC AVDD + ADC AVDD)
        ▼
  ┌─────────────────────────────────────────────────────────────────────┐
  │ U2: TI TPS62082  5V→3.3V  buck                                     │
  │   • V_in: 2.5–6.0 V                                                │
  │   • I_out (max): 1.2 A   • η ≈ 92 % @ 250 mA                       │
  │   • f_sw: 2.4 MHz                                                  │
  │   • Decoup: C_in 10 µF X7R + 100 nF, C_out 22 µF X7R + 100 nF      │
  └─────────────────────────────────────────────────────────────────────┘
        │  +3V3   typ 250 mA / peak 600 mA (FPGA aux + MCU + ADC DVDD)
        ▼
  ┌─────────────────────────────────────────────────────────────────────┐
  │ U3: TI LM317  3.3V→1.8V  LDO  (low-noise FPGA I/O bank rail)       │
  │   • V_in: 3.3 V (head 1.5 V; safe drop-out)                        │
  │   • I_out (max): 1.5 A   • η ≈ 54 % (LDO inherent)                 │
  │   • Dissipation: 1.5 V × 50 mA = 75 mW typ; OK no heatsink         │
  │   • Decoup: C_in 10 µF, C_out 22 µF tantalum + 100 nF              │
  └─────────────────────────────────────────────────────────────────────┘
        │  +1V8   typ 50 mA / peak 120 mA (ECP5 VCCIO bank 0–7 = 1.8V)
        ▼
  ┌─────────────────────────────────────────────────────────────────────┐
  │ U4: TI LP3878  1.8V→1.2V  LDO  (low-noise FPGA core rail)          │
  │   • V_in: 1.8 V (head 0.6 V; LP3878 V_drop ≤ 200 mV @ 800 mA)      │
  │   • I_out (max): 800 mA  • η ≈ 67 %                                │
  │   • PSRR: 75 dB @ 1 kHz (suits FPGA core jitter sensitivity)       │
  │   • Decoup: C_in 22 µF, C_out 22 µF + 4×100 nF (1 per core ball Q) │
  └─────────────────────────────────────────────────────────────────────┘
        │  +1V2   typ 150 mA / peak 400 mA (ECP5 VCCINT)
```

Total board input load:
- Typ: 24 V × 230 mA ≈ **5.5 W**
- Peak: 24 V × 350 mA ≈ **8.4 W** (FPGA stress + simultaneous DAC/ADC)
- PSU sizing recommendation: 24 V / 1.5 A (36 W) wall-wart — 4× headroom.

## 2. Decoupling network (per IC)

| IC                | rail   | bulk            | bypass (per pin) | total caps |
|:------------------|:-------|:----------------|:-----------------|:-----------|
| ECP5 LFE5UM-85F   | 1.2 V  | 1× 47 µF tant   | 100 nF × N_VCCINT (≈ 32) + 1 nF × N_VCCINT | ~65 |
| ECP5 LFE5UM-85F   | 1.8 V  | 1× 22 µF X7R    | 100 nF × N_VCCIO (≈ 24)                    | ~25 |
| ECP5 LFE5UM-85F   | 3.3 V  | 1× 10 µF X7R    | 100 nF × N_VCCAUX (≈ 6)                    | ~7  |
| STM32G474         | 3.3 V  | 1× 4.7 µF       | 100 nF × N_VDD (≈ 6) + 4.7 µF VDDA         | ~8  |
| ADS131M08         | 5.0 V  | 1× 10 µF        | 100 nF × 2 (AVDD) + 100 nF × 2 (DVDD)      | ~5  |
| AD5676R           | 5.0 V  | 1× 10 µF        | 100 nF × 2 (VDD)                           | ~3  |
| **Total decoups** |        |                 |                                            | **~115** |

Estimate aligned with `schematic_paper.md §5` "passives ~150" budget.

## 3. Power-on sequencer (TPS3823)

Sequence: 3.3 V → 1.8 V → 1.2 V (per ECP5 datasheet rule: VCCAUX before VCCIO before VCCINT).
Tolerance: each rail must reach 90 % nominal within 10 ms before next rail enables.
Reset: TPS3823 holds nRST low until the slowest rail (1.2 V, ramped via LP3878 EN) crosses 1.08 V (90 % × 1.2 V).
Brownout: any rail dropping below 85 % for > 50 µs → re-assert nRST + log fault to MCU via FAULT_LATCH GPIO.

```
    t (ms)   ┌────── +3V3 ramp (1 ms) ───────────────────────────────
             │                ┌── +1V8 ramp (2 ms) ──────────────────
             │                │              ┌── +1V2 ramp (3 ms) ───
             │                │              │      ┌──── nRST released
    0────────┴────────────────┴──────────────┴──────┴────────────────
                 1ms              4ms              10ms      11ms
```

## 4. Estimated rail noise (paper-tier)

| rail    | regulator   | f_sw / type | est. ripple p-p   | target              |
|:--------|:------------|:------------|:------------------|:--------------------|
| 5.0 V   | LMR16030    | 400 kHz buck| ~30 mV (0.6 %)    | < 50 mV for ADC ref |
| 3.3 V   | TPS62082    | 2.4 MHz buck| ~10 mV (0.3 %)    | < 30 mV for FPGA    |
| 1.8 V   | LM317 LDO   | DC          | ~1 mV             | < 5 mV  for FPGA IO |
| 1.2 V   | LP3878 LDO  | DC          | ~0.3 mV (PSRR 75 dB)| < 2 mV for FPGA core |

Critical loop: 1.2 V FPGA core. LP3878 PSRR at 1 kHz (75 dB) attenuates 1.8 V switching residue (~1 mV) to ~0.2 µV at the core ball — well below ECP5 VCCINT noise budget (typ < 30 mV).

## 5. Failure modes (FMEA-lite)

| failure                                | detection                       | response                          |
|:---------------------------------------|:--------------------------------|:----------------------------------|
| 24 V short (PSU OCP trips)             | PSU LED off, MCU power lost     | physical replug; no MCU log       |
| LMR16030 over-current shutdown         | 5 V drops, ADC AVDD lost        | TPS3823 BOR holds rest in reset   |
| TPS62082 thermal shutdown (155°C)      | 3.3 V drops, MCU resets         | natural cool; auto-recover        |
| LM317 dissipation > 1 W (heatsink miss)| 1.8 V sags, FPGA I/O instability| MCU FAULT_LATCH GPIO + thermistor on TO-220 tab |
| LP3878 input UV (1.8 V < 1.6 V)        | 1.2 V drops, FPGA core resets   | TPS3823 BOR cascades              |
| Decoup short (any 100 nF)              | rail current spike              | 4-rail crowbar (TPS3823 reset)    |
| Sequencer skipped (rail order wrong)   | FPGA enters undefined state     | nRST held high until all rails OK |

## 6. PI verification path (Phase E iter ≥ 3)

- [ ] LTspice or PSPICE: each LDO/buck loop closed, plot V_out ripple vs frequency
- [ ] HyperLynx PI: estimate Z_target across 1 kHz – 200 MHz for VCCINT
- [ ] Sentinel measurement plan: Tek MSO5 + 1 GHz probe, AC-couple, 50 Ω term at FPGA ball
- [ ] Stress test: 24 hr full-load (FPGA stress test pattern, ADC sampling at 32 kSPS)
- [ ] Brownout repro: ramp 24 V from 0 → 24 V at 100 ms / V — every rail must come up monotonically

(All deferred to physical-procurement gate G5.)

## 7. Cross-references

- Block schematic: `schematic_paper.md`
- KiCad project (skeleton): `fw01_corner.kicad_pro`
- Power budget table: `firmware/doc/board_v0_spec.md §1.3`
- Cross-board PI summary: `firmware/board/POWER_INTEGRITY.md`
- BOM rows: `firmware/board/bom_master.csv` (board=fw01_corner, items where group=power)
