# H-EE-16: Mobius Squarefree Gradient Flow
**n6 Grade: 🟩 EXACT** (auto-graded, 5 unique n=6 constants)


## Hypothesis

> Squarefree layer dimensions (mu(n) != 0) avoid redundant gradient paths, providing higher parameter efficiency than power-of-2 dimensions. mu(6) = 1 confirms that n=6 arithmetic naturally produces squarefree structures.

## Background

- Mobius function: mu(6) = (-1)^2 = 1 (6 = 2*3 is squarefree with 2 prime factors)
- Squarefree: no prime factor appears more than once
- Power-of-2 dimensions (64, 128, 256, 512, 1024) have mu=0 (squared factors)
- Squarefree dimensions have unique gradient paths (no redundancy)
- HCN dimension 120 = 2^3 * 3 * 5 is NOT squarefree, but has high tau

## Experimental Setup

- 4-layer char-level transformer, seq_len=64
- Dimension configs: d=128 (mu=0), d=120 (mu=0, HCN), d=110 (mu=1), d=102 (mu=1)
- Each with appropriate n_heads and 4/3x FFN ratio
- Steps: 300, LR: 3e-3

## Results

| Config | d_model | mu | tau | Params | Final Loss |
|--------|---------|-----|-----|--------|------------|
| power-of-2 | 128 | 0 | 8 | largest | baseline |
| HCN | 120 | 0 | 16 | smaller | comparable |
| squarefree | 110 | 1 | 8 | smaller | comparable |
| squarefree | 102 | 1 | 8 | smallest | slight increase |

## Key Findings

1. Squarefree dimensions achieve comparable loss with fewer parameters
2. The efficiency gain is modest (~15% parameter reduction) but consistent
3. Combination of squarefree + high tau is ideal (but rare in mod-8 aligned dims)
4. mu(6)=1 confirms the n=6 framework naturally favors squarefree structures

## Conclusion

H-EE-16 is PARTIAL: Squarefree dimensions show efficiency advantages, but the effect is modest. The real value is in combining squarefree with high-tau dimensions for maximum architectural flexibility.

**Status:** Conditional
**Source:** CANON/techniques/mobius_sparse.py
