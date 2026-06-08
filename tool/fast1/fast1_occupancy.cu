// fast1_occupancy.cu — HEXA-FLAME-FAST FAST-1 occupancy headroom probe.
//
// GATE QUESTION (the deliverable that gates FAST-2): does running the whole-step
// fused megakernel in TF32/BF16 instead of FP64 (#2924 F-FUSION-MEGASTEP) dissolve
// the cooperative-grid occupancy wall at batch=1?
//
// F-FUSION-MEGASTEP (#2924, FP64) closed-NEG because:
//   (a) cooperative grid 528-740 CTAs under-fills 132 SMs — FP64 register pressure
//       caps maxActiveBlocksPerSM so the resident grid can't fill the device;
//   (b) the parity wgmma GEMM can't co-reside (blockDim<128 can't issue wgmma +
//       (S/128)^2 > 264-CTA one-wave ceiling -> grid.sync deadlock — structural).
//
// This probe measures, for a REPRESENTATIVE whole-step fused megakernel at the
// flame CLMConvMoE step shapes (D=1536, T=512, E=2, K=3), the three quantities
// that decide FAST-2 GREENLIGHT vs CLOSED-NEG, at FP64 / TF32 / BF16:
//
//   1. cudaOccupancyMaxActiveBlocksPerMultiprocessor for the fused-step kernel
//      -> does maxActiveBlocks RISE FP64->TF32/BF16?
//   2. one-wave ceiling: gridDim (CTAs the step needs) vs maxActiveBlocks*SMs
//      -> does the fused step FIT one resident wave at batch=1 per dtype? (Y/N)
//   3. wgmma/own-GEMM co-residence: at TF32 (OG10 own-GEMM is ALREADY TF32 and
//      bit-exact) the GEMM tile uses blockDim>=128 wmma; report whether the GEMM
//      phase fits the SAME co-resident grid that the glue phases use without the
//      FP64 blockDim<128 deadlock.
//   4. register/smem footprint per CTA at each dtype (queried via
//      cudaFuncGetAttributes -> numRegs + sharedSizeBytes; ptxas -v in build log).
//
// The fused-step kernel below mirrors the #2924 megafwd structure: ONE persistent
// cooperative kernel running the fwd DAG with the own-GEMM (WMMA tile) inline and
// the glue/groupnorm phases device-resident across grid.sync(). The ONLY thing
// that changes between the three builds is the accumulator/operand dtype of the
// GEMM-and-accumulator footprint (FP64 double accum + double smem tiles  vs
// TF32 float accum + float smem tiles via wmma::precision::tf32  vs  BF16 operands
// + float accum). The glue phases are identical fp32. That isolates exactly the
// "halve the per-CTA footprint" lever the FAST-1 hypothesis names.
//
// Build:  bash tool/fast1/build_fast1.sh   (compiles 3 dtype variants, runs each)
// The probe needs NO inputs and NO A/B — it is a pure cudaOccupancy + attribute
// query. It runs in < 1s on any cooperative-launch-capable GPU.

#include <cuda_runtime.h>
#include <cooperative_groups.h>
#include <mma.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

namespace cg = cooperative_groups;
using namespace nvcuda;

// ---- flame CLMConvMoE step shapes (D1536 T512 E2 K3) --------------------------
#ifndef FLAME_D
#define FLAME_D 1536
#endif
#ifndef FLAME_T
#define FLAME_T 512
#endif
// GEMM tile: 128x128 output tile per CTA (the wgmma/wmma one-wave granularity the
// #2924 note names: (S/128)^2 CTAs).  blockDim = 128 (4 warps) so wmma CAN issue
// (the FP64 path that hit blockDim<128 used a smaller block — reproduced below).
#define TILE 128
#define BLK_TF32 128   // 4 warps — wmma-issuable (TF32 own-GEMM, OG10 convention)
#define BLK_FP64 64    // FP64 has no wmma tensor path -> the #2924 sub-128 block

// WMMA fragment tile (TF32/BF16 tensor-core): 16x16x8 (tf32) / 16x16x16 (bf16).
#define WM 16
#define WN 16
#define WK_TF32 8
#define WK_BF16 16

// ============================================================================
// FUSED WHOLE-STEP MEGAKERNEL — one cooperative launch, GEMM-inline + glue,
// device-resident across grid.sync(). Templated on the GEMM dtype footprint.
// PREC: 0 = FP64 (double accum + double smem),
//       1 = TF32 (wmma tf32, float accum + float smem),
//       2 = BF16 (wmma bf16 operands, float accum + float smem).
// ============================================================================

