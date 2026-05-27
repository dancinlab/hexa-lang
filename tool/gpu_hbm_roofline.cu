/* gpu_hbm_roofline — measure HBM bandwidth + recompute honest roofline for
 * cuBLAS SGEMM small-M sweep.
 *
 * HONEST CORRECTION to PR #1698 wedge probe ceiling claim. The "99.05%
 * sub-roofline at M=1" was computed against FP32 COMPUTE peak (31.2 TFLOPS)
 * which is the wrong reference for memory-bound GEMV — at M=1 the SGEMM is
 * HBM-bound, not compute-bound. The relevant ceiling is HBM bandwidth peak.
 *
 * Roofline model (Williams et al.):
 *   - Arithmetic intensity (AI) = FLOPS / bytes
 *   - For SGEMM with M·K·N: 2*M*N*K flops, bytes = (M·K + K·N + M·N)*4
 *   - At M=1, K=N=4096: AI = 2*1*4096*4096 / (4096 + 4096*4096 + 4096)*4
 *                         = 33.5M / 64MB ≈ 0.52 FLOPS/byte
 *   - Memory-bound threshold (FP32) = peak_compute / peak_HBM
 *     = 31.2 TFLOPS / ~672 GB/s ≈ 46 FLOPS/byte
 *   - AI=0.52 << 46 → strongly memory-bound. Compute roofline irrelevant.
 *   - HBM roofline = peak_HBM × AI
 *
 * This launcher:
 *   1. Measures effective HBM BW via cudaMemcpy DtoD timed (large transfer)
 *   2. Computes HBM roofline (GFLOPS) for each M ∈ {1,8,32,64,128,1024} at
 *      K=N=4096
 *   3. Reports cuBLAS achieved GFLOPS vs HBM roofline (% of HBM peak)
 *
 * This is the HONEST sub-roofline number. The W1 small-M GEMV wedge ceiling
 * is bounded by (100 - cuBLAS_HBM_pct), not (100 - cuBLAS_compute_pct).
 *
 * Build: nvcc -O2 -o gpu_hbm_roofline gpu_hbm_roofline.cu -lcublas -lcudart
 * Run:   ./gpu_hbm_roofline
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

    /* === Step 1: measure HBM BW via DtoD memcpy ===
     * Transfer 256 MB device-to-device, 20w + 200 timed. */
    const size_t BW_BYTES = 256ULL * 1024 * 1024;
    float *bw_src, *bw_dst;
    CK(cudaMalloc((void **)&bw_src, BW_BYTES));
    CK(cudaMalloc((void **)&bw_dst, BW_BYTES));

    cudaEvent_t e0, e1;
    CK(cudaEventCreate(&e0));
    CK(cudaEventCreate(&e1));

    /* warmup */
    for (int i = 0; i < 20; ++i) {
        CK(cudaMemcpyAsync(bw_dst, bw_src, BW_BYTES, cudaMemcpyDeviceToDevice, 0));
    }
    CK(cudaDeviceSynchronize());

    const int BW_ITERS = 200;
    double *bw_samples = (double *)malloc(BW_ITERS * sizeof(double));
    for (int i = 0; i < BW_ITERS; ++i) {
        CK(cudaEventRecord(e0, 0));
        CK(cudaMemcpyAsync(bw_dst, bw_src, BW_BYTES, cudaMemcpyDeviceToDevice, 0));
        CK(cudaEventRecord(e1, 0));
        CK(cudaEventSynchronize(e1));
        float ms;
        CK(cudaEventElapsedTime(&ms, e0, e1));
        bw_samples[i] = ms;
    }
    qsort(bw_samples, BW_ITERS, sizeof(double), cmp_d);
    double bw_median_ms = bw_samples[BW_ITERS / 2];
    /* DtoD reads BW_BYTES and writes BW_BYTES = 2x BW_BYTES traffic. */
    double effective_hbm_gbps = (2.0 * BW_BYTES) / (bw_median_ms * 1e-3) / 1e9;

    printf("# HBM bandwidth (effective) — cudaMemcpy DtoD 256 MB\n");
    printf("# median = %.4f ms, effective BW = %.2f GB/s (read+write)\n",
           bw_median_ms, effective_hbm_gbps);
    printf("# (NVIDIA RTX 5070 marketing: 672 GB/s; sustainable ~85%% = ~570 GB/s)\n\n");

    cudaFree(bw_src);
    cudaFree(bw_dst);

    /* === Step 2: cuBLAS SGEMM small-M sweep, compute HBM-roofline % ===
     * For each M, compare achieved GFLOPS vs HBM roofline (= effective_BW × AI).
     */
    const int M_vals[] = {1, 8, 32, 64, 128, 1024};
    const int n_M = sizeof(M_vals) / sizeof(M_vals[0]);
    const int K = 4096, N = 4096;
    const double FP32_PEAK_TFLOPS = 31.2;  /* RTX 5070 marketing, for compute reference */

    cublasHandle_t h;
    CB(cublasCreate(&h));
    float alpha = 1.0f, beta = 0.0f;
    const int WARMUP = 20, ITERS = 200;
    double *samples = (double *)malloc(ITERS * sizeof(double));

    printf("# cuBLAS SGEMM small-M sweep, HBM-roofline-honest\n");
    printf("# M     median_ms  GFLOPS   AI(F/B)   HBM_roof_GFLOPS  HBM_pct  compute_pct (for reference)\n");
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
        for (int i = 0; i < ITERS; ++i) {
            CK(cudaEventRecord(e0, 0));
            CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
                           &alpha, dB, N, dA, K, &beta, dC, N));
            CK(cudaEventRecord(e1, 0));
            CK(cudaEventSynchronize(e1));
            float ms;
            CK(cudaEventElapsedTime(&ms, e0, e1));
            samples[i] = ms;
        }
        qsort(samples, ITERS, sizeof(double), cmp_d);
        double median_ms = samples[ITERS / 2];
        double flops = 2.0 * (double)M * (double)N * (double)K;
        double bytes_total = (double)((size_t)M * K + (size_t)K * N + (size_t)M * N) * 4.0;
        double achieved_gflops = flops / (median_ms * 1e-3) / 1e9;
        double ai = flops / bytes_total;
        double hbm_roof_gflops = effective_hbm_gbps * 1e9 * ai / 1e9;
        double hbm_pct = 100.0 * achieved_gflops / hbm_roof_gflops;
        double compute_pct = 100.0 * (achieved_gflops / 1e3) / FP32_PEAK_TFLOPS;

        printf("%-5d  %.6f  %7.2f  %.4f  %7.2f         %6.2f%%  %6.2f%%\n",
               M, median_ms, achieved_gflops, ai, hbm_roof_gflops, hbm_pct, compute_pct);

        cudaFree(dA); cudaFree(dB); cudaFree(dC);
        free(hA); free(hB);
    }

    cudaEventDestroy(e0); cudaEventDestroy(e1);
    free(samples); free(bw_samples);
    cublasDestroy(h);
    return 0;
}
