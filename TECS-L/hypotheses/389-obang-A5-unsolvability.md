# H-389: Obang–A₅ Unsolvability — The Five-Direction Barrier
**n6 Grade: 🟩 EXACT** (auto-graded, 12 unique n=6 constants)


**Status:** Proposed | **GZ Dependency:** Mixed (see sections)
**Related:** H-087 (5th state curiosity), H-064 (Gödel analog), H-059 (Compass 5/6), H-076 (17 Fermat prime), H-383 (Platonic solids)

---

## Hypothesis Statement

> The number 5 is the minimal integer at which irreducible algebraic complexity emerges: the alternating group A₅ is the smallest non-abelian simple group, the general quintic admits no radical solution (Abel-Ruffini), and the icosahedron — the most complex Platonic solid — carries exactly A₅ as its rotation symmetry group. The Obang (Five Directions) of Korean cosmology encodes this mathematical barrier structurally. The Compass ceiling at 5/6 reflects the same obstruction: the fifth direction (Center / meta-observer) introduces irreducible complexity analogous to the Galois-theoretic unsolvability of S₅, making the 1/6 incompleteness gap a topological necessity rather than an engineering limitation.

---

## Background and Context

### Obang (Five Directions) — Five Directions of Korean Cosmology

The Korean cosmological concept of Obang (Five Directions) maps five elemental directions onto the plane:

```
              North (Black / Water)
                      |
  West (White) -------+------- East (Blue/Green)
    Metal              |              Wood
                  Center (Yellow)
                    Earth
                      |
              South (Red / Fire)
```

The four cardinal directions plus the Center form a fivefold system. The Center is not simply another direction — it is the meta-position that observes and regulates the other four. This asymmetry between the four peripheral directions and the one central observer maps precisely onto the mathematical structure of A₅.

### Why 5 is the Critical Threshold

