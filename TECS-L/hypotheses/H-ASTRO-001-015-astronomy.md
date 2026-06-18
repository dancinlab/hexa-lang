# Astronomy/Cosmology Hypotheses H-ASTRO-001 through H-ASTRO-015
**n6 Grade: 🟩 EXACT** (auto-graded, 15 unique n=6 constants)


> **Do astronomical structures (solar system, stellar physics, cosmology) exhibit
> privileged connections to the perfect number n=6 and its arithmetic functions
> sigma(6)=12, tau(6)=4, phi(6)=2, sigma_{-1}(6)=2?**

## Background

The TECS-L project has found structural connections between n=6 and pure mathematics
(H-067, H-090, H-092, H-098) and information theory (H-139, H-172). Physics constants
are explored in SEDI. This document tests whether ASTRONOMICAL structures -- planetary
systems, stellar physics, and cosmological parameters -- connect to n=6.

Existing related hypotheses (avoided for duplication):
- H-118: Universe composition (dark energy ~ 2/3, baryon ~ 1/e^3) -- already in TECS-L
- H-153: Hubble tension -- already in TECS-L (graded WHITE)
- SEDI PS-21: Exoplanet orbital period ratios -- already in SEDI

Framework constants tested against:

```
  n=6  sigma(6)=12  tau(6)=4  phi(6)=2  sigma_{-1}(6)=2
  Divisors: {1, 2, 3, 6}
  Golden Zone: [0.2123, 0.5], center 1/e=0.3679, width ln(4/3)=0.2877
```

## Results Summary

```
  ID             Hypothesis                              Err%   Grade
  -------------- --------------------------------------- ------ ------
  H-ASTRO-001    Lagrange points = n-1 = 5                0.0%  WHITE
  H-ASTRO-002    Jupiter-Saturn 5:2 from n=6              0.0%  WHITE
  H-ASTRO-003    Axial tilt ~ sigma*phi = 24              2.4%  WHITE
  H-ASTRO-004    Moon period from n=6                     2.4%  WHITE
  H-ASTRO-005    Classical planets = 6                    0.0%  WHITE
  H-ASTRO-006    Chandrasekhar ~ sqrt(2) ~ phi^(1/phi)    1.8%  WHITE
  H-ASTRO-007    Star formation efficiency ~ 1/N^2       39.0%  WHITE
  H-ASTRO-008    Luminosity classes = 6                   0.0%  WHITE
  H-ASTRO-009    Stellar fusion pathways = 6              0.0%  WHITE
  H-ASTRO-010    Onion shell burning layers = 6           0.0%  WHITE
  H-ASTRO-011    d=3 spatial dimensions = N/phi            0.0%  WHITE
  H-ASTRO-012    T_CMB ~ e (0.27% error)                  0.3%  ORANGE
  H-ASTRO-013    Baryon/photon eta mantissa ~ 6            1.6%  WHITE
  H-ASTRO-014    Spectral index ns from n=6                0.7%  WHITE
  H-ASTRO-015    z_DE-matter equality ~ ln(4/3)           1.3%  WHITE

  Grade distribution: 14 WHITE, 1 ORANGE, 0 ORANGE_STAR, 0 GREEN
```

## Grade Distribution ASCII Graph

```
  WHITE  |############################################| 14
  ORANGE |###                                         |  1
  STAR   |                                            |  0
  GREEN  |                                            |  0
         +----+----+----+----+----+----+----+----+----+
         0    2    4    6    8   10   12   14   16
```

---

## SOLAR SYSTEM (H-ASTRO-001 through H-ASTRO-005)

### H-ASTRO-001: Lagrange Points = n-1 = 5

> In the circular restricted 3-body problem, there are exactly 5 Lagrange
> equilibrium points (L1-L5) per body pair. Does 5 = n-1 = 6-1?

**Observed:** 5 Lagrange points (L1-L5)
**n=6 expressions:**
- n - 1 = 6 - 1 = 5 (exact)
- sigma - tau - phi = 12 - 4 - 2 = 6 (off by 1, ad-hoc)

