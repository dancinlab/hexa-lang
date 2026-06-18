# MUSICTOPO-041: Covering Spaces and Modulation

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> Key modulation in tonal music can be modeled as path lifting in a covering space. The space of keys is S^1 (circle of fifths with 12 = sigma(6) points), and modulation traces a path on this circle. The monodromy of a modulation sequence is an element of Z_12 = Z_{sigma(6)}.

## Background

Modulation (changing key) moves between points on the circle of fifths.
A sequence of modulations traces a path, and the net modulation after
returning to the original key is the monodromy.

## Verification

```
  Key space: Z_12 = Z_{sigma(6)} (circle of fifths)
  Modulation by fifth: +1 in Z_12
  Modulation by fourth: -1 in Z_12
  Modulation by third: +4 or +3 in Z_12

  Monodromy: total modulation mod 12
    C -> G -> D -> A -> E -> B -> F# -> Db -> Ab -> Eb -> Bb -> F -> C
    Net: 12 fifths = 0 mod 12 (trivial monodromy)  EXACT

  This is the deck transformation of the universal cover.
```

## ASCII Modulation Path

```
  Circle of fifths (key space):

       C
    F     G          Modulation path:
  Bb        D        C -> G -> D -> G -> C
  Eb         A       = loop in key space
    Ab    E          monodromy = 0
       Db/C#

  Non-trivial monodromy:
  C -> G -> D -> A   (3 steps = P1/2)
  Net shift: +3 in Z_12  (key of A)
```

## Monodromy Data

| Modulation Cycle | Steps | Net (mod 12) | Returns? |
|-----------------|-------|-------------|----------|
| All fifths | 12 = sigma(6) | 0 | yes |
| Major thirds | 3 = P1/2 | returns | yes |
| Minor thirds | 4 = tau(6) | returns | yes |
| Tritone | 2 = phi(6) | returns | yes |

## Interpretation

The monodromy of modulation lives in Z_{sigma(6)} = Z_12. Complete cycles
through all keys require sigma(6) = 12 fifth-steps. Shorter cycles of
length P1/2, tau(6), or phi(6) correspond to the subgroups of Z_12.
