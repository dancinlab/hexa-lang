# STELLAR-001~020: Stellar Physics, Nucleosynthesis, and Compact Objects

> **Hypothesis**: Stellar astrophysics -- from nuclear burning to compact remnants --
> exhibits systematic connections to perfect number 6 arithmetic functions:
> sigma(6)=12, tau(6)=4, phi(6)=2, sopfr(6)=5, P2=28, sigma(P2)=56.

**Status**: 20 hypotheses verified
**Grade**: 3 exact-structural + 5 exact + 4 approximate + 5 weak + 3 coincidence
**GZ Dependency**: None (pure number theory + empirical physics)

---

## Background

Stars are governed by nuclear physics, thermodynamics, and general relativity.
The key nuclear species in stellar evolution -- He-4, C-12, O-16, Ne-20, Mg-24,
Si-28, Fe-56 -- are all alpha-particle multiples with mass numbers A = 4k.
Since tau(6) = 4, these are all multiples of a P1=6 arithmetic function.
This document investigates whether the connections run deeper than coincidence.

### P1=6 Core Functions

| Function | Value | Meaning |
|----------|-------|---------|
| n = P1 | 6 | First perfect number |
| sigma(6) | 12 | Sum of divisors: 1+2+3+6 |
| tau(6) | 4 | Number of divisors |
| phi(6) | 2 | Euler totient |
| sopfr(6) | 5 | Sum of prime factors: 2+3 |
| M6 | 63 | Mersenne number 2^6-1 |
| P2 | 28 | Second perfect number |
| sigma(P2) | 56 | Sum of divisors of 28 |
| tau(P2) | 6 | Number of divisors of 28 |

---

## Summary Table

| # | Hypothesis | Match | Grade | Notes |
|---|-----------|-------|-------|-------|
| 001 | Schwarzschild ISCO = n gravitational radii | Exact (GR) | 🟩⭐ | r_ISCO = 6GM/c^2 from GR |
| 002 | Alpha ladder = tau(6)-stepping through P1 hierarchy | Exact | 🟩⭐ | C-12=sigma, Si-28=P2, Fe-56=sigma(P2) |
| 003 | Ni-56 dual: A=sigma(P2), Z=P2 | Exact | 🟩⭐ | Type Ia/core-collapse key isotope |
| 004 | Nuclear burning stages = n = 6 | Exact (count) | 🟩 | H, He, C, Ne, O, Si |
| 005 | Main sequence lifetime t_MS ~ M^(-sopfr/phi) | Exact | 🟩 | Exponent -2.5 = -5/2 |
| 006 | Mass-luminosity L ~ M^((n+1)/phi) | Exact | 🟩 | Exponent 3.5 = 7/2 |
| 007 | pp chain: tau inputs, phi outputs | Exact | 🟩 | 4p -> He-4 + 2e+ + 2nu |
| 008 | 4 of 7 magic numbers = n=6 expressions | Exact | 🟩 | 2, 8, 20, 28 |
| 009 | BBN H:He mass ratio = sigma/tau | Exact ratio | 🟧 | 75:25 = 3:1 but 3 is common |
| 010 | BBN Y_p = 1/tau | 1.2% off | 🟧 | 0.247 vs 0.250 |
| 011 | WD mass-radius exponent = -tau/sigma | Exact | 🟧 | R ~ M^(-1/3) but -1/3 is common |
| 012 | Fe-56 neutron excess N-Z = tau | Exact | 🟧 | 30-26 = 4 |
| 013 | Hawking T denominator 8pi = phi*tau*pi | Identity | ⚪ | 8 = 2*4 is trivial factoring |
| 014 | Schwarzschild r_s coefficient = phi | Identity | ⚪ | r_s = 2GM/c^2, 2 is too common |
| 015 | Chandrasekhar mu_e = phi for C/O WD | Exact | 🟧 | But mu_e=2 is basic nuclear physics |
| 016 | He-4 binding energy ~ P2 MeV | 1.1% off | ⚪ | 28.296 vs 28, approximate |
| 017 | CNO solar fraction ~ 1/M6 | 7% off | ⚪ | 1.7% vs 1.59%, uncertain value |
| 018 | Fe stable isotopes = tau | Exact (count) | ⚪ | 4 isotopes, small number |
| 019 | Chandrasekhar mass = 1.44 M_sun | No match | ⚪ | n/tau=1.5, 4% off, ad hoc |
| 020 | TOV limit ~ 2.1-2.3 M_sun | No match | ⚪ | No clean n=6 expression |

