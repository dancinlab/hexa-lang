# H-409: Game Theory and Social Choice Theory for n=6
**n6 Grade: 🟩 EXACT** (auto-graded, 7 unique n=6 constants)


## Hypothesis

> In the weighted voting game [n; divisors(n)] with quota = n, the Shapley-Shubik
> power indices follow an exact formula determined solely by tau(n) (the divisor count):
> Shapley(largest divisor = n) = (tau-1)/tau,
> Shapley(any other divisor) = 1/(tau*(tau-1)).
> For perfect number n=6, the additional identity 1/(tau*(tau-1)) = 1/sigma(n) holds
> because sigma(6) = tau(6)*(tau(6)-1) = 4*3 = 12.

## Background

This hypothesis explores whether game-theoretic voting structures built from
divisors of n=6 produce clean formulas expressible via the arithmetic functions
sigma, phi, tau, sopfr.

The divisors of 6 are {1, 2, 3, 6} with sigma(6)=12, tau(6)=4, phi(6)=2, sopfr(6)=5.

The weighted voting game [quota; w1, w2, ..., wk] has:
- Shapley-Shubik index: proportion of permutations where player is pivotal
- Banzhaf index: proportion of coalitions where player is a swing voter

Related: H-090 (perfect number 6 master formula), H-407 (Galois theory for n=6).

## Verified Results (python3, exact arithmetic with Fraction)

### Item 1: Nash Equilibria Count

```
E[mixed NE in n×n random game] ~ sqrt(pi*n/2)
At n=6: sqrt(3*pi) = 3.0700
sigma(6)/tau(6) = 12/4 = 3 (exact integer)
Difference: 2.33%

Simulation (10,000 random games, pure NE):
  Actual E[pure NE] ~ 1.0 for all n (not sqrt(pi*n/2))
  sqrt(pi*n/2) applies to MIXED strategy NE count
```

Generalization check (perfect numbers):

| n   | sqrt(pi*n/2) | sigma/tau | diff   |
|-----|-------------|-----------|--------|
| 6   | 3.0700      | 3.0000    | 2.33%  |
| 28  | 6.6319      | 9.3333    | 28.94% |
| 496 | 27.9126     | 99.2000   | 71.86% |

The near-match at n=6 is because n=6 ~ 2*pi (4.7% off).
Does NOT generalize. Grade: WHITE (coincidence)

### Item 2 & 7: Shapley and Banzhaf at quota = sigma(n)

Game: [12; 1, 2, 3, 6]

| Player | Weight | Shapley | Banzhaf |
|--------|--------|---------|---------|
| 1      | 1      | 1/4     | 1/4     |
| 2      | 2      | 1/4     | 1/4     |
| 3      | 3      | 1/4     | 1/4     |
| 4      | 6      | 1/4     | 1/4     |

All equal = 1/4 = 1/tau(6). Forced structure:
at quota = total_weight, only the grand coalition wins,
so every player is critical in exactly 1 coalition.
Proof: Shapley = (tau-1)!/tau! = 1/tau by symmetry.
Grade: GREEN (exact, but trivially forced)

### Item 2 MAIN: Shapley at quota = n = 6 (KEY FINDING)

Game: [6; 1, 2, 3, 6] and equivalently [7; 1, 2, 3, 6]

| Player | Weight | Swings | Shapley |  Decimal |
|--------|--------|--------|---------|----------|
| 1      | 1      |  2/24  | 1/12    | 0.083333 |
| 2      | 2      |  2/24  | 1/12    | 0.083333 |
| 3      | 3      |  2/24  | 1/12    | 0.083333 |
| 4      | 6      | 18/24  | 3/4     | 0.750000 |

```
Connections:
  Shapley(w=6) = 3/4 = (tau-1)/tau = 3/4
  Shapley(w=1) = 1/12 = 1/sigma(6) = 1/(tau*(tau-1))
  Note: sigma(6) = tau*(tau-1) = 12 is a coincidence specific to n=6
```

Generalization to n=28 (tau=6):

| Player | Weight | Shapley |  Decimal |
|--------|--------|---------|----------|
| 1      | 1      | 1/30    | 0.033333 |
| 2      | 2      | 1/30    | 0.033333 |
| 4      | 4      | 1/30    | 0.033333 |
| 7      | 7      | 1/30    | 0.033333 |
| 14     | 14     | 1/30    | 0.033333 |
| 28     | 28     | 5/6     | 0.833333 |

```
tau(28)=6: Shapley(w=28) = 5/6 = (tau-1)/tau CONFIRMED
tau(28)=6: Shapley(small) = 1/30 = 1/(tau*(tau-1)) CONFIRMED
sigma(28)=56 != 30, so 1/sigma connection breaks for n=28
```

Grade: GREEN (exact, generalizes)

### Item 4: Sprague-Grundy / Wythoff at (phi(6), sigma/tau(6)) = (2,3)

```
Wythoff's game Grundy values:
  P-positions (Grundy=0): (0,0), (1,2), (3,5), (4,7), ...
  Position (2,3): Grundy = 5 = sopfr(6) = 2+3
  2 XOR 3 = 1 (Nim value)
```

Is Grundy(2,3)=5 significant? Check how common Grundy(a,b)=a+b is:

