// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4d7_block_fwd_primitive.c — Phase 4-D-7 GPU-RESIDENT
// A2 forward primitive.
//
// Forks tool/flame_phase4d6_block_fwd_primitive.c (dim-generic CPU-loop A2
// fwd). Phase 4-D-6's d768·12L GPU fire #5 engaged the GPU (435 MiB) but
// ran 0 steps in 600s — only matmul was GPU-routed; the A2 block's
// non-matmul CPU loops (RMSNorm, attention softmax, RoPE, SwiGLU, residual)
// dominate at d768 scale. See state/flame_phase4d6_gpu_fire_2026_05_17/
// PHASE4D6_GPU_FIRE_ANALYSIS.md §6.
//
// ── The Phase 4-D-7 4-part transformation (analysis §6) ──────────────────
//   1. Persistent device residency — Bp (weights) + Bc (cache) farr stay
//      resident on the device for the whole block; one farr_to_device per
//      farr, compute on device, one farr_to_host at the end.
//   2. Non-matmul ops → forge Phase B kernels — RMSNorm/softmax/SwiGLU/
//      residual dispatch to hexa_farr_{rmsnorm_rows,softmax_rows,silu,mul,
//      add}_gpu (verified byte-eq A100, Phase 4-D-5-3 11/11 PASS).
//   3. Attention Q·Kᵀ / P·V → cuBLAS — matmul-shaped, route to
//      hexa_farr_matmul_gpu (the per-head Gram + value-combine).
//   4. RoPE — the one missing forge kernel (RFC 041 did not ship it).
//      Until _hx_cuda_farr_rope_gpu lands, RoPE stays the documented
//      remaining CPU op (honest); everything else is GPU-routed.
//
// ── BYTE-EQ CONTRACT (d=32·3L) ───────────────────────────────────────────
// The d=32 config has T·d = 1024·... small shapes; per the matmul GPU
// threshold (FLAME_MATMUL_GPU_THRESHOLD 8192) and the new
// FLAME_GPU_RESIDENT_THRESHOLD (d²), at d=32 the GPU-resident path is NOT
// taken — the primitive falls through to the byte-identical CPU loop body
// copied verbatim from flame_phase4d6_block_fwd_primitive.c. So d=32·3L
// stays strictly byte-eq (F-RFC047-A2-PATHB-FULL-BYTE-EQ holds).
//
// At d≥768 the GPU-resident path activates: per PHASE4C audit §6 R1 the
// forge Phase B kernels are TOL_OP-verified (~1e-12, not bit-exact for
// reductions), so the d=768 numerical contract is TOL_OP ≈ 1e-9, NOT
// strict byte-eq — honest per RFC 040/041 measured tolerance.
//
// Calls the matmul primitives in flame_phase4d6_matmul_primitives.c
// (reused unchanged — they already carry the Layer-2 GPU dispatch).
// Concat that file FIRST.
// ════════════════════════════════════════════════════════════════════════

#ifndef FLAME_BLOCK_PRIM_STANDALONE
HexaVal _db_proj_batch_farr(HexaVal W, HexaVal W_off, HexaVal X, HexaVal X_off, HexaVal Y, HexaVal Y_off, HexaVal T, HexaVal d_out, HexaVal d_in);
#endif

#ifdef FLAME_BLOCK_PRIM_STANDALONE
#include <math.h>
#include <stdint.h>
#include <stddef.h>
typedef struct { int tag; union { int64_t i; double f; void* p; }; } HexaVal;
typedef struct { double* buf; long len; void* d_buf; int loc, pinned, dirty_host, dirty_dev; } HexaFarrEntry;
static HexaFarrEntry* _hx_farr_table = NULL;
static inline HexaVal hexa_int(int64_t n) { HexaVal v; v.tag = 1; v.i = n; return v; }
static HexaVal farr_zeros;
static HexaVal farr_free;
#define hexa_call1(f, a) ((HexaVal(*)(HexaVal))((f).p))(a)
void flame_proj_batch_generic_primitive(int,int,int,int,int,int,int,int,int);
#endif

// ── GPU-resident activation threshold ───────────────────────────────────
// The block's non-matmul ops route to forge Phase B kernels only when the
// per-row width d exceeds this. At d=32 the GPU-resident path is skipped
// (CPU loop = byte-eq); at d=768 it activates. Same spirit as
// FLAME_MATMUL_GPU_THRESHOLD (matmul-primitives.c) — small shapes stay CPU.
#ifndef FLAME_GPU_RESIDENT_THRESHOLD
#define FLAME_GPU_RESIDENT_THRESHOLD 256
#endif

// ── Ported transcendentals (mirror stdlib/flame/flame_math.hexa) ───
static inline double flame_g7_dt_sqrt(double x) {
    if (x <= 0.0) return 0.0;
    double g = (x > 1.0) ? x : 1.0;
    for (int i = 0; i < 24; i++) g = 0.5 * (g + x / g);
    return g;
}

static inline double flame_g7_dt_exp(double x) {
    int r = 0; double xr = x;
    while ((xr > 0.0 ? xr : -xr) > 0.25) { xr = xr / 2.0; r = r + 1; }
    double term = 1.0, acc = 1.0;
    for (int k = 1; k < 12; k++) { term = term * xr / (double)k; acc = acc + term; }
    for (int s = 0; s < r; s++) acc = acc * acc;
    return acc;
}

static inline double flame_g7_db_sigmoid(double x) {
    return 1.0 / (1.0 + flame_g7_dt_exp(0.0 - x));
}

static inline double flame_g7_db_silu(double x) {
    return x * flame_g7_db_sigmoid(x);
}

