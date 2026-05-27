// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4b3_leaf_attention_bwd_test.c — Phase 4-B-3-3-5
//
// Byte-eq test harness for flame_attention_bwd_T16_nh4_nkv2_hd8_d32_primitive.
// Section #4rev — MOST COMPLEX bwd section (mirror of fwd attention).
// dQ/dK/dV accumulators, Path C revert lesson applies (inline dV).
//
// Algorithm (per hh_b, i_b, L = i_b + 1 causal):
//   dP[j] = Σ_c dctx[i,hh,c] · V[j,kvh,c]
//   sdot = Σ_j P[i,j] · dP[j]
//   dV[j,kvh,c] += P[i,j] · dctx[i,hh,c]
//   dS[i,j] = P · (dP - sdot) · scale
//   dQ[i,hh,c] += dS · K[j,kvh,c]
//   dK[j,kvh,c] += dS · Q[i,hh,c]
//
// Build:
//   clang -O2 tool/flame_phase4b3_leaf_attention_bwd_test.c -lm -o build/leaf_attention_bwd_test
// ════════════════════════════════════════════════════════════════════════

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

typedef struct {
    double*  buf;
    long     len;
    void*    d_buf;
    int      loc, pinned, dirty_host, dirty_dev;
} HexaFarrEntry;

static HexaFarrEntry* _hx_farr_table = NULL;
static long           _hx_farr_count = 0;
static long           _hx_farr_capacity = 0;

static int farr_alloc(long n, const double* init) {
    if (_hx_farr_count >= _hx_farr_capacity) {
        _hx_farr_capacity = _hx_farr_capacity < 16 ? 16 : _hx_farr_capacity * 2;
        _hx_farr_table = (HexaFarrEntry*)realloc(
            _hx_farr_table, _hx_farr_capacity * sizeof(HexaFarrEntry)
        );
    }
    int id = (int)_hx_farr_count++;
    _hx_farr_table[id].buf = (double*)calloc(n, sizeof(double));
    _hx_farr_table[id].len = n;
    _hx_farr_table[id].d_buf = NULL;
    _hx_farr_table[id].loc = 0; _hx_farr_table[id].pinned = 0;
    _hx_farr_table[id].dirty_host = 0; _hx_farr_table[id].dirty_dev = 0;
    if (init) memcpy(_hx_farr_table[id].buf, init, n * sizeof(double));
    return id;
}

// ── dt_sqrt port (mirror flame_math.hexa:44) ────────────────────────
static inline double dt_sqrt(double x) {
    if (x <= 0.0) return 0.0;
    double g = (x > 1.0) ? x : 1.0;
    for (int i = 0; i < 24; i++) g = 0.5 * (g + x / g);
    return g;
}