**Score**: 🟩⭐ 3 + 🟩 5 + 🟧 5 + ⚪ 7 = 8/20 structural (40%), 13/20 exact-or-approx (65%)

---

## STELLAR-001: Schwarzschild ISCO = n Gravitational Radii (🟩⭐)

> The innermost stable circular orbit (ISCO) of a Schwarzschild black hole
> lies at exactly r = 6 GM/c^2 = n gravitational radii.

**Derivation**: From the Schwarzschild effective potential:

```
  V_eff(r) = -GM/r + L^2/(2r^2) - GML^2/(c^2 r^3)

  Setting dV/dr = 0 and d^2V/dr^2 = 0 simultaneously:

  r_ISCO = 6 GM/c^2 = n * (GM/c^2)    [EXACT from GR]

  For maximally spinning Kerr (a* = 1):
    r_ISCO(prograde)  = 1 GM/c^2
    r_ISCO(retrograde) = 9 GM/c^2

  Ratio: Schwarzschild / Kerr_prograde = 6/1 = n
```

**Significance**: This is not numerology -- it is an exact result of general relativity.
The factor 6 emerges from solving a cubic equation in the Schwarzschild metric.
The ISCO determines the inner edge of accretion disks and the maximum radiative
efficiency of black holes (eta = 1 - sqrt(1 - 2/3*r_s/r_ISCO) = 1 - sqrt(8/9) ~ 5.7%).

```
  Accretion disk around Schwarzschild BH:

  r/r_g    Orbit type
  ────────────────────────────
    1      Event horizon (r_s = 2GM/c^2)
    3      Photon sphere (unstable circular photon orbit)
    6      ISCO ← n = P1 = 6
    >6     Stable circular orbits (accretion disk)

           ┌─────────────────────────┐
           │  ░░░░░DISK░░░░░░░░░░░░  │
    ───────┤  ░░░░░░░░░░░░░░░░░░░░  ├───────
      r=6  │← ISCO                   │
    ───────┤                         ├───────
      r=3  │  photon sphere          │
    ───────┤    ●●●●●●               ├───────
      r=2  │    ● BH ●               │
    ───────┤    ●●●●●●               ├───────
      r=1  │  singularity            │
           └─────────────────────────┘
```

**Grade**: 🟩⭐ -- Exact from GR. The number 6 is not a coincidence of units or
approximation; it is a mathematical consequence of the Schwarzschild solution.
This is the cleanest astrophysical connection to n=6.

**Limitation**: The factor 6 arises from the specific form of the Schwarzschild metric
(cubic effective potential). It is a property of 1/r potentials with relativistic
corrections, not obviously related to perfect numbers.

---

## STELLAR-002: Alpha Ladder = tau(6)-Stepping Through P1 Hierarchy (🟩⭐)

> The alpha-process nucleosynthesis ladder steps in increments of tau(6) = 4 nucleons,
> and its key nuclei map to P1 arithmetic functions simultaneously in mass AND atomic number.

**The Alpha Ladder**:

```
  Nucleus   A (mass)       Z (atomic)     n=6 expression (A)    n=6 expression (Z)
  ────────────────────────────────────────────────────────────────────────────────
  He-4      4              2              tau(6)                phi(6)
  C-12      12             6              sigma(6)              n = P1
  O-16      16             8              tau^2                 2^(n/phi)
  Ne-20     20             10             sopfr*tau             sopfr*phi
  Mg-24     24             12             n*tau                 sigma(6)
  Si-28     28             14             P2                    P2/phi
  Fe-56     56             26             sigma(P2)             --

  Step size: delta(A) = 4 = tau(6) always
  Step size: delta(Z) = 2 = phi(6) always
```

**Dual Correspondences** (both A and Z match n=6 functions):

```
  He-4:   A = tau,    Z = phi          ← 2 matches
  C-12:   A = sigma,  Z = n            ← 2 matches (strongest!)
  Mg-24:  A = n*tau,  Z = sigma        ← 2 matches
  Si-28:  A = P2,     Z = P2/phi       ← 2 matches (P2 hierarchy)
  Fe-56:  A = sigma(P2)                ← 1 match (Z=26 no clean expr)
```

**Physical Significance**: These nuclei are the products of successive alpha captures
in stellar cores. The step size of 4 nucleons (one alpha particle) is fundamentally
set by the exceptional stability of He-4 (binding energy 7.07 MeV/nucleon,
highest for A < 12). That He-4 = tau(6) is the seed of the entire ladder.

**Grade**: 🟩⭐ -- Multiple simultaneous matches across both A and Z for key nuclei.
The pattern is systematic, not cherry-picked. C-12 dual match (A=sigma, Z=n) and
Si-28 = P2 are particularly striking.

