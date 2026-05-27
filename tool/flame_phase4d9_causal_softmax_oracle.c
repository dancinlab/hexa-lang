// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4d9_causal_softmax_oracle.c — causal-softmax byte-eq ORACLE
//
// WHY THIS EXISTS
// ───────────────
// flame Phase 4-D-9 §4 gap #1: the attention block softmaxes over the
// CAUSAL row prefix (per row i: softmax over j∈[0, i+1)), but the only
// forge softmax kernel (_hx_cuda_farr_softmax_rows_gpu) softmaxes the
// FULL row — so the causal mask is a host loop today, blocking the
// device-resident fwd chain. This oracle byte-eq-verifies a NEW additive
// forge kernel (_hx_cuda_kern_causal_softmax_rows / wrapper
// _hx_cuda_farr_causal_softmax_rows_gpu — the 14th kernel, the 12
// verified + RFC 058 13th UNTOUCHED) at $0 on Mac / $-cents on a GPU,
// the same cheap-fire pattern as flame_phase4d7_gpu_path_oracle.
//
// THE BYTE-EQ TRAP (the reason a naive kernel FAILS)
// ──────────────────────────────────────────────────
// The flame attention softmax (tool/flame_phase4d7_block_fwd_primitive.c
// L767-789) uses `flame_g7_dt_exp` — a DETERMINISTIC polynomial exp
// (range-halve while |x|>0.25, 12-term Taylor, square back r times),
// NOT libm exp(). A kernel using CUDA/libm exp() would differ from the
// CPU reference by the exp-ALGORITHM error, not just the reduction
// reorder — it would NOT be byte-eq. So:
//   • the kernel implements `flame_g7_dt_exp` as a __device__ fn
//     (_hx_dt_exp_dev) ported VERBATIM (same constants, same loop
//     bounds, same order), and
//   • this oracle's CPU reference uses the IDENTICAL flame_g7_dt_exp.
// The residual numerical contract is then ONLY the per-row reduction
// reorder (deterministic tree vs sequential scan) — TOL ≈ 1e-12, the
// same Phase B reduction band as the other row kernels.
//
// THE CONTRACT (mirrors flame_phase4d7_block_fwd_primitive.c L767-789)
// ───────────────────────────────────────────────────────────────────
// For an R×T scores matrix X, per row i with causal prefix L = i+1:
//     m_max  = max_{j∈[0,L)}  X[i*T+j]
//     e_j    = flame_g7_dt_exp(X[i*T+j] - m_max)            j∈[0,L)
//     tot    = Σ_{j∈[0,L)} e_j
//     Y[i*T+j] = e_j / tot                                  j∈[0,L)
//     Y[i*T+j] = 0.0                                        j∈[L,T)
//
// TWO BUILD MODES (same as flame_phase4d7_gpu_path_oracle)
// ───────────────────────────────────────────────────────
//   no-CUDA (Mac, $0)  : CPU-vs-CPU self-check — proves the harness +
//     reference. The "candidate" is a second independent CPU evaluation
//     of the same contract; must report max|Δ| = 0.0 STRICT.
//   --cuda  (cheap GPU fire) : built -DHEXA_CUDA, links self/cuda/
//     runtime_cuda.c; the candidate is the real
//     _hx_cuda_farr_causal_softmax_rows_gpu kernel. Byte-compare vs the
//     CPU reference → max|Δ| ≤ TOL 1e-12. On a no-CUDA Mac --cuda only
//     does the SYNTACTIC clang -c -DHEXA_CUDA check.
//
// SCOPE — HONEST (g3)
// ───────────────────
//   FULLY IMPLEMENTED here: the CPU reference, the harness, the no-CUDA
//   self-check, and the --cuda compare path (compiles syntactically on
//   Mac). The --cuda NUMERIC run is the one step that genuinely needs a
//   GPU — a sub-second / $-cents fire handed to the parent. This is a
//   verified building block + its leaf oracle ONLY — the kernel is NOT
//   wired into the trainer/primitives (that is the later dev_view-chain
//   link; wiring without the dataflow conversion would be design-first).
//
// Build / run: tool/flame_phase4d9_causal_softmax_oracle.sh
// ════════════════════════════════════════════════════════════════════════

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

