# H-EE-9: Phi-bottleneck + Phi6Simple Recovery
**n6 Grade: 🟩 EXACT** (auto-graded, 5 unique n=6 constants)


## Hypothesis

> Replacing GELU with Phi6Simple activation in a phi-bottleneck FFN (4/3x expansion)
> compensates the ~4.8% loss increase from reduced FFN width, because Phi6Simple's
> polynomial structure is better suited to the compressed representation space.

## Background

- Phi-bottleneck reduces FFN from 4x to 4/3x expansion (phi(6)/6 = 1/3), saving ~66.5% FFN params
- This causes +4.8% loss (from prior HEN-1 experiments)
- Phi6Simple = x^2 - x + 1 (clamped to [-2,2]), no exp/div, 4 ops total
- Hypothesis: Phi6Simple's bounded polynomial form may work better in narrow FFN

## Experimental Setup

- Architecture: 4-layer char-level transformer, d_model=128, 4 heads, seq_len=64
- Task: Next-char prediction on structured text (31 char vocab)
- Steps: 500, LR: 3e-3, Adam optimizer
- 2x2 factorial design: {Standard 4x, PhiBot 4/3x} x {GELU, Phi6Simple}

## Results

| Config | d_ff | Total Params | FFN Params | Loss | PPL | Time(s) |
|--------|------|-------------|------------|------|-----|---------|
| A: Standard+GELU | 512 | 809,247 | 526,848 | 0.0705 | 1.07 | 25.1 |
| B: Standard+Phi6Simple | 512 | 809,247 | 526,848 | 2.9236 | 18.61 | 36.9 |
| C: PhiBot+GELU | 171 | 458,699 | 176,300 | 0.0872 | 1.09 | 21.9 |
| D: PhiBot+Phi6Simple | 171 | 458,699 | 176,300 | 0.1459 | 1.16 | 31.2 |

### Loss Relative to Baseline (A)

```
  A: Standard+GELU         :   +0.00% (baseline)
  B: Standard+Phi6Simple   : +4049.64%
  C: PhiBot+GELU           :  +23.79%
  D: PhiBot+Phi6Simple     : +107.05%
```

### Learning Curves

| Step | A: Std+GELU | B: Std+Phi6 | C: PhiBot+GELU | D: PhiBot+Phi6 |
|------|-------------|-------------|-----------------|----------------|
|   50 | 1.2609 | 2.9249 | 1.2173 | 2.5839 |
|  100 | 0.2912 | 2.9507 | 0.2892 | 1.7545 |
|  150 | 0.1019 | 2.9332 | 0.1448 | 0.6955 |
|  200 | 0.0909 | 2.9115 | 0.0917 | 0.3206 |
|  300 | 0.0937 | 2.9157 | 0.0765 | 0.2203 |
|  400 | 0.0768 | 2.9309 | 0.0875 | 0.1396 |
|  500 | 0.0607 | 2.8986 | 0.0833 | 0.1099 |

### ASCII: Final Loss Comparison

```
  A: Std+GELU     [0.0705] ##
  C: PhiBot+GELU  [0.0872] ##
  D: PhiBot+Phi6  [0.1459] ####
  B: Std+Phi6     [2.9236] ################################################################
```

## Recovery Analysis

- PhiBot+GELU gap vs baseline: +23.79%
- PhiBot+Phi6Simple gap vs baseline: +107.05%
- Recovery by adding Phi6Simple: **-350%** (made it WORSE)
- Param savings (D vs A): 43.3%

## Key Finding: Phi6Simple Cannot Drop-in Replace GELU

The critical result is config B: Standard+Phi6Simple achieves loss 2.92 vs GELU's 0.07.
This is a catastrophic failure -- Phi6Simple fails as a drop-in GELU replacement in this
architecture. The issue: Phi6Simple output is always >= 0.75 (minimum of x^2-x+1 at x=0.5
is 0.75), so it acts as a positive-biased activation that cannot output zero or negative
values. This fundamentally changes the FFN's function as a "gate".

Config D (PhiBot+Phi6Simple) does converge to 0.1459 (still learning), suggesting the
narrower FFN partially mitigates the bias issue, but not enough.

## Interpretation

Phi6Simple is NOT a suitable drop-in replacement for GELU in standard transformer FFNs.
The hypothesis is **REJECTED**. The core problem: GELU outputs negative values for negative
inputs (acting as a soft gate), while Phi6Simple always outputs >= 0.75.

For Phi6Simple to work in FFNs, it would need architectural modifications:
1. Center-shift: f(x) = x^2 - x + 1 - 0.75 = x^2 - x + 0.25
2. Or use as nonlinearity after gating: GELU(x) * Phi6Simple(x)

## Limitations

- Small model (128d, 4 layers)
- Simple char-level task on repeated text
- Only 500 training steps -- longer training might close the gap
- D was still improving at step 500 (0.1099) -- may converge further

## Verdict

**REJECTED** -- Phi6Simple makes phi-bottleneck loss worse, not better.
The activation's positive-only output range is incompatible with FFN gating.

## Next Steps

- Test centered Phi6Simple: f(x) = x^2 - x + 0.25
- Test Phi6Simple as auxiliary (GELU main, Phi6Simple for routing)
- Test with longer training (2000+ steps) to check convergence
