/* tool/cuda_test_farr_elementwise.cu — RFC 041 Phase B falsifier battery
 *
 * Standalone self-contained CUDA test that compiles independently of the
 * full hexa-lang runtime. Mirrors the 5 elementwise kernels added to
 * `self/cuda/runtime_cuda.c` (Phase 4-D-5-2) and runs them against a CPU
 * reference computed in-process. Reports max |Δ| per op + an EQ verdict.
 *
 * Falsifiers (RFC 041 §"Falsifier battery"):
 *   F-RFC041-ADD-EXACT     |Δ| == 0 (bit-exact, no reduction)
 *   F-RFC041-SCALE-EXACT   |Δ| == 0
 *   F-RFC041-MUL-EXACT     |Δ| == 0
 *   F-RFC041-SILU-EQ       |Δ| < TOL_ELEM    (f64 exp ULP — accept ≤4e-15 rel)
 *   F-RFC041-SILU-GRAD-EQ  |Δ| < TOL_ELEM
 *
 * Determinism (F-RFC041-DETERMINISM): each op run twice → second-run
 * cudaMemcmp against first run reports `det_bytes_equal`.
 *
 * NO-CUDA fallback (F-RFC041-NO-CUDA-FALLBACK): this TU compiles only
 * with HEXA_CUDA=1 + nvcc; the Mac no-CUDA build is unchanged (this file
 * is not part of the default link line — vast.ai/CUDA-host only).
 *
 * Honest scope:
 *   - Tests the math contract of the kernels, NOT the full
 *     `_hx_cuda_farr_*_gpu` dispatch path (which threads through the
 *     `_hx_farr_table` mirror — that wiring verify is Phase 4-D-5-3 on
 *     the host runtime build).
 *   - fp64 only (matches RFC 041 elementwise scope).
 *   - n=4096 default — large enough to exercise grid-stride
 *     (block=256 → 16 blocks) yet trivial wall-time.
 *
 * Build (CUDA host, vast.ai):
 *   nvcc -arch=sm_80 -O2 -o cuda_test_farr_elementwise \
 *        tool/cuda_test_farr_elementwise.cu
 * Run:
 *   ./cuda_test_farr_elementwise
 *
 * Exit code: 0 ALL-PASS, non-zero on any falsifier FAIL.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <cuda_runtime.h>

#define CK(call) do { \
    cudaError_t _e = (call); \
    if (_e != cudaSuccess) { \
        fprintf(stderr, "[T] CUDA %s:%d %s\n", \
                __FILE__, __LINE__, cudaGetErrorString(_e)); \
        exit(2); \
    } \
} while (0)

/* ── Kernel duplicates (must mirror runtime_cuda.c EXACTLY) ───────── */

#define _ELEM_BLOCK 256

__global__ void k_add(const double* __restrict__ A,
                      const double* __restrict__ B,
                      double* __restrict__ C, int64_t n) {
    int64_t i      = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    int64_t stride = (int64_t)gridDim.x  * (int64_t)blockDim.x;
    for (; i < n; i += stride) C[i] = A[i] + B[i];
}

__global__ void k_scale(const double* __restrict__ X, double alpha,
                        double* __restrict__ Y, int64_t n) {
    int64_t i      = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    int64_t stride = (int64_t)gridDim.x  * (int64_t)blockDim.x;
    for (; i < n; i += stride) Y[i] = alpha * X[i];
}

__global__ void k_mul(const double* __restrict__ A,
                      const double* __restrict__ B,
                      double* __restrict__ C, int64_t n) {
    int64_t i      = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    int64_t stride = (int64_t)gridDim.x  * (int64_t)blockDim.x;
    for (; i < n; i += stride) C[i] = A[i] * B[i];
}

__device__ __forceinline__ double sig_d(double x) {
    return 1.0 / (1.0 + exp(-x));
}

__global__ void k_silu(const double* __restrict__ X,
                       double* __restrict__ Y, int64_t n) {
    int64_t i      = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    int64_t stride = (int64_t)gridDim.x  * (int64_t)blockDim.x;
    for (; i < n; i += stride) { double xi = X[i]; Y[i] = xi * sig_d(xi); }
}

__global__ void k_silu_grad(const double* __restrict__ X,
                            double* __restrict__ Y, int64_t n) {
    int64_t i      = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    int64_t stride = (int64_t)gridDim.x  * (int64_t)blockDim.x;
    for (; i < n; i += stride) {
        double xi = X[i];
        double s  = sig_d(xi);
        Y[i] = s * (1.0 + xi * (1.0 - s));
    }
}

/* ── CPU oracles (must mirror self/runtime.c _hx_farr_*_cpu EXACTLY) ── */

static inline double sig_h(double x) { return 1.0 / (1.0 + exp(-x)); }

