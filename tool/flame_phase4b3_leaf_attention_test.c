// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4b3_leaf_attention_test.c — Phase 4-B-3-2-third-6
//
// Byte-eq test harness for flame_attention_T16_nh4_nkv2_hd8_d32_primitive.
// Section #4: attention core (causal GQA scaled-dot + softmax + value combine).
// Most complex section per audit; Path C revert lesson applies (strict
// byte-eq via algorithm equivalence — same reduction order).
//
// Build:
//   clang -O2 tool/flame_phase4b3_leaf_attention_test.c -lm -o build/leaf_attention_test
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

// ── dt_sqrt / dt_exp ports (mirror stdlib/flame/flame_math.hexa) ────
static inline double dt_sqrt(double x) {
    if (x <= 0.0) return 0.0;
    double g = (x > 1.0) ? x : 1.0;
    for (int i = 0; i < 24; i++) g = 0.5 * (g + x / g);
    return g;
}

static inline double dt_exp(double x) {
    int r = 0;
    double xr = x;
    while ((xr > 0.0 ? xr : -xr) > 0.25) { xr = xr / 2.0; r = r + 1; }
    double term = 1.0, acc = 1.0;
    for (int k = 1; k < 12; k++) { term = term * xr / (double)k; acc = acc + term; }
    for (int s = 0; s < r; s++) acc = acc * acc;
    return acc;
}

// ── Primitive: attention core for T=16, nh=4, nkv=2, hd=8, d=32 ─────
// Mirror of decoder_block_lib.hexa:147-214 line-by-line.
// Output: Bc[oCtx + i·d + hh·hd + c]
// Side-effect: Bc[oP + (hh·T + i)·T + 0..L] (softmax weights for backward)
static inline void flame_attention_T16_nh4_nkv2_hd8_d32_primitive(
    int Bc_id, int oQ, int oK, int oV, int oP, int oCtx
) {
    double* Bc = _hx_farr_table[Bc_id].buf;
    const int T = 16, nh = 4, nkv = 2, hd = 8, d = 32;
    const int n_rep = nh / nkv;  // = 2
    const double scale = 1.0 / dt_sqrt((double)hd);

    double srow_at[16];  // T-len scratch

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
            // softmax: m_max + dt_exp + normalize → P[(hh_a·T + i_a)·T + 0..L]
            double m_max = srow_at[0];
            for (int jj = 1; jj < L; jj++) {
                if (srow_at[jj] > m_max) m_max = srow_at[jj];
            }
            double tot = 0.0;
            for (int jj2 = 0; jj2 < L; jj2++) {
                double e = dt_exp(srow_at[jj2] - m_max);
                Bc[oP + (hh_a * T + i_a) * T + jj2] = e;
                tot = tot + e;
            }
            for (int jj3 = 0; jj3 < L; jj3++) {
                double cur = Bc[oP + (hh_a * T + i_a) * T + jj3];
                Bc[oP + (hh_a * T + i_a) * T + jj3] = cur / tot;
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

// libm reference: same algorithm, separate Bc copy
static void attention_ref(
    double* Bc, int oQ, int oK, int oV, int oP, int oCtx
) {
    const int T = 16, nh = 4, nkv = 2, hd = 8, d = 32;
    const int n_rep = nh / nkv;
    const double scale = 1.0 / dt_sqrt((double)hd);
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
            for (int jj = 1; jj < L; jj++) if (srow_at[jj] > m_max) m_max = srow_at[jj];
            double tot = 0.0;
            for (int jj2 = 0; jj2 < L; jj2++) {
                double e = dt_exp(srow_at[jj2] - m_max);
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

int main(void) {
    printf("=== flame Phase 4-B-3-2-third-6 — Attention primitive byte-eq test ===\n");
    printf("  algorithm: causal GQA scaled-dot + softmax + value combine\n");
    printf("  T=16, nh=4, nkv=2, hd=8, d=32, n_rep=2\n\n");

    // Bc layout (offsets matching d=32·3L config):
    //   oQ   = 0           (T·nh·hd = 512)
    //   oK   = 512         (T·nkv·hd = 256)
    //   oV   = 768         (T·nkv·hd = 256)
    //   oP   = 1024        (nh·T·T = 1024)
    //   oCtx = 2048        (T·d = 512)
    //   total = 2560
    const int oQ = 0, oK = 512, oV = 768, oP = 1024, oCtx = 2048;
    const int bc_size = 2560;

    double Bc_init[2560];
    for (int i = 0; i < bc_size; i++) {
        Bc_init[i] = sin(0.05 * (double)(i + 1)) * 0.3;
    }

    int Bc_id = farr_alloc(bc_size, Bc_init);
    flame_attention_T16_nh4_nkv2_hd8_d32_primitive(Bc_id, oQ, oK, oV, oP, oCtx);

    // Reference: replay on a copy
    double Bc_ref[2560];
    memcpy(Bc_ref, Bc_init, sizeof(Bc_ref));
    attention_ref(Bc_ref, oQ, oK, oV, oP, oCtx);

    double max_diff = 0.0;
    int worst_i = -1;
    for (int i = 0; i < bc_size; i++) {
        double d = fabs(_hx_farr_table[Bc_id].buf[i] - Bc_ref[i]);
        if (d > max_diff) { max_diff = d; worst_i = i; }
    }

    printf("  max|Bc_primitive − Bc_ref| = %.3e\n", max_diff);
    printf("  ctx[0]    primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[Bc_id].buf[oCtx + 0],   Bc_ref[oCtx + 0]);
    printf("  ctx[256]  primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[Bc_id].buf[oCtx + 256], Bc_ref[oCtx + 256]);
    printf("  P[100]    primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[Bc_id].buf[oP + 100], Bc_ref[oP + 100]);
    if (worst_i >= 0 && max_diff > 0.0) {
        printf("  worst idx %d: prim = %.17g  ref = %.17g\n",
               worst_i, _hx_farr_table[Bc_id].buf[worst_i], Bc_ref[worst_i]);
    }
    printf("\n");

    if (max_diff == 0.0) {
        printf("PASS  F-RFC047-LEAF-EMIT-ATTENTION  max|Δ| = 0.0 strict byte-eq\n");
        return 0;
    } else {
        printf("FAIL  F-RFC047-LEAF-EMIT-ATTENTION  max|Δ| = %.3e\n", max_diff);
        return 1;
    }
}
