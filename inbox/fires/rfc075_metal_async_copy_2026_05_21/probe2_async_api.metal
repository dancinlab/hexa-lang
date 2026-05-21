// Probe alternative async-copy spellings.
#include <metal_stdlib>
using namespace metal;

kernel void probe2(device const half* a [[buffer(0)]],
                   device       half* b [[buffer(1)]])
{
    threadgroup half tg[128];
    // Try OpenCL spelling first
    event_t e = async_work_group_copy((threadgroup half*)tg, a, 128, 0);
    wait_group_events(1, &e);
    b[0] = tg[0];
}
