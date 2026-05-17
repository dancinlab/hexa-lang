// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4b3_matmul_primitives.c — Path B matmul primitive bodies
//
// 4 shape primitives for _db_proj_batch_farr (decoder_block_lib.hexa:174).
// Each verified byte-eq vs libm reference:
//   d_out=32, d_in=32: commit e89ffe75 (Wq, Wo)
//   d_out=16, d_in=32: commit 552b7f7f (Wk, Wv)
//   d_out=64, d_in=32: commit 995c1774 (Wg, Wu)
//   d_out=32, d_in=64: commit 995c1774 (Wd)
//
// Same single-TU pattern — concat after #include "runtime.c" via build
// wrapper. _hx_farr_table[id].buf direct dereference (no HexaVal box).
// ════════════════════════════════════════════════════════════════════════

static inline void flame_proj_inline_matmul(
    const double* A, int M, int K, const double* B, int N, double* C
) {
    for (int i = 0; i < M; i++) for (int j = 0; j < N; j++) C[i*N+j] = 0.0;
    for (int i = 0; i < M; i++) {
        for (int k = 0; k < K; k++) {
            double aik = A[i*K+k];
            for (int j = 0; j < N; j++) C[i*N+j] += aik * B[k*N+j];
        }
    }
}

// d_out=32, d_in=32 (Wq, Wo)
static inline void flame_proj_batch_T16_d32x32_primitive(
    int W_id, int W_off, int X_id, int X_off, int Y_id, int Y_off
) {
    double* W = _hx_farr_table[W_id].buf;
    double* X = _hx_farr_table[X_id].buf;
    double* Y = _hx_farr_table[Y_id].buf;
    const int T = 16, d_out = 32, d_in = 32;
    double xbt[32*16], Wbuf[32*32], C[32*16];
    for (int t = 0; t < T; t++) for (int c = 0; c < d_in; c++) xbt[c*T+t] = X[X_off+t*d_in+c];
    for (int p = 0; p < d_out*d_in; p++) Wbuf[p] = W[W_off+p];
    flame_proj_inline_matmul(Wbuf, d_out, d_in, xbt, T, C);
    for (int r = 0; r < d_out; r++) for (int t2 = 0; t2 < T; t2++) Y[Y_off+t2*d_out+r] = C[r*T+t2];
}

// d_out=16, d_in=32 (Wk, Wv)
static inline void flame_proj_batch_T16_d16x32_primitive(
    int W_id, int W_off, int X_id, int X_off, int Y_id, int Y_off
) {
    double* W = _hx_farr_table[W_id].buf;
    double* X = _hx_farr_table[X_id].buf;
    double* Y = _hx_farr_table[Y_id].buf;
    const int T = 16, d_out = 16, d_in = 32;
    double xbt[32*16], Wbuf[16*32], C[16*16];
    for (int t = 0; t < T; t++) for (int c = 0; c < d_in; c++) xbt[c*T+t] = X[X_off+t*d_in+c];
    for (int p = 0; p < d_out*d_in; p++) Wbuf[p] = W[W_off+p];
    flame_proj_inline_matmul(Wbuf, d_out, d_in, xbt, T, C);
    for (int r = 0; r < d_out; r++) for (int t2 = 0; t2 < T; t2++) Y[Y_off+t2*d_out+r] = C[r*T+t2];
}

// d_out=64, d_in=32 (Wg, Wu)
static inline void flame_proj_batch_T16_d64x32_primitive(
    int W_id, int W_off, int X_id, int X_off, int Y_id, int Y_off
) {
    double* W = _hx_farr_table[W_id].buf;
    double* X = _hx_farr_table[X_id].buf;
    double* Y = _hx_farr_table[Y_id].buf;
    const int T = 16, d_out = 64, d_in = 32;
    double xbt[32*16], Wbuf[64*32], C[64*16];
    for (int t = 0; t < T; t++) for (int c = 0; c < d_in; c++) xbt[c*T+t] = X[X_off+t*d_in+c];
    for (int p = 0; p < d_out*d_in; p++) Wbuf[p] = W[W_off+p];
    flame_proj_inline_matmul(Wbuf, d_out, d_in, xbt, T, C);
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
    double xbt[64*16], Wbuf[32*64], C[32*16];
    for (int t = 0; t < T; t++) for (int c = 0; c < d_in; c++) xbt[c*T+t] = X[X_off+t*d_in+c];
    for (int p = 0; p < d_out*d_in; p++) Wbuf[p] = W[W_off+p];
    flame_proj_inline_matmul(Wbuf, d_out, d_in, xbt, T, C);
    for (int r = 0; r < d_out; r++) for (int t2 = 0; t2 < T; t2++) Y[Y_off+t2*d_out+r] = C[r*T+t2];
}

