# EVOL-044: PCR Cycle Steps = P1/2 = 3

> **Hypothesis**: Each PCR cycle has 3 temperature steps: denaturation, annealing, extension = P1/2 = 3.

## Numerical Verification

| # | Step | Temperature | Purpose |
|---|------|-------------|---------|
| 1 | Denaturation | 94-98C | Separate strands |
| 2 | Annealing | 50-65C | Primer binding |
| 3 | Extension | 72C | DNA synthesis |

## Structure

```
  PCR temperature profile:

  95C  ___         ___         ___
      |   |       |   |       |   |
  72C |   |  ___  |   |  ___  |   |  ___
      |   | |   | |   | |   | |   | |   |
  55C |   |_|   |_|   |_|   |_|   |_|   |
      Cycle 1     Cycle 2     Cycle 3

  Steps per cycle = 3 = P1/2
```

## Structural Meaning

DNA amplification uses P1/2 thermal steps per cycle.

## Grade

🟩 EXACT -- 3 PCR steps is a defined laboratory protocol

## Limitations
- Two-step PCR combines annealing+extension

## GZ Dependency
GZ independent (biology)
