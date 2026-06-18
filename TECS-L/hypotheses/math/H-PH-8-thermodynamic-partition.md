# H-PH-8: Thermodynamic Structure of Divisor Partition Function

---
domain: thermodynamics/statistical-mechanics
status: Under Verification
depends_on: [H-PH-7, sigma-phi-n-tau]
golden_zone_dependent: false
created: 2026-03-24
---

> **Hypothesis**: If we interpret the divisor set {d|n} of natural number n as energy levels,
> then the partition function Z_n(β) = Σ_{d|n} e^{-βd} is defined,
> and σ(n) and τ(n) are naturally recovered as the energy sum and number of states at the high-temperature limit (β→0).
> For n=6 (perfect number), entropy S_6(0) = ln(4) = ln(σ/τ) + ln(4/3),
> and the Golden Zone width ln(4/3) is the **gap** between maximum disorder and average energy scale.

## Background

In the σφ=nτ system, the divisors {1, 2, 3, 6} of n=6 are the core of arithmetic structure.
By reinterpreting these 4 divisors as **energy levels**, we can apply the standard tools of statistical mechanics,
the partition function, to number theory.

- In H-PH-7, we defined arithmetic entropy of R spectrum.
- Here, we reconstruct it in **orthodox statistical mechanics** formalism.
- We verify whether σ(n), τ(n), φ(n) naturally emerge as thermodynamic quantities.

Key number-theoretic constants:
```
  n=6:  σ(6)=12, τ(6)=4, φ(6)=2, R(6)=σφ/(nτ)=1
  n=28: σ(28)=56, τ(28)=6, φ(28)=12, R(28)=1
```

## Partition Function Definition

```
  Z_n(β) = Σ_{d|n} e^{-βd}

  n=6:  Z_6(β)  = e^{-β} + e^{-2β} + e^{-3β} + e^{-6β}
  n=28: Z_28(β) = e^{-β} + e^{-2β} + e^{-4β} + e^{-7β} + e^{-14β} + e^{-28β}

  Limits:
    β→0:  Z_n(0)  = τ(n)           (number of states = divisor count)
    β→∞:  Z_n(β) → e^{-β}          (only minimum divisor d=1 survives)
```

## Thermodynamic Quantities

### Internal Energy U = -∂ln(Z)/∂β = Σ d·e^{-βd} / Z

| β | Z_6 | U_6 | S_6 | C_v,6 |
|---:|---:|---:|---:|---:|
| 0.01 | 3.8825 | 2.9652 | 1.3861 | 0.0003 |
| 0.05 | 3.4576 | 2.8309 | 1.3821 | 0.0082 |
| 0.10 | 3.0132 | 2.6741 | 1.3704 | 0.0301 |
| 0.20 | 2.3391 | 2.3997 | 1.3297 | 0.0994 |
| 0.30 | 1.8615 | 2.1756 | 1.2741 | 0.1806 |
| 0.50 | 1.2473 | 1.8523 | 1.1471 | 0.3205 |
| 0.70 | 0.8806 | 1.6433 | 1.0232 | 0.4156 |
| 1.00 | 0.5555 | 1.4452 | 0.8573 | 0.5155 |
| 1.50 | 0.2842 | 1.2556 | 0.6251 | 0.6236 |
| 2.00 | 0.1561 | 1.1493 | 0.4415 | 0.6381 |
| 3.00 | 0.0524 | 1.0520 | 0.2070 | 0.4863 |
| 5.00 | 0.0068 | 1.0068 | 0.0407 | 0.1707 |

### Special Points

```
  β=0:      U_6 = σ(6)/τ(6) = 12/4 = 3.0  (average divisor)
  β=0.0855: U_6 = e ≈ 2.718               (natural constant)
  β=0.3974: U_6 = φ(6) = 2.0              (Euler function)
  β→∞:      U_6 → 1                        (minimum divisor)
  β→-∞:     U_6 → 6 = n                    (maximum divisor = n itself)
```

There is no finite β* where U_6 = n = 6 (asymptotic at β→-∞).

