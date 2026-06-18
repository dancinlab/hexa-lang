# H-CX-10: R-chain Length = Learning Phase Transition Count

> **Hypothesis**: The number of phase transitions in neural network learning is related to the R-chain length of input dimension n.

## Background
- R-chain: n→R(n)→...→1. Length is n's "arithmetic complexity"
- Golden MoE learning: multiple phase transitions exist in loss curve
- Hypothesis: In model dimension d, R-chain length L(d) predicts phase count

## R-chain Length Table

```
  n       R-chain              length
  ─────   ────────────────     ──────
  6       6→1                  2
  120     120→6→1              3
  6048    6048→120→6→1         4
  193750  193750→6048→120→6→1  5

  Most n: R(n) non-integer → length 1 (immediate termination)
  Integer R sparse: only 52 for n≤50000
```

## Verification Directions
1. [ ] Measure phase transition point count in Golden MoE learning loss curve
2. [ ] Compare learning phase count at hidden_dim=120, 6048, etc.
3. [ ] Correlate loss curve "step" count with R-chain length

## ASCII Prediction Graph

```
  Loss
  5 |*
    | *
  4 |  *
    |   *---*  ← phase transition 1
  3 |        *
    |         *---*  ← phase transition 2
  2 |              *
    |               *  ← phase transition 3 (if R-chain=4)
  1 |
    +--+--+--+--+--+--→ Steps
       1k 2k 3k 4k 5k
```

## Difficulty: Extreme High | Impact: ★★★★ (if successful)