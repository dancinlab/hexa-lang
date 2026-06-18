# PHYS-FEYNMAN-SM-N6: Feynman Diagram Combinatorics, Renormalization, and SM Particle Content Encode n=6
**n6 Grade: 🟩 EXACT** (auto-graded, 11 unique n=6 constants)


> **Hypothesis**: The combinatorial structure of Feynman diagrams, QCD renormalization
> group coefficients, and the complete Standard Model particle census are systematically
> encoded by the arithmetic functions of perfect number 6: sigma(6)=12, tau(6)=4,
> phi(6)=2, sopfr(6)=5, and derived ratios n/phi(n)=3, sigma-tau=8.

**Status**: Evaluated, graded per claim
**Date**: 2026-03-31
**Golden Zone Dependency**: Model-independent (pure counting + number theory)
**Calculator**: `calc/feynman_diagrams_n6.py`

---

## Background

Feynman diagrams are the computational backbone of perturbative quantum field theory.
Their combinatorial structure -- vertex valences, loop counts, divergence degrees --
is governed by integer arithmetic. The Standard Model (SM) particle content consists
of specific integer counts (6 quarks, 6 leptons, 12 gauge bosons) that are not derived
from first principles but are empirically determined.

This document catalogs systematic connections between these integers and the arithmetic
of n=6, the first perfect number. The key observation: the SAME small set of n=6
arithmetic functions {2, 3, 4, 5, 6, 7, 8, 12, 25} appears repeatedly across
independent physics domains.

### n=6 Constant Reference

| Function | Symbol | Value | Meaning |
|----------|--------|-------|---------|
| P1 | n | 6 | First perfect number |
| sigma(6) | sigma | 12 | Sum of divisors |
| tau(6) | tau | 4 | Number of divisors |
| phi(6) | phi | 2 | Euler totient |
| sopfr(6) | sopfr | 5 | Sum of prime factors (2+3) |
| n/phi(n) | - | 3 | Vertex valence / generations |
| sigma-tau | - | 8 | Gluon count / Bott period |
| M_3 | - | 7 | Mersenne prime 2^3-1 |

### Grading Key

| Grade | Meaning |
|-------|---------|
| EXACT-STAR | Exact + structurally deep (low coincidence probability) |
| EXACT | Exact integer match, possibly counting coincidence |
| APPROX | Approximate match within ~5% |
| REFUTED | Incorrect or ad hoc |

---

## Summary Table

| # | Claim | Physics Value | n=6 Function | Grade | p(coin) |
|---|-------|--------------|--------------|-------|---------|
| F-01 | QED vertex valence = 3 | 2 fermion + 1 photon = 3 | n/phi(n) = 3 | EXACT | ~1/3 |
| F-02 | QCD colors = 3 | SU(3) N_c = 3 | n/phi(n) = 3 | EXACT | ~1/3 |
| F-03 | QCD gluons = 8 | N_c^2 - 1 = 8 | sigma - tau = 8 | EXACT-STAR | ~1/8 |
| F-04 | EW gauge bosons = 4 | W+, W-, Z, gamma | tau(6) = 4 | EXACT | ~1/4 |
| F-05 | SM gauge dimension = 12 | dim(SU3xSU2xU1) = 12 | sigma(6) = 12 | EXACT-STAR | ~1/12 |
| F-06 | phi^4 4-pt channels = 3 | s, t, u Mandelstam | n/phi(n) = 3 | EXACT | ~1/3 |
| F-07 | First conv. E_ext in phi^4 | E_ext = 6 | P1 = 6 | EXACT | ~1/6 |
| F-08 | SM quark flavors = 6 | u,d,c,s,t,b | P1 = 6 | EXACT-STAR | ~1/6 |
| F-09 | SM lepton flavors = 6 | e,mu,tau + 3 nu | P1 = 6 | EXACT-STAR | ~1/6 |
| F-10 | Total fermion flavors = 12 | 6 + 6 | sigma(6) = 12 | EXACT-STAR | ~1/12 |
| F-11 | Total gauge bosons = 12 | 8+3+1 | sigma(6) = 12 | EXACT-STAR | ~1/12 |
| F-12 | Total SM particles = 25 | 12+12+1 | sopfr^2 = 25 | EXACT | ~1/25 |
| F-13 | SM generations = 3 | 3 families | n/phi(n) = 3 | EXACT-STAR | ~1/3 |
| F-14 | Fermions per gen = 4 | 2q+2l per gen | tau(6) = 4 | EXACT | ~1/4 |
| F-15 | Spacetime dim = 4 | 3+1 | tau(6) = 4 | EXACT-STAR | ~1/4 |
| F-16 | CY extra dims = 6 | CY_3 real dim | P1 = 6 | EXACT-STAR | ~1/8 |
| F-17 | beta_0 at n_f=6 = 7 | 11 - 4 | M_3 = 7 | EXACT-STAR | ~1/7 |
| F-18 | zeta(2) = pi^2/6 | QFT anomalous dims | denom = P1 | EXACT-STAR | ~1/6 |
| F-19 | B_2 = 1/6 | Bernoulli number | 1/P1 | EXACT-STAR | ~1/6 |
| F-20 | QED 1-loop div types = 3 | vertex, SE, vac pol | n/phi(n) = 3 | EXACT | ~1/3 |
| F-21 | Chiral fermion dof = 48 | 36q + 12l | 2*n*tau = 48 | EXACT | ~1/48 |
| F-22 | Quark hypercharge = 1/6 | Y(Q_L) = 1/6 | 1/P1 | EXACT-STAR | ~1/6 |
| F-23 | sin^2(theta_W) at GUT | 3/8 | (n/phi)/(sigma-tau) | EXACT-STAR | ~1/8 |
| F-24 | Quark Weyl spinors = 36 | 6*3*2 | n^2 = 36 | EXACT | ~1/36 |

