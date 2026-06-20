// owngemm_sm120_multi.cu — tf32-parity-research r2: multi-config CTA tiling +
// size dispatch for the sm_120 TF32 own-GEMM, layered on the BENCH-5/OP-1
// mma.sync.aligned.m16n8k8.row.col.f32.tf32.tf32.f32 kernel.
//
// r1 measured the 64x64 fixed-tile signature: own saturates ~30 TFLOP/s while
// cuBLAS-TF32 reaches ~34, so own loses 11-25% at every large-N size (1024+).
// The wall is arithmetic intensity: a 64x64 CTA produces too few outputs per
// smem byte loaded. REFERENCE (c23): CUTLASS/BLIS large-tile register blocking
// (128x128, 128x64) raises reuse — CUTLASS 4.2 added sm_120 128x64 tiles for
// +30%. This harness adds a 128x128 tile (8 warps, each warp 64x32 = 4x4 frags)
// alongside the 64x64 tile and dispatches by problem size.
//
// LEVERS (compile flags, applied incrementally + measured — NOT guessed):
//   LEVER1 multi-tile        : 128x128 kernel available + size dispatch (default ON here)
//   -DDEEP=N (N=2,3,4)       : cp.async pipeline depth on the 128x128 kernel (LEVER2)
//   -DSWZ=1                  : XOR smem swizzle on the 128x128 ldmatrix path (LEVER3)
//
// All kernels keep the IDENTICAL per-output K-major mma.sync accumulation order
// as OP-1 (so rel-RMS vs cuBLAS-TF32 stays at the OP-1 ~1e-5 level, gate <= 1e-2).
//
// Build: build_owngemm_multi.sh (run on aiden). Mode 0 = GATE, 1 = PERF.

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cuda_runtime.h>
#include <cublas_v2.h>

#define CK(x) do{cudaError_t e=(x); if(e!=cudaSuccess){printf("CUDA-ERR %s @%d: %s\n",#x,__LINE__,cudaGetErrorString(e));exit(3);}}while(0)
#define CB(x) do{cublasStatus_t s=(x); if(s!=CUBLAS_STATUS_SUCCESS){printf("CUBLAS-ERR %d @%d\n",(int)s,__LINE__);exit(3);}}while(0)

#ifndef DEEP
#define DEEP 2          // cp.async pipeline depth for the 128x128 kernel
#endif
#ifndef SWZ
#define SWZ 0           // XOR smem swizzle on the 128x128 path
#endif

// ---- shared TF32 / mma primitives ----
__device__ __forceinline__ unsigned f2tf32(float x){
    unsigned u; memcpy(&u,&x,4); u=(u+0x1000u)&0xFFFFE000u; return u;
}
__device__ __forceinline__ void mma_m16n8k8(float* d, const unsigned* a, const unsigned* b){
    asm volatile(
      "mma.sync.aligned.m16n8k8.row.col.f32.tf32.tf32.f32 "
      "{%0,%1,%2,%3}, {%4,%5,%6,%7}, {%8,%9}, {%0,%1,%2,%3};\n"
      : "+f"(d[0]),"+f"(d[1]),"+f"(d[2]),"+f"(d[3])
      : "r"(a[0]),"r"(a[1]),"r"(a[2]),"r"(a[3]),"r"(b[0]),"r"(b[1]));
}
__device__ __forceinline__ void cp_async_cg16(void* smem, const void* gmem){
    unsigned s = (unsigned)__cvta_generic_to_shared(smem);
    asm volatile("cp.async.cg.shared.global [%0], [%1], 16;\n" :: "r"(s), "l"(gmem));
}
__device__ __forceinline__ void cp_async_commit(){ asm volatile("cp.async.commit_group;\n"); }
template<int N> __device__ __forceinline__ void cp_async_wait(){ asm volatile("cp.async.wait_group %0;\n" :: "n"(N)); }

// =====================================================================
// 64x64 kernel — OP-1's exact production tiling (the r1 baseline). Used by
// the size dispatch for small problems where the big tile under-fills the grid.
// =====================================================================
#define S_BM 64
#define S_BN 64
#define S_BK 16
#define S_WM 2
#define S_WN 2
#define S_NWARP (S_WM*S_WN)
#define S_NTHREAD (S_NWARP*32)
#define S_WMF 2
#define S_WNF 4
#define S_ASPAD 4
#define S_BSPAD 4

