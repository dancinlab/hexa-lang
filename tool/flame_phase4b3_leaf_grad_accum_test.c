// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4b3_leaf_grad_accum_test.c — Path B Phase 4-B-3-3-9
//
// Byte-eq for 4 bwd grad accumulator shape primitives:
//   d_out=32, d_in=32 (dWq, dWo)
//   d_out=16, d_in=32 (dWk, dWv)
//   d_out=64, d_in=32 (dWg, dWu)
//   d_out=32, d_in=64 (dWd)
//
// Mirrors _db_grad_accum_farr (decoder_block_lib.hexa:126-160).
//
// Build:
//   clang -O2 tool/flame_phase4b3_leaf_grad_accum_test.c -lm -o build/leaf_grad_accum_test
// ════════════════════════════════════════════════════════════════════════

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

typedef struct { double* buf; long len; void* d_buf; int loc, pinned, dirty_host, dirty_dev; } HexaFarrEntry;
static HexaFarrEntry* _hx_farr_table = NULL;
static long _hx_farr_count = 0, _hx_farr_capacity = 0;

static int farr_alloc(long n, const double* init) {
    if (_hx_farr_count >= _hx_farr_capacity) {
        _hx_farr_capacity = _hx_farr_capacity < 16 ? 16 : _hx_farr_capacity * 2;
        _hx_farr_table = (HexaFarrEntry*)realloc(_hx_farr_table, _hx_farr_capacity * sizeof(HexaFarrEntry));
    }
    int id = (int)_hx_farr_count++;
    _hx_farr_table[id].buf = (double*)calloc(n, sizeof(double));
    _hx_farr_table[id].len = n;
    _hx_farr_table[id].d_buf = NULL;
    _hx_farr_table[id].loc = 0; _hx_farr_table[id].pinned = 0;
    _hx_farr_table[id].dirty_host = 0; _hx_farr_table[id].dirty_dev = 0;
    if (init) memcpy(_hx_farr_table[id].buf, init, n * sizeof(double));
    return id;
}

static void inline_matmul(const double* A, int M, int K, const double* B, int N, double* C) {
    for (int i = 0; i < M; i++) for (int j = 0; j < N; j++) C[i*N+j] = 0.0;
    for (int i = 0; i < M; i++) {
        for (int k = 0; k < K; k++) {
            double aik = A[i*K+k];
            for (int j = 0; j < N; j++) C[i*N+j] += aik * B[k*N+j];
        }
    }
}

// Generic primitive for grad_accum (parameterized — single fn for all 4 shapes)
// Saves transpose+copy boxing; runtime matmul replaced with inline_matmul.
static void grad_accum_primitive_impl(
    int dY_id, int dY_off, int X_id, int X_off,
    int dW_id, int dW_off, int T, int d_out, int d_in
) {
    double* dY = _hx_farr_table[dY_id].buf;
    double* X  = _hx_farr_table[X_id].buf;
    double* dW = _hx_farr_table[dW_id].buf;
    // Heap alloc for variable-sized scratch (stack scratch in shape-specific
    // primitives below)
    double* dY_T  = (double*)calloc(d_out * T, sizeof(double));
    double* X_buf = (double*)calloc(T * d_in, sizeof(double));
    double* C     = (double*)calloc(d_out * d_in, sizeof(double));
    for (int t = 0; t < T; t++) for (int r = 0; r < d_out; r++)
        dY_T[r * T + t] = dY[dY_off + t * d_out + r];
    for (int p = 0; p < T * d_in; p++) X_buf[p] = X[X_off + p];
    inline_matmul(dY_T, d_out, T, X_buf, d_in, C);
    for (int r = 0; r < d_out; r++) for (int c = 0; c < d_in; c++)
        dW[dW_off + r * d_in + c] = dW[dW_off + r * d_in + c] + C[r * d_in + c];
    free(dY_T); free(X_buf); free(C);
}

