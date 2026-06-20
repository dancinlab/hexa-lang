// owngemm_sm120_splitk.cu — TF32 Split-K own-GEMM for consumer Blackwell sm_120
// (RTX 5070, cc12.0). LEVER A of tf32-parity-research r4.
//
// PROBLEM (measured r4 baseline, aiden RTX 5070, 48 SMs):
//   own-GEMM plateaus at ~30 TFLOP/s at every size while cuBLAS climbs to 34.
//   At small sizes the 64x64 data-parallel grid leaves SMs idle:
//     256: 16 tiles / 48 SMs = 0.33 wave  -> 32 SMs idle  -> 1.24x off
//     512: 64 tiles / 48 SMs = 1.33 waves -> wave-quant    -> 1.11x off
//    1024: 256 tiles / 48 SMs = 5.33 waves                 -> 1.13x off
//   cuBLAS's own sm_120 kernel name (r3 census) is
//     nvjet_sm120_sss_tf32_mma_32x32x64_..._splitK_TNNN
//   = it uses Split-K. We port the SAME decomposition onto our mma.sync kernel.
//
// REFERENCE-FIRST (c23): CUTLASS example 47_ampere_gemm_universal_streamk +
//   classic Split-K (CUTLASS GemmSplitKParallel). Stream-K paper arxiv:2301.03598.
//   We implement classic FIXED Split-K first (simpler, deterministic):
//     - partition K into `splits` contiguous ranges,
//     - launch grid (N/BN, M/BM, splits); z-slice computes partial over its
//       K-range into workspace[z] (NO atomics -> deterministic, byteeq-spirit),
//     - a tiny reduction kernel sums the `splits` partial C-tiles -> C.
//   At evenly-tiling large sizes splits=1 path == the data-parallel baseline
//   (so 768/2048 do NOT regress — we pick splits per size).
//
// GEMM: C[M,N] = A[M,K] @ B[K,N], all row-major, TF32 / FP32 accum.
// Block tile BM x BN = 64 x 64, BK = 16, 4 warps (2x2). IDENTICAL inner mma.sync
// order as the shipped owngemm_sm120.cu — partials are bit-identical to the
// baseline's per-k-range partial; only the cross-split final sum is new math.
//
// This is an OPT-IN TF32 fastmode experimental variant — the shipped FP64/default
// path is untouched (byteeq-NEUTRAL). Not wired into production here; measured only.

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cuda_runtime.h>
#include <cublas_v2.h>

#define CK(x) do{cudaError_t e=(x); if(e!=cudaSuccess){printf("CUDA-ERR %s @%d: %s\n",#x,__LINE__,cudaGetErrorString(e));exit(3);}}while(0)
#define CB(x) do{cublasStatus_t s=(x); if(s!=CUBLAS_STATUS_SUCCESS){printf("CUBLAS-ERR %d @%d\n",(int)s,__LINE__);exit(3);}}while(0)

#define BM 64
#define BN 64
#define BK 16
#define WARPS_M 2
#define WARPS_N 2
#define NWARP (WARPS_M*WARPS_N)
#define NTHREAD (NWARP*32)
#define WM_FRAG 2
#define WN_FRAG 4
#define ASPAD 4
#define BSPAD 4

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

