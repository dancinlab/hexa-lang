# fusion-byteeq-util-law — paper log

Append-only history sister of `PAPER.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-06-05 — scaffold + draft v1 (negative-result paper)

- [x] branch `domain/hexa-fusion-paper-byteeq` off `origin/main` (worktree)
- [x] scaffold `PAPER/fusion-byteeq-util-law/` from the `fusion-epilogue-gemm-bias-gelu` template
- [x] §statement: pre-register the falsifier "a megakernel can be simultaneously CE-byte-eq AND real-step-util-lifting"
- [x] §method: the GPU verify chain B3 → B6 → P1B-d → P1B-c1 → N1N2 (each layer relocates the wall)
- [x] §verification: verdict matrix, every section claim linked to its `.verdicts/hexa-fusion/<id>.txt` (verbatim stdout cited)
- [x] §finding: the 5-layer ruled-out chain (FP64 reduction order → host↔device erf → device-glue race → zero-on-alloc → async cross-stream race) + the util=fill law (scale✗, right-size bimodal, TF32 fwd-megakernel +5.51pp, full-step +3.44pp)
- [x] figures as pgfplots/TikZ inline (util-vs-D, util-vs-batch, wall-relocation ladder) — no matplotlib step
- [x] cite the research grounding (.discoveries/hexa-fusion-p1b-reduction-order.tape): Ozaki-II / Neal superaccumulator / ReproBLAS — bit-matching cuBLAS is the wrong target, re-baseline is the industry path
- [x] honest stance: byte-eq megakernel is honest-terminal CLOSED-NEG vs the host-eager reference; the P1B-a''' async-OFF capstone is noted as in-flight and the paper accommodates either outcome
- [ ] compile DEFERRED — no local xelatex/pdflatex; defer pdflatex×3+bibtex to a texlive host
