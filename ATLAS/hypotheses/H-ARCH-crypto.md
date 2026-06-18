# H-ARCH Crypto: Cryptographic Standards Follow n=6
**n6 Grade: 🟩 EXACT** (auto-graded, 8 unique n=6 constants)


## Hypothesis

> Key cryptographic parameters — block sizes, round counts, key lengths — match n=6 arithmetic with remarkable precision.

## Patterns

| Pattern | n=6 Formula | Value | Match |
|---------|-------------|-------|-------|
| AES block = 128 bit | 2^(sigma-sopfr) = 2^7 | 128 | EXACT |
| AES-128 rounds = 10 | sigma_{-1}*sopfr = 2*5 | 10 | EXACT |
| SHA-256 = 256 bit | 2^(sigma-tau) = 2^8 | 256 | EXACT |
| RSA-2048 | 2^(sigma-mu) = 2^11 | 2048 | EXACT |
| ChaCha20 = 20 rounds | J_2-tau = 24-4 | 20 | EXACT |
| Ed25519 prime | no expression | - | FAIL |

## Score: 5 EXACT out of 6 (83%)

## Key Insight

The cryptographic constants form a power-of-2 ladder:
- 2^7 = 128 (AES block) where 7 = sigma-sopfr
- 2^8 = 256 (SHA) where 8 = sigma-tau
- 2^11 = 2048 (RSA) where 11 = sigma-mu

Each exponent is sigma minus a different n=6 function.

## Conclusion

**Status:** Observational — strongest category (83% exact)
