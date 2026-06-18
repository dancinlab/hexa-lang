# MUSICTOPO-038: Betti Numbers of Scale Complexes

**Domain**: Topology of Music | **Grade**: 🟧 WEAK
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> The simplicial complex of a musical scale (vertices = notes, simplices = consonant subsets) has Betti numbers encoding its topology. For the diatonic scale (7 notes from Z_12 = Z_{sigma(6)}), beta_0 = 1 (connected) and higher Betti numbers depend on consonance criteria.

## Background

Given a scale S subset Z_12 and a consonance criterion, we form a
simplicial complex by declaring subsets consonant if all pairwise
intervals are consonant. The Betti numbers of this complex reveal
topological structure.

## Construction

```
  Diatonic scale C major: S = {0, 2, 4, 5, 7, 9, 11}
  |S| = 7 = P1 + 1

  Consonant intervals: {3, 4, 5, 7, 8, 9}  (thirds, fourths, fifths, sixths)
  |consonant| = 6 = P1  EXACT

  Simplicial complex: edge (i,j) if |i-j| mod 12 in consonant set
```

## ASCII Diatonic Complex

```
  C(0)----D(2)
  |\      / \
  | \    /   \
  |  E(4)    F(5)
  | / \  \   / |
  |/   \  \ /  |
  G(7)--A(9)--B(11)

  beta_0 = 1 (connected)
  beta_1 = number of independent cycles
```

## Scale Size Table

| Scale | Size | Complement | n=6 Link |
|-------|------|-----------|----------|
| Chromatic | 12 | 0 | sigma(6) |
| Diatonic | 7 | 5 | P1+1, sopfr(6) |
| Pentatonic | 5 | 7 | sopfr(6) |
| Whole tone | 6 | 6 | P1 |
| Hexatonic | 6 | 6 | P1 |

## Interpretation

Scale complexes live inside Z_{sigma(6)}. The diatonic-pentatonic duality
(7 + 5 = sigma(6)) and the self-complementary whole-tone scale (6 = P1)
are topological features encoded by n=6. Grade: WEAK because specific
Betti numbers depend on the consonance criterion.
