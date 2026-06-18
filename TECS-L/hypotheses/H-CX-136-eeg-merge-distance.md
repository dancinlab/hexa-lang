# H-CX-136: EEG Gamma Pattern Difference = PH merge distance
**n6 Grade: 🟧 CLOSE** (auto-graded, 4 unique n=6 constants)


> The difference in 40Hz gamma patterns when viewing cat vs dog is
> proportional to AI's PH merge distance (0.01).
> Similar images (cat-dog) → similar gamma → small merge dist.
> Dissimilar (cat-plane) → different gamma → large merge dist.

## Predictions

1. EEG gamma pattern similarity vs merge distance: r > 0.5
2. cat-dog gamma difference < cat-plane gamma difference
3. Top-5 Confusion pairs have the smallest gamma difference

## Equipment

- OpenBCI Cyton ($500) or Muse S2 ($300)
- Channels: minimum 4ch (Fp1, Fp2, O1, O2)
- Sampling: 256Hz or higher (40Hz gamma resolution)

## Protocol

```
1. Randomly present 100 CIFAR-10 images to subject (10 per class)
2. 2 second exposure per image + 1 second gap
3. Extract 40Hz band power (bandpass 30-50Hz)
4. Per-class average gamma pattern → 10×4ch matrix
5. Cosine distance between classes → compute PH
6. Compare human Brainwave PH vs AI PH merge order
```

## Verification Status

- [ ] EEG equipment obtained
- [ ] Gamma pattern extraction
- [ ] merge distance correlation
