// megafwd_driver.cu — HEXA-FUSION B2 (research, util-GREEN north-star).
//
// Extends the H1b megakernel SKELETON (#2735, megakernel_driver.cu, the GEMM->
// gelu->GEMM witness) to the FULL clm_prod FORWARD step chained into ONE
// cooperative launch — the regime where the gap-collapse util win materializes.
//
// WHY (from landed findings):
//   H1a (#2734) proved the GEMMs SATURATE the H100 at all D -> the ~13% clm_prod
//   util is NOT size/GEMM, it is the SERIAL per-kernel-sync DAG of sub-ms glue
//   kernels (median util 2%, F-FUSION-OCCUPANCY-WALL).
//   H1b (#2735) proved the cooperative-launch persistent megakernel runs BYTE-
//   EXACT (rel-RMS 0.000, own-GEMM #2704 inline, grid.sync between phases, 132
//   SM co-resident, no register/smem wall) AND that gap-collapse WINS in the
//   small-kernel regime (small-shape mega > eager) — but the GEMM-pair witness
//   was too SATURATED to show it.
//   The FULL fwd step has the sub-ms glue (the gap-collapse target). So extending
//   the skeleton to the full fwd is the decisive util-GREEN experiment.
//
// WHAT THIS CHAINS (the clm_prod fwd DAG, in ONE cooperative launch):
//   PHASE 0  H1 = A · W1                     (conv GEMM1, own-GEMM WMMA2 inline)
//   --- grid.sync ---
//   PHASE 1a per-row partial sums of H1      (groupnorm reduction, pass 1)
//   --- grid.sync ---  (the cross-block reduction the design names as the unblock)
//   PHASE 1b N = groupnorm(H1) [mean/var]    (normalize using the reduced stats)
//   --- grid.sync ---
//   PHASE 1c E = gelu(N)                      (glue block-1, elementwise)
//   PHASE 1d R = E + H1  (residual add)       (fused into 1c — same tile)
//   --- grid.sync ---
//   PHASE 2  H2 = R · W2                      (conv GEMM2, own-GEMM WMMA2 inline)
//   --- grid.sync ---
//   PHASE 3a G2 = gelu(H2)                    (glue block-2, gelu2)
//   PHASE 3b P  = expert_pack(G2)             (per-row gated pack, elementwise)
//   --- grid.sync ---
//   PHASE 3c per-row max+sumexp of P          (moe_router softmax reduction, pass 1)
//   --- grid.sync ---
//   PHASE 3d Rt = softmax(P)                  (moe_router, normalize) -> FINAL out
//
//   Intermediates (H1, N, R, H2, G2, P, stats) stay DEVICE-RESIDENT across the
//   grid.sync() barriers — NO HBM-to-host round-trip, NO relaunch gap. This is
//   the entire fwd: 2 conv GEMMs + glue block-1 (groupnorm->gelu->residual) +
//   glue block-2 (gelu2->expert_pack->moe_router). 11 logical phases, 8 barriers.
//
// CORRECTNESS CONTRACT (HARD g5 gate):
//   The megakernel out (Rt) is checked vs an EAGER reference that runs the SAME
//   ops as SEPARATE launches (own-GEMM -> gn-reduce -> gn-norm -> gelu+resid ->
//   own-GEMM -> gelu2+pack -> router-reduce -> softmax). BOTH paths use the
//   identical own-GEMM TF32 kernel and identical fp32 glue, so the bar is the
//   approved TF32 own-GEMM rel-RMS <= 3e-3. (If the WMMA fragment schedule
//   matches we expect byte-exact; rel-RMS is the honest bar because the
//   cooperative strided-tile visitation MAY reorder fragments.)
//
// PROBE: prints [MEGAFWD-FIRED] exactly once when the cooperative full-fwd
//   kernel is actually launched (env HEXA_CLM_MEGASTEP=1, same gate, extended).
//
// BUDGET WALL (honest, the megakernel's hard structural limit):
//   cudaLaunchCooperativeKernel requires the WHOLE grid co-resident. We query
//   cudaOccupancyMaxActiveBlocksPerMultiprocessor for the full-fwd kernel: if
//   adding the extra phases' register/smem drops occupancy below 1 block/SM the
//   grid cannot be co-resident -> we report [MEGAFWD-BLOCKED] + the budget wall
//   and (a documented limit is a valid result) note the largest prefix that fit.
//
// Build (on the pod):  bash build_megafwd.sh
// Run:  ./megafwd_driver [M K N1 N2 iters]
//   env HEXA_CLM_MEGASTEP=1 -> fire the megafwd path + [MEGAFWD-FIRED] probe.

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

