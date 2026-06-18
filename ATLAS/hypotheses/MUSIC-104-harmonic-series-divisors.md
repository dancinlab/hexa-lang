# Hypothesis MUSIC-104: First 6 Harmonics Use Divisors and Functions of 6

**Grade: 🟩 EXACT**

## Hypothesis

> The first 6 = P1 harmonics of a vibrating string produce frequencies
> at multiples 1 through 6, which ARE the first perfect number's range.

## Background

The harmonic series (f, 2f, 3f, 4f, 5f, 6f, ...) is the physical
basis of musical consonance. The first 6 harmonics define the most
consonant intervals.

## Numerical Verification

| Harmonic | Freq  | Interval from fundamental | In div(6)? |
|---------|-------|--------------------------|-----------|
| 1       | f     | Unison                   | YES (1)   |
| 2       | 2f    | Octave                   | YES (2)   |
| 3       | 3f    | Octave + P5              | YES (3)   |
| 4       | 4f    | 2 Octaves                | NO (but tau(6)) |
| 5       | 5f    | 2 Oct + M3               | NO (but sopfr(6)) |
| 6       | 6f    | 2 Oct + P5               | YES (6)   |

First P1=6 harmonics. Harmonics {1,2,3,6} = div(6) are pure octaves/fifths.

## ASCII Diagram

```
  Harmonic series:
  1f ───── fundamental (unison)        d(6)
  2f ───── octave                      d(6)
  3f ───── octave + fifth              d(6)
  4f ───── 2 octaves                   tau(6)
  5f ───── 2 oct + major third         sopfr(6)
  6f ───── 2 octaves + fifth           d(6) = P1

  Consonance decreases as we move beyond div(6).
```

## Interpretation

The first P1=6 harmonics establish all basic consonant intervals.
Harmonics at div(6) positions give the purest intervals (octaves, fifths).
The "new" intervals enter at tau(6)=4 and sopfr(6)=5.

## Limitations

- The harmonic series is infinite; stopping at 6 is a choice.


## Grade: 🟩 EXACT

Golden Zone dependency: None (pure music theory observation).
