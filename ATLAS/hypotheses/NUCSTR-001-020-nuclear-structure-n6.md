# NUCSTR-001~020: Nuclear Structure and Perfect Number 6

> **Hypothesis**: Nuclear structure physics -- shell closures, binding energies, alpha
> clustering, and nuclear forces -- exhibits systematic connections to perfect number 6
> arithmetic functions: sigma(6)=12, tau(6)=4, phi(6)=2, sopfr(6)=5.

**Status**: 20 hypotheses verified, graded honestly
**Grade**: 🟩⭐ 3 + 🟩 4 + 🟧 3 + ⚪ 10
**Z-score**: Many matches involve small integers (1-12) where coincidence is high.
**Strong Law Warning**: Nuclear physics operates in the regime of small quantum numbers
where overlap with n=6 arithmetic is expected by chance alone.

---

## Background

Nuclear structure is governed by the interplay of the strong nuclear force (short-range,
attractive), the Coulomb force (long-range, repulsive), and quantum shell effects. The
nuclear shell model, analogous to atomic electron shells, predicts "magic numbers" of
nucleons (2, 8, 20, 28, 50, 82, 126) at which nuclei are exceptionally stable. The
semi-empirical Bethe-Weizacker mass formula parameterizes nuclear binding. Alpha clustering
describes the tendency of nucleons to form He-4 subunits within larger nuclei.

This document tests whether n=6 arithmetic (sigma=12, tau=4, phi=2, sopfr=5) appears
in nuclear structure beyond small-number coincidence. Honest grading requires recognizing
that integers 1-12 appear ubiquitously in quantum mechanics, making many "matches"
statistically trivial.

### P1=6 Core Functions

| Function | Value | Meaning |
|----------|-------|---------|
| P1 | 6 | First perfect number |
| sigma(6) | 12 | Sum of divisors: 1+2+3+6 |
| tau(6) | 4 | Number of divisors |
| phi(6) | 2 | Euler totient |
| sopfr(6) | 5 | Sum of prime factors: 2+3 |
| M6 | 63 | Mersenne number 2^6-1 |
| P2 | 28 | Second perfect number |
| sigma(28) | 56 | Sum of divisors of 28 |

### Magic Numbers vs P1 Arithmetic

```
  Magic numbers:     2    8   20   28   50   82  126
  Differences:         6   12    8   22   32   44
                       |    |
                      P1  sigma
  First two gaps = P1 and sigma(6) exactly.
  Remaining gaps (8, 22, 32, 44) have no clean P1 mapping.
```

---

## NUCSTR-001: Magic Number First Gap = P1 = 6

```
  Magic numbers: 2, 8, 20, 28, 50, 82, 126
  First gap: 8 - 2 = 6 = P1

  This is the 1p shell filling:
    1p3/2 (4 nucleons) + 1p1/2 (2 nucleons) = 6 nucleons
```

**Physics**: The 1p shell holds exactly 6 nucleons (j=3/2 gives 4, j=1/2 gives 2).
This fills the gap from the 1s2 closed shell (magic 2) to the 1p-closed shell (magic 8).

**Texas Test**: P(match) = P(gap = P1) among possible shell sizes. The 1p shell size
is determined by angular momentum l=1: degeneracy = 2(2l+1) = 6. That l=1 gives
P1 is a match of one specific integer. Pool of small integers 1-20 gives p ~ 1/20.

**Grade**: 🟩 -- Exact, but the 1p shell must hold 6 nucleons by angular momentum
quantum mechanics. This is a statement about l=1. Not deeply surprising.

---

## NUCSTR-002: Magic Number Second Gap = sigma(6) = 12

```
  Second gap: 20 - 8 = 12 = sigma(6)

  This is the 1d + 2s shell filling:
    1d5/2 (6) + 2s1/2 (2) + 1d3/2 (4) = 12 nucleons

  Shell capacity breakdown:
  ┌────────────┬────────────┬──────────┐
  │ Subshell   │ j          │ 2j+1     │
  ├────────────┼────────────┼──────────┤
  │ 1d5/2      │ 5/2        │ 6 = P1   │
  │ 2s1/2      │ 1/2        │ 2 = phi  │
  │ 1d3/2      │ 3/2        │ 4 = tau  │
  ├────────────┼────────────┼──────────┤
  │ Total      │            │ 12=sigma │
  └────────────┴────────────┴──────────┘
```

