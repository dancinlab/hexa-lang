# MUSICTOPO-006: Mobius Strip in Voice Leading via Contrary Motion

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> The space of unordered pairs of pitch classes (dyads) forms a Mobius strip. When two voices move in contrary motion (one up, one down by the same interval), they trace a path that crosses the Mobius strip's identification, reflecting the Z_2 = Z_{phi(6)} symmetry of voice exchange.

## Background

Dmitri Tymoczko showed that the space of unordered 2-note chords (dyads)
in continuous pitch-class space is a Mobius strip. This arises because
swapping two voices is a Z_2 reflection.

## Topological Construction

```
  Ordered pairs: T^2 = S^1 x S^1
  Unordered pairs: T^2 / Z_2 (identify (x,y) ~ (y,x))
  Result: Mobius strip (with boundary = unisons)

  Symmetry group of exchange: Z_2 = Z_{phi(6)}  EXACT
```

## ASCII Mobius Strip Construction

```
  Ordered space (torus):        Unordered space (Mobius):

  y|                            y|
   | . . . . .                   |\  .  .  .
   | . . . . .       Z_2         | \  .  .
   | . . . . .    --------->     |  \  .
   | . . . . .    (x,y)~(y,x)   |   \
   +----------x                  +----\---x
                                 identify with twist
```

## Verification

| Property | Value | n=6 Link |
|----------|-------|----------|
| Exchange symmetry | Z_2 | Z_{phi(6)} |
| Boundary components | 1 | non-orientable |
| Euler characteristic | 0 | -- |
| Orientation | non-orientable | voice exchange |
| Base space dim | 1 | S^1 |

## Interpretation

The Mobius strip structure of dyad space arises from Z_2 = Z_{phi(6)} symmetry.
Contrary motion in voice leading corresponds to paths crossing the twist,
making the non-orientability of the Mobius strip musically audible.