**Verdict:** n-1 = 5 is exact but trivially true for ANY n=6. The formula n-1
gives 5 for n=6, but the Lagrange point count comes from solving a 5th-degree
polynomial (quintic) in the rotating frame, which has nothing to do with perfect
numbers.

```
  L4
   *
  / \
 /   \           L1   L2   L3 are collinear
M1----L1--M2--L2      L4, L5 are equilateral
 \   /
  \ /
   *
  L5

  5 points: from solving R(x,y)=0 in rotating frame
  = 3 collinear + 2 equilateral, not from n=6
```

**Grade: WHITE** -- trivial identity, not structural.

---

### H-ASTRO-002: Jupiter-Saturn 5:2 Resonance

> The Jupiter-Saturn "Great Inequality" near-resonance has ratio 5:2 = 2.5.
> Can this be expressed as (tau(6)+1)/phi(6)?

**Observed:** Jupiter period 11.86 yr / Saturn period 29.46 yr = ratio 2.484
(near 5:2 = 2.5)
**n=6 expression:** (tau+1)/phi = (4+1)/2 = 2.5 -- requires ad-hoc +1

**Verdict:** The +1 correction disqualifies this per CLAUDE.md rules. The 5:2
near-resonance is a well-understood dynamical feature governed by orbital
mechanics, not number theory.

**Grade: WHITE** -- ad-hoc +1 required.

---

### H-ASTRO-003: Earth's Axial Tilt ~ sigma*phi = 24

> Earth's current axial tilt of 23.44 degrees is close to sigma(6)*phi(6) = 24.

**Observed:** 23.44 degrees (current epoch)
**Predicted:** sigma(6) * phi(6) = 12 * 2 = 24
**Error:** 2.39%

```
  Milankovitch Obliquity Cycle (41,000 years)
  Tilt (deg)
  24.5 |        *****
  24.0 |  *****       ***  ........ sigma*phi = 24
  23.5 |*               ****
  23.0 |                    ****
  22.5 |                        ***
  22.0 |                           **
       +---+---+---+---+---+---+---+--> time (kyr)
       0   10  20  30  40  50  60  70

  24 is within the Milankovitch range [22.1, 24.5]
  but so is any value in that 2.4-degree band
```

**Verdict:** The axial tilt oscillates between 22.1 and 24.5 degrees over a
41,000-year cycle. The value 24 = sigma*phi is within this range but holds no
privileged position. At other epochs, the tilt is far from 24.

**Grade: WHITE** -- unstable observable, coincidence.

---

### H-ASTRO-004: Moon Sidereal Period ~ n=6 expression

> The Moon's sidereal period of 27.322 days: can it be expressed from n=6?

**Observed:** 27.322 days

| Expression | Value | Error |
|---|---|---|
| 3^3 | 27 | 1.18% |
| sigma*phi + tau - 1 | 27 | 1.18% (ad-hoc -1) |
| sigma + tau*phi^2 | 28 | 2.48% |
| N^2 - tau*phi | 28 | 2.48% |

**Verdict:** The best match (3^3 = 27) is not specific to n=6. The n=6 expressions
either need ad-hoc corrections or have >2% error. The Moon's orbital period is
determined by the Earth-Moon mass ratio and orbital radius, not number theory.

**Grade: WHITE** -- contrived expressions, not n=6 specific.

---

### H-ASTRO-005: Classical Planets = 6

> The number of classical planets (Mercury through Saturn plus Earth) is 6 = n.

**Observed:** 6 planets visible to ancients (Mercury, Venus, Earth, Mars, Jupiter, Saturn)
**n = 6:** exact match

**Verdict:** This is an observational selection effect. The count depends on the
sensitivity of the human eye:
- Naked eye limit ~mag 6: 5 wandering planets + Earth = 6
- Slightly better eyes: Uranus at mag 5.7 becomes visible = 7
- Ancient classification: 7 celestial wanderers (Sun + Moon + 5 planets)

The number 6 here is an accident of human visual acuity, not a fundamental constant.

**Grade: WHITE** -- selection effect, not fundamental.

---

## STELLAR PHYSICS (H-ASTRO-006 through H-ASTRO-010)

### H-ASTRO-006: Chandrasekhar Limit ~ sqrt(sigma_{-1}(6))

