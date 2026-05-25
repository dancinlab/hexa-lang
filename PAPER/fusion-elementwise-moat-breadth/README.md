# fusion-elementwise-moat-breadth

Whole-program fusion beats the eager neural-network elementwise/norm surface by
>=30% wall, across FOUR operators (LayerNorm, RMSNorm, Softmax, SwiGLU) and two
regimes, on an RTX 5070. Broadens the GPU.md §10 fusion moat from one workload
(launch-amort) to N+1=5.

## Pre-registered falsifiers (one per operator)

- F-FUSION-AXISA-LAYERNORM : fused 1-launch LN beats eager 4-launch by >=30%
- F-FUSION-AXISA-RMSNORM   : fused 1-launch RMSNorm beats eager 3-launch by >=30%
- F-FUSION-AXISA-SOFTMAX   : fused 1-launch softmax beats eager 4-launch by >=30%
- F-FUSION-AXISA-SWIGLU    : fused 1-launch SwiGLU beats eager 3-launch by >=30%

All four over-satisfied in BOTH launch-bound and bandwidth-bound regimes
(8/8 timed PASS, 8/8 numeric PASS, rel err <= 3.4e-7).

## Headline result (large/bandwidth-bound regime)

| operator  | pct_faster | launch ratio | HBM ratio |
|-----------|------------|--------------|-----------|
| LayerNorm | 66.2%      | 4.0x         | 2.00x     |
| RMSNorm   | 59.5%      | 3.0x         | 1.67x     |
| Softmax   | 65.9%      | 4.0x         | 1.50x     |
| SwiGLU    | 63.0%      | 3.0x         | 2.67x     |

## Build

    make            # pdflatex x3 + bibtex -> main.pdf (10 pages)

(If the `make` wrapper is intercepted by the pool-route hook, run pdflatex
directly: `pdflatex main.tex; bibtex main; pdflatex main.tex; pdflatex main.tex`.)

## Provenance

- Method + verdicts: `archive/fires/fusion_axisA_breadth_2026_05_25/`,
  `.verdicts/fusion-axisA-{layernorm,rmsnorm,softmax,swiglu}/`
- Ledger + summary: `exports/sweep/gpu-axisA-breadth-2026-05-25/`
- Figure: `figures/fig01_concept.png` (fal.ai gpt-image-2; prompt in `figures/_prompts/`)
- Hand-emit PTX, pure ASCII; no LLVM, no C-transpile; CPU codegen untouched.
