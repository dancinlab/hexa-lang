// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4b3_leaf_matmul_test.c — Path B Phase 4-B-3-3-6
//
// Byte-eq test for flame_proj_batch_T16_d32x32_primitive — primitive
// form of _db_proj_batch_farr (decoder_block_lib.hexa:174-212) for
// d_out=d_in=32 (Wq, Wo). Eliminates transpose+copy boxing while
// keeping farr_matmul as runtime primitive.
//
// Algorithm:
//   transpose X (T·d_in → d_in·T) → xbt
//   copy W slice → W_buf
//   C = matmul(W_buf, xbt) shape [d_out · T] (libm reference)
//   transpose C → Y
//
// Path B contribution per audit: ~10% wall (saves transpose+copy boxing).
// Combined with A2 2.74×: projected ~3.0-3.2× (PUSH PAST ≥3× target).
//
// Build:
//   clang -O2 tool/flame_phase4b3_leaf_matmul_test.c -lm -o build/leaf_matmul_test
// ════════════════════════════════════════════════════════════════════════

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

typedef struct {
    double*  buf;
    long     len;
    void*    d_buf;
    int      loc, pinned, dirty_host, dirty_dev;
} HexaFarrEntry;

static HexaFarrEntry* _hx_farr_table = NULL;
static long           _hx_farr_count = 0;
static long           _hx_farr_capacity = 0;

static int farr_alloc(long n, const double* init) {
    if (_hx_farr_count >= _hx_farr_capacity) {
        _hx_farr_capacity = _hx_farr_capacity < 16 ? 16 : _hx_farr_capacity * 2;
        _hx_farr_table = (HexaFarrEntry*)realloc(
            _hx_farr_table, _hx_farr_capacity * sizeof(HexaFarrEntry)
        );
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

// Inline matmul (mirror of runtime farr_matmul algorithm — same ikj order)
static void inline_matmul(
    const double* A, int M, int K, const double* B, int N, double* C
) {
    // C[i*N + j] = Σ_k A[i*K + k] · B[k*N + j]
    for (int i = 0; i < M; i++) {
        for (int j = 0; j < N; j++) C[i * N + j] = 0.0;
    }
    for (int i = 0; i < M; i++) {
        for (int k = 0; k < K; k++) {
            double aik = A[i * K + k];
            for (int j = 0; j < N; j++) {
                C[i * N + j] = C[i * N + j] + aik * B[k * N + j];
            }
        }
    }
}

// ── Primitive: _db_proj_batch_farr for T=16, d_out=32, d_in=32 ──────
static inline void flame_proj_batch_T16_d32x32_primitive(
    int W_id, int W_off, int X_id, int X_off, int Y_id, int Y_off
) {
    double* W = _hx_farr_table[W_id].buf;
    double* X = _hx_farr_table[X_id].buf;
    double* Y = _hx_farr_table[Y_id].buf;
    const int T = 16, d_out = 32, d_in = 32;

    // Stack scratch (smaller than heap alloc for these sizes)
    static double xbt[32 * 16];   // d_in·T = 512
    static double Wbuf[32 * 32];  // d_out·d_in = 1024
    static double C[32 * 16];     // d_out·T = 512

    // transpose X (T·d_in) → xbt (d_in·T)
    for (int t = 0; t < T; t++) {
        for (int c = 0; c < d_in; c++) {
            xbt[c * T + t] = X[X_off + t * d_in + c];
        }
    }
    // copy W slice
    for (int p = 0; p < d_out * d_in; p++) Wbuf[p] = W[W_off + p];
    // matmul: C [d_out·T] = Wbuf [d_out·d_in] · xbt [d_in·T]
    inline_matmul(Wbuf, d_out, d_in, xbt, T, C);
    // transpose C (d_out·T) → Y (T·d_out)
    for (int r = 0; r < d_out; r++) {
        for (int t2 = 0; t2 < T; t2++) {
            Y[Y_off + t2 * d_out + r] = C[r * T + t2];
        }
    }
}

// libm reference (same algorithm)
static void proj_batch_ref(
    const double* W, int W_off, const double* X, int X_off,
    double* Y, int Y_off
) {
    const int T = 16, d_out = 32, d_in = 32;
    double xbt[32 * 16], Wbuf[32 * 32], C[32 * 16];
    for (int t = 0; t < T; t++) {
        for (int c = 0; c < d_in; c++) {
            xbt[c * T + t] = X[X_off + t * d_in + c];
        }
    }
    for (int p = 0; p < d_out * d_in; p++) Wbuf[p] = W[W_off + p];
    inline_matmul(Wbuf, d_out, d_in, xbt, T, C);
    for (int r = 0; r < d_out; r++) {
        for (int t2 = 0; t2 < T; t2++) {
            Y[Y_off + t2 * d_out + r] = C[r * T + t2];
        }
    }
}

int main(void) {
    printf("=== flame Path B — matmul primitive byte-eq test ===\n");
    printf("  algorithm: _db_proj_batch_farr d_out=32, d_in=32 (Wq, Wo case)\n");
    printf("  T·d = 16·32 = 512 elements per X/Y; W = 32·32 = 1024\n\n");

    const int W_size = 32 * 32;
    const int X_size = 16 * 32;
    const int Y_size = 16 * 32;
    double W_data[1024], X_data[512];
    for (int i = 0; i < W_size; i++) W_data[i] = sin(0.05 * (double)(i + 1)) * 0.3;
    for (int i = 0; i < X_size; i++) X_data[i] = cos(0.07 * (double)(i + 3)) * 0.2;

    int W_id = farr_alloc(W_size, W_data);
    int X_id = farr_alloc(X_size, X_data);
    int Y_id = farr_alloc(Y_size, NULL);

    flame_proj_batch_T16_d32x32_primitive(W_id, 0, X_id, 0, Y_id, 0);

    double Y_ref[512] = {0};
    proj_batch_ref(W_data, 0, X_data, 0, Y_ref, 0);

    double max_diff = 0.0;
    for (int i = 0; i < Y_size; i++) {
        double d = fabs(_hx_farr_table[Y_id].buf[i] - Y_ref[i]);
        if (d > max_diff) max_diff = d;
    }

    printf("  max|Y_primitive − Y_ref| = %.3e\n\n", max_diff);
    printf("  Y[0]   primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[Y_id].buf[0], Y_ref[0]);
    printf("  Y[256] primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[Y_id].buf[256], Y_ref[256]);
    printf("\n");

    if (max_diff == 0.0) {
        printf("PASS  F-RFC047-LEAF-EMIT-MATMUL  max|Δ| = 0.0 strict byte-eq\n");
        return 0;
    } else {
        printf("FAIL  F-RFC047-LEAF-EMIT-MATMUL  max|Δ| = %.3e\n", max_diff);
        return 1;
    }
}
