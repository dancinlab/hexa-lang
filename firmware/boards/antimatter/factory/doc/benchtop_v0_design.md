# factory benchtop v0 design — HEXA-FACTORY-01 + HEXA-PROPULSION-01

> Stage-1 benchtop hardware design covering both **F-AM-3** (Dirac mirror
> n=6 closed-form, CPT measurement) and **F-AM-4** (hexa-ufo Stage-3
> propulsion break-even).  Paper-design only.

**Status**: paper design (2026-05-08) · **F-AM-3 sat**: 100% bookkeeping · **F-AM-4 sat**: 100% bookkeeping

---

## §1 Goal

Two coupled benchtop demonstrations:

1. **F-AM-3 Dirac CPT bench** — measure m_p̄/m_p, g_p̄/g_p, q_p̄/q_p
   mass / magnetic-moment / charge ratios to ≤ 10⁻¹⁰ to verify the n=6
   Dirac-mirror closed-form (σ·φ = n·τ = J₂ = 24).

2. **F-AM-4 propulsion bench** — measure thrust from controlled p̄+p
   annihilation events; cross-verify Tsiolkovsky Δv = c·ln(m₀/m₁)
   prediction with measured exhaust velocity (target: 50% c equivalent
   at micro-thrust scale).

Apparatus mass ≈ 4 tons (CPT bench) + 1 ton (propulsion bench); cost
~$8M + $3M = $11M.

## §2 Block diagram (ASCII)

### CPT bench (F-AM-3)
```
   ┌────────────────┐  ┌──────────────────┐  ┌──────────────────┐
   │  p̄ from CERN  │->│  precision       │->│  cyclotron freq  │
   │  AD (≤100 keV) │  │  Penning trap    │  │  ν_c measurement │
   │  120 s pulse   │  │  (5 T solenoid)  │  │  (PLL + PSD)     │
   └────────────────┘  └──────────────────┘  └──────────────────┘
                                                      │
                                                      ▼
   ┌────────────────┐  ┌──────────────────┐  ┌──────────────────┐
   │  H̄ formation  │->│  hyperfine       │->│  Cs atomic clock │
   │  via positron  │  │  spectroscopy    │  │  reference       │
   │  recombination │  │  (1S-2S 243 nm)  │  │  (10⁻¹⁵ stab)    │
   └────────────────┘  └──────────────────┘  └──────────────────┘
```

### Propulsion bench (F-AM-4)
```
   ┌────────────────┐  ┌──────────────────┐  ┌──────────────────┐
   │  p̄ injection  │->│  annihilation    │->│  exhaust thrust  │
   │  (1e9 p̄/run)  │  │  chamber + mag.  │  │  Watt-balance    │
   │                │  │  nozzle          │  │  pendulum (μN)   │
   └────────────────┘  └──────────────────┘  └──────────────────┘
                                                      │
                                                      ▼
   ┌────────────────┐  ┌──────────────────┐  ┌──────────────────┐
   │  pion ToF      │->│  γ calorimeter   │->│  Δv reconstruct  │
   │  detector      │  │  (BGO/PbWO₄)     │  │  (DAQ + analysis)│
   └────────────────┘  └──────────────────┘  └──────────────────┘
```

## §3 BOM (CPT bench, F-AM-3)

