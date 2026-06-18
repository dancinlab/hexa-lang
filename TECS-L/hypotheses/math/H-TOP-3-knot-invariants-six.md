# H-TOP-3: Knot Invariants and 6

> **Hypothesis**: The invariants of the Trefoil knot T(2,3) reflect sigma,tau.

**Status: 🟨 Weak Evidence (Small Numbers Effect Dominant)**

## Background

Trefoil = simplest non-trivial knot = torus knot T(2,3).
(2,3) comes from the prime factorization of 6 = 2 x 3.

## List of Invariants for Trefoil T(2,3)

| Invariant | Value | sigma,tau relation? | Judgment |
|---|---|---|---|
| (p,q) | (2,3) | 2=phi(6), 3=sigma/tau | trivial |
| crossing number | 3 | sigma/tau = 12/4 = 3 | trivial |
| genus | 1 | (p-1)(q-1)/2 = 1 | unrelated |
| bridge number | 2 | min(p,q) = phi(6) | trivial |
| braid index | 2 | min(p,q) = phi(6) | trivial |
| signature | -2 | -phi(6) | trivial |
| determinant | 3 | sigma/tau | trivial |
| unknotting number | 1 | (p-1)(q-1)/2 | unrelated |
| writhe (standard) | 3 | sigma/tau | trivial |
| stick number | 6 | P_1 = 6 | notable |
| colorability | 3-colorable | sigma/tau | trivial |

### Alexander Polynomial

```
  Delta(t) = t - 1 + t^{-1}

  coefficients: [1, -1, 1]   -- alternating 1, -1
  Delta(-1) = -1 - 1 + (-1) = -3   =>  det = |Delta(-1)| = 3 = sigma/tau
  Delta(1) = 1 - 1 + 1 = 1
```

### Jones Polynomial

```
  V(t) = -t^{-4} + t^{-3} + t^{-1}

  coefficients: [-1, 1, 0, 1]  at  t^{-4}, t^{-3}, t^{-2}, t^{-1}
  exponent range: -4 to -1  =>  span = 3 = sigma/tau
  V(e^{2pi*i/6}): value at 6th unit root -- special value?

  t = e^{2pi*i/6}: t^6 = 1, t^3 = -1, t^2 = e^{2pi*i/3}
  V(e^{2pi*i/6}) = -e^{-8pi*i/6} + e^{-6pi*i/6} + e^{-2pi*i/6}
                 = -e^{-4pi*i/3} + e^{-pi*i} + e^{-pi*i/3}
                 = -e^{2pi*i/3} + (-1) + e^{-pi*i/3}
                 = -(cos(2pi/3)+i*sin(2pi/3)) - 1 + cos(pi/3)-i*sin(pi/3)
                 = -(-.5+.866i) - 1 + .5 - .866i
                 = .5 - .866i - 1 + .5 - .866i
                 = 0 - 1.732i = -i*sqrt(3)

  |V(e^{2pi*i/6})| = sqrt(3) -- interesting but sqrt(3) is a very common value
```

### Braid group B_3

```
  B_3 = <sigma_1, sigma_2 | sigma_1*sigma_2*sigma_1 = sigma_2*sigma_1*sigma_2>

  center: Z(B_3) = <(sigma_1*sigma_2)^3>
    index 3 = sigma/tau

  B_3 / Z(B_3) ≅ PSL(2,Z) = Z/2Z * Z/3Z (free product)
    2 = phi(6), 3 = sigma/tau

  PSL(2,Z) is the modular group -- symmetry group of modular forms
  weight 12 modular discriminant Delta:
    12 = sigma(6)
    Delta(q) = q * product_{n>=1} (1-q^n)^{24}
    24 = sigma(6) * phi(6)
```

## Core Problem: Small Numbers

In the correspondence table above, almost all invariant values are one of 1, 2, 3.
These overlap with the arithmetic function values of 6 (tau=4, phi=2, sigma=12),
but since these are the smallest positive integers, the probability of coincidental matches is very high.

```
  Distribution of invariant values:
    value = 1: genus, unknotting number    (2 items)
    value = 2: bridge, braid index         (2 items)
    value = 3: crossing, determinant       (2 items)
    value = 6: stick number                (1 item)

  sigma,tau function outputs:
    sigma/tau = 3,  phi = 2,  tau = 4,  1 (unit)

  Probability of 1, 2, 3 overlapping: very high
```

## Texas Sharpshooter Test (Rigorous)

