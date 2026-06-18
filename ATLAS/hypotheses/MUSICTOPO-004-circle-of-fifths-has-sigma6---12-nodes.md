# MUSICTOPO-004: Circle of Fifths has sigma(6) = 12 Nodes

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> The circle of fifths arranges 12 pitch classes by successive perfect fifth intervals (7 semitones). Since gcd(7, 12) = 1, this generates all 12 = sigma(6) pitch classes, forming an alternative circular ordering of Z_12.

## Background

The circle of fifths orders pitch classes by perfect fifth intervals:
C-G-D-A-E-B-F#-C#-G#-D#-A#-F-C. It is the fundamental organizing
principle of Western tonal harmony.

## Verification

```
  Fifth interval: 7 semitones
  gcd(7, 12) = 1  => 7 generates Z_12
  Circle of fifths visits all 12 = sigma(6) nodes  EXACT

  Sequence: C(0)-G(7)-D(2)-A(9)-E(4)-B(11)-F#(6)-
            C#(1)-G#(8)-D#(3)-A#(10)-F(5)-C(0)
  All 12 pitch classes appear exactly once.
```

## ASCII Circle of Fifths

```
          C
      F       G
    Bb          D
    Eb           A
    Ab          E
      Db      B
         F#/Gb

  Clockwise = ascending fifths (+7 mod 12)
  Counterclockwise = ascending fourths (+5 mod 12)
```

## Number Theory

```
  Generators of Z_12: {1, 5, 7, 11}
  |generators| = phi(12) = 4 = tau(6)  EXACT

  The four generators correspond to:
    1 = semitone (chromatic)
    5 = fourth (circle of fourths)
    7 = fifth (circle of fifths)
   11 = semitone descending
```

## Interpretation

The number of generators of Z_{sigma(6)} equals phi(12) = 4 = tau(6).
The circle of fifths is one of tau(6) possible generating circles,
connecting the diatonic cycle to both sigma(6) and tau(6).
