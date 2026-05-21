// matmul_bf16.metal — RFC 075 N41 codegen-emit reproduction.
//
// This file is the MECHANICAL OUTPUT of the N41 (commit 7b5f4997) Metal target
// codegen path for the `matmul_bf16` MIR shape, reproduced by inspection.
// Source: compiler/codegen/metal_target.hexa
//
//   _metal_emit_matmul_preamble()
//     ⇒ #include <metal_stdlib>
//        #include <metal_simdgroup_matrix>
//        using namespace metal;
//
//   _metal_emit_matmul_kernel_signature_bf16("matmul_bf16")
//     ⇒ kernel void matmul_bf16( device const bfloat* a [[buffer(0)]], … )
//
//   _metal_emit_matmul_bf16_body()
//     ⇒ { … TG_M=32 / TG_N=32 / TG_K=8 simdgroup_matrix<bfloat,8,8> MMA … }
//
// The MIR shape is STMT_LOAD(va<-a) · STMT_LOAD(vb<-b) ·
// STMT_BINOP("matmul_bf16", vc, va, vb) · STMT_STORE(vc->c) · STMT_RETURN,
// as built by metal_lower_test::_build_matmul_bf16_module (Case 20).
//
// NO HAND EDITS: every character below is the verbatim concatenation of the
// constants and literals in metal_target.hexa. This is the file the codegen
// would have written if the host-side Apple9 feature-set gate had let it land
// in the inbox.

#include <metal_stdlib>
#include <metal_simdgroup_matrix>
using namespace metal;

kernel void matmul_bf16(
    device const bfloat* a [[buffer(0)]],
    device const bfloat* b [[buffer(1)]],
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
    threadgroup bfloat As[32 * 8];
    threadgroup bfloat Bs[8 * 32];
    simdgroup_matrix<float, 8, 8> Cmat = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
    const uint tid = sgid * 32u + slid;
    const uint K8 = K / 8u;
    for (uint kk = 0u; kk < K8; ++kk) {
        if (tid < 256u) {
            const uint r = tid / TG_K;
            const uint cc = tid % TG_K;
            const uint a_row = block_row_base + r;
            const uint a_col = kk * 8u + cc;
            As[r * TG_K + cc] = (a_row < M && a_col < K) ? a[a_row * K + a_col] : bfloat(0.0f);
        }
        if (tid < 256u) {
            const uint r = tid / TG_N;
            const uint cc = tid % TG_N;
            const uint b_row = kk * 8u + r;
            const uint b_col = block_col_base + cc;
            Bs[r * TG_N + cc] = (b_row < K && b_col < N) ? b[b_row * N + b_col] : bfloat(0.0f);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        simdgroup_matrix<bfloat, 8, 8> Amat;
        simdgroup_matrix<bfloat, 8, 8> Bmat;
        simdgroup_load(Amat, As, ulong(TG_K), ulong2(0ul, ulong(sg_y * 8u)), false);
        simdgroup_load(Bmat, Bs, ulong(TG_N), ulong2(ulong(sg_x * 8u), 0ul), false);
        simdgroup_multiply_accumulate(Cmat, Amat, Bmat, Cmat);
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (row_base < M && col_base < N) {
        simdgroup_store(Cmat, c, ulong(N), ulong2(ulong(col_base), ulong(row_base)), false);
    }
}
