// owngemm_sm120_tma.cu — TF32 own-GEMM with TMA (cp.async.bulk.tensor) loads
// for consumer Blackwell sm_120 (RTX 5070). LEVER B of tf32-parity-research r4.
//
// cuBLAS's sm_120 TF32 kernel (r3 census name nvjet_sm120_..._tmaAB_...) uses TMA
// for the A/B loads. r4 baseline own-GEMM uses cp.async (cp.async.cg.shared.global)
// and plateaus ~30 TFLOP/s vs cuBLAS 34 at the large memory-bound sizes
// (2048..4096 = 1.10..1.25x off). TMA = single-instruction 2D async bulk copy with
// hardware address generation + mbarrier completion, freeing the address-math
// registers cp.async needs (WingEdge sm_120 HGEMM reached cuBLAS parity this way).
//
// REFERENCE-FIRST (c23): WingEdge sm_120 HGEMM TMA+ldmatrix+mma.sync writeup
//   (wingedge777.com/en/article/b2ab376d19f52ff4) + CUDA PTX cp.async.bulk.tensor
//   + cuTensorMapEncodeTiled host API (CUDA driver). We keep the IDENTICAL 64x64 /
//   BK=16 / 4-warp mma.sync inner loop; only the gmem->smem path changes to TMA.
//
// PROBE-CONFIRMED: cp.async.bulk.tensor.2d assembles for -arch=sm_120 (CUDA 13.0).
//
// Opt-in experimental TF32 fastmode variant — shipped FP64/default path untouched
// (byteeq-NEUTRAL). Measured only; not wired into production here.

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cuda.h>
#include <cuda_runtime.h>
#include <cublas_v2.h>

#define CK(x) do{cudaError_t e=(x); if(e!=cudaSuccess){printf("CUDA-ERR %s @%d: %s\n",#x,__LINE__,cudaGetErrorString(e));exit(3);}}while(0)
#define CB(x) do{cublasStatus_t s=(x); if(s!=CUBLAS_STATUS_SUCCESS){printf("CUBLAS-ERR %d @%d\n",(int)s,__LINE__);exit(3);}}while(0)
#define CD(x) do{CUresult r=(x); if(r!=CUDA_SUCCESS){const char*m;cuGetErrorString(r,&m);printf("CU-ERR %s @%d: %s\n",#x,__LINE__,m);exit(3);}}while(0)

#define BM 64
#define BN 64
#ifndef BK
#define BK 16
#endif
#define WARPS_M 2
#define WARPS_N 2
#define NWARP (WARPS_M*WARPS_N)
#define NTHREAD (NWARP*32)
#define WM_FRAG 2
#define WN_FRAG 4

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

// --- TMA / mbarrier device helpers ---
__device__ __forceinline__ void mbar_init(uint64_t* bar, int count){
    unsigned b=(unsigned)__cvta_generic_to_shared(bar);
    asm volatile("mbarrier.init.shared.b64 [%0], %1;\n" :: "r"(b), "r"(count));
}
__device__ __forceinline__ void mbar_expect(uint64_t* bar, int bytes){
    unsigned b=(unsigned)__cvta_generic_to_shared(bar);
    asm volatile("mbarrier.arrive.expect_tx.shared.b64 _, [%0], %1;\n" :: "r"(b), "r"(bytes));
}
// TMA 2D load: smem[BM/BK tile] <- gmem tile at tensor-coords (x,y).
__device__ __forceinline__ void tma_load_2d(void* smem, const CUtensorMap* tm,
                                            int x, int y, uint64_t* bar){
    unsigned s=(unsigned)__cvta_generic_to_shared(smem);
    unsigned b=(unsigned)__cvta_generic_to_shared(bar);
    asm volatile(
      "cp.async.bulk.tensor.2d.shared::cluster.global.mbarrier::complete_tx::bytes"
      " [%0], [%1, {%2, %3}], [%4];\n"
      :: "r"(s), "l"(tm), "r"(x), "r"(y), "r"(b) : "memory");
}
__device__ __forceinline__ void mbar_wait(uint64_t* bar, int phase){
    unsigned b=(unsigned)__cvta_generic_to_shared(bar);
    asm volatile(
      "{\n .reg .pred p;\n"
      "WAIT: mbarrier.try_wait.parity.shared.b64 p, [%0], %1;\n"
      "@p bra DONE;\n bra WAIT;\n DONE:\n }\n"
      :: "r"(b), "r"(phase));
}

