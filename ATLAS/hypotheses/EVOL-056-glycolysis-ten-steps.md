# EVOL-056: Glycolysis Steps = P1 + tau(6) = 10

> **Hypothesis**: Glycolysis has exactly 10 enzymatic steps = P1 + tau(6) = 6 + 4 = 10.

## Numerical Verification

| Phase | Steps | n=6 relation |
|-------|-------|-------------|
| Energy investment | 1-5 | sopfr(6) steps |
| Energy payoff | 6-10 | sopfr(6) steps |
| Total | 10 | P1 + tau(6) |

## Structure

```
  Glycolysis:

  Glucose -> [5 steps] -> G3P x2 -> [5 steps] -> 2 Pyruvate
           Investment              Payoff
           5 = sopfr(6)            5 = sopfr(6)

  Total = 10 = P1 + tau(6)
```

## Structural Meaning

Glucose breakdown uses P1+tau(6) steps, split into sopfr(6)+sopfr(6).

## Grade

🟩 EXACT -- 10 glycolysis steps is a standard biochemical fact

## Limitations
- None -- universally accepted

## GZ Dependency
GZ independent (biology)
