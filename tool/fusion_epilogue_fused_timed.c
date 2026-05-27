/* F-FUSION-EPILOGUE-GEMM-BIAS-GELU-WALL — FUSED hexa-emit kernel TIMED launcher.
 *
 * Clause (b) of BC3 (round-7 GPU.md). The companion structural launcher
 * (fusion_epilogue_fused_host.c) already proved numeric correctness (rel-err
 * <= 1e-2) for the single fused kernel. This file adds cuEvent-timed wall:
 *
 *   - 20 warmup iters (cuLaunchKernel + cuCtxSynchronize, NOT timed)
 *   - 200 timed iters (cuEventRecord begin -> kernel -> cuEventRecord end,
 *                      cuEventElapsedTime collected)
 *   - emit median + p10/p90 in JSON for direct comparison vs the cuBLAS
 *     3-launch baseline (fusion_epilogue_cublas_timed.c).
 *
 * Re-verifies numeric correctness on the FIRST timed iter (same path as the
 * structural launcher) so the timed run also satisfies the falsifier's
 * correctness gate.
 *
 * Build:  nvcc -O2 -o fusion_fused_timed fusion_epilogue_fused_timed.c -lcuda
 * Run:    ./fusion_fused_timed fused_gemm_bias_gelu.ptx M N K   (default 256 256 256)
 */
#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define CK(call) do { CUresult e = (call); \
    if (e != CUDA_SUCCESS) { const char *s = NULL; cuGetErrorString(e, &s); \
        fprintf(stderr, "CUDA error %d at %s:%d: %s\n", e, __FILE__, __LINE__, s ? s : "?"); \
        return 1; }} while (0)

