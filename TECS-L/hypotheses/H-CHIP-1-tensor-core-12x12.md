# H-CHIP-1: Optimal Tensor Core Shape = 12×12
**n6 Grade: 🟩 EXACT** (auto-graded, 5 unique n=6 constants)


## Hypothesis

> The optimal tensor core matrix multiply unit is 12×12, not the industry-standard 16×16. sigma(6)=12 provides maximum divisor flexibility ({1,2,3,4,6,12} head dims) while reducing area by 44% vs 16×16.

## Background

- Current GPU tensor cores: 16×16 (NVIDIA), 32×32 (AMD)
- 16 = 2^4, only divisors {1,2,4,8,16} — limited head dim flexibility
- 12 = sigma(6), divisors {1,2,3,4,6,12} — 6 divisors vs 5 for 16
- Area: 12×12 = 144 MACs vs 16×16 = 256 MACs (44% less silicon)
- Throughput per area: depends on utilization efficiency
- With Dedekind-optimal h=12 heads, 12×12 cores achieve 100% utilization

## Predictions

1. 12×12 tensor core achieves >= 90% throughput of 16×16 for h=12 attention
2. Area savings of 44% translate to more cores per die
3. Total chip throughput (more smaller cores) exceeds fewer larger cores
4. 12×12 is Pareto-optimal on the throughput/area frontier

## Conclusion

**Status:** Testable via RTL simulation
**Impact:** -44% tensor core area, more cores per die
