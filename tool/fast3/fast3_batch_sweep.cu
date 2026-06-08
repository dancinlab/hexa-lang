// fast3_batch_sweep.cu — HEXA-FLAME-FAST FAST-3 deliverable (THE DECISIVE TEST).
//
// Run the FAST-2 verified fused-TF32/BF16 whole-step megakernel across a BATCH
// SWEEP (B = 1,2,4,8,16,32; M = B*T) on a real H100, and measure whether the
// full-STEP self-speedup BREAKS the ~3x batch-fill cap. This is the genuinely-
// untested 3-way combo: fusion x low-precision (TF32/BF16) x batch>1.
//
// The kernel itself is the FAST-2 kernel VERBATIM (tool/fast2/fast2_fused_step.cu)
// — it is already parameterized on M (=B*T), so FAST-3 is purely a HARNESS change:
// sweep M = B*T, and at each B re-measure (a) correctness rel-RMS vs the same-dtype
// separate-kernel reference, (b) run-to-run determinism, (c) one-wave FIT (does the
// fused grid still fit one cooperative wave as M grows), and (d) THE DECISIVE NUMBER:
// fused self-speedup vs the separate-TF32 batch curve and vs the ~3x FP64 cap.
//
// WHY this MAY break ~3x (the hypothesis under test):
//   (a) TF32 keeps the bigger M=B*T grid fitting one cooperative wave (FAST-1: ~11x
//       GEMM-phase batch headroom before the 528-CTA ceiling binds),
//   (b) fusion removes the 86.8% between-op host-glue idle gap (FAST-2 co-resident),
//   (c) batch>1 fills the SMs (the #2913 batch-fill lever).
//   Each ALONE hit a DIFFERENT wall; together they MAY cancel all 3 -> break ~3x.
//   It may ALSO still cap ~3x (honest closed-neg) if the cap was never the gap.
//
// GATES (g5):
//   1. CORRECTNESS held across batch  rel-RMS <= 1e-2 vs same-dtype separate ref @each B;
//      run-to-run determinism max|d|=0.
//   2. ONE-WAVE FIT across batch      at each B, gridNeed vs 528 ceiling; report the B
//      at which it stops fitting (FAST-1-predicted ~11x headroom).
//   3. THE DECISIVE NUMBER            fused-TF32 full-step self-speedup vs B; DOES it
//      break ~3x vs (i) separate-TF32 curve, (ii) #2913 FP64 ~3x asymptote; util
//      mean/median at each B (does fusion lift the MEDIAN off ~0%).
//
// Build: bash tool/fast3/build_fast3.sh
// DTYPE at compile time via -DFUSE_PREC (1=TF32, 2=BF16).

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
#ifndef FLAME_D
#define FLAME_D 1536
#endif
#ifndef FLAME_T
#define FLAME_T 512
#endif

#define TILE 128
#define BLK  128
#define WM 16
#define WN 16
#if FUSE_PREC == 1
  #define WK 8
  typedef wmma::precision::tf32 ab_t;
  typedef float store_t;
  #define LOAD_TF32 1
  static const char* PREC_NAME = "TF32";
  __device__ __host__ __forceinline__ store_t to_store(float f){ return f; }
#else
  #define WK 16
  typedef __nv_bfloat16 ab_t;
  typedef __nv_bfloat16 store_t;
  #define LOAD_TF32 0
  static const char* PREC_NAME = "BF16";
  __device__ __host__ __forceinline__ store_t to_store(float f){ return (__nv_bfloat16)f; }
#endif

#define ADAM_LR   0.001f
#define ADAM_B1   0.9f
#define ADAM_B2   0.999f
#define ADAM_EPS  1e-8f
#define ADAM_WD   0.01f

