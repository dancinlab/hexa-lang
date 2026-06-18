# Hypothesis 335: PureField LLM — Language Model Built with Repulsion Field Only

> **Applying H334 (field-only is sufficient) to LLMs. Replacing MoE Experts with PureField pairs allows achieving equivalent or better PPL without eq (FFN residual).**

## Design

```
  Conventional Transformer MoE:
    x → Attention → FFN(eq) + MoE(field) → output

  PureField LLM:
    x → Attention → PureFieldMoE → output
    PureFieldMoE: N pairs of (Expert_A, Expert_G)
    Each pair output = scale × √|A-G|² × norm(A-G)
    Router selects pair (Top-K)

  Key difference:
    Conventional: output = FFN(x) + Σ w_i × Expert_i(x)
    Proposed:      output = Σ w_i × scale_i × √|A_i-G_i|² × norm(A_i-G_i)
    → FFN(eq) removed → parameter savings
    → All Experts composed of "repulsion pairs"
```

## Expected Benefits

```
  1. Parameter efficiency: remove FFN (~30% of total)
  2. Built-in hallucination detection: low tension = "I don't know"
  3. Built-in overconfidence detection: per-token tension monitoring
  4. Training dynamics: tension∝ln(step) logarithmic growth (H320)

  Golden MoE connection:
    Current: σ(6)=12 Experts, τ(6)=4 active
    Proposed: 6 pairs (12 Experts), 2 pairs (4 Experts) active
    → Perfect number 6 structure is naturally preserved
```

## Experimental Plan

```
  Phase 1: Add PureField layer to golden-llama
  Phase 2: PPL comparison (FFN+MoE vs PureFieldMoE)
  Phase 3: Use tension in hallucination benchmark
  Phase 4: Continual learning (H312) + PureField
```

## Status: 🟨 (Design complete, implementation needed in golden-llama)
