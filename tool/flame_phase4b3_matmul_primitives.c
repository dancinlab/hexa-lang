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
//
// ── Phase 4-D-5-2 Layer 2 + Layer 3 (2026-05-17) ─────────────────────────
// Each primitive is now dim-aware: small shapes (d_out·d_in ≤ THRESHOLD)
// keep the existing 3-nested-loop CPU matmul (A2 SHIPPED byte-eq must stay
// PASS at d=32·3L); large shapes route to the RFC 040 cuBLAS Dgemm path
// (hexa_farr_matmul_gpu) under #ifdef HEXA_CUDA.
//   d=32·3L  config: d_out·d_in ∈ {512, 1024, 2048} ≤ 4096 → CPU (byte-id)
//   d=768·12L config: d_out·d_in = 589824 > 8192        → cuBLAS Dgemm
// Threshold = 8192: clears the largest d=32·3L shape (2048) by 4× and sits
// well below the smallest d=768·12L shape (589824) by ~72×, so the choice
// is unambiguous for both configs. On the no-CUDA Mac build the GPU branch
// is compiled out entirely — small shapes are the only path and byte-eq
// is preserved by construction.
// ════════════════════════════════════════════════════════════════════════

// Layer 3 dim threshold. d_out·d_in strictly above this routes to cuBLAS
// (HEXA_CUDA builds only). At/below it the CPU inline loop is used — this
// covers every d=32·3L A2 SHIPPED shape (max 2048), keeping byte-eq.
#ifndef FLAME_MATMUL_GPU_THRESHOLD
#define FLAME_MATMUL_GPU_THRESHOLD 8192
#endif

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

#ifdef HEXA_CUDA
// ── Layer 2 GPU-routed matmul: C(M×N) = A(M×K) · B(K×N) via cuBLAS Dgemm ──
// Bridges the stack-buffer primitive ABI to the HexaVal farr API. Allocates
// fresh host farrs for A, B (and C is allocated inside hexa_farr_matmul_gpu),
// uploads, runs Dgemm device-side, copies C back, frees the temporaries.
//
// IMPORTANT: hexa_farr_zeros may realloc() _hx_farr_table, MOVING every
// HexaFarrEntry. Re-fetch .buf by id AFTER each allocation before touching it
// (same use-after-realloc hazard documented at runtime.c hexa_farr_matmul).
//
// On any allocation / dispatch error this falls back to the CPU inline loop
// so the primitive always produces a correct numeric result (no fake PASS).
static inline void flame_proj_gpu_matmul(
    const double* A, int M, int K, const double* B, int N, double* C
) {
    HexaVal a_h = hexa_farr_zeros(hexa_int((int64_t)M * K));
    int64_t a_id = HX_INT(a_h);
    if (a_id < 0 || a_id >= _hx_farr_count) {
        flame_proj_inline_matmul(A, M, K, B, N, C);
        return;
    }
    HexaVal b_h = hexa_farr_zeros(hexa_int((int64_t)K * N));
    int64_t b_id = HX_INT(b_h);
    if (b_id < 0 || b_id >= _hx_farr_count) {
        hexa_farr_free(a_h);
        flame_proj_inline_matmul(A, M, K, B, N, C);
        return;
    }
    // Re-fetch buffers AFTER both allocations (table may have moved).
    double* a_buf = _hx_farr_table[a_id].buf;
    double* b_buf = _hx_farr_table[b_id].buf;
    if (!a_buf || !b_buf) {
        hexa_farr_free(b_h);
        hexa_farr_free(a_h);
        flame_proj_inline_matmul(A, M, K, B, N, C);
        return;
    }
    for (int p = 0; p < M * K; p++) a_buf[p] = A[p];
    for (int p = 0; p < K * N; p++) b_buf[p] = B[p];
    // cuBLAS Dgemm: A is M×K row-major, B is K×N row-major, C is M×N.
    HexaVal c_h = hexa_farr_matmul_gpu(
        hexa_int(a_id), hexa_int(M), hexa_int(K),
        hexa_int(b_id), hexa_int(N));
    int64_t c_id = HX_INT(c_h);
    if (c_id < 0 || c_id >= _hx_farr_count) {
        hexa_farr_free(b_h);
        hexa_farr_free(a_h);
        flame_proj_inline_matmul(A, M, K, B, N, C);
        return;
    }
    double* c_buf = _hx_farr_table[c_id].buf;
    if (!c_buf) {
        hexa_farr_free(c_h);
        hexa_farr_free(b_h);
        hexa_farr_free(a_h);
        flame_proj_inline_matmul(A, M, K, B, N, C);
        return;
    }
    for (int p = 0; p < M * N; p++) C[p] = c_buf[p];
    hexa_farr_free(c_h);
    hexa_farr_free(b_h);
    hexa_farr_free(a_h);
}
#endif  // HEXA_CUDA

