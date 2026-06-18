# H-EE-118: Egyptian Routing Applied to Hypotheses — Optimal Research Allocation
**n6 Grade: 🟩 EXACT** (auto-graded, 5 unique n=6 constants)


## Hypothesis (META)

> Apply the Egyptian MoE routing (H-EE-egyptian-moe: 1/2 + 1/3 + 1/6 = 1)
> to the 92+ hypotheses in this system. Top 1/2 (46 hypotheses) receive
> 50% of verification effort. Next 1/3 (31 hypotheses) receive 33%.
> Bottom 1/6 (15 hypotheses) receive 17%. This allocation optimizes
> research resource usage under the framework's own routing principle.

## Background: Egyptian MoE Routing

The Egyptian fraction identity: 1/2 + 1/3 + 1/6 = 1

Applied to expert routing in MoE transformers:
  - 1/2 of tokens -> Expert 1 (high-priority)
  - 1/3 of tokens -> Expert 2 (medium-priority)
  - 1/6 of tokens -> Expert 3 (low-priority)

H-EE-118 applies this same routing to research hypotheses.

## Allocation Table

Total hypotheses as of H-EE-120: 120
  - Top tier (1/2): hypotheses 1-60   -> 50% effort
  - Mid tier  (1/3): hypotheses 61-100 -> 33% effort
  - Low tier  (1/6): hypotheses 101-120 -> 17% effort

(Note: exact partition should be by impact/testability rank, not just number order)

## Priority Ranking Criteria

A hypothesis receives high priority (top 1/2) if it satisfies:
  1. Testable with current resources (< 1 GPU-week)
  2. Falsifiable (clear failure criterion)
  3. High leverage (falsification or confirmation changes many other hypotheses)

A hypothesis receives low priority (bottom 1/6) if it satisfies:
  1. Requires resources > 100 GPU-years, or
  2. Purely philosophical (H-EE-115, H-EE-116), or
  3. Awaiting external results (H-EE-99, H-EE-100)

## Suggested Priority Rankings

### Top tier (50% effort):
  - H-EE-107 (confirmation bias) — critical to validate entire framework
  - H-EE-108 (finite-size) — run 100M param experiment
  - H-EE-98  (scale dependence) — same as above
  - H-EE-4   (entropy early stopping) — already demonstrated, extend
  - H-EE-11  (combined architecture) — run at 10M params
  - H-EE-117 (R fixed point) — verify computationally to n=10^6

### Mid tier (33% effort):
  - H-EE-111 (variational principle) — theoretical work
  - H-EE-112 (L-function) — requires specialist consultation
  - H-EE-113 (category theory) — theoretical work
  - H-EE-106 (deeper equation) — theoretical work

### Low tier (17% effort):
  - H-EE-114 (arithmetic multiverse) — speculative, deprioritize
  - H-EE-115 (anthropic arithmetic) — philosophical, low ROI
  - H-EE-116 (string landscape) — highly speculative
  - H-EE-110 (cultural bias) — interesting but not blocking
  - H-EE-119 (optimal document size) — self-referential

## Why Egyptian Routing Is Optimal Here

The 1/2+1/3+1/6 allocation matches the Pareto principle:
  - 50% of effort -> hypotheses with 80% of expected value
  - 17% of effort -> hypotheses with <5% of expected value (but must not be ignored)
  - The 1/6 "low" tier is not zero — unlike Pareto, nothing is discarded

## Conclusion

**Status: Practical recommendation — actionable now**
**Implementation:** Sort hypotheses by testability*leverage score, apply 1/2:1/3:1/6 split
**Meta-point:** The framework's own routing principle is optimal for managing the framework

*Written: 2026-03-28*
