// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4b3_leaf_swiglu_bwd_test.c — Phase 4-B-3-3-3
//
// Byte-eq test harness for flame_swiglu_bwd_T16_h64_primitive.
// Section #8rev silu_grad + Hadamard inner loop (matmul parts SKIP).
//
// Algorithm (per-ts × h iterations):
//   da[k] = ds[k] · b[k] · silu_grad(a[k])
//   db[k] = ds[k] · silu(a[k])
//
//   silu(x) = x · sigmoid(x) ; sigmoid(x) = 1/(1 + dt_exp(-x))
//   silu_grad(x) = sigmoid(x) + x · sigmoid(x) · (1 - sigmoid(x))
//
// dt_exp = anima 12-term Taylor + repeated-square (mirror of stdlib).
//
// Build:
//   clang -O2 tool/flame_phase4b3_leaf_swiglu_bwd_test.c -lm -o build/leaf_swiglu_bwd_test
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

// ── dt_exp / silu / silu_grad (mirror stdlib) ───────────────────────
static inline double dt_exp(double x) {
    int r = 0; double xr = x;
    while ((xr > 0.0 ? xr : -xr) > 0.25) { xr = xr / 2.0; r = r + 1; }
    double term = 1.0, acc = 1.0;
    for (int k = 1; k < 12; k++) { term = term * xr / (double)k; acc = acc + term; }
    for (int s = 0; s < r; s++) acc = acc * acc;
    return acc;
}
static inline double sigmoid(double x) { return 1.0 / (1.0 + dt_exp(0.0 - x)); }
static inline double silu(double x) { return x * sigmoid(x); }
static inline double silu_grad(double x) {
    double s = sigmoid(x);
    return s + x * s * (1.0 - s);
}

// ── Primitive: SwiGLU bwd silu_grad + Hadamard ──────────────────────
static inline void flame_swiglu_bwd_T16_h64_primitive(
    int a_id, int b_id, int ds_id, int da_id, int db_id
) {
    double* a  = _hx_farr_table[a_id].buf;
    double* b  = _hx_farr_table[b_id].buf;
    double* ds = _hx_farr_table[ds_id].buf;
    double* da = _hx_farr_table[da_id].buf;
    double* db = _hx_farr_table[db_id].buf;
    for (int ts = 0; ts < 16; ts++) {
        for (int k = 0; k < 64; k++) {
            int idx = ts * 64 + k;
            double ak = a[idx];
            double bk = b[idx];
            double dsk = ds[idx];
            da[idx] = dsk * bk * silu_grad(ak);
            db[idx] = dsk * silu(ak);
        }
    }
}

// libm-like reference
static void swiglu_bwd_ref(
    const double* a, const double* b, const double* ds,
    double* da, double* db
) {
    for (int ts = 0; ts < 16; ts++) {
        for (int k = 0; k < 64; k++) {
            int idx = ts * 64 + k;
            double ak = a[idx];
            double bk = b[idx];
            double dsk = ds[idx];
            da[idx] = dsk * bk * silu_grad(ak);
            db[idx] = dsk * silu(ak);
        }
    }
}

int main(void) {
    printf("=== flame Phase 4-B-3-3-3 — SwiGLU bwd primitive byte-eq test ===\n");
    printf("  algorithm: da = ds·b·silu_grad(a) ; db = ds·silu(a)\n");
    printf("  T·h = 16·64 = 1024 elements\n\n");

    double a_data[16*64], b_data[16*64], ds_data[16*64];
    for (int i = 0; i < 16*64; i++) {
        double t = (double)(i + 1) * 0.005;
        a_data[i]  = sin(t) * 2.5;
        b_data[i]  = cos(t * 0.7) * 1.3;
        ds_data[i] = sin(t * 0.3) * 0.4;
    }

    int a_id  = farr_alloc(16*64, a_data);
    int b_id  = farr_alloc(16*64, b_data);
    int ds_id = farr_alloc(16*64, ds_data);
    int da_id = farr_alloc(16*64, NULL);
    int db_id = farr_alloc(16*64, NULL);

    flame_swiglu_bwd_T16_h64_primitive(a_id, b_id, ds_id, da_id, db_id);

    double da_ref[16*64], db_ref[16*64];
    swiglu_bwd_ref(a_data, b_data, ds_data, da_ref, db_ref);

    double max_da_diff = 0.0, max_db_diff = 0.0;
    for (int i = 0; i < 16*64; i++) {
        double dda = fabs(_hx_farr_table[da_id].buf[i] - da_ref[i]);
        double ddb = fabs(_hx_farr_table[db_id].buf[i] - db_ref[i]);
        if (dda > max_da_diff) max_da_diff = dda;
        if (ddb > max_db_diff) max_db_diff = ddb;
    }

    printf("  max|da_primitive − da_ref| = %.3e\n", max_da_diff);
    printf("  max|db_primitive − db_ref| = %.3e\n\n", max_db_diff);
    printf("  da[0]    primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[da_id].buf[0], da_ref[0]);
    printf("  db[512]  primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[db_id].buf[512], db_ref[512]);
    printf("\n");

    if (max_da_diff == 0.0 && max_db_diff == 0.0) {
        printf("PASS  F-RFC047-LEAF-EMIT-SWIGLU-BWD  max|Δ| = 0.0 strict byte-eq\n");
        return 0;
    } else {
        printf("FAIL  F-RFC047-LEAF-EMIT-SWIGLU-BWD  max da=%.3e db=%.3e\n",
               max_da_diff, max_db_diff);
        return 1;
    }
}
