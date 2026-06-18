# DEEP: The Mersenne Bootstrap Chain
**n6 Grade: 🟩 EXACT** (auto-graded, 13 unique n=6 constants)


> **Hypothesis**: The chain M_2=3 -> P_1=6 -> sigma -> 12 -> sigma -> 28=P_2
> is a unique self-bootstrapping structure in number theory, where the
> first perfect number generates the second via iterated sigma. This
> bootstrap is unrepeatable: it relies on (2,3) being the only consecutive
> Mersenne exponents, which in turn relies on 2 being the only even prime.

## Background

The sum-of-divisors function sigma applied twice to the first perfect number 6
yields the second perfect number 28:

```
  sigma(6)  = 1+2+3+6 = 12
  sigma(12) = 1+2+3+4+6+12 = 28
```

This creates a "bootstrap chain":

```
  M_2=3  -->  P_1=6  --sigma-->  12  --sigma-->  28=P_2  (uses M_3=7)
  ^                                                        ^
  1st Mersenne prime                          2nd Mersenne prime
```

The chain works because:
1. sigma(6) = 12 = 2^2 * 3 (redistributes the prime factors)
2. sigma(12) = sigma(2^2)*sigma(3) = 7*4 = 28 (produces the Mersenne prime 7)
3. 28 = 2^2 * 7 = 2^(3-1) * (2^3 - 1) is perfect by Euclid-Euler

Related hypotheses: H-067 (1/2+1/3=5/6), H-098 (6 unique perfect), H-CX-501 (Bridge Theorem)

---

## 1. Does the Chain Continue?

### 1.1 sigma^k(28) for k=1..10

| k | sigma^k(28) | Factorization | Notes |
|---|-------------|---------------|-------|
| 1 | 56 | 2^3 * 7 | = 2*P_2 |
| 2 | 120 | 2^3 * 3 * 5 | T_15, 5! |
| 3 | 360 | 2^3 * 3^2 * 5 | |
| 4 | 1170 | 2 * 3^2 * 5 * 13 | |
| 5 | 3276 | 2^2 * 3^2 * 7 * 13 | |
| 6 | 10192 | 2^4 * 7^2 * 13 | |
| 7 | 24738 | 2 * 3 * 7 * 19 * 31 | |
| 8 | 61440 | 2^12 * 3 * 5 | |
| 9 | 196584 | 2^3 * 3 * 8191 | contains M_13! |
| 10 | 491520 | 2^15 * 3 * 5 | |

**Result**: 496 never appears. The chain diverges away from perfect numbers.

### 1.2 sigma^k(6) for k=1..15

| k | sigma^k(6) | Notes |
|---|-----------|-------|
| 0 | 6 | P_1, 3!, T_3 |
| 1 | 12 | = 2*P_1 |
| 2 | 28 | P_2, T_7 |
| 3 | 56 | = 2*P_2 |
| 4 | 120 | 5!, T_15 |
| 5 | 360 | |
| 6 | 1170 | |
| 7 | 3276 | |
| 8 | 10192 | |
| 9 | 24738 | |
| 10 | 61440 | |
| 11 | 196584 | |
| 12 | 491520 | |
| 13 | 1572840 | |
| 14 | 5433480 | |
| 15 | 20180160 | |

**Result**: Neither 496 nor 8128 appears in sigma^k(6) for k=1..100. The bootstrap
is a one-time event.

### 1.3 Alternative iterated functions from 28

```
  phi^k(28):  28 -> 12 -> 4 -> 2 -> 1  (collapses to 1)
  tau^k(28):  28 -> 6 -> 4 -> 3 -> 2   (collapses to 2)
                         ^
                     NOTE: tau(28) = 6 = P_1! (reverse bridge)
```

**Discovery**: tau(28) = 6. The divisor count of the 2nd perfect number
is the 1st perfect number. This is a REVERSE bridge: P_2 -> tau -> P_1.

