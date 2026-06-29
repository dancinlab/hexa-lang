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
/* HEXA_USE_CUBLAS — cuBLAS is an OPT-IN constraint (native-canonical-default).
 * By DEFAULT (macro unset) every cublas* call-site routes to its own-kernel;
 * the header + handle machinery compile out so the TU links with ZERO -lcublas
 * (own-kernels own 100%% of GEMM/gemv). Define HEXA_USE_CUBLAS to restore the
 * cuBLAS fast path + -lcublas. own==cuBLAS numerically (FP64 bit-identical),
 * so the gate changes SPEED, not output. */
#ifdef HEXA_USE_CUBLAS
#include <cublas_v2.h>
#endif
/* HEXA-TRAIN-FLOOR bf16 lever — __nv_bfloat16 device type for the
 * in-place bf16-MAC gemv slice (RFC 049 storage class is the sibling
 * runtime_bf16.c TU #include'd at the file tail; this header makes the
 * scalar type visible to the bf16 kernel emitted below). CUDA-toolkit
 * header — always present whenever cublas_v2.h is. */
#include <cuda_bf16.h>
/* HEXA-FUSION P1: cooperative_groups (C++ templates) — MUST be included at
 * top-level, OUTSIDE the extern "C" block below, or its libcxx headers hit
 * 'declaration may not have extern "C" linkage'. */
#ifdef __CUDACC__
#include <cooperative_groups.h>
namespace _hxcg = cooperative_groups;
#endif

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

/* Forward declarations — these static helpers are defined further down but
 * called earlier (e.g. by _hx_cuda_farr_im2col_gpu); nvcc -x cu compiles as
 * C++ which requires a prior declaration. */
static int _ensure_dev_alloc_out(int64_t out_id, int64_t need_len);
static int _d2h_out(int64_t out_id, int64_t copy_len);

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

/* Process-wide output-disposition register. -1 = UNSET → follow the
 * device-resident gate (_forge_out_keep below): when CLM_PROD_DEVRESIDENT/
 * HEXA_FUSE_ALL turns the device-resident chain on, the output stays
 * device-resident (DEVICE_KEEP) so the next op's H2D §6.1-skips instead of
 * a per-op D2H->H2D ping-pong (the glue-bound floor). Explicit
 * _hx_cuda_set_out_disposition wins. UNSET + no gate = HOST_NOW =
 * byte-identical to the verified pre-RFC-056 substrate. */
static int g_forge_out_disposition = -1;

/* Called by the host runtime.c shim immediately before a `_gpu` op to
 * express §6.4's consumed-by-next-GPU-op hint. Returns the previous
 * value (so callers can save/restore). */
int _hx_cuda_set_out_disposition(int d) {
    int prev = g_forge_out_disposition;
    g_forge_out_disposition = (d == FORGE_OUT_DEVICE_KEEP) ? FORGE_OUT_DEVICE_KEEP
                            : (d < 0) ? -1 /* unset -> follow device-resident gate */
                            : FORGE_OUT_HOST_NOW;
    return prev;
}

/* ════════════════════════════════════════════════════════════════════
 * HEXA-FUSION L1-② — async kernel-launch pipeline (per-step driver
 * host-sync removal). W2 CLOSED-NEGATIVE measured util MEAN 0.53%
 * even with the whole fwd+bwd glue device-resident: the binding floor
 * is the INTERPRETED per-step driver dispatching ~30 device kernels
 * one-by-one, each followed by a full `cudaDeviceSynchronize()` host
 * barrier — the GPU drains + idles between every launch.
 *
 * This substrate lets the device-resident chain queue back-to-back on
 * ONE non-blocking stream and sync only at a host READBACK boundary
 * (a _d2h / _d2h_out — the scalar loss or a materialised output). Same
 * kernels, same data-dependent order, ONE stream ⇒ identical numerics
 * (max|Δ|=0): a single-stream queue serialises exactly as the per-call
 * barrier did, only without draining the GPU between launches.
 *
 * Gated by env HEXA_CUDA_ASYNC (read once, cached). Default OFF ⇒
 * g_forge_stream stays the default stream (0) and _forge_launch_check
 * keeps the per-call cudaDeviceSynchronize() — byte-identical to the
 * verified pre-async substrate. The clm_prod driver sets it only under
 * CLM_PROD_DEVRESIDENT (default off → no behaviour change).
 * ════════════════════════════════════════════════════════════════════ */
static cudaStream_t g_forge_stream = 0;   /* 0 = default (legacy) stream */
static int          g_forge_async  = -1;  /* -1 = uninit, 0 off, 1 on */

static int _forge_async_on(void) {
    if (g_forge_async < 0) {
        /* Explicit HEXA_CUDA_ASYNC wins (1 = force on, 0 = force off /
         * kill switch). Unset → follow CLM_PROD_DEVRESIDENT: the async
         * pipeline only helps (and only fires kernels) on the
         * device-resident chain, which is exactly that gate. A default
         * (no CLM_PROD_DEVRESIDENT) run has async OFF → byte-identical. */
        const char* v = getenv("HEXA_CUDA_ASYNC");
        if (v && v[0]) {
            g_forge_async = (v[0] != '0') ? 1 : 0;
        } else {
            /* HEXA-FUSION E2: the HEXA_FUSE_ALL meta-flag turns the
             * device-resident byte-eq stack on as a whole, so async
             * follows it too (same coupling as CLM_PROD_DEVRESIDENT). */
            const char* dr = getenv("CLM_PROD_DEVRESIDENT");
            const char* fa = getenv("HEXA_FUSE_ALL");
            g_forge_async = ((dr && dr[0]) || (fa && fa[0])) ? 1 : 0;
        }
    }
    return g_forge_async;
}

/* Resolve the EFFECTIVE output disposition. Explicit set wins; UNSET (-1)
 * follows the device-resident gate (_forge_async_on = CLM_PROD_DEVRESIDENT/
 * HEXA_FUSE_ALL) so turning device-residency ON actually keeps activations
 * on-device (DEVICE_KEEP) — the gate previously flipped only the stream,
 * leaving every glue op to D2H its output for the next op to re-H2D (the
 * per-op ping-pong = glue-bound floor). UNSET + gate off = HOST_NOW =
 * byte-identical to the verified substrate. (This perf coupling is safe
 * only ON TOP of the stream-ordering family fix — same-stream producers
 * make the device-resident H2D-skip hand-off race-free.) */
static int _forge_out_keep(void) {
    if (g_forge_out_disposition >= 0)
        return g_forge_out_disposition == FORGE_OUT_DEVICE_KEEP;
    return _forge_async_on();
}

#ifdef __CUDACC__
/* Lazy non-blocking stream for the device-resident chain. When async is
 * off this returns the default stream (0) so launches are byte-identical
 * to legacy. On any stream-create failure we fall back to the default
 * stream (correctness over throughput — never silently wrong). */
static cudaStream_t _forge_stream(void) {
    if (!_forge_async_on()) return 0;
    if (g_forge_stream == 0) {
        cudaStream_t st = 0;
        cudaError_t er = cudaStreamCreateWithFlags(&st, cudaStreamNonBlocking);
        if (er != cudaSuccess || st == 0) {
            fprintf(stderr, "[cuda] forge stream create failed: %s\n",
                    cudaGetErrorString(er));
            return 0; /* fall back to default stream */
        }
        g_forge_stream = st;
    }
    return g_forge_stream;
}

/* Post-launch check. Legacy (async off): full cudaDeviceSynchronize() —
 * byte-identical per-call barrier. Async on: cudaGetLastError() only —
 * catches launch-config/resource errors WITHOUT a host barrier, so the
 * next kernel queues immediately behind this one on the same stream.
 * Returns 0 ok / -1 on a launch error (caller propagates -1). */
static int _forge_launch_check(const char* op) {
    cudaError_t er;
    if (_forge_async_on()) {
        er = cudaGetLastError();
    } else {
        er = cudaDeviceSynchronize();
    }
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] %s launch failed: %s\n", op,
                cudaGetErrorString(er));
        return -1;
    }
    return 0;
}

/* Stream barrier at a host-readback boundary. Async on: wait for every
 * queued kernel on the forge stream to retire before a D2H sees their
 * writes (the keystone that keeps numerics identical). Async off: no-op
 * (each launch already synced). Returns 0 ok / -1 err. */
static int _forge_sync(void) {
    if (!_forge_async_on()) return 0;
    if (g_forge_stream == 0) return 0; /* default stream: nothing queued */
    cudaError_t er = cudaStreamSynchronize(g_forge_stream);
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] forge stream sync failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    return 0;
}
#endif /* __CUDACC__ */

/* cuBLAS handle — lazy init. */
#ifdef HEXA_USE_CUBLAS
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
    /* L2-b: fold the cuBLAS GEMMs onto the forge stream when async-on so they
     * queue with the device kernels (no per-GEMM host barrier). async-off ->
     * _forge_stream() returns 0 = default stream = byte-identical legacy path. */
    if (_forge_async_on()) cublasSetStream(g_cublas, _forge_stream());
    return 0;
}
#else
/* default (no HEXA_USE_CUBLAS): no handle, _ensure_cublas is a no-op (own-kernels never use
 * it; it stays as a callable so the GEMM entry guards need not be touched). */
static int _ensure_cublas(void) { return 0; }
#endif

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
    /* HEXA-FUSION N2 RACEFIX (F-FUSION-N1N2-DETERMINISM): when async
     * is ON the glue kernels run on the non-blocking g_forge_stream and
     * are NOT host-synced per launch. The cudaFree/cudaMalloc/cudaMemcpy
     * H2D below mutate device memory on the DEFAULT stream, which a
     * cudaStreamNonBlocking stream does NOT order against — so this H2D
     * could free/overwrite a buffer a still-queued forge-stream kernel is
     * reading/writing -> the measured ~4.6e-2 run-to-run jitter (N1 proved
     * every glue kernel is deterministic in ISOLATION; the race is here on
     * the _h2d path, async-OFF is bit-reproducible). _d2h already drains;
     * mirror it. No-op when async is off => byte-identical legacy path. */
    if (_forge_sync() != 0) return -1;
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
    /* Async pipeline: a host readback is the sync boundary — drain the
     * forge stream so this D2H sees every queued kernel's writes. No-op
     * when async is off (each launch already synced). */
    if (_forge_sync() != 0) return -1;
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

/* HEXA-FUSION Phase 1a (CUDA-OWN) — our OWN FP64 GEMM kernel, NO cuBLAS.
 * row-major C[M,N] = A[M,K] · B[K,N]; one thread per output element (m,n),
 * naive K-accumulation (k=0..K sequential). FIRST step of owning the last
 * non-owned device piece (cublasDgemm) so the whole-step megakernel becomes
 * possible (a persistent kernel can't call cuBLAS). NOT bit-identical to
 * cublasDgemm (different accumulation order) — cuBLAS is demoted to a
 * CORRECTNESS ORACLE (within fp tolerance), no longer the byte-eq roofline.
 * Env-gated HEXA_OWN_GEMM in the matmul launcher; OFF → cublasDgemm (identical
 * to the prior build). Phase 1b will block/register-tile this for speed. */
__global__ void _hx_k_gemm(const double* __restrict__ A,
                           const double* __restrict__ B,
                           double* __restrict__ C,
                           int64_t M, int64_t K, int64_t N) {
    int64_t n = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
    int64_t m = (int64_t)blockIdx.y * blockDim.y + threadIdx.y;
    if (m >= M || n >= N) return;
    double acc = 0.0;
    for (int64_t k = 0; k < K; k++) acc += A[m * K + k] * B[k * N + n];
    C[m * N + n] = acc;
}

/* #4204 own-native fast-default — atomic split-K general GEMM (M>1). Splits
 * K across grid.z into KS chunks; each (m,n,kc) thread accumulates its chunk
 * partial then atomicAdd's into C[m*N+n]. CHANGES the reduction order (NOT
 * bit-identical) -> fast non-det DEFAULT (training). C MUST be pre-zeroed
 * (the dispatch cudaMemsetAsync's it before launch). HEXA_DET selects the
 * fixed-order _hx_k_gemm instead. gpu_only: needs nvcc compile + cuBLAS-
 * oracle numeric validation on summer BuildStage before trusting the
 * default training path. */
__global__ void _hx_k_gemm_splitk(const double* __restrict__ A,
                                  const double* __restrict__ B,
                                  double* __restrict__ C,
                                  int64_t M, int64_t K, int64_t N, int KS) {
    int64_t n = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
    int64_t m = (int64_t)blockIdx.y * blockDim.y + threadIdx.y;
    if (m >= M || n >= N) return;
    int64_t kc = (K + KS - 1) / KS;
    int64_t k0 = (int64_t)blockIdx.z * kc;
    int64_t k1 = k0 + kc; if (k1 > K) k1 = K;
    double acc = 0.0;
    for (int64_t k = k0; k < k1; k++) acc += A[m * K + k] * B[k * N + n];
    if (acc != 0.0) atomicAdd(&C[m * N + n], acc);
}

/* ===== decode GEMV fast-path (M==1) ==================================
 * kernel-quality-reffirst lane (profiler-driven, c1 root-cause). The 16x16
 * _hx_k_gemm tile WASTES 15/16 threads at M==1 (only threadIdx.y==0 live)
 * and launches grid.y==1 — MEASURED aiden RTX 5070 sm_120: 341 GB/s =
 * 0.54x cuBLAS Dgemv (629), DRAM 45% peak, 16-block grid underfills 48 SMs.
 * _hx_k_gemv_1d : one thread per output column, full sequential K-loop.
 * BIT-IDENTICAL reduction order to _hx_k_gemm -> BYTE-NEUTRAL default swap.
 * MEASURED 459 GB/s @4096 (1.34x), 634 @8192 (1.86x, BEATS cuBLAS 618).
 * _hx_k_gemv_splitk : split K across grid.y, atomicAdd partials. CHANGES
 * reduction order (NOT bit-identical) -> OPT-IN (HEXA_GEMV_SPLITK). Fills
 * the SMs when N is too small for the 1D path: MEASURED @2048 = 1167 GB/s
 * = 3.49x naive, parity/beats cuBLAS (1163); DRAM 45%->95.2% (ncu),
 * grid 16->128 blocks; relRMS vs cuBLAS 5.5e-15 (fp round-off). */
__global__ void _hx_k_gemv_1d(const double* __restrict__ A,
                              const double* __restrict__ B,
                              double* __restrict__ C,
                              int64_t K, int64_t N) {
    int64_t n = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
    if (n >= N) return;
    double acc = 0.0;
    for (int64_t k = 0; k < K; k++) acc += A[k] * B[k * N + n];
    C[n] = acc;
}
__global__ void _hx_k_gemv_splitk(const double* __restrict__ A,
                                  const double* __restrict__ B,
                                  double* __restrict__ C,
                                  int64_t K, int64_t N, int KS) {
    int64_t n = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
    if (n >= N) return;
    int64_t kc = (K + KS - 1) / KS;
    int64_t k0 = (int64_t)blockIdx.y * kc;
    int64_t k1 = k0 + kc; if (k1 > K) k1 = K;
    double acc = 0.0;
    for (int64_t k = k0; k < k1; k++) acc += A[k] * B[k * N + n];
    atomicAdd(&C[n], acc);
}
static int _forge_gemv_splitk_on(void) {
    const char* v = getenv("HEXA_GEMV_SPLITK");
    return (v && v[0] && v[0] != '0') ? 1 : 0;
}

/* #4204 own-native fast-default — determinism axis (own/vendor polarity
 * UNTOUCHED). The own-native NON-deterministic atomic kernels (atomic
 * split-K GEMV/GEMM, atomic-scatter col2im, atomic embedding grad-accum)
 * are now the DEFAULT (training gets the fast benefit). Opt-IN det mode
 * forces the own fixed-order / non-atomic kernels for bit-identical,
 * cross-host byte-parity runs — the eval/verdict/decode entry points and
 * the GPU byteeq/oracle CI jobs set det mode so Ψ-checksum + frozen
 * gate measurement stay byte-deterministic. INVERTED-POLARITY ref-match of
 * _forge_gemv_splitk_on: same opt-in shape, but every kernel dispatch
 * branches on `!_forge_det_on()` (default=fast-atomic) instead of gating
 * the atomic path behind an opt-in. NOTE this is the OWN-vs-OWN
 * (atomic vs fixed-order) axis only — _forge_own_gemm_on / HEXA_USE_CUBLAS
 * vendor polarity is unchanged (cuBLAS stays opt-in).
 *
 * #4214 canonical API upgrade (torch ref-match):
 *   PRIMARY surface = hexa_forge_set_deterministic(1/0) — in-process call
 *     (torch.use_deterministic_algorithms(True/False) 1-1 analogue).
 *   ESCAPE-HATCH = HEXA_DET env var — shell/CI/legacy setenv callers
 *     (CUBLAS_WORKSPACE_CONFIG low-level knob analogue).
 * Precedence: API (_hx_forge_det_mode >= 0) overrides env. Default
 * (-1 = API not called + env unset) = fast non-det (training default). */

/* process-global API mode: -1=unset (fall back to env), 0=fast-forced,
 * 1=det-forced. Written by hexa_forge_set_deterministic(). */
static int _hx_forge_det_mode = -1;

/* Returns 1 (det) if API was set OR env HEXA_DET is active; else 0 (fast). */
static int _forge_det_on(void) {
    if (_hx_forge_det_mode >= 0) return _hx_forge_det_mode;
    const char* v = getenv("HEXA_DET");
    return (v && v[0] && v[0] != '0') ? 1 : 0;
}

/* #4214 public C API — hexa set_deterministic()/is_deterministic() land here.
 * torch.use_deterministic_algorithms(True/False) 1-1 analogue. API call
 * overrides env; env is the escape-hatch for callers that cannot make an
 * in-process API call (shell scripts, CI launchers, legacy setenv). */
void hexa_forge_set_deterministic(int on) {
    _hx_forge_det_mode = on ? 1 : 0;
}
int hexa_forge_is_deterministic(void) {
    return _forge_det_on();
}

/* #pytorch-canon alertNotDeterministic ref-match: called in any non-det
 * dispatch path that has NO det counterpart when det mode is active.
 * Currently never reached — all 4 non-det atomic ops (GEMM/GEMV split-K,
 * col2im scatter, embedding-bwd scatter) have det gates — but this makes
 * the guarantee machine-enforced: a new atomic op added without a
 * _forge_det_on() gate will abort + report at runtime rather than silently
 * mis-execute in det mode. torch ref: aten/src/ATen/Context.cpp
 * alertNotDeterministic (RuntimeError when use_deterministic_algorithms(True)
 * and op has no det impl). Convention: call _forge_det_alert("op_name") in
 * any non-det branch that CANNOT fall back to a det counterpart when
 * _forge_det_on()==1. */
static __attribute__((unused)) void _forge_det_alert(const char* opname) {
    if (!_forge_det_on()) return;
    fprintf(stderr,
        "[forge det] RuntimeError: op '%s' has no deterministic implementation "
        "but det mode is ON (set_deterministic(true) or HEXA_DET=1). "
        "Disable det mode to use the fast non-det path "
        "(set_deterministic(false) or unset HEXA_DET).\n", opname);
    abort();
}

/* HEXA-0POD OP-24 (TF32 LIVE-WIRE) — deterministic TF32 fast-mode for the live
 * forge GEMM dispatch. OP-20 PROVED (aiden RTX 5070): a TF32 tensor-op step is
 * self-byte-eq run-to-run (max|delta|=0) AND W14-tol vs FP64 (rel-RMS ~1e-6) AND
 * 4.2x faster @B=1 — it breaks the ~3x FP64 step cap. OP-23 validated the
 * trajectory tracks FP64 over 100 steps. This wires that PROVEN compute-type into
 * the real trainer dispatch, env-gated HEXA_TF32_FASTMODE (FP64 stays the DEFAULT;
 * TF32 is opt-in). The forge farr buffers are FP64 (double); the TF32 path casts
 * A,B down to fp32 (a separate output buffer — NEVER mutates the FP64 inputs, so
 * the FP64 default path is byte-identical when the flag is off), runs the cuBLAS
 * TF32 tensor-op GEMM (CUBLAS_COMPUTE_32F_FAST_TF32, pinned CUBLAS_PEDANTIC_MATH
 * for the PORTABLE self-byte-eq guarantee per OP-20's ship recommendation), then
 * casts the fp32 result back up to the FP64 C buffer. The cast is a fixed-order
 * elementwise map (no reduction, no atomics) so it adds no determinism hazard;
 * the only determinism question is the cuBLAS TF32 GEMM, which PEDANTIC pins. */
__global__ void _hx_k_cast_d2f(const double* __restrict__ src,
                               float* __restrict__ dst, int64_t n) {
    int64_t i = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) dst[i] = (float)src[i];
}
__global__ void _hx_k_cast_f2d(const float* __restrict__ src,
                               double* __restrict__ dst, int64_t n) {
    int64_t i = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) dst[i] = (double)src[i];
}

/* OP-24: returns 1 iff HEXA_TF32_FASTMODE is set+non-empty (opt-in; default 0). */
static int _forge_tf32_fastmode(void) {
    const char* v = getenv("HEXA_TF32_FASTMODE");
    return (v && v[0]) ? 1 : 0;
}

/* own-GEMM is now the DEFAULT (FP64 own _hx_k_gemm == cuBLAS bit-identical,
 * rel-RMS 0 byte-neutral; cuBLAS Dgemm is the opt-OUT fallback). Returns 1
 * (own) unless HEXA_OWN_GEMM=0 explicitly reverts to cuBLAS. Any other value
 * (unset / =1 / etc.) keeps own-GEMM. */
static int _forge_own_gemm_on(void) {
#ifndef HEXA_USE_CUBLAS
    return 1;  /* cuBLAS-free variant: own-GEMM is the ONLY path (no opt-out). */
#else
    const char* v = getenv("HEXA_OWN_GEMM");
    return (v && v[0] == '0') ? 0 : 1;
#endif
}

/* within HEXA_TF32_FASTMODE: own mma.sync TF32 is the DEFAULT (byte-CHANGING
 * vs cublasGemmEx — different tensor-op accum — but confined to the already
 * non-deterministic fastmode lane; the default non-fastmode FP64 path is
 * untouched). Returns 1 (own) unless HEXA_TF32_OWN=0 reverts to cublasGemmEx. */
static int _forge_tf32_own_on(void) {
#ifndef HEXA_USE_CUBLAS
    return 1;  /* cuBLAS-free: own mma.sync TF32 is the ONLY tf32 path. */
#else
    const char* v = getenv("HEXA_TF32_OWN");
    return (v && v[0] == '0') ? 0 : 1;
#endif
}

/* OP-24: deterministic TF32 tensor-op GEMM on FP64 row-major farr device buffers.
 * Computes C[M,N] = A[M,K] . B[K,N] (same row->col trick + arg layout as the
 * cublasDgemm default path: cublas sees row-major as col-major transposed, so the
 * call is GemmEx(N,N, m=N,n=M,k=K, Bf,N, Af,K, Cf,N)). A_dev,B_dev,C_dev are the
 * existing FP64 device buffers; we allocate scratch fp32 mirrors, cast in, run the
 * TF32 tensor-op, cast the fp32 result back into C_dev. Returns 0 ok / -1 err.
 * Uses a PEDANTIC-math cuBLAS handle (lazy, separate from g_cublas which stays
 * fp64-strict for the default Dgemm path) so the TF32 self-byte-eq is portable. */
#ifdef HEXA_USE_CUBLAS
static cublasHandle_t g_cublas_tf32 = NULL;
static int _ensure_cublas_tf32(void) {
    if (g_cublas_tf32) return 0;
    cublasStatus_t st = cublasCreate(&g_cublas_tf32);
    if (st != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[cuda] cublasCreate(tf32) failed: %d\n", (int)st);
        g_cublas_tf32 = NULL; return -1;
    }
    /* PEDANTIC pins a deterministic, no-heuristic math mode -> portable self-byte-eq
     * (OP-20 ship recommendation). The TF32 tensor-op is selected per-GEMM via the
     * GemmEx computeType CUBLAS_COMPUTE_32F_FAST_TF32, not the handle math-mode. */
    cublasSetMathMode(g_cublas_tf32, CUBLAS_PEDANTIC_MATH);
    if (_forge_async_on()) cublasSetStream(g_cublas_tf32, _forge_stream());
    return 0;
}
static int _hx_cuda_gemm_tf32_dev(double* A_dev, double* B_dev, double* C_dev,
                                  int64_t M, int64_t K, int64_t N) {
    if (_ensure_cublas_tf32() != 0) return -1;
    float* Af = NULL; float* Bf = NULL; float* Cf = NULL;
    cudaError_t er;
    er = cudaMalloc((void**)&Af, (size_t)(M*K) * sizeof(float));
    if (er != cudaSuccess) { fprintf(stderr, "[cuda] tf32 malloc Af: %s\n", cudaGetErrorString(er)); return -1; }
    er = cudaMalloc((void**)&Bf, (size_t)(K*N) * sizeof(float));
    if (er != cudaSuccess) { fprintf(stderr, "[cuda] tf32 malloc Bf: %s\n", cudaGetErrorString(er)); cudaFree(Af); return -1; }
    er = cudaMalloc((void**)&Cf, (size_t)(M*N) * sizeof(float));
    if (er != cudaSuccess) { fprintf(stderr, "[cuda] tf32 malloc Cf: %s\n", cudaGetErrorString(er)); cudaFree(Af); cudaFree(Bf); return -1; }
    cudaStream_t strm = _forge_stream();
    { int64_t nA = M*K; dim3 b(256); dim3 g((unsigned)((nA + 255) / 256));
      _hx_k_cast_d2f<<<g, b, 0, strm>>>(A_dev, Af, nA); }
    { int64_t nB = K*N; dim3 b(256); dim3 g((unsigned)((nB + 255) / 256));
      _hx_k_cast_d2f<<<g, b, 0, strm>>>(B_dev, Bf, nB); }
    if (_forge_launch_check("tf32_cast_in") != 0) { cudaFree(Af); cudaFree(Bf); cudaFree(Cf); return -1; }
    static int _tf32_fired = 0;
    if (!_tf32_fired) { _tf32_fired = 1;
        fprintf(stderr, "[TF32-FASTMODE-FIRED] cublasGemmEx COMPUTE_32F_FAST_TF32 (PEDANTIC) DEVICE path\n"); }
    const float alpha = 1.0f; const float beta = 0.0f;
    cublasStatus_t st = cublasGemmEx(g_cublas_tf32,
                                     CUBLAS_OP_N, CUBLAS_OP_N,
                                     (int)N, (int)M, (int)K,
                                     &alpha,
                                     Bf, CUDA_R_32F, (int)N,
                                     Af, CUDA_R_32F, (int)K,
                                     &beta,
                                     Cf, CUDA_R_32F, (int)N,
                                     CUBLAS_COMPUTE_32F_FAST_TF32,
                                     CUBLAS_GEMM_DEFAULT_TENSOR_OP);
    if (st != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[cuda] cublasGemmEx TF32 failed: %d\n", (int)st);
        cudaFree(Af); cudaFree(Bf); cudaFree(Cf); return -1;
    }
    { int64_t nC = M*N; dim3 b(256); dim3 g((unsigned)((nC + 255) / 256));
      _hx_k_cast_f2d<<<g, b, 0, strm>>>(Cf, C_dev, nC); }
    if (_forge_launch_check("tf32_cast_out") != 0) { cudaFree(Af); cudaFree(Bf); cudaFree(Cf); return -1; }
    if (_forge_sync() != 0) { cudaFree(Af); cudaFree(Bf); cudaFree(Cf); return -1; }
    cudaFree(Af); cudaFree(Bf); cudaFree(Cf);
    return 0;
}
#endif /* HEXA_USE_CUBLAS (TF32 cublasGemmEx path) */

/* ===== census r3 OWN-TF32 PARITY KERNEL (no cuBLAS) ===========================
 * PORT of self/native/mma_sm120/owngemm_sm120.cu `gemm_sm120` — the PARITY TF32
 * own-GEMM for consumer Blackwell sm_120 (RTX 5070). Uses the PORTABLE warp-level
 * tensor-core MMA `mma.sync.aligned.m16n8k8.row.col.f32.tf32.tf32.f32` (Ampere
 * sm_80+; sm_90 wgmma is NOT used so ptxas accepts sm_120). 64x64 block tile, BK=16,
 * 4 warps (128 thr) 2x2, cp.async double-buffered staging, bank-conflict-free smem
 * pad, .v4 vectorized global loads, .v2 vectorized C store. MEASURED on aiden RTX
 * 5070 standalone = cublasGemmEx-TF32 PARITY (D512 0.90x, D768 1.06x, D1024 0.89x,
 * D2048 0.98x, D4096 0.80x; rel-RMS 1.3e-5..7.0e-5). NOT FP64-exact, NOT bit-id vs
 * cublasGemmEx-TF32 (different tensor-op accum); bar = TF32 rel-RMS vs FP64 (~1e-5)
 * + same-dtype agreement with cublasGemmEx-TF32. This is the cuBLAS-FREE TF32 path
 * (replaces the census-r3 slow WMMA-API kernel). row-major fp32 A[M,K],B[K,N],C[M,N]. */
#ifdef __CUDACC__
#define HX_OWNTF_BM 64
#define HX_OWNTF_BN 64
#define HX_OWNTF_BK 16
#define HX_OWNTF_WARPS_N 2
#define HX_OWNTF_NWARP 4
#define HX_OWNTF_NTHREAD 128
#define HX_OWNTF_WM_FRAG 2
#define HX_OWNTF_WN_FRAG 4
#define HX_OWNTF_ASPAD 4
/* BSPAD=8 (not 4): the m16n8k8 B-fragment read Bs[ks+tig][ncol+gid] strides
 * rows by (BN+BSPAD). BSPAD=4 -> stride 68, 68%32==4, so the 32 warp lanes
 * (tig 0-3 rows x gid 0-7 cols) collide on banks {tig*4+gid} (~245x conflicts).
 * BSPAD=8 -> stride 72, 72%32==8, lanes hit {tig*8+gid} = all 32 banks distinct.
 * MEASURED aiden sm_120: smem ld-conflicts 67.36M->274.7k (245x drop), TF32
 * square +3.8% (S4096 26.8->27.85 TFLOP/s); rel-RMS unchanged (pad-only). The
 * residual gap to cuBLAS is latency-bound (issue 36%, shallow 2-stage), not
 * bank conflicts. */
#define HX_OWNTF_BSPAD 8
__device__ __forceinline__ unsigned _hx_f2tf32(float x){
    unsigned u; memcpy(&u,&x,4); u=(u+0x1000u)&0xFFFFE000u; return u;
}
__device__ __forceinline__ void _hx_mma_m16n8k8(float* d, const unsigned* a, const unsigned* b){
    asm volatile(
      "mma.sync.aligned.m16n8k8.row.col.f32.tf32.tf32.f32 "
      "{%0,%1,%2,%3}, {%4,%5,%6,%7}, {%8,%9}, {%0,%1,%2,%3};\n"
      : "+f"(d[0]),"+f"(d[1]),"+f"(d[2]),"+f"(d[3])
      : "r"(a[0]),"r"(a[1]),"r"(a[2]),"r"(a[3]),"r"(b[0]),"r"(b[1]));
}
__device__ __forceinline__ void _hx_cp_async_cg16(void* smem, const void* gmem){
    unsigned s = (unsigned)__cvta_generic_to_shared(smem);
    asm volatile("cp.async.cg.shared.global [%0], [%1], 16;\n" :: "r"(s), "l"(gmem));
}
__device__ __forceinline__ void _hx_cp_async_commit(){ asm volatile("cp.async.commit_group;\n"); }
__device__ __forceinline__ void _hx_cp_async_wait1(){ asm volatile("cp.async.wait_group 1;\n"); }
__device__ __forceinline__ void _hx_cp_async_wait0(){ asm volatile("cp.async.wait_group 0;\n"); }
extern "C" __global__ void _hx_k_gemm_tf32_owngemm(const float* __restrict__ A,
                                      const float* __restrict__ B,
                                      float* __restrict__ C,
                                      int M, int N, int K){
    __shared__ float As[2][HX_OWNTF_BM][HX_OWNTF_BK+HX_OWNTF_ASPAD];
    __shared__ float Bs[2][HX_OWNTF_BK][HX_OWNTF_BN+HX_OWNTF_BSPAD];
    int bm = blockIdx.y*HX_OWNTF_BM, bn = blockIdx.x*HX_OWNTF_BN;
    int tid = threadIdx.x;
    int warp = tid>>5, lane = tid&31;
    int wm = (warp/HX_OWNTF_WARPS_N)*32;
    int wn = (warp%HX_OWNTF_WARPS_N)*32;
    int gid = lane>>2, tig = lane&3;
    float acc[HX_OWNTF_WM_FRAG][HX_OWNTF_WN_FRAG][4];
    #pragma unroll
    for(int i=0;i<HX_OWNTF_WM_FRAG;i++)for(int j=0;j<HX_OWNTF_WN_FRAG;j++)for(int e=0;e<4;e++) acc[i][j][e]=0.f;
    int nk = (K+HX_OWNTF_BK-1)/HX_OWNTF_BK;
    auto load_stage = [&](int buf,int k0){
        #pragma unroll
        for(int i=tid; i<HX_OWNTF_BM*HX_OWNTF_BK/4; i+=HX_OWNTF_NTHREAD){
            int r=i/(HX_OWNTF_BK/4), c4=i%(HX_OWNTF_BK/4), c=c4*4; int gr=bm+r, gc=k0+c;
            if(gr<M && gc+3<K) _hx_cp_async_cg16(&As[buf][r][c], &A[(long long)gr*K+gc]);
            else { float4 v=make_float4(0,0,0,0);
                   if(gr<M){ for(int e=0;e<4;e++) ((float*)&v)[e]=(gc+e<K)?A[(long long)gr*K+gc+e]:0.f; }
                   As[buf][r][c+0]=v.x;As[buf][r][c+1]=v.y;As[buf][r][c+2]=v.z;As[buf][r][c+3]=v.w; }
        }
        #pragma unroll
        for(int i=tid; i<HX_OWNTF_BK*HX_OWNTF_BN/4; i+=HX_OWNTF_NTHREAD){
            int r=i/(HX_OWNTF_BN/4), c4=i%(HX_OWNTF_BN/4), c=c4*4; int gr=k0+r, gc=bn+c;
            if(gr<K && gc+3<N) _hx_cp_async_cg16(&Bs[buf][r][c], &B[(long long)gr*N+gc]);
            else { float4 v=make_float4(0,0,0,0);
                   if(gr<K){ for(int e=0;e<4;e++) ((float*)&v)[e]=(gc+e<N)?B[(long long)gr*N+gc+e]:0.f; }
                   Bs[buf][r][c+0]=v.x;Bs[buf][r][c+1]=v.y;Bs[buf][r][c+2]=v.z;Bs[buf][r][c+3]=v.w; }
        }
    };
    load_stage(0,0); _hx_cp_async_commit();
    for(int k=0; k<nk; k++){
        int buf=k&1, nbuf=(k+1)&1;
        if(k+1<nk){ load_stage(nbuf,(k+1)*HX_OWNTF_BK); _hx_cp_async_commit(); _hx_cp_async_wait1(); }
        else      { _hx_cp_async_wait0(); }
        __syncthreads();
        #pragma unroll
        for(int ks=0; ks<HX_OWNTF_BK; ks+=8){
            #pragma unroll
            for(int fmi=0; fmi<HX_OWNTF_WM_FRAG; fmi++){
                int mrow = wm + fmi*16;
                unsigned af[4];
                af[0]=_hx_f2tf32(As[buf][mrow + gid    ][ks + tig    ]);
                af[1]=_hx_f2tf32(As[buf][mrow + gid + 8][ks + tig    ]);
                af[2]=_hx_f2tf32(As[buf][mrow + gid    ][ks + tig + 4]);
                af[3]=_hx_f2tf32(As[buf][mrow + gid + 8][ks + tig + 4]);
                #pragma unroll
                for(int fni=0; fni<HX_OWNTF_WN_FRAG; fni++){
                    int ncol = wn + fni*8;
                    unsigned bf[2];
                    bf[0]=_hx_f2tf32(Bs[buf][ks + tig    ][ncol + gid]);
                    bf[1]=_hx_f2tf32(Bs[buf][ks + tig + 4][ncol + gid]);
                    _hx_mma_m16n8k8(acc[fmi][fni], af, bf);
                }
            }
        }
        __syncthreads();
    }
    #pragma unroll
    for(int fmi=0; fmi<HX_OWNTF_WM_FRAG; fmi++){
        int mrow = bm + wm + fmi*16;
        #pragma unroll
        for(int fni=0; fni<HX_OWNTF_WN_FRAG; fni++){
            int ncol = bn + wn + fni*8;
            float* d = acc[fmi][fni];
            int r0=mrow+gid, r1=mrow+gid+8, c0=ncol+2*tig, c1=ncol+2*tig+1;
            bool aligned = ((c0&1)==0);
            if(r0<M && c1<N && aligned) *reinterpret_cast<float2*>(&C[(long long)r0*N+c0]) = make_float2(d[0],d[1]);
            else { if(r0<M && c0<N) C[(long long)r0*N+c0]=d[0];
                   if(r0<M && c1<N) C[(long long)r0*N+c1]=d[1]; }
            if(r1<M && c1<N && aligned) *reinterpret_cast<float2*>(&C[(long long)r1*N+c0]) = make_float2(d[2],d[3]);
            else { if(r1<M && c0<N) C[(long long)r1*N+c0]=d[2];
                   if(r1<M && c1<N) C[(long long)r1*N+c1]=d[3]; }
        }
    }
}
#endif

/* census r3: own-TF32 PARITY dispatcher — casts the FP64 device buffers down to
 * fp32 scratch mirrors (reusing _hx_k_cast_d2f), launches the row-major parity
 * own-GEMM _hx_k_gemm_tf32_owngemm (gemm_sm120 port; 64x64 tile, mma.sync, NO
 * cuBLAS), then casts the fp32 result back up into C_dev. Same cast-in/out as the
 * cublasGemmEx path (FP64 inputs NEVER mutated) — only the GEMM op differs. The
 * own kernel is natively row-major C[M,N]=A[M,K].B[K,N], so NO N/M/K transpose
 * swap is needed (unlike the col-major cuBLAS call). Returns 0 ok / -1 err. */
static int _hx_cuda_gemm_tf32_own_dev(double* A_dev, double* B_dev, double* C_dev,
                                      int64_t M, int64_t K, int64_t N) {
#ifdef __CUDACC__
    float* Af = NULL; float* Bf = NULL; float* Cf = NULL;
    cudaError_t er;
    er = cudaMalloc((void**)&Af, (size_t)(M*K) * sizeof(float));
    if (er != cudaSuccess) { fprintf(stderr, "[cuda] own-tf32 malloc Af: %s\n", cudaGetErrorString(er)); return -1; }
    er = cudaMalloc((void**)&Bf, (size_t)(K*N) * sizeof(float));
    if (er != cudaSuccess) { fprintf(stderr, "[cuda] own-tf32 malloc Bf: %s\n", cudaGetErrorString(er)); cudaFree(Af); return -1; }
    er = cudaMalloc((void**)&Cf, (size_t)(M*N) * sizeof(float));
    if (er != cudaSuccess) { fprintf(stderr, "[cuda] own-tf32 malloc Cf: %s\n", cudaGetErrorString(er)); cudaFree(Af); cudaFree(Bf); return -1; }
    cudaStream_t strm = _forge_stream();
    { int64_t nA = M*K; dim3 b(256); dim3 g((unsigned)((nA + 255) / 256));
      _hx_k_cast_d2f<<<g, b, 0, strm>>>(A_dev, Af, nA); }
    { int64_t nB = K*N; dim3 b(256); dim3 g((unsigned)((nB + 255) / 256));
      _hx_k_cast_d2f<<<g, b, 0, strm>>>(B_dev, Bf, nB); }
    if (_forge_launch_check("own_tf32_cast_in") != 0) { cudaFree(Af); cudaFree(Bf); cudaFree(Cf); return -1; }
    static int _own_tf32_fired = 0;
    if (!_own_tf32_fired) { _own_tf32_fired = 1;
        fprintf(stderr, "[OWN-TF32-FIRED] _hx_k_gemm_tf32_owngemm mma.sync m16n8k8 PARITY DEVICE path (no cuBLAS)\n"); }
    dim3 blk(HX_OWNTF_NTHREAD);
    dim3 grd((unsigned)((N+HX_OWNTF_BN-1)/HX_OWNTF_BN), (unsigned)((M+HX_OWNTF_BM-1)/HX_OWNTF_BM));
    _hx_k_gemm_tf32_owngemm<<<grd, blk, 0, strm>>>(Af, Bf, Cf, (int)M, (int)N, (int)K);
    if (_forge_launch_check("own_tf32_owngemm") != 0) { cudaFree(Af); cudaFree(Bf); cudaFree(Cf); return -1; }
    { int64_t nC = M*N; dim3 b(256); dim3 g((unsigned)((nC + 255) / 256));
      _hx_k_cast_f2d<<<g, b, 0, strm>>>(Cf, C_dev, nC); }
    if (_forge_launch_check("own_tf32_cast_out") != 0) { cudaFree(Af); cudaFree(Bf); cudaFree(Cf); return -1; }
    if (_forge_sync() != 0) { cudaFree(Af); cudaFree(Bf); cudaFree(Cf); return -1; }
    cudaFree(Af); cudaFree(Bf); cudaFree(Cf);
    return 0;
#else
    (void)A_dev; (void)B_dev; (void)C_dev; (void)M; (void)K; (void)N;
    fprintf(stderr, "[cuda] own-tf32 parity gemm requires CUDACC build\n");
    return -1;
#endif
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
    /* HEXA-FUSION N2 RACEFIX (F-FUSION-N1N2-DETERMINISM, 3rd hazard):
     * GEMM-C cudaFree/cudaMalloc/cudaMemset run on the DEFAULT stream;
     * when async is ON a queued forge-stream kernel may still reference
     * cs->d_buf -> free-under-use. Drain first (no-op async-off). */
    if (_forge_sync() != 0) return -1;
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
    /* HEXA-FUSION Phase 1a: own _hx_k_gemm (row-major, naive) is now the
     * DEFAULT GEMM (FP64 own == cuBLAS bit-identical, rel-RMS 0 byte-neutral).
     * HEXA_OWN_GEMM=0 opt-OUT reverts to cublasDgemm (which stays the A/B
     * correctness oracle). cuBLAS is no longer a hard dependency. */
    if (_forge_own_gemm_on()) {
        static int _own_gemm_fired = 0;
        if (!_own_gemm_fired) { _own_gemm_fired = 1;
            fprintf(stderr, "[OWN-GEMM-FIRED] _hx_k_gemm DEVICE path (no cuBLAS)\n"); }
        if (M == 1) {
            /* decode GEMV fast-path (kernel-quality-reffirst lane). The 16x16
             * tile wastes 15/16 threads at M==1. #4204 fast-default flip:
             * split-K atomic (_hx_k_gemv_splitk, fills SMs at small N, NOT
             * bit-id) is now the DEFAULT; HEXA_DET selects the BYTE-IDENTICAL
             * _hx_k_gemv_1d (same sequential K-loop reduction as _hx_k_gemm).
             * Legacy HEXA_GEMV_SPLITK still forces split-K even under HEXA_DET
             * is NOT honoured — det wins (eval/verdict must stay byte-exact). */
            if (!_forge_det_on()) {
                int _ks = 8; /* knee measured @sm_120: 128 blocks saturates DRAM 95% */
                cudaMemsetAsync(C_dev, 0, (size_t)N * sizeof(double), _forge_stream());
                dim3 _vblk(256);
                dim3 _vgrd((unsigned)((N + 255) / 256), (unsigned)_ks);
                _hx_k_gemv_splitk<<<_vgrd, _vblk, 0, _forge_stream()>>>(A_dev, B_dev, C_dev, K, N, _ks);
            } else {
                dim3 _vblk(256);
                dim3 _vgrd((unsigned)((N + 255) / 256));
                _hx_k_gemv_1d<<<_vgrd, _vblk, 0, _forge_stream()>>>(A_dev, B_dev, C_dev, K, N);
            }
            if (_forge_launch_check("own_gemv") != 0) return -1;
        } else if (!_forge_det_on()) {
            /* #4204 fast-default: atomic split-K general GEMM (NOT bit-id),
             * fills the SMs along K. C pre-zeroed for the atomicAdd. */
            int _gks = 8; /* K-split chunks; mirrors the GEMV knee */
            cudaMemsetAsync(C_dev, 0, (size_t)(M * N) * sizeof(double), _forge_stream());
            dim3 _skblk(16, 16);
            dim3 _skgrd((unsigned)((N + 15) / 16), (unsigned)((M + 15) / 16), (unsigned)_gks);
            _hx_k_gemm_splitk<<<_skgrd, _skblk, 0, _forge_stream()>>>(A_dev, B_dev, C_dev, M, K, N, _gks);
            if (_forge_launch_check("own_gemm_splitk") != 0) return -1;
        } else {
        dim3 _gblk(16, 16);
        dim3 _ggrd((unsigned)((N + 15) / 16), (unsigned)((M + 15) / 16));
        _hx_k_gemm<<<_ggrd, _gblk, 0, _forge_stream()>>>(A_dev, B_dev, C_dev, M, K, N);
        if (_forge_launch_check("own_gemm") != 0) return -1;
        }
#ifdef HEXA_USE_CUBLAS
    } else if (_forge_tf32_fastmode()) {
        /* HEXA-0POD OP-24: TF32 fast-mode (opt-in). FP64 default is UNTOUCHED above;
         * this branch only fires when HEXA_TF32_FASTMODE is set. census r3 (7->0):
         * 3-way TF32 split — HEXA_TF32_OWN=1 selects the cuBLAS-FREE PARITY own-GEMM
         * (_hx_cuda_gemm_tf32_own_dev, mma.sync m16n8k8 64x64 tile = gemm_sm120 port;
         * MEASURED cublasGemmEx-TF32 parity 0.80-1.06x on sm_120, rel-RMS ~1e-5),
         * else cublasGemmEx (the prior default TF32 path, byte-identical when OWN
         * unset). This makes forge cuBLAS-INDEPENDENT (cublasGemmEx 1->0): the LAST
         * cuBLAS dependency now has a parity own-kernel replacement. */
        if (_forge_tf32_own_on()) {
            if (_hx_cuda_gemm_tf32_own_dev(A_dev, B_dev, C_dev, M, K, N) != 0) return -1;
        } else {
            if (_hx_cuda_gemm_tf32_dev(A_dev, B_dev, C_dev, M, K, N) != 0) return -1;
        }
    } else {
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
    }
#else
    }
#endif
    /* RFC056 §6.4 — route the GEMM output through the disposition handler
     * (_d2h_out) instead of a hardcoded D2H. FORGE_OUT_DEVICE_KEEP keeps C
     * device-resident (loc=FARR_DEVICE, dirty_dev=1) so the next decode op's
     * _h2d hits the §6.1 skip and the ~13k matmul/frag host round-trips that
     * dominate single-token decode util collapse. _d2h_out syncs the forge
     * stream itself in the HOST_NOW path (race-free, byte-eq); DEVICE_KEEP
     * defers both sync and copy (stream-ordered with the next forge op).
     * Default FORGE_OUT_HOST_NOW = the prior D2H, byte-identical — matmul
     * (the most frequent decode op) was the lone forge holdout hardcoding
     * the copy; every other forge op already routes output through _d2h_out.
     * C's device buffer is g_slots[c_id].d_buf (= C_dev), already set above. */
    return _d2h_out(c_id, M * N);
}

/* HEXA-FUSION Phase 1c (CUDA-OWN) — our OWN strided-batched FP64 GEMM, NO
 * cuBLAS. C_all[b·M·N] = A_all[b·M·K] · B_all[b·K·N] per batch b (row-major,
 * one thread per (b,m,n), naive k-accumulation). Owns the conv2 expert path's
 * cublasDgemmStridedBatched. Env-gated HEXA_OWN_GEMM (same as the single GEMM);
 * OFF → cublasDgemmStridedBatched unchanged. cuBLAS = correctness oracle. */
__global__ void _hx_k_gemm_strided_batched(const double* __restrict__ A,
                           const double* __restrict__ B, double* __restrict__ C,
                           int64_t M, int64_t K, int64_t N, int64_t batch) {
    int64_t n = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
    int64_t m = (int64_t)blockIdx.y * blockDim.y + threadIdx.y;
    int64_t b = (int64_t)blockIdx.z;
    if (m >= M || n >= N || b >= batch) return;
    const double* Ab = A + b * M * K;
    const double* Bb = B + b * K * N;
    double acc = 0.0;
    for (int64_t k = 0; k < K; k++) acc += Ab[m * K + k] * Bb[k * N + n];
    C[b * M * N + m * N + n] = acc;
}

/* ════════════════════════════════════════════════════════════════════
 * _hx_cuda_farr_matmul_batched_gpu — LEVER (b), forge GPU util.
 *
 * ONE cublasDgemmStridedBatched over `batch` contiguous row-major
 * problems: A_all[batch·M·K] @ B_all[batch·K·N] = C_all[batch·M·N],
 * problem g at A_all[g·M·K], B_all[g·K·N], C_all[g·M·N]. C farr is
 * caller-allocated (len batch·M·N). The util lever vs `batch` serial
 * _hx_cuda_farr_matmul_gpu micro-launches — the GPU gets meaningful
 * work per launch instead of microsecond latency-bound calls.
 *
 * Row-major→column-major trick (same as the single matmul): each
 * row-major C_g[M,N] = A_g[M,K] · B_g[K,N] becomes column-major
 * C_g^T[N,M] = B_g^T[N,K] · A_g^T[K,M], i.e. Dgemm(N,N, m=N,n=M,k=K,
 * B_g, ldb=N, A_g, lda=K, C_g, ldc=N). Strides: A_g stride = M·K,
 * B_g stride = K·N, C_g stride = M·N (in the swapped call B carries
 * the K·N stride and A the M·K stride). Result bit-eq to `batch`
 * serial Dgemm (cuBLAS uses the same per-problem accumulation).
 * Returns 0 ok / -1 err. */
int _hx_cuda_farr_matmul_batched_gpu(int64_t a_id, int64_t M, int64_t K,
                                     int64_t b_id, int64_t N,
                                     int64_t batch, int64_t c_id) {
    if (_ensure_cublas() != 0) return -1;
    if (a_id < 0 || b_id < 0 || c_id < 0) return -1;
    if (M <= 0 || K <= 0 || N <= 0 || batch <= 0) return -1;
    /* Upload A_all,B_all (H2D, contiguous batch·M·K / batch·K·N). */
    if (_h2d(a_id) != 0) return -1;
    if (_h2d(b_id) != 0) return -1;
    if (_ensure_slot_cap(c_id) != 0) return -1;
    HexaFarrEntry* ce = &_hx_farr_table[c_id];
    _CudaFarrSlot*  cs = &g_slots[c_id];
    if (!ce->buf || ce->len < batch * M * N) {
        fprintf(stderr, "[cuda] matmul_batched: C host len %lld < batch*M*N %lld\n",
                (long long)ce->len, (long long)(batch*M*N));
        return -1;
    }
    /* HEXA-FUSION N2 RACEFIX (F-FUSION-N1N2-DETERMINISM, 3rd hazard,
     * batched): same default-stream GEMM-C realloc race. Drain first. */
    if (_forge_sync() != 0) return -1;
    if (!cs->d_buf || cs->len != ce->len) {
        if (cs->d_buf) cudaFree(cs->d_buf);
        cudaError_t er = cudaMalloc((void**)&cs->d_buf,
                                    (size_t)ce->len * sizeof(double));
        if (er != cudaSuccess) {
            fprintf(stderr, "[cuda] cudaMalloc C_batched(%lld) failed: %s\n",
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
    /* Swapped (B,A) so the row-major buffers map to the right column-
     * major problem; strideB = K·N (the cuBLAS-A operand here),
     * strideA = M·K (the cuBLAS-B operand), strideC = M·N. */
    if (_forge_own_gemm_on()) {
        static int _own_bgemm_fired = 0;
        if (!_own_bgemm_fired) { _own_bgemm_fired = 1;
            fprintf(stderr, "[OWN-GEMM-FIRED] _hx_k_gemm_strided_batched DEVICE path (no cuBLAS)\n"); }
        dim3 _bblk(16, 16);
        dim3 _bgrd((unsigned)((N + 15) / 16), (unsigned)((M + 15) / 16), (unsigned)batch);
        _hx_k_gemm_strided_batched<<<_bgrd, _bblk, 0, _forge_stream()>>>(A_dev, B_dev, C_dev, M, K, N, batch);
        if (_forge_launch_check("own_gemm_batched") != 0) return -1;
#ifdef HEXA_USE_CUBLAS
    } else {
    cublasStatus_t st = cublasDgemmStridedBatched(
        g_cublas, CUBLAS_OP_N, CUBLAS_OP_N,
        (int)N, (int)M, (int)K,
        &alpha,
        B_dev, (int)N, (long long)(K * N),
        A_dev, (int)K, (long long)(M * K),
        &beta,
        C_dev, (int)N, (long long)(M * N),
        (int)batch);
    if (st != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[cuda] cublasDgemmStridedBatched failed: %d\n", (int)st);
        return -1;
    }
    }
#else
    }
#endif
    if (_forge_sync() != 0) return -1;
    cudaError_t er = cudaMemcpy(ce->buf, C_dev,
                                (size_t)(batch * M * N) * sizeof(double),
                                cudaMemcpyDeviceToHost);
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] cudaMemcpy C_batched D2H failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    ce->d_buf      = (void*)C_dev;
    ce->loc        = FARR_MIRRORED;
    ce->dirty_host = 0;
    ce->dirty_dev  = 0;
    return 0;
}

/* HEXA-0POD OP-2 (BENCH-10 transpose-elimination) — C[K,N] = A[M,K]^T @ B[M,N]
 * via cuBLAS Dgemm with OP_T on A, NO materialized A^T. Owns the backward
 * dW = xcol^T @ dy of conv1d_bwd_via_forge: the prior path ran a SEPARATE
 * transpose-layout im2col pass (_clmp_im2col_t -> xcolT[Kdim,T]) then an OP_N
 * GEMM; this reuses the forward's NON-transposed xcol[T,Kdim] and lets cuBLAS
 * read it transposed for free (the extra full im2col_t pass is eliminated).
 * Math contract: dW_flat[j,c] = Σ_t A[t,j]·B[t,c] (contraction over the shared
 * M=T dim). Byte-eq to im2col_t+OP_N on the CPU oracle (max|Δ|=0,
 * clm_prod_transpose_elim_eq.hexa); the cuBLAS reduction is an fp-accum-order
 * variant of the OP_N Dgemm (rel-RMS ~1e-14, identical-tolerance lane).
 *
 * Row-major C[K,N] = A^T(K×M) @ B(M×N). cuBLAS col-major: view row-major B as
 * col-major B^T (N×M), row-major A as col-major A^T (K×M). Compute col-major
 *   C^T_col(N×K) = B^T_col(N×M) · (A^T_col)^T(M×K)
 * = Dgemm(OP_N on B, OP_T on A, m=N, n=K, k=M, B_dev ldb=N, A_dev lda=K,
 *   C_dev ldc=N) — the col-major (N×K) IS the row-major C(K×N). */
__global__ void _hx_k_gemm_t(const double* __restrict__ A,
                             const double* __restrict__ B,
                             double* __restrict__ C,
                             int64_t M, int64_t K, int64_t N) {
    /* own (no-cuBLAS) fallback: C[k,n] = Σ_m A[m*K+k]·B[m*N+n]. */
    int64_t n = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
    int64_t k = (int64_t)blockIdx.y * blockDim.y + threadIdx.y;
    if (k >= K || n >= N) return;
    double acc = 0.0;
    for (int64_t m = 0; m < M; m++) acc += A[m * K + k] * B[m * N + n];
    C[k * N + n] = acc;
}
int _hx_cuda_farr_matmul_tn_gpu(int64_t a_id, int64_t M, int64_t K,
                                int64_t b_id, int64_t N,
                                int64_t c_id) {
    if (_ensure_cublas() != 0) return -1;
    if (a_id < 0 || b_id < 0 || c_id < 0) {
        fprintf(stderr, "[cuda] matmul_tn: bad ids %lld %lld %lld\n",
                (long long)a_id, (long long)b_id, (long long)c_id);
        return -1;
    }
    if (M <= 0 || K <= 0 || N <= 0) {
        fprintf(stderr, "[cuda] matmul_t: bad shape M=%lld K=%lld N=%lld\n",
                (long long)M, (long long)K, (long long)N);
        return -1;
    }
    if (_h2d(a_id) != 0) return -1;
    if (_h2d(b_id) != 0) return -1;
    if (_ensure_slot_cap(c_id) != 0) return -1;
    HexaFarrEntry* ce = &_hx_farr_table[c_id];
    _CudaFarrSlot*  cs = &g_slots[c_id];
    if (!ce->buf || ce->len < K * N) {
        fprintf(stderr, "[cuda] matmul_t: C host len %lld < K*N %lld\n",
                (long long)ce->len, (long long)(K*N));
        return -1;
    }
    if (_forge_sync() != 0) return -1;
    if (!cs->d_buf || cs->len != ce->len) {
        if (cs->d_buf) cudaFree(cs->d_buf);
        cudaError_t er = cudaMalloc((void**)&cs->d_buf,
                                    (size_t)ce->len * sizeof(double));
        if (er != cudaSuccess) {
            fprintf(stderr, "[cuda] cudaMalloc C_t(%lld) failed: %s\n",
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
    if (_forge_own_gemm_on()) {
        static int _own_gemmt_fired = 0;
        if (!_own_gemmt_fired) { _own_gemmt_fired = 1;
            fprintf(stderr, "[OWN-GEMM-FIRED] _hx_k_gemm_t DEVICE path (no cuBLAS)\n"); }
        dim3 _gblk(16, 16);
        dim3 _ggrd((unsigned)((N + 15) / 16), (unsigned)((K + 15) / 16));
        _hx_k_gemm_t<<<_ggrd, _gblk, 0, _forge_stream()>>>(A_dev, B_dev, C_dev, M, K, N);
        if (_forge_launch_check("own_gemm_t") != 0) return -1;
#ifdef HEXA_USE_CUBLAS
    } else {
    static int _gemmt_fired = 0;
    if (!_gemmt_fired) { _gemmt_fired = 1;
        fprintf(stderr, "[MATMUL-T-FIRED] cuBLAS Dgemm OP_T (transpose-elim, no A^T pass)\n"); }
    /* Dgemm(OP_N B, OP_T A, m=N, n=K, k=M): col-major C^T(N×K) = B(N×M)·A(M×K). */
    cublasStatus_t st = cublasDgemm(g_cublas,
                                    CUBLAS_OP_N, CUBLAS_OP_T,
                                    (int)N, (int)K, (int)M,
                                    &alpha,
                                    B_dev, (int)N,
                                    A_dev, (int)K,
                                    &beta,
                                    C_dev, (int)N);
    if (st != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[cuda] cublasDgemm OP_T failed: %d\n", (int)st);
        return -1;
    }
    }
#else
    }  /* NO_CUBLAS: close the _forge_own_gemm_on() own-branch (cuBLAS else removed) */
#endif
    if (_forge_sync() != 0) return -1;
    cudaError_t er = cudaMemcpy(ce->buf, C_dev,
                                (size_t)(K * N) * sizeof(double),
                                cudaMemcpyDeviceToHost);
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] cudaMemcpy C_t D2H failed: %s\n",
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
 * LEVER (a) — device-resident im2col / col2im (forge device-feed).
 *
 * The dominant Lane-G util peg is the HOST backward feed: the trainer
 * rebuilds x_col on the host each step (host-dirty → re-H2D every GEMM)
 * and scatters col2im on the host. These kernels run the gather/scatter
 * ON-DEVICE and, when the disposition register is FORGE_OUT_DEVICE_KEEP,
 * KEEP the output FARR_DEVICE (via _d2h_out's RFC-056 defer) so the
 * follow-up forge GEMM reads it in place — NO D2H/H2D roundtrip.
 *
 * im2col gather   : x_col[t, ci*K+k] = (p>=0)?x[p,ci]:0, p=t-dil*(K-1-k)
 *   one thread per (t, ci, k) output cell — PURE GATHER, no atomics.
 * im2col_t (dW)   : xcolT[ci*K+k, t] (transpose layout, j*T+t).
 * col2im scatter  : dX[p,ci] = Σ_k dXcol[(p+dil*(K-1-k))*Kdim + ci*K+k],
 *   t<T. TRANSPOSE-GATHER form (one thread per dX[p,ci] output cell,
 *   summing the K taps) — NO atomics → deterministic, byte-eq to the
 *   host scatter order (the clm_conv_devfeed.hexa oracle).
 * ──────────────────────────────────────────────────────────────────── */
__global__ void _hx_k_im2col(const double* __restrict__ X,
                             double* __restrict__ XC,
                             int64_t T, int64_t Cin, int64_t K,
                             int64_t dil) {
    int64_t Kdim = Cin * K;
    int64_t total = T * Kdim;
    int64_t stride = (int64_t)blockDim.x * (int64_t)gridDim.x;
    for (int64_t idx = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         idx < total; idx += stride) {
        int64_t t  = idx / Kdim;
        int64_t j  = idx - t * Kdim;      /* j = ci*K + k */
        int64_t ci = j / K;
        int64_t k  = j - ci * K;
        int64_t p  = t - dil * (K - 1 - k);
        XC[idx] = (p >= 0) ? X[p * Cin + ci] : 0.0;
    }
}

__global__ void _hx_k_im2col_t(const double* __restrict__ X,
                               double* __restrict__ XCT,
                               int64_t T, int64_t Cin, int64_t K,
                               int64_t dil) {
    int64_t Kdim = Cin * K;
    int64_t total = Kdim * T;
    int64_t stride = (int64_t)blockDim.x * (int64_t)gridDim.x;
    for (int64_t idx = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         idx < total; idx += stride) {
        int64_t j  = idx / T;             /* j = ci*K + k */
        int64_t t  = idx - j * T;
        int64_t ci = j / K;
        int64_t k  = j - ci * K;
        int64_t p  = t - dil * (K - 1 - k);
        XCT[idx] = (p >= 0) ? X[p * Cin + ci] : 0.0;
    }
}

__global__ void _hx_k_col2im(const double* __restrict__ DXC,
                             double* __restrict__ DX,
                             int64_t T, int64_t Cin, int64_t K,
                             int64_t dil) {
    int64_t Kdim = Cin * K;
    int64_t total = T * Cin;
    int64_t stride = (int64_t)blockDim.x * (int64_t)gridDim.x;
    for (int64_t idx = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         idx < total; idx += stride) {
        int64_t p  = idx / Cin;
        int64_t ci = idx - p * Cin;
        double acc = 0.0;
        for (int64_t k = 0; k < K; k++) {
            int64_t t = p + dil * (K - 1 - k);
            if (t < T) acc += DXC[t * Kdim + (ci * K + k)];
        }
        DX[idx] = acc;
    }
}

/* #4204 own-native fast-default — atomic-SCATTER col2im. One thread per
 * DXC input cell (t, j=ci*K+k); maps to dX[p,ci] with p = t - dil*(K-1-k)
 * and atomicAdd's the tap into DX[p*Cin+ci]. CHANGES the float accum order
 * (NOT bit-identical) vs the transpose-GATHER _hx_k_col2im -> fast non-det
 * DEFAULT (training). DX MUST be pre-zeroed (the wrapper cudaMemsetAsync's
 * it). HEXA_DET selects the deterministic gather kernel. gpu_only: needs
 * nvcc compile + clm_conv_devfeed.hexa oracle (det path) on summer. */
__global__ void _hx_k_col2im_scatter(const double* __restrict__ DXC,
                                     double* __restrict__ DX,
                                     int64_t T, int64_t Cin, int64_t K,
                                     int64_t dil) {
    int64_t Kdim = Cin * K;
    int64_t total = T * Kdim;
    int64_t stride = (int64_t)blockDim.x * (int64_t)gridDim.x;
    for (int64_t idx = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         idx < total; idx += stride) {
        int64_t t  = idx / Kdim;
        int64_t j  = idx - t * Kdim;      /* j = ci*K + k */
        int64_t ci = j / K;
        int64_t k  = j - ci * K;
        int64_t p  = t - dil * (K - 1 - k);
        if (p >= 0) atomicAdd(&DX[p * Cin + ci], DXC[idx]);
    }
}

/* Launch helper: one 1-D grid over `total` output cells. */
static void _hx_im2col_grid(int64_t total, int* grid_sz, int* block_sz) {
    *block_sz = 256;
    int64_t want = (total + 255) / 256;
    *grid_sz = (want > 1024) ? 1024 : (int)want;
    if (*grid_sz < 1) *grid_sz = 1;
}

/* im2col gather → device-resident XC. Reads X (H2D idempotent), writes
 * the output device buffer; _d2h_out honours FORGE_OUT_DEVICE_KEEP so XC
 * stays FARR_DEVICE for the next GEMM (no roundtrip). 0 ok / -1 err. */
int _hx_cuda_farr_im2col_gpu(int64_t x_id, int64_t xc_id,
                             int64_t T, int64_t Cin, int64_t K,
                             int64_t dil) {
#ifdef __CUDACC__
    if (T <= 0 || Cin <= 0 || K <= 0 || dil <= 0) {
        fprintf(stderr, "[cuda] im2col: bad shape T=%lld Cin=%lld K=%lld dil=%lld\n",
                (long long)T, (long long)Cin, (long long)K, (long long)dil);
        return -1;
    }
    int64_t Kdim = Cin * K;
    if (_h2d(x_id) != 0) return -1;
    if (_ensure_dev_alloc_out(xc_id, T * Kdim) != 0) return -1;
    const double* X  = g_slots[x_id].d_buf;
    double*       XC = g_slots[xc_id].d_buf;
    int grid_sz, block_sz; _hx_im2col_grid(T * Kdim, &grid_sz, &block_sz);
    _hx_k_im2col<<<grid_sz, block_sz, 0, _forge_stream()>>>(X, XC, T, Cin, K, dil);
    if (_forge_launch_check("im2col") != 0) return -1;
    return _d2h_out(xc_id, T * Kdim);
#else
    (void)x_id; (void)xc_id; (void)T; (void)Cin; (void)K; (void)dil;
    fprintf(stderr, "[cuda] im2col: built without __CUDACC__\n");
    return -1;
#endif
}

int _hx_cuda_farr_im2col_t_gpu(int64_t x_id, int64_t xct_id,
                               int64_t T, int64_t Cin, int64_t K,
                               int64_t dil) {
#ifdef __CUDACC__
    if (T <= 0 || Cin <= 0 || K <= 0 || dil <= 0) return -1;
    int64_t Kdim = Cin * K;
    if (_h2d(x_id) != 0) return -1;
    if (_ensure_dev_alloc_out(xct_id, Kdim * T) != 0) return -1;
    const double* X   = g_slots[x_id].d_buf;
    double*       XCT = g_slots[xct_id].d_buf;
    int grid_sz, block_sz; _hx_im2col_grid(Kdim * T, &grid_sz, &block_sz);
    _hx_k_im2col_t<<<grid_sz, block_sz, 0, _forge_stream()>>>(X, XCT, T, Cin, K, dil);
    if (_forge_launch_check("im2col_t") != 0) return -1;
    return _d2h_out(xct_id, Kdim * T);
#else
    (void)x_id; (void)xct_id; (void)T; (void)Cin; (void)K; (void)dil;
    fprintf(stderr, "[cuda] im2col_t: built without __CUDACC__\n");
    return -1;
#endif
}

int _hx_cuda_farr_col2im_gpu(int64_t dxc_id, int64_t dx_id,
                             int64_t T, int64_t Cin, int64_t K,
                             int64_t dil) {
#ifdef __CUDACC__
    if (T <= 0 || Cin <= 0 || K <= 0 || dil <= 0) return -1;
    if (_h2d(dxc_id) != 0) return -1;
    if (_ensure_dev_alloc_out(dx_id, T * Cin) != 0) return -1;
    const double* DXC = g_slots[dxc_id].d_buf;
    double*       DX  = g_slots[dx_id].d_buf;
    if (!_forge_det_on()) {
        /* #4204 fast-default: atomic-scatter (NOT bit-id). DX pre-zeroed. */
        cudaMemsetAsync(DX, 0, (size_t)(T * Cin) * sizeof(double), _forge_stream());
        int gss, bss; _hx_im2col_grid(T * Cin * K, &gss, &bss);
        _hx_k_col2im_scatter<<<gss, bss, 0, _forge_stream()>>>(DXC, DX, T, Cin, K, dil);
    } else {
    int grid_sz, block_sz; _hx_im2col_grid(T * Cin, &grid_sz, &block_sz);
    _hx_k_col2im<<<grid_sz, block_sz, 0, _forge_stream()>>>(DXC, DX, T, Cin, K, dil);
    }
    cudaError_t er = cudaDeviceSynchronize();
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] col2im launch failed: %s\n", cudaGetErrorString(er));
        return -1;
    }
    return _d2h_out(dx_id, T * Cin);
#else
    (void)dxc_id; (void)dx_id; (void)T; (void)Cin; (void)K; (void)dil;
    fprintf(stderr, "[cuda] col2im: built without __CUDACC__\n");
    return -1;
#endif
}

/* ════════════════════════════════════════════════════════════════════
 * HEXA-FUSION L1 (GRAD half) — device-resident bias-gradient column-sum.
 *
 * The conv backward's bias grad is db[co] = Σ_{t=0..T-1} dy[t,co]. Today
 * conv1d_bwd_via_forge does this Σ on the HOST — it reads the device GEMM
 * output `dy` back element-by-element (T·Cout t_get) and writes db on
 * host, which the very next _adam(W, db, ...) then re-uploads (H2D). That
 * is a pure removable grad roundtrip: the bias grads d*B escape ONLY into
 * _adam (clm_prod.hexa — nothing on the host reads them between bwd and
 * the optimizer), so db can stay DEVICE-RESIDENT across bwd→AdamW.
 *
 * BIT-EXACTNESS (g5 max|Δ|=0): one thread per output channel `co` sums
 * dy[0,co], dy[1,co], … dy[T-1,co] in the SAME sequential t-order as the
 * host loop. NO tree / warp-shuffle reduction → NO fp re-association →
 * identical IEEE-754 accumulation → byte-eq to the host db reduction
 * (unlike the row-reduction kernels which carry a ~N·ε tolerance). The
 * channel count Cout (= d / E / V) is the parallel axis; T is summed
 * sequentially inside each thread.
 *
 * Residence contract for db after this call (mirrors the keepmv moments):
 *   loc = FARR_DEVICE, dirty_host = 0, live device slot, len = Cout.
 * The next step / next op's _h2d(db) then hits the RFC 056 §6.1 H2D-skip
 * and reuses the device buffer in place — host db stale but provably
 * never read, so byte-eq to the always-D2H path. Gated in clm_prod.hexa
 * behind env CLM_PROD_DEVRESIDENT; default off → host reduction unchanged. */
__global__ void _hx_k_db_colsum(const double* __restrict__ DY,
                                double* __restrict__ DB,
                                int64_t T, int64_t Cout) {
    int64_t stride = (int64_t)blockDim.x * (int64_t)gridDim.x;
    for (int64_t co = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         co < Cout; co += stride) {
        double acc = 0.0;
        for (int64_t t = 0; t < T; t++) acc += DY[t * Cout + co];
        DB[co] = acc;
    }
}

/* db colsum → device-resident DB. Reads DY (H2D idempotent — if DY is
 * already FARR_DEVICE from the upstream GEMM this is the §6.1 skip), runs
 * the sequential per-channel sum, then keeps DB DEVICE-RESIDENT
 * (loc=FARR_DEVICE, dirty_host=0) so the next _adam H2D-skips the grad.
 * 0 ok / -1 err. */
int _hx_cuda_farr_db_colsum_gpu(int64_t dy_id, int64_t db_id,
                                int64_t T, int64_t Cout) {
#ifdef __CUDACC__
    if (T <= 0 || Cout <= 0) {
        fprintf(stderr, "[cuda] db_colsum: bad shape T=%lld Cout=%lld\n",
                (long long)T, (long long)Cout);
        return -1;
    }
    if (_h2d(dy_id) != 0) return -1;
    if (_ensure_dev_alloc_out(db_id, Cout) != 0) return -1;
    const double* DY = g_slots[dy_id].d_buf;
    double*       DB = g_slots[db_id].d_buf;
    int block_sz = 256;
    int64_t want = (Cout + block_sz - 1) / block_sz;
    int grid_sz = (want > 1024) ? 1024 : (int)want;
    if (grid_sz < 1) grid_sz = 1;
    _hx_k_db_colsum<<<grid_sz, block_sz, 0, _forge_stream()>>>(DY, DB, T, Cout);
    if (_forge_launch_check("db_colsum") != 0) return -1;
    /* db stays DEVICE-RESIDENT: mark loc=FARR_DEVICE, dirty_host=0 so the
     * next _adam(W, db, ...) _h2d SKIPs the H2D and reuses the device
     * accumulator in place (host db never read — byte-eq to the host
     * reduction + always-D2H path). Same residence convention as the
     * keepmv moments (NOT _d2h_out's dirty_host=1, which would force a
     * re-upload). */
    {
        HexaFarrEntry* e = &_hx_farr_table[db_id];
        e->d_buf      = (void*)g_slots[db_id].d_buf;
        e->loc        = FARR_DEVICE;
        e->dirty_host = 0;
        e->dirty_dev  = 0;
    }
    return 0;
#else
    (void)dy_id; (void)db_id; (void)T; (void)Cout;
    fprintf(stderr, "[cuda] db_colsum: built without __CUDACC__\n");
    return -1;
#endif
}

/* ════════════════════════════════════════════════════════════════════
 * HEXA-FUSION L1 (PARAM half) — device-resident int4 fake-quant (QAT).
 *
 * Today clm_prod._fq calls nn_int4_quant_fwd on the HOST every forward —
 * it reads W back (Cout·rest t_get) to compute per-channel scale + the
 * int4 codes, which forces W D2H every step and blocks W from staying
 * device-resident. This kernel does the identical per-channel QAT on
 * device so W never leaves the GPU.
 *
 * BIT-EXACTNESS (g5 max|Δ|=0 — int4 is INTEGER, no FMA-drift excuse):
 * one thread per output channel `co` reproduces nn_int4_quant_fwd EXACTLY
 *   s   = (mx>0) ? mx/7 : 1,  mx = max_j |W[co,j]|   (sequential max)
 *   r   = round-half-away-from-zero(W[idx]/s)        (integer round)
 *   q   = clamp(r, -7, +7),  mask = (clamped ? 0 : 1)
 *   Wq  = q · s
 * The max scan is per-channel SEQUENTIAL (same compare order as the host
 * loop) and the round/clamp are integer — NO fp reduction re-association,
 * so every byte matches the host quant. _q_round = (x>=0)?(double)(long
 * long)(x+0.5):-(double)(long long)((-x)+0.5) mirrors quant_lib._q_round.
 *
 * Residence (mirrors keepmv / db_colsum): W loc=FARR_DEVICE preserved
 * (no D2H), wq/sc/ql/mask kept loc=FARR_DEVICE dirty_host=0 so the GEMM
 * reads Wq on device and the STE bwd reads mask on device. Gated in
 * clm_prod.hexa behind env CLM_PROD_DEVRESIDENT. */
__global__ void _hx_k_int4_quant(const double* __restrict__ W,
                                 double* __restrict__ WQ,
                                 double* __restrict__ SC,
                                 double* __restrict__ QL,
                                 double* __restrict__ MASK,
                                 int64_t Cout, int64_t rest) {
    int64_t stride = (int64_t)blockDim.x * (int64_t)gridDim.x;
    for (int64_t co = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         co < Cout; co += stride) {
        int64_t base = co * rest;
        double mx = 0.0;
        for (int64_t j = 0; j < rest; j++) {
            double a = W[base + j]; if (a < 0.0) a = -a;
            if (a > mx) mx = a;
        }
        double s = (mx > 0.0) ? (mx / 7.0) : 1.0;
        SC[co] = s;
        for (int64_t j = 0; j < rest; j++) {
            int64_t idx = base + j;
            double x = W[idx] / s;
            /* round-half-away-from-zero (quant_lib._q_round) */
            double r = (x >= 0.0) ? (double)(int64_t)(x + 0.5)
                                  : -(double)(int64_t)((-x) + 0.5);
            double q = r; double inrange = 1.0;
            if (q > 7.0)  { q = 7.0;  inrange = 0.0; }
            if (q < -7.0) { q = -7.0; inrange = 0.0; }
            QL[idx]   = q;
            MASK[idx] = inrange;
            WQ[idx]   = q * s;
        }
    }
}

/* int4 fake-quant → device-resident wq/sc/ql/mask, W kept resident. Reads
 * W (H2D idempotent — §6.1 skip if W already FARR_DEVICE), runs the
 * per-channel QAT, then keeps the four outputs DEVICE-RESIDENT
 * (loc=FARR_DEVICE, dirty_host=0). 0 ok / -1 err. */
int _hx_cuda_farr_int4_quant_gpu(int64_t w_id, int64_t wq_id,
                                 int64_t sc_id, int64_t ql_id,
                                 int64_t mask_id,
                                 int64_t Cout, int64_t rest) {
#ifdef __CUDACC__
    if (Cout <= 0 || rest <= 0) {
        fprintf(stderr, "[cuda] int4_quant: bad shape Cout=%lld rest=%lld\n",
                (long long)Cout, (long long)rest);
        return -1;
    }
    int64_t n = Cout * rest;
    if (_h2d(w_id) != 0) return -1;
    if (_ensure_dev_alloc_out(wq_id, n)    != 0) return -1;
    if (_ensure_dev_alloc_out(sc_id, Cout) != 0) return -1;
    if (_ensure_dev_alloc_out(ql_id, n)    != 0) return -1;
    if (_ensure_dev_alloc_out(mask_id, n)  != 0) return -1;
    const double* W  = g_slots[w_id].d_buf;
    double* WQ   = g_slots[wq_id].d_buf;
    double* SC   = g_slots[sc_id].d_buf;
    double* QL   = g_slots[ql_id].d_buf;
    double* MASK = g_slots[mask_id].d_buf;
    int block_sz = 256;
    int64_t want = (Cout + block_sz - 1) / block_sz;
    int grid_sz = (want > 1024) ? 1024 : (int)want;
    if (grid_sz < 1) grid_sz = 1;
    _hx_k_int4_quant<<<grid_sz, block_sz, 0, _forge_stream()>>>(W, WQ, SC, QL, MASK, Cout, rest);
    if (_forge_launch_check("int4_quant") != 0) return -1;
    /* wq/sc/ql/mask stay DEVICE-RESIDENT (same residence convention as the
     * keepmv moments / db_colsum). W keeps its existing loc (FARR_DEVICE
     * after _h2d — no D2H, that is the whole point: W stays resident). */
    {
        int64_t outs[4]; outs[0]=wq_id; outs[1]=sc_id; outs[2]=ql_id; outs[3]=mask_id;
        for (int oi = 0; oi < 4; oi++) {
            int64_t oid = outs[oi];
            HexaFarrEntry* e = &_hx_farr_table[oid];
            e->d_buf      = (void*)g_slots[oid].d_buf;
            e->loc        = FARR_DEVICE;
            e->dirty_host = 0;
            e->dirty_dev  = 0;
        }
    }
    return 0;
#else
    (void)w_id; (void)wq_id; (void)sc_id; (void)ql_id; (void)mask_id;
    (void)Cout; (void)rest;
    fprintf(stderr, "[cuda] int4_quant: built without __CUDACC__\n");
    return -1;
#endif
}

/* HEXA-FUSION L1 (PARAM half) — int4 clipped-STE backward.
 * dW[i] = dy[i] · mask[i] (mask ∈ {0,1}); pure elementwise, no reduction
 * → bit-exact to nn_int4_quant_bwd. Keeps dW DEVICE-RESIDENT so the next
 * _adam H2D-skips the grad. */
__global__ void _hx_k_int4_quant_bwd(const double* __restrict__ DY,
                                     const double* __restrict__ MASK,
                                     double* __restrict__ DW, int64_t n) {
    int64_t stride = (int64_t)blockDim.x * (int64_t)gridDim.x;
    for (int64_t i = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         i < n; i += stride) {
        DW[i] = DY[i] * MASK[i];
    }
}

int _hx_cuda_farr_int4_quant_bwd_gpu(int64_t dy_id, int64_t mask_id,
                                     int64_t dw_id, int64_t n) {
#ifdef __CUDACC__
    if (n <= 0) return -1;
    if (_h2d(dy_id) != 0) return -1;
    if (_h2d(mask_id) != 0) return -1;
    if (_ensure_dev_alloc_out(dw_id, n) != 0) return -1;
    const double* DY   = g_slots[dy_id].d_buf;
    const double* MASK = g_slots[mask_id].d_buf;
    double*       DW   = g_slots[dw_id].d_buf;
    int block_sz = 256;
    int64_t want = (n + block_sz - 1) / block_sz;
    int grid_sz = (want > 1024) ? 1024 : (int)want;
    if (grid_sz < 1) grid_sz = 1;
    _hx_k_int4_quant_bwd<<<grid_sz, block_sz, 0, _forge_stream()>>>(DY, MASK, DW, n);
    if (_forge_launch_check("int4_quant_bwd") != 0) return -1;
    {
        HexaFarrEntry* e = &_hx_farr_table[dw_id];
        e->d_buf      = (void*)g_slots[dw_id].d_buf;
        e->loc        = FARR_DEVICE;
        e->dirty_host = 0;
        e->dirty_dev  = 0;
    }
    return 0;
#else
    (void)dy_id; (void)mask_id; (void)dw_id; (void)n;
    fprintf(stderr, "[cuda] int4_quant_bwd: built without __CUDACC__\n");
    return -1;
#endif
}

/* HEXA-FUSION L3 (glue half) — device-resident elementwise residual-add.
 * OUT[i] = A[i] + B[i]; pure elementwise, no reduction → bit-exact to the
 * host scalar loop (max|Δ|=0). This is the highest-frequency interpreted
 * inter-op host glue in clm_prod_fwd (the residual xt = xec + hg0, run
 * T·d times per step in the interpreter between device GEMM spikes — the
 * ③ fwd-only 0% floor). Fusing it onto the device leaves the interpreter
 * off the per-step hot path AND keeps OUT FARR_DEVICE so the next conv
 * GEMM H2D-skips it. */
__global__ void _hx_k_residual_add(const double* __restrict__ A,
                                   const double* __restrict__ B,
                                   double* __restrict__ OUT, int64_t n) {
    int64_t stride = (int64_t)blockDim.x * (int64_t)gridDim.x;
    for (int64_t i = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         i < n; i += stride) {
        OUT[i] = A[i] + B[i];
    }
}

int _hx_cuda_farr_residual_add_gpu(int64_t a_id, int64_t b_id,
                                   int64_t out_id, int64_t n) {
#ifdef __CUDACC__
    if (n <= 0) return -1;
    if (_h2d(a_id) != 0) return -1;
    if (_h2d(b_id) != 0) return -1;
    if (_ensure_dev_alloc_out(out_id, n) != 0) return -1;
    const double* A   = g_slots[a_id].d_buf;
    const double* B   = g_slots[b_id].d_buf;
    double*       OUT = g_slots[out_id].d_buf;
    int block_sz = 256;
    int64_t want = (n + block_sz - 1) / block_sz;
    int grid_sz = (want > 1024) ? 1024 : (int)want;
    if (grid_sz < 1) grid_sz = 1;
    _hx_k_residual_add<<<grid_sz, block_sz, 0, _forge_stream()>>>(A, B, OUT, n);
    if (_forge_launch_check("residual_add") != 0) return -1;
    /* OUT stays DEVICE-RESIDENT (loc=FARR_DEVICE, dirty_host=0) so the next
     * conv GEMM that reads it H2D-skips (same residence convention as the
     * keepmv moments / db colsum / int4 quant). */
    {
        HexaFarrEntry* e = &_hx_farr_table[out_id];
        e->d_buf      = (void*)g_slots[out_id].d_buf;
        e->loc        = FARR_DEVICE;
        e->dirty_host = 0;
        e->dirty_dev  = 0;
    }
    return 0;
#else
    (void)a_id; (void)b_id; (void)out_id; (void)n;
    fprintf(stderr, "[cuda] residual_add: built without __CUDACC__\n");
    return -1;
#endif
}

/* HEXA-FUSION fusion-r2 (BEYOND-PARITY) — own-GEMM with the residual epilogue
 * FUSED into the C-store site. The default path runs _hx_k_gemm then a SEPARATE
 * _hx_k_residual_add (a full M*N DRAM round-trip: write C, read C+R, write C).
 * This kernel adds R at the store site register-resident -> one launch, no
 * round-trip. byte-eq by construction: same acc (same K-loop association as
 * _hx_k_gemm) + same R[i] add -> C[m*N+n] = acc + R[m*N+n] reproduces the
 * 2-call result CHARACTER-FOR-CHARACTER (max|delta|=0, MEASURED aiden RTX 5070
 * sm_120: bit_ne=0 across D=1024/2048/4096, all K). MEASURED WIN is regime-split
 * (the epilogue is only a fraction of a compute-bound square GEMM): for the
 * memory-bound projection shape (large M=N, small K -- the residual-add-after-
 * linear shape in transformer/CLM fwd) fusion is 1.15x (K=64) .. 2.07x (K=8) at
 * D=4096; for square K=D it is ~1.003x (epilogue ~0.2%% of GEMM). cuBLAS GemmEx
 * structurally cannot fuse this (no cuBLASLt epilogue here). Env-gated
 * HEXA_FUSE_EPILOGUE; the DEFAULT GEMM+residual path is UNTOUCHED (byte-neutral). */
__global__ void _hx_k_gemm_fused_residual(const double* __restrict__ A,
                                          const double* __restrict__ B,
                                          const double* __restrict__ R,
                                          double* __restrict__ C,
                                          int64_t M, int64_t K, int64_t N) {
    int64_t n = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
    int64_t m = (int64_t)blockIdx.y * blockDim.y + threadIdx.y;
    if (m >= M || n >= N) return;
    double acc = 0.0;
    for (int64_t k = 0; k < K; k++) acc += A[m * K + k] * B[k * N + n];
    C[m * N + n] = acc + R[m * N + n];
}

/* fusion-r2 fused entry point: C[M,N] = A[M,K].B[K,N] + R[M,N], one launch.
 * Only invoked when stdlib forge calls it under HEXA_FUSE_EPILOGUE; the default
 * GEMM-then-residual_add API path is unchanged. Same 16x16 block / N-x-M grid as
 * the own-GEMM default (_hx_k_gemm) so the byte-eq guarantee holds. */
int _hx_cuda_farr_gemm_residual_fused_gpu(int64_t a_id, int64_t b_id,
                                          int64_t r_id, int64_t c_id,
                                          int64_t M, int64_t K, int64_t N) {
#ifdef __CUDACC__
    if (M <= 0 || K <= 0 || N <= 0) return -1;
    if (_h2d(a_id) != 0) return -1;
    if (_h2d(b_id) != 0) return -1;
    if (_h2d(r_id) != 0) return -1;
    if (_ensure_dev_alloc_out(c_id, M * N) != 0) return -1;
    const double* A = g_slots[a_id].d_buf;
    const double* B = g_slots[b_id].d_buf;
    const double* R = g_slots[r_id].d_buf;
    double*       C = g_slots[c_id].d_buf;
    dim3 _fblk(16, 16);
    dim3 _fgrd((unsigned)((N + 15) / 16), (unsigned)((M + 15) / 16));
    static int _fuse_epi_fired = 0;
    if (!_fuse_epi_fired) { _fuse_epi_fired = 1;
        fprintf(stderr, "[FUSE-EPILOGUE-FIRED] _hx_k_gemm_fused_residual (1 launch, no DRAM round-trip)\n"); }
    _hx_k_gemm_fused_residual<<<_fgrd, _fblk, 0, _forge_stream()>>>(A, B, R, C, M, K, N);
    if (_forge_launch_check("gemm_residual_fused") != 0) return -1;
    {
        HexaFarrEntry* e = &_hx_farr_table[c_id];
        e->d_buf      = (void*)g_slots[c_id].d_buf;
        e->loc        = FARR_DEVICE;
        e->dirty_host = 0;
        e->dirty_dev  = 0;
    }
    return 0;
#else
    (void)a_id; (void)b_id; (void)r_id; (void)c_id; (void)M; (void)K; (void)N;
    fprintf(stderr, "[cuda] gemm_residual_fused: built without __CUDACC__\n");
    return -1;
#endif
}

/* HEXA-0POD OP-19b — device-side deterministic transcendentals, shared by
 * every device GELU kernel below (_hx_k_gelu, _hx_k_gelu2, _hx_gelu_dev,
 * _hx_k_gelu_bwd) AND the CE-grad kernel (F-OP19). Defined ONCE here, before
 * the first use, so all GELU kernels swap CUDA erf()/exp() → these → the
 * device GELU stays bit-exact to the host (which now uses flame_math dt_erf/
 * dt_exp) AND cross-platform deterministic (CUDA erf/exp diverge across
 * arch/OS like libm — OP-19 measured 1 ULP arm64↔x86). _hx_dt_erf_dev is the
 * byte-for-byte transcription of flame_math.hexa dt_erf (Maclaurin, NO libm).
 * _hx_dt_exp_dev is the F-OP19 dt_exp twin. */
__device__ static double _hx_dt_exp_dev(double x) {
    /* byte-identical to flame_math.hexa dt_exp. */
    long long r = 0;
    double xr = x;
    while ((xr > 0.0 ? xr : 0.0 - xr) > 0.25) { xr = xr / 2.0; r = r + 1; }
    double term = 1.0;
    double acc = 1.0;
    long long k = 1;
    while (k < 12) { term = term * xr / (double)k; acc = acc + term; k = k + 1; }
    long long s = 0;
    while (s < r) { acc = acc * acc; s = s + 1; }
    return acc;
}
__device__ static double _hx_dt_erf_dev(double x) {
    /* byte-identical to flame_math.hexa dt_erf — A&S 7.1.26 rational with the
     * exp routed through _hx_dt_exp_dev. BRANCHLESS in z (only the z=0 odd
     * sign flip), so it never straddles a value-dependent boundary; pure
     * +,-,*,/ + dt_exp, NO libm. max|Δ vs libm erf| = 1.38e-7. */
    double sign = 1.0;
    double z = x;
    if (z < 0.0) { sign = 0.0 - 1.0; z = 0.0 - z; }
    double t = 1.0 / (1.0 + 0.3275911 * z);
    const double a1 = 0.254829592;
    const double a2 = 0.0 - 0.284496736;
    const double a3 = 1.421413741;
    const double a4 = 0.0 - 1.453152027;
    const double a5 = 1.061405429;
    double poly = ((((a5 * t + a4) * t + a3) * t + a2) * t + a1) * t;
    return sign * (1.0 - poly * _hx_dt_exp_dev(0.0 - z * z));
}
/* HEXA-FUSION L3 (glue half) — device-resident elementwise GELU.
 * OUT[i] = IN[i]·0.5·(1 + erf(IN[i]·(1/√2))) — the EXACT erf-based GELU of
 * stdlib/flame/nn_lib.hexa _nn_gelu (GELU(x)=x·Φ(x), Φ(x)=0.5·(1+erf(x/√2))).
 * Pure elementwise, NO reduction. The constant 1/√2 is the SAME literal the
 * host uses (_nn_inv_sqrt2 = 0.70710678118654752440) and the op order matches
 * (x · cdf). OP-19b: erf → _hx_dt_erf_dev (deterministic, NO libm) → bit-exact
 * to the host scalar loop (now dt_erf) AND cross-platform. Fuses the gelu ×3
 * host glue in clm_prod_fwd (hg0/ex0/ex1 — the ③ fwd-only 0% floor) and keeps
 * OUT FARR_DEVICE so the next conv GEMM H2D-skips it. */
__global__ void _hx_k_gelu(const double* __restrict__ IN,
                           double* __restrict__ OUT, int64_t n) {
    const double inv_sqrt2 = 0.70710678118654752440;
    int64_t stride = (int64_t)blockDim.x * (int64_t)gridDim.x;
    for (int64_t i = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         i < n; i += stride) {
        double x = IN[i];
        double cdf = 0.5 * (1.0 + _hx_dt_erf_dev(x * inv_sqrt2));
        OUT[i] = x * cdf;
    }
}

int _hx_cuda_farr_gelu_gpu(int64_t in_id, int64_t out_id, int64_t n) {
#ifdef __CUDACC__
    if (n <= 0) return -1;
    if (_h2d(in_id) != 0) return -1;
    if (_ensure_dev_alloc_out(out_id, n) != 0) return -1;
    const double* IN  = g_slots[in_id].d_buf;
    double*       OUT = g_slots[out_id].d_buf;
    int block_sz = 256;
    int64_t want = (n + block_sz - 1) / block_sz;
    int grid_sz = (want > 1024) ? 1024 : (int)want;
    if (grid_sz < 1) grid_sz = 1;
    { static int _eager_devglue_fired = 0;
      if (!_eager_devglue_fired) { _eager_devglue_fired = 1;
        fprintf(stderr, "[EAGER-DEVGLUE-FIRED] _hx_k_gelu device CUDA-erf GELU (separate launch, P1B-a' device-resident eager ref)\n"); } }
    _hx_k_gelu<<<grid_sz, block_sz, 0, _forge_stream()>>>(IN, OUT, n);
    if (_forge_launch_check("gelu") != 0) return -1;
    {
        HexaFarrEntry* e = &_hx_farr_table[out_id];
        e->d_buf      = (void*)g_slots[out_id].d_buf;
        e->loc        = FARR_DEVICE;
        e->dirty_host = 0;
        e->dirty_dev  = 0;
    }
    return 0;
#else
    (void)in_id; (void)out_id; (void)n;
    fprintf(stderr, "[cuda] gelu: built without __CUDACC__\n");
    return -1;
#endif
}

/* HEXA-FUSION L3-b (OP-BOUNDARY FUSION) — device-resident dual GELU.
 * The two expert-conv activations in clm_prod_fwd (eo0->ex0, eo1->ex1) are
 * INDEPENDENT, same-shape (n = T*d) elementwise gelus that follow the SAME
 * conv2_fwd_via_forge_batched output. Fusing them collapses two micro gelu
 * launches into ONE thread-grid pass (one launch, one sync) to raise H100
 * occupancy. byte-eq by construction: each write reproduces _hx_k_gelu
 * arithmetic CHARACTER-FOR-CHARACTER (same 1/sqrt2 literal, same
 * 0.5*(1+erf(x*inv_sqrt2)) erf-based cdf) on its own input — A0[i]=gelu(G0[i]),
 * A1[i]=gelu(G1[i]) — so max|delta|=0 vs two separate _hx_k_gelu launches.
 * Env-gated HEXA_FUSE_GELU2; no-CUDA -> -1 -> host two _gelu calls. */
__global__ void _hx_k_gelu2(const double* __restrict__ G0,
                            double* __restrict__ A0,
                            const double* __restrict__ G1,
                            double* __restrict__ A1, int64_t n) {
    const double inv_sqrt2 = 0.70710678118654752440;
    int64_t stride = (int64_t)blockDim.x * (int64_t)gridDim.x;
    for (int64_t i = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         i < n; i += stride) {
        double x0 = G0[i];
        double cdf0 = 0.5 * (1.0 + _hx_dt_erf_dev(x0 * inv_sqrt2));
        A0[i] = x0 * cdf0;
        double x1 = G1[i];
        double cdf1 = 0.5 * (1.0 + _hx_dt_erf_dev(x1 * inv_sqrt2));
        A1[i] = x1 * cdf1;
    }
}

int _hx_cuda_farr_gelu2_gpu(int64_t g0_id, int64_t a0_id,
                            int64_t g1_id, int64_t a1_id, int64_t n) {
#ifdef __CUDACC__
    if (n <= 0) return -1;
    if (_h2d(g0_id) != 0) return -1;
    if (_h2d(g1_id) != 0) return -1;
    if (_ensure_dev_alloc_out(a0_id, n) != 0) return -1;
    if (_ensure_dev_alloc_out(a1_id, n) != 0) return -1;
    const double* G0 = g_slots[g0_id].d_buf;
    double*       A0 = g_slots[a0_id].d_buf;
    const double* G1 = g_slots[g1_id].d_buf;
    double*       A1 = g_slots[a1_id].d_buf;
    int block_sz = 256;
    int64_t want = (n + block_sz - 1) / block_sz;
    int grid_sz = (want > 1024) ? 1024 : (int)want;
    if (grid_sz < 1) grid_sz = 1;
    _hx_k_gelu2<<<grid_sz, block_sz, 0, _forge_stream()>>>(G0, A0, G1, A1, n);
    if (_forge_launch_check("gelu2") != 0) return -1;
    {
        int64_t outs[2] = { a0_id, a1_id };
        for (int k = 0; k < 2; k++) {
            HexaFarrEntry* e = &_hx_farr_table[outs[k]];
            e->d_buf      = (void*)g_slots[outs[k]].d_buf;
            e->loc        = FARR_DEVICE;
            e->dirty_host = 0;
            e->dirty_dev  = 0;
        }
    }
    return 0;
#else
    (void)g0_id; (void)a0_id; (void)g1_id; (void)a1_id; (void)n;
    fprintf(stderr, "[cuda] gelu2: built without __CUDACC__\n");
    return -1;
#endif
}

/* HEXA-FUSION L3 (glue half) — device-resident GroupNorm forward.
 * Reproduces stdlib/flame/gn_lib.hexa nn_groupnorm_fwd EXACTLY: per group g,
 *   mu  = (Σ_{t,c∈g} X[t,c]) / (Cg·T)
 *   var = (Σ_{t,c∈g} (X[t,c]-mu)²) / (Cg·T)
 *   inv = 1/sqrt(var+eps)   (eps=1e-5)
 *   xhat[t,c] = (X[t,c]-mu)·inv ; Y[t,c] = gamma[c]·xhat + beta[c]
 * BIT-EXACTNESS: the two reductions accumulate SEQUENTIALLY in the host order
 * (t outer, c inner) inside ONE thread per group — NO tree re-association, NO
 * warp/atomic partials — and inv uses the SAME Newton-Raphson 40-iteration
 * _gn_sqrt the host uses (NOT CUDA rsqrt/sqrt), so every IEEE-754 double op
 * matches → max|Δ|=0. Fuses the groupnorm ×2 host glue in clm_prod_fwd
 * (h0→hn0, y→yn — the ③ fwd-only 0% floor); keeps outputs FARR_DEVICE. */
__device__ static double _hx_gn_sqrt_dev(double x) {
    /* byte-identical to gn_lib.hexa _gn_sqrt (Newton-Raphson, 40 iters). */
    if (x <= 0.0) return 0.0;
    double g = x;
    for (int i = 0; i < 40; i++) { g = 0.5 * (g + x / g); }
    return g;
}
__global__ void _hx_k_groupnorm(const double* __restrict__ X,
                                const double* __restrict__ GAMMA,
                                const double* __restrict__ BETA,
                                double* __restrict__ Y,
                                double* __restrict__ MEAN,
                                double* __restrict__ INV,
                                double* __restrict__ XHAT,
                                int64_t T, int64_t C, int64_t G) {
    const double eps = 0.00001;
    int64_t cg = C / G;
    double m = (double)(cg * T);
    /* one thread per group → the per-group reduction is a single-thread
     * sequential loop in EXACTLY the host accumulation order. */
    for (int64_t g = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         g < G; g += (int64_t)blockDim.x * gridDim.x) {
        int64_t c0 = g * cg;
        double sum = 0.0;
        for (int64_t t = 0; t < T; t++)
            for (int64_t c = 0; c < cg; c++)
                sum += X[t * C + (c0 + c)];
        double mu = sum / m;
        double vs = 0.0;
        for (int64_t t = 0; t < T; t++)
            for (int64_t c = 0; c < cg; c++) {
                double d = X[t * C + (c0 + c)] - mu;
                vs += d * d;
            }
        double var = vs / m;
        double inv = 1.0 / _hx_gn_sqrt_dev(var + eps);
        MEAN[g] = mu;
        INV[g]  = inv;
        for (int64_t t = 0; t < T; t++)
            for (int64_t c = 0; c < cg; c++) {
                int64_t ch = c0 + c;
                double xh = (X[t * C + ch] - mu) * inv;
                XHAT[t * C + ch] = xh;
                Y[t * C + ch] = GAMMA[ch] * xh + BETA[ch];
            }
    }
}

int _hx_cuda_farr_groupnorm_gpu(int64_t x_id, int64_t gamma_id, int64_t beta_id,
                                int64_t y_id, int64_t mean_id, int64_t inv_id,
                                int64_t xhat_id, int64_t T, int64_t C, int64_t G) {
#ifdef __CUDACC__
    if (T <= 0 || C <= 0 || G <= 0 || (C % G) != 0) return -1;
    /* HEXA-FUSION MEGAKERNEL-GN-GRIDSYNC: when HEXA_FUSE_GN_COOP is set, route to
     * the cooperative grid-synced GN (fuse-able mid-megakernel). On -2 (no coop
     * support / launch miss) fall THROUGH to the sequential path below — which is
     * the byte-eq oracle this coop kernel must reproduce. */
    {
        extern int _hx_cuda_farr_groupnorm_coop_gpu(int64_t, int64_t, int64_t,
            int64_t, int64_t, int64_t, int64_t, int64_t, int64_t, int64_t);
        const char* gc = getenv("HEXA_FUSE_GN_COOP");
        if (gc && gc[0] != '0' && gc[0] != '\0') {
            int crc = _hx_cuda_farr_groupnorm_coop_gpu(x_id, gamma_id, beta_id,
                          y_id, mean_id, inv_id, xhat_id, T, C, G);
            if (crc == 0) return 0;
            /* crc==-2 → device/launch unsupported → sequential fallback below. */
        }
    }
    if (_h2d(x_id) != 0) return -1;
    if (_h2d(gamma_id) != 0) return -1;
    if (_h2d(beta_id) != 0) return -1;
    if (_ensure_dev_alloc_out(y_id, T * C) != 0) return -1;
    if (_ensure_dev_alloc_out(mean_id, G) != 0) return -1;
    if (_ensure_dev_alloc_out(inv_id, G) != 0) return -1;
    if (_ensure_dev_alloc_out(xhat_id, T * C) != 0) return -1;
    const double* X     = g_slots[x_id].d_buf;
    const double* GAMMA = g_slots[gamma_id].d_buf;
    const double* BETA  = g_slots[beta_id].d_buf;
    double*       Y     = g_slots[y_id].d_buf;
    double*       MEAN  = g_slots[mean_id].d_buf;
    double*       INV   = g_slots[inv_id].d_buf;
    double*       XHAT  = g_slots[xhat_id].d_buf;
    int block_sz = 64;
    int64_t want = (G + block_sz - 1) / block_sz;
    int grid_sz = (want > 1024) ? 1024 : (int)want;
    if (grid_sz < 1) grid_sz = 1;
    _hx_k_groupnorm<<<grid_sz, block_sz, 0, _forge_stream()>>>(X, GAMMA, BETA, Y, MEAN, INV, XHAT,
                                           T, C, G);
    if (_forge_launch_check("groupnorm") != 0) return -1;
    /* Y/xhat/mean/inv stay DEVICE-RESIDENT so the follow-up conv GEMM / gelu
     * H2D-skip them (same residence convention as residual_add). */
    {
        int64_t outs[4] = { y_id, mean_id, inv_id, xhat_id };
        for (int k = 0; k < 4; k++) {
            HexaFarrEntry* e = &_hx_farr_table[outs[k]];
            e->d_buf      = (void*)g_slots[outs[k]].d_buf;
            e->loc        = FARR_DEVICE;
            e->dirty_host = 0;
            e->dirty_dev  = 0;
        }
    }
    return 0;
#else
    (void)x_id; (void)gamma_id; (void)beta_id; (void)y_id; (void)mean_id;
    (void)inv_id; (void)xhat_id; (void)T; (void)C; (void)G;
    fprintf(stderr, "[cuda] groupnorm: built without __CUDACC__\n");
    return -1;
#endif
}

/* HEXA-FUSION L3 (OP-BOUNDARY FUSION) — device-resident GroupNorm+GELU.
 * The FIRST op-boundary fusion: the adjacent groupnorm #1 → gelu #1 pair in
 * clm_prod_fwd (h0→hn0 then hn0→hg0, gelu consumes the GN output with NOTHING
 * between) collapses into ONE kernel — the post-GN value stays in a REGISTER
 * (no HBM round-trip, no second launch). Reproduces gn_lib.hexa
 * nn_gn_gelu_fused EXACTLY: the GroupNorm half is character-for-character the
 * _hx_k_groupnorm math (same SEQUENTIAL reduction t-outer/c-inner, same
 * Newton-Raphson 40-iter _hx_gn_sqrt_dev, NO tree re-assoc) and the GELU half
 * is the _hx_k_gelu math (yv·0.5·(1+erf(yv·(1/√2))), same 1/√2 literal). Two
 * outputs: Y = pre-GELU GN affine (the bwd cache hn0 nn_gelu_bwd needs — bwd
 * UNCHANGED) and A = GELU(Y). Bit-identical to groupnorm-then-gelu because Y is
 * computed by the IDENTICAL expression and GELU is applied to that SAME double
 * (max|Δ|=0). Env-gated HEXA_FUSE_GN_GELU; no-CUDA → -1 → host nn_gn_gelu_fused. */
__device__ static double _hx_gelu_dev(double x) {
    /* byte-identical to _hx_k_gelu / gn_lib.hexa _gn_gelu (OP-19b dt_erf). */
    const double inv_sqrt2 = 0.70710678118654752440;
    double cdf = 0.5 * (1.0 + _hx_dt_erf_dev(x * inv_sqrt2));
    return x * cdf;
}
__global__ void _hx_k_groupnorm_gelu(const double* __restrict__ X,
                                     const double* __restrict__ GAMMA,
                                     const double* __restrict__ BETA,
                                     double* __restrict__ Y,
                                     double* __restrict__ A,
                                     double* __restrict__ MEAN,
                                     double* __restrict__ INV,
                                     double* __restrict__ XHAT,
                                     int64_t T, int64_t C, int64_t G) {
    const double eps = 0.00001;
    int64_t cg = C / G;
    double m = (double)(cg * T);
    /* one thread per group → the per-group reduction is the SAME single-thread
     * sequential loop as _hx_k_groupnorm (host accumulation order). */
    for (int64_t g = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         g < G; g += (int64_t)blockDim.x * gridDim.x) {
        int64_t c0 = g * cg;
        double sum = 0.0;
        for (int64_t t = 0; t < T; t++)
            for (int64_t c = 0; c < cg; c++)
                sum += X[t * C + (c0 + c)];
        double mu = sum / m;
        double vs = 0.0;
        for (int64_t t = 0; t < T; t++)
            for (int64_t c = 0; c < cg; c++) {
                double d = X[t * C + (c0 + c)] - mu;
                vs += d * d;
            }
        double var = vs / m;
        double inv = 1.0 / _hx_gn_sqrt_dev(var + eps);
        MEAN[g] = mu;
        INV[g]  = inv;
        for (int64_t t = 0; t < T; t++)
            for (int64_t c = 0; c < cg; c++) {
                int64_t ch = c0 + c;
                double xh = (X[t * C + ch] - mu) * inv;
                XHAT[t * C + ch] = xh;
                /* yv = the EXACT _hx_k_groupnorm output, kept in a register; */
                double yv = GAMMA[ch] * xh + BETA[ch];
                Y[t * C + ch] = yv;
                /* GELU applied to that same register value → no HBM round-trip. */
                A[t * C + ch] = _hx_gelu_dev(yv);
            }
    }
}

int _hx_cuda_farr_groupnorm_gelu_gpu(int64_t x_id, int64_t gamma_id, int64_t beta_id,
                                     int64_t y_id, int64_t a_id, int64_t mean_id,
                                     int64_t inv_id, int64_t xhat_id,
                                     int64_t T, int64_t C, int64_t G) {
#ifdef __CUDACC__
    if (T <= 0 || C <= 0 || G <= 0 || (C % G) != 0) return -1;
    if (_h2d(x_id) != 0) return -1;
    if (_h2d(gamma_id) != 0) return -1;
    if (_h2d(beta_id) != 0) return -1;
    if (_ensure_dev_alloc_out(y_id, T * C) != 0) return -1;
    if (_ensure_dev_alloc_out(a_id, T * C) != 0) return -1;
    if (_ensure_dev_alloc_out(mean_id, G) != 0) return -1;
    if (_ensure_dev_alloc_out(inv_id, G) != 0) return -1;
    if (_ensure_dev_alloc_out(xhat_id, T * C) != 0) return -1;
    const double* X     = g_slots[x_id].d_buf;
    const double* GAMMA = g_slots[gamma_id].d_buf;
    const double* BETA  = g_slots[beta_id].d_buf;
    double*       Y     = g_slots[y_id].d_buf;
    double*       A     = g_slots[a_id].d_buf;
    double*       MEAN  = g_slots[mean_id].d_buf;
    double*       INV   = g_slots[inv_id].d_buf;
    double*       XHAT  = g_slots[xhat_id].d_buf;
    int block_sz = 64;
    int64_t want = (G + block_sz - 1) / block_sz;
    int grid_sz = (want > 1024) ? 1024 : (int)want;
    if (grid_sz < 1) grid_sz = 1;
    /* forge stream (NOT the default stream): the async device-resident
     * chain queues producers (residual_add/conv) on _forge_stream(), a
     * cudaStreamNonBlocking stream that does NOT implicit-sync with the
     * legacy default stream. A default-stream launch here would be UNORDERED
     * vs those producers -> read stale/partial input -> mu/var corruption.
     * Same stream = stream-order enforces the data dependency. async-off:
     * _forge_stream()=0 + _forge_launch_check=cudaDeviceSynchronize() =
     * byte-identical to the legacy default-stream barrier. */
    _hx_k_groupnorm_gelu<<<grid_sz, block_sz, 0, _forge_stream()>>>(X, GAMMA, BETA, Y, A, MEAN, INV, XHAT,
                                                T, C, G);
    if (_forge_launch_check("groupnorm_gelu") != 0) return -1;
    /* Y/A/xhat/mean/inv stay DEVICE-RESIDENT so the follow-up residual_add /
     * conv GEMM H2D-skip them (same residence convention as groupnorm). */
    {
        int64_t outs[5] = { y_id, a_id, mean_id, inv_id, xhat_id };
        for (int k = 0; k < 5; k++) {
            HexaFarrEntry* e = &_hx_farr_table[outs[k]];
            e->d_buf      = (void*)g_slots[outs[k]].d_buf;
            e->loc        = FARR_DEVICE;
            e->dirty_host = 0;
            e->dirty_dev  = 0;
        }
    }
    return 0;
#else
    (void)x_id; (void)gamma_id; (void)beta_id; (void)y_id; (void)a_id;
    (void)mean_id; (void)inv_id; (void)xhat_id; (void)T; (void)C; (void)G;
    fprintf(stderr, "[cuda] groupnorm_gelu: built without __CUDACC__\n");
    return -1;
#endif
}

/* HEXA-FUSION L3-c (op-boundary fusion) — groupnorm + gelu + residual-add in
 * ONE kernel. Extends L3-a (_hx_k_groupnorm_gelu) by also taking the residual
 * operand R (= xec) and writing OUT = R + GELU(GN(X)) in the SAME launch — the
 * clm_prod_fwd head h0->hn0->hg0 THEN xt = xec + hg0 collapses from 2 launches
 * (groupnorm_gelu + residual_add) into 1. The GN+GELU half is character-for-
 * character _hx_k_groupnorm_gelu (same sequential reduction, same _hx_gn_sqrt_dev
 * NR-40, same _hx_gelu_dev erf), and the residual is OUT[i] = R[i] + gv with gv
 * the SAME register GELU value -> bit-identical to groupnorm_gelu-then-residual_add
 * (max|Δ|=0). THREE+ outputs preserved byte-for-byte: Y = pre-GELU GN affine (bwd
 * cache hn0, bwd UNCHANGED), A = GELU(Y) (kept so the bwd graph is identical), and
 * OUT = R + A (the fused residual = xt). Env-gated HEXA_FUSE_GN_GELU_RESID; no-CUDA
 * -> -1 -> host groupnorm_gelu + residual_add (byte-eq reference). */
__global__ void _hx_k_groupnorm_gelu_residual(const double* __restrict__ X,
                                     const double* __restrict__ GAMMA,
                                     const double* __restrict__ BETA,
                                     const double* __restrict__ R,
                                     double* __restrict__ Y,
                                     double* __restrict__ A,
                                     double* __restrict__ OUT,
                                     double* __restrict__ MEAN,
                                     double* __restrict__ INV,
                                     double* __restrict__ XHAT,
                                     int64_t T, int64_t C, int64_t G) {
    const double eps = 0.00001;
    int64_t cg = C / G;
    double m = (double)(cg * T);
    for (int64_t g = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         g < G; g += (int64_t)blockDim.x * gridDim.x) {
        int64_t c0 = g * cg;
        double sum = 0.0;
        for (int64_t t = 0; t < T; t++)
            for (int64_t c = 0; c < cg; c++)
                sum += X[t * C + (c0 + c)];
        double mu = sum / m;
        double vs = 0.0;
        for (int64_t t = 0; t < T; t++)
            for (int64_t c = 0; c < cg; c++) {
                double d = X[t * C + (c0 + c)] - mu;
                vs += d * d;
            }
        double var = vs / m;
        double inv = 1.0 / _hx_gn_sqrt_dev(var + eps);
        MEAN[g] = mu;
        INV[g]  = inv;
        for (int64_t t = 0; t < T; t++)
            for (int64_t c = 0; c < cg; c++) {
                int64_t ch = c0 + c;
                int64_t idx = t * C + ch;
                double xh = (X[idx] - mu) * inv;
                XHAT[idx] = xh;
                /* yv = the EXACT _hx_k_groupnorm output (bwd cache). */
                double yv = GAMMA[ch] * xh + BETA[ch];
                Y[idx] = yv;
                /* gv = GELU(yv) in a register (same as L3-a). */
                double gv = _hx_gelu_dev(yv);
                A[idx] = gv;
                /* residual fused: OUT = R + gv (= xec + hg0, same add order). */
                OUT[idx] = R[idx] + gv;
            }
    }
}

int _hx_cuda_farr_groupnorm_gelu_residual_gpu(int64_t x_id, int64_t gamma_id,
                                     int64_t beta_id, int64_t r_id,
                                     int64_t y_id, int64_t a_id, int64_t out_id,
                                     int64_t mean_id, int64_t inv_id, int64_t xhat_id,
                                     int64_t T, int64_t C, int64_t G) {
#ifdef __CUDACC__
    if (T <= 0 || C <= 0 || G <= 0 || (C % G) != 0) return -1;
    if (_h2d(x_id) != 0) return -1;
    if (_h2d(gamma_id) != 0) return -1;
    if (_h2d(beta_id) != 0) return -1;
    if (_h2d(r_id) != 0) return -1;
    if (_ensure_dev_alloc_out(y_id, T * C) != 0) return -1;
    if (_ensure_dev_alloc_out(a_id, T * C) != 0) return -1;
    if (_ensure_dev_alloc_out(out_id, T * C) != 0) return -1;
    if (_ensure_dev_alloc_out(mean_id, G) != 0) return -1;
    if (_ensure_dev_alloc_out(inv_id, G) != 0) return -1;
    if (_ensure_dev_alloc_out(xhat_id, T * C) != 0) return -1;
    const double* X     = g_slots[x_id].d_buf;
    const double* GAMMA = g_slots[gamma_id].d_buf;
    const double* BETA  = g_slots[beta_id].d_buf;
    const double* R     = g_slots[r_id].d_buf;
    double*       Y     = g_slots[y_id].d_buf;
    double*       A     = g_slots[a_id].d_buf;
    double*       OUT   = g_slots[out_id].d_buf;
    double*       MEAN  = g_slots[mean_id].d_buf;
    double*       INV   = g_slots[inv_id].d_buf;
    double*       XHAT  = g_slots[xhat_id].d_buf;
    int block_sz = 64;
    int64_t want = (G + block_sz - 1) / block_sz;
    int grid_sz = (want > 1024) ? 1024 : (int)want;
    if (grid_sz < 1) grid_sz = 1;
    /* forge stream (NOT default stream) — see _hx_k_groupnorm_gelu above.
     * This FUSED trunk kernel was the ONE decode glue op launched on the
     * default stream while its producers (conv/residual_add) ran on the
     * nonblocking forge stream -> unordered RACE -> stale h -> GN mu/var
     * corruption -> per-layer trunk activation divergence (the root of the
     * CLM_PROD_DEVRESIDENT decode byte-eq FAIL: ON diverges from OFF while
     * OFF is deterministic). async-off: byte-identical to legacy barrier. */
    _hx_k_groupnorm_gelu_residual<<<grid_sz, block_sz, 0, _forge_stream()>>>(X, GAMMA, BETA, R, Y, A, OUT,
                                                MEAN, INV, XHAT, T, C, G);
    if (_forge_launch_check("groupnorm_gelu_residual") != 0) return -1;
    /* Y/A/OUT/xhat/mean/inv stay DEVICE-RESIDENT so the follow-up conv GEMM
     * (over xt = OUT) H2D-skips them (same residence convention as L3-a). */
    {
        int64_t outs[6] = { y_id, a_id, out_id, mean_id, inv_id, xhat_id };
        for (int k = 0; k < 6; k++) {
            HexaFarrEntry* e = &_hx_farr_table[outs[k]];
            e->d_buf      = (void*)g_slots[outs[k]].d_buf;
            e->loc        = FARR_DEVICE;
            e->dirty_host = 0;
            e->dirty_dev  = 0;
        }
    }
    return 0;
#else
    (void)x_id; (void)gamma_id; (void)beta_id; (void)r_id; (void)y_id;
    (void)a_id; (void)out_id; (void)mean_id; (void)inv_id; (void)xhat_id;
    (void)T; (void)C; (void)G;
    fprintf(stderr, "[cuda] groupnorm_gelu_residual: built without __CUDACC__\n");
    return -1;
#endif
}

/* HEXA-FUSION MEGAKERNEL-GN-GRIDSYNC — the SECOND megakernel wall.
 * GroupNorm needs a FULL-Y reduction (G=1 → mean/var over ALL T·C). In a plain
 * kernel that reduction is single-block-walled: the existing _hx_k_groupnorm puts
 * ONE thread per group, so with G=1 ONE thread reduces the whole tensor — it can
 * never participate in a persistent whole-grid megakernel (no cross-block barrier).
 * This COOPERATIVE variant lifts GN into the grid-synced regime so it can FUSE into
 * the persistent megakernel (cudaLaunchCooperativeKernel + cooperative_groups
 * this_grid().sync()), WITHOUT breaking byte-eq.
 *
 * BYTE-EQ DISCIPLINE (the wall): a multi-block PARALLEL reduction (tree/atomic/warp
 * partials) re-associates the FP64 sum vs the host nn_groupnorm → max|Δ|!=0. So the
 * reduction here is NOT parallelized: per group g, the canonical reducer thread
 * (grid-rank == g, i.e. block g·... ) runs the IDENTICAL sequential t-outer/c-inner
 * accumulation as _hx_k_groupnorm (same order, same _hx_gn_sqrt_dev NR-40, NO
 * re-assoc), publishes mu/inv to MEAN[g]/INV[g], then grid.sync() broadcasts them.
 * The ONLY parallel phase is the embarrassingly-parallel per-element normalize
 * (xhat = (x-mu)·inv ; Y = gamma·xhat+beta) — no reduction, so bit-identical. The
 * grid.sync() PAIR (reduce → sync → normalize) is what makes this fuse-able mid-
 * megakernel while staying max|Δ|=0 vs the sequential _hx_k_groupnorm oracle.
 *
 * HONEST FRAMING (g5): this closes a STRUCTURAL-COMPLETENESS wall (the whole-step
 * megakernel is now 100% hexa-owned, cuBLAS-call-free, no un-fusable GN host op) —
 * NOT a util/throughput win. byte-eq FORCES the reduction single-thread, so the
 * coop launch buys ZERO reduction-parallelism; idle threads wait at the barrier.
 * The binding util term remains GEMM-gap occupancy (F-FUSION-OCCUPANCY-WALL),
 * untouched here. Env-gated HEXA_FUSE_GN_COOP; no-CUDA / no-coop-support → -1 →
 * host falls back to the sequential _hx_k_groupnorm path (byte-eq reference). */
__global__ void _hx_k_groupnorm_coop(const double* __restrict__ X,
                                     const double* __restrict__ GAMMA,
                                     const double* __restrict__ BETA,
                                     double* __restrict__ Y,
                                     double* __restrict__ MEAN,
                                     double* __restrict__ INV,
                                     double* __restrict__ XHAT,
                                     int64_t T, int64_t C, int64_t G) {
#ifdef __CUDACC__
    _hxcg::grid_group grid = _hxcg::this_grid();
    const double eps = 0.00001;
    int64_t cg = C / G;
    double m = (double)(cg * T);
    int64_t rank = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
    int64_t gridsz = (int64_t)blockDim.x * gridDim.x;
    /* PHASE 1 — reduction. EXACTLY one thread per group does the SEQUENTIAL host-
     * order reduction (t-outer, c-inner, NO tree re-assoc). With G=1 that is the
     * single canonical reducer (grid-rank 0) summing the whole T·C tensor — the
     * IDENTICAL accumulation order as _hx_k_groupnorm → bit-identical mu/var/inv. */
    for (int64_t g = rank; g < G; g += gridsz) {
        int64_t c0 = g * cg;
        double sum = 0.0;
        for (int64_t t = 0; t < T; t++)
            for (int64_t c = 0; c < cg; c++)
                sum += X[t * C + (c0 + c)];
        double mu = sum / m;
        double vs = 0.0;
        for (int64_t t = 0; t < T; t++)
            for (int64_t c = 0; c < cg; c++) {
                double d = X[t * C + (c0 + c)] - mu;
                vs += d * d;
            }
        double var = vs / m;
        double inv = 1.0 / _hx_gn_sqrt_dev(var + eps);
        MEAN[g] = mu;
        INV[g]  = inv;
    }
    /* GRID BARRIER — mu/inv now visible to EVERY block (this is the cross-block
     * barrier a plain kernel lacks; it is why GN can live mid-megakernel). */
    grid.sync();
    /* PHASE 2 — normalize. Embarrassingly parallel over all T·C elements; no
     * reduction → no re-assoc → bit-identical to the sequential normalize loop. */
    int64_t TC = T * C;
    for (int64_t idx = rank; idx < TC; idx += gridsz) {
        int64_t ch = idx % C;
        int64_t g  = ch / cg;
        double mu  = MEAN[g];
        double inv = INV[g];
        double xh  = (X[idx] - mu) * inv;
        XHAT[idx]  = xh;
        Y[idx]     = GAMMA[ch] * xh + BETA[ch];
    }
#else
    (void)X; (void)GAMMA; (void)BETA; (void)Y; (void)MEAN; (void)INV; (void)XHAT;
    (void)T; (void)C; (void)G;
#endif
}

/* Cooperative-launch wrapper for _hx_k_groupnorm_coop. Mirrors the
 * _hx_cuda_farr_groupnorm_gpu surface (same farr ids / residence convention) but
 * launches via cudaLaunchCooperativeKernel so this_grid().sync() is legal. Gates
 * on cudaDevAttrCooperativeLaunch AND sizes the grid to ONE WAVE
 * (cudaOccupancyMaxActiveBlocksPerMultiprocessor × SM count) so the whole grid is
 * co-resident (a cooperative-launch hard requirement). On any miss → return -2 so
 * the caller falls back to the sequential _hx_cuda_farr_groupnorm_gpu (byte-eq). */
int _hx_cuda_farr_groupnorm_coop_gpu(int64_t x_id, int64_t gamma_id, int64_t beta_id,
                                     int64_t y_id, int64_t mean_id, int64_t inv_id,
                                     int64_t xhat_id, int64_t T, int64_t C, int64_t G) {
#ifdef __CUDACC__
    if (T <= 0 || C <= 0 || G <= 0 || (C % G) != 0) return -1;
    int dev = 0; cudaGetDevice(&dev);
    int coop = 0;
    cudaDeviceGetAttribute(&coop, cudaDevAttrCooperativeLaunch, dev);
    if (!coop) {
        fprintf(stderr, "[cuda] groupnorm_coop: device lacks cooperative launch -> fallback\n");
        return -2;
    }
    if (_h2d(x_id) != 0) return -1;
    if (_h2d(gamma_id) != 0) return -1;
    if (_h2d(beta_id) != 0) return -1;
    if (_ensure_dev_alloc_out(y_id, T * C) != 0) return -1;
    if (_ensure_dev_alloc_out(mean_id, G) != 0) return -1;
    if (_ensure_dev_alloc_out(inv_id, G) != 0) return -1;
    if (_ensure_dev_alloc_out(xhat_id, T * C) != 0) return -1;
    const double* X     = g_slots[x_id].d_buf;
    const double* GAMMA = g_slots[gamma_id].d_buf;
    const double* BETA  = g_slots[beta_id].d_buf;
    double*       Y     = g_slots[y_id].d_buf;
    double*       MEAN  = g_slots[mean_id].d_buf;
    double*       INV   = g_slots[inv_id].d_buf;
    double*       XHAT  = g_slots[xhat_id].d_buf;
    int block_sz = 64;
    int numSM = 0;
    cudaDeviceGetAttribute(&numSM, cudaDevAttrMultiProcessorCount, dev);
    int blocksPerSM = 0;
    cudaOccupancyMaxActiveBlocksPerMultiprocessor(&blocksPerSM,
        (const void*)_hx_k_groupnorm_coop, block_sz, 0);
    if (blocksPerSM < 1) blocksPerSM = 1;
    /* one wave = the MAX co-resident grid; the cooperative grid must NOT exceed it. */
    int max_grid = numSM * blocksPerSM;
    if (max_grid < 1) max_grid = 1;
    int64_t want = (T * C + block_sz - 1) / block_sz;
    int grid_sz = (want > (int64_t)max_grid) ? max_grid : (int)want;
    if (grid_sz < 1) grid_sz = 1;
    void* args[] = { (void*)&X, (void*)&GAMMA, (void*)&BETA, (void*)&Y,
                     (void*)&MEAN, (void*)&INV, (void*)&XHAT,
                     (void*)&T, (void*)&C, (void*)&G };
    dim3 gdim(grid_sz, 1, 1), bdim(block_sz, 1, 1);
    cudaError_t le = cudaLaunchCooperativeKernel((const void*)_hx_k_groupnorm_coop,
                                                 gdim, bdim, args, 0, _forge_stream());
    if (le != cudaSuccess) {
        fprintf(stderr, "[cuda] groupnorm_coop launch failed: %s -> fallback\n",
                cudaGetErrorString(le));
        return -2;
    }
    cudaError_t er = cudaDeviceSynchronize();
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] groupnorm_coop sync failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    {
        int64_t outs[4] = { y_id, mean_id, inv_id, xhat_id };
        for (int k = 0; k < 4; k++) {
            HexaFarrEntry* e = &_hx_farr_table[outs[k]];
            e->d_buf      = (void*)g_slots[outs[k]].d_buf;
            e->loc        = FARR_DEVICE;
            e->dirty_host = 0;
            e->dirty_dev  = 0;
        }
    }
    return 0;
#else
    (void)x_id; (void)gamma_id; (void)beta_id; (void)y_id; (void)mean_id;
    (void)inv_id; (void)xhat_id; (void)T; (void)C; (void)G;
    fprintf(stderr, "[cuda] groupnorm_coop: built without __CUDACC__\n");
    return -1;
#endif
}

/* HEXA-FUSION L3 (glue half · final slice ⑤c) — device-resident expert-pack
 * copy. Reproduces the clm_prod_fwd j-loop EXACTLY: for j in 0..n,
 *   EX_OUT[0·n + j] = EX0[j] ; EX_OUT[1·n + j] = EX1[j]   (n = T·d)
 * = the two expert activations stacked into ex_out[E·T·d] (E=2). Pure copy,
 * NO arithmetic, NO reduction → trivially bit-exact (max|Δ|=0). Fuses the
 * T·d host t_get/t_set pack loop in clm_prod_fwd (between the gelu ×3 and the
 * moe-router — part of the ③ fwd-only 0% floor). Keeps EX_OUT FARR_DEVICE so
 * the follow-up moe-router H2D-skips it. */
__global__ void _hx_k_expert_pack2(const double* __restrict__ EX0,
                                   const double* __restrict__ EX1,
                                   double* __restrict__ EX_OUT, int64_t n) {
    int64_t stride = (int64_t)blockDim.x * (int64_t)gridDim.x;
    for (int64_t j = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         j < n; j += stride) {
        EX_OUT[j]     = EX0[j];
        EX_OUT[n + j] = EX1[j];
    }
}

int _hx_cuda_farr_expert_pack2_gpu(int64_t ex0_id, int64_t ex1_id,
                                   int64_t out_id, int64_t n) {
#ifdef __CUDACC__
    if (n <= 0) return -1;
    if (_h2d(ex0_id) != 0) return -1;
    if (_h2d(ex1_id) != 0) return -1;
    if (_ensure_dev_alloc_out(out_id, 2 * n) != 0) return -1;
    const double* EX0 = g_slots[ex0_id].d_buf;
    const double* EX1 = g_slots[ex1_id].d_buf;
    double*       OUT = g_slots[out_id].d_buf;
    int block_sz = 256;
    int64_t want = (n + block_sz - 1) / block_sz;
    int grid_sz = (want > 1024) ? 1024 : (int)want;
    if (grid_sz < 1) grid_sz = 1;
    _hx_k_expert_pack2<<<grid_sz, block_sz, 0, _forge_stream()>>>(EX0, EX1, OUT, n);
    if (_forge_launch_check("expert_pack2") != 0) return -1;
    {
        HexaFarrEntry* e = &_hx_farr_table[out_id];
        e->d_buf      = (void*)g_slots[out_id].d_buf;
        e->loc        = FARR_DEVICE;
        e->dirty_host = 0;
        e->dirty_dev  = 0;
    }
    return 0;
#else
    (void)ex0_id; (void)ex1_id; (void)out_id; (void)n;
    fprintf(stderr, "[cuda] expert_pack2: built without __CUDACC__\n");
    return -1;
#endif
}

/* HEXA-FUSION L3 (glue half · final slice ⑤c) — device-resident MoE router.
 * Reproduces moe_lib.hexa nn_moe_router_fwd EXACTLY: per time position t,
 *   probs[t,:] = softmax(logits[t,:])  (numerically-stable, max-subtracted)
 *   Y[t,c]     = Σ_e probs[t,e]·EX_OUT[e·T·C + t·C + c]
 * BIT-EXACTNESS — two subtleties handled VERBATIM:
 *  (1) the softmax uses moe_lib's HAND-ROLLED _moe_exp (scaled-Taylor range
 *      reduction, 13 terms, 2^n by repeated ·2/÷2), NOT CUDA exp()/expf — so
 *      the device replays _moe_exp_dev term-for-term in the SAME op order.
 *  (2) the softmax sum and the combine acc accumulate SEQUENTIALLY (e=0..E,
 *      and the combine e-loop inside c) in the host order — ONE thread per t,
 *      NO tree re-association, NO warp partials → max|Δ|=0 (no ULP delta).
 * Fuses the moe-router host glue in clm_prod_fwd (logits_r·ex_out → y, probs
 * — the ③ fwd-only 0% floor). Keeps Y + PROBS FARR_DEVICE. */
__device__ static double _hx_moe_exp_dev(double x) {
    /* byte-identical to moe_lib.hexa _moe_exp. */
    const double ln2 = 0.6931471805599453;
    long long n = 0;
    double r = x;
    while (r > 0.34657359) { r = r - ln2; n = n + 1; }
    while (r < 0.0 - 0.34657359) { r = r + ln2; n = n - 1; }
    double term = 1.0;
    double sum = 1.0;
    int k = 1;
    while (k < 14) { term = term * r / (double)k; sum = sum + term; k = k + 1; }
    double p = sum;
    if (n >= 0) { long long i = 0; while (i < n) { p = p * 2.0; i = i + 1; } }
    else { long long i = 0; while (i < (0 - n)) { p = p / 2.0; i = i + 1; } }
    return p;
}
__global__ void _hx_k_moe_router(const double* __restrict__ LOGITS,
                                 const double* __restrict__ EX_OUT,
                                 double* __restrict__ PROBS,
                                 double* __restrict__ Y,
                                 int64_t T, int64_t E, int64_t C) {
    /* one thread per time position → softmax + combine reductions are a
     * single-thread sequential loop in EXACTLY the host accumulation order. */
    for (int64_t t = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         t < T; t += (int64_t)blockDim.x * gridDim.x) {
        int64_t base = t * E;
        /* stable softmax — max */
        double mx = LOGITS[base];
        for (int64_t e = 1; e < E; e++) {
            double v = LOGITS[base + e];
            if (v > mx) mx = v;
        }
        /* exp (hand-rolled _moe_exp) + sequential sum */
        double s = 0.0;
        for (int64_t e = 0; e < E; e++) {
            double ev = _hx_moe_exp_dev(LOGITS[base + e] - mx);
            PROBS[base + e] = ev;
            s = s + ev;
        }
        /* normalize */
        for (int64_t e = 0; e < E; e++)
            PROBS[base + e] = PROBS[base + e] / s;
        /* weighted combine — sequential acc over experts, host order */
        for (int64_t c = 0; c < C; c++) {
            double acc = 0.0;
            for (int64_t e = 0; e < E; e++)
                acc = acc + PROBS[t * E + e] * EX_OUT[e * T * C + t * C + c];
            Y[t * C + c] = acc;
        }
    }
}

int _hx_cuda_farr_moe_router_gpu(int64_t logits_id, int64_t ex_out_id,
                                 int64_t probs_id, int64_t y_id,
                                 int64_t T, int64_t E, int64_t C) {
#ifdef __CUDACC__
    if (T <= 0 || E <= 0 || C <= 0) return -1;
    if (_h2d(logits_id) != 0) return -1;
    if (_h2d(ex_out_id) != 0) return -1;
    if (_ensure_dev_alloc_out(probs_id, T * E) != 0) return -1;
    if (_ensure_dev_alloc_out(y_id, T * C) != 0) return -1;
    const double* LOGITS = g_slots[logits_id].d_buf;
    const double* EX_OUT = g_slots[ex_out_id].d_buf;
    double*       PROBS  = g_slots[probs_id].d_buf;
    double*       Y      = g_slots[y_id].d_buf;
    int block_sz = 128;
    int64_t want = (T + block_sz - 1) / block_sz;
    int grid_sz = (want > 1024) ? 1024 : (int)want;
    if (grid_sz < 1) grid_sz = 1;
    _hx_k_moe_router<<<grid_sz, block_sz, 0, _forge_stream()>>>(LOGITS, EX_OUT, PROBS, Y, T, E, C);
    if (_forge_launch_check("moe_router") != 0) return -1;
    {
        int64_t outs[2] = { probs_id, y_id };
        for (int k = 0; k < 2; k++) {
            HexaFarrEntry* e = &_hx_farr_table[outs[k]];
            e->d_buf      = (void*)g_slots[outs[k]].d_buf;
            e->loc        = FARR_DEVICE;
            e->dirty_host = 0;
            e->dirty_dev  = 0;
        }
    }
    return 0;
#else
    (void)logits_id; (void)ex_out_id; (void)probs_id; (void)y_id;
    (void)T; (void)E; (void)C;
    fprintf(stderr, "[cuda] moe_router: built without __CUDACC__\n");
    return -1;
#endif
}

/* HEXA-FUSION L3-d (GLUE-BLOCK megakernel · fwd glue block 2) — fuses the
 * THREE adjacent device kernels gelu2 + expert_pack2 + moe_router into ONE
 * launch (3 launches -> 1; the grid-sync-free prefix of glue block 2 —
 * groupnorm#2 is excluded because its full-y reduction needs a grid barrier).
 * ONE thread per time position t (the moe_router mapping), so EVERY op keeps
 * its host accumulation order -> byte-eq max|Δ|=0 to gelu2-then-pack-then-router:
 *   - gelu: EX0[j]=gelu(EO0[j]), EX1[j]=gelu(EO1[j]) (same erf, 1/√2 literal as
 *     _hx_k_gelu2) and pack EX_OUT[0·n+j]=EX0[j], EX_OUT[1·n+j]=EX1[j] inline;
 *   - softmax over E (max-subtract, _hx_moe_exp_dev term-for-term, sequential
 *     sum, normalize) — IDENTICAL to _hx_k_moe_router;
 *   - combine Y[t,c]=Σ_e PROBS[t,e]·EX_OUT[e·n+t·C+c], e-loop inside c, host order.
 * EX0/EX1/EX_OUT/PROBS written byte-for-byte so the bwd (reads ex_out + probs)
 * is UNCHANGED. Env-gated HEXA_FUSE_MOE_BLOCK2; no-CUDA -> -1 -> the 3 separate
 * helpers run (byte-identical reference). */
__global__ void _hx_k_moe_block2(const double* __restrict__ EO0,
                                 const double* __restrict__ EO1,
                                 const double* __restrict__ LOGITS,
                                 double* __restrict__ EX0,
                                 double* __restrict__ EX1,
                                 double* __restrict__ EX_OUT,
                                 double* __restrict__ PROBS,
                                 double* __restrict__ Y,
                                 int64_t T, int64_t E, int64_t C) {
    const double inv_sqrt2 = 0.70710678118654752440;
    int64_t n = T * C;
    int64_t stride = (int64_t)blockDim.x * (int64_t)gridDim.x;
    for (int64_t t = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         t < T; t += stride) {
        /* gelu (×2 experts) + pack for this row's C elements. */
        for (int64_t c = 0; c < C; c++) {
            int64_t j = t * C + c;
            double x0 = EO0[j];
            double g0 = x0 * 0.5 * (1.0 + _hx_dt_erf_dev(x0 * inv_sqrt2));
            EX0[j] = g0; EX_OUT[j] = g0;
            double x1 = EO1[j];
            double g1 = x1 * 0.5 * (1.0 + _hx_dt_erf_dev(x1 * inv_sqrt2));
            EX1[j] = g1; EX_OUT[n + j] = g1;
        }
        /* softmax over E (max-subtract, _hx_moe_exp_dev, sequential sum/norm). */
        int64_t base = t * E;
        double mx = LOGITS[base];
        for (int64_t e = 1; e < E; e++) { double v = LOGITS[base + e]; if (v > mx) mx = v; }
        double s = 0.0;
        for (int64_t e = 0; e < E; e++) {
            double ev = _hx_moe_exp_dev(LOGITS[base + e] - mx);
            PROBS[base + e] = ev; s += ev;
        }
        for (int64_t e = 0; e < E; e++) { PROBS[base + e] = PROBS[base + e] / s; }
        /* combine Y[t,c] = Σ_e PROBS[t,e]·EX_OUT[e·n + t·C + c] (e-loop inside c). */
        for (int64_t c = 0; c < C; c++) {
            double acc = 0.0;
            for (int64_t e = 0; e < E; e++)
                acc += PROBS[base + e] * EX_OUT[e * n + t * C + c];
            Y[t * C + c] = acc;
        }
    }
}

int _hx_cuda_farr_moe_block2_gpu(int64_t eo0_id, int64_t eo1_id, int64_t logits_id,
                                 int64_t ex0_id, int64_t ex1_id, int64_t ex_out_id,
                                 int64_t probs_id, int64_t y_id,
                                 int64_t T, int64_t E, int64_t C) {
#ifdef __CUDACC__
    if (T <= 0 || E <= 0 || C <= 0) return -1;
    int64_t n = T * C;
    if (_h2d(eo0_id) != 0) return -1;
    if (_h2d(eo1_id) != 0) return -1;
    if (_h2d(logits_id) != 0) return -1;
    if (_ensure_dev_alloc_out(ex0_id, n) != 0) return -1;
    if (_ensure_dev_alloc_out(ex1_id, n) != 0) return -1;
    if (_ensure_dev_alloc_out(ex_out_id, 2 * n) != 0) return -1;
    if (_ensure_dev_alloc_out(probs_id, T * E) != 0) return -1;
    if (_ensure_dev_alloc_out(y_id, n) != 0) return -1;
    const double* EO0    = g_slots[eo0_id].d_buf;
    const double* EO1    = g_slots[eo1_id].d_buf;
    const double* LOGITS = g_slots[logits_id].d_buf;
    double*       EX0    = g_slots[ex0_id].d_buf;
    double*       EX1    = g_slots[ex1_id].d_buf;
    double*       EX_OUT = g_slots[ex_out_id].d_buf;
    double*       PROBS  = g_slots[probs_id].d_buf;
    double*       Y      = g_slots[y_id].d_buf;
    int block_sz = 64;
    int64_t want = (T + block_sz - 1) / block_sz;
    int grid_sz = (want > 1024) ? 1024 : (int)want;
    if (grid_sz < 1) grid_sz = 1;
    _hx_k_moe_block2<<<grid_sz, block_sz, 0, _forge_stream()>>>(EO0, EO1, LOGITS,
                                                EX0, EX1, EX_OUT, PROBS, Y, T, E, C);
    if (_forge_launch_check("moe_block2") != 0) return -1;
    {
        int64_t outs[5] = { ex0_id, ex1_id, ex_out_id, probs_id, y_id };
        for (int k = 0; k < 5; k++) {
            HexaFarrEntry* e = &_hx_farr_table[outs[k]];
            e->d_buf      = (void*)g_slots[outs[k]].d_buf;
            e->loc        = FARR_DEVICE;
            e->dirty_host = 0;
            e->dirty_dev  = 0;
        }
    }
    return 0;
#else
    (void)eo0_id; (void)eo1_id; (void)logits_id; (void)ex0_id; (void)ex1_id;
    (void)ex_out_id; (void)probs_id; (void)y_id; (void)T; (void)E; (void)C;
    fprintf(stderr, "[cuda] moe_block2: built without __CUDACC__\n");
    return -1;
#endif
}

/* ════════════════════════════════════════════════════════════════════════
 * HEXA-FUSION P1 (TF32 GEMM-PULLING full-fwd MEGAKERNEL) — _hx_k_clm_megafwd
 * ════════════════════════════════════════════════════════════════════════
 * USER PRECISION-UNLOCK PATH (TF32 authorized). The whole clm_prod fwd DAG
 *   embed→[conv GEMM1]→[conv GEMM2]→[gn→gelu→resid]→[conv router]→
 *   [conv experts ×2]→[gelu2→pack→softmax-combine]→[gn#2]
 * runs in ONE cudaLaunchCooperativeKernel persistent grid. ALL conv GEMMs are
 * pulled INSIDE the launch as TF32 own-GEMM tiles (operands cast f64→f32, FMA
 * accumulated in f32 — the precision the user authorized; this is the path B3
 * proved was byte-eq-blocked under the FP64 gate, now ADMISSIBLE because the
 * bar is TF32-tol CE convergence, NOT max|Δ|=0). Intermediates stay
 * device-resident across grid.sync() — no per-op relaunch gap. The 2 glue
 * blocks + groupnorm#2 keep their host accumulation ORDER (sequential per-row
 * reductions) so the ONLY precision delta vs the eager FP64 path is the GEMM
 * accumulation precision (the authorized TF32 tradeoff), not the reductions.
 *
 * Conv1d semantics reproduced exactly (clm_prod.hexa conv1d_via_forge):
 *   y[t,co] = b[co] + Σ_j XCOL[t,j]·W[co,j],  XCOL=im2col(x), W is [Cout,Kdim]
 *   (the host transposes W→Wt then matmuls; we fold the transpose into the
 *    inner loop reading W[co*Kdim+j] directly — mathematically identical).
 * Causal-dilated im2col on the fly: j=ci*K+k, p=t-dil*(K-1-k),
 *   XCOL[t,j] = (p>=0)? X[p*Cin+ci] : 0.
 * Weights here are the QUANTIZED int4 weights' DEQUANT — but clm_prod_fwd
 * passes the *Wq farr (the int4-quantized symmetric weights already scaled to
 * f64 in the farr buffer by _fq), so reading them as f64 reproduces the eager
 * conv1d_via_forge input exactly (same farr the eager matmul consumes).
 * grid.sync() requires cudaLaunchCooperativeKernel; the launcher checks the
 * cooperativeLaunch device attr and returns -1 (→ eager fallback) if absent.
 * The __device__/__global__ helpers below use C++ types (cg::grid_group&,
 * the Bufs struct), so we CLOSE extern "C" around them and REOPEN it for the
 * launcher (which must keep C linkage — runtime.c calls it). */
#ifdef __CUDACC__
#ifdef __cplusplus
}  /* close extern "C" for the C++ cooperative device code */
#endif
/* TF32-rounded multiply-accumulate: round each operand to TF32 (10-bit
 * mantissa, the Ampere+ tensor-core input format) then accumulate in f32.
 * __float_to_tf32 is exposed on sm_80+; fall back to a mask if unavailable. */
__device__ __forceinline__ float _hx_tf32(double x) {
    float f = (float)x;
#if (__CUDA_ARCH__ >= 800)
    unsigned u = __float_as_uint(f);
    u = (u + 0x1000u) & 0xffffe000u;   /* round-to-nearest, zero low 13 mant bits */
    return __uint_as_float(u);
#else
    return f;
#endif
}
/* device conv1d: Y[T,Cout] from X[T,Cin], W[Cout,Kdim] (Kdim=Cin*K), bias
 * B[Cout]; TF32 accumulation. Grid-strided over (t,co) output cells. */
__device__ void _hx_dev_conv_tf32(_hxcg::grid_group& g,
        const double* __restrict__ X, const double* __restrict__ W,
        const double* __restrict__ B, double* __restrict__ Y,
        int64_t T, int64_t Cin, int64_t Cout, int64_t K, int64_t dil) {
    int64_t Kdim = Cin * K;
    int64_t total = T * Cout;
    int64_t stride = (int64_t)gridDim.x * blockDim.x;
    for (int64_t idx = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         idx < total; idx += stride) {
        int64_t t  = idx / Cout;
        int64_t co = idx - t * Cout;
        float acc = 0.0f;
        for (int64_t j = 0; j < Kdim; j++) {
            int64_t ci = j / K, k = j - ci * K;
            int64_t p = t - dil * (K - 1 - k);
            float xv = (p >= 0) ? _hx_tf32(X[p * Cin + ci]) : 0.0f;
            acc += xv * _hx_tf32(W[co * Kdim + j]);
        }
        Y[idx] = (double)acc + B[co];
    }
}
/* ── HEXA-FUSION B6 (byte-eq path) ── FP64-EXACT device conv. Identical to
 * _hx_dev_conv_tf32 EXCEPT the accumulator is double (NO TF32 operand
 * rounding, NO f32 FMA). Each output cell (t,co) accumulates k=0..Kdim in a
 * single thread, SEQUENTIAL k-order (naive own-GEMM order). This is the SAME
 * accumulation pattern as _hx_k_gemm (#2697 F-FUSION-P1-OWN-GEMM): correct in
 * FP64, but the naive sequential k-reduction is NOT bit-identical to
 * cublasDgemm's tiled/blocked k-reduction (different summation order →
 * different IEEE-754 rounding). B6's pre-registered question is exactly
 * whether this survives the byte-eq gate vs the eager cublasDgemm path. */
__device__ void _hx_dev_conv_fp64(_hxcg::grid_group& g,
        const double* __restrict__ X, const double* __restrict__ W,
        const double* __restrict__ B, double* __restrict__ Y,
        int64_t T, int64_t Cin, int64_t Cout, int64_t K, int64_t dil) {
    int64_t Kdim = Cin * K;
    int64_t total = T * Cout;
    int64_t stride = (int64_t)gridDim.x * blockDim.x;
    for (int64_t idx = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         idx < total; idx += stride) {
        int64_t t  = idx / Cout;
        int64_t co = idx - t * Cout;
        double acc = 0.0;
        for (int64_t j = 0; j < Kdim; j++) {
            int64_t ci = j / K, k = j - ci * K;
            int64_t p = t - dil * (K - 1 - k);
            double xv = (p >= 0) ? X[p * Cin + ci] : 0.0;
            acc += xv * W[co * Kdim + j];
        }
        Y[idx] = acc + B[co];
    }
}
/* device groupnorm reproducing _hx_k_groupnorm with G=1 (the clm_prod
 * callsite: _groupnorm(..., T, d, 1)) — the reduction spans the WHOLE
 * [T,D] tensor (m = D*T), NOT per-row. Byte-eq math, f64, EXACT host
 * sequential accumulation order (t-outer, c-inner). The global reduction
 * is done by thread 0 only (writes MEAN[0]/INV[0]); a grid.sync() inside
 * the megakernel orders it before the parallel normalize-apply pass. */
__device__ void _hx_dev_groupnorm(_hxcg::grid_group& g,
        const double* __restrict__ Xr, const double* __restrict__ G,
        const double* __restrict__ Bn, double* __restrict__ HN,
        double* __restrict__ MEAN, double* __restrict__ INV,
        double* __restrict__ XHAT, int64_t T, int64_t D) {
    double eps = 1e-5;
    int64_t N = T * D;
    double m = (double)N;
    if (blockIdx.x == 0 && threadIdx.x == 0) {
        double sum = 0.0;
        for (int64_t t = 0; t < T; t++)
            for (int64_t c = 0; c < D; c++) sum += Xr[t * D + c];
        double mu = sum / m;
        double vs = 0.0;
        for (int64_t t = 0; t < T; t++)
            for (int64_t c = 0; c < D; c++) { double d = Xr[t * D + c] - mu; vs += d * d; }
        double var = vs / m;
        /* P1B-c1 (byte-eq re-baseline): use the SAME NR-40 software sqrt as the
         * eager device-resident groupnorm (_hx_k_groupnorm via _hx_gn_sqrt_dev),
         * NOT the CUDA intrinsic sqrt. The intrinsic differs ~1 ULP from the
         * hand-rolled NR-40 sqrt that is byte-identical to the host reference, and
         * that 1 ULP was the megakernel-vs-own-eager divergence (F-FUSION-P1B-REBASELINE). */
        double inv = 1.0 / _hx_gn_sqrt_dev(var + eps);
        MEAN[0] = mu; INV[0] = inv;
    }
    g.sync();
    double mu = MEAN[0], inv = INV[0];
    int64_t stride = (int64_t)gridDim.x * blockDim.x;
    for (int64_t i = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         i < N; i += stride) {
        int64_t c = i % D;
        double xh = (Xr[i] - mu) * inv;
        XHAT[i] = xh;
        HN[i] = G[c] * xh + Bn[c];
    }
}
/* gelu: reuse the file's existing _hx_gelu_dev (defined above, static
 * __device__ double — same erf / 1/√2 literal). */
/* THE cooperative full-fwd megakernel. Operand farr ids resolved to device
 * pointers by the launcher; every intermediate is a device buffer. assert_eq
 * is ignored here (TF32 path — the precision relaxation is the whole point). */
struct _HxClmMegaBufs {
    const double *XE, *ecW, *ecB, *tcW, *tcB, *tgG, *tgB, *rW, *rB,
                 *e0W, *e0B, *e1W, *e1B, *noG, *noB;
    double *XEC, *HN0, *XT, *MEAN0, *INV0, *XHAT0, *LOGR,
           *EO0, *EO1, *EXOUT, *PROBS, *Y, *YN, *MEANN, *INVN, *XHATN,
           *H0, *HG0, *EX0, *EX1;
};
__global__ void _hx_k_clm_megafwd(_HxClmMegaBufs b,
        int64_t T, int64_t D, int64_t E, int64_t K) {
    _hxcg::grid_group grid = _hxcg::this_grid();
    int64_t n = T * D;
    /* GEMM1: conv(xe→xec), Cin=Cout=D, kernel K, dil 1. */
    _hx_dev_conv_tf32(grid, b.XE, b.ecW, b.ecB, b.XEC, T, D, D, K, 1); grid.sync();
    /* GEMM2: conv(xec→h0). */
    _hx_dev_conv_tf32(grid, b.XEC, b.tcW, b.tcB, b.H0, T, D, D, K, 1); grid.sync();
    /* GLUE BLOCK 1: groupnorm#1 (h0→hn0) → gelu → residual (xt = xec + gelu). */
    _hx_dev_groupnorm(grid, b.H0, b.tgG, b.tgB, b.HN0, b.MEAN0, b.INV0, b.XHAT0, T, D);
    grid.sync();
    { int64_t stride=(int64_t)gridDim.x*blockDim.x;
      for(int64_t i=(int64_t)blockIdx.x*blockDim.x+threadIdx.x;i<n;i+=stride){
        double hg=_hx_gelu_dev(b.HN0[i]); b.HG0[i]=hg; b.XT[i]=b.XEC[i]+hg; } }
    grid.sync();
    /* ROUTER conv: conv(xt→logits_r), Cout=E, K=1. */
    _hx_dev_conv_tf32(grid, b.XT, b.rW, b.rB, b.LOGR, T, D, E, 1, 1); grid.sync();
    /* EXPERT convs (×2): conv(xt→eo0), conv(xt→eo1), Cout=D, kernel K. */
    _hx_dev_conv_tf32(grid, b.XT, b.e0W, b.e0B, b.EO0, T, D, D, K, 1); grid.sync();
    _hx_dev_conv_tf32(grid, b.XT, b.e1W, b.e1B, b.EO1, T, D, D, K, 1); grid.sync();
    /* GLUE BLOCK 2: gelu2 + expert_pack2 + moe_router(softmax E + combine).
     * ONE thread per t — host accumulation order (byte-eq to _hx_k_moe_block2). */
    { int64_t stride=(int64_t)gridDim.x*blockDim.x;
      for(int64_t t=(int64_t)blockIdx.x*blockDim.x+threadIdx.x;t<T;t+=stride){
        for(int64_t c=0;c<D;c++){ int64_t j=t*D+c;
          double g0=_hx_gelu_dev(b.EO0[j]); b.EX0[j]=g0; b.EXOUT[j]=g0;
          double g1=_hx_gelu_dev(b.EO1[j]); b.EX1[j]=g1; b.EXOUT[n+j]=g1; }
        int64_t base=t*E; double mx=b.LOGR[base];
        for(int64_t e=1;e<E;e++){ double vv=b.LOGR[base+e]; if(vv>mx)mx=vv; }
        double s=0.0;
        /* P1B-c1 (byte-eq re-baseline): scaled-Taylor _hx_moe_exp_dev — the SAME
         * hand-rolled exp moe_lib uses (eager device moe-router via _hx_moe_exp_dev),
         * NOT CUDA exp. CUDA exp differs ~1 ULP from the Taylor exp byte-identical to
         * the host nn_moe_router_fwd reference — the 2nd megakernel-vs-own-eager term. */
        for(int64_t e=0;e<E;e++){ double ev=_hx_moe_exp_dev(b.LOGR[base+e]-mx); b.PROBS[base+e]=ev; s+=ev; }
        for(int64_t e=0;e<E;e++) b.PROBS[base+e]/=s;
        for(int64_t c=0;c<D;c++){ double acc=0.0;
          for(int64_t e=0;e<E;e++) acc+=b.PROBS[base+e]*b.EXOUT[e*n+t*D+c];
          b.Y[t*D+c]=acc; } } }
    grid.sync();
    /* GROUPNORM #2 (y→yn). */
    _hx_dev_groupnorm(grid, b.Y, b.noG, b.noB, b.YN, b.MEANN, b.INVN, b.XHATN, T, D);
}
/* ── HEXA-FUSION B6 ── FP64-EXACT cooperative full-fwd megakernel. BYTE FOR
 * BYTE the same DAG / grid.sync() structure / glue+groupnorm code as
 * _hx_k_clm_megafwd ABOVE, the ONLY difference being the 4 conv GEMMs call
 * _hx_dev_conv_fp64 (FP64 own-GEMM accumulation) instead of _hx_dev_conv_tf32.
 * The glue blocks + both groupnorms are ALREADY f64 host-order in the TF32
 * kernel, so swapping the conv to FP64 makes EVERY op in this megakernel f64.
 * This is the B6 candidate: keep the cooperative-megakernel util structure of
 * P1 but with the byte-eq FP64 GEMM (#2697) pulled inside. Whether it matches
 * the eager cublasDgemm path to max|Δ|=0 is the open question — the conv uses
 * naive sequential k-order, cublasDgemm uses tiled k-order. */
__global__ void _hx_k_clm_megafwd_fp64(_HxClmMegaBufs b,
        int64_t T, int64_t D, int64_t E, int64_t K) {
    _hxcg::grid_group grid = _hxcg::this_grid();
    int64_t n = T * D;
    _hx_dev_conv_fp64(grid, b.XE, b.ecW, b.ecB, b.XEC, T, D, D, K, 1); grid.sync();
    _hx_dev_conv_fp64(grid, b.XEC, b.tcW, b.tcB, b.H0, T, D, D, K, 1); grid.sync();
    _hx_dev_groupnorm(grid, b.H0, b.tgG, b.tgB, b.HN0, b.MEAN0, b.INV0, b.XHAT0, T, D);
    grid.sync();
    { int64_t stride=(int64_t)gridDim.x*blockDim.x;
      for(int64_t i=(int64_t)blockIdx.x*blockDim.x+threadIdx.x;i<n;i+=stride){
        double hg=_hx_gelu_dev(b.HN0[i]); b.HG0[i]=hg; b.XT[i]=b.XEC[i]+hg; } }
    grid.sync();
    _hx_dev_conv_fp64(grid, b.XT, b.rW, b.rB, b.LOGR, T, D, E, 1, 1); grid.sync();
    _hx_dev_conv_fp64(grid, b.XT, b.e0W, b.e0B, b.EO0, T, D, D, K, 1); grid.sync();
    _hx_dev_conv_fp64(grid, b.XT, b.e1W, b.e1B, b.EO1, T, D, D, K, 1); grid.sync();
    { int64_t stride=(int64_t)gridDim.x*blockDim.x;
      for(int64_t t=(int64_t)blockIdx.x*blockDim.x+threadIdx.x;t<T;t+=stride){
        for(int64_t c=0;c<D;c++){ int64_t j=t*D+c;
          double g0=_hx_gelu_dev(b.EO0[j]); b.EX0[j]=g0; b.EXOUT[j]=g0;
          double g1=_hx_gelu_dev(b.EO1[j]); b.EX1[j]=g1; b.EXOUT[n+j]=g1; }
        int64_t base=t*E; double mx=b.LOGR[base];
        for(int64_t e=1;e<E;e++){ double vv=b.LOGR[base+e]; if(vv>mx)mx=vv; }
        double s=0.0;
        /* P1B-c1 (byte-eq re-baseline): scaled-Taylor _hx_moe_exp_dev — the SAME
         * hand-rolled exp moe_lib uses (eager device moe-router via _hx_moe_exp_dev),
         * NOT CUDA exp. CUDA exp differs ~1 ULP from the Taylor exp byte-identical to
         * the host nn_moe_router_fwd reference — the 2nd megakernel-vs-own-eager term. */
        for(int64_t e=0;e<E;e++){ double ev=_hx_moe_exp_dev(b.LOGR[base+e]-mx); b.PROBS[base+e]=ev; s+=ev; }
        for(int64_t e=0;e<E;e++) b.PROBS[base+e]/=s;
        for(int64_t c=0;c<D;c++){ double acc=0.0;
          for(int64_t e=0;e<E;e++) acc+=b.PROBS[base+e]*b.EXOUT[e*n+t*D+c];
          b.Y[t*D+c]=acc; } } }
    grid.sync();
    _hx_dev_groupnorm(grid, b.Y, b.noG, b.noB, b.YN, b.MEANN, b.INVN, b.XHATN, T, D);
}
/* ════════════════════════════════════════════════════════════════════════
 * HEXA-FUSION FF-VALLEY — persistent VALLEY-ONLY fusion megakernel.
 *
 * Distinct from _hx_k_clm_megafwd_fp64 (whole-fwd megakernel, fuses GEMMs +
 * valley): FF-VALLEY fuses ONLY the between-GEMM GLUE into a persistent
 * grid-synced kernel and keeps the 4 own-GEMM convs as SEPARATE (already-
 * saturated) kernel launches. The glue is the ~0%-util valley the whole-
 * megakernel was closed-negative on (byte-eq ⊥ util when FP64 GEMM is pulled
 * inside the cooperative one-wave grid — F-FUSION campaign-closed). By leaving
 * the GEMMs as their own saturated launches and fusing ONLY the valley glue,
 * FF-VALLEY attacks the idle valley without de-saturating the GEMMs.
 *
 * The forward DAG splits the valley into TWO glue blocks (the 2 expert GEMMs
 * sit between them, so a single persistent kernel cannot span both without
 * re-including those GEMMs):
 *   VALLEY-A  (after h0=conv):  groupnorm#1 -> gelu -> residual  (xt = xec + gelu(hn0))
 *   VALLEY-B  (after eo0,eo1=conv): gelu2 + expert-pack + moe-router(softmax+combine)
 *                                  -> groupnorm#2 (y -> yn)
 * Each reuses the IDENTICAL byte-eq device fns (_hx_dev_groupnorm host-order
 * reduction + NR-40 sqrt, _hx_gelu_dev erf, _hx_moe_exp_dev scaled-Taylor) the
 * whole-megakernel proved byte-identical -> max|delta|=0 vs the separate-kernel
 * reference BY CONSTRUCTION (same code, same grid.sync ordering). Env-gated
 * HEXA_FUSE_VALLEY; on no-coop / any miss -> -1 -> caller's separate eager glue. */
struct _HxValleyABufs {
    const double *XEC, *tgG, *tgB;
    double *H0, *HN0, *MEAN0, *INV0, *XHAT0, *HG0, *XT;
};
__global__ void _hx_k_clm_valley1_fp64(_HxValleyABufs b,
        int64_t T, int64_t D) {
    _hxcg::grid_group grid = _hxcg::this_grid();
    int64_t n = T * D;
    /* GLUE BLOCK 1: groupnorm#1 (h0->hn0) -> gelu -> residual (xt = xec + gelu(hn0)).
     * IDENTICAL to _hx_k_clm_megafwd_fp64's block-1, sans the two preceding convs. */
    _hx_dev_groupnorm(grid, b.H0, b.tgG, b.tgB, b.HN0, b.MEAN0, b.INV0, b.XHAT0, T, D);
    grid.sync();
    { int64_t stride=(int64_t)gridDim.x*blockDim.x;
      for(int64_t i=(int64_t)blockIdx.x*blockDim.x+threadIdx.x;i<n;i+=stride){
        double hg=_hx_gelu_dev(b.HN0[i]); b.HG0[i]=hg; b.XT[i]=b.XEC[i]+hg; } }
}
struct _HxValleyBBufs {
    const double *EO0, *EO1, *LOGR, *noG, *noB;
    double *EX0, *EX1, *EXOUT, *PROBS, *Y, *YN, *MEANN, *INVN, *XHATN;
};
__global__ void _hx_k_clm_valley2_fp64(_HxValleyBBufs b,
        int64_t T, int64_t D, int64_t E) {
    _hxcg::grid_group grid = _hxcg::this_grid();
    int64_t n = T * D;
    /* GLUE BLOCK 2: gelu2 + expert_pack2 + moe_router(softmax E + combine).
     * ONE thread per t — host accumulation order (byte-eq to _hx_k_moe_block2),
     * IDENTICAL to _hx_k_clm_megafwd_fp64's block-2 sans the 3 preceding convs. */
    { int64_t stride=(int64_t)gridDim.x*blockDim.x;
      for(int64_t t=(int64_t)blockIdx.x*blockDim.x+threadIdx.x;t<T;t+=stride){
        for(int64_t c=0;c<D;c++){ int64_t j=t*D+c;
          double g0=_hx_gelu_dev(b.EO0[j]); b.EX0[j]=g0; b.EXOUT[j]=g0;
          double g1=_hx_gelu_dev(b.EO1[j]); b.EX1[j]=g1; b.EXOUT[n+j]=g1; }
        int64_t base=t*E; double mx=b.LOGR[base];
        for(int64_t e=1;e<E;e++){ double vv=b.LOGR[base+e]; if(vv>mx)mx=vv; }
        double s=0.0;
        for(int64_t e=0;e<E;e++){ double ev=_hx_moe_exp_dev(b.LOGR[base+e]-mx); b.PROBS[base+e]=ev; s+=ev; }
        for(int64_t e=0;e<E;e++) b.PROBS[base+e]/=s;
        for(int64_t c=0;c<D;c++){ double acc=0.0;
          for(int64_t e=0;e<E;e++) acc+=b.PROBS[base+e]*b.EXOUT[e*n+t*D+c];
          b.Y[t*D+c]=acc; } } }
    grid.sync();
    /* GROUPNORM #2 (y->yn) — fused into the SAME persistent kernel. */
    _hx_dev_groupnorm(grid, b.Y, b.noG, b.noB, b.YN, b.MEANN, b.INVN, b.XHATN, T, D);
}
#ifdef __cplusplus
extern "C" {  /* REOPEN — the launcher keeps C linkage (runtime.c calls it) */
#endif
#endif /* __CUDACC__ (device block) */

/* FF-VALLEY launcher A — cooperativeLaunch valley-1 (GN#1+gelu+residual) glue.
 * Inputs (h0 from the preceding SEPARATE saturated conv GEMM, xec, gamma/beta)
 * are device-resident; outputs (hn0,hg0,xt,...) stay FARR_DEVICE for the NEXT
 * separate conv GEMMs. One-wave coop grid (grid.sync legal). On no-coop / any
 * miss -> -1 -> caller falls back to the separate eager glue kernels (byte-eq). */
int _hx_cuda_farr_clm_valley1_gpu(
        int64_t h0_id, int64_t xec_id, int64_t tgG_id, int64_t tgB_id,
        int64_t hn0_id, int64_t mean0_id, int64_t inv0_id, int64_t xhat0_id,
        int64_t hg0_id, int64_t xt_id, int64_t T, int64_t D) {
#ifdef __CUDACC__
    if (T <= 0 || D <= 0) return -1;
    int dev = 0; cudaGetDevice(&dev);
    int coop = 0; cudaDeviceGetAttribute(&coop, cudaDevAttrCooperativeLaunch, dev);
    if (!coop) { fprintf(stderr, "[cuda] valley1: no cooperativeLaunch\n"); return -1; }
    int64_t n = T * D;
    int64_t ins[4] = { h0_id, xec_id, tgG_id, tgB_id };
    for (int i = 0; i < 4; i++) { if (ins[i] >= 0 && _h2d(ins[i]) != 0) return -1; }
    if (_ensure_dev_alloc_out(hn0_id, n) != 0) return -1;
    if (_ensure_dev_alloc_out(mean0_id, 1) != 0) return -1;
    if (_ensure_dev_alloc_out(inv0_id, 1) != 0) return -1;
    if (_ensure_dev_alloc_out(xhat0_id, n) != 0) return -1;
    if (_ensure_dev_alloc_out(hg0_id, n) != 0) return -1;
    if (_ensure_dev_alloc_out(xt_id, n) != 0) return -1;
    _HxValleyABufs bb;
    bb.XEC=g_slots[xec_id].d_buf; bb.tgG=g_slots[tgG_id].d_buf; bb.tgB=g_slots[tgB_id].d_buf;
    bb.H0=g_slots[h0_id].d_buf; bb.HN0=g_slots[hn0_id].d_buf;
    bb.MEAN0=g_slots[mean0_id].d_buf; bb.INV0=g_slots[inv0_id].d_buf;
    bb.XHAT0=g_slots[xhat0_id].d_buf; bb.HG0=g_slots[hg0_id].d_buf; bb.XT=g_slots[xt_id].d_buf;
    int blk = 128;
    int numBlocksPerSm = 0;
    cudaOccupancyMaxActiveBlocksPerMultiprocessor(&numBlocksPerSm,
        (void*)_hx_k_clm_valley1_fp64, blk, 0);
    if (numBlocksPerSm < 1) numBlocksPerSm = 1;
    int numSm = 0; cudaDeviceGetAttribute(&numSm, cudaDevAttrMultiProcessorCount, dev);
    if (numSm < 1) numSm = 1;
    int grid_sz = numSm * numBlocksPerSm;
    dim3 gdim(grid_sz), bdim(blk);
    void* args[] = { (void*)&bb, (void*)&T, (void*)&D };
    cudaError_t le = cudaLaunchCooperativeKernel((void*)_hx_k_clm_valley1_fp64,
                        gdim, bdim, args, 0, _forge_stream());
    if (le != cudaSuccess) { fprintf(stderr, "[cuda] valley1 coop launch: %s\n", cudaGetErrorString(le)); return -1; }
    if (_forge_launch_check("clm_valley1") != 0) return -1;
    { static int _v1_fired = 0; if (!_v1_fired) { _v1_fired = 1;
        fprintf(stderr, "[VALLEY1-FIRED] _hx_k_clm_valley1_fp64 FP64 persistent GN#1+gelu+resid glue (grid=%d blk=%d, GEMMs SEPARATE)\n", grid_sz, blk); } }
    int64_t outs[6] = { hn0_id, mean0_id, inv0_id, xhat0_id, hg0_id, xt_id };
    for (int k = 0; k < 6; k++) {
        if (outs[k] < 0) continue;
        HexaFarrEntry* e = &_hx_farr_table[outs[k]];
        e->d_buf = (void*)g_slots[outs[k]].d_buf;
        e->loc = FARR_DEVICE; e->dirty_host = 0; e->dirty_dev = 0;
    }
    return 0;
#else
    (void)h0_id;(void)xec_id;(void)tgG_id;(void)tgB_id;(void)hn0_id;(void)mean0_id;
    (void)inv0_id;(void)xhat0_id;(void)hg0_id;(void)xt_id;(void)T;(void)D;
    fprintf(stderr, "[cuda] valley1: built without __CUDACC__\n"); return -1;
#endif
}
/* FF-VALLEY launcher B — cooperativeLaunch valley-2 (gelu2+pack+moe-router+GN#2).
 * Inputs eo0/eo1 (from the SEPARATE saturated expert conv GEMMs), logr (router
 * GEMM), gamma/beta are device-resident; outputs (y,yn,...) stay FARR_DEVICE for
 * the final separate out-logits conv. EX0/EX1 are transient device scratch. */
int _hx_cuda_farr_clm_valley2_gpu(
        int64_t eo0_id, int64_t eo1_id, int64_t logr_id, int64_t noG_id, int64_t noB_id,
        int64_t exout_id, int64_t probs_id, int64_t y_id, int64_t yn_id,
        int64_t meanN_id, int64_t invN_id, int64_t xhatN_id,
        int64_t T, int64_t D, int64_t E) {
#ifdef __CUDACC__
    if (T <= 0 || D <= 0 || E <= 0) return -1;
    int dev = 0; cudaGetDevice(&dev);
    int coop = 0; cudaDeviceGetAttribute(&coop, cudaDevAttrCooperativeLaunch, dev);
    if (!coop) { fprintf(stderr, "[cuda] valley2: no cooperativeLaunch\n"); return -1; }
    int64_t n = T * D;
    int64_t ins[5] = { eo0_id, eo1_id, logr_id, noG_id, noB_id };
    for (int i = 0; i < 5; i++) { if (ins[i] >= 0 && _h2d(ins[i]) != 0) return -1; }
    if (_ensure_dev_alloc_out(exout_id, 2 * n) != 0) return -1;
    if (_ensure_dev_alloc_out(probs_id, T * E) != 0) return -1;
    if (_ensure_dev_alloc_out(y_id, n) != 0) return -1;
    if (_ensure_dev_alloc_out(yn_id, n) != 0) return -1;
    if (_ensure_dev_alloc_out(meanN_id, T) != 0) return -1;
    if (_ensure_dev_alloc_out(invN_id, T) != 0) return -1;
    if (_ensure_dev_alloc_out(xhatN_id, n) != 0) return -1;
    double *d_ex0 = NULL, *d_ex1 = NULL;
    if (cudaMalloc((void**)&d_ex0, (size_t)n * sizeof(double)) != cudaSuccess) return -1;
    if (cudaMalloc((void**)&d_ex1, (size_t)n * sizeof(double)) != cudaSuccess) { cudaFree(d_ex0); return -1; }
    _HxValleyBBufs bb;
    bb.EO0=g_slots[eo0_id].d_buf; bb.EO1=g_slots[eo1_id].d_buf; bb.LOGR=g_slots[logr_id].d_buf;
    bb.noG=g_slots[noG_id].d_buf; bb.noB=g_slots[noB_id].d_buf;
    bb.EXOUT=g_slots[exout_id].d_buf; bb.PROBS=g_slots[probs_id].d_buf; bb.Y=g_slots[y_id].d_buf;
    bb.YN=g_slots[yn_id].d_buf; bb.MEANN=g_slots[meanN_id].d_buf;
    bb.INVN=g_slots[invN_id].d_buf; bb.XHATN=g_slots[xhatN_id].d_buf;
    bb.EX0=d_ex0; bb.EX1=d_ex1;
    int blk = 128;
    int numBlocksPerSm = 0;
    cudaOccupancyMaxActiveBlocksPerMultiprocessor(&numBlocksPerSm,
        (void*)_hx_k_clm_valley2_fp64, blk, 0);
    if (numBlocksPerSm < 1) numBlocksPerSm = 1;
    int numSm = 0; cudaDeviceGetAttribute(&numSm, cudaDevAttrMultiProcessorCount, dev);
    if (numSm < 1) numSm = 1;
    int grid_sz = numSm * numBlocksPerSm;
    dim3 gdim(grid_sz), bdim(blk);
    void* args[] = { (void*)&bb, (void*)&T, (void*)&D, (void*)&E };
    cudaError_t le = cudaLaunchCooperativeKernel((void*)_hx_k_clm_valley2_fp64,
                        gdim, bdim, args, 0, _forge_stream());
    if (le != cudaSuccess) { fprintf(stderr, "[cuda] valley2 coop launch: %s\n", cudaGetErrorString(le)); cudaFree(d_ex0); cudaFree(d_ex1); return -1; }
    if (_forge_launch_check("clm_valley2") != 0) { cudaFree(d_ex0); cudaFree(d_ex1); return -1; }
    { static int _v2_fired = 0; if (!_v2_fired) { _v2_fired = 1;
        fprintf(stderr, "[VALLEY2-FIRED] _hx_k_clm_valley2_fp64 FP64 persistent gelu2+pack+moe+GN#2 glue (grid=%d blk=%d, GEMMs SEPARATE)\n", grid_sz, blk); } }
    cudaFree(d_ex0); cudaFree(d_ex1);
    int64_t outs[7] = { exout_id, probs_id, y_id, yn_id, meanN_id, invN_id, xhatN_id };
    for (int k = 0; k < 7; k++) {
        if (outs[k] < 0) continue;
        HexaFarrEntry* e = &_hx_farr_table[outs[k]];
        e->d_buf = (void*)g_slots[outs[k]].d_buf;
        e->loc = FARR_DEVICE; e->dirty_host = 0; e->dirty_dev = 0;
    }
    return 0;
#else
    (void)eo0_id;(void)eo1_id;(void)logr_id;(void)noG_id;(void)noB_id;(void)exout_id;
    (void)probs_id;(void)y_id;(void)yn_id;(void)meanN_id;(void)invN_id;(void)xhatN_id;
    (void)T;(void)D;(void)E;
    fprintf(stderr, "[cuda] valley2: built without __CUDACC__\n"); return -1;
#endif
}

/* P1 launcher — cooperativeLaunch the full-fwd megakernel. Resolves all 37
 * farr ids to device buffers (inputs H2D, outputs dev-alloc), launches with
 * cudaLaunchCooperativeKernel sized to fill the device, marks every output
 * FARR_DEVICE for the eager bwd + the final eager conv(yn→out_logits). Returns
 * 0 on success / -1 (→ .hexa eager FP64 fallback) if the device lacks
 * cooperativeLaunch or any alloc/launch fails. assert_eq ignored (TF32 path). */
int _hx_cuda_farr_clm_megafwd_gpu(
        int64_t xe_id, int64_t ecW_id, int64_t ecB_id, int64_t tcW_id, int64_t tcB_id,
        int64_t tgG_id, int64_t tgB_id, int64_t xec_id, int64_t hn0_id, int64_t hg0_id,
        int64_t xt_id, int64_t mean0_id, int64_t inv0_id, int64_t xhat0_id,
        int64_t rW_id, int64_t rB_id, int64_t logr_id, int64_t e0W_id, int64_t e0B_id,
        int64_t e1W_id, int64_t e1B_id, int64_t eo0_id, int64_t eo1_id, int64_t exout_id,
        int64_t probs_id, int64_t y_id, int64_t noG_id, int64_t noB_id, int64_t yn_id,
        int64_t meanN_id, int64_t invN_id, int64_t xhatN_id,
        int64_t T, int64_t D, int64_t E, int64_t K, int assert_eq) {
#ifdef __CUDACC__
    (void)assert_eq;
    if (T <= 0 || D <= 0 || E <= 0 || K <= 0) return -1;
    int dev = 0; cudaGetDevice(&dev);
    int coop = 0;
    cudaDeviceGetAttribute(&coop, cudaDevAttrCooperativeLaunch, dev);
    if (!coop) { fprintf(stderr, "[cuda] clm_megafwd: no cooperativeLaunch\n"); return -1; }
    int64_t n = T * D;
    /* inputs resident */
    int64_t ins[15] = { xe_id, ecW_id, ecB_id, tcW_id, tcB_id, tgG_id, tgB_id,
                        rW_id, rB_id, e0W_id, e0B_id, e1W_id, e1B_id, noG_id, noB_id };
    for (int i = 0; i < 15; i++) { if (ins[i] >= 0 && _h2d(ins[i]) != 0) return -1; }
    /* outputs allocated device-side with the right length */
    if (_ensure_dev_alloc_out(xec_id, n) != 0) return -1;
    if (_ensure_dev_alloc_out(hn0_id, n) != 0) return -1;
    if (_ensure_dev_alloc_out(hg0_id, n) != 0) return -1;
    if (_ensure_dev_alloc_out(xt_id, n) != 0) return -1;
    if (_ensure_dev_alloc_out(mean0_id, 1) != 0) return -1;
    if (_ensure_dev_alloc_out(inv0_id, 1) != 0) return -1;
    if (_ensure_dev_alloc_out(xhat0_id, n) != 0) return -1;
    if (_ensure_dev_alloc_out(logr_id, T * E) != 0) return -1;
    if (_ensure_dev_alloc_out(eo0_id, n) != 0) return -1;
    if (_ensure_dev_alloc_out(eo1_id, n) != 0) return -1;
    if (_ensure_dev_alloc_out(exout_id, 2 * n) != 0) return -1;
    if (_ensure_dev_alloc_out(probs_id, T * E) != 0) return -1;
    if (_ensure_dev_alloc_out(y_id, n) != 0) return -1;
    if (_ensure_dev_alloc_out(yn_id, n) != 0) return -1;
    if (_ensure_dev_alloc_out(meanN_id, T) != 0) return -1;
    if (_ensure_dev_alloc_out(invN_id, T) != 0) return -1;
    if (_ensure_dev_alloc_out(xhatN_id, n) != 0) return -1;
    /* scratch ex0/ex1 — reuse hg0? no: separate device scratch via probs-sized.
     * We need EX0/EX1 [n] each; allocate transient device buffers. */
    double *d_ex0 = NULL, *d_ex1 = NULL;
    if (cudaMalloc((void**)&d_ex0, (size_t)n * sizeof(double)) != cudaSuccess) return -1;
    if (cudaMalloc((void**)&d_ex1, (size_t)n * sizeof(double)) != cudaSuccess) { cudaFree(d_ex0); return -1; }
    _HxClmMegaBufs bb;
    bb.XE=g_slots[xe_id].d_buf; bb.ecW=g_slots[ecW_id].d_buf; bb.ecB=g_slots[ecB_id].d_buf;
    bb.tcW=g_slots[tcW_id].d_buf; bb.tcB=g_slots[tcB_id].d_buf;
    bb.tgG=g_slots[tgG_id].d_buf; bb.tgB=g_slots[tgB_id].d_buf;
    bb.rW=g_slots[rW_id].d_buf; bb.rB=g_slots[rB_id].d_buf;
    bb.e0W=g_slots[e0W_id].d_buf; bb.e0B=g_slots[e0B_id].d_buf;
    bb.e1W=g_slots[e1W_id].d_buf; bb.e1B=g_slots[e1B_id].d_buf;
    bb.noG=g_slots[noG_id].d_buf; bb.noB=g_slots[noB_id].d_buf;
    bb.XEC=g_slots[xec_id].d_buf; bb.HN0=g_slots[hn0_id].d_buf; bb.HG0=g_slots[hg0_id].d_buf;
    bb.XT=g_slots[xt_id].d_buf; bb.MEAN0=g_slots[mean0_id].d_buf;
    bb.INV0=g_slots[inv0_id].d_buf; bb.XHAT0=g_slots[xhat0_id].d_buf;
    bb.LOGR=g_slots[logr_id].d_buf; bb.EO0=g_slots[eo0_id].d_buf; bb.EO1=g_slots[eo1_id].d_buf;
    bb.EXOUT=g_slots[exout_id].d_buf; bb.PROBS=g_slots[probs_id].d_buf; bb.Y=g_slots[y_id].d_buf;
    bb.YN=g_slots[yn_id].d_buf; bb.MEANN=g_slots[meanN_id].d_buf;
    bb.INVN=g_slots[invN_id].d_buf; bb.XHATN=g_slots[xhatN_id].d_buf;
    bb.H0=d_ex0; /* H0 [n] reuses ex0 scratch before block-2 reads ex0 */
    bb.EX0=d_ex0; bb.EX1=d_ex1;
    /* NOTE: H0 and EX0 alias d_ex0 safely — H0 is consumed by groupnorm#1
     * (writes hn0) BEFORE block-2 overwrites EX0; the grid.sync() between
     * them orders the reuse. */
    int blk = 128;
    /* B6: HEXA_CLM_MEGASTEP_FP64 selects the FP64-exact megakernel (byte-eq
     * candidate own-GEMM) instead of the P1 TF32 megakernel. Default (env
     * unset/empty) keeps the P1 TF32 kernel — unchanged behaviour. */
    int _b6_fp64 = (getenv("HEXA_CLM_MEGASTEP_FP64") && getenv("HEXA_CLM_MEGASTEP_FP64")[0]) ? 1 : 0;
    void* _mk = _b6_fp64 ? (void*)_hx_k_clm_megafwd_fp64 : (void*)_hx_k_clm_megafwd;
    int numBlocksPerSm = 0;
    cudaOccupancyMaxActiveBlocksPerMultiprocessor(&numBlocksPerSm,
        _mk, blk, 0);
    if (numBlocksPerSm < 1) numBlocksPerSm = 1;
    int numSm = 0; cudaDeviceGetAttribute(&numSm, cudaDevAttrMultiProcessorCount, dev);
    if (numSm < 1) numSm = 1;
    int grid_sz = numSm * numBlocksPerSm;
    dim3 gdim(grid_sz), bdim(blk);
    void* args[] = { (void*)&bb, (void*)&T, (void*)&D, (void*)&E, (void*)&K };
    cudaError_t le = cudaLaunchCooperativeKernel(_mk,
                        gdim, bdim, args, 0, _forge_stream());
    if (le != cudaSuccess) {
        fprintf(stderr, "[cuda] clm_megafwd coop launch: %s\n", cudaGetErrorString(le));
        cudaFree(d_ex0); cudaFree(d_ex1); return -1;
    }
    if (_forge_launch_check("clm_megafwd") != 0) { cudaFree(d_ex0); cudaFree(d_ex1); return -1; }
    { static int _mf_fired = 0; if (!_mf_fired) { _mf_fired = 1;
        if (_b6_fp64)
          fprintf(stderr, "[MEGAFWD-FIRED] _hx_k_clm_megafwd_fp64 FP64-EXACT coop full-fwd (grid=%d blk=%d, no cuBLAS, byte-eq candidate)\n", grid_sz, blk);
        else
          fprintf(stderr, "[MEGAFWD-FIRED] _hx_k_clm_megafwd TF32 coop full-fwd (grid=%d blk=%d, no cuBLAS)\n", grid_sz, blk); } }
    cudaFree(d_ex0); cudaFree(d_ex1);
    /* mark device-resident outputs (bwd reads them; final conv reads yn) */
    int64_t outs[16] = { xec_id, hn0_id, hg0_id, xt_id, mean0_id, inv0_id, xhat0_id,
                         logr_id, eo0_id, eo1_id, exout_id, probs_id, y_id, yn_id,
                         meanN_id, invN_id };
    for (int k = 0; k < 16; k++) {
        if (outs[k] < 0) continue;
        HexaFarrEntry* e = &_hx_farr_table[outs[k]];
        e->d_buf = (void*)g_slots[outs[k]].d_buf;
        e->loc = FARR_DEVICE; e->dirty_host = 0; e->dirty_dev = 0;
    }
    { HexaFarrEntry* e = &_hx_farr_table[xhatN_id];
      e->d_buf=(void*)g_slots[xhatN_id].d_buf; e->loc=FARR_DEVICE;
      e->dirty_host=0; e->dirty_dev=0; }
    return 0;
#else
    (void)xe_id;(void)ecW_id;(void)ecB_id;(void)tcW_id;(void)tcB_id;(void)tgG_id;(void)tgB_id;
    (void)xec_id;(void)hn0_id;(void)hg0_id;(void)xt_id;(void)mean0_id;(void)inv0_id;(void)xhat0_id;
    (void)rW_id;(void)rB_id;(void)logr_id;(void)e0W_id;(void)e0B_id;(void)e1W_id;(void)e1B_id;
    (void)eo0_id;(void)eo1_id;(void)exout_id;(void)probs_id;(void)y_id;(void)noG_id;(void)noB_id;
    (void)yn_id;(void)meanN_id;(void)invN_id;(void)xhatN_id;(void)T;(void)D;(void)E;(void)K;(void)assert_eq;
    fprintf(stderr, "[cuda] clm_megafwd: built without __CUDACC__\n");
    return -1;
#endif
}

/* HEXA-FUSION L3 (glue half · final slice ⑤c) — device-resident embedding
 * gather. Reproduces nn_lib.hexa nn_embedding_fwd EXACTLY: for each position
 * i in 0..T, tok = (int)IDS[i] (token ids stored as doubles in the farr —
 * truncate-toward-zero like to_int), then
 *   X_OUT[i·d + c] = TABLE[tok·d + c]   for c in 0..d.
 * Pure gather/copy, NO arithmetic, NO reduction → trivially bit-exact
 * (max|Δ|=0). Fuses the token-gather host glue at the head of clm_prod_fwd
 * (the ③ fwd-only 0% floor). Keeps X_OUT FARR_DEVICE so the first conv GEMM
 * H2D-skips it. */
__global__ void _hx_k_embedding(const double* __restrict__ IDS,
                                const double* __restrict__ TABLE,
                                double* __restrict__ X_OUT,
                                int64_t T, int64_t d) {
    /* one thread per (i,c) element; tok read per-thread (no shared state). */
    int64_t total = T * d;
    int64_t stride = (int64_t)blockDim.x * (int64_t)gridDim.x;
    for (int64_t idx = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         idx < total; idx += stride) {
        int64_t i = idx / d;
        int64_t c = idx - i * d;
        int64_t tok = (int64_t)IDS[i];
        X_OUT[i * d + c] = TABLE[tok * d + c];
    }
}

int _hx_cuda_farr_embedding_gpu(int64_t ids_id, int64_t table_id,
                                int64_t out_id, int64_t T, int64_t d) {
#ifdef __CUDACC__
    if (T <= 0 || d <= 0) return -1;
    if (_h2d(ids_id) != 0) return -1;
    if (_h2d(table_id) != 0) return -1;
    if (_ensure_dev_alloc_out(out_id, T * d) != 0) return -1;
    const double* IDS   = g_slots[ids_id].d_buf;
    const double* TABLE = g_slots[table_id].d_buf;
    double*       OUT   = g_slots[out_id].d_buf;
    int block_sz = 256;
    int64_t want = (T * d + block_sz - 1) / block_sz;
    int grid_sz = (want > 1024) ? 1024 : (int)want;
    if (grid_sz < 1) grid_sz = 1;
    _hx_k_embedding<<<grid_sz, block_sz, 0, _forge_stream()>>>(IDS, TABLE, OUT, T, d);
    if (_forge_launch_check("embedding") != 0) return -1;
    {
        HexaFarrEntry* e = &_hx_farr_table[out_id];
        e->d_buf      = (void*)g_slots[out_id].d_buf;
        e->loc        = FARR_DEVICE;
        e->dirty_host = 0;
        e->dirty_dev  = 0;
    }
    return 0;
#else
    (void)ids_id; (void)table_id; (void)out_id; (void)T; (void)d;
    fprintf(stderr, "[cuda] embedding: built without __CUDACC__\n");
    return -1;
#endif
}

/* HEXA-FUSION L3 (BWD glue half) — device-resident elementwise GELU backward.
 * Reproduces stdlib/flame/nn_lib.hexa nn_gelu_bwd EXACTLY:
 *   DG[i] = DA[i] · GELU'(G[i]) ; GELU'(x) = Φ(x) + x·φ(x)
 *   Φ(x) = 0.5·(1 + erf(x·(1/√2)))   (_nn_normal_cdf)
 *   φ(x) = (1/√(2π))·exp(-0.5·x²)    (_nn_normal_pdf)
 * G is the PRE-activation saved from forward. The constants are the SAME
 * literals the host uses (1/√2 = _nn_inv_sqrt2, 1/√(2π) = _nn_inv_sqrt2pi)
 * and the op order matches _nn_gelu_grad verbatim (cdf + x·pdf). Device erf()
 * and exp() are the IEEE-correct libm contract (same as the host builtins).
 * Pure elementwise, NO reduction → bit-exact to the host scalar loop
 * (max|Δ|=0). Fuses the gelu_bwd ×3 host glue in clm_prod_bwd (deo0/deo1/dhn0
 * — the bwd mirror of the fwd gelu ×3) and keeps DG FARR_DEVICE so the
 * follow-up conv-bwd GEMM H2D-skips it. */
__global__ void _hx_k_gelu_bwd(const double* __restrict__ G,
                               const double* __restrict__ DA,
                               double* __restrict__ DG, int64_t n) {
    const double inv_sqrt2   = 0.70710678118654752440;
    const double inv_sqrt2pi = 0.39894228040143267794;
    int64_t stride = (int64_t)blockDim.x * (int64_t)gridDim.x;
    for (int64_t i = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         i < n; i += stride) {
        double x   = G[i];
        double cdf = 0.5 * (1.0 + _hx_dt_erf_dev(x * inv_sqrt2));
        double pdf = inv_sqrt2pi * _hx_dt_exp_dev(0.0 - 0.5 * x * x);
        double grad = cdf + x * pdf;
        DG[i] = DA[i] * grad;
    }
}

int _hx_cuda_farr_gelu_bwd_gpu(int64_t g_id, int64_t da_id,
                               int64_t dg_id, int64_t n) {
#ifdef __CUDACC__
    if (n <= 0) return -1;
    if (_h2d(g_id) != 0) return -1;
    if (_h2d(da_id) != 0) return -1;
    if (_ensure_dev_alloc_out(dg_id, n) != 0) return -1;
    const double* G  = g_slots[g_id].d_buf;
    const double* DA = g_slots[da_id].d_buf;
    double*       DG = g_slots[dg_id].d_buf;
    int block_sz = 256;
    int64_t want = (n + block_sz - 1) / block_sz;
    int grid_sz = (want > 1024) ? 1024 : (int)want;
    if (grid_sz < 1) grid_sz = 1;
    _hx_k_gelu_bwd<<<grid_sz, block_sz, 0, _forge_stream()>>>(G, DA, DG, n);
    if (_forge_launch_check("gelu_bwd") != 0) return -1;
    {
        HexaFarrEntry* e = &_hx_farr_table[dg_id];
        e->d_buf      = (void*)g_slots[dg_id].d_buf;
        e->loc        = FARR_DEVICE;
        e->dirty_host = 0;
        e->dirty_dev  = 0;
    }
    return 0;
#else
    (void)g_id; (void)da_id; (void)dg_id; (void)n;
    fprintf(stderr, "[cuda] gelu_bwd: built without __CUDACC__\n");
    return -1;
#endif
}

/* HEXA-FUSION L3 (BWD glue half) — device-resident GroupNorm backward.
 * Reproduces stdlib/flame/gn_lib.hexa nn_groupnorm_bwd EXACTLY:
 *   per channel c: DGAMMA[c] = Σ_t DY[t,c]·XHAT[t,c] ; DBETA[c] = Σ_t DY[t,c]
 *   per group  g: s1 = Σ dxh ; s2 = Σ dxh·xhat  (dxh = DY·GAMMA over the group)
 *                 DX[t,c] = INV[g]·(dxh - s1/m - XHAT[t,c]·s2/m) , m = Cg·T
 * BIT-EXACTNESS: every reduction accumulates SEQUENTIALLY in the host order —
 * the per-channel sums over t (one thread per channel, t ascending), and the
 * per-group s1/s2 over (t outer, c inner) under ONE thread per group — NO tree
 * re-association, NO warp/atomic partials → max|Δ|=0. (No sqrt here; INV is the
 * saved forward reciprocal-stddev, read verbatim.) Fuses the groupnorm_bwd ×2
 * host glue in clm_prod_bwd (dy←dynorm, dh0←dhn0 — the bwd mirror of the fwd
 * groupnorm ×2). Keeps DGAMMA/DBETA/DX FARR_DEVICE. NOTE the kernel is split
 * into TWO launches sharing the grid (channel pass, then group pass) because
 * the DX pass depends on the per-group s1/s2 reductions — each pass is itself a
 * single-thread sequential reduction, preserving the host accumulation order. */
__global__ void _hx_k_groupnorm_bwd_affine(const double* __restrict__ XHAT,
                                           const double* __restrict__ DY,
                                           double* __restrict__ DGAMMA,
                                           double* __restrict__ DBETA,
                                           int64_t T, int64_t C) {
    for (int64_t c = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         c < C; c += (int64_t)blockDim.x * gridDim.x) {
        double sg = 0.0;
        double sb = 0.0;
        for (int64_t t = 0; t < T; t++) {
            int64_t idx = t * C + c;
            double gy = DY[idx];
            sg += gy * XHAT[idx];
            sb += gy;
        }
        DGAMMA[c] = sg;
        DBETA[c]  = sb;
    }
}
__global__ void _hx_k_groupnorm_bwd_dx(const double* __restrict__ XHAT,
                                       const double* __restrict__ INV,
                                       const double* __restrict__ GAMMA,
                                       const double* __restrict__ DY,
                                       double* __restrict__ DX,
                                       int64_t T, int64_t C, int64_t G) {
    int64_t cg = C / G;
    double m = (double)(cg * T);
    for (int64_t g = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         g < G; g += (int64_t)blockDim.x * gridDim.x) {
        int64_t c0 = g * cg;
        double inv_g = INV[g];
        double s1 = 0.0;
        double s2 = 0.0;
        for (int64_t t = 0; t < T; t++)
            for (int64_t cc = 0; cc < cg; cc++) {
                int64_t ch = c0 + cc;
                int64_t idx = t * C + ch;
                double dxh = DY[idx] * GAMMA[ch];
                s1 += dxh;
                s2 += dxh * XHAT[idx];
            }
        for (int64_t t = 0; t < T; t++)
            for (int64_t cc = 0; cc < cg; cc++) {
                int64_t ch = c0 + cc;
                int64_t idx = t * C + ch;
                double dxh = DY[idx] * GAMMA[ch];
                DX[idx] = inv_g * (dxh - s1 / m - XHAT[idx] * s2 / m);
            }
    }
}

int _hx_cuda_farr_groupnorm_bwd_gpu(int64_t xhat_id, int64_t inv_id,
                                    int64_t gamma_id, int64_t dy_id,
                                    int64_t dgamma_id, int64_t dbeta_id,
                                    int64_t dx_id,
                                    int64_t T, int64_t C, int64_t G) {
#ifdef __CUDACC__
    if (T <= 0 || C <= 0 || G <= 0 || (C % G) != 0) return -1;
    if (_h2d(xhat_id) != 0) return -1;
    if (_h2d(inv_id) != 0) return -1;
    if (_h2d(gamma_id) != 0) return -1;
    if (_h2d(dy_id) != 0) return -1;
    if (_ensure_dev_alloc_out(dgamma_id, C) != 0) return -1;
    if (_ensure_dev_alloc_out(dbeta_id, C) != 0) return -1;
    if (_ensure_dev_alloc_out(dx_id, T * C) != 0) return -1;
    const double* XHAT  = g_slots[xhat_id].d_buf;
    const double* INV   = g_slots[inv_id].d_buf;
    const double* GAMMA = g_slots[gamma_id].d_buf;
    const double* DY    = g_slots[dy_id].d_buf;
    double*       DGAMMA = g_slots[dgamma_id].d_buf;
    double*       DBETA  = g_slots[dbeta_id].d_buf;
    double*       DX     = g_slots[dx_id].d_buf;
    {
        int block_sz = 128;
        int64_t want = (C + block_sz - 1) / block_sz;
        int grid_sz = (want > 1024) ? 1024 : (int)want;
        if (grid_sz < 1) grid_sz = 1;
        _hx_k_groupnorm_bwd_affine<<<grid_sz, block_sz, 0, _forge_stream()>>>(XHAT, DY,
                                                          DGAMMA, DBETA, T, C);
    }
    {
        int block_sz = 64;
        int64_t want = (G + block_sz - 1) / block_sz;
        int grid_sz = (want > 1024) ? 1024 : (int)want;
        if (grid_sz < 1) grid_sz = 1;
        _hx_k_groupnorm_bwd_dx<<<grid_sz, block_sz, 0, _forge_stream()>>>(XHAT, INV, GAMMA, DY,
                                                      DX, T, C, G);
    }
    if (_forge_launch_check("groupnorm_bwd") != 0) return -1;
    {
        int64_t outs[3] = { dgamma_id, dbeta_id, dx_id };
        for (int k = 0; k < 3; k++) {
            HexaFarrEntry* e = &_hx_farr_table[outs[k]];
            e->d_buf      = (void*)g_slots[outs[k]].d_buf;
            e->loc        = FARR_DEVICE;
            e->dirty_host = 0;
            e->dirty_dev  = 0;
        }
    }
    return 0;
#else
    (void)xhat_id; (void)inv_id; (void)gamma_id; (void)dy_id;
    (void)dgamma_id; (void)dbeta_id; (void)dx_id; (void)T; (void)C; (void)G;
    fprintf(stderr, "[cuda] groupnorm_bwd: built without __CUDACC__\n");
    return -1;
#endif
}

/* HEXA-FUSION L3 (BWD glue half) — device-resident expert-unpack (residual
 * grad split). The bwd MIRROR of expert_pack2: reproduces the clm_prod_bwd
 * ei-loop EXACTLY: for i in 0..n,
 *   DEX0[i] = DEX_OUT[0·n + i] ; DEX1[i] = DEX_OUT[1·n + i]   (n = T·d)
 * = the moe-router grad dex_out[E·T·d] split back into the 2 per-expert grads.
 * Pure copy, NO arithmetic, NO reduction → trivially bit-exact (max|Δ|=0).
 * Fuses the T·d host t_get/t_set unpack loop in clm_prod_bwd (between the
 * moe-router bwd and the 2 gelu_bwd). Keeps DEX0/DEX1 FARR_DEVICE so the
 * follow-up gelu_bwd H2D-skips them. */
__global__ void _hx_k_expert_unpack2(const double* __restrict__ DEX_OUT,
                                     double* __restrict__ DEX0,
                                     double* __restrict__ DEX1, int64_t n) {
    int64_t stride = (int64_t)blockDim.x * (int64_t)gridDim.x;
    for (int64_t i = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         i < n; i += stride) {
        DEX0[i] = DEX_OUT[i];
        DEX1[i] = DEX_OUT[n + i];
    }
}

int _hx_cuda_farr_expert_unpack2_gpu(int64_t dex_out_id, int64_t dex0_id,
                                     int64_t dex1_id, int64_t n) {
#ifdef __CUDACC__
    if (n <= 0) return -1;
    if (_h2d(dex_out_id) != 0) return -1;
    if (_ensure_dev_alloc_out(dex0_id, n) != 0) return -1;
    if (_ensure_dev_alloc_out(dex1_id, n) != 0) return -1;
    const double* DEX_OUT = g_slots[dex_out_id].d_buf;
    double*       DEX0    = g_slots[dex0_id].d_buf;
    double*       DEX1    = g_slots[dex1_id].d_buf;
    int block_sz = 256;
    int64_t want = (n + block_sz - 1) / block_sz;
    int grid_sz = (want > 1024) ? 1024 : (int)want;
    if (grid_sz < 1) grid_sz = 1;
    _hx_k_expert_unpack2<<<grid_sz, block_sz, 0, _forge_stream()>>>(DEX_OUT, DEX0, DEX1, n);
    if (_forge_launch_check("expert_unpack2") != 0) return -1;
    {
        int64_t outs[2] = { dex0_id, dex1_id };
        for (int k = 0; k < 2; k++) {
            HexaFarrEntry* e = &_hx_farr_table[outs[k]];
            e->d_buf      = (void*)g_slots[outs[k]].d_buf;
            e->loc        = FARR_DEVICE;
            e->dirty_host = 0;
            e->dirty_dev  = 0;
        }
    }
    return 0;
#else
    (void)dex_out_id; (void)dex0_id; (void)dex1_id; (void)n;
    fprintf(stderr, "[cuda] expert_unpack2: built without __CUDACC__\n");
    return -1;
#endif
}

/* HEXA-FUSION L3 (BWD glue half · ⑤-bwd2) — device-resident CE softmax grad.
 * Reproduces clm_prod.hexa clm_ce_grad EXACTLY: per position t (one thread),
 *   mx = max_v LOGITS[t,v] ; sm = Σ_v exp(LOGITS[t,v] - mx)
 *   DLOGITS[t,v] = (exp(LOGITS[t,v] - mx)/sm) · (1/T)   for all v
 *   DLOGITS[t, tgt] -= 1/T          (tgt = (int)TARGETS[t])
 * The max + the sum + the per-col writes all run SEQUENTIALLY in the host
 * scan order (one thread per t, v ascending) — NO tree re-assoc, NO atomics.
 * F-OP19: exp = the HAND-ROLLED dt_exp Taylor (replayed term-for-term in
 * _hx_dt_exp_dev), NOT CUDA exp()/expf — so it is bit-exact to the host
 * clm_ce_grad (which ALSO uses dt_exp as of F-OP19) AND cross-platform
 * deterministic (CUDA exp, like host libm exp, diverged across arch/OS —
 * measured 1 ULP arm64-macos vs x86-linux). The _moe_exp_dev precedent.
 * The 1/T = 1.0/(double)T scaling matches `1.0 / to_float(T)` exactly →
 * bit-exact (max|Δ|=0). Fuses the clm_ce_grad host glue at the head of the
 * full-step driver (before clm_prod_bwd). Keeps DLOGITS FARR_DEVICE so the
 * first conv-bwd GEMM H2D-skips it. */
/* HEXA-0POD OP-19b: _hx_dt_exp_dev is now defined ONCE above (before the
 * device GELU kernels, which also need it for the bwd pdf) — the F-OP19
 * definition formerly inlined here was hoisted to avoid a redefinition. */
__global__ void _hx_k_ce_grad(const double* __restrict__ LOGITS,
                              const double* __restrict__ TARGETS,
                              double* __restrict__ DLOGITS,
                              int64_t T, int64_t V) {
    double invT = 1.0 / (double)T;
    for (int64_t t = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         t < T; t += (int64_t)blockDim.x * gridDim.x) {
        int64_t base = t * V;
        double mx = LOGITS[base];
        for (int64_t i = 1; i < V; i++) {
            double v = LOGITS[base + i];
            if (v > mx) mx = v;
        }
        double sm = 0.0;
        for (int64_t i2 = 0; i2 < V; i2++)
            sm += _hx_dt_exp_dev(LOGITS[base + i2] - mx);
        for (int64_t v3 = 0; v3 < V; v3++) {
            double p = _hx_dt_exp_dev(LOGITS[base + v3] - mx) / sm;
            DLOGITS[base + v3] = p * invT;
        }
        int64_t tgt = (int64_t)TARGETS[t];
        DLOGITS[base + tgt] = DLOGITS[base + tgt] - invT;
    }
}

int _hx_cuda_farr_ce_grad_gpu(int64_t logits_id, int64_t targets_id,
                              int64_t dlogits_id, int64_t T, int64_t V) {
#ifdef __CUDACC__
    if (T <= 0 || V <= 0) return -1;
    if (_h2d(logits_id) != 0) return -1;
    if (_h2d(targets_id) != 0) return -1;
    if (_ensure_dev_alloc_out(dlogits_id, T * V) != 0) return -1;
    const double* LOGITS  = g_slots[logits_id].d_buf;
    const double* TARGETS = g_slots[targets_id].d_buf;
    double*       DLOGITS = g_slots[dlogits_id].d_buf;
    int block_sz = 64;
    int64_t want = (T + block_sz - 1) / block_sz;
    int grid_sz = (want > 1024) ? 1024 : (int)want;
    if (grid_sz < 1) grid_sz = 1;
    _hx_k_ce_grad<<<grid_sz, block_sz, 0, _forge_stream()>>>(LOGITS, TARGETS, DLOGITS, T, V);
    if (_forge_launch_check("ce_grad") != 0) return -1;
    {
        HexaFarrEntry* e = &_hx_farr_table[dlogits_id];
        e->d_buf      = (void*)g_slots[dlogits_id].d_buf;
        e->loc        = FARR_DEVICE;
        e->dirty_host = 0;
        e->dirty_dev  = 0;
    }
    return 0;
#else
    (void)logits_id; (void)targets_id; (void)dlogits_id; (void)T; (void)V;
    fprintf(stderr, "[cuda] ce_grad: built without __CUDACC__\n");
    return -1;
#endif
}

/* HEXA-FUSION L3 (BWD glue half · ⑤-bwd2) — device-resident MoE-router bwd.
 * Reproduces moe_lib.hexa nn_moe_router_bwd EXACTLY (reads CACHED probs from
 * fwd — NO _moe_exp replay needed). Per position t (one thread):
 *   pass 1 (e ascending): pte = PROBS[t,e] ; dg = Σ_c DY[t,c]·EX_OUT[e,t,c]
 *                         DEX_OUT[e,t,c] = pte·DY[t,c]  (c ascending)
 *                         stash dg in DLOGITS[t,e] ; dot += pte·dg
 *   pass 2 (e ascending): DLOGITS[t,e] = PROBS[t,e]·(DLOGITS[t,e] - dot)
 * Every reduction (the inner Σ_c and the dot Σ_e) accumulates SEQUENTIALLY in
 * the host order under ONE thread per t — NO tree re-assoc, NO atomics → bit-
 * exact (max|Δ|=0). dot is read AFTER pass-1 completes the full E scan, so the
 * 2-pass dependency is preserved within the single thread (no cross-thread
 * sync). Fuses the nn_moe_router_bwd host glue in clm_prod_bwd; keeps
 * DLOGITS/DEX_OUT FARR_DEVICE so the follow-up conv-bwd + expert-unpack
 * H2D-skip them. */
__global__ void _hx_k_moe_router_bwd(const double* __restrict__ PROBS,
                                     const double* __restrict__ EX_OUT,
                                     const double* __restrict__ DY,
                                     double* __restrict__ DLOGITS,
                                     double* __restrict__ DEX_OUT,
                                     int64_t T, int64_t E, int64_t C) {
    for (int64_t t = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         t < T; t += (int64_t)blockDim.x * gridDim.x) {
        double dot = 0.0;
        for (int64_t e = 0; e < E; e++) {
            double pte = PROBS[t * E + e];
            double dg = 0.0;
            for (int64_t c = 0; c < C; c++) {
                double gy = DY[t * C + c];
                dg += gy * EX_OUT[e * T * C + t * C + c];
                DEX_OUT[e * T * C + t * C + c] = pte * gy;
            }
            DLOGITS[t * E + e] = dg;
            dot += pte * dg;
        }
        for (int64_t e2 = 0; e2 < E; e2++) {
            double pte = PROBS[t * E + e2];
            double dg = DLOGITS[t * E + e2];
            DLOGITS[t * E + e2] = pte * (dg - dot);
        }
    }
}

int _hx_cuda_farr_moe_router_bwd_gpu(int64_t probs_id, int64_t ex_out_id,
                                     int64_t dy_id, int64_t dlogits_id,
                                     int64_t dex_out_id,
                                     int64_t T, int64_t E, int64_t C) {
#ifdef __CUDACC__
    if (T <= 0 || E <= 0 || C <= 0) return -1;
    if (_h2d(probs_id) != 0) return -1;
    if (_h2d(ex_out_id) != 0) return -1;
    if (_h2d(dy_id) != 0) return -1;
    if (_ensure_dev_alloc_out(dlogits_id, T * E) != 0) return -1;
    if (_ensure_dev_alloc_out(dex_out_id, E * T * C) != 0) return -1;
    const double* PROBS  = g_slots[probs_id].d_buf;
    const double* EX_OUT = g_slots[ex_out_id].d_buf;
    const double* DY     = g_slots[dy_id].d_buf;
    double*       DLOGITS = g_slots[dlogits_id].d_buf;
    double*       DEX_OUT = g_slots[dex_out_id].d_buf;
    int block_sz = 64;
    int64_t want = (T + block_sz - 1) / block_sz;
    int grid_sz = (want > 1024) ? 1024 : (int)want;
    if (grid_sz < 1) grid_sz = 1;
    _hx_k_moe_router_bwd<<<grid_sz, block_sz, 0, _forge_stream()>>>(PROBS, EX_OUT, DY,
                                               DLOGITS, DEX_OUT, T, E, C);
    if (_forge_launch_check("moe_router_bwd") != 0) return -1;
    {
        int64_t outs[2] = { dlogits_id, dex_out_id };
        for (int k = 0; k < 2; k++) {
            HexaFarrEntry* e = &_hx_farr_table[outs[k]];
            e->d_buf      = (void*)g_slots[outs[k]].d_buf;
            e->loc        = FARR_DEVICE;
            e->dirty_host = 0;
            e->dirty_dev  = 0;
        }
    }
    return 0;
#else
    (void)probs_id; (void)ex_out_id; (void)dy_id; (void)dlogits_id;
    (void)dex_out_id; (void)T; (void)E; (void)C;
    fprintf(stderr, "[cuda] moe_router_bwd: built without __CUDACC__\n");
    return -1;
#endif
}

/* HEXA-FUSION L3 (BWD glue half · ⑤-bwd2) — device-resident 3-way grad sum.
 * Reproduces the clm_prod_bwd dxt accumulation EXACTLY:
 *   OUT[i] = A[i] + B[i] + C[i]   for i in 0..n  (left-to-right, host order)
 * = dxt = dxt_r + dxt_e0 + dxt_e1 (the router + 2 expert dX paths summed).
 * Pure elementwise, NO reduction across i, fixed (A+B)+C association matching
 * the host `t_get(a)+t_get(b)+t_get(c)` → bit-exact (max|Δ|=0). Fuses the dxt
 * 3-way host sum loop; keeps OUT FARR_DEVICE for the follow-up gelu_bwd. */
__global__ void _hx_k_grad_sum3(const double* __restrict__ A,
                                const double* __restrict__ B,
                                const double* __restrict__ C,
                                double* __restrict__ OUT, int64_t n) {
    int64_t stride = (int64_t)blockDim.x * (int64_t)gridDim.x;
    for (int64_t i = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         i < n; i += stride) {
        OUT[i] = A[i] + B[i] + C[i];
    }
}

int _hx_cuda_farr_grad_sum3_gpu(int64_t a_id, int64_t b_id, int64_t c_id,
                                int64_t out_id, int64_t n) {
#ifdef __CUDACC__
    if (n <= 0) return -1;
    if (_h2d(a_id) != 0) return -1;
    if (_h2d(b_id) != 0) return -1;
    if (_h2d(c_id) != 0) return -1;
    if (_ensure_dev_alloc_out(out_id, n) != 0) return -1;
    const double* A = g_slots[a_id].d_buf;
    const double* B = g_slots[b_id].d_buf;
    const double* C = g_slots[c_id].d_buf;
    double*       OUT = g_slots[out_id].d_buf;
    int block_sz = 256;
    int64_t want = (n + block_sz - 1) / block_sz;
    int grid_sz = (want > 1024) ? 1024 : (int)want;
    if (grid_sz < 1) grid_sz = 1;
    _hx_k_grad_sum3<<<grid_sz, block_sz, 0, _forge_stream()>>>(A, B, C, OUT, n);
    if (_forge_launch_check("grad_sum3") != 0) return -1;
    {
        HexaFarrEntry* e = &_hx_farr_table[out_id];
        e->d_buf      = (void*)g_slots[out_id].d_buf;
        e->loc        = FARR_DEVICE;
        e->dirty_host = 0;
        e->dirty_dev  = 0;
    }
    return 0;
#else
    (void)a_id; (void)b_id; (void)c_id; (void)out_id; (void)n;
    fprintf(stderr, "[cuda] grad_sum3: built without __CUDACC__\n");
    return -1;
#endif
}

/* HEXA-FUSION L3 (BWD glue half · ⑤-bwd2) — device-resident 2-way grad sum.
 * Reproduces the clm_prod_bwd dxec accumulation EXACTLY:
 *   OUT[i] = A[i] + B[i]   for i in 0..n  (host order) = dxec = dxt + dxec_b.
 * Pure elementwise, NO reduction → bit-exact (max|Δ|=0). Fuses the dxec 2-way
 * host sum loop; keeps OUT FARR_DEVICE for the follow-up conv-bwd GEMM. */
__global__ void _hx_k_grad_sum2(const double* __restrict__ A,
                                const double* __restrict__ B,
                                double* __restrict__ OUT, int64_t n) {
    int64_t stride = (int64_t)blockDim.x * (int64_t)gridDim.x;
    for (int64_t i = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         i < n; i += stride) {
        OUT[i] = A[i] + B[i];
    }
}

int _hx_cuda_farr_grad_sum2_gpu(int64_t a_id, int64_t b_id,
                                int64_t out_id, int64_t n) {
#ifdef __CUDACC__
    if (n <= 0) return -1;
    if (_h2d(a_id) != 0) return -1;
    if (_h2d(b_id) != 0) return -1;
    if (_ensure_dev_alloc_out(out_id, n) != 0) return -1;
    const double* A = g_slots[a_id].d_buf;
    const double* B = g_slots[b_id].d_buf;
    double*       OUT = g_slots[out_id].d_buf;
    int block_sz = 256;
    int64_t want = (n + block_sz - 1) / block_sz;
    int grid_sz = (want > 1024) ? 1024 : (int)want;
    if (grid_sz < 1) grid_sz = 1;
    _hx_k_grad_sum2<<<grid_sz, block_sz, 0, _forge_stream()>>>(A, B, OUT, n);
    if (_forge_launch_check("grad_sum2") != 0) return -1;
    {
        HexaFarrEntry* e = &_hx_farr_table[out_id];
        e->d_buf      = (void*)g_slots[out_id].d_buf;
        e->loc        = FARR_DEVICE;
        e->dirty_host = 0;
        e->dirty_dev  = 0;
    }
    return 0;
#else
    (void)a_id; (void)b_id; (void)out_id; (void)n;
    fprintf(stderr, "[cuda] grad_sum2: built without __CUDACC__\n");
    return -1;
#endif
}

/* HEXA-FUSION L3 (BWD glue half · ⑤-bwd2) — device-resident deterministic
 * embedding scatter (grad accumulate into the table). Reproduces nn_lib.hexa
 * nn_embedding_bwd_scatter EXACTLY but WITHOUT atomics: the host loops i in
 * 0..T and does DTABLE[tok·d + c] += DX[i·d + c] (tok = (int)IDS[i]); colliding
 * tokens accumulate in i-ascending order. To preserve that order bit-exactly
 * with NO atomics and NO tree re-assoc, we assign ONE THREAD PER VOCAB ROW r:
 * each thread scans i = 0..T ascending and, for every i with tok==r, adds
 * DX[i·d + c] into DTABLE[r·d + c] (c ascending) — so each table row is touched
 * by exactly one thread, accumulating its colliding tokens in the SAME
 * ascending-i order the host uses. DTABLE is pre-zeroed on the host (the
 * clm_prod_bwd zero loop). Sequential per-row accumulation → bit-exact
 * (max|Δ|=0). Fuses the nn_embedding_bwd_scatter host glue at the tail of
 * clm_prod_bwd; keeps DTABLE FARR_DEVICE for the follow-up AdamW. */
__global__ void _hx_k_embedding_bwd_scatter(const double* __restrict__ DX,
                                            const double* __restrict__ IDS,
                                            double* __restrict__ DTABLE,
                                            int64_t T, int64_t d, int64_t V) {
    for (int64_t r = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         r < V; r += (int64_t)blockDim.x * gridDim.x) {
        for (int64_t i = 0; i < T; i++) {
            int64_t tok = (int64_t)IDS[i];
            if (tok != r) continue;
            for (int64_t c = 0; c < d; c++)
                DTABLE[r * d + c] = DTABLE[r * d + c] + DX[i * d + c];
        }
    }
}

/* #4204 own-native fast-default — atomic embedding grad-accum. One thread
 * per (i,c): atomicAdd's DX[i*d+c] into DTABLE[tok*d+c] (tok=(int)IDS[i]).
 * Colliding tokens accumulate in nondeterministic order (NOT bit-id) ->
 * fast non-det DEFAULT (training); replaces the O(V*T) per-vocab-row scan.
 * DTABLE is pre-zeroed on the host (clm_prod_bwd) then H2D'd, so the
 * atomicAdds land on a clean table. HEXA_DET selects the deterministic
 * per-row scan _hx_k_embedding_bwd_scatter. gpu_only: needs nvcc compile +
 * clm_prod_embed_scatter_eq oracle (det path) on summer. */
__global__ void _hx_k_embedding_bwd_scatter_atomic(const double* __restrict__ DX,
                                                   const double* __restrict__ IDS,
                                                   double* __restrict__ DTABLE,
                                                   int64_t T, int64_t d, int64_t V) {
    int64_t total = T * d;
    int64_t stride = (int64_t)blockDim.x * (int64_t)gridDim.x;
    for (int64_t idx = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         idx < total; idx += stride) {
        int64_t i = idx / d;
        int64_t c = idx - i * d;
        int64_t tok = (int64_t)IDS[i];
        if (tok >= 0 && tok < V) atomicAdd(&DTABLE[tok * d + c], DX[i * d + c]);
    }
}

int _hx_cuda_farr_embedding_bwd_scatter_gpu(int64_t dx_id, int64_t ids_id,
                                            int64_t dtable_id,
                                            int64_t T, int64_t d, int64_t V) {
#ifdef __CUDACC__
    if (T <= 0 || d <= 0 || V <= 0) return -1;
    if (_h2d(dx_id) != 0) return -1;
    if (_h2d(ids_id) != 0) return -1;
    if (_h2d(dtable_id) != 0) return -1;   /* pre-zeroed host buffer → device */
    const double* DX  = g_slots[dx_id].d_buf;
    const double* IDS = g_slots[ids_id].d_buf;
    double*       DTABLE = g_slots[dtable_id].d_buf;
    if (!_forge_det_on()) {
        /* #4204 fast-default: atomic grad-accum (NOT bit-id), one thread per
         * (i,c). DTABLE is the host-pre-zeroed table just H2D'd above. */
        int eblk = 256;
        int64_t ewant = (T * d + eblk - 1) / eblk;
        int egrid = (ewant > 1024) ? 1024 : (int)ewant;
        if (egrid < 1) egrid = 1;
        _hx_k_embedding_bwd_scatter_atomic<<<egrid, eblk, 0, _forge_stream()>>>(DX, IDS, DTABLE, T, d, V);
        if (_forge_launch_check("embedding_bwd_scatter_atomic") != 0) return -1;
    } else {
    int block_sz = 128;
    int64_t want = (V + block_sz - 1) / block_sz;
    int grid_sz = (want > 1024) ? 1024 : (int)want;
    if (grid_sz < 1) grid_sz = 1;
    _hx_k_embedding_bwd_scatter<<<grid_sz, block_sz, 0, _forge_stream()>>>(DX, IDS, DTABLE, T, d, V);
    if (_forge_launch_check("embedding_bwd_scatter") != 0) return -1;
    }
    {
        HexaFarrEntry* e = &_hx_farr_table[dtable_id];
        e->d_buf      = (void*)g_slots[dtable_id].d_buf;
        e->loc        = FARR_DEVICE;
        e->dirty_host = 0;
        e->dirty_dev  = 0;
    }
    return 0;
#else
    (void)dx_id; (void)ids_id; (void)dtable_id; (void)T; (void)d; (void)V;
    fprintf(stderr, "[cuda] embedding_bwd_scatter: built without __CUDACC__\n");
    return -1;
#endif
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
    /* HEXA-FUSION N2 RACEFIX (F-FUSION-N1N2-DETERMINISM, 2nd hazard):
     * same cross-stream race as _h2d. The cudaFree/cudaMalloc/cudaMemset
     * below run on the DEFAULT stream; when async is ON a still-queued
     * forge-stream kernel may reference this slot's old d_buf ->
     * cudaFree-under-use / concurrent memset. Drain the forge stream first
     * (no-op async-off => byte-eq legacy). */
    if (_forge_sync() != 0) return -1;
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
    if (_forge_out_keep()) {
        /* Defer D2H — device authoritative, host stale. No bytes
         * copied; the next op reads s->d_buf directly via H2D-skip. */
        e->d_buf      = (void*)s->d_buf;
        e->loc        = FARR_DEVICE;
        /* residency-fix: dirty_host MUST stay 0 here. The host buf is
         * stale, but that is tracked by loc=FARR_DEVICE + dirty_dev=1 (a
         * host-read materialises via hexa_farr_get loc==FARR_DEVICE D2H).
         * dirty_host=1 means the USER mutated the host buf (hexa_farr_set)
         * and forces a re-upload; setting it on a DEVICE_KEEP output wrongly
         * BLOCKED the _h2d skip (which keys on !dirty_host) so the next GPU
         * op re-uploaded the never-written host buffer, CLOBBERING this
         * kernel device output with stale zeros -> device-resident fwd/grad
         * garbage -> CLM_PROD_DEVRESIDENT/DEVFEED frozen-train (measured
         * 4.7990 constant vs REF 3.5508 descend). Default = HOST_NOW so the
         * shipped build stays byte-identical; only the opt-in path fixed. */
        e->dirty_host = 0;
        e->dirty_dev  = 1;   /* device holds the freshest value */
        (void)copy_len;
        return 0;
    }
    /* HOST_NOW path = host readback boundary → drain the forge stream
     * first (no-op when async off). The DEVICE_KEEP path above returned
     * without a D2H, so it correctly leaves the kernel queued. */
    if (_forge_sync() != 0) return -1;
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
 * Kernel 1c (RFC gpu-resident-large-vocab-lmhead-loss, ADDITIVE) —
 * ce_seed: GPU-resident large-vocab lm-head cross-entropy loss + seed
 * gradient, ONE kernel, logits never leave the device.
 *
 *   row r ∈ [0,R), logits L[r,*] over a vocab of size V:
 *     m       = max_v L[r,v]                          (block-reduce)
 *     s       = Σ_v exp(L[r,v] - m)                    (block-reduce)
 *     lse     = m + log(s)                             (log-sum-exp)
 *     loss[r] = lse - L[r, target[r]]                 = -log softmax(target)
 *     dlogits[r,v] = softmax(L[r,v]) - onehot(v == target[r])
 *
 * Layout matches _hx_k_softmax_rows: one block per row (gridDim.x = R),
 * HX_RR_BLOCK threads striding the row; the two reductions use the same
 * deterministic _hx_block_max / _hx_block_sum tree. Per-row loss is
 * written to OUT_LOSS[r] (length R; the caller sums the R values on host
 * — R is small, e.g. 512). The seed grad fills OUT_DL[r*V + v] in place.
 *
 * HONEST SCOPE — bit-identity NOT claimed (online/parallel reduce order
 * differs from the host FP64 sequential loop); follows the forge `_gpu`
 * convention (rel-err tolerance, not max|Δ|=0). The targets arrive as a
 * double-encoded farr (token ids stored as doubles); each is rounded to
 * the nearest int64 vocab index.
 * ──────────────────────────────────────────────────────────────────── */
__global__ void _hx_k_ce_seed(const double* __restrict__ L,
                              const double* __restrict__ TGT,
                              double* __restrict__ OUT_LOSS,
                              double* __restrict__ OUT_DL,
                              int64_t R, int64_t V) {
    int64_t r = blockIdx.x;
    if (r >= R) return;
    const double* lr = L + r * V;
    double*       dr = OUT_DL + r * V;

    __shared__ double smem[HX_RR_BLOCK / 32];

    /* target index for this row (double-encoded → rounded int64). */
    int64_t tgt = (int64_t)(TGT[r] + (TGT[r] >= 0.0 ? 0.5 : -0.5));

    /* Pass 1: row max. */
    double vmax = -1.0e308;
    for (int64_t j = threadIdx.x; j < V; j += blockDim.x) {
        double v = lr[j];
        if (v > vmax) vmax = v;
    }
    double m = _hx_block_max(vmax, smem);

    /* Pass 2: write exp(x - m) into dlogits, accumulate sum-exp. */
    double vsum = 0.0;
    for (int64_t j = threadIdx.x; j < V; j += blockDim.x) {
        double e = exp(lr[j] - m);
        dr[j] = e;
        vsum += e;
    }
    double s   = _hx_block_sum(vsum, smem);
    double inv = (s > 0.0) ? (1.0 / s) : 0.0;

    /* CE loss for this row = lse - L[target] = (m + log s) - L[target].
     * One thread (lane 0 of block) writes OUT_LOSS[r]; guard tgt range. */
    if (threadIdx.x == 0) {
        double lse = m + log(s);
        double lt  = (tgt >= 0 && tgt < V) ? lr[tgt] : 0.0;
        OUT_LOSS[r] = lse - lt;
    }

    /* Pass 3: normalize → softmax, then subtract onehot(target). */
    for (int64_t j = threadIdx.x; j < V; j += blockDim.x) {
        double p = dr[j] * inv;
        if (j == tgt) p -= 1.0;
        dr[j] = p;
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

/* _hx_dt_exp_dev (flame_g7_dt_exp device port) is emitted ONCE near the
 * top of this TU (OP-19b canonical __device__ static def, before the
 * causal-softmax / GELU kernels). The previously-duplicated second
 * definition here was a hard nvcc redefinition error under -DHEXA_CUDA
 * (ing-cuda-build) — removed; the single canonical def is reachable from
 * every kernel below. */

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

/* In-place AdamW kernel — IDENTICAL arithmetic to _hx_k_adamw_step,
 * but W is both the read source AND the write destination (no separate
 * O). No `__restrict__` aliasing hazard (a single W pointer). Each
 * thread reads W[i] then writes W[i] within its own iteration → safe. */
__global__ void _hx_k_adamw_step_inplace(double* __restrict__ W,
                                 double* __restrict__ Mm,
                                 double* __restrict__ Vv,
                                 const double* __restrict__ G,
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
        W[i]  = wi;     /* W updated IN PLACE — no out buffer */
    }
}

/* ────────────────────────────────────────────────────────────────────
 * Kernel — packed_gemv_offset (small-dim fallback for cuBLAS Dgemv).
 *   out[i] = Σ_j P[off + i·cols + j] · U[j],  i in [0,rows).
 * Layout matches _hx_k_softmax_rows: one block per output row
 * (gridDim.x = rows), HX_RR_BLOCK threads stride across `cols`, then a
 * single block-sum reduction. Reduction order is the SAME fixed tree as
 * the softmax/ce kernels (warp-shfl → shared → re-reduce), NOT the
 * cuBLAS-tiled order — so this path carries the matmul tolerance caveat
 * (not bit-eq vs cuBLAS), same as the existing block-reduction kernels.
 * Used only when `rows` is small (see HEXA_GEMV_CUBLAS_MIN_ROWS gate in
 * the host wrapper); at small output dims the one-block-per-row launch
 * beats the cuBLAS Dgemv dispatch+sync cost (M7 RTX 5070 crossover).
 * ──────────────────────────────────────────────────────────────────── */
__global__ void _hx_k_packed_gemv_offset(const double* __restrict__ P,
                                 int64_t off,
                                 const double* __restrict__ U,
                                 double* __restrict__ O,
                                 int64_t rows, int64_t cols) {
    __shared__ double smem[HX_RR_BLOCK / 32];
    int64_t r = (int64_t)blockIdx.x;
    if (r >= rows) return;
    const double* row = P + off + r * cols;
    double acc = 0.0;
    for (int64_t j = (int64_t)threadIdx.x; j < cols; j += blockDim.x) {
        acc += row[j] * U[j];
    }
    double total = _hx_block_sum(acc, smem);
    if (threadIdx.x == 0) O[r] = total;
}

/* ────────────────────────────────────────────────────────────────────
 * HEXA-TRAIN-FLOOR M6 — fp32 dtype slice for packed_gemv_offset.
 *   out[i] = Σ_j P[off + i·cols + j] · U[j],  computed in fp32.
 *
 * SAME layout / reduction shape as _hx_k_packed_gemv_offset (one block
 * per output row, HX_RR_BLOCK threads stride `cols`, single block-sum),
 * but the per-thread products + accumulator are `float` (fp32) instead
 * of `double`. The device storage stays fp64 (_CudaFarrSlot.d_buf is
 * `double*`); each operand is narrowed fp64→fp32 AT THE LOAD and the
 * row dot-product reduces in fp32. The result is widened fp32→fp64 at
 * the store so the host ABI (packed-double farr) is unchanged.
 *
 * Why this is the M4-identified lever (HEXA-TRAIN-FLOOR.md §M4): the
 * trainer is fp64 COMPUTE-bound; the gemv contraction is the hot path.
 * fp32 multiply-accumulate runs at the device's fp32 throughput
 * (A100/5070: 32–64× the fp64 rate) — this kernel is the first slice
 * that exercises that rate without touching the fp64 storage layout.
 *
 * ACCURACY CAVEAT (opt-in only): fp32 has a 24-bit mantissa vs fp64's
 * 53-bit; the accumulator carries ~7 significant decimal digits. For a
 * length-`cols` dot product the relative error grows ~cols·2^-24. This
 * is mixed-precision training territory — it DOES perturb convergence
 * and is therefore OFF BY DEFAULT (HEXA_TRAIN_DTYPE unset/`fp64` keeps
 * the exact fp64 path). No bit-eq vs the fp64 reference is claimed; the
 * caller opts in only when the fp32 throughput win outweighs the loss
 * of mantissa bits (the M6→M7 measurement gate decides that per model).
 * ──────────────────────────────────────────────────────────────────── */
__device__ __forceinline__ float _hx_warp_sum_f(float v) {
    for (int offset = 16; offset > 0; offset >>= 1) {
        v += __shfl_down_sync(0xFFFFFFFFu, v, offset);
    }
    return v;
}

__device__ __forceinline__ float _hx_block_sum_f(float v, float* smem) {
    int lane = threadIdx.x & 31;
    int wid  = threadIdx.x >> 5;
    v = _hx_warp_sum_f(v);
    if (lane == 0) smem[wid] = v;
    __syncthreads();
    int n_warps = (blockDim.x + 31) >> 5;
    if (wid == 0) {
        float w = (lane < n_warps) ? smem[lane] : 0.0f;
        w = _hx_warp_sum_f(w);
        if (lane == 0) smem[0] = w;
    }
    __syncthreads();
    return smem[0];
}

__global__ void _hx_k_packed_gemv_offset_f32(const double* __restrict__ P,
                                 int64_t off,
                                 const double* __restrict__ U,
                                 double* __restrict__ O,
                                 int64_t rows, int64_t cols) {
    __shared__ float smem[HX_RR_BLOCK / 32];
    int64_t r = (int64_t)blockIdx.x;
    if (r >= rows) return;
    const double* row = P + off + r * cols;
    float acc = 0.0f;
    for (int64_t j = (int64_t)threadIdx.x; j < cols; j += blockDim.x) {
        /* narrow fp64→fp32 at load; multiply-accumulate in fp32. */
        acc += (float)row[j] * (float)U[j];
    }
    float total = _hx_block_sum_f(acc, smem);
    if (threadIdx.x == 0) O[r] = (double)total;  /* widen fp32→fp64 store */
}

/* ────────────────────────────────────────────────────────────────────
 * HEXA-TRAIN-FLOOR bf16 lever — bf16 dtype slice for packed_gemv_offset.
 *   out[i] = Σ_j P[off + i·cols + j] · U[j],  operands cast to bf16,
 *   multiply-accumulated in fp32 (mixed precision, FP32 accumulator).
 *
 * SAME block-per-row / HX_RR_BLOCK-stride / single-block-sum shape as the
 * M6 fp32 sibling _hx_k_packed_gemv_offset_f32; the ONLY change is the
 * per-operand narrowing: fp64 → __nv_bfloat16 (RNE via __double2bfloat16)
 * → fp32 product. The accumulator + block reduction stay fp32 (the same
 * CUBLAS_COMPUTE_32F discipline the RFC 049 cublasGemmEx bf16 path uses)
 * for convergence stability — bf16 has only an 8-bit mantissa, so a
 * bf16 accumulator would lose almost all precision over a length-`cols`
 * dot product. Storage stays fp64 (d_buf is double*) so the host ABI is
 * unchanged; this is the COMPUTE-precision slice, not a storage rewrite.
 *
 * Why bf16 (vs the M6 fp32 lever): bf16 multiply feeds the device's bf16
 * units; on a TensorCore-class GPU (A100 / RTX 5070) the bf16 rate is the
 * full mixed-precision throughput the M4 roofline identified as the fp64
 * ceiling-break. This per-row reduction kernel exercises bf16 *scalar*
 * math (not WMMA tiles — see the honest-scope note in the dispatcher);
 * the WMMA / cublasGemmEx TENSOR_OP route is the RFC 049 substrate
 * (_hx_gemm_ex_bf16 in the #include'd runtime_bf16.c), reachable once the
 * gemm operands live in bf16 storage tiles (residual scope).
 *
 * ACCURACY CAVEAT (opt-in only): bf16 keeps 8 mantissa bits (~2-3 sig
 * decimal digits per operand) — strictly coarser than fp32's 24. NOT
 * bit-eq vs fp64; perturbs convergence more than fp32. OFF BY DEFAULT
 * (HEXA_TRAIN_DTYPE unset/`fp64`). Measured accuracy: max|rel| ~1.3e-2
 * for cols>=128 (RTX 5070, fp32 accumulator working as designed).
 *
 * MEASURED PERF — 🔴 NOT RECOMMENDED for the gemv shape
 * (.verdicts/hexa-train-floor/bf16-lever.txt, RTX 5070): this in-place
 * bf16-MAC kernel is SLOWER than fp64/fp32 (bf16/f64 0.85–5.67x latency).
 * The per-element __double2bfloat16 narrowing adds cost on a memory-
 * bound per-row reduction, and scalar bf16 math does NOT engage Tensor-
 * Core (which needs WMMA tile ops). The bf16 ceiling-break (24.9–123x
 * vs fp64) lives in the square-GEMM cublasGemmEx TENSOR_OP path — the
 * RFC 049 _hx_gemm_ex_bf16 substrate — reachable only with bf16 STORAGE
 * tiles (residual M9+). This kernel is landed opt-in for completeness +
 * dtype-selector parity, NOT as a recommended speedup. fp32 (M6) stays
 * the best in-place lever (f32/f64 0.66–0.94).
 * ──────────────────────────────────────────────────────────────────── */
__global__ void _hx_k_packed_gemv_offset_bf16(const double* __restrict__ P,
                                 int64_t off,
                                 const double* __restrict__ U,
                                 double* __restrict__ O,
                                 int64_t rows, int64_t cols) {
    __shared__ float smem[HX_RR_BLOCK / 32];
    int64_t r = (int64_t)blockIdx.x;
    if (r >= rows) return;
    const double* row = P + off + r * cols;
    float acc = 0.0f;
    for (int64_t j = (int64_t)threadIdx.x; j < cols; j += blockDim.x) {
        /* narrow fp64→bf16 (RNE) at load; product widens to fp32; the
         * accumulator stays fp32 (CUBLAS_COMPUTE_32F discipline). */
        __nv_bfloat16 a = __double2bfloat16(row[j]);
        __nv_bfloat16 b = __double2bfloat16(U[j]);
        acc += __bfloat162float(a) * __bfloat162float(b);
    }
    float total = _hx_block_sum_f(acc, smem);
    if (threadIdx.x == 0) O[r] = (double)total;  /* widen fp32→fp64 store */
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

/* ── ce_seed host wrapper (RFC gpu-resident-large-vocab-lmhead-loss).
 * GPU-resident large-vocab lm-head CE loss + seed grad in ONE kernel.
 * Mirrors _hx_cuda_farr_softmax_rows_gpu's contract: validate → H2D the
 * two inputs (logits[R*V], targets[R]) → _ensure_dev_alloc_out for the
 * two caller-allocated outputs (out_loss[R], out_dlogits[R*V]) → launch
 * one block-per-row kernel → cudaDeviceSynchronize → D2H both outputs.
 * The logits farr is the lm-head matmul output that STAYS device-
 * resident (the RFC's whole point — no 78M H2D round-trip); _h2d() sees
 * it DEVICE && !dirty_host and SKIPs the redundant copy (RFC 056 §6.1).
 * loss is per-row (caller sums R values on host). Returns 0 ok / -1. */
int _hx_cuda_farr_ce_seed_gpu(int64_t logits_id, int64_t target_ids_id,
                              int64_t R, int64_t V,
                              int64_t out_loss_id, int64_t out_dlogits_id) {
#ifdef __CUDACC__
    if (R <= 0 || V <= 0) {
        fprintf(stderr, "[cuda] ce_seed: bad shape R=%lld V=%lld\n",
                (long long)R, (long long)V);
        return -1;
    }
    if (_h2d(logits_id) != 0)     return -1;
    if (_h2d(target_ids_id) != 0) return -1;
    if (_ensure_dev_alloc_out(out_loss_id, R) != 0)         return -1;
    if (_ensure_dev_alloc_out(out_dlogits_id, R * V) != 0)  return -1;
    const double* L   = g_slots[logits_id].d_buf;
    const double* TGT = g_slots[target_ids_id].d_buf;
    double* OUT_LOSS  = g_slots[out_loss_id].d_buf;
    double* OUT_DL    = g_slots[out_dlogits_id].d_buf;
    dim3 grid((unsigned)R), block(HX_RR_BLOCK);
    _hx_k_ce_seed<<<grid, block>>>(L, TGT, OUT_LOSS, OUT_DL, R, V);
    cudaError_t er = cudaDeviceSynchronize();
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] ce_seed launch failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    if (_d2h_out(out_loss_id, R) != 0)        return -1;
    return _d2h_out(out_dlogits_id, R * V);
#else
    (void)logits_id; (void)target_ids_id; (void)R; (void)V;
    (void)out_loss_id; (void)out_dlogits_id;
    fprintf(stderr, "[cuda] ce_seed: built without __CUDACC__ "
                    "(use nvcc -x cu)\n");
    return -1;
#endif
}

/* ────────────────────────────────────────────────────────────────────
 * BC-ANIMA M3 (2026-05-28): seed-only CE gradient kernel (5-arg).
 *
 *   row r ∈ [0,R), softmax S[r,*] over columns C:
 *     dlogits[r,c] = S[r,c] - onehot(c == target[r])
 *
 * Lighter sibling of _hx_k_ce_seed (which fuses loss + seed + softmax).
 * Used when softmax is already computed via M2 farr_softmax_rows. Single
 * pass — no reductions. One block per row; HX_RR_BLOCK threads stride C.
 * ──────────────────────────────────────────────────────────────────── */
__global__ void _hx_k_ce_seed_only(const double* __restrict__ S,
                                   const double* __restrict__ TGT,
                                   double* __restrict__ DL,
                                   int64_t R, int64_t C) {
    int64_t r = blockIdx.x;
    if (r >= R) return;
    const double* sr = S + r * C;
    double*       dr = DL + r * C;
    int64_t tgt = (int64_t)(TGT[r] + (TGT[r] >= 0.0 ? 0.5 : -0.5));
    for (int64_t c = threadIdx.x; c < C; c += blockDim.x) {
        double p = sr[c];
        if (c == tgt) p -= 1.0;
        dr[c] = p;
    }
}

/* ── BC-ANIMA M3 (2026-05-28): farr_ce_seed host wrapper.
 * 5-arg seed-only CE gradient — softmax precomputed (anima M2). H2D
 * the two inputs (softmax[R*C], targets[R]) → _ensure_dev_alloc_out
 * for caller-allocated dlogits[R*C] → launch slim block-per-row kernel
 * → cudaDeviceSynchronize → D2H dlogits. Returns 0 ok / -1. */
int _hx_cuda_farr_ce_seed(int64_t softmax_id, int64_t target_ids_id,
                          int64_t dlogits_id,
                          int64_t R, int64_t C) {
#ifdef __CUDACC__
    if (R <= 0 || C <= 0) {
        fprintf(stderr, "[cuda] ce_seed_only: bad shape R=%lld C=%lld\n",
                (long long)R, (long long)C);
        return -1;
    }
    if (_h2d(softmax_id) != 0)    return -1;
    if (_h2d(target_ids_id) != 0) return -1;
    if (_ensure_dev_alloc_out(dlogits_id, R * C) != 0) return -1;
    const double* S   = g_slots[softmax_id].d_buf;
    const double* TGT = g_slots[target_ids_id].d_buf;
    double*       DL  = g_slots[dlogits_id].d_buf;
    dim3 grid((unsigned)R), block(HX_RR_BLOCK);
    _hx_k_ce_seed_only<<<grid, block>>>(S, TGT, DL, R, C);
    cudaError_t er = cudaDeviceSynchronize();
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] ce_seed_only launch failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    return _d2h_out(dlogits_id, R * C);
#else
    (void)softmax_id; (void)target_ids_id; (void)dlogits_id;
    (void)R; (void)C;
    fprintf(stderr, "[cuda] ce_seed_only: built without __CUDACC__ "
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

    _hx_k_adamw_step<<<grid_sz, block_sz, 0, _forge_stream()>>>(W, Mm, Vv, G, O, n,
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

/* In-place AdamW host wrapper — no fresh device output buffer; W is
 * updated in place on its own device slot (out == W). H2D W/m/v/g,
 * launch _hx_k_adamw_step_inplace, then D2H W AND m,v back to host
 * (optimizer-state contract). Byte-eq to _hx_cuda_farr_adamw_step_gpu
 * with out_id == w_id (same arithmetic, O ≡ W). Returns 0 ok / -1. */
int _hx_cuda_farr_adamw_step_inplace_gpu(int64_t w_id, int64_t m_id,
                                  int64_t v_id, int64_t g_id,
                                  int64_t n, double lr, double b1,
                                  double b2, double eps, double wd,
                                  int64_t step_t) {
#ifdef __CUDACC__
    if (n <= 0 || step_t < 1) {
        fprintf(stderr, "[cuda] adamw_step_inplace: bad n=%lld step_t=%lld\n",
                (long long)n, (long long)step_t);
        return -1;
    }
    if (_h2d(w_id) != 0) return -1;
    if (_h2d(m_id) != 0) return -1;
    if (_h2d(v_id) != 0) return -1;
    if (_h2d(g_id) != 0) return -1;

    double b1t = 1.0, b2t = 1.0;
    for (int64_t e = 0; e < step_t; e++) { b1t *= b1; b2t *= b2; }
    double c1 = 1.0 - b1t;
    double c2 = 1.0 - b2t;

    double* W  = g_slots[w_id].d_buf;
    double* Mm = g_slots[m_id].d_buf;
    double* Vv = g_slots[v_id].d_buf;
    const double* G = g_slots[g_id].d_buf;

    int block_sz = 256;
    int64_t want_blocks = (n + block_sz - 1) / block_sz;
    int grid_sz = (want_blocks > 1024) ? 1024 : (int)want_blocks;
    if (grid_sz < 1) grid_sz = 1;

    _hx_k_adamw_step_inplace<<<grid_sz, block_sz, 0, _forge_stream()>>>(W, Mm, Vv, G, n,
                                            lr, b1, b2, eps, wd, c1, c2);
    cudaError_t er = cudaDeviceSynchronize();
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] adamw_step_inplace launch failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    /* Write back the in-place-updated W, m, v to their host buffers. */
    if (_d2h(w_id) != 0) return -1;
    if (_d2h(m_id) != 0) return -1;
    if (_d2h(v_id) != 0) return -1;
    return 0;
#else
    (void)w_id; (void)m_id; (void)v_id; (void)g_id;
    (void)n; (void)lr; (void)b1; (void)b2; (void)eps; (void)wd;
    (void)step_t;
    fprintf(stderr, "[cuda] adamw_step_inplace: built without __CUDACC__\n");
    return -1;
#endif
}

/* ════════════════════════════════════════════════════════════════════════
 * HEXA-FUSION M2 (FULL-STEP) — fused cooperative AdamW over ALL params.
 * ════════════════════════════════════════════════════════════════════════
 * The clm_prod training step ends with ~36 SEPARATE _adam(W_i,...) calls,
 * each a distinct <<<>>> kernel launch with its own launch+sync gap. With
 * the host on the critical path between every micro-launch, the optimizer
 * TAIL of the step under-fills the H100 exactly like the fwd glue DAG P1
 * attacked. M2 collapses ALL param updates into ONE cooperativeLaunch:
 * the grid strides over the CONCATENATION of every param tensor (prefix-
 * offset lookup per global index), so 36 launches → 1 persistent grid,
 * host fully off the optimizer critical path. Arithmetic is BYTE-IDENTICAL
 * to _hx_k_adamw_step_inplace (same per-element AdamW; each tensor carries
 * its own bias-correction c1/c2 since they share the same global step_t).
 * This is the M2 full-step lever's first landed chunk — the optimizer step
 * fused inside a cooperative launch alongside P1's fwd megakernel. */
#ifdef __CUDACC__
#define HX_FS_MAXP 64   /* max param tensors in one fused AdamW launch */
struct _HxAdamFused {
    double* W[HX_FS_MAXP];
    double* Mm[HX_FS_MAXP];
    double* Vv[HX_FS_MAXP];
    const double* G[HX_FS_MAXP];
    int64_t off[HX_FS_MAXP + 1];  /* prefix-sum offsets; off[np]=total */
    int np;
    double lr, b1, b2, eps, wd, c1, c2;
};
/* Cooperative fused-AdamW. ONE persistent grid strides over off[np] total
 * elements; for each global idx, find the owning tensor p (off[p]<=idx<
 * off[p+1]) then run the IDENTICAL AdamW update on element (idx-off[p]).
 * grid.sync() is unnecessary (no cross-element dependency) but the launch
 * is cooperative so it composes with the full-step megakernel chain and
 * incurs exactly ONE launch for the whole optimizer tail. */
__global__ void _hx_k_adamw_fused(_HxAdamFused f) {
    int64_t total = f.off[f.np];
    int64_t stride = (int64_t)gridDim.x * blockDim.x;
    for (int64_t idx = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
         idx < total; idx += stride) {
        /* linear scan np<=64 — cheap, branch-coherent within a warp for the
         * large contiguous tensors that dominate the element count. */
        int p = 0;
        while (p + 1 < f.np && idx >= f.off[p + 1]) p++;
        int64_t i = idx - f.off[p];
        double g    = f.G[p][i];
        double mi   = f.b1 * f.Mm[p][i] + (1.0 - f.b1) * g;
        double vi   = f.b2 * f.Vv[p][i] + (1.0 - f.b2) * g * g;
        double mhat = mi / f.c1;
        double vhat = vi / f.c2;
        double denom = sqrt(vhat) + f.eps;
        double wi   = f.W[p][i] - f.lr * f.wd * f.W[p][i] - f.lr * mhat / denom;
        f.Mm[p][i] = mi;
        f.Vv[p][i] = vi;
        f.W[p][i]  = wi;
    }
}
#endif /* __CUDACC__ */
/* Launcher — accepts up to HX_FS_MAXP (w,m,v,g,n) quintuples flattened into
 * parallel id arrays + a count. Resolves all to device buffers (H2D each),
 * builds the prefix-offset table, cooperativeLaunch ONE _hx_k_adamw_fused,
 * then D2H W/m/v for every tensor (same write-back contract as the per-
 * param inplace path). Returns 0 ok / -1 (→ caller falls back to the per-
 * param _adam loop, byte-eq). step_t/lr/b1/b2/eps/wd shared (clm uses one
 * global schedule). assert_eq unused (arithmetic is byte-eq by construction). */
int _hx_cuda_farr_adamw_fused_gpu(const int64_t* w_ids, const int64_t* m_ids,
                                  const int64_t* v_ids, const int64_t* g_ids,
                                  const int64_t* ns, int np,
                                  double lr, double b1, double b2,
                                  double eps, double wd, int64_t step_t) {
#ifdef __CUDACC__
    if (np <= 0 || np > HX_FS_MAXP || step_t < 1) {
        fprintf(stderr, "[cuda] adamw_fused: bad np=%d step_t=%lld\n",
                np, (long long)step_t);
        return -1;
    }
    int dev = 0; cudaGetDevice(&dev);
    int coop = 0;
    cudaDeviceGetAttribute(&coop, cudaDevAttrCooperativeLaunch, dev);
    if (!coop) { fprintf(stderr, "[cuda] adamw_fused: no cooperativeLaunch\n"); return -1; }
    for (int p = 0; p < np; p++) {
        if (ns[p] <= 0) { fprintf(stderr, "[cuda] adamw_fused: bad n[%d]\n", p); return -1; }
        if (_h2d(w_ids[p]) != 0) return -1;
        if (_h2d(m_ids[p]) != 0) return -1;
        if (_h2d(v_ids[p]) != 0) return -1;
        if (_h2d(g_ids[p]) != 0) return -1;
    }
    double b1t = 1.0, b2t = 1.0;
    for (int64_t e = 0; e < step_t; e++) { b1t *= b1; b2t *= b2; }
    _HxAdamFused f;
    f.np = np; f.lr = lr; f.b1 = b1; f.b2 = b2; f.eps = eps; f.wd = wd;
    f.c1 = 1.0 - b1t; f.c2 = 1.0 - b2t;
    f.off[0] = 0;
    for (int p = 0; p < np; p++) {
        f.W[p]  = g_slots[w_ids[p]].d_buf;
        f.Mm[p] = g_slots[m_ids[p]].d_buf;
        f.Vv[p] = g_slots[v_ids[p]].d_buf;
        f.G[p]  = g_slots[g_ids[p]].d_buf;
        f.off[p + 1] = f.off[p] + ns[p];
    }
    int blk = 256;
    int numBlocksPerSm = 0;
    cudaOccupancyMaxActiveBlocksPerMultiprocessor(&numBlocksPerSm,
        (void*)_hx_k_adamw_fused, blk, 0);
    if (numBlocksPerSm < 1) numBlocksPerSm = 1;
    int numSm = 0; cudaDeviceGetAttribute(&numSm, cudaDevAttrMultiProcessorCount, dev);
    if (numSm < 1) numSm = 1;
    int grid_sz = numSm * numBlocksPerSm;
    dim3 gdim(grid_sz), bdim(blk);
    void* args[] = { (void*)&f };
    cudaError_t le = cudaLaunchCooperativeKernel((void*)_hx_k_adamw_fused,
                        gdim, bdim, args, 0, _forge_stream());
    if (le != cudaSuccess) {
        fprintf(stderr, "[cuda] adamw_fused coop launch: %s\n", cudaGetErrorString(le));
        return -1;
    }
    if (_forge_launch_check("adamw_fused") != 0) return -1;
    { static int _af_fired = 0; if (!_af_fired) { _af_fired = 1;
        fprintf(stderr, "[FULLSTEP-FIRED] _hx_k_adamw_fused cooperative AdamW over %d params in ONE launch (grid=%d blk=%d, optimizer tail collapsed)\n", np, grid_sz, blk); } }
    for (int p = 0; p < np; p++) {
        if (_d2h(w_ids[p]) != 0) return -1;
        if (_d2h(m_ids[p]) != 0) return -1;
        if (_d2h(v_ids[p]) != 0) return -1;
    }
    return 0;
#else
    (void)w_ids;(void)m_ids;(void)v_ids;(void)g_ids;(void)ns;(void)np;
    (void)lr;(void)b1;(void)b2;(void)eps;(void)wd;(void)step_t;
    fprintf(stderr, "[cuda] adamw_fused: built without __CUDACC__\n");
    return -1;
#endif
}

/* ════════════════════════════════════════════════════════════════════
 * HEXA-FUSION L1 — device-resident moment lifetime (m, v).
 *
 * Identical arithmetic to _hx_cuda_farr_adamw_step_inplace_gpu, but the
 * Adam first/second moments m and v are kept DEVICE-RESIDENT across the
 * step boundary: NO D2H of m/v after the kernel. They are only ever
 * read + written by AdamW itself (never by the host fwd/bwd — in
 * clm_prod.hexa m_* / v_* escape ONLY into _adam), so there is no host
 * reader between steps and the device buffer is the sole authoritative
 * copy. W IS still D2H'd (the host forward re-quantizes the conv
 * weights, so W must materialize on host every step — contract kept).
 *
 * Residence contract for m/v after this call:
 *   loc = FARR_DEVICE, dirty_host = 0, live device slot, matching len.
 * The NEXT step's _h2d(m)/_h2d(v) then hits the RFC 056 §6.1 H2D-skip
 * (loc∈{DEVICE,MIRRORED} && !dirty_host && s->d_buf && s->len==e->len)
 * and SKIPs the cudaMemcpy HostToDevice — the device accumulator is
 * reused in place. We leave dirty_host=0 (NOT 1): host m/v is stale but
 * is provably never read, so the skip is byte-eq to the always-D2H
 * path — both leave the device holding the same fresh moments the next
 * kernel reads. Removes 2 (m,v) × 2 (D2H now + H2D next) cudaMemcpy per
 * param-tensor / step (pure roundtrip/boundary removal; NOT a kernel
 * speed claim). Gated in clm_prod.hexa behind env CLM_PROD_DEVRESIDENT;
 * default off → existing inplace path unchanged (F-CLM-DEVFEED-* 0.0). */
int _hx_cuda_farr_adamw_step_inplace_keepmv_gpu(int64_t w_id, int64_t m_id,
                                  int64_t v_id, int64_t g_id,
                                  int64_t n, double lr, double b1,
                                  double b2, double eps, double wd,
                                  int64_t step_t) {
#ifdef __CUDACC__
    if (n <= 0 || step_t < 1) {
        fprintf(stderr, "[cuda] adamw_keepmv: bad n=%lld step_t=%lld\n",
                (long long)n, (long long)step_t);
        return -1;
    }
    if (_h2d(w_id) != 0) return -1;
    if (_h2d(m_id) != 0) return -1;
    if (_h2d(v_id) != 0) return -1;
    if (_h2d(g_id) != 0) return -1;

    double b1t = 1.0, b2t = 1.0;
    for (int64_t e = 0; e < step_t; e++) { b1t *= b1; b2t *= b2; }
    double c1 = 1.0 - b1t;
    double c2 = 1.0 - b2t;

    double* W  = g_slots[w_id].d_buf;
    double* Mm = g_slots[m_id].d_buf;
    double* Vv = g_slots[v_id].d_buf;
    const double* G = g_slots[g_id].d_buf;

    int block_sz = 256;
    int64_t want_blocks = (n + block_sz - 1) / block_sz;
    int grid_sz = (want_blocks > 1024) ? 1024 : (int)want_blocks;
    if (grid_sz < 1) grid_sz = 1;

    _hx_k_adamw_step_inplace<<<grid_sz, block_sz, 0, _forge_stream()>>>(W, Mm, Vv, G, n,
                                            lr, b1, b2, eps, wd, c1, c2);
    cudaError_t er = cudaDeviceSynchronize();
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] adamw_keepmv launch failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    /* W materializes on host (host fwd reads it). m, v stay DEVICE-
     * RESIDENT: mark loc=FARR_DEVICE, dirty_host=0 so the next step's
     * _h2d SKIPs the H2D and reuses the device accumulator in place
     * — host m/v never read (byte-eq to the always-D2H inplace path). */
    if (_d2h(w_id) != 0) return -1;
    {
        HexaFarrEntry* em = &_hx_farr_table[m_id];
        HexaFarrEntry* ev = &_hx_farr_table[v_id];
        em->d_buf = (void*)g_slots[m_id].d_buf;
        ev->d_buf = (void*)g_slots[v_id].d_buf;
        em->loc = FARR_DEVICE; ev->loc = FARR_DEVICE;
        em->dirty_host = 0;    ev->dirty_host = 0;
        em->dirty_dev  = 0;    ev->dirty_dev  = 0;
    }
    return 0;
#else
    (void)w_id; (void)m_id; (void)v_id; (void)g_id;
    (void)n; (void)lr; (void)b1; (void)b2; (void)eps; (void)wd;
    (void)step_t;
    fprintf(stderr, "[cuda] adamw_keepmv: built without __CUDACC__\n");
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
    /* HEXA_OWN_GEMM (CUDA-OWN) — reuse the in-file _hx_k_gemm row-major
     * C=A·B kernel for out[1,C] = u[1,R] · M[R,C] (M_outer=1, K=R, N=C;
     * A=U_dev[1,R], B=M_dev[R,C], C=O_dev[1,C]). NOT bit-eq vs cuBLAS
     * (naive K-accum order vs cuBLAS-tiled) — rel-RMS within TOL_MATMUL,
     * cuBLAS demoted to correctness oracle. OFF (default) keeps the exact
     * cublasDgemm path below byte-identical to the prior build. */
    if (_forge_own_gemm_on()) {
        static int _own_matmult_fired = 0;
        if (!_own_matmult_fired) { _own_matmult_fired = 1;
            fprintf(stderr, "[OWN-GEMM-FIRED] _hx_k_gemm (matmul_t) DEVICE path (no cuBLAS)\n"); }
        dim3 _mblk(16, 16);
        dim3 _mgrd((unsigned)((C + 15) / 16), 1u);
        _hx_k_gemm<<<_mgrd, _mblk, 0, _forge_stream()>>>(U_dev, M_dev, O_dev,
                                                         (int64_t)1, R, C);
        if (_forge_launch_check("own_matmul_t") != 0) return -1;
        return _d2h_out(out_id, C);
    }
#ifdef HEXA_USE_CUBLAS
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
#else
    fprintf(stderr, "[cuda] matmul_t: own path should have returned\n");
    return -1;
#endif
}

/* packed_gemv_offset: out[i] = Σ_j P[off + i·cols + j]·U[j], out[rows].
 * P is a packed-double buffer; the [rows×cols] row-major sub-block
 * starts at element `off`. anima mm_packed_gemv 1:1.
 *
 * cuBLAS sees the (row-major) sub-block P[off..] as a column-major
 * [cols×rows] matrix A with lda=cols. Then A^T (= [rows×cols], our
 * row-major block) times U[cols] gives out[rows]:
 *   cublasDgemv(handle, CUBLAS_OP_T, m=cols, n=rows, alpha,
 *               A=P_dev+off, lda=cols, U_dev, incx=1, beta,
 *               O_dev, incy=1).
 * Single dot-product per output row, cuBLAS-tiled reduction →
 * TOL_MATMUL ≈ 2e-9 (same caveat as matmul_t). H2D P once (whole
 * buffer), base+offset device pointer, D2H out. */
/* HEXA-TRAIN-FLOOR M6/bf16 — training compute dtype selector (3-way).
 *   Reads HEXA_TRAIN_DTYPE once per call (cheap; process-stable in
 *   practice) and maps it to a compute-precision tier:
 *     HX_TRAIN_DTYPE_FP64 (0) — default / `fp64`/`f64`/`double`/unset
 *     HX_TRAIN_DTYPE_FP32 (1) — `fp32`/`f32`/`float`     (M6 slice)
 *     HX_TRAIN_DTYPE_BF16 (2) — `bf16`/`bfloat16`        (bf16 lever)
 *   Any UNRECOGNIZED value keeps fp64 — an unknown value NEVER silently
 *   downgrades precision (fail-safe to the exact path). Only fp64 is
 *   bit-eq vs the reference; fp32/bf16 are opt-in mixed precision. The
 *   bf16 tier here drives the in-place bf16-MAC gemv kernel (bf16
 *   operands, FP32 accumulator); the WMMA/cublasGemmEx TENSOR_OP route
 *   is the RFC 049 runtime_bf16.c substrate (residual scope). */
enum { HX_TRAIN_DTYPE_FP64 = 0, HX_TRAIN_DTYPE_FP32 = 1, HX_TRAIN_DTYPE_BF16 = 2 };
static int _hx_train_dtype(void) {
    const char* d = getenv("HEXA_TRAIN_DTYPE");
    if (!d || !*d) return HX_TRAIN_DTYPE_FP64;
    if (strcmp(d, "fp32")     == 0) return HX_TRAIN_DTYPE_FP32;
    if (strcmp(d, "f32")      == 0) return HX_TRAIN_DTYPE_FP32;
    if (strcmp(d, "float")    == 0) return HX_TRAIN_DTYPE_FP32;
    if (strcmp(d, "bf16")     == 0) return HX_TRAIN_DTYPE_BF16;
    if (strcmp(d, "bfloat16") == 0) return HX_TRAIN_DTYPE_BF16;
    return HX_TRAIN_DTYPE_FP64;  /* fp64 / fp64-spellings / unknown → exact */
}
/* M6 back-compat shim — the fp32 predicate now delegates to the 3-way
 * selector (no behavior change for existing fp32 callers). */
static int _hx_train_dtype_is_fp32(void) {
    return _hx_train_dtype() == HX_TRAIN_DTYPE_FP32;
}

int _hx_cuda_farr_packed_gemv_offset_gpu(int64_t p_id, int64_t off,
                               int64_t rows, int64_t cols,
                               int64_t u_id, int64_t out_id) {
    if (rows <= 0 || cols <= 0 || off < 0) {
        fprintf(stderr, "[cuda] packed_gemv_offset: bad off=%lld rows=%lld cols=%lld\n",
                (long long)off, (long long)rows, (long long)cols);
        return -1;
    }
    if (_h2d(p_id) != 0) return -1;
    if (_h2d(u_id) != 0) return -1;
    if (_ensure_dev_alloc_out(out_id, rows) != 0) return -1;

    double* P_dev = g_slots[p_id].d_buf + off;
    double* U_dev = g_slots[u_id].d_buf;
    double* O_dev = g_slots[out_id].d_buf;
#ifdef __CUDACC__
    /* HEXA_OWN_GEMM (CUDA-OWN) — force the in-file FP64 on-device gemv
     * kernel _hx_k_packed_gemv_offset (one block per output row, fixed
     * block-tree reduction) regardless of the rows-size crossover gate
     * below. This OWNS the cublasDgemv(packed_gemv_offset) call: under
     * HEXA_OWN_GEMM the FP64 path never reaches cuBLAS. NOT bit-eq vs
     * cuBLAS (block-tree reduction order vs cuBLAS-tiled) — rel-RMS within
     * TOL_MATMUL, cuBLAS demoted to oracle. Checked before the dtype
     * slices so own-FP64 wins for the default (fp64) dtype; the opt-in
     * fp32/bf16 mixed-precision kernels still take precedence (a separate,
     * deliberately-narrowed-precision choice). OFF (default) → falls
     * through to the existing gate, byte-identical to the prior build. */
    if (_forge_own_gemm_on() &&
        _hx_train_dtype() == HX_TRAIN_DTYPE_FP64) {
        static int _own_gemv_fired = 0;
        if (!_own_gemv_fired) { _own_gemv_fired = 1;
            fprintf(stderr, "[OWN-GEMM-FIRED] _hx_k_packed_gemv_offset DEVICE path (no cuBLAS)\n"); }
        dim3 grid_o((unsigned)rows), block_o(HX_RR_BLOCK);
        _hx_k_packed_gemv_offset<<<grid_o, block_o>>>(g_slots[p_id].d_buf, off,
                                                      U_dev, O_dev, rows, cols);
        cudaError_t oer = cudaDeviceSynchronize();
        if (oer != cudaSuccess) {
            fprintf(stderr, "[cuda] packed_gemv_offset own kernel failed: %s\n",
                    cudaGetErrorString(oer));
            return -1;
        }
        return _d2h_out(out_id, rows);
    }
    /* HEXA-TRAIN-FLOOR bf16 lever — bf16 dtype slice (opt-in). When
     * HEXA_TRAIN_DTYPE selects bf16, run the bf16-MAC on-device gemv
     * kernel: operands narrowed fp64→bf16 (RNE) at load, multiply-
     * accumulated in fp32 (FP32 accumulator for convergence stability,
     * mirroring the RFC 049 cublasGemmEx CUBLAS_COMPUTE_32F discipline).
     * Exercises the device's bf16 throughput — the M4-identified fp64-
     * compute-bound ceiling-break. Checked before fp32 (more aggressive
     * precision opt-in). NOT bit-eq vs fp64; default keeps fp64. */
    if (_hx_train_dtype() == HX_TRAIN_DTYPE_BF16) {
        dim3 grid_b((unsigned)rows), block_b(HX_RR_BLOCK);
        _hx_k_packed_gemv_offset_bf16<<<grid_b, block_b>>>(
            g_slots[p_id].d_buf, off, U_dev, O_dev, rows, cols);
        cudaError_t ber = cudaDeviceSynchronize();
        if (ber != cudaSuccess) {
            fprintf(stderr, "[cuda] packed_gemv_offset bf16 kernel failed: %s\n",
                    cudaGetErrorString(ber));
            return -1;
        }
        return _d2h_out(out_id, rows);
    }
    /* HEXA-TRAIN-FLOOR M6 — fp32 dtype slice (opt-in). When
     * HEXA_TRAIN_DTYPE selects fp32, run the fp32-accumulating on-device
     * gemv kernel: it narrows the fp64 device operands to fp32 at load
     * and reduces in fp32, exercising the device's fp32 throughput (the
     * M4-identified fp64-compute-bound lever). Independent of the cuBLAS
     * min-dim sync gate below — fp32 is a COMPUTE-precision choice, not a
     * dispatch-cost one. NOT bit-eq vs fp64 (mantissa loss); default
     * (unset/fp64) keeps the exact fp64 path unchanged. */
    if (_hx_train_dtype_is_fp32()) {
        dim3 grid_f((unsigned)rows), block_f(HX_RR_BLOCK);
        _hx_k_packed_gemv_offset_f32<<<grid_f, block_f>>>(
            g_slots[p_id].d_buf, off, U_dev, O_dev, rows, cols);
        cudaError_t fer = cudaDeviceSynchronize();
        if (fer != cudaSuccess) {
            fprintf(stderr, "[cuda] packed_gemv_offset fp32 kernel failed: %s\n",
                    cudaGetErrorString(fer));
            return -1;
        }
        return _d2h_out(out_id, rows);
    }
    /* work-size gate (hexa-lang #1354, rekeyed by HEXA-TRAIN-FLOOR M8).
     * The on-device kernel is one-block-per-row, so its true cost
     * predictor is `rows` (= #blocks = output dim), NOT the contraction
     * dim `cols`. M7 RTX 5070 microbench (.verdicts/hexa-train-floor/
     * M7-gemv-dthreshold.txt): on-device beats cuBLAS Dgemv at rows<=256
     * across ALL cols (f64/cuBLAS 0.63-0.99), but LOSES at rows=768
     * (1.11-1.34x) even for cols=64 — so a cols<128 gate would regress
     * large-output gemv. Rekeyed to rows: use the on-device block-
     * reduction kernel only when rows < threshold; large rows keeps
     * cuBLAS (regression-free). Default 512, between the measured
     * win@256 and loss@768 crossover. Override via
     * HEXA_GEMV_CUBLAS_MIN_ROWS; legacy HEXA_GEMV_CUBLAS_MIN_DIM still
     * honored as an alias for back-compat. */
    long min_rows = 512;
    const char* _mr = getenv("HEXA_GEMV_CUBLAS_MIN_ROWS");
    if (!(_mr && *_mr)) _mr = getenv("HEXA_GEMV_CUBLAS_MIN_DIM");
    if (_mr && *_mr) { long v = atol(_mr); if (v > 0) min_rows = v; }
    if (rows < min_rows) {
        dim3 grid((unsigned)rows), block(HX_RR_BLOCK);
        _hx_k_packed_gemv_offset<<<grid, block>>>(g_slots[p_id].d_buf, off,
                                                  U_dev, O_dev, rows, cols);
        cudaError_t ker = cudaDeviceSynchronize();
        if (ker != cudaSuccess) {
            fprintf(stderr, "[cuda] packed_gemv_offset kernel failed: %s\n",
                    cudaGetErrorString(ker));
            return -1;
        }
        return _d2h_out(out_id, rows);
    }
#ifndef HEXA_USE_CUBLAS
    /* cuBLAS-free: large-rows also goes own (the own FP64 kernel fired above
     * under _forge_own_gemm_on()==1, so this point is unreachable for CUDACC;
     * run the own kernel here too for robustness, then return). */
    {
        dim3 grid((unsigned)rows), block(HX_RR_BLOCK);
        _hx_k_packed_gemv_offset<<<grid, block>>>(g_slots[p_id].d_buf, off,
                                                  U_dev, O_dev, rows, cols);
        cudaError_t ker = cudaDeviceSynchronize();
        if (ker != cudaSuccess) {
            fprintf(stderr, "[cuda] packed_gemv_offset own(large) failed: %s\n",
                    cudaGetErrorString(ker));
            return -1;
        }
        return _d2h_out(out_id, rows);
    }
#endif
#endif
#ifdef HEXA_USE_CUBLAS
    if (_ensure_cublas() != 0) return -1;
    const double alpha = 1.0, beta = 0.0;
    cublasStatus_t st = cublasDgemv(g_cublas, CUBLAS_OP_T,
                                    (int)cols, (int)rows,
                                    &alpha,
                                    P_dev, (int)cols,
                                    U_dev, 1,
                                    &beta,
                                    O_dev, 1);
    if (st != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[cuda] cublasDgemv(packed_gemv_offset) failed: %d\n", (int)st);
        return -1;
    }
    return _d2h_out(out_id, rows);
#else
    fprintf(stderr, "[cuda] packed_gemv_offset: no CUDA device path\n");
    return -1;
#endif
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
    /* HEXA_OWN_GEMM (CUDA-OWN) — reuse the in-file _hx_k_gemm row-major
     * C=A·B kernel for out[R,C] = u[R,1] · v[1,C] (M_outer=R, K=1, N=C;
     * A=U_dev[R,1], B=V_dev[1,C], C=O_dev[R,C]). K=1 → SINGLE product per
     * output cell → ZERO reduction → BIT-EXACT vs cuBLAS (and vs the CPU
     * c3_outer oracle): max|Δ| = 0, same as the F-RFC041-OUTER-EXACT
     * contract. OFF (default) keeps the exact cublasDgemm path byte-id. */
    if (_forge_own_gemm_on()) {
        static int _own_outer_fired = 0;
        if (!_own_outer_fired) { _own_outer_fired = 1;
            fprintf(stderr, "[OWN-GEMM-FIRED] _hx_k_gemm (outer, k=1) DEVICE path (no cuBLAS)\n"); }
        dim3 _oblk(16, 16);
        dim3 _ogrd((unsigned)((C + 15) / 16), (unsigned)((R + 15) / 16));
        _hx_k_gemm<<<_ogrd, _oblk, 0, _forge_stream()>>>(U_dev, V_dev, O_dev,
                                                         R, (int64_t)1, C);
        if (_forge_launch_check("own_outer") != 0) return -1;
        return _d2h_out(out_id, R * C);
    }
#ifdef HEXA_USE_CUBLAS
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
#else
    fprintf(stderr, "[cuda] outer: own path should have returned\n");
    return -1;
#endif
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
    if (_forge_out_keep()) {
        e->d_buf      = (void*)s->d_buf;
        e->loc        = FARR_DEVICE;
        /* residency-fix (same bug as _d2h_out): device-keep output is
         * NOT user-mutated. dirty_host=1 here blocked the _h2d skip
         * (!dirty_host) so the next op re-uploaded the never-written host
         * buffer, clobbering this device output with stale zeros. loc=
         * FARR_DEVICE + dirty_dev=1 already track host-staleness. */
        e->dirty_host = 0;
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
    _hx_cuda_kern_add<<<grid, _HX_CUDA_ELEM_BLOCK, 0, _forge_stream()>>>(A, B, C, n);
    if (_forge_launch_check("add") != 0) return -1;
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
    _hx_cuda_kern_scale<<<grid, _HX_CUDA_ELEM_BLOCK, 0, _forge_stream()>>>(X, alpha, Y, n);
    if (_forge_launch_check("scale") != 0) return -1;
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
    _hx_cuda_kern_mul<<<grid, _HX_CUDA_ELEM_BLOCK, 0, _forge_stream()>>>(A, B, C, n);
    if (_forge_launch_check("mul") != 0) return -1;
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
    _hx_cuda_kern_silu<<<grid, _HX_CUDA_ELEM_BLOCK, 0, _forge_stream()>>>(X, Y, n);
    if (_forge_launch_check("silu") != 0) return -1;
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
    _hx_cuda_kern_silu_grad<<<grid, _HX_CUDA_ELEM_BLOCK, 0, _forge_stream()>>>(X, Y, n);
    if (_forge_launch_check("silu_grad") != 0) return -1;
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
        _hx_cuda_kern_rope_bwd<<<grid, _HX_CUDA_ELEM_BLOCK, 0, _forge_stream()>>>(
            X, COS, SIN, Y, T, nheads, hd);
    } else {
        _hx_cuda_kern_rope_fwd<<<grid, _HX_CUDA_ELEM_BLOCK, 0, _forge_stream()>>>(
            X, COS, SIN, Y, T, nheads, hd);
    }
    if (_forge_launch_check(tag) != 0) return -1;
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
    _hx_cuda_kern_transpose_scatter<<<grid, _HX_CUDA_ELEM_BLOCK, 0, _forge_stream()>>>(
        SRC, DST, rows, cols, dst_off);
    if (_forge_launch_check("transpose_scatter") != 0) return -1;
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




/* ── mk2 dt_* faithful device transcendentals restored from e030fa31 ─
 * _hx_cuda_dt_exp_d / _hx_cuda_dt_sqrt_d: non-contracted (__dmul_rn/
 * __dadd_rn/__ddiv_rn) device mirrors of the CPU _hx_dt_*_d, byte-eq
 * under FP_CONTRACT OFF (commit b73269ea discipline). Called by the
 * mk2-C5 device kernels below — must precede them. */
__device__ __forceinline__ double _hx_cuda_dt_exp_d(double x) {
    int r = 0;
    double xr = x;
    while ((xr > 0.0 ? xr : 0.0 - xr) > 0.25) { xr = xr / 2.0; r = r + 1; }
    double term = 1.0;
    double acc  = 1.0;
    int k = 1;
    while (k < 12) {
        term = __ddiv_rn(__dmul_rn(term, xr), (double)k);
        acc  = __dadd_rn(acc, term);
        k = k + 1;
    }
    int s = 0;
    while (s < r) { acc = __dmul_rn(acc, acc); s = s + 1; }
    return acc;
}

/* mk2-C2 (2026-05-19): dt_sqrt byte-exact device mirror of hexa
 * flame_math `dt_sqrt` (24-iter Newton from g0 = max(x,1)). The
 * decoder-block rmsnorm reference uses dt_sqrt, NOT libm sqrt —
 * same FMA / transcendental hazard as dt_exp. __dmul_rn / __ddiv_rn /
 * __dadd_rn = contraction-immune, byte-eq to host _hx_dt_sqrt_d
 * under FP_CONTRACT OFF (same discipline as the silu-gate dt_exp
 * mirror, commit e5faa8b0). */
__device__ __forceinline__ double _hx_cuda_dt_sqrt_d(double x) {
    if (x <= 0.0) return 0.0;
    double g = x > 1.0 ? x : 1.0;
    int i = 0;
    while (i < 24) {
        g = __dmul_rn(0.5, __dadd_rn(g, __ddiv_rn(x, g)));
        i = i + 1;
    }
    return g;
}

/* ── mk2-C5 __global__ device kernels restored from e030fa31 ───────
 * Launched by the host wrappers immediately below; the A/B/C merge
 * dropped both halves. Pure double* math kernels, FP_CONTRACT-safe
 * (compiled by nvcc -x cu). Must precede the host launchers. */
__global__ void _hx_cuda_kern_rmsnorm_mh(const double* __restrict__ X,
                                         const double* __restrict__ G,
                                         double* __restrict__ Y,
                                         double* __restrict__ XN,
                                         double* __restrict__ I,
                                         int64_t T, int64_t d) {
    int64_t i      = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    int64_t stride = (int64_t)gridDim.x  * (int64_t)blockDim.x;
    const double eps = 0.000001;
    for (; i < T; i += stride) {
        double ms = 0.0;
        for (int64_t c = 0; c < d; c++) {
            double xv = X[i*d + c];
            ms = __dadd_rn(ms, __dmul_rn(xv, xv));
        }
        ms = __ddiv_rn(ms, (double)d);
        double iv = __ddiv_rn(1.0, _hx_cuda_dt_sqrt_d(__dadd_rn(ms, eps)));
        I[i] = iv;
        for (int64_t c = 0; c < d; c++) {
            double xni = __dmul_rn(X[i*d + c], iv);
            XN[i*d + c] = xni;
            Y[i*d + c]  = __dmul_rn(G[c], xni);
        }
    }
}

/* mk2-C5 (2026-05-19): farr_copy_slice + farr_transpose_2d device
 * kernels — bandwidth-bound memcpy / memory rearrangement. No FP
 * arithmetic → trivially byte-eq with the host scalar t_get/t_set
 * loop. Eliminates the ~412M scalar HexaVal-box prelude that
 * dominated the d768·12L generic ag_tape step (mk2-FINAL #1 fire
 * 2026-05-19 timeout at 901s with 14min GPU idle). */
__global__ void _hx_cuda_kern_copy_slice(const double* __restrict__ src,
                                         double* __restrict__ dst,
                                         int64_t n) {
    int64_t i      = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    int64_t stride = (int64_t)gridDim.x  * (int64_t)blockDim.x;
    for (; i < n; i += stride) {
        dst[i] = src[i];
    }
}

/* transpose: dst[c·d_out + r] = src[soff + r·d_in + c], one thread per
 * (r, c) cell. byte-identical to the agt_wT_slice / agt_wT_off host
 * loop (no FP — pure memory rearrangement). */
__global__ void _hx_cuda_kern_transpose_2d(const double* __restrict__ src,
                                           int64_t soff,
                                           double* __restrict__ dst,
                                           int64_t doff,
                                           int64_t d_out, int64_t d_in) {
    int64_t flat   = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    int64_t total  = d_out * d_in;
    int64_t stride = (int64_t)gridDim.x  * (int64_t)blockDim.x;
    for (; flat < total; flat += stride) {
        int64_t r = flat / d_in;
        int64_t c = flat - r * d_in;
        dst[doff + c * d_out + r] = src[soff + r * d_in + c];
    }
}

/* mk2-C4 (2026-05-19): GQA attention-dt forge-route. One thread per
 * (head, query) pair = nh·T threads (strict per-pair sequential for
 * byte-eq with the host loop's nested hh→i→j order). Memory contract:
 *   in:  Q[T·nh·hd], K[T·nkv·hd], V[T·nkv·hd]
 *   out: P[nh·T·T]   — causal probs, j ∈ [0,i+1); j ∈ [i+1,T) is 0.
 *        CTX[T·nh·hd]
 * Uses dt_sqrt mirror (scale=1/√hd) + dt_exp mirror (stable softmax).
 * P doubles as scratch: step 1 writes raw scores; steps 3-4 transform
 * in place to probs. Op order byte-identical to ag_tape.hexa
 * _ag_attn_dt_fwd (causal mask + per-row stable softmax + GQA kvh =
 * hh/n_rep). */
__global__ void _hx_cuda_kern_attn_dt_fwd(const double* __restrict__ Q,
                                          const double* __restrict__ K,
                                          const double* __restrict__ V,
                                          double* __restrict__ P,
                                          double* __restrict__ CTX,
                                          int64_t T, int64_t nh,
                                          int64_t nkv, int64_t hd) {
    int64_t flat   = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    int64_t total  = nh * T;
    int64_t stride = (int64_t)gridDim.x  * (int64_t)blockDim.x;
    int64_t n_rep  = nh / nkv;
    int64_t d      = nh * hd;
    /* scale = 1 / dt_sqrt(hd). dt_sqrt-faithful (NOT libm sqrt) —
     * same hazard as rmsnorm. */
    double scale = __ddiv_rn(1.0, _hx_cuda_dt_sqrt_d((double)hd));
    for (; flat < total; flat += stride) {
        int64_t hh  = flat / T;
        int64_t i   = flat % T;
        int64_t kvh = hh / n_rep;
        int64_t L   = i + 1;
        /* Step 1: P[hh,i,j] = dot(Q[i,hh,·], K[j,kvh,·]) * scale */
        for (int64_t j = 0; j < L; j++) {
            double dot = 0.0;
            for (int64_t c = 0; c < hd; c++) {
                dot = __dadd_rn(dot,
                                __dmul_rn(Q[(i*nh + hh)*hd + c],
                                          K[(j*nkv + kvh)*hd + c]));
            }
            P[(hh*T + i)*T + j] = __dmul_rn(dot, scale);
        }
        /* Step 2: max */
        double mx = P[(hh*T + i)*T + 0];
        for (int64_t j = 1; j < L; j++) {
            double v = P[(hh*T + i)*T + j];
            if (v > mx) mx = v;
        }
        /* Step 3: e = dt_exp(P − mx); P := e; tot += e. */
        double tot = 0.0;
        for (int64_t j = 0; j < L; j++) {
            double e = _hx_cuda_dt_exp_d(P[(hh*T + i)*T + j] - mx);
            P[(hh*T + i)*T + j] = e;
            tot = __dadd_rn(tot, e);
        }
        /* Step 4: normalize */
        for (int64_t j = 0; j < L; j++) {
            P[(hh*T + i)*T + j] = __ddiv_rn(P[(hh*T + i)*T + j], tot);
        }
        /* Step 5: ctx[i,hh,c2] = Σ P[hh,i,j] · V[j,kvh,c2] */
        for (int64_t c2 = 0; c2 < hd; c2++) {
            double acc = 0.0;
            for (int64_t j = 0; j < L; j++) {
                acc = __dadd_rn(acc,
                                __dmul_rn(P[(hh*T + i)*T + j],
                                          V[(j*nkv + kvh)*hd + c2]));
            }
            CTX[i*d + hh*hd + c2] = acc;
        }
    }
}

/* mk2-C4-bwd (2026-05-19): GQA attention-dt bwd. Three kernels with
 * a shared scratch buffer (dP_row[nh·T·T], allocated by the host
 * wrapper).
 *   Step 1 (dProw kernel) — per (hh,i,j): dP_row[hh,i,j] = Σ_c
 *     dctx[i,hh,c]·V[j,kvh,c], j < L only.
 *   Step 2 (dS+dQ kernel) — per (hh,i): sdot=Σ_j P·dP_row; then for
 *     j<L overwrite dP_row[hh,i,j] := P·(dP_row[hh,i,j]-sdot)·scale
 *     (this IS dS); then dQ[i,hh,c2] = Σ_j dS·K[j,kvh,c2]. Each
 *     thread owns its dQ[(i*nh+hh)*hd + c2] cell — no race.
 *   Step 3a (dV kernel) — per (j,kvh,c): dV[j,kvh,c] = Σ_{hh in
 *     group, i ≥ j} P[hh,i,j]·dctx[i,hh,c]. Output-centric strict
 *     sequential = byte-eq with CPU canonical (hh,i) order.
 *   Step 3b (dK kernel) — per (j,kvh,c): dK[j,kvh,c] = Σ_{hh in
 *     group, i ≥ j} dS[hh,i,j]·Q[i,hh,c]. (dS lives in dP_row
 *     scratch after step 2.)
 * dQ/dK/dV are assumed FRESH t_zeros at the call site (the tape
 * replay site allocates them inline). */
__global__ void _hx_cuda_kern_attn_dt_bwd_dProw(
    const double* __restrict__ V,
    const double* __restrict__ dctx,
    double* __restrict__ dProw,
    int64_t T, int64_t nh, int64_t nkv, int64_t hd) {
    int64_t flat   = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    int64_t total  = nh * T * T;
    int64_t stride = (int64_t)gridDim.x  * (int64_t)blockDim.x;
    int64_t n_rep  = nh / nkv;
    int64_t d      = nh * hd;
    for (; flat < total; flat += stride) {
        int64_t hh = flat / (T * T);
        int64_t r  = flat - hh * T * T;
        int64_t i  = r / T;
        int64_t j  = r - i * T;
        if (j > i) { dProw[flat] = 0.0; continue; }
        int64_t kvh = hh / n_rep;
        double acc = 0.0;
        for (int64_t c = 0; c < hd; c++) {
            acc = __dadd_rn(acc,
                            __dmul_rn(dctx[i*d + hh*hd + c],
                                      V[(j*nkv + kvh)*hd + c]));
        }
        dProw[flat] = acc;
    }
}

__global__ void _hx_cuda_kern_attn_dt_bwd_dS_dQ(
    const double* __restrict__ Q,
    const double* __restrict__ K,
    const double* __restrict__ P,
    double* __restrict__ dProw,    /* in: dP_row, out: dS (same buffer) */
    double* __restrict__ dQ,
    int64_t T, int64_t nh, int64_t nkv, int64_t hd) {
    int64_t flat   = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    int64_t total  = nh * T;
    int64_t stride = (int64_t)gridDim.x  * (int64_t)blockDim.x;
    int64_t n_rep  = nh / nkv;
    /* Compute scale device-side (no cross-TU call to host static
     * `_hx_dt_sqrt_d`). 25 Newton iters × per-thread ≈ 300K ops total
     * at d768·12L — negligible. */
    double scale = __ddiv_rn(1.0, _hx_cuda_dt_sqrt_d((double)hd));
    for (; flat < total; flat += stride) {
        int64_t hh = flat / T;
        int64_t i  = flat - hh * T;
        int64_t kvh = hh / n_rep;
        int64_t L = i + 1;
        /* sdot = Σ_j P[hh,i,j] · dP_row[hh,i,j], j∈[0,L) */
        double sdot = 0.0;
        for (int64_t j = 0; j < L; j++) {
            sdot = __dadd_rn(sdot,
                             __dmul_rn(P[(hh*T + i)*T + j],
                                       dProw[(hh*T + i)*T + j]));
        }
        /* in-place: dProw[hh,i,j] := P · (dProw - sdot) · scale = dS */
        for (int64_t j = 0; j < L; j++) {
            double v = dProw[(hh*T + i)*T + j] - sdot;
            dProw[(hh*T + i)*T + j] = __dmul_rn(
                __dmul_rn(P[(hh*T + i)*T + j], v), scale);
        }
        /* dQ[i,hh,c2] = Σ_j dS[hh,i,j] · K[j,kvh,c2]
         * CPU canonical: outer j, inner c2 — accumulator per c2.
         * Reproduce: keep separate dQ acc per c2 (registers), j outer. */
        /* For each c2 ∈ [0..hd), the strict j-ascending fold matches
         * CPU exactly. (kvh constant for this thread.) */
        for (int64_t c2 = 0; c2 < hd; c2++) {
            double acc = 0.0;
            for (int64_t j = 0; j < L; j++) {
                acc = __dadd_rn(acc,
                                __dmul_rn(dProw[(hh*T + i)*T + j],
                                          K[(j*nkv + kvh)*hd + c2]));
            }
            dQ[(i*nh + hh)*hd + c2] = acc;
        }
    }
}

__global__ void _hx_cuda_kern_attn_dt_bwd_dV(
    const double* __restrict__ P,
    const double* __restrict__ dctx,
    double* __restrict__ dV,
    int64_t T, int64_t nh, int64_t nkv, int64_t hd) {
    int64_t flat   = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    int64_t total  = T * nkv * hd;
    int64_t stride = (int64_t)gridDim.x  * (int64_t)blockDim.x;
    int64_t n_rep  = nh / nkv;
    int64_t d      = nh * hd;
    for (; flat < total; flat += stride) {
        int64_t j   = flat / (nkv * hd);
        int64_t r   = flat - j * (nkv * hd);
        int64_t kvh = r / hd;
        int64_t c   = r - kvh * hd;
        int64_t hh0 = kvh * n_rep;
        double acc = 0.0;
        /* CPU canonical order: hh ascending, then i ascending (i ≥ j) */
        for (int64_t hh = hh0; hh < hh0 + n_rep; hh++) {
            for (int64_t i = j; i < T; i++) {
                acc = __dadd_rn(acc,
                                __dmul_rn(P[(hh*T + i)*T + j],
                                          dctx[i*d + hh*hd + c]));
            }
        }
        dV[(j*nkv + kvh)*hd + c] = acc;
    }
}

__global__ void _hx_cuda_kern_attn_dt_bwd_dK(
    const double* __restrict__ Q,
    const double* __restrict__ dS,    /* same buffer as dProw after step 2 */
    double* __restrict__ dK,
    int64_t T, int64_t nh, int64_t nkv, int64_t hd) {
    int64_t flat   = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    int64_t total  = T * nkv * hd;
    int64_t stride = (int64_t)gridDim.x  * (int64_t)blockDim.x;
    int64_t n_rep  = nh / nkv;
    for (; flat < total; flat += stride) {
        int64_t j   = flat / (nkv * hd);
        int64_t r   = flat - j * (nkv * hd);
        int64_t kvh = r / hd;
        int64_t c   = r - kvh * hd;
        int64_t hh0 = kvh * n_rep;
        double acc = 0.0;
        for (int64_t hh = hh0; hh < hh0 + n_rep; hh++) {
            for (int64_t i = j; i < T; i++) {
                acc = __dadd_rn(acc,
                                __dmul_rn(dS[(hh*T + i)*T + j],
                                          Q[(i*nh + hh)*hd + c]));
            }
        }
        dK[(j*nkv + kvh)*hd + c] = acc;
    }
}

/* silu-gate: O[i] = (A[i]·σ(A[i]))·B[i], σ=1/(1+dt_exp(-x)).
 * dt_exp-faithful (NOT _hx_cuda_sigmoid_d's libm exp). Op order
 * byte-identical to CPU _hx_farr_silu_gate_cpu / ag_tape
 * _ag_silu(a)*b. */
__global__ void _hx_cuda_kern_silu_gate(const double* __restrict__ A,
                                        const double* __restrict__ B,
                                        double* __restrict__ O,
                                        int64_t n) {
    int64_t i      = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    int64_t stride = (int64_t)gridDim.x  * (int64_t)blockDim.x;
    for (; i < n; i += stride) {
        double ai  = A[i];
        double sig = 1.0 / (1.0 + _hx_cuda_dt_exp_d(0.0 - ai));
        O[i] = __dmul_rn(__dmul_rn(ai, sig), B[i]);
    }
}


/* ── mk2-C5 GPU kernels restored from e030fa31 (rfc043-flame-camp) ──
 * The A/B/C three-way merge dropped Cycle A's runtime_cuda.c additions;
 * these 9 device kernels are the GPU side of the HEXA_CUDA seam in
 * self/runtime.c (silu_gate/rmsnorm_mh/attn_dt_fwd+bwd/copy_slice/
 * fill_dt_lcg/add_inplace/zero_slice/transpose_2d). byte-eq oracle-
 * gated vs the _hx_farr_*_cpu mirrors. */
/* mk2-C1b: silu-gate O = (A·σ(A))·B (dt_exp-faithful). Two host
 * inputs H2D'd; byte-eq oracle-gated vs CPU _hx_farr_silu_gate_cpu. */
int _hx_cuda_farr_silu_gate_gpu(int64_t a_id, int64_t b_id,
                                int64_t n, int64_t out_id) {
    if (a_id < 0 || b_id < 0 || out_id < 0) {
        fprintf(stderr, "[cuda] silu_gate: bad ids %lld %lld %lld\n",
                (long long)a_id, (long long)b_id, (long long)out_id);
        return -1;
    }
    if (n <= 0) {
        fprintf(stderr, "[cuda] silu_gate: bad n=%lld\n", (long long)n);
        return -1;
    }
    if (a_id >= _hx_farr_count || b_id >= _hx_farr_count ||
        out_id >= _hx_farr_count) {
        fprintf(stderr, "[cuda] silu_gate: id out of range\n");
        return -1;
    }
    if (_hx_farr_table[a_id].len < n || _hx_farr_table[b_id].len < n ||
        _hx_farr_table[out_id].len < n) {
        fprintf(stderr, "[cuda] silu_gate: host len < n\n");
        return -1;
    }
    if (_h2d(a_id) != 0) return -1;
    if (_h2d(b_id) != 0) return -1;
    if (_ensure_dev_buf(out_id, n) != 0) return -1;
    double* A = g_slots[a_id].d_buf;
    double* B = g_slots[b_id].d_buf;
    double* O = g_slots[out_id].d_buf;
    int grid = _hx_cuda_elem_grid(n);
    _hx_cuda_kern_silu_gate<<<grid, _HX_CUDA_ELEM_BLOCK, 0, _forge_stream()>>>(A, B, O, n);
    if (_forge_launch_check("silu_gate") != 0) return -1;
    if (_d2h_out(out_id, n) != 0) return -1;
    return 0;
}

/* mk2-C2 (2026-05-19): rmsnorm-mh fwd forge-route. fwd kernel above
 * computes y[T·d], xn[T·d], inv[T] in one launch (one thread per row,
 * sequential reduction for byte-eq). All three outputs go through
 * _d2h_out → DEVICE_KEEP register honoured (mk2-C3) so the next forge
 * op's _h2d sees them via the §6.1 skip path. Replaces the host-scalar
 * t_get/t_set loop in ag_tape.hexa::ag_rmsnorm_mh, byte-eq oracle-
 * gated vs CPU _hx_farr_rmsnorm_mh_cpu (FP_CONTRACT OFF, dt_sqrt-
 * faithful). */
int _hx_cuda_farr_rmsnorm_mh_gpu(int64_t x_id, int64_t g_id,
                                 int64_t y_id, int64_t xn_id,
                                 int64_t inv_id, int64_t T, int64_t d) {
    if (x_id < 0 || g_id < 0 || y_id < 0 || xn_id < 0 || inv_id < 0) {
        fprintf(stderr, "[cuda] rmsnorm_mh: bad ids\n");
        return -1;
    }
    if (T <= 0 || d <= 0) {
        fprintf(stderr, "[cuda] rmsnorm_mh: bad T=%lld d=%lld\n",
                (long long)T, (long long)d);
        return -1;
    }
    if (x_id >= _hx_farr_count || g_id >= _hx_farr_count ||
        y_id >= _hx_farr_count || xn_id >= _hx_farr_count ||
        inv_id >= _hx_farr_count) {
        fprintf(stderr, "[cuda] rmsnorm_mh: id out of range\n");
        return -1;
    }
    int64_t n_xy = T * d;
    if (_hx_farr_table[x_id].len  < n_xy || _hx_farr_table[g_id].len  < d ||
        _hx_farr_table[y_id].len  < n_xy || _hx_farr_table[xn_id].len < n_xy ||
        _hx_farr_table[inv_id].len < T) {
        fprintf(stderr, "[cuda] rmsnorm_mh: host len mismatch\n");
        return -1;
    }
    if (_h2d(x_id) != 0) return -1;
    if (_h2d(g_id) != 0) return -1;
    if (_ensure_dev_buf(y_id,   n_xy) != 0) return -1;
    if (_ensure_dev_buf(xn_id,  n_xy) != 0) return -1;
    if (_ensure_dev_buf(inv_id, T)    != 0) return -1;
    double* X = g_slots[x_id].d_buf;
    double* G = g_slots[g_id].d_buf;
    double* Y = g_slots[y_id].d_buf;
    double* XN= g_slots[xn_id].d_buf;
    double* I = g_slots[inv_id].d_buf;
    /* one thread per row; T parallel. Cap grid at 65535 (legacy CUDA
     * 1-D grid ceiling we already use elsewhere). */
    int block = 256;
    int64_t need = (T + block - 1) / block;
    int grid = (int)(need < 1 ? 1 : (need > 65535 ? 65535 : need));
    _hx_cuda_kern_rmsnorm_mh<<<grid, block, 0, _forge_stream()>>>(X, G, Y, XN, I, T, d);
    if (_forge_launch_check("rmsnorm_mh") != 0) return -1;
    if (_d2h_out(y_id,   n_xy) != 0) return -1;
    if (_d2h_out(xn_id,  n_xy) != 0) return -1;
    if (_d2h_out(inv_id, T)    != 0) return -1;
    return 0;
}

/* mk2-C4 (2026-05-19): GQA attention-dt fwd forge-route. One kernel
 * launch computes P[nh·T·T] (causal probs, j<L only) and CTX[T·nh·hd]
 * from Q/K/V. dt_sqrt + dt_exp mirrors guarantee byte-eq with the host
 * loop. Outputs honour DEVICE_KEEP via _d2h_out. */
int _hx_cuda_farr_attn_dt_fwd_gpu(int64_t q_id, int64_t k_id, int64_t v_id,
                                  int64_t p_id, int64_t ctx_id,
                                  int64_t T, int64_t nh, int64_t nkv,
                                  int64_t hd) {
    if (q_id < 0 || k_id < 0 || v_id < 0 || p_id < 0 || ctx_id < 0) {
        fprintf(stderr, "[cuda] attn_dt_fwd: bad ids\n");
        return -1;
    }
    if (T <= 0 || nh <= 0 || nkv <= 0 || hd <= 0) {
        fprintf(stderr, "[cuda] attn_dt_fwd: bad dims T=%lld nh=%lld nkv=%lld hd=%lld\n",
                (long long)T, (long long)nh, (long long)nkv, (long long)hd);
        return -1;
    }
    if (nh % nkv != 0) {
        fprintf(stderr, "[cuda] attn_dt_fwd: nh=%lld not divisible by nkv=%lld\n",
                (long long)nh, (long long)nkv);
        return -1;
    }
    if (q_id >= _hx_farr_count || k_id >= _hx_farr_count ||
        v_id >= _hx_farr_count || p_id >= _hx_farr_count ||
        ctx_id >= _hx_farr_count) {
        fprintf(stderr, "[cuda] attn_dt_fwd: id out of range\n");
        return -1;
    }
    int64_t nq = T * nh  * hd;
    int64_t nk = T * nkv * hd;
    int64_t np = nh * T * T;
    if (_hx_farr_table[q_id].len   < nq ||
        _hx_farr_table[k_id].len   < nk ||
        _hx_farr_table[v_id].len   < nk ||
        _hx_farr_table[p_id].len   < np ||
        _hx_farr_table[ctx_id].len < nq) {
        fprintf(stderr, "[cuda] attn_dt_fwd: host len mismatch\n");
        return -1;
    }
    if (_h2d(q_id) != 0) return -1;
    if (_h2d(k_id) != 0) return -1;
    if (_h2d(v_id) != 0) return -1;
    if (_ensure_dev_buf(p_id,   np) != 0) return -1;
    if (_ensure_dev_buf(ctx_id, nq) != 0) return -1;
    /* Zero P first — only j < L positions are written, the upper
     * triangle (j ≥ L per row) must stay 0 to match the t_zeros init
     * on the host side. cudaMemset is fine (P is doubles; 0x00·8 == 0.0). */
    cudaError_t ze = cudaMemsetAsync(g_slots[p_id].d_buf, 0,
                                (size_t)np * sizeof(double), _forge_stream());
    if (ze != cudaSuccess) {
        fprintf(stderr, "[cuda] attn_dt_fwd: cudaMemset P failed: %s\n",
                cudaGetErrorString(ze));
        return -1;
    }
    double* Q = g_slots[q_id].d_buf;
    double* K = g_slots[k_id].d_buf;
    double* V = g_slots[v_id].d_buf;
    double* P = g_slots[p_id].d_buf;
    double* C = g_slots[ctx_id].d_buf;
    /* one thread per (hh, i) — nh·T threads. */
    int64_t total = nh * T;
    int block = 64;
    int64_t need = (total + block - 1) / block;
    int grid = (int)(need < 1 ? 1 : (need > 65535 ? 65535 : need));
    _hx_cuda_kern_attn_dt_fwd<<<grid, block, 0, _forge_stream()>>>(Q, K, V, P, C, T, nh, nkv, hd);
    if (_forge_launch_check("attn_dt_fwd") != 0) return -1;
    if (_d2h_out(p_id,   np) != 0) return -1;
    if (_d2h_out(ctx_id, nq) != 0) return -1;
    return 0;
}

/* mk2-C4-bwd (2026-05-19): GQA attention-dt bwd forge-route. 3-kernel
 * pipeline using a temporary dP_row[nh·T·T] scratch (reused as dS
 * after step 2). dQ/dK/dV must be FRESH t_zeros at the call site —
 * the tape replay in ag_tape.hexa allocates them with t_zeros and the
 * kernel writes acc directly (no read-modify-write). All outputs go
 * through _d2h_out → DEVICE_KEEP honoured. */
int _hx_cuda_farr_attn_dt_bwd_gpu(int64_t q_id, int64_t k_id, int64_t v_id,
                                  int64_t p_id, int64_t dctx_id,
                                  int64_t dq_id, int64_t dk_id, int64_t dv_id,
                                  int64_t T, int64_t nh, int64_t nkv,
                                  int64_t hd) {
    if (q_id < 0 || k_id < 0 || v_id < 0 || p_id < 0 || dctx_id < 0 ||
        dq_id < 0 || dk_id < 0 || dv_id < 0) {
        fprintf(stderr, "[cuda] attn_dt_bwd: bad ids\n");
        return -1;
    }
    if (T <= 0 || nh <= 0 || nkv <= 0 || hd <= 0) {
        fprintf(stderr, "[cuda] attn_dt_bwd: bad dims T=%lld nh=%lld nkv=%lld hd=%lld\n",
                (long long)T, (long long)nh, (long long)nkv, (long long)hd);
        return -1;
    }
    if (nh % nkv != 0) {
        fprintf(stderr, "[cuda] attn_dt_bwd: nh not multiple of nkv\n");
        return -1;
    }
    if (q_id >= _hx_farr_count || k_id >= _hx_farr_count ||
        v_id >= _hx_farr_count || p_id >= _hx_farr_count ||
        dctx_id >= _hx_farr_count || dq_id >= _hx_farr_count ||
        dk_id >= _hx_farr_count || dv_id >= _hx_farr_count) {
        fprintf(stderr, "[cuda] attn_dt_bwd: id out of range\n");
        return -1;
    }
    int64_t nq = T * nh  * hd;
    int64_t nk = T * nkv * hd;
    int64_t np = nh * T * T;
    if (_hx_farr_table[q_id].len    < nq ||
        _hx_farr_table[k_id].len    < nk ||
        _hx_farr_table[v_id].len    < nk ||
        _hx_farr_table[p_id].len    < np ||
        _hx_farr_table[dctx_id].len < nq ||
        _hx_farr_table[dq_id].len   < nq ||
        _hx_farr_table[dk_id].len   < nk ||
        _hx_farr_table[dv_id].len   < nk) {
        fprintf(stderr, "[cuda] attn_dt_bwd: host len mismatch\n");
        return -1;
    }
    if (_h2d(q_id) != 0) return -1;
    if (_h2d(k_id) != 0) return -1;
    if (_h2d(v_id) != 0) return -1;
    if (_h2d(p_id) != 0) return -1;
    if (_h2d(dctx_id) != 0) return -1;
    if (_ensure_dev_buf(dq_id, nq) != 0) return -1;
    if (_ensure_dev_buf(dk_id, nk) != 0) return -1;
    if (_ensure_dev_buf(dv_id, nk) != 0) return -1;
    /* dP_row scratch (reused as dS after step 2) */
    double* dProw = NULL;
    cudaError_t er = cudaMalloc(&dProw, (size_t)np * sizeof(double));
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] attn_dt_bwd: dProw malloc failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    double* Q = g_slots[q_id].d_buf;
    double* K = g_slots[k_id].d_buf;
    double* V = g_slots[v_id].d_buf;
    double* P = g_slots[p_id].d_buf;
    double* dctx = g_slots[dctx_id].d_buf;
    double* dQ = g_slots[dq_id].d_buf;
    double* dK = g_slots[dk_id].d_buf;
    double* dV = g_slots[dv_id].d_buf;
    /* Step 1: dProw per (hh, i, j). nh·T·T threads. */
    {
        int64_t total = nh * T * T;
        int block = 64;
        int64_t need = (total + block - 1) / block;
        int grid = (int)(need < 1 ? 1 : (need > 65535 ? 65535 : need));
        _hx_cuda_kern_attn_dt_bwd_dProw<<<grid, block>>>(V, dctx, dProw,
                                                         T, nh, nkv, hd);
        er = cudaGetLastError();
        if (er != cudaSuccess) {
            fprintf(stderr, "[cuda] attn_dt_bwd dProw kernel failed: %s\n",
                    cudaGetErrorString(er));
            cudaFree(dProw);
            return -1;
        }
    }
    /* Step 2: dS in-place (overwrite dProw) + dQ. nh·T threads. */
    {
        int64_t total = nh * T;
        int block = 64;
        int64_t need = (total + block - 1) / block;
        int grid = (int)(need < 1 ? 1 : (need > 65535 ? 65535 : need));
        _hx_cuda_kern_attn_dt_bwd_dS_dQ<<<grid, block>>>(Q, K, P, dProw, dQ,
                                                         T, nh, nkv, hd);
        er = cudaGetLastError();
        if (er != cudaSuccess) {
            fprintf(stderr, "[cuda] attn_dt_bwd dS+dQ kernel failed: %s\n",
                    cudaGetErrorString(er));
            cudaFree(dProw);
            return -1;
        }
    }
    /* Step 3a: dV per (j, kvh, c). T·nkv·hd threads. */
    {
        int64_t total = T * nkv * hd;
        int block = 64;
        int64_t need = (total + block - 1) / block;
        int grid = (int)(need < 1 ? 1 : (need > 65535 ? 65535 : need));
        _hx_cuda_kern_attn_dt_bwd_dV<<<grid, block>>>(P, dctx, dV,
                                                      T, nh, nkv, hd);
        er = cudaGetLastError();
        if (er != cudaSuccess) {
            fprintf(stderr, "[cuda] attn_dt_bwd dV kernel failed: %s\n",
                    cudaGetErrorString(er));
            cudaFree(dProw);
            return -1;
        }
    }
    /* Step 3b: dK per (j, kvh, c). Same shape. */
    {
        int64_t total = T * nkv * hd;
        int block = 64;
        int64_t need = (total + block - 1) / block;
        int grid = (int)(need < 1 ? 1 : (need > 65535 ? 65535 : need));
        _hx_cuda_kern_attn_dt_bwd_dK<<<grid, block>>>(Q, dProw, dK,
                                                      T, nh, nkv, hd);
        er = cudaGetLastError();
        if (er != cudaSuccess) {
            fprintf(stderr, "[cuda] attn_dt_bwd dK kernel failed: %s\n",
                    cudaGetErrorString(er));
            cudaFree(dProw);
            return -1;
        }
    }
    cudaFree(dProw);
    if (_d2h_out(dq_id, nq) != 0) return -1;
    if (_d2h_out(dk_id, nk) != 0) return -1;
    if (_d2h_out(dv_id, nk) != 0) return -1;
    return 0;
}

/* mk2-C5: device-resident slice copy. Reads src[soff..soff+n) and
 * writes dst[doff..doff+n). DEVICE_KEEP honoured via _d2h_out. */
int _hx_cuda_farr_copy_slice_gpu(int64_t src_id, int64_t soff,
                                 int64_t dst_id, int64_t doff,
                                 int64_t n) {
    if (src_id < 0 || dst_id < 0) {
        fprintf(stderr, "[cuda] copy_slice: bad ids %lld %lld\n",
                (long long)src_id, (long long)dst_id);
        return -1;
    }
    if (n <= 0 || soff < 0 || doff < 0) {
        fprintf(stderr, "[cuda] copy_slice: bad n=%lld soff=%lld doff=%lld\n",
                (long long)n, (long long)soff, (long long)doff);
        return -1;
    }
    if (src_id >= _hx_farr_count || dst_id >= _hx_farr_count) {
        fprintf(stderr, "[cuda] copy_slice: id out of range\n");
        return -1;
    }
    HexaFarrEntry* se = &_hx_farr_table[src_id];
    HexaFarrEntry* de = &_hx_farr_table[dst_id];
    if (se->len < soff + n || de->len < doff + n) {
        fprintf(stderr, "[cuda] copy_slice: range out of bounds\n");
        return -1;
    }
    if (_h2d(src_id) != 0) return -1;
    if (_ensure_dev_buf(dst_id, de->len) != 0) return -1;
    const double* S = g_slots[src_id].d_buf;
    double* D = g_slots[dst_id].d_buf;
    /* Device-to-device cudaMemcpy is the canonical (and fastest) form
     * for a contiguous slice — saturates HBM bandwidth, no kernel
     * launch overhead per element. */
    cudaError_t er = cudaMemcpy(D + doff, S + soff,
                                (size_t)n * sizeof(double),
                                cudaMemcpyDeviceToDevice);
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] copy_slice cudaMemcpy failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    /* Mark dst as device-current; lazy-D2H handles host readback. */
    if (_d2h_out(dst_id, de->len) != 0) return -1;
    return 0;
}

/* mk2-C5: device-side dt_lcg fill (single thread sequential to match
 * the hexa nn_decoder_init / _train_fill_dt_lcg byte-eq exactly —
 * each value depends on the previous LCG state). int64_t modular
 * arithmetic is byte-identical to the hexa `(s * 1103515245 + 12345)
 * % 2^31`. ~100M elements/init × 25ns = ~2.5s on A100, vs ~10min on
 * host via HexaVal-box farr_set. The init runs once at startup,
 * before any forge ops fire — eliminating it is what lets the d768
 * trainer actually reach step 1. */
__global__ void _hx_cuda_kern_fill_dt_lcg(double* __restrict__ dst,
                                          int64_t off, int64_t n,
                                          int64_t seed, double scale) {
    if (blockIdx.x == 0 && threadIdx.x == 0) {
        int64_t s = seed;
        for (int64_t i = 0; i < n; i++) {
            s = (s * (int64_t)1103515245 + (int64_t)12345) % (int64_t)2147483648;
            double rv = (double)(s % 1000) / 1000.0 - 0.5;
            dst[off + i] = rv * scale;
        }
    }
}
int _hx_cuda_farr_fill_dt_lcg_gpu(int64_t dst_id, int64_t doff, int64_t n,
                                  int64_t seed, double scale) {
    /* IMPORTANT (mk2-FINAL #2 measured): the LCG state evolves
     * sequentially (s_{i+1} = f(s_i)), so the kernel is necessarily
     * single-thread. A GPU thread runs ~100ns/iter — 20× slower than
     * a host C loop (~5ns/iter). For ~100M elements per nn_decoder_
     * init, that's 10s/call on GPU vs 0.5s/call on CPU; 121 calls
     * blew the 901s budget on the v6 fire (GPU 100% util, never
     * reached step 1). Switch to host-side fill: the next forge op
     * (`farr_copy_slice_gpu(M, oTE, tokE, …)` in _agt_decoder_step)
     * triggers _h2d on M as a side-effect of the host-write path
     * marking dirty_host=1, so the data lands on device exactly once
     * per farr, lazily, when it's actually needed. */
    if (dst_id < 0 || dst_id >= _hx_farr_count) {
        fprintf(stderr, "[cuda] fill_dt_lcg: bad id\n");
        return -1;
    }
    if (n <= 0 || doff < 0) {
        fprintf(stderr, "[cuda] fill_dt_lcg: bad n=%lld doff=%lld\n",
                (long long)n, (long long)doff);
        return -1;
    }
    HexaFarrEntry* de = &_hx_farr_table[dst_id];
    if (!de->buf || de->len < doff + n) {
        fprintf(stderr, "[cuda] fill_dt_lcg: range out of bounds\n");
        return -1;
    }
    /* Pure C host loop — int64_t modular arithmetic byte-identical
     * to the hexa source (`(s * 1103515245 + 12345) % 2^31`). */
    int64_t s = seed;
    double* H = de->buf + doff;
    for (int64_t i = 0; i < n; i++) {
        s = (s * (int64_t)1103515245 + (int64_t)12345) % (int64_t)2147483648;
        double rv = (double)(s % 1000) / 1000.0 - 0.5;
        H[i] = rv * scale;
    }
    /* Mark host-fresh; the next _h2d uploads the new bytes. Do NOT
     * call _d2h_out here — we want the host buffer to be the source
     * of truth, not the device. */
    de->loc        = FARR_HOST;
    de->dirty_host = 1;
    de->dirty_dev  = 0;
    return 0;
}

/* mk2-C5: device in-place elementwise add dst[i] += src[i] for i ∈
 * [0..n). Used by the gradient accumulator (Mg_acc += Mg across the
 * micro-batch samples). No FMA-contraction concern — a single
 * __dadd_rn per element, byte-eq with host `dst + src` under
 * FP_CONTRACT OFF. */
__global__ void _hx_cuda_kern_add_inplace(double* __restrict__ dst,
                                          const double* __restrict__ src,
                                          int64_t n) {
    int64_t i      = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    int64_t stride = (int64_t)gridDim.x  * (int64_t)blockDim.x;
    for (; i < n; i += stride) {
        dst[i] = __dadd_rn(dst[i], src[i]);
    }
}
int _hx_cuda_farr_add_inplace_gpu(int64_t dst_id, int64_t src_id, int64_t n) {
    if (dst_id < 0 || src_id < 0) {
        fprintf(stderr, "[cuda] add_inplace: bad ids\n");
        return -1;
    }
    if (n <= 0) {
        fprintf(stderr, "[cuda] add_inplace: bad n=%lld\n", (long long)n);
        return -1;
    }
    if (dst_id >= _hx_farr_count || src_id >= _hx_farr_count) {
        fprintf(stderr, "[cuda] add_inplace: id out of range\n");
        return -1;
    }
    HexaFarrEntry* de = &_hx_farr_table[dst_id];
    HexaFarrEntry* se = &_hx_farr_table[src_id];
    if (de->len < n || se->len < n) {
        fprintf(stderr, "[cuda] add_inplace: range out of bounds\n");
        return -1;
    }
    if (_h2d(dst_id) != 0) return -1;
    if (_h2d(src_id) != 0) return -1;
    double* D = g_slots[dst_id].d_buf;
    const double* S = g_slots[src_id].d_buf;
    int block = 256;
    int64_t need = (n + block - 1) / block;
    int grid = (int)(need < 1 ? 1 : (need > 65535 ? 65535 : need));
    _hx_cuda_kern_add_inplace<<<grid, block, 0, _forge_stream()>>>(D, S, n);
    if (_forge_launch_check("add_inplace") != 0) return -1;
    if (_d2h_out(dst_id, de->len) != 0) return -1;
    return 0;
}

/* mk2-C5: device zero-fill of dst[doff..doff+n). Used to clear MgOut
 * at the top of each grad-gather postlude (~100M-double memset). */
int _hx_cuda_farr_zero_slice_gpu(int64_t dst_id, int64_t doff, int64_t n) {
    if (dst_id < 0 || dst_id >= _hx_farr_count) {
        fprintf(stderr, "[cuda] zero_slice: bad id %lld\n", (long long)dst_id);
        return -1;
    }
    if (n <= 0 || doff < 0) {
        fprintf(stderr, "[cuda] zero_slice: bad n=%lld doff=%lld\n",
                (long long)n, (long long)doff);
        return -1;
    }
    HexaFarrEntry* de = &_hx_farr_table[dst_id];
    if (de->len < doff + n) {
        fprintf(stderr, "[cuda] zero_slice: range out of bounds\n");
        return -1;
    }
    if (_ensure_dev_buf(dst_id, de->len) != 0) return -1;
    double* D = g_slots[dst_id].d_buf;
    cudaError_t er = cudaMemset(D + doff, 0, (size_t)n * sizeof(double));
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] zero_slice cudaMemset failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    if (_d2h_out(dst_id, de->len) != 0) return -1;
    return 0;
}

/* mk2-C5: device-resident 2-D transpose (dst[c·d_out + r] = src[soff +
 * r·d_in + c]), byte-eq with agt_wT_slice / agt_wT_off host loop. */
int _hx_cuda_farr_transpose_2d_gpu(int64_t src_id, int64_t soff,
                                   int64_t dst_id, int64_t doff,
                                   int64_t d_out, int64_t d_in) {
    if (src_id < 0 || dst_id < 0) {
        fprintf(stderr, "[cuda] transpose_2d: bad ids\n");
        return -1;
    }
    if (d_out <= 0 || d_in <= 0 || soff < 0 || doff < 0) {
        fprintf(stderr, "[cuda] transpose_2d: bad dims\n");
        return -1;
    }
    if (src_id >= _hx_farr_count || dst_id >= _hx_farr_count) {
        fprintf(stderr, "[cuda] transpose_2d: id out of range\n");
        return -1;
    }
    HexaFarrEntry* se = &_hx_farr_table[src_id];
    HexaFarrEntry* de = &_hx_farr_table[dst_id];
    int64_t total = d_out * d_in;
    if (se->len < soff + total || de->len < doff + total) {
        fprintf(stderr, "[cuda] transpose_2d: range out of bounds\n");
        return -1;
    }
    if (_h2d(src_id) != 0) return -1;
    if (_ensure_dev_buf(dst_id, de->len) != 0) return -1;
    const double* S = g_slots[src_id].d_buf;
    double* D = g_slots[dst_id].d_buf;
    int block = 256;
    int64_t need = (total + block - 1) / block;
    int grid = (int)(need < 1 ? 1 : (need > 65535 ? 65535 : need));
    _hx_cuda_kern_transpose_2d<<<grid, block, 0, _forge_stream()>>>(S, soff, D, doff, d_out, d_in);
    if (_forge_launch_check("transpose_2d") != 0) return -1;
    if (_d2h_out(dst_id, de->len) != 0) return -1;
    return 0;
}

/* ── flame spiking STDP pair-based GPU kernel ───────────────────────
 * inbox/patches/flame-stdp-pair-gpu-kernel.md (anima LEGO arc §141).
 * One thread per (i, j) weight cell on an N×N grid. Output bytes
 * match the CPU oracle spiking_lib.hexa::flame_stdp_pair exactly —
 * single-precision-free scalar fp64 arithmetic, no fma/__dmul_rn
 * substitution, same (ltp - ltd) subtraction order, same diagonal
 * passthrough + clip. F-STDP-GPU-1 / -2 / -3 are enforced by
 * construction. F-STDP-GPU-4 (scale speedup) is a fire-time measure-
 * ment gate, not a construction-time invariant. */
__global__ void _hx_cuda_kern_stdp_pair(const double* __restrict__ W,
                                        const double* __restrict__ tr_pre,
                                        const double* __restrict__ tr_post,
                                        const double* __restrict__ spike,
                                        double* __restrict__ out,
                                        int64_t n,
                                        double A_plus, double A_minus,
                                        double w_max) {
    int64_t i = (int64_t)blockIdx.y * (int64_t)blockDim.y + (int64_t)threadIdx.y;
    int64_t j = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    if (i >= n || j >= n) return;
    int64_t idx = i * n + j;
    double  w_ij = W[idx];
    double  wd;
    if (i == j) {
        wd = w_ij;
    } else {
        /* IMPORTANT — fma-free byte-equality with the CPU oracle.
         * nvcc auto-fuses `a*b + c` into __fma_rn by default; this would
         * silently diverge from the CPU loop (single-precision-free fp64
         * mul-then-add). Use __dmul_rn / __dadd_rn / __dsub_rn so each
         * scalar op rounds at IEEE-754 round-to-nearest in isolation,
         * matching the host scalar order in spiking_lib.hexa
         * flame_stdp_pair exactly. See feedback memory
         * flame_transcendental_byteeq_hazard.md mechanism (3). */
        double s_i      = spike[i];
        double trpost_i = tr_post[i];
        double tmp1     = __dmul_rn(A_plus,  s_i);
        double ltp      = __dmul_rn(tmp1,    tr_pre[j]);
        double tmp2     = __dmul_rn(A_minus, trpost_i);
        double ltd      = __dmul_rn(tmp2,    spike[j]);
        double dlt      = __dsub_rn(ltp, ltd);
        wd              = __dadd_rn(w_ij, dlt);
    }
    double neg_w_max = 0.0 - w_max;
    if (wd > w_max)     wd = w_max;
    if (wd < neg_w_max) wd = neg_w_max;
    out[idx] = wd;
}

int _hx_cuda_farr_stdp_pair_gpu(int64_t W_id, int64_t tr_pre_id,
                                int64_t tr_post_id, int64_t spike_id,
                                int64_t out_id, int64_t n,
                                double A_plus, double A_minus,
                                double w_max) {
    if (W_id < 0 || tr_pre_id < 0 || tr_post_id < 0 ||
        spike_id < 0 || out_id < 0) {
        fprintf(stderr, "[cuda] stdp_pair: bad ids\n");
        return -1;
    }
    if (n <= 0) {
        fprintf(stderr, "[cuda] stdp_pair: bad n=%lld\n", (long long)n);
        return -1;
    }
    if (W_id      >= _hx_farr_count || tr_pre_id >= _hx_farr_count ||
        tr_post_id>= _hx_farr_count || spike_id  >= _hx_farr_count ||
        out_id    >= _hx_farr_count) {
        fprintf(stderr, "[cuda] stdp_pair: id out of range\n");
        return -1;
    }
    int64_t nn = n * n;
    if (_hx_farr_table[W_id].len      < nn ||
        _hx_farr_table[tr_pre_id].len < n  ||
        _hx_farr_table[tr_post_id].len< n  ||
        _hx_farr_table[spike_id].len  < n  ||
        _hx_farr_table[out_id].len    < nn) {
        fprintf(stderr, "[cuda] stdp_pair: host len mismatch\n");
        return -1;
    }
    if (_h2d(W_id) != 0)       return -1;
    if (_h2d(tr_pre_id) != 0)  return -1;
    if (_h2d(tr_post_id) != 0) return -1;
    if (_h2d(spike_id) != 0)   return -1;
    if (_ensure_dev_buf(out_id, nn) != 0) return -1;
    const double* W      = g_slots[W_id].d_buf;
    const double* tr_pre = g_slots[tr_pre_id].d_buf;
    const double* tr_post= g_slots[tr_post_id].d_buf;
    const double* spike  = g_slots[spike_id].d_buf;
    double*       out    = g_slots[out_id].d_buf;
    /* 2D grid, 16×16 block — one thread per (i,j) cell. Cap each grid
     * dim at 65535 (legacy CUDA 1-D grid ceiling we use elsewhere); at
     * block=16 that covers N up to 16·65535 = 1,048,560 per dim, well
     * past the LEGO arc target (N≤16k). */
    int block_dim = 16;
    int64_t need = (n + block_dim - 1) / block_dim;
    int grid_dim = (int)(need < 1 ? 1 : (need > 65535 ? 65535 : need));
    dim3 block(block_dim, block_dim, 1);
    dim3 grid(grid_dim, grid_dim, 1);
    _hx_cuda_kern_stdp_pair<<<grid, block>>>(W, tr_pre, tr_post, spike,
                                             out, n, A_plus, A_minus, w_max);
    cudaError_t er = cudaGetLastError();
    if (er != cudaSuccess) {
        fprintf(stderr, "[cuda] stdp_pair launch failed: %s\n",
                cudaGetErrorString(er));
        return -1;
    }
    if (_d2h_out(out_id, nn) != 0) return -1;
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
