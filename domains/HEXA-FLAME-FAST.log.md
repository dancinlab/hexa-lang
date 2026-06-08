# HEXA-FLAME-FAST — log

## 2026-06-08 — domain registered (after the ~3x campaign + an honest correction)

User pushed back (correctly) on an earlier overstatement that "compiling the whole flame step = months-long
engine rewrite → flame becomes PyTorch → loses no-LLVM/byte-exact identity." That was WRONG. hexa already
native-compiles (no LLVM); whole-step fusion is a kernel-authoring task; compiling preserves byte-exactness
with a fixed accumulation order (FF-GN-PARALLEL #2931 + FF-EPILOGUE #2928 proved it). The whole-step
megakernel (#2924) was blocked by a HARDWARE fact — FP64 too big to fit one cooperative wave at batch=1
(occupancy), NOT by an engine-rewrite cost or identity loss.

So the genuinely-untested lever = the SAME whole-step fusion at TF32/BF16 (fits occupancy) + batch>1 (fills
SMs). The three levers were only ever tested SEPARATELY (#2924 fusion-FP64, #2917 precision, #2913 batch);
combining them is new. Registered FAST-1 (occupancy probe) -> FAST-2 (fused TF32 megakernel) -> FAST-3 (+batch,
the decisive ~3x test) -> FAST-4 (opt-in wiring, identity guard) -> FAST-5 (vs-PyTorch if FAST-3 wins). GPU 0
at registration; NOT attempted. flame's FP64 byte-exact identity is the protected default; FAST is opt-in/additive.
Related: commons g85 (~3x cap = host-glue idle) + reference_megastep_research + F-FUSION-FF-DUTYCYCLE.

## 2026-06-08 — FAST-1 occupancy headroom probe 🟢 GREENLIGHT FAST-2

Real H100 80GB HBM3 (132 SMs, cc9.0, cooperativeLaunch=1) — vast 39991563, tag hexa-fast1, DESTROYED leak-0.
Probe = tool/fast1/fast1_occupancy.cu: representative whole-step fused megakernel (own-GEMM tile inline +
groupnorm/gelu glue device-resident across grid.sync) built at FP64/TF32/BF16 differing ONLY in GEMM
footprint; cudaOccupancyMaxActiveBlocksPerMultiprocessor + cudaFuncGetAttributes + ptxas -v. flame D1536/T512.

VERBATIM:
  maxActiveBlocksPerSM   FP64=4   TF32=4   BF16=4   (RISE = NO)
  footprint/CTA          FP64 regs=52 smem=32768B | TF32 regs=46 smem=16384B | BF16 regs=46 smem=8192B
  smem halving           FP64->TF32 2.00x, FP64->BF16 4.00x  (CONFIRMED)
  one-wave FIT @batch=1  FP64=YES  TF32=YES  BF16=YES  (gridNeed 48/192 << 528-CTA ceiling)
  wgmma co-residence @TF32 = YES (blockDim=128 wmma-issuable)
  GATE: FAST-2 GREENLIGHT.

The two #2924 structural blockers DISSOLVE at TF32/BF16: footprint halves, and the TF32 GEMM at blockDim=128
is wmma-issuable so it co-resides with the glue in one cooperative grid (no grid.sync deadlock). HONEST g5
nuance: occupancy did NOT rise (4=4=4) — at batch=1 footprint was non-binding; the #2924 wall was UNDER-FILL
(48 CTAs << 528 one-wave capacity), NOT footprint-oversubscription. Even FP64 fits one wave here. So FAST-2 is
admissible (kernel launches + co-resides — corroborated by F-FUSION-P1-TF32-MEGASTEP which DID fire a TF32 coop
megakernel grid=752 blk=128); the footprint-halving payoff is for FAST-3 batch>1 (keeps the bigger grid fitting
one wave — ~11x GEMM-phase batch headroom before the 528 ceiling binds). Verdict: .verdicts/hexa-flame-fast/
F-FAST-1-OCCUPANCY.txt. 3 vast rentals: 39981994 (proxy-SSH dead) + 39986764 (key-injection broken) both
DESTROYED leak-0 before harvest; 39991563 harvested via bare-hostname SSH (config id_vast_anima) then DESTROYED.

## 2026-06-08 — FAST-2 🟢 GREEN: fused whole-step megakernel @ TF32/BF16 (real H100)

Authored the #2924-style whole-train-step uberkernel at the GPU-fitting precision FAST-1
greenlit. ONE persistent cooperative kernel (tool/fast2/fast2_fused_step.cu): PHASE0 fwd
conv-GEMM (wmma own-GEMM) → PHASE1 FF-VALLEY gelu glue → PHASE2 atomic-free bwd dW=A^T@dG
(fixed K order) → PHASE3 FF-FUSED-OPTIM AdamW, all device-resident across grid.sync(), NO
atomics. + same-dtype separate-kernel reference in the same binary. env HEXA_FLAME_FAST.

Build fix: wmma::precision::tf32 is an INCOMPLETE fragment-operand tag, not a storage type —
split store_t (float for TF32, __nv_bfloat16 for BF16) from the ab_t fragment tag; TF32
operands stored as float + converted at load via __float_to_tf32. Builds clean both dtypes.

Real H100 80GB HBM3 (vast 39996767, tag hexa-fast2), flame D1536 T512 batch=1, iters=50:
  CO-RESIDENCE  TF32+BF16: cudaLaunchCooperativeKernel launched=YES completed=YES (no deadlock)
  CORRECTNESS   rel-RMS(W' fused vs separate, same dtype) = 0.0 exactly  (gate<=1e-2 PASS) — TF32 + BF16
  DETERMINISM   run-to-run max|d|(fused W') = 0.0 exactly  (gate==0 PASS) — TF32 + BF16
  MEASURE       TF32 fused 1.8134 vs separate 1.8067 ms/step (0.996x); BF16 1.5483 vs 1.5456 (0.998x)
                fused grid=528 = full one-wave (maxActiveBlocks 4*132); occ-proxy 100%

FAST-2 DELIVERABLE COMPLETE: kernel BUILDS + CO-RESIDES (empirical) + CORRECT + DETERMINISTIC.
batch=1 wall flat ~1.00x EXACTLY as FAST-1 predicted (under-fill / serial-DAG idle floor, not
footprint). The ~3x break is FAST-3's batch>1 — this verified kernel is its substrate (store_t/ab_t
split makes TF32+BF16 first-class; baseline harness already wired, just vary M=B*T).

Pod 39996767 (tag hexa-fast2 confirmed) DESTROYED, leak 0. PR base main.
