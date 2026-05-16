# flame — hexa-native, compiler-only PyTorch-equivalent NN stdlib

> **Status: Phase 1/2/3 + 3-E/F/F-2/F-3 LANDED (2026-05-17) — 40
> falsifier PASS on compiled-native. anima d_corpus_fire byte-eq
> retry SUCCESS: flame init gn2 = 7.97113 vs anima 7.97116 (|Δ|
> 3.12e-5, ~4e-6 rel) · acc 8/8 = anima 8/8 · final gn2 8.87e-7 (same
> order as anima 3.73e-7) · collapse 8.98e6× ≈ anima 2.13e7× · 30.5s
> wall, M-Mac CPU. Algorithm-byte-eq foundation confirmed at every
> stage: same byte stream (read_file_bytes ≡ od -An -v -tu1), same
> windowing, same weight init (dt_lcg + dt_rand_unit), same RMSNorm /
> softmax / CE numerics (dt_sqrt + dt_exp + dt_ln). Only delta source
> = RoPE cos/sin (libm vs anima d5_sin/cos 14-term Taylor) last-ulp
> propagation. Stack: `tensor_lib` + `autograd_lib` + `nn_lib` (7
> layers) + `optim_lib` + `decoder_block_lib` + `decoder_lib` +
> `train_lib` + `flame_math`. Structural call_builtin = 0 sustained.**
>
> Optional Phase 3-G: d5_sin/cos 14-term Taylor → strict bit-eq.
> Phase 4 = compiler fusion. Phase 5 = whole-program fusion +
> d=768·12L GPU fire.
>
> **Pair**: `flame` (this directory — hexa NN stdlib) ↔ `self/forge/`
> (the GPU compute substrate: cuBLAS + .cu kernels). See AGENTS.tape §0
> `nn_stack`. Analog: `flame:forge :: torch:ATen`. The
> language-separation (hexa source vs C/CUDA runtime) is enforced by
> directory.

`flame` is to hexa-lang what `torch` is to Python: a cohesive
**Tensor + autograd + nn + optim + GPU** stack — but **compiler-only**
(`hexa build` native, ZERO `hexa_interp` dispatch; aligns with the
interpreter-deprecation directive).

| torch (PyTorch) | flame (hexa-native) | foundation already built |
|---|---|---|
| `Tensor` (GPU array) | `flame` Tensor | RFC 040 device-farr + cuBLAS (✅ verified) |
| `autograd` | reverse-mode tape | RFC 034 (✅ landed) → generalized |
| `nn` (layers) | nn layers | ConsciousDecoderV2 (anima HEXAD, 🔵) + d_train5 farr-refactor (✅ Phase E/E2) |
| `optim` | AdamW | RFC 040 B2 `farr_adamw` (✅ scaffold) |
| CUDA backend | cuBLAS Dgemm | RFC 040 (✅ 4× independent GPU verify, 51 TFLOPS) |

## Why this exists / what it preserves

The Phase D→E→E2 campaign **proved** the GPU substrate works and the
verified ConsciousDecoderV2 trainer is bit-equal correct, but the
pure-hexa interpreter cannot run LM-scale training to convergence
(named real limit, g3). `flame` = the structural answer: **fat native
stdlib + thin hexa orchestration**, so there is no heavy interpreted
driver loop. Interim, the same verified architecture trains via the
`.py` track (PyTorch) — see PLAN.md §dual-track.

**All campaign work is preserved as references in `FLAME.tape` §X**
(exact branch · commit SHA · path · RFC#). Nothing relies on memory;
nothing is duplicated (drift-avoidance, g3). The single biggest
preservation risk — 5 scattered hexa-lang branches holding the real
cuBLAS impl + 11 farr ops — is addressed as **PLAN.md Phase 0
(branch consolidation), explicitly the 물거품-방지 step**.

## Planned layout (compiled-first lib-split — NOT one file)

A torch-scale lib cannot be one file; hexa-lang's compiled pattern
(`<x>_lib.hexa` pure-fns + `<x>.hexa` entrypoint) requires the split.
One cohesive import surface (`import flame`), internally:

```
stdlib/flame/
  README.md          ← (this) overview + foundation
  PLAN.md            ← staged roadmap (Phase 0 preserve/consolidate → 1..5)
  FLAME.tape         ← tape v1.2 SSOT: identity · governance · §X reference index
  flame.hexa         ← [planned] entrypoint (import *_lib + selftest)
  tensor_lib.hexa    ← [planned] Tensor (device-farr, RFC 040)
  autograd_lib.hexa  ← [planned] reverse-mode tape (RFC 034 generalized)
  nn_lib.hexa        ← [planned] Linear/RMSNorm/RoPE/GQA-attn/SwiGLU/embed/tied-head
  optim_lib.hexa     ← [planned] AdamW
  train_lib.hexa     ← [planned] compiled train_step + CE loss
```
`[planned]` = NOT created (design-only; impl after RFC 043 + Phase 0).

## API stays fixed; implementation matures (the staging answer)

One designed API surface (RFC 043). The "PyTorch-parity → exceed-PyTorch"
progression is **implementation maturity of the same API**, not new
files — exactly how PyTorch evolved (eager → Inductor under one API).
See PLAN.md phases.

## Performance thesis (honest — g1/g3/g4/f1/f2)

- **North-star (ULTIMATE, multi-cycle, NOT a near-term/measured claim)**:
  exceed eager-PyTorch (and torch.compile in specialized regimes) on
  END-TO-END training throughput for the fixed verified architecture.
- **Real mechanism**: whole-program AOT compilation (no interpreter /
  Python-dispatch / GIL) · compile-time kernel fusion (transformer
  bottleneck = memory bandwidth, not FLOPs) · static-shape specialization.
- **Honest floor**: raw dense GEMM = cuBLAS/NVIDIA roofline — flame
  MATCHES, does NOT beat (the win is *above* GEMM). Anchored to the
  campaign's measured 51.24 TFLOPS FP64 (76% H100 peak).
- **Forbidden (f1/f2, hard fail)**: NO n=6 lattice numerology in any
  performance assertion. Perf anchors = Shannon / memory-bandwidth /
  cuBLAS-measured roofline only.

## Cross-references (SSOT)

- Design SSOT: `inbox/rfc_drafts_2026_05_12/rfc_043_hexa_torch_compiler_only_nn_stdlib.md`
- Backing RFCs: 040 (tensor/cuBLAS) · 041 (kernels) · 042 (subsumed) · 034 (autograd)
- Full preservation index + verified oracles: **`FLAME.tape` §X**
- Roadmap + Phase 0 consolidation: **`PLAN.md`**
- anima dual-track + §9: `dancinlab/anima HEXAD/PLAN.md` §9
- Substrate sibling (GPU): `self/forge/` — README + PLAN + FORGE.tape
  (flame consumes forge's `farr_*_gpu` / `cuda_*` compiled builtins;
  Phase 1 uses host CPU `farr_matmul` per honest carve-out — device
  routing is Phase 4 after RFC 041/042 codegen wiring lands)