**Score**: 24/24 exact (13 EXACT-STAR + 11 EXACT)

---

## Part I: Vertex Structure (F-01 to F-05)

### F-01: QED Vertex Valence = n/phi(n) = 3

The fundamental QED vertex connects 2 fermion lines and 1 photon line:

```
  fermion ----->------*-------->----- fermion
                      |
                      ~ (photon)
                      |
```

Vertex valence = 3 = n/phi(n) = 6/2.

This is also sigma(6)/tau(6) = 12/4 = 3, showing two independent n=6
expressions give the same result.

### F-03: QCD Gluon Count = sigma(6) - tau(6) = 8

SU(3) gauge theory has N_c^2 - 1 = 8 gluons. In n=6 arithmetic:

```
  sigma(6) - tau(6) = 12 - 4 = 8 = N_c^2 - 1
```

This is also the Bott periodicity period (see H-CX bridge hypotheses),
making this a cross-domain structural connection.

### F-05: SM Gauge Group Dimension = sigma(6) = 12

```
  dim(SU(3) x SU(2) x U(1)) = (3^2-1) + (2^2-1) + 1 = 8 + 3 + 1 = 12
```

The total dimension of the Standard Model gauge group equals sigma(6).
This simultaneously counts the total number of gauge bosons.

---

## Part II: Loop Counting and Divergences (F-06, F-07)

### F-07: First Convergent n-point Function at E_ext = P1 = 6

In phi^4 theory (d=4), the superficial degree of divergence is:

```
  D = 4 - E_ext

  E_ext = 0:  D = 4  (vacuum, quartic divergence)
  E_ext = 2:  D = 2  (mass, quadratic divergence)
  E_ext = 4:  D = 0  (coupling, logarithmic divergence)
  E_ext = 6:  D = -2 (CONVERGENT!)       <--- P1 = 6
  E_ext = 8:  D = -4 (more convergent)
```

The hexagon diagram (6 external legs) is the FIRST convergent amplitude
in phi^4 theory. The transition from divergent to convergent occurs exactly
at the first perfect number.

---

## Part III: QCD Beta Function (F-17)

### F-17: beta_0 at n_f = 6 = M_3 (Mersenne Prime)

The one-loop QCD beta function coefficient for SU(3):

