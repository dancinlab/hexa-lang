// owngemm_sm120_ozaki_int8.cu — Ozaki-scheme INT8 GEMM for consumer Blackwell
// sm_120 (RTX 5070, cc12.0). LAST cited TF32 speed-overturn lever (r-ozaki-int8).
//
// WHY: own TF32 mma.sync (owngemm_sm120.cu) measured ~0.87x cuBLAS-TF32 at
// 512-3072 on this card. Two emulation levers already MEASURE-FALSIFIED here:
//   - r-sched (ptxas already near-optimal; byte-eq PASS but perf-flat)
//   - r-3xtf32 FP16-accum (400x more accurate + deterministic, but 1.5-1.8x
//     SLOWER — this card's FP16:TF32 rate ~1.8x < the 2-3 MMA multiplier)
// The ONE remaining cited lever: INT8 tensor cores run ~4x the TF32 rate on
// GeForce — the only place the rate-advantage can exceed the emulation
// multiplier, but only at LARGE n.
//
// REFERENCES (reference-first, c23):
//   - ozIMMU: Ootomo, Ozaki, Yokota, arXiv 2306.11975 — DGEMM via INT8 TC.
//   - Ozaki-Scheme-II INT8: arXiv 2508.03984 — MEASURED on RTX 5080 (sm_120
//     sibling): OS-II INT8 beats native SGEMM at large n; for TF32-level
//     accuracy only N in {4,5,6,7} splits are needed; crossover ~n>=8K-12K.
//
// SCHEME (the integer error-free transform — deterministic by construction):
//   Each fp32 row of A (resp. col of B) is split into N int8 "slices" carrying
//   8 mantissa bits each, scaled by a shared per-row (per-col) exponent so the
//   slices are exact int8. Then:
//       A ~= sum_{p=0..N-1} 2^(-8p) * scaleA * Aint8[p]
//       B ~= sum_{q=0..N-1} 2^(-8q) * scaleB * Bint8[q]
//   so   A@B ~= scaleA*scaleB * sum_{p,q} 2^(-8(p+q)) * (Aint8[p] @ Bint8[q])
//   Each inner (Aint8[p] @ Bint8[q]) is an EXACT int32 matmul via IMMA
//   (mma.sync.aligned.m16n8k32.row.col.s32.s8.s8.s32) — the ~4x-rate path.
//   Slice pairs with p+q too large are dropped (their weight 2^(-8(p+q)) is
//   below the target accuracy floor) -> the "triangular" OS-II pruning. For
//   N total slices and a relative target ~1e-5 (TF32-level) we keep pairs with
//   p+q <= N-1 (so int8 slice count = N, distinct products ~ N(N+1)/2).
//
// DETERMINISM MOAT: the int8 products are EXACT integers; the int32 accum is
// associative-exact; the only fp rounding is the final scale recombine, done
// in a FIXED order (q-major then p-major). Run-to-run MUST be bit-identical.
// (the gate proves max|delta| run-to-run = 0.)
//
// This is an OPT-IN fastmode variant (HEXA_TF32_OZAKI_INT8). Shipped default
// TF32 + FP64 untouched -> byteeq-NEUTRAL.
//
// Modes (argv[2]):
//   0 GATE:   rel-RMS vs FP64 ref + off-ratio vs cuBLAS-TF32 (square S=argv[1]).
//   1 PERF:   TFLOP/s sweep + off-cuBLAS-TF32 ratio.
//   2 DET:    byte-identity run-to-run (max|delta| over 5 runs, must be 0).
//   3 DUMP:   write raw C to argv[3] (for external cmp).
// argv[3] (optional) = N splits (default 6).
//
// Build: build_owngemm_ozaki_int8.sh (run on aiden).

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cuda_runtime.h>
#include <cublas_v2.h>

#define CK(x) do{cudaError_t e=(x); if(e!=cudaSuccess){printf("CUDA-ERR %s @%d: %s\n",#x,__LINE__,cudaGetErrorString(e));exit(3);}}while(0)
#define CB(x) do{cublasStatus_t s=(x); if(s!=CUBLAS_STATUS_SUCCESS){printf("CUBLAS-ERR %d @%d\n",(int)s,__LINE__);exit(3);}}while(0)

