// simdgroup_matmul_64x64_tg.metal — RFC 075 Apple M3 64×64 threadgroup-tile MMA fire
//
// Goal: push past N30's 32×32_tg mixed-prec peak of 986.97 GFLOPS @ 1024³ toward
// closing the MPS 1.7 TFLOPS gap. Larger output tile per threadgroup → more
// arithmetic per loaded byte (better arithmetic intensity), fewer threadgroup
// dispatches.
//
// Topology choice — 64×64 output tile, FP16 inputs, FP32 accumulator
// (mixed-precision per N30 commit 99aed70f).
//
// Threadgroup organization:
//   - Output tile = 64×64 = 4096 elements, decomposed into 64 sub-tiles of 8×8.
//   - Max threads/TG on Apple M3 = 1024 = 32 simdgroups (32-thread SIMD width).
//   - 64 sub-tiles / 32 simdgroups = 2 sub-tiles owned per simdgroup.
//     → 2 FP32 accumulator registers per simdgroup (8×8 each).
//   - We arrange 32 simdgroups as 8 (M direction) × 4 (N direction); each SG
//     owns a column-pair of sub-tiles: at row sg_y in {0..7} and col-pair
//     sg_x in {0..3}, the SG computes output sub-tiles (sg_y, 2*sg_x) and
//     (sg_y, 2*sg_x + 1). This keeps the two C accumulators contiguous in
//     N, which lets a single Bmat load feed both MACs (we still issue two
//     B loads since the column offsets differ; the A load is shared).
//
// K-loop choice — TG_K = 32:
//   - threadgroup mem As: 64 × 32 = 2048 halves = 4096 B
//   - threadgroup mem Bs: 32 × 64 = 2048 halves = 4096 B
//   - total = 8 KiB / 32 KiB budget → 24 KiB headroom (enables double-buffer in
//     the companion .db kernel)
//   - Per cooperative load: 1024 threads · 1 half each → exactly one half per
//     thread for A and one for B (32-half stripe per thread? no — 2048 halves
//     and 1024 threads = 2 halves per thread; we use a stride-1024 loop).
//   - K-loop iterates K/32 times. At K=1024 that's 32 outer iters carrying
//     4 inner MMAs (32/8) × 64 output sub-tiles × ½ (since two-per-SG counted
//     once) = simpler: each outer iter does (32/8)=4 MMA "k-substeps", and at
//     each substep each SG issues 2 simdgroup_multiply_accumulate calls.
//
// Dispatch:
//   threads_per_threadgroup = (32, 32, 1) = 1024 threads = 32 simdgroups
//   threadgroup_position_in_grid spans ( (N+63)/64, (M+63)/64, 1 )
//   threads_per_grid = ( ((N+63)/64) * 32, ((M+63)/64) * 32, 1 )
//
// FP precision: identical to N30 mixed-prec form. FP32 accumulator means
// only FP16 input rounding contributes error.

#include <metal_stdlib>
#include <metal_simdgroup_matrix>
using namespace metal;

// ---------------------------------------------------------------------------
// Kernel: simdgroup_matmul_64x64_tg — 64×64 output via 32 simdgroups
// ---------------------------------------------------------------------------
constant constexpr uint K64_TG_M = 64;
constant constexpr uint K64_TG_N = 64;
constant constexpr uint K64_TG_K = 32;

kernel void simdgroup_matmul_64x64_tg(
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

    // 32 simdgroups = 8 (M) × 4 (N) → each SG owns column-pair (8×8 sub-tiles).
    const uint sg_y  = sgid >> 2u;          // 0..7  (M-axis sub-tile row)
    const uint sg_xp = sgid & 3u;           // 0..3  (N-axis sub-tile col PAIR)
    const uint sg_x0 = sg_xp * 2u;          // 0,2,4,6
    const uint sg_x1 = sg_xp * 2u + 1u;     // 1,3,5,7

    const uint row_base = block_row_base + sg_y  * 8u;
    const uint col_base0 = block_col_base + sg_x0 * 8u;
    const uint col_base1 = block_col_base + sg_x1 * 8u;

    threadgroup half As[K64_TG_M * K64_TG_K];   // 64×32 halves = 4 KiB
    threadgroup half Bs[K64_TG_K * K64_TG_N];   // 32×64 halves = 4 KiB

    // Two FP32 accumulators per simdgroup (column-pair).
    simdgroup_matrix<float, 8, 8> Cmat0 = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
    simdgroup_matrix<float, 8, 8> Cmat1 = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);

    const uint tid     = sgid * 32u + slid;     // 0..1023 linear TID
    const uint K_step  = K / K64_TG_K;          // outer K-loop count

    for (uint kk = 0u; kk < K_step; ++kk) {
        // Cooperative load of A slab [TG_M × TG_K] = 64*32 = 2048 halves.
        // 1024 threads → 2 halves/thread.
        // Layout in As: row-major row * TG_K + col.
        // Stride-1024 walk so consecutive threads grab consecutive halves
        // (coalesced device read).
        {
            const uint A_TILE = K64_TG_M * K64_TG_K;  // 2048
            const uint k_base = kk * K64_TG_K;
            // Load 2 halves per thread.
            for (uint off = tid; off < A_TILE; off += 1024u) {
                const uint r = off / K64_TG_K;
                const uint c_idx = off % K64_TG_K;
                const uint a_row = block_row_base + r;
                const uint a_col = k_base + c_idx;
                As[off] = (a_row < M && a_col < K) ? a[a_row * K + a_col] : half(0.0);
            }
        }
        // Cooperative load of B slab [TG_K × TG_N] = 32*64 = 2048 halves.
        {
            const uint B_TILE = K64_TG_K * K64_TG_N;  // 2048
            const uint k_base = kk * K64_TG_K;
            for (uint off = tid; off < B_TILE; off += 1024u) {
                const uint r = off / K64_TG_N;
                const uint c_idx = off % K64_TG_N;
                const uint b_row = k_base + r;
                const uint b_col = block_col_base + c_idx;
                Bs[off] = (b_row < K && b_col < N) ? b[b_row * N + b_col] : half(0.0);
            }
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);

        // Inner K-substep loop: TG_K / 8 = 4 MMA steps.
        const uint K8_INNER = K64_TG_K / 8u;
        for (uint kk2 = 0u; kk2 < K8_INNER; ++kk2) {
            simdgroup_matrix<half, 8, 8> Amat;
            simdgroup_matrix<half, 8, 8> Bmat0;
            simdgroup_matrix<half, 8, 8> Bmat1;
            // A is shared across both columns of the pair → one load.
            simdgroup_load(Amat, As, ulong(K64_TG_K),
                           ulong2(ulong(kk2 * 8u), ulong(sg_y * 8u)),
                           false);
            // Two B loads, one per column-half of the SG's owned pair.
            simdgroup_load(Bmat0, Bs, ulong(K64_TG_N),
                           ulong2(ulong(sg_x0 * 8u), ulong(kk2 * 8u)),
                           false);
            simdgroup_load(Bmat1, Bs, ulong(K64_TG_N),
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
                            ulong2(ulong(col_base0), ulong(row_base)),
                            false);
        }
        if (col_base1 < N) {
            simdgroup_store(Cmat1, c, ulong(N),
                            ulong2(ulong(col_base1), ulong(row_base)),
                            false);
        }
    }
}

