// simdgroup_matmul_mixed.metal — RFC 075 Apple M3 mixed-precision simdgroup_matrix MMA fire
//
// Hand-emit mixed-precision matmul using Apple's SIMD-group matrix MMA intrinsic
// with FP16 inputs and FP32 accumulator. Follows N16 FP32 fire (commit 31d729a4,
// peak 911 GFLOPS @ 768³ on 32x32_tg) and N25 pure-FP16 fire (commit ab0ff62d,
// peak 789 GFLOPS @ 1024³ on 32x32_tg, but FP16 accumulator → precision loss
// at K≥768).
//
// Mixed-precision MMA pattern (per Apple MSL §6.7 + on-system header):
//   simdgroup_matrix<half,  8, 8> A, B;     // FP16 inputs
//   simdgroup_matrix<float, 8, 8> C(0);     // FP32 accumulator
//   simdgroup_multiply_accumulate(C, A, B, C);   // overload resolves to mixed-prec
//
// The on-system header at
//   /var/run/com.apple.security.cryptexd/.../metal_simdgroup_matrix
// confirms the templated signature
//   template <typename R, typename T, typename U, typename V, int K, int Rows, int Cols>
//   METAL_FUNC enable_if_t<_valid_simdgroup_multiply_accumulate_v<R,T,U,V,K>>
//   simdgroup_multiply_accumulate(thread simdgroup_matrix<R, Cols, Rows> &d,
//                                 simdgroup_matrix<T, K, Rows> a,
//                                 simdgroup_matrix<U, Cols, K> b,
//                                 simdgroup_matrix<V, Cols, Rows> c);
// Independent {R, T, U, V} types are allowed — R == V == float, T == U == half
// is the canonical FP16-in / FP32-acc mixed-precision form.
//
// Storage:
//   - Input buffers a, b are FP16 (`half`, 2 B/elem).
//   - Output buffer c is FP32 (`float`, 4 B/elem) so the FP32 accumulator
//     can be stored without conversion loss. Host computes FP32 CPU
//     reference and compares directly.
//
// Layout: row-major A[M,K] · B[K,N] → C[M,N].
//
// FP precision goal (g3 honest):
//   - The accumulator is FP32, so K-loop drift should hit ~K * eps_fp16 / 2
//     ULP at most — empirically that lands around 1e-4 rel_err for K up to
//     1024 (1024 * 2^-10 ≈ 1, but accumulator carries 24-bit mantissa, so
//     the input rounding error is the floor, not the accumulator).
//   - Target tolerance: rel_err < 1e-4. If FP16 input rounding alone exceeds
//     that we document the floor honestly.
//
// Throughput hypothesis:
//   - Per N25 (pure-FP16): Apple M3 does NOT have a 2× FP16 MMA path; pure-FP16
//     ran at 0.87× FP32. The mixed-precision form may be:
//       (a) faster than pure-FP16 (if hardware preferentially feeds the FP32
//           accumulator pipe), or
//       (b) same as pure-FP16 (if the MMA pipe is identical and only operand
//           types differ for the loader), or
//       (c) slower (if mixed-precision requires extra widening ops).
//   - We measure and report honestly. The win we expect to keep is bandwidth
//     (FP16 buffers = half the size of FP32 → 2× cheaper to load).
//
// Three kernels mirror N16 + N25: 8x8 / 16x16 / 32x32_tg (the 32x32_tg
// pattern is N16's peak).
//
// Threadgroup memory budget for 32x32_tg:
//   - As: FP16 32×8 = 512 B
//   - Bs: FP16  8×32 = 512 B
//   Total = 1 KiB per TG (same as N25, well under 32 KiB M3 limit).

#include <metal_stdlib>
#include <metal_simdgroup_matrix>
using namespace metal;

