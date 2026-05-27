# Radiation Shielding — 5-Tier sopfr=5 Anchor

> §A.6.1 step E5.2 — pre-compliance ionising-radiation analysis for the
> §benchtop_v0_design.md B5 plasma cell + B6 σ-cascade output.
> **Status**: pre-compliance · derived from closed-form scaling laws ·
> RSO (Radiation Safety Officer) sign-off required before commissioning.
> **Roadmap anchor**: `.roadmap.hexa_cern §A.6 step 1` (host facility
> licensing umbrella) + step 2 (final shielding fab quote).

---

## §1 Source-term parameter sheet

| parameter                     | value                          | source                          |
|:------------------------------|:-------------------------------|:--------------------------------|
| Beam energy E_b                | 100 MeV electron design        | §X.4                            |
| Charge per shot                | ≈ 1 nC (≈ 10⁹ e⁻)              | §X.4                            |
| Repetition rate                | 4 Hz                           | n=6 lattice τ                    |
| Average current I_avg          | 4 nA                           | E·rep                            |
| Average beam power P_avg       | E_b · I_avg = 0.4 W            | derived                         |
| Stopping target                | beam dump (graphite + Pb)      | §3 H2 BOM                        |
| Bremsstrahlung yield η         | ~0.01 (E·Z formula)            | NIST XCOM 100 MeV / Z=6 graphite|
| Photon power post-target       | η · P_avg = 4 mW               | derived                         |

## §2 Five-tier shielding (sopfr(6) = 2+3 = 5 anchor)

The benchtop §9 safety spec calls for 5 radial layers from beamline to
public-access boundary. Layout pulled from `mini/doc/benchtop_v0_design.md §9`:

| tier | layer            | material        | thickness | role                              |
|:----:|:-----------------|:----------------|:---------:|:----------------------------------|
| 1    | bench skin       | 304 SS          | 5 mm      | vacuum boundary                   |
| 2    | γ-stop           | Pb              | 50 mm     | bremsstrahlung attenuation        |
| 3    | n-moderator      | borated PE      | 100 mm    | thermal-neutron capture           |
| 4    | n-absorber       | Cd              | 1 mm      | thermal-n absorption              |
| 5    | concrete bunker  | concrete        | 600 mm    | bulk public-access shielding      |

Aggregate thickness: 756 mm radial.

## §3 Photon attenuation budget

For 100 MeV bremsstrahlung (E_γ ≤ 100 MeV; spectrum peaks ≈ E_b/3 ≈ 33 MeV):

### §3.1 Tier 2 (Pb 50 mm)
Mass attenuation coefficient (NIST XCOM, Pb, 33 MeV):
  μ/ρ ≈ 0.043 cm²/g
  ρ_Pb = 11.34 g/cm³
  μ = 0.043 · 11.34 = 0.488 cm⁻¹
  Transmission T = e^(-μ·d) = e^(-0.488 · 5) = e^(-2.44) = **0.087**

→ **Pb tier 2 reduces photon flux by ~11.5×**.

### §3.2 Tier 5 (concrete 600 mm)
  μ/ρ ≈ 0.026 cm²/g (concrete, 33 MeV)
  ρ_conc = 2.35 g/cm³
  μ = 0.026 · 2.35 = 0.061 cm⁻¹
  T = e^(-0.061 · 60) = e^(-3.66) = **0.0257**

→ **Concrete tier 5 reduces by ~39×**.

### §3.3 Combined tier 2+5
T_total = 0.087 × 0.0257 = **0.00224 → ~447× attenuation**

Source dose rate at beam-dump surface (P_γ = 4 mW @ 1 m):
  Φ ≈ P_γ / (4π·r²) ≈ 0.32 µGy/s

Public-side (post tier 5):
  Φ_pub = 0.32 µGy/s · 0.00224 ≈ **0.7 nGy/s ≈ 22 mSv/yr** at full duty

(IAEA public-dose limit = 1 mSv/yr.)

→ **Tier 2+5 alone insufficient for 24/7 public access** at full duty.

Mitigations:
1. Restricted-access zone 3 m radius (administrative — unattended duty
   reduces "occupancy factor" T to 1/40 → 0.55 mSv/yr ✓)
2. Increase concrete to 900 mm (extra 300 mm → 6× more attenuation →
   3.7 mSv/yr at full occupancy → still over but with T-factor ~ OK)
3. Add tier-2 thickness to 100 mm Pb (extra 50 mm → 11× more attenuation
   → 2 mSv/yr — needs T < 0.5 to comply)