static cublasHandle_t g_cublas_handle;  // referenced by extracted launchers; megakernel never uses it

#include "gemm_kernels_extracted.cuh"   // own-GEMM #2697/#2704/#2714 verbatim
#include "gemm_device_extracted.cuh"    // wmma2_tile_device(): the WMMA2 body as a __device__ fn

// ─────────────────────────────────────────────────────────────────────────────
// glue device ops — fp32, byte-faithful to the runtime glue kernels.
// gelu: erf-based, out = x*0.5*(1+erf(x/sqrt2)). Eager uses the SAME fp32 erf so
// the glue itself is identical between paths (only GEMM tiling can perturb rms).
// ─────────────────────────────────────────────────────────────────────────────
__device__ __forceinline__ float megastep_gelu(float x) {
    const float inv_sqrt2 = 0.70710678118654752440f;
    return x * 0.5f * (1.0f + erff(x * inv_sqrt2));
}
// expert_pack: a per-element gated pack standing in for the MoE expert combine —
// a deterministic gate*value the eager path mirrors exactly. (silu-gate form.)
__device__ __forceinline__ float megastep_expack(float x) {
    float g = 1.0f / (1.0f + expf(-x));   // sigmoid gate
    return x * g;                          // gated value (silu) — deterministic, byte-mirrorable
}

// groupnorm constants: one "group" = the full row (M rows of width D=N1), eps 1e-5.
#define MEGAFWD_EPS 1e-5f

// Block (256-thread) reductions via WARP-SHUFFLE + an 8-float staging array.
// This replaces the 256-float __shared__ reduction buffers the naive form would
// use — CRITICAL on sm_100 (B200): the megafwd already spends the full 49152 B
// static-smem cap on the inline WMMA2 GEMM (As/Bs/tmp). Any extra 2-4 KB static
// reduction buffer overflows the per-block static cap. Shuffle needs only 32 B.
// Math is the SAME tree-sum/tree-max (associativity-identical to the eager
// gn_reduce_k/router_reduce_k block reductions for these row widths).
__device__ __forceinline__ float blk_sum256(float v, float* sh /*[8]*/) {
    for (int o=16;o>0;o>>=1) v += __shfl_down_sync(0xffffffff,v,o);
    int lane=threadIdx.x&31, warp=threadIdx.x>>5;
    if (lane==0) sh[warp]=v; __syncthreads();
    float r = (threadIdx.x<8) ? sh[threadIdx.x] : 0.f;
    if (warp==0){ for(int o=4;o>0;o>>=1) r += __shfl_down_sync(0x000000ff,r,o); if(lane==0) sh[0]=r; }
    __syncthreads(); return sh[0];
}
__device__ __forceinline__ float blk_max256(float v, float* sh /*[8]*/) {
    for (int o=16;o>0;o>>=1){ float t=__shfl_down_sync(0xffffffff,v,o); if(t>v)v=t; }
    int lane=threadIdx.x&31, warp=threadIdx.x>>5;
    if (lane==0) sh[warp]=v; __syncthreads();
    float r = (threadIdx.x<8) ? sh[threadIdx.x] : -1e30f;
    if (warp==0){ for(int o=4;o>0;o>>=1){ float t=__shfl_down_sync(0x000000ff,r,o); if(t>r)r=t; } if(lane==0) sh[0]=r; }
    __syncthreads(); return sh[0];
}

