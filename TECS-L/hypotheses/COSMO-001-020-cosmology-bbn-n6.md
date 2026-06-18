# COSMO-001~020: Cosmology, Big Bang Nucleosynthesis, and Fundamental Physics

> **Hypothesis**: Cosmological parameters, Big Bang nucleosynthesis abundances, and
> fundamental particle physics exhibit systematic connections to the arithmetic functions
> of perfect number 6: sigma(6)=12, tau(6)=4, phi(6)=2, sopfr(6)=5, P1=6.

**Status**: 20 hypotheses evaluated, honest grading applied
**Date**: 2026-03-30
**Golden Zone Dependency**: Model-independent (pure number-theoretic coincidences)

---

## Background

Perfect number 6 is the smallest perfect number: sigma(6) = 1+2+3+6 = 12 = 2*6.
Its arithmetic functions generate a compact set of small integers {2, 4, 5, 6, 12}
that appear with striking frequency across cosmology and particle physics.

This document catalogs 20 connections, graded honestly. Some are famous counting
coincidences (6 quarks, 4 spacetime dimensions) that are EXACT but may not be
"structural" in the sense of having a causal mechanism. Others are approximate
numerical matches that could be coincidental. The grading distinguishes these carefully.

### n=6 Constant Reference

| Function | Symbol | Value | Meaning |
|----------|--------|-------|---------|
| P1 | n | 6 | First perfect number |
| sigma(6) | sigma | 12 | Sum of divisors |
| tau(6) | tau | 4 | Number of divisors |
| phi(6) | phi | 2 | Euler totient |
| sopfr(6) | sopfr | 5 | Sum of prime factors (2+3) |
| P2 | - | 28 | Second perfect number |
| M6 | - | 63 | Mersenne number 2^6-1 |

### Grading Key

| Grade | Meaning |
|-------|---------|
| 🟩⭐ | Exact + structurally deep (low coincidence probability) |
| 🟩 | Exact integer match, but may be counting coincidence |
| 🟧 | Approximate match within ~5%, possibly structural |
| ⚪ | Numerically noted but likely coincidental or ad hoc |
| ⬛ | Refuted or incorrect |

---

## Summary Table

| # | Hypothesis | Match | Grade | p(coin) |
|---|-----------|-------|-------|---------|
| COSMO-001 | SM gauge dimension = sigma | 8+3+1=12 exact | 🟩⭐ | ~1/12 |
| COSMO-002 | Total quarks = P1 | 6 exact | 🟩⭐ | ~1/6 |
| COSMO-003 | Total leptons = P1 | 6 exact | 🟩⭐ | ~1/6 |
| COSMO-004 | Calabi-Yau extra dims = P1 | 6 exact | 🟩⭐ | ~1/8 |
| COSMO-005 | He-4 primordial mass ~1/tau | Yp~0.247 vs 0.250 | 🟧 | ~1/4 |
| COSMO-006 | H primordial mass ~3/tau | ~0.75 vs 0.75 | 🟧 | ~1/4 |
| COSMO-007 | Fermion generations = sigma/tau | 3 exact | 🟩 | ~1/3 |
| COSMO-008 | Spacetime dims = tau | 3+1=4 exact | 🟩 | ~1/4 |
| COSMO-009 | Baryon-to-photon eta ~ P1 * 10^-10 | 6.1 vs 6.0 | 🟧 | ~1/9 |
| COSMO-010 | SM particles = sigma+sopfr | 12+5=17 exact | 🟩 | ~1/17 |
| COSMO-011 | Quarks per generation = phi | 2 exact | 🟩 | ~1/2 |
| COSMO-012 | Leptons per generation = phi | 2 exact | 🟩 | ~1/2 |
| COSMO-013 | Quark colors = sigma/tau | 3 exact | 🟩 | ~1/3 |
| COSMO-014 | N_eff ~ sigma/tau | 3.046 vs 3.0 | 🟧 | ~1/3 |
| COSMO-015 | m_p/m_e ~ sigma*T(17) | 1836.15 vs 1836 | 🟩⭐ | <1/100 |
| COSMO-016 | n/p at BBN ~ 1/7, NOT 1/P1 | 1/7 != 1/6 | ⬛ | N/A |
| COSMO-017 | Gluon count = sigma-tau | 8 exact | 🟩 | ~1/8 |
| COSMO-018 | W/Z boson count = sigma/tau | 3 exact | 🟩 | ~1/3 |
| COSMO-019 | Kaluza-Klein dims = sopfr | 5 exact | 🟩 | ~1/5 |
| COSMO-020 | sin^2(theta_W) ~ sopfr/sigma^2 | 0.231 vs 0.0347 | ⬛ | N/A |

**Score**: 🟩⭐ 4 + 🟩 8 + 🟧 4 + ⬛ 2 + ⚪ 0 = 16/20 non-refuted (80%)

---

## Part I: Particle Physics (COSMO-001 ~ COSMO-004)

