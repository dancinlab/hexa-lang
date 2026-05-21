// simdgroup_matmul_fp16.metal — RFC 075 Apple M3 simdgroup_matrix<half,8,8> FP16 matmul silicon-fire
//
// Hand-emit FP16 matmul using Apple's SIMD-group matrix MMA intrinsic.
// Companion to simdgroup_matmul.metal (commit 31d729a4) which fired FP32 at
// 911 GFLOPS peak. This cycle fires the FP16 path:
//   `simdgroup_matrix<half, 8, 8>` from <metal_simdgroup_matrix>, FP16 inputs,
//   FP16 accumulator. Apple MSL §6.7 also allows a mixed-precision form
//   (FP16 inputs, FP32 accumulator) — out of scope for this first FP16 cycle;
//   we measure the pure-FP16 path first to characterise raw MMA throughput.
//
// References (cited per task spec):
//   - Apple Metal Shading Language Spec §6.7 ("SIMD-group Matrix Functions"):
//       https://developer.apple.com/metal/Metal-Shading-Language-Specification.pdf
//     Defines `simdgroup_matrix<T,8,8>` for T ∈ {float, half, bfloat} and the
//     `simdgroup_load`/`simdgroup_multiply_accumulate`/`simdgroup_store`
//     primitives we lower onto here. The 8x8x8 tile constraint and 32-lane
//     simdgroup are the same for FP16 as for FP32 (the difference is the
//     hardware MMA pipe used — Apple M3 has a dedicated FP16 path).
//   - Header on this system:
//       /Applications/Xcode.app/Contents/Developer/Toolchains/.../metal/metal_simdgroup_matrix
//     The `make_filled_simdgroup_matrix<half, 8, 8>(half)` and overloaded
//     `simdgroup_load(simdgroup_matrix<half,8,8>&, ...)`/store/MMA forms
//     are gated by `__HAVE_SIMDGROUP_MATRIX__` (defined on Apple M-series).
//   - FP32 reference fire: simdgroup_matmul.metal (commit `31d729a4`) —
//     peak 911.55 GFLOPS @ 768³ on the 32x32_tg kernel.
//
// Layout: row-major A[M,K] · B[K,N] → C[M,N], all FP16, all `device` storage.
// Host buffers are `half`-sized (2 bytes / elem), so the FP16 buffers are
// half the size of the FP32 ones.
//
// FP precision (g3 honest):
//   - FP16 has ~3-4 decimal digits of mantissa precision. With FP16
//     accumulator over K=128..1024 the accumulated rounding can hit the
//     1e-3 floor easily. Host tolerance: rel_err < 1e-2 (very lax for FP16;
//     a stricter threshold like 1e-3 will fail at K≥256 because FP16
//     accumulator overflows precision after a few hundred terms).
//   - For numerical sanity we compare against the same FP32 CPU `ikj`
//     reference as the FP32 host. The comparison is FP16-gpu vs FP32-cpu
//     after FP16→FP32 round-trip on the GPU output buffer.
//
// Honest scope (g3):
//   - FP16 inputs + FP16 accumulator. Mixed-prec (FP16 in, FP32 accum) is
//     a separate kernel — defer to followup.
//   - Same 8x8 tile-per-simdgroup constraint as FP32. The "FP16 should be
//     ~2× FP32" expectation is based on Apple's marketing for GPU FP16
//     throughput. If we don't observe ~2×, Apple M3 may not have an
//     accelerated FP16 MMA path — we report honestly either way.
//   - Three kernels mirror the FP32 fire: 8x8 minimum-tile, 16x16 four-
//     simdgroup, 32x32_tg sixteen-simdgroup-with-threadgroup-staging.
//   - Threadgroup memory budget for 32x32_tg: 32*8*2 = 512 B A + 8*32*2 =
//     512 B B = 1 KiB per threadgroup (was 8 KiB for FP32) — well under
//     the 32 KiB M3 limit.

#include <metal_stdlib>
#include <metal_simdgroup_matrix>
using namespace metal;

