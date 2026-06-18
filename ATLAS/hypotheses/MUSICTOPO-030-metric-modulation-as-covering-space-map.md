# MUSICTOPO-030: Metric Modulation as Covering Space Map

**Domain**: Topology of Music | **Grade**: 🟧 WEAK
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> Metric modulation (changing tempo so that a subdivision in the old meter becomes the beat of the new meter) can be modeled as a covering space map between rhythmic circles. The covering degree equals the ratio of beat subdivisions.

## Background

Metric modulation (Elliot Carter) reinterprets a rhythmic subdivision as
a new pulse. E.g., if triplet eighth notes become the new quarter note,
the tempo changes by factor 3/2.

## Topological Model

```
  Old meter: circle C_old with n_old beats
  New meter: circle C_new with n_new beats
  Covering map: p: C_new -> C_old, degree d

  Example: 4/4 -> 6/8 modulation
    C_old: 4 beats (quarter notes)
    C_new: 6 beats (eighth notes in compound)
    Covering degree: related to lcm(4,6) = 12 = sigma(6)  EXACT
```

## ASCII Metric Modulation

```
  4/4 meter:   |----|----|----|----|     4 beats
                                         modulate via triplets
  6/8 meter:   |--|--|--|--|--|--|        6 beats

  Common subdivision: 12 = sigma(6) = lcm(4,6)

  12-grid: x . . x . . x . . x . .     (4/4 quarters on 12-grid)
           x . x . x . x . x . x .     (6/8 eighths on 12-grid)
```

## Covering Space Data

| Modulation | lcm | Covering degree | n=6 Link |
|------------|-----|----------------|----------|
| 4/4 -> 6/8 | 12 | 3 | sigma(6), P1/2 |
| 3/4 -> 4/4 | 12 | 4 | sigma(6), tau(6) |
| 2/4 -> 3/4 | 6 | 3 | P1, P1/2 |
| 6/8 -> 4/4 | 12 | 2 | sigma(6), phi(6) |

## Interpretation

Metric modulations between common meters frequently involve lcm = 12 = sigma(6)
as the common subdivision. The covering degrees (2, 3, 4) correspond to
phi(6), P1/2, and tau(6). Grade: WEAK because the covering space model is
a framework, and the n=6 connections arise from the commonness of 4/4 and 6/8.