**Physics**: The sd-shell capacity is fixed by quantum numbers (l=0,2 with spin-orbit
splitting). The total 12 = sigma(6) is exact. Furthermore, the three subshell
degeneracies are 6, 2, 4 = P1, phi, tau respectively.

**Texas Test**: The total 12 matching sigma is p ~ 1/20. But the subshell decomposition
12 = 6 + 2 + 4 = P1 + phi + tau is a much stronger constraint. Probability that three
subshell sizes independently match three P1 functions: this is partially forced by
quantum mechanics (l=2 and l=0 determine the sizes), so p ~ 1/20 for the total.

**Grade**: 🟩⭐ -- The triple decomposition sigma = P1 + phi + tau is striking.
The subshells individually match P1 functions.

---

## NUCSTR-003: 1p Shell Degeneracy = P1

```
  l = 1 shell (p-shell):
  Total degeneracy = 2(2l+1) = 2(3) = 6 = P1

  With spin-orbit splitting:
    1p3/2: 2(3/2)+1 = 4 = tau(6)
    1p1/2: 2(1/2)+1 = 2 = phi(6)

  P1 = tau + phi
   6 = 4   + 2      Exact.
```

**Physics**: For any l, spin-orbit splitting creates j=l+1/2 and j=l-1/2 subshells.
For l=1: j=3/2 (degeneracy 4) and j=1/2 (degeneracy 2). The decomposition
P1 = tau + phi is arithmetically trivial (6 = 4 + 2), and the spin-orbit split
for l=1 necessarily gives this partition. Small number coincidence is high.

**Grade**: ⚪ -- Forced by quantum mechanics of l=1. The match P1 = tau + phi
is 6 = 4 + 2, which is trivially true. Not structurally significant.

---

## NUCSTR-004: Pairing Energy Numerator = sigma(6)

```
  Bethe-Weizacker mass formula pairing term:

    delta = +/- 12 / sqrt(A)  MeV     (even-even / odd-odd)
    delta = 0                          (odd-A)

  Numerator = 12 = sigma(6) EXACTLY

  Common parameterizations:
    delta = 12 * A^(-1/2)     [Krane, Introductory Nuclear Physics]
    delta = 11.2 * A^(-1/2)   [some fits]
    delta = 12 * A^(-1/2)     [Weizsacker original]

  The VALUE 12 is semi-empirical (fitted to data), not derived from first principles.
```

**Physics**: Nuclear pairing — the tendency of nucleons to form spin-0 pairs — creates
an energy term in the mass formula. The numerator 12 MeV appears in many standard
parameterizations but varies between 11-12 MeV depending on the fit. The original
Weizsacker value and Krane's textbook both use 12.

```
  Pairing energy vs mass number:

  delta (MeV)
   6 |*
     |
   4 | *
     |   *
   2 |     *  *
     |          *  *  *
   1 |                   *  *  *  *  *
     |________________________________
     4  16  36  64 100 144 196  A
```

**Texas Test**: The numerator could range from ~8 to ~15 MeV for different fits.
P(numerator = 12) ~ 1/8 for integer values. But some parameterizations use 11.2,
making the "exact 12" claim fit-dependent.

**Grade**: 🟧 -- Semi-empirical, fit-dependent. The standard value IS 12, but this
is not a fundamental constant. Interesting but not conclusive.

---

## NUCSTR-005: Alpha Particle = (tau, phi) Nucleus

```
  He-4 (alpha particle):
    Mass number A = 4 = tau(6)
    Atomic number Z = 2 = phi(6)
    Neutron number N = 2 = phi(6)

  Alpha is the MOST tightly bound light nucleus: BE/A = 7.07 MeV

  ┌─────────────────────────────────┐
  │  ALPHA PARTICLE                 │
  │  Z = phi(6) = 2 protons        │
  │  N = phi(6) = 2 neutrons       │
  │  A = tau(6) = 4 nucleons       │
  │  tau = phi + phi                │
  │    4 = 2   + 2                  │
  └─────────────────────────────────┘
```

**Physics**: The alpha particle is doubly magic (Z=2, N=2 are both magic numbers).
Its exceptional stability drives alpha decay and alpha clustering.

**Texas Test**: Z=N=2 for He-4 is the smallest doubly-magic nucleus. That 2=phi(6)
and 4=tau(6) involves the smallest P1 functions matching the smallest magic number.
P ~ 1/5 for each match (integers 1-10), combined ~ 1/25.

