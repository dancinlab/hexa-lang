/* runtime_cuda.c — anima RFC 040 Phase A real-cuBLAS impl.
 *
 * Provides the `_hx_cuda_*` TU forward-decl'd by hexa-lang self/runtime.c
 * under `#ifdef HEXA_CUDA`. When the host has a CUDA toolkit, this TU
 * compiles + links with `-lcudart -lcublas`, giving farr_matmul_gpu a
 * real cuBLAS Dgemm body. On a no-CUDA host this file is simply not
 * compiled (the no-CUDA build is byte-identical to today).
 *
 * Math contract — same as RFC 032 farr_matmul:
 *   A row-major M×K, B row-major K×N, C row-major M×N.
 *   Reproducible bit-identity is NOT claimed (cuBLAS reduces in a
 *   different order than the CPU ikj scalar loop, fp non-associativity).
 *   Tolerance: |Δ| < ~1e-9 for Dgemm — matches RFC 040 §"Honest caveats"
 *   TOL_MATMUL guess; this fire measures and reports the actual max |Δ|.
 *
 * cuBLAS is column-major. Our farr is row-major. We map row-major
 * C = A·B to cuBLAS column-major by computing:
 *   C^T_col = B^T_col · A^T_col
 * which in cuBLAS column-major terms (treating row-major A as col-major
 * A^T) is: `cublasDgemm(handle, N, N, N=cols_out, M=rows_out, K, alpha,
 * B_dev, ldb=N, A_dev, lda=K, beta, C_dev, ldc=N)`.
 *
 * Device-farr coordination: we own a tiny device-side mirror table keyed
 * by farr_id. Operands are uploaded H2D on demand (when not already
 * resident) and outputs allocated device-side. The runtime.c side keeps
 * `dirty_host=1` / `loc=FARR_DEVICE` to track residence; this TU does
 * the actual cudaMalloc / cudaMemcpy calls.
 *
 * Honest reporting: every error path returns -1 + a one-line stderr
 * message naming the failure. No silent fallbacks; no fake CUDA results.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <cuda_runtime.h>
#include <cublas_v2.h>

/* C linkage for the public surface so that C harnesses (or runtime.c on
 * the host build) can call these symbols without C++ name mangling.
 * `-x cu` always parses as C++; without `extern "C"`, the harness
 * `extern "C" { int _hx_cuda_*(...); }` will fail to resolve. */
#ifdef __cplusplus
extern "C" {
#endif

/* Tiny device-side mirror table. Keyed by farr_id (same int handle the
 * runtime.c HexaFarrEntry table uses). Sparse: grows on demand. */
typedef struct {
    double*  d_buf;       /* cudaMalloc'd device pointer, or NULL */
    int64_t  len;         /* element count (must match host len when valid) */
    /* RFC 056 §6.2: -1 = this slot owns its d_buf (cudaMalloc'd here, may
     * be cudaFree'd). >=0 = this slot is a NON-OWNING device sub-view of
     * base farr `view_base` (d_buf = g_slots[view_base].d_buf + offset);
     * device_free / free must NOT cudaFree it (would corrupt the base).
     * A view is invalidated when its base is freed/migrated (guarded). */
    int64_t  view_base;
} _CudaFarrSlot;

static _CudaFarrSlot* g_slots     = NULL;
static int64_t        g_slot_cap  = 0;

static int _ensure_slot_cap(int64_t id) {
    if (id < 0) return -1;
    if (id < g_slot_cap) return 0;
    int64_t new_cap = g_slot_cap < 16 ? 16 : g_slot_cap;
    while (new_cap <= id) new_cap *= 2;
    _CudaFarrSlot* ns = (_CudaFarrSlot*)realloc(g_slots,
                            (size_t)new_cap * sizeof(_CudaFarrSlot));
    if (!ns) { fprintf(stderr, "[cuda] OOM slot table\n"); return -1; }
    /* zero-init the new tail. view_base = -1 (owns / not a view). */
    for (int64_t i = g_slot_cap; i < new_cap; i++) {
        ns[i].d_buf     = NULL;
        ns[i].len       = 0;
        ns[i].view_base = -1;
    }
    g_slots = ns;
    g_slot_cap = new_cap;
    return 0;
}

/* Forward decls — these live in self/runtime.c. We access the host
 * HexaFarrEntry table to read host buf + len for H2D + D2H. */
typedef struct {
    double*  buf;
    int64_t  len;
    void*    d_buf;       /* runtime.c side device-ptr slot (we mirror) */
    int      loc;
    int      pinned;
    int      dirty_host;
    int      dirty_dev;
} HexaFarrEntry;
extern HexaFarrEntry* _hx_farr_table;
extern int64_t        _hx_farr_count;

enum { FARR_HOST = 0, FARR_DEVICE = 1, FARR_MIRRORED = 2 };

/* ════════════════════════════════════════════════════════════════════
 * RFC 056 — device residence contract + sub-view API (Phase 1).
 *
 * §6.4 output-disposition register. The forge `_gpu` wrappers do not
 * change ABI (the Phase 4-D-5-3 byte-eq oracle harnesses declare them
 * `extern "C"` and re-running that oracle unchanged is falsifier
 * F-RFC056-BYTEEQ-PRESERVE — a signature break would fail the gate by
 * construction). Instead RFC 056 §6.4's "per-call out_disposition arg"
 * is realised as a process-wide register set by the caller IMMEDIATELY
 * before the `_gpu` call (functionally per-call; single-threaded forge
 * dispatch). Default = FORGE_OUT_HOST_NOW → any caller not updated gets
 * byte-identical current behaviour (the backward-safety invariant; spec
 * §6.4 / §8.3).
 *
 *   FORGE_OUT_HOST_NOW   = 0  D2H the output now (== pre-RFC-056)
 *   FORGE_OUT_DEVICE_KEEP = 1 defer D2H, output stays loc=FARR_DEVICE,
 *                             dirty_dev=1 (consumed by next GPU op)
 *
 * H2D-skip (§6.1): _h2d on an input that is loc∈{DEVICE,MIRRORED} with
 * !dirty_host and a live device slot of matching len SKIPs the
 * cudaMemcpy HostToDevice — the device bytes were written by the
 * authoritative path and host has not mutated them since, so the copy
 * is provably a no-op. Zero output bytes change (the byte-eq invariant
 * of §6.1 "Byte-eq invariant").
 *
 * NB: every threshold/behaviour here traces to RFC 056 §6.1-6.4 + the
 * fire #5-#9 measured campaign; no lattice numerology (f1/f2).
 * ════════════════════════════════════════════════════════════════════ */
enum { FORGE_OUT_HOST_NOW = 0, FORGE_OUT_DEVICE_KEEP = 1 };

/* Process-wide output-disposition register. Default HOST_NOW =
 * byte-identical to the verified pre-RFC-056 substrate. */
static int g_forge_out_disposition = FORGE_OUT_HOST_NOW;

/* Called by the host runtime.c shim immediately before a `_gpu` op to
 * express §6.4's consumed-by-next-GPU-op hint. Returns the previous
 * value (so callers can save/restore). */
int _hx_cuda_set_out_disposition(int d) {
    int prev = g_forge_out_disposition;
    g_forge_out_disposition = (d == FORGE_OUT_DEVICE_KEEP)
                              ? FORGE_OUT_DEVICE_KEEP : FORGE_OUT_HOST_NOW;
    return prev;
}

/* cuBLAS handle — lazy init. */
static cublasHandle_t g_cublas = NULL;

static int _ensure_cublas(void) {
    if (g_cublas) return 0;
    cublasStatus_t st = cublasCreate(&g_cublas);
    if (st != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[cuda] cublasCreate failed: %d\n", (int)st);
        g_cublas = NULL;
        return -1;
    }
    /* Default math mode is fp64-strict for Dgemm; do NOT set
     * CUBLAS_TENSOR_OP_MATH (we want bit-reproducible Dgemm). */
    return 0;
}

/* Upload host buf → device. Allocate if needed. Returns 0 ok / -1 err. */
static int _h2d(int64_t id) {
    if (id < 0 || id >= _hx_farr_count) {
        fprintf(stderr, "[cuda] h2d: bad id %lld\n", (long long)id);
        return -1;
    }
    if (_ensure_slot_cap(id) != 0) return -1;
    HexaFarrEntry* e = &_hx_farr_table[id];
    _CudaFarrSlot* s = &g_slots[id];
    /* RFC 056 §6.2: a non-owning device sub-view is, by definition,
     * already device-resident (it aliases the base's live buffer).
     * Never upload, never realloc — that would corrupt the base.
     * Just mirror the device pointer back for visibility. */
    if (s->view_base >= 0 && s->d_buf) {
        e->d_buf = (void*)s->d_buf;
        e->dirty_dev = 0;
        return 0;
    }
    if (!e->buf || e->len <= 0) {
        fprintf(stderr, "[cuda] h2d: empty host farr id=%lld\n", (long long)id);
        return -1;
    }
    /* RFC 056 §6.1 H2D-skip. If the farr is device-resident
     * (loc∈{DEVICE,MIRRORED}) AND host is not dirty AND the device slot
     * is live with a matching length, the device bytes ALREADY equal
     * what the cudaMemcpy H2D would write (they were produced by the
     * authoritative path; host unchanged since). Skipping the copy is
     * therefore provably byte-eq — falsifier F-RFC056-BYTEEQ-PRESERVE
     * requires max|Δ|=0.0 with this path active. We still mirror the
     * device pointer back to the entry for visibility. */
    if ((e->loc == FARR_DEVICE || e->loc == FARR_MIRRORED) &&
        !e->dirty_host && s->d_buf && s->len == e->len) {
        e->d_buf = (void*)s->d_buf;
        e->dirty_dev = 0;
        return 0; /* SKIP cudaMemcpy HostToDevice */
    }
    if (!s->d_buf || s->len != e->len) {
        if (s->d_buf) cudaFree(s->d_buf);
        cudaError_t er = cudaMalloc((void**)&s->d_buf,
                                    (size_t)e->len * sizeof(double));
        if (er != cudaSuccess) {
            fprintf(stderr, "[cuda] cudaMalloc(%lld doubles) failed: %s\n",
                    (long long)e->len, cudaGetErrorString(er));
            s->d_buf = NULL; s->len = 0;
            return -1;
        }
        s->len = e->len;
    }
    cudaError_t er = cudaMemcpy(s->d_buf, e->buf,
                                (size_t)e->len * sizeof(double),
                                cudaMemcpyHostToDevice);
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] cudaMemcpy H2D failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    /* Mirror device pointer back to runtime.c entry for visibility. */
    e->d_buf = (void*)s->d_buf;
    if (e->loc == FARR_HOST) e->loc = FARR_MIRRORED;
    e->dirty_dev = 0;
    return 0;
}

/* Copy device → host. Returns 0 ok / -1 err. */
static int _d2h(int64_t id) {
    if (id < 0 || id >= _hx_farr_count) return -1;
    if (id >= g_slot_cap)               return -1;
    HexaFarrEntry* e = &_hx_farr_table[id];
    _CudaFarrSlot* s = &g_slots[id];
    if (!e->buf || !s->d_buf || s->len != e->len) {
        fprintf(stderr, "[cuda] d2h: state mismatch id=%lld\n", (long long)id);
        return -1;
    }
    cudaError_t er = cudaMemcpy(e->buf, s->d_buf,
                                (size_t)e->len * sizeof(double),
                                cudaMemcpyDeviceToHost);
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] cudaMemcpy D2H failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    e->dirty_host = 0;
    if (e->loc == FARR_DEVICE) e->loc = FARR_MIRRORED;
    return 0;
}

/* ── Public surface (forward-decl'd in self/runtime.c HEXA_CUDA block) ── */

int _hx_cuda_runtime_available(void) {
    int n = 0;
    cudaError_t er = cudaGetDeviceCount(&n);
    if (er != cudaSuccess) return 0;
    return (n > 0) ? 1 : 0;
}

int _hx_cuda_device_count_impl(void) {
    int n = 0;
    cudaError_t er = cudaGetDeviceCount(&n);
    if (er != cudaSuccess) return 0;
    return (n > 0) ? n : 0;
}

int _hx_cuda_farr_to_device(int64_t farr_id) {
    if (_h2d(farr_id) != 0) return -1;
    return 1;
}

int _hx_cuda_farr_to_host(int64_t farr_id) {
    if (_d2h(farr_id) != 0) return -1;
    return 1;
}

