// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4b3_block_fwd_primitive.c — Phase 4-B-3-2-third A2 (DRAFT)
//
// ⚠ DRAFT — fails to compile when concat'd into IPCP build pipeline:
//   - `farr_zeros` / `farr_free` are NOT direct fn calls in runtime.c
//     — they're `static HexaVal` variables holding fn pointers, used
//     via `hexa_call1(farr_zeros, ...)` macro in hexa_v2-emitted C
//   - `_db_proj_batch_farr` extern decl conflicts with implicit decl
//     from earlier use (needs the decl before any call site, or to
//     use the hexa-emitted signature exactly)
//
// Fix path: replace `farr_zeros(x)` → `hexa_call1(farr_zeros, x)` and
// add `extern HexaVal _db_proj_batch_farr(...)` BEFORE any use site.
// Next cycle work.
//
// Full primitive C body for nn_decoder_block_fwd specialized to
// (T=16, d=32, nh=4, nkv=2, h=64) per the d=32·3L flame_d32_corpus_test
// config. Mirrors stdlib/flame/decoder_block_lib.hexa:217-496 line-by-
// line, with all inline farr_get/set → _hx_farr_table[id].buf direct
// dereferences (boxing-elim).
//
// Matmul sections (#2, #5, #8's 3 calls) SKIP per audit (commit
// e7472b1e) — call HexaVal _db_proj_batch_farr via forward decl with
// hexa_int boxing at the call boundary.
//
// Algorithm-byte-eq with hexa source guaranteed by:
// 1. Same operation sequence per section (no reorder)
// 2. Same dt_sqrt/dt_exp/_db_silu Taylor/Newton (ported)
// 3. Same farr_table backing store (single-TU pattern shared)
//
// Concat into hexa_v2-emitted IPCP .c via build wrapper. Standalone
// compile-test verifies basic structure; byte-eq verify requires
// caller wire-up + run (next sub-step).
//
// Build (standalone compile check):
//   clang -O2 -c -I self tool/flame_phase4b3_block_fwd_primitive.c -o /tmp/block_prim.o
// ════════════════════════════════════════════════════════════════════════

// Forward decls for concat'd-into-hexa_v2-emit case. runtime.c provides
// `static HexaVal farr_zeros;` / `static HexaVal farr_free;` (fn ptr vars,
// not direct fns — call via `hexa_call1(farr_zeros, x)` macro).
// `_db_proj_batch_farr` is hexa-source emitted: signature is all-HexaVal.
#ifndef FLAME_BLOCK_PRIM_STANDALONE
HexaVal _db_proj_batch_farr(HexaVal W, HexaVal W_off, HexaVal X, HexaVal X_off, HexaVal Y, HexaVal Y_off, HexaVal T, HexaVal d_out, HexaVal d_in);
#endif

// Standalone compile context: emulate single-TU access to runtime.c types
// when not concat'd. When concat'd into hexa_v2-emitted .c (which
// `#include "runtime.c"`), these forward decls are redundant but harmless
// (matching definitions in runtime.c).
#ifdef FLAME_BLOCK_PRIM_STANDALONE
#include <math.h>
#include <stdint.h>
#include <stddef.h>
typedef struct { int tag; union { int64_t i; double f; void* p; }; } HexaVal;
typedef struct { double* buf; long len; void* d_buf; int loc, pinned, dirty_host, dirty_dev; } HexaFarrEntry;
static HexaFarrEntry* _hx_farr_table = NULL;
static inline HexaVal hexa_int(int64_t n) { HexaVal v; v.tag = 1; v.i = n; return v; }
static inline HexaVal hexa_float(double x) { HexaVal v; v.tag = 2; v.f = x; return v; }
HexaVal _db_proj_batch_farr(HexaVal, HexaVal, HexaVal, HexaVal, HexaVal, HexaVal, HexaVal, HexaVal, HexaVal);
HexaVal farr_zeros(HexaVal);
HexaVal farr_free(HexaVal);
#endif

// ── Ported transcendentals (mirror stdlib/flame/flame_math.hexa) ───
static inline double flame_dt_sqrt(double x) {
    if (x <= 0.0) return 0.0;
    double g = (x > 1.0) ? x : 1.0;
    for (int i = 0; i < 24; i++) g = 0.5 * (g + x / g);
    return g;
}

