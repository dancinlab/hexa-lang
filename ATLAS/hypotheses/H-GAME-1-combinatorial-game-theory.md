# H-GAME-1: Combinatorial Game Theory and Perfect Number 6

## Hypothesis

> In the divisor subtraction game, the Sprague-Grundy value of any even
> perfect number 2^(p-1)(2^p - 1) equals its 2-adic valuation p - 1.
> For n=6 (p=2), G(6) = 1. More broadly, perfect number 6 occupies a
> unique position in combinatorial game theory: it is the smallest
> N-position whose Grundy value equals 1 among perfect numbers, and the
> only perfect number where the Chomp game on its divisor poset has
> exactly tau(6) - 1 = 3 non-poison opening moves.

**Status**: Verified (green) -- arithmetic identities proven
**Golden Zone dependence**: None (pure combinatorics / number theory)

## Background

Combinatorial game theory (CGT) assigns Sprague-Grundy values to
positions in impartial games. A position with G=0 is a P-position
(previous player wins; losing for the mover). G > 0 is an N-position
(next player wins).

The **divisor subtraction game**: from position n, a player removes any
proper divisor d < n, leaving n - d. The player stuck at n=1 (no proper
divisors to remove that leave a positive position) loses.

Key question: what is G(n) for perfect numbers?

## Verified Results

### 1. Divisor Subtraction Game: G(n) = nu_2(n) for even n

The Grundy value of even n equals its 2-adic valuation (the largest
power of 2 dividing n). This is because:

- Every even n has 1 as a proper divisor, so n -> n-1 (odd) is always available.
- All odd positions are P-positions (G=0): their only proper divisors
  are odd, so subtracting gives even, which are N-positions.
- The mex calculation for even n then depends on which even positions
  are reachable, governed by the divisor structure.

| n | G(n) | nu_2(n) | Match |
|---|------|---------|-------|
| 2 | 1 | 1 | Yes |
| 4 | 2 | 2 | Yes |
| 6 | 1 | 1 | Yes |
| 8 | 3 | 3 | Yes |
| 10 | 1 | 1 | Yes |
| 12 | 2 | 2 | Yes |
| 14 | 1 | 1 | Yes |
| 16 | 4 | 4 | Yes |
| 18 | 1 | 1 | Yes |
| 20 | 2 | 2 | Yes |
| 24 | 3 | 3 | Yes |
| 28 | 2 | 2 | Yes |
| 32 | 5 | 5 | Yes |

Verified for all even n in [2, 100]: **perfect match**.

### 2. Perfect Numbers in the Divisor Game

Every even perfect number has the form 2^(p-1)(2^p - 1) where 2^p - 1
is a Mersenne prime. Therefore:

```
  G(perfect number) = nu_2(2^(p-1) * (2^p - 1))
                    = p - 1       (since 2^p - 1 is odd)
```

| Perfect Number | p | G = p-1 | Verified |
|----------------|---|---------|----------|
| 6 | 2 | 1 | Yes |
| 28 | 3 | 2 | Yes |
| 496 | 5 | 4 | (sieve confirms) |
| 8128 | 7 | 6 | (sieve confirms) |

**For n=6**: G(6) = 1 is the minimal nonzero Grundy value. First player
wins by removing 1 (leaving opponent at 5, a P-position).

### 3. Chomp on Divisor Poset of 6

The divisor poset of 6 is {1, 2, 3, 6} with divisibility ordering.
In Chomp, players remove an element and all its multiples. Taking 1
("poison") loses.

```
  Divisor Poset of 6:          Chomp Moves from {1,2,3,6}:

       6                        Remove 6 -> {1,2,3} (3 moves left)
      / \                       Remove 3 -> {1,2}   (1 move left)
     2   3                      Remove 2 -> {1,3}   (1 move left)
      \ /                       Remove 1 -> {}       LOSE (poison)
       1
```

Starting position {1,2,3,6}: **N-position** (first player wins).
Winning move: remove 6, leaving {1,2,3}. Then opponent must eventually
take poison.

The number of non-poison opening moves = tau(6) - 1 = 3.

Chomp on divisor poset of 28: also N-position (first player wins).
This generalizes: any n > 1 in Chomp is an N-position (known result
by Zermelo/strategy-stealing argument).

### 4. Wythoff's Game: Incidental Connection

Wythoff losing positions: (a_n, b_n) = (floor(n*phi), floor(n*phi^2)).

For n=6: (a_6, b_6) = (9, 15).

```
  a_6 + b_6 = 24 = sigma(6) * phi_euler(6) = 12 * 2
  b_6 - a_6 = 6  = n  (this is a general Wythoff property, b_n - a_n = n)
```

The sum a_6 + b_6 = 24 = sigma*phi(6) is a coincidence specific to n=6.
For n=28: a_28 + b_28 = 45 + 73 = 118, while sigma(28)*phi(28) = 672.
**No general pattern**. The Wythoff connection is spurious.

### 5. Grundy Value Pattern (ASCII Visualization)

```
  G(n) for n=1..32:

  n:  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16
  G:  0  1  0  2  0  1  0  3  0  1  0  2  0  1  0  4
      |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
      .  #  .  ## .  #  . ###  .  #  .  ## .  #  . ####

  n: 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32
  G:  0  1  0  2  0  1  0  3  0  1  0  2  0  1  0  5
      .  #  .  ## .  #  . ###  .  #  .  ## .  #  . #####

  Pattern: G(n) = nu_2(n) = ruler sequence (OEIS A007814)
  Perfect numbers marked: G(6)=1, G(28)=2

  Frequency of G values in [1,100]:
    G=0: ################################################## 50 (odd)
    G=1: #########################                          25
    G=2: ############                                       12
    G=3: ######                                              6
    G=4: ###                                                 3
    G=5: ##                                                  2
    G=6: #                                                   1
```

The Grundy values follow the **ruler sequence** (binary carry sequence),
identical to 2-adic valuation. This is OEIS A007814.

## Interpretation

1. **G(6) = 1 is minimal among perfect numbers**: n=6 has the simplest
   game-theoretic structure. One move suffices to reach a P-position.

2. **The Grundy value of perfect numbers grows as p-1**: The game
   complexity of perfect numbers grows with the Mersenne exponent.
   This is a direct consequence of their 2-adic structure, not a
   deep connection.

3. **Chomp on 6's divisor poset is the smallest nontrivial case**:
   With tau(6)=4 elements, the poset has exactly 3 opening moves.
   This is the smallest interesting Chomp position on a divisor lattice.

4. **No deep CGT-specific insight**: The game-theoretic properties of 6
   follow from it being even (N-position) and having nu_2(6)=1. The
   results are consequences of standard number theory, not new CGT
   phenomena.

## Limitations

- G(n) = nu_2(n) for even n is likely known but I have not found a
  specific literature reference. It may be folklore.
- The Wythoff sum coincidence (a_6+b_6=24=sigma*phi) is n=6-specific
  and does not generalize. Likely spurious.
- Chomp first-player-wins is known for all n > 1 by strategy-stealing,
  so this is not special to perfect numbers.

## Next Steps

- Search literature for G(n)=nu_2(n) proof in divisor subtraction game.
- Investigate whether Nim-sum of Grundy values across perfect number
  decompositions yields interesting structure.
- Examine divisor games on multiplicative lattices (not just subtract,
  but divide) for perfect numbers.
