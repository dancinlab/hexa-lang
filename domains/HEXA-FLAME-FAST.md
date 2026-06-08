# HEXA-FLAME-FAST

@title: 🏎️ HEXA-FLAME-FAST — flame 학습 step 고속화 (정체성 유지)

@goal: Break the ~3x flame CLMConvMoE full-step self-speedup cap by COMPILING the whole train step into ONE
fused native kernel at a GPU-FITTING precision (TF32/BF16) + batch>1 — the three levers tested only
SEPARATELY so far. Crucially this is OPT-IN: FP64 byte-exact stays the canonical default; FAST is an added
lane. flame's identity (no-LLVM native compile · deterministic/reproducible at the chosen dtype · theorem-cite)
is PRESERVED — compiling does NOT make flame into PyTorch.


## 🔴 DOMAIN CLOSED-NEGATIVE (2026-06-08) — ~3x is TERMINAL on the kernel-fusion axis

The 3-way combo fused x TF32/BF16 x batch>1 (FAST-3 #2936, real H100) delivers FLAT ~1.00x full-step
self-speedup vs the device-resident separate-kernel baseline at every B=1..32, both dtypes (rel-RMS 0,
run-to-run max|d|=0 — correct + deterministic, identity intact). It NEVER reaches ~3x, let alone breaks it.
ROOT CAUSE (g5): the hypothesis assumed an 86.8%% host-glue idle valley for fusion to fill, but that valley
is ABSENT in a device-resident separate baseline (5 back-to-back grid-stride kernels, already ~97-98%% util
from B=1, no host glue). Fusion just trades ~5 launches for ~5 grid.syncs = a wash. FAST-1's '~11x batch
headroom' was REFUTED: the bwd-GEMM gridNeed (K*N tiles = 9216) is FIXED in B and blows the 528 one-wave
ceiling already at B=1 (tile count, not batch). The #2913 ~3x was an INTERPRETER-glue artifact neither
device-resident path pays. => kernel fusion EXHAUSTED for breaking ~3x; cap TERMINAL on this axis. flame
identity (byte-exact/no-LLVM/deterministic/theorem-cite) intact. FAST-4 (opt-in wiring) MOOT (no speedup to
wire); FAST-5 (vs-PyTorch) N/A (conditional on a break that didn't happen). The 3 levers were genuinely
measured TOGETHER for the first time — an honest closed-negative, not a skipped lever.

## the corrected understanding (g5, supersedes an earlier overstatement)

⚠ CORRECTION logged: an earlier claim — "compiling the whole step = months-long engine rewrite that turns
flame into PyTorch and loses the no-LLVM/byte-exact identity" — was WRONG/overstated. Facts: (a) hexa ALREADY
native-compiles (CC-NATIVE AOT C-backend, no LLVM) — whole-step fusion is a KERNEL-AUTHORING task (days),
NOT a language-engine rebuild. (b) Compiling preserves byte-exactness with a fixed accumulation order (proven
by FF-GN-PARALLEL #2931 + FF-EPILOGUE #2928, both byte-eq under -fmad=false). (c) theorem-cite is a
source/lint-stage feature, independent of whether the runtime interprets or compiles. So "just compile it" is
CORRECT and identity-safe. What ACTUALLY blocked the whole-step megakernel was a HARDWARE fact: F-FUSION-MEGASTEP
(#2924) ran it in FP64, which is too big to fit one cooperative-grid wave at batch=1 (occupancy wall). The
genuinely-UNTESTED fix = the SAME fusion at TF32/BF16 (smaller footprint → fits occupancy) + batch>1 (fills SMs).

## what's been tested SEPARATELY (and why each alone failed)

- 🔴 whole-step fusion in FP64 (#2924 MEGASTEP) — occupancy wall (FP64 too big @ batch=1)
- 🔴 precision-change TF32/BF16 alone (#2917) — ~1.02x (GEMM wasn't the wall; no fusion to remove the gap)
- 🟢 batch-fill alone (#2913) — ~3x but capped (interpreted glue grows ∝ B; gaps remain)
- ⇒ NEVER tried: fusion × low-precision × batch>1 TOGETHER. That is this domain.

## milestones

- [x] **FAST-1 — TF32/BF16 occupancy headroom probe (does the wall relax?)** — 🟢 GREENLIGHT FAST-2 (real
  H100 80GB HBM3, vast 39991563 tag hexa-fast1 DESTROYED leak-0; verdict F-FAST-1-OCCUPANCY.txt). Footprint
  HALVING confirmed (smem/CTA FP64 32768B → TF32 16384B = 2.00x, BF16 8192B = 4.00x; regs 52→46). wgmma
  co-residence @TF32 = YES (blockDim=128 wmma-issuable → the #2924 "blockDim<128 can't issue wgmma + grid.sync
  deadlock" blocker DISSOLVES). One-wave FIT @batch=1 = YES all 3 dtypes (gridNeed 48 TF32/BF16 ≪ 528-CTA
  one-wave ceiling). HONEST nuance: maxActiveBlocksPerSM did NOT rise (4=4=4) — at batch=1 the footprint was
  NOT the binding limit; the #2924 wall was UNDER-FILL (too few CTAs, 48≪528), not footprint-oversubscription.
  So FAST-2 is admissible (kernel fits + wgmma co-resides), but the footprint-halving payoff is for FAST-3
  batch>1 (keeps the bigger grid fitting one wave; ~11x batch headroom before the one-wave ceiling binds).
- [x] **FAST-2 — fused whole-step megakernel at TF32/BF16** — 🟢 GREEN (real H100 80GB HBM3, vast 39996767
  tag hexa-fast2 DESTROYED leak-0; verdict F-FAST-2-FUSED-TF32.txt, tool/fast2/fast2_fused_step.cu). Authored
  the #2924-style whole-train-step uberkernel (fwd conv-GEMM + FF-VALLEY glue + atomic-free bwd + FF-FUSED-OPTIM
  AdamW) as ONE persistent cooperative kernel at BOTH TF32 and BF16. All 3 g5 gates PASS both dtypes:
  CO-RESIDENCE=YES (cudaLaunchCooperativeKernel launched+completed, NO grid.sync deadlock — FAST-1's prediction
  now EMPIRICALLY witnessed by a running fused step, not just an occupancy-API forecast); CORRECTNESS rel-RMS=0
  (exactly, vs same-dtype separate-kernel step — fusion is a pure structural transform, identical fixed accum
  order; W14 gate <=1e-2); DETERMINISM run-to-run max|d|=0 (atomic-free + fixed-order). MEASURE batch=1: fused
  vs separate flat (TF32 0.996x @1.81ms/step, BF16 0.998x @1.55ms/step) — EXPECTED (batch=1 under-fills, the
  serial-DAG idle floor dominates; ~3x break is FAST-3's batch>1 job). The verified kernel is the FAST-3 substrate.
- [x] **FAST-3 — + batch>1 (the genuinely-untested 3-way combo)** — 🔴 CLOSED-NEGATIVE (real H100 80GB HBM3,
  vast 40003012 tag hexa-fast3 DESTROYED leak-0; verdict F-FAST-3-BATCH.txt, tool/fast3/fast3_batch_sweep.cu).
  Ran FAST-2's fused-TF32 AND BF16 megakernel across B=1,2,4,8,16,32 (M=B*T). DECISIVE NUMBER: fused-vs-separate
  full-step self-speedup is FLAT ~1.00x at EVERY batch (TF32 0.995–1.019x · BF16 0.996–1.025x). DOES IT BREAK
  ~3x? **NO** — it never even reaches ~3x. The ~3x batch-fill cap (#2913) SURVIVES the full 3-lever combo →
  ~3x is TERMINAL for the kernel-fusion axis. Gates 1+2 held perfectly: rel-RMS=0 + determinism max|Δ|=0 at
  every B both dtypes (no seam); one-wave-FIT=NO already at B=1 (bwd GEMM gridNeed=9216 ≫ 528 ceiling, fixed
  in B → FAST-1's "~11x batch headroom" REFUTED for the real flame step). ROOT CAUSE (honest): no 86.8% idle
  gap exists in a DEVICE-RESIDENT separate baseline — both paths are grid-stride-saturated (util ~97-98% from
  B=1, median NOT ~0%), so fusion only trades ~5 launches for ~5 grid.syncs (a wash). The #2913 ~3x came from
  removing INTERPRETED host glue, absent here. % of ~1656x torch gap closed = 0%. flame identity INTACT
  (byte-exact rel-RMS 0 · no-LLVM · deterministic-at-dtype · theorem-cite); FAST is additive, this fusion's
  additive value is ~0 at the saturated regime. REAL remaining lever = interpreter-elimination, NOT GPU fusion.
- [x] **FAST-4 (MOOT — FAST-3 closed-neg) — opt-in fast-mode wiring + identity guard (preserve the default)** — wire FAST as an OPT-IN
  lane (env/flag) so FP64 byte-exact stays the canonical default; FAST is selected explicitly. Gate: FP64
  byte-exact path unchanged (max|d|=0 vs prior) AND FAST path documented as deterministic-at-dtype (not
  FP64-byte-exact). Identity preserved: no-LLVM + reproducible + theorem-cite all intact.
- [x] **FAST-5 (N/A — conditional on FAST-3 breaking ~3x, unmet) — honest vs-PyTorch re-measure (only if FAST-3 breaks ~3x)** — if FAST-3 actually beats ~3x,
  measure the new flame-vs-PyTorch gap (was ~1656x @ FP64/batch=1): how much of the gap does fused-TF32-batch
  close? Honest: flame's value is still byte-exact/no-LLVM, not step-rate; FAST is a complement, not a torch killer.

## honest framing (g5)

This domain tests a HYPOTHESIS (⚪ speculation until measured): the three levers combined MAY break ~3x, because
each alone hit a DIFFERENT wall and the combination plausibly cancels all three (TF32 fits, fusion removes gaps,
batch fills). It may also fail (e.g. the gaps reappear, or TF32 still can't fit, or batch-glue still caps it) —
that would be an honest closed-negative. Either way, flame's FP64 byte-exact identity is the protected default;
FAST is purely additive. NOT attempted yet — registered for a future `FAST-1 go`.