// ---------------------------------------------------------------------------
// Kernel 1: simdgroup_matmul_8x8_mixed — minimum-tile (1 simdgroup per 8x8 output)
// ---------------------------------------------------------------------------
// Dispatch:  threads_per_grid = ( (N/8)*32, M/8, 1 )
//            threads_per_threadgroup = ( 32, 1, 1 ) = 1 simdgroup
// One threadgroup = 1 simdgroup = one 8x8 output tile.
// ---------------------------------------------------------------------------
kernel void simdgroup_matmul_8x8_mixed(
    device   const half*   a    [[buffer(0)]],
    device   const half*   b    [[buffer(1)]],
    device         float*  c    [[buffer(2)]],
    constant       uint&   M    [[buffer(3)]],
    constant       uint&   N    [[buffer(4)]],
    constant       uint&   K    [[buffer(5)]],
    uint2  tgid [[threadgroup_position_in_grid]])
{
    const uint row_base = tgid.y * 8u;
    const uint col_base = tgid.x * 8u;
    if (row_base >= M || col_base >= N) { return; }

    // FP32 accumulator C tile = 0.
    simdgroup_matrix<float, 8, 8> Cmat = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);

    const uint K8 = K / 8u;
    for (uint kk = 0u; kk < K8; ++kk) {
        simdgroup_matrix<half, 8, 8> Amat;   // FP16 input
        simdgroup_matrix<half, 8, 8> Bmat;   // FP16 input

        simdgroup_load(Amat, a, ulong(K),
                       ulong2(ulong(kk * 8u), ulong(row_base)),
                       false);
        simdgroup_load(Bmat, b, ulong(N),
                       ulong2(ulong(col_base), ulong(kk * 8u)),
                       false);

        // Mixed-precision MMA: R=float, T=half, U=half, V=float.
        simdgroup_multiply_accumulate(Cmat, Amat, Bmat, Cmat);
    }

    simdgroup_store(Cmat, c, ulong(N),
                    ulong2(ulong(col_base), ulong(row_base)),
                    false);
}

// ---------------------------------------------------------------------------
// Kernel 2: simdgroup_matmul_16x16_mixed — larger block (4 simdgroups per TG)
// ---------------------------------------------------------------------------
// Each threadgroup computes a 16x16 output sub-block as 2x2 = 4 simdgroups of
// 8x8 output tiles. Each simdgroup handles ONE of the 4 quadrants and runs the
// full K-loop independently.
//
// Dispatch:  threads_per_grid = ( (N/16)*32, (M/16)*4, 1 )
//            threads_per_threadgroup = ( 32, 4, 1 ) = 4 simdgroups
// ---------------------------------------------------------------------------
kernel void simdgroup_matmul_16x16_mixed(
    device   const half*   a    [[buffer(0)]],
    device   const half*   b    [[buffer(1)]],
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
        simdgroup_matrix<half, 8, 8> Amat;
        simdgroup_matrix<half, 8, 8> Bmat;
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
// Kernel 3: simdgroup_matmul_32x32_tg_mixed — 32x32 block via threadgroup memory
// ---------------------------------------------------------------------------
// 4x4 = 16 simdgroups per threadgroup, each owns one 8x8 output sub-tile.
// K-loop is unrolled into TG_K-wide steps where each step:
//   1) cooperatively loads a 32 x TG_K slab of A (FP16) into threadgroup mem,
//      and a TG_K x 32 slab of B (FP16) into threadgroup mem.
//   2) issues one simdgroup mixed-precision MMA tile.
//
// Dispatch:  threads_per_grid = ( (N/32)*32, (M/32)*16, 1 )
//            threads_per_threadgroup = ( 32, 16, 1 ) = 16 simdgroups
//
// Threadgroup memory: 32*8*2 + 8*32*2 = 1 KiB (was 8 KiB at FP32).
// ---------------------------------------------------------------------------
constant constexpr uint TG_M = 32;
constant constexpr uint TG_N = 32;
constant constexpr uint TG_K = 8;

kernel void simdgroup_matmul_32x32_tg_mixed(
    device   const half*   a    [[buffer(0)]],
    device   const half*   b    [[buffer(1)]],
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

    threadgroup half As[TG_M * TG_K];
    threadgroup half Bs[TG_K * TG_N];

    simdgroup_matrix<float, 8, 8> Cmat = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);

    const uint tid = sgid * 32u + slid;
    const uint K8 = K / 8u;

    for (uint kk = 0u; kk < K8; ++kk) {
        // Cooperative load of A slab [TG_M × TG_K] = 32*8 = 256 halves.
        if (tid < 256u) {
            const uint r = tid / TG_K;
            const uint c_idx = tid % TG_K;
            const uint a_row = block_row_base + r;
            const uint a_col = kk * 8u + c_idx;
            As[r * TG_K + c_idx] = (a_row < M && a_col < K) ? a[a_row * K + a_col] : half(0.0);
        }
        // Cooperative load of B slab [TG_K × TG_N] = 8*32 = 256 halves.
        if (tid < 256u) {
            const uint r = tid / TG_N;
            const uint c_idx = tid % TG_N;
            const uint b_row = kk * 8u + r;
            const uint b_col = block_col_base + c_idx;
            Bs[r * TG_N + c_idx] = (b_row < K && b_col < N) ? b[b_row * N + b_col] : half(0.0);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);

        simdgroup_matrix<half, 8, 8> Amat;
        simdgroup_matrix<half, 8, 8> Bmat;
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