extern "C" __global__ void gemm_sm120_64(const float* __restrict__ A,
                                         const float* __restrict__ B,
                                         float* __restrict__ C,
                                         int M, int N, int K){
    __shared__ float As[2][S_BM][S_BK+S_ASPAD];
    __shared__ float Bs[2][S_BK][S_BN+S_BSPAD];
    int bm = blockIdx.y*S_BM, bn = blockIdx.x*S_BN;
    int tid = threadIdx.x;
    int warp = tid>>5, lane = tid&31;
    int wm = (warp/S_WN)*32, wn = (warp%S_WN)*32;
    int gid = lane>>2, tig = lane&3;
    float acc[S_WMF][S_WNF][4];
    #pragma unroll
    for(int i=0;i<S_WMF;i++)for(int j=0;j<S_WNF;j++)for(int e=0;e<4;e++) acc[i][j][e]=0.f;
    int nk = (K+S_BK-1)/S_BK;
    auto load_stage = [&](int buf,int k0){
        #pragma unroll
        for(int i=tid; i<S_BM*S_BK/4; i+=S_NTHREAD){
            int r=i/(S_BK/4), c4=i%(S_BK/4), c=c4*4; int gr=bm+r, gc=k0+c;
            if(gr<M && gc+3<K) cp_async_cg16(&As[buf][r][c], &A[(long long)gr*K+gc]);
            else { float4 v=make_float4(0,0,0,0);
                   if(gr<M){ for(int e=0;e<4;e++) ((float*)&v)[e]=(gc+e<K)?A[(long long)gr*K+gc+e]:0.f; }
                   As[buf][r][c+0]=v.x;As[buf][r][c+1]=v.y;As[buf][r][c+2]=v.z;As[buf][r][c+3]=v.w; }
        }
        #pragma unroll
        for(int i=tid; i<S_BK*S_BN/4; i+=S_NTHREAD){
            int r=i/(S_BN/4), c4=i%(S_BN/4), c=c4*4; int gr=k0+r, gc=bn+c;
            if(gr<K && gc+3<N) cp_async_cg16(&Bs[buf][r][c], &B[(long long)gr*N+gc]);
            else { float4 v=make_float4(0,0,0,0);
                   if(gr<K){ for(int e=0;e<4;e++) ((float*)&v)[e]=(gc+e<N)?B[(long long)gr*N+gc+e]:0.f; }
                   Bs[buf][r][c+0]=v.x;Bs[buf][r][c+1]=v.y;Bs[buf][r][c+2]=v.z;Bs[buf][r][c+3]=v.w; }
        }
    };
    load_stage(0,0); cp_async_commit();
    for(int k=0;k<nk;k++){
        int buf=k&1,nbuf=(k+1)&1;
        if(k+1<nk){ load_stage(nbuf,(k+1)*S_BK); cp_async_commit(); cp_async_wait<1>(); }
        else      { cp_async_wait<0>(); }
        __syncthreads();
        #pragma unroll
        for(int ks=0;ks<S_BK;ks+=8){
            #pragma unroll
            for(int fmi=0;fmi<S_WMF;fmi++){
                int mrow=wm+fmi*16; unsigned af[4];
                af[0]=f2tf32(As[buf][mrow+gid  ][ks+tig  ]);
                af[1]=f2tf32(As[buf][mrow+gid+8][ks+tig  ]);
                af[2]=f2tf32(As[buf][mrow+gid  ][ks+tig+4]);
                af[3]=f2tf32(As[buf][mrow+gid+8][ks+tig+4]);
                #pragma unroll
                for(int fni=0;fni<S_WNF;fni++){
                    int ncol=wn+fni*8; unsigned bf[2];
                    bf[0]=f2tf32(Bs[buf][ks+tig  ][ncol+gid]);
                    bf[1]=f2tf32(Bs[buf][ks+tig+4][ncol+gid]);
                    mma_m16n8k8(acc[fmi][fni],af,bf);
                }
            }
        }
        __syncthreads();
    }
    #pragma unroll
    for(int fmi=0;fmi<S_WMF;fmi++){
        int mrow=bm+wm+fmi*16;
        #pragma unroll
        for(int fni=0;fni<S_WNF;fni++){
            int ncol=bn+wn+fni*8; float* d=acc[fmi][fni];
            int r0=mrow+gid,r1=mrow+gid+8,c0=ncol+2*tig,c1=ncol+2*tig+1;
            bool al=((c0&1)==0);
            if(r0<M&&c1<N&&al) *reinterpret_cast<float2*>(&C[(long long)r0*N+c0])=make_float2(d[0],d[1]);
            else{ if(r0<M&&c0<N)C[(long long)r0*N+c0]=d[0]; if(r0<M&&c1<N)C[(long long)r0*N+c1]=d[1]; }
            if(r1<M&&c1<N&&al) *reinterpret_cast<float2*>(&C[(long long)r1*N+c0])=make_float2(d[2],d[3]);
            else{ if(r1<M&&c0<N)C[(long long)r1*N+c0]=d[2]; if(r1<M&&c1<N)C[(long long)r1*N+c1]=d[3]; }
        }
    }
}

