# benchtop_v0_design — HEXA-MINI-ACCEL paper design (v0)

> **Status**: paper-only · pre-build · derived from `mini/doc/mini-accelerator.md §X.4`
> **Last update**: 2026-05-08
> **Roadmap anchor**: `.roadmap.hexa_cern §A.6.1 step A`
> **Scope**: full BOM + block diagram + interface table + power/thermal/volume
> budget + safety spec, all anchored to the n=6 invariant lattice.
> **NOT in scope**: PCB layout, mechanical CAD, MCU firmware, HDL — those land
> in §A.6.1 step C/D (`firmware/sim/`, `firmware/hdl/`, `firmware/mcu/`).
>
> This document is the **funding-pitch / external-collab-meeting-ready**
> elaboration of the 4-line §X.4 proposal. Every parameter cited here must
> reconcile back to one of the n=6 lattice values: σ=12, τ=4, φ=2, J₂=24,
> sopfr(6)=5, n=6.

---

## §1 Lattice anchor (n=6)

```
σ(6) · φ(6) = n · τ(6) = J₂ = 24
   12   ·   2  =  6  ·   4  = 24
```

| symbol | value | benchtop role                                                |
|:------:|:-----:|:-------------------------------------------------------------|
| n      | 6     | laser normalized vector potential a₀ = 6                     |
| σ      | 12    | RF cavity count / σ-cascade order; 12% energy jitter ceiling |
| τ      | 4     | acceleration phase quartet · 4 Hz repetition rate            |
| φ      | 2     | electron / positron beam (single mode in v0: e⁻)             |
| J₂     | 24    | 24 GeV ceiling per stage (J₂ × 1 GV/m × 24 m? — see §6)       |
| sopfr  | 5     | 5-tier shielding (§9 safety)                                  |

Every BOM entry below carries an `n6=` tag pointing to which lattice
invariant grounds its parameter choice.

---

## §2 Block diagram (ASCII, 10 functional blocks)

```
                       ┌─────────────────────┐
                       │ § B1  Master Clock  │   tau=4 Hz · ±1 ppm
                       │   (OCXO + PLL)      │
                       └────────┬────────────┘
                                │
        ┌───────────────────────┼─────────────────────┐
        │                       │                     │
        ▼                       ▼                     ▼
┌──────────────┐     ┌────────────────────┐    ┌──────────────┐
│ § B2  Laser  │     │ § B3  Trigger /    │    │ § B4 Vacuum  │
│   Driver     │     │   Timing Ctrl       │    │   System      │
│ 100 TW · 100 │     │   (FPGA / MCU)      │    │ <10⁻⁶ mbar    │
│ fs · a₀=6    │     └─────────┬──────────┘    │ turbo + scroll│
└──────┬───────┘               │                └──────┬───────┘
       │ optical               │ digital              │ vacuum
       ▼                       ▼                      ▼
┌──────────────────────────────────────────────────────────────┐
│ § B5  Plasma Cell  (gas jet H₂ · n_e=10¹⁸ cm⁻³ · L=3 mm)      │
│       laser ──► wakefield bubble ──► electron capture          │
└──────────────────────────────┬───────────────────────────────┘
                               │ relativistic e⁻ beam (~100 MeV)
                               ▼
                ┌──────────────────────────────┐
                │ § B6  σ-cascade Multi-Pass    │
                │  τ=4 stages · n/φ=3 active +  │
                │  1 spare · 12 RF cavities     │
                └──────────┬───────────────────┘
                           │
       ┌───────────────────┼────────────────────┐
       ▼                   ▼                    ▼
┌──────────────┐  ┌──────────────────┐  ┌────────────────────┐
│ § B7 RT-SC   │  │ § B8 Beam        │  │ § B9 Diamond       │
│   Coil       │  │   Diagnostics    │  │   Detector (BT-85)  │
│ B=48 T · R=  │  │  (BPM + EOS)     │  │   ~10⁹ p / shot     │
│  10 cm       │  │                  │  │                     │
└──────────────┘  └──────────────────┘  └────────────────────┘

                       ┌────────────────────┐
                       │ § B10 Power /       │
                       │   Cooling / HV      │
                       │   10 kW · 5-tier    │
                       │   shield · interlock│
                       └────────────────────┘
```

Edges = signal flow. Optical = thick (B2→B5). Vacuum = vacuum line (B4→B5).
Digital = clock + trigger fanout (B1→B3→B2/B4/B6/B7/B8/B9).
Power / safety = shared infrastructure (B10).

---

## §3 BOM (Bill of Materials)

Cost / lead-time figures are **2026-Q2 indicative** — funding pitch
ballpark. Real numbers require vendor RFQ.

