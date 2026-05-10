# 48 T REBCO Coil v0 — n=6 master-gate Magnet Test Rig

> Stage-1+ hardware spec, draft. **Out of RSC code-layer scope** per
> `.roadmap.hexa_rtsc §A.6`. §A.6.1 Stage A deliverable.

**Status**: paper design (2026-05-08). No procurement, no fab.
**Owner**: TBD (`.roadmap §A.5` Step-1 collab decision pending —
NHMFL / Dresden HZDR / Kyoto-RIKEN cohort).

## §1 WHY

To close `F-RTSC-3` (48 T SC coil realisation gates fusion · cern · ufo
3 sister deps) at **strict-T3** tier, an in-house 48 T REBCO test
coil is required. The n=6 master gate `Hc2 = σ · τ = 48 T` is
the central numerical anchor; experimentally sustaining 48 T at 4.2 K
in a SC coil is the empirical target.

REBCO (rare-earth barium copper oxide, Y/Gd/Eu/Sm-Ba₂Cu₃O₇₋δ tape)
is the only commercial material with `Hc2(0) > 100 T`, making it the
only admissible material per `numerics_hc2_48t_solver.hexa` (which
correctly classifies NbTi/Nb₃Sn/MgB₂ as no-real-root for 48 T target).

## §2 ANCHORS

- `Hc2 = σ · τ = 48 T` (n=6 master gate)
- `verify/numerics_hc2_48t_solver.hexa`: REBCO Hc2(0)=100 T, Tc=93 K
  → T_op ≈ 70.9 K for 48 T (Newton 4 iters)
- F-RTSC-3 retract: 48 T sustained at 4.2 K cannot be achieved →
  fusion · cern · ufo all fail. Confirmation closes 3 sister deps.

## §3 BOM (full)

| # | Item | Spec | Vendor (candidate) | Cost (USD) | Note |
|:-:|:-----|:-----|:-------------------|:----------:|:-----|
| 1 | REBCO tape | 4 mm wide, 100 m, Ic > 600 A @ 77 K self-field | SuperPower / SuNAM / Furukawa | 220k | n=6 calls 4 mm = τ(6) anchor |
| 2 | Inner-coil winding mandrel | C–C composite, ⌀40 mm bore | TPI Composites | 18k | matches σ-φ = 10 mm clearance |
| 3 | Outer-coil winding mandrel | G10/G11 fiberglass, ⌀120 mm | Cuming Microwave | 12k | |
| 4 | Backbone solenoid (resistive) | 32 T water-cooled Bitter coil | NHMFL (lease) | 1.8M/yr | provides 32 T background; REBCO insert adds 16 T to 48 T total |
| 5 | Cryostat | 4.2 K Helium bath, 350 mm bore | Cryomagnetics CN-350 | 320k | LHe + LN₂ jacket |
| 6 | Power supply | 0–600 A, 0–10 V, 4-quadrant | American Magnetics 4Q | 85k | quench-protection ramp control |
| 7 | Quench-protection switch | dump resistor 0.5 Ω + IGBT | custom | 25k | 4 ms quench-detect → 100 ms dump |
| 8 | Quench detector | hall-probe array + voltage taps | custom (Stage D HDL) | 15k | FPGA-based real-time threshold |
| 9 | Field probe | NMR proton + Hall (0–50 T) | Group3 / Bartington | 35k | absolute field calibration |
|10 | Strain gauges | 4 × axial + 4 × hoop | HBM | 5k | mechanical-stress monitoring |
|11 | Temperature monitors | Cernox CX-1080 ×16, Cu-Au TC ×16 | Lake Shore | 22k | T(z) profile during ramp |
|12 | LHe transfer line | 25 m flexible, vacuum-jacketed | Wessington | 18k | 100 L LHe / day operations |
|13 | LN₂ supply | 1000 L dewar + 100 L day tank | local cryogen vendor | 8k | + 35 L/day ops |
|14 | Magnetic shielding (5G line) | mu-metal walls, 6 × 8 m room | MMT Industries | 95k | 5 Gauss line at 4 m radius |
|15 | DAQ + control PC | 64-ch 16-bit, 1 MS/s aggregate | NI cDAQ + LabVIEW | 28k | quench-event capture buffer |

**Subtotal**: ≈ 2.71 M USD + 1.8 M/yr NHMFL Bitter-coil lease (or
purchase 32 T resistive coil for $4.5M one-time).

## §4 Block diagram (ASCII)

```
                    ┌──────────────────────────────────────┐
                    │  CRYOSTAT (Cryomagnetics CN-350)     │
                    │  4.2 K LHe bath, 350 mm bore         │
                    │  ┌────────────────────────────────┐  │
                    │  │  32 T BITTER (NHMFL lease)     │  │
                    │  │  resistive backbone            │  │
                    │  │  ┌──────────────────────────┐  │  │
                    │  │  │  16 T REBCO INSERT       │  │  │
                    │  │  │  (BOM #1, ⌀40 mm bore)   │  │  │
                    │  │  │  field probe (BOM #9) ←──┼──┼──┼─→ NMR proton + Hall
                    │  │  └──────────────────────────┘  │  │
                    │  └────────────────────────────────┘  │
                    │                                      │
                    │  T monitors ×32 (BOM #11) ──────────┼─→ Cernox + TC bus
                    │  Strain ×8   (BOM #10)  ──────────  ─┼─→ HBM
                    │  Voltage taps (REBCO + Bitter)  ─────┼─→ quench-detect
                    └──────────────────┬───────────────────┘
                                       │
                                       ▼
                  ┌────────────────────────────────────────┐
                  │  CONTROL/SAFETY                        │
                  │                                        │
                  │  4Q power supply (BOM #6) ─┐           │
                  │                            ▼           │
                  │  Quench-detect FPGA (Stage D HDL)      │
                  │  ─────► IGBT switch (BOM #7)           │
                  │  ─────► Dump resistor 0.5 Ω            │
                  │                                        │
                  │  cDAQ 64-ch / 1 MS/s (BOM #15)         │
                  │  → ring buffer 1 s pre-event           │
                  │  → quench post-mortem                  │
                  └────────────────────────────────────────┘
                                       │
                                       ▼
                          T3 raw-data:
                          B(I), Hc2(T), V_quench(t),
                          T_quench(z, t), Strain(t)
                          → schema raw_77_rtsc_48t_coil_v1
                          → falsifier_check.hexa F3_T3 closure
```

