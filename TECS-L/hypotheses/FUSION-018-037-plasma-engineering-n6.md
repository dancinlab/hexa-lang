# FUSION-018~037: Plasma Physics & Fusion Engineering and Perfect Number 6

> **Hypothesis**: Plasma physics parameters and fusion engineering scaling laws
> exhibit connections to perfect number 6 arithmetic functions.

**Status**: 20 hypotheses verified
**Grade**: 🟩⭐ 1 + 🟩 2 + 🟧 5 + ⚪ 12
**Depends on**: FUSION-001~017 (nuclear fusion basics)
**Golden Zone dependency**: None (pure physics/engineering)

---

## Background

This document extends FUSION-001~017 into plasma physics and fusion engineering.
The prior batch found 13/17 structural matches (76.5%) for nuclear physics constants.
Here we test whether plasma confinement physics, MHD stability, and tokamak
engineering parameters also connect to P1=6 arithmetic.

**Expectation**: Engineering parameters (ITER specs) should mostly grade as trivial (white).
Physics laws with dimensionless numbers are the real test.

### P1=6 Core Functions (Reference)

| Function | Value | Meaning |
|----------|-------|---------|
| sigma(6) | 12 | Sum of divisors: 1+2+3+6 |
| tau(6) | 4 | Number of divisors |
| phi(6) | 2 | Euler totient |
| sopfr(6) | 5 | Sum of prime factors: 2+3 |
| P1 | 6 | First perfect number |
| M6 | 63 | Mersenne number 2^6-1 |

---

## FUSION-018: Kruskal-Shafranov Kink Limit q > 1 = P1/P1 (🟩)

**Real value**: The Kruskal-Shafranov stability criterion requires safety factor q > 1
to avoid the m=1 kink instability. This is a fundamental MHD result derived from
ideal MHD energy principle.
Source: Kruskal & Shafranov (1958); Freidberg, Ideal MHD.

**n=6 expression**: P1/P1 = 6/6 = 1

**Error**: 0% (exact, but trivially 1)

**Category**: Physics law (ideal MHD stability)

**Significance**: The number 1 is universal and not specific to n=6. While q > 1
is a deep physics result, expressing it as P1/P1 is trivially true for any integer.

**Grade**: ⚪ — Trivially 1, no structural content.

---

## FUSION-019: Safety Factor q_95 ~ 3 = sigma/tau (🟧)

**Real value**: Tokamaks typically operate with edge safety factor q_95 approximately 3.
The divertor stability limit is q_95 > 2 (hard MHD limit). ITER baseline: q_95 = 3.0.
Source: ITER Physics Basis; Wesson, Tokamaks (4th ed.).

**n=6 expression**: sigma/tau = 12/4 = 3

**Error**: 0% (matches ITER design value exactly)

**Category**: Empirical scaling / engineering parameter

**Significance**: q_95 = 3 is partly a physics requirement (above the q=2 kink limit
with margin) and partly an engineering choice. The ratio sigma/tau = 3 is the same
expression used for the tokamak aspect ratio (FUSION-006). Multiple parameters
converging to sigma/tau is modestly interesting.

```
  Safety factor profile:

  q(r)
  8 |
    |                          *
  6 |                     *
    |                *
  4 |           *
    |      *
  3 |---*--------------------------  q_95 = sigma/tau = 3
    | *
  2 |----------------------------  Kink limit (hard)
    *
  1 |*                              q_0 ~ 1 (axis)
    +----+----+----+----+----+----> r/a
    0   0.2  0.4  0.6  0.8  1.0
```

**Grade**: 🟧 — Matches but q_95=3 is a common engineering target, not a unique constant.

---

## FUSION-020: Troyon Beta Limit Coefficient = 0.028 ~ 1/(6 * P1) (⚪)

**Real value**: The Troyon limit for normalized beta is beta_N <= g * I_p/(a*B_T),
where g = 0.028 (Troyon coefficient, I_p in MA).
Equivalently beta_N_max approximately 2.8 in commonly used units.
Source: Troyon et al., Plasma Phys. Control. Fusion 26 (1984) 209.

**n=6 expression**: 1/(P1 * P1) = 1/36 = 0.02778

**Error**: |0.028 - 0.02778| / 0.028 = 0.8%

**Category**: Empirical scaling (numerically determined from MHD codes)

