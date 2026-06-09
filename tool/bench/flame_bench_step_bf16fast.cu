// flame_bench_step_bf16fast.cu — HEXA-0POD OP-25: deterministic BF16 fast-mode probe.
//
// THE NEXT RUNG of the precision-uncap ladder (OP-20 TF32 + OP-23 TF32-drift validated):
// the flame training step's ~3x FP64 cap (batch=1, serial cuBLAS op-DAG) was broken by a
// deterministic TF32 fast-mode (self-byte-eq run-to-run, rel-RMS ~1.1e-6 vs FP64, 4.2x+
// faster). The precision/speed/accuracy Pareto so far: FP64(exact,1x) -> TF32(e-6,4.2x).
// OP-25 probes the NEXT precision rung: BF16. BF16 has an 8-bit mantissa (vs TF32's 10-bit)
// so it is LESS accurate (rel-RMS ~e-3 expected) but POTENTIALLY faster (or same speed but
// half the GEMM input memory traffic). The question: is a deterministic BF16 STEP fast-mode
//   (a) self-byte-eq run-to-run (BF16 tensor-op may have its own split-K nondeterminism ->
//       does PEDANTIC fix it, like TF32 needed checking?),
//   (b) within the W14 1e-2 training tolerance vs FP64 (e-3 is looser than TF32 but inside
//       1e-2 -> still trainable?),
//   (c) FASTER than TF32, or SAME-SPEED (both 16-bit-input tensor-ops -> the 5070 may give
//       BF16 and TF32 the SAME tensor throughput -> BF16 may NOT be faster, just less
//       accurate = DOMINATED by TF32). That same-throughput-DOMINATED outcome is the likely
//       HONEST finding on a consumer card; if so we report it as the closed result (TF32 the
//       precision-uncap sweet spot). If BF16 IS faster (half mem traffic helping the memory-
//       bound glue) it is a NEW rung.
//
// This binary runs ALL THREE lanes (BF16, TF32, FP64) in ONE process so it can report the
// OP-25 numbers directly:
//   GATE-A  BF16 self-byte-eq:  max|delta(W')| run-to-run for the BF16 step == 0
//   GATE-B  W14 correctness:    rel-RMS(BF16 W' vs FP64 W') <= 1e-2
//   SPEED:  BF16 ms/step vs FP64 ms/step (ratio) AND BF16 ms/step vs TF32 ms/step (ratio)
//
// Lane storage / compute (the only thing that differs across lanes):
//   BF16 lane = CUDA_R_16BF storage, CUBLAS_COMPUTE_32F_FAST_16BF (BF16-input fp32-accum)
//   TF32 lane = CUDA_R_32F  storage, CUBLAS_COMPUTE_32F_FAST_TF32 (TF32-input fp32-accum)
//   FP64 lane = CUDA_R_64F  storage, CUBLAS_COMPUTE_64F           (fp64)
// All elementwise/reduction glue runs in a FIXED deterministic order (fixed-order per-row
// tree reduce, no atomics). For the BF16 lane the glue ACCUMULATES IN FP32 (the storage is
// bf16 but reductions promote to float) — that is the standard mixed-precision contract and
// matches how a real BF16 trainer behaves; only the GEMM inputs are bf16. The only
// determinism question is whether the cuBLAS BF16 tensor-core GEMM is run-to-run
// reproducible (split-K heuristics), same as the TF32 question OP-20 answered.
//
// CUBLAS DETERMINISM TOGGLE: -DPEDANTIC builds with CUBLAS_PEDANTIC_MATH on the BF16 + TF32
// handles to test whether the default tensor-op mode needs pedantic to stay self-byte-eq.
//
// Build: nvcc -arch=sm_120 -O3 -o flame_bf16fast flame_bench_step_bf16fast.cu -lcublas
//        add -DPEDANTIC for the pedantic-cublas determinism variant.
// Run:   ./flame_bf16fast D T B iters

#include <cuda_runtime.h>
#include <cuda_bf16.h>
#include <cublas_v2.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