// === device math (FAST-2 verbatim) =========================================
__device__ __forceinline__ float gelu_glue(float v) {
    return 0.5f*v*(1.0f+tanhf(0.7978845608f*(v+0.044715f*v*v*v)));
}
__device__ void gemm_tile(const float* As_unused,
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
    for (long long kk=0; kk<K; kk+=16) {
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

// === FUSED whole-step megakernel (FAST-2 verbatim) =========================
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
    { long long ntiles = ((M+WM-1)/WM) * tilesN;
      for (long long tg=bx; tg<ntiles; tg+=gridDim.x) {
          long long tr = tg / tilesN, tc = tg % tilesN;
          gemm_tile(nullptr, A, Wq, H, M, K, N, tr, tc); } }
    grid.sync();
    { long long n=M*N, stride=(long long)blockDim.x*gridDim.x;
      for (long long i=(long long)bx*blockDim.x+threadIdx.x; i<n; i+=stride) {
          G[i] = gelu_glue(H[i]); dGq[i] = to_store(dGrad[i]); } }
    grid.sync();
    { long long n=M*K, stride=(long long)blockDim.x*gridDim.x;
      for (long long i=(long long)bx*blockDim.x+threadIdx.x; i<n; i+=stride) {
          long long r=i/K, c=i%K; AT[c*M+r] = A[r*K+c]; } }
    grid.sync();
    { long long ntiles = ((K+WM-1)/WM) * tilesN;
      for (long long tg=bx; tg<ntiles; tg+=gridDim.x) {
          long long tr = tg / tilesN, tc = tg % tilesN;
          gemm_tile(nullptr, AT, dGq, dW, K, M, N, tr, tc); } }
    grid.sync();
    { float bc1 = 1.0f - powf(ADAM_B1, (float)tstep);
      float bc2 = 1.0f - powf(ADAM_B2, (float)tstep);
      long long n=K*N, stride=(long long)blockDim.x*gridDim.x;
      for (long long i=(long long)bx*blockDim.x+threadIdx.x; i<n; i+=stride) {
          float g = dW[i];
          float m = ADAM_B1*Mm[i] + (1.0f-ADAM_B1)*g;
          float v = ADAM_B2*Vv[i] + (1.0f-ADAM_B2)*g*g;
          Mm[i]=m; Vv[i]=v;
          float mh=m/bc1, vh=v/bc2, w = Wf[i];
          w = w - ADAM_LR*(mh/(sqrtf(vh)+ADAM_EPS) + ADAM_WD*w);
          Wf[i] = w; } }
    grid.sync();
}

// === SEPARATE-KERNEL reference (FAST-2 verbatim) ===========================
__global__ void k_gemm(const store_t* A, const store_t* B, float* C,
                       long long M, long long K, long long N) {
    long long bx=blockIdx.x, tilesN=(N+WN-1)/WN, ntiles=((M+WM-1)/WM)*tilesN;
    for (long long tg=bx; tg<ntiles; tg+=gridDim.x) {
        long long tr=tg/tilesN, tc=tg%tilesN;
        gemm_tile(nullptr, A, B, C, M, K, N, tr, tc); }
}
__global__ void k_valley(const float* H, float* G, const float* dGrad, store_t* dGq, long long n) {
    long long stride=(long long)blockDim.x*gridDim.x;
    for (long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; i<n; i+=stride) {
        G[i]=gelu_glue(H[i]); dGq[i]=to_store(dGrad[i]); }
}
__global__ void k_transpose(const store_t* A, store_t* AT, long long M, long long K) {
    long long n=M*K, stride=(long long)blockDim.x*gridDim.x;
    for (long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; i<n; i+=stride) {
        long long r=i/K, c=i%K; AT[c*M+r]=A[r*K+c]; }
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
        Wf[i]=w; }
}

// === host helpers ==========================================================
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

