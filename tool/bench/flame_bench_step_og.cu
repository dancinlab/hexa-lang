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
//   -DGEMM_BACKEND=5   CUBLAS-FP64  cublasGemmEx CUBLAS_COMPUTE_64F (BENCH-8).
//                              Pairs with -DBENCH_PREC=2; replaces the naive O(D^3)
//                              FP64 k_gemm with cuBLAS-FP64 to close BENCH-7's
//                              7 large-D FP64 losses (naive-GEMM confound, not a
//                              torch FP64-TC edge — both use FP64 CUDA cores).
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
#include <string.h>
#include <math.h>

#ifndef GEMM_BACKEND
#define GEMM_BACKEND 1          // default proxy = cuBLAS-TF32
#endif

#if GEMM_BACKEND == 1 || GEMM_BACKEND == 4 || GEMM_BACKEND == 5 || GEMM_BACKEND == 6
  #include <cublas_v2.h>
#endif
#if GEMM_BACKEND == 4 || GEMM_BACKEND == 6
  #include <cuda_bf16.h>
#endif
#if GEMM_BACKEND == 6
  #include <cublasLt.h>      // BENCH-9: cublasLt autotuned algo + epilogue fusion
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
#elif GEMM_BACKEND == 4
  static const char* GEMM_NAME = "cuBLAS-BF16";
#elif GEMM_BACKEND == 5
  static const char* GEMM_NAME = "cuBLAS-FP64";   // BENCH-8: cublasDgemm, CUBLAS_COMPUTE_64F
#elif GEMM_BACKEND == 6
  #ifdef LT_BF16
    static const char* GEMM_NAME = "cuBLASLt-BF16-autotune";   // BENCH-9
  #else
    static const char* GEMM_NAME = "cuBLASLt-TF32-autotune";   // BENCH-9
  #endif
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
#elif GEMM_BACKEND == 4
// BF16 lane (BENCH-7). float A/W storage + elementwise (deterministic, stable),
// but the load-bearing D->D GEMM runs in BF16 tensor cores (CUDA_R_16BF inputs,
// FP32 accum) — the matched-dtype peer of torch --dtype bf16's matmul. The cast
// to bf16 is RNE-deterministic so run-to-run max|delta|=0 holds, and the result is
// directly comparable to the naive FP32 ref within bf16's rel-RMS (~1e-2 gate).
static cublasHandle_t g_cublas = nullptr;
static __nv_bfloat16 *g_Ab=nullptr,*g_Bb=nullptr; static long long g_nA=0,g_nB=0;
__global__ void k_f2bf(const float* __restrict__ s, __nv_bfloat16* __restrict__ d, long long n){
    long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; if(i<n) d[i]=__float2bfloat16(s[i]); }
