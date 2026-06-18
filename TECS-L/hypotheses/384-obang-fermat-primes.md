# H-384: Obang–Fermat Prime Correspondence
**n6 Grade: 🟧 CLOSE** (auto-graded, 4 unique n=6 constants)


**Status:** Structural Observation (unverified as causal)
**Category:** Number Theory × Cultural Structure
**Date:** 2026-03-26
**Related:** H-076 (17 as amplification constant), H-214 (core primes), H-067 (1/2+1/3=5/6)

---

## Hypothesis Statement

> The five known Fermat primes (F₀=3, F₁=5, F₂=17, F₃=257, F₄=65537) map
> bijectively onto the five directions of Obang (Five Directions: Center,
> East, South, West, North), where each direction's role — foundation, count,
> amplification, extension, boundary — is reflected in the mathematical character
> of its assigned Fermat prime. The fact that exactly five Fermat primes are known
> (and conjectured to be all that exist) provides a structural parallel to the
> incompleteness term 1/6 in the core constant system.

---

## Background and Context

### What are Fermat Primes?

Fermat numbers are defined as:

```
Fₙ = 2^(2^n) + 1
```

Fermat conjectured all such numbers are prime. Euler refuted this in 1732 by
showing F₅ = 4294967297 = 641 × 6700417 is composite. As of 2026, only five
Fermat primes are confirmed: F₀ through F₄. Whether any further Fermat primes
exist is an open problem — most number theorists believe none exist beyond F₄,
but no proof has been found.

### What is Obang?

Obang (五方) is the classical East Asian cosmological system of five directions:
Center, East, South, West, North. These
correspond to the Five Elements, five colors, and five fundamental
relationships. The system assigns a qualitative character to each direction.

### Why This Matters

The coincidence of exactly 5 known Fermat primes mapping onto exactly 5
directions is notable but not the core claim. The claim is that the *character*
of each direction aligns with the *mathematical role* of its Fermat prime in the
existing constant system of this project. Specifically:

- F₀ = 3 already appears as the meta fixed-point denominator (1/3), the variable
  count in G = D×P/I, and the base of the 3-state system.
- F₂ = 17 was independently identified in H-076 as the amplification constant at
  θ = π in the complex compass.
- F₁ = 5 is self-referential: the five-direction system is named for the count 5,
  and 5 is itself a Fermat prime.

These prior appearances make the mapping non-arbitrary.

---

## The Mapping

### Direction → Fermat Prime Assignment

| Direction | Korean | Element | Fermat Prime | Value  | 2^n exponent |
|-----------|--------|---------|--------------|--------|--------------|
| Center    | 중 (中) | Earth   | F₀           | 3      | 2^1 + 1      |
| East      | 동 (東) | Wood    | F₁           | 5      | 2^2 + 1      |
| South     | 남 (南) | Fire    | F₂           | 17     | 2^4 + 1      |
| West      | 서 (西) | Metal   | F₃           | 257    | 2^8 + 1      |
| North     | 북 (北) | Water   | F₄           | 65537  | 2^16 + 1     |

### Rationale for Each Assignment

**Center → F₀ = 3**
Center is the origin from which all directions radiate. F₀ = 3 is the smallest
Fermat prime and appears as the foundational constant throughout this project:
- 1/3 = meta fixed point (contraction mapping f(I) = 0.7I + 0.1 converges to 1/3)
- G = D×P/I has exactly 3 variables
- 3-state entropy jump anchors the Golden Zone lower bound
- 1/2 + 1/3 + 1/6 = 1: the three canonical fractions sum to unity

**East → F₁ = 5**
East is the direction of origin/beginning in East Asian cosmology (sun rises in
the east). F₁ = 5 is self-referential: the system is called Five Directions
because there are 5 of them, and 5 is itself one of the five Fermat primes. This
closed loop — the count names the system, and the count is prime in the sequence —
is a structural self-reference matching H-070 (self-reference hypothesis).
Additionally, regular pentagon construction (n=5) is possible precisely because
5 is a Fermat prime (Gauss-Wantzel theorem).

**South → F₂ = 17**
South corresponds to Fire and maximal energy/heat. F₂ = 17 was identified in
H-076 as the amplification constant: at θ = π in the complex compass, the
amplification factor equals 17 (a Fermat prime, not arbitrary). Fire = maximal
amplification is a natural assignment. 17 is also the first Fermat prime that
is "non-trivial" — not immediately obvious from the sequence.

**West → F₃ = 257**
West is the direction of completion (sun sets in the west) and Metal, associated
with refinement and structure. F₃ = 257 = 2^8 + 1 is the first Fermat prime
requiring a byte (8 bits) to represent its exponent. It marks the transition
from small/obvious to large/structured. A regular 257-gon is constructible.

