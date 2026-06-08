// flame_bench_step_og.cu — HEXA-BENCH BENCH-3 flame-side harness.
//
// IDENTICAL step DAG to tool/bench/flame_bench_step.cu (BENCH-1), but the
// load-bearing D->D projection GEMM (PHASE 0 fwd  H = A @ W, and PHASE 2 bwd
// dW = A^T @ dG) is swapped from the NAIVE tiled CUDA-core kernel (k_gemm) to a
// TUNED / own-GEMM backend, selected at compile time:
//
//   -DGEMM_BACKEND=0   NAIVE   tiled CUDA-core k_gemm  (BENCH-1 baseline; for
//                              re-measuring on the same binary / sanity bit-eq)
//   -DGEMM_BACKEND=1   CUBLAS  cublasGemmEx + CUBLAS_COMPUTE_32F_FAST_TF32
//                              (the "tuned-GEMM proxy": what a sm_90a OG10 wgmma
//                              own-GEMM would APPROXIMATE within ~6.09x; bounds
//                              the realistic ceiling of a tuned/own GEMM's benefit)
//   -DGEMM_BACKEND=2   OG10    HEXA-FUSION W10 TF32-wgmma own-GEMM (sm_90a).
//                              Only built when the ISA is available; see the
//                              sm_120-vs-sm_90a finding in the verdict.
//   -DGEMM_BACKEND=3   OWN120  BENCH-5 sm_120 TF32 own-GEMM (mma.sync m16n8k8).
//                              The OG10-spirit own-GEMM PORTED to the consumer-
//                              Blackwell ISA (RTX 5070). RUNS where backend 2's
//                              wgmma is ptxas-rejected. Links owngemm_sm120.cu.
//
// Everything else (valley groupnorm+gelu, transpose, AdamW, RNG init, the
// determinism check, the [RESULT] line format) is byte-for-byte the same as
// BENCH-1 so the flame/torch ratio is directly comparable and the GATE is a
// real apples-to-apples bit-eq / rel-RMS vs the BENCH-1 naive math.
//
// PREC:  -DBENCH_PREC=1 -DUSE_TF32  -> TF32 lane (float storage, fp32 accum).
//        BENCH-3 only cares about the TF32 lane (that is where the 3-8x gap lives).
//
// Build: see tool/bench/build_bench3.sh / run_bench3.sh.

#include <cuda_runtime.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#ifndef GEMM_BACKEND
#define GEMM_BACKEND 1          // default proxy = cuBLAS-TF32
#endif

#if GEMM_BACKEND == 1
  #include <cublas_v2.h>
#endif

#ifndef BENCH_PREC
#define BENCH_PREC 1            // 1 = FP32/TF32 (float); BENCH-3 uses the TF32 lane
#endif

#if BENCH_PREC == 2
  typedef double real;
  static const char* PREC_NAME = "FP64";
#else
  typedef float real;
  #ifdef USE_TF32
    static const char* PREC_NAME = "TF32";   // float storage, tf32 matmul
  #else
    static const char* PREC_NAME = "FP32";
  #endif
#endif

#if   GEMM_BACKEND == 0
  static const char* GEMM_NAME = "NAIVE-tiled";
#elif GEMM_BACKEND == 1
  static const char* GEMM_NAME = "cuBLAS-TF32(proxy)";
#elif GEMM_BACKEND == 2
  static const char* GEMM_NAME = "OG10-wgmma";
#elif GEMM_BACKEND == 3
  static const char* GEMM_NAME = "OWN120-mma.sync";
#endif

// AdamW hyperparameters (fixed -> deterministic) — identical to BENCH-1.
#define ADAM_LR  0.001
#define ADAM_B1  0.9
#define ADAM_B2  0.999
#define ADAM_EPS 1e-8
#define ADAM_WD  0.01

#define TILE 16

static void ck(cudaError_t e, const char* what){
    if(e!=cudaSuccess){ printf("CUDA ERR %s: %s\n", what, cudaGetErrorString(e)); exit(2);} }