#ifndef OZ_NMAX
#define OZ_NMAX 8
#endif

// ---------------------------------------------------------------------------
// SPLIT KERNELS — fp32 -> N int8 slices + a per-row/col fp32 scale.
//
// For a length-K row x (of A) we want slices s.t.
//   x[k] ~= scale * sum_{p} 2^(-8p) * int8_slice[p][k]
// where each int8_slice is in [-127,127]. We pick a single per-ROW scale
// (the row max abs), then peel 8 bits at a time. (OS-II uses per-row for A,
// per-col for B; the shared K dim is the contraction.)
//
// scale = 2^ceil(log2(maxabs))  (a power of two so the recombine is exact-ish
// and the first slice's top bit sits at bit 6). Then normalize r = x/scale in
// [-1,1], and for p in 0..N-1:  q = round(r * 128); slice = clamp(q,-127,127);
// r = r - slice/128; r *= 256 (shift left 8 bits for next slice).
// Wait — to keep slices int8 and weights 2^(-8p), peel as:
//   t = r * 128            (so |t| <= 128)
//   slice0 = round(t) clamped to [-127,127]
//   resid = t - slice0     (|resid| <= 0.5+)
//   for p>=1: resid *= 256; slice_p = round(resid)clamp; resid -= slice_p
// reconstruction: x ~= scale * (slice0/128 + slice1/128/256 + ...) = scale *
//   sum_p slice_p * 2^(-7-8p). We fold the 2^(-7) into a recombine constant.
// ---------------------------------------------------------------------------

// per-row scale (max abs) for A (M rows, K cols, row-major).
__global__ void row_maxabs(const float* __restrict__ A, float* __restrict__ scale, int M, int K){
    int r = blockIdx.x*blockDim.x + threadIdx.x;
    if(r>=M) return;
    float mx = 0.f;
    const float* row = A + (long long)r*K;
    for(int k=0;k<K;k++){ float v=fabsf(row[k]); if(v>mx) mx=v; }
    // round up to a power of two; guard zero rows.
    if(mx==0.f){ scale[r]=1.f; return; }
    int e; frexpf(mx, &e);         // mx = m * 2^e, m in [0.5,1)
    scale[r] = ldexpf(1.f, e);     // 2^e >= mx
}
// per-col scale (max abs) for B (K rows, N cols, row-major) -> scale[N].
__global__ void col_maxabs(const float* __restrict__ B, float* __restrict__ scale, int K, int N){
    int c = blockIdx.x*blockDim.x + threadIdx.x;
    if(c>=N) return;
    float mx = 0.f;
    for(int k=0;k<K;k++){ float v=fabsf(B[(long long)k*N+c]); if(v>mx) mx=v; }
    if(mx==0.f){ scale[c]=1.f; return; }
    int e; frexpf(mx,&e);
    scale[c]=ldexpf(1.f,e);
}

// Split A[M,K] row-major into Aint8[NSPL][M,K] (each int8), using per-row scale.
// Aint8 is laid [p][r*K + k]. Row-major int8.
__global__ void split_rows(const float* __restrict__ A, const float* __restrict__ scale,
                           int8_t* __restrict__ Aint8, int M, int K, int NSPL){
    long long idx = blockIdx.x*(long long)blockDim.x + threadIdx.x;
    long long tot = (long long)M*K;
    if(idx>=tot) return;
    int r = idx / K;
    float r0 = A[idx] / scale[r];        // in [-1,1]
    float t = r0 * 128.f;                // |t| <= 128
    float resid = t;
    long long stride = tot;
    for(int p=0;p<NSPL;p++){
        float s = rintf(resid);
        if(s> 127.f) s= 127.f; if(s<-127.f) s=-127.f;
        Aint8[(long long)p*stride + idx] = (int8_t)s;
        resid = (resid - s) * 256.f;
    }
}
// Split B[K,N] row-major into Bint8[NSPL][K,N], per-col scale (scale[N]).
__global__ void split_cols(const float* __restrict__ B, const float* __restrict__ scale,
                           int8_t* __restrict__ Bint8, int K, int N, int NSPL){
    long long idx = blockIdx.x*(long long)blockDim.x + threadIdx.x;
    long long tot = (long long)K*N;
    if(idx>=tot) return;
    int c = idx % N;
    float r0 = B[idx] / scale[c];
    float t = r0 * 128.f;
    float resid = t;
    long long stride = tot;
    for(int q=0;q<NSPL;q++){
        float s = rintf(resid);
        if(s> 127.f) s= 127.f; if(s<-127.f) s=-127.f;
        Bint8[(long long)q*stride + idx] = (int8_t)s;
        resid = (resid - s) * 256.f;
    }
}