// ════════════════════════════════════════════════════════════════════════
// PART 1 — CPU-loop A2 fwd (byte-identical to flame_phase4d6 — d≤threshold)
// ════════════════════════════════════════════════════════════════════════
// Verbatim copy of flame_block_generic_fwd_primitive from
// flame_phase4d6_block_fwd_primitive.c. NO loop reordered, NO literal
// changed — this is the byte-eq d=32 path. The only delta from phase4d6
// is the function name (suffix _cpu) so it can be selected by the dim gate.
static inline void flame_block_generic_fwd_primitive_cpu(
    int X_id, int Bp_id, int Bc_id, int cos_id, int sin_id,
    int T, int d, int nh, int nkv, int h
) {
    const int hd = d / nh;            // head dim
    const int half = hd / 2;
    const int n_rep = nh / nkv;
    const int kvd = nkv * (d / nh);   // _kvd_of(d,nh,nkv)
    const double eps = 1e-6;
    const double scale = 1.0 / flame_g7_dt_sqrt((double)hd);

    // Bp offsets — bp_off_* formulas (decoder_block_lib.hexa:49-69).
    const int G1 = 0;
    const int WQ = d;
    const int WK = d + d*d;
    const int WV = d + d*d + kvd*d;
    const int WO = d + d*d + 2*kvd*d;
    const int G2 = d + 2*d*d + 2*kvd*d;
    const int WG = 2*d + 2*d*d + 2*kvd*d;
    const int WU = 2*d + 2*d*d + 2*kvd*d + h*d;
    const int WD = 2*d + 2*d*d + 2*kvd*d + 2*h*d;
    // Bc offsets — bc_off_* formulas (decoder_block_lib.hexa:75-103).
    const int oXout  = 0;
    const int oHstate= T*d;
    const int oRin   = 2*T*d;
    const int oRin2  = 3*T*d;
    const int oRm1xn = 4*T*d;
    const int oRm2xn = 5*T*d;
    const int oCtx   = 6*T*d;
    const int oQ     = 7*T*d;
    const int oK     = 8*T*d;
    const int oV     = 8*T*d + T*kvd;
    const int oP     = 8*T*d + 2*T*kvd;
    const int oSwA   = 8*T*d + 2*T*kvd + nh*T*T;
    const int oSwB   = 8*T*d + 2*T*kvd + nh*T*T + T*h;
    const int oSwS   = 8*T*d + 2*T*kvd + nh*T*T + 2*T*h;
    const int oR1inv = 8*T*d + 2*T*kvd + nh*T*T + 3*T*h;
    const int oR2inv = 8*T*d + 2*T*kvd + nh*T*T + 3*T*h + T;

    HexaVal qscr_v  = hexa_call1(farr_zeros, hexa_int(hd));
    HexaVal srow_v  = hexa_call1(farr_zeros, hexa_int(T));
    int qscr_id = (int)qscr_v.i, srow_id = (int)srow_v.i;

    double* X    = _hx_farr_table[X_id].buf;
    double* Bp   = _hx_farr_table[Bp_id].buf;
    double* Bc   = _hx_farr_table[Bc_id].buf;
    double* cos_ = _hx_farr_table[cos_id].buf;
    double* sin_ = _hx_farr_table[sin_id].buf;

    // ─── 1. per-position RMSNorm(X, g1) → rin, rm1xn, rm1inv ─────
    for (int i = 0; i < T; i++) {
        double ms = 0.0;
        for (int c = 0; c < d; c++) {
            double xi = X[i * d + c];
            ms = ms + xi * xi;
        }
        ms = ms / (double)d;
        double inv = 1.0 / flame_g7_dt_sqrt(ms + eps);
        Bc[oR1inv + i] = inv;
        for (int c2 = 0; c2 < d; c2++) {
            double xni = X[i * d + c2] * inv;
            Bc[oRm1xn + i * d + c2] = xni;
            Bc[oRin + i * d + c2] = Bp[G1 + c2] * xni;
        }
    }

    // ─── 2. Q/K/V projections — generic matmul primitive ─────────
    flame_proj_batch_generic_primitive(Bp_id, WQ, Bc_id, oRin, Bc_id, oQ, T, d,   d);
    flame_proj_batch_generic_primitive(Bp_id, WK, Bc_id, oRin, Bc_id, oK, T, kvd, d);
    flame_proj_batch_generic_primitive(Bp_id, WV, Bc_id, oRin, Bc_id, oV, T, kvd, d);
    Bc = _hx_farr_table[Bc_id].buf;

    // ─── 3. RoPE rotation on Q (nh heads) + K (nkv heads) ────────
    {
        double* q_scratch = _hx_farr_table[qscr_id].buf;
        for (int t_r2 = 0; t_r2 < T; t_r2++) {
            int bse = t_r2 * hd;
            for (int hh2 = 0; hh2 < nh; hh2++) {
                int row_off = oQ + (t_r2 * nh + hh2) * hd;
                for (int c = 0; c < hd; c++) {
                    double rh_c = (c < half)
                        ? (0.0 - Bc[row_off + half + c])
                        : Bc[row_off + c - half];
                    q_scratch[c] = Bc[row_off + c] * cos_[bse + c]
                                 + rh_c * sin_[bse + c];
                }
                for (int c3 = 0; c3 < hd; c3++) {
                    Bc[row_off + c3] = q_scratch[c3];
                }
            }
            for (int hk = 0; hk < nkv; hk++) {
                int row_off_k = oK + (t_r2 * nkv + hk) * hd;
                for (int c = 0; c < hd; c++) {
                    double rh_c = (c < half)
                        ? (0.0 - Bc[row_off_k + half + c])
                        : Bc[row_off_k + c - half];
                    q_scratch[c] = Bc[row_off_k + c] * cos_[bse + c]
                                 + rh_c * sin_[bse + c];
                }
                for (int c3 = 0; c3 < hd; c3++) {
                    Bc[row_off_k + c3] = q_scratch[c3];
                }
            }
        }
    }

    // ─── 4. attention core (causal GQA scaled-dot + softmax + value) ─
    {
        double* srow_at = _hx_farr_table[srow_id].buf;
        for (int hh_a = 0; hh_a < nh; hh_a++) {
            int kvh = hh_a / n_rep;
            for (int i_a = 0; i_a < T; i_a++) {
                int L = i_a + 1;
                for (int j = 0; j < L; j++) {
                    double dot = 0.0;
                    for (int c = 0; c < hd; c++) {
                        dot = dot + Bc[oQ + (i_a * nh + hh_a) * hd + c]
                                  * Bc[oK + (j * nkv + kvh) * hd + c];
                    }
                    srow_at[j] = dot * scale;
                }
                double m_max = srow_at[0];
                for (int jj = 1; jj < L; jj++) {
                    if (srow_at[jj] > m_max) m_max = srow_at[jj];
                }
                double tot = 0.0;
                for (int jj2 = 0; jj2 < L; jj2++) {
                    double e = flame_g7_dt_exp(srow_at[jj2] - m_max);
                    Bc[oP + (hh_a * T + i_a) * T + jj2] = e;
                    tot = tot + e;
                }
                for (int jj3 = 0; jj3 < L; jj3++) {
                    Bc[oP + (hh_a * T + i_a) * T + jj3] /= tot;
                }
                for (int c_v = 0; c_v < hd; c_v++) {
                    double acc = 0.0;
                    for (int j_v = 0; j_v < L; j_v++) {
                        acc = acc + Bc[oP + (hh_a * T + i_a) * T + j_v]
                                  * Bc[oV + (j_v * nkv + kvh) * hd + c_v];
                    }
                    Bc[oCtx + i_a * d + hh_a * hd + c_v] = acc;
                }
            }
        }
    }

    // ─── 5. output projection: attn_out = Wo · ctx ───────────────
    HexaVal attn_out_v = hexa_call1(farr_zeros, hexa_int(T * d));
    int attn_out_id = (int)attn_out_v.i;
    flame_proj_batch_generic_primitive(Bp_id, WO, Bc_id, oCtx, attn_out_id, 0, T, d, d);
    Bc = _hx_farr_table[Bc_id].buf;
    double* attn_out = _hx_farr_table[attn_out_id].buf;
    X = _hx_farr_table[X_id].buf;

    // ─── 6. residual: hstate = X + attn_out ──────────────────────
    for (int idx = 0; idx < T * d; idx++) {
        Bc[oHstate + idx] = X[idx] + attn_out[idx];
    }
    hexa_call1(farr_free, attn_out_v);

    // ─── 7. per-position RMSNorm(hstate, g2) → rin2, rm2xn, rm2inv ─
    Bc = _hx_farr_table[Bc_id].buf;
    Bp = _hx_farr_table[Bp_id].buf;
    for (int i2 = 0; i2 < T; i2++) {
        double ms = 0.0;
        for (int c = 0; c < d; c++) {
            double xi = Bc[oHstate + i2 * d + c];
            ms = ms + xi * xi;
        }
        ms = ms / (double)d;
        double inv = 1.0 / flame_g7_dt_sqrt(ms + eps);
        Bc[oR2inv + i2] = inv;
        for (int c2 = 0; c2 < d; c2++) {
            double xni = Bc[oHstate + i2 * d + c2] * inv;
            Bc[oRm2xn + i2 * d + c2] = xni;
            Bc[oRin2 + i2 * d + c2] = Bp[G2 + c2] * xni;
        }
    }

    // ─── 8. SwiGLU: a, b matmul + silu+Hadamard + o matmul ───────
    flame_proj_batch_generic_primitive(Bp_id, WG, Bc_id, oRin2, Bc_id, oSwA, T, h, d);
    flame_proj_batch_generic_primitive(Bp_id, WU, Bc_id, oRin2, Bc_id, oSwB, T, h, d);
    Bc = _hx_farr_table[Bc_id].buf;
    for (int ts = 0; ts < T; ts++) {
        for (int k = 0; k < h; k++) {
            double av = Bc[oSwA + ts * h + k];
            double bv = Bc[oSwB + ts * h + k];
            Bc[oSwS + ts * h + k] = flame_g7_db_silu(av) * bv;
        }
    }
    HexaVal sw_o_v = hexa_call1(farr_zeros, hexa_int(T * d));
    int sw_o_id = (int)sw_o_v.i;
    flame_proj_batch_generic_primitive(Bp_id, WD, Bc_id, oSwS, sw_o_id, 0, T, d, h);
    Bc = _hx_farr_table[Bc_id].buf;
    double* sw_o = _hx_farr_table[sw_o_id].buf;

    // ─── 9. residual: Xout = hstate + sw_o ───────────────────────
    for (int idx2 = 0; idx2 < T * d; idx2++) {
        Bc[oXout + idx2] = Bc[oHstate + idx2] + sw_o[idx2];
    }
    hexa_call1(farr_free, sw_o_v);
    hexa_call1(farr_free, srow_v);
    hexa_call1(farr_free, qscr_v);
}

