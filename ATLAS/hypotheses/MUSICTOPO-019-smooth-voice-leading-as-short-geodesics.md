# MUSICTOPO-019: Smooth Voice Leading as Short Geodesics

**Domain**: Topology of Music | **Grade**: 🟧 WEAK
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> Good voice leading in tonal music corresponds to short geodesics in chord space T^n/S_n. The geodesic distance between chords measures total voice displacement. Minimal voice leadings are geodesics whose length is bounded by the orbifold injectivity radius.

## Background

Tymoczko's key insight: voice-leading parsimony (moving each voice as
little as possible) corresponds geometrically to short paths in the
orbifold chord space with the Euclidean metric.

## Structural Connection

```
  Voice-leading distance: d((x1,...,xn), (y1,...,yn)) = sqrt(sum (xi-yi)^2)
  Geodesic = straight line in covering space, projected to orbifold

  Key triadic voice leadings:
    C -> F:  (C,E,G) -> (C,F,A) = (0,+1,+2) distance sqrt(5)
    C -> Am: (C,E,G) -> (C,E,A) = (0,0,+2) distance 2
    C -> Cm: (C,E,G) -> (C,Eb,G) = (0,-1,0) distance 1 (P operation)
```

## ASCII Geodesic in Chord Space

```
  C major        A minor         F major
  (0,4,7) -----> (0,4,9) -----> (0,5,9)
     \              |              /
      \___geodesic___|_____________/
         d=2          d=sqrt(2)

  Geodesics approximate good voice leading
  Shorter = smoother = more consonant transition
```

## n=6 Connection

| Property | Value | n=6 Link |
|----------|-------|----------|
| Space dimension | 3 | P1/2 |
| Metric | Euclidean | flat torus |
| NR operations distance | 1-2 | minimal geodesics |
| Geodesic count (PLR) | 3 | P1/2 |

## Interpretation

The connection between smooth voice leading and short geodesics is a
geometric fact about orbifolds. The n=6 link is indirect: the space
dimension P1/2 = 3 determines the metric structure. Grade: WEAK because
the geodesic-voice-leading connection is general topology, not specific to n=6.