static void gemm_setup(){
    cublasCreate(&g_cublas);
    cublasSetMathMode(g_cublas, CUBLAS_DEFAULT_MATH);   // BF16 tensor-core via 16BF inputs
}
static void gemm(real* C, const real* A, const real* Bm, int M, int K, int N){
    long long nA=(long long)M*K, nB=(long long)K*N;
    if(nA>g_nA){ if(g_Ab)cudaFree(g_Ab); cudaMalloc(&g_Ab,nA*sizeof(__nv_bfloat16)); g_nA=nA; }
    if(nB>g_nB){ if(g_Bb)cudaFree(g_Bb); cudaMalloc(&g_Bb,nB*sizeof(__nv_bfloat16)); g_nB=nB; }
    k_f2bf<<<(nA+255)/256,256>>>(A, g_Ab, nA);
    k_f2bf<<<(nB+255)/256,256>>>(Bm, g_Bb, nB);
    const float alpha=1.f, beta=0.f;
    // row-major C=A@B  ==  col-major C^T = B^T @ A^T  ==  gemm(N,M,K, B,A)
    cublasGemmEx(g_cublas, CUBLAS_OP_N, CUBLAS_OP_N,
                 N, M, K, &alpha,
                 g_Bb, CUDA_R_16BF, N,
                 g_Ab, CUDA_R_16BF, K,
                 &beta,
                 C,    CUDA_R_32F,  N,
                 CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP);
}
#elif GEMM_BACKEND == 5
// BENCH-8 cuBLAS-FP64 lane. Pairs with -DBENCH_PREC=2 (real==double): the whole
// step runs in FP64 (matched to torch --dtype fp64), but the load-bearing D->D
// GEMM is cuBLAS FP64 (CUDA_R_64F in/out, CUBLAS_COMPUTE_64F) instead of the
// naive O(D^3) k_gemm. Both flame-cuBLAS-FP64 and torch-FP64 use the SAME FP64
// CUDA-core path (no FP64 tensor cores on Hopper for this size), so this isolates
// flame's no-Python-glue edge from the naive-GEMM confound that lost BENCH-7's
// 7 large-D FP64 cells. rel-RMS vs the naive-FP64 ref is ~1e-14 associativity
// (different accumulation order), NOT necessarily bit-0; run-to-run det == 0.
static cublasHandle_t g_cublas = nullptr;
static void gemm_setup(){
    cublasCreate(&g_cublas);
    cublasSetMathMode(g_cublas, CUBLAS_DEFAULT_MATH);   // FP64: no tensor-op downcast
}
static void gemm(real* C, const real* A, const real* Bm, int M, int K, int N){
    // cuBLAS is column-major: row-major C=A(MxK)@B(KxN) == col-major C^T=B^T@A^T
    // == cublas(op_n, op_n, N, M, K, B, A). FP64 alpha/beta are double.
    const double alpha=1.0, beta=0.0;
    cublasGemmEx(g_cublas, CUBLAS_OP_N, CUBLAS_OP_N,
                 N, M, K,
                 &alpha,
                 Bm, CUDA_R_64F, N,
                 A,  CUDA_R_64F, K,
                 &beta,
                 C,  CUDA_R_64F, N,
                 CUBLAS_COMPUTE_64F, CUBLAS_GEMM_DEFAULT);
}
#elif GEMM_BACKEND == 6
// ===================== BENCH-9: cuBLASLt autotune + epilogue fusion =====================
// Closes the last flame-cuBLAS losing cell D=4096/B=8 (TF32 1.27x, BF16 2.00x vs
// torch.compile). Two levers, matching what torch's inductor does:
//   (1) AUTOTUNE: cublasLtMatmulAlgoGetHeuristic picks the best algo for THIS shape
//       instead of cublasGemmEx's CUBLAS_GEMM_DEFAULT_TENSOR_OP. The chosen algo is
//       cached per (M,K,N) so the per-step cost is one heuristic lookup, amortized.
//   (2) EPILOGUE: when HEXA_LT_EPILOGUE=gelu is set, the fwd GEMM fuses its activation
//       into the matmul epilogue (CUBLASLT_EPILOGUE_GELU) so the elementwise pass folds
//       into the GEMM — what inductor does. (Default = no epilogue, math == plain ref.)
//
// LT_BF16 compile flag -> cast inputs to bf16 (CUDA_R_16BF, COMPUTE_32F); else TF32
// (CUDA_R_32F, COMPUTE_32F_FAST_TF32). The cast is RNE-deterministic so max|delta|=0.
//
// cuBLASLt is COLUMN-MAJOR; row-major C[M,N]=A[M,K]@B[K,N] == col-major C^T = B^T @ A^T
// == matmul(opN,opN, N,M,K, B,A) — identical trick to the cublasGemmEx wrappers above.
static cublasLtHandle_t g_lt = nullptr;
static void* g_ws = nullptr;            // autotune workspace
static size_t g_ws_sz = 32u*1024u*1024u; // 32 MiB
static int g_epilogue_gelu = 0;         // HEXA_LT_EPILOGUE=gelu
#ifdef LT_BF16
static __nv_bfloat16 *g_Ab=nullptr,*g_Bb=nullptr; static long long g_nA=0,g_nB=0;
__global__ void k_f2bf(const float* __restrict__ s, __nv_bfloat16* __restrict__ d, long long n){
    long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x; if(i<n) d[i]=__float2bfloat16(s[i]); }
