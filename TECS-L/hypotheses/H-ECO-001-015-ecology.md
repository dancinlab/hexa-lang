# Ecology / Evolution Hypotheses H-ECO-001 through H-ECO-015
**n6 Grade: 🟩 EXACT** (auto-graded, 13 unique n=6 constants)


## Hypothesis Bundle

> Can the TECS-L framework (perfect number 6, sigma(6)=12, tau(6)=4, phi(6)=2,
> Golden Zone [0.212, 0.500], center 1/e) produce meaningful mappings to
> established constants in ecology and evolutionary biology?

## Background

Ecology and evolution contain some numerical regularities (Lindeman 10% rule,
typical trophic level counts, mutation type counts) but far fewer universal
dimensionless constants than physics or pure mathematics. Most ecological
"constants" are system-specific or have wide empirical ranges, making precise
numerical matching inherently suspect.

This bundle tests 15 candidate mappings across three domains:
population dynamics, food web structure, and evolution.

**Golden Zone dependency**: All 15 hypotheses are GZ-dependent (unverified framework).

## TECS-L Constants Used

```
  n = 6           (perfect number)
  sigma(6) = 12   (divisor sum)
  tau(6) = 4      (divisor count)
  phi(6) = 2      (Euler totient)
  GZ = [0.212, 0.500]    (Golden Zone)
  GZ center = 1/e = 0.3679
  GZ width = ln(4/3) = 0.2877
  1/6, 1/3, 5/6   (divisor reciprocals)
```

---

## A. Population Dynamics (H-ECO-001 to H-ECO-005)

### H-ECO-001: Logistic Map Chaos Onset vs n=6 Constants

> The Feigenbaum chaos onset r_c = 3.5699 in the logistic map can be
> expressed as e + 5/6 = 3.5516 (0.51% error).

**Verification:**

| Candidate Expression           | Value   | Error vs r_c |
|-------------------------------|---------|-------------|
| sigma(6)/tau(6) = 12/4        | 3.0000  | 15.97%      |
| 6/phi(6) = 6/2                | 3.0000  | 15.97%      |
| sigma(6)/pi = 12/pi           | 3.8197  | 7.00%       |
| 6*ln(2) - 1                   | 3.1589  | 11.52%      |
| sigma(6)*ln(4/3)              | 3.4522  | 3.30%       |
| 2 + phi_gold                  | 3.6180  | 1.35%       |
| **e + 5/6**                   | **3.5516** | **0.51%** |

```
  p-value (single):     0.0071
  p-value (Bonferroni): 0.0500  (7 candidates tested)
  Grade: orange (weak evidence, ad hoc)
```

**Limitation**: Seven candidate expressions were tested. The best match (e + 5/6)
survives single-test significance but barely passes after Bonferroni correction.
The expression e + 5/6 has no theoretical justification linking inhibition
constants to logistic map bifurcation.

```
  Grade: orange -- weak evidence, ad hoc from 7 trials
```

### H-ECO-002: Lotka-Volterra Cycle Period Ratios

> The Lotka-Volterra conservation law H = d*x - c*ln(x) + b*y - a*ln(y)
> is structurally analogous to G*I = D*P.

**Verification:** Lotka-Volterra has NO universal dimensionless constant.
Period and equilibrium depend entirely on system parameters (a, b, c, d).
The structural analogy to G*I = D*P is generic to all Hamiltonian systems
and carries no specific information about n=6.

```
  Grade: white -- no testable numerical claim
```

### H-ECO-003: r/K Strategy Dichotomy = phi(6) = 2

> The two ecological strategies (r-selected vs K-selected) correspond
> to phi(6) = 2.

**Verification:** 2 = 2 is exact, but "2" is the most common small integer.
Binary dichotomies pervade biology (male/female, prokaryote/eukaryote,
predator/prey, DNA/RNA). Modern ecology supersedes r/K with:
- r-K-A continuum (3 strategies, Pianka)
- Grime's CSR triangle (3 strategies: Competitive, Stress-tolerant, Ruderal)

```
  Grade: white -- trivial small integer match
```

### H-ECO-004: Allee Effect Threshold vs GZ Lower Bound

> The Allee effect threshold (~20% of carrying capacity) approximates
> the Golden Zone lower bound (0.2123).

**Verification:**

```
  Allee threshold:  ~0.20 (typical estimate)
  GZ lower bound:    0.2123
  Difference:        0.012  (5.8% relative error)
  p-value:           0.021
```

**Critical limitation**: The Allee threshold is NOT a universal constant.
It ranges from 5% to 50% of K depending on species (Courchamp et al. 1999).
Selecting "20%" as the representative value is itself ad hoc.

```
  Grade: orange -- ad hoc selection of representative value
```

### H-ECO-005: Carrying Capacity as GZ Upper Bound Analogy

> The carrying capacity K in logistic growth is structurally analogous
> to the GZ upper bound 1/2 as the maximum sustainable state.

**Verification:** K is system-specific and dimensional (individuals, biomass).
The logistic saturation form dN/dt = rN(1 - N/K) is the most generic
bounded growth model and appears in chemistry, epidemiology, economics, etc.
No numerical test is possible.

