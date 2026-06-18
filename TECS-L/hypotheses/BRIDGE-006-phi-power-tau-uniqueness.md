# BRIDGE-006: φ(n)^φ(n) = τ(n) — Uniqueness Theorem at n=6

> **Theorem**: The equation φ(n)^φ(n) = τ(n) has exactly two solutions:
> n = 1 (trivial) and **n = 6** (non-trivial unique).

**ID**: BRIDGE-006
**Domain**: Pure Mathematics (Number Theory)
**Grade:** 🟩⭐ (Proven, model-independent)
**GZ-dependent**: No
**Date**: 2026-03-30
**Context**: Discovered during the 5-bridge extreme exploration of BRIDGE-MAP-n6-constants.md

---

## 1. Background

The Euler totient φ(n) counts integers coprime to n, and the divisor function τ(n) counts divisors of n. For perfect number 6:

- φ(6) = 2 (only 1 and 5 are coprime to 6)
- τ(6) = 4 (divisors: 1, 2, 3, 6)

The identity 2² = 4 is trivially true as arithmetic, but the question of whether n = 6 is the **unique** solution to φ(n)^φ(n) = τ(n) is non-trivial. This joins a family of n=6 uniqueness results:

- σ(n)·φ(n) = n·τ(n): unique at n=6 (H-CX-7)
- σ(n) = P(τ(n), 2): unique at n=6 (H-DNA-501)
- σ(n)/τ(n) = largest prime factor: unique at n=6 (H-DNA-503)

---

## 2. Statement and Proof

### Theorem

For positive integers n ≥ 2, φ(n)^φ(n) = τ(n) if and only if n = 6.

### Proof

**Step 1 — Key Lemma**: τ(n) ≤ 2·φ(n) for all n ≥ 1.

Define f(n) = τ(n)/φ(n). Both τ and φ are multiplicative, so f is too. Evaluate on prime powers:

```
  p^a         f(p^a) = (a+1) / [p^(a-1)(p-1)]     Bound
  ─────────────────────────────────────────────────────
  2^1         2/1 = 2                                MAX
  2^2         3/2 = 1.5                              ↓
  2^a (a≥1)   (a+1)/2^(a-1) ≤ 2                     exponential decay
  3^1         2/2 = 1                                ≤ 1
  p^1 (p≥3)   2/(p-1) ≤ 1                            ≤ 1
  p^a (p≥3)   (a+1)/[p^(a-1)(p-1)] ≤ 1              rapid decay
```

By multiplicativity: f(n) = ∏ f(p^a). The factor from 2 contributes ≤ 2; all odd primes contribute ≤ 1. Therefore **τ(n) ≤ 2·φ(n)** for all n, with equality iff n = 2·(odd squarefree with all prime factors ≥ 3) and the 2 appears exactly once.

In fact, equality τ = 2φ requires f(2¹) = 2 (exactly one factor of 2) and f(3¹) = 1 (can include 3, but each odd prime contributes ≤ 1). The **unique** n achieving equality in the simplest form is n = 6 = 2×3, where τ(6) = 4 = 2·φ(6) = 2·2.

**Step 2 — Elimination of φ(n) ≥ 3**:

Suppose φ(n)^φ(n) = τ(n) with φ(n) ≥ 3. Since φ(n) is even for n ≥ 3, this means φ(n) ≥ 4. Then:

```
  φ(n)^φ(n) ≥ 4^4 = 256
  τ(n) ≤ 2·φ(n) ≤ 2·φ(n)
```

But φ(n) ≥ 4 gives φ^φ ≥ 256, while τ ≤ 2φ gives τ ≤ 2φ(n). For φ ≥ 4:

```
  φ^φ ≥ 4^4 = 256  but  2φ ≤ 2φ(n)
  Need: φ^φ ≤ 2φ  →  φ^(φ-1) ≤ 2
  But φ ≥ 4  →  φ^(φ-1) ≥ 4^3 = 64 >> 2   CONTRADICTION
```