// ---------------------------------------------------------------------------
// IMMA tile GEMM: Cint32[M,N] += Aint8p[M,K] @ Bint8q[K,N] (row-major, int8).
//
// Block tile BM x BN = 64 x 64, BK=32. 4 warps (128 threads) 2x2. Each warp
// owns 32x32 = 2 (m16) x 4 (n8) IMMA fragments. mma.sync m16n8k32 s8.s8.s32:
//   A frag = 4 int32 regs (16 int8 each = m16 x k32 / 32 lanes? layout below)
//   B frag = 2 int32 regs
//   C/D    = 4 int32 acc regs.
//
// We RUN ONE (p,q) product per launch (accumulating into Cint32 in DRAM with
// the proper 2^(-8(p+q)) weight applied on the host-side recombine? No — we
// accumulate the SCALED-recombine on device). To keep it simple+deterministic
// and bit-exact, we instead emit each (p,q) int32 product to its own pass and
// recombine in a final fp32 kernel with a FIXED summation order. But that is
// N(N+1)/2 DRAM C buffers. Better: accumulate weighted fp32 in-place with a
// fixed (p+q)-descending order so the recombine order is deterministic.
//
// DESIGN (deterministic recombine): we iterate products in order of DESCENDING
// weight w = p+q (largest 2^(-8w) first... actually smallest w = largest
// weight). To get a stable fp32 sum we go w = 0,1,2,... (decreasing magnitude)
// and within w, p = 0..w. Each product's int32 result is multiplied by
// scaleA[r]*scaleB[c]*2^(-7-8p)*2^(-7-8q) and ADDED into Cf32. Fixed order ->
// bit-identical. We do this by computing all products into one int32 scratch
// per (p,q) and folding — but to avoid N^2 DRAM, the gemm kernel takes (p,q)
// and an "accumulate weighted into Cf32" flag.
// ---------------------------------------------------------------------------

#define BM 64
#define BN 64
#define BK 32
#define WARPS_M 2
#define WARPS_N 2
#define NWARP (WARPS_M*WARPS_N)
#define NTHREAD (NWARP*32)
#define WM_FRAG 2
#define WN_FRAG 4
#define ISPAD 0   // int8 smem: pad in bytes; keep 0, handle conflicts via layout

__device__ __forceinline__ void imma_m16n8k32(int* d, const int* a, const int* b){
    asm volatile(
      "mma.sync.aligned.m16n8k32.row.col.s32.s8.s8.s32 "
      "{%0,%1,%2,%3}, {%4,%5,%6,%7}, {%8,%9}, {%0,%1,%2,%3};\n"
      : "+r"(d[0]),"+r"(d[1]),"+r"(d[2]),"+r"(d[3])
      : "r"(a[0]),"r"(a[1]),"r"(a[2]),"r"(a[3]),"r"(b[0]),"r"(b[1]));
}