#ifndef FLAME_BLOCK_PRIM_STANDALONE
// ════════════════════════════════════════════════════════════════════════
// PART 2 — GPU-RESIDENT A2 fwd (d≥threshold path)
// ════════════════════════════════════════════════════════════════════════
// The forge Phase B `*_gpu` dispatchers are declared in runtime.c (already
// concat'd ahead of this file): hexa_farr_{rmsnorm_rows,softmax_rows,silu,
// mul,add,matmul}_gpu. Each:
//   - takes input farr_id(s) + dims as hexa_int args,
//   - allocates a fresh output farr (hexa_farr_zeros),
//   - returns the output farr_id as hexa_int (-1 on error),
//   - on HEXA_CUDA uploads/computes/downloads; on no-CUDA runs the CPU
//     oracle (so the host-side build stays valid + byte-eq vs the CPU
//     reference for the kernels it can verify on Mac).
//
// ── Persistent device residency ──────────────────────────────────────────
// At block entry we call hexa_farr_to_device on the four block-scoped
// farrs (X, Bp, Bc, cos, sin). On HEXA_CUDA this is a one-shot H2D upload
// and the mirror flag (FARR_MIRRORED) keeps the device copy authoritative
// for the rest of the block; the forge `*_gpu` dispatchers each ensure
// device residency idempotently (no-op if already resident). At block exit
// hexa_farr_to_host(Bc) brings the result back ONCE. On the no-CUDA Mac
// build both calls are inert no-op-success — the residency model is a
// HEXA_CUDA-only fast path, never changing the no-CUDA numerics.
//
// This eliminates the flame_proj_gpu_matmul_g per-call H2D/D2H/free
// pattern for the NON-matmul ops: RMSNorm/softmax/SwiGLU/residual now run
// as a device-side kernel sequence on the already-resident buffers.
//
// ── What is GPU-resident here ─────────────────────────────────────────────
//   RMSNorm fwd (steps 1 & 7)  → hexa_farr_rmsnorm_rows_gpu + _mul_gpu (γ)
//   Q/K/V/O/G/U/D projections  → flame_proj_batch_generic_primitive (cuBLAS)
//   attention Q·Kᵀ, P·V        → hexa_farr_matmul_gpu (per (head,row))
//   softmax                    → hexa_farr_softmax_rows_gpu
//   SwiGLU                     → hexa_farr_silu_gpu + hexa_farr_mul_gpu
//   residual add (6 & 9)       → hexa_farr_add_gpu
//   RoPE (step 3)              → REMAINS CPU — forge kernel not yet shipped
//                                (RFC 041 gap; honest documented carve-out)
// ════════════════════════════════════════════════════════════════════════

// Forward decls of the forge Phase B dispatchers (defined in runtime.c).
HexaVal hexa_farr_to_device(HexaVal h_v);
HexaVal hexa_farr_to_host(HexaVal h_v);
HexaVal hexa_farr_zeros(HexaVal n_v);
HexaVal hexa_farr_free(HexaVal h_v);
HexaVal hexa_farr_rmsnorm_rows_gpu(HexaVal x_v, HexaVal r_v, HexaVal c_v, HexaVal eps_v);
HexaVal hexa_farr_softmax_rows_gpu(HexaVal x_v, HexaVal r_v, HexaVal c_v);
HexaVal hexa_farr_silu_gpu(HexaVal x_v, HexaVal n_v);
HexaVal hexa_farr_mul_gpu(HexaVal a_v, HexaVal b_v, HexaVal n_v);
HexaVal hexa_farr_add_gpu(HexaVal a_v, HexaVal b_v, HexaVal n_v);
HexaVal hexa_farr_matmul_gpu(HexaVal a_v, HexaVal ar_v, HexaVal ac_v, HexaVal b_v, HexaVal bc_v);
HexaVal hexa_farr_rope_gpu(HexaVal t_v, HexaVal cos_v, HexaVal sin_v, HexaVal T_v, HexaVal nh_v, HexaVal hd_v);
// RFC 056 Phase 1 — device residence contract + sub-view API (host C
// shims in runtime.c; no-CUDA Mac = inert no-ops, d=32·3L _cpu path
// untouched → F-RFC056-D32-BYTEEQ holds by construction).
HexaVal hexa_farr_pin_device(HexaVal h_v);
HexaVal hexa_farr_unpin_device(HexaVal h_v);
HexaVal hexa_farr_dev_view(HexaVal base_v, HexaVal off_v, HexaVal len_v);
HexaVal hexa_farr_set_out_disposition(HexaVal d_v);

// ── flame Phase 4-D-9 §3/§4-gap#1 — causal-masked softmax forge kernel ──
// The attention block's per-row causal-prefix softmax (step 4) was a HOST
// loop (flame_g7_dt_exp over [0,L), L=i+1). PHASE4D9_DEVICE_CHAIN_DESIGN.md
// §4 names it as the missing byte-eq-verified forge kernel; RFC 058's 14th
// ADDITIVE kernel _hx_cuda_kern_causal_softmax_rows (runtime_cuda.c:768,
// FORBIDDEN to modify — only called here) is that kernel: it ports
// flame_g7_dt_exp VERBATIM (_hx_dt_exp_dev, same constants/loop-bounds/
// order) and reduces m_max/tot with the SAME deterministic block tree as
// the 12 verified Phase-B kernels, so the only residual gap vs the CPU
// reference is the ~1e-12 reduction reorder — measured by the standalone
// instrument tool/flame_phase4d9_causal_softmax_oracle (PASS max|Δ|=0.0
// strict / 2.776e-17 GPU). Output Y[i*T+j] = softmax over the causal
// prefix [0,i+1) and EXACTLY 0.0 for j ≥ i+1 — which is byte-identically
// the masked P-matrix the P·V cuBLAS Dgemm consumes (the host code rebuilt
// that mask in a second loop; the kernel output IS it). There is NO
// hexa_farr_causal_softmax_rows_gpu shim in runtime.c / the oracle harness
// (both FORBIDDEN to touch), so — exactly as the matmul primitive calls
// the RFC 058 transpose-scatter kernel — we declare the _hx_cuda_* extern
// directly under the extern "C" linkage contract (mirrors runtime_cuda.c
// :45/:1913 — a missing guard MANGLES the symbol under the --cuda
// nvcc/C++ front-end; that exact link error already cost one fire) and
// supply a thin file-local wrapper. d ≤ FLAME_GPU_RESIDENT_THRESHOLD takes
// the _cpu path (this whole region is dim-gated + #ifndef
// FLAME_BLOCK_PRIM_STANDALONE) so d=32·3L is byte-eq by construction;
// no-CUDA Mac → the wrapper returns -1 and the verbatim host softmax
// fallback runs (identical numerics to the pre-conversion body).
#ifdef HEXA_CUDA
#ifdef __cplusplus
extern "C" {
#endif
extern int _hx_cuda_farr_causal_softmax_rows_gpu(int64_t x_id, int64_t R,
                                                 int64_t T, int64_t out_id);
#ifdef __cplusplus
}  /* extern "C" */
#endif
#endif  // HEXA_CUDA

// causal_softmax_rows: caller-allocates the [R·T] output farr (hexa_farr_
// zeros), the forge kernel fills row i with softmax over [0,i+1) and 0.0
// for j ≥ i+1. Returns the output farr-id, or -1 (no-CUDA / dispatch
// fail) → caller runs the verbatim host softmax fallback. Mirrors the
// runtime.c hexa_farr_transpose_scatter_gpu wrapper shape (validate →
// HEXA_CUDA dispatch → -1 on the no-CUDA build).
static int flame_g7_causal_softmax_rows_gpu(int x_id, int R, int Tt) {
#ifdef HEXA_CUDA
    if (R <= 0 || Tt <= 0) return -1;
    HexaVal o_v = hexa_farr_zeros(hexa_int((int64_t)R * Tt));
    int o_id = (int)o_v.i;
    if (o_id < 0) return -1;
    if (_hx_cuda_farr_causal_softmax_rows_gpu(
            (int64_t)x_id, (int64_t)R, (int64_t)Tt, (int64_t)o_id) != 0) {
        hexa_farr_free(o_v);
        return -1;
    }
    return o_id;
#else
    (void)x_id; (void)R; (void)Tt;
    return -1;  // no-CUDA: caller takes the verbatim host softmax fallback
#endif
}

