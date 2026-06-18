# MUSICTOPO-049: Nerve Theorem Applied to Chord Overlap

**Domain**: Topology of Music | **Grade**: 🟧 WEAK
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> The nerve theorem states that if a cover of a space has all intersections contractible, the nerve is homotopy equivalent to the space. Applied to the diatonic scale covered by its P1/2 = 3 consonant triads (I, IV, V), the nerve captures the harmonic topology.

## Background

The nerve of a cover {U_i} is the simplicial complex whose k-simplices
correspond to (k+1)-fold intersections. The nerve theorem guarantees
this nerve reflects the topology of the original space under mild conditions.

## Construction

```
  Diatonic scale: {C, D, E, F, G, A, B} = 7 notes

  Cover by triads:
    I  = {C, E, G}     (tonic)
    ii = {D, F, A}     (supertonic)
    iii= {E, G, B}     (mediant)
    IV = {F, A, C}     (subdominant)
    V  = {G, B, D}     (dominant)
    vi = {A, C, E}     (submediant)
    vii= {B, D, F}     (leading tone)

  Number of triads: 7 = P1 + 1

  Primary triads: I, IV, V = 3 = P1/2  EXACT
```

## ASCII Nerve Complex

```
  Nerve of primary triads (I, IV, V):

       I({C,E,G})
      / \
     /   \       I cap IV = {C} (nonempty -> edge)
    /     \      I cap V  = {G} (nonempty -> edge)
   IV------V     IV cap V = {} (empty -> no edge)

  Nerve = path graph, not triangle
  (because IV and V share no notes)
```

## Intersection Data

| Triad Pair | Intersection | Size |
|------------|-------------|------|
| I, ii | {} | 0 |
| I, iii | {E, G} | 2 |
| I, IV | {C} | 1 |
| I, V | {G} | 1 |
| I, vi | {C, E} | 2 |
| IV, V | {} | 0 |

## Interpretation

The nerve theorem applied to diatonic triads reveals harmonic proximity:
triads sharing common tones are nerve-adjacent. The P1/2 = 3 primary triads
(I, IV, V) form the backbone. Grade: WEAK because the nerve theorem
application requires checking contractibility conditions.
