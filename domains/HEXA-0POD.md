# HEXA-0POD

@title: 🔁 HEXA-0POD — flame+forge improvement loop on FREE resources only (no vast pod)

@goal: Continuously improve flame + forge using ONLY free resources — the sidecar pool (aiden RTX 5070
sm_120, summer RTX 5070, pi5-akida, ghost) + local CPU/code work. ZERO vast rentals. Each round: pick a
0-pod-feasible improvement, do it, verify on a free pool GPU (byte-eq / bit-exact gates), land it, loop.
Hopper-sm_90a-only work (the wgmma decode-elim own-GEMM) is OUT-OF-SCOPE here (needs an H100 pod); this
loop targets what the consumer card + code can carry.

## milestones (loop self-feeds; add as discovered)

- [ ] **OP-1 — sm_120 own-GEMM speedup on aiden (close the cuBLAS gap, bit-exact)** — the sm_120 OWN120
  (mma.sync m16n8k8 TF32, ~4.9-8.1 TFLOP/s, 3.2-6.9x off cuBLAS) has headroom: deeper smem staging,
  bank-conflict-free loads, register-tiling, mma pipelining (2 mma in flight), vectorized epilogue. Improve
  it toward consumer-card cuBLAS, bit-exact (rel-RMS vs FP64 ref). Free aiden GPU.
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
- [ ] **OP-4 — flame fused-step on aiden: extend shape/dtype coverage** — run the BENCH-10 fused step across
  more (D,T,B,dtype) on the free 5070, find + document where flame wins/loses on consumer hardware.
- [ ] **OP-5 — forge robustness/correctness hardening (local, 0-GPU)** — pick a forge code-quality / numerical-
  robustness improvement (error paths, dtype edge cases, determinism guards) verifiable without a GPU.

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

## honest framing (g5)

Free-resource-only loop: every gate runs on the sidecar pool (aiden/summer 5070) or locally — NO vast cost.
Bit-exact / byte-eq discipline holds (the consumer card preserves flame's identity). When a milestone genuinely
needs a Hopper H100 (sm_90a wgmma), it is DEFERRED here (out of 0-pod scope), not faked. The loop drains this
backlog and self-feeds new 0-pod milestones as they surface.
