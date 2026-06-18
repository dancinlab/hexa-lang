# H-405: AnimaLM Expert Topological Specialization
**n6 Grade: 🟩 EXACT** (auto-graded, 13 unique n=6 constants)


> **Hypothesis**: In a trained AnimaLM (A-G repulsion field) model, Engine A experts
> and Engine G experts will develop distinct topological signatures measurable via
> Persistent Homology. Specifically: A-camp experts will have lower H0 persistence
> (more concentrated representations) while G-camp experts will have higher H1
> persistence (more loop structures = associative connections). The Wasserstein
> distance between A-camp and G-camp barcodes will correlate with model accuracy
> (r > 0.5), indicating that topological specialization drives performance.

**Golden Zone Dependency**: PH computation is GZ-independent. The A/G camp interpretation
inherits GZ dependency from the tension framework.

---

## Background

AnimaLM splits 8 experts into two camps:
- **Engine A (experts 0-3)**: logic/analytical processing
- **Engine G (experts 4-7)**: pattern/creative processing
- **Output**: `A - G` (pure repulsion)

H-404 showed that soft camp assignment preserves the hard A/G split on MNIST
(camp_a_prob = 0.86-0.90), suggesting the initial split is already reasonable.

But we have never measured the **topological structure** of what each camp learns.

### Key Questions

1. Do A-experts and G-experts develop different topological signatures?
2. Is topological divergence between camps correlated with accuracy?
3. Can we predict model quality from PH analysis of expert representations alone?

### Related Hypotheses

| Hypothesis | Connection |
|------------|-----------|
| H-CX-62 | PH topology predicts accuracy (r=-0.97 H0 vs acc) |
| H-CX-82 | Epoch 1 confusion map — does camp divergence appear at epoch 1? |
| H-CX-88 | Confusion topology consistency across architectures |
| H-CX-93 | Confusion PCA = semantic axes — do A/G camps align with semantic axes? |
| H-401 | PH correction uses barcode distance — specialization determines its magnitude |
| H-402 | PH routing depends on expert signatures — this tests if signatures are meaningful |
| H-404 | Soft camp preserved hard split — but topological divergence untested |

---

## Prediction: Topological Specialization Pattern

```
  Training progression (predicted):

  Epoch 1:  A-camp and G-camp nearly identical PH
            H0 persistence similar, H1 minimal
            Wasserstein distance ≈ 0 (no specialization yet)

  Epoch 3:  Divergence begins
            A-camp H0 decreases (tighter clusters)
            G-camp H1 increases (loop structures forming)
            Wasserstein distance grows

  Epoch 10: Stable specialization
            A: low H0, near-zero H1 (concentrated, simple topology)
            G: moderate H0, significant H1 (distributed, complex topology)
            Wasserstein distance plateaus

  Wasserstein(A,G) vs accuracy:

  Acc     │
  98% ──► │                           ●●●●●
  97% ──► │               ●●●●●●●●●●●
  96% ──► │         ●●●●●●
  95% ──► │    ●●●●
  94% ──► │●●●
          └──────────────────────────────────
          0.0   0.1   0.2   0.3   0.4   0.5
                  Wasserstein(PH_A, PH_G)

  Prediction: r > 0.5, monotonic increase
  Higher camp divergence → better repulsion → better accuracy
```

---

## Measurement Protocol

### Step 1: Train AnimaLM on MNIST + CIFAR-10

Use existing `experiment_anima_simplification.py` Raw Repulsion model.
At each epoch checkpoint, extract:

```python
# For each test batch:
out_a, out_g = get_ag_outputs(experts, gate, x, n_camp_a)

# Compute PH on A-camp output space
ph_a = ripser(out_a.detach().cpu().numpy(), maxdim=1)
barcode_a_h0 = ph_a['dgms'][0]  # connected components
barcode_a_h1 = ph_a['dgms'][1]  # loops

# Compute PH on G-camp output space
ph_g = ripser(out_g.detach().cpu().numpy(), maxdim=1)
barcode_g_h0 = ph_g['dgms'][0]
barcode_g_h1 = ph_g['dgms'][1]

# Metrics:
total_pers_a_h0 = sum(death - birth for birth, death in barcode_a_h0 if finite)
total_pers_g_h0 = ...
total_pers_a_h1 = ...
total_pers_g_h1 = ...
wasserstein_h0 = wasserstein_distance(barcode_a_h0, barcode_g_h0)
wasserstein_h1 = wasserstein_distance(barcode_a_h1, barcode_g_h1)
```

