// Reference cookbook step1: single-tile 16x16 WMMA, single warp, no K-loop.
// Matches hexa step1_single_tile.ptx shape (sm_80).
#include <mma.h>
using namespace nvcuda;
__global__ void wmma_16x16(const half* __restrict__ A, const half* __restrict__ B, float* __restrict__ C) {
    wmma::fragment<wmma::matrix_a, 16,16,16, half, wmma::row_major> a_frag;
    wmma::fragment<wmma::matrix_b, 16,16,16, half, wmma::col_major> b_frag;
    wmma::fragment<wmma::accumulator, 16,16,16, float> c_frag;
    wmma::fill_fragment(c_frag, 0.0f);
    wmma::load_matrix_sync(a_frag, A, 16);
    wmma::load_matrix_sync(b_frag, B, 16);
    wmma::mma_sync(c_frag, a_frag, b_frag, c_frag);
    wmma::store_matrix_sync(C, c_frag, 16, wmma::mem_row_major);
}
