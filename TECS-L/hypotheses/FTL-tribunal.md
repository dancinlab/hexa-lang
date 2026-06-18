# FTL Tribunal: Systematic Classification of 15 Faster-Than-Light Mechanisms

## Observation

> Of the 15 known FTL mechanisms in physics, a systematic tribunal reveals only 2 are
> "allowed" (and neither achieves real FTL), 4 are conditional on exotic matter, 3 are
> illusory, 2 are forbidden, and 4 are speculative. Separately, the Schwarzschild black
> hole radii {2M, 3M, 6M} map exactly onto the proper divisors of 6: {2, 3, 6}.
> This GR coefficient correspondence is SPECULATIVE — the tribunal classification is the
> primary result.

## Status

- **Tribunal classification**: VERIFIED (standard physics)
- **n=6 GR coefficient observation**: SPECULATIVE (exact match, interpretation unproven)
- **GZ dependency**: Independent (no Golden Zone model required)
- **Date**: 2026-04-03
- **Calculators**: `calc/ftl_tribunal.py`, `calc/gr_coefficients.py`

## Background

Faster-than-light travel is one of the most explored topics in theoretical physics.
Despite popular fascination, no experimentally confirmed FTL mechanism exists. The
physics community has produced at least 15 distinct proposals, each with different
theoretical foundations and different failure modes.

This document provides two contributions:
1. A systematic tribunal classifying all 15 mechanisms by feasibility verdict
2. An observation that Schwarzschild BH characteristic radii coincide with divisors of 6

The first contribution stands on standard physics. The second is a pattern observation
whose significance is debatable (Texas Sharpshooter Z=3.39, p<0.01).

## FTL Tribunal: 15 Mechanisms

| # | Mechanism | Verdict | Basis | Key Obstacle |
|---|-----------|---------|-------|-------------|
| 1 | Cherenkov radiation | ALLOWED | Medium v < c, particle v > medium v | Not real FTL (v < c in vacuum) |
| 2 | Inflationary expansion | ALLOWED | Metric expansion, not local motion | Not real FTL (no information transfer) |
| 3 | Alcubierre warp drive | CONDITIONAL | GR solution exists | Requires negative energy density (exotic matter) |
| 4 | Traversable wormhole | CONDITIONAL | Einstein-Rosen bridge + exotic matter | Requires exotic matter to stabilize throat |
| 5 | Casimir effect propulsion | CONDITIONAL | Negative energy density measured | Energy density far too small for macroscopic warp |
| 6 | Krasnikov tube | CONDITIONAL | GR-consistent spacetime modification | Requires exotic matter; causality issues |
| 7 | Quantum tunneling | ILLUSORY | Tunneling time debate | No superluminal information transfer (Hartman) |
| 8 | Phase velocity > c | ILLUSORY | Wave dispersion | No energy/information transfer at v > c |
| 9 | Group velocity > c | ILLUSORY | Anomalous dispersion media | Signal velocity remains <= c |
| 10 | Tachyons | FORBIDDEN | Hypothetical m² < 0 particles | Violates causality; no experimental evidence |
| 11 | Entanglement FTL comm | FORBIDDEN | Bell nonlocality | No-communication theorem (proven) |
| 12 | T-duality (string) | SPECULATIVE | String theory R ↔ l_s²/R | No experimental access to string scale |
| 13 | Variable speed of light | SPECULATIVE | c = c(t) cosmologies (Magueijo) | No confirmed observational signature |
| 14 | Noncommutative geometry | SPECULATIVE | Modified dispersion relations | Planck-scale effects, untestable currently |
| 15 | Loop quantum gravity | SPECULATIVE | Discrete spacetime granularity | Framework incomplete; no FTL prediction |

### Verdict Summary

