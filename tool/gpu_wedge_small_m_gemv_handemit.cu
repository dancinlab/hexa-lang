/* gpu_wedge_small_m_gemv_handemit — F-WEDGE-SMALL-M-GEMV-WALL fire.
 *
 * Pre-registered falsifier (GPU.log.md 2026-05-27 ranked-wedge #1):
 *   hexa-native hand-emit GEMV vs cuBLAS SGEMM at M in {1, 8, 32}, K=N=4096.
 *
 * Context: cuBLAS at M=1 sustains only 0.30 TFLOPS = 0.95% of sm_120 FP32 peak
 * (31.2 TFLOPS). vLLM/llama.cpp ship custom GEMV CUDA kernels because cuBLAS
 * SGEMM is tile-shape-bound when M is too small. This fire asks: can a plain
 * hand-emit GEMV warp-reduce + broadcast kernel beat cuBLAS at small M?
 *
 * Strategy (M=1 case = pure GEMV):
 *   - One CTA per N-tile of size CTA_N_TILE = 64 output columns.
 *   - Block dim = (32 threads/warp x N_WARPS_PER_BLOCK warps); each warp owns
 *     warp-id's CTA_N_TILE/N_WARPS columns. Within a warp, the 32 lanes
 *     cooperate on the K-stripe reduction for one output column at a time
 *     (warp-reduce via shfl_xor), serialising the warp across its assigned
 *     columns. This is the canonical FasterTransformer / vllm style.
 *
 * Generalised M>1 case:
 *   - Grid Y = M (one CTA row per output row). Each CTA still produces a
 *     CTA_N_TILE output columns for its row. Same warp-reduce body.
 *
 * Verdict rubric (g5):
 *   GREEN (SUPPORTED-NUMERICAL) if handemit >= 1.5x cuBLAS at M=1.
 *   RED   (FALSIFIED)           if handemit <  1.05x cuBLAS at M=1.
 *
 * Build: nvcc -O3 -arch=sm_120 gpu_wedge_small_m_gemv_handemit.cu -lcublas \
 *               -o gpu_wedge_small_m_gemv_handemit
 * Run:   ./gpu_wedge_small_m_gemv_handemit
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

/* RTX 5070 sm_120 FP32 peak. */
static const double PEAK_FP32_TFLOPS = 31.2;

#define WARP_SIZE 32
#define N_WARPS_PER_BLOCK 4
#define CTA_THREADS (WARP_SIZE * N_WARPS_PER_BLOCK)
#define CTA_N_TILE 16  /* output columns per CTA; each warp owns CTA_N_TILE / N_WARPS = 4 columns. */

/* hand-emit GEMV kernel.
 * Computes C[m, n] = sum_k A[m, k] * B[k, n]  for m in [0, M), n in [0, N).
 * Row-major: A is M x K, B is K x N, C is M x N.
 *
 * Grid: dim3(N / CTA_N_TILE, M, 1)
 * Block: dim3(WARP_SIZE, N_WARPS_PER_BLOCK, 1)
 *
 * Within a CTA: warp w owns columns [w * (CTA_N_TILE / N_WARPS_PER_BLOCK),
 *                                    (w+1) * (CTA_N_TILE / N_WARPS_PER_BLOCK)).
 * For each owned column n_local, the warp's 32 lanes stripe-sum across K and
 * shfl_xor warp-reduce to a single scalar; lane 0 writes C[m, n_global].
 */
__global__ void gemv_warpreduce_kernel(
    const float * __restrict__ A,
    const float * __restrict__ B,
    float * __restrict__ C,
    int M, int K, int N)
{
    const int n_tile_base = blockIdx.x * CTA_N_TILE;
    const int m           = blockIdx.y;
    const int warp_id     = threadIdx.y;
    const int lane        = threadIdx.x;

    const int cols_per_warp = CTA_N_TILE / N_WARPS_PER_BLOCK;
    const int n_local_base  = warp_id * cols_per_warp;

    #pragma unroll
    for (int c = 0; c < cols_per_warp; ++c) {
        const int n_global = n_tile_base + n_local_base + c;
        if (n_global >= N) continue;

        float acc = 0.0f;
        /* lane k0 strides through K with step WARP_SIZE. */
        for (int k = lane; k < K; k += WARP_SIZE) {
            float a = A[m * K + k];
            float b = B[k * N + n_global];
            acc += a * b;
        }
        /* warp reduce: shfl_xor butterfly. */
        for (int offset = WARP_SIZE / 2; offset > 0; offset >>= 1) {
            acc += __shfl_xor_sync(0xffffffff, acc, offset);
        }
        if (lane == 0) {
            C[m * N + n_global] = acc;
        }
    }
}

static int cmp_d(const void *a, const void *b) {
    double x = *(const double *)a, y = *(const double *)b;
    return (x < y) ? -1 : (x > y) ? 1 : 0;
}