// AdamW hyperparameters (fixed -> deterministic) — identical to OP-20.
#define ADAM_LR  0.001
#define ADAM_B1  0.9
#define ADAM_B2  0.999
#define ADAM_EPS 1e-8
#define ADAM_WD  0.01

static void ck(cudaError_t e, const char* what){
    if(e!=cudaSuccess){ printf("CUDA ERR %s: %s\n", what, cudaGetErrorString(e)); exit(2);} }

// ====== precision traits: storage type R, fp32-or-fp64 ACCUM type Acc for the glue ======
// FP64 lane: R=double, Acc=double.  TF32 lane: R=float, Acc=float.  BF16 lane: R=bf16, Acc=float.
template<class R> struct Acc        { typedef double type; };
template<>        struct Acc<float> { typedef float  type; };
template<>        struct Acc<__nv_bfloat16> { typedef float type; };

template<class A> __device__ __forceinline__ A gelu_acc(A v){
    A c=(A)0.7978845608;
    return (A)0.5*v*((A)1.0+(A)tanh((double)(c*(v+(A)0.044715*v*v*v))));
}

// load/store helpers that promote the storage type to the accum type and back.
template<class R> __device__ __forceinline__ typename Acc<R>::type ld(const R* p, long long i){ return (typename Acc<R>::type)p[i]; }
template<> __device__ __forceinline__ float ld<__nv_bfloat16>(const __nv_bfloat16* p, long long i){ return __bfloat162float(p[i]); }
template<class R> __device__ __forceinline__ void st(R* p, long long i, typename Acc<R>::type v){ p[i]=(R)v; }
template<> __device__ __forceinline__ void st<__nv_bfloat16>(__nv_bfloat16* p, long long i, float v){ p[i]=__float2bfloat16(v); }

// FF-GN-PARALLEL valley: per-row FIXED-ORDER tree LN reduction (in Acc) + gelu, ONE kernel.
// FF-EPILOGUE folds the dGrad->dGq copy into the SAME pass. No atomics -> deterministic.
template<class R>
__global__ void k_valley(const R* __restrict__ H, R* __restrict__ G,
                         const R* __restrict__ dGrad, R* __restrict__ dGq, int M, int N){
    typedef typename Acc<R>::type A;
    int row=blockIdx.x; if(row>=M) return;
    __shared__ A red[256];
    int t=threadIdx.x, nt=blockDim.x;
    A s=(A)0; for(int j=t;j<N;j+=nt) s+=ld<R>(H,(long long)row*N+j);
    red[t]=s; __syncthreads();
    for(int o=nt/2;o>0;o>>=1){ if(t<o) red[t]+=red[t+o]; __syncthreads(); }
    A mean=red[0]/(A)N; __syncthreads();
    A v=(A)0; for(int j=t;j<N;j+=nt){ A d=ld<R>(H,(long long)row*N+j)-mean; v+=d*d; }
    red[t]=v; __syncthreads();
    for(int o=nt/2;o>0;o>>=1){ if(t<o) red[t]+=red[t+o]; __syncthreads(); }
    A inv=(A)1.0/(A)sqrt((double)(red[0]/(A)N+(A)1e-5)); __syncthreads();
    for(int j=t;j<N;j+=nt){
        long long idx=(long long)row*N+j;
        st<R>(G,   idx, gelu_acc<A>((ld<R>(H,idx)-mean)*inv));
        st<R>(dGq, idx, ld<R>(dGrad,idx));
    }
}