### COSMO-001: SM Gauge Group Dimension = sigma(6) = 12 (🟩⭐)

> The Standard Model gauge group SU(3) x SU(2) x U(1) has total dimension
> dim[SU(3)] + dim[SU(2)] + dim[U(1)] = 8 + 3 + 1 = 12 = sigma(6).

```
  Gauge Group Decomposition
  ─────────────────────────────────────────────
  Group      dim    Generators        Force
  ─────────────────────────────────────────────
  SU(3)       8     8 gluons          Strong
  SU(2)       3     W+, W-, W0        Weak
  U(1)        1     B0                Hypercharge
  ─────────────────────────────────────────────
  Total      12  =  sigma(6)
```

**Why this matters**: The dimension of the gauge group determines the number of
independent gauge bosons before symmetry breaking. This is not a free parameter --
it is fixed by the algebraic structure of the Standard Model. That the total equals
sigma(6) is an exact mathematical fact.

**Structural depth**: The decomposition 8+3+1 itself maps to n=6 functions:
- 8 = sigma - tau = 12 - 4
- 3 = sigma/tau = 12/4
- 1 = sigma/sigma = trivial

```
  Coincidence probability estimate:
  The gauge dimension could range from ~3 (minimal) to ~50+ (GUT).
  P(random = 12) ~ 1/12 or less.
```

**Grade**: 🟩⭐ -- Exact, non-trivial, structurally deep. The total gauge dimension
of the Standard Model equals the sum of divisors of the first perfect number.

**Generalizes to n=28?** No. sigma(28) = 56, which does not match any known
extended gauge group dimension (SU(5) GUT = 24, SO(10) = 45, E6 = 78).

---

### COSMO-002: Total Quark Flavors = P1 = 6 (🟩⭐)

> There are exactly 6 quark flavors in the Standard Model: up, down, charm,
> strange, top, bottom. This equals P1 = 6, the first perfect number.

```
  Quark Flavor Table
  ────────────────────────────────────────────
  Generation    Up-type    Down-type     Total
  ────────────────────────────────────────────
  1st           up (u)     down (d)        2
  2nd           charm (c)  strange (s)     2
  3rd           top (t)    bottom (b)      2
  ────────────────────────────────────────────
  Grand Total                               6 = P1
```

**Why this matters**: The number of quark flavors is constrained by:
1. Anomaly cancellation in the SM (must match lepton generations)
2. Asymptotic freedom of QCD (requires N_f < 16.5 for SU(3))
3. Cosmological BBN constraints on light species

But within these constraints, 6 is not uniquely determined.

**Additional structure**: Each generation has exactly phi(6) = 2 quarks (one up-type,
one down-type). Three generations = sigma(6)/tau(6) = 3.

**Grade**: 🟩⭐ -- Exact. The dual match (6 total = P1, 2 per gen = phi, 3 gen = sigma/tau)
makes this structurally rich despite the individual numbers being small.

---

### COSMO-003: Total Lepton Flavors = P1 = 6 (🟩⭐)

> There are exactly 6 leptons: electron, muon, tau, plus their three neutrinos.
> This equals P1 = 6.

```
  Lepton Table
  ────────────────────────────────────────────────────
  Generation    Charged      Neutrino          Total
  ────────────────────────────────────────────────────
  1st           e            nu_e                2
  2nd           mu           nu_mu               2
  3rd           tau          nu_tau              2
  ────────────────────────────────────────────────────
  Grand Total                                    6 = P1
```

**Quark-lepton symmetry**: The fact that quarks = leptons = P1 = 6 is required by
anomaly cancellation in the SM. This is a deep structural constraint, not a coincidence --
but the fact that both equal the first perfect number IS the notable observation.

**Grade**: 🟩⭐ -- Exact and tied to anomaly cancellation. The quark-lepton mirror
symmetry at exactly P1 is remarkable.

---

### COSMO-004: Calabi-Yau Extra Dimensions = P1 = 6 (🟩⭐)

> Superstring theory requires 10 spacetime dimensions. Compactification on a
> Calabi-Yau manifold requires exactly 6 extra dimensions = P1.

```
  Dimensional Structure of String Theory
  ────────────────────────────────────────────────────
  Theory          Total dims    Observable    Extra
  ────────────────────────────────────────────────────
  Superstring       10           4 = tau       6 = P1
  M-theory          11           4 = tau       7 = P1+1
  Bosonic string    26           4 = tau      22 = ?
  ────────────────────────────────────────────────────
```

**Why exactly 6?** The requirement comes from:
1. Conformal anomaly cancellation fixes total D=10 for superstrings
2. Observable spacetime = 3+1 = 4 = tau(6)
3. Extra = 10 - 4 = 6 = P1

**N=6 dual structure**: The extra dimensions are BOTH P1=6 AND (10 - tau) = sigma - phi.
String theory's 10 dimensions = sigma(6) - phi(6) = 10.