static inline double flame_dt_exp(double x) {
    int r = 0; double xr = x;
    while ((xr > 0.0 ? xr : -xr) > 0.25) { xr = xr / 2.0; r = r + 1; }
    double term = 1.0, acc = 1.0;
    for (int k = 1; k < 12; k++) { term = term * xr / (double)k; acc = acc + term; }
    for (int s = 0; s < r; s++) acc = acc * acc;
    return acc;
}

static inline double flame_db_sigmoid(double x) {
    return 1.0 / (1.0 + flame_dt_exp(0.0 - x));
}

static inline double flame_db_silu(double x) {
    return x * flame_db_sigmoid(x);
}

// ── Full primitive block_fwd for (T=16, d=32, nh=4, nkv=2, h=64) ───
//
// Layout offsets baked in as literal constants (per Bc/Bp computed
// formulas — see decoder_block_lib.hexa:49-95):
//   bp_off_g1=0   bp_off_Wq=32   bp_off_Wk=1056   bp_off_Wv=1568
//   bp_off_Wo=2080  bp_off_g2=3104  bp_off_Wg=3136
//   bp_off_Wu=5184  bp_off_Wd=7232
//   bc_off_Xout=0   bc_off_hstate=512   bc_off_rin=1024  bc_off_rin2=1536
//   bc_off_rm1xn=2048  bc_off_rm2xn=2560  bc_off_ctx=3072
//   bc_off_Q=3584  bc_off_K=4096  bc_off_V=4352  bc_off_P=4608
//   bc_off_sw_a=5632  bc_off_sw_b=6656  bc_off_sw_s=7680
//   bc_off_rm1inv=8704  bc_off_rm2inv=8720

