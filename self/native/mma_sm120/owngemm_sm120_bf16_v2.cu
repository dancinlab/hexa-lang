// owngemm_sm120_bf16_v2.cu — r3-cublas-independence BF16 r4: close the standalone
// kernel-quality gap vs cuBLAS-BF16 on sm_120 (RTX 5070, cc12.0).
//
// CONTEXT (captured aiden, this lane):
//   The OP-3 production own-BF16 kernel (owngemm_sm120_bf16.cu) is ALREADY at a
//   FLAT ~2x off cuBLAS-BF16 (512:1.91x 1024:2.05x 2048:1.99x) — NOT the 7.1/5.1/
//   3.1x the dispatch-path baseline showed. The 7.1x small-N blowup was the
//   runtime DISPATCH wrapper (3x cudaMalloc + 3x cudaFree + 3 cast kernels per
//   call), which the standalone kernel does NOT have (it stages fp32 in smem and
//   converts at fragment-load — L1/L2/L3 overhead-kill already realized). So the
//   residual ~2x is the STANDALONE KERNEL-QUALITY gap, the r4 target here.
//
// r4 LEVERS (BF16-specific — the prior TF32 sweep in owngemm_sm120_opt.cu could
// NOT pull these because TF32 needs 19-bit storage = fp32 smem; BF16 is 16-bit):
//
//   L4-a  BF16 SMEM STAGING. The OP-3 kernel stages As/Bs as fp32 (4 B/elem),
//         then re-converts fp32->bf16 at EVERY fragment load (each smem element
//         is re-converted up to WN_FRAG times per BK step via packbf16 = 2x
//         __float2bfloat16_rn + shifts). v2 converts fp32->bf16 ONCE during the
//         smem write and stores PACKED bf16 (2 B/elem). This (i) HALVES smem
//         footprint+bandwidth, and (ii) removes ALL per-fragment packbf16 ALU —
//         the fragment load becomes a single 32-bit smem read = 2 packed bf16 =
//         exactly one mma A/B register. Reference: CUTLASS stages the narrow
//         dtype in smem (cutlass/gemm/threadblock/default_mma.h), never the wide
//         one — narrow-smem is the canonical mixed-precision GEMM layout.
//
//   L4-b  BK=32 (TWO k16 mma steps per smem stage). Halving smem (L4-a) frees the
//         48KB sm_120 budget that BLOCKED BK=32 for the fp32-staged TF32 kernel
//         (owngemm_sm120_pipe.cu LBK=32 was closed-neg on smem pressure). At
//         BK=32 bf16: As[2][64][16+pad]+Bs[2][64][16+pad] words *4B = ~36KB <
//         48KB. Fewer __syncthreads + deeper per-stage K reuse raises the
//         compute:sync ratio. Accumulation stays K-MAJOR SINGLE-PASS (k=0..31
//         within a stage, stages serial) — NO Split-K, so determinism max|d|=0
//         holds (ggml gates Split-K off for exactly this reason).
//
// All on top of OP-3's proven layout: padded bank-conflict-free smem, double-
// buffered stage, and the .v2 (float2) vectorized C-store epilogue.
//
// ── VERDICT (MEASURED aiden RTX 5070 sm_120, this lane — CLOSED-NEGATIVE) ──────
//   off-cuBLAS-BF16 (lower=better):     512     1024    2048
//     OP-3 (owngemm_sm120_bf16.cu):     1.91x   2.05x   1.99x   <- BEST (production)
//     v2  BK=32 (this file, default):   5.39x   4.67x   3.78x
//     v2  BK=16 (-DLBK=16):              —      3.71x   3.43x
//   Gate PASS + determinism max|d|=0 HELD for ALL configs (correctness intact).
//   ISOLATION: BK=32->16 helps (overlap-less big K-tile hurts, matches the prior
//   TF32 pipe closed-neg); but even v2-BK=16 is ~1.7x WORSE than OP-3. The
//   residual regressor is the LOAD PATH: bf16-smem-staging FORCES scalar
//   synchronous fp32 global loads (cp.async cannot convert fp32->bf16 in-flight,
//   and .v4 float4 vectorization is lost), whereas OP-3 keeps cp.async double-
//   buffered + .v4 vectorized global loads. On this MEMORY-BOUND consumer card,
//   that global-bandwidth/overlap loss dominates and SWAMPS the smem-capacity +
//   per-fragment-ALU savings bf16 staging buys. ROOT CAUSE (c1, captured): the
//   5070 lever is global-load coalescing/vectorization + cp.async overlap, NOT
//   smem footprint or fragment-conversion ALU. The c23 lesson: I guessed the
//   bottleneck (ALU re-conversion) instead of measuring it first.
//   => bf16-smem-staging is closed-negative on sm_120; OP-3 stays production.
//   This file is retained as the determinism-preserving negative-result artifact.
//
// GATE (unchanged from OP-3): bit-FAITHFUL rel-RMS vs FP64 ref <= 1e-2 (BF16 8
// mantissa bits), AND run-to-run determinism max|delta| = 0 (identical K-major
// mma.sync order => self bit-reproducer). The v2 bf16 RNE conversion is the SAME
// __float2bfloat16_rn as OP-3, applied at the same math points, so v2's rel-RMS
// vs FP64 is the SAME as OP-3 (a staging/scheduling change, not a math change).
//
// GEMM: C[M,N] = A[M,K] @ B[K,N], all row-major, BF16 matmul / FP32 accum.
//
// Modes (argv[2]): 0 GATE / 1 PERF (vs cuBLAS-BF16) / 2 DETERMINISM.
// Build: build_owngemm_bf16_v2.sh (run on aiden).

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cuda_runtime.h>
#include <cuda_bf16.h>
#include <cublas_v2.h>

