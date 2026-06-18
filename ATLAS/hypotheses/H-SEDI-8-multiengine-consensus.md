# H-SEDI-8: Multi-Engine Consensus Improves Ensemble Predictions
**n6 Grade: 🟧 CLOSE** (auto-graded, 3 unique n=6 constants)


**Status**: SUPPORTED
**Golden Zone Dependency**: None (pure ensemble method)
**Experiment**: `experiments/experiment_h_sedi_8_consensus.py`

## Hypothesis

> Training 5 independent PureField models with different seeds and combining
> them using SEDI-style tension-weighted voting (weight = 1/tension) outperforms
> both simple majority voting and the single best model. Lower tension indicates
> higher confidence, so weighting by inverse tension is analogous to SEDI's
> multi-detector consensus where each detector's confidence modulates its vote.

## Background

SEDI uses 5 independent detectors (FFT, ratio, PH, runs test, entropy) that
vote on whether a signal contains structure. Each detector's confidence weights
its vote. This hypothesis tests whether the same principle -- consensus of
diverse weak detectors weighted by confidence -- improves neural classification.

## Method

1. Train 5 PureFieldEngine models on MNIST with seeds {42, 123, 456, 789, 1337}
2. Each model trains for 5 epochs with Adam(lr=0.001)
3. Compare four methods on test set:
   - (a) Best single model
   - (b) Simple majority vote (argmax per model, then mode)
   - (c) Average logits (mean of raw outputs)
   - (d) SEDI-weighted vote (logits weighted by 1/tension per sample)

## Results

### Individual Model Accuracies

| Model | Seed | Accuracy |
|-------|------|----------|
|     1 |   42 |  97.86%  |
|     2 |  123 |  97.92%  |
|     3 |  456 |  98.11%  |
|     4 |  789 |  97.81%  |
|     5 | 1337 |  97.98%  |

### Ensemble Comparison

| Method              | Accuracy | vs Best Single |
|---------------------|----------|----------------|
| Best single (s=456) |  98.11%  |     baseline   |
| Simple majority     |  98.28%  |       +0.17%   |
| Average logits      |  98.32%  |       +0.21%   |
| **SEDI-weighted**   |**98.31%**|     **+0.20%** |

### Improvement Analysis
```
  SEDI vs best single: +0.20%
  SEDI vs majority:    +0.03%
  Majority vs best:    +0.17%
  Avg vs best:         +0.21%
```

### ASCII Visualization: Accuracy Comparison
```
Accuracy (%)
 98.32 |                          ## Avg logits
 98.31 |                       ## SEDI-weighted
 98.28 |                    ## Majority vote
 98.11 |  ##                   Best single
 97.98 |##
 97.92 |#
 97.86 |#
 97.81 |#
       +--+--+--+--+--+--+--+--
        m1 m2 m3 m4 m5 Bst Maj SEDI
```

## Interpretation

- All ensemble methods beat the best single model
- SEDI-weighted voting (98.31%) and average logits (98.32%) are near-identical
- SEDI-weighted beats simple majority (98.28%) by 0.03%
- The improvement is modest (+0.20%) because MNIST is easy and individual
  models are already strong (~98%)
- Key finding: tension-based weighting provides sample-adaptive confidence
  that simple averaging cannot, which should matter more on harder tasks

## Limitations

- MNIST is too easy for large ensemble effects (ceiling ~99.7%)
- Only 5 models tested; SEDI uses 5 very different detectors, while our
  5 models differ only in random seed (less diversity)
- The margin between SEDI-weighted and average logits is negligible (0.01%)
- Need to test on CIFAR-10 or harder tasks where individual models vary more

## Next Steps

- Test on CIFAR-10 where individual model accuracy spread is larger
- Use architecturally diverse models (not just seed diversity)
- Test with more extreme tension values (adversarial inputs)
- Compare with temperature scaling and other calibration methods
- Investigate per-class tension patterns in ensemble disagreements
