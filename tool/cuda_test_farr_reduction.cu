/* tool/cuda_test_farr_reduction.cu — RFC 041 Phase 4-D-5-2 byte-eq harness
 *
 * Tests the 6 Phase B reduction + Phase B2 CUDA kernels in
 * `self/cuda/runtime_cuda.c` against their CPU oracles in `self/runtime.c`:
 *
 *   1. _hx_cuda_farr_softmax_rows_gpu      vs _hx_farr_softmax_rows_cpu
 *   2. _hx_cuda_farr_rmsnorm_rows_gpu      vs _hx_farr_rmsnorm_rows_cpu
 *   3. _hx_cuda_farr_rmsnorm_bwd_rows_gpu  vs _hx_farr_rmsnorm_bwd_rows_cpu
 *   4. _hx_cuda_farr_adamw_step_gpu        vs _hx_farr_adamw_step_cpu
 *   5. _hx_cuda_farr_matmul_t_gpu          vs _hx_farr_matmul_t_cpu
 *   6. _hx_cuda_farr_outer_gpu             vs _hx_farr_outer_cpu
 *
 * Build (CUDA host only):
 *   nvcc -O2 -std=c++14 -x cu -DHEXA_CUDA \
 *        self/cuda/runtime_cuda.c tool/cuda_test_farr_reduction.cu \
 *        -lcudart -lcublas -lm -o /tmp/cuda_test_farr_reduction
 *
 * Run:
 *   /tmp/cuda_test_farr_reduction
 *   → prints per-op max|Δ| + PASS/FAIL against F-RFC041-* tolerances.
 *
 * Falsifier coverage (RFC 041 §"Falsifier battery"):
 *   F-RFC041-MATMUL-T-EQ          |Δ| < TOL_MATMUL  (2e-9)
 *   F-RFC041-OUTER-EXACT          |Δ| == 0          (BIT-EXACT)
 *   F-RFC041-SOFTMAX-ROWS-EQ      |Δ| < TOL_ELEM    (1e-12)
 *   F-RFC041-RMSNORM-ROWS-EQ      |Δ| < TOL_ELEM    (1e-12)
 *   F-RFC041-RMSNORM-BWD-ROWS-EQ  |Δ| < TOL_ELEM    (1e-12)
 *   F-RFC041-ADAMW-EQ             |Δ| < TOL_ELEM    (1e-12)
 *   F-RFC041-DETERMINISM          run-twice byte-identical
 *
 * Determinism check runs each kernel twice on the same input and asserts
 * byte-equal outputs (no atomicAdd → run-to-run reproducible).
 *
 * Self-contained: does NOT include self/runtime.c (avoids HexaVal/farr-table
 * dependency for a unit test). Uses a tiny local farr-table mock that
 * matches the HexaFarrEntry / _hx_farr_table / _hx_farr_count contract
 * runtime_cuda.c depends on.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

/* Match the HexaFarrEntry layout runtime_cuda.c uses (see lines 71-79). */
typedef struct {
    double*  buf;
    int64_t  len;
    void*    d_buf;
    int      loc;
    int      pinned;
    int      dirty_host;
    int      dirty_dev;
} HexaFarrEntry;

/* Tiny mock farr table. Sized at startup; never realloc'd during a test
 * (sidesteps the RFC 032 use-after-realloc guard, which is enforced in
 * the real runtime.c — irrelevant for this unit-test harness).
 *
 * NB: runtime_cuda.c declares `extern HexaFarrEntry* _hx_farr_table;`
 * (pointer, not array) — must match here, or the runtime sees garbage
 * (`e->len` reads a huge random int64 → cudaMalloc OOM cascade). The
 * original `HexaFarrEntry _hx_farr_table[MOCK_FARR_CAP]` array form
 * produced this exact failure mode on the first refire. */
#define MOCK_FARR_CAP 1024
static HexaFarrEntry _hx_farr_storage[MOCK_FARR_CAP];
HexaFarrEntry*       _hx_farr_table = _hx_farr_storage;
int64_t              _hx_farr_count = 0;

