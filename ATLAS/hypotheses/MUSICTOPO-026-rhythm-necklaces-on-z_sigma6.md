# MUSICTOPO-026: Rhythm Necklaces on Z_sigma(6)

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> Rhythm necklaces (equivalence classes of rhythmic patterns under rotation) on Z_12 = Z_{sigma(6)} are counted by the necklace formula. The number of binary necklaces of length 12 is (1/12)*sum_{d|12} phi(d)*2^{12/d} = 352.

## Background

A rhythm necklace of length n is a binary string of length n considered
up to cyclic rotation. This counts distinct rhythmic patterns in a cycle
of n beats.

## Computation

```
  Necklace count N(n, k=2) = (1/n) * sum_{d|n} phi(d) * 2^{n/d}

  For n = 12 = sigma(6):
    Divisors of 12: {1, 2, 3, 4, 6, 12}
    Number of divisors: 6 = P1  EXACT

    d=1:  phi(1)  * 2^12 = 1  * 4096 = 4096
    d=2:  phi(2)  * 2^6  = 1  * 64   = 64
    d=3:  phi(3)  * 2^4  = 2  * 16   = 32
    d=4:  phi(4)  * 2^3  = 2  * 8    = 16
    d=6:  phi(6)  * 2^2  = 2  * 4    = 8
    d=12: phi(12) * 2^1  = 4  * 2    = 8
    Sum = 4224
    N(12,2) = 4224 / 12 = 352
```

## ASCII Necklace Example

```
  Pattern: x . x . x . . x . x . .   (5 onsets in 12 beats)

  Rotation equivalence:
  x . x . x . . x . x . .
  . x . x . . x . x . . x   <- same necklace
  x . x . . x . x . . x .   <- same necklace

  All rotations = same rhythm (different starting beat)
```

## Divisor Connection

| Divisor d of 12 | phi(d) | 2^{12/d} | Contribution |
|-----------------|--------|----------|-------------|
| 1 | 1 | 4096 | 4096 |
| 2 | 1 | 64 | 64 |
| 3 | 2 | 16 | 32 |
| 4 | 2 | 8 | 16 |
| 6 | 2 | 4 | 8 |
| 12 | 4 | 2 | 8 |
| **Sum** | | | **4224** |

Total necklaces: 4224/12 = 352. The sum uses all P1 = 6 divisors of sigma(6) = 12.

## Interpretation

Computing rhythm necklaces on Z_{sigma(6)} requires summing over all P1 = 6
divisors of 12. The necklace formula directly invokes the divisor structure
of sigma(6), making n=6 the arithmetic engine behind rhythmic enumeration.
