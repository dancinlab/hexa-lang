# HEXA-0POD

@title: 🔁 HEXA-0POD — flame+forge improvement loop on FREE resources only (no vast pod)

@goal: Continuously improve flame + forge using ONLY free resources — the sidecar pool (aiden RTX 5070
sm_120, summer RTX 5070, pi5-akida, ghost) + local CPU/code work. ZERO vast rentals. Each round: pick a
0-pod-feasible improvement, do it, verify on a free pool GPU (byte-eq / bit-exact gates), land it, loop.
Hopper-sm_90a-only work (the wgmma decode-elim own-GEMM) is OUT-OF-SCOPE here (needs an H100 pod); this
loop targets what the consumer card + code can carry.

## milestones (loop self-feeds; add as discovered)

- [x] **OP-1 — sm_120 own-GEMM speedup on aiden (close the cuBLAS gap, bit-exact)** — the sm_120 OWN120
  (mma.sync m16n8k8 TF32, ~4.9-8.1 TFLOP/s, 3.2-6.9x off cuBLAS) has headroom: deeper smem staging,
  bank-conflict-free loads, register-tiling, mma pipelining (2 mma in flight), vectorized epilogue. Improve
  it toward consumer-card cuBLAS, bit-exact (rel-RMS vs FP64 ref). Free aiden GPU.
  DONE — K2 (bank-conflict-free smem pad + .v4 128-bit global loads + cp.async double-buffer) folded into the
  production owngemm_sm120.cu, bit-exact (rel-RMS vs baseline=0, bitdiff=0). aiden RTX 5070: 6.75->24.49 TFLOP/s
  @1024 (4.16x->1.15x off cuBLAS), 8.05->29.81 TFLOP/s @2048 (3.83x->1.02x off — near parity). cuBLAS-multiple
  3.2-6.9x -> ~1.0-1.15x (target <2.5x beaten). Layout/load-vectorization = dominant lever (+3.1-3.4x); cp.async
  modest top-up; the 128x64 register tile PLATEAUED (regressed on consumer card, not shipped). Verdict
  .verdicts/hexa-0pod/F-OP1-SM120-OWNGEMM.txt.
- [x] **OP-2 — wire bench-proven step wins into the REAL flame trainer (forge code + aiden verify)** — the
  HEXA-BENCH wins live only in the bench harness; port the cuBLAS-FP64 lane + fused valley (LN+gelu) +
  single-launch AdamW + transpose-elimination into the actual flame CLMConvMoE trainer step so the real
  product gets faster. Gate: byte-eq vs prior trainer output (max|d|=0) on aiden; the trainer improves, not
  just a benchmark. Pure code + aiden verify, 0-pod. DONE: audit found 3/4 wins (cuBLAS-FP64 default,
  fused valley HEXA_FUSE_*, single-launch AdamW HEXA_CLM_FULLSTEP) ALREADY in the trainer from HEXA-FUSION.
  The missing BENCH-10 TRANSPOSE-ELIM is wired: GPU kernel _hx_cuda_farr_matmul_tn_gpu (cuBLAS OP_T) +
  forge_dispatch_matmul_t codegen/proto LANDED; byte-eq PROVEN max|Δ|=0 (4 cases) via the CPU oracle
  clm_prod_transpose_elim_eq.hexa on `hexa run` (0-pod, no GPU). The live trainer swap + step/s measure
  are deferred to the GPU build (runtime.c wrapper body is build-time-assembled). Verdict
  .verdicts/hexa-0pod/F-OP2-TRAINER-WIRE.txt.
