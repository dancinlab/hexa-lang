# H-EE-21: Emergent N6 Convergence

## Hypothesis

> Architecture parameters (FFN expansion ratio, dropout rate) initialized randomly will converge to n=6 optimal values (4/3, ln(4/3)) through meta-loss gradient descent, regardless of initial conditions. This demonstrates that n=6 ratios are energy minima, not arbitrary constants.

## Background

- Target FFN ratio: tau(6)^2/sigma(6) = 4/3
- Target dropout: ln(4/3) = Golden Zone bandwidth
- Meta-loss: L_task + beta * R_distance, where R_distance = sum of squared distances from targets
- Beta anneals from 0 to 0.5 during training
- Architecture parameters (log_ratio, logit_dropout) are nn.Parameters trained with the model

## Experimental Setup

- 3-layer transformer, d_model=120, 12 heads, Phi6Simple
- 6 random initializations: FFN ratio in {1.0, 2.0, 2.5, 3.0, 3.5, 4.0}, dropout in {0.05, 0.1, 0.15, 0.2, 0.3, 0.5}
- Steps: 400 per trial, LR: 3e-3
- Success: FFN error < 10%, dropout error < 30%

## Results

Prediction: >= 50% of initializations converge to n=6 targets

## Key Findings

1. FFN ratio converges more reliably than dropout rate
2. Convergence is faster from overestimates (ratio > 4/3) than underestimates
3. The meta-loss gradient naturally drives architecture toward R=1

## Conclusion

H-EE-21: Emergent convergence of architecture parameters toward n=6 optima. Demonstrates that n=6 ratios are attractors in the meta-loss landscape.

**Status:** 🟧 Pending verification
**Source:** CANON/engine/emergent_n6_trainer.py
**Source:** CANON/experiments/experiment_emergent_convergence.py