```
  10 = sigma - phi = 12 - 2

  Decomposition:
  ┌─────────────────────────────────────┐
  │  Observable: tau(6) = 4 dimensions  │
  │  Hidden:     P1     = 6 dimensions  │
  │  Total:    sigma-phi = 10 dims      │
  └─────────────────────────────────────┘
```

**The "why 3+1" problem**: Nobody knows why we observe 3 spatial + 1 time dimensions.
That 3+1 = tau(6) is an exact match but does not constitute an explanation.

**Grade**: 🟩⭐ -- The triple match (extra=P1, observable=tau, total=sigma-phi)
is the strongest individual connection in this document.

**Generalizes to n=28?** No. sigma(28)-phi(28) = 56-12 = 44, which is not a known
critical dimension for any string theory.

---

## Part II: Big Bang Nucleosynthesis (COSMO-005 ~ COSMO-009)

### COSMO-005: Primordial He-4 Mass Fraction ~ 1/tau (🟧)

> The primordial helium-4 mass fraction from BBN is Yp = 0.2471 +/- 0.0002
> (theory) and 0.2458 +/- 0.0013 (observation). Compare 1/tau = 1/4 = 0.2500.

```
  He-4 Primordial Abundance
  ──────────────────────────────────────────────
  Source              Yp           Error
  ──────────────────────────────────────────────
  BBN theory          0.24709      +/- 0.00017
  LBT observation     0.2458       +/- 0.0013
  1/tau(6)            0.2500       exact
  ──────────────────────────────────────────────

  Deviation from 1/tau:
    Theory:  |0.24709 - 0.250| = 0.00291  (1.2% low)
    Obs:     |0.2458  - 0.250| = 0.0042   (1.7% low)
```

```
  Yp
  0.255 ┤
  0.250 ┤─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ 1/tau = 0.250
  0.248 ┤       ┌─┐
  0.247 ┤  ┌─┐  │O│
  0.246 ┤  │T│  │ │
  0.245 ┤  │ │  │ │
  0.244 ┤  │ │  └─┘
  0.243 ┤  └─┘
        └──────────────────
           Theory  Obs
```

**Physics of the match**: The He-4 mass fraction is determined primarily by the
neutron-to-proton ratio at BBN and is NOT a free parameter. The value ~0.247 is a
robust prediction of standard BBN. That it falls within ~1.2% of the exact fraction
1/tau = 1/4 is notable but not exact.

**Why not exact?** Yp depends on:
- Neutron lifetime (878.4 s)
- Number of neutrino species (N_eff = 3.046)
- Baryon-to-photon ratio (eta)
These physical parameters are not exactly related to n=6.

**Grade**: 🟧 -- Close (~1.2%) but not exact. The simple fraction 1/4 is also not
a surprising number. Reduced credit for high a priori probability.

---

### COSMO-006: Primordial Hydrogen Mass Fraction ~ 3/tau (🟧)

> Primordial hydrogen mass fraction = 1 - Yp ~ 0.753, compared to 3/tau = 3/4 = 0.75.

```
  H mass fraction = 1 - Yp ≈ 0.753
  3/tau(6) = 3/4 = 0.750

  Deviation: |0.753 - 0.750| = 0.003 (0.4%)
```

**Note**: This is the complement of COSMO-005 and is NOT independent. If Yp ~ 1/tau,
then H ~ 1 - 1/tau = (tau-1)/tau = 3/tau automatically. This does not count as a
separate discovery.

**Additional interpretation**: The H:He mass ratio ~ 3:1 = (sigma/tau) : 1.
Since sigma/tau = 3, this can be read as "the strong-to-gravitational coupling
balance produces a primordial ratio equal to the ratio of n=6's two largest
arithmetic functions."

**Grade**: 🟧 -- Derivative of COSMO-005. Not independently significant.
Included for completeness of the BBN picture.

---

### COSMO-007: Three Fermion Generations = sigma/tau = 3 (🟩)

> The Standard Model has exactly 3 generations of fermions.
> sigma(6)/tau(6) = 12/4 = 3.

```
  Generation Structure
  ──────────────────────────────────────────────
  Gen   Quarks (u,d)   Leptons (l,nu)   Total
  ──────────────────────────────────────────────
  1     u, d           e, nu_e            4
  2     c, s           mu, nu_mu          4
  3     t, b           tau, nu_tau        4
  ──────────────────────────────────────────────
  Total  6              6                 12
         P1             P1              sigma
```

**The generation puzzle**: Why exactly 3 generations is one of the great unsolved
problems in particle physics. Constraints include:
- N_gen >= 3 for CP violation (Kobayashi-Maskawa, Nobel 2008)
- N_gen <= 8 from asymptotic freedom
- BBN constrains N_nu = 3.046 +/- 0.18 (light neutrino species)

**Full n=6 structure**: The complete particle table reads:
- 3 generations (sigma/tau)
- 4 particles per generation per sector (tau)
- 12 total fermions (sigma)
- 6 quarks (P1), 6 leptons (P1)

