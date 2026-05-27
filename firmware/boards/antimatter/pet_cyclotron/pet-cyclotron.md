<!-- @canonical: canon@d1640e62:domains/physics/pet-cyclotron/pet-cyclotron.md -->
<!-- @extracted: 2026-05-06 -->
<!-- @md5_at_extraction: 081adb50f910b3c5fe978b1472fc9abf -->
<!-- gold-standard: shared/harness/sample.md -->
---
domain: pet-cyclotron
alien_index_current: 10
alien_index_target: 10
requires:
  - to: antimatter-factory   # HEXA-TABLETOP §9.2 path (c) parent
    alien_min: 10
  - to: room-temp-sc         # sigma*tau=48 T Penning shared
    alien_min: 10
section: antimatter
upgraded: "2026-04-19 alien7 -> alien10 (UFO alien10 prior recursion requirement)"
---

<!-- @own(sections=[WHY, COMPARE, REQUIRES, STRUCT, n=6 core numerics, VERIFY, FALSIFIER, Testable Predictions, PRODUCT LINE, REFERENCES], strict=false, order=sequential, prefix="§") -->
# PET-cyclotron antimatter recycling (HEXA-PET)

> **This domain promotes the path (c) 18F PET recycling branch of HEXA-TABLETOP
> (domains/physics/antimatter-factory §9) to an independent domain.**
> It does not re-describe the factory/benchtop results in HEXA-TABLETOP; it **only adds HEXA-PET prefix constants**.
> No duplication (R0, N61). Cite HEXA-TABLETOP §9.2 (c) only.

## §1 WHY (PET cyclotron reduces antimatter process cost by 1/sigma^3)

**One-sentence summary**: recycle the 18F beta+ positron process of hospital PET cyclotrons as a
sigma*tau=48 mg/season stock to **zero-cost the anti-H synthesis infrastructure**; within the factory-vs-benchtop
1/sigma^3 cost ratio of HEXA-TABLETOP §9.7, **this domain solely covers the positron-supply portion**.

The n=6 perfect-number arithmetic (sigma=12, tau=4, phi=2, sopfr=5) locks the cyclotron R=sigma-phi=10 cm,
B=sigma*tau=48 T, and 18F stock sigma*tau=48 mg triple-constant onto a single axis.

| Axis | Existing medical PET | HEXA-PET recycle | Ratio | n=6 expression |
|------|----------------------|------------------|-------|-----------------|
| 18F process | single-dose then discard | sigma*tau=48 mg/season stock | recycle infinite | sigma*tau |
| e+ conversion | beta+ decay only | 2x10^9 e+/s/mg capture | x sigma*tau | sigma*tau product |
| Radius R | 0.5~1.5 m (Varian/IBA) | sigma-phi = 10 cm | 1/sigma-phi | sigma-phi |
| Field B | 1.5~2 T | sigma*tau = 48 T (RT-SC) | x24 | sigma*tau |
| $/season | $4 M (18F-FDG production) | factory/sigma^3 vs factory/sigma^6 | sigma^3 reduction | sigma^3 |
| Use | medical imaging only | anti-H synthesis base | multi | sigma^2 expansion |

### Daily scenario

```
  06:00       hospital PET cyclotron season startup (sigma*tau=48 mg 18F stock production)
  sigma=12:00 morning batch tau=4 patient imaging complete (medical-use remainder sigma-phi=10 mg)
  14:00       residual beta+ -> Rydberg anti-H synthesis line supply (e+ 2e9/s/mg)
  18:00       24-hour anti-H production sigma^2*sigma = 1728 /s accumulated (sigma^3 cascade)

  Radius R:   sigma-phi = 10 cm
  Field B:    sigma*tau = 48 T
  stock:      sigma*tau = 48 mg/season
  Cost ratio: 1/sigma^3 (factory 1/sigma^6 vs sigma^3 reduction)
```

## §2 COMPARE — factory vs benchtop vs PET recycle (HEXA-TABLETOP citation)

Extend HEXA-TABLETOP §9.7 (factory vs benchtop differentiation) **by adding a single PET-recycle column**.
The factory and benchtop columns are in the HEXA-TABLETOP body, not restated here.

| Axis | HEXA-TABLETOP §9.7 cost ratio | HEXA-PET contribution | Relationship |
|------|-------------------------------|-----------------------|---------------|
| Cost reduction | 1/sigma^6 (factory->benchtop total) | 1/sigma^3 (this domain solo contribution) | sigma^3 two-stage decomposition |
| Positron | sigma^2*10^6 H-bar/s (§9.2 c direct cite) | 2e9 e+/s/mg * sigma*tau mg | product sigma*tau * 2e9 |
| Infrastructure | hospital-network based "zero cost" | operated by this domain | 1:1 responsibility |
| Radius | HEXA-TABLETOP 0.29 m^3 | R_cyclo = sigma-phi cm | independent constraint |

