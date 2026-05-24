/* host_check.c — flame ag_linear FP32 Metal e2e (fwd + bwd) numeric oracle
 *
 * Drives the RUNTIME layer exercised by the new HEXA_METAL=1 env-gates
 * inside stdlib/flame/ag_tape.hexa:
 *   N40 _ag_linear_metal_fp32_fwd  → hexa_farr32_matmul        (forward)
 *   N53 _ag_linear_metal_fp32_bwd  → hexa_farr32_matmul_NT_b   (bwd dx)
 *                                  → hexa_farr32_matmul_NT_a   (bwd dW)
 *
 * Scope honest-fallback (per cycle outline):
 *   The hexa-source autograd harness (host_check.hexa next to this
 *   file) parses cleanly but fails to compile because `farr32_*` is
 *   not yet wired into codegen_c2.hexa as a builtin (only `farr_*` is).
 *   Adding that mapping would be a C-transpile codegen change, which
 *   the cycle constraint @F f2 forbids. So we validate the runtime
 *   layer directly — the hexa helpers `_ag_linear_metal_fp32_fwd/_bwd`
 *   would (when codegen support lands) call exactly the same C
 *   functions we call here, with the same dim-gate semantics. This
 *   covers the full Metal dispatch chain for fwd AND bwd.
 *
 * Topology: 2-layer Linear chain (matches host_check.hexa intent).
 *   x  [B=128, D=128]   →   h = x @ W1     [B=128, H=256]
 *   W1 [D=128, H=256]   →   y = h @ W2     [B=128, C=64]
 *   W2 [H=256, C=64]    →   L = sum(y)     scalar
 *
 * Backward (loss = sum(y), dy = ones[B, C]):
 *   dW2 = h^T · dy           shape [H=256, C=64]   via NT_a
 *   dh  = dy · W2^T          shape [B=128, H=256]  via NT_b
 *   dW1 = x^T · dh           shape [D=128, H=256]  via NT_a
 *   dx  = dh · W1^T          shape [B=128, D=128]  via NT_b
 *
 * Both layers' fwd matmul + bwd matmul shapes EXCEED the 8192 dim-gate
 * threshold (B*D = 16384, D*H = 32768, B*H = 32768, H*C = 16384) so
 * under HEXA_METAL=1 a total of SIX MPS dispatches happen per pass:
 *   2 fwd (matmul) + 2 bwd-dW (NT_a) + 2 bwd-dx (NT_b) = 6.
 *
 * Falsifier: F-RFC075-FLAME-AG-LINEAR-E2E-METAL-NUMERIC-EQ
 *   PASS iff max relative error against an FP64 ikj CPU reference is
 *   below 5e-3 for ALL FOUR result tensors (y, dW1, dW2, dx). 5e-3 is
 *   the FP32-honest budget per the task outline (chained K=128/256
 *   matmul accumulates ~512·eps_f32 ≈ 6e-5 best case, but the 1e-9
 *   denominator floor for near-zero outputs can spike per-element
 *   rel_err into the low 1e-3 range; 5e-3 buffer for MPS tile-major
 *   reduce ordering vs CPU ikj at chained-bwd shapes).
 *
 * Build (Mac, single-TU runtime.c-as-include):
 *   xcrun --sdk macosx clang -O2 \
 *       -DHEXA_METAL \
 *       -fobjc-arc \
 *       -framework Metal -framework MetalPerformanceShaders -framework Foundation \
 *       inbox/fires/rfc075_flame_ag_linear_e2e_metal_2026_05_21/host_check.c \
 *       self/metal/runtime_metal.m \
 *       -o /tmp/flame_e2e_metal_test
 *
 * Run (oracle):
 *   HEXA_METAL=1 /tmp/flame_e2e_metal_test   # MPS dispatch path
 *   /tmp/flame_e2e_metal_test                # CPU FP32 ikj fallback
 * Both produce one line ending PASS/FAIL plus structured per-tensor
 * max_abs + max_rel.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>

#include "../../../self/runtime.c"

/* Extern declarations for the Metal shims — bodies in runtime_metal.m. */
extern int _hx_metal_farr32_matmul_gpu(int64_t a_id, int64_t M, int64_t K,
                                       int64_t b_id, int64_t N,
                                       int64_t c_id);
