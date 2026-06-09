/* OP-6b — fuse the AdamW update INTO the bwd-GEMM epilogue (boundary-removal).
 *
 * CONTEXT (HEXA-0POD OP-6 #2983): OP-6 proved that memory-INSTRUCTION
 * vectorization (.v4/.v2) does NOT help the standalone memory-bound fp64 AdamW
 * elementwise kernel on the 5070 (already bandwidth-coalesced, ~1.005x). OP-6's
 * verdict identified the ONLY remaining elementwise headroom: BOUNDARY-REMOVAL —
 * fuse the AdamW update so dW is NOT written to DRAM and re-read as a separate
 * kernel launch. This is the lever that consistently WORKS in this codebase
 * (OG-FUSE-FOLD #2909 fused MoE-conv, OP-2 transpose-elim).
 *
 * ── WHICH BWD-dW PATH (determined, clm_prod.hexa) ─────────────────────────────
 * conv1d_bwd_via_forge (stdlib/flame/clm_prod.hexa:229-251) computes dW via
 *   dW_flat = forge_dispatch_matmul(xcolT, Kdim, T, dy, Cout)
 * which routes (CUDA host) to farr_matmul_gpu → cuBLAS Dgemm
 * (self/cuda/runtime_cuda_emit.hexa, "real cuBLAS Dgemm body"). The PRODUCTION
 * bwd-dW GEMM is cuBLAS-bound → SCOPE B: you CANNOT fuse an epilogue into a
 * closed cuBLAS call. The HONEST finding (g5) is therefore: epilogue-fusion
 * boundary-removal REQUIRES routing the bwd dW through an OWN-GEMM (sm_120
 * owngemm_sm120.cu family). This harness MEASURES what that own-GEMM-bwd +
 * fused-AdamW would buy vs the current separate-kernel structure, and whether it
 * stays bit-exact under --fmad=true/false.
 *
 * ── THE TWO PATHS COMPARED ────────────────────────────────────────────────────
 * SEPARATE (current structure): own-GEMM computes dW=A·B and STORES dW to DRAM;
 *   then a SEPARATE _hx_k_adamw_step kernel re-reads dW (+W,M,V) from DRAM and
 *   writes W,M,V. = dW write + dW re-read + AdamW (W,M,V read + W,M,V write) + a
 *   2nd kernel launch.
 * FUSED (boundary-removal): the own-GEMM consumes each dW cell IN-REGISTER as
 *   soon as the K-loop accumulation finishes, applies the AdamW update inline
 *   (reading W,M,V for that cell), and writes W,M,V DIRECTLY. dW NEVER hits DRAM,
 *   the dW re-read is gone, and the 2nd launch is gone.
 *
 * The AdamW per-element arithmetic is the VERBATIM body of
 * _hx_k_adamw_step_inplace (self/cuda/runtime_cuda.c), expanded from ONE shared
 * MACRO (ADAMW_BODY) in both the separate AdamW kernel and the fused epilogue, so
 * the expression text — hence ptxas fp-contraction — is identical. The ONLY
 * difference is WHERE the dW value comes from (DRAM re-read vs register).
 *
 * fp64 throughout: AdamW is fp64 in production; we use an fp64 own-GEMM so the
 * AdamW byte-eq comparison is apples-to-apples (the production own-GEMM is TF32,
 * but the boundary-removal saving is dtype-independent — it is a DRAM round-trip
 * + launch elimination, identical structure for a TF32 dW GEMM).
 *
 * GATE (g5): fused (W,M,V) must be BYTE-IDENTICAL to separate (W,M,V)
 *   max|Δ|=0, bitdiff=0. Reported under --fmad=false AND --fmad=true.
 *
 * Build (aiden RTX 5070, sm_120, nvcc 13.0):
 *   nvcc -O3 -arch=sm_120 --fmad=false op6b_adamw_fuse_bench.cu -o op6b_ff
 *   nvcc -O3 -arch=sm_120 --fmad=true  op6b_adamw_fuse_bench.cu -o op6b_ft
 */
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <cmath>
#include <cstdlib>
#include <cuda_runtime.h>

#define CK(x) do{ cudaError_t e=(x); if(e!=cudaSuccess){ \
  fprintf(stderr,"CUDA err %s:%d: %s\n",__FILE__,__LINE__,cudaGetErrorString(e)); exit(1);} }while(0)

/* per-element AdamW body — VERBATIM _hx_k_adamw_step_inplace arithmetic, as a
 * MACRO so the expression text is inlined IDENTICALLY in both the separate
 * AdamW kernel and the fused GEMM epilogue. Same fma fusion in both paths → the
 * only structural difference is the SOURCE of the gradient (DRAM vs register). */
