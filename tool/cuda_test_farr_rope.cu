/* tool/cuda_test_farr_rope.cu — RFC 041 Phase B RoPE falsifier battery
 *
 * Standalone self-contained CUDA test that compiles independently of the
 * full hexa-lang runtime. Mirrors the 2 RoPE kernels added to
 * `self/cuda/runtime_cuda.c` (Phase B completion, 2026-05-17) and runs
 * them against a CPU reference computed in-process. Reports max |Δ| per
 * op + an EQ verdict.
 *
 * RoPE = rotary position embedding. The flame decoder block (RFC 043,
 * stdlib/flame/decoder_block_lib.hexa §3 fwd / §3rev bwd; CPU reference
 * tool/flame_phase4d6_block_{fwd,bwd}_primitive.c) consumes PRECOMPUTED
 * cos/sin tables — the kernel does NOT recompute angles.
 *
 * Falsifiers (RFC 041 §"Falsifier battery"):
 *   F-RFC041-ROPE-EXACT     |Δ| == 0 (bit-exact: per-element rotation,
 *                           two fp64 products + one add, NO reduction)
 *   F-RFC041-ROPE-BWD-EXACT |Δ| == 0 (inverse rotation, same exactness)
 *
 * Determinism (F-RFC041-DETERMINISM): each op run twice → second-run
 * cudaMemcmp against first run reports `det_bytes_equal`.
 *
 * NO-CUDA fallback (F-RFC041-NO-CUDA-FALLBACK): this TU compiles only
 * with nvcc; the Mac no-CUDA build is unchanged (this file is not part
 * of the default link line — vast.ai/CUDA-host only).
 *
 * Honest scope:
 *   - Tests the math contract of the kernels, NOT the full
 *     `_hx_cuda_farr_rope*_gpu` dispatch path (which threads through the
 *     `_hx_farr_table` mirror — that wiring verify folds into the next
 *     d768 fire's byte-eq verification on the host runtime build).
 *   - fp64 only (matches RFC 041 elementwise scope).
 *   - Layout: tensor [T·nheads·hd], cos/sin [T·hd]. Default config
 *     T=128, nheads=12, hd=64 (d768-class shape; total=98304 elements).
 *
 * Build (CUDA host, vast.ai):
 *   nvcc -arch=sm_80 -O2 -o cuda_test_farr_rope \
 *        tool/cuda_test_farr_rope.cu
 * Run:
 *   ./cuda_test_farr_rope
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

#define _ELEM_BLOCK 256

/* ── Kernel duplicates (must mirror runtime_cuda.c EXACTLY) ───────── */

__global__ void k_rope_fwd(const double* __restrict__ X,
                           const double* __restrict__ COS,
                           const double* __restrict__ SIN,
                           double* __restrict__ Y,
                           int64_t T, int64_t nheads, int64_t hd) {
    int64_t total  = T * nheads * hd;
    int64_t half   = hd / 2;
    int64_t i      = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    int64_t stride = (int64_t)gridDim.x  * (int64_t)blockDim.x;
    for (; i < total; i += stride) {
        int64_t c   = i % hd;
        int64_t row = i - c;
        int64_t t   = i / (nheads * hd);
        int64_t bse = t * hd;
        double rh_c = (c < half)
            ? (0.0 - X[row + half + c])
            : X[row + c - half];
        /* __dmul_rn/__dadd_rn — mirror runtime_cuda.c: no FMA
         * contraction, conform to the non-contracted reference. */
        Y[i] = __dadd_rn(__dmul_rn(X[row + c], COS[bse + c]),
                         __dmul_rn(rh_c, SIN[bse + c]));
    }
}

__global__ void k_rope_bwd(const double* __restrict__ DX,
                           const double* __restrict__ COS,
                           const double* __restrict__ SIN,
                           double* __restrict__ Y,
                           int64_t T, int64_t nheads, int64_t hd) {
    int64_t total  = T * nheads * hd;
    int64_t half   = hd / 2;
    int64_t i      = (int64_t)blockIdx.x * (int64_t)blockDim.x + (int64_t)threadIdx.x;
    int64_t stride = (int64_t)gridDim.x  * (int64_t)blockDim.x;
    for (; i < total; i += stride) {
        int64_t c   = i % hd;
        int64_t row = i - c;
        int64_t t   = i / (nheads * hd);
        int64_t bse = t * hd;
        double gs = (c < half)
            ? __dmul_rn(DX[row + half + c], SIN[bse + half + c])
            : (0.0 - __dmul_rn(DX[row + c - half], SIN[bse + c - half]));
        Y[i] = __dadd_rn(__dmul_rn(DX[row + c], COS[bse + c]), gs);
    }
}

