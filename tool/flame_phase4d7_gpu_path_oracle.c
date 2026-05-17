// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4d7_gpu_path_oracle.c — d768 GPU-path byte-eq ORACLE
//
// WHY THIS EXISTS
// ───────────────
// The flame campaign trains a d768·12L transformer on a forge GPU
// substrate. The d=32 config has a byte-eq oracle (tool/flame_phase4b3_
// verify_all.sh); the d768 GPU-RESIDENT path had NONE. GPU-path changes
// (RFC 057 §6.1, RFC 058 transpose-scatter kernel) therefore went in
// UNVERIFIED — the RFC 058 regression was only caught at the 13th paid
// d768 GPU fire (gn2 3.99026 → 3.98438 → -nan).
//
// THE IDEA
// ────────
// Pick a MID-SIZE config that is
//   (a) small enough to compute a CPU reference on a Mac / in CI, AND
//   (b) large enough that the GPU-resident dim-gate
//       (M·K > FLAME_MATMUL_GPU_THRESHOLD, 8192) TRIGGERS — so it
//       exercises the SAME GPU-path code (flame_proj_gpu_matmul_g_ex
//       → cuBLAS Dgemm → optional transpose-scatter kernel) that the
//       d768 projection primitive runs.
// Then byte-compare the GPU-resident projection output vs the CPU
// reference. A CHEAP fire (sub-second compute) replaces the 600s d768
// fire as the byte-eq gate for future GPU-path changes.
//
// THE CONFIG — d_out = d_in = 96, T = 16
// ──────────────────────────────────────
//   matmul dispatch shape  M·K = d_out·d_in = 96·96 = 9216  >  8192
//   → flame_proj_matmul_dispatch_g_ex takes the GPU branch (cuBLAS Dgemm)
//   → mm_c_id ≥ 0  → the transpose-scatter consumer site is exercised
//   This is the SAME dim-gate the d768 Q/K/V/O/G/U/D projections cross
//   (d768·768 = 589 824 ≫ 8192). The ONLY difference vs d768 is the
//   value of the loop bounds — the code path is byte-for-byte the same
//   (flame_proj_batch_generic_primitive is dimension-generic, RFC 047).
//   96·96·8 B = 73 KiB W buffer — trivially cheap on any GPU.
//
// HOW THE BYTE-COMPARE WORKS
// ──────────────────────────
//   CPU reference  : flame_proj_inline_matmul_g host triple loop (the
//                    verified-good ikj order) + the host transpose
//                    scatter — i.e. the EXACT code the rolled-back d768
//                    path now runs (rfc058-rollback). This is the
//                    correct-by-construction baseline.
//   GPU candidate  : flame_proj_batch_generic_primitive compiled with
//                    -DHEXA_CUDA — cuBLAS Dgemm + (when the transpose-
//                    scatter kernel is revived) the on-device scatter.
//   Verdict        : max |Δ| over every Y element.
//                      max|Δ| == 0.0                → STRICT byte-eq
//                      max|Δ| ≤ TOL_OP (3e-11)      → TOL_OP PASS
//                      max|Δ| >  TOL_OP             → FAIL (regression)
//                      any NaN/Inf                  → FAIL (the fire #14
//                                                     -nan signature)
//   TOL_OP 3e-11 matches PHASE4D7_GPU_RESIDENT_NOTES.md §5: cuBLAS Dgemm
//   uses a different summation order than the CPU ikj loop (measured
//   rel-err up to 3e-11 at K=512), so the GPU projection is `≈` the CPU
//   reference at TOL_OP, NOT bit-identical. A regression (fire #13
//   gn2 3.98438) or a NaN (fire #14) blows through TOL_OP immediately.
//
// TWO BUILD MODES
// ───────────────
//   no-CUDA (Mac, $0)  : the GPU branch (#ifdef HEXA_CUDA) is compiled
//     out; flame_proj_batch_generic_primitive runs the CPU inline path.
//     The harness then byte-compares CPU-primitive vs CPU-reference —
//     this proves the harness wiring + the CPU reference are correct
//     and is the $0 Mac CI gate (must report max|Δ| = 0.0, strict).
//   CUDA (cheap fire)  : built with -DHEXA_CUDA on a GPU host; the GPU
//     branch runs cuBLAS Dgemm (+ transpose-scatter kernel once revived)
//     and the harness byte-compares GPU vs CPU-reference. This is the
//     SMALL ($-cents, sub-second) fire that gates GPU-path changes —
//     NOT the 600 s d768 fire.
//
// SCOPE — HONEST (g3)
// ───────────────────
//   FULLY IMPLEMENTED here: the CPU-reference half + the harness +
//   the no-CUDA self-check + the GPU-compare code path. The GPU half
//   compiles under -DHEXA_CUDA (syntactic) on Mac; its NUMERIC run is a
//   cheap GPU fire — that run is the one deliverable that genuinely
//   needs a GPU and is therefore handed to the parent (see
//   PHASE4D7_GPU_PATH_ORACLE.md "How to run").
//
// Build / run: tool/flame_phase4d7_gpu_path_oracle.sh
// ════════════════════════════════════════════════════════════════════════

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