> The Chandrasekhar mass limit 1.44 M_sun ~ sqrt(2) ~ sqrt(sigma_{-1}(6)).

**Observed:** 1.44 M_sun (range 1.39-1.46 depending on composition)
**Predicted:** sqrt(sigma_{-1}(6)) = sqrt(2) = 1.4142
**Error:** 1.79%

**Verdict:** The sqrt(2) appears in Chandrasekhar's derivation from the physics
of electron degeneracy pressure (Fermi-Dirac statistics), not from n=6. The actual
formula is M_Ch = (5.83/mu_e^2) M_sun where mu_e is the mean molecular weight per
electron. The sqrt(2) connection is coincidental -- it maps to phi(6)^(1/phi(6))
only because phi(6) happens to equal 2.

**Grade: WHITE** -- sqrt(2) comes from physics, attribution to n=6 is spurious.

---

### H-ASTRO-007: Star Formation Efficiency ~ 1/N^2

> The galactic star formation efficiency per free-fall time (~2%) ~ 1/N^2 = 1/36?

**Observed:** ~1-3% per free-fall time (Krumholz & McKee 2005)
**1/N^2 = 1/36 = 2.78%:** within the range but the range is enormous

**Verdict:** SFE varies from ~0.1% (low-density clouds) to ~30% (starburst cores).
Any constant between 0.001 and 0.3 would "match" somewhere. This is not a test.

**Grade: WHITE** -- target range too broad.

---

### H-ASTRO-008: Yerkes Luminosity Classes = 6

> The MKK/Yerkes classification has 6 luminosity classes (I through VI).

**Observed:** I (supergiants), II (bright giants), III (giants), IV (subgiants),
V (main sequence), VI (subdwarfs)
**n = 6:** exact match

**Verdict:** The count depends on which classification system is used:
- Original MKK (1943): 5 classes (I-V)
- Extended: 6 classes (I-VI, adding subdwarfs)
- Full: 8+ classes (0/Ia/Iab/Ib, ..., VII for white dwarfs)

Human classification boundaries are arbitrary. Nature provides a continuum.

**Grade: WHITE** -- classification-system dependent.

---

### H-ASTRO-009: Stellar Fusion Pathways = 6

> The number of major stellar nuclear fusion pathways is 6 = 3 + 2 + 1 (pp + CNO + He).

```
  pp chain:     ppI   ppII   ppIII    = 3 branches
  CNO cycle:    CN    NO               = 2 branches
  He burning:   triple-alpha           = 1 pathway
                                   Total = 6

  Note: 3 + 2 + 1 = sum of proper divisors of 6
```

**Verdict:** The count 6 depends on stopping at helium burning. If carbon, neon,
oxygen, and silicon burning are included, the count rises to 9+. The "major" cutoff
is a subjective human choice, not a physical boundary.

**Grade: WHITE** -- depends on where you draw the line.

---

### H-ASTRO-010: Onion Shell Burning Layers = 6

> Massive stars develop 6 concentric nuclear burning shells: H, He, C, Ne, O, Si.

```
  Onion shell structure of a massive star (>8 M_sun):

  ┌──────────────────────┐
  │    H envelope        │ Layer 1: Hydrogen
  │  ┌────────────────┐  │
  │  │  He shell      │  │ Layer 2: Helium
  │  │  ┌──────────┐  │  │
  │  │  │  C shell  │  │  │ Layer 3: Carbon
  │  │  │  ┌──────┐ │  │  │
  │  │  │  │Ne/O  │ │  │  │ Layer 4-5: Neon, Oxygen
  │  │  │  │┌────┐│ │  │  │
  │  │  │  ││ Si ││ │  │  │ Layer 6: Silicon
  │  │  │  ││ Fe ││ │  │  │ (Iron core = endpoint)
  │  │  │  │└────┘│ │  │  │
  │  │  │  └──────┘ │  │  │
  │  │  └──────────┘  │  │
  │  └────────────────┘  │
  └──────────────────────┘

  6 burning layers: H, He, C, Ne, O, Si
```

**Observed:** 6 distinct nuclear burning shells is the standard textbook result.
**n = 6:** exact match

