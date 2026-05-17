// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4d7_block_bwd_primitive.c — Phase 4-D-7 GPU-RESIDENT
// A2 backward primitive.
//
// Forks tool/flame_phase4d6_block_bwd_primitive.c. Same 4-part Phase 4-D-7
// transformation as the fwd primitive (see flame_phase4d7_block_fwd_
// primitive.c header): persistent device residency, non-matmul ops → forge
// Phase B kernels, attention-bwd contractions → cuBLAS, RoPE-bwd remaining
// CPU (forge RoPE kernel not yet shipped — RFC 041 gap).
//
// ── BYTE-EQ CONTRACT (d=32·3L) ───────────────────────────────────────────
// d ≤ FLAME_GPU_RESIDENT_THRESHOLD → CPU loop, byte-identical to the
// flame_phase4d6 bwd primitive (verbatim copy below). d=32 stays strictly
// byte-eq. d > threshold → GPU-resident; numerical contract TOL_OP ≈ 1e-9
// (forge Phase B kernels TOL_OP-verified, not bit-exact for reductions —
// PHASE4C audit §6 R1 / RFC 040-041).
//
// ── What is GPU-resident in the bwd path ─────────────────────────────────
//   SwiGLU bwd dW (grad_accum)   → flame_grad_accum_generic_primitive (cuBLAS)
//   silu / silu_grad             → hexa_farr_silu_gpu / _silu_grad_gpu
//   da/db Hadamard               → hexa_farr_mul_gpu
//   RMSNorm bwd vjp (×2)         → hexa_farr_rmsnorm_bwd_rows_gpu
//   Wo / Q / K / V proj bwd      → flame_grad_accum_generic_primitive (cuBLAS)
//   attention bwd contractions   → CPU (per-row causal growing-L; the
//                                  dominant grad_accum dW work IS cuBLAS,
//                                  the score-grad triangle stays CPU —
//                                  honest, the causal mask blocks a clean
//                                  batched Dgemm without a forge masked
//                                  attention-bwd kernel)
//   RoPE bwd                     → CPU (forge RoPE kernel not shipped)
//
// Calls generic matmul/grad_accum primitives in
// flame_phase4d6_matmul_primitives.c (reused — concat that file FIRST).
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

#ifndef FLAME_GPU_RESIDENT_THRESHOLD
#define FLAME_GPU_RESIDENT_THRESHOLD 256
#endif

// ── Ported transcendentals (mirror flame_math.hexa) ─────────────────
static inline double flame_g7_bwd_dt_sqrt(double x) {
    if (x <= 0.0) return 0.0;
    double g = (x > 1.0) ? x : 1.0;
    for (int i = 0; i < 24; i++) g = 0.5 * (g + x / g);
    return g;
}

static inline double flame_g7_bwd_dt_exp(double x) {
    int r = 0; double xr = x;
    while ((xr > 0.0 ? xr : -xr) > 0.25) { xr = xr / 2.0; r = r + 1; }
    double term = 1.0, acc = 1.0;
    for (int k = 1; k < 12; k++) { term = term * xr / (double)k; acc = acc + term; }
    for (int s = 0; s < r; s++) acc = acc * acc;
    return acc;
}

static inline double flame_g7_bwd_db_sigmoid(double x) {
    return 1.0 / (1.0 + flame_g7_bwd_dt_exp(0.0 - x));
}

static inline double flame_g7_bwd_db_silu(double x) {
    return x * flame_g7_bwd_db_sigmoid(x);
}

static inline double flame_g7_bwd_db_silu_grad(double x) {
    double s = flame_g7_bwd_db_sigmoid(x);
    return s + x * s * (1.0 - s);
}

