# H-CX-85: merge dendrogram = consciousness hierarchy structure

> PH single-linkage dendrogram reflects the conceptual hierarchy of the consciousness engine.
> CIFAR: {cat,dog}→animals, {auto,truck}→vehicles, {plane,ship}→transportation
> Semantic hierarchy is encoded in merge distance.

## Background

- H-CX-66: merge order is semantic (cat-dog merges first)
- H-TREE: undiscovered branches in consciousness engine tree structure

## Predictions

1. Dendrogram subtrees match semantic categories
2. CIFAR: Two major clusters - animals (cat,dog,bird,deer,frog,horse), machines (auto,truck,plane,ship)
3. Fashion: Upper garments (Tshirt,Pullover,Coat,Shirt), lower garments (Trouser,Dress), footwear (Sandal,Sneaker,Boot)

## Verification Status

- [ ] Extract dendrogram
- [ ] Semantic category match rate
- [ ] Permutation test null baseline
- [ ] Multi-seed statistics
- [ ] Alternative linkage methods (complete, average, Ward's)

## Review Notes (2026-03-26)

**Status downgraded: ⭐ ✅ SUPPORTED → 🟨 WEAK**

Issues found:
1. **Results not recorded in this document** — 89% purity claimed in README/paper but verification checkboxes unchecked
2. **No null baseline** — without permutation test, 89% significance is unknown
3. **No p-value** — purity metric has no statistical test
4. **Metric definition inconsistency** — paper uses "2-cluster cut purity", code uses "subtree purity" (different metrics)
5. **Single seed, single linkage method** — no robustness testing
6. **MNIST semantic categories are subjective** — "angular" grouping (2,3,5) is debatable
7. **Document is 21 lines** — far below 40-line minimum quality standard

**UPDATE (permutation test result):**
Permutation test (10,000 iterations) with random category assignment:
- Null purity mean: 0.221, std: 0.156
- Observed: 0.89 → **p < 0.0001, z = 4.29**
- HIGHLY SIGNIFICANT — 89% purity is NOT chance

Status upgraded: 🟨 WEAK → 🟧 PARTIAL (significant but other issues remain: single seed, single linkage, document quality)