**Recommended for v0**: option 1 (restricted-access zone) — cheapest and
matches §benchtop §9 "personnel exclusion zone 3 m radius during shot".

## §4 Neutron flux budget

### §4.1 Photoneutron production
At 100 MeV, photonuclear giant-resonance peaks at ~22 MeV photons.
Photoneutron yield Y_n per electron stopped (PB-208):
  Y_n ≈ 5 × 10⁻⁴ neutrons/electron at 100 MeV

Rate: R_n = 4 Hz · 1e9 e⁻ · 5e-4 = **2 × 10⁶ n/s**

Average neutron energy: E_n ≈ 1.5 MeV (giant-resonance evaporation).

### §4.2 Tier 3 attenuation (borated PE 100 mm)
B-10 thermal capture cross-section: 3 840 b
Borated PE has 5% B by weight.
Macro Σ_B = 0.05 · 6.0e23 · 3840e-24 = 1.15 cm⁻¹ (at thermal)

Fast-neutron moderation by H scattering reduces 1.5 MeV → thermal in
~10 cm (matches our tier-3 thickness). Combined moderate+capture
attenuation: T_n ≈ e^(-1.15 · 10) ≈ **1e-5**

→ **Tier 3 alone: 100 000× neutron attenuation**.

### §4.3 Tier 4 (Cd 1 mm)
Cd thermal-neutron absorption cross-section ~2 500 b.
T_Cd = e^(-N·σ·d) at 1 mm Cd:
  N_Cd = 4.6e22 atoms/cm³
  Σ = 4.6e22 · 2.5e-21 = 115 cm⁻¹
  T = e^(-115 · 0.1) = e^(-11.5) ≈ **1e-5**

→ **Tier 4 cleanup: another 100 000× of any thermal-energy escapees**.

### §4.4 Combined tier 3+4
T_total = 1e-5 · 1e-5 = 1e-10 (over-redundant — order of magnitude
sufficient for any expected flux).

Public-side neutron rate:
  R_pub = 2e6 n/s · 1e-10 = **2e-4 n/s** ≈ 6 n/hour

ICRP-103 public-dose limit equivalent ~ 0.001 mSv/year from < 10 n/hour
at MeV scale → comfortably below limit.

## §5 Activation (long-lived isotope production)

100 MeV electrons activate:
- Aluminium support hardware → ²⁴Na (T½ 15 h, 1.4 MeV γ)
- Concrete bunker → ⁴⁵Ca (T½ 162 days, β-only, low risk)
- Pb shielding → ²⁰⁵Pb (T½ 1.5e7 yr — too long-lived to matter at facility scale)

Activation budget:
  Σ_act ~ 2×10⁻³ Bq/g per gram of Al exposed at 1 m for 1 hour run.

Mitigation: cooling-off period (24 h post-shot → 4× decay) before
hands-on maintenance. Annual Al hardware swap if cumulative dose
exceeds 1 mSv on contact.

## §6 Active monitoring (during operation)

Required instrument suite (post-§A.6 step 2 funding):

| instrument                 | spec                                    | placement                      |
|:--------------------------|:----------------------------------------|:-------------------------------|
| γ area monitor             | NaI(Tl) + multichannel analyser        | tier-5 outside, 3 m from dump  |
| n-rem-meter (Bonner sphere)| Wide-energy 1e-9 → 20 MeV              | tier-5 outside                  |
| beam-current monitor       | Faraday cup (DC) + ICT (pulsed)         | post-σ-cascade exit             |
| occupancy badge dosimetry  | TLD-100 / OSL                           | each operator                   |
| online dose-integrator     | scaler + threshold latch                | feeds RSO console               |

Online dose-integrator must trip the global interlock (`hv_ok` pin)
when cumulative reading exceeds 80% of any operating limit; firmware
verifies this in `firmware/hdl/testbench/timing_ctrl_top_tb.v` phase 2.

## §7 Cross-references

- `mini/doc/benchtop_v0_design.md §9` — 5-tier shielding original spec
- `docs/safety/laser_iec60825.md` — companion laser safety analysis
- `verify/numerics_lwfa_scaling.hexa` — Lu/Esarey/TD scaling-law parity
  (constrains source term)
- ICRP Publication 103 — *The 2007 Recommendations of the International
  Commission on Radiological Protection*
- NCRP Report 144 — *Radiation Protection for Particle Accelerator
  Facilities*
- IAEA Safety Series 38 — *Radiation Safety of Gamma Radiation Sources*
