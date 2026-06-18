# Hypothesis 268: Difficulty-Axis Dominance Law — Hard problems are dominated by "how"
**n6 Grade: 🟧 CLOSE** (auto-graded, 3 unique n=6 constants)


> **As task difficulty increases, the dominant axis of the repulsion field shifts from content (what) to structure (how). In MNIST, content tension > structure tension, but in CIFAR, structure tension > content tension reverses.**

## Background/Context

```
  Content axis = Engine A (Number Theory) vs Engine G (Entropy) = "What is it"
  Structure axis = Engine E (Euler Product) vs Engine F (Modular Constraints) = "How is it composed"
```

Tension axis ratio reverses between MNIST and CIFAR.

Related hypotheses: 263 (Tension Integration), 264 (Design Principles)

## Measured Data

| Dataset | Content Tension | Structure Tension | Ratio (Structure/Content) |
|---|---|---|---|
| MNIST | 372 | 256 | 0.69 (content-dominant) |
| CIFAR | 273 | 656 | **2.40** (structure-dominant) |

```
  MNIST:                           CIFAR:
  Content ████████████████ 372     Content ██████████ 273
  Structure ███████████ 256        Structure █████████████████████████ 656

  → MNIST: what matters           → CIFAR: how matters
```

## Interpretation

```
  MNIST (handwritten digits):
    Simple shapes. "Is this stroke a 3 or 8?" is key.
    → Large repulsion between engines about content (meaning)
    → Fighting over "what it is"

  CIFAR (real photos):
    Same class has vastly different appearances. Cats have thousands of looks.
    → Large repulsion between engines about structure (form)
    → Fighting over "how it looks"

  Generalization:
    Easy problem = clear concepts → what is important
    Hard problem = ambiguous concepts → how is important

  Brain correspondence:
    what pathway (ventral stream) — object recognition, inferior temporal lobe
    how pathway (dorsal stream) — spatial relations, parietal lobe
    → Increased dorsal activity in difficult visual tasks (known fact)
```

## Predictions

```
  1. CIFAR-100 (100 classes, harder) → structure/content ratio > 2.40
  2. ImageNet (1000 classes) → ratio increases further
  3. Text classification → content-dominant? (meaning is key task)
  4. Speech recognition → structure-dominant? (waveform is key)
```

## Verification Direction

```
  1. Tension axis reversal experiment results pending (experiment_tension_axis_reversal.py)
  2. Track ratio change during training — structure-dominant from start or switches during training?
  3. CIFAR class-by-class analysis — which classes raise structure tension?
  4. Artificial difficulty adjustment (add noise to MNIST) → when does ratio reverse?
  5. Does same reversal appear in CNN-based models? (model_cnn_repulsion.py results pending)
```

## Limitations

```
  1. Observed in only 2 datasets (MNIST, CIFAR-10).
  2. Definition of "difficulty" is ambiguous — number of classes? classification accuracy? human error rate?
  3. Can't separate whether reversal cause is difficulty or data characteristics (grayscale vs color).
  4. MLP-based results. May differ in CNN.
```