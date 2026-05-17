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
// ════════════════════════════════════════════════════════════════════════
// RFC 057 §6.1 — Bc device-authoritative matmul primitive
// ════════════════════════════════════════════════════════════════════════
// fire #11 (H100 cross-check, RFC 057 §3) isolated the d768·12L wall as the
// host-authoritative Bc constraint, NOT GPU compute (6× faster TC, identical
// wall). RFC 057 §6.1: the cuBLAS Dgemm output farr must be left
// loc=FARR_DEVICE, dirty_dev=1 (RFC 056 §6.1 state machine) so downstream
// ops can hexa_farr_dev_view it byte-safely (RFC 057 §6.2) instead of
// host-rebuilding every slab.
//
// ── What this primitive can do byte-safely at $0 substrate cost ──────────
// _hx_cuda_farr_matmul_gpu (self/cuda/runtime_cuda.c) is the VERIFIED forge
// oracle — FORBIDDEN to modify (RFC 057 §1/§9). It hardcodes its output
// farr to loc=FARR_MIRRORED, dirty_host=0 after its own D2H, and keeps the
// device buffer C_dev LIVE in the entry (ce->d_buf = C_dev, runtime_cuda.c
// :477). It ignores the g_forge_out_disposition register.
//
// The matmul-primitive discipline (this file IS mine, RFC 057 §6 scope):
// after hexa_farr_matmul_gpu returns, the output farr is MIRRORED with a
// LIVE device slot — which already satisfies BOTH the §6.1 H2D-skip
// predicate (_h2d: loc∈{DEVICE,MIRRORED} && !dirty_host) AND the dev_view
// base requirement (dev_view only needs g_slots[base].d_buf live, NOT
// loc==DEVICE — runtime_cuda.c:340). So the matmul output is ALREADY a
// byte-safe dev_view base the moment it returns. The ONLY thing that
// destroys that property is the eager hexa_farr_free(c_h) (line ~109 of
// the pre-RFC-057 body) — on -DHEXA_CUDA it cudaFree's C_dev.
//
// RFC 057 §6.1 change (residence disposition ONLY, same Dgemm): the GPU
// path no longer eagerly destroys the cuBLAS output device buffer. The
// host C is filled byte-IDENTICALLY (same D2H from hexa_farr_matmul_gpu),
// so the transpose-scatter into Y/Bc is bit-identical → d=32·3L and d768
// numerics unchanged (F-RFC057-D32-BYTEEQ + BYTEEQ-PRESERVE by
// construction). The output farr-id flows OUT to the caller, which owns
// the residence/free decision (flame_proj_batch_generic_primitive frees
// it after the host scatter → no leak).
//
// ── HONEST scope (g3 — RFC 057 §8.2) ─────────────────────────────────────
// Full §6.1+§6.2 (Bc NEVER host-mutated, every slab a Bc dev_view) is
// blocked: flame_proj_batch_generic_primitive's projection output is
// transpose-scattered C[r·T+t]→Y[t·d_out+r] into Bc HOST-SIDE, and no
// byte-eq-verified forge transpose-scatter kernel exists (inventing one is
// forbidden — RFC 057 §8.2). So Bc stays host-authoritative after each
// projection and downstream Bc-slice dev_views would alias stale device
// bytes. This primitive lands the byte-safe §6.1 substrate-discipline
// piece (output device-resident, not destroyed); the remaining blocker is
// the missing transpose-scatter kernel — diagnosed precisely, not faked.
// ════════════════════════════════════════════════════════════════════════

// RFC 056 §6.1 residence-state enum mirror (self/cuda/runtime_cuda.c:98).
// The matmul primitive sets the output entry's residence flags directly
// (plain HexaFarrEntry struct fields — NOT a substrate function call, so
// no verified-oracle code is modified). HexaFarrEntry layout is declared
// by runtime.c (concat'd ahead) / the STANDALONE typedef in the block
// primitive files: { double* buf; long len; void* d_buf;
//                     int loc, pinned, dirty_host, dirty_dev; }.
#ifndef FLAME_FARR_DEVICE
#define FLAME_FARR_DEVICE 1   /* == FARR_DEVICE  (runtime_cuda.c:98) */
#endif

// RFC 057 §6.1 — leave a cuBLAS-output farr device-authoritative.
// The forge matmul left it loc=MIRRORED, dirty_host=0 with a live device
// slot; promoting to loc=FARR_DEVICE, dirty_dev=1 records that the device
// copy is the authoritative one (RFC 056 §6.1 FARR_DEVICE row). This is a
// pure flag write on the runtime.c HexaFarrEntry — zero bytes copied, the
// host buf is the identical D2H result the forge op already wrote, so a
// subsequent host reader still sees the correct value (MIRRORED→DEVICE
// only changes the residence DISPOSITION, not the data). Byte-eq-exact.
static inline void flame_rfc057_mark_device_authoritative(int64_t c_id) {
    if (c_id < 0 || c_id >= _hx_farr_count) return;
    _hx_farr_table[c_id].loc       = FLAME_FARR_DEVICE;
    _hx_farr_table[c_id].dirty_dev = 1;
}

