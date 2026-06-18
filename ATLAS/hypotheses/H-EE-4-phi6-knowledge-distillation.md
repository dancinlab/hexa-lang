# H-EE-4: Phi6Simple Knowledge Distillation
**n6 Grade: 🟧 CLOSE** (auto-graded, 4 unique n=6 constants)


## Hypothesis

> A Phi6Simple student can distill from a GELU teacher with minimal loss gap.

## Background

If organizations have already trained GELU-based models, they need a migration path.
Knowledge distillation (KD) transfers a teacher's learned representations to a student
with a different architecture. Can Phi6 students capture GELU teacher knowledge?

## Test Design

1. Train GELU teacher (1000 steps)
2. Train Phi6 student from scratch (baseline)
3. Distill: Phi6 student learns from GELU teacher soft targets
4. Vary temperature T and KD weight alpha
5. Measure: loss, accuracy, KL divergence from teacher

## Results

### Model Comparison

| Model                 | Eval Loss | Eval Acc | KL from Teacher |
|----------------------|----------|---------|----------------|
| GELU Teacher         | 3.2748   | 18.6%   | 0 (reference)  |
| Phi6 from scratch    | **2.6526**| **34.2%**| 0.200          |
| Phi6 distilled (best)| 3.0963   | 25.4%   | 0.102          |

**Surprise: Phi6 from scratch OUTPERFORMS the GELU teacher by a wide margin.**

### Distillation Configurations

| T   | alpha | Final CE | Eval Loss | Eval Acc | KL(T -> S) | vs Scratch |
|-----|-------|---------|----------|---------|-----------|-----------|
| 2.0 | 0.5   | 3.133   | 3.096    | 25.4%   | 0.102     | +16.7%    |
| 4.0 | 0.5   | 3.141   | 3.110    | 27.6%   | 0.077     | +17.2%    |
| 4.0 | 0.7   | 3.263   | 3.243    | 22.4%   | 0.061     | +22.2%    |
| 4.0 | 0.9   | 3.370   | 3.358    | 13.1%   | 0.052     | +26.6%    |
| 8.0 | 0.7   | 3.256   | 3.242    | 26.8%   | 0.035     | +22.2%    |

### Gap Analysis

```
  Teacher-to-Scratch gap:    -0.622 loss (Phi6 BETTER than GELU!)
  Teacher-to-Distilled gap:  -0.179 loss (distilled also better)
  Distillation KL reduction:  49.2%
  Gap closed by distillation: 71.3%

  Loss comparison (lower = better):
  GELU Teacher     |########################################| 3.275
  Phi6 Scratch     |################################........| 2.653  <-- BEST
  Phi6 Distill     |#####################################...| 3.096
```

## Key Finding: Distillation HURTS Phi6

This is the most important result: **distilling from a GELU teacher makes Phi6 WORSE**.

```
  Phi6 from scratch:  loss = 2.653 (34.2% accuracy)
  Phi6 distilled:     loss = 3.096 (25.4% accuracy)
  Delta:              +0.443 loss (+16.7% worse!)
```

The GELU teacher is a WORSE model than what Phi6 can learn on its own.
Distillation forces the Phi6 student to mimic the teacher's inferior representations.

## Interpretation

1. **Phi6 does not need distillation from GELU** -- it outperforms GELU from scratch.
   This means migration from GELU to Phi6 should be done via retraining, not distillation.

2. **The hypothesis is technically SUPPORTED** (distilled student within 5% of teacher),
   but the framing is backwards: Phi6 is the better activation, so the interesting
   distillation direction would be Phi6-teacher to GELU-student.

3. **KL divergence decreases with higher T and alpha**, confirming distillation works
   mechanically. The 49.2% KL reduction shows soft targets are being transferred.

4. **Higher alpha (more KD weight) makes performance WORSE**: the more the student
   imitates the inferior teacher, the worse it gets.

## Limitations

- Small scale (2-layer MLP, structured task)
- GELU underperformance may be task-specific
- At large scale with more data, GELU may be competitive
- Only tested with simple SGD optimizer

## Verification Direction

- Test distillation in the OTHER direction (Phi6 teacher -> GELU student)
- Test at larger scale where GELU's advantages may emerge
- Test with Adam optimizer and learning rate scheduling
- Test on tasks where GELU is known to excel

## Grade: SUPPORTED

The distilled Phi6 student matches the GELU teacher within 5.5% (3.096 vs 3.275),
confirming distillation works. However, the practical recommendation is to NOT distill --
Phi6 achieves 2.653 loss from scratch, significantly better than the teacher.

## Script

`experiments/h_ee_4_knowledge_distillation.py`
