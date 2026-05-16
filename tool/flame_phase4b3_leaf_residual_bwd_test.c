// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4b3_leaf_residual_bwd_test.c — Phase 4-B-3-3-1
//
// Byte-eq test harness for flame_residual_bwd_T16_d32_primitive.
// Section #9rev of nn_decoder_block_bwd: dh = dXout (pure copy).
//
// Trivial primitive — pure memcpy over T·d = 16·32 = 512 elements.
// Same algorithm as fwd residual (commit 9e065f89) but copy not add.
//
// Build:
//   clang -O2 tool/flame_phase4b3_leaf_residual_bwd_test.c -lm -o build/leaf_residual_bwd_test
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

// ── Primitive: residual bwd 9rev — dh = dXout (copy) ────────────────
// Algorithm: dh[i] = dXout[i] (sections 9rev of block_bwd; passthrough
// gradient of residual Xout = hstate + sw_o)
static inline void flame_residual_bwd_T16_d32_primitive(
    int dh_id, int dXout_id
) {
    double* dh    = _hx_farr_table[dh_id].buf;
    double* dXout = _hx_farr_table[dXout_id].buf;
    for (int i = 0; i < 16 * 32; i++) {
        dh[i] = dXout[i];
    }
}

// libm reference
static void residual_bwd_ref(const double* dXout, double* dh) {
    for (int i = 0; i < 16 * 32; i++) dh[i] = dXout[i];
}

int main(void) {
    printf("=== flame Phase 4-B-3-3-1 — residual bwd primitive byte-eq test ===\n");
    printf("  algorithm: dh = dXout (sections 9rev of block_bwd, pure passthrough)\n");
    printf("  T·d = 16·32 = 512 elements\n\n");

    double dXout_data[16*32];
    for (int i = 0; i < 16*32; i++) {
        dXout_data[i] = sin(0.03 * (double)(i + 1));
    }

    int dXout_id = farr_alloc(16*32, dXout_data);
    int dh_id = farr_alloc(16*32, NULL);

    flame_residual_bwd_T16_d32_primitive(dh_id, dXout_id);

    double dh_ref[16*32];
    residual_bwd_ref(dXout_data, dh_ref);

    double max_diff = 0.0;
    for (int i = 0; i < 16*32; i++) {
        double d = fabs(_hx_farr_table[dh_id].buf[i] - dh_ref[i]);
        if (d > max_diff) max_diff = d;
    }

    printf("  max|dh_primitive − dh_ref| = %.3e\n\n", max_diff);
    printf("  dh[0]   primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[dh_id].buf[0], dh_ref[0]);
    printf("  dh[256] primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[dh_id].buf[256], dh_ref[256]);
    printf("  dh[511] primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[dh_id].buf[511], dh_ref[511]);
    printf("\n");

    if (max_diff == 0.0) {
        printf("PASS  F-RFC047-LEAF-EMIT-RESIDUAL-BWD  max|Δ| = 0.0 strict byte-eq\n");
        return 0;
    } else {
        printf("FAIL  F-RFC047-LEAF-EMIT-RESIDUAL-BWD  max|Δ| = %.3e\n", max_diff);
        return 1;
    }
}