int _hx_cuda_farr_device_free(int64_t farr_id) {
    if (farr_id < 0 || farr_id >= g_slot_cap) return 1; /* nothing to free */
    _CudaFarrSlot* s = &g_slots[farr_id];
    if (s->view_base >= 0) {
        /* RFC 056 §6.2: this slot is a NON-OWNING device sub-view —
         * d_buf aliases the base's buffer. Never cudaFree it (that
         * would corrupt the base). Just drop the view. */
        s->d_buf     = NULL;
        s->len       = 0;
        s->view_base = -1;
    } else if (s->d_buf) {
        /* RFC 056 §6.2: freeing a base invalidates every view that
         * aliased it (use-after-free guard — F-RFC056-VIEW-SAFETY).
         * Scan the slot table and drop dependent views BEFORE the
         * cudaFree so a later op on a view sees d_buf=NULL, not a
         * dangling device pointer. */
        for (int64_t v = 0; v < g_slot_cap; v++) {
            if (g_slots[v].view_base == farr_id) {
                g_slots[v].d_buf     = NULL;
                g_slots[v].len       = 0;
                g_slots[v].view_base = -1;
                if (v < _hx_farr_count) {
                    HexaFarrEntry* ve = &_hx_farr_table[v];
                    ve->d_buf = NULL;
                    ve->loc = FARR_HOST;
                    ve->dirty_host = 0;
                    ve->dirty_dev = 0;
                }
            }
        }
        cudaFree(s->d_buf);
        s->d_buf = NULL;
        s->len = 0;
    }
    if (farr_id < _hx_farr_count) {
        HexaFarrEntry* e = &_hx_farr_table[farr_id];
        e->d_buf = NULL;
        e->loc = FARR_HOST;
        e->dirty_host = 0;
        e->dirty_dev = 0;
    }
    return 1;
}

#ifdef HEXA_CUDA
/* ════════════════════════════════════════════════════════════════════
 * RFC 055 055-P1 — hexa_cuda_launch_kernel
 *
 *   Thin Driver-API wrapper that loads a cubin from an in-memory blob,
 *   resolves a kernel by name, marshals the farr-base argument list,
 *   and launches with the caller's grid/block configuration. This is
 *   the `gpu_launch` host-ABI termination point (gpu/SPEC.md §7,
 *   RFC 055 §6.5): the hexa surface lowers to this call exactly the
 *   way `hexa_cuda_alloc / copy / free / sync` lower to the Runtime
 *   API helpers above.
 *
 *   Inputs:
 *     - cubin_blob / cubin_len  — the @gpu_kernel's compiled cubin
 *                                 (RFC 055 emits PTX text; ptxas turns
 *                                 it into a cubin which the build
 *                                 system embeds as a .rodata LSection).
 *     - kernel_name             — the PTX `.visible .entry` symbol.
 *     - gx/gy/gz/bx/by/bz       — CUDA grid + block dimensions.
 *     - farr_ids  / n_args      — argument list: each int64_t is a
 *                                 farr slot id; the wrapper resolves
 *                                 the slot's d_buf and marshals a
 *                                 (CUdeviceptr) pointer into the
 *                                 cuLaunchKernel argv. n is appended
 *                                 as a trailing i64 in extra_i64_args.
 *
 *   Returns 1 on success, 0 on failure (with stderr diagnostic).
 *
 *   F-RFC055-LAUNCH-ABI gates this entry point round-trip via the
 *   tool/dispatch_r055_p1_vec_add.sh harness (host→kernel→host). The
 *   wrapper compiles only under `#ifdef HEXA_CUDA`; on a host without
 *   the CUDA toolkit the symbol is defined as a no-op returning 0 so
 *   the f-style fallback (F-RFC055-FALLBACK) stays byte-identical to
 *   the no-NVPTX build.
 * ════════════════════════════════════════════════════════════════════ */
#include <cuda.h>   /* CUmodule / CUfunction / cuLaunchKernel — Driver API. */

int _hx_cuda_launch_kernel(const void*   cubin_blob,
                           size_t        cubin_len,
                           const char*   kernel_name,
                           int           gx, int gy, int gz,
                           int           bx, int by, int bz,
                           const int64_t* farr_ids,
                           int            n_farr,
                           const int64_t* extra_i64_args,
                           int            n_extra) {
    if (!cubin_blob || cubin_len == 0 || !kernel_name) {
        fprintf(stderr, "[cuda] launch_kernel: bad cubin/name\n");
        return 0;
    }
    /* Lazy Driver-API init — Runtime API above auto-inits cuCtx, but a
     * Driver-API cuModuleLoadData call without an explicit Init/Context
     * fails on some toolkit/driver pairings. Calling cuInit(0) is
     * idempotent and cheap. */
    CUresult cr = cuInit(0);
    if (cr != CUDA_SUCCESS) {
        fprintf(stderr, "[cuda] launch_kernel: cuInit failed (%d)\n", (int)cr);
        return 0;
    }
    CUmodule mod = NULL;
    cr = cuModuleLoadData(&mod, cubin_blob);
    if (cr != CUDA_SUCCESS) {
        fprintf(stderr, "[cuda] launch_kernel: cuModuleLoadData failed (%d)\n", (int)cr);
        return 0;
    }
    CUfunction kfn = NULL;
    cr = cuModuleGetFunction(&kfn, mod, kernel_name);
    if (cr != CUDA_SUCCESS) {
        fprintf(stderr, "[cuda] launch_kernel: cuModuleGetFunction(`%s`) failed (%d)\n",
                kernel_name, (int)cr);
        cuModuleUnload(mod);
        return 0;
    }

    /* Marshal the argument list. cuLaunchKernel expects an array of
     * `void*` pointing at each argument's storage; we hold the farr
     * d_buf pointers + the i64 extras in caller-allocated arrays so a
     * VLA-free build (MSVC, older compilers) still works — cap at 16
     * total args which is the documented gpu_launch surface for 055-P1
     * (gpu/SPEC.md §7 — kernel signatures fit comfortably). */
    enum { _HX_GPU_LAUNCH_MAX_ARGS = 16 };
    CUdeviceptr arg_dptrs[_HX_GPU_LAUNCH_MAX_ARGS];
    int64_t     arg_i64s [_HX_GPU_LAUNCH_MAX_ARGS];
    void*       arg_ptrs [_HX_GPU_LAUNCH_MAX_ARGS];

    int total = n_farr + n_extra;
    if (total > _HX_GPU_LAUNCH_MAX_ARGS) {
        fprintf(stderr, "[cuda] launch_kernel: too many args (%d > %d)\n",
                total, _HX_GPU_LAUNCH_MAX_ARGS);
        cuModuleUnload(mod);
        return 0;
    }
    int idx = 0;
    for (int i = 0; i < n_farr; i++) {
        int64_t farr_id = farr_ids[i];
        if (farr_id < 0 || farr_id >= g_slot_cap) {
            fprintf(stderr, "[cuda] launch_kernel: bad farr id %lld\n",
                    (long long)farr_id);
            cuModuleUnload(mod);
            return 0;
        }
        /* The kernel reads .global memory — ensure the slot is
         * device-resident before launch. */
        if (_h2d(farr_id) != 0) {
            fprintf(stderr, "[cuda] launch_kernel: h2d for farr %lld failed\n",
                    (long long)farr_id);
            cuModuleUnload(mod);
            return 0;
        }
        arg_dptrs[idx] = (CUdeviceptr)(uintptr_t)g_slots[farr_id].d_buf;
        arg_ptrs [idx] = &arg_dptrs[idx];
        idx++;
    }
    for (int i = 0; i < n_extra; i++) {
        arg_i64s[idx] = extra_i64_args[i];
        arg_ptrs[idx] = &arg_i64s[idx];
        idx++;
    }

    /* Launch — shared memory bytes = 0, stream = 0 (default). Extra
     * config (dynamic .shared, async stream) is 055-P2. */
    cr = cuLaunchKernel(kfn,
                       (unsigned)gx, (unsigned)gy, (unsigned)gz,
                       (unsigned)bx, (unsigned)by, (unsigned)bz,
                       0u, NULL,
                       arg_ptrs, NULL);
    if (cr != CUDA_SUCCESS) {
        fprintf(stderr, "[cuda] launch_kernel: cuLaunchKernel(`%s`) failed (%d)\n",
                kernel_name, (int)cr);
        cuModuleUnload(mod);
        return 0;
    }
    /* Synchronize so a follow-up _d2h sees the kernel's writes — the
     * Runtime API path above is cudaDeviceSynchronize but cuCtxSync is
     * the Driver-API equivalent. */
    cr = cuCtxSynchronize();
    if (cr != CUDA_SUCCESS) {
        fprintf(stderr, "[cuda] launch_kernel: cuCtxSynchronize failed (%d)\n",
                (int)cr);
        cuModuleUnload(mod);
        return 0;
    }
    /* Mark any farr arg as dev-dirty so a follow-up host read triggers
     * a D2H — the kernel just wrote to the .global buffers. */
    for (int i = 0; i < n_farr; i++) {
        int64_t farr_id = farr_ids[i];
        if (farr_id >= 0 && farr_id < _hx_farr_count) {
            HexaFarrEntry* e = &_hx_farr_table[farr_id];
            e->dirty_dev = 1;
            e->loc = FARR_MIRRORED;
        }
    }
    cuModuleUnload(mod);
    return 1;
}
#else
/* No-CUDA fallback (F-RFC055-FALLBACK) — the runtime_cuda.c TU still
 * compiles `-fsyntax-only` on a host without the CUDA toolkit; the
 * launch wrapper degrades to a no-op stub returning 0 ("no GPU"). */
int _hx_cuda_launch_kernel(const void*   cubin_blob,
                           size_t        cubin_len,
                           const char*   kernel_name,
                           int           gx, int gy, int gz,
                           int           bx, int by, int bz,
                           const int64_t* farr_ids,
                           int            n_farr,
                           const int64_t* extra_i64_args,
                           int            n_extra) {
    (void)cubin_blob; (void)cubin_len; (void)kernel_name;
    (void)gx; (void)gy; (void)gz; (void)bx; (void)by; (void)bz;
    (void)farr_ids; (void)n_farr; (void)extra_i64_args; (void)n_extra;
    return 0;
}
#endif /* HEXA_CUDA — gpu_launch wrapper guard */

/* ════════════════════════════════════════════════════════════════════
 * RFC 056 §6.2 — device sub-view API.  hexa_farr_dev_view(base, off,
 * len) binds an already-host-allocated farr handle `view_id` so that
 * its CUDA slot aliases base.d_buf + off*sizeof(double) for `len`
 * doubles. NON-OWNING: device_free/free on the view drops the alias
 * without cudaFree. The base must be device-resident (caller pins it
 * first, §6.3). Out-of-range (off,len) → -1, no UB. Returns 0 ok.
 * ════════════════════════════════════════════════════════════════════ */
int _hx_cuda_farr_dev_view(int64_t base_id, int64_t offset, int64_t len,
                           int64_t view_id) {
    if (base_id < 0 || base_id >= _hx_farr_count ||
        view_id < 0 || view_id >= _hx_farr_count) {
        fprintf(stderr, "[cuda] dev_view: bad ids base=%lld view=%lld\n",
                (long long)base_id, (long long)view_id);
        return -1;
    }
    if (offset < 0 || len <= 0) {
        fprintf(stderr, "[cuda] dev_view: bad offset=%lld len=%lld\n",
                (long long)offset, (long long)len);
        return -1;
    }
    if (_ensure_slot_cap(base_id) != 0) return -1;
    if (_ensure_slot_cap(view_id) != 0) return -1;
    _CudaFarrSlot* bs = &g_slots[base_id];
    if (!bs->d_buf || bs->len <= 0) {
        fprintf(stderr, "[cuda] dev_view: base %lld not device-resident\n",
                (long long)base_id);
        return -1;
    }
    if (offset + len > bs->len) {
        fprintf(stderr, "[cuda] dev_view: range [%lld,%lld) exceeds "
                "base len %lld\n", (long long)offset,
                (long long)(offset + len), (long long)bs->len);
        return -1; /* out-of-range — no UB, F-RFC056-VIEW-SAFETY */
    }
    _CudaFarrSlot* vs = &g_slots[view_id];
    /* If the view slot previously OWNED a device buffer, free it (we
     * are repurposing the handle as a non-owning view). */
    if (vs->view_base < 0 && vs->d_buf) {
        cudaFree(vs->d_buf);
    }
    vs->d_buf     = bs->d_buf + offset;     /* double* arithmetic */
    vs->len       = len;
    vs->view_base = base_id;
    /* Mirror into the host entry so forge `_gpu` ops + H2D-skip see the
     * view as device-resident (it shares the base's residence). */
    HexaFarrEntry* ve = &_hx_farr_table[view_id];
    ve->d_buf      = (void*)vs->d_buf;
    ve->loc        = FARR_DEVICE;
    ve->dirty_host = 1;   /* host buf of the view handle is not the data */
    ve->dirty_dev  = 0;   /* device bytes are the authoritative base data */
    return 0;
}

/* RFC 056 §6.3 — residence anchor. pin: force the farr device-resident
 * (H2D once) and mark it non-evictable (HexaFarrEntry.pinned, RFC 040).
 * unpin: clear the pin; if the device copy is dirty, D2H it back. */
