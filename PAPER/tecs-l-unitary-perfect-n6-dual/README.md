# A Unitary-Perfect Singleton at n=6

TECS-L paper 2/3 (INBOX #10). The first perfect number `6` is the **unique**
simultaneous ordinary-AND-unitary perfect number in `[1, 10^4]`, and the two
perfection sequences diverge at their next terms.

- **ordinary-perfect**: `sigma(n) = 2n`  (A000396: 6, 28, 496, 8128, ...)
- **unitary-perfect**:  `sigma*(n) = 2n` (A002827: 6, 60, 90, 87360, ...)
- **dual-perfect**:     both at once.

## Result

`6` is the only dual-perfect number in `[1, 10^4]`. The closure is a finite
**exhaustion** (not a sweep): dual-perfect ⊆ ordinary-perfect, and by
Euclid–Euler the ordinary-perfect numbers below `10^4` are exactly
`{6, 28, 496, 8128}`. Recomputing `sigma*` on each shows only `6` is unitary.
The sequences diverge immediately: `28` (ordinary) has `sigma*(28)=40≠56`;
`60` (unitary) has `sigma(60)=168≠120`.

## Falsifier (pre-registered)

`F-DUAL-PERFECT-N6`: ∃ n ≠ 6 in `[1,10^4]` that is dual-perfect ⟹ FALSIFIED.
Survives. See `../../.verdicts/paper-unitary-perfect-n6/FALSIFIER.md`.

## Verification

Twelve `hexa verify --expr` runs (sigma / sigma_star at 6, 28, 60, 90, 496,
8128), all 🔵 SUPPORTED-FORMAL. Raw transcripts:
`../../.verdicts/paper-unitary-perfect-n6/`.

## Build

```
make            # 3-pass pdflatex + bibtex -> main.pdf
make clean
```

Figure `figures/fig01_divergence.png` was generated via fal.ai from
`figures/_prompts/fig01_divergence.txt` (per commons g51 ≥1 figure).
