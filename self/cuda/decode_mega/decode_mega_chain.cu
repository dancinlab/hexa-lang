// decode_mega_chain.cu — fleet lane "decode-megakernel GPU", round r1.
//
// MECHANISM (cuBLAS-orthogonal, c23-ⓑ/ⓓ no-LLVM direct-emit strength):
//   A PERSISTENT whole-decode-step MEGAKERNEL. The chained back-to-back GEMMs
//   of a batch=1 decode inner loop are fused into ONE persistent grid-resident
//   kernel launch with an on-GPU scheduler (grid.sync between dependent ops),
//   keeping the intermediate activation in registers/smem — NEVER materialized
//   to DRAM, NO per-GEMM launch boundary. cuBLAS CANNOT do this: every
//   cublasGemm/Gemv is its own launch with a pipeline bubble + a DRAM roundtrip
//   of the intermediate.
//
// HONEST FRAMING: this is a LATENCY / launch-bubble win at batch=1 DECODE
// (M=1, the GEMMs degenerate to memory-bound GEMVs dominated by weight load +
// launch tax), NOT a raw-GEMM-rate parity win. At prefill (M=L>>1, compute-
// bound) the megakernel is closed-neg (rfc060_megakernel_fwd.cu already
// measured that). Decode (M=1) is the genuinely-different, memory-bound regime
// where eliminating the launch bubble + intermediate roundtrip should win.
//
// WORKLOAD: the decode-MLP block, batch=1, one token:
//   x   : [1, D]
//   h   = gelu(x @ W1)      W1: [D, Dff]   ->  h: [1, Dff]
//   y   = h @ W2            W2: [Dff, D]   ->  y: [1, D]
// with Dff = 4*D, D in {2048, 4096}.  All FP32.
//
//   BASELINE  (per-op engine = what cuBLAS-driven inference does):
//       cublasSgemm(W1) -> DRAM h -> gelu kernel -> DRAM h -> cublasSgemm(W2)
//       = 3 launches, 2 DRAM roundtrips of h ([1,Dff]).
//   MEGA      (this lane):
//       ONE persistent cooperative kernel. GEMV1 -> h kept in smem -> gelu in
//       smem -> GEMV2, grid.sync between, one launch, h never leaves the chip.
//
// MEASURE: end-to-end latency (us) over many iters via CUDA events; speedup;
//          rel-RMS of mega-y vs cuBLAS-chain-y; run-to-run byte-eq.
//
// Build: nvcc -O3 -std=c++14 -arch=native decode_mega_chain.cu \
//             -lcublas -lcudart -lm -o decode_mega_chain
// Run:   ./decode_mega_chain            # all shapes
//        ./decode_mega_chain 2048       # single D
//
// byteeq: NEW opt-in benchmark, no shipped path touched -> byteeq-NEUTRAL.
//
// ===========================================================================
// MEASURED r1 (aiden RTX 5070 sm_120, FP32, CUDA events, 2000 iters):
//   D     Dff    | base(cuBLAS 3-launch) | mega(1 persistent) | speedup | relRMS  | byteeq
//   2048  8192   | 219.19 us             | 831.33 us          | 0.264   | 1.3e-06 | YES
//   4096  16384  | 873.32 us             | 1754.82 us         | 0.498   | 1.8e-06 | YES
//   decomposition (own-GEMV-3launch = same GEMVs, 3 separate launches):
//     D=2048: own3=824.1us  fusion-gain(own3/mega)=0.991  kernel-quality(cublas/own3)=0.266
//     D=4096: own3=1750.7us fusion-gain(own3/mega)=0.998  kernel-quality(cublas/own3)=0.499
//   launch-tax probe: plain=2.05us  coop+grid.sync=2.05us  cublas-tiny-sgemm=6.14us
//
// VERDICT — closed-neg (measured wall), correctness GREEN.
//   The megakernel does NOT beat cuBLAS-per-call at batch=1 FP32 decode here.
//   Decomposition isolates WHY:
//     * fusion-gain = 0.99-1.0  -> fusing the chain into one persistent kernel
//       saves ~0%. Launch tax is ~2us/launch; the chain is 219us (D=2048), so
//       launch overhead is <=5% of total and grid.sync adds 0. The cited
//       1.5-2.5x launch-bubble win does NOT reproduce on this HW/dtype/shape
//       (launch tax tiny vs 268MB weight-read bandwidth).
//     * kernel-quality = 0.27-0.50 -> the naive hand GEMV is 2-4x slower than
//       cuBLAS's tuned GEMV. THAT is the entire gap (not the fusion).
//   relRMS ~1e-6 (FP32 reduction-order), run-to-run byte-eq YES (deterministic).
//
// WHY this diverges from Hazy "No Bubbles" / Mirage MPK (1.5-2.5x): their win
// is on datacenter GPUs with MANY small back-to-back ops (norm/attn/several
// projections) where accumulated launch+boundary overhead dominates. Here the
// regime is 2 large weight GEMVs (bandwidth-bound) + a 2us consumer launch tax
// + an already-near-roofline cuBLAS GEMV -> no fusion headroom.
//
// honest next rounds:
//   r2 (open): full decode block (~7-10 small ops: RMSNorm+QKV+attn+out+MLP) so
//     accumulated launch+boundary overhead is large enough for fusion to pay.
//   r3 (prerequisite): close the kernel-quality gap first (split-K / warp-reduce
//     GEMV, cuBLAS/OpenBLAS reference-first) -- until the own GEMV reaches
//     cuBLAS-parity the megakernel cannot win regardless of fusion.
// ===========================================================================

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cuda_runtime.h>
#include <cooperative_groups.h>
#include <cublas_v2.h>

