> 📍 SSOT: [ARCHITECTURE.md](ARCHITECTURE.md) · governance [CLAUDE.md](CLAUDE.md)

@title: 🟩 HEXA-CUDA — "just write CUDA in hexa" cookbook

@goal: A user-facing cookbook for writing hand-authored GPU kernels directly
in `.hexa` via the `@gpu_kernel` → NVPTX path (RFC 055 / gpu/SPEC.md),
contrasted with the auto-fusion flame/forge path. Grounded in the REAL
intrinsic/launch surface the compiler supports today — honest gaps marked.

## milestones

- [x] D0 — surface inventory: honest "what device intrinsics / launch forms
      hexa supports TODAY" matrix (thread/block/grid index, barrier, atomics,
      warp shuffle, WMMA, shared mem, gpu_launch). DONE — see the matrix in
      docs/hexa-cuda-cookbook.md §3 and the summary in HEXA-CUDA.log.md.
- [x] D4 — cookbook authored at docs/hexa-cuda-cookbook.md with runnable
      example kernels using ONLY verified-real syntax: vector-add, SAXPY,
      parallel reduction, tiled matmul. DONE (build-verified: pending — see D1).
- [x] D1(a) — DONE (un-gate landed, branch domain/hexa-cuda-nvptx-ungate):
      `hexa build --target=nvptx…` driver was GATED in the bootstrap binary
      (`_build_nvptx_emit_driver` at self/main.hexa:2404 returned 1 with
      `[nvptx] GATED RFC071-P3-PathB`). The gate reason ("compiler bodies NOT
      linked / 6 undefined symbols") was STALE — self/main.hexa already
      imports all 7 pipeline modules (lines 10-16), so `codegen_emit_ptx_for_sm`
      + lex/parse/lower/lower_hir/static_atlas were already in scope. Replaced
      the gate body with the inline lex→parse→lower→lower_hir→
      codegen_emit_ptx_for_sm pipeline (1:1 mirror of the verified spec sibling
      compiler/cli/build_nvptx.hexa). +50/-6, single file, OFF-safe (reached
      only from the nvptx dispatch branch; default build byte-identical).
      Verdict: .verdicts/hexa-cuda/F-HEXACUDA-NVPTX-UNGATE.txt (GREEN).
- [ ] D1(b/c/d) — remaining gaps found during D0, filed as follow-on work:
      (b) `gpu_shared_f64` / `gpu_shared_add` / `gpu_shared_get` used by the
          qforge `@phase("parse_only")` reference kernels are NOT real codegen
          intrinsics — the real shared-memory form is `@shared let t: [f64; N]`
          (gpu/SPEC.md §6). Cookbook uses the real form; flagged the divergence.
      (c) `gpu_tf32_round` (qforge mixprec kernel) is likewise not a codegen
          intrinsic — TF32 is host-side cuBLAS in that harness, not device PTX.
      (d) FP64 `exp()` intrinsic underflow bug below x≈−745 (qforge a2f d6 note)
          — kernel-side guard documented; codegen fix is a separate inbox item.
- [x] D2 — DONE + SILICON-VALIDATED on a real H100 (sm_90). `hexa build
      --target=nvptx` emits SOURCE-DERIVED PTX end-to-end (`.visible .entry
      vec_add`/`saxpy`, `.target sm_90`, `.version 7.8`, 4× `.param .u64`, real
      index-math + bounds-check + ld/st.global.f64 + ret). Both cookbook
      vec-add AND SAXPY @gpu_kernel were re-emitted by a FRESH self-host-built
      `hexa` (`tool/release_build`, Stage 0/1/2) on an H100 80GB HBM3 pod, then:
        · `ptxas -arch=sm_90` → exit 0, EMPTY stderr (CLEAN) — both kernels.
        · device run via the CUDA Driver API (cuModuleLoad → cuLaunchKernel,
          grid=ceil(2^20/256), block=256) → maxerr 0.000e+00, 0 mismatches
          over 1,048,576 f64 elements vs CPU reference — both kernels.
      D2 is fully silicon-PROVEN: .hexa @gpu_kernel → hexa build → PTX → ptxas
      cubin → driver-API launch → bit-exact result, no .cu / nvcc.
      Verdict (verbatim ptxas + device output): .verdicts/hexa-cuda/
      F-HEXACUDA-PTXAS-DEVICE.txt. Harness + PTX artifacts in
      tools/hexa-cuda-validate/.

## adoption — steer devs to `.hexa` GPU kernels over py/.cu (the funnel)

Capability exists (D0-D4); ADOPTION = remove every reason a dev falls back to
py/.cu: "blank page" · "porting effort" · "don't see the hexa path" · "editor
doesn't help". Levers D6-D9 attack each. (Branch domain/hexa-cuda-adoption-dx;
verdict .verdicts/hexa-cuda/F-HEXACUDA-ADOPTION-DX.txt.)