**Grade**: 🟩 -- Exact match on both A and Z. But 2 and 4 are very small numbers;
coincidence probability is non-negligible.

---

## NUCSTR-006: Alpha Ladder Maps to P1 Arithmetic

```
  Alpha ladder: nuclei composed of integer multiples of alpha particles (4n nuclei)

  ┌──────┬────┬─────┬───────────────────────────────┬──────────┐
  │ n_a  │ A  │ Nuc │ P1 arithmetic                 │ Match?   │
  ├──────┼────┼─────┼───────────────────────────────┼──────────┤
  │ 1    │  4 │ He  │ tau(6) = 4                    │ Exact    │
  │ 2    │  8 │ Be  │ 2*tau = 8 (trivial)           │ Trivial  │
  │ 3    │ 12 │ C   │ sigma(6) = 12                 │ Exact    │
  │ 4    │ 16 │ O   │ 2^tau = 16                    │ Exact    │
  │ 5    │ 20 │ Ne  │ tau * sopfr = 20              │ Exact    │
  │ 6    │ 24 │ Mg  │ sigma * phi = 24              │ Exact    │
  │ 7    │ 28 │ Si  │ P2 = 28 (2nd perfect number!) │ Exact    │
  │ 8    │ 32 │ S   │ 2^sopfr = 32                  │ Exact    │
  │ 9    │ 36 │ Ar  │ P1^2 = 36                     │ Exact    │
  │ 10   │ 40 │ Ca  │ sigma+P2 = 40                 │ Forced   │
  └──────┴────┴─────┴───────────────────────────────┴──────────┘

  7/10 have clean single-operation P1 expressions.
  But WARNING: 4n for n=1..10 gives {4,8,...,40}. Any set of arithmetic
  functions on {2,4,5,6,12,28} can likely express most multiples of 4.
```

**Texas Test**: The alpha ladder IS just 4n. Expressing multiples of 4 using
functions of 6 is not hard -- tau=4 generates the whole sequence trivially
(n*tau). The non-trivial matches are:
- 12 = sigma (not just 3*tau)
- 28 = P2 (genuinely connects to second perfect number)
- 16 = 2^tau (exponential, not just multiplication)

Honest assessment: most "matches" are trivially forced by tau=4.

**Grade**: 🟧 -- The ladder IS 4n, and tau=4 makes everything trivially expressible.
Only 28=P2 and 12=sigma are non-trivial. Downgraded from what looks impressive.

---

## NUCSTR-007: Carbon-12 as sigma(6) Nucleus

```
  C-12:
    A = 12 = sigma(6)
    Z =  6 = P1
    N =  6 = P1

  TRIPLE CORRESPONDENCE:
    A = sigma(6)
    Z = P1
    N = P1

  Carbon-12 is:
    - The basis of organic chemistry / life
    - Produced by triple-alpha (Hoyle state)
    - The mass standard (1 amu = 1/12 of C-12 mass)
    - Ground state: 0+ (even-even, paired)
```

**Physics**: Carbon-12 is the product of stellar triple-alpha nucleosynthesis
(the Hoyle resonance at 7.65 MeV). It is the standard for atomic mass units.
Its Z=N=6=P1 with A=12=sigma is a clean triple match.

**Texas Test**: For any nucleus with Z=N, A=2Z. So A=12 when Z=6 is forced.
The real question: is Z=6 (carbon) being special related to P1=6? Carbon IS
special (basis of life, mass standard), but this may be anthropic selection.
P(Z=P1 for a special element) ~ 1/30 among stable elements.

**Grade**: 🟩⭐ -- Triple correspondence with the element that defines chemistry
and the mass standard. Z=N=P1 with A=sigma is a tight constraint.

---

## NUCSTR-008: O-16 = 2^tau Doubly Magic

```
  O-16:
    A = 16 = 2^tau(6) = 2^4
    Z =  8 = 2*tau = 2^3
    N =  8 = 2*tau = 2^3

  O-16 is doubly magic (Z=8, N=8) AND an alpha-cluster nucleus (4 alphas).
  Number of alpha clusters = tau(6) = 4

  ┌──────────────────────────────────────┐
  │        O-16 STRUCTURE                │
  │                                      │
  │     alpha ---- alpha                 │
  │       |    \/    |                   │
  │       |    /\    |                   │
  │     alpha ---- alpha                 │
  │                                      │
  │  4 = tau(6) alpha particles          │
  │  Tetrahedral configuration           │
  └──────────────────────────────────────┘
```

