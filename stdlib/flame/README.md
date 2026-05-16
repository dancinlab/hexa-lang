# flame — hexa-native, compiler-only PyTorch-equivalent NN stdlib

> **Status (2026-05-17): Phase 3 COMPLETE + RFC 046 Phase 4 design
> shipped — 22 commits, 41+ falsifier PASS, regression 0, structural
> call_builtin = 0, ~6.4k LoC.**
>
> **Phase 3 correctness anchor — anima d_corpus_fire algorithm-byte-eq
> retry SUCCESS** (RFC 045 closure):
> - same hexa-lang toolchain, same Mac host, same corpus, same seed=42
> - **flame** init gn2 = `7.97113` → final `8.87256e-07`, acc 8/8, wall 18.5s
> - **anima** init gn2 = `7.97116` → final `3.73374e-07`, acc 8/8, wall ~30s
> - |Δ_init| = 3.12e-5 abs (~4e-6 rel) · |Δ_final| = 5.14e-7 (2.4× drift,
>   same shape, same order of magnitude)
> - acc 8/8 = 8/8 exact match — qualitative reproduction perfect
> - source #4 CONFIRMED: anima dict/list-based vs flame packed-farr-based
>   impl → different SSA assignments + different last-ulp non-associative
>   fp sum sequences (RFC 040 §2.2 TOL_MATMUL class). Strict bit-eq across
>   the two impls is not achievable without unifying storage rep, which
>   would defeat flame's compiler-only perf substrate goal.
>
> **Stack**: `tensor_lib` + `autograd_lib` + `nn_lib` (7 layers:
> Linear · RMSNorm · Embedding · LMHead · RoPE · SwiGLU · Attention-core)
> + `optim_lib` + `decoder_block_lib` + `decoder_lib` + `train_lib` +
> `flame_math` (dt_* hand-Taylor + d5_sin/cos). All decoder_block_lib
> projections farr_matmul-routed (Phase 3-J, same FMA fusion context as
> anima).
>
> **Sub-piece byte-id verified with anima** (Phase 3-A..3-J):
> - corpus byte stream: `read_file_bytes` ≡ `od -An -v -tu1` (Phase 3-F-3)
> - LCG sequence: `dt_lcg_next` ≡ anima d_train_lib (Phase 3-E + 3-H)
> - weight init values: tok_emb[0..10] max|Δ|=0.0 (Phase 3-H direct)
> - RMSNorm: `dt_sqrt` ≡ anima 24-iter Newton (Phase 3-E)
> - softmax: `dt_exp` ≡ anima Taylor + repeated-square (Phase 3-E)
> - CE: `dt_ln` ≡ anima atanh 24-term (Phase 3-E)
> - RoPE: `d5_sin` / `d5_cos` ≡ anima 14-term Taylor (Phase 3-G)
> - AdamW: same `adamw_step` builtin (Phase 3-A)
>
> **GRAD-EXACT correctness anchors**:
> - block-level: 9-probe central-diff, max rel **3.59e-10** (Phase 3-B)
> - full-model: 10-probe central-diff, max rel **2.66e-08** (Phase 3-C;
>   covers head→tied→finalnorm→block-stack→RoPE→GQA→embed reverse)
> - closed math invariants: `Rᵀ · R = I` RoPE orthogonality (machine ε)
>   + `P[hh,i,j>i]=0` attention causal-mask (exact)
>
> **Next gates** (RFC 046, design-shipped):
> - Phase 4-A: epilogue fusion (~2× wall)
> - Phase 4-B: block fusion / IR pass (~5× wall)
> - Phase 4-C: fwd+bwd graph fusion (~10× wall)
> - Phase 4-D: GPU dispatch + eager-PyTorch comparison —
>   F-RFC046-EAGER-PYTORCH-MATCH falsifier: flame d=768·12L wall
>   ≤1.3× eager-PyTorch 336.85s on A100 (the measurable mid-term goal).
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

## Current layout (Phase 3 LANDED)

```
stdlib/flame/
  README.md                   overview + status (this file)
  PLAN.md                     staged roadmap
  FLAME.tape                  tape v1.2 SSOT: identity · governance · §X
  flame.hexa                  ✅ Phase 1 entrypoint + selftest
  tensor_lib.hexa             ✅ Phase 1 — Tensor over RFC 040 farr
  autograd_lib.hexa           ✅ Phase 1 — RFC 034 ad_* wrapper
  nn_lib.hexa                 ✅ Phase 2 — 7 layers (fwd/bwd, closed vjp)
  optim_lib.hexa              ✅ Phase 3-A — AdamW thin wrapper
  decoder_block_lib.hexa      ✅ Phase 3-B/J — block fwd/bwd, farr_matmul-routed
  decoder_lib.hexa            ✅ Phase 3-C — full ConsciousDecoderV2 fwd/grad
  train_lib.hexa              ✅ Phase 3-D — train_step + 80-step driver + init
  flame_math.hexa             ✅ Phase 3-E/G — dt_lcg/sqrt/exp/ln + d5_sin/cos
  flame_<phase>_test.hexa     selftests (Phase 1/2/3-{A,B,C,D,E,F-3,H,J})
```

flame public API is fixed per `g_flame_api_fixed` — Phase 4 changes
only the C emission pattern under the hood, not the user-facing surface.

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
- Phase 3 closure: `inbox/rfc_drafts_2026_05_12/rfc_045_flame_phase3_algorithmic_byte_eq_with_anima_oracle.md`
- Phase 4 design: `inbox/rfc_drafts_2026_05_12/rfc_046_flame_phase4_compiler_fusion.md`
- Backing RFCs: 040 (tensor/cuBLAS) · 041 (kernels) · 042 (subsumed) · 034 (autograd)
- Full preservation index + verified oracles: **`FLAME.tape` §X**
- Roadmap + Phase 0 consolidation: **`PLAN.md`**
- anima dual-track + §9: `dancinlab/anima HEXAD/PLAN.md` §9
- Substrate sibling (GPU): `self/forge/` — README + PLAN + FORGE.tape
  (flame consumes forge's `farr_*_gpu` / `cuda_*` compiled builtins;
  Phase 3 uses host CPU `farr_matmul` per honest carve-out — device
  routing is Phase 4-D after RFC 044/046 codegen wiring lands)