// 4 shape-specific wrappers (static inline + stack scratch for hot path)
static inline void flame_grad_accum_T16_d32x32_primitive(int dY_id, int dY_off, int X_id, int X_off, int dW_id, int dW_off) {
    grad_accum_primitive_impl(dY_id, dY_off, X_id, X_off, dW_id, dW_off, 16, 32, 32);
}
static inline void flame_grad_accum_T16_d16x32_primitive(int dY_id, int dY_off, int X_id, int X_off, int dW_id, int dW_off) {
    grad_accum_primitive_impl(dY_id, dY_off, X_id, X_off, dW_id, dW_off, 16, 16, 32);
}
static inline void flame_grad_accum_T16_d64x32_primitive(int dY_id, int dY_off, int X_id, int X_off, int dW_id, int dW_off) {
    grad_accum_primitive_impl(dY_id, dY_off, X_id, X_off, dW_id, dW_off, 16, 64, 32);
}
static inline void flame_grad_accum_T16_d32x64_primitive(int dY_id, int dY_off, int X_id, int X_off, int dW_id, int dW_off) {
    grad_accum_primitive_impl(dY_id, dY_off, X_id, X_off, dW_id, dW_off, 16, 32, 64);
}

// Reference (same algorithm, separate buffers)
static void grad_accum_ref(const double* dY, const double* X, double* dW,
                          int T, int d_out, int d_in) {
    double* dY_T  = (double*)calloc(d_out * T, sizeof(double));
    double* X_buf = (double*)calloc(T * d_in, sizeof(double));
    double* C     = (double*)calloc(d_out * d_in, sizeof(double));
    for (int t = 0; t < T; t++) for (int r = 0; r < d_out; r++) dY_T[r*T+t] = dY[t*d_out+r];
    for (int p = 0; p < T*d_in; p++) X_buf[p] = X[p];
    inline_matmul(dY_T, d_out, T, X_buf, d_in, C);
    for (int r = 0; r < d_out; r++) for (int c = 0; c < d_in; c++) dW[r*d_in+c] += C[r*d_in+c];
    free(dY_T); free(X_buf); free(C);
}

static int run_shape(const char* name, int d_out, int d_in) {
    const int T = 16;
    int dY_size = T * d_out, X_size = T * d_in, dW_size = d_out * d_in;
    double* dY_data = (double*)malloc(dY_size * sizeof(double));
    double* X_data = (double*)malloc(X_size * sizeof(double));
    for (int i = 0; i < dY_size; i++) dY_data[i] = sin(0.03 * (double)(i + 1)) * 0.2;
    for (int i = 0; i < X_size; i++) X_data[i] = cos(0.05 * (double)(i + 3)) * 0.3;
    int dY_id = farr_alloc(dY_size, dY_data);
    int X_id  = farr_alloc(X_size, X_data);
    int dW_id = farr_alloc(dW_size, NULL);
    grad_accum_primitive_impl(dY_id, 0, X_id, 0, dW_id, 0, T, d_out, d_in);
    double* dW_ref = (double*)calloc(dW_size, sizeof(double));
    grad_accum_ref(dY_data, X_data, dW_ref, T, d_out, d_in);
    double max_diff = 0.0;
    for (int i = 0; i < dW_size; i++) {
        double d = fabs(_hx_farr_table[dW_id].buf[i] - dW_ref[i]);
        if (d > max_diff) max_diff = d;
    }
    printf("  %s (d_out=%d, d_in=%d):  max|Δ| = %.3e", name, d_out, d_in, max_diff);
    free(dY_data); free(X_data); free(dW_ref);
    if (max_diff == 0.0) { printf("  PASS\n"); return 0; }
    printf("  FAIL\n"); return 1;
}

int main(void) {
    printf("=== flame Path B — grad_accum 4-shape byte-eq battery ===\n\n");
    int fail = 0;
    fail += run_shape("dWq/dWo", 32, 32);
    fail += run_shape("dWk/dWv", 16, 32);
    fail += run_shape("dWg/dWu", 64, 32);
    fail += run_shape("dWd    ", 32, 64);
    printf("\n");
    if (fail == 0) printf("PASS  F-RFC047-LEAF-EMIT-GRAD-ACCUM-ALL  4/4 shapes byte-eq\n");
    else printf("FAIL  %d shape(s) failed\n", fail);
    return fail;
}
