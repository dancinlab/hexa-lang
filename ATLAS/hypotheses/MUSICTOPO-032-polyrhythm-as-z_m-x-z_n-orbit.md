# MUSICTOPO-032: Polyrhythm as Z_m x Z_n Orbit

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> A polyrhythm (simultaneous patterns of m and n beats) generates orbits under the Z_m x Z_n action on Z_{lcm(m,n)}. The polyrhythm 3:4 acts on Z_12 = Z_{sigma(6)}, and 2:3 acts on Z_6 = Z_{P1}.

## Background

A k:l polyrhythm superimposes a pattern of k even beats with l even beats.
The combined pattern lives in Z_{lcm(k,l)}, where both cycles align.

## Verification

```
  3:4 polyrhythm:
    Z_3 cycle: beats at 0, 4, 8 in Z_12
    Z_4 cycle: beats at 0, 3, 6, 9 in Z_12
    Universe: Z_12 = Z_{sigma(6)}  EXACT
    Combined onsets: {0, 3, 4, 6, 8, 9} = 6 = P1 onsets  EXACT

  2:3 polyrhythm:
    Z_2 cycle: beats at 0, 3 in Z_6
    Z_3 cycle: beats at 0, 2, 4 in Z_6
    Universe: Z_6 = Z_{P1}  EXACT
    Combined onsets: {0, 2, 3, 4} = 4 = tau(6) onsets  EXACT
```

## ASCII 3:4 Polyrhythm

```
  Beat:  0  1  2  3  4  5  6  7  8  9  10 11
  3-pat: X           X           X
  4-pat: X        X        X        X
  Both:  X        X  X     X     X  X
         |__________________________________|
                  12 = sigma(6) beats

  Combined onset count: 6 = P1
```

## Polyrhythm Table

| Polyrhythm | lcm | Universe | Onsets | n=6 Link |
|------------|-----|----------|--------|----------|
| 2:3 | 6 | Z_{P1} | 4 = tau(6) | P1, tau(6) |
| 3:4 | 12 | Z_{sigma(6)} | 6 = P1 | sigma(6), P1 |
| 2:6 | 6 | Z_{P1} | 6 = P1 | P1 |
| 4:6 | 12 | Z_{sigma(6)} | 8 | sigma(6) |

## Interpretation

The two most fundamental polyrhythms (2:3 and 3:4) live in Z_{P1} and
Z_{sigma(6)} respectively. The 3:4 polyrhythm produces exactly P1 = 6
combined onsets in sigma(6) = 12 beats, a striking n=6 coincidence.
