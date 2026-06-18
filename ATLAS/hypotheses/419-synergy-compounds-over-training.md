# H-419: Synergy Compounds Over Training (Positive Slope)

## Hypothesis

> The synergy between BitNet and Golden Zone INCREASES over training epochs.
> This "compounding effect" means the dual constraint becomes MORE valuable
> as the model trains longer, not less. The routing learns to exploit
> expert specialization patterns that only emerge in later epochs.

## Results

```
  MNIST synergy evolution:
  Epoch |  Synergy | Cumulative trend
  ──────+──────────+──────────────────
     1  |  +4.90%  | ====
     2  |  +5.23%  | =====
     3  |  +4.60%  | ====
     4  | +17.70%  | =================  (jump!)
     5  | +13.52%  | =============
     6  | +16.57%  | ================
     7  | +12.50%  | ============
     8  | +15.90%  | ===============
     9  | +14.50%  | ==============
    10  | +20.75%  | ====================  (peak!)

  Slope: +1.52%/epoch
  R-squared: strong upward trend

  FashionMNIST synergy evolution:
  Epoch |  Synergy | Cumulative trend
  ──────+──────────+──────────────────
     1  |  +7.38%  | =======
     2  | +11.98%  | ===========
     3  |  +8.46%  | ========
     4  | +11.05%  | ===========
     5  | +17.77%  | =================
     6  | +21.91%  | =====================
     7  | +22.37%  | ======================  (peak!)
     8  | +12.34%  | ============
     9  | +12.98%  | ============
    10  | +14.29%  | ==============

  Slope: +0.77%/epoch
```

### Phase Transition at Epoch 4 (MNIST)

```
  Epoch 3 → 4: synergy jumps from +4.6% to +17.7% (3.8x increase!)

  What happens at epoch 4:
    BitNet-Dense COLLAPSES: 87.07% → 75.04% (catastrophic forgetting)
    BitNet+Golden HOLDS:    92.14% → 93.14% (steady improvement)

  The phase transition is triggered by BitNet-Dense's instability.
  Without routing, ternary weights become unstable after initial convergence.
  With routing, the instability is contained by selective expert activation.
```

## Interpretation

1. **Routing improvement**: The Boltzmann gate learns expert strengths over time.
   Early epochs: routing is random-ish. Later: routing has learned which experts
   handle which inputs, creating targeted synergy.

2. **BitNet-Dense instability amplifies synergy**: As training progresses,
   BitNet-Dense becomes MORE unstable (oscillating accuracy), while BitNet+Golden
   remains stable. The growing gap IS the growing synergy.

3. **Implication for long training**: If synergy compounds at +1.5%/epoch,
   then longer training (20, 50, 100 epochs) should show even larger synergy.
   This predicts BitNet+Golden becomes increasingly superior at scale.

## Grade

🟧★ — Clear positive slope in both datasets. Phase transition at epoch 4 is
a strong structural finding. Needs longer training runs to confirm compounding.