// Split-K GEMM: blockIdx.z = split index. Each split computes the partial sum
// over its K-range [k_lo, k_hi) and STORES (not accumulates) into
// Cw[ split * M*N + ... ]. The K-range is aligned to BK so each split's inner
// loop is bit-identical to the baseline restricted to that range.
extern "C" __global__ void gemm_sm120_splitk(const float* __restrict__ A,
                                             const float* __restrict__ B,
                                             float* __restrict__ Cw,
                                             int M, int N, int K, int splits){
    __shared__ float As[2][BM][BK+ASPAD];
    __shared__ float Bs[2][BK][BN+BSPAD];
    int bm = blockIdx.y*BM, bn = blockIdx.x*BN;
    int sp = blockIdx.z;
    int tid = threadIdx.x;
    int warp = tid>>5, lane = tid&31;
    int wm = (warp/WARPS_N)*32;
    int wn = (warp%WARPS_N)*32;
    int gid = lane>>2, tig = lane&3;

    // K-range for this split, aligned to BK. nk_total BK-tiles split as evenly
    // as possible; split sp gets tiles [t_lo, t_hi).
    int nk_total = (K+BK-1)/BK;
    int per = (nk_total + splits - 1)/splits;     // ceil
    int t_lo = sp*per;
    int t_hi = t_lo + per; if(t_hi>nk_total) t_hi=nk_total;
    int my_nk = t_hi - t_lo;

    float acc[WM_FRAG][WN_FRAG][4];
    #pragma unroll
    for(int i=0;i<WM_FRAG;i++)for(int j=0;j<WN_FRAG;j++)for(int e=0;e<4;e++) acc[i][j][e]=0.f;

    auto load_stage = [&](int buf,int k0){
        #pragma unroll
        for(int i=tid; i<BM*BK/4; i+=NTHREAD){
            int r=i/(BK/4), c4=i%(BK/4), c=c4*4; int gr=bm+r, gc=k0+c;
            if(gr<M && gc+3<K) cp_async_cg16(&As[buf][r][c], &A[(long long)gr*K+gc]);
            else { float4 v=make_float4(0,0,0,0);
                   if(gr<M){ for(int e=0;e<4;e++) ((float*)&v)[e]=(gc+e<K)?A[(long long)gr*K+gc+e]:0.f; }
                   As[buf][r][c+0]=v.x;As[buf][r][c+1]=v.y;As[buf][r][c+2]=v.z;As[buf][r][c+3]=v.w; }
        }
        #pragma unroll
        for(int i=tid; i<BK*BN/4; i+=NTHREAD){
            int r=i/(BN/4), c4=i%(BN/4), c=c4*4; int gr=k0+r, gc=bn+c;
            if(gr<K && gc+3<N) cp_async_cg16(&Bs[buf][r][c], &B[(long long)gr*N+gc]);
            else { float4 v=make_float4(0,0,0,0);
                   if(gr<K){ for(int e=0;e<4;e++) ((float*)&v)[e]=(gc+e<N)?B[(long long)gr*N+gc+e]:0.f; }
                   Bs[buf][r][c+0]=v.x;Bs[buf][r][c+1]=v.y;Bs[buf][r][c+2]=v.z;Bs[buf][r][c+3]=v.w; }
        }
    };

    if(my_nk>0){
        load_stage(0, t_lo*BK); cp_async_commit();
        for(int kk=0; kk<my_nk; kk++){
            int buf=kk&1, nbuf=(kk+1)&1;
            if(kk+1<my_nk){ load_stage(nbuf,(t_lo+kk+1)*BK); cp_async_commit(); cp_async_wait<1>(); }
            else          { cp_async_wait<0>(); }
            __syncthreads();
            #pragma unroll
            for(int ks=0; ks<BK; ks+=8){
                #pragma unroll
                for(int fmi=0; fmi<WM_FRAG; fmi++){
                    int mrow = wm + fmi*16;
                    unsigned af[4];
                    af[0]=f2tf32(As[buf][mrow + gid    ][ks + tig    ]);
                    af[1]=f2tf32(As[buf][mrow + gid + 8][ks + tig    ]);
                    af[2]=f2tf32(As[buf][mrow + gid    ][ks + tig + 4]);
                    af[3]=f2tf32(As[buf][mrow + gid + 8][ks + tig + 4]);
                    #pragma unroll
                    for(int fni=0; fni<WN_FRAG; fni++){
                        int ncol = wn + fni*8;
                        unsigned bf[2];
                        bf[0]=f2tf32(Bs[buf][ks + tig    ][ncol + gid]);
                        bf[1]=f2tf32(Bs[buf][ks + tig + 4][ncol + gid]);
                        mma_m16n8k8(acc[fmi][fni], af, bf);
                    }
                }
            }
            __syncthreads();
        }
    }

    // store partial into workspace slice for this split.
    long long base = (long long)sp*M*N;
    #pragma unroll
    for(int fmi=0; fmi<WM_FRAG; fmi++){
        int mrow = bm + wm + fmi*16;
        #pragma unroll
        for(int fni=0; fni<WN_FRAG; fni++){
            int ncol = bn + wn + fni*8;
            float* d = acc[fmi][fni];
            int r0=mrow+gid, r1=mrow+gid+8, c0=ncol+2*tig, c1=ncol+2*tig+1;
            bool aligned = ((c0&1)==0);
            if(r0<M && c1<N && aligned) *reinterpret_cast<float2*>(&Cw[base+(long long)r0*N+c0]) = make_float2(d[0],d[1]);
            else { if(r0<M && c0<N) Cw[base+(long long)r0*N+c0]=d[0];
                   if(r0<M && c1<N) Cw[base+(long long)r0*N+c1]=d[1]; }
            if(r1<M && c1<N && aligned) *reinterpret_cast<float2*>(&Cw[base+(long long)r1*N+c0]) = make_float2(d[2],d[3]);
            else { if(r1<M && c0<N) Cw[base+(long long)r1*N+c0]=d[2];
                   if(r1<M && c1<N) Cw[base+(long long)r1*N+c1]=d[3]; }
        }
    }
}