// FF-FUSED-OPTIM: single-launch fused AdamW. The MASTER weights W/m/v are kept in the ACCUM
// precision (fp32 for BF16/TF32, fp64 for FP64) — the standard mixed-precision contract: the
// optimizer state is NOT bf16. The bf16 lane writes a bf16 copy Wlp for the next GEMM.
template<class R>
__global__ void k_adamw(const R* dWs, typename Acc<R>::type* Wf,
                        typename Acc<R>::type* Mm, typename Acc<R>::type* Vv,
                        R* Wlp, long long n, int tstep){
    typedef typename Acc<R>::type A;
    A bc1=(A)1.0-(A)pow((double)ADAM_B1,(double)tstep);
    A bc2=(A)1.0-(A)pow((double)ADAM_B2,(double)tstep);
    long long stride=(long long)blockDim.x*gridDim.x;
    for(long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; i<n; i+=stride){
        A g=ld<R>(dWs,i);
        A m=(A)ADAM_B1*Mm[i]+(A)(1.0-ADAM_B1)*g;
        A v=(A)ADAM_B2*Vv[i]+(A)(1.0-ADAM_B2)*g*g;
        Mm[i]=m; Vv[i]=v;
        A mh=m/bc1, vh=v/bc2, w=Wf[i];
        w=w-(A)ADAM_LR*(mh/((A)sqrt((double)vh)+(A)ADAM_EPS)+(A)ADAM_WD*w);
        Wf[i]=w;                 // master weight (accum precision)
        st<R>(Wlp,i,w);          // low-precision copy for the next fwd GEMM
    }
}

// init kernels (write the STORAGE type)
template<class R> __global__ void fill_r(R* x, long long n, unsigned seed, double scale){
    long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x;
    if(i<n){ unsigned h=(unsigned)(i*2654435761u)^seed; double val=((h&0xffff)/65535.0-0.5)*scale; st<R>(x,i,(typename Acc<R>::type)val); }
}
template<class R> __global__ void fillacc(typename Acc<R>::type* x, long long n, unsigned seed, double scale){
    long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x;
    if(i<n){ unsigned h=(unsigned)(i*2654435761u)^seed; x[i]=(typename Acc<R>::type)(((h&0xffff)/65535.0-0.5)*scale); }
}
template<class R> __global__ void copyacc(const typename Acc<R>::type* s, R* d, long long n){
    long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; if(i<n) st<R>(d,i,s[i]); }
template<class T> __global__ void zero_t(T* x,long long n){ long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; if(i<n)x[i]=(T)0; }
template<class T> __global__ void copy_t(const T* s,T* d,long long n){ long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; if(i<n)d[i]=s[i]; }

// ===================== lane descriptor =====================
template<class R>
struct Lane { cublasHandle_t h; cudaDataType_t dt; cublasComputeType_t ct; cublasGemmAlgo_t algo; };

