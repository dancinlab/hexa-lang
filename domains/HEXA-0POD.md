# HEXA-0POD

@title: 🔁 HEXA-0POD — flame+forge improvement loop on FREE resources only (no vast pod)

@goal: Continuously improve flame + forge using ONLY free resources — the sidecar pool (aiden RTX 5070
sm_120, summer RTX 5070, pi5-akida, ghost) + local CPU/code work. ZERO vast rentals. Each round: pick a
0-pod-feasible improvement, do it, verify on a free pool GPU (byte-eq / bit-exact gates), land it, loop.
Hopper-sm_90a-only work (the wgmma decode-elim own-GEMM) is OUT-OF-SCOPE here (needs an H100 pod); this
loop targets what the consumer card + code can carry.

## milestones (loop self-feeds; add as discovered)

<!-- ANCHOR:OP-45-GPU-OCCUPANCY-SWEEP (unique anchor — the GATED GPU sibling of OP-45 #3096 (static (a)-(d) cap classification) + OP-49 #3103 (CPU cost model). User-approved ONE H100 (~$1) to run the T1-T5 occupancy/profile matrix the static analysis handed off: confirm/refute the (a)-(d) classification with a real GPU profile + calibrate the cost model. T1 ptxas-v confirmed MODE8 = 90 regs/0 spill/96KB/2 CTA/SM D-invariant → (a)/(b) MEASURED-excluded. T2 ncu was INFRA-BLOCKED (RmProfilingAdminOnly=1, host-only kernel param, container can't change) so the (d)-splitter was resolved via a g5-legal ANALYTICAL ROOFLINE: D=4096 own kernel runs ~12-40% of HBM3 peak, AI 682 >> 104 compute-bound threshold → COMPUTE/SCHEDULING-bound, NOT a hard HBM roofline = FIXABLE stall. T3 MODE7 persistent+swizzle measured @4096 for the first time → does NOT recover the -9.9% (closed-neg, OP-49 GAP#2). T4 cuBLASLt heuristic → cuBLAS's +24.6% lever is a better single-pass tile + CTA-swizzle, split_k=1 (NOT split-K) → g5-bit-exact-reachable. T5 reconfirmed D=2048 anchor (320.6 TFLOP/s, 1.08x). Cost model MODE8@4096 over-prediction +9.2%→+1.0% via anchored steeper K-drain; ordering still PASS. One pod, ~$0.96, DESTROYED, leak-0) -->
- [x] **OP-45-GPU — REAL H100 sm_90a T1-T5 occupancy/profile sweep: the (a)-(d) classification CONFIRMED + the (d) sub-split RESOLVED → FIXABLE-SCHEDULING-STALL, not a hard HBM roofline. T1 90regs/0spill/96KB/2CTA-SM D-invariant ((a)/(b) measured-excluded); T2 analytical roofline DRAM ~12-40% peak + AI 682>>104 (compute-bound, ncu HW-counters infra-blocked); T3 MODE7-persistent @4096 closed-neg (no -9.9% recovery); T4 cuBLAS +24.6% = better single-pass tile+swizzle NOT split-K (bit-exact-reachable); T5 D=2048 anchor 320.6 TFLOP/s 1.08x; cost-model +9.2%→+1.0% calibrated. 1 H100 ~$0.96, leak-0** —
  🟢 GREEN. The OP-45 static (a)-(d) classification HOLDS under real GPU measurement and the surviving (d)
  is SPLIT into its actionable sub-case: the D=4096 own-GEMM cap is a FIXABLE compute/scheduling stall, NOT
  a hard HBM-bandwidth roofline (own kernel at ~283.9 TFLOP/s while DRAM idles at ~12-40% of HBM3 peak; TF32
  SM-math peak ~990 is 3.5x above). MODE7 persistent does NOT fix it (T3 closed-neg). cuBLAS's +24.6% large-D
  lever is a better single-pass tile + CTA-swizzle reachable WITHOUT bit-exact-breaking split-K (T4 split_k=1).
  ncu HW-counters were infra-blocked (RmProfilingAdminOnly=1, host-only); (d)-split resolved via g5-legal
  analytical roofline from the measured kernel wall-time. Cost model MODE8@4096 over-prediction +9.2%→+1.0%
  (anchored steeper K-drain; honest residual = drain non-uniform across modes → per-mode coeff is 0-pod
  follow-up); ordering still PASS both D. One H100 (contract 40729921), ~$0.96, DESTROYED, leak-0 verified,
  no foreign pod touched. Verdict .verdicts/hexa-0pod/F-OP45GPU-OCCUPANCY-SWEEP.txt.

<!-- ANCHOR:OP-52-TF32-GAP-CLOSE (unique anchor — OP-45-GPU T4 identified the @D=4096 TF32 sub-parity lever as a "better single-pass tile + CTA-swizzle, NOT split-K" (cuBLAS top D=4096 algo = split_k=1 + cta_swizzle=1, g5-bit-exact-reachable) and T2 proved the cap is a FIXABLE compute/scheduling stall (DRAM ~12-40% peak). User approved ONE H100 to BUILD that lever and measure if it closes the gap. OP-52 built MODE 9 gemm_og17_b14_swz = b14 MODE 8 math VERBATIM + a NON-PERSISTENT CTA-swizzle (1-CTA/tile grid, only the CTA→tile assignment order swizzled via the existing tile_unswizzle; SWZ=0 ≡ MODE 8 exactly) — isolating the swizzle from MODE 7's persistent-loop confound. RESULT: CTA-swizzle does NOT close the gap, it REGRESSES — best bit-exact swizzled @4096 = 280.5 TFLOP/s vs 285.1 SWZ=0 (−1.6%, ratio 1.50x→1.53x), every SWZ∈{2,4,6,8,12,16}×PDEP∈{1,2} worse, all rel_rms 0. Isolates OP-45-GPU T3 (the regress is the SWIZZLE not the persistent loop) + matches T2 physics (compute-bound ⇒ L2-locality reorder can't help). The in-tree larger single-pass tile (MODE5 t256) is already closed-neg @4096. Surviving lever = a NEW bit-exact single-pass per-CTA tile/schedule (a 2-CTA/SM-preserving kernel rewrite), NOT a launcher swizzle, NOT split-K. One H100 ~$0.70, DESTROYED, leak-0) -->
- [x] **OP-52 — BUILT the OP-45-GPU T4 CTA-swizzle lever (new MODE 9 gemm_og17_b14_swz = b14 MODE 8 + NON-persistent CTA-swizzle, isolated from MODE 7's persistent loop) + measured on a real H100: CTA-swizzle does NOT close the @D=4096 TF32 gap — it REGRESSES (best bit-exact swizzled 280.5 TFLOP/s vs 285.1 SWZ=0, −1.6%, ratio 1.50x→1.53x; all SWZ×PDEP worse; rel_rms 0 everywhere). 🔴/🟠 CLOSED-NEG. Surviving lever = a NEW bit-exact single-pass per-CTA tile/schedule, NOT a launcher swizzle. 1 H100 ~$0.70, leak-0** —
  🔴/🟠 CLOSED-NEGATIVE (honest, decisive). The CTA-swizzle lever OP-45-GPU T4 pointed at, built bit-exact and
  isolated from MODE 7's persistent-loop confound (MODE 9 = b14 MODE 8 math VERBATIM + 1-CTA/tile grid + only the
  CTA→tile order swizzled), does NOT close any part of the @D=4096 1.5x gap — it makes it slightly worse (best
  swizzled 280.5 vs the SWZ=0/MODE 8 baseline 285.1 TFLOP/s, −1.6%; ratio 1.50x→1.53x). Every group-width
  SWZ∈{2,4,6,8,12,16} × PDEP∈{1,2} regressed, all at rel_rms 0.000e+00 (bit-exactness PRESERVED at 100% of
  datapoints — the non-negotiable gate held; no faster-but-loose-TF32 variant was sought or produced). This
  ISOLATES OP-45-GPU T3 (MODE 7's @4096 regress was the SWIZZLE itself, not the persistent loop — strip the loop,
  keep the swizzle, regress persists) and matches T2's physics (compute/scheduling-bound, DRAM ~12-40% peak ⇒ an
  L2-locality CTA reorder cannot raise throughput). The in-tree larger single-pass tile (MODE 5 t256, 128x256) is
  already measured closed-neg @4096 (264.9 < 283.9, register-capped to 1 CTA/SM). Net: the @D=4096 gap is NOT
  closable bit-exact by a launcher/index swizzle; the surviving lever is a genuinely NEW bit-exact single-pass
  per-CTA tile/schedule (a 2-CTA/SM-preserving kernel rewrite), NOT split-K (g5). One H100 (contract 40733645,
  hexa-tf32gap), ~$0.70, DESTROYED, leak-0 verified, no foreign pod touched. Net-new code: self/native/wgmma/
  wgmma_tf32_b14.cu MODE 9 + op52_swz_run.sh. Verdict .verdicts/hexa-0pod/F-OP52-TF32-GAP-CLOSE.txt.

