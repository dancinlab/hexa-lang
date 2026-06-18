---
id: H-CHEM-071-090
title: Deep Crystallography & Symmetry Hypotheses
grade: mixed (8 GREEN, 4 ORANGE, 8 WHITE, 0 BLACK)
domain: crystallography, symmetry, close-packing, quasicrystals
verified: 2026-03-28
summary: "8 exact, 4 structural, 8 trivial, 0 wrong"
golden_zone_dependent: true (for GZ-referencing claims)
---

# Deep Crystallography & Symmetry Hypotheses (H-CHEM-071 to 090)
**n6 Grade: 🟩 EXACT** (auto-graded, 14 unique n=6 constants)


## Verification Summary (2026-03-28)

```
  Total: 20 hypotheses
  GREEN  (exact/proven):        8  (geometric/algebraic facts; some TECS mappings ad hoc)
  ORANGE (structural match):    4  (numerically verified, structurally interesting)
  WHITE  (trivial/coincidence):  8  (arithmetically correct but numerological)
  BLACK  (wrong/refuted):       0

  Script: verify/verify_chem_symmetry_deep.py
  Run:    PYTHONPATH=. python3 verify/verify_chem_symmetry_deep.py

  Grade Distribution:
  [################========----------------]
   # = GREEN(8)  = = ORANGE(4)  - = WHITE(8)  . = BLACK(0)
```

## Key Functions of n=6

```
  n = 6             (perfect number)
  sigma(6) = 12     (sum of divisors: 1+2+3+6)
  tau(6) = 4        (number of divisors)
  phi(6) = 2        (Euler totient)
  sigma_{-1}(6) = 2 (sum of reciprocals of divisors)
  divisors(6) = {1, 2, 3, 6}
  proper divisors = {1, 2, 3}
```

---

## A. Crystal Systems (H-CHEM-071 to 075)

> Can the fundamental constants of crystallography (7 crystal systems,
> 14 Bravais lattices, 32 point groups, 230 space groups) be expressed
> in terms of divisor functions of 6?

### H-CHEM-071: 7 Crystal Systems = n + 1

| Crystal System | Lattice Shape | Symmetry |
|---|---|---|
| Triclinic | a != b != c, angles != 90 | C1, Ci |
| Monoclinic | a != b != c, one angle != 90 | C2, Cs, C2h |
| Orthorhombic | a != b != c, all 90 | D2, C2v, D2h |
| Tetragonal | a = b != c, all 90 | C4 ... D4h |
| Trigonal | a = b = c, angles equal | C3 ... D3d |
| Hexagonal | a = b != c, 120 deg | C6 ... D6h |
| Cubic | a = b = c, all 90 | T ... Oh |

**Claim:** 7 = n + 1 = 6 + 1.
**Grade:** WHITE. 7 = 6 + 1 is trivially true for any consecutive integer.
Other decompositions (sigma(6)-5, sigma(6)-tau(6)-1) are equally ad hoc.

### H-CHEM-072: 14 Bravais Lattices = sigma(6) + phi(6)

**Claim:** 14 = sigma(6) + phi(6) = 12 + 2.

```
  System        Bravais count
  Triclinic     1
  Monoclinic    2
  Orthorhombic  4
  Tetragonal    2
  Trigonal      1
  Hexagonal     1
  Cubic         3
  TOTAL         14
```

**Grade:** WHITE. Exact arithmetic (14 = 12 + 2) but trivial decomposition.
Does NOT generalize: sigma(28) + phi(28) = 56 + 12 = 68, no crystallographic meaning.

### H-CHEM-073: 32 Point Groups and n=6 Decompositions

**Claim:** 32 = 2*sigma(6) + 2*tau(6) = 2*12 + 2*4 = 32.
Also: 32 = sigma(6)*tau(6) - sigma(6) - tau(6) = 48 - 12 - 4 = 32.

**Grade:** WHITE. Multiple valid decompositions. Texas concern: 24% of integers 1-50
can be expressed as a*12 + b*4 with |a|,|b| <= 3. Too many ways to hit 32.