#define CK(x) do{cudaError_t e=(x); if(e!=cudaSuccess){printf("CUDA-ERR %s @%d: %s\n",#x,__LINE__,cudaGetErrorString(e));exit(3);}}while(0)
#define CB(x) do{cublasStatus_t s=(x); if(s!=CUBLAS_STATUS_SUCCESS){printf("CUBLAS-ERR %d @%d\n",(int)s,__LINE__);exit(3);}}while(0)

#define BM 64
#define BN 64
#ifndef LBK
#define LBK 32           // K-tile per smem stage; 2 m16n8k16 mma steps when 32
#endif
#define BK LBK
#define WARPS_M 2
#define WARPS_N 2
#define NWARP (WARPS_M*WARPS_N)   // 4
#define NTHREAD (NWARP*32)        // 128
#define WM_FRAG 2
#define WN_FRAG 4

// round-to-nearest-even fp32 -> bf16 raw 16-bit (hardware RNE).
__device__ __forceinline__ unsigned short f2bf16(float x){
    __nv_bfloat16 b = __float2bfloat16_rn(x);
    unsigned short u; memcpy(&u,&b,2); return u;
}

// One mma.sync m16n8k16 BF16 step. A frag = 4 regs (8 bf16), B frag = 2 regs
// (4 bf16), C/D = 4 f32 acc regs (in/out). Identical to OP-3.
__device__ __forceinline__ void mma_m16n8k16(float* d, const unsigned* a, const unsigned* b){
    asm volatile(
      "mma.sync.aligned.m16n8k16.row.col.f32.bf16.bf16.f32 "
      "{%0,%1,%2,%3}, {%4,%5,%6,%7}, {%8,%9}, {%0,%1,%2,%3};\n"
      : "+f"(d[0]),"+f"(d[1]),"+f"(d[2]),"+f"(d[3])
      : "r"(a[0]),"r"(a[1]),"r"(a[2]),"r"(a[3]),"r"(b[0]),"r"(b[1]));
}

// Pad the PACKED-bf16 smem in units of 32-bit words (2 bf16 each) to break the
// 32-bank stride on the fragment loads. A is laid out as 32-bit words: each word
// holds 2 bf16 along K (the unit an A fragment register consumes). BKW = BK/2
// words along K. Pad 2 words. B is stored UNPACKED bf16, k-major (Bsh[k][n]) to
// keep its global load COALESCED (B's contiguous global dim is n); B fragment
// packing happens at the smem read (2 cheap bf16 smem reads per B register).
//
// r4-FIX (captured aiden): v2's first cut stored B n-major K-packed, which forced
// COLUMN-STRIDED (uncoalesced, stride-N) global B loads — measured 4.2-5.9x off
// cuBLAS (WORSE than OP-3's 2.0x). Root cause = global-load coalescing, NOT the
// per-fragment packbf16 ALU. Fix: A stays K-packed (A's K is its contiguous dim,
// so A pack IS coalesced); B reverts to coalesced k-major bf16 smem, packed at
// the fragment read. This keeps L4-a's HALF-smem + ALU win for A and the cheap
// smem-side pack for B, WITHOUT sacrificing global coalescing.
#define WPAD 2
#define BKW (BK/2)
#define BSPAD 8   // pad B's n-dim (bf16 unit) to break bank conflicts