// ── Path B bwd accumulator primitives (commit fdc3e1e5 verified byte-eq) ──
// dW[r·d_in+c] += Σ_t dY[t·d_out+r] · X[t·d_in+c]  (outer-product accumulator)
// Mirror of _db_grad_accum_farr (decoder_block_lib.hexa:126-160).

static inline void flame_grad_accum_T16_d32x32_primitive(int dY_id, int dY_off, int X_id, int X_off, int dW_id, int dW_off) {
    double* dY = _hx_farr_table[dY_id].buf;
    double* X  = _hx_farr_table[X_id].buf;
    double* dW = _hx_farr_table[dW_id].buf;
    const int T = 16, d_out = 32, d_in = 32;
    double dY_T[32*16], X_buf[16*32], C[32*32];
    for (int t = 0; t < T; t++) for (int r = 0; r < d_out; r++) dY_T[r*T+t] = dY[dY_off+t*d_out+r];
    for (int p = 0; p < T*d_in; p++) X_buf[p] = X[X_off+p];
    flame_proj_inline_matmul(dY_T, d_out, T, X_buf, d_in, C);
    for (int r = 0; r < d_out; r++) for (int c = 0; c < d_in; c++)
        dW[dW_off+r*d_in+c] += C[r*d_in+c];
}

static inline void flame_grad_accum_T16_d16x32_primitive(int dY_id, int dY_off, int X_id, int X_off, int dW_id, int dW_off) {
    double* dY = _hx_farr_table[dY_id].buf;
    double* X  = _hx_farr_table[X_id].buf;
    double* dW = _hx_farr_table[dW_id].buf;
    const int T = 16, d_out = 16, d_in = 32;
    double dY_T[16*16], X_buf[16*32], C[16*32];
    for (int t = 0; t < T; t++) for (int r = 0; r < d_out; r++) dY_T[r*T+t] = dY[dY_off+t*d_out+r];
    for (int p = 0; p < T*d_in; p++) X_buf[p] = X[X_off+p];
    flame_proj_inline_matmul(dY_T, d_out, T, X_buf, d_in, C);
    for (int r = 0; r < d_out; r++) for (int c = 0; c < d_in; c++)
        dW[dW_off+r*d_in+c] += C[r*d_in+c];
}

static inline void flame_grad_accum_T16_d64x32_primitive(int dY_id, int dY_off, int X_id, int X_off, int dW_id, int dW_off) {
    double* dY = _hx_farr_table[dY_id].buf;
    double* X  = _hx_farr_table[X_id].buf;
    double* dW = _hx_farr_table[dW_id].buf;
    const int T = 16, d_out = 64, d_in = 32;
    double dY_T[64*16], X_buf[16*32], C[64*32];
    for (int t = 0; t < T; t++) for (int r = 0; r < d_out; r++) dY_T[r*T+t] = dY[dY_off+t*d_out+r];
    for (int p = 0; p < T*d_in; p++) X_buf[p] = X[X_off+p];
    flame_proj_inline_matmul(dY_T, d_out, T, X_buf, d_in, C);
    for (int r = 0; r < d_out; r++) for (int c = 0; c < d_in; c++)
        dW[dW_off+r*d_in+c] += C[r*d_in+c];
}

static inline void flame_grad_accum_T16_d32x64_primitive(int dY_id, int dY_off, int X_id, int X_off, int dW_id, int dW_off) {
    double* dY = _hx_farr_table[dY_id].buf;
    double* X  = _hx_farr_table[X_id].buf;
    double* dW = _hx_farr_table[dW_id].buf;
    const int T = 16, d_out = 32, d_in = 64;
    double dY_T[32*16], X_buf[16*64], C[32*64];
    for (int t = 0; t < T; t++) for (int r = 0; r < d_out; r++) dY_T[r*T+t] = dY[dY_off+t*d_out+r];
    for (int p = 0; p < T*d_in; p++) X_buf[p] = X[X_off+p];
    flame_proj_inline_matmul(dY_T, d_out, T, X_buf, d_in, C);
    for (int r = 0; r < d_out; r++) for (int c = 0; c < d_in; c++)
        dW[dW_off+r*d_in+c] += C[r*d_in+c];
}