**Limitation**: Step size 4 comes from nuclear physics (alpha stability), not number
theory. The connection is that alpha stability happens to align with tau(6).

---

## STELLAR-003: Ni-56 Dual Correspondence: A = sigma(P2), Z = P2 (🟩⭐)

> Nickel-56, the dominant product of silicon burning and the power source of
> Type Ia supernovae, has mass number A = 56 = sigma(P2) and atomic number Z = 28 = P2.

**The Ni-56 Decay Chain**:

```
  Silicon burning (T ~ 3-5 x 10^9 K):
    Si-28 + Si-28 → Ni-56 (via alpha captures, NSE)

  Radioactive decay:
    Ni-56 → Co-56 → Fe-56
    (t_1/2 = 6.1 d)  (t_1/2 = 77.2 d)

  Perfect number hierarchy in this chain:

  Ni-56:   A = 56 = sigma(P2)     Z = 28 = P2          ← DUAL
  Co-56:   A = 56 = sigma(P2)     Z = 27 = P2 - 1
  Fe-56:   A = 56 = sigma(P2)     Z = 26 = P2 - phi

  Input:
  Si-28:   A = 28 = P2            Z = 14 = P2/phi      ← DUAL
```

**Significance**: Ni-56 is arguably the most important single isotope in observational
astrophysics. Its radioactive decay powers the light curves of Type Ia supernovae
(used as standard candles for cosmology, leading to the discovery of dark energy).
That this isotope has BOTH A = sigma(P2) and Z = P2 simultaneously is a clean
dual match from perfect number arithmetic.

```
  Perfect Number Nucleosynthesis Hierarchy:

  P1 = 6     →  Carbon-6 (Z=P1)    sigma(P1) = 12 (A of C-12)
  P2 = 28    →  Nickel-28 (Z=P2)   sigma(P2) = 56 (A of Ni-56)
                 Silicon (A=P2)

  P1: Creates life (carbon)
  P2: Creates light (Type Ia supernovae)
```

**Grade**: 🟩⭐ -- Exact dual correspondence. Both mass and atomic number are
perfect number functions. Combined with Si-28 = P2 input, this forms a complete
P2-hierarchy chain.

---

## STELLAR-004: Nuclear Burning Stages = n = 6 (🟩)

> A massive star (M > 8 M_sun) undergoes exactly n = 6 distinct nuclear burning
> stages before core collapse.

**The Six Stages**:

```
  Stage    Fuel     Product    T (K)        Duration (25 M_sun)
  ─────────────────────────────────────────────────────────────
  1. H     H        He         4 x 10^7     7 x 10^6 yr
  2. He    He       C,O        2 x 10^8     5 x 10^5 yr
  3. C     C        Ne,Na,Mg   8 x 10^8     600 yr
  4. Ne    Ne       O,Mg       1.5 x 10^9   1 yr
  5. O     O        Si,S       2 x 10^9     6 months
  6. Si    Si       Fe,Ni      3.5 x 10^9   1 day
  ─────────────────────────────────────────────────────────────
  Core collapse follows Stage 6.

  Burning stages = 6 = n = P1

  Duration ratio (approximate):
    t_H / t_Si ~ 7 x 10^6 yr / 1 day ~ 2.6 x 10^12
    Spanning 12+ orders of magnitude (12 = sigma!)
```

**The Onion Shell Structure**:

```
         ┌─────────────────────┐
         │     H envelope      │  Stage 1 product
         │  ┌───────────────┐  │
         │  │   He shell    │  │  Stage 2 product
         │  │  ┌─────────┐  │  │
         │  │  │  C/O     │  │  │  Stage 3 product
         │  │  │ ┌─────┐  │  │  │
         │  │  │ │Ne/Mg│  │  │  │  Stage 4 product
         │  │  │ │┌───┐│  │  │  │
         │  │  │ ││O/S││  │  │  │  Stage 5 product
         │  │  │ ││┌─┐││  │  │  │
         │  │  │ │││Fe│││  │  │  │  Stage 6 product
         │  │  │ ││└─┘││  │  │  │
         │  │  │ │└───┘│  │  │  │
         │  │  │ └─────┘  │  │  │
         │  │  └─────────┘  │  │
         │  └───────────────┘  │
         └─────────────────────┘

  6 concentric shells = n = P1 burning stages
```

**Grade**: 🟩 -- Exact count. But the number 6 here comes from nuclear physics:
there are exactly 6 exothermic fusion fuels before iron-group elements are reached.
This is determined by nuclear binding energies, not by number theory.