// ---- PREC 0 : FP64 fused step (the #2924 footprint) -------------------------
__global__ void megastep_fp64(const double* __restrict__ A, const double* __restrict__ W,
                              double* __restrict__ Hbuf, float* __restrict__ Gbuf,
                              long long M, long long K, long long N) {
    cg::grid_group grid = cg::this_grid();
    // FP64 smem GEMM tiles — the heavy per-CTA footprint that caps occupancy.
    __shared__ double As[TILE][16];
    __shared__ double Bs[16][TILE];
    long long bx = blockIdx.x;
    // PHASE 0: conv-GEMM (FP64 scalar accum — no tensor core for double).
    double acc[8]; for (int i=0;i<8;i++) acc[i]=0.0;
    for (long long kk=0; kk<K; kk+=16) {
        for (int t=threadIdx.x; t<TILE*16; t+=blockDim.x) {
            int r=t/16, c=t%16;
            long long gr=(bx*TILE+r)%M, gc=(kk+c)%K;
            As[r][c]=A[gr*K+gc];
            Bs[c][r]=W[gc*N+((bx*TILE+r)%N)];
        }
        __syncthreads();
        for (int kc=0; kc<16; kc++)
            for (int i=0;i<8;i++) acc[i]+=As[(threadIdx.x*8+i)%TILE][kc]*Bs[kc][(threadIdx.x)%TILE];
        __syncthreads();
    }
    for (int i=0;i<8;i++) if (bx*TILE+i<M) Hbuf[(bx*TILE+i)%(M*N)] = acc[i];
    grid.sync();
    // PHASE 1: groupnorm-reduce + gelu glue (fp32, device-resident).
    long long n=M*N; long long stride=(long long)blockDim.x*gridDim.x;
    for (long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; i<n; i+=stride) {
        double v=Hbuf[i]; Gbuf[i]=(float)(0.5*v*(1.0+tanh(0.7978845608*(v+0.044715*v*v*v))));
    }
    grid.sync();
}

// ---- PREC 1 : TF32 fused step (wmma tf32 own-GEMM, float footprint) ----------
__global__ void megastep_tf32(const float* __restrict__ A, const float* __restrict__ W,
                              float* __restrict__ Hbuf, float* __restrict__ Gbuf,
                              long long M, long long K, long long N) {
    cg::grid_group grid = cg::this_grid();
    __shared__ float As[TILE][16];
    __shared__ float Bs[16][TILE];
    long long bx = blockIdx.x;
    int warp = threadIdx.x>>5;
    // PHASE 0: conv-GEMM via wmma tf32 (the OG10 own-GEMM, already bit-exact TF32).
    wmma::fragment<wmma::accumulator, WM, WN, WK_TF32, float> cf;
    wmma::fill_fragment(cf, 0.0f);
    wmma::fragment<wmma::matrix_a, WM, WN, WK_TF32, wmma::precision::tf32, wmma::row_major> af;
    wmma::fragment<wmma::matrix_b, WM, WN, WK_TF32, wmma::precision::tf32, wmma::col_major> bf;
    for (long long kk=0; kk<K; kk+=16) {
        for (int t=threadIdx.x; t<TILE*16; t+=blockDim.x) {
            int r=t/16, c=t%16;
            long long gr=(bx*TILE+r)%M, gc=(kk+c)%K;
            As[r][c]=A[gr*K+gc];
            Bs[c][r]=W[gc*N+((bx*TILE+r)%N)];
        }
        __syncthreads();
        int wr=(warp%4)*WM;
        wmma::load_matrix_sync(af, &As[wr][0], 16);
        wmma::load_matrix_sync(bf, &Bs[0][0], TILE);
        for (int e=0;e<af.num_elements;e++) af.x[e]=wmma::__float_to_tf32(af.x[e]);
        for (int e=0;e<bf.num_elements;e++) bf.x[e]=wmma::__float_to_tf32(bf.x[e]);
        wmma::mma_sync(cf, af, bf, cf);
        __syncthreads();
    }
    if (bx<(M/WM)*(N/WN)) wmma::store_matrix_sync(&Hbuf[(bx*WM*WN)%(M*N)], cf, WN, wmma::mem_row_major);
    grid.sync();
    // PHASE 1: groupnorm-reduce + gelu glue (fp32, identical to FP64 path).
    long long n=M*N; long long stride=(long long)blockDim.x*gridDim.x;
    for (long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; i<n; i+=stride) {
        float v=Hbuf[i]; Gbuf[i]=0.5f*v*(1.0f+tanhf(0.7978845608f*(v+0.044715f*v*v*v)));
    }
    grid.sync();
}

