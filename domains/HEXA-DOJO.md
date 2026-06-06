# HEXA-DOJO — current state

@title: 🥋 HEXA-DOJO — GPU practice/recipe surface (build-trap absorption + kernel-authoring katas)

@goal: the hexa dojo (docs/hexa-dojo.md + tool/dojo_rent_preflight.sh + HEXA-CUDA.md) is the SINGLE practice surface that ABSORBS every known forge-CUDA build-trap + GPU-kernel-authoring lesson, so the next build/practice never re-hits a wall already paid for. **Scope honesty (g5)**: the dojo cures LAYER-A (build/toolchain traps — fixable, doc + codegen) — it does NOT cure LAYER-B (the serial kernel-DAG util ceiling, a codegen/fusion problem owned by [[HEXA-FUSION]], measured-FALSIFIED for graph-capture). dojo = recipe book; it stops "preheat the oven" mistakes, not "the oven is too small". Each absorbed trap cites its handoff id.

## ── LAYER-A: forge CUDA build-trap absorption (the 5 measured walls) ──

- [ ] **DOJO-A1 — HEXA_CUDA_LINK fork-bomb + dropped runtime_cuda.c (677b84cd)** — HEXA_CUDA_LINK=1 build fork-bombs (1800+ procs) at nested runtime_cuda.c emit + silently drops the ~100KB write. Proven fixes on branch laneg/devfeed-cudalink-integrated. LAND + dojo note. falsifier: build completes, runtime_cuda.c present and full.
- [ ] **DOJO-A2 — GLIBC_2.38 vs CUDA-devel glibc 2.35 (4a7841fe)** — prebuilt needs GLIBC_2.38 but cuda:12.4.1-devel-ubuntu22.04 ships 2.35. dojo+preflight: detect base glibc, advise from-source OR a 24.04 base. falsifier: preflight flags mismatch pre-build.
- [ ] **DOJO-A3 — Stage-1 transpile SIGKILL on 8MB stack (d751e2c4)** — large main_expanded.hexa SIGKILLs Stage-1 on the default stack. dojo+preflight: raise the stack ulimit before stage_build. falsifier: large-main transpile completes under raised limit.
- [ ] **DOJO-A4 — nvptx f64 exp() underflow garbage below x approx -745 (d631a08f)** — exp() intrinsic returns garbage below the underflow threshold (missing 2^k clamp). CODEGEN fix: clamp so very-negative x gives +0.0. falsifier: hexa verify exp(-800)==0.0 vs libm.
- [x] **DOJO-A5 — gpu_warp_shuffle_xor FP64 src as u32 (RFC071 GAP-C / N70 GAP-C)** — NVPTX lowering spelled FP64 shfl src as u32 bank → ptxas 'Arguments mismatch for shfl'. Blocked ALL FP64 in-warp reduction. CODEGEN fix (detect FP64 src, split hi/lo 32b, `shfl.sync.bfly.b32` each half, `mov.b64` recompose) ALREADY LANDED in `b1564fa37` (#1200, N71-B / N70 GAP-C). Verified present in origin/main across 3 sites of `compiler/codegen/nvptx_target.hexa`: classifier dst-kind override (~L4087), Pass-4 `.b32` scratch-half decl (~L4277), body lowering (~L1700-1756). falsifier (emit-inspection — no local ptxas/GPU): committed `nvptx_p9_warp_reduce_test.hexa.ptx` shows `mov.b64 {%r_shfl_lo,%r_shfl_hi}, %fd9` → `shfl.sync.bfly.b32` ×2 → `mov.b64 %fd18, {...}` — split-shfl present, operands b32/fd, NO f64-src-as-`%r`, NO Arguments-mismatch. GPU bit-correct = TODO (no safely-rentable sm_90/120 pod this round).

## ── LAYER-B boundary (NOT dojo-curable — pointer only) ──

- [x] **LAYER-B is HEXA-FUSION's, not dojo's** — the 13% util ceiling (80d47ccc) is a serial kernel-DAG/fusion problem; graph-capture FALSIFIED (5890c57b); only lift = TF32 GEMM-pulling megakernel +5.5pp (ab955314). dojo records the boundary; owned by [[HEXA-FUSION]].