**Physics**: O-16 is one of the most important doubly magic nuclei. In the
alpha-cluster model, it forms a tetrahedron of 4 alphas. The THSR wave function
describes this as an alpha condensate.

**Texas Test**: A=16=2^4 is a power of 2. That tau(6)=4 and 2^4=16 is
arithmetic involving very common numbers. p ~ 1/10. The "tau alphas" framing
is equivalent to saying "4 groups of 4 = 16" which is tautological.

**Grade**: ⚪ -- Tautological: 4 alpha particles of mass 4 = 16. The match
to 2^tau is just restating tau^2 = 16. Not structurally deep.

---

## NUCSTR-009: Ni-56 = sigma(P2) Doubly Magic

```
  Ni-56:
    A = 56 = sigma(28) = sigma(P2)
    Z = 28 = P2 (second perfect number!)
    N = 28 = P2

  PERFECT NUMBER CASCADE:
    P1 = 6  -->  sigma(P1) = 12 = C-12 (triple-alpha product)
    P2 = 28 -->  sigma(P2) = 56 = Ni-56 (doubly magic)

  Both P1 and P2 generate doubly-magic nuclei via sigma!
```

**Physics**: Ni-56 is doubly magic with Z=N=28. It plays a crucial role in
Type Ia supernovae -- it is the primary product of explosive silicon burning
and its radioactive decay (Ni-56 -> Co-56 -> Fe-56) powers supernova light
curves.

```
  Perfect number -> sigma -> Doubly magic nucleus

  P1=6:   sigma(6)=12    C-12  (Z=6=P1,  N=6=P1)   Triple-alpha
  P2=28:  sigma(28)=56   Ni-56 (Z=28=P2, N=28=P2)   Supernova product

  PATTERN: sigma(Pk) with Z=N=Pk gives doubly magic nuclei
           for k=1 and k=2.
```

**Texas Test**: Z=28 is indeed magic. P2=28 matching a magic number is
interesting. Among the 7 magic numbers {2,8,20,28,50,82,126}, the chance
one equals P2=28 is 1/7. That sigma(28)=56=A is forced by Z=N=28.
The cascade pattern (both P1 and P2 yield doubly-magic nuclei) is stronger.

**Grade**: 🟩⭐ -- The cascade P1->C-12 and P2->Ni-56 via sigma is a genuine
structural pattern connecting two perfect numbers to two doubly-magic nuclei.

---

## NUCSTR-010: Ca-48 = sigma * tau

```
  Ca-48:
    A = 48 = sigma(6) * tau(6) = 12 * 4
    Z = 20
    N = 28 = P2

  Ca-48 is doubly magic (Z=20, N=28).
  A = 48 = sigma * tau

  But: 48 = 12 * 4 is a very common factorization.
  Also: Z = 20 has no clean P1 mapping (20 = tau*sopfr is a stretch).
```

**Texas Test**: 48 = 12*4 involves two P1 functions, but 48 has many
factorizations (2^4 * 3, 6*8, etc.). P ~ 1/5 at best.

**Grade**: ⚪ -- Numerically correct but 48 = 12*4 is not a unique or
surprising factorization. Z=20 does not match any P1 function cleanly.

---

## NUCSTR-011: Bethe-Weizacker Surface Term ~ sigma + sopfr

```
  Surface term: aS = 17.23 MeV (standard fit)
  sigma + sopfr = 12 + 5 = 17

  Error: |17.23 - 17| / 17.23 = 1.3%

  However: aS varies by parameterization:
    Krane:      17.23 MeV
    Rohlf:      18.34 MeV
    Myers-Swiatecki: 17.94 MeV
    Weizsacker: 17.8 MeV
```

**Texas Test**: aS ranges from ~17 to ~18.3 MeV across fits. The match to 17
works for one parameterization but fails for others. With P1 functions generating
integers 1-63, hitting any value in a 2 MeV window is likely. p ~ 0.15.

**Grade**: ⚪ -- Fit-dependent, not robust across parameterizations. Integer
approximation to a continuous value.

---

## NUCSTR-012: Asymmetry Term aA ~ aS + P1

