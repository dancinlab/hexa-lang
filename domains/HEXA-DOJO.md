# HEXA-DOJO — current state

@title: 🥋 HEXA-DOJO — GPU practice/recipe surface (build-trap absorption + kernel-authoring katas)

@goal: the hexa dojo (docs/hexa-dojo.md + tool/dojo_rent_preflight.sh + HEXA-CUDA.md) is the SINGLE practice surface that ABSORBS every known forge-CUDA build-trap + GPU-kernel-authoring lesson, so the next build/practice never re-hits a wall already paid for. **Scope honesty (g5)**: the dojo cures LAYER-A (build/toolchain traps — fixable, doc + codegen) — it does NOT cure LAYER-B (the serial kernel-DAG util ceiling, a codegen/fusion problem owned by [[HEXA-FUSION]], measured-FALSIFIED for graph-capture). dojo = recipe book; it stops "preheat the oven" mistakes, not "the oven is too small". Each absorbed trap cites its handoff id.

## ── LAYER-A: forge CUDA build-trap absorption (the 5 measured walls) ──

- [ ] **DOJO-A1 — HEXA_CUDA_LINK fork-bomb + dropped runtime_cuda.c (677b84cd)** — HEXA_CUDA_LINK=1 build fork-bombs (1800+ procs) at nested runtime_cuda.c emit + silently drops the ~100KB write. Proven fixes on branch laneg/devfeed-cudalink-integrated. LAND + dojo note. falsifier: build completes, runtime_cuda.c present and full.
- [ ] **DOJO-A2 — GLIBC_2.38 vs CUDA-devel glibc 2.35 (4a7841fe)** — prebuilt needs GLIBC_2.38 but cuda:12.4.1-devel-ubuntu22.04 ships 2.35. dojo+preflight: detect base glibc, advise from-source OR a 24.04 base. falsifier: preflight flags mismatch pre-build.
- [ ] **DOJO-A3 — Stage-1 transpile SIGKILL on 8MB stack (d751e2c4)** — large main_expanded.hexa SIGKILLs Stage-1 on the default stack. dojo+preflight: raise the stack ulimit before stage_build. falsifier: large-main transpile completes under raised limit.
- [x] **DOJO-A4 — nvptx f64 exp() underflow garbage below x approx -745 (d631a08f)** — exp() intrinsic returns garbage below the underflow threshold (missing 2^k clamp). CODEGEN fix: clamp so very-negative x gives +0.0. falsifier: hexa verify exp(-800)==0.0 vs libm. ✅ FIXED — `max.s64 b, b, 0` clamp in nvptx_target.hexa exp arm (b<<52 no longer overflows the sign bit). Numerical PASS exp(-800)=0.0 / exp(0)=1.0 / exp(1) rel 7.3e-9; bug-repro (no clamp) = -1.18e+269. .verdicts/dojo-a4-nvptx-expf64-underflow/. GPU ptxas round-trip = TODO.
- [ ] **DOJO-A5 — gpu_warp_shuffle_xor FP64 src as u32 (0a848320 RFC071 GAP-C)** — NVPTX lowering spells FP64 shfl src as u32 bank, ptxas rejects 'Arguments mismatch for shfl'. Blocks ALL FP64 in-warp reduction. CODEGEN fix: detect FP64 src, split hi/lo 32b. falsifier: FP64 warp-reduce kernel ptxas-compiles + bit-correct.

## ── LAYER-B boundary (NOT dojo-curable — pointer only) ──

- [x] **LAYER-B is HEXA-FUSION's, not dojo's** — the 13% util ceiling (80d47ccc) is a serial kernel-DAG/fusion problem; graph-capture FALSIFIED (5890c57b); only lift = TF32 GEMM-pulling megakernel +5.5pp (ab955314). dojo records the boundary; owned by [[HEXA-FUSION]].