template<class T> static T* dalloc(size_t n){ void* p; ck(cudaMalloc(&p,n*sizeof(T)),"malloc"); return (T*)p; }

__device__ __forceinline__ real gelu_glue(real v){
    real c = (real)0.7978845608;
    return (real)0.5*v*((real)1.0+tanh(c*(v+(real)0.044715*v*v*v)));
}

// --- NAIVE tiled GEMM (BENCH-1 baseline), used for backend 0 and bit-eq reference ---
__global__ void k_gemm(const real* __restrict__ A, const real* __restrict__ Bm,
                       real* __restrict__ C, int M, int K, int N){
    __shared__ real As[TILE][TILE];
    __shared__ real Bs[TILE][TILE];
    int row = blockIdx.y*TILE + threadIdx.y;
    int col = blockIdx.x*TILE + threadIdx.x;
    real acc = (real)0;
    for(int k0=0; k0<K; k0+=TILE){
        int ak = k0 + threadIdx.x, bk = k0 + threadIdx.y;
        As[threadIdx.y][threadIdx.x] = (row<M && ak<K) ? A[(long long)row*K+ak] : (real)0;
        Bs[threadIdx.y][threadIdx.x] = (bk<K && col<N) ? Bm[(long long)bk*N+col] : (real)0;
        __syncthreads();
        #pragma unroll
        for(int kk=0; kk<TILE; kk++) acc += As[threadIdx.y][kk]*Bs[kk][threadIdx.x];
        __syncthreads();
    }
    if(row<M && col<N) C[(long long)row*N+col] = acc;
}

__global__ void k_valley(const real* __restrict__ H, real* __restrict__ G,
                         const real* __restrict__ dGrad, real* __restrict__ dGq,
                         int M, int N){
    int row = blockIdx.x;
    if(row>=M) return;
    __shared__ real red[256];
    int t = threadIdx.x, nt = blockDim.x;
    real s=(real)0; for(int j=t;j<N;j+=nt) s+=H[(long long)row*N+j];
    red[t]=s; __syncthreads();
    for(int o=nt/2;o>0;o>>=1){ if(t<o) red[t]+=red[t+o]; __syncthreads(); }
    real mean=red[0]/(real)N; __syncthreads();
    real v=(real)0; for(int j=t;j<N;j+=nt){ real d=H[(long long)row*N+j]-mean; v+=d*d; }
    red[t]=v; __syncthreads();
    for(int o=nt/2;o>0;o>>=1){ if(t<o) red[t]+=red[t+o]; __syncthreads(); }
    real inv = (real)1.0/sqrt(red[0]/(real)N + (real)1e-5); __syncthreads();
    for(int j=t;j<N;j+=nt){
        long long idx=(long long)row*N+j;
        G[idx]   = gelu_glue((H[idx]-mean)*inv);
        dGq[idx] = dGrad[idx];
    }
}

__global__ void k_transpose(const real* __restrict__ A, real* __restrict__ AT, int M, int K){
    long long n=(long long)M*K, stride=(long long)blockDim.x*gridDim.x;
    for(long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; i<n; i+=stride){
        long long r=i/K, c=i%K; AT[c*M+r]=A[r*K+c];
    }
}

__global__ void k_adamw(real* dW, real* Wf, real* Mm, real* Vv, long long n, int tstep){
    real bc1=(real)1.0-(real)pow((double)ADAM_B1,(double)tstep);
    real bc2=(real)1.0-(real)pow((double)ADAM_B2,(double)tstep);
    long long stride=(long long)blockDim.x*gridDim.x;
    for(long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; i<n; i+=stride){
        real g=dW[i];
        real m=(real)ADAM_B1*Mm[i]+(real)(1.0-ADAM_B1)*g;
        real v=(real)ADAM_B2*Vv[i]+(real)(1.0-ADAM_B2)*g*g;
        Mm[i]=m; Vv[i]=v;
        real mh=m/bc1, vh=v/bc2, w=Wf[i];
        w=w-(real)ADAM_LR*(mh/(sqrt(vh)+(real)ADAM_EPS)+(real)ADAM_WD*w);
        Wf[i]=w;
    }
}