int _hx_cuda_farr_pin_device(int64_t farr_id) {
    if (farr_id < 0 || farr_id >= _hx_farr_count) return -1;
    if (_h2d(farr_id) != 0) return -1;          /* ensure resident */
    HexaFarrEntry* e = &_hx_farr_table[farr_id];
    e->pinned = 1;
    if (e->loc == FARR_HOST) e->loc = FARR_MIRRORED;
    return 1;
}

int _hx_cuda_farr_unpin_device(int64_t farr_id) {
    if (farr_id < 0 || farr_id >= _hx_farr_count) return -1;
    HexaFarrEntry* e = &_hx_farr_table[farr_id];
    e->pinned = 0;
    if (e->dirty_dev) { (void)_d2h(farr_id); }  /* materialize if stale */
    return 1;
}

/* _hx_cuda_farr_matmul_gpu(A, M, K, B, N, C) — Dgemm row-major C = A · B.
 *   A is M×K, B is K×N, C is M×N.
 *   - Caller (runtime.c) has already allocated C farr_id with len = M·N
 *     via hexa_farr_zeros.
 *   - We upload A,B to device (idempotent — skips if already resident),
 *     compute Dgemm on device, copy result back to host C buf,
 *     mark C dirty_host=0 (host current), loc=MIRRORED.
 *   - Returns 0 ok / -1 err.
 *
 *   Row-major → column-major mapping:
 *     C_row[M,N] = A_row[M,K] · B_row[K,N]
 *   View row-major A as column-major A^T (K×M); same for B,C. Then
 *     C^T_col[N,M] = B^T_col[N,K] · A^T_col[K,M]
 *   cuBLAS Dgemm with (op=N, op=N, m=N, n=M, k=K, A=B_dev, lda=N,
 *                      B=A_dev, ldb=K, C=C_dev, ldc=N).
 */
int _hx_cuda_farr_matmul_gpu(int64_t a_id, int64_t M, int64_t K,
                             int64_t b_id, int64_t N,
                             int64_t c_id) {
    if (_ensure_cublas() != 0) return -1;
    if (a_id < 0 || b_id < 0 || c_id < 0) {
        fprintf(stderr, "[cuda] matmul: bad ids %lld %lld %lld\n",
                (long long)a_id, (long long)b_id, (long long)c_id);
        return -1;
    }
    if (M <= 0 || K <= 0 || N <= 0) {
        fprintf(stderr, "[cuda] matmul: bad shape M=%lld K=%lld N=%lld\n",
                (long long)M, (long long)K, (long long)N);
        return -1;
    }
    /* Upload A,B (H2D). */
    if (_h2d(a_id) != 0) return -1;
    if (_h2d(b_id) != 0) return -1;
    /* Ensure C device buffer exists with size M·N. We re-use _ensure_slot_cap
     * + a fresh cudaMalloc to make a clean device-resident output. */
    if (_ensure_slot_cap(c_id) != 0) return -1;
    HexaFarrEntry* ce = &_hx_farr_table[c_id];
    _CudaFarrSlot*  cs = &g_slots[c_id];
    if (!ce->buf || ce->len < M * N) {
        fprintf(stderr, "[cuda] matmul: C host len %lld < M*N %lld\n",
                (long long)ce->len, (long long)(M*N));
        return -1;
    }
    if (!cs->d_buf || cs->len != ce->len) {
        if (cs->d_buf) cudaFree(cs->d_buf);
        cudaError_t er = cudaMalloc((void**)&cs->d_buf,
                                    (size_t)ce->len * sizeof(double));
        if (er != cudaSuccess) {
            fprintf(stderr, "[cuda] cudaMalloc C(%lld) failed: %s\n",
                    (long long)ce->len, cudaGetErrorString(er));
            cs->d_buf = NULL; cs->len = 0;
            return -1;
        }
        cs->len = ce->len;
    }
    double* A_dev = g_slots[a_id].d_buf;
    double* B_dev = g_slots[b_id].d_buf;
    double* C_dev = cs->d_buf;
    const double alpha = 1.0;
    const double beta  = 0.0;
    /* Row-major C = A · B → column-major C^T = B^T · A^T trick:
     *   cuBLAS sees B's row-major buffer as column-major (N×K)
     *   cuBLAS sees A's row-major buffer as column-major (K×M)
     * Dgemm(N,N, m=N, n=M, k=K, alpha, B_dev, ldb=N, A_dev, lda=K,
     *       beta, C_dev, ldc=N) — produces column-major (N×M), which
     * IS the row-major C (M×N). */
    cublasStatus_t st = cublasDgemm(g_cublas,
                                    CUBLAS_OP_N, CUBLAS_OP_N,
                                    (int)N, (int)M, (int)K,
                                    &alpha,
                                    B_dev, (int)N,
                                    A_dev, (int)K,
                                    &beta,
                                    C_dev, (int)N);
    if (st != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[cuda] cublasDgemm failed: %d\n", (int)st);
        return -1;
    }
    /* Copy C device → host so the host-side caller sees the result. */
    cudaError_t er = cudaMemcpy(ce->buf, C_dev,
                                (size_t)(M * N) * sizeof(double),
                                cudaMemcpyDeviceToHost);
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] cudaMemcpy C D2H failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    ce->d_buf      = (void*)C_dev;
    ce->loc        = FARR_MIRRORED;
    ce->dirty_host = 0;
    ce->dirty_dev  = 0;
    return 0;
}

/* ════════════════════════════════════════════════════════════════════
 * RFC 041 Phase 4-D-5-2 — Phase B reduction + Phase B2 real CUDA kernels
 * ────────────────────────────────────────────────────────────────────
 * 6 ops landed this cycle (reduction + matmul-variants split; the
 * elementwise split — mul/add/scale/silu/silu_grad — is the parallel
 * Agent's deliverable):
 *
 *   reduction (block-per-row, warp-shuffle, no atomics):
 *     - _hx_cuda_farr_softmax_rows_gpu     (Phase B)
 *     - _hx_cuda_farr_rmsnorm_rows_gpu     (Phase B)
 *     - _hx_cuda_farr_rmsnorm_bwd_rows_gpu (Phase B2; two row reductions)
 *
 *   matmul-variants (cuBLAS Dgemm reshape per RFC 041 §1):
 *     - _hx_cuda_farr_matmul_t_gpu  (Mᵀ·u   = cublasDgemm u[1×R]·M[R×C]→[1×C])
 *     - _hx_cuda_farr_outer_gpu     (u⊗v    = cublasDgemm u[R×1]·v[1×C]→[R×C])
 *
 *   1-D fused in-place update (no cross-element reduction):
 *     - _hx_cuda_farr_adamw_step_gpu (decoupled-wd AdamW, mirrors dt2_adamw_step)
 *
 * Wiring contract (matches existing Phase A `_hx_cuda_farr_matmul_gpu`):
 *   - Caller (self/runtime.c) has already allocated `out_id` via
 *     hexa_farr_zeros with the correct length.
 *   - We H2D-upload inputs (idempotent), cudaMalloc the output device
 *     buffer (if not resident), launch the kernel / cuBLAS, then D2H
 *     the result back to the caller's host buffer.
 *   - Returns 0 ok / -1 err. Every error path prints `[cuda] <op>: ...`
 *     to stderr; no silent fallback, no fake PASS.
 *
 * Determinism (F-RFC041-DETERMINISM):
 *   - Reductions use FIXED block size + warp-shuffle/shared-mem tree
 *     (no `atomicAdd`). Run-to-run byte-identical at fixed shape.
 *   - cuBLAS Dgemm: same handle, no Tensor-Op math mode flip → bit-eq
 *     across invocations on the same shape (per Phase D evidence).
 *
 * Tolerance choices (CALIBRATED — not asserted by hope):
 *   - matmul_t   : TOL_MATMUL ≈ 2e-9 relative (carries RFC 040 §2.2 H100
 *                  cuBLAS Dgemm measurement; same kernel, same caveat)
 *   - outer      : |Δ| = 0 BIT-EXACT (single product term per cell,
 *                  zero reduction → no fp non-associativity; RFC 041
 *                  F-RFC041-OUTER-EXACT demands exactness)
 *   - softmax_rows / rmsnorm_rows / rmsnorm_bwd_rows : TOL_ELEM ≈ 1e-12
 *                  (one row-length reduction, C ≤ ~4096; warp-shuffle
 *                  tree reorders pairwise sums relative to CPU sequential
 *                  loop — the fp non-associativity bound for sum of N
 *                  doubles is ~N·ε ≈ 4096·2.22e-16 ≈ 1e-12. Conservative.)
 *   - adamw_step : TOL_ELEM ≈ 1e-12 (no cross-element reduction; only the
 *                  per-element sqrt/division ULP — essentially bit-eq
 *                  modulo the libm sqrt platform ulp delta. The CPU side
 *                  also uses libm sqrt; bit-eq expected on modern x86/A64
 *                  but a 1e-15 cushion guards against IEEE-754 corner
 *                  cases on the GPU sqrt.)
 *
 * Build:
 *   - Real kernels are compiled by `nvcc -x cu -c runtime_cuda.c` only
 *     (the gcc-on-no-GPU path in PHASE_D_H100_EVIDENCE remains valid
 *     for Phase A — it never enters the `__CUDACC__`-guarded bodies and
 *     would link-fail at runtime if the new symbols are called without
 *     nvcc; that link-fail is the correct, honest behaviour).
 *   - On Mac dev (clang -DHEXA_CUDA -I /usr/local/cuda/include) the
 *     `__CUDACC__` macro is undefined, so the wrappers below compile as
 *     `return -1` stubs — syntactic check passes, no fake PASS.
 * ════════════════════════════════════════════════════════════════════ */

/* ── Output-allocation helper (no H2D upload — output starts fresh). ── */
static int _ensure_dev_alloc_out(int64_t out_id, int64_t need_len) {
    if (out_id < 0 || out_id >= _hx_farr_count) {
        fprintf(stderr, "[cuda] out: bad id %lld\n", (long long)out_id);
        return -1;
    }
    if (_ensure_slot_cap(out_id) != 0) return -1;
    HexaFarrEntry* e = &_hx_farr_table[out_id];
    _CudaFarrSlot* s = &g_slots[out_id];
    /* RFC 056 §6.2: a non-owning view must never be used as a kernel
     * OUTPUT through this allocator (it would realloc/own the alias and
     * corrupt the base). Views are read-only slices in the A2 design;
     * reject defensively rather than risk the verified base buffer. */
    if (s->view_base >= 0) {
        fprintf(stderr, "[cuda] out: id %lld is a non-owning device view "
                "(cannot be a kernel output)\n", (long long)out_id);
        return -1;
    }
    if (!e->buf || e->len < need_len) {
        fprintf(stderr, "[cuda] out: host len %lld < need %lld\n",
                (long long)e->len, (long long)need_len);
        return -1;
    }
    if (!s->d_buf || s->len != e->len) {
        if (s->d_buf) cudaFree(s->d_buf);
        cudaError_t er = cudaMalloc((void**)&s->d_buf,
                                    (size_t)e->len * sizeof(double));
        if (er != cudaSuccess) {
            fprintf(stderr, "[cuda] cudaMalloc out(%lld) failed: %s\n",
                    (long long)e->len, cudaGetErrorString(er));
            s->d_buf = NULL; s->len = 0;
            return -1;
        }
        s->len = e->len;
    }
    return 0;
}

/* ── D2H of an output buffer with explicit length (post-kernel copy). ──
 *
 * RFC 056 §6.1/§6.4 D2H-defer. When the caller set the disposition
 * register to FORGE_OUT_DEVICE_KEEP (output is consumed by the next GPU
 * op, no host reader in between), the cudaMemcpy DeviceToHost is
 * DEFERRED: the output stays loc=FARR_DEVICE, dirty_dev=1 with a live
 * device slot. The very next forge op's _h2d sees DEVICE && !dirty_host
 * and SKIPs the redundant H2D — the value never round-trips. A later
 * host reader (or an explicit hexa_farr_to_host) does the lazy D2H.
 *
 * The DEFAULT (FORGE_OUT_HOST_NOW) is byte-identical to the verified
 * pre-RFC-056 substrate: same cudaMemcpy, same loc=FARR_MIRRORED,
 * dirty flags cleared. F-RFC056-BYTEEQ-PRESERVE re-runs the 12-kernel
 * oracle harnesses (which never set the register → always HOST_NOW)
 * and requires max|Δ|=0.0. */