/* Externs from self/cuda/runtime_cuda.c. */
extern "C" {
    int _hx_cuda_farr_softmax_rows_gpu(int64_t x_id, int64_t R, int64_t C,
                                       int64_t out_id);
    int _hx_cuda_farr_rmsnorm_rows_gpu(int64_t x_id, int64_t R, int64_t C,
                                       double eps, int64_t out_id);
    int _hx_cuda_farr_rmsnorm_bwd_rows_gpu(int64_t x_id, int64_t dxn_id,
                                           int64_t R, int64_t C, int64_t out_id);
    int _hx_cuda_farr_adamw_step_gpu(int64_t w_id, int64_t m_id, int64_t v_id,
                                     int64_t g_id, int64_t n, double lr,
                                     double b1, double b2, double eps, double wd,
                                     int64_t step_t, int64_t out_id);
    int _hx_cuda_farr_matmul_t_gpu(int64_t m_id, int64_t R, int64_t C,
                                   int64_t u_id, int64_t out_id);
    int _hx_cuda_farr_outer_gpu(int64_t u_id, int64_t v_id, int64_t R,
                                int64_t C, int64_t out_id);
}

/* ── CPU oracles — direct copies of the runtime.c CPU helpers (§10967,
 *    §11004, §11343, §11387, §11211, §11241). Same math, same accumulation
 *    order. Re-implemented here to keep the harness self-contained. ── */

static void cpu_softmax_rows(const double* X, double* Y, int64_t R, int64_t C) {
    for (int64_t r = 0; r < R; r++) {
        const double* xr = X + r * C;
        double*       yr = Y + r * C;
        double zmax = xr[0];
        for (int64_t j = 1; j < C; j++) if (xr[j] > zmax) zmax = xr[j];
        double s = 0.0;
        for (int64_t j = 0; j < C; j++) {
            double e = exp(xr[j] - zmax);
            yr[j] = e;
            s += e;
        }
        double inv = (s > 0.0) ? (1.0 / s) : 0.0;
        for (int64_t j = 0; j < C; j++) yr[j] *= inv;
    }
}

static void cpu_rmsnorm_rows(const double* X, double* Y, int64_t R, int64_t C,
                             double eps) {
    double inv_C = 1.0 / (double)C;
    for (int64_t r = 0; r < R; r++) {
        const double* xr = X + r * C;
        double*       yr = Y + r * C;
        double ms = 0.0;
        for (int64_t j = 0; j < C; j++) ms += xr[j] * xr[j];
        ms *= inv_C;
        double inv = 1.0 / sqrt(ms + eps);
        for (int64_t j = 0; j < C; j++) yr[j] = xr[j] * inv;
    }
}

static void cpu_rmsnorm_bwd_rows(const double* X, const double* DXN,
                                 double* O, int64_t R, int64_t C) {
    double inv_C = 1.0 / (double)C;
    for (int64_t r = 0; r < R; r++) {
        const double* xr  = X   + r * C;
        const double* dxr = DXN + r * C;
        double*       orr = O   + r * C;
        double ms = 0.0;
        for (int64_t j = 0; j < C; j++) ms += xr[j] * xr[j];
        ms *= inv_C;
        double inv  = 1.0 / sqrt(ms + 1e-6);
        double dot  = 0.0;
        for (int64_t k = 0; k < C; k++) dot += dxr[k] * xr[k];
        double coef = (inv * inv * inv) * inv_C;
        for (int64_t i = 0; i < C; i++)
            orr[i] = inv * dxr[i] - coef * xr[i] * dot;
    }
}