- [x] D6 — scaffolding: `hexa new gpu-kernel <name>` one-command @gpu_kernel
      skeleton (cmd_new + _new_gpu_kernel_template in self/main.hexa; `new`
      dispatch branch + top-level catalog + core_commands() SSOT row). Emits a
      minimal *compiling* vec-add kernel (REAL intrinsics) + host launch shape +
      build hint. Generated kernel output parse-checks clean. WIRED into the CLI
      (build-verify of the full self/main.hexa self-build pending — stale local
      oracle hangs flattening main.hexa).
- [x] D7 — porting guide: docs/hexa-cuda-porting-guide.md — line-by-line
      `.cu → .hexa` for vec-add / SAXPY / parallel reduction / tiled matmul +
      the full CUDA→hexa intrinsic mapping table (threadIdx.x→gpu_thread_id_x,
      __syncthreads→gpu_barrier, __shared__→@shared let, atomicAdd→gpu_atomic_add,
      __shfl_*→gpu_warp_shuffle_*, wmma→gpu_wmma_*, <<<>>>→gpu_launch) +
      10-step translation checklist. Cross-linked both ways with the cookbook.
- [x] D8 — nudge-lint: tool/lint_cu_nudge.hexa — report-only, NEVER-blocking
      advisory (exits 0) that scans for hand-written `.cu` + nvcc build steps and
      emits "this can be a @gpu_kernel — see the cookbook". Nudge fires correctly
      on a fixture. STANDALONE tool + documented integration points (pre-commit /
      build wrapper / future in-compiler .cu-FFI hook behind HEXA_CU_NUDGE=1) —
      NOT wired into `hexa build` (no user-facing .cu FFI/link path exists in the
      compiler today to hook; the advisory() string is the canonical message
      when one lands).
- [x] D9 — LSP/DX: self/lsp.hexa extended with @gpu_kernel intrinsic completion +
      hover for the 29 gpu/SPEC.md §5 intrinsics (get_gpu_intrinsics SSOT →
      handle_completion + handle_hover + all_global_names; gpu_intrinsics_export
      + `hexa-lsp gpu-intrinsics` CLI verb). Machine-readable artifact checked in
      at gpu/gpu_intrinsics.lsp.json (29 items, validated). self/lsp.hexa
      parse-checks clean; in-tree bin/hexa-lsp rebuild build-verify pending (fresh
      worktree lacks the bootstrap self/native/hexat artifact).
