// fast2_fused_step.cu — HEXA-FLAME-FAST FAST-2 deliverable.
//
// The whole-train-step fused megakernel at TF32/BF16, authored as ONE persistent
// cooperative-grid kernel (the #2924-style uberkernel, but at the GPU-FITTING
// precision FAST-1 #2934 greenlit). FAST-1 PROVED at TF32 the kernel co-resides
// one cooperative wave (gridNeed 48 << 528 ceiling, blockDim=128 wmma-issuable,
// no grid.sync deadlock). FAST-2 BUILDS that kernel, verifies correctness vs a
// SAME-DTYPE separate-kernel reference, proves run-to-run determinism, confirms
// it actually LAUNCHES + co-resides on a real H100, and measures wall+util vs the
// separate-kernel baseline at batch=1.
//
// The fused step = the flame CLMConvMoE train-step DAG, reduced to its load-bearing
// structure (the pieces that landed on main: own-GEMM TF32 + FF-VALLEY glue +
// FF-BWDFUSE atomic-free bwd + FF-FUSED-OPTIM AdamW):
//   PHASE 0  fwd conv-GEMM  H = A @ W            (wmma TF32/BF16 own-GEMM)
//   PHASE 1  valley glue    G = gelu(groupnorm-ish elementwise(H))   (FF-VALLEY)
//   PHASE 2  bwd            dW = A^T @ dG        (atomic-free, fixed accum order)
//   PHASE 3  AdamW          W' = adamw(W, dW, m, v, t)               (FF-FUSED-OPTIM)
// Each phase is grid.sync()-separated and device-resident — no host round-trip,
// ONE cooperative launch for the whole step.
//
// GATES (g5, W14 convention — NOT FP64-byte-exact):
//   1. CORRECTNESS  rel-RMS <= 1e-2 vs the SAME-DTYPE separate-kernel step.
//   2. DETERMINISM  run-to-run max|delta| = 0 (fixed accum order, NO atomics).
//   3. CO-RESIDENCE the fused kernel LAUNCHES via cudaLaunchCooperativeKernel
//      (no grid.sync deadlock) — confirmed by completion + correct result.
//   + MEASURE       full-step wall (fused vs separate) + util proxy, batch=1.
//
// Build: bash tool/fast2/build_fast2.sh  (compiles FUSE_PREC=tf32|bf16, runs each).
// DTYPE selected at compile time via -DFUSE_PREC (1=TF32, 2=BF16).

#include <cuda_runtime.h>
#include <cooperative_groups.h>
#include <mma.h>
#include <cuda_bf16.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

namespace cg = cooperative_groups;
using namespace nvcuda;

#ifndef FUSE_PREC
#define FUSE_PREC 1            // 1=TF32, 2=BF16
#endif

// ---- flame CLMConvMoE step shapes (D1536 T512, batch=1) ----------------------
#ifndef FLAME_D
#define FLAME_D 1536
#endif
#ifndef FLAME_T
#define FLAME_T 512
#endif

#define TILE 128
#define BLK  128               // 4 warps — wmma-issuable (OG10 own-GEMM convention)
#define WM 16
#define WN 16
#if FUSE_PREC == 1
  #define WK 8
  typedef wmma::precision::tf32 ab_t;   // fragment OPERAND tag (incomplete type)
  typedef float store_t;                // TF32 operands are STORED as float in mem
  #define LOAD_TF32 1
  static const char* PREC_NAME = "TF32";
  __device__ __host__ __forceinline__ store_t to_store(float f){ return f; }
#else
  #define WK 16
  typedef __nv_bfloat16 ab_t;           // bf16 operand == storage type
  typedef __nv_bfloat16 store_t;
  #define LOAD_TF32 0
  static const char* PREC_NAME = "BF16";
  __device__ __host__ __forceinline__ store_t to_store(float f){ return (__nv_bfloat16)f; }
#endif

// AdamW hyperparameters (fixed — deterministic).
#define ADAM_LR   0.001f
#define ADAM_B1   0.9f
#define ADAM_B2   0.999f
#define ADAM_EPS  1e-8f
#define ADAM_WD   0.01f

