# EVOL-055: Krebs Cycle Steps = 2^(P1/2) = 8

> **Hypothesis**: The citric acid (Krebs) cycle has 8 enzymatic steps = 2^(P1/2) = 8.

## Numerical Verification

| # | Enzyme | Substrate -> Product |
|---|--------|---------------------|
| 1 | Citrate synthase | OAA + Acetyl-CoA -> Citrate |
| 2 | Aconitase | Citrate -> Isocitrate |
| 3 | Isocitrate DH | Isocitrate -> alpha-KG |
| 4 | alpha-KG DH | alpha-KG -> Succinyl-CoA |
| 5 | Succinyl-CoA synthetase | Succinyl-CoA -> Succinate |
| 6 | Succinate DH | Succinate -> Fumarate |
| 7 | Fumarase | Fumarate -> Malate |
| 8 | Malate DH | Malate -> OAA |

## Structure

```
  Krebs Cycle (circular):

  OAA -1-> Citrate -2-> Isocitrate
   ^                        |
   8                        3
   |                        v
  Malate              alpha-KG
   ^                        |
   7                        4
   |                        v
  Fumarate <-6- Succinate <-5- Succinyl-CoA

  Steps = 8 = 2^(P1/2)
```

## Structural Meaning

Central metabolism cycles through 2^(P1/2) enzymatic reactions.

## Grade

🟩 EXACT -- 8 steps in the Krebs cycle is standard biochemistry

## Limitations
- None -- universally accepted

## GZ Dependency
GZ independent (biology)