// ---------------------------------------------------------------------------
// Kernel: simdgroup_matmul_64x64_tg_db — double-buffered variant
// ---------------------------------------------------------------------------
// Two slots for A and B in threadgroup memory. While the simdgroups compute
// on slot[(kk)&1], the loaders fill slot[(kk+1)&1] for the next iteration.
//
// Threadgroup memory:
//   2 × As (64×32 halves) = 8 KiB
//   2 × Bs (32×64 halves) = 8 KiB
//   total = 16 KiB / 32 KiB → fits with comfortable headroom.
//
// Pattern (classic prefetch):
//   - prologue: load slot 0 (kk=0)
//   - for kk in 0..K_step-1: if kk+1 < K_step prefetch slot[(kk+1)&1];
//       compute on slot[kk&1]
//   - epilogue: compute on slot[(K_step-1)&1]
// ---------------------------------------------------------------------------
kernel void simdgroup_matmul_64x64_tg_db(
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

    const uint row_base = block_row_base + sg_y  * 8u;
    const uint col_base0 = block_col_base + sg_x0 * 8u;
    const uint col_base1 = block_col_base + sg_x1 * 8u;

    threadgroup half As[2][K64_TG_M * K64_TG_K];   // 2× 4 KiB
    threadgroup half Bs[2][K64_TG_K * K64_TG_N];   // 2× 4 KiB

    simdgroup_matrix<float, 8, 8> Cmat0 = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
    simdgroup_matrix<float, 8, 8> Cmat1 = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);

    const uint tid     = sgid * 32u + slid;
    const uint K_step  = K / K64_TG_K;
    const uint A_TILE  = K64_TG_M * K64_TG_K;     // 2048
    const uint B_TILE  = K64_TG_K * K64_TG_N;     // 2048

    // ── Loader lambda: fills slot[s] for outer iteration kk.
    auto load_slot = [&](uint s, uint kk) {
        const uint k_base = kk * K64_TG_K;
        for (uint off = tid; off < A_TILE; off += 1024u) {
            const uint r = off / K64_TG_K;
            const uint c_idx = off % K64_TG_K;
            const uint a_row = block_row_base + r;
            const uint a_col = k_base + c_idx;
            As[s][off] = (a_row < M && a_col < K) ? a[a_row * K + a_col] : half(0.0);
        }
        for (uint off = tid; off < B_TILE; off += 1024u) {
            const uint r = off / K64_TG_N;
            const uint c_idx = off % K64_TG_N;
            const uint b_row = k_base + r;
            const uint b_col = block_col_base + c_idx;
            Bs[s][off] = (b_row < K && b_col < N) ? b[b_row * N + b_col] : half(0.0);
        }
    };

    // Prologue — load slot 0.
    load_slot(0, 0);
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint kk = 0u; kk < K_step; ++kk) {
        const uint s_use   = kk & 1u;
        const uint s_next  = (kk + 1u) & 1u;

        // Prefetch next slab if any next iteration exists.
        if (kk + 1u < K_step) {
            load_slot(s_next, kk + 1u);
        }

        // Inner MMA on s_use.
        const uint K8_INNER = K64_TG_K / 8u;
        for (uint kk2 = 0u; kk2 < K8_INNER; ++kk2) {
            simdgroup_matrix<half, 8, 8> Amat;
            simdgroup_matrix<half, 8, 8> Bmat0;
            simdgroup_matrix<half, 8, 8> Bmat1;
            simdgroup_load(Amat, As[s_use], ulong(K64_TG_K),
                           ulong2(ulong(kk2 * 8u), ulong(sg_y * 8u)),
                           false);
            simdgroup_load(Bmat0, Bs[s_use], ulong(K64_TG_N),
                           ulong2(ulong(sg_x0 * 8u), ulong(kk2 * 8u)),
                           false);
            simdgroup_load(Bmat1, Bs[s_use], ulong(K64_TG_N),
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
                            ulong2(ulong(col_base0), ulong(row_base)),
                            false);
        }
        if (col_base1 < N) {
            simdgroup_store(Cmat1, c, ulong(N),
                            ulong2(ulong(col_base1), ulong(row_base)),
                            false);
        }
    }
}