**North → F₄ = 65537**
North corresponds to Water and depth/mystery. F₄ = 65537 = 2^16 + 1 is the
largest known Fermat prime and sits at the known boundary of the sequence. Beyond
it lies only composites (as far as verified). North as boundary/limit is apt.
65537 is used in RSA encryption as the standard public exponent — a cryptographic
boundary protecting all digital communication.

---

## Key Mathematical Properties

### Product Formula

The product of all five known Fermat primes yields a near-Mersenne number:

```
3 × 5 × 17 × 257 × 65537 = 4294967295 = 2^32 - 1
```

Verification:
```
3 × 5        = 15
15 × 17      = 255      = 2^8  - 1
255 × 257    = 65535    = 2^16 - 1
65535 × 65537 = 4294967295 = 2^32 - 1
```

This follows from the telescoping identity:

```
(2^1 - 1)(2^1 + 1) = 2^2 - 1
(2^2 - 1)(2^2 + 1) = 2^4 - 1
...
∏_{k=0}^{n} F_k = 2^(2^(n+1)) - 1
```

So the five directions multiply to 2^32 - 1, a 32-bit all-ones mask. This is
not a coincidence of the mapping — it is a theorem about Fermat numbers.

### Gauss-Wantzel Connection

A regular n-gon is constructible with compass and straightedge if and only if:

```
n = 2^k × p₁ × p₂ × ... × pₘ
```

where p₁,...,pₘ are distinct Fermat primes. The constructible polygons based on
the five known Fermat primes include the regular 3-gon, 5-gon (pentagon), 17-gon,
257-gon, and 65537-gon — each corresponding to one direction. The regular
pentagon (5-gon) is the geometric Obang figure itself.

### Exponent Doubling Pattern

```
Fₙ = 2^(2^n) + 1:

  n=0: exponent = 2^0 = 1,     F₀ = 3
  n=1: exponent = 2^1 = 2,     F₁ = 5
  n=2: exponent = 2^2 = 4,     F₂ = 17
  n=3: exponent = 2^3 = 8,     F₃ = 257
  n=4: exponent = 2^4 = 16,    F₄ = 65537
  n=5: exponent = 2^5 = 32,    F₅ = 4294967297 = 641 × 6700417  (COMPOSITE)
```

The exponents 1, 2, 4, 8, 16 are powers of 2, doubling each step.

---

## ASCII Visualizations

### Obang Direction Map with Fermat Primes

```
                    NORTH
                    Water / Depth
                    F₄ = 65537
                    2^16 + 1
                       |
                       |
  WEST      ----------+---------- EAST
  Metal / Bound        |           Wood / Origin
  F₃ = 257          CENTER        F₁ = 5
  2^8 + 1                         2^2 + 1
                    Earth          self-referential
                    F₀ = 3
                    2^1 + 1
                    meta fixed pt
                       |
                       |
                    SOUTH
                    Fire / Amplify
                    F₂ = 17
                    2^4 + 1
                    H-076 constant
```

### Fermat Number Growth (log scale)

```
log₂(Fₙ) vs n:

  n=4 |                                    ████  65537 (~2^16)
      |
  n=3 |                        ████  257   (~2^8)
      |
  n=2 |            ████  17    (~2^4)
      |
  n=1 |      ████  5     (~2^2)
      |
  n=0 | ████  3    (~2^1)
      +----+------+----------+-----------------+---------> n
           0      1          2                 3      4

  Each step: exponent doubles → value squares
  F₄ is ~10^4.8 × larger than F₀
```

### Exponent Sequence: Powers of 2

```
  Position │ Direction │ Exponent │ Fermat Prime │ Digits
  ─────────┼───────────┼──────────┼──────────────┼────────
     F₀    │  Center   │    1     │      3       │   1
     F₁    │  East     │    2     │      5       │   1
     F₂    │  South    │    4     │     17       │   2
     F₃    │  West     │    8     │    257       │   3
     F₄    │  North    │   16     │  65537       │   5
     F₅    │  (beyond) │   32     │ composite    │   —
  ─────────┴───────────┴──────────┴──────────────┴────────
  Exponent doubles each step: 1→2→4→8→16→32
  Prime status: ✓  ✓  ✓  ✓  ✓  ✗
```

### Product Telescoping

```
  F₀                    =   3 = 2^2  - 1
  F₀ × F₁               =  15 = 2^4  - 1
  F₀ × F₁ × F₂          = 255 = 2^8  - 1
  F₀ × F₁ × F₂ × F₃     = 65535 = 2^16 - 1
  F₀ × F₁ × F₂ × F₃ × F₄ = 4294967295 = 2^32 - 1

  Pattern: ∏_{k=0}^{n} F_k = 2^(2^(n+1)) - 1
  At n=4 (all five directions): product = 2^32 - 1
```

---

## Verification Results

### Arithmetic Verification

All Fermat prime values confirmed:

