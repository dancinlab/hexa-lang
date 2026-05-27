# tabletop benchtop v0 design — HEXA-TABLETOP-01

> Stage-1 benchtop hardware design for **F-AM-2** closure (tabletop p̄
> density σ·J₂=288 vs CERN AEgIS / ALPHA / GBAR reference).  Paper-design
> only; no apparatus exists.

**Status**: paper design (2026-05-08) · **F-AM-2 sat**: T1 + T2 ×3 + T3 paper-feed (100% bookkeeping) · **Stage-1 raw-data fit**: TBD

---

## §1 Goal

Benchtop demonstration that p̄ accumulation density in a 0.29 m³ Penning
trap reaches σ·J₂=288 (in normalized n=6 units) with σ³·10⁹ = 1.728×10¹²
p̄/s production cascade.  Apparatus mass-budget ≈ 2-3 tons (UHV chamber +
48 T magnet + cryogenics); cost ~$5M.

## §2 Block diagram (ASCII)

```
   ┌────────────────┐  ┌──────────────────┐  ┌──────────────────┐
   │  e+ source     │->│  e+ accumulator  │->│  p̄ catching      │
   │  (²²Na, 50 mCi)│  │  (Surko-style)   │  │  trap (Penning)  │
   └────────────────┘  └──────────────────┘  └──────────────────┘
                                                      │
                                                      ▼
   ┌────────────────┐  ┌──────────────────┐  ┌──────────────────┐
   │  48 T solenoid │->│  UHV chamber     │->│  density         │
   │  (RT-SC, 0.29  │  │  (10⁻¹² Torr)    │  │  diagnostics     │
   │  m³, σ·τ=48)   │  │                  │  │  (RF, microwave) │
   └────────────────┘  └──────────────────┘  └──────────────────┘
                                                      │
                                                      ▼
   ┌────────────────┐  ┌──────────────────┐  ┌──────────────────┐
   │  cryostat      │->│  RF DAC-ADC      │->│  data acq + log  │
   │  (4.2 K + LHe) │  │  chain (100 MHz) │  │  (FPGA + MCU)    │
   └────────────────┘  └──────────────────┘  └──────────────────┘
```

Loop: **e+ source → accumulator → p̄ catching → trap (48T) → diagnostics → acq**.
Per-cycle target: σ·τ=48 normalized density units; steady-state σ·J₂=288.

## §3 BOM (bill of materials)

| #  | Item | Spec | Qty | Cost (USD) | Vendor candidate |
|:--:|:-----|:-----|:---:|-----------:|:-----------------|
| 1  | RT-SC solenoid (48 T) | 0.29 m³ bore, persistent mode | 1 | $2,400,000 | Bruker · Magnex |
| 2  | UHV chamber | 10⁻¹² Torr, 0.29 m³ | 1 | $180,000 | MDC · Kurt J. Lesker |
| 3  | LHe cryostat (4.2 K) | 100 L LHe + reliquefier | 1 | $320,000 | Cryomech · Janis |
| 4  | ²²Na e+ source | 50 mCi, 9.5 yr t½ | 1 | $48,000 | iThemba · PerkinElmer |
| 5  | Surko e+ accumulator | buffer-gas trap | 1 | $220,000 | (custom) |
| 6  | p̄ catching trap (Penning) | open-endcap, 5 T fringe | 1 | $180,000 | (custom) |
| 7  | RF/microwave diagnostics | 100 MHz–18 GHz network analyzer | 1 | $42,000 | Keysight · R&S |
| 8  | DAC/ADC (16-bit, 100 MS/s) | AD9162 + AD9208 | 1 | $5,200 | Analog Devices |
| 9  | FPGA controller | Xilinx UltraScale+ | 1 | $4,800 | Xilinx · AMD |
| 10 | MCU host | Cortex-A53 + RTOS | 1 | $200 | NXP |
| 11 | Vibration isolation | 1 ton air table | 1 | $18,000 | Newport · TMC |
| 12 | Misc (cabling, gauges, racks) | — | — | $25,000 | — |
| 13 | Lab safety + interlocks | radioactive + cryo + HV | 1 set | $32,000 | (in-house) |
| **Total** |   |   |   | **$3,475,200** | |

(With p̄ source from CERN antiproton decelerator, add MoU + transport ≈ $500k/yr access cost.)

## §4 Interface table