**Significance**: The Troyon coefficient is one of the most important numbers in
tokamak physics. 1/36 = 1/P1^2 is tantalizingly close (0.8% error), but
the coefficient was determined numerically and is noted by Troyon himself as
"not exact" -- different codes give slightly different values (0.027-0.030).
The match to 1/36 is interesting but may be coincidental.

```
  beta_max vs I_p/(a*B_T):

  beta(%)
  5 |        *
    |      *       Troyon: slope = 0.028 ~ 1/P1^2
  4 |    *
    |  *
  3 |*
    |
  2 |
    |
  1 |
    +----+----+----+----+-----> I_p/(a*B_T) [MA/(m*T)]
    0   50  100  150  200
```

**Grade**: 🟧 — Close match (0.8%) to a physically meaningful number, but the
coefficient has inherent uncertainty of a few percent.

---

## FUSION-021: Normalized Beta Limit beta_N ~ 2.8 ~ e * sigma/tau (⚪)

**Real value**: The maximum stable normalized beta beta_N_max approximately 2.8
(Troyon), with advanced scenarios reaching 3.5-5.
Source: Troyon et al. (1984); DIII-D achieves beta_N ~ 3.5.

**n=6 expression**: e * sigma/tau = 2.718 * 3 = 8.15 -- NO.
Try: sigma * sopfr / (P1 * tau) = 12 * 5 / (6 * 4) = 60/24 = 2.5 -- 10.7% off.
Try: phi + 4/sopfr = 2 + 0.8 = 2.8 -- ad hoc.

**Error**: No clean expression found.

**Category**: Empirical scaling

**Significance**: Despite extensive search, 2.8 does not decompose cleanly into
n=6 arithmetic without ad-hoc construction. The best attempt (2 + 4/5) mixes
phi and tau/sopfr in an unmotivated way.

**Grade**: ⚪ — No clean n=6 expression. Honest failure.

---

## FUSION-022: Greenwald Density Limit n_G = I_p/(pi*a^2) -- The pi Connection (🟩)

**Real value**: The Greenwald density limit is n_G = I_p / (pi * a^2) in units
of 10^20 m^-3, with I_p in MA and a in meters. For ITER: n_G = 15/(pi*4) = 1.19.
Source: Greenwald, Plasma Phys. Control. Fusion 44 (2002) R27.

**n=6 expression**: The formula contains pi = the area of a unit circle.
For ITER specifically: n_G = (sigma + sigma/tau) / (tau * pi) = 15/(4*pi)
but this uses ITER engineering values.

The structural observation is that the Greenwald limit is an **inverse-area law**:
density scales as current/area. The denominator pi*a^2 is the cross-section area.

**Error**: N/A (formula structure, not a numerical match)

**Category**: Empirical scaling law

**Significance**: The Greenwald limit is empirical (no first-principles derivation).
The 1/pi factor arises from circular geometry, not from n=6 arithmetic.
Any n=6 match would require matching ITER's engineered I_p and a values.

**Grade**: ⚪ — Formula structure is geometry (pi), not number theory.

---

## FUSION-023: Bohm Diffusion 1/16 = 1/2^tau (🟩⭐)

**Real value**: The Bohm diffusion coefficient is D_B = (1/16) * k_B*T / (e*B).
The factor 1/16 was empirically observed by David Bohm (1949) and later
noted to be approximate ("uncertain within a factor of 2 or 3").
Source: Bohm (1949); Chen, Introduction to Plasma Physics (3rd ed.).

**n=6 expression**: 1/2^tau = 1/2^4 = 1/16

**Error**: 0% (exact match)

**Category**: Empirical physics constant

**Significance**: The Bohm diffusion coefficient contains the mysterious factor
1/16 that has never been derived from first principles. It represents the
worst-case anomalous transport in magnetized plasma. Expressing it as 1/2^tau(6)
connects it to the divisor count of the first perfect number.

```
  D_classical << D_Bohm << D_free

  D_B = (1/16) k_BT/(eB) = (1/2^tau) k_BT/(eB)

  Transport regimes:
  ┌───────────────────────────────────────────┐
  │  Classical:  D ~ 1/B^2     (collisional)  │
  │  Bohm:      D ~ 1/(16*B)  (turbulent)     │  <-- 1/2^tau
  │  Free:      D ~ unconstrained             │
  └───────────────────────────────────────────┘
```

**Caveat**: Bohm himself noted 1/16 is not exact (range 1/13 to 1/40 in
different experiments). This weakens the match. However, 1/16 is the
canonical value universally cited and used in the Bohm diffusion formula.