static void cpu_add(const double* A, const double* B, double* C, int64_t n) {
    for (int64_t i = 0; i < n; i++) C[i] = A[i] + B[i];
}
static void cpu_scale(const double* X, double alpha, double* Y, int64_t n) {
    for (int64_t i = 0; i < n; i++) Y[i] = alpha * X[i];
}
static void cpu_mul(const double* A, const double* B, double* C, int64_t n) {
    for (int64_t i = 0; i < n; i++) C[i] = A[i] * B[i];
}
static void cpu_silu(const double* X, double* Y, int64_t n) {
    for (int64_t i = 0; i < n; i++) { double xi = X[i]; Y[i] = xi * sig_h(xi); }
}
static void cpu_silu_grad(const double* X, double* Y, int64_t n) {
    for (int64_t i = 0; i < n; i++) {
        double xi = X[i]; double s = sig_h(xi);
        Y[i] = s * (1.0 + xi * (1.0 - s));
    }
}

/* ── LCG (deterministic, matches the d_determinism.cu pattern) ───── */

static double lcg_next(uint64_t* st) {
    *st = (*st) * 6364136223846793005ULL + 1442695040888963407ULL;
    return (double)(((*st) >> 11) & 0x1FFFFFFFFFFFFFULL) / (double)(1ULL << 53);
}

/* ── Diff metrics ──────────────────────────────────────────────────── */

static double max_abs_diff(const double* a, const double* b, int64_t n) {
    double m = 0.0;
    for (int64_t i = 0; i < n; i++) {
        double d = fabs(a[i] - b[i]);
        if (d > m) m = d;
    }
    return m;
}

static int byte_equal(const double* a, const double* b, int64_t n) {
    return memcmp(a, b, (size_t)n * sizeof(double)) == 0;
}

/* ── Falsifier runner ──────────────────────────────────────────────── */

static int g_fail = 0;

static void report(const char* tag, double max_diff, double tol,
                   int byte_eq_required, int byte_eq_actual,
                   int det_byte_eq) {
    int eq_ok  = (byte_eq_required ? byte_eq_actual : 1);
    int tol_ok = (max_diff <= tol);
    int det_ok = det_byte_eq;
    int pass = eq_ok && tol_ok && det_ok;
    printf("[%s] max|Δ|=%.3e tol=%.3e byte_eq=%d (req=%d) det_byte_eq=%d => %s\n",
           tag, max_diff, tol, byte_eq_actual, byte_eq_required, det_byte_eq,
           pass ? "PASS" : "FAIL");
    if (!pass) g_fail++;
}