```
  (sigma o phi) chain from 28:
    sigma(phi(28)) = sigma(12) = 28  <-- FIXED POINT!
    sigma(phi(28)) = 28 forever
```

**Major Discovery**: 28 is a fixed point of sigma o phi.

```
  (phi o sigma) chain from 28:
    phi(sigma(28)) = phi(56) = 24
    phi(sigma(24)) = ... -> 24 -> 16 -> 30 -> 24 -> 16 -> 30 (3-cycle)
```

### 1.4 sigma(phi(n)) = n: Complete solution set

All solutions up to 10,000:

| n | phi(n) | sigma(phi(n)) |
|---|--------|---------------|
| 3 | 2 | 3 |
| 15 | 8 | 15 |
| **28** | **12** | **28** |
| 255 | 128 | 255 |
| 744 | 240 | 744 |
| 2418 | 720 | 2418 |

28 is the **only perfect number** that is a fixed point of sigma o phi.

Pattern in the solutions: 3 = M_2, 15 = M_4 (not prime but 2^4-1),
255 = M_8 = 2^8-1. These are all of the form 2^k - 1!

```
  3   = 2^2 - 1
  15  = 2^4 - 1
  28  = 2^2 * 7    (exception: the perfect number)
  255 = 2^8 - 1
```

---

## 2. Mersenne Prime Spacing

### 2.1 Gaps between consecutive Mersenne exponents

| p_k | p_{k+1} | gap |
|-----|---------|-----|
| 2 | 3 | **1** |
| 3 | 5 | 2 |
| 5 | 7 | 2 |
| 7 | 13 | 6 |
| 13 | 17 | 4 |
| 17 | 19 | 2 |
| 19 | 31 | 12 |
| 31 | 61 | 30 |
| 61 | 89 | 28 |
| 89 | 107 | 18 |
| 107 | 127 | 20 |
| 127 | 521 | 394 |

**Gap = 1 occurs exactly once**, between p=2 and p=3.

### 2.2 ASCII histogram of gaps

```
  gap=1:  *                            (2,3) -- THE BOOTSTRAP
  gap=2:  ***                          (3,5), (5,7), (17,19)
  gap=4:  *                            (13,17)
  gap=6:  *                            (7,13)
  gap=12: *                            (19,31)
  gap=18: *                            (89,107)
  gap=20: *                            (107,127)
  gap=28: *                            (61,89)
  gap=30: *                            (31,61)
  gap=394:*                            (127,521)
```

The gap=1 is not just minimum -- it is **provably unique** (see Section 5).

---

## 3. Generalized sigma-chains from Perfect Numbers

### sigma^k(P) for P = 6, 28, 496, 8128 (k=1..5)

| k | sigma^k(6) | sigma^k(28) | sigma^k(496) | sigma^k(8128) |
|---|-----------|------------|-------------|--------------|
| 1 | 12 | 56 | 992 | 16256 |
| 2 | 28 (P!) | 120 (5!) | 2016 (T_63) | 32640 (T_255) |
| 3 | 56 | 360 | 6552 | 110160 |
| 4 | 120 (5!) | 1170 | 21840 | 405108 |
| 5 | 360 | 3276 | 83328 | 1191680 |

**Observations**:

1. sigma^1(P_k) = 2*P_k always (definition of perfect number)
2. sigma^2(P_k) is always triangular (proved in Section 3.1)
3. Only sigma^2(P_1) = 28 is also perfect
4. The chains from 6 and 28 merge at k=3 (both reach 56 -> 120 -> ...)

### 3.1 THEOREM: sigma(sigma(P_k)) is always triangular

For P_k = 2^(p-1) * M_p where M_p = 2^p - 1 is Mersenne prime:

```
  sigma(P_k) = sigma(2^(p-1)) * sigma(M_p)
             = (2^p - 1) * (M_p + 1)
             = (2^p - 1) * 2^p
             = 2 * P_k
```

Then:

```
  sigma(2P_k) = sigma(2^p * M_p)
              = sigma(2^p) * sigma(M_p)      [gcd(2^p, M_p)=1]
              = (2^(p+1) - 1) * 2^p
```

