// megakernel_driver.cu — HEXA-FUSION H1b / B1 (research-grade SKELETON).
//
// The option-B device-resident full-step MEGAKERNEL SKELETON for clm_prod.
//
// WHAT THIS IS (scope, honestly):
//   A *skeleton* that runs a SMALL representative sub-chain  GEMM → gelu → GEMM
//   end-to-end inside ONE persistent grid-resident cooperative kernel
//   (cudaLaunchCooperativeKernel + cooperative_groups::grid_group::sync()),
//   demonstrating the DAG-collapse structure the F-FUSION-MEGAKERNEL-DESIGN
//   verdict names as the full unblock:
//     (1) a grid-resident persistent kernel with grid.sync() barriers between
//         the dependent phases (a phase counter implemented by the barrier);
//     (2) inline own-GEMM tiles for the dense GEMMs — the WMMA2 own-GEMM body
//         (_hx_k_sgemm_cm_wmma2 from self/native/hxqwen14b_cuda.cu) reused
//         VERBATIM as a __device__ function so the persistent kernel calls OUR
//         GEMM (cuBLAS could NOT be called from a persistent kernel — this is
//         exactly what own-GEMM #2697/#2704/#2714 unblocked);
//     (3) the glue op (gelu) fused inline BETWEEN the two GEMM phases, its
//         intermediate (the activation H1) kept device-resident across the
//         grid.sync() with no HBM round-trip to the host and no relaunch gap.
//
// WHAT THIS IS NOT:
//   NOT the full ~30-op clm_prod step. NOT a "megakernel done" claim. The
//   sub-chain is the smallest end-to-end witness that the structure runs.
//   The §finding documents exactly what remains for the full step.
//
// CORRECTNESS CONTRACT:
//   Megakernel output is checked vs an EAGER reference that runs the SAME three
//   ops as three separate launches (own-GEMM → gelu → own-GEMM), i.e. the eager
//   own-GEMM path — NOT cuBLAS. Both paths are TF32 own-GEMM, so the bar is
//   rel-RMS <= 3e-3 (the approved TF32 own-GEMM precision contract, identical
//   to cutlass_driver.cu / the E3 perf-gate). If the megakernel and the eager
//   path used the identical accumulation order we would expect max|Δ|=0; the
//   honest bar is rel-RMS because the megakernel's grid-resident tiling MAY
//   schedule the WMMA fragments in a different order than the 3-launch path.
//
// UTIL:
//   With HEXA_CLM_MEGASTEP set we ALSO time/sample both paths on the SAME
//   sub-chain in a sustained loop so an external nvidia-smi sampler (util_run-
//   style) can read whether collapsing the two launch-gaps raises util.
//
// PROBE: prints [MEGASTEP-FIRED] exactly once when the cooperative kernel is
//   actually launched (gated behind a successful cudaLaunchCooperativeKernel).
//
// Build (on the pod):  see build_megastep.sh  (extracts the WMMA2 kernel body
//   from self/native/hxqwen14b_cuda.cu into gemm_kernels_extracted.cuh, then
//   nvcc -O3 -arch=sm_90 -lcublas).
// Run:   ./megakernel_driver [M N K iters]
//   env HEXA_CLM_MEGASTEP=1  → fire the megakernel path + the [FIRED] probe.

#include <cuda_runtime.h>
#include <cooperative_groups.h>
#include <cublas_v2.h>
#include <mma.h>
#include <stdint.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

namespace cg = cooperative_groups;

// cuBLAS handle symbol the extracted fragment's host launchers reference; the
// megakernel itself never touches it (the persistent kernel calls own-GEMM).
static cublasHandle_t g_cublas_handle;

// The own-GEMM kernels (#2697/#2704/#2714), #included VERBATIM from the shipped
// .cu so the measured code IS the shipped code (no copy drift). This brings in
// _hx_k_sgemm_cm_wmma2 + the HXG_* tile defines + the cp.async helpers.
#include "gemm_kernels_extracted.cuh"