// =====================================================================
// 128x128 kernel (LEVER1) — register-blocked large tile.
//   BM=BN=128, BK=16, 8 warps (256 threads) laid 2x4.
//   Each warp owns 64x32 output = WMF=4 (m16) x WNF=4 (n8) fragments.
//   acc = 4x4x4 = 64 f32/thread.
//   cp.async pipeline depth = DEEP (LEVER2); SWZ=1 XOR-swizzles smem (LEVER3).
// Dynamic shared memory: DEEP*(128*(16+pad) + 16*(128+pad))*4 bytes.
// =====================================================================
#ifndef BIG
#define BIG 128                // big-tile BN: 128 (128x128) or 64 (128x64)
#endif
#define L_BM 128
#define L_BN BIG
#define L_BK 16
#if BIG == 128
#define L_WM 2
#define L_WN 4                 // 8 warps, each warp 64x32 = 4x4 frags
#else
#define L_WM 4
#define L_WN 2                 // 128x64: 8 warps 4x2, each warp 32x32 = 2x4 frags
#endif
#define L_NWARP (L_WM*L_WN)    // 8
#define L_NTHREAD (L_NWARP*32) // 256
#define L_WMF (128/L_WM/16)    // m-frags per warp
#define L_WNF (L_BN/L_WN/8)    // n-frags per warp
#if SWZ
#define L_ASPAD 0
#define L_BSPAD 0
#else
#define L_ASPAD 4
#define L_BSPAD 4
#endif
#define L_ASTRIDE (L_BK+L_ASPAD)
#define L_BSTRIDE (L_BN+L_BSPAD)

// XOR swizzle: permute the column index within a 32-bank window keyed by row,
// so consecutive ldmatrix lanes hit distinct banks. Same permutation is used in
// BOTH the cp.async store and the register load, so the data is logically
// identical (rel-RMS unchanged) — only the physical bank placement differs.
// For As: row r in [0,128), col c in [0,16); swizzle c ^= (r&7)? — but As BK=16
// only spans 4 banks of f32 (16*4=64B = 16 banks). We swizzle the leading dim.
__device__ __forceinline__ int swzA(int r,int c){
#if SWZ
    return c ^ ((r & 7));        // 8-row XOR group within the 16-wide K strip
#else
    return c;
#endif
}
__device__ __forceinline__ int swzB(int r,int c){
#if SWZ
    return c ^ ((r & 7) << 3);   // shift into the 128-wide N strip (8-bank stride)
#else
    return c;
#endif
}