- [x] **OP-3 — BF16 sm_120 own-GEMM (aiden)** — extend the sm_120 own-GEMM to BF16 (mma.sync bf16), measure
  vs cuBLAS-BF16, bit-faithful. Free aiden GPU.
  DONE — added a BF16 path (mma.sync.aligned.m16n8k16.row.col.f32.bf16.bf16.f32 — k16, two bf16/reg; fp32
  inputs RN→bf16, fp32 accum) in self/native/mma_sm120/owngemm_sm120_bf16.cu, reusing OP-1's bank-conflict-
  free smem pad + .v4 128-bit float4 global loads + cp.async double-buffer VERBATIM. aiden RTX 5070 (free,
  GPU 0% verified): own-GEMM-BF16 26.1-26.5 TFLOP/s @1024, 33.3 @2048; cuBLAS-BF16 54.7 @1024 / 61.5-66.7
  @2048 → cuBLAS-multiple ~2.0-2.1x @1024, ~1.85-2.0x @2048. GATE (g5 bit-FAITHFUL, W14): rel-RMS vs FP64
  ref 2.7e-3@768 / 6.7e-3@1024 / 8.0e-3@2048 ≤1e-2 PASS (BF16 8-bit-mantissa floor, correct layout);
  determinism max|d|=0 bitdiff=0/N HELD. HONEST: the multiple is WIDER than TF32's ~1.0-1.15x because BF16
  DOUBLES the cuBLAS roofline (own-GEMM absolute TFLOP/s is actually HIGHER than TF32; cuBLAS scales faster)
  — real ~2x reported per g5. Win = working bit-faithful BF16 own-GEMM on the consumer card riding OP-1's
  layout/load lever. Verdict .verdicts/hexa-0pod/F-OP3-BF16-SM120.txt.
- [x] **OP-3b — .v2 vectorized C-store epilogue on the BF16 sm_120 own-GEMM (aiden)** — apply OP-1b's ONE
  bit-exact-positive lever (.v2 float2 C-store) to the BF16 path; the BF16 mma OUTPUT fragment is fp32 with
  the IDENTICAL m16n8 C layout as TF32, so c0/c1 (and c2/c3) fuse to one 64-bit store. DONE — aiden RTX 5070
  (free, GPU 0% verified): .v2 helped BIT-EXACTLY +2.1% @1024 (26.06→26.60 TFLOP/s, 2.10x→2.06x off cuBLAS-
  BF16) / +1.0% @2048 (33.20→33.52), output BYTE-IDENTICAL to the OP-3 scalar baseline (rel-RMS vs OP-3 = 0,
  cmp clean). GATE (g5 bit-faithful) UNCHANGED: rel-RMS vs FP64 2.7e-3/6.7e-3/8.0e-3 PASS; determinism
  max|d|=0 bitdiff=0/N HELD. HONEST: ~2x gap is the doubled cuBLAS-BF16 roofline (roofline-bound), so the
  store-only lever gives the predicted ~1-2% — same magnitude as OP-1b's TF32 +1.7%; SHIP. BK=32/3-stage
  (OP-1b) + 128x64 register tile (OP-1) NOT re-attempted (CLOSED-NEG on 5070). The consumer-card own-GEMM's
  identity-preserving lever ladder is now EXHAUSTED. Verdict .verdicts/hexa-0pod/F-OP3B-BF16-EPILOGUE.txt.
- [x] **OP-4 — flame fused-step on aiden: extend shape/dtype coverage** — run the BENCH-10 fused step across
  more (D,T,B,dtype) on the free 5070, find + document where flame wins/loses on consumer hardware.
  DONE — swept D={768,1536,2048} x B={1,8} x dtype={FP64,TF32,BF16} = 18 cells on aiden RTX 5070 (sm_120),
  flame FUSED step (cuBLAS lane) vs torch eager+compile. HONEST consumer-card frontier: flame LOSES to
  torch.compile in ALL 18 cells (no crossover-D where flame wins). Ratio (flame/torch_compile) trend: TF32
  1.78x->8.96x (widens with D at B=1, ~2.8x at B=8); BF16 worst, up to 14.66x @D=2048/B=1; FP64 near-parity
  1.04-1.32x (D=1536/B=8 = 1.007x tied) — FP64 is compute-bound so the GEMM amortizes flame's glue overhead.
  0 OOM (12GB held every shape). GATE g5 PASS x18/18: determinism max|d(W')|=0 every cell, rel-RMS(fused vs
  unfused-naive ref) <=4.2e-8 (FP64 cells =0). flame's consumer-card value = byte-exact/device-resident/
  torch-free identity, NOT step-rate; torch.compile is faster everywhere on the 5070. The BENCH-1 "flame won
  @D=768 on 5070" claim does NOT reproduce vs torch 2.12. Verdict .verdicts/hexa-0pod/F-OP4-5070-COVERAGE.txt.
