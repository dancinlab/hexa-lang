// owngemm_sm120_bf16.cu — HEXA-0POD OP-3: BF16 own-GEMM for consumer Blackwell
// sm_120 (RTX 5070, cc12.0), using the PORTABLE warp-level tensor-core MMA
// `mma.sync.aligned.m16n8k16.row.col.f32.bf16.bf16.f32`.
//
// EXTENDS the OP-1 (#2972) TF32 own-GEMM (owngemm_sm120.cu) to BF16. The BF16
// mma is m16n8k16 (k16, NOT k8 like TF32) — the 16x8x16 fragment packs two
// bf16 per 32-bit register, so per warp the A fragment is 4 regs of 8 bf16 and
// the B fragment is 2 regs of 4 bf16. The fp32 input is round-to-nearest
// converted to bf16 (RN, ties-to-even) on the fly; accumulation stays fp32.
//
// We carry over OP-1's bit-faithful layout/load wins verbatim:
//   (a) bank-conflict-free smem pad (As[BM][BK+pad], Bs[BK][BN+pad]),
//   (b) vectorized 128-bit (.v4 / float4) global loads (fast path; scalar tail),
//   (c) cp.async double-buffered BK stage.
//   (d) [OP-3b] .v2 (float2) vectorized C-store epilogue — the BF16 m16n8 C
//       fragment is fp32 (same OUTPUT layout as TF32), so c0/c1 (and c2/c3) are
//       contiguous and fuse to one 64-bit store; SAME bits, fewer store insns.
//       This is the ONE lever OP-1b found bit-exactly positive on the 5070 (+1.7%
//       @1024 TF32); BK=32 / 3-stage cp.async were CLOSED-NEGATIVE there (smem
//       pressure on the 48KB cap) and are NOT attempted. rel-RMS vs the OP-3
//       baseline = 0 (a store-vectorization, not a math change).
// The fp32->bf16 RN conversion happens at the smem->register fragment load (same
// place TF32's f2tf32 happened), so the smem staging + global load path is an
// exact structural copy of the TF32 kernel; only the MMA tile (k16 vs k8), the
// fragment packing (2 bf16/reg), and the operand conversion differ.
//
// GATE (g5, W14 convention): bit-FAITHFUL, NOT bit-exact-vs-fp32. rel-RMS vs an
// FP64 reference <= 1e-2 (BF16 has 8 mantissa bits; truncation error is real and
// expected), AND run-to-run determinism max|delta| = 0 (identical K-major
// mma.sync accumulation order => the kernel is its own bit-for-bit reproducer).
//
// GEMM: C[M,N] = A[M,K] @ B[K,N], all row-major, BF16 matmul / FP32 accum.
//
// Block tile: BM x BN = 64 x 64, BK = 16 (== one k16 mma step). One block = 4
// warps (128 threads) laid 2x2; each warp owns a 32x32 output sub-tile = a 2x4
// grid of m16n8 MMA fragments (2 m16-rows x 4 n8-cols = 8 mma.sync per BK step).
//
// Modes (argv[2]):
//   0  GATE: rel-RMS / max|delta| vs FP64 ref at the bench shape (default D=768).
//   1  PERF: TFLOP/s vs cuBLAS-BF16 (square S from argv[1]).
//   2  DETERMINISM: run twice, report max|delta| between the two own-GEMM runs.
//   3  DUMP: write the own-GEMM C output to argv[3] as raw float32 (for the .v2-vs-
//      OP-3-baseline BYTE-IDENTICAL `cmp` — build a -DEPILOGUE_SCALAR twin + diff).
//
// Build: build_owngemm_bf16.sh (run on aiden).

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
#define BK 16            // == one m16n8k16 BF16 mma step
#define WARPS_M 2
#define WARPS_N 2
#define NWARP (WARPS_M*WARPS_N)   // 4
#define NTHREAD (NWARP*32)        // 128
// Per warp: 32x32 output = 2 (m16) x 4 (n8) fragments.
#define WM_FRAG 2
#define WN_FRAG 4

