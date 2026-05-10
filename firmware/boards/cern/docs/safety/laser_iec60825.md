# Laser Safety — IEC 60825-1 Class 4 PW-Class Fiber Laser

> §A.6.1 step E5.1 — pre-compliance assessment for the §benchtop_v0_design.md B2 laser driver.
> **Status**: pre-compliance · derived from datasheet specs · external safety engineer review required before commissioning.
> **Roadmap anchor**: `.roadmap.hexa_cern §A.6` step 1+2 (host facility decision drives jurisdictional licensing path).

---

## §1 Laser parameter sheet

| parameter            | value                       | source / lattice anchor          |
|:---------------------|:----------------------------|:---------------------------------|
| Class                | **Class 4** (IEC 60825-1)   | peak power > 0.5 W ⇒ Class 4      |
| Wavelength λ          | 800 nm                      | Ti:Sa / Yb:fiber typical          |
| Pulse energy          | 10 J                        | §X.4 + §3 BOM L1                  |
| Pulse duration τ_L   | 100 fs                      | §X.4                              |
| Peak power P_peak     | E/τ = 100 TW                | derived                           |
| Repetition rate       | 4 Hz (= τ lattice)          | §X.4 §3 D1                        |
| Average power P_avg   | E·rep = 40 W                | derived                           |
| a₀ normalised vector  | 6 (= n)                     | §X.4 + n=6 lattice                |
| Beam waist w_0        | 10 µm (Lu-matched)          | `verify/numerics_lwfa_scaling.hexa` |
| Beam divergence ½-angle | ~λ/(π·w_0) = 25 mrad       | Gaussian-beam derivation          |
| Polarization          | linear, P-axis               | matched-blowout default            |

## §2 IEC 60825-1 hazard analysis

### §2.1 MPE (Maximum Permissible Exposure) — eye

For 800 nm, 100 fs pulse, IEC 60825-1 §A.4 (skin/cornea) and §A.5 (retina):

- MPE_eye for a single 100 fs pulse @ 800 nm = **5 × 10⁻⁷ J/cm² (5 nJ/mm²)**
  - per Table A.1 of IEC 60825-1:2014 (700–1 050 nm, t < 1 ns).

For 4 Hz pulse train (10 s exposure ≤ 40 pulses), the C5 multi-pulse correction is:

  MPE_train = MPE_pulse · N^(-1/4)
            = 5e-7 · 40^(-1/4)
            ≈ 2 × 10⁻⁷ J/cm²

### §2.2 OD (Optical Density) requirement

Beam fluence at exit window (10 µm waist, 10 J pulse):

  F_exit = E / (π·w_0²) = 10 / (π · (1e-3)²) = 3.2 × 10⁶ J/cm²

Note: the 10 µm waist is at the plasma cell focus. At the exit window
(several mm downstream), the beam re-expands. We use a conservative
assumption of 1 mm² spot at any room-accessible aperture:

  F_room = E / 1e-2 cm² = 1 × 10³ J/cm²

OD required:

  OD = log₁₀(F_room / MPE_train)
     = log₁₀(1e3 / 2e-7)
     = log₁₀(5e9)
     ≈ **9.7 → round up to OD 10**

**No commercial laser-safety eyewear is rated OD 10 at 100 fs / 800 nm.**

→ Conclusion: **direct beam viewing is fundamentally not survivable**.
  Engineering controls (Class-1 enclosure during operation) are
  mandatory; PPE eyewear is a backup against scatter only.

### §2.3 NHZ (Nominal Hazard Zone)

For diffuse reflection from a Lambertian surface (worst-case retro-
scatter):

  d_NHZ = sqrt( E·ρ·cos(θ) / (π·MPE_train) )
        = sqrt( 10 J · 1.0 · 1.0 / (π · 2e-11 J/m²) )
        = sqrt( 1.59e11 )
        ≈ **400 km (formal)**

The formal NHZ exceeds any realistic laboratory; the Class-1 enclosure
collapses it to the enclosure boundary.

## §3 Engineering controls (mandatory, all must be in place)

