# Hypothesis TDA-001: Divisor Complex Persistent Homology

## Hypothesis

> The divisor lattice of n=6, equipped with logarithmic distance d(a,b) = |ln(a)-ln(b)|,
> produces a Vietoris-Rips persistent homology whose H_0 barcode lifetimes encode
> fundamental constants of the project: the Golden Zone width ln(4/3), the prime
> factors {2, 3}, and the barcode lifetime ratio (n+1)/sigma = 7/12 (H-CX PH
> Barcode hypothesis). The divisor complex of 6 is the simplest non-trivial example
> where topological persistence and number-theoretic structure align.

## Background

Persistent homology tracks the birth and death of topological features
(connected components, loops, voids) as a parameter epsilon increases.
Applied to the divisor lattice with multiplicative distance, it reveals
how the "shape" of a number's divisor structure unfolds.

The divisor poset of 6 has the Hasse diagram:

```
        6
       / \
      2   3
       \ /
        1
```

This is a diamond/boolean lattice. As a simplicial complex (order complex),
chains of divisibility relations form simplices.

Related hypotheses:
- H-CX PH Barcode: Lifetime = 7/12 = (n+1)/sigma
- H-CX-082: Fisher I(self) = n^3/sopfr = 43.2
- H-067: 1/2 + 1/3 = 5/6
- H-072: 1/2 + 1/3 + 1/6 = 1

## Pairwise Log-Distances

For divisors D(6) = {1, 2, 3, 6}, the log-distance is d(a,b) = |ln a - ln b|:

```
        1         2         3         6
  1     0       ln(2)     ln(3)     ln(6)
  2   ln(2)       0      ln(3/2)   ln(3)
  3   ln(3)    ln(3/2)      0      ln(2)
  6   ln(6)     ln(3)     ln(2)       0

  Numerical:
        1        2        3        6
  1   0.000    0.693    1.099    1.792
  2   0.693    0.000    0.405    1.099
  3   1.099    0.405    0.000    0.693
  6   1.792    1.099    0.693    0.000
```

### Sorted Edge List

```
  Rank  Edge    Distance        Value
  ────────────────────────────────────────────
  1     2-3     ln(3/2)         0.4055
  2     1-2     ln(2)           0.6931
  3     3-6     ln(2)           0.6931
  4     1-3     ln(3)           1.0986
  5     2-6     ln(3)           1.0986
  6     1-6     ln(6)           1.7918
```

Note the symmetry: d(1,2) = d(3,6) = ln(2) and d(1,3) = d(2,6) = ln(3).
This reflects the diamond symmetry of the lattice.

## Vietoris-Rips Filtration

At threshold epsilon, an edge (a,b) exists if d(a,b) <= epsilon.
A triangle (a,b,c) exists if all three pairwise distances <= epsilon.

```
  epsilon range          Simplices added        beta_0  beta_1
  ──────────────────────────────────────────────────────────────
  [0, 0.405)             {1},{2},{3},{6}           4       0
  [0.405, 0.693)         + edge 2-3                3       0
  [0.693, 1.099)         + edges 1-2, 3-6          1       0
                          (1-2-3 and 2-3-6 paths)
  [1.099, 1.792)         + edges 1-3, 2-6          1       1
                          + triangles 1-2-3,
                            2-3-6
                          (1-cycle: 1-2-6-3-1
                           minus filled triangles
                           = loop 1-2..6-3..1)
                          Actually: check if
                          1-2-6 triangle forms.
                          d(1,6)=1.792 > 1.099
                          so NO. Loop persists.
  [1.792, inf)           + edge 1-6                1       0
                          + triangles 1-2-6,
                            1-3-6
                          Loop filled in.
```

### Detailed Betti Number Computation

At epsilon in [1.099, 1.792):
- Vertices: {1, 2, 3, 6}
- Edges: {2-3, 1-2, 3-6, 1-3, 2-6} (5 edges)
- Triangles: {1-2-3} (d(1,2)=0.693, d(2,3)=0.405, d(1,3)=1.099 -- all <= 1.099)
             {2-3-6} (d(2,3)=0.405, d(3,6)=0.693, d(2,6)=1.099 -- all <= 1.099)