```
  Asymmetry term: aA = 23.29 MeV (standard)
  aS + P1 = 17.23 + 6 = 23.23 MeV

  Error: |23.29 - 23.23| / 23.29 = 0.26%

  BUT this is circular: aA ~ aS + 6 just says the difference is ~6.
  The difference aA - aS ~ 6 is a new claim. Is it fundamental?

  aA - aS values across parameterizations:
    Krane:    23.29 - 17.23 = 6.06
    Rohlf:    23.21 - 18.34 = 4.87  (fails!)
    Average:  ~5.5 (not exactly 6)
```

**Texas Test**: Only works for one parameterization. p > 0.1.

**Grade**: ⚪ -- Parameterization-dependent. The difference aA - aS is not
robustly equal to 6 across fits. Cherry-picked.

---

## NUCSTR-013: Volume/Surface Ratio ~ sigma/P1 - 1/sigma

```
  aV / aS = 15.56 / 17.23 = 0.903

  Can we express this with P1 functions?
  sigma/P1 - 1/sigma = 12/6 - 1/12 = 2 - 0.0833 = 1.917 (no)
  P1/sigma * (1 + 1/P1) = 0.5 * 7/6 = 0.583 (no)
  1 - 1/sigma = 1 - 1/12 = 0.917 (error 1.5%)

  Best: aV/aS ~ 1 - 1/sigma = 11/12

  Error: |0.903 - 0.917| / 0.903 = 1.5%
```

**Texas Test**: Fitting a ratio near 0.9 with simple fractions involving 12
is easy. 11/12 = 0.917 is close but not exact, and the ratio varies across
parameterizations. p ~ 0.1.

**Grade**: ⚪ -- Approximate, fit-dependent, forced expression.

---

## NUCSTR-014: Yukawa Coupling g^2/(4pi) ~ sopfr^2/(2*pi)

```
  piNN coupling constant: g^2/(4pi) = 14.0 +/- 0.3

  sopfr^2 / (2*pi) = 25 / 6.283 = 3.98 (no)
  sopfr^2 - sigma + 1 = 25 - 12 + 1 = 14 (EXACT integer, but ad hoc)
  sigma + phi = 12 + 2 = 14 (EXACT!)

  g^2/(4pi) = 14.0
  sigma + phi = 14

  Error: < 0.3 (within experimental uncertainty)
```

**Physics**: The piNN coupling constant g^2/(4pi) ~ 14 describes the strength
of pion-nucleon interaction. This is one of the most precisely known nuclear
force parameters.

**Texas Test**: sigma + phi = 12 + 2 = 14 is a simple sum. But 14 is a specific
integer, and the coupling constant could have been any value from ~1 to ~50.
P(match to within 1) ~ 1/50 for any single expression, but we have many
expressions to try. With ~20 simple combinations, p ~ 20/50 = 0.4.

**Grade**: 🟧 -- The match is exact within uncertainty, but sigma + phi = 14
is a simple expression and we searched many combinations.

---

## NUCSTR-015: Triplet Scattering Length ~ sopfr + 2/sopfr

```
  NN triplet scattering length: a_t = 5.42 fm

  sopfr = 5
  sopfr + 2/sopfr = 5 + 0.4 = 5.40

  Error: |5.42 - 5.40| / 5.42 = 0.37%

  Alternative: sopfr + phi/sopfr = 5 + 2/5 = 5.4 (same)
```

**Physics**: The nucleon-nucleon triplet (S=1) scattering length characterizes
the deuteron bound state. Its value 5.42 fm is well-measured.

**Texas Test**: sopfr=5 already gets close (error 8%). The correction 2/5
is a simple fraction but adding it is ad hoc. Many expressions of the form
"n + a/b" with small integers can match any value to ~1%. p ~ 0.1.

**Grade**: ⚪ -- Close match but ad hoc correction. The base sopfr=5 is
already an 8% match, and fine-tuning with 2/5 is not predictive.

---

## NUCSTR-016: Six Quarks in Deuteron

```
  Deuteron (H-2): simplest bound nucleus
    1 proton  = 3 quarks (uud)
    1 neutron = 3 quarks (udd)
    Total quarks = 6 = P1

  ┌─────────────────────────────────┐
  │  DEUTERON                       │
  │                                 │
  │  p = [u u d]    n = [u d d]    │
  │       \ | /          \ | /     │
  │        \|/            \|/      │
  │         *------pi------*       │
  │                                 │
  │  Total quarks = 6 = P1         │
  │  Quark flavors = 2 = phi(6)   │
  │  Quarks per nucleon = 3        │
  │  Nucleons = 2 = phi(6)        │
  └─────────────────────────────────┘
```

