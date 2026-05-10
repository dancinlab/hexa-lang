# `firmware/kicad/pet_cyclotron/` — Phase E project (HEXA-PET-FW-01)

> KiCad 8.0+ project for board v0 of `pet_cyclotron`.  **Empty** —
> Phase E is funding-gated.  See `../README.md` for context.

**Status**: empty (2026-05-08) · **Funding gate**: §A.6 step 2 · **Phase E sub-stage**: E1 (smallest board → recommended first demo target)

---

## §1 Spec inputs

| Read | What you'll find |
|:-----|:-----------------|
| `firmware/doc/board_v0_pet_cyclotron.md §1` | Target chip table (STM32H743VIT6 + LTC2641-16 DAC + LTC2378-16 ADC + ADuM4160 + crystals) |
| `firmware/doc/board_v0_pet_cyclotron.md §2` | 53-line pinout (PA0 RF_GATE, PA1 SHUTTER, PA2 NaI_GAMMA, PA3 DOOR_INTERLOCK, …) |
| `firmware/doc/board_v0_pet_cyclotron.md §3` | 10 connectors (J1 DC barrel, J2 Phoenix interlock, J3 SMA × 2, J4 LEMO 00B, …) |
| `firmware/doc/board_v0_pet_cyclotron.md §4` | 24-line BOM with Digi-Key/Mouser SKUs (~$220/unit @ 5-piece run) |
| `firmware/doc/board_v0_pet_cyclotron.md §5` | 7-rail power budget (~340 mA on 12 V → ~4 W) |
| `firmware/doc/board_v0_pet_cyclotron.md §6` | Mechanical (Hammond 1455-T1601BK, 100×80 mm 4-layer) |
| `firmware/doc/board_v0_pet_cyclotron.md §7` | 13-step bring-up checklist |
| `firmware/doc/schematic_v0_pet_cyclotron.md` | Block schematic + net list |
| `firmware/sim/cyclotron_trigger.hexa` | Golden behavioral sim (PASS criterion) |
| `firmware/mcu/pet_cyclotron.rs` | Rust no_std skeleton (cargo-test compatible) |

## §2 Phase E execution outline (when funded)

1. KiCad project init: `pet_cyclotron.kicad_pro` per `firmware/doc/phase_e_kicad_plan.md §2`
2. Schematic capture (top + power + STM32 + DAC/ADC + USB + SD + safety)
3. Pinout transcription from board_v0 §2 → schematic + `.kicad_pcb` pinmap
4. PCB layout: 4-layer 100×80 mm, ENIG, JLCPCB Pro
5. Gerber export → JLCPCB ($0.5–1.5k / spin)
6. SMT assembly (one-sided, JLCPCB SMT, $25 × 5)
7. Receiving + AOI per `phase_e_procurement.md §5`
8. Bring-up per board_v0 §7 (13 steps)
9. Sim parity vs `firmware/sim/cyclotron_trigger.hexa`
10. Sign-off in per-board `phase_e_test_report_*.md`

## §3 Phase E budget (this board only)

| Item | Cost | Lead |
|:-----|-----:|:----:|
| KiCad design (paper) | $0 (in-house, ~80 SE-h) | — |
| 5 × bare PCB (4L ENIG) | $50 | 7 d |
| 5 × SMT assembly | $125 | 5 d |
| BOM (5 sets) | $1,100 | 4 wk worst-case |
| First-spin fab + SMT | ~$1,300 total | ~6 wk |
| 2nd-spin (DfM revision, est) | ~$700 | 3 wk |
| **Phase E1 sub-total (this board)** | **~$2,000** | **~9 wk** |

Smallest of the 4 boards — recommended Phase E1 demo target.

## §4 Why MCU-only (no FPGA)

The PET ¹⁸F batch reactor + cyclotron-RF gate are 1 kHz control-rate
events; STM32H7 480 MHz Cortex-M7 has 480k cycles/ms — ample headroom
for state machine + DAC/ADC + safety EXTI without an FPGA.  See
`firmware/hdl/cyclotron_trigger.v` (placeholder) and
`firmware/mcu/pet_cyclotron.rs` (full MCU spec) for rationale.
