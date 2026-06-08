// owngemm_sm120.cu — HEXA-BENCH BENCH-5: TF32 own-GEMM for consumer Blackwell
// sm_120 (RTX 5070, cc12.0), using the PORTABLE warp-level tensor-core MMA
// `mma.sync.aligned.m16n8k8.row.col.f32.tf32.tf32.f32`.
//
// WHY NOT OG10-exact: OG10 (self/native/wgmma/wgmma_tf32_w10.cu) is a Hopper
// sm_90a kernel built on wgmma.mma_async + cp.async.bulk.tensor TMA + 128B-
// swizzle matrix descriptors — NONE of which are in the sm_120 ISA (BENCH-3
// confirmed ptxas rejects wgmma.* for sm_120). We PORT OG10's idea (a hand-
// written tensor-core own-GEMM, bit-checked vs cuBLAS-TF32) to the instruction
// sm_120 DOES expose: the Ampere+ warp synchronous MMA. We keep OG10's tiling
// spirit (block tile + smem stage + register-resident accumulators) but on the
// warp-MMA primitive instead of the warpgroup-async one.
//
// GEMM: C[M,N] = A[M,K] @ B[K,N], all row-major, TF32 matmul / FP32 accum.
//
// Block tile: BM x BN = 64 x 64, BK = 16. One block = 4 warps (128 threads),
// laid 2x2; each warp owns a 32x32 output sub-tile = a 2x4 grid of m16n8 MMA
// fragments (warp does 2 m16-rows x 4 n8-cols = 8 mma.sync per k8 step).
//
// Modes (argv[2]):
//   0  GATE: rel-RMS / max|delta| vs cuBLAS-TF32 at the bench shape (default D=768).
//   1  PERF: TFLOP/s sweep (square S from argv[1]).
//
// Build: build_owngemm.sh (run on aiden).

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
#define NWARP (WARPS_M*WARPS_N)   // 4
#define NTHREAD (NWARP*32)        // 128
// Per warp: 32x32 output = 2 (m16) x 4 (n8) fragments.
#define WM_FRAG 2
#define WN_FRAG 4

__device__ __forceinline__ unsigned f2tf32(float x){
    // round-to-nearest TF32 (truncate mantissa to 10 bits with RN) then keep f32 bits.
    unsigned u; memcpy(&u,&x,4); u=(u+0x1000u)&0xFFFFE000u; return u;
}

// One mma.sync m16n8k8 TF32 step. A frag = 4 tf32 regs, B frag = 2 tf32 regs,
// C/D = 4 f32 acc regs (in/out).
__device__ __forceinline__ void mma_m16n8k8(float* d, const unsigned* a, const unsigned* b){
    asm volatile(
      "mma.sync.aligned.m16n8k8.row.col.f32.tf32.tf32.f32 "
      "{%0,%1,%2,%3}, {%4,%5,%6,%7}, {%8,%9}, {%0,%1,%2,%3};\n"
      : "+f"(d[0]),"+f"(d[1]),"+f"(d[2]),"+f"(d[3])
      : "r"(a[0]),"r"(a[1]),"r"(a[2]),"r"(a[3]),"r"(b[0]),"r"(b[1]));
}