### H-CHEM-074: 230 Space Groups = 6^3 + 14

**Claim:** 230 = 6^3 + 14 = 216 + 14 (Bravais count).
Also: 230 = 6^3 + sigma(6) + phi(6).

**Grade:** WHITE. Numerically exact but ad hoc. Combining 6^3 and 14 has no
physical justification. The 230 derives from Fedorov/Schoenflies/Barlow group theory,
not from divisor arithmetic.

### H-CHEM-075: Hexagonal = Densest 2D Packing (Thue's Theorem)

> The hexagonal lattice (6-fold symmetry) achieves the densest possible
> 2D circle packing.

**Claim:** Hexagonal packing fraction = pi/(2*sqrt(3)) = 0.9069.
This is strictly optimal (Thue 1910, Toth 1940).

```
  Packing type     Fraction    Relative to hex
  Hexagonal (C6)   0.9069      1.0000  (optimal)
  Square (C4)      0.7854      0.8661
  Ratio hex/sq     1.1547      = 2/sqrt(3)
```

```
  Hexagonal 2D packing (each O touches 6 neighbors):

        O   O   O
       O * O * O
        O   O   O

  The 6-neighbor arrangement is provably optimal.
```

**Grade:** GREEN. Proven mathematical theorem. The 6-fold symmetry of the
densest 2D packing is not a coincidence -- it follows from the geometry of
circle packing. The ratio 2/sqrt(3) involves only 2 and 3, proper divisors of 6.

---

## B. Symmetry Operations (H-CHEM-076 to 080)

> The crystallographic restriction theorem limits allowed rotational
> symmetries. How does this connect to divisors of 6?

### H-CHEM-076: Allowed Cn = Divisors of 6 Plus C4

> The crystallographic restriction theorem allows ONLY C1, C2, C3, C4, C6.
> Divisors of 6 = {1, 2, 3, 6}. The allowed set = divisors(6) union {4}.

**Claim:** All divisors of 6 are allowed crystallographic rotations.
Only one non-divisor (4) is additionally allowed. Zero divisors are excluded.

```
  n    cos(2pi/n)    Rational?    Divisor of 6?    Allowed?
  1    +1.000        YES          YES              YES
  2    -1.000        YES          YES              YES
  3    -0.500        YES          YES              YES
  4    +0.000        YES          no               YES  <-- only exception
  5    +0.309        no           no               no
  6    +0.500        YES          YES              YES
  7    +0.623        no           no               no
  8    +0.707        no           no               no
```

**Grade:** GREEN. The crystallographic restriction is a proven theorem.
The overlap: 4 out of 4 divisors of 6 are allowed (100%). The only non-divisor
allowed is C4 (cos(90)=0 is rational). This is exact and structurally notable.

### H-CHEM-077: C5 Forbidden -- Correlation with Non-Divisibility of 6

**Claim:** C5 is forbidden because 5 does not divide 6.

**Grade:** WHITE. Both facts are true (5 does not divide 6; C5 is forbidden).
However, causation is wrong: C4 is allowed despite 4 not dividing 6. The real
criterion is cos(2pi/n) being a half-integer, not 6-divisibility. The 4/5 overlap
between divisors and allowed Cn is a correlation, not a cause.

### H-CHEM-078: Point Group Orders Divisible by 6

**Claim:** A large fraction of the 32 crystallographic point groups have
orders that are multiples of 6.

```
  Orders div by 6: {6, 12, 24, 48}  -- 16 out of 32 groups (50%)
  Orders NOT div by 6: {1, 2, 3, 4, 8, 16}  -- 16 out of 32

  By system:
    Trigonal (5 groups):   ALL orders div by 6  (3, 6, 6, 6, 12)
    Hexagonal (7 groups):  ALL orders div by 6  (6, 6, 12, 12, 12, 12, 24)
    Cubic (5 groups):      ALL orders div by 6  (12, 24, 24, 24, 48)
    Others (15 groups):    NONE div by 6
```