extern "C" __global__ void gemm_sm120_128(const float* __restrict__ A,
                                          const float* __restrict__ B,
                                          float* __restrict__ C,
                                          int M, int N, int K){
    extern __shared__ float smem[];
    // As[DEEP][128][L_ASTRIDE], Bs[DEEP][16][L_BSTRIDE]
    float* As = smem;
    float* Bs = smem + (size_t)DEEP*L_BM*L_ASTRIDE;
    auto AsAt = [&](int buf,int r,int c)->float& { return As[((size_t)buf*L_BM + r)*L_ASTRIDE + swzA(r,c)]; };
    auto BsAt = [&](int buf,int r,int c)->float& { return Bs[((size_t)buf*L_BK + r)*L_BSTRIDE + swzB(r,c)]; };

    int bm = blockIdx.y*L_BM, bn = blockIdx.x*L_BN;
    int tid = threadIdx.x;
    int warp = tid>>5, lane = tid&31;
    int wm = (warp/L_WN)*(L_WMF*16);    // warp row offset
    int wn = (warp%L_WN)*(L_WNF*8);     // warp col offset
    int gid = lane>>2, tig = lane&3;

    float acc[L_WMF][L_WNF][4];
    #pragma unroll
    for(int i=0;i<L_WMF;i++)for(int j=0;j<L_WNF;j++)for(int e=0;e<4;e++) acc[i][j][e]=0.f;

    int nk = (K+L_BK-1)/L_BK;

    // load one BK stage. A: 128x16 = 2048 floats = 512 float4 / 256 thr -> 2 each.
    // B: 16x128 = 2048 floats = 512 float4 -> 2 each. Swizzle is applied per-float
    // when storing (so cp.async 128-bit vector store can't be used under swizzle;
    // we scalarize the store when SWZ=1, vectorize when SWZ=0).
    auto load_stage = [&](int buf,int k0){
#if SWZ
        // scalar store path so we can XOR the destination column
        #pragma unroll
        for(int i=tid;i<L_BM*L_BK;i+=L_NTHREAD){
            int r=i/L_BK, c=i%L_BK; int gr=bm+r, gc=k0+c;
            AsAt(buf,r,c) = (gr<M&&gc<K)? A[(long long)gr*K+gc] : 0.f;
        }
        #pragma unroll
        for(int i=tid;i<L_BK*L_BN;i+=L_NTHREAD){
            int r=i/L_BN, c=i%L_BN; int gr=k0+r, gc=bn+c;
            BsAt(buf,r,c) = (gr<K&&gc<N)? B[(long long)gr*N+gc] : 0.f;
        }
#else
        #pragma unroll
        for(int i=tid;i<L_BM*L_BK/4;i+=L_NTHREAD){
            int r=i/(L_BK/4), c4=i%(L_BK/4), c=c4*4; int gr=bm+r, gc=k0+c;
            if(gr<M&&gc+3<K) cp_async_cg16(&AsAt(buf,r,c), &A[(long long)gr*K+gc]);
            else { float4 v=make_float4(0,0,0,0);
                   if(gr<M){for(int e=0;e<4;e++)((float*)&v)[e]=(gc+e<K)?A[(long long)gr*K+gc+e]:0.f;}
                   AsAt(buf,r,c+0)=v.x;AsAt(buf,r,c+1)=v.y;AsAt(buf,r,c+2)=v.z;AsAt(buf,r,c+3)=v.w; }
        }
        #pragma unroll
        for(int i=tid;i<L_BK*L_BN/4;i+=L_NTHREAD){
            int r=i/(L_BN/4), c4=i%(L_BN/4), c=c4*4; int gr=k0+r, gc=bn+c;
            if(gr<K&&gc+3<N) cp_async_cg16(&BsAt(buf,r,c), &B[(long long)gr*N+gc]);
            else { float4 v=make_float4(0,0,0,0);
                   if(gr<K){for(int e=0;e<4;e++)((float*)&v)[e]=(gc+e<N)?B[(long long)gr*N+gc+e]:0.f;}
                   BsAt(buf,r,c+0)=v.x;BsAt(buf,r,c+1)=v.y;BsAt(buf,r,c+2)=v.z;BsAt(buf,r,c+3)=v.w; }
        }
#endif
    };

    auto compute_stage = [&](int buf){
        #pragma unroll
        for(int ks=0;ks<L_BK;ks+=8){
            #pragma unroll
            for(int fmi=0;fmi<L_WMF;fmi++){
                int mrow=wm+fmi*16; unsigned af[4];
                af[0]=f2tf32(AsAt(buf,mrow+gid  ,ks+tig  ));
                af[1]=f2tf32(AsAt(buf,mrow+gid+8,ks+tig  ));
                af[2]=f2tf32(AsAt(buf,mrow+gid  ,ks+tig+4));
                af[3]=f2tf32(AsAt(buf,mrow+gid+8,ks+tig+4));
                #pragma unroll
                for(int fni=0;fni<L_WNF;fni++){
                    int ncol=wn+fni*8; unsigned bf[2];
                    bf[0]=f2tf32(BsAt(buf,ks+tig  ,ncol+gid));
                    bf[1]=f2tf32(BsAt(buf,ks+tig+4,ncol+gid));
                    mma_m16n8k8(acc[fmi][fni],af,bf);
                }
            }
        }
    };

#if DEEP == 2
    load_stage(0,0); cp_async_commit();
    for(int k=0;k<nk;k++){
        int buf=k&1,nbuf=(k+1)&1;
        if(k+1<nk){ load_stage(nbuf,(k+1)*L_BK); cp_async_commit();
#if !SWZ
            cp_async_wait<1>();
#endif
        }
#if !SWZ
        else { cp_async_wait<0>(); }
#endif
        __syncthreads();
        compute_stage(buf);
        __syncthreads();
    }
#else
    // DEEP>=3 ring
    #pragma unroll
    for(int s=0;s<DEEP-1;s++){ if(s<nk){ load_stage(s, s*L_BK);} cp_async_commit(); }
    for(int k=0;k<nk;k++){
        int buf=k%DEEP;
        int kp=k+(DEEP-1);
        if(kp<nk){ load_stage(kp%DEEP, kp*L_BK); }
        cp_async_commit();
#if !SWZ
        cp_async_wait<DEEP-1>();
#endif
        __syncthreads();
        compute_stage(buf);
        __syncthreads();
    }
#endif

    // epilogue (float2 .v2 store, same as OP-1b)
    #pragma unroll
    for(int fmi=0;fmi<L_WMF;fmi++){
        int mrow=bm+wm+fmi*16;
        #pragma unroll
        for(int fni=0;fni<L_WNF;fni++){
            int ncol=bn+wn+fni*8; float* d=acc[fmi][fni];
            int r0=mrow+gid,r1=mrow+gid+8,c0=ncol+2*tig,c1=ncol+2*tig+1;
            bool al=((c0&1)==0);
            if(r0<M&&c1<N&&al) *reinterpret_cast<float2*>(&C[(long long)r0*N+c0])=make_float2(d[0],d[1]);
            else{ if(r0<M&&c0<N)C[(long long)r0*N+c0]=d[0]; if(r0<M&&c1<N)C[(long long)r0*N+c1]=d[1]; }
            if(r1<M&&c1<N&&al) *reinterpret_cast<float2*>(&C[(long long)r1*N+c0])=make_float2(d[2],d[3]);
            else{ if(r1<M&&c0<N)C[(long long)r1*N+c0]=d[2]; if(r1<M&&c1<N)C[(long long)r1*N+c1]=d[3]; }
        }
    }
}