static int _d2h_out(int64_t out_id, int64_t copy_len) {
    HexaFarrEntry* e = &_hx_farr_table[out_id];
    _CudaFarrSlot* s = &g_slots[out_id];
    if (g_forge_out_disposition == FORGE_OUT_DEVICE_KEEP) {
        /* Defer D2H — device authoritative, host stale. No bytes
         * copied; the next op reads s->d_buf directly via H2D-skip. */
        e->d_buf      = (void*)s->d_buf;
        e->loc        = FARR_DEVICE;
        e->dirty_host = 1;   /* host buf no longer current */
        e->dirty_dev  = 1;   /* device holds the freshest value */
        (void)copy_len;
        return 0;
    }
    cudaError_t er = cudaMemcpy(e->buf, s->d_buf,
                                (size_t)copy_len * sizeof(double),
                                cudaMemcpyDeviceToHost);
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] D2H out failed: %s\n", cudaGetErrorString(er));
        return -1;
    }
    e->d_buf      = (void*)s->d_buf;
    e->loc        = FARR_MIRRORED;
    e->dirty_host = 0;
    e->dirty_dev  = 0;
    return 0;
}

#ifdef __CUDACC__

/* ── Warp + block sum-reduction primitives (deterministic tree). ── */
/* Block size for row-reduction kernels. 256 threads = 8 warps, fits
 * even long rows (C up to ~4096 with grid-stride within the block). */
#define HX_RR_BLOCK 256

__device__ __forceinline__ double _hx_warp_sum(double v) {
    /* unsigned mask = 0xFFFFFFFF — all 32 threads of the warp. */
    for (int offset = 16; offset > 0; offset >>= 1) {
        v += __shfl_down_sync(0xFFFFFFFFu, v, offset);
    }
    return v;
}

__device__ __forceinline__ double _hx_warp_max(double v) {
    for (int offset = 16; offset > 0; offset >>= 1) {
        double o = __shfl_down_sync(0xFFFFFFFFu, v, offset);
        if (o > v) v = o;
    }
    return v;
}

/* Block-wide sum: warp-reduce → shared-mem (one slot per warp) → first
 * warp re-reduces. HX_RR_BLOCK=256 → 8 warps → 8 shared slots. Returns
 * the total on thread 0; other threads see garbage. */
__device__ __forceinline__ double _hx_block_sum(double v, double* smem) {
    int lane = threadIdx.x & 31;
    int wid  = threadIdx.x >> 5;
    v = _hx_warp_sum(v);
    if (lane == 0) smem[wid] = v;
    __syncthreads();
    /* First warp reads up-to-(HX_RR_BLOCK/32) warp sums + reduces. */
    int n_warps = (blockDim.x + 31) >> 5;
    if (wid == 0) {
        double w = (lane < n_warps) ? smem[lane] : 0.0;
        w = _hx_warp_sum(w);
        if (lane == 0) smem[0] = w;
    }
    __syncthreads();
    return smem[0];
}

__device__ __forceinline__ double _hx_block_max(double v, double* smem) {
    int lane = threadIdx.x & 31;
    int wid  = threadIdx.x >> 5;
    v = _hx_warp_max(v);
    if (lane == 0) smem[wid] = v;
    __syncthreads();
    int n_warps = (blockDim.x + 31) >> 5;
    if (wid == 0) {
        /* -inf-equivalent for unused slots; rows always have ≥1 valid val. */
        double w = (lane < n_warps) ? smem[lane] : -1.0e308;
        w = _hx_warp_max(w);
        if (lane == 0) smem[0] = w;
    }
    __syncthreads();
    return smem[0];
}

/* ────────────────────────────────────────────────────────────────────
 * Kernel 1 — softmax_rows: numerically-stable row-wise softmax.
 *   Y[r,j] = exp(X[r,j] - max_j X[r,j]) / Σ_j exp(...)
 * Layout: one block per row (gridDim.x = R), HX_RR_BLOCK threads per
 * block. Each thread strides across the row.
 * Two reductions per row (max, then sum). Fixed tree → deterministic.
 * ──────────────────────────────────────────────────────────────────── */
__global__ void _hx_k_softmax_rows(const double* __restrict__ X,
                                   double* __restrict__ Y,
                                   int64_t R, int64_t C) {
    int64_t r = blockIdx.x;
    if (r >= R) return;
    const double* xr = X + r * C;
    double*       yr = Y + r * C;

    __shared__ double smem[HX_RR_BLOCK / 32];

    /* Pass 1: row max. */
    double vmax = -1.0e308;
    for (int64_t j = threadIdx.x; j < C; j += blockDim.x) {
        double v = xr[j];
        if (v > vmax) vmax = v;
    }
    double zmax = _hx_block_max(vmax, smem);

    /* Pass 2: write exp(x - max) into Y, accumulate sum. */
    double vsum = 0.0;
    for (int64_t j = threadIdx.x; j < C; j += blockDim.x) {
        double e = exp(xr[j] - zmax);
        yr[j] = e;
        vsum += e;
    }
    double s = _hx_block_sum(vsum, smem);
    double inv = (s > 0.0) ? (1.0 / s) : 0.0;

    /* Pass 3: normalize. */
    for (int64_t j = threadIdx.x; j < C; j += blockDim.x) {
        yr[j] *= inv;
    }
}

/* ────────────────────────────────────────────────────────────────────
 * Kernel 1b (flame Phase 4-D-9, ADDITIVE — RFC 058 12→13→14 precedent)
 * ────────────────────────────────────────────────────────────────────
 * causal_softmax_rows: per-row causal-prefix softmax for the attention
 * block (tool/flame_phase4d7_block_fwd_primitive.c L767-789). For row i,
 * with the causal prefix length L = i+1:
 *
 *     m_max  = max_{j∈[0,L)}  X[i*T+j]
 *     e_j    = _hx_dt_exp_dev(X[i*T+j] - m_max)              j∈[0,L)
 *     tot    = Σ_{j∈[0,L)} e_j
 *     Y[i*T+j] = e_j / tot                                   j∈[0,L)
 *     Y[i*T+j] = 0.0                                         j∈[L,T)
 *
 * BYTE-EQ CONTRACT — the CPU reference uses `flame_g7_dt_exp`, a
 * deterministic 12-term-Taylor / range-halving polynomial, NOT libm
 * `exp()`. _hx_dt_exp_dev below is that algorithm ported VERBATIM
 * (same constants, same loop bounds 1..11 / 0..r-1, same order) so the
 * only numerical gap vs the CPU reference is the row-reduction reorder
 * (deterministic tree, ~1e-12 band), never an exp-algorithm error.
 *
 * The existing _hx_k_softmax_rows (Kernel 1 above) softmaxes the FULL
 * row with libm exp() and is UNTOUCHED — this is a separate, additive
 * kernel for the causal-masked attention path.
 * ──────────────────────────────────────────────────────────────────── */

/* __device__ port of flame_g7_dt_exp (tool/flame_phase4d7_block_fwd_
 * primitive.c:78-85). Byte-for-byte the same algorithm: range-reduce by
 * halving while |xr| > 0.25 (counting r halvings), 12-term Taylor
 * (k = 1..11, term *= xr/k, acc += term), then square the result r
 * times. Same operations, same order ⇒ bit-identical to the CPU
 * reference modulo NONE (pure fp64 ops, identical sequence). */
__device__ __forceinline__ double _hx_dt_exp_dev(double x) {
    int r = 0; double xr = x;
    while ((xr > 0.0 ? xr : -xr) > 0.25) { xr = xr / 2.0; r = r + 1; }
    double term = 1.0, acc = 1.0;
    for (int k = 1; k < 12; k++) { term = term * xr / (double)k; acc = acc + term; }
    for (int s = 0; s < r; s++) acc = acc * acc;
    return acc;
}

__global__ void _hx_cuda_kern_causal_softmax_rows(const double* __restrict__ X,
                                                  double* __restrict__ Y,
                                                  int64_t R, int64_t T) {
    int64_t i = blockIdx.x;                 /* one block per row i */
    if (i >= R) return;
    const double* xr = X + i * T;
    double*       yr = Y + i * T;
    int64_t L = i + 1;                      /* causal prefix length */

    __shared__ double smem[HX_RR_BLOCK / 32];

    /* Pass 1: max over the causal prefix [0, L). Threads outside the
     * prefix contribute the -inf-equivalent identity (matches the CPU
     * reference which seeds m_max = sc[i*T+0] and scans j∈[1,L)). */
    double vmax = -1.0e308;
    for (int64_t j = threadIdx.x; j < L; j += blockDim.x) {
        double v = xr[j];
        if (v > vmax) vmax = v;
    }
    double zmax = _hx_block_max(vmax, smem);

    /* Pass 2: e_j = dt_exp(x - max) into Y[0,L); accumulate the prefix
     * sum. j∈[L,T) is written exactly 0.0 (the CPU code only writes /
     * normalizes [0,L) and leaves the rest of the Bc slab as its prior
     * zeros — here Y is the dedicated output so we zero it explicitly). */
    double vsum = 0.0;
    for (int64_t j = threadIdx.x; j < T; j += blockDim.x) {
        if (j < L) {
            double e = _hx_dt_exp_dev(xr[j] - zmax);
            yr[j] = e;
            vsum += e;
        } else {
            yr[j] = 0.0;
        }
    }
    double tot = _hx_block_sum(vsum, smem);

    /* Pass 3: normalize the causal prefix. The CPU reference divides
     * (`Bc[oP+...] /= tot`) — use the SAME divide here (NOT a
     * multiply-by-reciprocal) so the only residual numerical gap vs the
     * CPU reference is the deterministic-tree reorder of m_max and tot.
     * The CPU `tot` is always > 0 (≥ exp(0)=1 from the j=i diagonal),
     * so no /0 guard is needed to mirror it; guard defensively anyway. */
    for (int64_t j = threadIdx.x; j < L; j += blockDim.x) {
        if (tot != 0.0) yr[j] = yr[j] / tot;
    }
}

/* ────────────────────────────────────────────────────────────────────
 * Kernel 2 — rmsnorm_rows: Y[r,j] = X[r,j] / sqrt(mean_j(X²) + eps)
 *   One block per row; one reduction (sum of squares).
 * ──────────────────────────────────────────────────────────────────── */
__global__ void _hx_k_rmsnorm_rows(const double* __restrict__ X,
                                   double* __restrict__ Y,
                                   int64_t R, int64_t C, double eps) {
    int64_t r = blockIdx.x;
    if (r >= R) return;
    const double* xr = X + r * C;
    double*       yr = Y + r * C;

    __shared__ double smem[HX_RR_BLOCK / 32];

    double v = 0.0;
    for (int64_t j = threadIdx.x; j < C; j += blockDim.x) {
        double x = xr[j];
        v += x * x;
    }
    double ss = _hx_block_sum(v, smem);
    double ms = ss / (double)C;
    double inv = 1.0 / sqrt(ms + eps);

    for (int64_t j = threadIdx.x; j < C; j += blockDim.x) {
        yr[j] = xr[j] * inv;
    }
}

/* ────────────────────────────────────────────────────────────────────
 * Kernel 3 — rmsnorm_bwd_rows: exact dx-branch of RMSNorm vjp.
 *   inv  = (mean_j(x²)+ε)^(−1/2)
 *   dot  = Σ_k dxn_k · x_k
 *   dx_i = inv·dxn_i − (inv³·x_i / C)·dot
 *   ε = 1e-6 (mirrors CPU c3_rmsnorm_bwd contract).
 * Two reductions per row (ms = Σx², dot = Σdxn·x).
 * ──────────────────────────────────────────────────────────────────── */
__global__ void _hx_k_rmsnorm_bwd_rows(const double* __restrict__ X,
                                       const double* __restrict__ DXN,
                                       double* __restrict__ O,
                                       int64_t R, int64_t C) {
    int64_t r = blockIdx.x;
    if (r >= R) return;
    const double* xr  = X   + r * C;
    const double* dxr = DXN + r * C;
    double*       orr = O   + r * C;

    __shared__ double smem[HX_RR_BLOCK / 32];

    /* Reduction 1: sum of squares. */
    double ssq = 0.0;
    for (int64_t j = threadIdx.x; j < C; j += blockDim.x) {
        double x = xr[j];
        ssq += x * x;
    }
    double ms_total = _hx_block_sum(ssq, smem);
    double ms       = ms_total / (double)C;
    double inv      = 1.0 / sqrt(ms + 1e-6);

    /* Reduction 2: dot(dxn, x). */
    double dotp = 0.0;
    for (int64_t k = threadIdx.x; k < C; k += blockDim.x) {
        dotp += dxr[k] * xr[k];
    }
    double dot  = _hx_block_sum(dotp, smem);
    double coef = (inv * inv * inv) / (double)C;

    /* Write dx. */
    for (int64_t i = threadIdx.x; i < C; i += blockDim.x) {
        orr[i] = inv * dxr[i] - coef * xr[i] * dot;
    }
}

