// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4d6_block_bwd_primitive.c — Phase 4-D-6 dimension-generic
// A2 backward primitive (RFC 047 genericization).
//
// Replaces tool/flame_phase4b3_block_bwd_primitive.c's dim-baked
// flame_block_T16_d32_nh4_nkv2_h64_bwd_primitive with ONE generic function
// whose config arrives as runtime fn arguments:
//   flame_block_generic_bwd_primitive(X_id,Bp_id,Bc_id,dXout_id,dX_out_id,
//                                     Bg_id,cos_id,sin_id, T,d,nh,nkv,h)
//
// ── Why generic / byte-eq argument — see flame_phase4d6_block_fwd_primitive.c
// Same approach: dims → fn args, offsets → bp_off_*/bc_off_* formulas,
// stack scratch (ds_pos_st[64], da/db_pos_st[64], dP_row[16], tmp_rope[8],
// dx_pos[32]) → heap farr. NO reduction loop reordered (PHASE4C audit §6 R1).
// For the d=32 config the computed offsets equal the old literals → the
// executed fp-op sequence is byte-identical.
//
// IMPORTANT — the generic matmul/grad_accum primitives call farr_zeros,
// which may realloc() _hx_farr_table. Every dereferenced pointer is
// re-fetched by id after such calls. (The d=32 primitives used stack
// matmul buffers so the table never moved; the generic ones heap-allocate,
// hence the extra re-fetches — pointer-freshness only, no fp change.)
//
// Calls generic primitives in flame_phase4d6_matmul_primitives.c — concat
// that file FIRST.
// ════════════════════════════════════════════════════════════════════════

#ifndef FLAME_BLOCK_BWD_PRIM_STANDALONE
HexaVal _db_proj_batch_farr(HexaVal W, HexaVal W_off, HexaVal X, HexaVal X_off, HexaVal Y, HexaVal Y_off, HexaVal T, HexaVal d_out, HexaVal d_in);
HexaVal _db_grad_accum_farr(HexaVal dY, HexaVal dY_off, HexaVal X, HexaVal X_off, HexaVal dW_out, HexaVal dW_off, HexaVal T, HexaVal d_out, HexaVal d_in);
#endif

#ifdef FLAME_BLOCK_BWD_PRIM_STANDALONE
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
void flame_grad_accum_generic_primitive(int,int,int,int,int,int,int,int,int);
#endif

// ── Ported transcendentals (mirror flame_math.hexa) ─────────────────
static inline double flame_g_bwd_dt_sqrt(double x) {
    if (x <= 0.0) return 0.0;
    double g = (x > 1.0) ? x : 1.0;
    for (int i = 0; i < 24; i++) g = 0.5 * (g + x / g);
    return g;
}

static inline double flame_g_bwd_dt_exp(double x) {
    int r = 0; double xr = x;
    while ((xr > 0.0 ? xr : -xr) > 0.25) { xr = xr / 2.0; r = r + 1; }
    double term = 1.0, acc = 1.0;
    for (int k = 1; k < 12; k++) { term = term * xr / (double)k; acc = acc + term; }
    for (int s = 0; s < r; s++) acc = acc * acc;
    return acc;
}

static inline double flame_g_bwd_db_sigmoid(double x) {
    return 1.0 / (1.0 + flame_g_bwd_dt_exp(0.0 - x));
}

static inline double flame_g_bwd_db_silu(double x) {
    return x * flame_g_bwd_db_sigmoid(x);
}

static inline double flame_g_bwd_db_silu_grad(double x) {
    double s = flame_g_bwd_db_sigmoid(x);
    return s + x * s * (1.0 - s);
}