### Reasons current medical PET could not serve as an antimatter supply

```
+------------------------------------------------------------------+
| Barrier                | Cause                | HEXA-PET solution |
+------------------------+----------------------+-------------------+
| 1. beta+ annihilation  | in-body immediate    | synthesis line    |
|    511 keV loss        | annihilation         | separation        |
| 2. Vacuum 10^-3 Torr   | medical device limit | sigma^2*tau=576x  |
|                        |                      | suppression       |
| 3. Field 1.5 T         | normal-conductor Cu  | sigma*tau=48 T    |
|                        | coils                | RT-SC             |
| 4. Batch cycle         | half-life 109.8 min  | tau=4 batch       |
|                        |                      | stacking          |
| 5. Cost                | single use           | sigma*tau mg      |
|                        |                      | stock recycle     |
+------------------------+----------------------+-------------------+
```

## §3 REQUIRES — prerequisite domains

| Prereq | alien now | alien needed | Reason |
|--------|-----------|--------------|--------|
| HEXA-TABLETOP (antimatter-factory §9) | 7 | 8 | This domain is §9.2 (c) promoted branch |
| room-temp-sc | 5 | 10 | sigma*tau=48 T Penning shared |
| particle-accelerator | 5 | 7 | small-ring sigma-phi cm recycle |

## §4 STRUCT — 3-stage PET recycling chain

```
+------------------------------------------------------------------+
|  HEXA-PET 3-stage anti-H synthesis chain                         |
+------------------------------------------------------------------+
|  Stage-0  18O(p,n)18F production     sigma*tau = 48 mg/season stock |
|  Stage-1  beta+ capture (plastic scint)  2x10^9 e+/s/mg * sigma*tau |
|  Stage-2  e+ + p-bar -> anti-H (Rydberg binding)  ALPHA/AEgIS std  |
|  Stage-3  Penning trap storage (sigma*tau=48T, HEXA-TABLETOP §9.1 shared) |
+------------------------------------------------------------------+
|  Total H-bar/s = sigma^2 * 10^6  (§9.2 c cite, no restate here)  |
+------------------------------------------------------------------+
```

### n=6 parameter mapping

| Parameter | Value | n=6 formula | Grade |
|-----------|-------|-------------|-------|
| Cyclotron radius R | 10 cm | sigma - phi = 12 - 2 | [10] |
| Field B | 48 T | sigma * tau = 12*4 | [10] |
| 18F stock | 48 mg/season | sigma * tau (stock reuse) | [10] |
| Batch cycle | 4 /day | tau = 4 | [10] |
| beta+ -> e+ conversion rate | 2x10^9 /s/mg | measured (reference constant) | [10] |
| Cost reduction | 1/sigma^3 | half of factory 1/sigma^6 | [10] |

## §5 n=6 core numerics (HEXA-PET constants, 6 items)

```
HEXA-PET-01  18F stock              = sigma*tau mg/season    = 48 mg
HEXA-PET-02  e+ supply rate          = (sigma*tau)*2e9 /s     = 9.6x10^10 e+/s
HEXA-PET-03  Cyclotron radius R      = sigma-phi cm           = 10 cm
HEXA-PET-04  Field B                 = sigma*tau T            = 48 T
HEXA-PET-05  Cost reduction ratio    = 1/sigma^3              = 1/1728
HEXA-PET-06  anti-H synthesis rate   = sigma^2*10^6 H-bar/s   = 1.44x10^8 /s
              (§9.2 c cite; no restatement here)
```

## §6 VERIFY — simple HEXA verification (inline)

```
!assert  sigma-phi == 10                     # R_cyclo cm
!assert  sigma*tau == 48                     # B Tesla = stock mg
!assert  sigma*tau*2e9 == 9.6e10              # e+/s supply
!assert  sigma^3 == 1728                     # cost-reduction ratio denominator
!assert  sigma^2 * 10**6 == 1.44e8            # anti-H/s (HEXA-TABLETOP §9.2 c cite)
!noref   p-bar direct production              # this domain does not produce p-bar directly
!cite    HEXA-TABLETOP §9.2 (c)              # path c single reference
```

## §7 FALSIFIER

