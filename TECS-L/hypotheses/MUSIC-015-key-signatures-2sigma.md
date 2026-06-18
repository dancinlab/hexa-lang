# Hypothesis MUSIC-015: Key Signatures = 2*sigma(6) = 24

**Grade: 🟩 EXACT**

## Hypothesis

> There are exactly 24 = 2*sigma(6) distinct key signatures in Western
> music: 12 major keys + 12 minor keys (relative major/minor pairs).

## Background

Each of the 12 pitch classes can serve as the tonic of a major or minor
key, giving 24 total key signatures. Major and minor keys sharing the
same key signature are called "relative" keys.

## Numerical Verification

| Quantity          | Value | n=6 Expression | Match |
|-------------------|-------|--------------- |-------|
| Major keys        |  12   | sigma(6)       | EXACT |
| Minor keys        |  12   | sigma(6)       | EXACT |
| Total keys        |  24   | 2*sigma(6)     | EXACT |
| Relative pairs    |  12   | sigma(6)       | EXACT |
| Max sharps/flats  |   6   | P1=6           | EXACT |

## ASCII Diagram: Key Signature Counts

```
  Sharps: 0  1  2  3  4  5  6
  Major:  C  G  D  A  E  B  F#
  Minor:  a  e  b  f# c# g# d#

  Flats:  0  1  2  3  4  5  6
  Major:  C  F  Bb Eb Ab Db Gb
  Minor:  a  d  g  c  f  bb eb

  Max accidentals = 6 = P1 (in either direction)
```

## Interpretation

24 = 2*sigma(6) keys, with maximum 6 = P1 sharps or flats. The number
P1 appears as both the maximum accidental count and the organizing constant.

## Limitations

- 24 = 2*12 is a simple doubling; the deeper fact is 12 = sigma(6).


## Grade: 🟩 EXACT

Golden Zone dependency: None (pure music theory observation).