## ASCII Graphs

### Z_6(β) — Partition Function

```
  Z
  3.88 |*
  3.63 | *
  3.37 |  *
  3.12 |
  2.86 |   *
  2.61 |
  2.35 |    *
  2.10 |     *
  1.84 |      *
  1.58 |       *
  1.33 |        **
  1.07 |          **
  0.82 |            ****
  0.56 |                *****
  0.31 |                     ***********
  0.05 |                                *******************
       +------------------------------------------------------
       0.0                  1.5                           3.0
                           beta
```

Starting from Z_6(0) = τ(6) = 4, decreases exponentially with increasing β.
Near β≈1, drops sharply to Z≈0.56 — high-energy divisors (3, 6) are suppressed.

### S_6(β) — Entropy

```
  S
  1.39 |***
  1.31 |   **
  1.23 |     ***
  1.15 |        **
  1.07 |          **
  0.99 |            **
  0.91 |              **
  0.84 |                ***
  0.76 |                   **
  0.68 |                     ***
  0.60 |                        ****
  0.52 |                            ***
  0.44 |                               ****
  0.36 |                                   *****
  0.29 |                                        ******
  0.21 |                                              ****
       +------------------------------------------------------
       0.0                  1.5                           3.0
                           beta
```

S_6(0) = ln(4) = 1.386 (maximum entropy, uniform distribution over 4 divisors).
Monotonically decreasing, S→0 as β→∞ (only d=1 occupied).

### C_v,6(β) — Heat Capacity

```
  C_v
  0.64 |                         ***********
  0.60 |                     ****           *****
  0.56 |                  ***                    ****
  0.52 |                **                           ****
  0.47 |              **                                 *
  0.43 |            **
  0.39 |          **
  0.34 |         *
  0.30 |        *
  0.26 |       *
  0.22 |      *
  0.17 |     *
  0.13 |    *
  0.09 |   *
  0.04 |  *
  0.00 |**
       +------------------------------------------------------
       0.0                  1.5                           3.0
                           beta
```

Heat capacity reaches maximum C_v ≈ 0.638 at β≈2.0.
**Schottky anomaly**-like peak — characteristic of discrete energy level systems.
"Quasi-2-level" transition created by 4 divisors (d=1 vs d=2,3,6).

## Heat Capacity Comparison: n=6 vs n=28

| β | C_v(6) | C_v(28) | C_v(28)/C_v(6) |
|---:|---:|---:|---:|
| 0.01 | 0.0003 | 0.0079 | 22.8 |
| 0.05 | 0.0082 | 0.1173 | 14.4 |
| 0.10 | 0.0301 | 0.2352 | 7.8 |
| 0.20 | 0.0994 | 0.3201 | 3.2 |
| 0.30 | 0.1806 | 0.3679 | 2.0 |
| 0.50 | 0.3205 | 0.4401 | 1.4 |
| 1.00 | 0.5155 | 0.4973 | 1.0 |
| 2.00 | 0.6381 | 0.4920 | 0.8 |
| 3.00 | 0.4863 | 0.4158 | 0.9 |

n=28 has 6 divisors (wider energy spectrum), so much larger heat capacity at low temperature.
At β=0.3, C_v(28)/C_v(6) ≈ 2.0 — and **C_v(28)(β=0.3) = 0.3679 ≈ 1/e**!

## High-Temperature Limit Interpretation of σ(n)

```
  At β=0:
    Z_n(0) = τ(n)                    (number of states)
    U_n(0) = Σd / τ(n) = σ(n)/τ(n)  (average energy)

  Therefore:
    σ(n) = τ(n) × U_n(0) = (number of states) × (average energy)

  This is the thermodynamic meaning of σ(n):
    divisor sum = total energy expectation × degeneracy at high-temperature limit
```

Perfect number condition σ(n) = 2n gives:
```
  2n = τ(n) × U_n(0)
  U_n(0) = 2n/τ(n)

  n=6:  U_6(0)  = 12/4 = 3.0  = n/2
  n=28: U_28(0) = 56/6 = 9.33 = n/3

  General perfect number: U_n(0) = 2n/τ(n)
```

