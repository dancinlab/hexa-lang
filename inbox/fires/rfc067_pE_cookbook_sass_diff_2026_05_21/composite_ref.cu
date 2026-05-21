// Reference cookbook composite: 256x256 HGEMM, 4x4 thread-block grid, 16 warps/block.
// Matches hexa composite_perf.ptx shape (sm_90).
// Per block: 64x64 output sub-block.  Per warp inside block: 16x16 output tile.
// K-loop: K_TILES = K/16 = 16.
#include <mma.h>
using namespace nvcuda;
extern "C" __global__ void wmma_256x256_grid(const half* __restrict__ A,
                                              const half* __restrict__ B,
                                              float* __restrict__ C,
                                              int k_tiles) {
    const int N = 256;
    int block_row = blockIdx.y;   // 0..3
    int block_col = blockIdx.x;   // 0..3
    int warp_id = threadIdx.x / 32;
    int m_tile = warp_id / 4;     // 0..3
    int n_tile = warp_id % 4;     // 0..3

    const half* a_warp = A + (block_row * 64 + m_tile * 16) * N;
    const half* b_warp = B + (block_col * 64 + n_tile * 16) * N;
    float* c_warp = C + ((block_row * 64 + m_tile * 16) * N
                          + (block_col * 64 + n_tile * 16));

    wmma::fragment<wmma::matrix_a, 16,16,16, half, wmma::row_major> a_frag;
    wmma::fragment<wmma::matrix_b, 16,16,16, half, wmma::col_major> b_frag;
    wmma::fragment<wmma::accumulator, 16,16,16, float> c_frag;
    wmma::fill_fragment(c_frag, 0.0f);
    for (int i = 0; i < k_tiles; ++i) {
        wmma::load_matrix_sync(a_frag, a_warp + i * 16, N);
        wmma::load_matrix_sync(b_frag, b_warp + i * 16, N);
        wmma::mma_sync(c_frag, a_frag, b_frag, c_frag);
    }
    wmma::store_matrix_sync(c_warp, c_frag, N, wmma::mem_row_major);
}
