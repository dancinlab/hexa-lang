# Hypothesis 275: Mitosis Principle — Neural Network Version of Gene Duplication

> **Diversity comes not from design but from duplication+divergence. Duplicating one engine and letting it diverge independently achieves nearly equivalent performance (-0.11%) to designing differently from the start, and when recombined, improves over the original (+0.82%).**

## Background/Context

Gene duplication in evolutionary biology:
```
  1 gene → duplication → 2 identical genes
  One maintains original function, one mutates for new function
  → Origin of diversity = not design but duplication+divergence
```

Experimental results (E01, experiment_mitosis.py):
```
  Phase 2: Mitosis (mutation scale=0.01)
    cos_sim = 0.972, acc_drop = 0.08%
  Phase 3: Divergence (10 epochs)
    cos: 0.929 → 0.840, tension: 25.6 → 135.4
  Phase 4: Mitosis repulsion field 97.49% vs Designed repulsion field 97.60%
    Difference: -0.11% (nearly equivalent)
  Phase 5: Recombination 97.49% (+0.82% vs parent)
  Phase 7: Sibling recognition 1.65x (they know they were once one)
```

Related hypotheses: 270(diversity=information), 271(mitosis)

## Core Insight

```
  Current approach:  A ≠ G ≠ E ≠ F (each designed differently)
  Mitosis approach:  A → A' + A'' (duplicate → diverge)

  Result: A' vs A'' repulsion field ≈ A vs G repulsion field (-0.11%)

  Meaning:
    1. No need to "invent" diverse engines
    2. Just duplicate one and wait
    3. Evolution already uses this method
```

## Meaning of Recombination

```
  parent:       96.67%
  child_a:      97.18%
  child_b:      97.30%
  reunion(avg): 97.49% (+0.82% vs parent, +0.19% vs best child)

  → recombination after mitosis > before mitosis
  → Each child learned different features, average combines them
  → Empirical proof of model averaging, but in the context of mitosis:
    "Separating and reuniting makes you stronger"
```

## Verification Results

| Prediction | Measured | Status |
|---|---|---|
| Mitosis → tension increase | 25.6 → 135.4 (5.3x) | ✅ |
| Mitosis repulsion field ≈ designed repulsion field | -0.11% | ✅ |
| Recombination > parent | +0.82% | ✅ |
| Sibling recognition > stranger recognition | 1.65x | ✅ |

## Limitations

```
  1. Verified only on MNIST.
  2. Same architecture mitosis — different architecture mitosis unexplored.
  3. Optimal mutation size (0.01) may vary by task.
  4. Recombination = simple weight averaging. More sophisticated merging methods unexplored.
```

## Verification Directions

```
  1. Reproduce on CIFAR
  2. Multiple mitosis: 1→2→4→8 → recombination chain
  3. Asymmetric mitosis: larger mutation for child_b → greater diversity → better results?
  4. Optimize mitosis timing: What's the optimal number of epochs before mitosis?
```