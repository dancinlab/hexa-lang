# HEXA-0POD — log

## 2026-06-09 — OP-4 DONE: flame fused-step 5070 win/lose map — LOSES everywhere, near-parity only in FP64

Swept the flame BENCH-10 FUSED training step (flame_bench_step_fused.cu -DFUSED, cuBLAS lane = the speed lane:
fused valley LN+gelu+copy + single-launch AdamW + transpose-elim) vs torch eager+compile across
D={768,1536,2048} x B={1,8} x dtype={FP64,TF32,BF16} = 18 cells on aiden RTX 5070 (sm_120, 12GB), free pool,
NO vast. T=256, ITERS=50, exclusive-GPU guard (util<5% & mem<800MiB; it fired several times as parallel
OP-2/OP-3 agents hit the card and correctly held each timed run).

HONEST consumer-card frontier: flame LOSES to torch.compile in ALL 18 cells — there is NO crossover-D where
flame wins on the 5070. Ratio (flame_ms / torch_compile_ms) by regime: TF32 1.78x->8.96x (widens with D at
B=1; ~2.8x flat at B=8). BF16 WORST, up to 14.66x @D=2048/B=1 (torch inductor + cuBLASLt BF16 on small-M is
very efficient; flame pays per-step f32->bf16 cast + cuBLAS overhead on a tiny matmul). FP64 near-PARITY
1.04-1.32x, tightest at large B (D=1536/B=8 = 1.007x tied, D=2048/B=8 = 1.038x) — FP64 is compute-bound on
consumer Blackwell so the GEMM dominates the wall and flame's glue overhead amortizes. 0 OOM (12GB held every
shape; largest FP64/D=2048/B=8 used ~0.4 GiB).

GATE g5 PASS x18/18: per-cell determinism run-to-run max|delta(W')| = 0 every cell; rel-RMS(fused W' vs
un-fused NAIVE-GEMM ref) <= 4.2e-8 (FP64 cells = 0.000e+00). The fusion is bit-faithful on the consumer card.

