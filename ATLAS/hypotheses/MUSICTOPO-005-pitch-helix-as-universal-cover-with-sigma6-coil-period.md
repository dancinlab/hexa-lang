# MUSICTOPO-005: Pitch Helix as Universal Cover with sigma(6) Coil Period

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> The pitch helix is the universal covering space of the pitch class circle S^1. Each coil of the helix spans one octave = 12 = sigma(6) semitones, and the covering map projects the helix onto S^1 with fiber Z (the integers labeling octaves).

## Background

While pitch classes live on S^1, actual pitches (with octave information)
live on the helix: the universal cover of S^1, which is R (the real line)
wrapped into a spiral.

## Topological Verification

```
  Base space: S^1 (pitch class circle)
  Universal cover: R (real line = pitch helix unwound)
  Covering map: p: R -> S^1, p(x) = x mod 12
  Fiber: Z (octave labels)
  Deck transformations: x -> x + 12k, k in Z

  Coil period: 12 semitones = sigma(6)  EXACT
  Fundamental group: pi_1(S^1) = Z (integer octave shifts)
```

## ASCII Pitch Helix

```
        C5---
       / B4
      /  A#4
     /   A4          Helix (universal cover of S^1)
    /    G#4
   C4    G4          Each coil = 12 = sigma(6) semitones
    \    F#4
     \   F4
      \  E4
       \ D#4
        C4--D4
       /
      C3---
```

## Covering Space Data

| Property | Value | n=6 Link |
|----------|-------|----------|
| Coil period | 12 | sigma(6) |
| Deck group | Z | pi_1(S^1) |
| Sheets per point | countably inf | Z |
| Base space dim | 1 | -- |
| Fiber | Z | integers |

## Interpretation

The pitch helix realizes the universal cover of S^1 with period sigma(6) = 12.
Every octave shift is a deck transformation, and the entire structure
is governed by the covering space theory of the circle with Z_{sigma(6)} action.
