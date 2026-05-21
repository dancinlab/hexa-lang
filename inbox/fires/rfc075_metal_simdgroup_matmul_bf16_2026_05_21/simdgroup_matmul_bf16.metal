// simdgroup_matmul_bf16.metal — RFC 075 Apple M3 bfloat16 simdgroup_matrix MMA fire
//
// Hand-emit bfloat16-input + FP32-accumulator matmul using Apple's SIMD-group
// matrix MMA intrinsic. Follows N30 mixed-prec (FP16/FP32) fire (commit 99aed70f,
// peak 987 GFLOPS @ 1024^3 on 32x32_tg) and N25 pure-FP16 fire (commit ab0ff62d,
// peak 789 GFLOPS).
//
// bf16 hypothesis (g3-honest):
//   - bf16 has FP32-equivalent dynamic range (8-bit exponent) with 2-byte storage.
//   - On NVIDIA H100 tensor cores bf16 has dedicated path, ~equal to FP16 path,
//     2× FP32 throughput. Does Apple M3 expose dedicated bf16 acceleration, or
//     does it route bf16 through the same hardware path as FP16 (both 2-byte
//     2-operand MMA), or does it fall back to FP32 emulation (no bf16 path)?
//
// API status: confirmed on this toolchain (Metal v32023.883, macOS 26.5):
//   - Header `<metal_simdgroup_matrix>` declares `typedef simdgroup_matrix<bfloat, 8, 8> simdgroup_bfloat8x8;`
//   - `_valid_simdgroup_multiply_accumulate_v<R=float, T=bfloat, U=bfloat, V=float>`
//     instantiates cleanly. Standalone smoke-compile of the templated form
//     succeeded with zero diagnostics.
//
// Pattern (mixed-precision MMA with bf16 inputs, FP32 accumulator):
//   simdgroup_matrix<bfloat, 8, 8> A, B;     // bf16 inputs
//   simdgroup_matrix<float,  8, 8> C(0);     // FP32 accumulator (preserves range+precision)
//   simdgroup_multiply_accumulate(C, A, B, C);
//
// Storage:
//   - Input buffers a, b are bf16 (`bfloat`, 2 B/elem; identical storage cost to FP16).
//   - Output buffer c is FP32 (4 B/elem) so the FP32 accumulator stores without loss.
//   - Reference is computed on bf16-rounded inputs cast back to FP32 → isolates
//     compute-side error from input-rounding noise.
//
// Layout: row-major A[M,K] · B[K,N] → C[M,N].
//
// FP precision goal:
//   - bf16 mantissa = 7 bits (vs FP16 = 10 bits). Per-operand rounding eps ≈ 2^-7 ≈ 7.8e-3.
//   - With FP32 accumulator, K-loop drift is bounded; the error floor is the
//     bf16 input rounding alone. For LCG-uniform inputs, dot-product noise scales
//     as ~sqrt(K)·eps_bf16, so at K=1024: ~32 * 7.8e-3 = ~0.25 worst case,
//     but for uniformly-random inputs the empirical mean error is much smaller
//     (~K·eps²/2 in expectation). Target tolerance: rel_err < 1e-2.
//
// Three kernels mirror N30: 8x8 / 16x16 / 32x32_tg.
//
// Threadgroup memory budget for 32x32_tg (identical to N30 since bf16 = 2 B):
//   - As: bf16 32×8 = 512 B
//   - Bs: bf16  8×32 = 512 B
//   Total = 1 KiB per TG (under 32 KiB M3 limit).

#include <metal_stdlib>
#include <metal_simdgroup_matrix>
using namespace metal;

// ---------------------------------------------------------------------------
// Kernel 1: simdgroup_matmul_8x8_bf16 — minimum-tile (1 simdgroup per 8x8 output)
// ---------------------------------------------------------------------------
// Dispatch:  threads_per_grid = ( (N/8)*32, M/8, 1 )
//            threads_per_threadgroup = ( 32, 1, 1 ) = 1 simdgroup
// ---------------------------------------------------------------------------
kernel void simdgroup_matmul_8x8_bf16(
    device   const bfloat* a    [[buffer(0)]],
    device   const bfloat* b    [[buffer(1)]],
    device         float*  c    [[buffer(2)]],
    constant       uint&   M    [[buffer(3)]],
    constant       uint&   N    [[buffer(4)]],
    constant       uint&   K    [[buffer(5)]],
    uint2  tgid [[threadgroup_position_in_grid]])
{
    const uint row_base = tgid.y * 8u;
    const uint col_base = tgid.x * 8u;
    if (row_base >= M || col_base >= N) { return; }

    simdgroup_matrix<float, 8, 8> Cmat = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);

    const uint K8 = K / 8u;
    for (uint kk = 0u; kk < K8; ++kk) {
        simdgroup_matrix<bfloat, 8, 8> Amat;
        simdgroup_matrix<bfloat, 8, 8> Bmat;

        simdgroup_load(Amat, a, ulong(K),
                       ulong2(ulong(kk * 8u), ulong(row_base)),
                       false);
        simdgroup_load(Bmat, b, ulong(N),
                       ulong2(ulong(col_base), ulong(kk * 8u)),
                       false);

        // Mixed-precision MMA: R=float, T=bfloat, U=bfloat, V=float.
        simdgroup_multiply_accumulate(Cmat, Amat, Bmat, Cmat);
    }

    simdgroup_store(Cmat, c, ulong(N),
                    ulong2(ulong(col_base), ulong(row_base)),
                    false);
}

