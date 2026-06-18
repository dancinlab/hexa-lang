# Hypothesis Review 063: Cobweb Convergence = Monotone (Glide) ✅

## Hypothesis

> Is the cobweb diagram convergence pattern of meta iteration f(I) = 0.7I + 0.1 spiral or monotone glide? Since f'(1/3) = 0.7 > 0, it should be monotone convergence.

## Background: Two Types of Convergence in Cobweb Diagrams

A cobweb diagram visualizes the convergence process of an iterative function x_{n+1} = f(x_n).

```
  The sign of the derivative f'(x*) at the fixed point determines convergence type:

  0 < f'(x*) < 1  →  Monotone convergence (staircase approach from one side)
  -1 < f'(x*) < 0 →  Spiral convergence (alternating approach from both sides)
  |f'(x*)| ≥ 1    →  Divergence (does not converge)
```

## Verification Result: ✅ Monotone Convergence (Not Spiral)

### Mathematical Determination

```
  f(I) = 0.7I + 0.1
  f'(I) = 0.7       (same for all I, linear function)

  Fixed point: I* = 1/3
  f'(I*) = 0.7

  Determination: 0 < 0.7 < 1  →  ✅ Monotone convergence
```

### Cobweb Diagram: Starting from I₀ = 0.8

```
  f(I)
  0.70 ┤                               ╱
       │                      ___──── ╱
  0.66─┤─ ─ ─ ─ ─ ─ ─ ─ ─ ●₁──── ╱   f(I)=0.7I+0.1
       │                ╱ │     ╱
  0.56─┤─ ─ ─ ─ ─ ─ ●₂─ ─│─ ╱
       │           ╱ │    │╱
  0.49─┤─ ─ ─ ─ ●₃─ ─│─ ╱│        y = I
       │       ╱ │    │╱  │
  0.44─┤─ ─ ●₄─ ─│─ ╱│   │
       │     │╱   │╱  │   │
  0.41─┤─ ●₅╱ ─ ╱│   │   │
       │  ╱│  ╱  │   │   │
  1/3 ─┤●──●──●───●───●───●── ← Fixed point (limit)
       │╱  │  │   │   │   │
  0.10─●───┼──┼───┼───┼───┼──
       0   1/3 0.41 0.49 0.56 0.66 0.8  I
              ←──←──←──←──←
              One-direction approach (right→left)
```

### Step-by-Step Convergence Trajectory

```
  Step   I_n        f(I_n)     |I_n - 1/3|   Contraction rate
  ────  ─────────  ─────────  ───────────  ────────
   0    0.800                  0.467
   1    0.660      0.660       0.327        0.700
   2    0.562      0.562       0.229        0.700
   3    0.493      0.493       0.160        0.700
   4    0.445      0.445       0.112        0.700
   5    0.412      0.412       0.079        0.700
   6    0.388      0.388       0.055        0.700
   7    0.372      0.372       0.039        0.700
   8    0.360      0.360       0.027        0.700
   9    0.352      0.352       0.019        0.700
  10    0.347      0.347       0.014        0.700
  ∞     0.333...               0.000

  Error reduces by exactly 0.7x each step (linear contraction)
```

### Comparison with Spiral Convergence (If f' = -0.7)

```
  Monotone convergence (f'=+0.7, our model)    Spiral convergence (f'=-0.7, hypothetical)
  ─────────────────────────────────────       ─────────────────────────────────────────

  I(n)                                         I(n)
  0.8│●                                        0.8│●
     │ ╲                                          │ ╲
  0.6│  ╲                                      0.6│  ╲
     │   ╲                                        │   ╲     ╱╲
  0.4│    ╲                                     0.4│    ╲  ╱    ╲
     │     ╲                                       │     ●       ●
  1/3│──────●───●───●───●──                    1/3│──────●───●───●──
     │                                             │         ╲  ╱
  0.2│                                          0.2│          ╲╱
     ├──┬──┬──┬──┬──┬──┤                          ├──┬──┬──┬──┬──┬──┤
     0  2  4  6  8  10 n                          0  2  4  6  8  10 n

  Always approach from above                    Oscillating approach from above-below
  No overshoot                                  Overshoot every time
```

### Convergence Dynamics within Golden Zone

```
  Flow along Inhibition axis:

  0.0    0.24       1/3    1/e    0.48    0.5    1.0
  ├──→→→→┤──→→→→→──●──────●──←←←←┤──←←←←─┤──←←←─┤
         │    Golden Zone         │
         │                       │
  I₀=0.8:  0.80 → 0.66 → 0.56 → 0.49 → 0.44 → 0.41 → ...→ 1/3
                                    ↑ Enter Golden Zone (4th iteration)

  I₀=0.1:  0.10 → 0.17 → 0.22 → 0.25 → 0.28 → 0.29 → ...→ 1/3
                                  ↑ Enter Golden Zone (3rd iteration)
```

## Interpretation

1. **Stable glide**: Monotone convergence means the system approaches the target without "overshooting". Inhibition converges to the Golden Zone without overcorrection. This corresponds to a biologically stable adaptation process.

2. **Constant contraction rate**: Being a linear function, the contraction rate is exactly 0.7. Error reduces by 30% with each iteration. In nonlinear systems, the contraction rate can change as it approaches the fixed point.

3. **Golden Zone entry speed**: Even starting from I₀ = 0.8, it enters the Golden Zone in about 4 iterations. This shows the system reaches the optimal region relatively quickly.

4. **Connection to 061**: The golden ratio compared in hypothesis 061 (f' = -0.382) shows spiral convergence, while our model (f' = +0.7) shows monotone convergence. This cobweb analysis is the specific evidence for "same type (contraction mapping), different kind (convergence pattern)".

## Limitations

- f(I) = 0.7I + 0.1 is a linear approximation. In actual nonlinear models, f'(I) varies with I, so this analysis is only valid near the fixed point.
- Contraction rate 0.7 is a value from a single parameter setting. If D, P change, the contraction rate may also change.
- Need to verify if the monotone convergence condition 0 < f' < 1 always holds across the entire parameter range.

## Verification Directions

- [ ] Explore conditions where the sign of f'(I*) switches in nonlinear iterative functions
- [ ] Measure the variation range of contraction rate 0.7 with changes in D, P
- [ ] Theoretical review of whether scenarios exist where spiral convergence is more advantageous

---

*Date: 2026-03-22 | Verification: verify_meta_math.py*