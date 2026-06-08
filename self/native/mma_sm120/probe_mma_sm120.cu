// probe_mma_sm120.cu — HEXA-BENCH BENCH-5 ISA probe.
//
// Probes which TF32 tensor-core MMA instruction families ptxas ACCEPTS for
// -arch=sm_120 (consumer Blackwell, RTX 5070, cc12.0) on aiden's CUDA 13.0.88.
//
// Each candidate is gated behind a -D macro so a single ptxas pass per family
// tells us Y/N. The build script (build_probe.sh) compiles once per macro and
// greps the ptxas error.
//
//   -DTRY_MMA_SYNC    mma.sync.aligned.m16n8k8.row.col.f32.tf32.tf32.f32
//                     (Ampere+ warp-level TF32 MMA — the portable fallback,
//                      expected to assemble on sm_120)
//   -DTRY_TCGEN05     tcgen05.mma / tcgen05.ld (Blackwell 5th-gen tensor cores,
//                      bleeding-edge PTX — may not be in CUDA 13.0.88 ptxas)
//   -DTRY_WGMMA       wgmma.mma_async.sync.aligned.m64n8k8.f32.tf32.tf32
//                     (Hopper sm_90a warpgroup MMA — expected REJECTED on sm_120;
//                      this is the BENCH-3 ISA-gap confirmation)
//
// We don't need correctness here — just "does ptxas emit SASS or reject".

#include <cstdint>
#include <cstdio>
#include <cuda_runtime.h>

#ifdef TRY_MMA_SYNC
__global__ void probe(const float* A, const float* B, float* D){
    // Ampere+ warp-level TF32 MMA. 32-thread warp. m16n8k8.
    // A = 4 tf32 regs, B = 2 tf32 regs, C/D = 4 f32 regs.
    unsigned a0,a1,a2,a3,b0,b1;
    a0=__float_as_uint(A[0]); a1=__float_as_uint(A[1]);
    a2=__float_as_uint(A[2]); a3=__float_as_uint(A[3]);
    b0=__float_as_uint(B[0]); b1=__float_as_uint(B[1]);
    float d0=0,d1=0,d2=0,d3=0;
    asm volatile(
      "mma.sync.aligned.m16n8k8.row.col.f32.tf32.tf32.f32 "
      "{%0,%1,%2,%3}, {%4,%5,%6,%7}, {%8,%9}, {%0,%1,%2,%3};\n"
      : "+f"(d0),"+f"(d1),"+f"(d2),"+f"(d3)
      : "r"(a0),"r"(a1),"r"(a2),"r"(a3),"r"(b0),"r"(b1));
    D[threadIdx.x] = d0+d1+d2+d3;
}
#endif

#ifdef TRY_WGMMA
__global__ void probe(const float* A, const float* B, float* D){
    // Hopper warpgroup async MMA — expected to be rejected on sm_120.
    float d[2]={0,0};
    uint64_t descA=0, descB=0;
    asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
    asm volatile(
      "wgmma.mma_async.sync.aligned.m64n8k8.f32.tf32.tf32 "
      "{%0,%1}, %2, %3, 1,1,1;\n"
      : "+f"(d[0]),"+f"(d[1]) : "l"(descA),"l"(descB));
    asm volatile("wgmma.commit_group.sync.aligned;\n":::"memory");
    asm volatile("wgmma.wait_group.sync.aligned 0;\n":::"memory");
    D[threadIdx.x]=d[0]+d[1];
}
#endif

#ifdef TRY_TCGEN05
__global__ void probe(const float* A, const float* B, float* D){
    // Blackwell 5th-gen tensor-core tcgen05 family (bleeding-edge). We probe the
    // simplest form the SASS encoder might accept; exact operand encoding varies.
    uint32_t taddr=0; uint64_t idesc=0;
    asm volatile(
      "tcgen05.mma.cta_group::1.kind::tf32 [%0], %1, %2, %3;\n"
      :: "r"(taddr),"r"(0u),"r"(0u),"l"(idesc) : "memory");
    D[threadIdx.x]=A[0]+B[0];
}
#endif

int main(){ printf("probe TU compiled+linked OK\n"); return 0; }
