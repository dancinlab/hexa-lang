# MUSICTOPO-008: Hexatonic Systems: tau(6) = 4 Cycles

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> The 24 major and minor triads partition into exactly 4 hexatonic systems under the PL-cycle (alternating P and L operations). The number of hexatonic systems equals tau(6) = 4, the divisor count of 6.

## Background

A hexatonic system is a set of 6 triads closed under the PL-cycle
(alternating Parallel and Leading-tone operations). Richard Cohn (1996)
showed that the 24 triads split into exactly 4 such systems.

## Verification

```
  Total triads: 24 = 2 * sigma(6)
  Hexatonic systems: 4 = tau(6)  EXACT
  Triads per system: 24 / 4 = 6 = P1  EXACT

  System 0 (Northern): C, c, Ab, ab, E, e
  System 1 (Eastern):  G, g, Eb, eb, B, b
  System 2 (Southern): D, d, Bb, bb, F#, f#
  System 3 (Western):  A, a, F, f, C#, c#
```

## ASCII Hexatonic Cycle

```
  System 0:
    C ---P--- c ---L--- Ab ---P--- ab ---L--- E ---P--- e ---L--- (C)
    |_________________________6 triads = P1________________________|

  All 4 systems:
    Sys 0: C-c-Ab-ab-E-e       (6 triads)
    Sys 1: G-g-Eb-eb-B-b       (6 triads)
    Sys 2: D-d-Bb-bb-F#-f#     (6 triads)
    Sys 3: A-a-F-f-C#-c#       (6 triads)
    Total: 4 x 6 = 24 = 2*sigma(6)
```

## Verification Table

| Property | Value | n=6 Link |
|----------|-------|----------|
| Number of systems | 4 | tau(6) |
| Triads per system | 6 | P1 |
| Total triads | 24 | 2*sigma(6) |
| PL-cycle length | 6 | P1 |

## Interpretation

The hexatonic partition is a perfect tau(6)-fold decomposition where each
piece has exactly P1 = 6 elements. The product tau(6) * P1 = 4 * 6 = 24 = 2*sigma(6)
recovers the total triad count, making n=6 the master organizer.
