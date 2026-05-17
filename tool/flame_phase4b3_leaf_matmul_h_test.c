// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4b3_leaf_matmul_h_test.c — Path B Phase 4-B-3-3-8
//
// Byte-eq for d_out=64, d_in=32 (Wg, Wu) AND d_out=32, d_in=64 (Wd).
// Batched test — both SwiGLU matmul shapes verified in one cycle.
//
// Build:
//   clang -O2 tool/flame_phase4b3_leaf_matmul_h_test.c -lm -o build/leaf_matmul_h_test
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

// d_out=64, d_in=32 (Wg, Wu)
static inline void flame_proj_batch_T16_d64x32_primitive(
    int W_id, int W_off, int X_id, int X_off, int Y_id, int Y_off
) {
    double* W = _hx_farr_table[W_id].buf;
    double* X = _hx_farr_table[X_id].buf;
    double* Y = _hx_farr_table[Y_id].buf;
    const int T = 16, d_out = 64, d_in = 32;
    static double xbt[32*16], Wbuf[64*32], C[64*16];
    for (int t = 0; t < T; t++) for (int c = 0; c < d_in; c++) xbt[c*T+t] = X[X_off+t*d_in+c];
    for (int p = 0; p < d_out*d_in; p++) Wbuf[p] = W[W_off+p];
    inline_matmul(Wbuf, d_out, d_in, xbt, T, C);
    for (int r = 0; r < d_out; r++) for (int t2 = 0; t2 < T; t2++) Y[Y_off+t2*d_out+r] = C[r*T+t2];
}

// d_out=32, d_in=64 (Wd)
static inline void flame_proj_batch_T16_d32x64_primitive(
    int W_id, int W_off, int X_id, int X_off, int Y_id, int Y_off
) {
    double* W = _hx_farr_table[W_id].buf;
    double* X = _hx_farr_table[X_id].buf;
    double* Y = _hx_farr_table[Y_id].buf;
    const int T = 16, d_out = 32, d_in = 64;
    static double xbt[64*16], Wbuf[32*64], C[32*16];
    for (int t = 0; t < T; t++) for (int c = 0; c < d_in; c++) xbt[c*T+t] = X[X_off+t*d_in+c];
    for (int p = 0; p < d_out*d_in; p++) Wbuf[p] = W[W_off+p];
    inline_matmul(Wbuf, d_out, d_in, xbt, T, C);
    for (int r = 0; r < d_out; r++) for (int t2 = 0; t2 < T; t2++) Y[Y_off+t2*d_out+r] = C[r*T+t2];
}

static void proj_ref(const double* W, const double* X, double* Y, int T, int d_out, int d_in) {
    double* xbt = (double*)calloc(d_in*T, sizeof(double));
    double* Wbuf = (double*)calloc(d_out*d_in, sizeof(double));
    double* C = (double*)calloc(d_out*T, sizeof(double));
    for (int t = 0; t < T; t++) for (int c = 0; c < d_in; c++) xbt[c*T+t] = X[t*d_in+c];
    for (int p = 0; p < d_out*d_in; p++) Wbuf[p] = W[p];
    inline_matmul(Wbuf, d_out, d_in, xbt, T, C);
    for (int r = 0; r < d_out; r++) for (int t2 = 0; t2 < T; t2++) Y[t2*d_out+r] = C[r*T+t2];
    free(xbt); free(Wbuf); free(C);
}

int main(void) {
    int fail = 0;
    printf("=== flame Path B — matmul d_out=64/d_in=32 (Wg/Wu) byte-eq ===\n");
    {
        double W_data[64*32], X_data[16*32];
        for (int i = 0; i < 64*32; i++) W_data[i] = sin(0.05*(double)(i+1))*0.3;
        for (int i = 0; i < 16*32; i++) X_data[i] = cos(0.07*(double)(i+3))*0.2;
        int W_id = farr_alloc(64*32, W_data);
        int X_id = farr_alloc(16*32, X_data);
        int Y_id = farr_alloc(16*64, NULL);
        flame_proj_batch_T16_d64x32_primitive(W_id, 0, X_id, 0, Y_id, 0);
        double Y_ref[16*64] = {0};
        proj_ref(W_data, X_data, Y_ref, 16, 64, 32);
        double max_diff = 0.0;
        for (int i = 0; i < 16*64; i++) {
            double d = fabs(_hx_farr_table[Y_id].buf[i] - Y_ref[i]);
            if (d > max_diff) max_diff = d;
        }
        printf("  max|Δ| = %.3e", max_diff);
        if (max_diff == 0.0) printf("  PASS  F-RFC047-LEAF-EMIT-MATMUL-WGWU\n");
        else { printf("  FAIL\n"); fail++; }
    }
    printf("\n=== flame Path B — matmul d_out=32/d_in=64 (Wd) byte-eq ===\n");
    {
        double W_data[32*64], X_data[16*64];
        for (int i = 0; i < 32*64; i++) W_data[i] = sin(0.05*(double)(i+1))*0.3;
        for (int i = 0; i < 16*64; i++) X_data[i] = cos(0.07*(double)(i+3))*0.2;
        int W_id = farr_alloc(32*64, W_data);
        int X_id = farr_alloc(16*64, X_data);
        int Y_id = farr_alloc(16*32, NULL);
        flame_proj_batch_T16_d32x64_primitive(W_id, 0, X_id, 0, Y_id, 0);
        double Y_ref[16*32] = {0};
        proj_ref(W_data, X_data, Y_ref, 16, 32, 64);
        double max_diff = 0.0;
        for (int i = 0; i < 16*32; i++) {
            double d = fabs(_hx_farr_table[Y_id].buf[i] - Y_ref[i]);
            if (d > max_diff) max_diff = d;
        }
        printf("  max|Δ| = %.3e", max_diff);
        if (max_diff == 0.0) printf("  PASS  F-RFC047-LEAF-EMIT-MATMUL-WD\n");
        else { printf("  FAIL\n"); fail++; }
    }
    return fail;
}
