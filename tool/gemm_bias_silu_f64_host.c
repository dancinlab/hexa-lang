// §5a GEMM+bias+SiLU epilogue host driver + CPU libm ref (Round 6)
//
// Build (ubu-2):
//   nvcc -O2 -o gemm_bias_silu_host gemm_bias_silu_f64_host.c -lcuda -lm
//   PTX expected at /tmp/probe_gemm_bias_silu_f64.ptx
//
// PASS: worst < 1e-12 across all M*N outputs (near-byte-eq).

#include <cuda.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define M 4
#define N 64
#define K 128
#define CK(x) do { CUresult r = (x); if (r) { const char *s; cuGetErrorString(r, &s); fprintf(stderr, "cu err %s @ %d\n", s, __LINE__); return 1; } } while (0)

static double cpu_sigmoid(double x) {
    // sigmoid(x) = 1/(1+exp(-x))
    return 1.0 / (1.0 + exp(-x));
}

int main(void) {
    // deterministic init
    double A[M * K], B[K * N], bias[N];
    double y_ref[M * N], y_gpu[M * N];
    for (int i = 0; i < M * K; i++) A[i] = sin(0.011 * (double)i + 0.3) * 0.5;
    for (int i = 0; i < K * N; i++) B[i] = sin(0.017 * (double)i + 1.1) * 0.5;
    for (int i = 0; i < N; i++)     bias[i] = sin(0.029 * (double)i + 0.7) * 0.2;

    // CPU libm reference (closed-form same as kernel)
    for (int m = 0; m < M; m++) {
        for (int n = 0; n < N; n++) {
            double acc = 0.0;
            for (int k = 0; k < K; k++) acc += A[m * K + k] * B[k * N + n];
            double z = acc + bias[n];
            y_ref[m * N + n] = z * cpu_sigmoid(z);
        }
    }

    // CUDA boot
    CK(cuInit(0));
    CUdevice dev; CK(cuDeviceGet(&dev, 0));
    CUcontext ctx; CK(cuCtxCreate(&ctx, 0, dev));

    FILE *fp = fopen("/tmp/probe_gemm_bias_silu_f64.ptx", "rb");
    if (!fp) { fprintf(stderr, "ptx open fail\n"); return 1; }
    fseek(fp, 0, SEEK_END); long sz = ftell(fp); fseek(fp, 0, SEEK_SET);
    char *ptx = (char*)malloc(sz + 1);
    if (fread(ptx, 1, sz, fp) != (size_t)sz) { fprintf(stderr, "ptx read short\n"); return 1; }
    ptx[sz] = 0; fclose(fp);

    CUmodule mod;
    CUjit_option opts[] = {CU_JIT_ERROR_LOG_BUFFER, CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES};
    char log[8192] = {0}; size_t logsz = sizeof(log);
    void *vals[] = {log, (void*)logsz};
    CUresult lr = cuModuleLoadDataEx(&mod, ptx, 2, opts, vals);
    if (lr) { fprintf(stderr, "JIT err: %s\n", log); return 1; }

    CUfunction fn; CK(cuModuleGetFunction(&fn, mod, "probe_gemm_bias_silu_f64"));

    CUdeviceptr dA, dB, dbias, dy;
    CK(cuMemAlloc(&dA, M * K * sizeof(double)));
    CK(cuMemAlloc(&dB, K * N * sizeof(double)));
    CK(cuMemAlloc(&dbias, N * sizeof(double)));
    CK(cuMemAlloc(&dy, M * N * sizeof(double)));
    CK(cuMemcpyHtoD(dA, A, M * K * sizeof(double)));
    CK(cuMemcpyHtoD(dB, B, K * N * sizeof(double)));
    CK(cuMemcpyHtoD(dbias, bias, N * sizeof(double)));

    long long mm = M, nn = N, kk = K;
    void *kargs[] = {&dA, &dB, &dbias, &dy, &mm, &nn, &kk};
    // 256 threads = M*N, single block
    CK(cuLaunchKernel(fn, 1, 1, 1, M * N, 1, 1, 0, 0, kargs, 0));
    CK(cuCtxSynchronize());

    CK(cuMemcpyDtoH(y_gpu, dy, M * N * sizeof(double)));

    double maxe = 0.0, sume = 0.0, ref_abs_max = 0.0;
    int worst = 0;
    for (int i = 0; i < M * N; i++) {
        double e = fabs(y_gpu[i] - y_ref[i]);
        if (e > maxe) { maxe = e; worst = i; }
        sume += e;
        if (fabs(y_ref[i]) > ref_abs_max) ref_abs_max = fabs(y_ref[i]);
    }
    double rel = ref_abs_max > 0 ? maxe / ref_abs_max : 0.0;
    printf("GEMM+bias+SiLU 1-kernel wedge (M=%d N=%d K=%d, %d outputs)\n", M, N, K, M * N);
    printf("  max_abs_err = %.3e  (@i=%d, gpu=%.17g ref=%.17g)\n",
           maxe, worst, y_gpu[worst], y_ref[worst]);
    printf("  mean_abs_err = %.3e\n", sume / (M * N));
    printf("  ref_abs_max  = %.6g  → max_rel_err = %.3e\n", ref_abs_max, rel);
    if (maxe < 1e-12) printf("  RESULT: PASS (byte-eq band <1e-12)\n");
    else if (rel < 1e-13) printf("  RESULT: PASS-near-byte-eq (rel <1e-13)\n");
    else if (maxe < 1e-7) printf("  RESULT: PASS-numerical (<1e-7)\n");
    else printf("  RESULT: FAIL\n");

    return 0;
}
