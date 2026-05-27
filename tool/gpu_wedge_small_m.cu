/* gpu_wedge_small_m — sub-roofline cuBLAS SGEMM at small M (LLM inference).
 *
 * BC3 decomp (PR #1697) showed cuBLAS-using NN stacks are 92% GEMM at large
 * M·N — leaving fusion ceilings of just 1.085×. The wedge with a real >1.5×
 * ceiling for hexa is shape regions where cuBLAS itself is sub-roofline.
 *
 * Single-batch token decode (M=1) is the canonical small-M case: vLLM/etc.
 * shell out to custom GEMV because cuBLAS underperforms when M is too small
 * for the tile size's M-dimension.
 *
 * This launcher sweeps M ∈ {1, 8, 32, 64, 128, 1024} at fixed K=N=4096 and
 * measures cuBLAS SGEMM wall + a roofline reference (achieved GFLOPS vs
 * sm_120 FP32 peak). The 'sub-roofline ratio' = (achieved / peak) flags M
 * where cuBLAS is leaving FLOPS on the table.
 *
 * RTX 5070 sm_120: 31.2 TFLOPS FP32 peak (canonical) — refs PR #1685 atlas.
 *
 * Build: nvcc -O2 -o gpu_wedge_small_m gpu_wedge_small_m.cu -lcublas -lcudart
 * Run:   ./gpu_wedge_small_m
 */
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <stdio.h>
#include <stdlib.h>

#define CK(call) do { cudaError_t e = (call); \
    if (e != cudaSuccess) { fprintf(stderr, "CUDA error %s at %s:%d\n", \
        cudaGetErrorString(e), __FILE__, __LINE__); return 1; }} while (0)
#define CB(call) do { cublasStatus_t s = (call); \
    if (s != CUBLAS_STATUS_SUCCESS) { fprintf(stderr, "cuBLAS err %d at %s:%d\n", \
        (int)s, __FILE__, __LINE__); return 1; }} while (0)

static int cmp_d(const void *a, const void *b) {
    double x = *(const double *)a, y = *(const double *)b;
    return (x < y) ? -1 : (x > y) ? 1 : 0;
}

/* RTX 5070 FP32 peak: 31.2 TFLOPS = 3.12e13 FLOPS. */
static const double PEAK_FP32_TFLOPS = 31.2;

int main(int argc, char **argv) {
    (void)argc; (void)argv;
    const int M_vals[] = {1, 8, 32, 64, 128, 1024};
    const int n_M = sizeof(M_vals) / sizeof(M_vals[0]);
    const int K = 4096, N = 4096;

    printf("# gpu_wedge_small_m — sub-roofline cuBLAS SGEMM sweep (RTX 5070 sm_120)\n");
    printf("# Peak FP32 = %.2f TFLOPS\n", PEAK_FP32_TFLOPS);
    printf("# K=%d N=%d, cuEvent 20 warmup + 200 timed median\n", K, N);
    printf("# M  median_ms  achieved_TFLOPS  sub_roofline_pct\n");

    cublasHandle_t h;
    CB(cublasCreate(&h));
    float alpha = 1.0f, beta = 0.0f;
    const int WARMUP = 20, ITERS = 200;
    double *samples = (double *)malloc(ITERS * sizeof(double));

    for (int mi = 0; mi < n_M; ++mi) {
        int M = M_vals[mi];
        size_t szA = (size_t)M * K * sizeof(float);
        size_t szB = (size_t)K * N * sizeof(float);
        size_t szC = (size_t)M * N * sizeof(float);

        float *hA = (float *)malloc(szA);
        float *hB = (float *)malloc(szB);
        for (long i = 0; i < (long)M * K; ++i) hA[i] = (float)((i % 7) - 3) * 0.1f;
        for (long i = 0; i < (long)K * N; ++i) hB[i] = (float)((i % 5) - 2) * 0.1f;
        float *dA, *dB, *dC;
        CK(cudaMalloc((void **)&dA, szA));
        CK(cudaMalloc((void **)&dB, szB));
        CK(cudaMalloc((void **)&dC, szC));
        CK(cudaMemcpy(dA, hA, szA, cudaMemcpyHostToDevice));
        CK(cudaMemcpy(dB, hB, szB, cudaMemcpyHostToDevice));

        for (int i = 0; i < WARMUP; ++i) {
            CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
                           &alpha, dB, N, dA, K, &beta, dC, N));
        }
        CK(cudaDeviceSynchronize());

        cudaEvent_t e0, e1;
        CK(cudaEventCreate(&e0));
        CK(cudaEventCreate(&e1));
        for (int i = 0; i < ITERS; ++i) {
            CK(cudaEventRecord(e0, 0));
            CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
                           &alpha, dB, N, dA, K, &beta, dC, N));
            CK(cudaEventRecord(e1, 0));
            CK(cudaEventSynchronize(e1));
            float ms;
            CK(cudaEventElapsedTime(&ms, e0, e1));
            samples[i] = (double)ms;
        }

        qsort(samples, ITERS, sizeof(double), cmp_d);
        double median_ms = samples[ITERS / 2];
        double flops = 2.0 * (double)M * (double)N * (double)K;
        double achieved_tflops = flops / (median_ms * 1e-3) * 1e-12;
        double sub_roofline_pct = 100.0 * (1.0 - achieved_tflops / PEAK_FP32_TFLOPS);

        printf("%-5d %.6f  %8.3f         %6.2f%%\n",
               M, median_ms, achieved_tflops, sub_roofline_pct);

        cudaEventDestroy(e0); cudaEventDestroy(e1);
        cudaFree(dA); cudaFree(dB); cudaFree(dC);
        free(hA); free(hB);
    }

    free(samples);
    cublasDestroy(h);
    return 0;
}
