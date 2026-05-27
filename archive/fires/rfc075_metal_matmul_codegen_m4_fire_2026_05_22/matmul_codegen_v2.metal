#include <metal_stdlib>
using namespace metal;

kernel void matmul_kernel(
    device const float* a [[buffer(0)]],
    device const float* b [[buffer(1)]],
    device float* c [[buffer(2)]],
    constant uint& M [[buffer(3)]],
    constant uint& N [[buffer(4)]],
    constant uint& K [[buffer(5)]],
    uint2 tg [[threadgroup_position_in_grid]])
{
    uint row_tile = tg.y * 32;  // block row origin
    uint col_tile = tg.x * 32;  // block col origin
    simdgroup_float8x8 c_frag[4][4];
    for (uint sm = 0; sm < 4; ++sm) {
        for (uint sn = 0; sn < 4; ++sn) {
            c_frag[sm][sn] = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);  // zero-init accumulator
        }
    }
    for (uint kk = 0; kk < K; kk += 8) {
        simdgroup_float8x8 a_frag[4];
        for (uint sm = 0; sm < 4; ++sm) {
            simdgroup_load(a_frag[sm], a + (row_tile + sm * 8) * K + kk, K, 0, false);  // A sub-tile
        }
        simdgroup_float8x8 b_frag[4];
        for (uint sn = 0; sn < 4; ++sn) {
            simdgroup_load(b_frag[sn], b + kk * N + (col_tile + sn * 8), N, 0, false);  // B sub-tile
        }
        for (uint sm = 0; sm < 4; ++sm) {
            for (uint sn = 0; sn < 4; ++sn) {
                simdgroup_multiply_accumulate(c_frag[sm][sn], a_frag[sm], b_frag[sn], c_frag[sm][sn]);  // c = a*b + c
            }
        }
    }
    for (uint sm = 0; sm < 4; ++sm) {
        for (uint sn = 0; sn < 4; ++sn) {
            simdgroup_store(c_frag[sm][sn], c + (row_tile + sm * 8) * N + (col_tile + sn * 8), N);  // C sub-tile store
        }
    }
}