Now set k = 2^(p+1) - 1. Then:

```
  k * (k+1) / 2 = (2^(p+1) - 1) * 2^(p+1) / 2
                 = (2^(p+1) - 1) * 2^p
                 = sigma(sigma(P_k))
```

**Therefore sigma(sigma(P_k)) = T_{2^(p+1)-1} = T_{M_{p+1}} for all even perfect P_k.**

Verified computationally:

| p | P_k | sigma^2(P_k) | Triangular index | Index = M_{p+1}? |
|---|-----|-------------|-----------------|------------------|
| 2 | 6 | 28 | T_7 | 7 = M_3 YES |
| 3 | 28 | 120 | T_15 | 15 = M_4 (not prime) |
| 5 | 496 | 2016 | T_63 | 63 = M_6 (not prime) |
| 7 | 8128 | 32640 | T_255 | 255 = M_8 (not prime) |
| 13 | 33550336 | 134209536 | T_16383 | 16383 = M_14 (not prime) |

**Corollary**: sigma(sigma(P_k)) is perfect if and only if 2^(p+1)-1 is Mersenne prime,
which requires p+1 to also be a Mersenne exponent.

---

## 4. The Mersenne Tower

### 4.1 Catalan-Mersenne sequence

Define T(p) = 2^p - 1 and iterate starting from p=2:

```
  Level 0:  p = 2
  Level 1:  M_2 = 3                                    (prime)
  Level 2:  M_3 = 7                                    (prime)
  Level 3:  M_7 = 127                                  (prime)
  Level 4:  M_127 = 170141183460469231731687303715884105727  (prime, Lucas 1876)
  Level 5:  M_{M_127} = 2^(1.7*10^38) - 1              (UNKNOWN)
```

This is the **Catalan-Mersenne conjecture** (1876): every term in this sequence is prime.
Status: **UNRESOLVED**. M_{M_127} has approximately 10^38 digits and has never been tested.

### 4.2 Perfect numbers from the tower

Each tower level produces a perfect number:

```
  Level 1: M_2=3    -> P = 2^1 * 3 = 6
  Level 2: M_3=7    -> P = 2^2 * 7 = 28
  Level 3: M_7=127  -> P = 2^6 * 127 = 8128
  Level 4: M_127    -> P = 2^126 * M_127 (a 39-digit number)
```

Note: The tower skips P_3 = 496 (which uses M_5 = 31, and 5 is not in the tower).

### 4.3 Tower vs sigma-chain comparison

```
  sigma-chain:  6 --> 12 --> 28 --> 56 --> 120 --> 360 --> ...
                P_1              P_2         5!

  Tower:        6 ---------> 28 ------------------> 8128
                P_1          P_2                     P_4

  The sigma-chain connects P_1 to P_2 (tower levels 1-2).
  It NEVER reaches P_4=8128 or any higher tower entry.
  The tower connects P_1 to P_2 to P_4 via the Mersenne iteration.
```

The sigma-chain is "local" (arithmetic), while the tower is "exponential" (2^p - 1).
They only agree at the first step because the gap between Mersenne exponents 2 and 3 is 1.

---

## 5. Why (2,3) is the Only Consecutive Mersenne Exponent Pair

### 5.1 THEOREM (proved)

**(2,3) is the unique pair of consecutive integers that are both Mersenne exponents.**

**Proof**:

```
  1. For 2^p - 1 to be prime, p must be prime (well-known).
     (If p = ab composite, then 2^p - 1 = (2^a - 1)(2^a(b-1) + ... + 1))

  2. All primes except 2 are odd.

  3. If p >= 3 is a Mersenne exponent, then p is an odd prime, so p+1 is even.

  4. The only even prime is 2. But p+1 >= 4 > 2, so p+1 is not prime.

  5. Since p+1 is not prime, p+1 cannot be a Mersenne exponent.

  6. The only remaining case is p=2: then p+1=3, which IS a Mersenne exponent.

  QED.
```

