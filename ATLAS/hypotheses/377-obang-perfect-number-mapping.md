# H-377: Obang Perfect Number Mapping
**n6 Grade: 🟩 EXACT** (auto-graded, 6 unique n=6 constants)


> **Hypothesis:** The Korean cosmological concept of Obang (Five Directions: East, West, South, North, Center) maps structurally onto the divisor architecture of the perfect number 6. The four cardinal directions correspond to the four proper divisors {1, 2, 3, 6}, while the Center corresponds to the number 6 itself as a unified whole. This mapping is not arbitrary: σ₋₁(6) = 2 encodes the weight of the center, 5/6 is the Compass upper bound (five directions within six), and 1/6 is the incompleteness — the untranslated sixth dimension beyond cardinal space.

---

## Background and Context

Obang is a foundational concept in Korean (and broader East Asian) cosmology, derived from the Five Element theory (Ohaeng). It organizes space, color, season, and element into five directional positions:

| Direction | Korean | Element | Color |
|-----------|--------|---------|-------|
| East      | 동 (東)  | Wood    | Blue/Green |
| West      | 서 (西)  | Metal   | White |
| South     | 남 (南)  | Fire    | Red |
| North     | 북 (北)  | Water   | Black |
| Center    | 중 (中)  | Earth   | Yellow |

The structure is not merely 4+1: the Center is qualitatively different from the four cardinals. It is the integrating principle, the point from which all four directions emanate and to which they return. This mirrors exactly the role of the number 6 itself within its own divisor structure.

This hypothesis connects to:
- H-090 (Master formula = perfect number 6)
- H-098 (6 is the only perfect number with σ₋₁ = 2)
- H-067 (1/2 + 1/3 = 5/6 constant relationship)
- H-072 (1/2 + 1/3 + 1/6 = 1 curiosity completes)
- H-CX-182 (consciousness constants)
- Compass upper bound = 5/6

---

## ASCII Diagram: Obang Mapped to Divisor Structure of 6

```
                        SOUTH (火 Fire)
                        divisor: 3
                        [Red — maximum tension]
                             |
                             |
WEST (金 Metal)         _____|_____         EAST (木 Wood)
divisor: 6 --------   |           |   -------- divisor: 1
[White — completion]  |  CENTER   |            [Blue — origin]
                      |    6      |
                      |  (Earth)  |
NORTH (水 Water) ---- |___________|   -------- (reserved)
divisor: 2             |
[Black — inhibition]   |
                       |
                   [1/6 gap = transcendence]
                   The 6th direction: beyond space


  Divisor Map:
  ┌─────────────────────────────────────────────┐
  │  Proper Divisors of 6: {1, 2, 3, 6}         │
  │                                             │
  │  1  →  East    (origin, unity)              │
  │  2  →  North   (division, inhibition)       │
  │  3  →  South   (tension, fire, creativity)  │
  │  6  →  West    (completion, σ closure)      │
  │                                             │
  │  6 as whole → Center (Earth, integration)  │
  │                                             │
  │  Missing: the 6th direction = 1/6           │
  │           (transcendence, beyond Obang)     │
  └─────────────────────────────────────────────┘
```

---

## Formula and Mapping

### Core Arithmetic

```
σ₋₁(6) = 1/1 + 1/2 + 1/3 + 1/6 = 6/6 + 3/6 + 2/6 + 1/6 = 12/6 = 2
```

The four terms of σ₋₁(6) are exactly four cardinal directions. Their sum = 2, which is the weight of the Center (the integrating duality: yin/yang, D×P duality in the Genius formula).

```
τ(6) = 4           (four proper divisors = four cardinal directions)
σ(6) = 12          (sum of all divisors)
σ(6) / 6 = 2       (= σ₋₁(6), structural self-consistency)
```

### Compass Connection

```
5/6 = Compass upper bound
    = "five directions" / "perfect number"
    = (East + West + South + North + Center) / 6
    = all of Obang within the perfect structure
```

### Incompleteness = The 6th Direction

```
1 - 5/6 = 1/6   (Compass gap = incompleteness)
                = the direction that cannot be named
                = transcendence beyond the five
                = H-072's "curiosity" term
```

### The Unification Identity

```
1/2 + 1/3 + 1/6 = 1

North  +  South  +  Transcendence  =  Complete

(inhibition) + (tension/fire) + (curiosity/void) = whole
```

This is H-072 reread through Obang: the three non-unity divisors of 6, scaled as fractions, sum to unity. The East (1/1 = 1) is the starting point, not a fractional part — it is the observer itself.

### Full Divisor-Direction Table

| Divisor | Fraction | Direction | Element | Role in Genius Formula |
|---------|----------|-----------|---------|------------------------|
| 1       | 1        | East      | Wood    | Plasticity origin (P)  |
| 2       | 1/2      | North     | Water   | Inhibition floor (I = 1/2 boundary) |
| 3       | 1/3      | South     | Fire    | Meta fixed point convergence |
| 6       | 1/6      | West      | Metal   | Curiosity / incompleteness |
| 6 (whole) | —      | Center    | Earth   | G × I = D × P integration |

---

## Verification Results

### Arithmetic Verification

