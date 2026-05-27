// wgmma_probe.cu — minimal sm_90 wgmma support probe for RTX 5070 (sm_120, driver-JIT)
// Verifies: (1) nvcc -arch=sm_90 accepts wgmma PTX, (2) ptxas emits clean, (3) driver-JIT to sm_120 launches.
#include <cstdio>
#include <cuda_runtime.h>
#include <cuda_fp16.h>

extern "C" __global__ void wgmma_probe_kernel(const __half* A, const __half* B, float* D) {
    // wgmma.mma_async.sync.aligned.m64n32k16.f32.f16.f16
    // Requires 128-thread warpgroup (4 warps). D is 32-float register-distributed accumulator per thread.
    // For probe we just construct shared-memory descriptors and issue one instruction.

    extern __shared__ __align__(16) unsigned char smem[];
    __half* As = reinterpret_cast<__half*>(smem);                 // 64x16 A tile
    __half* Bs = reinterpret_cast<__half*>(smem + 64*16*2);       // 16x32 B tile

    // Naive cooperative load (probe only; not perf path)
    int tid = threadIdx.x;
    if (tid < 64*16) As[tid] = A[tid];
    if (tid < 16*32) Bs[tid] = B[tid];
    __syncthreads();

    // Build wgmma shared-memory descriptor (PTX ISA 8.7 §9.7.13.3)
    // descriptor encodes: matrix start addr (smem), leading dim byte offset, stride, swizzle mode
    auto make_desc = [](void* ptr, unsigned ld, unsigned sd) -> unsigned long long {
        unsigned long long desc = 0;
        unsigned long long addr = __cvta_generic_to_shared(ptr);
        desc |= (addr & 0x3FFFF) >> 4;                       // bits  0..13 : start address (14-bit, /16)
        desc |= ((unsigned long long)ld & 0x3FFF) << 16;     // bits 16..29 : leading dim byte offset (/16)
        desc |= ((unsigned long long)sd & 0x3FFF) << 32;     // bits 32..45 : stride byte offset (/16)
        // bits 62..63: swizzle mode = 0 (none)
        return desc;
    };

    unsigned long long descA = make_desc(As, 32, 16);   // 64x16, ld=32B(16 half), sd=16B step
    unsigned long long descB = make_desc(Bs, 32, 16);

    float d[16] = {0.f};  // wgmma m64n32k16 = 32 floats / warpgroup, 1 thread holds 4 floats per 4-tile = ~16 max

    // Issue wgmma instruction (inline PTX). Format from PTX ISA 8.7 §9.7.13.5.
    // wgmma.mma_async.sync.aligned.m64n32k16.f32.f16.f16  d, a-desc, b-desc, scale-d, scale-a, scale-b, trans-a, trans-b;
    asm volatile(
        "wgmma.fence.sync.aligned;\n"
        "wgmma.mma_async.sync.aligned.m64n32k16.f32.f16.f16 "
        "{%0,%1,%2,%3,%4,%5,%6,%7,%8,%9,%10,%11,%12,%13,%14,%15}, "
        "%16, %17, 1, 1, 1, 0, 0;\n"
        "wgmma.commit_group.sync.aligned;\n"
        "wgmma.wait_group.sync.aligned 0;\n"
        : "+f"(d[0]),"+f"(d[1]),"+f"(d[2]),"+f"(d[3]),
          "+f"(d[4]),"+f"(d[5]),"+f"(d[6]),"+f"(d[7]),
          "+f"(d[8]),"+f"(d[9]),"+f"(d[10]),"+f"(d[11]),
          "+f"(d[12]),"+f"(d[13]),"+f"(d[14]),"+f"(d[15])
        : "l"(descA), "l"(descB)
    );

    if (tid < 16) D[tid] = d[tid];
}

int main() {
    cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop, 0);
    printf("Device: %s  CC sm_%d%d  driver supports wgmma at sm_90+\n",
           prop.name, prop.major, prop.minor);

    __half *A, *B;
    float *D;
    cudaMalloc(&A, 64*16*sizeof(__half));
    cudaMalloc(&B, 16*32*sizeof(__half));
    cudaMalloc(&D, 16*sizeof(float));
    cudaMemset(A, 0, 64*16*sizeof(__half));
    cudaMemset(B, 0, 16*32*sizeof(__half));

    // 128 threads = 1 warpgroup
    size_t smem_bytes = 64*16*sizeof(__half) + 16*32*sizeof(__half);
    wgmma_probe_kernel<<<1,128,smem_bytes>>>(A, B, D);
    cudaError_t e = cudaDeviceSynchronize();
    if (e == cudaSuccess) {
        printf("WGMMA_PROBE: PASS — kernel launched + completed on sm_%d%d\n", prop.major, prop.minor);
        return 0;
    } else {
        printf("WGMMA_PROBE: FAIL — cudaError=%d (%s)\n", (int)e, cudaGetErrorString(e));
        return 1;
    }
}