// ── Layer 2 GPU-routed matmul: C(M×N) = A(M×K) · B(K×N) via cuBLAS Dgemm ──
// Identical to the Phase 4-D-5-2 flame_proj_gpu_matmul (commit 6e3cb5a9),
// renamed _g to avoid a duplicate-symbol clash if both primitive files are
// ever concat'd in the same TU. Falls back to the CPU inline loop on any
// allocation / dispatch error so the primitive never fakes a PASS.
//
// RFC 057 §6.1: the cuBLAS output farr-id is returned via *out_c_id (≥0
// when the GPU path produced a device-resident result; -1 when the CPU
// fallback ran, in which case there is no device buffer). The host C is
// always filled. Callers that pass out_c_id != NULL own the returned
// farr's lifetime; callers passing NULL get the legacy free-here behavior.
static inline void flame_proj_gpu_matmul_g_ex(
    const double* A, int M, int K, const double* B, int N, double* C,
    int64_t* out_c_id
) {
    if (out_c_id) *out_c_id = -1;
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
    // Host C is filled byte-IDENTICALLY whether or not the output farr is
    // kept device-resident — the D2H inside hexa_farr_matmul_gpu already
    // ran. So the transpose-scatter the caller does next is bit-identical
    // (F-RFC057-D32-BYTEEQ + BYTEEQ-PRESERVE by construction).
    for (int p = 0; p < M * N; p++) C[p] = c_buf[p];
    hexa_farr_free(b_h);
    hexa_farr_free(a_h);
    if (out_c_id) {
        // RFC 057 §6.1: hand the cuBLAS output farr OUT, device-resident.
        // The forge matmul left c_h loc=MIRRORED with a live device slot;
        // promote it to FARR_DEVICE/dirty_dev=1 so a downstream
        // hexa_farr_dev_view(c_id,…) is byte-safe (RFC 056 §6.1/§6.2).
        // The CALLER owns c_h's lifetime now (frees it after the host
        // transpose-scatter) — no leak, no double-free.
        flame_rfc057_mark_device_authoritative(c_id);
        *out_c_id = c_id;
    } else {
        // Legacy callers (out_c_id == NULL): free here as before — the
        // pre-RFC-057 disposition (host-authoritative, device buffer
        // destroyed). Kept for any caller not yet RFC-057-restructured.
        hexa_farr_free(c_h);
    }
}

// Legacy 6-arg wrapper — host-authoritative output, device buffer freed
// (pre-RFC-057 disposition). Retained so callers not restructured for the
// §6.1 farr-id-out contract keep byte-identical behavior.
static inline void flame_proj_gpu_matmul_g(
    const double* A, int M, int K, const double* B, int N, double* C
) {
    flame_proj_gpu_matmul_g_ex(A, M, K, B, N, C, (int64_t*)0);
}
#endif  // HEXA_CUDA

// Dim-aware dispatch — small shape → CPU (byte-identical), large → cuBLAS.
// RFC 057 §6.1: _ex variant threads the cuBLAS output farr-id out via
// out_c_id when the GPU path runs; the CPU/threshold-gated path leaves it
// -1 (no device buffer). d=32·3L (M·K = d²=1024 < FLAME_MATMUL_GPU_
// THRESHOLD 8192) ALWAYS takes the CPU inline path → out_c_id stays -1,
// behaviour byte-identical to pre-RFC-057 (F-RFC057-D32-BYTEEQ).
static inline void flame_proj_matmul_dispatch_g_ex(
    const double* A, int M, int K, const double* B, int N, double* C,
    int64_t* out_c_id
) {
    if (out_c_id) *out_c_id = -1;
#ifdef HEXA_CUDA
    if ((long)M * (long)K > FLAME_MATMUL_GPU_THRESHOLD) {
        flame_proj_gpu_matmul_g_ex(A, M, K, B, N, C, out_c_id);
        return;
    }
#endif
    flame_proj_inline_matmul_g(A, M, K, B, N, C);
}

