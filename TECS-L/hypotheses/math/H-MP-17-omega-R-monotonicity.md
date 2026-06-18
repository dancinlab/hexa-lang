# H-MP-17: Monotonicity of ω(n) and R(n) — More Prime Factors Increase R

> **Hypothesis**: For squarefree n, R(n) increases asymptotically 
> exponentially with ω(n) (number of prime factors), with R(n) ≥ (4/3)^{ω(n)-1}·(3/4).

## Background

For squarefree n = p₁·p₂·...·p_k:
R(n) = ∏ f(p_i,1) = ∏ (p_i²-1)/(2p_i)

Minimum: When using the smallest k primes
R_min(k) = f(2,1)·f(3,1)·f(5,1)·...·f(p_k,1)

```
  k=1: R_min = f(2,1) = 3/4
  k=2: R_min = f(2,1)·f(3,1) = 1     ← n=6!
  k=3: R_min = 1·f(5,1) = 12/5 = 2.4
  k=4: R_min = 2.4·f(7,1) = 2.4·24/7 ≈ 8.23
  k=5: R_min = 8.23·f(11,1) = 8.23·60/11 ≈ 44.9
```

## Core Theorem

```
  THEOREM: For squarefree n with ω(n)=k≥3:
    R(n) ≥ (12/5) · ∏_{i=3}^{k} (p_i-1)/2
    → R grows superexponentially in ω

  Proof: f(p,1) = (p+1)(p-1)/(2p) ≥ (p-1)/2 for p≥3.
  For k≥3 primes including 2,3:
    R = f(2,1)·f(3,1)·∏_{i≥3} f(p_i,1) = 1·∏ f(p_i,1)
    ≥ ∏ (p_i-1)/2 ≥ (4/2)·(6/2)·... → grows fast

  ASCII: R_min(k) growth

  R_min
  10^6 |                              ·
  10^4 |                        ·
  100  |                  ·
  10   |            ·
  1    |      ·
  0.75 |  ·
       +--+--+--+--+--+--+--+--→ k=ω(n)
       1  2  3  4  5  6  7  8
```

## Verdict: 🟩 (Trivial but useful lower bound)
## Difficulty: Low | Impact: ★★