// ---------------------------------------------------------------------------
// Kernel 2: simdgroup_matmul_16x16_bf16 — larger block (4 simdgroups per TG)
// ---------------------------------------------------------------------------
// Dispatch:  threads_per_grid = ( (N/16)*32, (M/16)*4, 1 )
//            threads_per_threadgroup = ( 32, 4, 1 ) = 4 simdgroups
// ---------------------------------------------------------------------------
kernel void simdgroup_matmul_16x16_bf16(
    device   const bfloat* a    [[buffer(0)]],
    device   const bfloat* b    [[buffer(1)]],
    device         float*  c    [[buffer(2)]],
    constant       uint&   M    [[buffer(3)]],
    constant       uint&   N    [[buffer(4)]],
    constant       uint&   K    [[buffer(5)]],
    uint2  tgid    [[threadgroup_position_in_grid]],
    uint2  lid     [[thread_position_in_threadgroup]])
{
    const uint block_row_base = tgid.y * 16u;
    const uint block_col_base = tgid.x * 16u;

    const uint sg_y = lid.y >> 1u;       // 0..1
    const uint sg_x = lid.y & 1u;        // 0..1
    const uint row_base = block_row_base + sg_y * 8u;
    const uint col_base = block_col_base + sg_x * 8u;
    if (row_base >= M || col_base >= N) { return; }

    simdgroup_matrix<float, 8, 8> Cmat = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
    const uint K8 = K / 8u;
    for (uint kk = 0u; kk < K8; ++kk) {
        simdgroup_matrix<bfloat, 8, 8> Amat;
        simdgroup_matrix<bfloat, 8, 8> Bmat;
        simdgroup_load(Amat, a, ulong(K),
                       ulong2(ulong(kk * 8u), ulong(row_base)),
                       false);
        simdgroup_load(Bmat, b, ulong(N),
                       ulong2(ulong(col_base), ulong(kk * 8u)),
                       false);
        simdgroup_multiply_accumulate(Cmat, Amat, Bmat, Cmat);
    }
    simdgroup_store(Cmat, c, ulong(N),
                    ulong2(ulong(col_base), ulong(row_base)),
                    false);
}

// ---------------------------------------------------------------------------
// Kernel 3: simdgroup_matmul_32x32_tg_bf16 — 32x32 block via threadgroup memory
// ---------------------------------------------------------------------------
// 4x4 = 16 simdgroups per threadgroup, each owns one 8x8 output sub-tile.
// Dispatch:  threads_per_grid = ( (N/32)*32, (M/32)*16, 1 )
//            threads_per_threadgroup = ( 32, 16, 1 ) = 16 simdgroups
// Threadgroup memory: 32*8*2 + 8*32*2 = 1 KiB.
// ---------------------------------------------------------------------------
constant constexpr uint TG_M = 32;
constant constexpr uint TG_N = 32;
constant constexpr uint TG_K = 8;

kernel void simdgroup_matmul_32x32_tg_bf16(
    device   const bfloat* a    [[buffer(0)]],
    device   const bfloat* b    [[buffer(1)]],
    device         float*  c    [[buffer(2)]],
    constant       uint&   M    [[buffer(3)]],
    constant       uint&   N    [[buffer(4)]],
    constant       uint&   K    [[buffer(5)]],
    uint2  tgid    [[threadgroup_position_in_grid]],
    uint2  lid     [[thread_position_in_threadgroup]],
    uint   sgid    [[simdgroup_index_in_threadgroup]],
    uint   slid    [[thread_index_in_simdgroup]])
{
    const uint block_row_base = tgid.y * TG_M;
    const uint block_col_base = tgid.x * TG_N;

    const uint sg_y = sgid >> 2u;   // 0..3
    const uint sg_x = sgid & 3u;    // 0..3
    const uint row_base = block_row_base + sg_y * 8u;
    const uint col_base = block_col_base + sg_x * 8u;

    threadgroup bfloat As[TG_M * TG_K];
    threadgroup bfloat Bs[TG_K * TG_N];

    simdgroup_matrix<float, 8, 8> Cmat = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);

    const uint tid = sgid * 32u + slid;
    const uint K8 = K / 8u;

    for (uint kk = 0u; kk < K8; ++kk) {
        // Cooperative load of A slab [TG_M × TG_K] = 32*8 = 256 bfloats.
        if (tid < 256u) {
            const uint r = tid / TG_K;
            const uint c_idx = tid % TG_K;
            const uint a_row = block_row_base + r;
            const uint a_col = kk * 8u + c_idx;
            As[r * TG_K + c_idx] = (a_row < M && a_col < K) ? a[a_row * K + a_col] : bfloat(0.0);
        }
        // Cooperative load of B slab [TG_K × TG_N] = 8*32 = 256 bfloats.
        if (tid < 256u) {
            const uint r = tid / TG_N;
            const uint c_idx = tid % TG_N;
            const uint b_row = kk * 8u + r;
            const uint b_col = block_col_base + c_idx;
            Bs[r * TG_N + c_idx] = (b_row < K && b_col < N) ? b[b_row * N + b_col] : bfloat(0.0);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);

        simdgroup_matrix<bfloat, 8, 8> Amat;
        simdgroup_matrix<bfloat, 8, 8> Bmat;
        simdgroup_load(Amat, As, ulong(TG_K),
                       ulong2(0ul, ulong(sg_y * 8u)),
                       false);
        simdgroup_load(Bmat, Bs, ulong(TG_N),
                       ulong2(ulong(sg_x * 8u), 0ul),
                       false);
        simdgroup_multiply_accumulate(Cmat, Amat, Bmat, Cmat);

        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (row_base < M && col_base < N) {
        simdgroup_store(Cmat, c, ulong(N),
                        ulong2(ulong(col_base), ulong(row_base)),
                        false);
    }
}