- [x] D10 — DOJO (learn-by-doing): `hexa dojo hexa-cuda <slug> '<spec>'` emits
      `@gpu_kernel` authoring katas — a 4-rung ladder (vec-add · reduction ·
      tiled-gemm · wmma) of kernel.hexa + CPU oracle + host gpu_launch shape +
      run.sh parse-gate + README, with a `--lang=both` `.cu`/ctypes contrast.
      REAL intrinsics only (gpu/SPEC.md §5/§6; wmma kept parse-clean — the
      gpu_wmma_* family is codegen-level/RFC 067, documented not source-called).
      Sibling track `hexa dojo flame-forge` emits flame `.hexa` trainers (linreg ·
      mlp · tiny-clm) with a descent gate. All 7 emitted katas hexa-parse clean;
      all 3 flame-forge trainers RUN + PASS the descent gate (local CPU).
      PREFLIGHT-HARDENED: the flame-forge run.sh cloud path (DOJO_CLOUD=1) sources
      tool/dojo_rent_preflight.sh — the 6-fix "no-troubleshoot" RunPod rent/preflight
      helper (image-tag validation · PUBLIC_KEY inject · supply ladder 8→4→2 /
      SECURE→COMMUNITY / H200→H100→A100 · failure classification · per-GPU mem
      OOM-block via stdlib/cloud/preflight.hexa · torchrun --tee/--redirect log
      harvest), reflecting sidecar handoff 4474f21b (anima 7B DDP fire). Helper
      self-tests GREEN (all 6 fixes, no rental); OOM-block + auth fail-fast verified
      locally — NO silent dead pods. RECIPE-HARDENED (sidecar handoff a10891bc — the
      anima 7B CLMConvMoE DDP *training-recipe* lessons): the preflight now folds a
      training-recipe advisory into the mem gate — RECOMMEND --bf16-weights for ≥~3B-param
      models (the anima 7B winner ~70GB; fp32-AdamW thrashes 96-99% near the 141GB cap),
      BLOCK adamw-8bit when a single tensor > 2^31 elements (the bitsandbytes ops.cu:226
      break), + a "DDP-won't-help-if-model-bound" advisory (single-GPU can beat multi-GPU
      when conv/GEMM-bound). The tiny-clm README carries a bench-before-vectorize note
      (grouped-conv 14min/step vs ModuleList 74s/step — fewer launches ≠ faster), and
      docs/hexa-dojo.md gains a "Training recipe — optimization gotchas" section. Advisory
      self-tests GREEN (+5 cases). CITED anima observations — attributed, not re-measured.
      Docs: docs/hexa-dojo.md (incl. the no-troubleshoot preflight + the training-recipe
      gotchas sections). DOJO-IMPROVE (branch domain/hexa-dojo-improve): (a) the fp32/f32
      dtype mismatch is FIXED end-to-end — DOJO_DTYPE=fp32 (docs + emitted run.sh) used to
      error `unknown --param-dtype fp32` on the hexa preflight path; _dtype_bytes +
      the shell coarse-mem gate now accept fp64=f64 / fp32=f32 / fp16=f16 aliases, self-test
      stays GREEN (+2 dtype-alias cases). (b) vision · rl · tabular PROMOTED stub → [full]:
      real flame trainers over the same stdlib/flame substrate as flame-forge — vision
      (softmax-clf · patch-mlp, softmax-CE descent; patch-MLP floor since flame has no 2-D
      conv backward yet — honest, ref.py uses nn.Conv2d) · rl (bandit-pg · gridworld-pg
      REINFORCE + baseline, deterministic inline-LCG sampling, reward-ASCENT gate) · tabular
      (logreg · mlp-tab, softmax-CE descent). All SIX domains now [full]; every new kata
      emits 4 files + emitted train.hexa parses clean + RUNs with its gate GREEN + run.sh
      bash -n clean + ref.py py_compile clean + --lang filter correct (verified via a
      localized-import harness against the worktree modules). Verdict:
      .verdicts/hexa-cuda/F-HEXACUDA-DOJO.txt (GREEN, §8). Build-verify pending:
      `hexa dojo domains` listing all SIX [full] via the INSTALLED binary (Jun-1
      binary caches a precompiled stdlib/dojo snapshot — SOURCE verified via
      self-contained compile) · NVPTX PTX emission (needs a CUDA host) · a live
      multi-GPU DDP rent (preflight LOGIC locally verified).
- [x] D11 — DOJO reflects the own-GEMM / megakernel arc (branch
      domain/dojo-reflect-owngemm): the landed `sm_90a` `wgmma`+TMA own-GEMM
      W-ladder (W6 50.7 → W8 66.5 → W10 70.7 TFLOP/s, all bit-exact rel-RMS 0,
      ~6.09× off cuBLAS-TF32 roofline @4096³) + the persistent whole-step
      megakernel (both walls closed — own-GEMM removes the cuBLAS-call wall;
      a grid-sync cooperative kernel closes the GroupNorm full-y reduction wall,
      byte-eq max|Δ|=0) are reflected into the track-1 hexa-cuda dojo as a
      READING LESSON ("GPU own-GEMM parity & the persistent megakernel" in
      docs/hexa-dojo.md). HONEST FRAMING throughout: cuBLAS = roofline, parity
      NOT achieved (6.09×), util-via-megakernel is a CLOSED-NEGATIVE — the win is
      OWNERSHIP/completeness, not a perf/util brag. The 4 named gotchas (GMMA 8×4
      INTER layout · `fence.proxy.async.shared::cta` · single-elected-thread HW
      TMA producer for occupancy · software-composed `SWIZZLE_128B` w/ HW-swizzle
      closed-neg) are documented as `.cu`/codegen-level engineering lessons — NOT
      source-callable `@gpu` intrinsics (no invented source calls). CITES the
      landed verdicts verbatim (F-FUSION-SM90-WGMMA-W8/W10 · MEGAKERNEL-GN-GRIDSYNC,
      PRs #2841/#2847/#2845) + the lit scan (docs/research/sm90-wgmma-parity-litscan.md,
      #2846). No new perf claims of our own. Verdict:
      .verdicts/hexa-cuda/F-HEXACUDA-DOJO.txt (§9). Docs-only, no GPU.
- [x] D12 — DOJO reflects the DECISION/ALGORITHM root cause "WHY the 7B parallel
      path FAILED" (branch domain/dojo-parallel-rootcause; sidecar handoff
      f5e18a0f — the companion to the infra 4474f21b + recipe a10891bc handoffs,
      both already reflected). docs/hexa-dojo.md "Training recipe — optimization
      gotchas" gains a decision-grade subsection "WHY parallel was the wrong path
      — root cause": THE TRAP (vectorize 30 ConvExpert ModuleList → one grouped
      Conv1d(E·d,E·d,K,groups=30), 186 240 channels, to cut 30 launches → 1) →
      THE 11× MEASUREMENT (grouped ~14 min/step vs ModuleList ~74 s/step on H200,
      cuDNN on or off) → THE ROOT CAUSE (a wide many-group conv defeats GPU
      group-parallelism; cuDNN falls to a naive path — fewer launches ≠ faster)
      → THE CASCADE (DDP replicates the FULL model so each GPU re-pays the 11×;
      4×H200 DDP lost to 1×H200 at 4× cost — parallel was NOT wall-first) +
      the secondary 2³¹ trip-wire (the 3.47 B-elem fused weight breaks
      bitsandbytes optim8bit at ops.cu:226 — VECTORIZATION is what crosses the
      ceiling) → the 4 PRESCRIPTIONS (keep experts as a ModuleList + bench-first ·
      MEASURE single-GPU step on the ACTUAL kernels before DDP, don't parallelize
      a pathological op · gate vectorization on the 2³¹ ceiling · canonical
      7B-ENGINE recipe = single 141 GB H200 + ModuleList + grad-ckpt + AdamW8bit
      ~74 s/step), as a before/after side-by-side. The preflight
      tool/dojo_rent_preflight.sh dojo_recipe_advisory carries the two causal
      lines cleanly — "DON'T PARALLELIZE A PATHOLOGICAL OP" (MEASURE single-GPU
      first; DDP multiplies it) + "VECTORIZATION is what crosses the 2³¹ ceiling"
      — self-test stays GREEN (+2 cases, bash -n clean). CITED anima H200
      observations (f5e18a0f) — attributed, NOT re-measured here; no new perf
      claims authored. Verdict: .verdicts/hexa-cuda/F-HEXACUDA-DOJO.txt (§10).
      Docs/tool only, NO GPU (leaked-pod sweep: 0 leaked — only the spared
      rtsc-39610026 anchor + known owned campaign pods; rented nothing).