// ════════════════════════════════════════════════════════════════════════
// PART 1 — CPU-loop A2 bwd (byte-identical to flame_phase4d6 — d≤threshold)
// ════════════════════════════════════════════════════════════════════════
// Verbatim copy of flame_block_generic_bwd_primitive from
// flame_phase4d6_block_bwd_primitive.c. NO loop reordered. d=32 byte-eq path.
static inline void flame_block_generic_bwd_primitive_cpu(
    int X_id, int Bp_id, int Bc_id,
    int dXout_id, int dX_out_id, int Bg_id,
    int cos_id, int sin_id,
    int T, int d, int nh, int nkv, int h
) {
    const int hd = d / nh;
    const int half = hd / 2;
    const int kvd = nkv * (d / nh);
    const int n_rep = nh / nkv;
    const double scale = 1.0 / flame_g7_bwd_dt_sqrt((double)hd);

    const int G1 = 0;
    const int WQ = d;
    const int WK = d + d*d;
    const int WV = d + d*d + kvd*d;
    const int WO = d + d*d + 2*kvd*d;
    const int G2 = d + 2*d*d + 2*kvd*d;
    const int WG = 2*d + 2*d*d + 2*kvd*d;
    const int WU = 2*d + 2*d*d + 2*kvd*d + h*d;
    const int WD = 2*d + 2*d*d + 2*kvd*d + 2*h*d;
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

    HexaVal dh_v = hexa_call1(farr_zeros, hexa_int(T * d));
    int dh_id = (int)dh_v.i;
    double* dh = _hx_farr_table[dh_id].buf;
    dXout = _hx_farr_table[dXout_id].buf;
    for (int i = 0; i < T * d; i++) dh[i] = dXout[i];

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
            double da_v = dsk * bk * flame_g7_bwd_db_silu_grad(ak);
            double db_v = dsk * flame_g7_bwd_db_silu(ak);
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
    flame_grad_accum_generic_primitive(da_all_id, 0, Bc_id, oRin2, Bg_id, WG, T, h, d);
    flame_grad_accum_generic_primitive(db_all_id, 0, Bc_id, oRin2, Bg_id, WU, T, h, d);
    hexa_call1(farr_free, dr_pos_v);
    hexa_call1(farr_free, da_all_v);
    hexa_call1(farr_free, db_all_v);
    Bc = _hx_farr_table[Bc_id].buf;
    Bg = _hx_farr_table[Bg_id].buf;
    Bp = _hx_farr_table[Bp_id].buf;
    dh = _hx_farr_table[dh_id].buf;

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

#ifndef FLAME_BLOCK_BWD_PRIM_STANDALONE
// ════════════════════════════════════════════════════════════════════════
// PART 2 — GPU-RESIDENT A2 bwd (d≥threshold path)
// ════════════════════════════════════════════════════════════════════════
// Forge Phase B2 dispatchers (declared in runtime.c, concat'd ahead):
//   hexa_farr_silu_gpu / _silu_grad_gpu / _mul_gpu / _add_gpu /
//   _rmsnorm_bwd_rows_gpu — verified byte-eq A100 (Phase 4-D-5-3).
// The grad-accumulator matmuls (dW = dYᵀ·X) route through
// flame_grad_accum_generic_primitive which itself dispatches to cuBLAS at
// large shapes (FLAME_MATMUL_GPU_THRESHOLD).
//
// The GPU-resident bwd keeps the SAME math sequence as the CPU bwd; the
// per-position SwiGLU element work (silu_grad, Hadamard) and the two
// RMSNorm vjp's are dispatched to forge kernels instead of CPU loops.
// The per-row causal attention-bwd triangle stays CPU (no forge masked
// attention-bwd kernel exists — honest carve-out, named for a follow-on).
// ════════════════════════════════════════════════════════════════════════

HexaVal hexa_farr_to_device(HexaVal h_v);
HexaVal hexa_farr_to_host(HexaVal h_v);
HexaVal hexa_farr_zeros(HexaVal n_v);
HexaVal hexa_farr_free(HexaVal h_v);
HexaVal hexa_farr_silu_gpu(HexaVal x_v, HexaVal n_v);
HexaVal hexa_farr_silu_grad_gpu(HexaVal x_v, HexaVal n_v);
HexaVal hexa_farr_mul_gpu(HexaVal a_v, HexaVal b_v, HexaVal n_v);
HexaVal hexa_farr_rmsnorm_bwd_rows_gpu(HexaVal x_v, HexaVal dxn_v, HexaVal r_v, HexaVal c_v);
HexaVal hexa_farr_rope_bwd_gpu(HexaVal t_v, HexaVal cos_v, HexaVal sin_v, HexaVal T_v, HexaVal nh_v, HexaVal hd_v);

// ── GPU-resident A2 backward (d≥threshold) ──────────────────────────────
// Structurally identical to the CPU bwd; the inner element-wise loops for
// SwiGLU activation grads route to forge silu/silu_grad/mul kernels. The
// resident model: Bp/Bc/Bg/dXout uploaded once at entry, dX_out + Bg
// brought back at exit.
static void flame_block_generic_bwd_primitive_gpu(
    int X_id, int Bp_id, int Bc_id,
    int dXout_id, int dX_out_id, int Bg_id,
    int cos_id, int sin_id,
    int T, int d, int nh, int nkv, int h
) {
    const int hd = d / nh;
    const int half = hd / 2;
    const int kvd = nkv * (d / nh);
    const int n_rep = nh / nkv;
    const double scale = 1.0 / flame_g7_bwd_dt_sqrt((double)hd);

    const int G1 = 0;
    const int WQ = d;
    const int WK = d + d*d;
    const int WV = d + d*d + kvd*d;
    const int WO = d + d*d + 2*kvd*d;
    const int G2 = d + 2*d*d + 2*kvd*d;
    const int WG = 2*d + 2*d*d + 2*kvd*d;
    const int WU = 2*d + 2*d*d + 2*kvd*d + h*d;
    const int WD = 2*d + 2*d*d + 2*kvd*d + 2*h*d;
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

    // ── PART 1: persistent device residency ──
    hexa_farr_to_device(hexa_int(X_id));
    hexa_farr_to_device(hexa_int(Bp_id));
    hexa_farr_to_device(hexa_int(Bc_id));
    hexa_farr_to_device(hexa_int(Bg_id));
    hexa_farr_to_device(hexa_int(dXout_id));

    HexaVal dh_v = hexa_farr_zeros(hexa_int((int64_t)T * d));
    int dh_id = (int)dh_v.i;
    {
        double* dh = _hx_farr_table[dh_id].buf;
        double* dXout = _hx_farr_table[dXout_id].buf;
        for (int i = 0; i < T * d; i++) dh[i] = dXout[i];
    }

    // ─── 8rev: SwiGLU bwd. dWd via cuBLAS grad_accum. ────────────
    flame_grad_accum_generic_primitive(dXout_id, 0, Bc_id, oSwS, Bg_id, WD, T, d, h);

    HexaVal da_all_v = hexa_farr_zeros(hexa_int((int64_t)T * h));
    HexaVal db_all_v = hexa_farr_zeros(hexa_int((int64_t)T * h));
    int da_all_id = (int)da_all_v.i;
    int db_all_id = (int)db_all_v.i;

    // ds_all[ts·h+k] = Σ_r Wd[r·h+k]·dXout[ts·d+r]  — matmul-shaped.
    // Build dXout-block [T·d] and Wd [d·h], dispatch dXout·Wd → ds [T·h].
    HexaVal ds_all_v = hexa_farr_zeros(hexa_int((int64_t)T * h));
    int ds_all_id = (int)ds_all_v.i;
    {
        // ds = dXout(T×d) · Wd(d×h)   via flame_proj_batch (cuBLAS at scale)
        // flame_proj_batch_generic_primitive(W,W_off,X,X_off,Y,Y_off,T,d_out,d_in)
        //   computes Y[t·d_out+r] = Σ_c W[r·d_in+c]·X[t·d_in+c].
        // We need ds[t·h+k] = Σ_r dXout[t·d+r]·Wd[r·h+k]. Treat Wdᵀ as the
        // "W" (h×d) and dXout as "X" (T×d): Y[t·h+k]=Σ_r Wdᵀ[k·d+r]·dXout[t·d+r].
        HexaVal wdt_v = hexa_farr_zeros(hexa_int((int64_t)h * d));
        int wdt_id = (int)wdt_v.i;
        {
            double* Bp = _hx_farr_table[Bp_id].buf;
            double* wdt = _hx_farr_table[wdt_id].buf;
            for (int r = 0; r < d; r++)
                for (int k = 0; k < h; k++) wdt[k*d + r] = Bp[WD + r*h + k];
        }
        hexa_farr_to_device(wdt_v);
        flame_proj_batch_generic_primitive(wdt_id, 0, dXout_id, 0, ds_all_id, 0,
                                           T, h, d);
        hexa_farr_free(wdt_v);
    }
    // da/db element grads — forge silu_grad + silu + mul kernels.
    {
        // ak = Bc[oSwA..], bk = Bc[oSwB..]; build contiguous a,b [T·h].
        HexaVal a_v = hexa_farr_zeros(hexa_int((int64_t)T * h));
        HexaVal b_v = hexa_farr_zeros(hexa_int((int64_t)T * h));
        int a_id = (int)a_v.i, b_id = (int)b_v.i;
        {
            double* Bc = _hx_farr_table[Bc_id].buf;
            double* av = _hx_farr_table[a_id].buf;
            double* bv = _hx_farr_table[b_id].buf;
            for (int p = 0; p < T * h; p++) { av[p] = Bc[oSwA+p]; bv[p] = Bc[oSwB+p]; }
        }
        hexa_farr_to_device(a_v);
        hexa_farr_to_device(b_v);
        HexaVal sg_v   = hexa_farr_silu_grad_gpu(hexa_int(a_id), hexa_int((int64_t)T*h));
        HexaVal silu_v = hexa_farr_silu_gpu(hexa_int(a_id), hexa_int((int64_t)T*h));
        int sg_id = (int)sg_v.i, silu_id = (int)silu_v.i;
        if (sg_id >= 0 && silu_id >= 0) {
            // da = ds ⊙ b ⊙ silu_grad(a)   ;   db = ds ⊙ silu(a)
            HexaVal dsb_v = hexa_farr_mul_gpu(hexa_int(ds_all_id), hexa_int(b_id),
                                              hexa_int((int64_t)T*h));
            int dsb_id = (int)dsb_v.i;
            if (dsb_id >= 0) {
                HexaVal da_v = hexa_farr_mul_gpu(hexa_int(dsb_id), hexa_int(sg_id),
                                                 hexa_int((int64_t)T*h));
                int da_id = (int)da_v.i;
                if (da_id >= 0) {
                    double* da = _hx_farr_table[da_id].buf;
                    double* da_all = _hx_farr_table[da_all_id].buf;
                    for (int p = 0; p < T*h; p++) da_all[p] = da[p];
                    hexa_farr_free(da_v);
                }
                hexa_farr_free(dsb_v);
            }
            HexaVal db_v = hexa_farr_mul_gpu(hexa_int(ds_all_id), hexa_int(silu_id),
                                             hexa_int((int64_t)T*h));
            int db_id = (int)db_v.i;
            if (db_id >= 0) {
                double* db = _hx_farr_table[db_id].buf;
                double* db_all = _hx_farr_table[db_all_id].buf;
                for (int p = 0; p < T*h; p++) db_all[p] = db[p];
                hexa_farr_free(db_v);
            }
            hexa_farr_free(silu_v);
            hexa_farr_free(sg_v);
        } else {  // CPU fallback for da/db
            double* Bc = _hx_farr_table[Bc_id].buf;
            double* ds = _hx_farr_table[ds_all_id].buf;
            double* da_all = _hx_farr_table[da_all_id].buf;
            double* db_all = _hx_farr_table[db_all_id].buf;
            for (int p = 0; p < T*h; p++) {
                double ak = Bc[oSwA+p], bk = Bc[oSwB+p], dsk = ds[p];
                da_all[p] = dsk * bk * flame_g7_bwd_db_silu_grad(ak);
                db_all[p] = dsk * flame_g7_bwd_db_silu(ak);
            }
            if (sg_id >= 0) hexa_farr_free(sg_v);
            if (silu_id >= 0) hexa_farr_free(silu_v);
        }
        hexa_farr_free(b_v);
        hexa_farr_free(a_v);
    }
    // dWg / dWu accumulators — cuBLAS grad_accum (h×d).
    flame_grad_accum_generic_primitive(da_all_id, 0, Bc_id, oRin2, Bg_id, WG, T, h, d);
    flame_grad_accum_generic_primitive(db_all_id, 0, Bc_id, oRin2, Bg_id, WU, T, h, d);

    // dr[ts·d+c] = Σ_k (Wg[k·d+c]·da[k] + Wu[k·d+c]·db[k])  — matmul-shaped.
    HexaVal dr_all_v = hexa_farr_zeros(hexa_int((int64_t)T * d));
    int dr_all_id = (int)dr_all_v.i;
    {
        // dr = da · Wg + db · Wu. flame_proj_batch with W=Wgᵀ(d×h is Wg,
        // need Y[t·d+c]=Σ_k Wg[k·d+c]·da[t·h+k]); treat Wg as already k×d:
        // Wg[k·d+c] → "W" of shape d×h needs Wg-transpose. Build Wgt[c·h+k].
        HexaVal wgt_v = hexa_farr_zeros(hexa_int((int64_t)d * h));
        HexaVal wut_v = hexa_farr_zeros(hexa_int((int64_t)d * h));
        int wgt_id = (int)wgt_v.i, wut_id = (int)wut_v.i;
        {
            double* Bp = _hx_farr_table[Bp_id].buf;
            double* wgt = _hx_farr_table[wgt_id].buf;
            double* wut = _hx_farr_table[wut_id].buf;
            for (int k = 0; k < h; k++)
                for (int c = 0; c < d; c++) {
                    wgt[c*h + k] = Bp[WG + k*d + c];
                    wut[c*h + k] = Bp[WU + k*d + c];
                }
        }
        hexa_farr_to_device(wgt_v);
        hexa_farr_to_device(wut_v);
        HexaVal drg_v = hexa_farr_zeros(hexa_int((int64_t)T * d));
        HexaVal dru_v = hexa_farr_zeros(hexa_int((int64_t)T * d));
        int drg_id = (int)drg_v.i, dru_id = (int)dru_v.i;
        flame_proj_batch_generic_primitive(wgt_id, 0, da_all_id, 0, drg_id, 0, T, d, h);
        flame_proj_batch_generic_primitive(wut_id, 0, db_all_id, 0, dru_id, 0, T, d, h);
        {
            double* drg = _hx_farr_table[drg_id].buf;
            double* dru = _hx_farr_table[dru_id].buf;
            double* dr  = _hx_farr_table[dr_all_id].buf;
            for (int p = 0; p < T * d; p++) dr[p] = drg[p] + dru[p];
        }
        hexa_farr_free(dru_v);
        hexa_farr_free(drg_v);
        hexa_farr_free(wut_v);
        hexa_farr_free(wgt_v);
    }
    hexa_farr_free(ds_all_v);
    hexa_farr_free(db_all_v);
    hexa_farr_free(da_all_v);

    // ─── 7rev: RMSNorm 2 vjp.  γ-grad accumulate + dh contribution. ──
    // dr currently holds dr (pre-gain). The RMSNorm vjp: Bg[G2] += dr⊙rm2xn;
    // dxn = dr⊙γ; dh += rmsnorm_bwd(hstate, dxn). The inv-rms vjp core is
    // the forge rmsnorm_bwd_rows kernel.
    {
        double* Bp = _hx_farr_table[Bp_id].buf;
        double* Bg = _hx_farr_table[Bg_id].buf;
        double* Bc = _hx_farr_table[Bc_id].buf;
        double* dr = _hx_farr_table[dr_all_id].buf;
        // γ-grad: Bg[G2+c] += Σ_t dr[t·d+c]·rm2xn[t·d+c]
        for (int t = 0; t < T; t++)
            for (int c = 0; c < d; c++)
                Bg[G2 + c] += dr[t*d+c] * Bc[oRm2xn + t*d + c];
        // dxn = dr ⊙ γ  (broadcast γ over rows)
        for (int t = 0; t < T; t++)
            for (int c = 0; c < d; c++)
                dr[t*d+c] = dr[t*d+c] * Bp[G2 + c];
    }
    {
        // dh += rmsnorm_bwd(hstate-slab, dxn)  — forge kernel.
        HexaVal hs_v  = hexa_farr_zeros(hexa_int((int64_t)T * d));
        HexaVal dxn_v = hexa_farr_zeros(hexa_int((int64_t)T * d));
        int hs_id = (int)hs_v.i, dxn_id = (int)dxn_v.i;
        {
            double* Bc = _hx_farr_table[Bc_id].buf;
            double* dr = _hx_farr_table[dr_all_id].buf;
            double* hs = _hx_farr_table[hs_id].buf;
            double* dxn = _hx_farr_table[dxn_id].buf;
            for (int p = 0; p < T * d; p++) { hs[p] = Bc[oHstate+p]; dxn[p] = dr[p]; }
        }
        hexa_farr_to_device(hs_v);
        hexa_farr_to_device(dxn_v);
        HexaVal dx_v = hexa_farr_rmsnorm_bwd_rows_gpu(
            hexa_int(hs_id), hexa_int(dxn_id), hexa_int(T), hexa_int(d));
        int dx_id = (int)dx_v.i;
        double* dh = _hx_farr_table[dh_id].buf;
        if (dx_id >= 0) {
            double* dx = _hx_farr_table[dx_id].buf;
            for (int p = 0; p < T * d; p++) dh[p] += dx[p];
            hexa_farr_free(dx_v);
        } else {  // CPU fallback for the RMSNorm-2 vjp
            double* Bc = _hx_farr_table[Bc_id].buf;
            double* dr = _hx_farr_table[dr_all_id].buf;
            for (int t = 0; t < T; t++) {
                double inv2 = Bc[oR2inv + t];
                double dot2 = 0.0;
                for (int c = 0; c < d; c++)
                    dot2 += dr[t*d+c] * Bc[oHstate + t*d + c];
                double inv3 = inv2*inv2*inv2;
                double scl = (inv3 / (double)d) * dot2;
                for (int c = 0; c < d; c++)
                    dh[t*d+c] += inv2 * dr[t*d+c] - scl * Bc[oHstate + t*d + c];
            }
        }
        hexa_farr_free(dxn_v);
        hexa_farr_free(hs_v);
    }
    hexa_farr_free(dr_all_v);

    // ─── 5rev: Wo proj bwd (cuBLAS grad_accum) + dctx ────────────
    flame_grad_accum_generic_primitive(dh_id, 0, Bc_id, oCtx, Bg_id, WO, T, d, d);
    HexaVal dctx_v = hexa_farr_zeros(hexa_int((int64_t)T * d));
    int dctx_id = (int)dctx_v.i;
    {
        // dctx = dh · Wo  →  flame_proj_batch with W = Woᵀ (d×d).
        HexaVal wot_v = hexa_farr_zeros(hexa_int((int64_t)d * d));
        int wot_id = (int)wot_v.i;
        {
            double* Bp = _hx_farr_table[Bp_id].buf;
            double* wot = _hx_farr_table[wot_id].buf;
            for (int r = 0; r < d; r++)
                for (int c = 0; c < d; c++) wot[c*d + r] = Bp[WO + r*d + c];
        }
        hexa_farr_to_device(wot_v);
        flame_proj_batch_generic_primitive(wot_id, 0, dh_id, 0, dctx_id, 0, T, d, d);
        hexa_farr_free(wot_v);
    }

    // ─── 4rev: attention bwd — per-row causal triangle stays CPU ──
    // No forge masked attention-bwd kernel exists; the growing-L causal
    // dependency forbids a clean batched Dgemm. Honest CPU carve-out.
    HexaVal dQ_v = hexa_farr_zeros(hexa_int((int64_t)T * d));
    HexaVal dK_v = hexa_farr_zeros(hexa_int((int64_t)T * kvd));
    HexaVal dV_v = hexa_farr_zeros(hexa_int((int64_t)T * kvd));
    HexaVal dProw_v = hexa_farr_zeros(hexa_int((int64_t)T));
    int dQ_id = (int)dQ_v.i, dK_id = (int)dK_v.i, dV_id = (int)dV_v.i;
    int dProw_id = (int)dProw_v.i;
    {
        double* Bc   = _hx_farr_table[Bc_id].buf;
        double* dctx = _hx_farr_table[dctx_id].buf;
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
                    for (int c = 0; c < hd; c++)
                        acc += dctx[i_b*d + hh_b*hd + c]
                             * Bc[oV + (j*nkv+kvh)*hd + c];
                    dP_row[j] = acc;
                }
                double sdot = 0.0;
                for (int j2 = 0; j2 < L; j2++)
                    sdot += Bc[oP + (hh_b*T+i_b)*T + j2] * dP_row[j2];
                for (int j3 = 0; j3 < L; j3++) {
                    double pij = Bc[oP + (hh_b*T+i_b)*T + j3];
                    for (int c = 0; c < hd; c++) {
                        int idx_dv = (j3*nkv+kvh)*hd + c;
                        dV[idx_dv] += pij * dctx[i_b*d + hh_b*hd + c];
                    }
                }
                for (int j4 = 0; j4 < L; j4++) {
                    double dS = Bc[oP + (hh_b*T+i_b)*T + j4]
                              * (dP_row[j4] - sdot) * scale;
                    for (int c2 = 0; c2 < hd; c2++) {
                        int idx_dq = (i_b*nh+hh_b)*hd + c2;
                        int idx_dk = (j4*nkv+kvh)*hd + c2;
                        dQ[idx_dq] += dS * Bc[oK + (j4*nkv+kvh)*hd + c2];
                        dK[idx_dk] += dS * Bc[oQ + (i_b*nh+hh_b)*hd + c2];
                    }
                }
            }
        }
    }
    hexa_farr_free(dProw_v);
    hexa_farr_free(dctx_v);

    // ─── 3rev: RoPE bwd — forge RoPE-bwd kernel (landed commit 9582a395) ─
    // dQ is [T·nh·hd] contiguous, dK is [T·nkv·hd] contiguous — both from
    // index 0. hexa_farr_rope_bwd_gpu applies the inverse rotation in the
    // [T·nheads·hd] layout. Dispatch in-place via fresh slabs.
    {
        hexa_farr_to_device(dQ_v);
        HexaVal qr_v = hexa_farr_rope_bwd_gpu(hexa_int(dQ_id), hexa_int(cos_id),
            hexa_int(sin_id), hexa_int(T), hexa_int(nh), hexa_int(hd));
        int qr_id = (int)qr_v.i;
        if (qr_id >= 0) {
            double* qr = _hx_farr_table[qr_id].buf;
            double* dQ = _hx_farr_table[dQ_id].buf;
            for (int p = 0; p < T * nh * hd; p++) dQ[p] = qr[p];
            hexa_farr_free(qr_v);
        } else {  // CPU fallback rope-bwd (dQ)
            double* dQ = _hx_farr_table[dQ_id].buf;
            double* cos_ = _hx_farr_table[cos_id].buf;
            double* sin_ = _hx_farr_table[sin_id].buf;
            for (int t_r = 0; t_r < T; t_r++) {
                int bse = t_r * hd;
                for (int hh = 0; hh < nh; hh++) {
                    int row_off = (t_r * nh + hh) * hd;
                    double tmp[256];
                    for (int c = 0; c < hd; c++) {
                        double gs = (c < half)
                            ? dQ[row_off + half + c] * sin_[bse + half + c]
                            : (0.0 - dQ[row_off + c - half] * sin_[bse + c - half]);
                        tmp[c] = dQ[row_off + c] * cos_[bse + c] + gs;
                    }
                    for (int c2 = 0; c2 < hd; c2++) dQ[row_off + c2] = tmp[c2];
                }
            }
        }
        hexa_farr_to_device(dK_v);
        HexaVal kr_v = hexa_farr_rope_bwd_gpu(hexa_int(dK_id), hexa_int(cos_id),
            hexa_int(sin_id), hexa_int(T), hexa_int(nkv), hexa_int(hd));
        int kr_id = (int)kr_v.i;
        if (kr_id >= 0) {
            double* kr = _hx_farr_table[kr_id].buf;
            double* dK = _hx_farr_table[dK_id].buf;
            for (int p = 0; p < T * nkv * hd; p++) dK[p] = kr[p];
            hexa_farr_free(kr_v);
        } else {  // CPU fallback rope-bwd (dK)
            double* dK = _hx_farr_table[dK_id].buf;
            double* cos_ = _hx_farr_table[cos_id].buf;
            double* sin_ = _hx_farr_table[sin_id].buf;
            for (int t_r = 0; t_r < T; t_r++) {
                int bse = t_r * hd;
                for (int hk = 0; hk < nkv; hk++) {
                    int row_off = (t_r * nkv + hk) * hd;
                    double tmp[256];
                    for (int c = 0; c < hd; c++) {
                        double gs = (c < half)
                            ? dK[row_off + half + c] * sin_[bse + half + c]
                            : (0.0 - dK[row_off + c - half] * sin_[bse + c - half]);
                        tmp[c] = dK[row_off + c] * cos_[bse + c] + gs;
                    }
                    for (int c2 = 0; c2 < hd; c2++) dK[row_off + c2] = tmp[c2];
                }
            }
        }
    }

    // ─── 2rev: Q/K/V proj bwd (cuBLAS grad_accum) + drin ─────────
    flame_grad_accum_generic_primitive(dQ_id, 0, Bc_id, oRin, Bg_id, WQ, T, d,   d);
    flame_grad_accum_generic_primitive(dK_id, 0, Bc_id, oRin, Bg_id, WK, T, kvd, d);
    flame_grad_accum_generic_primitive(dV_id, 0, Bc_id, oRin, Bg_id, WV, T, kvd, d);
    HexaVal drin_v = hexa_farr_zeros(hexa_int((int64_t)T * d));
    int drin_id = (int)drin_v.i;
    {
        // drin[t·d+c] = Σ_r Wq[r·d+c]·dQ[t·d+r] + Σ_rk (Wk·dK + Wv·dV).
        // Wq-part: flame_proj_batch with W=Wqᵀ. Wk/Wv: same with kvd.
        HexaVal wqt_v = hexa_farr_zeros(hexa_int((int64_t)d * d));
        int wqt_id = (int)wqt_v.i;
        {
            double* Bp = _hx_farr_table[Bp_id].buf;
            double* wqt = _hx_farr_table[wqt_id].buf;
            for (int r = 0; r < d; r++)
                for (int c = 0; c < d; c++) wqt[c*d + r] = Bp[WQ + r*d + c];
        }
        hexa_farr_to_device(wqt_v);
        flame_proj_batch_generic_primitive(wqt_id, 0, dQ_id, 0, drin_id, 0, T, d, d);
        hexa_farr_free(wqt_v);
        // Wk / Wv parts (kvd contraction) — small kvd, CPU accumulate onto drin.
        {
            double* Bp = _hx_farr_table[Bp_id].buf;
            double* dK = _hx_farr_table[dK_id].buf;
            double* dV = _hx_farr_table[dV_id].buf;
            double* drin = _hx_farr_table[drin_id].buf;
            for (int t = 0; t < T; t++)
                for (int c = 0; c < d; c++) {
                    double acc = 0.0;
                    for (int rk = 0; rk < kvd; rk++)
                        acc += Bp[WK + rk*d + c] * dK[t*kvd + rk]
                             + Bp[WV + rk*d + c] * dV[t*kvd + rk];
                    drin[t*d+c] += acc;
                }
        }
    }
    hexa_farr_free(dV_v);
    hexa_farr_free(dK_v);
    hexa_farr_free(dQ_v);

    // ─── 1rev: RMSNorm 1 vjp + dX_out final write ────────────────
    {
        double* Bp = _hx_farr_table[Bp_id].buf;
        double* Bg = _hx_farr_table[Bg_id].buf;
        double* Bc = _hx_farr_table[Bc_id].buf;
        double* drin = _hx_farr_table[drin_id].buf;
        // γ-grad + dxn (in place)
        for (int t = 0; t < T; t++)
            for (int c = 0; c < d; c++)
                Bg[G1 + c] += drin[t*d+c] * Bc[oRm1xn + t*d + c];
        for (int t = 0; t < T; t++)
            for (int c = 0; c < d; c++)
                drin[t*d+c] = drin[t*d+c] * Bp[G1 + c];
    }
    {
        // dx_rms = rmsnorm_bwd(X-slab, dxn)  — forge kernel.
        HexaVal xs_v  = hexa_farr_zeros(hexa_int((int64_t)T * d));
        HexaVal dxn_v = hexa_farr_zeros(hexa_int((int64_t)T * d));
        int xs_id = (int)xs_v.i, dxn_id = (int)dxn_v.i;
        {
            double* X = _hx_farr_table[X_id].buf;
            double* drin = _hx_farr_table[drin_id].buf;
            double* xs = _hx_farr_table[xs_id].buf;
            double* dxn = _hx_farr_table[dxn_id].buf;
            for (int p = 0; p < T * d; p++) { xs[p] = X[p]; dxn[p] = drin[p]; }
        }
        hexa_farr_to_device(xs_v);
        hexa_farr_to_device(dxn_v);
        HexaVal dx_v = hexa_farr_rmsnorm_bwd_rows_gpu(
            hexa_int(xs_id), hexa_int(dxn_id), hexa_int(T), hexa_int(d));
        int dx_id = (int)dx_v.i;
        double* dX_out = _hx_farr_table[dX_out_id].buf;
        double* dh = _hx_farr_table[dh_id].buf;
        if (dx_id >= 0) {
            double* dx = _hx_farr_table[dx_id].buf;
            for (int p = 0; p < T * d; p++)
                dX_out[p] += dh[p] + dx[p];
            hexa_farr_free(dx_v);
        } else {  // CPU fallback for the RMSNorm-1 vjp
            double* X = _hx_farr_table[X_id].buf;
            double* Bc = _hx_farr_table[Bc_id].buf;
            double* drin = _hx_farr_table[drin_id].buf;
            for (int t = 0; t < T; t++) {
                double inv1 = Bc[oR1inv + t];
                double dot1 = 0.0;
                for (int c = 0; c < d; c++)
                    dot1 += drin[t*d+c] * X[t*d+c];
                double inv3 = inv1*inv1*inv1;
                double scl = (inv3 / (double)d) * dot1;
                for (int c = 0; c < d; c++)
                    dX_out[t*d+c] += dh[t*d+c]
                        + inv1 * drin[t*d+c] - scl * X[t*d+c];
            }
        }
        hexa_farr_free(dxn_v);
        hexa_farr_free(xs_v);
    }
    hexa_farr_free(drin_v);
    hexa_farr_free(dh_v);

    // ── PART 1 close: dX_out + Bg back to host ──
    hexa_farr_to_host(hexa_int(dX_out_id));
    hexa_farr_to_host(hexa_int(Bg_id));
}

