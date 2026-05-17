/* b_dsm_ffn_stage2.cu — forge Phase R / B Stage 2 (DSM cluster fused FFN, FIRST FIRE = API smoke)
 *
 * Pre-registered B Stage 2 falsifier (RFC 044):
 *   F-FORGE-B-STAGE2-LARGE — DSM fused FFN (Llama-7B scale) latency ≤ 0.6 × cuBLAS chain
 *   F-FORGE-B-STAGE2-MEDIUM — DSM fused FFN (mid scale) latency ≤ 0.75 × cuBLAS chain
 *   F-FORGE-B-STAGE2-SMALL  — DSM fused FFN (small scale) latency ≤ 0.85 × cuBLAS chain
 *   F-FORGE-B-STAGE2-BITEQ  — fused output bit-equal vs cuBLAS reference
 *
 * SCOPE FOR FIRST FIRE: H100/H200 cluster API verification — NOT perf comparison.
 * Real DSM-fused FFN with cluster::shared cross-block reuse = multi-turn iterative
 * implementation. First fire just proves:
 *   1. Cluster API compiles on sm_90 toolchain
 *   2. cudaLaunchKernelEx with cluster config runs
 *   3. cooperative_groups::cluster_group basic ops work
 *   4. cluster::sync barrier works
 *
 * Subsequent fires (Stage 2 Phase 2) will:
 *   - Split FFN W1 across cluster blocks
 *   - Use cluster.map_shared_rank() to access other blocks' SMEM (true DSM)
 *   - Measure latency vs cuBLAS chain on Llama-7B scale (M=128, D=4096, FD=11008)
 *
 * Reference: FlashFuser (arxiv 2512.12949) — first compiler framework using H100 DSM.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <cooperative_groups.h>

namespace cg = cooperative_groups;

#define CK(call) do { cudaError_t _e = (call); if (_e != cudaSuccess) { fprintf(stderr, "[B2] CUDA %s:%d %s\n", __FILE__, __LINE__, cudaGetErrorString(_e)); exit(1); } } while (0)
#define CB(call) do { cublasStatus_t _s = (call); if (_s != CUBLAS_STATUS_SUCCESS) { fprintf(stderr, "[B2] cuBLAS %s:%d %d\n", __FILE__, __LINE__, (int)_s); exit(1); } } while (0)

static double now_sec(void) {
    struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

/* ========================================================================
 * Cluster API smoke kernel — proves toolchain + API works.
 *
 * Cluster of 2 blocks. Each block writes its block_rank into shared mem,
 * cluster.sync(), then block 0 reads block 1's SMEM via map_shared_rank
 * and writes the joint sum to global output.
 *
 * This is API verification only, NOT a real fused FFN. Once this fires
 * successfully on H100/H200, we extend to the real DSM-fused FFN kernel.
 * ======================================================================== */
__global__ void __cluster_dims__(2, 1, 1)
dsm_smoke_kernel(int* out_block0_sees, int* out_block1_sees, int* out_cluster_size)
{
    cg::cluster_group cluster = cg::this_cluster();
    int block_rank = cluster.block_rank();
    int cluster_size = cluster.num_blocks();

    extern __shared__ int smem[];
    if (threadIdx.x == 0) {
        smem[0] = block_rank * 100 + 7;  /* distinctive marker per block */
    }
    __syncthreads();

    cluster.sync();  /* DSM barrier — both blocks see each other's SMEM */

    /* Block 0 reads block 1's SMEM via cluster.map_shared_rank */
    if (block_rank == 0 && threadIdx.x == 0) {
        int* other_smem = cluster.map_shared_rank(smem, 1);
        out_block0_sees[0] = smem[0];        /* own = 0*100+7 = 7 */
        out_block0_sees[1] = other_smem[0];  /* other = 1*100+7 = 107 */
        out_cluster_size[0] = cluster_size;
    }
    if (block_rank == 1 && threadIdx.x == 0) {
        int* other_smem = cluster.map_shared_rank(smem, 0);
        out_block1_sees[0] = smem[0];        /* own = 1*100+7 = 107 */
        out_block1_sees[1] = other_smem[0];  /* other = 0*100+7 = 7 */
    }
}