// ─────────────────────────────────────────────────────────────────────────────
// EAGER reference kernels (each is a SEPARATE launch in the eager path).
// ─────────────────────────────────────────────────────────────────────────────
// col-major M×N: element (r,c) at index r + c*M. Row r is a strided gather.
// groupnorm pass1: per-row sum and sumsq over the N columns (the cross-"block"
// reduction). One block per row; block-stride over columns; block-reduce.
__global__ void gn_reduce_k(const float* __restrict__ X, long long M, long long N,
                            float* __restrict__ rowMean, float* __restrict__ rowVar) {
    long long r = blockIdx.x;
    if (r >= M) return;
    __shared__ float ssum[256]; __shared__ float ssq[256];
    float s=0.f, sq=0.f;
    for (long long c = threadIdx.x; c < N; c += blockDim.x) {
        float v = X[r + c*M]; s += v; sq += v*v;
    }
    ssum[threadIdx.x]=s; ssq[threadIdx.x]=sq; __syncthreads();
    for (int off=blockDim.x>>1; off>0; off>>=1) {
        if (threadIdx.x<off){ ssum[threadIdx.x]+=ssum[threadIdx.x+off]; ssq[threadIdx.x]+=ssq[threadIdx.x+off]; }
        __syncthreads();
    }
    if (threadIdx.x==0){ float mean=ssum[0]/(float)N; float var=ssq[0]/(float)N - mean*mean;
                         rowMean[r]=mean; rowVar[r]=var; }
}
// groupnorm pass2: normalize using the row stats.
__global__ void gn_norm_k(const float* __restrict__ X, long long M, long long N,
                          const float* __restrict__ rowMean, const float* __restrict__ rowVar,
                          float* __restrict__ OUT) {
    long long n = M*N; long long stride=(long long)blockDim.x*gridDim.x;
    for (long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; i<n; i+=stride) {
        long long r = i % M;          // col-major: row index is i mod M
        float inv = rsqrtf(rowVar[r] + MEGAFWD_EPS);
        OUT[i] = (X[i]-rowMean[r])*inv;
    }
}
// glue block-1 tail: E = gelu(N); R = E + H1  (residual). fused in one launch.
__global__ void gelu_resid_k(const float* __restrict__ Nrm, const float* __restrict__ H1,
                             float* __restrict__ R, long long n) {
    long long stride=(long long)blockDim.x*gridDim.x;
    for (long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; i<n; i+=stride)
        R[i] = megastep_gelu(Nrm[i]) + H1[i];
}
// glue block-2 head: G2=gelu(H2); P=expert_pack(G2). fused in one launch.
__global__ void gelu2_pack_k(const float* __restrict__ H2, float* __restrict__ P, long long n) {
    long long stride=(long long)blockDim.x*gridDim.x;
    for (long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; i<n; i+=stride)
        P[i] = megastep_expack(megastep_gelu(H2[i]));
}
// moe_router pass1: per-row max + sumexp over the N2 cols (softmax reduction).
__global__ void router_reduce_k(const float* __restrict__ P, long long M, long long N,
                                float* __restrict__ rowMax, float* __restrict__ rowSum) {
    long long r = blockIdx.x; if (r>=M) return;
    __shared__ float smax[256]; __shared__ float ssum[256];
    float mx=-1e30f;
    for (long long c=threadIdx.x; c<N; c+=blockDim.x){ float v=P[r+c*M]; if(v>mx)mx=v; }
    smax[threadIdx.x]=mx; __syncthreads();
    for (int off=blockDim.x>>1; off>0; off>>=1){ if(threadIdx.x<off){ if(smax[threadIdx.x+off]>smax[threadIdx.x])smax[threadIdx.x]=smax[threadIdx.x+off]; } __syncthreads(); }
    float rmax=smax[0]; __syncthreads();
    float se=0.f;
    for (long long c=threadIdx.x; c<N; c+=blockDim.x) se += expf(P[r+c*M]-rmax);
    ssum[threadIdx.x]=se; __syncthreads();
    for (int off=blockDim.x>>1; off>0; off>>=1){ if(threadIdx.x<off) ssum[threadIdx.x]+=ssum[threadIdx.x+off]; __syncthreads(); }
    if (threadIdx.x==0){ rowMax[r]=rmax; rowSum[r]=ssum[0]; }
}
// moe_router pass2: softmax normalize -> final out.
__global__ void router_norm_k(const float* __restrict__ P, long long M, long long N,
                              const float* __restrict__ rowMax, const float* __restrict__ rowSum,
                              float* __restrict__ OUT) {
    long long n=M*N; long long stride=(long long)blockDim.x*gridDim.x;
    for (long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; i<n; i+=stride){
        long long r=i%M; OUT[i]=expf(P[i]-rowMax[r])/rowSum[r];
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// THE FULL-FWD MEGAKERNEL — _hx_k_clm_megafwd
//
// One persistent grid-resident cooperative kernel running the WHOLE fwd DAG.
// Every block executes phase k, hits grid.sync(), proceeds to k+1 only when the
// whole grid finished phase k. Intermediates live in device scratch (cross-phase
// GEMM reindexes tiles -> global scratch is the correct skeleton choice).
//
// The groupnorm + moe_router reductions are CROSS-BLOCK: pass-1 writes per-row
// stats to global, a grid.sync() makes them globally visible, pass-2 reads them.
// This is exactly the cross-block reduction the megakernel design names as the
// unblock — realized with the SAME grid.sync() the GEMM phases use.
// ─────────────────────────────────────────────────────────────────────────────
__global__ void _hx_k_clm_megafwd(
        long long M, long long K, long long N1, long long N2,
        const float* __restrict__ A,    // M×K
        const float* __restrict__ W1,   // K×N1
        const float* __restrict__ W2,   // N1×N2
        float* __restrict__ H1,         // scratch M×N1  (GEMM1 out)
        float* __restrict__ Nrm,        // scratch M×N1  (groupnorm out)
        float* __restrict__ R,          // scratch M×N1  (gelu+residual out)
        float* __restrict__ H2,         // scratch M×N2  (GEMM2 out)
        float* __restrict__ P,          // scratch M×N2  (gelu2+pack out)
        float* __restrict__ Rt,         // M×N2  (router/softmax final)
        float* __restrict__ rowMean,    // M
        float* __restrict__ rowVar,     // M
        float* __restrict__ rowMax,     // M
        float* __restrict__ rowSum,     // M
        int* __restrict__ fired_flag) {
    cg::grid_group grid = cg::this_grid();
    const int tid = threadIdx.x;
    if (blockIdx.x == 0 && tid == 0) *fired_flag = 1;

    // ── PHASE 0: H1 = A · W1  (conv GEMM1, own-GEMM inline) ─────────────────
    {
        long long tM=(M+HXG_BM-1)/HXG_BM, tN=(N1+HXG_BN-1)/HXG_BN, nT=tM*tN;
        for (long long t=blockIdx.x; t<nT; t+=gridDim.x)
            wmma2_tile_device(t/tN, t%tN, 0,0, M,N1,K, 1.0f, A,M, W1,K, 0.0f, H1,M);
    }
    grid.sync();

    // ── PHASE 1a: groupnorm reduction (per-row mean/var). One block per row. ──
    // WARP-SHUFFLE reduction (32 B static smem) — the megafwd cannot afford a
    // 256-float __shared__ buffer (the inline WMMA2 GEMM already uses the full
    // 48 KB static cap on sm_100). All 256 threads share the same row r → no
    // divergence at the reduction barriers.
    {
        __shared__ float red[8];
        for (long long r=blockIdx.x; r<M; r+=gridDim.x) {
            float s=0.f, sq=0.f;
            for (long long c=tid; c<N1; c+=blockDim.x){ float v=H1[r+c*M]; s+=v; sq+=v*v; }
            float tot  = blk_sum256(s,  red); __syncthreads();
            float totq = blk_sum256(sq, red); __syncthreads();
            if (tid==0){ float mean=tot/(float)N1; rowMean[r]=mean; rowVar[r]=totq/(float)N1-mean*mean; }
            __syncthreads();
        }
    }
    grid.sync();   // per-row stats now globally visible (cross-block reduction)

    // ── PHASE 1b/1c/1d: N = groupnorm(H1); E=gelu(N); R=E+H1 (fused) ─────────
    {
        long long n=M*N1; long long stride=(long long)blockDim.x*gridDim.x;
        for (long long i=(long long)blockIdx.x*blockDim.x+tid; i<n; i+=stride){
            long long r=i%M;
            float inv = rsqrtf(rowVar[r]+MEGAFWD_EPS);
            float nrm = (H1[i]-rowMean[r])*inv;
            Nrm[i]=nrm;
            R[i] = megastep_gelu(nrm) + H1[i];   // gelu + residual fused
        }
    }
    grid.sync();

    // ── PHASE 2: H2 = R · W2  (conv GEMM2, own-GEMM inline) ──────────────────
    {
        long long tM=(M+HXG_BM-1)/HXG_BM, tN=(N2+HXG_BN-1)/HXG_BN, nT=tM*tN;
        for (long long t=blockIdx.x; t<nT; t+=gridDim.x)
            wmma2_tile_device(t/tN, t%tN, 0,0, M,N2,N1, 1.0f, R,M, W2,N1, 0.0f, H2,M);
    }
    grid.sync();

    // ── PHASE 3a/3b: G2=gelu(H2); P=expert_pack(G2) (fused) ─────────────────
    {
        long long n=M*N2; long long stride=(long long)blockDim.x*gridDim.x;
        for (long long i=(long long)blockIdx.x*blockDim.x+tid; i<n; i+=stride)
            P[i] = megastep_expack(megastep_gelu(H2[i]));
    }
    grid.sync();

    // ── PHASE 3c: moe_router reduction (per-row max + sumexp). One block/row. ─
    // WARP-SHUFFLE reduction (32 B static smem), same rationale as PHASE 1a.
    {
        __shared__ float red[8];
        for (long long r=blockIdx.x; r<M; r+=gridDim.x) {
            float mx=-1e30f;
            for (long long c=tid; c<N2; c+=blockDim.x){ float v=P[r+c*M]; if(v>mx)mx=v; }
            float rmax=blk_max256(mx, red); __syncthreads();
            float se=0.f;
            for (long long c=tid; c<N2; c+=blockDim.x) se += expf(P[r+c*M]-rmax);
            float rsum=blk_sum256(se, red); __syncthreads();
            if (tid==0){ rowMax[r]=rmax; rowSum[r]=rsum; }
            __syncthreads();
        }
    }
    grid.sync();

    // ── PHASE 3d: moe_router softmax -> FINAL out Rt ────────────────────────
    {
        long long n=M*N2; long long stride=(long long)blockDim.x*gridDim.x;
        for (long long i=(long long)blockIdx.x*blockDim.x+tid; i<n; i+=stride){
            long long r=i%M; Rt[i]=expf(P[i]-rowMax[r])/rowSum[r];
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// helpers
// ─────────────────────────────────────────────────────────────────────────────
static double rel_rms(const float* ref, const float* got, long long n) {
    double se=0.0, sr=0.0;
    for (long long i=0;i<n;i++){ double d=(double)got[i]-(double)ref[i]; se+=d*d; sr+=(double)ref[i]*(double)ref[i]; }
    return sqrt(se/(sr>0?sr:1.0));
}
static double max_abs_diff(const float* ref, const float* got, long long n) {
    double mx=0.0; for (long long i=0;i<n;i++){ double d=fabs((double)got[i]-(double)ref[i]); if(d>mx)mx=d; } return mx;
}

// EAGER reference: the FULL fwd as SEPARATE launches (the serial per-kernel-sync
// DAG — the regime H1a/H1b name as the util wall).
static void eager_fwd(long long M, long long K, long long N1, long long N2,
                      const float* dA, const float* dW1, const float* dW2,
                      float* dH1, float* dNrm, float* dR, float* dH2, float* dP, float* dRt,
                      float* dMean, float* dVar, float* dMax, float* dSum) {
    float alpha=1.0f, beta=0.0f;
    dim3 g1blk(256), g1grd((unsigned)((M+HXG_BM-1)/HXG_BM),(unsigned)((N1+HXG_BN-1)/HXG_BN));
    _hx_k_sgemm_cm_wmma2<<<g1grd,g1blk>>>(0,0,M,N1,K, alpha, dA,M, dW1,K, beta, dH1,M);   // GEMM1
    gn_reduce_k<<<(unsigned)M,256>>>(dH1,M,N1,dMean,dVar);                                 // gn reduce
    long long n1=M*N1; int blk=256; int grd1=(int)((n1+blk-1)/blk); if(grd1>65535)grd1=65535;
    gn_norm_k<<<grd1,blk>>>(dH1,M,N1,dMean,dVar,dNrm);                                     // gn norm
    gelu_resid_k<<<grd1,blk>>>(dNrm,dH1,dR,n1);                                            // gelu+resid
    dim3 g2blk(256), g2grd((unsigned)((M+HXG_BM-1)/HXG_BM),(unsigned)((N2+HXG_BN-1)/HXG_BN));
    _hx_k_sgemm_cm_wmma2<<<g2grd,g2blk>>>(0,0,M,N2,N1, alpha, dR,M, dW2,N1, beta, dH2,M);  // GEMM2
    long long n2=M*N2; int grd2=(int)((n2+blk-1)/blk); if(grd2>65535)grd2=65535;
    gelu2_pack_k<<<grd2,blk>>>(dH2,dP,n2);                                                 // gelu2+pack
    router_reduce_k<<<(unsigned)M,256>>>(dP,M,N2,dMax,dSum);                               // router reduce
    router_norm_k<<<grd2,blk>>>(dP,M,N2,dMax,dSum,dRt);                                    // router softmax
}

int main(int argc, char** argv) {
    long long M=1024, K=1536, N1=1536, N2=1024; int iters=50;
    if (argc>=5){ M=atoll(argv[1]); K=atoll(argv[2]); N1=atoll(argv[3]); N2=atoll(argv[4]); }
    if (argc>=6) iters=atoi(argv[5]);
    const char* mega_env=getenv("HEXA_CLM_MEGASTEP");
    int mega_on=(mega_env && mega_env[0] && strcmp(mega_env,"0"));
    const char* loop_env=getenv("MEGASTEP_LOOP");   // "eager" | "mega" → sustained single-path loop

    cublasCreate(&g_cublas_handle); cublasSetMathMode(g_cublas_handle, CUBLAS_TF32_TENSOR_OP_MATH);
    int dev; cudaGetDevice(&dev); cudaDeviceProp p; cudaGetDeviceProperties(&p,dev);

    long long szA=M*K, szW1=K*N1, szW2=N1*N2, szH1=M*N1, szH2=M*N2;
    float *hA=(float*)malloc(szA*4), *hW1=(float*)malloc(szW1*4), *hW2=(float*)malloc(szW2*4);
    float *hRef=(float*)malloc(szH2*4), *hGot=(float*)malloc(szH2*4);
    srand(1234);
    for (long long i=0;i<szA;i++)  hA[i]  = (float)(rand()%2001-1000)/1000.0f;
    for (long long i=0;i<szW1;i++) hW1[i] = (float)(rand()%2001-1000)/1000.0f;
    for (long long i=0;i<szW2;i++) hW2[i] = (float)(rand()%2001-1000)/1000.0f;

    float *dA,*dW1,*dW2,*dH1,*dNrm,*dR,*dH2,*dP,*dRt,*dRt2;
    float *dMean,*dVar,*dMax,*dSum;
    cudaMalloc(&dA,szA*4); cudaMalloc(&dW1,szW1*4); cudaMalloc(&dW2,szW2*4);
    cudaMalloc(&dH1,szH1*4); cudaMalloc(&dNrm,szH1*4); cudaMalloc(&dR,szH1*4);
    cudaMalloc(&dH2,szH2*4); cudaMalloc(&dP,szH2*4); cudaMalloc(&dRt,szH2*4); cudaMalloc(&dRt2,szH2*4);
    cudaMalloc(&dMean,M*4); cudaMalloc(&dVar,M*4); cudaMalloc(&dMax,M*4); cudaMalloc(&dSum,M*4);
    cudaMemcpy(dA,hA,szA*4,cudaMemcpyHostToDevice);
    cudaMemcpy(dW1,hW1,szW1*4,cudaMemcpyHostToDevice);
    cudaMemcpy(dW2,hW2,szW2*4,cudaMemcpyHostToDevice);
    int* dFired; cudaMalloc(&dFired,sizeof(int)); cudaMemset(dFired,0,sizeof(int));

    printf("GPU: %s (sm_%d%d)\n", p.name, p.major, p.minor);
    printf("FULL fwd: GEMM1(M=%lld,N1=%lld,K=%lld) -> [gn->gelu->resid] -> GEMM2(M=%lld,N2=%lld,K=%lld) -> [gelu2->pack->router]  iters=%d\n",
           M,N1,K, M,N2,N1, iters);
    printf("eager fwd = 8 launches (GEMM,gn-reduce,gn-norm,gelu+resid,GEMM,gelu2+pack,router-reduce,router-norm)\n");
    printf("HEXA_CLM_MEGASTEP=%s\n", mega_on?"1 (megafwd path ON)":"0 (eager only)");

    // pack the kargs once (15 args).
    void* kargs[]={ &M,&K,&N1,&N2, &dA,&dW1,&dW2, &dH1,&dNrm,&dR,&dH2,&dP,&dRt2,
                    &dMean,&dVar,&dMax,&dSum, &dFired };

    // ── 0) sustained single-path loop for the external nvidia-smi util sampler ──
    if (loop_env && loop_env[0]) {
        double secs=15.0; struct timespec t0,t1; long it=0;
        int isMega=!strcmp(loop_env,"mega");
        dim3 block(256), grid;
        if (isMega){
            int nbps=0; cudaOccupancyMaxActiveBlocksPerMultiprocessor(&nbps,_hx_k_clm_megafwd,256,0);
            int gb=nbps*p.multiProcessorCount; if(gb<1){ printf("[MEGAFWD-BLOCKED] coop occ=0\n"); return 3; }
            grid=dim3(gb);
        }
        clock_gettime(CLOCK_MONOTONIC,&t0);
        for(;;){
            if (isMega) cudaLaunchCooperativeKernel((void*)_hx_k_clm_megafwd,grid,block,kargs,0,0);
            else        eager_fwd(M,K,N1,N2,dA,dW1,dW2,dH1,dNrm,dR,dH2,dP,dRt,dMean,dVar,dMax,dSum);
            if(((++it)&15)==0){ cudaDeviceSynchronize(); clock_gettime(CLOCK_MONOTONIC,&t1);
                double el=(t1.tv_sec-t0.tv_sec)+(t1.tv_nsec-t0.tv_nsec)/1e9; if(el>=secs) break; }
        }
        cudaDeviceSynchronize();
        printf("MEGASTEP_LOOP=%s: %ld iters\n", loop_env, it);
        return 0;
    }

    // ── 1) EAGER reference (8 launches) ──────────────────────────────────────
    eager_fwd(M,K,N1,N2,dA,dW1,dW2,dH1,dNrm,dR,dH2,dP,dRt,dMean,dVar,dMax,dSum);
    cudaError_t er=cudaDeviceSynchronize();
    if (er!=cudaSuccess){ printf("EAGER launch error: %s\n",cudaGetErrorString(er)); return 2; }
    cudaMemcpy(hRef,dRt,szH2*4,cudaMemcpyDeviceToHost);

    // ── 2) MEGAFWD (1 cooperative launch) ────────────────────────────────────
    int mega_ok=0; double rms=-1, mad=-1; int grid_blocks=0, numBlocksPerSm=0;
    if (mega_on) {
        cudaError_t oce=cudaOccupancyMaxActiveBlocksPerMultiprocessor(&numBlocksPerSm,_hx_k_clm_megafwd,256,0);
        grid_blocks=numBlocksPerSm*p.multiProcessorCount;
        printf("coop occupancy: %d blocks/SM × %d SM = %d resident blocks (occ query: %s)\n",
               numBlocksPerSm, p.multiProcessorCount, grid_blocks, cudaGetErrorString(oce));
        if (grid_blocks<1) {
            printf("[MEGAFWD-BLOCKED] cooperative occupancy = 0 (register/smem budget over-subscribed by the "
                   "added phases); the persistent grid cannot be co-resident → FULL fwd does NOT fit one "
                   "cooperative launch. BUDGET WALL: report largest prefix that fit.\n");
        } else {
            cudaMemset(dRt2,0,szH2*4); cudaMemset(dFired,0,sizeof(int));
            dim3 grid(grid_blocks), block(256);
            cudaError_t le=cudaLaunchCooperativeKernel((void*)_hx_k_clm_megafwd,grid,block,kargs,0,0);
            if (le!=cudaSuccess){ printf("[MEGAFWD-BLOCKED] cudaLaunchCooperativeKernel failed: %s\n",cudaGetErrorString(le)); }
            else {
                cudaError_t se=cudaDeviceSynchronize();
                if (se!=cudaSuccess){ printf("[MEGAFWD-BLOCKED] megafwd runtime error: %s\n",cudaGetErrorString(se)); }
                else {
                    int firedHost=0; cudaMemcpy(&firedHost,dFired,sizeof(int),cudaMemcpyDeviceToHost);
                    if (firedHost) printf("[MEGAFWD-FIRED]\n");
                    cudaMemcpy(hGot,dRt2,szH2*4,cudaMemcpyDeviceToHost);
                    rms=rel_rms(hRef,hGot,szH2); mad=max_abs_diff(hRef,hGot,szH2); mega_ok=1;
                }
            }
        }
    }

    // ── 3) correctness verdict ───────────────────────────────────────────────
    if (mega_ok) {
        printf("\ncorrectness (megafwd vs eager full-fwd):\n");
        printf("  rel-RMS  = %.3e  %s  (TF32 own-GEMM bar <= 3e-3)\n", rms, rms<=3e-3?"PASS":"FAIL");
        printf("  max|Δ|   = %.3e\n", mad);
    }

    // ── 4) util A/B on the FULL fwd (sustained loop, where the sub-ms glue lives) ──
    if (mega_on && mega_ok) {
        double secs=12.0; struct timespec t0,t1;
        long itE=0; clock_gettime(CLOCK_MONOTONIC,&t0);
        for(;;){ eager_fwd(M,K,N1,N2,dA,dW1,dW2,dH1,dNrm,dR,dH2,dP,dRt,dMean,dVar,dMax,dSum);
                 if(((++itE)&15)==0){ cudaDeviceSynchronize(); clock_gettime(CLOCK_MONOTONIC,&t1);
                   double el=(t1.tv_sec-t0.tv_sec)+(t1.tv_nsec-t0.tv_nsec)/1e9; if(el>=secs) break; } }
        cudaDeviceSynchronize(); clock_gettime(CLOCK_MONOTONIC,&t1);
        double elE=(t1.tv_sec-t0.tv_sec)+(t1.tv_nsec-t0.tv_nsec)/1e9;
        dim3 grid(grid_blocks), block(256);
        long itM=0; clock_gettime(CLOCK_MONOTONIC,&t0);
        for(;;){ cudaLaunchCooperativeKernel((void*)_hx_k_clm_megafwd,grid,block,kargs,0,0);
                 if(((++itM)&15)==0){ cudaDeviceSynchronize(); clock_gettime(CLOCK_MONOTONIC,&t1);
                   double el=(t1.tv_sec-t0.tv_sec)+(t1.tv_nsec-t0.tv_nsec)/1e9; if(el>=secs) break; } }
        cudaDeviceSynchronize(); clock_gettime(CLOCK_MONOTONIC,&t1);
        double elM=(t1.tv_sec-t0.tv_sec)+(t1.tv_nsec-t0.tv_nsec)/1e9;
        printf("\nsustained throughput on the FULL fwd (%.0fs each):\n", secs);
        printf("  eager  (8 launches)  : %ld iters  (%.1f fwd-steps/s)\n", itE, itE/elE);
        printf("  megafwd (1 coop)     : %ld iters  (%.1f fwd-steps/s)\n", itM, itM/elM);
        printf("  -> for util MEAN run util_megafwd.sh (external nvidia-smi sampler).\n");
    }

    cudaFree(dA);cudaFree(dW1);cudaFree(dW2);cudaFree(dH1);cudaFree(dNrm);cudaFree(dR);
    cudaFree(dH2);cudaFree(dP);cudaFree(dRt);cudaFree(dRt2);
    cudaFree(dMean);cudaFree(dVar);cudaFree(dMax);cudaFree(dSum);cudaFree(dFired);
    free(hA);free(hW1);free(hW2);free(hRef);free(hGot);
    return mega_on ? (mega_ok?0:3) : 0;
}