// round-to-nearest-even fp32 -> bf16 (hardware instruction).
__device__ __forceinline__ unsigned short f2bf16(float x){
    __nv_bfloat16 b = __float2bfloat16_rn(x);
    unsigned short u; memcpy(&u,&b,2); return u;
}
// pack two bf16 (lo,hi) into a 32-bit register (lo in low 16 bits).
__device__ __forceinline__ unsigned packbf16(float lo, float hi){
    return (unsigned)f2bf16(lo) | ((unsigned)f2bf16(hi) << 16);
}

// One mma.sync m16n8k16 BF16 step. A frag = 4 regs (8 bf16), B frag = 2 regs
// (4 bf16), C/D = 4 f32 acc regs (in/out).
__device__ __forceinline__ void mma_m16n8k16(float* d, const unsigned* a, const unsigned* b){
    asm volatile(
      "mma.sync.aligned.m16n8k16.row.col.f32.bf16.bf16.f32 "
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

// Tiled BF16 GEMM. A,B,C row-major. fp32 inputs staged into smem AS fp32 (same
// global-load / cp.async path as the OP-1 TF32 kernel), then RN-converted to bf16
// at the smem->register fragment load. Identical 64x64 / BK=16 tiling and the
// IDENTICAL per-output K-major mma.sync accumulation order, so run-to-run is
// bit-for-bit reproducible (determinism max|d|=0).
extern "C" __global__ void gemm_sm120_bf16(const float* __restrict__ A,
                                           const float* __restrict__ B,
                                           float* __restrict__ C,
                                           int M, int N, int K){
    __shared__ float As[2][BM][BK+ASPAD];   // double-buffered, padded (fp32 staged)
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

        // one k16 step per BK tile (BK==16). m16n8k16 BF16 fragment layout:
        //   A (m16k16, row): each thread holds 8 bf16 in 4 regs. For group g=gid,
        //   t=tig: a0 = {a[g][2t], a[g][2t+1]} (k=0..1 of the t-th col-pair),
        //   a1 = {a[g+8][2t], a[g+8][2t+1]}, a2 = {a[g][2t+8], a[g][2t+9]},
        //   a3 = {a[g+8][2t+8], a[g+8][2t+9]} — i.e. the k8 TF32 layout doubled
        //   along K (each TF32 single-k element becomes a bf16 pair at k and k+8
        //   ... no: the k16 packs k=2t,2t+1 in reg0 low/high). See PTX ISA 9.7.13.3.
        #pragma unroll
        for(int fmi=0; fmi<WM_FRAG; fmi++){
            int mrow = wm + fmi*16;
            // A fragment (m16n8k16, .row): thread (gid,tig) holds, per the PTX
            // fragment map, 4 registers each packing 2 bf16 along K:
            //   reg0: A[gid   ][2*tig  ], A[gid   ][2*tig+1]
            //   reg1: A[gid+8 ][2*tig  ], A[gid+8 ][2*tig+1]
            //   reg2: A[gid   ][2*tig+8], A[gid   ][2*tig+9]
            //   reg3: A[gid+8 ][2*tig+8], A[gid+8 ][2*tig+9]
            unsigned af[4];
            af[0]=packbf16(As[buf][mrow+gid  ][2*tig  ], As[buf][mrow+gid  ][2*tig+1]);
            af[1]=packbf16(As[buf][mrow+gid+8][2*tig  ], As[buf][mrow+gid+8][2*tig+1]);
            af[2]=packbf16(As[buf][mrow+gid  ][2*tig+8], As[buf][mrow+gid  ][2*tig+9]);
            af[3]=packbf16(As[buf][mrow+gid+8][2*tig+8], As[buf][mrow+gid+8][2*tig+9]);
            #pragma unroll
            for(int fni=0; fni<WN_FRAG; fni++){
                int ncol = wn + fni*8;
                // B fragment (m16n8k16, .col): thread (gid,tig) holds 2 registers,
                // each packing 2 bf16 along K, for column n=gid:
                //   reg0: B[2*tig  ][gid], B[2*tig+1][gid]
                //   reg1: B[2*tig+8][gid], B[2*tig+9][gid]
                unsigned bf[2];
                bf[0]=packbf16(Bs[buf][2*tig  ][ncol+gid], Bs[buf][2*tig+1][ncol+gid]);
                bf[1]=packbf16(Bs[buf][2*tig+8][ncol+gid], Bs[buf][2*tig+9][ncol+gid]);
                mma_m16n8k16(acc[fmi][fni], af, bf);
            }
        }
        __syncthreads();
    }

    // store: each thread of the warp holds 4 acc per (16x8) fragment.
    // m16n8 C layout: c0:(row=groupID,col=2*tig), c1:(row=groupID,col=2*tig+1),
    //                 c2:(row=groupID+8,col=2*tig), c3:(row=groupID+8,col=2*tig+1)
    // HEXA-0POD OP-3b: the BF16 m16n8 C fragment layout is IDENTICAL to the TF32
    // m16n8 one (the mma OUTPUT fragment is fp32 in both — only the input dtype /
    // k-step differ), so OP-1b's bit-exact .v2 (float2) vectorized C-store epilogue
    // applies VERBATIM: c0/c1 (and c2/c3) are CONTIGUOUS in C (cols 2*tig, 2*tig+1),
    // so emit each pair as one 64-bit float2 .v2 store instead of two scalar writes
    // — SAME bits (no math change; rel-RMS vs the OP-3 baseline = 0), half the store
    // instructions in the common interior-tile case. Scalar masked fallback at the
    // right/bottom boundary tiles and on odd (8-byte-unaligned) column start.
    #pragma unroll
    for(int fmi=0; fmi<WM_FRAG; fmi++){
        int mrow = bm + wm + fmi*16;
        #pragma unroll
        for(int fni=0; fni<WN_FRAG; fni++){
            int ncol = bn + wn + fni*8;
            float* d = acc[fmi][fni];
            int r0=mrow+gid, r1=mrow+gid+8, c0=ncol+2*tig, c1=ncol+2*tig+1;
#ifdef EPILOGUE_SCALAR
            // OP-3 baseline epilogue (scalar stores) — built with -DEPILOGUE_SCALAR
            // so the build script can prove the .v2 path is BYTE-IDENTICAL to it.
            if(r0<M && c0<N) C[(long long)r0*N+c0]=d[0];
            if(r0<M && c1<N) C[(long long)r0*N+c1]=d[1];
            if(r1<M && c0<N) C[(long long)r1*N+c0]=d[2];
            if(r1<M && c1<N) C[(long long)r1*N+c1]=d[3];
#else
            bool aligned = ((c0&1)==0);   // c0 even -> &C[..][c0] is 8-byte aligned
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

// host wrapper.
extern "C" void owngemm_sm120_bf16(float* C, const float* A, const float* B, int M, int K, int N){
    dim3 blk(NTHREAD);
    dim3 grid((N+BN-1)/BN, (M+BM-1)/BM);
    gemm_sm120_bf16<<<grid,blk>>>(A,B,C,M,N,K);
}

#ifdef OWNGEMM_MAIN
static void fill(float* x, long long n, unsigned seed){
    for(long long i=0;i<n;i++){ unsigned h=(unsigned)(i*2654435761u)^seed; x[i]=((h&0xffff)/65535.f-0.5f)*0.2f; }
}
// FP64 reference: R = A@B with double accumulation (the bit-faithful oracle).
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

    // own-GEMM BF16
    owngemm_sm120_bf16(dC,dA,dB,M,K,N);
    cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){ printf("OWNGEMM FAULT: %s\n",cudaGetErrorString(e)); return 4; }
    CK(cudaMemcpy(hC,dC,szC*4,cudaMemcpyDeviceToHost));

    // GATE: rel-RMS vs FP64 reference (bit-faithful, BF16 mantissa truncation OK).
    double *hR=(double*)malloc(szC*8);
    ref_fp64(hA,hB,hR,M,N,K);
    double se=0,sr=0,maxd=0;
    for(size_t i=0;i<szC;i++){ double a=hC[i],b=hR[i],dd=a-b; se+=dd*dd; sr+=b*b; if(fabs(dd)>maxd)maxd=fabs(dd); }
    double relrms = sr>0 ? sqrt(se/szC)/sqrt(sr/szC) : 0.0;
    printf("[GATE] S=%d own-GEMM-BF16 vs FP64 ref: rel-RMS=%.3e max|delta|=%.3e (gate<=1e-2: %s)\n",
           S,relrms,maxd, relrms<=1e-2?"PASS":"FAIL");

    if(MODE==3){
        // DUMP own-GEMM C as raw float32 to argv[3] — the build script builds this
        // (.v2 epilogue) and a -DEPILOGUE_SCALAR twin, dumps both, and `cmp`s them
        // for BYTE-IDENTITY (proves the .v2 store changed zero output bits).
        const char* path = argc>3?argv[3]:"/tmp/owngemm_bf16_dump.bin";
        FILE* f=fopen(path,"wb");
        if(!f){ printf("[DUMP] cannot open %s\n",path); return 5; }
        fwrite(hC,4,szC,f); fclose(f);
        printf("[DUMP] S=%d wrote %zu floats to %s\n",S,szC,path);
    }

    if(MODE==2){
        // DETERMINISM: run again, compare own-vs-own bit-for-bit.
        CK(cudaMemset(dC,0,szC*4));
        owngemm_sm120_bf16(dC,dA,dB,M,K,N); CK(cudaDeviceSynchronize());
        CK(cudaMemcpy(hC2,dC,szC*4,cudaMemcpyDeviceToHost));
        double md=0; size_t nbit=0;
        for(size_t i=0;i<szC;i++){ double dd=fabs((double)hC[i]-(double)hC2[i]); if(dd>md)md=dd;
            unsigned u1,u2; memcpy(&u1,&hC[i],4); memcpy(&u2,&hC2[i],4); if(u1!=u2)nbit++; }
        printf("[DET] S=%d run-to-run max|delta|=%.3e bitdiff=%zu/%zu (determinism: %s)\n",
               S,md,nbit,szC, (md==0.0&&nbit==0)?"HELD":"BROKEN");
    }

    if(MODE==1){
        // PERF vs cuBLAS-BF16. cuBLAS needs bf16 device buffers.
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
        // own perf
        owngemm_sm120_bf16(dC,dA,dB,M,K,N); CK(cudaDeviceSynchronize());
        cudaEvent_t t0,t1; cudaEventCreate(&t0); cudaEventCreate(&t1);
        cudaEventRecord(t0);
        for(int it=0;it<iters;it++) owngemm_sm120_bf16(dC,dA,dB,M,K,N);
        cudaEventRecord(t1); CK(cudaEventSynchronize(t1));
        float ms=0; cudaEventElapsedTime(&ms,t0,t1); double ms1=ms/iters;
        double flops=2.0*(double)M*N*K, tflops=flops/(ms1*1e-3)/1e12;
        // cuBLAS-BF16: R = A@B row-major == cublas(N,N, N,M,K, B,A) col-major.
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
        printf("[PERF] S=%d own-GEMM-BF16 %.2f TFLOP/s (%.4f ms)  cuBLAS-BF16 %.2f TFLOP/s (%.4f ms)  off-cuBLAS=%.2fx\n",
               S,tflops,ms1,cbtf,cbms, cbtf/tflops);
    }
    return relrms<=1e-2?0:2;
}
#endif