// ─────────────────────────────────────────────────────────────────────────────
// Inline own-GEMM tile as a __device__ function.
//
// The WMMA2 own-GEMM body is authored as a __global__ kernel. To call it from
// inside the persistent megakernel we need its body as a __device__ function.
// Rather than duplicate (drift risk), we wrap: a __device__ entry that a single
// thread-block executes for its assigned C-tile, with the SAME body semantics.
//
// SKELETON SIMPLIFICATION (scoped honestly): _hx_k_sgemm_cm_wmma2 assumes a
// 256-thread (8-warp) block laid over a 128×64 C macro-tile, indexed by
// blockIdx/threadIdx. Inside a cooperative grid we keep the IDENTICAL launch
// geometry (256-thread blocks, one 128×64 macro-tile per block) so the WMMA2
// scheduling is byte-for-byte the shipped path; the device wrapper just forwards
// the same (blockIdx, threadIdx) the kernel already reads. We therefore call the
// own-GEMM by giving the megakernel the EXACT SAME grid the standalone WMMA2
// launch would use, and dispatch phase-by-phase via a grid.sync() barrier. The
// own-GEMM math/tiling/accumulation is UNCHANGED.
//
// Because _hx_k_sgemm_cm_wmma2 reads blockIdx.{x,y} directly and our cooperative
// grid is 1-D in blocks, we provide a thin device shim that recomputes the 2-D
// (blockRow, blockCol) the kernel expects from a linear tile id, then inlines
// the same staging+mma+epilogue. To avoid re-deriving 130 lines (drift), we
// instead compile the WMMA2 body ALSO as a __device__ function via a macro that
// renames blockIdx references — see the GEMM_AS_DEVICE include below.
// ─────────────────────────────────────────────────────────────────────────────

// We re-include the WMMA2 body a second time, this time textually transformed
// into a __device__ function `wmma2_tile_device(tileRow, tileCol, ...)` that
// takes the (tileRow,tileCol) macro-tile coordinate explicitly instead of
// reading blockIdx. The transform is mechanical (build_megastep.sh emits
// gemm_device_extracted.cuh). This keeps the GEMM math identical to the shipped
// __global__ while making it callable from the persistent kernel.
#include "gemm_device_extracted.cuh"

// ─────────────────────────────────────────────────────────────────────────────
// gelu device op — byte-faithful to _hx_k_gelu (runtime_cuda.c): erf-based,
// out[i] = x * 0.5 * (1 + erf(x / sqrt2)). Authored fp32 here (own-GEMM TF32
// regime); the eager reference uses the SAME fp32 erf so the gelu step itself
// is identical between paths (the only rel-RMS source is the GEMM tiling).
// ─────────────────────────────────────────────────────────────────────────────
__device__ __forceinline__ float megastep_gelu(float x) {
    const float inv_sqrt2 = 0.70710678118654752440f;
    float cdf = 0.5f * (1.0f + erff(x * inv_sqrt2));
    return x * cdf;
}

// Standalone eager gelu kernel (the reference path's middle launch).
__global__ void eager_gelu_k(const float* __restrict__ IN, float* __restrict__ OUT, long long n) {
    long long stride = (long long)blockDim.x * gridDim.x;
    for (long long i = (long long)blockIdx.x * blockDim.x + threadIdx.x; i < n; i += stride)
        OUT[i] = megastep_gelu(IN[i]);
}

