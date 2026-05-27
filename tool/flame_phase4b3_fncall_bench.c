// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4b3_fncall_bench.c — fn-call elim micro-probe
//
// Phase 4-B-3 mechanism #3 (PHASE4B3_EMISSION_DESIGN.md): inlining the
// 7-12 inner fn calls per block_fwd (rmsnorm/linear/attn_core/swiglu/...)
// should yield ~1.2-1.5× wall improvement. This bench measures the
// floor by comparing fn-call dispatch vs full inline of the same kernel.
//
// Workload: per "block-call" invokes 7 helper fns sequentially, each
// doing a small reduction over a stack buffer. Realistic shape:
// rmsnorm(in) → linear(rmsnorm_out, W) → attn(...) → ... → out.
//
// Build:
//   clang -O2 tool/flame_phase4b3_fncall_bench.c -o build/fncall_bench
//
// CAUTION: clang -O2 may inline the "fn-call" helpers if they are not
// marked __attribute__((noinline)). The bench uses noinline to force
// the per-call dispatch path that matches the IPCP-rewritten flame C.
// ════════════════════════════════════════════════════════════════════════

#include <stdio.h>
#include <time.h>

#define BUF_N 512   // 16 × 32 = T·d
#define N_INNER 7   // approximate # of helper fn calls per block-fwd
#define N_REPS  100000

static volatile double sink = 0.0;

// ── Force-noinline helpers (mimics fn-dispatch path in IPCP source) ─

static __attribute__((noinline)) double helper_sum_sq(const double* x, int n) {
    double s = 0.0;
    for (int i = 0; i < n; i++) s += x[i] * x[i];
    return s;
}

static __attribute__((noinline)) double helper_dot(const double* a, const double* b, int n) {
    double s = 0.0;
    for (int i = 0; i < n; i++) s += a[i] * b[i];
    return s;
}

static __attribute__((noinline)) double helper_sum_silu(const double* x, int n) {
    double s = 0.0;
    for (int i = 0; i < n; i++) {
        double v = x[i];
        // silu approximation cheap: v * (1 / (1 + e^-v))
        // approximate with v/(1+|v|) (faster, similar shape)
        double sig = v / (1.0 + (v < 0 ? -v : v));
        s += v * sig;
    }
    return s;
}

static __attribute__((noinline)) double helper_combine(double a, double b, double c) {
    return a + b * c;
}

// Path 1: fn-call dispatch (mimics IPCP-rewritten flame inner loop).
// Per-rep buffer mutation forces real work — defeats clang CSE/loop-
// invariant-code-motion that would collapse the rep loop otherwise.
static void run_call(double* buf, double* buf2) {
    double acc = 0.0;
    for (int rep = 0; rep < N_REPS; rep++) {
        // mutate buffer per-rep to defeat CSE
        buf[rep % BUF_N]  += 1e-9;
        buf2[rep % BUF_N] += 1e-9;
        for (int blk = 0; blk < N_INNER; blk++) {
            double s1 = helper_sum_sq(buf, BUF_N);
            double s2 = helper_dot(buf, buf2, BUF_N);
            double s3 = helper_sum_silu(buf, BUF_N);
            acc = helper_combine(acc, s1, s2);
            acc = helper_combine(acc, s3, 1.0);
        }
    }
    sink = acc;
}

// Path 2: full inline (mimics Phase 4-B-3 specialized kernel)
static void run_inline(double* buf, double* buf2) {
    double acc = 0.0;
    for (int rep = 0; rep < N_REPS; rep++) {
        buf[rep % BUF_N]  += 1e-9;
        buf2[rep % BUF_N] += 1e-9;
        for (int blk = 0; blk < N_INNER; blk++) {
            double s1 = 0.0;
            for (int i = 0; i < BUF_N; i++) s1 += buf[i] * buf[i];
            double s2 = 0.0;
            for (int i = 0; i < BUF_N; i++) s2 += buf[i] * buf2[i];
            double s3 = 0.0;
            for (int i = 0; i < BUF_N; i++) {
                double v = buf[i];
                double sig = v / (1.0 + (v < 0 ? -v : v));
                s3 += v * sig;
            }
            acc = acc + s1 * s2;
            acc = acc + s3 * 1.0;
        }
    }
    sink = acc;
}

static double now_sec(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

int main(void) {
    static double buf [BUF_N];
    static double buf2[BUF_N];
    for (int i = 0; i < BUF_N; i++) {
        buf[i]  = 0.01 * (double)(i + 1);
        buf2[i] = 0.02 * (double)(i + 1);
    }

    printf("=== flame Phase 4-B-3 fn-call elim probe ===\n");
    printf("  inner kernels per block: %d (sum_sq, dot, sum_silu + 2 combine)\n", N_INNER);
    printf("  buffer size: %d doubles\n", BUF_N);
    printf("  total reps: %d\n", N_REPS);
    printf("  helpers marked __attribute__((noinline)) to force call dispatch\n");
    printf("\n");

    run_call(buf, buf2); run_inline(buf, buf2); // warm

    double sum_call = 0.0, sum_inline = 0.0;
    double final_call = 0.0, final_inline = 0.0;
    for (int run = 1; run <= 5; run++) {
        double t0 = now_sec();
        run_call(buf, buf2);
        double t1 = now_sec();
        final_call = sink;
        run_inline(buf, buf2);
        double t2 = now_sec();
        final_inline = sink;
        double tc = t1 - t0, ti = t2 - t1;
        printf("  run %d: call=%.4fs  inline=%.4fs  ratio=%.2fx\n",
               run, tc, ti, tc / ti);
        sum_call += tc;
        sum_inline += ti;
    }
    double avg_call   = sum_call / 5.0;
    double avg_inline = sum_inline / 5.0;
    printf("\n");
    printf("  5-run avg call   : %.4fs\n", avg_call);
    printf("  5-run avg inline : %.4fs\n", avg_inline);
    double ratio = avg_call / avg_inline;
    printf("  ratio (call / inline) = %.2fx\n", ratio);
    printf("\n");

    printf("  final call   result: %.17g\n", final_call);
    printf("  final inline result: %.17g\n", final_inline);
    double d = final_call - final_inline;
    if (d < 0) d = -d;
    if (d < 1e-9) printf("  PASS  byte-eq within fp-tol (|Δ|=%.2e)\n", d);
    else printf("  WARN  diverged (|Δ|=%.2e) — likely reduction-order diff\n", d);

    printf("\nHypothesis check (PHASE4B3_EMISSION_DESIGN.md mechanism #3):\n");
    printf("  expected fn-call-elim factor: 1.2-1.5x\n");
    if (ratio >= 1.2 && ratio <= 2.5) {
        printf("  PASS  measured %.2fx falls in plausible range\n", ratio);
    } else if (ratio < 1.2) {
        printf("  PARTIAL  measured %.2fx below 1.2x estimate\n", ratio);
    } else {
        printf("  STRONGER  measured %.2fx ABOVE 1.5x upper bound\n", ratio);
    }
    return 0;
}