/* ────────────────────────────────────────────────────────────────────
 * Kernel 4 — adamw_step: decoupled-wd AdamW in-place.
 *   m_i  ← β1·m_i + (1-β1)·g_i
 *   v_i  ← β2·v_i + (1-β2)·g_i²
 *   mhat = m_i / (1-β1^t)
 *   vhat = v_i / (1-β2^t)
 *   W_i  ← W_i - lr·wd·W_i - lr·mhat/(sqrt(vhat)+eps)   (out → O[i])
 *   m, v updated in-place on their device buffers.
 * 1-D grid-stride; no cross-element reduction → bit-eq per element
 * (modulo sqrt ULP).
 * ──────────────────────────────────────────────────────────────────── */
__global__ void _hx_k_adamw_step(double* __restrict__ W,
                                 double* __restrict__ Mm,
                                 double* __restrict__ Vv,
                                 const double* __restrict__ G,
                                 double* __restrict__ O,
                                 int64_t n,
                                 double lr, double b1, double b2,
                                 double eps, double wd,
                                 double c1, double c2) {
    int64_t stride = (int64_t)blockDim.x * (int64_t)gridDim.x;
    for (int64_t i = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         i < n;
         i += stride) {
        double g    = G[i];
        double mi   = b1 * Mm[i] + (1.0 - b1) * g;
        double vi   = b2 * Vv[i] + (1.0 - b2) * g * g;
        double mhat = mi / c1;
        double vhat = vi / c2;
        double denom = sqrt(vhat) + eps;
        double wi   = W[i] - lr * wd * W[i] - lr * mhat / denom;
        Mm[i] = mi;     /* in-place optimizer state */
        Vv[i] = vi;
        O[i]  = wi;
    }
}

#endif /* __CUDACC__ — kernel bodies (compiled by nvcc only) */

/* ════════════════════════════════════════════════════════════════════
 * Host wrappers — match the extern decls in self/runtime.c §10941-10954
 * (Phase B) and §11181-11200 (Phase B2). Signature: caller owns the
 * pre-allocated out_id farr; we return 0 ok / -1 err.
 * ════════════════════════════════════════════════════════════════════ */

int _hx_cuda_farr_softmax_rows_gpu(int64_t x_id, int64_t R, int64_t C,
                                   int64_t out_id) {
#ifdef __CUDACC__
    if (R <= 0 || C <= 0) {
        fprintf(stderr, "[cuda] softmax_rows: bad shape R=%lld C=%lld\n",
                (long long)R, (long long)C);
        return -1;
    }
    if (_h2d(x_id) != 0) return -1;
    if (_ensure_dev_alloc_out(out_id, R * C) != 0) return -1;
    const double* X = g_slots[x_id].d_buf;
    double*       Y = g_slots[out_id].d_buf;
    dim3 grid((unsigned)R), block(HX_RR_BLOCK);
    _hx_k_softmax_rows<<<grid, block>>>(X, Y, R, C);
    cudaError_t er = cudaDeviceSynchronize();
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] softmax_rows launch failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    return _d2h_out(out_id, R * C);
#else
    (void)x_id; (void)R; (void)C; (void)out_id;
    fprintf(stderr, "[cuda] softmax_rows: built without __CUDACC__ "
                    "(use nvcc -x cu)\n");
    return -1;
#endif
}

/* ── causal_softmax_rows host wrapper (flame Phase 4-D-9, the 14th
 * kernel — ADDITIVE; the 12 verified kernels + RFC 058 13th + all
 * existing wrappers are UNTOUCHED). Mirrors _hx_cuda_farr_softmax_rows_
 * gpu EXACTLY: validate → _h2d(x) → _ensure_dev_alloc_out(R*T) → launch
 * → cudaDeviceSynchronize/cudaGetLastError → _d2h_out(R*T) → mark. The
 * X buffer is R×T causal scores; Y[i*T+j] = softmax over [0,i+1) (the
 * causal prefix), 0.0 for j ≥ i+1. Per-row reduction is the same
 * deterministic _hx_block_max/_hx_block_sum tree as Kernel 1. */
int _hx_cuda_farr_causal_softmax_rows_gpu(int64_t x_id, int64_t R,
                                          int64_t T, int64_t out_id) {
#ifdef __CUDACC__
    if (R <= 0 || T <= 0) {
        fprintf(stderr, "[cuda] causal_softmax_rows: bad shape "
                "R=%lld T=%lld\n", (long long)R, (long long)T);
        return -1;
    }
    if (_h2d(x_id) != 0) return -1;
    if (_ensure_dev_alloc_out(out_id, R * T) != 0) return -1;
    const double* X = g_slots[x_id].d_buf;
    double*       Y = g_slots[out_id].d_buf;
    dim3 grid((unsigned)R), block(HX_RR_BLOCK);
    _hx_cuda_kern_causal_softmax_rows<<<grid, block>>>(X, Y, R, T);
    cudaError_t er = cudaDeviceSynchronize();
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] causal_softmax_rows launch failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    return _d2h_out(out_id, R * T);
#else
    (void)x_id; (void)R; (void)T; (void)out_id;
    fprintf(stderr, "[cuda] causal_softmax_rows: built without __CUDACC__ "
                    "(use nvcc -x cu)\n");
    return -1;
#endif
}

int _hx_cuda_farr_rmsnorm_rows_gpu(int64_t x_id, int64_t R, int64_t C,
                                   double eps, int64_t out_id) {
#ifdef __CUDACC__
    if (R <= 0 || C <= 0) {
        fprintf(stderr, "[cuda] rmsnorm_rows: bad shape R=%lld C=%lld\n",
                (long long)R, (long long)C);
        return -1;
    }
    if (!(eps >= 0.0)) {
        fprintf(stderr, "[cuda] rmsnorm_rows: bad eps %g\n", eps);
        return -1;
    }
    if (_h2d(x_id) != 0) return -1;
    if (_ensure_dev_alloc_out(out_id, R * C) != 0) return -1;
    const double* X = g_slots[x_id].d_buf;
    double*       Y = g_slots[out_id].d_buf;
    dim3 grid((unsigned)R), block(HX_RR_BLOCK);
    _hx_k_rmsnorm_rows<<<grid, block>>>(X, Y, R, C, eps);
    cudaError_t er = cudaDeviceSynchronize();
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] rmsnorm_rows launch failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    return _d2h_out(out_id, R * C);
#else
    (void)x_id; (void)R; (void)C; (void)eps; (void)out_id;
    fprintf(stderr, "[cuda] rmsnorm_rows: built without __CUDACC__\n");
    return -1;
#endif
}

int _hx_cuda_farr_rmsnorm_bwd_rows_gpu(int64_t x_id, int64_t dxn_id,
                                       int64_t R, int64_t C,
                                       int64_t out_id) {
#ifdef __CUDACC__
    if (R <= 0 || C <= 0) {
        fprintf(stderr, "[cuda] rmsnorm_bwd: bad shape R=%lld C=%lld\n",
                (long long)R, (long long)C);
        return -1;
    }
    if (_h2d(x_id) != 0) return -1;
    if (_h2d(dxn_id) != 0) return -1;
    if (_ensure_dev_alloc_out(out_id, R * C) != 0) return -1;
    const double* X   = g_slots[x_id].d_buf;
    const double* DXN = g_slots[dxn_id].d_buf;
    double*       O   = g_slots[out_id].d_buf;
    dim3 grid((unsigned)R), block(HX_RR_BLOCK);
    _hx_k_rmsnorm_bwd_rows<<<grid, block>>>(X, DXN, O, R, C);
    cudaError_t er = cudaDeviceSynchronize();
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] rmsnorm_bwd launch failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    return _d2h_out(out_id, R * C);
#else
    (void)x_id; (void)dxn_id; (void)R; (void)C; (void)out_id;
    fprintf(stderr, "[cuda] rmsnorm_bwd: built without __CUDACC__\n");
    return -1;
#endif
}

int _hx_cuda_farr_adamw_step_gpu(int64_t w_id, int64_t m_id,
                                  int64_t v_id, int64_t g_id,
                                  int64_t n, double lr, double b1,
                                  double b2, double eps, double wd,
                                  int64_t step_t, int64_t out_id) {
#ifdef __CUDACC__
    if (n <= 0 || step_t < 1) {
        fprintf(stderr, "[cuda] adamw_step: bad n=%lld step_t=%lld\n",
                (long long)n, (long long)step_t);
        return -1;
    }
    /* H2D for ALL four operands. W/m/v get updated (in-place on device);
     * we then D2H W back to the CALLER's out buf and ALSO D2H m,v back
     * to their host bufs so the optimizer-state contract holds
     * (CPU oracle updates m,v in place on the host buffers). */
    if (_h2d(w_id) != 0) return -1;
    if (_h2d(m_id) != 0) return -1;
    if (_h2d(v_id) != 0) return -1;
    if (_h2d(g_id) != 0) return -1;
    if (_ensure_dev_alloc_out(out_id, n) != 0) return -1;

    /* Compute c1 = 1 - β1^t, c2 = 1 - β2^t on host (deterministic,
     * matches CPU oracle's per-step repeated mul: see runtime.c
     * §11419-11422). */
    double b1t = 1.0, b2t = 1.0;
    for (int64_t e = 0; e < step_t; e++) { b1t *= b1; b2t *= b2; }
    double c1 = 1.0 - b1t;
    double c2 = 1.0 - b2t;

    double* W  = g_slots[w_id].d_buf;
    double* Mm = g_slots[m_id].d_buf;
    double* Vv = g_slots[v_id].d_buf;
    const double* G = g_slots[g_id].d_buf;
    double* O  = g_slots[out_id].d_buf;

    /* 1-D grid-stride: ~256 threads/block, blocks = min(1024, ceil(n/256)).
     * Cap at 1024 blocks to keep stride pattern compact + deterministic. */
    int block_sz = 256;
    int64_t want_blocks = (n + block_sz - 1) / block_sz;
    int grid_sz = (want_blocks > 1024) ? 1024 : (int)want_blocks;
    if (grid_sz < 1) grid_sz = 1;

    _hx_k_adamw_step<<<grid_sz, block_sz>>>(W, Mm, Vv, G, O, n,
                                            lr, b1, b2, eps, wd, c1, c2);
    cudaError_t er = cudaDeviceSynchronize();
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] adamw_step launch failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    /* Write back W (out_id) AND in-place-updated m, v (their own ids). */
    if (_d2h_out(out_id, n) != 0) return -1;
    if (_d2h(m_id) != 0)          return -1;
    if (_d2h(v_id) != 0)          return -1;
    return 0;
#else
    (void)w_id; (void)m_id; (void)v_id; (void)g_id;
    (void)n; (void)lr; (void)b1; (void)b2; (void)eps; (void)wd;
    (void)step_t; (void)out_id;
    fprintf(stderr, "[cuda] adamw_step: built without __CUDACC__\n");
    return -1;
#endif
}

/* ════════════════════════════════════════════════════════════════════
 * matmul_t and outer — cuBLAS Dgemm reshape (RFC 041 §1, proven exact
 * on real hardware for the outer case; same Dgemm path as Phase A
 * for matmul_t — TOL_MATMUL ≈ 2e-9 inherited).
 *
 * Row-major→column-major trick recap (same as _hx_cuda_farr_matmul_gpu):
 *   to compute row-major C[M,N] = A[M,K]·B[K,N] via column-major Dgemm,
 *   call cublasDgemm(N,N, m=N, n=M, k=K, alpha, B_dev, ldb=N,
 *                    A_dev, lda=K, beta, C_dev, ldc=N).
 * ════════════════════════════════════════════════════════════════════ */

/* matmul_t: Mᵀ·u = [C].  M row-major [R,C], u [R], out [C].
 *
 * View as the matmul of u-as-row-vector with M:  out[1,C] = u[1,R] · M[R,C].
 * Plug into the row-major→col trick with M_outer=1, K=R, N=C:
 *   cublasDgemm(N, N, m=C, n=1, k=R, alpha, M_dev, ldb=C, U_dev, lda=R,
 *               beta, O_dev, ldc=C).
 * Reduction order: cuBLAS-tiled (NOT the CPU c3_matvec_t r-outer/k-inner
 * order) → reduction-tolerance applies. TOL_MATMUL ≈ 2e-9 (RFC 040 §2.2).
 */