// load one BK-stage of int8 slice S (M,K row-major) into smem As[BM][BK].
__device__ __forceinline__ void load_As(int8_t As[BM][BK], const int8_t* __restrict__ Ap,
                                         int bm,int k0,int M,int K,int tid){
    int i = tid;                              // 0..127, one int4 (16B) each
    int r = (i*16)/BK, cbyte = (i*16)%BK;     // BK=32 -> r=i/2, c=(i%2)*16
    int gr = bm+r, gc = k0+cbyte;
    if(gr<M && gc+16<=K)
        *reinterpret_cast<int4*>(&As[r][cbyte]) = *reinterpret_cast<const int4*>(&Ap[(long long)gr*K+gc]);
    else if(gr<M){ for(int e=0;e<16;e++){ int cc=gc+e; As[r][cbyte+e]=(cc<K)?Ap[(long long)gr*K+cc]:(int8_t)0; } }
    else *reinterpret_cast<int4*>(&As[r][cbyte]) = make_int4(0,0,0,0);
}
__device__ __forceinline__ void load_Bs(int8_t Bs[BK][BN], const int8_t* __restrict__ Bq,
                                         int bn,int k0,int K,int N,int tid){
    int i = tid;
    int r = (i*16)/BN, cbyte=(i*16)%BN;       // BN=64 -> r=i/4, c=(i%4)*16
    int gr = k0+r, gc = bn+cbyte;
    if(gr<K && gc+16<=N)
        *reinterpret_cast<int4*>(&Bs[r][cbyte]) = *reinterpret_cast<const int4*>(&Bq[(long long)gr*N+gc]);
    else if(gr<K){ for(int e=0;e<16;e++){ int cc=gc+e; Bs[r][cbyte+e]=(cc<N)?Bq[(long long)gr*N+cc]:(int8_t)0; } }
    else *reinterpret_cast<int4*>(&Bs[r][cbyte]) = make_int4(0,0,0,0);
}

// OUTPUT-STATIONARY Ozaki-INT8 GEMM. Each block owns a 64x64 output tile and
// is the ONLY writer of it (disjoint tiles -> NO race, NO atomics). It loops
// over all (p,q) slice products in a FIXED order (q-major within p-major) and
// accumulates the weighted fp32 result in registers, then writes C once. The
// fixed loop order + register fp32 accumulate => bit-identical run-to-run
// (the determinism moat). int32 products are EXACT.
//
// Pruning (OS-II triangular): only pairs with p+q <= NSPL-1 are computed
// (their weight 2^(-8(p+q)) dominates; deeper pairs are below the ~1e-5 floor).
// Slices laid: Aint8[p][M*K], Bint8[q][K*N] contiguous (stride = M*K / K*N).
extern "C" __global__ void ozaki_gemm(
        const int8_t* __restrict__ Aint8, const int8_t* __restrict__ Bint8,
        float* __restrict__ C,
        const float* __restrict__ scaleA, const float* __restrict__ scaleB,
        int M, int N, int K, int NSPL){
    __shared__ int8_t As[BM][BK];
    __shared__ int8_t Bs[BK][BN];
    int bm = blockIdx.y*BM, bn = blockIdx.x*BN;
    int tid = threadIdx.x;
    int warp = tid>>5, lane = tid&31;
    int wm = (warp/WARPS_N)*32;
    int wn = (warp%WARPS_N)*32;
    int gid = lane>>2, tig = lane&3;

    // fp32 register accumulators for this tile's outputs (the deterministic sum).
    float facc[WM_FRAG][WN_FRAG][4];
    #pragma unroll
    for(int i=0;i<WM_FRAG;i++)for(int j=0;j<WN_FRAG;j++)for(int e=0;e<4;e++) facc[i][j][e]=0.f;

    long long strideA = (long long)M*K, strideB = (long long)K*N;
    int nk = (K+BK-1)/BK;

    // FIXED ORDER: p = 0..NSPL-1 (outer), q = 0..NSPL-1-p (inner). weight grows
    // smaller as p+q grows; this ascending-(p+q) order keeps the fp32 sum stable.
    for(int p=0; p<NSPL; p++){
        const int8_t* Ap = Aint8 + (long long)p*strideA;
        for(int q=0; q + p < NSPL; q++){
            const int8_t* Bq = Bint8 + (long long)q*strideB;
            float wpq = ldexpf(1.f, -(7+8*p)) * ldexpf(1.f, -(7+8*q));

            int iacc[WM_FRAG][WN_FRAG][4];
            #pragma unroll
            for(int i=0;i<WM_FRAG;i++)for(int j=0;j<WN_FRAG;j++)for(int e=0;e<4;e++) iacc[i][j][e]=0;

            for(int k=0;k<nk;k++){
                int k0 = k*BK;
                load_As(As,Ap,bm,k0,M,K,tid);
                load_Bs(Bs,Bq,bn,k0,K,N,tid);
                __syncthreads();
                // m16n8k32 s8.s8.s32 fragment loads (canonical .row.col layout).
                #pragma unroll
                for(int fmi=0; fmi<WM_FRAG; fmi++){
                    int mrow = wm + fmi*16;
                    int af[4];
                    af[0]=*reinterpret_cast<int*>(&As[mrow+gid   ][tig*4]);
                    af[1]=*reinterpret_cast<int*>(&As[mrow+gid+8 ][tig*4]);
                    af[2]=*reinterpret_cast<int*>(&As[mrow+gid   ][16+tig*4]);
                    af[3]=*reinterpret_cast<int*>(&As[mrow+gid+8 ][16+tig*4]);
                    #pragma unroll
                    for(int fni=0; fni<WN_FRAG; fni++){
                        int ncol = wn + fni*8;
                        int8_t bb0[4], bb1[4];
                        #pragma unroll
                        for(int e=0;e<4;e++){
                            bb0[e]=Bs[tig*4+e   ][ncol+gid];
                            bb1[e]=Bs[16+tig*4+e][ncol+gid];
                        }
                        int bf[2]={*reinterpret_cast<int*>(bb0),*reinterpret_cast<int*>(bb1)};
                        imma_m16n8k32(iacc[fmi][fni], af, bf);
                    }
                }
                __syncthreads();
            }
            // fold this (p,q) int32 product into the fp32 register accumulator
            // with the slice weight wpq (per-element scaleA*scaleB folded at store).
            #pragma unroll
            for(int i=0;i<WM_FRAG;i++)for(int j=0;j<WN_FRAG;j++)
                #pragma unroll
                for(int e=0;e<4;e++) facc[i][j][e] += (float)iacc[i][j][e] * wpq;
        }
    }

    // store: apply per-row/col scale and write once (sole writer of this tile).
    #pragma unroll
    for(int fmi=0; fmi<WM_FRAG; fmi++){
        int mrow = bm + wm + fmi*16;
        #pragma unroll
        for(int fni=0; fni<WN_FRAG; fni++){
            int ncol = bn + wn + fni*8;
            float* d = facc[fmi][fni];
            int r0=mrow+gid, r1=mrow+gid+8, c0=ncol+2*tig, c1=ncol+2*tig+1;
            if(r0<M && c0<N) C[(long long)r0*N+c0]=d[0]*scaleA[r0]*scaleB[c0];
            if(r0<M && c1<N) C[(long long)r0*N+c1]=d[1]*scaleA[r0]*scaleB[c1];
            if(r1<M && c0<N) C[(long long)r1*N+c0]=d[2]*scaleA[r1]*scaleB[c0];
            if(r1<M && c1<N) C[(long long)r1*N+c1]=d[3]*scaleA[r1]*scaleB[c1];
        }
    }
}