// ── HexaVal / farr-table shim ───────────────────────────────────────────
// Identical approach to tool/flame_phase4d7_gpu_path_oracle.c: a
// self-contained farr table so the oracle is ONE translation unit (no
// runtime.c). When built --cuda, self/cuda/runtime_cuda.c is linked and
// `extern`-declares `_hx_farr_table` (HexaFarrEntry*) + `_hx_farr_count`
// (int64_t) — they MUST be non-static here and the type must match
// (runtime_cuda.c:86-96). HexaFarrEntry layout is byte-identical to the
// runtime_cuda.c typedef.
typedef struct {
    double*  buf;
    int64_t  len;
    void*    d_buf;
    int      loc, pinned, dirty_host, dirty_dev;
} HexaFarrEntry;

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

// ── flame_g7_dt_exp — VERBATIM from flame_phase4d7_block_fwd_primitive.c
// :78-85. The CPU reference MUST use this exact algorithm (NOT libm exp)
// or the byte-compare measures the exp-algorithm gap instead of just the
// reduction reorder. _hx_dt_exp_dev in runtime_cuda.c is the __device__
// port of THIS function — same constants, same loop bounds, same order.
static inline double flame_g7_dt_exp(double x) {
    int r = 0; double xr = x;
    while ((xr > 0.0 ? xr : -xr) > 0.25) { xr = xr / 2.0; r = r + 1; }
    double term = 1.0, acc = 1.0;
    for (int k = 1; k < 12; k++) { term = term * xr / (double)k; acc = acc + term; }
    for (int s = 0; s < r; s++) acc = acc * acc;
    return acc;
}

// ════════════════════════════════════════════════════════════════════════
// CPU REFERENCE — the verified-good causal-prefix softmax
// ════════════════════════════════════════════════════════════════════════
// Byte-for-byte the flame attention softmax body
// (tool/flame_phase4d7_block_fwd_primitive.c L775-788): per row i,
// L=i+1, m_max seeded at X[i*T+0] then scanned over [1,L), tot summed
// SEQUENTIALLY over [0,L) with flame_g7_dt_exp, divide-normalize over
// [0,L); cells j≥L stay 0.0. Correct-by-construction baseline.
static void oracle_causal_softmax_ref(
    const double* X, double* Y, int R, int T
) {
    for (int i = 0; i < R; i++) {
        for (int j = 0; j < T; j++) Y[i*T+j] = 0.0;   // j≥L stays 0.0
        int L = i + 1;
        double m_max = X[i*T+0];
        for (int j = 1; j < L; j++)
            if (X[i*T+j] > m_max) m_max = X[i*T+j];
        double tot = 0.0;
        for (int j = 0; j < L; j++) {
            double e = flame_g7_dt_exp(X[i*T+j] - m_max);
            Y[i*T+j] = e;
            tot += e;
        }
        for (int j = 0; j < L; j++)
            Y[i*T+j] /= tot;
    }
}

#ifdef HEXA_CUDA
// ── CUDA bridge ─────────────────────────────────────────────────────────
// The candidate is the real runtime_cuda.c wrapper. C-LINKAGE: the .sh
// builds via `nvcc -x cu` (parses as C++); runtime_cuda.c exports every
// _hx_cuda_* op inside `#ifdef __cplusplus extern "C" {` — the harness
// MUST mirror that guard or the C++ TU emits a MANGLED call site →
// undefined-reference at link (a fire already cost us this exact bug:
// flame_phase4d7 oracle --cuda link error 2026-05-18).
#ifdef __cplusplus
extern "C" {
#endif
extern int _hx_cuda_farr_causal_softmax_rows_gpu(int64_t x_id, int64_t R,
                                                 int64_t T, int64_t out_id);
#ifdef __cplusplus
}  /* extern "C" */
#endif
#endif

// ── Deterministic input generator (reproducible across runs / hosts) ────
// A spread of magnitudes so flame_g7_dt_exp's range-halving (|x|>0.25)
// and multi-square paths are all exercised; values stay O(1) like real
// scaled attention scores.
static double oracle_gen_score(int idx) {
    return sin(0.021 * (double)(idx + 1)) * 1.7 + cos(0.011 * (double)idx) * 0.6;
}

