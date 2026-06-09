// flame_bench_step_tf32fast.cu — HEXA-0POD OP-20: deterministic TF32 fast-mode probe.
//
// THE UNEXPLORED LEVER (from MEGASTEP memory + flame_h100_h200_closeout): flame's
// training step is ~3x capped at batch=1 by the serial FP64 cuBLAS op-DAG. Kernel-
// fusion / interp-elim / graph-capture are ALL exhausted (closed-neg). The ONLY two
// uncap levers named are (a) PRECISION-CHANGE FP64->TF32 + dense compute-bound fusion,
// (b) right-sized GPU. (a) is unexplored. This harness probes (a) on the FREE 5070.
//
// KEY INSIGHT (the OP-20 thesis): FP64->TF32 breaks byte-eq-vs-FP64, BUT a TF32 step
// can still be byte-eq-vs-ITSELF (run-to-run deterministic). That preserves flame's
// reproducibility IDENTITY at a different PRECISION CONTRACT (the W14 convention:
// rel-rms <= 1e-2 vs same-dtype). So "deterministic TF32 fast-mode" = a legitimate
// flame product mode, not an identity sacrifice -- IF it stays self-byte-eq.
//
// Unlike OP-4's flame_bench_step_fused.cu (which builds ONE precision per binary and
// compares rel-RMS within the SAME dtype), this binary runs BOTH a TF32 step and an
// FP64 step in ONE process so it can report the THREE OP-20 numbers directly:
//   GATE-A  self-byte-eq:   max|delta(W',m',v',loss)| run-to-run for the TF32 step == 0
//   GATE-B  W14 correctness: rel-RMS(TF32 W' vs FP64 W') <= 1e-2
//   SPEED:   TF32 ms/step vs FP64 ms/step -> ratio. Does it break the ~3x FP64 cap?
//
// The step DAG is identical to the OP-4 FUSED lane (fused valley LN+gelu+copy +
// transpose-elim bwd GEMM + single-launch AdamW); only the GEMM compute type differs:
//   TF32 lane = CUDA_R_32F storage, CUBLAS_COMPUTE_32F_FAST_TF32 (tensor-core TF32 math)
//   FP64 lane = CUDA_R_64F storage, CUBLAS_COMPUTE_64F
// All elementwise/reduction glue stays in the FIXED deterministic order (fixed-order
// per-row tree reduce, no atomics) so the only determinism question is whether the
// cuBLAS TF32 tensor-core GEMM is itself run-to-run reproducible (split-K heuristics!).
//
// CUBLAS DETERMINISM TOGGLE: -DPEDANTIC builds with CUBLAS_PEDANTIC_MATH on the TF32
// handle (forces a deterministic, no-heuristic math mode) to test whether the default
// TF32 tensor-op mode is self-byte-eq or NEEDS pedantic to stay reproducible.
//
// Build: nvcc -arch=sm_120 -O3 -o flame_tf32fast flame_bench_step_tf32fast.cu -lcublas
//        add -DPEDANTIC for the pedantic-cublas determinism variant.
// Run:   ./flame_tf32fast D T B iters

#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

// AdamW hyperparameters (fixed -> deterministic) — identical to OP-4 BENCH-10.
#define ADAM_LR  0.001
#define ADAM_B1  0.9
#define ADAM_B2  0.999
#define ADAM_EPS 1e-8
#define ADAM_WD  0.01
#define TILE 16

static void ck(cudaError_t e, const char* what){
    if(e!=cudaSuccess){ printf("CUDA ERR %s: %s\n", what, cudaGetErrorString(e)); exit(2);} }

// ===== generic step templated on the storage type (float for TF32, double for FP64) =====
template<class R>
__device__ __forceinline__ R gelu_glue(R v){
    R c = (R)0.7978845608;
    return (R)0.5*v*((R)1.0+tanh(c*(v+(R)0.044715*v*v*v)));
}

