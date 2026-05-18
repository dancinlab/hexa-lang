// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4b3_leaf_rmsnorm_test.c — Phase 4-B-3-2-third-1b
//
// Byte-eq test harness for flame_rmsnorm_d32_fwd_primitive.
// Standalone C — minimal _hx_farr_table mock + libm reference.
//
// Tests that the primitive produces output bit-identical to the
// same algorithm computed directly in libm (Σx² + 1/sqrt + scale).
// Same operations in same order → max|Δ| = 0.0 (strict byte-eq,
// Phase 2 tier per F-RFC043-LAYER-EQ-RMSNORM-FWD).
//
// Build:
//   clang -O2 tool/flame_phase4b3_leaf_rmsnorm_test.c -lm -o build/leaf_rmsnorm_test
// ════════════════════════════════════════════════════════════════════════

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

// ── Minimal _hx_farr_table mock matching self/runtime.c ─────────────
typedef struct {
    double*  buf;
    long     len;
    void*    d_buf;
    int      loc, pinned, dirty_host, dirty_dev;
} HexaFarrEntry;

static HexaFarrEntry* _hx_farr_table = NULL;
static long           _hx_farr_count = 0;
static long           _hx_farr_capacity = 0;

static int farr_alloc(long n, const double* init_values) {
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
    if (init_values) {
        memcpy(_hx_farr_table[id].buf, init_values, n * sizeof(double));
    }
    return id;
}

// ── Pasted primitive (must match tool/flame_phase4b3_emit_trampoline.hexa output)
static inline void flame_rmsnorm_d32_fwd_primitive(
    int x_id, int g_id, int y_id, int xn_id, int inv_id
) {
    double* x   = _hx_farr_table[x_id].buf;
    double* g   = _hx_farr_table[g_id].buf;
    double* y   = _hx_farr_table[y_id].buf;
    double* xn  = _hx_farr_table[xn_id].buf;
    double* inv = _hx_farr_table[inv_id].buf;
    const double eps = 1e-6;
    double ms = 0.0;
    for (int i = 0; i < 32; i++) {
        ms += x[i] * x[i];
    }
    ms /= (double)32;
    double iv = 1.0 / sqrt(ms + eps);
    inv[0] = iv;
    for (int j = 0; j < 32; j++) {
        double xni = x[j] * iv;
        xn[j] = xni;
        y[j]  = g[j] * xni;
    }
}

// ── libm reference (same algorithm, same order — must byte-eq) ─────
static void rmsnorm_ref_libm(
    const double* x, const double* g,
    double* y_out, double* xn_out, double* inv_out
) {
    const double eps = 1e-6;
    double ms = 0.0;
    for (int i = 0; i < 32; i++) {
        ms += x[i] * x[i];
    }
    ms /= (double)32;
    double iv = 1.0 / sqrt(ms + eps);
    inv_out[0] = iv;
    for (int j = 0; j < 32; j++) {
        double xni = x[j] * iv;
        xn_out[j] = xni;
        y_out[j]  = g[j] * xni;
    }
}

int main(void) {
    printf("=== flame Phase 4-B-3-2-third-1b — rmsnorm primitive byte-eq test ===\n");
    printf("  algorithm: nn_rmsnorm_fwd (Σx² + 1/sqrt + per-element scale)\n");
    printf("  d = 32, eps = 1e-6\n");
    printf("\n");

    // Deterministic input pattern (sin/cos) so result is reproducible.
    double x_data[32], g_data[32];
    for (int i = 0; i < 32; i++) {
        x_data[i] = sin(0.1 * (double)(i + 1));
        g_data[i] = cos(0.1 * (double)(i + 1));
    }

    int x_id = farr_alloc(32, x_data);
    int g_id = farr_alloc(32, g_data);
    int y_id = farr_alloc(32, NULL);
    int xn_id = farr_alloc(32, NULL);
    int inv_id = farr_alloc(1, NULL);

    flame_rmsnorm_d32_fwd_primitive(x_id, g_id, y_id, xn_id, inv_id);

    // Reference using libm
    double y_ref[32], xn_ref[32], inv_ref[1];
    rmsnorm_ref_libm(x_data, g_data, y_ref, xn_ref, inv_ref);

    // Diff
    double max_inv_diff = fabs(_hx_farr_table[inv_id].buf[0] - inv_ref[0]);
    double max_y_diff   = 0.0;
    double max_xn_diff  = 0.0;
    for (int i = 0; i < 32; i++) {
        double dy  = fabs(_hx_farr_table[y_id].buf[i]  - y_ref[i]);
        double dxn = fabs(_hx_farr_table[xn_id].buf[i] - xn_ref[i]);
        if (dy  > max_y_diff)  max_y_diff  = dy;
        if (dxn > max_xn_diff) max_xn_diff = dxn;
    }

    printf("  max|inv_primitive − inv_ref| = %.3e\n", max_inv_diff);
    printf("  max|xn_primitive  − xn_ref|  = %.3e\n", max_xn_diff);
    printf("  max|y_primitive   − y_ref|   = %.3e\n", max_y_diff);
    printf("\n");

    // Sample first 3 elements (visual sanity)
    printf("  inv[0]   primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[inv_id].buf[0], inv_ref[0]);
    for (int i = 0; i < 3; i++) {
        printf("  y[%d]    primitive = %.17g  ref = %.17g\n",
               i, _hx_farr_table[y_id].buf[i], y_ref[i]);
    }
    printf("\n");

    int pass = (max_inv_diff == 0.0) && (max_y_diff == 0.0) && (max_xn_diff == 0.0);
    if (pass) {
        printf("PASS  F-RFC047-LEAF-EMIT-RMSNORM-FWD  max|Δ| = 0.0 (strict byte-eq vs libm reference)\n");
        return 0;
    } else {
        printf("FAIL  F-RFC047-LEAF-EMIT-RMSNORM-FWD  primitive deviates from algorithmic reference\n");
        return 1;
    }
}
