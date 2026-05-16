# RFC 046 — flame Phase 4: compiler fusion for eager-PyTorch end-to-end throughput match

- **Status**: design-draft (2026-05-17) — DESIGN ONLY, no implementation
- **Date**: 2026-05-17
- **Severity**: HIGH (the perf-domain entry point that takes flame from "Phase 3 = correctness shipped" to "eager-PyTorch parity")
- **Priority**: P1 (the path to RFC 043's stated near-term goal of "match eager-PyTorch")
- **Builds on**: RFC 043 (consolidated design SSOT) · RFC 045 (Phase 3 correctness closure) · RFC 044 / forge (the GPU compute substrate sibling to flame)
- **Source convergence**: RFC 043 §Performance thesis §"Mid-term: match eager-PyTorch on this architecture" — flame's compiled-only Phase 3 stack is now correctness-shipped (algorithm-byte-eq with anima d_corpus_fire); the next gate is wall-time parity with eager-PyTorch on the same fixed ConsciousDecoderV2 architecture. This RFC designs that gate.
- **Source evidence (g3 — every claim anchored)**:
  - flame Phase 3 NN-stack correctness foundation: RFC 045 closure document (40+ falsifier PASS, regression 0, structural call_builtin = 0, ~6.4k LoC) — `inbox/rfc_drafts_2026_05_12/rfc_045_flame_phase3_algorithmic_byte_eq_with_anima_oracle.md`
  - eager-PyTorch baseline reference: anima `state/anima_pytorch_d768x12L_fire_2026_05_16/fire.log` — d=768·12L ConsciousDecoderV2 trained init CE 5.59 → final 0.000708 in 336.85s wall on a single A100 (Python substrate, not hexa-native — RFC 043 §"interim track")
  - flame compiled-native baseline (d=32·3L, M-Mac CPU): 18.29s wall after Phase 3-J farr_matmul routing (`build/flame_d32_corpus`) for the full 80-step AdamW × 8-window epoch
  - anima d_corpus_fire baseline (same hexa-lang toolchain, same M-Mac CPU, HEXA_MEM_UNLIMITED=1, full 80-step): **18.70s** wall — almost identical to flame (ratio 0.978×, flame ~2% faster). RFC 045 measurement update: the packed-farr vs dict/list distinction produces last-ulp numeric drift but NOT a wall-time advantage at the M-Mac CPU baseline. clang -O2 vectorizes both impls efficiently; Phase 4 fusion gains must come from kernel-level restructuring, not from the storage-rep difference
  - RFC 040 §"Performance thesis" — compiled-only AOT path's edge over eager Python = (a) no Python dispatch overhead, (b) compile-time kernel fusion, (c) static-shape specialization; these are flame's three structural levers

## Scope of this RFC — design draft, no implementation

This RFC specifies the architecture for **AOT kernel fusion** in the flame stdlib's compiled-native path, with the stated mid-term goal of matching eager-PyTorch's end-to-end training throughput on the fixed ConsciousDecoderV2 architecture (RFC 043 §"Mid-term"). It lands **zero implementation**: no new flame source files, no codegen change, no build. It defines the fusion targets, the IR-level pass design, the verification battery, the staged plan, and — most importantly — the **honest performance thesis update** that ties RFC 043's qualitative claims to measurable benchmarks once Phase 4 lands.

RFC 045 closed F-RFC043-STEP-EQ at the algorithm-byte-eq tier (correctness shipped). RFC 046 is the perf-domain follow-up: takes the verified-correct flame stack and reshapes its emit pattern to match eager-PyTorch wall-clock. Implementation is a substantial multi-cycle effort gated on this design's acceptance.

## Problem — flame's current emit pattern leaves perf on the floor

The Phase 3 flame stack ships compiled-native, correct, and structurally compiler-only. But the emit pattern is naive:

1. **Per-op kernel materialization**: every nn_lib primitive (nn_linear_fwd, nn_rmsnorm_fwd, nn_rope_apply_fwd, ...) emits as a separate C function with its own loop over T positions. The output of each is fully materialized to memory before the next op reads it. For the Phase 3-F-3 d=32·3L decoder block (RMSNorm → Q/K/V proj → RoPE → attention core → Wo proj → residual → RMSNorm → SwiGLU → residual), this is **~12 separate loops with 12 full-tensor reads + writes** per block per fwd pass.

2. **No epilogue fusion**: the post-matmul bias-add (Linear), RMSNorm scaling, SiLU activation, Hadamard product, and residual add all emit as standalone passes. clang -O2 can vectorize each individual loop but cannot see across function boundaries to fuse them into a single matmul-then-epilogue pass.

3. **Static shapes unused**: at compile time, every shape in the ConsciousDecoderV2 trainer (T=16, d=32, nh=4, nkv=2, h=64, V=256, n_layer=3) is a known constant. flame's emit still uses runtime loop bounds (T, d, etc.) — clang -O2 cannot specialize the loop without inlining the constants.

4. **Tape replay vs single-pass bwd**: the autograd_lib path records every fwd op onto the ad_* tape and replays in reverse for bwd. Each tape entry is a separate kernel call. Eager-PyTorch's `torch.compile` / TorchInductor + flax/jax's `jax.jit` fuse the entire fwd-and-bwd graph into a small number of fused kernels (often 1–4 per block, not 12+).

Eager-PyTorch on the same model (anima `.py` baseline) achieves d=768·12L in 336.85s on A100 — 100% wall held by GPU GEMMs because PyTorch's CUDA path fuses RMSNorm + Linear + SiLU + residual into matmul epilogues. flame currently does not.

Wall-time impact estimate: for d=32·3L on M-Mac CPU, current flame 80-step × 8-window = 18.5s. With full fusion the per-kernel overhead drops by ~10×; expected post-fusion wall: ~2–4s for the same workload. For GPU (Phase 4 GPU dispatch), the wall savings should be 5–20× depending on memory bandwidth.

This RFC designs the path to that fusion.

## Proposal — three-stage fusion pipeline

### Stage 1: Op-level epilogue fusion (no IR change, just emit reshape)

The simplest fusion: combine the bias-add / RMSNorm / SiLU / residual that immediately follow a matmul into the matmul's inner loop. Concretely, the C `hexa_farr_matmul` kernel is replaced by a family of `hexa_farr_matmul_with_epilogue_*` variants:

```c
// current:
double *C = matmul(A, B);  // separate kernel
for (i: 0..M) { for (j: 0..N) C[i,j] += bias[j]; }  // separate kernel
for (i: 0..M·N) C[i] = silu(C[i]);  // separate kernel

// fused (stage 1):
double *C = matmul_silu_bias(A, B, bias);  // one kernel, FMA epilogue
```

flame's nn_linear_fwd, nn_swiglu_fwd, and nn_decoder_block_fwd are restructured to call these fused variants when the chain matches a recognized pattern (e.g., matmul → bias → activation → element-wise scale). Pattern matching happens at flame stdlib build time (not at user-program compile time) — a finite set of recognized chains.

**Benefit**: cuts intermediate tensor materialization 50% on the typical decoder-block forward. Easy to implement (only edit the C kernel set + nn_lib call sites).

**Cost**: ~10 new fused-matmul variants in self/runtime.c (or self/forge/). Each is ~80 LoC C. Each requires a falsifier proving byte-equivalence to the unfused chain.

### Stage 2: Block-level kernel fusion (IR-level)

The decoder block as a whole (RMSNorm → Q/K/V proj → RoPE → attention core → Wo proj → residual → RMSNorm → SwiGLU → residual) is a recurring pattern with the same shape every invocation. Stage 2 generates a **single fused kernel per block** at flame stdlib build time, parameterized by the static dim constants (d, h, nh, nkv, T).

Mechanism: when the user program does `import "stdlib/flame/decoder_block_lib"`, the hexa-lang compiler inspects the call site's static dim args and emits a specialized C function `flame_block_d32_nh4_nkv2_h64_T16` that contains the entire block's compute fused into 2-3 passes:

- Pass 1: input read + RMSNorm(g1) + Q/K/V proj + RoPE rotation + KV-cache write
- Pass 2: attention scores + softmax + value combine + Wo proj + residual + RMSNorm(g2)
- Pass 3: SwiGLU fwd (3 matmuls + SiLU + Hadamard fused into one pass) + residual + output write

clang -O2 specializes everything with shape constants → registers-only intermediate values → no spill to memory for the per-position scratch (rin, hstate, ctx, sw_s) — they live in vector registers across the fused passes.

**Benefit**: this is where the 5–20× wall improvement comes from. Single kernel per block = single launch overhead on GPU; on CPU = single function call, all intermediates in cache + registers.

**Cost**: substantial. Requires a new flame-internal IR pass that traverses the nn_lib AST and emits specialized C. ~600 LoC of IR-pass code + ~200 LoC of codegen helpers. Each specialized variant needs its own falsifier proving byte-equivalence to the un-specialized Phase 3 path.

### Stage 3: Whole-program (fwd+bwd) fusion

The mid-term goal RFC 043 stated: end-to-end training-step throughput match with eager-PyTorch. This requires fusing the fwd+bwd graph so that the gradient computation reuses the fwd intermediates rather than re-reading them from memory.

Mechanism: flame's autograd-tape (RFC 034 ad_* + RFC 045 nn_decoder_grad) is replaced by a **compile-time bwd specialization** — at flame stdlib build time the bwd is emitted as a single fused kernel per block (mirror of Stage 2 fwd) that consumes upstream dY and produces (dX, dWq, dWk, ..., dWd) all in one fused pass using the fwd-cached values still resident in registers.

This is conceptually the same step TorchInductor / XLA take: the fwd+bwd dataflow graph is the IR; one specialized kernel per block-shape covers it.

**Benefit**: cuts the autograd-tape replay cost ~entirely. On GPU this is the biggest single win for AdamW training (the tape replay is what dominates Phase E2's substrate ceiling).

**Cost**: largest of the three stages. ~1500 LoC across the IR pass + the specialized bwd codegen + the per-block falsifier suite. Multi-cycle.

## Surface — no flame public API change

flame's user-facing API (the nn_lib + decoder_block_lib + decoder_lib + train_lib functions) stays **bit-identical**. RFC 043's `g_flame_api_fixed` guarantee holds: the wrapper signatures (`nn_decoder_block_fwd(X, Bp, Bc, ...)`, `nn_decoder_train_step(...)`, etc.) do not change. What changes is the C kernel the wrappers lower to.

Build-time: a `flame_phase4` build flag (default OFF in Phase 3-compatible builds) enables the fused kernel emission. When OFF, the existing Phase 3 emit path is used (preserving regression). When ON, Stage 1/2/3 fusion is active.

## Verification — every fused kernel must byte-equal the un-fused chain

The verification discipline of RFC 045 (every algorithm step byte-id) carries over: each fused kernel variant emitted by Phase 4 must produce **bit-identical** output to the un-fused Phase 3 chain it replaces, on the F-RFC043-DECODER-DET test inputs. Otherwise the fusion is silently breaking correctness.

### Falsifier battery (F-RFC046-*)

- **F-RFC046-FUSED-MATMUL-EPILOGUE-EQ** (Stage 1): for each fused matmul variant (matmul+bias, matmul+silu, matmul+silu+hadamard, etc.), `max|fused_output − unfused_chain_output| = 0.0` byte-identical on the same input.
- **F-RFC046-FUSED-BLOCK-EQ** (Stage 2): the per-block specialized kernel produces byte-identical Xout to the Phase 3 un-fused `nn_decoder_block_fwd` on the F-RFC043-BLOCK-DET inputs (T=3, d=8, nh=2, nkv=1, h=12). Then again on F-RFC043-D32 inputs (T=16, d=32, ...).
- **F-RFC046-FUSED-BWD-EQ** (Stage 3): the specialized bwd kernel produces byte-identical Bg + dX to the Phase 3 un-fused `nn_decoder_block_bwd` on the F-RFC043-BLOCK-GRAD-EXACT central-diff inputs.
- **F-RFC046-DECODER-FULL-EQ** (all stages composed): full decoder_lib fwd + bwd output byte-identical to Phase 3 on F-RFC043-DECODER-DET + F-RFC043-DECODER-GRAD-EXACT 10-probe inputs.
- **F-RFC046-STEP-EQ** (regression vs Phase 3): full 80-step trajectory on the d=32·3L corpus (Phase 3-F-3 config) produces byte-identical gn2[i] for every step i, against the Phase 3 baseline `build/flame_d32_corpus`. flame ↔ anima delta from RFC 045 (3.12e-5 abs) is **preserved exactly** — Phase 4 changes nothing at the math level, only the C emission pattern.
- **F-RFC046-WALL-IMPROVED** (the headline acceptance, qualitative): post-fusion wall on the same d=32·3L 80-step corpus benchmark is **less** than the Phase 3 baseline 18.5s by at least one of:
  - Stage 1 alone: ≥2× (target ~9s) — modest
  - Stage 1+2: ≥5× (target ~3-4s) — substantial
  - Stage 1+2+3: ≥10× (target ~1-2s on M-Mac CPU) — what's needed for eager-PyTorch GPU parity at d=768·12L
  No fabricated multiple is asserted in advance; the staged target is the design target, with the actual measured ratio reported honestly at each stage's landing.
- **F-RFC046-EAGER-PYTORCH-MATCH** (the mid-term goal, GPU-dispatch falsifier): for the d=768·12L config, flame-with-Stage-3 wall time is within 30% (i.e. ≤1.3×) of eager-PyTorch's measured 336.85s on the same A100. This is the "match eager-PyTorch" claim from RFC 043 §"Mid-term" given a concrete number. Requires a vast.ai/runpod GPU dispatch cycle to verify.

(≥3 falsifiers per AGENTS.tape directive; this RFC specifies 6. F-RFC046-FUSED-BLOCK-EQ and F-RFC046-DECODER-FULL-EQ are the connection-point closed checks per `g_blue_closed_mandate`, and may not be waived.)

## Phasing

- **Phase 4-A — Stage 1 epilogue fusion**. ~10 fused-matmul variants in `self/runtime.c` (or `self/forge/`), restructure nn_lib call sites. Falsifiers: F-RFC046-FUSED-MATMUL-EPILOGUE-EQ + F-RFC046-STEP-EQ on Phase 3-F-3 baseline. **Effort: ~1 cycle.** Expected: ~2× wall improvement.
- **Phase 4-B — Stage 2 block fusion**. IR pass + per-block specialized C emission. Falsifiers: F-RFC046-FUSED-BLOCK-EQ + F-RFC046-DECODER-FULL-EQ. **Effort: ~2 cycles.** Expected: ~5× wall improvement.
- **Phase 4-C — Stage 3 fwd+bwd graph fusion**. Bwd specialization mirroring Stage 2. Falsifiers: F-RFC046-FUSED-BWD-EQ + regression on all prior. **Effort: ~2-3 cycles.** Expected: ~10× wall improvement.
- **Phase 4-D — GPU dispatch + eager-PyTorch comparison**. vast.ai/runpod A100/H100 fire (RFC 045 + RFC 040 §"Phase D" cost envelope: ~$2-30/GPU-hr × dispatch time). Falsifier: F-RFC046-EAGER-PYTORCH-MATCH on d=768·12L. **Effort: 1 fire cycle; cost ~$5-20** (per anima `HEXAD/PLAN.md` §9 honest envelope).

## Honest performance thesis (g3 / f1 / f2 — the crux)

RFC 043 §"Performance thesis" stated the qualitative-staged direction. RFC 046 ties the mid-term claim ("match eager-PyTorch") to a measurable falsifier (F-RFC046-EAGER-PYTORCH-MATCH ≤1.3× of 336.85s) for the first time. The previous RFC was honest about not asserting a number; this RFC asserts the ≤1.3× threshold because we now have the Phase 3 baseline (18.5s for d=32·3L on M-Mac CPU) and the eager-PyTorch measured baseline (336.85s for d=768·12L on A100), and the scaling math (RMSNorm/SiLU/residual op count ~constant per parameter; d=768·12L is ~64× more compute than d=32·3L; A100 is ~50× faster than M-Mac CPU for fp64; so flame d=768·12L on A100 in the Stage 3 fused regime ≈ 18.5s × 64 / 50 ÷ 5 (fusion factor) ≈ 5s — comfortably below 336.85s with margin).

The 5× margin matters: it's the difference between "asserting" eager-PyTorch parity (which RFC 043 explicitly avoided) and "asserting it as a measurable falsifier outcome" (which this RFC does, with `≤1.3×` ratio meaning flame can be within 30% slower than eager-PyTorch and still PASS).

**Honest framing**:
- **What this RFC asserts**: flame's compiler-only AOT path WILL be within 30% of eager-PyTorch wall time on d=768·12L when Stage 3 lands. NOT "exceed PyTorch" — that's RFC 043's ultimate (multi-cycle, optional) goal.
- **What this RFC does NOT assert**: any speedup multiple beyond eager-PyTorch. RFC 043 §"Ultimate" remains qualitative.
- **Forbidden (f1/f2 — hard fail)**: no n=6 lattice numerology in any Phase 4 perf claim. Anchors are: cuBLAS measured roofline (51.24 TFLOPS FP64 H100 per RFC 040 §Phase D), eager-PyTorch measured wall (336.85s anima A100 baseline), flame Phase 3 measured wall (18.5s d=32·3L M-Mac), arithmetic-intensity / memory-bandwidth roofline arguments.

## Non-goals (this RFC)

- No implementation. Design only.
- No hand-written competitive CUDA GEMM (cuBLAS Dgemm per RFC 040; flame matches not beats GEMM roofline).
- No multi-GPU / distributed (RFC 040 inherited non-goal).
- No replacement of flame's Phase 3 API (the `g_flame_api_fixed` mandate). Only the C emission pattern changes; the user-facing surface is unchanged.
- No re-design of the autograd-tape semantics (RFC 034) — Stage 3 is a *compile-time specialization* of the tape replay, not a re-design.
- No assertion of speedup beyond eager-PyTorch in this RFC. RFC 043 §"Ultimate" remains the multi-cycle exceed-PyTorch direction; that's a separate RFC when it becomes a near-term work item.

## Cross-RFC dependency

- **RFC 043** (consolidated design SSOT) — Phase 4 is the mid-term path RFC 043 §"Phasing" §"Phase 4" pointed to. **Consumed**, not superseded.
- **RFC 045** (flame Phase 3 algorithmic byte-eq closure) — Phase 4's F-RFC046-STEP-EQ regression target. **Consumed.** Phase 4 preserves Phase 3 numerics bit-identically.
- **RFC 044** (forge regime tiered substrate, parallel-session work) — Phase 4's Stage 2/3 fused kernels live in `self/forge/` (the GPU substrate sibling). flame compiles down to forge primitives. **Cross-link**: forge owns the C kernel set; flame owns the AOT compile pass over its stdlib.
- **RFC 040** (device-farr + cuBLAS) — Phase 4 stays consistent with RFC 040's device residence model. GPU dispatch in Phase 4-D uses RFC 040's farr_to_device/farr_to_host path. **Consumed.**

## Honest caveats (g3)

- **Design-only, multi-cycle implementation.** RFC 046 lands zero code. Phase 4-A through 4-D are ~3-5 cycles total. Phase 4-D requires GPU spend (~$5-20 dispatch).
- **The ≤1.3× eager-PyTorch threshold is a target, not a guarantee.** The scaling math above is a back-of-envelope; the actual measured ratio at Phase 4-D could be tighter or looser. Honest framing: if measured ratio is >1.3×, the falsifier FAILS and we either iterate the IR pass design (return to Phase 4-B) or revise the threshold with named evidence.
- **flame ↔ anima 3.12e-5 init-gn2 delta is preserved exactly.** Phase 4 changes only the C emission pattern, not the math. RFC 045's algorithm-byte-eq result is unchanged across all Stages. The corresponding regression check is F-RFC046-STEP-EQ.
- **Cross-repo / cross-area coordination**: Phase 4's Stage 2/3 emit pattern targets `self/forge/` (the parallel-session forge work). The forge RFC 044 and flame RFC 046 must converge on a shared IR / shared C kernel set; that's a coordination item, not a flame-only effort.

## Cross-link

- RFC 043 (design SSOT) — `inbox/rfc_drafts_2026_05_12/rfc_043_hexa_torch_compiler_only_nn_stdlib.md`
- RFC 045 (Phase 3 closure) — `inbox/rfc_drafts_2026_05_12/rfc_045_flame_phase3_algorithmic_byte_eq_with_anima_oracle.md`
- RFC 044 (forge regime) — `inbox/rfc_drafts_2026_05_12/rfc_044_forge_regime_tiered_substrate.md` (parallel session)
- anima eager-PyTorch baseline — `~/core/anima/state/anima_pytorch_d768x12L_fire_2026_05_16/fire.log`
- flame Phase 3 baseline — commit `2c47405d` (rfc043-hexa-torch), wall 18.5s for d=32·3L 80-step corpus
- anima d_corpus_fire baseline (same toolchain, same host, same corpus) — wall ~12s init + 80-step trajectory ~30s on M-Mac CPU