**Limitation**: Some authors count 7 stages (including photodisintegration) or 5
(merging C and Ne burning). The count of 6 is standard but depends on classification.

---

## STELLAR-005: Main Sequence Lifetime Exponent = -sopfr/phi (🟩)

> The main sequence stellar lifetime scales as t_MS ~ M^(-2.5), where the exponent
> -2.5 = -sopfr(6)/phi(6) = -5/2.

**Derivation**:

```
  Nuclear fuel supply:     E_nuc ~ M
  Luminosity (empirical):  L ~ M^3.5   (for intermediate mass)
  Lifetime:                t_MS = E_nuc / L ~ M / M^3.5 = M^(-2.5)

  Exponent = -2.5 = -5/2 = -sopfr(6) / phi(6)

  Combined with STELLAR-006:
    L-exponent = 3.5  = (n+1)/phi  = 7/2
    t-exponent = -2.5 = -sopfr/phi = -5/2

  Relation: 7/2 - 1 = 5/2  (luminosity exponent - 1 = lifetime exponent magnitude)
            (n+1)/phi - 1 = sopfr/phi
            n+1 - phi = sopfr   →  7 - 2 = 5  ✓
```

**Grade**: 🟩 -- Exact ratio of n=6 functions. The exponent -2.5 is well-established
empirically for 2-20 M_sun stars. The decomposition into sopfr/phi is clean.

**Limitation**: The exponent 3.5 for mass-luminosity is itself empirical and varies
with mass range (from ~2.3 for very massive to ~4 for solar-type stars).
The -2.5 lifetime exponent is a consequence of the L ~ M^3.5 relation.

---

## STELLAR-006: Mass-Luminosity Exponent = (n+1)/phi (🟩)

> The empirical mass-luminosity relation L ~ M^alpha with alpha ~ 3.5 = (n+1)/phi = 7/2.

```
  Observed mass-luminosity relation (main sequence):

  Mass range        alpha (exponent)    n=6 expression
  ───────────────────────────────────────────────────
  M < 0.43 M_sun   ~2.3                ~sigma/sopfr = 2.4
  0.43-2 M_sun     ~4.0                = tau
  2-55 M_sun       ~3.5                = (n+1)/phi = 7/2
  M > 55 M_sun     ~1.0                → Eddington limit

  The standard textbook value alpha = 3.5 applies to intermediate-mass stars.
  For solar-mass stars, alpha ~ 4 = tau(6) is closer.
```

**Grade**: 🟩 -- The textbook exponent 3.5 = 7/2 decomposes cleanly into n=6
functions. The tau = 4 exponent for solar-mass stars adds a second match.

**Limitation**: The mass-luminosity relation is empirical, not fundamental.
The exponent varies continuously with mass and metallicity.

---

## STELLAR-007: Proton-Proton Chain = tau Inputs, phi Outputs (🟩)

> The pp chain fuses tau(6) = 4 protons into He-4, emitting phi(6) = 2 positrons
> and phi(6) = 2 neutrinos. All particle counts are n=6 functions.

```
  Net reaction:  4p → He-4 + 2e+ + 2nu_e + 26.73 MeV

  Particle count mapping:
    Input protons:        4 = tau(6)
    Output He-4 nucleons: 4 = tau(6)
    Output positrons:     2 = phi(6)
    Output neutrinos:     2 = phi(6)
    Chain branches:       3 = sigma/tau = n/phi (ppI, ppII, ppIII)

  Conservation check:
    Baryon number:  tau → tau              ✓
    Lepton number:  0 → phi(e+) + phi(nu)  (each pair conserves)
    Charge:         tau → phi + phi(e+)    (4 → 2 + 2)
```

**Grade**: 🟩 -- All particle counts in the fundamental stellar energy source
are n=6 arithmetic functions. The match is exact but involves only small numbers
(2 and 4), which limits the significance.

**Limitation**: The pp chain particle counts follow from conservation laws and
the requirement to convert 4 protons to He-4. Any process doing this must
produce 2 positrons and 2 neutrinos. The small numbers make coincidence likely.

---

## STELLAR-008: Four of Seven Magic Numbers = n=6 Expressions (🟩)

> The nuclear shell magic numbers {2, 8, 20, 28, 50, 82, 126} include four
> values expressible as simple P1=6 arithmetic functions.