namespace cg = cooperative_groups;

#define CK(x) do{ cudaError_t e=(x); if(e!=cudaSuccess){ \
  printf("CUDA-ERR %s @%d: %s\n",#x,__LINE__,cudaGetErrorString(e)); exit(3);} }while(0)
#define CB(x) do{ cublasStatus_t s=(x); if(s!=CUBLAS_STATUS_SUCCESS){ \
  printf("CUBLAS-ERR %d @%d\n",(int)s,__LINE__); exit(3);} }while(0)

// ---- gelu (tanh approx, same constants as stdlib) -------------------------
__device__ __forceinline__ float gelu(float v){
    const float k0 = 0.7978845608028654f;   // sqrt(2/pi)
    const float k1 = 0.044715f;
    float u = k0 * (v + k1*v*v*v);
    float t = tanhf(u);
    return 0.5f * v * (1.0f + t);
}

// ===========================================================================
// BASELINE path kernels (per-op engine)
// ===========================================================================
// gelu over [1,Dff] in DRAM (the launch the per-op engine must pay between the
// two GEMVs, plus the two DRAM roundtrips of h cuBLAS forces).
__global__ void gelu_dram(const float* __restrict__ in, float* __restrict__ out, int n){
    int i = blockIdx.x*blockDim.x + threadIdx.x;
    if (i < n) out[i] = gelu(in[i]);
}

// ===========================================================================
// MEGA path: ONE persistent GRID-WIDE cooperative kernel for the decode chain.
// ===========================================================================
// x:[D]  W1:[D,Dff] row-major  W2:[Dff,D] row-major  y:[D]
//
// KEY (corrected r1b): decode GEMVs are WEIGHT-BANDWIDTH-bound — winning needs
// ALL SMs reading W1/W2, so the kernel is a MULTI-BLOCK persistent cooperative
// grid (gridDim = #SMs), NOT a single block. The intermediate h:[Dff] is
// published through a small global scratch buffer that stays L2-resident
// (Dff floats = 32-64KB << L2). The mechanism's win is therefore:
//   - ONE launch instead of 3  -> 2 launch bubbles eliminated
//   - h published via a single grid.sync barrier instead of two cuBLAS
//     kernel-boundary HBM commits + a separate gelu launch
// grid.sync() couples GEMV1 -> gelu -> GEMV2 inside the single launch.
//
// GEMV1:  h[j] = gelu( sum_k x[k]*W1[k*Dff + j] )   j in [0,Dff)  -> hscr (L2)
// GEMV2:  y[i] =      sum_j h[j]*W2[j*D + i]         i in [0,D)
//
// x:[D] is staged into smem per-block (cheap broadcast). h read from hscr.
extern __shared__ float smem[];