// ---------------------------------------------------------------------------
// host wrapper: Ozaki-INT8 GEMM C[M,N] = A[M,K] @ B[K,N] (all row-major fp32),
// using NSPL int8 slices. Allocates slice + scale scratch each call (the bench
// reuses persistent scratch; this is the convenience entry).
// ---------------------------------------------------------------------------
extern "C" void ozaki_int8_gemm(float* C, const float* A, const float* B,
                                int M, int K, int N, int NSPL,
                                int8_t* Aint8, int8_t* Bint8,
                                float* scaleA, float* scaleB){
    // 1) per-row/col scales
    row_maxabs<<<(M+255)/256,256>>>(A, scaleA, M, K);
    col_maxabs<<<(N+255)/256,256>>>(B, scaleB, K, N);
    // 2) split into int8 slices
    long long totA=(long long)M*K, totB=(long long)K*N;
    split_rows<<<(totA+255)/256,256>>>(A, scaleA, Aint8, M, K, NSPL);
    split_cols<<<(totB+255)/256,256>>>(B, scaleB, Bint8, K, N, NSPL);
    // 3) output-stationary Ozaki GEMM
    dim3 blk(NTHREAD);
    dim3 grid((N+BN-1)/BN, (M+BM-1)/BM);
    ozaki_gemm<<<grid,blk>>>(Aint8, Bint8, C, scaleA, scaleB, M, N, K, NSPL);
}