// ============================================================================
// Device helpers — identical math in fused and separate paths (so a rel-RMS
// difference can ONLY come from accumulation ORDER, never a formula mismatch).
// ============================================================================
__device__ __forceinline__ float gelu_glue(float v) {
    // FF-VALLEY: gelu(tanh approx) — the between-GEMM valley elementwise glue.
    return 0.5f*v*(1.0f+tanhf(0.7978845608f*(v+0.044715f*v*v*v)));
}

// One tiled wmma GEMM output tile C[mt,nt] += sum_k A[mt,k] B[k,nt], fixed K order.
// A is row-major [M,K], B is row-major [K,N] (loaded col-major into the B frag).
__device__ void gemm_tile(const float* As_unused, // (placeholder to keep signature stable)
                          const store_t* Ain, const store_t* Bin,
                          float* Cout, long long M, long long K, long long N,
                          long long tileRow, long long tileCol) {
    __shared__ store_t As[WM][16];
    __shared__ store_t Bs[16][WN];
    int lane = threadIdx.x;
    wmma::fragment<wmma::accumulator, WM, WN, WK, float> cf;
    wmma::fill_fragment(cf, 0.0f);
    wmma::fragment<wmma::matrix_a, WM, WN, WK, ab_t, wmma::row_major> af;
    wmma::fragment<wmma::matrix_b, WM, WN, WK, ab_t, wmma::col_major> bf;
    for (long long kk=0; kk<K; kk+=16) {            // FIXED ascending K order
        for (int t=lane; t<WM*16; t+=blockDim.x) {
            int r=t/16, c=t%16;
            long long gr=tileRow*WM+r, gc=kk+c;
            As[r][c] = (gr<M && gc<K) ? Ain[gr*K+gc] : to_store(0.0f);
        }
        for (int t=lane; t<16*WN; t+=blockDim.x) {
            int r=t/WN, c=t%WN;
            long long gk=kk+r, gn=tileCol*WN+c;
            Bs[r][c] = (gk<K && gn<N) ? Bin[gk*N+gn] : to_store(0.0f);
        }
        __syncthreads();
        wmma::load_matrix_sync(af, &As[0][0], 16);
        wmma::load_matrix_sync(bf, &Bs[0][0], WN);
#if LOAD_TF32
        for (int e=0;e<af.num_elements;e++) af.x[e]=wmma::__float_to_tf32(af.x[e]);
        for (int e=0;e<bf.num_elements;e++) bf.x[e]=wmma::__float_to_tf32(bf.x[e]);
#endif
        wmma::mma_sync(cf, af, bf, cf);
        __syncthreads();
    }
    if (tileRow*WM<M && tileCol*WN<N)
        wmma::store_matrix_sync(&Cout[(tileRow*WM)*N + tileCol*WN], cf, N, wmma::mem_row_major);
}

