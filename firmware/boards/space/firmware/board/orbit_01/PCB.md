<!-- @canonical: hexa-space@local-draft (.roadmap §A.6.2 Phase E) -->

# HEXA-ORBIT-01 — PCB layout & stack-up

> 4-layer FR-4, 100 mm × 80 mm, 1.6 mm finished thickness.

## §1 Stack-up (4-layer ENIG)

| Layer | Name        | Material | Thickness | Function |
|:-----:|:------------|:---------|:----------|:---------|
| 1 | TOP         | Cu 1 oz HOZ-finish | 35 µm | Signal + components |
| — | Prepreg     | FR-4 7628          | 250 µm |  |
| 2 | GND         | Cu 1 oz             | 35 µm | Solid ground plane |
| — | Core        | FR-4                | 1100 µm | thick core for stiffness |
| 3 | PWR         | Cu 1 oz             | 35 µm | +3V3 / +1V2 / +3V3_A islands |
| — | Prepreg     | FR-4 7628          | 250 µm |  |
| 4 | BOTTOM      | Cu 1 oz             | 35 µm | Signal + bottom-side decap |

Total ≈ 1.6 mm.  Surface finish ENIG (Au 0.05 µm / Ni 5 µm).

## §2 Board outline

- Outline: 100.00 × 80.00 mm rectangular, 1 mm corner radius.
- 4× M3 mounting holes at corners (3.2 mm drill, 6 mm keepout).
- USB-C (J1) at edge X=10, Y=−2 (offset for connector overhang).
- Battery holder (J3) on bottom side at X=85, Y=10.

## §3 Routing rules

- Min trace / space: 5 mil / 5 mil (0.127 mm) — JLCPCB economy class.
- Min via: 0.3 mm drill / 0.6 mm pad (PTH).
- Differential pairs: USB D+/D− 90 Ω, length-match ±5 mil.
- Crystal Y1 traces ≤ 10 mm, no via, ground guard all sides.
- ADC parallel bus length-match ±20 mil within byte (PA[7:0] / PB[3:0]).
- DAC parallel bus length-match ±20 mil within nibble.
- USART nets > 10 mm: series 33 Ω termination at MCU side.

## §4 Power-island map (layer 3 PWR)

```
   ┌─────────────────────────────────────┐
   │                                     │
   │   +3V3 (digital)         +3V3_A     │  ← pour split
   │   ┌──────────────┐  ┌─────────────┐ │
   │   │  MCU + GPS   │  │  ADC analog │ │
   │   │  + RS485     │  │             │ │
   │   └──────────────┘  └─────────────┘ │
   │                                     │
   │   +1V2_CORE  (small island)         │
   │   ┌────────┐                        │
   │   │ MCU core│                       │
   │   └────────┘                        │
   └─────────────────────────────────────┘
```

Splits routed with anti-pad bridges only at L1 ferrite footprint.

## §5 Impedance & EMC

- USB D+/D−: 90 Ω diff.  Calculated for 5 mil trace, 5 mil space, 250 µm
  prepreg → ~89 Ω @ 100 MHz (within ±10 % spec).
- Single-ended SE 50 Ω target for high-speed parallel — not critical
  for 1 MSPS ADC at 30 cm board span.
- Common-mode choke on USB if FCC Part 15 emissions fail (TBD bench
  measurement).

## §6 Assembly notes

- All SMT on top side (single-pass JLCPCB EconomyPCB Assembly).
- CR2032 holder J3 on bottom side (2nd pass hand-solder or paste-+-reflow).
- Test points: TP1 (+3V3), TP2 (+1V2), TP3 (+3V3_A), TP4 (GND), TP5
  (OSC_25M), TP6 (PA0/PPS).
- Boundary scan: SWD only; no JTAG-BST chain (single MCU).

## §7 KiCad files

- `orbit_01.kicad_pro` — project file (TBD on first KiCad open)
- `orbit_01.kicad_sch` — root schematic (skeleton: empty sheet w/ title block; populate from `SCHEMATIC.md`)
- `orbit_01.kicad_pcb` — PCB layout (skeleton: outline + mounting holes only)

These KiCad skeletons let a board-designer open the project, then populate
schematic per `SCHEMATIC.md` §2 net list and place components per the BOM.
Auto-router Freerouting can produce a 4-layer routing in ≈ 10 min once
schematic + footprints are placed.

— provenance: drafted 2026-05-08, RSC iter 18.