static int cmp_double(const void *a, const void *b) {
    double x = *(const double *)a, y = *(const double *)b;
    return (x < y) ? -1 : (x > y) ? 1 : 0;
}

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s fused.ptx [M N K]\n", argv[0]); return 2; }
    const char *ptx_path = argv[1];
    int M = (argc > 2) ? atoi(argv[2]) : 256;
    int N = (argc > 3) ? atoi(argv[3]) : 256;
    int K = (argc > 4) ? atoi(argv[4]) : 256;

    FILE *fp = fopen(ptx_path, "rb");
    if (!fp) { perror("ptx open"); return 1; }
    fseek(fp, 0, SEEK_END); long np = ftell(fp); fseek(fp, 0, SEEK_SET);
    char *ptx = (char *)malloc(np + 1);
    fread(ptx, 1, np, fp); ptx[np] = 0; fclose(fp);

    CK(cuInit(0));
    CUdevice dev; CK(cuDeviceGet(&dev, 0));
    CUcontext ctx; CK(cuCtxCreate(&ctx, 0, dev));

    char err_log[8192]; err_log[0] = 0;
    CUjit_option opts[2] = { CU_JIT_ERROR_LOG_BUFFER, CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES };
    unsigned int log_sz = sizeof(err_log);
    void *vals[2] = { err_log, (void *)(uintptr_t)log_sz };
    CUmodule mod;
    CUresult r = cuModuleLoadDataEx(&mod, ptx, 2, opts, vals);
    if (r != CUDA_SUCCESS) {
        fprintf(stderr, "JIT err: %s\n", err_log);
        return 1;
    }
    CUfunction f;
    CK(cuModuleGetFunction(&f, mod, "fused_gemm_bias_gelu"));

    size_t szA = (size_t)M * K * sizeof(float);
    size_t szB = (size_t)K * N * sizeof(float);
    size_t szBias = (size_t)N * sizeof(float);
    size_t szC = (size_t)M * N * sizeof(float);
    float *hA = (float *)malloc(szA);
    float *hB = (float *)malloc(szB);
    float *hBias = (float *)malloc(szBias);
    float *hC = (float *)malloc(szC);
    for (long i = 0; i < (long)M * K; ++i) hA[i] = (float)((i % 7) - 3) * 0.1f;
    for (long i = 0; i < (long)K * N; ++i) hB[i] = (float)((i % 5) - 2) * 0.1f;
    for (int i = 0; i < N; ++i)            hBias[i] = (float)((i % 3) - 1) * 0.5f;

    CUdeviceptr dA, dB, dBias, dC;
    CK(cuMemAlloc(&dA, szA));
    CK(cuMemAlloc(&dB, szB));
    CK(cuMemAlloc(&dBias, szBias));
    CK(cuMemAlloc(&dC, szC));
    CK(cuMemcpyHtoD(dA, hA, szA));
    CK(cuMemcpyHtoD(dB, hB, szB));
    CK(cuMemcpyHtoD(dBias, hBias, szBias));

    void *kargs[7] = { &dA, &dB, &dBias, &dC, &M, &N, &K };
    unsigned gx = (N + 15) / 16, gy = (M + 15) / 16;

    /* === Warmup (untimed) === */
    const int WARMUP = 20;
    for (int i = 0; i < WARMUP; ++i) {
        CK(cuLaunchKernel(f, gx, gy, 1, 16, 16, 1, 0, NULL, kargs, NULL));
    }
    CK(cuCtxSynchronize());

    /* === Timed iters === */
    const int ITERS = 200;
    double *samples = (double *)malloc(ITERS * sizeof(double));
    CUevent e0, e1;
    CK(cuEventCreate(&e0, CU_EVENT_DEFAULT));
    CK(cuEventCreate(&e1, CU_EVENT_DEFAULT));
    for (int i = 0; i < ITERS; ++i) {
        CK(cuEventRecord(e0, 0));
        CK(cuLaunchKernel(f, gx, gy, 1, 16, 16, 1, 0, NULL, kargs, NULL));
        CK(cuEventRecord(e1, 0));
        CK(cuEventSynchronize(e1));
        float ms;
        CK(cuEventElapsedTime(&ms, e0, e1));
        samples[i] = (double)ms;
    }

    /* Numeric check on the last fired result. */
    CK(cuMemcpyDtoH(hC, dC, szC));
    int total = M * N;
    int step = (total > 4096) ? (total / 4096) : 1;
    double max_rel = 0.0, max_abs = 0.0; int checked = 0;
    for (int idx = 0; idx < total; idx += step) {
        int m = idx / N, n = idx % N;
        double acc = 0.0;
        for (int k = 0; k < K; ++k)
            acc += (double)hA[m * K + k] * (double)hB[k * N + n];
        double x = acc + (double)hBias[n];
        double t = 0.7978845608028654 * (x + 0.044715 * x * x * x);
        double g = 0.5 * x * (1.0 + tanh(t));
        double d = fabs((double)hC[idx] - g);
        double rel = d / (fabs(g) + 1e-6);
        if (d > max_abs) max_abs = d;
        if (rel > max_rel) max_rel = rel;
        ++checked;
    }

    qsort(samples, ITERS, sizeof(double), cmp_double);
    double median = samples[ITERS / 2];
    double p10 = samples[ITERS / 10];
    double p90 = samples[ITERS - ITERS / 10 - 1];

    const char *verd = (max_rel <= 1e-2) ? "PASS" : "FAIL";
    printf("F-FUSION-EPILOGUE-WALL fused %s shape=%dx%dx%d median=%.6f ms p10=%.6f p90=%.6f "
           "max_rel=%g max_abs=%g\n",
           verd, M, N, K, median, p10, p90, max_rel, max_abs);

    FILE *rj = fopen("result_fused_timed.json", "w");
    if (rj) {
        fprintf(rj, "{\n");
        fprintf(rj, "  \"falsifier\": \"F-FUSION-EPILOGUE-GEMM-BIAS-GELU-WALL\",\n");
        fprintf(rj, "  \"kernel\": \"fused_gemm_bias_gelu\",\n");
        fprintf(rj, "  \"verdict\": \"%s\",\n", verd);
        fprintf(rj, "  \"shape\": \"%dx%dx%d\",\n", M, N, K);
        fprintf(rj, "  \"launches\": 1,\n");
        fprintf(rj, "  \"warmup\": %d,\n", WARMUP);
        fprintf(rj, "  \"iters\": %d,\n", ITERS);
        fprintf(rj, "  \"median_ms\": %.6f,\n", median);
        fprintf(rj, "  \"p10_ms\": %.6f,\n", p10);
        fprintf(rj, "  \"p90_ms\": %.6f,\n", p90);
        fprintf(rj, "  \"max_rel\": %g,\n", max_rel);
        fprintf(rj, "  \"max_abs\": %g\n", max_abs);
        fprintf(rj, "}\n");
        fclose(rj);
    }

    cuEventDestroy(e0); cuEventDestroy(e1);
    cuMemFree(dA); cuMemFree(dB); cuMemFree(dBias); cuMemFree(dC);
    cuModuleUnload(mod); cuCtxDestroy(ctx);
    free(samples); free(hA); free(hB); free(hBias); free(hC); free(ptx);
    return (max_rel <= 1e-2) ? 0 : 1;
}
