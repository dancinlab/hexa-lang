# H-379: Obang Pentagon Golden Ratio
**n6 Grade: 🟩 EXACT** (auto-graded, 9 unique n=6 constants)


**Status:** Proposed
**Golden Zone Dependency:** Partial (pentagon geometry is independent; Golden Zone mapping is GZ-dependent)
**Related:** H-CX-310 (Fibonacci origin), H-CX-312 (Golden Zone derivation), H-072 (completeness), H-098 (perfect 6)

---

## Hypothesis Statement

> The five-direction system (Obang) embeds the golden ratio φ = (1+√5)/2 ≈ 1.618
> as its fundamental geometric invariant. The regular pentagon's diagonal-to-side ratio
> equals φ exactly, and its angular decomposition (72°, 108°, 36°) generates a self-similar
> cascade that mirrors the Fibonacci scaling observed in consciousness engine dynamics.
> Furthermore, five-fold symmetry is the unique rotational symmetry that cannot tile the
> Euclidean plane — structurally analogous to the incompleteness term 1/6 in the
> consciousness completeness relation 1/2 + 1/3 + 1/6 = 1 (H-072).

---

## Background and Context

Obang is the classical East Asian cosmological system of five directions:
East, West, South, North, and Center. It underlies the Five Elements (Ohaeng, Wuxing)
framework connecting wood, fire, earth, metal, and water to spatial orientation.

Independent of this cultural framing, the regular pentagon is the canonical geometric
figure with exactly 5-fold symmetry. It is the only convex polygon whose diagonal-to-side
ratio is the golden ratio φ. This is not an approximation — it is an exact algebraic
identity derivable from the minimal polynomial x² - x - 1 = 0.

The golden ratio appears throughout this project:
- H-CX-310 establishes Fibonacci as the origin of Golden Zone structure
- H-CX-312 derives the Golden Zone bounds via quadratic/zeta methods
- H-CX-313 identifies φ-cubed relations in Fibonacci
- The consciousness engine's optimal inhibition I_optimal ≈ 1/e ≈ 0.368 sits inside
  the Golden Zone [0.2123, 0.5000], whose width is ln(4/3) ≈ 0.2877

The five-fold connection thus links a cultural-geometric concept to the algebraic
foundations already established in the project's mathematical core.

---

## Geometric Structure of the Regular Pentagon

### ASCII Pentagon with Golden Ratio Annotations

```
                    A
                   /|\
                  / | \
                 /  |  \
                /   |   \
               / φ  |  φ \
              /     |     \
             B------+------E
            / \   Center  / \
           /   \         /   \
          /     \       /     \
         /  1    \     /  1    \
        C----------D (side = 1)
           side=1

  Diagonal AC = BD = BE = CE = AD = φ  (when side = 1)
  Interior angle at each vertex = 108°
  Each triangle ABE, BCD, etc. = golden gnomon
  Apex angle of isoceles triangle = 36°, base angles = 72°

  Self-similar subdivision:
    Diagonal intersections create a smaller regular pentagon
    Ratio of outer to inner pentagon side = φ²

  Angular cascade:
    360° / 5 = 72°  (one Obang sector)
    108° = 3 × 36°  (interior angle)
     72° = 2 × 36°  (exterior angle)
     36° = base unit (golden angle factor)
```

### The Golden Gnomon Triangle

```
  Isoceles triangle with apex 36°, base angles 72°:

        A
       /|\
      / | \
  φ  /  |  \  φ
    /   |   \
   /36° | 36°\
  B-----+-----C
     1 (base)

  AB/BC = φ  (long leg / short leg = golden ratio)
  This triangle tiles into itself recursively via the pentagon diagonal.
```

---

## Numerical Verification

### Core Constants

| Quantity | Exact Form | Numerical Value |
|---|---|---|
| φ (golden ratio) | (1 + √5) / 2 | 1.6180339887... |
| 1/φ | φ - 1 = (√5 - 1) / 2 | 0.6180339887... |
| φ² | φ + 1 | 2.6180339887... |
| φ³ | 2φ + 1 | 4.2360679774... |
| 1/φ² | 2 - φ | 0.3819660112... |
| √5 | — | 2.2360679774... |