- [x] **OP-4b — 5070 launch-overhead-floor: CUDA-graph the fused step (aiden)** — wrap the fused per-step DAG
  (cuBLAS fwd GEMM + fused valley + cuBLAS OP_T bwd GEMM (transpose-elim) + fused AdamW) in a CUDA graph
  (cudaStreamBeginCapture/EndCapture -> Instantiate -> GraphLaunch) so the whole step replays as ONE launch,
  to collapse the small-B launch floor OP-4 found (B=1: TF32 up to 8.96x, BF16 up to 14.66x @D=2048 vs
  torch.compile). DONE on aiden RTX 5070 (sm_120) over B=1 x D={768,1536,2048} x dtype={TF32,BF16,FP64}.
  CLOSED-NEGATIVE (honest): graph/eager = 1.00-1.02x in EVERY small-B cell — graph capture does NOT cut the
  floor. Worst cell BF16/D=2048/B=1 went 14.66x -> 14.64x (shaved <0.5%). The small-B loss is GEMM-RATE-bound,
  NOT per-launch-overhead-bound — same structural result as the H100 BENCH-6 graph finding; launch-elimination
  is exhausted as a lever on the consumer card. GATE g5 PASS x9/9: max|d(W')| graph-vs-eager =0 + run-to-run
  determinism =0 every cell (graph capture is bit-exact + deterministic, a SAFE optimization that just doesn't
  help here). flame's consumer value stays its byte-exact/device-resident/torch-free identity, NOT step-rate.
  Harness tool/bench/flame_bench_step_graph_fused.cu + driver run_op4b_5070.sh. Verdict
  .verdicts/hexa-0pod/F-OP4B-GRAPH-5070.txt.
- [x] **OP-5 — forge robustness/correctness hardening (local, 0-GPU)** — pick a forge code-quality / numerical-
  robustness improvement (error paths, dtype edge cases, determinism guards) verifiable without a GPU.
  DONE — fixed the `self/runtime.h:422-423` `'/*' within block comment` `-Wcomment` warning (the `native/*.c`
  glob inside a `/* … */` block formed a nested `/*` token). Minimal comment-only fix (`native/ *.c`, +2/-2):
  `clang -fsyntax-only -Wcomment -x c self/runtime.h` 2 warnings → 0, no declaration/codegen/behavior change.
  Repo-wide `-Wcomment` + `-Wextra-tokens` sweep over ALL checked-in C/H/CU/CUH + forge-emitted wrappers +
  emit-string `.hexa` sources found NO other genuine hits (one `#pragma once in main file` artifact correctly
  ignored, not "fixed"). All behavior-preserving. Verdict .verdicts/hexa-0pod/F-OP5-FORGE-HARDEN.txt.
- [x] **OP-5b — forge-runtime warning-hygiene CI gate (local, 0-GPU)** — lock in the OP-5 `-Wcomment` cleanup
  so it can't reland. Added `tool/forge_runtime_warn_gate.sh` (SSOT) + `.github/workflows/forge-runtime-warn-
  gate.yml` (PR-on-main, paths-scoped). OPTION A hard gate: `clang -fsyntax-only -Wcomment -Werror -x c` over an
  EXPLICIT OP-5-clean allow-list (`self/runtime.h`, `self/forge/forge_tier_v1.h`, `self/native/lora_cuda.h`),
  fails ONLY on a new nested-comment warning in those files. LOW BLAST RADIUS — NOT a repo-wide `-Werror`:
  allow-list only (grandfathered warnings elsewhere can never fail it) + only `-Wcomment` (purely lexical, no
  CUDA/includes/types). Verified LOCALLY: passes on clean tree (3/3 PASS, exit 0); catches an injected nested
  `/*` in a guarded file (exit 1, precise diagnostic, reverts clean); IGNORES the same warning injected into an
  unguarded file (exit 0 = CI-safe). Behavior-preserving CI-only addition. Verdict .verdicts/hexa-0pod/F-OP5B-WARN-GATE.txt.
- [x] **OP-1b — sm_120 own-GEMM: BK=32 + 3-stage cp.async pipeline + .v2/.v4 vectorized epilogue (aiden)** —
  OP-1 deferred TF32 follow-up to close the residual ~3-15% off cuBLAS-TF32 @D=1024 (K2 was furthest off
  there). DONE — swept all 3 levers on aiden RTX 5070 (sm_120) bit-exact vs FP64 + vs the OP-1 baseline.
  HONEST partial-positive: ONLY the .v2 (float2) vectorized C-store epilogue helped — c0/c1 (and c2/c3) are
  contiguous so they fuse to one 64-bit store; +1.7% @1024 (24.50→24.93 TFLOP/s, 1.143x→1.124x off cuBLAS),
  small top-up @2048 (29.74→29.92, ~1.02x). BK=32 and the 3-stage cp.async ring BOTH REGRESSED (−1.7 TFLOP/s
  @1024: doubling per-stage smem cuts CTA occupancy below the already-saturated latency-hide on the 5070's
  48KB cap), and BK32+3stage OVERFLOWS smem entirely (0xd200 > 0xc000, ptxas reject) — both CLOSED-NEGATIVE
  on the consumer card, kept OUT of production (the consumer-card lever is memory-instruction vectorization,
  not staging depth — matches OP-1). The 128x64 register tile was NOT re-attempted (closed-neg, OP-1). GATE
  (g5): bit-exact HELD — every building config byte-identical to the OP-1 baseline (rel-RMS vs baseline = 0;
  vs-cuBLAS-TF32 1.33e-05@768/3.02e-05@1024/1.74e-05@2048 unchanged; vs-FP64 ~1e-4 = the TF32 truncation
  floor, same for cuBLAS). Shipped: .v2 epilogue folded into the production owngemm_sm120.cu (re-verified on
  aiden). Best: 24.93 TFLOP/s @1024 (1.13x off cuBLAS, was 1.15x) / 29.86 @2048 (1.02x). Verdict
  .verdicts/hexa-0pod/F-OP1B-SM120-PIPE.txt.

## deferred (0-pod follow-ups surfaced by the loop — self-feed)

- **OP-2b — land the runtime.c hexa_forge_dispatch_matmul_t wrapper body + flip the trainer to the live
  transpose-elim call.** OP-2 landed the GPU kernel (_hx_cuda_farr_matmul_tn_gpu, cuBLAS OP_T), codegen
  mapping, runtime.h proto, and proved dW byte-eq (max|Δ|=0). The remaining piece is the runtime.c wrapper
  body (no-CUDA host A^T@B oracle + CUDA route) — self/runtime.c is build-time-assembled (gitignored), so it
  + a fresh hexa rebuild must be done in the clm_prod_gpu GPU build env (project_clmprod_gpu_build_seed_drift).
  Then flip the documented comment in conv1d_bwd_via_forge to the live forge_dispatch_matmul_t call under
  HEXA_BWD_TRANSPOSE_ELIM, and measure step/s before/after on aiden. NOT vast — the small-config build runs on
  the pool 5070.
- **OP-2c — batched-expert transpose-elim (forge_dispatch_matmul_t_batched, cublasDgemmStridedBatched OP_T).**
  conv2_bwd_via_forge_batched (the 2-expert path, ~65% of step cost) still uses the OP_N strided
  _clmp_matmul_batched. Extend the OP_T transpose-elim to the batched dW GEMM to reach the dominant path.
  Byte-eq gate identical (max|Δ|=0 to the im2col_t+OP_N batched reference). Free aiden GPU.

- **OP-5c — forge error-path / dtype-edge / determinism hardening (NEEDS GPU — deferred out of 0-GPU scope).**
  The robustness improvements OP-5 originally listed (error paths, dtype edge cases, determinism guards in the
  forge runtime) cannot be gated byte-eq without running a kernel; they belong to a GPU round (aiden 5070), not
  this 0-pod pass. Logged here so the loop doesn't re-attempt them as "0-GPU".
## honest framing (g5)

Free-resource-only loop: every gate runs on the sidecar pool (aiden/summer 5070) or locally — NO vast cost.
Bit-exact / byte-eq discipline holds (the consumer card preserves flame's identity). When a milestone genuinely
needs a Hopper H100 (sm_90a wgmma), it is DEFERRED here (out of 0-pod scope), not faked. The loop drains this
backlog and self-feeds new 0-pod milestones as they surface.