```
  ALLOWED      2/15  (13%)  — Not real FTL; subluminal in vacuum
  CONDITIONAL  4/15  (27%)  — GR-valid solutions requiring exotic matter
  ILLUSORY     3/15  (20%)  — Apparent superluminality, no info transfer
  FORBIDDEN    2/15  (13%)  — Violate fundamental theorems
  SPECULATIVE  4/15  (27%)  — Framework-dependent, untestable currently
```

**Bottom line**: Zero mechanisms provide confirmed, usable FTL. The "best" candidates
(Alcubierre, wormholes) require exotic matter with negative energy density, which has
never been produced at macroscopic scale.

## GR Coefficient Discovery: {2, 3, 6} = Proper Divisors of 6

### Schwarzschild Black Hole Characteristic Radii

```
  Schwarzschild radius   r_s  = 2GM/c²    coefficient = 2 = phi(6)
  Photon sphere          r_ph = 3GM/c²    coefficient = 3 = sigma(6)/tau(6)
  ISCO                   r_ISCO = 6GM/c²  coefficient = 6 = n
```

All three coefficients are proper divisors of the first perfect number 6.
The divisor lattice structure maps onto the BH spacetime zones:

### Divisor Lattice ↔ BH Spacetime (ASCII Diagram)

```
        6 = n (ISCO — last stable orbit)
       / \
      3   2
      |   |
      3 = sigma/tau (Photon sphere — light trapping)
      |
      2 = phi (Event horizon — causal boundary)
      |
      1 (Singularity — information endpoint)

  Divisor lattice of 6:     BH spacetime structure:

      6                         ISCO (6M)
     / \                          |
    2   3                   Photon sphere (3M)
     \ /                          |
      1                   Event horizon (2M)
                                  |
                            Singularity (0)

  Radial ordering: 0 → 2M → 3M → 6M
  Divisor ordering: 1 → 2  → 3  → 6
```

The map is: divisor d → radius coefficient d×GM/c² (with 1 → singularity at r=0).

## n=6 Match / Non-Match Table

| # | Quantity | Value | n=6 Match? | Notes |
|---|----------|-------|-----------|-------|
| 1 | ISCO coefficient | 6 | YES (exact) | = n, the perfect number itself |
| 2 | Photon sphere coefficient | 3 | YES (exact) | = sigma/tau = 12/4 |
| 3 | Schwarzschild coefficient | 2 | YES (exact) | = phi(6) = Euler totient |
| 4 | Divisor set completeness | {1,2,3,6} | YES (exact) | All divisors of 6 appear |
| 5 | BH temperature T_H ∝ 1/(8piM) | 8pi | WEAK | 8 = 2³, no clean n=6 form |
| 6 | Bekenstein-Hawking S = A/4 | 4 | MARGINAL | = tau(6), but small integer |
| 7 | Kerr ISCO (prograde) | 1-6 range | PARTIAL | Reduces from 6M; only Schwarzschild exact |
| 8 | Fine structure constant alpha | 1/137.036 | NO | No n=6 connection found |
| 9 | Speed of light c | 299792458 m/s | NO | Dimensional, unit-dependent |
| 10 | Newton's G | 6.674e-11 | NO | Leading 6 is coincidence (unit-dependent) |
| 11 | Planck length | 1.616e-35 m | NO | No n=6 structure |
| 12 | Cosmological constant | ~1e-52 m⁻² | NO | No n=6 structure |
| 13 | Chandrasekhar limit | 1.4 M_sun | NO | = 5.83/mu_e², no n=6 |
| 14 | GR light deflection | 4GM/c²b | 4 | MARGINAL | = tau(6) again, small integer |
| 15 | Shapiro delay | 4GM/c³ | 4 | MARGINAL | Same 4 as above |
| 16 | Gravitational wave strain | (various) | NO | Complex expressions, no clean match |
| 17 | Perihelion precession | 6piGM/ac²(1-e²) | 6pi | YES | 6 appears explicitly |
| 18 | Graviton spin | 2 | MARGINAL | = phi(6), but trivially spin-2 |
| 19 | Stress-energy trace | T^mu_mu | NO | Tensor, not a number |

