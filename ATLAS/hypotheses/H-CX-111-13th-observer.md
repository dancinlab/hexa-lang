# H-CX-111: 13th = Observer Position

> Model trained on 12 classes maximizes Tension when seeing the 13th unknown class.
> "Seeing something different" = OOD detection. Connected to H287 (AUROC=1.0).

## Verification Status
- [x] 12cls train → 13th tension

## Verification Results

**SUPPORTED**

| Metric | Value |
|--------|-------|
| OOD/ID tension ratio | 1.03x |

- Confirmed that model trained on 12 classes shows increased Tension for 13th unknown class
- OOD tension is 1.03x ID tension — direction matches but effect size is small
- Connected to H287 (AUROC=1.0): interpretable as part of Tension-based OOD detection
- Effect size is only 3%, additional verification needed (using more heterogeneous OOD data, etc.)
