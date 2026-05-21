// kernels.metal — hand-emit Metal kernels for Apple M3 roofline probe.
//
// Each kernel reads 2 elements (a[i], b[i]) and writes 1 element c[i],
// performing N add operations between the read and write to vary
// arithmetic intensity. Compares wall time as N grows from 1 to 64.
//
// This is NOT codegen-produced — it's a hand-written .metal file written
// to probe Apple M3 GPU's roofline crossover point (memory-bound vs
// compute-bound). The compute kernels parallel the codegen vec-add shape
// but compute-extended.
//
// Used by host_roofline.swift.

#include <metal_stdlib>
using namespace metal;

kernel void vec_add_1op(
    device const float* a [[buffer(0)]],
    device const float* b [[buffer(1)]],
    device float* c [[buffer(2)]],
    uint i [[thread_position_in_grid]])
{
    c[i] = a[i] + b[i];
}

kernel void vec_add_4op(
    device const float* a [[buffer(0)]],
    device const float* b [[buffer(1)]],
    device float* c [[buffer(2)]],
    uint i [[thread_position_in_grid]])
{
    float x = a[i] + b[i];
    x = x + b[i];
    x = x + b[i];
    x = x + b[i];
    c[i] = x;
}

kernel void vec_add_16op(
    device const float* a [[buffer(0)]],
    device const float* b [[buffer(1)]],
    device float* c [[buffer(2)]],
    uint i [[thread_position_in_grid]])
{
    float x = a[i] + b[i];
    for (int k = 0; k < 15; k++) {
        x = x + b[i];
    }
    c[i] = x;
}

kernel void vec_add_64op(
    device const float* a [[buffer(0)]],
    device const float* b [[buffer(1)]],
    device float* c [[buffer(2)]],
    uint i [[thread_position_in_grid]])
{
    float x = a[i] + b[i];
    for (int k = 0; k < 63; k++) {
        x = x + b[i];
    }
    c[i] = x;
}

kernel void vec_add_256op(
    device const float* a [[buffer(0)]],
    device const float* b [[buffer(1)]],
    device float* c [[buffer(2)]],
    uint i [[thread_position_in_grid]])
{
    float x = a[i] + b[i];
    for (int k = 0; k < 255; k++) {
        x = x + b[i];
    }
    c[i] = x;
}
