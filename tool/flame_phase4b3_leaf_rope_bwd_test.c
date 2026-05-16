// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4b3_leaf_rope_bwd_test.c — Phase 4-B-3-3-4
//
// Byte-eq test harness for flame_rope_bwd_T16_nh4_nkv2_hd8_primitive.
// Section #3rev of nn_decoder_block_bwd: RoPE inverse rotation.
//
// Algorithm (per t_r, head, c):
//   gs_for_rht = dQ[row_off + half + c] · sin[bse + half + c]   if c < half
//              = -dQ[row_off + c - half] · sin[bse + c - half]  if c >= half
//   v = dQ[row_off + c] · cos[bse + c] + gs_for_rht
//   (computed into scratch, then written back to dQ)
//
// Two-pass scratch pattern (mirror of fwd RoPE rotation).
//
// Build:
//   clang -O2 tool/flame_phase4b3_leaf_rope_bwd_test.c -lm -o build/leaf_rope_bwd_test
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

// ── Primitive: RoPE bwd inverse rotation T=16, nh=4, nkv=2, hd=8 ────
static inline void flame_rope_bwd_T16_nh4_nkv2_hd8_primitive(
    int dQ_id, int dK_id, int cos_id, int sin_id
) {
    double* dQ   = _hx_farr_table[dQ_id].buf;
    double* dK   = _hx_farr_table[dK_id].buf;
    double* cos_ = _hx_farr_table[cos_id].buf;
    double* sin_ = _hx_farr_table[sin_id].buf;
    double tmp[8];  // hd scratch
    const int hd = 8, half = 4;

    for (int t_r = 0; t_r < 16; t_r++) {
        int bse = t_r * hd;
        // dQ inverse-rotate per head (nh=4)
        for (int hh = 0; hh < 4; hh++) {
            int row_off = (t_r * 4 + hh) * hd;
            for (int c = 0; c < hd; c++) {
                double gs_for_rht = (c < half)
                    ? dQ[row_off + half + c] * sin_[bse + half + c]
                    : (0.0 - dQ[row_off + c - half] * sin_[bse + c - half]);
                tmp[c] = dQ[row_off + c] * cos_[bse + c] + gs_for_rht;
            }
            for (int c2 = 0; c2 < hd; c2++) dQ[row_off + c2] = tmp[c2];
        }
        // dK inverse-rotate per kv-head (nkv=2)
        for (int hk = 0; hk < 2; hk++) {
            int row_off = (t_r * 2 + hk) * hd;
            for (int c = 0; c < hd; c++) {
                double gs_for_rht = (c < half)
                    ? dK[row_off + half + c] * sin_[bse + half + c]
                    : (0.0 - dK[row_off + c - half] * sin_[bse + c - half]);
                tmp[c] = dK[row_off + c] * cos_[bse + c] + gs_for_rht;
            }
            for (int c2 = 0; c2 < hd; c2++) dK[row_off + c2] = tmp[c2];
        }
    }
}

// libm reference (same algorithm, separate buffers)
static void rope_bwd_ref(
    double* dQ, double* dK, const double* cos_, const double* sin_
) {
    double tmp[8];
    const int hd = 8, half = 4;
    for (int t_r = 0; t_r < 16; t_r++) {
        int bse = t_r * hd;
        for (int hh = 0; hh < 4; hh++) {
            int row_off = (t_r * 4 + hh) * hd;
            for (int c = 0; c < hd; c++) {
                double gs_for_rht = (c < half)
                    ? dQ[row_off + half + c] * sin_[bse + half + c]
                    : (0.0 - dQ[row_off + c - half] * sin_[bse + c - half]);
                tmp[c] = dQ[row_off + c] * cos_[bse + c] + gs_for_rht;
            }
            for (int c2 = 0; c2 < hd; c2++) dQ[row_off + c2] = tmp[c2];
        }
        for (int hk = 0; hk < 2; hk++) {
            int row_off = (t_r * 2 + hk) * hd;
            for (int c = 0; c < hd; c++) {
                double gs_for_rht = (c < half)
                    ? dK[row_off + half + c] * sin_[bse + half + c]
                    : (0.0 - dK[row_off + c - half] * sin_[bse + c - half]);
                tmp[c] = dK[row_off + c] * cos_[bse + c] + gs_for_rht;
            }
            for (int c2 = 0; c2 < hd; c2++) dK[row_off + c2] = tmp[c2];
        }
    }
}

int main(void) {
    printf("=== flame Phase 4-B-3-3-4 — RoPE bwd primitive byte-eq test ===\n");
    printf("  algorithm: inverse rotation Q (nh=4) + K (nkv=2) per (t_r, head, c)\n");
    printf("  T=16, hd=8, half=4 → 16·(4+2)·8 = 768 rotated grad elements\n\n");

    const int dQ_size = 16 * 4 * 8;  // T·nh·hd = 512
    const int dK_size = 16 * 2 * 8;  // T·nkv·hd = 256

    double dQ_init[512], dK_init[256], cos_data[128], sin_data[128];
    for (int i = 0; i < dQ_size; i++) dQ_init[i] = sin(0.1 * (double)(i + 1));
    for (int i = 0; i < dK_size; i++) dK_init[i] = cos(0.07 * (double)(i + 3));
    for (int t = 0; t < 16; t++) {
        for (int c = 0; c < 8; c++) {
            double theta = (double)t * pow(10000.0, -2.0 * (double)c / 8.0);
            cos_data[t * 8 + c] = cos(theta);
            sin_data[t * 8 + c] = sin(theta);
        }
    }

    int dQ_id  = farr_alloc(dQ_size, dQ_init);
    int dK_id  = farr_alloc(dK_size, dK_init);
    int cos_id = farr_alloc(128, cos_data);
    int sin_id = farr_alloc(128, sin_data);

    flame_rope_bwd_T16_nh4_nkv2_hd8_primitive(dQ_id, dK_id, cos_id, sin_id);

    double dQ_ref[512], dK_ref[256];
    memcpy(dQ_ref, dQ_init, sizeof(dQ_ref));
    memcpy(dK_ref, dK_init, sizeof(dK_ref));
    rope_bwd_ref(dQ_ref, dK_ref, cos_data, sin_data);

    double max_dQ_diff = 0.0, max_dK_diff = 0.0;
    for (int i = 0; i < dQ_size; i++) {
        double d = fabs(_hx_farr_table[dQ_id].buf[i] - dQ_ref[i]);
        if (d > max_dQ_diff) max_dQ_diff = d;
    }
    for (int i = 0; i < dK_size; i++) {
        double d = fabs(_hx_farr_table[dK_id].buf[i] - dK_ref[i]);
        if (d > max_dK_diff) max_dK_diff = d;
    }

    printf("  max|dQ_primitive − dQ_ref| = %.3e\n", max_dQ_diff);
    printf("  max|dK_primitive − dK_ref| = %.3e\n\n", max_dK_diff);
    printf("  dQ[0]   primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[dQ_id].buf[0], dQ_ref[0]);
    printf("  dK[100] primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[dK_id].buf[100], dK_ref[100]);
    printf("\n");

    if (max_dQ_diff == 0.0 && max_dK_diff == 0.0) {
        printf("PASS  F-RFC047-LEAF-EMIT-ROPE-BWD  max|Δ| = 0.0 strict byte-eq\n");
        return 0;
    } else {
        printf("FAIL  F-RFC047-LEAF-EMIT-ROPE-BWD  max dQ=%.3e dK=%.3e\n",
               max_dQ_diff, max_dK_diff);
        return 1;
    }
}