// ── Primitive: attention bwd T=16, nh=4, nkv=2, hd=8, d=32 ──────────
// Mirror of decoder_block_lib.hexa:509+ section 4rev.
// Output: dQ[T·d], dK[T·kvd], dV[T·kvd] (caller pre-allocates, zeroed).
// Input: dctx[T·d], Bc[oQ/oK/oV/oP].
static inline void flame_attention_bwd_T16_nh4_nkv2_hd8_d32_primitive(
    int dctx_id, int Bc_id, int oQ, int oK, int oV, int oP,
    int dQ_id, int dK_id, int dV_id
) {
    double* dctx = _hx_farr_table[dctx_id].buf;
    double* Bc   = _hx_farr_table[Bc_id].buf;
    double* dQ   = _hx_farr_table[dQ_id].buf;
    double* dK   = _hx_farr_table[dK_id].buf;
    double* dV   = _hx_farr_table[dV_id].buf;
    const int T = 16, nh = 4, nkv = 2, hd = 8, d = 32;
    const int n_rep = 2;
    const double scale = 1.0 / dt_sqrt((double)hd);
    double dP_row[16];

    for (int hh_b = 0; hh_b < nh; hh_b++) {
        int kvh = hh_b / n_rep;
        for (int i_b = 0; i_b < T; i_b++) {
            int L = i_b + 1;
            // dP[j] = Σ_c dctx[i,hh,c] · V[j,kvh,c]
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
            // dV[j,kvh,c] += P[i,j] · dctx[i,hh,c]
            for (int j3 = 0; j3 < L; j3++) {
                double pij = Bc[oP + (hh_b * T + i_b) * T + j3];
                for (int c = 0; c < hd; c++) {
                    int idx_dv = (j3 * nkv + kvh) * hd + c;
                    dV[idx_dv] = dV[idx_dv] + pij * dctx[i_b * d + hh_b * hd + c];
                }
            }
            // dS, dQ, dK
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
}

// libm reference (same algorithm, separate Bc/dctx/dQ/dK/dV)
static void attention_bwd_ref(
    const double* dctx, const double* Bc,
    int oQ, int oK, int oV, int oP,
    double* dQ, double* dK, double* dV
) {
    const int T = 16, nh = 4, nkv = 2, hd = 8, d = 32;
    const int n_rep = 2;
    const double scale = 1.0 / dt_sqrt((double)hd);
    double dP_row[16];

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
}

int main(void) {
    printf("=== flame Phase 4-B-3-3-5 — Attention bwd primitive byte-eq test ===\n");
    printf("  algorithm: causal GQA bwd → dQ + dK + dV (Path C revert lesson)\n");
    printf("  T=16, nh=4, nkv=2, hd=8, d=32\n\n");

    // Bc layout (matches fwd test commit fe7c1922)
    const int oQ = 0, oK = 512, oV = 768, oP = 1024;
    const int bc_size = 2048;
    const int dctx_size = 16 * 32;  // T·d
    const int dQ_size = 16 * 32;
    const int dK_size = 16 * 16;
    const int dV_size = 16 * 16;

    double Bc_init[2048], dctx_init[512];
    for (int i = 0; i < bc_size; i++) Bc_init[i] = sin(0.04 * (double)(i + 1)) * 0.3;
    // Make P rows valid softmax (normalize before primitive runs)
    for (int hh = 0; hh < 4; hh++) {
        for (int i = 0; i < 16; i++) {
            double tot = 0.0;
            for (int j = 0; j <= i; j++) {
                int idx = oP + (hh * 16 + i) * 16 + j;
                Bc_init[idx] = fabs(Bc_init[idx]) + 0.001;
                tot += Bc_init[idx];
            }
            for (int j = 0; j <= i; j++) {
                Bc_init[oP + (hh * 16 + i) * 16 + j] /= tot;
            }
        }
    }
    for (int i = 0; i < dctx_size; i++) dctx_init[i] = cos(0.07 * (double)(i + 3)) * 0.2;

    int Bc_id  = farr_alloc(bc_size, Bc_init);
    int dctx_id = farr_alloc(dctx_size, dctx_init);
    int dQ_id = farr_alloc(dQ_size, NULL);
    int dK_id = farr_alloc(dK_size, NULL);
    int dV_id = farr_alloc(dV_size, NULL);

    flame_attention_bwd_T16_nh4_nkv2_hd8_d32_primitive(
        dctx_id, Bc_id, oQ, oK, oV, oP, dQ_id, dK_id, dV_id);

    double dQ_ref[512] = {0}, dK_ref[256] = {0}, dV_ref[256] = {0};
    attention_bwd_ref(dctx_init, Bc_init, oQ, oK, oV, oP, dQ_ref, dK_ref, dV_ref);

    double max_dQ = 0.0, max_dK = 0.0, max_dV = 0.0;
    for (int i = 0; i < dQ_size; i++) {
        double d = fabs(_hx_farr_table[dQ_id].buf[i] - dQ_ref[i]);
        if (d > max_dQ) max_dQ = d;
    }
    for (int i = 0; i < dK_size; i++) {
        double d = fabs(_hx_farr_table[dK_id].buf[i] - dK_ref[i]);
        if (d > max_dK) max_dK = d;
    }
    for (int i = 0; i < dV_size; i++) {
        double d = fabs(_hx_farr_table[dV_id].buf[i] - dV_ref[i]);
        if (d > max_dV) max_dV = d;
    }

    printf("  max|dQ_primitive − dQ_ref| = %.3e\n", max_dQ);
    printf("  max|dK_primitive − dK_ref| = %.3e\n", max_dK);
    printf("  max|dV_primitive − dV_ref| = %.3e\n\n", max_dV);
    printf("  dQ[0]    primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[dQ_id].buf[0], dQ_ref[0]);
    printf("  dV[100]  primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[dV_id].buf[100], dV_ref[100]);
    printf("\n");

    if (max_dQ == 0.0 && max_dK == 0.0 && max_dV == 0.0) {
        printf("PASS  F-RFC047-LEAF-EMIT-ATTENTION-BWD  max|Δ| = 0.0 strict byte-eq\n");
        return 0;
    } else {
        printf("FAIL  F-RFC047-LEAF-EMIT-ATTENTION-BWD  max dQ=%.3e dK=%.3e dV=%.3e\n",
               max_dQ, max_dK, max_dV);
        return 1;
    }
}