// ── HexaVal / runtime shim ──────────────────────────────────────────────
// flame_phase4d6_matmul_primitives.c calls a small slice of the runtime
// farr API. The leaf tests (tool/flame_phase4b3_leaf_matmul_test.c) take
// the same approach: provide a self-contained farr table + the handful of
// API symbols, so the oracle is ONE translation unit with no runtime.c.

typedef struct { int tag; int64_t i; } HexaVal;
#define TAG_INT 1
#define HX_INT(v) ((v).i)
static HexaVal hexa_int(int64_t n) { HexaVal v; v.tag = TAG_INT; v.i = n; return v; }

typedef struct {
    double*  buf;
    long     len;
    void*    d_buf;
    int      loc, pinned, dirty_host, dirty_dev;
} HexaFarrEntry;

// NOTE on linkage: when built --cuda the oracle links self/cuda/
// runtime_cuda.c, which `extern`-declares `_hx_farr_table` and
// `_hx_farr_count`. They must be NON-static here and `_hx_farr_count`
// must be `int64_t` (runtime_cuda.c:95-96) so the symbols resolve and
// the types match. HexaFarrEntry layout is byte-identical to the
// runtime_cuda.c typedef (runtime_cuda.c:86-94).
HexaFarrEntry* _hx_farr_table    = NULL;
int64_t        _hx_farr_count    = 0;
static int64_t _hx_farr_capacity = 0;

static int _oracle_farr_alloc(long n, const double* init) {
    if (_hx_farr_count >= _hx_farr_capacity) {
        _hx_farr_capacity = _hx_farr_capacity < 16 ? 16 : _hx_farr_capacity * 2;
        _hx_farr_table = (HexaFarrEntry*)realloc(
            _hx_farr_table, _hx_farr_capacity * sizeof(HexaFarrEntry));
    }
    int id = (int)_hx_farr_count++;
    _hx_farr_table[id].buf = (double*)calloc(n > 0 ? n : 1, sizeof(double));
    _hx_farr_table[id].len = n;
    _hx_farr_table[id].d_buf = NULL;
    _hx_farr_table[id].loc = 0; _hx_farr_table[id].pinned = 0;
    _hx_farr_table[id].dirty_host = 0; _hx_farr_table[id].dirty_dev = 0;
    if (init) memcpy(_hx_farr_table[id].buf, init, n * sizeof(double));
    return id;
}