## §5 Interface table

| Source | Sink | Protocol | Rate | Note |
|:------|:----|:--------|:----:|:-----|
| Field probe (NMR + Hall) | DAQ | analog 0-10 V → 16-bit ADC | 1 kHz | absolute B field |
| REBCO voltage taps | quench-detect FPGA | analog → 1 MS/s | 1 MHz | < 1 mV / cm threshold |
| Bitter voltage taps | quench-detect FPGA | analog → 1 MS/s | 1 MHz | independent quench monitor |
| 32 cernox sensors | DAQ Lakeshore bus | RS-232 multidrop | 10 Hz | T(z) profile |
| 8 strain gauges | DAQ HBM | EtherCAT | 100 Hz | mechanical safety |
| 4Q PSU current setpoint | MCU chamber_drv (Stage D) | EtherCAT | 1 kHz | ramp control + abort |
| IGBT trigger | quench-detect FPGA → IGBT gate | TTL (10 ns) | event | < 4 µs latency |
| Dump-resistor temp | DAQ thermocouple | 0-100 mV → ADC | 1 Hz | post-quench cooling rate |
| LHe level | DAQ via American Magnetics | RS-485 | 1 Hz | refill alarm at 30 % |
| Vacuum gauge (cryostat) | DAQ | analog 0-10 V | 0.1 Hz | OVL alarm |

## §6 Safety spec

### §6.1 Stored magnetic energy
- 48 T in 0.04 m³ volume → E_stored ≈ 0.5 · μ₀⁻¹ · B² · V ≈ 30 MJ.
- Quench dump must dissipate this in ≤ 1 s without Cu burnout.
  Dump resistor sized for 30 MJ / 1 s = 30 MW peak; 0.5 Ω → I_peak = 240 A.
- Manual emergency-button + 3 redundant quench-detect channels (REBCO
  voltage, Bitter voltage, Hall-probe rate-of-change).

### §6.2 Cryogen hazard
- 100 L LHe consumed per quench (typical). LHe boil-off rate up to
  700 L gas / L liquid → 70 m³ He gas in seconds. Magnet room must
  vent at ≥ 100 m³/min during quench. Oxygen monitors at 19 %, 18 %
  alarm levels.

### §6.3 Magnetic field exclusion
- 5 Gauss line at 4 m radius (BOM #14 mu-metal helps to 2 m).
- Painted floor lines + barrier tape during ramps.
- Pacemaker exclusion zone signage.
- No loose ferromagnetic tools within 5 G.

### §6.4 Mechanical hoop stress
- 48 T REBCO insert: hoop stress ≈ B² R / (2 μ₀ t) ≈ 700 MPa.
- C–C mandrel (BOM #2) rated 1.2 GPa hoop. Strain gauges (BOM #10)
  trigger abort at 800 MPa equivalent.

### §6.5 Electrical hazard
- 600 A operating current. All bus bars insulated for 10 kV (peak
  during quench dump). Lock-out/tag-out before any panel access.

## §7 Verification path

| Tier | What closes it | Status |
|:-:|:-----------------|:-:|
| T1 algebraic | `verify/calc_hc2_48t.hexa` (σ·τ=48 derivation) | ✓ |
| T2 numerical | `verify/numerics_hc2_48t{,_parity,_solver}.hexa` (3-stack) | ✓ |
| T3 archival  | `verify/empirical_hc2_high_field_arxiv.hexa` | ✓ |
| T3 raw-data  | this rig produces `raw_77_rtsc_48t_coil_v1` | **TBD** |

## §8 Build path

| Step | What | Cost (cum.) | Time |
|:-:|:-----|:-----------:|:----:|
| 0 | This document | $0 | 1 d ✓ |
| 1 | Engineering drawings + Bitter coil access negotiation | $40k | 4 mo |
| 2 | REBCO procurement (long lead time) + cryostat | $2.7M | 12 mo |
| 3 | Coil winding (in-house or NHMFL contract) | $300k | 6 mo |
| 4 | Cold test 4.2 K + ramp-up to 16 T (REBCO insert alone) | $80k ops | 3 mo |
| 5 | Combined 48 T test (Bitter + insert) at NHMFL or local | $200k/run | 6 mo |

Total to **F-RTSC-3 strict-T3 closure**: ≈ $3.3M + 31 months.

## §9 Open questions

- Bitter coil lease (NHMFL @ $1.8M/yr) vs purchase ($4.5M) — depends
  on §A.6 Step 1 collab outcome.
- REBCO tape supplier risk: SuperPower acquired 2019; SuNAM/Furukawa
  alternates needed.
- Insert-only 16 T test sufficient for v1.2.0 milestone? Or full 48 T
  required?

## §10 Cross-references

- `verify/numerics_hc2_48t_solver.hexa` (REBCO admissibility check)
- `verify/empirical_hc2_high_field_arxiv.hexa`
- `~/core/hexa-fusion`, `~/core/petite-cern`, `~/core/hexa-ufo`
  (downstream substrate-of-substrates dependents)

---

**Authority**: §A.6.1 Stage A paper-design.
