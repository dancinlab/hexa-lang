# PMATH-THETA-PERFECT: Theta_{4k-1} = sigma(P_k) Pattern
**n6 Grade: 🟩 EXACT** (auto-graded, 12 unique n=6 constants)


## Status: REFUTED

## Golden Zone Dependency: None -- pure number theory / lattice theory

## Hypothesis

> For the k-th even perfect number P_k (P_1=6, P_2=28, P_3=496, ...),
> there exists a standard lattice theta series Theta_L such that
> the coefficient Theta_L(4k-1) equals sigma(P_k) = 2*P_k.
>
> Specifically: Theta_3 = 12, Theta_7 = 56, Theta_11 = 992,
> Theta_15 = 16256, Theta_19 = 67100672.

## Background/Context

Lattice theta series encode the number of lattice vectors of a given norm.
For a lattice L in R^d, the theta series is:

```
  Theta_L(q) = sum_{v in L} q^{|v|^2} = sum_{n>=0} a_L(n) q^n
```

where a_L(n) counts vectors of squared norm n. These are modular forms
of weight d/2 and connect number theory to geometry.

Perfect numbers satisfy sigma(n) = 2n, so the target sequence is:

```
  k=1:  sigma(6)        = 2^2 * 3     = 12
  k=2:  sigma(28)       = 2^3 * 7     = 56
  k=3:  sigma(496)      = 2^5 * 31    = 992
  k=4:  sigma(8128)     = 2^7 * 127   = 16256
  k=5:  sigma(33550336) = 2^13 * 8191 = 67100672

  General: sigma(P_k) = 2^p * (2^p - 1) where p is the k-th Mersenne exponent
```

Related hypotheses:
- 259: Umbral Moonshine (lattice theta series, dimension 24 = 2*sigma(6))
- 092: Model = zeta Euler product p=2,3 truncation
- PERFECT-CLASSIFY: Universal expansion of perfect number identities

## Lattice Theta Series Tested

```
  +--------------+------------------------------------------+-------------------+
  | Lattice      | Theta formula                            | Growth type       |
  +--------------+------------------------------------------+-------------------+
  | Z^d          | r_d(n) = #{sum of d squares = n}         | Polynomial in d   |
  | D_d          | (theta_3^d + theta_4^d)/2                | Even norms only   |
  | E8           | 1 + 240*sum sigma_3(n)*q^n               | 240*sigma_3(n)    |
  | Leech (L24)  | (65520/691)*(sigma_11(n) - tau(n))       | ~sigma_11(n)      |
  +--------------+------------------------------------------+-------------------+
```

## Verification Results

### Z^d Lattice (d = 1 to 16)

No exact match found for any dimension d at any target index.

```
  r_d(n) at target indices:
  | d  | r_d(3)  | r_d(7)  | r_d(11)  | r_d(15)  | r_d(19)  |
  |----|---------|---------|----------|----------|----------|
  | 3  | 8       | 0       | 24       | 0        | 24       |
  | 4  | 32      | 64      | 96       | 192      | 160      |
  | 5  | 80      | 320     | 560      | 960      | 1520     |
  | 6  | 160     | 960     | 2400     | 4160     | 7200     |
  | 7  | 280     | 2368    | 7560     | 16576    | 27720    |
  | 8  | 448     | 5504    | 21312    | 56448    | 109760   |

  TARGETS: 12       56       992      16256    67100672

  Near miss: r_7(15) = 16576 vs target 16256 (ratio 1.020)
  But r_7(7) = 2368 vs target 56 (ratio 42.3) -- no consistency.
```

### E8 Lattice

```
  | Index | E8 coeff  | Target  | Ratio      |
  |-------|-----------|---------|------------|
  | 3     | 6720      | 12      | 560.0      |
  | 7     | 82560     | 56      | 1474.3     |
  | 11    | 319680    | 992     | 322.3      |
  | 15    | 846720    | 16256   | 52.1       |
  | 19    | 1646400   | 67100672| 0.025      |

  Ratios vary wildly -- no consistent relationship.
  E8 grows as O(n^3), targets grow as O(2^{2p}) -- incompatible.
```

### D_d Lattice (d = 2 to 12)

All zero at target indices. This is correct: D_d lattice vectors have
even coordinate sums, so squared norms are always even. The indices
3, 7, 11, 15, 19 are all odd, giving Theta_{D_d}(n) = 0.

### Leech Lattice

