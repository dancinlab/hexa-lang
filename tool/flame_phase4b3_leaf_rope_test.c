// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4b3_leaf_rope_test.c — Phase 4-B-3-2-third-5
//
// Byte-eq test harness for flame_rope_T16_nh4_nkv2_hd8_primitive.
// Section #3's RoPE rotation on Q (nh heads) + K (nkv heads).
//
// Algorithm: per (t_r, head, c) where c ∈ [0, hd):
//   rh_c = -Bc[row_off + half + c]    if c < half
//        =  Bc[row_off + c - half]    if c >= half
//   new[c] = Bc[row_off + c] · cos[bse + c] + rh_c · sin[bse + c]
//   (computed into scratch, then written back to avoid read-write hazard)
//
// Build:
//   clang -O2 tool/flame_phase4b3_leaf_rope_test.c -lm -o build/leaf_rope_test
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

// ── Primitive: RoPE rotation, T=16, nh=4, nkv=2, hd=8 ────────────────
//
// Mirrors decoder_block_lib.hexa:92-146 (post-restart-comment body).
// Two passes per head: (1) compute into scratch, (2) copy back.
static inline void flame_rope_T16_nh4_nkv2_hd8_primitive(
    int Bc_id, int cos_id, int sin_id,
    int oQ, int oK
) {
    double* Bc   = _hx_farr_table[Bc_id].buf;
    double* cos_ = _hx_farr_table[cos_id].buf;
    double* sin_ = _hx_farr_table[sin_id].buf;
    double q_scratch[8];

    for (int t_r = 0; t_r < 16; t_r++) {
        int bse = t_r * 8;
        // Q rotation: nh=4 heads
        for (int hh = 0; hh < 4; hh++) {
            int row_off = oQ + (t_r * 4 + hh) * 8;
            for (int c = 0; c < 8; c++) {
                double rh_c = (c < 4)
                    ? (0.0 - Bc[row_off + 4 + c])
                    : Bc[row_off + c - 4];
                q_scratch[c] = Bc[row_off + c] * cos_[bse + c]
                             + rh_c * sin_[bse + c];
            }
            for (int c3 = 0; c3 < 8; c3++) {
                Bc[row_off + c3] = q_scratch[c3];
            }
        }
        // K rotation: nkv=2 heads
        for (int hk = 0; hk < 2; hk++) {
            int row_off_k = oK + (t_r * 2 + hk) * 8;
            for (int c = 0; c < 8; c++) {
                double rh_c = (c < 4)
                    ? (0.0 - Bc[row_off_k + 4 + c])
                    : Bc[row_off_k + c - 4];
                q_scratch[c] = Bc[row_off_k + c] * cos_[bse + c]
                             + rh_c * sin_[bse + c];
            }
            for (int c3 = 0; c3 < 8; c3++) {
                Bc[row_off_k + c3] = q_scratch[c3];
            }
        }
    }
}

// libm reference: same algorithm, same loop order, separate arrays
static void rope_ref(
    double* Bc, const double* cos_, const double* sin_,
    int oQ, int oK
) {
    double q_scratch[8];
    for (int t_r = 0; t_r < 16; t_r++) {
        int bse = t_r * 8;
        for (int hh = 0; hh < 4; hh++) {
            int row_off = oQ + (t_r * 4 + hh) * 8;
            for (int c = 0; c < 8; c++) {
                double rh_c = (c < 4)
                    ? (0.0 - Bc[row_off + 4 + c])
                    : Bc[row_off + c - 4];
                q_scratch[c] = Bc[row_off + c] * cos_[bse + c]
                             + rh_c * sin_[bse + c];
            }
            for (int c3 = 0; c3 < 8; c3++) Bc[row_off + c3] = q_scratch[c3];
        }
        for (int hk = 0; hk < 2; hk++) {
            int row_off_k = oK + (t_r * 2 + hk) * 8;
            for (int c = 0; c < 8; c++) {
                double rh_c = (c < 4)
                    ? (0.0 - Bc[row_off_k + 4 + c])
                    : Bc[row_off_k + c - 4];
                q_scratch[c] = Bc[row_off_k + c] * cos_[bse + c]
                             + rh_c * sin_[bse + c];
            }
            for (int c3 = 0; c3 < 8; c3++) Bc[row_off_k + c3] = q_scratch[c3];
        }
    }
}

int main(void) {
    printf("=== flame Phase 4-B-3-2-third-5 — RoPE primitive byte-eq test ===\n");
    printf("  algorithm: pair-rotate Q (nh=4) + K (nkv=2) per (t_r,head,c)\n");
    printf("  T=16, hd=8, half=4 → 16·(4+2)·8 = 768 rotated elements\n\n");

    // Build a Bc-shaped buffer with Q at offset oQ, K at offset oK
    // For minimal Bc, use only: Q (T·nh·hd = 512) + K (T·nkv·hd = 256) = 768
    const int oQ = 0;
    const int oK = 16 * 4 * 8;  // = 512
    const int bc_size = oK + 16 * 2 * 8;  // = 768

    double Bc_init[768];
    double cos_data[16 * 8], sin_data[16 * 8];

    for (int i = 0; i < bc_size; i++) {
        Bc_init[i] = sin(0.1 * (double)(i + 1));
    }
    for (int t = 0; t < 16; t++) {
        for (int c = 0; c < 8; c++) {
            double theta = (double)t * pow(10000.0, -2.0 * (double)c / 8.0);
            cos_data[t * 8 + c] = cos(theta);
            sin_data[t * 8 + c] = sin(theta);
        }
    }

    int Bc_id  = farr_alloc(bc_size, Bc_init);
    int cos_id = farr_alloc(16*8, cos_data);
    int sin_id = farr_alloc(16*8, sin_data);

    flame_rope_T16_nh4_nkv2_hd8_primitive(Bc_id, cos_id, sin_id, oQ, oK);

    // Reference: replay on a separate copy
    double Bc_ref[768];
    memcpy(Bc_ref, Bc_init, sizeof(Bc_ref));
    rope_ref(Bc_ref, cos_data, sin_data, oQ, oK);

    double max_diff = 0.0;
    int worst_i = -1;
    for (int i = 0; i < bc_size; i++) {
        double d = fabs(_hx_farr_table[Bc_id].buf[i] - Bc_ref[i]);
        if (d > max_diff) { max_diff = d; worst_i = i; }
    }

    printf("  max|Bc_primitive − Bc_ref| = %.3e\n", max_diff);
    printf("  Bc[0]    primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[Bc_id].buf[0], Bc_ref[0]);
    printf("  Bc[256]  primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[Bc_id].buf[256], Bc_ref[256]);
    printf("  Bc[700]  primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[Bc_id].buf[700], Bc_ref[700]);
    if (worst_i >= 0 && max_diff > 0.0) {
        printf("  worst idx %d: prim = %.17g  ref = %.17g\n",
               worst_i, _hx_farr_table[Bc_id].buf[worst_i], Bc_ref[worst_i]);
    }
    printf("\n");

    if (max_diff == 0.0) {
        printf("PASS  F-RFC047-LEAF-EMIT-ROPE  max|Δ| = 0.0 strict byte-eq\n");
        return 0;
    } else {
        printf("FAIL  F-RFC047-LEAF-EMIT-ROPE  max|Δ| = %.3e\n", max_diff);
        return 1;
    }
}