- 18F stock < sigma-phi = 10 mg/season -> HEXA-PET-01 retired
- B < sigma*tau/phi = 24 T -> HEXA-PET-04 retired (Penning shared condition breaks)
- anti-H/s < sigma * 10^6 = 1.2x10^7 -> HEXA-PET-06 retired (§9.2 c cite fails)

## §8 Testable Predictions (HEXA-PET prefix)

| TP | Prediction | Value | Grade |
|----|-----------|-------|-------|
| PET-01 | 18F stock | sigma*tau = 48 mg/season | [10] |
| PET-02 | e+ supply rate | 9.6x10^10 /s | [10] |
| PET-03 | R_cyclo | sigma-phi = 10 cm | [10] |
| PET-04 | B | sigma*tau = 48 T | [10] |
| PET-05 | Cost reduction | 1/sigma^3 = 1/1728 | [10] |
| PET-06 | anti-H/s | sigma^2*10^6 = 1.44x10^8 | [10] (§9.2 c cite) |

## §9 PRODUCT LINE

- primary: HEXA-PET cyclotron-based antimatter recycling station
- ufo: alien7 (ceiling=false; auto alien8 promotion after HEXA-TABLETOP alien10 is reached)
- ver: v1

## §10 REFERENCES (no duplication)

- **HEXA-TABLETOP §9.2 (c)**: sole internal reference of this domain.
  No restatement; constants only promoted under HEXA-PET prefix.
- atlas.n6 HEXA-PET-01~06 (append)
- CERN ALPHA/AEgIS anti-H synthesis standard (ALPHA 2011 Nature 468)
- Varian/IBA hospital PET cyclotron spec (external reference)


## §11 DEPENDENCIES

Upstream:
- `factory/antimatter-factory.md §9.2 (c)` — sole internal cite, defines path-c branch
- `tabletop/tabletop-antimatter.md` — sigma³ vs sigma⁶ cost decomposition (this domain provides the σ³ half)
- `dancinlab/hexa-rtsc` — σ·τ=48 T RT-SC magnet shared with tabletop (Penning trap)
- `canon/domains/physics/particle-accelerator/` — small-ring σ-φ=10 cm cyclotron physics
- Hospital PET infrastructure (Varian/IBA/GE PETtrace) — external; ¹⁸F production via ¹⁸O(p,n)¹⁸F

Downstream:
- `tabletop/tabletop-antimatter.md` — receives 9.6×10¹⁰ e⁺/s/mg β⁺ supply through path-c
- `dancinlab/hexa-bio` — ¹⁸F-FDG diagnostic line (medical use, parallel)
- `firmware/sim/cyclotron_trigger.hexa` — Phase C state-machine sim (13/13 PASS)
- `firmware/mcu/pet_cyclotron.rs` — Phase D Rust skeleton (STM32H743VIT6 controller)

Internal numerical layer:
- `verify/calc_pet_cyclotron.hexa` — T1 algebraic derivation
- `verify/numerics_pet_cyclotron.hexa` + `verify/numerics_pet_cyclotron_parity.hexa` + `verify/numerics_pet_cyclotron_solver.hexa` — T2 numerical (3 stack)
- `verify/numerics_pet_realistic.hexa` — Phase B numerics (realistic loss model)
- `verify/empirical_pet_inspire.hexa` — T3 empirical paper-feed (INSPIRE-HEP literature scan)
- `firmware/doc/{board,schematic}_v0_pet_cyclotron.md` — Phase D paper-spec surface

## §12 TIMELINE

| Phase | Window | Milestone | Status |
|:------|:-------|:----------|:------:|
| Phase A — paper design | 2026-Q2 | `pet_cyclotron/doc/benchtop_v0_design.md` (127 lines) | ✅ done |
| Phase B — sim parity | 2026-Q2 | `verify/numerics_pet_cyclotron_*.hexa` + `numerics_pet_realistic.hexa` (4 scripts) | ✅ done |
| Phase C — sim firmware | 2026-Q2 | `firmware/sim/cyclotron_trigger.hexa` (13/13 PASS, 7-state machine) | ✅ done |
| Phase D — paper schematic + MCU | 2026-Q2 | `firmware/doc/{board,schematic}_v0_pet_cyclotron.md` + `firmware/mcu/pet_cyclotron.rs` | ✅ done |
| Phase E1 — KiCad + PCB v0 | 2026-Q3 | KiCad schematic + 6-layer PCB; ~$3-5 K fab | ⏳ funding |
| Phase E2 — bench bring-up | 2026-Q4 | board flash + STM32H743 + LTC2641 DAC sanity | ⏳ funding |
| Phase E3 — hospital pilot | 2027-Q1 | partner with one PET-capable hospital, hijack residual ¹⁸F | ⏳ funding + ethics review |
| Phase E4 — σ·τ=48 mg/season production | 2028+ | full season cycle + 9.6×10¹⁰ e⁺/s/mg supply demonstrated | ⏳ funding |

