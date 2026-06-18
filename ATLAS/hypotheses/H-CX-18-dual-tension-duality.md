# H-CX-18: Internal/Inter Tension Duality = Wave-Particle Duality? (Cross-domain)
**n6 Grade: 🟩 EXACT** (auto-graded, 6 unique n=6 constants)


> **The "internal tension = inverted, inter-tension = normal" discovered in H307 is structurally similar to wave-particle duality in quantum mechanics. Looking at the same system from inside (internal tension) reveals one side, while looking from outside (inter-tension) reveals the opposite.**

## Duality Structure

```
  Measurement method   Normal data      Anomaly data      Analogy
  ──────────      ──────────      ──────────      ──────
  Internal tension  High (2.76)      Low (1.03)       "Wave"
  Inter-tension     Low (0.0017)     High (0.0071)    "Particle"

  Quantum duality:
    As wave: interference pattern (diffuse)
    As particle: point pattern (focused)
    → Complementary perspectives on the same phenomenon

  Tension duality:
    From inside: agreement=anomaly, disagreement=normal
    From inter (outside): disagreement=anomaly, agreement=normal
    → Complementary perspectives on the same data
```

## Mathematical Connection

```
  R spectrum duality:
    R(n) = σφ/(nτ)
    Inverse of R(n) = nτ/(σφ)

  n=6 (perfect number): R=1, 1/R=1 → self-dual!
  n≠6: R≠1 → R and 1/R differ

  Internal tension ↔ R(n): normal=high
  Inter-tension ↔ 1/R(n): normal=low

  "Duality unifies at the perfect number"
  → Perfect number = point where internal/inter tensions are equal?
```

## Information Theory Connection

```
  MI(X;Y) = H(X) - H(X|Y)

  Internal tension: MI(engine_a; engine_g | same_child)
    Normal: high MI (engines share much)
    Anomaly: low MI (engines share less)

  Inter-tension: MI(child_a; child_b | same_input)
    Normal: low MI (learned differently)
    Anomaly: high MI (failing similarly... actually high difference)

  Correction: high inter-tension ≠ high MI
  Inter-tension = |output_a - output_b|² = disagreement
  High disagreement = low MI

  → Internal: anomaly=low MI (consensus) → low tension
  → Inter: anomaly=low MI (disagreement) → high tension
  → Both "anomaly=low MI", but expressed differently!
```

## Experimental Results (2026-03-24, 3 trials × 3 configs)

```
  Two independent PureFieldEngines trained then measured:
  Internal = ||A-G||² within model, Inter = ||out1-out2||² between models

  Config       T  IntN      IntA     InterN   InterA   Dual?
  ──────────── ── ──────── ──────── ──────── ──────── ──────
  0-7 vs 8-9   1  418.25   256.05   13.33     8.63     no
  0-7 vs 8-9   2  378.07   247.75   13.96    10.15     no
  0-7 vs 8-9   3  402.60   288.00   13.82    11.73     no
  0-4 vs 5-9   1  425.44   344.48   12.78    12.00     no
  0-4 vs 5-9   2  370.24   333.18   13.54    12.84     no
  0-4 vs 5-9   3  402.86   355.57   13.76    13.03     no
  even vs odd  1  357.93   413.41   12.81    12.00     no
  even vs odd  2  331.28   372.56   13.29    13.12     no
  even vs odd  3  349.45   409.40   14.34    12.50     no

  Duality confirmed: 0/9 (0%)!!
```

### Interpretation

```
  1. Normal > Anomaly for BOTH internal AND inter (0-7 vs 8-9)
     → No duality! Both tensions in the same direction
  2. Only in even vs odd does internal invert (Anomaly > Normal)
     → Odd digits have more complex patterns → higher internal tension
  3. Difference from H307 (dual mechanism):
     → H307: tension between children after mitosis (shared structure)
     → H-CX-18: two independent models (no sharing)
     → "Duality" is a phenomenon that holds only in mitosis relationships?
  4. Internal tension Mann-Whitney p < 1e-50 (strong separation)
     → Tension is significant for class separation, but not duality
```

## Status: ⬛ Refuted (Duality 0/9, internal/inter tensions in same direction)
