/* gpu_wedge_grouped_qkv — grouped vs separate cuBLAS GEMM, QKV projection pattern.
 *
 * Transformer attention projection: 3 separate GEMMs share input X of shape
 * (M x K) and produce Q, K, V each of shape (M x N). cuBLAS-using stacks
 * typically launch them as 3 separate cublasSgemm calls, paying 3x the X-load
 * HBM cost (X is read 3 times) + 3 launch overhead.
 *
 * cuBLAS provides cublasSgemmStridedBatched which fuses N independent GEMMs of
 * the same shape into one launch. For QKV projection with identical X but
 * different weight matrices, the input-share advantage is real.
 *
 * Decomposition:
 *   baseline_3sep_ms = 3x cublasSgemm in sequence (NN-stack default)
 *   grouped_ms       = cublasSgemmStridedBatched count=3
 *   fusion_ceiling   = baseline_3sep_ms / grouped_ms
 *
 * If ceiling > 1.2x at typical transformer shapes (M=batch*seq, K=d_model,
 * N=d_model), grouped-GEMM is a real >5% wedge above the canonical NN stack.
 *
 * Shapes representative of LLaMA-7B / Qwen-7B (d_model=4096):
 *   - prefill batch:  M=2048 (seq*batch), K=4096, N=4096
 *   - decode single:  M=1,    K=4096, N=4096
 *   - small batch:    M=32,   K=4096, N=4096
 *
 * Build: nvcc -O2 -o gpu_wedge_grouped_qkv gpu_wedge_grouped_qkv.cu -lcublas -lcudart
 * Run:   ./gpu_wedge_grouped_qkv
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
    const int M_vals[] = {1, 32, 128, 512, 2048};
    const int n_M = sizeof(M_vals) / sizeof(M_vals[0]);
    const int K = 4096, N = 4096;

    printf("# gpu_wedge_grouped_qkv — 3 separate cuBLAS Sgemm vs 1 cublasSgemmStridedBatched\n");
    printf("# K=%d N=%d (d_model=4096), 3 weight matrices share input X\n", K, N);
    printf("# cuEvent 20 warmup + 200 timed median\n");
    printf("# M     sep_3x_ms   grouped_ms  ceiling_x\n");

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

        float *dA, *dBq, *dBk, *dBv, *dCq, *dCk, *dCv;
        CK(cudaMalloc((void **)&dA, szA));
        CK(cudaMalloc((void **)&dBq, szB));
        CK(cudaMalloc((void **)&dBk, szB));
        CK(cudaMalloc((void **)&dBv, szB));
        CK(cudaMalloc((void **)&dCq, szC));
        CK(cudaMalloc((void **)&dCk, szC));
        CK(cudaMalloc((void **)&dCv, szC));
        CK(cudaMemcpy(dA, hA, szA, cudaMemcpyHostToDevice));
        CK(cudaMemcpy(dBq, hB, szB, cudaMemcpyHostToDevice));
        CK(cudaMemcpy(dBk, hB, szB, cudaMemcpyHostToDevice));
        CK(cudaMemcpy(dBv, hB, szB, cudaMemcpyHostToDevice));

        /* Warmup both paths. */
        for (int i = 0; i < WARMUP; ++i) {
            CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha, dBq, N, dA, K, &beta, dCq, N));
            CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha, dBk, N, dA, K, &beta, dCk, N));
            CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha, dBv, N, dA, K, &beta, dCv, N));
        }
        CK(cudaDeviceSynchronize());

        /* Timed: 3 separate cublasSgemm. */
        cudaEvent_t e0, e1;
        CK(cudaEventCreate(&e0));
        CK(cudaEventCreate(&e1));
        for (int i = 0; i < ITERS; ++i) {
            CK(cudaEventRecord(e0, 0));
            CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha, dBq, N, dA, K, &beta, dCq, N));
            CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha, dBk, N, dA, K, &beta, dCk, N));
            CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha, dBv, N, dA, K, &beta, dCv, N));
            CK(cudaEventRecord(e1, 0));
            CK(cudaEventSynchronize(e1));
            float ms;
            CK(cudaEventElapsedTime(&ms, e0, e1));
            samples[i] = (double)ms;
        }
        qsort(samples, ITERS, sizeof(double), cmp_d);
        double sep_ms = samples[ITERS / 2];

        /* Timed: cublasSgemmStridedBatched count=3.
         * batchA stride = 0 (same A reused), batchB stride = K*N, batchC stride = M*N. */
        for (int i = 0; i < WARMUP; ++i) {
            CB(cublasSgemmStridedBatched(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
                &alpha, dBq, N, (long long)K * N, dA, K, 0LL, &beta, dCq, N, (long long)M * N, 3));
        }
        CK(cudaDeviceSynchronize());
        for (int i = 0; i < ITERS; ++i) {
            CK(cudaEventRecord(e0, 0));
            CB(cublasSgemmStridedBatched(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
                &alpha, dBq, N, (long long)K * N, dA, K, 0LL, &beta, dCq, N, (long long)M * N, 3));
            CK(cudaEventRecord(e1, 0));
            CK(cudaEventSynchronize(e1));
            float ms;
            CK(cudaEventElapsedTime(&ms, e0, e1));
            samples[i] = (double)ms;
        }
        qsort(samples, ITERS, sizeof(double), cmp_d);
        double grouped_ms = samples[ITERS / 2];

        double ceiling = sep_ms / grouped_ms;
        printf("%-5d  %.6f    %.6f    %.3fx\n", M, sep_ms, grouped_ms, ceiling);

        cudaEventDestroy(e0); cudaEventDestroy(e1);
        cudaFree(dA); cudaFree(dBq); cudaFree(dBk); cudaFree(dBv);
        cudaFree(dCq); cudaFree(dCk); cudaFree(dCv);
        free(hA); free(hB);
    }

    free(samples);
    cublasDestroy(h);
    return 0;
}