// ─────────────────────────────────────────────────────────────────────────────
// THE MEGAKERNEL — _hx_k_clm_megastep
//
// One persistent grid-resident cooperative kernel running the sub-chain:
//   PHASE 0:  H1 = GEMM(A, W1)        (own-GEMM WMMA2, M×N1, K=K)
//   --- grid.sync() ---               (H1 must be globally complete)
//   PHASE 1:  G  = gelu(H1)           (elementwise, fused inline)
//   --- grid.sync() ---               (G must be globally complete)
//   PHASE 2:  C  = GEMM(G, W2)        (own-GEMM WMMA2, M×N2, K=N1)
//
// The phase counter IS the grid.sync() barrier: every block executes phase k,
// hits the barrier, then proceeds to phase k+1 only when the whole grid has
// finished phase k's writes. Intermediates H1 and G live in global device
// memory (scratch) — NOT host round-tripped, NOT relaunched. A future revision
// keeps H1/G in shared where a tile fits; the skeleton keeps them in device
// scratch (a 128×64 tile per block fits, but the cross-phase GEMM reindexes
// tiles, so global scratch is the correct skeleton choice — see §finding).
//
// GRID GEOMETRY: the cooperative grid is sized so EVERY macro-tile of the
// LARGER of the two GEMMs has a resident block (cooperative launch requires the
// whole grid to be co-resident). Each block, in each GEMM phase, computes the
// macro-tile(s) it owns; in the gelu phase it strides over its share of H1.
// ─────────────────────────────────────────────────────────────────────────────
__global__ void _hx_k_clm_megastep(
        long long M, long long K, long long N1, long long N2,
        const float* __restrict__ A,    // M×K   (col-major)
        const float* __restrict__ W1,   // K×N1
        const float* __restrict__ W2,   // N1×N2
        float* __restrict__ H1,         // scratch M×N1 (GEMM1 out)
        float* __restrict__ G,          // scratch M×N1 (gelu out)
        float* __restrict__ Cout,       // M×N2  (final)
        int* __restrict__ fired_flag) { // probe: set to 1 once by block 0 lane 0
    cg::grid_group grid = cg::this_grid();
    const int tid = threadIdx.x;

    // Probe: the FIRST resident block/thread marks the megakernel as fired.
    if (blockIdx.x == 0 && tid == 0) *fired_flag = 1;

    // ── PHASE 0: H1 = A · W1  (own-GEMM WMMA2, inline) ──────────────────────
    // Macro-tile grid for GEMM1: ceil(M/BM) × ceil(N1/BN). We map this block's
    // linear id onto the 2-D tile grid; blocks beyond the tile count idle this
    // phase (still resident for the barrier).
    {
        long long tilesM = (M  + HXG_BM - 1) / HXG_BM;
        long long tilesN = (N1 + HXG_BN - 1) / HXG_BN;
        long long nTiles = tilesM * tilesN;
        for (long long t = blockIdx.x; t < nTiles; t += gridDim.x) {
            long long tr = t / tilesN, tc = t % tilesN;
            wmma2_tile_device(tr, tc, 0, 0, M, N1, K, 1.0f, A, M, W1, K, 0.0f, H1, M);
        }
    }
    grid.sync();

    // ── PHASE 1: G = gelu(H1)  (elementwise, fused inline) ──────────────────
    {
        long long n = M * N1;
        long long stride = (long long)blockDim.x * gridDim.x;
        for (long long i = (long long)blockIdx.x * blockDim.x + tid; i < n; i += stride)
            G[i] = megastep_gelu(H1[i]);
    }
    grid.sync();

    // ── PHASE 2: Cout = G · W2  (own-GEMM WMMA2, inline) ────────────────────
    {
        long long tilesM = (M  + HXG_BM - 1) / HXG_BM;
        long long tilesN = (N2 + HXG_BN - 1) / HXG_BN;
        long long nTiles = tilesM * tilesN;
        for (long long t = blockIdx.x; t < nTiles; t += gridDim.x) {
            long long tr = t / tilesN, tc = t % tilesN;
            wmma2_tile_device(tr, tc, 0, 0, M, N2, N1, 1.0f, G, M, W2, N1, 0.0f, Cout, M);
        }
    }
    // no trailing barrier needed; Cout is the kernel output.
}

// ─────────────────────────────────────────────────────────────────────────────
// helpers
// ─────────────────────────────────────────────────────────────────────────────
static double rel_rms(const float* ref, const float* got, long long n) {
    double se = 0.0, sr = 0.0;
    for (long long i = 0; i < n; i++) {
        double d = (double)got[i] - (double)ref[i];
        se += d*d; sr += (double)ref[i]*(double)ref[i];
    }
    return sqrt(se / (sr > 0 ? sr : 1.0));
}
static double max_abs_diff(const float* ref, const float* got, long long n) {
    double mx = 0.0;
    for (long long i = 0; i < n; i++) { double d = fabs((double)got[i]-(double)ref[i]); if (d>mx) mx=d; }
    return mx;
}