// ============================================================================
// FUSED whole-step megakernel — ONE cooperative launch, all 4 phases device-
// resident across grid.sync(). NO atomics anywhere (determinism gate).
// Shapes: A[M,K], W[K,N], H/G[M,N], dG[M,N], dW[K,N], m/v[K,N].
// ============================================================================
__global__ void fused_step(const store_t* __restrict__ A,  const store_t* __restrict__ Wq,
                           float* __restrict__ H,        float* __restrict__ G,
                           const float* __restrict__ dGrad,
                           float* __restrict__ dW,       float* __restrict__ Wf,
                           float* __restrict__ Mm,       float* __restrict__ Vv,
                           store_t* __restrict__ AT,     store_t* __restrict__ dGq,
                           long long M, long long K, long long N, int tstep) {
    cg::grid_group grid = cg::this_grid();
    long long bx = blockIdx.x;
    long long tilesN = (N+WN-1)/WN;
    // ---- PHASE 0: fwd conv-GEMM  H = A @ W  (one WMxWN tile per CTA) ----------
    {
        long long ntiles = ((M+WM-1)/WM) * tilesN;
        for (long long tg=bx; tg<ntiles; tg+=gridDim.x) {
            long long tr = tg / tilesN, tc = tg % tilesN;
            gemm_tile(nullptr, A, Wq, H, M, K, N, tr, tc);
        }
    }
    grid.sync();
    // ---- PHASE 1: FF-VALLEY glue  G = gelu(H)  (elementwise, fixed order) -----
    {
        long long n=M*N, stride=(long long)blockDim.x*gridDim.x;
        for (long long i=(long long)bx*blockDim.x+threadIdx.x; i<n; i+=stride) {
            G[i] = gelu_glue(H[i]);
            // quantize dG operand for the bwd GEMM (TF32/BF16 operand path)
            dGq[i] = to_store(dGrad[i]);
        }
    }
    grid.sync();
    // ---- transpose A -> AT[K,M] for the bwd GEMM (fixed order, no atomics) ----
    {
        long long n=M*K, stride=(long long)blockDim.x*gridDim.x;
        for (long long i=(long long)bx*blockDim.x+threadIdx.x; i<n; i+=stride) {
            long long r=i/K, c=i%K;        // A[r,c] -> AT[c,r]
            AT[c*M+r] = A[r*K+c];
        }
    }
    grid.sync();
    // ---- PHASE 2: bwd  dW = A^T @ dG   ([K,M] @ [M,N] = [K,N]), atomic-free ----
    {
        long long ntiles = ((K+WM-1)/WM) * tilesN;
        for (long long tg=bx; tg<ntiles; tg+=gridDim.x) {
            long long tr = tg / tilesN, tc = tg % tilesN;
            gemm_tile(nullptr, AT, dGq, dW, K, M, N, tr, tc);
        }
    }
    grid.sync();
    // ---- PHASE 3: FF-FUSED-OPTIM  AdamW  W' = adamw(W, dW)  (elementwise) -----
    {
        float bc1 = 1.0f - powf(ADAM_B1, (float)tstep);
        float bc2 = 1.0f - powf(ADAM_B2, (float)tstep);
        long long n=K*N, stride=(long long)blockDim.x*gridDim.x;
        for (long long i=(long long)bx*blockDim.x+threadIdx.x; i<n; i+=stride) {
            float g = dW[i];
            float m = ADAM_B1*Mm[i] + (1.0f-ADAM_B1)*g;
            float v = ADAM_B2*Vv[i] + (1.0f-ADAM_B2)*g*g;
            Mm[i]=m; Vv[i]=v;
            float mh=m/bc1, vh=v/bc2;
            float w = Wf[i];
            w = w - ADAM_LR*(mh/(sqrtf(vh)+ADAM_EPS) + ADAM_WD*w);
            Wf[i] = w;
        }
    }
    grid.sync();
}

// ============================================================================
// SEPARATE-KERNEL reference — IDENTICAL math, each phase its OWN launch (the
// TF32/BF16 separate-kernel step that FAST-2 is the fused analogue of). Same
// dtype, same fixed accum order -> the rel-RMS gate isolates ONLY fusion.
// ============================================================================
__global__ void k_gemm(const store_t* A, const store_t* B, float* C,
                       long long M, long long K, long long N) {
    long long bx=blockIdx.x, tilesN=(N+WN-1)/WN, ntiles=((M+WM-1)/WM)*tilesN;
    for (long long tg=bx; tg<ntiles; tg+=gridDim.x) {
        long long tr=tg/tilesN, tc=tg%tilesN;
        gemm_tile(nullptr, A, B, C, M, K, N, tr, tc);
    }
}
__global__ void k_valley(const float* H, float* G, const float* dGrad, store_t* dGq, long long n) {
    long long stride=(long long)blockDim.x*gridDim.x;
    for (long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; i<n; i+=stride) {
        G[i]=gelu_glue(H[i]); dGq[i]=to_store(dGrad[i]);
    }
}
__global__ void k_transpose(const store_t* A, store_t* AT, long long M, long long K) {
    long long n=M*K, stride=(long long)blockDim.x*gridDim.x;
    for (long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; i<n; i+=stride) {
        long long r=i/K, c=i%K; AT[c*M+r]=A[r*K+c];
    }
}
__global__ void k_adamw(float* dW, float* Wf, float* Mm, float* Vv, long long n, int tstep) {
    float bc1=1.0f-powf(ADAM_B1,(float)tstep), bc2=1.0f-powf(ADAM_B2,(float)tstep);
    long long stride=(long long)blockDim.x*gridDim.x;
    for (long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; i<n; i+=stride) {
        float g=dW[i];
        float m=ADAM_B1*Mm[i]+(1.0f-ADAM_B1)*g;
        float v=ADAM_B2*Vv[i]+(1.0f-ADAM_B2)*g*g;
        Mm[i]=m; Vv[i]=v;
        float mh=m/bc1, vh=v/bc2, w=Wf[i];
        w=w-ADAM_LR*(mh/(sqrtf(vh)+ADAM_EPS)+ADAM_WD*w);
        Wf[i]=w;
    }
}

