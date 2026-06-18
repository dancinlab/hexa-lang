# H-CHIP-35: Photonic Tensor Core = 12x12 MZI Mesh
**n6 Grade: 🟧 CLOSE** (auto-graded, 3 unique n=6 constants)


## Hypothesis

> A 12x12 Mach-Zehnder interferometer mesh for optical matrix multiplication uses 66 MZI elements vs 120 for 16x16 — a 45% reduction in optical components while maintaining sigma(6)=12 divisor flexibility for head dimensions.

## Background

- Clements decomposition: NxN unitary requires N(N-1)/2 MZI elements
- 12x12: 12*11/2 = 66 MZI
- 16x16: 16*15/2 = 120 MZI
- Reduction: 66/120 = 55% of 16x16 (45% fewer components)
- Each MZI: 2 phase shifters + 2 beam splitters → significant cost per element
- Photonic chips (Lightmatter, Luminous) use MZI meshes for inference
- 12x12 maintains compatibility with head_dim divisors {1,2,3,4,6,12}

## Predictions

1. 12x12 photonic core achieves >= 85% throughput of 16x16 for h=12 attention
2. Manufacturing yield improves with fewer MZI (fewer defect opportunities)
3. Power consumption: ~45% less (fewer phase shifters to tune)
4. 12x12 is the photonic Pareto optimum (components vs throughput)

## Conclusion

**Status:** Testable — photonic simulation
**Impact:** Significant cost reduction for optical AI accelerators
