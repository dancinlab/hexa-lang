// Probe whether Apple MSL on this host exposes ANY async-copy API.
#include <metal_stdlib>
using namespace metal;

kernel void probe(device const half* a [[buffer(0)]],
                  device       half* b [[buffer(1)]])
{
    threadgroup half tg[128];
    simdgroup_event e = simdgroup_async_copy_2d(
        16, ulong2(16, 8),
        (threadgroup half*)tg,
        16,
        ulong2(16, 8),
        a);
    simdgroup_event evs[1] = { e };
    simdgroup_event::wait(1, evs);
    b[0] = tg[0];
}
