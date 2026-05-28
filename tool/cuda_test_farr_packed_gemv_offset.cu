/* tool/cuda_test_farr_packed_gemv_offset.cu
 *
 * GPU byte-eq oracle for the offset-aware packed gemv builtin
 * `_hx_cuda_farr_packed_gemv_offset_gpu` vs a CPU reference loop.
 *
 *   out[i] = Σ_j P[off + i·cols + j] · U[j]   (anima mm_packed_gemv 1:1)
 *
 * Falsifiers:
 *   F-GEMV-OFFSET-EQ-CPU : gpu Dgemv ≈ CPU reference          (TOL_MATMUL)
 *   F-GEMV-OFFSET-DETERM : rerun byte-identical               (|Δ|=0)
 *   F-GEMV-OFFSET-SLICE  : non-zero off reads the right block (TOL_MATMUL)
 *
 * cuBLAS Dgemv (CUBLAS_OP_T, base+offset ptr, lda=cols) → reduction is
 * cuBLAS-tiled, so TOL_MATMUL ≈ 2e-9 relative (same caveat as matmul_t).
 *
 * Build (on GPU host):
 *   nvcc -O2 -std=c++14 -DHEXA_CUDA -gencode arch=compute_<CC>,code=compute_<CC> \
 *       -x cu runtime_cuda.c cuda_test_farr_packed_gemv_offset.cu \
 *       -lcublas -lcudart -lcuda -lm -o test_gemv_offset
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

typedef struct {
    double*  buf;
    int64_t  len;
    void*    d_buf;
    int      loc;
    int      pinned;
    int      dirty_host;
    int      dirty_dev;
} HexaFarrEntry;

#define MOCK_FARR_CAP 1024
static HexaFarrEntry _hx_farr_storage[MOCK_FARR_CAP];
HexaFarrEntry*       _hx_farr_table = _hx_farr_storage;
int64_t              _hx_farr_count = 0;

extern "C" {
    int _hx_cuda_farr_packed_gemv_offset_gpu(int64_t p_id, int64_t off,
                                   int64_t rows, int64_t cols,
                                   int64_t u_id, int64_t out_id);
}

static void cpu_packed_gemv_offset(const double* P, int64_t off,
                                   int64_t rows, int64_t cols,
                                   const double* U, double* O) {
    for (int64_t i = 0; i < rows; i++) {
        double acc = 0.0;
        const double* pr = P + off + i * cols;
        for (int64_t j = 0; j < cols; j++) acc += pr[j] * U[j];
        O[i] = acc;
    }
}

static int64_t alloc_farr(int64_t len) {
    int64_t id = _hx_farr_count++;
    if (id >= MOCK_FARR_CAP) { fprintf(stderr, "[harness] overflow\n"); exit(2); }
    HexaFarrEntry* e = &_hx_farr_table[id];
    e->buf = (double*)calloc((size_t)len, sizeof(double));
    if (!e->buf) { perror("calloc"); exit(2); }
    e->len = len;
    e->d_buf = NULL; e->loc = 0; e->pinned = 0; e->dirty_host = 0; e->dirty_dev = 0;
    return id;
}

static int byte_equal(const double* a, const double* b, int64_t n) {
    return memcmp(a, b, (size_t)n * sizeof(double)) == 0 ? 1 : 0;
}

static double max_rel_diff(const double* got, const double* ref, int64_t n) {
    double m = 0.0;
    for (int64_t i = 0; i < n; i++) {
        double a = fabs(ref[i]);
        double d = fabs(got[i] - ref[i]);
        double r = (a > 1e-30) ? d / a : d;
        if (r > m) m = r;
    }
    return m;
}

#define TOL_MATMUL 2e-9
static int n_pass = 0, n_fail = 0;
static void check(const char* name, int ok, double m, double tol) {
    if (ok) { printf("  PASS  %-32s rel=%.3e (tol %.3e)\n", name, m, tol); n_pass++; }
    else    { printf("  FAIL  %-32s rel=%.3e > tol %.3e\n", name, m, tol); n_fail++; }
}

static void test_gemv(int64_t rows, int64_t cols, int64_t off, int n_blocks) {
    printf("[F-GEMV-OFFSET] rows=%lld cols=%lld off=%lld\n",
           (long long)rows, (long long)cols, (long long)off);
    int64_t block = rows * cols;
    int64_t p_id = alloc_farr((int64_t)n_blocks * block);
    int64_t u_id = alloc_farr(cols);
    int64_t out_id = alloc_farr(rows);
    for (int64_t k = 0; k < (int64_t)n_blocks * block; k++)
        _hx_farr_table[p_id].buf[k] = 0.01 * sin((double)(k + 1) * 0.073) + 0.2;
    for (int64_t j = 0; j < cols; j++)
        _hx_farr_table[u_id].buf[j] = 0.3 - 0.001 * (double)j;

    double* ref = (double*)malloc((size_t)rows * sizeof(double));
    cpu_packed_gemv_offset(_hx_farr_table[p_id].buf, off, rows, cols,
                           _hx_farr_table[u_id].buf, ref);

    int rc = _hx_cuda_farr_packed_gemv_offset_gpu(p_id, off, rows, cols, u_id, out_id);
    if (rc != 0) { printf("  FAIL  launch rc=%d\n", rc); n_fail++; return; }
    double m = max_rel_diff(_hx_farr_table[out_id].buf, ref, rows);
    check("gemv_offset ≈ cpu", m < TOL_MATMUL, m, TOL_MATMUL);

    /* Determinism: rerun, byte-identical. */
    double* run1 = (double*)malloc((size_t)rows * sizeof(double));
    memcpy(run1, _hx_farr_table[out_id].buf, (size_t)rows * sizeof(double));
    rc = _hx_cuda_farr_packed_gemv_offset_gpu(p_id, off, rows, cols, u_id, out_id);
    if (rc != 0) { printf("  FAIL  rerun rc=%d\n", rc); n_fail++; return; }
    int eq = byte_equal(run1, _hx_farr_table[out_id].buf, rows);
    check("gemv_offset rerun byte-eq", eq, eq ? 0.0 : 1.0, 0.0);

    free(ref); free(run1);
}

int main(void) {
    printf("=== farr_packed_gemv_offset GPU byte-eq oracle ===\n");
    /* small (below dim-gate, but the GPU fn is exercised directly here) */
    test_gemv(5, 4, 0, 2);
    test_gemv(5, 4, 20, 2);          /* off = second block */
    /* large — the dominant-expert MoE shape (rows·cols > 8192). */
    test_gemv(2048, 64, 0, 2);       /* 131072 doubles per block */
    test_gemv(2048, 64, 2048 * 64, 2);
    printf("=== SUMMARY: %d PASS / %d FAIL ===\n", n_pass, n_fail);
    return n_fail == 0 ? 0 : 1;
}