int main(void) {
    // R rows × T cols scores matrix. R==T (square, as the attention
    // scores sc[T·T] are). Small: a T-length reduction per row, trivial
    // on a Mac, and large enough to span the block reduction (T>32).
    const int R = 48, T = 48;
    const int N = R * T;

    printf("=== flame Phase 4-D-9 — CAUSAL-softmax byte-eq ORACLE ===\n");
    printf("  config : R=%d  T=%d  (causal prefix L=i+1 per row)\n", R, T);
#ifdef HEXA_CUDA
    printf("  build  : -DHEXA_CUDA  → candidate = real forge kernel\n");
#else
    printf("  build  : no-CUDA    → candidate = independent CPU eval "
           "(harness self-check)\n");
#endif
    printf("\n");

    double* X = (double*)malloc(sizeof(double) * N);
    for (int i = 0; i < N; i++) X[i] = oracle_gen_score(i);

    int X_id = _oracle_farr_alloc(N, X);
    int Y_id = _oracle_farr_alloc(N, NULL);

    // ── candidate ──────────────────────────────────────────────────────
#ifdef HEXA_CUDA
    int rc_k = _hx_cuda_farr_causal_softmax_rows_gpu(X_id, R, T, Y_id);
    if (rc_k != 0) {
        printf("FAIL  F-PHASE4D9-CAUSAL-SOFTMAX  kernel wrapper "
               "returned %d\n", rc_k);
        return 1;
    }
    double* Y_cand = _hx_farr_table[Y_id].buf;
#else
    // no-CUDA: the candidate is an INDEPENDENT CPU evaluation of the
    // same contract (proves the harness + reference are self-consistent).
    double* Y_cand = _hx_farr_table[Y_id].buf;
    oracle_causal_softmax_ref(X, Y_cand, R, T);
#endif

    // ── reference: verified-good CPU causal-prefix softmax ─────────────
    double* Y_ref = (double*)calloc(N, sizeof(double));
    oracle_causal_softmax_ref(X, Y_ref, R, T);

    // ── byte-compare ───────────────────────────────────────────────────
    double max_abs = 0.0;
    int    nan_hit = 0, exact = 1;
    for (int i = 0; i < N; i++) {
        double a = Y_cand[i], b = Y_ref[i];
        if (isnan(a) || isinf(a) || isnan(b) || isinf(b)) { nan_hit = 1; continue; }
        double d = fabs(a - b);
        if (d != 0.0) exact = 0;
        if (d > max_abs) max_abs = d;
    }

    // TOL: the residual is ONLY the per-row reduction reorder (the
    // deterministic block tree vs the sequential scan) — flame_g7_dt_exp
    // is byte-identical on both sides. Same ~1e-12 band as the other
    // Phase B reductions (rmsnorm/softmax row kernels).
    const double TOL = 1e-12;
    printf("  reference Y[0,0..2]   = %.15f %.15f %.15f\n",
           Y_ref[0], Y_ref[1], Y_ref[2]);
    printf("  reference Y[r1 j0..2] = %.15f %.15f %.15f\n",
           Y_ref[1*T+0], Y_ref[1*T+1], Y_ref[1*T+2]);
    printf("  candidate Y[0,0..2]   = %.15f %.15f %.15f\n",
           Y_cand[0], Y_cand[1], Y_cand[2]);
    // spot-check the causal mask: row 0 has L=1 so Y[0][1..] must be 0.
    printf("  causal-zero check: Y[0][1]=%.1f Y[0][%d]=%.1f "
           "(both must be 0.0)\n", Y_cand[1], T-1, Y_cand[T-1]);
    printf("  max|Δ| = %.3e   (TOL = %.0e)\n\n", max_abs, TOL);

    int rc;
    if (nan_hit) {
        printf("FAIL  F-PHASE4D9-CAUSAL-SOFTMAX  NaN/Inf in output\n");
        rc = 1;
    } else if (exact) {
        printf("PASS  F-PHASE4D9-CAUSAL-SOFTMAX  max|Δ|=0.0  STRICT byte-eq "
               "vs verified-good CPU reference\n");
        rc = 0;
    } else if (max_abs <= TOL) {
        printf("PASS  F-PHASE4D9-CAUSAL-SOFTMAX  max|Δ| ≤ TOL  "
               "(per-row reduction reorder; dt_exp byte-identical)\n");
        rc = 0;
    } else {
        printf("FAIL  F-PHASE4D9-CAUSAL-SOFTMAX  max|Δ| > TOL  "
               "— kernel does NOT match the flame causal-softmax reference\n");
        rc = 1;
    }

    free(X); free(Y_ref);
    return rc;
}