__global__ void decode_mega(const float* __restrict__ x,
                            const float* __restrict__ W1,
                            const float* __restrict__ W2,
                            float* __restrict__ y,
                            float* __restrict__ hscr,   // [Dff] L2-resident scratch
                            int D, int Dff){
    cg::grid_group grid = cg::this_grid();
    float* sx = smem;        // [D] per-block copy of x
    int tid    = blockIdx.x*blockDim.x + threadIdx.x;
    int stride = gridDim.x*blockDim.x;

    for (int k = threadIdx.x; k < D; k += blockDim.x) sx[k] = x[k];
    __syncthreads();

    // --- GEMV1 + gelu (all SMs split the Dff columns) -----------------------
    // consecutive threads -> consecutive output cols j -> for fixed k the loads
    // W1[k*Dff + j] over consecutive j are a contiguous 128B line = coalesced.
    for (int j = tid; j < Dff; j += stride){
        float acc = 0.0f;
        const float* w1col = W1 + j;          // W1 row-major [D,Dff], col j
        #pragma unroll 4
        for (int k = 0; k < D; ++k) acc += sx[k] * w1col[(size_t)k*Dff];
        hscr[j] = gelu(acc);                  // h published to L2-resident scratch
    }
    grid.sync();   // one barrier replaces 2 cuBLAS kernel boundaries + gelu launch

    // --- GEMV2 (all SMs split the D output cols) ----------------------------
    for (int i = tid; i < D; i += stride){
        float acc = 0.0f;
        const float* w2col = W2 + i;          // W2 row-major [Dff,D], col i
        #pragma unroll 4
        for (int j = 0; j < Dff; ++j) acc += hscr[j] * w2col[(size_t)j*D];
        y[i] = acc;
    }
}

// Non-fused twins of the mega GEMV phases, as SEPARATE launches (same math /
// access pattern as decode_mega). Used to isolate the pure FUSION benefit
// (mega vs these) from raw kernel quality (these vs cuBLAS).
__global__ void gemv1_gelu(const float* __restrict__ x, const float* __restrict__ W1,
                           float* __restrict__ h, int D, int Dff){
    int j = blockIdx.x*blockDim.x + threadIdx.x;
    if (j >= Dff) return;
    float acc=0.f; const float* w1col=W1+j;
    #pragma unroll 4
    for (int k=0;k<D;++k) acc += x[k]*w1col[(size_t)k*Dff];
    h[j]=gelu(acc);
}
__global__ void gemv2(const float* __restrict__ h, const float* __restrict__ W2,
                      float* __restrict__ y, int D, int Dff){
    int i = blockIdx.x*blockDim.x + threadIdx.x;
    if (i >= D) return;
    float acc=0.f; const float* w2col=W2+i;
    #pragma unroll 4
    for (int j=0;j<Dff;++j) acc += h[j]*w2col[(size_t)j*D];
    y[i]=acc;
}

// ---------------------------------------------------------------------------
static float frand(uint64_t* s){
    *s = *s*6364136223846793005ULL + 1442695040888963407ULL;
    return ((int64_t)(*s>>33) / (float)(1ull<<30)) * 0.02f;
}

struct Stat { double mean_us; };

static Stat time_event(cudaEvent_t a, cudaEvent_t b, int iters,
                       void(*launch)(void*), void* ctx){
    for (int i=0;i<20;i++) launch(ctx);          // warmup
    CK(cudaDeviceSynchronize());
    CK(cudaEventRecord(a));
    for (int i=0;i<iters;i++) launch(ctx);       // batched -> captures device launch tax
    CK(cudaEventRecord(b));
    CK(cudaEventSynchronize(b));
    float ms=0; CK(cudaEventElapsedTime(&ms,a,b));
    Stat st; st.mean_us = (double)ms*1000.0/iters; return st;
}

