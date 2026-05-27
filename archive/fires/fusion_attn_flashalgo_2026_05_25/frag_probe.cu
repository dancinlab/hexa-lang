/* Probe the m16n16k16 f32 accumulator fragment lane->(row,col) map empirically.
 * Fill the accumulator with known values such that on store we can read out
 * which lane holds which (row,col). Strategy: do mma where A is row-identity-ish
 * via Q[r][d] = (r==d) and K^T[d][c] = c-encoded, then S[r][c] = c when r==d...
 * easier: just store an initialized fragment with known data and inspect.
 *
 * Approach 2 (simpler): use store_matrix_sync to write the fragment to shared,
 * then have lane 0 read it back. But that doesn't tell us per-lane map.
 *
 * Approach 3 (the right one): each lane writes its OWN .x[i] value into a
 * tagged global buffer, then we do a store_matrix_sync and observe which
 * (row,col) in shared got which tag.
 *
 * Tag layout: lane * 16 + i  (each of the 32*8 = 256 elements gets a unique tag,
 * fits in [0..511]). After store, shared[row*16+col] = tag(lane, i) tells us
 * the inverse map.
 */
#include <cuda_runtime.h>
#include <cuda_fp16.h>
#include <mma.h>
#include <stdio.h>
using namespace nvcuda;

__global__ void probe() {
    __shared__ float s[16*16];
    int lane = threadIdx.x & 31;
    wmma::fragment<wmma::accumulator, 16, 16, 16, float> f;
    // initialize every accumulator element to a unique tag = lane*16 + i
    for (int i = 0; i < f.num_elements; ++i) f.x[i] = (float)(lane * 16 + i);
    wmma::store_matrix_sync(s, f, 16, wmma::mem_row_major);
    __syncwarp();
    if (lane == 0) {
        // print the 16x16 grid -- each cell holds tag = (lane * 16 + elem_idx)
        for (int r = 0; r < 16; ++r) {
            for (int c = 0; c < 16; ++c) {
                int tag = (int)s[r*16+c];
                int l = tag / 16, e = tag % 16;
                printf("(%2d,%2d)=l%02d.e%d  ", r, c, l, e);
            }
            printf("\n");
        }
    }
}

int main() {
    probe<<<1, 32>>>();
    cudaDeviceSynchronize();
    return 0;
}
