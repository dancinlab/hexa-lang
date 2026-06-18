# H-CX-67: Optimal Synergy Point — Unified Precognition Synergy Maximized in Golden Zone
**n6 Grade: 🟩 EXACT** (auto-graded, 5 unique n=6 constants)


> Unified precognition synergy (unified - max(individual)) is
> maximized in a specific range of tension distribution, and that range coincides with the Golden Zone (1/e ± ln(4/3)/2).

## Background

- Unified precognition: +17.8%p synergy in Fashion (maximum)
- Golden Zone: I ∈ [0.2123, 0.5000], center 1/e ≈ 0.368
- H-CX-58: Monotonic increase in accuracy by tension quintile

**Key Connection**: Synergy won't be uniform across all tension ranges.
Tension range where "magnitude" and "direction" information are most complementary = Golden Zone?
Too high tension → Magnitude alone sufficient (synergy unnecessary)
Too low tension → Direction also uncertain (synergy impossible)
Medium tension → Magnitude alone insufficient but direction complements → Maximum synergy

## Predictions

1. Calculate synergy (LR_AUC - mag_AUC) by tension quintile
2. Maximum synergy in middle quintiles (Q2-Q3)
3. Maximum synergy tension range near 1/e ratio of total tension range
4. Minimum synergy in high/low tension ranges

## Verification Method

```
1. Quintile-wise analysis in unified precognition script
2. Compare mag_AUC vs unified_AUC within each quintile
3. Distribution of synergy = unified - mag by quintile
4. Compare tension median of max synergy quintile / total tension range
```

## Related Hypotheses

- Unified precognition (H-CX-58+59), Golden Zone constant system
- H-CX-58 (precognition lens), H329 (tension duality)

## Limitations

- Small samples within quintiles make AUC unstable
- Golden Zone mapping may be forced
- Absolute tension values differ by dataset (normalization needed)

## Verification Status

- [x] Synergy measurement by quintile
- [x] Golden Zone mapping confirmation

## Verification Results

**Verdict: PARTIAL (2/3 datasets)**

### Maximum Synergy by Quintile

| Dataset | Max Quintile | Synergy  | relative_pos | delta from 1/e | Verdict |
|---------|-------------|----------|-------------|----------------|---------|
| MNIST   | Q3          | +0.026   | 0.340       | 0.028          | SUPPORTED |
| Fashion | Q3          | +0.025   | 0.341       | 0.027          | SUPPORTED |
| CIFAR   | Q5          | +0.040   | 0.644       | 0.276          | REJECTED  |

```
  relative_pos of max synergy
       1/e = 0.368
        |
  0.7 | |                  *  CIFAR (0.644) -- REJECTED
  0.6 | |
  0.5 | |
  0.4 | |
  0.3 | * MNIST (0.340)  * Fashion (0.341)
  0.2 | |
  0.1 | |
      +-+--+--------+--------+--->
       1/e  MNIST   FAS     CIF
```

### MNIST & Fashion: Near Golden Zone

- MNIST: relative_pos = 0.340, |delta| = 0.028 from 1/e (0.368)
- Fashion: relative_pos = 0.341, |delta| = 0.027 from 1/e (0.368)
- Both datasets within 0.03 of 1/e

### CIFAR: Rejected

- In CIFAR, maximum synergy occurs at Q5 (highest tension)
- relative_pos = 0.644, 0.276 deviation from Golden Zone center
- CIFAR's high difficulty allows synergy only at high tension

### Interpretation

In MNIST/Fashion (easy datasets), magnitude+direction synergy maximizes at medium tension (Golden Zone).
In CIFAR (difficult dataset), sufficient information only at high tension → Different synergy pattern.
Golden Zone mapping depends on dataset difficulty and is not universal.