// === main: BATCH SWEEP =====================================================
int main(int argc, char** argv) {
    long long D=(argc>1)?atoll(argv[1]):FLAME_D;
    long long T=(argc>2)?atoll(argv[2]):FLAME_T;
    int iters=(argc>3)?atoi(argv[3]):50;
    int dev=0; cudaSetDevice(dev);
    cudaDeviceProp p; cudaGetDeviceProperties(&p,dev);
    int numSMs=p.multiProcessorCount;
    int coopAttr=0; cudaDeviceGetAttribute(&coopAttr,cudaDevAttrCooperativeLaunch,dev);

    int maxab=0; ck(cudaOccupancyMaxActiveBlocksPerMultiprocessor(&maxab,(void*)fused_step,BLK,0),"occ");
    int grid = maxab*numSMs;
    double oneWave=(double)maxab*numSMs;

    printf("============================================================\n");
    printf("HEXA-FLAME-FAST  FAST-3  BATCH SWEEP  fused whole-step megakernel [%s]\n", PREC_NAME);
    printf("GPU: %s  SMs=%d  cc=%d.%d  cooperativeLaunch=%d\n", p.name,numSMs,p.major,p.minor,coopAttr);
    printf("flame step: D=%lld T=%lld  iters=%d   one-wave ceiling=%d (maxActiveBlocks=%d * SMs=%d)\n",
           D,T,iters,grid,maxab,numSMs);
    printf("B  M=B*T   gridNeed(fwd)  gridNeed(bwd)  one-wave-FIT  sep-ms  fused-ms  self-speedup  util%%(grid-stride-waves)  rel-RMS  determ-max|d|\n");
    printf("------------------------------------------------------------\n");

    long long K=D, N=D;
    int Bs[] = {1,2,4,8,16,32};
    for (int bi=0; bi<6; bi++) {
        int B = Bs[bi];
        long long M = (long long)B*T;
        long long MN=M*N, KN=K*N, MK=M*K;
        store_t *A=dalloc<store_t>(MK), *Wq=dalloc<store_t>(KN), *AT=dalloc<store_t>(MK), *dGq=dalloc<store_t>(MN);
        float *H=dalloc<float>(MN), *G=dalloc<float>(MN), *dGrad=dalloc<float>(MN), *dW=dalloc<float>(KN);
        float *Wf=dalloc<float>(KN);
        float *Wf_s=dalloc<float>(KN), *Mm_s=dalloc<float>(KN), *Vv_s=dalloc<float>(KN);
        float *Wf_f=dalloc<float>(KN), *Mm_f=dalloc<float>(KN), *Vv_f=dalloc<float>(KN);
        float *Wf_d=dalloc<float>(KN), *Mm_d=dalloc<float>(KN), *Vv_d=dalloc<float>(KN);
        auto gB=[&](long long n){ return (int)((n+255)/256); };
        fill_ab<<<gB(MK),256>>>(A,MK,11); fill_ab<<<gB(KN),256>>>(Wq,KN,22);
        fill_f<<<gB(KN),256>>>(Wf,KN,33,0.02f); fill_f<<<gB(MN),256>>>(dGrad,MN,44,0.05f);
        ck(cudaDeviceSynchronize(),"init");

        auto run_separate=[&](float* Wfx,float* Mmx,float* Vvx,int tstep){
            k_gemm<<<grid,BLK>>>(A,Wq,H,M,K,N);
            k_valley<<<grid,BLK>>>(H,G,dGrad,dGq,MN);
            k_transpose<<<grid,BLK>>>(A,AT,M,K);
            k_gemm<<<grid,BLK>>>(AT,dGq,dW,K,M,N);
            k_adamw<<<grid,BLK>>>(dW,Wfx,Mmx,Vvx,KN,tstep);
        };
        auto run_fused=[&](float* Wfx,float* Mmx,float* Vvx,int tstep,bool* launched){
            void* args[]={&A,&Wq,&H,&G,&dGrad,&dW,&Wfx,&Mmx,&Vvx,&AT,&dGq,&M,&K,&N,&tstep};
            cudaError_t e=cudaLaunchCooperativeKernel((void*)fused_step,dim3(grid),dim3(BLK),args,0,0);
            *launched = (e==cudaSuccess);
            if(e!=cudaSuccess) printf("  [B=%d] coop launch FAILED: %s\n",B,cudaGetErrorString(e));
        };

        // correctness: 1 step from same init, fused vs separate
        copy_f<<<gB(KN),256>>>(Wf,Wf_s,KN); zero_f<<<gB(KN),256>>>(Mm_s,KN); zero_f<<<gB(KN),256>>>(Vv_s,KN);
        copy_f<<<gB(KN),256>>>(Wf,Wf_f,KN); zero_f<<<gB(KN),256>>>(Mm_f,KN); zero_f<<<gB(KN),256>>>(Vv_f,KN);
        ck(cudaDeviceSynchronize(),"copy");
        run_separate(Wf_s,Mm_s,Vv_s,1); ck(cudaDeviceSynchronize(),"sep1");
        bool launched=false; run_fused(Wf_f,Mm_f,Vv_f,1,&launched); ck(cudaDeviceSynchronize(),"fus1");
        float *hs=(float*)malloc(KN*sizeof(float)), *hf=(float*)malloc(KN*sizeof(float));
        ck(cudaMemcpy(hs,Wf_s,KN*sizeof(float),cudaMemcpyDeviceToHost),"cp_s");
        ck(cudaMemcpy(hf,Wf_f,KN*sizeof(float),cudaMemcpyDeviceToHost),"cp_f");
        double se=0,sr=0; for(long long i=0;i<KN;i++){ double d=(double)hf[i]-hs[i]; se+=d*d; sr+=(double)hs[i]*hs[i]; }
        double relrms = sqrt(se/(double)KN)/(sqrt(sr/(double)KN)+1e-30);

        // determinism: 2nd fused run from same init
        copy_f<<<gB(KN),256>>>(Wf,Wf_d,KN); zero_f<<<gB(KN),256>>>(Mm_d,KN); zero_f<<<gB(KN),256>>>(Vv_d,KN);
        ck(cudaDeviceSynchronize(),"detinit");
        bool l2=false; run_fused(Wf_d,Mm_d,Vv_d,1,&l2); ck(cudaDeviceSynchronize(),"det");
        float *hd=(float*)malloc(KN*sizeof(float));
        ck(cudaMemcpy(hd,Wf_d,KN*sizeof(float),cudaMemcpyDeviceToHost),"cp_d");
        double maxd=0; for(long long i=0;i<KN;i++){ double d=fabs((double)hd[i]-hf[i]); if(d>maxd)maxd=d; }

        // one-wave-fit: gridNeed for fwd (M-tiles) and bwd (K-tiles)
        long long tilesN=(N+WN-1)/WN;
        long long gridNeed_fwd = ((M+WM-1)/WM)*tilesN;
        long long gridNeed_bwd = ((K+WM-1)/WM)*tilesN;
        long long gridNeedMax = gridNeed_fwd>gridNeed_bwd?gridNeed_fwd:gridNeed_bwd;
        const char* fit = (gridNeedMax<=oneWave) ? "YES" : "NO";
        // grid-stride waves a phase iterates = ceil(gridNeed / grid); util proxy =
        // resident-fill of the LAST (partial) wave averaged over the iterated waves.
        double waves_fwd = ceil((double)gridNeed_fwd/grid);
        double waves_bwd = ceil((double)gridNeed_bwd/grid);
        // util% = mean resident occupancy across the grid-stride iterations:
        // full waves are 100%, the tail wave is (gridNeed mod grid)/grid.
        auto util_of=[&](long long need)->double{
            double w=ceil((double)need/grid);
            double full=w-1.0; double tail=(double)(need-(long long)full*grid)/grid;
            return (full*100.0 + tail*100.0)/w; };
        double util_fwd=util_of(gridNeed_fwd), util_bwd=util_of(gridNeed_bwd);
        double util_mean=(util_fwd+util_bwd)/2.0;

        // MEASURE: full-step wall, fused vs separate
        cudaEvent_t e0,e1; cudaEventCreate(&e0); cudaEventCreate(&e1);
        run_separate(Wf_s,Mm_s,Vv_s,2); bool lw=false; run_fused(Wf_f,Mm_f,Vv_f,2,&lw); ck(cudaDeviceSynchronize(),"warm");
        cudaEventRecord(e0); for(int it=0;it<iters;it++) run_separate(Wf_s,Mm_s,Vv_s,it+3); cudaEventRecord(e1);
        ck(cudaEventSynchronize(e1),"st"); float ms_sep=0; cudaEventElapsedTime(&ms_sep,e0,e1);
        cudaEventRecord(e0); for(int it=0;it<iters;it++){ bool l=false; run_fused(Wf_f,Mm_f,Vv_f,it+3,&l);} cudaEventRecord(e1);
        ck(cudaEventSynchronize(e1),"ft"); float ms_fus=0; cudaEventElapsedTime(&ms_fus,e0,e1);
        double wsep=ms_sep/iters, wfus=ms_fus/iters;

        printf("%-2d %-6lld  fwd=%-6lld     bwd=%-6lld     %-3s(need=%lld/%d)  %7.4f  %7.4f  %6.3fx  util=%5.1f%%(fwd %.0f/bwd %.0f waves)  %.3e  %.3e\n",
               B, M, gridNeed_fwd, gridNeed_bwd, fit, gridNeedMax, grid,
               wsep, wfus, wsep/wfus, util_mean, waves_fwd, waves_bwd, relrms, maxd);
        fflush(stdout);

        free(hs);free(hf);free(hd);
        cudaFree(A);cudaFree(Wq);cudaFree(AT);cudaFree(dGq);cudaFree(H);cudaFree(G);cudaFree(dGrad);cudaFree(dW);
        cudaFree(Wf);cudaFree(Wf_s);cudaFree(Mm_s);cudaFree(Vv_s);cudaFree(Wf_f);cudaFree(Mm_f);cudaFree(Vv_f);
        cudaFree(Wf_d);cudaFree(Mm_d);cudaFree(Vv_d);
        cudaEventDestroy(e0);cudaEventDestroy(e1);
    }
    printf("============================================================\n");
    printf("[FAST-3] batch sweep complete — see self-speedup column vs ~3x FP64 batch-fill cap\n");
    printf("============================================================\n");
    return 0;
}
