# HEXA-FLAME-FAST

@title: 🏎️ HEXA-FLAME-FAST — flame 학습 step 고속화 (정체성 유지)

@goal: Break the ~3x flame CLMConvMoE full-step self-speedup cap by COMPILING the whole train step into ONE
fused native kernel at a GPU-FITTING precision (TF32/BF16) + batch>1 — the three levers tested only
SEPARATELY so far. Crucially this is OPT-IN: FP64 byte-exact stays the canonical default; FAST is an added
lane. flame's identity (no-LLVM native compile · deterministic/reproducible at the chosen dtype · theorem-cite)
is PRESERVED — compiling does NOT make flame into PyTorch.

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
- [ ] **FAST-2 — fused whole-step megakernel at TF32/BF16** — author the #2924 whole-step uberkernel but in
  TF32/BF16 so it fits occupancy. Gate (g5): rel-RMS <= 1e-2 vs same-dtype reference (W14 convention, NOT
  FP64-byte-exact) AND run-to-run determinism max|d|=0 (fixed accum order, reproducible). Measure full-step
  wall vs the separate-kernel baseline + util mean/median.
- [ ] **FAST-3 — + batch>1 (the genuinely-untested 3-way combo)** — run FAST-2's fused-TF32 megakernel at
  batch>1: fit occupancy (TF32) + remove the gaps (fusion) + fill the SMs (batch) ALL AT ONCE. Gate: does the
  full-STEP self-speedup BREAK ~3x? Report the new ceiling vs the ~3x batch-fill cap. This is the decisive test.
- [ ] **FAST-4 — opt-in fast-mode wiring + identity guard (preserve the default)** — wire FAST as an OPT-IN
  lane (env/flag) so FP64 byte-exact stays the canonical default; FAST is selected explicitly. Gate: FP64
  byte-exact path unchanged (max|d|=0 vs prior) AND FAST path documented as deterministic-at-dtype (not
  FP64-byte-exact). Identity preserved: no-LLVM + reproducible + theorem-cite all intact.
- [ ] **FAST-5 — honest vs-PyTorch re-measure (only if FAST-3 breaks ~3x)** — if FAST-3 actually beats ~3x,
  measure the new flame-vs-PyTorch gap (was ~1656x @ FP64/batch=1): how much of the gap does fused-TF32-batch
  close? Honest: flame's value is still byte-exact/no-LLVM, not step-rate; FAST is a complement, not a torch killer.

## honest framing (g5)

This domain tests a HYPOTHESIS (⚪ speculation until measured): the three levers combined MAY break ~3x, because
each alone hit a DIFFERENT wall and the combination plausibly cancels all three (TF32 fits, fusion removes gaps,
batch fills). It may also fail (e.g. the gaps reappear, or TF32 still can't fit, or batch-glue still caps it) —
that would be an honest closed-negative. Either way, flame's FP64 byte-exact identity is the protected default;
FAST is purely additive. NOT attempted yet — registered for a future `FAST-1 go`.
