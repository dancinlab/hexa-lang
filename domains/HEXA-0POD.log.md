# HEXA-0POD — log

## 2026-06-11 — OP-24d DONE: G1 turnkey kit pre-gates the proven input-side determinism (OP-28/28b) ($0 · 0-pod · NO GPU/vast/pod)
- Deep-dive round-7 branch ④: closes the 0-pod-feasible completeness of gap G1 (real-corpus end-to-end). The GPU
  trainer run stays GPU-build-gated, but the now-proven INPUT-side pieces are WIRED into OP-24c's turnkey kit.
- INTEGRATION (tool/clm/build_clmprod_tf32_e2e.sh, the only code change): added STEP 0 · INPUT-SIDE PRE-GATE BEFORE
  the PROVISION/ENV/nvcc guards (CPU-only, runs on ANY host). run_input_oracle <name> <oracle> <pass-token> runs each
  oracle TWICE via $HEXA_RUN (bare-file form, matching the script's own emit call) and asserts (i) the in-oracle PASS
  token (F-OP28-CORPUS-LOADER-DET = 1 / F-OP28B-BPE-FIX = 1) AND (ii) process-to-process byte-eq (run1==run2 diff
  clean), surfacing each CROSSPLAT-FINGERPRINT line. Runs BOTH oracles (OP-28 byte-level V=256 + OP-28b BPE V=151936);
  INPUT_PREGATE=PASS only if BOTH pass both legs, else the kit STOPS (exit 2) before spending a GPU build (g5: a
  determinism claim on a non-reproducible input is meaningless). HEADLINE [RESULT] line now also reports
  INPUT-PRE-GATE(OP-24d · CPU · 0-GPU)=$INPUT_PREGATE alongside GATE-A/B/C.
- VALIDATION (0-pod, CPU): bash -n VALID. op28 oracle PASS locally, fingerprint 0 0 0 216 16 88 186 65 == the F-OP28
  recorded local+aiden x86-linux value (cross-platform byte-eq). op28b oracle PASS locally (fingerprint
  0 0 0 100 21 127 152 65). The pre-gate function exercised end-to-end against ~/.hx/bin/hexa-run => INPUT_PREGATE=PASS
  (both oracles PASS both legs, both fingerprints surfaced).
- G1-READINESS PICTURE: PROVEN 0-pod NOW + pre-gated = the INPUT side (tokenize->pack->batch, byte-level F-OP28 AND
  BPE F-OP28b, byte-eq + machine-independent by construction). SOLE GATED REMAINDER = the GPU trainer STEP run
  (clm_prod_gpu -DHEXA_CUDA build env; F-OP24B's 31-host-marshal-wrapper frozen-seed completeness, a build-ENV gate,
  not a pod). G1 is 0-pod-MAXIMALLY-CLOSED: everything provable without a GPU is proven AND wired; only the GPU step
  awaits authorization.
- Behavior-preserving: the kit's GPU STAGE/BUILD/RUN/GATE-A/B/C logic UNCHANGED; OP-24d only PREPENDS a CPU pre-gate +
  a headline line. Readiness doc G1 row updated (severity HIGH -> reduced). NO GPU run, NO vast, NO pod, NO foreign
  pod touched. Verdict .verdicts/hexa-0pod/F-OP24D-G1-READINESS.txt.

## 2026-06-11 — OP-31 DONE: machine-independence on a 3rd flame arch (MLP) + OP-30 cross-ISA-matmul invariant DIRECTLY DEMONSTRATED ($0 · 0-pod)
- Generalizes OP-29's G2 from 2 archs to THREE. 3rd arch = a plain feed-forward MLP (Linear→GELU→Linear→GELU→Linear),
  structurally DISTINCT from CLMConvMoE (OP-15: conv+MoE+GroupNorm) AND the decoder block (OP-29: attention+RoPE+
  SwiGLU+RMSNorm). Every MLP layer is a pure dense GEMM → the purest stress of the OP-30 cross-ISA matmul invariant.
- 3rd-arch model = PRODUCTION nn_lib MLP primitives (nn_linear_fwd + nn_gelu_fwd + nn_linear_bwd + nn_gelu_bwd).
- ORACLES: stdlib/flame/op31_mlp_determinism_eq.hexa (run-to-run, imports the prod lib) +
  stdlib/flame/op31_mlp_selfcontained.hexa (cross-platform inline-reduction twin, NO `use`, scp-runnable, + an
  in-band OP-30 FMA diagnostic that computes layer-1 BOTH via the inline-ascending dot AND via the FMA-fused C kernel).
- byte-eq RUN-TO-RUN: fwd out · bwd grads · bwd dx all max|Δ|=0 on BOTH oracles, BOTH platforms (local arm64-macos +
  aiden x86-linux).
- CROSS-PLATFORM byte-IDENTICAL (the real OP-30 test): local arm64-macos vs aiden x86-linux (free CPU pool
  @192.168.50.119, $0, NO vast/NO GPU) emit IDENTICAL checksums (fwd 1585504437 / grad 926871122) + IDENTICAL IEEE-754
  fingerprints FWD `0 0 64 45 56 160 215 65` · GRAD `0 0 0 41 119 159 203 65` on the inline-ascending det path.
- OP-30 INVARIANT DIRECTLY DEMONSTRATED (not just asserted): the production nn_linear_fwd routes through
  forge_dispatch_matmul → FMA-fused farr_matmul (tensor_lib L58 "ikj order, FMA-fused under clang -O2") = a REAL hole.
  The twin's in-band diagnostic shows that exact kernel's L1 checksum byte-DIVERGES arm64 2039553633 vs x86 124945498
  on byte-IDENTICAL fp64 inputs, WHILE the inline-ascending rewrite of the SAME matmul stays byte-identical (fwd ck
  1585504437 on both). The invariant is the live difference between those two on this arch.
- HOLE CLOSED inline-ascending (_mlp_linear_fwd = plain mul+add, no C kernel — the OP-29/CLMConvMoE discipline);
  nn_linear_bwd was already inline-clean. libm-CLEAN (GELU via dt_erf/dt_exp; MLP has no RMSNorm → _nn_sqrt libm not on
  this path). Machine-independence GENERALIZES to 3 structurally-distinct archs → Y.
- Milestone OP-31 flipped [x]. Verdict .verdicts/hexa-0pod/F-OP31-3RD-ARCH.txt. aiden temp files cleaned (leak-0). $0 ·
  0-GPU · 0-pod · no vast · foreign pod NOT touched.

## 2026-06-11 — OP-19f DONE: musl ctor-ABI regression gate (static POSIX-environ guard; locks OP-19e) ($0 · 0-pod)
- Closes OP-26b gap G6 ("musl ctor-ABI fix CI-gate, LOW"). A LOW-BLAST-RADIUS gate that regression-locks the
  OP-19e (#3029) musl env-capture fix so the `(argc,argv,envp)` constructor-args ABI it removed can't silently
  re-land (CI doesn't run under musl → a revert/seed-regen would bring the SIGSEGV back unnoticed).
- MECHANISM (static grep guard, NOT a runtime musl test — honest per g5): `tool/musl_ctor_abi_gate.sh` reads the
  OP-19e patch SOURCE `tool/restore_frozen_seeds`, extracts ONLY the awk-EMITTED C of the env-capture patch (the
  `print "..."` payloads, dropping `//` comment payloads), then asserts (1) the musl-safe
  `hxlcl_capture_environ(void){ hxlcl_environ = environ; }` POSIX-environ form is PRESENT, and (2) any args-ABI
  capture (`hxlcl_capture_environ(int …` OR `hxlcl_environ = envp`) is ABSENT. The shell `#` prose + emitted `//`
  comments that DO spell out the old bad signature are structurally exempt (non-print + //-drop) → can't false-fail.
- CI wrapper `.github/workflows/musl-ctor-abi-gate.yml`, paths-scoped to restore_frozen_seeds + the gate + the
  workflow. Mirrors OP-5b's forge_runtime_warn_gate discipline (guard ONLY the clean thing).
- PROVEN 0-GPU, $0: (A) PASSES on the current OP-19e-fixed tree (exit 0, no false positive). (B) CATCHES an
  injected args-ABI form — scratch copy, file restored to 0-diff — exit 1, BOTH guns fire (safe-form-missing +
  args-ABI-present). (C) low-blast-radius confirmed: unrelated prose mentioning argc/argv/envp did NOT trip it.
- HONEST: static source-pattern guard, not a musl runtime run (CI has no musl runner) — the cheapest effective
  guard, locking the exact source pattern the musl SIGSEGV depends on.
- Milestone OP-19f flipped [x]. Verdict .verdicts/hexa-0pod/F-OP19F-MUSL-CTOR-GATE.txt. $0 · 0-GPU · 0-pod · no
  vast. Foreign vast pod 40375114 (anima-chat-7b) NOT touched.

## 2026-06-11 — OP-21D DONE: build_w16.sh hardened + dry-run + OP-29 FMA-ref check (turnkey bullet-proof; H100 perf still gated) ($0 · 0-pod)
- The 0-pod-feasible completeness pass over the H100-GATED w16 perf measurement (NO GPU, NO vast, NO pod).
- (a) DRY-RAN + HARDENED tool/wgmma/build_w16.sh. bash -n VALID. Structural walkthrough: gate ORDER correct
  (provision-guards -> build -> MODE 9 -> MODE 0 HARD GATE -> MODE 1 D1-falsifier HARD GATE + sweep + OP-21B
  fallback -> MODE 4 bit-exact + perf -> SASS -> DESTROY). Guards added: set -o pipefail; NVCC_MISSING clean
  early-exit; NO_GPU clean early-exit (nvidia-smi absent/empty OR compute_cap != 9.0 -> refuse wrong-arch build,
  no auto-rent); MODE 0 + MODE 1 HARD GATES die BEFORE any MODE 4/perf; MODE 4 per-cell rel_rms fail prints NO
  perf + final STOP if all floored; EXIT trap prints leak-0 DESTROY on EVERY exit path.
- DRY-RAN on the 0-pod box: NVCC_MISSING path AND NO_GPU path both exit clean (code 1) with instructions and the
  DESTROY trap fires. CONFIRMED.
- (b) OP-29 (#3042) FMA cross-cut: WROTE tool/wgmma/w16_op29_ref_check.cpp (clang++, 0-pod). Proved MODE-1's CPU
  reference is the OP-29-SAFE inline ascending `acc += a*b` (not fmaf-fused; == w16.cu L558; FMA Δ << 3e-3 tol),
  and MODE-4's reference is cuBLAS-TF32 ON DEVICE (no CPU FMA) -> the OP-29 cross-ISA FMA divergence is
  STRUCTURALLY ABSENT from the MODE-4 gate and CANNOT false-fail it. Device K-accum order well-defined
  (ascending k, slab==flat 16384/16384). grep: only `fmax` (not fma) in w16.cu CPU paths. RAN: 4/4 PASS.
- Re-ran the prior 0-pod checks: OP-21B 7/7 PASS, OP-21C 6/6 PASS, OP-21D 4/4 PASS.
- HONEST (g5): the H100 perf measurement REMAINS GATED — no wgmma/PTX executed, no TFLOP/s claimed. Value = the
  build kit is now bullet-proof turnkey + the OP-29 subtlety checked OFF -> highest H100 first-try odds.
- Milestone OP-21D flipped [x]. Verdict .verdicts/hexa-0pod/F-OP21D-W16-HARDEN.txt. $0 · 0-GPU · 0-pod · no vast.
  Foreign vast pod 40375114 (anima-chat-7b) NOT touched.

## 2026-06-10 — OP-27 DONE: deterministic TF32 fast-mode reflected into the dojo (0-pod docs) + commons directive DRAFTED for user sign ($0)
- Reflected the validated deterministic TF32 fast-mode (OP-20 #2999 + OP-23 #3005 + OP-24 #3009 + OP-25 #3007)
  into docs/hexa-dojo.md as a contributor recipe: `### deterministic TF32 fast-mode (precision-uncap)`, inserted
  after the g86 "flame vs PyTorch — fair-bench parity recipe" section, before `## references`. Elephant-rule
  (current-facts only). Covers: WHEN (HEXA_TF32_FASTMODE=1 for >3× keeping determinism; FP64 default byte-identical
  flag-off; keep FP64 for cross-machine byte-eq) · DETERMINISM (self-byte-eq max|Δ|=0 single-step + whole 100-step
  trajectory; pin CUBLAS_PEDANTIC_MATH portable guarantee) · W14 (rel-RMS 1.13e-6, ~34× inside) · REAL-not-illusion
  (N=100 loss-track ~1e-7, bounded ~5e-7 drift) · card-robust 4.2×@B=1 (B=8 19-21× FP64-throttle-caveated) ·
  precision Pareto FP64→TF32 SWEET-SPOT→BF16 DOMINATED + ASCII diagram · live-wire dispatch site (runtime_cuda_emit
  .hexa `_hx_cuda_farr_matmul_gpu`). Every number CITED from a verdict (g5).
- COMMONS half: DRAFTED ONLY. Wrote the proposed `g87_tf32_fastmode` directive (do/dont ≤100char/line, ASCII)
  verbatim in the verdict for the user to apply AFTER `sidecar sign commons`. The agent NEVER self-signs a
  sign-gated SSOT → NO .tape file edited in this PR. Honest: dojo half shipped 0-pod, commons half awaits user sign.
- $0 · 0-pod · NO GPU · NO vast · NO pod · foreign vast pod 40306156 NOT touched.
  Verdict .verdicts/hexa-0pod/F-OP27-TF32-DOJO.txt.

## 2026-06-10 — OP-21A DONE: Hopper warp-spec TMA kernel WRITTEN (wgmma_tf32_w16.cu) + turnkey build kit, local-checked, H100-gated perf (0-pod, $0)
- Turned the OP-21 DESIGN (#3000, F-OP21-HOPPER-WARPSPEC-DESIGN) into CODE. WROTE self/native/wgmma/wgmma_tf32_w16.cu
  (#define W10_NO_MAIN; #include "wgmma_tf32_w10_lib.h" for the SAME-BINARY gemm_w10 + cuBLAS-TF32 apples baseline,
  the W11/W12/W13/W15 pattern). All FIVE OP-21A deltas implemented, each adapted line citing w10_lib.h:
    D1 canonical-atom landing  — enc_canonical() + MODE 0 (w16_probe_canon) + MODE 1 (w16_probe_desc) = the
       FALSIFIABLE D1 gate; descriptor-direct read via mk_sw(swmode=1), (lbo,sbo,boff,swmode) runtime-swept (W15 fields).
    D2 descriptor-direct wgmma — gemm_w16 reads swizzled smem IN PLACE; the As0/As1/B0/B1 gmma decode band
       (w10_lib.h L361) DELETED. smem 96->64KB/CTA (W15-measured), 2 CTA/SM held.
    D3 NST=3 decode-free ring  — only the swizzled tiles ring (w10_lib.h L331 SWBUF); the -32KB headroom buys the stage.
    D4 wgmma.wait_group<NST-2> — literal 1 (=NST-2@NST=3); commit per slab then wait<1> so the OLDEST group drains
       while the NEWEST issues (back-to-back across K-slabs), replacing w10_lib.h L407 wgmma.wait_group 0.
    D5 setmaxnreg producer/consumer split — 384 thr: producer WG setmaxnreg.dec 40 (TMA+mbar, empty[]-gated stream)
       + 2 consumer WGs setmaxnreg.inc 232 (wgmma). UNBLOCKED at the 128x128 64-reg accumulator (w10_lib.h L345) vs
       W12's 128x256 128-reg that ptxas rejected (C7507). FALLBACK -DW16_PRODUCER_WG=0 = single-elected-thread (W10 H1).
    + gemm_w16b = OP-21B fallback (keep band, no M3 dependency) for the D1-floored path.
- LOCAL 0-pod CHECK (no nvcc locally — `which nvcc` absent; device-PTX compile is GPU-TOOLCHAIN-GATED):
    (a) host-side C++ STRUCTURAL parse (clang++ -std=c++17 -fsyntax-only, CUDA stubbed, device-asm/__syncthreads
        neutralized): DEFAULT (producer-WG) exit 0, FALLBACK (-DW16_PRODUCER_WG=0) exit 0 — both paths well-formed C++.
    (b) sm_90a ISA-level review of authored PTX: wgmma.wait_group/commit_group + setmaxnreg as IMMEDIATE literals
        (canonical form, matches w10_lib.h's `...aligned 0;`), mbarrier.arrive.shared::cta.b64, fence.proxy.async,
        mk_sw bit-packing + GMMA 8x4 const reused VERBATIM — NO discrepancy. Only unproven element = D1 (canonical
        landing -> bit-exact), which is the pre-registered falsifier gated by MODE 1, NOT asserted.
    (c) exact GPU-gated compile step: `nvcc -O3 -arch=sm_90a wgmma_tf32_w16.cu -o w16 -lcublas -lcuda -Xptxas -v`
        (watch C7507 setmaxnreg-ignored -> -DW16_PRODUCER_WG=0). Runs on authorized H100 only.
- WROTE turnkey tool/wgmma/build_w16.sh (bash -n syntax-valid): provision-checklist (NO auto-rent, ZERO-VAST; exits
  if no sm_90a visible) -> build -> MODE 9 canonical dump -> MODE 0/1 gates (D1 falsifier, field sweep, OP-21B switch
  on full-sweep floor, W10 KEPT) -> MODE 4 bit-exact gate + occupancy + perf sweep S{2048,4096,8192} x NST{3,4,2}
  vs same-binary gemm_w10 (the 70.7 apples) + cuBLAS-TF32 -> SASS (decode STS gone + wgmma back-to-back) ->
  Δ-vs-W10 headline -> destroy leak-0. g5 gate order enforced (no perf before rel_rms-0 single-tile gate).
- HONEST (g5): NO perf number produced or claimed — the device-PTX compile + ALL TFLOP/s is H100-GATED. W10 70.7
  frontier KEPT (the W11/W12/W13 hard rule) until w16 lifts it bit-exact on H100. cuBLAS-TF32 = ROOFLINE, no
  superiority claim. Value = the OP-21A lever is now CODE not just design — H100 authorization -> one command.
  $0 · 0-GPU · 0-pod · no vast/pool/pod. Verdict .verdicts/hexa-0pod/F-OP21A-W16-KERNEL.txt.

## 2026-06-10 — OP-19b DONE: pure-FP deterministic erf seals the GELU cross-platform hole → flame FULLY machine-independent byte-exact (0-GPU)

Closed OP-19's measured latent residual (GELU libm `erf`, the last libm transcendental in the step).
Implemented `flame_math.dt_erf` = Abramowitz & Stegun 7.1.26 rational with the exp via OP-19's deterministic
`dt_exp` — pure +,-,*,/ + dt_exp, NO libm, BRANCHLESS in z (only the z=0 odd sign flip).

KEY DEAD-END NOTED: a first cut (Maclaurin series + hard clamp |z|≥4) was 1.54e-8-accurate but BROKE the
fused-vs-unfused GN-GELU byte-eq (max|Δ|=2.5e-7): the GELU argument straddles the clamp boundary differently
in-register (fused) vs stored-reload (unfused). A series+rational-tail hybrid had the same seam defect. The
unconditional A&S form has NO value-dependent boundary → byte-eq restored. (Maclaurin also diverges past z≈5.)

WIRED: host nn_lib `_nn_normal_cdf`/`_pdf` + gn_lib `_gn_gelu` (+ `_gn_dt_exp` replica); reference
clm_conv_devfeed (4 erf + 2 exp sites); device `_hx_dt_erf_dev` shared by all GELU kernels (+ `_hx_dt_exp_dev`
hoisted, F-OP19 dup removed); host C fallback (restore_frozen_seeds `_op18_gelu`→dt_erf) — VERIFIED clang-clean
+ BYTE-IDENTICAL to hexa dt_erf (fold 93,35,192,253,183,12,237,63 @1.19071).

CROSS-PLATFORM ORACLE (op19b_crossplatform_erf.hexa, self-contained): det-erf GELU fwd+bwd byte fold IDENTICAL
on local+ghost arm64-macos AND aiden x86-linux — FWD 4548590605583584556, BWD 4249661408190172843 on all 3.
BEFORE: libm `erf` won't even LINK on aiden (`hexa_math_erf` undefined) → can't be cross-platform measured.
ACCURACY: max|dt_erf − libm erf| = 1.38e-7 (≤ GELU tolerance; g5 honest trade matches-libm → matches-all-platforms).

DEPENDENT ORACLES re-locked: OP-9 LN-reduction PASS 0.0; GN-GELU re-lock proof (op19b_gngelu_relock.hexa, both
arms dt_erf) PASS max|Δ|=0; OP-15 step + OP-18 gelu2 inherit via nn_lib + the byte-eq host fallback (validate on
fresh build — local hexa is a stale prebuilt that uses its own embedded stdlib).

RESULT: exp/erf/ln all hand-rolled deterministic, sqrt Newton — NO libm transcendental left → flame is now
FULLY machine-independent byte-exact. $0 · 0-GPU · free pool (aiden/ghost) · no vast. Verdict
.verdicts/hexa-0pod/F-OP19B-DET-ERF.txt.

## 2026-06-10 — OP-25 GREEN gates / DOMINATED: deterministic BF16 fast-mode — Pareto-dominated by TF32 (aiden 5070, FREE)

The precision-uncap ladder's NEXT rung after OP-20 TF32 (#2999) + OP-23 TF32-drift (#3005). BF16 has an
8-bit mantissa (vs TF32's 10-bit) so the GEMM is less accurate but POTENTIALLY faster (or same speed, half
GEMM-input bytes). OP-25 asks: is a deterministic BF16 step fast-mode (a) self-byte-eq, (b) within W14 vs
FP64, (c) FASTER than TF32 — i.e. a NEW rung, or DOMINATED by TF32 (same throughput, no reason to use it)?

- METHOD: 3-lane (BF16 / TF32 / FP64) single-process harness over the OP-20 fused step DAG (fwd GEMM →
  fused valley LN+gelu+copy → transpose-elim bwd GEMM → single-launch AdamW); only cuBLAS storage/compute
  differs (BF16=CUDA_R_16BF/COMPUTE_32F_FAST_16BF). MIXED-PRECISION CONTRACT (decisive): master weights +
  AdamW state + glue accum all fp32; only the two GEMM operands are bf16 (bf16 copy refreshed each AdamW).
  All glue fixed-order, no atomics. Drift harness = continuous trajectory per lane (W/m/v persist) + scalar
  loss mean(G²). aiden RTX 5070 FREE, idle-guard hard-backoff 30→480s×8. 8/8 1-step + 4/4 drift cells.
- (1) BF16 SELF-BYTE-EQ: YES, max|delta(W',loss)|=EXACTLY 0 on every cell AND over the full 50-step
  trajectory. PEDANTIC NOT needed (DEFAULT bf16 tensor-op already run-to-run deterministic; identical bytes
  + time — same finding as OP-20's TF32). Pin PEDANTIC for a portable ship guarantee (costs nothing).
- (2) rel-RMS vs FP64 ~1.13-1.22e-6 — NOT the expected ~1e-3, and essentially EQUAL to TF32's 1.13e-6.
  WHY (load-bearing): fp32 master weights → only GEMM operands bf16 → the e-3 GEMM error enters W through
  ONE tiny optimizer step → e-6 W' error. Fully trainable; 4 orders inside W14 1e-2. (A bf16-MASTER step
  WOULD show e-3 — but nobody ships that; the fp32-master contract is the real one and is what we measured.)
- (3) SPEED: FP64/BF16 = 3.88-4.10×@B=1, 15.8-16.8×@B=8 (B=8 inflated by 5070's ~1/64 FP64, same OP-20
  caveat). BF16-vs-TF32 = TF32/BF16 1.01-1.12× → BF16 at most ~12% faster @B=8 (half-input-bytes mem
  traffic, NOT compute) and a DEAD HEAT @B=1 (1.01-1.02×, the latency regime the ~3× cap names). On the
  5070 BF16 & TF32 are both 16-bit-input fp32-accum tensor-ops at EQUAL throughput → no GEMM-cost edge.
- (4) DRIFT N=50, B=1: BF16 LOSS TRACKS FP64 — worst loss-track gap 9.4e-5 (D=768) / 1.7e-4 (D=1536),
  bounded, no growth; weight rel-RMS ~e-6 does NOT accumulate (1.2e-6@step1 → 2.5e-6@step50) =
  chaotic-but-microscopic, same shape as OP-23's TF32 drift. Real trainable fast-mode, not a 1-step illusion.
- PARETO PLACEMENT: FP64(exact,1×) → TF32(e-6, 4.2×) → BF16(e-6, 4.1× — SAME accuracy + SAME speed as TF32).
  BF16 is Pareto-DOMINATED by TF32: not worse, but BETTER on neither axis → no reason to prefer it. The
  expected "less accurate but faster" trade did NOT appear: (i) fp32-master contract erases the accuracy
  gap, (ii) equal 16-bit tensor throughput erases the speed gap. TF32 stays the precision-uncap TERMINAL
  SWEET SPOT; the BF16 rung is a NO-OP on consumer hardware. HONEST CLOSED result, $0, no vast/pod/leak.
- ARTIFACTS: verdict .verdicts/hexa-0pod/F-OP25-BF16-FASTMODE.txt; harness
  tool/bench/flame_bench_step_bf16fast.cu + flame_traj_drift_bf16_op25.cu; drivers run_op25_5070.sh +
  run_op25_drift_5070.sh; raw op25_5070_raw.log + op25_drift_5070_raw.log. branch domain/hexa-0pod-op25.

## 2026-06-10 — OP-23 GREEN: TF32 N-step trajectory drift vs FP64 — TF32 fast-mode is REAL, not a 1-step illusion (aiden 5070, FREE)

The decisive validation of OP-20's deterministic TF32 fast-mode. OP-20 (#2999) proved a SINGLE TF32 flame
step is self-byte-eq + rel-RMS 1.13e-6 vs FP64 + 4.2×@B=1 — but flagged the LARGER deferred question:
does the TF32 TRAJECTORY track FP64 over N steps, or peel away (1-step illusion)? OP-23 answers it.

- METHOD: TWO continuous trajectories (TF32 lane + FP64 lane) from the SAME seed + SAME fixed data, N=100
  steps, AdamW state W/m/v PERSISTS across steps so drift ACCUMULATES (OP-20 reset every step). Same step
  DAG as OP-20 (fwd GEMM → fused valley LN+gelu+copy → transpose-elim bwd GEMM → single-launch AdamW); only
  cuBLAS compute type differs. Added deterministic loss = mean(G²) over the post-valley activation (fixed-
  order block tree reduce, no atomics). TF32 trajectory run TWICE for whole-trajectory self-byte-eq.
  aiden RTX 5070 sm_120, FREE sidecar pool, idle-guarded, leak-0. 4/4 cells (DEFAULT+PEDANTIC, D={768,1536},
  B={1,8}).
- Q1 WEIGHT DRIFT = BOUNDED: relRMS(TF32-W vs FP64-W) starts ~1.13e-6 (OP-20's 1-step #), SHRINKS to
  ~4.5–5.3e-7 by step 100 — does NOT grow. max|dW| creeps 1e-8→~5e-7 (chaotic accum) but stays microscopic
  (3–4 orders inside NN's ~1e-3 forgiveness). The GOOD case.
- Q2 LOSS-TRACKING = YES (decisive): TF32 loss matches FP64 loss to ~1e-7 every step. WORST gap 2.495e-5 is
  at the COLD-START step 1 (before AdamW's bias-corrected moments settle); from step 6 it DROPS to ~1e-7 and
  stays flat. NO peeling, NO drift trend — both lanes ride the SAME loss curve to the SAME loss (~0.40739).
- Q3 SELF-BYTE-EQ over the WHOLE trajectory: run1-vs-run2 W max|Δ|=0.000e+00 AND per-step loss max|Δ|=0.000e+00
  at step N on every cell. Determinism holds across the trajectory, not just step 1. PEDANTIC NOT needed
  (DEFAULT TF32-tensor-op already bit-identical run-to-run, identical numbers).
- VERDICT (g5 honest): the RIGHT metric is loss-tracking (training-equivalent), NOT weight byte-closeness —
  chaos guarantees weights drift, which is exactly why flame's identity is SELF-determinism (TF32-vs-TF32=0),
  not cross-precision. Bounded loss-tracking ⇒ TF32-mode is a REAL training fast-mode, CONFIRMED at the
  trajectory level. The 1-step rel-RMS 1e-6 was NOT an illusion. Caveats: N=100 small synthetic config
  (mean(G²) proxy, no real corpus/LR-schedule); drift TREND flat-to-shrinking to step 100, no late blow-up.
- Harness tool/bench/flame_traj_drift_tf32_op23.cu · driver tool/bench/run_op23_5070.sh · raw
  tool/bench/op23_5070_raw.log · verdict .verdicts/hexa-0pod/F-OP23-TF32-DRIFT.txt. FREE pool, NO vast, $0.

## 2026-06-09 — OP-22 DONE: MEGASTEP whole-step megakernel DESIGN + Amdahl bound + H100 recipe (0-pod, vs TF32)

Produced (reading existing real-pod verdicts + research memory only — $0, 0-GPU, NO vast/pod) the 0-pod
DESIGN + honest Amdahl ceiling + turnkey experiment recipe for MEGASTEP: the whole flame CLMConvMoE train
step fused into one persistent grid-resident cooperative megakernel to fill the between-GEMM valley.

- VALLEY STRUCTURE (cited F-FUSION-FF-DUTYCYCLE, real H100 SXM, vast 39958628 DESTROYED leak-0):
  GEMM% = 0.04% of wall (≈0.3% GPU-active) vs valley = 99.96% (GLUE 13.15% + GAP/idle 86.80% + OPT 0.01%).
  GPU-active is 90.5% the 2 byte-eq-forced single-thread GroupNorm reductions (105–132 ms EACH). util
  MEDIAN 1% / MEAN 10.9% / 72.2% samples <5% = BIMODAL {bursts, ~0% idle} occupancy wall. The step is in
  NO sense GEMM-bound.
- AMDAHL CEILING = 1/GEMM% = 1/0.0004 = 2844× — flagged HONESTLY as a USELESS ceiling (huge only because
  GEMM is a rounding error; Amdahl gives the limit of perfect serial-removal, NOT what a megakernel reaches).
  Binding bound = the serial-DAG occupancy FLOOR; MEASURED achievable ~1.0–1.04× (M2 MEAN +3.4pp).
- DESIGN: 9-phase grid.sync()-delimited cooperative megakernel (cudaLaunchCooperativeKernel, one wave) with
  inline own-GEMM replacing cuBLAS host calls. BOTH megakernel walls already closed: own-GEMM (#2697) + coop
  grid-synced byte-eq GroupNorm (F-FUSION-MEGAKERNEL-GN-GRIDSYNC, A100 max|Δ|=0). Buildable; just doesn't win.
- THREE honest tensions (all cited, real-pod): (1) own-GEMM ~6× off cuBLAS (W10 70.7 TFLOP/s) — fusion trades
  GEMM speed; (2) byte-eq ⊥ util-lift (B6 max|Δ first_ce| 9e-16…1.8e-15 ≠ 0 after ONE fwd — GEMM k-order ≠
  cublasDgemm, structural); (3) parity wgmma CANNOT co-reside (MEGA-OWNGEMM: blockDim<128 can't issue wgmma +
  (S/128)² > 264-CTA one-wave ceiling → grid.sync deadlock @S=4096).
- MEGASTEP-vs-TF32 (OP-20 ~4.2× @B=1) HONEST VERDICT: (b) DOMINATED. Same 99.96% valley; TF32 ~4× the win at
  ~0 architecture risk (P1-TF32 +5.5pp util CE-safe). MEGASTEP's only GREEN slice (FF-VALLEY 2.5×) is a byte-eq
  single-thread-GN ARTIFACT that collapses to MPK ~1.2–1.3× in a parallel/TF32 trainer; no orthogonal stack on
  top of TF32 (TF32 already pulls GEMMs inline + collapses launches; residual idle is the serial-DAG floor).
  DECISION: do NOT spend an H100 campaign on MEGASTEP. Bank TF32 for B=1; pursue BATCH-FILL (≈3×) for SM-sat.
- TURNKEY RECIPE: FF-DUTYCYCLE → FF-VALLEY → MEGASTEP rungs + byte-eq/util/wall/batch-fill/TF32 gates + leak-0
  destroy, runnable the moment a GPU is authorized — with an EARLY-EXIT note (RUNG C already measured closed-
  neg; re-running buys 0 info → spend the GPU on TF32 drift-study or batch-fill instead).
- HONEST (OP-2b/OP-21-class, g5): DESIGN + BOUND only. NO measurement performed or claimed; the H100 measure
  stays GPU-gated and out of 0-pod scope. NO pod rented this session (0-pod goal = ZERO vast). leak = 0.
  Verdict .verdicts/hexa-0pod/F-OP22-MEGASTEP-DESIGN.txt.

## 2026-06-09 — OP-18 DONE: host fallbacks for the remaining L3 fused dispatchers (gelu2 + moe_block2), 0-GPU

Completed the OP-16 (#2995) L3 fused-dispatch FAMILY. forge_dispatch_gelu2 (L3-b) + forge_dispatch_moe_block2
(L3-d) were supplied ONLY by the GPU build's fusion_dispatch.c (`#ifdef HEXA_CUDA`), so a 0-GPU `hexa run`
harness driving the fused paths (clm_prod.hexa _gelu2 / _moe_block2, which emit the bare symbol via codegen)
FAILED TO LINK off-CUDA — the last 2 of the family's 3 dispatchers still host-undefined after OP-16 fixed
groupnorm_gelu only.

- WROTE the `#ifndef HEXA_CUDA` host twins in self/runtime.c (after OP-16's groupnorm_gelu block, same
  bare-wrapper-seam idiom, FP_CONTRACT OFF):
    gelu2(g0,a0,g1,a1,n)      = two erf-GELU passes (GELU(x)=x·0.5·(1+erf(x/√2))) == 2× nn_gelu_fwd.
    moe_block2(…,T,E,C)       = gelu2 → expert_pack2 (E=2 stack into ex_out[E·T·C]) → moe_router replaying
                               moe_lib _moe_exp (scaled-Taylor, NOT libm exp) with per-pos max-sub +
                               sequentially-summed denom + e-ASCENDING combine = OP-8's (#2993) PROVEN order.
- BYTE-EQ 0-GPU: both symbols U→T (nm); two TRACKED oracles drive each fused entry through the host dispatch
  vs the unfused reference → max|Δ| = 0.0:
    clm_prod_gelu2_hostdispatch_eq.hexa     — gelu2 vs 2× nn_gelu_fwd, n=16/64/257/1/1024 → 0.0 all.
    clm_prod_moe_block2_hostdispatch_eq.hexa — moe_block2 vs unfused chain, 6 shapes, comparing
                                              ex0/ex1/ex_out/probs/y → 0.0 all (whole fused unit locked).
  rc==0 on every shape (host dispatch actually fired). FP_CONTRACT OFF cured the would-be ~1-ULP FMA gap →
  EXACTLY 0 (OP-16's lesson; no residual).
- GPU PATH UNCHANGED: `#ifndef HEXA_CUDA` only — `clang -DHEXA_CUDA -fsyntax-only` shows no duplicate/
  redefinition on the 2 symbols (fusion_dispatch.c still owns the HEXA_CUDA bodies).
- DURABLE LANDING (g5, OP-17-class): self/runtime.c is gitignored frozen-seed (#2065, restored from immutable
  blob 151c52c8… which PREDATES all L3 fusion glue). Durable fix = idempotent, marker-guarded OP-18
  POST-RESTORE PATCH in the TRACKED tool/restore_frozen_seeds that APPENDS the 3 `#ifndef HEXA_CUDA` host
  bodies (gelu2 + moe_block2 + groupnorm_gelu — OP-16 never landed groupnorm_gelu durably, so OP-18 makes the
  WHOLE family restorable) at EOF where _hx_farr_table/hexa_as_num/erf/hexa_int are in scope. VERIFIED
  end-to-end: append on the freshly-restored frozen blob → patched runtime.c compiles clean no-CUDA (exit 0),
  nm all 3 symbols U→T, HEXA_CUDA excludes them (GPU untouched), idempotent (2nd run no-ops). Fully in-0-pod
  (no GPU-build regen needed beyond the restore-tool patch). Whole L3 fused-dispatch family now 0-GPU
  host-testable byte-eq. Verdict .verdicts/hexa-0pod/F-OP18-L3-FUSED-HOST.txt. $0, no GPU/pool/vast.

## 2026-06-09 — OP-4 DONE: flame fused-step 5070 win/lose map — LOSES everywhere, near-parity only in FP64

Swept the flame BENCH-10 FUSED training step (flame_bench_step_fused.cu -DFUSED, cuBLAS lane = the speed lane:
fused valley LN+gelu+copy + single-launch AdamW + transpose-elim) vs torch eager+compile across
D={768,1536,2048} x B={1,8} x dtype={FP64,TF32,BF16} = 18 cells on aiden RTX 5070 (sm_120, 12GB), free pool,
NO vast. T=256, ITERS=50, exclusive-GPU guard (util<5% & mem<800MiB; it fired several times as parallel
OP-2/OP-3 agents hit the card and correctly held each timed run).

HONEST consumer-card frontier: flame LOSES to torch.compile in ALL 18 cells — there is NO crossover-D where
flame wins on the 5070. Ratio (flame_ms / torch_compile_ms) by regime: TF32 1.78x->8.96x (widens with D at
B=1; ~2.8x flat at B=8). BF16 WORST, up to 14.66x @D=2048/B=1 (torch inductor + cuBLASLt BF16 on small-M is
very efficient; flame pays per-step f32->bf16 cast + cuBLAS overhead on a tiny matmul). FP64 near-PARITY
1.04-1.32x, tightest at large B (D=1536/B=8 = 1.007x tied, D=2048/B=8 = 1.038x) — FP64 is compute-bound on
consumer Blackwell so the GEMM dominates the wall and flame's glue overhead amortizes. 0 OOM (12GB held every
shape; largest FP64/D=2048/B=8 used ~0.4 GiB).

GATE g5 PASS x18/18: per-cell determinism run-to-run max|delta(W')| = 0 every cell; rel-RMS(fused W' vs
un-fused NAIVE-GEMM ref) <= 4.2e-8 (FP64 cells = 0.000e+00). The fusion is bit-faithful on the consumer card.

Framing (g5): flame's value on consumer HW is its IDENTITY (byte-exact / device-resident / deterministic /
no-LLVM / torch-free native step), NOT raw step-rate — torch.compile is faster everywhere on the 5070. The
earlier BENCH-1 "flame won @D=768 on the 5070" claim does NOT reproduce against torch 2.12 eager+compile
(D=768/B=1 TF32: torch eager 0.21 ms vs flame 0.43 ms). Root cause of the worst losses = per-launch + separate
cuBLAS-handle overhead at small B (the launch floor) vs torch's whole-step inductor fusion. Verdict
.verdicts/hexa-0pod/F-OP4-5070-COVERAGE.txt; driver tool/bench/run_op4_5070.sh. Deferred OP-4b (CUDA-graph /
single-megakernel step to collapse the small-B launch floor — small-B-only win, won't beat torch everywhere).

## 2026-06-09 — OP-1 DONE: sm_120 own-GEMM 3.2-6.9x -> ~1.0-1.15x off cuBLAS, bit-exact (aiden RTX 5070)

Swept 5 kernel variants (K0 baseline .. K4 all-levers) on aiden (free pool, NO vast). Levers: (1) cp.async
double-buffer, (2) bank-conflict-free smem pad, (3) 128x64 register tile, (5) .v4 128-bit global loads. All
variants BIT-EXACT vs the K0 baseline (rel-RMS=0, bitdiff=0/N) and vs cuBLAS-TF32 (rel-RMS ~3e-5, gate PASS) at
D={1024,2048} — scheduling/layout-only, accumulation order preserved.

Results (TFLOP/s, GPU exclusivity verified): D=1024 K0 6.75 (4.16x off) -> K2 24.49 (1.15x off); D=2048 K0 8.05
(3.83x) -> K2 29.81 (1.02x — near parity). K2 = pad + .v4 + cp.async double-buffer = BEST bit-exact config.
Findings: layout/load-vectorization (K1) was the dominant lever (+3.1-3.4x — baseline had pathological bank
conflicts + scalar loads); cp.async a modest top-up (+0.08-0.15x); the 128x64 register tile (K3/K4) PLATEAUED/
regressed on the consumer card (occupancy loss > AI gain) and was NOT shipped (closed-negative).

Promoted K2 into the production self/native/mma_sm120/owngemm_sm120.cu (gemm_sm120) so flame's real sm_120
own-GEMM gets the speedup — re-verified: GATE @768 rel-RMS 1.33e-5 (== baseline, bit-faithful), PERF 24.48
@1024 / 29.81 @2048 TFLOP/s. Sweep harness owngemm_sm120_opt.cu + build_owngemm_opt.sh kept for reproduction.
Verdict .verdicts/hexa-0pod/F-OP1-SM120-OWNGEMM.txt. Deferred OP-1b (BK=32 / 3-stage pipeline / vectorized
epilogue) appended to self-feed the loop; register-tile lever marked closed-negative (do not re-attempt).

## 2026-06-09 — domain registered (0-pod free-resource improvement loop)

User goal: "0 pod 으로 flame+forge 개선 계속 진행 루프" + "pool 은 활용가능". Continuous flame+forge improvement
using ONLY free resources (sidecar pool aiden/summer RTX 5070 + local code), zero vast rentals. aiden confirmed
free (RTX 5070 sm_120, 0% util). Backlog OP-1..5 (sm_120 own-GEMM speedup · wire bench wins into real trainer ·
BF16 own-GEMM · fused-step coverage · forge hardening). Hopper-only own-GEMM decode-elim is out-of-scope (needs
H100 pod). Loop fans out free-resource agents per round, byte-eq/bit-exact gated on the consumer card.

## 2026-06-09 — OP-2 — wire bench step wins into the REAL flame CLMConvMoE trainer 🟢

Audited the 4 HEXA-BENCH step wins against the real trainer (stdlib/flame/clm_prod.hexa + the forge device
runtime self/cuda/runtime_cuda_emit.hexa). Finding: 3 of 4 are ALREADY in the product, env-gated, from the
HEXA-FUSION campaign — cuBLAS-FP64 projection GEMM is the DEFAULT _hx_cuda_farr_matmul_gpu path (HEXA_OWN_GEMM
only swaps the naive kernel IN); fused valley LN+gelu(+resid) under HEXA_FUSE_VALLEY/GN_GELU(_RESID) →
_hx_k_groupnorm_gelu[_residual]; single-launch fused AdamW under HEXA_CLM_FULLSTEP → _hx_k_adamw_fused
cooperative. The bench's "flame FP64 = naive O(D^3)" refers to the HEXA_OWN_GEMM kernel, not the default trainer.

The one MISSING win = BENCH-10 TRANSPOSE-ELIMINATION for the backward dW GEMM. conv1d_bwd_via_forge ran a
SEPARATE transpose-layout im2col pass (_clmp_im2col_t → xcolT[Kdim,T]) then an OP_N GEMM; the bench computes
dW = A^T@dGq via cuBLAS OP_T on A directly (no materialized A^T). Wired it: new forge_dispatch_matmul_t(A,M,K,
B,N) = A^T@B builtin — GPU side _hx_cuda_farr_matmul_tn_gpu (cublasDgemm CUBLAS_OP_T, + _hx_k_gemm_t own
fallback) in runtime_cuda_emit.hexa (emit verified, no symbol collision w/ the RFC-040 M^T·u gemv, brace-
balanced); codegen call-name mapping + runtime.h protos. The trainer's conv1d_bwd_via_forge documents the
3-line swap (im2col + matmul_t, drops the im2col_t pass) as a COMMENT — NOT a live call — so the build stays
unbroken until the runtime.c wrapper body lands at GPU-build time.

GATE (g5) byte-eq HELD: clm_prod_transpose_elim_eq.hexa CPU oracle proves im2col+matmul_t dW ==
im2col_t+matmul dW max|Δ|=0 across 4 (T,Cin,Cout,K,dil) cases via `hexa run` (0-pod, mac/aiden CPU — the
same dispatch path, no GPU build needed). Bit-exact because xcolT[j,t]==xcol[t,j] and the contraction runs
over the same t-dim in the same ascending order. GPU cuBLAS OP_T is the documented ~1e-14 accum-order lane.

Deferred (GPU build, NOT vast): OP-2b runtime.c wrapper body + flip trainer to live call + step/s measure;
OP-2c batched-expert transpose-elim (cublasDgemmStridedBatched OP_T) for the dominant 2-expert path. Verdict
.verdicts/hexa-0pod/F-OP2-TRAINER-WIRE.txt.

## 2026-06-09 — OP-5 forge/runtime hygiene (LOCAL, 0-GPU)

Fixed the diagnostic-surfaced `self/runtime.h:422-423` `'/*' within block comment` `-Wcomment` warning: the
`native/*.c` glob written inside a `/* … */` block forms a nested `/*` token clang flags. Minimal comment-only
fix (`native/ *.c`, +2/-2) — `clang -fsyntax-only -Wcomment -x c self/runtime.h` 2 warnings → 0. No
declaration / codegen / behavior change. Repo-wide `-Wcomment` + `-Wextra-tokens` sweep over every checked-in
C/H/CU/CUH header, the forge-emitted CUDA wrappers (self/cuda/*.cu|*.c), and the emit-string `.hexa` sources
(runtime_cuda_emit / runtime_bf16_emit / forge_tier_v1_emit) confirmed runtime.h:422-423 was the ONLY genuine
hit (one `#pragma once in main file` artifact from standalone header parse correctly ignored, not "fixed").
All behavior-preserving. Verdict .verdicts/hexa-0pod/F-OP5-FORGE-HARDEN.txt. Deferred OP-5b (CI -Werror=comment
gate, 0-GPU) + OP-5c (error-path/dtype/determinism hardening — NEEDS GPU, out of 0-pod scope) to self-feed.

## 2026-06-09 — OP-5b DONE: forge-runtime -Wcomment hygiene CI gate (LOCAL, 0-GPU)

Regression-locked the OP-5 (#2973) `-Wcomment` cleanup. Added `tool/forge_runtime_warn_gate.sh` (SSOT,
locally runnable / hook-able) + `.github/workflows/forge-runtime-warn-gate.yml` (PR-on-main, paths-scoped to
the guarded files + script + workflow). OPTION A hard gate: `clang -fsyntax-only -Wcomment -Werror -x c` over an
EXPLICIT OP-5-clean allow-list (`self/runtime.h`, `self/forge/forge_tier_v1.h`, `self/native/lora_cuda.h`);
fails ONLY on a new nested-comment warning in those files. LOW BLAST RADIUS — deliberately NOT a repo-wide
`-Werror`: (1) allow-list only, so grandfathered warnings anywhere else can never fail it; (2) only `-Wcomment`,
a purely lexical class, so no CUDA toolchain / includes / type defs are needed (each file compiles stand-alone
`-x c`; runtime.h also passes full `-fsyntax-only` exit 0). clang→gcc→cc fallback. Verified LOCALLY: passes on
clean tree (3/3 PASS, exit 0); catches an injected nested `/*` in a guarded file (exit 1, precise diagnostic,
reverts clean); IGNORES the same warning injected into an unguarded file (`self/native/hxcuda_conv1d.cu`, exit
0) — proving it cannot break CI on grandfathered code. Behavior-preserving (CI-only; no source/codegen change).
Verdict .verdicts/hexa-0pod/F-OP5B-WARN-GATE.txt. OP-5b removed from `## deferred`; flipped `[x]` in milestones.

## 2026-06-09 — OP-3 BF16 sm_120 own-GEMM (aiden RTX 5070, free pool)

Extended the OP-1 (#2972) TF32 sm_120 own-GEMM to BF16 in self/native/mma_sm120/owngemm_sm120_bf16.cu using
the portable warp-mma `mma.sync.aligned.m16n8k16.row.col.f32.bf16.bf16.f32` — note BF16 is k16 (NOT k8 like
TF32), the 16x8x16 fragment packs two bf16 per 32-bit register (A=4 regs/8 bf16, B=2 regs/4 bf16). fp32 inputs
RN-converted to bf16 (__float2bfloat16_rn) at the smem→register fragment load (where TF32's f2tf32 lived);
fp32 accumulation. Carried over OP-1's THREE layout/load wins VERBATIM — (a) bank-conflict-free smem pad
As[BM][BK+4]/Bs[BK][BN+4], (b) .v4 128-bit float4 global loads (masked scalar tail), (c) cp.async double-
buffered BK stage — and kept the IDENTICAL K-major mma.sync accumulation order (so the kernel is its own
bit-for-bit reproducer). Did NOT touch the 128x64 register-tile lever (CLOSED-NEG on the consumer card, OP-1).

Built clean on aiden (CUDA 13.0, sm_120). GPU verified free (0% / 2 MiB) before every timed run.
GATE (g5 bit-FAITHFUL, W14 convention — NOT bit-exact-vs-fp32; BF16 8-bit mantissa): rel-RMS vs FP64 ref
8.4e-3@256 / 2.7e-3@768 / 6.7e-3@1024 / 8.0e-3@2048, all ≤1e-2 PASS (sits at the BF16 precision floor →
fragment layout is correct; a wrong m16n8k16 map would give rel-RMS ~0.5-1.0). Determinism: run-to-run
max|delta|=0, bitdiff=0/N @1024 and @2048 HELD.
PERF (2 timed passes): own-GEMM-BF16 26.1-26.5 TFLOP/s @1024, 33.3 @2048; cuBLAS-BF16 54.7 @1024, 61.5-66.7
@2048 → cuBLAS-multiple ~2.0-2.1x @1024, ~1.85-2.0x @2048.

HONEST (g5): the multiple is WIDER than the TF32 path's ~1.0-1.15x EXACTLY as predicted — BF16 ~doubles the
cuBLAS roofline (cuBLAS-BF16 ~55-67 vs cuBLAS-TF32 ~28-31 TFLOP/s). The own-GEMM's ABSOLUTE throughput is
actually HIGHER in BF16 (26-33) than TF32 (24-30 @ OP-1), but cuBLAS scales up faster, so the ratio opens to
~2x. The win = a working bit-faithful BF16 own-GEMM on the consumer card riding OP-1's layout lever; NOT
cuBLAS-BF16 parity (cuBLAS uses f16-class tensor-core scheduling the portable warp-mma doesn't). Verdict
.verdicts/hexa-0pod/F-OP3-BF16-SM120.txt. Deferred OP-3b (BK=32 / 3-stage cp.async / .v2-.v4 epilogue for the
BF16 path, mirroring OP-1b — NOT the register tile) to self-feed.

## OP-4b — CUDA-graph-captured flame FUSED step on RTX 5070 (sm_120) — CLOSED-NEGATIVE (honest)
Attacked the small-B launch-overhead floor OP-4 found (B=1: TF32 up to 8.96x, BF16 up to 14.66x @D=2048 vs
torch.compile) by wrapping the fused per-step DAG (cuBLAS fwd GEMM + fused valley + cuBLAS OP_T bwd GEMM
(transpose-elim) + single-launch AdamW) in a CUDA graph (cudaStreamBeginCapture/EndCapture -> Instantiate ->
GraphLaunch) so the whole step replays as ONE launch. Harness tool/bench/flame_bench_step_graph_fused.cu
(BYTE-FOR-BYTE the OP-4 -DFUSED math, only the launch mechanism differs; BF16 cast scratch pre-warmed before
BeginCapture since cudaMalloc isn't capturable), driver run_op4b_5070.sh. Swept B=1 x D={768,1536,2048} x
dtype={TF32,BF16,FP64} on the FREE pool 5070 aiden (0-pod, NO vast), iters=50, exclusivity-gated.
RESULT: graph/eager = 1.00-1.02x in EVERY cell (best BF16/D=768 1.0198x ~2%; FP64/D=768 0.9989x = noise).
The worst cell BF16/D=2048/B=1 went 14.66x -> 14.64x (ratio vs torch.compile shaved <0.5%). flame still LOSES
every small-B cell. WHERE THE LOSS LIVES: NOT launch — GEMM-RATE. Graph capture collapses ALL per-op
launch/sync into one replay; if the floor were launch-bound the ratio would have dropped, but it moved <2%.
So on the 5070 the small-B step wall is dominated by the cuBLAS GEMM execution (+ BF16 cast traffic), not by
issuing launches — the per-launch overhead is already negligible relative to even a tiny-M cuBLAS GEMM at
these D. Same structural outcome as the H100 BENCH-6 graph finding (graph ~1.0x => residual pinned to
GEMM-throughput). GATE g5 PASS x9/9: max|d(W')| graph-vs-eager =0 + run-to-run determinism =0 every cell —
graph capture is bit-exact + deterministic (a SAFE optimization that simply doesn't help this workload/card).
Launch-elimination is now CLOSED-NEGATIVE on the consumer 5070 too; flame's consumer value remains its
byte-exact/device-resident/torch-free identity, NOT step-rate. Verdict .verdicts/hexa-0pod/F-OP4B-GRAPH-5070.txt.

## OP-1b — sm_120 TF32 own-GEMM pipeline-depth sweep on RTX 5070 (aiden) — partial-positive (honest)
OP-1's deferred TF32 follow-up: close the residual ~3-15% off cuBLAS-TF32 @D=1024 (K2 = BK16/2-stage cp.async/
scalar epilogue was furthest off there, 1.15x). Probed 3 schedule/layout levers — (1) BK=32 deeper K-tile,
(2) 3-stage cp.async ring (wait_group<2>) vs the 2-stage double buffer, (3) .v2 (float2) vectorized C-store
epilogue. Harness self/native/mma_sm120/owngemm_sm120_pipe.cu (production kernel parameterized by -DLBK/
-DLSTAGES/-DLVEC; defaults 16/2/0 reproduce OP-1 bit-for-bit) + build_owngemm_pipe.sh. 8-config grid built +
run on the FREE pool 5070 aiden (sm_120, 0-pod, NO vast, GPU 0% verified idle before each timed run), gate
adds a host FP64 ground-truth ref (g5). The 128x64 register tile was NOT re-attempted (closed-neg, OP-1).
RESULT (own-GEMM TFLOP/s, off cuBLAS-TF32): baseline 24.50@1024(1.143x)/29.74@2048; L3 .v2-epi
24.93@1024(1.124x)/29.92@2048 = +1.7% @1024 WIN; L1 BK=32 22.76@1024(1.231x) REGRESS; L2 3-stage
22.79@1024(1.229x) REGRESS; every combo with BK32 or 3-stage REGRESSES; BK32+3stage BUILD-FAIL (ptxas
0xd200 smem > 0xc000 48KB cap). baseline & L3 re-run x3, variance <0.05 TFLOP/s — the +0.43 TFLOP/s gain is
stable not noise. WHERE: the K-pipeline-depth levers made it WORSE — on the 5070's 48KB smem cap the
2-stage/BK16 config is the occupancy sweet spot at D=1024/2048; deepening the K-tile or the ring trades
occupancy for a latency-hide that's already saturated, and stacking them overflows smem. Matches OP-1: the
consumer-card lever is memory-instruction VECTORIZATION (.v4 loads = OP-1's big win, .v2 store = OP-1b's
small one), NOT staging depth. GATE g5: bit-exact HELD — every building config byte-identical to the OP-1
baseline (rel-RMS vs baseline = 0; vs-cuBLAS-TF32 1.33e-05@768/3.02e-05@1024/1.74e-05@2048 unchanged;
vs-FP64 ~1e-4 = the TF32 10-bit-mantissa truncation floor, same for cuBLAS). SHIPPED: only the .v2 epilogue
folded into the production owngemm_sm120.cu (re-verified on aiden: @1024 24.93 TFLOP/s 1.13x / @2048 29.86
1.02x, gate PASS). BK=32 / 3-stage kept OUT (closed-negative on consumer card). Best sm_120 TF32 own-GEMM
now 24.93 TFLOP/s @1024 (1.13x off cuBLAS, was 1.15x). Verdict .verdicts/hexa-0pod/F-OP1B-SM120-PIPE.txt.

## OP-3b — .v2 vectorized C-store epilogue on the BF16 sm_120 own-GEMM (aiden RTX 5070) — GREEN/SHIP
Applied OP-1b's ONE bit-exact-positive lever — the .v2 (float2) vectorized C-store epilogue — to the BF16
path of owngemm_sm120_bf16.cu (mma.sync m16n8k16 bf16). The BF16 mma OUTPUT fragment is fp32 with the
IDENTICAL m16n8 C layout as the TF32 path (c0/c1 and c2/c3 contiguous at cols 2*tig, 2*tig+1), so the
TF32 .v2 epilogue ports VERBATIM: each pair fuses to one 64-bit store. Added a -DEPILOGUE_SCALAR (OP-3
baseline) compile twin + MODE==3 raw-f32 C dump so the build proves byte-identity by `cmp`. NARROW scope
per OP-1b: only .v2 — NOT BK=32 / 3-stage cp.async (CLOSED-NEG on the 5070 48KB smem cap) nor the 128x64
register tile (CLOSED-NEG, OP-1). aiden RTX 5070 (free, GPU 0%/2MiB verified): .v2 helped BIT-EXACTLY —
+2.1% @1024 (scalar 26.06 → .v2 26.60 TFLOP/s, off-cuBLAS-BF16 2.10x → 2.06x) / +1.0% @2048 (33.20 →
33.52). cuBLAS-BF16 ~54.8 @1024 / ~62-67 @2048; new multiple ~2.06x @1024, ~1.92-1.97x @2048. GATE g5
(bit-faithful, UNCHANGED — store-vectorization not math): rel-RMS vs FP64 2.65e-3@768 / 6.70e-3@1024 /
8.01e-3@2048 ≤1e-2 PASS; determinism max|d|=0 bitdiff=0/N HELD; BYTE-IDENTICAL to OP-3 scalar baseline
@1024 & @2048 (cmp clean → rel-RMS vs OP-3 = 0). HONEST: the ~2x BF16 gap is the doubled cuBLAS-BF16
roofline (roofline-bound), so the store-only lever can only give ~1-2% — delivered exactly that, same
magnitude as OP-1b's TF32 +1.7%. SHIP (positive + bit-exact, no regression). After OP-3b the consumer-card
own-GEMM's identity-preserving lever ladder is EXHAUSTED. 0-pod, NO vast, NO leak (pool host). Verdict
.verdicts/hexa-0pod/F-OP3B-BF16-EPILOGUE.txt.

DEPLETION NOTE: with OP-3b shipped the 0-pod-actionable backlog is DRAINED. Remaining deferred items all
need a GPU build env / frozen-seed runtime, OUT of 0-pod scope: OP-2b (runtime.c forge_dispatch_matmul_t
wrapper body — self/runtime.c build-time-assembled in clm_prod_gpu env), OP-2c (batched-expert transpose-
elim — needs the OP-2b wrapper first), OP-5c (forge error-path/dtype-edge/determinism — can't be byte-eq
gated without a kernel build). No further 0-pod follow-up surfaces from OP-3b (the lever ladder is closed).

## OP-7 — forward conv im2col==direct byte-eq CPU oracle (0-GPU) · GREEN
Self-generated 0-pod follow-up (re-opening the oracle-hardening lane that OP-2 started). Added
stdlib/flame/clm_prod_conv_im2col_eq.hexa: a pure-host `hexa run` oracle that bit-exactly locks the flame
CLMConvMoE trainer's FORWARD causal-dilated conv1d layout transform. The trainer (conv1d_via_forge) computes
the conv as im2col(x)[T,Kdim] + GEMM(.,Wt[Kdim,Cout]) + bias; the oracle proves this equals a DIRECT
sliding-window conv reference y[t,co]=b[co]+Σ_ci Σ_k x[p,ci]*w[co,ci*K+k] (p=t-dil*(K-1-k)). The im2col col
index j=ci*K+k makes the reference's (ci-outer,k-inner) accumulation order EXACTLY the j-ascending GEMM
contraction order ⇒ bit-for-bit equal (true re-layout identity, NOT associativity — no tolerance).
`hexa run` PASS: max|Δ|=0 across 5 shapes (K=3/4/5, dil=1/2/3, Cin==Cout & Cin!=Cout, wide-dilation zero-pad
seam). Honest finding: NONE non-bit-exact — the identity is genuinely exact, max|Δ|=0 is real not faked.
Behavior-preserving: no trainer logic touched (verification/oracle addition only). Forward companion to
OP-2's backward-dW transpose-elim oracle (#2974). Verdict .verdicts/hexa-0pod/F-OP7-IDENTITY-ORACLE.txt.

## OP-6 — vectorize a memory-bound flame sm_120 kernel (.v4 loads/stores, bit-exact) — CLOSED-NEGATIVE
Generalized OP-1's memory-instruction-vectorization lever (.v4/.v2 coalesced loads + vectorized stores) from
the compute-bound own-GEMM to a MEMORY-BOUND flame elementwise kernel on aiden (RTX 5070, sm_120, free pool,
GPU 0% verified). Target = the fp64 AdamW optimizer update _hx_k_adamw_step_inplace
(self/cuda/runtime_cuda.c:1236-1289): 7 fp64 streams (read W,M,V,G + write M,V,W), no reduction, no cross-elem
dependency, scalar grid-stride loads — the correct memory-bound un-vectorized candidate.
Applied double2 (128-bit) coalesced loads + double2 stores (2 elems/thread, scalar n%2 tail).
RESULT (honest, NO win): scalar fp64 AdamW already hits ~333 GB/s; double2 = 1.005-1.006x @16M/64M/odd-tail.
Root-cause probe (op6_bandwidth_probe.cu): pure fp64 COPY also 1.005x (567->570 GB/s); fp32 AdamW with the
literal .v4 float4 lever only 1.028x. On the 5070 (GDDR7) contiguous scalar 32/64-bit grid-stride accesses
ALREADY coalesce to peak DRAM BW → .v4/.v2 add nothing. OP-1 won because its GEMM had STRIDED partially-
uncoalesced smem-feed loads to repair; a contiguous elementwise/copy kernel has no such pattern → the lever
does not transfer (memory-INSTRUCTION vectorization != memory-BANDWIDTH gain when already coalesced).
BIT-EXACT (g5): vec BYTE-IDENTICAL to scalar under --fmad=false (bitdiff=0, max|Δ|=0, all sizes incl odd-N
tail — the rewrite is mathematically pure); under --fmad=true (production default) a 1-ULP (1.388e-17)
FMA-scheduling artifact appears (different fma fusion in single-elem vs pair loop), so a double2 production
rewrite would FAIL the OP-2 byte-eq-vs-prior-trainer gate. NOT shipped (no win + not byte-eq under defaults).
Contiguous-elementwise vectorization lever EXHAUSTED on the 5070; only remaining headroom = AdamW-into-bwd-
GEMM-epilogue FUSION (boundary removal), deferred as OP-6b. $0 (free pool, no vast, no leak). Harness
tool/op6/op6_adamw_vec_bench.cu + op6_bandwidth_probe.cu. Verdict .verdicts/hexa-0pod/F-OP6-VECTORIZE-KERNEL.txt.

## OP-6b — fuse the AdamW update INTO the bwd-GEMM epilogue (boundary-removal) — CLOSED-NEGATIVE
OP-6's deferred follow-up. Determined the bwd-dW path FIRST: conv1d_bwd_via_forge (clm_prod.hexa:238) computes
dW = forge_dispatch_matmul(xcolT,...) → farr_matmul_gpu → REAL cuBLAS Dgemm (runtime_cuda_emit.hexa). The
PRODUCTION bwd-dW GEMM is CLOSED cuBLAS = SCOPE B: you cannot fuse an AdamW epilogue into a cuBLAS call;
boundary-removal is only expressible on an own-GEMM bwd path. Built a scope-A demonstration on aiden (RTX 5070,
sm_120, free pool, GPU 0% verified): fp64 tiled own-GEMM dW[M,N]=A·B, SEPARATE (gemm_dW_store writes dW to DRAM
+ adamw_separate re-reads dW + 2 launches) vs FUSED (gemm_dW_adamw_fused consumes the dW cell IN-REGISTER the
instant the K-loop ends, applies the verbatim ADAMW_BODY, writes W,M,V directly — dW write + re-read + 2nd
launch all eliminated). AdamW arithmetic = ONE shared MACRO in both paths.
PERF (honest, NO win): GEMM-dominated production shapes ~1.000-1.002x (the eliminated dW round-trip is
Amdahl-negligible vs the GEMM cost — e.g. dW[1536,512] saves 0.0126 GB ~0.9-2.1 GB/s over a 5.9ms step).
dW-DOMINATED regime (large M,N, tiny K) is SLOWER 0.98x: the fused epilogue runs the W,M,V elementwise work
inside the GEMM's TILE=16 geometry (low elementwise occupancy) at WORSE bandwidth than a dedicated 256-thread
AdamW kernel, outweighing the ~40-70 GB/s of dW traffic saved. Fusion wins ONLY in a tiny launch-bound regime
(dW[256,256] 1.108x @0.02ms step) where killing the 2nd LAUNCH is a real fraction — a launch-elim win, gone at
production scale.
BIT-EXACT (g5, STRONGER than OP-6): fused W,M,V == separate W,M,V, max|Δ|=0 bitdiff=0 under BOTH --fmad=false
AND --fmad=true at every shape. Unlike OP-6's vectorization (which broke byte-eq under --fmad=true via pair-vs-
single FMA reschedule), register-source fusion changes the gradient SOURCE not the AdamW arithmetic ORDER, so
the FMA chain is identical → byte-eq holds even under production flags.
WHERE BOUNDARY-REMOVAL MUST LIVE: only on the own-GEMM bwd path (cuBLAS closed), AND not worth it even there
(byte-eq but perf-flat/negative) because neither the bwd GEMM nor the AdamW is under-utilized — boundary-removal
pays only when a side is under-filled (cf OG-FUSE-FOLD #2909 under-filling 30 conv micro-launches). Elementwise
optimizer lever now EXHAUSTED on BOTH axes (OP-6 instruction-width, OP-6b boundary-removal). NOT shipped, no
production code changed. $0 (free pool aiden, no vast, no pod, no leak). Harness
tool/op6b/op6b_adamw_fuse_bench.cu. Verdict .verdicts/hexa-0pod/F-OP6B-ADAMW-FUSE.txt.

## OP-8 — MoE softmax+combine byte-eq CPU oracle (0-GPU) · max|Δ|=0
F-OP8-MOE-COMBINE-EQ = 1. Picked the highest-value not-yet-locked flame identity: the CLMConvMoE MoE-router
softmax-gate + gate-weighted expert combine, which lives in the FUSED hot path (HEXA_FUSE_MOE_BLOCK2 megakernel
= gelu2 + expert_pack2 + moe_router in ONE launch). Added LOCAL `hexa run` (0-GPU) oracle
stdlib/flame/clm_prod_moe_combine_eq.hexa locking the trainer's TWO-PASS form (nn_moe_router_fwd: full
probs[T·E] softmax buffer, THEN per-position e-ascending Σ_e probs[t,e]·ex_out[e,t,c]) == a ONE-PASS FUSED form
(the megakernel shape: inline per-position gate kept register-local, combine fused immediately after, NO full-T
probs DRAM round-trip). max|Δ|=0 across 6 shapes (E=2 trainer 2-expert · E=3/4/8 · varied T,C · degenerate
T=1,C=1 pure-gate edge). HONEST (g5): genuine fusion/ordering identity NOT an associativity case — both forms
use the SAME hand-rolled scaled-Taylor _moe_exp (NOT libm/CUDA exp), SAME per-position max-subtraction, SAME
sequentially-summed denominator, SAME e-ascending combine accumulation, so every float op is identical (no
tolerance, max|Δ|=0 not faked). This LOCKS the megakernel's explicit "accumulate BOTH reductions SEQUENTIALLY,
NO tree re-assoc → bit-exact" determinism contract — a future refactor that tree-reduces the softmax sum/combine
or drops the max-sub now breaks the oracle. Canonical order documented: softmax max-sub ON + e-ascending exp/sum
+ sequential denom; combine Σ_e e-ascending; exp = scaled-Taylor _moe_exp. Behavior-preserving: NO trainer logic
changed (oracle/verification addition only). Companion to OP-2 (bwd dW transpose-elim) + OP-7 (fwd conv im2col).
$0 — pure local CPU `hexa run`, no GPU / no pool / no vast. Oracle stdlib/flame/clm_prod_moe_combine_eq.hexa ·
verdict .verdicts/hexa-0pod/F-OP8-IDENTITY-ORACLE.txt.

## OP-9 — GroupNorm/LN valley reduction byte-eq CPU oracle (0-GPU) — 2026-06-09

Continuing the OP-2/OP-7/OP-8 determinism-oracle series, added a LOCAL `hexa run` (0-GPU) oracle that
bit-exactly locks the flame CLMConvMoE GroupNorm "valley" normalization the FUSED hot path (HEXA_FUSE_VALLEY /
HEXA_FUSE_GN_GELU · forge_dispatch_groupnorm_gelu) relies on. WHICH REDUCTION: the production GroupNorm
(gn_lib.hexa nn_groupnorm_fwd / nn_gn_gelu_fused, called from clm_prod.hexa _groupnorm / _groupnorm_gelu) uses
a TWO-PASS mean/variance reduction (NOT Welford): pass-1 sum=Σ_{c∈g,t} X[t,c] → mu=sum/(cg·T); pass-2
vs=Σ (X-mu)² → var=vs/(cg·T); inv=1/_gn_sqrt(var+eps), eps=1e-5 — BOTH passes iterate (t-OUTER,c-INNER),
sequential, NO tree re-assoc. Then Y=gamma·xhat+beta, A=GELU(Y) (erf-based normal CDF, libm builtin).

The oracle proves the UN-FUSED form (_gn_ref = nn_groupnorm_fwd shape: two-pass reduction + SEPARATE affine
sweep writing Y, THEN a SEPARATE GELU sweep re-reading Y → A — two elementwise sweeps over [T·C]) ==
the FUSED VALLEY form (_gn_fused = nn_gn_gelu_fused shape: SAME two-pass reduction, but affine+GELU in ONE
pass — post-GN [T·C] tensor touched ONCE, no Y read+write round-trip — the megakernel shape), with
max(|ΔY|,|ΔA|)=0. Both share _ln_sqrt (byte-identical to gn_lib _gn_sqrt, 40-iter Newton) + _ln_gelu
(byte-identical erf-GELU), same mu, same inv, same affine ⇒ a true fusion/boundary-removal identity, NOT an
associativity case (no tolerance, max|Δ|=0 not faked).

HONEST (g5): the tree-vs-sequential associativity RISK the spec flagged is REAL but does NOT arise here —
gn_lib's fused valley keeps the SAME sequential (t-outer,c-inner) two-pass order as the un-fused path; the
fusion only collapses the GN-affine+GELU elementwise sweeps (boundary removal), it does NOT re-associate the
mean/var sum. So the CPU oracle matches the production reduction order EXACTLY → genuine max|Δ|=0, no eps
needed. CANONICAL ORDER (device kernel = SSOT): sequential (t-outer,c-inner) two-pass mean-then-var,
inv=1/_gn_sqrt(var+eps) eps=1e-5, affine, erf-GELU. A future warp-shuffle/tree reduce of the mean/var sum or a
Welford switch would trip THIS oracle — its job.

`hexa run` PASS, max|Δ|=0 across 7 shapes (G=1 LN-over-channels degenerate, G=2/3/4/8, varied T,C, + T=1 pure
cross-channel + cg=1 G=8 per-channel edges). Behavior-preserving: NO trainer logic changed (oracle/verification
addition only). $0 — pure local CPU `hexa run`, no GPU / no pool / no vast. Oracle
stdlib/flame/clm_prod_ln_reduction_eq.hexa · verdict .verdicts/hexa-0pod/F-OP9-LN-REDUCTION-ORACLE.txt.

## 2026-06-09 — OP-10 DONE: B>1 window-concat causal-conv SEAM characterized (0-GPU)

Made the flame_h100_h200_closeout's KNOWN honest non-bit-exact spot PRECISE. The flame CLMConvMoE batched step
(CLM_PROD_BATCH=B, clm_prod.hexa) concatenates B distinct length-Tw windows into ONE length-T=B*Tw buffer and
runs the causal-dilated Conv1d over the whole concat; the closeout flagged a "K-1 causal-conv SEAM-only Δ" vs a
per-window-segmented conv but did NOT pin the exact positions/magnitude. This LOCAL `hexa run` (0-GPU, no pool,
no vast) oracle computes BOTH paths on CPU with identical weights/bias/FP dtype: (a) the flame concat conv
(every previous-window row visible to the receptive field p = t - dil*(K-1-k)) vs (b) a per-window-segmented
reference that zeros the cross-window causal context, then maps Δ per output position.

FINDING (g5 — honest CHARACTERIZATION, NOT a clean max|Δ|=0-everywhere identity):
  • INTERIOR BIT-EXACT: every output position OUTSIDE the seam band has Δ exactly 0 (interior max|Δ|=0, bad
    interior positions = 0 across all 6 cases — exactly 0, not merely small).
  • SEAM = EXACTLY the first (K-1)*dil output positions of every window AFTER the first; there Δ = the
    cross-window causal context that the segmented conv zeros (genuinely nonzero; mischaracterized seam = 0,
    so the band is neither over- nor under-claimed). Window 0 is fully bit-exact (no previous window).
  • CONFIRMS the closeout's claim AND REFINES it: at dil=1 the band = K-1 (the closeout's named "K-1 seam");
    at dil>1 (the trunk's dilated convs) the band WIDENS to (K-1)*dil — the closeout said a flat "K-1", this
    oracle sharpens it. Seam max|Δ| ranged ~0.035–0.384 on the LCG fixture (e.g. K=3 dil=4 → full 8-wide band).

Behavior-preserving: NO trainer logic changed (characterization/verification addition only). Companion to OP-7
(fwd conv im2col==direct, B=1) — OP-7 locked the B=1 conv bit-exactly, OP-10 maps exactly where B>1 departs.
$0 — pure local CPU `hexa run`, no GPU / no pool / no vast. Oracle stdlib/flame/clm_conv_window_seam_eq.hexa ·
verdict .verdicts/hexa-0pod/F-OP10-CONV-SEAM-ORACLE.txt.

## OP-11 — CE loss + softmax-gradient byte-eq CPU oracle (0-GPU) · 🟢 max|Δ|=0

Continuing the OP-2/OP-7/OP-8/OP-9/OP-10 determinism-oracle series. Added a LOCAL `hexa run` (0-GPU) oracle that
bit-exactly locks the flame CLMConvMoE LOSS path — the flame_h100_h200_closeout-flagged "CE/softmax-grad host
glue". Two independent identities, each replaying its OWN production exp impl (the subtle hazard: the two CE
entry points use DIFFERENT exp):
  (A) BWD fused-grad: clm_ce_grad (clm_prod.hexa:919, libm `exp`) == (softmax(logits) − onehot(target))/T.
  (B) FWD loss scalar: nn_ce_loss_allpos (nn_lib.hexa:957, `dt_exp`/`dt_ln` flame_math Taylor, NOT libm,
      NOT _moe_exp) == definitional mean-NLL.
`hexa run` PASS, max|Δ|=0 across 6 shapes each (V=7..256 CLM-scale, varied T, T=1 edge).

HONEST FINDING (g5) — a REAL associativity gap, found + resolved (NOT faked): the backward grad's TARGET INDEX
is float-sensitive. Production writes (p·invT) for every v THEN subtracts invT at tgt → (p_tgt·invT)−invT; an
algebraically-equal fused reference (p_tgt−1)·invT is float-DIFFERENT. The FIRST oracle run showed grad
max|Δ| = 1.38778e-17 at T12/V7 (all others 0). Fix = replay the EXACT production op order (scale-then-subtract,
NOT refold) → genuine max|Δ|=0 everywhere, no eps. Production order = SSOT (clm_prod.hexa:933-937).

CANONICAL ORDER (SSOT): BWD = libm exp, per-row max-sub, v-ascending denom, grad=p/T then tgt−=1/T;
FWD = dt_exp/dt_ln, per-row max-sub, v-ascending denom, p_t≥1e-6 clamp, t-ascending loss sum, mean/T.
Behavior-preserving: NO trainer logic changed (oracle addition only). $0 — pure local CPU, no GPU/pool/vast.
Oracle stdlib/flame/clm_prod_ce_softmax_grad_eq.hexa · verdict .verdicts/hexa-0pod/F-OP11-CE-SOFTMAX-ORACLE.txt.

## OP-13 — embedding bwd scatter-add byte-eq CPU oracle (0-GPU) — DONE

F-OP13-EMBED-RESIDUAL-ORACLE = 1. Locked the INPUT path (previously unlocked): the token-embedding
gather BACKWARD (nn_lib.hexa nn_embedding_bwd_scatter). Repeated tokens → multiple positions accumulate
into the SAME dtable row; float non-associativity makes the accumulation ORDER load-bearing (the classic
determinism trap). Production order = POSITION-ASCENDING in-place scatter-add.

Oracle stdlib/flame/clm_prod_embed_scatter_eq.hexa, three forms over a repeated-token fixture:
  REF      = exact mirror of nn_embedding_bwd_scatter (i-asc in-place; pre-seeded tied-head term).
  GROUPED+ = per-row reformulation, positions i-ASCENDING  → GATE: REF==GROUPED+ max|Δ|=0 (all 6 shapes).
  GROUPED- = per-row, positions i-DESCENDING → HONEST probe: eps 5.68e-14…4.55e-13 on repeated rows.
hexa run PASS (max|Δ|=0 gate; max-repeat up to 12 positions/row exercised; T=1 probe correctly 0.0).

CANONICAL ORDER (SSOT): per shared token row, accumulate contributing positions' gradients in
POSITION-ASCENDING order (i=0..T-1), matching the in-place scatter loop. A future gather-then-grouped-sum
or GPU atomic-scatter refactor MUST preserve this i-ascending per-row order to stay bit-exact.
HONEST (g5): GATE max|Δ|=0 is a true reorder identity (NOT faked); GROUPED- eps is the genuine
non-associativity witness. Behavior-preserving: NO trainer logic changed. $0 — pure local CPU.
Verdict .verdicts/hexa-0pod/F-OP13-EMBED-RESIDUAL-ORACLE.txt.

## OP-12 — AdamW update-arithmetic byte-eq CPU oracle (0-GPU) · 🟢 max|Δ|=0

Continuing the OP-2/OP-7/OP-8/OP-9/OP-10/OP-11 determinism-oracle series. Added a LOCAL `hexa run` (0-GPU)
oracle that bit-exactly locks the flame AdamW optimizer decoupled-weight-decay UPDATE-arithmetic identity.
OP-6/OP-6b touched the AdamW kernel for PERF (fuse into the bwd-GEMM epilogue) but never oracle-locked the
UPDATE MATH itself. PRODUCTION SSOT = _hx_farr_adamw_step_cpu (self/runtime.c:10783), byte-eq twin of the
CUDA _hx_k_adamw_step (self/cuda/runtime_cuda.c:1236).

PROD (replays the SSOT op order VERBATIM) == REF (a clean Loshchilov-2017 AdamW update written to MATCH the
production associativity). max|Δ|=0 over the FULL state transition — W AND the in-place optimizer state m,v —
across 7 configs sweeping every knob: lr∈{3e-4..1e-2}, β1∈{.8,.9,.95}, β2∈{.99..​.9999}, ε∈{0,1e-8,1e-7,1e-6},
wd∈{0,.01,.05,.1}, step_t∈{1,3,5,10,50,100}, n∈{1,64,96,128,200} (incl. t=1 max-bias-corr, t=100 late, ε=0,
wd=0, n=1 edge). SQRT held CONSTANT across both forms — both call the SAME 24-iter Newton _adamw_sqrt
(flame_math dt_sqrt / gn_lib _gn_sqrt discipline; the SSOT's libm `sqrt` has no `hexa run` float surface and
its own comment pins dt_sqrt ≡ the same double) → the lock ISOLATES the update ORDER. ε is OUTSIDE the √
(denom = √v̂ + ε) in BOTH the SSOT and the oracle.

HONEST FINDING (g5) — a REAL associativity gap, found + resolved (NOT faked max|Δ|=0): a first REF that
grouped the squared-grad term as the natural `(1−β2)·(g·g)` diverged from production by up to 8.88e-16
(1.11e-16 across most of the 7 cases, 2.78e-17/0 on others). The production writes `(1−β2)·g·g`, which the
language groups LEFT-associatively as `((1−β2)·g)·g` — a DIFFERENT IEEE-754 double. Replaying that exact
grouping (production order = SSOT, NOT an algebraic refold) → genuine max|Δ|=0 everywhere, no eps.

CANONICAL ORDER (SSOT, runtime.c:10819-10830): v=(β2·v)+(((1−β2)·g)·g); m=(β1·m)+((1−β1)·g); m̂=m/c1 BEFORE
v̂=v/c2; denom=√v̂+ε (ε OUTSIDE √, sqrt held constant); W'=((W−lr·wd·W)−lr·(m̂/denom)) (two separate
subtractions, decoupled-wd term first); c1,c2=1−βᵗ with βᵗ by repeated-mul (not pow). `hexa run` PASS,
max|Δ|=0 all 7 cases. Behavior-preserving: NO trainer logic changed (oracle addition only). $0 — pure local
CPU, no GPU/pool/vast. Oracle stdlib/flame/clm_prod_adamw_update_eq.hexa · verdict
.verdicts/hexa-0pod/F-OP12-ADAMW-UPDATE-ORACLE.txt.

## 2026-06-09 — OP-14 DONE: flame determinism-contract doc consolidating the byte-eq oracle invariants (0-GPU)

Consolidated the HEXA-0POD byte-eq oracle findings into ONE contributor-facing doc —
docs/flame-determinism-contract.md — making flame's reproducibility-first identity legible. Pure local doc
authoring (0-GPU, $0); NO trainer/oracle/.hexa/.tape code changed.

INDEXED 8 verdicts as a per-phase table (step phase → oracle file → CANONICAL ORDER invariant → what-breaks-it),
with an ASCII step-phase map (g3 minimal):
  · F-OP13 INPUT  embedding bwd scatter-add (position-ASCENDING)
  · F-OP7  FWD    conv1d im2col+GEMM == direct (j-ASCENDING, j=ci*K+k)
  · F-OP2  BWD    dW transpose-elim (same-order contraction sum)
  · F-OP9  NORM   GroupNorm two-pass mean/var (t-out,c-in) + _gn_sqrt + eps=1e-5 + erf-GELU
  · F-OP8  MoE    softmax+combine (_moe_exp, max-sub, e-ASCENDING)
  · F-OP11 LOSS   bwd grad (libm exp) + fwd NLL (dt_exp/dt_ln), v-ASCENDING, scale-then-subtract
  · F-OP12 OPTIM  AdamW (v=β2·v+((1−β2)·g)·g left-assoc; m̂/c1 before v̂/c2; ε outside √; _adamw_sqrt)
  · F-OP10 SEAM   B>1 window-concat conv (interior bit-exact; seam = first (K-1)*dil pos)

CROSS-CUTTING RULE the doc leads with:
  1. THREE distinct exp impls each load-bearing — libm exp (CE bwd) · dt_exp (CE fwd) · _moe_exp (MoE) — a
     "unify the exp" refactor silently breaks byte-eq. (+ _gn_sqrt = 40-iter Newton, not libm.)
  2. Reductions SEQUENTIAL — no tree/warp-shuffle, no Welford.
  3. Accumulations ASCENDING — softmax denom v-asc · MoE combine e-asc · CE fwd t-asc · embed position-asc ·
     GroupNorm (t-out,c-in) · conv/GEMM j-asc.

DOJO POINTER: one-line blockquote pointer to flame-determinism-contract.md added to docs/hexa-dojo.md
"Training recipe — optimization gotchas" (the CLMConvMoE recipe) section. No dojo restructure.

GATE (g5): doc-consolidation milestone — value = the byte-eq reproducibility contract made legible, NOT new
computation. Every canonical-order claim traces to a specific verdict line (no invented invariant). $0, 0-GPU,
no pool/vast. OP-12 (AdamW optimizer oracle) landed in parallel and is indexed here as the OPTIMIZER phase.
Verdict .verdicts/hexa-0pod/F-OP14-DETERMINISM-DOC.txt.

## OP-15 — integration byte-eq oracle (whole micro-step byte-identical run-to-run)

- WIP skeleton pushed (stdlib/flame/clm_step_determinism_eq.hexa).
- DONE (`hexa run`, 0-GPU): composed CLMConvMoE micro-step (embed→conv→GroupNorm→MoE→CE→bwd→AdamW, 17 params)
  BYTE-IDENTICAL run-to-run from same fixed-seed init. loss 4.81916 both runs; max|Δ| = 0 over W, m, v, loss.
  Composition is deterministic — no uninit-scratch / non-det-iteration / address-ordered hole. Comparator
  sensitivity confirmed via negative control (distinct seed → 0.344217; identical → 0.0). GREEN (g5).
  Verdict .verdicts/hexa-0pod/F-OP15-STEP-DETERMINISM.txt.

## OP-16 — gn_lib host fallback (fused-valley GN+GELU 0-GPU hexa-run-testable)

- WIP skeleton pushed (milestone + verdict reproducing the OP-15 link gap).
- GAP REPRODUCED: `hexa run` of a harness that `use`s gn_lib → `Undefined symbols: _forge_dispatch_groupnorm_gelu,
  referenced from _nn_gn_gelu_fused_off`. The bare L3 fused-dispatch symbol has no host body off-CUDA (GPU build
  supplies it via fusion_dispatch.c `#ifdef HEXA_CUDA` glue, absent on CPU).
- HOST BODY written in self/runtime.c as `#ifndef HEXA_CUDA` definition of the bare symbol — two-pass mean/var
  (t-outer/c-inner), eps=1e-5 var+eps, 40-iter Newton _gn_sqrt, erf-GELU, writing the FP64 farr buffers. GPU
  dispatch UNCHANGED (guard avoids duplicate symbol with fusion_dispatch.c).
- BYTE-EQ CURE: naïve body diverged 3.55e-15 (clang -O2 FMA-contracts gamma*xhat+beta; hexa codegen does not).
  `#pragma STDC FP_CONTRACT OFF` (the proven ag_tape recipe) → max|Δ| EXACTLY 0.
- PROVEN (0-GPU): rebuilt runtime.o (`clang -O2 -c`), nm shows symbol U→T; flame_gn_gelu_fused_test (use's
  gn_lib) LINKS+PASSES max_abs_diff=0; tracked oracle clm_prod_gn_gelu_hostdispatch_eq.hexa drives the FUSED
  entry point through the host dispatch (env-gated) vs unfused OP-9 ref → max|Δ|=0 on Y,A,mean,inv,xhat (7 shapes).
- HONEST LANDING (g5, OP-2b-class): self/runtime.c is gitignored frozen-seed (#2065 .c-graduation, no tracked
  emit SSOT for forge dispatchers) → the C BODY lands via a runtime rebuild in the release/build env (verbatim
  body + exact one-rebuild fix in the verdict). Byte-eq oracle + milestone + verdict ship now (tracked).
  links-now YES · byte-eq max|Δ|=0 · GPU untouched YES. Verdict .verdicts/hexa-0pod/F-OP16-GN-HOST-FALLBACK.txt.

## OP-17 — fix runtime.c -Wmacro-redefined (9 libc macros) at source · 🟢 9→0

- WIP skeleton pushed first (milestone + placeholder verdict; durable-worktree rule).
- SIGNAL: clang on self/runtime.c → 9 [-Wmacro-redefined] (strcat/bzero/memcpy/memset/memmove/strncpy/strcpy/
  snprintf/sprintf). Forge-hygiene class — same as OP-5/OP-5b (-Wcomment) but a DIFFERENT warning class.
- TWO COLLIDING SITES located: (1) Darwin _FORTIFY_SOURCE secure headers `<secure/_string.h>`/`_strings.h`/
  `_stdio.h` ALREADY `#define` these 9 as `__*_chk_func` fortify macros (transitive via top `#include <string.h>`/
  `<strings.h>`/`<stdio.h>`); (2) runtime.c "Textual override" block (frozen lines 2070,2082-2087,2095-2096)
  redefines them to the `hxlcl_*` svc-trap helpers. Only these 9 collide — the rest (strlen/memcmp/…) are plain
  externs, not fortify macros.
- MINIMAL FIX: `#undef` the 9 names before the override block — the EXACT precedent the seed already uses for
  `#undef isalnum`/`#undef exit`. BEHAVIOR-PRESERVING (clang -E proof): hxlcl_* is the LAST `#define` either way →
  expansion byte-identical before/after; `#undef` only kills the warning (no-op on Linux glibc → platform-neutral).
- LOCAL VERIFY (0-GPU, `clang -fsyntax-only -DHEXA_RT_SELFEMIT`): -Wmacro-redefined 9→0; the 2 unrelated
  pre-existing classes (4 -Wincompatible-pointer + 12 -Wundefined-internal) UNCHANGED; 0 errors.
- HONEST LANDING (g5, OP-2b/OP-15/OP-16 class): self/runtime.c is gitignored frozen-seed (#2065, restored from
  immutable blob 151c52c8… — no tracked emit SSOT) → durable fix lands as a deterministic, idempotent,
  marker-guarded POST-RESTORE PATCH in the TRACKED tool/restore_frozen_seeds (injects the 9 `#undef`s on every
  restore). End-to-end verified through the patched tool (warnings 0 after restore; re-restore stays single-inject).
  9 warnings GONE · behavior-preserving YES · no new warn YES · GPU/pod/vast NONE ($0).
  Verdict .verdicts/hexa-0pod/F-OP17-MACRO-REDEF.txt.

## OP-20 — deterministic TF32 fast-mode (the PRECISION-CHANGE uncap lever)

Probed the one unexplored uncap lever the campaign named (MEGASTEP + flame_h100_h200_closeout): does a
FP64->TF32 precision change break the ~3x flame step cap WHILE keeping flame's reproducibility identity?
Key insight: TF32 breaks byte-eq-vs-FP64 but can still be byte-eq-vs-ITSELF (run-to-run) — a different
PRECISION CONTRACT (W14: rel-rms<=1e-2 vs same dtype), a legitimate product mode not an identity sacrifice.

Harness tool/bench/flame_bench_step_tf32fast.cu runs BOTH a TF32 lane (CUDA_R_32F /
CUBLAS_COMPUTE_32F_FAST_TF32 tensor-op) and an FP64 lane (CUDA_R_64F / COMPUTE_64F) in ONE process over the
OP-4 fused step DAG (fused valley LN+gelu+copy + transpose-elim bwd GEMM + single-launch AdamW; only the
cuBLAS compute type differs; all elementwise/reduction glue in FIXED deterministic order, no atomics).
-DPEDANTIC toggles CUBLAS_PEDANTIC_MATH to test whether default tensor-op TF32 needs pedantic to stay
self-byte-eq. Driver tool/bench/run_op20_5070.sh, idle-guarded, on FREE aiden RTX 5070 (sm_120, CUDA 13.0).

Result (8/8 cells GREEN, both DEFAULT and PEDANTIC):
  GATE-A self-byte-eq: max|delta(W')| = EXACTLY 0 — pedantic NOT needed (default TF32 already deterministic
         on the 5070; PEDANTIC = identical bytes, identical time → recommend PEDANTIC as portable SHIP guarantee).
  GATE-B rel-RMS(TF32 vs FP64) ~ 1.13e-6 — 4 orders inside W14 1e-2.
  SPEED  FP64/TF32 = 4.19-4.63x @B=1, 19.08-21.36x @B=8 — BREAKS the ~3x cap at every shape.
Honest: B=8 ~20x is inflated by the 5070's crippled FP64 (~1/64 FP32); quote B=1 (4.2x, card-robust) as the
headline. Determinism proven for THIS card/cuBLAS-13.0; pin PEDANTIC to guarantee portably. Single-step
rel-RMS only (long-horizon TF32-vs-FP64 drift deferred). Harness-level (OP-4 fused lane) — live forge GEMM
TF32-dispatch wire deferred (clm_prod build + aiden verify). Deterministic TF32 fast-mode = a REAL flame
fast-mode: identity kept + W14-equivalent + >3x faster. The precision-change uncap lever WORKS. $0, no vast.
Verdict .verdicts/hexa-0pod/F-OP20-TF32-FASTMODE.txt.

## OP-21 — Hopper warp-spec TMA pipeline DESIGN (0-pod, GPU-gated measure) — 2026-06-09

Deep-dive design round, $0/0-GPU, by reading the W10 frontier source + the W-ladder verdicts ONLY. Produced
the design + perf-gap roofline + turnkey H100 recipe for the forge own-GEMM's remaining Hopper (sm_90a wgmma)
perf lever — a warp-specialized TMA producer/consumer software pipeline (the cuBLAS-class mainloop).

W10-HAS (from self/native/wgmma/wgmma_tf32_w10_lib.h gemm_w10): HW TMA producer driven by a single elected
thread (W8 lever), dual consumer warpgroups, SWIZZLE_128B TMA descriptors (W9 permute-removal), the COMPOSED
software decode (W10 fix, bit-exact rel_rms 0), and an NST-deep swizzled-TMA ring (load side pipelined).
W10-MISSES (the cuBLAS-class residual): M1 dedicated producer warpgroup + setmaxnreg register realloc (W10
has NO setmaxnreg; W12 tried it on 128x256 and ptxas IGNORED it C7507 — but the W10 128x128 has 64-reg
accumulator headroom W12's 128 did not); M2 decode/MMA overlap at 2 CTA/SM (gemm_w10 does wgmma.wait_group 0
every slab + a SINGLE non-ringed decode band -> decode<->MMA serialize); M3 descriptor-direct wgmma deleting
the 32KB band (W10-inplace + W15's 3200-config sweep floored rel_rms 1.392/1.000 — the atom-major landing is
a "3rd interaction"); M4 m64n256k8 wider-N; M5 ping-pong epilogue.

PERF-GAP ROOFLINE (cited, NOT re-measured): own W10 70.7 TFLOP/s @4096 vs cuBLAS-TF32 ~430 = 6.09x. Gap
decomposed: occupancy (A) ~0% — W10 is already at the max 2 CTA/SM (W8 closed 1->2; W11/W13 regressed trying
to use more); mainloop/decode-MMA overlap (B) = DOMINANT share (wait_group 0 + single band serialize, cuBLAS
never stalls the TCs); decode-band tax (C) = secondary AND COUPLED to (B) — you can't ring-deepen the band
(W13: 2nd 32KB band -> 1 CTA/SM -27%) NOR delete it (W15: read wrong) without a structural change; epilogue
(D) small (W10 already has the register-blocked scatter). The 6.09x is the (B)+(C) decode/MMA-overlap KNOT.

DESIGNED LEVER OP-21A: untie the knot — (1) canonical-atom re-encode so the SWIZZLE_128B TMA lands the exact
CuTe Layout_K_SW128_Atom the wgmma HW de-swizzle expects (kills W15's root cause, the falsifiable core);
(2) descriptor-direct wgmma -> delete the 32KB software decode band (W15 MEASURED this real: 96->64KB/CTA,
2 CTA/SM held); (3) spend the 32KB on a deeper decode-free TMA ring (NST=3) + wgmma.wait_group<NST-2> so the
oldest committed group drains while the newest issues (the overlap, attacks B); (4) dedicated producer WG +
setmaxnreg.dec 40 / consumer setmaxnreg.inc 232 — GRANTABLE here because the 128x128 accumulator is only 64
regs/thread (W12's 128x256 was 128, rejected). Concrete params: tile 128x128 (kept — W11 proved bigger alone
regresses), TKSW=32, NST=3, full[]/empty[] mbar + wgmma.wait_group<NST-2>, producer/consumer reg split with
single-elected-thread fallback. FALLBACK OP-21B (if canonical re-encode doesn't hit rel_rms 0): keep the band,
register wgmma double-buffer (no M3 dependency). PRE-REGISTERED FALSIFIER stated (lift past 70.7 toward parity,
to confirm/refute on H100; either way a publishable closed-negative with a number).

TURNKEY H100 RECIPE: rent 1 H100 (sm_90a, nvcc 12.6.77, driver 560.35.x — apples to W10/W15) -> author
wgmma_tf32_w16.cu (#include wgmma_tf32_w10_lib.h for same-binary gemm_w10 baseline + canonical-atom encoder +
probe_desc_canonical + gemm_w16 descriptor-direct/NST=3/wait_group<NST-2>/setmaxnreg) -> GATE rel_rms 0
(MODE 0/1 single-tile, then MODE 4 @2048/4096/8192) BEFORE any perf -> ONLY THEN occupancy (confirm 2 CTA/SM)
+ perf sweep own vs same-binary cuBLAS-TF32 (Δ vs W10 70.7) + SASS (STS gone) -> write W16 verdict (new
frontier if lifts bit-exact, else closed-negative W10 KEPT) -> destroy pod (leak 0). One H100-hour suffices.

HONEST (OP-2b-class, g5): NO measurement performed or claimed. This is the DESIGN for a GPU-GATED experiment;
the Hopper sm_90a measure is out of 0-pod scope until an H100 is authorized. cuBLAS-TF32 = roofline, parity
NOT claimed. $0, no vast/pool/pod. Verdict .verdicts/hexa-0pod/F-OP21-HOPPER-WARPSPEC-DESIGN.txt (PR #3000).

## OP-19 — cross-platform byte-exact: libm-exp CE-bwd divergence MEASURED + CLOSED (2026-06-09)

- THESIS (deep-dive, MEASURED REAL): OP-11 found CE-bwd clm_ce_grad uses the libm `exp` builtin; the OP-2/7/8/
  9/10/11/12/13+OP-15 series prove only SINGLE-machine run-to-run byte-eq. Cross-PLATFORM (x86 vs arm64,
  Darwin vs Linux libm) was UNVERIFIED. libm transcendentals are not correctly-rounded → suspected hole.
- ORACLE (0-GPU, $0, free pool): stdlib/flame/op19_crossplatform_selfcontained.hexa — self-contained `hexa
  run` that folds the exact IEEE-754 bytes (f64_to_bytes_le; float_to_bits too new for aiden's runtime.a) of
  CE-bwd grad in libm-exp + dt_exp form. RAN on local+ghost (arm64-macos) vs aiden (x86-linux) = cross-arch +
  cross-OS.
- VERDICT (BEFORE): libm-exp CEBWD fold DIVERGED — local/ghost 7969105254299072804 ≠ aiden 3352931952497630952;
  dt_exp byte-IDENTICAL (7679248634312321699) on all 3. ISOLATED via per-element byte diff: EXACTLY 4/4096 grad
  elems differ, EACH by 1 mantissa-LSB = 1 ULP (glibc vs Darwin libm). Run-to-run stable per machine.
- FIX: clm_ce_grad libm `exp` → dt_exp (matches CE-fwd) on host (clm_prod.hexa) + GPU kernel (_hx_dt_exp_dev in
  runtime_cuda_emit.hexa, _moe_exp_dev precedent → host↔device byte-eq preserved). Grad-change: max abs
  2.17e-18, max rel ≈2.0e-14 (a few ULPs). Trades "matches libm" for "matches across ALL platforms" (g5).
- AFTER: production CE-bwd fold = 7679248634312321699 IDENTICAL on all 3 → cross-platform byte-identical YES.
- OP-11 RE-LOCK: clm_prod_ce_softmax_grad_eq.hexa _ce_grad_prod + _ce_grad_ref libm→dt_exp; F-OP11 = 1 PASS
  (all 6 grad + 6 loss cases max|Δ|=0). Contract doc updated (3 exp impls → 2).
- RESIDUAL (honest latent, OP-19b deferred): GELU libm `erf` (fwd+bwd) is the same hole; no bit-accurate
  deterministic erf in-tree + `erf` won't link on aiden's runtime → documented follow-up.
- $0 · 0-GPU · free pool (aiden/ghost) · no vast · no pod. Verdict .verdicts/hexa-0pod/F-OP19-CROSSPLATFORM-EXACT.txt.

## OP-24 — wire deterministic TF32 fast-mode into the live forge GEMM dispatch (env-gated, byte-eq-safe, aiden) 🟢 dispatch-unit
- GOAL: take OP-20's PROVEN deterministic TF32 fast-mode (self-byte-eq + W14-tol vs FP64, 4.2x @B=1) +
  OP-23's validated N-step trajectory and WIRE it into the REAL flame forge GEMM dispatch the CLMConvMoE
  trainer rides — env-gated like HEXA_OWN_GEMM/HEXA_FUSE_*, FP64 default UNCHANGED. The OP-2-class
  harness-win→live-trainer wire the F-OP20 verdict named as the deferred follow-up.
- DISPATCH SITE: self/cuda/runtime_cuda_emit.hexa `_hx_cuda_farr_matmul_gpu` (the forge row-major
  projection GEMM; same fn OP-2 touched for transpose-elim). Default = cublasDgemm (FP64); prior only
  opt-in was HEXA_OWN_GEMM (naive _hx_k_gemm). runtime_cuda_emit.hexa is git-TRACKED, NOT a frozen seed
  (FROZEN_SEEDS = runtime.c + .c fragments + hexa_cc.c) → durable landing is the ordinary branch→PR path.
- WIRE: new `else if (_forge_tf32_fastmode())` branch (env HEXA_TF32_FASTMODE). FP64 farr buffers are
  double; TF32 path casts A,B→fp32 into SCRATCH (never mutates inputs → FP64 default byte-identical),
  runs cublasGemmEx CUBLAS_COMPUTE_32F_FAST_TF32 on a SEPARATE PEDANTIC-pinned handle g_cublas_tf32
  (OP-20's portable self-byte-eq ship guarantee), casts result fp32→FP64 C. Cast = fixed-order elementwise
  (no reduction/atomics) → no determinism hazard. g_cublas (FP64) untouched, stays fp64-strict.
- VERIFY (aiden RTX 5070 sm_120, CUDA 13.0, FREE pool, idle-guarded): op24_tf32_livewire_dispatch.cu
  replays the EXACT wired codepath (same FP64 buffers, cast kernels, PEDANTIC handle, arg layout) — the
  LIVE dispatch logic in isolation, not the OP-20 fp32-storage harness. 4/4 cells (D={768,1536}×B={1,8})
  PASS all 3 gates: GATE-A FP64-default byte-id max|Δ|=0; GATE-B TF32-live self-byte-eq max|Δ|=0;
  GATE-C W14 rel-RMS ~2.94e-4 (~34x inside 1e-2); SPEED 29.9–51.0x (GEMM-only).
- HONEST (g5): dispatch-UNIT not full-trainer. rel-RMS 2.9e-4 = RAW single-GEMM output (OP-20's 1.1e-6
  was post-AdamW weight delta — both pass, different metric). 30-51x OVERSTATES trainer step (5070 FP64
  ~1/64 throttle + no glue dilution); card-robust signal = OP-20's B=1 ~4.2x. EXACT remaining OP-2b-class
  step: build clm_prod_gpu -DHEXA_CUDA on aiden, run trainer HEXA_TF32_FASTMODE=1 vs unset, report loss
  self-byte-eq + wall step/s. PEDANTIC PINNED (not optional) = portable determinism; GATE-B=0 confirms.
- $0 · free aiden · no vast · no pod · aiden /tmp cleaned (no residue). Verdict F-OP24-TF32-LIVEWIRE.txt;
  raw tool/bench/op24_5070_raw.log.

## OP-26 — machine-independent bit-exact training: rigorous results writeup (docs-only, 0-pod, $0, NO paper) — 2026-06-10
- DELIVERABLE: docs/flame-machine-independent-training.md — a rigorous, evidence-complete RESULTS document
  (NOT a paper) consolidating the HEXA-0POD result that flame's CLMConvMoE step is FULLY machine-independent
  byte-exact. Verified by READING the existing verdicts; NO new computation, NO GPU, NO vast, NO pod.
- THE CLAIM: same fixed-seed step produces the same weights/grads/loss to the LAST BIT on x86-64-linux (glibc)
  and arm64-macos (Darwin libm) — cross-arch AND cross-OS. torch/JAX do NOT give this (libm exp/erf/log are
  not correctly-rounded; glibc vs Darwin round the last ULP differently). flame has NO libm transcendental
  left on the step path → every transcendental is a fixed-iteration +−×÷ routine = bit-identical on any
  IEEE-754 hardware.
- THREAT MODEL → closure → verdict (ASCII diagrams in doc): T1 libm-not-correctly-rounded → dt_exp/dt_erf/
  dt_ln/_moe_exp + Newton sqrt (F-OP19/19b/8/11) · T2 tree/warp reduction → sequential ASCENDING (F-OP8/9/11)
  · T3 atomic-scatter → position-ASCENDING scatter-add (F-OP13).
- EVIDENCE TABLE — 12 cited verdicts with byte-cmp values: F-OP7/2/8/9/11/12/13 per-phase (max|Δ|=0 + honest
  reorder probes 1.39e-17 / 8.88e-16 / 5.68e-14), F-OP15 whole-step capstone (max|Δ|=0 over W/m/v/loss,
  neg-control 0.344217), F-OP19 CE-bwd libm exp DIVERGE (arm64-macos 7969105254299072804 vs x86-linux
  3352931952497630952 = 4/4096 × 1 ULP; dt_exp 7679248634312321699 identical on all 3), F-OP19b GELU dt_erf
  fwd 4548590605583584556 / bwd 4249661408190172843 identical on local+ghost arm64-macos + aiden x86-linux,
  F-OP23 TF32 self-byte-eq N=100 + loss-track ~1e-7.
- DETERMINISM CONSTRUCTION recipe (§4) + HONEST LIMITS (§5): dt_erf 1.38e-7 from libm BY DESIGN · TF32
  self-not-cross-precision · single-machine GPU scope (host↔device byte-eq + cross-platform CPU byte-eq) ·
  B>1 conv seam intentional (F-OP10) · production-stdlib final 0.0 read build-deferred.
- Pointer added from docs/flame-determinism-contract.md (contributor SSOT) → the results doc.
- GOVERNANCE (project.tape g84 PAPER OPT-IN): logged-discovery consolidation ONLY. NO /paper scaffolded, NO
  PAPER.tape/PAPER.md created, paper skill NOT invoked. A paper happens ONLY on explicit /paper.
- $0 · 0-GPU · 0-pod · no vast. Verdict .verdicts/hexa-0pod/F-OP26-MACHINEINDEP-WRITEUP.txt.

## OP-19c — 3rd-platform byte-exact: pi5-akida arm64-LINUX confirms machine-independence (2026-06-10)
- GOAL: extend OP-19/19b's 2-platform proof (x86-linux aiden ↔ arm64-macos local/ghost) to a 3rd distinct
  arch×OS cell = pi5-akida arm64-LINUX (Raspberry Pi 5, glibc) — isolates arch-vs-OS (same arch as macos, same OS
  as aiden). FREE POOL ONLY (pi5-akida), ZERO vast, 0-GPU (`hexa run`), $0.
- pi5 hexa status: RUNNABLE = YES. OP-19/19b noted pi5 had no hexa; installed it 0-pod this op:
  (a) official installer pulled prebuilt hexa-linux-arm64.tar.gz (v0.17.3) → hexa 0.1.0-dispatch (SAME version
      as all 3 prior hosts — apples-to-apples). ELF aarch64 GNU/Linux.
  (b) pi5 has gcc 13.3.0 but NO clang; `hexa run` C-backend hardcodes clang → dropped user-local ~/.hx/bin/clang
      shim → gcc, stripping the clang-only -fbracket-depth flag.
  (c) release tarball ships no self/ → scp'd a matching-version self/ runtime tree (runtime.c + headers +
      native/*.c + forge/*.c) from the local 0.1.0-dispatch install, md5-verified; `tar -h` to dereference the
      4 macOS-absolute symlinks (native/crypto_blowfish.c, hxtok.h, parser_v2.c, hxtok.c). symlinked ~/.hx/bin/self.
- pi5 byte folds (verbatim `hexa run` output):
    CEBWD-TAYLOR (dt_exp)  = 7679248634312321699
    GELUFWD-DET  (dt_erf)  = 4548590605583584556
    GELUBWD-DET  (dt_erf)  = 4249661408190172843
    (libm baselines also dumped: CEBWD-LIBM = 3352931952497630952, GELUFWD/BWD-LIBM = glibc values)
- 3-WAY cmp (pi5 vs recorded arm64-macos local/ghost + x86-linux aiden):
    CE-bwd dt_exp  : MATCH  (7679248634312321699 on all 3)
    GELU FWD dt_erf: MATCH  (4548590605583584556 on all 3)
    GELU BWD dt_erf: MATCH  (4249661408190172843 on all 3)
  => 3-PLATFORM BYTE-IDENTICAL = YES. {x86,arm64}×{linux,macos} matrix now 3/4 cells confirmed (4th = x86-macos,
     no pool host — retired Intel Macs). pi5 supplies the arm64-linux diagonal isolating arch vs OS.
- BONUS (strengthens OP-19): pi5 arm64-linux CEBWD-LIBM = 3352931952497630952 == aiden x86-linux, NOT arm64-macos's
  7969105254299072804. => the libm `exp` divergence OP-19 measured is an OS/libc effect (glibc vs Darwin libm), NOT
  arch — pi5 tracks the OS it shares (Linux/glibc), not the arch it shares (arm64). dt_exp/dt_erf remove that path.
- NO divergence on the production deterministic path. $0 · 0-GPU · 0-pod · free pool (pi5-akida only) · no vast.
  Verdict .verdicts/hexa-0pod/F-OP19C-PI5-3PLATFORM.txt.

## OP-24b — TF32 fast-mode end-to-end through the REAL clm_prod_gpu trainer (aiden build attempt) — 2026-06-10
- GOAL: complete OP-24's TF32 live-wire from dispatch-UNIT to the FULL end-to-end CLMConvMoE trainer —
  build clm_prod_gpu -DHEXA_CUDA on aiden (free RTX 5070, HAS nvcc) + run flame trainer FP64 vs
  HEXA_TF32_FASTMODE=1. FREE aiden only, ZERO vast, foreign pod 40306156 untouched.
- RESULT = HONEST BUILD-GATED (OP-2b-class, g5 OR-branch). clm_prod_gpu BUILT ON AIDEN = NO.
- EXACT BLOCKER (quantified at current main 304a4019f): the real trainer stdlib/flame/clm_prod.hexa
  (1421 L) calls 31 forge_dispatch_<op> ops; their HOST marshal wrappers hexa_forge_dispatch_<op>(HexaVal..)
  must live in a coherent runtime.c. The frozen seed runtime.c (151c52c82, restore_frozen_seeds) provides
  ONLY 2/31 (matmul + ffn_fp64_via_bf16). The other 30 are in NO tracked current-main source: 24 live only
  in the UNTRACKED inbox patch forge-devfeed-lever-a-runtime-c-fragment.c.txt (749 L, stale worktrees);
  ~6 hand-spliced on the gone W2 pod, never re-frozen. restore_frozen_seeds appends only OP-18
  #ifndef HEXA_CUDA CPU fallbacks, not the #ifdef HEXA_CUDA device wrappers. = the same terminal wall
  project_clmprod_gpu_build_seed_drift documents, now measured: 2/31 present, 30 missing. aiden adds the
  toolchain (nvcc 13.0/sm_120 compiles fine) but NOT the missing SOURCE → wall unmoved.
- UNBLOCK (maintainer/CI, one-time): re-freeze a runtime.c seed with all 31 #ifdef HEXA_CUDA host wrappers,
  OR add a CUDA build job to release.yml. THEN 0-pod on aiden: transpile clm_prod.hexa, emit runtime_cuda.c
  (TF32 wire already in it), nvcc -DHEXA_CUDA, link -lcudart -lcublas -lcuda, run trainer x2.
- 0-POD DELIVERED (the well-formed proof): emitted current-main runtime_cuda.c (334KB, TF32 wire present:
  10 hits) COMPILES CLEAN under `nvcc -x cu -DHEXA_CUDA -arch=sm_120` on aiden -> runtime_cuda.o 3.4 MB
  (benign warnings only, none in TF32 code). nm confirms ALL TF32 symbols emitted: _hx_k_cast_d2f/f2d,
  g_cublas_tf32 (PEDANTIC handle), _hx_cuda_gemm_tf32_dev, _hx_cuda_farr_matmul_gpu (TF32 else-if branch);
  only external cublasGemmEx/cublasSetMathMode undefined (resolve at -lcublas link). => TF32 branch is
  WELL-FORMED + CODEGEN-COMPLETE in the real -DHEXA_CUDA context. Only the RUN is gated, not the code.
- BONUS FINDING (0-pod, real): first -DHEXA_CUDA compile surfaced a PRE-EXISTING OP-19b regression —
  _hx_dt_exp_dev defined TWICE in runtime_cuda.c (line 1624 + dead line-4092 Taylor variant; OP-19b's
  "defined ONCE above" comment never removed the 2nd). Latent emit bug that ONLY breaks under nvcc
  -DHEXA_CUDA (the 0-GPU blind spot OP-15 named). Isolated (renamed dead def) for the proof; trivial
  0-pod follow-up = delete the line-4092 block from self/cuda/runtime_cuda_emit.hexa.
- $0 · free aiden · no vast · no pod · aiden ~/op24b_wellformed cleaned (no residue). NO end-to-end run
  claimed (g5). Verdict .verdicts/hexa-0pod/F-OP24B-TF32-ENDTOEND.txt.

## 2026-06-10 — OP-24c DONE: TF32 end-to-end TURNKEY build kit (build_clmprod_tf32_e2e.sh) WRITTEN + local-checked, GPU-build-gated run (0-pod, $0)
- GOAL: turn OP-24b's honest build-gated finding into a TURNKEY one-command kit — the OP-21A pattern
  (code+script ready, measurement env-gated) wired specifically to the TF32 end-to-end test through the
  REAL clm_prod_gpu CLMConvMoE trainer. 0-pod: WRITE + local-check the script; NO build, NO run, NO GPU.
- DELIVERED: tool/clm/build_clmprod_tf32_e2e.sh (turnkey, bash -n VALID, every step concrete). The moment
  a complete-frozen-seed GPU-build env is authorized, the whole test = `bash tool/clm/build_clmprod_tf32_e2e.sh`.
- STRUCTURE (JOB a-e): (a) PROVISION CHECKLIST + ZERO-VAST guard (does NOT rent; exits clean if no nvcc /
  no sm_120+ GPU) + OP-23/24 idle guard. (b) frozen-seed stage (FROZEN_SEED_REF=151c52c8… restore_frozen_seeds)
  + EXACT-BLOCKER PRE-CHECK: greps restored self/runtime.c for the 31 host marshal wrappers clm_prod.hexa calls;
  if any missing, prints the F-OP24B blocker verbatim (the 30 absent, the 2 unblock options) + EXITS 3 BEFORE
  wasting a build; then EMIT runtime_cuda.c (TF32 wire asserted present) + nvcc -x cu -DHEXA_CUDA -arch=$ARCH
  + gcc-link -lcudart -lcublas -lcuda (the proven recipe). (c) run the trainer x2 each FP64-default +
  HEXA_TF32_FASTMODE=1, tiny config (CLM_PROD_{D,E,T,BATCH,NSAMP,EPOCHS} env knobs, all verified in main()).
  (d) g5 GATE SEQUENCE: GATE-A FP64-unchanged (run1==run2 loss max|Δ|=0) → GATE-B TF32 self-byte-eq → GATE-C
  TF32-tracks-FP64 (OP-23 E2E, worst |Δloss|/|loss_FP64| <= W14 1e-2) → SPEED wall step/s ratio (ONLY after
  A+B+C PASS, with the honest glue-dilution caveat: << GEMM-only 30-51x, nearer OP-20 ~4.2x @B=1; consumer-card
  FP64 ~1/64 inflates it; no superiority claim). (e) verdict headline + leak-0 cleanup trap.
- LOCAL 0-POD CHECK (verbatim): `bash -n tool/clm/build_clmprod_tf32_e2e.sh` -> PASS. Referenced paths/flags/
  knobs verified at current main: restore_frozen_seeds OK, runtime_cuda_emit.hexa OK, clm_prod.hexa (main L1164)
  OK, frozen ref 151c52c8… resolves to a commit, all 6 CLM_PROD_* knobs read by main(). self/runtime.c is
  correctly ABSENT at main (graduated-removed seed RESTORED by the script's own step b.1 BEFORE step b.2 greps
  it — ordering correct). inbox patch absent (F-OP24B says untracked; script doesn't depend on it).
- EXACT REMAINING GPU-BUILD-ENV-GATED STEP (F-OP24B-confirmed, the single irreducible wall): in the canonical
  self-host build env, re-freeze a runtime.c seed carrying ALL 31 #ifdef HEXA_CUDA host wrappers (today 2/31:
  matmul + ffn_fp64_via_bf16), OR add a CUDA build job to release.yml. THEN `bash tool/clm/build_clmprod_tf32_e2e.sh`
  runs unchanged + the pre-check passes instead of exiting 3. TF32 code already proven well-formed + codegen-
  complete under -DHEXA_CUDA (F-OP24B §3) — only the RUN is gated, and this script IS the run.
- TURNKEY = YES. HONEST: no end-to-end number claimed (kit-ready, run-gated; OP-21A framing). 0-pod · $0 · no
  vast · no pod · no GPU · no leak · foreign pod 40306156 untouched. Verdict .verdicts/hexa-0pod/F-OP24C-TF32-TURNKEY.txt.

## OP-19d — 4th-env byte-exact: musl (Alpine) strengthens machine-independence to 3 distinct libm impls (2026-06-10)
- GOAL: extend OP-19/19b/19c's 3-platform proof (Darwin · glibc-x86 aiden · glibc-arm64 pi5) to a 4TH DISTINCT
  ENVIRONMENT giving a 3rd DISTINCT libc/libm — musl (Alpine). The hardest "no libm dependence left" test:
  musl ≠ glibc ≠ Darwin. FREE POOL ONLY (summer's docker), ZERO vast, 0-GPU, $0.
- 4th env chosen = MUSL (Alpine Linux) via `docker run alpine` on summer (has /usr/bin/docker). Picked over a 4th
  glibc host because musl is a genuinely new libm impl. summer's own native glibc hexa was bootstrap-broken (hexat
  transpiler missing, runtime_core.c rebuild fails 10 errors) → summer served ONLY as the docker host, not a glibc run.
- hexa runnable on musl = YES, with a DISCLOSED TEST-ONLY shim. hexa.real is glibc-linked (can't run under musl), but
  `hexa run` = transpile→C then `clang …runtime.c -lm`. Transpiled both oracles on aiden (self/native/hexa_v2), then
  COMPILED+RAN the C in Alpine — binaries link MUSL (`ldd → libc.musl-x86_64.so.1`), libm = musl. Build fixes (build-
  only, NOT numeric): `-include sys/un.h…` (musl <sys/un.h> strlen proto vs runtime `#define strlen`), `-fuse-ld=lld`,
  apk gcc+libgcc (CRT). REAL RUNTIME BUG found (gdb): SIGSEGV at init in _hexa_init_mem_cap→hxlcl_getenv — the
  priority-101 `hxlcl_capture_environ(argc,argv,envp)` ctor relies on the glibc/Darwin-only "(argc,argv,envp)→ctor"
  ABI; musl passes NO args to ctors → envp garbage → segfault before main. Worked around with a throwaway runtime copy
  (ctor reads musl `extern __environ`; env-capture ONLY, all math byte-identical; NOT committed). The ctor-ABI bug is a
  genuine runtime follow-up (separate guarded PR), INDEPENDENT of fold math.
- musl byte folds (verbatim, env-capture-shimmed run):
    CEBWD-TAYLOR (dt_exp)  = 7679248634312321699
    GELUFWD-DET  (dt_erf)  = 4548590605583584556
    GELUBWD-DET  (dt_erf)  = 4249661408190172843
- 4-WAY cmp (musl vs recorded Darwin + glibc-x86 aiden + glibc-arm64 pi5):
    CE-bwd dt_exp  : MATCH  (7679248634312321699 on all 4)
    GELU FWD dt_erf: MATCH  (4548590605583584556 on all 4)
    GELU BWD dt_erf: MATCH  (4249661408190172843 on all 4)
  => 4-ENVIRONMENT BYTE-IDENTICAL = YES.
- # DISTINCT libm impls spanned = 3 (glibc · musl · Darwin). libm `erf` (GELU-FWD-LIBM) gives 4 DIFFERENT values
  across the 4 envs: musl 7314648833623304241 ≠ glibc-x86 6306829276275644424 ≠ glibc-arm64 3332333775004383127 ≠
  Darwin 1521224270287218303, while dt_erf is identical on all → DEFINITIVE: only the dt_* path is machine-independent.
  (libm exp CE-bwd: musl 3352931952497630952 == glibc, ≠ Darwin 7969105254299072804 — confirms OP-19c's OS/libc thesis
  with a 3rd libc in hand.)
- NO divergence/defect on the production deterministic path (the musl init segfault is a pre-main libc-ABI env-capture
  bug, flagged as a runtime follow-up). $0 · 0-GPU · 0-pod · free pool (summer docker + Alpine) · ZERO vast · foreign
  pod 40306156 untouched. Verdict .verdicts/hexa-0pod/F-OP19D-4TH-ENV.txt.

## OP-19e — musl-safe env-capture (POSIX environ, not constructor-args ABI); fixes the OP-19d SIGSEGV (0-pod)
- THE durable fix for the REAL hexa-runtime↔musl bug OP-19d surfaced. ROOT CAUSE: self/runtime.c (frozen 151c52c8…,
  "RUNTIME tail (cycle 85)") priority-101 ctor `hxlcl_capture_environ(int argc, char**argv, char**envp){ hxlcl_environ
  = envp; }` relies on the glibc/Darwin-only "(argc,argv,envp)→constructor" ABI. musl runs ctors with NO args → `envp`
  is a garbage register → `hxlcl_environ`=garbage → SIGSEGV in `_hexa_init_mem_cap`→`hxlcl_getenv` BEFORE main().
- FIX: read the POSIX global `extern char **environ` (defined by EVERY libc incl. musl) instead of the ctor arg:
    extern char **environ;
    static char **hxlcl_environ = 0;
    __attribute__((constructor(101)))
    static void hxlcl_capture_environ(void) { hxlcl_environ = environ; }
    #define environ hxlcl_environ
  `extern char **environ;` + the body's `environ` read sit BEFORE the `#define environ hxlcl_environ` shadow → bind the
  libc symbol. BEHAVIOR-PRESERVING on glibc/Darwin (ctor-arg envp and libc `environ` point at the same vector at start);
  FIXES musl (real pointer, not a garbage register).
- DURABLE LANDING: self/runtime.c is gitignored (frozen seed). Per OP-16/17/18, the fix lands as an idempotent,
  marker-guarded OP-19e post-restore awk patch in tool/restore_frozen_seeds (rewrites the 6-line capture block on every
  restore). ONE tracked file changed; runtime.c stays untracked. wipe_guard scoped (small additive patch, no deletions).
- PROOF (0-pod · summer docker + Alpine · $0 · NO vast · NO GPU):
  (a) isolated reproducer, both variants compiled NATIVE: Alpine/musl (/lib/ld-musl-x86_64.so.1) OLD ctor-ABI =
      "Segmentation fault (core dumped)" exit 139; NEW POSIX-environ = "environ_nonnull=1 OP19E_PROBE=hello PATH=1"
      exit 0. Ubuntu glibc 2.39 OLD≡NEW identical (exit 0). Darwin (local clang) NEW clean exit 0.
  (b) full patched self/runtime.c BUILDS: Darwin `clang -fsyntax-only` exit 0 (zero errors); Alpine/musl `clang -c` →
      runtime.o OK, ZERO environ diagnostics (extra flags = OP-19d-class build-env: header pre-ordering + lld + gcc/
      libgcc CRT + openssl/sodium-dev — BUILD-ONLY, not the env fix).
  (c) BONUS — REAL native-musl `hexa run` of stdlib/flame/op19_crossplatform_selfcontained.hexa against the OP-19e-
      patched runtime, NO SHIM: transpiled to C on aiden (build/hexat), compiled+linked in Alpine/musl →
      `ldd → libc.musl-x86_64.so.1`, RUN_EXIT=0 (SIGSEGV GONE). Deterministic Taylor folds BYTE-IDENTICAL across
      Darwin + glibc(summer) + native-musl (all built from the same patched runtime):
        CEBWD-TAYLOR  (dt_exp)  = 7679248634312321699   (all 3)
        GELUFWD-TAYLOR(dt_erf)  = 4548590605583584556   (all 3)
        GELUBWD-TAYLOR          = 636106759170901885    (all 3)
      libm-* lines DIVERGE (Darwin≠glibc≠musl) → only dt_* is machine-independent, now on a REAL musl run not a shim.
- GATE g5: env-capture musl-safe (POSIX environ) YES · musl SIGSEGV GONE YES · behavior-preserving glibc/Darwin YES ·
  durable via restore_frozen_seeds YES · bonus native-musl folds match YES. Residual: NONE on the env-capture path
  (musl build still needs OP-19d's documented build-env knobs — pre-existing, not this ABI bug).
- Temp artifacts cleaned on summer (docker image + /tmp), aiden (/tmp), local. Foreign vast pod 40375114 untouched.
  Verdict .verdicts/hexa-0pod/F-OP19E-MUSL-ENVFIX.txt.

## OP-21C — w16.cu remaining-MODE GPU-free reference logic CPU-validated 0-pod (extends OP-21B)
- branch domain/hexa-0pod-op21c (worktree off origin/main). 0-pod: no GPU, no vast, no pod, $0.
- GOAL: extend OP-21B's D1 CPU de-risk to the OTHER w16.cu MODEs' GPU-free reference logic, so MORE of
  build_w16.sh's H100 gate sequence (not just MODE 0/1) is CPU-pre-validated before the run.
- WROTE tool/wgmma/w16_modes_cpu_check.cpp (clang++ -std=c++17, ZERO GPU/CUDA/PTX) — ports SSOT arithmetic
  VERBATIM (gmma_phys, tf(), composed_A/composed_B) + models the device epilogue scatter VERBATIM from
  gemm_w16 L395-403. 6 element-for-element/bit-exact checks:
      C1a  epilogue register->global scatter = BIJECTIVE FULL COVER of 128x128 tile (every output once)
      C1b  MODE-4 FULL-TILE (128x128) ref GEMM = TF32-round + fp32-FMA in kernel K-order == straight GEMM
           bit-for-bit (K=96 turns NST=3) — extends OP-21B T6's 8x8 to full tile
      C2   B per-slab read recovers global B bit-exact across ALL 3 slabs + all 4 N-atoms (12288/12288)
      C3   gemm_w16b band decode (composed -> gmma_phys repack) == gemm_w16 operands (A/B 4096/4096 each)
      C3b  w16b per-slab 128x128 GEMM == w16 per-slab GEMM (16384/16384) — same math, different schedule
      C4   descriptor stride byte arithmetic self-consistent across NST=3 stages (ring st*SWBUF, w16 kk*4
           [0,32,64,96]B, w16b (kk>>3)*512*4 [0,2k,4k,6k]B, MODE-1 lbo=16/sbo=1024 vs 1024B atom)
- RAN locally (0-GPU): 6 PASS, 0 FAIL, exit 0 — remaining-MODE GPU-free reference logic CPU-PROVEN correct, NO bug.
  Teeth confirmed: injected wrong-xor in B read drops round-trip to 2190/4096; epilogue cover catches double-write/gap.
- GATE g5: extended harness runs locally YES · additional MODEs' GPU-free reference logic proven correct YES (no bug).
  STILL H100-GATED: device wgmma swmode=1 HW de-swizzle (MODE 1/4 rel_rms), the gemm_w16b device band path, ALL perf.
  No wgmma/PTX executed, no TFLOP/s claimed. Build temp cleaned (disk-frugal). Foreign vast pod 40375114 untouched.
  Verdict .verdicts/hexa-0pod/F-OP21C-W16-MODES-DERISK.txt.

## OP-23b — TF32 drift N=500 + LR-schedule (longer/harsher horizon) — GREEN (aiden 5070, $0, 0-pod)
- EXTENDED OP-23 (#3005) to a LONGER + HARSHER regime to resolve its caveat ("N=100, no LR-schedule;
  flat-to-shrinking to step 100 with no late blow-up — does it hold longer/harsher?"):
    N=500 (5x) · standard transformer LR schedule (linear warmup 50 steps 0->1e-3, then cosine decay to
    5e-5; computed in DOUBLE, passed IDENTICALLY to both lanes so the schedule is not a divergence source) ·
    harder structured synthetic (row/col sinusoidal dGrad target, default D bumped 768->1024).
  Harness: tool/bench/flame_traj_drift_tf32_op23b.cu (step DAG byte-identical to OP-23/OP-20; only cuBLAS
  compute type differs + per-step LR). Driver: run_op23b_5070.sh (idle-guarded, DEFAULT+PEDANTIC).
- 4/4 cells on aiden RTX 5070 sm_120 (D={1024,768}, T=256, B={1,8}). FREE pool, NO vast, NO pod, leak-0,
  /tmp/op23b cleaned after. Raw: tool/bench/op23b_5070_raw.log.
- RESULTS (verbatim):
    DEFAULT  D=1024 B=1  selfByteEqN=Y  lossTrackN=3.170e-06  worstLossTrack=1.864e-04@3  lateWorst=3.240e-06@476  peakWorst=3.284e-06@52
    DEFAULT  D=1024 B=8  selfByteEqN=Y  lossTrackN=1.145e-07  worstLossTrack=1.904e-04@3  lateWorst=2.156e-07@492  peakWorst=2.909e-07@52
    DEFAULT  D=768  B=1  selfByteEqN=Y  lossTrackN=3.398e-06  worstLossTrack=6.334e-05@5  lateWorst=3.518e-06@454  peakWorst=3.338e-06@48
    PEDANTIC D=1024 B=1  selfByteEqN=Y  lossTrackN=3.170e-06  worstLossTrack=1.864e-04@3  lateWorst=3.240e-06@476  peakWorst=3.284e-06@52
- THREE QUESTIONS:
    Q1 bounded-to-500-vs-late-blowup -> BOUNDED. Worst gap always EARLY (step 3-5); late-half worst SMALLER
       and FLAT; step-500 tracking 1e-7..3.4e-6. NO late blow-up. Caveat resolved in the GOOD direction.
    Q2 LR-schedule amplifies? -> NO. Warmup-peak window [45..55] worst (~3e-6/~3e-7) == steady-state order;
       the 1e-3 LR peak is not a spike. Bounded-tracking SURVIVES the schedule.
    Q3 self-byte-eq at 500? -> YES every cell (W AND loss max|delta|=0 over the whole 500-step trajectory).
- Weight rel-RMS@500 = 9.7e-3 (B=1) / 4.6e-5 (B=8): chaotic-but-bounded (5x steps + harder target + noisy
  B=1) — exactly why LOSS, not weights, is decisive (butterfly drifts weights; loss tracks). OP-23 lesson re-confirmed.
- VERDICT: TF32 fast-mode HOLDS at the longer/harsher horizon — training-equivalent (bounded loss-tracking)
  to >=N=500 under an LR schedule + through the warmup peak. STRENGTHENS OP-23 (1-step ~1e-6 was a real
  fast-mode, not an illusion). HONEST SYNTHETIC CAVEAT (unchanged): still a proxy (loss=mean(G^2), single
  fused block, structured-synthetic target); real-corpus CLMConvMoE end-to-end is GPU-build-gated (OP-24b/24c).
  Verdict .verdicts/hexa-0pod/F-OP23B-TF32-DRIFT-LONG.txt.

## OP-26b — machine-independent training SUBMISSION-READINESS assessment (4-env evidence; NO paper scaffold, g84)
- DELIVERABLE: docs/flame-machine-independent-SUBMISSION-READINESS.md — a go/no-go readiness assessment
  (NOT a paper) so the user can decide whether/when to instruct /paper. Authored by READING verdicts; $0 0-pod.
- STRONGEST-CURRENT CLAIM: machine-independent bit-exact CLMConvMoE training byte-identical across
  {x86,arm64}x{linux,macos} + musl, spanning 3 DISTINCT libm impls (glibc/musl/Darwin) — STRONGER than
  OP-26's 2-platform consolidation. Growth: OP-19c (F-OP19C) pi5 arm64-linux 3rd cell (libm split = OS/libc
  not arch); OP-19d (F-OP19D) musl 4th env / 3rd libm impl (libm erf = 4 values, dt_* identical);
  OP-19e (F-OP19E) durable POSIX-environ fix -> real un-shimmed native-musl run.
- READINESS CHECKLIST: DONE = result (F-OP15 whole-step max|delta|=0) + 8 per-phase oracles + 4-env evidence
  + threat model + construction recipe + honest limits, all -> verdicts. PAPER ADDS = abstract · related-work
  survey (PyTorch/JAX determinism, CNR, CR-libm/RLIBM) · figures · repro Docker artifact · venue fit · front-matter.
- GAP LIST: G1 real-corpus e2e = GPU-build-gated (HIGH) · G2 2nd architecture (MED) · G3 x86-macos cell
  blocked (no Intel-Mac host, LOW) · G4 perf<->det Pareto via TF32/BF16 (MED) · G5 cross-GPU-arch byte (MED)
  · G6 musl ctor-ABI fix CI-gate (LOW).
- NOVELTY: torch/JAX/TF give NO cross-platform bit-exact training (libm not correctly-rounded); flame removes
  ALL libm — MEASURED: libm erf = 4 different values across 4 envs, dt_exp/dt_erf collapse all to bit-identical
  folds; split proven OS/libc not arch (pi5 tracks aiden). Honest: reproducible-everywhere NOT bit-equal-to-libm
  (dt_erf 1.38e-7 by design); byte-exactness is FP64-lane (TF32/BF16 self-det, not cross-precision).
- GOVERNANCE (g84 PAPER OPT-IN): NO /paper scaffolded, NO PAPER.tape/PAPER.md/LaTeX, paper skill NOT invoked.
  Doc ends with the explicit user action: USER runs `/paper new flame-machine-independent` (or similar) — the
  agent does NOT auto-scaffold per g84. CONFIRMED no paper scaffolded.
- Milestone OP-26b flipped [x]. Verdict .verdicts/hexa-0pod/F-OP26B-SUBMISSION-READINESS.txt. $0 · 0-GPU · 0-pod · no vast.

## OP-28 — real-corpus token-pipeline determinism oracle (0-pod slice of gap G1; input side proven, GPU step still gated)
- 0-POD SLICE OF G1: OP-26b gap G1 (real-corpus end-to-end) is GPU-build-gated because the trainer STEP needs
  the GPU. But the trainer's INPUT side — the token pipeline producing the (ids,targets) fed to clm_step — runs
  on CPU and IS 0-pod-verifiable. OP-28 proves that input pipeline deterministic + machine-independent.
- THE PIPELINE (verbatim from flame_d32_corpus_test.hexa, the production byte-level corpus path):
  (1) tokenize = read_file_bytes -> byte ids [0,256) [V=256]; (2) pack/window = IDS[s*T+p]=toks[s*stride+p],
  YS[s]=toks[s*stride+T] (pure integer index math, fixed ascending (s,p) order); (3) batch = (IDS,YS)==(ids,targets).
- ORACLE stdlib/flame/op28_corpus_loader_det.hexa — SELF-CONTAINED (no `use`, scp/stdin-runnable on any host),
  embedded 306-byte ASCII corpus = the same bytes read_file_bytes yields (disk-free, disk-frugal). Runs full
  pipeline twice + emits f64_to_bytes_le(checksum) IEEE fingerprint for cross-platform byte-diff.
- FINDING: byte-level token path is PURE INTEGER — NO float, NO libm transcendental, NO dict/set/hash-ordered
  vocab iteration — so (ids,targets) bit-identical run-to-run AND across machines BY CONSTRUCTION.
- GATE PASS: ids max|delta| = 0, targets max|delta| = 0 run-to-run; checksum 441979096 identical both runs.
  ids[window 0] = 99 111 110 115 ... = literal bytes of "conscious..." (REAL corpus ids, not synthetic).
- PROCESS-TO-PROCESS: two independent `hexa run` invocations -> full 945-byte output BYTE-IDENTICAL (diff empty).
- CROSS-PLATFORM (free CPU pool host, $0, NO vast/NO GPU): local arm64-macos (Darwin libm) vs aiden x86-linux
  (glibc) emit the byte-IDENTICAL IEEE-754 fingerprint `0 0 0 216 16 88 186 65`; ids/targets/checksum identical.
  aiden /tmp cleaned; no pod/GPU/vast touched.
- STILL GPU-GATED (honest, G1 NOT fully closed): the GPU TRAINER STEP (nn_decoder_fwd/grad/AdamW on the
  (ids,targets)) is the gated remainder. OP-28 closes the INPUT-side slice only; the STEP RUN remains gated.
- RESIDUAL: BPE path (V=151936) also documented-integer but flame's BPE has a known upstream chr()-unicode
  limitation (not cleanly 0-pod-runnable today) — FLAGGED, not locked.
- Milestone OP-28 flipped [x]. Verdict .verdicts/hexa-0pod/F-OP28-CORPUS-LOADER-DET.txt. $0 · 0-GPU · 0-pod · no vast.

## OP-29 — machine-independence generalizes to a 2nd flame model arch (decoder block) — GREEN
- GAP: OP-26b gap G2 (a 2nd architecture beyond CLMConvMoE). The 8 per-op oracles + OP-15 capstone all lock the
  SAME CLMConvMoE step; OP-29 proves the machine-independent determinism construction GENERALIZES to a SECOND arch.
- 2nd ARCH: stdlib/flame/decoder_block_lib.hexa — pre-norm Transformer DECODER BLOCK (GQA scaled-dot attention +
  RoPE + SwiGLU + RMSNorm). Shares NO operators with CLMConvMoE (no conv/MoE/GroupNorm). Tiny CPU config
  T=4·d=8·nh=2·nkv=1·h=16, fixed LCG seed (no RNG/clock).
- ORACLES: op29_decoder_block_determinism_eq.hexa (run-to-run, imports production lib) +
  op29_decoder_block_selfcontained.hexa (cross-platform inline-reduction twin, NO `use`, scp-runnable).
- RUN-TO-RUN: fwd Xout max|Δ|=0, bwd grads max|Δ|=0, bwd dX max|Δ|=0 (both oracles).
- HOLE #1 (libm RoPE, closed): nn_rope_build_tables computes inv-freq via libm ln/exp → leaks libm. Closed with
  deterministic _rope_build_tables_dt (dt_exp/dt_ln/d5_cos/d5_sin) — the OP-19/19b discipline.
- HOLE #2 (FMA matmul — the REAL find, closed): with #1 closed the block was still byte-eq run-to-run but
  byte-DIVERGENT cross-platform. Bisect (cache-stage checksum): cos/sin/Bp/X/rin identical; FIRST divergence =
  Q projection. Isolated to the C farr_matmul kernel (ikj FMA-fused clang -O2): on byte-identical fp64 inputs an
  8×8·8×4 matmul returns arm64 ck=241449363 vs x86 ck=1401117690 (arm64 fuses a*b+c into one FMA, x86 mul+add).
  Closed by re-implementing _db_proj_batch_farr/_db_grad_accum_farr as INLINE ascending dot products (no C kernel)
  → inline ck=1401117690 on BOTH ISAs. Same sequential-reduction discipline the CLMConvMoE oracles use.
- CROSS-PLATFORM (free CPU pool host, $0, NO vast/NO GPU): local arm64-macos (Darwin) vs aiden x86-linux (glibc)
  emit byte-IDENTICAL fingerprints FWD `0 0 64 78 44 169 214 65` · GRAD `0 0 128 244 215 140 211 65`; checksums
  fwd=1520742713 grad=1311989714 identical. aiden /tmp + ~ probe files cleaned; no pod/GPU/vast touched.
- CONTRACT learned: any flame arch must route matmul through inline ascending reductions, not the FMA-fused
  farr_matmul, to be byte-identical across ISAs. Machine-independence GENERALIZES beyond CLMConvMoE → Y. G2 closed.
- Milestone OP-29 flipped [x]. Verdict .verdicts/hexa-0pod/F-OP29-2ND-ARCH.txt. $0 · 0-GPU · 0-pod · no vast.

## OP-30 — cross-ISA matmul invariant formalized in the determinism contract (0-pod, docs-only)
- Deep-dive round-7 branch ①. NO GPU, NO vast, NO pod, NO .tape edits, NO foreign-pod touch. $0.
- PROBLEM: OP-29's cross-cutting find (the C farr_matmul FMA-fused kernel byte-DIVERGES across ISAs) lived ONLY
  in the OP-29 milestone block + verdict — not discoverable as a contract invariant. OP-30 formalizes it.
- ADDED to docs/flame-determinism-contract.md §1: "### cross-ISA invariant: matmul = inline ascending reduction,
  NOT FMA-fused" — RULE (det-path matmul MUST accumulate via inline ascending reductions; FMA-fused farr_matmul
  forbidden), WHY (clang -O2 fuses a*b+c → 1-rounding FMA on arm64 but mul+add 2-roundings on x86; cites OP-29
  ck=241449363 arm64 vs ck=1401117690 x86 from byte-identical fp64 inputs W ck=1950370123/xbt ck=527426024),
  SCOPE (cross-ISA layer ON TOP of run-to-run + libm-free — a model can be both and STILL cross-ISA-divergent),
  HOW (inline ascending dot the oracles use, OR -ffp-contract=off off the det path). ASCII arm64-vs-x86 FMA
  diagram (g3 minimal) + a "what breaks the contract" checklist entry.
- ADDED to docs/flame-machine-independent-training.md: the 3-LAYER determinism model (run-to-run · libm-free ·
  cross-ISA-FMA-free) in §1 claim, a 4th threat-model row T4 (FMA-fused matmul ISA divergence → inline ascending
  dots, F-OP29) distinct from T1/T2/T3 as a back-end codegen (not library) divergence, recipe item (d) "inline
  ascending matmul — NOT the FMA-fused C kernel", and an F-OP29/F-OP30 provenance entry.
- 3-LAYER MODEL: layer1 run-to-run (OP-2/7/8/9/11/12/13+OP-15) · layer2 libm-free (OP-19/19b) · layer3
  cross-ISA-FMA-free (OP-29) — independent; clearing any two does NOT imply the third.
- Every claim traces to F-OP29-2ND-ARCH (g5). NO new computation, docs-only consolidation.
- Milestone OP-30 flipped [x]. Verdict .verdicts/hexa-0pod/F-OP30-CROSSISA-CONTRACT.txt (invariant text + 3-layer
  model + cited OP-29 evidence verbatim). $0 · 0-GPU · 0-pod · no vast.

## OP-28b — BPE tokenizer byte-to-unicode fix (canonical GPT-2/Qwen map); BPE pipeline determinism-provable (0-pod)
- Deep-dive round-7 branch ③. NO GPU, NO vast, NO pod, NO .tape edits, NO foreign-pod touch. $0.
- CLOSES OP-28's flagged residual: the BPE path (flame_bpe_corpus_lib.hexa, V=151936 real Qwen vocab) was not
  cleanly 0-pod-runnable because self/ml/tokenizer_bpe.hexa build_byte_to_char did NOT build the canonical
  GPT-2/Qwen bytes_to_unicode.
- ROOT CAUSE (verified on the live hexa runtime, two defects):
  (1) chr-truncation / wrong-glyph: printable bytes used chr(b) -> RAW byte (probe chr(161)=[161], chr(288)=[32]
      == space collision hazard); canonical (+ Qwen vocab.json) uses the UNICODE codepoint U+00A1.. for the
      Latin-1 printable range (probe from_char_code(161)=[194,161] = UTF-8 U+00A1). chr is byte-truncating.
  (2) wrong codepoint formula: non-printable bytes used from_char_code(256+byte) instead of the canonical running
      counter 256+n — agree only for bytes 0..32, DIVERGE for 35 bytes 127..160,173 (byte 127 canonical U+0121
      vs old U+017F; byte 160 U+0142 vs U+01A0; byte 173 U+0143 vs U+01AD).
  OP-28 had attributed the residual to chr() truncation — that is defect (1); the dominant defect was (2).
- FIX (surgical, build_byte_to_char): emit the canonical 256-entry bijection via the UTF-8 encoder from_char_code
  for the WHOLE table (printable byte -> from_char_code(byte); the rest -> from_char_code(256+n) running counter).
  Never byte-truncating chr in the byte->unicode map. Pure integer/table, no libm/float/hash-order. Decode side
  (bpe_decode + build_char_to_byte) already UTF-8-codepoint-aware, consumes the same table -> no decode change.
  flame_bpe_corpus_lib.hexa header: limitation RESOLVED.
- ORACLE stdlib/flame/op28b_bpe_byteuni_det.hexa (self-contained, use-free cross-platform twin embedding the
  canonical map + a tiny self-contained BPE byte-encode->merge->id over canonical-glyph merge/vocab tables —
  no merges.txt/vocab.json disk dependency).
- GATE GREEN (hexa run): byte->unicode->byte round-trip = 256/256 exact; glyph collisions = 0; space byte 32 ->
  glyph [196,160] = canonical U+0120 -> back 32; bytes 127/160/173 all round-trip; bpe ids "hello hello" ->
  22 33 11 55 44 33 11 55 (l+l merge + space+h merge fire); bpe ids max|Δ| run-to-run = 0; F-OP28B-BPE-FIX = 1.
- PROCESS-TO-PROCESS byte-eq: two independent hexa run -> 945B output byte-identical (diff clean). YES.
- CROSS-PLATFORM byte-eq: local arm64-macos == aiden x86-linux (sidecar pool CPU host, scp self-contained source):
  checksum 102745433, FINGERPRINT `0 0 0 100 21 127 152 65` on BOTH; full output diff clean. YES. aiden /tmp
  cleaned; no pod/GPU/vast touched.
- OP-30: BPE is integer (no matmul) -> FMA cross-ISA invariant N/A; confirmed NO libm/float leak in the token id
  path (byte->uni table, encode, merge, id lookup all pure integer/string-table; remaining chr() uses are in
  bpe_decode/byte_detokenize rebuilding a RAW byte from a recovered 0..255 value = correct).
- HONEST REMAINDER: NOT exercised against a real on-disk 151936-entry Qwen vocab.json (oracle stays use-free +
  disk-frugal with canonical-glyph self-contained tables; the FLAGGED byte-encoder is fixed, merge/id machinery
  is unchanged integer lookups — a full real-vocab round-trip is the natural next confirmation, needs vocab files
  staged, NOT a code defect). The simplified space-split pre-tokenizer (vs GPT-2's full regex) + the GPU trainer
  step are unchanged + out-of-scope.
- Milestone OP-28b flipped [x]. Verdict .verdicts/hexa-0pod/F-OP28B-BPE-FIX.txt. $0 · 0-GPU · 0-pod · no vast.

## OP-30b — fix stale "GELU erf still-open" line in the determinism contract (0-pod, docs-only)

- 2026-06-11 · deep-dive round-8 branch ① (OP-30 residual). OP-30 (#3047) flagged out-of-scope a STALE line in
  docs/flame-determinism-contract.md: the step-phase-map closing parenthetical still read "(The GELU `erf` is a
  still-open libm hole — see §1 residual.)" — pre-OP-19b leftover, factually wrong since OP-19b (#3008,
  F-OP19B-DET-ERF) closed the GELU erf hole via dt_erf (A&S 7.1.26 branchless on dt_exp, no libm,
  byte-identical cross-platform), and contradicting the doc's own §1 closure paragraph + NORM table row +
  what-breaks checklist. The "§1 residual" pointer was dangling.
- Surgical fix: parenthetical now states the current truth — erf likewise closed (dt_erf, F-OP19b), step has NO
  libm transcendental left, pointer → §1 closure. Whole-doc stale-claim scan found NO other contradiction
  (remaining "still" hits = correct run-to-run-vs-cross-ISA F-OP29 usages; "residual" hit = the
  F-OP13-EMBED-RESIDUAL-ORACLE filename). Doc internally consistent about erf post-fix
  (grep still-open/still open/open libm → 0).
- Milestone OP-30b flipped [x]. Verdict .verdicts/hexa-0pod/F-OP30B-CONTRACT-FIX.txt. Docs-only · $0 · 0-GPU ·
  0-pod · no vast. Honest: consistency fix only, no new determinism claim.
