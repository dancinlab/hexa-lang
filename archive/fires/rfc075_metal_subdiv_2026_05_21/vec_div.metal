#include <metal_stdlib>
using namespace metal;

kernel void vec_div(
    device const float* a [[buffer(0)]],
    device const float* b [[buffer(1)]],
    device float* c [[buffer(2)]],
    uint i [[thread_position_in_grid]])
{
    c[i] = a[i] / b[i];
}