<!-- ANCHOR:OP-51-SURVIVE-SHADOW-TRANCHE (unique anchor — OP-48 closed the [R]-only tranche (7 dereg + arange pinned on a self-host compiler-closure ref), dropping the OP-43 survivor set to 16. Those 16 ALL carry [S] LOCAL-FN SHADOWS — a strictly HARDER tranche: a local `fn NAME` exists in real programs, so the safety analysis must prove the roster entry is deregisterable WITHOUT breaking those shadow bindings. OP-51 audits a tranche of 6 [S R]-survivors (kv_cache_append · repeat_kv · quantize_int8 · dequantize_int8 · magnitude_prune · tensor_fill) with the SAME per-builtin g5 method PLUS the explicit [S] shadow-safety CONTROL (a local `fn NAME` emits its OWN forward-decl+def+call and binds roster-INDEPENDENTLY, proven clean per name) + a compiler-closure zero-ref check (the arange lesson) + the proof-block-drop control. CONSERVATIVE; "more keeps than [R]" was the expected/permitted outcome) -->
- [x] **OP-51 — [S]-shadow survive-audit tranche (6 of 16 [S R]-survivors): all 6 g5-falsified + [S] shadow-binding CONTROL proven roster-independent per name + every compiling caller resolves to a local/imported shadow + every builtin-dep call-site dead (example -1 / already-AOT-fail / proof-block-dropped) + compiler/** ZERO refs → ALL 6 DEREGISTERED. Survivor set 16→10** —
  🟢 audited the [S]-shadow tranche kv_cache_append·repeat_kv·quantize_int8·dequantize_int8·magnitude_prune·
  tensor_fill (the HARDER tranche: each carries a REAL local `fn NAME` shadow). Per builtin: 0 codegen guard
  + 0 runtime symbol (incl prefix variants); AOT probe with correct args RE-VERIFIED FALSIFIED verbatim
  ("use of undeclared identifier 'NAME'" each). THE CRITICAL [S] CONTROL: a minimal `fn NAME(x){…}` + caller
  emits `HexaVal NAME(...)` def + call in the generated C and binds roster-INDEPENDENTLY (clang CLEAN per
  name) — so deregistration can never break a shadow. Every COMPILING caller resolves to a shadow:
  self/test_flash_decode `import "ml/kv_cache.hexa"` → `extern HexaVal kv_cache_append(_,_,_,_,_)` (5-arg
  LOCAL); repeat_kv = THE CLEANEST (all 4 caller files carry a local `fn repeat_kv`, 0 builtin-dep);
  quantize_model binds the 3-arg quantize.hexa shadow + fails on OTHER syms. Every builtin-dep (no-shadow)
  call-site dead: example baseline exit_code=-1 (benchmark_all/test_conv_cache_io/test_quant_beam_init/
  anima_mega_demo/anima_convergence_proof/benchmark_ai_native/test_reward_prune_ts); every self/ml tensor_fill
  caller ALREADY AOT/transpile-fails today with the builtin STILL registered (builtin-independent); the lone
  proof-block ref (self/test_array_ops_suite:379) is codegen-DROPPED (an UNREGISTERED name compiles inside
  `proof {}` — confirmed, 0 refs in C). compiler/** ZERO refs to all 6 (vs arange's 2 in bind.hexa:1281 →
  byte-eq fixpoint safe). env.hexa transpiles clean after the 6 removals (wipe_guard net +35/−4). HONEST
  FRONTIER: 9 [S R] survivors remain (relu sigmoid transpose normalize zeros attention topk sample_token
  mse_loss) + arange pinned; the EASY [S] removals are now largely consumed — the remaining 9 carry larger/
  liver shadow surfaces (sigmoid shadow=8/self=102, relu shadow=3/self=23, mse_loss shadow=9) and need
  per-name baseline-PASS verification of every unshadowed call-site; ≥1 (sigmoid-class) looks like a
  conservative live-shadow KEEP. Reservoir depleting; expect the next tranche to dereg FEWER than 6. $0 ·
  0-GPU · 0-pod · no vast · no foreign-pod · no .tape. Verdict .verdicts/hexa-0pod/F-OP51-SURVIVE-SHADOW-TRANCHE.txt.

<!-- ANCHOR:OP-50-ROUTEA-BOUNDARY-DOCS (unique anchor — the route-(a) own-GEMM perf story has a precise, hard-won boundary scattered across OP-45 #3096 + the GPU route-(a) measurement #3094 + OP-49 #3103: route-(a) pre-permute own-GEMM is bit-exact (rel_rms 0) AND reaches cuBLAS-TF32 PARITY (~1.08x, ~93% roofline, 315 TFLOP/s) @D=2048 but is NOT a cuBLAS BEAT and falls to ~1.50x @D=4096 because it is SHAPE-RIGID (one fixed 128x128 tile) vs cuBLAS SHAPE-ADAPTIVE. OP-50 REFLECTS that boundary into the canonical forge doc (docs/forge-routea-shape-adaptive.md, the file OP-49 authored — extend > duplicate per Occam g0) as a "§0 perf boundary / honest scope" section: what own-GEMM IS (bit-exact-parity-not-beat), what it ISN'T (cuBLAS beat; W14 FP16 11.5x off, W10 6.09x off), its VALUE (bit-exactness + device-residency + no-LLVM, NOT raw TFLOP/s — mirrors flame closeout framing), and the path forward (OP-49 selector + 4 config gaps). DOCS-ONLY, every number traces to a verdict) -->
- [x] **OP-50 — route-(a) own-GEMM perf BOUNDARY reflected into the canonical forge doc (docs/forge-routea-shape-adaptive.md §0): bit-exact (rel_rms 0) + cuBLAS-TF32 PARITY (1.08x, ~93% roofline, 315 TFLOP/s) @D=2048 — NOT a beat; ~1.50x @D=4096 because SHAPE-RIGID (fixed 128x128) vs cuBLAS SHAPE-ADAPTIVE; VALUE = bit-exactness + device-residency + no-LLVM, not raw TFLOP/s; path-forward = OP-49 selector + 4 gaps. DOCS-ONLY, $0, 0-pod** —
  🟢 DOCS-ONLY reflection (no code/runtime/.tape). Added a "## 0. Perf boundary / honest scope — what own-GEMM
  IS and ISN'T" section to docs/forge-routea-shape-adaptive.md (the OP-49 file; extend > duplicate, Occam g0),
  placed FIRST so a contributor reads the settled boundary before treating "beat cuBLAS" as a goal. STATES:
  (IS) route-(a) pre-permute = bit-exact rel_rms 0.000e+00 @every config + cuBLAS-TF32 PARITY @D=2048 (b14 MODE8
  NST3 PDEP2: own ~315 TFLOP/s, ratio 1.08x, PARITY=YES = ~93% of roofline), no-LLVM/no-cuBLAS-call, device-
  resident. (ISN'T) NOT a beat — cuBLAS-TF32 is the roofline; @D=4096 own falls to ~1.50x (own ~284 vs cuBLAS
  ~427, PARITY=NO) because SHAPE-RIGID (one fixed 128x128 plain-launch tile) vs cuBLAS SHAPE-ADAPTIVE (+24.6%
  @4096 via large-tile/split-K/persistent); spill/occupancy/D-indep-ptxas-ceiling all statically EXCLUDED, cause
  = (d) large-D scheduling roofline (OP-45). FP16 W14 ~11.5x off · W10 summit 70.7 TFLOP/s 6.09x off — neither a
  beat. (VALUE) bit-exactness + device-residency + no-LLVM-compile-theorem (a GEMM a persistent megakernel can
  call where it can never call the cuBLAS host API), NOT raw TFLOP/s-vs-cuBLAS — mirrors project_flame_h100_h200_
  closeout framing. (PATH-FORWARD) OP-49 shape-adaptive selector + 4 config gaps (64x64 small-tile · MODE7
  persistent @4096 · bit-exact split-K · NST-adaptive launcher), each a gated GPU-session build mapped to OP-45
  T1-T5 — IF a beat is ever pursued (not a standing goal). Every number traces to a verdict (#3094/#3096/#3103
  + W10/W14). $0 · 0-pod · no vast · no foreign-pod · no .tape. Verdict .verdicts/hexa-0pod/F-OP50-ROUTEA-BOUNDARY-DOCS.txt.

<!-- ANCHOR:OP-49-SHAPE-ADAPTIVE-DESIGN (unique anchor — OP-45 found route-(a) own-GEMM is SHAPE-RIGID (one fixed 128x128 plain-launch tile, parity @D=2048 1.08x but ~1.50x @D=4096) while cuBLAS is SHAPE-ADAPTIVE (+24.6% @D=4096 via large-tile/split-K/persistent kernel selection). OP-49 DESIGNS (0-pod, no GPU) a shape-adaptive tile-selector — a D-bucketed kernel-mode policy + a CPU analytical cost model that PREDICTS which existing kernel mode to launch per shape — and VALIDATES the cost model against the already-measured OG16/OG17/MODE8/MODE5 verdict points (no new GPU run). DOCS/DESIGN + a CPU reference cost-model script; the policy SPECS the kernels, building new modes is the GPU-session follow-up) -->
- [x] **OP-49 — route-(a) own-GEMM SHAPE-ADAPTIVE tile-selector DESIGN + CPU analytical cost model that PREDICTS the launch config per shape; cost-model ORDERING VALIDATED against measured OG16/OG17/MODE8/MODE5 points (PASS both D, mean |rel.err| 2.2%) → 🟢; 4 config-gaps flagged for the GPU session** —
  🟢 0-pod DESIGN (no GPU, no nvcc; all measured numbers CITED from F-OP45 + W-ladder verdicts). INVENTORY: 5
  in-tree route-(a) modes (MODE4 og16 128x128 2CTA/SM · MODE5 t256 128x256 154-reg→1CTA/SM · MODE6 relaxed · MODE7
  persist+swizzle (untested @4096) · MODE8 b14 dual-issue = frontier). POLICY: 3 shape buckets (small-D under-fill
  D≤1024 · medium-D parity 1024<D≤3072 · large-D drain-bound D>3072). COST MODEL (self/native/wgmma/routea_cost_model.py):
  predict_tflops = PEAK(349)·issue_eff·occ_factor·wave_eff·drain·reuse·fill, occupancy = MIN(smem-limited, REGISTER-
  limited) — the 154-reg t256→1CTA/SM register-cap is LOAD-BEARING (smem-only mispredicts the large-D crossover);
  issue_eff fit ONCE/kernel @D=2048 (per-kernel const, OP-45 finding1), D-scaling = PREDICTION. SELECTOR = argmax over
  {mode×NST}. VALIDATION: reproduces measured win-order at BOTH D — D=2048 [MODE8,OG17,OG16,t256] MATCH (anchors,
  exact) · D=4096 [MODE8,OG17,t256,OG16] MATCH (PREDICTION, incl. t256-above-OG16 crossover), mean |rel.err| 2.2%,
  ORDERING=PASS. Honest sub-residual: MODE8@4096 absolute +9.2% (static drain under-credits large-D K-drain; ordering
  unaffected; calibrate via OP-45 T2 ncu). GAPS: #1 64x64 small-tile · #2 MODE7 measured @4096 (=T3) · #3 bit-exact
  tree-reduction split-K (=T4) · #4 NST-adaptive launcher. $0 · 0-GPU · 0-pod · no vast · no foreign-pod · no .tape.
  Verdict .verdicts/hexa-0pod/F-OP49-SHAPE-ADAPTIVE-DESIGN.txt · docs/forge-routea-shape-adaptive.md.

<!-- ANCHOR:OP-45-ROUTEA-D4096-CAP (unique anchor — the route-(a) pre-permute own-GEMM (#3094, F-GPU-ROUTEA-KEEPBAND-MEASURE) crossed cuBLAS-TF32 parity @D=2048 (1.08x, 315 TFLOP/s, rel_rms 0) but did NOT @D=4096 (~1.50x, 284 TFLOP/s), with the verdict footnote attributing the residual to a "256-elt register-realloc ptxas cap". OP-45 STATICALLY (0-pod, no GPU) characterizes WHY @D=4096 misses parity — register-spill (a) / occupancy (b) / D-independent ptxas ceiling (c) / memory-roofline (d) — by source-level register/smem/occupancy/wave accounting of the actual measured kernel (b14 MODE 8 gemm_og17_b14), to either pin the cause or hand a precise GPU test matrix to the gated OP-45-GPU sibling) -->
- [x] **OP-45 — route-(a) own-GEMM D=4096 sub-parity cap STATICALLY characterized: (a) spill / (b) occupancy / (c) D-independent ptxas-ceiling ALL EXCLUDED; cause = (d) shape-rigidity-vs-cuBLAS-adaptivity (cuBLAS +24.6% / own −9.9% at larger D); 🟠 (d) sub-split needs a GPU profile, T1-T5 matrix handed to OP-45-GPU** —
  🟠 0-pod static analysis (nvcc not local → no on-CPU ptxas -v capture; numbers from the W-ladder verdicts +
  kernel source). KEY CORRECTION: the #3094 footnote's "256-elt register-realloc ptxas-cap" describes MODE 5
  (gemm_og17_t256, d0..d3 = 128 accumulator regs, the W11/W12 closed-neg), a DIFFERENT kernel that was NEVER the
  measured D=4096 datapoint. The measured kernel is MODE 8 (gemm_og17_b14): fixed 128x128 tile, d0/d1 = 64
  accumulator regs/thread, NST=3 → 96 KB/CTA → 2 CTA/SM — and this config is COMPILE-TIME CONSTANT, byte-identical
  at D=2048 AND D=4096 (D is a kernel ARG, not a template param). So (a) register-spill EXCLUDED (same binary both
  D; if no spill @2048 then none @4096), (b) occupancy-drop EXCLUDED (2 CTA/SM held both D), (c) D-independent
  ptxas ceiling EXCLUDED as the GAP cause (own MOVES with D 315→284 = −9.9%; a constant ceiling can't make a
  D-dependent number). The gap 1.08x→1.50x decomposes EXACTLY into cuBLAS scaling UP +24.6% (342.5→426.8, shape-
  adaptive large-tile/split-K/persistent) + own scaling DOWN −9.9% (315.0→283.9, fixed 128x128 plain-launch, 2x
  K-loop drain at nks 64→128). Wave-quantization EXCLUDED (0.970 efficiency at BOTH D, computed: 132 SMs x 2 =
  264 resident; 256/264 vs 1024/(4*264)). Surviving classification = (d) memory/large-D scheduling roofline =
  own-GEMM SHAPE-RIGIDITY vs cuBLAS SHAPE-ADAPTIVITY. HONEST 🟠: the (d) sub-split (hard HBM-BW roofline vs fixable
  scheduling/drain stall) needs a real GPU ncu/nsys profile; precise T1-T5 test matrix (ptxas -v confirm, ncu
  DRAM%/Tensor%, MODE 7 persistent recovery, cuBLAS algo introspection, W12 TN re-confirm) handed to the gated
  OP-45-GPU sibling. $0 · 0-GPU · 0-pod · no vast · no foreign-pod · no .tape. Verdict
  .verdicts/hexa-0pod/F-OP45-ROUTEA-D4096-CAP.txt.

<!-- ANCHOR:OP-42-HEXFLOAT-CONTRACT-GATE (unique anchor — OP-40 (#3084) FIXED the comptime float const-fold to serialize folded doubles as bit-exact C99 hex-float literals (0x1.<mant>p<exp>, integer ops) instead of the lossy host %.17e path, closing a max-1-ULP residual to 0 across 125 cases. That is a determinism-relevant COMPILE-STEP guarantee whose discoverability + regression-lock were incomplete: OP-40's verdict explicitly deferred the contract clause ("docs milestone") and the OP-39 gate locked the fold bits but had no case NAMED for the hex-float path. OP-42 reflects the guarantee into the determinism contract (new compile-time-const-folding subsection) + extends the OP-39 gate with hex-float-specific cases — docs+test+workflow-comment only, NO codegen, NO .tape, g84 no-paper) -->
- [x] **OP-42 — OP-40 hex-float fold-serialize reflected into the determinism contract (new compile-time-const-folding §) + OP-39 const-fold gate extended with 5 hex-float regression cases (13→18)** —
  🟢 docs+gate, fully verified BOTH ways on the freshest local hexat (built from current source). CONTRACT
  (docs/flame-determinism-contract.md): new §1 subsection "compile-time constant folding — bit-exact hex-float serialize"
  framed as a COMPILE-STEP sibling of the 3 run-step layers — (a) compiler const-folds let-bound float-literal exprs at
  comptime + inlines the folded literal at every use-site; (b) RULE: folded const serialized as a bit-exact C99 hex-float
  literal (0x1.<mant>p<exp>, integer ops only) so clang re-parses ZERO-loss, NOT decimal %g/%e (hand-rolled formatter not
  correctly-rounded → drifts); (c) WHY: a 1-ULP fold drift makes the SAME source compile to different float bytes per host's
  printf, breaking machine-independence at the COMPILE step — tied to OP-37/40 MEASURED evidence + explicitly INDEPENDENT of
  the FMA layer (cross-ISA policy unaffected) + cross-linked to CHECKPOINT's fp64-reinterpret. + one "what breaks the
  contract" bullet. GATE (stdlib/flame/op39_constfold_byteeq.hexa + tool/op39_constfold_gate.sh): +5 MUL_HF* hex-float cases
  — products the OLD %.17e/%g serialize mis-rounded (MUL_HF1 0.254829592*0.3275911 emitted lossy 0.0834799 pre-fix vs exact
  0x1.55ef06babe355p-4 post-fix), goldens = python struct.pack correctly-rounded. VERIFIED: built the OP-40-fixed hexat from
  current source (tool/regen_cc_manual, HEXA_V2=Jun-8 hexat + restored frozen runtime.c) → emits hex-floats, self-tests
  15/15; gate PASS all 18 on fixed compiler (exit 0); hand-corrupt MUL_HF1 golden by 1 ULP → FAIL (exit 1, teeth). SEED
  ADVISORY: pre-fix Jun-8 hexat (= CI's frozen-seed generation) DRIFTs on all 5 new cases identically to the existing 13 →
  they stay under OP-39's continue-on-error advisory (NO yaml change, NO enforcing flip — that's OP-39b's deferred
  frozen-anchor re-pin; whole gate auto-goes-GREEN on promote). SCOPE: test oracle + gate script + doc + CI comments only —
  NO codegen/SSOT-module touch → self-host fixpoint unaffected (OP-40 proved it on main). Verdict
  .verdicts/hexa-0pod/F-OP42-HEXFLOAT-CONTRACT-GATE.txt.
  $0 · 0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape edits.

<!-- ANCHOR:W16-WGMMA-H100-MEASURE (unique anchor — the GPU-gated remainder of OP-21A: the w16 descriptor-direct own-GEMM kernel (canonical-atom re-encode -> delete the 32KB decode band) was CPU-de-risked 0-pod (w16_canon/modes/op29_ref checks pass) but its bit-exactness + perf were H100-sm_90a-GATED (aiden 5070 is sm_120, cannot run sm_90a wgmma). Resolved under a ONE-TIME user-approved H100 rental — the documented Hopper-out-of-scope exception. The MODE-1 descriptor-direct read is the PRE-REGISTERED D1 FALSIFIER) -->
- [x] **W16 — OP-21A w16 descriptor-direct own-GEMM, REAL H100 sm_90a gate: D1 pre-registered falsifier RESOLVED (closed-neg WITH a number)** —
  🟢 GREEN (ran + measured on real Hopper; ONE-TIME user-approved H100 rental, ~$0.72, leak-0 confirmed,
  NO foreign pod touched). vast 40664227 (label hexa-g1w16) H100 80GB HBM3 sm_90a, driver 550.163.01,
  nvcc 12.6.77 (EXACT W10/W12/W13 apples). RESULT: the OP-21A D1 hypothesis (canonical-atom re-encode lets
  a descriptor-DIRECT wgmma read the SWIZZLE_128B-TMA tile bit-exactly, deleting the 32KB software decode
  band) is FALSIFIED. MODE 0 canonical-decode PASS rel_rms 0.000e+00 (4096/4096 exact — the encode + host
  composed-read law are correct); MODE 1 descriptor-direct FLOORS rel_rms 1.107 at default AND across the
  FULL inline (lbo×sbo×boff×swmode) sweep — NO config reaches rel_rms 0. Per g5 the hard gate STOPS before
  any MODE 4 / perf (no TFLOP/s on a falsified read law); W10 70.7/6.09x frontier KEPT (W11/12/13 hard rule);
  the documented OP-21B fallback (gemm_w16b, keep the band) is the indicated next kernel. REPRODUCES the
  W15 (3200-cfg) + BENCH-12 (1.009) wall on the canonical-atom box: the TMA-swizzle ↔ wgmma-descriptor-
  swizzle layout interaction is REAL, NOT removable by canonical re-encode + a descriptor-field sweep alone.
  (Context: route-(a) PRE-PERMUTE — OG16 #2866 / BENCH-12/14 — is the bit-exact path that DID delete the
  band and reach 1.10x parity @D=2048; w16 is the closed-negative in-place-descriptor branch of that lever,
  now confirmed falsified on fresh H100.) Verdict .verdicts/hexa-0pod/F-W16-WGMMA-H100-MEASURE.txt.

<!-- ANCHOR:GPU-ROUTEA-KEEPBAND-MEASURE (unique anchor — the COMPLEMENT to W16: w16 confirmed the in-place-descriptor route-(b) is bit-exact-impossible (FALSIFIED rel_rms 1.107). This milestone measures the OTHER lever — route-(a) PRE-PERMUTE own-GEMM (the bit-exact path: gmma-INTER global pre-lay + NO-swizzle TMA + descriptor-direct, no decode band), to test whether its documented ~1.10x parity vs cuBLAS-TF32 @D=2048 reproduces on a fresh H100. Same ONE-TIME user-approved H100 exception as W16) -->
- [x] **ROUTE-A — route-(a) pre-permute own-GEMM, REAL H100 sm_90a re-measure: the ~1.10x parity @D=2048 claim REPRODUCED and EXCEEDED (bit-exact)** —
  🟢 GREEN (ran + measured on real Hopper; ONE-TIME user-approved H100 rental, ~$2.00/hr × ~15min ≈ $0.50,
  leak-0 CONFIRMED, NO foreign pod touched). vast 40675177 (label hexa-routeA) H100 80GB HBM3 sm_90a,
  driver 550.163.01, nvcc 12.6.77 (EXACT OG16/OG17/W16 apples). LEVER (a) = route-(a) pre-permute, the
  BIT-EXACT path (NOT (b) OP-21B keep-band/w16, already closed-neg & not re-run). RESULT: route-(a) is
  rel_rms 0.000e+00 at EVERY config of the full PDEP/NST sweep (vs route-(b)/w16 floored 1.107 — bit-exact
  is the load-bearing separator). Its strongest in-tree kernel b14 MODE 8 (deeper wgmma-group pipeline,
  PDEP dual-issue) @D=2048 NST=3 CROSSES PARITY: PDEP=2 own 314-316 TFLOP/s ratio 1.08-1.09x (3 reps, all
  PARITY=YES, all rel_rms 0, 2 CTA/SM 96KB band-free); PDEP=1 own 305 ratio 1.12x (== the documented ~1.10x).
  The ~1.10x parity @D=2048 is REPRODUCED and slightly BEATEN (best 1.08x). Same-pod apples re-confirm the
  W-ladder: W10 6.09x → OG16 1.36-1.40x → OG17-pipe 1.29-1.32x → b14 PDEP=2 1.08x, all bit-exact. HONEST
  (g5): 1.08x is NOT a cuBLAS beat (~93% of the roofline, bit-exact); @D=4096 parity NOT crossed (~1.5x,
  cuBLAS scales better, last lever = ptxas-capped 256-elt register-realloc = W12/OG17-MODE5 closed-neg).
  Verdict .verdicts/hexa-0pod/F-GPU-ROUTEA-KEEPBAND-MEASURE.txt.

<!-- ANCHOR:G1-CLMPROD-TF32-GPU-STEP (unique anchor — the SOLE GPU-gated remainder of gap G1 (real-corpus clm_prod_gpu TF32 end-to-end step). OP-24c/24d closed everything 0-pod-provable: input side proven byte-eq (OP-28/28b/28c) + pre-gated as STEP-0, TF32 code proven well-formed under -DHEXA_CUDA (F-OP24B), fast-mode determinism + bounded loss-tracking proven on sm_120 (OP-20/23/23b/24/25). The remaining un-measured piece = the real wall-clock TF32-vs-FP64 step ratio end-to-end, build-env-gated. Attempted on the same ONE-TIME H100 rental to capture the gate verbatim on real Hopper) -->
- [x] **G1 — clm_prod_gpu TF32 e2e step, REAL H100 build attempt: build-env gate CONFIRMED on Hopper (toolchain + frozen-seed, NOT a GPU limit)** —
  🟠 BLOCKED-CONFIRMED (on-HW attempt verbatim; same ~$0.72 H100 rental, leak-0). On a fully-capable H100
  (nvcc 12.6 + sm_90a live — the SAME pod ran the w16 wgmma kernels), the clm_prod_gpu TF32 step STILL
  cannot build, confirming G1's sole gate is BUILD-ENV / TOOLCHAIN / FROZEN-SEED-PACKAGING, NOT a Hopper/
  CUDA-capability limit. Gate reproduced on-HW, twofold: (i) TOOLCHAIN — a fresh CUDA pod has NO hexa/
  hexa-run; the kit's STEP-0 (and the runtime_cuda.c emit + clm_prod.hexa transpile) NEED the self-host
  hexa runner → kit failed clean at STEP-0 `hexa run FAILED (exit 127) — need a working hexa-run`, then
  EXIT (bootstrapping hexa from source = multi-stage, out of scope for a 30-min rental); (ii) FROZEN-SEED —
  a plain `git archive HEAD` carries the THIN pre-graduation self/runtime.c stub, MEASURED 0/31 host marshal
  wrappers on the pod; the complete CUDA runtime.c is the gitignored 151c52c8 blob `restore_frozen_seeds`
  fetches from git history (not in the shallow tarball). This is EXACTLY the F-OP24D documented remainder;
  the NEW datapoint = the gate is confirmed toolchain/seed on real Hopper. Natural fixes (kit-named, NOT pod
  tasks): (a) commit a re-frozen runtime.c with all 31 #ifdef HEXA_CUDA wrappers, OR (b) add a CUDA build
  job to release.yml. Input side of G1 unchanged (proven 0-pod F-OP28/28b/28c). Verdict
  .verdicts/hexa-0pod/F-G1-CLMPROD-TF32-GPU-STEP.txt.

<!-- ANCHOR:OP-33D-ADAM-STEP-SWEEP (unique anchor — the OP-33c HONEST §8 follow-up: OP-33c cleaned dead adam/safe_update from stdlib/optim.hexa + deregistered grad_clip_norm, but LEFT the falsified adam_step builtin registered in the self/env.hexa roster because 12+ other surfaces (self/ml/*) reference it — out of OP-33c scope. OP-33d does the systematic sweep: classify EVERY adam_step reference as live vs dead, repoint live / NOTE dead, then deregister iff no live surface needs it. Independently RE-VERIFIES (g5) that adam_step is falsified — runtime backs only adamw_step (RFC 034, 11-arg, a DIFFERENT symbol)) -->
- [x] **OP-33d — falsified adam_step builtin swept across self/ml/* → no LIVE caller → deregistered from the env.hexa roster** —
  🟢 g5 RE-VERIFIED falsified on CURRENT main (verbatim): `adam_step(...)` → emitted C `call to undeclared
  function 'adam_step'` / note: did you mean 'adamw_step'? (runtime.h:1543) → clang fails. Full caller sweep
  (grep -rn over *.hexa) classified EVERY ref: bare-builtin call sites = 4 example demos
  (anima_convergence_proof/benchmark_ai_native/test_optimizer/benchmark_all, all baseline exit_code=-1 never-passing)
  + self/ml/t2_gpu_bench.hexa (CUDA-gated bench, no gpu_optimizer import, CPU transpile aborts) — ALL DEAD →
  NOTE pointer comment. self/ml/{train_gpu,distributed_train}.hexa call `adam_step(state,grad,lr,t)` (4-arg) but
  `use "gpu_optimizer"` which DEFINES a local `fn adam_step` → resolve LOCALLY, not the builtin → NOTE. The
  adam_step_naive/_fused/galore_adam_step/ref_adam_step hits in self/test_*/self/ai_native/self/ml/galore are
  locally-defined fns (red herrings, unrelated to the builtin). NO live surface refs the builtin → DEREGISTERED
  from the self/env.hexa roster (mirrors OP-33c grad_clip_norm / OP-33b cosine_lr·warmup_lr); removing the builtin
  does NOT affect the local fn the gpu trainers bind to. adamw_step is 11-arg (p,g,m,v,n,lr,b1,b2,eps,wd,t) — NOT
  a drop-in for the 9-arg adam_step, so dead demos are NOTE'd not faithfully repointed (they're dead on the broader
  randn/zeros/cross_entropy family anyway). wipe_guard: 1 deletion (roster entry) « 50. Verdict
  .verdicts/hexa-0pod/F-OP33D-ADAM-STEP-SWEEP.txt. $0 · 0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape edits.

<!-- ANCHOR:OP-41-FALSIFIED-BUILTIN-SWEEP (unique anchor — the OP-33-family CLOSEOUT: the prior OP-33/33b/33c/33d ops removed individual falsified optimizer-scheduler builtins (scheduled_lr/cosine_lr/warmup_lr/adam/safe_update/grad_clip_norm/adam_step) one at a time as they were tripped over. OP-41 does the SYSTEMATIC repo-wide audit: enumerate EVERY one of the 231 self/env.hexa roster builtins, empirically probe each (g5: emit a call, inspect generated C) to build the DEFINITIVE real-vs-falsified matrix, then close the optimizer-scheduler family by deregistering any remaining falsified member with zero live caller) -->
- [x] **OP-41 — systematic falsified-builtin roster sweep: COMPLETE 231-builtin matrix (126 real / 105 falsified); optimizer-scheduler family CLOSED (sgd_step/numerical_grad/phase_lr/grad_accumulate deregistered)** —
  🟢 the DEFINITIVE audit: all 231 self/env.hexa roster builtins classified real-vs-falsified by cross-referencing
  codegen-inline lowering (`if name ==` guards) ∪ runtime.h/runtime.c symbols, then EMPIRICALLY probing every
  candidate (g5: `let _r = NAME(correct-args)` via fresh installed hexat → inspect generated C). RESULT MATRIX:
  126 REAL (codegen-inline or runtime-backed: print/len/matmul/softmax/layer_norm/Some/Ok/Err/sum/keys/… + all
  term_*/net_*/json_*), 105 FALSIFIED (AOT emits "use of undeclared identifier/function" — registered so the binder
  type-checks but no runtime impl). The OP-33 OPTIMIZER-SCHEDULER FAMILY had 4 remaining残党: sgd_step / numerical_grad
  / phase_lr / grad_accumulate — each g5-RE-VERIFIED falsified (verbatim undeclared-C), each with ONLY never-passing
  example callers (test_optimizer/test_lr_batch/anima_convergence_proof, baseline exit_code=-1) — every self/ml/
  {train_100m*,optimizer}.hexa `sgd_step(...)` caller binds to its OWN LOCAL `fn sgd_step` (red-herring, not the
  builtin) → zero compiler-core ref → DEREGISTERED (mirrors OP-33b/c/d). env.hexa transpiles clean; the train_100m
  transpile quirk is PRE-EXISTING (reproduces identically on builtins-present checkout). The remaining 101 falsified
  are OUT of the OP-33 family (ML/array/conv/quant/consciousness/n6 builtins — relu/sigmoid/zeros/cross_entropy/conv1d/
  …); MANY have local-fn shadows (e.g. relu→stdlib/nn.hexa) so deregistering en-masse is NOT conservative (g0) —
  bounded-with-reason + deferred to a future dedicated ML-builtin sweep, the matrix documents each. FAMILY-CLOSURE:
  after OP-41 the optimizer-scheduler falsified set is EMPTY. wipe_guard: net +18/−3 « 50. Verdict
  .verdicts/hexa-0pod/F-OP41-FALSIFIED-BUILTIN-SWEEP.txt. $0 · 0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape edits.