#endif
struct LtCache { int M,K,N,fwd; cublasLtMatmulAlgo_t algo; int valid; };
static LtCache g_cache[8]; static int g_ncache=0;
static void gemm_setup(){
    cublasLtCreate(&g_lt);
    cudaMalloc(&g_ws, g_ws_sz);
    const char* ep = getenv("HEXA_LT_EPILOGUE");
    if(ep && (!strcmp(ep,"gelu")||!strcmp(ep,"GELU"))) g_epilogue_gelu = 1;
    for(int i=0;i<8;i++) g_cache[i].valid=0;
}
static void gemm_impl(real* C, const real* A, const real* Bm, int M, int K, int N, int is_fwd){
#ifdef LT_BF16
    cudaDataType_t IN_T = CUDA_R_16BF;
    long long nA=(long long)M*K, nB=(long long)K*N;
    if(nA>g_nA){ if(g_Ab)cudaFree(g_Ab); cudaMalloc(&g_Ab,nA*sizeof(__nv_bfloat16)); g_nA=nA; }
    if(nB>g_nB){ if(g_Bb)cudaFree(g_Bb); cudaMalloc(&g_Bb,nB*sizeof(__nv_bfloat16)); g_nB=nB; }
    k_f2bf<<<(nA+255)/256,256>>>(A, g_Ab, nA);
    k_f2bf<<<(nB+255)/256,256>>>(Bm, g_Bb, nB);
    const void *pA=g_Ab, *pB=g_Bb;
    cublasComputeType_t COMP = CUBLAS_COMPUTE_32F;
#else
    cudaDataType_t IN_T = CUDA_R_32F;
    const void *pA=A, *pB=Bm;
    cublasComputeType_t COMP = CUBLAS_COMPUTE_32F_FAST_TF32;
#endif
    cublasLtMatmulDesc_t op;
    cublasLtMatmulDescCreate(&op, COMP, CUDA_R_32F);
    cublasOperation_t opn = CUBLAS_OP_N;
    cublasLtMatmulDescSetAttribute(op, CUBLASLT_MATMUL_DESC_TRANSA, &opn, sizeof(opn));
    cublasLtMatmulDescSetAttribute(op, CUBLASLT_MATMUL_DESC_TRANSB, &opn, sizeof(opn));
    int use_gelu = (is_fwd && g_epilogue_gelu);
    if(use_gelu){
        cublasLtEpilogue_t epi = CUBLASLT_EPILOGUE_GELU;
        cublasLtMatmulDescSetAttribute(op, CUBLASLT_MATMUL_DESC_EPILOGUE, &epi, sizeof(epi));
    }
    cublasLtMatrixLayout_t lB, lA, lC;
    cublasLtMatrixLayoutCreate(&lB, IN_T,        N, K, N);
    cublasLtMatrixLayoutCreate(&lA, IN_T,        K, M, K);
    cublasLtMatrixLayoutCreate(&lC, CUDA_R_32F,  N, M, N);
    const float alpha=1.f, beta=0.f;
    int ci=-1;
    for(int i=0;i<g_ncache;i++) if(g_cache[i].M==M&&g_cache[i].K==K&&g_cache[i].N==N&&g_cache[i].fwd==use_gelu){ ci=i; break; }
    if(ci<0 && g_ncache<8){
        cublasLtMatmulPreference_t pref; cublasLtMatmulPreferenceCreate(&pref);
        cublasLtMatmulPreferenceSetAttribute(pref, CUBLASLT_MATMUL_PREF_MAX_WORKSPACE_BYTES,
                                             &g_ws_sz, sizeof(g_ws_sz));
        cublasLtMatmulHeuristicResult_t heur[1]; int nres=0;
        cublasStatus_t hs = cublasLtMatmulAlgoGetHeuristic(g_lt, op, lB, lA, lC, lC,
                                                           pref, 1, heur, &nres);
        if(hs==CUBLAS_STATUS_SUCCESS && nres>0){
            ci=g_ncache++;
            g_cache[ci].M=M; g_cache[ci].K=K; g_cache[ci].N=N; g_cache[ci].fwd=use_gelu;
            g_cache[ci].algo=heur[0].algo; g_cache[ci].valid=1;
        }
        cublasLtMatmulPreferenceDestroy(pref);
    }
    const cublasLtMatmulAlgo_t* algo = (ci>=0 && g_cache[ci].valid)? &g_cache[ci].algo : nullptr;
    cublasLtMatmul(g_lt, op, &alpha, pB, lB, pA, lA, &beta, C, lC, C, lC,
                   algo, g_ws, g_ws_sz, 0);
    cublasLtMatrixLayoutDestroy(lB); cublasLtMatrixLayoutDestroy(lA); cublasLtMatrixLayoutDestroy(lC);
    cublasLtMatmulDescDestroy(op);
}
static void gemm(real* C, const real* A, const real* Bm, int M, int K, int N){
    gemm_impl(C, A, Bm, M, K, N, 0);   // generic (bwd) entry — no epilogue
}
static void gemm_fwd(real* C, const real* A, const real* Bm, int M, int K, int N){
    gemm_impl(C, A, Bm, M, K, N, 1);   // fwd entry — epilogue may apply
}
#else
static void gemm_setup(){}
static void gemm(real* C, const real* A, const real* Bm, int M, int K, int N){
    dim3 blk(TILE,TILE);
    dim3 g((N+TILE-1)/TILE,(M+TILE-1)/TILE);
    k_gemm<<<g,blk>>>(A, Bm, C, M, K, N);
}
#endif

// For backends without a dedicated fwd-epilogue entry, fwd == generic gemm.
#if GEMM_BACKEND != 6
#define gemm_fwd gemm
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
        gemm_fwd(H, A, Wf, M, K, N);                // PHASE 0 fwd  H = A @ W   (tuned GEMM; bk6 epilogue-able)
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
