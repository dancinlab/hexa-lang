# H-EE-54: Quantum Error Correction Overhead = tau(6)/sigma(6) = 1/3
**n6 Grade: 🟧 CLOSE** (auto-graded, 3 unique n=6 constants)


## Hypothesis

> The optimal ratio of physical to logical qubits for fault-tolerant quantum computation is sigma(6)/tau(6) = 3:1. Three physical qubits per logical qubit achieves the error correction threshold while minimizing overhead, matching the phi-bottleneck compression ratio.

## Background

- Quantum error correction: encode logical qubits in physical qubits
- Typical overhead: 10-1000 physical per logical (surface codes)
- Theoretical minimum for distance-3 code: 5 physical per 1 logical (Laflamme bound)
- n=6 prediction: sigma/tau = 12/4 = 3 physical per logical
- This matches the [[3,1,1]] repetition code (simplest QEC)
- Phi-bottleneck: 4/3x expansion = 1/3 compression (same ratio)

## Predictions

1. The most energy-efficient QEC code has rate k/n = tau/sigma = 1/3
2. Higher-distance codes approach this ratio asymptotically
3. The 1/3 ratio balances error correction capability against qubit overhead
4. Quantum computers operating at this ratio achieve R=1 in quantum information space

## Conclusion

**Status:** Testable — compare QEC codes at various rates
**Bridge:** Quantum computing ↔ phi-bottleneck ↔ n=6
