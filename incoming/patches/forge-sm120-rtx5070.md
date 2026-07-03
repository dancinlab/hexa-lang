# forge CUDA runtime — sm_120 (Blackwell RTX 5070) enablement + runtime.c host-compile fix

**Status:** GPU LIVE on pool host `summer` (cuda_available=1, device GEMM fires, GPU util 81%).
**Date:** 2026-06-22 · **Host:** summer (RTX 5070, compute_cap 12.0, driver 580.159.03).
**Scope:** hexa-lang only (forge cuda runtime build). anima repo untouched.

## Root cause (measured)
- summer GPU = RTX 5070 = Blackwell sm_120. Default `nvcc` on PATH = CUDA 12.0 (V12.0.140), supports only up to sm_90 → forge's `runtime_cuda.o`/`runtime.cuda.a` built for wrong arch (observed bin runtime.a arch=sm_75, stale runtime.cuda.a arch=sm_86). No sm_120 SASS → forge tier fell back to farr (CPU).
- Host has `/usr/local/cuda-12.9` (V12.9.86, sm_120-capable); only the default PATH / `/usr/local/cuda` symlink points at 12.0.
- `tool/stage_resolve_runtime_a` already defaults SM=120 and prepends $CUDA_HOME/bin — arch knob correct; only CUDA_HOME default (12.0 symlink) was wrong.

## Real source bug (the actual blocker)
With CUDA_HOME=/usr/local/cuda-12.9 SM=120, the nvcc device compile of runtime_cuda.c SUCCEEDED for sm_120 (build/runtime_cuda.o arch = sm_120). But the host-side -DHEXA_CUDA compile of self/runtime.c FAILED:

    self/runtime.c:9972: error: call to undeclared function '_hx_cuda_farr_silu_gate_gpu'
        [-Wimplicit-function-declaration]   (fatal under clang C99)

Cause: `_hx_cuda_farr_silu_gate_gpu` is called at runtime.c:9972 but its only extern is at runtime.c:10553 (AFTER the use). Every other `_hx_cuda_farr_*_gpu` has its extern in the forward-decl block ~9615 (before use); silu_gate's was misplaced → runtime_cuda_host.o never built → ar fold skipped → stale sm_86 runtime.cuda.a left in place (silent wrong-arch ship).

## Fix applied (self/runtime.c on summer, uncommitted)
Added forward extern in the #ifdef HEXA_CUDA forward-decl block (after _hx_cuda_farr_scale_gpu, before its #endif ~9624):

    /* 2026-06-22 sm_120 build fix: silu_gate_gpu extern was below its use at
     * ~9972 (only decl at ~10553) -> implicit-function-declaration error under
     * clang C99 broke the -DHEXA_CUDA host compile. Forward-declare here. */
    extern int  _hx_cuda_farr_silu_gate_gpu(int64_t a_id, int64_t b_id,
                                            int64_t n, int64_t out_id);

Pure forward-declaration ordering fix (no behavior change); body still in runtime_cuda.c:6709, late extern at 10553 harmless.

## Rebuild recipe (reproducible)
    cd ~/.hx/src
    export CUDA_HOME=/usr/local/cuda-12.9 PATH=/usr/local/cuda-12.9/bin:$PATH \
           HEXA_CUDA=1 SM=120 CC=clang \
           CFLAGS_COMMON="-O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs"
    bash tool/stage_resolve_runtime_a            # -> build/runtime.cuda.a (arch=sm_120)
    cp -f build/runtime.cuda.a ~/.hx/bin/build/runtime.a
    cp -f build/runtime.cuda.a ~/.hx/src/build/runtime.a
    : > ~/.hx/.cuda-runtime                       # marker -> auto -lcudart -lcublas

## Verification (engine output)
- runtime.cuda.a cuobjdump arch = sm_120 (was sm_86)
- print(cuda_available()) -> 1
- 1024^3 forge_dispatch_matmul loop -> [OWN-GEMM-FIRED] _hx_k_gemm DEVICE path + GPU sm% peak 33%
- 2048^3 sustained -> GPU sm% peak 81% (real on-device compute, not farr fallback)
- Regression: CPU program runs (4), flame_forge_dispatch_test PASS, flame_bf16_tc_matmul_test PASS.

## Upstream TODO (so a fresh `hx install` does not revert it)
1. Commit the self/runtime.c forward-extern fix — without it any -DHEXA_CUDA host build on modern clang fails for everyone, not just sm_120.
2. Make stage_resolve_runtime_a (or the -cuda release job) default CUDA_HOME to the newest /usr/local/cuda-* whose max sm >= device compute_cap (or auto-derive SM from nvidia-smi compute_cap, gated against nvcc --list-gpu-arch), instead of the bare /usr/local/cuda symlink.
3. Ship an sm_120 -cuda release asset (prebuilt cuda asset currently bakes an older arch).

Note: forge tier chose its own device GEMM (_hx_k_gemm) over cuBLAS for these shapes; both are on-GPU. cuBLAS GemmEx is exercised by the bf16 TC path (test PASS). A cuBLAS-specific fp64 route is a tier-dispatch policy question, separate from this arch-enablement fix.

---

## 2026-06-22 UPDATE — stable-channel pivot evaluated and REJECTED (measured)

A coordinator pivot proposed switching summer from edge to a stable release (`hexa self-update --stable`) on the hope that stable already ships an sm_120 forge cuda build (a clean one-shot GPU enable). Evaluated against measurement; rejected:

1. **No such verb** — `hexa self-update` is not a subcommand on this toolchain (`error: unknown subcommand 'self-update'`). Current channel = `hexa edge`.
2. **Stable DOES ship a cuda asset** (contrary to install.sh comments): latest stable `v0.262.0` has `hexa-linux-x86_64-cuda.tar.gz`. BUT —
3. **That stable cuda asset is `arch = sm_75`** (cuobjdump on its `build/runtime.a`, size 2310186 = the same old-arch CPU-fallback-sized build), with **NO forward-compat PTX** (`compute_*` PTX absent) → it cannot run NOR JIT-forward on RTX 5070 sm_120. Installing it would OVERWRITE the live sm_120 runtime.a and REGRESS the GPU (back to farr/CPU fallback), then still require the exact src rebuild done above.

Conclusion: there is no clean stable self-update GPU win — stable's forge cuda asset is built for sm_75. The edge src rebuild (CUDA_HOME=12.9, SM=120, + the runtime.c forward-extern fix) remains the only path that yields sm_120 GPU execution on this host, and it is LIVE (cuda_available=1, util 81%). Did NOT install stable (would have been a strict regression). Live install left intact.

Added upstream TODO #4: the stable `-cuda` release asset should be built with `-gencode arch=compute_120,code=sm_120` (and ideally a `compute_120` PTX entry for forward-compat), so future Blackwell hosts get GPU from the asset without a src rebuild.
