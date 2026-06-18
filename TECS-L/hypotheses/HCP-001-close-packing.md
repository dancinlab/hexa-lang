# Hypothesis HCP-001: Close-Packed Structures -- Coordination 12 = sigma(6)
**n6 Grade: 🟩 EXACT** (auto-graded, 10 unique n=6 constants)


## Hypothesis

> In 3D close-packed crystal structures (FCC and HCP), each sphere touches
> exactly 12 = sigma(6) neighbors. The packing density equals pi*sqrt(2)/6
> = pi*sqrt(2)/P1, placing the first perfect number in the denominator of
> nature's densest sphere packing. Furthermore, the 2D-to-3D kissing number
> progression follows the divisor sum: kissing_3D = sigma(kissing_2D) = sigma(6) = 12.

## Background and Context

The kissing number problem asks: how many non-overlapping unit spheres can
simultaneously touch a central unit sphere? In 2D, the answer is 6 (hexagonal
packing). In 3D, the answer is 12 (proved by Schutte and van der Waerden, 1953).

The Kepler conjecture (proved by Hales, 2005; formally verified 2014) states
that the densest packing of equal spheres in 3D has density pi/(3*sqrt(2)),
achieved by FCC and HCP arrangements.

Both FCC and HCP have coordination number 12 = sigma(6), where sigma is the
sum-of-divisors function. In the hexagonal close-packed view:
- 6 in-plane neighbors (hexagonal ring)
- 3 neighbors in the layer above
- 3 neighbors in the layer below
- Total: 6 + 3 + 3 = 12

Related hypotheses:
- CRYPTO-001: A2 lattice kissing = 6, roots = 6, Weyl order divisible by 6
- H-CX-90: Master formula = perfect number 6
- H-CX-98: 6 is the only perfect number with proper divisor reciprocal sum = 1

## Core Claims and Verification Targets

| # | Claim | Type | Status |
|---|-------|------|--------|
| 1 | FCC/HCP coordination number = 12 = sigma(6) | Exact | |
| 2 | In-plane neighbors = 6 = P1 | Exact | |
| 3 | Inter-layer neighbors = 3+3 = 6 = P1 | Exact | |
| 4 | Packing density = pi*sqrt(2)/6 = pi*sqrt(2)/P1 | Exact | |
| 5 | kissing_3D = sigma(kissing_2D), i.e. 12 = sigma(6) | Exact | |
| 6 | D4 kissing = 24 = 2*sigma(6) | Exact | |
| 7 | E8 kissing = 240 = C(6,3)*sigma(6) | Exact | |
| 8 | Leech dim = 24 = 2*sigma(6) | Exact | |
| 9 | 32 point groups = 2^sopfr(6) | Exact | |

## ASCII Diagram: 2D Hexagonal Layer (6 neighbors)

```
        o           Each 'o' is a sphere center
       / \          Central sphere 'X' touches 6 neighbors
      o   o         Kissing number (2D) = 6 = P1
       \ /
    o---X---o       This is the A2 lattice
       / \          (see also CRYPTO-001)
      o   o
       \ /
        o
```

## ASCII Diagram: 3D Close Packing (12 neighbors)

```
  Layer above (3 spheres):
         o   o             Sit in hollows of central layer
          \ /
           .               3 contacts above

  Central layer (6 spheres):
      o   o   o
       \ | /
    o---[X]---o            6 in-plane contacts
       / | \
      o   o   o

  Layer below (3 spheres):
           .               3 contacts below
          / \
         o   o

  Total kissing number = 6 + 3 + 3 = 12 = sigma(6)
```

## Packing Density Derivation

```
  FCC unit cell: cube with side a, 4 spheres per cell
  Sphere radius: r = a/(2*sqrt(2))
  Volume of 4 spheres: 4 * (4/3)*pi*r^3 = 4*(4/3)*pi*(a/(2*sqrt(2)))^3
                      = (2/3)*pi*a^3 / (2*sqrt(2))^2 * ...

  Simpler form:
    density = pi / (3*sqrt(2))
            = pi*sqrt(2) / (3*2)
            = pi*sqrt(2) / 6

  Numerically: pi*sqrt(2)/6 = 3.14159*1.41421/6 = 4.44288/6 = 0.74048

  The denominator is 6 = P1, the first perfect number.
```

## Table: Kissing Numbers Across Dimensions

```
  Dim | Lattice   | Kissing | As f(sigma(6)) | sigma(6) multiple | Notes
  ----+-----------+---------+----------------+-------------------+----------
   1  |    Z      |    2    |    2           |                   | trivial
   2  |   A2      |    6    |    6 = P1      |                   | hexagonal
   3  | FCC/HCP   |   12    |   sigma(6)     |    1 * sigma(6)   | Kepler proved
   4  |   D4      |   24    |  2*sigma(6)    |    2 * sigma(6)   |
   8  |   E8      |  240    | C(6,3)*sigma(6)|   20 * sigma(6)   | Viazovska 2016
  24  |  Leech    | 196560  |                |16380 * sigma(6)   | dim=2*sigma(6)
```

