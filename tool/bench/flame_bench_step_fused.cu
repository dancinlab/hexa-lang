// flame_bench_step_fused.cu — HEXA-BENCH BENCH-10 fused-glue flame harness.
//
// BENCH-6 refuted graph-capture and BENCH-9 refuted GEMM-autotune as the closer for
// the LAST flame-cuBLAS losing cell D=4096/B=8; BOTH pinned the residual to flame's
// UN-FUSED elementwise/optimizer glue: the per-step DAG ran SEPARATE kernels
//   k_valley (LN-reduction + gelu)  +  k_transpose (A -> A^T)  +  k_adamw
// each making a full pass over the large 4096x4096 tensors, while torch.compile/
// inductor FUSES LN+gelu+loss+AdamW into a few kernels around the two cuBLAS GEMMs
// and nearly HALVES its eager time. The GEMM is IDENTICAL (both ride cuBLAS); the gap
// is the glue.
//
// BENCH-10 wires flame's EXISTING HEXA-FLAME-FAST fused kernels into the bench step:
//   - FF-GN-PARALLEL : the fused fixed-order parallel-tree LN reduction (deterministic,
//                      no atomics, bit-reproducible) — the valley's LN+gelu stays ONE
//                      kernel (already a per-row tree reduce; -DFUSED keeps it but folds
//                      the dGrad copy in the same pass = FF-EPILOGUE elementwise fusion).
//   - FF-FUSED-OPTIM : single-launch AdamW (already 1 launch here; -DFUSED keeps it).
//   - TRANSPOSE-ELIM : the decisive new lever. The separate k_transpose full-MN
//                      read+write pass (pure overhead inductor never does) is REMOVED:
//                      the bwd GEMM dW = A^T @ dGq is computed with cuBLAS OP_T on A
//                      directly (no materialized A^T). This drops one full elementwise
//                      pass over A from every step — the inductor-style fusion of the
//                      transpose into the matmul.
//
// The GEMM = cuBLAS(Lt) — the winning lane (BENCH-9). -DFUSED toggles the fused glue
// path vs the BENCH-9 un-fused baseline so the SAME binary measures both head-to-head.
//
// PREC:   -DBENCH_PREC=1 -DUSE_TF32 -> TF32 lane (float, COMPUTE_32F_FAST_TF32)
//         -DBENCH_PREC=1 -DUSE_TF32 -DLANE_BF16 -> BF16 lane (cast to 16BF, COMPUTE_32F)
//         -DBENCH_PREC=2 -> FP64 lane (double, COMPUTE_64F)
// FUSE:   -DFUSED   -> fused valley+AdamW + transpose-elim (BENCH-10 attack)
//         (default) -> BENCH-9 un-fused baseline (separate k_transpose) for head-to-head.
//
// GATE g5: determinism run-to-run max|delta(W')|=0 + rel-RMS(W' vs un-fused NAIVE ref)
//          <=1e-2 (fusion is a structural transform; rel-RMS ~ machine-eps). The fused
//          and un-fused W' are compared in the SAME binary so the bit-faithfulness of
//          the fusion is checked directly.
//
// Build/driver: tool/bench/run_bench10.sh.

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

#ifdef FUSED
  static const char* FUSE_NAME = "FUSED(valley+adamw+transpose-elim)";
#else
  static const char* FUSE_NAME = "UNFUSED(BENCH-9 baseline)";
#endif

// AdamW hyperparameters (fixed -> deterministic) — identical to BENCH-1/9.
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

// ===================== cuBLAS GEMM wrapper (the winning lane) =====================
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

