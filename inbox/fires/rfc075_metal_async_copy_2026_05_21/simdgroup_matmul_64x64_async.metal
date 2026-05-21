// simdgroup_matmul_64x64_async.metal — RFC 075 Apple M3 async-copy probe
//
// **API GAP DOCUMENTED** (honest scope, @D g3):
//   The Apple Metal Toolchain installed on this Mac
//   (Apple metal 32023.883, macOS SDK 26.4, metalfe target air64-apple-darwin25.5.0)
//   does NOT expose any of:
//     - simdgroup_event / simdgroup_async_copy_2d (modern Apple async API)
//     - async_work_group_copy / wait_group_events / event_t (OpenCL-derived)
//     - prefetch / __metal_async_* / tg_memcpy builtins
//   Verified by:
//     1. exhaustive grep over the installed metal_stdlib header tree
//        (no symbol matches `simdgroup_event|async_work_group|async_copy|wait_group_events|prefetch`)
//     2. minimal probe kernels probe_async_api.metal / probe2_async_api.metal
//        FAIL to compile against -std=metal3.0, -std=metal3.1, -std=metal3.2.
//   See fire.log + api_gap_evidence.txt in the artifact dir for raw evidence.
//
// Apple's MSL spec documents `simdgroup_event` / `simdgroup_async_copy_2d`
// (since MSL 3.x on iOS 18+ / macOS 15+); however on macOS 26.4 with the
// installed toolchain they are NOT compiled-in. This appears to be either a
// platform gating (only iOS/visionOS exposes the symbols), a missing
// MTLLanguageVersion requirement we cannot trigger via the CLI driver, or a
// deliberate withhold on macOS GPUs that lack the necessary DMA engine.
//
// Since hardware async is unavailable, we instead probe THREE software
// emulations to characterize whether load-vs-compute decoupling, even without
// a dedicated DMA engine, can move past N37's DB peak of 1518 GFLOPS:
//
//   (A) simdgroup_matmul_64x64_async_sw      — control: identical to N37 DB
//       but written inline (load + compute interleaved by source order). Sanity
//       check that this artifact reproduces N37 numbers on the same hardware.
//
//   (B) simdgroup_matmul_64x64_async_swpipe  — software-pipelined inner K-loop:
//       hoist ALL 4 inner A/B simdgroup_loads above the FMA section so the
//       hardware scheduler can interleave LDS reads with FMAs. This IS Apple's
//       only documented sole "async" path: schedule it yourself, the compiler
//       reorders. Closest available approximation to async-copy semantics.
//
//   (C) simdgroup_matmul_64x64_async_split   — interleave NEXT-slot loads
//       inside the inner K-substep loop (each MMA substep issues one quarter
//       of the next K-block's device-tg copy). Tests whether finer-grained
//       load+compute interleaving (vs N37 DB's monolithic prefetch+wait+MMA)
//       moves the needle.
//
// All three kernels use pure simdgroup_load + simdgroup_multiply_accumulate
// against threadgroup memory — no exotic primitives. They compile against
// stock <metal_stdlib>.

#include <metal_stdlib>
#include <metal_simdgroup_matrix>
using namespace metal;

constant constexpr uint K64_TG_M = 64;
constant constexpr uint K64_TG_N = 64;
constant constexpr uint K64_TG_K = 32;

