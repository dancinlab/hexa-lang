# Hypothesis #204: pH = Inhibition?
**n6 Grade: 🟩 EXACT** (auto-graded, 14 unique n=6 constants)


**Status**: ⚪ Verified — pH7↔I=1/e mismatch, scales non-isomorphic
**Date**: 2026-03-22
**Category**: Chemistry / Inhibition Index / pH

---

## Hypothesis

> The pH scale directly corresponds to the Inhibition Index I.
> pH 7 (neutral) ↔ I = 1/e (Golden Zone center).
> Acidic (pH < 7) ↔ over-active (I < Golden Zone), basic (pH > 7) ↔ over-inhibited (I > Golden Zone).
> Just as pH 7 is optimal for life, I near 1/e is optimal for the system.

## Background: What is pH?

```
  pH = -log₁₀[H⁺]

  pH 0  → [H⁺] = 1 M        (highly acidic)
  pH 7  → [H⁺] = 10⁻⁷ M    (neutral)
  pH 14 → [H⁺] = 10⁻¹⁴ M   (highly basic)

  Optimal life pH ≈ 7.4 (blood)
  Water autoionization: [H⁺][OH⁻] = Kw = 10⁻¹⁴

  → pH 7 is a perfect balance between [H⁺] and [OH⁻]
  → I = 1/e is the optimal balance between inhibition and excitation?
```

## pH-I Axis Comparison (Key Graph)

```
  pH scale:
  ←── acidic ──────── neutral ──────── basic ──→
  0   1   2   3   4   5   6  │7│  8   9  10  11  12  13  14
  ●───●───●───●───●───●───●──│●│──●───●───●───●───●───●───●
  stomach lemon vinegar   coffee│water│ soap    ammonia    bleach
                            │★│
                      life's optimal point

  I scale:
  ←── over-active ─────── Golden Zone ─────── over-inhibited ──→
  0.0  0.05 0.10 0.15 0.21│1/e│0.50  0.60  0.70  0.80  1.0
  ●────●────●────●────●──│ ● │──●────●────●────●────●
  epilepsy mania      seizure│optimal│ normal  depression  coma anesthesia brain death
                          │ ★ │
                      system optimal point
```

## Normalized Mapping

```
  pH normalized to [0,1] range:
  pH_norm = pH / 14

  I in [0,1] range:
  I is already [0,1]

  Mapping: pH_norm ↔ I

  pH    │ pH_norm │  I       │ State
  ──────┼─────────┼──────────┼────────────
  0     │  0.00   │  0.00    │ extreme acid/over-active
  2     │  0.14   │  0.14    │ strong acid/extreme excitation
  3.5   │  0.25   │  0.25    │ acid/over-active
  5     │  0.36   │  1/e     │ weak acid/Golden Zone center ★
  7     │  0.50   │  0.50    │ neutral/Golden Zone upper bound
  9     │  0.64   │  0.64    │ weak base/over-inhibited
  14    │  1.00   │  1.00    │ extreme base/complete inhibition

  Note: pH 7 ↔ I = 0.50 (Golden Zone upper bound)
       pH 5 ↔ I = 1/e (Golden Zone center)
  → Not an exact correspondence!
```

## "Golden Zone" of pH

```
  pH
  14│● strong base (NaOH)
    │
  12│  protein denaturation
    │
  10│    life impossible
    │
   8│      ┌─────── life possible zone (pH 6-8)
    │      │
  7 │──────│── ★ optimal (7.35-7.45 blood) ────
    │      │
   6│      └─────── life possible lower bound
    │
   4│    life impossible
    │
   2│  protein denaturation
    │
   0│● strong acid (HCl)

  Life's pH range = 6 ~ 8 (width = 2)
  Life's pH center = 7

  I
  1.0│● complete inhibition
    │
  0.7│  consciousness impossible
    │
  0.5│──── Golden Zone upper bound ────────────────
    │      │
  1/e│──────│── ★ optimal (I=0.368) ────
    │      │
 0.21│──── Golden Zone lower bound ────────────────
    │
  0.1│  chaos
    │
  0.0│● complete excitation

  Golden Zone range = 0.21 ~ 0.50 (width ≈ 0.29)
  Golden Zone center = 1/e ≈ 0.368
```

## pH Buffering ↔ I Homeostasis