/* ── CPU oracles ──────────────────────────────────────────────────────
 * Mirror flame_phase4d6_block_fwd_primitive.c §3 (RoPE pair-rotate,
 * lines 162-167) and flame_phase4d6_block_bwd_primitive.c §3rev
 * (inverse rotation, lines 322-327). The CPU primitive rotates in
 * place via a scratch buffer; here we read X and write a fresh Y, the
 * same data dependence (each Y element reads X[c] + X[c±half]). */

static void cpu_rope_fwd(const double* X, const double* COS,
                         const double* SIN, double* Y,
                         int64_t T, int64_t nheads, int64_t hd) {
    int64_t half = hd / 2;
    for (int64_t t = 0; t < T; t++) {
        int64_t bse = t * hd;
        for (int64_t hh = 0; hh < nheads; hh++) {
            int64_t row = (t * nheads + hh) * hd;
            for (int64_t c = 0; c < hd; c++) {
                double rh_c = (c < half)
                    ? (0.0 - X[row + half + c])
                    : X[row + c - half];
                Y[row + c] = X[row + c] * COS[bse + c]
                           + rh_c * SIN[bse + c];
            }
        }
    }
}

static void cpu_rope_bwd(const double* DX, const double* COS,
                         const double* SIN, double* Y,
                         int64_t T, int64_t nheads, int64_t hd) {
    int64_t half = hd / 2;
    for (int64_t t = 0; t < T; t++) {
        int64_t bse = t * hd;
        for (int64_t hh = 0; hh < nheads; hh++) {
            int64_t row = (t * nheads + hh) * hd;
            for (int64_t c = 0; c < hd; c++) {
                double gs = (c < half)
                    ? (DX[row + half + c] * SIN[bse + half + c])
                    : (0.0 - DX[row + c - half] * SIN[bse + c - half]);
                Y[row + c] = DX[row + c] * COS[bse + c] + gs;
            }
        }
    }
}

