// flame_bench_step.cu — HEXA-BENCH BENCH-1 flame-side harness.
//
// The flame CLMConvMoE whole-train-step, reduced to its load-bearing structure
// (same DAG as tool/fast2/fast2_fused_step.cu, the FAST-2 deliverable), but with
// a BATCH dimension and an FP64 path so it can be compared FAIRLY against a
// PyTorch equivalent across a matched-dtype batch sweep.
//
// Step DAG (per batch element, device-resident, no host round-trip):
//   PHASE 0  fwd GEMM    H = A @ W           (own-GEMM, A[B*T, D] @ W[D, D])
//   PHASE 1  groupnorm-ish + gelu valley     G = gelu(gn(H))      (FF-VALLEY)
//   PHASE 2  bwd GEMM    dW = A^T @ dG        (atomic-free, fixed accum order)
//   PHASE 3  AdamW       W' = adamw(W, dW)    (FF-FUSED-OPTIM)
//
// This is NOT the wmma own-GEMM summit kernel — it is a CUDA-core tiled GEMM so
// the SAME source compiles at FP64 (no TF32/BF16 tensor-core dtype) and at FP32
// (the "TF32" lane: float storage + tf32-precision matmul on Blackwell via
// -DUSE_TF32, which sets matmul accumulation to float = the consumer-Blackwell
// equivalent of torch.set_float32_matmul_precision('high')). The point of
// BENCH-1 is the flame÷torch RATIO at matched dtype + batch, not the kernel summit.
//
// PREC selected at compile time:  -DBENCH_PREC=1 -> FP32/TF32 path (float)
//                                 -DBENCH_PREC=2 -> FP64 path (double)
//
// Metrics emitted (machine-greppable): per (dtype,B):
//   ms/step, step/s, samples/s (= B * step/s). flame is byte-exact/deterministic —
//   we also emit a run-to-run max|delta| == 0 determinism check.
//
// Build: see tool/bench/build_flame_bench.sh.

#include <cuda_runtime.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#ifndef BENCH_PREC
#define BENCH_PREC 1            // 1 = FP32/TF32 (float), 2 = FP64 (double)
#endif

#if BENCH_PREC == 2
  typedef double real;
  static const char* PREC_NAME = "FP64";
#else
  typedef float real;
  #ifdef USE_TF32
    static const char* PREC_NAME = "TF32";   // float storage, fp32 accum ('high')
  #else
    static const char* PREC_NAME = "FP32";
  #endif
#endif

// AdamW hyperparameters (fixed -> deterministic)
#define ADAM_LR  0.001
#define ADAM_B1  0.9
#define ADAM_B2  0.999
#define ADAM_EPS 1e-8
#define ADAM_WD  0.01

#define TILE 16                 // tiled shared-memory GEMM, fixed K order

static void ck(cudaError_t e, const char* what){
    if(e!=cudaSuccess){ printf("CUDA ERR %s: %s\n", what, cudaGetErrorString(e)); exit(2);} }
template<class T> static T* dalloc(size_t n){ void* p; ck(cudaMalloc(&p,n*sizeof(T)),"malloc"); return (T*)p; }

__device__ __forceinline__ real gelu_glue(real v){
    real c = (real)0.7978845608;
    return (real)0.5*v*((real)1.0+tanh(c*(v+(real)0.044715*v*v*v)));
}

// Tiled GEMM  C[M,N] = A[M,K] @ B[K,N], fixed ascending-K accumulation.
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

// groupnorm-ish (per-row mean/var normalize) + gelu valley. One block per row.
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

