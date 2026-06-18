# H-CX-81: Aberration-Phase Alignment — Classes with High Chromatic Aberration = Classes that Merge Quickly

> Classes with high chromatic aberration (H-CX-60) (classes with high AUC variance)
> match classes that merge quickly in PH (H-CX-66).
> Cause of aberration = topological proximity.

## Background

- H-CX-60: Chromatic aberration = per-class AUC variance (Fashion variance=0.035)
- H-CX-66: PH merge order = confusion order (r=-0.97)
- Intersection: Are low AUC classes the ones that merge quickly?

## Predictions

1. Positive correlation between per-class AUC and that class's min_merge_distance
2. The two classes in the fastest-merging class pair = lowest AUC classes
3. Spearman(min_merge_dist, class_AUC) > 0.5

## Verification Method

```
1. Reuse H-CX-65/66 data
2. Each class's min_merge_distance (distance to nearest neighbor)
3. Each class's precog AUC
4. Spearman(min_merge_dist, AUC)
```

## Related Hypotheses

- H-CX-60 (Aberration Precognition), H-CX-66 (Directional Topology), H-CX-65 (Aberration Correction)

## Limitations

- In H-CX-65, isolation vs AUC was refuted — similar hypothesis
- If min_merge_dist ≈ isolation, then repeating the same hypothesis

## Verification Status

- [ ] min_merge_dist vs AUC
- [ ] Difference analysis with H-CX-65