#define ADAMW_BODY(w_in, m_in, v_in, g_in, w_out, m_out, v_out)               \
    do {                                                                      \
        double _g    = (g_in);                                                \
        double _mi   = b1 * (m_in) + (1.0 - b1) * _g;                         \
        double _vi   = b2 * (v_in) + (1.0 - b2) * _g * _g;                    \
        double _mhat = _mi / c1;                                              \
        double _vhat = _vi / c2;                                              \
        double _denom = sqrt(_vhat) + eps;                                    \
        double _wi   = (w_in) - lr * wd * (w_in) - lr * _mhat / _denom;       \
        (m_out) = _mi; (v_out) = _vi; (w_out) = _wi;                          \
    } while (0)

/* ── tiled fp64 own-GEMM: C[M,N] = A[M,K] · B[K,N], row-major ──
 * This mirrors the dW GEMM (dW = xcolT[Kdim,T] · dy[T,Cout]) STRUCTURE: one
 * thread per output cell, K-loop accumulate, smem-staged A/B tiles. It is the
 * own-GEMM stand-in for the closed cuBLAS path (see scope-B note in header).
 * TILE = 16 (256 thr/block). */
#define TILE 16

/* SEPARATE path, stage 1: own-GEMM → write dW to DRAM (no epilogue). */
__global__ void gemm_dW_store(const double* __restrict__ A,
                              const double* __restrict__ B,
                              double* __restrict__ dW,
                              int Mr, int Nc, int Kk) {
    __shared__ double As[TILE][TILE];
    __shared__ double Bs[TILE][TILE];
    int row = blockIdx.y * TILE + threadIdx.y;
    int col = blockIdx.x * TILE + threadIdx.x;
    double acc = 0.0;
    for (int t = 0; t < (Kk + TILE - 1) / TILE; ++t) {
        int aCol = t * TILE + threadIdx.x;
        int bRow = t * TILE + threadIdx.y;
        As[threadIdx.y][threadIdx.x] = (row < Mr && aCol < Kk) ? A[row * Kk + aCol] : 0.0;
        Bs[threadIdx.y][threadIdx.x] = (bRow < Kk && col < Nc) ? B[bRow * Nc + col] : 0.0;
        __syncthreads();
        #pragma unroll
        for (int k = 0; k < TILE; ++k) acc += As[threadIdx.y][k] * Bs[k][threadIdx.x];
        __syncthreads();
    }
    if (row < Mr && col < Nc) dW[row * Nc + col] = acc;
}

/* SEPARATE path, stage 2: standalone AdamW kernel re-reads dW from DRAM.
 * (verbatim grid-stride over the flattened dW, = production _hx_k_adamw_step). */
__global__ void adamw_separate(double* __restrict__ W,
                               double* __restrict__ Mm,
                               double* __restrict__ Vv,
                               const double* __restrict__ dW,
                               int64_t n,
                               double lr, double b1, double b2,
                               double eps, double wd, double c1, double c2) {
    int64_t stride = (int64_t)blockDim.x * (int64_t)gridDim.x;
    for (int64_t i = (int64_t)blockIdx.x * blockDim.x + threadIdx.x; i < n; i += stride) {
        ADAMW_BODY(W[i], Mm[i], Vv[i], dW[i], W[i], Mm[i], Vv[i]);
    }
}

/* FUSED path: own-GEMM with AdamW epilogue. The dW cell `acc` is consumed
 * IN-REGISTER the instant the K-loop finishes — it NEVER touches DRAM. The
 * thread reads W,M,V for that (row,col) cell, applies the SAME ADAMW_BODY, and
 * writes W,M,V directly. dW write + dW re-read + 2nd launch all ELIMINATED. */
__global__ void gemm_dW_adamw_fused(const double* __restrict__ A,
                                    const double* __restrict__ B,
                                    double* __restrict__ W,
                                    double* __restrict__ Mm,
                                    double* __restrict__ Vv,
                                    int Mr, int Nc, int Kk,
                                    double lr, double b1, double b2,
                                    double eps, double wd, double c1, double c2) {
    __shared__ double As[TILE][TILE];
    __shared__ double Bs[TILE][TILE];
    int row = blockIdx.y * TILE + threadIdx.y;
    int col = blockIdx.x * TILE + threadIdx.x;
    double acc = 0.0;
    for (int t = 0; t < (Kk + TILE - 1) / TILE; ++t) {
        int aCol = t * TILE + threadIdx.x;
        int bRow = t * TILE + threadIdx.y;
        As[threadIdx.y][threadIdx.x] = (row < Mr && aCol < Kk) ? A[row * Kk + aCol] : 0.0;
        Bs[threadIdx.y][threadIdx.x] = (bRow < Kk && col < Nc) ? B[bRow * Nc + col] : 0.0;
        __syncthreads();
        #pragma unroll
        for (int k = 0; k < TILE; ++k) acc += As[threadIdx.y][k] * Bs[k][threadIdx.x];
        __syncthreads();
    }
    if (row < Mr && col < Nc) {
        int64_t i = (int64_t)row * Nc + col;
        /* acc IS the dW cell — consumed from register, never stored to DRAM */
        ADAMW_BODY(W[i], Mm[i], Vv[i], acc, W[i], Mm[i], Vv[i]);
    }
}