## Lee-Yang Zero Analysis

Analyzing zeros of Z_6(β) in variable z = e^{-β}:

```
  Z_6 = z + z² + z³ + z⁶ = z(1 + z + z² + z⁵)

  Roots of 1 + z + z² + z⁵ = 0:
    z₀ = 0.8518 + 0.9113i   |z| = 1.2474
    z₁ = 0.8518 - 0.9113i   |z| = 1.2474
    z₂ = -1.0000             |z| = 1.0000   ← On unit circle!
    z₃ = -0.3518 + 0.7203i  |z| = 0.8017
    z₄ = -0.3518 - 0.7203i  |z| = 0.8017
```

- **No positive real roots** → No phase transition on real β axis.
- z₂ = -1 corresponds to β = iπ — antiferromagnetic zero at imaginary temperature.
- n=28 also has 0 positive real roots → perfect numbers have no real-axis phase transitions.

This is consistent with **Lee-Yang theorem**: Non-interacting systems without Fermi interaction
have no real-axis phase transitions. Divisors don't "interact" with each other, so this is expected.

## Thermodynamic Meaning of Golden Zone Width

Key equation:
```
  S_6(0) = ln(τ) = ln(4) = ln(3) + ln(4/3)
                          = ln(σ/τ) + Golden Zone width

  i.e.: maximum_entropy = ln(average_divisor) + Golden_Zone_width
```

This decomposition is arithmetically trivial (ln(4) = ln(4)) but semantically non-trivial:

| Term | Value | Meaning |
|---|---|---|
| S_6(0) = ln(4) | 1.3863 | Maximum disorder of uniform distribution over 4 divisors |
| ln(σ/τ) = ln(3) | 1.0986 | Log of average energy scale |
| ln(4/3) | 0.2877 | **Excess disorder** = Golden Zone width |

**Golden Zone width = Residual disorder after subtracting energy scale from maximum entropy**.
This is why it's equivalent to "3→4 state entropy jump":
- Information increase from 3 divisors (energy scale) → 4 divisors (total states).

## Special Structure at β* = 0.3974 (U = φ(n))

```
  At β* ≈ 0.3974, U_6 = φ(6) = 2

  At this temperature:
    Z_6(β*)  = 1.5194
    S_6(β*)  = 1.2131
    C_v(β*)  ≈ 0.267

  S_6(β*) = 1.2131 ≈ ?
    Compare: ln(σ/τ) = ln(3) = 1.0986
             ln(e)   = 1.0
             Far from Golden Zone upper bound = 1/2

  β* ≈ 0.3974 ≈ ln(4/3) + 0.110
    Near Golden Zone width but not exactly matching.
```

## Limitations

1. **Non-interacting model**: Divisors occupy independently — unlike real physics,
   doesn't reflect correlations between divisors (e.g., d₁×d₂=n).
2. **No Lee-Yang zeros**: No phase transitions, limiting "critical phenomena" interpretation.
3. **ln(4) = ln(3) + ln(4/3)** decomposition is arithmetically an identity,
   so caution needed in assigning physical meaning.
4. Special value at β* (U=φ) not verified to be significant for other perfect numbers (n=28).
5. Interpreting divisors as energy levels is itself an analogy without physical justification.

## Verification Directions

- [ ] Calculate β*(U=φ(28)=12) for n=28 and compare
- [ ] Extend non-interacting → interacting model: Z_n(β,J) = Σ e^{-β Σd - J Σ_{d₁d₂=n}}
- [ ] Generalize relationship between Schottky peak position β_peak and divisor distribution
- [ ] Test significance of C_v(28)(β=0.3) ≈ 1/e observation (coincidence?)
- [ ] Explore thermodynamic role of other number-theoretic functions (Möbius μ, Liouville λ)
- [ ] Compare C_v profiles of perfect vs abundant vs deficient numbers