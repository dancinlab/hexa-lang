# Hypothesis MUSIC-105: Concert Pitch A440: 440 and n=6
**n6 Grade: 🟩 EXACT** (auto-graded, 5 unique n=6 constants)


**Grade: ⚪ INCONCLUSIVE**

## Hypothesis

> Concert pitch A4 = 440 Hz. While 440 = 8 * 55 = 2^3 * 5 * 11,
> there is no clean mapping to n=6 arithmetic functions.

## Background

The international standard concert pitch is A4 = 440 Hz, adopted in
1955 by ISO. Earlier standards varied (435, 432, 415 Hz, etc.).

## Numerical Verification

| Quantity         | Value | n=6 match?         |
|-----------------|-------|--------------------|
| A4 frequency     | 440   | 440/sigma(6) = 36.67 (not clean) |
| Middle C (C4)    | 261.6 | no clean mapping   |
| Lowest piano (A0)| 27.5  | no clean mapping   |
| A4 / 440         | 1     | --                 |

440 = 2^3 * 5 * 11
sigma(6) = 12 = 2^2 * 3
No common structure.

## ASCII Diagram

```
  A4 = 440 Hz
  440 / 6  = 73.33...  (not integer)
  440 / 12 = 36.67...  (not integer)
  440 / 5  = 88        (= 8 * 11)
  440 / 4  = 110       (A2)
  440 / 2  = 220       (A3)

  No clean n=6 relationship found.
```

## Interpretation

Concert pitch does not connect to n=6. The 440 Hz standard is a
20th-century convention, not a structural constant.

## Limitations

- 440 Hz is arbitrary; earlier standards (A=415, 432) were different.
- Grade INCONCLUSIVE: no connection found.


## Grade: ⚪ INCONCLUSIVE

Golden Zone dependency: None (pure music theory observation).
