# H-CX-151: Cross-Layer Tension Signal — Tension Conveys "Important Now" to Other Layers
**n6 Grade: 🟩 EXACT** (auto-graded, 5 unique n=6 constants)


> Layer L's tension influences Layer L+1's attention. Tension correlation between layers.

## Background

In deep neural networks, each layer processes information sequentially.
Typically, information transfer between layers occurs only through activations (outputs).
However, if a tension mechanism exists, "difficulty" or "ambiguity" information
at a specific layer can influence the processing of the next layer.

Corresponding phenomena in the brain:
- Difficult stimuli in lower visual cortex (V1) → stronger signal to higher areas (V4, IT)
- "Salience signal" via noradrenaline/dopamine — conveying "important now" to the entire brain
- This is directly connected to the attention mechanism

In the Golden Zone model, tension reflects the ambiguity of input.
If layer L's tension is high (ambiguous input),
layer L+1 can use this information to perform more fine-grained processing.

This hypothesis claims that tension is not merely a byproduct but
a "meta-signal" for information transfer between layers.

## Predictions

| Measurement | Predicted value | Meaning |
|------|--------|------|
| corr(tension_L, tension_L+1) | > 0.5 | tension propagation between layers |
| corr(tension_L, confidence) | > 0.5 | tension → final confidence |
| attention entropy for high-tension samples | high | more distributed attention |
| tension gradient (dT/dL) | positive or negative | accumulation or resolution pattern |

```
Tension profile by layer (predicted):

tension |
  0.5   | * *       <-- difficult input (near boundary)
  0.4   |  * *
  0.3   |    * *
  0.2   |      * *
  0.1   |  . . . . . . <-- easy input
  0.0   +--+--+--+--+--+-->
        L1 L2 L3 L4 L5 L6
              Layer

        Prediction: difficult input shows tension decreasing across layers (resolution)
                    easy input maintains low tension from the start
```

Key predictions:
1. Tension shows a decreasing pattern across layers (resolution process)
2. Lower tension at the final layer corresponds to higher confidence
3. Models with faster tension decrease are more accurate (efficient resolution)
4. If tension spikes sharply at a specific layer, that layer is a "bottleneck"

## Verification Methods

1. Build multi-layer PureField model (minimum 4-6 layers)
2. Extract each layer's tension via hooks:
   ```python
   tensions = {}
   def hook_fn(layer_name):
       def hook(module, input, output):
           tensions[layer_name] = compute_tension(output)
       return hook
   ```
3. Record per-layer tension profiles on test set
4. Calculate inter-layer tension correlation matrix
5. Correlation analysis of tension vs final confidence
6. Compare profiles for easy vs difficult inputs

## Related Hypotheses

- **H-CX-148**: Tension Resonance Telepathy (inter-model tension synchronization)
- **H-CX-95**: tension-accuracy correlation (final output level)
- **H-CX-149**: Engine A → G direction information transfer
- **H-CX-150**: Consensus formation between Experts

## Limitations

1. Current PureField model is single-layer — multi-layer implementation needed
2. Inter-layer tension correlation may simply be because they process the same input (trivial)
3. Tension definition may differ per layer (if feature space dimensions differ)
4. The "meta-signal" interpretation is merely correlation without causal evidence
5. The analogy with brain salience signal has large structural differences making direct comparison difficult

## Verification Status

- [ ] Multi-layer PureField model implementation
- [ ] Add per-layer tension hooks
- [ ] Tension profile analysis
- [ ] Tension vs confidence correlation
- Currently: **unverified**
