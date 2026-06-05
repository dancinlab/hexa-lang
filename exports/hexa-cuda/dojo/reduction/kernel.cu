// hexa-cuda dojo kata — CUDA .cu CONTRAST (NOT the production path)
// slug: reduction  ·  kata: reduction
//
// Side-by-side reference of the SAME kata in CUDA C++. The hexa
// kernel.hexa is the production surface; this .cu shows the 1:1
// intrinsic mapping (gpu/SPEC.md §5 table): threadIdx.x →
// gpu_thread_id_x(), __syncthreads() → gpu_barrier(), atomicAdd →
// gpu_atomic_add, __shared__ → @shared let. Compile contrast only:
//   nvcc -arch=sm_90 kernel.cu -o kernel_cu
#include <cstdio>

__global__ void reduce_sum(const double* a, double* out, long n) {
    __shared__ double scratch[256];
    int tid = threadIdx.x;
    long gid = blockIdx.x * blockDim.x + threadIdx.x;
    scratch[tid] = (gid < n) ? a[gid] : 0.0;
    __syncthreads();
    for (int s = blockDim.x / 2; s > 0; s >>= 1) {
        if (tid < s) scratch[tid] += scratch[tid + s];
        __syncthreads();
    }
    if (tid == 0) atomicAdd(out, scratch[0]);
}
