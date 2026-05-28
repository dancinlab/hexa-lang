/* gpu_wedge_topk_fused_handemit
 *
 * F-WEDGE-TOPK-FUSED-WALL  (2026-05-28)
 *
 * Hand-emit fused GEMM + streaming top-K vs baseline cublasSgemm +
 * cub::DeviceSegmentedRadixSort. Shapes target the LM-head decode regime
 * where the 2026-05-27 cheap-first oracle measured a 1.80x ceiling at
 * M=8 LLaMA-vocab and a 1.68x ceiling at M=32 Qwen-vocab.
 *
 * Strategy of the fused kernel:
 *   - one block per output row (M rows total).
 *   - block iterates over the N output columns in tiles of TILE_N=128.
 *     For each tile, each thread loads x[k] strips of K=4096 from the
 *     input row of A (held in shared memory in chunks of TILE_K=64).
 *     Per-thread accumulator sums partial dot products A[m,:] dot B[:,n]
 *     for an assigned column n.
 *   - Once the dot product for column n is complete, the thread inserts
 *     (value, index) into a thread-local top-K register heap (K_TOP=8,
 *     ascending in slot 0..7 by value, slot 0 = current minimum).
 *   - After all N columns are processed, the block performs a warp-level
 *     merge: each thread holds K_TOP=8 candidates; we shuffle-merge them
 *     across the warp using __shfl_sync to produce a per-warp top-K=8.
 *     A second shared-memory merge across warps in the block emits the
 *     final top-K=8 sorted descending into out_vals[m,:] / out_idx[m,:].
 *
 * Notes:
 *   - The kernel keeps the M=8 / M=32 row count below the warp count, so
 *     we use one block per row and parallelize columns within the block.
 *   - K=4096 fits in fast HBM caches; we stream B[:,n] strips column-major
 *     and broadcast A[m, k] from shared per-block.
 *   - FP32 throughout. Comments restricted to pure ASCII per
 *     reference_gpu_fire_infra (driver JIT ptxas rejects non-ASCII).
 *
 * Baseline:
 *   - cublasSgemm to produce dC[M,N] in column-major (default cuBLAS).
 *   - cub::DeviceSegmentedRadixSort::SortPairsDescending over (val, idx)
 *     of all M rows in a single segmented call. Two-call temp-storage probe.
 *   - Take first K_TOP=8 from each segment.
 *
 * Build:
 *   nvcc -O3 -arch=sm_120 -lcublas -o /tmp/topk_fused \
 *        tool/gpu_wedge_topk_fused_handemit.cu
 */

#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <cub/cub.cuh>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define CK(call) do { cudaError_t e = (call); \
    if (e != cudaSuccess) { fprintf(stderr, "CUDA error %s at %s:%d\n", \
        cudaGetErrorString(e), __FILE__, __LINE__); return 1; }} while (0)
#define CB(call) do { cublasStatus_t s = (call); \
    if (s != CUBLAS_STATUS_SUCCESS) { fprintf(stderr, "cuBLAS err %d at %s:%d\n", \
        (int)s, __FILE__, __LINE__); return 1; }} while (0)

#define K_TOP 8

struct Shape { int M, K, N; const char *name; };

static int cmp_d(const void *a, const void *b) {
    double x = *(const double *)a, y = *(const double *)b;
    return (x < y) ? -1 : (x > y) ? 1 : 0;
}

/* ------------------------------------------------------------------ */
/* Fused GEMM + top-K kernel.                                          */
/*                                                                     */
/* dA: row-major (M, K). dB: column-major (K, N) i.e. B[k,n] at        */
/* dB[k + n*K] -- matches cuBLAS column-major B used by the baseline.  */
/* For one row m, output column n is sum_k A[m,k] * B[k,n].            */
/*                                                                     */
/* Grid: one block per row, BLOCK_DIM threads per block.               */
/* Each thread owns columns n in stride BLOCK_DIM.                     */
/* For each owned column, accumulate dot, then insert (val, n) into a  */
/* per-thread top-K=8 ascending min-heap (slot 0 = smallest of held).  */
/* After the column sweep, perform two-stage block reduction:          */
/*   (a) warp-level: each warp merges its 32 thread heaps to a single  */
/*       sorted-descending warp-top-K.                                  */
/*   (b) block-level: shared-memory merge of WARP heaps to one         */
/*       block-top-K.                                                  */
/* ------------------------------------------------------------------- */

