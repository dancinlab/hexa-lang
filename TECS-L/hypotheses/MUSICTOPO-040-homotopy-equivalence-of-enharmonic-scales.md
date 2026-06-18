# MUSICTOPO-040: Homotopy Equivalence of Enharmonic Scales

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> Enharmonically equivalent scales (e.g., F# major and Gb major) are the same point in pitch-class space Z_12, hence trivially homotopy equivalent. The enharmonic identification quotients the 7 sharps and 7 flats to give sigma(6) = 12 distinct classes.

## Background

In equal temperament, enharmonic equivalence identifies notes like F# = Gb.
This is the fundamental quotient that reduces the theoretically infinite
spiral of fifths to the closed circle of fifths.

## Verification

```
  Without enharmonic equivalence:
    Spiral of fifths: ..., Dbb, Abb, Ebb, Bb, F, C, G, D, A, E, B, F#, C#, ...
    Infinite in both directions

  With enharmonic equivalence (equal temperament):
    Circle of fifths: C, G, D, A, E, B=Cb, F#=Gb, C#=Db, Ab, Eb, Bb, F
    Exactly 12 = sigma(6) classes  EXACT

  Quotient map: R (spiral) -> S^1 (circle), period 12
```

## ASCII Enharmonic Identification

```
  Spiral of fifths (no enharmonic equiv):

  ...--Fb--Cb--Gb--Db--Ab--Eb--Bb--F--C--G--D--A--E--B--F#--C#--G#--...
                    |                                           |
                    |<------------ 12 = sigma(6) fifths ------->|
                    |                                           |
                    Db =============================== C# (identified!)

  After identification: circle of 12 = sigma(6) notes
```

## Key Signatures

```
  Sharps: 0(C), 1(G), 2(D), 3(A), 4(E), 5(B), 6(F#), 7(C#)
  Flats:  0(C), 1(F), 2(Bb), 3(Eb), 4(Ab), 5(Db), 6(Gb), 7(Cb)
  Overlaps: B=Cb, F#=Gb, C#=Db (and enharmonic equivalents)
  Distinct keys: 12 = sigma(6)
  Enharmonic pairs: 3 = P1/2
```

## Interpretation

Enharmonic equivalence is the topological quotient that closes the spiral of
fifths into a circle of sigma(6) = 12 elements, with P1/2 = 3 enharmonic pairs.