### 5.2 Consequence for the bootstrap

For sigma(sigma(P_k)) to be perfect, we need p and p+1 to both be Mersenne exponents
(so that 2^(p+1)-1 is Mersenne prime). By the theorem above, this happens only for p=2.

**Therefore the Mersenne Bootstrap Chain 6 -> 28 is unique. No other perfect number
generates the next perfect number via double-sigma.**

---

## 6. The Bootstrap as a Fixed-Point Equation

### 6.1 f(P) = sigma(sigma(P)) results

| P_k | f(P_k) = sigma^2(P_k) | Perfect? |
|-----|----------------------|----------|
| 6 | 28 | YES |
| 28 | 120 = 5! | no |
| 496 | 2016 | no |
| 8128 | 32640 | no |

### 6.2 General formula

```
  f(P_k) = sigma(sigma(P_k)) = (2^(p+1) - 1) * 2^p

  For p=2:  f(6)    = 7 * 4     = 28   = 2^2 * 7    (perfect: 7 = M_3)
  For p=3:  f(28)   = 15 * 8    = 120  = 2^3 * 15   (NOT perfect: 15 = 3*5)
  For p=5:  f(496)  = 63 * 32   = 2016 = 2^5 * 63   (NOT perfect: 63 = 9*7)
  For p=7:  f(8128) = 255 * 128 = 32640 = 2^7 * 255 (NOT perfect: 255 = 3*5*17)
```

The pattern is clear: sigma^2(P_k) = 2^p * (2^(p+1) - 1), which has the Euclid-Euler
form 2^q * M if and only if 2^(p+1) - 1 is Mersenne prime.

### 6.3 Is there a function g with g(P_k) = P_{k+1} for all k?

No simple arithmetic function works because the Mersenne exponents grow irregularly:
2, 3, 5, 7, 13, 17, 19, 31, ...

The ratios P_{k+1}/P_k are:
```
  P_2/P_1 = 28/6       = 4.667
  P_3/P_2 = 496/28     = 17.714
  P_4/P_3 = 8128/496   = 16.387
```

No pattern. The "generator" for perfect numbers is the Mersenne primality condition,
which is not expressible as an iterated arithmetic function.

---

## 7. Connection to the Prime Factorial Theorem

### 7.1 Two theorems, one root

**Theorem A** (Prime Factorial): p * q = q! with p,q prime has unique solution (2,3), product 6.

**Theorem B** (Bootstrap Uniqueness): sigma(sigma(P_k)) = P_{k+1} has unique solution k=1 (P_1=6 -> P_2=28).

Both theorems ultimately rely on the same fact:

> **2 and 3 are the only consecutive primes.**

For Theorem A: p*q = q! requires p = (q-1)!, and (q-1)! is prime only for q=2 (gives p=1, not prime)
or q=3 (gives p=2). The adjacency of 2 and 3 as primes is what makes 2*3 = 3! work.

For Theorem B: The bootstrap requires consecutive Mersenne exponents, and since all Mersenne
exponents > 2 are odd, two consecutive integers cannot both be Mersenne exponents unless one
of them is 2 (the only even prime).

### 7.2 Unified root theorem

**Theorem (The Uniqueness of 2)**:

The following are all equivalent consequences of "2 is the only even prime":

```
  (a) (2,3) is the only pair of consecutive primes
  (b) (2,3) is the only pair of consecutive Mersenne exponents
  (c) p*q = q! has unique prime solution (p,q) = (2,3)
  (d) 6 = 2*3 = 3! is the only number that is both a prime product and a prime factorial
  (e) The Mersenne Bootstrap 6 -> 28 is unique
  (f) 6 is the only perfect number whose sigma-chain hits another perfect number
```

The root cause in every case: 2 is the only prime p such that p+1 is also prime.
This is because every other prime is odd, and odd+1 = even > 2 = composite.

---

## 8. The Number 120 = sigma(sigma(28)) = 5!

### 8.1 Properties

