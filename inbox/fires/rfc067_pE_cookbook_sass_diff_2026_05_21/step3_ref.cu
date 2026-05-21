// Reference cookbook step3: multiwarp 64x64 WMMA grid, 16 warps single block.
// Matches hexa step3_multiwarp.ptx shape (sm_90).
// 512 threads = 16 warps; warp_id = tid.x/32; m_tile = warp_id/4; n_tile = warp_id%4.
// A row-major [64x64], B col-major [64x64], C f32 row-major [64x64], K_TILES=4.
#include <mma.h>
using namespace nvcuda;
extern "C" __global__ void wmma_64x64_grid(const half* __restrict__ A,
                                            const half* __restrict__ B,
                                            float* __restrict__ C,
                                            int k_tiles) {
    const int N = 64;
    int warp_id = threadIdx.x / 32;
    int m_tile = warp_id / 4;
    int n_tile = warp_id % 4;
    const half* a_warp = A + m_tile * 16 * N;
    const half* b_warp = B + n_tile * 16 * N;
    float* c_warp = C + (m_tile * 16) * N + n_tile * 16;

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