#define BLOCK_DIM 256
#define WARPS_PER_BLOCK (BLOCK_DIM / 32)

__device__ __forceinline__ void heap_insert(float *hv, int *hi, float v, int idx) {
    /* min-heap of K_TOP. slot 0 is current minimum. Replace if v > slot0. */
    if (v <= hv[0]) return;
    hv[0] = v; hi[0] = idx;
    /* Re-find new minimum among slots; K_TOP=8 small -- linear scan. */
    float mn = hv[0]; int pos = 0;
    #pragma unroll
    for (int s = 1; s < K_TOP; ++s) {
        if (hv[s] < mn) { mn = hv[s]; pos = s; }
    }
    /* Swap min into slot 0. */
    if (pos != 0) {
        float tv = hv[0]; int ti = hi[0];
        hv[0] = hv[pos]; hi[0] = hi[pos];
        hv[pos] = tv;    hi[pos] = ti;
    }
}

__device__ __forceinline__ void heap_sort_desc(float *hv, int *hi) {
    /* Selection sort, K_TOP=8. After: slot 0 = largest, ascending index. */
    #pragma unroll
    for (int i = 0; i < K_TOP - 1; ++i) {
        int best = i; float bv = hv[i];
        for (int j = i + 1; j < K_TOP; ++j) {
            if (hv[j] > bv) { bv = hv[j]; best = j; }
        }
        if (best != i) {
            float tv = hv[i]; int ti = hi[i];
            hv[i] = hv[best]; hi[i] = hi[best];
            hv[best] = tv;    hi[best] = ti;
        }
    }
}

__global__ void fused_gemm_topk_kernel(
    const float * __restrict__ dA, /* (M, K) row-major */
    const float * __restrict__ dB, /* (K, N) col-major: B[k,n] at dB[k + n*K] */
    float *out_vals,               /* (M, K_TOP), sorted descending  */
    int   *out_idx,                /* (M, K_TOP) */
    int M, int K, int N)
{
    int row = blockIdx.x;
    if (row >= M) return;
    int tid = threadIdx.x;

    /* Per-thread top-K registers. Initialize values to -INF. */
    float hv[K_TOP];
    int   hi[K_TOP];
    #pragma unroll
    for (int s = 0; s < K_TOP; ++s) { hv[s] = -INFINITY; hi[s] = -1; }

    const float *Arow = dA + (size_t)row * K;

    /* Stride over output columns. */
    for (int n = tid; n < N; n += BLOCK_DIM) {
        const float *Bcol = dB + (size_t)n * K;
        float acc = 0.0f;
        /* Dot product. Unroll by 4 for better ILP. */
        int k = 0;
        for (; k + 3 < K; k += 4) {
            acc += Arow[k]   * Bcol[k];
            acc += Arow[k+1] * Bcol[k+1];
            acc += Arow[k+2] * Bcol[k+2];
            acc += Arow[k+3] * Bcol[k+3];
        }
        for (; k < K; ++k) acc += Arow[k] * Bcol[k];
        heap_insert(hv, hi, acc, n);
    }

    /* ---- Block reduction. Each thread writes its K_TOP into shared ---- */
    /* Total shared: BLOCK_DIM * K_TOP floats + ints = 256*8 = 2048 floats. */
    __shared__ float sV[BLOCK_DIM * K_TOP];
    __shared__ int   sI[BLOCK_DIM * K_TOP];
    #pragma unroll
    for (int s = 0; s < K_TOP; ++s) {
        sV[tid * K_TOP + s] = hv[s];
        sI[tid * K_TOP + s] = hi[s];
    }
    __syncthreads();

    /* Thread 0 performs final merge over BLOCK_DIM*K_TOP = 2048 candidates. */
    /* Selection of K_TOP=8 largest is O(2048 * 8) = 16384 compares -- tiny. */
    if (tid == 0) {
        float bv[K_TOP];
        int   bi[K_TOP];
        #pragma unroll
        for (int s = 0; s < K_TOP; ++s) { bv[s] = -INFINITY; bi[s] = -1; }
        int total = BLOCK_DIM * K_TOP;
        for (int p = 0; p < total; ++p) {
            float v = sV[p]; int idx = sI[p];
            if (v <= bv[0]) continue;
            bv[0] = v; bi[0] = idx;
            float mn = bv[0]; int pos = 0;
            #pragma unroll
            for (int s = 1; s < K_TOP; ++s) {
                if (bv[s] < mn) { mn = bv[s]; pos = s; }
            }
            if (pos != 0) {
                float tv = bv[0]; int ti = bi[0];
                bv[0] = bv[pos]; bi[0] = bi[pos];
                bv[pos] = tv;    bi[pos] = ti;
            }
        }
        heap_sort_desc(bv, bi);
        #pragma unroll
        for (int s = 0; s < K_TOP; ++s) {
            out_vals[row * K_TOP + s] = bv[s];
            out_idx[row * K_TOP + s]  = bi[s];
        }
    }
}