// FF-GN-PARALLEL valley: per-row FIXED-ORDER tree LN reduction + gelu, ONE kernel.
// FF-EPILOGUE folds the dGrad->dGq copy into the SAME pass. No atomics -> deterministic.
template<class R>
__global__ void k_valley(const R* __restrict__ H, R* __restrict__ G,
                         const R* __restrict__ dGrad, R* __restrict__ dGq, int M, int N){
    int row = blockIdx.x; if(row>=M) return;
    __shared__ R red[256];
    int t = threadIdx.x, nt = blockDim.x;
    R s=(R)0; for(int j=t;j<N;j+=nt) s+=H[(long long)row*N+j];
    red[t]=s; __syncthreads();
    for(int o=nt/2;o>0;o>>=1){ if(t<o) red[t]+=red[t+o]; __syncthreads(); }
    R mean=red[0]/(R)N; __syncthreads();
    R v=(R)0; for(int j=t;j<N;j+=nt){ R d=H[(long long)row*N+j]-mean; v+=d*d; }
    red[t]=v; __syncthreads();
    for(int o=nt/2;o>0;o>>=1){ if(t<o) red[t]+=red[t+o]; __syncthreads(); }
    R inv = (R)1.0/sqrt(red[0]/(R)N + (R)1e-5); __syncthreads();
    for(int j=t;j<N;j+=nt){
        long long idx=(long long)row*N+j;
        G[idx]   = gelu_glue<R>((H[idx]-mean)*inv);
        dGq[idx] = dGrad[idx];
    }
}

// FF-FUSED-OPTIM: single-launch fused AdamW over the whole W tensor (deterministic).
template<class R>
__global__ void k_adamw(R* dW, R* Wf, R* Mm, R* Vv, long long n, int tstep){
    R bc1=(R)1.0-(R)pow((double)ADAM_B1,(double)tstep);
    R bc2=(R)1.0-(R)pow((double)ADAM_B2,(double)tstep);
    long long stride=(long long)blockDim.x*gridDim.x;
    for(long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; i<n; i+=stride){
        R g=dW[i];
        R m=(R)ADAM_B1*Mm[i]+(R)(1.0-ADAM_B1)*g;
        R v=(R)ADAM_B2*Vv[i]+(R)(1.0-ADAM_B2)*g*g;
        Mm[i]=m; Vv[i]=v;
        R mh=m/bc1, vh=v/bc2, w=Wf[i];
        w=w-(R)ADAM_LR*(mh/(sqrt(vh)+(R)ADAM_EPS)+(R)ADAM_WD*w);
        Wf[i]=w;
    }
}

template<class R>
__global__ void fill_r(R* x, long long n, unsigned seed, double scale){
    long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x;
    if(i<n){ unsigned h=(unsigned)(i*2654435761u)^seed; x[i]=(R)(((h&0xffff)/65535.0-0.5)*scale); }
}
template<class R> __global__ void zero_r(R* x,long long n){ long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; if(i<n)x[i]=(R)0; }
template<class R> __global__ void copy_r(const R* s,R* d,long long n){ long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; if(i<n)d[i]=s[i]; }

// ===================== one full training step (templated lane) =====================
// gemm_op: row-major C[M,N] = opA(A) @ B[K,N] via col-major C^T = B^T @ opA(A)^T.
// computeType/dataType pick the precision lane. The TF32 lane rides the SAME storage
// (float) but COMPUTE_32F_FAST_TF32 so the tensor-core path is used; FP64 uses double.
template<class R>
struct Lane {
    cublasHandle_t h;
    cudaDataType_t dt;
    cublasComputeType_t ct;
    cublasGemmAlgo_t algo;
};