static inline void flame_proj_matmul_dispatch_g(
    const double* A, int M, int K, const double* B, int N, double* C
) {
    flame_proj_matmul_dispatch_g_ex(A, M, K, B, N, C, (int64_t*)0);
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
    // RFC 057 §6.1 — _ex variant returns the cuBLAS output farr-id when the
    // GPU path runs (mm_c_id ≥ 0, device-resident loc=FARR_DEVICE); the
    // CPU/threshold-gated path leaves it -1. d=32·3L (d²=1024 <
    // FLAME_MATMUL_GPU_THRESHOLD 8192) always takes the CPU path → mm_c_id
    // stays -1, host C filled identically (F-RFC057-D32-BYTEEQ).
    int64_t mm_c_id = -1;
    flame_proj_matmul_dispatch_g_ex(Wbuf, d_out, d_in, xbt, T, C, &mm_c_id);
    // Y-scatter transpose C[r·T+t]→Y[t·d_out+r].
    //
    // RFC 058 §5.3/§5.4 — TWO paths, dim-gated by mm_c_id:
    //
    //  • d768 GPU-resident path (mm_c_id ≥ 0): mm_c_id is set iff the
    //    cuBLAS Dgemm ran, i.e. iff d_out·d_in > FLAME_MATMUL_GPU_
    //    THRESHOLD (8192) — the dim-gate the RFC asks for. C is then
    //    device-resident (RFC 057 §6.1, loc=FARR_DEVICE). The forge
    //    transpose-scatter kernel fills the Y/Bc slab ON-DEVICE
    //    (dst[Y_off+c·d_out+r] = src[r·T+c] — identical index map to the
    //    host loop) and leaves Bc device-authoritative (RFC 056 §6.1).
    //    Bc no longer round-trips through the host → RFC 057 §6.2
    //    (downstream slabs hexa_farr_dev_view Bc) is unblocked. Pure
    //    index permutation, ZERO fp ops → bit-identical to the host loop
    //    (F-RFC058-KERNEL-BYTEEQ, confirmed by the d768 fire #13 oracle).
    //
    //  • d=32 / CPU path (mm_c_id < 0): the matmul took the CPU inline
    //    loop, C is host-only. Keep the host transpose loop verbatim —
    //    byte-IDENTICAL to pre-RFC-058 (F-RFC058-D32-BYTEEQ). The kernel
    //    call is unreachable on this path: same #ifdef HEXA_CUDA + the
    //    mm_c_id ≥ 0 gate (RFC 058 §5.4 — d=32 absolutely unchanged).
    //
    // C-pointer re-fetched: hexa_farr_matmul_gpu may have realloc'd
    // _hx_farr_table.
    C = _hx_farr_table[C_id].buf;
    Y = _hx_farr_table[Y_id].buf;
    int did_dev_scatter = 0;
#ifdef HEXA_CUDA
    if (mm_c_id >= 0) {
        // src = C (d_out×T, device-resident), dst = Y (Bc), slab at
        // Y_off. rows=d_out, cols=T → dst[Y_off+t·d_out+r]=C[r·T+t].
        HexaVal ts_rc = hexa_farr_transpose_scatter_gpu(
            hexa_int(mm_c_id), hexa_int(Y_id),
            hexa_int(d_out), hexa_int(T), hexa_int(Y_off));
        if (HX_INT(ts_rc) == 0) {
            did_dev_scatter = 1;
        }
        // rc != 0 → fall through to the host loop below (no fake PASS;
        // C's host bytes are byte-identical so the host scatter is safe).
    }
#endif
    if (!did_dev_scatter) {
        for (int r = 0; r < d_out; r++)
            for (int t2 = 0; t2 < T; t2++)
                Y[Y_off + t2*d_out + r] = C[r*T+t2];
    }

    // RFC 057 §6.1 — the matmul-primitive owns the device-resident cuBLAS
    // output's lifetime: free it AFTER the scatter consumed it (host bytes
    // on the CPU path, device bytes via the kernel on the d768 path — the
    // forge transpose-scatter kernel has already run and its launch read
    // mm_c_id's device buffer). Freeing the device-resident handle here
    // changes no bytes — it releases the cuBLAS output device buffer the
    // §6.1 disposition kept live (no leak, no double-free; mm_c_id is a
    // distinct handle from C_v). On the no-CUDA/CPU path mm_c_id = -1.
    if (mm_c_id >= 0) hexa_call1(farr_free, hexa_int(mm_c_id));
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
    // RFC 057 §6.1 — same device-authoritative output discipline as the
    // fwd projection primitive. mm_c_id ≥ 0 only on the GPU path; the
    // grad_accum dispatch shape is d_out·T (d=32·3L: 32·1024 etc. — most
    // grad_accum shapes cross FLAME_MATMUL_GPU_THRESHOLD on d768 only).
    int64_t mm_c_id = -1;
    flame_proj_matmul_dispatch_g_ex(dY_T, d_out, T, X_buf, d_in, C, &mm_c_id);
    // dW accumulate reads C HOST-side (re-fetch after possible realloc).
    C  = _hx_farr_table[C_id].buf;
    dW = _hx_farr_table[dW_id].buf;
    for (int r = 0; r < d_out; r++)
        for (int c = 0; c < d_in; c++)
            dW[dW_off + r*d_in + c] += C[r*d_in + c];

    // RFC 057 §6.1 — release the device-resident cuBLAS output after the
    // host accumulate consumed it (byte-eq; no leak; mm_c_id distinct
    // from C_v). CPU path → mm_c_id = -1, nothing to free.
    if (mm_c_id >= 0) hexa_call1(farr_free, hexa_int(mm_c_id));
    hexa_call1(farr_free, C_v);
    hexa_call1(farr_free, Xbuf_v);
    hexa_call1(farr_free, dYT_v);
}