// Run the EAGER reference: three separate own-GEMM/gelu launches.
static void eager_subchain(long long M, long long K, long long N1, long long N2,
                           const float* dA, const float* dW1, const float* dW2,
                           float* dH1, float* dG, float* dC) {
    float alpha=1.0f, beta=0.0f;
    // GEMM1: H1 = A·W1
    dim3 g1blk(256), g1grd((unsigned)((M+HXG_BM-1)/HXG_BM),(unsigned)((N1+HXG_BN-1)/HXG_BN));
    _hx_k_sgemm_cm_wmma2<<<g1grd,g1blk>>>(0,0,M,N1,K, alpha, dA,M, dW1,K, beta, dH1,M);
    // gelu: G = gelu(H1)
    long long n1 = M*N1;
    int gblk=256; int ggrd=(int)((n1+gblk-1)/gblk); if(ggrd>65535) ggrd=65535;
    eager_gelu_k<<<ggrd,gblk>>>(dH1,dG,n1);
    // GEMM2: C = G·W2
    dim3 g2blk(256), g2grd((unsigned)((M+HXG_BM-1)/HXG_BM),(unsigned)((N2+HXG_BN-1)/HXG_BN));
    _hx_k_sgemm_cm_wmma2<<<g2grd,g2blk>>>(0,0,M,N2,N1, alpha, dG,M, dW2,N1, beta, dC,M);
}

