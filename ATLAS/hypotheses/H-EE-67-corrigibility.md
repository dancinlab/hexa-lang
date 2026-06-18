# H-EE-67: Corrigibility = phi(6)/tau(6) = 1/2

## Hypothesis

> A corrigible AI reserves exactly phi(6)/tau(6) = 2/4 = 1/2 of its decision weight for
> human override. The remaining weight follows Egyptian fraction routing:
> 1/3 to the AI's primary decision channel and 1/6 to AI fallback/exploration.
> Together: 1/2 (human) + 1/3 (AI primary) + 1/6 (AI fallback) = 1.
> This is the n=6 arithmetic architecture for safe autonomy.

## Background

- Corrigibility: an AI's property of accepting correction, shutdown, or modification
- Stuart Russell's CIRL: uncertainty about human preferences drives corrigibility
- phi(6) = 2 (Euler's totient: numbers coprime to 6 in {1,...,6}: {1,5})
- tau(6) = 4 (number of divisors: {1,2,3,6})
- phi(6)/tau(6) = 2/4 = 1/2: the "human channel" fraction
- Egyptian fraction decomposition: 1 = 1/2 + 1/3 + 1/6 (exactly)
- This is also the expert routing used in H-EE-45 (Egyptian MoE)

## The Corrigibility Architecture

```
Decision weight allocation (sums to 1):
  1/2 = phi(6)/tau(6)    -- Human override channel
  1/3 = 1/tau(6)*...     -- AI primary reasoning
  1/6 = 1/sigma(6)/2     -- AI exploration/fallback

Properties:
  - Human retains majority (1/2 > 1/3 + 1/6 would hold iff 1/2 > 1/2: NO)
  - Human has equal weight to AI total: 1/2 = 1/3 + 1/6 (exact balance)
  - This is R=1 corrigibility: neither human nor AI dominates
```

## Predictions

1. AI systems with 1/2 human / 1/2 AI decision weighting show optimal safety-capability tradeoff
2. Less corrigible systems (human weight < 1/2) show higher capability but higher risk
3. More corrigible systems (human weight > 1/2) are safe but underperform on hard tasks
4. The 1/2:1/3:1/6 routing is a stable Nash equilibrium for human-AI cooperation

## Conclusion

**Status:** Framework proposal
**Bridge:** Corrigibility ↔ phi(6)/tau(6) ↔ Egyptian fraction routing ↔ AI safety