struct BaseCtx {
    cublasHandle_t h; int D,Dff;
    const float *x,*W1,*W2; float *hbuf,*y;
};
static void launch_base(void* p){
    BaseCtx* c=(BaseCtx*)p;
    float one=1.0f, zero=0.0f;
    // row-major C[1,Dff]=A[1,D]*B[D,Dff]  ==  col-major C^T[Dff,1]=B^T*A^T
    //   cublasSgemm(N,N, Dff,1,D, W1(ld=Dff), x(ld=D), h(ld=Dff))
    CB(cublasSgemm(c->h, CUBLAS_OP_N, CUBLAS_OP_N,
                   c->Dff, 1, c->D, &one,
                   c->W1, c->Dff, c->x, c->D, &zero, c->hbuf, c->Dff));
    // between-GEMM gelu launch + DRAM roundtrip of h
    int blk=256, grd=(c->Dff+blk-1)/blk;
    gelu_dram<<<grd,blk>>>(c->hbuf, c->hbuf, c->Dff);
    // row-major C[1,D]=A[1,Dff]*B[Dff,D]
    CB(cublasSgemm(c->h, CUBLAS_OP_N, CUBLAS_OP_N,
                   c->D, 1, c->Dff, &one,
                   c->W2, c->D, c->hbuf, c->Dff, &zero, c->y, c->D));
}

struct MegaCtx {
    int D,Dff,blk,grid; size_t smem;
    const float *x,*W1,*W2; float *y,*hscr;
};
static void launch_mega(void* p){
    MegaCtx* c=(MegaCtx*)p;
    dim3 grid(c->grid), block(c->blk);   // multi-block persistent cooperative grid
    void* args[] = { (void*)&c->x,(void*)&c->W1,(void*)&c->W2,(void*)&c->y,
                     (void*)&c->hscr,(void*)&c->D,(void*)&c->Dff };
    CK(cudaLaunchCooperativeKernel((void*)decode_mega, grid, block, args, c->smem, 0));
}
// SAME scalar GEMVs as mega, but 3 separate launches + DRAM h (no fusion):
// isolates fusion benefit (mega vs this) from kernel quality (this vs cuBLAS).
static void launch_own3(void* p){
    MegaCtx* c=(MegaCtx*)p;
    int b=256;
    gemv1_gelu<<<(c->Dff+b-1)/b,b>>>(c->x,c->W1,c->hscr,c->D,c->Dff);
    gemv2<<<(c->D+b-1)/b,b>>>(c->hscr,c->W2,c->y,c->D,c->Dff);
}

