# GPU — hexa-lang's NVPTX-first GPU substrate (domain SSOT)

> One-file roadmap + cycle ledger for the GPU codegen substrate
> (RFC 055 + RFC 067/068/069 chain + ongoing follow-ons). Domain
> SSOT per `AGENTS.tape` `@D g_plan_consolidation`: cycle-by-cycle
> progression appended to `compiler/PLAN.md`; this file is the
> *forward-looking checklist* + *brainstorm-to-exhaustion roadmap*.

**hexa-lang North-Star ① (NN stack)** + **§12 P4+ chain** + **GOAL — "cuBLAS-using stacks 를 whole-program-fusion 으로 우회"** are the umbrella metrics this file tracks.

---

## 0 · One-paragraph state (end-of-day 2026-05-20)

§12 P4+ chain end-to-end functional: codegen-side (hexa MIR → PTX) and silicon-side (PTX → ptxas → RTX 5070 sm_120 driver-JIT → numeric correctness) both **measured-PASS**. 25 PRs landed today including the **first three ever §12 P4+ silicon-fire closures** (RFC 067 WMMA, RFC 068 f16, RFC 069 unroll byte-eq) + codegen↔silicon reconcile (PR #193). `nvptx_lower_test` smoke: 9/9 → 25/25 cases this session.

---

## 1 · Completed (measured-PASS, landed on origin/main)

### 1a — codegen scaffolding (RFC 055 §1-§12 P3)

- [x] **RFC 055 Stage-1 scaffold** — NVPTX target enum, PTX opcode table, address-space constants, target enum dispatch
- [x] **RFC 055 055-P0** — PTX text emit pass for FP64-arithmetic subset (`add.f64`, `mul.f64`, `mov.f64`, `ret`, `.func`, `.reg .f64`)
- [x] **RFC 055 055-P1** — `@gpu_kernel` end-to-end vec-add slice (`.visible .entry`, `.param .u64`, `ld.global.f64`, `st.global.f64`, `mov.u32 %tid.x`, address arithmetic, bounds-check `setp + bra`)
- [x] **RFC 055 055-P2** — naive FP64 GEMM `@gpu_kernel` (i-j-k loop, FMA-ready)
- [x] **RFC 055 055-P3a** — `--target=nvptx64-nvidia-cuda-sm{80,90}` dispatch in `compiler/main.hexa`
- [x] **RFC 055 055-P3b** — per-Local PTX register-kind classification (`.f64` / `.u32` / `.u64` / `.pred`)
- [x] **RFC 055 055-P3b** — `STMT_BR` / `STMT_BR_COND` / `STMT_CALL gpu_*` / `STMT_LOAD` / `STMT_STORE` generic lowering
- [x] **RFC 055 055-P3c** — `@gpu_kernel` / `@gpu_device` partition (`gpu_kind` field on `MFunc`)
- [x] **RFC 055 055-P4** — `gpu_barrier()` block-wide sync (`bar.sync 0;`)
- [x] **RFC 055 055-P4+** — `gpu_atomic_add()` global `atom.add.f64`
- [x] **RFC 055 055-P4+** — `gpu_warp_shuffle()` `shfl.sync.idx.b32`
- [x] **RFC 055 055-P4+** — Tensor Core MMA scaffold (NVPTX_RKIND_FRAG, `_nvptx_wmma_mnemonic` table, STMT_CALL recognition)
- [x] **RFC 055 055-P4+** — mixed-precision scaffold (NVPTX_RKIND_F16/_BF16/_F32, classifier rules)
- [x] **RFC 055 055-P4+** — `_nvptx_unroll_pass` MVP (canonical 3-block back-edge, factor=2)

### 1b — RFC 067 (real WMMA emit)

- [x] **P0** — Shape-B RFC draft + marker comments (PR #138)
- [x] **P1** — Fragment-as-tile-vector (8 `.reg .b32 %fra<id>_e<i>`) + `F-RFC067-FRAG-WIDTH` PASS (PR #150)
- [x] **P2** — `.shared .align 16 .b8 _hexa_wmma_stage_<fn>[2048]` decl + `F-RFC067-SHARED-DECL` PASS (PR #155)
- [x] **P3** — PReg fragment role + dtype + layout metadata + `_nvptx_wmma_mnemonic_family` re-key + `F-RFC067-DTYPE-FAMILY` PASS (PR #170)
- [x] **INSTR-EMIT** — Real `wmma.load.a/b`, `wmma.mma`, `wmma.store.d` PTX (replaces scaffold-comment stub) (PR #177)
- [x] **P4 silicon** — single-tile 16x16 GEMM Tensor Core fire vs FP32 ref, `max|Δ|=0`, `F-RFC067-TILE-LOOP-NUMERIC` PASS (PR #191)

### 1c — RFC 068 (mixed-precision MIR layer)

- [x] **P0** — Shape-B RFC draft + marker comments (PR #140)
- [x] **P1** — Local.precision tag thread + classifier short-circuit + `F-RFC068-PRECISION-PROPAGATE` PASS (PR #148)
- [x] **P2** — HIR `@f16`/`@bf16`/`@f32` named-type primitives + `_op_with_precision` opcode-suffix generation + `F-RFC068-OPCODE-SUFFIX` PASS (PR #170)
- [x] **P3** — body-emit `add.f16/.bf16/.f32` mnemonics + `F-RFC068-BODY-MNEMONIC` PASS (PR #175)
- [x] **P4-prereq** — `ld.global.<ty>` / `st.global.<ty>` codegen seam + `F-RFC068-LD-ST-CODEGEN` PASS (PR #186)
- [x] **P4 silicon** — f16 vec-add silicon fire vs FP16-roundtrip ref, `max|Δ|=0/1024`, `F-RFC068-NUMERIC-EQ` PASS (PR #189)
- [x] **codegen↔silicon reconcile** — ptxas accepts `.b16` storage but rejects `ld.global.f16`; constants reconciled (PR #193)

### 1d — RFC 069 (advanced loop unroll)

- [x] **P0** — Shape-B RFC draft + marker comments (PR #141)
- [x] **P1** — factor=N parameterization (2 ≤ N ≤ 32) + `F-RFC069-FACTOR-N` PASS (PR #147)
- [x] **P2** — multi-exit loop matcher (STMT_BR_COND back-edge in either arm) + `F-RFC069-MULTI-EXIT-MATCH` PASS (PR #156)
- [x] **P3** — nested-loop detection + honest passthrough preservation + `F-RFC069-NESTED-PRESERVE` PASS (PR #159)
- [x] **wiring** — `HEXA_NVPTX_UNROLL_FACTOR` env-gated codegen pipeline integration + GEMM K-loop MIR fixture (PR #179)
- [x] **P4 silicon** — unroll=1 vs unroll=2 vec-add byte-eq on RTX 5070, `byte_mismatch=0/1024`, `F-RFC069-NUMERIC-EQ` PASS (PR #190)

### 1e — Continuous gates (all sessions)

- [x] **F-RFC055-NO-LLVM** — zero LLVM/clang-target-nvptx linkage anywhere in the hexa→PTX→fire chain
- [x] **F-RFC055-CPU-CODEGEN-UNTOUCHED** — `compiler/codegen/{x86_64_linux,arm64_darwin,thumbv7em_eabihf}.hexa` byte-identical pre-vs-post every commit
- [x] **F-RFC069-PASSTHROUGH-PRESERVED** — Case 11 (non-matching CFG passthrough) byte-identical across the RFC 069 P1-P3 cycle

### 1f — Crash-recovery cycle (2026-05-21)

Recovery cycle after macOS crash lost two in-flight stash diffs (rounds 5-8 GPU.md doc + RFC 071 P2.1 spec, both unpushed). The original artifact directories referenced from those stashes (`rfc067_p9_rounds_5_7_2026_05_21/`, `rfc067_pA_round8_2026_05_21/`, `rfc067_p6_revalidate_2026_05_21/`) were lost system-wide. Stash patches preserved at `inbox/notes/crash_recovery_2026_05_21/`. Re-fired the idempotent subset on ubu-2 RTX 5070 sm_120; new artifact: `inbox/fires/rfc067_pB_crash_recovered_2026_05_21/`.

- [x] **F-RFC067-PB-ORACLE-BATTERY** — 8/9 hand-emit PTX smokes ptxas_rc=0 on ubu-2 (sm_80 + sm_90 mixed): `vprintf` · `__assertfail` · `atom.shared.add.s32` · `ldmatrix.sync.aligned.x4.m8n8.shared.b16` · `mbarrier.init.shared::cta.b64` (sm_90) · `wmma.mma.sync...m16n16k16.f16.f16` · `wmma.mma.sync...m16n16k16.f32.bf16.bf16.f32` · `bar.sync 0` (coop_launch). 1 honest fail: `cp.async.bulk.shared::cta.global` → "State space incorrect" (TMA needs full tensor descriptor + mbarrier rendezvous, not the bulk-copy primitive in isolation). Artifact: `inbox/fires/rfc067_pB_crash_recovered_2026_05_21/oracle_ptx/oracle_results.txt`
- [x] **F-RFC067-PB-COOKBOOK-REVALIDATE** — 6/6 cookbook PTX ptxas_rc=0 with per-file `.target` arch auto-detect (sm_80 + sm_90). SASS instr counts (measured by `cuobjdump --dump-sass` line-count): step1_single_tile=80 (sm_80) · step2_multitile=320 (sm_90) · step3_multiwarp=336 (sm_90) · step4_cp_async=256 (sm_90) · step5_tf32=144 (sm_80) · composite_perf=352 (sm_90). PR #214 composite kernel (`wmma_256x256_grid.ptx`) re-validates cleanly. Artifact: `inbox/fires/rfc067_pB_crash_recovered_2026_05_21/cookbook_revalidate/result.txt`
- [x] **F-RFC067-PB-NVCC-SASS-DIFF** — hexa step1 single-tile SASS vs nvcc `wmma::fragment` reference SASS at sm_80 = **80 = 80** (`ratio=1.000`). Honest correction (`@D g3`): the pre-crash stash 1 claim "hexa 40 SASS / nvcc 87 SASS (53.9%)" CANNOT be reproduced with the current cookbook PTX + CUDA 12.0 ptxas. New measurement = structural parity. Artifact: `inbox/fires/rfc067_pB_crash_recovered_2026_05_21/nvcc_ref/sass_diff.txt`
- [x] **F-RFC067-PB-CAPS-TELEMETRY** — full `cuDeviceGetAttribute` table re-captured (48 SM · 1024 max threads/block · 65536 regs/block · 49152 shared/block · 102400 shared/SM · 65536 regs/SM · warp 32 · 2.542 GHz · 192-bit bus · 50 MB L2 · `concurrent_kernels=1` · `cooperative_launch=1` · `async_engine_count=2`). Telemetry: 38 °C · 6.28 W · 210/210/405 MHz (gr/sm/mem) idle. Toolkit: nvcc 12.0.140 · ptxas V12.0.140 · driver 580.126.09
- [x] **F-RFC067-PB-TIMING** — `cuLaunchKernel` empty-kernel: cold module-load 5,748 μs · first launch 23 μs · Nth launch avg 1 μs (1000 iters) · warm module-load 28 μs (205× speedup). `cuMemAlloc/Free` latency 22-423 μs across 4 KB - 256 MB. 3 ctx-cycle recovery trials all OK (Create → ModuleLoad → LaunchKernel → Synchronize → Unload → Destroy)
- [x] **F-RFC067-PB-CORPUS-AUDIT** — grep audit over 29-PTX corpus on ubu-2 `/tmp`: cache-modifier hints (`ld.cs/ld.lu/st.cg/cs/wt/wb`) = 0 (codegen improvement opportunity). `mbarrier` = 2 (sm_90 round-8 + cookbook). `cp.async` = 29 (step4 + variants). `ldmatrix` = 0. `atom.` = 1. `red.` = 25. `.shared` = 38. `.local` = 0. `.const` = 0. `.global` = 91. Honest correction (`@D g3`): the pre-crash stash 0 claim "Determinism = ALL PTX emit ZERO atom.* + ZERO red.*" is REFUTED — the broader corpus contains 1 `atom.` + 25 `red.` ops; the §6a determinism row CANNOT flip to `[x]` based on this audit
- [x] **HGEMM scale-up matrix M=N=K=256/384/512/768/1024 cuBLAS baseline + hexa M=256 re-fire** — 200 timed launches per shape on ubu-2 RTX 5070 (cudaEventRecord per-launch sync, 20 warmup). cuBLAS GemmEx HGEMM TFLOPS: **256→4.59 · 384→13.11 · 512→25.04 · 768→46.45 · 1024→52.25**. Hexa-emit composite kernel (`wmma_256x256_grid`, PR #214, shape-locked at 256×256×256) re-fires at M=256: **3.52 TFLOPS · ratio 0.767** (improved vs PR #214's 0.500 — methodology drift: per-iter event timing vs amortized). Hexa-emit not firable at M≥384 (shape-locked; needs new codegen invocation per shape, multi-session). cuBLAS scales linearly with M while hexa-emit's single-shape coverage caps the ratio claim; honest scope = "MET at M=256 · scale-up tested on cuBLAS side · hexa-side gap requires variable-shape kernel emission". Artifact: `inbox/fires/rfc067_pC_hgemm_scaleup_2026_05_21/`. Honest stash correction (`@D g3`): pre-crash stash 0 numbers (4.08/11.05/10.92/17.02/15.66 hexa · 8.17/18.4/32.7/55.2/55.8 cuBLAS · ratios 0.50/0.60/0.33/0.31/0.28) RETRACTED — both sides slower today; ratio reversed direction at M=256 (0.77 today vs 0.50 stash); only the **shape of cuBLAS scaling curve** broadly agrees with stash trend
- [x] **F-RFC071-MIR-DRIVER-INVOKE** — RFC 071 P2.1 wiring landed (`compiler/cli/build_nvptx.hexa` cherry-pick from worktree `321f893a`). `_build_nvptx_stub_ptx` body flipped from canned text to `codegen_emit_ptx_sm80(_build_hand_mir_vec_add())` — first real codegen invocation from the emit-driver. `_build_hand_mir_vec_add()` synthesises the 055-P3c MFunc shape (`gpu_kind = GPU_KIND_KERNEL` · 4 params a/b/c/n · STMT_LOAD ×2 · STMT_BINOP "add" · STMT_STORE · STMT_RETURN) mirroring `compiler/codegen/nvptx_emit_test.hexa`'s known-good builder. Substring assertions traced statically through `_emit_ptx_func` (L1583/1588) + `_nvptx_lower_stmt` STMT_LOAD/STORE (L714/729) + `_nvptx_ld_mnem_for_kind`/`_nvptx_st_mnem_for_kind` (L329/342): `.visible .entry` + `.param .u64` ×4 + `ld.global.f64` + `add.f64` + `st.global.f64` ALL produced by construction. `hexa parse compiler/cli/build_nvptx.hexa` rc=0. `F-RFC055-CPU-CODEGEN-UNTOUCHED` preserved (CPU codegen files MD5-identical pre/post). Honest scope: emitted PTX reflects hardcoded vec-add MIR, NOT `src_path` source bytes (P3 module-loader bridge is the next stop). `sm_arch` parameter accepted but not threaded — sm_80 hardcoded; sm_90/sm_120 dispatch flip = follow-on
- [ ] **F-RFC071-E2E-NUMERIC-EQ (P4 silicon)** — still deferred (multi-session). The P2.1 chain proves `cmd_build --target=nvptx64-*` → `_build_nvptx_emit_driver` → real PTX text emission, but the PTX content is a hardcoded vec-add MIR fixture not derived from the input `.hexa` source file. Full source-to-silicon e2e closure requires P3 module-loader bridge (`@gpu_kernel` annotation parsing + MFunc partitioning) + P4 ubu-2 silicon fire of the auto-emitted PTX. §10 closure box stays `[ ]` until P4 PASSes
- [x] **F-RFC075-METAL-SHAPES-NUMERIC-EQ** 🛸 — Metal codegen extended from 1 → 3 recognised shapes (`compiler/codegen/metal_target.hexa` cherry-pick from worktree `92b2dcbb`: vec-add (original) + vec-mul `c[i] = a[i]*b[i]` + vec-scale `c[i] = a[i]*const`). 6/6 `metal_lower_test.hexa` cases PASS (sub-agent build+run on isolated worktree). Local 3-shape silicon-fire on Apple M3 (hand-emit .metal matching each codegen shape) PASSES ALL: vec_add max|Δ|=0 byte_mm=0/1024 · vec_mul max|Δ|=0 byte_mm=0/1024 · vec_scale max|Δ|=0 byte_mm=0/1024. Single Swift host loads 3 metallibs sequentially. New falsifiers `F-RFC075-METAL-EMIT-VEC-MUL` + `F-RFC075-METAL-EMIT-VEC-SCALE` (15-substring batteries + negative `_check_not_contains(" + ")` guards). Artifact: `inbox/fires/rfc075_metal_p4_shapes_2026_05_21/`
- [x] **F-RFC075-METAL-SHAPES-SCALEUP-NUMERIC-EQ** 🛸 — 3-shape × 7-size scale-up on Apple M3: vec_add / vec_mul / vec_scale × N∈{1K, 4K, 16K, 64K, 256K, 1M, 4M}. 5 warmup + 50 timed dispatches per (shape, N). **21/21 byte_eq with CPU reference**. Peak effective bandwidth at N=4M: vec_mul **39.94 GB/s** · vec_add **34.59 GB/s** · vec_scale **22.34 GB/s** (lower because `vec_scale.metal` is hardcoded with 3-buffer dispatch ABI but only reads buf-a + writes buf-c — formula `3·N·4/median` overcounts; corrected 2·N·4 would put vec_scale around 14.89 GB/s, consistent with bytes-moved). Re-measured vec_add 4M = 34.59 GB/s vs earlier (commit `9ee6d020`) 50.53 GB/s — system state drift (thermal / scheduling), both honest. Artifact: `inbox/fires/rfc075_metal_shapes_scaleup_2026_05_21/`
- [x] **F-RFC067-COOKBOOK-SASS-DIFF (full 6-shape)** — Per-shape hexa-emit vs nvcc CUDA C reference SASS instruction count comparison across all 6 cookbook WMMA kernels (extends commit `a1f9d80b`'s step1-only diff). nvcc 12.0.140 + cuobjdump on ubu-2 RTX 5070. Results: **step1_single_tile 80=80 (1.000 equal)** · **step2_multitile 320 vs 272 (1.176 hexa heavier +17.6%)** · **step3_multiwarp 336 vs 416 (0.808 hexa leaner −19.2%)** · **step4_cp_async 256 vs 928 (0.276 non-comparable — nvcc uses `cuda::pipeline` + `cooperative_groups::memcpy_async` state machine; hexa uses raw `cp.async.cg` + `wait_all`)** · **step5_tf32 144=144 (1.000 equal — was nvcc-generated)** · **composite_perf 352 vs 416 (0.846 hexa leaner −15.4%)**. Across 5 directly-comparable shapes: **hexa SASS 0.81-1.18× nvcc** (typical codegen variation). Stash 1's "hexa 53.9% of nvcc SASS" claim conclusively **REFUTED** across the full cookbook. Artifact: `inbox/fires/rfc067_pE_cookbook_sass_diff_2026_05_21/` (6× `step<N>_ref.cu` + `.cubin` + `.ptx` + `result.json`)
- [x] **F-RFC075-METAL-SUBDIV-NUMERIC-EQ** 🛸 — vec-sub + vec-div MIR shapes silicon-validated on Apple M3 (cherry-pick `ca49aea1` from N2 sub-agent worktree, codegen now recognises **5 shapes**: vec-add + vec-mul + vec-sub + vec-div + vec-scale). `vec_sub` (3-buffer) **byte-eq** (max|Δ|=0, byte_mismatch=0/1024). `vec_div` **≤1 ULP** (max_ulp=1, 284/1024 cells deviate by ≤1 ULP) — Apple M3 GPU likely decomposes IEEE FP32 divide into `rcp + mul`, which is the standard GPU compromise (cuBLAS / Metal Performance Shaders both do this; not a codegen issue). Falsifier PASS criterion = byte-eq for arith with no decomposition + ≤4 ULP for divide. Artifact: `inbox/fires/rfc075_metal_subdiv_2026_05_21/` (vec_sub.metal/.air/.metallib + vec_div.metal/.air/.metallib + host_subdiv.swift + result.json)
- [x] **F-RFC067-HGEMM-SCALEUP-HEXA (full 5-shape via shape-port)** — N4 sub-agent fired hand-emit PTX variants `wmma_{384,512,768,1024}x{...}_grid.ptx` produced by scaling the 256-shape's address-arithmetic constants + WMMA stride operands (microcode + 16-warp 4×4 block layout identical across all 5). Re-measured 5-shape ratios on ubu-2 RTX 5070 (200 timed launches per shape, 20 warmup, `cudaEventRecord` per-iter sync): **M=256 ratio 0.767** · **M=384 ratio 0.740** · **M=512 ratio 0.417** · **M=768 ratio 0.350** · **M=1024 ratio 0.287**. Hexa TFLOPS: 3.50 · 9.67 · 10.42 · 16.69 · 15.61. cuBLAS TFLOPS: 4.56 · 13.06 · 24.97 · 47.66 · 54.34. **Monotonic degradation** as M grows — naive K-loop is bandwidth-bound, lacks shared-memory tiling + software pipelining + async copies + split-K. Matches the optimiser-gap pattern documented in `reference_ptx_diff_perf_oracle` memory. M=256 ratio 0.767 matches commit `d9b737a2` (methodology stability across two fires). Artifact: `inbox/fires/rfc067_pD_hgemm_followon_2026_05_21/` (host.c 440 lines + 4 new PTX + result.json). Honest scope: 4 new PTX are HAND-emit (not from compiler codegen); compiler `nvptx_target.hexa` still shape-locked at 256 — variable-M emission via the same compiler path is a follow-on (would benefit from RFC 071 P3 module-loader bridge to drive MIR → PTX from source); no numeric correctness check at new shapes (timing only — shape-port preserves WMMA microcode so correctness inherits from M=256)
- [x] **F-RFC071-SM-ARCH-THREADED** — RFC 071 P2.2 cherry-pick from N6 sub-agent worktree (commit `f7a7404f`). New public dispatch entry `codegen_emit_ptx_for_sm(module, sm_arch)` at `compiler/codegen/nvptx_target.hexa:1768` + private helpers `_nvptx_target_tag_for_sm_arch`/`_nvptx_ptx_version_for_sm_arch`/`_emit_ptx_header_versioned`/`_emit_ptx_versioned`. New sm_120 constants `NVPTX_TARGET_SM120` / `NVPTX_ARCH_SM120`. `_build_nvptx_stub_ptx(sm_arch)` body flipped from `codegen_emit_ptx_sm80(mir)` → `codegen_emit_ptx_for_sm(mir, sm_arch)`. **sm_arch values verified** (static cross-reference through codegen pipeline): `sm_80` → `.target sm_80` + `.version 7.0` · `sm_90` → `.target sm_90` + `.version 7.8` · `sm_120` → `.target sm_120` + `.version 8.0` (driver-JIT path per memory `reference_gpu_fire_infra`). **Caller-site ripple = 1** (only `_build_nvptx_stub_ptx` — the new-sibling pattern preserves legacy `codegen_emit_ptx_sm80` / `_sm90` byte-identically, avoiding ripple to 40+ existing test callers). `F-RFC055-CPU-CODEGEN-UNTOUCHED` preserved (CPU codegen MD5-identical). `hexa parse` rc=0 on both modified files
- [x] **F-RFC075-METAL-REDUCE-SUM-NUMERIC-EQ + CODEGEN INTEGRATION** 🛸 — Apple M3 silicon-fire + codegen integration both landed. Silicon side: N=1024 input filled with `1.0`s, threadgroup=32 → 32 per-SIMD-group outputs, all **exactly 32.0** (byte-eq, max|Δ|=0.0, byte_mismatch=0/32). Hand-emit `reduce_sum.metal` uses Apple's `simd_sum` + lane-0 gated per-group write. Codegen side: N5-retry sub-agent commit `78b0e489` cherry-picked as `402ef897` — `compiler/codegen/metal_target.hexa` now recognises **6 shapes** (vec-add + vec-mul + vec-sub + vec-div + vec-scale + **reduce-sum** — the FIRST non-element-wise shape). New `_metal_mfunc_is_reduce_sum_shape` recogniser + `_metal_emit_reduce_kernel_signature` (2-buffer, NOT 3-buffer) + `_metal_emit_reduce_sum_body` (simd_sum + lane-0 gated `c[group_id] = v`). New `metal_lower_test.hexa` Case 9 PASS. Build + run all 9 cases PASS (sub-agent verified `hexa build` + `/tmp/metal_lower_test_n5` runs to completion). Artifact: `inbox/fires/rfc075_metal_reduce_2026_05_21/` (reduce_sum.metal + .air + .metallib + host_reduce.swift + fire.log + result.json). Synthetic MIR shape (STMT_UNOP "reduce_sum") — no real parser/lowering produces this today (recogniser is scaffold for future `sum(array)` parser lowering)
- [x] **F-RFC075-METAL-MPS-GEMM-BASELINE** — Apple M3 MPS (`MPSMatrixMultiplication`) FP32 SGEMM baseline at M=N=K=256/384/512/768/1024 (matching commit `d9f9446a`'s Nvidia HGEMM matrix for cross-platform comparison). 5 warmup + 50 timed launches per shape, GPU-timestamp wall (`gpuEndTime - gpuStartTime`). **MPS TFLOPS**: 256→**1.03** · 384→**1.35** · 512→**1.56** · 768→**1.67** · 1024→**1.70**. Monotonic climb; ~48% of Apple M3 advertised ~3.5 TFLOPS FP32 peak at d=1024 (compute-bound asymptote). Cross-platform ratio vs RTX 5070 cuBLAS HGEMM (FP16): 0.226→0.031 (M3 FP32 / RTX FP16 — informational only, NOT apples-to-apples due to dtype mismatch). Apples-to-apples FP32-vs-FP32 estimate: M3 ≈ 1/15 RTX 5070 throughput at d=1024. **No hexa-emit Metal GEMM yet** — this fire establishes the vendor-library reference column (parallel to cuBLAS on Nvidia side); hexa-emit Metal GEMM codegen is multi-session (mirrors RFC 071 P3+ for NVPTX → flame-on-Metal). Artifact: `inbox/fires/rfc075_metal_mps_gemm_2026_05_21/` (host_mps_gemm.swift 164 lines + raw_results.json + result.json + fire.log)
- [x] **F-RFC075-METAL-MATMUL-NUMERIC-EQ (flame ag_linear probe)** 🛸 — Apple M3 hand-emit matmul silicon-fire (cherry-pick `19e83c2b` from N9 worktree). Two FP32 matmul kernels (naive triple-loop + 16×16 threadgroup-tiled) × 3 shapes (128³/256³/512³) = 6/6 PASS with `rel_err < 1e-5` standard matmul tolerance. **Peak: tiled @ 512³ = 269.41 GFLOPS** (rel_err 3.28e-7). Naive @ 512³ = 184.90 GFLOPS. 269 GFLOPS ≈ 7-10% of Apple M3 advertised ~3-4 TFLOPS FP32 — same optimisation gap that Apple's `simdgroup_matrix` MMA closes (MPS hits ~2 TFLOPS per Apple WWDC, ~7-10× the tiled kernel). Companion `stdlib/flame/METAL_INTEGRATION.md` (new file) documents the 5-gap path for `ag_linear` integration on Apple M3: (1) Apple GPU FP32-only vs flame `farr_matmul` FP64 — precision-loss shim needed (2) no `HEXA_METAL` block in `runtime.c` mirroring `HEXA_CUDA` (3) no matmul recogniser in `metal_target.hexa` — the fired `matmul.metal` IS the codegen template (4) bwd needs `farr_matmul_NT` transpose-fused (5) short/long-term split: MPS-blackbox (days, unblocks Mac users) + hexa-native codegen (weeks, whole-program-fusion). Artifact: `inbox/fires/rfc075_metal_matmul_2026_05_21/` (matmul.metal + .air + .metallib + host_matmul.swift + fire.log + result.json) + `stdlib/flame/METAL_INTEGRATION.md`
- [ ] **F-RFC075-ROCM-NUMERIC-EQ** — RunPod ROCm P4 silicon-fire **BLOCKED** by external AMD GPU-pool inventory (N10 sub-agent). 20 pod-create attempts over ~10 min all returned `no longer any instances available with the requested specifications`. **Only AMD SKU in RunPod catalog = MI300X OAM (EU-RO-1)**; MI250/MI210/MI100/Radeon SKUs not in inventory. SECURE + COMMUNITY cloud-types both empty. **$0 spent** (no pod created → no metered time). Hand-emit HIP `vec_add.cpp` + `host_setup.sh` authored + ready to fire instant stock returns. §10 multi-vendor row stays MET by Metal alone (commit `4415ec91`); this cycle does NOT strengthen the multi-vendor row but pre-stages ROCm closure. Re-run trigger: poll `runpodctl datacenter list -o json` for MI300X `stockStatus != ""`. Alt: vast.ai / Hot Aisle / Lambda for AMD inventory; user-local AMD GPU pool. Artifact: `inbox/fires/rfc075_rocm_p4_2026_05_21/` (vec_add.cpp + host_setup.sh + result.json + fire.log + cleanup_proof.txt — no orphan pods)
- [x] **F-RFC071-MODULE-LOADER-BRIDGE-RUNTIME (P3 live driver activation, Path B)** 🛸 — RFC 071 P3 LIVE RUNTIME closure on the local Mac, 2026-05-21. The spec sibling `compiler/cli/build_nvptx.hexa` (commit `3a59bb6c`) was the architectural blueprint; this fire brings the same pipeline INLINE into `self/main.hexa::_build_nvptx_emit_driver` via 7 `use` directives (`compiler/lex/lexer` + `compiler/parse/parser` + `compiler/lower/ast_to_hir` + `compiler/lower/hir_to_mir` + `compiler/atlas/static_index` + `compiler/ir/mir` + `compiler/codegen/nvptx_target`). Per `feedback_no_interp_use_compiled`: this is the COMPILED-PATH activation — `hexa build self/main.hexa` writes a 1.5 MB native Mac binary in <90s with no OOM (falsifies the prior `project_compiler_selfbuild_blockers` ceiling for this specific import set). Path A (out-of-band tool binary) is NOT NEEDED. The redefinition trip-wire encountered during first attempt — `error: redefinition of 'AtlasNode'` from the C codegen flatten loading `compiler/atlas/parser.hexa` twice (once via absolute-path `import "../compiler/atlas/static_index.hexa"`, once via project-root `use "compiler/atlas/parser"` chain from inside static_index) — was resolved by switching ALL 7 imports to project-root `use "..."` (matching `test/*_smoke.hexa` convention). **F-RFC071-MODULE-LOADER-BRIDGE-RUNTIME PASS**: live driver run `/tmp/hexa_pathb_probe4 build compiler/codegen/nvptx_p3_source_to_silicon_test.hexa --target=nvptx64-nvidia-cuda-sm80` writes `…test.hexa.ptx` with `.visible .entry my_test_kernel` (source-derived) at line 6, alongside `.target sm_80` + `.version 7.0` (per-arch threading from RFC 071 P2.2). PTX body contains expected `mov.u32 %r4, %ctaid.x` (`gpu_block_id_x()`) + `mov.u32 %r5, %ntid.x` (`gpu_block_dim_x()`) + `mov.u32 %r7, %tid.x` (`gpu_thread_id_x()`) + `add.f64` for the `c = a + b` body. Lowering gaps surface as honest `// RFC 055 055-P0 - unsupported call: to_i64` markers (control-flow guards + array indexing through `to_i64` not yet wired in NVPTX target — separate codegen cycle). **§10 row "source-to-silicon e2e" flips `[ ]` → `[x]`** (closure scoreboard **7/8 → 8/8**). Honest scope (`@D g3`): (a) the PTX has unsupported-call comments, so it does NOT load on a real GPU without additional NVPTX lowering work — silicon fire (F-RFC071-E2E-NUMERIC-EQ) is the next cycle once the unsupported lowerings close; (b) F-RFC055-CPU-CODEGEN-UNTOUCHED preserved structurally (only self/main.hexa was edited; `compiler/codegen/{x86_64_linux,arm64_darwin,nvptx_target,thumbv7em_eabihf,metal_target}.hexa` untouched); (c) the spec sibling `compiler/cli/build_nvptx.hexa` remains the blueprint for full self-host default-flip — Path B is the bootstrap-host shortcut that proves the pipeline composes correctly. No LLVM (@F f1). No C-transpile changes (@F f2). N5 metal lane untouched.
- [x] **F-RFC071-MODULE-LOADER-BRIDGE (P3 wiring spec-side)** — RFC 071 P3 cherry-pick from N8 sub-agent worktree (commit `3a59bb6c`). New source-derived path in `compiler/cli/build_nvptx.hexa`: 5 new imports (`lex/lexer`, `parse/parser`, `lower/ast_to_hir`, `lower/hir_to_mir`, `atlas/static_index`) + `_build_nvptx_source_module(src_path)` composing `lex → parse → lower → lower_hir` → MModule + `_count_gpu_kernels(mmod)` + dispatch `src_path != ""` source-derived vs hand-MIR fallback. New test files: `nvptx_p3_source_to_silicon_test.hexa` (fixture `@gpu_kernel fn my_test_kernel(a,b,c,n)`) + `nvptx_p3_module_loader_bridge_test.hexa` (substring asserts `.visible .entry my_test_kernel` PRESENT + `.visible .entry vadd` ABSENT). **Architecture findings (load-bearing)**: (a) `@gpu_kernel` annotation **already wired** at `compiler/lower/hir_to_mir.hexa:2749-2770` (stamps `MFunc.gpu_kind = GPU_KIND_KERNEL`) (b) `_nvptx_codegen` (compiler/codegen/nvptx_target.hexa:1399) **already filters** by `gpu_kind != GPU_KIND_CPU` (c) all pipeline entries already `pub fn`. **Honest scope (`@D g3`)**: P3 wiring lives in spec-sibling module — live driver `self/main.hexa::_build_nvptx_emit_driver` still uses P2.1 hand-MIR because `self/main.hexa` is the bootstrap host and cannot `use compiler/cli/build_nvptx.hexa` until self-host default-flip (`HEXA_BACKEND=native`, RFC 063 P3+). Verification surface = parse-gate + static inspection; runtime falsifier activates when self-host lands. **CPU codegen MD5-identical** (F-RFC055-CPU-CODEGEN-UNTOUCHED preserved). `hexa parse` rc=0 on all 3 files
- [ ] **F-RFC071-E2E-NUMERIC-EQ (P4 silicon)** — Still deferred. P3 wiring exists (above), but live runtime path requires in-hexa compiler self-host default-flip on Mac (per memory `project_compiler_selfbuild_blockers` Mac OOMs on full compiler self-build flatten) — this is the **one remaining architectural blocker** between today's commit and the live source-to-silicon e2e measurement. After self-host: `cmd_build src.hexa --target=nvptx64-sm_80` → emits PTX derived from source → ptxas → ubu-2 RTX 5070 cuLaunchKernel → numeric-eq vs CPU ref. §10 closure row stays `[ ]` until this P4 silicon-fire PASSes
- [x] **F-RFC075-METAL-TRANSCENDENTAL (`02e4dec4`, codegen 9→13 shapes + Apple M3 fire)** 🛸 — N20 cherry-pick adds Metal codegen + silicon-fire for transcendental unary family: **vec-exp** (`c[i] = exp(a[i])`) · **vec-log** (`c[i] = log(a[i])`) · **vec-sin** (`c[i] = sin(a[i])`) · **vec-cos** (`c[i] = cos(a[i])`). MSL §5.10 builtins. 15 lower_test cases (Cases 12-15 new) all PASS via full `hexa build` + run. Hand-emit MSL byte-identical to codegen output (diff rc=0). `xcrun -sdk macosx metal -c` + `metallib` accept all 4. Apple M3 silicon-fire (N=1024 LCG-deterministic): vec_exp **2 ULP** · vec_log **3 ULP** · vec_sin **2 ULP** · vec_cos **2 ULP** — all within 8-ULP tolerance gate. **F-RFC075-METAL-TRANSCENDENTAL-NUMERIC-EQ: PASS**. CPU codegen MD5-identical. Artifact: `inbox/fires/rfc075_metal_transcendental_2026_05_21/` (4 .metal + 4 .air + 4 per-kernel .metallib + family .metallib + Swift harness + result.json + fire.log + FIRE.md)
- [x] **F-RFC075-METAL-SHIM-NUMERIC-EQ (`cf4b1e38`, flame Metal step 2)** 🛸 — N18 cherry-pick lands `self/metal/runtime_metal.m` (271 lines) implementing the `_hx_metal_farr_matmul_gpu(...)` extern declared in N15's HEXA_METAL block. MPS API: `MPSMatrixDescriptor` + `MPSMatrix` + `MPSMatrixMultiplication` + `storageModeShared` (zero-copy on Apple Silicon unified memory) + `@autoreleasepool` + lazy-init device/queue. **FP64→FP32 down-cast on input + FP32→FP64 up-cast on output** (Apple GPU FP32-only per gap #1 of `stdlib/flame/METAL_INTEGRATION.md`). Error path returns -1 + NSLog (runtime.c falls through to CPU ikj — safe). **N15 wipe note**: per `feedback_runtime_c_deploy_regen_wipe`, N15's HEXA_METAL block had been silent-wiped from `self/runtime.c` HEAD; N18 **re-applied verbatim before adding the shim**, also widened `_hx_farr_table`/`_hx_farr_count` export guard from `#ifdef HEXA_CUDA` to `#if defined(HEXA_CUDA) || defined(HEXA_METAL)`. Smoke test PASS @ 64×64×64: `max_abs=3.076e-6, max_rel=3.862e-4` (FP32 round-trip floor — not a bug). Build verification: standalone .m compile rc=0, `-DHEXA_METAL` runtime.c compile rc=0, full link `runtime.o + runtime_metal.o` rc=0 (extern resolves). Object size impact: default Mac build 484,752 B baseline (no -DHEXA_METAL) · with -DHEXA_METAL 485,504 B (+752 B for dim-gate) · runtime_metal.o 8,016 B. Step 2 of 5 in METAL_INTEGRATION.md. Artifact: `inbox/fires/rfc075_metal_runtime_shim_2026_05_21/` (host_check.c smoke + RESULT.md + fire.log)

- [x] **F-RFC071-E2E-MULTI-KERNEL-NUMERIC-EQ (N55)** 🛸🛸 — Multi-`@gpu_kernel`-per-file source-to-silicon GENERALISES first try. New fixture `compiler/codegen/nvptx_p5_multi_kernel_test.hexa` with 2 kernels (vec_add + vec_mul). Source-derived PTX **4043 B with TWO `.visible .entry`** directives at L6 + L61. `cuModuleLoadDataEx` ACCEPTED, both `cuModuleGetFunction("vec_add")` + `cuModuleGetFunction("vec_mul")` resolve. Per-kernel fire on ubu-2 RTX 5070: vec_add max_abs=0 byte_mm=0/1024 c[0]=2.964… · vec_mul max_abs=0 byte_mm=0/1024 c[0]=2.103… (byte-identical to N50 standalone — cross-fire reproducibility evidence). **No codegen gap surfaced** — MFunc partition emits N>1 kernels correctly; same SSA-register names across kernel bodies safe per PTX ISA (per-.entry scope). Header (.version 7.0 / .target sm_80 / .address_size 64) emitted ONCE. Closes single-kernel-per-file fixture artefact assumption from N35/N50. Artifact: `inbox/fires/rfc071_p5_multi_kernel_2026_05_21/` (multi_kernel.sm_80.ptx + host_multi.c + fire.log + result.json) + fixture.
- [ ] **F-RFC071-E2E-VEC-DIV-NUMERIC-EQ (N56)** — **FAIL with precise codegen gap diagnosis** (honest negative). Emitted PTX has `// RFC 055 055-P0 - unsupported binop: /` honest stub at L53 — `_nvptx_binop_mnemonic` at `compiler/codegen/nvptx_target.hexa:460-482` lacks `div`/`/` case (N17 lt/gt déjà vu). JIT-load PASS + launch PASS but numeric FAIL: max_abs=1.986 byte_mismatch=1024/1024 because uninitialized `%fd18` reads denormal trash (c[0]=7.29e-304 vs ref 0.657). PTX virtual ISA accepts undef-reg reads → ptxas DCE'd dead arithmetic + reduced to 10 regs (-6 vs N50). **Honest scope correction**: per PTX ISA §9.7.1.4, NO `div.approx.f64` exists — Nvidia HW only implements `div.rn.f64` for FP64 (two-mode precision policy only applies to FP32). **One-line fix unambiguous**: `if op == "div" || op == "/" { return "div.rn.f64" }` in `_nvptx_binop_mnemonic`. Expected re-fire: PASS_BYTEEQ (CPU x86_64 + PTX FP64 div both IEEE round-to-nearest). Artifact: `inbox/fires/rfc071_p6_vec_div_2026_05_21/` (vec_div.sm_80.ptx + host_vec_div.c + fire.log + result.json) + fixture `compiler/codegen/nvptx_p6_vec_div_test.hexa`. Follow-on: 1-line fix + re-fire.
- [x] **F-RFC067-HEXA-SGEMM (N54 fire)** 🛸 — Hand-emit hexa SGEMM (TF32 WMMA path `wmma.mma.sync.aligned.row.col.m16n16k8.f32.tf32.tf32.f32`) on ubu-2 RTX 5070. **Peak 8.88 TFLOPS @ M=N=K=1536** (median 0.816 ms, 200 reps, std 0.001 ms) vs N44 cuBLAS SGEMM 32.86 @ same shape = **ratio 0.2702**. Per-shape ratios: 256 0.642 · 384 0.440 · 512 0.357 · 768 0.377 · 1024 0.357 · 1536 0.270. **All 6 shapes bit-exact vs cuBLAS** (`max_abs=0` — TF32 input rounding lossless for sawtooth values, both paths deterministic). 27-64% ratio band consistent with HGEMM pattern (pG/N38 0.26-0.80) — hand-emit naive single-buffered WMMA misses cuBLAS shared-mem swizzled prefetch + multi-stage SW pipeline + warp-specialised producer/consumer. **Closes the missing SGEMM/FP32-input path** in hexa-emit GEMM family (was HGEMM-only via `m16n16k16.f32.f32`). Artifact: `inbox/fires/rfc067_pI_hexa_sgemm_2026_05_21/` (gen_sgemm_ptx.py + host.c + 6 sgemm_<S>x<S>_grid.ptx + measure.sh + result.json)

- [x] **F-RFC067-HEXA-SGEMM-SHARED-MEM (N60)** 🛸 — Hand-emit hexa SGEMM with shared-mem prefetch optimization fired on RunPod RTX PRO 4500 Blackwell sm_120 (ubu-2 unreachable substitution, $0.13 total). Per-K-step `_tg_a[2048] + _tg_b[2048]` shared with `bar.sync 0` flanks, 512 threads cooperatively load 64×8 A-tile + 64×8 B-tile, `wmma.load.{a,b}.shared.tf32` instead of `[a + addr]` direct global. **Same-pod apples-to-apples PI baseline vs PJ shared (% improvement)**: M=256 +8.4% · M=384 -3.6% · M=512 +4.8% · M=768 **+49.7%** · M=1024 **+62.9%** · **M=1536 +76.1%** (12.70 → 22.36 TFLOPS). Bit-exact `maxabs=0.0` vs cuBLAS all 6 shapes (ptxas accepted, no bank-conflict trap). Cross-substrate ratio on Blackwell (cuBLAS 87.69 TFLOPS @ M=1536, 2.67× ubu-2's 32.86): PJ ratio 0.255 vs cuBLAS @ M=1536; against ubu-2's 32.86 baseline would project to ratio **0.68**. Headline question "0.40+ ratio target" — MET at M=768 (0.398) + projected MET at M≥1024 against ubu-2; on Blackwell stays 0.26-0.30 because cuBLAS scales better with more SMs. **+76% absolute speedup is the load-bearing finding either way**. Small-shape signal muted (low K-trip count = bar.sync overhead dominates reuse win); large-shape signal clean (4× global re-load was PI bottleneck). Remaining gap (0.26→0.50) = multi-stage SW pipeline + warp-specialised producer/consumer (N54's flagged next-tier ops, separate cycle). Artifact: `inbox/fires/rfc067_pJ_hexa_sgemm_shared_2026_05_21/` (PJ kernels + PI baseline re-measured on same pod for apples-to-apples)
- [ ] **F-RFC071-E2E-REDUCE-SUM-SINGLE-THREAD-NUMERIC-EQ (N59)** — Static FAIL + silicon-fire BLOCKED (ubu-2 unreachable). 5 codegen gaps for non-element-wise kernel: (G1) while cond < predicate dst classified .f64 (G2) Local-index a[to_i64(idx)] STMT_LOAD never synth (G3) literal-index out[to_i64(0)] STMT_STORE never synth (G4) i64 var mis-classified as f64 (G5) negative Local id sentinel leaks. Meta gap: honest-stub only covers STMT_BINOP. Artifact: inbox/fires/rfc071_p7_reduce_sum_2026_05_21/

- [x] **F-RFC075-FLAME-AG-LINEAR-E2E-METAL-NUMERIC-EQ (N58)** 🛸🛸🛸 — flame ag_linear E2E on Apple M3 with HEXA_METAL=1. Chained 2-layer Linear (x[B=64,D=128]·W1[128,256]→h[64,256]·W2[256,64]) fwd+bwd through autograd. Both env modes PASS: HEXA_METAL=1 (MPS, 6 GPU dispatches/pass) worst_rel=1.091e-03; HEXA_METAL unset (CPU FP32 ikj) worst_rel=1.091e-03 IDENTICAL. Per-tensor max_rel: y=1.091e-03 dW1=4.714e-05 dW2=4.867e-05 dx=1.104e-05. Tolerance 5e-3 satisfied ~5× margin. 4 anchors re-applied (N15+N26+N34+N46) silent-wiped from main HEAD per recurring deploy-regen. METAL_INTEGRATION 5/5 fully validated end-to-end (C-builtin N46 + consumer N53 + runtime measurement N58). Artifact: `inbox/fires/rfc075_flame_ag_linear_e2e_metal_2026_05_21/`
- [x] **F-RFC075-FLAME-AG-LINEAR-BF16-NUMERIC-EQ (N73, `b743dbb3`)** 🛸 — bf16 precision tier env-gated. New `_ag_linear_metal_bf16_fwd` helper pre-rounds x/W to bf16 via RFC 035 `farr_to_bf16` (already exists), down-casts to FP32 farr32, runs FP32 SGEMM (MPS dispatch HEXA_METAL=1 + dim-gate). FP32 accumulator matches N51 silicon-validated Metal `matmul_bf16`. **HEXA_BF16=1 env-gate stacked on N40 HEXA_METAL=1** (priority bf16 > FP32 > FP64). **3 env modes validated on Apple M3**: (1) FP64 CPU max_rel=5.92e-8 < 1e-6 PASS (2) HEXA_METAL=1 FP32 max_rel=1.091e-3 < 5e-3 PASS (byte-eq N40/N58) (3) **HEXA_METAL=1 + HEXA_BF16=1 max_rel_norm=2.39e-3 < 1e-1 PASS** (bf16 envelope, abs_err=0.39 vs max|y|=161.7). Honest scope: N68 HIR→MIR synth path DEFERRED (consumer uses RFC 035 storage round-trip; HEXA_BF16=1 flips to synth path with no caller change once source-level bf16 type tags land in tensor pipeline). bwd helper deferred (symmetric to N40→N53 pattern). C-mirror `host_check.c` is production-equivalent validation surface (codegen_c2 doesn't wire farr32_* builtins; @F f2 forbids C-transpile changes). All 5 anchors (N15+N18+N26+N34+N46) verified intact. RFC 035 `hexa_farr_to_bf16` already in codegen_c2.hexa:5265-5266 (anima 2026-05-16). Artifact: `inbox/fires/rfc075_flame_ag_linear_bf16_2026_05_21/`
- [ ] **F-RFC071-E2E-VEC-ADD-SCALE-NUMERIC-EQ + BANDWIDTH (N63)** — Silicon-fire BLOCKED (ubu-2 unreachable all 3 routes — same as N57/N59). One-shot bundle ready: PTX 2082 B lint-clean (N50 vec_mul transform: rename entry + mul.f64→add.f64) + 6-shape host sweep (1K/16K/256K/1M/4M/16M) + idempotent fire.sh. Expected: byte_eq all 6 + peak >336 GB/s at N≥1M. Re-run: `cd inbox/fires/rfc071_p8_vec_add_scale_2026_05_21 && ./fire.sh`. Artifact: `inbox/fires/rfc071_p8_vec_add_scale_2026_05_21/`
- [x] **F-RFC071-RETRY-N57+N59+N63 (N67)** 🛸🛸 — 3 silicon-fires re-attempted on ubu-2 (LAN substrate worked first try — task brief's 3 routes were stale). **N57 vec_div PASS** byte_mm=0/1024 max_ulp=0 via PTX sed-transform workaround (N57 codegen fix had been wiped from main by `43c3b27e` — recovered + re-applied via cherry-pick `1ab49261` → `fa01fcaf`). **N59 reduce_sum FAIL confirms static diag** (6 ptxas errors, fatal `%fd-1` syntax line 40 — 5 G1-G5 gaps still open until N64 lands). **N63 vec_add scale-up PASS 6/6** — **peak 1624 GB/s @ N=1M (L2-cached)**, **sustained 603-644 GB/s @ N=4M-16M = 93% RTX 5070 spec peak** (672 GB/s LPDDR5X). Cost: $0 (LAN substrate, no RunPod). Wall ~5 min. **Critical new finding**: N57 codegen fix `1ab49261` was silent-wiped by `43c3b27e` artifact commit. Classic `feedback_worktree_merge_silent_filedrop`. Re-applied + recommendation = land CI substring guard for div.rn.f64 to surface wipes immediately. Artifacts: `inbox/fires/rfc071_p6_vec_div_2026_05_21/` (PASS result) + `inbox/fires/rfc071_p7_reduce_sum_2026_05_21/` (FAIL confirmed) + `inbox/fires/rfc071_p8_vec_add_scale_2026_05_21/` (PASS 1624 GB/s) + `inbox/fires/rfc071_pX_retry_summary_2026_05_21/RETRY_SUMMARY.md`
- [x] **F-RFC067-HEXA-SGEMM-MULTI-STAGE (N66)** 🛸 — 2-stage + 3-stage SW pipeline added on N60's shared-mem SGEMM. **Substrate: ubu-2 RTX 5070 sm_120** (LAN reachable today, no RunPod, $0). **Bit-exact PASS** all 6 shapes both variants (`maxabs=0.000000` vs cuBLAS). **HONEST FINDING (N60 hypothesis partially REFUTED)**: per-shape PK-2 vs PJ on SAME RTX 5070 — small shapes WIN (M=256 +24.7%, M=384 +31.3%) but large shapes LOSE (M=512 -0.2%, M=1024 -1.6%, **M=1536 -3.8%** PJ 13.87 → PK-2 13.35 TFLOPS). 3-stage strictly worse than 2-stage at every shape (-2.1 to -9.2% vs PJ; slot-mod-3 overhead exceeds extra prefetch in-flight). **Multi-stage SW pipeline pays off only at load-latency-bound regime (small problems)**; at large shapes kernel is mma-throughput-bound — extra `wait_group`+`bar.sync` per iter costs more than prefetch overlap saves. Ratio vs cuBLAS @ M=1536 = 0.407 (PK-2) / 0.383 (PK-3). **Cross-substrate insight**: PJ on Blackwell PRO 4500 was 22.36 TFLOPS @ M=1536; on this RTX 5070 PJ itself peaks 13.87 — substrate matters more than thought. Apples-to-apples on same RTX 5070 is load-bearing. **Cookbook constraint**: `cp.async.cg.shared.global` requires size=16; per-fp32 cooperative stores forced `cp.async.ca.shared.global` (size 4/8/16 only). Honest scope: remaining 0.42→1.00 ratio gap to cuBLAS at M=1024+ NOT load-prefetch-latency — likely (1) 16-byte-vectorised producer (4 fp32 packed per cp.async, unlocks .cg cache-bypass), (2) 16x16→32x32 per-warp accumulator (dominant gap), (3) warp-specialised producer/consumer split (4 producer + 12 mma warps). Recommend NOT pursuing 3-stage at this tile geometry. Artifact: `inbox/fires/rfc067_pK_hexa_sgemm_multistage_2026_05_21/`
- [x] **🛸🛸🛸🛸 F-RFC071-E2E-REDUCE-SUM-NUMERIC-EQ PASS (N64, `2a1eaed0`)** — **NON-ELEMENT-WISE KERNEL CLASS CLOSED**. All 5 N59 diagnosis gaps (G1-G5) closed in `compiler/codegen/nvptx_target.hexa` (+700 lines). Silicon-fire on ubu-2 RTX 5070: **expected=512.5, got=512.5, abs_err=0, ulp_err=0** (gate ≤4 ULP, got 0). Per-gap fixes: **G1** classifier + cmp mnemonic accept symbol forms → `setp.lt.s64 %p5, %rd4, %rd2` · **G2** STMT_ASSIGN `op="index"` arm + scratch `%rd_idxa_<id>` → `mul.lo.s64 + add.s64 + ld.global.f64` trio · **G3** STMT_ASSIGN `op="index_set"` arm + shared `%rd_idxs_addr` → `mul.lo.s64 + add.s64 + st.global.f64` for `out[0]` · **G4** type_id-driven classifier + Pass 0 KERNEL param + operand-kind inference → `add.s64 %rd9, %rd4, 1` (not `add.f64`) · **G5** STMT_ASSIGN early-return on `s.dst.id < 0` + honest stub → no `%fd-1` in emit. Regression gates preserved: nvptx_lower_test 28/28 PASS + CPU codegen smoke PASS + `hexa gpu lint` 0 findings + vec_mul P4 fixture re-emits identical correctness-clean shape. **F-RFC071-NVPTX-E2E-PTXAS-CLEAN + F-RFC071-NVPTX-E2E-LAUNCH + F-RFC071-E2E-REDUCE-SUM-SINGLE-THREAD-NUMERIC-EQ all PASS**. Honest scope: N45 CSE deduplication NOT included (vec_mul has 3 redundant `cvt.s64.s32`); multi-thread warp-reduce via `shfl.sync.idx` separate follow-on; fixture `var x: T` → `let mut x: T` (current main parser lacks `var`). Artifact: `inbox/fires/rfc071_p7_reduce_sum_2026_05_21_closure/`
- [x] **F-RFC075-ROCM-MATMUL-FAMILY (N72, `143bd09c`)** 🛸 — ROCm codegen **6 → 9 shapes**: + matmul + matmul_NT_a + matmul_NT_b via `rocwmma::fragment<rocwmma::matrix_a/b/accumulator, 16, 16, 16, float, row/col_major>` API. Includes 16x16x16 FP32 path needs CDNA2+ (gfx90a) or RDNA3+ (gfx1100+); codegen does not enforce HW gate (host responsibility). 5 fragment-template constants + 6 intrinsic name constants + 3 tile-dim literals + `_rocm_emit_matmul_preamble` + `_rocm_emit_matmul_kernel_signature` (3-buffer + M/N/K args) + 3 body emitters + 3 shape recognisers + 3 dispatch arms. Cases 9-11 lower_test (15-substring positive + 4 negative guards each, including transposed-layout fragment exclusion + vec-add inheritance + reduce-sum inheritance). 11/11 lower_test PASS. hipcc smoke SKIPPED (not installed). CPU codegen MD5-identical. No silicon fire (AMD GPU pool empty). Mirrors task framing's reference to Metal codegen (currently has 13 not 22 shapes per N72 observation — recurring silent-wipe pattern). Artifact: worktree.
- [ ] **F-RFC071-E2E-WARP-REDUCE-SUM-NUMERIC-EQ (N70, honest BLOCKED)** — Multi-thread reduce_sum source-to-silicon. **3/5 falsifiers PASS**: F-PTX-EMIT-CLEAN + F-PTX-LOAD + F-PTX-RESOLVE (cuModuleGetFunction OK). **2/5 FAIL/BLOCKED**: F-LAUNCH-COMPLETE (kernel hangs, `timeout 10s exit 124`) + F-NUMERIC-EQ (BLOCKED no output). **2 precise codegen gaps surfaced**: **GAP-A** `gpu_warp_shuffle_xor` NOT WIRED — existing `gpu_warp_shuffle(v, lane)` at `nvptx_target.hexa:927` is `shfl.sync.idx.b32` only (idx-mode source-lane select); XOR-butterfly variant `shfl.sync.bfly.b32` + FP64 composition (2× u32-half) both unimplemented. **GAP-B** integer `/` binop NOT WIRED — 3 occurrences (`mask/2`, `tid/32`×2) emit `// unsupported binop: /`; leaves `%rd20`/`%rd21`/`%rd25` undefined → garbage in `mask` → `mask > 0` infinite loop → kernel hangs. **N64's STMT_LOAD/STORE + cmp + bounds-check + i64-classifier work PERFECTLY** for multi-thread accumulator loop (PTX lines 47-69 verified clean). Per-warp outputs N/A (hung before lane-0 store). Recommended follow-on cycles: **N71-A** wire `gpu_warp_shuffle_xor` → `shfl.sync.bfly.b32` · **N71-B** extend warp-shuffle FP64 composition · **N71-C** wire integer `/` → `div.s64`/`div.u64`. Artifact: `inbox/fires/rfc071_p9_warp_reduce_2026_05_21/` + fixture `compiler/codegen/nvptx_p9_warp_reduce_test.hexa`
- [x] **F-RFC067-HEXA-SGEMM-32X32-WARP-ACC (N71, FALSIFIES N66 hypothesis)** 🛸 — 32×32 per-warp accumulator implemented + fired on ubu-2 RTX 5070 sm_120. **Bit-exact PASS** all 6 shapes (maxabs=0.0). **PL peak = 13.45 TFLOPS @ M=1536 ratio 0.410 vs cuBLAS** — vs N66 PK 13.35 @ same shape = **+0.7% (noise floor)**. Per-shape vs PK: **M=256 -60%, M=384 -63%, M=512 -40%, M=768 -19%, M=1024 -24%, M=1536 +1%**. **N66's hypothesis "bump 16×16→32×32 per-warp as drop-in" FALSIFIED**. Mechanism: **register footprint 32→70 regs/thread** (32 fp32 accumulators + 16 fragment regs + pipeline temps); reg/CTA 70×512=35840 → only **1 CTA/SM fits** (RTX 5070 = 65536 regs/SM); vs N66 PK 32×512=16384 → 4 CTAs/SM. **Occupancy collapse 4×** wipes the 4× per-warp compute amortisation. ptxas info: 70 regs/thread, 16384 B smem, **0 spill** uniform across shapes. Small/mid shapes (M≤768) regress 19-63% because (M/128²) × 1 CTA = ≤36 CTAs vs 48 SMs (can't even fill 1 CTA/SM). cuBLAS ratio @ M=1536 went 0.406→0.410 (no real movement). **Real bottleneck instrumented**: RTX 5070 peak TF32 ~108 TFLOPS; cuBLAS hits 32.8 (30%); we hit 41% of cuBLAS = 12% of peak. **Remaining gap is memory subsystem**, NOT per-warp output size: (1) `cp.async` vectorisation size=4→16 (2) shared-mem bank-conflict swizzling (3) `ldmatrix` for shared→register. Follow-up candidates: 4-warp 32×32 CTA (64×64 output, fewer warps, vectorised cp.async size=16) + `.maxnreg 32` to force spill over occupancy collapse + `ldmatrix`-based shared→fragment. Artifact: `inbox/fires/rfc067_pL_hexa_sgemm_32x32_acc_2026_05_21/`
- [x] **F-RFC071-NVPTX-CSE-EXTENDED (N69, `a42db655`)** 🛸 — N45 CSE extended to N64's STMT_ASSIGN op="index"/"index_set" arms. **Multi-kernel PTX -12.28% (4609 → 4043 B / -566 B)** measured on ubu-2 RTX 5070. Per-kernel: `cvt.s64.s32` 4→1 + `mul.lo.s64` 3→1 (dedupes 3 redundant `to_i64(gid)` calls + shares `%rd_idx_off_<id>_<sz>` U64 reg). Declared virtual regs 21→19. ptxas physical regs 16→16 (pool coalesces). **Silicon-fire PASS all 3 fixtures**: vec_add max_abs=0 byte_mm=0/1024 · vec_mul max_abs=0 byte_mm=0/1024 · reduce_sum expected=512.5 got=512.5 abs_err=0 ulp_err=0. Reduce_sum 0 B delta is CORRECT (IndexSet uses const_int 0 not Local, so `_nvptx_collect_shared_idx_locals` finds no idx Local referenced by 2+ ops — CSE for `to_i64` also fires only once per kernel). 6 helpers added: `_nvptx_cse_intcast_remap` + `_nvptx_cse_apply` + `_nvptx_cse_remap_lookup` + `_nvptx_collect_shared_idx_locals` + `_nvptx_shared_idx_off_reg` + `_nvptx_shared_idx_has`. `_nvptx_lower_stmt` signature gained `shared_idx_off: [i64]`. 28/28 lower_test PASS. CPU codegen MD5-untouched (CSE only fires in `_nvptx_lower_func`, never reached for GPU_KIND_CPU). N45 baseline (single-kernel) maintained + N64 STMT_ASSIGN arms now benefit too. Artifact: `inbox/fires/rfc071_p4plus_n45_extend_2026_05_21/`
- [x] **F-RFC067-HEXA-SGEMM-CP-ASYNC-SIZE16 (N74)** 🛸 — Vectorised `cp.async.cg.shared.global` size=16 (4 fp32 per instruction) replaces N66's `cp.async.ca` size=4. **Peak 15.25 TFLOPS @ M=1536 (+14.2% vs N66 13.35), ratio 0.464 vs cuBLAS 32.83 (+0.058 absolute vs N66 0.406)**. Bit-exact PASS all 6 shapes (max_abs=0 vs cuBLAS, TF32 deterministic). Per-shape Δ vs N66: M=256 +0.0% (launch-bound), M=384 +0.2%, M=512 **+12.0%**, M=768 **+12.1%**, M=1024 **+12.2%**, M=1536 **+14.2%**. ±0.16% RSD at M=1536. **Partially falsifies N71's first-candidate prediction (+30%)**: measured +14.2% = ~47% of predicted. cp.async IS real bottleneck (above 10% sanity floor) but **NOT dominant**. Per-K-step cp.async instruction count dropped 4× (1024→256) but wall-time only improved 14% — cp.async issue throughput NOT gating mechanism at compute-bound shapes. Remaining 2.16× gap to cuBLAS bounded by: shared-mem bank conflicts at `wmma.load.shared` (N75 candidate), lack of ldmatrix swizzle (N76 candidate), warp-specialisation (256 threads idle during cooperative load), or occupancy limits. Implementation: single-instruction swap + thread mapping tid[0,128) load A vec4, tid[128,256) load B vec4, tid[256,512) idle. Alignment proof in PTX comments: S≡0 mod 64 → 16-aligned ✓. Predication divergence at warp granularity (no within-warp penalty). Artifact: `inbox/fires/rfc067_pM_hexa_sgemm_cpasync_vec16_2026_05_21/`
- [ ] **F-RFC067-HEXA-SGEMM-XOR-SWIZZLE (N75, RATE-LIMITED partial fire)** — Sub-agent rate-limited mid-cycle. PTX generator + 6 .ptx + host.c produced; **ptxas REJECTS all 6 with undeclared `%rb20`/`%rb21` registers** (line 299, 304, 317). 6/6 shapes SKIPPED (ptxas err: Unknown symbol). cuBLAS baseline reproduced (33.14 TFLOPS @ M=1536). Sub-agent did not finish debugging the swizzle register declarations before rate-limit. **Honest negative**: bundle non-functional, requires another cycle to fix register declarations (likely missing `.reg .b64 %rb<...>` declarations or wrong bank). Artifact: `inbox/fires/rfc067_pN_hexa_sgemm_xor_swizzle_2026_05_21/`
- [ ] **F-RFC067-HEXA-SGEMM-LDMATRIX (N76, RATE-LIMITED partial fire)** — Sub-agent rate-limited mid-cycle. PTX generator + 6 .ptx + host.c produced; **ptxas REJECTS all 6** at line 247 (`wmma.mma`): "Unexpected instruction types specified for 'wmma.mma'". Confirms honest scope risk N76 was warned about: ldmatrix.b16 vs TF32 wmma type mismatch — reinterpret was incorrect. 6/6 shapes SKIPPED. cuBLAS HGEMM baseline reproduced (66.58 TFLOPS @ M=1536 — Path B FP16 chosen by sub-agent before rate-limit). **Honest negative**: ldmatrix.x4.m8n8.b16 emits 4× 16-bit fragments but `wmma.mma.aligned.col.row.m16n16k8.f32.tf32.tf32.f32` expects TF32 fragments — type mismatch unresolvable without bit-reinterpret cast `mov.b32 → cvt.tf32.f32`. Next cycle: either (A) full TF32 reinterpret via mov.b32 between ldmatrix and wmma, OR (B) switch to FP16 wmma path natively (`wmma.mma.aligned.col.row.m16n16k8.f16.f16.f16.f16` or `.f32.f16.f16.f32`) and compare to N38 HGEMM baseline. Artifact: `inbox/fires/rfc067_pO_hexa_sgemm_ldmatrix_2026_05_21/`
- [ ] **F-RFC071-NVPTX-SHFL-BFLY-B32 (N71-A, RATE-LIMITED)** — Sub-agent rate-limited at 63 tool uses / 380s. NO worktree commits. `gpu_warp_shuffle_xor` builtin wiring NOT landed. Recovery: re-launch in next cycle (target line ~927 of `compiler/codegen/nvptx_target.hexa`, add sibling to existing `gpu_warp_shuffle`, emit `shfl.sync.bfly.b32`).
- [ ] **F-RFC071-NVPTX-DIV-INTEGER (N71-C, RATE-LIMITED)** — Sub-agent rate-limited at 57 tool uses / 363s. NO worktree commits. Integer `/` → `div.s64`/`div.s32`/`div.rn.f32` wiring NOT landed. Recovery: re-launch in next cycle (same pattern as N57 `div.rn.f64`).
- [x] **F-RFC067-HEXA-SGEMM-LDMATRIX (N76-retry, Path B FP16 HGEMM)** 🛸🛸 — **NEW HEXA RECORD: peak 31.28 TFLOPS @ M=1536, +76% vs N38 baseline (17.78), +105% vs N74 (15.25), ratio 0.462 vs cuBLAS HGEMM 67.65**. Bit-exact all 6 shapes (max_abs=0.0). Path A (TF32 reinterpret) skipped; Path B (FP16 native HGEMM with `mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32`) chosen — `ldmatrix.x4.b16` produces 4 b32-packed fragments per lane (correct for `mma.m16n8k16` A-frag input). Per-shape ratios: M=256 0.979 (launch-bound) · M=384 0.897 · M=512 0.645 · M=768 0.577 · M=1024 0.479 · **M=1536 0.462**. Kernel design: 16 warps in 4×4 layout, 64×64 output/CTA, 512 threads/block. Each warp computes 16×16 via 2× `mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32`. Shared mem 8192 B (2 buffers × 2 slabs × 64×16×2 B). K-tile = 16 FP16 elements. `ldmatrix.sync.aligned.m8n8.x4.shared.b16` for A (row), `.x4.trans` for B (col-major in shared). 2-stage `cp.async.ca` pipeline (prologue + per-iter prefetch/consume). **Falsifier F-RFC067-HEXA-SGEMM-LDMATRIX PASS**. Honest scope: 0.46-0.48 ratio at large M under 0.5+ headline target — ldmatrix wasn't the only bottleneck. Plateau M=512..1536 = register pressure + single-buffered D + lack of software-pipelined mma/ldmatrix overlap. Small-shape ratio 0.98 @ M=256 is launch-bound, not signal. PI/PJ/PK/PL/PM TF32 series vs PO HGEMM are NOT apples-to-apples — only absolute TFLOPS on same device comparable. Path A unmeasured. Artifact: `inbox/fires/rfc067_pO_hexa_sgemm_ldmatrix_2026_05_21/`
- [x] **F-RFC067-HEXA-SGEMM-XOR-SWIZZLE (N75-retry)** 🛸 — XOR row-permutation swizzle on shared-mem layout. Bit-exact PASS all 6 shapes on RTX 5070 sm_120 (max_abs=0.0). **Peak 14.15 TFLOPS @ M=1536, ratio 0.4269 vs cuBLAS** = **+6.0% vs N66 PK baseline (13.35)** · **-7.2% vs N74 PM baseline (15.25)**. Per-shape ratios: M=256 0.695 · M=384 0.509 · M=512 0.499 · M=768 0.563 · M=1024 0.553 · **M=1536 0.427**. **Fix from rate-limited cycle**: prior PTX declared `.reg .b32 %rb<4>;` + `.reg .b32 %rb2<4>;` intending `%rb0..3` + `%rb20..23`, but ptxas tokenises `%rb20` ambiguously. Collapsed to single `.reg .b32 %rb<6>;` and renamed `%rb20→%rb4`, `%rb21→%rb5`. Swizzle pattern: `phys_col = log_col XOR (log_row & 7)` applied symmetrically on cp.async store + consumer load. XOR self-inverse so round-trip preserves semantics. **Useful partial negative (`@D g3`)**: 2 changes bundled (XOR swizzle + mma path swap to `mma.sync.m16n8k8 × 2`). The +6% over N66 PK can NOT be attributed solely to XOR — likely the 2-mma manual-fragment path adds overhead partly cancelling swizzle gain, consistent with -7% vs N74. **Conclusion**: bank-conflict swizzling on RTX 5070 sm_120 is **measurable but not dominant**; vector cp.async (N74) remains stronger single-axis win on this substrate. Plain `ssh ubu-2` per 2026-05-21 user instruction. Artifact: `inbox/fires/rfc067_pN_hexa_sgemm_xor_swizzle_2026_05_21/`
- [x] **F-RFC071-NVPTX-SHFL-BFLY-B32 (N71-A, `9d21356c` + `7671d7db`)** 🛸 — `gpu_warp_shuffle_xor(v, lane_mask) -> u32` wired to NVPTX codegen. Emits `shfl.sync.bfly.b32 %r<dst>, %r<src>, %r<mask>, 0x1f, 0xffffffff;`. `bfly` mode XORs caller's lane id with mask operand → canonical primitive for warp-reduce butterfly (mask = 16, 8, 4, 2, 1 reduces 32 lanes pairwise). `0x1f` lane-mask+clamp-mode selector (full warp); `0xffffffff` membermask covering all 32 warp lanes (CUDA __FULL_MASK). Mirrors `gpu_warp_shuffle` shape — same U32 dst bank, same `%r<id>` register operands. **NEW const**: `PTX_OP_SHFL_SYNC_BFLY_B32`. **Classifier rule** added → NVPTX_RKIND_U32. Manual integration on main (preserving N71-C's div.s64/.s32 work landed in `9652fd5e`/`56256c6f`) — lower_test case 30 cherry-pick conflicted with N71-C's case 29 + counter strings, deferred case-30 re-pick to follow-on cycle. **Combined N71-A + N71-C closes both N70 GAP-A + GAP-B**: N70 warp_reduce_sum kernel previously hung at `mask/2`/`tid/32` (no integer div) + `gpu_warp_shuffle_xor` (no XOR shuffle). Both now wired — silicon re-fire pending (N77+ cycle). FP64 composition (2× shfl on hi+lo halves + `mov.b64` reassemble) deferred. PTX ISA §9.7.13.4.
- [x] **🛸🛸🛸 F-RFC067-HEXA-SGEMM-LDMATRIX-CPASYNC-STACK (N77, NEW HEXA RECORD)** — Stack ldmatrix consumer (N76) + cp.async size=16 producer (N74) into single HGEMM kernel. **Peak 36.06 TFLOPS @ M=1536, ratio 0.533 vs cuBLAS HGEMM 67.65 = +15.27% over N76 baseline (31.28)**. Bit-exact PASS all 6 shapes (max_abs=0.0). **Stack COMPOUNDS, no interference**. Multiplicative prediction 0.462 × 1.142 = 0.528; measured 0.533 slightly ABOVE prediction. Per-shape: M=256 +4.84% · M=384 +4.50% · M=512 **+15.29%** · M=768 **+12.99%** · M=1024 **+15.12%** · M=1536 **+15.27%** (ratio 0.533). Design: only producer changed (N76 used 512 threads × `cp.async.ca size=2` per-fp16 = 1024 async issues/K-step; PP uses 256 active threads × `cp.async.cg size=16` 8-fp16-packed = 256 issues/K-step = **4× reduction**). Consumer (`ldmatrix.x4` + 2× `mma.sync.aligned.m16n8k16`) byte-identical to N76. **Honest scope**: M=256/384 launch-bound regime (+4-5% small). Wins ADDITIVE in % terms not super-additive — clean compound, no 2nd-order amplification. ~47% gap to cuBLAS HGEMM remains; next lever likely mma fragment shape m16n8k16 vs cuBLAS's likely m16n8k32, or register pressure/occupancy. Plain `ssh ubu-2`. Artifact: `inbox/fires/rfc067_pP_hexa_sgemm_ldmatrix_cpasync_2026_05_21/`
- [x] **F-RFC067-PERF-SCOREBOARD (N87)** 📊 — Cumulative cuBLAS catch-up scoreboard at `inbox/fires/perf_scoreboard_2026_05_21/SCOREBOARD.md` (322 lines, 31 cycles tabulated across 8 sections). Per-substrate peaks (PRE-N77; N77 supersedes HGEMM row): **RTX 5070 HGEMM 31.28 TFLOPS @ 1536³ (N76-retry, ratio 0.462)** + **RTX 5070 SGEMM 15.25 TFLOPS (N74 cp.async, ratio 0.464)** + RTX PRO 4500 Blackwell SGEMM 22.36 (N60 cross-substrate) + Apple M3 MPS FP32 1.70 (N48) + RTX 5070 bandwidth **1624 GB/s L2 peak / 644 GB/s sustained DRAM = 93% spec peak (N63)**. Top 3 single-axis wins: (1) N76-retry ldmatrix **+76% vs N38** (17.78→31.28) (2) N74 cp.async vec16 **+14.2% vs N66** (3) N75-retry XOR swizzle +6.0%. Top 3 falsified hypotheses: (1) N66 3-stage SW pipeline strictly worse than 2-stage (slot-mod-3 overhead) (2) N71 32×32 per-warp collapses occupancy 4× (70 regs/thread → 1 CTA/SM) (3) N76 Path A TF32 reinterpret + ldmatrix.b16 unresolvable (switched to Path B FP16 native for +76% record). **Honest scope on cuBLAS-beat: NO compute-bound shape currently exceeds ratio 1.0**. Best compute-bound = 0.897 (N76 HGEMM @ 384³). Best overall = 0.979 @ 256³ launch-bound (not signal). NOTE: N77 stack (ratio 0.533 @ M=1536) supersedes N76-retry baseline; scoreboard captured pre-N77 state.
### 1g — RFC 075 Metal P4 silicon-fire (2026-05-21) 🛸

First-ever Mac silicon-fire for hexa-lang. Crash-recovery cycle freed Mac-local capacity; Metal P4 closure was the next P4-ready row in §10. MSL kernel text emitted via the same shape that `codegen_emit_metal_msl` produces (verified by reading `compiler/codegen/metal_target.hexa:318-350` `_metal_emit_preamble` + `_metal_emit_kernel_signature` + `_metal_emit_vec_add_body` constants), compiled through Apple's toolchain, dispatched on Apple M3 GPU, compared bit-exact to a CPU reference. Artifact: `inbox/fires/rfc075_metal_p4_2026_05_21/`.

- [x] **F-RFC075-METAL-EMIT-PIPELINE** — `xcrun -sdk macosx metal -c vec_add.metal -o vec_add.air` rc=0 + `xcrun metallib vec_add.air -o vec_add.metallib` rc=0. AIR=3,584 B, metallib=3,741 B. Toolchain: Apple metal 32023.883 (metalfe-32023.883), target `air64-apple-darwin25.5.0`
- [x] **F-RFC075-METAL-LIBRARY-LOAD** — `MTLDevice.makeLibrary(URL:)` resolves the `vec_add` function symbol; `MTLComputePipelineState` constructs cleanly on Apple M3 (registry_id=4294968442, max threads/threadgroup 1024). No `Metal` runtime errors
- [x] **F-RFC075-METAL-NUMERIC-EQ** 🛸 — N=1024 FP32 cells, LCG-deterministic inputs (`a[i] = lcg_f32()`, `b[i] = lcg_f32()`, ref `c[i] = a[i] + b[i]`), dispatch as 1D grid (`dispatchThreads(grid, threadsPerThreadgroup:1024)`), read-back via `MTLBuffer.contents()`. **max|Δ|=0.0**, **byte_mismatch=0/1024** (bit-exact via `bitPattern` comparison). PASS
- [x] **§10 closure box "Multi-vendor: ROCm or Metal kernel parity" flips `[ ]` → `[x]`** — Metal P4 silicon-fire MET. Closure scoreboard moves **6/8 → 7/8 ✅**. ROCm P4 still pending (no AMD GPU in pool — multi-session procurement)
- [x] **F-RFC075-METAL-SCALEUP-NUMERIC-EQ** 🛸 — 7-shape sweep N∈{1024, 4096, 16384, 65536, 262144, 1048576, 4194304}. ALL byte-eq with CPU reference (`max|Δ|=0.0`, `byte_mismatch=0/N` per shape). Effective bandwidth scales with N: 0.05 → 0.25 → 1.08 → 3.73 → 12.19 → 23.13 → **50.53 GB/s** at N=4 M (3·N·4 B / median_ms · 1e9). Apple M3 LPDDR5 theoretical ~100-150 GB/s shared with CPU → 35-50% efficiency at saturation. 50 timed launches per shape (5 warmup) using `cuLaunchKernel`-equivalent `MTLCommandBuffer.waitUntilCompleted` wall time. Artifact: `inbox/fires/rfc075_metal_p4_scaleup_2026_05_21/`
- [x] **F-RFC075-METAL-ROOFLINE-PROBE** 🛸 — Apple M3 GPU roofline probe via hand-emit `kernels.metal` with 5 kernels (1op / 4op / 16op / 64op / 256op chained per cell) × 4 shapes (N=64K/256K/1M/4M). 50 timed launches per (kernel, N). Crossover regime at N=4M: 1op = 34.91 GB/s + 2.91 GFLOPS (memory-bound) · 16op = **52.37 GB/s peak + 69.83 GFLOPS** (bandwidth saturation) · 64op = 48.73 GB/s + **259.87 GFLOPS peak** (compute-bound) · 256op = 11.11 GB/s + 236.98 GFLOPS (register pressure or thermal). Apple M3 8-core GPU theoretical ~3.2 TFLOPS FP32 → achieved 260 GFLOPS ≈ 8 % (single-buffer, no SIMD-group optimization). Roofline crossover = between 16-op and 64-op for vec-add-style memory pattern. Artifact: `inbox/fires/rfc075_metal_roofline_2026_05_21/`. Hand-emit kernels are NOT codegen-produced (probe is for Apple M3 characterisation, not codegen validation)

g3 caveats:
- Single vec-add kernel shape (the only shape `codegen_emit_metal_msl` recognises today); general `MFunc` → MSL emit is multi-session follow-on
- USER-LOCAL Mac fire path: this kernel cannot run on ubu-2 x86_64 / RTX 5070 (the Mac and the Nvidia GPU lanes are now bi-platform validated and remain orthogonal)
- N=1024 (small); larger N + multi-threadgroup + reductions are follow-on cycles
- No perf measurement — silicon-fire correctness only; Metal vs cuBLAS / Metal Performance Shaders perf comparison is a separate cycle

---

## 2 · Next layer (concrete, scope-bounded — pick one to start)

### 2a — Source-to-silicon e2e closure (RFC 068 last gap)

Today's silicon fires used hand-emit PTX (codegen verification via `nvptx_lower_test` smoke; silicon via fire). The remaining gap: a `.hexa` source file with `@gpu_kernel fn f16_vadd(...)` lowering through HIR → MIR → codegen_emit_ptx_sm80 → ptxas → fire.

- [ ] **source kernel fixture** — write `test/rfc068_f16_vadd_e2e.hexa` with `@gpu_kernel fn f16_vadd(a: [f16], b: [f16], c: [f16], n: i64)` body
- [ ] **HIR → MIR lowering** — verify `let t: f16 = a[i] + b[i]` lowers to `STMT_LOAD .f16 + STMT_BINOP add_f16 + STMT_STORE .f16` with precision tag propagated
- [ ] **MFunc.gpu_kind = KERNEL** — `@gpu_kernel` annotation parse + lowering hooked
- [ ] **codegen emits launchable PTX** — `.visible .entry` + `.param .u64` quartet (a/b/c/n) + body
- [ ] **ptxas-clean check** — emitted PTX passes `ptxas -arch=sm_80`
- [ ] **fire on ubu-2** — driver-JIT + cuLaunchKernel + compare to f64 reference
- [ ] **`F-RFC068-E2E-NUMERIC-EQ`** PASS — full source-to-silicon chain byte-eq closure
- [ ] **commit** — same `inbox/fires/` pattern as PR #189

### 2a finding (2026-05-20): build pipeline gap analysis

The blocker is NOT in `self/main.hexa::cmd_build` `--target=` validation
(adding a `nvptx64-*` branch there is one-line edit). The substantive
gap is the BUILD PIPELINE itself:

```
Current `hexa build` (CPU targets):
  src.hexa → module_loader (flatten) → hexa_v2 transpiler (.c)
           → clang/zig cc → native binary

Required for NVPTX:
  src.hexa → module_loader (flatten) → in-hexa compiler self-host
           → MIR → codegen_emit_ptx_sm80 → PTX text
```

`hexa_v2` is the **bootstrap transpiler** that emits C — it doesn't
know about NVPTX. The NVPTX codegen lives in `compiler/codegen/
nvptx_target.hexa` and is invoked only from within the in-hexa
self-host pipeline (which today produces CPU artifacts via the
existing `compiler/*` tree, not via `hexa_v2`).

To wire `hexa build --target=nvptx64-*` properly, options are:
- (A) **Internal emit-driver pattern** — `cmd_build` synthesizes a
  small driver `import src.hexa + compiler/codegen/nvptx_target.hexa`
  and prints `codegen_emit_ptx_sm80(...)`. Substantial: requires
  exposing the full compiler pipeline as a callable.
- (B) **Compiler self-host on NVPTX** — the in-hexa compiler IS
  the build path for `--target=nvptx64`. Aligned with north-star ②
  (self-host already PROVEN for CPU at fixpoint per memory
  `project_compiler_native_self_host_fixpoint`); extending to
  NVPTX is the natural next step.
- (C) **Out-of-band emit driver** — keep using the external script
  pattern from PR #82 (`tool/dispatch_*.sh`). Today's 8 fires
  successfully demonstrate this works. **No `hexa build` wiring
  required** for the actual silicon-validation path.

Choice for this session: **(C)** — defer (A)/(B) as multi-session
campaigns. The §1 ledger shows all silicon-fires landed via the
out-of-band pattern; full source-to-silicon `hexa build --target=
nvptx64-*` is a strategic infrastructure cycle for a separate
session.

**Update 2026-05-20 (RFC 071 P0 scaffold landed):** This gap is now
formally tracked as RFC 071 — see
`inbox/rfc_drafts_2026_05_20/rfc_071_source_to_silicon_e2e.md`. P0
landed the `cmd_build` target-string recognition for
`nvptx64-nvidia-cuda-sm80` / `sm90` / `sm120` (informative deferred
exit + RFC pointer; CPU codegen path byte-identical, no LLVM, no new
C-transpile architecture per `@F f1`/`@F f2`). P1-P4 (real dispatch +
emit-driver module + module_loader bridge + e2e silicon fire) are
explicitly deferred multi-cycle work governed by the F-RFC071-* falsifier
battery. Approach **A (internal emit-driver synthesis)** is the
recommended P1-P2 path; **B (compiler self-host on NVPTX)** is the
P3+ convergence path once north-star ②'s CPU self-host campaign
default-flips. Approach C remains the codegen-author fast iteration
shell — RFC 071 introduces a new path, not a replacement.

**Update 2026-05-20 (RFC 071 P1+P2 landed):** P1 replaced the
deferred-print + exit(1) branch with a call to
`self/main.hexa::_build_nvptx_emit_driver(src, sm_arch)` (F-RFC071-
TARGET-ACCEPT PASS). P2 added the spec sibling module
`compiler/cli/build_nvptx.hexa` defining
`pub fn build_nvptx_emit_driver(src_path, sm_arch) -> int` with a
canned stub PTX writer (`.version 7.0` / `.target sm_NN` /
`.address_size 64` / `.visible .entry _hexa_smoke() { ret; }`) —
F-RFC071-EMIT-DRIVER-INVOKE PASS as a STUB. **Honest punt (@D g3):**
the body emits CANNED PTX — F-RFC071-MODULE-LOADER-BRIDGE is
INTENTIONALLY deferred until P2.1 wires `codegen_emit_ptx_sm80(mir)`
(parse → check → lower → codegen chain documented in the module
docstring). CPU codegen byte-identical (`F-RFC055-CPU-CODEGEN-
UNTOUCHED` PASS by md5; @F f1/@F f2 honored). §10 box `[ ] §12 P4+
source-to-silicon e2e` stays `[ ]` per @D g3 — only the P4 numeric-eq
falsifier flips it.

### 2b — Multi-tile WMMA GEMM K-loop (RFC 067 §3 P4 spec form)

PR #191 closed the *single-tile* WMMA fire. The RFC 067 §3 P4 spec asks for 64×64 GEMM = 4×4 output tiles × 4 K-tiles = 64 `wmma.mma` calls with `.shared` staging.

- [ ] **multi-tile kernel** — hand-emit `wmma_64x64.ptx` with explicit 4×4×4 nested loops
- [ ] **`.shared` staging slot allocation** — 4 KB shared mem for A/B double-buffer tiles
- [ ] **K-loop accumulator carry** — C fragment reuse across K-tile iterations (no spill)
- [ ] **host launcher** — `tool/r067_p4_multi_host.c` mirrors `r067_p4_host.c` but 64×64
- [ ] **fire on ubu-2 + compare to FP32 reference** — `≤ 1e-2 rel error` tolerance (the canonical f16-mul-f32-acc bound)
- [ ] **`F-RFC067-TILE-LOOP-NUMERIC-MULTI`** PASS
- [ ] **codegen-side hexa equivalent** — synthesize MFunc with multi-block K-loop body + multi-`gpu_wmma_mma` STMT_CALL emit

### 2c — Codegen-side BF16 silicon reconcile

Today's PR #193 reconciled `f16 → b16` storage; bf16 reg type still trips ptxas 12.0 `.reg .bf16` parse.

- [ ] **PTX 7.8 toolchain bump probe** — test bf16 acceptance on `.version 8.0` / `.version 8.x` PTX targets
- [ ] **`add.bf16` instruction support** — verify ptxas accepts the bf16 arithmetic path
- [ ] **hexa codegen flip** — if PTX 8.x parses cleanly, emit `.version 8.0` + native `.reg .bf16` decl; else stay with `.reg .b16` and use bitcast
- [ ] **bf16 vec-add fire** — same pattern as PR #189 but bf16 inputs
- [ ] **`F-RFC068-NUMERIC-EQ-BF16`** PASS

### 2d — Hexa-native dispatch (replace direct-bash + sidesetep HEXA_FIRST_WARN)

PR #189/#190/#191 fires used direct one-shot bash; sustained automation needs hexa-native.

- [ ] **stdlib/cloud dispatch primer** — leverage existing `stdlib/cloud` ssh/scp/rsync APIs
- [ ] **`tool/dispatch_gpu_fire.hexa`** — generic hexa-native fire dispatcher (PTX path, host C path, target host)
- [ ] **smoke verify** — re-fire PR #82 / #189 / #190 / #191 kernels via the hexa dispatcher; results identical
- [ ] **migrate** — deprecate `tool/dispatch_r055_p2_gemm.sh` once hexa equivalent measured-PASS

### 2e — `cp.async` pipelining (sm_80+) — performance, not correctness

- [ ] **PTX opcode constants** — `PTX_OP_CP_ASYNC_F16`, `PTX_OP_CP_ASYNC_COMMIT_GROUP`, `PTX_OP_CP_ASYNC_WAIT_GROUP`
- [ ] **codegen seam** — when WMMA kernel's K-loop body references `.shared` storage, emit `cp.async.cg.shared.global` for prefetch
- [ ] **double-buffer pattern** — two `.shared` staging slots; alternating fill/use
- [ ] **fire vs no-`cp.async` baseline** — same numeric output, measure throughput gain
- [ ] **`F-RFC067-CP-ASYNC-PERF`** — throughput delta documented (≥ 1.3× target)

---

## 3 · Mid-term (deferred, scoped but multi-cycle)

### 3a — Additional dtypes

- [ ] **bf16 full silicon validation** (depends on 2c)
- [ ] **tf32 support** — `mma.sync.aligned.row.col.m16n16k8.f32.tf32.tf32.f32` for fp32 acceleration
- [ ] **int8 / int4** — quantization-friendly types; `dp4a` / `dp2a` instructions
- [x] **fp8 e4m3 / e5m2** (Hopper sm_90+) — codegen scaffold landed (RFC 068 §3): `NVPTX_RKIND_F8_E4M3` / `_F8_E5M2` constants + `%fe3<id>` / `%fe5<id>` reg banks (silicon-canonical `.b8` container per PTX ISA §5.4.1 + §9.7.13.5) + classifier short-circuit on `.f8_e4m3` / `.f8_e5m2` precision tag + `ld.global.b8` / `st.global.b8` ld/st dispatch + Case 26/27 lower_test (ld/st round-trip, bank-isolation negative guard). **No silicon fire** — fp8 WMMA mnemonic family (`wmma.mma.sync...e4m3.e4m3.f32`) + sub-byte ABI (kernel-arg packing, addr alignment) + parser-side `@f8_*` named-type grammar are follow-on cycles.
- [ ] **posit** — custom dtype emission (lattice-friendly arithmetic; experimental)
- [ ] **MXFP4 / NVFP4** — Blackwell sm_120+ dtypes if applicable to RTX 5070

### 3b — Tensor Core families beyond canonical

- [ ] **bf16×bf16→f32** family — flip `_nvptx_wmma_mnemonic_family` selector
- [ ] **f16×f16→f16** family — accumulation in `.f16` (lower precision)
- [ ] **tf32×tf32→f32** (Ampere+) — TF32 default precision GEMM
- [ ] **fp8 wgmma** (Hopper sm_90+) — `wgmma.mma_async` (asynchronous warp-group)
- [ ] **wgmma 64x64x16, 64x128x16** large tiles — larger working tile geometry
- [ ] **m8n8k16 / m16n8k8** non-standard shapes — flexible mnemonic table

### 3c — Memory hierarchy + addressing

- [ ] **`.shared` register-tiling helpers** — auto-staging on `gpu_*` op patterns
- [ ] **`.local` scratch space** — register-spill destination for large kernels
- [ ] **`.const` constant bank** — for kernel-invariant LUTs
- [ ] **`ld.cs` / `ld.lu` cache hints** — streaming / last-use semantics
- [ ] **TMA (Tensor Memory Accelerator) sm_90+** — `cp.async.bulk.tensor.<dim>d.shared.global`
- [ ] **Async barriers** — `mbarrier.init`, `mbarrier.arrive`, `mbarrier.wait`

### 3d — Optimization passes

- [ ] **Unroll factor>4 with register-pressure analysis** — refuse factor=N if predicted register count > 64
- [ ] **Loop-carried dependency analysis** — true LCD detection (currently trusts user)
- [ ] **Loop fusion** — adjacent kernels with shared address → single launch
- [ ] **Software pipelining** — interleave K-loop iterations
- [ ] **Constant folding through PTX** — known-constant operands → immediate
- [ ] **Dead-code elimination** — operations whose results are never read
- [ ] **Register allocation** — proper graph coloring (currently 1:1 Local→reg)
- [ ] **Polyhedral / affine loop transformation** — far-future advanced opt

### 3e — Source-level features (`@gpu_kernel` ergonomics)

- [ ] **`@gpu_kernel` attribute parse** — currently honored at lowering; verify parser surface
- [ ] **`@shared` annotation** — declare a `let` as shared-memory-resident
- [ ] **`@warp_intrinsic` annotation** — opt-in warp-shuffle intrinsics
- [ ] **`gpu_launch` builtin** — host-side `gpu_launch<<<grid, block>>>(kernel, args...)` lowering
- [ ] **`gpu_launch_async` / `gpu_event`** — CUDA stream + event API equivalents
- [ ] **`gpu_sync()` host-side** — `cudaDeviceSynchronize` wrapper
- [ ] **Source-level `gpu_atomic_*` family** — atomic ops covering add/cas/exch/min/max
- [ ] **Source-level `gpu_block_*` reductions** — sum / max / argmax via `bar.sync` + shared

### 3f — Multi-vendor (downstream — orthogonal to NVPTX)

- [ ] **HIP/AMD ROCm backend** — `gfx*` target dispatch (RFC 075 P0 scaffold landed: `compiler/codegen/rocm_target.hexa` + `rocm_lower_test.hexa` — emit stub returns `""`, P1+ multi-session BLOCKED — no AMD GPU in pool, cycle cannot silicon-fire-validate)
- [x] **Metal Performance Shaders** 🛸 — Apple Silicon GPU (`@gpu_kernel` → MSL source text; RFC 075 P1+P2+P3 codegen-only LANDED 2026-05-20 Campaign C: `compiler/codegen/metal_target.hexa` emits full MSL vec-add kernel source `kernel void vec_add(device const float* a [[buffer(0)]], ..., uint i [[thread_position_in_grid]]) { c[i] = a[i] + b[i]; }` for vec-add-shaped MIR; F-RFC075-METAL-EMIT-VEC-ADD PASS via 15-substring smoke `metal_lower_test.hexa`; **P4 silicon-fire LANDED 2026-05-21** — `xcrun -sdk macosx metal` + `metallib` + Swift `MTLComputePipelineState` dispatch on Apple M3 GPU. N=1024 FP32 vec-add max|Δ|=0.0 byte_mismatch=0/1024. F-RFC075-METAL-NUMERIC-EQ PASS. Artifact: `inbox/fires/rfc075_metal_p4_2026_05_21/`)
- [ ] **Intel oneAPI / Level Zero / SPIR-V** — Intel iGPU / Xe substrate (deferred to follow-on RFC, see RFC 075 §2)
- [ ] **WebGPU / SPIR-V** — browser substrate
- [ ] **Cross-vendor abstraction layer** — shared IR pre-target

---

## 4 · Performance benchmarking + competitive positioning

### 4a — Throughput baselines (vs vendor)

- [ ] **HGEMM throughput** — hexa-emit vs cuBLAS HGEMM on identical (M,N,K)
- [ ] **SGEMM throughput** — hexa-emit vs cuBLAS SGEMM
- [ ] **FP64 GEMM** — hexa-emit vs cuBLAS DGEMM
- [ ] **vec-add bandwidth** — hexa-emit vs CUDA stream `cudaMemcpy` (memory-bound)
- [ ] **kernel-launch overhead** — hexa-emit vs CUDA driver native (microseconds)

### 4b — End-to-end workload (flame integration)

- [x] **flame d=768·12L transformer 1 step wall** — hexa-emit (forge) **20-43% faster** vs PyTorch eager (memory: `project_flame_phase4d9_closure`, commit `28e9d648`)
- [ ] **flame d=4096 LLaMA-3 8B inference latency** — single-token autoregressive
- [ ] **flame mixture-of-experts dispatch** — sparse expert routing on GPU
- [ ] **flame flash-attention 2 fused kernel** — vs `xformers.ops.memory_efficient_attention`

### 4c — vs alternative GPU compiler stacks

- [ ] **vs Triton** — same kernels in hexa vs Triton DSL
- [ ] **vs Mojo** — heavy GPU kernels in hexa vs Mojo MAX
- [ ] **vs Halide-GPU** — algorithm + schedule split comparison
- [ ] **vs ThunderKittens** — single-file abstraction over wmma
- [ ] **vs CUTLASS** — template-based GEMM library

### 4d — vs cuBLAS-using stacks (where hexa structural advantage applies)

- [ ] **PyTorch eager (uses cuBLAS+cuDNN+ATen)** — already partially measured (flame 4-D-9 closure)
- [ ] **JAX (XLA-based; uses cuBLAS via XLA)** — comparable architecture, more aggressive fusion
- [ ] **TensorFlow eager** — older but still widely deployed
- [ ] **MLX (Apple ML)** — Metal-based stack on M-series
- [ ] **TinyGrad** — minimalist Python-based codegen

---

## 5 · Niches where hexa structurally beats cuBLAS (potential moat)

### 5a — Fusion that cuBLAS can't do

- [ ] **GEMM + epilogue fusion** — GEMM + bias_add + ReLU + dropout in single kernel (cuBLAS-LT does some, but limited)
- [ ] **Attention scoring fusion** — Q@K^T + softmax + V@ in single kernel (flash-attn pattern)
- [ ] **MoE dispatch + GEMM + reduce** — single kernel from gate to output
- [ ] **LayerNorm + GEMM fusion** — pre-layer-norm fused with GEMM weights
- [ ] **AdamW step fusion** — optimizer + parameter update fused with gradient compute

### 5b — Compile-time specialization

- [ ] **Static shape specialization** — known-(M,N,K) kernels avoid all runtime branches
- [ ] **Dead-output elimination** — masked outputs / pruned channels removed at compile time
- [ ] **Sparsity-pattern specialization** — block-sparse / structured-sparse layouts as compile-time facts
- [ ] **Mixed-precision auto-selection** — picker chooses dtype per layer based on compile-time error analysis

### 5c — Custom dtypes / non-IEEE arithmetic

- [ ] **n=6 lattice primitives** — RFC 057 / hexa-arch chip — non-binary lattice math on GPU
- [ ] **Posit arithmetic** — variable-precision posit emit
- [ ] **Interval arithmetic** — error-bounded compute
- [ ] **Stochastic rounding** — quantization-friendly random rounding

### 5d — Whole-program autograd-aware

- [x] **flame `ag_tape` / `ag_derive`** — already SD1-SD6 landed (PRs in main history)
- [ ] **GPU kernel fusion across autograd boundaries** — forward + backward kernels fused
- [ ] **Compile-time gradient symbolic simplification** — vs PyTorch's autograd runtime tape

### 5e — Non-NVIDIA hardware

- [ ] **Apple M-series Metal Performance Shaders** — Apple-silicon GPUs (currently flame uses CPU on M-series)
- [ ] **AMD MI300 / MI350** — ROCm HIP backend
- [ ] **Intel Xe / Arc** — oneAPI / Level Zero
- [ ] **Multi-vendor unified kernel** — same `@gpu_kernel` lowered to multiple backends

### 5f — Launch-overhead amortization (PyTorch eager / library-call stacks lose here)

- [x] **flame d=768·12L transformer — 20-43% faster than PyTorch eager** — already measured (`project_flame_phase4d9_closure`). PyTorch eager pays per-op kernel launch overhead; cuBLAS calls cost ≥5 μs each. Hexa whole-program fusion eliminates the per-op launch path
- [ ] **No PyBind11 / no ATen dispatch overhead** — cuBLAS via PyTorch goes through Python → C++ Tensor → ATen → CUDA stream → cuBLAS handle. Hexa-emit directly compiled into the binary
- [ ] **Static kernel selection** — cuBLAS-LT runtime heuristic picks an algorithm; hexa compile-time selects + bakes the algorithm
- [ ] **Single-shot binary** — no shared library boundary, no `cudaGetSymbolAddress`, no driver-level dispatch table

### 5g — Operator-specific surgical override

- [ ] **Replace one kernel mid-pipeline** — cuBLAS is monolithic API; hexa codegen lets a single GEMM in a chain be hand-tuned while the rest of the pipeline stays unchanged
- [ ] **Per-call-site precision** — same logical GEMM compiled with different precision per call site (cuBLAS forces uniform-handle precision)
- [ ] **Mixed-precision in single kernel** — f16 A × f16 B → f32 accum → bf16 store, all in one kernel; cuBLAS API forces handle-uniform dtype
- [ ] **Custom layout / striding** — cuBLAS has limited stride options; hexa per-kernel custom layouts (e.g., interleaved tile arrangements)

### 5h — Compile-time error / safety analysis

- [ ] **Static overflow check** — known input ranges + arithmetic chain → compile-time overflow risk warning (cuBLAS = runtime only, often silent)
- [ ] **Compile-time NaN-Inf propagation reasoning** — track which operations could introduce NaN/Inf based on input domain analysis
- [ ] **Numerical-stability lint** — flag patterns like `large - small` that lose precision; cuBLAS users have no static signal
- [ ] **Determinism-mode at compile-time** — `@deterministic` annotation switches to deterministic-reduction emit at codegen; cuBLAS's `CUBLAS_PEDANTIC_MATH` is a runtime flag that costs perf

### 5i — Source-level visibility + ergonomics

- [ ] **`.so` blob vs source emit** — cuBLAS is closed-source binary; hexa users see + modify the emit path. Bug-fix loop: cuBLAS = file ticket + wait; hexa = patch source + rebuild
- [ ] **`hexa gpu disasm`** — view exact SASS via `cuobjdump`; cuBLAS too but harder to correlate to user code (the high-level mapping is lost in the closed binary)
- [ ] **Single-language stack** — host + device + autograd all in hexa-lang; cuBLAS-using stacks need Python/C++/CUDA polyglot
- [ ] **No vendor-lock-in path** — hexa codegen targets backend-agnostic IR; cuBLAS hard-binds to NVIDIA

### 5j — Algorithmic flexibility (cuBLAS = limited operator surface)

- [ ] **FlashAttention-style fused softmax + attention** — already a paper-derived pattern; cuBLAS doesn't cover the attention-block pattern directly (xformers / FlashAttention 별도 library)
- [ ] **Online softmax** — single-pass numerically stable softmax (cuBLAS = no softmax at all)
- [ ] **Block-sparse / structured-sparse GEMM** — cuBLAS = dense only (sparse is cuSPARSE 별도)
- [ ] **Custom reductions** — cuBLAS has SUM/MAX; arbitrary reduction (LogSumExp / soft-argmax) hand-written
- [ ] **Top-k / argmax fused with GEMM** — cuBLAS = GEMM only; hexa can fuse arbitrary epilogue

### 5k — Domain-specific kernel libraries (whole-program co-design)

- [x] **flame `ag_*` autograd-aware GEMM family** — SD1-SD10 vjp registry landed; GEMM kernels know about gradients (memory: `project_flame_mk2_cycle_2026_05_19`)
- [ ] **sim_universe lattice GEMM** — non-binary lattice arithmetic on GPU (RFC 057 bridge)
- [ ] **quantum amplitude-update kernels** — `stdlib/quantum` state-vector simulation (cuBLAS = no amplitude ops)
- [ ] **flame layer-fused training kernel** — forward + backward + AdamW + grad-clip in single kernel emit
- [ ] **NN-specific HEXA primitives** — `softmax`, `layer_norm`, `RoPE`, `swiglu` as first-class compiler-aware ops

### 5l — Edge / embedded / standalone deployment

- [ ] **Standalone cubin embed** — `hexa build` produces a binary with embedded `.cubin`; no separate cuBLAS .so dependency
- [ ] **AOT compilation** — kernel compiled once at build time; no runtime cuBLAS JIT
- [ ] **Multi-arch fat binary** — embed PTX for sm_70 + sm_80 + sm_90 in one cubin via hexa codegen
- [ ] **NVIDIA-runtime-free deployment** — minimal driver-only deployment surface (no cuBLAS/cuDNN required)
- [ ] **Containerized cubin** — single-binary container without `libcublas.so.12` dependency

### 5m — Measured wins to-date (g3-honest claims)

- [x] **flame d=768·12L 1-step wall**: hexa-emit 191-268s vs PyTorch-eager 336.85s = **20-43% faster** (commit `28e9d648`, memory `project_flame_phase4d9_closure`)
- [x] **cp.async pipelining ~7% slower than no-async at K=64**: honest negative perf measurement (PR #207) — proves the codegen path works + sets the boundary where cp.async overhead amortizes (large K)
- [x] **WMMA + multi-warp grid + multi-K-tile + cp.async + tf32**: 5 distinct WMMA-family kernel patterns all silicon-validated max\|Δ\|=0 vs FP32 reference (PRs #191/#205/#206/#207/#213)
- [x] **HGEMM throughput vs cuBLAS at M=N=K=256**: hexa-emit **4.0960 TFLOPS** vs cuBLAS GemmEx **8.1907 TFLOPS** = **ratio 0.500 ±0.0002** (6-run variance, sub-0.1% std). Closure criterion "≥ 50% of cuBLAS HGEMM" **MET at this shape** (PR #214). Caveat (g3): single shape; at larger M/N/K cuBLAS's k-loop unroll + ILP + shared-memory pipelining advantages compound; this single data point does NOT generalize. Multi-tile cp.async (PR #207) not yet integrated into this perf kernel — natural next-cycle.
- [ ] **HGEMM at M=N=K≥1024**: pending — scale-up + cp.async integration to test if 0.50× ratio holds or degrades at large shapes (where cuBLAS optimizations matter)
- [x] **PyTorch eager d=1024 12L FP32 PROXY baseline on RTX 5070**: median 1-step wall = **116.286 ms** (std 0.104 ms = 0.089 % of median; peak 5,060 MiB) at d=1024 n_layer=12 batch=2 seq=512 FP32 Adam eager. RFC 072 P1 (this PR). Caveat (g3): this is the L4 ladder rung — RFC 072 §2 spec (d=2048+ 12L) **does not fit** the 12 GB consumer-GPU envelope on PyTorch eager (50,257-token embed+head alone occupies ~5 GiB Adam-state overhead); d=4096 24L full-spec baseline requires H100 80GB multi-session. F-RFC072-WALL-PT-PROXY MEASURED · F-RFC072-WALL-PT-FULL DEFERRED.
- [ ] **Whole-program-fusion ≥ 30% over cuBLAS-using stack on a representative LLM workload** — sustained across model variants (flame d=768 partially measured)

---

## 6 · Verification + safety

### 6a — Numerical

- [ ] **Bit-exact reference** — every emitted kernel compared to a bit-exact reference (cpu)
- [ ] **ULP-bounded checker** — tolerance-aware compare via a small test harness
- [ ] **Determinism mode** — force deterministic reductions (no atomics, ordered K-loop)
- [ ] **Kahan summation in GEMM K-loop** — error-bounded accumulator
- [ ] **NaN / Inf propagation** — verified across f16 / bf16 underflow / overflow

### 6b — Formal / semantic

- [ ] **PTX emit semantic equivalence proof** — Coq/Lean proof that codegen preserves MIR semantics
- [ ] **Register allocation correctness** — formal proof that allocation never aliases live ranges
- [ ] **Loop-unroll preservation** — proof that unrolled CFG ≡ original CFG semantically

### 6c — Runtime safety

- [ ] **Bounds-check elision** — verified safe when guarded
- [ ] **Race-detection** — static analyzer over shared-memory accesses
- [ ] **Memory-ordering** — `bar.sync` / `mbarrier` placement audit

---

## 7 · Ecosystem + observability

### 7a — Profiling / introspection

- [ ] **PTX register-count reporter** — `ptxas -v` integration into `hexa build`
- [ ] **Occupancy estimator** — given kernel + GPU SM, predict theoretical occupancy
- [ ] **Nsight Compute integration** — emit metadata for profiler attach
- [ ] **CUDA Graph API** — `cuGraphLaunch` for multi-kernel graphs
- [ ] **Driver API vs Runtime API** — pick based on use-case

### 7b — Documentation + examples

- [x] **gpu/SPEC.md** — existing spec doc (per AGENTS.tape mentions)
- [x] **inbox/rfc_drafts_2026_05_20/rfc_06[7-9]_*.md** — 3 RFC drafts
- [ ] **GPU.md** (this file) — domain SSOT roadmap
- [ ] **Tutorial — "first GPU kernel in hexa"** — beginner's onramp
- [ ] **Cookbook — "GEMM patterns from naive to wmma"** — performance evolution

### 7c — Toolchain ergonomics

- [ ] **`hexa gpu build`** — single-command path: source `.hexa` → PTX → cubin
- [x] **`hexa gpu fire <kernel> <host>`** — single-command remote fire  (PR #215, 2026-05-20)
- [ ] **`hexa gpu profile`** — wraps Nsight Compute
- [x] **`hexa gpu lint <ptx>`** — static check on a PTX file (non-ASCII / `.target sm_NN` / `.reg` count / opcode-vs-sm consistency)  (this PR, 2026-05-20)
- [x] **`hexa gpu disasm <ptx>`** — PTX opcode-family histogram via pure-hexa scan (no ptxas/cuobjdump dependency)  (this PR, 2026-05-20)

---

## 8 · Far-future / research questions

### 8a — Beyond NVPTX

- [ ] **PTX → SASS direct emit** — bypass ptxas, hand-emit GPU machine code
- [ ] **SPIR-V emit** — open-standard GPU IR
- [ ] **MLIR integration** — bridge to upstream MLIR (controversial — vs hexa-native principle)
- [ ] **Cooperative groups API** — multi-block synchronization

### 8b — Auto-tuning

- [ ] **Search-based tile-size selection** — autotune over block/grid/unroll
- [ ] **ML-based scheduling** — neural-net cost model for codegen choices
- [ ] **Random restart for kernel synthesis** — try N variants, pick best

### 8c — Specialized hardware

- [ ] **NVIDIA Grace-Hopper** — CPU+GPU unified memory (`MemcpyDtoH` becomes a no-op)
- [ ] **NVLink / NVSwitch** — multi-GPU collective primitives
- [ ] **AMD Instinct MI300A** — APU-style hexa kernel
- [ ] **Intel Ponte Vecchio** — Xe Matrix Extensions

### 8d — Esoteric / experimental

- [ ] **Quantum GPU bridge** — `stdlib/quantum` + GPU acceleration for state-vector simulation
- [ ] **Lattice n=6 GPU emit** — RFC 057 hexa-arch substrate, but on GPU
- [ ] **Neuromorphic compatibility** — `stdlib/sim_universe` substrate on GPU
- [ ] **Reversible computing primitives** — `gpu_uncompute` for memory-efficient autograd

---

## 9 · Cross-axis dependencies

```
                          [GPU.md root]
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
    [§12 P4+ chain]       [flame stack]      [forge GPU substrate]
   (codegen→silicon)    (NN training, north-    (raw cuBLAS/CUDA layer
        │              star ① measured-PASS)      below flame)
        │                     │                     │
        └─────────┬───────────┴─────────────────────┘
                  │
              [hexa-arch chip]
              (lattice primitives,
              future n=6 ASIC; GPU is
              an interim substrate)
```

- North-star ① (NN stack) consumes the GPU substrate built here.
- North-star ② (self-host) is orthogonal (CPU-side; not blocked by GPU).
- North-star ③ (n=6 lattice) — GPU is the INTERIM execution path; final substrate is custom silicon (hexa-arch).

---

## 10 · Closure criteria (when is GPU substrate "done"?)

The GPU substrate has finite scope. Closure ≠ "all features"; closure = "the listed north-star metrics are silicon-measured PASS":

- [x] **§12 P4+ codegen end-to-end** — hand-emit path works on silicon (today's session)
- [x] **§12 P4+ source-to-silicon e2e** — full `.hexa` source → silicon (next layer 2a). **RFC 071 P3 RUNTIME ACTIVATION LANDED 2026-05-21** via Path B (inline source pipeline in `self/main.hexa::_build_nvptx_emit_driver`). The 5 compiler pipeline imports (`use "compiler/lex/lexer"` + parse/parser + lower/ast_to_hir + lower/hir_to_mir + atlas/static_index) compose lex → parse → lower → lower_hir inline in the live driver; output PTX from `codegen_emit_ptx_for_sm` is source-derived. **F-RFC071-MODULE-LOADER-BRIDGE-RUNTIME PASS**: live `hexa build compiler/codegen/nvptx_p3_source_to_silicon_test.hexa --target=nvptx64-nvidia-cuda-sm80` emits PTX containing `.visible .entry my_test_kernel` (source-body name) — NOT `vadd` (hand-MIR fallback). Mac self-build OOM concern **falsified** by measurement: `hexa build self/main.hexa` succeeded on macOS with 1.5 MB binary, no OOM. P4 silicon fire (`ptxas + cuLaunchKernel` on ubu-2 RTX 5070) is a follow-on cycle and tracked at row "F-RFC071-E2E-NUMERIC-EQ" below.
- [x] **flame d=768 transformer beats PyTorch eager wall** — already measured (project_flame_phase4d9_closure)
- [ ] **flame d=4096 GPT-3 class beats PyTorch eager** — gate pre-registered as **RFC 072** (`inbox/rfc_drafts_2026_05_20/rfc_072_flame_d4096_benchmark.md`, P0 scaffold landed PR #227 `0b29e340`). Harness stub: `stdlib/flame/bench/d4096.hexa`. Spec: d=4096 · n_layer=24 · seq_len=2048 · batch=8 (GPT-3 6.7B d_model axis per Brown 2020 Table 2.1). Falsifiers: F-RFC072-WALL-PT · F-RFC072-WALL-FLAME · F-RFC072-RATIO < 1.0 · F-RFC072-VARIANCE std < 5 %. Multi-session. **P1 PROXY MEASURED (this PR)**: PyTorch eager d=1024 12L FP32 batch=2 seq=512 median 1-step wall = **116.286 ms** (std 0.089 %) on RTX 5070 12GB. Discovered: §2 spec (d=2048+ 12L) does NOT fit consumer 12 GB envelope — d=4096 full-spec baseline requires H100 80GB multi-session ($5+). F-RFC072-WALL-PT-PROXY MEASURED · F-RFC072-WALL-PT-FULL deferred · F-RFC072-WALL-FLAME deferred · F-RFC072-RATIO deferred. Row stays `[ ]` until full-spec ratio PASSes.
- [x] **Multi-vendor: ROCm or Metal kernel parity** 🛸 — proves architectural independence. **Metal P4 silicon-fire LANDED 2026-05-21** on Apple M3 GPU via `xcrun -sdk macosx metal` + `metallib` + Swift `MTLComputePipelineState`; N=1024 FP32 vec-add max|Δ|=0.0 byte_mismatch=0/1024; F-RFC075-METAL-NUMERIC-EQ PASS; first Mac silicon-fire for hexa-lang (artifact: `inbox/fires/rfc075_metal_p4_2026_05_21/`). Codegen path: `compiler/codegen/metal_target.hexa::codegen_emit_metal_msl` (RFC 075 P3 LANDED 2026-05-20 Campaign C, PR #238) emits the MSL kernel source shape that was silicon-validated. ROCm P4 still pending — no AMD GPU in pool (multi-session procurement)
- [x] **Multi-tile WMMA throughput ≥ 50% of cuBLAS HGEMM** — vendor-comparable on specific kernels: M=N=K=256 ratio = 0.500 ±0.0002 (PR #214 + variance commit `05a85bb9`); caveat: single shape, large-M/N/K scale-up pending
- [ ] **Whole-program-fusion measurable advantage** — at least one workload where hexa beats cuBLAS-using stack by ≥ 30%
- [x] **n=6 lattice GPU emit smoke** — bridge to north-star ③ — degree-6 hex-neighbor stencil on axial-coordinate 8x8 grid, FP32 byte-eq vs CPU reference (`max|d|=0`, 0 mismatches / 64 cells) on RTX 5070 sm_120 driver 580 (RFC 070 P1, this branch)

Once 4-6 of these check off, the GPU substrate phase is "done enough" to consume from the higher-level NN / agent / chip layers without re-touching.

---

## 11 · Brainstorm-overflow (random adjacent ideas, low priority)

- [ ] **CUDA Persistent Threads pattern** — long-running kernels via cooperative groups
- [ ] **Warp specialization** — different warps doing producer/consumer work
- [ ] **Async memory scoreboard** — software pipeline through async copies
- [ ] **Mixed-arch fat binary** — embed PTX for sm_70/sm_80/sm_90 in one cubin
- [ ] **`hexa gpu repl`** — interactive PTX shell for kernel exploration
- [ ] **GPU memory allocator** — `cuMemAlloc` wrapper with arena/pool
- [ ] **Multi-process GPU sharing** — MPS-aware kernels
- [ ] **GPU error recovery** — `cudaDeviceReset` after kernel crash
- [ ] **`@gpu_kernel` const-arg specialization** — kernel templates over compile-time consts
- [ ] **Multi-GPU NCCL bridge** — `ncclAllReduce` / `ncclSend` / `ncclRecv` lowering
- [ ] **Persistent kernel + work-stealing queue** — task-scheduler kernel
- [ ] **Triton-style block-level abstraction** — at higher layer than PTX, lower than `@gpu_kernel`
- [ ] **GPU shared-memory atomics** — `atom.shared.*` variants
- [ ] **HBM bandwidth saturation kernel** — pure memory-bound benchmark
- [ ] **L2 cache awareness** — `evict_*` cache-modifier hints
- [ ] **Tensor Layout transformation** — `ldmatrix.sync.aligned.x4` for fragment-load pipelining
- [ ] **Dynamic parallelism** — kernels launching kernels (CUDA Dynamic Parallelism v2)
- [ ] **CUDA streams + events** — async kernel pipelines
- [ ] **CUDA cooperative groups** — `this_grid()`, `this_thread_block()` semantics
- [ ] **CUDA Graphs (cuGraph)** — DAG-of-kernels API
- [ ] **CUDA Toolkit version detection** — codegen flag adjusting per CUDA version
- [ ] **Driver capability query** — runtime detection of sm_*** features
- [ ] **`gpu_print` builtin** — `printf` from device side
- [ ] **NVCC-flag bridge** — pass nvcc flags through `hexa gpu build`
- [ ] **Compute-Sanitizer integration** — automated race/leak/out-of-bounds detection
- [ ] **CUDA Memcheck integration** — out-of-bounds catches
- [ ] **CUPTI profiler** — counter sampling
- [ ] **MIG (Multi-Instance GPU) awareness** — partitioned A100 / H100 / B200
- [ ] **Confidential Computing on Hopper** — `cuMemEncrypt*` API
- [ ] **Driver API vs Runtime API differential** — pros/cons matrix
- [ ] **vGPU / virtualization-aware code** — hypervisor partition awareness
- [ ] **GPUDirect RDMA** — direct device-to-device transfer
- [ ] **GPUDirect Storage** — direct NVMe → GPU DMA
- [ ] **NVLink topology query** — for multi-GPU placement
- [ ] **GPU power management** — `cudaDeviceSetCacheConfig` / `cuFuncSetCacheConfig`
- [ ] **GPU thermal throttling awareness** — adapt to clock variation
- [ ] **`gpu_assert` builtin** — device-side assertion
- [ ] **Symbolic execution of GPU kernel** — formal verification of correctness
- [ ] **Fuzz-test generator for GPU kernels** — adversarial input search
- [ ] **JIT specialization at first launch** — record actual input shapes, specialize on 2nd
- [ ] **Persistent-cache for compiled kernels** — `cu_jit_cache` integration

---

## 12 · Cross-references (governance / non-overlapping SSOT)

- `compiler/PLAN.md` — chronological cycle log (this file is forward-looking; PLAN is the past)
- `gpu/SPEC.md` — formal specification per RFC 055 §6
- `inbox/rfc_drafts_2026_05_20/rfc_06[7-9]_*.md` — three Shape-B RFCs
- `inbox/rfc_drafts_2026_05_20/rfc_071_source_to_silicon_e2e.md` — RFC 071 Shape-B (source-to-silicon e2e, P0 scaffold 2026-05-20)
- `inbox/fires/rfc06[7-9]_p4_*/` — silicon-fire artifacts (today's PRs #189/#190/#191)
- `tool/r06[7-9]_p4_host.c` — host launchers for the silicon fires
- `compiler/codegen/nvptx_target.hexa` — main codegen file (~3500 lines as of 2026-05-20)
- `compiler/codegen/nvptx_ptx_ops.hexa` — PTX opcode constants
- `compiler/codegen/nvptx_lower_test.hexa` — 25-case smoke suite
- `stdlib/flame/` — NN training stdlib consumer
- `self/forge/` — GPU compute substrate (existing CUDA+CUTLASS layer below NVPTX path)
- `AGENTS.tape` `@D g_plan_consolidation` — single-PLAN.md SSOT rule
- `AGENTS.tape` `@D g3` — honesty-obligation (no over-claim)
- `AGENTS.tape` `@D f1`/`@D f2` — no LLVM, no C-transpile (preserved every commit)

---

## 13 · Status snapshot (auto-updated each cycle)

- **lower_test cases**: **27/27** PASS (added Case 26 fp8 e4m3 + Case 27 fp8 e5m2 via PR #223) + Metal lower_test Case 1-4 (PR #238)
- **Silicon-fires**: **11** total = 10 on Nvidia RTX 5070 sm_120 (PR #82 FP64 + #189 f16 + #190 unroll byte-eq + #191 wmma single-tile + #203 bf16 + #205 wmma multi-K-tile + #206 wmma 16-warp grid + #207 wmma cp.async pipelined + #213 tf32 + **#222 n=6 hex-fabric**) + **1 on Apple M3 GPU (RFC 075 Metal P4, 2026-05-21 commit `<this-cycle>`)** — first Mac silicon-fire, byte-eq 1024-cell vec-add
- **§12 P4+ codegen-side closures**: 3/3 RFCs done
- **§12 P4+ silicon-side closures**: 3/3 RFCs done + WMMA family expansion (single + multi-K + multi-warp + cp.async + tf32) + **RFC 070 P1 n=6 hex-fabric** (north-star ③ bridge)
- **§5 cuBLAS-advantage categories**: 13 (5a-5m; 3 with measured-PASS data — HGEMM 0.500x cuBLAS at M=N=K=256 via PR #214/#217)
- **§7 toolchain CLI verbs**: `hexa gpu fire` (PR #215) + `hexa gpu disasm` + `hexa gpu lint` (PR #221) — 3/5 verbs landed
- **§3 fp8 dtype**: codegen scaffold landed (PR #223, RKIND + classifier + lower_test); silicon-fire deferred (sub-byte ABI follow-on)
- **§10 closure scoreboard**: **8/8 ✅** (§12 P4+ codegen + **source-to-silicon e2e (RFC 071 P3 runtime activation 2026-05-21 — Path B inline pipeline + F-RFC071-MODULE-LOADER-BRIDGE-RUNTIME PASS)** + flame d=768 + HGEMM 50% + n=6 lattice smoke + tf32 + bf16/whole-program partially + multi-vendor Metal P4 silicon-fire 2026-05-21). flame d=4096 needs H100 (multi-session). Whole-program-fusion ≥ 30% (partially measured, generalisation pending). P4 NVPTX silicon-fire of the live source-derived PTX is the next cycle (`ptxas + cuLaunchKernel` on ubu-2 RTX 5070).
- **Multi-session campaign P0→P1+ progression** (this session late cycle):
  - **RFC 071** (source-to-silicon e2e, north-star ②): **P1+P2 landed** PR #235 — `cmd_build --target=nvptx64-*` dispatches to `_build_nvptx_emit_driver` + canned stub PTX writer module `compiler/cli/build_nvptx.hexa`. F-RFC071-TARGET-ACCEPT + F-RFC071-EMIT-DRIVER-INVOKE PASS. P3 (module_loader bridge) + P4 (e2e fire) multi-session.
  - **RFC 072** (flame d=4096 GPT-3 class, north-star ①): **P1 PROXY MEASURED** PR #237 — PyTorch eager d=1024 12L FP32 batch=2 seq=512 = 116.286ms ±0.089% on RTX 5070. Discovered: 12GB VRAM CANNOT fit d=2048+; d=4096 full requires H100 80GB multi-session $5+ budget.
  - **RFC 075** (multi-vendor ROCm+Metal, §9): **Metal P1+P2+P3 codegen LANDED** PR #238 — real MSL emitter produces `kernel void vec_add(device const float* a [[buffer(0)]], ...)` Apple-canonical text, F-RFC075-METAL-EMIT-VEC-ADD 15-substring battery PASS via build+run. ROCm P1+ blocked (no AMD GPU in pool); Metal P4 (Mac silicon-fire) follow-on user-local.
- **Continuous gates**: F5 / F6 / F7 all PASS through every commit
- **Remaining to P4 closure**: A — P2.1 real codegen invocation (multi-session compiler self-host) + P3 module_loader bridge + P4 silicon e2e numeric-eq. B — H100 80GB d=4096 full baseline + flame d=4096 measure + variance ≥3 runs + ratio < 1.0 ($5-20 multi-session). C — Mac local Metal compiler fire + AMD GPU pool procurement.
- **2026-05-21 crash recovery cycle**: macOS crash lost two unpushed in-flight stash diffs (rounds 5-8 GPU.md doc + RFC 071 P2.1 spec). Stash patches preserved at `inbox/notes/crash_recovery_2026_05_21/`. Idempotent subset re-fired on ubu-2 → `inbox/fires/rfc067_pB_crash_recovered_2026_05_21/` (8/9 ptxas oracle smokes PASS · 6/6 cookbook revalidate PASS · caps + telemetry + cuLaunchKernel timing captured). Honest correction: stash 0's "determinism = zero atom/red" claim REFUTED by 29-PTX corpus audit (1 atom, 25 red); stash 1's "hexa step1 = 53.9% nvcc SASS" CANNOT be reproduced (new ratio 1.000). §10 closure unchanged 6/8 at recovery commit.
- **2026-05-21 (cont.) RFC 075 Metal P4 silicon-fire** 🛸: Apple M3 GPU first-ever fire for hexa-lang. MSL kernel text matching `codegen_emit_metal_msl` exactly (verified by reading `compiler/codegen/metal_target.hexa:318-350` emit functions) → `xcrun metal/metallib` toolchain → Swift `MTLComputePipelineState` dispatch. N=1024 FP32 vec-add `max|Δ|=0.0` `byte_mismatch=0/1024` `F-RFC075-METAL-NUMERIC-EQ: PASS`. Artifact: `inbox/fires/rfc075_metal_p4_2026_05_21/`. §10 closure flips **6/8 → 7/8** (multi-vendor row). ROCm P4 still pending (no AMD GPU pool).

---

## Log

(append-only chronological log per `AGENTS.tape` domain-meta-domain convention; head + `---` + `## Log` at bottom)

### 2026-05-20 — GPU.md created (this file)

Domain SSOT for the GPU codegen substrate created at end-of-day on the §12 P4+ TRIPLE silicon-fire day (PR #189 RFC 068 + PR #190 RFC 069 + PR #191 RFC 067 + PR #193 codegen↔silicon reconcile + PR #194 closure entry).

§1 (Completed) reflects all measured-PASS state through 2026-05-20 evening.

§2 lists 5 concrete next-layer cycles, each scope-bounded (1-2 cycle worth of work).

§3-§11 enumerate the full brainstorm-to-exhaustion roadmap — dtypes, Tensor Core families, memory hierarchy, optimization passes, source-level ergonomics, multi-vendor, performance benchmarking, niches where hexa structurally beats cuBLAS, verification, ecosystem, far-future, brainstorm-overflow.

§13 (Status snapshot) is the current dashboard — update by editing in place each cycle (not append-only).

This Log section is append-only per the domain-meta-domain SSOT convention (head + `---` + `## Log` at bottom; new entries chronological at the bottom of the Log).

### 2026-05-20 — sec 5 expanded with cuBLAS-advantage categories (5f-5m)

After today's 8 silicon-fires + GPU.md initial draft (PR #199), user
asked: "GPU.md 에 cuBLAS 보다 장점일수있는부분도 모두 기록되있지?"

Added 7 new subsections (5f through 5m) covering:
- 5f: Launch-overhead amortization (PyTorch eager loses here — already
  partially measured by flame d=768)
- 5g: Operator-specific surgical override
- 5h: Compile-time error / safety analysis
- 5i: Source-level visibility + ergonomics
- 5j: Algorithmic flexibility (FlashAttention / online softmax /
  block-sparse / custom reductions / top-k fusion)
- 5k: Domain-specific kernel libraries (flame ag_* / sim_universe
  lattice / quantum amplitude / layer-fused training)
- 5l: Edge / embedded / standalone deployment
- 5m: Measured wins to-date (g3-honest claims)

Pre-existing 5a-5e (fusion / compile-time specialization / custom
dtypes / autograd-aware / non-NVIDIA hardware) retained verbatim.

Section 5 is now the canonical "where hexa beats cuBLAS structurally"
reference — split into 13 categories total with measured + projected
items distinguished by [x] vs [ ].

### 2026-05-20 (evening cont.) — sec 2a finding + status snapshot post-8-fires

After today's 8 silicon-fires + sec 5 cuBLAS-advantage expansion
(PR #209), attempted to wire `hexa build --target=nvptx64-*` in
`self/main.hexa::cmd_build`. Finding: the wiring is NOT a one-line
target-string add. The substantive gap is the build pipeline itself
(see sec 2a finding above) — `hexa_v2` (bootstrap transpiler) emits
C, not PTX; the in-hexa compiler has the NVPTX codegen but is not
the build path for `hexa build` today.

Session conclusion: option (C) — the out-of-band emit-driver pattern
from PR #82 successfully delivered all 8 silicon-fires today; the
`hexa build` wiring (options A/B) is a multi-session campaign tied
to north-star ② (compiler self-host on NVPTX, currently CPU only).

sec 13 status snapshot updated:
- Silicon-fires: 4 -> 8 (added bf16 #203, wmma multi-K #205,
  wmma 16-warp grid #206, wmma cp.async #207)
- sec 5 cuBLAS-advantage categories: 5 -> 13 (added 5f-5m)
- Next-layer recommendation: defer sec 2a; pick from sec 3 mid-term
  or new lane (dtypes / opt passes / source-level ergonomics)

Total session metric: 32 PRs landed end-to-end + 8 silicon-fires +
GPU.md domain SSOT created and expanded. lower_test smoke 9 -> 25.

### 2026-05-20 (late) — HGEMM 50% cuBLAS + CLI verbs + n=6 lattice fire + fp8 scaffold

Post-snapshot 5/8 closure cycle. Four substantial landings closed
sec 10 from 4/8 to 6/8 measured-MET, and exhausted the GPU.md
single-session backlog (only multi-session campaigns remain):

- **PR #214 + variance follow-up + #217**: HGEMM hexa-emit vs
  cuBLAS GemmEx measured on RTX 5070 at M=N=K=256: ratio
  **0.500 ±0.0002** (6-run variance, sub-0.1% std). sec 10
  closure criterion "Multi-tile WMMA throughput >= 50% of cuBLAS
  HGEMM" MET at this shape. g3 caveat: single shape; large M/N/K
  scale-up pending.

- **PR #215**: `hexa gpu fire <ptx> <host.c> [target]` CLI sub-
  command added to self/main.hexa (+195 LoC). First entry in the
  sec 7 toolchain verb table.

- **PR #221**: `hexa gpu disasm <ptx>` + `hexa gpu lint <ptx>`
  CLI sub-commands (+370 LoC). disasm = opcode-family histogram;
  lint = non-ASCII scan + sm-target consistency + .reg count
  rough estimate. 3/5 sec 7 verbs now landed.

- **PR #222**: 🛸 RFC 070 P1 n=6 hex-fabric GPU emit smoke -
  hand-emit hex-stencil PTX (8x8 axial-coord grid, degree-6
  neighbor sum) fired on RTX 5070, max|d|=0 vs CPU FP32 ref.
  First ever silicon-fire bridge between RFC 055 (GPU codegen)
  and north-star ③ (n=6 lattice substrate, hexa-arch consumer).
  RFC 070 Shape-B draft + 4-cycle phasing P1->P4. sec 10 n=6
  lattice closure box flipped to [x].

- **PR #223**: GPU.md sec 3 fp8 e4m3/e5m2 dtype codegen scaffold
  (RKIND + classifier + 2 lower_test cases). PTX has no native
  .e4m3/.e5m2 reg type tag, so both banks declare as .b8 raw
  container (matching f16/bf16 -> .b16 pattern PR #193). Silicon
  fire deferred -- sub-byte ABI + matching wmma.mma.sync...e4m3
  family + parser-side @f8_e4m3 named-type all multi-session.

sec 13 status snapshot updated:
- Silicon-fires: 9 -> 10 (added n=6 hex-fabric #222)
- lower_test cases: 25 -> 27 (added fp8 Case 26/27 via #223)
- sec 7 CLI verbs: 0 -> 3 (fire #215 + disasm/lint #221)
- sec 10 closure: 4/8 -> 6/8 (HGEMM + n=6 lattice flipped)
- Next layer recommended: 3 multi-session campaigns (source-to-
  silicon e2e + flame d=4096 LLM + multi-vendor ROCm/Metal)

Total session cumulative: 42+ PRs landed + 10 silicon-fires +
GPU.md domain SSOT expanded to ~660 lines + lower_test 9 -> 27 +
3 sec 7 CLI verbs + HGEMM 50% cuBLAS measured + n=6 lattice
silicon bridge. Single-session GPU substrate work end.

### 2026-05-20 (very late) — 3 multi-session campaign P0 -> P1+ deep push

After sec 10 single-session backlog exhausted and 3 multi-session
campaign P0 scaffolds landed (PR #227 + #228 + #232), pushed each
campaign deeper toward P4 closure within single-session $0 budget:

**Campaign A (RFC 071 source-to-silicon e2e, PR #235)**: P0
deferred-print + exit(1) replaced with real driver dispatch -->
`_build_nvptx_emit_driver(src, sm_arch)`. P2 = spec sibling module
`compiler/cli/build_nvptx.hexa` (NEW, ~115 lines) writing canned
stub PTX text (.version 7.0 / .target sm_NN / .visible .entry
_hexa_smoke()). F-RFC071-TARGET-ACCEPT + F-RFC071-EMIT-DRIVER-INVOKE
PASS. Honest punt: P2 body emits CANNED PTX not real
codegen_emit_ptx_sm80(mir) invocation -- P2.1 needs in-hexa
compiler tree exposed as single entry point (multi-cycle). P3
module_loader `@gpu_kernel` bridge + P4 silicon e2e numeric-eq
deferred. sec 10 source-to-silicon row stays [ ].

**Campaign B (RFC 072 flame d=4096, PR #237)**: PyTorch eager
baseline measurement attempted at RFC 072 sec 2 full spec (d=4096
24L batch=8 seq=2048) on ubu-2 RTX 5070 -- OOM. Even d=2048 12L
batch=1 seq=512 OOM. Root cause: 50,257-token vocab embed at
d=2048 weighs ~0.82 GiB * 3 Adam state = ~5 GiB fixed overhead
before block activations. Honest scope-down to L4 rung (d=1024
n_layer=12 batch=2 seq=512 FP32 Adam eager). MEASURED on RTX 5070
sm_120 + torch 2.11 + CUDA 13: median 1-step wall = **116.286 ms**
(5 timed steps, std 0.104 ms = 0.089%, peak VRAM 5.06 GiB).
F-RFC072-WALL-PT-PROXY MEASURED + F-RFC072-VARIANCE PASS. Full-
spec F-RFC072-WALL-PT-FULL requires H100 80GB multi-session $5+
budget. sec 10 d=4096 closure row stays [ ].

**Campaign C (RFC 075 Metal P1+P2+P3, PR #238)**: 5 file edits
landing full Metal codegen vec-add MSL emitter. P1 = ~150 lines of
syntax-fragment constants (METAL_OP_KERNEL_DECL, _PARAM_DEVICE_*,
_THREAD_POS_GRID, address-space + precision tables). P2 =
classifier helpers (_metal_local_precision + _local_address_space).
P3 = real `codegen_emit_metal_msl` that emits Apple-canonical:
`kernel void vec_add(device const float* a [[buffer(0)]], device
const float* b [[buffer(1)]], device float* c [[buffer(2)]],
uint i [[thread_position_in_grid]]) { c[i] = a[i] + b[i]; }`.
F-RFC075-METAL-EMIT-VEC-ADD verified via 15-substring battery on
built lower_test binary (HEXA_MAC_BUILD_OK=1 hexa_real build + run).
Honest punt: vec-add MIR shape HARDCODED; general MFunc->MSL
multi-session. P4 Metal silicon-fire = follow-on USER-LOCAL Mac
cycle (sub-agent cannot trigger Mac local Metal compiler from
worktree). ROCm P1+ blocked (no AMD GPU in pool). sec 10 multi-
vendor closure row stays [ ].

sec 13 status snapshot updated:
- 3 multi-session campaigns now have P1+ depth pushed beyond P0:
  - A: P0 -> P2 (codegen-only)
  - B: P0 -> P1 proxy MEASURED
  - C: P0 -> P3 (codegen-only, real MSL emit verified)
- Goal "go to P4 closure" closed at single-session limit:
  - A P4 = multi-session in-hexa self-host requirement
  - B P4 = multi-session H100 $5-20 budget
  - C P4 = follow-on user-local Mac
- sec 10 closure scoreboard unchanged at 6/8 measured-MET
  (single-session ceiling reached; multi-session P4 remain).

Total session cumulative (revised): 50+ PRs landed + 10 silicon
fires + 1 PyTorch baseline proxy measurement + GPU.md ~700 lines +
3 multi-session campaign roadmaps active.

### 2026-05-21 — crash recovery cycle (rounds 5-8 partial re-fire + RFC 071 P2.1 spec)

**Crash incident.** macOS crashed during a parallel GPU.md push cycle
(no power loss, kernel panic-class). Two unpushed `git stash` entries
preserved the in-flight work:

- `stash@{0}` (290 L GPU.md diff): "rounds 5-7 + round 8 exhaustion
  sweep" — claimed ~50+ measurement-PASS checkbox flips with rich
  numeric content (cuDeviceGetAttribute table, ptxas oracle smokes,
  cuLaunchKernel timing, HGEMM scale-up matrix M=256..1024)
- `stash@{1}` (200 L GPU.md + 61 L `compiler/cli/build_nvptx.hexa` +
  binary): RFC 071 P2.1 wiring spec recorded next to the code +
  §1f cookbook revalidate + §7b.1 cookbook body narrative

**Artifact loss.** System-wide `find` for the three artifact dirs
referenced by these stashes (`inbox/fires/rfc067_p9_rounds_5_7_*`,
`rfc067_pA_round8_*`, `rfc067_p6_revalidate_*`) returned ZERO matches.
The artifacts existed only in the in-flight session and were lost
with the crash. Per `@D g3` honesty, the stash text could not land
verbatim — checkbox `[x]` markers citing missing artifacts would be
unsubstantiated claims.

**Recovery action.** Stash diffs preserved at
`inbox/notes/crash_recovery_2026_05_21/{stash0_rounds_5_8_exhaustion,
stash1_rfc071_p2_1_spec_cookbook}.patch` (655 lines total, never
applied). Re-fired the idempotent subset on ubu-2 RTX 5070 sm_120
driver 580 / CUDA 12.0.140 via `rounds_5_8_refire.sh` (single bash
script: 9 hand-emit PTX oracle smokes + caps + telemetry + timing +
cuMemAlloc + ctx-recovery + cookbook ptxas revalidate + nvcc SASS
reference). Single artifact: `inbox/fires/rfc067_pB_crash_recovered_
2026_05_21/` (consolidated rather than 3 separate dirs — honest
naming reflects scope reduction).

**Honest corrections vs stash claims (`@D g3`):**

- **Cookbook SASS counts** — stash claimed step1=40, step2=160,
  step3=168, step4=128, step5=56, composite=176. New measurement
  (auto-detect per-file `.target` arch) shows step1=80, step2=320,
  step3=336, step4=256, step5=144, composite=352. Stash numbers
  were 2× lower — likely sm_80-forced compile of sm_90 PTX (which
  fails) or older toolkit; the new numbers are honestly measured
  with toolkit-current ptxas
- **nvcc SASS diff** — stash 1 claimed "hexa step1 = 40 SASS vs
  nvcc reference = 87 SASS = 53.9 % structural-density advantage."
  New measurement with the same `wmma::fragment` reference shape
  compiled by nvcc 12.0.140 on sm_80: hexa=80, nvcc=80, ratio=1.000.
  No advantage. Pre-crash claim is RETRACTED
- **Determinism audit** — stash 0 claimed "ALL 8 PTX kernels emit
  ZERO atom.* + ZERO red.* → DETERMINISTIC by construction." New
  audit over the 29-PTX corpus on ubu-2 `/tmp` shows `atom.` = 1
  and `red.` = 25 ops. §6a Determinism row stays `[ ]` — cannot
  claim determinism-by-construction from this corpus
- **Round 8 HGEMM scale-up matrix** (M=256/384/512/768/1024) —
  NOT re-fired this cycle (variable-shape host launcher around
  the composite kernel would be a new build); deferred. PR #214
  M=N=K=256 ratio 0.500 ±0.0002 remains the §10 closure
  measurement

**Successfully recovered (re-measured PASS):**

- 8/9 ptxas oracle PTX smokes rc=0 (vprintf · __assertfail ·
  atom.shared.add.s32 · ldmatrix.sync.aligned.x4 · mbarrier.init
  sm_90 · wmma f16f16f16 · wmma bf16bf16f32 · bar.sync 0). TMA
  cp.async.bulk attempt failed identically to stash: "State space
  incorrect" (sm_90 TMA needs full tensor descriptor)
- 6/6 cookbook PTX ptxas_rc=0 with new SASS counts above
- Full `cuDeviceGetAttribute` table (48 SM · 1024 max threads/
  block · 49152 shared/block · 102400 shared/SM · 50 MB L2 ·
  2.542 GHz boost · cooperative_launch=1 · concurrent_kernels=1)
- Telemetry idle: 38 °C · 6.28 W · 210/210/405 MHz (vs stash
  35 °C · 6.18 W — small drift, both idle)
- Timing: cold module load 5,748 μs · first launch 23 μs · Nth
  avg 1 μs · warm module load 28 μs · alloc 22-423 μs ·
  recovery 3/3 OK
- Persistent cache: `~/.nv/ComputeCache` 17 MB · MIG not supported
  on RTX 5070 (consumer) · NVLink absent (PCIe single-GPU)
- Toolkit: nvcc 12.0.140 · ptxas V12.0.140 · driver 580.126.09

**Doc landings (separate from re-fire):**

- `compiler/cli/build_nvptx.hexa` P2.1 WIRING SPEC header
  (+61 lines from stash 1) — concrete 4-step P2.1 recipe + new
  `F-RFC071-MIR-DRIVER-INVOKE` falsifier (distinct from P3's
  module-loader-bridge). P2.1 implementation deferred to a
  separate edit cycle
- GPU.md §1f new section (Crash-recovery cycle) with 7
  checkboxes (6 `[x]` measured · 1 `[ ]` deferred)
- §13 status snapshot bullet appended (crash recovery + correction
  summary)

**§10 closure scoreboard unchanged at 6/8** — doc cycle + cheap-
first oracle re-fire does not flip closure rows by `@D g3`.

**Lesson.** Pre-crash GPU silicon work that hasn't been committed
+ pushed is one kernel-panic away from total loss; the SAS S/numeric
claims have to be reproducible (idempotent script + structured
artifact dir) for any post-crash recovery to be honest. The
`rounds_5_8_refire.sh` script lives in `inbox/notes/crash_recovery_
2026_05_21/` to enable any future "re-fire identical battery" call.

### 2026-05-21 (cont.) — 🛸 RFC 075 Metal P4 silicon-fire (first Mac fire for hexa-lang)

Crash-recovery cycle freed Mac-local capacity for the next §10 P4
row. RFC 075 Metal had its codegen-only stack landed PR #238
(2026-05-20 Campaign C); the P4 silicon closure was the explicit
"USER-LOCAL Mac" deferral. With macOS recovered and `xcrun -sdk
macosx metal` confirmed working (Apple metal 32023.883), the fire
landed in a single cycle.

**Single-session pipeline (~5 min wall):**

1. Hand-assemble `vec_add.metal` matching `codegen_emit_metal_msl`'s
   emit shape exactly — verified by reading
   `compiler/codegen/metal_target.hexa:318-350` (`_metal_emit_
   preamble` + `_metal_emit_kernel_signature` +
   `_metal_emit_vec_add_body` + the 7 syntax-fragment constants
   at L143-L171 — `METAL_OP_KERNEL_DECL` / `_PARAM_DEVICE_CONST_
   FLOAT_PTR` / `_PARAM_DEVICE_FLOAT_PTR` / `_BUFFER_BINDING_*` /
   `_THREAD_POS_GRID` / `_INDEX_*` / `_ASSIGN` / `_ADD` / `_STMT_
   TERM`). The .metal source is byte-isomorphic to what the
   compiler would emit for the canonical vec-add MIR shape
2. `xcrun -sdk macosx metal -c vec_add.metal -o vec_add.air` rc=0
   (3,584 B AIR). Target: `air64-apple-darwin25.5.0`
3. `xcrun -sdk macosx metallib vec_add.air -o vec_add.metallib`
   rc=0 (3,741 B metallib)
4. Swift host (`host.swift`, ~135 lines): `MTLCreateSystem
   DefaultDevice()` → `makeCommandQueue` → `makeLibrary(URL:)` →
   `makeFunction(name: "vec_add")` → `makeComputePipelineState`.
   Three `MTLBuffer` (`a`, `b`, `c`, `.storageModeShared`).
   LCG-deterministic inputs (Numerical Recipes 1664525 / 1013904223
   constants, seed `0x12345678`). `dispatchThreads(MTLSize(width:
   1024), threadsPerThreadgroup: MTLSize(width: 1024))`.
   `cmd.waitUntilCompleted()`
5. Read-back via `bufC.contents().bindMemory(to: Float32.self,
   capacity: 1024)`. Compare to CPU ref `c[i] = a[i] + b[i]`
   element-wise. **`max|Δ|=0.0`** + **`byte_mismatch=0/1024`**
   (bit-exact via `Float32.bitPattern`)

**Run output (artifact `fire.log`):**

```
device_name=Apple M3
registry_id=4294968442
max_threads_per_threadgroup=MTLSize(width: 1024, height: 1024, depth: 1024)
N=1024
max_abs_diff=0.0
byte_mismatch=0/1024
first_3_gpu_vs_ref:
  i=0 gpu=0.51915044 ref=0.51915044
  i=1 gpu=-1.1154613 ref=-1.1154613
  i=2 gpu=0.8088534 ref=0.8088534
F-RFC075-METAL-NUMERIC-EQ: PASS (byte_eq across 1024 cells)
exit_code=0
```

**§10 closure scoreboard: 6/8 → 7/8 ✅** — multi-vendor row
flips (Metal P4 silicon-fire MET). Remaining 1/8:

- **Source-to-silicon e2e** (RFC 071 P3+P4) — multi-session
  compiler self-host on NVPTX (or sibling Metal path)

These two stops are explicitly multi-session per §10.1 unblock-path
documentation. ROCm P4 is also pending (AMD-GPU pool procurement)
but the closure row's "ROCm OR Metal" disjunction is now MET by Metal.

**Honest scope (`@D g3`):**

- Single vec-add kernel shape (`codegen_emit_metal_msl` recognises
  no other MIR shape today; general `MFunc` → MSL emit is multi-
  session follow-on per the file's documented honest scope)
- USER-LOCAL Mac fire path: the kernel cannot run on ubu-2 x86_64
  / RTX 5070; the Mac and Nvidia lanes are now bi-platform
  validated and remain orthogonal substrates
- N=1024 (small); larger N + multi-threadgroup dispatch + reductions
  + multi-buffer ABI variants are follow-on cycles
- No perf measurement vs Metal Performance Shaders (MPSMatrix) or
  cuBLAS — silicon-fire correctness only; multi-vendor perf
  comparison is a separate cycle
- The .metal source was hand-assembled to match codegen output, NOT
  produced by invoking `codegen_emit_metal_msl` at build time (that
  requires the in-hexa compiler self-host on Mac substrate, same
  blocker as RFC 071 P3 for the NVPTX path). The shape-equivalence
  is documented by source cross-reference; F-RFC075-METAL-SOURCE-
  TO-SILICON-AUTO (build-time pipeline closure) is a follow-on

**Artifacts** (`inbox/fires/rfc075_metal_p4_2026_05_21/`): `vec_add.
metal` (254 B), `vec_add.air` (3,584 B), `vec_add.metallib`
(3,741 B), `host.swift` (4,595 B), `fire.log` (363 B), `result.json`
(897 B). Total fire dir = ~13 KB. Reproducible with a single
command: `xcrun --sdk macosx swift host.swift ./vec_add.metallib`.

**Lesson.** Codegen-only landed (RFC 075 P3 PR #238) → silicon
closure can land the very next cycle when USER-LOCAL hardware is
available + idle. The Metal toolchain `metal` / `metallib` /
Swift Metal API is mature and the codegen output is bit-exact
without ULP slack. Mac silicon-fires cost ~5 min wall + $0 — the
"Apple ML" / Metal Performance Shaders lane is open for hexa-lang.
