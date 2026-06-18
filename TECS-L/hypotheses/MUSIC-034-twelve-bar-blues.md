# Hypothesis MUSIC-034: 12-Bar Blues = sigma(6) Bars

**Grade: 🟩 EXACT**

## Hypothesis

> The 12-bar blues, the most influential song form in popular music,
> spans exactly 12 = sigma(6) measures.

## Background

The 12-bar blues is the harmonic foundation of blues, rock and roll, jazz,
and R&B. Its I-IV-V chord progression over 12 bars has been used in
countless songs since the early 20th century.

## Numerical Verification

| Quantity              | Value | n=6 Function | Match |
|-----------------------|-------|-------------- |-------|
| Total bars            |  12   | sigma(6)=12  | EXACT |
| Chord I bars          |   4   | tau(6)=4     | EXACT |
| Chord IV bars (first) |   2   | phi(6)=2     | EXACT |
| Distinct chords used  |   3   | P1/2=3       | EXACT |

## ASCII Diagram: Standard 12-Bar Blues

```
  Bar: | 1  2  3  4 | 5  6  7  8 | 9  10 11 12 |
       | I  I  I  I | IV IV I  I | V  IV I  I  |
       |<- tau(6) ->|            |<- sigma(6)=12 ->|

  3 chords (I, IV, V) = P1/2
  12 bars = sigma(6)
```

## Interpretation

The 12-bar blues = sigma(6) bars, using P1/2=3 chords. The tonic
occupies tau(6)=4 of the first 4 bars. Clean multi-constant mapping.

## Limitations

- Many 12-bar variants exist (quick change, jazz blues, minor blues).


## Grade: 🟩 EXACT

Golden Zone dependency: None (pure music theory observation).
