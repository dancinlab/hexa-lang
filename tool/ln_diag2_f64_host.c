// §5a LN NaN pinpoint host (Round 9b)
// Build: nvcc -O2 -o ln_diag2_host ln_diag2_f64_host.c -lcuda -lm

#include <cuda.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#define N 256
#define CK(x) do { CUresult r = (x); if (r) { const char *s; cuGetErrorString(r, &s); fprintf(stderr, "cu err %s @ %d\n", s, __LINE__); return 1; } } while (0)

int main(void) {
    double x[N], normed_ref[N], y_gpu[N], stats[3] = {0,0,0};
    for (int i = 0; i < N; i++) x[i] = sin(0.013 * (double)i + 0.7) * 2.0 + 0.5;
    double sum = 0.0;
    for (int i = 0; i < N; i++) sum += x[i];
    double mean = sum / (double)N;
    double svar = 0.0;
    for (int i = 0; i < N; i++) { double d = x[i] - mean; svar += d * d; }
    double var = svar / (double)N;
    double inv = 1.0 / sqrt(var + 0.00001);
    for (int i = 0; i < N; i++) normed_ref[i] = (x[i] - mean) * inv;

    CK(cuInit(0));
    CUdevice dev; CK(cuDeviceGet(&dev, 0));
    CUcontext ctx; CK(cuCtxCreate(&ctx, 0, dev));
    FILE *fp = fopen("/tmp/probe_ln_diag2_f64.ptx", "rb");
    if (!fp) { fprintf(stderr, "ptx open fail\n"); return 1; }
    fseek(fp, 0, SEEK_END); long sz = ftell(fp); fseek(fp, 0, SEEK_SET);
    char *ptx = (char*)malloc(sz + 1);
    if (fread(ptx, 1, sz, fp) != (size_t)sz) { fprintf(stderr, "read short\n"); return 1; }
    ptx[sz] = 0; fclose(fp);
    CUmodule mod;
    CUjit_option opts[] = {CU_JIT_ERROR_LOG_BUFFER, CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES};
    char log[8192] = {0}; size_t logsz = sizeof(log);
    void *vals[] = {log, (void*)logsz};
    CUresult rj = cuModuleLoadDataEx(&mod, ptx, 2, opts, vals);
    if (rj) { fprintf(stderr, "JIT err: %s\n", log); return 1; }
    CUfunction fn; CK(cuModuleGetFunction(&fn, mod, "probe_ln_diag2_f64"));

    CUdeviceptr dx, dy, dstats;
    CK(cuMemAlloc(&dx, N * sizeof(double)));
    CK(cuMemAlloc(&dy, N * sizeof(double)));
    CK(cuMemAlloc(&dstats, 3 * sizeof(double)));
    CK(cuMemcpyHtoD(dx, x, N * sizeof(double)));
    CK(cuMemcpyHtoD(dstats, stats, 3 * sizeof(double)));

    long long nn = N;
    void *kargs[] = {&dx, &dy, &dstats, &nn};
    CK(cuLaunchKernel(fn, 1, 1, 1, 256, 1, 1, 0, 0, kargs, 0));
    CK(cuCtxSynchronize());
    CK(cuMemcpyDtoH(y_gpu, dy, N * sizeof(double)));
    CK(cuMemcpyDtoH(stats, dstats, 3 * sizeof(double)));

    int n_nan = 0;
    for (int i = 0; i < N; i++) if (isnan(y_gpu[i]) || isinf(y_gpu[i])) n_nan++;
    printf("LN pinpoint (N=%d)\n", N);
    printf("  GPU mean=%.17g  CPU ref=%.17g\n", stats[0], mean);
    printf("  GPU var =%.17g  CPU ref=%.17g\n", stats[1], var);
    printf("  GPU inv =%.17g  CPU ref=%.17g\n", stats[2], inv);
    printf("  normed n_nan_inf = %d / %d  (gpu[0]=%.6g ref[0]=%.6g)\n", n_nan, N, y_gpu[0], normed_ref[0]);
    printf("  --- pinpoint: first NaN among mean/var/inv tells the failing reduce ---\n");
    return 0;
}