// TMA tile sizes (bytes): A tile BM x BK floats, B tile BK x BN floats.
#define A_TILE_BYTES (BM*BK*4)
#define B_TILE_BYTES (BK*BN*4)

// TMA GEMM: tensor maps tmA (M x K), tmB (K x N) passed grid_constant. smem tiles
// hold the raw float values (no swizzle — interleave=NONE) and the mma.sync reads
// them in the same fragment layout as the cp.async baseline (so bit-identical
// inner accumulation). Double-buffered with two mbarriers (ping/pong phases).
extern "C" __global__ void gemm_sm120_tma(const __grid_constant__ CUtensorMap tmA,
                                          const __grid_constant__ CUtensorMap tmB,
                                          float* __restrict__ C,
                                          int M, int N, int K){
    // smem: 2-stage A and B tiles, 128B-aligned for TMA, + 2 barriers.
    __shared__ alignas(128) float As[2][BM][BK];
    __shared__ alignas(128) float Bs[2][BK][BN];
    __shared__ alignas(8) uint64_t barA[2];
    __shared__ alignas(8) uint64_t barB[2];

    int bm = blockIdx.y*BM, bn = blockIdx.x*BN;
    int tid = threadIdx.x;
    int warp = tid>>5, lane = tid&31;
    int wm = (warp/WARPS_N)*32;
    int wn = (warp%WARPS_N)*32;
    int gid = lane>>2, tig = lane&3;

    int nk = (K+BK-1)/BK;

    float acc[WM_FRAG][WN_FRAG][4];
    #pragma unroll
    for(int i=0;i<WM_FRAG;i++)for(int j=0;j<WN_FRAG;j++)for(int e=0;e<4;e++) acc[i][j][e]=0.f;

    if(tid==0){
        mbar_init(&barA[0],1); mbar_init(&barA[1],1);
        mbar_init(&barB[0],1); mbar_init(&barB[1],1);
    }
    __syncthreads();

    // issue stage-0 TMA loads. tensor coords: A at (k, m), B at (n, k) — TMA
    // box coords are (inner-contig-dim-index, outer-dim-index) in elements.
    auto issue = [&](int buf,int k0){
        if(tid==0){
            mbar_expect(&barA[buf], A_TILE_BYTES);
            tma_load_2d(&As[buf][0][0], &tmA, k0, bm, &barA[buf]);
            mbar_expect(&barB[buf], B_TILE_BYTES);
            tma_load_2d(&Bs[buf][0][0], &tmB, bn, k0, &barB[buf]);
        }
    };

    int phaseA[2]={0,0}, phaseB[2]={0,0};
    issue(0,0);
    for(int k=0;k<nk;k++){
        int buf=k&1, nbuf=(k+1)&1;
        if(k+1<nk) issue(nbuf,(k+1)*BK);
        // wait for this stage's A and B.
        mbar_wait(&barA[buf], phaseA[buf]); phaseA[buf]^=1;
        mbar_wait(&barB[buf], phaseB[buf]); phaseB[buf]^=1;
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

    // C store epilogue (same .v2 layout as the cp.async baseline).
    #pragma unroll
    for(int fmi=0; fmi<WM_FRAG; fmi++){
        int mrow = bm + wm + fmi*16;
        #pragma unroll
        for(int fni=0; fni<WN_FRAG; fni++){
            int ncol = bn + wn + fni*8;
            float* d = acc[fmi][fni];
            int r0=mrow+gid, r1=mrow+gid+8, c0=ncol+2*tig, c1=ncol+2*tig+1;
            bool aligned = ((c0&1)==0);
            if(r0<M && c1<N && aligned) *reinterpret_cast<float2*>(&C[(long long)r0*N+c0]) = make_float2(d[0],d[1]);
            else { if(r0<M && c0<N) C[(long long)r0*N+c0]=d[0];
                   if(r0<M && c1<N) C[(long long)r0*N+c1]=d[1]; }
            if(r1<M && c1<N && aligned) *reinterpret_cast<float2*>(&C[(long long)r1*N+c0]) = make_float2(d[2],d[3]);
            else { if(r1<M && c0<N) C[(long long)r1*N+c0]=d[2];
                   if(r1<M && c1<N) C[(long long)r1*N+c1]=d[3]; }
        }
    }
}

// build a 2D row-major tensor map. `gmem` points to a (rows x cols) row-major
// float matrix; box = (boxCols inner-contiguous, boxRows outer). globalDim is
// given inner-first: {cols, rows}. globalStride[0] = row stride in BYTES.
static CUtensorMap make_tensor_map(const float* gmem, int rows, int cols,
                                   int boxRows, int boxCols){
    CUtensorMap tm{};
    uint64_t gdim[2]   = { (uint64_t)cols, (uint64_t)rows };
    uint64_t gstride[1]= { (uint64_t)cols*4 };               // bytes per row
    uint32_t bdim[2]   = { (uint32_t)boxCols, (uint32_t)boxRows };
    uint32_t bstride[2]= { 1u, 1u };
    CD(cuTensorMapEncodeTiled(&tm, CU_TENSOR_MAP_DATA_TYPE_FLOAT32, 2,
        (void*)gmem, gdim, gstride, bdim, bstride,
        CU_TENSOR_MAP_INTERLEAVE_NONE, CU_TENSOR_MAP_SWIZZLE_NONE,
        CU_TENSOR_MAP_L2_PROMOTION_NONE, CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE));
    return tm;
}

extern "C" void owngemm_sm120_tma(float* C, const float* A, const float* B,
                                  int M, int K, int N){
    CUtensorMap tmA = make_tensor_map(A, M, K, BM, BK);   // A is MxK, box BMxBK
    CUtensorMap tmB = make_tensor_map(B, K, N, BK, BN);   // B is KxN, box BKxBN
    dim3 blk(NTHREAD);
    dim3 grid((N+BN-1)/BN, (M+BM-1)/BM, 1);
    gemm_sm120_tma<<<grid,blk>>>(tmA, tmB, C, M, N, K);
}

#ifdef OWNGEMM_MAIN
static void fill(float* x, long long n, unsigned seed){
    for(long long i=0;i<n;i++){ unsigned h=(unsigned)(i*2654435761u)^seed; x[i]=((h&0xffff)/65535.f-0.5f)*0.2f; }
}
int main(int argc,char**argv){
    int S = argc>1?atoi(argv[1]):768;
    int MODE = argc>2?atoi(argv[2]):0;
    int M=S,N=S,K=S;
    CD(cuInit(0));
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

    owngemm_sm120_tma(dC,dA,dB,M,K,N);
    cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){ printf("OWNGEMM-TMA FAULT: %s\n",cudaGetErrorString(e)); return 4; }

    CK(cudaMemcpy(hC,dC,szC*4,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hR,dR,szC*4,cudaMemcpyDeviceToHost));
    double se=0,sr=0,maxd=0;
    for(size_t i=0;i<szC;i++){ double a=hC[i],b=hR[i],dd=a-b; se+=dd*dd; sr+=b*b; if(fabs(dd)>maxd)maxd=fabs(dd); }
    double relrms = sr>0 ? sqrt(se/szC)/sqrt(sr/szC) : 0.0;
    printf("[GATE-TMA] S=%d own-GEMM-TMA vs cuBLAS-TF32: rel-RMS=%.3e max|delta|=%.3e (gate<=1e-2: %s)\n",
           S,relrms,maxd, relrms<=1e-2?"PASS":"FAIL");

    if(MODE==1){
        int iters=50;
        owngemm_sm120_tma(dC,dA,dB,M,K,N); CK(cudaDeviceSynchronize());
        cudaEvent_t t0,t1; cudaEventCreate(&t0); cudaEventCreate(&t1);
        cudaEventRecord(t0);
        for(int it=0;it<iters;it++) owngemm_sm120_tma(dC,dA,dB,M,K,N);
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
        printf("[PERF-TMA] S=%d own-GEMM-TMA %.2f TFLOP/s (%.4f ms)  cuBLAS-TF32 %.2f TFLOP/s (%.4f ms)  off-cuBLAS=%.2fx\n",
               S,tflops,ms1,cbtf,cbms, cbtf/tflops);
    }
    return relrms<=1e-2?0:2;
}
#endif

