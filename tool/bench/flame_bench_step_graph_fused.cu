// flame_bench_step_graph_fused.cu — HEXA-0POD OP-4b graph-captured FUSED step harness.
//
// OP-4 mapped the flame FUSED training step (flame_bench_step_fused.cu -DFUSED: fused
// valley LN+gelu+copy + single-launch AdamW + transpose-elim, GEMM=cuBLAS) vs torch on
// the consumer RTX 5070 (sm_120) and found flame LOSES every cell, WORST at SMALL B
// (B=1) where the GEMM is tiny and the step wall is dominated by per-launch + separate-
// cuBLAS-handle overhead (TF32 1.78x->8.96x as D grows; BF16 up to 14.66x @D=2048/B=1).
// torch.compile/inductor fuses the whole step into ~2 kernels AND graph-captures it via
// inductor's cudagraph trees, so it pays the launch floor ~once.
//
// OP-4b attacks that launch floor on flame's side: wrap the SAME fused per-step kernel
// DAG (cuBLAS fwd GEMM + fused valley + cuBLAS OP_T bwd GEMM (transpose-elim) + fused
// AdamW) in a CUDA GRAPH (cudaStreamBeginCapture/EndCapture -> cudaGraphInstantiate ->
// cudaGraphLaunch) so the whole step replays as ONE graph launch, amortizing the per-op
// launch+sync overhead. Re-measure the worst small-B cells (B=1, D={768,1536,2048},
// TF32+BF16) vs the un-captured (eager) fused step and vs torch.compile.
//
//   IF graph-capture cuts the small-B floor (graph << eager) -> the floor lived in
//        per-launch overhead; the residual narrows toward torch.compile.
//   IF graph-capture gives ~1.0x (graph == eager) -> the launch floor was NOT the
//        binding cost on this card; the small-B loss is cuBLAS GEMM-rate-bound, NOT
//        launch (same as the H100 BENCH-6 finding). HONEST closed-neg pinning the loss.
//
// The step DAG is BYTE-FOR-BYTE the FUSED step of flame_bench_step_fused.cu -DFUSED.
// The ONLY difference is HOW it is launched: eager (one launch per op) vs replayed from
// a captured graph. Graph capture changes NOTHING mathematically.
//   GATE g5: max|delta(W')| = 0 (graph-captured vs eager, SAME snapshot/opt-state) +
//            run-to-run determinism max|delta(W')| = 0.
//
// PREC:  -DBENCH_PREC=1 -DUSE_TF32            -> TF32 lane (float, COMPUTE_32F_FAST_TF32)
//        -DBENCH_PREC=1 -DUSE_TF32 -DLANE_BF16-> BF16 lane (cast to 16BF, COMPUTE_32F)
//        -DBENCH_PREC=2                       -> FP64 lane (double, COMPUTE_64F)
//
// Build/driver: tool/bench/run_op4b_5070.sh.

#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#ifndef BENCH_PREC
#define BENCH_PREC 1
#endif

#if BENCH_PREC == 2
  typedef double real;
  static const char* PREC_NAME = "FP64";
#else
  typedef float real;
  #if defined(LANE_BF16)
    static const char* PREC_NAME = "BF16";
  #elif defined(USE_TF32)
    static const char* PREC_NAME = "TF32";
  #else
    static const char* PREC_NAME = "FP32";
  #endif
#endif

#if defined(LANE_BF16)
  #include <cuda_bf16.h>
#endif

// AdamW hyperparameters (fixed -> deterministic) — identical to OP-4 fused harness.
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

// --- NAIVE tiled GEMM: bit-eq reference only (the timed step uses cuBLAS). ---
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

// FF-GN-PARALLEL valley: per-row fixed-order tree LN reduction + gelu, ONE kernel.
// FF-EPILOGUE: folds the dGrad->dGq copy into the SAME pass (no separate copy kernel).
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
        dGq[idx] = dGrad[idx];                       // FF-EPILOGUE: copy fused into valley
    }
}

__global__ void k_transpose(const real* __restrict__ A, real* __restrict__ AT, int M, int K){
    long long n=(long long)M*K, stride=(long long)blockDim.x*gridDim.x;
    for(long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; i<n; i+=stride){
        long long r=i/K, c=i%K; AT[c*M+r]=A[r*K+c];
    }
}

