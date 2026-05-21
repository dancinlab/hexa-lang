// simdgroup_matmul_96x64_unroll.metal — RFC 075 Apple M3 GEMM optimization fire
//
// Goal: close the remaining 11% MPS gap from N37 (peak 1518 GFLOPS @ 1024^3, DB
// variant, 64x64 tile). N42 confirmed gap is NOT load-latency-bound (async-copy
// SW emulation gave 1.0x parity). Remaining 11% should be compute-side, so we
// attack with two optimisations:
//   (a) bigger tile (96x64 rectangular — 96x96 exceeds 32 KiB threadgroup mem)
//   (b) K-loop unroll (TG_K=64 instead of 32) for register-resident accumulator
//       reuse and amortized barrier cost.
//
// Three variants, all FP16 inputs + FP32 accumulator (same recipe as N37):
//
//   V1: simdgroup_matmul_96x64_tg_db
//       96x64 output tile, TG_K=32, double-buffered.
//       96x64 = 12*8 = 96 sub-tiles. 32 SGs (4 row x 8 col) → 3 sub-tiles/SG
//       (all 3 owned in M direction; shared B-load per inner step).
//       TG mem: 2*(96*32 halves + 32*64 halves) = 2*(6+4)=20 KiB / 32 KiB ✓
//
//   V2: simdgroup_matmul_64x64_kunroll2
//       64x64 output tile, TG_K=64, single-buffered.
//       Same 32-SG (8 row x 4 col-pair) topology as N37, but each outer iter
//       processes K8_INNER=8 substeps instead of 4 (explicit K-loop unroll 2x).
//       TG mem: 1*(64*64 halves + 64*64 halves) = 16 KiB / 32 KiB ✓
//
//   V3: simdgroup_matmul_96x64_kunroll2
//       96x64 output tile, TG_K=64, single-buffered.
//       Combines (a) + (b). TG mem: 1*(96*64 + 64*64 halves) = 12+8=20 KiB ✓
//
// All kernels dispatch with 1024 threads = 32 simdgroups per threadgroup.
//
// References:
//   - N37 (rfc075_metal_simdgroup_matmul_64x64_2026_05_21): peak 1518.73 GFLOPS
//     @ 1024^3 (64x64 tile + DB).
//   - N42 (rfc075_metal_async_copy_2026_05_21): SW-emulated async copy 1.0x N37
//     (load latency is NOT the bottleneck).
//   - MPS FP32 anchor: 1702.75 GFLOPS @ 1024^3.
//   - Apple M3 advertised peak FP32: ~3500 GFLOPS.

#include <metal_stdlib>
#include <metal_simdgroup_matrix>
using namespace metal;

// ---------------------------------------------------------------------------
// V1: simdgroup_matmul_96x64_tg_db — 96x64 tile, TG_K=32, double-buffered.
// ---------------------------------------------------------------------------
// Output tile: 96 rows x 64 cols = 96 sub-tiles (12*8).
// 32 simdgroups arranged as 4 row groups x 8 col groups.
//   sg_y = sgid / 8  (0..3) → owns sub-tile rows {3*sg_y, 3*sg_y+1, 3*sg_y+2}
//   sg_x = sgid % 8  (0..7) → owns sub-tile col sg_x
// Each SG holds 3 FP32 8x8 accumulators (M-stacked column).
//
// Per inner K8 step: 1 B load (shared across 3 M rows) + 3 A loads (one per
// owned sub-tile row) + 3 simdgroup_multiply_accumulate calls.
// ---------------------------------------------------------------------------
constant constexpr uint V1_TG_M  = 96;
constant constexpr uint V1_TG_N  = 64;
constant constexpr uint V1_TG_K  = 32;
constant constexpr uint V1_A_TILE = V1_TG_M * V1_TG_K;   // 96*32 = 3072 halves = 6 KiB
constant constexpr uint V1_B_TILE = V1_TG_K * V1_TG_N;   // 32*64 = 2048 halves = 4 KiB

