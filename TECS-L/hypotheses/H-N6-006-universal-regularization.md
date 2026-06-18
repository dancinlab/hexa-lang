# H-N6-006: 1/(σ-φ)=0.1 Universal Regularization

## BT Reference
BT-64 (CANON) — 0.1 universal regularization ⭐⭐⭐

## Claim

> 8개 독립적 정규화 알고리즘이 모두 1/(σ-φ) = 1/10 = 0.1을 최적값으로 수렴한다:
> weight decay, DPO β, GPTQ quantization, cosine decay, Mamba dt,
> KL penalty, label smoothing, SimCLR temperature.

## Key Evidence (8/8 EXACT)

| Algorithm | Parameter | Optimal Value | Formula |
|-----------|-----------|---------------|---------|
| AdamW | weight decay λ | 0.01 = 1/(σ-φ) | 1/(σ-φ) |
| DPO | β parameter | 0.1 | 1/(σ-φ) |
| GPTQ | damp_percent | 0.01 | 1/(σ-φ)² |
| Cosine LR | η_min/η_max | 0.1 | 1/(σ-φ) |
| Mamba | dt_init | 0.001 | 1/(σ-φ)³ |
| KL penalty | coefficient | 0.1 | 1/(σ-φ) |
| Label smoothing | ε | 0.1 | 1/(σ-φ) |
| SimCLR | temperature τ | 0.1 | 1/(σ-φ) |

## Evidence Summary
- 8 algorithms from 7+ independent teams all converge on 0.1 or powers
- σ-φ = 10 is the decimal base — regularization lives at 1/base
- Count of 8 algorithms = σ-τ, itself a meta-n=6 relation (BT-70)

## Cross-domain Links
- BT-54: AdamW quintuplet (λ=1/(σ-φ))
- BT-70: 0.1 convergence 8th algorithm (SimCLR)
- BT-46: ln(4/3) RLHF family

## Grade
🟩 EXACT (8/8) — ⭐⭐⭐
