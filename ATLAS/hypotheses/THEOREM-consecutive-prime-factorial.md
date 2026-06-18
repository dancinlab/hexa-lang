# Theorem: Consecutive Prime Factorial Product
**n6 Grade: 🟩 EXACT** (auto-graded, 8 unique n=6 constants)


> **Theorem.** Let p and q be primes with p < q. Then p*q = q! if and only if
> (p, q) = (2, 3). The product is 6.

## Statement

Among all pairs of primes (p, q) with p < q, the equation

```
p * q = q!
```

has the unique solution (p, q) = (2, 3), yielding 2 * 3 = 6 = 3!.

## Proof

**Step 1.** Divide both sides by q (which is nonzero):

```
p = q!/q = (q-1)!
```

**Step 2.** Determine when (q-1)! is prime.

For q >= 4, we have q-1 >= 3, so (q-1)! = 1 * 2 * 3 * ... * (q-1).
This product contains both the factor 2 and the factor (q-1) >= 3 as
distinct terms, so (q-1)! >= 6 and (q-1)! is composite.

For q = 3: (q-1)! = 2! = 2, which is prime.
For q = 2: (q-1)! = 1! = 1, which is not prime.

**Step 3.** Therefore q = 3 is the unique value making (q-1)! prime.
This gives p = 2. Check: 2 and 3 are indeed primes with 2 < 3.
Product: 2 * 3 = 6 = 3!. QED.

## Computational Verification

| q  | (q-1)!            | Prime? | Notes                          |
|----|--------------------|--------|--------------------------------|
|  2 | 1                  | No     | 1 is not prime                 |
|  3 | 2                  | **Yes**| p=2, product 2*3=6=3!         |
|  4 | 6                  | No     | 6 = 2*3                        |
|  5 | 24                 | No     | 24 = 2^3 * 3                   |
|  6 | 120                | No     | 120 = 2^3 * 3 * 5              |
|  7 | 720                | No     | 720 = 2^4 * 3^2 * 5            |
|  8 | 5,040              | No     | composite                      |
|  9 | 40,320             | No     | composite                      |
| 10 | 362,880            | No     | composite                      |

Verified computationally for q up to 19. For q >= 4, (q-1)! is always composite
because it contains 2 as a factor and has magnitude >= 6.

## Key Observations

### The proof is elementary

The entire argument rests on one fact: n! is composite for n >= 3.
This is because n! = 1*2*3*...*n contains both 2 and n as factors when n >= 3,
making it divisible by 2 and hence not prime (and >= 6, so not equal to 2).

### Consecutiveness is free

The theorem statement does not require p and q to be consecutive primes.
For ANY primes p < q, p*q = q! forces q = 3 and p = 2.
That (2, 3) are consecutive is a **consequence**, not an assumption.

### Connection to root equation

The equation p*q = q! with p = (q-1)! being prime forces q = 3.
Compare with the root equation: (k-1)! = (k+1)/2, solved by k = 3.

Both characterize k = 3 (and hence n = 3! = 6) through factorial equations.
The present theorem does so via primality of (q-1)!.

## Corollary

> **Corollary.** 6 is the only natural number that is simultaneously:
> (a) a product of two distinct primes, and
> (b) the factorial of the larger prime factor.

**Proof.** If n = p*q with p < q primes and n = q!, then p*q = q!,
which by the theorem forces (p,q) = (2,3) and n = 6. QED.

## Relation to Known Characterizations of 6

| # | Characterization                              | Formula          |
|---|-----------------------------------------------|------------------|
| 1 | Smallest perfect number                       | sigma(6) = 12    |
| 2 | Sum of proper divisors                        | 1+2+3 = 6        |
| 3 | Product of proper divisors                    | 1*2*3 = 6        |
| 4 | Factorial                                     | 3! = 6            |
| 5 | Triangular number                             | T_3 = 6           |
| 6 | **Prime-pair factorial product (this theorem)**| **2*3 = 3! = 6** |

Characterization (6) is independent of (1)-(5). It does not reference
divisor sums, proper divisors, or triangular numbers. It connects the
prime factorization of 6 to its factorial structure in a new way.

## Wilson's Theorem Enhancement

Combining this theorem with Wilson's theorem yields a stronger result:

> **Theorem (Wilson-Root Uniqueness).** The system
>
> (i)  (k-1)! = (k+1)/2  (root equation)
> (ii) k is prime          (Wilson's theorem applies)
>
> has the unique solution k = 3.

**Proof.** By Wilson: (k-1)! = -1 (mod k). Substituting (i):
(k+1)/2 = -1 (mod k), so k+1 = -2 (mod k), so 1 = -2 (mod k),
so k | 3. The unique prime divisor of 3 is k = 3. QED.

## ASCII Diagram: Growth of (q-1)! vs Primality

```
ln((q-1)!)
    |
 15 |                                          *  q=10
    |                                    *  q=9
 10 |                              *  q=8
    |                        *  q=7
  5 |                  *  q=6
    |            *  q=5
    |      *  q=4
    | *  q=3  <-- ONLY PRIME VALUE: (q-1)! = 2
  0 +--+--+--+--+--+--+--+--+--+--> q
    2  3  4  5  6  7  8  9  10
    |
    |  (q-1)! = 1 at q=2 (not prime)
    |  (q-1)! = 2 at q=3 (PRIME!) <-- unique
    |  (q-1)! >= 6 for q>=4 (always composite)
```

## Limitations

- This theorem, while clean and correct, characterizes a very specific property of 6.
- The result is elementary; it follows directly from the fact that n! is composite for n >= 3.
- It does not, by itself, explain *why* 6 is a perfect number.
- The connection to the TECS model's root equation is structural (both select k=3)
  but not causal.

## Verification Direction

- Check whether analogous "product = factorial" theorems exist for other
  number-theoretic functions (e.g., p*q = sigma(q), p*q = phi(q)!).
- Investigate whether this characterization extends to even perfect numbers
  2^(p-1)(2^p - 1) in any useful way.
- Explore whether the theorem has implications for the distribution of
  factorial primes (primes of the form n! +/- 1).
