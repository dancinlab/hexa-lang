// §5a LN+GEMM combined v2 host (Round 9c) — to_i64()-wrapped workaround verify
// Build: nvcc -O2 -o ln_gemm_v2_host ln_gemm_v2_f64_host.c -lcuda -lm

#include <cuda.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#define N 256
#define M 64
#define CK(x) do { CUresult r = (x); if (r) { const char *s; cuGetErrorString(r, &s); fprintf(stderr, "cu err %s @ %d\n", s, __LINE__); return 1; } } while (0)

int main(void) {
    double x[N], W[N * M], y_ref[M], y_gpu[M];
    for (int i = 0; i < N; i++) x[i] = sin(0.013 * (double)i + 0.7) * 2.0 + 0.5;
    for (int i = 0; i < N * M; i++) W[i] = sin(0.019 * (double)i + 1.1) * 0.5;

    double sum = 0.0;
    for (int i = 0; i < N; i++) sum += x[i];
    double mean = sum / (double)N;
    double svar = 0.0;
    for (int i = 0; i < N; i++) { double d = x[i] - mean; svar += d * d; }
    double var = svar / (double)N;
    double inv = 1.0 / sqrt(var + 0.00001);
    double normed[N];
    for (int i = 0; i < N; i++) normed[i] = (x[i] - mean) * inv;
    for (int j = 0; j < M; j++) {
        double acc = 0.0;
        for (int k = 0; k < N; k++) acc += W[k * M + j] * normed[k];
        y_ref[j] = acc;
    }

    CK(cuInit(0));
    CUdevice dev; CK(cuDeviceGet(&dev, 0));
    CUcontext ctx; CK(cuCtxCreate(&ctx, 0, dev));
    FILE *fp = fopen("/tmp/probe_ln_gemm_v3_f64.ptx", "rb");
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
    CUfunction fn; CK(cuModuleGetFunction(&fn, mod, "probe_ln_gemm_v3_f64"));

    CUdeviceptr dx, dW, dy;
    CK(cuMemAlloc(&dx, N * sizeof(double)));
    CK(cuMemAlloc(&dW, N * M * sizeof(double)));
    CK(cuMemAlloc(&dy, M * sizeof(double)));
    CK(cuMemcpyHtoD(dx, x, N * sizeof(double)));
    CK(cuMemcpyHtoD(dW, W, N * M * sizeof(double)));

    long long nn = N, mm = M;
    void *kargs[] = {&dx, &dW, &dy, &nn, &mm};
    CK(cuLaunchKernel(fn, 1, 1, 1, 256, 1, 1, 0, 0, kargs, 0));
    CK(cuCtxSynchronize());
    CK(cuMemcpyDtoH(y_gpu, dy, M * sizeof(double)));

    int n_nan = 0;
    double maxe = 0.0, ref_abs_max = 0.0;
    int worst = 0;
    for (int j = 0; j < M; j++) {
        if (isnan(y_gpu[j]) || isinf(y_gpu[j])) { n_nan++; continue; }
        double e = fabs(y_gpu[j] - y_ref[j]);
        if (e > maxe) { maxe = e; worst = j; }
        if (fabs(y_ref[j]) > ref_abs_max) ref_abs_max = fabs(y_ref[j]);
    }
    double rel = ref_abs_max > 0 ? maxe / ref_abs_max : 0.0;
    printf("LN+GEMM v2 (to_i64-wrapped) (N=%d M=%d, %d outputs)\n", N, M, M);
    printf("  n_nan_inf = %d / %d\n", n_nan, M);
    printf("  max_abs_err = %.3e  (@j=%d, gpu=%.17g ref=%.17g)\n", maxe, worst, y_gpu[worst], y_ref[worst]);
    printf("  ref_abs_max = %.6g  → max_rel_err = %.3e\n", ref_abs_max, rel);
    if (n_nan == 0 && maxe < 1e-12) printf("  RESULT: PASS (byte-eq band <1e-12) — WORKAROUND CONFIRMED\n");
    else if (n_nan == 0 && rel < 1e-13) printf("  RESULT: PASS-near-byte-eq — WORKAROUND CONFIRMED\n");
    else if (n_nan == 0 && maxe < 1e-7) printf("  RESULT: PASS-numerical\n");
    else printf("  RESULT: FAIL (n_nan=%d)\n", n_nan);
    return 0;
}