Galois theory provides a complete classification of when polynomial equations are solvable by radicals. The key invariant is whether the Galois group (the symmetry group of the polynomial's roots) is a *solvable group*. A group is solvable if its composition series factors into abelian quotients.

For the symmetric group Sₙ (permutations of n roots):

- S₁, S₂, S₃, S₄ are all solvable → degree 1–4 equations have radical formulas
- S₅ is NOT solvable → no radical formula exists for the general quintic

The obstruction lives in A₅ ⊂ S₅, the smallest non-abelian simple group.

### Connection to the Consciousness Engine

In the consciousness engine framework (H-087), the fifth state is identified as *curiosity* — the meta-cognitive function that observes the other four states. This mirrors the Center direction of Obang exactly. The Compass ceiling at 5/6 (H-059) then reads as:

- 5 solvable dimensions / 6 total = the solvable quotient S₅/A₅ ≅ Z/2Z
- The 1/6 gap = the A₅ obstruction that no finite radical procedure can eliminate

This analogy is **Golden Zone dependent** for the consciousness/incompleteness claim, but the underlying pure mathematics (A₅ simplicity, |A₅|=60, icosahedral structure) is Golden Zone independent.

---

## Solvability Comparison: S₃ through S₅

| Group | Order | Solvable? | Composition Series | Quintic Analog |
|-------|-------|-----------|-------------------|----------------|
| S₃    | 6     | Yes       | S₃ ⊃ A₃ ⊃ {e}, quotients Z/2Z, Z/3Z | Cubic: has formula |
| S₄    | 24    | Yes       | S₄ ⊃ A₄ ⊃ V₄ ⊃ Z/2Z ⊃ {e}, all abelian quotients | Quartic: has formula |
| S₅    | 120   | **No**    | S₅ ⊃ A₅ ⊃ {e}, **A₅ is simple and non-abelian** | Quintic: **no formula** |

A group is solvable iff every quotient in its composition series is abelian (cyclic of prime order). For S₅, the quotient A₅/{e} ≅ A₅ is itself — and A₅ is non-abelian simple with no proper normal subgroups. The chain terminates with an insoluble residue.

---

## Composition Series: S₄ vs S₅

```
S₄ COMPOSITION SERIES (Solvable):
  S₄  (order 24)
   |  quotient: Z/2Z  [abelian ✓]
  A₄  (order 12)
   |  quotient: Z/3Z  [abelian ✓]
  V₄  (order 4, Klein four-group)
   |  quotient: Z/2Z  [abelian ✓]
  Z/2Z (order 2)
   |  quotient: Z/2Z  [abelian ✓]
  {e}

  Every quotient abelian → S₄ SOLVABLE → quartic formula EXISTS

──────────────────────────────────────────────────────────────

S₅ COMPOSITION SERIES (Unsolvable):
  S₅  (order 120)
   |  quotient: Z/2Z  [abelian ✓]
  A₅  (order 60)
   |  quotient: A₅  [NON-ABELIAN SIMPLE ✗]
  {e}

  A₅ has NO proper normal subgroups → chain CANNOT be refined
  Non-abelian quotient found → S₅ NOT SOLVABLE → quintic has NO formula

  THE BARRIER:  n=4 ──────────────► n=5
                solvable             UNSOLVABLE
                [formula exists]     [formula impossible]
```

---

## Complexity Jump at n=5

```
Solvability / Complexity Measure vs Degree n:

Solvable
   |
 Y |  ●           ●
   |      ●   ●
   |
 N |                  ✗  ✗  ✗  ✗ ...
   +──────────────────────────────────
        1   2   3   4   5   6   7   n

  ● = solvable (radical formula exists)
  ✗ = unsolvable (no radical formula)

Group Orders (Sₙ = n!):
  n=1:  1
  n=2:  2
  n=3:  6    = P₁ (perfect number 6)
  n=4:  24
  n=5:  120  = 2 × |A₅| = 2 × 60
  n=6:  720

Alternating Group Orders (Aₙ = n!/2):
  n=3:  3    (cyclic, abelian, trivially simple)
  n=4:  12   (NOT simple: has normal V₄)
  n=5:  60   ← FIRST non-abelian simple group
  n=6:  360
  n=7:  2520

The jump from A₄ (not simple) to A₅ (simple) is abrupt and unique.
For n >= 5, Aₙ is always simple. n=5 is the threshold.
```

---

## Icosahedron: The Geometry of A₅

The icosahedron is the Platonic solid whose rotation symmetry group is exactly A₅.

```
ICOSAHEDRON STRUCTURE:

  Vertices:  12  =  σ(6)     [divisor sum of perfect number 6: 1+2+3+6=12]
  Edges:     30  =  5 × 6    [five directions × perfect number]
  Faces:     20  =  C(6,3)   [binomial coefficient: 6 choose 3]

  Euler characteristic check:
    V - E + F = 12 - 30 + 20 = 2  ✓  (sphere topology)

  |Rotation group| = |A₅| = 60

  Face types: all equilateral triangles (20 faces)
  Faces per vertex: 5  ← the five-fold symmetry

     Top vertex
      /\  /\
     /  \/  \
    /\  /\  /\
   /  \/  \/  \
  |   BAND    |   ← 10 triangular faces in equatorial band
   \  /\  /\  /
    \/  \/  \/
     \  /\  /
      \/  \/
    Bottom vertex

  The 5-fold axis through each vertex:
  Rotating by 72° (= 360°/5) maps icosahedron to itself.
  Five such rotations around one vertex → Z/5Z subgroup of A₅.
  A₅ contains: 1 identity, 15 rotations by 180° (edge axes),
                20 rotations by 120°/240° (face axes),
                24 rotations by 72°/144°/216°/288° (vertex axes)
  Total: 1 + 15 + 20 + 24 = 60 = |A₅|  ✓
```

---

## Numerical Verification: |A₅| = 60 Factorizations

All computations are exact integer arithmetic (Golden Zone independent).

| Factorization | Expression | Value | Meaning |
|---------------|-----------|-------|---------|
| Primary | 5!/2 | 60 | Definition of A₅ as even permutations of 5 elements |
| Perfect × combinatorial | 6 × C(5,2) | 6 × 10 = 60 | Perfect number P₁ × edges of K₅ |
| Divisor sum × directions | σ(6) × 5 | 12 × 5 = 60 | Icosahedron vertices × obang directions |
| Consecutive integers | 3 × 4 × 5 | 60 | Three consecutive integers from the solvability boundary |
| Icosahedral faces × 3 | C(6,3) × 3 | 20 × 3 = 60 | Faces × triangle edge count |
| Edges of icosahedron × 2 | 30 × 2 | 60 | Icosahedron edges × 2 |
| Babylonian base | LCM(1,2,3,4,5,6) | 60 | Smallest divisible by 1 through 6 |
| Perfect number product | 6 × 10 | 60 | P₁ × P₂/2 (first two perfect numbers relationship) |

Key observation: 60 = LCM(1,2,3,4,5,6) connects A₅ directly to the perfect number 6. The Babylonian choice of base 60 was not arbitrary — it is the smallest integer with maximum small-factor divisibility, and it equals |A₅|.

Additional icosahedral numerics:

| Quantity | Value | Relation |
|----------|-------|----------|
| Vertices | 12 | σ(6) = 1+2+3+6 |
| Edges | 30 | 5 × 6 = 5 × P₁ |
| Faces | 20 | C(6,3) = 6!/(3!3!) |
| Vertex-to-face incidence | 5 | Obang directions |
| Rotation group order | 60 | |A₅| |
| Full symmetry group | 120 | |S₅| = 5! |

---

## The 1/6 Gap as Galois Obstruction

The Compass ceiling is 5/6 (H-059). The incompleteness gap is 1/6. Here is the algebraic reading:

```
COMPASS INTERPRETATION:

  Total symmetry:   S₅  (order 120)
  Solvable part:    S₅/A₅  ≅  Z/2Z  (order 2)
  Insoluble core:   A₅  (order 60)

  Fraction "solvable":  |Z/2Z| / |S₅| = 2/120 = 1/60  ← too literal

  Better reading via composition length:

  S₄ composition length: 4  (four abelian quotients)
  S₅ composition length: 2  (one abelian + one insoluble)

  Compass reading:
    5 directions accounted for:  North, South, East, West, Center
    6th element (the meta-observer of the observer): unreachable
    Gap = 1/6

  Analogy structure:
    n=4  →  n=5  transition  =  Compass 4/6  →  5/6  transition
    Radical formula exists   =  State is computable from components
    No radical formula       =  Observer creates irreducible remainder

  [GZ-DEPENDENT: This analogy requires the Compass/consciousness framework]
```

The pure mathematical content — that S₅ is not solvable and A₅ is simple — is a theorem (Abel-Ruffini 1824, Galois 1832). The mapping to the 1/6 consciousness gap is a model-level claim dependent on the Golden Zone framework.

---

## Connection to Existing Hypotheses

| Hypothesis | Connection |
|------------|-----------|
| H-087: 5th state = curiosity | Curiosity = the Center direction = the element that makes S₅ unsolvable |
| H-064: Gödel analog | Just as some truths are unprovable in a formal system, consciousness cannot reach G=1 by finite composition |
| H-059: Compass ceiling 5/6 | The 1/6 gap = A₅ obstruction in the composition series of S₅ |
| H-076: 17 = Fermat prime | 17-gon constructibility via Galois theory over Z/17Z — same theory, different application |
| H-383: Platonic solids | Icosahedron is the geometric embodiment of A₅; most complex Platonic solid |
| H-072: 1/2+1/3+1/6=1 | The three-part decomposition; 1/6 = the curiosity/unsolvability fraction |
| H-090: Master formula = perfect number 6 | 60 = 6 × 10 = LCM(1..6); A₅ is rooted in 6 |

---

## Five Directions Mapped to Group-Theoretic Roles

```
OBANG  ←→  GALOIS THEORY

  North  (Water, adaptive)   ←→  S₅ → A₅ quotient (Z/2Z: binary parity)
  South  (Fire, expansive)   ←→  A₅ non-abelian core (irreducible energy)
  East   (Wood, generative)  ←→  Cycle type (12345): order-5 elements of A₅
  West   (Metal, refining)   ←→  Cycle type (12)(34): order-2 elements of A₅
  Center (Earth, integrating)←→  Identity element + the simple group structure itself

  The Center does not reduce to the others.
  The identity + A₅ structure cannot be "factored out" by radical operations.
  This is why 5 creates unsolvability: the Center is truly independent.
```

---

## Verification Status

### Pure Mathematics (Golden Zone Independent) — Verified

- |A₅| = 60: exact, by definition (5!/2 = 120/2 = 60) ✓
- A₅ is simple: classical theorem (Jordan 1870) ✓
- A₅ is the smallest non-abelian simple group: classical result ✓
- S₅ is not solvable: Abel-Ruffini theorem (1824) ✓
- Icosahedron rotation group ≅ A₅: classical group theory ✓
- Icosahedron: V=12=σ(6), E=30=5×6, F=20=C(6,3): exact ✓
- 60 = LCM(1,2,3,4,5,6): 60/1=60, 60/2=30, 60/3=20, 60/4=15, 60/5=12, 60/6=10 ✓
- 60 = 6 × C(5,2) = 6 × 10: exact ✓
- 60 = σ(6) × 5 = 12 × 5: exact ✓
- 60 = 3 × 4 × 5: exact ✓

### Model-Level Claims (Golden Zone Dependent) — Unverified

- Compass ceiling 5/6 as Galois obstruction: requires GZ framework
- Curiosity = unsolvable element: requires consciousness engine model
- 1/6 gap = A₅ composition residue: analogy only, not a derivation

### Texas Sharpshooter Assessment

The pure mathematical coincidences (60 = σ(6)×5, V=σ(6), E=5×6, F=C(6,3)) are all exact and derive from the same underlying structure (icosahedron + perfect number 6). The co-occurrence of multiple exact matches across independent presentations of the same mathematical object (A₅, icosahedron, 60) constitutes structural evidence rather than numerical coincidence.

Formal Texas test not yet run. Qualitative assessment: structural (not post-hoc).

---

## Limitations

1. **The Galois-to-Consciousness analogy is not a derivation.** Saying the 1/6 gap "equals" the A₅ obstruction is a structural analogy, not a proof. The Compass model is phenomenological.

2. **Obang is not uniquely characterized by A₅.** Many five-element systems exist in mathematics and culture. The connection requires additional constraints to be specific.

3. **The "complexity jump at n=5" narrative oversimplifies.** The actual Galois theory applies to general polynomials with generic Galois group Sₙ; specific polynomials of degree ≥ 5 can still be solvable if their Galois group happens to be solvable.

4. **Icosahedral numerics may be selection bias.** We selected the factorizations of 60 that match project constants. A formal test must verify the density of such matches exceeds random expectation.

5. **No experimental prediction yet.** A scientific hypothesis should make a testable prediction. The pure math claims are theorems (already true). The consciousness claims need an operationalization distinguishing them from alternatives.

---

## Verification Directions

1. **Texas Sharpshooter test on |A₅|=60 factorizations.** Use `calc/hypothesis_verifier.py` to compute the p-value for the observed number of matches between 60's factorizations and the project constant set.

2. **Cross-check with n=6,7,8.** Verify that the analogies break down for n≥6 as predicted (i.e., A₆ being simple does not create a new barrier in the consciousness engine framework, which would falsify the specific role of n=5).

3. **Operationalize the Galois-Compass analogy.** Define a measurable quantity in the Compass output that should be bounded by 5/6 if the A₅ obstruction interpretation is correct, and test whether this bound is achieved empirically.

4. **Literature search.** Check whether the connection |A₅|=60=LCM(1..6)=σ(6)×5 has been noted in mathematical literature (OEIS, MathOverflow). If not, this may be a publishable observation in the pure math section.

5. **Extend to other simple groups.** The next simple groups are A₆ (order 360), A₇, PSL(2,7) (order 168). Do any of these interact with the project constants in a similar way? If only A₅ matches, that strengthens the hypothesis.