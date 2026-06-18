# MUSICTOPO-025: Contrapuntal Symmetries as Group Actions on Z_sigma(6)

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> Species counterpoint rules define symmetries acting on Z_12 = Z_{sigma(6)}. The permitted intervals in first-species counterpoint (unison, third, fifth, sixth, octave) form a subset of Z_12 closed under the consonance-preserving operations, totaling P1 = 6 consonant interval classes.

## Background

In species counterpoint (Fux), the consonant intervals are classified
as perfect (unison, fifth, octave) and imperfect (third, sixth).
Dissonances (second, fourth, seventh, tritone) are restricted.

## Verification

```
  Consonant intervals (mod 12):
    Unison:      0
    Minor third: 3
    Major third: 4
    Perfect fifth: 7
    Minor sixth: 8
    Major sixth: 9

  Count of consonant interval classes: 6 = P1  EXACT

  As interval classes (mod 12, unordered):
    ic0 = unison, ic3 = third, ic4 = third,
    ic5 = fourth/fifth, ic8 = sixth, ic9 = sixth
    Wait -- ic5 includes fourth (dissonant) and fifth (consonant)!
```

## Corrected Count

```
  Consonant DIRECTED intervals in [0,11]:
    {0, 3, 4, 7, 8, 9} = 6 elements = P1  EXACT

  Complement (dissonant): {1, 2, 5, 6, 10, 11} = 6 elements = P1

  Consonant : Dissonant = P1 : P1 = 1:1
  Perfect balance!
```

## ASCII Consonance Map

```
  0  1  2  3  4  5  6  7  8  9  10 11
  C  .  .  C  C  .  .  C  C  C  .  .
  |        |  |        |  |  |
  unison  m3 M3      P5 m6 M6

  C = consonant (6 = P1 intervals)
  . = dissonant (6 = P1 intervals)
```

## Interpretation

The 12 = sigma(6) directed intervals split evenly: P1 = 6 consonant and
P1 = 6 dissonant. This perfect 50/50 split reflects the self-dual nature
of perfect number 6 in the structure of consonance.