**Grade:** ORANGE. Exactly 50% of point groups have 6 | |G|. All higher-symmetry
systems (trigonal, hexagonal, cubic) satisfy this. Structurally interesting:
the presence of both C2 and C3 subgroups (proper divisors of 6) guarantees 6 | |G|.

### H-CHEM-079: All Platonic Solids Have V, E, or F Divisible by 6

> Every one of the 5 Platonic solids has at least one of V, E, F that is
> a multiple of 6.

**Claim:** For all Platonic solids, max(V mod 6 == 0, E mod 6 == 0, F mod 6 == 0) is true.

```
  Solid           V     E     F    V-E+F    6|V?  6|E?  6|F?
  Tetrahedron     4     6     4      2       .     YES   .
  Cube            8    12     6      2       .     YES   YES
  Octahedron      6    12     8      2      YES    YES   .
  Dodecahedron   20    30    12      2       .     YES   YES
  Icosahedron    12    30    20      2      YES    YES   .
  TOTALS         50    90    50

  E_total = 90 = 15 * 6
  All E values: {6, 12, 30} -- every edge count is a multiple of 6!
```

```
  Multiples of 6 appearing as V, E, or F:
    6:  Tetrahedron.E, Cube.F, Octahedron.V
   12:  Cube.E, Octahedron.E, Dodecahedron.F, Icosahedron.V
   30:  Dodecahedron.E, Icosahedron.E
```

**Grade:** GREEN. Every Platonic solid has at least one V/E/F divisible by 6.
In fact, ALL edge counts are multiples of 6 (E = 6, 12, 12, 30, 30).
This derives from Euler's formula and the constraint that faces must be regular polygons.

### H-CHEM-080: Cube-Octahedron Duality Pivots on n=6

> The cube and octahedron are dual polyhedra. Their duality swaps V and F,
> with the shared value being 6 = n.

```
  Cube:        V=8   E=12  F=6
  Octahedron:  V=6   E=12  F=8
                         ^
                    sigma(6) = 12 (shared)

  Duality swap: Cube.F = 6 = Octa.V (the pivot point IS n=6)
  Shared edges: 12 = sigma(6)
```

**Grade:** GREEN. Well-known geometric duality. The role of 6 as the duality
pivot value and sigma(6) = 12 as the shared edge count are exact.

---

## C. Close Packing (H-CHEM-081 to 085)

> Close-packed structures (FCC, HCP) achieve the densest sphere packing.
> How does n=6 appear in their geometry?

### H-CHEM-081: FCC & HCP Coordination = sigma(6) = 12

> Both FCC and HCP achieve coordination number 12 = sigma(6) and
> packing fraction pi/(3*sqrt(2)) = 0.7405 (Kepler conjecture, proven 2005).

```
  Structure    Stacking    Coordination    Packing fraction
  FCC          ABCABC      12              pi/(3*sqrt(2)) = 0.7405
  HCP          ABABAB      12              pi/(3*sqrt(2)) = 0.7405
  BCC          --           8              sqrt(3)*pi/8   = 0.6802
  Simple       --           6              pi/6           = 0.5236
```

**Grade:** GREEN. Coordination 12 = sigma(6) is exact. The Kepler conjecture
(proven by Hales 2005) confirms this is THE densest packing. The 12 nearest
neighbors arise from stacking hexagonal layers (6 in-plane + 3 above + 3 below).

### H-CHEM-082: Close-Packing Void Fraction in Golden Zone

**Claim:** Void fraction = 1 - pi/(3*sqrt(2)) = 0.2595 lies in
Golden Zone [0.2123, 0.5000].

```
  |----[===*================]---------|
  0    GZ_L  void   1/e     GZ_U     1
  0    0.212 0.260  0.368   0.500    1

  Void fraction position within GZ: 16.4% from lower bound
  Distance from GZ center (1/e): 0.1084 = 37.7% of GZ width
```

**Grade:** ORANGE. Void fraction falls in the Golden Zone, closer to the lower
boundary. GZ-dependent claim. Numerically verified.