// Layer 3 dim-aware dispatch — small shape → CPU (byte-id), large → cuBLAS.
static inline void flame_proj_matmul_dispatch(
    const double* A, int M, int K, const double* B, int N, double* C
) {
#ifdef HEXA_CUDA
    // M·K = d_out·d_in for fwd projection (and d_out·T for bwd accum).
    if ((long)M * (long)K > FLAME_MATMUL_GPU_THRESHOLD) {
        flame_proj_gpu_matmul(A, M, K, B, N, C);
        return;
    }
#endif
    flame_proj_inline_matmul(A, M, K, B, N, C);
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
    flame_proj_matmul_dispatch(Wbuf, d_out, d_in, xbt, T, C);
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
    flame_proj_matmul_dispatch(Wbuf, d_out, d_in, xbt, T, C);
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
    flame_proj_matmul_dispatch(Wbuf, d_out, d_in, xbt, T, C);
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
    flame_proj_matmul_dispatch(Wbuf, d_out, d_in, xbt, T, C);
    for (int r = 0; r < d_out; r++) for (int t2 = 0; t2 < T; t2++) Y[Y_off+t2*d_out+r] = C[r*T+t2];
}

// ── Path B bwd accumulator primitives (commit fdc3e1e5 verified byte-eq) ──
// dW[r·d_in+c] += Σ_t dY[t·d_out+r] · X[t·d_in+c]  (outer-product accumulator)
// Mirror of _db_grad_accum_farr (decoder_block_lib.hexa:126-160).
// The matmul shape here is C(d_out×d_in) = dY_T(d_out×T) · X_buf(T×d_in),
// so the dim-aware dispatch threshold tests d_out·T (= M·K).

static inline void flame_grad_accum_T16_d32x32_primitive(int dY_id, int dY_off, int X_id, int X_off, int dW_id, int dW_off) {
    double* dY = _hx_farr_table[dY_id].buf;
    double* X  = _hx_farr_table[X_id].buf;
    double* dW = _hx_farr_table[dW_id].buf;
    const int T = 16, d_out = 32, d_in = 32;
    double dY_T[32*16], X_buf[16*32], C[32*32];
    for (int t = 0; t < T; t++) for (int r = 0; r < d_out; r++) dY_T[r*T+t] = dY[dY_off+t*d_out+r];
    for (int p = 0; p < T*d_in; p++) X_buf[p] = X[X_off+p];
    flame_proj_matmul_dispatch(dY_T, d_out, T, X_buf, d_in, C);
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
    flame_proj_matmul_dispatch(dY_T, d_out, T, X_buf, d_in, C);
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
    flame_proj_matmul_dispatch(dY_T, d_out, T, X_buf, d_in, C);
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
    flame_proj_matmul_dispatch(dY_T, d_out, T, X_buf, d_in, C);
    for (int r = 0; r < d_out; r++) for (int c = 0; c < d_in; c++)
        dW[dW_off+r*d_in+c] += C[r*d_in+c];
}