// ── Dimension-generic block_bwd ─────────────────────────────────────
// Mirrors flame_phase4b3_block_bwd_primitive.c line-for-line.
static inline void flame_block_generic_bwd_primitive(
    int X_id, int Bp_id, int Bc_id,
    int dXout_id, int dX_out_id, int Bg_id,
    int cos_id, int sin_id,
    int T, int d, int nh, int nkv, int h
) {
    const int hd = d / nh;
    const int half = hd / 2;
    const int kvd = nkv * (d / nh);
    const int n_rep = nh / nkv;
    const double scale = 1.0 / flame_g_bwd_dt_sqrt((double)hd);

    // Bp offsets
    const int G1 = 0;
    const int WQ = d;
    const int WK = d + d*d;
    const int WV = d + d*d + kvd*d;
    const int WO = d + d*d + 2*kvd*d;
    const int G2 = d + 2*d*d + 2*kvd*d;
    const int WG = 2*d + 2*d*d + 2*kvd*d;
    const int WU = 2*d + 2*d*d + 2*kvd*d + h*d;
    const int WD = 2*d + 2*d*d + 2*kvd*d + 2*h*d;
    // Bc offsets
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

    // Heap scratch (d=32 used ds/da/db_pos_st[64], dP_row[16], tmp_rope[8],
    // dx_pos[32] on stack — heap keeps the frame bounded for any config).
    HexaVal dspos_v  = hexa_call1(farr_zeros, hexa_int(h));
    HexaVal dapos_v  = hexa_call1(farr_zeros, hexa_int(h));
    HexaVal dbpos_v  = hexa_call1(farr_zeros, hexa_int(h));
    HexaVal dProw_v  = hexa_call1(farr_zeros, hexa_int(T));
    HexaVal trope_v  = hexa_call1(farr_zeros, hexa_int(hd));
    HexaVal dxpos_v  = hexa_call1(farr_zeros, hexa_int(d));
    int dspos_id=(int)dspos_v.i, dapos_id=(int)dapos_v.i, dbpos_id=(int)dbpos_v.i;
    int dProw_id=(int)dProw_v.i, trope_id=(int)trope_v.i, dxpos_id=(int)dxpos_v.i;

    double* X     = _hx_farr_table[X_id].buf;
    double* Bp    = _hx_farr_table[Bp_id].buf;
    double* Bc    = _hx_farr_table[Bc_id].buf;
    double* dXout = _hx_farr_table[dXout_id].buf;
    double* dX_out = _hx_farr_table[dX_out_id].buf;
    double* Bg    = _hx_farr_table[Bg_id].buf;
    double* cos_  = _hx_farr_table[cos_id].buf;
    double* sin_  = _hx_farr_table[sin_id].buf;
    (void)X; (void)cos_; (void)sin_; (void)dX_out;

    // ─── 9rev: dh = dXout (residual passthrough) ──────────────────
    HexaVal dh_v = hexa_call1(farr_zeros, hexa_int(T * d));
    int dh_id = (int)dh_v.i;
    double* dh = _hx_farr_table[dh_id].buf;
    dXout = _hx_farr_table[dXout_id].buf;
    for (int i = 0; i < T * d; i++) dh[i] = dXout[i];

    // ─── 8rev: SwiGLU bwd (generic grad_accum: dWd d×h) ───────────
    flame_grad_accum_generic_primitive(dXout_id, 0, Bc_id, oSwS, Bg_id, WD, T, d, h);
    Bc = _hx_farr_table[Bc_id].buf;
    Bg = _hx_farr_table[Bg_id].buf;
    Bp = _hx_farr_table[Bp_id].buf;
    dXout = _hx_farr_table[dXout_id].buf;
    dh = _hx_farr_table[dh_id].buf;

    HexaVal dr_pos_v = hexa_call1(farr_zeros, hexa_int(d));
    HexaVal da_all_v = hexa_call1(farr_zeros, hexa_int(T * h));
    HexaVal db_all_v = hexa_call1(farr_zeros, hexa_int(T * h));
    int dr_pos_id = (int)dr_pos_v.i;
    int da_all_id = (int)da_all_v.i;
    int db_all_id = (int)db_all_v.i;
    // Re-fetch all after the 3 allocations.
    Bc = _hx_farr_table[Bc_id].buf;
    Bg = _hx_farr_table[Bg_id].buf;
    Bp = _hx_farr_table[Bp_id].buf;
    dXout = _hx_farr_table[dXout_id].buf;
    dh = _hx_farr_table[dh_id].buf;
    double* dr_pos = _hx_farr_table[dr_pos_id].buf;
    double* da_all = _hx_farr_table[da_all_id].buf;
    double* db_all = _hx_farr_table[db_all_id].buf;
    double* ds_pos_st = _hx_farr_table[dspos_id].buf;
    double* da_pos_st = _hx_farr_table[dapos_id].buf;
    double* db_pos_st = _hx_farr_table[dbpos_id].buf;

    for (int ts = 0; ts < T; ts++) {
        // ds[k] = Σ_r Wd[r·h+k] · dXout[ts·d+r]
        for (int k = 0; k < h; k++) {
            double acc = 0.0;
            for (int rr = 0; rr < d; rr++) {
                acc = acc + Bp[WD + rr * h + k] * dXout[ts * d + rr];
            }
            ds_pos_st[k] = acc;
        }
        // da/db inline
        for (int k = 0; k < h; k++) {
            double ak = Bc[oSwA + ts * h + k];
            double bk = Bc[oSwB + ts * h + k];
            double dsk = ds_pos_st[k];
            double da_v = dsk * bk * flame_g_bwd_db_silu_grad(ak);
            double db_v = dsk * flame_g_bwd_db_silu(ak);
            da_pos_st[k] = da_v;
            db_pos_st[k] = db_v;
            da_all[ts * h + k] = da_v;
            db_all[ts * h + k] = db_v;
        }
        // dr[c] = Σ_k (Wg[k·d+c]·da[k] + Wu[k·d+c]·db[k])
        for (int cc = 0; cc < d; cc++) {
            double acc2 = 0.0;
            for (int k = 0; k < h; k++) {
                acc2 = acc2 + Bp[WG + k * d + cc] * da_pos_st[k]
                            + Bp[WU + k * d + cc] * db_pos_st[k];
            }
            dr_pos[cc] = acc2;
        }

        // ─── 7rev (per-ts): RMSNorm 2 vjp ──────────────────────
        double inv2 = Bc[oR2inv + ts];
        double dot2 = 0.0;
        for (int i7 = 0; i7 < d; i7++) {
            double dxn_i = dr_pos[i7] * Bp[G2 + i7];
            Bg[G2 + i7] = Bg[G2 + i7]
                        + dr_pos[i7] * Bc[oRm2xn + ts * d + i7];
            dot2 = dot2 + dxn_i * Bc[oHstate + ts * d + i7];
            dr_pos[i7] = dxn_i;  // stash
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
    // Batched dWg/dWu accumulators (generic grad_accum: h×d)
    flame_grad_accum_generic_primitive(da_all_id, 0, Bc_id, oRin2, Bg_id, WG, T, h, d);
    flame_grad_accum_generic_primitive(db_all_id, 0, Bc_id, oRin2, Bg_id, WU, T, h, d);
    hexa_call1(farr_free, dr_pos_v);
    hexa_call1(farr_free, da_all_v);
    hexa_call1(farr_free, db_all_v);
    Bc = _hx_farr_table[Bc_id].buf;
    Bg = _hx_farr_table[Bg_id].buf;
    Bp = _hx_farr_table[Bp_id].buf;
    dh = _hx_farr_table[dh_id].buf;

    // ─── 6rev: dX_residual += dh  (deferred to 1rev write) ────
    // ─── 5rev: Wo proj bwd (generic grad_accum: d×d) + dctx inline ──
    flame_grad_accum_generic_primitive(dh_id, 0, Bc_id, oCtx, Bg_id, WO, T, d, d);
    Bc = _hx_farr_table[Bc_id].buf;
    Bp = _hx_farr_table[Bp_id].buf;
    Bg = _hx_farr_table[Bg_id].buf;
    dh = _hx_farr_table[dh_id].buf;

    HexaVal dctx_v = hexa_call1(farr_zeros, hexa_int(T * d));
    int dctx_id = (int)dctx_v.i;
    Bc = _hx_farr_table[Bc_id].buf;
    Bp = _hx_farr_table[Bp_id].buf;
    dh = _hx_farr_table[dh_id].buf;
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

    // ─── 4rev: attention bwd ─────────────────────────────────
    HexaVal dQ_v = hexa_call1(farr_zeros, hexa_int(T * d));
    HexaVal dK_v = hexa_call1(farr_zeros, hexa_int(T * kvd));
    HexaVal dV_v = hexa_call1(farr_zeros, hexa_int(T * kvd));
    int dQ_id = (int)dQ_v.i;
    int dK_id = (int)dK_v.i;
    int dV_id = (int)dV_v.i;
    Bc   = _hx_farr_table[Bc_id].buf;
    dctx = _hx_farr_table[dctx_id].buf;
    double* dQ = _hx_farr_table[dQ_id].buf;
    double* dK = _hx_farr_table[dK_id].buf;
    double* dV = _hx_farr_table[dV_id].buf;
    double* dP_row = _hx_farr_table[dProw_id].buf;
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

    // ─── 3rev: RoPE bwd inverse rotation ──────────────────────
    {
        dQ = _hx_farr_table[dQ_id].buf;
        dK = _hx_farr_table[dK_id].buf;
        cos_ = _hx_farr_table[cos_id].buf;
        sin_ = _hx_farr_table[sin_id].buf;
        double* tmp_rope = _hx_farr_table[trope_id].buf;
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

    // ─── 2rev: Q/K/V proj bwd (generic grad_accum) + drin inline ─
    flame_grad_accum_generic_primitive(dQ_id, 0, Bc_id, oRin, Bg_id, WQ, T, d,   d);
    flame_grad_accum_generic_primitive(dK_id, 0, Bc_id, oRin, Bg_id, WK, T, kvd, d);
    flame_grad_accum_generic_primitive(dV_id, 0, Bc_id, oRin, Bg_id, WV, T, kvd, d);
    Bp = _hx_farr_table[Bp_id].buf;
    Bg = _hx_farr_table[Bg_id].buf;
    Bc = _hx_farr_table[Bc_id].buf;
    dQ = _hx_farr_table[dQ_id].buf;
    dK = _hx_farr_table[dK_id].buf;
    dV = _hx_farr_table[dV_id].buf;
    dh = _hx_farr_table[dh_id].buf;

    HexaVal drin_v = hexa_call1(farr_zeros, hexa_int(T * d));
    int drin_id = (int)drin_v.i;
    Bp = _hx_farr_table[Bp_id].buf;
    dQ = _hx_farr_table[dQ_id].buf;
    dK = _hx_farr_table[dK_id].buf;
    dV = _hx_farr_table[dV_id].buf;
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

    // ─── 1rev: RMSNorm 1 vjp + dX_out final write ──────────────
    Bp = _hx_farr_table[Bp_id].buf;
    Bg = _hx_farr_table[Bg_id].buf;
    Bc = _hx_farr_table[Bc_id].buf;
    drin = _hx_farr_table[drin_id].buf;
    dh = _hx_farr_table[dh_id].buf;
    X = _hx_farr_table[X_id].buf;
    dX_out = _hx_farr_table[dX_out_id].buf;
    double* dx_pos = _hx_farr_table[dxpos_id].buf;
    for (int ti = 0; ti < T; ti++) {
        double inv1 = Bc[oR1inv + ti];
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
    hexa_call1(farr_free, dxpos_v);
    hexa_call1(farr_free, trope_v);
    hexa_call1(farr_free, dProw_v);
    hexa_call1(farr_free, dbpos_v);
    hexa_call1(farr_free, dapos_v);
    hexa_call1(farr_free, dspos_v);
}