/* ── LCG (deterministic, matches cuda_test_farr_elementwise.cu) ───── */

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
    /* Config: T positions, nheads heads, hd head-dim (even). */
    int64_t T = 128, nheads = 12, hd = 64;
    if (argc > 1) { long p = strtol(argv[1], NULL, 10); if (p > 0) T = p; }
    if (argc > 2) { long p = strtol(argv[2], NULL, 10); if (p > 0) nheads = p; }
    if (argc > 3) { long p = strtol(argv[3], NULL, 10); if (p > 1) hd = (p & 1) ? p - 1 : p; }

    int64_t total = T * nheads * hd;   /* tensor element count */
    int64_t cslen = T * hd;            /* cos/sin table element count */

    int grid = (int)((total + _ELEM_BLOCK - 1) / _ELEM_BLOCK);
    if (grid < 1)     grid = 1;
    if (grid > 65535) grid = 65535;

    printf("[T] RoPE test — T=%lld nheads=%lld hd=%lld (total=%lld, cos/sin=%lld)\n",
           (long long)T, (long long)nheads, (long long)hd,
           (long long)total, (long long)cslen);

    double* hX     = (double*)malloc((size_t)total * sizeof(double));
    double* hCOS   = (double*)malloc((size_t)cslen * sizeof(double));
    double* hSIN   = (double*)malloc((size_t)cslen * sizeof(double));
    double* hY_cpu = (double*)malloc((size_t)total * sizeof(double));
    double* hY_gpu = (double*)malloc((size_t)total * sizeof(double));
    double* hY_gpu2= (double*)malloc((size_t)total * sizeof(double));
    if (!hX || !hCOS || !hSIN || !hY_cpu || !hY_gpu || !hY_gpu2) {
        fprintf(stderr, "[T] host malloc failed\n");
        return 2;
    }

    /* Tensor input — uniform [-2, 2]. */
    uint64_t s1 = 0x1234567890abcdefULL;
    for (int64_t i = 0; i < total; i++)
        hX[i] = (lcg_next(&s1) - 0.5) * 4.0;

    /* Precomputed cos/sin tables — proper RoPE angle θ = t·base^(-2i/hd)
     * with base=10000, mirroring the flame convention (cos_id/sin_id are
     * caller-precomputed). cos/sin laid out [T·hd]; for coordinate c the
     * pair index is (c mod half) so cos[t·hd + c] = cos(t·freq[c%half]). */
    int64_t half = hd / 2;
    for (int64_t t = 0; t < T; t++) {
        for (int64_t c = 0; c < hd; c++) {
            int64_t pair = c % half;
            double freq  = pow(10000.0, -2.0 * (double)pair / (double)hd);
            double theta = (double)t * freq;
            hCOS[t * hd + c] = cos(theta);
            hSIN[t * hd + c] = sin(theta);
        }
    }

    double *dX = NULL, *dCOS = NULL, *dSIN = NULL, *dY = NULL, *dY2 = NULL;
    CK(cudaMalloc(&dX,   (size_t)total * sizeof(double)));
    CK(cudaMalloc(&dCOS, (size_t)cslen * sizeof(double)));
    CK(cudaMalloc(&dSIN, (size_t)cslen * sizeof(double)));
    CK(cudaMalloc(&dY,   (size_t)total * sizeof(double)));
    CK(cudaMalloc(&dY2,  (size_t)total * sizeof(double)));
    CK(cudaMemcpy(dX,   hX,   (size_t)total * sizeof(double), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dCOS, hCOS, (size_t)cslen * sizeof(double), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dSIN, hSIN, (size_t)cslen * sizeof(double), cudaMemcpyHostToDevice));

    const double TOL_EXACT = 0.0;

    /* ── F-RFC041-ROPE-EXACT ────────────────────────────────────────── */
    cpu_rope_fwd(hX, hCOS, hSIN, hY_cpu, T, nheads, hd);
    k_rope_fwd<<<grid, _ELEM_BLOCK>>>(dX, dCOS, dSIN, dY, T, nheads, hd);
    CK(cudaGetLastError());
    CK(cudaMemcpy(hY_gpu, dY, (size_t)total * sizeof(double), cudaMemcpyDeviceToHost));
    k_rope_fwd<<<grid, _ELEM_BLOCK>>>(dX, dCOS, dSIN, dY2, T, nheads, hd);
    CK(cudaGetLastError());
    CK(cudaMemcpy(hY_gpu2, dY2, (size_t)total * sizeof(double), cudaMemcpyDeviceToHost));
    report("F-RFC041-ROPE-EXACT", max_abs_diff(hY_cpu, hY_gpu, total),
           TOL_EXACT, 1, byte_equal(hY_cpu, hY_gpu, total),
           byte_equal(hY_gpu, hY_gpu2, total));

    /* ── F-RFC041-ROPE-BWD-EXACT ────────────────────────────────────── */
    cpu_rope_bwd(hX, hCOS, hSIN, hY_cpu, T, nheads, hd);
    k_rope_bwd<<<grid, _ELEM_BLOCK>>>(dX, dCOS, dSIN, dY, T, nheads, hd);
    CK(cudaGetLastError());
    CK(cudaMemcpy(hY_gpu, dY, (size_t)total * sizeof(double), cudaMemcpyDeviceToHost));
    k_rope_bwd<<<grid, _ELEM_BLOCK>>>(dX, dCOS, dSIN, dY2, T, nheads, hd);
    CK(cudaGetLastError());
    CK(cudaMemcpy(hY_gpu2, dY2, (size_t)total * sizeof(double), cudaMemcpyDeviceToHost));
    report("F-RFC041-ROPE-BWD-EXACT", max_abs_diff(hY_cpu, hY_gpu, total),
           TOL_EXACT, 1, byte_equal(hY_cpu, hY_gpu, total),
           byte_equal(hY_gpu, hY_gpu2, total));

    /* ── round-trip sanity: bwd(fwd(x)) is NOT identity (the bwd is the
     * transpose, not the inverse) — but fwd then bwd with the SAME
     * cos/sin recovers x ONLY for the rotation-matrix special case.
     * We do not assert it; the two EXACT falsifiers above are the
     * binding correctness anchors. */

    cudaFree(dX); cudaFree(dCOS); cudaFree(dSIN); cudaFree(dY); cudaFree(dY2);
    free(hX); free(hCOS); free(hSIN); free(hY_cpu); free(hY_gpu); free(hY_gpu2);

    if (g_fail == 0) {
        printf("\n[T] ALL-PASS — 2/2 RoPE falsifiers PASS "
               "(T=%lld nheads=%lld hd=%lld)\n",
               (long long)T, (long long)nheads, (long long)hd);
        return 0;
    } else {
        printf("\n[T] FAIL — %d/2 RoPE falsifiers FAIL\n", g_fail);
        return 1;
    }
}