### Step 2: Track Divergence Over Training

| Epoch | A_H0_pers | G_H0_pers | A_H1_pers | G_H1_pers | W_H0 | W_H1 | Acc |
|-------|-----------|-----------|-----------|-----------|------|------|-----|
| 1     | ?         | ?         | ?         | ?         | ?    | ?    | ~95%|
| 3     | ?         | ?         | ?         | ?         | ?    | ?    | ~97%|
| 5     | ?         | ?         | ?         | ?         | ?    | ?    | ~97.5%|
| 10    | ?         | ?         | ?         | ?         | ?    | ?    | ~97.8%|

### Step 3: Statistical Tests

- Spearman correlation: Wasserstein vs accuracy across epochs
- Permutation test: randomize A/G assignment, measure if real split > random
- Cross-dataset: verify pattern holds for both MNIST and CIFAR-10

---

## ASCII Architecture: What We're Measuring

```
  Input tokens
      │
      ▼
  [BoltzmannRouter I≈1/e]
      │
  ┌───┴───────────────────────────┐
  │                               │
  E0  E1  E2  E3          E4  E5  E6  E7
  └──── A-camp ────┘      └──── G-camp ────┘
         │                       │
       out_A                   out_G
         │                       │
    ┌────┴────┐            ┌─────┴────┐
    │  PH(A)  │            │  PH(G)   │
    │ H0: ??? │            │ H0: ???  │
    │ H1: ??? │            │ H1: ???  │
    └────┬────┘            └────┬─────┘
         │                      │
         └──── Wasserstein ─────┘
               distance
                 │
         correlation with accuracy?
```

---

## Experimental Results

### MNIST (10 epochs, seed 42)

```
  Ep |    Acc |  A_H0   |  G_H0   |  A_H1  |  G_H1  |    BD   | BD_rnd
  ───┼────────┼─────────┼─────────┼────────┼────────┼─────────┼────────
   1 | 95.73% | 367.021 | 290.809 | 11.044 |  5.564 | 0.1897  | 0.1674
   2 | 96.60% | 410.462 | 379.805 | 12.497 |  7.990 | 0.0646  | 0.0721
   3 | 97.08% | 469.517 | 429.329 | 10.256 |  9.430 | 0.0119  | 0.0884
   5 | 97.38% | 542.319 | 507.003 | 10.880 |  9.737 | 0.0036  | 0.0323
   7 | 97.47% | 662.553 | 563.465 | 14.301 |  6.476 | 0.0875  | 0.1539
  10 | 97.89% | 584.784 | 789.295 | 10.408 | 18.843 | 0.1186  | 0.0881

  BD vs Acc: r = -0.200, p = 0.58  → NO CORRELATION
  |H0_diff| vs Acc: r = -0.018, p = 0.96  → NO CORRELATION
  BD real (0.058) < BD random (0.072) → A/G split ≤ random (ratio 0.81)
```

**MNIST VERDICT: NOT SUPPORTED** — No topological specialization on ceiling-bound data.

Notable: at epoch 10, G_H0 (789) surpassed A_H0 (585) — late reversal, but
overall no consistent direction (A>G or G>A alternates randomly).

### CIFAR-10 (15 epochs, seed 42)

