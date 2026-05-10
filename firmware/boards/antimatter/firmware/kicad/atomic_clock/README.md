# `firmware/kicad/atomic_clock/` — Phase E project (HEXA-FACTORY-FW-01 CPT bench)

> KiCad 8.0+ project for board v0 of `atomic_clock`.  **Empty** —
> Phase E is funding-gated.  See `../README.md` for context.

**Status**: empty (2026-05-08) · **Funding gate**: §A.6 step 2 · **Phase E sub-stage**: E1 (small-mid, second demo target)

---

## §1 Spec inputs

| Read | What you'll find |
|:-----|:-----------------|
| `firmware/doc/board_v0_atomic_clock.md §1` | Target chip table (XCKU040 Kintex UltraScale + STM32H723 companion + TDC7201 1-ps TDC + LTC2387-24 + ADF4356 LO + Wenzel ULN-OCXO + Cs 5071A 10 MHz off-board) |
| `firmware/doc/board_v0_atomic_clock.md §2` | Bank 64–70 timing-critical pinout (10 MHz Cs ref, TDC start/stop1/stop2, photodiode pulse, ADF4356 SPI, laser-lock DAC SPI) |
| `firmware/doc/board_v0_atomic_clock.md §3` | 12 connectors (ATX, EPS, BNC Cs ref, SMA TDC test, LEMO photodiode, DB-15 laser monitor, RJ45 GbE, JTAG ×2) |
| `firmware/doc/board_v0_atomic_clock.md §4` | 19-line BOM (~$2,400/unit @ 5-piece, 14 wk worst-case) |
| `firmware/doc/board_v0_atomic_clock.md §5` | Power budget (~50 W steady — 250 W ATX light load) |
| `firmware/doc/board_v0_atomic_clock.md §6` | Mechanical (Hammond 1455-T2201BK 1U rack, 180×180 mm 6L controlled-Z) |
| `firmware/doc/board_v0_atomic_clock.md §7` | 13-step bring-up checklist (Cs ref < 1 ps RMS jitter, 1 PPS counter ≤ 100 ns vs Cs, ADF4356 PLL lock @ 6.8 GHz, …) |
| `firmware/doc/schematic_v0_atomic_clock.md` | Block schematic + net list |
| `firmware/sim/atomic_clock_counter.hexa` | Golden behavioral sim |
| `firmware/hdl/atomic_clock.v` + `atomic_clock.xdc` | Vivado top + constraints |
| `firmware/mcu/cpt_bench.rs` | STM32H723 + XCKU040 PS Rust skeleton |

## §2 Phase E execution outline

1. KiCad project init (per `phase_e_kicad_plan.md §2`)
2. Schematic capture (top + power + Kintex + DDR3 + TDC + LTC2387 + ADF4356 + photodiode amp + Cs ref input cond)
3. PCB layout: 6-layer controlled-Z (50 Ω LVDS + 100 Ω diff CML for TDC stops)
4. Gerber export → PCBWay 6L controlled-Z ($190/spin)
5. SMT assembly (BGA + LFCSP, PCBWay Pro, $620 × 5)
6. Bring-up per board_v0 §7 — critical: Cs ref jitter, TDC self-cal, photodiode dark count, ν_c counter long-term run vs Cs
7. Sim parity vs `firmware/sim/atomic_clock_counter.hexa`

## §3 Phase E budget (this board only)

| Item | Cost | Lead |
|:-----|-----:|:----:|
| KiCad design (paper) | $0 (in-house, ~220 SE-h) | — |
| 5 × bare PCB (6L controlled-Z) | $190 | 14 d |
| 5 × SMT assembly | $3,100 | 18 d |
| BOM (5 sets, incl. Wenzel + Cs ref jumper, photodiode is 8 wk lead) | $12,000 | 14 wk |
| First-spin fab + SMT | ~$15,300 | ~16 wk |
| 2nd-spin | ~$3,500 | 5 wk |
| **Phase E1 sub-total (this board)** | **~$18,800** | **~21 wk** |

## §4 Cross-board dependencies

- Cs 5071A reference (off-board) — shared with `thrust_acquisition` board (J3 BNC daisy-chain via passive splitter).
- Wenzel ULN-OCXO 100 MHz — same vendor as tabletop_penning.
- Vivado Design Edition seat — same as tabletop/thrust.

## §5 Why split MCU + FPGA

The CPT bench has BOTH:
- A timing-critical FPGA (XCKU040) for ν_c counting + TDC + ADF4356 LO + photodiode pulse capture
- A general-purpose companion MCU (STM32H723) for laser-lock servo + UART telemetry + safety interlock

The MCU offloads non-real-time work (slow PI laser servo, USB console)
so the FPGA can stay focused on sub-ns timing.  Same pattern as
`thrust_acquisition`.