**Verdict:** The 6 layers reflect the 6 exothermic fusion stages before iron:
H->He, He->C, C->Ne/Na, Ne->O/Mg, O->Si/S, Si->Fe. This is determined by
nuclear physics (Coulomb barriers and binding energies), not by n=6. One could
argue Ne and O burning are nearly simultaneous, giving 5 layers. The count is
robust but physically determined.

**Grade: WHITE** -- physically determined by nuclear binding energy curve.

---

## COSMOLOGY (H-ASTRO-011 through H-ASTRO-015)

### H-ASTRO-011: Spatial Dimensions = N/phi(6) = 3

> The 3 spatial dimensions = N/phi(6) = 6/2 = 3.

**Observed:** d = 3 spatial dimensions
**n=6 expression:** N/phi(6) = 6/2 = 3

**Verdict:** N/phi(N) = N/2 = 3 works for ANY even number N, not just the perfect
number 6. Additionally, 3 is a divisor of 6, but that is true for every multiple
of 3. The anthropic argument (Ehrenfest: only d=3 allows stable orbits AND stable
atoms) provides a physics-based reason for d=3 that has nothing to do with perfect
numbers.

**Grade: WHITE** -- generic for any even N, not n=6 specific.

---

### H-ASTRO-012: CMB Temperature ~ e

> T_CMB = 2.7255 +/- 0.0006 K vs e = 2.71828... Error: 0.265%.

```
  T (K)
  2.730 |          * T_CMB = 2.7255
  2.725 |  --------|--------  (measurement band +/- 0.0006)
  2.720 |       * e = 2.7183
  2.715 |
        +--+--+--+--+--+--+-->
        0.265% gap = 12 sigma from exact match
```

**Observed:** T_CMB = 2.7255 K (FIRAS, Fixsen 2009)
**e = 2.71828...**
**Error:** 0.265%
**Sigma distance:** 12.0 sigma (measurement EXCLUDES T_CMB = e exactly)

**Verdict:** The 0.265% proximity is noteworthy numerically but:
1. T_CMB is measured to 12 sigma precision and EXCLUDES e exactly
2. T_CMB evolves as T = T_0 * (1+z), so was equal to e at z ~ 0.00265
3. The value depends on baryon density, photon density, and expansion history
4. Already known in TECS-L (results/formula_discovery.md)
5. Not specific to n=6 -- relates to e, which is a universal constant

**Grade: ORANGE** -- 0.27% is notable but already catalogued, not new.

---

### H-ASTRO-013: Baryon-to-Photon Ratio eta ~ 6 x 10^-10

> The cosmic baryon-to-photon ratio eta = (6.10 +/- 0.04) x 10^-10.
> Is the mantissa ~ n = 6?

**Observed:** eta = (6.10 +/- 0.04) x 10^-10 (Planck 2018)
**n = 6:** mantissa 6.10 vs 6.00, difference = 0.10
**Sigma distance:** 0.10 / 0.04 = 2.5 sigma

```
  Probability density for eta mantissa
  p(x)
  |        ****
  |      **    **
  |    **        **
  |  **            **
  | *                *
  |*                  *
  +--+--+--+--+--+--+--+-->
  5.9 6.0 6.1 6.2 6.3
       ^         ^
       n=6       measured center (6.10)
       (2.5 sigma away)
```

**Verdict:** The mantissa 6.10 is close to 6 but statistically excluded at 2.5
sigma. If the true value were exactly 6.00, it would be 2.5 sigma away from the
measurement -- unlikely but not impossible (p ~ 0.012 one-sided). However, the
exponent -10 has no n=6 connection, and mantissa matching across orders of
magnitude is a known source of numerological false positives.

**Grade: WHITE** -- excluded at 2.5 sigma, mantissa matching is unreliable.

---

### H-ASTRO-014: Spectral Index ns from n=6

> The CMB scalar spectral index ns = 0.9649 +/- 0.0042. Can any n=6 expression
> reproduce this?