// ===========================================================================
// Kernel A: simdgroup_matmul_64x64_async_sw — DB control (reproduces N37 db)
// ===========================================================================
kernel void simdgroup_matmul_64x64_async_sw(
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
    const uint block_row_base = tgid.y * K64_TG_M;
    const uint block_col_base = tgid.x * K64_TG_N;

    const uint sg_y  = sgid >> 2u;
    const uint sg_xp = sgid & 3u;
    const uint sg_x0 = sg_xp * 2u;
    const uint sg_x1 = sg_xp * 2u + 1u;

    threadgroup half As[2][K64_TG_M * K64_TG_K];
    threadgroup half Bs[2][K64_TG_K * K64_TG_N];

    simdgroup_matrix<float, 8, 8> Cmat0 = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
    simdgroup_matrix<float, 8, 8> Cmat1 = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);

    const uint tid     = sgid * 32u + slid;
    const uint K_step  = K / K64_TG_K;
    const uint A_TILE  = K64_TG_M * K64_TG_K;
    const uint B_TILE  = K64_TG_K * K64_TG_N;

    // Prologue: load slot 0.
    {
        const uint k_base = 0u;
        for (uint off = tid; off < A_TILE; off += 1024u) {
            const uint r = off / K64_TG_K;
            const uint c_idx = off % K64_TG_K;
            const uint a_row = block_row_base + r;
            const uint a_col = k_base + c_idx;
            As[0][off] = (a_row < M && a_col < K) ? a[a_row * K + a_col] : half(0.0);
        }
        for (uint off = tid; off < B_TILE; off += 1024u) {
            const uint r = off / K64_TG_N;
            const uint c_idx = off % K64_TG_N;
            const uint b_row = k_base + r;
            const uint b_col = block_col_base + c_idx;
            Bs[0][off] = (b_row < K && b_col < N) ? b[b_row * N + b_col] : half(0.0);
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint kk = 0u; kk < K_step; ++kk) {
        const uint s_use  = kk & 1u;
        const uint s_next = (kk + 1u) & 1u;

        if (kk + 1u < K_step) {
            const uint k_base = (kk + 1u) * K64_TG_K;
            for (uint off = tid; off < A_TILE; off += 1024u) {
                const uint r = off / K64_TG_K;
                const uint c_idx = off % K64_TG_K;
                const uint a_row = block_row_base + r;
                const uint a_col = k_base + c_idx;
                As[s_next][off] = (a_row < M && a_col < K) ? a[a_row * K + a_col] : half(0.0);
            }
            for (uint off = tid; off < B_TILE; off += 1024u) {
                const uint r = off / K64_TG_N;
                const uint c_idx = off % K64_TG_N;
                const uint b_row = k_base + r;
                const uint b_col = block_col_base + c_idx;
                Bs[s_next][off] = (b_row < K && b_col < N) ? b[b_row * N + b_col] : half(0.0);
            }
        }

        const uint K8_INNER = K64_TG_K / 8u;
        for (uint kk2 = 0u; kk2 < K8_INNER; ++kk2) {
            simdgroup_matrix<half, 8, 8> Amat;
            simdgroup_matrix<half, 8, 8> Bmat0;
            simdgroup_matrix<half, 8, 8> Bmat1;
            simdgroup_load(Amat, As[s_use], ulong(K64_TG_K),
                           ulong2(ulong(kk2 * 8u), ulong(sg_y * 8u)), false);
            simdgroup_load(Bmat0, Bs[s_use], ulong(K64_TG_N),
                           ulong2(ulong(sg_x0 * 8u), ulong(kk2 * 8u)), false);
            simdgroup_load(Bmat1, Bs[s_use], ulong(K64_TG_N),
                           ulong2(ulong(sg_x1 * 8u), ulong(kk2 * 8u)), false);
            simdgroup_multiply_accumulate(Cmat0, Amat, Bmat0, Cmat0);
            simdgroup_multiply_accumulate(Cmat1, Amat, Bmat1, Cmat1);
        }

        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    const uint row_base  = block_row_base + sg_y  * 8u;
    const uint col_base0 = block_col_base + sg_x0 * 8u;
    const uint col_base1 = block_col_base + sg_x1 * 8u;
    if (row_base < M) {
        if (col_base0 < N) {
            simdgroup_store(Cmat0, c, ulong(N),
                            ulong2(ulong(col_base0), ulong(row_base)), false);
        }
        if (col_base1 < N) {
            simdgroup_store(Cmat1, c, ulong(N),
                            ulong2(ulong(col_base1), ulong(row_base)), false);
        }
    }
}

// ===========================================================================
// Kernel B: simdgroup_matmul_64x64_async_swpipe — SW-pipelined inner K-loop
// (hoist all 4 A + 8 B simdgroup_loads above the 8 FMAs)
// ===========================================================================
kernel void simdgroup_matmul_64x64_async_swpipe(
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
    const uint block_row_base = tgid.y * K64_TG_M;
    const uint block_col_base = tgid.x * K64_TG_N;

    const uint sg_y  = sgid >> 2u;
    const uint sg_xp = sgid & 3u;
    const uint sg_x0 = sg_xp * 2u;
    const uint sg_x1 = sg_xp * 2u + 1u;

    threadgroup half As[2][K64_TG_M * K64_TG_K];
    threadgroup half Bs[2][K64_TG_K * K64_TG_N];

    simdgroup_matrix<float, 8, 8> Cmat0 = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
    simdgroup_matrix<float, 8, 8> Cmat1 = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);

    const uint tid     = sgid * 32u + slid;
    const uint K_step  = K / K64_TG_K;
    const uint A_TILE  = K64_TG_M * K64_TG_K;
    const uint B_TILE  = K64_TG_K * K64_TG_N;

    // Prologue.
    {
        const uint k_base = 0u;
        for (uint off = tid; off < A_TILE; off += 1024u) {
            const uint r = off / K64_TG_K;
            const uint c_idx = off % K64_TG_K;
            const uint a_row = block_row_base + r;
            const uint a_col = k_base + c_idx;
            As[0][off] = (a_row < M && a_col < K) ? a[a_row * K + a_col] : half(0.0);
        }
        for (uint off = tid; off < B_TILE; off += 1024u) {
            const uint r = off / K64_TG_N;
            const uint c_idx = off % K64_TG_N;
            const uint b_row = k_base + r;
            const uint b_col = block_col_base + c_idx;
            Bs[0][off] = (b_row < K && b_col < N) ? b[b_row * N + b_col] : half(0.0);
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint kk = 0u; kk < K_step; ++kk) {
        const uint s_use  = kk & 1u;
        const uint s_next = (kk + 1u) & 1u;

        if (kk + 1u < K_step) {
            const uint k_base = (kk + 1u) * K64_TG_K;
            for (uint off = tid; off < A_TILE; off += 1024u) {
                const uint r = off / K64_TG_K;
                const uint c_idx = off % K64_TG_K;
                const uint a_row = block_row_base + r;
                const uint a_col = k_base + c_idx;
                As[s_next][off] = (a_row < M && a_col < K) ? a[a_row * K + a_col] : half(0.0);
            }
            for (uint off = tid; off < B_TILE; off += 1024u) {
                const uint r = off / K64_TG_N;
                const uint c_idx = off % K64_TG_N;
                const uint b_row = k_base + r;
                const uint b_col = block_col_base + c_idx;
                Bs[s_next][off] = (b_row < K && b_col < N) ? b[b_row * N + b_col] : half(0.0);
            }
        }

        // SW-pipelined inner K-loop: hoist all 4 A + 8 B simdgroup_loads.
        simdgroup_matrix<half, 8, 8> A0, A1, A2, A3;
        simdgroup_matrix<half, 8, 8> B0_0, B0_1, B1_0, B1_1;
        simdgroup_matrix<half, 8, 8> B2_0, B2_1, B3_0, B3_1;
        simdgroup_load(A0,  As[s_use], ulong(K64_TG_K), ulong2(0u,  ulong(sg_y * 8u)), false);
        simdgroup_load(A1,  As[s_use], ulong(K64_TG_K), ulong2(8u,  ulong(sg_y * 8u)), false);
        simdgroup_load(A2,  As[s_use], ulong(K64_TG_K), ulong2(16u, ulong(sg_y * 8u)), false);
        simdgroup_load(A3,  As[s_use], ulong(K64_TG_K), ulong2(24u, ulong(sg_y * 8u)), false);
        simdgroup_load(B0_0, Bs[s_use], ulong(K64_TG_N), ulong2(ulong(sg_x0 * 8u), 0u),  false);
        simdgroup_load(B0_1, Bs[s_use], ulong(K64_TG_N), ulong2(ulong(sg_x1 * 8u), 0u),  false);
        simdgroup_load(B1_0, Bs[s_use], ulong(K64_TG_N), ulong2(ulong(sg_x0 * 8u), 8u),  false);
        simdgroup_load(B1_1, Bs[s_use], ulong(K64_TG_N), ulong2(ulong(sg_x1 * 8u), 8u),  false);
        simdgroup_load(B2_0, Bs[s_use], ulong(K64_TG_N), ulong2(ulong(sg_x0 * 8u), 16u), false);
        simdgroup_load(B2_1, Bs[s_use], ulong(K64_TG_N), ulong2(ulong(sg_x1 * 8u), 16u), false);
        simdgroup_load(B3_0, Bs[s_use], ulong(K64_TG_N), ulong2(ulong(sg_x0 * 8u), 24u), false);
        simdgroup_load(B3_1, Bs[s_use], ulong(K64_TG_N), ulong2(ulong(sg_x1 * 8u), 24u), false);

        simdgroup_multiply_accumulate(Cmat0, A0, B0_0, Cmat0);
        simdgroup_multiply_accumulate(Cmat1, A0, B0_1, Cmat1);
        simdgroup_multiply_accumulate(Cmat0, A1, B1_0, Cmat0);
        simdgroup_multiply_accumulate(Cmat1, A1, B1_1, Cmat1);
        simdgroup_multiply_accumulate(Cmat0, A2, B2_0, Cmat0);
        simdgroup_multiply_accumulate(Cmat1, A2, B2_1, Cmat1);
        simdgroup_multiply_accumulate(Cmat0, A3, B3_0, Cmat0);
        simdgroup_multiply_accumulate(Cmat1, A3, B3_1, Cmat1);

        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    const uint row_base  = block_row_base + sg_y  * 8u;
    const uint col_base0 = block_col_base + sg_x0 * 8u;
    const uint col_base1 = block_col_base + sg_x1 * 8u;
    if (row_base < M) {
        if (col_base0 < N) {
            simdgroup_store(Cmat0, c, ulong(N),
                            ulong2(ulong(col_base0), ulong(row_base)), false);
        }
        if (col_base1 < N) {
            simdgroup_store(Cmat1, c, ulong(N),
                            ulong2(ulong(col_base1), ulong(row_base)), false);
        }
    }
}

// ===========================================================================
// Kernel C: simdgroup_matmul_64x64_async_split — fine-grained load interleave
// (issue 1/4 of next-slot device-tg copy in each inner MMA substep)
// ===========================================================================
kernel void simdgroup_matmul_64x64_async_split(
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
    const uint block_row_base = tgid.y * K64_TG_M;
    const uint block_col_base = tgid.x * K64_TG_N;

    const uint sg_y  = sgid >> 2u;
    const uint sg_xp = sgid & 3u;
    const uint sg_x0 = sg_xp * 2u;
    const uint sg_x1 = sg_xp * 2u + 1u;

    threadgroup half As[2][K64_TG_M * K64_TG_K];
    threadgroup half Bs[2][K64_TG_K * K64_TG_N];

    simdgroup_matrix<float, 8, 8> Cmat0 = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
    simdgroup_matrix<float, 8, 8> Cmat1 = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);

    const uint tid     = sgid * 32u + slid;
    const uint K_step  = K / K64_TG_K;
    const uint A_TILE  = K64_TG_M * K64_TG_K;
    const uint B_TILE  = K64_TG_K * K64_TG_N;

    // Prologue.
    {
        for (uint off = tid; off < A_TILE; off += 1024u) {
            const uint r = off / K64_TG_K;
            const uint c_idx = off % K64_TG_K;
            const uint a_row = block_row_base + r;
            As[0][off] = (a_row < M && c_idx < K) ? a[a_row * K + c_idx] : half(0.0);
        }
        for (uint off = tid; off < B_TILE; off += 1024u) {
            const uint r = off / K64_TG_N;
            const uint c_idx = off % K64_TG_N;
            const uint b_col = block_col_base + c_idx;
            Bs[0][off] = (r < K && b_col < N) ? b[r * N + b_col] : half(0.0);
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint kk = 0u; kk < K_step; ++kk) {
        const uint s_use  = kk & 1u;
        const uint s_next = (kk + 1u) & 1u;

        const bool have_next = (kk + 1u < K_step);
        const uint k_base_next = (kk + 1u) * K64_TG_K;

        const uint K8_INNER = K64_TG_K / 8u;
        // Each inner substep: bring in 1/4 of next-slot A and 1/4 of next-slot B.
        // 1/4 of A_TILE = 512 halves; 1024 threads → 1 half per ~2 threads; do
        // simple stride-1024 for the kk2-th quarter (off range [kk2*512, kk2*512+512)).
        for (uint kk2 = 0u; kk2 < K8_INNER; ++kk2) {
            if (have_next) {
                const uint off_a = kk2 * 512u + tid;
                if (off_a < A_TILE && off_a < (kk2 + 1u) * 512u) {
                    const uint r = off_a / K64_TG_K;
                    const uint c_idx = off_a % K64_TG_K;
                    const uint a_row = block_row_base + r;
                    const uint a_col = k_base_next + c_idx;
                    As[s_next][off_a] = (a_row < M && a_col < K) ? a[a_row * K + a_col] : half(0.0);
                }
                const uint off_b = kk2 * 512u + tid;
                if (off_b < B_TILE && off_b < (kk2 + 1u) * 512u) {
                    const uint r = off_b / K64_TG_N;
                    const uint c_idx = off_b % K64_TG_N;
                    const uint b_row = k_base_next + r;
                    const uint b_col = block_col_base + c_idx;
                    Bs[s_next][off_b] = (b_row < K && b_col < N) ? b[b_row * N + b_col] : half(0.0);
                }
            }

            // MMA substep on current slot.
            simdgroup_matrix<half, 8, 8> Amat;
            simdgroup_matrix<half, 8, 8> Bmat0;
            simdgroup_matrix<half, 8, 8> Bmat1;
            simdgroup_load(Amat,  As[s_use], ulong(K64_TG_K),
                           ulong2(ulong(kk2 * 8u), ulong(sg_y * 8u)), false);
            simdgroup_load(Bmat0, Bs[s_use], ulong(K64_TG_N),
                           ulong2(ulong(sg_x0 * 8u), ulong(kk2 * 8u)), false);
            simdgroup_load(Bmat1, Bs[s_use], ulong(K64_TG_N),
                           ulong2(ulong(sg_x1 * 8u), ulong(kk2 * 8u)), false);
            simdgroup_multiply_accumulate(Cmat0, Amat, Bmat0, Cmat0);
            simdgroup_multiply_accumulate(Cmat1, Amat, Bmat1, Cmat1);
        }

        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    const uint row_base  = block_row_base + sg_y  * 8u;
    const uint col_base0 = block_col_base + sg_x0 * 8u;
    const uint col_base1 = block_col_base + sg_x1 * 8u;
    if (row_base < M) {
        if (col_base0 < N) {
            simdgroup_store(Cmat0, c, ulong(N),
                            ulong2(ulong(col_base0), ulong(row_base)), false);
        }
        if (col_base1 < N) {
            simdgroup_store(Cmat1, c, ulong(N),
                            ulong2(ulong(col_base1), ulong(row_base)), false);
        }
    }
}
