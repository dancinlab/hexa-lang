// matmul_codegen_fixed.metal — N161 codegen-emitted matmul MSL with the SINGLE
// codegen compile bug fixed (one token), for the numeric-eq fire.
//
// This is byte-identical to matmul_codegen.metal (the verbatim
// _metal_emit_matmul_body(false,false) output) EXCEPT line 15, where the
// codegen-emitted
//     make_filled_simdgroup_matrix(simdgroup_float8x8, 0.0f)
// (which does NOT compile — passes the fragment TYPE as a runtime first arg)
// is replaced with the Apple-canonical template form
//     make_filled_simdgroup_matrix<float, 8, 8>(0.0f)
//
// Everything else — preamble, 6-arg signature, 32x32 tile origin, 8-wide
// K-loop, scalar-origin simdgroup_load(frag, ptr, stride, 0, false),
// simdgroup_multiply_accumulate, simdgroup_store(frag, ptr, stride) — is the
// verbatim codegen output. This isolates the fire to the codegen's structural
// + numeric correctness once the single emit bug is patched.
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
    simdgroup_float8x8 c_frag = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);  // C tile accumulator
    simdgroup_float8x8 a_frag;
    simdgroup_float8x8 b_frag;
    for (uint kk = 0; kk < K; kk += 8) {
        simdgroup_load(a_frag, a + row_tile * K + kk, K, 0, false);  // A tile
        simdgroup_load(b_frag, b + kk * N + col_tile, N, 0, false);  // B tile
        simdgroup_multiply_accumulate(c_frag, a_frag, b_frag, c_frag);  // c = a*b + c
    }
    simdgroup_store(c_frag, c + row_tile * N + col_tile, N);  // C tile store
}