```
  Number of invariants: 11 (above table)
  sigma,tau related target values: {1, 2, 3, 4, 6, 12}  (6 values)
  Invariant value range: mostly [1, 10]

  Probability of one invariant randomly hitting target: ~6/10 = 0.6
  Expected matches among 11: 11 * 0.6 = 6.6
  Actual matches: ~8 (including genus=1, unknotting=1)

  Observed matches are close to expected value!

  p-value (8 or more matches): from binomial B(11, 0.6)
    P(X >= 8) = C(11,8)*0.6^8*0.4^3 + C(11,9)*0.6^9*0.4^2
              + C(11,10)*0.6^10*0.4 + C(11,11)*0.6^11
            = 165*0.01680*0.064 + 55*0.01008*0.16
              + 11*0.00605*0.4 + 1*0.00363
            = 0.1774 + 0.0887 + 0.0266 + 0.0036
            = 0.296

  p = 0.30 >> 0.05  (not significant!)
```

## Separate Review of stick number = 6

```
  Is Trefoil's stick number = 6 special?

  stick number: minimum number of straight sticks to realize the knot
  Trefoil: needs minimum 6 straight segments (proven, Randell 1994)

  This matches 2*3=6, not 2+3=5 from T(2,3).
  However, general formula for torus knot T(p,q) stick number:
    s(T(p,q)) = 2q  (if p < q, p >= 2, for some range)
    s(T(2,3)) = 2*3 = 6  ← simply 2q

  This is a trivial consequence of the fact 6 = 2*3.
  Since stick = 2q, T(2,3)'s stick=6 has trivial structural reason.
```

## B_3 -> PSL(2,Z) -> modular forms Path

This path is most interesting but the connection to sigma,tau is indirect:

```
  T(2,3) ──> B_3 ──> PSL(2,Z) = Z/2 * Z/3
                        |
                        v
                    modular forms
                        |
                    weight 12 = sigma(6)
                        |
                    Delta = q * prod(1-q^n)^{24}
                        |
                    24 = 2 * sigma(6)
                        |
                    Leech lattice (dim 24)
                    Ramanujan tau function

  The appearance of 12 and 24 in this path is deep mathematics,
  but is sigma(6)=12 appearing here coincidence or necessity?

  Origin of weight 12:
    - weight of modular discriminant Delta = 12
    - 12 = 2*2*3 = first even weight where cusp form appears
    - dimension of S_k(SL_2(Z)): dim S_{12} = 1 (unique cusp form = Delta)
    - Why 12 is special: naturally derived from SL_2(Z) relations

  Relationship between sigma(6) = 12 and weight 12:
    - 12 = 1+2+3+4+6+12... no, sigma(6) = 1+2+3+6 = 12
    - The reason weight 12 is special in modular theory and
      the reason sigma(6)=12 are independent
    - Commonality: both arise from combinations of 2 and 3
      (6=2*3, SL_2=2x2 matrices, Z/2*Z/3=PSL_2)
```

## Judgment

| Item | Result |
|---|---|
| T(2,3) parameters (2,3) = factors of 6 | trivial (by definition) |
| invariant matches 8/11 | expected 6.6, p=0.30 (not significant) |
| stick=6 | 2q=2*3, trivial consequence |
| B_3->PSL_2->weight 12 | indirect, independent origins |
| Texas p-value | 0.30 (not significant) |
| ad hoc nature | Small Numbers effect dominant |
| **Grade** | **🟨 Weak evidence (small numbers, p=0.30)** |

## ASCII Summary Diagram

```
  Trefoil T(2,3)
    |
    |-- Invariants: almost all in {1, 2, 3}
    |   |
    |   +-- sigma,tau values also {1, 2, 3, 4, 6, 12}
    |   |
    |   +-- overlap: small numbers => p=0.30 (not significant)
    |
    |-- B_3 -> PSL(2,Z) -> modular forms
    |   |
    |   +-- weight 12 = sigma(6)?
    |   |
    |   +-- independent origins (SL_2 structure vs divisor sum)
    |
    +-- Conclusion: interesting but statistically not significant

  Significance:  |====.........| p=0.30 (below threshold 0.05)
```

## Limitations
- Incomplete analysis of special values of Jones polynomial
- The deep number-theoretic origin of weight 12 and its relation to sigma(6) merit further study
- No systematic comparison with perfect numbers for general torus knots T(p,q)

## Interpretation

The relationship between Trefoil T(2,3) and 6=2x3 is trivial by definition.
The overlap between knot invariants and sigma,tau is because all values are small integers,
and is not statistically significant (p=0.30).

The only non-trivial path is B_3 -> PSL(2,Z) -> weight 12 modular forms,
but the reason 12 appears in this path and the reason sigma(6)=12 are independent.
While it's interesting that both arise from combinations of 2 and 3, this reflects
the prime structure of 6=2x3, not a property unique to perfect numbers.

## Difficulty: High | Impact: ★ (Small Numbers Limitation)