kernel void simdgroup_matmul_96x64_tg_db(
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
    const uint block_row_base = tgid.y * V1_TG_M;
    const uint block_col_base = tgid.x * V1_TG_N;

    // 32 SGs = 4 (M, x3 sub-tile stack) x 8 (N)
    const uint sg_y = sgid >> 3u;             // 0..3
    const uint sg_x = sgid & 7u;              // 0..7
    const uint row_base0 = block_row_base + (sg_y * 3u + 0u) * 8u;
    const uint row_base1 = block_row_base + (sg_y * 3u + 1u) * 8u;
    const uint row_base2 = block_row_base + (sg_y * 3u + 2u) * 8u;
    const uint col_base  = block_col_base + sg_x * 8u;

    threadgroup half As[2][V1_A_TILE];        // 2x 6 KiB
    threadgroup half Bs[2][V1_B_TILE];        // 2x 4 KiB

    simdgroup_matrix<float, 8, 8> Cmat0 = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
    simdgroup_matrix<float, 8, 8> Cmat1 = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
    simdgroup_matrix<float, 8, 8> Cmat2 = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);

    const uint tid    = sgid * 32u + slid;
    const uint K_step = K / V1_TG_K;

    auto load_slot = [&](uint s, uint kk) {
        const uint k_base = kk * V1_TG_K;
        for (uint off = tid; off < V1_A_TILE; off += 1024u) {
            const uint r = off / V1_TG_K;
            const uint c_idx = off % V1_TG_K;
            const uint a_row = block_row_base + r;
            const uint a_col = k_base + c_idx;
            As[s][off] = (a_row < M && a_col < K) ? a[a_row * K + a_col] : half(0.0);
        }
        for (uint off = tid; off < V1_B_TILE; off += 1024u) {
            const uint r = off / V1_TG_N;
            const uint c_idx = off % V1_TG_N;
            const uint b_row = k_base + r;
            const uint b_col = block_col_base + c_idx;
            Bs[s][off] = (b_row < K && b_col < N) ? b[b_row * N + b_col] : half(0.0);
        }
    };

    load_slot(0, 0);
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint kk = 0u; kk < K_step; ++kk) {
        const uint s_use  = kk & 1u;
        const uint s_next = (kk + 1u) & 1u;

        if (kk + 1u < K_step) {
            load_slot(s_next, kk + 1u);
        }

        const uint K8_INNER = V1_TG_K / 8u;       // = 4
        for (uint kk2 = 0u; kk2 < K8_INNER; ++kk2) {
            simdgroup_matrix<half, 8, 8> Amat0;
            simdgroup_matrix<half, 8, 8> Amat1;
            simdgroup_matrix<half, 8, 8> Amat2;
            simdgroup_matrix<half, 8, 8> Bmat;
            // Three A rows (M-stacked), one B col (shared across the stack).
            simdgroup_load(Amat0, As[s_use], ulong(V1_TG_K),
                           ulong2(ulong(kk2 * 8u), ulong((sg_y * 3u + 0u) * 8u)),
                           false);
            simdgroup_load(Amat1, As[s_use], ulong(V1_TG_K),
                           ulong2(ulong(kk2 * 8u), ulong((sg_y * 3u + 1u) * 8u)),
                           false);
            simdgroup_load(Amat2, As[s_use], ulong(V1_TG_K),
                           ulong2(ulong(kk2 * 8u), ulong((sg_y * 3u + 2u) * 8u)),
                           false);
            simdgroup_load(Bmat,  Bs[s_use], ulong(V1_TG_N),
                           ulong2(ulong(sg_x * 8u), ulong(kk2 * 8u)),
                           false);
            simdgroup_multiply_accumulate(Cmat0, Amat0, Bmat, Cmat0);
            simdgroup_multiply_accumulate(Cmat1, Amat1, Bmat, Cmat1);
            simdgroup_multiply_accumulate(Cmat2, Amat2, Bmat, Cmat2);
        }

        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (col_base < N) {
        if (row_base0 < M) {
            simdgroup_store(Cmat0, c, ulong(N),
                            ulong2(ulong(col_base), ulong(row_base0)), false);
        }
        if (row_base1 < M) {
            simdgroup_store(Cmat1, c, ulong(N),
                            ulong2(ulong(col_base), ulong(row_base1)), false);
        }
        if (row_base2 < M) {
            simdgroup_store(Cmat2, c, ulong(N),
                            ulong2(ulong(col_base), ulong(row_base2)), false);
        }
    }
}

// ---------------------------------------------------------------------------
// V2: simdgroup_matmul_64x64_kunroll2 — 64x64 tile, TG_K=64, single-buffered
// ---------------------------------------------------------------------------
// Same 32-SG (8 row x 4 col-pair) topology as N37 winner, but TG_K=64 (instead
// of 32) → each outer iteration carries 8 inner MMA substeps (K8_INNER=8)
// per SG-owned column. Total MMAs per outer iter = 8 * 2 (col pair) = 16.
// This amortizes barrier cost 2x and gives the compiler a longer in-flight
// chain of register-resident accumulator updates.
//
// TG mem: As 64*64 halves (8 KiB) + Bs 64*64 halves (8 KiB) = 16 KiB.
// (No DB version — DB would need 32 KiB which is right at the limit.)
// ---------------------------------------------------------------------------
constant constexpr uint V2_TG_M  = 64;
constant constexpr uint V2_TG_N  = 64;
constant constexpr uint V2_TG_K  = 64;
constant constexpr uint V2_A_TILE = V2_TG_M * V2_TG_K;   // 4096 halves = 8 KiB
constant constexpr uint V2_B_TILE = V2_TG_K * V2_TG_N;   // 4096 halves = 8 KiB

