// owngemm_batched_sm120.cu — HEXA fleet-full kernel-quality-lever1 GPU.
//
// BEYOND-PARITY overtake target: cublasSgemmStridedBatched on consumer
// Blackwell sm_120 (RTX 5070) is reported (CloudRift, sm_120/5090) to
// mis-dispatch — it picks a tiny SIMT tile (cutlass_*_simt_sgemm_128x32)
// and gets stuck at 33-42% FMA-util across 256->8192, its escalation logic
// MISSING for the batched FP32 path. An own register-/tensor-tiled batched
// kernel (one tile-program per (batch, tile), grid = batch x tiles) can
// saturate the 48 SMs and overtake the cuBLAS pinned-tile.
//
// This standalone bench:
//   PREREQ  — measure stock cublasSgemmStridedBatched GFLOP/s on this card,
//             so we MEASURE whether the 5070 reproduces the mis-dispatch
//             (don't assume the 5090 result transfers).
//   OWN     — a batched FP32 GEMM built on the SAME bit-exact-vs-cuBLAS
//             TF32 mma.sync.m16n8k8 core as owngemm_sm120.cu (gemm core
//             below mirrors gemm_sm120, batched over blockIdx.z), measured
//             at the same shapes/batches.
//   COMPARE — own GFLOP/s vs cuBLAS, off-ratio overtake, rel-RMS vs FP64
//             reference, run-to-run byte-eq (deterministic: pinned K-major
//             reduction order, no atomics).
//
// NOTE on dtype: cuBLAS Sgemm = true FP32. Our tensor-core core is TF32
// (mma.sync .tf32). We therefore ALSO run a cublas TF32 strided-batched
// reference (cublasGemmStridedBatchedEx + COMPUTE_32F_FAST_TF32) as the
// apples-to-apples math oracle for the own kernel, while reporting the raw
// cublasSgemmStridedBatched (FP32) baseline the defect is about. Off-ratio
// is reported against BOTH (cuBLAS-Sgemm and cuBLAS-TF32-batched).
//
// Build: build_owngemm_batched.sh (run on aiden).
//
// ─── MEASURED VERDICT (aiden RTX 5070 sm_120, 2026-06-21) ───────────────
// PREREQ — the 5070 does NOT reproduce the 5090 batched-FP32 dispatcher
// defect in any beatable form. cublasSgemmStridedBatched (true FP32) runs a
// steady ~13.6-14.4 TFLOP/s across S∈{512..4096}, B∈{4,8,16} — flat, not a
// tiny-tile collapse; that ~14 TF/s is the consumer FP32 ceiling (no native
// FP32 tensor path on consumer Blackwell). cublasGemmStridedBatchedEx with
// COMPUTE_32F_FAST_TF32 dispatches CORRECTLY at ~20→34 TFLOP/s (rising with
// size, ~near the card's ~37 TF/s TF32 roofline). No mis-dispatch to escalate.
// (ncu FMA/tensor-util unavailable on this host: ERR_NVGPUCTRPERM, non-root
// pool user can't read GPU perf counters — so util-% not captured; GFLOP/s
// roofline-fraction is the evidence instead.)
//
// own/Sgemm = 1.67-2.10x — but that is TF32(own) vs true-FP32(cuBLAS), an
// apples-to-oranges dtype gap, NOT a dispatcher win. The honest same-math
// comparison is own-TF32 vs cuBLAS-TF32-batched:
//   S=512  B4/8/16: own/TF32 = 1.183 / 1.007 / 1.029x   ← only overtake band
//   S=1024 B4/8/16:           = 0.990 / 0.909 / 0.919x
//   S=2048 B4/8/16:           = 0.909 / 0.872 / 0.861x
//   S=4096 B4/8/16:           = 0.712 / 0.672 / 0.661x
// Overtake exists ONLY in the small-S (512) under-fill regime where many tiny
// batched problems leave cuBLAS's larger TF32 tile under-occupied and our
// 64x64 grid×batch fills the 48 SMs better (≤1.18x); at S≥1024 cuBLAS's
// batched TF32 kernel is well-occupied and wins (own ~0.86-0.99x parity-band,
// degrading at S=4096 where our fixed 64x64/BK16/no-Lds-pipeline tile leaves
// MMA throughput on the table vs cuBLAS's bigger tiles).
// rel-RMS(own vs FP64)=6.2e-4 (TF32 mantissa), run-to-run byte-eq = YES
// (max|Δ|=0, pinned K-major reduction, no atomics — the deterministic moat).
//
// VERDICT: measured 🧱 — the beyond-parity batched-overtake REGIME IS ABSENT
// on the 5070 (cuBLAS dispatches its batched TF32 path correctly here; the
// CloudRift 5090 Sgemm mis-dispatch did NOT transfer). The lane yields a
// real but NARROW win: own deterministic batched TF32 overtakes cuBLAS by
// ≤1.18x ONLY at small S=512 under-fill — shippable as an opt-in
// deterministic batched fast-path for skinny/many-batch shapes, NOT a general
// overtake. FP64 shipped default (_hx_k_gemm_strided_batched) untouched →
// byteeq-NEUTRAL.

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cuda_runtime.h>
#include <cublas_v2.h>