int main(int argc, char** argv) {
    long long M = 1024, K = 1536, N1 = 1536, N2 = 1024; int iters = 50;
    // sub-chain dims chosen to resemble a clm_prod conv-block: D=1536-ish hidden.
    if (argc >= 5) { M = atoll(argv[1]); K = atoll(argv[2]); N1 = atoll(argv[3]); N2 = atoll(argv[4]); }
    if (argc >= 6) iters = atoi(argv[5]);
    const char* mega_env = getenv("HEXA_CLM_MEGASTEP");
    int mega_on = (mega_env && mega_env[0] && strcmp(mega_env,"0"));
    const char* loop_env = getenv("MEGASTEP_LOOP");  // "eager" | "mega" → sustained single-path loop for external util sampler

    cublasCreate(&g_cublas_handle);
    cublasSetMathMode(g_cublas_handle, CUBLAS_TF32_TENSOR_OP_MATH);

    int dev; cudaGetDevice(&dev); cudaDeviceProp p; cudaGetDeviceProperties(&p,dev);

    long long szA=M*K, szW1=K*N1, szW2=N1*N2, szH1=M*N1, szC=M*N2;
    float *hA=(float*)malloc(szA*4), *hW1=(float*)malloc(szW1*4), *hW2=(float*)malloc(szW2*4);
    float *hRef=(float*)malloc(szC*4), *hGot=(float*)malloc(szC*4);
    srand(1234);
    for (long long i=0;i<szA;i++)  hA[i]  = (float)(rand()%2001-1000)/1000.0f;
    for (long long i=0;i<szW1;i++) hW1[i] = (float)(rand()%2001-1000)/1000.0f;
    for (long long i=0;i<szW2;i++) hW2[i] = (float)(rand()%2001-1000)/1000.0f;

    float *dA,*dW1,*dW2,*dH1,*dG,*dC,*dC2;
    cudaMalloc(&dA,szA*4); cudaMalloc(&dW1,szW1*4); cudaMalloc(&dW2,szW2*4);
    cudaMalloc(&dH1,szH1*4); cudaMalloc(&dG,szH1*4); cudaMalloc(&dC,szC*4); cudaMalloc(&dC2,szC*4);
    cudaMemcpy(dA,hA,szA*4,cudaMemcpyHostToDevice);
    cudaMemcpy(dW1,hW1,szW1*4,cudaMemcpyHostToDevice);
    cudaMemcpy(dW2,hW2,szW2*4,cudaMemcpyHostToDevice);
    int* dFired; cudaMalloc(&dFired,sizeof(int)); cudaMemset(dFired,0,sizeof(int));

    printf("GPU: %s (sm_%d%d)\n", p.name, p.major, p.minor);
    printf("sub-chain: GEMM(M=%lld,N1=%lld,K=%lld) -> gelu -> GEMM(M=%lld,N2=%lld,K=N1=%lld)  iters=%d\n",
           M,N1,K, M,N2,N1, iters);
    printf("HEXA_CLM_MEGASTEP=%s\n", mega_on?"1 (megakernel path ON)":"0 (eager only)");

    // ── 0) sustained single-path loop for the external nvidia-smi util sampler.
    //    MEGASTEP_LOOP=eager → loop the 3-launch eager sub-chain ~15s.
    //    MEGASTEP_LOOP=mega  → loop the 1-coop megakernel sub-chain ~15s.
    if (loop_env && loop_env[0]) {
        double secs = 15.0;
        struct timespec t0,t1; long it=0;
        int isMega = !strcmp(loop_env,"mega");
        dim3 grid, block(256); void* kargs[11];
        if (isMega) {
            int nbps=0; cudaOccupancyMaxActiveBlocksPerMultiprocessor(&nbps,_hx_k_clm_megastep,256,0);
            int gb=nbps*p.multiProcessorCount; if (gb<1) { printf("[MEGASTEP-BLOCKED] coop occ=0\n"); return 3; }
            grid=dim3(gb);
            kargs[0]=&M;kargs[1]=&K;kargs[2]=&N1;kargs[3]=&N2;kargs[4]=&dA;kargs[5]=&dW1;kargs[6]=&dW2;
            kargs[7]=&dH1;kargs[8]=&dG;kargs[9]=&dC2;kargs[10]=&dFired;
        }
        clock_gettime(CLOCK_MONOTONIC,&t0);
        for(;;){
            if (isMega) cudaLaunchCooperativeKernel((void*)_hx_k_clm_megastep,grid,block,kargs,0,0);
            else        eager_subchain(M,K,N1,N2,dA,dW1,dW2,dH1,dG,dC);
            if(((++it)&15)==0){ cudaDeviceSynchronize(); clock_gettime(CLOCK_MONOTONIC,&t1);
                double el=(t1.tv_sec-t0.tv_sec)+(t1.tv_nsec-t0.tv_nsec)/1e9; if(el>=secs) break; }
        }
        cudaDeviceSynchronize();
        printf("MEGASTEP_LOOP=%s: %ld iters\n", loop_env, it);
        return 0;
    }

    // ── 1) EAGER reference (3 launches) ──────────────────────────────────────
    eager_subchain(M,K,N1,N2, dA,dW1,dW2, dH1,dG,dC);
    cudaError_t er = cudaDeviceSynchronize();
    if (er != cudaSuccess) { printf("EAGER launch error: %s\n", cudaGetErrorString(er)); return 2; }
    cudaMemcpy(hRef,dC,szC*4,cudaMemcpyDeviceToHost);

    // ── 2) MEGAKERNEL (1 cooperative launch) ─────────────────────────────────
    int mega_ok = 0; double rms = -1, mad = -1;
    if (mega_on) {
        // Cooperative-launch occupancy: how many blocks of 256 threads can be
        // co-resident? cudaLaunchCooperativeKernel requires the WHOLE grid to
        // fit. We query max active blocks/SM for the megakernel and cap the grid.
        int numBlocksPerSm = 0;
        cudaError_t oce = cudaOccupancyMaxActiveBlocksPerMultiprocessor(
            &numBlocksPerSm, _hx_k_clm_megastep, 256, 0);
        int grid_blocks = numBlocksPerSm * p.multiProcessorCount;
        printf("coop occupancy: %d blocks/SM × %d SM = %d resident blocks (occ query: %s)\n",
               numBlocksPerSm, p.multiProcessorCount, grid_blocks, cudaGetErrorString(oce));
        if (grid_blocks < 1) {
            printf("[MEGASTEP-BLOCKED] cooperative occupancy = 0 (register/smem budget over-subscribed); "
                   "the persistent grid cannot be co-resident → SKELETON BLOCKED at launch.\n");
        } else {
            cudaMemset(dC2,0,szC*4); cudaMemset(dFired,0,sizeof(int));
            void* kargs[] = { &M,&K,&N1,&N2, &dA,&dW1,&dW2, &dH1,&dG,&dC2, &dFired };
            dim3 grid(grid_blocks), block(256);
            cudaError_t le = cudaLaunchCooperativeKernel(
                (void*)_hx_k_clm_megastep, grid, block, kargs, 0, 0);
            if (le != cudaSuccess) {
                printf("[MEGASTEP-BLOCKED] cudaLaunchCooperativeKernel failed: %s\n", cudaGetErrorString(le));
            } else {
                cudaError_t se = cudaDeviceSynchronize();
                if (se != cudaSuccess) {
                    printf("[MEGASTEP-BLOCKED] megakernel runtime error: %s\n", cudaGetErrorString(se));
                } else {
                    int firedHost = 0; cudaMemcpy(&firedHost,dFired,sizeof(int),cudaMemcpyDeviceToHost);
                    if (firedHost) printf("[MEGASTEP-FIRED]\n");
                    cudaMemcpy(hGot,dC2,szC*4,cudaMemcpyDeviceToHost);
                    rms = rel_rms(hRef,hGot,szC); mad = max_abs_diff(hRef,hGot,szC);
                    mega_ok = 1;
                }
            }
        }
    }

    // ── 3) correctness verdict ───────────────────────────────────────────────
    if (mega_ok) {
        printf("\ncorrectness (megakernel vs eager own-GEMM sub-chain):\n");
        printf("  rel-RMS  = %.3e  %s  (TF32 own-GEMM bar <= 3e-3)\n", rms, rms<=3e-3?"PASS":"FAIL");
        printf("  max|Δ|   = %.3e\n", mad);
    }

    // ── 4) util A/B on the SAME sub-chain (sustained loop) ───────────────────
    if (mega_on && mega_ok) {
        double secs = 12.0;
        cudaEvent_t e0,e1; cudaEventCreate(&e0); cudaEventCreate(&e1);
        // eager timing
        struct timespec t0,t1; long itE=0;
        clock_gettime(CLOCK_MONOTONIC,&t0);
        for(;;){ eager_subchain(M,K,N1,N2,dA,dW1,dW2,dH1,dG,dC);
                 if(((++itE)&15)==0){ cudaDeviceSynchronize(); clock_gettime(CLOCK_MONOTONIC,&t1);
                   double el=(t1.tv_sec-t0.tv_sec)+(t1.tv_nsec-t0.tv_nsec)/1e9; if(el>=secs) break; } }
        cudaDeviceSynchronize(); clock_gettime(CLOCK_MONOTONIC,&t1);
        double elE=(t1.tv_sec-t0.tv_sec)+(t1.tv_nsec-t0.tv_nsec)/1e9;
        // megakernel timing
        int numBlocksPerSm=0; cudaOccupancyMaxActiveBlocksPerMultiprocessor(&numBlocksPerSm,_hx_k_clm_megastep,256,0);
        int grid_blocks=numBlocksPerSm*p.multiProcessorCount;
        dim3 grid(grid_blocks), block(256);
        void* kargs[]={ &M,&K,&N1,&N2, &dA,&dW1,&dW2, &dH1,&dG,&dC2, &dFired };
        long itM=0; clock_gettime(CLOCK_MONOTONIC,&t0);
        for(;;){ cudaLaunchCooperativeKernel((void*)_hx_k_clm_megastep,grid,block,kargs,0,0);
                 if(((++itM)&15)==0){ cudaDeviceSynchronize(); clock_gettime(CLOCK_MONOTONIC,&t1);
                   double el=(t1.tv_sec-t0.tv_sec)+(t1.tv_nsec-t0.tv_nsec)/1e9; if(el>=secs) break; } }
        cudaDeviceSynchronize(); clock_gettime(CLOCK_MONOTONIC,&t1);
        double elM=(t1.tv_sec-t0.tv_sec)+(t1.tv_nsec-t0.tv_nsec)/1e9;
        printf("\nsustained throughput on the SAME sub-chain (%.0fs each):\n", secs);
        printf("  eager (3 launches)   : %ld iters  (%.1f sub-chains/s)\n", itE, itE/elE);
        printf("  megakernel (1 coop)  : %ld iters  (%.1f sub-chains/s)\n", itM, itM/elM);
        printf("  -> for util MEAN run util_megastep.sh (external nvidia-smi sampler).\n");
    }

    cudaFree(dA);cudaFree(dW1);cudaFree(dW2);cudaFree(dH1);cudaFree(dG);cudaFree(dC);cudaFree(dC2);cudaFree(dFired);
    free(hA);free(hW1);free(hW2);free(hRef);free(hGot);
    return mega_on ? (mega_ok ? 0 : 3) : 0;
}