**Key identity:** φ² = φ + 1 (defining equation, from x² - x - 1 = 0)

**Self-referential cascade:**
```
  φ⁰ = 1.0000
  φ¹ = 1.6180   +0.6180
  φ²  = 2.6180   +1.0000
  φ³  = 4.2361   +1.6180
  φ⁴  = 6.8541   +2.6180
  φ⁵  = 11.0902  +4.2361

  Differences equal φ^(n-1): Fibonacci growth confirmed
```

### Trigonometric Identities from Pentagon

| Angle | Exact Value | Numerical |
|---|---|---|
| cos(36°) = cos(π/5) | φ/2 | 0.80901... |
| cos(72°) = cos(2π/5) | (φ-1)/2 = 1/(2φ) | 0.30902... |
| cos(108°) = cos(3π/5) | -1/(2φ) | -0.30902... |
| sin(36°) = sin(π/5) | √(10-2√5)/4 | 0.58779... |
| sin(72°) = sin(2π/5) | √(10+2√5)/4 | 0.95106... |

**Arithmetic check (cos(36°)):**
```
  φ/2 = 1.6180339887.../2 = 0.80901699...
  cos(π/5) = 0.80901699...  ✓ exact match
```

**Arithmetic check (cos(72°)):**
```
  1/(2φ) = 1/(2 × 1.6180...) = 1/3.2360... = 0.30901699...
  cos(2π/5) = 0.30901699...  ✓ exact match
```

### Obang Angular Structure

```
  Five directions partition 360°:
    360° / 5 = 72° per sector

  Pentagon angle decomposition:
    Interior angle = (5-2) × 180° / 5 = 108°
    Exterior angle = 180° - 108° = 72°
    Half-apex of golden gnomon = 36°

  Ratio chain:
    108 : 72 : 36 = 3 : 2 : 1
    Sum = 216 = 6 × 36  (factor of 6, perfect number connection)
    108 / 72 = 3/2  (musical fifth ratio)
    72 / 36 = 2     (octave ratio)
```

### Connection to Golden Zone

```
  Golden Zone: I ∈ [0.2123, 0.5000]
  Center: 1/e ≈ 0.3679

  Reciprocal relations:
    1/φ ≈ 0.6180  (above Golden Zone, outside)
    1/φ² ≈ 0.3820  (inside Golden Zone — near center 1/e ≈ 0.3679)
    1/φ³ ≈ 0.2361  (near Golden Zone lower bound 0.2123)

  Distance from 1/φ² to center:
    |0.3820 - 0.3679| = 0.0141  (within ~4% of zone width)

  NOTE: This Golden Zone mapping is GZ-dependent and unverified analytically.
```

---

## Five-Fold Symmetry and Incompleteness

The five-fold rotational symmetry group C₅ is the smallest cyclic group that **cannot**
produce a periodic tiling of the Euclidean plane. Triangles (3), squares (4), and
hexagons (6) tile perfectly. Pentagons leave gaps.

This structural incompleteness has a formal parallel in the consciousness completeness
relation H-072:

```
  1/2 + 1/3 + 1/6 = 1

  Boundary   : 1/2  (Riemann line — complete coverage)
  Convergence: 1/3  (meta fixed point — closes toward 1)
  Curiosity  : 1/6  (incompleteness term — the irreducible gap)
```

The pentagon's inability to tile represents a persistent remainder — analogous to 1/6.
The factor 6 appears in:
- 108 + 72 + 36 = 216 = 6³ = 6 × 36
- Perfect number 6 is the smallest number with σ₋₁(6) = 1/1 + 1/2 + 1/3 + 1/6 = 2
- Five is the only integer n where C_n cannot tile but C_(n+1) = C₆ can

This is a structural observation, not a proof. The connection to 1/6 is speculative.

---

## Fibonacci and Consciousness Scaling

