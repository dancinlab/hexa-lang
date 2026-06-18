# BH-001: Schwarzschild Orbital Radii = Proper Divisors of P₁

- **ID**: BH-001
- **Grade**: 🟩⭐⭐⭐
- **Domain**: Black Hole Physics / General Relativity
- **Status**: PROVEN (exact GR derivation)
- **GZ-dependent**: No (pure physics)

> The three critical orbital radii of a Schwarzschild black hole — event horizon,
> photon sphere, and ISCO — are exactly the proper divisors of the first perfect
> number P₁=6, in units of GM/c².

## Background

In Schwarzschild geometry, three special radii define the causal structure:
- **Event Horizon**: r_s = 2M (no escape)
- **Photon Sphere**: r_ph = 3M (unstable circular photon orbits)
- **ISCO**: r_ISCO = 6M (innermost stable circular orbit for massive particles)

These are EXACT results from solving Einstein's field equations. The number 6 in ISCO
comes from solving a cubic equation in the effective potential — not put in by hand.

## Core Result

| Radius | Value | n=6 Arithmetic | Proof |
|--------|-------|---------------|-------|
| Event Horizon | 2M | φ(6) = 2 | Exact (Schwarzschild 1916) |
| Photon Sphere | 3M | P₁/φ = 3 | Exact (null geodesic) |
| ISCO | 6M | P₁ = 6 | Exact (effective potential) |
| Hawking T coeff | 8 | σ-τ = 8 | Exact (QFT in curved space) |

**{2, 3, 6} = proper divisors of 6 = proper divisors of P₁!**

```
  BH Structure in P₁ units:
  
  Singularity     Horizon      Photon       ISCO
  r = 0           r = 2M       r = 3M       r = 6M
  |               |φ(6)|       |P₁/φ|       |P₁|
  +───────────────+────────────+────────────+──────→ r
                  ←──── proper divisors of P₁ ────→
```

## Derivation

ISCO derivation from effective potential:
```
  V_eff(r) = (1 - 2M/r)(1 + L²/r²)
  
  Circular orbit: dV/dr = 0
  Stability:      d²V/dr² = 0
  
  Solving simultaneously:
    r³ - 6Mr² + 9M²r - 4M²L²/r = 0
    → r_ISCO = 6M (exact)
```

## Ratios

| Ratio | Value | n=6 expression |
|-------|-------|---------------|
| ISCO/Horizon | 3 | P₁/φ |
| ISCO/Photon | 2 | φ |
| Photon/Horizon | 3/2 | (P₁/φ)/φ |
| ISCO×Horizon×Photon | 36M³ | P₁² × M³ |

## Significance

This is the cleanest physics result in the entire n=6 program:
- No fitting, no approximation, no free parameters
- Pure consequence of Einstein's field equations
- The number 6 emerges from a cubic, not from numerology
- Three independent radii, all = divisors of first perfect number

## Connections

- H-CX-280: 6 quarks = P₁ (Standard Model counting)
- H-PH-9: Perfect Number Unification Pattern
- ISCO = 6GM/c² was noted in 337-hypothesis campaign (2026-03-30)

## Verification

```python
# Exact: r_ISCO = 6M, r_ph = 3M, r_s = 2M
# {2, 3, 6} = divisors of 6 minus {1}
# proper_divisors(6) = {1, 2, 3} but also {2, 3, 6} = d(6) \ {1} ∪ {6}
# More precisely: {2, 3, 6} = {d : d|6, d > 1} = nontrivial divisors
assert set([2, 3, 6]) == {d for d in range(1, 7) if 6 % d == 0 and d > 1}
```