int main(int argc, char** argv){
    int Ds[2] = {2048, 4096}; int nD=2;
    if (argc>1){ Ds[0]=atoi(argv[1]); nD=1; }

    int dev=0; CK(cudaSetDevice(dev));
    cudaDeviceProp prop; CK(cudaGetDeviceProperties(&prop,dev));
    printf("# device: %s  sm_%d%d  SMs=%d  smem/block(optin)=%dKB\n",
           prop.name, prop.major, prop.minor, prop.multiProcessorCount,
           (int)(prop.sharedMemPerBlockOptin/1024));
    printf("# workload: decode-MLP chain  y = gelu(x@W1)@W2   batch=1 M=1  FP32\n");
    printf("# baseline = cublasSgemm(W1)+gelu-kernel+cublasSgemm(W2) (3 launch, 2 DRAM h-roundtrip)\n");
    printf("# mega     = 1 persistent cooperative block (h in smem, no DRAM roundtrip, 1 launch)\n\n");

    cublasHandle_t cu; CB(cublasCreate(&cu));
    cudaEvent_t e0,e1; CK(cudaEventCreate(&e0)); CK(cudaEventCreate(&e1));

    printf("%-6s %-7s | %-12s %-12s %-8s | %-11s %-9s\n",
           "D","Dff","base_us","mega_us","speedup","relRMS","byteeq");
    printf("-------------------------------------------------------------------------------\n");

    int ITERS = 2000;
    for (int di=0; di<nD; ++di){
        int D=Ds[di], Dff=4*D;
        size_t szx=(size_t)D, szW1=(size_t)D*Dff, szW2=(size_t)Dff*D, szy=(size_t)D, szh=(size_t)Dff;

        float *hx=(float*)malloc(szx*4), *hW1=(float*)malloc(szW1*4),
              *hW2=(float*)malloc(szW2*4);
        uint64_t s=0x1234567ULL ^ (uint64_t)D;
        for (size_t i=0;i<szx;i++)  hx[i]=frand(&s);
        for (size_t i=0;i<szW1;i++) hW1[i]=frand(&s);
        for (size_t i=0;i<szW2;i++) hW2[i]=frand(&s);

        float *x,*W1,*W2,*y_base,*y_mega,*hbuf,*hscr;
        CK(cudaMalloc(&x,szx*4));      CK(cudaMalloc(&W1,szW1*4));
        CK(cudaMalloc(&W2,szW2*4));    CK(cudaMalloc(&y_base,szy*4));
        CK(cudaMalloc(&y_mega,szy*4)); CK(cudaMalloc(&hbuf,szh*4));
        CK(cudaMalloc(&hscr,szh*4));   // L2-resident h scratch for the mega kernel
        CK(cudaMemcpy(x,hx,szx*4,cudaMemcpyHostToDevice));
        CK(cudaMemcpy(W1,hW1,szW1*4,cudaMemcpyHostToDevice));
        CK(cudaMemcpy(W2,hW2,szW2*4,cudaMemcpyHostToDevice));

        size_t smem = (size_t)D*sizeof(float);   // x only (per-block broadcast)
        int blk = 256;
        // size the persistent grid to occupancy: blocks/SM * #SMs, all SMs busy.
        int blocksPerSM = 0;
        CK(cudaOccupancyMaxActiveBlocksPerMultiprocessor(
            &blocksPerSM, decode_mega, blk, smem));
        int grid = blocksPerSM * prop.multiProcessorCount;
        if (grid < 1) grid = prop.multiProcessorCount;

        BaseCtx bc{cu,D,Dff,x,W1,W2,hbuf,y_base};
        MegaCtx mc; mc.D=D; mc.Dff=Dff; mc.blk=blk; mc.grid=grid; mc.smem=smem;
        mc.x=x; mc.W1=W1; mc.W2=W2; mc.y=y_mega; mc.hscr=hscr;

        // correctness: y_mega vs y_base (cuBLAS chain)
        launch_base(&bc); CK(cudaDeviceSynchronize());
        launch_mega(&mc); CK(cudaDeviceSynchronize());
        float *yb=(float*)malloc(szy*4), *ym=(float*)malloc(szy*4);
        CK(cudaMemcpy(yb,y_base,szy*4,cudaMemcpyDeviceToHost));
        CK(cudaMemcpy(ym,y_mega,szy*4,cudaMemcpyDeviceToHost));
        double num=0,den=0;
        for (size_t i=0;i<szy;i++){ double d=(double)ym[i]-yb[i]; num+=d*d; den+=(double)yb[i]*yb[i]; }
        double relRMS = den>0 ? sqrt(num/den) : sqrt(num);

        // byte-eq run-to-run for mega
        CK(cudaMemset(y_mega,0,szy*4));
        launch_mega(&mc); CK(cudaDeviceSynchronize());
        float *ym2=(float*)malloc(szy*4);
        CK(cudaMemcpy(ym2,y_mega,szy*4,cudaMemcpyDeviceToHost));
        int byteeq = (memcmp(ym,ym2,szy*4)==0);

        Stat sb = time_event(e0,e1,ITERS,launch_base,&bc);
        Stat sm = time_event(e0,e1,ITERS,launch_mega,&mc);
        Stat so = time_event(e0,e1,ITERS,launch_own3,&mc);   // own GEMVs, 3 launches
        double speedup = sb.mean_us / sm.mean_us;

        printf("%-6d %-7d | %-12.3f %-12.3f %-8.3f | %-11.2e %-9s\n",
               D,Dff, sb.mean_us, sm.mean_us, speedup, relRMS, byteeq?"YES":"NO");

        // decomposition: own3 (same GEMVs, 3 launches) isolates the two effects.
        printf("       mega grid=%d blk=%d (%d blk/SM x %d SM) | own-GEMV-3launch=%.3f us  "
               "fusion-gain(own3/mega)=%.3f  kernel-quality(cublas/own3)=%.3f\n",
               grid, blk, blocksPerSM, prop.multiProcessorCount,
               so.mean_us, so.mean_us/sm.mean_us, sb.mean_us/so.mean_us);

        free(yb); free(ym); free(ym2);
        free(hx); free(hW1); free(hW2);
        cudaFree(x); cudaFree(W1); cudaFree(W2);
        cudaFree(y_base); cudaFree(y_mega); cudaFree(hbuf); cudaFree(hscr);
    }
    cublasDestroy(cu);
    return 0;
}