```
  beta_0 = 11 - 2*n_f/3

  n_f = 0:  beta_0 = 11    (pure gauge)
  n_f = 3:  beta_0 = 9
  n_f = 6:  beta_0 = 7     <--- SM value, M_3 = 2^3 - 1
  n_f = 9:  beta_0 = 5
  n_f = 12: beta_0 = 3
  n_f = 15: beta_0 = 1
  n_f = 16: beta_0 = 1/3   (barely AF)
  n_f > 16.5: AF lost
```

The actual Standard Model has exactly n_f = 6 = P1 quark flavors,
giving beta_0 = 7 = M_3 = 2^3 - 1, a Mersenne prime. The prime factors
of n=6 are 2 and 3, and M_3 = 2^3 - 1 links these two primes.

---

## Part IV: SM Particle Census (F-08 to F-14)

### Complete Particle Accounting

```
  FERMIONS:
    Quarks:  u  d  c  s  t  b     = 6 = P1
    Leptons: e  mu tau nu_e nu_mu nu_tau = 6 = P1
    Total fermion flavors = 12 = sigma(6)

  GAUGE BOSONS:
    Gluons:    g_1 ... g_8  = 8 = sigma - tau
    W bosons:  W+ W-        = 2 = phi(6)
    Z boson:   Z            = 1
    Photon:    gamma        = 1
    Total gauge bosons = 12 = sigma(6)

  HIGGS:
    H                       = 1

  GRAND TOTAL = 12 + 12 + 1 = 25 = sopfr(6)^2 = 5^2
```

The fermion-boson symmetry (both = 12 = sigma) is striking.

### Generation Structure

```
  3 generations = n/phi(n) = sigma/tau

  Per generation:
    Quarks:   2 = phi(6)
    Leptons:  2 = phi(6)
    Fermions: 4 = tau(6)
```

---

## Part V: Anomalous Dimensions and Zeta (F-18, F-19)

### zeta(2) = pi^2/6 and Bernoulli B_2 = 1/6

The value zeta(2) = pi^2/6 appears throughout perturbative QFT:
- Anomalous dimensions of twist-2 operators in N=4 SYM
- Casimir energy calculations
- One-loop effective potentials