// row-major C[M,N] = opA(A)[M,K] @ B[K,N]. cuBLAS is col-major: compute C^T = B^T @ opA(A)^T
// == cublas(OP_N, opA, N, M, K, B, A). transA toggles whether A is read transposed (used
// by transpose-elim: A stored [K,M] read as [M,K] via OP_T => no materialized A^T).
static void gemm_op(real* C, const real* A, const real* Bm, int M, int K, int N,
                    cublasOperation_t opA, int lda){
#if BENCH_PREC == 2
    const double alpha=1.0, beta=0.0;
    cublasGemmEx(g_cublas, CUBLAS_OP_N, opA, N, M, K, &alpha,
                 Bm, CUDA_R_64F, N, A, CUDA_R_64F, lda, &beta,
                 C, CUDA_R_64F, N, CUBLAS_COMPUTE_64F, CUBLAS_GEMM_DEFAULT);
#elif defined(LANE_BF16)
    long long nA=(long long)M*K, nB=(long long)K*N;
    if(nA>g_nA){ if(g_Ab)cudaFree(g_Ab); cudaMalloc(&g_Ab,nA*sizeof(__nv_bfloat16)); g_nA=nA; }
    if(nB>g_nB){ if(g_Bb)cudaFree(g_Bb); cudaMalloc(&g_Bb,nB*sizeof(__nv_bfloat16)); g_nB=nB; }
    k_f2bf<<<(nA+255)/256,256>>>(A, g_Ab, nA);
    k_f2bf<<<(nB+255)/256,256>>>(Bm, g_Bb, nB);
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
// plain C[M,N] = A[M,K] @ B[K,N]
static void gemm(real* C, const real* A, const real* Bm, int M, int K, int N){
    gemm_op(C, A, Bm, M, K, N, CUBLAS_OP_N, K);
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
    printf("[CFG] %s %s  GPU=%s cc=%d.%d  D=%d T=%d B=%d -> M=%d K=%d N=%d  iters=%d  est_mem=%.2f GiB\n",
           PREC_NAME,FUSE_NAME,p.name,p.major,p.minor,D,T,B,M,K,N,iters,gib);

    gemm_setup();

    real *A=nullptr,*AT=nullptr,*dGq=nullptr,*H=nullptr,*G=nullptr,*dGrad=nullptr,*dW=nullptr,*Wf=nullptr,*Mm=nullptr,*Vv=nullptr;
    auto tryalloc=[&](real**pp,long long n,const char*nm)->bool{
        cudaError_t e=cudaMalloc((void**)pp,n*sizeof(real));
        if(e!=cudaSuccess){ printf("[OOM] alloc %s (%lld elems) failed: %s\n",nm,n,cudaGetErrorString(e)); return false; }
        return true; };
    if(!(tryalloc(&A,MK,"A")&&tryalloc(&AT,MK,"AT")&&tryalloc(&dGq,MN,"dGq")&&tryalloc(&H,MN,"H")
       &&tryalloc(&G,MN,"G")&&tryalloc(&dGrad,MN,"dGrad")&&tryalloc(&dW,KN,"dW")
       &&tryalloc(&Wf,KN,"Wf")&&tryalloc(&Mm,KN,"Mm")&&tryalloc(&Vv,KN,"Vv"))){
        printf("[RESULT] %s %s B=%d OOM\n",PREC_NAME,FUSE_NAME,B); return 3; }
    real *Wf2=dalloc<real>(KN);

    auto gB=[&](long long n){ return (int)((n+255)/256); };
    fill_r<<<gB(MK),256>>>(A,MK,11,0.1);
    fill_r<<<gB(KN),256>>>(Wf,KN,33,0.02);
    fill_r<<<gB(MN),256>>>(dGrad,MN,44,0.05);
    ck(cudaDeviceSynchronize(),"init");

    int eGrid=(int)((KN+255)/256);

    // The per-step DAG. FUSED removes the separate transpose pass: the bwd GEMM
    // dW = A^T @ dGq is computed via cuBLAS OP_T on A directly (A is [M,K]; reading
    // it transposed gives [K,M]). UN-FUSED materializes A^T with k_transpose first
    // (BENCH-9 baseline) then a plain GEMM — the extra full-MN read+write pass.
    auto step=[&](int tstep){
        gemm(H, A, Wf, M, K, N);                     // PHASE 0 fwd  H = A @ W  (cuBLAS)
        k_valley<<<M,256>>>(H,G,dGrad,dGq,M,N);      // PHASE 1 valley (fused LN+gelu+copy)
#ifdef FUSED
        // PHASE 2 bwd  dW[K,N] = A^T @ dGq.  A is row-major [M,K]; to compute
        // dW = A^T(KxM) @ dGq(MxN) we need op on A = transpose. In the col-major
        // C^T = B^T @ opA(A)^T form, opA=OP_T reads A as [K,M] with lda=K -> A^T.
        gemm_op(dW, A, dGq, K, M, N, CUBLAS_OP_T, K);
#else
        k_transpose<<<256,256>>>(A,AT,M,K);          // materialize A^T (the extra pass)
        gemm(dW, AT, dGq, K, M, N);                  // PHASE 2 bwd dW = A^T @ dGq
#endif
        k_adamw<<<eGrid,256>>>(dW,Wf,Mm,Vv,KN,tstep);// FF-FUSED-OPTIM single-launch AdamW
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
    printf("[DETERMINISM] %s %s B=%d run-to-run max|delta(W')| = %.3e (gate ==0: %s)\n",
           PREC_NAME,FUSE_NAME,B,maxd,maxd==0.0?"PASS":"FAIL");

    // GATE: rel-RMS of W' vs the UN-FUSED NAIVE-GEMM reference (BENCH-9 ref math). The
    // fused path must be bit-faithful to the un-fused step within machine-eps.
    {
        real* Wref=dalloc<real>(KN); real* Mr=dalloc<real>(KN); real* Vr=dalloc<real>(KN);
        copy_r<<<gB(KN),256>>>(Wf2,Wref,KN); zero_r<<<gB(KN),256>>>(Mr,KN); zero_r<<<gB(KN),256>>>(Vr,KN);
        ck(cudaDeviceSynchronize(),"ref-snap");
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
        printf("[GATE] %s %s B=%d rel-RMS(W' vs UNFUSED-NAIVE-ref) = %.3e (gate <=1e-2: %s)\n",
               PREC_NAME,FUSE_NAME,B,relrms, relrms<=1e-2?"PASS":"FAIL");
        free(hr); cudaFree(Wref); cudaFree(Mr); cudaFree(Vr);
        copy_r<<<gB(KN),256>>>(Wf2,Wf,KN); zero_r<<<gB(KN),256>>>(Mm,KN); zero_r<<<gB(KN),256>>>(Vv,KN);
        ck(cudaDeviceSynchronize(),"restore");
    }

    // MEASURE full-step wall.
    cudaEvent_t e0,e1; cudaEventCreate(&e0); cudaEventCreate(&e1);
    step(2); ck(cudaDeviceSynchronize(),"warmup");
    cudaEventRecord(e0); for(int it=0;it<iters;it++) step(it+3); cudaEventRecord(e1);
    ck(cudaEventSynchronize(e1),"time"); float ms=0; cudaEventElapsedTime(&ms,e0,e1);
    double ms_step=ms/iters, step_s=1000.0/ms_step, samp_s=step_s*(double)B;
    printf("[RESULT] %s %s B=%d  ms/step=%.4f  step/s=%.4f  samples/s=%.4f\n",
           PREC_NAME,FUSE_NAME,B,ms_step,step_s,samp_s);
    free(h1); free(h2);
    return 0;
}