int _hx_cuda_farr_matmul_t_gpu(int64_t m_id, int64_t R, int64_t C,
                               int64_t u_id, int64_t out_id) {
    if (_ensure_cublas() != 0) return -1;
    if (R <= 0 || C <= 0) {
        fprintf(stderr, "[cuda] matmul_t: bad shape R=%lld C=%lld\n",
                (long long)R, (long long)C);
        return -1;
    }
    if (_h2d(m_id) != 0) return -1;
    if (_h2d(u_id) != 0) return -1;
    if (_ensure_dev_alloc_out(out_id, C) != 0) return -1;

    double* M_dev = g_slots[m_id].d_buf;
    double* U_dev = g_slots[u_id].d_buf;
    double* O_dev = g_slots[out_id].d_buf;
    const double alpha = 1.0, beta = 0.0;
    /* row-major: out[1·C] = u[1·R] · M[R·C]
     * → cuBLAS Dgemm(N,N, m=C, n=1, k=R, alpha, M_dev, ldb=C, U_dev, lda=R,
     *                beta, O_dev, ldc=C) */
    cublasStatus_t st = cublasDgemm(g_cublas,
                                    CUBLAS_OP_N, CUBLAS_OP_N,
                                    (int)C, 1, (int)R,
                                    &alpha,
                                    M_dev, (int)C,
                                    U_dev, (int)R,
                                    &beta,
                                    O_dev, (int)C);
    if (st != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[cuda] cublasDgemm(matmul_t) failed: %d\n", (int)st);
        return -1;
    }
    return _d2h_out(out_id, C);
}

/* outer: u⊗v = [R·C].  u [R], v [C], out row-major [R,C].
 *
 * out[R,C] = u[R,1] · v[1,C]. Plug into the trick with M_outer=R, K=1, N=C:
 *   cublasDgemm(N, N, m=C, n=R, k=1, alpha, V_dev, ldb=C, U_dev, lda=1,
 *               beta, O_dev, ldc=C).
 * K=1 → SINGLE product term per output cell → ZERO reduction →
 * BIT-EXACT vs CPU c3_outer (F-RFC041-OUTER-EXACT demands |Δ| = 0).
 */
int _hx_cuda_farr_outer_gpu(int64_t u_id, int64_t v_id,
                            int64_t R, int64_t C, int64_t out_id) {
    if (_ensure_cublas() != 0) return -1;
    if (R <= 0 || C <= 0) {
        fprintf(stderr, "[cuda] outer: bad shape R=%lld C=%lld\n",
                (long long)R, (long long)C);
        return -1;
    }
    if (_h2d(u_id) != 0) return -1;
    if (_h2d(v_id) != 0) return -1;
    if (_ensure_dev_alloc_out(out_id, R * C) != 0) return -1;

    double* U_dev = g_slots[u_id].d_buf;
    double* V_dev = g_slots[v_id].d_buf;
    double* O_dev = g_slots[out_id].d_buf;
    const double alpha = 1.0, beta = 0.0;
    cublasStatus_t st = cublasDgemm(g_cublas,
                                    CUBLAS_OP_N, CUBLAS_OP_N,
                                    (int)C, (int)R, 1,
                                    &alpha,
                                    V_dev, (int)C,
                                    U_dev, 1,
                                    &beta,
                                    O_dev, (int)C);
    if (st != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[cuda] cublasDgemm(outer) failed: %d\n", (int)st);
        return -1;
    }
    return _d2h_out(out_id, R * C);
}

/* ══════════════════════════════════════════════════════════════════
 * RFC 041 Phase B — elementwise CUDA kernels (5 ops)
 *
 *   _hx_cuda_farr_add_gpu        C[i] = A[i] + B[i]
 *   _hx_cuda_farr_scale_gpu      Y[i] = α · X[i]
 *   _hx_cuda_farr_mul_gpu        C[i] = A[i] · B[i]   (Hadamard)
 *   _hx_cuda_farr_silu_gpu       Y[i] = X[i] · σ(X[i])
 *   _hx_cuda_farr_silu_grad_gpu  Y[i] = σ(X[i]) · (1 + X[i] · (1 − σ(X[i])))
 *
 * Math contract — bit-identical to the CPU oracles
 * (`self/runtime.c` `_hx_farr_{add,scale,mul,silu,silu_grad}_cpu`):
 *   - add / scale / mul: no cross-thread reduction → falsifier demands
 *     `|Δ| = 0` exact vs the CPU loop (F-RFC041-ADD-EXACT,
 *     -SCALE-EXACT, -MUL-EXACT).
 *   - silu / silu_grad: per-element transcendental (`exp` in fp64);
 *     tolerance is the f64 `exp` ULP — `TOL_ELEM` per RFC 041
 *     §"Falsifier battery" (F-RFC041-SILU-EQ, -SILU-GRAD-EQ).
 *
 * ABI — each host wrapper matches the existing `extern int _hx_cuda_*`
 * forward-decl in `self/runtime.c` (lines 10950-10953, 11188-11192).
 * Output farr_id is caller-allocated (host-side `hexa_farr_zeros`); this
 * TU H2D's inputs, ensures the device output slot is sized, launches the
 * kernel on the default stream, D2H's the result back, and marks the
 * output entry MIRRORED/clean — mirrors the Phase A `_hx_cuda_farr_matmul_gpu`
 * residence protocol.
 *
 * Determinism — 1-D grid-stride elementwise; no atomics, no cross-thread
 * reduction; the output for thread `i` is a pure function of input[i]
 * (and α for scale). Hence run-to-run byte-identical
 * (F-RFC041-DETERMINISM extends trivially here).
 *
 * Honest caveats:
 *   - `exp()` device-side resolves to the CUDA math device library
 *     fp64 `exp` (matches host libm fp64 `exp` to within 1 ULP per the
 *     CUDA math API contract; the silu falsifier framing accounts for
 *     this — `TOL_ELEM`, not bit-exact).
 *   - No tensor-core / mixed-precision path here; this is the strict
 *     fp64 elementwise reference. A bf16 / fp16 variant is RFC 044+/049.
 *   - Host wrappers compile only under `#ifdef HEXA_CUDA` (Mac no-CUDA
 *     build is unchanged — the wrapper symbols are simply absent;
 *     `self/runtime.c`'s `hexa_farr_*_gpu` dispatcher already returns
 *     -1 from the CUDA branch when the symbol isn't wired by the
 *     caller path, preserving the F-RFC041-NO-CUDA-FALLBACK contract).
 *
 * Kernel launch geometry — block=256, grid=min((n+255)/256, 65535).
 * Grid-stride loop covers any n (no upper bound from grid cap).
 *
 * The `__global__` kernels and `cudaLaunchKernel`-style `<<<...>>>`
 * launch syntax require the TU to be compiled with nvcc (CUDA C++) or
 * with clang's `-x cuda --cuda-path=...` mode. The build-system rename
 * `runtime_cuda.c` → `runtime_cuda.cu` (or nvcc `-x cu`) is the
 * concern of Phase 4-D-5-3 (CUDA-host link verify). This TU stays
 * `*.c` for the no-CUDA path — every existing build remains
 * byte-identical when HEXA_CUDA is undefined (the entire Phase B
 * elementwise block below is inside `#ifdef HEXA_CUDA`).
 * ══════════════════════════════════════════════════════════════════ */

#ifdef HEXA_CUDA

/* Default 1-D launch geometry. 256 threads/block balances occupancy on
 * SM 7.0+ (V100/A100/H100) without wasting SM resources on the simple
 * elementwise body; grid is capped at 65535 blocks (well under any
 * device's gridDim.x max — 2^31-1 on SM 3.0+, but 65535 fits the
 * grid-stride loop naturally and avoids over-subscription for small n).
 */
#define _HX_CUDA_ELEM_BLOCK 256
#define _HX_CUDA_ELEM_MAX_GRID 65535

static int _hx_cuda_elem_grid(int64_t n) {
    int64_t blocks = (n + (_HX_CUDA_ELEM_BLOCK - 1)) / _HX_CUDA_ELEM_BLOCK;
    if (blocks < 1) blocks = 1;
    if (blocks > _HX_CUDA_ELEM_MAX_GRID) blocks = _HX_CUDA_ELEM_MAX_GRID;
    return (int)blocks;
}

/* Ensure the device-side slot for `id` has an allocated buffer of `len`
 * doubles. Re-allocs if size changed. Returns 0 ok / -1 err. */
static int _ensure_dev_buf(int64_t id, int64_t len) {
    if (id < 0 || len <= 0) return -1;
    if (_ensure_slot_cap(id) != 0) return -1;
    _CudaFarrSlot* s = &g_slots[id];
    if (!s->d_buf || s->len != len) {
        if (s->d_buf) cudaFree(s->d_buf);
        cudaError_t er = cudaMalloc((void**)&s->d_buf,
                                    (size_t)len * sizeof(double));
        if (er != cudaSuccess) {
            fprintf(stderr, "[cuda] cudaMalloc(%lld doubles) failed: %s\n",
                    (long long)len, cudaGetErrorString(er));
            s->d_buf = NULL; s->len = 0;
            return -1;
        }
        s->len = len;
    }
    return 0;
}

/* D2H copy `len` doubles from device slot `id` to its host buf, then
 * mark MIRRORED/clean. Returns 0 ok / -1 err.
 * (Agent #25 Phase B elementwise variant with bounds checks; the Phase B
 *  reduction code uses the simpler `_d2h_out` at line 403. Renamed here
 *  to avoid redefinition.) */
static int _d2h_out_elem(int64_t id, int64_t len) {
    if (id < 0 || id >= _hx_farr_count) return -1;
    if (id >= g_slot_cap)               return -1;
    HexaFarrEntry* e = &_hx_farr_table[id];
    _CudaFarrSlot* s = &g_slots[id];
    if (!e->buf || !s->d_buf || e->len < len || s->len < len) return -1;
    /* RFC 056 §6.1/§6.4 D2H-defer — same contract as _d2h_out. Default
     * FORGE_OUT_HOST_NOW = byte-identical to the verified substrate. */
    if (g_forge_out_disposition == FORGE_OUT_DEVICE_KEEP) {
        e->d_buf      = (void*)s->d_buf;
        e->loc        = FARR_DEVICE;
        e->dirty_host = 1;
        e->dirty_dev  = 1;
        return 0;
    }
    cudaError_t er = cudaMemcpy(e->buf, s->d_buf,
                                (size_t)len * sizeof(double),
                                cudaMemcpyDeviceToHost);
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] cudaMemcpy elem D2H failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    e->d_buf      = (void*)s->d_buf;
    e->loc        = FARR_MIRRORED;
    e->dirty_host = 0;
    e->dirty_dev  = 0;
    return 0;
}

/* ── __global__ kernels (1-D grid-stride, fp64) ────────────────────── */

__global__ void _hx_cuda_kern_add(const double* __restrict__ A,
                                  const double* __restrict__ B,
                                  double* __restrict__ C,
                                  int64_t n) {
    int64_t i      = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    int64_t stride = (int64_t)gridDim.x  * (int64_t)blockDim.x;
    for (; i < n; i += stride) {
        C[i] = A[i] + B[i];
    }
}

__global__ void _hx_cuda_kern_scale(const double* __restrict__ X,
                                    double alpha,
                                    double* __restrict__ Y,
                                    int64_t n) {
    int64_t i      = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    int64_t stride = (int64_t)gridDim.x  * (int64_t)blockDim.x;
    for (; i < n; i += stride) {
        Y[i] = alpha * X[i];
    }
}

__global__ void _hx_cuda_kern_mul(const double* __restrict__ A,
                                  const double* __restrict__ B,
                                  double* __restrict__ C,
                                  int64_t n) {
    int64_t i      = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    int64_t stride = (int64_t)gridDim.x  * (int64_t)blockDim.x;
    for (; i < n; i += stride) {
        C[i] = A[i] * B[i];
    }
}

/* σ(x) = 1 / (1 + exp(-x)), fp64 device math. Matches the CPU
 * `_hx_sigmoid_d` (host libm `exp`) to within the CUDA fp64 `exp` ULP. */
__device__ __forceinline__ double _hx_cuda_sigmoid_d(double x) {
    return 1.0 / (1.0 + exp(-x));
}

__global__ void _hx_cuda_kern_silu(const double* __restrict__ X,
                                   double* __restrict__ Y,
                                   int64_t n) {
    int64_t i      = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    int64_t stride = (int64_t)gridDim.x  * (int64_t)blockDim.x;
    for (; i < n; i += stride) {
        double xi = X[i];
        Y[i] = xi * _hx_cuda_sigmoid_d(xi);
    }
}

/* silu'(x) = σ(x) · (1 + x · (1 − σ(x))). Mirrors CPU `_hx_farr_silu_grad_cpu`
 * (`self/runtime.c` §11314-11332) — same algebraic form, same single
 * `exp` call per element. */
__global__ void _hx_cuda_kern_silu_grad(const double* __restrict__ X,
                                        double* __restrict__ Y,
                                        int64_t n) {
    int64_t i      = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    int64_t stride = (int64_t)gridDim.x  * (int64_t)blockDim.x;
    for (; i < n; i += stride) {
        double xi = X[i];
        double s  = _hx_cuda_sigmoid_d(xi);
        Y[i] = s * (1.0 + xi * (1.0 - s));
    }
}

