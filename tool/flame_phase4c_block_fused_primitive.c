// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4c_block_fused_primitive.c — Phase 4-C-2c (FUSED)
//
// Phase 4-C-2c: fused fwd+bwd primitive with inline bodies, iteratively
// extracting Bc intermediates to C local arrays. Eliminates Bc DRAM
// round-trip traffic between fwd-exit and bwd-entry for "pure fwd→bwd
// local" intermediates (per audit below).
//
// ── Iteration ledger (Bc-elimination per commit) ─────────────────────
//
//   V0  (baseline)       full inline body, NO extractions yet — byte-eq
//                        canvas for incremental extractions. Bc traffic
//                        identical to SCAFFOLD wrapper / paired calls.
//
//   PURE LOCALS (extract one per iteration, smallest-first):
//   iter 1   oRm1inv  16 dbl  rmsnorm1 fwd inv → vjp inv read
//   iter 2   oRm2inv  16 dbl  rmsnorm2 fwd inv → vjp inv read
//   iter 3   oRm1xn  512 dbl  rmsnorm1 normalized → vjp grad
//   iter 4   oRm2xn  512 dbl  rmsnorm2 normalized → vjp grad
//   iter 5   oRin    512 dbl  rmsnorm1 output (matmul input → grad)
//   iter 6   oRin2   512 dbl  rmsnorm2 output (matmul input → grad)
//   iter 7   oSwS   1024 dbl  silu(a)·b → SwiGLU bwd
//
//   Total potential extraction: 3104 doubles = 24 KB DRAM RT eliminated.
//   L1-resident on M2 (96 KB typical per core).
//
//   REMAINS IN Bc (matmul-bound, requires API change — 4-C-3+ scope):
//   oQ, oK, oV, oP, oCtx, oSwA, oSwB, oXout, oHstate.
//
// ── Falsifier per iteration ──────────────────────────────────────────
//
//   F-RFC048-FUSED-FWD-BWD-EQ      max|Δ| = 0.0 vs paired-call baseline
//                                  (STRICT byte-eq; STOP & revert if FAIL
//                                  per Path C revert lesson, audit §6 R1)
//
//   F-RFC048-FUSED-WALL-IMPROVED   ≥1.30× over paired baseline (cumulative)
//                                  primitive-level micro-bench
//                                  (tool/flame_phase4c_leaf_fused_build.sh
//                                   reports ratio)
//
// ── Critical caveat (Path C revert lesson, audit §6 R1) ──────────────
//
//   clang -O2 may reorder vectorized loops differently for locals vs
//   farr backing store. Per-iteration max|Δ|=0 verification is MANDATORY.
//   If an iteration breaks byte-eq, revert THAT extraction (keep prior
//   extractions). Selective fusion > forced fusion.
//
// Audit: stdlib/flame/PHASE4C_IMPLEMENTATION_AUDIT.md §4 (Phase 4-C-2c row),
//        §6 R1 (reduction-order preservation), R4 (fallback preservation).
// Test:  tool/flame_phase4c_leaf_fused_test.c (byte-eq + wall bench)
// Build: tool/flame_phase4c_leaf_fused_build.sh
// ════════════════════════════════════════════════════════════════════════

// Forward declarations — primitives provided by concat'd build
// (tool/flame_phase4b3_matmul_primitives.c + tool/flame_phase4b3_block_*_primitive.c).
#ifndef FLAME_BLOCK_FUSED_PRIM_STANDALONE
// Real build path: extern declarations match concat'd helpers.
extern void flame_proj_batch_T16_d32x32_primitive(int W_id, int W_off, int X_id, int X_off, int Y_id, int Y_off);
extern void flame_proj_batch_T16_d16x32_primitive(int W_id, int W_off, int X_id, int X_off, int Y_id, int Y_off);
extern void flame_proj_batch_T16_d64x32_primitive(int W_id, int W_off, int X_id, int X_off, int Y_id, int Y_off);
extern void flame_proj_batch_T16_d32x64_primitive(int W_id, int W_off, int X_id, int X_off, int Y_id, int Y_off);
extern void flame_grad_accum_T16_d32x32_primitive(int dY_id, int dY_off, int X_id, int X_off, int dW_id, int dW_off);
extern void flame_grad_accum_T16_d16x32_primitive(int dY_id, int dY_off, int X_id, int X_off, int dW_id, int dW_off);
extern void flame_grad_accum_T16_d64x32_primitive(int dY_id, int dY_off, int X_id, int X_off, int dW_id, int dW_off);
extern void flame_grad_accum_T16_d32x64_primitive(int dY_id, int dY_off, int X_id, int X_off, int dW_id, int dW_off);
#endif

