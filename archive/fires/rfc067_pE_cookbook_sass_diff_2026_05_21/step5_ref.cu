// Reference cookbook step5: TF32 WMMA single-tile.
// Matches hexa step5_tf32.ptx shape (sm_80).
// M=16 N=16 K=8, A row-major tf32, B col-major tf32, C f32 row-major, single warp.
// Mirrors the standard nvcc tf32_ref pattern (the very source of step5's PTX).
#include <mma.h>
using namespace nvcuda;
extern "C" __global__ void tf32_ref(const float* __restrict__ A,
                                     const float* __restrict__ B,
                                     float* __restrict__ C) {
    wmma::fragment<wmma::matrix_a, 16,16,8, wmma::precision::tf32, wmma::row_major> a_frag;
    wmma::fragment<wmma::matrix_b, 16,16,8, wmma::precision::tf32, wmma::col_major> b_frag;
    wmma::fragment<wmma::accumulator, 16,16,8, float> c_frag;
    wmma::fill_fragment(c_frag, 0.0f);
    wmma::load_matrix_sync(a_frag, A, 16);
    wmma::load_matrix_sync(b_frag, B, 16);
    // tf32 fragments must be rounded prior to mma.
    #pragma unroll
    for (int i = 0; i < a_frag.num_elements; ++i) {
        a_frag.x[i] = wmma::__float_to_tf32(a_frag.x[i]);
    }
    #pragma unroll
    for (int i = 0; i < b_frag.num_elements; ++i) {
        b_frag.x[i] = wmma::__float_to_tf32(b_frag.x[i]);
    }
    wmma::mma_sync(c_frag, a_frag, b_frag, c_frag);
    wmma::store_matrix_sync(C, c_frag, 16, wmma::mem_row_major);
}