/* ── RoPE kernels (RFC 041 Phase B completion, 2026-05-17) ──────────
 *
 * Rotary position embedding. The flame decoder block (RFC 043,
 * stdlib/flame/decoder_block_lib.hexa §3 fwd / §3rev bwd; CPU reference
 * tool/flame_phase4d6_block_{fwd,bwd}_primitive.c) consumes PRECOMPUTED
 * cos/sin tables — the kernel does NOT recompute angles.
 *
 * Layout — tensor T_buf is row-major [T · nheads · hd]; the row for
 * position t, head hh starts at (t·nheads + hh)·hd. cos/sin are
 * row-major [T · hd], indexed bse + c with bse = t·hd. `half = hd/2`.
 *
 * Forward (mirrors fwd_primitive.c lines 162-167):
 *   rh_c   = (c < half) ? -x[row+half+c] : x[row+c-half]
 *   out[c] = x[row+c]·cos[bse+c] + rh_c·sin[bse+c]
 *
 * Backward — inverse rotation (mirrors bwd_primitive.c lines 322-327):
 *   gs   = (c < half) ?  dx[row+half+c]·sin[bse+half+c]
 *                     : -dx[row+c-half]·sin[bse+c-half]
 *   out[c] = dx[row+c]·cos[bse+c] + gs
 *
 * Each output element is a pure function of TWO input-row elements
 * (index c and c±half) plus cos/sin — NO cross-element reduction. A
 * thread-per-element kernel reading from a SEPARATE input buffer is
 * therefore BIT-EXACT vs the CPU scratch-buffer loop: same two
 * fp64 products + one add, no reordering (F-RFC041-ROPE-EXACT,
 * F-RFC041-ROPE-BWD-EXACT demand |Δ| = 0).
 *
 * 1-D grid-stride over the flat index e ∈ [0, T·nheads·hd). For each e
 * we recover t = e/(nheads·hd), c = e mod hd, and the row base.
 */

__global__ void _hx_cuda_kern_rope_fwd(const double* __restrict__ X,
                                       const double* __restrict__ COS,
                                       const double* __restrict__ SIN,
                                       double* __restrict__ Y,
                                       int64_t T, int64_t nheads,
                                       int64_t hd) {
    int64_t total  = T * nheads * hd;
    int64_t half   = hd / 2;
    int64_t i      = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    int64_t stride = (int64_t)gridDim.x  * (int64_t)blockDim.x;
    for (; i < total; i += stride) {
        int64_t c   = i % hd;
        int64_t row = i - c;             /* (t·nheads+hh)·hd */
        int64_t t   = i / (nheads * hd);
        int64_t bse = t * hd;
        double rh_c = (c < half)
            ? (0.0 - X[row + half + c])
            : X[row + c - half];
        /* __dmul_rn/__dadd_rn: explicit round-to-nearest, no FMA
         * contraction. nvcc device default (--fmad=true) would fuse
         * a*b+c*d into one fma() (1 rounding); the verified flame
         * reference nn_rope_apply_fwd (and the CPU fallback, pinned
         * by #pragma STDC FP_CONTRACT OFF, commit c0789e05) does 2
         * roundings. The RoPE GPU byte-eq oracle measured the fused
         * form diverging max|Δ|=4.441e-16 — this conforms the kernel
         * to the reference's rounding (F-RFC041-ROPE-EXACT |Δ|=0). */
        Y[i] = __dadd_rn(__dmul_rn(X[row + c], COS[bse + c]),
                         __dmul_rn(rh_c, SIN[bse + c]));
    }
}

__global__ void _hx_cuda_kern_rope_bwd(const double* __restrict__ DX,
                                       const double* __restrict__ COS,
                                       const double* __restrict__ SIN,
                                       double* __restrict__ Y,
                                       int64_t T, int64_t nheads,
                                       int64_t hd) {
    int64_t total  = T * nheads * hd;
    int64_t half   = hd / 2;
    int64_t i      = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    int64_t stride = (int64_t)gridDim.x  * (int64_t)blockDim.x;
    for (; i < total; i += stride) {
        int64_t c   = i % hd;
        int64_t row = i - c;
        int64_t t   = i / (nheads * hd);
        int64_t bse = t * hd;
        /* __dmul_rn/__dadd_rn — no FMA contraction; conform to the
         * non-contracted reference (see fwd kernel note + c0789e05). */
        double gs = (c < half)
            ? __dmul_rn(DX[row + half + c], SIN[bse + half + c])
            : (0.0 - __dmul_rn(DX[row + c - half], SIN[bse + c - half]));
        Y[i] = __dadd_rn(__dmul_rn(DX[row + c], COS[bse + c]), gs);
    }
}

/* ── Transpose-scatter kernel (RFC 058 §5.1, 13th forge kernel) ──────
 *
 * Pure index permutation: src (rows×cols, row-major) → dst transposed
 * (cols×rows, row-major) at byte-offset dst_off:
 *
 *   dst[dst_off + c*rows + r] = src[r*cols + c]
 *
 * ZERO floating-point operations — a `double` is copied bit-for-bit
 * from one slot to another, no add / mul / fma / rounding. The output
 * is a reindexing of the input bits, so byte-equality vs the CPU host
 * transpose loop `Y[Y_off + t*d_out + r] = C[r*T + t]` is mathematically
 * trivial (no accumulation order, no fp ULP — F-RFC058-KERNEL-BYTEEQ
 * |Δ|=0 by construction; the d768 GPU fire confirms it empirically).
 *
 * The flat thread index e ∈ [0, rows*cols) decomposes as r = e/cols,
 * c = e%cols — the SAME (r,c) the CPU loop visits (CPU iterates r outer,
 * c inner over the *transposed* read C[r*T+t]; here src has rows=d_out,
 * cols=T so r∈[0,d_out), c∈[0,T) and dst[dst_off+c*rows+r] is exactly
 * Y[Y_off + t*d_out + r] with t=c). No cross-element dependency, so a
 * thread-per-element grid-stride kernel is order-independent and exact.
 *
 * dst is NOT a fresh buffer — it is Bc, populated slab-by-slab across
 * projections. Only the [dst_off, dst_off+rows*cols) range is written;
 * the host wrapper H2D-uploads dst's current contents first so untouched
 * regions are preserved. The 12 verified kernels above are UNTOUCHED —
 * this is purely additive (RFC 058 §1, g_forge_verify_oracle 12→13). */
__global__ void _hx_cuda_kern_transpose_scatter(const double* __restrict__ src,
                                                double* __restrict__ dst,
                                                int64_t rows, int64_t cols,
                                                int64_t dst_off) {
    int64_t total  = rows * cols;
    int64_t i      = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    int64_t stride = (int64_t)gridDim.x  * (int64_t)blockDim.x;
    for (; i < total; i += stride) {
        int64_t r = i / cols;
        int64_t c = i % cols;
        dst[dst_off + c * rows + r] = src[r * cols + c];
    }
}

/* ── Host wrappers (extern surface — match runtime.c forward-decls) ──
 * Each: validate → H2D inputs → ensure output device buf sized → launch
 * → cudaGetLastError → D2H output → mark MIRRORED/clean. Returns 0 ok /
 * -1 err with a one-line stderr message (no silent fallback). */

int _hx_cuda_farr_add_gpu(int64_t a_id, int64_t b_id,
                          int64_t n, int64_t out_id) {
    if (a_id < 0 || b_id < 0 || out_id < 0) {
        fprintf(stderr, "[cuda] add: bad ids %lld %lld %lld\n",
                (long long)a_id, (long long)b_id, (long long)out_id);
        return -1;
    }
    if (n <= 0) {
        fprintf(stderr, "[cuda] add: bad n=%lld\n", (long long)n);
        return -1;
    }
    if (a_id >= _hx_farr_count || b_id >= _hx_farr_count ||
        out_id >= _hx_farr_count) {
        fprintf(stderr, "[cuda] add: id out of range\n");
        return -1;
    }
    if (_hx_farr_table[a_id].len < n || _hx_farr_table[b_id].len < n ||
        _hx_farr_table[out_id].len < n) {
        fprintf(stderr, "[cuda] add: host len < n\n");
        return -1;
    }
    if (_h2d(a_id) != 0) return -1;
    if (_h2d(b_id) != 0) return -1;
    if (_ensure_dev_buf(out_id, n) != 0) return -1;
    double* A = g_slots[a_id].d_buf;
    double* B = g_slots[b_id].d_buf;
    double* C = g_slots[out_id].d_buf;
    int grid = _hx_cuda_elem_grid(n);
    _hx_cuda_kern_add<<<grid, _HX_CUDA_ELEM_BLOCK>>>(A, B, C, n);
    cudaError_t er = cudaGetLastError();
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] add launch failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    if (_d2h_out(out_id, n) != 0) return -1;
    return 0;
}

int _hx_cuda_farr_scale_gpu(int64_t x_id, double alpha,
                            int64_t n, int64_t out_id) {
    if (x_id < 0 || out_id < 0) {
        fprintf(stderr, "[cuda] scale: bad ids %lld %lld\n",
                (long long)x_id, (long long)out_id);
        return -1;
    }
    if (n <= 0) {
        fprintf(stderr, "[cuda] scale: bad n=%lld\n", (long long)n);
        return -1;
    }
    if (x_id >= _hx_farr_count || out_id >= _hx_farr_count) {
        fprintf(stderr, "[cuda] scale: id out of range\n");
        return -1;
    }
    if (_hx_farr_table[x_id].len < n || _hx_farr_table[out_id].len < n) {
        fprintf(stderr, "[cuda] scale: host len < n\n");
        return -1;
    }
    if (_h2d(x_id) != 0) return -1;
    if (_ensure_dev_buf(out_id, n) != 0) return -1;
    double* X = g_slots[x_id].d_buf;
    double* Y = g_slots[out_id].d_buf;
    int grid = _hx_cuda_elem_grid(n);
    _hx_cuda_kern_scale<<<grid, _HX_CUDA_ELEM_BLOCK>>>(X, alpha, Y, n);
    cudaError_t er = cudaGetLastError();
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] scale launch failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    if (_d2h_out(out_id, n) != 0) return -1;
    return 0;
}

int _hx_cuda_farr_mul_gpu(int64_t a_id, int64_t b_id,
                          int64_t n, int64_t out_id) {
    if (a_id < 0 || b_id < 0 || out_id < 0) {
        fprintf(stderr, "[cuda] mul: bad ids %lld %lld %lld\n",
                (long long)a_id, (long long)b_id, (long long)out_id);
        return -1;
    }
    if (n <= 0) {
        fprintf(stderr, "[cuda] mul: bad n=%lld\n", (long long)n);
        return -1;
    }
    if (a_id >= _hx_farr_count || b_id >= _hx_farr_count ||
        out_id >= _hx_farr_count) {
        fprintf(stderr, "[cuda] mul: id out of range\n");
        return -1;
    }
    if (_hx_farr_table[a_id].len < n || _hx_farr_table[b_id].len < n ||
        _hx_farr_table[out_id].len < n) {
        fprintf(stderr, "[cuda] mul: host len < n\n");
        return -1;
    }
    if (_h2d(a_id) != 0) return -1;
    if (_h2d(b_id) != 0) return -1;
    if (_ensure_dev_buf(out_id, n) != 0) return -1;
    double* A = g_slots[a_id].d_buf;
    double* B = g_slots[b_id].d_buf;
    double* C = g_slots[out_id].d_buf;
    int grid = _hx_cuda_elem_grid(n);
    _hx_cuda_kern_mul<<<grid, _HX_CUDA_ELEM_BLOCK>>>(A, B, C, n);
    cudaError_t er = cudaGetLastError();
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] mul launch failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    if (_d2h_out(out_id, n) != 0) return -1;
    return 0;
}

int _hx_cuda_farr_silu_gpu(int64_t x_id, int64_t n, int64_t out_id) {
    if (x_id < 0 || out_id < 0) {
        fprintf(stderr, "[cuda] silu: bad ids %lld %lld\n",
                (long long)x_id, (long long)out_id);
        return -1;
    }
    if (n <= 0) {
        fprintf(stderr, "[cuda] silu: bad n=%lld\n", (long long)n);
        return -1;
    }
    if (x_id >= _hx_farr_count || out_id >= _hx_farr_count) {
        fprintf(stderr, "[cuda] silu: id out of range\n");
        return -1;
    }
    if (_hx_farr_table[x_id].len < n || _hx_farr_table[out_id].len < n) {
        fprintf(stderr, "[cuda] silu: host len < n\n");
        return -1;
    }
    if (_h2d(x_id) != 0) return -1;
    if (_ensure_dev_buf(out_id, n) != 0) return -1;
    double* X = g_slots[x_id].d_buf;
    double* Y = g_slots[out_id].d_buf;
    int grid = _hx_cuda_elem_grid(n);
    _hx_cuda_kern_silu<<<grid, _HX_CUDA_ELEM_BLOCK>>>(X, Y, n);
    cudaError_t er = cudaGetLastError();
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] silu launch failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    if (_d2h_out(out_id, n) != 0) return -1;
    return 0;
}