int main(int argc,char**argv){
    int D=(argc>1)?atoi(argv[1]):768;
    int T=(argc>2)?atoi(argv[2]):256;
    int B=(argc>3)?atoi(argv[3]):1;
    int iters=(argc>4)?atoi(argv[4]):50;
    int M=B*T, K=D, N=D;       // batch folds into GEMM M: A[B*T, D] @ W[D, D]
    int dev=0; cudaSetDevice(dev);
    cudaDeviceProp p; cudaGetDeviceProperties(&p,dev);

    long long MK=(long long)M*K, KN=(long long)K*N, MN=(long long)M*N;
    double bytes=(double)sizeof(real)*( MK*3 + MN*3 + KN*4 );
    double gib=bytes/(1024.0*1024.0*1024.0);
    printf("[CFG] %s  GPU=%s cc=%d.%d  D=%d T=%d B=%d -> M=%d K=%d N=%d  iters=%d  est_mem=%.2f GiB\n",
           PREC_NAME,p.name,p.major,p.minor,D,T,B,M,K,N,iters,gib);

    real *A=nullptr,*AT=nullptr,*dGq=nullptr,*H=nullptr,*G=nullptr,*dGrad=nullptr,*dW=nullptr,*Wf=nullptr,*Mm=nullptr,*Vv=nullptr;
    auto tryalloc=[&](real**pp,long long n,const char*nm)->bool{
        cudaError_t e=cudaMalloc((void**)pp,n*sizeof(real));
        if(e!=cudaSuccess){ printf("[OOM] alloc %s (%lld elems) failed: %s\n",nm,n,cudaGetErrorString(e)); return false; }
        return true; };
    if(!(tryalloc(&A,MK,"A")&&tryalloc(&AT,MK,"AT")&&tryalloc(&dGq,MN,"dGq")&&tryalloc(&H,MN,"H")
       &&tryalloc(&G,MN,"G")&&tryalloc(&dGrad,MN,"dGrad")&&tryalloc(&dW,KN,"dW")
       &&tryalloc(&Wf,KN,"Wf")&&tryalloc(&Mm,KN,"Mm")&&tryalloc(&Vv,KN,"Vv"))){
        printf("[RESULT] %s B=%d OOM\n",PREC_NAME,B); return 3; }
    real *Wf2=dalloc<real>(KN);

    auto gB=[&](long long n){ return (int)((n+255)/256); };
    fill_r<<<gB(MK),256>>>(A,MK,11,0.1);
    fill_r<<<gB(KN),256>>>(Wf,KN,33,0.02);
    fill_r<<<gB(MN),256>>>(dGrad,MN,44,0.05);
    ck(cudaDeviceSynchronize(),"init");

    dim3 blk(TILE,TILE);
    dim3 gFwd((N+TILE-1)/TILE,(M+TILE-1)/TILE);
    dim3 gBwd((N+TILE-1)/TILE,(K+TILE-1)/TILE);
    int eGrid=(int)((KN+255)/256);

    auto step=[&](int tstep){
        k_gemm<<<gFwd,blk>>>(A,Wf,H,M,K,N);
        k_valley<<<M,256>>>(H,G,dGrad,dGq,M,N);
        k_transpose<<<256,256>>>(A,AT,M,K);
        k_gemm<<<gBwd,blk>>>(AT,dGq,dW,K,M,N);
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
    printf("[DETERMINISM] %s B=%d run-to-run max|delta(W')| = %.3e (gate ==0: %s)\n",
           PREC_NAME,B,maxd,maxd==0.0?"PASS":"FAIL");

    // MEASURE full-step wall.
    cudaEvent_t e0,e1; cudaEventCreate(&e0); cudaEventCreate(&e1);
    step(2); ck(cudaDeviceSynchronize(),"warmup");
    cudaEventRecord(e0); for(int it=0;it<iters;it++) step(it+3); cudaEventRecord(e1);
    ck(cudaEventSynchronize(e1),"time"); float ms=0; cudaEventElapsedTime(&ms,e0,e1);
    double ms_step=ms/iters, step_s=1000.0/ms_step, samp_s=step_s*(double)B;
    printf("[RESULT] %s B=%d  ms/step=%.4f  step/s=%.4f  samples/s=%.4f\n",
           PREC_NAME,B,ms_step,step_s,samp_s);
    free(h1); free(h2);
    return 0;
}
