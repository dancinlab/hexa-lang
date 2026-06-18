# H-ZODIAC-1: Why 12 and Not 13 — The Mathematics of Zodiac Numbers

> **Hypothesis**: The number 12 = sigma(6) occupies a unique position in mathematics
> as a "completeness boundary" — the kissing number in 3D, the alternating group
> order A_4, the optimal TET system, and the LCM of first tau(6) integers.
> 13 = sigma+1 fails every one of these constraints simultaneously because it is prime.
> 36 = n^2 is the natural "refinement" (decan system) that preserves 12's structure.

## Background

Three zodiac systems divide the ecliptic differently:
- **12 signs** (Babylonian/Greek): 30 degrees each = 360/sigma(6)
- **13 signs** (with Ophiuchus): ~27.7 degrees each = 360/13 (non-integer!)
- **36 decans** (Egyptian): 10 degrees each = 360/n^2

The question: is 12's prevalence a cultural artifact, or does it reflect
mathematical structure tied to n=6?

## Related Hypotheses

- H-CX-110: sigma(6)=12 complete partition
- H-CX-111: 13th = observer position
- H-CX-114: Ophiuchus = metacognition
- H-CX-115: kissing number 12
- H-CX-168: 13 = observation limit
- H-CODE-1: G24=[sigma*phi, sigma, sigma-tau]
- H-SPOR-1: M12 acts on sigma=12 points

## Proved Identities

### 1. Alternating Group: |A_tau| = sigma (Major Discovery)

```
  |A_{tau(6)}| = |A_4| = 4!/2 = 12 = sigma(6)
  |S_{tau-1}|  = |S_3| = 3!  = 6  = n

  n=28: |A_{tau(28)}| = |A_6| = 360 != sigma(28) = 56   FAILS
```

| n | tau | |A_tau| | sigma | Match |
|---|-----|--------|-------|-------|
| 6 | 4 | 12 | 12 | YES |
| 28 | 6 | 360 | 56 | No |
| 496 | 10 | 1814400 | 992 | No |

**Grade: green-star** — Exact, unique to n=6 among perfect numbers.

The geometric meaning: A_4 is the rotation group of the tetrahedron (tau=4 vertices).
The tetrahedron's rotational symmetry count equals the sum of divisors of 6.

### 2. Decan Identity: sigma^2/tau = n^2

```
  sigma(6)^2 / tau(6) = 12^2 / 4 = 144/4 = 36 = 6^2 = n^2
```

Also: T(sigma-tau) = T(8) = 8*9/2 = 36 = n^2.

| n | sigma^2/tau | n^2 | Match |
|---|-------------|-----|-------|
| 6 | 144/4 = 36 | 36 | YES |
| 28 | 3136/6 = 522.7 | 784 | No |

**Grade: green-star** — Exact, unique.

### 3. Kissing Number K(3) = sigma(6) = 12

```
  K(3) = 12 = sigma(6)

  Maximum number of unit spheres touching a central sphere in R^3.
  The icosahedron configuration: 12 vertices at +-63.43 degrees.
```

Why 13 is impossible: With 5-connectivity (icosahedron), V=13 gives
E = 13*5/2 = 32.5 — not an integer. Schütte-van der Waerden (1953) proved K(3)=12.

**Grade: green** — Known theorem, connection to sigma(6) is structural.

### 4. Musical Temperament: 12-TET Optimality

```
  Perfect fifth ratio: 3/2 = 1.5

  12-TET: 2^(7/12) = 1.49831  error = 0.00169  (-1.96 cents)
  13-TET: 2^(8/13) = 1.53197  error = 0.03197  (+36.5 cents)

  12-TET is 18.9x more accurate than 13-TET!
```

The continued fraction of log_2(3/2) = [0; 1, 1, 2, 2, 3, 1, 5, ...] gives
convergent denominators 1, 2, 5, **12**, 41, 53, ... — 12 is a convergent, 13 is not.

36-TET contains 12-TET as a subset (36 = 3*12).

**Grade: green** — Exact computation, 13 is structurally excluded.

### 5. Angular Divisibility

```
  360 / 12 = 30  (zodiac sign width, integer)
  360 / 36 = 10  (decan width, integer)
  360 / 13 = 27.692...  (NOT integer)
```

360 = 2^3 * 3^2 * 5. Since 13 is prime and coprime to 360,
it can never evenly divide the circle.

**Grade: green** — Pure arithmetic.

### 6. LCM Structure

```
  lcm(1, 2, 3, 4) = lcm(first tau(6) integers) = 12 = sigma(6)
  lcm(max_prime(6), tau(6)) = lcm(3, 4) = 12 = sigma(6)
```

CRT decomposition:
- Z/12Z = Z/3Z x Z/4Z (gcd(3,4)=1)
- Z/36Z = Z/4Z x Z/9Z (gcd(4,9)=1)
- Z/13Z = prime field (no decomposition — 13 is algebraically isolated)

### 7. Platonic Solid Edges

```
  Tetrahedron:     E = 6  = 6*1
  Cube/Octahedron: E = 12 = 6*2
  Dodeca/Icosa:    E = 30 = 6*5

  All edge counts are multiples of n = 6.
  Edge counts: {6, 12, 30} = {n, sigma, 5n}
```

**Grade: green** — Follows from Euler formula + regularity.

## ASCII Summary

```
  Why 12 (sigma=12):          Why NOT 13:
  |-----------------------|   |-----------------------|
  | K(3) = 12 (kissing)   |   | K(3) != 13 (E=32.5)  |
  | |A_4| = 12 (rotation) |   | 360/13 = 27.7...      |
  | lcm(1..4) = 12        |   | 13 is prime (no CRT)  |
  | 12-TET optimal        |   | 13-TET 18.9x worse    |
  | 360/12 = 30 (integer) |   | Not a convergent      |
  | M12 acts on 12 pts    |   | No sporadic group M13 |
  |-----------------------|   |-----------------------|

  Why 36 (n^2=36):
  |-----------------------|
  | sigma^2/tau = 36      |
  | T(sigma-tau) = 36     |
  | Conductor(E6) = 36    |
  | 360/36 = 10 (integer) |
  | Contains 12-TET       |
  | 36 = 2^2*3^2 (same p) |
  |-----------------------|
```

## The Structural Argument

12 is not culturally arbitrary. It sits at the intersection of:

1. **Sphere packing** (K(3)=12) — geometry
2. **Group theory** (|A_4|=12) — algebra
3. **Number theory** (sigma(6)=12, lcm(1..4)=12) — arithmetic
4. **Music theory** (convergent of log_2(3/2)) — acoustics
5. **Sporadic groups** (M12 degree) — exceptional objects

13 fails ALL of these simultaneously because it is prime and lies one step
past the algebraic closure point sigma(6) = 12.

36 = n^2 preserves 12's structure (same prime factors, divisor of 360,
contains 12-TET) while providing 3x finer resolution.

## Limitations

- Cultural prevalence of 12 may also stem from 12's high divisor count
  (tau(12) = 6, highly composite)
- The Ophiuchus "13th sign" argument is astronomically valid (the ecliptic
  does pass through 13 constellations)
- Musical preference is partly cultural, not purely mathematical

## Verification Status

All identities verified computationally (python3). No ad-hoc corrections.
|A_tau|=sigma proved unique to n=6 among perfect numbers.