| ref  | block | item                                          | qty | unit cost (USD) | lead-time | vendor candidate            | n6 anchor             |
|:----:|:-----:|:----------------------------------------------|:---:|:---------------:|:---------:|:----------------------------|:----------------------|
| L1   | B2    | PW-class fiber laser, 100 TW · 100 fs · 800 nm | 1   | 1,500,000–4,000,000 | 18–24 mo | Thales (Alpha 100 class), Coherent, Amplitude | a₀=n=6                 |
| L2   | B2    | Beam transport optics (off-axis parabola, mirrors) | 1 set | 80,000        | 6 mo      | Edmund Optics, Optosigma   | n=6 dof               |
| P1   | B5    | Pulsed gas jet valve (Even-Lavie type, H₂)     | 1   | 25,000          | 4 mo      | Even-Lavie, Parker IOTA      | length = sopfr-φ = 3 mm |
| P2   | B5    | Plasma cell housing + skimmer                  | 1   | 12,000          | 3 mo      | custom (in-house machining) | —                     |
| M1   | B7    | RT-SC compact coil, B = 48 T at R = 10 cm      | 1   | **N/A — current world record ≈ 45 T (NHMFL hybrid). Item requires R&D collab.** | 24–36 mo R&D | NHMFL / RIKEN / IFW Dresden | B = σ·τ = 48 T, R = σ-φ = 10 cm |
| M2   | B7    | Cryostat + LHe supply (or cryocooler)          | 1   | 350,000         | 12 mo     | Cryogenic Ltd, Janis        | —                     |
| V1   | B4    | Turbomolecular pump, 600 L/s                   | 2   | 18,000          | 3 mo      | Pfeiffer, Edwards            | —                     |
| V2   | B4    | Vacuum chamber, 50 L benchtop volume           | 1   | 30,000          | 6 mo      | custom (304 SS)              | V = V_TT·φ/σ = 0.048 m³ ≈ 50 L |
| C1   | B6    | σ-cascade RF cavity, n=6 mode, 1.3 GHz          | 12  | 80,000          | 12 mo     | Research Instruments        | σ = 12                |
| D1   | B9    | CVD diamond detector, single-crystal, 4×4×0.5 mm | 4   | 15,000          | 6 mo      | DDK, Element Six             | BT-85 carbon Z=6      |
| D2   | B8    | Beam position monitor (BPM), button-type, 4×    | 4   | 6,000           | 4 mo      | Bergoz, custom              | —                     |
| D3   | B8    | Electro-optic sampler (EOS) bench               | 1   | 75,000          | 6 mo      | LightConversion, in-house   | —                     |
| F1   | B3    | FPGA timing controller (Xilinx Kintex-7 class) | 1   | 4,500           | 1 mo      | Digi-Key / Xilinx          | tau=4 Hz trigger      |
| F2   | B3    | MCU laser-driver board (STM32H7 / RP2040)      | 1   | 800             | 1 mo      | Digi-Key                    | n=6 channel ADC + DAC |
| F3   | B1    | OCXO master oscillator, 100 MHz, ±1 ppm        | 1   | 2,500           | 2 mo      | Wenzel / Vectron            | —                     |
| H1   | B10   | HV supply, ±50 kV · 0.5 A, regulated           | 1   | 35,000          | 4 mo      | Spellman, Bertan            | 5-tier interlock      |
| H2   | B10   | Bench frame + 5-tier radiation shield (concrete + Pb + B-poly + Cd + paraffin) | 1 | 80,000 | 6 mo | in-house build              | sopfr=5 layers        |
| H3   | B10   | Cooling chiller, 15 kW capacity                | 1   | 22,000          | 3 mo      | ThermoFisher Polar          | 10 kW load + 50% margin |

**Subtotal hard parts (excl. M1)**: ≈ **$2.4 M – $5.0 M** (laser dominant).
**M1 (48 T compact magnet)**: pre-commercial, 24–36 mo R&D — likely the **single
hardest item**. Step 1 collab decision (DESY/SLAC/KEK) is largely about who
has access to or can build M1.

**Soft costs** (clean room build, RF licensing, radiation permit, FTE × 36 mo):
≈ **$3 M – $5 M**.

**Total v0 estimate**: **$5.4 M – $10 M**, 24–36 month build. This is the
ballpark figure that goes on a Step 2 funding pitch.

---

## §4 Interface table (signal-by-signal)