// ════════════════════════════════════════════════════════════════════════
// flame Phase 4-D-9 — A2 resident-dataflow rewire (RFC 056 §6.5 consumer)
// ════════════════════════════════════════════════════════════════════════
// fire #9 isolated the d768·12L wall as STRUCTURAL per-op H2D round-trip +
// CPU glue (PHASE4D7_FIRE9_ANALYSIS.md §3); RFC 056 Phase 1 (`1f077af1`)
// landed the substrate residence API; this is the consumer-side §6.5 work.
//
// ── The byte-safe resident-chaining mechanism (substrate-as-verified) ──
// RFC 056 §6.1 H2D-skip (runtime_cuda.c:182-195): a forge `_gpu` op whose
// input farr is loc∈{DEVICE,MIRRORED} && !dirty_host && a live device slot
// of matching len SKIPs the cudaMemcpy H2D — the device bytes already
// equal what the copy would write (authoritative path produced them, host
// untouched since). Provably byte-eq (F-RFC056-BYTEEQ-PRESERVE max|Δ|=0).
//
// A forge op output under the DEFAULT disposition (FORGE_OUT_HOST_NOW)
// leaves its fresh farr at loc=FARR_MIRRORED, dirty_host=0, with the
// device slot live (runtime_cuda.c:620-624). Therefore: if that EXACT
// farr-id is passed straight to the NEXT forge op WITHOUT any host-side
// write to its buffer in between, the next op's _h2d hits the §6.1 skip —
// the (dominant, activation-slab-sized) re-upload is elided. This needs
// NO substrate edit and NO FORGE_OUT_DEVICE_KEEP.
//
// HONEST substrate constraint (g3): FORGE_OUT_DEVICE_KEEP additionally
// skips the D2H but `_d2h_out` then sets dirty_host=1 (runtime_cuda.c:608)
// — which DEFEATS the §6.1 skip on the very next op (it requires
// !dirty_host) → that op would re-upload the STALE host buffer (wrong
// bytes, not just slow). So DEVICE_KEEP by-id chaining is NOT byte-safe
// with the verified-oracle substrate as-is; the byte-safe lever is
// id-chaining under the DEFAULT disposition (re-upload elided, the
// smaller output-sized D2H retained). This is the precise scope verdict.
//
// What this rewire lands (byte-safe, no substrate touch):
//   • SwiGLU fwd: silu_gpu → mul_gpu chained by farr-id (silu output
//     stays resident for the Hadamard; its re-upload elided).
//   • RMSNorm fwd: rmsnorm_rows_gpu → mul_gpu(γ) — the normalized-rows
//     intermediate xn is consumed by-id with no host write between, so
//     its re-upload is already §6.1-elided; the γ-broadcast and the
//     stash reads do not dirty it.
// d=32·3L is unaffected (d ≤ FLAME_GPU_RESIDENT_THRESHOLD → the _cpu
// path; this whole TU region is #ifndef FLAME_BLOCK_PRIM_STANDALONE +
// the GPU body is dim-gated) → F-RFC056-D32-BYTEEQ byte-eq by
// construction. No-CUDA Mac: every forge `_gpu` is the CPU oracle and
// the disposition register is inert (runtime.c) → identical numerics.

// ── Phase 4-D-8: redundant pre-op H2D elision (byte-eq-exact) ────────────
// Every scratch farr below is built host-side and then immediately passed
// to a forge `*_gpu` op. The forge substrate (self/cuda/runtime_cuda.c)
// uploads each op input UNCONDITIONALLY via the internal `_h2d` helper
// (runtime_cuda.c:110 — always cudaMemcpy H2D; it has NO residence-skip,
// it only CLEARS dirty_dev/loc AFTER the copy, never gates ON them). So
// the explicit `hexa_farr_to_device(scratch)` that precedes each `*_gpu`
// call is a SECOND, fully redundant cudaMemcpy of the identical (size-
// unchanged → no realloc) buffer. Eliding it is byte-eq-EXACT: the forge
// op's own `_h2d` performs the authoritative upload from the same,
// host-unmutated buffer, so the resulting device bytes are bit-identical;
// the only removed effect is the duplicate PCIe transfer (~halves the H2D
// traffic for every non-cuBLAS op: RMSNorm/RoPE/silu/mul/add/softmax).
// This is NOT "true persistent residency" — the host stays authoritative
// and every op still round-trips ONCE (see PHASE4D8 analysis §"scope").
// It is the byte-eq-safe primitive-discipline win available at $0 Mac.
// No-CUDA Mac build: hexa_farr_to_device is already a no-op (returns 1) so
// this macro changes nothing there — d=32·3L is the _cpu path regardless.
#define hexa_farr_to_device(h) ((void)0)

// ── GPU-resident row-RMSNorm with per-channel gain ──────────────────────
// Computes, for each of T rows of width d:  out[i·d+c] = γ[c] · x̂[i·d+c]
// where x̂ = x / sqrt(mean(x²)+eps). The gain-free normalize is the forge
// rmsnorm_rows kernel; γ is broadcast-multiplied row-wise. Also stashes the
// pre-gain normalized rows (rm_xn) needed by the bwd primitive and the
// per-row inv-rms (r_inv) — both written into the resident Bc cache.
//
// gain γ lives at Bp[g_off .. g_off+d), the d-vector. rmsnorm_rows_gpu
// expects a contiguous [R·C] input — we pass the T·d slab starting at
// src_off in src_id; it returns a fresh [T·d] normalized farr.
static void flame_g7_rmsnorm_resident(
    int src_id, int src_off, int Bp_id, int g_off,
    int Bc_id, int rin_off, int rmxn_off, int rinv_off,
    int T, int d
) {
    const double eps = 1e-6;
    // Build a contiguous [T·d] view of the src slab (src is X or Bc[hstate]).
    HexaVal slab_v = hexa_farr_zeros(hexa_int((int64_t)T * d));
    int slab_id = (int)slab_v.i;
    {
        double* src = _hx_farr_table[src_id].buf;
        double* slab = _hx_farr_table[slab_id].buf;
        for (int p = 0; p < T * d; p++) slab[p] = src[src_off + p];
    }
    hexa_farr_to_device(slab_v);
    // gain-free normalized rows x̂  (forge rmsnorm_rows kernel)
    // BYTE-EQ FIX (block oracle 1st real catch, 2026-05-18): the 4th arg
    // is eps. It was hexa_int(0) → the forge kernel computed
    // x̂ = x/√(mean(x²)+0), but the _cpu reference AND this fn's own r_inv
    // recompute (below) use flame_g7_dt_sqrt(ms + eps) with eps=1e-6. The
    // block-fwd GPU oracle localised the divergence to oRin (max|Δ|=1.704e-1
    // — eps=0 blows up on rows with mean(x²)≈0, a strong root-cause
    // candidate for the 15-fire d768 -nan/gn2-drift). Pass the real eps as
    // a TAG_FLOAT HexaVal (the shim does __hx_to_double(eps_v); an int 0
    // can never carry 1e-6) so x̂ matches the reference and r_inv.
    HexaVal xn_v = hexa_farr_rmsnorm_rows_gpu(
        hexa_int(slab_id), hexa_int(T), hexa_int(d), hexa_float(eps));
    int xn_id = (int)xn_v.i;
    if (xn_id < 0) {  // forge dispatch failed — fall back to CPU normalize
        double* slab = _hx_farr_table[slab_id].buf;
        double* Bc   = _hx_farr_table[Bc_id].buf;
        double* Bp   = _hx_farr_table[Bp_id].buf;
        for (int i = 0; i < T; i++) {
            double ms = 0.0;
            for (int c = 0; c < d; c++) { double xi = slab[i*d+c]; ms += xi*xi; }
            ms /= (double)d;
            double inv = 1.0 / flame_g7_dt_sqrt(ms + eps);
            Bc[rinv_off + i] = inv;
            for (int c = 0; c < d; c++) {
                double xni = slab[i*d+c] * inv;
                Bc[rmxn_off + i*d + c] = xni;
                Bc[rin_off + i*d + c]  = Bp[g_off + c] * xni;
            }
        }
        hexa_farr_free(slab_v);
        return;
    }
    // r_inv per row — recompute Σx² (the forge kernel does not export it);
    // this is a cheap T-row reduction, NOT the d-dominated normalize loop.
    {
        double* slab = _hx_farr_table[slab_id].buf;
        double* Bc   = _hx_farr_table[Bc_id].buf;
        for (int i = 0; i < T; i++) {
            double ms = 0.0;
            for (int c = 0; c < d; c++) { double xi = slab[i*d+c]; ms += xi*xi; }
            ms /= (double)d;
            Bc[rinv_off + i] = 1.0 / flame_g7_dt_sqrt(ms + eps);
        }
    }
    // stash x̂ into rm_xn slot
    {
        double* xn = _hx_farr_table[xn_id].buf;
        double* Bc = _hx_farr_table[Bc_id].buf;
        for (int p = 0; p < T * d; p++) Bc[rmxn_off + p] = xn[p];
    }
    // rin = γ ⊙ x̂  — broadcast γ across T rows, then forge mul kernel.
    HexaVal gbc_v = hexa_farr_zeros(hexa_int((int64_t)T * d));
    int gbc_id = (int)gbc_v.i;
    {
        double* Bp  = _hx_farr_table[Bp_id].buf;
        double* gbc = _hx_farr_table[gbc_id].buf;
        for (int i = 0; i < T; i++)
            for (int c = 0; c < d; c++) gbc[i*d + c] = Bp[g_off + c];
    }
    hexa_farr_to_device(gbc_v);
    HexaVal rin_v = hexa_farr_mul_gpu(hexa_int(xn_id), hexa_int(gbc_id),
                                      hexa_int((int64_t)T * d));
    int rin_id = (int)rin_v.i;
    if (rin_id >= 0) {
        double* rin = _hx_farr_table[rin_id].buf;
        double* Bc  = _hx_farr_table[Bc_id].buf;
        for (int p = 0; p < T * d; p++) Bc[rin_off + p] = rin[p];
        hexa_farr_free(rin_v);
    } else {  // mul dispatch failed — CPU broadcast multiply
        double* xn  = _hx_farr_table[xn_id].buf;
        double* Bp  = _hx_farr_table[Bp_id].buf;
        double* Bc  = _hx_farr_table[Bc_id].buf;
        for (int i = 0; i < T; i++)
            for (int c = 0; c < d; c++)
                Bc[rin_off + i*d + c] = Bp[g_off + c] * xn[i*d + c];
    }
    hexa_farr_free(gbc_v);
    hexa_farr_free(xn_v);
    hexa_farr_free(slab_v);
}