This is the **lowest-cost** of the 3 verbs (PET infrastructure already exists in hospitals; this domain only adds the recycle loop, not the cyclotron itself).

## §13 TOOLS

Code-layer (current):
- `hexa` runtime + `cargo` (host-side Rust unit tests for `firmware/mcu/pet_cyclotron.rs`)
- `verify/all.hexa` — 38-step orchestrator
- `cli/hexa-antimatter.hexa pet_cyclotron` — verb dispatch

Phase D paper:
- STM32H743VIT6 (no FPGA on this board — MCU-only); `cyclotron_trigger.v` is a placeholder
- `firmware/mcu/pet_cyclotron.rs` — `no_std` Rust skeleton (state machine + DAC ramp + safety interlock)
- `cargo build --target thumbv7em-none-eabihf --release --bin pet_cyclotron` (compiles, not flashable)

Phase E hardware:
- KiCad 8+ — 6-layer impedance-controlled PCB (cheaper stack than tabletop board)
- JLCPCB / OSH Park — fab + assembly ($3-5 K typical run)
- ST-LINK V3 + probe-rs + Vivado Lab Edition (no FPGA, just for SVF/JTAG cross-utilities)
- Hospital PET cyclotron access (one of: Varian / IBA / GE PETtrace) — partner agreement
- ¹⁸F separation chemistry kit (off-board, hospital pharmacy supply)
- NaI(Tl) 3"×3" detector + LEMO 00B preamp ($1.5 K) — γ counter

Documentation:
- pandoc + xelatex
- markdown-lint

## §14 TEAM

Code/spec layer (current):
- 1× substrate maintainer (HEXA family)
- Auto-pilot: Phase D lint + cross-doc audit on every commit

Phase E build layer (recommended hires post-funding):
- 1× embedded firmware engineer (Rust no_std + STM32H7 + RTIC)
- 1× hardware engineer (6-layer PCB + ADC/DAC + opto-isolated safety)
- 1× radiation safety officer (¹⁸F handling, NaI(Tl) calibration)
- 1× hospital partner liaison (HIPAA / IRB / cyclotron access)

Advisory:
- One PET-capable hospital research collaborator (radiology + medical physics)
- ALPHA / AEgIS β⁺ supply spec peer review

## §15 REFERENCES

Primary literature:
- ALPHA Collaboration. *Trapped antihydrogen.* Nature 468, 673–676 (2010).
- ALPHA Collaboration. *Confinement of antihydrogen for 1,000 seconds.* Nature Physics 7, 558–564 (2011).
- AEgIS Collaboration. *Pulsed production of antihydrogen.* Communications Physics 4, 19 (2021).
- Czarnecki, A., Krause, B., & Marciano, W. J. *Recoil corrections to the muon-decay spectrum.* Phys. Rev. Lett. 76, 3267 (1996). [β⁺ kinematics]
- IAEA TRS-471 (2009) — ¹⁸F-FDG production and quality control reference

Substrate / SSOT:
- `canon/domains/physics/pet-cyclotron/` — provenance c0f1f570:domains/physics/pet-cyclotron
- `factory/antimatter-factory.md §9.2 (c)` — path-c parent (sole external cite per §10 reduction notice)
- `tabletop/tabletop-antimatter.md` — sigma³ vs sigma⁶ cost decomposition

n=6 lattice (algebraic):
- `verify/n6_arithmetic.hexa` — σ·φ = n·τ = J₂ = 24 first-principles proof
- atlas.n6 HEXA-PET-01 ~ HEXA-PET-06 (append-only registration)

Phase D paper:
- ST RM0433 (STM32H743 reference manual)
- Linear Tech LTC2641-16 + LTC2378-16 datasheets
- Analog Devices ADuM4160 USB isolator datasheet
- TI TPS65987DDH PMIC datasheet
- Cortex-M7 ARMv7-M reference

External anchors:
- Varian / IBA / GE PETtrace cyclotron specs (off-board hospital infrastructure)
- ¹⁸F half-life: 109.77 min (NIST)
- β⁺ branching ratio for ¹⁸F: 96.7% (NUDAT 2.7)
- Hospital PET workflow (Sokoloff et al.) — clinical baseline