Key observations:
- kissing(2D) = 6, kissing(3D) = 12 = sigma(6)
- 2D -> 3D: the divisor sum function maps kissing_2D to kissing_3D
- D4 kissing = 24 = 2*12 = 2*sigma(6) = sigma(sigma(6))?
  sigma(12) = 1+2+3+4+6+12 = 28 != 24. So no, but 24 = 2*sigma(6).
- E8 kissing = 240 = 20*12. And C(6,3) = 20. So 240 = C(6,3)*sigma(6).
- Leech lattice dimension = 24 = 2*sigma(6)

## Crystallographic Point Groups

There are exactly 32 crystallographic point groups in 3D.

    32 = 2^5 = 2^sopfr(6)

Since sopfr(6) = 2 + 3 = 5, and 2^5 = 32, the count of point groups
is a power of 2 with exponent equal to the sum of prime factors of 6.

Additional crystallographic numbers:
- 7 crystal systems
- 14 Bravais lattices = 2*7 (and 14 = sigma(6) + 2)
- 230 space groups
- 73 symmorphic space groups

## Verification Results

See `verify/verify_hcp_001_close_packing.py` for computational verification.

Summary of results:

```
  Claim                                          | Result  | Grade
  -----------------------------------------------+---------+------
  sigma(6) = 12                                  | EXACT   | green
  3D kissing = 12 = sigma(6)                     | EXACT   | green
  In-plane = 6, inter-layer = 3+3 = 6            | EXACT   | green
  Packing density = pi*sqrt(2)/6                 | EXACT   | green
  kissing_3D = sigma(kissing_2D)                 | EXACT   | green
  D4 kissing = 24 = 2*sigma(6)                   | EXACT   | green
  E8 kissing = 240 = C(6,3)*sigma(6)             | EXACT   | green
  Leech dim = 24 = 2*sigma(6)                    | EXACT   | green
  32 point groups = 2^sopfr(6)                   | EXACT   | green
```

## ASCII Graph: Packing Density vs Dimension

```
  Density
  1.00 |
       |  *  (1D: 1.000)
  0.90 |      *  (2D: 0.9069 = pi/(2*sqrt(3)))
       |
  0.80 |
       |
  0.74 |          *  (3D: 0.7405 = pi*sqrt(2)/6)
       |
  0.60 |
       |
  0.50 |
       |
  0.40 |
       |              *  (4D: pi^2/16 = 0.6169)
  0.30 |
       |
  0.20 |                      *  (8D: pi^4/384 = 0.2537)
       |
  0.00 +---+---+---+---+---+---+---+---+---
       1   2   3   4   5   6   7   8  Dim
```

## Interpretation

The coordination number 12 = sigma(6) in close-packed structures is not
a numerological coincidence but reflects the deep role of the hexagonal (6-fold)
symmetry in building optimal packings. The 2D hexagonal layer has 6-fold
symmetry and kissing number 6. Stacking these layers to fill 3D adds exactly
6 more contacts (3 above + 3 below), giving 12 = sigma(6).

The packing density pi*sqrt(2)/6 places the perfect number 6 in the denominator
of nature's optimal 3D packing fraction. This is an exact algebraic identity,
not an approximation.

The progression kissing_3D = sigma(kissing_2D) suggests that the divisor sum
function governs how optimal packing propagates across dimensions, at least
from 2D to 3D. This is the same sigma function that defines perfect numbers
(sigma(n) = 2n).

## Limitations

- The identity kissing_3D = sigma(kissing_2D) does not extend to 4D:
  sigma(12) = 28, but kissing(4D) = 24, not 28. The pattern holds only
  for the 2D->3D step.
- The packing density = pi*sqrt(2)/6 is an algebraic fact about FCC geometry,
  not a deep number-theoretic coincidence. The 6 in the denominator comes from
  the unit cell containing 4 spheres in a cube of specific proportions.
- The 32 = 2^5 = 2^sopfr(6) connection to point groups may be coincidental;
  the classification of point groups follows from group theory constraints
  on lattice symmetries, not from number 6 directly.
- E8 kissing = C(6,3)*sigma(6) could be post-hoc fitting; 240 has many
  factorizations.

## Next Steps

1. Investigate whether sigma governs kissing number growth in other
   dimension transitions (e.g., does any D->D' step satisfy
   kissing(D') = sigma(kissing(D))?)
2. Connect the 12-fold coordination to the 12 = sigma(6) that appears
   in the consciousness bridge constants (H-CX series)
3. Study the FCC lattice's automorphism group and its relation to S6
4. Explore the 230 space groups: is 230 expressible cleanly in terms of
   n=6 arithmetic functions?