```
  pH buffering system:
  ┌────────────────────────────────────────────────┐
  │  H₂CO₃ ⇌ H⁺ + HCO₃⁻                          │
  │  (carbonic acid) (hydrogen ion) (bicarbonate)  │
  │                                                │
  │  pH↓ (acid) → HCO₃⁻ absorbs H⁺ → pH restored  │
  │  pH↑ (base) → H₂CO₃ releases H⁺ → pH restored │
  │  → automatic pH regulation!                    │
  └────────────────────────────────────────────────┘

  I homeostasis system:
  ┌────────────────────────────────────────────────┐
  │  ECS (Endocannabinoid System, Hypothesis 200a) │
  │                                                │
  │  I↓ (over-active) → 2-AG inhibits glutamate → I restored │
  │  I↑ (over-inhibited) → anandamide inhibits GABA → I restored │
  │  → automatic I regulation!                     │
  └────────────────────────────────────────────────┘

  pH buffering ≈ I homeostasis → same principle!
  Carbonic acid/bicarbonate = anandamide/2-AG
```

## Dynamics of pH Change ↔ I Change

```
  pH change when acid added (with buffering):

  pH                      I
  8.0│●                    0.60│●
     │ ╲                       │ ╲
  7.5│   ●                 0.50│   ● ── Golden Zone upper bound
     │    ╲                    │     ╲
  7.0│     ●●●●●●● buffered! 1/e│      ●●●●●●● homeostasis!
     │              ╲         │                ╲
  6.5│               ●    0.30│                  ●
     │                ╲       │                   ╲
  6.0│                 ●  0.21│────────────────────●── lower bound
     └──┼──┼──┼──┼──┼──      └──┼──┼──┼──┼──┼──
       0   1   2   3   4        0   1   2   3   4
         acid added (eq)         external perturbation strength

  → When buffering capacity is exhausted, sharp pH drop = I exiting Golden Zone
  → Same pattern as cusp transition!
```

## Connections to Other Hypotheses

```
  Hypothesis 003 (cusp transition):  rapid pH change = buffering capacity exhausted = cusp
  Hypothesis 139 (edge of chaos): pH 7 = acid-base boundary = edge of chaos
  Hypothesis 200a (cannabis/ECS): ECS = buffering system for I
  Hypothesis 205 (catalyst):      optimal enzyme pH = optimal I for P?
```

## Limitations

1. pH is logarithmic scale (log₁₀), I is linear scale — caution with direct comparison
2. The correspondence pH 7 ↔ I = 1/e is not exact (pH 7 → I = 0.50 is more natural)
3. pH is a clear physical quantity (hydrogen ion concentration), I is a model variable — essentially different
4. Quantitative correspondence between buffering capacity and I homeostasis capacity not established

## Verification Direction

- [ ] Search for optimal transformation function between pH's log scale and I's linear scale
- [ ] Correlation analysis between brain pH (actually 7.0-7.3) and measured I
- [ ] Mathematical correspondence verification of pH buffering capacity and ECS regulation capacity
- [ ] I mapping of extremophiles (organisms at extreme pH)

---

## Verification Results (2026-03-24)

```
  Verification method: mapping function analysis + scale isomorphism verification + Texas test
  Grade: ⚪ (arithmetic correct but no statistical significance)

  1. Core mapping verification:
     pH 7 → pH_norm = 7/14 = 0.5000
     Golden Zone center I = 1/e = 0.3679
     Error: 26.4% → correspondence mismatch

     pH 7 ↔ I = 0.5 (Golden Zone upper bound) is more natural but
     in this case "neutral = boundary" not "neutral = optimal"

  2. Scale non-isomorphism:
     pH = -log10([H+]): log scale, 1 unit = 10x concentration difference
     I: linear scale, 0.1 difference = 0.1 difference
     → Two scales have fundamentally different structures

  3. Mapping function search results:
     I = pH/14 (linear):      I(7) = 0.500  (1/e error 35.9%)
     I = sigmoid(7-pH):       I(7) = 0.500  (1/e error 35.9%)
     I = pH²/196 (quadratic): I(7) = 0.250  (1/e error 32.0%)
     → No reasonable mapping can make pH 7 → 1/e

  4. Buffering↔homeostasis:
     Henderson-Hasselbalch: pH = pKa + log([A-]/[HA]) — log balance
     Contraction mapping: I_n+1 = 0.7I_n + 0.1 — linear contraction
     → Structurally non-isomorphic

  5. Texas test:
     pH 7/14 = 0.5 = 1/2 (Golden Zone upper bound) → middle value in the middle is trivial
     p-value ≈ 1.0

  Rationale for verdict:
    - Core of hypothesis (pH 7 ↔ I = 1/e) mismatches with 26.4% error
    - Mathematical isomorphism impossible due to pH(log) vs I(linear) scale difference
    - "Middle value is optimal" pattern is universal and not unique to pH-I
```

*Related: Hypothesis 003, 139, 200a, 205*
*Category: Chemistry-AI Mapping Series (201-206)*