```
  Grade: white -- structural analogy only, no testable claim
```

---

## B. Food Web / Ecosystem (H-ECO-006 to H-ECO-010)

### H-ECO-006: Trophic Levels = tau(6) = 4

> The typical number of trophic levels in food webs (~4) equals tau(6) = 4.

**Verification:**

```
  Mean trophic levels:  ~4 (Pimm 1982, Post & Pace 2004)
  tau(6):               4
  Match:                exact (4 = 4)
  Range in nature:      2 to 6
```

The mean ~ 4 is determined by energetic constraints (Lindeman 10% rule):
if 10% energy transfers per level, 4 levels retain 0.01% of base energy.
This is a thermodynamic limit, not a number-theoretic one.
Matching the small integer 4 has probability ~1/5 in the realistic range [2,6].

```
  Grade: white -- small integer coincidence (p = 0.20)
```

### H-ECO-007: Energy Transfer Rate 10% vs 1/sigma(6) = 1/12

> Lindeman's 10% energy transfer rule approximates 1/sigma(6) = 1/12 = 8.33%.

**Verification:**

```
  Lindeman efficiency:  0.10
  1/sigma(6) = 1/12:   0.0833
  Relative error:       17%
  Actual range:         5-20%
  p-value (Bonferroni): 0.025
```

The 10% "rule" is a rough approximation. Actual transfer efficiency varies
from 5% (endotherms) to 20% (ectotherms). The 17% relative error between
10% and 8.33% is substantial, and the comparison is ad hoc (3 candidates tried).

```
  Grade: orange -- weak, large relative error, approximate ecological value
```

### H-ECO-008: Shannon Biodiversity Index Structure

> Shannon index for S=6 species gives H_max = ln(6), and
> H_max(S=12) - H_max(S=6) = ln(2).

**Verification:** This is a tautology: ln(12) - ln(6) = ln(12/6) = ln(2).
The Shannon index uses natural logarithm by definition, so any relationship
with e or ln is built into the formula, not emergent. No empirical ecological
constant is being matched here.

```
  Grade: white -- tautological (Shannon uses ln by definition)
```

### H-ECO-009: Ecological Network Connectance vs Golden Zone

> Food web connectance C ~ 0.1-0.3 overlaps the Golden Zone [0.212, 0.500].

**Verification:**

```
  Connectance mean (Dunne 2002):  C = 0.11
  Connectance range:              0.05 - 0.32
  Golden Zone:                    [0.212, 0.500]
  C_mean in GZ?                   NO (0.11 < 0.212)
```

The mean connectance (0.11) falls below the GZ lower bound. Only the upper
tail of the connectance distribution overlaps with GZ. This is partial
overlap of wide ranges, not a precise match.

```
  Grade: white -- mean outside GZ, partial range overlap only
```

### H-ECO-010: Keystone Species Proportion

> The fraction of keystone species in ecosystems matches a TECS-L constant.

**Verification:** No universal numeric constant exists for keystone species
proportion. The concept (Paine 1969) is qualitative: species with
disproportionate community effects relative to their abundance. Rough
estimates (5-15%, Power et al. 1996) are too imprecise and variable
for meaningful comparison.

```
  Grade: white -- no universal constant to test
```

---

## C. Evolution (H-ECO-011 to H-ECO-015)

### H-ECO-011: Point Mutation Types = 6 = n

> The 6 types of DNA point mutations (2 transitions + 4 transversions)
> equal the perfect number n = 6. Furthermore, directed mutations = 12 = sigma(6).

**Verification:**

```
  Undirected mutation pairs:
    Transitions:    A<->G, C<->T             = 2
    Transversions:  A<->C, A<->T, G<->C, G<->T = 4
    Total:          6 = C(4,2) from 4 DNA bases

  Directed mutations:
    Each base -> 3 others = 4 x 3 = 12 = P(4,2)

  Transition/Transversion ratio: 2/4 = 1/2
```

The "6" is C(4,2), a combinatorial identity from 4 DNA bases. If DNA had
5 bases, there would be C(5,2) = 10 types. The 12 directed mutations = P(4,2).
These are standard combinatorics, not number theory. The connection to
perfect number 6 is coincidental.

```
  Grade: white -- combinatorial origin from 4 bases, not n=6
```

### H-ECO-012: Mass Extinctions: Big Five vs n = 6

> The number of mass extinctions (5 or 6) relates to n = 6 or tau(6) + 1 = 5.

**Verification:**

```
  Established mass extinctions:  5 (Big Five, Raup & Sepkoski 1982)
  n = 6:                        5 != 6
  tau(6) + 1 = 5:               requires ad-hoc +1 correction
  6 - 1 = 5:                    requires ad-hoc -1 correction
```

The "Big Six" (including Holocene) is scientifically contested
(Barnosky et al. 2011 calls it "potential" not established).
Forcing the match requires either ad-hoc arithmetic or accepting
a contested classification.

```
  Grade: white -- 5 != 6, ad-hoc corrections needed
```

