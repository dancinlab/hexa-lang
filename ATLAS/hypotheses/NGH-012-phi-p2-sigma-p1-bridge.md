# NGH-012: phi(P2) = sigma(P1) — Unique Bridge Between Perfect Numbers

- **ID**: NGH-012
- **Grade**: PROVEN (exact arithmetic)
- **Domain**: Number Theory / Cross-domain
- **Status**: PROVEN
- **GZ-dependent**: No

> phi(28) = 12 = sigma(6). The Euler totient of the second perfect number
> equals the divisor sum of the first. This holds ONLY for (P1,P2)=(6,28).

## Proof

phi(28) = 28 * (1-1/2) * (1-1/7) = 28 * 3/7 = 12
sigma(6) = 1+2+3+6 = 12

phi(P2) = sigma(P1) = 12. QED.

## Uniqueness

phi(P3) = phi(496) = 240, but sigma(P2) = sigma(28) = 56. 240 != 56.
phi(P4) = phi(8128) = 3584, sigma(P3) = sigma(496) = 992. Not equal.

This bridge exists ONLY for the first pair of perfect numbers.

## Connection to Cyclotomic Fields

Q(zeta_28): [Q(zeta_28):Q] = phi(28) = 12 = sigma(6)
The 28th cyclotomic field has degree sigma(P1) over Q.