// Tiled BF16 GEMM, v2: A K-packed bf16 smem (1 word = 1 A reg, no per-frag conv);
// B unpacked-bf16 k-major smem (coalesced global load, packed at fragment read).
// A,B,C row-major. fp32 -> bf16 RNE conversion ONCE at smem write. 64x64 tile,
// BK=LBK, double-buffered. IDENTICAL per-output K-major mma.sync accumulation
// order => run-to-run bit-for-bit reproducible.
extern "C" __global__ void gemm_sm120_bf16_v2(const float* __restrict__ A,
                                              const float* __restrict__ B,
                                              float* __restrict__ C,
                                              int M, int N, int K){
    __shared__ unsigned       Asw[2][BM][BKW+WPAD];     // A: 2 bf16/word along K
    __shared__ unsigned short Bsh[2][BK][BN+BSPAD];     // B: unpacked bf16, k-major
    int bm = blockIdx.y*BM, bn = blockIdx.x*BN;
    int tid = threadIdx.x;
    int warp = tid>>5, lane = tid&31;
    int wm = (warp/WARPS_N)*32;
    int wn = (warp%WARPS_N)*32;
    int gid = lane>>2, tig = lane&3;

    float acc[WM_FRAG][WN_FRAG][4];
    #pragma unroll
    for(int i=0;i<WM_FRAG;i++)for(int j=0;j<WN_FRAG;j++)for(int e=0;e<4;e++) acc[i][j][e]=0.f;

    int nk = (K+BK-1)/BK;

    // Stage one BK tile into smem buffer `buf`, packing fp32->bf16 in-register.
    // A row-major[m][k]: K is A's contiguous dim -> consecutive-K reads coalesce.
    //   pack 2 consecutive K into one word. BM*BKW words total.
    // B row-major[k][n]: n is B's contiguous dim -> store k-major bf16 (coalesced
    //   global read along n). BK*BN bf16 total.
    auto load_stage = [&](int buf,int k0){
        #pragma unroll
        for(int i=tid; i<BM*BKW; i+=NTHREAD){
            int m = i/BKW, kw = i%BKW; int k = kw*2;
            int gr = bm+m, gc = k0+k;
            float a0 = (gr<M && gc  <K) ? A[(long long)gr*K+gc  ] : 0.f;
            float a1 = (gr<M && gc+1<K) ? A[(long long)gr*K+gc+1] : 0.f;
            Asw[buf][m][kw] = (unsigned)f2bf16(a0) | ((unsigned)f2bf16(a1) << 16);
        }
        #pragma unroll
        for(int i=tid; i<BK*BN; i+=NTHREAD){
            int k = i/BN, n = i%BN;
            int gr = k0+k, gc = bn+n;
            float b0 = (gr<K && gc<N) ? B[(long long)gr*N+gc] : 0.f;
            Bsh[buf][k][n] = f2bf16(b0);
        }
    };

    load_stage(0,0); __syncthreads();
    for(int k=0; k<nk; k++){
        int buf=k&1, nbuf=(k+1)&1;
        if(k+1<nk) load_stage(nbuf,(k+1)*BK);
        // consume current buffer: BK/16 m16n8k16 steps (BK=32 -> 2 steps).
        #pragma unroll
        for(int kk=0; kk<BK; kk+=16){
            int kwb = kk/2;   // word offset of this k16 sub-step (8 words = 16 K)
            #pragma unroll
            for(int fmi=0; fmi<WM_FRAG; fmi++){
                int mrow = wm + fmi*16;
                // A fragment (m16k16,.row): thread (gid,tig) holds 4 words, each
                // = 2 bf16 along K. Word index for K-pair {2*tig,2*tig+1} is tig;
                // for {2*tig+8,2*tig+9} is tig+4. Same fragment map as OP-3, now a
                // single packed-word smem read per register (no packbf16).
                unsigned af[4];
                af[0]=Asw[buf][mrow+gid  ][kwb+tig  ];
                af[1]=Asw[buf][mrow+gid+8][kwb+tig  ];
                af[2]=Asw[buf][mrow+gid  ][kwb+tig+4];
                af[3]=Asw[buf][mrow+gid+8][kwb+tig+4];
                #pragma unroll
                for(int fni=0; fni<WN_FRAG; fni++){
                    int ncol = wn + fni*8;
                    // B fragment (m16n8k16,.col): thread (gid,tig) holds 2 regs,
                    // column n=gid, each reg = 2 bf16 along K. Bsh is k-major
                    // unpacked bf16: reg0 = {B[kk+2*tig][n], B[kk+2*tig+1][n]},
                    // reg1 = {B[kk+2*tig+8][n], B[kk+2*tig+9][n]}. Two cheap bf16
                    // smem reads per reg (B kept coalesced in global; pack here).
                    int bn0 = ncol+gid;
                    unsigned bf[2];
                    bf[0]=(unsigned)Bsh[buf][kk+2*tig  ][bn0] | ((unsigned)Bsh[buf][kk+2*tig+1][bn0]<<16);
                    bf[1]=(unsigned)Bsh[buf][kk+2*tig+8][bn0] | ((unsigned)Bsh[buf][kk+2*tig+9][bn0]<<16);
                    mma_m16n8k16(acc[fmi][fni], af, bf);
                }
            }
        }
        __syncthreads();
    }

    // store: .v2 (float2) vectorized C-store epilogue (OP-3b, bit-exact). m16n8 C
    // fragment fp32 layout identical to OP-3.
    #pragma unroll
    for(int fmi=0; fmi<WM_FRAG; fmi++){
        int mrow = bm + wm + fmi*16;
        #pragma unroll
        for(int fni=0; fni<WN_FRAG; fni++){
            int ncol = bn + wn + fni*8;
            float* d = acc[fmi][fni];
            int r0=mrow+gid, r1=mrow+gid+8, c0=ncol+2*tig, c1=ncol+2*tig+1;
#ifdef EPILOGUE_SCALAR
            if(r0<M && c0<N) C[(long long)r0*N+c0]=d[0];
            if(r0<M && c1<N) C[(long long)r0*N+c1]=d[1];
            if(r1<M && c0<N) C[(long long)r1*N+c0]=d[2];
            if(r1<M && c1<N) C[(long long)r1*N+c1]=d[3];
#else
            bool aligned = ((c0&1)==0);
            if(r0<M && c1<N && aligned) *reinterpret_cast<float2*>(&C[(long long)r0*N+c0]) = make_float2(d[0],d[1]);
            else { if(r0<M && c0<N) C[(long long)r0*N+c0]=d[0];
                   if(r0<M && c1<N) C[(long long)r0*N+c1]=d[1]; }
            if(r1<M && c1<N && aligned) *reinterpret_cast<float2*>(&C[(long long)r1*N+c0]) = make_float2(d[2],d[3]);
            else { if(r1<M && c0<N) C[(long long)r1*N+c0]=d[2];
                   if(r1<M && c1<N) C[(long long)r1*N+c1]=d[3]; }
#endif
        }
    }
}