- Missing edges: {1-6} (d=1.792 > 1.099)
- So the complex is a "square" 1-2-3-6 with diagonals 2-3, 1-3, 2-6 but NOT 1-6.
  Two filled triangles: 1-2-3 and 2-3-6.
  The boundary cycle 1-2-6 + 6-3-1 minus the filled parts leaves a 1-cycle.

  chi = 4 - 5 + 2 = 1, so beta_0 - beta_1 = 1, with beta_0 = 1, beta_1 = 0?
  Wait: chi = V - E + F = 4 - 5 + 2 = 1. If beta_0 = 1 then beta_1 = 0.

  Actually let me recount. Euler characteristic for a simplicial complex:
  chi = f_0 - f_1 + f_2 = 4 - 5 + 2 = 1
  chi = beta_0 - beta_1 + beta_2 = 1 - beta_1 + 0
  So beta_1 = 0.

  Hmm, but there seems to be a cycle 1-3-6-2-1 that isn't filled.
  Let me check: 1-3 edge exists, 3-6 edge exists, 6-2 edge exists, 2-1 edge exists.
  Triangle 1-3-6: need d(1,6)=1.792 > 1.099, so NOT a face.
  Triangle 1-2-6: need d(1,6)=1.792 > 1.099, so NOT a face.
  So the cycle 1-2-6-3-1 exists.
  But 1-2-3 is filled and 2-3-6 is filled.
  The cycle 1-2-6-3-1 = (1-2) + (2-6) + (6-3) + (3-1).
  Can decompose: = [(1-2) + (2-3) + (3-1)] + [(2-6) + (6-3) + (3-2)]
                 = boundary(1-2-3) + boundary(2-3-6) with appropriate signs.
  So actually the cycle IS a boundary! beta_1 = 0.

  Correction: the naive "loop" is homologous to zero because the two triangles
  fill it in. So beta_1 = 0 at this stage too.

At epsilon >= 1.792: everything connected, all triangles filled, beta_0=1, beta_1=0.

### Corrected Filtration Table

```
  epsilon range          beta_0  beta_1    Events
  ──────────────────────────────────────────────────
  [0, 0.405)               4       0      4 isolated points
  [0.405, 0.693)           3       0      Merge 2-3
  [0.693, 1.099)           1       0      Merge 1 and 6 into component
  [1.099, 1.792)           1       0      Add cross-edges, triangles
  [1.792, inf)             1       0      Complete complex
```

## Persistence Barcode (H_0)

```
  H_0 Barcode:
  Component   Birth    Death     Lifetime
  ─────────────────────────────────────────
  {1}         0        0.693     0.693 = ln(2)
  {2}         0        0.405     0.405 = ln(3/2)
  {3}         0        0.405     0.405 = ln(3/2)
                                 (merges with 2 at eps=0.405)
  Wait: {2} and {3} merge at 0.405. One of them "dies", the other survives.
  Then {1} merges with {2,3} at 0.693 (via edge 1-2).
  {6} merges with {2,3} at 0.693 (via edge 3-6).
  The "essential" component (born at 0, never dies) is {1} or whichever survives.

  Using elder rule (older component survives):
  Component   Birth    Death     Lifetime
  ─────────────────────────────────────────
  {1}         0        inf       essential (survives forever)
  {2}         0        0.693     0.693 = ln(2)
  {3}         0        0.405     0.405 = ln(3/2)
  {6}         0        0.693     0.693 = ln(2)

  Wait: at eps=0.405, edge 2-3 forms. {2} born at 0, {3} born at 0.
  By elder rule with vertex labeling, say {2} survives. {3} dies at 0.405.
  At eps=0.693: edges 1-2 and 3-6 both appear.
    {1} merges with {2,3}: {1} born 0, {2} born 0 -- tie, say {1} survives.
    {6} merges with {2,3,6}: actually 3-6 connects {6} to the {2,3} component.
      {6} born 0, {2} born 0 -- tie, {2} (or {1}) survives. {6} dies at 0.693.
    And 1-2 merges {1} with {2,3}: {1} survives, {2} dies at 0.693.

  Final barcode:
  Component   Birth    Death     Lifetime
  ─────────────────────────────────────────
  {1}         0        inf       essential
  {3}         0        0.405     ln(3/2) = 0.4055
  {2}         0        0.693     ln(2)   = 0.6931
  {6}         0        0.693     ln(2)   = 0.6931
```

### ASCII Barcode Diagram

```
  H_0 Persistence Barcode for D(6) = {1, 2, 3, 6}

  eps:  0    0.2    0.4    0.6    0.8    1.0    1.2  ...
        |      |      |      |      |      |      |
  {1}   =====================================================> (essential)
  {3}   ============X                                   dies at ln(3/2)
  {2}   =====================X                          dies at ln(2)
  {6}   =====================X                          dies at ln(2)
                     ^        ^
                  ln(3/2)   ln(2)
                  =0.405    =0.693

  Finite lifetimes: ln(3/2), ln(2), ln(2)
  Sum of finite lifetimes: ln(3/2) + 2*ln(2) = ln(3/2) + ln(4) = ln(6) = 1.7918
  Average finite lifetime: ln(6)/3 = 0.5973

  Compare with (n+1)/sigma = 7/12 = 0.5833...
  Difference: 0.5973 - 0.5833 = 0.014 (2.4% error)
```

## Comparison with n=28

