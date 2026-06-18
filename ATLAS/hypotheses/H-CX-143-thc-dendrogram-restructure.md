# H-CX-143: THC = Dendrogram Restructuring
**n6 Grade: 🟧 CLOSE** (auto-graded, 3 unique n=6 constants)


> Animal/machine separation transitions to color/shape/emotion-based separation. "Seeing the world from a different perspective."

## Background

In a normal consciousness state, the CIFAR-10 PH dendrogram separates into
animal/vehicle as semantic top-level categories. This aligns with the basic categorization
of human cognition (Rosch, 1975), and the learned features reflect semantic similarity.

THC weakens top-down inhibition through CB1 receptors.
In this case, semantic categorization weakens, and instead
low-level perceptual features (color, shape, texture) or emotional responses
can become the new basis of categorization.

This also connects to synesthesia-like experiences:
THC users report "colors appear more vivid", "music feels visual" —
these can be interpreted as a shift in categorization criteria.

If H0_total decreases as predicted in the prior hypothesis H-CX-142, the existing dendrogram could collapse and reorganize under new criteria. Whether this is simple collapse or restructuring is the core question of this hypothesis.

## Predictions

| Measurement | Normal dendrogram | THC dendrogram (predicted) |
|------------|-------------------|---------------------------|
| Top-level separation | animal vs vehicle | color-warm vs color-cool or round vs angular |
| Separation basis | semantic meaning | perceptual features |
| Depth | 3-4 levels | 2-3 levels (simplified) |
| Stability | consistent across trials | increased trial-to-trial variation |

```
Normal state dendrogram:      THC state dendrogram (predicted):

     ALL                           ALL
    /   \                         /   \
 ANIMAL  VEHICLE              WARM    COOL
 / | \   / | \               / | \   / | \
cat dog  car truck          cat car  dog truck
deer frog ship plane        deer frog ship plane
         horse bird         (orange)  (blue/gray)
```

Specific predictions:
1. cophenetic correlation between normal vs THC dendrograms r < 0.3 (structural change)
2. THC dendrogram places same color-family classes close together
3. Transition from normal → THC shows discontinuous change in dendrogram topology (phase transition)

## Verification Methods

1. Generate dendrogram while progressively reducing tension_scale in PureField model
2. Calculate cophenetic distance matrix at each step
3. Measure cophenetic correlation between normal vs modulated dendrograms
4. Analyze clustering basis: semantic vs perceptual feature contribution

EEG protocol (same session as H-CX-142):
- Image classification task in normal/THC state
- Build PH dendrogram from activation patterns in each state
- Compare dendrogram topology

## Related Hypotheses

- **H-CX-142**: THC PH simplification (H0_total decrease, prior hypothesis)
- **H-CX-85**: PH dendrogram structure and consciousness
- **H-CX-152**: Rosch prototype theory and PH dendrogram
- **H-CX-144**: Gamma suppression (mechanism of dendrogram restructuring)

## Limitations

1. "Color/shape/emotion-based separation" is one of many possibilities; actual restructuring criteria may differ
2. Simple collapse (no structure) rather than restructuring is also possible
3. CIFAR-10's 10 classes may not be sufficient to observe restructuring
4. Uncertain how well tension_scale modulation in AI models reflects biological THC effects

## Verification Status

- [ ] AI model dendrogram comparison (tension_scale modulation)
- [ ] cophenetic correlation measurement
- [ ] Distinguish restructuring vs collapse
- Currently: **unverified**