| # | from block | to block | signal type | spec / level | latency / rate | n6 anchor |
|:-:|:----------:|:--------:|:-----------:|:-------------|:--------------:|:---------:|
| 1 | B1         | B3       | digital clock | 100 MHz LVDS, ±1 ppm | continuous | —        |
| 2 | B3         | B2       | digital trigger | 3.3 V CMOS, 50 Ω | <10 ns jitter | tau=4 Hz |
| 3 | B3         | B6       | digital fanout (12) | LVDS to RF cavity tuners | <100 ps skew | σ=12 fanout |
| 4 | B3         | B9       | digital trigger | 3.3 V, gated readout | aligned to laser | — |
| 5 | B2         | B5       | optical pulse | 100 fs · 800 nm · 10 J | 4 Hz · jitter <1 fs | a₀=6 |
| 6 | B4         | B5       | vacuum line | KF-40 · <10⁻⁶ mbar | quasi-static | — |
| 7 | B5         | B6       | relativistic e⁻ beam | ~100 MeV · ~10⁹ e⁻/shot | bunch < 1 ps | — |
| 8 | B6         | B7       | RF + magnetic field | 1.3 GHz · 48 T DC | continuous | σ × τ = 48 T |
| 9 | B6         | B8       | beam (BPM pickup) | 1 ns sample window | 4 Hz | — |
| 10| B6         | B9       | beam (diamond) | charge integration over 100 ns | per shot | — |
| 11| B8         | B3       | analog → digital | 16-bit ADC, 1 GS/s | 4 Hz post-shot | — |
| 12| B9         | B3       | analog → digital | 14-bit ADC, 100 MS/s | 4 Hz post-shot | — |
| 13| B10        | all      | DC power rails | ±50 kV (HV), ±15 V (analog), 3.3 V (digital) | continuous | — |
| 14| B10        | all      | interlock chain | 24 V dry contact, fail-safe open | <100 ms react | sopfr=5 |
| 15| B10        | B5/B7    | cooling water | 6 L/min · 18 °C ± 1 °C | continuous | 10 kW heat load |

Signals 1–4 (digital) + 11–12 (ADC return) form the FPGA-local control
loop targeted in `firmware/hdl/timing_ctrl.v` (§A.6.1 step D).
Signals 13–15 are §10 power & safety.

---

## §5 Power budget (10 kW total, σ-φ = 10 anchor)

| block | element             | typical (W) | peak (W) | source / sink |
|:-----:|:--------------------|:-----------:|:--------:|:--------------|
| B2    | laser pump diodes   | 4,000       | 6,000    | wall plug → diodes |
| B7    | RT-SC cryocooler    | 3,000       | 3,500    | wall → cryostat |
| B6    | RF amplifiers (σ=12) | 1,500       | 2,500    | wall → cavity (heat) |
| B4    | turbo pumps + scroll | 800         | 1,000    | wall → vacuum |
| B10   | HV supply quiescent | 200         | 300      | — |
| B3    | FPGA + MCU + ADC    | 100         | 150      | — |
| B8/B9 | diagnostics rack    | 200         | 300      | — |
| **Σ** | **total**           | **9,800**   | **13,750** | wall |

Operational headroom: peak 13.75 kW vs §X.4 budget 10 kW means we are
~38% over peak budget. Mitigations: duty-cycle the laser (4 Hz × 100 fs
= 4×10⁻¹⁰ duty → average pump 4 kW within budget), or upgrade chiller to
20 kW (cost +$8 k).

**n6 anchor**: σ-φ = 10, so 10 kW is the lattice-derived budget. Peak
overshoot acceptable as long as average < 10 kW.

---

## §6 Thermal budget (10 kW load)

| heat source        | location | ΔT target | extraction route       | sink medium |
|:-------------------|:--------:|:---------:|:-----------------------|:------------|
| laser pump diodes  | B2       | < 35 °C  | water cold-plate, 6 L/min | chiller (H3) |
| RT-SC magnet       | B7       | 4 K      | LHe boiloff or cryocooler | cryogenic   |
| RF cavities ×12    | B6       | < 60 °C  | water cold-plate, 4 L/min | chiller (H3) |
| HV ballast         | B10      | < 55 °C  | forced air, 200 CFM    | room        |
| ADC / FPGA / MCU   | B3, B8/9 | < 70 °C  | forced air + heatsink  | room        |

Aggregate water cooling: 6+4 = 10 L/min @ ΔT 8 K → 5.6 kW capacity.
Air-side sink: ~3 kW at 22 °C ambient.
**Cryogenic load**: ~5 W static @ 4 K (cryocooler in B7); not in 10 kW
budget (separate).

---

## §7 Volume budget (50 L benchtop, V_TT·φ/σ anchor)

| block | volume contribution (L) | role |
|:-----:|:-----------------------:|:-----|
| B5 (plasma cell + housing) | 5  | core experiment  |
| B6 (σ-cascade, 12 cavities × ~3 L) | 36 | bulk volume      |
| B7 (RT-SC coil + cryostat) | 8 | adjacent (separate enclosure) |
| B4 (vacuum chamber inner) | (50 nominal) | enclosing all above |