static void cpu_adamw_step(const double* W_in, double* W_out,
                           double* Mm, double* Vv, const double* G,
                           int64_t n, double lr, double b1, double b2,
                           double eps, double wd, int64_t step_t) {
    double b1t = 1.0, b2t = 1.0;
    for (int64_t e = 0; e < step_t; e++) { b1t *= b1; b2t *= b2; }
    double c1 = 1.0 - b1t, c2 = 1.0 - b2t;
    for (int64_t i = 0; i < n; i++) {
        double g  = G[i];
        double mi = b1 * Mm[i] + (1.0 - b1) * g;
        double vi = b2 * Vv[i] + (1.0 - b2) * g * g;
        double mhat = mi / c1;
        double vhat = vi / c2;
        double denom = sqrt(vhat) + eps;
        double wi = W_in[i] - lr * wd * W_in[i] - lr * mhat / denom;
        Mm[i] = mi;
        Vv[i] = vi;
        W_out[i] = wi;
    }
}

static void cpu_matmul_t(const double* M, const double* U, double* O,
                         int64_t R, int64_t C) {
    for (int64_t k = 0; k < C; k++) O[k] = 0.0;
    for (int64_t r = 0; r < R; r++) {
        const double* mr = M + r * C;
        double ur = U[r];
        for (int64_t k = 0; k < C; k++) O[k] += mr[k] * ur;
    }
}

static void cpu_outer(const double* U, const double* V, double* O,
                      int64_t R, int64_t C) {
    for (int64_t r = 0; r < R; r++) {
        double ur = U[r];
        double* orow = O + r * C;
        for (int64_t c = 0; c < C; c++) orow[c] = ur * V[c];
    }
}

/* ── Test plumbing. ── */

static int64_t alloc_farr(int64_t len) {
    int64_t id = _hx_farr_count++;
    if (id >= MOCK_FARR_CAP) {
        fprintf(stderr, "[harness] farr table overflow\n"); exit(2);
    }
    HexaFarrEntry* e = &_hx_farr_table[id];
    e->buf = (double*)calloc((size_t)len, sizeof(double));
    if (!e->buf) { perror("calloc"); exit(2); }
    e->len = len;
    e->d_buf = NULL;
    e->loc = 0; e->pinned = 0; e->dirty_host = 0; e->dirty_dev = 0;
    return id;
}

static void fill_seq(int64_t id, double scale, double bias) {
    HexaFarrEntry* e = &_hx_farr_table[id];
    for (int64_t i = 0; i < e->len; i++) {
        e->buf[i] = scale * sin((double)(i + 1) * 0.137) + bias;
    }
}

static double max_abs_diff(int64_t id, const double* ref, int64_t len) {
    HexaFarrEntry* e = &_hx_farr_table[id];
    double m = 0.0;
    for (int64_t i = 0; i < len; i++) {
        double d = fabs(e->buf[i] - ref[i]);
        if (d > m) m = d;
    }
    return m;
}

static double max_rel_diff(int64_t id, const double* ref, int64_t len) {
    HexaFarrEntry* e = &_hx_farr_table[id];
    double m = 0.0;
    for (int64_t i = 0; i < len; i++) {
        double a = fabs(ref[i]);
        double d = fabs(e->buf[i] - ref[i]);
        double r = (a > 1e-30) ? d / a : d;
        if (r > m) m = r;
    }
    return m;
}

static int byte_equal(const double* a, const double* b, int64_t n) {
    return memcmp(a, b, (size_t)n * sizeof(double)) == 0 ? 1 : 0;
}

#define TOL_MATMUL 2e-9
#define TOL_ELEM   1e-12

static int n_pass = 0, n_fail = 0;

static void check_pass(const char* name, int ok, double m, double tol,
                       const char* metric) {
    if (ok) {
        printf("  PASS  %-34s %s=%.3e (tol %.3e)\n", name, metric, m, tol);
        n_pass++;
    } else {
        printf("  FAIL  %-34s %s=%.3e > tol %.3e\n", name, metric, m, tol);
        n_fail++;
    }
}

/* ── Per-op tests. ── */

