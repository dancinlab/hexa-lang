/* gpu_qforge_ridge — empirical validation of the QFORGE-PERF RIDGE corollary
 * (bench/qforge/accel_corollaries.hexa #6) on a real RTX 5070.
 *
 * QFORGE's H_apply hot loop is a dense real-symmetric matvec v ↦ H·v. Davidson
 * batches nb trial vectors → the matvec becomes a GEMM (H[n×n] · V[n×nb]). The
 * closed-form RIDGE corollary predicts AI = nb/2 (fp32), so the kernel leaves the
 * memory roof only when nb ≥ 2·ridge ≈ 122 (FP32 CUDA) / 452 (tensor). This tool
 * MEASURES the achieved GFLOP/s + HBM% across nb (= cuBLAS M) at K=N=n=4096 and
 * confirms the predicted crossover empirically. Standalone (no stdlib/qforge edit).
 *
 * Reuses the harness of tool/gpu_hbm_roofline.cu (DtoD BW + cuBLAS timing).
 * Build: nvcc -O2 -o gpu_qforge_ridge gpu_qforge_ridge.cu -lcublas -lcudart
 * Run:   ./gpu_qforge_ridge
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

int main(int argc, char **argv) {
    (void)argc; (void)argv;

    /* === Step 1: effective HBM BW via DtoD memcpy (256 MB, 20w + 200 timed) === */
    const size_t BW_BYTES = 256ULL * 1024 * 1024;
    float *bw_src, *bw_dst;
    CK(cudaMalloc((void **)&bw_src, BW_BYTES));
    CK(cudaMalloc((void **)&bw_dst, BW_BYTES));
    cudaEvent_t e0, e1;
    CK(cudaEventCreate(&e0));
    CK(cudaEventCreate(&e1));
    for (int i = 0; i < 20; ++i)
        CK(cudaMemcpyAsync(bw_dst, bw_src, BW_BYTES, cudaMemcpyDeviceToDevice, 0));
    CK(cudaDeviceSynchronize());
    const int BW_ITERS = 200;
    double *bw_samples = (double *)malloc(BW_ITERS * sizeof(double));
    for (int i = 0; i < BW_ITERS; ++i) {
        CK(cudaEventRecord(e0, 0));
        CK(cudaMemcpyAsync(bw_dst, bw_src, BW_BYTES, cudaMemcpyDeviceToDevice, 0));
        CK(cudaEventRecord(e1, 0));
        CK(cudaEventSynchronize(e1));
        float ms; CK(cudaEventElapsedTime(&ms, e0, e1));
        bw_samples[i] = ms;
    }
    qsort(bw_samples, BW_ITERS, sizeof(double), cmp_d);
    double bw_median_ms = bw_samples[BW_ITERS / 2];
    double hbm_gbps = (2.0 * BW_BYTES) / (bw_median_ms * 1e-3) / 1e9;
    cudaFree(bw_src); cudaFree(bw_dst);

    /* === Step 2: nb sweep (cuBLAS M) at K=N=n=4096, the QFORGE matrix dim === */
    const int NB[] = {1, 4, 16, 32, 64, 100, 122, 144, 256, 452, 512};
    const int n_nb = sizeof(NB) / sizeof(NB[0]);
    const int K = 4096, N = 4096;          /* QFORGE H is n×n; n=4096 */
    const double FP32_PEAK_TFLOPS = 34.11; /* RTX 5070 measured peak (GPU-ROOFLINE.bench.md) */
    double ridge = FP32_PEAK_TFLOPS * 1e3 / hbm_gbps; /* compute_peak/BW (flop/byte) */

    printf("# gpu_qforge_ridge — RIDGE corollary empirical validation (RTX 5070)\n");
    printf("# HBM_BW=%.2f GB/s  FP32_peak=%.2f TFLOP/s  measured_ridge=%.2f flop/byte\n",
           hbm_gbps, FP32_PEAK_TFLOPS, ridge);
    printf("# predicted nb_crossover (fp32) = 2*ridge = %.1f  (corollary said ~121.9)\n", 2.0 * ridge);
    printf("# nb     GFLOPs    AI(F/B)   HBM_pct   compute_pct   regime\n");

    cublasHandle_t h; CB(cublasCreate(&h));
    float alpha = 1.0f, beta = 0.0f;
    const int WARMUP = 20, ITERS = 100;
    double *samples = (double *)malloc(ITERS * sizeof(double));

    for (int bi = 0; bi < n_nb; ++bi) {
        int M = NB[bi];
        size_t szA = (size_t)M * K * sizeof(float);
        size_t szB = (size_t)K * N * sizeof(float);
        size_t szC = (size_t)M * N * sizeof(float);
        float *hA = (float *)malloc(szA), *hB = (float *)malloc(szB);
        for (long i = 0; i < (long)M * K; ++i) hA[i] = (float)((i % 7) - 3) * 0.1f;
        for (long i = 0; i < (long)K * N; ++i) hB[i] = (float)((i % 5) - 2) * 0.1f;
        float *dA, *dB, *dC;
        CK(cudaMalloc((void **)&dA, szA)); CK(cudaMalloc((void **)&dB, szB)); CK(cudaMalloc((void **)&dC, szC));
        CK(cudaMemcpy(dA, hA, szA, cudaMemcpyHostToDevice));
        CK(cudaMemcpy(dB, hB, szB, cudaMemcpyHostToDevice));
        for (int i = 0; i < WARMUP; ++i)
            CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha, dB, N, dA, K, &beta, dC, N));
        CK(cudaDeviceSynchronize());
        for (int i = 0; i < ITERS; ++i) {
            CK(cudaEventRecord(e0, 0));
            CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha, dB, N, dA, K, &beta, dC, N));
            CK(cudaEventRecord(e1, 0));
            CK(cudaEventSynchronize(e1));
            float ms; CK(cudaEventElapsedTime(&ms, e0, e1));
            samples[i] = ms;
        }
        qsort(samples, ITERS, sizeof(double), cmp_d);
        double median_ms = samples[ITERS / 2];
        double flops = 2.0 * (double)M * (double)N * (double)K;
        double bytes_total = (double)((size_t)M * K + (size_t)K * N + (size_t)M * N) * 4.0;
        double gflops = flops / (median_ms * 1e-3) / 1e9;
        double ai = flops / bytes_total;
        double hbm_roof = hbm_gbps * ai;                 /* GFLOP/s memory ceiling */
        double hbm_pct = 100.0 * gflops / hbm_roof;
        double compute_pct = 100.0 * (gflops / 1e3) / FP32_PEAK_TFLOPS;
        const char *regime = (ai < ridge) ? "memory-bound" : "compute-bound";
        printf("%-5d  %8.1f  %7.3f  %6.1f%%   %6.1f%%      %s\n",
               M, gflops, ai, hbm_pct, compute_pct, regime);
        cudaFree(dA); cudaFree(dB); cudaFree(dC); free(hA); free(hB);
    }
    cudaEventDestroy(e0); cudaEventDestroy(e1);
    free(samples); free(bw_samples); cublasDestroy(h);
    return 0;
}