| #  | Item | Spec | Qty | Cost (USD) | Vendor candidate |
|:--:|:-----|:-----|:---:|-----------:|:-----------------|
| 1  | Precision Penning trap | 5 T, 10⁻¹⁰ ν_c stability | 1 | $1,800,000 | (custom, CERN BASE-style) |
| 2  | 5 T persistent solenoid | NMR-grade homogeneity | 1 | $850,000 | Bruker · Magnex |
| 3  | LHe cryostat | 100 L + reliquefier | 1 | $320,000 | Cryomech |
| 4  | UHV beam line (CERN AD ↔ trap) | 10⁻¹² Torr | 1 | $240,000 | (custom) |
| 5  | Cs atomic clock | 10⁻¹⁵ short-term | 1 | $180,000 | Microsemi · NIST-traceable |
| 6  | 1S-2S laser (243 nm, narrow) | 1 kHz linewidth | 1 | $480,000 | Toptica · (custom doubling) |
| 7  | Microwave 1.42 GHz | hyperfine | 1 | $32,000 | R&S · Keysight |
| 8  | RF DAC/ADC chain (24-bit) | LTC2378-24 + AD9164 | 1 | $9,200 | Analog Devices |
| 9  | Digital lock-in / phase det | UHF 600 MHz | 1 | $48,000 | Zurich · Stanford Research |
| 10 | Laser stabilization (cavity) | finesse > 100k | 1 | $120,000 | Stable Laser Systems |
| 11 | DAQ FPGA + MCU | UltraScale+ + Cortex-A | 1 | $8,000 | Xilinx · NXP |
| 12 | Vibration isolation, racks, misc | — | — | $80,000 | — |
| 13 | Lab safety + interlocks | strong field + UV laser | 1 set | $35,000 | (in-house) |
| **CPT subtotal** |   |   |   | **$4,200,200** | |

## §4 BOM (Propulsion bench, F-AM-4)

| #  | Item | Spec | Qty | Cost (USD) | Vendor candidate |
|:--:|:-----|:-----|:---:|-----------:|:-----------------|
| 1  | Annihilation chamber + nozzle | 1 m³ UHV + magnetic confinement | 1 | $620,000 | (custom, NASA-style) |
| 2  | Watt-balance pendulum | μN-class thrust meas | 1 | $280,000 | NIST · Sandia |
| 3  | BGO/PbWO₄ γ calorimeter | 4π coverage, 511 keV + π⁰ | 1 | $420,000 | Saint-Gobain |
| 4  | Pion ToF detector array | 1 ns res, scintillator | 1 | $180,000 | Hamamatsu |
| 5  | UHV chamber (1 m³) | 10⁻¹⁰ Torr | 1 | $140,000 | Kurt J. Lesker |
| 6  | Magnetic nozzle coil | 8 T pulsed | 1 | $320,000 | (custom) |
| 7  | DAQ (10 GS/s waveform) | 12-bit ADCs ×16 | 1 | $80,000 | Teledyne · Tektronix |
| 8  | Trigger electronics | NIM/CAMAC + FPGA | 1 set | $48,000 | CAEN |
| 9  | Vibration / thermal isolation | sub-μN sensitivity | 1 | $120,000 | Newport |
| 10 | Lab safety + interlocks | radiation + HV | 1 set | $25,000 | (in-house) |
| 11 | Misc (cabling, racks) | — | — | $32,000 | — |
| **Propulsion subtotal** |   |   |   | **$2,265,000** | |

| **Combined factory benchtop** | (CPT + propulsion, excluding p̄ source access) |   |   | **$6,465,200** | |

## §5 Interface table

| Interface | Type | Direction | Rate | Protocol | Notes |
|:----------|:-----|:----------|:-----|:---------|:------|
| Cs clock ↔ FPGA | digital | clock → FPGA | 10 MHz | sine ref | absolute time base |
| precision trap ↔ DAC | digital | DAC → trap | 24-bit @ 10 kS/s | DC bias drive | electrode voltages |
| trap ↔ ADC (PLL) | analog | trap → ADC | 1 MS/s | LVDS | ν_c readout |
| 243 nm laser ↔ trap | optical | laser → trap | continuous | UHV port | 1S-2S spectroscopy |
| BGO calorimeter ↔ ADC | analog | calo → ADC | 10 GS/s burst | LVDS | 511 keV + π⁰ tagging |
| pion ToF ↔ FPGA | digital | ToF → FPGA | 1 GHz | CAMAC | 1 ns res |
| Watt balance ↔ ADC | analog | balance → ADC | 1 kHz | precision diff | μN sensitivity |
| FPGA ↔ MCU | digital | bidirectional | 100 MHz | AXI | trigger + cmds |
| MCU ↔ host | digital | bidirectional | 1 GHz | 10 GbE | 1 PB/yr data rate |
| safety interlock | digital | various → MCU | event | TTL | abort < 1 ms |

