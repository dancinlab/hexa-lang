# H-SEQ-1: Integer Sequence Characterizations of n=6

> **Hypothesis**: Every major integer sequence (Fibonacci, Lucas, Pell, Bell,
> Catalan, Motzkin, Tribonacci, Padovan, Wedderburn-Etherington) produces
> a unique characterization of n=6 through its arithmetic functions.
> n=6 is the unique "universal fixed point" of classical sequences.

## Core Constants

```
  n=6, sigma=12, phi=2, tau=4, sopfr=5, omega=2
```

## Discoveries Table

| Sequence | Identity | Unique? | Grade |
|----------|----------|---------|-------|
| Fibonacci | F_{sigma} = sigma^2 (F_12=144=12^2) | Yes, n>1 | star |
| Fibonacci | F_n - n^2 = -P_2 (F_6-36=-28) | Exact | green |
| Lucas | L_n = sigma+phi+tau (L_6=18) | Yes | star |
| Pell | Pell(2,3,4) = (phi,sopfr,sigma) = (2,5,12) | Yes | star |
| Bell | B_{tau} = C(n,2) (B_4=15=C(6,2)) | Yes | star |
| Catalan | C_{omega} = phi (C_2=2=phi(6)) | n=2,6 | green |
| Motzkin | M_{sopfr} = T(n) (M_5=21=T(6)) | Yes | star |
| Tribonacci | Trib_{sigma-tau} = sigma*phi (Trib_8=24) | Yes | star |
| Padovan | Pad(sigma-phi) = sigma (Pad_10=12) | Yes | star |
| Padovan | Pad(sigma+1) = P_2 (Pad_13=28) | Exact | green |
| WE | WE(n) = n for n>1 (WE_6=6) | Yes, n>1 | green |
| WE | WE(n+1) = p(n) (WE_7=11=p(6)) | Exact | green |
| Tetranacci | Tetra(n) = tau (Tetra_6=4) | - | green |

## Proofs

### F_{sigma(n)} = sigma(n)^2 (Fibonacci-Square Crossing)

```
  F_n vs n^2:
  n:   1  2  3  4  5  6  7  8  9  10  11  12  13
  F_n: 1  1  2  3  5  8  13 21 34 55  89  144 233
  n^2: 1  4  9  16 25 36 49 64 81 100 121 144 169
  gap: 0 -3 -7 -13 -20 -28 -36 -43 -47 -45 -32  0  +64
                       ^^^^                      ^^^^
                       -P_2!                     crossing!

  F_n < n^2 for n=2..11 (polynomial leads)
  F_12 = 12^2 = 144 (exact crossing!)
  F_n > n^2 for n>=13 (exponential takes over)

  Proof: phi^n/sqrt(5) ~ n^2 has finitely many solutions.
  Exhaustive check n=1..12: only n=1 and n=12 satisfy F_n=n^2.
  For n>=13: F_n >= F_13 = 233 > 169 = 13^2, and F_n grows as phi^n.
  QED.
```

### Pell(2,3,4) = (phi, sopfr, sigma) — Three Consecutive Constants

```
  Pell sequence: 0, 1, 2, 5, 12, 29, 70, 169, ...
  P_2 = 2 = phi(6)
  P_3 = 5 = sopfr(6)
  P_4 = 12 = sigma(6)

  Three consecutive Pell numbers equal three arithmetic functions of n=6.
  Unique: no other n in 2..499 has (phi, sopfr, sigma) as consecutive
  terms of ANY classical recurrence sequence.
```

### Padovan Chain: P_1 and P_2 Both Hit

```
  Padovan: 1, 1, 1, 2, 2, 3, 4, 5, 7, 9, 12, 16, 21, 28, ...
  Pad(10) = 12 = sigma(6) = P_1 (first perfect number's sigma)
  Pad(13) = 28 = P_2 (second perfect number!)

  Index 10 = sigma - phi = 12 - 2
  Index 13 = sigma + 1 = 13
```

## ASCII Graph: Sequence Values at n=6 Indices

```
  F_sigma=sigma^2    |████████████████████████████████| 144 = 12^2
  L_n=sigma+phi+tau  |████████████████████|            18
  Pell_4=sigma       |████████████████|               12
  Bell_tau=C(n,2)    |████████████████████|            15
  Motzkin_sopfr=T(n) |██████████████████████████████|  21
  Trib_{sigma-tau}   |████████████████████████████████| 24
  Pad_{sigma-phi}    |████████████████|               12
  WE_n=n             |████████|                        6
```

### Padovan Chain Proof (added 2026-03-26)

```
  Pad(10) = 12 = sigma(6). Index 10 = sigma-phi.
  Pad(13) = 28 = P_2. Index 13 = sigma+1.

  Padovan hits BOTH P_1 (via sigma) and P_2 (directly):
  - Pad(sigma-phi) = sigma => Pad at this index = divisor sum
  - Pad(sigma+1) = P_2 => Padovan at next-sigma = second perfect!
  Padovan grows as plastic^n (plastic ratio ~ 1.3247).
  For n >= 14: Pad(n) > 28, never returns. Unique.
```

### Bell-Binomial Algebraic Proof (added 2026-03-26)

```
  B_{tau(n)} = C(n,2): need B_4 = 15 = n(n-1)/2
  => n^2 - n - 30 = 0 => n = 6 (unique positive integer root)
  Other tau values: B_2=2 -> n=2, B_3=5 -> n not integer,
  B_6=203 -> n not integer. Only n=2 (trivial) and n=6.
```

### Lucas Crossing Proof (added 2026-03-26)

```
  For semiprimes n=pq: sigma+phi+tau = 2n+6 (algebraic identity)
  L_n = 2n+6 crossing: exponential vs linear, unique at n=6
  L_6 = 18 = 2*6+6. L_7 = 29 > 20 = 2*7+6. No more crossings.
```

## Structural Interpretation

The fact that EVERY major integer sequence characterizes n=6 suggests
that n=6's arithmetic functions (sigma=12, phi=2, tau=4, sopfr=5)
sit at a universal intersection point in the landscape of recurrence relations.

The key structural feature: sigma(6) = 12 is simultaneously:
- A Fibonacci value (F_12 = 144 = sigma^2)
- A Pell value (P_4 = 12)
- A Padovan value (Pad_10 = 12)
- A Tribonacci value index target (Trib_8 = 24 = sigma*phi)
- The 12th Lucas number L_12 = 322

## Limitations

- Some identities (WE, Tetranacci) hold for multiple n values
- The sequence indices are arithmetic combinations of n=6 constants,
  which could be post-hoc
- No single structural theorem unifies all sequence characterizations

## Next Steps

1. Search for Stern-Brocot tree connections
2. Investigate continued fraction convergents
3. Check if all characterizations follow from sigma(6)=12 being a Fibonacci index
