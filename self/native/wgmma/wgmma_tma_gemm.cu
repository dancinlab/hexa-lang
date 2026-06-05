// wgmma_tma_gemm.cu — Stage 2-4 of F-FUSION-SM90-WGMMA-TMA.
//
// A standalone CUTLASS-3.x-class own-source GEMM for native sm_90 H100:
//   - TMA (cp.async.bulk.tensor.2d) global->shared bulk loads driven by
//     cuTensorMapEncodeTiled descriptors + mbarrier (Stage 2),
//   - wgmma.mma_async warpgroup async tensor-core mainloop over the TMA-fed
//     shared tiles, register accumulators per warpgroup (Stage 3),
//   - measured vs cuBLAS-TF32 on a square problem (Stage 4).
//
// This is the residual lever named by F-FUSION-SM90-CUBLAS-MAINLOOP: the
// mma.sync CB mainloop hit 11.55 TFLOP/s = 29.4x off cuBLAS because mma.sync is
// a warp-level class; wgmma+TMA is the warpgroup-async class cuBLAS uses to
// reach Hopper TC peak. Goal = pin how far own-source closes that 29.4x gap.
//
// Precision: TF32 inputs (rounded via cvt.rna.tf32.f32 in the TMA->shared path
// is not possible — TMA copies bytes; we round on the host into a tf32-as-fp32
// staging buffer so the shared tile holds tf32-rounded fp32, matching the
// wgmma .tf32 operand). rel-RMS bar = 3e-3 vs cuBLAS-TF32.
//
// Build (on native sm_90 H100, nvcc 12.x):
//   nvcc -O3 -arch=sm_90a -lcublas -o wgmma_tma_gemm wgmma_tma_gemm.cu
//
// Run:   ./wgmma_tma_gemm [N]   (default N=2048, square)
//
// Honest framing: parity-seeking. cuBLAS is the roofline; no superiority claim.
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cuda_runtime.h>
#include <cublas_v2.h>