// ── Dimension-gated dispatch entry point (concat / non-standalone) ──────
// d ≤ FLAME_GPU_RESIDENT_THRESHOLD → CPU loop (byte-eq d=32 path).
// d > threshold → GPU-resident kernel sequence.
// Lives inside the `#ifndef FLAME_BLOCK_BWD_PRIM_STANDALONE` region (the
// build-script strip only removes `#ifdef ..._STANDALONE` blocks).
static inline void flame_block_generic_bwd_primitive(
    int X_id, int Bp_id, int Bc_id,
    int dXout_id, int dX_out_id, int Bg_id,
    int cos_id, int sin_id,
    int T, int d, int nh, int nkv, int h
) {
    if (d > FLAME_GPU_RESIDENT_THRESHOLD) {
        flame_block_generic_bwd_primitive_gpu(X_id, Bp_id, Bc_id, dXout_id,
            dX_out_id, Bg_id, cos_id, sin_id, T, d, nh, nkv, h);
    } else {
        flame_block_generic_bwd_primitive_cpu(X_id, Bp_id, Bc_id, dXout_id,
            dX_out_id, Bg_id, cos_id, sin_id, T, d, nh, nkv, h);
    }
}
#endif  // !FLAME_BLOCK_BWD_PRIM_STANDALONE

#ifdef FLAME_BLOCK_BWD_PRIM_STANDALONE
// Standalone compile-check only — CPU path direct, no GPU primitive linked.
static inline void flame_block_generic_bwd_primitive(
    int X_id, int Bp_id, int Bc_id,
    int dXout_id, int dX_out_id, int Bg_id,
    int cos_id, int sin_id,
    int T, int d, int nh, int nkv, int h
) {
    flame_block_generic_bwd_primitive_cpu(X_id, Bp_id, Bc_id, dXout_id,
        dX_out_id, Bg_id, cos_id, sin_id, T, d, nh, nkv, h);
}
#endif
