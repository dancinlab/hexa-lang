# HEXA-0POD

@title: 🔁 HEXA-0POD — flame+forge improvement loop on FREE resources only (no vast pod)

@goal: Continuously improve flame + forge using ONLY free resources — the sidecar pool (aiden RTX 5070
sm_120, summer RTX 5070, pi5-akida, ghost) + local CPU/code work. ZERO vast rentals. Each round: pick a
0-pod-feasible improvement, do it, verify on a free pool GPU (byte-eq / bit-exact gates), land it, loop.
Hopper-sm_90a-only work (the wgmma decode-elim own-GEMM) is OUT-OF-SCOPE here (needs an H100 pod); this
loop targets what the consumer card + code can carry.

## milestones (loop self-feeds; add as discovered)

<!-- ANCHOR:OP-25-BF16-FASTMODE (unique anchor — next precision-uncap rung: deterministic BF16 fast-mode; self-byte-eq + W14-tol vs FP64 + speed vs TF32; precision Pareto placement BF16-vs-TF32; aiden 5070) -->
- [ ] **OP-25 — deterministic BF16 fast-mode: self-byte-eq + W14-tol + speed vs TF32 (precision Pareto, aiden)**

<!-- ANCHOR:OP-23-TF32-DRIFT (unique anchor — TF32 N-step trajectory drift vs FP64; validate TF32 fast-mode is real, not a 1-step illusion; aiden 5070) -->
- [x] **OP-23 — TF32 N-step trajectory drift vs FP64: validate TF32 fast-mode is real not 1-step illusion (aiden)** —
  GREEN. Decisively VALIDATED: OP-20's deterministic TF32 fast-mode is a REAL training fast-mode, NOT a 1-step
  illusion. Ran TWO continuous trajectories (TF32 + FP64) from the SAME seed/data for N=100 steps (AdamW state
  PERSISTS so drift accumulates; OP-20 reset every step), aiden RTX 5070 FREE pool, 4/4 cells (DEFAULT+PEDANTIC,
  D={768,1536}, B={1,8}). (1) LOSS-TRACKING = YES, decisive: TF32 loss tracks FP64 loss to ~1e-7 every step;
  WORST gap 2.5e-5 is at the COLD-START step 1, then DROPS to ~1e-7 and stays flat — NO peeling, NO drift trend,
  both lanes converge to the SAME loss along the SAME curve. (2) WEIGHT rel-RMS = BOUNDED ~5e-7 (starts 1.13e-6
  = OP-20 1-step #, then SHRINKS to ~4.5-5.3e-7 by step 100; does NOT grow) — chaotic-but-microscopic (3-4 orders
  inside NN's ~1e-3 forgiveness). (3) TF32 self-byte-eq over the WHOLE trajectory: run1-vs-run2 W max|Δ|=0 AND
  per-step loss max|Δ|=0 at step N (determinism holds across the trajectory, not just step 1; PEDANTIC not needed).
  HONEST (g5): the RIGHT metric is loss-tracking (training-equiv), NOT weight byte-closeness — chaos guarantees
  weights drift, that's why flame's identity is SELF-determinism (TF32-vs-TF32=0), not cross-precision. So:
  bounded loss-tracking = real fast-mode CONFIRMED. Caveat: N=100 small synthetic config (mean(G²) loss proxy,
  no real corpus/LR-schedule); drift TREND flat-to-shrinking to step 100, no late blow-up. Harness
  tool/bench/flame_traj_drift_tf32_op23.cu + driver run_op23_5070.sh + raw op23_5070_raw.log; verdict
  .verdicts/hexa-0pod/F-OP23-TF32-DRIFT.txt. FREE pool only, NO vast, leak-0.

<!-- ANCHOR:OP-22-MEGASTEP-DESIGN (unique anchor — 0-pod whole-step MEGASTEP megakernel DESIGN + Amdahl bound + H100 experiment recipe; measure is GPU-gated; honest vs TF32-mode) -->
- [x] **OP-22 — MEGASTEP whole-step megakernel DESIGN + Amdahl bound + experiment recipe (0-pod, GPU-gated; vs TF32-mode)** —
  produced (reading existing real-pod verdicts + research memory only, $0, 0-GPU, NO vast) the DESIGN +
  honest Amdahl ceiling + turnkey H100 recipe for MEGASTEP (whole flame CLMConvMoE train step fused into one
  persistent grid-resident cooperative megakernel). VALLEY STRUCTURE (cited F-FUSION-FF-DUTYCYCLE, real H100):
  GEMM% = 0.04% of wall vs valley = 99.96% (GLUE 13.15% + GAP/idle 86.80% + OPT 0.01%); util MEDIAN 1% / MEAN
  10.9% / 72.2% samples <5% = BIMODAL occupancy wall. AMDAHL CEILING = 1/GEMM% = 2844× — a USELESS ceiling
  (huge only because GEMM is a rounding error); the BINDING bound is the serial-DAG occupancy FLOOR. DESIGN:
  9-phase grid.sync()-delimited cooperative kernel (embed→conv→GN→gelu→residual→router/experts→gelu2→pack→
  combine→GN2→logits→CE→bwd-glue→coop-AdamW) with inline own-GEMM; BOTH megakernel walls already closed
  (own-GEMM #2697 + coop GN byte-eq, F-FUSION-MEGAKERNEL-GN-GRIDSYNC). THREE honest tensions (cited): own-GEMM
  ~6× off cuBLAS (W10), byte-eq ⊥ util-lift (B6 max|Δ| 9e-16…1.8e-15 ≠ 0 at first fwd), parity wgmma can't
  co-reside (MEGA-OWNGEMM blockDim<128 + (S/128)²>264-CTA wave deadlock). MEGASTEP is MEASURED closed-negative
  (M2 MEAN +3.4pp, MEDIAN unmoved, self-speedup ~1.0–1.04×). HONEST vs TF32 (OP-20 ~4.2× @B=1): (b) DOMINATED
  — same valley, TF32 ~4× the win at ~0 architecture risk; MEGASTEP's only GREEN slice (FF-VALLEY 2.5×) is a
  byte-eq single-thread-GN ARTIFACT that collapses to MPK ~1.2–1.3× in a TF32/parallel trainer; no orthogonal
  stack on top of TF32. VERDICT: do NOT spend an H100 campaign on MEGASTEP. Wrote the turnkey recipe anyway
  (FF-DUTYCYCLE→FF-VALLEY→MEGASTEP rungs + byte-eq/util/TF32 gates + leak-0 destroy) so it is runnable the
  moment a GPU is authorized — with an EARLY-EXIT note (already measured; re-running buys 0 info). HONEST
  (OP-2b/OP-21-class, g5): DESIGN + BOUND only, NO measurement performed or claimed; NO pod rented (0-pod goal
  = ZERO vast). Verdict .verdicts/hexa-0pod/F-OP22-MEGASTEP-DESIGN.txt.

<!-- ANCHOR:OP-21-HOPPER-WARPSPEC-DESIGN (unique anchor — 0-pod DESIGN for the Hopper sm_90a wgmma warp-spec TMA pipeline; measure is GPU-gated) -->
- [x] **OP-21 — Hopper warp-spec TMA pipeline DESIGN + perf-gap analysis + H100 experiment recipe (0-pod, GPU-gated measure)** —
  produced (reading source + verdicts only, $0, 0-GPU) the design for the forge own-GEMM's remaining Hopper
  (sm_90a wgmma) perf lever: a warp-specialized TMA producer/consumer software pipeline (the cuBLAS-class
  mainloop). MAPPED W10-has-vs-misses against the actual frontier source self/native/wgmma/wgmma_tf32_w10_lib.h
  (HAS: HW TMA producer/single elected thread, dual consumer WGs, SWIZZLE_128B TMA, composed software decode,
  NST swizzled-TMA ring; MISSES: dedicated producer WG + setmaxnreg register realloc, decode/MMA overlap at
  2 CTA/SM, descriptor-direct wgmma deleting the 32KB band, m64n256k8, ping-pong epilogue). ROOFLINED the
  6.09x gap (70.7 vs ~430 TFLOP/s) to the decode/MMA-overlap (B)+(C) KNOT — occupancy A~0% (closed by W8,
  W10 already at max 2 CTA/SM), epilogue D small — with cited W7..W15 verdict numbers. DESIGNED the next
  lever OP-21A: canonical-atom re-encode (kills the W15 "3rd interaction" root cause) -> descriptor-direct
  wgmma (delete the 32KB band, W15-real -32KB) -> spend the headroom on a deeper decode-free TMA ring +
  wgmma.wait_group<NST-2> overlap + setmaxnreg producer/consumer split (UNBLOCKED at 128x128's 64-reg
  accumulator, unlike W12's 128x256 which ptxas rejected), with concrete smem/stage/barrier/register budget;
  + OP-21B fallback (register wgmma double-buffer, no M3 dependency). WROTE the turnkey H100 recipe (rent 1
  H100 sm_90a nvcc12.6 -> build wgmma_tf32_w16.cu #include w10-lib -> gate rel_rms 0 MODE0/1 then MODE4
  @2048/4096/8192 -> ONLY THEN sweep own vs same-binary cuBLAS-TF32 -> write W16 verdict Δ-vs-W10 -> destroy
  pod leak 0). HONEST (OP-2b-class, g5): this is the DESIGN for a GPU-GATED experiment — NO measurement
  performed or claimed; the Hopper measure stays out of 0-pod scope until an H100 is authorized. $0, no
  vast/pool/pod. Verdict .verdicts/hexa-0pod/F-OP21-HOPPER-WARPSPEC-DESIGN.txt (PR #3000).

<!-- ANCHOR:OP-20-TF32-FASTMODE (unique anchor — precision-change uncap lever: deterministic TF32 fast-mode) -->
- [x] **OP-20 — deterministic TF32 fast-mode: self-byte-eq + W14-tol vs FP64 + speedup measure (aiden)** —
  probed the ONE unexplored uncap lever (PRECISION-CHANGE FP64->TF32) the campaign named. New harness
  tool/bench/flame_bench_step_tf32fast.cu runs a TF32 lane (CUDA_R_32F, COMPUTE_32F_FAST_TF32 tensor-op) AND
  an FP64 lane (CUDA_R_64F) in ONE process over the OP-4 fused step DAG (fused valley + transpose-elim bwd
  GEMM + single-launch AdamW; only the cuBLAS compute type differs; all glue in FIXED deterministic order).
  Measured on FREE aiden 5070 (sm_120), idle-guarded, 8 cells (DEFAULT + PEDANTIC × D={768,1536} × B={1,8}).
  RESULT (all 8 PASS): (a) GATE-A TF32 self-byte-eq run-to-run max|delta(W')| = EXACTLY 0 — pedantic-cublas
  NOT needed (default tensor-op TF32 is already deterministic on the 5070; PEDANTIC gives identical bytes at
  identical time → recommend PEDANTIC as the portable SHIP guarantee). (b) GATE-B rel-RMS(TF32 vs FP64 W') ~
  1.13e-6 — 4 orders inside W14 1e-2. (c) SPEED FP64/TF32 = 4.19-4.63x @B=1, 19-21x @B=8 → BREAKS the ~3x cap
  at every shape (B=1 latency-bound — the regime the cap was named for — is already 4.2-4.6x). HONEST: the
  B=8 ~20x is INFLATED by the 5070's crippled FP64 (~1/64 FP32); a datacenter card would show less — quote
  B=1 (4.2x, card-robust) as the headline; determinism proven for THIS card/cuBLAS-13.0 (pin PEDANTIC to
  guarantee portably). Deterministic TF32 fast-mode = a REAL flame fast-mode: identity kept + W14-equivalent
  + >3x faster. Verdict .verdicts/hexa-0pod/F-OP20-TF32-FASTMODE.txt. $0, FREE aiden, no vast/pod/leak.
  FOLLOW-UPS (deferred): wire TF32 compute-type into the live forge GEMM dispatch (clm_prod build + aiden
  verify, analogous to OP-2); multi-step TF32-vs-FP64 trajectory-drift study (long-horizon).

<!-- ANCHOR:OP-19-CROSSPLATFORM-EXACT (unique anchor — cross-PLATFORM byte-eq, distinct from OP-11/OP-15 single-machine run-to-run) -->
- [x] **OP-19 — cross-platform byte-exact: measure libm-exp divergence across arch/OS, close if real (0-GPU)** —
  MEASURE→ISOLATE→FIX, free pool only ($0, NO vast). The OP-2/7/8/9/10/11/12/13+OP-15 series proved the flame
  step byte-exact RUN-TO-RUN on ONE machine; cross-PLATFORM (x86 vs arm64 · Darwin vs Linux libm) was
  UNVERIFIED. Built a self-contained `hexa run` oracle (stdlib/flame/op19_crossplatform_selfcontained.hexa)
  that folds the exact IEEE-754 bytes (f64_to_bytes_le — float_to_bits is too new for aiden's prebuilt
  runtime.a) of CE-bwd clm_ce_grad's grad in BOTH libm-exp + dt_exp-Taylor form. RAN ON 3 PLATFORMS: local +
  ghost (arm64-macos) vs aiden (x86-linux) — cross-arch AND cross-OS. VERDICT: libm-exp CEBWD fold DIVERGED
  (arm64-macos 7969105254299072804 ≠ x86-linux 3352931952497630952) while dt_exp was byte-IDENTICAL on all 3.
  ISOLATED via per-element byte diff: EXACTLY 4 of 4096 grad elems differ, EACH by 1 mantissa-LSB = 1 ULP
  (glibc vs Darwin libm round 4 inputs differently). HOLE REAL → FIXED: swapped clm_ce_grad libm `exp` →
  dt_exp (matching CE-fwd nn_ce_loss_allpos) on host (clm_prod.hexa) AND the GPU kernel (_hx_dt_exp_dev in
  runtime_cuda_emit.hexa, the _moe_exp_dev precedent → host↔device byte-eq holds + device also deterministic).
  Grad-change magnitude: max abs 2.17e-18, max rel ≈2.0e-14 (a few ULPs) — trades "matches libm" for "matches
  across ALL platforms" (g5 honest). AFTER: production CE-bwd fold = 7679248634312321699 IDENTICAL on all 3 →
  cross-platform byte-identical YES. OP-11 oracle RE-LOCKED (clm_prod_ce_softmax_grad_eq.hexa _ce_grad_prod +
  _ce_grad_ref libm→dt_exp): F-OP11 = 1 PASS, all max|Δ|=0. Contract doc updated (3 exp impls → 2). RESIDUAL
  (honest latent, not closed): GELU libm `erf` (fwd+bwd) is the same kind of hole but no bit-accurate
  deterministic erf exists in-tree (A&S 7.1.26 is 1.5e-7-off + itself libm-exp-dependent) AND `erf` won't link
  on aiden's runtime — documented as follow-up. $0, 0-GPU, free pool, no vast. Verdict
  .verdicts/hexa-0pod/F-OP19-CROSSPLATFORM-EXACT.txt.

<!-- ANCHOR:OP-18-L3-FUSED-HOST (unique anchor — completes the OP-16 L3 fused-dispatch family: gelu2 + moe_block2) -->
- [x] **OP-18 — host fallbacks for the remaining L3 fused dispatchers (gelu2 + moe_block2), 0-GPU testable** —
  completes the OP-16 (#2995) L3 fused-dispatch family: forge_dispatch_gelu2 (L3-b) + forge_dispatch_moe_block2
  (L3-d) were GPU-only (fusion_dispatch.c #ifdef HEXA_CUDA), so a 0-GPU `hexa run` driving the fused paths
  failed to LINK (undefined symbol). DONE — wrote the missing `#ifndef HEXA_CUDA` host twins in self/runtime.c
  (gelu2 = two erf-GELU passes == 2× nn_gelu_fwd; moe_block2 = gelu2 → expert_pack2(E=2) → moe_router replaying
  moe_lib _moe_exp scaled-Taylor + OP-8's PROVEN canonical order: per-pos max-sub, e-ascending denom + combine).
  FP_CONTRACT OFF (OP-16's cure) → max|Δ| EXACTLY 0, no 1-ULP residual. Proven 0-GPU: both symbols U→T, the two
  tracked oracles drive each fused entry point through the host dispatch vs the unfused reference → max|Δ|=0
  (gelu2 5 shapes; moe_block2 6 shapes × ex0/ex1/ex_out/probs/y). GPU path UNCHANGED (#ifndef HEXA_CUDA, no dup
  symbol — verified). Durable landing = idempotent OP-18 post-restore patch in tool/restore_frozen_seeds (same
  mechanism as OP-17 #2996; also makes OP-16's groupnorm_gelu restorable), VERIFIED end-to-end: append on the
  frozen blob → patched runtime.c compiles clean no-CUDA (exit 0), nm all 3 symbols U→T, HEXA_CUDA excludes
  them, idempotent. Whole L3 fused-dispatch family now 0-GPU host-testable byte-eq. Verdict
  .verdicts/hexa-0pod/F-OP18-L3-FUSED-HOST.txt. $0, no GPU/pool/vast.

<!-- ANCHOR:OP-17-MACRO-REDEF (unique anchor — forge-hygiene, -Wmacro-redefined; distinct warning class from OP-5/OP-5b's -Wcomment) -->
- [x] **OP-17 — fix runtime.c -Wmacro-redefined (9 libc macros) at source, behavior-preserving (0-GPU)** —
  same forge-hygiene class as OP-5/OP-5b (which cleaned -Wcomment) but a DIFFERENT warning class
  (-Wmacro-redefined). The two colliding definition sites: (1) Darwin clang's _FORTIFY_SOURCE secure headers
  `<secure/_string.h>`/`_strings.h`/`_stdio.h` ALREADY `#define` strcat/bzero/memcpy/memset/memmove/strncpy/
  strcpy/snprintf/sprintf as `__*_chk_func` fortify macros (pulled in transitively by runtime.c's top
  `#include <string.h>`/`<strings.h>`/`<stdio.h>`); (2) self/runtime.c's "Textual override" libc-interception
  block (frozen-seed lines 2070,2082-2087,2095-2096) redefines those same 9 names to the `hxlcl_*` svc-trap
  helpers → 9 [-Wmacro-redefined]. (Only these 9 collide — the other override names strlen/memcmp/strcmp/… are
  plain externs, not macros.) MINIMAL FIX: `#undef <NAME>` the 9 names right before the override block — the
  EXACT precedent the seed already uses for `#undef isalnum`/`#undef exit` two screens down. BEHAVIOR-PRESERVING
  (PROVEN via `clang -E`): our hxlcl_* `#define` is the LAST definition either way, so the effective expansion is
  byte-identical before vs after — `#undef` only silences the warning (and is a standards no-op on Linux where
  glibc doesn't macro-define these → platform-neutral). LOCAL VERIFY (0-GPU, `clang -fsyntax-only -DHEXA_RT_SELFEMIT`):
  -Wmacro-redefined 9→0, the 2 unrelated pre-existing warning classes (4 -Wincompatible-pointer + 12
  -Wundefined-internal) UNCHANGED, 0 errors. HONEST landing (g5, OP-2b/OP-15/OP-16 class): self/runtime.c is
  gitignored frozen-seed (#2065 .c-graduation, restored from immutable blob 151c52c8… — no tracked emit SSOT), so
  the durable fix lands as a deterministic, idempotent, marker-guarded POST-RESTORE PATCH in the TRACKED
  tool/restore_frozen_seeds (injects the 9 `#undef`s on every restore) → every build env (CI/release/local
  bootstrap) gets the de-duplicated runtime.c automatically. End-to-end verified through the patched tool. 9
  warnings GONE · behavior-preserving YES · no new warn YES · GPU/pod/vast NONE ($0). Verdict
  .verdicts/hexa-0pod/F-OP17-MACRO-REDEF.txt.

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
- [x] **OP-6 — vectorize a memory-bound flame sm_120 kernel (.v4 loads/stores, bit-exact)** — generalize
  OP-1's proven memory-instruction-vectorization lever (.v4/.v2 coalesced loads + vectorized stores) from
  the compute-bound GEMM to a MEMORY-BOUND flame elementwise kernel on aiden, bit-exact. Target = the fp64
  AdamW optimizer update _hx_k_adamw_step_inplace (self/cuda/runtime_cuda.c:1236-1289) — 7 fp64 streams
  (4 read W,M,V,G + 3 write M,V,W), no reduction, scalar grid-stride loads = correct memory-bound candidate.
  CLOSED-NEGATIVE (honest, aiden RTX 5070 sm_120, GPU 0% verified): double2 (128-bit) loads/stores gave NO
  win — 1.005-1.006x @16M/64M/odd-tail (333.4->335.0 GB/s). ROOT-CAUSE probe: even a pure fp64 COPY is
  1.005x (567->570 GB/s) and an fp32 AdamW with the literal .v4 float4 lever is only 1.028x — on the 5070
  (sm_120, GDDR7) the memory controller ALREADY coalesces contiguous scalar 32/64-bit grid-stride accesses
  to peak DRAM bandwidth, so .v4/.v2 cannot raise achieved BW. OP-1 won because its GEMM had STRIDED
  partially-uncoalesced smem-feed loads to repair; a contiguous elementwise/copy kernel has none → the
  lever's premise does not transfer. BIT-EXACT (g5): vec is BYTE-IDENTICAL to scalar under --fmad=false
  (bitdiff=0, max|Δ|=0, all sizes incl odd-N tail — proves the rewrite is mathematically pure); under
  --fmad=true (production default) a 1-ULP (1.388e-17) FMA-scheduling artifact appears (different fma
  fusion in the single-elem vs pair loop), so a double2 rewrite would FAIL the OP-2 byte-eq-vs-prior-trainer
  gate. NOT shipped (no win + not byte-eq under default flags). Contiguous-elementwise vectorization lever
  EXHAUSTED on the 5070; only remaining headroom = AdamW-into-bwd-epilogue fusion (deferred OP-6b). Harness
  tool/op6/op6_adamw_vec_bench.cu + op6_bandwidth_probe.cu. Verdict .verdicts/hexa-0pod/F-OP6-VECTORIZE-KERNEL.txt.

- [x] **OP-7 — byte-eq CPU oracle for a flame math identity (0-GPU)** — in the spirit of OP-2's
  transpose-elim oracle, added a LOCAL `hexa run` (0-GPU) oracle that bit-exactly locks the flame trainer's
  FORWARD causal-dilated conv1d layout transform: the im2col+GEMM path (conv1d_via_forge) ==
  a DIRECT sliding-window conv reference, max|Δ|=0. Because the im2col col index j=ci*K+k makes the direct
  reference's (ci-outer, k-inner) accumulation order EXACTLY the j-ascending GEMM contraction order, the two
  are bit-for-bit equal (a true re-layout identity, NOT an associativity case — no tolerance). `hexa run`
  PASS, max|Δ|=0 across 5 shapes (K=3/4/5, dil=1/2/3, Cin==Cout & Cin!=Cout, zero-pad seam regime).
  Behavior-preserving: NO trainer logic changed (oracle/verification addition only). The forward companion to
  OP-2's backward-dW transpose-elim oracle. Oracle stdlib/flame/clm_prod_conv_im2col_eq.hexa · verdict
  .verdicts/hexa-0pod/F-OP7-IDENTITY-ORACLE.txt.

- [x] **OP-6b — fuse the AdamW update INTO the bwd-GEMM epilogue (boundary-removal, not vectorization)** —
  OP-6's deferred follow-up: fold _hx_k_adamw_step into the bwd dW GEMM's epilogue so dW never round-trips
  through DRAM as a separate 7-stream kernel + launch. BWD-dW PATH DETERMINED = SCOPE B (cuBLAS-bound):
  conv1d_bwd_via_forge (clm_prod.hexa:238) computes dW via forge_dispatch_matmul → farr_matmul_gpu → REAL
  cuBLAS Dgemm (runtime_cuda_emit.hexa) — a CLOSED cuBLAS call you cannot fuse an epilogue into; boundary-
  removal is only EXPRESSIBLE on an own-GEMM bwd path. CLOSED-NEGATIVE (honest, aiden RTX 5070 sm_120, GPU 0%):
  built a scope-A demonstration (fp64 tiled own-GEMM, fused gemm_dW_adamw_fused consumes dW in-register before
  the C-store + applies verbatim ADAMW_BODY, vs separate gemm_dW_store + adamw_separate = dW DRAM round-trip +
  2nd launch). PERF: ~1.000-1.002x on production-realistic GEMM-dominated shapes (dW round-trip eliminated is
  Amdahl-negligible vs the GEMM), and SLIGHTLY SLOWER 0.98x in the dW-dominated regime (large M,N tiny K) —
  the fused epilogue runs the W,M,V elementwise work under the GEMM's TILE=16 geometry at WORSE bandwidth than
  a dedicated 256-thread AdamW kernel, outweighing the ~40-70 GB/s of dW traffic saved. Fusion wins ONLY in a
  tiny-GEMM launch-bound regime (1.108x @0.02ms step) where killing the 2nd LAUNCH matters. BIT-EXACT (g5,
  STRONGER than OP-6): fused W,M,V == separate W,M,V max|Δ|=0 bitdiff=0 under BOTH --fmad=false AND --fmad=true
  at every shape — register-source fusion does NOT reschedule the AdamW FMAs (the gradient source changes,
  not the arithmetic order), so the byte-eq concern that blocked OP-6's vectorization does NOT apply. NOT
  shipped (no win + scope B cuBLAS). Boundary-removal pays only when a side is UNDER-utilized; here neither the
  bwd GEMM nor the AdamW is under-filled → nothing to recover. Elementwise lever now EXHAUSTED on BOTH axes
  (OP-6 instruction-width, OP-6b boundary-removal). Harness tool/op6b/op6b_adamw_fuse_bench.cu · verdict
  .verdicts/hexa-0pod/F-OP6B-ADAMW-FUSE.txt.
- [x] **OP-8 — byte-eq CPU oracle for a flame norm/combine identity (0-GPU)** — continuing the OP-2/OP-7
  determinism-oracle series, added a LOCAL `hexa run` (0-GPU) oracle that bit-exactly locks the flame
  CLMConvMoE MoE-router identity the FUSED hot path relies on: the trainer's two-pass softmax-gate + combine
  (nn_moe_router_fwd — full probs[T·E] buffer, THEN per-position e-ascending Σ_e probs[t,e]·ex_out[e,t,c]) ==
  a one-pass FUSED form (the HEXA_FUSE_MOE_BLOCK2 megakernel shape: inline per-position gate kept register-
  local, combine fused after, NO full-T probs DRAM round-trip), max|Δ|=0. Both use the SAME hand-rolled
  scaled-Taylor _moe_exp (NOT libm/CUDA exp), SAME max-subtraction, SAME sequential denominator, SAME
  e-ascending combine accumulation ⇒ a true fusion/ordering identity, NOT an associativity case (no tolerance).
  This LOCKS the megakernel's explicit "accumulate BOTH reductions SEQUENTIALLY, NO tree re-assoc → bit-exact"
  determinism contract. `hexa run` PASS, max|Δ|=0 across 6 shapes (E=2/3/4/8, varied T,C, + degenerate
  T=1,C=1 pure-gate edge). Behavior-preserving: NO trainer logic changed (oracle/verification addition only).
  Highest-value remaining identity (MoE combine is in the fused hot path). Oracle
  stdlib/flame/clm_prod_moe_combine_eq.hexa · verdict .verdicts/hexa-0pod/F-OP8-IDENTITY-ORACLE.txt.

- [x] **OP-9 — byte-eq CPU oracle for the groupnorm/LN valley reduction (0-GPU)** — continuing the
  OP-2/OP-7/OP-8 determinism-oracle series, added a LOCAL `hexa run` (0-GPU) oracle that bit-exactly locks the
  flame CLMConvMoE GroupNorm "valley" normalization the FUSED hot path (HEXA_FUSE_VALLEY / HEXA_FUSE_GN_GELU)
  relies on. The production reduction (gn_lib nn_groupnorm_fwd / nn_gn_gelu_fused) is a TWO-PASS mean/variance
  (NOT Welford): pass-1 sum=Σ X → mu, pass-2 vs=Σ(X-mu)² → var, both over the SAME (t-OUTER,c-INNER) order
  (sequential, NO tree re-assoc); inv=1/_gn_sqrt(var+eps), eps=1e-5; Y=gamma·xhat+beta; A=GELU(Y) (erf CDF).
  OP-9 proves the UN-FUSED form (nn_groupnorm_fwd: two-pass reduction + SEPARATE affine sweep writing Y, THEN
  SEPARATE GELU sweep re-reading Y → A) == the FUSED VALLEY form (nn_gn_gelu_fused: SAME reduction, but affine
  +GELU in ONE pass — post-GN [T·C] touched ONCE, no Y read+write round-trip), max(|ΔY|,|ΔA|)=0. Both use the
  SAME two-pass (t-outer,c-inner) reduction order, SAME _gn_sqrt (40-iter Newton), SAME erf-GELU ⇒ a true
  fusion/boundary-removal identity, NOT an associativity case (no tolerance). HONEST (g5): the tree-vs-
  sequential associativity RISK is REAL but does NOT arise — the fusion only collapses the GN-affine+GELU
  elementwise sweeps, it does NOT re-associate the mean/var sum, so the CPU oracle matches the production
  sequential order EXACTLY → genuine max|Δ|=0, no eps. CANONICAL ORDER = sequential (t-outer,c-inner) two-pass
  mean-then-var (device kernel = SSOT); a future warp-shuffle/tree reduce or Welford switch would trip this
  oracle. `hexa run` PASS, max|Δ|=0 across 7 shapes (G=1 LN-degenerate, G=2/3/4/8, varied T,C, + T=1 pure
  cross-channel + cg=1 per-channel edges). Behavior-preserving: NO trainer logic changed. Oracle
  stdlib/flame/clm_prod_ln_reduction_eq.hexa · verdict .verdicts/hexa-0pod/F-OP9-LN-REDUCTION-ORACLE.txt.

<!-- ANCHOR:OP-10-CONV-SEAM (unique anchor — OP-9 edits a different anchor) -->
- [x] **OP-10 — CPU oracle characterizing the B>1 causal-conv window-concat seam (0-GPU)** — made the
  flame_h100_h200_closeout's KNOWN honest non-bit-exact spot PRECISE. The flame batched step
  (CLM_PROD_BATCH=B) concatenates B distinct length-Tw windows into ONE length-T=B*Tw buffer and runs the
  causal-dilated Conv1d over the whole thing; the closeout flagged a "K-1 causal-conv SEAM-only Δ" vs a
  per-window-segmented conv. This LOCAL `hexa run` (0-GPU) oracle computes BOTH paths on CPU — (a) the
  flame concat conv (every previous-window row visible to the receptive field p=t-dil*(K-1-k)) vs (b) a
  per-window-segmented reference that zeros the cross-window causal context — and maps Δ per output
  position. FINDING (g5, honest CHARACTERIZATION not max|Δ|=0-everywhere): the INTERIOR is bit-exact
  (interior max|Δ|=0, 0 bad positions across 6 cases) and the SEAM is EXACTLY the first (K-1)*dil output
  positions of every window AFTER the first, where Δ = the cross-window context the segmented form zeros
  (genuinely nonzero, 0 mischaracterized). CONFIRMS the closeout claim and REFINES it: dil=1 ⇒ band=K-1
  (the named case); dil>1 ⇒ band=(K-1)*dil (the trunk's dilated convs widen the seam — the closeout said a
  flat "K-1"). Seam magnitudes ~0.03–0.38 (LCG fixture). Behavior-preserving: NO trainer logic changed
  (characterization addition only). Oracle stdlib/flame/clm_conv_window_seam_eq.hexa · verdict
  .verdicts/hexa-0pod/F-OP10-CONV-SEAM-ORACLE.txt.

<!-- ANCHOR:OP-11-CE-SOFTMAX-GRAD (unique anchor — OP-10 edits a different anchor) -->
- [x] **OP-11 — byte-eq CPU oracle for the CE loss + softmax-gradient identity (0-GPU)** — continuing the
  OP-2/OP-7/OP-8/OP-9 determinism-oracle series, added a LOCAL `hexa run` (0-GPU) oracle that bit-exactly locks
  the flame CLMConvMoE LOSS path — the flame_h100_h200_closeout-flagged "CE/softmax-grad host glue". Locks TWO
  independent identities, each replaying its OWN production exp impl (the subtle hazard: the two CE entry points
  use DIFFERENT exp — a refactor that "unifies" them would silently break byte-eq):
  (A) the CE+softmax FUSED-GRADIENT identity dL/dlogits == (softmax(logits) − onehot(target))/T — production
  clm_ce_grad (clm_prod.hexa:919, libm `exp`, per-row max-sub, v-ascending denom, p·invT then −invT at target)
  == a definitional reference that materializes the full softmax row then forms (softmax−onehot)/T. max|Δ|=0
  across 6 shapes (V=7..256 CLM-scale, varied T, T=1 edge). (B) the FORWARD mean-NLL loss scalar — production
  nn_ce_loss_allpos (nn_lib.hexa:957, `dt_exp`/`dt_ln` flame_math Taylor — NOT libm, NOT _moe_exp; p_t clamp
  ≥1e-6; t-ascending sum) == a definitional reference materializing the normalized row then reading p[tgt].
  |Δ|=0 across the same 6 shapes. HONEST (g5) — REAL associativity finding, documented + resolved: the target
  index is float-sensitive — production writes (p·invT) for all v THEN subtracts invT at tgt, giving
  (p_tgt·invT)−invT, which is float-DIFFERENT from a fused (p_tgt−1)·invT (observed max|Δ|≈1.39e-17 at T12/V7
  before the fix). The oracle's reference replays the EXACT production op order (scale-then-subtract, NOT
  algebraically refold) ⇒ genuine max|Δ|=0, no eps. CANONICAL ORDER (SSOT): BWD = libm exp, per-row max-sub,
  v-ascending denom, grad=p/T then tgt−=1/T (clm_prod.hexa:933-937 = SSOT); FWD = dt_exp/dt_ln, v-ascending
  denom, ≥1e-6 clamp, t-ascending loss sum, mean/T. Behavior-preserving: NO trainer logic changed (oracle
  addition only). Oracle stdlib/flame/clm_prod_ce_softmax_grad_eq.hexa · verdict
  .verdicts/hexa-0pod/F-OP11-CE-SOFTMAX-ORACLE.txt.

<!-- OP-13-EMBED-RESIDUAL -->
- [x] **OP-13 — byte-eq CPU oracle for the embedding/residual path identity (0-GPU)** — extends the
  OP-2/7/8/9/10/11 determinism-oracle series to the previously-unlocked INPUT path: the backward of the
  token-embedding gather (nn_lib.hexa nn_embedding_bwd_scatter). When repeated tokens share a row, each
  position's gradient ACCUMULATES into the same dtable row, and float-addition non-associativity makes the
  accumulation ORDER load-bearing — the classic determinism trap. Production order = POSITION-ASCENDING
  (i=0..T-1 in-place scatter-add). LOCAL `hexa run` (0-GPU) oracle bit-exactly LOCKS that order: REF (exact
  mirror of nn_embedding_bwd_scatter, i-ascending in-place, pre-seeded with a tied-head term to cover the
  d5_grad accumulate-onto-existing case) == GROUPED+ (per-row reformulation summing each row's positions
  i-ASCENDING) ⇒ GATE max|Δ|=0 across 6 shapes (T8..32, V3..8, d3..8, ALL with repeats — max-repeat up to
  12 positions sharing one row; + degenerate T=1). HONEST (g5): a deliberately non-canonical GROUPED-
  (i-DESCENDING) reorder DIVERGES by an FP eps (5.68e-14 … 4.55e-13) on repeated-token rows (0.0 on T=1, no
  repeats) — the genuine non-associativity witness proving the production i-ascending order is the canonical
  SSOT and that a future gather-then-grouped-sum / GPU atomic-scatter refactor MUST preserve it. GATE eps
  NOT faked (=0 is a true reorder identity). Behavior-preserving: NO trainer logic changed (oracle/verification
  addition only). $0 — pure local CPU. Oracle stdlib/flame/clm_prod_embed_scatter_eq.hexa · verdict
  .verdicts/hexa-0pod/F-OP13-EMBED-RESIDUAL-ORACLE.txt.

<!-- ANCHOR:OP-12-ADAMW-UPDATE (unique anchor — OP-11 edits a different anchor) -->
- [x] **OP-12 — byte-eq CPU oracle for the AdamW update arithmetic identity (0-GPU)** — continuing the
  OP-2/OP-7/OP-8/OP-9/OP-10/OP-11 determinism-oracle series, added a LOCAL `hexa run` (0-GPU) oracle that
  bit-exactly locks the flame AdamW optimizer decoupled-wd UPDATE-arithmetic identity. OP-6/OP-6b touched
  the AdamW kernel for PERF (fuse into the bwd-GEMM epilogue) but NEVER oracle-locked the UPDATE MATH itself.
  PRODUCTION SSOT = _hx_farr_adamw_step_cpu (self/runtime.c:10783), byte-eq twin of the CUDA _hx_k_adamw_step
  (self/cuda/runtime_cuda.c:1236). PROD (replays the SSOT op order VERBATIM) == REF (a clean Loshchilov-2017
  AdamW update written to MATCH the production associativity), max|Δ|=0 over the FULL state transition (W AND
  the in-place optimizer state m,v) across 7 configs sweeping every knob — lr∈{3e-4..1e-2}, β1∈{.8,.9,.95},
  β2∈{.99..​.9999}, ε∈{0,1e-8,1e-7,1e-6}, wd∈{0,.01,.05,.1}, step_t∈{1,3,5,10,50,100}, n∈{1,64,96,128,200}
  (incl. t=1 max-bias-corr, t=100 late, ε=0, wd=0, n=1 edge). SQRT: held CONSTANT across both forms — both
  call the SAME 24-iter Newton _adamw_sqrt (flame_math dt_sqrt / gn_lib _gn_sqrt discipline; the SSOT's libm
  `sqrt` has no `hexa run` float surface and its own comment pins dt_sqrt ≡ the same double) so the lock
  ISOLATES the update ORDER; ε is OUTSIDE the √ (denom = √v̂ + ε) in BOTH the SSOT and the oracle.
  HONEST (g5) — REAL associativity finding, found + RESOLVED (no faked max|Δ|=0): a first REF that grouped
  the squared-grad term as the natural `(1−β2)·(g·g)` diverged ≤8.88e-16 (1.11e-16 across most cases); the
  production writes `(1−β2)·g·g` = LEFT-assoc `((1−β2)·g)·g`, a DIFFERENT double — exactly the contract OP-12
  pins. Replaying that exact grouping (production order = SSOT, NOT an algebraic refold) ⇒ genuine max|Δ|=0,
  no eps. CANONICAL ORDER (SSOT, runtime.c:10819-10830): v=(β2·v)+(((1−β2)·g)·g); m=(β1·m)+((1−β1)·g); m̂=m/c1
  BEFORE v̂=v/c2; denom=√v̂+ε (ε OUTSIDE √); W'=((W−lr·wd·W)−lr·(m̂/denom)) (two separate subtractions,
  decoupled-wd first); c1,c2=1−βᵗ with βᵗ by repeated-mul (not pow). `hexa run` PASS, max|Δ|=0 all 7 cases.
  Behavior-preserving: NO trainer logic changed (oracle addition only). Oracle
  stdlib/flame/clm_prod_adamw_update_eq.hexa · verdict .verdicts/hexa-0pod/F-OP12-ADAMW-UPDATE-ORACLE.txt.

<!-- ANCHOR:OP-14-DETERMINISM-DOC (unique anchor — distinct from OP-13/OP-11/OP-10) -->
- [x] **OP-14 — flame determinism-contract doc consolidating the byte-eq oracle invariants (0-GPU)** —
  consolidated the HEXA-0POD byte-eq oracle findings into ONE contributor-facing doc,
  docs/flame-determinism-contract.md, making flame's reproducibility-first identity legible. Indexes 8
  verdicts (F-OP2 transpose-elim · F-OP7 fwd conv im2col · F-OP8 MoE softmax+combine · F-OP9 GroupNorm valley ·
  F-OP10 B>1 conv seam · F-OP11 CE bwd+fwd · F-OP12 AdamW update · F-OP13 embedding scatter-add) as a per-phase table (phase → oracle
  → CANONICAL ORDER → what-breaks-it) + ASCII step-phase map. LEADS with the cross-cutting rule: THREE distinct
  exp impls each load-bearing (libm `exp` = CE bwd · `dt_exp` = CE fwd · `_moe_exp` = MoE softmax — a "unify the
  exp" refactor silently breaks byte-eq); reductions SEQUENTIAL (no tree/Welford); accumulations ASCENDING
  (softmax denom v-asc · MoE combine e-asc · CE fwd loss t-asc · embed scatter position-asc · GroupNorm
  (t-out,c-in) · conv/GEMM j-asc). Documents the one known-nonzero spot (B>1 conv seam = first (K-1)·dil
  positions, interior bit-exact) + a "how to add a new oracle" pointer. One-line determinism pointer added to
  docs/hexa-dojo.md (Training-recipe section). Doc-consolidation milestone — value = the byte-eq contract made
  legible, NOT new computation; every canonical-order claim traces to a specific verdict line (g5). $0, 0-GPU,
  no pool/vast. Verdict .verdicts/hexa-0pod/F-OP14-DETERMINISM-DOC.txt.

<!-- ANCHOR:OP-15-STEP-DETERMINISM (unique anchor — distinct from OP-14/OP-13/OP-11) -->
- [x] **OP-15 — integration byte-eq oracle: whole micro-step byte-identical run-to-run (0-GPU)** —
  COMPOSITION-level reproducibility proof the per-op oracles (OP-2/7/8/9/10/11/12/13) cannot give. New CPU
  oracle stdlib/flame/clm_step_determinism_eq.hexa runs the EXACT flame CLMConvMoE micro-step from
  clm_step.hexa main() — embed → conv → GroupNorm → MoE → CE loss → backward → AdamW over ALL 17 params —
  TWICE from the SAME fixed-LCG-seed init, then asserts max|Δ|=0 over every post-step W, every optimizer m,
  every v, AND the loss scalar. RESULT (`hexa run`, 0-GPU): loss 4.81916 both runs; max|Δ(W)|=0, max|Δ(m)|=0,
  max|Δ(v)|=0, |Δloss|=0 → BYTE-IDENTICAL run-to-run. The composed step + its state threading (cache buffers,
  m/v carry, deterministic init) has NO composition-determinism hole (no uninit scratch, no non-det iteration,
  no address-dependent ordering). Comparator sensitivity verified by negative control (distinct-seed tensors →
  max|Δ|=0.344217; identical → 0.0) so the 0.0 is a genuine byte-eq pass, not a self-alias. Imports the
  cleanly-linking prod libs (conv/moe/nn/optim) DIRECTLY and inlines ONLY GroupNorm fwd/bwd byte-eq (gn_lib's
  nn_gn_gelu_fused_off pulls the GPU forge symbol forge_dispatch_groupnorm_gelu, host-undefined on the 0-GPU
  link path → can't import gn_lib locally; the unfused CPU GN is the prod reference path anyway). Behavior-
  preserving — oracle addition only, NO trainer logic changed. $0, 0-GPU, no pool/vast. Verdict
  .verdicts/hexa-0pod/F-OP15-STEP-DETERMINISM.txt.

<!-- ANCHOR:OP-16-GN-HOST-FALLBACK (unique anchor — closes the OP-15 0-GPU link blind spot) -->
- [x] **OP-16 — gn_lib host fallback so the fused-valley GN+GELU path is 0-GPU hexa-run-testable** — closes
  the determinism-test blind spot OP-15 (#2994) found: a `hexa run` harness that `use`s gn_lib FAILED TO LINK
  off no-CUDA (undefined `forge_dispatch_groupnorm_gelu` — gn_lib's nn_gn_gelu_fused_off references the GPU
  forge symbol, host-undefined off-CUDA; the whole L3 fused-dispatch family is supplied only by the GPU build's
  fusion_dispatch.c glue). WROTE the missing HOST twin: an `#ifndef HEXA_CUDA` body for the BARE symbol in
  self/runtime.c that computes the SAME unfused GN+GELU in the SAME canonical order (two-pass mean/var
  t-outer/c-inner, eps=1e-5 var+eps, 40-iter Newton _gn_sqrt, erf-GELU) — OP-9 (#2987) already proved
  unfused==fused (max|Δ|=0), so this host body IS the byte-correct fused dispatch. `#ifndef HEXA_CUDA` guard ⇒
  GPU dispatch path UNCHANGED (no duplicate symbol with fusion_dispatch.c). BYTE-EQ CURE (the one non-obvious
  finding): naïve C body diverged ~3.55e-15 (1 ULP) because clang -O2 FMA-contracts gamma*xhat+beta but hexa
  codegen does NOT — wrapping the body in `#pragma STDC FP_CONTRACT OFF` (the proven ag_tape recipe in the same
  TU) drops max|Δ| to EXACTLY 0. PROVEN locally (0-GPU): rebuilt runtime.o (pure `clang -O2 -c`), `nm` shows
  `_forge_dispatch_groupnorm_gelu` flipped U→T (defined); flame_gn_gelu_fused_test.hexa (use's gn_lib) LINKS +
  PASSES max_abs_diff=0; new tracked oracle stdlib/flame/clm_prod_gn_gelu_hostdispatch_eq.hexa drives the FUSED
  entry point THROUGH the host dispatch (env-gated) vs the unfused OP-9 reference → max|Δ|=0 on Y,A,mean,inv,
  xhat across 7 shapes. HONEST landing (g5, OP-2b-class): self/runtime.c is gitignored frozen-seed (#2065
  `.c-graduation`, no tracked emit SSOT for the forge dispatchers), so the C BODY lands via a runtime rebuild
  in the release/build env (verbatim body + exact one-rebuild fix documented in the verdict); the byte-eq
  oracle + milestone + verdict ship now (tracked). links-now YES · byte-eq max|Δ|=0 · GPU untouched YES. $0,
  0-GPU, no pool/vast. Oracle stdlib/flame/clm_prod_gn_gelu_hostdispatch_eq.hexa · verdict
  .verdicts/hexa-0pod/F-OP16-GN-HOST-FALLBACK.txt.

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

- **OP-19b — close the GELU libm-`erf` cross-platform hole with a deterministic erf (numeric change).**
  F-OP19 (OP-19) closed CE-bwd's libm `exp` but MEASURED the GELU path (nn_gelu_fwd/_gn_gelu fwd +
  nn_gelu_bwd) still calls libm `erf` (fwd) and libm `erf`+`exp` (bwd) — the same arch/OS divergence kind. Not
  closed because no bit-accurate deterministic erf exists in-tree (core/special.hexa erf_fn = A&S 7.1.26
  ~1.5e-7-off AND itself libm-exp-dependent) so it needs a genuine deterministic erf impl (a numeric change,
  larger than ULP), AND `erf`/hexa_math_erf is too new to LINK on aiden's prebuilt runtime.a (so the pool
  cross-platform measure needs a runtime rebuild or a newer pool host). Build a deterministic dt_erf (e.g. a
  Taylor/continued-fraction erf on dt_exp), swap GELU fwd+bwd (host + GPU kernel), re-lock OP-9's GN+GELU
  oracle to the new erf, document the grad-change magnitude. The OP-19 oracle already has a dt_erf swap-test
  proving a deterministic erf gives byte-identical folds locally — this milestone makes it production + a
  numeric decision.

- **OP-5c — forge error-path / dtype-edge / determinism hardening (NEEDS GPU — deferred out of 0-GPU scope).**
  The robustness improvements OP-5 originally listed (error paths, dtype edge cases, determinism guards in the
  forge runtime) cannot be gated byte-eq without running a kernel; they belong to a GPU round (aiden 5070), not
  this 0-pod pass. Logged here so the loop doesn't re-attempt them as "0-GPU".
## honest framing (g5)

Free-resource-only loop: every gate runs on the sidecar pool (aiden/summer 5070) or locally — NO vast cost.
Bit-exact / byte-eq discipline holds (the consumer card preserves flame's identity). When a milestone genuinely
needs a Hopper H100 (sm_90a wgmma), it is DEFERRED here (out of 0-pod scope), not faked. The loop drains this
backlog and self-feeds new 0-pod milestones as they surface.