H-CX-310 establishes that Fibonacci growth emerges from the Golden Zone's quadratic
structure. The pentagon diagonal self-similarity directly generates Fibonacci:

```
  Pentagon diagonal subdivision sequence:
    d₀ = 1 (side)
    d₁ = φ (first diagonal)
    d₂ = φ² = φ+1 (second level)
    d₃ = φ³ = 2φ+1
    ...

  Fibonacci F(n):
    F(1)=1, F(2)=1, F(3)=2, F(4)=3, F(5)=5, F(6)=8, F(7)=13...
    F(n)/F(n-1) → φ as n → ∞

  At n=5 (five directions):
    F(5)/F(4) = 5/3 ≈ 1.667  (4% above φ)
    F(6)/F(5) = 8/5 = 1.600  (1% below φ)
    φ is the attractor of this ratio sequence
```

The consciousness engine's phase acceleration (H-CX-8, H-124) shows stepwise ×3 jumps.
The Fibonacci connection suggests that five-fold geometry may encode the transition
between the n=3 and n=5 Fibonacci indices — a cross-domain conjecture only.

---

## Summary of Verified Relations

| Relation | Type | Status |
|---|---|---|
| Pentagon diagonal/side = φ | Exact geometric identity | Proven (Euclidean geometry) |
| φ² = φ + 1 | Algebraic identity | Proven (minimal polynomial) |
| cos(π/5) = φ/2 | Trigonometric identity | Proven |
| cos(2π/5) = 1/(2φ) | Trigonometric identity | Proven |
| 360°/5 = 72° (Obang sector) | Arithmetic | Exact |
| 108°+72°+36° = 216° = 6³ | Arithmetic observation | Exact (weak significance) |
| 1/φ² ≈ center of Golden Zone | GZ mapping | GZ-dependent, unverified |
| Pentagon ↔ incompleteness 1/6 | Structural analogy | Speculative |
| Five-fold → Fibonacci scaling | Cross-domain conjecture | Unverified |

---

## Limitations

1. **Golden Zone mapping is unverified.** The observation that 1/φ² ≈ 0.382 lies near
   the Golden Zone center 1/e ≈ 0.368 is numerically suggestive but lacks analytical
   derivation. The Golden Zone formula G = D×P/I is itself an unverified model.

2. **The 216 = 6³ observation is weak.** The sum 108+72+36 = 216 = 6³ involves the
   Strong Law of Small Numbers. Multiple decompositions of 360 produce multiples of 6.
   Texas Sharpshooter p-value not yet computed for this specific match.

3. **Pentagon ↔ 1/6 incompleteness analogy is structural, not algebraic.** No formula
   connects C₅ non-tileability directly to the 1/6 term in H-072.

4. **Obang as cultural framing adds no mathematical content.** The five-direction system
   is a historical/cultural organizing principle. The mathematical content resides entirely
   in the regular pentagon. The cultural connection is motivational, not evidential.

5. **Fibonacci connection to consciousness scaling is unverified.** H-CX-310 establishes
   the Fibonacci-Golden Zone link, but the bridge to five-fold Obang geometry is
   speculative and requires explicit experimental verification.

---

## Verification Directions

1. **Texas Sharpshooter test** on the 216 = 6³ match: enumerate all angle sums
   derivable from regular polygons and test whether 6³ matches are frequent by chance.

2. **Algebraic derivation:** Attempt to show 1/φ² falls within [1/2 - ln(4/3), 1/2]
   from first principles, without invoking the unverified G = D×P/I model.

3. **Tiling incompleteness quantification:** Define a "tiling gap ratio" for C_n symmetries
   and test whether n=5 produces a gap ratio proportional to 1/6.

4. **Cross-domain experiment:** Run consciousness engine (compass.py) with 5-expert Golden
   MoE configuration and measure whether inhibition converges to I ≈ 1/φ² ≈ 0.382
   rather than the standard 1/e ≈ 0.368.

5. **Fibonacci scaling test:** Verify whether F(5)/F(4) = 5/3 serves as a better
   approximation to phase transition thresholds than φ in the empirical data from H-124.