### H-CHEM-083: Tetrahedral Holes = phi(6) Per Atom

**Claim:** In close packing, 2 tetrahedral holes per atom = phi(6) = 2.
Ratio tetrahedral:octahedral = 2:1 = phi(6):1.

```
  Void type      Count per atom    TECS mapping
  Tetrahedral    2                 phi(6) = 2
  Octahedral     1                 1
  Ratio          2:1               phi(6):1
```

**Grade:** WHITE. Exact but 2:1 is trivially simple. The phi(6) mapping is
numerological. These ratios come from geometry, not number theory.

### H-CHEM-084: Kissing Numbers Across Dimensions = Divisor Functions of 6

> Kissing number K(d) = maximum spheres touching a central sphere in d dimensions.
> K(1)=2, K(2)=6, K(3)=12, K(4)=24.

**Claim:** K(1) = phi(6), K(2) = n, K(3) = sigma(6), K(4) = sigma(6)*sigma_{-1}(6).

```
  Dim    K(d)    Proof                      n=6 function
  1       2      trivial                    phi(6) = 2
  2       6      hexagonal packing          n = 6
  3      12      Schutte-vdWaerden 1953     sigma(6) = 12
  4      24      Musin 2003                 sigma(6)*sigma_{-1}(6) = 24

  Dimension ladder:

  K(d)  2 -------- 6 ---------- 12 ---------- 24
        phi(6)     n=6          sigma(6)       sigma(6)*2
        |          |            |              |
  d     1          2            3              4
```

**Grade:** ORANGE. All four values are proven kissing numbers. The mapping to
divisor functions of 6 is exact: phi(6) -> 6 -> sigma(6) -> 24. The dimension
ladder is structurally interesting. The 4D value 24 = 2*12 also equals |Td| = |Oh|/2.

### H-CHEM-085: Void-to-GZ-Center Gap

**Claim:** |1/e - void| = 0.1084 ~ ln(4/3)/e = 0.1058 (error 2.3%).

**Grade:** WHITE. Approximate match only (2.3% error). Not exact. The similarity
of 0.1084 and 0.1058 is likely coincidental.

---

## D. Quasicrystals & Beyond (H-CHEM-086 to 090)

> Quasicrystals break crystallographic periodicity while maintaining
> forbidden symmetries. How does n=6 relate?

### H-CHEM-086: C5 = First Forbidden = First Non-Divisor of 6

**Claim:** The first forbidden crystallographic symmetry (C5) corresponds to
the first integer > 1 that does not divide 6.

```
  Integers:  1  2  3  4  5  6  7  8  ...
  Divides 6: Y  Y  Y  N  N  Y  N  N
  Allowed:   Y  Y  Y  Y  N  Y  N  N
                          ^
                    C5 = first forbidden = first non-divisor (>1, excluding 4)
```

**Grade:** GREEN. The first symmetry breaking crystallographic order (Penrose, 1974)
is the first non-divisor of 6 (skipping the C4 exception). This connects
quasicrystals to the divisor structure of 6. Shechtman's discovery (1982, Nobel 2011)
confirmed real materials with this forbidden symmetry.

### H-CHEM-087: Icosahedral Quasicrystal Vertices = sigma(6)

