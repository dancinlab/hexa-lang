# H-UD-3: Crystallographic Restriction = div(6) U {tau(6)}
**n6 Grade: 🟩 EXACT** (auto-graded, 9 unique n=6 constants)


**Grade: ★★★**
**Status: Verified (exact theorem match)**
**Date: 2026-03-27**
**Golden Zone Dependency: None (pure mathematics + crystallography)**

## Hypothesis

> The crystallographic restriction theorem states that the only rotational
> symmetries compatible with a periodic lattice in 2D/3D are orders
> {1, 2, 3, 4, 6}. This set is EXACTLY div(6) U {tau(6)} = {1,2,3,6} U {4}.
> The allowed symmetries of crystals are the divisors of the first perfect
> number, plus its divisor count.

## Background

The crystallographic restriction theorem is a proven result in mathematics
and physics. It constrains which rotational symmetries can appear in
crystalline structures:

- A 2D lattice can only have n-fold rotational symmetry for n in {1,2,3,4,6}.
- A 3D lattice inherits this same constraint.
- This is why there are exactly 17 wallpaper groups (2D) and 230 space
  groups (3D), not infinitely many.

The proof relies on the fact that rotation matrices with integer entries
(required for lattice compatibility) restrict cos(2*pi/n) to be a half-integer
or zero, yielding only n in {1, 2, 3, 4, 6}.

n=6 constants:
- div(6) = {1, 2, 3, 6}
- tau(6) = 4

## The Exact Match

```
  Allowed rotational orders:    {1, 2, 3, 4, 6}
  div(6):                       {1, 2, 3, 6}
  tau(6):                       4
  div(6) U {tau(6)}:            {1, 2, 3, 4, 6}   <--- EXACT MATCH

  FORBIDDEN orders: 5, 7, 8, 9, 10, 11, ...
  These are NOT divisors of 6 and NOT tau(6).
```

## Lattice Symmetry Diagram

```
  Allowed rotational symmetries in 2D lattices:

  n=1 (trivial)     n=2 (180 deg)     n=3 (120 deg)
  .                  . <---> .         .
                                      / \
                                     .   .

  n=4 (90 deg)      n=6 (60 deg)
  . --- .            .   .
  |     |           . .'. .
  . --- .            .   .

  FORBIDDEN:
  n=5 (72 deg)       n=7 (51.4 deg)
  Cannot tile!       Cannot tile!
    .                  Cannot form
   / \                 periodic lattice
  .   .
   \ /
    .
  (gaps remain)
```

## Proof Sketch (Why Only These Orders)

For an n-fold rotation to be compatible with a lattice, the trace
of the rotation matrix must be an integer:

```
  2*cos(2*pi/n) must be an integer

  n=1:  2*cos(2*pi)   = 2*1     = 2   (integer)  ALLOWED
  n=2:  2*cos(pi)     = 2*(-1)  = -2  (integer)  ALLOWED
  n=3:  2*cos(2*pi/3) = 2*(-1/2)= -1  (integer)  ALLOWED
  n=4:  2*cos(pi/2)   = 2*0     = 0   (integer)  ALLOWED
  n=5:  2*cos(2*pi/5) = 2*0.309 = 0.618...       FORBIDDEN
  n=6:  2*cos(pi/3)   = 2*1/2   = 1   (integer)  ALLOWED
  n=7:  2*cos(2*pi/7) = 2*0.623 = 1.247...       FORBIDDEN
  n=8:  2*cos(pi/4)   = 2*0.707 = 1.414...       FORBIDDEN
```

The integer constraint filters to exactly {1, 2, 3, 4, 6}.

## Verification

| Property                    | Value         | Status    |
|-----------------------------|---------------|-----------|
| Crystallographic allowed    | {1,2,3,4,6}  | THEOREM   |
| div(6)                      | {1,2,3,6}    | EXACT     |
| tau(6)                      | 4             | EXACT     |
| div(6) U {tau(6)}           | {1,2,3,4,6}  | EXACT     |
| Set equality                | Yes           | PROVED    |

This is not an approximation or a statistical claim. It is an
exact set equality between a crystallographic theorem and n=6
arithmetic.

## Connection to Other Hypotheses

- **H-UD-8 (Hexagonal Tiling)**: The n=6 symmetry is the highest
  allowed order, and hexagonal tiling is optimal (Hales 1999).
- **H-UD-1 (Music)**: Both music and crystals are constrained by
  small-integer relationships, and both land on n=6.
- **H-090 (Master Formula)**: sigma_{-1}(6) = 2, the defining
  property of perfect numbers, generates the divisor set.

## Significance

This is arguably the strongest n=6 correspondence because:
1. The theorem is PROVED (not empirical).
2. The match is EXACT (not approximate).
3. The set {1,2,3,4,6} is not trivially "small integers" — it
   specifically excludes 5, which IS a small integer.
4. The exclusion of 5-fold symmetry (and its presence in
   quasicrystals, which are NOT periodic) reinforces that this
   set is special.

## Limitations

- The crystallographic restriction follows from the integer trace
  condition on rotation matrices. The connection to n=6 may be
  coincidental — both are consequences of small-integer arithmetic.
- In higher dimensions (d >= 4), additional symmetry orders become
  allowed, breaking the n=6 correspondence.
- Quasicrystals (Shechtman, 1984 Nobel) exhibit 5-fold and other
  "forbidden" symmetries, showing nature is not strictly limited
  to this set.
- The decomposition {1,2,3,6} U {4} is post-hoc — one could also
  write {1,2,3,4} U {6} or other partitions.

## Next Steps

- Investigate whether the 17 wallpaper groups have further n=6
  structure in their classification.
- Check if the 230 space groups contain n=6 arithmetic in their
  enumeration.
- Extend to 4D: which new symmetry orders appear, and do they
  relate to n=28?