static int g_maxsmem_set = 0;
static size_t l_smem_bytes(){
    return (size_t)DEEP*(L_BM*L_ASTRIDE + L_BK*L_BSTRIDE)*sizeof(float);
}

// host wrapper: SIZE DISPATCH (LEVER1). Big tile for problems whose grid still
// saturates the GPU's SMs; fall back to 64x64 for small ones.
extern "C" void owngemm_sm120(float* C, const float* A, const float* B, int M, int K, int N){
    // 128x128 grid cells:
    int g128 = ((N+L_BN-1)/L_BN) * ((M+L_BM-1)/L_BM);
    // RTX 5070 has ~48 SMs; need enough CTAs to fill. Use big tile when the 128
    // grid still yields >= ~SM count of blocks AND M,N are reasonably large.
    bool use_big = (M>=256 && N>=256 && g128 >= 24);
    if(use_big){
        size_t shb = l_smem_bytes();
        if(!g_maxsmem_set && shb > 48*1024){
            cudaFuncSetAttribute(gemm_sm120_128, cudaFuncAttributeMaxDynamicSharedMemorySize, (int)shb);
            g_maxsmem_set = 1;
        }
        dim3 blk(L_NTHREAD);
        dim3 grid((N+L_BN-1)/L_BN, (M+L_BM-1)/L_BM);
        gemm_sm120_128<<<grid,blk,shb>>>(A,B,C,M,N,K);
    } else {
        dim3 blk(S_NTHREAD);
        dim3 grid((N+S_BN-1)/S_BN, (M+S_BM-1)/S_BM);
        gemm_sm120_64<<<grid,blk>>>(A,B,C,M,N,K);
    }
}

