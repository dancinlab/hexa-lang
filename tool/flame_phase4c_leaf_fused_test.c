// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4c_leaf_fused_test.c — Phase 4-C-2c byte-eq harness
//
// Validates F-RFC048-FUSED-FWD-BWD-EQ at the C-primitive level:
//   1. Runs `flame_block_..._fwd_primitive` then `..._bwd_primitive`
//      back-to-back (paired baseline) → records Bc, dX_out, Bg.
//   2. Runs `flame_block_..._fused_primitive` on identical inputs →
//      records fresh Bc, dX_out, Bg.
//   3. Compares max|Δ| element-wise. STRICT byte-eq requires max|Δ|==0.
//
// Also performs an N-iter wall micro-benchmark (paired vs fused) for
// F-RFC048-FUSED-WALL-IMPROVED tracking. This is a primitive-level
// micro-bench, NOT the full d=32·3L corpus wall (which requires the
// IPCP/A2 pipeline currently blocked by pre-existing hexat codegen
// bug on `_db_grad_accum_farr` 9-param signature — see PHASE4C
// IMPLEMENTATION_AUDIT.md §1 for the verify_all baseline state).
//
// Build (via tool/flame_phase4c_leaf_fused_build.sh):
//   clang -O2 -DFLAME_BLOCK_BWD_PRIM_STANDALONE \
//     -DFLAME_PRIMS_INLINE \
//     tool/flame_phase4c_leaf_fused_test.c -lm -o build/leaf_fused_test
//
// The harness brings in:
//   - tool/flame_phase4b3_matmul_primitives.c  (Path B 4 matmul + 4 grad_accum)
//   - tool/flame_phase4b3_block_fwd_primitive.c (fwd primitive, ~270 LoC)
//   - tool/flame_phase4b3_block_bwd_primitive.c (bwd primitive, ~360 LoC)
//   - tool/flame_phase4c_block_fused_primitive.c (the unit-under-test)
//
// Falsifier: F-RFC048-FUSED-FWD-BWD-EQ (max|Δ|=0 strict tier).
// ════════════════════════════════════════════════════════════════════════

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>
#include <stddef.h>
#include <time.h>

// ── Minimal _hx_farr_table mock matching self/runtime.c layout ───────
typedef struct {
    int tag;
    union { int64_t i; double f; void* p; };
} HexaVal;

typedef struct {
    double*  buf;
    long     len;
    void*    d_buf;
    int      loc, pinned, dirty_host, dirty_dev;
} HexaFarrEntry;

static HexaFarrEntry* _hx_farr_table = NULL;
static long           _hx_farr_count = 0;
static long           _hx_farr_capacity = 0;

static inline HexaVal hexa_int(int64_t n)  { HexaVal v; v.tag = 1; v.i = n; return v; }
static inline HexaVal hexa_float(double x) { HexaVal v; v.tag = 2; v.f = x; return v; }

