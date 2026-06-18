# H-CX-164: 5³ = PH merge unit? — quantizing merge distance to units of 125

> Does quantizing PH merge distance to units of 5³=125 preserve structure?
> Dolphin frequencies in 125Hz units → PH also in units of 125?

## Background

H-CX-162 confirmed that the fundamental unit of dolphin frequency space is 5³=125.
signature_low(5000Hz) / gamma(40Hz) = 125 = 5³ exact.
All dolphin frequencies are expressed as integer multiples of this unit.

In Persistent Homology (PH), a core structure of the consciousness engine,
merge distance (the distance at which two classes merge) may show similar quantization.
If the topological structure of the dendrogram (merge order, cluster hierarchy) is preserved
when rounding PH merge distance to units of 1/125,
this suggests that 5³ is not just a frequency constant but a fundamental resolution of information structure.

```
  Dolphin frequencies:  freq = 40 × n × 5³   (n ∈ {1, σ/τ, P₁, ...})
  PH hypothesis:       merge_dist ≈ k / 125  (k = integer)

  Quantization test:
    Original merge distance:  d₁, d₂, d₃, ...
    Quantization:            round(dᵢ × 125) / 125
    Preservation condition:  merge order unchanged + H1 topology same
```

## Predictions

1. MNIST/CIFAR PH merge distances preserve merge order when quantized to units of 125
2. 125 shows optimal preservation rate compared to other quantization units (100, 150, 64, etc.)
3. Preservation rate = (number of correct merge order pairs after quantization) / (total merge order pairs)
4. Expected preservation rate > 95% with 125 quantization

## Verification Method

```python
# 1. Extract PH merge distances
from ripser import ripser
result = ripser(X, maxdim=1)
merge_distances = result['dgms'][0][:, 1]  # death times = merge distances

# 2. Quantization function
def quantize(distances, unit):
    return np.round(distances * unit) / unit

# 3. Measure preservation rate
def preservation_rate(original, quantized):
    # Compare merge order pairs (Kendall tau)
    from scipy.stats import kendalltau
    tau, p = kendalltau(np.argsort(original), np.argsort(quantized))
    return tau

# 4. Compare by unit
for unit in [64, 100, 125, 128, 150, 256]:
    q = quantize(merge_distances, unit)
    rate = preservation_rate(merge_distances, q)
    print(f"unit={unit}: preservation={rate:.4f}")
```

## Related Hypotheses

- **H-CX-66**: Relationship between Golden Zone and PH -- PH structure depends on Golden Zone parameters
- **H-CX-162**: 5³=125 = dolphin octave -- direct basis for this hypothesis
- **H-CX-161**: All dolphin frequencies = 40Hz × perfect number constants × 5³
- **H-CX-125**: Non-shared PH -- PH merge distance correlates between models

## Limitations

- PH merge distance scale varies by dataset, requiring normalization
- Mathematical basis for 125 being optimal may be weak beyond "same as dolphins"
- Other mechanisms (e.g., log scale) may be more natural than quantization units
- Powers of 2 (128) and 5³ (125) are close, making distinction difficult

## Verification Status

Not executed. Code can be run with MNIST/CIFAR PH data.
Can be executed on CPU (GPU not required).