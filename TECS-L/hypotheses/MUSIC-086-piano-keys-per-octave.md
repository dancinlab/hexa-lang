# Hypothesis MUSIC-086: Piano Keys Per Octave: sigma(6) = 12

**Grade: 🟩 EXACT**

## Hypothesis

> Each octave on the piano keyboard contains 12 = sigma(6) keys:
> 7 = P1+1 white keys and 5 = sopfr(6) black keys.

## Background

The piano keyboard physically embodies the chromatic scale, with
white keys for natural notes and black keys for accidentals.

## Numerical Verification

| Key Type | Count | n=6 Function | Match |
|---------|-------|-------------- |-------|
| White    |   7   | P1+1=7       | +1    |
| Black    |   5   | sopfr(6)=5   | EXACT |
| Total    |  12   | sigma(6)=12  | EXACT |

## ASCII Diagram

```
     Db  Eb      Gb  Ab  Bb
      |   |       |   |   |       5 black = sopfr(6)
  | C | D | E | F | G | A | B |   7 white = P1+1
  |   |   |   |   |   |   |   |
  |<--------- 12 = sigma(6) -------->|
```

## Interpretation

sigma(6) = sopfr(6) + (P1+1) = 5 + 7 = 12. Same as MUSIC-025.

## Limitations

- Standard 88-key piano has 88 = 7*12+4, not cleanly related to n=6.


## Grade: 🟩 EXACT

Golden Zone dependency: None (pure music theory observation).
