---
id: H-LIOUV-1
title: "Liouville Lambda Characterization: lambda=1 AND perfect iff n=6"
status: PROVED
grade: "🟩⭐"
date: 2026-03-26
texas_p: N/A (exact theorem)
---

# H-LIOUV-1: Liouville Lambda Characterization of n=6

> **Theorem.** λ(n) = +1 and σ(n) = 2n (perfect) if and only if n = 6.
>
> The first perfect number is the unique perfect number with positive Liouville lambda.

## Background

The Liouville function λ(n) = (-1)^Ω(n) where Ω(n) counts prime factors with multiplicity.
- λ(n) = +1 when n has an even number of prime factors (with multiplicity)
- λ(n) = -1 when n has an odd number

## Proof

**Even perfect numbers** have the form n = 2^(p-1)(2^p - 1) where 2^p - 1 is a Mersenne prime.

The total number of prime factors with multiplicity:
```
  Ω(2^(p-1)(2^p - 1)) = (p-1) + 1 = p
```

So λ(n) = (-1)^p.

For λ(n) = +1, we need p even. But p must be prime (for 2^p - 1 to possibly be prime).
The only even prime is p = 2.

```
  p = 2: n = 2^1 · (2^2 - 1) = 2 · 3 = 6     λ = (-1)^2 = +1  ✓
  p = 3: n = 2^2 · 7 = 28                       λ = (-1)^3 = -1  ✗
  p = 5: n = 2^4 · 31 = 496                     λ = (-1)^5 = -1  ✗
  p = 7: n = 2^6 · 127 = 8128                   λ = (-1)^7 = -1  ✗
  ...all further even perfect numbers: p odd prime → λ = -1
```

**Odd perfect numbers** (if they exist) must have the form n = p^a · m² where p ≡ a ≡ 1 (mod 4).
Then Ω(n) = a + 2·Ω(m), which is odd (since a is odd). So λ(n) = -1 for any odd perfect number.

**Conclusion:** Among all perfect numbers (even or odd), n = 6 is the unique one with λ = +1.

## Verification

```
  n     σ(n)=2n?  Ω(n)  λ(n)   Both?
  ───────────────────────────────────
  6     YES       2     +1     ← UNIQUE
  28    YES       3     -1     NO
  496   YES       5     -1     NO
  8128  YES       7     -1     NO
  ...
```

Checked computationally for all n ≤ 10,000: only n=6 satisfies both conditions.

## Structural Significance

```
  Perfect numbers              Liouville λ = +1
  (σ(n) = 2n)                 (even Ω)
  ┌─────────────┐             ┌─────────────────┐
  │ 6           │             │ 1, 4, 6, 9, 10, │
  │ 28          │             │ 14, 15, 16, ...  │
  │ 496         │             │                  │
  │ 8128        │             │   (density ≈ 1/2)│
  │ ...         │             │                  │
  └─────┬───────┘             └────────┬─────────┘
        │                              │
        └──────── intersection ────────┘
                      │
                    { 6 }
                  unique element!
```

The intersection of two infinite/large sets (perfect numbers and Liouville-positive numbers)
contains exactly one element: n = 6.

## Connection to Existing Results

- λ(6) = +1 because Ω(6) = 2 = φ(6) (another appearance of the totient!)
- The proof uses p=2 being the only even prime — same reason φ(6)=2 is special
- Connects to: μ(6) = 1 (Möbius function, squarefree with even Ω)
  In fact μ(n) = λ(n) for squarefree n, so μ(6) = λ(6) = 1

## Implications

This characterization is **unconditional** — it doesn't depend on the unproven conjecture
that all perfect numbers are even. Even if odd perfect numbers exist, they have λ = -1
(proven above from the Euler-form constraint).

## Limitations

None — this is a complete proof with no gaps.