// gemm_op: row-major C[M,N] = opA(A) @ B[K,N] via col-major C^T = B^T @ opA(A)^T.
// alpha/beta are in the COMPUTE precision (fp32 for BF16/TF32, fp64 for FP64).
template<class R>
static void gemm_op(Lane<R>& L, R* C, const R* A, const R* Bm, int M, int K, int N,
                    cublasOperation_t opA, int lda){
    if (L.ct==CUBLAS_COMPUTE_64F){ const double a=1.0,b=0.0;
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

// ============ tensors: storage (R) + accum master state (Acc) ============
template<class R>
struct Buf {
    typedef typename Acc<R>::type A;
    R *Astor,*Wlp,*H,*G,*dGrad,*dGq,*dW;   // STORAGE-precision tensors (GEMM in/out)
    A *Wf,*Mm,*Vv,*Wsnap;                   // master AdamW state (accum precision)
    long long MK,MN,KN;
};

template<class R>
static bool alloc_lane(Buf<R>& b, int M,int K,int N){
    typedef typename Acc<R>::type A;
    b.MK=(long long)M*K; b.MN=(long long)M*N; b.KN=(long long)K*N;
    auto AR=[&](R**pp,long long n){ return cudaMalloc((void**)pp,n*sizeof(R))==cudaSuccess; };
    auto AA=[&](A**pp,long long n){ return cudaMalloc((void**)pp,n*sizeof(A))==cudaSuccess; };
    return AR(&b.Astor,b.MK)&&AR(&b.Wlp,b.KN)&&AR(&b.H,b.MN)&&AR(&b.G,b.MN)&&AR(&b.dGrad,b.MN)
         &&AR(&b.dGq,b.MN)&&AR(&b.dW,b.KN)
         &&AA(&b.Wf,b.KN)&&AA(&b.Mm,b.KN)&&AA(&b.Vv,b.KN)&&AA(&b.Wsnap,b.KN);
}
// init with the SAME seeds/scales across lanes so all three start bit-identical (mod cast).
template<class R>
static void init_lane(Buf<R>& b, int M,int K,int N){
    auto gB=[&](long long n){ return (int)((n+255)/256); };
    fill_r<R><<<gB(b.MK),256>>>(b.Astor,b.MK,11,0.1);
    fillacc<R><<<gB(b.KN),256>>>(b.Wf,b.KN,33,0.02);
    copyacc<R><<<gB(b.KN),256>>>(b.Wf,b.Wlp,b.KN);
    fill_r<R><<<gB(b.MN),256>>>(b.dGrad,b.MN,44,0.05);
    copy_t<typename Acc<R>::type><<<gB(b.KN),256>>>(b.Wf,b.Wsnap,b.KN);
    zero_t<typename Acc<R>::type><<<gB(b.KN),256>>>(b.Mm,b.KN);
    zero_t<typename Acc<R>::type><<<gB(b.KN),256>>>(b.Vv,b.KN);
    ck(cudaDeviceSynchronize(),"init_lane");
}
template<class R>
static void reset_lane(Buf<R>& b){
    auto gB=[&](long long n){ return (int)((n+255)/256); };
    copy_t<typename Acc<R>::type><<<gB(b.KN),256>>>(b.Wsnap,b.Wf,b.KN);
    copyacc<R><<<gB(b.KN),256>>>(b.Wf,b.Wlp,b.KN);
    zero_t<typename Acc<R>::type><<<gB(b.KN),256>>>(b.Mm,b.KN);
    zero_t<typename Acc<R>::type><<<gB(b.KN),256>>>(b.Vv,b.KN);
    ck(cudaDeviceSynchronize(),"reset_lane");
}

// run ONE training step (fwd GEMM -> fused valley -> transpose-elim bwd GEMM -> AdamW)
template<class R>
static void run_step(Buf<R>& b, Lane<R>& L, int M,int K,int N,long long KN,int eGrid,int tstep){
    gemm<R>(L, b.H, b.Astor, b.Wlp, M, K, N);                       // fwd  H = A @ Wlp
    k_valley<R><<<M,256>>>(b.H,b.G,b.dGrad,b.dGq,M,N);             // fused valley LN+gelu+copy
    gemm_op<R>(L, b.dW, b.Astor, b.dGq, K, M, N, CUBLAS_OP_T, K);  // bwd dW = A^T @ dGq
    k_adamw<R><<<eGrid,256>>>(b.dW,b.Wf,b.Mm,b.Vv,b.Wlp,KN,tstep); // single-launch AdamW
}

// copy the master weight Wf (accum precision) to a host double buffer (canonical W' compare).
template<class R>
static void wf_to_host(Buf<R>& b, double* out, long long KN){
    typedef typename Acc<R>::type A;
    A* tmp=(A*)malloc(KN*sizeof(A));
    ck(cudaMemcpy(tmp,b.Wf,KN*sizeof(A),cudaMemcpyDeviceToHost),"wf2host");
    for(long long i=0;i<KN;i++) out[i]=(double)tmp[i];
    free(tmp);
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
    const char* MODE_NAME="BF16-PEDANTIC";
#else
    const char* MODE_NAME="BF16-DEFAULT";
#endif
    printf("[CFG] OP-25 %s  GPU=%s cc=%d.%d  D=%d T=%d B=%d -> M=%d K=%d N=%d iters=%d\n",
           MODE_NAME,p.name,p.major,p.minor,D,T,B,M,K,N,iters);

    // ---- BF16 lane ----
    Lane<__nv_bfloat16> Lb; cublasCreate(&Lb.h);
#ifdef PEDANTIC
    cublasSetMathMode(Lb.h, CUBLAS_PEDANTIC_MATH);
#else
    cublasSetMathMode(Lb.h, CUBLAS_DEFAULT_MATH);   // BF16 tensor-op is the default for 16BF compute
#endif
    Lb.dt=CUDA_R_16BF; Lb.ct=CUBLAS_COMPUTE_32F_FAST_16BF; Lb.algo=CUBLAS_GEMM_DEFAULT_TENSOR_OP;

    // ---- TF32 lane (the OP-20 validated fast-mode, to compare BF16 speed against) ----
    Lane<float> Lt; cublasCreate(&Lt.h);
#ifdef PEDANTIC
    cublasSetMathMode(Lt.h, CUBLAS_PEDANTIC_MATH);
#else
    cublasSetMathMode(Lt.h, CUBLAS_TF32_TENSOR_OP_MATH);
#endif
    Lt.dt=CUDA_R_32F; Lt.ct=CUBLAS_COMPUTE_32F_FAST_TF32; Lt.algo=CUBLAS_GEMM_DEFAULT_TENSOR_OP;

    // ---- FP64 lane (the reference precision) ----
    Lane<double> Lf; cublasCreate(&Lf.h);
    cublasSetMathMode(Lf.h, CUBLAS_DEFAULT_MATH);
    Lf.dt=CUDA_R_64F; Lf.ct=CUBLAS_COMPUTE_64F; Lf.algo=CUBLAS_GEMM_DEFAULT;

    Buf<__nv_bfloat16> bb; Buf<float> bt; Buf<double> bf;
    if(!alloc_lane<__nv_bfloat16>(bb,M,K,N) || !alloc_lane<float>(bt,M,K,N) || !alloc_lane<double>(bf,M,K,N)){
        printf("[RESULT] OP-25 %s B=%d D=%d OOM\n",MODE_NAME,B,D); return 3; }
    init_lane<__nv_bfloat16>(bb,M,K,N); init_lane<float>(bt,M,K,N); init_lane<double>(bf,M,K,N);

    double* w1=(double*)malloc(KN*sizeof(double));
    double* w2=(double*)malloc(KN*sizeof(double));
    double* wd=(double*)malloc(KN*sizeof(double));
    double* wt=(double*)malloc(KN*sizeof(double));

    // ===== GATE-A : BF16 self-byte-eq run-to-run (same seed). max|delta(W')| must be 0. =====
    reset_lane<__nv_bfloat16>(bb);
    run_step<__nv_bfloat16>(bb,Lb,M,K,N,KN,eGrid,1);
    ck(cudaDeviceSynchronize(),"bf16-run1");
    wf_to_host<__nv_bfloat16>(bb,w1,KN);
    reset_lane<__nv_bfloat16>(bb);
    run_step<__nv_bfloat16>(bb,Lb,M,K,N,KN,eGrid,1);
    ck(cudaDeviceSynchronize(),"bf16-run2");
    wf_to_host<__nv_bfloat16>(bb,w2,KN);
    double maxd=0; for(long long i=0;i<KN;i++){ double d=fabs(w1[i]-w2[i]); if(d>maxd)maxd=d; }
    printf("[GATE-A] %s D=%d B=%d  BF16 run-to-run max|delta(W')| = %.3e  (self-byte-eq ==0: %s)\n",
           MODE_NAME,D,B,maxd, maxd==0.0?"PASS":"FAIL");

    // ===== GATE-B : rel-RMS(BF16 W' vs FP64 W') <= 1e-2 (W14 cross-precision tolerance) =====
    reset_lane<double>(bf);
    run_step<double>(bf,Lf,M,K,N,KN,eGrid,1);
    ck(cudaDeviceSynchronize(),"fp64-run");
    wf_to_host<double>(bf,wd,KN);
    double se=0,sr=0; for(long long i=0;i<KN;i++){ double a=w1[i], b=wd[i]; se+=(a-b)*(a-b); sr+=b*b; }
    double relrms = (sr>0)? sqrt(se/KN)/sqrt(sr/KN) : 0.0;
    printf("[GATE-B] %s D=%d B=%d  rel-RMS(BF16 vs FP64 W') = %.3e  (W14 <=1e-2: %s)\n",
           MODE_NAME,D,B,relrms, relrms<=1e-2?"PASS":"FAIL");

    // ===== reference: rel-RMS(TF32 vs FP64) so the verdict reports BF16-vs-TF32 accuracy gap =====
    reset_lane<float>(bt);
    run_step<float>(bt,Lt,M,K,N,KN,eGrid,1);
    ck(cudaDeviceSynchronize(),"tf32-run");
    wf_to_host<float>(bt,wt,KN);
    double se2=0,sr2=0; for(long long i=0;i<KN;i++){ double a=wt[i], b=wd[i]; se2+=(a-b)*(a-b); sr2+=b*b; }
    double relrms_tf32 = (sr2>0)? sqrt(se2/KN)/sqrt(sr2/KN) : 0.0;
    printf("[REF] %s D=%d B=%d  rel-RMS(TF32 vs FP64 W') = %.3e\n", MODE_NAME,D,B,relrms_tf32);

    // ===== SPEED : BF16 vs TF32 vs FP64 ms/step. Timed loops, warmed. =====
    auto time_bf16=[&]()->double{
        reset_lane<__nv_bfloat16>(bb);
        run_step<__nv_bfloat16>(bb,Lb,M,K,N,KN,eGrid,2);
        ck(cudaDeviceSynchronize(),"bf16-warm");
        cudaEvent_t e0,e1; cudaEventCreate(&e0); cudaEventCreate(&e1);
        cudaEventRecord(e0);
        for(int it=0;it<iters;it++) run_step<__nv_bfloat16>(bb,Lb,M,K,N,KN,eGrid,it+3);
        cudaEventRecord(e1); ck(cudaEventSynchronize(e1),"bf16-time");
        float ms=0; cudaEventElapsedTime(&ms,e0,e1); return ms/iters; };
    auto time_tf32=[&]()->double{
        reset_lane<float>(bt);
        run_step<float>(bt,Lt,M,K,N,KN,eGrid,2);
        ck(cudaDeviceSynchronize(),"tf32-warm");
        cudaEvent_t e0,e1; cudaEventCreate(&e0); cudaEventCreate(&e1);
        cudaEventRecord(e0);
        for(int it=0;it<iters;it++) run_step<float>(bt,Lt,M,K,N,KN,eGrid,it+3);
        cudaEventRecord(e1); ck(cudaEventSynchronize(e1),"tf32-time");
        float ms=0; cudaEventElapsedTime(&ms,e0,e1); return ms/iters; };
    auto time_fp64=[&]()->double{
        reset_lane<double>(bf);
        run_step<double>(bf,Lf,M,K,N,KN,eGrid,2);
        ck(cudaDeviceSynchronize(),"fp64-warm");
        cudaEvent_t e0,e1; cudaEventCreate(&e0); cudaEventCreate(&e1);
        cudaEventRecord(e0);
        for(int it=0;it<iters;it++) run_step<double>(bf,Lf,M,K,N,KN,eGrid,it+3);
        cudaEventRecord(e1); ck(cudaEventSynchronize(e1),"fp64-time");
        float ms=0; cudaEventElapsedTime(&ms,e0,e1); return ms/iters; };

    double bf16_ms=time_bf16();
    double tf32_ms=time_tf32();
    double fp64_ms=time_fp64();
    double r_bf_fp = (bf16_ms>0)? fp64_ms/bf16_ms : 0.0;   // BF16 vs FP64 (>1 = BF16 faster)
    double r_bf_tf = (bf16_ms>0)? tf32_ms/bf16_ms : 0.0;   // BF16 vs TF32 (>1 = BF16 faster than TF32)
    printf("[SPEED] %s D=%d B=%d  BF16=%.4f  TF32=%.4f  FP64=%.4f ms/step  FP64/BF16=%.3fx  TF32/BF16=%.3fx\n",
           MODE_NAME,D,B,bf16_ms,tf32_ms,fp64_ms,r_bf_fp,r_bf_tf);
    printf("[RESULT] OP-25 %s D=%d B=%d  selfByteEq=%s  relRMSvsFP64=%.3e  relRMS_TF32=%.3e  BF16_ms=%.4f  TF32_ms=%.4f  FP64_ms=%.4f  FP64/BF16=%.3fx  TF32/BF16=%.3fx\n",
           MODE_NAME,D,B, maxd==0.0?"Y":"N", relrms, relrms_tf32, bf16_ms, tf32_ms, fp64_ms, r_bf_fp, r_bf_tf);

    free(w1); free(w2); free(wd); free(wt);
    return 0;
}
