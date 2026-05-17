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

/* Tiny device-side mirror table. Keyed by farr_id (same int handle the
 * runtime.c HexaFarrEntry table uses). Sparse: grows on demand. */
typedef struct {
    double*  d_buf;       /* cudaMalloc'd device pointer, or NULL */
    int64_t  len;         /* element count (must match host len when valid) */
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
    /* zero-init the new tail. */
    for (int64_t i = g_slot_cap; i < new_cap; i++) {
        ns[i].d_buf = NULL;
        ns[i].len   = 0;
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
    if (!e->buf || e->len <= 0) {
        fprintf(stderr, "[cuda] h2d: empty host farr id=%lld\n", (long long)id);
        return -1;
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
    if (s->d_buf) {
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
 * mark MIRRORED/clean. Returns 0 ok / -1 err. */
static int _d2h_out(int64_t id, int64_t len) {
    if (id < 0 || id >= _hx_farr_count) return -1;
    if (id >= g_slot_cap)               return -1;
    HexaFarrEntry* e = &_hx_farr_table[id];
    _CudaFarrSlot* s = &g_slots[id];
    if (!e->buf || !s->d_buf || e->len < len || s->len < len) return -1;
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

#endif /* HEXA_CUDA */
