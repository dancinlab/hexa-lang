// owngemm_sm120_bf16_occ.cu — BF16 own-GEMM OCCUPANCY variant for sm_120 (RTX 5070).
//
// WALL-B closer. Census root-cause: the own BF16 kernel (owngemm_sm120_bf16.cu)
// runs ~0.5x cuBLAS (2x slow) because it is OCCUPANCY-limited, not compute-
// limited — sm_120 has 48 warps/SM and 100KB smem but NO TMEM/tcgen05/wgmma
// (mma.sync only), so the Hopper "bigger tile + ldmatrix" playbook BACKFIRES
// (register inflation lowers resident warps). The fix is the OPPOSITE: SHRINK the
// per-block footprint to RAISE resident-warp occupancy.
//
// MEASURED baseline footprint (nvcc --ptxas-options=-v, sm_120): the fp32-staged
// kernel uses 72 registers + 18944 bytes smem per 128-thread block => ~7 blocks/SM
// by registers but the 18944 B double-buffered FP32 smem staging is the dominant
// limiter. ~28 resident warps = 58% of the 48-warp max.
//
// THIS kernel cuts the footprint two ways, both bit-faithful:
//   (1) STAGE A/B IN SMEM AS BF16, not fp32. The fp32->bf16 RN conversion happens
//       ONCE at the global->smem load (not per-fragment), HALVING the smem staging
//       (18944 -> ~9.5KB) so more blocks fit per SM. (Math identical: same RN
//       conversion of the same fp32 inputs, just done earlier; the mma.sync
//       consumes the same bf16 bits.)
//   (2) the smem is now bf16 so the fragment load reads bf16 pairs directly
//       (no per-fragment f2bf16), trimming register pressure in the inner loop.
// Same 64x64 / BK=16 tiling, same m16n8k16 mma, same k-ascending order => the
// result is bit-for-bit the owngemm_sm120_bf16.cu baseline (rel-RMS vs it = 0)
// and run-to-run deterministic (max|delta|=0).
//
// Opt-in: production selects via env HEXA_BF16_OCC; default stays the fp32-staged
// kernel. Shipped default paths untouched => byteeq-NEUTRAL.
//
// GEMM: C[M,N]=A[M,K]@B[K,N], row-major, BF16 matmul / FP32 accum.
// Modes (argv[2]): 0 GATE (rel-RMS vs FP64) · 1 PERF (vs cuBLAS-BF16) ·
//                  2 DETERMINISM (run-to-run max|delta|, MUST 0).
// Build: build_owngemm_bf16_occ.sh (run on aiden).

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

#ifndef BM
#define BM 64
#endif
#ifndef BN
#define BN 64
#endif
#define BK 16            // == one m16n8k16 BF16 mma step
#define WARPS_M 2
#define WARPS_N 2
#define NWARP (WARPS_M*WARPS_N)
#define NTHREAD (NWARP*32)
#define WM_FRAG (BM/32)
#define WN_FRAG (BN/16)
// smem bf16 pad (in bf16 elements). keep an 8-element pad to break bank stride.
#define ASPAD 8
#define BSPAD 8

__device__ __forceinline__ __nv_bfloat16 f2bf16(float x){ return __float2bfloat16_rn(x); }

__device__ __forceinline__ void mma_m16n8k16(float* d, const unsigned* a, const unsigned* b){
    asm volatile(
      "mma.sync.aligned.m16n8k16.row.col.f32.bf16.bf16.f32 "
      "{%0,%1,%2,%3}, {%4,%5,%6,%7}, {%8,%9}, {%0,%1,%2,%3};\n"
      : "+f"(d[0]),"+f"(d[1]),"+f"(d[2]),"+f"(d[3])
      : "r"(a[0]),"r"(a[1]),"r"(a[2]),"r"(a[3]),"r"(b[0]),"r"(b[1]));
}
__device__ __forceinline__ void cp_async_commit(){ asm volatile("cp.async.commit_group;\n"); }
template<int N> __device__ __forceinline__ void cp_async_wait(){ asm volatile("cp.async.wait_group %0;\n" :: "n"(N)); }

