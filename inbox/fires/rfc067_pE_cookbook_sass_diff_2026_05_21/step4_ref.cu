// Reference cookbook step4: cp.async pipelined WMMA, single warp.
// Matches hexa step4_cp_async.ptx shape (sm_90).
// Double-buffered K-loop: prologue loads K=0, then for each i, load i+1 while
// computing i, drain at end. M=16 N=16 K_TOTAL = k_tiles * 16.
//
// Uses cuda::pipeline + cooperative_groups for cp.async (the canonical CUDA
// equivalent of hexa's hand-emitted cp.async.cg.shared.global pattern).
#include <mma.h>
#include <cuda/pipeline>
#include <cooperative_groups.h>
#include <cooperative_groups/memcpy_async.h>
using namespace nvcuda;
namespace cg = cooperative_groups;

extern "C" __global__ void wmma_cp_async(const half* __restrict__ A,
                                          const half* __restrict__ B,
                                          float* __restrict__ C,
                                          int k_tiles) {
    const int K_TOTAL = 64;
    __shared__ alignas(16) half stage_a[2][16 * 16];
    __shared__ alignas(16) half stage_b[2][16 * 16];

    auto block = cg::this_thread_block();
    __shared__ cuda::pipeline_shared_state<cuda::thread_scope::thread_scope_block, 2> pstate;
    auto pipe = cuda::make_pipeline(block, &pstate);

    wmma::fragment<wmma::matrix_a, 16,16,16, half, wmma::row_major> a_frag;
    wmma::fragment<wmma::matrix_b, 16,16,16, half, wmma::col_major> b_frag;
    wmma::fragment<wmma::accumulator, 16,16,16, float> c_frag;
    wmma::fill_fragment(c_frag, 0.0f);

    auto load_tile = [&](int kidx, int slot) {
        // Asynchronously copy the K=kidx tile of A and B into shared stage[slot].
        cuda::memcpy_async(block,
                           &stage_a[slot][0],
                           A + kidx * 16,
                           cuda::aligned_size_t<16>(16 * 16 * sizeof(half)),
                           pipe);
        cuda::memcpy_async(block,
                           &stage_b[slot][0],
                           B + kidx * 16,
                           cuda::aligned_size_t<16>(16 * 16 * sizeof(half)),
                           pipe);
    };

    // Prologue: kick K=0.
    pipe.producer_acquire();
    load_tile(0, 0);
    pipe.producer_commit();

    for (int i = 0; i < k_tiles; ++i) {
        // Prefetch next.
        if (i + 1 < k_tiles) {
            pipe.producer_acquire();
            load_tile(i + 1, (i + 1) & 1);
            pipe.producer_commit();
        }
        // Wait on current tile, consume.
        pipe.consumer_wait();
        wmma::load_matrix_sync(a_frag, &stage_a[i & 1][0], 16);
        wmma::load_matrix_sync(b_frag, &stage_b[i & 1][0], 16);
        wmma::mma_sync(c_frag, a_frag, b_frag, c_frag);
        pipe.consumer_release();
    }
    wmma::store_matrix_sync(C, c_frag, 16, wmma::mem_row_major);
}
