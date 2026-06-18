# MUSICTOPO-016: Trichord Space as Orbifold with Cone Points

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> The space of unordered 3-note chords (trichords) in continuous pitch-class space is an orbifold with cone-point singularities at augmented triads, where the local structure has Z_3 = Z_{P1/2} isotropy.

## Background

When we quotient T^3 by S_3 to get unordered trichord space, points
where two or more voices coincide become orbifold singularities.
Augmented triads (0,4,8) have a special Z_3 symmetry.

## Verification

```
  Orbifold: T^3 / S_3
  Singularity at augmented triads: isotropy Z_3
  |Z_3| = 3 = P1/2  EXACT

  Augmented triads in Z_12:
    {0,4,8}, {1,5,9}, {2,6,10}, {3,7,11}
    Count: 4 = tau(6)  EXACT

  Each augmented triad: invariant under cyclic permutation (123)
    (0,4,8) -> (4,8,0) -> (8,0,4) all same unordered set
```

## ASCII Cone Point

```
  Near a generic trichord:         Near augmented triad:

       *-----*                          *
      / \   / \                        /|\
     /   \ /   \                      / | \
    *-----*-----*                    /  |  \
    smooth (6 sheets)              cone point (2 sheets)
    S_3 acts freely               Z_3 isotropy
```

## Verification Table

| Property | Value | n=6 Link |
|----------|-------|----------|
| Cone point isotropy | Z_3 | P1/2 |
| Number of cone points | 4 | tau(6) |
| Generic isotropy | trivial | -- |
| Orbifold dimension | 3 | P1/2 |

## Interpretation

The tau(6) = 4 augmented triads are the orbifold singularities of
trichord space, each with Z_{P1/2} = Z_3 isotropy. These are the most
symmetric triads, and their count and symmetry are governed by n=6.