static void test_softmax_rows(int64_t R, int64_t C) {
    printf("[F-RFC041-SOFTMAX-ROWS-EQ] R=%lld C=%lld\n",
           (long long)R, (long long)C);
    int64_t x_id   = alloc_farr(R * C);
    int64_t out_id = alloc_farr(R * C);
    fill_seq(x_id, 2.5, 0.3);
    /* Run GPU. */
    int rc = _hx_cuda_farr_softmax_rows_gpu(x_id, R, C, out_id);
    if (rc != 0) { printf("  FAIL  launch rc=%d\n", rc); n_fail++; return; }
    /* CPU oracle. */
    double* ref = (double*)malloc((size_t)R * C * sizeof(double));
    cpu_softmax_rows(_hx_farr_table[x_id].buf, ref, R, C);
    double m = max_abs_diff(out_id, ref, R * C);
    check_pass("softmax_rows abs", m < TOL_ELEM, m, TOL_ELEM, "|Δ|");
    /* Determinism. */
    double* run1 = (double*)malloc((size_t)R * C * sizeof(double));
    memcpy(run1, _hx_farr_table[out_id].buf, (size_t)R * C * sizeof(double));
    rc = _hx_cuda_farr_softmax_rows_gpu(x_id, R, C, out_id);
    if (rc != 0) { printf("  FAIL  rerun rc=%d\n", rc); n_fail++; }
    int eq = byte_equal(run1, _hx_farr_table[out_id].buf, R * C);
    check_pass("softmax_rows determinism", eq, 0.0, 0.0, "byte-eq");
    free(ref); free(run1);
}

static void test_rmsnorm_rows(int64_t R, int64_t C, double eps) {
    printf("[F-RFC041-RMSNORM-ROWS-EQ] R=%lld C=%lld eps=%g\n",
           (long long)R, (long long)C, eps);
    int64_t x_id   = alloc_farr(R * C);
    int64_t out_id = alloc_farr(R * C);
    fill_seq(x_id, 1.7, 0.1);
    int rc = _hx_cuda_farr_rmsnorm_rows_gpu(x_id, R, C, eps, out_id);
    if (rc != 0) { printf("  FAIL  launch rc=%d\n", rc); n_fail++; return; }
    double* ref = (double*)malloc((size_t)R * C * sizeof(double));
    cpu_rmsnorm_rows(_hx_farr_table[x_id].buf, ref, R, C, eps);
    double m = max_abs_diff(out_id, ref, R * C);
    check_pass("rmsnorm_rows abs", m < TOL_ELEM, m, TOL_ELEM, "|Δ|");
    double* run1 = (double*)malloc((size_t)R * C * sizeof(double));
    memcpy(run1, _hx_farr_table[out_id].buf, (size_t)R * C * sizeof(double));
    rc = _hx_cuda_farr_rmsnorm_rows_gpu(x_id, R, C, eps, out_id);
    int eq = byte_equal(run1, _hx_farr_table[out_id].buf, R * C);
    check_pass("rmsnorm_rows determinism", eq, 0.0, 0.0, "byte-eq");
    free(ref); free(run1);
}

static void test_rmsnorm_bwd_rows(int64_t R, int64_t C) {
    printf("[F-RFC041-RMSNORM-BWD-ROWS-EQ] R=%lld C=%lld\n",
           (long long)R, (long long)C);
    int64_t x_id   = alloc_farr(R * C);
    int64_t dxn_id = alloc_farr(R * C);
    int64_t out_id = alloc_farr(R * C);
    fill_seq(x_id,   1.4, 0.05);
    fill_seq(dxn_id, 0.8, 0.0);
    int rc = _hx_cuda_farr_rmsnorm_bwd_rows_gpu(x_id, dxn_id, R, C, out_id);
    if (rc != 0) { printf("  FAIL  launch rc=%d\n", rc); n_fail++; return; }
    double* ref = (double*)malloc((size_t)R * C * sizeof(double));
    cpu_rmsnorm_bwd_rows(_hx_farr_table[x_id].buf,
                         _hx_farr_table[dxn_id].buf, ref, R, C);
    double m = max_abs_diff(out_id, ref, R * C);
    check_pass("rmsnorm_bwd_rows abs", m < TOL_ELEM, m, TOL_ELEM, "|Δ|");
    double* run1 = (double*)malloc((size_t)R * C * sizeof(double));
    memcpy(run1, _hx_farr_table[out_id].buf, (size_t)R * C * sizeof(double));
    rc = _hx_cuda_farr_rmsnorm_bwd_rows_gpu(x_id, dxn_id, R, C, out_id);
    int eq = byte_equal(run1, _hx_farr_table[out_id].buf, R * C);
    check_pass("rmsnorm_bwd_rows determinism", eq, 0.0, 0.0, "byte-eq");
    free(ref); free(run1);
}