## §6 Safety specification

| Hazard | Source | Mitigation |
|:-------|:-------|:-----------|
| 8 T pulsed nozzle field | propulsion | 10 m exclusion + ferromag scan |
| 5 T persistent CPT field | trap | 5 m exclusion + signage |
| 243 nm UV laser | spectroscopy | enclosed beam line + interlock |
| γ radiation (511 keV + π⁰ → 2γ) | annihilation | 10 cm Pb shield + dosimetry |
| Cryogenics (LHe ×2 systems) | cryostats | O₂ monitors + venting |
| HV (trap electrodes 10 kV) | precision trap | grounded cage + LOTO |

Both benches operate under **DOE 10 CFR 851 + 10 CFR 35** (radiation +
strong field + laser).  Pacemakers / cochlear implants / metal implants
prohibited within 5 m of either bench.

## §7 n=6 lattice anchors

| Anchor | Target | Bench | Source verify script |
|:-------|:-------|:------|:---------------------|
| σ·φ = J₂ = 24 (master identity) | exact (CPT) | F-AM-3 | `verify/calc_factory.hexa` |
| m_p̄/m_p ratio | -1 ± 10⁻¹⁰ (CPT) | F-AM-3 | `verify/numerics_factory_parity.hexa` |
| g_p̄/g_p ratio | -1 ± 10⁻⁹ (CPT) | F-AM-3 | (extends parity in Stage-1) |
| Tsiolkovsky Δv = c·ln(m₀/m₁) | exact | F-AM-4 | `verify/numerics_break_even_solver.hexa` |
| 2 m_p c² = 1.876 GeV per pair | per annihilation | F-AM-4 | `verify/numerics_break_even.hexa` |
| σ³·10⁹ = 1.728e12 p̄/s flux | input | both | `verify/numerics_tabletop.hexa` |

## §8 Stage-1 success criterion

### F-AM-3 (CPT bench)
1. ν_c (cyclotron freq) measured to 10⁻¹⁰ vs Cs clock reference.
2. Mass ratio m_p̄/m_p = -1.000 000 000 0 ± 10⁻¹⁰.
3. Magnetic moment ratio g_p̄/g_p to 10⁻⁹.

### F-AM-4 (propulsion bench)
1. Annihilation event detected with full pion ToF + γ calorimeter coverage.
2. Per-event energy budget closes within 1% (E_input vs E_pion + E_γ).
3. Watt balance measures μN-class thrust impulse from controlled p̄
   release (~10⁹ p̄ batch).
4. Reconstructed Δv matches Tsiolkovsky closed-form ± 5%.

## §9 External dependencies

- **CERN Antiproton Decelerator + ELENA** — p̄ supply (both benches).
  Same MoU as tabletop pillar.
- **NIST atomic-clock calibration** — Cs reference cross-traceable.
- **CERN BASE / ATRAP collaboration** — methodology + cross-check
  (F-AM-3).

## §10 Cross-link

- `verify/numerics_factory*.hexa` — T1+T2 (F-AM-3 algebraic + numerical)
- `verify/numerics_break_even*.hexa` — T1+T2 (F-AM-4)
- `verify/empirical_dirac_inspire.hexa` — F-AM-3 T3
- `verify/empirical_break_even_inspire.hexa` — F-AM-4 T3
- `.roadmap.hexa_antimatter §A.4 F-AM-3 + F-AM-4`
- `.roadmap.hexa_antimatter §A.6 step 3`
- `~/core/hexa-ufo` — Stage-3 propulsion downstream consumer

## §11 Open questions

1. CPT bench shares CERN AD time slots with tabletop pillar — schedule
   conflict or co-location?
2. Propulsion bench thrust resolution — μN floor vs nN target; would
   benefit from torsion-balance variant.
3. p̄ batching for propulsion — 10⁹ p̄ per shot vs continuous low-flux
   trade-off (DAQ rate).
4. Cross-bench p̄ source sharing — single CERN AD beam dump split between
   CPT + propulsion + tabletop = 3-way request, may need rotation.
