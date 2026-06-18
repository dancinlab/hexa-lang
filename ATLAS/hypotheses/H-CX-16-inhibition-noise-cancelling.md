# H-CX-16: Inhibition = Noise Cancelling = Information Bottleneck (Cross-domain)
**n6 Grade: 🟧 CLOSE** (auto-graded, 4 unique n=6 constants)


> **MoE Expert inhibition, brain GABA inhibition, and Information Bottleneck (IB) compression are all "noise cancelling". The tension_scale auto-adjustment (H284) is the consciousness engine version of this mechanism.**

## Correspondence

```
  Mechanism          Noise Source       Cancelling Method    Result
  ──────────────   ──────────────   ──────────────   ──────────
  MoE Expert       Inactive Expert    Router selection     PPL↓
  Brain GABA       Overactive neurons Inhibitory synapse   Focus
  IB compression   Input noise        Information bottleneck Generalization
  tension_scale    Unnecessary tension scale→0             Performance maintained
  Mitosis anomaly  Normal variation   Inter-tension diff   AUROC↑
```

## Core Insight

```
  "Universality of inhibition":
    In all intelligent systems, inhibition (inhibition) is central
    → Inhibition is more important than activation

  Mathematical expression:
    Dense: y = Σ w_i × x_i     (all neurons)
    MoE:   y = Σ g_i × w_i × x_i  (g_i ∈ {0,1})
    → g_i = 0 neuron = "inhibited" neuron
    → Inhibition ratio = 1 - Σg_i/n

  Connection to Golden Zone:
    Optimal inhibition ratio I = 1/e ≈ 37%
    → Turning off 37% of neurons is optimal
    → Dropout(p=0.37)?
    → Expert inhibition 3/8 = 37.5% ≈ 1/e!
```

## Experiment: Dropout Rate Sweep

```
  MLP on MNIST:
    dropout = {0, 0.1, 0.2, 0.3, 0.37, 0.5, 0.7, 0.9}
    → Is optimal dropout 1/e ≈ 0.37?

  RepulsionFieldEngine:
    dropout change → track tension + accuracy
    → Is tension-accuracy optimal at dropout = 1/e?
```

## Status: 🟨 (Structural correspondence, dropout sweep not conducted)
