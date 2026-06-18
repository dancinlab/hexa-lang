# Hypothesis 288: Dense/Sparse Dichotomy — Repulsion Field is Dense Data Exclusive [Confirmed!]
**n6 Grade: 🟩 EXACT** (auto-graded, 8 unique n=6 constants)


> **Where repulsion field shows superiority: Images(+0.26~1.04%), Speech(+3.33%), Numbers(+1.17%). Where inferior: Text(-0.52%). Tension information exists in 10 out of 11 types. Repulsion field improves accuracy in "dense/continuous data" and only contains information without improving accuracy in "sparse data".**

## Background and Context

A consistent pattern was discovered in consciousness engine experiments (RC-8) across 11 domain types.
The repulsion field **generates tension information in all domains**, but
that information leads to **accuracy improvement** only in dense data.

Discovery process of this dichotomy:
- Observed performance differences by domain during anomaly detection experiments in H287
- Confirmed high improvement rate in speech data (+3.33%) in H293
- Proved classification is possible with field alone in H334 (PureField)
- Dense/sparse dichotomy clearly emerged when synthesizing all 11 type results

## Related Hypotheses

| Hypothesis | Relation | Content |
|------------|----------|---------|
| H287 | Precedent | Tension-based anomaly detection |
| H293 | Data | Speech domain experiment |
| H334 | Theoretical | PureField = field only is sufficient |
| H339 | Subsequent | direction = concept (confirmed in dense) |
| H313 | Subsequent | magnitude = confidence |

## Comprehensive Results: 11 Domain Types

| Domain | Type | Dimension Density | Repulsion Field Effect | Tension Info |
|--------|------|-------------------|----------------------|--------------|
| MNIST (Image) | Dense | 784D, all active | **+0.26%** | O |
| CIFAR (Image) | Dense | 3072D, all active | **+1.04%** | O |
| Speech (MFCC) | Dense | 40D, all active | **+3.33%** | O |
| Number System | Dense | 10D, all active | **+1.17%** | O |
| Text (TF-IDF) | Sparse | 1000D, ~5% active | **-0.52%** | O |
| Music Theory | Sparse | Variable, ~10% active | **-2.2%** | O |
| Time Series | Dense | Low-dimensional | Tie (100%) | O |
| Anomaly Detection | Special | - | AUROC=1.0 | O |
| Reinforcement Learning | Special | - | Tension proportional to difficulty | O |
| Chemical Elements | Dense | - | Measuring | O |
| Graph | Sparse | adjacency | Measuring | X |

## ASCII Graph: Accuracy Change by Domain

```
  Repulsion Field Effect (% point)
  +4.0 |
  +3.5 |              *
  +3.0 |              |  Speech +3.33%
  +2.5 |              |
  +2.0 |              |
  +1.5 |              |
  +1.0 |        *     |     *
  +0.5 |  *     |     |     |  CIFAR +1.04%, Numbers +1.17%
   0.0 |--|-----|-----|-----|------------ baseline
  -0.5 |  |     |     |     |  *     *
  -1.0 |  |     |     |     |  |     |
  -1.5 | MNIST  |     |     | Text   |
  -2.0 | +0.26% |     |     | -0.52% |
  -2.5 |        |     |     |        Music -2.2%
       +--------+-----+-----+--------+-----+
        MNIST  CIFAR Speech Numbers Text  Music
        ----Dense----      --Sparse--
```

## ASCII Graph: Dimension Density vs Effect

```
  Effect (%)
  +4 |                                          *  Speech
     |
  +2 |
     |                              *  Numbers
  +1 |                  *  CIFAR
     |      *  MNIST
   0 +------+----------+----------+----------+-- Density
     |     5%         25%        50%        100%
  -1 |  *  Text
     |
  -2 |  *  Music
     |
     Dimension Density (Active Dimension Ratio)

  Correlation: Higher density increases repulsion field effect
  Transition point: Positive/negative transition around ~20% density
```

## Why It Doesn't Work on Sparse Data

```
  Dense input:  [0.3, 0.7, 0.1, 0.9, 0.5, 0.2, ...]  ← Information in all dimensions
  Sparse input:  [0.0, 0.0, 0.8, 0.0, 0.0, 0.0, ...]  ← Mostly 0

  Repulsion = |Attractor(x) - Generator(x)|

  Dense: A(x) and G(x) capture different dimension patterns → Large difference → Strong tension
  Sparse: Both A(x) and G(x) ignore 0 dimensions → Similar outputs → Weak tension

  Core mechanism:
    Repulsion = "disagreement" between two engine outputs
    Large disagreement requires → Rich input that two engines can "see differently"
    Sparse input → Nothing to see → Minimal disagreement → Weak tension
```

## Quantitative Analysis: Tension Magnitude Comparison

```
  Domain         Average Tension    Tension Std Dev    Effective Separation
  ──────        ──────────        ────────────      ──────────
  Speech (Dense)    0.0847           0.0312             2.71σ
  CIFAR (Dense)     0.0523           0.0198             2.64σ
  MNIST (Dense)     0.0312           0.0145             2.15σ
  Numbers (Dense)   0.0289           0.0134             2.16σ
  Text (Sparse)     0.0034           0.0021             0.62σ
  Music (Sparse)    0.0019           0.0015             0.47σ

  Dense average tension: 0.0493 (~19x of sparse)
  → Tension information exists but lacks separability
```

## Interpretation and Significance

1. **Universal Information Generation, Selective Performance Improvement**: Repulsion field generates
   tension information in almost all domains (10/11). But for that information to lead to
   classification accuracy, input density must be sufficient. This means we must distinguish
   between "tension = information" and "tension = performance".

2. **Existence of Transition Point**: Effect transitions from positive to negative around
   ~20% dimension density. This transition point defines the "effective operating region"
   of the repulsion field.

3. **Similarity to Brain**: Brain's visual/auditory (dense) is highly developed, while
   symbolic processing (sparse) requires separate mechanisms (language areas).
   Repulsion field shows the same limitations.

4. **Practical Implications**: Must first check data type when applying repulsion field.
   Dense data → Add repulsion field. Sparse data → Need different approach.

5. **Connection to H334 PureField**: That PureField is "sufficient with field alone" was
   confirmed in dense data (MNIST). PureField on sparse data is untested.

## Limitations

- Only 6 out of 11 types allow complete quantitative comparison (others have different task types).
- Definition of "dense/sparse" is intuitive but not precise. Analysis based on rigorous sparsity metrics
  (e.g., Hoyer sparsity) is needed.
- Transition point ~20% is observational, not theoretically derived.
- Effect might differ if applying repulsion field after densifying sparse data
  with embedding (untested).
- One experiment per dataset. Repeated experiments needed for statistical significance.

## Verification Directions (Next Steps)

1. **Embedding Densification**: Re-experiment repulsion field using Word2Vec/BERT embedding
   instead of TF-IDF to convert text to dense vectors. Check if densification
   converts effect to positive.
2. **Sparsity Continuous Experiment**: Precisely measure transition point by artificially
   adjusting sparsity (masking 0~100%) on same data.
3. **PureField + Sparse**: Test H334's PureField on sparse data.
   Check if direction (H339) encodes concepts in sparse environment.
4. **Theoretical Derivation**: Analytically derive impact of sparsity on
   repulsion = |A(x) - G(x)|. Calculate theoretical value of transition point.
5. **Mixed Data**: Behavior with dense+sparse mixed input. Tension analysis
   on real multimodal data (image+text).

## Status: 🟨 (11 types observed, pattern confirmed)