template<class R>
static void gemm_op(Lane<R>& L, R* C, const R* A, const R* Bm, int M, int K, int N,
                    cublasOperation_t opA, int lda){
    if (sizeof(R)==8){ const double a=1.0,b=0.0;
        cublasGemmEx(L.h, CUBLAS_OP_N, opA, N, M, K, &a, Bm, L.dt, N, A, L.dt, lda, &b,
                     C, L.dt, N, L.ct, L.algo);
    } else { const float a=1.f,b=0.f;
        cublasGemmEx(L.h, CUBLAS_OP_N, opA, N, M, K, &a, Bm, L.dt, N, A, L.dt, lda, &b,
                     C, L.dt, N, L.ct, L.algo);
    }
}
template<class R> static void gemm(Lane<R>& L, R* C, const R* A, const R* Bm, int M,int K,int N){
    gemm_op<R>(L, C, A, Bm, M, K, N, CUBLAS_OP_N, K);
}

// run ONE training step (fwd GEMM -> fused valley -> transpose-elim bwd GEMM -> AdamW)
template<class R>
static void run_step(Lane<R>& L, R* A, R* Wf, R* H, R* G, R* dGrad, R* dGq, R* dW,
                     R* Mm, R* Vv, int M, int K, int N, long long KN, int eGrid, int tstep){
    gemm<R>(L, H, A, Wf, M, K, N);                          // fwd  H = A @ W
    k_valley<R><<<M,256>>>(H,G,dGrad,dGq,M,N);              // fused valley LN+gelu+copy
    gemm_op<R>(L, dW, A, dGq, K, M, N, CUBLAS_OP_T, K);     // bwd dW = A^T @ dGq (transpose-elim)
    k_adamw<R><<<eGrid,256>>>(dW,Wf,Mm,Vv,KN,tstep);        // single-launch AdamW
}

// allocate + init one lane's tensors and return W snapshot for resets.
template<class R>
struct Buf { R *A,*H,*G,*dGrad,*dGq,*dW,*Wf,*Mm,*Vv,*Wsnap; long long MK,MN,KN; };

template<class R>
static bool alloc_lane(Buf<R>& b, int M,int K,int N){
    b.MK=(long long)M*K; b.MN=(long long)M*N; b.KN=(long long)K*N;
    auto A=[&](R**pp,long long n){ return cudaMalloc((void**)pp,n*sizeof(R))==cudaSuccess; };
    return A(&b.A,b.MK)&&A(&b.H,b.MN)&&A(&b.G,b.MN)&&A(&b.dGrad,b.MN)&&A(&b.dGq,b.MN)
         &&A(&b.dW,b.KN)&&A(&b.Wf,b.KN)&&A(&b.Mm,b.KN)&&A(&b.Vv,b.KN)&&A(&b.Wsnap,b.KN);
}
// init with the SAME seeds/scales across lanes so TF32 and FP64 start bit-identical (mod cast).
template<class R>
static void init_lane(Buf<R>& b, int M,int K,int N){
    auto gB=[&](long long n){ return (int)((n+255)/256); };
    fill_r<R><<<gB(b.MK),256>>>(b.A,b.MK,11,0.1);
    fill_r<R><<<gB(b.KN),256>>>(b.Wf,b.KN,33,0.02);
    fill_r<R><<<gB(b.MN),256>>>(b.dGrad,b.MN,44,0.05);
    copy_r<R><<<gB(b.KN),256>>>(b.Wf,b.Wsnap,b.KN);
    zero_r<R><<<gB(b.KN),256>>>(b.Mm,b.KN); zero_r<R><<<gB(b.KN),256>>>(b.Vv,b.KN);
    ck(cudaDeviceSynchronize(),"init_lane");
}
template<class R>
static void reset_lane(Buf<R>& b){
    auto gB=[&](long long n){ return (int)((n+255)/256); };
    copy_r<R><<<gB(b.KN),256>>>(b.Wsnap,b.Wf,b.KN);
    zero_r<R><<<gB(b.KN),256>>>(b.Mm,b.KN); zero_r<R><<<gB(b.KN),256>>>(b.Vv,b.KN);
    ck(cudaDeviceSynchronize(),"reset_lane");
}

