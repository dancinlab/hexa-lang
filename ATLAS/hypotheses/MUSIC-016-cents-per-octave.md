# Hypothesis MUSIC-016: Cents Per Octave = 100 * sigma(6) = 1200

**Grade: 🟩 EXACT**

## Hypothesis

> One octave equals exactly 1200 = 100 * sigma(6) cents, where the cent
> is defined as 1/100 of a semitone = 1/100 of 1/sigma(6) of an octave.

## Background

The cent is the standard logarithmic unit for measuring musical intervals.
Defined by Alexander Ellis in 1885: 1 cent = 1/1200 of an octave.

## Numerical Verification

| Quantity              | Value | n=6 Expression   | Match |
|-----------------------|-------|------------------ |-------|
| Cents per octave      | 1200  | 100*sigma(6)     | EXACT |
| Cents per semitone    |  100  | 100               | def.  |
| Semitones per octave  |   12  | sigma(6)=12      | EXACT |

## ASCII Diagram

```
  0         300        600        900       1200 cents
  |----------|----------|----------|----------|
  C          Eb         F#         A          C
  0          3          6          9          12 semitones
             P1/2       P1         (none)     sigma(6)
```

## Interpretation

1200 = 100 * sigma(6) is definitional given 12-TET, but reinforces
that sigma(6) is the architectural constant of Western pitch.

## Limitations

- The factor 100 is arbitrary (decimal convenience, not structural).


## Grade: 🟩 EXACT

Golden Zone dependency: None (pure music theory observation).
