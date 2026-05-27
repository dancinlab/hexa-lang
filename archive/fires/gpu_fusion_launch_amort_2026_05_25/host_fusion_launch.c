/* F-FUSION-LAUNCH-AMORT -- launch-overhead amortization host harness.
 *
 * Fires two PTX modules computing the SAME 5-op elementwise chain
 *   y = residual + scale * GeLU(a*x + b)
 * over an n-element f32 tensor:
 *
 *   (A) fused_chain.ptx     -- 1 kernel launch, t1..t4 stay in registers
 *   (B) baseline_chain.ptx  -- 5 kernel launches (k1_mul, k2_add, k3_gelu,
 *                              k4_mul_scale, k5_add_resid), each round-tripping
 *                              the tensor through HBM with a sync between
 *                              (eager-stack / per-op-library semantics).
 *
 * Outputs, per shape n:
 *   - launch count        : fused=1   baseline=5
 *   - HBM read/write count : fused = 2 read + 1 write
 *                            baseline = 6 read + 5 write (k5 reads 2 buffers)
 *   - numeric correctness  : fused vs f64 CPU reference (tol gate)
 *   - timed wall (median of REPS) for both, fused speedup, >=30% gate
 *
 * NOTE: the TIMED portion is the DEFERRED-to-serial silicon confirmation
 * (ubu-2 is shared; parallel timed fires contend). The $0 oracle finding
 * (launch count + HBM traffic + the closed-form crossover projection) is
 * computed deterministically in the companion oracle.hexa and does NOT need
 * this binary to run. This .c is the harness for the serial follow-up.
 *
 * Build:  nvcc -O2 -o host_fusion_launch host_fusion_launch.c -lcuda -lm
 * Run:    ./host_fusion_launch fused_chain.ptx baseline_chain.ptx [n] [reps]
 */
#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

#define CHECK(call) do { CUresult e = (call); \
    if (e != CUDA_SUCCESS) { const char *s = NULL; cuGetErrorString(e, &s); \
        fprintf(stderr, "CUDA error %d at %s:%d: %s\n", e, __FILE__, __LINE__, s ? s : "?"); \
        return 1; }} while (0)

static char *slurp(const char *path) {
    FILE *fp = fopen(path, "rb");
    if (!fp) { perror(path); exit(1); }
    fseek(fp, 0, SEEK_END); long n = ftell(fp); fseek(fp, 0, SEEK_SET);
    char *buf = (char *)malloc(n + 1);
    if (fread(buf, 1, n, fp) != (size_t)n) { perror("read"); exit(1); }
    buf[n] = 0; fclose(fp);
    return buf;
}

/* tanh-approx GeLU in f64 (CPU reference for the SAME chain) */
static double gelu_ref(double u) {
    const double k0 = 0.7978845608028654; /* sqrt(2/pi) */
    const double k1 = 0.044715;
    double inner = u + k1 * u * u * u;
    return 0.5 * u * (1.0 + tanh(k0 * inner));
}

static int cmp_double(const void *a, const void *b) {
    double x = *(const double *)a, y = *(const double *)b;
    return (x < y) ? -1 : (x > y) ? 1 : 0;
}