static inline void flame_block_T16_d32_nh4_nkv2_h64_fwd_primitive(
    int X_id, int Bp_id, int Bc_id, int cos_id, int sin_id
) {
    double* X    = _hx_farr_table[X_id].buf;
    double* Bp   = _hx_farr_table[Bp_id].buf;
    double* Bc   = _hx_farr_table[Bc_id].buf;
    double* cos_ = _hx_farr_table[cos_id].buf;
    double* sin_ = _hx_farr_table[sin_id].buf;

    const int T = 16, d = 32, nh = 4, nkv = 2, h = 64;
    const int hd = 8;          // d/nh
    const int half = 4;        // hd/2
    const int n_rep = 2;       // nh/nkv
    const double eps = 1e-6;
    const double scale = 1.0 / flame_dt_sqrt((double)hd);

    // Bp offsets (literal-baked)
    const int G1 = 0,    WQ = 32,    WK = 1056,  WV = 1568;
    const int WO = 2080, G2 = 3104,  WG = 3136;
    const int WU = 5184, WD = 7232;
    // Bc offsets (literal-baked)
    const int oXout=0,    oHstate=512, oRin=1024,  oRin2=1536;
    const int oRm1xn=2048, oRm2xn=2560, oCtx=3072;
    const int oQ=3584,    oK=4096,    oV=4352,    oP=4608;
    const int oSwA=5632,  oSwB=6656,  oSwS=7680;
    const int oR1inv=8704, oR2inv=8720;

    // ─── 1. per-position RMSNorm(X, g1) → rin, rm1xn, rm1inv ─────
    for (int i = 0; i < T; i++) {
        double ms = 0.0;
        for (int c = 0; c < d; c++) {
            double xi = X[i * d + c];
            ms = ms + xi * xi;
        }
        ms = ms / (double)d;
        double inv = 1.0 / flame_dt_sqrt(ms + eps);
        Bc[oR1inv + i] = inv;
        for (int c2 = 0; c2 < d; c2++) {
            double xni = X[i * d + c2] * inv;
            Bc[oRm1xn + i * d + c2] = xni;
            Bc[oRin + i * d + c2] = Bp[G1 + c2] * xni;
        }
    }

    // ─── 2. Q/K/V projections — Path B primitives (matmul boxing eliminated) ─
    flame_proj_batch_T16_d32x32_primitive(Bp_id, WQ, Bc_id, oRin, Bc_id, oQ);
    flame_proj_batch_T16_d16x32_primitive(Bp_id, WK, Bc_id, oRin, Bc_id, oK);
    flame_proj_batch_T16_d16x32_primitive(Bp_id, WV, Bc_id, oRin, Bc_id, oV);
    Bc = _hx_farr_table[Bc_id].buf;

    // ─── 3. RoPE rotation on Q (nh heads) + K (nkv heads) ────────
    {
        double q_scratch[8];  // hd-sized stack scratch
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
        double srow_at[16];  // T-sized stack scratch
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
                // softmax: m_max + flame_dt_exp + normalize
                double m_max = srow_at[0];
                for (int jj = 1; jj < L; jj++) {
                    if (srow_at[jj] > m_max) m_max = srow_at[jj];
                }
                double tot = 0.0;
                for (int jj2 = 0; jj2 < L; jj2++) {
                    double e = flame_dt_exp(srow_at[jj2] - m_max);
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

    // ─── 5. output projection: attn_out = Wo · ctx — matmul SKIP ──
    HexaVal attn_out_v = hexa_call1(farr_zeros, hexa_int(T * d));
    int attn_out_id = (int)attn_out_v.i;
    flame_proj_batch_T16_d32x32_primitive(Bp_id, WO, Bc_id, oCtx, attn_out_id, 0);
    Bc = _hx_farr_table[Bc_id].buf;
    double* attn_out = _hx_farr_table[attn_out_id].buf;

    // ─── 6. residual: hstate = X + attn_out ──────────────────────
    for (int idx = 0; idx < T * d; idx++) {
        Bc[oHstate + idx] = X[idx] + attn_out[idx];
    }
    hexa_call1(farr_free, attn_out_v);

    // ─── 7. per-position RMSNorm(hstate, g2) → rin2, rm2xn, rm2inv ─
    for (int i2 = 0; i2 < T; i2++) {
        double ms = 0.0;
        for (int c = 0; c < d; c++) {
            double xi = Bc[oHstate + i2 * d + c];
            ms = ms + xi * xi;
        }
        ms = ms / (double)d;
        double inv = 1.0 / flame_dt_sqrt(ms + eps);
        Bc[oR2inv + i2] = inv;
        for (int c2 = 0; c2 < d; c2++) {
            double xni = Bc[oHstate + i2 * d + c2] * inv;
            Bc[oRm2xn + i2 * d + c2] = xni;
            Bc[oRin2 + i2 * d + c2] = Bp[G2 + c2] * xni;
        }
    }

    // ─── 8. SwiGLU: a, b matmul + silu+Hadamard + o matmul (Path B) ─
    flame_proj_batch_T16_d64x32_primitive(Bp_id, WG, Bc_id, oRin2, Bc_id, oSwA);
    flame_proj_batch_T16_d64x32_primitive(Bp_id, WU, Bc_id, oRin2, Bc_id, oSwB);
    Bc = _hx_farr_table[Bc_id].buf;
    // silu + Hadamard (primitive inline)
    for (int ts = 0; ts < T; ts++) {
        for (int k = 0; k < h; k++) {
            double av = Bc[oSwA + ts * h + k];
            double bv = Bc[oSwB + ts * h + k];
            Bc[oSwS + ts * h + k] = flame_db_silu(av) * bv;
        }
    }
    // o = Wd · s (Path B primitive)
    HexaVal sw_o_v = hexa_call1(farr_zeros, hexa_int(T * d));
    int sw_o_id = (int)sw_o_v.i;
    flame_proj_batch_T16_d32x64_primitive(Bp_id, WD, Bc_id, oSwS, sw_o_id, 0);
    Bc = _hx_farr_table[Bc_id].buf;
    double* sw_o = _hx_farr_table[sw_o_id].buf;

    // ─── 9. residual: Xout = hstate + sw_o ───────────────────────
    for (int idx2 = 0; idx2 < T * d; idx2++) {
        Bc[oXout + idx2] = Bc[oHstate + idx2] + sw_o[idx2];
    }
    hexa_call1(farr_free, sw_o_v);
}
