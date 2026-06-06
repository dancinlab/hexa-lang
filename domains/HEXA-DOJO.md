# HEXA-DOJO — current state

@title: 🥋 HEXA-DOJO — GPU practice/recipe surface (build-trap absorption + kernel-authoring katas)

@goal: the hexa dojo (docs/hexa-dojo.md + tool/dojo_rent_preflight.sh + HEXA-CUDA.md) is the SINGLE practice surface that ABSORBS every known forge-CUDA build-trap + GPU-kernel-authoring lesson, so the next build/practice never re-hits a wall already paid for. **Scope honesty (g5)**: the dojo cures LAYER-A (build/toolchain traps — fixable, doc + codegen) — it does NOT cure LAYER-B (the serial kernel-DAG util ceiling, a codegen/fusion problem owned by [[HEXA-FUSION]], measured-FALSIFIED for graph-capture). dojo = recipe book; it stops "preheat the oven" mistakes, not "the oven is too small". Each absorbed trap cites its handoff id.

## ── LAYER-A: forge CUDA build-trap absorption (the 5 measured walls) ──

- [x] **DOJO-A1 — HEXA_CUDA_LINK fork-bomb + dropped runtime_cuda.c (677b84cd)** — falsifier MET on main (🟢 emit-step verified): runtime_cuda.c emits clean at full **308919 B** as a single short-lived process — no 1800+ proc fork-bomb, no dropped write. FINDING: of the 2 laneg fixes, #3b (write_file vs E2BIG heredoc, `bb10154fb`) is **already on main** (#2630 `8409117e2`); #3a (fork-bomb guard, `27535d93d`) targets `cuda_link_decision()`/the `HEXA_CUDA_LINK=1` opt-in link path that was **never merged to main** (closed-negative — fork-bomb structurally impossible here; `grep HEXA_CUDA_LINK self/main.hexa` → rc=1). TODO: full nvcc/pod end-to-end link if the opt-in path ever merges. verdict: `.verdicts/dojo-a1-cudalink-forkbomb/DOJO-A1.txt`.
- [ ] **DOJO-A2 — GLIBC_2.38 vs CUDA-devel glibc 2.35 (4a7841fe)** — prebuilt needs GLIBC_2.38 but cuda:12.4.1-devel-ubuntu22.04 ships 2.35. dojo+preflight: detect base glibc, advise from-source OR a 24.04 base. falsifier: preflight flags mismatch pre-build.
- [ ] **DOJO-A3 — Stage-1 transpile SIGKILL on 8MB stack (d751e2c4)** — large main_expanded.hexa SIGKILLs Stage-1 on the default stack. dojo+preflight: raise the stack ulimit before stage_build. falsifier: large-main transpile completes under raised limit.
- [ ] **DOJO-A4 — nvptx f64 exp() underflow garbage below x approx -745 (d631a08f)** — exp() intrinsic returns garbage below the underflow threshold (missing 2^k clamp). CODEGEN fix: clamp so very-negative x gives +0.0. falsifier: hexa verify exp(-800)==0.0 vs libm.
- [ ] **DOJO-A5 — gpu_warp_shuffle_xor FP64 src as u32 (0a848320 RFC071 GAP-C)** — NVPTX lowering spells FP64 shfl src as u32 bank, ptxas rejects 'Arguments mismatch for shfl'. Blocks ALL FP64 in-warp reduction. CODEGEN fix: detect FP64 src, split hi/lo 32b. falsifier: FP64 warp-reduce kernel ptxas-compiles + bit-correct.

## ── LAYER-B boundary (NOT dojo-curable — pointer only) ──

- [x] **LAYER-B is HEXA-FUSION's, not dojo's** — the 13% util ceiling (80d47ccc) is a serial kernel-DAG/fusion problem; graph-capture FALSIFIED (5890c57b); only lift = TF32 GEMM-pulling megakernel +5.5pp (ab955314). dojo records the boundary; owned by [[HEXA-FUSION]].