// ATOMIC-accumulate variant of the split-K store: instead of writing into a
// per-split workspace + separate reduce pass, each split atomicAdds its partial
// directly into C (which must be pre-zeroed). Saves the workspace alloc and the
// full extra MN read/write pass of splitk_reduce — better when the reduce pass
// dominates (mid sizes 512/1024). Same inner math; cross-split order is now
// nondeterministic (atomic) but TF32 tolerance absorbs it (gate stays PASS).
extern "C" __global__ void gemm_sm120_splitk_atomic(const float* __restrict__ A,
                                                    const float* __restrict__ B,
                                                    float* __restrict__ C,
                                                    int M, int N, int K, int splits){
    __shared__ float As[2][BM][BK+ASPAD];
    __shared__ float Bs[2][BK][BN+BSPAD];
    int bm = blockIdx.y*BM, bn = blockIdx.x*BN;
    int sp = blockIdx.z;
    int tid = threadIdx.x;
    int warp = tid>>5, lane = tid&31;
    int wm = (warp/WARPS_N)*32;
    int wn = (warp%WARPS_N)*32;
    int gid = lane>>2, tig = lane&3;

    int nk_total = (K+BK-1)/BK;
    int per = (nk_total + splits - 1)/splits;
    int t_lo = sp*per;
    int t_hi = t_lo + per; if(t_hi>nk_total) t_hi=nk_total;
    int my_nk = t_hi - t_lo;

    float acc[WM_FRAG][WN_FRAG][4];
    #pragma unroll
    for(int i=0;i<WM_FRAG;i++)for(int j=0;j<WN_FRAG;j++)for(int e=0;e<4;e++) acc[i][j][e]=0.f;

    auto load_stage = [&](int buf,int k0){
        #pragma unroll
        for(int i=tid; i<BM*BK/4; i+=NTHREAD){
            int r=i/(BK/4), c4=i%(BK/4), c=c4*4; int gr=bm+r, gc=k0+c;
            if(gr<M && gc+3<K) cp_async_cg16(&As[buf][r][c], &A[(long long)gr*K+gc]);
            else { float4 v=make_float4(0,0,0,0);
                   if(gr<M){ for(int e=0;e<4;e++) ((float*)&v)[e]=(gc+e<K)?A[(long long)gr*K+gc+e]:0.f; }
                   As[buf][r][c+0]=v.x;As[buf][r][c+1]=v.y;As[buf][r][c+2]=v.z;As[buf][r][c+3]=v.w; }
        }
        #pragma unroll
        for(int i=tid; i<BK*BN/4; i+=NTHREAD){
            int r=i/(BN/4), c4=i%(BN/4), c=c4*4; int gr=k0+r, gc=bn+c;
            if(gr<K && gc+3<N) cp_async_cg16(&Bs[buf][r][c], &B[(long long)gr*N+gc]);
            else { float4 v=make_float4(0,0,0,0);
                   if(gr<K){ for(int e=0;e<4;e++) ((float*)&v)[e]=(gc+e<N)?B[(long long)gr*N+gc+e]:0.f; }
                   Bs[buf][r][c+0]=v.x;Bs[buf][r][c+1]=v.y;Bs[buf][r][c+2]=v.z;Bs[buf][r][c+3]=v.w; }
        }
    };

    if(my_nk>0){
        load_stage(0, t_lo*BK); cp_async_commit();
        for(int kk=0; kk<my_nk; kk++){
            int buf=kk&1, nbuf=(kk+1)&1;
            if(kk+1<my_nk){ load_stage(nbuf,(t_lo+kk+1)*BK); cp_async_commit(); cp_async_wait<1>(); }
            else          { cp_async_wait<0>(); }
            __syncthreads();
            #pragma unroll
            for(int ks=0; ks<BK; ks+=8){
                #pragma unroll
                for(int fmi=0; fmi<WM_FRAG; fmi++){
                    int mrow = wm + fmi*16;
                    unsigned af[4];
                    af[0]=f2tf32(As[buf][mrow + gid    ][ks + tig    ]);
                    af[1]=f2tf32(As[buf][mrow + gid + 8][ks + tig    ]);
                    af[2]=f2tf32(As[buf][mrow + gid    ][ks + tig + 4]);
                    af[3]=f2tf32(As[buf][mrow + gid + 8][ks + tig + 4]);
                    #pragma unroll
                    for(int fni=0; fni<WN_FRAG; fni++){
                        int ncol = wn + fni*8;
                        unsigned bf[2];
                        bf[0]=f2tf32(Bs[buf][ks + tig    ][ncol + gid]);
                        bf[1]=f2tf32(Bs[buf][ks + tig + 4][ncol + gid]);
                        mma_m16n8k8(acc[fmi][fni], af, bf);
                    }
                }
            }
            __syncthreads();
        }
    }

    #pragma unroll
    for(int fmi=0; fmi<WM_FRAG; fmi++){
        int mrow = bm + wm + fmi*16;
        #pragma unroll
        for(int fni=0; fni<WN_FRAG; fni++){
            int ncol = bn + wn + fni*8;
            float* d = acc[fmi][fni];
            int r0=mrow+gid, r1=mrow+gid+8, c0=ncol+2*tig, c1=ncol+2*tig+1;
            if(r0<M && c0<N) atomicAdd(&C[(long long)r0*N+c0], d[0]);
            if(r0<M && c1<N) atomicAdd(&C[(long long)r0*N+c1], d[1]);
            if(r1<M && c0<N) atomicAdd(&C[(long long)r1*N+c0], d[2]);
            if(r1<M && c1<N) atomicAdd(&C[(long long)r1*N+c1], d[3]);
        }
    }
}