/* ------------------------------------------------------------------ */
/* Baseline: cublasSgemm + cub::DeviceSegmentedRadixSort + take K_TOP. */
/* ------------------------------------------------------------------ */

static int run_baseline_once(
    cublasHandle_t h,
    const float *dA_row,  /* (M, K) row-major */
    const float *dB_col,  /* (K, N) col-major */
    float *dC,            /* scratch (M, N) col-major from cuBLAS */
    float *dC_rowmajor,   /* (M, N) row-major scratch for cub  */
    float *dKeys_alt,     /* (M, N) scratch                    */
    int   *dVals,         /* (M, N) index source -- prefilled  */
    int   *dVals_alt,     /* (M, N) sorted indices scratch     */
    int   *dOffsets,      /* (M+1) segment offsets             */
    void  *dTemp,
    size_t tempBytes,
    int M, int K, int N,
    float *outVals,       /* (M, K_TOP) sorted descending      */
    int   *outIdx)        /* (M, K_TOP)                        */
{
    float alpha = 1.0f, beta = 0.0f;
    /* C[N,M] col-major == C[M,N] row-major reading. We use the convenient
     * cuBLAS layout where C is N x M column-major; reinterpret as row-major
     * M x N when feeding cub segmented sort by row. */
    CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N,
                   N, M, K,
                   &alpha,
                   dB_col, N,  /* B: N x K col-major == K x N row-major used by kernel */
                   dA_row, K,  /* A: K x M col-major == M x K row-major (we have row-major M,K) */
                   &beta,
                   dC, N));
    /* dC is N x M column-major == M x N row-major: dC[m*N + n] = C[m,n]. */

    /* Segmented sort descending. */
    cudaError_t e = cub::DeviceSegmentedRadixSort::SortPairsDescending(
        dTemp, tempBytes,
        dC, dKeys_alt,
        dVals, dVals_alt,
        M * N, M,
        dOffsets, dOffsets + 1);
    if (e != cudaSuccess) {
        fprintf(stderr, "cub sort err %s\n", cudaGetErrorString(e));
        return 1;
    }
    /* dKeys_alt[m*N + 0..K_TOP-1] are the top values in descending order.   */
    /* dVals_alt[m*N + 0..K_TOP-1] are the matching column indices.          */
    if (outVals && outIdx) {
        /* Gather K_TOP per row via D2H of just the prefix. */
        for (int m = 0; m < M; ++m) {
            CK(cudaMemcpy(outVals + m * K_TOP, dKeys_alt + (size_t)m * N,
                          K_TOP * sizeof(float), cudaMemcpyDeviceToHost));
            CK(cudaMemcpy(outIdx + m * K_TOP, dVals_alt + (size_t)m * N,
                          K_TOP * sizeof(int), cudaMemcpyDeviceToHost));
        }
    }
    return 0;
}