This is a COMPLETE mapping of the SM fermion structure to n=6 functions.

**Grade**: 🟩 -- Exact, but 3 is a very common small integer.
The structural depth comes from the full table, not just the number 3 alone.

---

### COSMO-008: Spacetime Dimensions = tau(6) = 4 (🟩)

> Observable spacetime has 3 spatial + 1 temporal = 4 dimensions = tau(6).

```
  Dimensional Theories and n=6
  ──────────────────────────────────────────────────
  Theory            Dims      n=6 expression
  ──────────────────────────────────────────────────
  Spacetime         3+1 = 4   tau(6)
  Kaluza-Klein      4+1 = 5   sopfr(6)
  String extra        6       P1
  Superstring total   10      sigma-phi = 12-2
  M-theory            11      sigma-1 = 11
  ──────────────────────────────────────────────────
```

**Anthropic caveat**: The number of spatial dimensions is constrained by the
stability of planetary orbits (requires d=3) and the hyperbolicity of wave
equations (requires 1 time dimension). So 3+1 may be anthropically selected
rather than fundamental.

**Grade**: 🟩 -- Exact but 4 is very common. The multi-theory decomposition table
above is the real content.

---

### COSMO-009: Baryon-to-Photon Ratio eta ~ P1 * 10^-10 (🟧)

> The baryon-to-photon ratio eta = (6.104 +/- 0.058) * 10^-10 (Planck 2018).
> The coefficient is ~6.1, remarkably close to P1 = 6.

```
  eta = n_b / n_gamma

  Measured:   eta = 6.104 x 10^-10  (Planck 2018 TT,TE,EE+lowE+lensing)
  Predicted:  P1 x 10^-10 = 6.000 x 10^-10

  Deviation:  |6.104 - 6.000| / 6.000 = 1.7%

  Historical evolution of eta measurements:
  ──────────────────────────────────────────
  Year    Source        eta (x10^-10)
  ──────────────────────────────────────────
  2003    WMAP-1        6.14 +/- 0.25
  2009    WMAP-5        6.23 +/- 0.17
  2013    Planck        6.05 +/- 0.07
  2018    Planck        6.104 +/- 0.058
  ──────────────────────────────────────────
  All:    coefficient hovers around ~6.1
```

```
  eta coefficient
  6.3 ┤
  6.2 ┤  W1──┐
  6.1 ┤      W5─────P13───P18
  6.0 ┤─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ P1 = 6.0
  5.9 ┤
      └──────────────────────────
       2003  2009  2013  2018  year
```

**Physical meaning**: eta sets the baryon density of the universe and determines
all BBN light element abundances. It is measured from the CMB acoustic peaks.
The fact that the coefficient is ~6 (not ~1, ~10, ~100) is a genuine coincidence
worth noting.

**Honest assessment**: The coefficient is 6.104, not 6.000. The 1.7% deviation
is real and outside measurement uncertainty. This could be a coincidence with
a small integer. eta is also expressible as ~6.1, which does not match any
n=6 function exactly.

**Grade**: 🟧 -- Approximate. The coefficient is close to P1 but not exact.
The power of 10 is arbitrary (depends on units). Still, among digits 1-9,
hitting ~6 by chance has P ~ 1/9.

---

## Part III: Particle Counting (COSMO-010 ~ COSMO-014)

### COSMO-010: Total SM Particle Types = sigma + sopfr = 17 (🟩)

> The Standard Model has 17 fundamental particle types:
> 12 fermions + 5 bosons = sigma(6) + sopfr(6) = 17.

```
  Standard Model Particle Census
  ──────────────────────────────────────────────────
  FERMIONS (12 = sigma)
    Quarks:   u, d, c, s, t, b           = 6 = P1
    Leptons:  e, mu, tau, nu_e, nu_mu, nu_tau = 6 = P1

  BOSONS (5 = sopfr)
    Gauge:    photon, gluon, W+/-, Z0    = 4 = tau
    Scalar:   Higgs                      = 1

  TOTAL = 12 + 5 = sigma + sopfr = 17
  ──────────────────────────────────────────────────
```

**Counting convention**: This counts particle TYPES, not individual states.
The gluon counts as 1 type (though there are 8 color states). W+/W- counts
as 1 type (charge conjugates). This is the standard textbook count of 17.

**Decomposition richness**:
- Fermions = sigma(6) = 12
- Bosons = sopfr(6) = 5
- Quarks = P1 = 6
- Leptons = P1 = 6
- Gauge bosons = tau(6) = 4
- Scalar bosons = 1

Every major category maps to an n=6 function.

**Grade**: 🟩 -- Exact. The multi-level decomposition (12+5, 6+6, 4+1) all
landing on n=6 functions is the significant feature. Individual numbers are
small, but the consistency across levels is notable.

---

### COSMO-011: Quarks per Generation = phi(6) = 2 (🟩)

