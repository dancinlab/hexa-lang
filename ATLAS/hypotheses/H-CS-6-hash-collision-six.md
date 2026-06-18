# H-CS-6: Hash Collision Probability and σφ/(nτ) Ratio

> **Hypothesis**: The "optimal load factor" of collision probability in n-bucket hash is related to the σφ/(nτ) ratio.

## Grade: ⚪ (Coincidence — No structural connection)

## Background
- Birthday problem: Collision probability when inserting k items into n buckets
- Optimal load factor: Usually 0.7-0.8
- Is σφ/(nτ) the "arithmetic fitness" of hash table size n?

## Verification Results (2026-03-24)

### Test 1: Birthday Paradox

6 does not appear at all in the Birthday paradox formula.

```
P(collision) = 1 - prod(1 - i/N) for i=0..k-1
50% threshold: k ≈ sqrt(2*ln(2)) * sqrt(N) ≈ 1.1774 * sqrt(N)

N=2^128 (MD5):    k ≈ 2^64.2
N=2^256 (SHA-256): k ≈ 2^128.2
N=2^512 (SHA-512): k ≈ 2^256.2
```

The constant sqrt(2*ln(2)) = 1.1774 consists only of 2 and ln(2). Unrelated to 6.

### Test 2: Hash Function Round Count Survey

| Algorithm  | Bits | Rounds | Rounds%6==0? |
|------------|------|--------|--------------|
| MD5        | 128  |     64 | NO           |
| SHA-1      | 160  |     80 | NO           |
| SHA-256    | 256  |     64 | NO           |
| SHA-512    | 512  |     80 | NO           |
| SHA-3/256  | 256  |     24 | YES (4x6)    |
| SHA-3/512  | 512  |     24 | YES (4x6)    |
| BLAKE2b    | 512  |     12 | YES (2x6)    |
| BLAKE3     | 256  |      7 | NO           |
| Whirlpool  | 512  |     10 | NO           |

```
Multiples of 6: 5/11 = 45%
Control — multiples of 4: 9/11 = 82%
Control — multiples of 8: 8/11 = 73%
```

4 and 8 are much more prevalent than 6. This is natural in binary computers.

### Test 3: Keccak l=6 Analysis

Keccak round count formula: `nr = 12 + 2*l` where `l = log2(w)`.

```
w= 1: l=0, nr=12
w= 2: l=1, nr=14
w= 4: l=2, nr=16
w= 8: l=3, nr=18
w=16: l=4, nr=20
w=32: l=5, nr=22
w=64: l=6, nr=24   ← standard SHA-3
```

Reason for l=6: lane width=64 was chosen to fit 64-bit CPU registers.
For 128-bit CPU, l=7, nr=26. **6 is a byproduct of CPU architecture, not a number-theoretic inevitability.**

### Test 4: σφ/(nτ) = 1

```
n=6:   σ=12, φ=2, τ=4  → σφ/(nτ) = 24/24 = 1.000
n=28:  σ=56, φ=12, τ=6 → σφ/(nτ) = 672/168 = 4.000
n=496: σ=992, φ=240, τ=10 → σφ/(nτ) = 238080/4960 = 48.000
```

σφ/(nτ)=1 holds only for n=6 (not for n=28, 496).
While it's a unique property of n=6, there's no causal connection to hash performance.
The coincidence with optimal load factor=1 for chaining hash tables is accidental.

### Test 5: Other

```
sqrt(2*ln(2)) = 1.1774  (birthday constant)
sqrt(6)       = 2.4495
ln(6)         = 1.7918
```

No combination matches standard hash constants.

## Conclusion

| Item | Result |
|------|--------|
| Does 6 appear in Birthday paradox? | NO |
| Pattern of 6 in hash round counts? | Only some (SHA-3, BLAKE2). 4, 8 are more prevalent |
| Keccak l=6? | Byproduct of 64-bit CPU architecture |
| σφ/(nτ)=1 → hash performance? | No causal connection |

**GRADE: ⚪** — There is no structural mathematical connection between hash collision probability and 6.
Keccak's l=6 is a result of engineering choice (64-bit CPU), and σφ/(nτ)=1 is a unique property of n=6 but
unrelated to hash performance.

## Difficulty: Low | Impact: ★