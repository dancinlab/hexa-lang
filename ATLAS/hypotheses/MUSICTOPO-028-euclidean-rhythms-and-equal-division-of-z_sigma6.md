# MUSICTOPO-028: Euclidean Rhythms and Equal Division of Z_sigma(6)

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> Euclidean rhythms distribute k onsets as evenly as possible among n = 12 = sigma(6) beats using the Euclidean algorithm. Many traditional world rhythms are Euclidean rhythms on Z_12, with onset counts related to divisors of 12.

## Background

Toussaint (2005) showed that the Euclidean algorithm, when applied to
distributing k onsets in n beats, generates rhythms found in many
musical traditions worldwide.

## Verification

```
  E(k, 12) = Euclidean rhythm with k onsets in 12 = sigma(6) beats

  E(2, 12) = [x . . . . . x . . . . .]   half notes
  E(3, 12) = [x . . . x . . . x . . .]   dotted quarter = shuffle
  E(4, 12) = [x . . x . . x . . x . .]   dotted eighth pattern
  E(6, 12) = [x . x . x . x . x . x .]   eighth notes in 6/8

  Special cases using divisors of 12:
    k=1:  trivial
    k=2:  period 6 = P1
    k=3:  period 4 = tau(6)
    k=4:  period 3 = P1/2
    k=6:  period 2 = phi(6)
    k=12: all beats
```

## ASCII Euclidean Rhythms

```
  E(3,12):  x . . . x . . . x . . .     Cuban tresillo variant
  E(4,12):  x . . x . . x . . x . .     Afro-Cuban 12/8
  E(5,12):  x . x . x . . x . x . .     Bossa nova variant

  Beat:  0  1  2  3  4  5  6  7  8  9 10 11
  E(3):  X           X           X
  E(4):  X        X        X        X
  E(6):  X     X     X     X     X     X
```

## Period Table

| k onsets | Period = 12/gcd(k,12) | gcd(k,12) | n=6 Link |
|----------|----------------------|-----------|----------|
| 2 | 6 | 2 | P1 |
| 3 | 4 | 3 | tau(6) |
| 4 | 3 | 4 | P1/2 |
| 6 | 2 | 6 | phi(6) |

## Interpretation

Euclidean rhythms on Z_{sigma(6)} = Z_12 have periods that are divisors
of 12. These periods {2, 3, 4, 6} = {phi(6), P1/2, tau(6), P1} are
exactly the nontrivial n=6 constants, making every Euclidean rhythm
a realization of n=6 arithmetic.
