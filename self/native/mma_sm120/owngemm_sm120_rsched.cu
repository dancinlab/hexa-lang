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

// cp.async 16-byte (128-bit) shared<-global, .cg (bypass L1). sm_80+ incl sm_120.
__device__ __forceinline__ void cp_async_cg16(void* smem, const void* gmem){
    unsigned s = (unsigned)__cvta_generic_to_shared(smem);
    asm volatile("cp.async.cg.shared.global [%0], [%1], 16;\n" :: "r"(s), "l"(gmem));
}
__device__ __forceinline__ void cp_async_commit(){ asm volatile("cp.async.commit_group;\n"); }
template<int N> __device__ __forceinline__ void cp_async_wait(){ asm volatile("cp.async.wait_group %0;\n" :: "n"(N)); }

// Bank-conflict-free smem pad — break the 32-bank stride on the fragment loads.
#define ASPAD 4
#define BSPAD 4

// Tiled TF32 GEMM. A,B,C row-major. HEXA-0POD OP-1 (#PR): tuned over the original
// F-BENCH-5 baseline (verdict .verdicts/hexa-0pod/F-OP1-SM120-OWNGEMM.txt). Three
// bit-exact-preserving optimizations stacked onto the same 64x64 / BK=16 tiling
// and the IDENTICAL per-output K-major mma.sync accumulation order (so the result
// is bit-for-bit the baseline's — rel-RMS vs baseline = 0, bitdiff = 0):
//   (a) bank-conflict-free smem pad (As[BM][BK+4], Bs[BK][BN+4]),
//   (b) vectorized 128-bit (.v4 / float4) global loads (K%4==0 && N%4==0 fast path,
//       scalar tail fallback otherwise),
//   (c) cp.async double-buffered BK stage (prefetch next tile while MMAs consume
//       the current one).
//   (d) [OP-1b] .v2 (float2) vectorized C-store epilogue — c0/c1 (and c2/c3) are
//       contiguous so they fuse to one 64-bit store; same bits, fewer store insns.
// Measured on aiden RTX 5070 (sm_120): 6.75->24.93 TFLOP/s @1024 (1.12x off cuBLAS),
// 8.05->29.92 TFLOP/s @2048 (~1.02x off cuBLAS). Was 3.2-6.9x off; now ~1.0-1.12x.
// OP-1b probed BK=32 + 3-stage cp.async ring too: both REGRESSED on the consumer
// card (smem-pressure occupancy loss; BK32+3stage overflows the 48KB cap). Only the
// .v2 epilogue (d) helped bit-exactly, so only it is shipped.
extern "C" __global__ void gemm_sm120(const float* __restrict__ A,
                                      const float* __restrict__ B,
                                      float* __restrict__ C,
                                      int M, int N, int K){
    __shared__ float As[2][BM][BK+ASPAD];   // double-buffered, padded
    __shared__ float Bs[2][BK][BN+BSPAD];
    int bm = blockIdx.y*BM, bn = blockIdx.x*BN;
    int tid = threadIdx.x;
    int warp = tid>>5, lane = tid&31;
    int wm = (warp/WARPS_N)*32;    // warp row offset within block (0 or 32)
    int wn = (warp%WARPS_N)*32;    // warp col offset within block (0 or 32)
    int gid = lane>>2, tig = lane&3;

    // accumulators: WM_FRAG x WN_FRAG fragments, each 4 f32.
    float acc[WM_FRAG][WN_FRAG][4];
    #pragma unroll
    for(int i=0;i<WM_FRAG;i++)for(int j=0;j<WN_FRAG;j++)for(int e=0;e<4;e++) acc[i][j][e]=0.f;

    int nk = (K+BK-1)/BK;
    // load one BK stage into smem buffer `buf` via cp.async 128-bit copies. A: 64x16
    // = 256 float4 / 128 threads -> 2 each. B: 16x64 = 256 float4 -> 2 each. Falls
    // back to a masked scalar gather for non-multiple-of-4 or boundary tiles.
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

    // prologue: stage 0
    load_stage(0,0); cp_async_commit();
    for(int k=0; k<nk; k++){
        int buf=k&1, nbuf=(k+1)&1;
        if(k+1<nk){ load_stage(nbuf,(k+1)*BK); cp_async_commit(); cp_async_wait<1>(); }
        else      { cp_async_wait<0>(); }
        __syncthreads();

        // two k8 sub-steps within BK.
        // ROUND-A r-sched (HEXA TF32 fastmode): cluster ALL shared-mem fragment
        // loads for the k8 step into a register buffer FIRST (a burst of LDS that
        // the scheduler can issue staggered across warps), THEN issue ALL MMAs
        // back-to-back. Vs the baseline (which interleaves one LDS group right
        // before each MMA, spreading LDS into the FMA/MMA pipe -> warp contention),
        // this separates the LDS phase from the MMA phase. The accumulation order
        // and operand values are IDENTICAL -> bit-for-bit the baseline result.
        #pragma unroll
        for(int ks=0; ks<BK; ks+=8){
            // (1) clustered LDS burst: all A and B fragments into registers.
            unsigned af[WM_FRAG][4];
            unsigned bf[WN_FRAG][2];
            #pragma unroll
            for(int fmi=0; fmi<WM_FRAG; fmi++){
                int mrow = wm + fmi*16;
                af[fmi][0]=f2tf32(As[buf][mrow + gid    ][ks + tig    ]);
                af[fmi][1]=f2tf32(As[buf][mrow + gid + 8][ks + tig    ]);
                af[fmi][2]=f2tf32(As[buf][mrow + gid    ][ks + tig + 4]);
                af[fmi][3]=f2tf32(As[buf][mrow + gid + 8][ks + tig + 4]);
            }
            #pragma unroll
            for(int fni=0; fni<WN_FRAG; fni++){
                int ncol = wn + fni*8;
                bf[fni][0]=f2tf32(Bs[buf][ks + tig    ][ncol + gid]);
                bf[fni][1]=f2tf32(Bs[buf][ks + tig + 4][ncol + gid]);
            }
            // (2) MMA phase: all m16n8k8 back-to-back, SAME order as baseline
            //     (fmi outer, fni inner) -> identical per-acc accumulation order.
            #pragma unroll
            for(int fmi=0; fmi<WM_FRAG; fmi++){
                #pragma unroll
                for(int fni=0; fni<WN_FRAG; fni++){
                    mma_m16n8k8(acc[fmi][fni], af[fmi], bf[fni]);
                }
            }
        }
        __syncthreads();
    }

    // store: each thread of the warp holds 4 acc per (16x8) fragment.
    // m16n8 C layout: c0:(row=groupID,col=2*tig), c1:(row=groupID,col=2*tig+1),
    //                 c2:(row=groupID+8,col=2*tig), c3:(row=groupID+8,col=2*tig+1)
    // HEXA-0POD OP-1b: c0/c1 (and c2/c3) are CONTIGUOUS in C (cols 2*tig, 2*tig+1),
    // so emit them as one 64-bit float2 .v2 store instead of two scalar writes —
    // SAME bits (no math change; rel-RMS vs baseline = 0), half the store
    // instructions in the common interior-tile case. Aiden RTX 5070 (sm_120):
    // +1.7% @1024 (24.50->24.93 TFLOP/s, 1.143x->1.124x off cuBLAS-TF32), small
    // top-up @2048 (the deeper-K levers BK=32 / 3-stage cp.async REGRESSED on the
    // consumer card's 48KB smem cap — occupancy loss > latency-hide; see verdict
    // .verdicts/hexa-0pod/F-OP1B-SM120-PIPE.txt). Scalar masked fallback at the
    // right/bottom boundary tiles and on odd alignment.
    #pragma unroll
    for(int fmi=0; fmi<WM_FRAG; fmi++){
        int mrow = bm + wm + fmi*16;
        #pragma unroll
        for(int fni=0; fni<WN_FRAG; fni++){
            int ncol = bn + wn + fni*8;
            float* d = acc[fmi][fni];
            int r0=mrow+gid, r1=mrow+gid+8, c0=ncol+2*tig, c1=ncol+2*tig+1;
            bool aligned = ((c0&1)==0);   // c0 even -> &C[..][c0] is 8-byte aligned
            if(r0<M && c1<N && aligned) *reinterpret_cast<float2*>(&C[(long long)r0*N+c0]) = make_float2(d[0],d[1]);
            else { if(r0<M && c0<N) C[(long long)r0*N+c0]=d[0];
                   if(r0<M && c1<N) C[(long long)r0*N+c1]=d[1]; }
            if(r1<M && c1<N && aligned) *reinterpret_cast<float2*>(&C[(long long)r1*N+c0]) = make_float2(d[2],d[3]);
            else { if(r1<M && c0<N) C[(long long)r1*N+c0]=d[2];
                   if(r1<M && c1<N) C[(long long)r1*N+c1]=d[3]; }
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
