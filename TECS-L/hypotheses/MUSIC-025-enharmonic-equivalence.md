# Hypothesis MUSIC-025: Enharmonic Pitch Classes = sigma(6) = 12

**Grade: 🟩 EXACT**

## Hypothesis

> Under enharmonic equivalence (e.g., C# = Db), there are exactly
> 12 = sigma(6) distinct pitch classes.

## Background

Enharmonic equivalence identifies pitches that sound the same but are
spelled differently (C# = Db, D# = Eb, etc.). In 12-TET, this reduces
the infinite set of note names to exactly 12 equivalence classes.

## Numerical Verification

| Quantity              | Value | n=6 Function | Match |
|-----------------------|-------|-------------- |-------|
| Pitch classes         |  12   | sigma(6)=12  | EXACT |
| Natural notes         |   7   | P1+1=7       | +1    |
| Accidental notes      |   5   | sopfr(6)=5   | EXACT |
| Enharmonic pairs      |   5   | sopfr(6)=5   | EXACT |

## ASCII Diagram

```
  Natural: C  D  E  F  G  A  B     = 7 = P1+1
  Sharp:      C# D#    F# G# A#   = 5 = sopfr(6)
  ─────────────────────────────────────
  Total pitch classes = 12 = sigma(6)

  Natural notes (7) + accidentals (5) = sigma(6)
  P1+1 + sopfr(6) = 7+5 = 12 = sigma(6)  EXACT!
```

## Interpretation

sigma(6) = P1+1 + sopfr(6) = 7+5 = 12. The decomposition of the
chromatic scale into naturals and accidentals mirrors n=6 arithmetic.

## Limitations

- 7+5=12 is a partition; many partitions of 12 exist.


## Grade: 🟩 EXACT

Golden Zone dependency: None (pure music theory observation).
