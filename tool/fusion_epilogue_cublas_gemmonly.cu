/* F-FUSION-EPILOGUE-GEMM-DECOMP — cuBLAS standalone SGEMM timed (NO epilogue).
 *
 * BC3 timed-wall falsification (PR #1696, fused 1.57x-13.57x SLOWER) attributed
 * the gap to "naive 16x16 single-warp scalar-fma GEMM vs cuBLAS-grade SGEMM".
 * This launcher isolates the GEMM by removing bias+GELU, so we can decompose:
 *
 *   ratio_gemm_eff  = fused_ms / cublas_gemmonly_ms   (inner-loop efficiency gap)
 *   ratio_epi_share = cublas_gemmonly_ms / cublas3_ms (cuBLAS-3 = GEMM + 2 light kernels)
 *
 * (fusion ceiling under cuBLAS GEMM = cublas_gemmonly_ms / cublas3_ms; below
 *  1.0 means even a free-fusion would lose because cuBLAS GEMM alone takes
 *  most of cuBLAS-3 time.)
 *
 * Same timing convention as fusion_epilogue_{fused,cublas}_timed.{c,cu}:
 *   20 warmup + 200 timed median, cuEvent, GPU 0% util pre-fire.
 *
 * Build:  nvcc -O2 -o fusion_cublas_gemmonly fusion_epilogue_cublas_gemmonly.cu -lcublas -lcudart
 * Run:    ./fusion_cublas_gemmonly M N K   (default 256 256 256)
 */
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#define CK(call) do { cudaError_t e = (call); \
    if (e != cudaSuccess) { fprintf(stderr, "CUDA error %s at %s:%d\n", \
        cudaGetErrorString(e), __FILE__, __LINE__); return 1; }} while (0)
#define CB(call) do { cublasStatus_t s = (call); \
    if (s != CUBLAS_STATUS_SUCCESS) { fprintf(stderr, "cuBLAS error %d at %s:%d\n", \
        (int)s, __FILE__, __LINE__); return 1; }} while (0)

static int cmp_double(const void *a, const void *b) {
    double x = *(const double *)a, y = *(const double *)b;
    return (x < y) ? -1 : (x > y) ? 1 : 0;
}

int main(int argc, char **argv) {
    int M = (argc > 1) ? atoi(argv[1]) : 256;
    int N = (argc > 2) ? atoi(argv[2]) : 256;
    int K = (argc > 3) ? atoi(argv[3]) : 256;

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

    cublasHandle_t h;
    CB(cublasCreate(&h));

    float alpha = 1.0f, beta = 0.0f;
    const int WARMUP = 20;
    for (int i = 0; i < WARMUP; ++i) {
        CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N,
                       N, M, K,
                       &alpha, dB, N, dA, K,
                       &beta, dC, N));
    }
    CK(cudaDeviceSynchronize());

    const int ITERS = 200;
    double *samples = (double *)malloc(ITERS * sizeof(double));
    cudaEvent_t e0, e1;
    CK(cudaEventCreate(&e0));
    CK(cudaEventCreate(&e1));
    for (int i = 0; i < ITERS; ++i) {
        CK(cudaEventRecord(e0, 0));
        CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N,
                       N, M, K,
                       &alpha, dB, N, dA, K,
                       &beta, dC, N));
        CK(cudaEventRecord(e1, 0));
        CK(cudaEventSynchronize(e1));
        float ms;
        CK(cudaEventElapsedTime(&ms, e0, e1));
        samples[i] = (double)ms;
    }

    qsort(samples, ITERS, sizeof(double), cmp_double);
    double median = samples[ITERS / 2];
    double p10 = samples[ITERS / 10];
    double p90 = samples[ITERS - ITERS / 10 - 1];

    printf("F-FUSION-EPILOGUE-DECOMP cublas_gemmonly shape=%dx%dx%d median=%.6f ms p10=%.6f p90=%.6f\n",
           M, N, K, median, p10, p90);

    cudaEventDestroy(e0); cudaEventDestroy(e1);
    cudaFree(dA); cudaFree(dB); cudaFree(dC);
    cublasDestroy(h);
    free(samples); free(hA); free(hB);
    return 0;
}
