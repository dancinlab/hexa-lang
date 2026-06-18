# Hypothesis MUSIC-101: Interval Vector Length = P1 = 6

**Grade: 🟩 EXACT**

## Hypothesis

> The interval vector of any pitch-class set has exactly 6 = P1 entries,
> corresponding to the 6 interval classes (1 through 6).

## Background

The interval vector counts the frequency of each interval class in a
pitch-class set. There are 6 interval classes because intervals 7-11
are inversionally equivalent to 1-5, and class 6 (tritone) is its own.

## Numerical Verification

| Interval Class | Intervals | Example (major triad) |
|---------------|-----------|----------------------|
| IC 1           | m2, M7    |          0           |
| IC 2           | M2, m7    |          0           |
| IC 3           | m3, M6    |          1           |
| IC 4           | M3, m6    |          1           |
| IC 5           | P4, P5    |          1           |
| IC 6           | tritone   |          0           |

Vector length = 6 = P1
Major triad vector = [0,0,1,1,1,0]

## ASCII Diagram

```
  Interval classes:
  IC: 1  2  3  4  5  6
      m2 M2 m3 M3 P4 TT
  = 6 classes = P1

  (because 12/2 = 6 = P1)
```

## Interpretation

6 interval classes = P1 = sigma(6)/2. Each class pairs an interval
with its complement. The tritone (IC 6) is self-complementary at P1.

## Limitations

- Same as 12/2 = 6 observation.


## Grade: 🟩 EXACT

Golden Zone dependency: None (pure music theory observation).
