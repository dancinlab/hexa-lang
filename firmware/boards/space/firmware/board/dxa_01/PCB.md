<!-- @canonical: hexa-space@local-draft (.roadmap §A.6.2 Phase E) -->

# HEXA-DXA-01 — PCB layout & stack-up

> 4-layer FR-4, 100 mm × 80 mm.  Same process as ORBIT-01; only signal
> mix differs (USB-host + LCD instead of GPS + RS-485).

## §1 Stack-up
Identical to `firmware/board/orbit_01/PCB.md §1` (4-layer ENIG, 1.6 mm).

## §2 Board outline
- 100 × 80 mm, 1 mm corner radius, 4× M3 mount holes.
- USB-C input (J1) at edge X=10, Y=−2.
- USB-A host (J3) at edge X=−2, Y=40 (perpendicular to J1 for cable strain relief).
- microSD (J5) on bottom side at X=85, Y=10.
- TFT FFC (J6) at edge X=50, Y=82.

## §3 Routing rules

- Min trace / space: 5 mil / 5 mil.
- USB-A host D+/D−: 90 Ω diff, length-match ±5 mil, < 50 mm length.
- LCD RGB parallel: length-match ±20 mil within byte; LCD_CLK is the
  reference for all RGB/HSYNC/VSYNC nets.
- Crystal Y1 traces ≤ 10 mm, ground guard.

## §4 Power-island map

- Layer 3 PWR split: +3V3 (digital, large pour), +5V_HOST (small island
  near U8 and J3), +1V2_CORE (small island under MCU).

## §5 Impedance & EMC

- USB D+/D− 90 Ω diff.
- LCD ribbon ≥ 50 mm: optionally add common-mode choke at FFC entry.

## §6 Assembly notes

- All SMT on top side except J5 (microSD bottom).
- TFT LCD attaches via FFC (no soldering on board side).
- 5 V boost for USB host VBUS via U8 (TPS2051) — already on +3V3 rail
  pre-boost; if external 5 V from J1 USB-C is gated, U8 sources from there.

## §7 KiCad files

- `dxa_01.kicad_pro`
- `dxa_01.kicad_sch`
- `dxa_01.kicad_pcb`

— provenance: drafted 2026-05-08, RSC iter 18.