extern "C" void owngemm_sm120_bf16_v2(float* C, const float* A, const float* B, int M, int K, int N){
    dim3 blk(NTHREAD);
    dim3 grid((N+BN-1)/BN, (M+BM-1)/BM);
    gemm_sm120_bf16_v2<<<grid,blk>>>(A,B,C,M,N,K);
}

#ifdef OWNGEMM_MAIN
static void fill(float* x, long long n, unsigned seed){
    for(long long i=0;i<n;i++){ unsigned h=(unsigned)(i*2654435761u)^seed; x[i]=((h&0xffff)/65535.f-0.5f)*0.2f; }
}
static void ref_fp64(const float* A,const float* B,double* R,int M,int N,int K){
    for(int i=0;i<M;i++) for(int j=0;j<N;j++){
        double s=0; for(int k=0;k<K;k++) s+=(double)A[(long long)i*K+k]*(double)B[(long long)k*N+j];
        R[(long long)i*N+j]=s;
    }
}
int main(int argc,char**argv){
    int S = argc>1?atoi(argv[1]):768;
    int MODE = argc>2?atoi(argv[2]):0;
    int M=S,N=S,K=S;
    size_t szA=(size_t)M*K, szB=(size_t)K*N, szC=(size_t)M*N;
    float *hA=(float*)malloc(szA*4),*hB=(float*)malloc(szB*4),*hC=(float*)malloc(szC*4),*hC2=(float*)malloc(szC*4);
    fill(hA,szA,11); fill(hB,szB,22);
    float *dA,*dB,*dC;
    CK(cudaMalloc(&dA,szA*4)); CK(cudaMalloc(&dB,szB*4)); CK(cudaMalloc(&dC,szC*4));
    CK(cudaMemcpy(dA,hA,szA*4,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB,hB,szB*4,cudaMemcpyHostToDevice));

    owngemm_sm120_bf16_v2(dC,dA,dB,M,K,N);
    cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){ printf("OWNGEMM FAULT: %s\n",cudaGetErrorString(e)); return 4; }
    CK(cudaMemcpy(hC,dC,szC*4,cudaMemcpyDeviceToHost));

    double *hR=(double*)malloc(szC*8);
    ref_fp64(hA,hB,hR,M,N,K);
    double se=0,sr=0,maxd=0;
    for(size_t i=0;i<szC;i++){ double a=hC[i],b=hR[i],dd=a-b; se+=dd*dd; sr+=b*b; if(fabs(dd)>maxd)maxd=fabs(dd); }
    double relrms = sr>0 ? sqrt(se/szC)/sqrt(sr/szC) : 0.0;
    printf("[GATE] S=%d own-GEMM-BF16-v2 vs FP64 ref: rel-RMS=%.3e max|delta|=%.3e (gate<=1e-2: %s)\n",
           S,relrms,maxd, relrms<=1e-2?"PASS":"FAIL");

    if(MODE==2){
        CK(cudaMemset(dC,0,szC*4));
        owngemm_sm120_bf16_v2(dC,dA,dB,M,K,N); CK(cudaDeviceSynchronize());
        CK(cudaMemcpy(hC2,dC,szC*4,cudaMemcpyDeviceToHost));
        double md=0; size_t nbit=0;
        for(size_t i=0;i<szC;i++){ double dd=fabs((double)hC[i]-(double)hC2[i]); if(dd>md)md=dd;
            unsigned u1,u2; memcpy(&u1,&hC[i],4); memcpy(&u2,&hC2[i],4); if(u1!=u2)nbit++; }
        printf("[DET] S=%d run-to-run max|delta|=%.3e bitdiff=%zu/%zu (determinism: %s)\n",
               S,md,nbit,szC, (md==0.0&&nbit==0)?"HELD":"BROKEN");
    }

    if(MODE==1){
        __nv_bfloat16 *dAb,*dBb; float *dCb;
        CK(cudaMalloc(&dAb,szA*2)); CK(cudaMalloc(&dBb,szB*2)); CK(cudaMalloc(&dCb,szC*4));
        __nv_bfloat16 *hAb=(__nv_bfloat16*)malloc(szA*2),*hBb=(__nv_bfloat16*)malloc(szB*2);
        for(size_t i=0;i<szA;i++) hAb[i]=__float2bfloat16(hA[i]);
        for(size_t i=0;i<szB;i++) hBb[i]=__float2bfloat16(hB[i]);
        CK(cudaMemcpy(dAb,hAb,szA*2,cudaMemcpyHostToDevice));
        CK(cudaMemcpy(dBb,hBb,szB*2,cudaMemcpyHostToDevice));
        cublasHandle_t cb; CB(cublasCreate(&cb));
        const float alpha=1.f, beta=0.f;
        int iters=50;
        owngemm_sm120_bf16_v2(dC,dA,dB,M,K,N); CK(cudaDeviceSynchronize());
        cudaEvent_t t0,t1; cudaEventCreate(&t0); cudaEventCreate(&t1);
        cudaEventRecord(t0);
        for(int it=0;it<iters;it++) owngemm_sm120_bf16_v2(dC,dA,dB,M,K,N);
        cudaEventRecord(t1); CK(cudaEventSynchronize(t1));
        float ms=0; cudaEventElapsedTime(&ms,t0,t1); double ms1=ms/iters;
        double flops=2.0*(double)M*N*K, tflops=flops/(ms1*1e-3)/1e12;
        CB(cublasGemmEx(cb, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha,
            dBb, CUDA_R_16BF, N, dAb, CUDA_R_16BF, K, &beta,
            dCb, CUDA_R_32F, N, CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
        CK(cudaDeviceSynchronize());
        cudaEventRecord(t0);
        for(int it=0;it<iters;it++)
          cublasGemmEx(cb, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha,
            dBb, CUDA_R_16BF, N, dAb, CUDA_R_16BF, K, &beta,
            dCb, CUDA_R_32F, N, CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP);
        cudaEventRecord(t1); CK(cudaEventSynchronize(t1));
        cudaEventElapsedTime(&ms,t0,t1); double cbms=ms/iters, cbtf=flops/(cbms*1e-3)/1e12;
        printf("[PERF] S=%d own-GEMM-BF16-v2 %.2f TFLOP/s (%.4f ms)  cuBLAS-BF16 %.2f TFLOP/s (%.4f ms)  off-cuBLAS=%.2fx\n",
               S,tflops,ms1,cbtf,cbms, cbtf/tflops);
    }
    return relrms<=1e-2?0:2;
}
#endif