kernel void simdgroup_matmul_64x64_kunroll2(
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
    const uint block_row_base = tgid.y * V2_TG_M;
    const uint block_col_base = tgid.x * V2_TG_N;

    const uint sg_y  = sgid >> 2u;          // 0..7
    const uint sg_xp = sgid & 3u;           // 0..3 col-pair
    const uint sg_x0 = sg_xp * 2u;
    const uint sg_x1 = sg_xp * 2u + 1u;

    const uint row_base  = block_row_base + sg_y * 8u;
    const uint col_base0 = block_col_base + sg_x0 * 8u;
    const uint col_base1 = block_col_base + sg_x1 * 8u;

    threadgroup half As[V2_A_TILE];
    threadgroup half Bs[V2_B_TILE];

    simdgroup_matrix<float, 8, 8> Cmat0 = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
    simdgroup_matrix<float, 8, 8> Cmat1 = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);

    const uint tid    = sgid * 32u + slid;
    const uint K_step = K / V2_TG_K;          // outer iter count
    const uint K8_INNER = V2_TG_K / 8u;       // = 8

    for (uint kk = 0u; kk < K_step; ++kk) {
        // Cooperative load A slab 64x64 = 4096 halves; 1024 threads → 4/thread
        {
            const uint k_base = kk * V2_TG_K;
            for (uint off = tid; off < V2_A_TILE; off += 1024u) {
                const uint r = off / V2_TG_K;
                const uint c_idx = off % V2_TG_K;
                const uint a_row = block_row_base + r;
                const uint a_col = k_base + c_idx;
                As[off] = (a_row < M && a_col < K) ? a[a_row * K + a_col] : half(0.0);
            }
        }
        {
            const uint k_base = kk * V2_TG_K;
            for (uint off = tid; off < V2_B_TILE; off += 1024u) {
                const uint r = off / V2_TG_N;
                const uint c_idx = off % V2_TG_N;
                const uint b_row = k_base + r;
                const uint b_col = block_col_base + c_idx;
                Bs[off] = (b_row < K && b_col < N) ? b[b_row * N + b_col] : half(0.0);
            }
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);

        // Inner K-substep — 8 iterations (K-unroll 2x relative to N37 winner).
        for (uint kk2 = 0u; kk2 < K8_INNER; ++kk2) {
            simdgroup_matrix<half, 8, 8> Amat;
            simdgroup_matrix<half, 8, 8> Bmat0;
            simdgroup_matrix<half, 8, 8> Bmat1;
            simdgroup_load(Amat, As, ulong(V2_TG_K),
                           ulong2(ulong(kk2 * 8u), ulong(sg_y * 8u)),
                           false);
            simdgroup_load(Bmat0, Bs, ulong(V2_TG_N),
                           ulong2(ulong(sg_x0 * 8u), ulong(kk2 * 8u)),
                           false);
            simdgroup_load(Bmat1, Bs, ulong(V2_TG_N),
                           ulong2(ulong(sg_x1 * 8u), ulong(kk2 * 8u)),
                           false);
            simdgroup_multiply_accumulate(Cmat0, Amat, Bmat0, Cmat0);
            simdgroup_multiply_accumulate(Cmat1, Amat, Bmat1, Cmat1);
        }

        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

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

// ---------------------------------------------------------------------------
// V3: simdgroup_matmul_96x64_kunroll2 — 96x64 tile + TG_K=64, single-buffered
// ---------------------------------------------------------------------------
// Combines V1's larger output tile with V2's K-unroll. Single-buffered to fit
// in 32 KiB (DB would need 40 KiB).
//
// TG mem: As 96*64 halves (12 KiB) + Bs 64*64 halves (8 KiB) = 20 KiB.
// 32 SGs as 4 (M, x3 stack) x 8 (N). Inner K8_INNER=8.
// Per inner step: 3 A loads + 1 B load (shared) + 3 simdgroup MACs.
// Over K8_INNER=8 substeps: 24 A loads + 8 B loads + 24 MACs (per SG).
// ---------------------------------------------------------------------------
constant constexpr uint V3_TG_M  = 96;
constant constexpr uint V3_TG_N  = 64;
constant constexpr uint V3_TG_K  = 64;
constant constexpr uint V3_A_TILE = V3_TG_M * V3_TG_K;   // 96*64 = 6144 halves = 12 KiB
constant constexpr uint V3_B_TILE = V3_TG_K * V3_TG_N;   // 64*64 = 4096 halves = 8 KiB

kernel void simdgroup_matmul_96x64_kunroll2(
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
    const uint block_row_base = tgid.y * V3_TG_M;
    const uint block_col_base = tgid.x * V3_TG_N;

    const uint sg_y = sgid >> 3u;
    const uint sg_x = sgid & 7u;
    const uint row_base0 = block_row_base + (sg_y * 3u + 0u) * 8u;
    const uint row_base1 = block_row_base + (sg_y * 3u + 1u) * 8u;
    const uint row_base2 = block_row_base + (sg_y * 3u + 2u) * 8u;
    const uint col_base  = block_col_base + sg_x * 8u;

    threadgroup half As[V3_A_TILE];
    threadgroup half Bs[V3_B_TILE];

    simdgroup_matrix<float, 8, 8> Cmat0 = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
    simdgroup_matrix<float, 8, 8> Cmat1 = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
    simdgroup_matrix<float, 8, 8> Cmat2 = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);

    const uint tid    = sgid * 32u + slid;
    const uint K_step = K / V3_TG_K;
    const uint K8_INNER = V3_TG_K / 8u;          // = 8

    for (uint kk = 0u; kk < K_step; ++kk) {
        const uint k_base = kk * V3_TG_K;
        // Load A slab 96x64 = 6144 halves → 6/thread
        for (uint off = tid; off < V3_A_TILE; off += 1024u) {
            const uint r = off / V3_TG_K;
            const uint c_idx = off % V3_TG_K;
            const uint a_row = block_row_base + r;
            const uint a_col = k_base + c_idx;
            As[off] = (a_row < M && a_col < K) ? a[a_row * K + a_col] : half(0.0);
        }
        // Load B slab 64x64 = 4096 halves → 4/thread
        for (uint off = tid; off < V3_B_TILE; off += 1024u) {
            const uint r = off / V3_TG_N;
            const uint c_idx = off % V3_TG_N;
            const uint b_row = k_base + r;
            const uint b_col = block_col_base + c_idx;
            Bs[off] = (b_row < K && b_col < N) ? b[b_row * N + b_col] : half(0.0);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);

        for (uint kk2 = 0u; kk2 < K8_INNER; ++kk2) {
            simdgroup_matrix<half, 8, 8> Amat0;
            simdgroup_matrix<half, 8, 8> Amat1;
            simdgroup_matrix<half, 8, 8> Amat2;
            simdgroup_matrix<half, 8, 8> Bmat;
            simdgroup_load(Amat0, As, ulong(V3_TG_K),
                           ulong2(ulong(kk2 * 8u), ulong((sg_y * 3u + 0u) * 8u)),
                           false);
            simdgroup_load(Amat1, As, ulong(V3_TG_K),
                           ulong2(ulong(kk2 * 8u), ulong((sg_y * 3u + 1u) * 8u)),
                           false);
            simdgroup_load(Amat2, As, ulong(V3_TG_K),
                           ulong2(ulong(kk2 * 8u), ulong((sg_y * 3u + 2u) * 8u)),
                           false);
            simdgroup_load(Bmat,  Bs, ulong(V3_TG_N),
                           ulong2(ulong(sg_x * 8u), ulong(kk2 * 8u)),
                           false);
            simdgroup_multiply_accumulate(Cmat0, Amat0, Bmat, Cmat0);
            simdgroup_multiply_accumulate(Cmat1, Amat1, Bmat, Cmat1);
            simdgroup_multiply_accumulate(Cmat2, Amat2, Bmat, Cmat2);
        }

        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (col_base < N) {
        if (row_base0 < M) {
            simdgroup_store(Cmat0, c, ulong(N),
                            ulong2(ulong(col_base), ulong(row_base0)), false);
        }
        if (row_base1 < M) {
            simdgroup_store(Cmat1, c, ulong(N),
                            ulong2(ulong(col_base), ulong(row_base1)), false);
        }
        if (row_base2 < M) {
            simdgroup_store(Cmat2, c, ulong(N),
                            ulong2(ulong(col_base), ulong(row_base2)), false);
        }
    }
}
