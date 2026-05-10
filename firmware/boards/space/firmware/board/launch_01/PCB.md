<!-- @canonical: hexa-space@local-draft (.roadmap §A.6.2 Phase E) -->

# HEXA-LAUNCH-01 — PCB layout & stack-up

> 8-layer FR-4, 200 mm × 130 mm, 1.6 mm. BGA-1156 + DDR4 routing → 8 layer
> floor; HDIs may push to 10 layer if DDR4 fly-by topology fails timing.

## §1 Stack-up (8-layer ENIG, controlled-impedance)

| Layer | Name        | Material | Thickness | Function |
|:-----:|:------------|:---------|:----------|:---------|
| 1 | TOP         | Cu 1 oz HOZ | 35 µm | Signal (FPGA top + components) |
| — | Prepreg     | FR-4 7628  | 100 µm |  |
| 2 | GND-1       | Cu 1 oz     | 35 µm | reference for L1 |
| — | Core        | FR-4 4mil   | 100 µm |  |
| 3 | SIG-INNER1  | Cu 1 oz     | 35 µm | DDR4 cmd/addr |
| — | Prepreg     | FR-4 1080  | 75 µm |  |
| 4 | PWR-1       | Cu 2 oz     | 70 µm | +1V0 VCCINT pour |
| — | Core        | FR-4 8mil   | 200 µm |  |
| 5 | PWR-2       | Cu 2 oz     | 70 µm | +1V8 + +0V85 islands |
| — | Prepreg     | FR-4 1080  | 75 µm |  |
| 6 | SIG-INNER2  | Cu 1 oz     | 35 µm | DDR4 data byte-lanes |
| — | Core        | FR-4 4mil   | 100 µm |  |
| 7 | GND-2       | Cu 1 oz     | 35 µm | reference for L8 |
| — | Prepreg     | FR-4 7628  | 100 µm |  |
| 8 | BOTTOM      | Cu 1 oz     | 35 µm | Signal + bottom-side decap |

Total ≈ 1.6 mm. Surface finish ENIG; solder mask LPI green; silkscreen white.

## §2 Board outline

- 200.00 × 130.00 mm rectangular, 2 mm corner radius.
- 4× M3 mounting holes at corners.
- HDMI input (J2) at edge X=−2, Y=20.
- HDMI output (J3) at edge X=−2, Y=80.
- DC barrel (J1) at edge X=202, Y=65 (opposite side from HDMI).

## §3 Routing rules

- Min trace / space: 4 mil / 4 mil (0.10 mm).
- Min via: 0.25 mm drill / 0.5 mm pad (PTH); 0.15 mm uVia for BGA escape.
- HDMI TMDS: 100 Ω diff, length-match ±2 mil per pair.
- DDR4 cmd/addr fly-by: ±25 mil match, terminate at far-end with 39 Ω.
- DDR4 data byte-lane: ±5 mil within byte; bytes match within ±50 mil.
- DDR4 DQS: −0/+10 mil leading vs DQ.
- 200 MHz LVDS ref: 100 Ω diff, length-match ±2 mil.

## §4 Power-island map

- Layer 4 PWR-1 split: VCCINT (large island under FPGA), +5V0 corner.
- Layer 5 PWR-2 split: +1V8 (VCCAUX + HP banks pour), +0V85 (BRAM),
  +3V3 (peripherals).

## §5 Impedance & EMC

- HDMI TMDS 100 Ω diff: 4 mil trace, 4 mil space, 100 µm prepreg above
  GND-1 → ~98 Ω calc (within ±10 % spec).
- DDR4 SE 40 Ω target for DQ; diff 80 Ω for clock + DQS.
- HDMI common-mode choke (Würth 744232090) at each HDMI connector.

## §6 Assembly notes

- All SMT on top side. BGA-1156 (FPGA) + 4× DDR4 BGA-78 + ADC LFCSP-48.
- JLCPCB BGA assembly (X-ray inspection mandatory).
- JTAG (J6) + SD (J5) on bottom side.
- Test points: TP1-TP12 for each rail + key DDR signals.

## §7 KiCad files

- `launch_01.kicad_pro` — project file
- `launch_01.kicad_sch` — root schematic skeleton
- `launch_01.kicad_pcb` — PCB layout skeleton (outline + holes only)

— provenance: drafted 2026-05-08, RSC iter 18.