// Tiled TF32 GEMM. A,B,C row-major. Shared-mem staged BK-deep, two m16n8k8 sub-
// steps per BK (BK=16 = 2 * k8).
extern "C" __global__ void gemm_sm120(const float* __restrict__ A,
                                      const float* __restrict__ B,
                                      float* __restrict__ C,
                                      int M, int N, int K){
    __shared__ float As[BM][BK];   // 64x16
    __shared__ float Bs[BK][BN];   // 16x64
    int bm = blockIdx.y*BM, bn = blockIdx.x*BN;
    int tid = threadIdx.x;
    int warp = tid>>5, lane = tid&31;
    int wm = (warp/WARPS_N)*32;    // warp row offset within block (0 or 32)
    int wn = (warp%WARPS_N)*32;    // warp col offset within block (0 or 32)

    // accumulators: WM_FRAG x WN_FRAG fragments, each 4 f32.
    float acc[WM_FRAG][WN_FRAG][4];
    #pragma unroll
    for(int i=0;i<WM_FRAG;i++)for(int j=0;j<WN_FRAG;j++)for(int e=0;e<4;e++) acc[i][j][e]=0.f;

    for(int k0=0; k0<K; k0+=BK){
        // cooperative load A[bm:bm+64, k0:k0+16] -> As ; B[k0:k0+16, bn:bn+64] -> Bs
        // As: 64*16=1024 floats, 128 threads -> 8 each.
        #pragma unroll
        for(int i=tid; i<BM*BK; i+=NTHREAD){
            int r=i/BK, c=i%BK; int gr=bm+r, gc=k0+c;
            As[r][c] = (gr<M && gc<K) ? A[(long long)gr*K+gc] : 0.f;
        }
        // Bs: 16*64=1024 floats.
        #pragma unroll
        for(int i=tid; i<BK*BN; i+=NTHREAD){
            int r=i/BN, c=i%BN; int gr=k0+r, gc=bn+c;
            Bs[r][c] = (gr<K && gc<N) ? B[(long long)gr*N+gc] : 0.f;
        }
        __syncthreads();

        // two k8 sub-steps within BK
        #pragma unroll
        for(int ks=0; ks<BK; ks+=8){
            // For each m16 fragment row and n8 fragment col owned by this warp,
            // load A/B fragments from smem in the mma.sync canonical layout and accumulate.
            #pragma unroll
            for(int fmi=0; fmi<WM_FRAG; fmi++){
                int mrow = wm + fmi*16;     // base row of this 16-row A fragment, within block
                // --- A fragment (m16 x k8), row-major operand A, 4 tf32 regs/thread ---
                // canonical mma.m16n8k8 A layout (tf32):
                //   groupID = lane>>2 ; threadInGroup = lane&3
                //   a0 -> row groupID,      col (threadInGroup)         [k 0..3 even? -> actually]
                // tf32 m16n8k8 A: each thread holds a[0..3] for
                //   a0: (row=groupID,     col=threadInGroup)
                //   a1: (row=groupID+8,   col=threadInGroup)
                //   a2: (row=groupID,     col=threadInGroup+4)
                //   a3: (row=groupID+8,   col=threadInGroup+4)
                int gid = lane>>2, tig = lane&3;
                unsigned af[4];
                af[0]=f2tf32(As[mrow + gid    ][ks + tig    ]);
                af[1]=f2tf32(As[mrow + gid + 8][ks + tig    ]);
                af[2]=f2tf32(As[mrow + gid    ][ks + tig + 4]);
                af[3]=f2tf32(As[mrow + gid + 8][ks + tig + 4]);
                #pragma unroll
                for(int fni=0; fni<WN_FRAG; fni++){
                    int ncol = wn + fni*8;   // base col of this 8-col B fragment, within block
                    // --- B fragment (k8 x n8), operand B col-major, 2 tf32 regs/thread ---
                    // tf32 m16n8k8 B:
                    //   b0: (row=threadInGroup,   col=groupID)
                    //   b1: (row=threadInGroup+4, col=groupID)
                    unsigned bf[2];
                    bf[0]=f2tf32(Bs[ks + tig    ][ncol + gid]);
                    bf[1]=f2tf32(Bs[ks + tig + 4][ncol + gid]);
                    mma_m16n8k8(acc[fmi][fni], af, bf);
                }
            }
        }
        __syncthreads();
    }

    // store: each thread of the warp holds 4 acc per (16x8) fragment.
    // m16n8 C layout: c0:(row=groupID,col=2*tig), c1:(row=groupID,col=2*tig+1),
    //                 c2:(row=groupID+8,col=2*tig), c3:(row=groupID+8,col=2*tig+1)
    int gid = lane>>2, tig = lane&3;
    #pragma unroll
    for(int fmi=0; fmi<WM_FRAG; fmi++){
        int mrow = bm + wm + fmi*16;
        #pragma unroll
        for(int fni=0; fni<WN_FRAG; fni++){
            int ncol = bn + wn + fni*8;
            float* d = acc[fmi][fni];
            int r0=mrow+gid, r1=mrow+gid+8, c0=ncol+2*tig, c1=ncol+2*tig+1;
            if(r0<M && c0<N) C[(long long)r0*N+c0]=d[0];
            if(r0<M && c1<N) C[(long long)r0*N+c1]=d[1];
            if(r1<M && c0<N) C[(long long)r1*N+c0]=d[2];
            if(r1<M && c1<N) C[(long long)r1*N+c1]=d[3];
        }
    }
}

