#include <metal_stdlib>
using namespace metal;

kernel void vec_neg(
    device const float* a [[buffer(0)]],
    device float* c [[buffer(1)]],
    uint i [[thread_position_in_grid]])
{
    c[i] = -a[i];
}