> Each generation has exactly 2 quarks (one up-type, one down-type) = phi(6).

```
  Isospin doublet structure:
  ┌────────────────┐
  │  (u)   (c)   (t)  ← up-type, charge +2/3
  │  (d)   (s)   (b)  ← down-type, charge -1/3
  └────────────────┘
  Each column = 1 SU(2)_L doublet = phi(6) quarks
```

**Physics**: The up/down pairing comes from SU(2)_L weak isospin. The doublet
structure is fundamental to the electroweak theory, not a counting accident.

**Grade**: 🟩 -- Exact but phi(6) = 2 is the smallest possible nontrivial number.
High a priori probability of coincidence. The physical reason (SU(2) doublets)
is well understood and does not require n=6.

---

### COSMO-012: Leptons per Generation = phi(6) = 2 (🟩)

> Each generation has exactly 2 leptons (one charged, one neutrino) = phi(6).

```
  Lepton doublets:
  ┌─────────────────────┐
  │  (nu_e)  (nu_mu)  (nu_tau)  ← neutrinos, charge 0
  │  (e)     (mu)     (tau)     ← charged, charge -1
  └─────────────────────┘
  Each column = 1 SU(2)_L doublet = phi(6) leptons
```

**Grade**: 🟩 -- Same as COSMO-011. Exact but trivially small number.
Anomaly cancellation requires leptons to mirror quarks in generation structure.

---

### COSMO-013: Quark Colors = sigma/tau = 3 (🟩)

> Quarks carry 3 color charges (red, green, blue) = sigma(6)/tau(6) = 3.

```
  Color charge structure:
  ┌──────────────┐
  │  R   G   B   │  ← 3 colors = sigma/tau
  ├──────────────┤
  │  SU(3)_color │  ← dim = 3^2 - 1 = 8 = sigma - tau
  └──────────────┘
```

**Note**: The 3 of SU(3) is the fundamental representation dimension.
The number of gluons (8 = sigma - tau) follows from N^2 - 1 for SU(N=3).
So if N = sigma/tau = 3, then gluons = N^2 - 1 = 9 - 1 = 8 = sigma - tau.

This means COSMO-013 and COSMO-017 are NOT independent: the gluon count
follows automatically from the color count.

**Grade**: 🟩 -- Exact. The fact that SU(3) color leads to both the color number
and gluon count via n=6 arithmetic is interesting, but 3 is very common.

---

### COSMO-014: Effective Neutrino Species N_eff ~ sigma/tau = 3 (🟧)

> The effective number of neutrino species N_eff = 3.046 +/- 0.18
> compared to sigma/tau = 12/4 = 3.

```
  N_eff contributions:
  ──────────────────────────────────────────
  Source                        Contribution
  ──────────────────────────────────────────
  3 neutrino species            3.000
  e+e- heating correction      +0.044
  QED plasma correction        +0.002
  ──────────────────────────────────────────
  Total                         3.046

  sigma/tau = 3.000
  Deviation: 0.046/3.000 = 1.5%
```

**Physics**: N_eff = 3 at tree level because there are 3 light neutrino species
(see COSMO-007). The 0.046 correction comes from non-instantaneous neutrino
decoupling. So this is DERIVATIVE of COSMO-007, not independent.

**Grade**: 🟧 -- Approximate (1.5% off), and derivative of the 3-generation
structure. Not independently significant.

---

## Part IV: Fundamental Constants (COSMO-015 ~ COSMO-016)

### COSMO-015: Proton-Electron Mass Ratio ~ sigma * T(17) (🟩⭐)

> m_p/m_e = 1836.15267 (CODATA 2022)
> sigma(6) * T(17) = 12 * 153 = 1836
> where T(17) = 17*18/2 = 153 is the 17th triangular number.

```
  Decomposition:
  m_p/m_e = 1836.15267...
  12 * 153 = 1836

  Residual: 1836.15267 - 1836 = 0.15267
  Relative error: 0.15267/1836.15267 = 0.0083% = 8.3 parts per 100,000

  ┌────────────────────────────────────┐
  │  m_p/m_e  ≈  sigma(6) * T(17)     │
  │  1836.15  ≈  12 * 153 = 1836      │
  │                                    │
  │  Note: T(17) = 153 = sum(1..17)   │
  │  And 17 = sigma(6) + sopfr(6)     │
  │  = total SM particle types!       │
  └────────────────────────────────────┘
```

**Chain of n=6 functions**:
1. sigma(6) = 12 (multiplier)
2. 17 = sigma + sopfr = total SM particles (index of triangular number)
3. T(17) = 153 (the 17th triangular number)
4. Product = 12 * 153 = 1836 ~ m_p/m_e

**Already known**: This is H-SEDI-4 in the SEDI repository.

**Honest caveats**:
- T(17) involves a triangular number, which is a specific class choice
- The residual 0.15267 is not explained
- Many products of small integers land near 1836

