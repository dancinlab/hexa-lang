// vec_add.metal — RFC 075 Apple M4 vec-add baseline (N=1M FP32)
//
// Minimal element-wise FP32 add: c[gid] = a[gid] + b[gid].
// Compiled via xcrun --sdk macosx metal + metallib; dispatched from Swift host.
//
// Build:
//   xcrun --sdk macosx metal -c vec_add.metal -o vec_add.air
//   xcrun --sdk macosx metallib vec_add.air -o vec_add.metallib

#include <metal_stdlib>
using namespace metal;

kernel void vec_add(
    device   const float* a [[buffer(0)]],
    device   const float* b [[buffer(1)]],
    device         float* c [[buffer(2)]],
    constant       uint&  N [[buffer(3)]],
    uint                  gid [[thread_position_in_grid]])
{
    if (gid >= N) return;
    c[gid] = a[gid] + b[gid];
}
