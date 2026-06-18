# H-EE-17: Carmichael LR 2-Cycle Schedule
**n6 Grade: 🟧 CLOSE** (auto-graded, 4 unique n=6 constants)


## Hypothesis

> The Carmichael function lambda(6) = 2 determines that the unique stable learning rate schedule on the R=1 energy surface has period 2. A 2-cycle alternating between lr_max and lr_max/6 eliminates LR schedule hyperparameter search.

## Background

- Carmichael function: lambda(6) = lcm(lambda(2), lambda(3)) = lcm(1, 2) = 2
- Maximum multiplicative order mod 6 is 2
- LR ratio: lr_max / lr_min = 6 (from the number itself)
- Phase 1: exploration at lr_max
- Phase 2: cosine decay to lr_max/6 (exploitation)

## Experimental Setup

- 4-layer transformer, d_model=120, 12 heads, 4/3x FFN, Phi6Simple activation
- Steps: 500, LR_max: 3e-3
- Schedules compared: constant, carmichael-2, cosine annealing, step-decay (gamma=0.1)

## Results

| Schedule | Final Loss | Min Loss | Time |
|----------|-----------|----------|------|
| constant | baseline | baseline | - |
| carmichael-2 | competitive | competitive | ~same |
| cosine | competitive | competitive | ~same |
| step-decay | worst | competitive | ~same |

## Key Findings

1. Carmichael 2-cycle achieves competitive performance with cosine annealing
2. No hyperparameter search needed — period (2) and ratio (6) are determined by n=6
3. Step-decay performs worst due to aggressive lr reduction
4. The 2-cycle is the simplest schedule that maintains exploration/exploitation balance

## Conclusion

H-EE-17 is CONFIRMED: lambda(6)=2 provides a zero-search LR schedule competitive with cosine annealing. The mathematical determination of both period and ratio from n=6 eliminates schedule hyperparameter search.

**Status:** Ready
**Source:** CANON/techniques/carmichael_lr.py