```
  Ep |    Acc |  A_H0   |  G_H0   |  A_H1  |  G_H1  |    BD   | BD_rnd
  ───┼────────┼─────────┼─────────┼────────┼────────┼─────────┼────────
   1 | 44.58% | 102.496 | 131.710 |  2.753 |  3.578 | 0.1446  | 0.1867
   3 | 48.42% | 129.025 | 139.996 |  3.664 |  4.203 | 0.0841  | 0.0054
   5 | 49.95% | 136.403 | 186.402 |  4.631 |  5.313 | 0.0874  | 0.2159
   7 | 51.28% | 170.415 | 196.170 |  4.001 |  3.287 | 0.0419  | 0.0148
  10 | 51.23% | 171.843 | 257.303 |  3.661 |  5.993 | 0.1840  | 0.1672
  12 | 52.57% | 172.083 | 192.512 |  3.229 |  4.629 | 0.0412  | 0.1924
  15 | 53.26% | 174.554 | 204.165 |  4.444 |  5.272 | 0.1659  | 0.0009

  BD vs Acc: r = +0.336, p = 0.22  → WEAK POSITIVE (not significant)
  |H0_diff| vs Acc: r = +0.232, p = 0.41  → WEAK
  BD real (0.097) ≈ BD random (0.093) → ratio 1.04

  G_H0 > A_H0: 15/15 epochs (100%)  ← CONSISTENT PATTERN
  G_H1 > A_H1: 10/15 epochs (67%)
```

**CIFAR-10 VERDICT: PARTIAL SUPPORT** — G-camp consistently develops higher H0
persistence (100% of epochs), indicating G-experts learn more distributed/complex
representations than A-experts. However, BD vs Acc correlation is weak (r=0.34)
and not statistically significant (p=0.22).

### Key Finding: G-camp H0 > A-camp H0 on Complex Data

```
  MNIST (simple):    G_H0 > A_H0 in  1/10 epochs (10%)  — no pattern
  CIFAR (complex):   G_H0 > A_H0 in 15/15 epochs (100%) — strong pattern

  G_H0/A_H0 ratio over CIFAR training:
  1.0 ─── no difference ──────────────────────────────────────────
       │●         ●
  1.1 ─│──────●──────────────●──────────────────────────────────
       │         ●     ●
  1.2 ─│────────────●────────●──────●──────────●────●───────●──
       │
  1.3 ─│───────────────────────────────────────────────────────
       │●                                ●
  1.4 ─│──────────────●──────────────────────────────────────
       │                          ●
  1.5 ─│────────────────────●──────────────────────────────────
       └───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬──
           1   2   3   4   5   6   7   8   9  10  11  12  13  14 15
                                 Epoch

  Interpretation: On complex data (CIFAR), the G-camp (pattern/creative)
  consistently develops MORE topological structure than A-camp (logic).
  This suggests the camps DO specialize — but specialization does NOT
  predict accuracy improvement (BD vs Acc r=0.34, p=0.22).
```

---

## Falsification Criteria

1. If Wasserstein(A,G) shows no correlation with accuracy (r < 0.3): **MNIST REFUTED (r=-0.20)**
2. If A-camp and G-camp develop identical PH profiles: **CIFAR REFUTED — clear G>A pattern**
3. If random A/G assignment achieves same Wasserstein: **MNIST: yes (ratio 0.81), CIFAR: borderline (ratio 1.04)**

**Overall: Criterion 2 is refuted on CIFAR (camps DO specialize), but criterion 1 is
not met (specialization doesn't predict accuracy). Mixed result.**

---

## Limitations

1. **MNIST ceiling**: limited dynamic range for correlation measurement
2. **Batch size dependence**: PH on different batch sizes may give different barcodes
3. **Expert count**: only 4 experts per camp — small sample for PH computation
4. **Output space PH**: measuring PH on 10-dim output, not hidden representations.
   Hidden dim PH would be richer but more expensive
5. **Confound**: divergence and accuracy both increase with training.
   Must control for epoch (partial correlation or detrending)
6. **Single seed**: only seed 42 tested. Need 3+ seeds for statistical confidence.

---

## Next Steps

1. Run with 3+ seeds to confirm G_H0 > A_H0 pattern on CIFAR
2. Measure on hidden representations (not just output) for richer PH signal
3. Detrend BD and Acc to remove shared training trend (partial correlation)
4. Cross-reference with H-CX-93: do A/G camps align with animal/machine semantic axis?
5. If confirmed: G-camp specialization supports H-401 (PH correction has real signal)

---

*H-405 | Status: Partial (CIFAR: G_H0>A_H0 100%, but BD vs Acc r=0.34 NS) | GZ-dependency: Partial*
*Related: H-401, H-402, H-404, H-CX-62, H-CX-82, H-CX-88, H-CX-93*
