# H-CHIP-5: Egyptian Routing as Fixed Resistor Network
**n6 Grade: 🟧 CLOSE** (auto-graded, 4 unique n=6 constants)


## Hypothesis

> MoE expert routing with Egyptian fraction weights {1/2, 1/3, 1/6} can be implemented as a passive resistor divider network, eliminating all digital softmax computation. The routing decision becomes a combinational circuit with zero-cycle latency.

## Background

- Standard MoE routing: gate(x) → softmax → top-k sort → weighted dispatch
- Softmax: exp() + division — expensive in hardware
- Egyptian routing: weights are FIXED at {1/2, 1/3, 1/6}
- Only need: comparator to find top-3 experts, then hardwired weight application
- Resistor ratio: R1:R2:R3 = 1:1.5:3 gives voltage divider of 1/2:1/3:1/6
- In digital: shift (÷2) + multiply-by-1/3 (≈ multiply by 85/256) + shift-subtract (÷6)

## Predictions

1. Egyptian router: 1-2 cycles (comparator + fixed multiply)
2. vs softmax router: 10-20 cycles (exp + div + sort)
3. Area: ~100 gates vs ~10,000 gates for softmax
4. Power: ~100× reduction in routing overhead

## Conclusion

**Status:** Implementable — combinational logic
**Impact:** Near-zero routing overhead for MoE