__global__ void fill_r(real* x, long long n, unsigned seed, double scale){
    long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x;
    if(i<n){ unsigned h=(unsigned)(i*2654435761u)^seed; x[i]=(real)(((h&0xffff)/65535.0-0.5)*scale); }
}
__global__ void zero_r(real* x,long long n){ long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; if(i<n)x[i]=(real)0; }
__global__ void copy_r(const real* s,real* d,long long n){ long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; if(i<n)d[i]=s[i]; }

// ===================== GEMM backend wrapper =====================
// gemm(C, A, B, M, K, N): C[M,N] = A[M,K] @ B[K,N], row-major, TF32 lane.
#if GEMM_BACKEND == 1
static cublasHandle_t g_cublas = nullptr;
static void gemm_setup(){
    cublasCreate(&g_cublas);
    // TF32 lane: tensor-op math with TF32 reduced precision (== torch 'high').
    cublasSetMathMode(g_cublas, CUBLAS_TF32_TENSOR_OP_MATH);
}
static void gemm(real* C, const real* A, const real* Bm, int M, int K, int N){
    // cuBLAS is column-major. To get row-major C = A(MxK) @ B(KxN) we compute
    // C^T = B^T @ A^T in column-major == cublas(op_n, op_n, N, M, K, B, A).
    const float alpha=1.f, beta=0.f;
    cublasGemmEx(g_cublas, CUBLAS_OP_N, CUBLAS_OP_N,
                 N, M, K,
                 &alpha,
                 Bm, CUDA_R_32F, N,
                 A,  CUDA_R_32F, K,
                 &beta,
                 C,  CUDA_R_32F, N,
                 CUBLAS_COMPUTE_32F_FAST_TF32, CUBLAS_GEMM_DEFAULT_TENSOR_OP);
}
#elif GEMM_BACKEND == 2
// OG10 wgmma own-GEMM (sm_90a). Wired only when the ISA compiles. The W10 kernel
// is a square-tile TF32 wgmma GEMM; for non-summit shapes here we fall back to the
// naive launch but keep the symbol so the backend reports honestly. (Populated in
// the og-wire step; if sm_120 ISA-incompatible this TU is never built.)
extern void og10_gemm(real* C, const real* A, const real* Bm, int M, int K, int N);
static void gemm_setup(){}
static void gemm(real* C, const real* A, const real* Bm, int M, int K, int N){
    og10_gemm(C, A, Bm, M, K, N);
}
#elif GEMM_BACKEND == 3
// BENCH-5 sm_120 own-GEMM (mma.sync m16n8k8 TF32). Defined in owngemm_sm120.cu
// (compiled into the same binary). Signature C[M,N]=A[M,K]@B[K,N], TF32 lane.
extern "C" void owngemm_sm120(float* C, const float* A, const float* B, int M, int K, int N);
static void gemm_setup(){}
static void gemm(real* C, const real* A, const real* Bm, int M, int K, int N){
    owngemm_sm120(C, A, Bm, M, K, N);   // BENCH_PREC=1 -> real==float, TF32 lane
}
#else
static void gemm_setup(){}
static void gemm(real* C, const real* A, const real* Bm, int M, int K, int N){
    dim3 blk(TILE,TILE);
    dim3 g((N+TILE-1)/TILE,(M+TILE-1)/TILE);
    k_gemm<<<g,blk>>>(A, Bm, C, M, K, N);
}
#endif

