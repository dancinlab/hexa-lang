// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4d6_matmul_primitives.c — Phase 4-D-6 dimension-generic
// A2 matmul primitives (RFC 047 genericization).
//
// Replaces the 8 dim-baked wrappers of tool/flame_phase4b3_matmul_primitives.c
// (flame_proj_batch_T16_d{16,32,64}x{32,64}_primitive + 4 grad_accum) with
// TWO generic functions whose dims arrive as runtime fn arguments:
//   flame_proj_batch_generic_primitive(W_id,W_off,X_id,X_off,Y_id,Y_off, T,d_out,d_in)
//   flame_grad_accum_generic_primitive(dY_id,dY_off,X_id,X_off,dW_id,dW_off, T,d_out,d_in)
//
// ── Why generic (Approach A — parameterize) ─────────────────────────────
// The Phase 4-D-5-2 dispatch core `flame_proj_matmul_dispatch(A,M,K,B,N,C)`
// was ALREADY runtime-generic (M,K,N as args). The blocker was the 8
// WRAPPERS: each baked T/d_out/d_in as `const int` AND used fixed-size
// STACK arrays (xbt[32*16], Wbuf[32*32], C[32*16]). At d=768 the W buffer
// is 768·768·8 = 4.7 MB — a guaranteed stack overflow.
//
// Fix: dims become fn args; the 3 scratch buffers (xbt, Wbuf, C) move from
// stack to heap via the runtime farr API (hexa_call1(farr_zeros,...)).
// The GPU matmul path (flame_proj_gpu_matmul) already heap-allocates A/B/C;
// the CPU path (flame_proj_inline_matmul) reads/writes purely by pointer —
// stack vs heap is invisible to it. No reduction loop is reordered, so
// d=32·3L stays BYTE-IDENTICAL (F-RFC047-A2-PATHB-FULL-BYTE-EQ).
//
// ── Byte-eq argument (d=32·3L) ──────────────────────────────────────────
// 1. flame_proj_matmul_dispatch is the IDENTICAL function (same source) —
//    same i/k/j loop nest, same C[i*N+j] += aik*B[k*N+j] order.
// 2. The transpose / W-copy / Y-scatter loops are byte-copied from the
//    d=32 wrappers, only the literal dims (16,32,32,...) → variables.
//    Loop bounds change value but not structure → identical fp ops.
// 3. Heap buffers vs stack buffers: the inline matmul never observes
//    storage class; double arithmetic is bit-identical either way.
//
// Concat after #include "runtime.c" via tool/flame_phase4d6_a2_build.sh.
// ════════════════════════════════════════════════════════════════════════

// runtime.c provides `static HexaVal farr_zeros;` / `static HexaVal farr_free;`
// (fn-pointer vars) — call via the hexa_call1 macro. _hx_farr_table may be
// realloc()'d by farr_zeros, so every buffer pointer is re-fetched by id
// AFTER all allocations and BEFORE first use (use-after-realloc hazard).

#ifndef FLAME_MATMUL_GPU_THRESHOLD
#define FLAME_MATMUL_GPU_THRESHOLD 8192
#endif

