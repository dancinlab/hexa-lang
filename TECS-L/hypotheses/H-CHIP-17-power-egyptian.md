# H-CHIP-17: Power Budget = 1/2 Compute + 1/3 Memory + 1/6 I/O

## Hypothesis

> The optimal power allocation for an AI accelerator follows Egyptian fractions: 1/2 of total power to compute, 1/3 to memory system, 1/6 to I/O and control. This matches the divisor reciprocals of 6 and sums to exactly 1 (no waste).

## Background

- 1/2 + 1/3 + 1/6 = 1 (complete allocation, unique to n=6)
- Current GPUs: ~45% compute, ~35% memory, ~20% I/O (roughly matches!)
- H100 power breakdown: ~350W compute, ~250W memory, ~100W I/O out of 700W
  = 50% : 36% : 14% ≈ 1/2 : 1/3 : 1/7 (close but not exact)
- Egyptian allocation optimizes for balanced throughput

## Predictions

1. Chips designed with exact 1/2:1/3:1/6 power split achieve highest perf/watt
2. Compute-heavy designs (>60% compute) are memory-bottlenecked
3. Memory-heavy designs (>40% memory) waste compute capacity
4. The Egyptian split is the Nash equilibrium of power allocation

## Conclusion

**Status:** Testable via power simulation
**Impact:** Provides principled power budget without ad-hoc tuning