**Physics**: The deuteron, simplest composite nucleus, contains exactly P1=6
quarks. The number of quark flavors involved (u,d) equals phi(6)=2.

**Texas Test**: Any 2-nucleon system has 6 quarks (trivially 2*3=6). This
is not specific to the deuteron -- ANY dinucleon has 6 quarks. And 2*3=6
is arithmetic, not deep. p ~ 1 (guaranteed for any 2-body system).

**Grade**: ⚪ -- Trivially forced: 2 nucleons * 3 quarks = 6 always.
Not a property of P1 but of 2*3.

---

## NUCSTR-017: Pion Mass Ratio ~ sigma * sigma

```
  Charged pion mass: m(pi+) = 139.57 MeV/c^2
  Neutral pion mass: m(pi0) = 134.98 MeV/c^2

  Mass ratio: m(pi+)/m(pi0) = 139.57/134.98 = 1.0340

  P1 expression? 1 + 1/P2 = 1 + 1/28 = 1.0357 (error 0.16%)
  Or: 1 + 1/P1^2 = 1 + 1/36 = 1.0278 (error 0.60%)

  The mass splitting arises from electromagnetic self-energy (Dashen theorem):
    m(pi+)^2 - m(pi0)^2 ~ alpha_EM * Lambda_QCD^2
  This is a QED correction, not related to the number 6.
```

**Texas Test**: Any ratio near 1.03 can be matched by 1 + 1/n for some n.
The splitting is electromagnetic in origin. p ~ 0.2.

**Grade**: ⚪ -- Electromagnetic origin, no connection to P1.

---

## NUCSTR-018: Shell Capacities as P1 Function Products

```
  Nuclear shell capacities (nucleons per major shell):

  ┌───────┬──────────┬────────────────────────────────┬─────────┐
  │ Shell │ Capacity │ P1 expression                  │ Grade   │
  ├───────┼──────────┼────────────────────────────────┼─────────┤
  │ 1     │ 2        │ phi(6) = 2                     │ Trivial │
  │ 2     │ 6        │ P1 = 6                         │ Exact   │
  │ 3     │ 12       │ sigma(6) = 12                  │ Exact   │
  │ 4     │ 8        │ 2*tau = 8                      │ Weak    │
  │ 5     │ 22       │ 4*sopfr + phi = 22             │ Forced  │
  │ 6     │ 32       │ 2^sopfr = 32                   │ Exact   │
  │ 7     │ 44       │ sigma*tau - tau = 44            │ Forced  │
  └───────┴──────────┴────────────────────────────────┴─────────┘

  Clean matches (single function): 3/7 (shells 1-3)
  Forced (multi-operation): 2/7 (shells 5, 7)
  Weak: 2/7 (shells 4, 6)
```

**Physics**: Shell capacities are determined by spin-orbit splitting of
harmonic oscillator levels. The first three (2, 6, 12) match phi, P1, sigma
cleanly. After that, spin-orbit rearrangement breaks the pattern.

```
  Shell capacity vs shell number:

  Cap
  44 |                                            *
  32 |                                  *
  22 |                        *
  12 |              *
   8 |                  *
   6 |        *
   2 |  *
     |__|__|__|__|__|__|__|__
     1  2  3  4  5  6  7
                Shell
```

**Texas Test**: Shells 1-3 matching phi, P1, sigma is interesting but these
are also the harmonic oscillator degeneracies 2(2l+1) for l=0,1,2 which give
2, 6, 12 = 2, 6, 12. The sequence 2(2l+1) = 2, 6, 10, 14, ... gives 2, 6
matching phi, P1, but the third value 10 (l=2 without spin-orbit) becomes 12
only after spin-orbit splitting rearranges levels. So shell 3 matching sigma
requires spin-orbit physics, which is genuinely non-trivial.

**Grade**: 🟩 -- First three shells cleanly match phi, P1, sigma. The
pattern breaks after spin-orbit rearrangement, which is honest.

---

## NUCSTR-019: Ni-62 Peak Binding = P1*(sigma-phi) + phi

