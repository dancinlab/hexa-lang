# Hypothesis MUSIC-014: Circle of Fifths = sigma(6) = 12 Keys

**Grade: 🟩 EXACT**

## Hypothesis

> The circle of fifths contains exactly 12 = sigma(6) keys before returning
> to the starting pitch class.

## Background

The circle of fifths is a fundamental organizing principle of Western
music theory. Starting from any note and ascending by perfect fifths
(7 semitones each), one passes through all 12 pitch classes before
returning to the start: 12 * 7 = 84 semitones = 7 octaves.

## Numerical Verification

| Quantity               | Value | n=6 Function | Match |
|------------------------|-------|-------------- |-------|
| Keys in circle         |  12   | sigma(6)=12  | EXACT |
| Octaves traversed      |   7   | P1+1=7       | EXACT |
| Semitones per fifth    |   7   | P1+1=7       | EXACT |
| Total semitones        |  84   | 7*sigma(6)   | EXACT |

## ASCII Diagram

```
          C
       F     G         12 = sigma(6) keys
     Bb        D        7 = P1+1 semitones per step
    Eb          A        7 = P1+1 octaves to close
     Ab        E
       Db    B
          F#
```

## Interpretation

The circle of fifths' 12-key structure is sigma(6). The step size
(perfect fifth = 7 semitones) and closure octave count (7) both
equal P1+1, though this involves a +1 correction.

## Limitations

- 7 = P1+1 uses a +1 correction — ad hoc risk.


## Grade: 🟩 EXACT

Golden Zone dependency: None (pure music theory observation).