static int farr_alloc_id(long n, const double* init_values) {
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

// hexa_call1(farr_zeros, hexa_int(n)) → HexaVal(int id)
// hexa_call1(farr_free, hexa_int_val) → no-op (test leaks fine)
static HexaVal farr_zeros_impl(HexaVal n) {
    int id = farr_alloc_id(n.i, NULL);
    return hexa_int((int64_t)id);
}
static HexaVal farr_free_impl(HexaVal v) {
    (void)v;  // leak — test process exits after run
    return hexa_int(0);
}

// hexa_call1 macro: call function pointer stored in HexaVal.p
#define hexa_call1(f, a) (((HexaVal(*)(HexaVal))((f).p))(a))

// HexaVal-wrapped function pointers matching runtime.c convention
static HexaVal farr_zeros;
static HexaVal farr_free;

static void init_farr_fnptrs(void) {
    farr_zeros.tag = 9; farr_zeros.p = (void*)farr_zeros_impl;
    farr_free.tag  = 9; farr_free.p  = (void*)farr_free_impl;
}

// ── Include primitive bodies (concat'd; not separately compiled) ─────
// The standalone tests use FLAME_BLOCK_PRIM_STANDALONE / FLAME_BLOCK_BWD_
// PRIM_STANDALONE to switch on internal typedefs we already provide here.
// We define a FLAME_PRIMS_INLINE flag to STRIP the internal typedef
// blocks so they don't redefine HexaVal/HexaFarrEntry. Achieve via
// guarding them via #ifndef FLAME_PRIMS_INLINE in this file (we already
// supplied them above) — simplest path: include the matmul primitives
// (no standalone guard there), then include fwd/bwd primitives with
// their FLAME_BLOCK_*_PRIM_STANDALONE OFF (so they use the table above).
//
// Trick: define FLAME_BLOCK_PRIM_STANDALONE and FLAME_BLOCK_BWD_PRIM_
// STANDALONE OFF but skip their typedef section by guarding inclusion
// with FLAME_PRIMS_INLINE.

// We CANNOT use #include because all 4 files would re-define the typedef
// blocks unless we control via -D flags carefully. The build script
// concatenates this file with the 4 primitive sources via a wrapper.

// Forward decls — the build wrapper concat's the primitive bodies BELOW
// this header into one TU.

// Matmul primitives (from tool/flame_phase4b3_matmul_primitives.c)
static inline void flame_proj_inline_matmul(
    const double* A, int M, int K, const double* B, int N, double* C
);
static inline void flame_proj_batch_T16_d32x32_primitive(int W_id, int W_off, int X_id, int X_off, int Y_id, int Y_off);
static inline void flame_proj_batch_T16_d16x32_primitive(int W_id, int W_off, int X_id, int X_off, int Y_id, int Y_off);
static inline void flame_proj_batch_T16_d64x32_primitive(int W_id, int W_off, int X_id, int X_off, int Y_id, int Y_off);
static inline void flame_proj_batch_T16_d32x64_primitive(int W_id, int W_off, int X_id, int X_off, int Y_id, int Y_off);
static inline void flame_grad_accum_T16_d32x32_primitive(int dY_id, int dY_off, int X_id, int X_off, int dW_id, int dW_off);
static inline void flame_grad_accum_T16_d16x32_primitive(int dY_id, int dY_off, int X_id, int X_off, int dW_id, int dW_off);
static inline void flame_grad_accum_T16_d64x32_primitive(int dY_id, int dY_off, int X_id, int X_off, int dW_id, int dW_off);
static inline void flame_grad_accum_T16_d32x64_primitive(int dY_id, int dY_off, int X_id, int X_off, int dW_id, int dW_off);

// Block primitives
static inline void flame_block_T16_d32_nh4_nkv2_h64_fwd_primitive(
    int X_id, int Bp_id, int Bc_id, int cos_id, int sin_id
);
static inline void flame_block_T16_d32_nh4_nkv2_h64_bwd_primitive(
    int X_id, int Bp_id, int Bc_id,
    int dXout_id, int dX_out_id, int Bg_id,
    int cos_id, int sin_id
);
static inline void flame_block_T16_d32_nh4_nkv2_h64_fused_primitive(
    int X_id, int Bp_id, int Bc_id,
    int dXout_id, int dX_out_id, int Bg_id,
    int cos_id, int sin_id
);

// ── Sizes (mirror decoder_block_lib offsets) ─────────────────────────
//   Bp_size = 9216  (g1+Wq+Wk+Wv+Wo+g2+Wg+Wu+Wd at d=32,nh=4,nkv=2,h=64)
//   Bc_size = 8736  (Xout+hstate+rin+rin2+rm1xn+rm2xn+ctx+Q+K+V+P+swA+swB+swS+rm1inv+rm2inv)
//   X_size  = 16*32 = 512
//   cos/sin = 16*8  = 128
//   dXout   = 512   dX_out = 512   Bg = 9216

#define X_SIZE   (16*32)
#define BP_SIZE  9216
#define BC_SIZE  8736
#define CS_SIZE  (16*8)
#define BG_SIZE  9216

static void run_test(int do_wall_bench);

int main(void) {
    init_farr_fnptrs();
    run_test(1);
    return 0;
}

// ── Helpers ──────────────────────────────────────────────────────────
static double max_abs_diff(const double* a, const double* b, long n) {
    double m = 0.0;
    for (long i = 0; i < n; i++) {
        double d = fabs(a[i] - b[i]);
        if (d > m) m = d;
    }
    return m;
}

static void seed_pattern(double* buf, long n, long seed_off) {
    // Deterministic small-magnitude input
    for (long i = 0; i < n; i++) {
        buf[i] = sin(0.01 * (double)(i + seed_off + 1));
    }
}

static void run_test(int do_wall_bench) {
    printf("=== flame Phase 4-C-2c — fused fwd+bwd primitive byte-eq test ===\n");
    printf("  config: T=16, d=32, nh=4, nkv=2, h=64 (d=32·3L block)\n");
    printf("\n");

    // ── Seed deterministic input arrays ────────────────────────────
    double X_init[X_SIZE], Bp_init[BP_SIZE], cos_init[CS_SIZE], sin_init[CS_SIZE];
    double dXout_init[X_SIZE];
    seed_pattern(X_init,    X_SIZE,    1);
    seed_pattern(Bp_init,   BP_SIZE,   2);
    seed_pattern(cos_init,  CS_SIZE,   3);
    seed_pattern(sin_init,  CS_SIZE,   4);
    seed_pattern(dXout_init, X_SIZE,   5);

    // ── PAIRED CALL: fwd then bwd into farrs (a) ──────────────────
    int X_a     = farr_alloc_id(X_SIZE, X_init);
    int Bp_a    = farr_alloc_id(BP_SIZE, Bp_init);
    int Bc_a    = farr_alloc_id(BC_SIZE, NULL);
    int cos_a   = farr_alloc_id(CS_SIZE, cos_init);
    int sin_a   = farr_alloc_id(CS_SIZE, sin_init);
    int dXout_a = farr_alloc_id(X_SIZE, dXout_init);
    int dX_a    = farr_alloc_id(X_SIZE, NULL);
    int Bg_a    = farr_alloc_id(BG_SIZE, NULL);

    flame_block_T16_d32_nh4_nkv2_h64_fwd_primitive(X_a, Bp_a, Bc_a, cos_a, sin_a);
    flame_block_T16_d32_nh4_nkv2_h64_bwd_primitive(X_a, Bp_a, Bc_a, dXout_a, dX_a, Bg_a, cos_a, sin_a);

    // Copy outputs (Bc, dX_out, Bg) since later iters may reuse table
    double Bc_paired[BC_SIZE];
    double dX_paired[X_SIZE];
    double Bg_paired[BG_SIZE];
    memcpy(Bc_paired, _hx_farr_table[Bc_a].buf, BC_SIZE * sizeof(double));
    memcpy(dX_paired, _hx_farr_table[dX_a].buf, X_SIZE  * sizeof(double));
    memcpy(Bg_paired, _hx_farr_table[Bg_a].buf, BG_SIZE * sizeof(double));

    // ── FUSED CALL: fused primitive into farrs (b) ────────────────
    int X_b     = farr_alloc_id(X_SIZE, X_init);
    int Bp_b    = farr_alloc_id(BP_SIZE, Bp_init);
    int Bc_b    = farr_alloc_id(BC_SIZE, NULL);
    int cos_b   = farr_alloc_id(CS_SIZE, cos_init);
    int sin_b   = farr_alloc_id(CS_SIZE, sin_init);
    int dXout_b = farr_alloc_id(X_SIZE, dXout_init);
    int dX_b    = farr_alloc_id(X_SIZE, NULL);
    int Bg_b    = farr_alloc_id(BG_SIZE, NULL);

    flame_block_T16_d32_nh4_nkv2_h64_fused_primitive(
        X_b, Bp_b, Bc_b, dXout_b, dX_b, Bg_b, cos_b, sin_b
    );

    double Bc_fused[BC_SIZE];
    double dX_fused[X_SIZE];
    double Bg_fused[BG_SIZE];
    memcpy(Bc_fused, _hx_farr_table[Bc_b].buf, BC_SIZE * sizeof(double));
    memcpy(dX_fused, _hx_farr_table[dX_b].buf, X_SIZE  * sizeof(double));
    memcpy(Bg_fused, _hx_farr_table[Bg_b].buf, BG_SIZE * sizeof(double));

    // ── Byte-eq diff ──────────────────────────────────────────────
    //
    // Output contract per RFC 048 §"Equivalence":
    //   PRIMARY outputs (gate F-RFC048-FUSED-FWD-BWD-EQ):
    //     - dX_out  : full T·d (block input gradient)
    //     - Bg      : full Bp size (parameter gradients)
    //     - Bc[oXout]   : forward output (residual to next block)
    //     - Bc[oHstate] : intermediate residual (downstream observable)
    //
    //   INTERNAL Bc slots (excluded from byte-eq once extracted):
    //     - oRm1inv/oR2inv (16+16 dbl) — extracted to locals
    //     - oRm1xn/oRm2xn (512+512 dbl) — extracted to locals
    //     - oRin/oRin2 (512+512 dbl) — extracted to locals
    //     - oSwS (1024 dbl) — extracted to locals
    //     - oQ/oK/oV/oP/oCtx/oSwA/oSwB — matmul targets, REMAIN in Bc
    //
    // The full Bc max|Δ| is reported as INFO (drift expected at extracted
    // slots); the PASS gate is on (Bc[oXout]/Bc[oHstate]/dX_out/Bg).

    const int oXout = 0, oHstate = 512;
    const int X_BLOCK = 16 * 32;  // T·d

    double mBc_all  = max_abs_diff(Bc_paired,            Bc_fused,            BC_SIZE);
    double mBc_xout = max_abs_diff(Bc_paired + oXout,    Bc_fused + oXout,    X_BLOCK);
    double mBc_hst  = max_abs_diff(Bc_paired + oHstate,  Bc_fused + oHstate,  X_BLOCK);
    double mdX = max_abs_diff(dX_paired, dX_fused, X_SIZE);
    double mBg = max_abs_diff(Bg_paired, Bg_fused, BG_SIZE);

    printf("  max|Bc_paired   − Bc_fused|   = %.3e   (full Bc, includes extracted slots)\n", mBc_all);
    printf("  max|Bc[oXout]   − Bc_fused|   = %.3e   (block fwd output, must be 0)\n", mBc_xout);
    printf("  max|Bc[oHstate] − Bc_fused|   = %.3e   (residual interm, must be 0)\n", mBc_hst);
    printf("  max|dX_paired   − dX_fused|   = %.3e   (block input gradient)\n", mdX);
    printf("  max|Bg_paired   − Bg_fused|   = %.3e   (parameter gradients)\n", mBg);
    printf("\n");

    int pass = (mBc_xout == 0.0) && (mBc_hst == 0.0) && (mdX == 0.0) && (mBg == 0.0);
    if (!pass) {
        printf("FAIL  F-RFC048-FUSED-FWD-BWD-EQ  fused primitive deviates from paired baseline\n");
        printf("      (Path C revert lesson: revert this extraction, do not chase last-ulp drift)\n");
        exit(1);
    }
    printf("PASS  F-RFC048-FUSED-FWD-BWD-EQ  max|Δ| = 0.0 on (Bc[oXout], Bc[oHstate], dX_out, Bg)\n");

    if (!do_wall_bench) return;

    // ── Wall micro-bench (N iter × paired vs fused) ───────────────
    // Each call re-runs fwd+bwd on the SAME farrs (their state mutates
    // but we don't read it — only timing the compute).
    //
    // Warm-up pass eliminates cold-cache + first-call ICache miss bias.
    // Interleaved runs (paired1 fused1 paired2 fused2 ... → 3 reps)
    // average out frequency scaling drift.
    printf("\n");
    printf("=== Wall micro-bench (paired vs fused, primitive-level) ===\n");
    int iters = 200;

    // Warm-up
    for (int it = 0; it < 20; it++) {
        flame_block_T16_d32_nh4_nkv2_h64_fwd_primitive(X_a, Bp_a, Bc_a, cos_a, sin_a);
        flame_block_T16_d32_nh4_nkv2_h64_bwd_primitive(X_a, Bp_a, Bc_a, dXout_a, dX_a, Bg_a, cos_a, sin_a);
        flame_block_T16_d32_nh4_nkv2_h64_fused_primitive(
            X_b, Bp_b, Bc_b, dXout_b, dX_b, Bg_b, cos_b, sin_b
        );
    }

    double paired_best = 1e9, fused_best = 1e9;
    struct timespec t0, t1;
    for (int rep = 0; rep < 3; rep++) {
        clock_gettime(CLOCK_MONOTONIC, &t0);
        for (int it = 0; it < iters; it++) {
            flame_block_T16_d32_nh4_nkv2_h64_fwd_primitive(X_a, Bp_a, Bc_a, cos_a, sin_a);
            flame_block_T16_d32_nh4_nkv2_h64_bwd_primitive(X_a, Bp_a, Bc_a, dXout_a, dX_a, Bg_a, cos_a, sin_a);
        }
        clock_gettime(CLOCK_MONOTONIC, &t1);
        double s = (t1.tv_sec - t0.tv_sec) + 1e-9 * (t1.tv_nsec - t0.tv_nsec);
        if (s < paired_best) paired_best = s;

        clock_gettime(CLOCK_MONOTONIC, &t0);
        for (int it = 0; it < iters; it++) {
            flame_block_T16_d32_nh4_nkv2_h64_fused_primitive(
                X_b, Bp_b, Bc_b, dXout_b, dX_b, Bg_b, cos_b, sin_b
            );
        }
        clock_gettime(CLOCK_MONOTONIC, &t1);
        s = (t1.tv_sec - t0.tv_sec) + 1e-9 * (t1.tv_nsec - t0.tv_nsec);
        if (s < fused_best) fused_best = s;
    }

    double ratio = paired_best / fused_best;
    printf("  paired wall best (%d iter × 3 reps) = %.4fs  (%.2f µs/iter)\n",
           iters, paired_best, paired_best * 1e6 / iters);
    printf("  fused  wall best (%d iter × 3 reps) = %.4fs  (%.2f µs/iter)\n",
           iters, fused_best, fused_best * 1e6 / iters);
    printf("  ratio (paired/fused) = %.3fx\n", ratio);
    printf("\n");

    if (ratio >= 1.30) {
        printf("PASS  F-RFC048-FUSED-WALL-IMPROVED  %.3fx ≥ 1.30x threshold\n", ratio);
    } else if (ratio >= 1.05) {
        printf("INFO  F-RFC048-FUSED-WALL-IMPROVED  %.3fx (mild improvement, <1.30x threshold)\n", ratio);
    } else {
        printf("INFO  F-RFC048-FUSED-WALL-IMPROVED  %.3fx (no/negative improvement at single-block scope)\n", ratio);
    }
}
