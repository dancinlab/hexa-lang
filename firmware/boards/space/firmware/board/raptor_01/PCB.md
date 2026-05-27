<!-- @canonical: hexa-space@local-draft (.roadmap §A.6.2 Phase E) -->

# HEXA-RAPTOR-01 — PCB layout & stack-up

> 8-layer FR-4, 180 mm × 130 mm.  Same process as LAUNCH-01 with smaller
> footprint (no HDMI TX, no APU SoC complexity).

## §1 Stack-up
Identical to `firmware/board/launch_01/PCB.md §1` (8-layer ENIG, 1.6 mm).

## §2 Board outline

- 180 × 130 mm, 2 mm corner radius, 4× M3 mounts.
- HDMI input (J2) at edge X=−2, Y=20.
- DC barrel (J1) at edge X=182, Y=65.
- JTAG (J6) on top side near FPGA at X=90, Y=110.

## §3 Routing rules
Same as LAUNCH-01 §3. No HDMI TX → simpler layer 1 routing.

## §4 Power-island map

- Layer 4 PWR-1 split: VCCINT, +5V0.
- Layer 5 PWR-2: +1V8 (VCCAUX + HP banks), +0V95 (BRAM, note 0.95 V vs
  0.85 V on LAUNCH-01), +3V3.

## §5 Impedance & EMC
Same as LAUNCH-01 §5.

## §6 Assembly notes
Same as LAUNCH-01 §6.  Bottom side hosts JTAG (J6), microSD (J5), Pmod (J9).

## §7 KiCad files

- `raptor_01.kicad_pro`
- `raptor_01.kicad_sch`
- `raptor_01.kicad_pcb`

— provenance: drafted 2026-05-08, RSC iter 18.
