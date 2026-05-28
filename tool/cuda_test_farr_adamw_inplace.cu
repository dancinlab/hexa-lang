/* tool/cuda_test_farr_adamw_inplace.cu
 *
 * GPU byte-eq oracle for the in-place AdamW builtin
 * `_hx_cuda_farr_adamw_step_inplace_gpu` vs the allocating sibling
 * `_hx_cuda_farr_adamw_step_gpu` (and both vs a CPU oracle).
 *
 * Falsifiers:
 *   F-ADAMW-INPLACE-EQ-GPU  : inplace_gpu W,m,v ≡ alloc_gpu W,m,v   (|Δ|=0)
 *   F-ADAMW-INPLACE-EQ-CPU  : inplace_gpu W,m,v ≈ CPU oracle        (TOL_ELEM)
 *   F-ADAMW-INPLACE-DETERM  : rerun byte-identical                  (|Δ|=0)
 *
 * The two GPU kernels run IDENTICAL arithmetic — the only difference is
 * the write destination (fresh O vs W in place). On the same inputs the
 * updated W, m, v are expected bit-identical (|Δ|=0).
 *
 * Build (on the GPU host):
 *   nvcc -O2 -std=c++14 -DHEXA_CUDA -gencode arch=compute_<CC>,code=sm_<CC> \
 *       -x cu runtime_cuda.c cuda_test_farr_adamw_inplace.cu \
 *       -lcublas -lcudart -lm -o test_adamw_inplace
 *
 * Mirrors the cuda_test_farr_reduction.cu harness contract (mock
 * _hx_farr_table pointer + _hx_farr_count, calloc'd host bufs).
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
    int _hx_cuda_farr_adamw_step_gpu(int64_t w_id, int64_t m_id, int64_t v_id,
                                     int64_t g_id, int64_t n, double lr,
                                     double b1, double b2, double eps, double wd,
                                     int64_t step_t, int64_t out_id);
    int _hx_cuda_farr_adamw_step_inplace_gpu(int64_t w_id, int64_t m_id,
                                     int64_t v_id, int64_t g_id, int64_t n,
                                     double lr, double b1, double b2,
                                     double eps, double wd, int64_t step_t);
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

static void fill_seq(int64_t id, double scale, double bias) {
    HexaFarrEntry* e = &_hx_farr_table[id];
    for (int64_t i = 0; i < e->len; i++)
        e->buf[i] = scale * sin((double)(i + 1) * 0.137) + bias;
}

static int byte_equal(const double* a, const double* b, int64_t n) {
    return memcmp(a, b, (size_t)n * sizeof(double)) == 0 ? 1 : 0;
}

static double max_abs_diff_buf(const double* a, const double* b, int64_t n) {
    double m = 0.0;
    for (int64_t i = 0; i < n; i++) { double d = fabs(a[i] - b[i]); if (d > m) m = d; }
    return m;
}

#define TOL_ELEM 1e-12
static int n_pass = 0, n_fail = 0;
static void check(const char* name, int ok, double m, double tol) {
    if (ok) { printf("  PASS  %-32s |Δ|=%.3e (tol %.3e)\n", name, m, tol); n_pass++; }
    else    { printf("  FAIL  %-32s |Δ|=%.3e > tol %.3e\n", name, m, tol); n_fail++; }
}

static void test_adamw_inplace(int64_t n, int64_t step_t) {
    printf("[F-ADAMW-INPLACE] n=%lld step_t=%lld\n", (long long)n, (long long)step_t);
    const double lr = 0.001, b1 = 0.9, b2 = 0.999, eps = 1e-8, wd = 0.01;

    /* Two parallel sets of W,m,v sharing the SAME g. A = allocating,
     * B = in-place. */
    int64_t wA = alloc_farr(n), mA = alloc_farr(n), vA = alloc_farr(n);
    int64_t wB = alloc_farr(n), mB = alloc_farr(n), vB = alloc_farr(n);
    int64_t g  = alloc_farr(n);
    int64_t outA = alloc_farr(n);  /* allocating variant's output */

    fill_seq(g, 0.2, 0.0);
    for (int64_t i = 0; i < n; i++) {
        double w = 0.5 - (double)i * 0.01;
        double m = 0.01 * (double)i;
        double v = 0.001 * (double)(i + 1);
        _hx_farr_table[wA].buf[i] = w; _hx_farr_table[mA].buf[i] = m; _hx_farr_table[vA].buf[i] = v;
        _hx_farr_table[wB].buf[i] = w; _hx_farr_table[mB].buf[i] = m; _hx_farr_table[vB].buf[i] = v;
    }

    /* CPU oracle on a third copy. */
    double* W_ref = (double*)malloc((size_t)n * sizeof(double));
    double* m_ref = (double*)malloc((size_t)n * sizeof(double));
    double* v_ref = (double*)malloc((size_t)n * sizeof(double));
    memcpy(m_ref, _hx_farr_table[mA].buf, (size_t)n * sizeof(double));
    memcpy(v_ref, _hx_farr_table[vA].buf, (size_t)n * sizeof(double));
    cpu_adamw_step(_hx_farr_table[wA].buf, W_ref, m_ref, v_ref,
                   _hx_farr_table[g].buf, n, lr, b1, b2, eps, wd, step_t);

    /* GPU allocating. */
    int rcA = _hx_cuda_farr_adamw_step_gpu(wA, mA, vA, g, n, lr, b1, b2, eps, wd,
                                           step_t, outA);
    if (rcA != 0) { printf("  FAIL  alloc rc=%d\n", rcA); n_fail++; return; }
    /* GPU in-place (W written into wB). */
    int rcB = _hx_cuda_farr_adamw_step_inplace_gpu(wB, mB, vB, g, n, lr, b1, b2,
                                                   eps, wd, step_t);
    if (rcB != 0) { printf("  FAIL  inplace rc=%d\n", rcB); n_fail++; return; }

    /* F-ADAMW-INPLACE-EQ-GPU: alloc(outA) vs inplace(wB), m, v. */
    double dW = max_abs_diff_buf(_hx_farr_table[outA].buf, _hx_farr_table[wB].buf, n);
    check("inplace W ≡ alloc W (gpu)", dW == 0.0, dW, 0.0);
    double dM = max_abs_diff_buf(_hx_farr_table[mA].buf, _hx_farr_table[mB].buf, n);
    check("inplace m ≡ alloc m (gpu)", dM == 0.0, dM, 0.0);
    double dV = max_abs_diff_buf(_hx_farr_table[vA].buf, _hx_farr_table[vB].buf, n);
    check("inplace v ≡ alloc v (gpu)", dV == 0.0, dV, 0.0);

    /* F-ADAMW-INPLACE-EQ-CPU: inplace(wB) vs CPU oracle. */
    double cW = max_abs_diff_buf(_hx_farr_table[wB].buf, W_ref, n);
    check("inplace W ≈ cpu", cW < TOL_ELEM, cW, TOL_ELEM);
    double cM = max_abs_diff_buf(_hx_farr_table[mB].buf, m_ref, n);
    check("inplace m ≈ cpu", cM < TOL_ELEM, cM, TOL_ELEM);
    double cV = max_abs_diff_buf(_hx_farr_table[vB].buf, v_ref, n);
    check("inplace v ≈ cpu", cV < TOL_ELEM, cV, TOL_ELEM);

    /* F-ADAMW-INPLACE-DETERM: rerun on a fresh copy, byte-identical W. */
    int64_t wC = alloc_farr(n), mC = alloc_farr(n), vC = alloc_farr(n);
    for (int64_t i = 0; i < n; i++) {
        _hx_farr_table[wC].buf[i] = 0.5 - (double)i * 0.01;
        _hx_farr_table[mC].buf[i] = 0.01 * (double)i;
        _hx_farr_table[vC].buf[i] = 0.001 * (double)(i + 1);
    }
    int rcC = _hx_cuda_farr_adamw_step_inplace_gpu(wC, mC, vC, g, n, lr, b1, b2,
                                                   eps, wd, step_t);
    if (rcC != 0) { printf("  FAIL  rerun rc=%d\n", rcC); n_fail++; return; }
    int eq = byte_equal(_hx_farr_table[wB].buf, _hx_farr_table[wC].buf, n);
    check("inplace W rerun byte-eq", eq, eq ? 0.0 : 1.0, 0.0);

    free(W_ref); free(m_ref); free(v_ref);
}

int main(void) {
    printf("=== farr_adamw_step_inplace GPU byte-eq oracle ===\n");
    test_adamw_inplace(8, 1);
    test_adamw_inplace(257, 3);
    test_adamw_inplace(4096, 7);
    printf("=== SUMMARY: %d PASS / %d FAIL ===\n", n_pass, n_fail);
    return n_fail == 0 ? 0 : 1;
}
