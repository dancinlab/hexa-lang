#include <metal_stdlib>
#include <metal_simdgroup_matrix>
using namespace metal;

kernel void matmul_NT_a(
    device const float* a [[buffer(0)]],
    device const float* b [[buffer(1)]],
    device float* c [[buffer(2)]],
    constant uint& M [[buffer(3)]],
    constant uint& N [[buffer(4)]],
    constant uint& K [[buffer(5)]],
    uint2 tgid [[threadgroup_position_in_grid]],
    uint2 lid [[thread_position_in_threadgroup]],
    uint sgid [[simdgroup_index_in_threadgroup]],
    uint slid [[thread_index_in_simdgroup]])
{
    const uint TG_M = 32u;
    const uint TG_N = 32u;
    const uint TG_K = 8u;
    const uint block_row_base = tgid.y * TG_M;
    const uint block_col_base = tgid.x * TG_N;
    const uint sg_y = sgid >> 2u;
    const uint sg_x = sgid & 3u;
    const uint row_base = block_row_base + sg_y * 8u;
    const uint col_base = block_col_base + sg_x * 8u;
    threadgroup float As[8 * 32];
    threadgroup float Bs[8 * 32];
    simdgroup_matrix<float, 8, 8> Cmat = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
    const uint tid = sgid * 32u + slid;
    const uint K8 = K / 8u;
    for (uint kk = 0u; kk < K8; ++kk) {
        if (tid < 256u) {
            const uint r = tid / TG_M;
            const uint cc = tid % TG_M;
            const uint a_row = kk * 8u + r;
            const uint a_col = block_row_base + cc;
            As[r * TG_M + cc] = (a_row < K && a_col < M) ? a[a_row * M + a_col] : 0.0f;
        }
        if (tid < 256u) {
            const uint r = tid / TG_N;
            const uint cc = tid % TG_N;
            const uint b_row = kk * 8u + r;
            const uint b_col = block_col_base + cc;
            Bs[r * TG_N + cc] = (b_row < K && b_col < N) ? b[b_row * N + b_col] : 0.0f;
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        simdgroup_matrix<float, 8, 8> Amat;
        simdgroup_matrix<float, 8, 8> Bmat;
        simdgroup_load(Amat, As, ulong(TG_M), ulong2(ulong(sg_y * 8u), 0ul), true);
        simdgroup_load(Bmat, Bs, ulong(TG_N), ulong2(ulong(sg_x * 8u), 0ul), false);
        simdgroup_multiply_accumulate(Cmat, Amat, Bmat, Cmat);
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (row_base < M && col_base < N) {
        simdgroup_store(Cmat, c, ulong(N), ulong2(ulong(col_base), ulong(row_base)), false);
    }
}

