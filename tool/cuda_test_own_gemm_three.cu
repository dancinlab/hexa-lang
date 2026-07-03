/* tool/cuda_test_own_gemm_three.cu
 *
 * census-r2 micro byte-eq oracle for the three HEXA_OWN_GEMM own-kernel
 * wirings added to runtime_cuda_emit.hexa:
 *
 *   _hx_cuda_farr_matmul_t_gpu          out[1,C] = u[1,R]·M[R,C]   (_hx_k_gemm, M=1)
 *   _hx_cuda_farr_outer_gpu             out[R,C] = u[R]⊗v[C]       (_hx_k_gemm, K=1)
 *   _hx_cuda_farr_packed_gemv_offset_gpu out[i]  = Σ_j P[off+i·cols+j]·U[j]
 *
 * Each launcher reads env HEXA_OWN_GEMM at call time. We run the WHOLE binary
 * twice (driver script): once with HEXA_OWN_GEMM unset (cuBLAS = oracle) and
 * once with HEXA_OWN_GEMM=1 (own kernel). Each run dumps the result vectors to
 * a binary file; the driver byte-diffs the two files for max|Δ|.
 *
 * Within a single run we ALSO check the active path vs a CPU reference loop
 * (rel-RMS) so a launch that silently no-ops is caught.
 *
 * Build (GPU host):
 *   nvcc -O2 -std=c++14 -DHEXA_CUDA -gencode arch=compute_<CC>,code=compute_<CC> \
 *       -x cu runtime_cuda.c cuda_test_own_gemm_three.cu \
 *       -lcublas -lcudart -lcuda -lm -o test_own_gemm_three
 * Run:
 *   ./test_own_gemm_three <dump-path>
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
    int _hx_cuda_farr_matmul_t_gpu(int64_t m_id, int64_t R, int64_t C,
                                   int64_t u_id, int64_t out_id);
    int _hx_cuda_farr_outer_gpu(int64_t u_id, int64_t v_id,
                                int64_t R, int64_t C, int64_t out_id);
    int _hx_cuda_farr_packed_gemv_offset_gpu(int64_t p_id, int64_t off,
                                   int64_t rows, int64_t cols,
                                   int64_t u_id, int64_t out_id);
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
static int n_fail = 0;
static FILE* g_dump = NULL;
static void dump_vec(const double* v, int64_t n) {
    if (g_dump) fwrite(v, sizeof(double), (size_t)n, g_dump);
}
static void report(const char* name, double m, double tol) {
    const char* tag = (m <= tol) ? "PASS" : "FAIL";
    printf("  %s  %-26s rel=%.3e (tol %.3e)\n", tag, name, m, tol);
    if (m > tol) n_fail++;
}

/* ── matmul_t: out[C] = u[R] · M[R,C] (u as row vector) ── */
static void test_matmul_t(int64_t R, int64_t C) {
    int64_t m_id = alloc_farr(R * C);
    int64_t u_id = alloc_farr(R);
    int64_t o_id = alloc_farr(C);
    for (int64_t k = 0; k < R * C; k++)
        _hx_farr_table[m_id].buf[k] = 0.01 * sin((double)(k + 1) * 0.0731) + 0.2;
    for (int64_t i = 0; i < R; i++)
        _hx_farr_table[u_id].buf[i] = 0.3 - 0.0017 * (double)i;
    double* ref = (double*)malloc((size_t)C * sizeof(double));
    for (int64_t c = 0; c < C; c++) {
        double acc = 0.0;
        for (int64_t r = 0; r < R; r++)
            acc += _hx_farr_table[u_id].buf[r] * _hx_farr_table[m_id].buf[r * C + c];
        ref[c] = acc;
    }
    int rc = _hx_cuda_farr_matmul_t_gpu(m_id, R, C, u_id, o_id);
    if (rc != 0) { printf("  FAIL matmul_t launch rc=%d\n", rc); n_fail++; return; }
    double mm = max_rel_diff(_hx_farr_table[o_id].buf, ref, C);
    printf("[matmul_t] R=%lld C=%lld\n", (long long)R, (long long)C);
    report("matmul_t vs cpu", mm, TOL_MATMUL);
    dump_vec(_hx_farr_table[o_id].buf, C);
    free(ref);
}