// FF-FUSED-OPTIM: single-launch fused AdamW over the whole W tensor.
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

// ===================== cuBLAS GEMM wrapper (stream-scoped for capture) =====================
static cublasHandle_t g_cublas = nullptr;
#if defined(LANE_BF16)
static __nv_bfloat16 *g_Ab=nullptr,*g_Bb=nullptr; static long long g_nA=0,g_nB=0;
__global__ void k_f2bf(const float* __restrict__ s, __nv_bfloat16* __restrict__ d, long long n){
    long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; if(i<n) d[i]=__float2bfloat16(s[i]); }
#endif

static void gemm_setup(){
    cublasCreate(&g_cublas);
#if BENCH_PREC == 2
    cublasSetMathMode(g_cublas, CUBLAS_DEFAULT_MATH);            // FP64
#elif defined(LANE_BF16)
    cublasSetMathMode(g_cublas, CUBLAS_DEFAULT_MATH);            // BF16 via 16BF inputs
#else
    cublasSetMathMode(g_cublas, CUBLAS_TF32_TENSOR_OP_MATH);     // TF32 ('high')
#endif
}

// row-major C[M,N] = opA(A)[M,K] @ B[K,N] on stream `s`. opA toggles transpose-elim.
static void gemm_op_s(cudaStream_t s, real* C, const real* A, const real* Bm,
                      int M, int K, int N, cublasOperation_t opA, int lda){
    cublasSetStream(g_cublas, s);
#if BENCH_PREC == 2
    const double alpha=1.0, beta=0.0;
    cublasGemmEx(g_cublas, CUBLAS_OP_N, opA, N, M, K, &alpha,
                 Bm, CUDA_R_64F, N, A, CUDA_R_64F, lda, &beta,
                 C, CUDA_R_64F, N, CUBLAS_COMPUTE_64F, CUBLAS_GEMM_DEFAULT);
#elif defined(LANE_BF16)
    long long nA=(long long)M*K, nB=(long long)K*N;
    if(nA>g_nA){ if(g_Ab)cudaFree(g_Ab); cudaMalloc(&g_Ab,nA*sizeof(__nv_bfloat16)); g_nA=nA; }
    if(nB>g_nB){ if(g_Bb)cudaFree(g_Bb); cudaMalloc(&g_Bb,nB*sizeof(__nv_bfloat16)); g_nB=nB; }
    k_f2bf<<<(nA+255)/256,256,0,s>>>(A, g_Ab, nA);
    k_f2bf<<<(nB+255)/256,256,0,s>>>(Bm, g_Bb, nB);
    const float alpha=1.f, beta=0.f;
    cublasGemmEx(g_cublas, CUBLAS_OP_N, opA, N, M, K, &alpha,
                 g_Bb, CUDA_R_16BF, N, g_Ab, CUDA_R_16BF, lda, &beta,
                 C, CUDA_R_32F, N, CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP);
#else
    const float alpha=1.f, beta=0.f;
    cublasGemmEx(g_cublas, CUBLAS_OP_N, opA, N, M, K, &alpha,
                 Bm, CUDA_R_32F, N, A, CUDA_R_32F, lda, &beta,
                 C, CUDA_R_32F, N, CUBLAS_COMPUTE_32F_FAST_TF32, CUBLAS_GEMM_DEFAULT_TENSOR_OP);
#endif
}
static void gemm_s(cudaStream_t s, real* C, const real* A, const real* Bm, int M, int K, int N){
    gemm_op_s(s, C, A, Bm, M, K, N, CUBLAS_OP_N, K);
}

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
    printf("[CFG] %s GRAPH-FUSED  GPU=%s cc=%d.%d  D=%d T=%d B=%d -> M=%d K=%d N=%d  iters=%d  est_mem=%.2f GiB\n",
           PREC_NAME,p.name,p.major,p.minor,D,T,B,M,K,N,iters,gib);

    gemm_setup();
    cudaStream_t st; ck(cudaStreamCreate(&st),"stream");

    real *A=nullptr,*AT=nullptr,*dGq=nullptr,*H=nullptr,*G=nullptr,*dGrad=nullptr,*dW=nullptr,*Wf=nullptr,*Mm=nullptr,*Vv=nullptr;
    auto tryalloc=[&](real**pp,long long n,const char*nm)->bool{
        cudaError_t e=cudaMalloc((void**)pp,n*sizeof(real));
        if(e!=cudaSuccess){ printf("[OOM] alloc %s (%lld elems) failed: %s\n",nm,n,cudaGetErrorString(e)); return false; }
        return true; };
    if(!(tryalloc(&A,MK,"A")&&tryalloc(&AT,MK,"AT")&&tryalloc(&dGq,MN,"dGq")&&tryalloc(&H,MN,"H")
       &&tryalloc(&G,MN,"G")&&tryalloc(&dGrad,MN,"dGrad")&&tryalloc(&dW,KN,"dW")
       &&tryalloc(&Wf,KN,"Wf")&&tryalloc(&Mm,KN,"Mm")&&tryalloc(&Vv,KN,"Vv"))){
        printf("[RESULT] %s GRAPH-FUSED B=%d OOM\n",PREC_NAME,B); return 3; }
    real *Wf2=dalloc<real>(KN);

    auto gB=[&](long long n){ return (int)((n+255)/256); };
    fill_r<<<gB(MK),256>>>(A,MK,11,0.1);
    fill_r<<<gB(KN),256>>>(Wf,KN,33,0.02);
    fill_r<<<gB(MN),256>>>(dGrad,MN,44,0.05);
    ck(cudaDeviceSynchronize(),"init");

    int eGrid=(int)((KN+255)/256);

    // ---- EAGER FUSED step on stream `s` (capturable). transpose-elim: bwd dW=A^T@dGq
    // via cuBLAS OP_T on A directly (no materialized A^T). SAME math as OP-4 -DFUSED. ----
    auto step_eager=[&](cudaStream_t s, int tstep){
        gemm_s(s, H, A, Wf, M, K, N);                          // PHASE 0 fwd  H = A @ W
        k_valley<<<M,256,0,s>>>(H,G,dGrad,dGq,M,N);            // PHASE 1 fused valley
        gemm_op_s(s, dW, A, dGq, K, M, N, CUBLAS_OP_T, K);     // PHASE 2 bwd dW=A^T@dGq (transpose-elim)
        k_adamw<<<eGrid,256,0,s>>>(dW,Wf,Mm,Vv,KN,tstep);      // FF-FUSED-OPTIM single-launch AdamW
    };

    auto reset_opt=[&](){  // restore Wf to snapshot + zero optimizer state
        copy_r<<<gB(KN),256>>>(Wf2,Wf,KN); zero_r<<<gB(KN),256>>>(Mm,KN); zero_r<<<gB(KN),256>>>(Vv,KN);
        ck(cudaDeviceSynchronize(),"reset-opt");
    };

    // snapshot init weights for repeatable single-step comparisons.
    copy_r<<<gB(KN),256>>>(Wf,Wf2,KN); ck(cudaDeviceSynchronize(),"snap");

    // For BF16, the cast scratch (g_Ab/g_Bb) is lazily allocated on first GEMM call —
    // a cudaMalloc is NOT capturable. Warm the eager path ONCE pre-capture so the
    // scratch exists before BeginCapture (capture then sees only kernels + cublas).
    reset_opt();
    step_eager(st, 1); ck(cudaStreamSynchronize(st),"prewarm-scratch");

    // ============================================================================
    // CAPTURE the fused per-step DAG into a CUDA graph (tstep fixed = 1).
    // The whole step replays as ONE cudaGraphLaunch.
    // ============================================================================
    cudaGraph_t graph; cudaGraphExec_t gexec;
    reset_opt();
    ck(cudaStreamBeginCapture(st, cudaStreamCaptureModeThreadLocal),"begin-capture");
    step_eager(st, 1);
    ck(cudaStreamEndCapture(st, &graph),"end-capture");
    ck(cudaGraphInstantiate(&gexec, graph, nullptr, nullptr, 0),"instantiate");
    size_t numNodes=0; cudaGraphGetNodes(graph, nullptr, &numNodes);
    printf("[GRAPH] %s B=%d captured fused step -> %zu graph nodes (replays as 1 launch)\n",
           PREC_NAME,B,numNodes);

    // ---- DETERMINISM (graph path): same init twice, replay graph once each ----
    reset_opt();
    ck(cudaGraphLaunch(gexec, st),"glaunch-det1"); ck(cudaStreamSynchronize(st),"gsync-det1");
    real* hg1=(real*)malloc(KN*sizeof(real)); ck(cudaMemcpy(hg1,Wf,KN*sizeof(real),cudaMemcpyDeviceToHost),"cpg1");
    reset_opt();
    ck(cudaGraphLaunch(gexec, st),"glaunch-det2"); ck(cudaStreamSynchronize(st),"gsync-det2");
    real* hg2=(real*)malloc(KN*sizeof(real)); ck(cudaMemcpy(hg2,Wf,KN*sizeof(real),cudaMemcpyDeviceToHost),"cpg2");
    double gdet=0; for(long long i=0;i<KN;i++){ double d=fabs((double)hg1[i]-(double)hg2[i]); if(d>gdet)gdet=d; }
    printf("[DETERMINISM] %s GRAPH B=%d run-to-run max|delta(W')| = %.3e (gate ==0: %s)\n",
           PREC_NAME,B,gdet,gdet==0.0?"PASS":"FAIL");

    // ---- GATE g5: bit-exact captured-vs-EAGER (graph capture changes nothing) ----
    // Run ONE eager fused step from the SAME snapshot/optimizer state and compare W'.
    reset_opt();
    step_eager(st, 1); ck(cudaStreamSynchronize(st),"eager1");
    real* he=(real*)malloc(KN*sizeof(real)); ck(cudaMemcpy(he,Wf,KN*sizeof(real),cudaMemcpyDeviceToHost),"cpe");
    double gate=0; for(long long i=0;i<KN;i++){ double d=fabs((double)hg1[i]-(double)he[i]); if(d>gate)gate=d; }
    printf("[GATE] %s GRAPH B=%d max|delta(W')| (graph vs EAGER fused) = %.3e (gate ==0: %s)\n",
           PREC_NAME,B,gate,gate==0.0?"PASS":"FAIL");

    // ============================================================================
    // MEASURE: eager fused step/s vs graph-replay step/s. iters replays from one
    // snapshot; one event window per loop (matches OP-4's measurement methodology).
    // ============================================================================
    cudaEvent_t e0,e1; cudaEventCreate(&e0); cudaEventCreate(&e1);

    // EAGER timing (tstep fixed = 1, matching the captured graph's baked tstep).
    reset_opt();
    step_eager(st, 1); ck(cudaStreamSynchronize(st),"warm-eager");  // warmup
    cudaEventRecord(e0, st); for(int it=0;it<iters;it++) step_eager(st, 1); cudaEventRecord(e1, st);
    ck(cudaStreamSynchronize(st),"time-eager"); float ms_e=0; cudaEventElapsedTime(&ms_e,e0,e1);
    double mse=ms_e/iters, steps_e=1000.0/mse;
    printf("[RESULT] %s EAGER B=%d  ms/step=%.4f  step/s=%.4f  samples/s=%.4f\n",
           PREC_NAME,B,mse,steps_e,steps_e*(double)B);

    // GRAPH timing (replay the captured graph `iters` times).
    reset_opt();
    ck(cudaGraphLaunch(gexec, st),"warm-graph"); ck(cudaStreamSynchronize(st),"warm-graph-sync"); // warmup
    cudaEventRecord(e0, st); for(int it=0;it<iters;it++) ck(cudaGraphLaunch(gexec, st),"glaunch"); cudaEventRecord(e1, st);
    ck(cudaStreamSynchronize(st),"time-graph"); float ms_g=0; cudaEventElapsedTime(&ms_g,e0,e1);
    double msg=ms_g/iters, steps_g=1000.0/msg;
    printf("[RESULT] %s GRAPH B=%d  ms/step=%.4f  step/s=%.4f  samples/s=%.4f\n",
           PREC_NAME,B,msg,steps_g,steps_g*(double)B);

    // SPEEDUP graph vs eager — the headline: did graph-capture cut the launch floor?
    double gspeedup = mse / msg;   // >1 = graph faster
    printf("[SPEEDUP] %s B=%d  graph/eager = %.4fx  (eager %.4f ms -> graph %.4f ms/step)\n",
           PREC_NAME,B,gspeedup,mse,msg);

    free(hg1); free(hg2); free(he);
    cudaGraphExecDestroy(gexec); cudaGraphDestroy(graph);
    return 0;
}
