# HEXA-0POD — log

## 2026-06-09 — OP-1 DONE: sm_120 own-GEMM 3.2-6.9x -> ~1.0-1.15x off cuBLAS, bit-exact (aiden RTX 5070)

Swept 5 kernel variants (K0 baseline .. K4 all-levers) on aiden (free pool, NO vast). Levers: (1) cp.async
double-buffer, (2) bank-conflict-free smem pad, (3) 128x64 register tile, (5) .v4 128-bit global loads. All
variants BIT-EXACT vs the K0 baseline (rel-RMS=0, bitdiff=0/N) and vs cuBLAS-TF32 (rel-RMS ~3e-5, gate PASS) at
D={1024,2048} — scheduling/layout-only, accumulation order preserved.

Results (TFLOP/s, GPU exclusivity verified): D=1024 K0 6.75 (4.16x off) -> K2 24.49 (1.15x off); D=2048 K0 8.05
(3.83x) -> K2 29.81 (1.02x — near parity). K2 = pad + .v4 + cp.async double-buffer = BEST bit-exact config.
Findings: layout/load-vectorization (K1) was the dominant lever (+3.1-3.4x — baseline had pathological bank
conflicts + scalar loads); cp.async a modest top-up (+0.08-0.15x); the 128x64 register tile (K3/K4) PLATEAUED/
regressed on the consumer card (occupancy loss > AI gain) and was NOT shipped (closed-negative).

Promoted K2 into the production self/native/mma_sm120/owngemm_sm120.cu (gemm_sm120) so flame's real sm_120
own-GEMM gets the speedup — re-verified: GATE @768 rel-RMS 1.33e-5 (== baseline, bit-faithful), PERF 24.48
@1024 / 29.81 @2048 TFLOP/s. Sweep harness owngemm_sm120_opt.cu + build_owngemm_opt.sh kept for reproduction.
Verdict .verdicts/hexa-0pod/F-OP1-SM120-OWNGEMM.txt. Deferred OP-1b (BK=32 / 3-stage pipeline / vectorized
epilogue) appended to self-feed the loop; register-tile lever marked closed-negative (do not re-attempt).

## 2026-06-09 — domain registered (0-pod free-resource improvement loop)

User goal: "0 pod 으로 flame+forge 개선 계속 진행 루프" + "pool 은 활용가능". Continuous flame+forge improvement
using ONLY free resources (sidecar pool aiden/summer RTX 5070 + local code), zero vast rentals. aiden confirmed
free (RTX 5070 sm_120, 0% util). Backlog OP-1..5 (sm_120 own-GEMM speedup · wire bench wins into real trainer ·
BF16 own-GEMM · fused-step coverage · forge hardening). Hopper-only own-GEMM decode-elim is out-of-scope (needs
H100 pod). Loop fans out free-resource agents per round, byte-eq/bit-exact gated on the consumer card.

## 2026-06-09 — OP-2 — wire bench step wins into the REAL flame CLMConvMoE trainer 🟢

Audited the 4 HEXA-BENCH step wins against the real trainer (stdlib/flame/clm_prod.hexa + the forge device
runtime self/cuda/runtime_cuda_emit.hexa). Finding: 3 of 4 are ALREADY in the product, env-gated, from the
HEXA-FUSION campaign — cuBLAS-FP64 projection GEMM is the DEFAULT _hx_cuda_farr_matmul_gpu path (HEXA_OWN_GEMM
only swaps the naive kernel IN); fused valley LN+gelu(+resid) under HEXA_FUSE_VALLEY/GN_GELU(_RESID) →
_hx_k_groupnorm_gelu[_residual]; single-launch fused AdamW under HEXA_CLM_FULLSTEP → _hx_k_adamw_fused
cooperative. The bench's "flame FP64 = naive O(D^3)" refers to the HEXA_OWN_GEMM kernel, not the default trainer.

The one MISSING win = BENCH-10 TRANSPOSE-ELIMINATION for the backward dW GEMM. conv1d_bwd_via_forge ran a
SEPARATE transpose-layout im2col pass (_clmp_im2col_t → xcolT[Kdim,T]) then an OP_N GEMM; the bench computes
dW = A^T@dGq via cuBLAS OP_T on A directly (no materialized A^T). Wired it: new forge_dispatch_matmul_t(A,M,K,
B,N) = A^T@B builtin — GPU side _hx_cuda_farr_matmul_tn_gpu (cublasDgemm CUBLAS_OP_T, + _hx_k_gemm_t own
fallback) in runtime_cuda_emit.hexa (emit verified, no symbol collision w/ the RFC-040 M^T·u gemv, brace-
balanced); codegen call-name mapping + runtime.h protos. The trainer's conv1d_bwd_via_forge documents the
3-line swap (im2col + matmul_t, drops the im2col_t pass) as a COMMENT — NOT a live call — so the build stays
unbroken until the runtime.c wrapper body lands at GPU-build time.

