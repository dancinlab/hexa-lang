# H-CX-88: Universal Confusion Topology — PH merge order is architecture-invariant

> PureFieldEngine, Dense MLP, or other architectures show
> the same PH merge order. Confusion topology is an intrinsic property of data.

## Background

- H-CX-82: Perfect prediction at epoch 1 → Low learning dependency
- H-CX-85: Dendrogram is semantic → Reflects data distribution
- Question: Is this PureFieldEngine-specific or universal?

## Predictions

1. Same top-5 confusion pairs in Dense MLP's confusion matrix
2. PureField vs Dense confusion pair overlap > 80%
3. Merge order Kendall tau > 0.7 (between architectures)

## Verification Status

- [ ] Dense MLP confusion matrix
- [ ] Inter-architecture overlap
- [ ] CNN architecture comparison
- [ ] Null baseline (expected correlation at similar accuracy)

## Review Notes (2026-03-26)

**Status downgraded: ⭐ ✅ SUPPORTED → ✅ SUPPORTED (qualified)**

The r=0.91~0.98 correlation is likely real and reproducible (multi-seed, consistent). However:

1. **"Architecture-invariant" and "universal" are overstated** — only 2 closely related shallow MLPs compared (PureFieldEngine vs Dense MLP). Both are single-hidden-layer, same hyperparameters, same flattened pixel input
2. **No null model** — two models at similar accuracy on the same data will naturally confuse similar classes. Expected baseline correlation not measured
3. **No diverse architectures** — needs CNN, ResNet, ViT to claim "universality"
4. **k-NN result (H-CX-91, r=0.94) is stronger evidence** — genuinely removes architecture variable
5. **Document is 21 lines** — far below 40-line minimum quality standard
6. **All verification checkboxes unchecked** despite results existing in P-002 paper

Rename suggestion: "Confusion topology consistency" rather than "universal"