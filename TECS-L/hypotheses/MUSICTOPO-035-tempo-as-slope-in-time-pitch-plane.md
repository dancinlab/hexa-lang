# MUSICTOPO-035: Tempo as Slope in Time-Pitch Plane

**Domain**: Topology of Music | **Grade**: 🟧 WEAK
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> In the time-pitch plane R^2, a melody traces a curve. The tempo determines the horizontal scaling, while pitch intervals determine vertical jumps. A steady tempo corresponds to constant horizontal spacing, and tempo changes are slope variations in this 2 = phi(6) dimensional space.

## Background

The piano-roll representation places time on the x-axis and pitch on the
y-axis, creating a 2D representation of music. This is a projection of
the full musical space onto R^2.

## Construction

```
  Time-pitch plane: R^2 (dimension 2 = phi(6))
  Melody: curve gamma(t) = (t, p(t)) in R^2
  Tempo: dt/d(beat) = horizontal scaling
  Intervals: dp/dt = pitch rate of change

  At constant tempo: horizontal spacing uniform
  Accelerando: horizontal spacing decreases
  Ritardando: horizontal spacing increases
```

## ASCII Time-Pitch Plane

```
  Pitch
  (MIDI)
   |       *
   |   *       *
   | *           *   *
   |               *       melody curve
   |
   +--+--+--+--+--+--+---> Time
   |  |  |  |  |  |  |
   beat subdivisions
   (12 per measure = sigma(6))

  Dimension of this space: 2 = phi(6)
```

## Properties

| Property | Value | n=6 Link |
|----------|-------|----------|
| Plane dimension | 2 | phi(6) |
| Time subdivisions | 12/measure | sigma(6) |
| Pitch range | ~88 keys | -- |
| Tempo = slope | horizontal rate | -- |

## Interpretation

The time-pitch plane is a phi(6) = 2 dimensional projection of musical
structure. The standard subdivision of 12 = sigma(6) beats per measure
provides the grid. Grade: WEAK because the 2D representation is a
visualization choice, not a topological invariant.