Framing (g5): flame's value on consumer HW is its IDENTITY (byte-exact / device-resident / deterministic /
no-LLVM / torch-free native step), NOT raw step-rate — torch.compile is faster everywhere on the 5070. The
earlier BENCH-1 "flame won @D=768 on the 5070" claim does NOT reproduce against torch 2.12 eager+compile
(D=768/B=1 TF32: torch eager 0.21 ms vs flame 0.43 ms). Root cause of the worst losses = per-launch + separate
cuBLAS-handle overhead at small B (the launch floor) vs torch's whole-step inductor fusion. Verdict
.verdicts/hexa-0pod/F-OP4-5070-COVERAGE.txt; driver tool/bench/run_op4_5070.sh. Deferred OP-4b (CUDA-graph /
single-megakernel step to collapse the small-B launch floor — small-B-only win, won't beat torch everywhere).

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

## 2026-06-09 — OP-5b DONE: forge-runtime -Wcomment hygiene CI gate (LOCAL, 0-GPU)

Regression-locked the OP-5 (#2973) `-Wcomment` cleanup. Added `tool/forge_runtime_warn_gate.sh` (SSOT,
locally runnable / hook-able) + `.github/workflows/forge-runtime-warn-gate.yml` (PR-on-main, paths-scoped to
the guarded files + script + workflow). OPTION A hard gate: `clang -fsyntax-only -Wcomment -Werror -x c` over an
EXPLICIT OP-5-clean allow-list (`self/runtime.h`, `self/forge/forge_tier_v1.h`, `self/native/lora_cuda.h`);
fails ONLY on a new nested-comment warning in those files. LOW BLAST RADIUS — deliberately NOT a repo-wide
`-Werror`: (1) allow-list only, so grandfathered warnings anywhere else can never fail it; (2) only `-Wcomment`,
a purely lexical class, so no CUDA toolchain / includes / type defs are needed (each file compiles stand-alone
`-x c`; runtime.h also passes full `-fsyntax-only` exit 0). clang→gcc→cc fallback. Verified LOCALLY: passes on
clean tree (3/3 PASS, exit 0); catches an injected nested `/*` in a guarded file (exit 1, precise diagnostic,
reverts clean); IGNORES the same warning injected into an unguarded file (`self/native/hxcuda_conv1d.cu`, exit
0) — proving it cannot break CI on grandfathered code. Behavior-preserving (CI-only; no source/codegen change).
Verdict .verdicts/hexa-0pod/F-OP5B-WARN-GATE.txt. OP-5b removed from `## deferred`; flipped `[x]` in milestones.

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

## OP-4b — CUDA-graph-captured flame FUSED step on RTX 5070 (sm_120) — CLOSED-NEGATIVE (honest)
Attacked the small-B launch-overhead floor OP-4 found (B=1: TF32 up to 8.96x, BF16 up to 14.66x @D=2048 vs
torch.compile) by wrapping the fused per-step DAG (cuBLAS fwd GEMM + fused valley + cuBLAS OP_T bwd GEMM
(transpose-elim) + single-launch AdamW) in a CUDA graph (cudaStreamBeginCapture/EndCapture -> Instantiate ->
GraphLaunch) so the whole step replays as ONE launch. Harness tool/bench/flame_bench_step_graph_fused.cu
(BYTE-FOR-BYTE the OP-4 -DFUSED math, only the launch mechanism differs; BF16 cast scratch pre-warmed before
BeginCapture since cudaMalloc isn't capturable), driver run_op4b_5070.sh. Swept B=1 x D={768,1536,2048} x
dtype={TF32,BF16,FP64} on the FREE pool 5070 aiden (0-pod, NO vast), iters=50, exclusivity-gated.
RESULT: graph/eager = 1.00-1.02x in EVERY cell (best BF16/D=768 1.0198x ~2%; FP64/D=768 0.9989x = noise).
The worst cell BF16/D=2048/B=1 went 14.66x -> 14.64x (ratio vs torch.compile shaved <0.5%). flame still LOSES
every small-B cell. WHERE THE LOSS LIVES: NOT launch — GEMM-RATE. Graph capture collapses ALL per-op
launch/sync into one replay; if the floor were launch-bound the ratio would have dropped, but it moved <2%.
So on the 5070 the small-B step wall is dominated by the cuBLAS GEMM execution (+ BF16 cast traffic), not by
issuing launches — the per-launch overhead is already negligible relative to even a tiny-M cuBLAS GEMM at
these D. Same structural outcome as the H100 BENCH-6 graph finding (graph ~1.0x => residual pinned to
GEMM-throughput). GATE g5 PASS x9/9: max|d(W')| graph-vs-eager =0 + run-to-run determinism =0 every cell —
graph capture is bit-exact + deterministic (a SAFE optimization that simply doesn't help this workload/card).
Launch-elimination is now CLOSED-NEGATIVE on the consumer 5070 too; flame's consumer value remains its
byte-exact/device-resident/torch-free identity, NOT step-rate. Verdict .verdicts/hexa-0pod/F-OP4B-GRAPH-5070.txt.

## OP-1b — sm_120 TF32 own-GEMM pipeline-depth sweep on RTX 5070 (aiden) — partial-positive (honest)
OP-1's deferred TF32 follow-up: close the residual ~3-15% off cuBLAS-TF32 @D=1024 (K2 = BK16/2-stage cp.async/
scalar epilogue was furthest off there, 1.15x). Probed 3 schedule/layout levers — (1) BK=32 deeper K-tile,
(2) 3-stage cp.async ring (wait_group<2>) vs the 2-stage double buffer, (3) .v2 (float2) vectorized C-store
epilogue. Harness self/native/mma_sm120/owngemm_sm120_pipe.cu (production kernel parameterized by -DLBK/
-DLSTAGES/-DLVEC; defaults 16/2/0 reproduce OP-1 bit-for-bit) + build_owngemm_pipe.sh. 8-config grid built +
run on the FREE pool 5070 aiden (sm_120, 0-pod, NO vast, GPU 0% verified idle before each timed run), gate
adds a host FP64 ground-truth ref (g5). The 128x64 register tile was NOT re-attempted (closed-neg, OP-1).
RESULT (own-GEMM TFLOP/s, off cuBLAS-TF32): baseline 24.50@1024(1.143x)/29.74@2048; L3 .v2-epi
24.93@1024(1.124x)/29.92@2048 = +1.7% @1024 WIN; L1 BK=32 22.76@1024(1.231x) REGRESS; L2 3-stage
22.79@1024(1.229x) REGRESS; every combo with BK32 or 3-stage REGRESSES; BK32+3stage BUILD-FAIL (ptxas
0xd200 smem > 0xc000 48KB cap). baseline & L3 re-run x3, variance <0.05 TFLOP/s — the +0.43 TFLOP/s gain is
stable not noise. WHERE: the K-pipeline-depth levers made it WORSE — on the 5070's 48KB smem cap the
2-stage/BK16 config is the occupancy sweet spot at D=1024/2048; deepening the K-tile or the ring trades
occupancy for a latency-hide that's already saturated, and stacking them overflows smem. Matches OP-1: the
consumer-card lever is memory-instruction VECTORIZATION (.v4 loads = OP-1's big win, .v2 store = OP-1b's
small one), NOT staging depth. GATE g5: bit-exact HELD — every building config byte-identical to the OP-1
baseline (rel-RMS vs baseline = 0; vs-cuBLAS-TF32 1.33e-05@768/3.02e-05@1024/1.74e-05@2048 unchanged;
vs-FP64 ~1e-4 = the TF32 10-bit-mantissa truncation floor, same for cuBLAS). SHIPPED: only the .v2 epilogue
folded into the production owngemm_sm120.cu (re-verified on aiden: @1024 24.93 TFLOP/s 1.13x / @2048 29.86
1.02x, gate PASS). BK=32 / 3-stage kept OUT (closed-negative on consumer card). Best sm_120 TF32 own-GEMM
now 24.93 TFLOP/s @1024 (1.13x off cuBLAS, was 1.15x). Verdict .verdicts/hexa-0pod/F-OP1B-SM120-PIPE.txt.
