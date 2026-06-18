# MUSICTOPO-023: Homology of Pitch-Class Set Complexes

**Domain**: Topology of Music | **Grade**: 🟧 WEAK
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> The simplicial complex formed by pitch-class sets under inclusion has homology groups reflecting musical structure. For the complex of all subsets of Z_12 = Z_{sigma(6)}, the total number of nonempty subsets is 2^12 - 1 = 4095.

## Background

Treating pitch-class sets as simplices (a chord with n notes is an
(n-1)-simplex), one can build simplicial complexes and compute their
homology, revealing topological structure of musical collections.

## Computation

```
  Full power set complex on Z_12:
    Vertices: 12 = sigma(6)
    Total subsets: 2^12 = 4096
    Nonempty: 4095
    This is the full simplex Delta^11 (contractible)

  More interesting: consonance complex
    Vertices: 12 pitch classes
    Simplices: consonant subsets (e.g., subsets of diatonic scales)
```

## ASCII Simplicial Complex (fragment)

```
  Diatonic complex (C major scale):

       C
      /|\
     / | \
    E--G--B       Simplices = consonant subsets
    |\/ \/|       0-simplices: 7 notes
    | D   |       1-simplices: consonant dyads
    |/\ /\|       2-simplices: consonant triads
    F--A--C

  beta_0 = 1 (connected)
  beta_1 = ? (depends on consonance criterion)
```

## n=6 Connections

| Property | Value | n=6 Link |
|----------|-------|----------|
| Vertex count | 12 | sigma(6) |
| Diatonic scale size | 7 | P1 + 1 |
| Pentatonic scale size | 5 | sopfr(6) |
| Chromatic complement | 12 - 7 = 5 | sopfr(6) |

## Interpretation

The simplicial complex approach to music theory operates on sigma(6) = 12
vertices. The diatonic/pentatonic complementarity (7 + 5 = 12) connects
to sopfr(6) = 5. Grade: WEAK because the homological structure depends on
the specific consonance criterion chosen.