static inline void flame_proj_inline_matmul_g(
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
// Identical to the Phase 4-D-5-2 flame_proj_gpu_matmul (commit 6e3cb5a9),
// renamed _g to avoid a duplicate-symbol clash if both primitive files are
// ever concat'd in the same TU. Falls back to the CPU inline loop on any
// allocation / dispatch error so the primitive never fakes a PASS.
static inline void flame_proj_gpu_matmul_g(
    const double* A, int M, int K, const double* B, int N, double* C
) {
    HexaVal a_h = hexa_farr_zeros(hexa_int((int64_t)M * K));
    int64_t a_id = HX_INT(a_h);
    if (a_id < 0 || a_id >= _hx_farr_count) {
        flame_proj_inline_matmul_g(A, M, K, B, N, C);
        return;
    }
    HexaVal b_h = hexa_farr_zeros(hexa_int((int64_t)K * N));
    int64_t b_id = HX_INT(b_h);
    if (b_id < 0 || b_id >= _hx_farr_count) {
        hexa_farr_free(a_h);
        flame_proj_inline_matmul_g(A, M, K, B, N, C);
        return;
    }
    double* a_buf = _hx_farr_table[a_id].buf;
    double* b_buf = _hx_farr_table[b_id].buf;
    if (!a_buf || !b_buf) {
        hexa_farr_free(b_h);
        hexa_farr_free(a_h);
        flame_proj_inline_matmul_g(A, M, K, B, N, C);
        return;
    }
    for (int p = 0; p < M * K; p++) a_buf[p] = A[p];
    for (int p = 0; p < K * N; p++) b_buf[p] = B[p];
    HexaVal c_h = hexa_farr_matmul_gpu(
        hexa_int(a_id), hexa_int(M), hexa_int(K),
        hexa_int(b_id), hexa_int(N));
    int64_t c_id = HX_INT(c_h);
    if (c_id < 0 || c_id >= _hx_farr_count) {
        hexa_farr_free(b_h);
        hexa_farr_free(a_h);
        flame_proj_inline_matmul_g(A, M, K, B, N, C);
        return;
    }
    double* c_buf = _hx_farr_table[c_id].buf;
    if (!c_buf) {
        hexa_farr_free(c_h);
        hexa_farr_free(b_h);
        hexa_farr_free(a_h);
        flame_proj_inline_matmul_g(A, M, K, B, N, C);
        return;
    }
    for (int p = 0; p < M * N; p++) C[p] = c_buf[p];
    hexa_farr_free(c_h);
    hexa_farr_free(b_h);
    hexa_farr_free(a_h);
}
#endif  // HEXA_CUDA

// Dim-aware dispatch — small shape → CPU (byte-identical), large → cuBLAS.
static inline void flame_proj_matmul_dispatch_g(
    const double* A, int M, int K, const double* B, int N, double* C
) {
#ifdef HEXA_CUDA
    if ((long)M * (long)K > FLAME_MATMUL_GPU_THRESHOLD) {
        flame_proj_gpu_matmul_g(A, M, K, B, N, C);
        return;
    }
#endif
    flame_proj_inline_matmul_g(A, M, K, B, N, C);
}

// ── Generic forward projection primitive ─────────────────────────────────
// Y[t·d_out+r] = Σ_c W[r·d_in+c] · X[t·d_in+c]   (batched over t = 0..T-1)
//
// Body is the d=32 wrapper byte-for-byte with literal dims → fn args and
// the 3 scratch buffers (xbt T·d_in, Wbuf d_out·d_in, C d_out·T) heap-
// allocated. Dispatch shape M·K = d_out·d_in (matches the d=32 wrapper).
static inline void flame_proj_batch_generic_primitive(
    int W_id, int W_off, int X_id, int X_off, int Y_id, int Y_off,
    int T, int d_out, int d_in
) {
    // Heap scratch — sized for any config (d=768·12L would be 4.7 MB on
    // the stack otherwise). farr_zeros may realloc _hx_farr_table.
    HexaVal xbt_v  = hexa_call1(farr_zeros, hexa_int((int64_t)T * d_in));
    HexaVal Wbuf_v = hexa_call1(farr_zeros, hexa_int((int64_t)d_out * d_in));
    HexaVal C_v    = hexa_call1(farr_zeros, hexa_int((int64_t)d_out * T));
    int xbt_id = (int)xbt_v.i, Wbuf_id = (int)Wbuf_v.i, C_id = (int)C_v.i;

    // Re-fetch ALL pointers AFTER every allocation (table may have moved).
    double* W   = _hx_farr_table[W_id].buf;
    double* X   = _hx_farr_table[X_id].buf;
    double* Y   = _hx_farr_table[Y_id].buf;
    double* xbt = _hx_farr_table[xbt_id].buf;
    double* Wbuf= _hx_farr_table[Wbuf_id].buf;
    double* C   = _hx_farr_table[C_id].buf;

    for (int t = 0; t < T; t++)
        for (int c = 0; c < d_in; c++)
            xbt[c*T+t] = X[X_off + t*d_in + c];
    for (int p = 0; p < d_out*d_in; p++) Wbuf[p] = W[W_off + p];
    flame_proj_matmul_dispatch_g(Wbuf, d_out, d_in, xbt, T, C);
    for (int r = 0; r < d_out; r++)
        for (int t2 = 0; t2 < T; t2++)
            Y[Y_off + t2*d_out + r] = C[r*T+t2];

    hexa_call1(farr_free, C_v);
    hexa_call1(farr_free, Wbuf_v);
    hexa_call1(farr_free, xbt_v);
}

// ── Generic bwd grad-accumulator primitive ───────────────────────────────
// dW[r·d_in+c] += Σ_t dY[t·d_out+r] · X[t·d_in+c]   (outer-product accum)
//
// Body is the d=32 grad_accum wrapper byte-for-byte with literal dims →
// fn args. Matmul shape C(d_out×d_in) = dY_T(d_out×T) · X_buf(T×d_in),
// dispatch tests M·K = d_out·T (matches the d=32 wrapper).
static inline void flame_grad_accum_generic_primitive(
    int dY_id, int dY_off, int X_id, int X_off, int dW_id, int dW_off,
    int T, int d_out, int d_in
) {
    HexaVal dYT_v   = hexa_call1(farr_zeros, hexa_int((int64_t)d_out * T));
    HexaVal Xbuf_v  = hexa_call1(farr_zeros, hexa_int((int64_t)T * d_in));
    HexaVal C_v     = hexa_call1(farr_zeros, hexa_int((int64_t)d_out * d_in));
    int dYT_id = (int)dYT_v.i, Xbuf_id = (int)Xbuf_v.i, C_id = (int)C_v.i;

    double* dY   = _hx_farr_table[dY_id].buf;
    double* X    = _hx_farr_table[X_id].buf;
    double* dW   = _hx_farr_table[dW_id].buf;
    double* dY_T = _hx_farr_table[dYT_id].buf;
    double* X_buf= _hx_farr_table[Xbuf_id].buf;
    double* C    = _hx_farr_table[C_id].buf;

    for (int t = 0; t < T; t++)
        for (int r = 0; r < d_out; r++)
            dY_T[r*T+t] = dY[dY_off + t*d_out + r];
    for (int p = 0; p < T*d_in; p++) X_buf[p] = X[X_off + p];
    flame_proj_matmul_dispatch_g(dY_T, d_out, T, X_buf, d_in, C);
    for (int r = 0; r < d_out; r++)
        for (int c = 0; c < d_in; c++)
            dW[dW_off + r*d_in + c] += C[r*d_in + c];

    hexa_call1(farr_free, C_v);
    hexa_call1(farr_free, Xbuf_v);
    hexa_call1(farr_free, dYT_v);
}