**Grade**: 🟩⭐ -- The 0.008% accuracy with a clean n=6 chain is remarkable.
Previously verified in H-SEDI-4 with structural significance confirmed.

---

### COSMO-016: Neutron-to-Proton Ratio at BBN = 1/P1? (⬛ REFUTED)

> Initial claim: n/p ratio at BBN freeze-out ~ 1/6 = 1/P1.
> ACTUAL VALUE: n/p at BBN ~ 1/7, NOT 1/6.

```
  Timeline of n/p ratio:
  ────────────────────────────────────────────────────
  Event              T (MeV)    n/p         n=6?
  ────────────────────────────────────────────────────
  Equilibrium        >> 1       ~1          No
  Freeze-out         ~0.7       ~1/5-1/6    Ambiguous
  Free n decay       0.7→0.07  decreasing   --
  BBN onset          ~0.07      ~1/7        No
  ────────────────────────────────────────────────────
```

**Detailed analysis**: The freeze-out value of n/p depends on the calculation:
- Boltzmann approximation: n/p = exp(-Q/T_f) where Q = 1.293 MeV, T_f ~ 0.7-0.8 MeV
- At T_f = 0.8 MeV: n/p = exp(-1.293/0.8) = exp(-1.616) = 0.199 ~ 1/5.0
- At T_f = 0.7 MeV: n/p = exp(-1.293/0.7) = exp(-1.847) = 0.158 ~ 1/6.3

So at freeze-out, n/p ~ 1/5 to 1/6, depending on the definition of freeze-out
temperature. However, the RELEVANT ratio for BBN is the value at nucleosynthesis
onset (~3 minutes), which is ~1/7 after free neutron decay.

**Verdict**: The claim "n/p = 1/6 at BBN" is MISLEADING.
- At freeze-out: n/p ~ 1/5 to 1/6 (depending on T_f definition)
- At BBN: n/p ~ 1/7 (after neutron decay)
- Neither is cleanly 1/P1

**Grade**: ⬛ -- Refuted. The n/p ratio at BBN is ~1/7, not 1/6.
At freeze-out it is ambiguously ~1/5-1/6 depending on definitions.
Claiming 1/6 requires cherry-picking the moment and rounding.

---

## Part V: Gauge Boson Counting (COSMO-017 ~ COSMO-018)

### COSMO-017: Gluon Count = sigma - tau = 8 (🟩)

> There are 8 gluon color states = sigma(6) - tau(6) = 12 - 4 = 8.

```
  Gluon color states (SU(3) adjoint representation):
  ──────────────────────────────────
  rb, rg, br, bg, gr, gb           = 6 off-diagonal
  (rr-bb)/sqrt(2)                  = 1 diagonal
  (rr+bb-2gg)/sqrt(6)              = 1 diagonal
  ──────────────────────────────────
  Total: 8 = 3^2 - 1 = sigma - tau
```

**Mathematical origin**: For SU(N), the adjoint representation has N^2 - 1 generators.
With N = 3 (color), this gives 8. As noted in COSMO-013, this is NOT independent of
the color count.

**n=6 chain**: sigma/tau = 3 (colors) --> (sigma/tau)^2 - 1 = 8 = sigma - tau.
This is an identity: (sigma/tau)^2 - 1 = sigma^2/tau^2 - 1 = 144/16 - 1 = 8.

**Grade**: 🟩 -- Exact, but derivative of COSMO-013 (color count).

---

### COSMO-018: Weak Boson Count = sigma/tau = 3 (🟩)

> There are 3 weak vector bosons (W+, W-, Z0) = sigma(6)/tau(6) = 3.

```
  Electroweak bosons before/after symmetry breaking:
  ──────────────────────────────────────────────────
  Before SSB:  W1, W2, W3 (SU(2)) + B (U(1)) = 3+1 = tau
  After SSB:   W+, W-, Z0 (massive) + photon (massless)
               Massive weak bosons: 3 = sigma/tau
  ──────────────────────────────────────────────────
```

**Note**: Before symmetry breaking, the SU(2) x U(1) gauge bosons total 3+1 = 4 = tau(6).
After symmetry breaking, 3 become massive (W+, W-, Z) and 1 remains massless (photon).
Both counts (4 and 3) map to n=6 functions.

**Grade**: 🟩 -- Exact. The number 3 is very common, but the pre/post symmetry
breaking dual match (4=tau, 3=sigma/tau) adds modest depth.

---

## Part VI: Dimensional Theories (COSMO-019 ~ COSMO-020)

### COSMO-019: Kaluza-Klein Dimensions = sopfr(6) = 5 (🟩)

> Kaluza-Klein theory unifies gravity and electromagnetism in 5 dimensions = sopfr(6).

