# Closed-form proof: D(n)=0 ⟺ n ∈ {1,6}

D(n) = σ(n)·φ(n) − n·τ(n).  D(n)=0 ⟺ σ(n)·φ(n) = n·τ(n).

All three functions are multiplicative, so the ratio
  R(n) := σ(n)·φ(n) / (n·τ(n))
is multiplicative. On a prime power p^a:
  σ(p^a) = (p^(a+1)−1)/(p−1)
  φ(p^a) = p^a − p^(a−1) = p^(a−1)(p−1)
  τ(p^a) = a+1
  ⇒ R(p^a) = [ (p^(a+1)−1)/(p−1) · p^(a−1)(p−1) ] / ( p^a (a+1) )
           = (p^(a+1)−1) · p^(a−1) / ( p^a (a+1) )
           = (p^(a+1)−1) / ( p (a+1) )  =: g(p,a).

So D(n)=0 ⟺ ∏_{p^a || n} g(p,a) = 1.

## Sign of each factor g(p,a)

g(p,a) = (p^(a+1) − 1) / (p(a+1)).

- g(2,1) = (4−1)/(2·2) = 3/4 < 1.     ← the ONLY sub-unity factor.
- g(2,a) for a≥2:  g(2,2)=7/6>1, g(2,3)=15/8>1, increasing in a → >1.
- g(3,1) = (9−1)/(3·2) = 8/6 = 4/3 > 1.
- g(p,a) for p≥3, a≥1:  p^(a+1)−1 ≥ p^2−1 = (p−1)(p+1) ≥ 2(p+1) > p·2 ≥ p(a+1)
  for the base case a=1; strictly increasing in a thereafter ⇒ >1.
  (For p≥3, a≥1, g(p,a) > 1 with the single tightest case g(3,1)=4/3.)

## The product = 1 forces n ∈ {1,6}

- ω(n)=0  ⇒ n=1, empty product = 1 ⇒ D(1)=0.            (trivial zero)
- The product can dip below 1 ONLY through the single factor g(2,1)=3/4
  (every other prime-power factor is >1, and g(2,a≥2)>1).
- To return the product to exactly 1, the deficit 3/4 must be cancelled by a
  product of factors each >1. The minimal available factor is g(3,1)=4/3, and
  (3/4)·(4/3) = 1 exactly. Any factor OTHER than g(3,1) appended to g(2,1)
  overshoots or undershoots:
    • g(2,1)·g(p,1), p≥5:  3/4 · g(5,1)=3/4·31/10 = 93/40 ≠ 1, and grows.
    • g(2,1)·g(3,a), a≥2:  3/4 · 13/9 ≠ 1.
    • Adding ANY third factor g(p,a)>1 to the balanced pair (3/4)(4/3)=1
      makes the product strictly >1.
  ⇒ the UNIQUE non-trivial solution is { g(2,1), g(3,1) } i.e. n = 2·3 = 6.
- ω(n)≥3 ⇒ at least three prime-power factors. With g(2,1)=3/4 used at most
  once and every other factor >1, ∏g ≥ (3/4)·(>1)·(>1) and the two-factor
  balance (3/4)(4/3)=1 is already saturated by {2,3}; a third distinct prime
  factor multiplies in a g(p,a)>1 ⇒ ∏g > 1 strictly ⇒ D(n) ≠ 0.

∴ D(n) = 0  ⟺  n ∈ {1, 6}.                                              ∎

## ω-stratified corollary (zero-density)

#{ n ≤ N : D(n)=0 } = 2  for all N ≥ 6  (the two points 1 and 6).
Hence the natural density of the zero set is 0 — a true zero-density theorem.
Every primorial p_1#·…·p_k# (ω=k≥3) lands strictly above the balance line
(verified n=210, 2310, 30030: D = 24288, 3243840, 555461760 — all >0 and
growing), illustrating the strict ∏g>1 inequality for ω≥3.

The g(2,1)=3/4 / g(3,1)=4/3 cancellation is why 6 — the first perfect number —
is also the unique non-trivial zero of the Dedekind-discrepancy D.