```
  120 = 5!                    (factorial)
  120 = T_15 = 15*16/2        (triangular)
  120 = 2^3 * 3 * 5           (factorization)
  120 = |S_5|                  (symmetric group order)
  120 = order of Ih            (icosahedral symmetry group)
  tau(120) = 16                (highly composite)
  sigma(120) = 360             (degrees in a circle!)
  sigma(120)/120 = 3           (integer abundancy!)
  120 is a practical number    (every k <= 120 is a sum of distinct divisors)
```

### 8.2 Divisors of 120

```
  1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 24, 30, 40, 60, 120
                    ^
                    6 divides 120!
```

Note: 6 (the first perfect number) is a divisor of 120, but 28 is not.

### 8.3 The chain 6 -> 12 -> 28 -> 56 -> 120 and abundancy

| n | sigma(n)/n | Type |
|---|-----------|------|
| 6 | 2.0000 | perfect (sigma/n = 2 exactly) |
| 12 | 2.3333 | abundant |
| 28 | 2.0000 | perfect (sigma/n = 2 exactly) |
| 56 | 2.1429 | abundant |
| 120 | 3.0000 | abundant (integer abundancy!) |

The abundancy oscillates: perfect -> abundant -> perfect -> abundant -> highly abundant.

### 8.4 sigma(120) = 360

```
  sigma(120) = 360 = degrees in a circle (Babylonian base-60 system)
  360 = 2^3 * 3^2 * 5
  tau(360) = 24 divisors (why Babylonians chose it: maximally divisible)
  sigma(360) = 1170
```

While the 360-degree connection is numerologically tempting, it is a historical
convention (Babylonian base-60) rather than a mathematical necessity. The fact
that sigma(120) = 360 is arithmetically correct but not structurally deep.

### 8.5 Triangular factorials: a remarkable coincidence

Numbers that are BOTH factorial and triangular (up to 10^30):

| n | Factorial | Triangular |
|---|----------|-----------|
| 1 | 1! | T_1 |
| 6 | 3! | T_3 |
| 120 | 5! | T_15 |

