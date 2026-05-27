/* F-FUSION-EPILOGUE-GEMM-BIAS-GELU-WALL — cuBLAS 3-launch BASELINE TIMED.
 *
 * Companion to fusion_epilogue_fused_timed.c. Same shape, same numeric
 * computation `C = GeLU(A @ B + bias)`, but via the canonical cuBLAS-using
 * NN-stack path (3 separate launches sharing HBM round-trips):
 *
 *   launch 1: cublasSgemm        (M x N C-write)
 *   launch 2: bias_add_kernel    (read C + bias, write C)
 *   launch 3: gelu_kernel        (read C, write C)
 *
 * The TIMED wall sums these three launches per iter (1 cuEvent record begin
 * before launch 1, 1 cuEvent record after launch 3) so the median directly
 * reports the wall a cuBLAS-using NN-stack would observe per FFN epilogue
 * step. 20 warmup + 200 timed median, identical to the fused launcher.
 *
 * Build:  nvcc -O2 -o fusion_cublas_timed fusion_epilogue_cublas_timed.c -lcublas -lcudart
 * Run:    ./fusion_cublas_timed M N K       (default 256 256 256)
 */
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define CK(call) do { cudaError_t e = (call); \
    if (e != cudaSuccess) { fprintf(stderr, "CUDA error %s at %s:%d\n", \
        cudaGetErrorString(e), __FILE__, __LINE__); return 1; }} while (0)
#define CB(call) do { cublasStatus_t s = (call); \
    if (s != CUBLAS_STATUS_SUCCESS) { fprintf(stderr, "cuBLAS error %d at %s:%d\n", \
        (int)s, __FILE__, __LINE__); return 1; }} while (0)

__global__ void bias_add_kernel(float *C, const float *bias, int M, int N) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = M * N;
    if (idx < total) {
        int n = idx % N;
        C[idx] = C[idx] + bias[n];
    }
}

__global__ void gelu_kernel(float *C, int M, int N) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = M * N;
    if (idx < total) {
        float x = C[idx];
        float x3 = x * x * x;
        float t = 0.7978845608028654f * (x + 0.044715f * x3);
        float th = tanhf(t);
        C[idx] = 0.5f * x * (1.0f + th);
    }
}

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
    size_t szBias = (size_t)N * sizeof(float);
    size_t szC = (size_t)M * N * sizeof(float);
    float *hA = (float *)malloc(szA);
    float *hB = (float *)malloc(szB);
    float *hBias = (float *)malloc(szBias);
    float *hC = (float *)malloc(szC);
    for (long i = 0; i < (long)M * K; ++i) hA[i] = (float)((i % 7) - 3) * 0.1f;
    for (long i = 0; i < (long)K * N; ++i) hB[i] = (float)((i % 5) - 2) * 0.1f;
    for (int i = 0; i < N; ++i)            hBias[i] = (float)((i % 3) - 1) * 0.5f;

    float *dA, *dB, *dBias, *dC;
    CK(cudaMalloc((void **)&dA, szA));
    CK(cudaMalloc((void **)&dB, szB));
    CK(cudaMalloc((void **)&dBias, szBias));
    CK(cudaMalloc((void **)&dC, szC));
    CK(cudaMemcpy(dA, hA, szA, cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB, hB, szB, cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dBias, hBias, szBias, cudaMemcpyHostToDevice));

    cublasHandle_t h;
    CB(cublasCreate(&h));

    float alpha = 1.0f, beta = 0.0f;
    int total = M * N;
    int tb = 256, gb = (total + tb - 1) / tb;

    /* Warmup */
    const int WARMUP = 20;
    for (int i = 0; i < WARMUP; ++i) {
        /* row-major C = A * B emulated via column-major: B^T * A^T -> C^T then
         * read as row-major. Equivalent to cublasSgemm(N, A, B, ...) trick. */
        CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N,
                       N, M, K,
                       &alpha, dB, N, dA, K,
                       &beta, dC, N));
        bias_add_kernel<<<gb, tb>>>(dC, dBias, M, N);
        gelu_kernel<<<gb, tb>>>(dC, M, N);
    }
    CK(cudaDeviceSynchronize());

    /* Timed */
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
        bias_add_kernel<<<gb, tb>>>(dC, dBias, M, N);
        gelu_kernel<<<gb, tb>>>(dC, M, N);
        CK(cudaEventRecord(e1, 0));
        CK(cudaEventSynchronize(e1));
        float ms;
        CK(cudaEventElapsedTime(&ms, e0, e1));
        samples[i] = (double)ms;
    }

    CK(cudaMemcpy(hC, dC, szC, cudaMemcpyDeviceToHost));
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
    printf("F-FUSION-EPILOGUE-WALL cublas3 %s shape=%dx%dx%d median=%.6f ms p10=%.6f p90=%.6f "
           "max_rel=%g max_abs=%g\n",
           verd, M, N, K, median, p10, p90, max_rel, max_abs);

    FILE *rj = fopen("result_cublas_timed.json", "w");
    if (rj) {
        fprintf(rj, "{\n");
        fprintf(rj, "  \"falsifier\": \"F-FUSION-EPILOGUE-GEMM-BIAS-GELU-WALL\",\n");
        fprintf(rj, "  \"path\": \"cublas3\",\n");
        fprintf(rj, "  \"verdict\": \"%s\",\n", verd);
        fprintf(rj, "  \"shape\": \"%dx%dx%d\",\n", M, N, K);
        fprintf(rj, "  \"launches\": 3,\n");
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

    cudaEventDestroy(e0); cudaEventDestroy(e1);
    cudaFree(dA); cudaFree(dB); cudaFree(dBias); cudaFree(dC);
    cublasDestroy(h);
    free(samples); free(hA); free(hB); free(hBias); free(hC);
    return (max_rel <= 1e-2) ? 0 : 1;
}