#define CK(x) do{cudaError_t e=(x); if(e!=cudaSuccess){printf("CUDA-ERR %s @%d: %s\n",#x,__LINE__,cudaGetErrorString(e));exit(3);}}while(0)
#define CB(x) do{cublasStatus_t s=(x); if(s!=CUBLAS_STATUS_SUCCESS){printf("CUBLAS-ERR %d @%d\n",(int)s,__LINE__);exit(3);}}while(0)

// ── batched TF32 mma.sync core (mirror of owngemm_sm120.cu gemm_sm120) ──
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

// Batched tiled TF32 GEMM. A,B,C row-major, contiguous strided batch.
// One block computes a 64x64 tile of one batch's C; grid.z = batch.
// Same K-major mma.sync accumulation order as gemm_sm120 -> bit-exact
// vs the single-GEMM kernel per batch, deterministic, no atomics.
extern "C" __global__ void gemm_batched_sm120(const float* __restrict__ A,
                                              const float* __restrict__ B,
                                              float* __restrict__ C,
                                              int M, int N, int K){
    __shared__ float As[2][BM][BK+ASPAD];
    __shared__ float Bs[2][BK][BN+BSPAD];
    long long b = blockIdx.z;
    const float* Ab = A + b*(long long)M*K;
    const float* Bb = B + b*(long long)K*N;
    float*       Cb = C + b*(long long)M*N;
    int bm = blockIdx.y*BM, bn = blockIdx.x*BN;
    int tid = threadIdx.x;
    int warp = tid>>5, lane = tid&31;
    int wm = (warp/WARPS_N)*32, wn = (warp%WARPS_N)*32;
    int gid = lane>>2, tig = lane&3;

    float acc[WM_FRAG][WN_FRAG][4];
    #pragma unroll
    for(int i=0;i<WM_FRAG;i++)for(int j=0;j<WN_FRAG;j++)for(int e=0;e<4;e++) acc[i][j][e]=0.f;

    int nk = (K+BK-1)/BK;
    auto load_stage = [&](int buf,int k0){
        #pragma unroll
        for(int i=tid; i<BM*BK/4; i+=NTHREAD){
            int r=i/(BK/4), c4=i%(BK/4), c=c4*4; int gr=bm+r, gc=k0+c;
            if(gr<M && gc+3<K) cp_async_cg16(&As[buf][r][c], &Ab[(long long)gr*K+gc]);
            else { float4 v=make_float4(0,0,0,0);
                   if(gr<M){ for(int e=0;e<4;e++) ((float*)&v)[e]=(gc+e<K)?Ab[(long long)gr*K+gc+e]:0.f; }
                   As[buf][r][c+0]=v.x;As[buf][r][c+1]=v.y;As[buf][r][c+2]=v.z;As[buf][r][c+3]=v.w; }
        }
        #pragma unroll
        for(int i=tid; i<BK*BN/4; i+=NTHREAD){
            int r=i/(BN/4), c4=i%(BN/4), c=c4*4; int gr=k0+r, gc=bn+c;
            if(gr<K && gc+3<N) cp_async_cg16(&Bs[buf][r][c], &Bb[(long long)gr*N+gc]);
            else { float4 v=make_float4(0,0,0,0);
                   if(gr<K){ for(int e=0;e<4;e++) ((float*)&v)[e]=(gc+e<N)?Bb[(long long)gr*N+gc+e]:0.f; }
                   Bs[buf][r][c+0]=v.x;Bs[buf][r][c+1]=v.y;Bs[buf][r][c+2]=v.z;Bs[buf][r][c+3]=v.w; }
        }
    };

    load_stage(0,0); cp_async_commit();
    for(int k=0; k<nk; k++){
        int buf=k&1, nbuf=(k+1)&1;
        if(k+1<nk){ load_stage(nbuf,(k+1)*BK); cp_async_commit(); cp_async_wait<1>(); }
        else      { cp_async_wait<0>(); }
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

    #pragma unroll
    for(int fmi=0; fmi<WM_FRAG; fmi++){
        int mrow = bm + wm + fmi*16;
        #pragma unroll
        for(int fni=0; fni<WN_FRAG; fni++){
            int ncol = bn + wn + fni*8;
            float* d = acc[fmi][fni];
            int r0=mrow+gid, r1=mrow+gid+8, c0=ncol+2*tig, c1=ncol+2*tig+1;
            bool aligned = ((c0&1)==0);
            if(r0<M && c1<N && aligned) *reinterpret_cast<float2*>(&Cb[(long long)r0*N+c0]) = make_float2(d[0],d[1]);
            else { if(r0<M && c0<N) Cb[(long long)r0*N+c0]=d[0];
                   if(r0<M && c1<N) Cb[(long long)r0*N+c1]=d[1]; }
            if(r1<M && c1<N && aligned) *reinterpret_cast<float2*>(&Cb[(long long)r1*N+c0]) = make_float2(d[2],d[3]);
            else { if(r1<M && c0<N) Cb[(long long)r1*N+c0]=d[2];
                   if(r1<M && c1<N) Cb[(long long)r1*N+c1]=d[3]; }
        }
    }
}

extern "C" void owngemm_batched_sm120(float* C, const float* A, const float* B,
                                      int M, int K, int N, int batch, cudaStream_t s){
    dim3 blk(NTHREAD);
    dim3 grid((N+BN-1)/BN, (M+BM-1)/BM, batch);
    gemm_batched_sm120<<<grid,blk,0,s>>>(A,B,C,M,N,K);
}

// ───────────────────────────── bench main ──────────────────────────────
static void fill(float* x, long long n, unsigned seed){
    for(long long i=0;i<n;i++){ unsigned h=(unsigned)(i*2654435761u)^seed; x[i]=((h&0xffff)/65535.f-0.5f)*0.2f; }
}

// FP64 reference (one batch slab) for rel-RMS — host, K-major.
static void ref_fp64(const float* A,const float* B,double* C,int M,int N,int K){
    for(int i=0;i<M;i++)for(int j=0;j<N;j++){ double acc=0;
        for(int k=0;k<K;k++) acc += (double)A[(long long)i*K+k]*(double)B[(long long)k*N+j];
        C[(long long)i*N+j]=acc; }
}

int main(int argc,char**argv){
    int S     = argc>1?atoi(argv[1]):1024;
    int batch = argc>2?atoi(argv[2]):8;
    int MODE  = argc>3?atoi(argv[3]):1;   // 0 gate(rel-RMS+byteeq), 1 perf
    int M=S,N=S,K=S;
    long long pA=(long long)M*K, pB=(long long)K*N, pC=(long long)M*N;
    long long tA=pA*batch, tB=pB*batch, tC=pC*batch;

    float *hA=(float*)malloc(tA*4),*hB=(float*)malloc(tB*4);
    fill(hA,tA,11); fill(hB,tB,22);
    float *dA,*dB,*dOwn,*dRef;
    CK(cudaMalloc(&dA,tA*4)); CK(cudaMalloc(&dB,tB*4));
    CK(cudaMalloc(&dOwn,tC*4)); CK(cudaMalloc(&dRef,tC*4));
    CK(cudaMemcpy(dA,hA,tA*4,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB,hB,tB*4,cudaMemcpyHostToDevice));

    cublasHandle_t cb; CB(cublasCreate(&cb));
    const float alpha=1.f, beta=0.f;
    cudaEvent_t e0,e1; CK(cudaEventCreate(&e0)); CK(cudaEventCreate(&e1));
    const int ITER=20, WARM=5;
    double gflop = 2.0*(double)M*N*K*batch/1e9;

    // row-major C = A@B  ==  cublas col-major C^T = B^T A^T
    //   cublas(N,N, m=N, n=M, k=K, B(ldb=N,strideB=K*N), A(lda=K,strideA=M*K),
    //          C(ldc=N,strideC=M*N))
    // ── PREREQ baseline: stock cublasSgemmStridedBatched (true FP32) ──
    auto run_sgemm = [&](){
        CB(cublasSgemmStridedBatched(cb, CUBLAS_OP_N, CUBLAS_OP_N,
            N, M, K, &alpha,
            dB, N, (long long)K*N,
            dA, K, (long long)M*K,
            &beta, dRef, N, (long long)M*N, batch)); };
    // ── apples-to-apples TF32 batched reference (same math as own) ──
    auto run_tf32 = [&](){
        CB(cublasGemmStridedBatchedEx(cb, CUBLAS_OP_N, CUBLAS_OP_N,
            N, M, K, &alpha,
            dB, CUDA_R_32F, N, (long long)K*N,
            dA, CUDA_R_32F, K, (long long)M*K,
            &beta, dRef, CUDA_R_32F, N, (long long)M*N, batch,
            CUBLAS_COMPUTE_32F_FAST_TF32, CUBLAS_GEMM_DEFAULT_TENSOR_OP)); };
    auto run_own = [&](){ owngemm_batched_sm120(dOwn,dA,dB,M,K,N,batch,0); };

    auto timeit = [&](void(*nop)(), auto&& fn)->double{
        for(int i=0;i<WARM;i++) fn();
        CK(cudaDeviceSynchronize());
        CK(cudaEventRecord(e0));
        for(int i=0;i<ITER;i++) fn();
        CK(cudaEventRecord(e1)); CK(cudaEventSynchronize(e1));
        float ms=0; CK(cudaEventElapsedTime(&ms,e0,e1));
        return gflop/((ms/ITER)/1e3);
    };

    // SGEMM baseline
    CB(cublasSetMathMode(cb, CUBLAS_DEFAULT_MATH));
    double gf_sgemm;
    { for(int i=0;i<WARM;i++) run_sgemm(); CK(cudaDeviceSynchronize());
      CK(cudaEventRecord(e0)); for(int i=0;i<ITER;i++) run_sgemm();
      CK(cudaEventRecord(e1)); CK(cudaEventSynchronize(e1));
      float ms=0; CK(cudaEventElapsedTime(&ms,e0,e1)); gf_sgemm=gflop/((ms/ITER)/1e3); }

    // TF32 batched reference
    CB(cublasSetMathMode(cb, CUBLAS_TF32_TENSOR_OP_MATH));
    double gf_tf32;
    { for(int i=0;i<WARM;i++) run_tf32(); CK(cudaDeviceSynchronize());
      CK(cudaEventRecord(e0)); for(int i=0;i<ITER;i++) run_tf32();
      CK(cudaEventRecord(e1)); CK(cudaEventSynchronize(e1));
      float ms=0; CK(cudaEventElapsedTime(&ms,e0,e1)); gf_tf32=gflop/((ms/ITER)/1e3); }

    // OWN
    run_own(); cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){ printf("OWN FAULT: %s\n",cudaGetErrorString(e)); return 4; }
    double gf_own;
    { for(int i=0;i<WARM;i++) run_own(); CK(cudaDeviceSynchronize());
      CK(cudaEventRecord(e0)); for(int i=0;i<ITER;i++) run_own();
      CK(cudaEventRecord(e1)); CK(cudaEventSynchronize(e1));
      float ms=0; CK(cudaEventElapsedTime(&ms,e0,e1)); gf_own=gflop/((ms/ITER)/1e3); }

    printf("[PERF] S=%d batch=%d  cuBLAS-Sgemm=%.1f GF/s  cuBLAS-TF32=%.1f GF/s  OWN-TF32=%.1f GF/s  | own/Sgemm=%.3fx own/TF32=%.3fx\n",
           S,batch,gf_sgemm,gf_tf32,gf_own, gf_own/gf_sgemm, gf_own/gf_tf32);

    if(MODE==0){
        // rel-RMS vs FP64 (batch 0 slab) + run-to-run byte-eq
        run_tf32(); CK(cudaDeviceSynchronize());
        run_own();  CK(cudaDeviceSynchronize());
        float* hOwn=(float*)malloc(pC*4);
        CK(cudaMemcpy(hOwn,dOwn,pC*4,cudaMemcpyDeviceToHost));
        double* hRef=(double*)malloc(pC*8);
        ref_fp64(hA,hB,hRef,M,N,K);
        double se=0,sr=0,maxd=0;
        for(long long i=0;i<pC;i++){ double a=hOwn[i],b=hRef[i],dd=a-b; se+=dd*dd; sr+=b*b; if(fabs(dd)>maxd)maxd=fabs(dd); }
        double relrms = sr>0? sqrt(se/pC)/sqrt(sr/pC):0;
        // byte-eq: re-run own into a fresh buffer, memcmp the whole batched C
        float *dOwn2; CK(cudaMalloc(&dOwn2,tC*4));
        owngemm_batched_sm120(dOwn2,dA,dB,M,K,N,batch,0); CK(cudaDeviceSynchronize());
        owngemm_batched_sm120(dOwn,dA,dB,M,K,N,batch,0);  CK(cudaDeviceSynchronize());
        float *hC1=(float*)malloc(tC*4),*hC2=(float*)malloc(tC*4);
        CK(cudaMemcpy(hC1,dOwn,tC*4,cudaMemcpyDeviceToHost));
        CK(cudaMemcpy(hC2,dOwn2,tC*4,cudaMemcpyDeviceToHost));
        int byteeq = memcmp(hC1,hC2,(size_t)tC*4)==0;
        printf("[GATE] S=%d batch=%d  rel-RMS(own vs FP64)=%.3e  max|d|=%.3e  byte-eq(run2run)=%s\n",
               S,batch,relrms,maxd, byteeq?"YES(max|d|=0)":"NO");
    }
    return 0;
}
