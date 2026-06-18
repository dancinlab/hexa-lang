# Hypothesis MUSIC-085: Guitar Tuning Intervals: 4ths and 1 Major 3rd

**Grade: 🟧 WEAK**

## Hypothesis

> Standard guitar tuning uses 5 = sopfr(6) intervals between 6 = P1 strings:
> four perfect 4ths and one major 3rd.

## Background

Standard guitar tuning (E-A-D-G-B-E) uses mostly perfect fourth
intervals (5 semitones) with one major third (4 semitones) between
G and B strings.

## Numerical Verification

| Strings  | Interval      | Semitones | n=6 match    |
|---------|--------------|-----------|------------- |
| E-A      | Perfect 4th   |     5     | sopfr(6)=5  |
| A-D      | Perfect 4th   |     5     | sopfr(6)=5  |
| D-G      | Perfect 4th   |     5     | sopfr(6)=5  |
| G-B      | Major 3rd     |     4     | tau(6)=4    |
| B-E      | Perfect 4th   |     5     | sopfr(6)=5  |

Intervals = 5 = sopfr(6) between P1=6 strings
P4 intervals = 4 = tau(6)
M3 intervals = 1

## ASCII Diagram

```
  E ─P4─ A ─P4─ D ─P4─ G ─M3─ B ─P4─ E
  5      5      5      4      5  (semitones)
  sopfr  sopfr  sopfr  tau    sopfr
```

## Interpretation

P1=6 strings connected by sopfr(6)=5 intervals (mostly).
The exception (M3=4=tau(6)) prevents exact match.

## Limitations

- The mixed intervals weaken the pattern. Grade WEAK.


## Grade: 🟧 WEAK

Golden Zone dependency: None (pure music theory observation).
