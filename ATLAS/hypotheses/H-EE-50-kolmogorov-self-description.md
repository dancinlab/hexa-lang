# H-EE-50: Kolmogorov Complexity K(6) = sigma(6)

## Hypothesis

> The Kolmogorov complexity of the number 6 is exactly sigma(6) = 12 bits. Perfect numbers are "self-describing": the information needed to specify them equals their divisor sum. This self-descriptive property is why n=6 appears as a universal constant.

## Background

- Kolmogorov complexity K(n): length of shortest program that outputs n
- K(6) is small (6 is a simple number) — but the claim is about a specific value
- sigma(6) = 12: sum of all divisors
- Self-description: "I am the number whose divisors sum to 12" uniquely identifies 6
- Perfect number property: sigma(n) = 2n, so sigma(6) = 12 = 2*6
- The description "perfect number with 2 prime factors" is ~12 bits of information

## Predictions

1. The shortest description of 6 in any reasonable encoding ~ 12 bits
2. This self-descriptive property is unique to perfect numbers
3. K(28) = sigma(28) = 56 (second perfect number, same pattern)
4. Non-perfect numbers: K(n) != sigma(n) in general

## Conclusion

**Status:** Speculative — K(n) is uncomputable in general
**Bridge:** Information theory ↔ perfect number theory