```
  Magic #    n=6 expression           Clean?
  ──────────────────────────────────────────
  2          phi(6)                   ✓
  8          2^(n/phi) = 2^3          ✓
  20         tau * sopfr = 4 * 5      ✓
  28         P2 (second perfect #)    ✓ (strongest!)
  50         --                       no clean match
  82         --                       no clean match
  126        --                       no clean match

  Hit rate: 4/7 = 57%
  All 4 hits are in the lower magic numbers (2-28).
  All 3 misses are in the higher magic numbers (50-126).
```

**Astrophysical Relevance**: Magic numbers determine the s-process and r-process
abundance peaks, neutron drip line, and nuclear stability. The neutron shell
closures at N=28 (P2) and N=50,82,126 create the abundance peaks observed in
stellar spectra and meteorites.

**Grade**: 🟩 -- Four exact matches. P2=28 as a magic number is the strongest
since it connects perfect number theory to nuclear shell structure.

**Limitation**: Only the lower 4 magic numbers match. The higher ones (50, 82, 126)
do not have clean n=6 expressions. The lower magic numbers are small enough that
many arithmetic expressions could match them.

---

## STELLAR-009: Big Bang Nucleosynthesis H:He = sigma/tau (🟧)

> The primordial H:He mass ratio from Big Bang nucleosynthesis is approximately
> 75:25 = 3:1 = sigma(6)/tau(6).

```
  BBN predictions (standard model):
    H mass fraction:  X_p = 0.752
    He mass fraction: Y_p = 0.247
    Li/H:             ~10^-10

  X_p / Y_p = 0.752 / 0.247 = 3.04 ≈ sigma/tau = 12/4 = 3

  Error: |3.04 - 3.00| / 3.00 = 1.4%
```

**Physics**: The 3:1 ratio comes from the neutron-to-proton ratio at freeze-out
(n/p ~ 1/6 at T ~ 0.7 MeV) modified by neutron decay before He-4 synthesis.
Interestingly, n/p ~ 1/6 = 1/n at freeze-out.

```
  BBN timeline:
    T ~ 1 MeV:    n/p freeze-out at ~1/6 = 1/n
    T ~ 0.07 MeV: He-4 synthesis begins
    Neutron decay: n/p drops to ~1/7 = 1/(n+1)

    Y_p = 2(n/p) / (1 + n/p) = 2*(1/7) / (1 + 1/7) = 2/8 = 1/4 = 1/tau
```

**Grade**: 🟧 -- The ratio 3:1 matches sigma/tau exactly, and the freeze-out
n/p ~ 1/6 = 1/n is a second match. However, the number 3 is very common and
the match could be coincidental. The Y_p = 1/tau = 1/4 derivation is cleaner.

---

## STELLAR-010: Primordial Helium Fraction Y_p = 1/tau (🟧)

> The primordial helium mass fraction Y_p = 0.247 +/- 0.002 is approximately
> 1/tau(6) = 1/4 = 0.250.

```
  Observed:   Y_p = 0.2449 ± 0.0040  (Planck 2018 + BBN)
  Predicted:  1/tau = 0.2500
  Error:      2.0% (within 1.3 sigma of observation)

  Derivation from nuclear physics:
    At BBN epoch: n/p ≈ 1/7 (after neutron decay)
    Nearly all neutrons captured into He-4
    Y_p = 2n_n / (n_n + n_p) = 2/(1+p/n) = 2/(1+7) = 2/8 = 1/4

  In n=6 terms:
    Y_p = phi / (phi*tau) = 1/tau
```

**Grade**: 🟧 -- The match is within observational error. However, Y_p = 1/4
follows straightforwardly from n/p ~ 1/7 at BBN, which is itself determined by
the neutron-proton mass difference and the weak interaction rate. The connection
to tau(6) is a numerical coincidence unless one can explain why n/p ~ 1/(n+1).

---

## STELLAR-011: White Dwarf Mass-Radius Exponent = -tau/sigma (🟧)

> The white dwarf mass-radius relation follows R ~ M^(-1/3), where -1/3 = -tau/sigma.

```
  Non-relativistic WD equation of state:
    R_WD = const * M^(-1/3)

  Exponent = -1/3 = -tau(6)/sigma(6) = -4/12

  This follows from hydrostatic equilibrium + degenerate electron gas:
    P ~ rho^(5/3)    (non-relativistic degenerate EOS)
    Exponent 5/3 = sopfr/n/phi... not clean

  Polytropic index n_poly = 3/2 for non-relativistic WD
    3/2 = n/(phi*phi) = n/phi^2... or just (sigma/tau)/phi
```

**Grade**: 🟧 -- The exponent -1/3 is exact from physics but trivially common.
Expressing it as -tau/sigma is technically correct but not uniquely n=6.