GATE (g5) byte-eq HELD: clm_prod_transpose_elim_eq.hexa CPU oracle proves im2col+matmul_t dW ==
im2col_t+matmul dW max|Δ|=0 across 4 (T,Cin,Cout,K,dil) cases via `hexa run` (0-pod, mac/aiden CPU — the
same dispatch path, no GPU build needed). Bit-exact because xcolT[j,t]==xcol[t,j] and the contraction runs
over the same t-dim in the same ascending order. GPU cuBLAS OP_T is the documented ~1e-14 accum-order lane.

Deferred (GPU build, NOT vast): OP-2b runtime.c wrapper body + flip trainer to live call + step/s measure;
OP-2c batched-expert transpose-elim (cublasDgemmStridedBatched OP_T) for the dominant 2-expert path. Verdict
.verdicts/hexa-0pod/F-OP2-TRAINER-WIRE.txt.

## 2026-06-09 — OP-5 forge/runtime hygiene (LOCAL, 0-GPU)

Fixed the diagnostic-surfaced `self/runtime.h:422-423` `'/*' within block comment` `-Wcomment` warning: the
`native/*.c` glob written inside a `/* … */` block forms a nested `/*` token clang flags. Minimal comment-only
fix (`native/ *.c`, +2/-2) — `clang -fsyntax-only -Wcomment -x c self/runtime.h` 2 warnings → 0. No
declaration / codegen / behavior change. Repo-wide `-Wcomment` + `-Wextra-tokens` sweep over every checked-in
C/H/CU/CUH header, the forge-emitted CUDA wrappers (self/cuda/*.cu|*.c), and the emit-string `.hexa` sources
(runtime_cuda_emit / runtime_bf16_emit / forge_tier_v1_emit) confirmed runtime.h:422-423 was the ONLY genuine
hit (one `#pragma once in main file` artifact from standalone header parse correctly ignored, not "fixed").
All behavior-preserving. Verdict .verdicts/hexa-0pod/F-OP5-FORGE-HARDEN.txt. Deferred OP-5b (CI -Werror=comment
gate, 0-GPU) + OP-5c (error-path/dtype/determinism hardening — NEEDS GPU, out of 0-pod scope) to self-feed.

## 2026-06-09 — OP-3 BF16 sm_120 own-GEMM (aiden RTX 5070, free pool)

Extended the OP-1 (#2972) TF32 sm_120 own-GEMM to BF16 in self/native/mma_sm120/owngemm_sm120_bf16.cu using
the portable warp-mma `mma.sync.aligned.m16n8k16.row.col.f32.bf16.bf16.f32` — note BF16 is k16 (NOT k8 like
TF32), the 16x8x16 fragment packs two bf16 per 32-bit register (A=4 regs/8 bf16, B=2 regs/4 bf16). fp32 inputs
RN-converted to bf16 (__float2bfloat16_rn) at the smem→register fragment load (where TF32's f2tf32 lived);
fp32 accumulation. Carried over OP-1's THREE layout/load wins VERBATIM — (a) bank-conflict-free smem pad
As[BM][BK+4]/Bs[BK][BN+4], (b) .v4 128-bit float4 global loads (masked scalar tail), (c) cp.async double-
buffered BK stage — and kept the IDENTICAL K-major mma.sync accumulation order (so the kernel is its own
bit-for-bit reproducer). Did NOT touch the 128x64 register-tile lever (CLOSED-NEG on the consumer card, OP-1).

Built clean on aiden (CUDA 13.0, sm_120). GPU verified free (0% / 2 MiB) before every timed run.
GATE (g5 bit-FAITHFUL, W14 convention — NOT bit-exact-vs-fp32; BF16 8-bit mantissa): rel-RMS vs FP64 ref
8.4e-3@256 / 2.7e-3@768 / 6.7e-3@1024 / 8.0e-3@2048, all ≤1e-2 PASS (sits at the BF16 precision floor →
fragment layout is correct; a wrong m16n8k16 map would give rel-RMS ~0.5-1.0). Determinism: run-to-run
max|delta|=0, bitdiff=0/N @1024 and @2048 HELD.
PERF (2 timed passes): own-GEMM-BF16 26.1-26.5 TFLOP/s @1024, 33.3 @2048; cuBLAS-BF16 54.7 @1024, 61.5-66.7
@2048 → cuBLAS-multiple ~2.0-2.1x @1024, ~1.85-2.0x @2048.

HONEST (g5): the multiple is WIDER than the TF32 path's ~1.0-1.15x EXACTLY as predicted — BF16 ~doubles the
cuBLAS roofline (cuBLAS-BF16 ~55-67 vs cuBLAS-TF32 ~28-31 TFLOP/s). The own-GEMM's ABSOLUTE throughput is
actually HIGHER in BF16 (26-33) than TF32 (24-30 @ OP-1), but cuBLAS scales up faster, so the ratio opens to
~2x. The win = a working bit-faithful BF16 own-GEMM on the consumer card riding OP-1's layout lever; NOT
cuBLAS-BF16 parity (cuBLAS uses f16-class tensor-core scheduling the portable warp-mma doesn't). Verdict
.verdicts/hexa-0pod/F-OP3-BF16-SM120.txt. Deferred OP-3b (BK=32 / 3-stage cp.async / .v2-.v4 epilogue for the
BF16 path, mirroring OP-1b — NOT the register tile) to self-feed.