<!-- ANCHOR:OP-44-VSNPRINTF-CORRECT-ROUND (unique anchor — OP-40 (#3084) root-caused the comptime const-fold drift to the runtime's hand-rolled %.17e serialize (hxlcl_vsnprintf / rt_format_float_sci, "Not bit-exact with libc's") and worked AROUND it for the const-fold path via hex-float literals. But hxlcl_vsnprintf's %g/%e/%f is STILL non-correctly-rounded for ALL runtime float printing — every hexa program that prints a float uses it. OP-44 ASSESSES + (if tractable+safe 0-pod) FIXES the runtime float formatter to be correctly-rounded) -->
- [ ] **OP-44 — runtime float formatter `hxlcl_vsnprintf` non-correctly-rounded: MEASURED (62% of doubles mis-round %.17g/%.17e, ≤5 ULP, NOT shortest-round-trip) + libc-delegation fix PROVEN (→0/0) → 🟠 DEFERRED (frozen-seed runtime.c re-pin, same blocker as OP-39b/OP-40)** —
  🟠 the OP-40 ROOT cause, generalized. DEFECT MEASURED (g5, 5536 deduped finite doubles: A&S products + 5000 random
  magnitude 1e-300..1e300 seed=44 + 500 subnormals + edges; the EXACT frozen-blob float-format algorithm extracted
  verbatim into a standalone C harness vs host libc snprintf + python correctly-rounded ground truth): hxlcl_vsnprintf
  %.17g does NOT round-trip to the same double in 3463/5536 (62.6%), differs from libc in 5057/5536 (91.3%); %.17e
  parses to a DIFFERENT double than libc in 3432/5536 (62.0%), MAX 5 ULP (OP-40's narrow A&S sweep saw only 1 ULP —
  the wide range is worse). libc round-trips 100% (0/5536, sanity). → shortest-round-trip-INCORRECT, REAL + PERVASIVE
  (every high-precision float print: println/loss/grad-norm logs/to_string). ROOT = naive digit-extraction
  (`d=(int)dv; dv=(dv-d)*10.0` accumulates fp error; round-half-up peek-1-digit; no Grisu/Ryū; capped 18 digits),
  frozen self/runtime.c:722. CORRECT FIX = route the float branch to libc snprintf (OP-37b's atof→strtod pattern in
  REVERSE; libc %e/%g are C-standard correctly-rounded AND machine-independent → cross-platform deterministic). PROVEN:
  same 5521-case sweep with the float branch delegating to libc snprintf → 0/5521 round-trip fail, 0/5521 drift. libc
  IS reachable (runtime #includes <stdio.h>/<math.h> + already calls 36 real libm cos/sin/exp directly per
  stdlib_trig_libm; the hxlcl_* layer is deliberate symbol-elimination, not freestanding-hard). DEFERRED 0-pod: the
  formatter body lives ONLY in the gitignored frozen-seed self/runtime.c (restored from IMMUTABLE anchor 151c52c82;
  NO tracked SSOT emitter — codegen.hexa refs are comments; runtime.c.hexanoport: "Cannot be ported to .hexa (it IS
  the bootstrap runtime)"). A tracked fix needs the OP-39b-class frozen-anchor RE-PIN (build-host self-host ladder +
  gen3→gen4 byte-eq + FROZEN_SEED_REF bump) + a repo-wide golden re-bake (91% of float strings shift) — out of $0
  single-PR scope. OP-44 makes NO source/runtime/.tape edit → self-host fixpoint UNTOUCHED (no red-gate risk). The
  validated formatter patch + unblock recipe are in the verdict (drop-in for the eventual SELFHOST-NEXT promote;
  3rd instance of the frozen-seed-promote dependency after OP-39b/OP-40). Verdict
  .verdicts/hexa-0pod/F-OP44-VSNPRINTF-CORRECT-ROUND.txt. $0 · 0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape edits.
  → CONSOLIDATED (OP-46) into the SELFHOST-NEXT promote bundle: docs/selfhost-next-constfold-promote.md §2(c)/§3.

<!-- ANCHOR:OP-46-PROMOTE-BUNDLE-SPEC (unique anchor — three landed source fixes (OP-37b host-atof strtod parse · OP-40 bit-exact hex-float const-fold serialize · OP-44 libc-snprintf float-formatter delegation) are all correct in tracked source / proven-as-recipe but BLOCKED on the SAME frozen-seed-promote dependency: CI's toolchain bootstraps from the IMMUTABLE 151c52c8 anchor that pre-dates them, so each sat as a scattered "out of 0-pod scope" DEFER + OP-39's gate stays advisory (OP-39b). OP-46 CONSOLIDATES the four into ONE SELFHOST-NEXT work item — a single runbook spec + one unified deferred registration — so the next build-host session executes them as one promote bundle, not four scattered re-derivations. DOCS-ONLY: no seed regen, no build-host work, no codegen/runtime/.tape edits) -->
- [x] **OP-46 — SELFHOST-NEXT const-fold+atof+vsnprintf seed-promote bundle: 3 scattered DEFERs (OP-37b/40/44) + the OP-39b gate-flip CONSOLIDATED into ONE runbook spec + one deferred registration** —
  🟢 GREEN (DOCS/SPEC, 0-pod). The three float-correctness fixes share ONE blocker (the frozen-seed re-pin:
  build_selfhost.sh ladder + gen3→gen4 byte-eq + FROZEN_SEED_REF bump), so OP-46 turns 4 scattered "out of
  0-pod scope" notes into 1 executable build-host work item. DELIVERABLE: **docs/selfhost-next-constfold-promote.md**
  — the single runbook: (1) the promote MECHANISM (CI's seed = gitignored hexa_cc.c+runtime.c restored from the
  IMMUTABLE 151c52c8 .c-graduation anchor; re-pin = wholesale anchor refresh, 27,068-line drift measured by
  OP-39b); (2) the 3 source fixes + exact codegen.hexa/runtime.c sites + golden changes [OP-37b _cf_as_float
  strtod parse → operands byte-exact · OP-40 _cf_float_node bit-exact hex-float serialize → MAX 0 ULP · OP-44
  hxlcl_vsnprintf float-branch libc-snprintf delegation → 62.6% mis-round/≤5 ULP → 0/0]; (3) the ONE promote
  procedure (apply OP-44 to runtime → regen seed → coherent anchor commit → build_selfhost.sh fixpoint+parity →
  FROZEN_SEED_REF re-pin → ~91% float-string golden re-bake as its own PR); (4) post-promote cleanup (drop the 3
  nobaseline-gate.yml :129/:193/:256 continue-on-error lines → OP-39 gate enforcing, per OP-39b); (5) per-fix
  verification checklist (each oracle/gate green post-promote). REGISTERED: domain `## deferred` now opens with the
  unified "SELFHOST-NEXT — const-fold+atof+vsnprintf seed-promote bundle (OP-37b/40/44/39b)" item pointing at the
  spec; the OP-39b deferred note marked SUPERSEDED-by-bundle; the OP-44 milestone cross-links the runbook. The
  individual verdicts (F-OP37B/F-OP40/F-OP44/F-OP39B) are KEPT — OP-46 only unifies the forward-pointer. NO seed
  regen, NO build-host work (that IS the deferred item), NO codegen/runtime/.tape edits. Verdict
  .verdicts/hexa-0pod/F-OP46-PROMOTE-BUNDLE-SPEC.txt. $0 · 0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape edits.

<!-- ANCHOR:OP-47-MATMUL-DOT-PROBE (unique anchor — OP-43 KEPT 26 ML-family survivors conservatively; the THREE with the largest broken caller surfaces (matmul_into 333 real call-sites · mat_add_inplace 80 · dot 12) were held purely on g0 blast-radius. OP-47 PROBES — not assumes — whether that hold still binds: re-applies OP-41/OP-43's exact per-builtin g5 method (AOT probe correct-args + arg-shape-trap control + local-fn-shadow CONTROL + dead/live caller classification + compiler-core/byte-eq zero-ref check + pre-existing-failure control) to decide keep-or-deregister per builtin. Honest "all stay" was a permitted outcome) -->
- [x] **OP-47 — matmul_into/dot/mat_add_inplace large-surface probe: all 3 g5-falsified + DEAD-surface + shadow-safe + byte-eq-safe → ALL THREE DEREGISTERED** —
  🟢 PROBED (not assumed) the 3 largest OP-43 [R]-survivors. All three g5-RE-VERIFIED falsified (fresh
  hexat ~/.hx/bin/build/hexat → clang -fsyntax-only, CORRECT args: matmul_into([[..]],[[..]],[[..]]) /
  mat_add_inplace([[..]],[[..]]) / dot([..],[..]) each emit "use of undeclared identifier 'NAME'"); ZERO
  codegen-inline guard + ZERO runtime symbol (incl prefix variants) each → arg-shape-trap controlled.
  CONTROL: a local `fn dot` emits its OWN `HexaVal dot(...)` def + a call compiling CLEAN → shadows bind
  roster-INDEPENDENTLY (11 dot shadows incl stdlib/flame/clm_h911 UNAFFECTED). CALLER SWEEP: matmul_into 333
  real call-sites ALL self/ml/* trainers + self/test_inplace (already-falsified, NOT in compiler closure);
  mat_add_inplace 80 ALL self/ml + self/test_inplace/test_new_builtins; dot 12 non-shadow = 3 baseline-dead
  examples (exit_code=-1) + self/ml,self/stdlib,self/test tensor files that already TRANSPILE-FAIL today
  ("index 1 out of bounds") + 1 string-literal in a codegen test. SELF-HOST SAFE: compiler/** (byte-eq core,
  build_selfhost walk(compiler/main.hexa) closure) has ZERO refs to all three + ZERO compiler imports of
  self/ml → fixpoint untouched. PRE-EXISTING-FAILURE CONTROL: every caller fails on the INSTALLED hexat which
  STILL registers the builtins → dereg is not the cause. DECISION (g0): all four conditions hold for each
  (falsified ∧ no-live-caller ∧ shadow-binds-without-it ∧ 0 compiler-core ref) → ALL THREE DEREGISTERED; the
  OP-43 "large surface → keep" hold RELEASED because the surface is proven DEAD not merely large (breaks no
  working program — every caller already falsified). OP-43 survivor set 26→23. env.hexa transpiles clean after
  removal; neighbors (matvec/mat_add/rms_norm/rope/rope_inplace/repeat_kv) intact. REVERSIBLE one-line re-add.
  wipe_guard: net +11/−2 « 50. Verdict .verdicts/hexa-0pod/F-OP47-MATMUL-DOT-PROBE.txt.
  $0 · 0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape edits.

<!-- ANCHOR:OP-48-SURVIVE-AUDIT-TRANCHE (unique anchor — OP-47 dropped the OP-43 survivor set to 23. OP-48 audits the NEXT TRANCHE — the 8 [R]-ONLY (no-local-fn-shadow) survivors (cross_entropy · arange · clip · conv1d · save_array · load_array · rope · rope_inplace), the cleanest-to-decide subset — with OP-41/OP-43/OP-47's exact per-builtin g5 method (AOT probe correct-args + arg-shape-trap control + local-fn-shadow binding CONTROL + dead/live caller classification + compiler-core/byte-eq zero-ref + pre-existing-failure control). CONSERVATIVE; honest "most stay" permitted. The conservative compiler-closure safety gate is the load-bearing teeth, not ceremony) -->
- [x] **OP-48 — next-tranche survive-audit (8 [R]-only survivors): 7 g5-falsified + DEAD-surface + 0-shadow + byte-eq-safe → DEREGISTERED; arange STAYS (self-host compiler-closure ref). Survivor set 23→16** —
  🟢 audited the 8 [R]-ONLY OP-43 survivors (cross_entropy·arange·clip·conv1d·save_array·load_array·rope·
  rope_inplace) — the cleanest tranche (no local-fn-shadow ambiguity). ALL 8 g5-RE-VERIFIED falsified (fresh
  hexat ~/.hx/bin/build/hexat → clang -fsyntax-only, CORRECT args: each emits "use of undeclared identifier
  'NAME'"); ALL 8 = 0 codegen-inline guard + 0 runtime symbol (cross_entropy's only hit is the DIFFERENT RFC-034
  ad_softmax_cross_entropy carrier; clip/rope hits are runtime COMMENTS) → arg-shape-trap controlled. CONTROL: a
  local `fn cross_entropy` emits its OWN `HexaVal cross_entropy(...)` def + a clean-compiling call → shadows bind
  roster-INDEPENDENTLY (none of the 8 actually has a shadow — 0 each). CALLER SWEEP (word-boundary; comments +
  "…NAME(…" string-literals excluded): every REAL call-site DEAD — example callers baseline exit_code=-1
  (anima_convergence_proof/test_matmul_loss/test_conv_cache_io/test_modern_llm/…); stdlib/nn.hexa+self/ml/
  grad_engine+self/test_nn_stdlib (cross_entropy) ALREADY AOT-fail TODAY with the builtins STILL registered;
  self/ml/train_decoder_cpu_b (rope) already AOT-fails; train_7b + train_decoder_cpu_c/d/b2 (rope_inplace/save_
  array/load_array) already transpile-fail; stdlib/flame/clm_prod's `conv1d(` = the LOCAL conv1d_via_forge fn;
  stdlib bare-clip = formula prose. PRE-EXISTING-FAILURE CONTROL: every non-example caller fails on the INSTALLED
  hexat which STILL registers all 8 → dereg is not the cause. SELF-HOST: compiler/** has ZERO refs to the 7
  (byte-eq fixpoint untouched). DECISION (g0): 7 satisfy all four conditions → DEREGISTERED. **arange STAYS** —
  the safety gate caught a SELF-HOST COMPILER CLOSURE reference (registered in the tier-1 compiler bind allow-list
  compiler/check/bind.hexa:1281 + a codegen special-path per compiler/PLAN.md:574), failing the byte-eq/
  compiler-core zero-ref precondition. "Most go, one stays" — the conservative win: the gate actively prevented
  touching the self-host compiler's own bind surface. OP-43 survivor set 26→23 (OP-47)→16 (OP-48); the [R]-only
  tranche is now CLOSED (remaining 16 all carry [S] local-fn shadows — a harder later tranche). env.hexa
  transpiles clean after removal; arange + neighbors intact. REVERSIBLE one-line re-add. wipe_guard: net +33/−5
  « 50. Verdict .verdicts/hexa-0pod/F-OP48-SURVIVE-AUDIT-TRANCHE.txt.
  $0 · 0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape edits.

<!-- ANCHOR:OP-43-ML-FAMILY-FALSIFIED (unique anchor — OP-41 deferred ~101 non-optimizer falsified roster builtins conservatively. OP-43 takes the ML-FAMILY subset (conv/quant/activation/attention/array-ML cluster) and audits it ONE LAYER DEEPER with OP-41's exact per-builtin g5 method (AOT probe with CORRECT args + arg-shape-trap control + local-fn-shadow vs builtin distinction + dead/live caller classification) to either safely deregister the truly-dead or document precisely why each survives) -->
- [x] **OP-43 — ML-family falsified-builtin deeper audit: 42-builtin sub-matrix (all 42 AOT-falsified); 16 truly-dead DEREGISTERED, 26 SURVIVE-WITH-REASON** —
  🟢 re-applied OP-41's RIGOROUS g5 method to the 42-member ML family. Built AOT probe harness (fresh hexat
  ~/.hx/bin/build/hexat <in> <out.c> → clang -fsyntax-only) with the arg-shape-trap CONTROLLED (verified 0
  codegen-inline guards for all 42 → probe robust to arg shape) and the substring-over-count hazard REFUTED
  (sigmoid/cross_entropy/transpose/zeros/ones/attention/dot static grep-hits all empirically FALSIFIED). ALL 42
  emit "use of undeclared identifier 'NAME'". DEREGISTERED 16 (tanh_ ones ema batch_matvec batch_norm dropout
  gru_cell sinusoidal_pe multi_head_attention max_pool1d attention_cached beam_search_step xavier_init kaiming_init
  sparsity weight_dict) — each falsified + ZERO local-fn shadow repo-wide + EVERY caller a baseline-dead example/
  demo (tool/examples_baseline.json exit_code=-1), weight_dict a pure 0-call orphan. SURVIVE-WITH-REASON 26 (relu
  sigmoid cross_entropy transpose normalize zeros arange clip attention topk sample_token mse_loss conv1d
  kv_cache_append save_array load_array quantize_int8 dequantize_int8 magnitude_prune tensor_fill repeat_kv dot
  mat_add_inplace matmul_into rope rope_inplace) — local-fn shadows in real programs [S] and/or substantial broken
  self//stdlib caller surfaces [R] (matmul_into 50, dot 55, mat_add_inplace 33) → conservative g0 blast-radius bound,
  documented. CONTROL: a local `fn relu` emits `HexaVal relu(...)` (bare-name local def) compiling clean → shadows
  provide their own symbol, don't depend on the roster. SELF-HOST SAFE: compiler/** (byte-eq core) has ZERO refs to
  any removed name (only a `// sigmoid(x)=...` comment); no CI compiles example//self/ml. env.hexa transpiles clean
  after removal. CLOSURE: truly-dead ML-family subset is now EMPTY; the falsified ML family is bounded-with-reason
  to the 26 survivors. wipe_guard: net +22/−12 « 50. Verdict .verdicts/hexa-0pod/F-OP43-ML-FAMILY-FALSIFIED.txt.
  $0 · 0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape edits.

<!-- ANCHOR:OP-37B-HOST-ATOF-CORRECT-ROUND (unique anchor — OP-37 (#3069) fixed the `0.0 - X` NEGATION idiom byte-exact by preserving operand source TEXT, but left a documented residual: folds that COMPUTE a value from RE-PARSED operands (e.g. `let a = 1.5 * 0.1`) re-parse via to_float→hxlcl_atof, a naive digit-accumulator 1 ULP off the correctly-rounded value. OP-37b settles whether a correctly-rounded host parse is tractable WITHOUT risking the self-host byte-eq fixpoint: measure the residual exactly on from-source rebuild, then find the smallest correct fix) -->
- [x] **OP-37b — host-atof residual: computed const-folds re-parse operands 1 ULP off → FIXED via correctly-rounded strtod route (parse_float); fixpoint byte-identical** —
  🟢 the OP-37 residual is REAL on CURRENT source: MEASURED MAX 3 ULP (operands 1 ULP off via to_float/hxlcl_atof,
  compounding through `*`) on a from-source rebuild (NOT assumed). ROOT CAUSE = the host runtime has TWO string→double
  paths: `to_float`→__hx_to_double→`hxlcl_atof` (naive n=n*10+d accumulator, NOT correctly-rounded) vs
  `str.parse_float()`→hexa_str_parse_float→libc `strtod` (C-standard correctly-rounded) — `_cf_as_float` used the lossy
  one. FIX (g0/g4, additive, no deletions): route the const-folder operand parse through `lit.value.parse_float()` (the
  already-present strtod path — no runtime edit, no new parser, hxlcl_atof's C body lives in the untracked build-assembled
  runtime.c bootstrap substrate so editing it is neither needed nor in-tree) + make the `abs` float-fold preserve exact
  source text (the one remaining direct to_float site). RESULT: operands now byte-exact vs python correctly-rounded
  doubles; residual MAX 3→1 ULP (the lone remaining 1 ULP is host comptime `*` rounding vs clang, NOT a parse error — a
  separate smaller host-arithmetic-parity surface, logged out of scope). SELF-HOST FIXPOINT GREEN: fixed hexat re-
  compiling fixed source → gen-N==gen-N+1 SSOT C BYTE-IDENTICAL (+ object byte-identical), embedded self-tests 15/15,
  OP-37 negation idiom + abs regression byte-exact. Verdict .verdicts/hexa-0pod/F-OP37B-HOST-ATOF-CORRECT-ROUND.txt.
  $0 · 0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape edits.

<!-- ANCHOR:OP-40-COMPTIME-MUL-ULP (unique anchor — OP-37b (#3073) cured the const-fold operand PARSE (strtod route) but left ONE documented 1-ULP residual on COMPUTED products (e.g. `let a = 1.421413741 * 0.5`) and ASSUMED it was the host comptime `*` (rt_mul) rounding differently from clang. OP-40 MEASURES + CLASSIFIES that residual precisely (g5, measure don't assume) to either close it or bound+document it) -->
- [x] **OP-40 — comptime float-fold 1-ULP residual: ROOT-CAUSED to the host's hand-rolled %.17e SERIALIZE (not the multiply, not the parse, not clang FMA); FIXED via bit-exact hex-float literal → MAX 1→0 ULP** —
  🟢 the OP-37b residual is REAL: MEASURED MAX 1 ULP, nonzero in 16/125 computed-fold cases (A&S erf products + seed=40
  random products/sums/divisions) on a from-source rebuild — ~13%, NOT "rare" as OP-37b estimated. The OP-37b assumption
  (host comptime `*` rounds differently from clang) is FALSIFIED with evidence: (1) the multiply IS IEEE-correct — same
  runtime, parse_float·parse_float·* gives the exact python bits, single isolated fp64 `*`, NO FMA, -O0==-O2; (2) the parse
  is byte-exact (OP-37b strtod). ROOT CAUSE = the comptime fold computes the CORRECT product then SERIALIZES it via
  format_float_sci (%.17e), which in the self-host build routes through the runtime's hand-rolled snprintf override
  (hxlcl_vsnprintf, self/runtime.c:2095, "Not bit-exact with libc's") / hexa-source rt_format_float_sci — NOT correctly-
  rounded, round-trips bits-182 → "…117067" → bits-183 (1 ULP high). DIVERGING SIDE = the host serialize; IEEE-correct side
  = clang/runtime (the `let`-decl emitted `hexa_float((L)*(R))` is clang-folded, bit-exact). Same fragility class as the
  `stdlib_trig_libm` directive. FIX (g0/g4, additive +86/−9, no deletions, no runtime edit): `_cf_float_node` serializes the
  folded double as a bit-EXACT C99 hex-float literal (`0x1.<mant>p<exp>`) via `_cf_float_hexlit` built from raw IEEE-754
  bits with INTEGER ops only (clang parses hex-floats exactly → no decimal rounding step). RESULT: MAX 0 ULP across all 125
  folds (python-exact). SELF-HOST FIXPOINT GREEN: 4/4 SSOT modules gen-N (Jun-8 hexat) == gen-N+1 (fixed) BYTE-IDENTICAL,
  self-tests 15/15, OP-37 negation regression byte-exact. Not a clang-FMA issue → cross-ISA FMA invariant (OP-29/30/31)
  unaffected. Verdict .verdicts/hexa-0pod/F-OP40-COMPTIME-MUL-ULP.txt.
  $0 · 0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape edits.

<!-- ANCHOR:OP-38-CKPT-RECIPE-REFLECT (unique anchor — OP-35 (#3062) BUILT + PROVED the 6th determinism surface, a deterministic training checkpoint (stdlib/flame/ckpt_lib.hexa, "FCK\x01" v1 — binary fp64 little-endian bit-pattern reinterpret, full [t][n_params][W,m,v] state, resume==uninterrupted max|Δ|=0). The capability existed + was oracle-locked but its discoverability across the two contributor doc SSOTs was incomplete: the determinism contract's CHECKPOINT row asserted "not shortest-round-trip text" without tying it to OP-37's MEASURED to_string/%g lossiness, and the dojo had NO practical checkpoint recipe. OP-38 reflects the capability into both surfaces — docs-only, NO new code/oracle, NO .tape, g84 no-paper) -->
- [x] **OP-38 — deterministic checkpoint (ckpt_lib FCK v1) reflected into the determinism contract + dojo recipe (docs-only)** —
  docs/flame-determinism-contract.md REFINED (no duplicate): the CHECKPOINT row + "what breaks it" bullet now tie the
  binary-bit-pattern rationale to F-OP37's MEASURED proof that to_string/%g is "%g" 6-digit lossy (corrupts fp64 by up
  to 2.027e-6) — so the reinterpret exists PRECISELY to avoid text round-trip; the full-state [t][n_params][W,m,v]
  invariant + bit-for-bit resume==uninterrupted + cross-platform portability were already accurate from OP-35 and left
  as-is. docs/hexa-dojo.md GAINED a new terse callout in "Training recipe — optimization gotchas": the exact API
  (ckpt_begin → ckpt_save_param per param in pinned order → ckpt_load_param, resume at ckpt_step+1), the TWO gotchas
  (MUST save m,v AND step t — weights-only resets bias-correction, MEASURED 0.042; NEVER serialize through text), the
  bit-exact + machine/arch-portable property, and a one-line proof pointer to ckpt_lib.hexa + the op35 oracles. Every
  claim verified line-by-line against ckpt_lib.hexa + op35_ckpt_resume_eq.hexa + op35_ckpt_xplat_selfcontained.hexa
  (magic/header/field-order/API names/guarantees ALL MATCH — no invented API, no invented guarantee). DOCS-ONLY · $0 ·
  0-GPU · 0-pod · no vast · no .tape · g84 no-paper. Verdict .verdicts/hexa-0pod/F-OP38-CKPT-RECIPE-REFLECT.txt

<!-- ANCHOR:OP-39-CONSTFOLD-CI-GATE (unique anchor — OP-37 (#3069) + OP-37b (#3073) fixed REAL SILENT float const-fold codegen bugs: `let a = 0.0 - <float lit>` was const-folded through %g (6-sig-digit lossy → max|Δ|=2.027e-6), and computed folds re-parsed operands ≤1 ULP off via naive hxlcl_atof. These don't crash — they emit subtly wrong float bytes — so a future codegen refactor could reintroduce them undetected. OP-39 adds a byte-eq CI tripwire that locks the fixes: a self-contained oracle exercises the exact folder path + a gate asserts each fold's IEEE-754 LE bit pattern == recorded golden, on every push) -->
- [x] **OP-39 — float const-fold byte-eq CI regression gate: tripwire locking OP-37/OP-37b so the silent float bugs can never re-land** —
  🟢 self-contained oracle stdlib/flame/op39_constfold_byteeq.hexa binds `let nN = 0.0 - X` (full A&S erf coeff set:
  0.254829592/-0.284496736/1.421413741/-1.453152027/1.061405429/0.3275911 + the X-0.0/0.0+X/X+0.0 additive-identity
  forms) and the computed folds (0.254829592*0.284496736, 1.421413741*0.5, 0.1+0.2, 1.0/3.0), then REFERENCES each — the
  use-site inlines the comptime-folded literal (codegen.hexa:3105 _register_comptime_const path), exercising the EXACT
  serialize/parse path OP-37/OP-37b fixed (a bare inline arg is NOT registered → handed to clang full-precision → would
  mask the bug, so we deliberately bind-then-reference). 13 assertions on each fold's IEEE-754 LE bit pattern (decoded
  to signed-64 int) — PORTABLE, same goldens on every arch/OS, so byte-eq is machine-independent. tool/op39_constfold_gate.sh
  (modeled on OP-34's tool/fold_ci_gate.sh, low blast radius) wired into nobaseline-gate.yml on all 3 platforms right after
  the OP-34 fold gate — ADVISORY (continue-on-error) because the gate REVEALED CI's ./hexa is the FROZEN seed hexat
  (built from self/native/hexa_cc.c @ 151c52c8, PRE-OP-37/37b — the source fix is NOT YET PROMOTED into the seed, a step
  both verdicts deferred); it reports the seed-toolchain bug now + auto-flips to GREEN/enforcing on promotion (drop the
  one continue-on-error line). GOLDENS verified by RUNNING the FIXED-compiler-built oracle binary (/tmp/hexat_op37b_v4 → emitted
  C → clang + self/runtime.c → exit 0, all 13 match). PROVEN BOTH WAYS with the SAME gate: PASS on fixed-compiler output
  (exit 0) · FAIL on the pre-fix deployed ~/.hx/bin/hexa run (all 13 DRIFT to the lossy %g values, exit 1) — the bug/fix
  differential IS the test, no hand-corruption needed; plus a single-golden 1-ULP corruption confirms it catches even a
  one-bit drift. (a) negation/additive cases byte-EXACT vs python struct.pack('<d'); (b) MUL1 locks the +1-ULP host-rt_mul
  value the FIXED compiler emits (the documented OP-37b residual), NOT python's, so a re-broken parse drifts away. $0 ·
  0-GPU · 0-pod · no vast · no .tape. Verdict .verdicts/hexa-0pod/F-OP39-CONSTFOLD-CI-GATE.txt

<!-- ANCHOR:OP-39B-SEED-PROMOTE-FLIP (unique anchor — OP-39's deferred follow-up: promote the OP-37/37b fix into the CI seed self/native/hexa_cc.c, then flip the OP-39 gate advisory→enforcing. OP-39b SURVEYED the seed-regen mechanism and found CI's seed is NOT a tracked/surgical file: hexa_cc.c is gitignored + restored by git checkout of the IMMUTABLE frozen .c-graduation anchor 151c52c8. "Promote into the seed" = a wholesale frozen-anchor RE-PIN, not a fix cherry-pick; validated by the ~3.5h build_selfhost.sh self-host ladder on a build host. g0 tractability STOP for a $0 local single-PR task) -->
- [ ] **OP-39b — promote OP-37/37b const-fold fix into CI seed + flip gate enforcing → 🟠 DEFERRED (frozen-anchor re-pin, out of 0-pod scope); fix PROVEN correct + fixpoint-stable locally** —
  🟠 DEFERRED (honest g0 STOP — a clean DEFER beats a broken bootstrap seed). DECISIVE FINDING: "the CI seed" is an
  IMMUTABLE FROZEN GIT ANCHOR, not a tracked/regenerable/surgically-patchable file. self/native/hexa_cc.c is gitignored
  (.gitignore:286); CI restores it via `git checkout 151c52c8 -- self/native/hexa_cc.c` (tool/restore_frozen_seeds,
  FROZEN_SEED_REF = the .c-graduation parent of #2065) → stage_prebuild_hexat clang-builds CI's build/hexat from it. So
  "promote into the seed" is NOT a marker-guarded re-emit: the ONLY way to put the fix in CI's seed is to RE-PIN
  FROZEN_SEED_REF to a NEW bootstrap anchor carrying a coherent fresh snapshot of all 23 seeds. MEASURED that this is a
  wholesale, not surgical, change: regen of hexa_cc.c from current self/codegen.hexa (tool/regen_cc_manual, Jun-8 hexat)
  = 2,098,186 B / 31,222 lines vs frozen seed 1,854,825 B / 28,482 lines → diff = 27,068 lines of UNRELATED compiler
  drift (the const-fold helpers _cf_negate_float_text/_cf_float_node don't even EXIST in the frozen seed → nothing to
  cherry-pick into). Its byte-eq validation is the ~3.5h build_selfhost.sh self-host ladder (cc-gen3.o==cc-gen4.o) on a
  build host — out of 0-pod scope + the exact "bad seed breaks bootstrap" risk. The task's explicit STOP: regen carries
  unrelated drift → DEFER. PROVEN LOCALLY ($0, deterministic, arm64-macos) that the FIX is correct + fixpoint-stable:
  (1) regen builds clean → /tmp/hexat_regen; (2) SELF-HOST FIXPOINT byte-identical (gen-N re-regen == gen-N+1, cmp clean);
  (3) regen emits the FIXED exact/strtod literals (-0.254829592 · 7.24981871602117067e-02), NOT the lossy %g; (4) the
  OP-39 gate PASSES all 13 goldens against a binary built from the fixed regen → confirms the gate auto-goes-GREEN the
  moment the seed carries the fix. GATE FLIP NOT DONE (correct): the 3 continue-on-error lines (nobaseline-gate.yml
  :129/:193/:256) are LEFT IN PLACE — flipping while CI's frozen seed still has the pre-fix folder would turn all 3 jobs
  RED, the make-or-break red-gate the task forbids. The flip is correctly coupled to a seed promotion that did not happen.
  Exact unblock (build-host, NOT 0-pod): new coherent 23-seed anchor commit → build_selfhost.sh fixpoint + parity →
  re-pin FROZEN_SEED_REF → gate auto-GREEN → drop the 3 continue-on-error lines. $0 · 0-GPU · 0-pod · no vast · no
  foreign-pod touch · no .tape. Verdict .verdicts/hexa-0pod/F-OP39B-SEED-PROMOTE-FLIP.txt

<!-- ANCHOR:OP-36-DISPATCH-AUDIT (unique anchor — deep-dive round-10 branch ④: the OP-16 (groupnorm_gelu) / OP-18 (gelu2, moe_block2) / OP-32b (stdp_pair) class produced 4 REACTIVE discoveries of "GPU dispatch symbol declared + CUDA emit exists, but NO CPU body → importing the lib fails to link on CPU-only hosts" (hexa codegen emits ALL module fns, no DCE). OP-36 closes the pattern PROACTIVELY: sweep ALL forge dispatch symbols, build the symbol × CUDA-emit × CPU-body matrix, classify each CPU-missing symbol (real lib link hole / GPU-build-only by design / orphan), fix the real holes via the tool/restore_frozen_seeds marker-guarded channel, and CPU-link-probe every flame lib) -->
- [x] **OP-36 — forge dispatch CPU-fallback systematic audit: full symbol matrix, remaining link holes fixed (OP-16/18/32b class closed proactively)** —
  33-symbol matrix (prototype × CUDA-emit × CPU-body × reach): 33 CUDA-emitted · 8 CPU-covered · 25 CPU-missing
  · 0 orphans. Class (a) real holes FIXED link-proven byte-eq: HOLE-1 matmul_t (committed transpose-elim oracle
  was unlinkable → now F-OP2-TRANSPOSE-ELIM-BWD-EQ=1) + HOLE-2 matmul_batched (F-FORGE-BATCHED-EQ=1) + SEAM-3
  hexa_ twins for the OP-16/18 bare-only bodies. Class (b) = all 25 remaining, reachable ONLY from clm_prod.hexa
  (standalone GPU-build-only program, not importable) — documented, no blind math added. 16/16 flame *_lib.hexa
  CPU-link-probed LINK-OK (repo sources, clean sandbox). Verdict .verdicts/hexa-0pod/F-OP36-DISPATCH-AUDIT.txt

<!-- ANCHOR:OP-37-FLOAT-CONSTFOLD-VERIFY (unique anchor — OP-36 HONEST-NOTE #2 follow-up: OP-36 observed the stale Jun-1 hexat MISCOMPILE `let aN = 0.0 - <float literal>` (lossy ~6-sig-digit const-fold roundtrip, a2 -2.64e-7 / a4 +2.027e-6) and deferred it as a presumed stale-toolchain ghost per project_local_hexa_stale_oracle. OP-37 settles the decisive question: does it reproduce on CURRENT main, or is it env-bound? Build a self-contained f64_to_bytes_le byte-dump repro, run it through the FRESHEST local native compiler, compare to IEEE-754 ground truth, and if it reproduces localize+fix the codegen const-folder) -->
- [x] **OP-37 — `0.0 - <float literal>` const-fold miscompile: REPRODUCED on current main → REAL codegen bug → FIXED byte-exact** —
  🟢 the miscompile REPRODUCES on the freshest local native compiler (~/.hx/bin/build/hexat, Jun-8) — NOT a
  stale ghost. Self-contained repro (f64_to_bytes_le byte dump, PLAIN `let a=X` vs NEGATED `0.0-X`) shows the
  PLAIN block byte-exact but the inline-arg NEGATED block corrupted to ~6 sig-digits (a2 |Δ|=2.64e-7, a4
  |Δ|=2.027e-6 — matches OP-36 exactly). Root-caused to TWO bugs in self/codegen.hexa comptime_eval: (1)
  folded floats re-serialized via `to_string` = "%g" 6-digit (round-trip-lossy); (2) operands re-parsed via
  `to_float`/hxlcl_atof = naive digit-accumulator (1 ULP off the lexer's exact literal). FIX (additive,
  no deletions): `_cf_float_node` serializes folds at format_float_sci(f,17) = "%.17e"; `_cf_negate_float_text`
  + additive-identity special-cases (`-X`, `0.0-X`, `X-0.0`, `0.0+X`, `X+0.0`) preserve EXACT operand text
  (sign-toggle only, zero parse/re-serialize). Rebuilt from-source via tool/regen_cc_manual → clang → fixed
  hexat: NEGATED block now BYTE-EXACT (max|Δ|=0 across the full A&S erf coefficient set, python-cross-checked);
  ordinary `* /` folds + identities verified non-regressive. Verdict .verdicts/hexa-0pod/F-OP37-FLOAT-CONSTFOLD-VERIFY.txt

<!-- ANCHOR:OP-19G-SUMMER-5TH-ENV (unique anchor — deep-dive round-10 branch ②: formalize summer as the 5th RECORDED environment row of the machine-independence matrix. Summer (a distinct x86_64-linux glibc host from aiden, possibly a different glibc minor/distro) has been used as a substitute leg (OP-33/35) but was never RECORDED as an environment row with its exact glibc/distro/kernel fingerprint. Adding it diversifies the glibc-version axis and formalizes what OP-33/35 ran ad-hoc. Self-contained oracles only — summer's older hexa miscompiles cross-module imports (F-OP33/35 quirk)) -->
- [x] **OP-19g — summer recorded as 5th environment (distinct glibc x86 host): golden folds verified + matrix row** —
  summer fingerprinted precisely (Ubuntu 24.04.2 LTS · kernel 6.17.0-35-generic x86_64 · glibc 2.39 Ubuntu
  2.39-0ubuntu8.7 · AMD Ryzen 5 9600X) and formally RECORDED as the 5th environment (6th counting musl) in the
  docs/flame-machine-independent-training.md matrix. All 3 golden folds reproduce EXACTLY on summer (dt_exp
  7679248634312321699 · dt_erf FWD 4548590605583584556 · dt_erf BWD 4249661408190172843, process-to-process
  byte-eq double-runs) + breadth lanes F-OP33-LR-SCHEDULE=1 (d5 checksum 598834071, fingerprint == all-env) and
  F-OP35-XPLAT-LOCAL=1 (loss bits == record). NEW glibc-axis point: summer's LIBM folds == aiden's recorded
  glibc-x86 LIBM folds (3352931952497630952 / 6306829276275644424 / 5500011732941122953) — two independent
  glibc x86_64 hosts round identically on the libm lane while dt_* is identical across all 6 environments.
  HONEST: aiden DOWN + its glibc version never recorded (version-diversity unknown); summer = self-contained
  oracle lane only (older hexa miscompiles cross-module imports — F-OP33/35 quirk). Verdict
  .verdicts/hexa-0pod/F-OP19G-SUMMER-5TH-ENV.txt. $0 · 0-GPU · no vast.

<!-- ANCHOR:OP-35-CHECKPOINT (unique anchor — deep-dive round-10 branch ①: the 6th determinism surface = CHECKPOINT save/restore. A machine-independent run is only useful if you can STOP it, serialize (W, m, v, step t), restore, and RESUME byte-identical to an uninterrupted run. Serialization is a classic determinism hole: float→text round-trip loses bits; binary endianness; missing optimizer state restarts bias-correction; field/tensor iteration order. stdlib's only checkpoint (clm_ckpt.hexa .clm) is an int4-QAT INFERENCE export at fp32 — NOT a training checkpoint) -->
- [x] **OP-35 — checkpoint save/restore determinism: resume==uninterrupted byte-eq + exact serialization (6th surface)** —
  GREEN ($0, CPU `hexa run` + pool summer x86-linux; NO GPU/vast/pod). AUDIT: NO training checkpoint existed in
  stdlib — clm_ckpt.hexa (.clm) is an int4/fp32 INFERENCE export carrying BOTH classic training-resume holes
  (fp32 narrowing of fp64 state + no AdamW m/v/step-t); both DEMONSTRATED divergent in-band (fp32-trunc resume
  1.77e-8, wrong-t resume 0.042 — REAL-AND-CLOSED, not latent). CLOSE: stdlib/flame/ckpt_lib.hexa "FCK\x01" v1 —
  binary fp64-LE bit-pattern reinterpret (f64_to_bytes_le, NO text), fixed field order, COMPLETE state
  (W+m+v+applied-t). ORACLES: op35_ckpt_resume_eq.hexa — production CLMConvMoE micro-step save@2→restore-FRESH→
  resume 3..4 == uninterrupted 4-step run BIT-FOR-BIT (max|Δ|=0, 0 bit-mismatch over 17×{W,m,v}, loss bits eq) +
  adversarial IEEE-754 round-trip 33/33 (denormals·-0.0·±inf·qNaN-payload·sNaN-pattern); op35_ckpt_xplat_
  selfcontained.hexa (pool pattern) — 4/4 file-level cmp gates byte-IDENTICAL arm64-macos ↔ x86_64-linux
  (FORMAT-ECHO · RESUME-XPLAT · WRITE-SIDE · FINAL-UNINT) on a machine-independent pure-hexa step (no
  farr_matmul/no C-builtin AdamW — any diff attributable to the ckpt surface). Contract doc gains the CHECKPOINT
  row + what-breaks bullet. Verdict .verdicts/hexa-0pod/F-OP35-CHECKPOINT.txt.

<!-- ANCHOR:OP-34-FOLD-CI-GATE (unique anchor — deep-dive round-9 branch ④: the cross-platform oracles (OP-19 dt_exp / OP-19b dt_erf folds) exist on main but NOTHING ran them in CI — a regression (libm reintroduced on a deterministic site, canonical fold order broken, codegen FP-semantics change) would land silently. Wire the fold checks into CI as a low-blast-radius regression gate on the 3 CI platforms = the same matrix as faithful-nobaseline) -->
- [x] **OP-34 — machine-independence fold CI regression gate: dt_exp/dt_erf golden folds asserted per-platform** —
  GREEN ($0, 0-GPU, 0-pod, NO vast). WIRING: the 3 faithful-nobaseline jobs (darwin-arm64 · linux-x86_64 ·
  linux-arm64) already build a working ./hexa via the shared release path → the fold gate is APPENDED there
  (cheapest honest wiring: zero new builds/jobs; `hexa run` works on the seeds-removed checkout via the
  HEXA_PREBUILT_RUNTIME=build/runtime.a .c=0 seam). SSOT script tool/fold_ci_gate.sh (OP-5b/19f gate
  discipline — thin YAML wrappers) runs the two SELF-CONTAINED oracles op19_crossplatform_selfcontained.hexa +
  op19b_crossplatform_erf.hexa and asserts the 3 deterministic folds == the recorded 4-environment goldens:
  dt_exp CEBWD 7679248634312321699 · dt_erf GELUFWD 4548590605583584556 · dt_erf GELUBWD 4249661408190172843
  (LIBM lines intentionally NOT asserted — platform-dependent by construction). TEETH proven locally: altered
  golden → DRIFT line + exit 1; reverted → PASS exit 0. LOW-BLAST: only a real fold drift (or the oracle
  failing to run on a release platform) can fail it — no repo-wide scan, no new trigger surface. musl stays
  covered by F-OP19D (recorded) + the OP-19f static gate (honest limit — musl is not a CI platform).
  <5 s/platform. Verdict .verdicts/hexa-0pod/F-OP34-FOLD-CI-GATE.txt.

<!-- ANCHOR:OP-30C-FMA-BOUNDARY (unique anchor — deep-dive round-9 branch ③: OP-32's DIAG-B finding (binary {0,1}-operand matmuls are FMA-IMMUNE: fused≡unfused because a·b is exact when b∈{0,1}) formalized as the PRECISE boundary condition of the OP-30 cross-ISA-matmul invariant in docs/flame-determinism-contract.md — the boundary lived only in the F-OP32 verdict, not as a first-class discoverable part of the contract) -->
- [x] **OP-30c — FMA-immunity boundary (exact-product operands) formalized in the cross-ISA invariant (docs-only)** —
  GREEN (docs-only, $0, 0-pod, NO GPU/vast). docs/flame-determinism-contract.md gains "#### boundary:
  exact-product operands are FMA-immune" under the cross-ISA invariant: (a) MATH — round(a·b+c) ==
  round(round(a·b)+c) iff the product a·b is EXACT in fp64 (b∈{0,1} / ±2^k / 0 classes; ASCII exact-vs-inexact
  diagram); (b) MEASUREMENT — F-OP32 DIAG-B binary {0,1} spikes byte-IDENTICAL cross-ISA (1881150137 BOTH)
  through the SAME forbidden FMA-fused farr_matmul kernel that DIAG-A rate-coded real-valued drive diverges
  on (arm64 1478294112 ≠ x86 210297454); (c) PRACTICAL RULE — one-hot/mask/binary-spike matmuls provably safe
  through the fused kernel, but the immunity is an operand-VALUE property → conditional + fragile (plasticity/
  scaling/normalization make operands real-valued → blanket rule applies; default inline-ascending unless
  exact operands PROVEN); (d) blanket inline-ascending default KEPT (explicit SCOPE: explanation + narrowly-
  licensed exception, not a loophole). + surgical T4 cross-ref in flame-machine-independent-training.md.
  Verdict .verdicts/hexa-0pod/F-OP30C-FMA-BOUNDARY.txt.

<!-- ANCHOR:OP-33-LR-SCHEDULE (unique anchor — deep-dive round-9 branch ②: the 5th determinism surface = the LR-SCHEDULER arithmetic (warmup + cosine decay). The step path is libm-free (F-OP19/19b/29) but the schedule is a separate per-step float surface feeding lr into AdamW; the cosine needs cos() and libm cos is the same not-correctly-rounded cross-platform hole class F-OP19 closed for exp. OP-23b's harness computed its schedule once host-side and passed it to both lanes — sidestepping the production question) -->
- [x] **OP-33 — LR-scheduler determinism surface: audit + deterministic schedule (d5_cos) + oracle (5th surface)** —
  GREEN ($0, CPU `hexa run` + pool x86-linux; NO GPU/vast/pod). AUDIT: NO production LR scheduler existed in
  stdlib/flame (every trainer takes fixed lr — the surface was USER-SIDE); legacy stdlib/optim.hexa scheduled_lr
  wraps cosine_lr/warmup_lr builtins that NO LONGER BUILD (dead); no other schedule-class float arithmetic on the
  training loop (wd/betas fixed); libm cos IS a live builtin → the hole class was real for any user schedule.
  LOCK (case b): pub fn opt_lr_warmup_cosine (stdlib/flame/optim_lib.hexa) — linear warmup + cosine decay with
  cos = d5_cos (the F-OP29 RoPE 14-term-Taylor primitive), π = d5_pi(), fold order PINNED; the OP-23b lr_at()
  formula made machine-independent. ORACLE stdlib/flame/op33_lr_schedule_determinism_eq.hexa (self-contained
  OP-28/29 pattern): N=500 schedule byte-eq RUN-TO-RUN max|Δ|=0 + process-to-process full-output byte-eq +
  CROSS-PLATFORM d5 lane 0/500 byte-diff (arm64-macos vs summer x86-linux glibc, fingerprint
  `0 0 128 203 189 216 193 65` both) — AND the libm-cos twin lane MEASURED DIVERGENT: 10/500 steps differ
  1–4 ULP (t=121 180 367 381 387 391 394 407 414 433) Darwin vs glibc → REAL-AND-CLOSED (not latent; the
  F-OP19 exp pattern, now cos). Swap cost ~ULPs (max|Δ| 3.18e-19 vs libm on-host). Contract doc: SCHEDULE row +
  what-breaks entry + step-phase-map node (cite F-OP33). aiden was DOWN (ssh timeout) — x86 leg ran on summer
  (toolchain repaired host-locally: consistent generated runtime.c pair + prebuilt hexat_linux + runtime.a).
  Verdict .verdicts/hexa-0pod/F-OP33-LR-SCHEDULE.txt.

<!-- ANCHOR:OP-33B-DEAD-LR-CLEANUP (unique anchor — deep-dive round-10 branch ③: surgical cleanup of the DEAD legacy LR path OP-33's audit surfaced. stdlib/optim.hexa scheduled_lr wrapped cosine_lr/warmup_lr builtin names that have NO runtime impl (generated C fails to link: use of undeclared identifier) yet the self/env.hexa builtin roster still REGISTERED them so the compiler emitted calls into nothing. Deletion user-sanctioned per g34 (/afg)) -->
- [x] **OP-33b — dead scheduled_lr/cosine_lr legacy path removed (falsified builtins); canonical opt_lr_warmup_cosine pointed** —
  GREEN ($0, CPU `hexa run`, NO GPU/vast/pod). DEADNESS RE-VERIFIED independently (not trusted from F-OP33):
  probes `cosine_lr(...)`/`warmup_lr(...)` both FAIL — clang `error: use of undeclared identifier 'cosine_lr'`
  (the compiler emits hexa_call4 into a nonexistent runtime symbol — the roster/runtime split is the bug).
  CALLER SWEEP: 4 example files (test_stdlib · test_lr_batch · anima_mega_demo · anima_convergence_proof —
  ALL baseline-broken, examples_baseline.json exit_code=-1 never-passed) + the self/env.hexa roster row; zero
  LIVE callers. EXECUTED: scheduled_lr removed from stdlib/optim.hexa (one-line pointer comment →
  opt_lr_warmup_cosine, F-OP33); all 4 examples REPOINTED to `use "../stdlib/flame/optim_lib"` +
  opt_lr_warmup_cosine (floor_frac mapping: legacy min_lr=base·0.1 → 0.1; conv-proof 0.001/0.05 → 0.02;
  warmup-only = floor_frac 1.0 degenerate); self/env.hexa deregisters warmup_lr/cosine_lr (next compiler build
  rejects at hexa level instead of emitting broken C). POST: zero non-historical refs to the 3 names; OP-33
  oracle re-run PASS (F-OP33-LR-SCHEDULE = 1); canonical probe green (warm 0.0005 · mid 0.000628142).
  HONEST: stdlib/optim.hexa adam/safe_update wrap adam_step/grad_clip_norm which are ALSO dead (same falsified
  legacy-ML builtin family, incl. slice/zeros/mean/cross_entropy used by the examples) — NOT sanctioned here,
  left as a follow-up candidate. Verdict .verdicts/hexa-0pod/F-OP33B-DEAD-LR-CLEANUP.txt.

<!-- ANCHOR:OP-33C-DEAD-OPTIM-CLEANUP (unique anchor — the OP-33b HONEST §6 follow-up: stdlib/optim.hexa still held adam/safe_update wrapping adam_step/grad_clip_norm. OP-33c independently RE-VERIFIES deadness (g5, not trusted from OP-33b): adam_step → runtime defines only adamw_step (RFC 034, a different symbol) so codegen emits a call to an undeclared 'adam_step' → broken C; grad_clip_norm → no runtime impl AT ALL (undeclared identifier in generated C). Both wrappers are DEAD-FALSIFIED; their only callers are 2 already baseline-broken example files. Removes the wrappers + deregisters grad_clip_norm from the env.hexa roster (root-cause: no other live surface refs it). adam_step LEFT registered — 12+ other surfaces (self/ml/*) reference it, out of scope) -->
- [x] **OP-33c — dead adam/safe_update wraps removed (falsified adam_step/grad_clip_norm); grad_clip_norm deregistered** —
  GREEN ($0, CPU `hexa run`, NO GPU/vast/pod). DEADNESS RE-VERIFIED independently (g5): probe `adam_step(...)` →
  clang `call to undeclared function 'adam_step'` (runtime has only `adamw_step`, RFC 034 — a DIFFERENT symbol);
  probe `grad_clip_norm(...)` → `use of undeclared identifier 'grad_clip_norm'` (NO runtime impl at all). Both
  wrappers DEAD-FALSIFIED. CALLER SWEEP: adam ← example/anima_mega_demo.hexa only; safe_update ← example/test_stdlib.hexa
  only — BOTH examples_baseline.json exit_code=-1 (never-passed, array-dialect demos already broken on the same
  falsified-ML family: randn/zeros/slice/...); zero LIVE callers. EXECUTED: adam+safe_update removed from
  stdlib/optim.hexa (pointer comment → opt_adamw_step/opt_lr_warmup_cosine); grad_clip_norm DEREGISTERED from the
  self/env.hexa roster (only non-roster refs were the 3 baseline-broken examples + the now-removed wrapper — no live
  surface, so next compiler build rejects at hexa level instead of emitting broken C); the 2 example call sites got
  NOTE pointer comments (faithful repoint impossible — array-dialect vs handle-dialect opt_adamw_step signature).
  POST: stdlib/optim.hexa now BUILDS+RUNS clean (`[optim loaded]`, was: undeclared 'adam_step'); canonical flame
  path unaffected (opt_lr_warmup_cosine 0.0005 ✓). adam_step LEFT registered (12+ self/ml/* surfaces ref it — out
  of OP-33c scope; honest follow-up). Verdict .verdicts/hexa-0pod/F-OP33C-DEAD-OPTIM-CLEANUP.txt.

<!-- ANCHOR:OP-26C-READINESS-V2 (unique anchor — OP-26b (#3035) wrote docs/flame-machine-independent-SUBMISSION-READINESS.md against the round-5 evidence (1 arch · 4 env · gap G2 open · G1 input-side unproven). Rounds 6-8 grew the evidence: G2 CLOSED ×3-over (OP-29 decoder block #3045 · OP-31 MLP #3048 · OP-32 spiking LIF+STDP #3052 = 4 archs total), the G1 input slice fully proven (OP-28 byte-level #3041 · OP-28b BPE fix #3049 · OP-28c REAL Qwen vocab 151643 entries #3053) + pre-gated into the turnkey kit (OP-24d #3050), and NEW findings landed (OP-30 #3047 3-layer determinism model + cross-ISA FMA-matmul invariant; OP-32 binary-spike FMA-immunity boundary; OP-30b #3051 contract consistency). OP-26c refreshes the readiness doc to the current state: 4-arch claim, refreshed gap list, new evidence rows, sharpened FMA novelty, honest limits; docs-only, NO /paper scaffold per g84) -->
- [x] **OP-26c — SUBMISSION-READINESS updated: 4-arch G2 closed, real-vocab input, FMA novelty (docs-only, g84)** —
  GREEN (docs-only, $0, NO GPU/vast/pod). docs/flame-machine-independent-SUBMISSION-READINESS.md refreshed (v2)
  to the round-7/8 evidence: (a) CLAIM = the construction is GENERAL — 4 structurally-distinct archs (CLMConvMoE
  conv+MoE F-OP15 · decoder block attention F-OP29 · dense MLP F-OP31 · recurrent spiking LIF+STDP F-OP32 — first
  recurrent/event-driven/non-backprop) under the formalized 3-layer model (run-to-run · libm-free ·
  cross-ISA-FMA-free, F-OP30); flagship matrix stays 4-env × 3-libm, archs 2-4 honestly scoped to the 2-env ISA
  pair (new gap G7, LOW). (b) GAPS: G2 CLOSED ×3-over; G1 input slice CLOSED + pre-gated (F-OP28 byte-level ·
  F-OP28b canonical BPE · F-OP28c REAL Qwen vocab 151643 through production bpe_load · F-OP24d turnkey step-0
  pre-gate) — sole remainder = the GPU trainer step run, severity high→low-medium; G3-G6 verified unchanged.
  (c) EVIDENCE table +13 rows (incl. F-OP30b contract consistency, F-OP32b spiking CPU link). (d) NOVELTY now
  TWO legs: the 4-arch constructive recipe AND the cross-ISA FMA-contraction class itself — measured ×3 archs
  (F-OP29 241449363≠1401117690 · F-OP31 2039553633≠124945498 · F-OP32 DIAG-A 1478294112≠210297454), mitigation
  contract (inline ascending, F-OP30), measured boundary (binary {0,1} operands FMA-IMMUNE: F-OP32 DIAG-B
  1881150137 both ISAs). (e) honest limits refreshed (7 items); readiness ~80%→~90%. g84: NO /paper scaffold —
  readiness assessment only. Verdict .verdicts/hexa-0pod/F-OP26C-READINESS-V2.txt.

<!-- ANCHOR:OP-30B-CONTRACT-FIX (unique anchor — OP-30 (#3047) formalized the cross-ISA matmul invariant in docs/flame-determinism-contract.md but flagged OUT-OF-SCOPE a STALE pre-OP-19b line in the step-phase-map section still calling the GELU erf "a still-open libm hole" + pointing at a "§1 residual" that no longer exists; OP-19b (#3008, F-OP19B-DET-ERF) CLOSED that hole via dt_erf (A&S 7.1.26 branchless on dt_exp, byte-identical cross-platform), so the line is factually wrong and contradicts the doc's own §1 + per-phase table + what-breaks list. OP-30b corrects it; docs-only, 0-pod) -->
- [x] **OP-30b — fix stale "GELU erf still-open" line in the determinism contract (OP-19b closed it via dt_erf)** —
  GREEN (docs-only). The step-phase-map closing parenthetical in docs/flame-determinism-contract.md still read
  "(The GELU `erf` is a still-open libm hole — see §1 residual.)" — a pre-OP-19b leftover that was factually
  wrong (OP-19b #3008 closed the hole via dt_erf, byte-identical cross-platform; F-OP19B-DET-ERF) and
  contradicted the doc's own §1 + NORM table row + what-breaks checklist; the "§1 residual" pointer was
  dangling (§1 contains the closure, not a residual). Corrected surgically to the current truth: erf closed by
  dt_erf (A&S 7.1.26 branchless on dt_exp, no libm; F-OP19b) → step has NO libm transcendental left. Whole-doc
  stale-claim scan: this parenthetical was the SOLE contradiction (other "still"/"residual" hits = correct
  run-to-run-vs-cross-ISA usages + the F-OP13 filename). Doc now internally consistent about erf's status.
  Verdict .verdicts/hexa-0pod/F-OP30B-CONTRACT-FIX.txt.

<!-- ANCHOR:OP-24D-G1-READINESS (unique anchor — OP-24c (tool/clm/build_clmprod_tf32_e2e.sh) is the turnkey GPU-build kit for the real-corpus clm_prod_gpu TF32 end-to-end run; it is GPU-build-gated. OP-28 (byte-level) + OP-28b (BPE) proved the INPUT side (tokenize->pack->batch) byte-eq + machine-independent 0-pod. OP-24d WIRES those input-side oracles INTO the turnkey kit as a CPU pre-gate (step 0, runs NOW with NO GPU) so the kit verifies input reproducibility before the GPU step. Result: G1 is 0-pod-maximally-closed — everything provable without a GPU is proven + wired, the SOLE remaining G1 item is the GPU trainer step run; 0-pod, no GPU, no vast) -->
- [x] **OP-24d — G1 turnkey kit pre-gates the proven input-side determinism (OP-28/28b); only the GPU step remains gated** —
  GREEN. Wires OP-28 (byte-level) + OP-28b (BPE) input-side determinism oracles INTO OP-24c's
  turnkey GPU-build kit (tool/clm/build_clmprod_tf32_e2e.sh) as STEP 0 · INPUT-SIDE PRE-GATE —
  CPU-only, 0-GPU, runs BEFORE any nvcc/PROVISION guard. The pre-gate runs each oracle TWICE via
  $HEXA_RUN and asserts (i) the in-oracle PASS token (F-OP28-CORPUS-LOADER-DET = 1 /
  F-OP28B-BPE-FIX = 1) AND (ii) process-to-process byte-eq (run1==run2 diff clean), surfacing the
  CROSSPLAT-FINGERPRINT for the cross-platform leg; INPUT_PREGATE=PASS only if BOTH pass both legs,
  else the kit STOPS (exit 2) before spending a GPU build (g5: a determinism claim on a
  non-reproducible input is meaningless). Verified 0-pod: bash -n VALID; both oracles PASS locally
  (op28 fingerprint 0 0 0 216 16 88 186 65 == the F-OP28 recorded local+aiden value; op28b PASS);
  the pre-gate function exercised end-to-end against the real runner => INPUT_PREGATE=PASS. G1 is
  now 0-pod-MAXIMALLY-CLOSED: input side proven + pre-gated NOW, the GPU trainer STEP run (clm_prod_gpu
  -DHEXA_CUDA build env) is the SOLE gated remainder. NO GPU/vast/pod. Verdict
  .verdicts/hexa-0pod/F-OP24D-G1-READINESS.txt; readiness doc G1 row updated (HIGH -> reduced).

<!-- ANCHOR:OP-28B-BPE-FIX (unique anchor — OP-28 flagged a RESIDUAL: the BPE path (flame_bpe_corpus_lib.hexa, V=151936 real Qwen vocab) is not cleanly 0-pod-runnable because build_byte_to_char's byte->unicode map is non-canonical. OP-28b fixes the byte<->unicode mapping to the canonical GPT-2/Qwen bytes_to_unicode (256-entry bijection: printable ASCII -> itself, the rest -> U+0100.. in RUNNING-COUNTER order), making the BPE token pipeline byte-eq run-to-run + cross-platform determinism-provable, closing OP-28's residual input-side item; 0-pod, no GPU, no vast) -->
- [x] **OP-28b — BPE tokenizer byte-to-unicode fix (canonical GPT-2/Qwen map); BPE token pipeline determinism-provable (0-pod)** —
  GREEN. Closes OP-28's flagged residual input-side item. flame's BPE byte<->unicode map
  (self/ml/tokenizer_bpe.hexa build_byte_to_char) was NOT the canonical GPT-2/Qwen
  bytes_to_unicode — TWO defects: (1) printable bytes used byte-truncating chr(b) -> raw
  byte 0xA1, not the U+00A1 codepoint (UTF-8 0xC2 0xA1) the real Qwen vocab uses for the
  Latin-1 range (chr is also the chr(256+i)==chr(i) space-collision hazard); (2)
  non-printable bytes used codepoint 256+byte instead of the canonical running counter
  256+n (diverges for 35 bytes: 127..160, 173 — e.g. byte 127 canonical U+0121 vs old
  U+017F). FIX: build_byte_to_char now emits the canonical 256-entry bijection via the
  UTF-8 encoder from_char_code (never chr) with the running-counter formula — pure
  integer/table, no libm/float/hash-order. Oracle stdlib/flame/op28b_bpe_byteuni_det.hexa
  (self-contained, `use`-free cross-platform twin) PROVES: byte->unicode->byte round-trips
  ALL 256 bytes exactly (256/256, 0 collisions — space byte 32 -> U+0120 196 160 -> back
  32; bytes 127/160/173 round-trip); BPE pipeline (byte-encode->merge->id) byte-eq
  run-to-run max|Δ|=0 (in-process + process-to-process 945B identical); cross-platform
  byte-eq local arm64-macos == aiden x86-linux (checksum 102745433, fingerprint
  `0 0 0 100 21 127 152 65` on BOTH). OP-30: BPE is integer (no matmul) so FMA invariant
  N/A; confirmed no libm/float leak in the token id path. Honest remainder: NOT run
  against a real on-disk 151936-entry Qwen vocab.json (oracle uses a canonical-glyph
  self-contained merge/vocab to stay use-free + disk-frugal; the flagged byte-encoder is
  fixed, merge/id machinery is unchanged integer lookups); the simplified regex
  pre-tokenizer + GPU step are unchanged out-of-scope. $0, no vast, no GPU.
  Verdict .verdicts/hexa-0pod/F-OP28B-BPE-FIX.txt.

<!-- ANCHOR:OP-28C-VOCAB-STAGING (unique anchor — OP-28b's honest remainder: its oracle proved the fixed byte-encoder end-to-end but did NOT run against a real on-disk Qwen vocab.json (used a canonical-glyph self-contained merge/vocab — a staging gap, not a code defect). OP-28c closes that staging gap 0-pod: stage/verify the BPE tokenizer against a REAL on-disk Qwen-style vocab through the PRODUCTION load path (bpe_load: load_merges + load_vocab json_parse -> id lookup) at real-vocab scale — round-trip exact + byte-eq run-to-run + deterministic load + cross-platform arm64-macos==x86-linux; 0-pod, no GPU, no vast) -->
- [x] **OP-28c — BPE real-scale vocab staging: production load path round-trip + byte-eq + cross-platform (closes OP-28b remainder)** —
  GREEN. Staging approach = (a) REAL Qwen vocab (no synthetic fallback needed): a real Qwen2.5
  tokenizer already on this machine (edge/ckpt/storyboard-grpo vocab.json 151643 entries +
  merges.txt 151387 rules — read-only, never committed; 151936 = embedding rows incl. special
  tokens in tokenizer.json, NOT vocab.json). Oracle stdlib/flame/op28c_bpe_realvocab_staging.hexa
  uses the PRODUCTION modules (bpe_load: load_merges + load_vocab json_parse -> id maps; plus
  flame_bpe_corpus_load) — candidate-path + env override + honest SKIP-if-absent. RESULT: parse
  spot-checks 7/7 vs real-vocab ids incl. the OP-28b-repaired byte glyphs (byte 127 -> 221,
  160 -> 254, 173 -> 255, 'Ġhello' -> 23811); round-trip exact 6/6 multilingual (ASCII,
  space-heavy, Latin-1, KO, ZH/JA-no-spaces, mixed); ids byte-eq run-to-run AND across two
  independent fresh loads max|Δ|=0; FULL 151643-entry id->token table identical across fresh
  json_parse loads (no hash-order leak into observable ids); flame corpus-entry leg green;
  CROSS-PLATFORM local arm64-macos == aiden x86-linux byte-IDENTICAL DET block (1895 B, checksum
  757635534, fingerprint `0 0 0 231 76 148 198 65` on BOTH). FINDING (staging trap, not a code
  defect): a STALE installed hexa resolves `use "self/ml/tokenizer_bpe"` of a stdlib/flame-resident
  file against the INSTALL's pre-OP-28b self/ tree — first run silently reproduced the exact
  pre-fix failure; cure = run a repo-root copy (documented in the oracle header). Production load
  path showed NO defect at real scale. $0, no vast, no GPU.
  Verdict .verdicts/hexa-0pod/F-OP28C-VOCAB-STAGING.txt.

<!-- ANCHOR:OP-31-3RD-ARCH (unique anchor — OP-29 proved machine-independence on a 2nd flame arch (decoder block); OP-31 generalizes to a THIRD structurally-distinct arch — a plain feed-forward MLP (nn_lib nn_linear_fwd + GELU, NO attention/RoPE/conv/MoE/norm) — and verifies the OP-30 cross-ISA-matmul invariant (inline ascending reduction, NOT FMA-fused farr_matmul) holds. The production nn_linear_fwd routes through forge_dispatch_matmul → FMA-fused farr_matmul (tensor_lib L58 "ikj order, FMA-fused under clang -O2") = a REAL OP-30 hole; close it inline-ascending like OP-29) -->
- [x] **OP-31 — machine-independence on a 3rd flame arch + OP-30 cross-ISA-matmul invariant verified (or violation found+closed)** —
  GREEN. Generalizes OP-29's G2 from 2 archs to THREE: machine-independent byte-exact determinism now holds on a plain
  feed-forward MLP (Linear→GELU→Linear→GELU→Linear), structurally DISTINCT from CLMConvMoE (OP-15: conv+MoE+GroupNorm)
  AND the decoder block (OP-29: attention+RoPE+SwiGLU+RMSNorm) — every MLP layer is a pure GEMM, the purest stress of the
  OP-30 cross-ISA matmul invariant. 3rd arch = PRODUCTION nn_lib MLP (nn_linear_fwd + nn_gelu_fwd + nn_linear_bwd +
  nn_gelu_bwd). ORACLES stdlib/flame/op31_mlp_determinism_eq.hexa (run-to-run, imports prod lib) +
  stdlib/flame/op31_mlp_selfcontained.hexa (cross-platform inline-reduction twin + an in-band OP-30 FMA diagnostic).
  RESULT: byte-eq run-to-run (fwd out · bwd grads · bwd dx all max|Δ|=0) on BOTH oracles, BOTH platforms; AND
  cross-platform byte-IDENTICAL on local arm64-macos vs aiden x86-linux (free CPU pool, $0, NO vast/NO GPU) — identical
  checksums (fwd 1585504437 / grad 926871122) + identical IEEE-754 fingerprints FWD `0 0 64 45 56 160 215 65` · GRAD
  `0 0 0 41 119 159 203 65` on BOTH. OP-30 INVARIANT DIRECTLY DEMONSTRATED (not just verified): the production
  nn_linear_fwd rides forge_dispatch_matmul → FMA-fused farr_matmul (tensor_lib L58 "ikj order, FMA-fused under clang
  -O2") — a REAL OP-30 hole. The self-contained twin's in-band FMA diagnostic shows that exact kernel's L1 checksum
  byte-DIVERGES arm64 2039553633 vs x86 124945498 on byte-identical fp64 inputs, WHILE the inline-ascending rewrite of
  the same matmul stays byte-identical (fwd ck 1585504437 on both) — the live difference the invariant guards. HOLE
  CLOSED inline-ascending (_mlp_linear_fwd plain mul+add, no C kernel), the OP-29/CLMConvMoE discipline; nn_linear_bwd
  was already inline. libm-CLEAN (GELU via dt_erf/dt_exp; no RMSNorm so no _nn_sqrt libm on this path). Machine-
  independence GENERALIZES to 3 structurally-distinct archs. Verdict .verdicts/hexa-0pod/F-OP31-3RD-ARCH.txt.

<!-- ANCHOR:OP-32-4TH-ARCH (unique anchor — OP-15/29/31 proved machine-independence on 3 archs (CLMConvMoE · decoder block · MLP); OP-32 generalizes to a FOURTH structurally-distinct arch exercising a NEW primitive class: a spiking LIF RECURRENT network (spiking_lib flame_event_threshold + flame_refractory_step + flame_stdp_pair) — sequential state-carry across timesteps (recurrence = a new determinism surface: state-threading order), event thresholding (>= branch), integer refractory countdown, clip, and LOCAL STDP learning (non-backprop). spiking_lib primitives are pure t_* loops (NO farr_matmul, NO transcendental) → OP-30-compliant by construction; the oracle's recurrent/input current matvec is inline-ascending + an in-band FMA diag like OP-31) -->
- [x] **OP-32 — machine-independence on a 4th flame arch (new primitive class) + OP-30 compliance** —
  GREEN. Generalizes from 3 archs to FOUR: machine-independent byte-exact determinism now holds on a spiking LIF
  RECURRENT network with local STDP/Hebbian plasticity — the first RECURRENT (state-threaded across T=32 timesteps),
  first EVENT-DRIVEN, and first NON-BACKPROP-learning arch in the series. NEW primitives vs all 3 proven archs: event
  thresholding (v≥v_th), integer refractory countdown w/ clamp, clip, winner-take-all argmax, pair-STDP + competitive
  Hebbian local learning. 4th arch = PRODUCTION spiking_lib (flame_event_threshold + flame_refractory_step +
  flame_stdp_pair) + plasti_sim (ps_present chain). ORACLES stdlib/flame/op32_spiking_determinism_eq.hexa (run-to-run;
  imports prod plasti_sim + verbatim spiking CPU primitives) + stdlib/flame/op32_spiking_selfcontained.hexa
  (cross-platform twin + TWO in-band OP-30 FMA diagnostics). RESULT: byte-eq run-to-run (raster · plastic W · membrane v
  · traces · plasti_sim W/winners all max|Δ|=0, non-trivial: 25 spikes, STDP moved weights 0.2549) AND cross-platform
  byte-IDENTICAL local arm64-macos vs aiden x86-linux ($0, NO vast/GPU) — identical checksums (raster 236398270 / W
  876398044 / v 147958574) + identical fingerprints RASTER `0 0 0 124 77 46 172 65` · W `0 0 0 238 98 30 202 65` · V
  `0 0 0 92 86 163 161 65`. OP-30: substrate compliant BY CONSTRUCTION (pure t_* loops, no farr_matmul); currents
  inline-ascending; DIAG-A (rate-coded real-valued drive through FMA-fused farr_matmul) byte-DIVERGES arm64 1478294112
  vs x86 210297454 (live reproduction), while NEW FINDING DIAG-B: the binary {0,1} spike pattern through the SAME fused
  kernel is byte-IDENTICAL (1881150137 both) — binary-spike matvecs are PROVABLY (a·b exact for b∈{0,1} ⇒ fused≡unfused)
  and now MEASURABLY FMA-immune; the OP-30 boundary is precision-structural. libm-CLEAN by construction (decays are
  binary-exact rationals 15/16 · 7/8 · 13/16 — no transcendental on the arch). HOLE-2 FOUND (pre-existing, documented
  not closed): `use spiking_lib` does not LINK on CPU-only hosts — flame_stdp_pair_gpu's builtin lowers to
  hexa_forge_dispatch_stdp_pair whose CPU body is ABSENT from the regenerated runtime.c (header+codegen+CUDA-emit only;
  never committed) → packaging follow-up, not a determinism hole. Machine-independence GENERALIZES to 4 structurally-
  distinct archs. Verdict .verdicts/hexa-0pod/F-OP32-4TH-ARCH.txt.

<!-- ANCHOR:OP-32B-STDP-HOST (unique anchor — closes OP-32's HOLE-2: spiking_lib fails to LINK on any CPU-only host because flame_stdp_pair_gpu's builtin lowers to hexa_forge_dispatch_stdp_pair, whose prototype (runtime.h L1504) + CUDA kernel emit exist but whose CPU body was never committed to the regenerated self/runtime.c (codegen emits all module fns, no DCE → merely importing the lib pulls the undefined symbol). OP-32b adds the #ifndef HEXA_CUDA host fallback body — the OP-16/18 host-fallback pattern, landed durably via the tracked tool/restore_frozen_seeds idempotent marker-guarded post-restore patch — making spiking_lib 0-GPU linkable + the host dispatch byte-eq vs the proven flame_stdp_pair CPU reference) -->
- [x] **OP-32b — spiking_lib CPU link hole fixed: hexa_forge_dispatch_stdp_pair host fallback (OP-16/18 pattern)** —
  GREEN (0-pod, $0, NO GPU/vast). Closes OP-32 HOLE-2: the flame STDP GPU seam landed header+codegen+CUDA-emit only —
  the runtime.c body was never committed (gitignored frozen seed predates it) → `use spiking_lib` failed to LINK on
  every CPU-only host (`ld: _hexa_forge_dispatch_stdp_pair` undefined; codegen emits all module fns, no DCE).
  FIX = tool/restore_frozen_seeds OP-32b idempotent marker-guarded append (the OP-17/18/19e durable channel):
  `#ifndef HEXA_CUDA` host body for hexa_forge_dispatch_stdp_pair (+ bare forge_dispatch_stdp_pair bootstrap seam,
  matmul pattern) — canonical sequential STDP pair update scalar-order-IDENTICAL to flame_stdp_pair (left-assoc muls,
  (ltp−ltd) order, diagonal passthrough + clip), FP_CONTRACT OFF (anti-fma/fms, the CUDA kernel's __dmul_rn hazard),
  n derived from spike farr len; local install (~/.hx/bin/self/runtime.c) patched with the same block. PROOF: symbol
  U→T (nm T _hexa_forge_dispatch_stdp_pair); spiking_lib import LINKS+RUNS 0-GPU; BYTE-EQ imported flame_stdp_pair_gpu
  (host dispatch) vs flame_stdp_pair n=24 mismatch=0 max|Δ|=0 cksum 347631115==347631115 w/ clip ENGAGED + non-trivial
  movement 0.372 (oracle stdlib/flame/op32b_stdp_hostdispatch_eq.hexa, committed); OP-32 oracle re-run PASS; GPU path
  UNTOUCHED (`clang -E -DHEXA_CUDA` → 0 stdp definitions in the TU — block fully elided, no duplicate symbol possible);
  restore re-run idempotent (marker count 1). Residual (honest): the frozen seed still supplies NO CUDA-side wrapper
  (unchanged by design — GPU-build-gated; natural fix = #ifdef twin calling _hx_cuda_farr_stdp_pair_gpu, 1 GPU session).
  Verdict .verdicts/hexa-0pod/F-OP32B-STDP-HOST.txt.

<!-- ANCHOR:OP-30-CROSSISA-CONTRACT (unique anchor — OP-29 surfaced a cross-cutting find: the C farr_matmul FMA-fused kernel byte-DIVERGES across ISAs (arm64 single-FMA vs x86 mul+add under clang -O2); OP-29 closed it by re-implementing matmul as inline ascending reductions. That contract requirement currently lives only in the OP-29 milestone+verdict — OP-30 formalizes it as a FIRST-CLASS, discoverable invariant in docs/flame-determinism-contract.md so a future contributor can't miss it: flame matmul on the det path MUST route through inline ascending reductions, NOT the FMA-fused farr_matmul) -->
- [x] **OP-30 — cross-ISA matmul invariant formalized in the determinism contract (FMA-fused farr_matmul forbidden on the det path)** —
  DOCS-COMPLETE (0-pod, NO GPU/vast). OP-29's cross-cutting find (the C farr_matmul FMA-fused kernel byte-DIVERGES
  across ISAs — arm64 single-FMA on a*b+c vs x86 mul+add under clang -O2) lived only in the OP-29 milestone+verdict.
  OP-30 promotes it to a FIRST-CLASS, discoverable invariant. (1) docs/flame-determinism-contract.md §1 gains a
  "### cross-ISA invariant: matmul = inline ascending reduction, NOT FMA-fused" section — RULE (det-path matmul MUST use
  inline ascending reductions; FMA-fused farr_matmul forbidden), WHY (clang -O2 fuses a*b+c → 1-rounding FMA on arm64 vs
  mul+add 2-roundings x86; cites OP-29 ck 241449363 arm64 vs 1401117690 x86 on byte-identical fp64 inputs), SCOPE (the
  cross-ISA layer ON TOP of run-to-run + libm-free — a model can be both and STILL cross-ISA-divergent), HOW (use the
  inline-ascending dot the oracles use, OR -ffp-contract=off off the det path) + an ASCII arm64-vs-x86 FMA diagram + a
  "what breaks the contract" checklist entry. (2) docs/flame-machine-independent-training.md gains the 3-LAYER model
  (run-to-run · libm-free · cross-ISA-FMA-free) in §1, a 4th threat-model row T4 (FMA-fused matmul ISA divergence →
  inline ascending dots, F-OP29), a recipe item (d), and an F-OP29/F-OP30 provenance entry. Every claim traces to
  F-OP29-2ND-ARCH (g5). NO new computation, NO .tape edits. Verdict .verdicts/hexa-0pod/F-OP30-CROSSISA-CONTRACT.txt.

<!-- ANCHOR:OP-29-2ND-ARCH (unique anchor — OP-26b gap G2 = a 2nd architecture beyond CLMConvMoE: the 8 oracles + OP-15 capstone all lock the CLMConvMoE step; prove the machine-independent byte-exact determinism construction (dt_exp/dt_sqrt + sequential reductions + ascending accumulation) GENERALIZES to a SECOND flame model arch — a full pre-norm Transformer decoder block (GQA attention + RoPE + SwiGLU + RMSNorm), stdlib/flame/decoder_block_lib) -->
- [x] **OP-29 — machine-independence generalizes to a 2nd flame model arch (G2 closed, or a 2nd-arch libm hole found+closed)** —
  GREEN. OP-26b gap G2 = "a 2nd architecture beyond CLMConvMoE": the 8 per-op oracles + OP-15 capstone all lock the
  SAME CLMConvMoE step. OP-29 proves the machine-independent determinism construction GENERALIZES to a SECOND,
  structurally-different arch: a pre-norm Transformer DECODER BLOCK (stdlib/flame/decoder_block_lib — GQA scaled-dot
  attention + RoPE + SwiGLU + RMSNorm), which shares NO operators with CLMConvMoE (no conv, no MoE, no GroupNorm) and
  exercises a different determinism surface (attention softmax, RoPE rotation, SiLU gate, RMSNorm). ORACLES
  stdlib/flame/op29_decoder_block_determinism_eq.hexa (run-to-run, imports the production lib) +
  stdlib/flame/op29_decoder_block_selfcontained.hexa (cross-platform inline-reduction twin, NO `use`, scp-runnable).
  RESULT: byte-eq run-to-run (fwd Xout · bwd grads · bwd dX all max|Δ|=0) AND cross-platform byte-IDENTICAL on local
  arm64-macos vs aiden x86-linux (free CPU pool host, $0, NO vast/NO GPU) — identical IEEE-754 fingerprints FWD
  `0 0 64 78 44 169 214 65` · GRAD `0 0 128 244 215 140 211 65` on BOTH. TWO 2nd-arch holes found+CLOSED: (#1 libm
  RoPE) the production nn_rope_build_tables computes inv-freq via libm ln/exp — closed with a deterministic
  _rope_build_tables_dt (dt_exp/dt_ln/d5_cos/d5_sin), the OP-19/19b discipline; (#2 FMA matmul — the real find) the
  C farr_matmul kernel (ikj FMA-fused under clang -O2) is NOT machine-independent — on byte-identical fp64 inputs an
  8×8·8×4 matmul byte-diverges arm64 (single FMA on a*b+c) vs x86 (mul+add), bisected to the Q projection — closed by
  re-implementing _db_proj_batch_farr/_db_grad_accum_farr as INLINE ascending dot products (no C kernel), the same
  sequential-reduction discipline the CLMConvMoE oracles use. CONTRACT learned: any flame arch must route matmul
  through inline ascending reductions, not the FMA-fused farr_matmul, to be byte-identical across ISAs. Machine-
  independence GENERALIZES beyond CLMConvMoE → Y. Verdict .verdicts/hexa-0pod/F-OP29-2ND-ARCH.txt.

<!-- ANCHOR:OP-28-CORPUS-LOADER-DET (unique anchor — the 0-pod-feasible slice of gap G1 (real-corpus end-to-end): the trainer STEP is GPU-build-gated but the INPUT side — the data loader / token pipeline (tokenize->pack->batch) producing (ids,targets) — runs on CPU and IS 0-pod-verifiable; byte-eq oracle proving it deterministic + machine-independent, so the real-corpus INPUT is proven reproducible before the GPU step runs) -->
- [x] **OP-28 — real-corpus token-pipeline determinism oracle (0-pod slice of gap G1; input side proven, GPU step still gated)** —
  GREEN. 0-pod slice of OP-26b gap G1 (real-corpus end-to-end, GPU-build-gated): the trainer STEP needs the GPU,
  but its INPUT side — the token pipeline that produces the (ids,targets) tensors fed to clm_step — runs on CPU
  and IS 0-pod-verifiable. THE PIPELINE (verbatim from flame_d32_corpus_test.hexa, the production corpus path):
  (1) tokenize = read_file_bytes(corpus) → byte ids [0,256) [V=256 byte-level vocab, the anima d_corpus_fire
  equivalent]; (2) pack/window = IDS[s*T+p]=toks[s*stride+p], YS[s]=toks[s*stride+T] (pure integer index math,
  fixed ascending (s,p) order); (3) batch = (IDS,YS)==(ids,targets). ORACLE stdlib/flame/op28_corpus_loader_det.hexa
  (SELF-CONTAINED, no `use` → runs via scp/stdin on any host; embedded byte-string corpus = the same bytes
  read_file_bytes yields, disk-free). FINDING: the byte-level token path is PURE INTEGER — NO float, NO libm
  transcendental, NO dict/set/hash-ordered iteration over a vocab — so (ids,targets) are bit-identical run-to-run
  AND across machines BY CONSTRUCTION. PROVEN not just asserted: (a) in-process double-run + process-to-process
  full-output diff → (ids,targets) byte-eq run-to-run max|Δ|=0; (b) CROSS-PLATFORM — local arm64-macos vs aiden
  x86-linux (free CPU pool host, $0, NO vast/NO GPU) emit the byte-IDENTICAL IEEE-754 fingerprint `0 0 0 216 16
  88 186 65` (checksum 441979096) + identical ids/targets. HONEST: the GPU TRAINER STEP (nn_decoder_fwd/grad/AdamW
  on the (ids,targets)) is the GPU-build-gated remainder of G1 — NOT closed here, by design; this closes the
  INPUT-side 0-pod slice. RESIDUAL input-side item: the BPE path (V=151936) is also documented-integer but flame's
  BPE has a known upstream chr()-unicode limitation (not cleanly 0-pod-runnable today) — flagged, not locked. $0 ·
  0-GPU · 0-pod · no vast. Verdict .verdicts/hexa-0pod/F-OP28-CORPUS-LOADER-DET.txt.

<!-- ANCHOR:OP-23B-TF32-DRIFT-LONG (unique anchor — extend OP-23's TF32 trajectory-drift validation to N=500 + an LR schedule (warmup+cosine decay) + a harder synthetic; does bounded loss-tracking hold at the longer/harsher horizon, or does a late blow-up / LR-amplified drift appear; aiden 5070, 0-pod) -->
- [x] **OP-23b — TF32 drift N=500 + LR-schedule: bounded-tracking holds at longer/harsher horizon (or honest late-blowup bound)** —
  GREEN. Extended OP-23's TF32-vs-FP64 trajectory-drift harness to a LONGER + HARSHER regime: N=500 (5x),
  a standard transformer LR schedule (linear warmup 50 steps 0->1e-3 then cosine decay to 5e-5, computed
  in double + passed identically to both lanes), and a harder structured synthetic (row/col sinusoidal
  target, D bumped to 1024). 4/4 cells on aiden RTX 5070 (D={1024,768}, B={1,8}, DEFAULT+PEDANTIC), FREE
  pool, $0, 0-pod. RESOLVES OP-23's caveat in the GOOD direction: (1) loss-tracking stays BOUNDED to N=500
  — worst gap is at step 3-5 (EARLY transient), late-half (steps>250) worst is SMALLER (3.2e-6 / 2.2e-7)
  and flat, step-500 tracking 1.1e-7 (B=8) to 3.4e-6 (B=1), NO late blow-up; (2) the LR schedule does NOT
  amplify — warmup-peak window [45..55] worst loss-track (~3e-6 / ~3e-7) is the SAME order as steady-state,
  the 1e-3 peak is not a spike; (3) TF32 self-byte-eq over the WHOLE 500-step trajectory (W AND loss
  max|delta|=0 at step 500) in every cell. Weight rel-RMS at N=500 is 9.7e-3 (B=1) / 4.6e-5 (B=8) —
  chaotic-but-bounded (5x more steps + harder target + noisy B=1), EXACTLY why LOSS not weights is the
  decisive metric (butterfly drifts weights; loss tracks). VERDICT: TF32 fast-mode HOLDS at the longer/
  harsher horizon — training-equivalent (bounded loss-tracking) to >=N=500 under an LR schedule; strengthens
  OP-23 (the 1-step ~1e-6 was a real fast-mode, not an illusion, now bounded at 5x the horizon + through the
  warmup peak). HONEST SYNTHETIC CAVEAT (unchanged): still a proxy (loss=mean(G^2), single fused block,
  structured-synthetic target) — the real-corpus CLMConvMoE end-to-end read is GPU-build-gated (OP-24b/24c).
  Harness tool/bench/flame_traj_drift_tf32_op23b.cu · driver run_op23b_5070.sh · raw op23b_5070_raw.log ·
  verdict .verdicts/hexa-0pod/F-OP23B-TF32-DRIFT-LONG.txt.

<!-- ANCHOR:OP-27-TF32-DOJO (unique anchor — reflect the VALIDATED deterministic TF32 fast-mode OP-20/23/24/25 into the dojo as a contributor recipe; 0-pod docs; flag the commons.tape governance reflection for user sign) -->
- [x] **OP-27 — deterministic TF32 fast-mode dojo recipe (0-pod) + commons directive drafted for user sign** —
  DOCS-COMPLETE (0-pod half SHIPPED). Added `### deterministic TF32 fast-mode (precision-uncap)` to
  docs/hexa-dojo.md (after the g86 fair-bench section): when to use HEXA_TF32_FASTMODE (>3× keeping run-to-run
  determinism, FP64 default byte-identical flag-off), the determinism guarantee (self-byte-eq max|Δ|=0 single-step
  + whole 100-step trajectory; PIN CUBLAS_PEDANTIC_MATH for portable cross-card guarantee), the W14 rel-RMS≤1e-2
  contract (1.13e-6 post-AdamW weight, ~2.9e-4 raw live-GEMM), the card-robust 4.2×@B=1 (B=8 19-21× FP64-throttle-
  caveated), N-step loss-tracking (~1e-7/step, bounded ~5e-7 weight drift → real fast-mode not 1-step illusion),
  the precision Pareto (FP64 exact 1× → TF32 e-6 4.2× SWEET SPOT → BF16 e-6 4.1× DOMINATED) + ASCII diagram, and
  the live-wire dispatch site (self/cuda/runtime_cuda_emit.hexa `_hx_cuda_farr_matmul_gpu`). Every number CITED
  from a verdict (g5), elephant-rule. COMMONS half DRAFTED ONLY (g87_tf32_fastmode do/dont ≤100char/line, ASCII)
  → awaits user `sidecar sign commons` (agent CANNOT self-sign). NO .tape edited. $0 · 0-pod · no GPU · no vast.
  Verdict .verdicts/hexa-0pod/F-OP27-TF32-DOJO.txt (dojo summary + drafted directive verbatim + governance note).

<!-- ANCHOR:OP-26-MACHINEINDEP-WRITEUP (unique anchor — consolidate the OP-19/19b + oracle-series machine-independent bit-exact training RESULT into a rigorous evidence-complete results doc; docs-only; NO /paper scaffold per g84 OPT-IN) -->
- [x] **OP-26 — machine-independent bit-exact training: rigorous results writeup (evidence-complete, docs-only, NO paper scaffold)** —
  DOCS-COMPLETE. Authored docs/flame-machine-independent-training.md — a rigorous, evidence-complete RESULTS
  document (NOT a paper) consolidating the HEXA-0POD result that the flame CLMConvMoE step is FULLY
  machine-independent byte-exact (same weights/loss to the bit on ANY IEEE-754 arch/OS — a property
  torch/JAX do NOT give, since libm transcendentals are not correctly-rounded across platforms). Contains:
  (a) THE CLAIM, (b) the THREAT MODEL (libm transcendentals not correctly-rounded · tree-reduction
  nondeterminism · atomic-scatter order → flame closure → verdict, with ASCII closure diagrams), (c) an
  EVIDENCE TABLE citing 12 verdicts (8 per-phase oracles + F-OP15 capstone + F-OP19/19b cross-platform byte
  folds + F-OP23 TF32) with byte-cmp values + ULP divergences + platforms, (d) the DETERMINISM CONSTRUCTION
  recipe (dt_exp/dt_erf/_moe_exp/dt_ln + Newton sqrt + sequential reductions + ascending accumulation +
  fixed foldings + deterministic init), (e) HONEST LIMITS (1.38e-7 erf-vs-libm by design · TF32 self-not-
  cross-precision · single-machine GPU scope · B>1 conv seam · build-deferred final read). Every number
  traces to a cited verdict (g5); no new computation — verified by reading the existing verdicts. Pointer
  added from docs/flame-determinism-contract.md (the contributor SSOT). GOVERNANCE (project.tape g84 PAPER
  OPT-IN): logged-discovery consolidation ONLY — NO /paper scaffolded, NO PAPER.tape/PAPER.md, paper skill
  NOT invoked. $0 · 0-GPU · 0-pod · no vast. Verdict .verdicts/hexa-0pod/F-OP26-MACHINEINDEP-WRITEUP.txt.

<!-- ANCHOR:OP-26B-SUBMISSION-READINESS (unique anchor — submission-readiness assessment for the machine-independent bit-exact training result, capturing the NOW-4-environment evidence stronger than OP-26's doc; readiness checklist DONE-vs-paper-ADD + gap list + novelty argument; NO /paper scaffold per g84 OPT-IN) -->
- [x] **OP-26b — machine-independent training SUBMISSION-READINESS assessment (4-env evidence; NO paper scaffold, g84)** —
  DOCS-COMPLETE. Authored docs/flame-machine-independent-SUBMISSION-READINESS.md — a go/no-go readiness
  assessment (NOT a paper) so the user can decide whether/when to instruct /paper. Extends OP-26's results
  doc to the NOW-4-environment evidence base: (a) THE CLAIM in its strongest current form — machine-independent
  bit-exact NN training byte-identical across {x86,arm64}×{linux,macos} + musl, spanning 3 DISTINCT libm
  impls (glibc·musl·Darwin), STRONGER than OP-26's 2-platform consolidation (OP-19c pi5 arm64-linux 3rd cell;
  OP-19d musl 4th env / 3rd libm; OP-19e durable POSIX-environ fix → real un-shimmed musl run); (b) READINESS
  CHECKLIST — DONE (result + 8 oracles + 4-env evidence + threat model + recipe + honest limits, all → verdicts)
  vs what a PAPER ADDS (abstract · related-work survey · figures · repro Docker · venue fit); (c) GAP LIST
  G1-G6 (G1 real-corpus e2e = GPU-build-gated HIGH · G2 2nd arch · G3 x86-macos blocked · G4 perf↔det Pareto
  · G5 cross-GPU-arch byte · G6 musl CI-gate); (d) NOVELTY ARGUMENT (torch/JAX give NO cross-platform bit-exact
  training; flame removes ALL libm — MEASURED: libm erf = 4 values, dt_* identical on all 4) + ASCII go/no-go
  diagram. Every claim traces to F-OP15/19/19b/19c/19d/19e + OP-26 (g5); no new computation. GOVERNANCE
  (project.tape g84 PAPER OPT-IN): NO /paper scaffolded, NO PAPER.tape/PAPER.md/LaTeX, paper skill NOT invoked
  — the doc ends with the explicit user action (USER runs `/paper new flame-machine-independent`, agent does
  NOT auto-scaffold). $0 · 0-GPU · 0-pod · no vast. Verdict .verdicts/hexa-0pod/F-OP26B-SUBMISSION-READINESS.txt.

<!-- ANCHOR:OP-24-TF32-LIVEWIRE (unique anchor — wire OP-20's validated deterministic TF32 fast-mode into the live forge GEMM dispatch, env-gated, byte-eq-safe, aiden verify) -->
- [x] **OP-24 — wire deterministic TF32 fast-mode into the live forge GEMM dispatch (env-gated, byte-eq-safe, aiden verify)** —
  GREEN (dispatch-unit). OP-20's PROVEN deterministic TF32 fast-mode is now an env-gated OPT-IN
  (HEXA_TF32_FASTMODE) branch in the LIVE forge projection-GEMM dispatch `_hx_cuda_farr_matmul_gpu`
  (self/cuda/runtime_cuda_emit.hexa — the path the real CLMConvMoE trainer rides; same fn OP-2 wired).
  FP64 cublasDgemm stays the DEFAULT, byte-identical when the flag is off; the TF32 branch casts the
  FP64 farr device buffers down to fp32, runs cublasGemmEx CUBLAS_COMPUTE_32F_FAST_TF32 on a PEDANTIC-
  pinned handle (OP-20's portable self-byte-eq guarantee), casts the result back up. Durable landing =
  the tracked runtime_cuda_emit.hexa SSOT (NOT a frozen seed — no restore_frozen_seeds patch needed).
  aiden RTX 5070 dispatch-unit verify (op24_tf32_livewire_dispatch.cu replays the EXACT wired codepath),
  4/4 cells PASS all 3 gates: GATE-A FP64-default byte-identical max|Δ|=0; GATE-B TF32-live self-byte-eq
  max|Δ|=0 (PEDANTIC confirms determinism); GATE-C W14-tol rel-RMS ~2.9e-4 (~34x inside 1e-2);
  SPEED 29.9–51.0x (GEMM-only; OVERSTATES the trainer step — consumer-5070 FP64 ~1/64 throttle + no
  glue dilution; card-robust signal = OP-20's B=1 ~4.2x). HONEST (g5): dispatch-UNIT, not full-trainer
  — full end-to-end needs the clm_prod_gpu GPU build (OP-2b-class; exact remaining step named in verdict:
  build with -DHEXA_CUDA, run trainer HEXA_TF32_FASTMODE=1 vs unset, report loss self-byte-eq + wall
  step/s). FREE aiden, $0, no vast/pod/leak. Verdict .verdicts/hexa-0pod/F-OP24-TF32-LIVEWIRE.txt.

<!-- ANCHOR:OP-24B-TF32-ENDTOEND (unique anchor — complete OP-24's TF32 live-wire end-to-end through the REAL clm_prod_gpu CLMConvMoE trainer: attempt the -DHEXA_CUDA build on aiden 0-pod; if it builds, run FP64 vs HEXA_TF32_FASTMODE=1 and report FP64-unchanged + TF32 self-byte-eq + loss-track + live step/s; else honest build-gated step + well-formed-in-DHEXA_CUDA proof) -->
- [x] **OP-24b — TF32 fast-mode end-to-end through the REAL clm_prod_gpu trainer (aiden build) OR honest build-gated step** —
  HONEST BUILD-GATED (OP-2b-class; g5 OR-branch). Attempted the clm_prod_gpu -DHEXA_CUDA build on aiden
  (FREE RTX 5070 sm_120, nvcc 13.0, $0). clm_prod_gpu BUILT ON AIDEN = NO — blocked at a precisely-named
  SOURCE-completeness step (NOT a toolchain/host gap; aiden's toolchain compiles fine). The real trainer
  stdlib/flame/clm_prod.hexa (1421 L CLMConvMoE corpus loop) calls 31 forge_dispatch_<op> ops whose HOST
  marshal wrappers `hexa_forge_dispatch_<op>(HexaVal...)` must live in a consistent runtime.c. MEASURED:
  the authoritative frozen seed runtime.c (151c52c82, restored by tool/restore_frozen_seeds) provides only
  2/31 (matmul + ffn_fp64_via_bf16); the other 30 are in NO git-tracked current-main source — 24 live only
  in the UNTRACKED inbox patch forge-devfeed-lever-a-runtime-c-fragment.c.txt (749 L, stale worktrees only),
  ~6 were hand-spliced on the gone W2 pod + never re-frozen. restore_frozen_seeds appends ONLY OP-18
  #ifndef HEXA_CUDA host FALLBACKS, not the #ifdef HEXA_CUDA device marshal wrappers. = the SAME terminal
  wall project_clmprod_gpu_build_seed_drift documents, now quantified at current main (2/31 present, 30
  missing). UNBLOCK (maintainer/CI one-time): re-freeze a runtime.c seed carrying all 31 #ifdef HEXA_CUDA
  host wrappers, OR add a CUDA build job to release.yml. WHAT IS 0-POD WAS DELIVERED: the OP-24 TF32 branch
  is PROVEN WELL-FORMED + CODEGEN-COMPLETE in the REAL -DHEXA_CUDA context — emitted runtime_cuda.c (current-
  main SSOT, 334KB, TF32 wire present) COMPILES CLEAN under `nvcc -x cu -DHEXA_CUDA -arch=sm_120` to a 3.4 MB
  object on aiden (only benign warnings, none in TF32 code); `nm` confirms ALL TF32 symbols emitted
  (_hx_k_cast_d2f/f2d, g_cublas_tf32 PEDANTIC handle, _hx_cuda_gemm_tf32_dev, _hx_cuda_farr_matmul_gpu with
  the TF32 else-if branch; only external cublasGemmEx/cublasSetMathMode undefined → -lcublas at link). So
  the ONLY gap to end-to-end is the RUN, not the code; NO end-to-end trainer run claimed (g5). BONUS 0-pod
  finding: the first -DHEXA_CUDA compile surfaced a PRE-EXISTING OP-19b regression — `_hx_dt_exp_dev` is
  emitted TWICE in runtime_cuda.c (line 1624 + dead line-4092 Taylor variant; OP-19b's "defined ONCE above"
  comment didn't remove the 2nd), a latent emit bug that only breaks under nvcc -DHEXA_CUDA (the 0-GPU blind
  spot OP-15 named). Isolated it (renamed the dead def) for the proof; trivial 0-pod follow-up = delete the
  line-4092 block from runtime_cuda_emit.hexa. FREE aiden, $0, no vast/pod/leak, foreign pod 40306156
  untouched. Verdict .verdicts/hexa-0pod/F-OP24B-TF32-ENDTOEND.txt.

<!-- ANCHOR:OP-24C-TF32-TURNKEY (unique anchor — turn OP-24b's honest build-gated finding into a ONE-COMMAND turnkey build+run+gate kit for the TF32 end-to-end test, mirroring OP-21A's build_w16.sh: code+script ready, the GPU build+run env-gated; local-checked 0-pod, no GPU run) -->
- [x] **OP-24c — TF32 end-to-end TURNKEY build kit (build_clmprod_tf32_e2e.sh), local-checked, GPU-build-gated run** —
  KIT-READY, RUN-GATED (0-pod; write + local-check only; NO GPU, NO build, NO run; $0; foreign pod 40306156
  untouched). Turned OP-24b's honest build-gated finding into a TURNKEY ONE-COMMAND script
  tool/clm/build_clmprod_tf32_e2e.sh — the moment a complete-frozen-seed GPU-build env is authorized, the
  whole TF32 end-to-end test is `bash tool/clm/build_clmprod_tf32_e2e.sh`. Mirrors the OP-21A pattern
  (tool/wgmma/build_w16.sh) EXACTLY: code+script written + local-checked, GPU half documented-gated, no
  number claimed. STRUCTURE: (a) ZERO-VAST provision+idle guard (exits clean if no nvcc / no sm_120+ GPU);
  (b) frozen-seed stage (FROZEN_SEED_REF=151c52c8… restore_frozen_seeds) + EXACT-BLOCKER pre-check that
  greps the restored runtime.c for the 31 host marshal wrappers and, if any missing, prints the F-OP24B
  blocker verbatim + EXITS 3 before wasting a build + nvcc -DHEXA_CUDA -lcuda build of the TF32-wired
  runtime (with the §4 _hx_dt_exp_dev dup-def NOTE-guard); (c) run the real CLMConvMoE trainer x2 each FP64
  default + HEXA_TF32_FASTMODE=1, tiny config (CLM_PROD_* knobs all verified in main()); (d) g5 gate
  sequence — GATE-A FP64-unchanged (run1==run2 max|Δ|=0) / GATE-B TF32 self-byte-eq / GATE-C TF32-tracks-FP64
  (OP-23 E2E, worst |Δloss|/|loss_FP64| <= W14 1e-2) / SPEED wall step/s ratio reported ONLY after A+B+C
  PASS with the honest glue-dilution caveat; (e) verdict headline + leak-0 cleanup trap. LOCAL CHECK:
  bash -n PASS; all referenced paths/flags/env-knobs verified (restore_frozen_seeds, runtime_cuda_emit.hexa,
  clm_prod.hexa main(), frozen ref resolves, 6 CLM_PROD_* knobs present); self/runtime.c correctly absent at
  main (graduated seed restored by the script's own step b.1 BEFORE step b.2 greps it — ordering correct).
  EXACT REMAINING GPU-BUILD-ENV-GATED STEP (F-OP24B-confirmed): re-freeze a runtime.c seed with all 31
  #ifdef HEXA_CUDA host wrappers (currently 2/31), OR add a CUDA build job to release.yml; THEN the script
  runs unchanged + its pre-check passes. Turnkey = YES; honest (no end-to-end number claimed). Verdict
  .verdicts/hexa-0pod/F-OP24C-TF32-TURNKEY.txt.

<!-- ANCHOR:OP-25-BF16-FASTMODE (unique anchor — next precision-uncap rung: deterministic BF16 fast-mode; self-byte-eq + W14-tol vs FP64 + speed vs TF32; precision Pareto placement BF16-vs-TF32; aiden 5070) -->
- [x] **OP-25 — deterministic BF16 fast-mode: self-byte-eq + W14-tol + speed vs TF32 (precision Pareto, aiden)** —
  GREEN gates / DOMINATED outcome (honest closed result). Probed the precision-uncap ladder's NEXT rung after
  OP-20 TF32: a deterministic BF16 step fast-mode (CUBLAS_COMPUTE_32F_FAST_16BF, bf16 GEMM operands, fp32 master
  weights+AdamW+glue = standard mixed-precision contract). 3-lane (BF16/TF32/FP64) harness + drift, aiden RTX 5070
  FREE pool, 8/8 1-step cells + 4/4 drift cells (DEFAULT+PEDANTIC × D={768,1536} × B={1,8}). (1) BF16 SELF-BYTE-EQ
  YES — max|delta(W',loss)|=EXACTLY 0 every cell + over the whole 50-step trajectory; PEDANTIC NOT needed (DEFAULT
  bf16 tensor-op already deterministic, identical bytes+time — same as TF32/OP-20). (2) rel-RMS vs FP64 ~1.1e-6
  (NOT the expected ~1e-3) — because fp32 MASTER weights mean only GEMM operands are bf16, so the bf16 e-3 GEMM
  error enters W via one tiny optimizer step → e-6; essentially EQUAL to TF32's 1.13e-6, well inside W14 1e-2.
  (3) SPEED: BF16/FP64 = 3.88-4.10× @B=1 (same as TF32); BF16-vs-TF32 = TF32/BF16 1.01-1.12× → BF16 at most ~12%
  faster @B=8 (half-input-bytes mem traffic, NOT compute) and a DEAD HEAT @B=1 (1.01-1.02×, the latency regime the
  ~3× cap names). On the 5070 BF16 & TF32 are both 16-bit-input tensor-ops at EQUAL throughput → no GEMM-cost edge.
  (4) DRIFT N=50: BF16 LOSS TRACKS FP64 (worst loss-track gap 9.4e-5/1.7e-4, bounded, no peel; weight rel-RMS ~e-6,
  does NOT grow — chaotic-but-microscopic, same shape as OP-23's TF32 drift) → real trainable fast-mode, not a
  1-step illusion. PARETO: FP64(exact,1×) → TF32(e-6,4.2×) → BF16(e-6,4.1× = SAME accuracy + SAME speed as TF32).
  ==> BF16 is Pareto-DOMINATED by TF32: not worse, but not better on either axis → no reason to prefer it. TF32
  stays the precision-uncap TERMINAL SWEET SPOT; the BF16 rung is a NO-OP on consumer hardware. Verdict
  .verdicts/hexa-0pod/F-OP25-BF16-FASTMODE.txt; harness tool/bench/flame_bench_step_bf16fast.cu +
  flame_traj_drift_bf16_op25.cu; raw op25_5070_raw.log + op25_drift_5070_raw.log. $0, no vast/pod/leak.

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

<!-- ANCHOR:OP-21A-W16-KERNEL (unique anchor — OP-21A's designed lever turned into WRITTEN wgmma_tf32_w16.cu + turnkey build kit; local-checked, perf H100-gated) -->
- [x] **OP-21A — Hopper warp-spec TMA kernel WRITTEN (wgmma_tf32_w16.cu) + turnkey build kit, local-checked, H100-gated perf** —
  turned the OP-21 DESIGN (#3000) into CODE: WROTE self/native/wgmma/wgmma_tf32_w16.cu implementing all five
  OP-21A deltas vs the W10 frontier (each adapted line citing wgmma_tf32_w10_lib.h) — D1 canonical-atom landing
  (enc_canonical + MODE 0/1 probes = the falsifiable D1 gate), D2 descriptor-direct wgmma via mk_sw(swmode=1)
  DELETING the 32KB software decode band (96->64KB/CTA, W15-measured), D3 NST=3 decode-free swizzled-TMA ring,
  D4 wgmma.wait_group<NST-2> (literal 1) back-to-back across K-slabs (replaces W10's wait_group 0), D5 dedicated
  producer WG setmaxnreg.dec 40 / consumer WGs setmaxnreg.inc 232 (384 thr, UNBLOCKED at the 128x128 tile's
  64-reg accumulator unlike W12's 128x256) with -DW16_PRODUCER_WG=0 single-elected-thread fallback; + gemm_w16b
  OP-21B fallback (keep band, no M3 dependency). #include w10-lib for the SAME-BINARY gemm_w10 + cuBLAS-TF32
  apples baseline. LOCAL 0-pod CHECK (no nvcc locally): host-side C++ structural parse (clang++ -fsyntax-only,
  CUDA stubbed, device-PTX neutralized) PASSES for BOTH build paths (exit 0); rigorous sm_90a ISA-level review
  of the authored PTX (wait_group/commit_group/setmaxnreg literals, mbarrier.arrive, fence.proxy.async, mk_sw
  bit-packing, GMMA 8x4 const) — no discrepancy; the one unproven element D1 is the pre-registered falsifier
  gated by MODE 1, not asserted. WROTE the turnkey tool/wgmma/build_w16.sh (bash -n valid): one-command
  provision-checklist (NO auto-rent, ZERO-VAST) -> nvcc -arch=sm_90a -Xptxas -v build (C7507 setmaxnreg detect)
  -> MODE 9 canonical dump -> MODE 0/1 gates (D1 falsifier, field sweep, OP-21B switch on floor) -> MODE 4
  bit-exact gate + occupancy + perf sweep @2048/4096/8192 x NST{3,4,2} vs same-binary w10+cuBLAS -> SASS ->
  Δ-vs-W10-70.7 -> destroy leak-0; g5 gate order enforced. HONEST (g5): device-PTX compile + ALL perf is
  H100-GATED — NO number produced or claimed; the exact gated step is `nvcc -O3 -arch=sm_90a wgmma_tf32_w16.cu
  -o w16 -lcublas -lcuda -Xptxas -v` on an authorized H100. W10 70.7 frontier KEPT (the W11/W12/W13 hard rule).
  Value = the lever is now CODE not just design — H100 authorization -> turnkey measurement. $0, no vast/pool/pod.
  Verdict .verdicts/hexa-0pod/F-OP21A-W16-KERNEL.txt (PR #3017).

<!-- ANCHOR:OP-21B-W16-CPU-DERISK (unique anchor — OP-21A's riskiest GPU-free element D1 CPU-validated 0-pod via a clang++ canonical-atom harness; de-risks the H100 bit-exact gate) -->
- [x] **OP-21B — w16.cu canonical-atom encoder CPU-validated 0-pod (de-risks the H100 bit-exact gate)** —
  de-risked OP-21A's D1 (the canonical-atom re-encode, the pre-registered MODE-1 falsifier) BEFORE the H100 run
  by validating its GPU-FREE arithmetic on a CPU. WROTE tool/wgmma/w16_canon_cpu_check.cpp (clang++ -std=c++17,
  ZERO GPU/CUDA/PTX) that ports the pure-arithmetic SSOT VERBATIM from w10_lib.h (gmma_phys 8x4 INTER core,
  sw128_measured 128B-swizzle index, tf() TF32 round) + the EXACT composed read laws hard-coded in w16.cu, and
  asserts 7 element-for-element checks: T1 sw128_measured is a bijection over each 8x32 atom (the landed swizzle
  MUST be a permutation or the in-place read cannot recover A); T2 w16.cu w16_probe_canon L175 law
  `a*256 + r*32 + (((k>>2)^(r&7))<<2) + (k&3)` == the W10-proven `a*256 + sw128_measured(r,k)` element-for-element
  (proves w16's copy did not drift); T3 the composed A-read recovers global A bit-exact on the 128x32 box
  (the MODE-0 gate simulated on CPU, exact 4096/4096); T4 gmma_phys is a bijection over the 64x8 wgmma operand
  sub-tile; T5 the per-slab B-read recovers global B bit-exact (exact 2048/2048); T6 the reference GEMM math is
  TF32-round-inputs + fp32-FMA accumulate (so MODE-4's bit-exact-vs-cuBLAS gate checks the RIGHT reference); T7
  the D1 descriptor-stride byte arithmetic is self-consistent (atom=1024B=SBO default, swrow=128B, 1KB swizzle
  period, k8 bump=32B). RAN locally: 7/7 PASS, exit 0 — the canonical-atom encoder GPU-free logic is CPU-PROVEN
  correct, NO bug found. HONEST (g5): this proves the GPU-FREE half of D1 only; the DEVICE wgmma swmode=1
  de-swizzle actually reading the descriptor as this law predicts (MODE-1 rel_rms 0) + ALL perf REMAIN
  H100-GATED — no wgmma/PTX executed, no TFLOP/s claimed. Value = the riskiest GPU-free part of w16 (the
  canonical-atom encode/read, W15's root-cause) is now CPU-verified, raising the H100 D1 first-try success odds.
  $0, no vast/pool/pod/GPU. Verdict .verdicts/hexa-0pod/F-OP21B-W16-CPU-DERISK.txt.

<!-- ANCHOR:OP-21C-W16-MODES-DERISK (unique anchor — extends OP-21B by CPU-validating the REMAINING-MODE GPU-free reference logic of w16.cu — MODE-4 full-tile ref + epilogue scatter, the B-ring read, the gemm_w16b fallback ref, the descriptor stride consistency — so more of the H100 gate sequence is pre-validated 0-pod) -->
- [x] **OP-21C — w16.cu remaining-MODE reference logic CPU-validated 0-pod (extends OP-21B; more of the H100 gate de-risked)** —
  EXTENDED OP-21B's D1 CPU de-risk to the OTHER w16.cu MODEs' GPU-free reference logic, so more of build_w16.sh's
  H100 gate sequence (not just MODE 0/1) is pre-validated. WROTE tool/wgmma/w16_modes_cpu_check.cpp (clang++
  -std=c++17, ZERO GPU/CUDA/PTX) that ports the SSOT arithmetic VERBATIM (gmma_phys, tf() TF32 round, composed_A/
  composed_B) + models the device epilogue register->global scatter VERBATIM from gemm_w16 L395-403, and asserts 6
  element-for-element / bit-exact checks: C1a the epilogue scatter is a BIJECTIVE FULL COVER of the 128x128 output
  tile (every output written exactly once — gates MODE 4 regardless of the GEMM math); C1b the MODE-4 FULL-TILE
  (128x128) reference GEMM = TF32-round + fp32-FMA accumulated in the kernel's K-order (TKSW=32 slabs, TK=8 inner,
  K=96 so NST=3 turns) reproduces a straight increasing-k TF32-round + fp32-FMA GEMM bit-for-bit (extends T6's 8x8
  to full tile -> MODE-4's vs-cuBLAS gate checks the RIGHT reference at scale); C2 the B per-slab read recovers
  global B bit-exact across ALL NST=3 slabs AND all 4 N-atoms (extends T5's single slab/2 atoms; exact 12288/12288);
  C3 the gemm_w16b fallback band decode (composed_A/B -> gmma_phys repack) reconstructs the SAME logical operands
  gemm_w16 reads in place (A=4096/4096 B=4096/4096); C3b the w16b per-slab 128x128 GEMM == the w16 per-slab GEMM
  element-for-element (16384/16384 — same math, different schedule); C4 the descriptor stride byte arithmetic is
  self-consistent across the NST=3 stages (ring slot st*SWBUF non-overlap/contiguous, w16 kk*4 bumps tile a 128B
  swizzle row [0,32,64,96]B, w16b (kk>>3)*512*4 bumps tile the 4 gmma sub-tiles [0,2k,4k,6k]B, MODE-1 lbo=16/sbo=
  1024 match the 1024B atom). RAN locally: 6/6 PASS, exit 0 — the remaining-MODE GPU-free reference logic is
  CPU-PROVEN correct, NO bug found (teeth confirmed: an injected wrong-xor drops the B round-trip to 2190/4096).
  HONEST (g5): proves GPU-FREE reference logic only; the DEVICE wgmma swmode=1 HW de-swizzle (MODE 1 rel_rms 0,
  MODE 4 rel_rms <=3e-3 vs cuBLAS), the gemm_w16b device band path, and ALL perf REMAIN H100-GATED — no wgmma/PTX
  executed, no TFLOP/s claimed. Value = MORE of the w16 H100 gate sequence (MODE 4 full-tile ref + epilogue, the
  B-ring read, the w16b fallback, the descriptor stride consistency) is CPU-pre-validated -> higher first-try odds.
  $0, no vast/pool/pod/GPU; build temp cleaned. Verdict .verdicts/hexa-0pod/F-OP21C-W16-MODES-DERISK.txt.

<!-- ANCHOR:OP-21D-W16-HARDEN (unique anchor — the 0-pod-feasible completeness pass for the H100-gated w16 perf: dry-run + harden tool/wgmma/build_w16.sh into a bullet-proof turnkey kit (no-GPU/no-nvcc clean exit, MODE 0/1 HARD-GATE STOP-before-perf, leak-0 DESTROY trap on every exit) + the OP-29 (#3042) FMA-reference cross-cut check confirming w16's MODE-4 gate cannot be false-failed by cross-ISA FMA divergence; H100 perf measurement STILL gated) -->
- [x] **OP-21D — build_w16.sh hardened + dry-run + OP-29 FMA-ref check (turnkey bullet-proof; H100 perf still gated)** —
  the 0-pod-feasible completeness pass over the H100-GATED w16 perf measurement (NO GPU, NO vast). (a) DRY-RAN +
  HARDENED tool/wgmma/build_w16.sh: bash -n VALID; structural walkthrough confirmed the gate ORDER is correct
  (provision-guards -> build -> MODE 9 dump -> MODE 0 HARD GATE -> MODE 1 D1-falsifier HARD GATE + field sweep +
  OP-21B fallback on floor -> MODE 4 bit-exact gate + perf -> SASS -> DESTROY). Added guards: `set -o pipefail`;
  NVCC_MISSING clean early-exit (instructions); NO_GPU clean early-exit when nvidia-smi absent/empty OR compute_cap
  != 9.0 (refuses to build for the wrong arch; ZERO-VAST — no auto-rent, only checks an already-provisioned host);
  MODE 0 + MODE 1 are HARD GATES that `die` BEFORE any MODE 4/perf (no TFLOP/s on a falsified read law); MODE 4
  per-(S,NST) rel_rms FAIL prints NO perf for that cell + a final STOP if EVERY cell floored; and an EXIT trap that
  prints the leak-0 DESTROY reminder on EVERY exit path (success OR failure/abort). DRY-RAN on the 0-pod box: both
  NVCC_MISSING and NO_GPU paths exit clean (code 1) with copy-paste instructions and the DESTROY trap fires. (b) the
  OP-29 (#3042) FMA cross-cut: AUDITED w16's gate references — WROTE tool/wgmma/w16_op29_ref_check.cpp (clang++,
  0-pod) proving MODE-1's CPU reference is the OP-29-SAFE inline ascending `acc += a*b` (NOT fmaf-fused; mul+add are
  separate statements so -ffp-contract cannot synthesize an FMA; deterministic re-run; == w16.cu L558 verbatim; the
  addmul-vs-FMA Δ is << the 3e-3 gate tolerance), AND that MODE-4's reference is cuBLAS-TF32 ON DEVICE (cublasSgemm +
  CUBLAS_TF32_TENSOR_OP_MATH, w16.cu L645-647) with NO CPU FMA at all — so the OP-29 cross-ISA FMA-divergence failure
  mode is STRUCTURALLY ABSENT from the MODE-4 gate and CANNOT false-fail it; the device wgmma K-accumulation order is
  well-defined (ascending k, slab-order == flat-order 16384/16384). RAN locally: 4/4 PASS, exit 0. HONEST (g5): the
  H100 perf measurement REMAINS GATED — no wgmma/PTX executed, no TFLOP/s claimed; value = the build kit is now
  bullet-proof turnkey + the OP-29 subtlety is checked OFF for w16's gate -> highest H100 first-try odds. $0, no
  vast/pool/pod/GPU. Verdict .verdicts/hexa-0pod/F-OP21D-W16-HARDEN.txt.

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

<!-- ANCHOR:OP-19B-DET-ERF (unique anchor — seals the GELU erf cross-platform hole OP-19 deferred; the LAST libm transcendental in the step) -->
- [x] **OP-19b — pure-FP deterministic erf seals GELU → flame FULLY machine-independent byte-exact (0-GPU)** —
  Closed OP-19's measured latent residual: the GELU `erf` path (fwd `GELU(x)=x·0.5·(1+erf(x/√2))` + bwd
  `GELU'=Φ+x·φ`). Implemented `dt_erf` (flame_math.hexa) = Abramowitz & Stegun 7.1.26 rational with the single
  exp routed through OP-19's deterministic `dt_exp` Taylor — pure +,-,*,/ + dt_exp, **NO libm, NO other
  transcendental**. KEY: BRANCHLESS in z (only the z=0 odd sign flip). A first cut used a Maclaurin series +
  hard clamp at |z|≥4; that PIECEWISE form broke max|Δ|=0 because the GELU argument straddles the branch
  boundary under in-register-vs-stored-reload rounding (measured 2e-7 fused≠unfused). The unconditional A&S form
  has no value-dependent boundary to straddle → byte-eq restored. max|dt_erf − libm erf| = 1.38e-7 (≤ GELU
  tolerance; honest g5 — trades "matches libm erf" for "matches across ALL platforms"). Wired host (nn_lib
  `_nn_normal_cdf`/`_pdf` + gn_lib `_gn_gelu`) + reference (clm_conv_devfeed) + device (`_hx_dt_erf_dev` shared by
  `_hx_k_gelu`/gelu2/`_hx_gelu_dev`/gelu_bwd; `_hx_dt_exp_dev` hoisted) + host C fallback (restore_frozen_seeds
  `_op18_gelu` → dt_erf, BYTE-IDENTICAL to the hexa dt_erf, fold 93,35,192,253,183,12,237,63 @1.19071). CROSS-
  PLATFORM ORACLE (stdlib/flame/op19b_crossplatform_erf.hexa, self-contained): det-erf GELU fwd+bwd byte fold
  IDENTICAL on local + ghost (arm64-macos) AND aiden (x86-linux) — FWD 4548590605583584556, BWD
  4249661408190172843 on all 3. BEFORE (honest): libm `erf` won't even LINK on aiden (`hexa_math_erf` undefined)
  so a libm-erf GELU oracle CANNOT be cross-platform measured — the same hole-class OP-19 measured for libm exp
  (1 ULP arm64↔x86). DEPENDENT ORACLES re-locked: OP-9 LN-reduction (self-contained _ln_gelu→dt_erf) PASS 0.0;
  GN-GELU fusion re-lock proof (op19b_gngelu_relock.hexa, both arms dt_erf) PASS max|Δ|=0; OP-15 step + OP-18
  gelu2 inherit via nn_lib + the dt_erf host fallback (re-lock on fresh build — local hexa is a stale prebuilt
  that uses its own embedded stdlib, so the production-stdlib oracles validate on CI rebuild). RESULT: with
  OP-19's dt_exp + OP-19b's dt_erf, the flame CLMConvMoE step has **NO libm transcendental left** (exp/erf/ln all
  hand-rolled deterministic; sqrt already Newton) → flame is now FULLY machine-independent byte-exact. $0, 0-GPU,
  free pool (aiden/ghost), no vast. Verdict .verdicts/hexa-0pod/F-OP19B-DET-ERF.txt.

<!-- ANCHOR:OP-19C-PI5-3PLATFORM (unique anchor — extends OP-19/19b's 2-platform cross-platform byte-eq to a 3rd distinct arch×OS combo: pi5-akida arm64-LINUX, isolating arch-vs-OS) -->
- [x] **OP-19c — 3rd-platform byte-exact: pi5 arm64-linux confirms machine-independence (or honest blocked/divergence)** —
  Extended OP-19 (#3002) + OP-19b (#3008)'s 2-platform machine-independence proof (x86-linux aiden ↔ arm64-macos
  local/ghost) to a THIRD distinct arch×OS cell: **pi5-akida = arm64-LINUX** (Raspberry Pi 5, glibc), which isolates
  arch-vs-OS — SAME arch as the macos machines, SAME OS as aiden. OP-19/19b noted pi5 had no hexa; installed it
  **0-pod** (NO vast, NO build-from-source): official release tarball `hexa-linux-arm64.tar.gz` → `hexa 0.1.0-dispatch`
  (SAME version as all 3 prior hosts) + a user-local `clang→gcc` shim (pi5 has gcc 13.3.0, no clang; strips the
  clang-only `-fbracket-depth`) + scp'd a matching-version `self/` runtime tree (md5-verified, `tar -h` to deref the 4
  macOS-absolute symlinks). Ran BOTH self-contained oracles (op19_crossplatform_selfcontained + op19b_crossplatform_erf)
  via `hexa run` (0-GPU). **RESULT — 3-platform byte-IDENTICAL**: pi5 CE-bwd dt_exp = `7679248634312321699`, GELU FWD
  dt_erf = `4548590605583584556`, GELU BWD dt_erf = `4249661408190172843` — all THREE deterministic folds match the
  recorded arm64-macos AND x86-linux values bit-for-bit. The {x86,arm64}×{linux,macos} matrix is now **3/4 cells
  confirmed** (4th = x86-macos, no pool host — retired Intel Macs); pi5 supplies the arm64-linux diagonal. **BONUS
  (strengthens OP-19)**: pi5's libm CE-bwd fold = `3352931952497630952` == aiden x86-linux (NOT arm64-macos's
  `7969105254299072804`) → the libm `exp` divergence OP-19 measured is an **OS/libc effect (glibc vs Darwin libm), NOT
  arch** — pi5 tracks the OS it shares (Linux/glibc), not the arch it shares (arm64). dt_exp/dt_erf remove exactly that
  OS-dependent path. NO divergence on the production deterministic path. $0, 0-GPU, free pool (pi5-akida only), ZERO
  vast. Verdict .verdicts/hexa-0pod/F-OP19C-PI5-3PLATFORM.txt.

<!-- ANCHOR:OP-19D-4TH-ENV (unique anchor — 4th distinct env: musl libc (Alpine) adds a 3rd distinct libm impl beyond glibc+Darwin; OP-19c proved the divergence is an OS/libc effect, this tests it HARDER with a different libc entirely) -->
- [x] **OP-19d — 4th-env byte-exact: musl/summer strengthens machine-independence (or honest blocked)** —
  Extended OP-19/19b/19c's 3-platform machine-independence proof (Darwin · glibc-x86 aiden · glibc-arm64 pi5)
  to a 4TH DISTINCT ENVIRONMENT supplying a 3rd DISTINCT libc/libm: **musl (Alpine Linux)**, reached 0-pod via
  `docker run alpine` on summer (pool linux w/ docker; NO vast, NO GPU, NO pod). Picked musl over a 4th glibc host
  (musl≠glibc≠Darwin = the strongest "no libm dependence left" test; summer's own native glibc hexa was bootstrap-
  broken so it served ONLY as the docker host). hexa.real is glibc-linked so can't run under musl, but `hexa run`
  transpiles .hexa→C then `clang …runtime.c -lm`; transpiled both oracles on aiden, then COMPILED+RAN the C inside
  Alpine — binaries link MUSL libc (`ldd → libc.musl-x86_64.so.1`), libm exp/erf = musl. Build needed `-include
  sys/un.h…` (musl's <sys/un.h> strlen proto clashes with runtime's `#define strlen`), `-fuse-ld=lld`, gcc/libgcc
  CRT. **Found a REAL hexa-runtime↔musl bug** (gdb): SIGSEGV in `_hexa_init_mem_cap`→`hxlcl_getenv` at process init —
  the priority-101 `hxlcl_capture_environ(argc,argv,envp)` ctor relies on the glibc/Darwin-only "(argc,argv,envp)→
  constructor" ABI; **musl passes NO args to ctors** → envp garbage → `hxlcl_environ`=garbage → segfault before main.
  Worked around with a DISCLOSED TEST-ONLY runtime copy (ctor reads musl's `extern __environ`; env-capture ONLY, all
  math byte-identical; NOT committed). RESULT — **4-ENVIRONMENT byte-IDENTICAL**: musl dt_exp = 7679248634312321699,
  dt_erf FWD = 4548590605583584556, BWD = 4249661408190172843 — all match the recorded Darwin+glibc-x86+glibc-arm64
  values bit-for-bit. # DISTINCT libm impls spanned = **3 (glibc·musl·Darwin)**: libm `erf` gives 4 DIFFERENT values
  across the 4 envs (musl 7314648833623304241 ≠ glibc-x86 6306829276275644424 ≠ glibc-arm64 3332333775004383127 ≠
  Darwin 1521224270287218303) while dt_erf is identical on all → DEFINITIVE that ONLY the deterministic dt_* path is
  machine-independent. NO divergence/defect on the production path (the musl init segfault is a libc-ABI env-capture
  bug hit BEFORE any fold math — flagged as a runtime follow-up). $0, 0-GPU, free pool (summer docker + Alpine), ZERO
  vast. Verdict .verdicts/hexa-0pod/F-OP19D-4TH-ENV.txt.

<!-- ANCHOR:OP-19E-MUSL-ENVFIX (unique anchor — the durable runtime fix for the OP-19d musl ctor-ABI SIGSEGV: POSIX `environ` global replaces the glibc/Darwin-only (argc,argv,envp) constructor-args ABI; upgrades OP-19d's test-only shim to a real native-musl run) -->
- [x] **OP-19e — musl-safe env-capture (POSIX environ, not constructor-args ABI); fixes the OP-19d SIGSEGV (0-pod)** —
  THE durable fix for the REAL hexa-runtime↔musl bug OP-19d surfaced. The priority-101 `hxlcl_capture_environ(int argc,
  char**argv, char**envp)` ctor relied on the glibc/Darwin-only "(argc,argv,envp)→constructor" ABI; **musl passes NO
  args to ctors** → `envp` = garbage register → `hxlcl_environ`=garbage → SIGSEGV in `_hexa_init_mem_cap`→`hxlcl_getenv`
  BEFORE main(). FIX: read the POSIX global `extern char **environ` (defined by EVERY libc incl. musl) instead — ctor
  still runs at prio 101 (`hxlcl_capture_environ(void){ hxlcl_environ = environ; }`), `environ` referenced before the
  `#define environ hxlcl_environ` shadow so it binds the libc symbol. BEHAVIOR-PRESERVING on glibc/Darwin (ctor-arg envp
  and libc `environ` point at the SAME vector at start → same env captured), FIXES musl (real pointer). DURABLE LANDING:
  self/runtime.c is gitignored (frozen seed 151c52c8…), so the fix lands via the OP-16/17/18 mechanism — an idempotent,
  marker-guarded **OP-19e post-restore awk patch in tool/restore_frozen_seeds** that rewrites the 6-line capture block on
  every restore (the ONE tracked file; runtime.c stays untracked). PROOF (0-pod, summer docker + Alpine, $0, NO vast/GPU):
  (a) isolated reproducer native — Alpine/musl OLD ctor-ABI = SIGSEGV exit 139, NEW POSIX-environ = clean exit 0; glibc
  OLD≡NEW identical; Darwin clean. (b) full patched self/runtime.c builds under musl (runtime.o OK, ZERO environ diags)
  + Darwin (`-fsyntax-only` exit 0). (c) BONUS — real native-musl `hexa run` of op19_crossplatform_selfcontained.hexa
  against the patched runtime, NO SHIM: `ldd → libc.musl-x86_64.so.1`, **RUN_EXIT=0** (SIGSEGV GONE), deterministic
  Taylor folds **byte-identical across Darwin + glibc(summer) + native-musl** (dt_exp 7679248634312321699, dt_erf FWD
  4548590605583584556, GELUBWD 636106759170901885 — all three equal on all three), while every libm-* line DIVERGES
  (Darwin≠glibc≠musl) → upgrades OP-19d's test-only shim to a REAL native-musl run. Verdict
  .verdicts/hexa-0pod/F-OP19E-MUSL-ENVFIX.txt.

<!-- ANCHOR:OP-19F-MUSL-CTOR-GATE (unique anchor — regression-locks OP-19e: static source-pattern guard over the env-capture patch so the (argc,argv,envp) args-ABI form can't silently re-land; closes OP-26b gap G6) -->
- [x] **OP-19f — musl ctor-ABI regression gate (static POSIX-environ guard; locks OP-19e, low-blast-radius)** —
  closes OP-26b gap G6 ("musl ctor-ABI fix CI-gate, LOW"). LOW-BLAST-RADIUS gate (`tool/musl_ctor_abi_gate.sh` +
  `.github/workflows/musl-ctor-abi-gate.yml`, paths-scoped) that locks the OP-19e (#3029) fix at its SOURCE: it
  extracts ONLY the awk-EMITTED C of the env-capture patch in `tool/restore_frozen_seeds` (the `print "..."`
  payloads, minus `//` comments) and asserts the musl-safe `hxlcl_capture_environ(void){ hxlcl_environ = environ; }`
  POSIX form is PRESENT and any args-ABI capture (`hxlcl_capture_environ(int …` / `hxlcl_environ = envp`) is ABSENT.
  The explanatory comments that spell out the OLD bad `(argc,argv,envp)` signature are structurally exempt → can't
  false-fail. PROVEN 0-GPU, $0: PASSES on the fixed tree; an injected args-ABI form is CAUGHT (exit 1, both guns
  fire); unrelated prose mentioning argc/argv/envp does NOT trip it. Honest: CI has no musl runner, so this is a
  STATIC source-pattern guard (the cheapest effective check), not a runtime musl test. Mirrors OP-5b discipline.
  Verdict .verdicts/hexa-0pod/F-OP19F-MUSL-CTOR-GATE.txt.

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

- **SELFHOST-NEXT — const-fold + atof + vsnprintf seed-promote bundle (OP-37b / OP-40 / OP-44 / OP-39b).**
  → CONSOLIDATED 2026-06-12 (OP-46). THE SINGLE build-host work item that lands all three float-correctness
  fixes + flips the OP-39 gate in ONE coherent promote, replacing the three scattered "out of 0-pod scope"
  DEFERs below (they share ONE blocker: CI's toolchain is built from the IMMUTABLE frozen-seed anchor 151c52c8
  that pre-dates all three fixes). RUNBOOK: **docs/selfhost-next-constfold-promote.md** — (a) the 3 source fixes
  + their codegen.hexa/runtime.c sites + golden changes [OP-37b strtod operand parse · OP-40 bit-exact hex-float
  const-fold serialize · OP-44 libc-snprintf float-formatter delegation], (b) the ONE promote procedure
  (build_selfhost.sh ladder → cc-gen3.o==cc-gen4.o byte-eq → FROZEN_SEED_REF re-pin → ~91% float-string golden
  re-bake), (c) post-promote cleanup (drop the 3 nobaseline-gate.yml continue-on-error lines → OP-39 gate
  enforcing per OP-39b), (d) the per-fix verification checklist. Verdict F-OP46-PROMOTE-BUNDLE-SPEC.txt. NOT
  0-pod: build-host self-host-anchor refresh (highest blast-radius op in the repo). The individual verdicts
  (F-OP37B / F-OP40 / F-OP44 / F-OP39B) are KEPT; this is the unified forward-pointer.

- **OP-39b — promote the OP-37/OP-37b float const-fold fix into the seed/deployed toolchain, then flip the
  OP-39 CI gate to ENFORCING.** → ADDRESSED 2026-06-12, 🟠 DEFERRED (promoted to a milestone above; verdict
  F-OP39B-SEED-PROMOTE-FLIP.txt). The deferral note's optimistic "re-emit via the marker-guarded channel"
  framing was WRONG: OP-39b's survey found CI's seed is the IMMUTABLE frozen .c-graduation anchor 151c52c8
  (gitignored hexa_cc.c, restored by git checkout), so promotion is a wholesale frozen-anchor RE-PIN carrying
  27,068 lines of unrelated drift, validated by the ~3.5h build_selfhost.sh self-host ladder on a build host —
  out of 0-pod scope. The fix is PROVEN correct + fixpoint-stable + gate-PASSING locally ($0); the gate is left
  advisory (flipping now would red-gate CI). Unblock belongs to a SELFHOST-NEXT / build-host work item.
  → SUPERSEDED by the SELFHOST-NEXT promote bundle above (OP-46): the gate-flip is step (c) of the unified
  runbook (docs/selfhost-next-constfold-promote.md), not a standalone item.

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
