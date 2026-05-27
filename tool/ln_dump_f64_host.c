// §5a LN+GEMM NaN isolation diagnostic host (Round 9)
//
// Build (ubu-2): nvcc -O2 -o ln_dump_host ln_dump_f64_host.c -lcuda -lm
// PTX at /tmp/probe_ln_dump_f64.ptx
//
// Compares GPU sm[tid]=normed dump vs CPU LN reference.
// Reports n_nan + max_abs_err. Distinguishes LN/round-trip vs cross-thread-read.

#include <cuda.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#define N 256
#define CK(x) do { CUresult r = (x); if (r) { const char *s; cuGetErrorString(r, &s); fprintf(stderr, "cu err %s @ %d\n", s, __LINE__); return 1; } } while (0)

int main(void) {
    double x[N], normed_ref[N], y_gpu[N];
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

    FILE *fp = fopen("/tmp/probe_ln_dump_f64.ptx", "rb");
    if (!fp) { fprintf(stderr, "ptx open fail\n"); return 1; }
    fseek(fp, 0, SEEK_END); long sz = ftell(fp); fseek(fp, 0, SEEK_SET);
    char *ptx = (char*)malloc(sz + 1);
    if (fread(ptx, 1, sz, fp) != (size_t)sz) { fprintf(stderr, "ptx read short\n"); return 1; }
    ptx[sz] = 0; fclose(fp);

    CUmodule mod;
    CUjit_option opts[] = {CU_JIT_ERROR_LOG_BUFFER, CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES};
    char log[8192] = {0}; size_t logsz = sizeof(log);
    void *vals[] = {log, (void*)logsz};
    CUresult rj = cuModuleLoadDataEx(&mod, ptx, 2, opts, vals);
    if (rj) { fprintf(stderr, "JIT err: %s\n", log); return 1; }

    CUfunction fn; CK(cuModuleGetFunction(&fn, mod, "probe_ln_dump_f64"));

    CUdeviceptr dx, dy;
    CK(cuMemAlloc(&dx, N * sizeof(double)));
    CK(cuMemAlloc(&dy, N * sizeof(double)));
    CK(cuMemcpyHtoD(dx, x, N * sizeof(double)));

    long long nn = N;
    void *kargs[] = {&dx, &dy, &nn};
    CK(cuLaunchKernel(fn, 1, 1, 1, 256, 1, 1, 0, 0, kargs, 0));
    CK(cuCtxSynchronize());
    CK(cuMemcpyDtoH(y_gpu, dy, N * sizeof(double)));

    int n_nan = 0;
    double maxe = 0.0;
    int worst = 0;
    for (int i = 0; i < N; i++) {
        if (isnan(y_gpu[i]) || isinf(y_gpu[i])) n_nan++;
        else {
            double e = fabs(y_gpu[i] - normed_ref[i]);
            if (e > maxe) { maxe = e; worst = i; }
        }
    }
    printf("LN dump diagnostic (N=%d, self-thread dump, NO cross-thread read)\n", N);
    printf("  n_nan_inf = %d / %d\n", n_nan, N);
    printf("  mean=%.6g var=%.6g inv=%.6g (CPU ref)\n", mean, var, inv);
    printf("  gpu[0]=%.17g  ref[0]=%.17g\n", y_gpu[0], normed_ref[0]);
    printf("  gpu[1]=%.17g  ref[1]=%.17g\n", y_gpu[1], normed_ref[1]);
    if (n_nan == 0) {
        printf("  max_abs_err = %.3e (@i=%d)\n", maxe, worst);
        printf("  VERDICT: LN+sm-roundtrip CLEAN → R8 culprit = Phase-2 cross-thread sm[k] read\n");
    } else {
        printf("  VERDICT: NaN in LN/sm-roundtrip itself → culprit upstream of Phase-2\n");
    }
    return 0;
}
