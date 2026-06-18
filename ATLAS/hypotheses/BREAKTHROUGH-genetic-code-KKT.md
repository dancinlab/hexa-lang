# BREAKTHROUGH ATTEMPT: Derive sigma(n)=2n from Genetic Code Optimization
**n6 Grade: 🟩 EXACT** (auto-graded, 11 unique n=6 constants)


**Status: FAILED (Level 1 -- numerological coincidence only)**
**Date: 2026-03-29**

> **Hypothesis**: Optimizing a genetic code from first principles (maximizing
> robustness to point mutations) REQUIRES n to be a perfect number, i.e.,
> sigma(n) = 2n.

## Background

The parametrization b = tau(n), L = n/phi(n) maps n=6 to (b=4, L=3) -- life's
actual genetic code (4 bases, codons of length 3). This raised the question:
does sigma(n)=2n (the perfect number condition) emerge naturally from optimizing
code robustness?

## Setup

- A = 21 amino acids (20 + 1 stop)
- b = alphabet size (number of bases)
- L = codon length
- Codons = b^L (must be >= 21)
- Robustness metric: R_spread = (d^(1/L) - 1)/(b-1)
  where d = b^L/A = average degeneracy
  This measures the fraction of single-base mutations that are silent
  under an optimal (evenly-spread) codon assignment.
- Information efficiency: E = log2(A) / (L * log2(b))
- Waste: W = b^L - A

## Key Finding 1: n/phi(n) in Z selects {2^a * 3^b} only

The integrality condition n/phi(n) in Z holds for exactly those n whose
prime factors are a subset of {2, 3}:

```
  n    n/phi  tau  factorization
  2      2     2   {2:1}
  4      2     3   {2:2}
  6      3     4   {2:1, 3:1}    <-- maps to (4,3) = life
  8      2     4   {2:3}
  12     3     6   {2:2, 3:1}    <-- maps to (6,3)
  16     2     5   {2:4}
  18     3     6   {2:1, 3:2}
  24     3     8   {2:3, 3:1}
  ...
```

This condition has nothing to do with sigma(n)=2n. It selects all
3-smooth numbers, of which n=6 is just the smallest with both 2 and 3.

## Key Finding 2: (4,3) is NOT robustness-optimal

For fixed L=3, R_spread is monotonically increasing in b:

```
  b   L   codons   R_spread   InfoEff   Notes
  3   3       27    0.0437     0.924
  4   3       64    0.1499     0.732    LIFE
  5   3      125    0.2031     0.631
  6   3      216    0.2350     0.566    n=12
  7   3      343    0.2562     0.522
  8   3      512    0.2714     0.488
```

Proof: R(b) = (b - c)/(c(b-1)) where c = A^(1/L).
dR/db = (c-1)/[c(b-1)^2] > 0 for all c > 1.
Robustness is strictly increasing in b. No interior optimum exists.

## Key Finding 3: (4,3) is dominated on the Pareto front

Multi-objective Pareto analysis (maximize R, maximize InfoEff, minimize waste):

```
  Pareto-optimal codes:
   b  L  codons  R_spread  InfoEff  waste
   5  2      25    0.0228    0.946      4
   3  3      27    0.0437    0.924      6
   2  5      32    0.0879    0.878     11
   7  2      49    0.0879    0.782     28
   2  6      64    0.2041    0.732     43
   2  7     128    0.2946    0.627    107
   3  5     243    0.3159    0.554    222
   2  8     256    0.3669    0.549    235
```

(4,3) is NOT on this front. It is dominated by (2,6):

```
  (4,3): R=0.1499, InfoEff=0.732, waste=43
  (2,6): R=0.2041, InfoEff=0.732, waste=43
```

Same codons (64), same waste (43), same info efficiency (0.732),
but (2,6) has strictly higher robustness.

## Key Finding 4: Counterfactual -- n=6 vs n=12

```
  n=6  (perfect):     b=4, L=3, codons=64,  R=0.1499
  n=12 (not perfect): b=6, L=3, codons=216, R=0.2350
```

n=12 gives a MORE ROBUST code than n=6. The perfect number property
confers no advantage whatsoever.

## Key Finding 5: Why life actually uses (4,3)

1. **Chemistry constrains b=4**: Watson-Crick base pairing produces
   exactly 4 bases (2 purines + 2 pyrimidines). This is a biochemical
   fact, not an optimization outcome.

2. **Minimality constrains L=3**: Given b=4, the minimum L with
   4^L >= 21 is L=3 (since 4^2 = 16 < 21).

3. **No number theory needed**: The explanation is b=4 (chemistry) +
   L=3 (minimality). Full stop.

## Verdict

```
  sigma(n)=2n appears in derivation:  NO
  (4,3) is robustness-optimal:        NO
  (4,3) is Pareto-optimal:            NO
  Perfect number confers advantage:   NO
  n=6 mapping to (4,3) is a coincidence: YES (tau(6)=4, 6/phi(6)=3)
```

**Grade: Level 1 (pattern match / numerological coincidence)**

The mapping n=6 -> (tau(6), 6/phi(6)) = (4,3) is arithmetically correct
but carries no explanatory or predictive power. The perfect number condition
sigma(n)=2n is completely irrelevant to genetic code optimization.

## Limitations

- Robustness metric assumes uniform mutation model and optimal codon assignment.
  Real genetic code has non-uniform mutation rates and historical contingency.
- Even with more sophisticated metrics (Freeland & Hurst 1998), the conclusion
  would not change: b=4 is a chemical constraint, not an optimum.

## What this teaches

Not every number-theoretic coincidence is meaningful. The parametrization
(tau(n), n/phi(n)) is a valid map from integers to (alphabet, length) pairs,
and n=6 happens to land on life's code. But "happens to" is the operative
phrase. This is a textbook example of the Texas Sharpshooter fallacy:
drawing the target after the bullet lands.
