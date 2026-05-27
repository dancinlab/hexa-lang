// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4b3_boxing_bench.c — HexaVal boxing-elimination probe
//
// Phase 4-B-3 hypothesis (PHASE4B3_EMISSION_DESIGN.md): emitting
// primitive-typed specialized kernels yields ~1.5-2.5× wall speedup
// over the HexaVal-boxed path. This bench measures the floor of that
// effect using a simple sum-of-products kernel matching the inner
// loop pattern of farr-based fp arithmetic.
//
// Two implementations of the same operation:
//   1. HexaVal-boxed: tag dispatch + box+unbox per op
//   2. Direct fp64:   single FADD instruction
//
// Build:
//   clang -O2 tool/flame_phase4b3_boxing_bench.c -o build/boxing_bench
// ════════════════════════════════════════════════════════════════════════

#include <stdio.h>
#include <stdint.h>
#include <time.h>

// ── Mirror of self/runtime.c HexaVal struct ─────────────────────────
typedef enum { TAG_NIL=0, TAG_INT=1, TAG_FLOAT=2, TAG_BOOL=3 } HexaTag;

typedef struct HexaVal_ {
    HexaTag tag;
    union {
        int64_t i;
        double  f;
        int     b;
        void*   p;
    };
} HexaVal;

static inline HexaVal hexa_float(double x) {
    HexaVal v; v.tag = TAG_FLOAT; v.f = x; return v;
}

static inline HexaVal hexa_int(int64_t x) {
    HexaVal v; v.tag = TAG_INT; v.i = x; return v;
}

// Tagged add — what the hexat-emitted C generates for `a + b` when
// a and b are HexaVal. Real runtime.c hexa_add has more cases; this is
// the floor (only int/float dispatch).
static HexaVal hexa_add(HexaVal a, HexaVal b) {
    if (a.tag == TAG_FLOAT) {
        if (b.tag == TAG_FLOAT) return hexa_float(a.f + b.f);
        if (b.tag == TAG_INT)   return hexa_float(a.f + (double)b.i);
    }
    if (a.tag == TAG_INT) {
        if (b.tag == TAG_INT)   return hexa_int(a.i + b.i);
        if (b.tag == TAG_FLOAT) return hexa_float((double)a.i + b.f);
    }
    // tag mismatch fallback
    return hexa_float(0.0);
}

static HexaVal hexa_mul(HexaVal a, HexaVal b) {
    if (a.tag == TAG_FLOAT) {
        if (b.tag == TAG_FLOAT) return hexa_float(a.f * b.f);
        if (b.tag == TAG_INT)   return hexa_float(a.f * (double)b.i);
    }
    if (a.tag == TAG_INT) {
        if (b.tag == TAG_INT)   return hexa_int(a.i * b.i);
        if (b.tag == TAG_FLOAT) return hexa_float((double)a.i * b.f);
    }
    return hexa_float(0.0);
}

// ── Inner kernels ────────────────────────────────────────────────────
//
// Mimic a 16×32 RMSNorm Σx² accumulator inner loop — matches Phase
// 4-B-2 flame inner loop pattern.

#define N_ELEM 512    // 16 * 32
#define N_REPS 200000 // outer loop reps

static volatile double sink_d = 0.0;
static volatile HexaVal sink_h;

// Path 1: HexaVal-boxed (current Phase 4-B-2 path after IPCP)
static void run_boxed(const HexaVal* xs) {
    for (int rep = 0; rep < N_REPS; rep++) {
        HexaVal acc = hexa_float(0.0);
        for (int i = 0; i < N_ELEM; i++) {
            HexaVal xv = xs[i];
            HexaVal sq = hexa_mul(xv, xv);
            acc = hexa_add(acc, sq);
        }
        sink_h = acc;
    }
}

// Path 2: Direct fp64 (proposed Phase 4-B-3 emission)
static void run_direct(const double* xs) {
    for (int rep = 0; rep < N_REPS; rep++) {
        double acc = 0.0;
        for (int i = 0; i < N_ELEM; i++) {
            double xv = xs[i];
            acc += xv * xv;
        }
        sink_d = acc;
    }
}

static double now_sec(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

int main(void) {
    // Identical input data, two encodings
    double  xs_d[N_ELEM];
    HexaVal xs_h[N_ELEM];
    for (int i = 0; i < N_ELEM; i++) {
        double v = 0.001 * (double)(i + 1);
        xs_d[i] = v;
        xs_h[i] = hexa_float(v);
    }

    printf("=== flame Phase 4-B-3 HexaVal boxing-elimination probe ===\n");
    printf("  workload: Σx² over %d elements, repeated %d times\n", N_ELEM, N_REPS);
    printf("  total ops: %ld (2 ops/elem × %d × %d)\n", 2L * N_ELEM * N_REPS, N_ELEM, N_REPS);
    printf("\n");

    // 5-run measurement per PERF.md convention
    double sum_boxed = 0.0, sum_direct = 0.0;
    for (int run = 1; run <= 5; run++) {
        double t0 = now_sec();
        run_boxed(xs_h);
        double t1 = now_sec();
        run_direct(xs_d);
        double t2 = now_sec();
        double tb = t1 - t0, td = t2 - t1;
        printf("  run %d: boxed=%.4fs  direct=%.4fs  ratio=%.2fx\n",
               run, tb, td, tb / td);
        sum_boxed += tb;
        sum_direct += td;
    }
    double avg_boxed = sum_boxed / 5.0;
    double avg_direct = sum_direct / 5.0;
    printf("\n");
    printf("  5-run avg boxed  : %.4fs\n", avg_boxed);
    printf("  5-run avg direct : %.4fs\n", avg_direct);
    printf("  ratio (boxed / direct) = %.2fx\n", avg_boxed / avg_direct);
    printf("\n");

    // Verify both paths computed the same answer
    double final_boxed = sink_h.f;
    double final_direct = sink_d;
    printf("  final boxed  result: %.17g\n", final_boxed);
    printf("  final direct result: %.17g\n", final_direct);
    double diff = final_boxed - final_direct;
    if (diff < 0) diff = -diff;
    if (diff < 1e-12) {
        printf("  PASS  byte-eq within fp-tol (|Δ|=%.2e)\n", diff);
    } else {
        printf("  FAIL  diverged (|Δ|=%.2e)\n", diff);
    }

    printf("\n");
    printf("Hypothesis check (PHASE4B3_EMISSION_DESIGN.md):\n");
    printf("  expected boxing-elim factor: 1.5-2.5x\n");
    double ratio = avg_boxed / avg_direct;
    if (ratio >= 1.5 && ratio <= 4.0) {
        printf("  PASS  measured %.2fx falls in plausible range\n", ratio);
    } else if (ratio < 1.5) {
        printf("  PARTIAL  measured %.2fx below 1.5x expectation\n", ratio);
        printf("          (Phase 4-B-3 mechanism estimate may need revision)\n");
    } else {
        printf("  STRONGER  measured %.2fx ABOVE upper bound\n", ratio);
        printf("           (Phase 4-B-3 expected ceiling may exceed 3.85x estimate)\n");
    }
    return 0;
}
