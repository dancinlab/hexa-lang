# H-AI-8: Why 6-Dimensional Embedding is Optimal Compression

> **Hypothesis**: The semantic space of natural language has an inflection point of intrinsic dimensionality near 6 dimensions, which corresponds to the σφ=nτ balance.

## Background
- Word2Vec/GloVe: Uses 300 dimensions, but intrinsic dim is much lower
- Many cases where 6 principal components explain a meaningful proportion of variance in PCA analysis
- σφ=nτ: "6 is the arithmetic balance point" → Balance in representation space too?

## Verification Directions
1. [ ] PCA analysis of public embeddings (GloVe, FastText): Inflection point near 6 dimensions?
2. [ ] Intrinsic dimension estimation (MLE, TwoNN) gives values near 6?
3. [ ] Autoencoder bottleneck sweep: dim=2..20 → reconstruction loss

## Difficulty: Medium | Impact: ★★★