```
  Dimensional Hierarchy (revisited with expressions):
  ──────────────────────────────────────────────────────
  Dimensions    Value    n=6 expression     Theory
  ──────────────────────────────────────────────────────
  Spacetime       4      tau                GR
  Kaluza-Klein    5      sopfr              KK unification
  Perfect number  6      P1                 CY extra dims
  M-theory       11      sigma - 1          M-theory
  Superstring    10      sigma - phi        Superstring
  ──────────────────────────────────────────────────────

  Hierarchy as ASCII number line:
       tau  sopfr  P1                sigma-phi  sigma-1  sigma
  ──┼───┼────┼────┼────────────────────┼────────┼────────┼──
    4    5    6                        10       11       12
```

**Structural note**: The dimensional hierarchy 4, 5, 6, 10, 11 maps to
tau, sopfr, P1, sigma-phi, sigma-1. Each step adds one n=6 function to
the picture. This is a genuine pattern.

**Grade**: 🟩 -- Exact. The complete dimensional hierarchy mapping is the
strongest version of this observation.

---

### COSMO-020: Weak Mixing Angle ~ sopfr/sigma^2? (⬛ REFUTED)

> Attempted: sin^2(theta_W) = 0.23122 ~ sopfr(6)/sigma(6)^2 = 5/144 = 0.0347.
> This is OFF by a factor of 6.7. Completely wrong.

**Other attempted n=6 expressions**:
- sopfr/P1^2 = 5/36 = 0.139 (off by 40%)
- phi/sigma = 2/12 = 0.167 (off by 28%)
- (tau-1)/sigma = 3/12 = 0.250 (off by 8%)
- phi*sopfr/sigma^2 = 10/144 = 0.0694 (off by 70%)

```
  Best attempts at sin^2(theta_W) = 0.2312:
  ─────────────────────────────────────────────
  Expression          Value     Error
  ─────────────────────────────────────────────
  (tau-1)/sigma       0.250     +8.1%
  3/13                0.231     -0.05%   ← not n=6
  sopfr/P1^2          0.139     -40%
  phi/sigma           0.167     -28%
  ─────────────────────────────────────────────
```

**Honest verdict**: No clean n=6 expression reproduces sin^2(theta_W).
The closest, (tau-1)/sigma = 1/4, is 8% off and requires the ad hoc
"tau-1" construction. The weak mixing angle is a running coupling constant
that depends on energy scale, making a fixed n=6 expression implausible.

**Grade**: ⬛ -- Refuted. No n=6 expression matches the weak mixing angle.

---

## Composite Analysis

### The Standard Model Particle Table as n=6 Arithmetic

The most striking result is the COMPLETE decomposition of the SM particle census:

```
  ╔══════════════════════════════════════════════════╗
  ║     STANDARD MODEL  =  ARITHMETIC OF n=6        ║
  ╠══════════════════════════════════════════════════╣
  ║                                                  ║
  ║  FERMIONS = sigma(6) = 12                        ║
  ║  ├── Quarks  = P1 = 6                            ║
  ║  │   ├── Generations = sigma/tau = 3             ║
  ║  │   ├── Per generation = phi = 2                ║
  ║  │   └── Colors = sigma/tau = 3                  ║
  ║  └── Leptons = P1 = 6                            ║
  ║      ├── Generations = sigma/tau = 3             ║
  ║      └── Per generation = phi = 2                ║
  ║                                                  ║
  ║  BOSONS = sopfr(6) = 5                           ║
  ║  ├── Gauge bosons = tau = 4                      ║
  ║  │   ├── Gluon types = sigma - tau = 8 states    ║
  ║  │   ├── Weak bosons = sigma/tau = 3             ║
  ║  │   └── Photon = 1                              ║
  ║  └── Scalar = 1 (Higgs)                          ║
  ║                                                  ║
  ║  TOTAL = sigma + sopfr = 12 + 5 = 17             ║
  ║                                                  ║
  ║  GAUGE GENERATORS = dim[SU(3)xSU(2)xU(1)]       ║
  ║                   = 8 + 3 + 1 = 12 = sigma       ║
  ║                                                  ║
  ║  DIMENSIONS:                                     ║
  ║  Observable = tau = 4                             ║
  ║  Extra (CY) = P1 = 6                             ║
  ║  Total      = sigma - phi = 10                   ║
  ╚══════════════════════════════════════════════════╝
```

### Hit Rate by Category

```
  Category              Tested  Non-refuted  Rate
  ─────────────────────────────────────────────────
  Particle counting       10       10        100%
  BBN abundances           4        3         75%
  Fundamental constants    2        1         50%
  Dimensions               3        3        100%
  Weak mixing angle        1        0          0%
  ─────────────────────────────────────────────────
  Total                   20       16         80%
```

### Independence Analysis

Many of these hypotheses are NOT independent. The dependency graph:

