// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4b3_alloc_bench.c — allocator-elim micro-probe
//
// Phase 4-B-3 mechanism #2 (PHASE4B3_EMISSION_DESIGN.md): replacing
// farr_zeros + farr_free per layer with stack-resident scratch should
// yield ~1.3-1.7× wall improvement. This bench measures the floor by
// comparing per-iteration malloc/free against stack-scratch for the
// flame block-fwd scratch buffer pattern.
//
// Build:
//   clang -O2 tool/flame_phase4b3_alloc_bench.c -o build/alloc_bench
//
// Workload per "layer-call":
//   - alloc Bp_l[bp_total(32,4,2,64)] ≈ 8 × (32 + 32·32·3 + 32·32 + 32 + 64·32·2 + 32·64) = ~63 KB
//   - alloc Bc_l[bc_total(16,32,4,2,64)] ≈ 8 × (16·32·6 + 16·32 + 16·32 + 16·64·3 + ...) = ~36 KB
//   - alloc Xc[16·32] = 4 KB
//   - write zeros to all three
//   - free all three
//
// Simulated against:
//   - stack scratch sized appropriately, write zeros (no alloc, no free)
//
// 80 steps × 3 layers × 1 inner = 240 layer-calls per training run.
// ════════════════════════════════════════════════════════════════════════

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

// Dim constants from d=32·3L config.
#define T 16
#define D 32
#define NH 4
#define NKV 2
#define H 64
#define HD (D / NH)   // 8
#define KVD (NKV * HD)  // 16

// Sizes (matches stdlib/flame/decoder_block_lib.hexa bp_total / bc_total):
#define BP_TOTAL (D + D*D + KVD*D + KVD*D + D*D + D + H*D + H*D + D*H)
// = 32 + 1024 + 512 + 512 + 1024 + 32 + 2048 + 2048 + 2048 = 9280 doubles
#define BC_TOTAL (T*D + T*D + T*D + T*D + T*D + T*D + T*D + T*D + T*KVD + T*KVD + NH*T*T + T*H + T*H + T*H + T + T)
// = 16·32·8 + 16·16·2 + 4·16·16 + 16·64·3 + 16·2 = 4096 + 512 + 1024 + 3072 + 32 = 8736
#define XC_TOTAL (T * D)
// = 512

#define LAYER_CALLS (240)  // 80 steps × 3 layers
#define N_REPS 50          // outer reps to amplify cost

static volatile double sink = 0.0;

// Realistic touch — write a runtime-dependent value into every cell
// using a small mixing function. Optimizer cannot DCE because each
// cell's value depends on rep/lc and we return acc to a volatile sink.
//
// Touch cost is intentionally bounded (~constant per buffer size) so
// it does NOT dominate alloc/free cost — we want the ratio to surface.
// We touch every 64th cell (one per cache line) — enough to fault
// pages without saturating fp ops.

static inline double touch_strided(double* p, int n, int seed) {
    double s = 0.0;
    for (int i = 0; i < n; i += 8) {
        double v = (double)(seed + i);
        p[i] = v;
        s += v;
    }
    return s;
}

// Path 1: malloc + memset(0) + touch + free per layer-call
static void run_heap(void) {
    for (int rep = 0; rep < N_REPS; rep++) {
        double acc = 0.0;
        for (int lc = 0; lc < LAYER_CALLS; lc++) {
            double* Bp_l = (double*)malloc(BP_TOTAL * sizeof(double));
            double* Bc_l = (double*)malloc(BC_TOTAL * sizeof(double));
            double* Xc   = (double*)malloc(XC_TOTAL * sizeof(double));
            memset(Bp_l, 0, BP_TOTAL * sizeof(double));
            memset(Bc_l, 0, BC_TOTAL * sizeof(double));
            memset(Xc,   0, XC_TOTAL * sizeof(double));
            acc += touch_strided(Bp_l, BP_TOTAL, rep * 31 + lc);
            acc += touch_strided(Bc_l, BC_TOTAL, rep * 37 + lc);
            acc += touch_strided(Xc,   XC_TOTAL, rep * 41 + lc);
            free(Bp_l);
            free(Bc_l);
            free(Xc);
        }
        sink = acc;
    }
}

// Path 2: stack-resident scratch + zero + touch per layer-call
static void run_stack(void) {
    for (int rep = 0; rep < N_REPS; rep++) {
        double acc = 0.0;
        for (int lc = 0; lc < LAYER_CALLS; lc++) {
            double Bp_l[BP_TOTAL];
            double Bc_l[BC_TOTAL];
            double Xc  [XC_TOTAL];
            memset(Bp_l, 0, BP_TOTAL * sizeof(double));
            memset(Bc_l, 0, BC_TOTAL * sizeof(double));
            memset(Xc,   0, XC_TOTAL * sizeof(double));
            acc += touch_strided(Bp_l, BP_TOTAL, rep * 31 + lc);
            acc += touch_strided(Bc_l, BC_TOTAL, rep * 37 + lc);
            acc += touch_strided(Xc,   XC_TOTAL, rep * 41 + lc);
        }
        sink = acc;
    }
}

static double now_sec(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

int main(void) {
    printf("=== flame Phase 4-B-3 allocator-elim probe ===\n");
    printf("  Bp_l size: %d doubles (%d bytes)\n", BP_TOTAL, BP_TOTAL * (int)sizeof(double));
    printf("  Bc_l size: %d doubles (%d bytes)\n", BC_TOTAL, BC_TOTAL * (int)sizeof(double));
    printf("  Xc   size: %d doubles (%d bytes)\n", XC_TOTAL, XC_TOTAL * (int)sizeof(double));
    printf("  layer-calls per rep: %d\n", LAYER_CALLS);
    printf("  total reps: %d\n", N_REPS);
    printf("\n");

    // Warm both paths once
    run_heap();
    run_stack();

    double sum_heap = 0.0, sum_stack = 0.0;
    for (int run = 1; run <= 5; run++) {
        double t0 = now_sec();
        run_heap();
        double t1 = now_sec();
        run_stack();
        double t2 = now_sec();
        double th = t1 - t0, ts = t2 - t1;
        printf("  run %d: heap=%.4fs  stack=%.4fs  ratio=%.2fx\n",
               run, th, ts, th / ts);
        sum_heap += th;
        sum_stack += ts;
    }
    double avg_heap  = sum_heap / 5.0;
    double avg_stack = sum_stack / 5.0;
    printf("\n");
    printf("  5-run avg heap  : %.4fs\n", avg_heap);
    printf("  5-run avg stack : %.4fs\n", avg_stack);
    double ratio = avg_heap / avg_stack;
    printf("  ratio (heap / stack) = %.2fx\n", ratio);
    printf("\n");

    printf("Hypothesis check (PHASE4B3_EMISSION_DESIGN.md mechanism #2):\n");
    printf("  expected allocator-elim factor: 1.3-1.7x\n");
    if (ratio >= 1.3 && ratio <= 3.0) {
        printf("  PASS  measured %.2fx falls in plausible range\n", ratio);
    } else if (ratio < 1.3) {
        printf("  PARTIAL  measured %.2fx below 1.3x estimate\n", ratio);
        printf("           (allocator overhead smaller than expected; emission gain mostly from boxing/fn-call)\n");
    } else {
        printf("  STRONGER  measured %.2fx ABOVE 1.7x upper bound\n", ratio);
        printf("           (allocator effect larger than estimate)\n");
    }
    return 0;
}