/* ========================================================================
 * Reference: cuBLAS FFN chain (matmul → SiLU → matmul), Llama-7B-ish shape.
 * (Same as Stage 1 B baseline, kept here for comparison context.)
 * ======================================================================== */
__global__ void silu_kernel(double* y, const double* x, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = gridDim.x * blockDim.x;
    for (; i < n; i += stride) {
        double v = x[i];
        double sig = 1.0 / (1.0 + exp(-v));
        y[i] = v * sig;
    }
}

static void cublas_ffn_chain(cublasHandle_t h, cudaStream_t st, int M, int D, int FD,
                              const double* dX, const double* dW1, double* dH, double* dH_act,
                              const double* dW2, double* dY) {
    const double alpha = 1.0, beta = 0.0;
    cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, FD, M, D, &alpha, dW1, FD, dX, D, &beta, dH, FD);
    int n_act = M * FD;
    int threads = 256, blocks = (n_act + threads - 1) / threads;
    if (blocks > 65535) blocks = 65535;
    silu_kernel<<<blocks, threads, 0, st>>>(dH_act, dH, n_act);
    cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, D, M, FD, &alpha, dW2, D, dH_act, FD, &beta, dY, D);
}

int main(int argc, char** argv) {
    (void)argc; (void)argv;
    int n_dev = 0; cudaGetDeviceCount(&n_dev);
    if (n_dev <= 0) { fprintf(stderr, "[B2] FATAL: no CUDA device\n"); return 1; }
    int cc_major = 0, cc_minor = 0;
    cudaDeviceGetAttribute(&cc_major, cudaDevAttrComputeCapabilityMajor, 0);
    cudaDeviceGetAttribute(&cc_minor, cudaDevAttrComputeCapabilityMinor, 0);
    char pci[256] = "unknown"; cudaDeviceGetPCIBusId(pci, sizeof(pci), 0);
    fprintf(stderr, "[B2] device 0: pci=%s cc=%d.%d\n", pci, cc_major, cc_minor);

    /* DSM cluster requires sm_90+ */
    int hopper_or_newer = (cc_major >= 9) ? 1 : 0;
    fprintf(stderr, "[B2] Hopper-or-newer (sm_90+): %s\n", hopper_or_newer ? "YES" : "NO — DSM kernels will fail to launch");

    /* ====================================================================
     * SMOKE TEST 1: Cluster API basic operation
     * ==================================================================== */
    fprintf(stderr, "\n[B2] === SMOKE 1: cluster API basic ===\n");
    int *d_block0_sees, *d_block1_sees, *d_cluster_size;
    int h_block0_sees[2] = {0, 0}, h_block1_sees[2] = {0, 0}, h_cluster_size[1] = {0};
    CK(cudaMalloc((void**)&d_block0_sees, 2 * sizeof(int)));
    CK(cudaMalloc((void**)&d_block1_sees, 2 * sizeof(int)));
    CK(cudaMalloc((void**)&d_cluster_size, sizeof(int)));
    CK(cudaMemset(d_block0_sees, 0, 2 * sizeof(int)));
    CK(cudaMemset(d_block1_sees, 0, 2 * sizeof(int)));
    CK(cudaMemset(d_cluster_size, 0, sizeof(int)));

    /* Launch with cluster config */
    cudaLaunchConfig_t config = {0};
    config.gridDim = dim3(2, 1, 1);     /* 2 blocks (matches cluster size) */
    config.blockDim = dim3(32, 1, 1);
    config.dynamicSmemBytes = 256;       /* enough for smoke */
    cudaLaunchAttribute attrs[1] = {0};
    attrs[0].id = cudaLaunchAttributeClusterDimension;
    attrs[0].val.clusterDim.x = 2;
    attrs[0].val.clusterDim.y = 1;
    attrs[0].val.clusterDim.z = 1;
    config.attrs = attrs;
    config.numAttrs = 1;

    cudaError_t launch_err = cudaLaunchKernelEx(&config, dsm_smoke_kernel,
                                                 d_block0_sees, d_block1_sees, d_cluster_size);
    if (launch_err != cudaSuccess) {
        fprintf(stderr, "[B2] SMOKE 1 FAIL: launch err = %s\n", cudaGetErrorString(launch_err));
        return 2;
    }
    CK(cudaDeviceSynchronize());
    CK(cudaMemcpy(h_block0_sees, d_block0_sees, 2 * sizeof(int), cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(h_block1_sees, d_block1_sees, 2 * sizeof(int), cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(h_cluster_size, d_cluster_size, sizeof(int), cudaMemcpyDeviceToHost));

    int smoke1_pass = (h_block0_sees[0] == 7 && h_block0_sees[1] == 107 &&
                       h_block1_sees[0] == 107 && h_block1_sees[1] == 7 &&
                       h_cluster_size[0] == 2) ? 1 : 0;
    fprintf(stderr, "[B2] SMOKE 1 result: block0_sees=[%d,%d] block1_sees=[%d,%d] cluster_size=%d → %s\n",
            h_block0_sees[0], h_block0_sees[1], h_block1_sees[0], h_block1_sees[1], h_cluster_size[0],
            smoke1_pass ? "PASS" : "FAIL");

    cudaFree(d_block0_sees); cudaFree(d_block1_sees); cudaFree(d_cluster_size);

    /* ====================================================================
     * SMOKE TEST 2: cuBLAS FFN chain baseline (Llama-7B-like shape)
     * ==================================================================== */
    fprintf(stderr, "\n[B2] === SMOKE 2: cuBLAS FFN chain baseline (Llama-7B-ish) ===\n");
    cublasHandle_t h; CB(cublasCreate(&h));
    cudaStream_t stream; CK(cudaStreamCreate(&stream));
    CB(cublasSetStream(h, stream));

    int M = 128, D = 4096, FD = 11008;  /* Llama-7B block-ish */
    size_t szX = (size_t)M*D*sizeof(double);
    size_t szW1 = (size_t)D*FD*sizeof(double);
    size_t szH = (size_t)M*FD*sizeof(double);
    size_t szW2 = (size_t)FD*D*sizeof(double);
    size_t szY = szX;

    double *dX, *dW1, *dW2, *dH, *dH_act, *dY;
    CK(cudaMalloc((void**)&dX, szX));
    CK(cudaMalloc((void**)&dW1, szW1));
    CK(cudaMalloc((void**)&dW2, szW2));
    CK(cudaMalloc((void**)&dH, szH));
    CK(cudaMalloc((void**)&dH_act, szH));
    CK(cudaMalloc((void**)&dY, szY));

    /* Fill with deterministic LCG */
    double *hX = (double*)malloc(szX), *hW1 = (double*)malloc(szW1), *hW2 = (double*)malloc(szW2);
    uint64_t st_lcg = 0xb2cafe;
    for (size_t i = 0; i < (size_t)M*D; i++)   hX[i]  = ((double)(st_lcg = st_lcg*6364136223846793005ULL+1) / (double)(1ULL<<60)) - 0.5;
    for (size_t i = 0; i < (size_t)D*FD; i++)  hW1[i] = ((double)(st_lcg = st_lcg*6364136223846793005ULL+1) / (double)(1ULL<<60)) * 0.01;
    for (size_t i = 0; i < (size_t)FD*D; i++)  hW2[i] = ((double)(st_lcg = st_lcg*6364136223846793005ULL+1) / (double)(1ULL<<60)) * 0.01;
    CK(cudaMemcpy(dX, hX, szX, cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dW1, hW1, szW1, cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dW2, hW2, szW2, cudaMemcpyHostToDevice));
    free(hX); free(hW1); free(hW2);

    /* Warmup + measure cuBLAS chain */
    for (int w = 0; w < 3; w++) cublas_ffn_chain(h, stream, M, D, FD, dX, dW1, dH, dH_act, dW2, dY);
    CK(cudaStreamSynchronize(stream));
    int n_iter = 11;
    double tot = 0;
    for (int it = 0; it < n_iter; it++) {
        double t0 = now_sec();
        cublas_ffn_chain(h, stream, M, D, FD, dX, dW1, dH, dH_act, dW2, dY);
        CK(cudaStreamSynchronize(stream));
        tot += (now_sec() - t0) * 1000.0;
    }
    double cublas_ms = tot / n_iter;
    fprintf(stderr, "[B2] cuBLAS FFN chain M=%d D=%d FD=%d avg=%.3f ms\n", M, D, FD, cublas_ms);

    cudaFree(dX); cudaFree(dW1); cudaFree(dW2); cudaFree(dH); cudaFree(dH_act); cudaFree(dY);
    cudaStreamDestroy(stream); cublasDestroy(h);

    /* ====================================================================
     * Result JSON
     * ==================================================================== */
    FILE* jf = fopen("result.json", "w");
    fprintf(jf, "{\n");
    fprintf(jf, "  \"experiment\": \"forge_phaseR_b_stage2_dsm_smoke\",\n");
    fprintf(jf, "  \"date\": \"2026-05-17\",\n");
    fprintf(jf, "  \"device_pci\": \"%s\",\n", pci);
    fprintf(jf, "  \"device_cc\": \"%d.%d\",\n", cc_major, cc_minor);
    fprintf(jf, "  \"hopper_or_newer\": %d,\n", hopper_or_newer);
    fprintf(jf, "  \"smoke1_cluster_api\": {\n");
    fprintf(jf, "    \"block0_sees_own\": %d,\n", h_block0_sees[0]);
    fprintf(jf, "    \"block0_sees_other\": %d,\n", h_block0_sees[1]);
    fprintf(jf, "    \"block1_sees_own\": %d,\n", h_block1_sees[0]);
    fprintf(jf, "    \"block1_sees_other\": %d,\n", h_block1_sees[1]);
    fprintf(jf, "    \"cluster_size_reported\": %d,\n", h_cluster_size[0]);
    fprintf(jf, "    \"pass\": %d\n", smoke1_pass);
    fprintf(jf, "  },\n");
    fprintf(jf, "  \"smoke2_cublas_ffn_baseline\": {\n");
    fprintf(jf, "    \"M\": %d, \"D\": %d, \"FD\": %d,\n", M, D, FD);
    fprintf(jf, "    \"cublas_chain_ms\": %.4f,\n", cublas_ms);
    fprintf(jf, "    \"n_iter\": %d\n", n_iter);
    fprintf(jf, "  },\n");
    fprintf(jf, "  \"summary\": {\n");
    fprintf(jf, "    \"smoke1_cluster_api\": %d,\n", smoke1_pass);
    fprintf(jf, "    \"smoke2_cublas_baseline\": %d,\n", 1);  /* always runs */
    fprintf(jf, "    \"next_step\": \"Real DSM-fused FFN kernel (cluster.map_shared_rank for cross-block SMEM reuse) — Stage 2 Phase 2\"\n");
    fprintf(jf, "  }\n");
    fprintf(jf, "}\n");
    fclose(jf);

    fprintf(stderr, "\n[B2] DONE — SMOKE 1 cluster API: %s · SMOKE 2 cuBLAS baseline: %.3f ms\n",
            smoke1_pass ? "PASS" : "FAIL", cublas_ms);
    return smoke1_pass ? 0 : 3;
}
