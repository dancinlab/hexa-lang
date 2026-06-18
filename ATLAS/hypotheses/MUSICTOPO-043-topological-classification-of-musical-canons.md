# MUSICTOPO-043: Topological Classification of Musical Canons

**Domain**: Topology of Music | **Grade**: 🟧 WEAK
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> Musical canons can be classified topologically by their voice-entry structure. A round (strict canon at the unison) with n voices is characterized by a Z_n cyclic symmetry. The most common canon types have 2, 3, or 4 voices = phi(6), P1/2, tau(6).

## Background

A canon is a contrapuntal technique where a melody is imitated by one
or more voices at fixed time delays. The number of voices and the
imitation interval classify the canon type.

## Classification

```
  Canon types by voice count:
    2-voice canon: Z_2 = Z_{phi(6)} symmetry
    3-voice canon: Z_3 = Z_{P1/2} symmetry
    4-voice canon: Z_4 = Z_{tau(6)} symmetry
    6-voice canon: Z_6 = Z_{P1} symmetry (rare, virtuosic)

  Famous examples:
    2-voice: most rounds, many Bach canons
    3-voice: "Row Row Row Your Boat"
    4-voice: Pachelbel's Canon (with variations)
    6-voice: Bach, Musical Offering (Ricercar a 6)
```

## ASCII Canon Structure

```
  3-voice round (Z_3 symmetry):

  Time --->
  V1: |==melody==|==melody==|==melody==|
  V2:      |==melody==|==melody==|==melody==|
  V3:           |==melody==|==melody==|==melody==|
       <-T->    T = entry delay

  Symmetry: shift by T maps V1->V2->V3->V1 (Z_3 action)
```

## Canon Voice Count Distribution

| Voices | Symmetry | Frequency | n=6 Link |
|--------|----------|-----------|----------|
| 2 | Z_2 | very common | phi(6) |
| 3 | Z_3 | common | P1/2 |
| 4 | Z_4 | common | tau(6) |
| 5 | Z_5 | rare | sopfr(6) |
| 6 | Z_6 | very rare | P1 |

## Interpretation

Canon voice counts {2, 3, 4, 6} align with the divisors of P1 = 6 and
n=6 constants. The 6-voice canon (Z_{P1} symmetry) is the most complex
commonly attempted structure. Grade: WEAK because voice counts are partly
constrained by human limitations, not pure topology.
