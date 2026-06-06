# fusion-byteeq-util-law — paper status

@title: 🧱 The Byte-Equivalence Wall and the Utilisation-is-Fill Law — A Negative Result on Megakernel Fusion
@goal: Document, as a publishable negative result, that no megakernel realisation is simultaneously CE-byte-equivalent and real-step-util-lifting, and that GPU utilisation is governed by SM-fill, not by fusion.

- [x] draft v1 (negative-result framing, 4 required sections)
- [x] §statement — pre-registered falsifier (byte-eq ∧ util-lift)
- [x] §method — the GPU verify chain (B3 → B6 → P1B-d → P1B-c1 → N1N2)
- [x] §verification — verdict matrix, every claim → .verdicts/hexa-fusion/<id>.txt
- [x] §finding — 5-layer ruled-out chain + util=fill law
- [x] figures (pgfplots: util-vs-D, util-vs-batch, the wall-relocation ladder)
- [ ] references ≥10 (`/paper bib add <doi-or-arxiv>`) — 12 entries in references.bib
- [ ] lint pass (`/paper lint .`)
- [ ] compile clean (`/paper compile .`) — DEFERRED: no local xelatex/pdflatex (texlive host)
- [ ] arxiv submit ready (`/paper arxiv-prep .`)