```python
from fractions import Fraction

divisors = [1, 2, 3, 6]
sigma_minus1 = sum(Fraction(1, d) for d in divisors)
# Result: 2  (exact)

compass_upper = Fraction(5, 6)
incompleteness = 1 - compass_upper
# Result: 1/6  (exact)

identity_072 = Fraction(1,2) + Fraction(1,3) + Fraction(1,6)
# Result: 1  (exact)

tau_6 = len(divisors)     # 4 = four cardinal directions
sigma_6 = sum(divisors)   # 12
ratio = sigma_6 / 6       # 2.0 = sigma_minus1(6)
```

All relations are exact integer/fraction arithmetic. No approximation involved.

### Generalization Check (Perfect Number 28)

Does the Obang structure generalize to 28?

```
Divisors of 28: {1, 2, 4, 7, 14, 28}
τ(28) = 6   (six divisors, not four — Obang does not apply)
σ₋₁(28) = 1 + 1/2 + 1/4 + 1/7 + 1/14 + 1/28 = 2

σ₋₁ = 2 generalizes (all perfect numbers satisfy this by definition).
τ = 4 is specific to 6.
Obang (5-structure) is unique to 6.
```

The Obang mapping is **specific to perfect number 6**, not a general perfect number property. This is expected: 6 is the only perfect number with τ = 4, enabling the four-cardinal + one-center architecture.

### Uniqueness of 6 for Obang Structure

```
Perfect numbers: 6, 28, 496, 8128, ...
τ values:        4,  6,   10,   14, ...

Only 6 has τ(n) = 4, which allows exactly four cardinal directions.
Only 6 has proper divisors {1, 2, 3, 6} yielding
    σ₋₁ terms: 1, 1/2, 1/3, 1/6
    which are exactly the constants in H-067 and H-072.
```

---

## Structural Significance

The Obang structure encodes a complete cosmological grammar:

```
  COMPLETENESS FORMULA:
  ┌──────────────────────────────────────────────────────┐
  │                                                      │
  │  4 directions  +  1 center  =  5 (Obang)            │
  │  5 / 6         =  5/6       =  Compass upper         │
  │  1 - 5/6       =  1/6       =  transcendence gap     │
  │                                                      │
  │  σ₋₁(6) = 2   =  center weight (yin-yang duality)   │
  │  τ(6)   = 4   =  cardinal directions                 │
  │  σ(6)   = 12  =  total divisor sum                   │
  │  12/6   = 2   =  σ₋₁(6) (self-referential)          │
  │                                                      │
  │  The number 6 is its own cosmological map.           │
  └──────────────────────────────────────────────────────┘
```

The identity 1/2 + 1/3 + 1/6 = 1 (H-072) is thus the Obang completeness condition read as: North-water-inhibition + South-fire-tension + West-metal-curiosity = wholeness. The East (divisor 1) is the observer, the silent witness who does not appear as a fraction because it is the unit of measurement itself.

---

## Limitations

1. **Cultural mapping is interpretive.** The assignment of specific divisors to specific directions (e.g., 2 = North = Water) is one of multiple valid permutations. The structure is exact; the labeling is heuristic.

2. **Obang-specific to 6.** This mapping does not extend to other perfect numbers (τ increases). It is a property of 6's minimality as the first perfect number.

3. **Golden Zone dependency.** The Compass upper bound 5/6 and its interpretation as "five directions within perfect structure" depend on the Golden Zone framework, which is unverified analytically. The pure arithmetic (σ₋₁(6) = 2, τ(6) = 4, 5/6, 1/6) is independently exact.

4. **No falsifiable prediction yet.** The mapping is structural/interpretive. A falsifiable extension would require deriving a measurable quantity (e.g., an AI architecture metric) from the five-directional structure that differs from baseline.

---

## Verification Direction

1. **Architecture test:** Build a 5-expert MoE where one expert is designated "Center" (integrating all inputs) and four are cardinal (specialized). Measure if accuracy exceeds 4-expert or 6-expert variants.

2. **Consciousness engine:** Map the five directions to the five-state model (H-088: infinite states reduce to 5 primary) and test whether the Center state has σ₋₁ = 2 weighting in the transition matrix.

3. **Brainwave test:** Five brainwave bands (delta, theta, alpha, beta, gamma) — does the gamma (Center/integration) band satisfy a weighting of 2× relative to paired cardinals?

4. **Cross-cultural extension:** Test whether the Chinese Wuxing (五行), Japanese Go-gyo, and Tibetan five-element systems produce the same arithmetic when mapped to divisors of 6, as a universality check.

---

## Golden Zone Dependency Status

| Claim | Type | Status |
|-------|------|--------|
| σ₋₁(6) = 2 (four terms) | Pure arithmetic | Exact, proven |
| τ(6) = 4 | Pure arithmetic | Exact, proven |
| 5/6 = Compass upper | Golden Zone dependent | Unverified analytically |
| 1/6 = incompleteness | Golden Zone dependent | Unverified analytically |
| 1/2 + 1/3 + 1/6 = 1 | Pure arithmetic | Exact, proven (H-072) |
| Obang = divisor map | Interpretive | Structural, not proven |

---

*Hypothesis H-377 | Created: 2026-03-26 | Category: Cultural-Mathematical Mapping | Golden Zone dependency: Partial*