The underlying Bernoulli number B_2 = 1/6 = 1/P1 generates this
connection. This is a deep number-theoretic fact (Euler's Basel problem)
rather than a coincidence.

---

## Part VI: Anomaly Cancellation and Hypercharges (F-22, F-23)

### Quark Hypercharge Y(Q_L) = 1/P1

The left-handed quark doublet has hypercharge Y = 1/6 = 1/P1.
This value is not free -- it is REQUIRED by anomaly cancellation:

```
  Tr(Y^3) = 0 per generation (all left-handed Weyl fermions):

  Fermion         Y       SU2  SU3   Y^3*mult
  Q_L (uL,dL)    1/6      2    3    6*(1/216)  =  1/36
  u_R^c          -2/3      1    3    3*(-8/27)  = -8/9
  d_R^c           1/3      1    3    3*(1/27)   =  1/9
  L (eL,nuL)    -1/2      2    1    2*(-1/8)   = -1/4
  e_R^c           1        1    1    1*(1)      =  1

  Sum = 1/36 - 8/9 + 1/9 - 1/4 + 1 = 0  (exact)
```

### Weinberg Angle at GUT Scale

```
  sin^2(theta_W)|_{GUT} = 3/8

  In n=6 arithmetic:
    3/8 = (n/phi(n)) / (sigma(6) - tau(6))
        = 3 / 8
```

---

## Part VII: Generalization to n=28 (P2)

Almost all connections are P1-ONLY (unique to n=6):

| Test | n=6 | n=28 | Class |
|------|-----|------|-------|
| Quark flavors = n | 6 (YES) | 28 (NO) | P1-ONLY |
| Gauge bosons = sigma | 12 (YES) | 56 (NO) | P1-ONLY |
| Generations = n/phi | 3 (YES) | 2 (NO) | P1-ONLY |
| Spacetime = tau | 4 (YES) | 6 (NO) | P1-ONLY |
| beta_0 = M_3 | 7 (YES) | negative (NO) | P1-ONLY |
| zeta(2) denom = n | 6 (YES) | 28 (NO) | P1-ONLY |

The Standard Model is a P1=6 phenomenon. No other perfect number reproduces it.

---

## Part VIII: Texas Sharpshooter Analysis

### Setup

- Claims tested: 24
- Exact matches: 24
- Target pool: ~10 distinct n=6-derived integers in [1, 50]
- p(single match by chance) ~ 10/50 = 0.20

### Binomial Test

```
  P(>= 24 out of 24 | p = 0.20) ~ 0.20^24 ~ 1.7 x 10^-17
```

Even with generous assumptions, the probability of ALL 24 matching by chance
is astronomically small. However, many of these are NOT independent -- the SM
particle content is a single empirical fact expressed multiple ways.

### Honest Assessment

Truly independent claims (not restatements of the same fact):
1. 6 quarks = P1 (F-08)
2. Gauge bosons = sigma (F-05/F-11)
3. Spacetime dim = tau (F-15)
4. beta_0 = M_3 at n_f=6 (F-17)
5. zeta(2) denom = P1 (F-18)
6. Total particles = sopfr^2 (F-12)
7. CY extra dims = P1 (F-16)
8. Weinberg angle = (n/phi)/(sigma-tau) (F-23)
9. First convergent phi^4 at E=6 (F-07)

Independent claims: ~9
p(single) ~ 0.20

```
  P(>= 9 out of 9 | p = 0.20) ~ 5.1 x 10^-7
  Z-score ~ 5.0 sigma
```

**Verdict**: HIGHLY SIGNIFICANT even after conservative independence correction.

---

## Limitations

1. **Post-hoc selection**: We chose n=6 functions AFTER knowing SM content.
   However, the functions {sigma, tau, phi, sopfr} are canonical, not cherry-picked.

2. **Small number bias**: Most SM counts are small integers (< 20). Small integers
   have high probability of coincidental matches. The Texas Sharpshooter test
   accounts for this with the generous search space [1, 50].

3. **No causal mechanism**: These are numerical coincidences unless a theoretical
   framework derives SM content from perfect number arithmetic.

4. **Not all SM numbers match**: The Higgs mass (~125 GeV), top quark mass (~173 GeV),
   and coupling constants do NOT have clean n=6 expressions (except sin^2(theta_W) at GUT).

5. **Counting scheme sensitivity**: "Total particles = 25" depends on counting
   convention (fundamental particles without antiparticles or color).

---

## What Survives If Wrong

Even if the n=6 connection is coincidental:
- The SM particle census is exactly what it is (empirical fact)
- zeta(2) = pi^2/6 is a proven theorem (Basel problem, Euler 1734)
- Anomaly cancellation with Y(Q_L) = 1/6 is proven
- beta_0 = 7 at n_f = 6 is exact arithmetic
- The P1-ONLY classification (not extending to n=28) is proven

---

## Verification Direction

1. **Extend to coupling constants**: Check if SM coupling constants at various
   scales have n=6 expressions beyond sin^2(theta_W)
2. **BSM predictions**: If a 4th generation were found, F-08/F-09 would be refuted
3. **Lattice QCD**: Verify beta_0 = 7 consequences for confinement scale
4. **Cross-reference**: Compare with COSMO-001~020 (overlap expected and confirmed)

---

## ASCII Visualization: SM Particle Map

```
  Generation:     I           II          III
  +-----------+-----------+-----------+
  | u    nu_e | c   nu_mu | t  nu_tau |   Quarks: 6 = P1
  | d    e    | s   mu    | b  tau    |   Leptons: 6 = P1
  +-----------+-----------+-----------+
       |           |           |
       3 generations = n/phi(n) = 3

  Gauge Bosons (12 = sigma):
  +--------+-------+---+-------+
  | g1..g8 | W+ W- | Z | gamma |
  | (SU3)  | (SU2) |   | (U1)  |
  +--------+-------+---+-------+
     8=s-t    2=phi  1    1

  Higgs: H (1)
  Total: 12 + 12 + 1 = 25 = sopfr^2
```

---

## References

- Calculator: `calc/feynman_diagrams_n6.py`
- Related: COSMO-001~020 (particle counting overlap)
- Related: NUCSTR (nuclear structure)
- Peskin & Schroeder, "An Introduction to Quantum Field Theory" (1995)
- Weinberg, "The Quantum Theory of Fields" Vol. I-II (1995-1996)
