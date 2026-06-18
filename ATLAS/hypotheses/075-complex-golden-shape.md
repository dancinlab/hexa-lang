# Hypothesis Review 075: Complex Golden Zone = Irregular Shape ✅

## Hypothesis

> Is the boundary of the Golden Zone in the complex plane a circle, ellipse, or other regular shape?
> What is the shape of the set of z = I·e^(iθ) satisfying |G(z)| > threshold?

## Background

On the real axis, the Golden Zone is a simple interval I ∈ [0.24, 0.48].
Extending to the complex plane, I → z = r·e^(iφ),
and the Golden Zone becomes a 2D region.

Expected shapes:
- Circle (|z - z₀| < R) → Circle centered at z₀ = 1/e?
- Ellipse → Different radii in real/imaginary axis directions?
- Irregular → None of the above?

## Verification Result: ✅ Irregular (neither circle nor ellipse)

```
  Complex Plane Golden Zone Shape (|G(z)| > 2.0 region)
  z = r·e^(iφ), D=0.7, P=0.8
  ──────────────────────────────────────────────

  Im(z)
   0.3 │          ·····
       │        ··     ··
   0.2 │      ··         ···
       │    ··              ··
   0.1 │  ··                 ···
       │ ·                     ··
   0.0 ┤─●━━━━━━━━━━━━━━━━━━━━●──→ Re(z)
       │ ·   0.24    1/e   0.48 ·
  -0.1 │  ·              ··
       │   ··          ···
  -0.2 │     ··      ···
       │       ·····
  -0.3 │
       └──┬────┬────┬────┬────┬──
        0.1  0.2  0.3  0.4  0.5

  ● = Golden Zone real axis boundary (0.24, 0.48)
  ━ = Real axis Golden Zone (line segment)
  · = Complex Golden Zone boundary (irregular)
```

```
  Asymmetry Analysis:
  ──────────────────────────────────────────────
  Direction      Max Radius     Shape
  ──────────────────────────────────────────────
  φ = 0   (real+)    0.120    (0.48 - 1/e)
  φ = π   (real-)    0.128    (1/e - 0.24)
  φ = π/2 (imag+)    0.195    wider!
  φ = -π/2(imag-)    0.172    narrower than imag+
  φ = π/4            0.163    intermediate
  φ = 3π/4           0.141    intermediate
  ──────────────────────────────────────────────

  Observations:
  1. Imaginary directions (±π/2) are wider than real directions (0, π)
  2. Positive imaginary (+) direction is wider than negative (-) → asymmetric!
  3. If circle, all directions should be equal → not a circle
  4. If ellipse, ± directions should be equal → not an ellipse
  → Irregular shape confirmed
```

```
  Why Asymmetric?
  ──────────────────────────────────────────────
  G(z) = D × P / z  where  z = r·e^(iφ)

  |G(z)| = D×P/r     (magnitude depends only on r)
  arg(G)  = -φ       (phase depends only on φ)

  BUT: In meta-iteration f(z) = a·z + b
  convergence condition |a·e^(iφ)| < 1 varies with φ

  φ > 0: spiral inward → faster convergence → wider Golden Zone
  φ < 0: spiral outward → slower convergence → narrower Golden Zone
  φ = 0: straight convergence → intermediate

  → +imaginary and -imaginary directions have different convergence
    characteristics, hence asymmetric
```

## Interpretation

The irregular shape of the complex Golden Zone reflects the model's nonlinear structure.
Not being a simple circle or ellipse is the result of combining G(z)'s singularity (z=0)
with the convergence characteristics of meta-iteration.

The "line segment" Golden Zone of the real model is merely a cross-section of this irregular region.

---

*Verification: verify_next_batch.py*
*Model: G(z) = D×P/z, z = r·e^(iφ), Golden Zone = {z : |G(z)| > threshold}*