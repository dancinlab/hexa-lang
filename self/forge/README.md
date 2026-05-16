# forge — hexa-lang's GPU compute substrate

> **Status: NAMING + SCAFFOLD (2026-05-16). Underlying code already exists
> and is verified.** `forge` is the SSOT label for the runtime/CUDA
> substrate that `flame` stdlib calls. This directory is not new code —
> it is the durable scaffold for what already lives in `self/runtime.c`
> (cuBLAS bindings, GPU dispatchers) + `self/cuda/` (`.cu` kernels).

## Position in the stack

| Layer | What | Lives in | RFC |
|---|---|---|---|
| hexa stdlib (orchestration, compiler-only) | `flame` — Tensor / autograd / nn / optim / train | `stdlib/flame/` | RFC 043 |
| **forge — GPU compute substrate** | **device-farr alloc/copy/free · cuBLAS Dgemm · `.cu` kernels** | **`self/runtime.c` + `self/cuda/`** | **RFC 040 / 041** |
| Core farr primitive (CPU, unified) | farr mmap / matmul / reverse-mode autograd tape | `self/runtime.c` | RFC 025 / 032 / 033 / 034 |

Analogy (PyTorch): **flame:forge :: torch:ATen**. flame writes hexa; forge
writes C / CUDA. flame calls forge through compiled builtin dispatch
(`hexa_farr_matmul_gpu`, `hexa_cuda_*`, …) — never through `hexa_interp`.

## Why a name (and not just "RFC 040/041")

- Vocabulary parity with flame — symmetric SSOT pair (`FLAME.tape` ↔ `FORGE.tape`).
- Honest metaphor: **flame builds on forge** / forge powers flame. Reads in English & Korean cleanly.
- `f1` / `f2` safe — pure thermal lineage, **zero numerology / lattice claim** in the name.
- One label for the GPU layer simplifies cross-repo references (anima `state/` docs, HF model cards, upstream RFCs).

## What forge IS (concretely, today)

- `hexa_cuda_*` runtime functions (device alloc / copy / free / sync) — in `self/runtime.c`
- `hexa_farr_*_gpu` dispatchers — in `self/runtime.c`
- `self/cuda/runtime_cuda.c` — **cuBLAS Dgemm impl** (RFC 040, ✅ verified 4× across 2 H100 + 2 A100, 51.24 TFLOPS FP64 / 76 % H100 peak, max\|Δ\|=4.44e-15 vs CPU)
- `self/cuda/PHASE_D_H100_EVIDENCE.md` — original landing evidence
- **`hexa-lang/inbox/rfc_drafts_2026_05_12/rfc_040_*.md`** — design SSOT (device-farr + cuBLAS)
- **`hexa-lang/inbox/rfc_drafts_2026_05_12/rfc_041_*.md`** — real `.cu` kernel design (non-matmul)

## What forge is NOT

- ❌ Not a hexa-source stdlib (those go in `stdlib/`; forge is C / CUDA)
- ❌ Not a separate repo (toolchain ABI lockstep — `hexa-first` principle; CLAUDE.md "absorbed intrinsic over forking")
- ❌ Not a GPU codegen backend (hexa source → PTX would be a separate future RFC; out of forge scope)
- ❌ Not a name for the CPU farr primitive (that's core hexa, RFC 025/032/033/034 — flame uses it directly)

## Verified oracles (forge correctness floor)

| Oracle | Fact | Source |
|---|---|---|
| cuBLAS ≡ CPU | max\|Δ\|=4.44e-15; reduction-heavy TOL_MATMUL ≈ 2e-9 (RFC 040 fp-non-assoc) | RFC 040 / `self/cuda/PHASE_D_H100_EVIDENCE.md` |
| cuBLAS perf | 51.24 TFLOPS FP64 H100 (76 % peak) · 13,526 GF/s A100 · 4× indep verify | Phase D + A100 retry + runpod 4th verify |
| Phase B2 ops ≡ boxed | `tmp_rfc040_phaseB2_smoke.hexa` 9 / 9 (matmul_t, outer, mul, silu, silu_grad, rmsnorm_bwd, adamw on no-CUDA path) | branch `rfc040-phaseB2-complete` `017b988f` |

These are the references **any new forge kernel must reproduce** before landing (g_blue_closed_mandate).

## Performance thesis (honest — g1/g3/g4/f1/f2)

- **Floor**: raw dense GEMM = cuBLAS / NVIDIA roofline. forge **matches**, does NOT beat (the win is *above* GEMM, owned by flame fusion).
- **Forge wins** = (a) replacing `.cu` `TODO[cuda]` stubs with real elementwise / reduce kernels (RFC 041), (b) memory-traffic minimisation at the kernel boundary (fused epilogues for `flame` to dispatch into).
- **Forbidden**: NO n=6 lattice numerology in any perf assertion (`f1` / `f2` hard fail). Anchors = Shannon / memory-bandwidth / cuBLAS-measured roofline only.

## Cross-references (SSOT)

- Design SSOTs: RFC 040 (`inbox/.../rfc_040_*.md`) + RFC 041 (`inbox/.../rfc_041_*.md`)
- Companion stdlib: `stdlib/flame/README.md` · `stdlib/flame/FLAME.tape` §X (same campaign artifacts indexed from the stdlib angle)
- Roadmap: `self/forge/PLAN.md`
- Tape SSOT: `self/forge/FORGE.tape`
- Cross-repo evidence: `dancinlab/anima` `state/hexad_gpu_fire_*` + `docs/anima_rfc040_phase_*`
