// Reference cookbook step2: multitile WMMA K-loop, single warp, M=16 N=16 K_TOTAL=64.
// Matches hexa step2_multitile.ptx shape (sm_90). K_TILES = 4 iters of 16-K each.
// A row-major [16x64], stride K_TOTAL=64.  B col-major [64x16], stride K_TOTAL=64.
// C f32 row-major [16x16], stride 16.
#include <mma.h>
using namespace nvcuda;
extern "C" __global__ void wmma_multitile(const half* __restrict__ A,
                                          const half* __restrict__ B,
                                          float* __restrict__ C,
                                          int k_tiles) {
    wmma::fragment<wmma::matrix_a, 16,16,16, half, wmma::row_major> a_frag;
    wmma::fragment<wmma::matrix_b, 16,16,16, half, wmma::col_major> b_frag;
    wmma::fragment<wmma::accumulator, 16,16,16, float> c_frag;
    wmma::fill_fragment(c_frag, 0.0f);
    const int K_TOTAL = 64;
    for (int i = 0; i < k_tiles; ++i) {
        // Stride is K_TOTAL elements for both A (row-stride) and B (col-stride).
        wmma::load_matrix_sync(a_frag, A + i * 16, K_TOTAL);
        wmma::load_matrix_sync(b_frag, B + i * 16, K_TOTAL);
        wmma::mma_sync(c_frag, a_frag, b_frag, c_frag);
    }
    wmma::store_matrix_sync(C, c_frag, 16, wmma::mem_row_major);
}
