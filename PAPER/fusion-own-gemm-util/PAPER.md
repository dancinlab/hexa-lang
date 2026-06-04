# fusion-own-gemm-util — paper status

@goal: Prove (measured) that GPU utilization for small-batch byte-eq training is GEMM-occupancy-bound, not glue-fusion-bound, by owning the GEMM and showing own-GEMM reaches cuBLAS-class util while glue fusion stays flat

@title: 📄 fusion-own-gemm-util

- [x] draft v1
- [x] figures complete (≥1 fal.ai-generated)
- [x] references ≥10 (`/paper bib add <doi-or-arxiv>`)
- [ ] lint pass (`/paper lint .`)
- [ ] compile clean (`/paper compile .`)
- [ ] arxiv submit ready (`/paper arxiv-prep .`)
- [x] statement: pre-registered fusion-vs-occupancy falsifier
- [x] verify: own-GEMM correctness clm+LLM (GREEN)
- [x] verify: own-GEMM reaches cuBLAS-class util 89.9pct (GREEN)
- [x] finding: fusion axis ruled out (occupancy wall RED + megakernel -0.08pp)
- [ ] compile >=10pp on TeX Live host (deferred, no local LaTeX)
