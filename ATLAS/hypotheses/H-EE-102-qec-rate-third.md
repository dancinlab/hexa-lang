# H-EE-102: Optimal QEC Code Rate Converges to 1/3 — FUTURE PREDICTION
**n6 Grade: 🟩 EXACT** (auto-graded, 8 unique n=6 constants)


## Hypothesis

> As quantum hardware scales and fault-tolerant quantum computing matures,
> the optimal quantum error correction code rate will converge to 1/3 = tau(6)/sigma(6).
> This is the natural rate for codes balanced by n=6 arithmetic.

## Background

- Quantum error correction (QEC) encodes k logical qubits in n physical qubits
- Code rate R_code = k/n (higher is more efficient, lower is more protected)
- Current best rates: surface code ~0.01-0.1, LDPC codes ~0.1-0.2
- Information-theoretic upper bound (hashing bound): ~0.5 for depolarizing channel

## The 1/3 Prediction

tau(6) = 4 (number of divisors)
sigma(6) = 12 (sum of divisors)
Ratio: tau(6)/sigma(6) = 4/12 = 1/3

The prediction: 1/3 is the Pareto-optimal code rate for the
fault-tolerance vs. efficiency tradeoff on near-term quantum hardware
(gate error rate ~0.1-1%).

## Why 1/3 Is Natural

For a [[n,k,d]] code:
- Rate 1/3: encode 1 logical qubit in 3 physical qubits (minimal repetition code)
- The 3-qubit bit-flip code achieves rate 1/3 and corrects 1 error
- More sophisticated [[n, n/3, d]] families approach rate 1/3 with growing distance

The divisor structure of n=6:
  Divisors: 1, 2, 3, 6
  tau(6) = 4 divisors, sigma(6) = 12 sum
  tau/sigma = 1/3 selects the "three-fold" encoding as natural

## Comparison to Known Code Rates

| Code Family              | Rate     | Distance |
|--------------------------|----------|----------|
| 3-qubit repetition       | 1/3      | 1        |
| [[7,1,3]] Steane code    | 1/7      | 3        |
| [[5,1,3]] perfect code   | 1/5      | 3        |
| Surface code (distance d)| ~1/d^2   | d        |
| Good LDPC (asymptotic)   | ~0.1-0.2 | sqrt(n)  |
| **n=6 prediction**       | **1/3**  | optimal  |

At moderate error rates (~0.5%), the 1/3 rate family should dominate.

## Testability

- Large-scale QEC experiments on 50-500 qubit systems
- Sweep over code rates for a fixed error budget
- Check if 1/3 consistently appears at the Pareto knee
- Timeline: Testable 2026-2028 (IBM, Google, IonQ platforms)

## Conclusion

**Status: Pre-registered future prediction — testable 2026-2028**
**Prediction:** Optimal QEC code rate converges to 1/3 = tau(6)/sigma(6) on near-term hardware
**Falsification:** Optimal rate consistently outside [0.28, 0.38] across multiple platforms.