| Expression | Value | Delta | Sigma distance |
|---|---|---|---|
| 1 - 1/sigma(6) | 0.9167 | 0.0482 | 11.5 sigma |
| 1 - 1/N^2 | 0.9722 | 0.0073 | 1.7 sigma |
| 1 - phi/N^2 | 0.9444 | 0.0205 | 4.9 sigma |
| 1 - 1/(N^2-1) | 0.9714 | 0.0065 | 1.6 sigma |
| 1 - 1/tau! | 0.9583 | 0.0066 | 1.6 sigma |

**Verdict:** The best candidates (1-1/N^2, 1-1/(N^2-1), 1-1/tau!) are all 1.6-1.7
sigma away. None achieves a match within 1 sigma. With 5 candidates tried, the
effective sigma threshold should be higher (look-elsewhere effect). No clean
connection exists.

**Grade: WHITE** -- no expression matches within 1 sigma after corrections.

---

### H-ASTRO-015: Dark Energy-Matter Equality Redshift ~ ln(4/3)

> The redshift at which dark energy and matter densities are equal, z_eq ~ 0.292,
> is close to the Golden Zone width ln(4/3) = 0.2877.

**Derived:** z_eq = (Omega_Lambda / Omega_m)^(1/3) - 1 = (0.683/0.317)^(1/3) - 1 = 0.2916
**GZ_width:** ln(4/3) = 0.2877
**Error:** 1.34%

```
  Density
  |  matter ~ (1+z)^3
  |  ****
  |       ****
  |            ****______ dark energy (constant)
  |     z_eq=0.292
  |            |
  +----+----+--+--+----+---> z (redshift)
  0   0.1  0.2  0.3  0.4
              ^
              ln(4/3)=0.288
```

**Verdict:** The 1.3% match is interesting but NOT independent: z_eq is derived
from Omega_Lambda and Omega_m, which are already addressed in H-118 (universe
composition). This is a mathematical consequence of H-118, not a new observation.
Additionally, the value depends sensitively on the measured cosmological parameters,
which have evolved across survey generations (WMAP vs Planck vs DESI).

**Grade: WHITE** -- derived from H-118, not independent.

---

## Overall Verdict

```
  ┌───────────────────────────────────────────────────────────────┐
  │  ASTRONOMY / COSMOLOGY n=6 CONNECTION: NEGATIVE RESULT       │
  │                                                               │
  │  15 hypotheses tested:                                        │
  │    14 WHITE (coincidence/selection effect/contrived)           │
  │     1 ORANGE (T_CMB ~ e, already known, not new)              │
  │     0 ORANGE_STAR (none structural)                           │
  │     0 GREEN (none proven)                                     │
  │                                                               │
  │  Root causes of failure:                                      │
  │  1. Small-number bias: 3, 6, 12 appear everywhere in nature   │
  │  2. Selection effects: choosing which items to count           │
  │  3. Post-hoc fitting: many n=6 expressions available          │
  │  4. Broad target ranges: SFE, classification boundaries       │
  │                                                               │
  │  Conclusion: Astronomy is NOT a fruitful domain for n=6       │
  │  connections. The strong results remain in pure mathematics    │
  │  and information theory (H-067, H-090, H-092, H-098, H-172). │
  └───────────────────────────────────────────────────────────────┘
```

## Limitations

1. Only 15 hypotheses tested -- more astronomical observables exist
2. We focused on simple arithmetic expressions; deeper connections (e.g., group theory
   of n=6 symmetries in cosmological perturbation theory) were not explored
3. Some "exact" matches (fusion pathways, onion shells) may deserve deeper investigation
   into WHY the nuclear physics produces 6 stages

## Verification Directions

- [ ] Explore group-theoretic connections (S_6 permutation group in cosmology?)
- [ ] Test with perfect number 28: do any astronomical structures prefer 28?
- [ ] Investigate the onion shell = 6 connection more rigorously (why 6 exothermic stages?)
- [ ] Cross-check with updated DESI/Euclid cosmological parameters

---

*Verification script: verify/verify_astro_001_015.py*
*Date: 2026-03-28*
*Golden Zone dependent: Yes (H-ASTRO-012, H-ASTRO-015). Rest are n=6 arithmetic only.*
*Related: H-118 (cosmos constants), H-153 (Hubble tension), SEDI PS-21 (exoplanet orbits)*