int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr, "usage: %s fused.ptx baseline.ptx [n] [reps]\n", argv[0]);
        return 2;
    }
    const char *fused_ptx_path    = argv[1];
    const char *baseline_ptx_path = argv[2];
    int n    = (argc > 3) ? atoi(argv[3]) : 1024;
    int reps = (argc > 4) ? atoi(argv[4]) : 200;
    const int warmup = 20;

    const float a = 1.3f, b = -0.5f, s = 2.0f; /* chain scalars */

    char *fused_ptx    = slurp(fused_ptx_path);
    char *baseline_ptx = slurp(baseline_ptx_path);

    CHECK(cuInit(0));
    CUdevice dev;  CHECK(cuDeviceGet(&dev, 0));
    CUcontext ctx; CHECK(cuCtxCreate(&ctx, 0, dev));

    CUmodule mf, mb;
    CUjit_option jit_opts[1] = { CU_JIT_TARGET_FROM_CUCONTEXT };
    void *jit_vals[1] = { (void *)0 };
    CHECK(cuModuleLoadDataEx(&mf, fused_ptx,    1, jit_opts, jit_vals));
    CHECK(cuModuleLoadDataEx(&mb, baseline_ptx, 1, jit_opts, jit_vals));

    CUfunction kf, k1, k2, k3, k4, k5;
    CHECK(cuModuleGetFunction(&kf, mf, "fused_chain"));
    CHECK(cuModuleGetFunction(&k1, mb, "k1_mul"));
    CHECK(cuModuleGetFunction(&k2, mb, "k2_add"));
    CHECK(cuModuleGetFunction(&k3, mb, "k3_gelu"));
    CHECK(cuModuleGetFunction(&k4, mb, "k4_mul_scale"));
    CHECK(cuModuleGetFunction(&k5, mb, "k5_add_resid"));

    size_t bytes = (size_t)n * sizeof(float);
    float *hx = (float *)malloc(bytes);
    float *hr = (float *)malloc(bytes);
    float *hy = (float *)malloc(bytes);
    double *ref = (double *)malloc((size_t)n * sizeof(double));

    /* LCG-deterministic inputs */
    uint32_t st = 0x1234567u;
    for (int i = 0; i < n; ++i) {
        st = st * 1664525u + 1013904223u;
        hx[i] = ((float)(st >> 8) / (float)(1u << 24)) * 4.0f - 2.0f; /* [-2,2) */
        st = st * 1664525u + 1013904223u;
        hr[i] = ((float)(st >> 8) / (float)(1u << 24)) * 2.0f - 1.0f; /* [-1,1) */
        double u = (double)a * (double)hx[i] + (double)b;
        ref[i] = (double)hr[i] + (double)s * gelu_ref(u);
    }

    CUdeviceptr dx, dr, dy, dt1, dt2; /* dt1/dt2 ping-pong for baseline HBM round-trips */
    CHECK(cuMemAlloc(&dx,  bytes));
    CHECK(cuMemAlloc(&dr,  bytes));
    CHECK(cuMemAlloc(&dy,  bytes));
    CHECK(cuMemAlloc(&dt1, bytes));
    CHECK(cuMemAlloc(&dt2, bytes));
    CHECK(cuMemcpyHtoD(dx, hx, bytes));
    CHECK(cuMemcpyHtoD(dr, hr, bytes));

    const int TPB = 256;
    unsigned grid = (n + TPB - 1) / TPB;

    /* ---- fused launch (single kernel) ---- */
    void *fargs[7] = { &dx, &dr, &dy, (void*)&a, (void*)&b, (void*)&s, &n };
    CHECK(cuLaunchKernel(kf, grid,1,1, TPB,1,1, 0, NULL, fargs, NULL));
    CHECK(cuCtxSynchronize());
    CHECK(cuMemcpyDtoH(hy, dy, bytes));

    /* numeric correctness vs f64 reference */
    double max_abs = 0.0, max_rel = 0.0, max_ref = 0.0;
    for (int i = 0; i < n; ++i) {
        double d = fabs((double)hy[i] - ref[i]);
        if (d > max_abs) max_abs = d;
        double r = (fabs(ref[i]) > 1e-9) ? d / fabs(ref[i]) : d;
        if (r > max_rel) max_rel = r;
        if (fabs(ref[i]) > max_ref) max_ref = fabs(ref[i]);
    }
    /* tanh.approx.f32 carries ~2^-11 rel error; gate at 1e-2 abs */
    double tol = 1e-2;
    const char *num_verd = (max_abs <= tol) ? "PASS" : "FAIL";

    /* ---- timed: fused (1 launch) vs baseline (5 launches) ---- */
    CUevent e0, e1; CHECK(cuEventCreate(&e0,0)); CHECK(cuEventCreate(&e1,0));
    double *tf = (double *)malloc(reps * sizeof(double));
    double *tb = (double *)malloc(reps * sizeof(double));

    /* warmup */
    for (int w = 0; w < warmup; ++w) {
        CHECK(cuLaunchKernel(kf, grid,1,1, TPB,1,1, 0, NULL, fargs, NULL));
    }
    CHECK(cuCtxSynchronize());

    for (int rep = 0; rep < reps; ++rep) {
        CHECK(cuEventRecord(e0, 0));
        CHECK(cuLaunchKernel(kf, grid,1,1, TPB,1,1, 0, NULL, fargs, NULL));
        CHECK(cuEventRecord(e1, 0));
        CHECK(cuEventSynchronize(e1));
        float ms = 0.0f; CHECK(cuEventElapsedTime(&ms, e0, e1));
        tf[rep] = (double)ms;
    }

    /* baseline: 5 launches in sequence, ping-pong buffers, no extra sync
       (eager-stack semantics: each op materialises its output in HBM,
       stream-ordered; one event pair brackets the whole 5-launch chain). */
    void *a1[4] = { &dx,  &dt1, (void*)&a, &n };
    void *a2[4] = { &dt1, &dt2, (void*)&b, &n };
    void *a3[3] = { &dt2, &dt1, &n };
    void *a4[4] = { &dt1, &dt2, (void*)&s, &n };
    void *a5[4] = { &dt2, &dr,  &dy, &n };
    for (int w = 0; w < warmup; ++w) {
        CHECK(cuLaunchKernel(k1, grid,1,1, TPB,1,1, 0, NULL, a1, NULL));
        CHECK(cuLaunchKernel(k2, grid,1,1, TPB,1,1, 0, NULL, a2, NULL));
        CHECK(cuLaunchKernel(k3, grid,1,1, TPB,1,1, 0, NULL, a3, NULL));
        CHECK(cuLaunchKernel(k4, grid,1,1, TPB,1,1, 0, NULL, a4, NULL));
        CHECK(cuLaunchKernel(k5, grid,1,1, TPB,1,1, 0, NULL, a5, NULL));
    }
    CHECK(cuCtxSynchronize());

    for (int rep = 0; rep < reps; ++rep) {
        CHECK(cuEventRecord(e0, 0));
        CHECK(cuLaunchKernel(k1, grid,1,1, TPB,1,1, 0, NULL, a1, NULL));
        CHECK(cuLaunchKernel(k2, grid,1,1, TPB,1,1, 0, NULL, a2, NULL));
        CHECK(cuLaunchKernel(k3, grid,1,1, TPB,1,1, 0, NULL, a3, NULL));
        CHECK(cuLaunchKernel(k4, grid,1,1, TPB,1,1, 0, NULL, a4, NULL));
        CHECK(cuLaunchKernel(k5, grid,1,1, TPB,1,1, 0, NULL, a5, NULL));
        CHECK(cuEventRecord(e1, 0));
        CHECK(cuEventSynchronize(e1));
        float ms = 0.0f; CHECK(cuEventElapsedTime(&ms, e0, e1));
        tb[rep] = (double)ms;
    }

    qsort(tf, reps, sizeof(double), cmp_double);
    qsort(tb, reps, sizeof(double), cmp_double);
    double med_f = tf[reps/2];
    double med_b = tb[reps/2];
    double speedup = (med_f > 0.0) ? (med_b / med_f) : 0.0;
    double pct_faster = (med_b > 0.0) ? (1.0 - med_f / med_b) * 100.0 : 0.0;
    const char *gate_verd = (pct_faster >= 30.0) ? "PASS" : "FAIL";

    /* ---- structural (deterministic, independent of timing) ---- */
    int launch_fused = 1, launch_base = 5;
    int hbm_read_fused = 2,  hbm_write_fused = 1;
    int hbm_read_base  = 6,  hbm_write_base  = 5;

    printf("F-FUSION-LAUNCH-AMORT n=%d reps=%d\n", n, reps);
    printf("  STRUCTURAL: launches fused=%d baseline=%d (ratio %.1fx)\n",
        launch_fused, launch_base, (double)launch_base/launch_fused);
    printf("  STRUCTURAL: HBM fused=%dR+%dW baseline=%dR+%dW (traffic ratio %.2fx)\n",
        hbm_read_fused, hbm_write_fused, hbm_read_base, hbm_write_base,
        (double)(hbm_read_base+hbm_write_base)/(hbm_read_fused+hbm_write_fused));
    printf("  NUMERIC %s: max|d|=%g max_rel=%g tol=%g max_ref=%g\n",
        num_verd, max_abs, max_rel, tol, max_ref);
    printf("  TIMED: fused_med=%.4f ms baseline_med=%.4f ms speedup=%.3fx faster=%.1f%% gate(>=30%%) %s\n",
        med_f, med_b, speedup, pct_faster, gate_verd);

    FILE *rj = fopen("result.json", "w");
    fprintf(rj, "{\n");
    fprintf(rj, "  \"falsifier\": \"F-FUSION-LAUNCH-AMORT\",\n");
    fprintf(rj, "  \"chain\": \"y = residual + scale * GeLU(a*x + b)\",\n");
    fprintf(rj, "  \"n\": %d,\n", n);
    fprintf(rj, "  \"reps\": %d,\n", reps);
    fprintf(rj, "  \"launches_fused\": %d,\n", launch_fused);
    fprintf(rj, "  \"launches_baseline\": %d,\n", launch_base);
    fprintf(rj, "  \"hbm_fused\": \"%dR+%dW\",\n", hbm_read_fused, hbm_write_fused);
    fprintf(rj, "  \"hbm_baseline\": \"%dR+%dW\",\n", hbm_read_base, hbm_write_base);
    fprintf(rj, "  \"numeric_verdict\": \"%s\",\n", num_verd);
    fprintf(rj, "  \"max_abs\": %g,\n", max_abs);
    fprintf(rj, "  \"max_rel\": %g,\n", max_rel);
    fprintf(rj, "  \"fused_med_ms\": %.6f,\n", med_f);
    fprintf(rj, "  \"baseline_med_ms\": %.6f,\n", med_b);
    fprintf(rj, "  \"speedup\": %.4f,\n", speedup);
    fprintf(rj, "  \"pct_faster\": %.2f,\n", pct_faster);
    fprintf(rj, "  \"gate30_verdict\": \"%s\"\n", gate_verd);
    fprintf(rj, "}\n");
    fclose(rj);

    cuMemFree(dx); cuMemFree(dr); cuMemFree(dy); cuMemFree(dt1); cuMemFree(dt2);
    cuEventDestroy(e0); cuEventDestroy(e1);
    cuModuleUnload(mf); cuModuleUnload(mb);
    cuCtxDestroy(ctx);
    return (strcmp(num_verd, "PASS") == 0) ? 0 : 1;
}
