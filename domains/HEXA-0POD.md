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
- [ ] **OP-3 — BF16 sm_120 own-GEMM (aiden)** — extend the sm_120 own-GEMM to BF16 (mma.sync bf16), measure
  vs cuBLAS-BF16, bit-faithful. Free aiden GPU.
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

## deferred (0-pod follow-ups surfaced by the loop — self-feed)

- **OP-1b — sm_120 own-GEMM: BK=32 + 3-stage cp.async pipeline + .v2/.v4 vectorized epilogue.** OP-1 reached
  1.02-1.15x off cuBLAS with K2 (BK=16, 2-stage). Probe whether deepening the K tile to BK=32 and going to a
  3-deep cp.async ring (wait_group<2>) closes the residual ~3-15% at D=1024 (where K2 is furthest off). Also
  vectorize the C store epilogue (.v2/.v4) — currently 4 scalar masked writes per fragment. Bit-exact gate
  unchanged (accumulation order preserved; pure schedule/layout). Free aiden GPU. The register-tile lever
  (128x64) is CLOSED-NEGATIVE on the consumer card — do NOT re-attempt it; the win is K-pipeline depth + the
  epilogue, not the per-CTA output tile.
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
- **OP-4b — 5070 launch-overhead-floor: CUDA-graph / single-megakernel fused step (aiden).** OP-4 found flame's
  worst losses on the consumer card are at SMALL B (B=1): TF32 1.78x->8.96x and BF16 up to 14.66x as D grows,
  where the GEMM is tiny and the step is dominated by per-launch + separate-cuBLAS-handle overhead (torch's
  inductor fuses the whole step into ~2 kernels). The lever flame already has but the bench step does NOT use:
  capture the per-step DAG into a CUDA graph (one launch/replay) OR fold valley+epilogue+AdamW into one
  megakernel around the two cuBLAS calls, to collapse the per-launch floor that loses small-M cells. Gate:
  byte-eq vs the current fused step (max|d(W')|=0) on aiden + re-measure the small-B ratio. Free 5070, 0-pod.
  HONEST scope note: this only attacks the launch-floor regime (small B); FP64 is already near-parity (compute-
  bound, 1.0x) so it won't move there, and large-B TF32/BF16 stays ~3-5x off (cuBLAS GEMM-rate bound, not
  glue) — so OP-4b is a small-B-only win, not a path to beating torch.compile everywhere on the consumer card.

## honest framing (g5)

Free-resource-only loop: every gate runs on the sidecar pool (aiden/summer 5070) or locally — NO vast cost.
Bit-exact / byte-eq discipline holds (the consumer card preserves flame's identity). When a milestone genuinely
needs a Hopper H100 (sm_90a wgmma), it is DEFERRED here (out of 0-pod scope), not faked. The loop drains this
backlog and self-feeds new 0-pod milestones as they surface.
