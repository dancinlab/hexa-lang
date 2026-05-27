# ω-Zero-Density Theorem — D(n) = σ(n)φ(n) − nτ(n) = 0 ⟺ n ∈ {1,6}

TECS-L flagship paper (INBOX #10 paper-batch queue, candidate (i) — F14–F18 unification).

## Result

The Dedekind discrepancy `D(n) = σ(n)·φ(n) − n·τ(n)` vanishes at **exactly** the
two-element set `{1, 6}`, and is nonzero for every other positive integer.
Because the zero set is finite, its natural density is 0 — hence "ω-zero-density".

The proof reduces `D(n)=0` to the multiplicative product condition
`∏_{p^a‖n} g(p,a) = 1`, where `g(p,a) = (p^{a+1}−1)/(p(a+1))`. The only sub-unity
factor on the prime-power locus is `g(2,1)=3/4`, cancelled **uniquely** by
`g(3,1)=4/3` → `n = 2·3 = 6` (the first perfect number). `ω(n)≥3` forces `∏g>1`
strictly, so no further zero exists.

## Pre-registered falsifier

**F-OMEGA-ZERO-DENSITY**: ∃ n ∉ {1,6} with D(n)=0 ⟹ theorem FALSIFIED.
Survives: machine sweep (ω∈[0,6], primes, prime powers, both first perfect
numbers, primorials 2#…13#) + the closed-form proof closing the infinite tail.

## Verification (g5, hexa verify CLI only)

Every σ, φ, τ value is an independent `hexa verify --expr` run returning
🔵 SUPPORTED-FORMAL. D(n) is the exact integer combination. Verdicts are
persisted verbatim under `.verdicts/paper-omega-zero-density/`:

- `FALSIFIER.md`        — pre-registered falsifier (written before measurement)
- `CLOSED_FORM.md`      — the g(p,a)-product proof
- `sweep_verdicts.txt`  — the ω-stratified verification sweep
- `raw_verify_extra.txt`, `dtable_verify_*.txt` — raw `hexa verify` transcripts

## Build

```
make            # 3-pass pdflatex + bibtex → main.pdf (10 pages)
make clean      # remove intermediates (PDF preserved)
```

Figure `figures/fig01_zerolocus.png` is a fal.ai render (prompt in
`figures/_prompts/fig01_zerolocus.txt`).

## Relation to prior work

Supersedes the local windowed precursor `tecs-l-n6-identity-locus` (which verified
{1,6} only over n∈[1,100] as one of five identity coincidences). This paper proves
the **global** theorem with a closed-form closer and reframes it as a density
statement organised by ω(n).