static void test_adamw_step(int64_t n, int64_t step_t) {
    printf("[F-RFC041-ADAMW-EQ] n=%lld step_t=%lld\n",
           (long long)n, (long long)step_t);
    /* Two separate copies of (W, m, v): one for CPU oracle, one for GPU.
     * adamw mutates m, v in place — must not share state. */
    int64_t W_id  = alloc_farr(n);
    int64_t m_id  = alloc_farr(n);
    int64_t v_id  = alloc_farr(n);
    int64_t g_id  = alloc_farr(n);
    int64_t out_id = alloc_farr(n);
    fill_seq(W_id, 0.3,   0.1);
    fill_seq(m_id, 0.01,  0.0);
    fill_seq(v_id, 0.005, 1e-4);
    fill_seq(g_id, 0.2,   0.0);
    /* Snapshot pre-call for CPU oracle (since GPU also mutates m, v). */
    double* W_ref     = (double*)malloc((size_t)n * sizeof(double));
    double* m_pre     = (double*)malloc((size_t)n * sizeof(double));
    double* v_pre     = (double*)malloc((size_t)n * sizeof(double));
    double* m_cpu_out = (double*)malloc((size_t)n * sizeof(double));
    double* v_cpu_out = (double*)malloc((size_t)n * sizeof(double));
    memcpy(m_pre, _hx_farr_table[m_id].buf, (size_t)n * sizeof(double));
    memcpy(v_pre, _hx_farr_table[v_id].buf, (size_t)n * sizeof(double));
    memcpy(m_cpu_out, m_pre, (size_t)n * sizeof(double));
    memcpy(v_cpu_out, v_pre, (size_t)n * sizeof(double));
    double lr=1e-3, b1=0.9, b2=0.999, eps=1e-8, wd=0.01;
    cpu_adamw_step(_hx_farr_table[W_id].buf, W_ref,
                   m_cpu_out, v_cpu_out, _hx_farr_table[g_id].buf,
                   n, lr, b1, b2, eps, wd, step_t);
    int rc = _hx_cuda_farr_adamw_step_gpu(W_id, m_id, v_id, g_id, n,
                                          lr, b1, b2, eps, wd, step_t, out_id);
    if (rc != 0) { printf("  FAIL  launch rc=%d\n", rc); n_fail++;
                   free(W_ref); free(m_pre); free(v_pre);
                   free(m_cpu_out); free(v_cpu_out); return; }
    double mw = max_abs_diff(out_id, W_ref, n);
    check_pass("adamw W abs", mw < TOL_ELEM, mw, TOL_ELEM, "|Δ|");
    double mm = max_abs_diff(m_id, m_cpu_out, n);
    check_pass("adamw m abs", mm < TOL_ELEM, mm, TOL_ELEM, "|Δ|");
    double mv = max_abs_diff(v_id, v_cpu_out, n);
    check_pass("adamw v abs", mv < TOL_ELEM, mv, TOL_ELEM, "|Δ|");
    free(W_ref); free(m_pre); free(v_pre); free(m_cpu_out); free(v_cpu_out);
}

