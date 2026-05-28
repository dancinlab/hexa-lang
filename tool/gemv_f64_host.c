// W1 small-M GEMV wedge host (Round 10) — driver + CPU libm ref
// Build (ubu-2): nvcc -O2 -o gemv_host gemv_f64_host.c -lcuda -lm
// PTX at /tmp/probe_gemv_f64.ptx

#include <cuda.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#define N 256
#define K 512
#define CK(x) do { CUresult r = (x); if (r) { const char *s; cuGetErrorString(r, &s); fprintf(stderr, "cu err %s @ %d\n", s, __LINE__); return 1; } } while (0)

int main(void) {
    double W[N * K], xv[K], y_ref[N], y_gpu[N];
    for (int i = 0; i < N * K; i++) W[i] = sin(0.0007 * (double)i + 0.3) * 0.5;
    for (int k = 0; k < K; k++) xv[k] = sin(0.013 * (double)k + 1.1) * 1.5;

    for (int n = 0; n < N; n++) {
        double acc = 0.0;
        for (int k = 0; k < K; k++) acc += W[n * K + k] * xv[k];
        y_ref[n] = acc;
    }

    CK(cuInit(0));
    CUdevice dev; CK(cuDeviceGet(&dev, 0));
    CUcontext ctx; CK(cuCtxCreate(&ctx, 0, dev));
    FILE *fp = fopen("/tmp/probe_gemv_f64.ptx", "rb");
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
    CUfunction fn; CK(cuModuleGetFunction(&fn, mod, "probe_gemv_f64"));

    CUdeviceptr dW, dx, dy;
    CK(cuMemAlloc(&dW, N * K * sizeof(double)));
    CK(cuMemAlloc(&dx, K * sizeof(double)));
    CK(cuMemAlloc(&dy, N * sizeof(double)));
    CK(cuMemcpyHtoD(dW, W, N * K * sizeof(double)));
    CK(cuMemcpyHtoD(dx, xv, K * sizeof(double)));

    long long nn = N, kk = K;
    void *kargs[] = {&dW, &dx, &dy, &nn, &kk};
    CK(cuLaunchKernel(fn, 1, 1, 1, N, 1, 1, 0, 0, kargs, 0));
    CK(cuCtxSynchronize());
    CK(cuMemcpyDtoH(y_gpu, dy, N * sizeof(double)));

    int n_nan = 0;
    double maxe = 0.0, ref_abs_max = 0.0;
    int worst = 0;
    for (int n = 0; n < N; n++) {
        if (isnan(y_gpu[n]) || isinf(y_gpu[n])) { n_nan++; continue; }
        double e = fabs(y_gpu[n] - y_ref[n]);
        if (e > maxe) { maxe = e; worst = n; }
        if (fabs(y_ref[n]) > ref_abs_max) ref_abs_max = fabs(y_ref[n]);
    }
    double rel = ref_abs_max > 0 ? maxe / ref_abs_max : 0.0;
    printf("small-M GEMV wedge (decode, N=%d K=%d, %d outputs)\n", N, K, N);
    printf("  n_nan_inf = %d / %d\n", n_nan, N);
    printf("  max_abs_err = %.3e  (@n=%d, gpu=%.17g ref=%.17g)\n", maxe, worst, y_gpu[worst], y_ref[worst]);
    printf("  ref_abs_max = %.6g  → max_rel_err = %.3e\n", ref_abs_max, rel);
    if (n_nan == 0 && maxe < 1e-12) printf("  RESULT: PASS (byte-eq band <1e-12)\n");
    else if (n_nan == 0 && rel < 1e-13) printf("  RESULT: PASS-near-byte-eq (rel <1e-13)\n");
    else if (n_nan == 0 && maxe < 1e-7) printf("  RESULT: PASS-numerical (<1e-7)\n");
    else printf("  RESULT: FAIL (n_nan=%d)\n", n_nan);
    return 0;
}