| layer | control                                       | spec                                           |
|:-----:|:----------------------------------------------|:-----------------------------------------------|
| 1     | Class-1 enclosure (operation mode)             | full optical-tight enclosure, < 10 nW leakage  |
| 2     | Door interlock (microswitch + Schmitt + crowbar) | < 10 ms switch-to-shutter response              |
| 3     | Laser shutter (B2 → B5 inline)                 | mechanical, fail-closed, 5 ms close time       |
| 4     | Beam dump at every diagnostic port             | absorber (carbon/ceramic), > 99.99% absorption |
| 5     | Permanent warning labels (IEC 60825-1 figure 1) | door + enclosure + emission aperture           |

The door-interlock signal feeds into:
- `firmware/hdl/timing_ctrl.v` `laser_shutter_ok_i` input
- `firmware/mcu/src/interlock.rs` `InterlockOk::from_pins(.., shutter_ok)` argument

When the door-interlock drops, the trigger generator stops issuing
pulses (verified in `firmware/hdl/testbench/timing_ctrl_top_tb.v`
phase 2: "interlock-drop disables further triggers").

## §4 Administrative controls

| control                       | implementation                                     |
|:------------------------------|:---------------------------------------------------|
| Authorised personnel only      | host-facility access registry + named-user permit |
| LSO (Laser Safety Officer)     | host facility appoints; signs off SOPs              |
| Training cert. requirement     | all operators: classroom + practical eval          |
| SOP per operating mode         | one SOP per: alignment, commissioning, shot, decom  |
| Logbook                        | per-shot record incl. interlock state + LSO acknowledgement |

## §5 Personal protective equipment (PPE) — backup only

Eyewear:
- OD ≥ 10 @ 800 nm IS NOT COMMERCIALLY AVAILABLE FOR FS-PULSES.
- Use **OD 7+ "scatter-protection-only" eyewear** (e.g. Laservision
  R-AKM-CP-A1 series) marked "for scatter, NOT direct beam".
- All operators must understand: eyewear protects against diffuse
  scatter only; direct beam = blindness even with eyewear.

Skin:
- Lab coat (Nomex preferred for fire risk from beam dump)
- Closed-toe shoes (debris from beam dump)

## §6 Compliance pathway (post-§A.6 step 1 collab decision)

| jurisdiction       | regulator                          | filing path                          |
|:-------------------|:------------------------------------|:-------------------------------------|
| EU (DESY, CERN)     | local Health & Safety + EU CE       | DSGVO + Maschinenrichtlinie + IEC 60825-1 self-cert |
| US (SLAC, FACET)    | OSHA + ANSI Z136.1 + FDA CDRH 21 CFR 1040 | IDE filing if used for human-adjacent applications  |
| Japan (KEK)         | JIS C 6802 + 労安法 + 電波法            | JIS C 6802 self-cert + 安衛法届出      |
| Korea (PAL-XFEL)    | KOSHA + KS C IEC 60825-1            | KOSHA-C-2-2010 + KS self-cert         |

The exact filing burden depends on §A.6 step 1 host. None of the four
candidate hosts requires Class-4-laser certification beyond what this
document outlines — they all have existing in-house laser safety
infrastructure that the new bench inherits.

## §7 Pre-compliance to-do (deferred)

These must be addressed before first-photon, but cannot be done
in-repo:

- [ ] LSO appointment (depends on host facility)
- [ ] Calibrated power meter for emission verification (Coherent FieldMaxII)
- [ ] Laser-warning-light wiring to room-entrance interlock
- [ ] Emergency stop button (red mushroom, latching, 1-meter from operator)
- [ ] Fire-suppression system review (FS-pulse → ablation plume → HEPA filter)
- [ ] Radiation-protection officer joint sign-off (combined hazard with §radiation_shielding.md)

## §8 Cross-references

- `mini/doc/benchtop_v0_design.md §9` — 5-tier shielding spec
- `firmware/hdl/timing_ctrl.v` — `laser_shutter_ok_i` interlock GPIO
- `firmware/hdl/timing_ctrl_top_tb.v` — phase-2 interlock-gating regression
- `firmware/mcu/src/interlock.rs` — `InterlockOk` typestate construction
- `docs/safety/radiation_shielding.md` — companion ionising-radiation analysis
- IEC 60825-1:2014 *Safety of laser products – Part 1: Equipment classification and requirements*