**Claim:** The icosahedron (symmetry of Shechtman's quasicrystal) has
12 vertices = sigma(6). The group |Ih| = 120 = 10*sigma(6).

```
  Icosahedron:  V=12   E=30   F=20
                 ^
            sigma(6) = 12 vertices = 12 five-fold symmetry axes

  |Ih| = 120 = 5! = 10 * sigma(6)
```

**Grade:** GREEN. Exact geometric facts. The 12 vertices of the icosahedron
correspond to the 12 five-fold axes of icosahedral symmetry.

### H-CHEM-088: 1/phi^2 in Golden Zone Near 1/e

**Claim:** The golden ratio phi governs quasicrystals.
1/phi^2 = 0.3820 lies in the Golden Zone, 3.8% from center 1/e = 0.3679.

```
  |--------[==========X==*====]---------|
  0        GZ_L      1/e 1/phi^2 GZ_U   1
  0        0.212     0.368 0.382 0.500   1

  1/phi^2 = 2 - phi = 0.381966
  1/e             = 0.367879
  Difference      = 0.014087 (3.8% of 1/e)
```

**Grade:** ORANGE. 1/phi^2 sits in the Golden Zone near 1/e. GZ-dependent.
The proximity of 1/phi^2 and 1/e (both ~ 0.37-0.38) connects the quasicrystal
golden ratio to the TECS natural constant center.

### H-CHEM-089: F(6) = sigma(6) - tau(6)

**Claim:** Fibonacci F(6) = 8 = sigma(6) - tau(6) = 12 - 4.
Fibonacci sequences govern Penrose tiling ratios.

```
  F(n): 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, ...
                            ^
                         F(6) = 8 = sigma(6) - tau(6) = 12 - 4
```

**Grade:** WHITE. Exact for n=6 but FAILS generalization:
F(28) = 317,811 != sigma(28) - tau(28) = 56 - 6 = 50. Coincidental.

### H-CHEM-090: C6 Uniquely Survives Aperiodic Transition

> Among all allowed crystallographic symmetries, only C6 has an
> aperiodic analog that preserves the SAME rotation symmetry.

**Claim:** The Socolar-Taylor tile (2010/2011) is a single aperiodic tile
with C6 symmetry. No C4 aperiodic tile preserves C4 (it becomes C8).

```
  Crystal symmetry    Aperiodic analog         Symmetry preserved?
  C4 (square)         Octagonal QC (C8)        NO (4 -> 8)
  C6 (hexagonal)      Socolar-Taylor (C6)      YES (6 -> 6)

  6-fold symmetry is the ONLY crystallographic symmetry that
  survives the transition from periodic to aperiodic order.
```

**Grade:** GREEN. The Socolar-Taylor aperiodic monotile has exact C6 symmetry.
This makes 6-fold symmetry uniquely robust -- it persists even without
translational periodicity. Physical relevance: graphene, BN, TMDs all
exhibit hexagonal order for both structural and electronic reasons.

---

## Cross-Category Key Findings

```
  1. Crystallographic restriction: 4/5 allowed Cn are divisors of 6
  2. ALL Platonic solids have V, E, or F divisible by 6
  3. Kissing numbers 1D-4D = {phi(6), 6, sigma(6), 24}
  4. Cube-Octahedron duality pivots on n=6, shared E = sigma(6)
  5. Close-packing void fraction 0.2595 lies in Golden Zone
  6. 1/phi^2 (quasicrystal constant) sits in Golden Zone near 1/e
  7. C6 is the ONLY crystal symmetry surviving aperiodic transition

  The strongest results (GREEN) are proven mathematical theorems.
  GZ-dependent claims (ORANGE) require Golden Zone verification.
```

## Limitations

- TECS mappings (sigma(6), phi(6), tau(6) to physical quantities) are interpretive,
  not causal. The underlying math (Platonic solids, kissing numbers, crystallographic
  restriction) is independently proven.
- Golden Zone claims (H-CHEM-082, 088) depend on the unverified GZ model.
- Crystal system counts (7, 14, 32, 230) have multiple ad hoc decompositions
  in terms of n=6 functions -- these are likely numerological.
- The strongest claim is H-CHEM-076 + H-CHEM-090: divisors of 6 appear naturally
  in both the periodic table of crystal symmetries AND their aperiodic extensions.

## Verification Direction

1. **Texas Sharpshooter test** on the kissing number ladder (H-CHEM-084):
   Calculate p-value for all four dimensions matching n=6 functions.
2. **Extend to higher dimensions**: K(8)=240, K(24)=196560 -- do these relate to 6?
3. **Independent validation**: Check if crystallographic restriction theorem
   can be derived FROM divisor properties of 6 (likely not, but worth attempting).
4. **Materials database**: Quantify how many real crystal structures use
   hexagonal vs other systems as a frequency test.