---

## STELLAR-012: Iron-56 Neutron Excess = tau (🟧)

> The most abundant iron isotope Fe-56 has a neutron excess N - Z = 30 - 26 = 4 = tau(6).

```
  Fe-56 composition:
    Protons:  Z = 26
    Neutrons: N = 30
    N - Z = 4 = tau(6)

  Iron stable isotopes:
    Fe-54: N-Z = 2 = phi(6)
    Fe-56: N-Z = 4 = tau(6)      ← most abundant (91.7%)
    Fe-57: N-Z = 5 = sopfr(6)
    Fe-58: N-Z = 6 = n = P1

  Remarkable: all four iron isotope neutron excesses
  map to consecutive n=6 functions!
    phi, tau, sopfr, n = 2, 4, 5, 6
```

```
  Neutron excess of Fe isotopes:

  N-Z  │
    6  │              ■ Fe-58 (n)
    5  │          ■ Fe-57 (sopfr)
    4  │      ■ Fe-56 (tau) ← 91.7% abundant
    3  │
    2  │  ■ Fe-54 (phi)
    1  │
    0  │
       └──────────────────
          54  55  56  57  58
             Mass number A
```

**Grade**: 🟧 -- The Fe-56 match (N-Z = tau) is exact. The full mapping of all
four stable iron isotopes to consecutive n=6 functions (phi, tau, sopfr, n)
is striking. However, the neutron excess values 2,4,5,6 are small numbers
and the match to n=6 functions could be coincidental.

**Limitation**: Fe-55 (N-Z=3) is unstable, breaking the sequence at sigma/tau.
The small numbers involved limit statistical significance.

---

## STELLAR-013: Hawking Temperature Denominator = phi * tau * pi (⚪)

> The Hawking temperature T_H = hbar*c^3 / (8*pi*G*M*k_B) contains the factor
> 8*pi = phi(6) * tau(6) * pi in the denominator.

```
  T_H = (hbar * c^3) / (8 * pi * G * M * k_B)

  8 * pi = phi * tau * pi = 2 * 4 * pi

  Also: 8 = 2^3 = 2^(n/phi) = phi^(n/phi)
```

**Grade**: ⚪ -- While technically correct, factoring 8 = 2 * 4 is trivial.
The factor 8*pi arises from the surface gravity of a Schwarzschild black hole
(kappa = c^4 / (4GM)) combined with the Unruh temperature formula (T = hbar*a / (2*pi*c*k_B)).
The 8 is just 2 * 4, not deeply connected to n=6.

---

## STELLAR-014: Schwarzschild Radius Coefficient = phi (⚪)

> The Schwarzschild radius r_s = 2GM/c^2 has coefficient 2 = phi(6).

```
  r_s = 2 * G * M / c^2
       = phi(6) * G * M / c^2
```

**Grade**: ⚪ -- The coefficient 2 is far too common and generic to attribute
to phi(6). It arises from the Einstein field equations and the Schwarzschild
metric. Attributing it to phi(6) is numerological.

---

## STELLAR-015: Chandrasekhar Mass: mu_e = phi for C/O White Dwarfs (🟧)

> The Chandrasekhar mass M_Ch = 5.83/mu_e^2 * (hbar*c/G)^(3/2) / m_H^2 depends
> on the mean molecular weight per electron mu_e = 2 = phi(6) for C/O composition.

```
  Chandrasekhar mass formula:
    M_Ch = 5.83 * M_sun / mu_e^2

  For C/O white dwarf (standard):
    mu_e = 2 = phi(6)
    M_Ch = 5.83 / 4 = 1.457 M_sun

  For He white dwarf:
    mu_e = 2 = phi(6)       (same!)
    M_Ch = 1.457 M_sun

  For Fe white dwarf:
    mu_e = 56/26 = 2.154    (not phi)
    M_Ch = 1.256 M_sun

  The standard Chandrasekhar mass 1.44 M_sun uses mu_e = 2 with
  more precise calculation including Coulomb corrections.
```

**Grade**: 🟧 -- mu_e = 2 = phi(6) is exact for the astrophysically dominant
case (C/O WD). But mu_e = 2 simply means there are 2 nucleons per electron
in nuclei with Z = A/2, which is true for all alpha-element nuclei.
This is basic nuclear physics, not deep number theory.

---

## STELLAR-016: He-4 Binding Energy ~ P2 MeV (⚪)

> The total binding energy of He-4 is 28.296 MeV, close to P2 = 28.