// host wrapper used by both this harness and the bench (extern "C" og10-style sym).
extern "C" void owngemm_sm120(float* C, const float* A, const float* B, int M, int K, int N){
    dim3 blk(NTHREAD);
    dim3 grid((N+BN-1)/BN, (M+BM-1)/BM);
    gemm_sm120<<<grid,blk>>>(A,B,C,M,N,K);
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

    // cuBLAS-TF32 reference: R = A@B row-major == cublas(N,N, N,M,K, B,A) col-major.
    cublasHandle_t cb; CB(cublasCreate(&cb));
    CB(cublasSetMathMode(cb, CUBLAS_TF32_TENSOR_OP_MATH));
    const float alpha=1.f, beta=0.f;
    CB(cublasGemmEx(cb, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha,
        dB, CUDA_R_32F, N, dA, CUDA_R_32F, K, &beta,
        dR, CUDA_R_32F, N, CUBLAS_COMPUTE_32F_FAST_TF32, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
    CK(cudaDeviceSynchronize());

    // own-GEMM
    owngemm_sm120(dC,dA,dB,M,K,N);
    cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){ printf("OWNGEMM FAULT: %s\n",cudaGetErrorString(e)); return 4; }

    CK(cudaMemcpy(hC,dC,szC*4,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hR,dR,szC*4,cudaMemcpyDeviceToHost));
    double se=0,sr=0,maxd=0;
    for(size_t i=0;i<szC;i++){ double a=hC[i],b=hR[i],dd=a-b; se+=dd*dd; sr+=b*b; if(fabs(dd)>maxd)maxd=fabs(dd); }
    double relrms = sr>0 ? sqrt(se/szC)/sqrt(sr/szC) : 0.0;
    printf("[GATE] S=%d own-GEMM vs cuBLAS-TF32: rel-RMS=%.3e max|delta|=%.3e (gate<=1e-2: %s)\n",
           S,relrms,maxd, relrms<=1e-2?"PASS":"FAIL");

    if(MODE==1){
        // PERF
        int iters=50;
        owngemm_sm120(dC,dA,dB,M,K,N); CK(cudaDeviceSynchronize());
        cudaEvent_t t0,t1; cudaEventCreate(&t0); cudaEventCreate(&t1);
        cudaEventRecord(t0);
        for(int it=0;it<iters;it++) owngemm_sm120(dC,dA,dB,M,K,N);
        cudaEventRecord(t1); CK(cudaEventSynchronize(t1));
        float ms=0; cudaEventElapsedTime(&ms,t0,t1); double ms1=ms/iters;
        double flops=2.0*(double)M*N*K, tflops=flops/(ms1*1e-3)/1e12;
        // cuBLAS perf for ratio
        cudaEventRecord(t0);
        for(int it=0;it<iters;it++)
          cublasGemmEx(cb, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha,
            dB, CUDA_R_32F, N, dA, CUDA_R_32F, K, &beta,
            dR, CUDA_R_32F, N, CUBLAS_COMPUTE_32F_FAST_TF32, CUBLAS_GEMM_DEFAULT_TENSOR_OP);
        cudaEventRecord(t1); CK(cudaEventSynchronize(t1));
        cudaEventElapsedTime(&ms,t0,t1); double cbms=ms/iters, cbtf=flops/(cbms*1e-3)/1e12;
        printf("[PERF] S=%d own-GEMM %.2f TFLOP/s (%.4f ms)  cuBLAS-TF32 %.2f TFLOP/s (%.4f ms)  off-cuBLAS=%.2fx\n",
               S,tflops,ms1,cbtf,cbms, cbtf/tflops);
    }
    return relrms<=1e-2?0:2;
}
#endif
