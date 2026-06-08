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

## 2026-06-08 — FAST-3 batch sweep 🔴 CLOSED-NEGATIVE: ~3x cap SURVIVES the full 3-combo (TERMINAL)

THE DECISIVE TEST. Ran FAST-2's verified fused whole-step megakernel (TF32 AND BF16, kernel math verbatim)
across batch B=1,2,4,8,16,32 (M=B*T) on a real H100 80GB HBM3 (vast 40003012, tag hexa-fast3, DESTROYED
leak-0, tag-confirmed). flame step D=1536 T=512, 50 iters/B. Verdict: F-FAST-3-BATCH.txt.

DOES fused × TF32/BF16 × batch>1 BREAK ~3x?  ==> NO. Full-step fused-vs-separate SELF-speedup is FLAT
~1.00x at EVERY batch (TF32 0.995–1.019x · BF16 0.996–1.025x). It never even reaches ~3x. The #2913 ~3x
batch-fill cap SURVIVES the full 3-lever combination → ~3x is TERMINAL for the kernel-fusion axis.

Gates held perfectly where they could: CORRECTNESS rel-RMS=0.0e+00 at every B both dtypes (pure structural
transform, fixed accum order); DETERMINISM run-to-run max|Δ|=0.0e+00 at every B (atomic-free) — NO B>1 seam.
ONE-WAVE-FIT=NO already at B=1: the bwd GEMM gridNeed=K*N tiles=9216 ≫ 528 one-wave ceiling and is FIXED in
B → the megakernel never fits one cooperative wave at the real flame size; it grid-strides 6→187 waves.
FAST-1's "~11x batch headroom before 528 binds" is REFUTED for the real flame step (the bwd tile count, not
batch, blows the ceiling).

ROOT CAUSE (honest, g5): the hypothesis assumed an 86.8% between-op host-glue idle gap for fusion to fill.
THAT GAP IS ABSENT in a device-resident separate baseline — 5 back-to-back grid-stride kernels, no host glue,
each already saturating the H100 (util ~97-98% from B=1, mean≈median, never ~0%). With no idle valley, fusion
only trades ~5 kernel launches for ~5 grid.sync barriers (a wash) → ~1.00x is the CORRECT result for a
saturated DAG. Batch>1 scales work linearly (ms ∝ B); no under-fill existed to relax. The #2913 ~3x was an
INTERPRETER-glue artifact (t_get/t_set + eager AdamW), which neither path here pays. % of ~1656x torch gap
closed by FAST-3 = 0%.

flame identity INTACT and never at stake (byte-exact rel-RMS 0 · no-LLVM · deterministic-at-dtype ·
theorem-cite); FAST is purely additive — this fusion's additive value is ~0 at the saturated regime. CAMPAIGN
CONCLUSION: kernel-fusion is EXHAUSTED on this axis; the real remaining lever is INTERPRETER-ELIMINATION
(native step) + batch>1 at the eager boundary (per reference_megastep_research + flame_h100_h200_closeout),
NOT GPU kernel fusion. FAST-4/FAST-5 are moot for breaking ~3x (FAST-5 was gated on FAST-3 winning).
