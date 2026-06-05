// hexa-cuda dojo kata — CUDA .cu CONTRAST (NOT the production path)
// slug: wmma  ·  kata: wmma
//
// Side-by-side reference of the SAME kata in CUDA C++. The hexa
// kernel.hexa is the production surface; this .cu shows the 1:1
// intrinsic mapping (gpu/SPEC.md §5 table): threadIdx.x →
// gpu_thread_id_x(), __syncthreads() → gpu_barrier(), atomicAdd →
// gpu_atomic_add, __shared__ → @shared let. Compile contrast only:
//   nvcc -arch=sm_90 kernel.cu -o kernel_cu
#include <cstdio>

#include <mma.h>
using namespace nvcuda::wmma;
// 16x16x16 Tensor-Core tile MMA (half x half -> float accumulator).
__global__ void wmma_tile(const half* a, const half* b, float* c) {
    fragment<matrix_a, 16,16,16, half, row_major> fa;
    fragment<matrix_b, 16,16,16, half, col_major> fb;
    fragment<accumulator, 16,16,16, float> fc;
    fill_fragment(fc, 0.0f);
    load_matrix_sync(fa, a, 16);
    load_matrix_sync(fb, b, 16);
    mma_sync(fc, fa, fb, fc);
    store_matrix_sync(c, fc, 16, mem_row_major);
}