#ifdef OWNGEMM_MAIN
static void fill(float* x, long long n, unsigned seed){
    for(long long i=0;i<n;i++){ unsigned h=(unsigned)(i*2654435761u)^seed; x[i]=((h&0xffff)/65535.f-0.5f)*0.2f; }
}
int main(int argc,char**argv){
    int S = argc>1?atoi(argv[1]):768;
    int MODE = argc>2?atoi(argv[2]):0;
    int M=S,N=S,K=S;
    size_t szA=(size_t)M*K, szB=(size_t)K*N, szC=(size_t)M*N;
    float *hA=(float*)malloc(szA*4),*hB=(float*)malloc(szB*4),*hC=(float*)malloc(szC*4),*hR=(float*)malloc(szC*4);
    fill(hA,szA,11); fill(hB,szB,22);
    float *dA,*dB,*dC,*dR;
    CK(cudaMalloc(&dA,szA*4)); CK(cudaMalloc(&dB,szB*4)); CK(cudaMalloc(&dC,szC*4)); CK(cudaMalloc(&dR,szC*4));
    CK(cudaMemcpy(dA,hA,szA*4,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB,hB,szB*4,cudaMemcpyHostToDevice));
    cublasHandle_t cb; CB(cublasCreate(&cb));
    CB(cublasSetMathMode(cb, CUBLAS_TF32_TENSOR_OP_MATH));
    const float alpha=1.f, beta=0.f;
    CB(cublasGemmEx(cb, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha,
        dB, CUDA_R_32F, N, dA, CUDA_R_32F, K, &beta,
        dR, CUDA_R_32F, N, CUBLAS_COMPUTE_32F_FAST_TF32, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
    CK(cudaDeviceSynchronize());
    owngemm_sm120(dC,dA,dB,M,K,N);
    cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){ printf("OWNGEMM FAULT S=%d: %s\n",S,cudaGetErrorString(e)); return 4; }
    CK(cudaMemcpy(hC,dC,szC*4,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hR,dR,szC*4,cudaMemcpyDeviceToHost));
    double se=0,sr=0,maxd=0;
    for(size_t i=0;i<szC;i++){ double a=hC[i],b=hR[i],dd=a-b; se+=dd*dd; sr+=b*b; if(fabs(dd)>maxd)maxd=fabs(dd); }
    double relrms = sr>0 ? sqrt(se/szC)/sqrt(sr/szC) : 0.0;
    printf("[GATE] cfg(DEEP=%d,SWZ=%d) S=%d own vs cuBLAS-TF32: rel-RMS=%.3e max|d|=%.3e (gate<=1e-2: %s)\n",
           DEEP,SWZ,S,relrms,maxd, relrms<=1e-2?"PASS":"FAIL");
    if(MODE==1){
        int iters=50;
        owngemm_sm120(dC,dA,dB,M,K,N); CK(cudaDeviceSynchronize());
        cudaEvent_t t0,t1; cudaEventCreate(&t0); cudaEventCreate(&t1);
        cudaEventRecord(t0);
        for(int it=0;it<iters;it++) owngemm_sm120(dC,dA,dB,M,K,N);
        cudaEventRecord(t1); CK(cudaEventSynchronize(t1));
        float ms=0; cudaEventElapsedTime(&ms,t0,t1); double ms1=ms/iters;
        double flops=2.0*(double)M*N*K, tflops=flops/(ms1*1e-3)/1e12;
        cudaEventRecord(t0);
        for(int it=0;it<iters;it++)
          cublasGemmEx(cb, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha,
            dB, CUDA_R_32F, N, dA, CUDA_R_32F, K, &beta,
            dR, CUDA_R_32F, N, CUBLAS_COMPUTE_32F_FAST_TF32, CUBLAS_GEMM_DEFAULT_TENSOR_OP);
        cudaEventRecord(t1); CK(cudaEventSynchronize(t1));
        cudaEventElapsedTime(&ms,t0,t1); double cbms=ms/iters, cbtf=flops/(cbms*1e-3)/1e12;
        printf("[PERF] cfg(DEEP=%d,SWZ=%d) S=%d own %.2f TFLOP/s (%.4f ms)  cuBLAS-TF32 %.2f TFLOP/s  off=%.3fx\n",
               DEEP,SWZ,S,tflops,ms1,cbtf, cbtf/tflops);
    }
    return relrms<=1e-2?0:2;
}
#endif