// ── GPU-resident A2 forward (d≥threshold) ───────────────────────────────
static void flame_block_generic_fwd_primitive_gpu(
    int X_id, int Bp_id, int Bc_id, int cos_id, int sin_id,
    int T, int d, int nh, int nkv, int h
) {
    const int hd = d / nh;
    const int half = hd / 2;
    const int n_rep = nh / nkv;
    const int kvd = nkv * (d / nh);
    const double scale = 1.0 / flame_g7_dt_sqrt((double)hd);

    const int G1 = 0;
    const int WQ = d;
    const int WK = d + d*d;
    const int WV = d + d*d + kvd*d;
    const int WO = d + d*d + 2*kvd*d;
    const int G2 = d + 2*d*d + 2*kvd*d;
    const int WG = 2*d + 2*d*d + 2*kvd*d;
    const int WU = 2*d + 2*d*d + 2*kvd*d + h*d;
    const int WD = 2*d + 2*d*d + 2*kvd*d + 2*h*d;
    const int oXout  = 0;
    const int oHstate= T*d;
    const int oRin   = 2*T*d;
    const int oRin2  = 3*T*d;
    const int oRm1xn = 4*T*d;
    const int oRm2xn = 5*T*d;
    const int oCtx   = 6*T*d;
    const int oQ     = 7*T*d;
    const int oK     = 8*T*d;
    const int oV     = 8*T*d + T*kvd;
    const int oP     = 8*T*d + 2*T*kvd;
    const int oSwA   = 8*T*d + 2*T*kvd + nh*T*T;
    const int oSwB   = 8*T*d + 2*T*kvd + nh*T*T + T*h;
    const int oSwS   = 8*T*d + 2*T*kvd + nh*T*T + 2*T*h;
    const int oR1inv = 8*T*d + 2*T*kvd + nh*T*T + 3*T*h;
    const int oR2inv = 8*T*d + 2*T*kvd + nh*T*T + 3*T*h + T;

    // ── PART 1: residence-state contract (FIRE7 d2h-state-mismatch fix) ──
    // The original design called hexa_farr_to_device on the long-lived
    // block farrs (X/Bp/Bc/cos/sin) at entry and hexa_farr_to_host(Bc) at
    // exit, asserting a "persistent device residency" model. But the actual
    // dataflow never used it: every GPU sub-op below (the forge `*_gpu`
    // kernels and the cuBLAS matmul/proj primitives) is SELF-CONTAINED — it
    // builds a FRESH scratch farr, does its OWN _h2d on that scratch input,
    // computes, and _d2h_out's into the scratch's host buffer; the primitive
    // then copies the result HOST-SIDE into Bc.buf. So Bc/X/... are only
    // ever read/written through their HOST buffers here.
    //
    // The block-level to_device/to_host calls were therefore not just inert
    // for the compute — they were ACTIVELY HARMFUL on -DHEXA_CUDA:
    //   • the scratch farrs cycle through hexa_farr_zeros/_free, and (under
    //     -DHEXA_CUDA) hexa_farr_free → _hx_cuda_farr_device_free zeros that
    //     id's g_slots entry; hexa_farr_zeros then RE-USES freed ids from the
    //     freelist. Across training steps Bc/dX_out/Bg ids are themselves
    //     freed+reallocated, so the entry-time _h2d device snapshot for Bc
    //     goes stale while the primitive keeps mutating Bc.buf host-side.
    //   • the exit hexa_farr_to_host(Bc) then either (a) copies that STALE
    //     entry-time device buffer back OVER the freshly-computed host Bc
    //     (silent corruption), or (b) hits `!s->d_buf || s->len != e->len`
    //     and prints `[cuda] d2h: state mismatch id=…` (FIRE7 ids 11/12/16
    //     = the long-lived Bc / dX_out / Bg handles whose g_slots slot was
    //     never (re)synced to match their freelist-reused host entry).
    // The forge substrate (runtime.c / runtime_cuda.c) is verified-correct;
    // the bug is purely this primitive's residence call discipline. The
    // correct contract for host-accumulated farrs is: DO NOT assert a
    // device-resident copy of them at the block boundary — each sub-op
    // owns its own scratch residency, and Bc/X/… stay authoritative on the
    // host. (No-CUDA Mac build: these calls were inert no-ops anyway, and
    // d=32·3L takes the _cpu path which never had them — byte-eq intact.)

    // ── RFC 056 §6.3 residence anchor — pin model weights (Bp) + the
    //    block cache (Bc) device-resident ONCE at block entry. With Bp/Bc
    //    pinned, every forge `_gpu` op that takes a slice/view of them
    //    hits the §6.1 H2D-skip (loc∈{DEVICE,MIRRORED} && !dirty_host →
    //    no re-upload) instead of the structural per-op round-trip fire
    //    #9 measured. This is byte-eq-SAFE: pin only does the H2D + sets
    //    the non-evict flag; the host buffers remain authoritative for
    //    the (unchanged) host-side copy-back dataflow, so output bytes
    //    are bit-identical to pre-RFC-056 (F-RFC056-BYTEEQ-PRESERVE).
    //    No-CUDA Mac: hexa_farr_pin_device just records pinned=1 (no
    //    device) — inert, d=32·3L _cpu path never reaches this fn.
    (void)hexa_farr_pin_device(hexa_int(Bp_id));
    (void)hexa_farr_pin_device(hexa_int(Bc_id));

    // ─── 1. RMSNorm(X, g1) → rin / rm1xn / r1inv  (forge kernel) ──
    flame_g7_rmsnorm_resident(X_id, 0, Bp_id, G1,
                              Bc_id, oRin, oRm1xn, oR1inv, T, d);

    // ─── 2. Q/K/V projections — cuBLAS via matmul primitive ──────
    flame_proj_batch_generic_primitive(Bp_id, WQ, Bc_id, oRin, Bc_id, oQ, T, d,   d);
    flame_proj_batch_generic_primitive(Bp_id, WK, Bc_id, oRin, Bc_id, oK, T, kvd, d);
    flame_proj_batch_generic_primitive(Bp_id, WV, Bc_id, oRin, Bc_id, oV, T, kvd, d);

    // ─── 3. RoPE rotation — forge RoPE kernel (landed commit 9582a395) ─
    // Q-block is [T·nh·hd] contiguous at oQ, K-block [T·nkv·hd] at oK —
    // exactly the [T·nheads·hd] layout hexa_farr_rope_gpu expects. We
    // build a contiguous slab, dispatch the GPU rope kernel, write back.
    {
        // Q rotation: [T·nh·hd] slab.
        HexaVal qs_v = hexa_farr_zeros(hexa_int((int64_t)T * nh * hd));
        int qs_id = (int)qs_v.i;
        {
            double* Bc = _hx_farr_table[Bc_id].buf;
            double* qs = _hx_farr_table[qs_id].buf;
            for (int p = 0; p < T * nh * hd; p++) qs[p] = Bc[oQ + p];
        }
        hexa_farr_to_device(qs_v);
        HexaVal qr_v = hexa_farr_rope_gpu(hexa_int(qs_id), hexa_int(cos_id),
            hexa_int(sin_id), hexa_int(T), hexa_int(nh), hexa_int(hd));
        int qr_id = (int)qr_v.i;
        if (qr_id >= 0) {
            double* qr = _hx_farr_table[qr_id].buf;
            double* Bc = _hx_farr_table[Bc_id].buf;
            for (int p = 0; p < T * nh * hd; p++) Bc[oQ + p] = qr[p];
            hexa_farr_free(qr_v);
        } else {  // CPU fallback rope rotation (Q)
            double* Bc   = _hx_farr_table[Bc_id].buf;
            double* cos_ = _hx_farr_table[cos_id].buf;
            double* sin_ = _hx_farr_table[sin_id].buf;
            for (int t_r2 = 0; t_r2 < T; t_r2++) {
                int bse = t_r2 * hd;
                for (int hh2 = 0; hh2 < nh; hh2++) {
                    int row_off = oQ + (t_r2 * nh + hh2) * hd;
                    double tmp[256];
                    for (int c = 0; c < hd; c++) {
                        double rh_c = (c < half)
                            ? (0.0 - Bc[row_off + half + c])
                            : Bc[row_off + c - half];
                        tmp[c] = Bc[row_off + c] * cos_[bse + c]
                               + rh_c * sin_[bse + c];
                    }
                    for (int c3 = 0; c3 < hd; c3++) Bc[row_off + c3] = tmp[c3];
                }
            }
        }
        hexa_farr_free(qs_v);
        // K rotation: [T·nkv·hd] slab.
        HexaVal ks_v = hexa_farr_zeros(hexa_int((int64_t)T * nkv * hd));
        int ks_id = (int)ks_v.i;
        {
            double* Bc = _hx_farr_table[Bc_id].buf;
            double* ks = _hx_farr_table[ks_id].buf;
            for (int p = 0; p < T * nkv * hd; p++) ks[p] = Bc[oK + p];
        }
        hexa_farr_to_device(ks_v);
        HexaVal kr_v = hexa_farr_rope_gpu(hexa_int(ks_id), hexa_int(cos_id),
            hexa_int(sin_id), hexa_int(T), hexa_int(nkv), hexa_int(hd));
        int kr_id = (int)kr_v.i;
        if (kr_id >= 0) {
            double* kr = _hx_farr_table[kr_id].buf;
            double* Bc = _hx_farr_table[Bc_id].buf;
            for (int p = 0; p < T * nkv * hd; p++) Bc[oK + p] = kr[p];
            hexa_farr_free(kr_v);
        } else {  // CPU fallback rope rotation (K)
            double* Bc   = _hx_farr_table[Bc_id].buf;
            double* cos_ = _hx_farr_table[cos_id].buf;
            double* sin_ = _hx_farr_table[sin_id].buf;
            for (int t_r2 = 0; t_r2 < T; t_r2++) {
                int bse = t_r2 * hd;
                for (int hk = 0; hk < nkv; hk++) {
                    int row_off_k = oK + (t_r2 * nkv + hk) * hd;
                    double tmp[256];
                    for (int c = 0; c < hd; c++) {
                        double rh_c = (c < half)
                            ? (0.0 - Bc[row_off_k + half + c])
                            : Bc[row_off_k + c - half];
                        tmp[c] = Bc[row_off_k + c] * cos_[bse + c]
                               + rh_c * sin_[bse + c];
                    }
                    for (int c3 = 0; c3 < hd; c3++) Bc[row_off_k + c3] = tmp[c3];
                }
            }
        }
        hexa_farr_free(ks_v);
    }

    // ─── 4. attention — Q·Kᵀ → softmax → P·V  (cuBLAS + forge softmax) ─
    // For each head we build the L×hd Q-block and L×hd K-block (causal,
    // L = i+1 grows per row) and dispatch the score matmul + softmax +
    // value matmul to the GPU. The per-(head,row) growing-L causal mask
    // forces a per-row dispatch; the score / value contractions
    // themselves are the GPU-routed work.
    {
        for (int hh_a = 0; hh_a < nh; hh_a++) {
            int kvh = hh_a / n_rep;
            // full-T score matrix for this head: scores[i·T+j], i≥j only
            HexaVal sc_v = hexa_farr_zeros(hexa_int((int64_t)T * T));
            int sc_id = (int)sc_v.i;
            // Q-block [T·hd] and K-block [T·hd] for this head, contiguous
            HexaVal qh_v = hexa_farr_zeros(hexa_int((int64_t)T * hd));
            HexaVal kh_v = hexa_farr_zeros(hexa_int((int64_t)T * hd));
            int qh_id = (int)qh_v.i, kh_id = (int)kh_v.i;
            {
                double* Bc = _hx_farr_table[Bc_id].buf;
                double* qh = _hx_farr_table[qh_id].buf;
                double* kh = _hx_farr_table[kh_id].buf;
                for (int t = 0; t < T; t++)
                    for (int c = 0; c < hd; c++) {
                        qh[t*hd+c] = Bc[oQ + (t*nh+hh_a)*hd + c];
                        kh[t*hd+c] = Bc[oK + (t*nkv+kvh)*hd + c];
                    }
            }
            hexa_farr_to_device(qh_v);
            hexa_farr_to_device(kh_v);
            // K-blockᵀ: [hd·T] so Q[T·hd]·Kᵀ[hd·T] = scores[T·T] (cuBLAS).
            HexaVal kt_v = hexa_farr_zeros(hexa_int((int64_t)hd * T));
            int kt_id = (int)kt_v.i;
            {
                double* kh = _hx_farr_table[kh_id].buf;
                double* kt = _hx_farr_table[kt_id].buf;
                for (int t = 0; t < T; t++)
                    for (int c = 0; c < hd; c++) kt[c*T + t] = kh[t*hd + c];
            }
            hexa_farr_to_device(kt_v);
            // raw scores = Q · Kᵀ  (cuBLAS Dgemm: T×hd · hd×T → T×T)
            HexaVal raw_v = hexa_farr_matmul_gpu(
                hexa_int(qh_id), hexa_int(T), hexa_int(hd),
                hexa_int(kt_id), hexa_int(T));
            int raw_id = (int)raw_v.i;
            int sc_ok = (raw_id >= 0);
            if (sc_ok) {
                double* raw = _hx_farr_table[raw_id].buf;
                double* sc  = _hx_farr_table[sc_id].buf;
                // causal mask + scale; masked cells = -inf-ish via row-len
                for (int i = 0; i < T; i++)
                    for (int j = 0; j < T; j++)
                        sc[i*T+j] = (j <= i) ? raw[i*T+j] * scale : 0.0;
                hexa_farr_free(raw_v);
            } else {
                // CPU fallback for the score contraction
                double* qh = _hx_farr_table[qh_id].buf;
                double* kh = _hx_farr_table[kh_id].buf;
                double* sc = _hx_farr_table[sc_id].buf;
                for (int i = 0; i < T; i++)
                    for (int j = 0; j <= i; j++) {
                        double dot = 0.0;
                        for (int c = 0; c < hd; c++) dot += qh[i*hd+c]*kh[j*hd+c];
                        sc[i*T+j] = dot * scale;
                    }
            }
            // ── PHASE4D9 §3/§4-gap#1: causal-masked softmax — forge kernel
            //    replaces the host per-row L-prefix loop ───────────────────
            // The forge causal_softmax_rows kernel computes EXACTLY the CPU
            // reference's per-row softmax over the causal prefix [0,L=i+1)
            // (verbatim flame_g7_dt_exp via _hx_dt_exp_dev, deterministic
            // block-tree m_max/tot, the same `/= tot` divide) AND zero-fills
            // j ≥ i+1 — so its [T·T] output is byte-identically BOTH the
            // Bc[oP] cache slab the bwd pass reads AND the masked P-matrix
            // the P·V cuBLAS Dgemm consumes (the host code rebuilt that mask
            // in a SECOND loop into a separate `pmat` farr; the kernel
            // output IS pmat — that redundant host slab + its T·T alloc are
            // eliminated). sc is host-fresh (just mask+scaled above) so the
            // kernel's _h2d(sc) is the authoritative upload; its output is
            // D2H'd (default HOST_NOW) because Bc[oP] is a bwd-cache field
            // read host-side AND the P·V matmul reads it host-side — the
            // honest residual round-trip (PHASE4D9 §3: the wall fully moves
            // only when the bwd half also dev_view-consumes Bc[oP]; this
            // fwd-only conversion still D2Hs the bwd-cache fields).
            HexaVal vh_v = hexa_farr_zeros(hexa_int((int64_t)T * hd));
            int vh_id = (int)vh_v.i;
            {
                double* Bc = _hx_farr_table[Bc_id].buf;
                double* vh = _hx_farr_table[vh_id].buf;
                for (int t = 0; t < T; t++)
                    for (int c = 0; c < hd; c++)
                        vh[t*hd+c] = Bc[oV + (t*nkv+kvh)*hd + c];
            }
            int csm_id = flame_g7_causal_softmax_rows_gpu(sc_id, T, T);
            int pmat_id;
            HexaVal pmat_v; pmat_v.tag = 1; pmat_v.i = -1;
            if (csm_id >= 0) {
                // Kernel output P[T·T] IS the masked P-matrix (j≥i+1 → 0.0,
                // identical to the host pmat rebuild) AND the Bc[oP] cache.
                // Copy into Bc[oP] for the bwd pass (host reader); reuse the
                // SAME farr directly as the P·V matmul input (no rebuild).
                double* P  = _hx_farr_table[csm_id].buf;
                double* Bc = _hx_farr_table[Bc_id].buf;
                for (int i = 0; i < T; i++)
                    for (int j = 0; j < T; j++)
                        Bc[oP + (hh_a*T+i)*T + j] = P[i*T+j];
                pmat_id = csm_id;
            } else {
                // CPU fallback — VERBATIM the pre-conversion host softmax
                // loop + masked-P rebuild (byte-identical; the no-CUDA Mac
                // build + any dispatch failure take this path unchanged).
                {
                    double* sc = _hx_farr_table[sc_id].buf;
                    double* Bc = _hx_farr_table[Bc_id].buf;
                    for (int i = 0; i < T; i++) {
                        int L = i + 1;
                        double m_max = sc[i*T+0];
                        for (int j = 1; j < L; j++)
                            if (sc[i*T+j] > m_max) m_max = sc[i*T+j];
                        double tot = 0.0;
                        for (int j = 0; j < L; j++) {
                            double e = flame_g7_dt_exp(sc[i*T+j] - m_max);
                            Bc[oP + (hh_a*T + i)*T + j] = e;
                            tot += e;
                        }
                        for (int j = 0; j < L; j++)
                            Bc[oP + (hh_a*T + i)*T + j] /= tot;
                    }
                }
                pmat_v = hexa_farr_zeros(hexa_int((int64_t)T * T));
                pmat_id = (int)pmat_v.i;
                {
                    double* Bc   = _hx_farr_table[Bc_id].buf;
                    double* pmat = _hx_farr_table[pmat_id].buf;
                    for (int i = 0; i < T; i++)
                        for (int j = 0; j < T; j++)
                            pmat[i*T+j] = (j <= i)
                                ? Bc[oP + (hh_a*T+i)*T + j] : 0.0;
                }
            }
            // P·V — value combine. P is [T·T] lower-tri, V-block [T·hd];
            // ctx[T·hd] = P · V_block. cuBLAS Dgemm (masked P has 0s above
            // the diagonal so the full T×T · T×hd product is exact).
            hexa_farr_to_device(pmat_v);
            hexa_farr_to_device(vh_v);
            HexaVal ctx_v = hexa_farr_matmul_gpu(
                hexa_int(pmat_id), hexa_int(T), hexa_int(T),
                hexa_int(vh_id), hexa_int(hd));
            int ctx_id = (int)ctx_v.i;
            if (ctx_id >= 0) {
                double* ctx = _hx_farr_table[ctx_id].buf;
                double* Bc  = _hx_farr_table[Bc_id].buf;
                for (int t = 0; t < T; t++)
                    for (int c = 0; c < hd; c++)
                        Bc[oCtx + t*d + hh_a*hd + c] = ctx[t*hd + c];
                hexa_farr_free(ctx_v);
            } else {  // CPU fallback for value-combine
                double* Bc = _hx_farr_table[Bc_id].buf;
                for (int i = 0; i < T; i++) {
                    int L = i + 1;
                    for (int c = 0; c < hd; c++) {
                        double acc = 0.0;
                        for (int j = 0; j < L; j++)
                            acc += Bc[oP + (hh_a*T+i)*T + j]
                                 * Bc[oV + (j*nkv+kvh)*hd + c];
                        Bc[oCtx + i*d + hh_a*hd + c] = acc;
                    }
                }
            }
            hexa_farr_free(vh_v);
            // Free the P-matrix farr by its ACTUAL id: on the kernel path
            // pmat_id == csm_id (the causal_softmax output, reused directly
            // as the P·V matmul input — no separate pmat alloc); on the CPU
            // fallback pmat_id is the freshly-zeros'd pmat_v farr. Either
            // way pmat_id is the single live handle to free exactly once
            // (pmat_v's -1 sentinel on the kernel path must NOT be freed).
            hexa_farr_free(hexa_int(pmat_id));
            hexa_farr_free(kt_v);
            hexa_farr_free(kh_v);
            hexa_farr_free(qh_v);
            hexa_farr_free(sc_v);
        }
    }

    // ─── 5. output projection: attn_out = Wo · ctx  (cuBLAS) ─────
    HexaVal attn_out_v = hexa_farr_zeros(hexa_int((int64_t)T * d));
    int attn_out_id = (int)attn_out_v.i;
    flame_proj_batch_generic_primitive(Bp_id, WO, Bc_id, oCtx, attn_out_id, 0, T, d, d);

    // ─── 6. residual: hstate = X + attn_out  (forge add kernel) ──
    hexa_farr_to_device(attn_out_v);
    {
        // X is [T·d] resident; build a [T·d] view, add, write to hstate.
        HexaVal xslab_v = hexa_farr_zeros(hexa_int((int64_t)T * d));
        int xslab_id = (int)xslab_v.i;
        {
            double* X = _hx_farr_table[X_id].buf;
            double* xs = _hx_farr_table[xslab_id].buf;
            for (int p = 0; p < T * d; p++) xs[p] = X[p];
        }
        hexa_farr_to_device(xslab_v);
        HexaVal hs_v = hexa_farr_add_gpu(hexa_int(xslab_id), hexa_int(attn_out_id),
                                         hexa_int((int64_t)T * d));
        int hs_id = (int)hs_v.i;
        double* Bc = _hx_farr_table[Bc_id].buf;
        if (hs_id >= 0) {
            double* hs = _hx_farr_table[hs_id].buf;
            for (int p = 0; p < T * d; p++) Bc[oHstate + p] = hs[p];
            hexa_farr_free(hs_v);
        } else {
            double* X  = _hx_farr_table[X_id].buf;
            double* ao = _hx_farr_table[attn_out_id].buf;
            for (int p = 0; p < T * d; p++) Bc[oHstate + p] = X[p] + ao[p];
        }
        hexa_farr_free(xslab_v);
    }
    hexa_farr_free(attn_out_v);

    // ─── 7. RMSNorm(hstate, g2) → rin2 / rm2xn / r2inv  (forge) ──
    flame_g7_rmsnorm_resident(Bc_id, oHstate, Bp_id, G2,
                              Bc_id, oRin2, oRm2xn, oR2inv, T, d);

    // ─── 8. SwiGLU: a,b matmul (cuBLAS) + silu⊙ (forge kernels) ──
    flame_proj_batch_generic_primitive(Bp_id, WG, Bc_id, oRin2, Bc_id, oSwA, T, h, d);
    flame_proj_batch_generic_primitive(Bp_id, WU, Bc_id, oRin2, Bc_id, oSwB, T, h, d);
    {
        // s = silu(a) ⊙ b  — forge silu kernel then forge mul kernel.
        HexaVal a_v = hexa_farr_zeros(hexa_int((int64_t)T * h));
        HexaVal b_v = hexa_farr_zeros(hexa_int((int64_t)T * h));
        int a_id = (int)a_v.i, b_id = (int)b_v.i;
        {
            double* Bc = _hx_farr_table[Bc_id].buf;
            double* av = _hx_farr_table[a_id].buf;
            double* bv = _hx_farr_table[b_id].buf;
            for (int p = 0; p < T * h; p++) {
                av[p] = Bc[oSwA + p];
                bv[p] = Bc[oSwB + p];
            }
        }
        hexa_farr_to_device(a_v);
        hexa_farr_to_device(b_v);
        // RFC 056 §6.4/§6.5 resident chain: keep silu's output on the
        // device (FORGE_OUT_DEVICE_KEEP → no D2H), then feed the Hadamard
        // mul a dev_view of it. The view path in runtime_cuda.c:173-177
        // SKIPs H2D unconditionally for a view (s->view_base>=0) — it does
        // NOT consult dirty_host, so this is byte-safe even though
        // _d2h_out set dirty_host=1 on the deferred silu output (the
        // documented substrate constraint that defeats raw by-id
        // DEVICE_KEEP chaining; the view path is the byte-safe escape:
        // device bytes ARE silu's authoritative output, zero host
        // involvement). Restore HOST_NOW before mul so its result D2Hs
        // for the host copy into Bc[oSwS] (consumed by the cuBLAS WD
        // proj, a host reader). Removes one full silu→mul round-trip
        // (D2H of sa + re-H2D of sa) — fire #9 structural bound.
        int sw_prev_disp = (int)hexa_farr_set_out_disposition(
            hexa_int(HEXA_FORGE_OUT_DEVICE_KEEP)).i;
        HexaVal sa_v = hexa_farr_silu_gpu(hexa_int(a_id), hexa_int((int64_t)T * h));
        int sa_id = (int)sa_v.i;
        (void)hexa_farr_set_out_disposition(hexa_int(sw_prev_disp));
        double* Bc = _hx_farr_table[Bc_id].buf;
        if (sa_id >= 0) {
            // dev_view over the device-resident silu output (no host copy,
            // no re-upload). No-CUDA: dev_view returns a real CPU copy of
            // sa (logically byte-eq) — identical numerics on Mac.
            HexaVal sav_v = hexa_farr_dev_view(hexa_int(sa_id), hexa_int(0),
                                               hexa_int((int64_t)T * h));
            int sav_id = (int)sav_v.i;
            int mul_lhs = (sav_id >= 0) ? sav_id : sa_id;
            HexaVal s_v = hexa_farr_mul_gpu(hexa_int(mul_lhs), hexa_int(b_id),
                                            hexa_int((int64_t)T * h));
            int s_id = (int)s_v.i;
            Bc = _hx_farr_table[Bc_id].buf;
            if (s_id >= 0) {
                double* s = _hx_farr_table[s_id].buf;
                for (int p = 0; p < T * h; p++) Bc[oSwS + p] = s[p];
                hexa_farr_free(s_v);
            } else {
                double* sa = _hx_farr_table[sa_id].buf;
                double* bv = _hx_farr_table[b_id].buf;
                for (int p = 0; p < T * h; p++) Bc[oSwS + p] = sa[p] * bv[p];
            }
            if (sav_id >= 0) hexa_farr_free(sav_v);
            hexa_farr_free(sa_v);
        } else {  // silu dispatch failed — CPU silu⊙
            for (int p = 0; p < T * h; p++) {
                double av = Bc[oSwA + p], bv = Bc[oSwB + p];
                Bc[oSwS + p] = flame_g7_db_silu(av) * bv;
            }
        }
        hexa_farr_free(b_v);
        hexa_farr_free(a_v);
    }
    HexaVal sw_o_v = hexa_farr_zeros(hexa_int((int64_t)T * d));
    int sw_o_id = (int)sw_o_v.i;
    flame_proj_batch_generic_primitive(Bp_id, WD, Bc_id, oSwS, sw_o_id, 0, T, d, h);

    // ─── 9. residual: Xout = hstate + sw_o  (forge add kernel) ───
    hexa_farr_to_device(sw_o_v);
    {
        HexaVal hslab_v = hexa_farr_zeros(hexa_int((int64_t)T * d));
        int hslab_id = (int)hslab_v.i;
        {
            double* Bc = _hx_farr_table[Bc_id].buf;
            double* hs = _hx_farr_table[hslab_id].buf;
            for (int p = 0; p < T * d; p++) hs[p] = Bc[oHstate + p];
        }
        hexa_farr_to_device(hslab_v);
        HexaVal xo_v = hexa_farr_add_gpu(hexa_int(hslab_id), hexa_int(sw_o_id),
                                         hexa_int((int64_t)T * d));
        int xo_id = (int)xo_v.i;
        double* Bc = _hx_farr_table[Bc_id].buf;
        if (xo_id >= 0) {
            double* xo = _hx_farr_table[xo_id].buf;
            for (int p = 0; p < T * d; p++) Bc[oXout + p] = xo[p];
            hexa_farr_free(xo_v);
        } else {
            double* swo = _hx_farr_table[sw_o_id].buf;
            for (int p = 0; p < T * d; p++) Bc[oXout + p] = Bc[oHstate + p] + swo[p];
        }
        hexa_farr_free(hslab_v);
    }
    hexa_farr_free(sw_o_v);

    // ── RFC 056 §6.3 — release the residence anchor at block exit.
    //    unpin clears the non-evict flag; if D2H-defer left Bp/Bc with
    //    dirty_dev=1 it materializes them back to host (lazy D2H), which
    //    is exactly the host-authoritative exit contract documented
    //    below. With the current (unchanged) host-side copy-back
    //    dataflow Bc.dirty_dev stays 0, so unpin is a pure flag-clear
    //    and the host Bc remains the authoritative result — byte-eq
    //    preserved (F-RFC056-BYTEEQ-PRESERVE). No-CUDA Mac: inert.
    (void)hexa_farr_unpin_device(hexa_int(Bc_id));
    (void)hexa_farr_unpin_device(hexa_int(Bp_id));

    // ── PART 1 close (FIRE7 fix): NO block-level to_host(Bc) ──
    // Bc was accumulated entirely host-side (every forge/cuBLAS sub-op
    // _d2h'd its own scratch output and the primitive copied it into
    // Bc.buf). Bc's authoritative copy IS the host buffer. Calling
    // hexa_farr_to_host(Bc) here would D2H the STALE entry-time device
    // snapshot back over the correct host result (or fail the d2h state
    // check → the `[cuda] d2h: state mismatch` of FIRE7). The forge
    // substrate is verified; the residence contract for host-accumulated
    // farrs is "host stays authoritative — no block-boundary D2H".
}

