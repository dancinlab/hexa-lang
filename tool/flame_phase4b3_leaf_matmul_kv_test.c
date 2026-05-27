// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4b3_leaf_matmul_kv_test.c — Path B Phase 4-B-3-3-7
//
// Byte-eq for flame_proj_batch_T16_d16x32_primitive — d_out=16,
// d_in=32 case (Wk, Wv since kvd = nkv·hd = 2·8 = 16).
//
// Build:
//   clang -O2 tool/flame_phase4b3_leaf_matmul_kv_test.c -lm -o build/leaf_matmul_kv_test
// ════════════════════════════════════════════════════════════════════════

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

typedef struct {
    double*  buf; long len; void* d_buf;
    int loc, pinned, dirty_host, dirty_dev;
} HexaFarrEntry;

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

// Primitive: d_out=16, d_in=32 (Wk, Wv)
static inline void flame_proj_batch_T16_d16x32_primitive(
    int W_id, int W_off, int X_id, int X_off, int Y_id, int Y_off
) {
    double* W = _hx_farr_table[W_id].buf;
    double* X = _hx_farr_table[X_id].buf;
    double* Y = _hx_farr_table[Y_id].buf;
    const int T = 16, d_out = 16, d_in = 32;
    static double xbt[32 * 16];   // d_in·T = 512
    static double Wbuf[16 * 32];  // d_out·d_in = 512
    static double C[16 * 16];     // d_out·T = 256

    for (int t = 0; t < T; t++)
        for (int c = 0; c < d_in; c++)
            xbt[c * T + t] = X[X_off + t * d_in + c];
    for (int p = 0; p < d_out * d_in; p++) Wbuf[p] = W[W_off + p];
    inline_matmul(Wbuf, d_out, d_in, xbt, T, C);
    for (int r = 0; r < d_out; r++)
        for (int t2 = 0; t2 < T; t2++)
            Y[Y_off + t2 * d_out + r] = C[r * T + t2];
}

static void proj_batch_ref(
    const double* W, int W_off, const double* X, int X_off, double* Y, int Y_off
) {
    const int T = 16, d_out = 16, d_in = 32;
    double xbt[32*16], Wbuf[16*32], C[16*16];
    for (int t = 0; t < T; t++)
        for (int c = 0; c < d_in; c++)
            xbt[c*T+t] = X[X_off+t*d_in+c];
    for (int p = 0; p < d_out*d_in; p++) Wbuf[p] = W[W_off+p];
    inline_matmul(Wbuf, d_out, d_in, xbt, T, C);
    for (int r = 0; r < d_out; r++)
        for (int t2 = 0; t2 < T; t2++)
            Y[Y_off+t2*d_out+r] = C[r*T+t2];
}

int main(void) {
    printf("=== flame Path B — matmul d_out=16, d_in=32 (Wk/Wv) byte-eq ===\n\n");
    double W_data[16*32], X_data[16*32];
    for (int i = 0; i < 16*32; i++) W_data[i] = sin(0.05*(double)(i+1))*0.3;
    for (int i = 0; i < 16*32; i++) X_data[i] = cos(0.07*(double)(i+3))*0.2;
    int W_id = farr_alloc(16*32, W_data);
    int X_id = farr_alloc(16*32, X_data);
    int Y_id = farr_alloc(16*16, NULL);
    flame_proj_batch_T16_d16x32_primitive(W_id, 0, X_id, 0, Y_id, 0);
    double Y_ref[16*16] = {0};
    proj_batch_ref(W_data, 0, X_data, 0, Y_ref, 0);
    double max_diff = 0.0;
    for (int i = 0; i < 16*16; i++) {
        double d = fabs(_hx_farr_table[Y_id].buf[i] - Y_ref[i]);
        if (d > max_diff) max_diff = d;
    }
    printf("  max|Y_primitive − Y_ref| = %.3e\n", max_diff);
    printf("  Y[0]   = %.17g (ref %.17g)\n", _hx_farr_table[Y_id].buf[0], Y_ref[0]);
    printf("\n");
    if (max_diff == 0.0) { printf("PASS  F-RFC047-LEAF-EMIT-MATMUL-KV  max|Δ| = 0.0\n"); return 0; }
    printf("FAIL max|Δ| = %.3e\n", max_diff); return 1;
}
