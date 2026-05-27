// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4d6_block_fwd_primitive.c — Phase 4-D-6 dimension-generic
// A2 forward primitive (RFC 047 genericization).
//
// Replaces tool/flame_phase4b3_block_fwd_primitive.c's dim-baked
// flame_block_T16_d32_nh4_nkv2_h64_fwd_primitive with ONE generic function
// whose config (T, d, nh, nkv, h) arrives as runtime fn arguments:
//   flame_block_generic_fwd_primitive(X_id,Bp_id,Bc_id,cos_id,sin_id,
//                                     T,d,nh,nkv,h)
//
// ── Why generic (Approach A — parameterize) ─────────────────────────────
// The d=32 primitive baked `const int T=16, d=32, nh=4, nkv=2, h=64` and
// every Bp/Bc layout offset as a literal, plus stack scratch q_scratch[8],
// srow_at[16]. At d=768·12L hd=64, T=1024, h=3072 → srow_at would be
// 1024 doubles, and the d=768 matmul W buffer 4.7 MB. Parameterizing:
//   - dims → fn args
//   - offsets → computed from the SAME bp_off_*/bc_off_* formulas
//     (decoder_block_lib.hexa:49-106), verified to reproduce the d=32
//     literals exactly (G1=0 WQ=32 ... oR2inv=8720)
//   - stack scratch → heap farr (sized per-config)
//
// ── Byte-eq argument (d=32·3L) ──────────────────────────────────────────
// Every loop is byte-copied from flame_phase4b3_block_fwd_primitive.c;
// only literal dims become variables and scratch arrays move stack→heap.
// NO reduction loop is reordered (PHASE4C audit §6 R1). For the d=32
// config the computed offsets equal the old literals, so the executed
// fp-op sequence is identical → F-RFC047-A2-PATHB-FULL-BYTE-EQ holds.
//
// Calls the generic matmul primitive flame_proj_batch_generic_primitive
// (tool/flame_phase4d6_matmul_primitives.c) — concat that file FIRST.
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

// ── Ported transcendentals (mirror stdlib/flame/flame_math.hexa) ───
static inline double flame_g_dt_sqrt(double x) {
    if (x <= 0.0) return 0.0;
    double g = (x > 1.0) ? x : 1.0;
    for (int i = 0; i < 24; i++) g = 0.5 * (g + x / g);
    return g;
}

static inline double flame_g_dt_exp(double x) {
    int r = 0; double xr = x;
    while ((xr > 0.0 ? xr : -xr) > 0.25) { xr = xr / 2.0; r = r + 1; }
    double term = 1.0, acc = 1.0;
    for (int k = 1; k < 12; k++) { term = term * xr / (double)k; acc = acc + term; }
    for (int s = 0; s < r; s++) acc = acc * acc;
    return acc;
}

static inline double flame_g_db_sigmoid(double x) {
    return 1.0 / (1.0 + flame_g_dt_exp(0.0 - x));
}

static inline double flame_g_db_silu(double x) {
    return x * flame_g_db_sigmoid(x);
}

// ── Dimension-generic block_fwd ─────────────────────────────────────
// Mirrors flame_phase4b3_block_fwd_primitive.c line-for-line; dims are
// fn args, offsets computed from bp_off_*/bc_off_* formulas, scratch
// arrays heap-allocated.
static inline void flame_block_generic_fwd_primitive(
    int X_id, int Bp_id, int Bc_id, int cos_id, int sin_id,
    int T, int d, int nh, int nkv, int h
) {
    const int hd = d / nh;            // head dim
    const int half = hd / 2;
    const int n_rep = nh / nkv;
    const int kvd = nkv * (d / nh);   // _kvd_of(d,nh,nkv)
    const double eps = 1e-6;
    const double scale = 1.0 / flame_g_dt_sqrt((double)hd);

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

    // Heap scratch (d=32 used q_scratch[8]/srow_at[16] on stack; at
    // d=768 hd=64 / T=1024 — heap keeps the frame bounded for any config).
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
        double inv = 1.0 / flame_g_dt_sqrt(ms + eps);
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
            // Q rotation
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
            // K rotation
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
                // dot products → srow_at[j]
                for (int j = 0; j < L; j++) {
                    double dot = 0.0;
                    for (int c = 0; c < hd; c++) {
                        dot = dot + Bc[oQ + (i_a * nh + hh_a) * hd + c]
                                  * Bc[oK + (j * nkv + kvh) * hd + c];
                    }
                    srow_at[j] = dot * scale;
                }
                // softmax: m_max + flame_g_dt_exp + normalize
                double m_max = srow_at[0];
                for (int jj = 1; jj < L; jj++) {
                    if (srow_at[jj] > m_max) m_max = srow_at[jj];
                }
                double tot = 0.0;
                for (int jj2 = 0; jj2 < L; jj2++) {
                    double e = flame_g_dt_exp(srow_at[jj2] - m_max);
                    Bc[oP + (hh_a * T + i_a) * T + jj2] = e;
                    tot = tot + e;
                }
                for (int jj3 = 0; jj3 < L; jj3++) {
                    Bc[oP + (hh_a * T + i_a) * T + jj3] /= tot;
                }
                // value combine: ctx[i_a·d + hh_a·hd + c] = Σ_j P · V
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
        double inv = 1.0 / flame_g_dt_sqrt(ms + eps);
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
    // silu + Hadamard (primitive inline)
    for (int ts = 0; ts < T; ts++) {
        for (int k = 0; k < h; k++) {
            double av = Bc[oSwA + ts * h + k];
            double bv = Bc[oSwB + ts * h + k];
            Bc[oSwS + ts * h + k] = flame_g_db_silu(av) * bv;
        }
    }
    // o = Wd · s (generic matmul primitive)
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