Only THREE known. This is likely a complete list (related to Brocard's problem, unresolved).

The triangular indices 1, 3, 15 have ratios 3, 5 -- consecutive odd primes!

**Remarkable**: The sigma-chain from 6 hits ALL known triangular-factorials:

```
  sigma^0(6) = 6   = 3!  = T_3
  sigma^2(6) = 28  =     = T_7   (triangular but not factorial)
  sigma^4(6) = 120 = 5!  = T_15
```

The even-indexed terms of the sigma-chain from 6 trace through
T_3 -> T_7 -> T_15, with triangular indices 3, 7, 15 = M_2, M_3, M_4.

---

## 9. Complete Structure Diagram

```
  THE MERSENNE BOOTSTRAP CHAIN
  ============================

  2 (only even prime)
  |
  |--- "2 is the only even prime"
  |         |
  |    (2,3) only consecutive primes
  |         |
  |    +----+----+----+
  |    |         |    |
  |  p*q=q!   consec  unique
  |  unique   Mersenne perfect-
  |  at 6     exps    number
  |    |       |      factorial
  |    v       v        |
  |    6 = 3!  (2,3)    v
  |    |       gap=1    6
  |    |       |
  |    +---+---+
  |        |
  |   BOOTSTRAP CHAIN
  |        |
  |   6 --sigma--> 12 --sigma--> 28
  |   P_1 = T_3                  P_2 = T_7
  |   3!                         |
  |                         --sigma--> 56 --sigma--> 120
  |                                                  5! = T_15
  |                                                  |
  |                                             sigma(120) = 360
  |
  |   MERSENNE TOWER (separate structure)
  |   M_2=3 -> M_3=7 -> M_7=127 -> M_127 -> ...
  |   P_1=6    P_2=28   P_4=8128   P_12=huge
  |
  |   KEY FORMULA:
  |   sigma^2(P_k) = T_{M_{p+1}} = (2^(p+1)-1) * 2^p
  |   This is perfect iff M_{p+1} is Mersenne prime
  |   iff p+1 is a Mersenne exponent
  |   iff (p, p+1) are consecutive Mersenne exponents
  |   iff p=2 (proved)
```

---

## 10. Summary of Results

### Proven results (6 theorems)

| # | Result | Status |
|---|--------|--------|
| 1 | sigma^2(P_k) = T_{M_{p+1}} for all even perfect P_k | PROVEN (algebraic) |
| 2 | (2,3) is the unique pair of consecutive Mersenne exponents | PROVEN (parity) |
| 3 | The bootstrap 6->28 is the only sigma^2 perfect-to-perfect bridge | PROVEN (from 1+2) |
| 4 | tau(28) = 6 (reverse bridge P_2 -> P_1) | VERIFIED |
| 5 | 28 is the only perfect number with sigma(phi(n))=n | VERIFIED (to 10^4) |
| 6 | sigma^k(6) never hits 496 or 8128 | VERIFIED (to k=100) |

### Structural observations (not claimed as theorems)

| # | Observation | Assessment |
|---|------------|-----------|
| A | Triangular indices of sigma^{2k}(6): 3, 7, 15 = M_2, M_3, M_4 | Partially coincidental (only 3 data points) |
| B | 1, 6, 120 are the only triangular factorials | Open conjecture (Brocard-related) |
| C | sigma(120) = 360 (degrees in circle) | Arithmetically true but culturally contingent |
| D | 28 is a fixed point of sigma o phi | True, one of 6 known solutions to 10^4 |
| E | Catalan-Mersenne tower 2->3->7->127->M_127->... all prime | UNRESOLVED (open since 1876) |

### Limitations

1. The bootstrap chain is a property of small numbers (6, 28). The Strong Law of
   Small Numbers warns against over-interpretation.

2. The uniqueness proof (Theorem 2) is elementary -- it follows directly from
   2 being the only even prime. This is well-known number theory, not a new discovery.

3. The sigma^2(P_k) = T_{M_{p+1}} formula, while elegant, is a straightforward
   consequence of sigma being multiplicative. It should be in the literature.

4. The connection to the Prime Factorial Theorem via "2 is the only even prime" is
   a unifying observation, not a deep theorem. Both results have trivial proofs.

5. Whether the chain 6->28 has any significance beyond number theory (e.g., for
   consciousness models) depends entirely on the validity of the G=D*P/I model,
   which is postulated, not proven.

### What IS genuinely remarkable

The bootstrap chain concentrates an unusual density of mathematical structure:

```
  In just 5 steps: 6 -> 12 -> 28 -> 56 -> 120

  - Two perfect numbers (6, 28)
  - Three triangular numbers (6=T_3, 28=T_7, 120=T_15)
  - Two factorials (6=3!, 120=5!)
  - One fixed point of sigma o phi (28)
  - Triangular indices are Mersenne numbers (3, 7, 15)
  - The abundancy oscillates between exactly 2 (perfect) and non-integer
  - 120 has integer abundancy 3 (rare)
```

This concentration of structure in such a short chain is the real observation.
Whether it is "significant" or a consequence of small numbers having many
properties is a matter of mathematical taste.

---

## Verification Direction

1. Search the literature for sigma^2(P_k) = T_{M_{p+1}} -- likely known but worth citing
2. Extend sigma(phi(n))=n search beyond 10^4 to check if 28 remains the only perfect solution
3. Investigate whether the triangular index pattern M_2, M_3, M_4 continues (it does not:
   sigma^6(6) = 1170, and checking if sigma^8(6) is triangular would test this)
4. Connect to the Bridge Theorem (H-CX-501) framework: the bootstrap is another
   manifestation of 6 being the unique organizing number

---

*Golden Zone dependency: NONE. These are pure number theory results, independent of
the G=D*P/I model. The uniqueness proofs are unconditional.*

*Computed: 2026-03-29. All numerical results verified with sympy.*
