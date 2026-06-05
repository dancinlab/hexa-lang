# fusion-byteeq-util-law — the HEXA-FUSION megakernel negative result

> A 🔴 closed-negative paper: no megakernel realisation is simultaneously
> CE-byte-equivalent AND real-step-util-lifting, and GPU utilisation is
> governed by SM-fill, not by fusion. Valid under `paper_negative_ok`.

## Source

- `main.tex` — single-column arxiv-style LaTeX (article class, 11pt A4).
  Figures are **inline pgfplots/TikZ** (util-vs-D, util-vs-batch, the
  wall-relocation ladder) — no external matplotlib step.
- `references.bib` — 12 BibTeX entries, each with DOI / arXiv id / URL.
- `Makefile` — `make` builds `main.pdf` (pdflatex × 3 + bibtex).

## Build

```bash
make            # → main.pdf  (requires a TeX Live host: pgfplots, natbib, booktabs)
make clean      # remove .aux/.log/.bbl (keep PDF)
make distclean  # also remove PDF
```

**Compile is DEFERRED.** No local xelatex/pdflatex on the authoring host
(see memory `reference_paper_compile_toolchain`); the figures are pgfplots
source and the document is scaffolded + lint-checked locally, with the
pdflatex×3+bibtex pass deferred to a TeX Live host.

## What this paper documents

Five GPU-verified falsification layers, each relocating the byte-eq wall,
plus the campaign's one positive law (utilisation = SM-fill):

| layer | id | verdict file |
|-------|----|--------------|
| mutual exclusion | B3 | `.verdicts/hexa-fusion/F-FUSION-B3-REALTRAINER.txt` |
| FP64 own-GEMM ≠ cuBLAS (~4 ULP) | B6 | `.verdicts/hexa-fusion/F-FUSION-B6-BYTEEQ-MEGAKERNEL.txt` |
| not GEMM order — host↔device erf | P1B-d / P1B-c1 | `.verdicts/hexa-fusion/F-FUSION-P1B-REBASELINE.txt` |
| TF32 fwd-megakernel +5.51pp | P1 | `.verdicts/hexa-fusion/F-FUSION-P1-TF32-MEGASTEP.txt` |
| right-size bimodal | P2 | `.verdicts/hexa-fusion/F-FUSION-P2-RIGHTSIZED-REALSTEP.txt` |
| research grounding | — | `.discoveries/hexa-fusion-p1b-reduction-order.tape` |

The deeper layers (device-glue race ~7e-6, zero-on-alloc falsified ~1e-1,
the async cross-stream race cured by `HEXA_CUDA_ASYNC=0`) are recorded in
the `F-FUSION-P1B-REBASELINE` finding and the discovery tape; the
async-OFF capstone (P1B-a''') is noted as in-flight and the paper's
finding is written to accommodate either terminal outcome.

## Honest stance

- Every section claim traces to a `.verdicts/hexa-fusion/<id>.txt` verdict;
  the verbatim 17-digit CE deltas are quoted, not paraphrased.
- This is framed as a **negative result** (`paper_negative_ok`): the
  pre-registered falsifier + the ruled-out space.
- The B200-served-for-H100 substrate caveat is reproduced as the verdicts
  recorded it (not papered over).