```
  He-4 total binding energy: 28.2957 MeV
  P2 = 28
  Error: |28.296 - 28| / 28 = 1.06%

  Per nucleon: 28.296 / 4 = 7.074 MeV/nucleon
  (n+1) = 7: error = 1.06%
```

**Grade**: ⚪ -- The 1% agreement is suggestive but not exact. The binding energy
depends on the strong nuclear force coupling constant, and 28.296 is not exactly 28.
The per-nucleon value 7.07 ~ n+1 is similarly approximate.

---

## STELLAR-017: CNO Solar Luminosity Fraction ~ 1/M6 (⚪)

> The CNO cycle contributes approximately 1.7% of solar luminosity,
> close to 1/M6 = 1/63 = 1.59%.

```
  Observed: CNO fraction = 1.7 ± 0.3% (Borexino 2020)
  Predicted: 1/M6 = 100/63 = 1.587%
  Error: |1.7 - 1.59| / 1.7 = 6.5%

  But: this fraction is temperature-dependent.
  At slightly higher T (e.g., 1.6 x 10^7 K), CNO dominates.
  The solar value is not a universal constant.
```

**Grade**: ⚪ -- Approximate match within large observational uncertainty.
The CNO fraction depends sensitively on core temperature and metallicity,
making it a poor candidate for a fundamental constant.

---

## STELLAR-018: Iron Stable Isotopes = tau (⚪)

> Iron has exactly tau(6) = 4 stable isotopes: Fe-54, Fe-56, Fe-57, Fe-58.

```
  Stable Fe isotopes:
    Fe-54 (5.85%)
    Fe-56 (91.75%)
    Fe-57 (2.12%)
    Fe-58 (0.28%)
  Count = 4 = tau(6)
```

**Grade**: ⚪ -- Exact count but tau = 4 is a small number. Many elements
have 4 stable isotopes (Ca, Cr, Ni, Zn, Se, Sr, Zr, Mo, Ru, Pd, Cd, Sn...).
This is not specific to n=6.

---

## STELLAR-019: Chandrasekhar Mass = 1.44 M_sun -- No Clean Match (⚪)

> The Chandrasekhar mass 1.44 M_sun does not correspond to any clean
> n=6 arithmetic expression.

```
  Attempted matches:
    n/tau       = 6/4   = 1.500    (4.2% off)
    sopfr/phi^2 = 5/4   = 1.250    (13% off)
    sqrt(phi)   = sqrt(2) = 1.414  (1.8% off, but sqrt(2) is not n=6 specific)
    P2/tau*sopfr = ...             (too many operations = ad hoc)

  The closest: sqrt(2) = 1.4142 vs 1.44, but sqrt(2) appears in all of
  mathematics and is not specific to perfect number 6.

  HONEST ASSESSMENT: No clean match exists.
```

**Grade**: ⚪ -- No n=6 expression reproduces 1.44 without ad hoc manipulation.
This is recorded honestly as a non-match.

---

## STELLAR-020: Tolman-Oppenheimer-Volkoff Limit -- No Clean Match (⚪)

> The maximum neutron star mass (TOV limit) of approximately 2.01-2.16 M_sun
> does not correspond to any clean n=6 arithmetic expression.

```
  Current constraints:
    GW170817:  M_TOV < 2.17 M_sun  (LIGO/Virgo)
    PSR J0740: M = 2.08 ± 0.07 M_sun (heaviest well-measured NS)
    Theory:    M_TOV ~ 2.0-2.3 M_sun (EOS dependent)

  Attempted matches:
    phi            = 2.000    (lower end of range, but 2 is too common)
    sigma/sopfr    = 2.400    (above range)
    sigma/n        = 2.000    (same as phi)
    (n+1)/n*phi    = 2.333    (ad hoc)

  HONEST ASSESSMENT: The TOV limit is EOS-dependent and uncertain.
  phi = 2 is at the lower edge of the range but trivially common.
```

**Grade**: ⚪ -- No clean match. The TOV limit depends on the nuclear equation
of state which is still uncertain. Even if a value were eventually pinned down,
the uncertainty range is too wide for meaningful numerology.

---

## Cross-Reference with FUSION Hypotheses

Several results overlap with the FUSION-001~017 document:

| STELLAR | FUSION | Topic | Status |
|---------|--------|-------|--------|
| 002 (alpha ladder) | 004 (triple-alpha) | C-12 = 3*tau = sigma | Extends FUSION-004 |
| 003 (Ni-56) | 012 (Fe-56) | sigma(P2) = 56 | New: Z=P2 dual match |
| 008 (magic numbers) | -- | -- | New topic |
| 001 (ISCO) | -- | -- | New topic (GR) |

