# MUSICTOPO-037: Persistent Homology of Melodic Contour

**Domain**: Topology of Music | **Grade**: 🟧 WEAK
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> Applying persistent homology to a melody's pitch contour (as a time series) reveals topological features at multiple scales. The birth-death pairs in the persistence diagram encode melodic structure, with H_0 features counting connected components (phrases) and H_1 features counting loops (repeated patterns).

## Background

Persistent homology (TDA) tracks topological features as a filtration
parameter varies. Applied to music, the filtration can be the pitch
threshold: connect notes within k semitones.

## Construction

```
  Melody as point cloud: {(t_i, p_i)} in R^2
  Filtration: Rips complex at scale epsilon
  As epsilon grows: components merge, loops form

  For a melody in 12 = sigma(6) semitone range:
    H_0 persistence: phrase segmentation
    H_1 persistence: melodic loops / sequences
```

## ASCII Persistence Diagram

```
  Death
   |
  12|    *                  (long-lived H_0 feature)
   |
   8|  *   *                (medium features)
   |
   4| * * *                 (short-lived features)
   | * *
   +--+--+--+--+--+-> Birth
   0  2  4  6  8  12

  Features near diagonal: noise
  Features far from diagonal: significant structure
  Max death value: 12 = sigma(6) (octave range)
```

## Musical TDA Data

| Feature | Meaning | Typical Count |
|---------|---------|--------------|
| H_0 long bars | phrases | 3-5 (P1/2 to sopfr(6)) |
| H_0 short bars | ornaments | many |
| H_1 features | sequences | 1-3 |
| Max persistence | sigma(6) | octave range |

## Interpretation

Persistent homology reveals the multi-scale topology of melody.
The octave range sigma(6) = 12 sets the maximum persistence value.
Grade: WEAK because the specific features depend on the melody, and the
n=6 connection is through the 12-semitone octave.