static int run_one_M(cublasHandle_t h, int M, int K, int N,
                     double *out_cublas_ms, double *out_handemit_ms,
                     double *out_max_abs_err)
{
    size_t szA = (size_t)M * K * sizeof(float);
    size_t szB = (size_t)K * N * sizeof(float);
    size_t szC = (size_t)M * N * sizeof(float);

    float *hA = (float *)malloc(szA);
    float *hB = (float *)malloc(szB);
    float *hC_ref = (float *)malloc(szC);
    float *hC_he  = (float *)malloc(szC);

    for (long i = 0; i < (long)M * K; ++i) hA[i] = (float)((i % 7) - 3) * 0.1f;
    for (long i = 0; i < (long)K * N; ++i) hB[i] = (float)((i % 5) - 2) * 0.1f;

    float *dA, *dB, *dC_ref, *dC_he;
    CK(cudaMalloc((void **)&dA, szA));
    CK(cudaMalloc((void **)&dB, szB));
    CK(cudaMalloc((void **)&dC_ref, szC));
    CK(cudaMalloc((void **)&dC_he,  szC));
    CK(cudaMemcpy(dA, hA, szA, cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB, hB, szB, cudaMemcpyHostToDevice));

    /* cuBLAS baseline: same call shape as gpu_wedge_small_m.cu. */
    float alpha = 1.0f, beta = 0.0f;
    const int WARMUP = 20, ITERS = 200;
    double *samples = (double *)malloc(ITERS * sizeof(double));

    for (int i = 0; i < WARMUP; ++i) {
        CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
                       &alpha, dB, N, dA, K, &beta, dC_ref, N));
    }
    CK(cudaDeviceSynchronize());

    cudaEvent_t e0, e1;
    CK(cudaEventCreate(&e0));
    CK(cudaEventCreate(&e1));
    for (int i = 0; i < ITERS; ++i) {
        CK(cudaEventRecord(e0, 0));
        CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
                       &alpha, dB, N, dA, K, &beta, dC_ref, N));
        CK(cudaEventRecord(e1, 0));
        CK(cudaEventSynchronize(e1));
        float ms;
        CK(cudaEventElapsedTime(&ms, e0, e1));
        samples[i] = (double)ms;
    }
    qsort(samples, ITERS, sizeof(double), cmp_d);
    *out_cublas_ms = samples[ITERS / 2];

    /* hand-emit kernel. */
    dim3 grid((N + CTA_N_TILE - 1) / CTA_N_TILE, M, 1);
    dim3 block(WARP_SIZE, N_WARPS_PER_BLOCK, 1);

    for (int i = 0; i < WARMUP; ++i) {
        gemv_warpreduce_kernel<<<grid, block>>>(dA, dB, dC_he, M, K, N);
    }
    CK(cudaDeviceSynchronize());
    CK(cudaGetLastError());

    for (int i = 0; i < ITERS; ++i) {
        CK(cudaEventRecord(e0, 0));
        gemv_warpreduce_kernel<<<grid, block>>>(dA, dB, dC_he, M, K, N);
        CK(cudaEventRecord(e1, 0));
        CK(cudaEventSynchronize(e1));
        float ms;
        CK(cudaEventElapsedTime(&ms, e0, e1));
        samples[i] = (double)ms;
    }
    qsort(samples, ITERS, sizeof(double), cmp_d);
    *out_handemit_ms = samples[ITERS / 2];

    /* numerical check: copy both back and compute max|delta|. */
    CK(cudaMemcpy(hC_ref, dC_ref, szC, cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hC_he,  dC_he,  szC, cudaMemcpyDeviceToHost));
    double max_abs = 0.0;
    /* cuBLAS used column-major view of (N x M); the dC_ref linear layout in
     * cudaMemcpy is identical to "row-major C with C[m,n] at index n*M+m"
     * because cuBLAS wrote (N rows, M cols) col-major. Our handemit wrote
     * row-major C[m,n] at index m*N+n. Re-index when comparing. */
    for (int m = 0; m < M; ++m) {
        for (int n = 0; n < N; ++n) {
            float ref = hC_ref[n * M + m];     /* cuBLAS col-major in linearmem */
            float he  = hC_he [m * N + n];     /* our row-major */
            double d = (double)he - (double)ref;
            if (d < 0) d = -d;
            if (d > max_abs) max_abs = d;
        }
    }
    *out_max_abs_err = max_abs;

    cudaEventDestroy(e0); cudaEventDestroy(e1);
    free(samples);
    cudaFree(dA); cudaFree(dB); cudaFree(dC_ref); cudaFree(dC_he);
    free(hA); free(hB); free(hC_ref); free(hC_he);
    return 0;
}

int main(int argc, char **argv) {
    (void)argc; (void)argv;
    const int M_vals[] = {1, 8, 32};
    const int n_M = sizeof(M_vals) / sizeof(M_vals[0]);
    const int K = 4096, N = 4096;

    printf("# F-WEDGE-SMALL-M-GEMV-WALL — hand-emit GEMV vs cuBLAS (RTX 5070 sm_120)\n");
    printf("# Peak FP32 = %.2f TFLOPS, K=%d N=%d, cuEvent 20 warmup + 200 timed median\n",
           PEAK_FP32_TFLOPS, K, N);
    printf("# M  cuBLAS_ms  handemit_ms  handemit_TFLOPS  speedup_x  sub_roofline_pct  max_abs_err\n");

    cublasHandle_t h;
    CB(cublasCreate(&h));

    for (int i = 0; i < n_M; ++i) {
        int M = M_vals[i];
        double cublas_ms = 0.0, he_ms = 0.0, err = 0.0;
        if (run_one_M(h, M, K, N, &cublas_ms, &he_ms, &err) != 0) {
            fprintf(stderr, "run failed at M=%d\n", M);
            return 2;
        }
        double flops = 2.0 * (double)M * (double)N * (double)K;
        double he_tflops = flops / (he_ms * 1e-3) * 1e-12;
        double speedup   = cublas_ms / he_ms;
        double sub_rl    = 100.0 * (1.0 - he_tflops / PEAK_FP32_TFLOPS);
        printf("%-5d %.6f  %.6f  %8.3f         %7.3fx  %6.2f%%  %.3e\n",
               M, cublas_ms, he_ms, he_tflops, speedup, sub_rl, err);
    }

    cublasDestroy(h);
    return 0;
}
