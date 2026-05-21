#include <metal_stdlib>
using namespace metal;

kernel void reduce_sum(
    device const float* a [[buffer(0)]],
    device float* c [[buffer(1)]],
    uint i [[thread_position_in_grid]])
{
    float v = a[i];
    v = simd_sum(v);
    if (simd_is_first()) {
        uint group_id = i / 32u;
        c[group_id] = v;
    }
}