static double now_ms(cudaEvent_t a, cudaEvent_t b){ float ms=0; cudaEventElapsedTime(&ms,a,b); return ms; }

int main(int argc, char** argv){
    /* dW GEMM shape: dW[Kdim, Cout] = xcolT[Kdim, T] · dy[T, Cout].
     * Default mirrors a flame conv1d_bwd dW: Kdim = Cin*K, Cout, contracted over T. */
    int Mr = (argc>1)? atoi(argv[1]) : 1536;   /* Kdim (e.g. Cin=512,K=3) */
    int Nc = (argc>2)? atoi(argv[2]) : 512;    /* Cout */
    int Kk = (argc>3)? atoi(argv[3]) : 2048;   /* T (sequence length) */
    int iters = (argc>4)? atoi(argv[4]) : 50;

    int64_t n = (int64_t)Mr * Nc;              /* dW element count */
    double lr=1e-3, b1=0.9, b2=0.999, eps=1e-8, wd=0.01;
    int64_t step_t = 10; double b1t=1.0,b2t=1.0;
    for(int64_t e=0;e<step_t;e++){b1t*=b1;b2t*=b2;}
    double c1=1.0-b1t, c2=1.0-b2t;

    size_t aBytes=(size_t)Mr*Kk*sizeof(double);
    size_t bBytes=(size_t)Kk*Nc*sizeof(double);
    size_t nBytes=(size_t)n*sizeof(double);

    double *hA=(double*)malloc(aBytes),*hB=(double*)malloc(bBytes);
    double *hW=(double*)malloc(nBytes),*hM=(double*)malloc(nBytes),*hV=(double*)malloc(nBytes);
    uint64_t s=88172645463325252ULL;
    #define RND ({ s^=s<<13; s^=s>>7; s^=s<<17; ((double)(s>>11))/9007199254740992.0; })
    for(int64_t i=0;i<(int64_t)Mr*Kk;i++) hA[i]=(RND-0.5)*0.1;
    for(int64_t i=0;i<(int64_t)Kk*Nc;i++) hB[i]=(RND-0.5)*0.1;
    for(int64_t i=0;i<n;i++){ double r=RND; hW[i]=(r-0.5)*0.2; hM[i]=r*0.001; hV[i]=r*1e-6; }

    double *A,*B,*dW;
    double *Ws,*Ms,*Vs;   /* separate-path W,M,V */
    double *Wf,*Mf,*Vf;   /* fused-path W,M,V */
    CK(cudaMalloc(&A,aBytes)); CK(cudaMalloc(&B,bBytes)); CK(cudaMalloc(&dW,nBytes));
    CK(cudaMalloc(&Ws,nBytes)); CK(cudaMalloc(&Ms,nBytes)); CK(cudaMalloc(&Vs,nBytes));
    CK(cudaMalloc(&Wf,nBytes)); CK(cudaMalloc(&Mf,nBytes)); CK(cudaMalloc(&Vf,nBytes));
    CK(cudaMemcpy(A,hA,aBytes,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(B,hB,bBytes,cudaMemcpyHostToDevice));

    dim3 blk(TILE,TILE);
    dim3 grd((Nc+TILE-1)/TILE, (Mr+TILE-1)/TILE);
    int ablk=256; int64_t want=(n+ablk-1)/ablk; int agrid=(want>1024)?1024:(int)want; if(agrid<1)agrid=1;

    auto reinit=[&](double*W,double*M,double*V){
        CK(cudaMemcpy(W,hW,nBytes,cudaMemcpyHostToDevice));
        CK(cudaMemcpy(M,hM,nBytes,cudaMemcpyHostToDevice));
        CK(cudaMemcpy(V,hV,nBytes,cudaMemcpyHostToDevice));
    };

    cudaEvent_t e0,e1; CK(cudaEventCreate(&e0)); CK(cudaEventCreate(&e1));

    /* warm up + functional run: SEPARATE */
    reinit(Ws,Ms,Vs);
    gemm_dW_store<<<grd,blk>>>(A,B,dW,Mr,Nc,Kk);
    adamw_separate<<<agrid,ablk>>>(Ws,Ms,Vs,dW,n,lr,b1,b2,eps,wd,c1,c2);
    CK(cudaDeviceSynchronize());
    /* functional run: FUSED */
    reinit(Wf,Mf,Vf);
    gemm_dW_adamw_fused<<<grd,blk>>>(A,B,Wf,Mf,Vf,Mr,Nc,Kk,lr,b1,b2,eps,wd,c1,c2);
    CK(cudaDeviceSynchronize());

    /* ── BIT-EXACT GATE: fused (W,M,V) vs separate (W,M,V) ── */
    double *cWs=(double*)malloc(nBytes),*cMs=(double*)malloc(nBytes),*cVs=(double*)malloc(nBytes);
    double *cWf=(double*)malloc(nBytes),*cMf=(double*)malloc(nBytes),*cVf=(double*)malloc(nBytes);
    CK(cudaMemcpy(cWs,Ws,nBytes,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(cMs,Ms,nBytes,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(cVs,Vs,nBytes,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(cWf,Wf,nBytes,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(cMf,Mf,nBytes,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(cVf,Vf,nBytes,cudaMemcpyDeviceToHost));
    int64_t bitdiff=0; double maxd=0.0;
    for(int64_t i=0;i<n;i++){
        if(memcmp(&cWs[i],&cWf[i],8)) bitdiff++;
        if(memcmp(&cMs[i],&cMf[i],8)) bitdiff++;
        if(memcmp(&cVs[i],&cVf[i],8)) bitdiff++;
        double d;
        d=fabs(cWs[i]-cWf[i]); if(d>maxd)maxd=d;
        d=fabs(cMs[i]-cMf[i]); if(d>maxd)maxd=d;
        d=fabs(cVs[i]-cVf[i]); if(d>maxd)maxd=d;
    }

    /* ── TIMED: SEPARATE (GEMM-store + AdamW re-read) ── */
    reinit(Ws,Ms,Vs);
    CK(cudaDeviceSynchronize()); CK(cudaEventRecord(e0));
    for(int it=0;it<iters;it++){
        gemm_dW_store<<<grd,blk>>>(A,B,dW,Mr,Nc,Kk);
        adamw_separate<<<agrid,ablk>>>(Ws,Ms,Vs,dW,n,lr,b1,b2,eps,wd,c1,c2);
    }
    CK(cudaEventRecord(e1)); CK(cudaEventSynchronize(e1));
    double ms_sep = now_ms(e0,e1)/iters;

    /* ── TIMED: FUSED (GEMM + AdamW epilogue, no dW DRAM round-trip) ── */
    reinit(Wf,Mf,Vf);
    CK(cudaDeviceSynchronize()); CK(cudaEventRecord(e0));
    for(int it=0;it<iters;it++){
        gemm_dW_adamw_fused<<<grd,blk>>>(A,B,Wf,Mf,Vf,Mr,Nc,Kk,lr,b1,b2,eps,wd,c1,c2);
    }
    CK(cudaEventRecord(e1)); CK(cudaEventSynchronize(e1));
    double ms_fused = now_ms(e0,e1)/iters;

    /* dW DRAM traffic eliminated by fusion: 1 dW write (GEMM) + 1 dW read (AdamW). */
    double dW_roundtrip_GB = 2.0 * (double)nBytes / 1e9;
    double sep_extra_GBps  = dW_roundtrip_GB / (ms_sep/1e3);

    printf("OP-6b — AdamW-into-bwd-GEMM-epilogue fusion (boundary-removal)\n");
    printf("shape: dW[%d,%d] = A[%d,%d] . B[%d,%d]  (n=%lld dW elems)\n",
           Mr,Nc,Mr,Kk,Kk,Nc,(long long)n);
    printf("BIT-EXACT GATE (fused W,M,V vs separate W,M,V): bitdiff=%lld/%lld  max|delta|=%.3e  -> %s\n",
           (long long)bitdiff,(long long)(3*n),maxd, (bitdiff==0)?"BYTE-IDENTICAL (PASS)":"DIFFERS (FAIL)");
    printf("PERF: SEPARATE %.4f ms/step | FUSED %.4f ms/step | speedup %.3fx\n",
           ms_sep, ms_fused, ms_sep/ms_fused);
    printf("      dW DRAM round-trip ELIMINATED by fusion: %.4f GB (write+reread) = %.1f GB/s @ separate ms\n",
           dW_roundtrip_GB, sep_extra_GBps);
    printf("      separate = 2 launches (GEMM + AdamW); fused = 1 launch (GEMM+epilogue)\n");
    return 0;
}