extern int _hx_metal_farr32_matmul_NT_a_gpu(int64_t a_id, int64_t M, int64_t K,
                                            int64_t b_id, int64_t K2,
                                            int64_t N, int64_t c_id);
extern int _hx_metal_farr32_matmul_NT_b_gpu(int64_t a_id, int64_t M, int64_t K,
                                            int64_t b_id, int64_t N,
                                            int64_t c_id);

static double lcg_next_host(uint64_t* state) {
    *state = *state * 6364136223846793005ULL + 1442695040888963407ULL;
    uint32_t bits24 = (uint32_t)(*state >> 40) & 0xFFFFFFu;
    return ((double)bits24 / (double)(1 << 23)) - 1.0;
}

/* FP64 reference ikj matmul: C[M,N] = A[M,K] · B[K,N] (row-major). */
static void ref_matmul_ikj(const double* A, const double* B, double* C,
                            int64_t M, int64_t K, int64_t N) {
    memset(C, 0, (size_t)(M * N) * sizeof(double));
    for (int64_t i = 0; i < M; i++) {
        const double* Ai = A + i * K;
        double*       Ci = C + i * N;
        for (int64_t k = 0; k < K; k++) {
            double a_ik = Ai[k];
            const double* Bk = B + k * N;
            for (int64_t j = 0; j < N; j++) Ci[j] += a_ik * Bk[j];
        }
    }
}

/* FP64 reference NT_a: C[M,N] = A^T[M,K] · B[K,N]
 * (A is K×M row-major in memory; A^T is M×K logically).
 * Iter: C[i,j] = sum_k A[k,i] * B[k,j].
 */
static void ref_matmul_NT_a(const double* A_KxM, const double* B_KxN,
                             double* C_MxN,
                             int64_t M, int64_t K, int64_t N) {
    memset(C_MxN, 0, (size_t)(M * N) * sizeof(double));
    for (int64_t k = 0; k < K; k++) {
        const double* Ak = A_KxM + k * M;  /* A's k-th row, length M */
        const double* Bk = B_KxN + k * N;  /* B's k-th row, length N */
        for (int64_t i = 0; i < M; i++) {
            double aki = Ak[i];
            double*  Ci = C_MxN + i * N;
            for (int64_t j = 0; j < N; j++) Ci[j] += aki * Bk[j];
        }
    }
}

/* FP64 reference NT_b: C[M,N] = A[M,K] · B^T[K,N]
 * (B is N×K row-major in memory; B^T is K×N logically).
 * Iter: C[i,j] = sum_k A[i,k] * B[j,k].
 */
static void ref_matmul_NT_b(const double* A_MxK, const double* B_NxK,
                             double* C_MxN,
                             int64_t M, int64_t K, int64_t N) {
    memset(C_MxN, 0, (size_t)(M * N) * sizeof(double));
    for (int64_t i = 0; i < M; i++) {
        const double* Ai = A_MxK + i * K;
        double*       Ci = C_MxN + i * N;
        for (int64_t j = 0; j < N; j++) {
            const double* Bj = B_NxK + j * K;
            double s = 0.0;
            for (int64_t k = 0; k < K; k++) s += Ai[k] * Bj[k];
            Ci[j] = s;
        }
    }
}

typedef struct {
    double max_abs;
    double max_rel;
} ErrStat;