#ifdef OZAKI_MAIN
static void fill(float* x, long long n, unsigned seed){
    for(long long i=0;i<n;i++){ unsigned h=(unsigned)(i*2654435761u)^seed; x[i]=((h&0xffff)/65535.f-0.5f)*0.2f; }
}
// FP64 host reference (the accuracy oracle).
static void ref_fp64(const float* A,const float* B,double* R,int M,int N,int K){
    for(int i=0;i<M;i++) for(int j=0;j<N;j++){
        double s=0; for(int k=0;k<K;k++) s += (double)A[(long long)i*K+k]*(double)B[(long long)k*N+j];
        R[(long long)i*N+j]=s;
    }
}
int main(int argc,char**argv){
    int S    = argc>1?atoi(argv[1]):4096;
    int MODE = argc>2?atoi(argv[2]):0;
    int NSPL = 6;
    const char* dumpf=nullptr;
    if(MODE==3){ dumpf = argc>3?argv[3]:"/tmp/oz_dump.bin"; if(argc>4) NSPL=atoi(argv[4]); }
    else if(argc>3) NSPL=atoi(argv[3]);
    if(NSPL<1) NSPL=1; if(NSPL>OZ_NMAX) NSPL=OZ_NMAX;
    int M=S,N=S,K=S;
    size_t szA=(size_t)M*K, szB=(size_t)K*N, szC=(size_t)M*N;
    float *hA=(float*)malloc(szA*4),*hB=(float*)malloc(szB*4),*hC=(float*)malloc(szC*4),*hR=(float*)malloc(szC*4);
    fill(hA,szA,11); fill(hB,szB,22);

    float *dA,*dB,*dC,*dR; int8_t *dAi,*dBi; float *dSA,*dSB;
    CK(cudaMalloc(&dA,szA*4)); CK(cudaMalloc(&dB,szB*4)); CK(cudaMalloc(&dC,szC*4)); CK(cudaMalloc(&dR,szC*4));
    CK(cudaMalloc(&dAi,(size_t)NSPL*szA)); CK(cudaMalloc(&dBi,(size_t)NSPL*szB));
    CK(cudaMalloc(&dSA,(size_t)M*4)); CK(cudaMalloc(&dSB,(size_t)N*4));
    CK(cudaMemcpy(dA,hA,szA*4,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB,hB,szB*4,cudaMemcpyHostToDevice));

    // cuBLAS-TF32 ref/perf: R = A@B row-major == cublas(N,N, N,M,K, B,A) col-major.
    cublasHandle_t cb; CB(cublasCreate(&cb));
    CB(cublasSetMathMode(cb, CUBLAS_TF32_TENSOR_OP_MATH));
    const float alpha=1.f, beta=0.f;
    auto run_cublas=[&](float* out){
        CB(cublasGemmEx(cb, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha,
            dB, CUDA_R_32F, N, dA, CUDA_R_32F, K, &beta,
            out, CUDA_R_32F, N, CUBLAS_COMPUTE_32F_FAST_TF32, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
    };

    auto run_own=[&](){
        ozaki_int8_gemm(dC,dA,dB,M,K,N,NSPL,dAi,dBi,dSA,dSB);
    };

    // correctness first
    run_own();
    cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){ printf("OZAKI FAULT: %s\n",cudaGetErrorString(e)); return 4; }
    CK(cudaMemcpy(hC,dC,szC*4,cudaMemcpyDeviceToHost));

    if(MODE==3){
        FILE* f=fopen(dumpf,"wb"); fwrite(hC,4,szC,f); fclose(f);
        printf("[DUMP] S=%d NSPL=%d -> %s (%zu floats)\n",S,NSPL,dumpf,szC);
        return 0;
    }

    if(MODE==2){
        // determinism: 5 runs, max|delta| vs run0 must be 0.
        float* h0=(float*)malloc(szC*4); memcpy(h0,hC,szC*4);
        double maxd=0;
        for(int it=0;it<5;it++){
            run_own(); CK(cudaDeviceSynchronize());
            CK(cudaMemcpy(hC,dC,szC*4,cudaMemcpyDeviceToHost));
            for(size_t i=0;i<szC;i++){ double dd=fabs((double)hC[i]-(double)h0[i]); if(dd>maxd)maxd=dd; }
        }
        printf("[DET] S=%d NSPL=%d run-to-run max|delta|=%.3e (byte-eq: %s)\n",
               S,NSPL,maxd, maxd==0.0?"PASS (bit-identical)":"FAIL");
        return maxd==0.0?0:2;
    }

    // GATE: rel-RMS vs FP64 + off-ratio vs cuBLAS-TF32.
    // FP64 ref only for S<=4096 (host O(n^3) cost); else compare vs cuBLAS-TF32
    // as the practical accuracy floor and report rel-RMS vs cuBLAS.
    double relrms_fp64=-1, relrms_cb=-1, maxd_cb=0;
    run_cublas(dR); CK(cudaDeviceSynchronize());
    CK(cudaMemcpy(hR,dR,szC*4,cudaMemcpyDeviceToHost));
    { double se=0,sr=0; for(size_t i=0;i<szC;i++){ double dd=(double)hC[i]-(double)hR[i]; se+=dd*dd; sr+=(double)hR[i]*(double)hR[i]; if(fabs(dd)>maxd_cb)maxd_cb=fabs(dd);} relrms_cb=sr>0?sqrt(se/szC)/sqrt(sr/szC):0; }
    if(S<=2048){
        double* hF=(double*)malloc(szC*8); ref_fp64(hA,hB,hF,M,N,K);
        double se=0,sr=0; for(size_t i=0;i<szC;i++){ double dd=(double)hC[i]-hF[i]; se+=dd*dd; sr+=hF[i]*hF[i]; } relrms_fp64=sr>0?sqrt(se/szC)/sqrt(sr/szC):0;
        // also cuBLAS-TF32's own rel-RMS vs FP64 for context
        double se2=0; for(size_t i=0;i<szC;i++){ double dd=(double)hR[i]-hF[i]; se2+=dd*dd; }
        double cb_fp64 = sr>0?sqrt(se2/szC)/sqrt(sr/szC):0;
        printf("[GATE] S=%d NSPL=%d  rel-RMS(own vs FP64)=%.3e  rel-RMS(cuBLAS-TF32 vs FP64)=%.3e  rel-RMS(own vs cuBLAS)=%.3e\n",
               S,NSPL,relrms_fp64,cb_fp64,relrms_cb);
        free(hF);
    } else {
        printf("[GATE] S=%d NSPL=%d  rel-RMS(own vs cuBLAS-TF32)=%.3e  max|delta|=%.3e  (FP64 ref skipped: S>4096)\n",
               S,NSPL,relrms_cb,maxd_cb);
    }

    if(MODE==1){
        int iters = S>=8192?10:30;
        // own perf
        run_own(); CK(cudaDeviceSynchronize());
        cudaEvent_t t0,t1; cudaEventCreate(&t0); cudaEventCreate(&t1);
        cudaEventRecord(t0); for(int it=0;it<iters;it++) run_own(); cudaEventRecord(t1); CK(cudaEventSynchronize(t1));
        float ms=0; cudaEventElapsedTime(&ms,t0,t1); double ms1=ms/iters;
        double flops=2.0*(double)M*N*K, tflops=flops/(ms1*1e-3)/1e12;
        // cuBLAS-TF32 perf
        run_cublas(dR); CK(cudaDeviceSynchronize());
        cudaEventRecord(t0); for(int it=0;it<iters;it++) run_cublas(dR); cudaEventRecord(t1); CK(cudaEventSynchronize(t1));
        cudaEventElapsedTime(&ms,t0,t1); double cbms=ms/iters, cbtf=flops/(cbms*1e-3)/1e12;
        printf("[PERF] S=%d NSPL=%d  Ozaki-INT8 %.2f TFLOP/s (%.3f ms)  cuBLAS-TF32 %.2f TFLOP/s (%.3f ms)  off-cuBLAS=%.3fx  speedup=%.3fx\n",
               S,NSPL,tflops,ms1,cbtf,cbms, cbtf/tflops, tflops/cbtf);
    }
    return 0;
}
#endif