int main(int argc,char**argv){
    int D=(argc>1)?atoi(argv[1]):768;
    int T=(argc>2)?atoi(argv[2]):256;
    int B=(argc>3)?atoi(argv[3]):1;
    int iters=(argc>4)?atoi(argv[4]):50;
    int M=B*T, K=D, N=D;
    long long KN=(long long)K*N;
    int eGrid=(int)((KN+255)/256);
    cudaSetDevice(0);
    cudaDeviceProp p; cudaGetDeviceProperties(&p,0);

#ifdef PEDANTIC
    const char* MODE_NAME="TF32-PEDANTIC";
#else
    const char* MODE_NAME="TF32-DEFAULT";
#endif
    printf("[CFG] OP-20 %s  GPU=%s cc=%d.%d  D=%d T=%d B=%d -> M=%d K=%d N=%d iters=%d\n",
           MODE_NAME,p.name,p.major,p.minor,D,T,B,M,K,N,iters);

    // ---- TF32 lane ----
    Lane<float> Lt; cublasCreate(&Lt.h);
#ifdef PEDANTIC
    cublasSetMathMode(Lt.h, CUBLAS_PEDANTIC_MATH);   // deterministic, no split-K heuristics
#else
    cublasSetMathMode(Lt.h, CUBLAS_TF32_TENSOR_OP_MATH);
#endif
    Lt.dt=CUDA_R_32F; Lt.ct=CUBLAS_COMPUTE_32F_FAST_TF32; Lt.algo=CUBLAS_GEMM_DEFAULT_TENSOR_OP;

    // ---- FP64 lane (the reference precision) ----
    Lane<double> Lf; cublasCreate(&Lf.h);
    cublasSetMathMode(Lf.h, CUBLAS_DEFAULT_MATH);
    Lf.dt=CUDA_R_64F; Lf.ct=CUBLAS_COMPUTE_64F; Lf.algo=CUBLAS_GEMM_DEFAULT;

    Buf<float> bt; Buf<double> bf;
    if(!alloc_lane<float>(bt,M,K,N) || !alloc_lane<double>(bf,M,K,N)){
        printf("[RESULT] OP-20 %s B=%d D=%d OOM\n",MODE_NAME,B,D); return 3; }
    init_lane<float>(bt,M,K,N); init_lane<double>(bf,M,K,N);

    // ===== GATE-A : TF32 self-byte-eq run-to-run (same seed). max|delta(W')| must be 0. =====
    reset_lane<float>(bt);
    run_step<float>(Lt,bt.A,bt.Wf,bt.H,bt.G,bt.dGrad,bt.dGq,bt.dW,bt.Mm,bt.Vv,M,K,N,KN,eGrid,1);
    ck(cudaDeviceSynchronize(),"tf32-run1");
    float* w1=(float*)malloc(KN*sizeof(float)); ck(cudaMemcpy(w1,bt.Wf,KN*sizeof(float),cudaMemcpyDeviceToHost),"cp-w1");
    reset_lane<float>(bt);
    run_step<float>(Lt,bt.A,bt.Wf,bt.H,bt.G,bt.dGrad,bt.dGq,bt.dW,bt.Mm,bt.Vv,M,K,N,KN,eGrid,1);
    ck(cudaDeviceSynchronize(),"tf32-run2");
    float* w2=(float*)malloc(KN*sizeof(float)); ck(cudaMemcpy(w2,bt.Wf,KN*sizeof(float),cudaMemcpyDeviceToHost),"cp-w2");
    double maxd=0; for(long long i=0;i<KN;i++){ double d=fabs((double)w1[i]-(double)w2[i]); if(d>maxd)maxd=d; }
    printf("[GATE-A] %s D=%d B=%d  TF32 run-to-run max|delta(W')| = %.3e  (self-byte-eq ==0: %s)\n",
           MODE_NAME,D,B,maxd, maxd==0.0?"PASS":"FAIL");

    // ===== GATE-B : rel-RMS(TF32 W' vs FP64 W') <= 1e-2 (W14 cross-precision tolerance) =====
    reset_lane<double>(bf);
    run_step<double>(Lf,bf.A,bf.Wf,bf.H,bf.G,bf.dGrad,bf.dGq,bf.dW,bf.Mm,bf.Vv,M,K,N,KN,eGrid,1);
    ck(cudaDeviceSynchronize(),"fp64-run");
    double* wd=(double*)malloc(KN*sizeof(double)); ck(cudaMemcpy(wd,bf.Wf,KN*sizeof(double),cudaMemcpyDeviceToHost),"cp-wd");
    double se=0,sr=0; for(long long i=0;i<KN;i++){ double a=(double)w1[i], b=wd[i]; se+=(a-b)*(a-b); sr+=b*b; }
    double relrms = (sr>0)? sqrt(se/KN)/sqrt(sr/KN) : 0.0;
    printf("[GATE-B] %s D=%d B=%d  rel-RMS(TF32 vs FP64 W') = %.3e  (W14 <=1e-2: %s)\n",
           MODE_NAME,D,B,relrms, relrms<=1e-2?"PASS":"FAIL");

    // ===== SPEED : TF32 ms/step vs FP64 ms/step. ratio = FP64_ms / TF32_ms (>1 = TF32 faster). =====
    auto time_lane_tf32=[&]()->double{
        reset_lane<float>(bt);
        run_step<float>(Lt,bt.A,bt.Wf,bt.H,bt.G,bt.dGrad,bt.dGq,bt.dW,bt.Mm,bt.Vv,M,K,N,KN,eGrid,2);
        ck(cudaDeviceSynchronize(),"tf32-warm");
        cudaEvent_t e0,e1; cudaEventCreate(&e0); cudaEventCreate(&e1);
        cudaEventRecord(e0);
        for(int it=0;it<iters;it++) run_step<float>(Lt,bt.A,bt.Wf,bt.H,bt.G,bt.dGrad,bt.dGq,bt.dW,bt.Mm,bt.Vv,M,K,N,KN,eGrid,it+3);
        cudaEventRecord(e1); ck(cudaEventSynchronize(e1),"tf32-time");
        float ms=0; cudaEventElapsedTime(&ms,e0,e1); return ms/iters; };
    auto time_lane_fp64=[&]()->double{
        reset_lane<double>(bf);
        run_step<double>(Lf,bf.A,bf.Wf,bf.H,bf.G,bf.dGrad,bf.dGq,bf.dW,bf.Mm,bf.Vv,M,K,N,KN,eGrid,2);
        ck(cudaDeviceSynchronize(),"fp64-warm");
        cudaEvent_t e0,e1; cudaEventCreate(&e0); cudaEventCreate(&e1);
        cudaEventRecord(e0);
        for(int it=0;it<iters;it++) run_step<double>(Lf,bf.A,bf.Wf,bf.H,bf.G,bf.dGrad,bf.dGq,bf.dW,bf.Mm,bf.Vv,M,K,N,KN,eGrid,it+3);
        cudaEventRecord(e1); ck(cudaEventSynchronize(e1),"fp64-time");
        float ms=0; cudaEventElapsedTime(&ms,e0,e1); return ms/iters; };

    double tf32_ms=time_lane_tf32();
    double fp64_ms=time_lane_fp64();
    double ratio = (tf32_ms>0)? fp64_ms/tf32_ms : 0.0;   // how many x faster TF32 is than FP64
    printf("[SPEED] %s D=%d B=%d  TF32 ms/step=%.4f  FP64 ms/step=%.4f  speedup(FP64/TF32)=%.3fx\n",
           MODE_NAME,D,B,tf32_ms,fp64_ms,ratio);
    printf("[RESULT] OP-20 %s D=%d B=%d  selfByteEq=%s  relRMSvsFP64=%.3e  TF32_ms=%.4f  FP64_ms=%.4f  FP64/TF32=%.3fx\n",
           MODE_NAME,D,B, maxd==0.0?"Y":"N", relrms, tf32_ms, fp64_ms, ratio);

    free(w1); free(w2); free(wd);
    return 0;
}