### Score

```
  YES (exact):   5/19  (26%)  — ISCO, photon sphere, Schwarzschild, divisor set, precession
  MARGINAL:      4/19  (21%)  — tau(6)=4 appearances, spin-2
  NO:            9/19  (47%)  — Dimensional constants, alpha, cosmological constant
  PARTIAL:       1/19  ( 5%)  — Kerr (only Schwarzschild limit exact)

  Honest assessment: The YES matches cluster in Schwarzschild geometry.
  Outside that specific context, n=6 has no predictive power for GR constants.
```

## Statistical Validation

```
  Texas Sharpshooter Test:
    Target space:    19 GR-related quantities
    Hits:            5 exact + 4 marginal = 9 (counting marginal as 0.5 → 7 effective)
    Random baseline: 19 × P(match|random) ≈ 2.1 ± 1.4
    Z-score:         3.39
    p-value:         < 0.01

  Interpretation:
    Statistically significant (Z > 3), but:
    - The "target" (Schwarzschild radii) was chosen AFTER seeing the pattern
    - Schwarzschild coefficients {2,3,6} are derived from orbit equations,
      not from any number-theoretic principle
    - The coefficients arise from solving r³ - 6Mr² + 9M²r - 4M³ = 0
      (effective potential extrema), where 6 appears from algebraic structure
    - Tesla 369 project has STRONGER n=6 connections (see related hypotheses)
```

## Honest Limitations

1. **Post-hoc selection**: The {2,3,6} pattern was noticed after examining BH physics,
   not predicted in advance. Classic Texas Sharpshooter risk.

2. **Small integer bias**: 2, 3, and 6 are among the smallest integers. They appear
   everywhere in physics for algebraic reasons unrelated to perfect numbers.

3. **Schwarzschild-only**: The clean divisor mapping breaks for Kerr (spinning) and
   Reissner-Nordstrom (charged) black holes. Real astrophysical BHs spin.

4. **No mechanism**: Even if the pattern is real, there is no proposed mechanism by
   which "perfect number 6" would constrain GR solutions.

5. **Unit dependence**: 9 of 19 quantities show NO match. The n=6 pattern is absent
   from fundamental constants (alpha, c, G, Lambda).

6. **Algebraic origin known**: The coefficients come from solving cubic potential
   equations. The factor 6 in ISCO arises from 3×2, not from sigma(6)=12.

7. **Confirmation bias**: We searched specifically for n=6 matches. A search for
   n=7 or n=12 matches might yield comparable hit rates.

## If Wrong: What Survives

Even if the n=6 GR connection is pure coincidence (which is likely):

1. **The tribunal stands**: The 15-mechanism classification is based on standard
   physics and is independent of any n=6 claim.

2. **The Schwarzschild structure stands**: {2M, 3M, 6M} are exact GR results
   regardless of any number-theoretic interpretation.

3. **The methodology stands**: Systematic FTL classification with explicit verdicts
   and evidence grades is useful independent of the n=6 overlay.

4. **The non-matches are informative**: Documenting where n=6 does NOT appear
   (alpha, c, G, Lambda) constrains future speculation.

## Related Hypotheses

- **H-CX-082~110**: Consciousness Bridge Constants (29 bridges, n=6 arithmetic)
- **H-098**: 6 is the only perfect number with proper divisor reciprocal sum = 1
- **Tesla 369**: Stronger n=6 connection in electromagnetic phenomena
- **P-SLE6**: SLE_6 critical exponents (7/7 match, much stronger than this result)
- **P-005**: Perfect number string theory (dimensional connections)

## Conclusion

The FTL tribunal provides a clean, physics-grounded classification of 15 mechanisms.
None achieve confirmed FTL. The n=6 observation in Schwarzschild geometry is exact but
speculative — it may reflect deep structure or simply the ubiquity of small integers
in fundamental physics. The honest non-match rate (47%) suggests caution.