/* ── outer: out[R,C] = u[R] ⊗ v[C] ── */
static void test_outer(int64_t R, int64_t C) {
    int64_t u_id = alloc_farr(R);
    int64_t v_id = alloc_farr(C);
    int64_t o_id = alloc_farr(R * C);
    for (int64_t i = 0; i < R; i++)
        _hx_farr_table[u_id].buf[i] = 0.3 - 0.0017 * (double)i;
    for (int64_t j = 0; j < C; j++)
        _hx_farr_table[v_id].buf[j] = 0.11 + 0.0023 * (double)j;
    double* ref = (double*)malloc((size_t)(R * C) * sizeof(double));
    for (int64_t i = 0; i < R; i++)
        for (int64_t j = 0; j < C; j++)
            ref[i * C + j] = _hx_farr_table[u_id].buf[i] * _hx_farr_table[v_id].buf[j];
    int rc = _hx_cuda_farr_outer_gpu(u_id, v_id, R, C, o_id);
    if (rc != 0) { printf("  FAIL outer launch rc=%d\n", rc); n_fail++; return; }
    double mm = max_rel_diff(_hx_farr_table[o_id].buf, ref, R * C);
    printf("[outer] R=%lld C=%lld\n", (long long)R, (long long)C);
    report("outer vs cpu (k=1 exact)", mm, 0.0);  /* k=1 → bit-exact expected */
    dump_vec(_hx_farr_table[o_id].buf, R * C);
    free(ref);
}

/* ── packed_gemv_offset ── */
static void test_gemv(int64_t rows, int64_t cols, int64_t off, int n_blocks) {
    int64_t block = rows * cols;
    int64_t p_id = alloc_farr((int64_t)n_blocks * block);
    int64_t u_id = alloc_farr(cols);
    int64_t o_id = alloc_farr(rows);
    for (int64_t k = 0; k < (int64_t)n_blocks * block; k++)
        _hx_farr_table[p_id].buf[k] = 0.01 * sin((double)(k + 1) * 0.073) + 0.2;
    for (int64_t j = 0; j < cols; j++)
        _hx_farr_table[u_id].buf[j] = 0.3 - 0.001 * (double)j;
    double* ref = (double*)malloc((size_t)rows * sizeof(double));
    for (int64_t i = 0; i < rows; i++) {
        double acc = 0.0;
        const double* pr = _hx_farr_table[p_id].buf + off + i * cols;
        for (int64_t j = 0; j < cols; j++) acc += pr[j] * _hx_farr_table[u_id].buf[j];
        ref[i] = acc;
    }
    int rc = _hx_cuda_farr_packed_gemv_offset_gpu(p_id, off, rows, cols, u_id, o_id);
    if (rc != 0) { printf("  FAIL gemv launch rc=%d\n", rc); n_fail++; return; }
    double mm = max_rel_diff(_hx_farr_table[o_id].buf, ref, rows);
    printf("[packed_gemv] rows=%lld cols=%lld off=%lld\n",
           (long long)rows, (long long)cols, (long long)off);
    report("packed_gemv vs cpu", mm, TOL_MATMUL);
    dump_vec(_hx_farr_table[o_id].buf, rows);
    free(ref);
}

int main(int argc, char** argv) {
    const char* own = getenv("HEXA_OWN_GEMM");
    printf("=== own-gemm three micro byte-eq (HEXA_OWN_GEMM=%s) ===\n",
           (own && own[0]) ? own : "(unset → cuBLAS)");
    if (argc > 1) {
        g_dump = fopen(argv[1], "wb");
        if (!g_dump) { perror("fopen dump"); return 2; }
    }
    /* large output dims so packed_gemv would otherwise hit the cuBLAS gate */
    test_matmul_t(512, 768);
    test_outer(384, 512);
    test_gemv(768, 256, 0, 2);          /* rows=768 > MIN_ROWS(512) → cuBLAS gate w/o OWN */
    test_gemv(768, 256, 768 * 256, 2);  /* offset block */
    if (g_dump) fclose(g_dump);
    printf("=== %d FAIL ===\n", n_fail);
    return n_fail == 0 ? 0 : 1;
}