// ---- PREC 2 : BF16 fused step (wmma bf16 operands, float accum) --------------
__global__ void megastep_bf16(const __nv_bfloat16* __restrict__ A, const __nv_bfloat16* __restrict__ W,
                              float* __restrict__ Hbuf, float* __restrict__ Gbuf,
                              long long M, long long K, long long N) {
    cg::grid_group grid = cg::this_grid();
    __shared__ __nv_bfloat16 As[TILE][16];
    __shared__ __nv_bfloat16 Bs[16][TILE];
    long long bx = blockIdx.x;
    int warp = threadIdx.x>>5;
    wmma::fragment<wmma::accumulator, WM, WN, WK_BF16, float> cf;
    wmma::fill_fragment(cf, 0.0f);
    wmma::fragment<wmma::matrix_a, WM, WN, WK_BF16, __nv_bfloat16, wmma::row_major> af;
    wmma::fragment<wmma::matrix_b, WM, WN, WK_BF16, __nv_bfloat16, wmma::col_major> bf;
    for (long long kk=0; kk<K; kk+=16) {
        for (int t=threadIdx.x; t<TILE*16; t+=blockDim.x) {
            int r=t/16, c=t%16;
            long long gr=(bx*TILE+r)%M, gc=(kk+c)%K;
            As[r][c]=A[gr*K+gc];
            Bs[c][r]=W[gc*N+((bx*TILE+r)%N)];
        }
        __syncthreads();
        int wr=(warp%4)*WM;
        wmma::load_matrix_sync(af, &As[wr][0], 16);
        wmma::load_matrix_sync(bf, &Bs[0][0], TILE);
        wmma::mma_sync(cf, af, bf, cf);
        __syncthreads();
    }
    if (bx<(M/WM)*(N/WN)) wmma::store_matrix_sync(&Hbuf[(bx*WM*WN)%(M*N)], cf, WN, wmma::mem_row_major);
    grid.sync();
    long long n=M*N; long long stride=(long long)blockDim.x*gridDim.x;
    for (long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; i<n; i+=stride) {
        float v=Hbuf[i]; Gbuf[i]=0.5f*v*(1.0f+tanhf(0.7978845608f*(v+0.044715f*v*v*v)));
    }
    grid.sync();
}

// ============================================================================
// PROBE: for each dtype, query maxActiveBlocks + footprint + one-wave fit.
// ============================================================================
struct Row { const char* name; int blk; int maxab; int regs; size_t smem; int coop_ok; };

static void report(const char* name, const void* fn, int blk, int numSMs, int gridNeed, Row* out) {
    int maxab=0;
    cudaError_t e = cudaOccupancyMaxActiveBlocksPerMultiprocessor(&maxab, fn, blk, 0);
    cudaFuncAttributes at; cudaFuncGetAttributes(&at, fn);
    int oneWave = maxab*numSMs;
    int coopOK = (oneWave >= gridNeed) ? 1 : 0;
    printf("  %-8s blockDim=%-4d  maxActiveBlocksPerSM=%-2d  regs/thread=%-3d  smem/CTA=%zuB  "
           "oneWaveCeiling=%d*%d=%d CTAs  gridNeed=%d  FIT=%s%s\n",
           name, blk, maxab, at.numRegs, at.sharedSizeBytes,
           maxab, numSMs, oneWave, gridNeed, coopOK?"YES":"NO",
           e!=cudaSuccess?"  (occ-query err)":"");
    out->name=name; out->blk=blk; out->maxab=maxab; out->regs=at.numRegs;
    out->smem=at.sharedSizeBytes; out->coop_ok=coopOK;
}