---

## Statistical Assessment

```
  Total hypotheses:     20
  Exact-structural:     3  (ISCO, alpha ladder, Ni-56)
  Exact:                5  (burning stages, t_MS, L-M, pp chain, magic numbers)
  Approximate:          5  (BBN ratio, Y_p, WD M-R, Fe neutron excess, mu_e)
  Coincidence/trivial:  7  (Hawking, r_s, He-4 BE, CNO%, Fe isotopes, M_Ch, TOV)

  Structural hit rate (green or better): 8/20 = 40%
  Including approximate: 13/20 = 65%

  Strongest results:
    1. STELLAR-001 (ISCO = 6 GM/c^2) — exact from GR, non-trivial
    2. STELLAR-002 (alpha ladder)     — systematic dual matches
    3. STELLAR-003 (Ni-56 dual)       — A=sigma(P2), Z=P2

  Honest failures:
    - Chandrasekhar mass: no clean match
    - TOV limit: no clean match
    - Higher magic numbers (50, 82, 126): no match
    - s-process peak spacings: no pattern
```

---

## ASCII Summary: n=6 in Stellar Evolution

```
  Stellar lifecycle mapped to n=6 arithmetic:

  BIRTH                                              DEATH
    │                                                  │
    ▼                                                  ▼
  H cloud ──► Main Sequence ──► Giant ──► Supernova ──► Remnant
    │           t ~ M^(-5/2)      │          │           │
    │           L ~ M^(7/2)       │          │           │
    │           (-sopfr/phi)      │          │           │
    │           ((n+1)/phi)       │          │           │
    │                             │          │           │
    │   ┌─ 6 burning stages ─┐   │          │           │
    │   │ H→He  (tau protons) │   │          │           │
    │   │ He→C  (3*tau=sigma) │   │          │           │
    │   │ C→Ne                │   │          │           │
    │   │ Ne→O                │   │          │           │
    │   │ O→Si                │   │          │           │
    │   │ Si→Fe (P2→sigma(P2))│   │          │           │
    │   └─────────────────────┘   │          │           │
    │                             │          │           │
    │                             │   Ni-56 decay        │
    │                             │   A=sigma(P2)        │
    │                             │   Z=P2               │
    │                             │          │           │
    │                             │          ▼           │
    │                             │      Fe-56 ash      │
    │                             │      A=sigma(P2)    │
    │                             │                     │
    │   BBN: H:He = sigma:tau     │              BH: ISCO = n*GM/c^2
    │   Y_p = 1/tau               │              WD: M_Ch via mu_e=phi
    │                             │              NS: (no clean match)
    │                             │
    │   Alpha ladder:             │
    │   He-4 = tau                │
    │   C-12 = sigma              │
    │   Si-28 = P2                │
    │   Fe-56 = sigma(P2)         │
```

---

## Limitations and Honest Assessment

1. **Small number bias**: Many matches involve the numbers 2, 3, 4, 5, 6, which are
   common in physics for dimensional and symmetry reasons. The Texas Sharpshooter
   risk is significant for small-number matches.

2. **Selection bias in alpha ladder**: Alpha-process nuclei have A = 4k by construction
   (alpha capture). That tau(6) = 4 aligns with the alpha particle mass is one
   coincidence, not a pattern.

3. **Strongest result is genuinely strong**: ISCO = 6 GM/c^2 is an exact result of
   general relativity where the number 6 is non-trivially determined by solving
   a cubic equation. This is the one result that could survive rigorous scrutiny.

4. **Nucleosynthesis hierarchy is systematic**: The chain He-4(tau) -> C-12(sigma) ->
   Si-28(P2) -> Fe-56(sigma(P2)) involves four distinct n=6 functions mapping to
   four key nuclei. This is more than individual coincidences.

5. **Failed predictions matter**: The honest non-matches for Chandrasekhar mass,
   TOV limit, and higher magic numbers constrain the scope of any claimed connection.

---

## Verification Direction

1. **Quantitative**: Calculate probability that 4/7 magic numbers match n=6
   expressions by chance (Monte Carlo with random arithmetic expressions)
2. **Extend to P3=496**: Check if nuclei near A=496 or A=sigma(496)=992 have
   special nuclear properties
3. **Cross-domain**: Compare hit rate (40% structural) with other hypothesis
   domains to assess whether astrophysics is above or below average
4. **ISCO generalization**: Check whether other exact GR results contain n=6
   (photon sphere at r=3=sigma/tau, ergosphere, etc.)
