// og10_gemm_wrap.cu — HEXA-BENCH BENCH-4 OG10 own-GEMM backend (sm_90a Hopper).
//
// Wraps the HEXA-FUSION W10 TF32-wgmma own-GEMM (self/native/wgmma/wgmma_tf32_w10_lib.h,
// the #2847 frontier kernel `gemm_w10`, ~70.7 TFLOP/s @2048, bit-exact vs cuBLAS-TF32,
// 6.09x off cuBLAS) into the pluggable backend the BENCH-3 harness expects:
//
//     extern void og10_gemm(real* C, const real* A, const real* Bm, int M, int K, int N);
//
// computing C[M,N] = A[M,K] @ B[K,N], row-major, TF32. This is the REAL OG10 number that
// BENCH-3 could only PROXY with cuBLAS-TF32 (sm_120 rejected the wgmma ISA).
//
// W10 MODE-4 launch contract (the proven path): swizzled-TMA A box{32(K),128(M)} +
// B box{32(N),32(K)}, SWIZZLE_128B, composed-decode read, m64n64k8 wgmma. Shape
// constraints: N%128==0 && K%32==0 (the bench shapes D=768, M=B*256 all satisfy this;
// fwd  H = A[M,768]@W[768,768]; bwd dW = AT[768,M]@dG[M,768]). M is padded to a multiple
// of TM=128 by the grid (Mx+TM-1)/TM and OOB rows are guarded inside the kernel via the M
// bound. We TF32-truncate A and B in-place (same tf() the W10 gate uses) so the result is
// the actual OG10 TF32 math, bit-comparable to the harness's naive/cuBLAS lanes.
//
// Built ONLY for sm_90a (Hopper). On any other arch the wgmma ISA is rejected by ptxas
// and this TU is simply not compiled (the harness then uses GEMM_BACKEND 0/1).

#define W10_NO_MAIN 1
#include "wgmma_tf32_w10_lib.h"   // gemm_w10, enc/get_enc, tf, mbar/TMA helpers, WG macro

// TF32-truncate a device buffer in place (matches the W10 gate's host tf()).
__global__ void k_tf32_trunc(float* x, long long n){
    long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x;
    if(i<n){ unsigned u; float v=x[i]; memcpy(&u,&v,4); u=(u+0x1000u)&0xFFFFE000u; memcpy(&v,&u,4); x[i]=v; }
}

static Enc_t g_enc = nullptr;

extern "C" void og10_gemm(float* C, const float* A, const float* Bm, int M, int K, int N){
    if(!g_enc){ g_enc = get_enc();
        if(!g_enc){ printf("[OG10] cuTensorMapEncodeTiled unavailable (CUDA<12?)\n"); return; } }
    if(N%128 || K%32){ printf("[OG10] shape M=%d K=%d N=%d violates N%%128==0 && K%%32==0\n",M,K,N); return; }

    // TF32-truncate inputs in place (idempotent — tf() is a fixed-point round).
    {
        long long nA=(long long)M*K, nB=(long long)K*N;
        k_tf32_trunc<<<(nA+255)/256,256>>>((float*)A,nA);
        k_tf32_trunc<<<(nB+255)/256,256>>>((float*)Bm,nB);
    }

    // Swizzled TMA descriptors — VERBATIM the W10 MODE-4 encode (A box 32K x128M, B box 32N x32K).
    CUtensorMap tmapA{}, tmapB{};
    { cuuint64_t gd[2]={(cuuint64_t)K,(cuuint64_t)M}; cuuint64_t gs[1]={(cuuint64_t)K*4};
      cuuint32_t bd[2]={32,128}; cuuint32_t es[2]={1,1};
      CUresult r=g_enc(&tmapA,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,(void*)A,gd,gs,bd,es,
        CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
        CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
      if(r!=CUDA_SUCCESS){ printf("[OG10] encodeA r=%d\n",(int)r); return; } }
    { cuuint64_t gd[2]={(cuuint64_t)N,(cuuint64_t)K}; cuuint64_t gs[1]={(cuuint64_t)N*4};
      cuuint32_t bd[2]={32,32}; cuuint32_t es[2]={1,1};
      CUresult r=g_enc(&tmapB,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,(void*)Bm,gd,gs,bd,es,
        CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
        CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
      if(r!=CUDA_SUCCESS){ printf("[OG10] encodeB r=%d\n",(int)r); return; } }

    const int TM=128,TN=128,TKSW=32;
    const int NST=3;                       // W10 frontier pipeline depth
    size_t SWBUF=(size_t)(TM*TKSW + TN*TKSW);
    size_t GMMA=(size_t)(2*64*TKSW + 2*TKSW*64);
    size_t smsz=(size_t)NST*SWBUF*4 + GMMA*4 + (size_t)2*NST*8;
    dim3 grid(N/128,(M+TM-1)/TM); int blk=256;
    static bool attr_set=false;
    if(!attr_set){ cudaFuncSetAttribute(gemm_w10,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz); attr_set=true; }
    cudaMemset(C,0,(size_t)M*N*4);
    gemm_w10<<<grid,blk,smsz>>>(tmapA,tmapB,C,M,N,K,NST);
}