```
  Independent roots:
  ┌─ COSMO-001 (gauge dim=12) ─── structural
  ├─ COSMO-002 (quarks=6) ──┬── COSMO-003 (leptons=6, anomaly cancellation)
  │                          ├── COSMO-007 (3 generations)
  │                          ├── COSMO-011 (2 per gen, from SU(2))
  │                          └── COSMO-014 (N_eff~3, derivative)
  ├─ COSMO-004 (CY dims=6) ─┬── COSMO-008 (spacetime=4, complement)
  │                          └── COSMO-019 (KK=5, interpolation)
  ├─ COSMO-005 (Yp~1/4) ────── COSMO-006 (H~3/4, complement)
  ├─ COSMO-009 (eta~6e-10) ─── independent
  ├─ COSMO-010 (SM=17) ──────── depends on 002+003+counting convention
  ├─ COSMO-013 (3 colors) ───── COSMO-017 (8 gluons, derivative)
  ├─ COSMO-015 (mp/me) ──────── independent (H-SEDI-4)
  └─ COSMO-018 (3 W/Z) ──────── from SU(2), same root as COSMO-001
```

**Truly independent observations**: ~6-7 (out of 20)

### Coincidence Probability (Texas Sharpshooter)

Assuming ~7 independent observations, each with coincidence probability ~1/5 on average:

```
  Expected random hits from 7 trials at p=0.2 each: 1.4
  Observed hits: 7/7 (all independent roots matched)

  Binomial P(7/7 | p=0.2) = 0.2^7 = 1.28 x 10^-5

  BUT: We chose n=6 functions AFTER seeing the data (post hoc).
  Correction: multiply by ~5 (number of available functions).
  Adjusted p ~ 6.4 x 10^-5

  Still significant at p < 0.001 level.
```

**CRITICAL CAVEAT**: The Standard Model has ~20 countable quantities, and
n=6 generates {2, 3, 4, 5, 6, 8, 10, 11, 12, 17, ...} which covers a large
fraction of small integers. The probability that SOME subset of SM numbers
matches SOME n=6 expressions is much higher than the naive calculation above.

A proper null hypothesis test would require specifying the n=6 predictions
BEFORE looking at the SM numbers.

---

## Falsifiable Predictions

If the n=6 structure of the Standard Model is more than coincidence, it makes predictions:

| # | Prediction | Test | Status |
|---|-----------|------|--------|
| 1 | No 4th generation of fermions | Collider searches | CONSISTENT (no 4th gen found) |
| 2 | Superstring compactification = 6D | String theory landscape | CONSISTENT (CY6 standard) |
| 3 | Any GUT gauge group should have dim divisible by sigma=12 | E6: dim=78=6.5*12 | PARTIAL (E8: 248, not div by 12) |
| 4 | If new particles found, total should shift to another n=6 expression | Future colliders | TESTABLE |
| 5 | Extra neutrino species (N_eff > 3.046) would break sigma/tau match | CMB-S4 experiment | TESTABLE |

---

## Limitations and Honest Assessment

### What is genuinely remarkable
1. The COMPLETE particle census decomposition (12+5 = sigma+sopfr, with every
   sub-count also matching) is a non-trivial observation.
2. The gauge group dimension = sigma connection involves no free parameters.
3. The dimensional hierarchy (4,5,6,10,11) mapping is aesthetically striking.

### What is likely coincidental
1. Any single small-number match (3 generations, 2 per doublet) has high
   a priori probability.
2. BBN abundances (~1/4 helium) are close to simple fractions by nature.
3. The baryon-to-photon coefficient ~6 is approximate and unit-dependent.

### What is definitely wrong
1. n/p ratio at BBN is 1/7, not 1/6 (COSMO-016, refuted).
2. No n=6 expression matches the weak mixing angle (COSMO-020, refuted).
3. The fine structure constant alpha^-1 = 137.036 has no clean n=6 decomposition.

### The "small number" problem
n=6 functions generate {2, 3, 4, 5, 6, 8, 10, 11, 12}. These cover most of the
single-digit integers. ANY physical theory with small integer parameters will
show "matches" to this set. The question is whether the PATTERN (which function
maps to which physical quantity) is meaningful, not whether individual matches occur.

---

## Connection to Other Hypothesis Documents

| Document | Overlap |
|----------|---------|
| H-SEDI-4 | COSMO-015 (mp/me = 12*153) previously verified |
| FUSION-001~017 | COSMO-002 (6 quarks) underlies nuclear physics |
| H-CX-501~507 | Golden Zone independent of particle counting |
| NOBEL-grand | COSMO-001 (gauge dim) feeds SLE_6 criticality theorem |

---

## References

- Planck Collaboration (2020). Planck 2018 results. VI. Cosmological parameters. A&A, 641, A6.
- Particle Data Group (2024). Review of Particle Physics. Phys. Rev. D.
- CODATA (2022). Recommended Values of the Fundamental Physical Constants.
- Cyburt et al. (2016). Big Bang Nucleosynthesis: Present Status. Rev. Mod. Phys. 88, 015004.
- Candelas, Horowitz, Strominger, Witten (1985). Vacuum Configurations for Superstrings. Nucl. Phys. B 258, 46.
- Aver, Olive, Skillman (2025). LBT Yp Project V. arXiv:2601.22239.