Cryostat (8 L) and pumps live outside the 50 L vacuum bench — total
**lab footprint** ≈ 1.5 m × 1.0 m (~50 L vacuum + ~1 m² support hardware).

The 50 L figure tracks `V = V_TT·φ/σ = 0.29·2/12 ≈ 0.048 m³`.

---

## §8 Acceptance gates (build-time falsifier mapping)

§X.5 declares 6 falsifiers. Each becomes a build-time / commission-time
acceptance gate:

| gate | falsifier | build-time test | acceptance threshold |
|:----:|:---------:|:----------------|:--------------------:|
| G1 | F1 (cyclotron R) | survey magnet bore + run 100 MeV proton stub | R = 10 cm ± σ% (12%) |
| G2 | F2 (wakefield E) | EOS measurement of plasma wake field | E ≥ 120 GV/m (Tajima-Dawson lower bound) |
| G3 | F3 (laser a₀)    | scan a₀ ∈ [4, 8], measure energy gain | optimum at a₀ = 6 ± 1 |
| G4 | F4 (volume)      | measure as-built bench footprint | V ≤ 50 L ± 10% |
| G5 | F5 (Ω_ACCEL)     | book-keeping check: field·string·quantum = 1728 | exact |
| G6 | F6 (rep-rate)    | count diamond detector triggers / second | ≥ 4 Hz |

Gates G1, G3, G4, G6 are commissioning-gates (must pass before first
science shot). G2 is the **science gate** (the entire 1 GeV/m claim).
G5 is paper-only (already verified by `verify/falsifier_check.hexa`).

---

## §9 Safety spec (5-tier shielding, sopfr=5 anchor)

5 layers in radial order from beamline:

| tier | layer        | material      | thickness | role                        |
|:----:|:------------:|:--------------|:---------:|:----------------------------|
| 1    | bench skin   | 304 SS        | 5 mm      | vacuum boundary             |
| 2    | γ stop       | Pb            | 50 mm     | photon attenuation > 100 MeV |
| 3    | n moderator  | borated PE    | 100 mm    | thermal-neutron capture     |
| 4    | n absorber   | Cd            | 1 mm      | thermal-n absorption        |
| 5    | concrete bunker | concrete   | 600 mm    | bulk shielding to public area |

**Laser class**: Class 4 (PW-class) → mandatory enclosed Class 1 enclosure
during operation, interlocked beam dump at every diagnostic outlet.

**HV interlock**: 50 kV supply (H1) chained to door switches, vacuum
pressure switch, water-flow switch, laser shutter switch. Any open →
crowbar to ground in <100 ms.

**Personnel exclusion zone**: 3 m radius during shot; remote operation
from outside tier-5 wall.

**Regulatory**: requires ionizing radiation generator permit (varies by
jurisdiction). Step 1 collab choice (DESY/SLAC/KEK) inherits host's
licensing umbrella.

---

## §10 Out-of-scope deferments

What this v0 design intentionally does **not** specify yet:

| item                          | deferred to            | reason                  |
|:------------------------------|:----------------------:|:------------------------|
| PCB schematic / Gerber        | §A.6.1 step D          | needs MCU/FPGA part-specific |
| Mechanical CAD (STEP / STL)   | post step 1 collab    | depends on host facility |
| MCU firmware (Rust/C)         | §A.6.1 step C/D        | sim-only first (step C) |
| HDL (Verilog timing ctrl)     | §A.6.1 step D          | toolchain heavy         |
| RF cavity field map           | step B (sim parity)   | needs FBPIC/CST         |
| Thermal CFD                   | post-funding           | needs ANSYS license     |
| EMC compliance plan           | post-host-decision    | jurisdiction-dependent |
| Decommissioning plan          | post-host-decision    | host-specific waste path |

---

## §11 Anchored references

- `mini/doc/mini-accelerator.md §X.4` — the 4-line proposal this design expands
- `.roadmap.hexa_cern §A.1` — n=6 lattice (σ, τ, φ, J₂)
- `.roadmap.hexa_cern §A.6` — Stage-1+ external-bound steps
- `.roadmap.hexa_cern §A.6.1` — A→B→C→D in-repo ladder (this doc = step A)
- `verify/calc_wakefield.hexa` — wakefield ceiling closed-form (G2)
- `verify/numerics_lwfa_solver.hexa` — non-relativistic LWFA solver (step B = relativistic upgrade)
- `verify/falsifier_check.hexa` — F-PCERN-1/2/3 closure tracker

---

## §12 Sentinel for downstream verify

For machine-readable inclusion in any verify script that audits this
design's presence on disk:

```
__HEXA_CERN_BENCHTOP_V0_DESIGN__ EXISTS
```

(Plain string, no PASS/FAIL status — this is a design doc, not a runnable
verification.)
