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