// farr API symbols the matmul primitive references.
static HexaVal hexa_farr_zeros(HexaVal n_v) {
    return hexa_int(_oracle_farr_alloc(HX_INT(n_v), NULL));
}
static HexaVal hexa_farr_free(HexaVal id_v) {
    // No-op free — the oracle is one-shot; calloc'd buffers are reclaimed
    // at process exit. Matters only that the id stays valid (the primitive
    // never re-reads a freed id). Mirrors the leaf-test simplification.
    (void)id_v; return hexa_int(0);
}
// hexa_call1 dispatch macro the primitive uses for farr_zeros / farr_free.
// runtime.c routes through fn-pointer vars; the oracle binds the names
// directly. The primitive only ever passes farr_zeros / farr_free.
static HexaVal farr_zeros_fn(HexaVal a) { return hexa_farr_zeros(a); }
static HexaVal farr_free_fn(HexaVal a)  { return hexa_farr_free(a);  }
#define farr_zeros farr_zeros_fn
#define farr_free  farr_free_fn
#define hexa_call1(f, a1) (f)(a1)

#ifdef HEXA_CUDA
// ── CUDA bridge shims ───────────────────────────────────────────────────
// flame_phase4d6_matmul_primitives.c's HEXA_CUDA branch calls the runtime
// surface hexa_farr_matmul_gpu / hexa_farr_transpose_scatter_gpu. In the
// real trainer those live in self/runtime.c and forward to the _hx_cuda_*
// kernels in self/cuda/runtime_cuda.c. The oracle is standalone (no
// runtime.c — like the Phase 4-B-3 leaf tests), so it provides its OWN
// thin shims here that forward to the SAME _hx_cuda_* kernels. The shim
// bodies are byte-for-byte the runtime.c wrapper logic (runtime.c:10972
// hexa_farr_matmul_gpu, :11943 hexa_farr_transpose_scatter_gpu) — so the
// oracle exercises the identical kernel dispatch the d768 trainer does.
// runtime_cuda.c is linked by the .sh; its kernels are FORBIDDEN to
// modify and are NOT modified — only called.
//
// C-LINKAGE (the fire: oracle --cuda link error 2026-05-18). The .sh
// builds via `nvcc -x cu` which ALWAYS parses as C++. runtime_cuda.c
// exports every _hx_cuda_* op inside `#ifdef __cplusplus extern "C" {`
// (runtime_cuda.c:45-46 / :1787-1788) → unmangled C symbols. Without
// the matching `extern "C"` here the harness's C++ TU emits MANGLED
// call sites (`_Z24_hx_cuda_farr_matmul_gpu...`) → undefined-reference
// at link. The no-CUDA + clang-syntactic checks never caught it (no
// C++ link step). Mirror the runtime_cuda.c guard exactly.
#ifdef __cplusplus
extern "C" {
#endif
extern int _hx_cuda_farr_matmul_gpu(int64_t a_id, int64_t M, int64_t K,
                                    int64_t b_id, int64_t N, int64_t c_id);
extern int _hx_cuda_farr_transpose_scatter_gpu(int64_t src_id, int64_t dst_id,
                                               int64_t rows, int64_t cols,
                                               int64_t dst_off);
#ifdef __cplusplus
}  /* extern "C" */
#endif

// runtime.c:10972 hexa_farr_matmul_gpu — allocate fresh C farr, Dgemm.
static HexaVal hexa_farr_matmul_gpu(HexaVal a_v, HexaVal ar_v, HexaVal ac_v,
                                    HexaVal b_v, HexaVal bc_v) {
    int64_t M = HX_INT(ar_v), K = HX_INT(ac_v), N = HX_INT(bc_v);
    int64_t a_id = HX_INT(a_v), b_id = HX_INT(b_v);
    if (M <= 0 || K <= 0 || N <= 0) return hexa_int(-1);
    if (a_id < 0 || a_id >= _hx_farr_count) return hexa_int(-1);
    if (b_id < 0 || b_id >= _hx_farr_count) return hexa_int(-1);
    int64_t c_id = _oracle_farr_alloc(M * N, NULL);
    if (c_id < 0) return hexa_int(-1);
    int rc = _hx_cuda_farr_matmul_gpu(a_id, M, K, b_id, N, c_id);
    if (rc != 0) return hexa_int(-1);
    return hexa_int(c_id);
}