#ifdef FLAME_BLOCK_FUSED_PRIM_STANDALONE
#include <math.h>
#include <stdint.h>
#include <stddef.h>
typedef struct { int tag; union { int64_t i; double f; void* p; }; } HexaVal;
typedef struct { double* buf; long len; void* d_buf; int loc, pinned, dirty_host, dirty_dev; } HexaFarrEntry;
static HexaFarrEntry* _hx_farr_table = NULL;
static inline HexaVal hexa_int(int64_t n) { HexaVal v; v.tag = 1; v.i = n; return v; }
static HexaVal farr_zeros, farr_free;
#define hexa_call1(f, a) (((HexaVal(*)(HexaVal))((f).p))(a))
static void flame_proj_batch_T16_d32x32_primitive(int W_id, int W_off, int X_id, int X_off, int Y_id, int Y_off) { (void)W_id;(void)W_off;(void)X_id;(void)X_off;(void)Y_id;(void)Y_off; }
static void flame_proj_batch_T16_d16x32_primitive(int W_id, int W_off, int X_id, int X_off, int Y_id, int Y_off) { (void)W_id;(void)W_off;(void)X_id;(void)X_off;(void)Y_id;(void)Y_off; }
static void flame_proj_batch_T16_d64x32_primitive(int W_id, int W_off, int X_id, int X_off, int Y_id, int Y_off) { (void)W_id;(void)W_off;(void)X_id;(void)X_off;(void)Y_id;(void)Y_off; }
static void flame_proj_batch_T16_d32x64_primitive(int W_id, int W_off, int X_id, int X_off, int Y_id, int Y_off) { (void)W_id;(void)W_off;(void)X_id;(void)X_off;(void)Y_id;(void)Y_off; }
static void flame_grad_accum_T16_d32x32_primitive(int dY_id, int dY_off, int X_id, int X_off, int dW_id, int dW_off) { (void)dY_id;(void)dY_off;(void)X_id;(void)X_off;(void)dW_id;(void)dW_off; }
static void flame_grad_accum_T16_d16x32_primitive(int dY_id, int dY_off, int X_id, int X_off, int dW_id, int dW_off) { (void)dY_id;(void)dY_off;(void)X_id;(void)X_off;(void)dW_id;(void)dW_off; }
static void flame_grad_accum_T16_d64x32_primitive(int dY_id, int dY_off, int X_id, int X_off, int dW_id, int dW_off) { (void)dY_id;(void)dY_off;(void)X_id;(void)X_off;(void)dW_id;(void)dW_off; }
static void flame_grad_accum_T16_d32x64_primitive(int dY_id, int dY_off, int X_id, int X_off, int dW_id, int dW_off) { (void)dY_id;(void)dY_off;(void)X_id;(void)X_off;(void)dW_id;(void)dW_off; }
#endif

// ── Ported transcendentals — namespaced to avoid collision with
//    flame_dt_sqrt (fwd primitive) and flame_bwd_dt_sqrt (bwd primitive).
//    Same algorithm so reductions remain byte-identical.
static inline double flame_fused_dt_sqrt(double x) {
    if (x <= 0.0) return 0.0;
    double g = (x > 1.0) ? x : 1.0;
    for (int i = 0; i < 24; i++) g = 0.5 * (g + x / g);
    return g;
}

static inline double flame_fused_dt_exp(double x) {
    int r = 0; double xr = x;
    while ((xr > 0.0 ? xr : -xr) > 0.25) { xr = xr / 2.0; r = r + 1; }
    double term = 1.0, acc = 1.0;
    for (int k = 1; k < 12; k++) { term = term * xr / (double)k; acc = acc + term; }
    for (int s = 0; s < r; s++) acc = acc * acc;
    return acc;
}

