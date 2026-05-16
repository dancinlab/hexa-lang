// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4b3_leaf_rmsnorm_bwd_test.c — Phase 4-B-3-3-2
//
// Byte-eq test harness for flame_rmsnorm_d32_bwd_primitive.
// Section #7rev + #1rev of nn_decoder_block_bwd: RMSNorm vjp.
//
// Algorithm (from stdlib/flame/nn_lib.hexa:664 nn_rmsnorm_bwd):
//   pass 1: dxn_i = dy_i · g_i ; dg[i] = dy_i · xn_i ; dot += dxn_i · x_i
//           (store dxn_i into dx_out temporarily)
//   pass 2: dx[j] = inv · dxn_j − (inv³/d · dot) · x_j
//
// Build:
//   clang -O2 tool/flame_phase4b3_leaf_rmsnorm_bwd_test.c -lm -o build/leaf_rmsnorm_bwd_test
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

// ── Primitive: RMSNorm bwd vjp for d=32 ─────────────────────────────
// Mirror of nn_rmsnorm_bwd (stdlib/flame/nn_lib.hexa:664) — 2-pass:
//   pass 1: dxn_i = dy_i · g_i ; dg[i] = dy_i · xn_i ; dot += dxn_i · x_i
//   pass 2: dx[j] = inv · dxn_j − (inv³/d · dot) · x_j
static inline void flame_rmsnorm_d32_bwd_primitive(
    int x_id, int g_id, int xn_id, double inv, int dy_id,
    int dx_out_id, int dg_out_id
) {
    double* x      = _hx_farr_table[x_id].buf;
    double* g      = _hx_farr_table[g_id].buf;
    double* xn     = _hx_farr_table[xn_id].buf;
    double* dy     = _hx_farr_table[dy_id].buf;
    double* dx_out = _hx_farr_table[dx_out_id].buf;
    double* dg_out = _hx_farr_table[dg_out_id].buf;

    // pass 1
    double dot = 0.0;
    for (int i = 0; i < 32; i++) {
        double dxn_i = dy[i] * g[i];
        dg_out[i] = dy[i] * xn[i];
        dot = dot + dxn_i * x[i];
        dx_out[i] = dxn_i;  // stash
    }
    // pass 2
    double inv3 = inv * inv * inv;
    double scale = (inv3 / 32.0) * dot;
    for (int j = 0; j < 32; j++) {
        double dxn_j = dx_out[j];
        dx_out[j] = inv * dxn_j - scale * x[j];
    }
}

// libm reference (same algorithm)
static void rmsnorm_bwd_ref(
    const double* x, const double* g, const double* xn, double inv,
    const double* dy, double* dx_out, double* dg_out
) {
    double dot = 0.0;
    for (int i = 0; i < 32; i++) {
        double dxn_i = dy[i] * g[i];
        dg_out[i] = dy[i] * xn[i];
        dot = dot + dxn_i * x[i];
        dx_out[i] = dxn_i;
    }
    double inv3 = inv * inv * inv;
    double scale = (inv3 / 32.0) * dot;
    for (int j = 0; j < 32; j++) {
        double dxn_j = dx_out[j];
        dx_out[j] = inv * dxn_j - scale * x[j];
    }
}

int main(void) {
    printf("=== flame Phase 4-B-3-3-2 — RMSNorm bwd primitive byte-eq test ===\n");
    printf("  algorithm: nn_rmsnorm_bwd vjp (2-pass: dxn + dg + dot ; dx via scale)\n");
    printf("  d = 32\n\n");

    double x_data[32], g_data[32], xn_data[32], dy_data[32];
    for (int i = 0; i < 32; i++) {
        x_data[i]  = sin(0.1 * (double)(i + 1));
        g_data[i]  = cos(0.1 * (double)(i + 1));
        xn_data[i] = x_data[i] * 1.4271461477876914;  // x · inv (from fwd test)
        dy_data[i] = sin(0.05 * (double)(i + 7)) * 0.5;
    }
    double inv = 1.4271461477876914;

    int x_id  = farr_alloc(32, x_data);
    int g_id  = farr_alloc(32, g_data);
    int xn_id = farr_alloc(32, xn_data);
    int dy_id = farr_alloc(32, dy_data);
    int dx_id = farr_alloc(32, NULL);
    int dg_id = farr_alloc(32, NULL);

    flame_rmsnorm_d32_bwd_primitive(x_id, g_id, xn_id, inv, dy_id, dx_id, dg_id);

    double dx_ref[32], dg_ref[32];
    rmsnorm_bwd_ref(x_data, g_data, xn_data, inv, dy_data, dx_ref, dg_ref);

    double max_dx_diff = 0.0, max_dg_diff = 0.0;
    for (int i = 0; i < 32; i++) {
        double ddx = fabs(_hx_farr_table[dx_id].buf[i] - dx_ref[i]);
        double ddg = fabs(_hx_farr_table[dg_id].buf[i] - dg_ref[i]);
        if (ddx > max_dx_diff) max_dx_diff = ddx;
        if (ddg > max_dg_diff) max_dg_diff = ddg;
    }

    printf("  max|dx_primitive − dx_ref| = %.3e\n", max_dx_diff);
    printf("  max|dg_primitive − dg_ref| = %.3e\n\n", max_dg_diff);
    printf("  dx[0]  primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[dx_id].buf[0], dx_ref[0]);
    printf("  dg[0]  primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[dg_id].buf[0], dg_ref[0]);
    printf("  dx[31] primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[dx_id].buf[31], dx_ref[31]);
    printf("\n");

    if (max_dx_diff == 0.0 && max_dg_diff == 0.0) {
        printf("PASS  F-RFC047-LEAF-EMIT-RMSNORM-BWD  max|Δ| = 0.0 strict byte-eq\n");
        return 0;
    } else {
        printf("FAIL  F-RFC047-LEAF-EMIT-RMSNORM-BWD  max dx=%.3e dg=%.3e\n",
               max_dx_diff, max_dg_diff);
        return 1;
    }
}
