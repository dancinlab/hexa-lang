/* gpu_wedge_topk — cuBLAS Sgemm + thrust top-K vs hypothetical fused ceiling.
 *
 * §5j top-k+GEMM fusion ceiling probe. Common NN pattern: linear projection
 * to vocab (M·N matmul where N = vocab_size ~150K) followed by top-K over
 * the row to find candidate tokens. cuBLAS-using stacks: cublasSgemm +
 * separate top-K kernel; the top-K reads the full M·N output back from HBM.
 *
 * Decomposition:
 *   gemm_only_ms = cublasSgemm wall (reference)
 *   gemm_plus_topk_ms = cublasSgemm + thrust::sort + take first K  (canonical NN-stack
 *                       path; uses thrust as a stand-in for cub::DeviceSegmentedRadixSort)
 *   topk_share = (gemm_plus_topk - gemm_only) / gemm_plus_topk
 *   fusion_ceiling = gemm_plus_topk / gemm_only  (assuming free fusion of top-K)
 *
 * If topk_share > 30% at FFN-output shape, §5j is a real >1.4× wedge.
 * Back-of-envelope from BC3 decomp (HBM ~672 GB/s, FFN C = 180 MB →
 * 0.27 ms min topk read time, cuBLAS gemm = 15.4 ms): ceiling ~1.018×.
 * This launcher measures the actual cost.
 *
 * Note: thrust::sort is NOT the cheapest top-K (radix-select is faster) but
 * it represents what NN stacks typically use without specialized cub plumbing.
 *
 * Build: nvcc -O2 -o gpu_wedge_topk gpu_wedge_topk.cu -lcublas -lcudart
 * Run:   ./gpu_wedge_topk
 */
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <thrust/device_vector.h>
#include <thrust/sort.h>
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

struct Shape { int M, K, N; const char *name; };

int main(int argc, char **argv) {
    (void)argc; (void)argv;
    /* Representative LM-head shapes — vocab projections (N = vocab_size). */
    Shape shapes[] = {
        { 1, 4096, 151643, "decode-1tok-Qwen-vocab"   },
        { 8, 4096, 151643, "decode-8tok-Qwen-vocab"   },
        { 32, 4096, 151643, "small-batch-Qwen-vocab"  },
        { 1, 4096,  32000, "decode-1tok-LLaMA-vocab"  },
        { 8, 4096,  32000, "decode-8tok-LLaMA-vocab"  },
    };
    const int n_sh = sizeof(shapes) / sizeof(shapes[0]);

    printf("# gpu_wedge_topk — cuBLAS Sgemm + thrust::sort (top-K) ceiling probe\n");
    printf("# K=d_model=4096, N=vocab; thrust::sort over N per row (stand-in for cub topK)\n");
    printf("# cuEvent 20 warmup + 200 timed median\n");
    printf("# shape                          gemm_ms       gemm+topk_ms  topk_share  ceiling_x\n");

    cublasHandle_t h;
    CB(cublasCreate(&h));
    float alpha = 1.0f, beta = 0.0f;
    const int WARMUP = 20, ITERS = 100;  /* top-K is heavier; halve iters. */
    double *samples = (double *)malloc(ITERS * sizeof(double));

    for (int si = 0; si < n_sh; ++si) {
        int M = shapes[si].M, K = shapes[si].K, N = shapes[si].N;
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

        /* === GEMM only === */
        for (int i = 0; i < WARMUP; ++i) {
            CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha, dB, N, dA, K, &beta, dC, N));
        }
        CK(cudaDeviceSynchronize());

        cudaEvent_t e0, e1;
        CK(cudaEventCreate(&e0));
        CK(cudaEventCreate(&e1));
        for (int i = 0; i < ITERS; ++i) {
            CK(cudaEventRecord(e0, 0));
            CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha, dB, N, dA, K, &beta, dC, N));
            CK(cudaEventRecord(e1, 0));
            CK(cudaEventSynchronize(e1));
            float ms;
            CK(cudaEventElapsedTime(&ms, e0, e1));
            samples[i] = (double)ms;
        }
        qsort(samples, ITERS, sizeof(double), cmp_d);
        double gemm_ms = samples[ITERS / 2];

        /* === GEMM + thrust::sort per row (top-K stand-in) === */
        for (int i = 0; i < WARMUP; ++i) {
            CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha, dB, N, dA, K, &beta, dC, N));
            for (int row = 0; row < M; ++row) {
                thrust::sort(thrust::device, dC + (size_t)row * N, dC + (size_t)row * N + N);
            }
        }
        CK(cudaDeviceSynchronize());
        for (int i = 0; i < ITERS; ++i) {
            CK(cudaEventRecord(e0, 0));
            CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha, dB, N, dA, K, &beta, dC, N));
            for (int row = 0; row < M; ++row) {
                thrust::sort(thrust::device, dC + (size_t)row * N, dC + (size_t)row * N + N);
            }
            CK(cudaEventRecord(e1, 0));
            CK(cudaEventSynchronize(e1));
            float ms;
            CK(cudaEventElapsedTime(&ms, e0, e1));
            samples[i] = (double)ms;
        }
        qsort(samples, ITERS, sizeof(double), cmp_d);
        double full_ms = samples[ITERS / 2];

        double topk_share_pct = 100.0 * (full_ms - gemm_ms) / full_ms;
        double ceiling = full_ms / gemm_ms;
        printf("%-30s  %.6f  %.6f  %6.2f%%   %.3fx\n",
               shapes[si].name, gemm_ms, full_ms, topk_share_pct, ceiling);

        cudaEventDestroy(e0); cudaEventDestroy(e1);
        cudaFree(dA); cudaFree(dB); cudaFree(dC);
        free(hA); free(hB);
    }

    free(samples);
    cublasDestroy(h);
    return 0;
}