// ---------------------------------------------------------------------------
// Kernel 1: simdgroup_matmul_8x8_fp16 — minimum-tile (1 simdgroup per 8x8 output)
// ---------------------------------------------------------------------------
// Dispatch:  threads_per_grid = ( (N/8)*32, M/8, 1 )
//            threads_per_threadgroup = ( 32, 1, 1 ) = 1 simdgroup
// One threadgroup = 1 simdgroup = one 8x8 output tile.
// ---------------------------------------------------------------------------
kernel void simdgroup_matmul_8x8_fp16(
    device   const half*  a    [[buffer(0)]],
    device   const half*  b    [[buffer(1)]],
    device         half*  c    [[buffer(2)]],
    constant       uint&  M    [[buffer(3)]],
    constant       uint&  N    [[buffer(4)]],
    constant       uint&  K    [[buffer(5)]],
    uint2  tgid [[threadgroup_position_in_grid]])
{
    const uint row_base = tgid.y * 8u;
    const uint col_base = tgid.x * 8u;
    if (row_base >= M || col_base >= N) { return; }

    // Accumulator C tile = 0 (half).
    simdgroup_matrix<half, 8, 8> Cmat = make_filled_simdgroup_matrix<half, 8, 8>(half(0.0));

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
// Kernel 2: simdgroup_matmul_16x16_fp16 — larger block (4 simdgroups per TG)
// ---------------------------------------------------------------------------
// Each threadgroup computes a 16x16 output sub-block as 2x2 = 4 simdgroups of
// 8x8 output tiles. Each simdgroup handles ONE of the 4 quadrants and runs the
// full K-loop independently.
//
// Dispatch:  threads_per_grid = ( (N/16)*32, (M/16)*4, 1 )
//            threads_per_threadgroup = ( 32, 4, 1 ) = 4 simdgroups
//
// simdgroup index within threadgroup: lid.y in [0..3] → (sg_y, sg_x) = (lid.y/2, lid.y%2).
// ---------------------------------------------------------------------------
kernel void simdgroup_matmul_16x16_fp16(
    device   const half*  a    [[buffer(0)]],
    device   const half*  b    [[buffer(1)]],
    device         half*  c    [[buffer(2)]],
    constant       uint&  M    [[buffer(3)]],
    constant       uint&  N    [[buffer(4)]],
    constant       uint&  K    [[buffer(5)]],
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

    simdgroup_matrix<half, 8, 8> Cmat = make_filled_simdgroup_matrix<half, 8, 8>(half(0.0));
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
// Kernel 3: simdgroup_matmul_32x32_tg_fp16 — 32x32 block via threadgroup memory
// ---------------------------------------------------------------------------
// 4x4 = 16 simdgroups per threadgroup, each owns one 8x8 output sub-tile.
// K-loop is unrolled into TG_K-wide steps where each step:
//   1) cooperatively loads a 32 x TG_K slab of A into threadgroup mem,
//      and a TG_K x 32 slab of B into threadgroup mem.
//   2) issues one simdgroup MMA tile inside the inner K loop.
//
// Dispatch:  threads_per_grid = ( (N/32)*32, (M/32)*16, 1 )
//            threads_per_threadgroup = ( 32, 16, 1 ) = 16 simdgroups
//
// Threadgroup memory: 32*8*2 + 8*32*2 = 1 KiB (was 8 KiB at FP32).
// ---------------------------------------------------------------------------
constant constexpr uint TG_M = 32;
constant constexpr uint TG_N = 32;
constant constexpr uint TG_K = 8;

kernel void simdgroup_matmul_32x32_tg_fp16(
    device   const half*  a    [[buffer(0)]],
    device   const half*  b    [[buffer(1)]],
    device         half*  c    [[buffer(2)]],
    constant       uint&  M    [[buffer(3)]],
    constant       uint&  N    [[buffer(4)]],
    constant       uint&  K    [[buffer(5)]],
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

    simdgroup_matrix<half, 8, 8> Cmat = make_filled_simdgroup_matrix<half, 8, 8>(half(0.0));

    const uint tid = sgid * 32u + slid;
    const uint K8 = K / 8u;

    for (uint kk = 0u; kk < K8; ++kk) {
        // Cooperative load of A slab [TG_M × TG_K] = 32*8 = 256 halves.
        if (tid < 256u) {
            const uint r = tid / TG_K;
            const uint c = tid % TG_K;
            const uint a_row = block_row_base + r;
            const uint a_col = kk * 8u + c;
            As[r * TG_K + c] = (a_row < M && a_col < K) ? a[a_row * K + a_col] : half(0.0);
        }
        // Cooperative load of B slab [TG_K × TG_N] = 8*32 = 256 halves.
        if (tid < 256u) {
            const uint r = tid / TG_N;
            const uint c = tid % TG_N;
            const uint b_row = kk * 8u + r;
            const uint b_col = block_col_base + c;
            Bs[r * TG_N + c] = (b_row < K && b_col < N) ? b[b_row * N + b_col] : half(0.0);
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
