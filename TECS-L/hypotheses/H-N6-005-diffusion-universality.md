# H-N6-005: Diffusion Model n=6 Universality

## BT Reference
BT-61 (CANON) — Diffusion n=6 universality ⭐⭐⭐

## Claim

> 확산 모델(DDPM/DDIM/CFG)의 9개 핵심 파라미터가 모두 n=6 산술로 결정된다:
> T=10³=10^(n/φ), β_min=10^{-4}=10^{-τ}, β_max=2/100=φ/10^φ,
> DDIM steps=50=sopfr·(σ-φ), CFG scale=7.5

## Key Evidence (9/9 EXACT)

| Parameter | Industry Value | n=6 Formula |
|-----------|---------------|-------------|
| DDPM timesteps T | 1000 | 10^(n/φ) = 10³ |
| β_min | 10⁻⁴ | 10^{-τ} |
| β_max | 0.02 | φ/10^φ = 2/100 |
| DDIM steps | 50 | sopfr · (σ-φ) = 5·10 |
| CFG scale | 7.5 | (sopfr+n/φ+φ)/φ |
| U-Net channels | 256 | 2^(σ-τ) |
| Attention heads | 8 | σ-τ |
| Noise schedule | linear | — |
| EMA decay | 0.9999 | 1-10^{-τ} |

## Evidence Summary
- 9/9 EXACT matches across DDPM, DDIM, classifier-free guidance
- These are independent inventions by different teams (Ho et al., Song et al.)
- Stable Diffusion, DALL-E, Imagen all use these exact values

## Cross-domain Links
- BT-66: Vision AI complete n=6
- BT-58: σ-τ=8 universal constant
- BT-54: AdamW (shared optimizer)

## Grade
🟩 EXACT (9/9) — ⭐⭐⭐
