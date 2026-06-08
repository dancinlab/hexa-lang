// flame_bench_step_graph.cu — HEXA-BENCH BENCH-6 graph-capture harness.
//
// GOAL: BENCH-3 flattened flame's TF32 gap to a near batch-INVARIANT ~2.0-2.9x vs
// torch and ATTRIBUTED the residual ~2x to "launch/glue/occupancy of the serial DAG —
// a different lever (megakernel/graph-capture), NOT GEMM." That attribution was
// asserted, not tested. BENCH-6 TESTS it honestly: it wraps the per-step kernel
// sequence (cuBLAS-TF32 GEMM + LayerNorm/gelu valley + transpose + cuBLAS-TF32 bwd
// GEMM + AdamW) in a CUDA GRAPH (cudaStreamBeginCapture/EndCapture →
// cudaGraphInstantiate → cudaGraphLaunch) so the whole step replays as ONE graph
// launch, amortizing per-op launch+sync overhead, and measures captured step/s vs
// the un-captured baseline at B=1,2,4,8.
//
//   IF graph-capture cuts the residual ~2x  → the residual lived in LAUNCH overhead.
//   IF graph-capture gives ~1.0x (no change) → cuBLAS GEMM dominates the step time,
//        the elementwise/launch cost is negligible, and the residual ~2x is
//        GEMM-THROUGHPUT (cuBLAS vs torch's inductor-tuned), NOT launch. (closed-neg
//        that PINS the residual to GEMM, the honest outcome BENCH-3 flagged as likely.)
//
// The step DAG is BYTE-FOR-BYTE the same as BENCH-3's cuBLAS-TF32 backend
// (flame_bench_step_og.cu -DGEMM_BACKEND=1). The ONLY difference is HOW the step is
// launched: eager (one cuLaunch per kernel/cublas call) vs replayed from a captured
// graph. Graph capture changes NOTHING mathematically — the GATE is max|delta(W')|=0
// (bit-exact captured-vs-eager) + run-to-run determinism.
//
// PREC: TF32 lane (float storage, fp32 accum) — that is where the gap lives.
//
// Build: see tool/bench/run_bench6.sh.
//   nvcc -arch=sm_120 -O3 -DBENCH_PREC=1 -DUSE_TF32 \
//        -o flame_graph flame_bench_step_graph.cu -lcublas

#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#ifndef BENCH_PREC
#define BENCH_PREC 1            // 1 = FP32/TF32 (float); BENCH-6 uses the TF32 lane
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

// AdamW hyperparameters (fixed -> deterministic) — identical to BENCH-1/3.
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

// --- NAIVE tiled GEMM (BENCH-1 baseline) — used ONLY for the bit-eq reference step ---
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

