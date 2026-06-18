# Hypothesis MUSIC-082: Staff Lines = sopfr(6) = 5

**Grade: 🟩 EXACT**

## Hypothesis

> The modern musical staff has exactly 5 = sopfr(6) lines,
> a standard established in the 11th century.

## Background

The five-line staff has been the standard for Western music notation
since Guido d'Arezzo. Earlier staves had 4, 6, or varying numbers of
lines before 5 became universal.

## Numerical Verification

| Quantity        | Value | n=6 Function | Match |
|-----------------|-------|-------------- |-------|
| Staff lines     |   5   | sopfr(6)=5   | EXACT |
| Staff spaces    |   4   | tau(6)=4     | EXACT |
| Positions (L+S) |   9   | (P1/2)^2=9  | EXACT |
| Ledger lines    | varies| --           | --    |

## ASCII Diagram

```
  ──────── line 5
           space 4
  ──────── line 4
           space 3     5 lines = sopfr(6)
  ──────── line 3      4 spaces = tau(6)
           space 2     9 positions = (P1/2)^2
  ──────── line 2
           space 1
  ──────── line 1
```

## Interpretation

5 lines = sopfr(6), 4 spaces = tau(6). Lines + spaces = 9 = 3^2 = (P1/2)^2.

## Limitations

- Medieval notation used 4-line staves; 5 is a convention that won.


## Grade: 🟩 EXACT

Golden Zone dependency: None (pure music theory observation).