int _hx_cuda_farr_silu_grad_gpu(int64_t x_id, int64_t n, int64_t out_id) {
    if (x_id < 0 || out_id < 0) {
        fprintf(stderr, "[cuda] silu_grad: bad ids %lld %lld\n",
                (long long)x_id, (long long)out_id);
        return -1;
    }
    if (n <= 0) {
        fprintf(stderr, "[cuda] silu_grad: bad n=%lld\n", (long long)n);
        return -1;
    }
    if (x_id >= _hx_farr_count || out_id >= _hx_farr_count) {
        fprintf(stderr, "[cuda] silu_grad: id out of range\n");
        return -1;
    }
    if (_hx_farr_table[x_id].len < n || _hx_farr_table[out_id].len < n) {
        fprintf(stderr, "[cuda] silu_grad: host len < n\n");
        return -1;
    }
    if (_h2d(x_id) != 0) return -1;
    if (_ensure_dev_buf(out_id, n) != 0) return -1;
    double* X = g_slots[x_id].d_buf;
    double* Y = g_slots[out_id].d_buf;
    int grid = _hx_cuda_elem_grid(n);
    _hx_cuda_kern_silu_grad<<<grid, _HX_CUDA_ELEM_BLOCK>>>(X, Y, n);
    cudaError_t er = cudaGetLastError();
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] silu_grad launch failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    if (_d2h_out(out_id, n) != 0) return -1;
    return 0;
}

/* ── RoPE host wrappers (RFC 041 Phase B completion) ────────────────
 * Signature: (t_id, cos_id, sin_id, T, nheads, hd, out_id). Caller
 * (self/runtime.c) has pre-allocated out_id via hexa_farr_zeros with
 * len = T·nheads·hd. Validate → H2D the 3 inputs → ensure output
 * device buffer → launch the per-element kernel → D2H → MIRRORED.
 * `out` is a fresh buffer (separate from the input) so the rotation
 * reads originals — the byte-exact contract holds. */

static int _hx_cuda_rope_common(int64_t t_id, int64_t cos_id,
                                int64_t sin_id, int64_t T,
                                int64_t nheads, int64_t hd,
                                int64_t out_id, int is_bwd) {
    const char* tag = is_bwd ? "rope_bwd" : "rope";
    if (T <= 0 || nheads <= 0 || hd <= 0) {
        fprintf(stderr, "[cuda] %s: bad shape T=%lld nheads=%lld hd=%lld\n",
                tag, (long long)T, (long long)nheads, (long long)hd);
        return -1;
    }
    if ((hd & 1) != 0) {
        fprintf(stderr, "[cuda] %s: hd=%lld must be even\n",
                tag, (long long)hd);
        return -1;
    }
    if (t_id < 0 || cos_id < 0 || sin_id < 0 || out_id < 0) {
        fprintf(stderr, "[cuda] %s: bad ids %lld %lld %lld %lld\n",
                tag, (long long)t_id, (long long)cos_id,
                (long long)sin_id, (long long)out_id);
        return -1;
    }
    if (t_id >= _hx_farr_count || cos_id >= _hx_farr_count ||
        sin_id >= _hx_farr_count || out_id >= _hx_farr_count) {
        fprintf(stderr, "[cuda] %s: id out of range\n", tag);
        return -1;
    }
    int64_t total = T * nheads * hd;
    if (_hx_farr_table[t_id].len < total ||
        _hx_farr_table[out_id].len < total) {
        fprintf(stderr, "[cuda] %s: tensor host len < T*nheads*hd %lld\n",
                tag, (long long)total);
        return -1;
    }
    if (_hx_farr_table[cos_id].len < T * hd ||
        _hx_farr_table[sin_id].len < T * hd) {
        fprintf(stderr, "[cuda] %s: cos/sin host len < T*hd %lld\n",
                tag, (long long)(T * hd));
        return -1;
    }
    if (_h2d(t_id) != 0)   return -1;
    if (_h2d(cos_id) != 0) return -1;
    if (_h2d(sin_id) != 0) return -1;
    if (_ensure_dev_buf(out_id, total) != 0) return -1;
    const double* X   = g_slots[t_id].d_buf;
    const double* COS = g_slots[cos_id].d_buf;
    const double* SIN = g_slots[sin_id].d_buf;
    double*       Y   = g_slots[out_id].d_buf;
    int grid = _hx_cuda_elem_grid(total);
    if (is_bwd) {
        _hx_cuda_kern_rope_bwd<<<grid, _HX_CUDA_ELEM_BLOCK>>>(
            X, COS, SIN, Y, T, nheads, hd);
    } else {
        _hx_cuda_kern_rope_fwd<<<grid, _HX_CUDA_ELEM_BLOCK>>>(
            X, COS, SIN, Y, T, nheads, hd);
    }
    cudaError_t er = cudaGetLastError();
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] %s launch failed: %s\n",
                tag, cudaGetErrorString(er));
        return -1;
    }
    if (_d2h_out(out_id, total) != 0) return -1;
    return 0;
}

int _hx_cuda_farr_rope_gpu(int64_t t_id, int64_t cos_id, int64_t sin_id,
                           int64_t T, int64_t nheads, int64_t hd,
                           int64_t out_id) {
    return _hx_cuda_rope_common(t_id, cos_id, sin_id, T, nheads, hd,
                                out_id, 0);
}

int _hx_cuda_farr_rope_bwd_gpu(int64_t t_id, int64_t cos_id, int64_t sin_id,
                               int64_t T, int64_t nheads, int64_t hd,
                               int64_t out_id) {
    return _hx_cuda_rope_common(t_id, cos_id, sin_id, T, nheads, hd,
                                out_id, 1);
}

/* ── Transpose-scatter host wrapper (RFC 058 §5.2) ──────────────────
 *
 * Fills a slab of dst with the transpose of src on-device:
 *   dst[dst_off + c*rows + r] = src[r*cols + c]   (rows×cols → cols×rows)
 *
 * src is the cuBLAS projection output C — left FARR_DEVICE/dirty_dev by
 * RFC 057 §6.1, so _h2d(src_id) SKIPs the redundant H2D (H2D-skip
 * predicate, line ~190). dst is Bc — populated slab-by-slab. The kernel
 * writes ONLY the [dst_off, dst_off+rows*cols) range, so dst's current
 * device contents must be correct outside that range; _h2d(dst_id)
 * uploads dst's host bytes first (and SKIPs once dst is already
 * device-authoritative — exactly the residency win RFC 058 unlocks).
 *
 * On return dst (Bc) is MIRRORED — the kernel result is copied D2H back
 * to the host buffer so host Bc == device Bc byte-identically.
 *
 * RFC 058 byte-eq fix (fire #13 regression): the original wrapper marked
 * dst loc=FARR_DEVICE/dirty_host=1 and SKIPPED the D2H ("device freshest,
 * a host reader triggers a lazy D2H"). But the downstream A2-block ops
 * (RMSNorm/RoPE/attention/SwiGLU slabs in flame_phase4d7_block_*_
 * primitive.c) read Bc via the RAW host pointer `_hx_farr_table[Bc].buf`
 * — NOT through a farr API — so the lazy-D2H trigger never fires. They
 * read STALE host Bc bytes → wrong numerics (d768 init gn2 3.98438 vs
 * the correct 3.99026 of fires #8–#12).
 *
 * Device residency is all-or-nothing: marking Bc device-authoritative
 * while consumers still host-read it breaks byte-eq. Until every Bc
 * reader is converted to hexa_farr_dev_view (RFC 057 §6.2 consume wiring,
 * flame Phase 4-D-9 — element-loop kernels for RMSNorm/RoPE/attention/
 * SwiGLU not yet landed), the wrapper MUST D2H so the host buffer is
 * correct. The full-buffer _d2h is valid here: _h2d(dst_id) above
 * uploaded dst's whole host buffer, the kernel wrote only the slab, so
 * the device buffer holds the entire correct Bc; _d2h copies it all
 * back, sets dirty_host=0, loc=FARR_MIRRORED. The device copy stays live
 * (MIRRORED) so a later GPU op's _h2d still SKIPs — no wall regression
 * beyond the D2H round-trip itself.
 *
 * NOTE the d=32 path NEVER reaches this wrapper — the consumer keeps the
 * host transpose loop below the dim-gate (RFC 058 §5.4) so d=32 stays
 * byte-identical. This is purely the d768 GPU-resident path. */
int _hx_cuda_farr_transpose_scatter_gpu(int64_t src_id, int64_t dst_id,
                                        int64_t rows, int64_t cols,
                                        int64_t dst_off) {
    if (src_id < 0 || dst_id < 0) {
        fprintf(stderr, "[cuda] transpose_scatter: bad ids %lld %lld\n",
                (long long)src_id, (long long)dst_id);
        return -1;
    }
    if (rows <= 0 || cols <= 0 || dst_off < 0) {
        fprintf(stderr, "[cuda] transpose_scatter: bad shape "
                "rows=%lld cols=%lld dst_off=%lld\n",
                (long long)rows, (long long)cols, (long long)dst_off);
        return -1;
    }
    if (src_id >= _hx_farr_count || dst_id >= _hx_farr_count) {
        fprintf(stderr, "[cuda] transpose_scatter: id out of range\n");
        return -1;
    }
    int64_t total = rows * cols;
    if (_hx_farr_table[src_id].len < total) {
        fprintf(stderr, "[cuda] transpose_scatter: src host len %lld "
                "< rows*cols %lld\n",
                (long long)_hx_farr_table[src_id].len, (long long)total);
        return -1;
    }
    if (_hx_farr_table[dst_id].len < dst_off + total) {
        fprintf(stderr, "[cuda] transpose_scatter: dst host len %lld "
                "< dst_off+rows*cols %lld\n",
                (long long)_hx_farr_table[dst_id].len,
                (long long)(dst_off + total));
        return -1;
    }
    /* src device-resident → _h2d SKIPs (RFC 057 §6.1). dst current host
     * bytes uploaded so the kernel preserves regions outside the slab;
     * SKIPs once dst is already device-authoritative. */
    if (_h2d(src_id) != 0) return -1;
    if (_h2d(dst_id) != 0) return -1;
    const double* SRC = g_slots[src_id].d_buf;
    double*       DST = g_slots[dst_id].d_buf;
    if (!SRC || !DST) {
        fprintf(stderr, "[cuda] transpose_scatter: null device buf\n");
        return -1;
    }
    int grid = _hx_cuda_elem_grid(total);
    _hx_cuda_kern_transpose_scatter<<<grid, _HX_CUDA_ELEM_BLOCK>>>(
        SRC, DST, rows, cols, dst_off);
    cudaError_t er = cudaGetLastError();
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] transpose_scatter launch failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    /* RFC 058 byte-eq fix — D2H the kernel result back to the host buffer.
     * Downstream A2-block consumers (RMSNorm/RoPE/attention/SwiGLU slabs)
     * read Bc via the RAW host pointer, NOT a farr API, so the lazy-D2H
     * trigger never fires; the host buffer MUST therefore be made fresh
     * here. _d2h copies the whole device buffer back (it holds the entire
     * correct Bc — see header), sets dirty_host=0, loc=FARR_MIRRORED. The
     * device pointer stays live so a later GPU op's _h2d still SKIPs. The
     * resident-residency win (dropping this D2H) lands once all Bc readers
     * are converted to hexa_farr_dev_view — flame Phase 4-D-9. */
    if (_d2h(dst_id) != 0) return -1;
    return 0;
}

#endif /* HEXA_CUDA — Agent #25 Phase B elementwise block (opened at line 944) */

#ifdef __cplusplus
}  /* extern "C" */
#endif

/* ════════════════════════════════════════════════════════════════════
 * forge RFC 049 Stage 2 — BF16 mixed-precision substrate.
 *
 * The `farr_bf16` storage class + `*_bf16_gpu` kernel entry points live
 * in the sibling TU runtime_bf16.c. It is `#include`d here (not compiled
 * separately) so the BF16 tier shares this file's single `nvcc -x cu`
 * build — the same way the FP64 substrate above is one TU. runtime_bf16.c
 * carries its own `extern "C"` + `#include` guards and gates every
 * CUDA-only line behind `#ifdef HEXA_CUDA`, so on a no-CUDA host it
 * `cc -fsyntax-only`s clean as plain C.
 *
 * Stage 2 status: storage-class + kernel-entry SCAFFOLD. The Stage 1
 * BF16 fused FFN kernel is already MEASURED PASS (9.67x FP64 cuBLAS,
 * self/cuda/experiments/r049_bf16_fused_ffn.cu); the production kernel
 * fire-validation is a follow-up cost-bearing cycle.
 * ════════════════════════════════════════════════════════════════════ */
#include "runtime_bf16.c"