static inline double flame_fused_db_sigmoid(double x) {
    return 1.0 / (1.0 + flame_fused_dt_exp(0.0 - x));
}

static inline double flame_fused_db_silu(double x) {
    return x * flame_fused_db_sigmoid(x);
}

static inline double flame_fused_db_silu_grad(double x) {
    double s = flame_fused_db_sigmoid(x);
    return s + x * s * (1.0 - s);
}

// ── Fused primitive (V0: inline fwd+bwd body, no extractions yet) ────
//
// Identical math + order to invoking fwd then bwd primitives back-to-
// back. Bc still materialized exactly as in paired call. This V0 form
// is the byte-eq canvas for the iterative Bc-elimination commits that
// follow.

static inline void flame_block_T16_d32_nh4_nkv2_h64_fused_primitive(
    int X_id, int Bp_id, int Bc_id,
    int dXout_id, int dX_out_id, int Bg_id,
    int cos_id, int sin_id
) {
    double* X     = _hx_farr_table[X_id].buf;
    double* Bp    = _hx_farr_table[Bp_id].buf;
    double* Bc    = _hx_farr_table[Bc_id].buf;
    double* dXout = _hx_farr_table[dXout_id].buf;
    double* dX_out = _hx_farr_table[dX_out_id].buf;
    double* Bg    = _hx_farr_table[Bg_id].buf;
    double* cos_  = _hx_farr_table[cos_id].buf;
    double* sin_  = _hx_farr_table[sin_id].buf;

    const int T = 16, d = 32, nh = 4, nkv = 2, h = 64;
    const int hd = 8, half = 4, kvd = 16;
    const int n_rep = 2;
    const double eps = 1e-6;
    const double scale = 1.0 / flame_fused_dt_sqrt((double)hd);

    // Bp offsets
    const int G1 = 0,    WQ = 32,    WK = 1056,  WV = 1568;
    const int WO = 2080, G2 = 3104,  WG = 3136;
    const int WU = 5184, WD = 7232;
    // Bc offsets
    const int oXout=0,    oHstate=512, oRin=1024,  oRin2=1536;
    const int oRm1xn=2048, oRm2xn=2560, oCtx=3072;
    const int oQ=3584, oK=4096, oV=4352, oP=4608;
    const int oSwA=5632, oSwB=6656, oSwS=7680;
    const int oR2inv=8720;
    // oR1inv: EXTRACTED to local rm1inv_loc[16] (iter 1, commit pending)
    //   fwd section 1 writes; bwd section 1rev reads. No other reader.

    // ── Extracted intermediates (Bc-elimination locals) ──────────────
    double rm1inv_loc[16];  // iter 1: replaces Bc[oR1inv + i] for i=0..T-1

    // ═══════════════════════ FWD PHASE ═══════════════════════════════
    // (Mirrors tool/flame_phase4b3_block_fwd_primitive.c sections 1..9.)

    // ─── 1. RMSNorm(X, g1) → rin, rm1xn, rm1inv_loc ──────────────
    for (int i = 0; i < T; i++) {
        double ms = 0.0;
        for (int c = 0; c < d; c++) {
            double xi = X[i * d + c];
            ms = ms + xi * xi;
        }
        ms = ms / (double)d;
        double inv = 1.0 / flame_fused_dt_sqrt(ms + eps);
        rm1inv_loc[i] = inv;  // [extracted iter 1] was: Bc[oR1inv + i] = inv;
        for (int c2 = 0; c2 < d; c2++) {
            double xni = X[i * d + c2] * inv;
            Bc[oRm1xn + i * d + c2] = xni;
            Bc[oRin + i * d + c2] = Bp[G1 + c2] * xni;
        }
    }

    // ─── 2. Q/K/V projections (Path B primitives) ────────────────
    flame_proj_batch_T16_d32x32_primitive(Bp_id, WQ, Bc_id, oRin, Bc_id, oQ);
    flame_proj_batch_T16_d16x32_primitive(Bp_id, WK, Bc_id, oRin, Bc_id, oK);
    flame_proj_batch_T16_d16x32_primitive(Bp_id, WV, Bc_id, oRin, Bc_id, oV);
    Bc = _hx_farr_table[Bc_id].buf;

    // ─── 3. RoPE on Q (nh heads) + K (nkv heads) ─────────────────
    {
        double q_scratch[8];
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

    // ─── 4. attention core (causal GQA softmax + value combine) ──
    {
        double srow_at[16];
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
                    double e = flame_fused_dt_exp(srow_at[jj2] - m_max);
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
    flame_proj_batch_T16_d32x32_primitive(Bp_id, WO, Bc_id, oCtx, attn_out_id, 0);
    Bc = _hx_farr_table[Bc_id].buf;
    double* attn_out = _hx_farr_table[attn_out_id].buf;

    // ─── 6. residual: hstate = X + attn_out ──────────────────────
    for (int idx = 0; idx < T * d; idx++) {
        Bc[oHstate + idx] = X[idx] + attn_out[idx];
    }
    hexa_call1(farr_free, attn_out_v);

    // ─── 7. RMSNorm(hstate, g2) → rin2, rm2xn, rm2inv ────────────
    for (int i2 = 0; i2 < T; i2++) {
        double ms = 0.0;
        for (int c = 0; c < d; c++) {
            double xi = Bc[oHstate + i2 * d + c];
            ms = ms + xi * xi;
        }
        ms = ms / (double)d;
        double inv = 1.0 / flame_fused_dt_sqrt(ms + eps);
        Bc[oR2inv + i2] = inv;
        for (int c2 = 0; c2 < d; c2++) {
            double xni = Bc[oHstate + i2 * d + c2] * inv;
            Bc[oRm2xn + i2 * d + c2] = xni;
            Bc[oRin2 + i2 * d + c2] = Bp[G2 + c2] * xni;
        }
    }

    // ─── 8. SwiGLU: a, b matmul + silu+Hadamard + o matmul ───────
    flame_proj_batch_T16_d64x32_primitive(Bp_id, WG, Bc_id, oRin2, Bc_id, oSwA);
    flame_proj_batch_T16_d64x32_primitive(Bp_id, WU, Bc_id, oRin2, Bc_id, oSwB);
    Bc = _hx_farr_table[Bc_id].buf;
    for (int ts = 0; ts < T; ts++) {
        for (int k = 0; k < h; k++) {
            double av = Bc[oSwA + ts * h + k];
            double bv = Bc[oSwB + ts * h + k];
            Bc[oSwS + ts * h + k] = flame_fused_db_silu(av) * bv;
        }
    }
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

    // ═══════════════════════ BWD PHASE ═══════════════════════════════
    // (Mirrors tool/flame_phase4b3_block_bwd_primitive.c sections 9rev..1rev.)
    //
    // Re-bind farr pointers after possible table realloc from fwd's
    // farr_zeros (attn_out, sw_o were freed but the underlying farr
    // entries may have stayed valid; table may have grown).
    X     = _hx_farr_table[X_id].buf;
    Bp    = _hx_farr_table[Bp_id].buf;
    Bc    = _hx_farr_table[Bc_id].buf;
    dXout = _hx_farr_table[dXout_id].buf;
    dX_out = _hx_farr_table[dX_out_id].buf;
    Bg    = _hx_farr_table[Bg_id].buf;
    cos_  = _hx_farr_table[cos_id].buf;
    sin_  = _hx_farr_table[sin_id].buf;

    // ─── 9rev: dh = dXout (residual passthrough) ─────────────────
    HexaVal dh_v = hexa_call1(farr_zeros, hexa_int(T * d));
    int dh_id = (int)dh_v.i;
    double* dh = _hx_farr_table[dh_id].buf;
    for (int i = 0; i < T * d; i++) dh[i] = dXout[i];

    // ─── 8rev: SwiGLU bwd ────────────────────────────────────────
    flame_grad_accum_T16_d32x64_primitive(dXout_id, 0, Bc_id, oSwS, Bg_id, WD);
    Bc = _hx_farr_table[Bc_id].buf;
    Bg = _hx_farr_table[Bg_id].buf;
    dXout = _hx_farr_table[dXout_id].buf;

    HexaVal dr_pos_v = hexa_call1(farr_zeros, hexa_int(d));
    HexaVal da_all_v = hexa_call1(farr_zeros, hexa_int(T * h));
    HexaVal db_all_v = hexa_call1(farr_zeros, hexa_int(T * h));
    int dr_pos_id = (int)dr_pos_v.i;
    int da_all_id = (int)da_all_v.i;
    int db_all_id = (int)db_all_v.i;
    double* dr_pos = _hx_farr_table[dr_pos_id].buf;
    double* da_all = _hx_farr_table[da_all_id].buf;
    double* db_all = _hx_farr_table[db_all_id].buf;

    double ds_pos_st[64];
    double da_pos_st[64];
    double db_pos_st[64];

    // dh may be invalidated by farr_zeros calls above (realloc)
    dh = _hx_farr_table[dh_id].buf;

    for (int ts = 0; ts < T; ts++) {
        for (int k = 0; k < h; k++) {
            double acc = 0.0;
            for (int rr = 0; rr < d; rr++) {
                acc = acc + Bp[WD + rr * h + k] * dXout[ts * d + rr];
            }
            ds_pos_st[k] = acc;
        }
        for (int k = 0; k < h; k++) {
            double ak = Bc[oSwA + ts * h + k];
            double bk = Bc[oSwB + ts * h + k];
            double dsk = ds_pos_st[k];
            double da_v = dsk * bk * flame_fused_db_silu_grad(ak);
            double db_v = dsk * flame_fused_db_silu(ak);
            da_pos_st[k] = da_v;
            db_pos_st[k] = db_v;
            da_all[ts * h + k] = da_v;
            db_all[ts * h + k] = db_v;
        }
        for (int cc = 0; cc < d; cc++) {
            double acc2 = 0.0;
            for (int k = 0; k < h; k++) {
                acc2 = acc2 + Bp[WG + k * d + cc] * da_pos_st[k]
                            + Bp[WU + k * d + cc] * db_pos_st[k];
            }
            dr_pos[cc] = acc2;
        }

        // 7rev (per-ts): RMSNorm 2 vjp
        double inv2 = Bc[oR2inv + ts];
        double dot2 = 0.0;
        for (int i7 = 0; i7 < d; i7++) {
            double dxn_i = dr_pos[i7] * Bp[G2 + i7];
            Bg[G2 + i7] = Bg[G2 + i7]
                        + dr_pos[i7] * Bc[oRm2xn + ts * d + i7];
            dot2 = dot2 + dxn_i * Bc[oHstate + ts * d + i7];
            dr_pos[i7] = dxn_i;
        }
        double inv3_2 = inv2 * inv2 * inv2;
        double scl2 = (inv3_2 / (double)d) * dot2;
        for (int i8 = 0; i8 < d; i8++) {
            double dxn_j = dr_pos[i8];
            double xj = Bc[oHstate + ts * d + i8];
            double dh_contrib = inv2 * dxn_j - scl2 * xj;
            dh[ts * d + i8] = dh[ts * d + i8] + dh_contrib;
        }
    }
    flame_grad_accum_T16_d64x32_primitive(da_all_id, 0, Bc_id, oRin2, Bg_id, WG);
    flame_grad_accum_T16_d64x32_primitive(db_all_id, 0, Bc_id, oRin2, Bg_id, WU);
    hexa_call1(farr_free, dr_pos_v);
    hexa_call1(farr_free, da_all_v);
    hexa_call1(farr_free, db_all_v);
    Bc = _hx_farr_table[Bc_id].buf;
    Bg = _hx_farr_table[Bg_id].buf;
    dh = _hx_farr_table[dh_id].buf;

    // ─── 5rev: Wo proj bwd + dctx inline ─────────────────────────
    flame_grad_accum_T16_d32x32_primitive(dh_id, 0, Bc_id, oCtx, Bg_id, WO);
    Bc = _hx_farr_table[Bc_id].buf;
    Bp = _hx_farr_table[Bp_id].buf;
    dh = _hx_farr_table[dh_id].buf;

    HexaVal dctx_v = hexa_call1(farr_zeros, hexa_int(T * d));
    int dctx_id = (int)dctx_v.i;
    double* dctx = _hx_farr_table[dctx_id].buf;
    for (int t_w = 0; t_w < T; t_w++) {
        for (int c2 = 0; c2 < d; c2++) {
            double acc = 0.0;
            for (int rr = 0; rr < d; rr++) {
                acc = acc + Bp[WO + rr * d + c2] * dh[t_w * d + rr];
            }
            dctx[t_w * d + c2] = acc;
        }
    }

    // ─── 4rev: attention bwd ─────────────────────────────────────
    HexaVal dQ_v = hexa_call1(farr_zeros, hexa_int(T * d));
    HexaVal dK_v = hexa_call1(farr_zeros, hexa_int(T * kvd));
    HexaVal dV_v = hexa_call1(farr_zeros, hexa_int(T * kvd));
    int dQ_id = (int)dQ_v.i;
    int dK_id = (int)dK_v.i;
    int dV_id = (int)dV_v.i;
    double* dQ = _hx_farr_table[dQ_id].buf;
    double* dK = _hx_farr_table[dK_id].buf;
    double* dV = _hx_farr_table[dV_id].buf;
    double dP_row[16];
    Bc = _hx_farr_table[Bc_id].buf;
    dctx = _hx_farr_table[dctx_id].buf;
    for (int hh_b = 0; hh_b < nh; hh_b++) {
        int kvh = hh_b / n_rep;
        for (int i_b = 0; i_b < T; i_b++) {
            int L = i_b + 1;
            for (int j = 0; j < L; j++) {
                double acc = 0.0;
                for (int c = 0; c < hd; c++) {
                    acc = acc + dctx[i_b * d + hh_b * hd + c]
                              * Bc[oV + (j * nkv + kvh) * hd + c];
                }
                dP_row[j] = acc;
            }
            double sdot = 0.0;
            for (int j2 = 0; j2 < L; j2++) {
                sdot = sdot + Bc[oP + (hh_b * T + i_b) * T + j2] * dP_row[j2];
            }
            for (int j3 = 0; j3 < L; j3++) {
                double pij = Bc[oP + (hh_b * T + i_b) * T + j3];
                for (int c = 0; c < hd; c++) {
                    int idx_dv = (j3 * nkv + kvh) * hd + c;
                    dV[idx_dv] = dV[idx_dv] + pij * dctx[i_b * d + hh_b * hd + c];
                }
            }
            for (int j4 = 0; j4 < L; j4++) {
                double dS = Bc[oP + (hh_b * T + i_b) * T + j4]
                          * (dP_row[j4] - sdot) * scale;
                for (int c2 = 0; c2 < hd; c2++) {
                    int idx_dq = (i_b * nh + hh_b) * hd + c2;
                    int idx_dk = (j4 * nkv + kvh) * hd + c2;
                    dQ[idx_dq] = dQ[idx_dq]
                               + dS * Bc[oK + (j4 * nkv + kvh) * hd + c2];
                    dK[idx_dk] = dK[idx_dk]
                               + dS * Bc[oQ + (i_b * nh + hh_b) * hd + c2];
                }
            }
        }
    }
    hexa_call1(farr_free, dctx_v);

    // ─── 3rev: RoPE bwd inverse rotation ─────────────────────────
    {
        double tmp_rope[8];
        for (int t_r = 0; t_r < T; t_r++) {
            int bse = t_r * hd;
            for (int hh = 0; hh < nh; hh++) {
                int row_off = (t_r * nh + hh) * hd;
                for (int c = 0; c < hd; c++) {
                    double gs_for_rht = (c < half)
                        ? dQ[row_off + half + c] * sin_[bse + half + c]
                        : (0.0 - dQ[row_off + c - half] * sin_[bse + c - half]);
                    tmp_rope[c] = dQ[row_off + c] * cos_[bse + c] + gs_for_rht;
                }
                for (int c2 = 0; c2 < hd; c2++) dQ[row_off + c2] = tmp_rope[c2];
            }
            for (int hk = 0; hk < nkv; hk++) {
                int row_off = (t_r * nkv + hk) * hd;
                for (int c = 0; c < hd; c++) {
                    double gs_for_rht = (c < half)
                        ? dK[row_off + half + c] * sin_[bse + half + c]
                        : (0.0 - dK[row_off + c - half] * sin_[bse + c - half]);
                    tmp_rope[c] = dK[row_off + c] * cos_[bse + c] + gs_for_rht;
                }
                for (int c2 = 0; c2 < hd; c2++) dK[row_off + c2] = tmp_rope[c2];
            }
        }
    }

    // ─── 2rev: Q/K/V proj bwd + drin inline ──────────────────────
    flame_grad_accum_T16_d32x32_primitive(dQ_id, 0, Bc_id, oRin, Bg_id, WQ);
    flame_grad_accum_T16_d16x32_primitive(dK_id, 0, Bc_id, oRin, Bg_id, WK);
    flame_grad_accum_T16_d16x32_primitive(dV_id, 0, Bc_id, oRin, Bg_id, WV);
    Bp = _hx_farr_table[Bp_id].buf;
    Bg = _hx_farr_table[Bg_id].buf;
    Bc = _hx_farr_table[Bc_id].buf;
    dQ = _hx_farr_table[dQ_id].buf;
    dK = _hx_farr_table[dK_id].buf;
    dV = _hx_farr_table[dV_id].buf;
    dh = _hx_farr_table[dh_id].buf;

    HexaVal drin_v = hexa_call1(farr_zeros, hexa_int(T * d));
    int drin_id = (int)drin_v.i;
    double* drin = _hx_farr_table[drin_id].buf;
    for (int t_p = 0; t_p < T; t_p++) {
        for (int cc = 0; cc < d; cc++) {
            double acc = 0.0;
            for (int rr = 0; rr < d; rr++) {
                acc = acc + Bp[WQ + rr * d + cc] * dQ[t_p * d + rr];
            }
            for (int rk2 = 0; rk2 < kvd; rk2++) {
                acc = acc + Bp[WK + rk2 * d + cc] * dK[t_p * kvd + rk2]
                          + Bp[WV + rk2 * d + cc] * dV[t_p * kvd + rk2];
            }
            drin[t_p * d + cc] = acc;
        }
    }
    hexa_call1(farr_free, dQ_v);
    hexa_call1(farr_free, dK_v);
    hexa_call1(farr_free, dV_v);

    // ─── 1rev: RMSNorm 1 vjp + dX_out final write ────────────────
    double dx_pos[32];
    Bp = _hx_farr_table[Bp_id].buf;
    Bg = _hx_farr_table[Bg_id].buf;
    Bc = _hx_farr_table[Bc_id].buf;
    drin = _hx_farr_table[drin_id].buf;
    dh = _hx_farr_table[dh_id].buf;
    X = _hx_farr_table[X_id].buf;
    dX_out = _hx_farr_table[dX_out_id].buf;
    for (int ti = 0; ti < T; ti++) {
        double inv1 = rm1inv_loc[ti];  // [extracted iter 1] was: Bc[oR1inv + ti];
        double dot1 = 0.0;
        for (int i_r = 0; i_r < d; i_r++) {
            double dxn_i = drin[ti * d + i_r] * Bp[G1 + i_r];
            Bg[G1 + i_r] = Bg[G1 + i_r]
                         + drin[ti * d + i_r] * Bc[oRm1xn + ti * d + i_r];
            dot1 = dot1 + dxn_i * X[ti * d + i_r];
            dx_pos[i_r] = dxn_i;
        }
        double inv3_1 = inv1 * inv1 * inv1;
        double scl1 = (inv3_1 / (double)d) * dot1;
        for (int i_d2 = 0; i_d2 < d; i_d2++) {
            double dxn_j = dx_pos[i_d2];
            double xj = X[ti * d + i_d2];
            double dx_contrib = inv1 * dxn_j - scl1 * xj;
            dX_out[ti * d + i_d2] = dX_out[ti * d + i_d2]
                                  + dh[ti * d + i_d2] + dx_contrib;
        }
    }
    hexa_call1(farr_free, drin_v);
    hexa_call1(farr_free, dh_v);
}