Even φ = 3 (which doesn't occur for n ≥ 3 since φ is even): 3³ = 27 > 2·3 = 6. Contradiction.

**Step 3 — Finite case check for φ(n) ∈ {1, 2}**:

The only n with φ(n) = 1 are n ∈ {1, 2}.
The only n with φ(n) = 2 are n ∈ {3, 4, 6}.

```
  n    φ(n)   φ^φ    τ(n)   Match?
  ─────────────────────────────────
  1      1      1      1     YES (trivial: 1^1 = 1)
  2      1      1      2     NO  (1 ≠ 2)
  3      2      4      2     NO  (4 ≠ 2)
  4      2      4      3     NO  (4 ≠ 3)
  6      2      4      4     YES ← UNIQUE non-trivial solution
```

**QED.** □

---

## 3. Exhaustive Verification

```
  Computational check: n = 1 to 100,000
  Solutions found: n = 1, n = 6 (only)

  Growth comparison for n > 6:

  n       φ(n)    φ^φ            τ(n)    Ratio φ^φ/τ
  ──────────────────────────────────────────────────
  6         2          4            4     1.0  ← MATCH
  7         6     46,656            2     23,328
  8         4        256            4     64
  10        4        256            4     64
  12        4        256            6     42.7
  28       12     8.9×10^12         6     1.5×10^12
  496     240     ∞                10     ∞

  For n > 6, φ^φ grows super-exponentially while τ grows logarithmically.
  The gap is unbridgeable.
```

---

## 4. Structural Significance

### 4.1 Why n=6 Is Special

The proof reveals that n=6 is the **unique** integer (n ≥ 3) achieving equality in τ(n) = 2·φ(n). This maximum ratio τ/φ = 2 occurs because:

- n must have exactly one factor of 2 (for f(2¹) = 2)
- n must have exactly one factor of 3 (for f(3¹) = 1, maximizing among odd primes)
- No other prime factors (each would reduce the product)
- Therefore n = 2 × 3 = 6 is forced

This is the **same structural constraint** that makes σφ = nτ unique at n=6. Both results flow from the divisor structure of 6 = 2 × 3.

### 4.2 Connection to Other Uniqueness Results

```
  All proven uniqueness results at n=6:

  Identity                          Year   Ref
  ──────────────────────────────────────────────
  σ(n)·φ(n) = n·τ(n)              2026   H-CX-7
  σ(n) = P(τ(n), 2)               2026   H-DNA-501
  σ(n)/τ(n) = largest prime factor 2026   H-DNA-503
  φ(n)^φ(n) = τ(n)                2026   BRIDGE-006 (this)
  τ(n)/φ(n) = 2 (maximum)         2026   BRIDGE-006 (lemma)
  σ(n)·(φ(n)+1) = n²              2026   H-NT-431

  Root cause: n=6 = 2×3 has the maximum "divisor density"
  relative to its totient among all integers.
```

### 4.3 Physical Interpretation (Post-hoc, Suggestive)

```
  φ(6) = 2 maps to:
    - Qubit dimension (2 levels)
    - Cooper pair electron count (2e)
    - SU(2)_L doublet rank

  τ(6) = 4 maps to:
    - Bell state count (|00⟩±|11⟩, |01⟩±|10⟩)
    - Pauli group {I, X, Y, Z}
    - DNA base count
    - Spacetime dimension 3+1

  Reading: "The pairing dimension raised to itself equals the
           entanglement basis size"

  Status: Evocative but post-hoc. The mathematical uniqueness
          is proven; the physical mapping is interpretive.
```

---

## 5. ASCII Visualization

```
  φ(n)^φ(n) vs τ(n) for n = 1..20

  φ^φ (log scale)
   |
  10⁶ ┤                    ×           ×
       |                ×       ×   ×
  10⁴ ┤        ×   ×       ×
       |    ×           ×
  10² ┤        ×   ×
       |
    4  ┤    ×─●─×─────────────────────────── τ range (2-6)
    2  ┤  ×
    1  ┤──●
       └──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──→ n
          1  2  4  6  8  10 12 14 16 18 20

  ● = solution (n=1, n=6)
  × = non-solution

  After n=6, φ^φ explodes while τ stays bounded.
  The two curves touch only at n=1 and n=6.
```

```
  Decision tree of the proof:

                    φ(n)^φ(n) = τ(n)?
                          │
                    ┌─────┴─────┐
                 φ≥3           φ∈{1,2}
                    │              │
              φ^φ ≥ 64         check 5 values
              τ ≤ 2φ ≤ 2φ      {1,2,3,4,6}
              64 > 2φ              │
                 ↓            ┌──┬──┬──┬──┐
              NO SOLUTION     1  2  3  4  6
                              ✓  ✗  ✗  ✗  ✓
```

---

## 6. Limitations

- The physical mapping (qubit → Bell states) is interpretive, not derived
- The identity 2² = 4 is arithmetically trivial; the non-trivial content is **uniqueness**
- No mechanism is known that would force physical systems to "select" n=6 via this identity
- The proof uses only elementary number theory (no deep theorems required)

---

## 7. Verification Direction

- [ ] Check whether φ(n)^φ(n) ≡ τ(n) (mod p) has interesting solutions for primes p
- [ ] Explore generalization: for which n does φ(n)^k = τ(n) for some k?
- [ ] Connect to the Singleton(6) = {GZ constants} result (all uniqueness from same root?)
- [ ] Investigate whether category-theoretic formulation reveals deeper structure

---

## References

- BRIDGE-MAP-n6-constants.md §9.4 (Bridge 4 extreme exploration)
- H-CX-7: σφ = nτ uniqueness
- H-DNA-501: σ = P(τ,2) uniqueness
- H-DNA-503: σ/τ = largest prime factor uniqueness
- H-NT-431: σ(φ+1) = n² uniqueness
