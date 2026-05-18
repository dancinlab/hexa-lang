// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4b3_leaf_residual_test.c — Phase 4-B-3-2-third-2
//
// Byte-eq test harness for flame_residual_T16_d32_primitive.
// Section #6 + #9 (residuals: hstate=X+attn_out, Xout=hstate+sw_o).
//
// Algorithm: elementwise `out[i] = a[i] + b[i]` over T·d = 16·32 = 512 elements.
// No reduction, no transcendental — should be the simplest byte-eq.
//
// Build:
//   clang -O2 tool/flame_phase4b3_leaf_residual_test.c -lm -o build/leaf_residual_test
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
    _hx_farr_table[id].loc = 0;
    _hx_farr_table[id].pinned = 0;
    _hx_farr_table[id].dirty_host = 0;
    _hx_farr_table[id].dirty_dev = 0;
    if (init) memcpy(_hx_farr_table[id].buf, init, n * sizeof(double));
    return id;
}

// ── Primitive residual for T·d = 16·32 = 512 elements ───────────────
// Algorithm: out[i] = a[i] + b[i] (elementwise add).
// Block_fwd section #6: hstate[i] = X[i] + attn_out[i]
// Block_fwd section #9: Xout[i]   = hstate[i] + sw_o[i]
// Same algorithm both sections — one primitive serves both.
static inline void flame_residual_T16_d32_primitive(
    int a_id, int b_id, int out_id
) {
    double* a   = _hx_farr_table[a_id].buf;
    double* b   = _hx_farr_table[b_id].buf;
    double* out = _hx_farr_table[out_id].buf;
    for (int i = 0; i < 16 * 32; i++) {
        out[i] = a[i] + b[i];
    }
}

// libm reference (literal same algorithm)
static void residual_ref(const double* a, const double* b, double* out) {
    for (int i = 0; i < 16 * 32; i++) {
        out[i] = a[i] + b[i];
    }
}

int main(void) {
    printf("=== flame Phase 4-B-3-2-third-2 — residual primitive byte-eq test ===\n");
    printf("  algorithm: elementwise add (sections #6 + #9 of block_fwd)\n");
    printf("  T·d = 16·32 = 512 elements\n\n");

    double a_data[16*32], b_data[16*32];
    for (int i = 0; i < 16*32; i++) {
        a_data[i] = sin(0.01 * (double)(i + 1));
        b_data[i] = cos(0.02 * (double)(i + 1));
    }

    int a_id   = farr_alloc(16*32, a_data);
    int b_id   = farr_alloc(16*32, b_data);
    int out_id = farr_alloc(16*32, NULL);

    flame_residual_T16_d32_primitive(a_id, b_id, out_id);

    double out_ref[16*32];
    residual_ref(a_data, b_data, out_ref);

    double max_diff = 0.0;
    for (int i = 0; i < 16*32; i++) {
        double d = fabs(_hx_farr_table[out_id].buf[i] - out_ref[i]);
        if (d > max_diff) max_diff = d;
    }

    printf("  max|out_primitive − out_ref| = %.3e\n\n", max_diff);
    printf("  out[0]   primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[out_id].buf[0], out_ref[0]);
    printf("  out[256] primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[out_id].buf[256], out_ref[256]);
    printf("  out[511] primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[out_id].buf[511], out_ref[511]);
    printf("\n");

    if (max_diff == 0.0) {
        printf("PASS  F-RFC047-LEAF-EMIT-RESIDUAL  max|Δ| = 0.0 strict byte-eq vs libm reference\n");
        return 0;
    } else {
        printf("FAIL  F-RFC047-LEAF-EMIT-RESIDUAL  max|Δ| = %.3e\n", max_diff);
        return 1;
    }
}