// ===================== cuBLAS-TF32 GEMM (BENCH-3 best backend) =====================
// gemm_s(stream, C, A, B, M, K, N): C[M,N] = A[M,K] @ B[K,N], row-major, TF32 lane.
// The cublas handle's stream is set so the call records onto the capture stream.
static cublasHandle_t g_cublas = nullptr;
static void gemm_setup(){
    cublasCreate(&g_cublas);
    cublasSetMathMode(g_cublas, CUBLAS_TF32_TENSOR_OP_MATH);
}
static void gemm_s(cudaStream_t s, real* C, const real* A, const real* Bm, int M, int K, int N){
    cublasSetStream(g_cublas, s);
    const float alpha=1.f, beta=0.f;
    // row-major C = A(MxK)@B(KxN) == cublas col-major C^T = B^T@A^T.
    cublasGemmEx(g_cublas, CUBLAS_OP_N, CUBLAS_OP_N,
                 N, M, K,
                 &alpha,
                 Bm, CUDA_R_32F, N,
                 A,  CUDA_R_32F, K,
                 &beta,
                 C,  CUDA_R_32F, N,
                 CUBLAS_COMPUTE_32F_FAST_TF32, CUBLAS_GEMM_DEFAULT_TENSOR_OP);
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
    printf("[CFG] %s GEMM=cuBLAS-TF32 GRAPH-bench  GPU=%s cc=%d.%d  D=%d T=%d B=%d -> M=%d K=%d N=%d  iters=%d  est_mem=%.2f GiB\n",
           PREC_NAME,p.name,p.major,p.minor,D,T,B,M,K,N,iters,gib);

    gemm_setup();

    // dedicated NON-default stream for capture (default stream cannot be captured).
    cudaStream_t st; ck(cudaStreamCreate(&st),"stream");

    real *A=nullptr,*AT=nullptr,*dGq=nullptr,*H=nullptr,*G=nullptr,*dGrad=nullptr,*dW=nullptr,*Wf=nullptr,*Mm=nullptr,*Vv=nullptr;
    auto tryalloc=[&](real**pp,long long n,const char*nm)->bool{
        cudaError_t e=cudaMalloc((void**)pp,n*sizeof(real));
        if(e!=cudaSuccess){ printf("[OOM] alloc %s (%lld elems) failed: %s\n",nm,n,cudaGetErrorString(e)); return false; }
        return true; };
    if(!(tryalloc(&A,MK,"A")&&tryalloc(&AT,MK,"AT")&&tryalloc(&dGq,MN,"dGq")&&tryalloc(&H,MN,"H")
       &&tryalloc(&G,MN,"G")&&tryalloc(&dGrad,MN,"dGrad")&&tryalloc(&dW,KN,"dW")
       &&tryalloc(&Wf,KN,"Wf")&&tryalloc(&Mm,KN,"Mm")&&tryalloc(&Vv,KN,"Vv"))){
        printf("[RESULT] %s GRAPH B=%d OOM\n",PREC_NAME,B); return 3; }
    real *Wf2=dalloc<real>(KN);

    auto gB=[&](long long n){ return (int)((n+255)/256); };
    fill_r<<<gB(MK),256>>>(A,MK,11,0.1);
    fill_r<<<gB(KN),256>>>(Wf,KN,33,0.02);
    fill_r<<<gB(MN),256>>>(dGrad,MN,44,0.05);
    ck(cudaDeviceSynchronize(),"init");

    int eGrid=(int)((KN+255)/256);

    // ---- EAGER step: one launch per op onto stream `st`. tstep baked. ----
    // (Same DAG as BENCH-3 cuBLAS backend; stream-scoped so it is capturable.)
    auto step_eager=[&](cudaStream_t s, int tstep){
        gemm_s(s, H, A, Wf, M, K, N);                       // PHASE 0 fwd  H = A @ W
        k_valley<<<M,256,0,s>>>(H,G,dGrad,dGq,M,N);         // PHASE 1 valley (LN+gelu)
        k_transpose<<<256,256,0,s>>>(A,AT,M,K);             // AT = A^T
        gemm_s(s, dW, AT, dGq, K, M, N);                    // PHASE 2 bwd  dW = A^T @ dG
        k_adamw<<<eGrid,256,0,s>>>(dW,Wf,Mm,Vv,KN,tstep);   // AdamW update
    };

    auto reset_opt=[&](){  // restore Wf to snapshot + zero optimizer state
        copy_r<<<gB(KN),256>>>(Wf2,Wf,KN); zero_r<<<gB(KN),256>>>(Mm,KN); zero_r<<<gB(KN),256>>>(Vv,KN);
        ck(cudaDeviceSynchronize(),"reset-opt");
    };

    // snapshot init weights for repeatable single-step comparisons.
    copy_r<<<gB(KN),256>>>(Wf,Wf2,KN); ck(cudaDeviceSynchronize(),"snap");

    // ============================================================================
    // CAPTURE the per-step kernel sequence into a CUDA graph (tstep fixed = 1).
    // The whole step replays as ONE cudaGraphLaunch.
    // ============================================================================
    cudaGraph_t graph; cudaGraphExec_t gexec;
    reset_opt();
    ck(cudaStreamBeginCapture(st, cudaStreamCaptureModeThreadLocal),"begin-capture");
    step_eager(st, 1);
    ck(cudaStreamEndCapture(st, &graph),"end-capture");
    ck(cudaGraphInstantiate(&gexec, graph, nullptr, nullptr, 0),"instantiate");
    // count nodes for the verdict (how many launches the graph subsumes).
    size_t numNodes=0; cudaGraphGetNodes(graph, nullptr, &numNodes);
    printf("[GRAPH] %s B=%d captured step -> %zu graph nodes (replays as 1 launch)\n",
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

    // ---- GATE: bit-exact captured-vs-EAGER (graph capture changes nothing) ----
    // Run ONE eager step from the SAME snapshot/optimizer state and compare W'.
    reset_opt();
    step_eager(st, 1); ck(cudaStreamSynchronize(st),"eager1");
    real* he=(real*)malloc(KN*sizeof(real)); ck(cudaMemcpy(he,Wf,KN*sizeof(real),cudaMemcpyDeviceToHost),"cpe");
    double gate=0; for(long long i=0;i<KN;i++){ double d=fabs((double)hg1[i]-(double)he[i]); if(d>gate)gate=d; }
    printf("[GATE] %s GRAPH B=%d max|delta(W')| (graph vs EAGER) = %.3e (gate ==0: %s)\n",
           PREC_NAME,B,gate,gate==0.0?"PASS":"FAIL");

    // ============================================================================
    // MEASURE: eager step/s vs graph-replay step/s. iters replays from one snapshot
    // (state evolves the same way in both loops; we measure WALL only, no per-iter
    // sync — the whole loop is one event window, mirroring BENCH-3's measurement).
    // ============================================================================
    cudaEvent_t e0,e1; cudaEventCreate(&e0); cudaEventCreate(&e1);

    // EAGER timing (tstep fixed = 1 so it matches the captured graph's baked tstep;
    // BENCH-3 used a varying tstep but the launch-overhead question is tstep-agnostic
    // and a fixed tstep keeps eager and graph apples-to-apples).
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

    // SPEEDUP graph vs eager — the headline: did graph-capture cut the launch overhead?
    double gspeedup = mse / msg;   // >1 = graph faster
    printf("[SPEEDUP] %s B=%d  graph/eager step/s = %.4fx  (eager %.4f ms -> graph %.4f ms/step)\n",
           PREC_NAME,B,gspeedup,mse,msg);

    free(hg1); free(hg2); free(he);
    cudaGraphExecDestroy(gexec); cudaGraphDestroy(graph);
    return 0;
}
