// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4b3_leaf_swiglu_test.c — Phase 4-B-3-2-third-4
//
// Byte-eq test harness for flame_silu_hadamard_T16_h64_primitive.
// Section #8's silu + Hadamard loop only (the 3 matmul calls are
// skipped per sections #2+#5 audit, commit e7472b1e).
//
// Algorithm: s[ts·h + k] = silu(a[ts·h + k]) · b[ts·h + k]
//            where silu(x) = x · sigmoid(x) = x / (1 + dt_exp(-x))
// dt_exp is anima d_train_lib's 12-term Taylor + repeated-square.
//
// Build:
//   clang -O2 tool/flame_phase4b3_leaf_swiglu_test.c -lm -o build/leaf_swiglu_test
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

// ── dt_exp port from stdlib/flame/flame_math.hexa:58 ─────────────────
// 12-term Taylor series + repeated-square (anima d_train_lib byte-eq)
static inline double dt_exp(double x) {
    int r = 0;
    double xr = x;
    while ((xr > 0.0 ? xr : -xr) > 0.25) {
        xr = xr / 2.0;
        r = r + 1;
    }
    double term = 1.0;
    double acc = 1.0;
    for (int k = 1; k < 12; k++) {
        term = term * xr / (double)k;
        acc = acc + term;
    }
    // repeated-square r times
    for (int s = 0; s < r; s++) {
        acc = acc * acc;
    }
    return acc;
}

static inline double silu(double x) {
    // silu(x) = x · sigmoid(x) = x / (1 + dt_exp(-x))
    return x / (1.0 + dt_exp(0.0 - x));
}

// ── Primitive: silu + Hadamard over T·h = 16·64 = 1024 elements ─────
static inline void flame_silu_hadamard_T16_h64_primitive(
    int a_id, int b_id, int s_id
) {
    double* a = _hx_farr_table[a_id].buf;
    double* b = _hx_farr_table[b_id].buf;
    double* s = _hx_farr_table[s_id].buf;
    for (int ts = 0; ts < 16; ts++) {
        for (int k = 0; k < 64; k++) {
            int idx = ts * 64 + k;
            double av = a[idx];
            double bv = b[idx];
            s[idx] = silu(av) * bv;
        }
    }
}

// libm-like reference using SAME dt_exp/silu helpers (algorithm-byte-eq)
static void silu_hadamard_ref(
    const double* a, const double* b, double* s
) {
    for (int ts = 0; ts < 16; ts++) {
        for (int k = 0; k < 64; k++) {
            int idx = ts * 64 + k;
            s[idx] = silu(a[idx]) * b[idx];
        }
    }
}

int main(void) {
    printf("=== flame Phase 4-B-3-2-third-4 — SwiGLU silu+Hadamard primitive byte-eq test ===\n");
    printf("  algorithm: s = silu(a) · b ; silu(x) = x / (1 + dt_exp(-x))\n");
    printf("  dt_exp = anima 12-term Taylor + repeated-square\n");
    printf("  T·h = 16·64 = 1024 elements\n\n");

    double a_data[16*64], b_data[16*64];
    for (int i = 0; i < 16*64; i++) {
        // Use range that exercises both small + larger |x| values
        double t = (double)(i + 1) * 0.005;
        a_data[i] = sin(t) * 2.5;       // |a| up to ~2.5
        b_data[i] = cos(t * 0.7) * 1.3;
    }

    int a_id = farr_alloc(16*64, a_data);
    int b_id = farr_alloc(16*64, b_data);
    int s_id = farr_alloc(16*64, NULL);

    flame_silu_hadamard_T16_h64_primitive(a_id, b_id, s_id);

    double s_ref[16*64];
    silu_hadamard_ref(a_data, b_data, s_ref);

    double max_diff = 0.0;
    int worst_i = -1;
    for (int i = 0; i < 16*64; i++) {
        double d = fabs(_hx_farr_table[s_id].buf[i] - s_ref[i]);
        if (d > max_diff) { max_diff = d; worst_i = i; }
    }

    printf("  max|s_primitive − s_ref| = %.3e\n", max_diff);
    if (worst_i >= 0) {
        printf("  worst idx %d: primitive = %.17g  ref = %.17g\n",
               worst_i, _hx_farr_table[s_id].buf[worst_i], s_ref[worst_i]);
    }
    printf("  s[0]    primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[s_id].buf[0], s_ref[0]);
    printf("  s[512]  primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[s_id].buf[512], s_ref[512]);
    printf("  s[1023] primitive = %.17g  ref = %.17g\n",
           _hx_farr_table[s_id].buf[1023], s_ref[1023]);
    printf("\n");

    if (max_diff == 0.0) {
        printf("PASS  F-RFC047-LEAF-EMIT-SWIGLU-HADAMARD  max|Δ| = 0.0 strict byte-eq\n");
        return 0;
    } else {
        printf("FAIL  F-RFC047-LEAF-EMIT-SWIGLU-HADAMARD  max|Δ| = %.3e\n", max_diff);
        return 1;
    }
}