// runtime.c:11943 hexa_farr_transpose_scatter_gpu — slab transpose.
static HexaVal hexa_farr_transpose_scatter_gpu(HexaVal src_v, HexaVal dst_v,
                                               HexaVal rows_v, HexaVal cols_v,
                                               HexaVal dst_off_v) {
    int64_t src_id = HX_INT(src_v), dst_id = HX_INT(dst_v);
    int64_t rows = HX_INT(rows_v), cols = HX_INT(cols_v);
    int64_t dst_off = HX_INT(dst_off_v);
    if (rows <= 0 || cols <= 0 || dst_off < 0) return hexa_int(-1);
    if (src_id < 0 || src_id >= _hx_farr_count) return hexa_int(-1);
    if (dst_id < 0 || dst_id >= _hx_farr_count) return hexa_int(-1);
    int rc = _hx_cuda_farr_transpose_scatter_gpu(src_id, dst_id,
                                                 rows, cols, dst_off);
    return hexa_int(rc);
}
#endif

// ── The primitive under test ────────────────────────────────────────────
// Pulls in flame_proj_batch_generic_primitive verbatim — the SAME source
// the d768 trainer compiles. No fork, no copy: the oracle tests the real
// code. The build script (.sh) splices flame_phase4d6_matmul_primitives.c
// in at the marker line immediately below.
//@FLAME_ORACLE_SPLICE_MARKER@

// ════════════════════════════════════════════════════════════════════════
// CPU REFERENCE — the verified-good projection (rfc058-rollback host path)
// ════════════════════════════════════════════════════════════════════════
// Y[t·d_out+r] = Σ_c W[W_off+r·d_in+c] · X[X_off+t·d_in+c]
// This is flame_proj_inline_matmul_g's ikj order + the host transpose
// scatter — i.e. EXACTLY what flame_proj_batch_generic_primitive runs on
// the CPU path AND, post-rfc058-rollback, what the d768 path runs (the
// transpose-scatter kernel call is disabled → host loop always runs).
// Correct-by-construction baseline.
static void oracle_proj_ref(
    const double* W, int W_off, const double* X, int X_off,
    double* Y, int Y_off, int T, int d_out, int d_in
) {
    double* xbt  = (double*)calloc((size_t)T * d_in,    sizeof(double));
    double* Wbuf = (double*)calloc((size_t)d_out * d_in, sizeof(double));
    double* C    = (double*)calloc((size_t)d_out * T,    sizeof(double));
    for (int t = 0; t < T; t++)
        for (int c = 0; c < d_in; c++)
            xbt[c*T+t] = X[X_off + t*d_in + c];
    for (int p = 0; p < d_out*d_in; p++) Wbuf[p] = W[W_off + p];
    // ikj triple loop — the verified-good reduction order.
    for (int i = 0; i < d_out; i++)
        for (int j = 0; j < T; j++) C[i*T+j] = 0.0;
    for (int i = 0; i < d_out; i++)
        for (int k = 0; k < d_in; k++) {
            double aik = Wbuf[i*d_in+k];
            for (int j = 0; j < T; j++) C[i*T+j] += aik * xbt[k*T+j];
        }
    for (int r = 0; r < d_out; r++)
        for (int t2 = 0; t2 < T; t2++)
            Y[Y_off + t2*d_out + r] = C[r*T+t2];
    free(xbt); free(Wbuf); free(C);
}

// ── Deterministic input generator (reproducible across runs / hosts) ────
static double oracle_gen_w(int i) { return sin(0.013 * (double)(i + 1)) * 0.25; }
static double oracle_gen_x(int i) { return cos(0.017 * (double)(i + 5)) * 0.20; }