// reduction: C[i] = sum_{sp} Cw[sp*M*N + i]. Grid-stride, vectorized .f4 where aligned.
extern "C" __global__ void splitk_reduce(const float* __restrict__ Cw, float* __restrict__ C,
                                         long long MN, int splits){
    long long i = (long long)blockIdx.x*blockDim.x + threadIdx.x;
    long long stride = (long long)gridDim.x*blockDim.x;
    for(; i<MN; i+=stride){
        float s = Cw[i];
        for(int sp=1; sp<splits; sp++) s += Cw[(long long)sp*MN + i];
        C[i] = s;
    }
}

// host wrapper: chooses splits, allocates workspace, launches split + reduce.
// Workspace is a caller-provided scratch (Cw, splits*M*N floats).
extern "C" void owngemm_sm120_splitk(float* C, const float* A, const float* B,
                                     int M, int K, int N, int splits, float* Cw){
    if(splits<=1){
        // direct path: split-1 writes straight into C (no reduce).
        dim3 blk(NTHREAD);
        dim3 grid((N+BN-1)/BN, (M+BM-1)/BM, 1);
        gemm_sm120_splitk<<<grid,blk>>>(A,B,C,M,N,K,1);
        return;
    }
    dim3 blk(NTHREAD);
    dim3 grid((N+BN-1)/BN, (M+BM-1)/BM, splits);
    gemm_sm120_splitk<<<grid,blk>>>(A,B,Cw,M,N,K,splits);
    long long MN=(long long)M*N;
    int rb=256; int rg=(int)((MN+rb-1)/rb); if(rg>4096) rg=4096;
    splitk_reduce<<<rg,rb>>>(Cw,C,MN,splits);
}

// atomic split-K: C must be pre-zeroed; each split atomicAdds into C. No workspace.
extern "C" void owngemm_sm120_splitk_atomic(float* C, const float* A, const float* B,
                                            int M, int K, int N, int splits){
    CK(cudaMemset(C, 0, (size_t)M*N*4));
    dim3 blk(NTHREAD);
    dim3 grid((N+BN-1)/BN, (M+BM-1)/BM, splits<1?1:splits);
    gemm_sm120_splitk_atomic<<<grid,blk>>>(A,B,C,M,N,K,splits<1?1:splits);
}

