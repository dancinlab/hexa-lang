# Hypothesis MUSIC-100: Set Class Complementation: Size 6 is Self-Complementary

**Grade: 🟩 EXACT**

## Hypothesis

> In pitch-class set theory, only sets of size 6 = P1 can be
> self-complementary (Z-related to their own complement).

## Background

A pitch-class set's complement contains the remaining pitch classes.
Sets of size 6 are unique: their complement is also size 6, enabling
self-complementary (hexachordal combinatorial) properties.

## Numerical Verification

| Set Size | Complement Size | Self-comp possible? |
|---------|----------------|-------------------|
| 1       |      11        | No                |
| 2       |      10        | No                |
| 3       |       9        | No                |
| 4       |       8        | No                |
| 5       |       7        | No                |
| **6**   |     **6**      | **YES = P1**      |

## ASCII Diagram

```
  Only at size P1=6:
  Set:        {C, D, E, F#, G#, A#}    6 = P1
  Complement: {C#, Eb, F, G, A, B}     6 = P1
  Both hexachords, both size P1
  This is unique to P1 within sigma(6)=12!
```

## Interpretation

Self-complementarity requires n = sigma(6)/2 = 12/2 = 6 = P1.
The perfect number is the unique self-complementary size.

## Limitations

- This follows from 12/2 = 6; the deeper claim is 12 = sigma(6).


## Grade: 🟩 EXACT

Golden Zone dependency: None (pure music theory observation).