int main(int argc, char** argv) {
    int64_t n = 4096;
    if (argc > 1) {
        long parsed = strtol(argv[1], NULL, 10);
        if (parsed > 0) n = (int64_t)parsed;
    }
    int grid = (int)((n + _ELEM_BLOCK - 1) / _ELEM_BLOCK);
    if (grid < 1)     grid = 1;
    if (grid > 65535) grid = 65535;

    /* Generate input — small spread to keep silu_grad within reasonable range. */
    double* hA = (double*)malloc((size_t)n * sizeof(double));
    double* hB = (double*)malloc((size_t)n * sizeof(double));
    double* hC_cpu = (double*)malloc((size_t)n * sizeof(double));
    double* hC_gpu = (double*)malloc((size_t)n * sizeof(double));
    double* hC_gpu2= (double*)malloc((size_t)n * sizeof(double));
    if (!hA || !hB || !hC_cpu || !hC_gpu || !hC_gpu2) {
        fprintf(stderr, "[T] host malloc failed\n");
        return 2;
    }
    uint64_t s1 = 0x1234567890abcdefULL;
    uint64_t s2 = 0xfedcba0987654321ULL;
    for (int64_t i = 0; i < n; i++) {
        hA[i] = (lcg_next(&s1) - 0.5) * 4.0;  /* uniform [-2, 2] */
        hB[i] = (lcg_next(&s2) - 0.5) * 4.0;
    }
    double alpha = 0.3141592653589793;

    double *dA = NULL, *dB = NULL, *dC = NULL, *dD = NULL;
    CK(cudaMalloc(&dA, (size_t)n * sizeof(double)));
    CK(cudaMalloc(&dB, (size_t)n * sizeof(double)));
    CK(cudaMalloc(&dC, (size_t)n * sizeof(double)));
    CK(cudaMalloc(&dD, (size_t)n * sizeof(double)));
    CK(cudaMemcpy(dA, hA, (size_t)n * sizeof(double), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB, hB, (size_t)n * sizeof(double), cudaMemcpyHostToDevice));

    const double TOL_EXACT = 0.0;
    const double TOL_ELEM  = 4e-15;  /* fp64 exp typically ~1 ULP rel; abs ≤4e-15
                                       across [-2,2] silu/silu_grad range */

    /* ── F-RFC041-ADD-EXACT ─────────────────────────────────────────── */
    cpu_add(hA, hB, hC_cpu, n);
    k_add<<<grid, _ELEM_BLOCK>>>(dA, dB, dC, n);
    CK(cudaGetLastError());
    CK(cudaMemcpy(hC_gpu, dC, (size_t)n * sizeof(double), cudaMemcpyDeviceToHost));
    k_add<<<grid, _ELEM_BLOCK>>>(dA, dB, dD, n);
    CK(cudaGetLastError());
    CK(cudaMemcpy(hC_gpu2, dD, (size_t)n * sizeof(double), cudaMemcpyDeviceToHost));
    report("F-RFC041-ADD-EXACT", max_abs_diff(hC_cpu, hC_gpu, n),
           TOL_EXACT, 1, byte_equal(hC_cpu, hC_gpu, n),
           byte_equal(hC_gpu, hC_gpu2, n));

    /* ── F-RFC041-SCALE-EXACT ───────────────────────────────────────── */
    cpu_scale(hA, alpha, hC_cpu, n);
    k_scale<<<grid, _ELEM_BLOCK>>>(dA, alpha, dC, n);
    CK(cudaGetLastError());
    CK(cudaMemcpy(hC_gpu, dC, (size_t)n * sizeof(double), cudaMemcpyDeviceToHost));
    k_scale<<<grid, _ELEM_BLOCK>>>(dA, alpha, dD, n);
    CK(cudaGetLastError());
    CK(cudaMemcpy(hC_gpu2, dD, (size_t)n * sizeof(double), cudaMemcpyDeviceToHost));
    report("F-RFC041-SCALE-EXACT", max_abs_diff(hC_cpu, hC_gpu, n),
           TOL_EXACT, 1, byte_equal(hC_cpu, hC_gpu, n),
           byte_equal(hC_gpu, hC_gpu2, n));

    /* ── F-RFC041-MUL-EXACT ─────────────────────────────────────────── */
    cpu_mul(hA, hB, hC_cpu, n);
    k_mul<<<grid, _ELEM_BLOCK>>>(dA, dB, dC, n);
    CK(cudaGetLastError());
    CK(cudaMemcpy(hC_gpu, dC, (size_t)n * sizeof(double), cudaMemcpyDeviceToHost));
    k_mul<<<grid, _ELEM_BLOCK>>>(dA, dB, dD, n);
    CK(cudaGetLastError());
    CK(cudaMemcpy(hC_gpu2, dD, (size_t)n * sizeof(double), cudaMemcpyDeviceToHost));
    report("F-RFC041-MUL-EXACT", max_abs_diff(hC_cpu, hC_gpu, n),
           TOL_EXACT, 1, byte_equal(hC_cpu, hC_gpu, n),
           byte_equal(hC_gpu, hC_gpu2, n));

    /* ── F-RFC041-SILU-EQ ───────────────────────────────────────────── */
    cpu_silu(hA, hC_cpu, n);
    k_silu<<<grid, _ELEM_BLOCK>>>(dA, dC, n);
    CK(cudaGetLastError());
    CK(cudaMemcpy(hC_gpu, dC, (size_t)n * sizeof(double), cudaMemcpyDeviceToHost));
    k_silu<<<grid, _ELEM_BLOCK>>>(dA, dD, n);
    CK(cudaGetLastError());
    CK(cudaMemcpy(hC_gpu2, dD, (size_t)n * sizeof(double), cudaMemcpyDeviceToHost));
    report("F-RFC041-SILU-EQ", max_abs_diff(hC_cpu, hC_gpu, n),
           TOL_ELEM, 0, byte_equal(hC_cpu, hC_gpu, n),
           byte_equal(hC_gpu, hC_gpu2, n));

    /* ── F-RFC041-SILU-GRAD-EQ ──────────────────────────────────────── */
    cpu_silu_grad(hA, hC_cpu, n);
    k_silu_grad<<<grid, _ELEM_BLOCK>>>(dA, dC, n);
    CK(cudaGetLastError());
    CK(cudaMemcpy(hC_gpu, dC, (size_t)n * sizeof(double), cudaMemcpyDeviceToHost));
    k_silu_grad<<<grid, _ELEM_BLOCK>>>(dA, dD, n);
    CK(cudaGetLastError());
    CK(cudaMemcpy(hC_gpu2, dD, (size_t)n * sizeof(double), cudaMemcpyDeviceToHost));
    report("F-RFC041-SILU-GRAD-EQ", max_abs_diff(hC_cpu, hC_gpu, n),
           TOL_ELEM, 0, byte_equal(hC_cpu, hC_gpu, n),
           byte_equal(hC_gpu, hC_gpu2, n));

    cudaFree(dA); cudaFree(dB); cudaFree(dC); cudaFree(dD);
    free(hA); free(hB); free(hC_cpu); free(hC_gpu); free(hC_gpu2);

    if (g_fail == 0) {
        printf("\n[T] ALL-PASS — 5/5 falsifiers PASS (n=%lld)\n", (long long)n);
        return 0;
    } else {
        printf("\n[T] FAIL — %d/5 falsifiers FAIL (n=%lld)\n", g_fail, (long long)n);
        return 1;
    }
}