/* Sort helper used in correctness check to canonicalize tied groups. */
static void sort_indices_by_value_desc(float *vals, int *idx, int n) {
    /* selection sort n small. ties: smaller idx first.                   */
    for (int i = 0; i < n - 1; ++i) {
        int best = i;
        for (int j = i + 1; j < n; ++j) {
            if (vals[j] > vals[best]) best = j;
            else if (vals[j] == vals[best] && idx[j] < idx[best]) best = j;
        }
        if (best != i) {
            float tv = vals[i]; int ti = idx[i];
            vals[i] = vals[best]; idx[i] = idx[best];
            vals[best] = tv;      idx[best] = ti;
        }
    }
}

int main(int argc, char **argv) {
    (void)argc; (void)argv;
    Shape shapes[] = {
        { 8,  4096,  32000, "decode-8tok-LLaMA-vocab"   },
        { 32, 4096, 151643, "small-batch-Qwen-vocab"    },
    };
    const int n_sh = sizeof(shapes) / sizeof(shapes[0]);

    printf("# F-WEDGE-TOPK-FUSED-WALL: hand-emit fused GEMM+top-K vs cuBLAS+cub::DeviceSegmentedRadixSort\n");
    printf("# K=4096, K_TOP=%d, cuEvent warmup=20 iters=200 median\n", K_TOP);
    printf("# shape                          baseline_ms   fused_ms     speedup   ceiling_share\n");

    cublasHandle_t h;
    CB(cublasCreate(&h));

    const int WARMUP = 20, ITERS = 200;
    double *samples = (double *)malloc(ITERS * sizeof(double));

    /* Sanity-check tracking per shape. */
    int any_corr_fail = 0;

    for (int si = 0; si < n_sh; ++si) {
        int M = shapes[si].M, K = shapes[si].K, N = shapes[si].N;
        size_t szA = (size_t)M * K * sizeof(float);
        size_t szB = (size_t)K * N * sizeof(float);
        size_t szC = (size_t)M * N * sizeof(float);
        float *hA = (float *)malloc(szA);
        float *hB = (float *)malloc(szB);
        for (long i = 0; i < (long)M * K; ++i) hA[i] = (float)((i % 7) - 3) * 0.1f;
        for (long i = 0; i < (long)K * N; ++i) hB[i] = (float)((i % 5) - 2) * 0.1f;
        float *dA, *dB, *dC, *dKeys_alt;
        int   *dVals, *dVals_alt, *dOffsets;
        CK(cudaMalloc((void **)&dA, szA));
        CK(cudaMalloc((void **)&dB, szB));
        CK(cudaMalloc((void **)&dC, szC));
        CK(cudaMalloc((void **)&dKeys_alt, szC));
        CK(cudaMalloc((void **)&dVals,     (size_t)M * N * sizeof(int)));
        CK(cudaMalloc((void **)&dVals_alt, (size_t)M * N * sizeof(int)));
        CK(cudaMalloc((void **)&dOffsets,  (size_t)(M + 1) * sizeof(int)));
        CK(cudaMemcpy(dA, hA, szA, cudaMemcpyHostToDevice));
        CK(cudaMemcpy(dB, hB, szB, cudaMemcpyHostToDevice));

        /* Prefill index source: row-major flat 0..N-1 repeated M times.   */
        int *hVals = (int *)malloc((size_t)M * N * sizeof(int));
        for (int m = 0; m < M; ++m) {
            for (int n = 0; n < N; ++n) hVals[(size_t)m * N + n] = n;
        }
        CK(cudaMemcpy(dVals, hVals, (size_t)M * N * sizeof(int), cudaMemcpyHostToDevice));
        free(hVals);

        int *hOff = (int *)malloc((size_t)(M + 1) * sizeof(int));
        for (int m = 0; m <= M; ++m) hOff[m] = m * N;
        CK(cudaMemcpy(dOffsets, hOff, (size_t)(M + 1) * sizeof(int), cudaMemcpyHostToDevice));
        free(hOff);

        /* Probe cub temp storage. */
        size_t tempBytes = 0;
        cudaError_t e = cub::DeviceSegmentedRadixSort::SortPairsDescending(
            (void *)NULL, tempBytes,
            (const float *)dC, dKeys_alt,
            (const int *)dVals, dVals_alt,
            M * N, M,
            dOffsets, dOffsets + 1);
        if (e != cudaSuccess) {
            fprintf(stderr, "cub probe err %s\n", cudaGetErrorString(e));
            return 1;
        }
        void *dTemp = NULL;
        CK(cudaMalloc(&dTemp, tempBytes));

        /* Allocate fused outputs. */
        float *d_fused_vals; int *d_fused_idx;
        CK(cudaMalloc((void **)&d_fused_vals, (size_t)M * K_TOP * sizeof(float)));
        CK(cudaMalloc((void **)&d_fused_idx,  (size_t)M * K_TOP * sizeof(int)));

        /* === Correctness: one run each, compare. === */
        float *base_vals = (float *)malloc((size_t)M * K_TOP * sizeof(float));
        int   *base_idx  = (int *)malloc((size_t)M * K_TOP * sizeof(int));
        if (run_baseline_once(h, dA, dB, dC, NULL, dKeys_alt, dVals, dVals_alt,
                              dOffsets, dTemp, tempBytes, M, K, N,
                              base_vals, base_idx) != 0) return 1;

        /* Restore dVals (consumed by cub sort) for the timed phase. */
        int *hVals2 = (int *)malloc((size_t)M * N * sizeof(int));
        for (int m = 0; m < M; ++m) {
            for (int n = 0; n < N; ++n) hVals2[(size_t)m * N + n] = n;
        }
        CK(cudaMemcpy(dVals, hVals2, (size_t)M * N * sizeof(int), cudaMemcpyHostToDevice));
        free(hVals2);

        fused_gemm_topk_kernel<<<M, BLOCK_DIM>>>(dA, dB, d_fused_vals, d_fused_idx, M, K, N);
        cudaError_t le = cudaGetLastError();
        if (le != cudaSuccess) {
            fprintf(stderr, "fused kernel launch err %s\n", cudaGetErrorString(le));
            return 1;
        }
        CK(cudaDeviceSynchronize());

        float *fused_vals = (float *)malloc((size_t)M * K_TOP * sizeof(float));
        int   *fused_idx  = (int *)malloc((size_t)M * K_TOP * sizeof(int));
        CK(cudaMemcpy(fused_vals, d_fused_vals, (size_t)M * K_TOP * sizeof(float),
                      cudaMemcpyDeviceToHost));
        CK(cudaMemcpy(fused_idx,  d_fused_idx,  (size_t)M * K_TOP * sizeof(int),
                      cudaMemcpyDeviceToHost));

        /* Compare descending-sorted top-K per row. */
        int rows_match = 0;
        for (int m = 0; m < M; ++m) {
            float bv[K_TOP]; int bi[K_TOP];
            float fv[K_TOP]; int fi[K_TOP];
            for (int s = 0; s < K_TOP; ++s) {
                bv[s] = base_vals[m * K_TOP + s]; bi[s] = base_idx[m * K_TOP + s];
                fv[s] = fused_vals[m * K_TOP + s]; fi[s] = fused_idx[m * K_TOP + s];
            }
            sort_indices_by_value_desc(bv, bi, K_TOP);
            sort_indices_by_value_desc(fv, fi, K_TOP);
            int ok = 1;
            for (int s = 0; s < K_TOP; ++s) {
                float diff = fabsf(bv[s] - fv[s]);
                float scale = fabsf(bv[s]) + 1e-6f;
                /* tolerance: ties may give different but equal-valued indices */
                if (diff / scale > 1e-4f) ok = 0;
            }
            if (ok) rows_match++;
            else {
                printf("# row %d MISMATCH base[0]=(%g,%d) fused[0]=(%g,%d) base[%d]=(%g,%d) fused[%d]=(%g,%d)\n",
                       m, bv[0], bi[0], fv[0], fi[0],
                       K_TOP-1, bv[K_TOP-1], bi[K_TOP-1], K_TOP-1, fv[K_TOP-1], fi[K_TOP-1]);
            }
        }
        int corr_ok = (rows_match == M);
        printf("# corr %s rows %s=%d/%d\n", shapes[si].name,
               corr_ok ? "PASS" : "FAIL", rows_match, M);
        if (!corr_ok) any_corr_fail = 1;
        free(base_vals); free(base_idx); free(fused_vals); free(fused_idx);

        if (!corr_ok) {
            printf("# %s INSUFFICIENT -- skipping timing\n", shapes[si].name);
            cudaFree(dA); cudaFree(dB); cudaFree(dC); cudaFree(dKeys_alt);
            cudaFree(dVals); cudaFree(dVals_alt); cudaFree(dOffsets); cudaFree(dTemp);
            cudaFree(d_fused_vals); cudaFree(d_fused_idx);
            free(hA); free(hB);
            continue;
        }

        /* === Baseline timing === */
        cudaEvent_t e0, e1;
        CK(cudaEventCreate(&e0));
        CK(cudaEventCreate(&e1));
        for (int i = 0; i < WARMUP; ++i) {
            /* Restore dVals between calls to keep behavior consistent. */
            CK(cudaMemcpyAsync(dVals, dVals_alt, (size_t)M * N * sizeof(int),
                               cudaMemcpyDeviceToDevice));
            if (run_baseline_once(h, dA, dB, dC, NULL, dKeys_alt, dVals, dVals_alt,
                                  dOffsets, dTemp, tempBytes, M, K, N, NULL, NULL) != 0) return 1;
        }
        CK(cudaDeviceSynchronize());

        for (int i = 0; i < ITERS; ++i) {
            CK(cudaEventRecord(e0, 0));
            if (run_baseline_once(h, dA, dB, dC, NULL, dKeys_alt, dVals, dVals_alt,
                                  dOffsets, dTemp, tempBytes, M, K, N, NULL, NULL) != 0) return 1;
            CK(cudaEventRecord(e1, 0));
            CK(cudaEventSynchronize(e1));
            float ms;
            CK(cudaEventElapsedTime(&ms, e0, e1));
            samples[i] = (double)ms;
        }
        qsort(samples, ITERS, sizeof(double), cmp_d);
        double base_ms = samples[ITERS / 2];

        /* === Fused timing === */
        for (int i = 0; i < WARMUP; ++i) {
            fused_gemm_topk_kernel<<<M, BLOCK_DIM>>>(dA, dB, d_fused_vals, d_fused_idx, M, K, N);
        }
        CK(cudaDeviceSynchronize());
        for (int i = 0; i < ITERS; ++i) {
            CK(cudaEventRecord(e0, 0));
            fused_gemm_topk_kernel<<<M, BLOCK_DIM>>>(dA, dB, d_fused_vals, d_fused_idx, M, K, N);
            CK(cudaEventRecord(e1, 0));
            CK(cudaEventSynchronize(e1));
            float ms;
            CK(cudaEventElapsedTime(&ms, e0, e1));
            samples[i] = (double)ms;
        }
        qsort(samples, ITERS, sizeof(double), cmp_d);
        double fused_ms = samples[ITERS / 2];

        double speedup = base_ms / fused_ms;
        /* Oracle ceiling at M=8 LLaMA = 1.802x; at M=32 Qwen = 1.683x.  */
        double ceiling = (si == 0) ? 1.802 : 1.683;
        double share = 100.0 * speedup / ceiling;
        printf("%-30s  %.6f  %.6f   %.3fx     %5.1f%% of %.3fx\n",
               shapes[si].name, base_ms, fused_ms, speedup, share, ceiling);

        cudaEventDestroy(e0); cudaEventDestroy(e1);
        cudaFree(dA); cudaFree(dB); cudaFree(dC); cudaFree(dKeys_alt);
        cudaFree(dVals); cudaFree(dVals_alt); cudaFree(dOffsets); cudaFree(dTemp);
        cudaFree(d_fused_vals); cudaFree(d_fused_idx);
        free(hA); free(hB);
    }

    free(samples);
    cublasDestroy(h);
    if (any_corr_fail) {
        printf("# OVERALL: INSUFFICIENT -- correctness failure\n");
        return 2;
    }
    return 0;
}