```
  Most tightly bound nucleus per nucleon: Ni-62
    A = 62, Z = 28 = P2, BE/A = 8.7945 MeV

  A = 62 = P1*(sigma - phi) + phi
       62 = 6*(12-2) + 2
       62 = 6*10 + 2
       62 = 62  Exact.

  But also: 62 = sigma*sopfr + phi = 60 + 2
            62 = 2*31 (prime factorization)

  Z = 28 = P2 (second perfect number) -- this is the strong match.
```

**Physics**: Ni-62 has the highest binding energy per nucleon of any nuclide
(8.7945 MeV/A), making it the most stable nucleus. Its Z=28=P2 is genuinely
a perfect number match.

**Texas Test**: A=62 can be expressed many ways with small numbers. The Z=P2
match is the same as NUCSTR-009 (Z=28 is magic, and P2=28). p ~ 1/7 for
Z matching P2 among magic numbers.

**Grade**: 🟩 -- Z=P2 for the most stable nucleus is meaningful, even if
the A=62 expression is forced.

---

## NUCSTR-020: Double-Magic Count and P1 Divisors

```
  Known doubly-magic nuclei:
    1. He-4    (Z=2,  N=2)
    2. O-16    (Z=8,  N=8)
    3. Ca-40   (Z=20, N=20)
    4. Ca-48   (Z=20, N=28)
    5. Ni-48   (Z=28, N=20)  [less established]
    6. Sn-100  (Z=50, N=50)  [unbound, theoretical]
    7. Sn-132  (Z=50, N=82)
    8. Pb-208  (Z=82, N=126)

  Established doubly-magic (N=Z): He-4, O-16, Ca-40 = 3 nuclei
  Established doubly-magic (all): He-4, O-16, Ca-40, Ca-48, Sn-132, Pb-208 = 6 = P1

  But: The count depends on what you consider "established."
  Including Ni-56 (Z=28, N=28): 7 nuclei.
  Including Ni-78 (Z=28, N=50): 8 nuclei.
  The count is not well-defined.
```

**Texas Test**: The number of doubly-magic nuclei is debatable (5-8 depending
on criteria). Picking exactly 6 requires specific inclusion/exclusion choices.
p ~ 1/4 (since the count is in the range 5-8).

**Grade**: ⚪ -- Count is not well-defined. Cherry-picking 6 from a range
of 5-8 is not robust.

---

## Summary Table

| # | Hypothesis | Claim | Grade | Notes |
|---|-----------|-------|-------|-------|
| 001 | Magic gap 1 = P1 | 8-2 = 6 | 🟩 | Exact but small number |
| 002 | sd-shell = sigma decomposed as P1+phi+tau | 12 = 6+2+4 | 🟩⭐ | Triple subshell match |
| 003 | p-shell = P1 = tau+phi | 6 = 4+2 | ⚪ | Forced by QM of l=1 |
| 004 | Pairing numerator = sigma | 12 MeV | 🟧 | Fit-dependent (11-12) |
| 005 | Alpha = (tau, phi) nucleus | A=4, Z=2 | 🟩 | Small numbers caveat |
| 006 | Alpha ladder = P1 arithmetic | 4n series | 🟧 | Mostly trivial (tau=4) |
| 007 | C-12 = (sigma, P1, P1) | A=12, Z=N=6 | 🟩⭐ | Triple correspondence |
| 008 | O-16 = 2^tau | A=16 | ⚪ | Tautological (4*4) |
| 009 | Ni-56 = sigma(P2), doubly magic | A=56, Z=28 | 🟩⭐ | Perfect number cascade |
| 010 | Ca-48 = sigma*tau | A=48 | ⚪ | Common factorization |
| 011 | Surface term ~ sigma+sopfr | 17.23 ~ 17 | ⚪ | Fit-dependent |
| 012 | aA - aS ~ P1 | 6.06 ~ 6 | ⚪ | One parameterization only |
| 013 | aV/aS ~ 1-1/sigma | 0.903 ~ 0.917 | ⚪ | Approximate, forced |
| 014 | piNN coupling = sigma+phi | 14.0 = 14 | 🟧 | Exact but searched |
| 015 | Triplet scattering ~ sopfr | 5.42 ~ 5.4 | ⚪ | Ad hoc correction |
| 016 | Deuteron quarks = P1 | 2*3 = 6 | ⚪ | Trivially forced |
| 017 | Pion mass ratio | 1.034 | ⚪ | Electromagnetic, unrelated |
| 018 | Shell capacities = phi, P1, sigma | 2, 6, 12 | 🟩 | First 3 shells clean |
| 019 | Ni-62 Z = P2 | Z=28 peak binding | 🟩 | Most stable nucleus |
| 020 | Double-magic count = P1 | Count ~ 6 | ⚪ | Ill-defined count |