// ── Dimension-gated dispatch entry point (concat / non-standalone) ──────
// d ≤ FLAME_GPU_RESIDENT_THRESHOLD → CPU loop (byte-eq d=32 path).
// d > threshold → GPU-resident kernel sequence.
// Name matches the sed-rewrite target in flame_phase4d7_a2_build.sh.
// NOTE: this wrapper lives inside the `#ifndef FLAME_BLOCK_PRIM_STANDALONE`
// region with the GPU primitive — the build-script strip regex only
// removes `#ifdef FLAME_BLOCK_PRIM_STANDALONE` blocks, so keeping the
// dispatch + GPU body under a single `#ifndef` guard means the strip never
// eats the dispatch body. The standalone-only trivial wrapper is below.
static inline void flame_block_generic_fwd_primitive(
    int X_id, int Bp_id, int Bc_id, int cos_id, int sin_id,
    int T, int d, int nh, int nkv, int h
) {
    if (d > FLAME_GPU_RESIDENT_THRESHOLD) {
        flame_block_generic_fwd_primitive_gpu(X_id, Bp_id, Bc_id, cos_id, sin_id,
                                              T, d, nh, nkv, h);
    } else {
        flame_block_generic_fwd_primitive_cpu(X_id, Bp_id, Bc_id, cos_id, sin_id,
                                              T, d, nh, nkv, h);
    }
}
// Phase 4-D-8: scope the redundant-H2D-elision macro to THIS primitive
// only — the a2 build concats fwd then bwd into one TU, and bwd re-emits
// `HexaVal hexa_farr_to_device(HexaVal);` forward-decls that must NOT be
// macro-expanded. #undef here keeps the elision strictly fwd-local.
#undef hexa_farr_to_device
#endif  // !FLAME_BLOCK_PRIM_STANDALONE

#ifdef FLAME_BLOCK_PRIM_STANDALONE
// Standalone compile-check only — no GPU primitive linked, CPU path direct.
static inline void flame_block_generic_fwd_primitive(
    int X_id, int Bp_id, int Bc_id, int cos_id, int sin_id,
    int T, int d, int nh, int nkv, int h
) {
    flame_block_generic_fwd_primitive_cpu(X_id, Bp_id, Bc_id, cos_id, sin_id,
                                          T, d, nh, nkv, h);
}
#endif