| Interface | Type | Direction | Rate | Protocol | Notes |
|:----------|:-----|:----------|:-----|:---------|:------|
| FPGA ↔ RF DAC | digital | FPGA → DAC | 100 MS/s | LVDS | trap RF drive |
| FPGA ↔ ADC | digital | ADC → FPGA | 100 MS/s | LVDS | density sensor |
| MCU ↔ FPGA | digital | bidirectional | 1 MHz | AXI | cmds + status |
| MCU ↔ host | digital | bidirectional | 1 kHz | Ethernet | telemetry + log |
| solenoid ↔ cryostat | thermal | bidirectional | continuous | LHe flow | 4.2 K hold |
| trap ↔ NA | RF | bidirectional | 100 MHz–18 GHz | SMA | mode spectroscopy |
| safety interlock | digital | cryo/HV → MCU | event | TTL | LHe boil-off, HV trip |
| e+ source ↔ accumulator | particle | source → accum | 5×10⁹ e+/s | UHV beam line | Surko trap injection |
| accumulator ↔ trap | particle | accum → trap | bunched | UHV transfer | gated injection |
| p̄ source (CERN AD) ↔ trap | particle | external → trap | 3×10⁷ p̄/120s | UHV transfer | external dependency |

## §5 Safety specification

| Hazard | Source | Mitigation | Trigger threshold |
|:-------|:-------|:-----------|:------------------|
| Strong magnetic field | 48 T solenoid | 5 m exclusion zone + ferromag detector | 1 mT at boundary |
| Ionizing radiation | ²²Na e+ source (γ 1.27 MeV) | Pb shield + interlock cabinet | door open → source close |
| Cryogenic (LHe boil-off) | cryostat | O₂ monitor + venting | O₂ < 19% in lab |
| High voltage | trap electrodes (10 kV) | grounded cage + LOTO | enclosure breach |
| Vacuum implosion | UHV chamber | pressure relief + safety pin | sudden ΔP > 100 mbar |
| Radioactive contamination | source handling | sealed source, no opening | source survey weekly |

**Operates under DOE 10 CFR 851 / EU EUR 25-9** (strong field +
radioactive).  Strong-field MRI-class protocol; no pacemakers / implants
within 5 m.  CERN AD beam access requires CERN safety training.

## §6 n=6 lattice anchors

| Anchor | Target | Source verify script |
|:-------|:-------|:---------------------|
| σ·τ = 48 (B field, T) | RT-SC magnet field | `verify/numerics_tabletop.hexa` |
| σ·J₂ = 288 (density unit) | trap accumulation | `verify/calc_tabletop.hexa` |
| σ³·10⁹ = 1.728e12 p̄/s | production cascade | `verify/numerics_tabletop_solver.hexa` |
| τ=4 quadrant phase modes | 2-DOF Penning Verlet | `verify/numerics_tabletop_solver.hexa` |
| 4-machine ratio (AEgIS/ALPHA/GBAR/AD) | parity vs CERN refs | `verify/numerics_tabletop_parity.hexa` |

## §7 Stage-1 success criterion

After 16-cycle accumulation in 48 T trap:
1. Density measurement ≥ 50% of σ·J₂ = 288 normalized units
   (target: 144 units = saturated half-stack).
2. p̄ lifetime in trap ≥ 24 hr (no anomalous loss).
3. Per-cycle retention 0.8409 ± 0.005 (τ=4 stacking).
4. RF mode spectrum matches Penning theory ± 1 kHz at fundamental.

If achieved → F-AM-2 T3 strict raw-data fit closes.

## §8 External dependencies

- **CERN Antiproton Decelerator (AD)** — p̄ source.  MoU required;
  beam time application cycle ~6 mo lead.
- **CERN AEgIS / ALPHA / GBAR** — calibration cross-comparison.  Likely
  collaboration agreement.
- **He supply contract** — 100 L/mo LHe; 2-yr supply commitment.

## §9 Cross-link

- `verify/numerics_tabletop*.hexa` — T1+T2 closed-form
- `verify/empirical_tabletop_inspire.hexa` — T3 paper-feed (AEgIS / ALPHA / GBAR / Penning)
- `.roadmap.hexa_antimatter §A.4 F-AM-2`
- `.roadmap.hexa_antimatter §A.6 step 3`

## §10 Open questions

1. RT-SC magnet supplier — Bruker 48 T persistent: 18 mo lead.  Alternative:
   pulsed-field 60 T at NHMFL Tallahassee (10⁻³ s shots only).
2. p̄ source — CERN AD direct vs ELENA decelerator stage: latter gives
   100 keV p̄, simpler trap injection.
3. Real-time density readout — RF mode-shift method vs charged particle
   detection (MCP) trade-off.