int main(int argc,char**argv){
    int D=(argc>1)?atoi(argv[1]):768;
    int T=(argc>2)?atoi(argv[2]):256;
    int B=(argc>3)?atoi(argv[3]):1;
    int iters=(argc>4)?atoi(argv[4]):50;
    int M=B*T, K=D, N=D;
    int dev=0; cudaSetDevice(dev);
    cudaDeviceProp p; cudaGetDeviceProperties(&p,dev);

    long long MK=(long long)M*K, KN=(long long)K*N, MN=(long long)M*N;
    double bytes=(double)sizeof(real)*( MK*3 + MN*3 + KN*4 );
    double gib=bytes/(1024.0*1024.0*1024.0);
    printf("[CFG] %s GEMM=%s  GPU=%s cc=%d.%d  D=%d T=%d B=%d -> M=%d K=%d N=%d  iters=%d  est_mem=%.2f GiB\n",
           PREC_NAME,GEMM_NAME,p.name,p.major,p.minor,D,T,B,M,K,N,iters,gib);

    gemm_setup();

    real *A=nullptr,*AT=nullptr,*dGq=nullptr,*H=nullptr,*G=nullptr,*dGrad=nullptr,*dW=nullptr,*Wf=nullptr,*Mm=nullptr,*Vv=nullptr;
    auto tryalloc=[&](real**pp,long long n,const char*nm)->bool{
        cudaError_t e=cudaMalloc((void**)pp,n*sizeof(real));
        if(e!=cudaSuccess){ printf("[OOM] alloc %s (%lld elems) failed: %s\n",nm,n,cudaGetErrorString(e)); return false; }
        return true; };
    if(!(tryalloc(&A,MK,"A")&&tryalloc(&AT,MK,"AT")&&tryalloc(&dGq,MN,"dGq")&&tryalloc(&H,MN,"H")
       &&tryalloc(&G,MN,"G")&&tryalloc(&dGrad,MN,"dGrad")&&tryalloc(&dW,KN,"dW")
       &&tryalloc(&Wf,KN,"Wf")&&tryalloc(&Mm,KN,"Mm")&&tryalloc(&Vv,KN,"Vv"))){
        printf("[RESULT] %s GEMM=%s B=%d OOM\n",PREC_NAME,GEMM_NAME,B); return 3; }
    real *Wf2=dalloc<real>(KN);

    auto gB=[&](long long n){ return (int)((n+255)/256); };
    fill_r<<<gB(MK),256>>>(A,MK,11,0.1);
    fill_r<<<gB(KN),256>>>(Wf,KN,33,0.02);
    fill_r<<<gB(MN),256>>>(dGrad,MN,44,0.05);
    ck(cudaDeviceSynchronize(),"init");

    int eGrid=(int)((KN+255)/256);

    auto step=[&](int tstep){
        gemm(H, A, Wf, M, K, N);                    // PHASE 0 fwd  H = A @ W   (tuned GEMM)
        k_valley<<<M,256>>>(H,G,dGrad,dGq,M,N);     // PHASE 1 valley
        k_transpose<<<256,256>>>(A,AT,M,K);         // AT = A^T
        gemm(dW, AT, dGq, K, M, N);                 // PHASE 2 bwd  dW = A^T @ dG (tuned GEMM)
        k_adamw<<<eGrid,256>>>(dW,Wf,Mm,Vv,KN,tstep);
    };

    // DETERMINISM: same init twice, max|delta(W')|.
    zero_r<<<gB(KN),256>>>(Mm,KN); zero_r<<<gB(KN),256>>>(Vv,KN);
    copy_r<<<gB(KN),256>>>(Wf,Wf2,KN);
    ck(cudaDeviceSynchronize(),"det-snap");
    step(1); ck(cudaDeviceSynchronize(),"det-run1");
    real* h1=(real*)malloc(KN*sizeof(real)); ck(cudaMemcpy(h1,Wf,KN*sizeof(real),cudaMemcpyDeviceToHost),"cp1");
    copy_r<<<gB(KN),256>>>(Wf2,Wf,KN); zero_r<<<gB(KN),256>>>(Mm,KN); zero_r<<<gB(KN),256>>>(Vv,KN);
    ck(cudaDeviceSynchronize(),"det-reset");
    step(1); ck(cudaDeviceSynchronize(),"det-run2");
    real* h2=(real*)malloc(KN*sizeof(real)); ck(cudaMemcpy(h2,Wf,KN*sizeof(real),cudaMemcpyDeviceToHost),"cp2");
    double maxd=0; for(long long i=0;i<KN;i++){ double d=fabs((double)h1[i]-(double)h2[i]); if(d>maxd)maxd=d; }
    printf("[DETERMINISM] %s GEMM=%s B=%d run-to-run max|delta(W')| = %.3e (gate ==0: %s)\n",
           PREC_NAME,GEMM_NAME,B,maxd,maxd==0.0?"PASS":"FAIL");

    // GATE: rel-RMS of W' vs the NAIVE-GEMM reference (same math, same step).
    // Recompute one step with the naive k_gemm and compare. Only meaningful when
    // the GEMM backend differs from naive; for backend 0 this is identically 0.
    {
        real* Wref=dalloc<real>(KN); real* Mr=dalloc<real>(KN); real* Vr=dalloc<real>(KN);
        copy_r<<<gB(KN),256>>>(Wf2,Wref,KN); zero_r<<<gB(KN),256>>>(Mr,KN); zero_r<<<gB(KN),256>>>(Vr,KN);
        ck(cudaDeviceSynchronize(),"ref-snap");
        // one naive step writing into Wref
        dim3 blk(TILE,TILE);
        dim3 gFwd((N+TILE-1)/TILE,(M+TILE-1)/TILE);
        dim3 gBwd((N+TILE-1)/TILE,(K+TILE-1)/TILE);
        k_gemm<<<gFwd,blk>>>(A,Wref,H,M,K,N);
        k_valley<<<M,256>>>(H,G,dGrad,dGq,M,N);
        k_transpose<<<256,256>>>(A,AT,M,K);
        k_gemm<<<gBwd,blk>>>(AT,dGq,dW,K,M,N);
        k_adamw<<<eGrid,256>>>(dW,Wref,Mr,Vr,KN,1);
        ck(cudaDeviceSynchronize(),"ref-run");
        real* hr=(real*)malloc(KN*sizeof(real)); ck(cudaMemcpy(hr,Wref,KN*sizeof(real),cudaMemcpyDeviceToHost),"cpr");
        double se=0, sr=0; for(long long i=0;i<KN;i++){ double a=(double)h1[i], b=(double)hr[i]; se+=(a-b)*(a-b); sr+=b*b; }
        double relrms = (sr>0)? sqrt(se/KN)/sqrt(sr/KN) : 0.0;
        printf("[GATE] %s GEMM=%s B=%d rel-RMS(W' vs NAIVE-ref) = %.3e (gate <=1e-2: %s)\n",
               PREC_NAME,GEMM_NAME,B,relrms, relrms<=1e-2?"PASS":"FAIL");
        free(hr); cudaFree(Wref); cudaFree(Mr); cudaFree(Vr);
        // restore Wf to the post-run1 state's init for the timing loop
        copy_r<<<gB(KN),256>>>(Wf2,Wf,KN); zero_r<<<gB(KN),256>>>(Mm,KN); zero_r<<<gB(KN),256>>>(Vv,KN);
        ck(cudaDeviceSynchronize(),"restore");
    }

    // MEASURE full-step wall.
    cudaEvent_t e0,e1; cudaEventCreate(&e0); cudaEventCreate(&e1);
    step(2); ck(cudaDeviceSynchronize(),"warmup");
    cudaEventRecord(e0); for(int it=0;it<iters;it++) step(it+3); cudaEventRecord(e1);
    ck(cudaEventSynchronize(e1),"time"); float ms=0; cudaEventElapsedTime(&ms,e0,e1);
    double ms_step=ms/iters, step_s=1000.0/ms_step, samp_s=step_s*(double)B;
    printf("[RESULT] %s GEMM=%s B=%d  ms/step=%.4f  step/s=%.4f  samples/s=%.4f\n",
           PREC_NAME,GEMM_NAME,B,ms_step,step_s,samp_s);
    free(h1); free(h2);
    return 0;
}