- [x] D13 — DOJO reflects this session's TWO byte-exact-gated GPU-kernel PARITY
      breakthroughs + the regime law (branch domain/dojo-parity-recipes). A new
      decision-grade reading-lesson subsection "GPU kernel parity recipes —
      canonical-atom GEMM · weight-reuse conv · the under-fill/saturated regime
      law" lands in docs/hexa-dojo.md (in the GPU/kernel area, after the parallel
      root-cause subsection): (a) own-GEMM stuck off cuBLAS → RE-ENCODE the operand
      in GLOBAL to the canonical CuTe Layout_K_SW128 / gmma-INTER atom + NO-swizzle
      TMA so the landed SMEM tile IS wgmma-ready (descriptor-direct, NO 32KB decode
      band) — single-tile rel-RMS 1.000 → 0.000, smem 96→64KB (2 CTA/SM), own-GEMM
      70.2 → 264.7 TFLOP/s, ratio 6.09× → 1.37× (~85–90% of the gap closed,
      bit-exact; PARITY ≤1.3× NOT quite reached — OG16, #2866); (b) conv/grouped-conv
      at a SATURATED shape → recast as IMPLICIT-GEMM + WEIGHT-REUSE register tiling
      (CTA owns BM time-rows × BN out-ch, stage weight tile to smem ONCE + reuse
      across all BM rows → weight HBM traffic cut ~BM-fold), NOT fusion-fill — byte-eq
      max|Δ|=0, 6.57× vs ModuleList-30 @d=6208 (6.6–13.7× across the sweep; util
      ~92% on both paths so it is WORK-REDUCTION not fill — PROD-KERNEL, #2867);
      (c) the REGIME LAW (under-fill, idle SMs → fusion-fill · saturated, ≥98% util,
      d≥1024 → weight-reuse GEMM recast) as an ASCII decision tree, from the
      OG-FUSE-OPT/XOVER/RIGHTSIZE sweeps (#2862/#2865/#2863). HONEST FRAMING
      throughout: cuBLAS/cuDNN = ROOFLINE, the wins are reach-roofline /
      boundary-removal NOT raw-math superiority, parity NOT claimed (OG16 best
      1.37×), byte-exact gate FIRST. The preflight tool/dojo_rent_preflight.sh
      dojo_recipe_advisory carries a one-line regime hint (saturated →
      weight-reuse-GEMM / under-fill → fusion-fill) — self-test stays GREEN (+2
      cases, bash -n clean). Mirrored to commons g82; CITES the verdicts verbatim
      (F-FUSION-SM90-WGMMA-OG16 · F-FUSION-MOE-CONV-PROD-KERNEL) + attributes the
      PRs. Verdict: .verdicts/hexa-cuda/F-HEXACUDA-DOJO.txt (§11). Docs/tool only,
      NO GPU (cited verbatim from landed fusion verdicts — rented nothing).
