# MUSICTOPO-046: Fundamental Group pi_1 of Pitch Space = Z

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> The fundamental group of pitch-class space S^1 is pi_1(S^1) = Z, the integers. Each generator corresponds to one octave traversal of 12 = sigma(6) semitones. The universal cover R -> S^1 is the pitch helix with fiber Z.

## Background

The fundamental group pi_1(X) classifies loops in X up to homotopy.
For the circle S^1, every loop is characterized by its winding number
(how many times it goes around).

## Verification

```
  pi_1(S^1) = Z

  Musical interpretation:
    Generator +1: ascending octave (12 = sigma(6) semitones up)
    Generator -1: descending octave (12 semitones down)
    Element n: n octaves up (n * sigma(6) semitones)

  Covering space: p: R -> S^1
    p(x) = x mod 12
    Fiber over any point: Z (all octave copies)
    Deck transformations: x -> x + 12k
```

## ASCII Fundamental Group

```
  Loops in S^1:

  Winding 0:    Winding +1:     Winding +2:
  *-->--*       *-->-->-->*     *-->-->-->-->-->-->*
  |     |       (one full       (two full
  *--<--*        loop)           loops)

  pi_1 = Z = {..., -2, -1, 0, +1, +2, ...}
  Each unit = one octave = sigma(6) semitones
```

## Homotopy Data

| Loop | Winding | Semitones | n=6 Link |
|------|---------|-----------|----------|
| Trivial | 0 | 0 | identity |
| One octave up | +1 | 12 | sigma(6) |
| One octave down | -1 | -12 | -sigma(6) |
| Two octaves | +2 | 24 | 2*sigma(6) |
| n octaves | n | 12n | n*sigma(6) |

## Interpretation

pi_1(S^1) = Z is one of the most fundamental results in algebraic topology,
and in music it simply counts octaves. Each generator represents sigma(6) = 12
semitones, making the fundamental group a direct encoding of the divisor sum of 6.
