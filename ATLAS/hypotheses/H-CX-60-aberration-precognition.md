# H-CX-60: Aberration Precognition — Precognition failure types map to Seidel aberrations
**n6 Grade: 🟩 EXACT** (auto-graded, 5 unique n=6 constants)


> Class-specific AUC deviations in precognition are structurally isomorphic to lens aberrations (H-GEO-9).
> 5 Seidel aberrations = 5 precognition failure modes.

## Background

- H-GEO-9: 5 Seidel aberrations in R spectrum (chromatic/spherical/astigmatic/coma/distortion)
- Precognition: AUC=0.925 but with class-specific deviations
- H339/H341: Direction+magnitude decomposition

**Key connection**: Why precognition isn't perfect = lens aberrations.
Each aberration type corresponds to specific precognition failure patterns.

## Aberration-Precognition Mapping

| Seidel Aberration | R Spectrum (H-GEO-9) | Precognition Failure Mode |
|---|---|---|
| Chromatic | f(p,1) prime-specific differences | Class-specific AUC deviations |
| Spherical | Density profile around R=1 | Mid-tension range uncertainty |
| Astigmatic | R-S asymmetry | Direction vs magnitude asymmetry |
| Coma | Asymmetric gaps delta-/delta+ | Overconfidence vs underconfidence asymmetry |
| Distortion | R-chain distribution | Epoch-wise precognition accuracy distortion |

## Predictions

1. Class-specific AUC deviation patterns follow "chromatic aberration" structure (similar classes have lower AUC)
2. Mid-tension range precognition failure rate follows "spherical aberration" pattern (U-shaped)
3. Direction stability vs magnitude stability asymmetry = "astigmatism"
4. Overconfident wrong (high tension + wrong) vs underconfident correct (low tension + correct) asymmetry = "coma"
5. Early vs late training precognition pattern changes = "distortion"

## ASCII Aberration Spectrum

```
  AUC
  1.0 |  0   1       2           6   7
  0.9 |          3       5
  0.8 |              4       8
  0.7 |                          9
      +--+--+--+--+--+--+--+--+--+--→ Class
       0  1  2  3  4  5  6  7  8  9

  Chromatic: Similar classes (3/8, 4/9) converge
  Astigmatic: Direction stability ≠ Magnitude stability
```

## Verification Method

```
1. Train PureFieldEngine (3 datasets)
2. Calculate class-specific precognition AUC (chromatic)
3. Tension 5-quantile precognition accuracy (spherical)
4. Compare direction std vs magnitude std (astigmatic)
5. Compare overconfidence/underconfidence ratios (coma)
6. Epoch-wise precognition AUC trends (distortion)
```

## Related Hypotheses

- H-GEO-9 (lens aberration classification), H-CX-58 (precognition lens)
- H316 (similar class overconfidence), H339 (direction=concept)

## Limitations

- 5-aberration mapping may be forced (over-fitting to metaphor)
- Aberration correction methods unclear

## Verification Status

- [x] Measure 5 aberrations
- [ ] Inter-aberration correlations
- [ ] Explore correction possibilities

## Verification Results

**PARTIAL (3/5 aberrations confirmed)**

| Aberration Type | Result | Details |
|---|---|---|
| Chromatic | SUPPORTED | Fashion Trouser AUC=0.971 vs Sneaker=0.267 — extreme class-specific deviations |
| Spherical | REJECTED | Monotonic increase pattern, not U-shaped |
| Astigmatic | SUPPORTED | dir_std << mag_std consistent (ratio 0.01-0.09) |
| Coma | SUPPORTED (MNIST/Fashion) | Extreme asymmetry — MNIST over/under=0.010 |
| Distortion | SUPPORTED | HIGH in all datasets (5-9 reversals in 14 epochs) |

```
  Aberration Scorecard:
  Chromatic   ████████████████████  SUPPORTED
  Spherical   ░░░░░░░░░░░░░░░░░░░░  REJECTED (monotonic, not U-shape)
  Astigmatic  ████████████████████  SUPPORTED
  Coma        ██████████████░░░░░░  SUPPORTED (MNIST/Fashion)
  Distortion  ████████████████████  SUPPORTED

  3/5 confirmed → PARTIAL support
```

- Only spherical aberration rejected: mid-tension range uncertainty is monotonically increasing, not U-shaped
- Astigmatism most clear: direction stability 1-2 orders of magnitude lower than magnitude stability
- Coma asymmetry extreme: overconfident wrong vastly outnumbered by underconfident correct