int main(void) {
    // The mid-size config — see header. d_out·d_in = 9216 > 8192 → GPU gate.
    const int T = 16, d_out = 96, d_in = 96;
    const int W_size = d_out * d_in;     //  9 216
    const int X_size = T * d_in;         //  1 536
    const int Y_size = T * d_out;        //  1 536

    printf("=== flame Phase 4-D-7 — d768 GPU-PATH byte-eq ORACLE ===\n");
    printf("  config : T=%d  d_out=%d  d_in=%d\n", T, d_out, d_in);
    printf("  dispatch shape M·K = d_out·d_in = %d  (threshold 8192)\n", W_size);
#ifdef HEXA_CUDA
    printf("  build  : -DHEXA_CUDA  → GPU branch (cuBLAS Dgemm) ACTIVE\n");
    printf("  gate   : %d > 8192  → GPU-resident path WILL trigger\n", W_size);
#else
    printf("  build  : no-CUDA    → CPU inline path (harness self-check)\n");
#endif
    printf("\n");

    double* W_data = (double*)malloc(sizeof(double) * W_size);
    double* X_data = (double*)malloc(sizeof(double) * X_size);
    for (int i = 0; i < W_size; i++) W_data[i] = oracle_gen_w(i);
    for (int i = 0; i < X_size; i++) X_data[i] = oracle_gen_x(i);

    int W_id = _oracle_farr_alloc(W_size, W_data);
    int X_id = _oracle_farr_alloc(X_size, X_data);
    int Y_id = _oracle_farr_alloc(Y_size, NULL);

    // ── candidate: the real primitive (GPU path under -DHEXA_CUDA) ──
    flame_proj_batch_generic_primitive(
        W_id, 0, X_id, 0, Y_id, 0, T, d_out, d_in);
    double* Y_cand = _hx_farr_table[Y_id].buf;

    // ── reference: verified-good CPU host projection ──
    double* Y_ref = (double*)calloc(Y_size, sizeof(double));
    oracle_proj_ref(W_data, 0, X_data, 0, Y_ref, 0, T, d_out, d_in);

    // ── byte-compare ──
    double max_abs = 0.0;
    int    nan_hit = 0, exact = 1;
    for (int i = 0; i < Y_size; i++) {
        double a = Y_cand[i], b = Y_ref[i];
        if (isnan(a) || isinf(a) || isnan(b) || isinf(b)) { nan_hit = 1; continue; }
        double d = fabs(a - b);
        if (d != 0.0) exact = 0;
        if (d > max_abs) max_abs = d;
    }

    const double TOL_OP = 3e-11;   // PHASE4D7_GPU_RESIDENT_NOTES.md §5
    printf("  reference Y[0..3] = %.15f %.15f %.15f %.15f\n",
           Y_ref[0], Y_ref[1], Y_ref[2], Y_ref[3]);
    printf("  candidate Y[0..3] = %.15f %.15f %.15f %.15f\n",
           Y_cand[0], Y_cand[1], Y_cand[2], Y_cand[3]);
    printf("  max|Δ| = %.3e   (TOL_OP = %.0e)\n\n", max_abs, TOL_OP);

    int rc;
    if (nan_hit) {
        printf("FAIL  F-RFC058-GPU-PATH-ORACLE  NaN/Inf in output "
               "(the fire #14 -nan signature)\n");
        rc = 1;
    } else if (exact) {
        printf("PASS  F-RFC058-GPU-PATH-ORACLE  max|Δ|=0.0  STRICT byte-eq "
               "vs verified-good CPU reference\n");
        rc = 0;
    } else if (max_abs <= TOL_OP) {
        printf("PASS  F-RFC058-GPU-PATH-ORACLE  max|Δ| ≤ TOL_OP  "
               "(cuBLAS reorder, PHASE4D7 §5 numerical contract)\n");
        rc = 0;
    } else {
        printf("FAIL  F-RFC058-GPU-PATH-ORACLE  max|Δ| > TOL_OP  "
               "— GPU-path REGRESSION (the fire #13 gn2-drift signature)\n");
        rc = 1;
    }

    free(W_data); free(X_data); free(Y_ref);
    return rc;
}