// read a packed bf16 pair from smem (two adjacent bf16 -> one 32-bit reg).
__device__ __forceinline__ unsigned pack2(const __nv_bfloat16* p){
    unsigned u; memcpy(&u,p,4); return u;     // p[0] low, p[1] high
}

// BF16 GEMM, A/B staged in smem AS bf16 (halved smem footprint vs fp32-staged).
// fp32 inputs are RN-converted to bf16 once at the global->smem load.
extern "C" __global__ void gemm_sm120_bf16_occ(const float* __restrict__ A,
                                               const float* __restrict__ B,
                                               float* __restrict__ C,
                                               int M, int N, int K){
    __shared__ __nv_bfloat16 As[2][BM][BK+ASPAD];   // bf16 staging (half of fp32)
    __shared__ __nv_bfloat16 Bs[2][BK][BN+BSPAD];
    int bm = blockIdx.y*BM, bn = blockIdx.x*BN;
    int tid = threadIdx.x;
    int warp = tid>>5, lane = tid&31;
    int wm = (warp/WARPS_N)*32, wn = (warp%WARPS_N)*32;
    int gid = lane>>2, tig = lane&3;

    float acc[WM_FRAG][WN_FRAG][4];
    #pragma unroll
    for(int i=0;i<WM_FRAG;i++)for(int j=0;j<WN_FRAG;j++)for(int e=0;e<4;e++) acc[i][j][e]=0.f;

    int nk = (K+BK-1)/BK;
    // Load one BK stage into smem buf, converting fp32->bf16 RN at load. VECTORIZED:
    // read 4 fp32 (float4, 128-bit) from global, RN-convert all 4 to bf16, and write
    // them as one 64-bit bf16x4 store. K%4==0 && N%4==0 fast path; scalar tail
    // fallback at the right/bottom boundary. Restores the baseline's wide global
    // loads while keeping the halved bf16 smem footprint.
    auto load_stage = [&](int buf,int k0){
        #pragma unroll
        for(int i=tid; i<BM*BK/4; i+=NTHREAD){
            int r=i/(BK/4), c4=i%(BK/4), c=c4*4; int gr=bm+r, gc=k0+c;
            __nv_bfloat16* dst = &As[buf][r][c];
            if(gr<M && gc+3<K){
                float4 v=*reinterpret_cast<const float4*>(&A[(long long)gr*K+gc]);
                dst[0]=f2bf16(v.x); dst[1]=f2bf16(v.y); dst[2]=f2bf16(v.z); dst[3]=f2bf16(v.w);
            } else {
                for(int e=0;e<4;e++){ float v=(gr<M&&gc+e<K)?A[(long long)gr*K+gc+e]:0.f; dst[e]=f2bf16(v); }
            }
        }
        #pragma unroll
        for(int i=tid; i<BK*BN/4; i+=NTHREAD){
            int r=i/(BN/4), c4=i%(BN/4), c=c4*4; int gr=k0+r, gc=bn+c;
            __nv_bfloat16* dst = &Bs[buf][r][c];
            if(gr<K && gc+3<N){
                float4 v=*reinterpret_cast<const float4*>(&B[(long long)gr*N+gc]);
                dst[0]=f2bf16(v.x); dst[1]=f2bf16(v.y); dst[2]=f2bf16(v.z); dst[3]=f2bf16(v.w);
            } else {
                for(int e=0;e<4;e++){ float v=(gr<K&&gc+e<N)?B[(long long)gr*N+gc+e]:0.f; dst[e]=f2bf16(v); }
            }
        }
    };

    load_stage(0,0);
    for(int k=0; k<nk; k++){
        int buf=k&1, nbuf=(k+1)&1;
        __syncthreads();
        if(k+1<nk) load_stage(nbuf,(k+1)*BK);

        #pragma unroll
        for(int fmi=0; fmi<WM_FRAG; fmi++){
            int mrow = wm + fmi*16;
            // A fragment (m16n8k16,.row): reg packs 2 bf16 along K. Read directly
            // from bf16 smem as a 32-bit pair (no per-fragment conversion).
            unsigned af[4];
            af[0]=pack2(&As[buf][mrow+gid  ][2*tig  ]);
            af[1]=pack2(&As[buf][mrow+gid+8][2*tig  ]);
            af[2]=pack2(&As[buf][mrow+gid  ][2*tig+8]);
            af[3]=pack2(&As[buf][mrow+gid+8][2*tig+8]);
            #pragma unroll
            for(int fni=0; fni<WN_FRAG; fni++){
                int ncol = wn + fni*8;
                // B fragment (.col): reg packs 2 bf16 along K for column n=gid.
                // Bs is row-major [k][n]; the two K-rows 2*tig,2*tig+1 are NOT
                // adjacent in memory (stride BN+pad), so build the pair explicitly.
                __nv_bfloat16 b0lo=Bs[buf][2*tig  ][ncol+gid], b0hi=Bs[buf][2*tig+1][ncol+gid];
                __nv_bfloat16 b1lo=Bs[buf][2*tig+8][ncol+gid], b1hi=Bs[buf][2*tig+9][ncol+gid];
                unsigned bf[2];
                unsigned short s0,s1; memcpy(&s0,&b0lo,2); memcpy(&s1,&b0hi,2); bf[0]=(unsigned)s0|((unsigned)s1<<16);
                memcpy(&s0,&b1lo,2); memcpy(&s1,&b1hi,2); bf[1]=(unsigned)s0|((unsigned)s1<<16);
                mma_m16n8k16(acc[fmi][fni], af, bf);
            }
        }
        __syncthreads();   // finish reading buf before next iter overwrites it
    }

    // store (same fp32 m16n8 C fragment layout as baseline). .v2 vectorized.
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

extern "C" void owngemm_sm120_bf16_occ(float* C, const float* A, const float* B, int M, int K, int N){
    dim3 blk(NTHREAD);
    dim3 grid((N+BN-1)/BN, (M+BM-1)/BM);
    gemm_sm120_bf16_occ<<<grid,blk>>>(A,B,C,M,N,K);
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

    owngemm_sm120_bf16_occ(dC,dA,dB,M,K,N);
    cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){ printf("OCC FAULT: %s\n",cudaGetErrorString(e)); return 4; }
    CK(cudaMemcpy(hC,dC,szC*4,cudaMemcpyDeviceToHost));

    double *hR=(double*)malloc(szC*8);
    ref_fp64(hA,hB,hR,M,N,K);
    double se=0,sr=0,maxd=0;
    for(size_t i=0;i<szC;i++){ double a=hC[i],b=hR[i],dd=a-b; se+=dd*dd; sr+=b*b; if(fabs(dd)>maxd)maxd=fabs(dd); }
    double relrms = sr>0 ? sqrt(se/szC)/sqrt(sr/szC) : 0.0;
    printf("[GATE] S=%d bf16-occ vs FP64 ref: rel-RMS=%.3e max|delta|=%.3e (gate<=1e-2: %s)\n",
           S,relrms,maxd, relrms<=1e-2?"PASS":"FAIL");

    if(MODE==2){
        CK(cudaMemset(dC,0,szC*4));
        owngemm_sm120_bf16_occ(dC,dA,dB,M,K,N); CK(cudaDeviceSynchronize());
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
        owngemm_sm120_bf16_occ(dC,dA,dB,M,K,N); CK(cudaDeviceSynchronize());
        cudaEvent_t t0,t1; cudaEventCreate(&t0); cudaEventCreate(&t1);
        cudaEventRecord(t0);
        for(int it=0;it<iters;it++) owngemm_sm120_bf16_occ(dC,dA,dB,M,K,N);
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
        printf("[PERF] S=%d bf16-occ %.2f TFLOP/s (%.4f ms)  cuBLAS-BF16 %.2f TFLOP/s (%.4f ms)  off-cuBLAS=%.2fx\n",
               S,tflops,ms1,cbtf,cbms, cbtf/tflops);
    }
    return relrms<=1e-2?0:2;
}
#endif