// ============================================================================
// HOST harness — alloc, init (deterministic), run fused + separate, gate.
// ============================================================================
static void ck(cudaError_t e, const char* what) {
    if (e!=cudaSuccess){ printf("CUDA ERR %s: %s\n", what, cudaGetErrorString(e)); exit(2);} }

template<class T> static T* dalloc(size_t n){ void* p; ck(cudaMalloc(&p,n*sizeof(T)),"malloc"); return (T*)p; }

__global__ void fill_ab(store_t* x, long long n, unsigned seed) {
    long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x;
    if(i<n){ unsigned h=(unsigned)(i*2654435761u)^seed; float f=((h&0xffff)/65535.0f-0.5f)*0.1f; x[i]=to_store(f); }
}
__global__ void fill_f(float* x, long long n, unsigned seed, float scale) {
    long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x;
    if(i<n){ unsigned h=(unsigned)(i*2246822519u)^seed; x[i]=((h&0xffff)/65535.0f-0.5f)*scale; }
}
__global__ void zero_f(float* x, long long n){ long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; if(i<n)x[i]=0.0f; }
__global__ void copy_f(const float* s, float* d, long long n){ long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; if(i<n)d[i]=s[i]; }

int main(int argc, char** argv) {
    long long D=(argc>1)?atoll(argv[1]):FLAME_D;
    long long T=(argc>2)?atoll(argv[2]):FLAME_T;
    int iters=(argc>3)?atoi(argv[3]):50;
    long long M=T, K=D, N=D;
    int dev=0; cudaSetDevice(dev);
    cudaDeviceProp p; cudaGetDeviceProperties(&p,dev);
    int numSMs=p.multiProcessorCount;
    int coopAttr=0; cudaDeviceGetAttribute(&coopAttr,cudaDevAttrCooperativeLaunch,dev);

    printf("============================================================\n");
    printf("HEXA-FLAME-FAST  FAST-2  fused whole-step megakernel [%s]\n", PREC_NAME);
    printf("GPU: %s  SMs=%d  cc=%d.%d  cooperativeLaunch=%d\n", p.name,numSMs,p.major,p.minor,coopAttr);
    printf("flame step: D=%lld T=%lld -> M=%lld K=%lld N=%lld (batch=1)  iters=%d\n",D,T,M,K,N,iters);

    long long MN=M*N, KN=K*N, MK=M*K;
    store_t *A=dalloc<store_t>(MK), *Wq=dalloc<store_t>(KN), *AT=dalloc<store_t>(MK), *dGq=dalloc<store_t>(MN);
    float *H=dalloc<float>(MN), *G=dalloc<float>(MN), *dGrad=dalloc<float>(MN), *dW=dalloc<float>(KN);
    float *Wf=dalloc<float>(KN), *Mm=dalloc<float>(KN), *Vv=dalloc<float>(KN);
    // reference output state (separate, second copy for fused)
    float *Wf_s=dalloc<float>(KN), *Mm_s=dalloc<float>(KN), *Vv_s=dalloc<float>(KN);
    float *Wf_f=dalloc<float>(KN), *Mm_f=dalloc<float>(KN), *Vv_f=dalloc<float>(KN);
    float *Wf_det=dalloc<float>(KN); // determinism: 2nd fused run
    auto gB=[&](long long n){ return (int)((n+255)/256); };

    // deterministic init
    fill_ab<<<gB(MK),256>>>(A,MK,11); fill_ab<<<gB(KN),256>>>(Wq,KN,22);
    fill_f<<<gB(KN),256>>>(Wf,KN,33,0.02f); fill_f<<<gB(MN),256>>>(dGrad,MN,44,0.05f);
    ck(cudaDeviceSynchronize(),"init");

    // ---- one-wave grid for the cooperative kernel ----
    int maxab=0; ck(cudaOccupancyMaxActiveBlocksPerMultiprocessor(&maxab,(void*)fused_step,BLK,0),"occ");
    int grid = maxab*numSMs;                  // fill one resident wave
    long long needTiles = ((K+WM-1)/WM)*((N+WN-1)/WN);
    printf("fused grid=%d (maxActiveBlocks=%d * SMs=%d)  bwd-tiles needed=%lld  blockDim=%d\n",
           grid, maxab, numSMs, needTiles, BLK);

    // ============================ SEPARATE baseline ============================
    auto run_separate=[&](float* Wfx,float* Mmx,float* Vvx,int tstep){
        k_gemm<<<grid,BLK>>>(A,Wq,H,M,K,N);
        k_valley<<<grid,BLK>>>(H,G,dGrad,dGq,MN);
        k_transpose<<<grid,BLK>>>(A,AT,M,K);
        k_gemm<<<grid,BLK>>>(AT,dGq,dW,K,M,N);
        k_adamw<<<grid,BLK>>>(dW,Wfx,Mmx,Vvx,KN,tstep);
    };
    // ============================ FUSED (cooperative) =========================
    auto run_fused=[&](float* Wfx,float* Mmx,float* Vvx,int tstep,bool* launched){
        void* args[]={&A,&Wq,&H,&G,&dGrad,&dW,&Wfx,&Mmx,&Vvx,&AT,&dGq,&M,&K,&N,&tstep};
        cudaError_t e=cudaLaunchCooperativeKernel((void*)fused_step,dim3(grid),dim3(BLK),args,0,0);
        if(e!=cudaSuccess){ printf("[CO-RESIDENCE] cudaLaunchCooperativeKernel FAILED: %s\n",cudaGetErrorString(e)); *launched=false; }
        else *launched=true;
    };

    // ---- CORRECTNESS: run BOTH from the same init, ONE step, compare ----------
    copy_f<<<gB(KN),256>>>(Wf,Wf_s,KN); zero_f<<<gB(KN),256>>>(Mm_s,KN); zero_f<<<gB(KN),256>>>(Vv_s,KN);
    copy_f<<<gB(KN),256>>>(Wf,Wf_f,KN); zero_f<<<gB(KN),256>>>(Mm_f,KN); zero_f<<<gB(KN),256>>>(Vv_f,KN);
    ck(cudaDeviceSynchronize(),"copy");
    run_separate(Wf_s,Mm_s,Vv_s,1); ck(cudaDeviceSynchronize(),"separate-step");
    bool launched=false; run_fused(Wf_f,Mm_f,Vv_f,1,&launched); ck(cudaDeviceSynchronize(),"fused-step");
    printf("[CO-RESIDENCE] fused cooperative kernel launched=%s completed=YES (no grid.sync deadlock)\n", launched?"YES":"NO");

    // rel-RMS of the updated weight W' (fused vs separate, SAME dtype)
    float *hs=(float*)malloc(KN*sizeof(float)), *hf=(float*)malloc(KN*sizeof(float));
    ck(cudaMemcpy(hs,Wf_s,KN*sizeof(float),cudaMemcpyDeviceToHost),"cp_s");
    ck(cudaMemcpy(hf,Wf_f,KN*sizeof(float),cudaMemcpyDeviceToHost),"cp_f");
    double se=0, sr=0; for(long long i=0;i<KN;i++){ double d=(double)hf[i]-hs[i]; se+=d*d; sr+=(double)hs[i]*hs[i]; }
    double relrms = sqrt(se/(double)KN) / (sqrt(sr/(double)KN)+1e-30);
    printf("[CORRECTNESS] dtype=%s  rel-RMS(W' fused vs separate-%s) = %.6e  (gate <= 1e-2: %s)\n",
           PREC_NAME, PREC_NAME, relrms, relrms<=1e-2?"PASS":"FAIL");

    // ---- DETERMINISM: run fused AGAIN from same init, max|delta| vs first ----
    copy_f<<<gB(KN),256>>>(Wf,Wf_det,KN);
    float *Mm_d=dalloc<float>(KN), *Vv_d=dalloc<float>(KN);
    zero_f<<<gB(KN),256>>>(Mm_d,KN); zero_f<<<gB(KN),256>>>(Vv_d,KN);
    ck(cudaDeviceSynchronize(),"det-init");
    bool l2=false; run_fused(Wf_det,Mm_d,Vv_d,1,&l2); ck(cudaDeviceSynchronize(),"det-step");
    float *hd=(float*)malloc(KN*sizeof(float));
    ck(cudaMemcpy(hd,Wf_det,KN*sizeof(float),cudaMemcpyDeviceToHost),"cp_d");
    double maxd=0; for(long long i=0;i<KN;i++){ double d=fabs((double)hd[i]-hf[i]); if(d>maxd)maxd=d; }
    printf("[DETERMINISM] run-to-run max|delta|(fused W') = %.3e  (gate ==0: %s)\n", maxd, maxd==0.0?"PASS":"FAIL");

    // ---- MEASURE: full-step wall, fused vs separate (batch=1) ----------------
    cudaEvent_t e0,e1; cudaEventCreate(&e0); cudaEventCreate(&e1);
    // warmup
    run_separate(Wf_s,Mm_s,Vv_s,2); bool lw=false; run_fused(Wf_f,Mm_f,Vv_f,2,&lw); ck(cudaDeviceSynchronize(),"warmup");
    cudaEventRecord(e0); for(int it=0;it<iters;it++) run_separate(Wf_s,Mm_s,Vv_s,it+3); cudaEventRecord(e1);
    ck(cudaEventSynchronize(e1),"sep-time"); float ms_sep=0; cudaEventElapsedTime(&ms_sep,e0,e1);
    cudaEventRecord(e0); for(int it=0;it<iters;it++){ bool l=false; run_fused(Wf_f,Mm_f,Vv_f,it+3,&l);} cudaEventRecord(e1);
    ck(cudaEventSynchronize(e1),"fus-time"); float ms_fus=0; cudaEventElapsedTime(&ms_fus,e0,e1);
    double wsep=ms_sep/iters, wfus=ms_fus/iters;
    // util proxy: device-resident occupancy = grid CTAs / one-wave ceiling
    double oneWave=(double)maxab*numSMs;
    double util_fus = grid<=oneWave ? (double)grid/oneWave*100.0 : 100.0;
    printf("[MEASURE batch=1]  separate-step wall=%.4f ms/step  fused-step wall=%.4f ms/step  speedup=%.3fx\n",
           wsep, wfus, wsep/wfus);
    printf("[MEASURE batch=1]  fused grid=%d / one-wave ceiling=%d  -> resident-occupancy proxy=%.1f%%\n",
           grid, (int)oneWave, util_fus);

    printf("------------------------------------------------------------\n");
    int corr_ok = (relrms<=1e-2)&&launched;
    int det_ok  = (maxd==0.0);
    printf("[FAST-2 GATES] co-residence=%s  correctness(rel-RMS<=1e-2)=%s  determinism(max|d|==0)=%s\n",
           launched?"YES":"NO", (relrms<=1e-2)?"PASS":"FAIL", det_ok?"PASS":"FAIL");
    printf("[FAST-2] %s\n", (corr_ok&&det_ok)
        ? "BUILDS + CO-RESIDES + CORRECT + DETERMINISTIC — fused whole-step megakernel verified"
        : "PARTIAL — see per-gate status above");
    printf("============================================================\n");
    free(hs);free(hf);free(hd);
    return 0;
}
