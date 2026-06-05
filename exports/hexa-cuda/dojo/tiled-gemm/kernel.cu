// hexa-cuda dojo kata — CUDA .cu CONTRAST (NOT the production path)
// slug: tiled-gemm  ·  kata: tiled-gemm
//
// Side-by-side reference of the SAME kata in CUDA C++. The hexa
// kernel.hexa is the production surface; this .cu shows the 1:1
// intrinsic mapping (gpu/SPEC.md §5 table): threadIdx.x →
// gpu_thread_id_x(), __syncthreads() → gpu_barrier(), atomicAdd →
// gpu_atomic_add, __shared__ → @shared let. Compile contrast only:
//   nvcc -arch=sm_90 kernel.cu -o kernel_cu
#include <cstdio>

#define TILE 16
__global__ void gemm_tiled(const double* a, const double* b, double* c,
                           long m, long n, long k) {
    __shared__ double as_tile[TILE*TILE];
    __shared__ double bs_tile[TILE*TILE];
    long row = blockIdx.y * blockDim.y + threadIdx.y;
    long col = blockIdx.x * blockDim.x + threadIdx.x;
    double acc = 0.0;
    for (long t = 0; t < k; t += TILE) {
        if (row < m && t + threadIdx.x < k)
            as_tile[threadIdx.y*TILE+threadIdx.x] = a[row*k + t + threadIdx.x];
        if (t + threadIdx.y < k && col < n)
            bs_tile[threadIdx.y*TILE+threadIdx.x] = b[(t+threadIdx.y)*n + col];
        __syncthreads();
        for (int kk = 0; kk < TILE; kk++)
            acc += as_tile[threadIdx.y*TILE+kk] * bs_tile[kk*TILE+threadIdx.x];
        __syncthreads();
    }
    if (row < m && col < n) c[row*n+col] = acc;
}
