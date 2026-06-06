// hexa-cuda dojo kata — CUDA .cu CONTRAST (NOT the production path)
// slug: vec-add  ·  kata: vec-add
//
// Side-by-side reference of the SAME kata in CUDA C++. The hexa
// kernel.hexa is the production surface; this .cu shows the 1:1
// intrinsic mapping (gpu/SPEC.md §5 table): threadIdx.x →
// gpu_thread_id_x(), __syncthreads() → gpu_barrier(), atomicAdd →
// gpu_atomic_add, __shared__ → @shared let. Compile contrast only:
//   nvcc -arch=sm_90 kernel.cu -o kernel_cu
#include <cstdio>

__global__ void vadd(const double* a, const double* b, double* c, long n) {
    long gid = blockIdx.x * blockDim.x + threadIdx.x;
    if (gid < n) c[gid] = a[gid] + b[gid];
}