```
  D(28) = {1, 2, 4, 7, 14, 28}
  Log-distances: d(a,b) = |ln(a) - ln(b)|

  Sorted edges (15 total):
  Rank  Edge     Distance
  ─────────────────────────
  1     4-7      ln(7/4) = 0.560
  2     2-4      ln(2)   = 0.693
  3     14-28    ln(2)   = 0.693
  4     1-2      ln(2)   = 0.693
  5     7-14     ln(2)   = 0.693
  6     2-7      ln(7/2) = 1.253
  7     4-14     ln(7/2) = 1.253
  8     4-28     ln(7)   = 1.946
  9     1-4      ln(4)   = 1.386
  10    7-28     ln(4)   = 1.386
  ...

  More edges and triangles. 6 vertices = richer complex.

  (n+1)/sigma for n=28: 29/56 = 0.5179
  Avg finite H_0 bar lifetime for n=28: 0.6664 (28.7% error vs 0.5179)
  The (n+1)/sigma approximation degrades for larger perfect numbers.
```

## Euler Characteristic Through Filtration

```
  eps range        V    E    F    chi = V-E+F
  ────────────────────────────────────────────
  [0, 0.405)       4    0    0    4
  [0.405, 0.693)   4    1    0    3
  [0.693, 1.099)   4    3    0    1
  [1.099, 1.792)   4    5    2    1
  [1.792, inf)     4    6    4    2

  Final complex: K4 (complete graph on 4 vertices)
    V=4, E=6, F=4 (all 4 triangles), chi=2
    (No tetrahedron since we need 4-clique for that, which K4 is, but
     in VR complex on 4 points, the 3-simplex {1,2,3,6} requires all
     6 pairwise distances <= eps. At eps=1.792 all are, so we get the
     tetrahedron too: chi = 4-6+4-1 = 1.)

  Correction with tetrahedron:
  [1.792, inf)     4    6    4    1    (V-E+F-T = 4-6+4-1 = 1)
```

## Verification Results

| Quantity                     | Value          | Connection              |
|------------------------------|----------------|-------------------------|
| First edge distance          | ln(3/2)=0.4055 | Closest divisor pair    |
| Second edge distance         | ln(2)=0.6931   | Prime factor 2          |
| Sum finite H_0 lifetimes     | ln(6)=1.7918   | ln(n) exact!            |
| Avg finite H_0 lifetime      | ln(6)/3=0.5973 | Close to 7/12=0.5833   |
| Error vs (n+1)/sigma         | 2.4%           | Approximate match       |
| Max H_1 Betti number         | 0              | No persistent loops     |
| Final Euler char (with tet)  | 1              | Contractible            |

Key finding: The sum of all finite H_0 bar lifetimes equals ln(n) = ln(6) exactly.
This is a general result: for the complete filtration on n points, the sum of
finite lifetimes in H_0 equals the diameter of the point cloud, which here is
max distance = ln(6). But the decomposition into ln(3/2) + ln(2) + ln(2) = ln(6)
is specific to the divisor structure.

## Interpretation

1. **Sum of lifetimes = ln(n)**: The total "persistence" of the divisor complex
   equals the natural logarithm of n. For n=6, this is ln(6) = ln(2) + ln(3),
   decomposing into prime factor contributions.

2. **First edge = ln(3/2)**: The closest divisor pair is {2,3}, the consecutive
   primes. Their log-distance ln(3/2) is related to ln(4/3) (Golden Zone width)
   via: ln(3/2) = ln(4/3) + ln(9/8). Not a clean relationship.

3. **Average lifetime vs 7/12**: The average finite H_0 bar lifetime ln(6)/3 = 0.597
   is close to but not equal to 7/12 = 0.583. The 2.4% gap means the barcode
   hypothesis (n+1)/sigma is approximate for this construction.

4. **Diamond symmetry**: The distance matrix has a beautiful symmetry where
   d(1,k) = d(6/k, 6) for all divisors k. This is the multiplicative involution
   k -> n/k on the divisor lattice.

## Limitations

- beta_1 = 0 throughout the filtration, so no persistent loops arise.
  The divisor complex of 6 is topologically simple (contractible).
- The barcode lifetime connection to 7/12 is approximate (2.4% error),
  not exact. May not warrant a structural claim.
- With only 4 points, the complex is small. Richer structure might appear
  for n=28 (6 points) or n=496 (10 points).
- Sum of lifetimes = ln(n) = diameter is a general property of VR
  filtrations on 1D point sets, not specific to divisor structure.

## Grade

- I_total = ln(6) (sum of finite lifetimes): 🟩 exact but follows from general VR theory
- Average lifetime = 7/12: 🟧 approximate (2.4% error)
- Diamond symmetry d(1,k) = d(n/k,n): 🟩 exact, follows from log distance definition

## Next Steps

1. Compute full persistent homology for n=28 (6-point complex)
2. Check if average H_0 lifetime converges to (n+1)/sigma for larger perfect numbers
3. Explore weighted filtrations using divisor function values as weights
4. Investigate if sigma(n) appears in the persistence diagram directly
5. Try cubical homology on the divisor lattice viewed as a cube complex
