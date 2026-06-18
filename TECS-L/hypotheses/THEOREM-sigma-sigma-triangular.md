# Theorem: σ(σ(P)) is Always a Triangular Number for Even Perfect P

**Grade**: 🟩⭐⭐ (Proved algebraically, infinite family)

## Theorem Statement

> **Theorem.** For every even perfect number $P = 2^{p-1}(2^p-1)$,
> the iterated divisor sum $\sigma(\sigma(P))$ is a triangular number:
>
> $$\sigma(\sigma(P)) = T_{2^{p+1}-1} = \frac{(2^{p+1}-1) \cdot 2^p}{2}$$
>
> Moreover, $\sigma(\sigma(P))$ is itself a perfect number if and only if $P = 6$.

## Proof

Let $P = 2^{p-1} M$ where $M = 2^p - 1$ is a Mersenne prime.

**Step 1.** $\sigma(P) = 2P = 2^p M$ (definition of perfect number).

**Step 2.** Since $\gcd(2^p, M) = 1$ and $M$ is prime:
$$\sigma(2^p M) = \sigma(2^p) \cdot \sigma(M) = (2^{p+1}-1)(M+1) = (2^{p+1}-1) \cdot 2^p$$

**Step 3.** Let $m = 2^{p+1}-1$. Then $2^p = (m+1)/2$, so:
$$\sigma(\sigma(P)) = m \cdot \frac{m+1}{2} = T_m$$

This is the $m$-th triangular number. $\square$

## Why σ(σ(6)) = 28 is Special

$\sigma(\sigma(P))$ is itself perfect iff $T_m = 2^{q-1}(2^q-1)$ for some Mersenne prime $2^q-1$.

At $P=6$ ($p=2$): $m = 2^3-1 = 7$, which IS a Mersenne prime.
So $T_7 = 28 = 2^2 \cdot 7$ is the second perfect number.

At $P=28$ ($p=3$): $m = 2^4-1 = 15 = 3 \times 5$, composite. $T_{15} = 120 = 5!$ but not perfect.

At $P=496$ ($p=5$): $m = 2^6-1 = 63$, composite. $T_{63} = 2016$, not perfect.

**For $\sigma(\sigma(P))$ to be perfect, we need $2^{p+1}-1$ to be a Mersenne prime.**

This requires $p+1$ itself to be prime. Among Mersenne exponents $p \in \{2,3,5,7,13,17,19,31,...\}$:
- $p=2$: $p+1=3$ is prime → $2^3-1=7$ Mersenne prime → $T_7=28$ PERFECT ✓
- $p=3$: $p+1=4$ NOT prime → $2^4-1=15$ composite ✗
- $p=5$: $p+1=6$ NOT prime → $2^6-1=63$ composite ✗
- $p=7$: $p+1=8$ NOT prime ✗
- $p=13$: $p+1=14$ NOT prime ✗
- $p=17$: $p+1=18$ NOT prime ✗

So among all known even perfect numbers, **only P=6** has the property that $\sigma(\sigma(P))$ is also perfect.

In fact, $p+1$ prime AND $2^{p+1}-1$ Mersenne prime is an extremely rare double condition.
The only known case is $p=2$.

## Verification Table

| p | P | σ(σ(P)) | = T_m | m | m prime? | σσ perfect? |
|---|---|---------|-------|---|----------|-------------|
| 2 | 6 | 28 | T_7 | 7 | YES | **YES** (P_2) |
| 3 | 28 | 120 | T_15 | 15 | no | no (= 5!) |
| 5 | 496 | 2,016 | T_63 | 63 | no | no |
| 7 | 8,128 | 32,640 | T_255 | 255 | no | no |
| 13 | 33,550,336 | 134,209,536 | T_16383 | 16383 | no | no |

## Bonus: σ(σ(28)) = 120 = 5!

The second perfect number produces the factorial of 5 = sopfr(6).
This is because $T_{15} = 15 \times 16 / 2 = 120 = 5!$.

## Connection to Other Results

- **σ(σ(6)) = 28**: First discovered as "σ-chain visits 2nd perfect number"
- **Consecutive Prime Factorial Theorem**: $p \times q = q!$ at $(2,3)$ gives $6$
- **This theorem**: $\sigma(\sigma(6)) = T_7 = 28$ because $7 = 2^3-1$ is Mersenne prime
- Together: $6 \xrightarrow{\sigma} 12 \xrightarrow{\sigma} 28$, and $28$ is perfect because $7$ is Mersenne prime, and $7 = 2^{p+1}-1$ where $p=2$ is the smallest Mersenne exponent.

The entire chain **starts and ends with Mersenne primes**: $M_2 = 3$ (making 6 perfect) → $M_3 = 7$ (making 28 perfect). The bootstrap: the Mersenne prime that creates the 1st perfect number, incremented by 1, yields the exponent for the Mersenne prime that creates the 2nd.