static void test_matmul_t(int64_t R, int64_t C) {
    printf("[F-RFC041-MATMUL-T-EQ] R=%lld C=%lld\n",
           (long long)R, (long long)C);
    int64_t M_id = alloc_farr(R * C);
    int64_t u_id = alloc_farr(R);
    int64_t out_id = alloc_farr(C);
    fill_seq(M_id, 0.7, 0.1);
    fill_seq(u_id, 1.1, 0.0);
    int rc = _hx_cuda_farr_matmul_t_gpu(M_id, R, C, u_id, out_id);
    if (rc != 0) { printf("  FAIL  launch rc=%d\n", rc); n_fail++; return; }
    double* ref = (double*)malloc((size_t)C * sizeof(double));
    cpu_matmul_t(_hx_farr_table[M_id].buf, _hx_farr_table[u_id].buf,
                 ref, R, C);
    double m = max_rel_diff(out_id, ref, C);
    check_pass("matmul_t rel", m < TOL_MATMUL, m, TOL_MATMUL, "|Δ_rel|");
    double* run1 = (double*)malloc((size_t)C * sizeof(double));
    memcpy(run1, _hx_farr_table[out_id].buf, (size_t)C * sizeof(double));
    rc = _hx_cuda_farr_matmul_t_gpu(M_id, R, C, u_id, out_id);
    int eq = byte_equal(run1, _hx_farr_table[out_id].buf, C);
    check_pass("matmul_t determinism", eq, 0.0, 0.0, "byte-eq");
    free(ref); free(run1);
}

static void test_outer(int64_t R, int64_t C) {
    printf("[F-RFC041-OUTER-EXACT] R=%lld C=%lld\n",
           (long long)R, (long long)C);
    int64_t u_id = alloc_farr(R);
    int64_t v_id = alloc_farr(C);
    int64_t out_id = alloc_farr(R * C);
    fill_seq(u_id, 0.9, 0.0);
    fill_seq(v_id, 1.3, 0.0);
    int rc = _hx_cuda_farr_outer_gpu(u_id, v_id, R, C, out_id);
    if (rc != 0) { printf("  FAIL  launch rc=%d\n", rc); n_fail++; return; }
    double* ref = (double*)malloc((size_t)R * C * sizeof(double));
    cpu_outer(_hx_farr_table[u_id].buf, _hx_farr_table[v_id].buf,
              ref, R, C);
    /* F-RFC041-OUTER-EXACT demands |Δ| == 0. K=1 → no reduction. */
    int eq = byte_equal(_hx_farr_table[out_id].buf, ref, R * C);
    double m = max_abs_diff(out_id, ref, R * C);
    check_pass("outer EXACT", eq, m, 0.0, "|Δ|");
    double* run1 = (double*)malloc((size_t)R * C * sizeof(double));
    memcpy(run1, _hx_farr_table[out_id].buf, (size_t)R * C * sizeof(double));
    rc = _hx_cuda_farr_outer_gpu(u_id, v_id, R, C, out_id);
    int eq2 = byte_equal(run1, _hx_farr_table[out_id].buf, R * C);
    check_pass("outer determinism", eq2, 0.0, 0.0, "byte-eq");
    free(ref); free(run1);
}

int main(void) {
    printf("RFC 041 Phase 4-D-5-2 — 6-op kernel byte-eq harness\n");
    printf("=================================================================\n");
    /* Shapes: 1 small + 1 medium for each op family. Sized so reductions
     * exercise both single-warp (C≤32) and multi-warp (C>32) paths. */

    /* Phase B reductions. */
    test_softmax_rows(8, 32);
    test_softmax_rows(16, 512);
    test_softmax_rows(4, 4096);              /* deep row reduction stress */

    test_rmsnorm_rows(8, 32, 1e-6);
    test_rmsnorm_rows(16, 768, 1e-6);

    test_rmsnorm_bwd_rows(8, 32);
    test_rmsnorm_bwd_rows(16, 768);

    /* Phase B2 — adamw. */
    test_adamw_step(1024, 1);
    test_adamw_step(1024, 100);              /* β^t large t stresses bias-correct */

    /* Phase B2 — matmul-variants (cuBLAS reshape path). */
    test_matmul_t(32, 128);
    test_matmul_t(512, 768);                  /* deep K — TOL_MATMUL stress */

    test_outer(64, 64);
    test_outer(768, 768);                     /* K=1 → must stay bit-exact */

    printf("=================================================================\n");
    printf("TOTAL: %d PASS / %d FAIL\n", n_pass, n_fail);
    return (n_fail == 0) ? 0 : 1;
}