static ErrStat compare_farr32_vs_double(int64_t farr32_id, const double* ref,
                                         int64_t n) {
    ErrStat st = {0.0, 0.0};
    for (int64_t idx = 0; idx < n; idx++) {
        HexaVal vv = hexa_farr32_get(hexa_int(farr32_id), hexa_int(idx));
        double  a  = HX_IS_FLOAT(vv) ? HX_FLOAT(vv) : (double)HX_INT(vv);
        double  r  = ref[idx];
        double  d  = fabs(a - r);
        if (d > st.max_abs) st.max_abs = d;
        double denom = fabs(r) + 1e-9;
        double rel   = d / denom;
        if (rel > st.max_rel) st.max_rel = rel;
    }
    return st;
}

int main(int argc, char** argv) {
    (void)argc; (void)argv;

    const int64_t B = 128;   /* batch */
    const int64_t D = 128;   /* input dim */
    const int64_t H = 256;   /* hidden dim */
    const int64_t Co = 64;   /* output dim (avoid conflict with C variable below) */

    /* All four matmul shapes must exceed the 8192 dim-gate so
     * HEXA_METAL=1 routes to MPS for fwd AND bwd-dW AND bwd-dx. */
    const int64_t gate = 8192;
    const int64_t s_fwd1_lhs = B * D;       /* 16384  */
    const int64_t s_fwd1_rhs = D * H;       /* 32768  */
    const int64_t s_fwd2_lhs = B * H;       /* 32768  */
    const int64_t s_fwd2_rhs = H * Co;      /* 16384  */
    /* bwd dW1 = x^T · dh   shape: [D, H] = NT_a(B,D), (B,H)   K=B M=D N=H */
    /* bwd dW2 = h^T · dy   shape: [H, C] = NT_a(B,H), (B,C)   K=B M=H N=C */
    /* bwd dh  = dy · W2^T  shape: [B, H] = NT_b(B,C), (H,C)   K=C M=B N=H */
    /* bwd dx  = dh · W1^T  shape: [B, D] = NT_b(B,H), (D,H)   K=H M=B N=D */

    const char* metal_env = getenv("HEXA_METAL");
    int metal_on = (metal_env && strcmp(metal_env, "1") == 0) ? 1 : 0;

    fprintf(stderr,
            "[harness] shape B=%lld D=%lld H=%lld C=%lld  HEXA_METAL=%s\n"
            "[harness] fwd1 M·K=%lld K·N=%lld (gate %lld)\n"
            "[harness] fwd2 M·K=%lld K·N=%lld (gate %lld)\n"
            "[harness] bwd  via NT_a/NT_b same magnitudes (mirror of fwd)\n",
            (long long)B, (long long)D, (long long)H, (long long)Co,
            metal_env ? metal_env : "<unset>",
            (long long)s_fwd1_lhs, (long long)s_fwd1_rhs, (long long)gate,
            (long long)s_fwd2_lhs, (long long)s_fwd2_rhs, (long long)gate);

    /* ── FP64 reference arena ─────────────────────────────────────────── */
    double* x_ref   = calloc((size_t)(B * D),  sizeof(double));
    double* W1_ref  = calloc((size_t)(D * H),  sizeof(double));
    double* W2_ref  = calloc((size_t)(H * Co), sizeof(double));
    double* h_ref   = calloc((size_t)(B * H),  sizeof(double));
    double* y_ref   = calloc((size_t)(B * Co), sizeof(double));
    double* dy_ref  = calloc((size_t)(B * Co), sizeof(double));
    double* dW2_ref = calloc((size_t)(H * Co), sizeof(double));
    double* dh_ref  = calloc((size_t)(B * H),  sizeof(double));
    double* dW1_ref = calloc((size_t)(D * H),  sizeof(double));
    double* dx_ref  = calloc((size_t)(B * D),  sizeof(double));
    if (!x_ref || !W1_ref || !W2_ref || !h_ref || !y_ref || !dy_ref
        || !dW2_ref || !dh_ref || !dW1_ref || !dx_ref) {
        fprintf(stderr, "F-RFC075-FLAME-AG-LINEAR-E2E-METAL-NUMERIC-EQ "
                        "FAIL: oom ref bufs\n");
        return 1;
    }

    uint64_t s_x  = 0x12345678ULL;
    uint64_t s_w1 = 0x9ABCDEF0ULL;
    uint64_t s_w2 = 0xFEDCBA98ULL;
    for (int64_t i = 0; i < B  * D;  i++) x_ref[i]  = lcg_next_host(&s_x);
    for (int64_t i = 0; i < D  * H;  i++) W1_ref[i] = lcg_next_host(&s_w1);
    for (int64_t i = 0; i < H  * Co; i++) W2_ref[i] = lcg_next_host(&s_w2);
    for (int64_t i = 0; i < B  * Co; i++) dy_ref[i] = 1.0;  /* sum-loss seed */

    /* Forward: h = x @ W1, y = h @ W2 */
    ref_matmul_ikj(x_ref, W1_ref, h_ref, B, D, H);
    ref_matmul_ikj(h_ref, W2_ref, y_ref, B, H, Co);

    /* Backward:
     *   dW2 [H, C] = h^T · dy   (NT_a: A=h K×M=B×H, B=dy K×N=B×C)
     *   dh  [B, H] = dy · W2^T  (NT_b: A=dy M×K=B×C, B=W2 N×K=H×C)
     *   dW1 [D, H] = x^T · dh   (NT_a: A=x K×M=B×D, B=dh K×N=B×H)
     *   dx  [B, D] = dh · W1^T  (NT_b: A=dh M×K=B×H, B=W1 N×K=D×H)
     *
     * Reference call: ref_matmul_NT_a(A_KxM, B_KxN, C_MxN, M, K, N)
     *                 ref_matmul_NT_b(A_MxK, B_NxK, C_MxN, M, K, N)
     */
    ref_matmul_NT_a(h_ref,  dy_ref, dW2_ref, H, B,  Co);
    ref_matmul_NT_b(dy_ref, W2_ref, dh_ref,  B, Co, H);
    ref_matmul_NT_a(x_ref,  dh_ref, dW1_ref, D, B,  H);
    ref_matmul_NT_b(dh_ref, W1_ref, dx_ref,  B, H,  D);

    /* ── FP32 runtime path ────────────────────────────────────────────── */
    HexaVal xn_h  = hexa_farr32_zeros(hexa_int(B  * D));
    HexaVal W1n_h = hexa_farr32_zeros(hexa_int(D  * H));
    HexaVal W2n_h = hexa_farr32_zeros(hexa_int(H  * Co));
    HexaVal dyn_h = hexa_farr32_zeros(hexa_int(B  * Co));
    int64_t xn_id  = HX_INT(xn_h);
    int64_t W1n_id = HX_INT(W1n_h);
    int64_t W2n_id = HX_INT(W2n_h);
    int64_t dyn_id = HX_INT(dyn_h);
    if (xn_id < 0 || W1n_id < 0 || W2n_id < 0 || dyn_id < 0) {
        fprintf(stderr,
            "F-RFC075-FLAME-AG-LINEAR-E2E-METAL-NUMERIC-EQ FAIL: "
            "farr32_zeros bad ids %lld %lld %lld %lld\n",
            (long long)xn_id, (long long)W1n_id, (long long)W2n_id,
            (long long)dyn_id);
        return 1;
    }
    for (int64_t i = 0; i < B  * D;  i++) {
        hexa_farr32_set(hexa_int(xn_id),  hexa_int(i), hexa_float(x_ref[i]));
    }
    for (int64_t i = 0; i < D  * H;  i++) {
        hexa_farr32_set(hexa_int(W1n_id), hexa_int(i), hexa_float(W1_ref[i]));
    }
    for (int64_t i = 0; i < H  * Co; i++) {
        hexa_farr32_set(hexa_int(W2n_id), hexa_int(i), hexa_float(W2_ref[i]));
    }
    for (int64_t i = 0; i < B  * Co; i++) {
        hexa_farr32_set(hexa_int(dyn_id), hexa_int(i), hexa_float(dy_ref[i]));
    }

    /* Forward: h = x @ W1  (M=B K=D N=H) */
    HexaVal hn_h = hexa_farr32_matmul(hexa_int(xn_id), hexa_int(B),
                                       hexa_int(D),    hexa_int(W1n_id),
                                       hexa_int(H));
    int64_t hn_id = HX_INT(hn_h);
    if (hn_id < 0) {
        fprintf(stderr,
            "F-RFC075-FLAME-AG-LINEAR-E2E-METAL-NUMERIC-EQ FAIL: "
            "fwd matmul L1 bad id %lld\n", (long long)hn_id);
        return 1;
    }

    /* Forward: y = h @ W2  (M=B K=H N=C) */
    HexaVal yn_h = hexa_farr32_matmul(hexa_int(hn_id), hexa_int(B),
                                       hexa_int(H),    hexa_int(W2n_id),
                                       hexa_int(Co));
    int64_t yn_id = HX_INT(yn_h);
    if (yn_id < 0) {
        fprintf(stderr,
            "F-RFC075-FLAME-AG-LINEAR-E2E-METAL-NUMERIC-EQ FAIL: "
            "fwd matmul L2 bad id %lld\n", (long long)yn_id);
        return 1;
    }

    /* Backward dW2 [H, Co] = h^T · dy
     * hexa_farr32_matmul_NT_a(a, ar, ac, b, bc) signature:
     *   a is K×M row-major  → ar=K, ac=M  → for "h^T · dy" with h shape
     *   B×H, the K of NT_a = B (contracting), M = H. b is dy B×C →
     *   bc = N = Co.
     */
    HexaVal dW2n_h = hexa_farr32_matmul_NT_a(hexa_int(hn_id),
                                              hexa_int(B), hexa_int(H),
                                              hexa_int(dyn_id),
                                              hexa_int(Co));
    int64_t dW2n_id = HX_INT(dW2n_h);
    if (dW2n_id < 0) {
        fprintf(stderr,
            "F-RFC075-FLAME-AG-LINEAR-E2E-METAL-NUMERIC-EQ FAIL: "
            "bwd dW2 NT_a bad id %lld\n", (long long)dW2n_id);
        return 1;
    }

    /* Backward dh [B, H] = dy · W2^T
     * hexa_farr32_matmul_NT_b(a, ar, ac, b, br) signature:
     *   a is M×K row-major  → ar=M=B, ac=K=Co.
     *   b is N×K row-major  → br=N=H. */
    HexaVal dhn_h = hexa_farr32_matmul_NT_b(hexa_int(dyn_id),
                                             hexa_int(B), hexa_int(Co),
                                             hexa_int(W2n_id),
                                             hexa_int(H));
    int64_t dhn_id = HX_INT(dhn_h);
    if (dhn_id < 0) {
        fprintf(stderr,
            "F-RFC075-FLAME-AG-LINEAR-E2E-METAL-NUMERIC-EQ FAIL: "
            "bwd dh NT_b bad id %lld\n", (long long)dhn_id);
        return 1;
    }

    /* Backward dW1 [D, H] = x^T · dh  (NT_a: K=B, M=D, N=H) */
    HexaVal dW1n_h = hexa_farr32_matmul_NT_a(hexa_int(xn_id),
                                              hexa_int(B), hexa_int(D),
                                              hexa_int(dhn_id),
                                              hexa_int(H));
    int64_t dW1n_id = HX_INT(dW1n_h);
    if (dW1n_id < 0) {
        fprintf(stderr,
            "F-RFC075-FLAME-AG-LINEAR-E2E-METAL-NUMERIC-EQ FAIL: "
            "bwd dW1 NT_a bad id %lld\n", (long long)dW1n_id);
        return 1;
    }

    /* Backward dx [B, D] = dh · W1^T  (NT_b: M=B, K=H, N=D) */
    HexaVal dxn_h = hexa_farr32_matmul_NT_b(hexa_int(dhn_id),
                                             hexa_int(B), hexa_int(H),
                                             hexa_int(W1n_id),
                                             hexa_int(D));
    int64_t dxn_id = HX_INT(dxn_h);
    if (dxn_id < 0) {
        fprintf(stderr,
            "F-RFC075-FLAME-AG-LINEAR-E2E-METAL-NUMERIC-EQ FAIL: "
            "bwd dx NT_b bad id %lld\n", (long long)dxn_id);
        return 1;
    }

    /* Compare each output. */
    ErrStat s_y   = compare_farr32_vs_double(yn_id,   y_ref,   B * Co);
    ErrStat s_dW1 = compare_farr32_vs_double(dW1n_id, dW1_ref, D * H);
    ErrStat s_dW2 = compare_farr32_vs_double(dW2n_id, dW2_ref, H * Co);
    ErrStat s_dx  = compare_farr32_vs_double(dxn_id,  dx_ref,  B * D);

    /* Free handles. */
    hexa_farr32_free(hexa_int(xn_id));
    hexa_farr32_free(hexa_int(W1n_id));
    hexa_farr32_free(hexa_int(W2n_id));
    hexa_farr32_free(hexa_int(dyn_id));
    hexa_farr32_free(hexa_int(hn_id));
    hexa_farr32_free(hexa_int(yn_id));
    hexa_farr32_free(hexa_int(dhn_id));
    hexa_farr32_free(hexa_int(dW1n_id));
    hexa_farr32_free(hexa_int(dW2n_id));
    hexa_farr32_free(hexa_int(dxn_id));
    free(x_ref); free(W1_ref); free(W2_ref);
    free(h_ref); free(y_ref);  free(dy_ref);
    free(dW2_ref); free(dh_ref); free(dW1_ref); free(dx_ref);

    /* 5e-3 = FP32 chained-matmul + chained-bwd-matmul honest budget. */
    const double TOL = 5e-3;
    double worst = s_y.max_rel;
    if (s_dW1.max_rel > worst) worst = s_dW1.max_rel;
    if (s_dW2.max_rel > worst) worst = s_dW2.max_rel;
    if (s_dx.max_rel  > worst) worst = s_dx.max_rel;

    /* Structured JSON-friendly line for the result.json packer. */
    fprintf(stdout,
        "JSON {\"metal\": \"%s\", \"y\": {\"max_abs\": %.6e, \"max_rel\": %.6e}, "
        "\"dW1\": {\"max_abs\": %.6e, \"max_rel\": %.6e}, "
        "\"dW2\": {\"max_abs\": %.6e, \"max_rel\": %.6e}, "
        "\"dx\": {\"max_abs\": %.6e, \"max_rel\": %.6e}, "
        "\"worst_rel\": %.6e, \"tol\": %.0e}\n",
        metal_env ? metal_env : "unset",
        s_y.max_abs,   s_y.max_rel,
        s_dW1.max_abs, s_dW1.max_rel,
        s_dW2.max_abs, s_dW2.max_rel,
        s_dx.max_abs,  s_dx.max_rel,
        worst, TOL);

    const char* verdict = (worst < TOL) ? "PASS" : "FAIL";
    fprintf(stdout,
        "F-RFC075-FLAME-AG-LINEAR-E2E-METAL-NUMERIC-EQ %s  "
        "metal=%s shape=B%lld·D%lld·H%lld·C%lld  "
        "y.max_rel=%.3e dW1.max_rel=%.3e dW2.max_rel=%.3e dx.max_rel=%.3e "
        "tol=%.0e\n",
        verdict, metal_env ? metal_env : "unset",
        (long long)B, (long long)D, (long long)H, (long long)Co,
        s_y.max_rel, s_dW1.max_rel, s_dW2.max_rel, s_dx.max_rel, TOL);
    (void)metal_on;
    return (worst < TOL) ? 0 : 1;
}
