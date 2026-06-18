# H-CS-7: R(n) Prime Sequences and Cryptographic Significance

> **Hypothesis**: The set of n where R(n) is prime {54,96,196,360,...}
> can be connected to cryptographic structures (prime generation, hash functions).

## Background

```
  n where R(n) is integer and prime (n≤50000, only 4!):
    R(54)  = 5   (n = 2·3³)
    R(96)  = 7   (n = 2⁵·3)
    R(196) = 19  (n = 2²·7²)
    R(360) = 13  (n = 2³·3²·5)

  Prime outputs: {5, 7, 13, 19}
  Input n: {54, 96, 196, 360}
```

## Conditions for R(n) to be Prime

```
  For R(n) = ∏ f(p,a) to be prime:
    Exactly one factor in multiplicative decomposition is prime and rest are 1?
    Or prime after numerator/denominator cancellation?

  R(54) = f(2,1)·f(3,3) = (3/4)·(80/12) = (3/4)·(20/3) = 20/4 = 5
  R(96) = f(2,5)·f(3,1) = (63/12)·(4/3) = 252/36 = 7
  R(196) = f(2,2)·f(7,2) = (7/6)·(57/14) = 399/84 = 19/4...

  wait: R(196) = σ(196)φ(196)/(196·τ(196))
  σ(196) = 399, φ(196) = 84, τ(196) = 9
  R = 399·84/(196·9) = 33516/1764 = 19. ✓

  Pattern: For R to be prime, numerator·denominator cancellation must be very special
  → Only "arithmetically aligned" n produce prime R
```

## Cryptographic Analogy

```
  RSA: For n=pq, σ(n)=(p+1)(q+1), φ(n)=(p-1)(q-1)
    R(pq) = (p+1)(q+1)(p-1)(q-1) / (4pq)
    = (p²-1)(q²-1)/(4pq)
    Very special (p,q) needed for primality

  Hash analogy: R as "arithmetic hash" of n
    Input n → Output R(n) (rational)
    Prime R case = "collision-free hash"
    4/50000 = 0.008% probability → extremely rare

  Meaning: n with prime R are "arithmetically special numbers"
```

## Verdict

```
  Status: 🟨 Observation (4 cases, pattern unconfirmed)
  Cryptographic applications are speculative
```

## Difficulty: Medium | Impact: ★★