### H-ECO-013: Hardy-Weinberg Equilibrium Structure

> HW equilibrium has 3 genotype terms = count of proper divisors of 6.

**Verification:**

```
  HW terms (2 alleles):  p^2 + 2pq + q^2 = 1  -> 3 terms
  Proper divisors of 6:  {1, 2, 3} -> count = 3
  tau(6) - 1:            4 - 1 = 3
```

The 3 terms come from C(2+1, 2) = 3 for 2 alleles. For 3 alleles: 6 genotypes.
For 4 alleles: 10 genotypes. The "3" is a binomial coefficient from the
simplest case (2 alleles), not from perfect number 6.

Additionally, p^2 + 2pq + q^2 = (p+q)^2 = 1 is an algebraic identity,
not a conservation law analogous to G*I = D*P.

```
  Grade: white -- small integer match from simplest case
```

### H-ECO-014: Neutral Theory Mutation Rate

> The neutral mutation rate ~1e-8 per nucleotide per generation relates
> to TECS-L constants.

**Verification:** Mutation rates are species-specific, dimensional, and vary
100-fold across organisms:

```
  Human:       1.2 x 10^-8 / nt / generation
  Drosophila:  3.5 x 10^-9 / nt / generation
  E. coli:     2.2 x 10^-10 / nt / generation
```

These are dimensional quantities (per nucleotide per generation) that cannot
be meaningfully compared to dimensionless constants in [0, 1].

```
  Grade: white -- species-specific dimensional quantity
```

### H-ECO-015: Cambrian Explosion Timing

> The Cambrian explosion at 541 Ma satisfies 541 ~ e^6 = 403.4
> (since ln(541) = 6.29 ~ 6).

**Verification:**

```
  Cambrian:  541 Ma
  e^6:       403.4 Ma
  Error:     25.4%  (137.6 Ma off)
  ln(541):   6.293  (4.9% from 6)
```

25% error is far too large for a meaningful match. The Cambrian date
(541 +/- 1 Ma) is Earth-specific geology, not a universal constant.
Other planets would have entirely different evolutionary timelines.

```
  Grade: orange -- 25% error, Earth-specific, forced comparison
```

---

## Summary

| #   | Hypothesis                           | Grade |
|-----|--------------------------------------|-------|
| 001 | Logistic chaos r_c vs e + 5/6        | orange  |
| 002 | Lotka-Volterra conservation analogy  | white |
| 003 | r/K strategy = phi(6) = 2            | white |
| 004 | Allee threshold vs GZ lower          | orange  |
| 005 | Carrying capacity analogy            | white |
| 006 | Trophic levels = tau(6) = 4          | white |
| 007 | Energy transfer 10% vs 1/12          | orange  |
| 008 | Shannon index structure              | white |
| 009 | Network connectance vs GZ            | white |
| 010 | Keystone species proportion          | white |
| 011 | Point mutation types = 6             | white |
| 012 | Mass extinctions Big Five vs 6       | white |
| 013 | Hardy-Weinberg 3 terms               | white |
| 014 | Neutral mutation rate                | white |
| 015 | Cambrian explosion timing            | orange  |

### Grade Distribution

```
  green (proven):           0
  orange-star (structural): 0
  orange (weak evidence):   4
  white (coincidence):     11
  black (refuted):          0

  Grade Histogram
  -----------------------------------------------
  green       |                               0
  orange-star |                               0
  orange      |############                   4
  white       |#################################  11
  black       |                               0
  -----------------------------------------------
```

## Interpretation

**11 of 15 hypotheses are white circles** -- either coincidence, untestable
structural analogy, or small integer matching.

The 4 orange grades (ECO-001, 004, 007, 015) all suffer from:
- Ad hoc selection of candidate expressions (001: 7 candidates tried)
- Ad hoc selection of representative value from wide range (004: Allee 5-50%)
- Large relative error (007: 17%; 015: 25%)
- Earth-specific non-universal quantities (015)

**Core problem**: Ecology and evolution contain very few universal dimensionless
constants. Most ecological "numbers" are:
1. System-specific (carrying capacity, mutation rate, connectance)
2. Small integers with obvious alternative explanations (2, 3, 4, 6)
3. Rough averages with wide ranges (10% energy transfer, ~4 trophic levels)
4. Tautological when logarithms are involved (Shannon index)

The TECS-L framework is better suited to domains with precise universal
constants (physics, information theory) than to ecology where most quantities
are contingent on evolutionary history and local conditions.

## Limitations

- All 15 hypotheses are Golden Zone dependent (unverified framework)
- No hypothesis reached orange-star or higher
- The 4 orange results are all weakened by ad hoc choices or wide error margins
- Texas Sharpshooter corrections applied; none survived Bonferroni cleanly

## Verification Direction

- Domain with more universal constants (e.g., allometric scaling laws,
  metabolic theory of ecology) might yield better matches
- Kleiber's law exponent 3/4 could be tested against TECS-L constants
- West-Brown-Enquist metabolic scaling theory has precise predictions

## Verification Script

```
  PYTHONPATH=. python3 verify/verify_eco_001_015.py
```