| n | 2^n | 2^(2^n) | Fₙ = 2^(2^n)+1 | Prime? |
|---|-----|---------|-----------------|--------|
| 0 | 1   | 2       | 3               | Yes    |
| 1 | 2   | 4       | 5               | Yes    |
| 2 | 4   | 16      | 17              | Yes    |
| 3 | 8   | 256     | 257             | Yes    |
| 4 | 16  | 65536   | 65537           | Yes    |
| 5 | 32  | 4294967296 | 4294967297   | No (= 641 × 6700417) |

Product verification:
```
3 × 5 × 17 × 257 × 65537
= 15 × 17 × 257 × 65537
= 255 × 257 × 65537
= 65535 × 65537
= 4294967295
= 2^32 - 1  ✓
```

### Connection to Existing Project Constants

| Fermat Prime | Project Appearance | Hypothesis |
|-------------|-------------------|------------|
| F₀ = 3      | 1/3 meta fixed point; 3 variables in G=D×P/I | H-067, H-090 |
| F₁ = 5      | 5 directions = self-referential count | H-070 |
| F₂ = 17     | Amplification at θ=π in complex compass | H-076 |
| F₃ = 257    | No prior project appearance (new) | — |
| F₄ = 65537  | RSA standard exponent; boundary constant | — |

3 out of 5 Fermat primes (F₀, F₁, F₂) already appear independently in the
project constant system. The probability of 3 of 5 randomly chosen primes
matching prior project constants depends on the density of "significant" primes
in the project — this requires a Texas Sharpshooter test to quantify.

### Incompleteness Parallel

The fraction of known Fermat primes to total Fermat numbers is:
```
5 known primes out of infinitely many Fermat numbers
= asymptotically 0 (all others appear composite)
```

The project incompleteness term is 1/6. Whether this numerical connection
is meaningful or coincidental is unresolved. What is structurally parallel:
- The system has exactly 5 complete, known elements (the 5 primes)
- The boundary (F₅ onward) is composite / unknown / unprovable
- This mirrors the 5/6 compass ceiling: 5/6 is achievable, the remaining 1/6
  is the incompleteness gap

---

## Limitations

1. **Direction assignment is interpretive.** The assignment of F₀ to Center vs.
   other directions is motivated post-hoc by the role of 3 in existing constants.
   A different assignment is mathematically possible. The hypothesis requires the
   specific assignment to be justified independently.

2. **Exactly 5 known Fermat primes may be accidental.** Number theorists believe
   F₅ onward are all composite, but this is not proven. If a sixth Fermat prime
   is discovered, the mapping breaks unless Obang is extended (which it cannot be
   — it is a fixed cultural system).

3. **No causal mechanism proposed.** This is a structural correspondence, not a
   claim that Obang "causes" or "explains" the distribution of Fermat primes, or
   vice versa. The mapping is observational.

4. **Texas Sharpshooter not yet computed.** The prior independent appearances of
   F₀, F₁, F₂ in project constants strengthen the case but the p-value has not
   been calculated with the full pipeline.

5. **F₃ = 257 and F₄ = 65537 have no prior project appearance.** Only 3 of 5
   connections are independently motivated. The West and North assignments are
   the weakest parts of the mapping.

---

## Verification Direction

1. **Texas Sharpshooter test:** Given the project's set of "significant constants,"
   what is the probability that 3 of the 5 Fermat primes appear independently?
   Run `calc/hypothesis_verifier.py` with Fermat prime set.

2. **Find F₃, F₄ in project:** Search all hypothesis documents and constant tables
   for appearances of 257 and 65537. Any independent appearance upgrades the
   mapping strength.

3. **Generalization test:** Does the Obang system appear in other mathematical
   structures with exactly-5 known elements? (Known: 5 Platonic solids, 5
   exceptional Lie groups — these are different structures.)

4. **Product formula utility:** Does 2^32 - 1 (the product of all five) appear
   in any project formula or computational constant? This would provide a
   multiplicative bridge between directions.

5. **Gauss-Wantzel connection to compass:** The compass tool in this
   project uses angular geometry. Regular polygons constructible from Fermat
   primes may connect to compass angle quantization.

---

## Summary

Five known Fermat primes map onto five Obang directions with character alignment:
Center=foundation (3), East=self-reference (5), South=amplification (17),
West=structure boundary (257), North=known limit (65537). Three of five primes
(F₀, F₁, F₂) appear independently in existing project constants, providing
partial non-arbitrary grounding. The product of all five is 2^32 - 1, a
mathematically clean result following from the Fermat number telescoping identity.
The fact that exactly 5 Fermat primes are known — and that this number matches
exactly the 5 Obang directions — may reflect a deeper structural reason why 5
is the natural completion count for this class of prime, or it may be coincidence.
The hypothesis is currently a structural observation awaiting Texas Sharpshooter
verification and independent appearance of F₃ and F₄ in project constants.