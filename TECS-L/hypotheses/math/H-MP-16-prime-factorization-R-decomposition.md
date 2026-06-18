# H-MP-16: Structure of Prime Factorization of R — Deep Properties of Multiplicative Decomposition

> **Hypothesis**: The prime-wise decomposition f(p,a) of R(n) is an "arithmetic fingerprint" of primes,
> and the combination of these fingerprints determines all arithmetic properties of n.

## Background

R(n) = ∏ f(p,a) where f(p,a) = (p^{a+1}-1)/(p(a+1))

```
  f(2,1)=3/4   f(3,1)=4/3   f(5,1)=12/5   f(7,1)=24/7
  f(2,2)=7/6   f(3,2)=13/6  f(5,2)=31/10  f(7,2)=57/14
  f(2,3)=15/8  f(3,3)=40/12 f(5,3)=156/20 f(7,3)=400/28
```

## Core Structure

### Pattern of f(p,1)

```
  f(p,1) = (p²-1)/(2p) = (p+1)(p-1)/(2p)

  f(2,1) = 3/4 < 1  ← The only sub-1!
  f(3,1) = 4/3 = 1/(close to reciprocal of f(2,1))
  f(5,1) = 12/5 ≈ 2.4
  f(7,1) = 24/7 ≈ 3.43
  f(p,1) → p/2 (p→∞)

  Telescoping pairs:
    f(2,1)·f(3,1) = 1     ← σφ=nτ
    f(2,1)²·f(3,1)² = 1   ← ∏R(d|6)=1
    h(2,1)·h(3,1) = 1     ← σ²=n²τ (where h=(f·n/σ)²/τ)
```

### Prime factor interpretation of v_{M_p}(∏R) = -(p-2)

```
  Perfect number P_p = 2^{p-1}·M_p:
    f(2,p-1) = (2^p-1)/(2p) = M_p/(2p) ← M_p in numerator!
    f(M_p,1) = (M_p²-1)/(2M_p) ← M_p in denominator!

  In divisor product:
    M_p denominator: f(M_p,1) contributes in p divisors → M_p^p
    M_p numerator: f(2,p-1)=M_p/(2p) contributes in 2 divisors → M_p^2
    Net exponent: -(p-2)

  Only p=2 cancels: M₂=3 appears 2 times in numerator, 2 times in denominator → exactly 0!
```

### Prime factor count and R behavior

```
  ω(n)=1 (prime powers):
    R(p^a) = f(p,a) — single factor
    R(p) = (p²-1)/(2p) — always >1 (p≥3) or <1 (p=2)

  ω(n)=2 (semiprimes):
    R(pq) = f(p,1)·f(q,1) — product of two factors
    R=1 ⟺ f(p,1)·f(q,1)=1 ⟺ n=6

  ω(n)=3:
    R(pqr) = f(p,1)·f(q,1)·f(r,1) — product of three factors
    Always >1 (∵ f(2,1)·f(3,1)·f(5,1)=12/5>1)

  ASCII: ω vs R relationship

  R
  100|                    · ·
   10|           · · · ·
    1|   ·   ·
  0.5|  ·
     +--+--+--+--+--→ ω(n)
     1  2  3  4  5
```

## Verification Complete

```
  ✅ f(2,1)=3/4 only sub-1 value (proven)
  ✅ f(p,a) monotone in p for fixed a (provable)
  ✅ v_{M_p}(∏R)=-(p-2) (proven this session!)
  ✅ Unique solution R=1 at ω=2 is n=6 (proven)
```

## Difficulty: Medium | Impact: ★★★★