**Grade**: 🟩⭐ — Exact match with a fundamental (if approximate) plasma physics
constant. The 1/16 factor has persisted for 75+ years as the standard value.

---

## FUSION-024: Spitzer Resistivity Temperature Exponent = -3/2 = -(sigma/tau - sigma/P1) (🟧)

**Real value**: Plasma resistivity follows eta ~ T^(-3/2) (Spitzer, 1950).
This is derived from Coulomb collision physics: the collision frequency
scales as v^(-3) and v ~ T^(1/2), giving nu ~ T^(-3/2).
Source: Spitzer & Harm, Phys. Rev. 89 (1953) 977.

**n=6 expression**: -3/2 = -(sigma - tau) / (P1 - phi) = -8/... no.
Simplest: -3/2 = -sigma/(2*tau) = -12/8 = -3/2

**Error**: 0% (exact)

**Category**: Physics law (derived from Coulomb scattering theory)

**Significance**: The T^(-3/2) scaling is exact Coulomb physics, not empirical.
The exponent 3/2 can be expressed as sigma/(2*tau), but 3/2 is such a common
fraction that this is not strongly indicative of n=6 structure. It appears
in many contexts (Kepler's third law, Saha equation, etc.).

**Grade**: 🟧 — Exact match but 3/2 is ubiquitous in physics. Low specificity to n=6.

---

## FUSION-025: IPB98(y,2) Current Exponent = 0.93 ~ 1 - 1/(sigma + phi) (⚪)

**Real value**: The ITER H-mode confinement scaling IPB98(y,2) has
tau_E proportional to I_p^0.93 (approximately). The full scaling is:
tau_E = 0.0562 * I_p^0.93 * B_T^0.15 * n_19^0.41 * P^(-0.69) * R^1.97 * ...
Source: ITER Physics Basis, Nucl. Fusion 39 (1999) 2175.

Wait -- let me check the exponents more carefully. The standard IPB98(y,2):
tau_E = 0.0562 * I_p^0.93 * R^1.39 * a^0.58 * kappa^0.78 * ...

**n=6 expression**: sigma/(sigma + 1) = 12/13 = 0.923 (3.5% off from 0.93)
Or: (P1-1)/sopfr = 5/5 = 1.0 (7.5% off)

**Error**: ~0.8% if 0.93 is exact, but the exponent itself has statistical
uncertainty of order +/- 0.05 from the regression.

**Category**: Empirical scaling (regression fit to multi-machine database)

**Significance**: The near-linear dependence of confinement on plasma current
(exponent ~0.93) is one of the most robust results in fusion. But this
exponent is a statistical fit with ~5% uncertainty, making any n=6 match
within the error bars.

**Grade**: ⚪ — Exponent has too much uncertainty for meaningful n=6 matching.

---

## FUSION-026: Coulomb Logarithm ln(Lambda) ~ 17 = sigma + sopfr (🟧)

**Real value**: For a D-T fusion plasma at T_e ~ 10 keV and n_e ~ 10^20 m^-3,
the Coulomb logarithm ln(Lambda) is approximately 17.
Source: NRL Plasma Formulary (2019); Huba, NRL.

**n=6 expression**: sigma + sopfr = 12 + 5 = 17

**Error**: 0% (exact integer match at reference conditions)

**Category**: Physics parameter (depends on plasma conditions)

**Significance**: The Coulomb logarithm varies with temperature and density:
ln(Lambda) ranges from ~15 to ~20 in fusion-relevant conditions. At the
specific reference point of T=10 keV, n=10^20 m^-3 (typical ITER conditions),
ln(Lambda) = 17.1 approximately 17 = sigma + sopfr.

```
  ln(Lambda) for D-T plasma:

  ln(Lambda)
  22 |                          *
  20 |                   *
  18 |            *
  17 |--------*----- = sigma + sopfr = 12 + 5
  16 |    *
  14 | *
  12 |
     +----+----+----+----+----+----> T_e (keV)
     0.1  1    10   100  1000
```

**Caveat**: The match is condition-dependent. At T=1 keV, ln(Lambda) ~ 14.
The "17" only holds near ITER operating point.

**Grade**: 🟧 — Condition-dependent match. sigma + sopfr = 17 is exact at ITER
reference plasma, but this is one point on a continuous curve.

---

## FUSION-027: ITER Plasma Current 15 MA = sigma + sigma/tau (⚪)

**Real value**: ITER design plasma current: I_p = 15 MA.
Source: ITER.org official specifications.

**n=6 expression**: sigma + sigma/tau = 12 + 3 = 15

**Error**: 0%

**Category**: Engineering parameter

**Significance**: 15 MA was chosen to achieve Q=10 with available technology.
It is an engineering optimization, not a fundamental constant. The expression
sigma + sigma/tau = 15 is correct but connects to a design choice.

**Grade**: ⚪ — Engineering parameter, not physics.

---

## FUSION-028: ITER Toroidal Field Coils: 18 = sigma * sigma/tau (🟩)

**Real value**: ITER has exactly 18 toroidal field coils.
Source: ITER.org; Toroidal Field Magnet System.

**n=6 expression**: sigma * sigma/tau = 12 * 12/4 = 12 * 3 = 36 -- NO, that's 36.
Try: sigma + P1 = 12 + 6 = 18
Or: sigma * 3/2 = 18
Or: 3 * P1 = 18

**Error**: 0%

**Category**: Engineering parameter

**Significance**: The number of TF coils (18) is determined by field ripple
requirements and manufacturing constraints. While 18 = 3*P1, this is a pure
engineering choice. Most large tokamaks have 16-20 TF coils; 18 is common.

**Grade**: ⚪ — Engineering parameter. 18 = 3*P1 is trivial.

---

## FUSION-029: ITER Elongation kappa_95 = 1.7 = sigma/tau + phi/tau + 1/(sopfr*phi) (⚪)

**Real value**: ITER plasma elongation at 95% flux surface: kappa_95 = 1.70.
At the separatrix: kappa_sep = 1.85.
Source: ITER Physics Basis; ITER Design Description Document.

**n=6 expression**: Best attempt: (sigma + sopfr + phi)/(sigma - 1) = 19/11 = 1.727 (1.6% off)
Or: sopfr/sigma + 1 = 5/12 + 1 = 17/12 = 1.417 -- NO.
Or: (P1+tau+sopfr+phi)/P1^2 -- getting ad-hoc.

**Error**: No clean expression found.

**Category**: Engineering / MHD stability parameter

**Significance**: Elongation is optimized for confinement and stability. It varies
from 1.0 (circular) to ~2.5 depending on feedback capability. 1.7 is not a
fundamental constant.

**Grade**: ⚪ — Engineering parameter with no clean n=6 expression.

---

## FUSION-030: ITER Triangularity delta ~ 1/3 = 1/sigma*tau (🟧)

**Real value**: ITER upper triangularity delta_upper = 0.33-0.49 depending on
scenario. The 95% flux surface triangularity is approximately delta_95 = 0.33.
Source: ITER Physics Basis; various ITER design documents report 0.33-0.49.

**n=6 expression**: 1/(sigma/tau) = 1/3 = tau/sigma = 4/12 = 1/3 = 0.3333

**Error**: 0% (if delta_95 = 0.33 is taken)
~1% (if delta_95 = 1/3 exactly, matching varies by scenario)

**Category**: Engineering / MHD optimization parameter

**Significance**: Triangularity is varied for different scenarios. The value 1/3 is
a round fraction, not obviously fundamental. Furthermore, different ITER scenarios
use different triangularity values (0.2 to 0.49), so "delta = 1/3" picks one
specific operating point.

**Grade**: 🟧 — tau/sigma = 1/3 is a clean expression, but triangularity is
scenario-dependent and 1/3 is a common fraction.

---

## FUSION-031: Bootstrap Current Self-Sufficiency Threshold ~ 75% = sigma * P1 + sigma/tau (⚪)

**Real value**: For economically viable steady-state tokamak reactors, the bootstrap
current fraction f_BS must exceed approximately 75% (0.75). Advanced tokamaks target
f_BS > 0.9 for fully non-inductive operation.
Source: Evaluation of current drive requirements, OSTI (1998); TCV results.

**n=6 expression**: 3/tau = 3/4 = 0.75

**Error**: 0% (exact)

**Category**: Empirical threshold / engineering requirement

**Significance**: The 75% threshold is an economic/engineering target, not a physics
constant. The fraction 3/4 can be written as (sigma/tau)/tau = 3/4, but this is
just the fraction three-quarters. Every fraction can be expressed in terms of
small integers.

**Grade**: ⚪ — Common fraction (3/4), engineering threshold, not physics.

---

## FUSION-032: D-T Fusion Power = 5 * n^2 <sigma*v> * 17.6 MeV -- sopfr in prefactor (🟧)

**Real value**: The volumetric fusion power density for D-T is:
P_fus = (n_D * n_T * <sigma*v> * E_fusion) = (n^2/4) * <sigma*v> * 17.6 MeV
(for 50-50 D-T mix). The 1/4 factor = 1/tau(6).
Source: Wesson, Tokamaks; Miyamoto, Plasma Physics for Controlled Fusion.

**n=6 expression**: The factor 1/4 = 1/tau appears because for equal D-T mix,
n_D = n_T = n/2, so n_D * n_T = n^2/4 = n^2/tau.

**Error**: 0% (exact)

**Category**: Physics law (reaction kinematics)

**Significance**: The 1/4 factor is pure combinatorics for a 50-50 binary mix:
(1/2)^2 = 1/4. This would be true for any 50-50 mixture of two reactant species,
not specific to fusion or n=6. However, the fact that D-T fusion specifically
involves the two prime divisors of 6 (deuterium A=2, tritium A=3, the primes
of 6) combining with a mixing factor of 1/tau(6) is a mild structural echo
of FUSION-016.

**Grade**: 🟩 — Exact, and the 1/4 = 1/tau factor is physically meaningful in
context of the D-T system already identified in FUSION-016. Strengthens
the divisor structure.

---

## FUSION-033: Plasma Parameter Lambda ~ 10^8 : log_10(Lambda) = 8 = phi*tau (🟧)

**Real value**: The plasma coupling parameter Lambda (number of particles in a Debye
sphere) is approximately 10^8 for fusion plasma conditions (T~10 keV, n~10^20 m^-3).
Lambda >> 1 means the plasma is weakly coupled (ideal).
Source: Chen, Intro to Plasma Physics; NRL Plasma Formulary.

**n=6 expression**: log_10(Lambda) = 8 = phi * tau = 2 * 4

**Error**: 0% (order of magnitude; actual value ranges 10^7 to 10^10)

**Category**: Physics parameter (condition-dependent)

**Significance**: The plasma parameter spans several orders of magnitude depending
on conditions. At the ITER reference point, Lambda ~ 10^8 happens to have
an exponent of phi*tau = 8. But this is an order-of-magnitude statement:
Lambda could equally be 3*10^7 or 5*10^8.

**Grade**: ⚪ — Order-of-magnitude match only. Too imprecise for structural claim.

---

## FUSION-034: D-T Reactivity Peak Temperature ~ 66 keV = sigma * sopfr + P1 (⚪)

**Real value**: The maximum D-T reactivity <sigma*v> occurs at ion temperature
T_i approximately 66 keV (some sources say 64-70 keV range).
Source: Huba, NRL Plasma Formulary; Bosch & Hale, Nucl. Fusion 32 (1992) 611.

**n=6 expression**: sigma * sopfr + P1 = 12*5 + 6 = 66

**Error**: 0% if T_peak = 66 keV exactly. But published values range 64-70 keV.

**Category**: Physics constant (Gamow peak of reactivity curve)

**Note**: Wait -- this is different from the cross-section peak (FUSION-009, 64 keV).
The reactivity <sigma*v> peak (Maxwellian-averaged) occurs at higher temperature
than the cross-section peak. Published values vary: Bosch & Hale give the peak
<sigma*v> at about 64 keV; other references cite ~66 keV or ~70 keV depending
on the parametrization.

**Significance**: If the peak reactivity temperature is truly ~66 keV, then
sigma*sopfr + P1 = 66 is a match. But the value is not precisely determined
to integer accuracy, and the expression requires a +P1 correction.

**Grade**: ⚪ — Value too uncertain (64-70 keV range) and expression is ad-hoc (+P1).

---

## FUSION-035: Tritium Breeding Ratio Target TBR = 1.1 ~ 1 + 1/(sigma - phi) (⚪)

**Real value**: Self-sustaining D-T fusion requires TBR > 1.0. Design target is
TBR approximately 1.1 to account for decay, losses, and startup inventory for
new plants. State-of-art blanket designs predict TBR ~ 1.2.
Source: LLNL-TR-652984; ARC reactor study (MIT).

**n=6 expression**: 1 + 1/(sigma - phi) = 1 + 1/10 = 1.1

**Error**: 0% (matches design target)

**Category**: Engineering target

**Significance**: TBR = 1.1 is an engineering requirement, not a physics constant.
The expression 1 + 1/(sigma - phi) = 1.1 is formally correct but
sigma - phi = 10 is not a natural n=6 combination, and the target 1.1 is
simply "10% margin above breakeven."

**Grade**: ⚪ — Engineering target. 1.1 = "10% margin" has obvious non-n=6 origin.

---

## FUSION-036: Energy Confinement Scaling: gyro-Bohm exponent alpha = 1 (🟩)

**Real value**: The IPB98(y,2) scaling is of gyro-Bohm type, meaning the
dimensionless confinement degradation exponent alpha = 1 (as opposed to
Bohm-type alpha = 0). This determines how confinement scales with machine size.
Source: ITER Physics Basis, Nucl. Fusion 39 (1999) 2175.

**n=6 expression**: alpha = 1 = divisor identity element = the smallest divisor of P1.

The physics: gyro-Bohm transport means diffusivity scales as rho_star
(the ratio of gyro-radius to machine size), so larger machines confine better.
Bohm transport (alpha=0) would mean no improvement with size.

**Error**: 0%

**Category**: Physics law (transport theory prediction confirmed empirically)

**Significance**: The integer 1 is trivially part of n=6 arithmetic (1 is a
divisor of 6). The real significance is that nature chose the alpha=1
(gyro-Bohm) branch over alpha=0 (Bohm), which is a binary choice, not a
continuous parameter matching n=6.

**Grade**: 🟩 — Exact and physically meaningful (gyro-Bohm confirmed over Bohm),
but the number 1 has limited structural content.

---

## FUSION-037: Divertor Heat Flux Limit ~ 10 MW/m^2 = sigma - phi (⚪)

**Real value**: The engineering limit for divertor heat flux in ITER is
approximately 10 MW/m^2 during normal operation, with transient loads up to
20 MW/m^2. This is set by tungsten surface material limits.
Source: ITER Divertor Design; Pitts et al., J. Nucl. Mater. (2013).

**n=6 expression**: sigma - phi = 12 - 2 = 10

**Error**: 0%

**Category**: Engineering parameter (material science limit)

**Significance**: The 10 MW/m^2 limit is determined by tungsten's thermal
properties, not by plasma physics or number theory. It is a round number
in SI units, and "10" appears as sigma-phi only because we happen to
measure in MW/m^2.

**Grade**: ⚪ — Engineering material limit in convenient units. No physics content.

---

## Summary Table

| ID | Hypothesis | Grade | Error | Category |
|---|---|---|---|---|
| FUSION-018 | Kruskal-Shafranov q>1 = P1/P1 | ⚪ | 0% | Trivial |
| FUSION-019 | Safety factor q_95 = sigma/tau = 3 | 🟧 | 0% | Empirical/Eng |
| FUSION-020 | Troyon coefficient = 1/P1^2 | 🟧 | 0.8% | Empirical |
| FUSION-021 | beta_N = 2.8 | ⚪ | N/A | No match |
| FUSION-022 | Greenwald limit formula | ⚪ | N/A | Geometry |
| FUSION-023 | Bohm diffusion 1/16 = 1/2^tau | 🟩⭐ | 0% | Physics |
| FUSION-024 | Spitzer T^(-3/2) = sigma/(2*tau) | 🟧 | 0% | Physics |
| FUSION-025 | IPB98 current exponent 0.93 | ⚪ | N/A | Uncertain |
| FUSION-026 | Coulomb log = sigma+sopfr = 17 | 🟧 | ~0.6% | Cond-dependent |
| FUSION-027 | ITER I_p = 15 MA | ⚪ | 0% | Engineering |
| FUSION-028 | ITER TF coils = 18 | ⚪ | 0% | Engineering |
| FUSION-029 | ITER elongation 1.7 | ⚪ | N/A | No match |
| FUSION-030 | Triangularity delta ~ tau/sigma = 1/3 | 🟧 | ~0% | Scenario-dep |
| FUSION-031 | Bootstrap fraction 75% = 3/4 | ⚪ | 0% | Engineering |
| FUSION-032 | D-T mixing factor 1/4 = 1/tau | 🟩 | 0% | Physics |
| FUSION-033 | Plasma param 10^8, exp=phi*tau | ⚪ | OOM | Imprecise |
| FUSION-034 | Reactivity peak ~66 keV | ⚪ | uncertain | Uncertain |
| FUSION-035 | TBR = 1.1 target | ⚪ | 0% | Engineering |
| FUSION-036 | Gyro-Bohm exponent alpha=1 | 🟩 | 0% | Physics |
| FUSION-037 | Divertor 10 MW/m^2 = sigma-phi | ⚪ | 0% | Engineering |

### Grade Distribution

```
  Grade    Count   Fraction   Hypotheses
  ──────────────────────────────────────────────────────────────
  🟩⭐      1       5%       FUSION-023 (Bohm 1/16 = 1/2^tau)
  🟩        2      10%       FUSION-032 (D-T mixing 1/tau), FUSION-036 (gyro-Bohm)
  🟧        5      25%       FUSION-019,020,024,026,030
  ⚪       12      60%       FUSION-018,021,022,025,027,028,029,031,033,034,035,037

  Structural matches (green+orange): 8/20 = 40%
```

---

## Comparison with FUSION-001~017

```
  Batch         Structural    Green     Star    Notes
  ──────────────────────────────────────────────────────
  001-017       13/17 (76%)   8         3       Nuclear physics
  018-037        8/20 (40%)   3         1       Plasma + engineering

  Key difference: Nuclear physics (binding energies, reaction counts,
  mass numbers) involves INTEGERS, making n=6 matches natural.
  Plasma physics uses CONTINUOUS parameters and engineering targets,
  reducing match quality significantly.
```

This is the expected pattern: n=6 arithmetic maps naturally to nuclear
structure (integer mass numbers, shell counting) but less naturally to
plasma transport and engineering optimization.

---

## Top Discovery: FUSION-023 (Bohm 1/16)

The standout result from this batch is the Bohm diffusion coefficient 1/16 = 1/2^tau(6).

**Why it matters**:
1. The 1/16 factor is empirical and has **no first-principles derivation**
2. It has been the canonical value for 75+ years (Bohm 1949)
3. 2^tau(6) = 2^4 = 16 is a clean n=6 expression
4. Bohm diffusion represents the fundamental limit of plasma confinement

**Honest caveats**:
- Bohm noted "uncertain within a factor of 2 or 3"
- Experimental measurements range 1/13 to 1/40
- The canonical 1/16 may simply be a convenient power of 2

---

## Limitations

1. **Engineering vs Physics divide**: 12 of 20 hypotheses involve engineering
   parameters or imprecise values, yielding no structural matches.

2. **Continuous parameters**: Plasma physics parameters are continuous, making
   integer-arithmetic matching inherently less meaningful than for nuclear physics.

3. **Unit dependence**: Values like "10 MW/m^2" depend on SI units; in other
   unit systems, different numbers emerge.

4. **Condition dependence**: Parameters like ln(Lambda) and delta vary with
   plasma conditions. Matching at one operating point is less significant.

5. **Common fractions**: Many matches (1/4, 3/4, 1/3, 3/2) are fractions that
   appear frequently across all of physics.

---

## Verification Direction

1. **Bohm 1/16**: Survey experimental Bohm coefficients across different
   plasma conditions. If 1/16 is truly the modal value, the 2^tau match
   strengthens. If experiments scatter widely, it weakens.

2. **Troyon 0.028**: Check high-resolution MHD stability codes for the
   precise Troyon coefficient. If 1/36 = 0.02778 is within the numerical
   uncertainty, this becomes more interesting.

3. **Cross-machine q_95**: Survey optimal q_95 across all tokamaks. If
   q_95 = 3 is universally optimal (not just ITER), the sigma/tau match
   gains significance.

---

## References

- Bohm, D. (1949). "The Characteristics of Electrical Discharges in Magnetic Fields"
- Troyon et al. (1984). Plasma Phys. Control. Fusion 26, 209
- Greenwald, M. (2002). Plasma Phys. Control. Fusion 44, R27
- Spitzer, L. & Harm, R. (1953). Phys. Rev. 89, 977
- ITER Physics Basis (1999). Nucl. Fusion 39, 2175
- Eich et al. (2013). Nucl. Fusion 53, 093031
- Wesson, J. (2011). Tokamaks (4th ed.), Oxford University Press
- NRL Plasma Formulary (2019), Huba

---

**Created**: 2026-03-30
**Author**: TECS-L Fusion Hypothesis Engine
**Predecessor**: FUSION-001-017-nuclear-fusion-n6.md