```
Positions where Grundy(a,b) = a+b (up to 10x10):
  (0,k) for all k: Grundy(0,k)=k trivially (one pile game)
  (1,3): Grundy=4, (1,4): Grundy=5, (2,3): Grundy=5, ...
  Total: 22 out of ~66 non-trivial positions (33%)
```

Wythoff P-positions (Grundy=0): only (floor(k*phi_golden), floor(k*phi_golden^2))

```
Position (2,3) is between P-positions:
  k=1: (1,2) - P-position
  k=2: (3,5) - P-position
  (2,3) is an N-position (first player wins), Grundy=5
```

Grade: WHITE (sopfr=a+b is trivial, Grundy=a+b not specific)

Confirmed strong: XOR(divisors(6)) = 6 = n
Only n=1 and n=6 have this property up to 200 (also n=120, n=198 found up to 200).
Numbers with XOR(divs)=n up to 200: {1, 6, 120, 198}

### Item 7: Banzhaf at quota = n = 6

Game: [6; 1, 2, 3, 6]

| Player | Weight | Swings | Normalized |
|--------|--------|--------|------------|
| 1      | 1      | 1      | 1/10       |
| 2      | 2      | 1      | 1/10       |
| 3      | 3      | 1      | 1/10       |
| 4      | 6      | 7      | 7/10       |

```
Banzhaf(w=6) = 7/10 -- no clean n=6 constant connection
Ratio = 7:1 (vs phi=2, tau=4, etc.) -- no match
```

Grade: WHITE (no n=6 constant match)

## ASCII Graph: Shapley Power Distribution

```
Game [6; 1,2,3,6]  vs  Game [12; 1,2,3,6]
quota = n               quota = sigma

Shapley:                Shapley:
1.0 |                   1.0 |
0.8 |       [###]       0.8 |
0.6 |       [###]       0.6 |
0.4 |       [###]       0.4 |       [###]   <- equal = 1/tau
0.2 |       [###]       0.2 |       [###]
0.0 +--+--+--+--+       0.0 +--+--+--+--+
     1  2  3  6              1  2  3  6
    (w=1,2,3 too small)     (uniform by symmetry)

     w=6 dominates: 3/4
     w=1=w=2=w=3: 1/12 each
```

## Main Theorem (Exact, Provable)

**Theorem**: In the weighted voting game G = [n; d_1, d_2, ..., d_tau] where
{d_i} = divisors(n) and quota = n (for a perfect number n), the Shapley-Shubik
power indices are:

```
  Shapley(d_tau = n)  = (tau - 1) / tau
  Shapley(d_i < n)    = 1 / (tau * (tau - 1))    for all i < tau
```

Verification table:

| n   | tau | Shapley(n) | Formula (tau-1)/tau | Shapley(small) | Formula 1/(tau*(tau-1)) |
|-----|-----|------------|---------------------|----------------|------------------------|
| 6   | 4   | 3/4        | 3/4 = 0.75 EXACT    | 1/12           | 1/12 EXACT             |
| 28  | 6   | 5/6        | 5/6 = 0.833 EXACT   | 1/30           | 1/30 EXACT             |

**n=6 special case**: sigma(6) = tau*(tau-1) = 12, so Shapley(small) = 1/sigma(6).
This is a coincidental identity unique to n=6 since sigma(28)=56 != 30=tau*(tau-1).

## Why the Formula Holds

The game [n; divs(n)] with quota=n has a special structure for perfect numbers:
- Player w=n alone can win (n >= quota n)
- The coalition {all proper divisors} also wins (their sum = n by perfectness)
- This creates a symmetric role for the tau-1 small players

In any permutation, the player w=n is pivotal unless it appears after all tau-1
small players have been placed (in which case the last small player is the pivot
when the cumulative sum crosses n). The probability structure gives exactly
Shapley(large) = (tau-1)/tau.

## Connections to n=6 Structure

```
  Shapley(w=6) = 3/4 = (tau-1)/tau = 3/4
  Shapley(w=1) = 1/12 = 1/sigma(6) = 1/(tau*(tau-1))

  sigma(6) = tau(6)*(tau(6)-1) = 12: unique n=6 identity
  => Shapley connects to BOTH sigma and tau via this identity

  Connection path: divisors -> voting game -> Shapley -> sigma/tau
  This is a Golden Zone-independent pure math connection
```

## Limitations

- Theorem only verified for n=6 and n=28 (two data points for generalization)
- Quota = n may not be the most natural choice (quota = sigma/2 = 6 is another option)
- The Banzhaf index at quota=n shows no clean constant connection (7/10 at n=6)
- Nash equilibria connection (item 1) fails to generalize beyond n=6

## Verification Direction

1. Prove the Shapley formula analytically for all perfect numbers
2. Check if the formula holds for imperfect numbers with specific divisor structures
3. Find if any other voting-game quota gives cleaner n=6 connections
4. Submit to combinatorics/game theory literature if analytical proof found

## Status

- Computation: Exact (python3, Fraction arithmetic)
- Generalization: Verified for n=6 and n=28
- Proof: Partially sketched, needs formal writeup
- Grade: GREEN for Shapley theorem, WHITE for Nash/Wythoff items
- Golden Zone dependency: INDEPENDENT (pure combinatorics/number theory)