#define CK(x) do{ cudaError_t e=(x); if(e!=cudaSuccess){ \
  printf("CUDA-ERR %s @%d: %s\n", #x, __LINE__, cudaGetErrorString(e)); exit(3);} }while(0)
#define CB(x) do{ cublasStatus_t s=(x); if(s!=CUBLAS_STATUS_SUCCESS){ \
  printf("CUBLAS-ERR %s @%d: %d\n", #x, __LINE__, (int)s); exit(3);} }while(0)

// ============================ Tile geometry =================================
// Block computes a BM x BN output tile. One CTA = one warpgroup (128 threads)
// for the minimal correct mainloop. BK is the K-step staged by TMA.
//   wgmma.m64nNk8.f32.tf32.tf32 : M-tile is fixed 64, N-tile up to 256, K=8.
// We use BM=64, BN=128, BK=32 (4 wgmma K-substeps of 8 per staged slice).
#define BM 64
#define BN 128
#define BK 32
#define WG_THREADS 128          // one warpgroup
#define NSTAGES 3               // TMA software pipeline depth

// ===================== wgmma shared descriptor =============================
__device__ __forceinline__ uint64_t make_desc(const void* p, uint32_t lbo, uint32_t sbo) {
    uint32_t a = (uint32_t)__cvta_generic_to_shared(const_cast<void*>(p));
    uint64_t d = 0;
    d |= (uint64_t)((a & 0x3FFFF) >> 4);
    d |= ((uint64_t)((lbo >> 4) & 0x3FFF)) << 16;
    d |= ((uint64_t)((sbo >> 4) & 0x3FFF)) << 32;
    return d;   // swizzle=0, base=0
}

// ===================== mbarrier + TMA helpers ==============================
__device__ __forceinline__ void mbar_init(uint64_t* bar, int count) {
    uint32_t s = (uint32_t)__cvta_generic_to_shared(bar);
    asm volatile("mbarrier.init.shared.b64 [%0], %1;\n" :: "r"(s), "r"(count));
}
__device__ __forceinline__ void mbar_expect_tx(uint64_t* bar, uint32_t bytes) {
    uint32_t s = (uint32_t)__cvta_generic_to_shared(bar);
    asm volatile("mbarrier.arrive.expect_tx.shared.b64 _, [%0], %1;\n" :: "r"(s), "r"(bytes));
}
__device__ __forceinline__ bool mbar_try_wait(uint64_t* bar, uint32_t phase) {
    uint32_t s = (uint32_t)__cvta_generic_to_shared(bar);
    uint32_t ok;
    asm volatile(
        "{\n .reg .pred p;\n"
        " mbarrier.try_wait.parity.shared.b64 p, [%1], %2;\n"
        " selp.b32 %0, 1, 0, p;\n}\n"
        : "=r"(ok) : "r"(s), "r"(phase));
    return ok;
}
// 2D TMA bulk load: gmem tensor (described by the tensor map) -> shared, with
// the completion tracked by the mbarrier (expect_tx the byte count).
__device__ __forceinline__ void tma_load_2d(void* dst_smem, const void* tmap,
                                             int32_t x, int32_t y, uint64_t* bar) {
    uint32_t d = (uint32_t)__cvta_generic_to_shared(dst_smem);
    uint32_t b = (uint32_t)__cvta_generic_to_shared(bar);
    asm volatile(
        "cp.async.bulk.tensor.2d.shared::cluster.global.mbarrier::complete_tx::bytes"
        " [%0], [%1, {%2, %3}], [%4];\n"
        :: "r"(d), "l"(tmap), "r"(x), "r"(y), "r"(b) : "memory");
}

// ============================ wgmma mainloop kernel =========================
// A is MxK row-major (tf32-rounded fp32), B is KxN row-major. TMA tiles:
//   A tile = BM x BK, B tile = BK x BN. Both staged NSTAGES deep.
// C is row-major MxN (this standalone uses row-major for clarity; the in-tree
// integration uses the col-major cublasSgemm contract).
extern "C" __global__ void __launch_bounds__(WG_THREADS)
wgmma_tma_kernel(const __grid_constant__ CUtensorMap tmapA,
                 const __grid_constant__ CUtensorMap tmapB,
                 float* C, int M, int N, int K) {
    extern __shared__ __align__(128) uint8_t smem_raw[];
    // Layout: As[NSTAGES][BM*BK], Bs[NSTAGES][BK*BN], then mbarriers.
    float* As = reinterpret_cast<float*>(smem_raw);
    float* Bs = As + NSTAGES * BM * BK;
    uint64_t* barA = reinterpret_cast<uint64_t*>(Bs + NSTAGES * BK * BN);
    uint64_t* barB = barA + NSTAGES;

    const int tid = threadIdx.x;
    const int tileM = blockIdx.y * BM;
    const int tileN = blockIdx.x * BN;

    if (tid == 0) {
        for (int s = 0; s < NSTAGES; ++s) { mbar_init(&barA[s], 1); mbar_init(&barB[s], 1); }
    }
    __syncthreads();

    const uint32_t bytesA = BM * BK * sizeof(float);
    const uint32_t bytesB = BK * BN * sizeof(float);
    const int nK = (K + BK - 1) / BK;

    // Accumulators: wgmma.m64n128k8 => 64 f32 per thread (N/2 = 64).
    float acc[64];
    #pragma unroll
    for (int i = 0; i < 64; ++i) acc[i] = 0.f;

    // ---- Prologue: kick off the first NSTAGES TMA loads (leader thread) ----
    int phaseA[NSTAGES] = {0}, phaseB[NSTAGES] = {0};
    auto issue = [&](int s, int kk) {
        if (tid == 0) {
            mbar_expect_tx(&barA[s], bytesA);
            tma_load_2d(&As[s*BM*BK], &tmapA, /*x=*/kk, /*y=*/tileM, &barA[s]);
            mbar_expect_tx(&barB[s], bytesB);
            tma_load_2d(&Bs[s*BK*BN], &tmapB, /*x=*/tileN, /*y=*/kk, &barB[s]);
        }
    };
    int kk = 0, fill = 0;
    for (; fill < NSTAGES && fill < nK; ++fill) { issue(fill, kk); kk += BK; }

    // ---- Mainloop: consume staged tile, issue next, wgmma over BK in 8-steps -
    for (int kit = 0; kit < nK; ++kit) {
        int s = kit % NSTAGES;
        // wait for both A and B of this stage
        while (!mbar_try_wait(&barA[s], phaseA[s])) {}
        while (!mbar_try_wait(&barB[s], phaseB[s])) {}
        phaseA[s] ^= 1; phaseB[s] ^= 1;
        __syncthreads();

        // wgmma over the BK slice in K=8 substeps.
        asm volatile("wgmma.fence.sync.aligned;\n" ::: "memory");
        #pragma unroll
        for (int kf = 0; kf < BK/8; ++kf) {
            uint64_t dA = make_desc(&As[s*BM*BK + kf*8], 16, BM*8*4);
            uint64_t dB = make_desc(&Bs[s*BK*BN + kf*8*BN], 16, 8*BN*4);
            // m64n128k8 : 64 accumulators.
            asm volatile(
              "wgmma.mma_async.sync.aligned.m64n128k8.f32.tf32.tf32 "
              "{%0,%1,%2,%3,%4,%5,%6,%7,%8,%9,%10,%11,%12,%13,%14,%15,"
              "%16,%17,%18,%19,%20,%21,%22,%23,%24,%25,%26,%27,%28,%29,%30,%31,"
              "%32,%33,%34,%35,%36,%37,%38,%39,%40,%41,%42,%43,%44,%45,%46,%47,"
              "%48,%49,%50,%51,%52,%53,%54,%55,%56,%57,%58,%59,%60,%61,%62,%63}, "
              "%64, %65, 1, 1, 1;\n"   // tf32: scaleD,scaleA,scaleB only (no transpose imms)
              : "+f"(acc[0]),"+f"(acc[1]),"+f"(acc[2]),"+f"(acc[3]),"+f"(acc[4]),"+f"(acc[5]),"+f"(acc[6]),"+f"(acc[7]),
                "+f"(acc[8]),"+f"(acc[9]),"+f"(acc[10]),"+f"(acc[11]),"+f"(acc[12]),"+f"(acc[13]),"+f"(acc[14]),"+f"(acc[15]),
                "+f"(acc[16]),"+f"(acc[17]),"+f"(acc[18]),"+f"(acc[19]),"+f"(acc[20]),"+f"(acc[21]),"+f"(acc[22]),"+f"(acc[23]),
                "+f"(acc[24]),"+f"(acc[25]),"+f"(acc[26]),"+f"(acc[27]),"+f"(acc[28]),"+f"(acc[29]),"+f"(acc[30]),"+f"(acc[31]),
                "+f"(acc[32]),"+f"(acc[33]),"+f"(acc[34]),"+f"(acc[35]),"+f"(acc[36]),"+f"(acc[37]),"+f"(acc[38]),"+f"(acc[39]),
                "+f"(acc[40]),"+f"(acc[41]),"+f"(acc[42]),"+f"(acc[43]),"+f"(acc[44]),"+f"(acc[45]),"+f"(acc[46]),"+f"(acc[47]),
                "+f"(acc[48]),"+f"(acc[49]),"+f"(acc[50]),"+f"(acc[51]),"+f"(acc[52]),"+f"(acc[53]),"+f"(acc[54]),"+f"(acc[55]),
                "+f"(acc[56]),"+f"(acc[57]),"+f"(acc[58]),"+f"(acc[59]),"+f"(acc[60]),"+f"(acc[61]),"+f"(acc[62]),"+f"(acc[63])
              : "l"(dA), "l"(dB));
        }
        asm volatile("wgmma.commit_group.sync.aligned;\n" ::: "memory");
        asm volatile("wgmma.wait_group.sync.aligned 0;\n" ::: "memory");

        // issue the next stage's TMA (ring)
        if (kk < K) { issue(s, kk); kk += BK; }
        __syncthreads();
    }

    // ---- Epilogue: canonical m64n128 D-reg -> C[row,col] (row-major) -------
    int warp = tid >> 5, lane = tid & 31;
    int row_base = warp * 16 + (lane >> 2);
    int col_base = (lane & 3) * 2;
    #pragma unroll
    for (int c = 0; c < 16; ++c) {       // 16 column octets for N=128
        #pragma unroll
        for (int r = 0; r < 2; ++r) {
            #pragma unroll
            for (int p = 0; p < 2; ++p) {
                int idx = c * 4 + r * 2 + p;
                int row = tileM + row_base + r * 8;
                int col = tileN + col_base + p + c * 8;
                if (row < M && col < N) C[(long)row * N + col] = acc[idx];
            }
        }
    }
}

// ===================== TMA tensor map (host) ===============================
// Encodes a 2D tiled tensor map. CUDA driver entry; declared here to avoid a
// hard dep on the exact header version.
typedef CUresult (*EncTiled_t)(CUtensorMap*, CUtensorMapDataType, cuuint32_t,
    void*, const cuuint64_t*, const cuuint64_t*, const cuuint32_t*, const cuuint32_t*,
    CUtensorMapInterleave, CUtensorMapSwizzle, CUtensorMapL2promotion, CUtensorMapFloatOOBfill);

static EncTiled_t get_encode() {
    void* fn = nullptr;
    // CUDA 12.x: cuGetProcAddress for cuTensorMapEncodeTiled.
    cudaDriverEntryPointQueryResult q;
    cudaGetDriverEntryPoint("cuTensorMapEncodeTiled", &fn, cudaEnableDefault, &q);
    return reinterpret_cast<EncTiled_t>(fn);
}

static inline float tf32r(float x) {
    uint32_t u; memcpy(&u,&x,4); u=(u+0x1000u)&0xFFFFE000u; float r; memcpy(&r,&u,4); return r;
}

int main(int argc, char** argv) {
    int Nsq = (argc > 1) ? atoi(argv[1]) : 2048;
    int M=Nsq, N=Nsq, K=Nsq;
    printf("== wgmma+TMA own-GEMM probe == M=N=K=%d (TF32)\n", M);

    size_t szA=(size_t)M*K, szB=(size_t)K*N, szC=(size_t)M*N;
    float *hA=new float[szA], *hB=new float[szB];
    srand(7);
    for (size_t i=0;i<szA;++i) hA[i]=tf32r(((rand()%2001)-1000)/1000.0f);
    for (size_t i=0;i<szB;++i) hB[i]=tf32r(((rand()%2001)-1000)/1000.0f);

    float *dA,*dB,*dC,*dCref;
    CK(cudaMalloc(&dA,szA*4)); CK(cudaMalloc(&dB,szB*4));
    CK(cudaMalloc(&dC,szC*4)); CK(cudaMalloc(&dCref,szC*4));
    CK(cudaMemcpy(dA,hA,szA*4,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB,hB,szB*4,cudaMemcpyHostToDevice));

    // ---- TMA tensor maps for A (MxK) and B (KxN), row-major ----
    EncTiled_t enc = get_encode();
    if (!enc) { printf("WGMMA_TMA: FAIL — cuTensorMapEncodeTiled unavailable (CUDA<12.0?)\n"); return 4; }
    CUtensorMap tmapA{}, tmapB{};
    // A: global dims {K, M} (fastest=K), tile {BK, BM}.
    {
        cuuint64_t gdim[2]={(cuuint64_t)K,(cuuint64_t)M};
        cuuint64_t gstr[1]={(cuuint64_t)K*4};
        cuuint32_t bdim[2]={BK,BM}; cuuint32_t estr[2]={1,1};
        CUresult r=enc(&tmapA,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dA,gdim,gstr,bdim,estr,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_NONE,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
        if(r!=CUDA_SUCCESS){printf("WGMMA_TMA: FAIL — encodeA r=%d\n",(int)r);return 4;}
    }
    {
        cuuint64_t gdim[2]={(cuuint64_t)N,(cuuint64_t)K};
        cuuint64_t gstr[1]={(cuuint64_t)N*4};
        cuuint32_t bdim[2]={BN,BK}; cuuint32_t estr[2]={1,1};
        CUresult r=enc(&tmapB,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dB,gdim,gstr,bdim,estr,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_NONE,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
        if(r!=CUDA_SUCCESS){printf("WGMMA_TMA: FAIL — encodeB r=%d\n",(int)r);return 4;}
    }

    size_t smem = (size_t)NSTAGES*(BM*BK + BK*BN)*4 + 2*NSTAGES*sizeof(uint64_t);
    CK(cudaFuncSetAttribute(wgmma_tma_kernel, cudaFuncAttributeMaxDynamicSharedMemorySize, (int)smem));
    dim3 grid(N/BN, M/BM), block(WG_THREADS);

    // ---- cuBLAS-TF32 oracle + timing baseline ----
    cublasHandle_t h; CB(cublasCreate(&h));
    CB(cublasSetMathMode(h, CUBLAS_TF32_TENSOR_OP_MATH));
    float alpha=1.f, beta=0.f;
    // row-major C = A*B  ==  col-major: C^T = B^T*A^T ; compute via swapped args.
    CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha, dB, N, dA, K, &beta, dCref, N));
    CK(cudaDeviceSynchronize());

    // correctness
    CK(cudaMemset(dC,0,szC*4));
    wgmma_tma_kernel<<<grid,block,smem>>>(tmapA,tmapB,dC,M,N,K);
    cudaError_t le=cudaGetLastError();
    if(le!=cudaSuccess){printf("WGMMA_TMA: FAIL — launch %s\n",cudaGetErrorString(le));return 5;}
    CK(cudaDeviceSynchronize());

    float *hC=new float[szC], *hR=new float[szC];
    CK(cudaMemcpy(hC,dC,szC*4,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hR,dCref,szC*4,cudaMemcpyDeviceToHost));
    double se=0,sr=0; long nz=0;
    for(size_t i=0;i<szC;++i){double e=(double)hC[i]-hR[i]; se+=e*e; sr+=(double)hR[i]*hR[i]; if(hC[i]!=0.f)++nz;}
    double relrms=sqrt(se/fmax(1e-12,sr));
    printf("CORRECTNESS nonzero=%ld/%zu rel_rms=%.3e (bar 3e-3)\n", nz, szC, relrms);
    int correct = (nz > (long)szC*3/4) && (relrms <= 3e-3);

    // ---- timing (only meaningful if correct) ----
    auto timeit=[&](auto fn)->double{
        cudaEvent_t a,b; cudaEventCreate(&a); cudaEventCreate(&b);
        for(int w=0;w<5;++w) fn();
        CK(cudaDeviceSynchronize());
        cudaEventRecord(a);
        int it=20; for(int i=0;i<it;++i) fn();
        cudaEventRecord(b); cudaEventSynchronize(b);
        float ms=0; cudaEventElapsedTime(&ms,a,b); return ms/it;
    };
    double flops = 2.0*M*N*K;
    double own_ms = timeit([&]{ wgmma_tma_kernel<<<grid,block,smem>>>(tmapA,tmapB,dC,M,N,K); });
    double cub_ms = timeit([&]{ cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,N,M,K,&alpha,dB,N,dA,K,&beta,dCref,N); });
    double own_tf = flops/(own_ms*1e-3)/1e12;
    double cub_tf = flops/(cub_ms*1e-3)/1e12;

    printf("OWN   %.3f ms  %.2f TFLOP/s\n", own_ms, own_tf);
    printf("CUBLAS %.3f ms  %.2f TFLOP/s\n", cub_ms, cub_tf);
    printf("RATIO cublas/own = %.2fx\n", own_tf>0?cub_tf/own_tf:0);
    printf("WGMMA_TMA: %s\n", correct ? "PASS" : "FAIL");
    return correct ? 0 : 2;
}