#ifdef OWNGEMM_MAIN
static void fill(float* x, long long n, unsigned seed){
    for(long long i=0;i<n;i++){ unsigned h=(unsigned)(i*2654435761u)^seed; x[i]=((h&0xffff)/65535.f-0.5f)*0.2f; }
}
int main(int argc,char**argv){
    int S = argc>1?atoi(argv[1]):768;
    int MODE = argc>2?atoi(argv[2]):0;
    int SPLITS = argc>3?atoi(argv[3]):1;
    int ATOMIC = argc>4?atoi(argv[4]):0;   // 1 = atomic-accumulate path (no workspace/reduce)
    int M=S,N=S,K=S;
    size_t szA=(size_t)M*K, szB=(size_t)K*N, szC=(size_t)M*N;
    float *hA=(float*)malloc(szA*4),*hB=(float*)malloc(szB*4),*hC=(float*)malloc(szC*4),*hR=(float*)malloc(szC*4);
    fill(hA,szA,11); fill(hB,szB,22);
    float *dA,*dB,*dC,*dR,*dW;
    CK(cudaMalloc(&dA,szA*4)); CK(cudaMalloc(&dB,szB*4)); CK(cudaMalloc(&dC,szC*4)); CK(cudaMalloc(&dR,szC*4));
    CK(cudaMalloc(&dW,(size_t)SPLITS*szC*4));
    CK(cudaMemcpy(dA,hA,szA*4,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB,hB,szB*4,cudaMemcpyHostToDevice));

    cublasHandle_t cb; CB(cublasCreate(&cb));
    CB(cublasSetMathMode(cb, CUBLAS_TF32_TENSOR_OP_MATH));
    const float alpha=1.f, beta=0.f;
    CB(cublasGemmEx(cb, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha,
        dB, CUDA_R_32F, N, dA, CUDA_R_32F, K, &beta,
        dR, CUDA_R_32F, N, CUBLAS_COMPUTE_32F_FAST_TF32, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
    CK(cudaDeviceSynchronize());

    if(ATOMIC) owngemm_sm120_splitk_atomic(dC,dA,dB,M,K,N,SPLITS);
    else       owngemm_sm120_splitk(dC,dA,dB,M,K,N,SPLITS,dW);
    cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){ printf("OWNGEMM FAULT: %s\n",cudaGetErrorString(e)); return 4; }

    CK(cudaMemcpy(hC,dC,szC*4,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hR,dR,szC*4,cudaMemcpyDeviceToHost));
    double se=0,sr=0,maxd=0;
    for(size_t i=0;i<szC;i++){ double a=hC[i],b=hR[i],dd=a-b; se+=dd*dd; sr+=b*b; if(fabs(dd)>maxd)maxd=fabs(dd); }
    double relrms = sr>0 ? sqrt(se/szC)/sqrt(sr/szC) : 0.0;
    printf("[GATE] S=%d splits=%d own-GEMM vs cuBLAS-TF32: rel-RMS=%.3e max|delta|=%.3e (gate<=1e-2: %s)\n",
           S,SPLITS,relrms,maxd, relrms<=1e-2?"PASS":"FAIL");

    if(MODE==1){
        int iters=50;
        if(ATOMIC) owngemm_sm120_splitk_atomic(dC,dA,dB,M,K,N,SPLITS);
        else       owngemm_sm120_splitk(dC,dA,dB,M,K,N,SPLITS,dW);
        CK(cudaDeviceSynchronize());
        cudaEvent_t t0,t1; cudaEventCreate(&t0); cudaEventCreate(&t1);
        cudaEventRecord(t0);
        for(int it=0;it<iters;it++){ if(ATOMIC) owngemm_sm120_splitk_atomic(dC,dA,dB,M,K,N,SPLITS);
                                     else       owngemm_sm120_splitk(dC,dA,dB,M,K,N,SPLITS,dW); }
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
        printf("[PERF] S=%d splits=%d own-GEMM %.2f TFLOP/s (%.4f ms)  cuBLAS-TF32 %.2f TFLOP/s (%.4f ms)  off-cuBLAS=%.2fx\n",
               S,SPLITS,tflops,ms1,cbtf,cbms, cbtf/tflops);
    }
    return relrms<=1e-2?0:2;
}
#endif