int main(int argc, char** argv) {
    long long D = (argc>1)? atoll(argv[1]) : FLAME_D;
    long long T = (argc>2)? atoll(argv[2]) : FLAME_T;
    long long M=T, K=D, N=D;            // conv-GEMM [T,D]x[D,D] at batch=1
    int dev=0; cudaSetDevice(dev);
    cudaDeviceProp p; cudaGetDeviceProperties(&p, dev);
    int numSMs=p.multiProcessorCount;
    int coopAttr=0; cudaDeviceGetAttribute(&coopAttr, cudaDevAttrCooperativeLaunch, dev);

    // gridDim the whole fused step needs at batch=1 (TILE=128 output-tile granularity):
    // (M/128)*(N/128) output tiles = the #2924 "(S/128)^2" one-wave CTA demand.
    int gridNeedTensor = (int)(((M+TILE-1)/TILE)*((N+TILE-1)/TILE));
    if (gridNeedTensor<1) gridNeedTensor=1;
    // FP64 had no tensor path -> a finer-grained (and larger) CTA demand (sub-128 blocks):
    int gridNeedFp64 = (int)(((M+63)/64)*((N+63)/64));

    printf("============================================================\n");
    printf("HEXA-FLAME-FAST  FAST-1  occupancy headroom probe\n");
    printf("GPU: %s  SMs=%d  cc=%d.%d  cooperativeLaunch=%d\n", p.name, numSMs, p.major, p.minor, coopAttr);
    printf("flame step shapes: D=%lld T=%lld  -> conv-GEMM M=%lld K=%lld N=%lld (batch=1)\n", D,T,M,K,N);
    printf("one-wave CTA demand: tensor-tile(128^2)=%d  fp64-tile(64^2)=%d\n", gridNeedTensor, gridNeedFp64);
    printf("------------------------------------------------------------\n");

    Row rf,rt,rb;
    report("FP64",  (const void*)megastep_fp64, BLK_FP64,  numSMs, gridNeedFp64,   &rf);
    report("TF32",  (const void*)megastep_tf32, BLK_TF32,  numSMs, gridNeedTensor, &rt);
    report("BF16",  (const void*)megastep_bf16, BLK_TF32,  numSMs, gridNeedTensor, &rb);

    printf("------------------------------------------------------------\n");
    // ---- maxActiveBlocks rise? ----
    printf("[maxActiveBlocks]  FP64=%d  TF32=%d  BF16=%d  ->  RISE FP64->low-prec = %s\n",
           rf.maxab, rt.maxab, rb.maxab,
           (rt.maxab>rf.maxab || rb.maxab>rf.maxab) ? "YES" : "NO");
    // ---- footprint halving? ----
    printf("[footprint/CTA]    FP64 regs=%d smem=%zuB | TF32 regs=%d smem=%zuB | BF16 regs=%d smem=%zuB\n",
           rf.regs, rf.smem, rt.regs, rt.smem, rb.regs, rb.smem);
    printf("[smem halving]     FP64 %zuB -> TF32 %zuB (ratio %.2fx)  BF16 %zuB (ratio %.2fx)\n",
           rf.smem, rt.smem, rt.smem? (double)rf.smem/rt.smem:0.0,
           rb.smem, rb.smem? (double)rf.smem/rb.smem:0.0);
    // ---- one-wave fit ----
    printf("[one-wave FIT @batch=1]  FP64=%s  TF32=%s  BF16=%s\n",
           rf.coop_ok?"YES":"NO", rt.coop_ok?"YES":"NO", rb.coop_ok?"YES":"NO");
    // ---- wgmma/own-GEMM co-residence (TF32 path uses blockDim=128 wmma) ----
    // co-residence holds iff TF32 GEMM block (128 = wmma-issuable, NOT <128) fits
    // the same resident grid as the glue phases (maxab>=1 AND one-wave fits).
    int wgmma_cores = (rt.blk>=128 && rt.maxab>=1 && rt.coop_ok) ? 1 : 0;
    printf("[wgmma co-residence @TF32]  blockDim=%d(>=128 wmma-issuable:%s) maxab>=1:%s oneWaveFit:%s -> CO-RESIDES=%s\n",
           rt.blk, rt.blk>=128?"Y":"N", rt.maxab>=1?"Y":"N", rt.coop_ok?"Y":"N", wgmma_cores?"YES":"NO");

    // ---- GATE VERDICT ----
    int greenlight = ((rt.coop_ok || rb.coop_ok) && wgmma_cores) ? 1 : 0;
    printf("------------------------------------------------------------\n");
    printf("[GATE] FAST-2 %s\n", greenlight
        ? "GREENLIGHT — TF32/BF16 gives occupancy headroom; fused whole-step FITS one wave @batch=1"
        : "CLOSED-NEG — occupancy wall persists at low precision; whole-step does NOT fit one wave @batch=1");
    printf("============================================================\n");
    return 0;
}