### Score Distribution

```
  🟩⭐  3  (15%)   Structurally significant
  🟩    4  (20%)   Exact, noteworthy
  🟧    3  (15%)   Approximate or searched
  ⚪   10  (50%)   Coincidence / trivial / forced

  Total structural (🟩⭐ + 🟩 + 🟧): 10/20 = 50%

  Grade Distribution:

  ⚪  |||||||||| 10
  🟩  ||||       4
  🟧  |||        3
  🟩⭐ |||        3
      ──────────────
       0  2  4  6  8  10
```

### Honest Assessment

The 50% structural rate is LOWER than the 62.3% average across the 400-hypothesis
campaign. Nuclear structure operates with small quantum numbers (l=0,1,2,3; j=1/2
to 9/2; shell capacities 2-44) that naturally overlap with P1 arithmetic. Many
"matches" are forced by:

1. **Spin-orbit quantum mechanics**: l=1 shell MUST hold 6 nucleons
2. **Alpha clustering**: 4n arithmetic is trivially captured by tau=4
3. **Small number overlap**: Integers 2-12 appear constantly in both QM and P1 functions
4. **Semi-empirical fits**: Bethe-Weizacker parameters vary by 5-10% across fits

The genuinely interesting findings are:

1. **NUCSTR-002**: The sd-shell decomposition sigma = P1 + phi + tau matching three
   distinct subshell degeneracies is a non-trivial triple coincidence.

2. **NUCSTR-007**: Carbon-12 having A=sigma, Z=N=P1 for the element that defines
   both chemistry and the mass standard.

3. **NUCSTR-009**: The perfect number cascade P1->C-12, P2->Ni-56 connecting
   two perfect numbers to two doubly-magic nuclei via sigma function.

These three are worth further investigation. The rest are small-number artifacts.

### Comparison with Other Domains

```
  Domain               Hit Rate   Strong Hits   Assessment
  ─────────────────────────────────────────────────────────
  Nuclear Fusion        76.5%     3 🟩⭐          High (some forced)
  Nuclear Structure     50.0%     3 🟩⭐          Moderate (small number bias)
  SLE / Critical Exp    100%      7 🟩⭐          Very high (proven)
  Genetic Code           92%      5 🟩⭐          Very high
  Overall Campaign       62.3%    --             Baseline
```

Nuclear structure's 50% is below the campaign average, consistent with the
small-number problem dominating this domain.

---

## Falsifiable Predictions

1. **P3-cascade**: The third perfect number P3=496 should NOT yield a doubly-magic
   nucleus at A=sigma(496)=992, Z=496, because no magic number equals 496.
   This LIMITS the cascade to P1 and P2.

2. **Shell capacity pattern**: If the phi-P1-sigma pattern for shells 1-3 is
   fundamental, the 4th shell "should" involve tau-dependent quantities. The
   actual 4th shell capacity is 8 = 2*tau, which is a weak match.

3. **Superheavy magic numbers**: Predicted magic numbers beyond 126 (e.g., 184)
   should NOT match P1 functions cleanly if the connection is coincidental.
   184 = ? No clean single P1 expression exists. This supports the null hypothesis.

---

## References

- Mayer, M.G. (1949). "On Closed Shells in Nuclei. II." Phys. Rev. 75, 1969.
- Haxel, Jensen, Suess (1949). "On the Magic Numbers in Nuclear Structure." Phys. Rev. 75, 1766.
- Bethe, H.A. & Weizsacker, C.F. (1935). Semi-empirical mass formula.
- Krane, K.S. "Introductory Nuclear Physics." Wiley, 1988.
- Hoyle, F. (1954). "On Nuclear Reactions Occurring in Very Hot Stars." Ap. J. Suppl. 1, 121.
- Tohsaki, Horiuchi, Schuck, Ropke (2001). "Alpha Cluster Condensation." Phys. Rev. Lett. 87, 192501.
- Ikeda, K. et al. (1968). "The Systematic Structure-Change into the Molecule-like Structures."