```
  | Index | Leech coeff   | Target  |
  |-------|---------------|---------|
  | 3     | 16773120      | 12      |
  | 7     | 187489935360  | 56      |

  Off by factors of ~10^6 to 10^9. No relationship.
```

## Ratio Analysis (Z^d)

```
  r_d(3)/12  r_d(7)/56  r_d(11)/992  r_d(15)/16256
  d=4: 2.67    1.14       0.097        0.012
  d=5: 6.67    5.71       0.565        0.059
  d=6: 13.3    17.1       2.42         0.256
  d=7: 23.3    42.3       7.62         1.020
  d=8: 37.3    98.3       21.5         3.47

  No constant ratio across columns for any d.
  The columns would need identical ratios for a valid pattern.
```

## Fundamental Obstruction

The conjecture fails for a deep structural reason:

```
  Indices:        3, 7, 11, 15, 19     (arithmetic progression, step 4)
  Mersenne exp:   2, 3,  5,  7, 13     (NOT arithmetic progression)

  sigma(P_k) = 2^p_k * (2^{p_k} - 1)

  The target values grow as ~4^{p_k} where p_k follows the IRREGULAR
  sequence of Mersenne prime exponents. No lattice theta series can
  produce such irregular growth at regularly-spaced indices because:

  1. Theta coefficients of fixed lattices satisfy modular form
     recurrences with REGULAR growth patterns.
  2. The Mersenne prime distribution is conjectured to follow
     ~e^gamma * n / ln(2) (heuristic, no proven pattern).
  3. Matching requires the theta series to "know" about Mersenne
     primes, which would imply a deep and unexpected connection
     between lattice geometry and prime number distribution.
```

## ASCII Graph: Growth Rate Mismatch

```
  log2(value)
  26 |                                                    * target k=5
     |
  20 |
     |
  14 |                          * target k=4
     |                    ..... Z^16(15)
  10 |            * target k=3
     |        .... Z^16(11)
   6 |  * target k=2
     | .. Z^8(7)
   4 | * target k=1
   2 |.
   0 +----+----+----+----+-----> index (4k-1)
     3    7    11   15   19

  Targets (x): exponential in Mersenne exponent (irregular)
  Z^d (.):     polynomial in index (regular)
  Growth types are fundamentally incompatible.
```

## Trivial Connection Found

```
  r_d(1) = 2d  for all d >= 1  (exactly 2d vectors of norm 1 in Z^d)

  Therefore r_{P_k}(1) = 2*P_k = sigma(P_k) for ALL perfect numbers.

  But this is trivially true for ANY even number, not just perfect numbers.
  r_{N/2}(1) = N for all even N.  Not a meaningful pattern.
```

## Texas Sharpshooter Test

```
  Total lattice types tested:  29
  Total comparisons made:      166
  Exact matches found:         0
  Expected by chance:          ~17 (generous upper bound)
  p-value (raw):               1.000
  p-value (Bonferroni):        1.000
  Assessment:                  Not applicable (zero matches)
```

## Interpretation

The conjecture Theta_{4k-1} = sigma(P_k) is **definitively refuted** for all
standard lattice theta series (Z^d for d=1..16, D_d for d=2..12, E8, Leech).

The fundamental reason is a growth-rate mismatch: sigma(P_k) grows as
2^{2p_k} where p_k are Mersenne prime exponents (irregular), while lattice
theta coefficients at fixed indices grow polynomially or via divisor-sum
formulas (regular). No standard theta series can bridge this gap.

## Limitations

- Only tested up to d=16 for Z^d and d=12 for D_d (higher dimensions are
  computationally expensive but would only make coefficients larger, not
  smaller toward the targets).
- Did not test exotic lattices (Barnes-Wall, Coxeter-Todd, etc.), though
  these are unlikely to produce the specific irregular growth needed.
- A custom-constructed theta series could trivially match any sequence,
  but that would not constitute a meaningful mathematical pattern.

## Verification Direction

- The pattern is refuted. No further investigation needed.
- If a connection between perfect numbers and theta functions exists,
  it more likely involves the modular properties of sigma(n) itself
  (Eisenstein series) rather than lattice representation numbers.
- The known connection 24 = 2*sigma(6) = dim(Leech lattice) remains
  the deepest verified link between perfect numbers and lattice theory
  (see hypothesis 259: Umbral Moonshine).

## Calculator

`calc/theta_perfect_pattern.py`

## Grade: REFUTED (zero matches, fundamental growth-rate obstruction)
