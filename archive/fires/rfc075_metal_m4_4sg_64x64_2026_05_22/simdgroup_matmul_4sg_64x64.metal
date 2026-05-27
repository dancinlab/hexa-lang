// simdgroup_matmul_4sg_64x64.metal — N138 Apple M4 4-simdgroup 64×64 MMA fire
//
// Goal: port N107 NVPTX 4-warp 64×64 pattern (peak 51.65 TFLOPS @ M=1536, ratio
// 0.777 on RTX 5070) to Apple Metal MSL. N107 found dominant axis on Nvidia =
// tile-shrink + few-warps (32 → 4 warps/CTA → 1×→8× CTA/SM occupancy lift).
//
// Question: does the same compounding pattern (4 SIMD-groups × 32 threads = 128
// threads/threadgroup, 64×64 output tile) win on Apple M4 GPU architecture, or
// does it regress (M4's GPU has different occupancy/scheduler/register file)?
//
// N133 measured M4 baseline (32-simdgroup 64×64 db): peak 1858.35 GFLOPS @ 1024³.
// This 4-simdgroup variant tests whether shrinking from 32 → 4 simdgroups/TG —
// while keeping the same 64×64 output tile — compounds, plateaus, or regresses.
//
// Topology — 64×64 output / threadgroup, 4 simdgroups in 2×2 grid:
//   - Threadgroup = 4 simdgroups × 32 threads = 128 threads (vs N133's 1024).
//   - Each simdgroup owns 32M × 32N sub-tile = 16 (= 4×4) sub-tiles of 8×8.
//   - Layout: sg_y = sgid >> 1 (0..1, M-axis), sg_x = sgid & 1 (0..1, N-axis).
//   - 16 FP32 accumulators per simdgroup (8×8 each) — register pressure axis
//     under test on M4.
//
// K-loop — TG_K = 16 (mirrors N107's K=16/step):
//   - threadgroup mem As: 64 × 16 = 1024 halves = 2 KiB
//   - threadgroup mem Bs: 16 × 64 = 1024 halves = 2 KiB
//   - total = 4 KiB single-buffer / 8 KiB double-buffer (well below 32 KiB M4 limit)
//   - Per cooperative load: 128 threads · 8 halves each → 1024 halves total. Use
//     stride-128 walk so consecutive threads grab consecutive halves (coalesced).
//
// Inner K-step (8 simdgroup_matrix MMAs per simdgroup per K-substep):
//   - K_INNER = TG_K / 8 = 2 (one per K-substep of 8 elements).
//   - Per inner step: each SG does 4×4 = 16 MMAs (one per 8×8 sub-tile).
//   - Total MMAs/SG/K-outer-step = 2 × 16 = 32. Mirrors N107's 8 mma/warp/K-step
//     but Apple's 8×8×8 vs Nvidia's m16n8k16 means we issue more MMAs.
//
// Dispatch:
//   threads_per_threadgroup = (4, 32, 1) = 128 threads = 4 simdgroups
//   threadgroup_position_in_grid spans ( (N+63)/64, (M+63)/64, 1 )
//   threads_per_grid = ( ((N+63)/64) * 4, ((M+63)/64) * 32, 1 )
//
// FP precision: identical to N133 mixed-prec (FP16 inputs + FP32 accumulator).
// rel_err < 1e-4 gate.

#include <metal_stdlib>
#include <metal_simdgroup_matrix>
using namespace metal;

constant constexpr uint TG_M = 64;
constant constexpr uint TG_N = 64;
constant constexpr uint TG_K = 16;

// ---------------------------------------------------------------------------
// Kernel: simdgroup_matmul_4sg_64x64 — single-buffer
// ---------------------------------------------------------------------------
kernel void simdgroup_matmul_4sg_64x64(
    device   const half*   a    [[buffer(0)]],
    device   const half*   b    [[buffer(1)]],
    device         float*  c    [[buffer(2)]],
    constant       uint&   M    [[buffer(3)]],
    constant       uint&   N    [[buffer(4)]],
    constant       uint&   K    [[buffer(5)]],
    uint2  tgid    [[threadgroup_position_in_grid]],
    uint   sgid    [[simdgroup_index_in_threadgroup]],
    uint   slid    [[thread_index_in_simdgroup]])
{
    const uint block_row_base = tgid.y * TG_M;
    const uint block_col_base = tgid.x * TG_N;

    // 4 simdgroups in 2×2: sg_y selects M-band (32 rows), sg_x selects N-band.
    const uint sg_y = sgid >> 1u;      // 0..1
    const uint sg_x = sgid & 1u;       // 0..1
    const uint row_warp_base = block_row_base + sg_y * 32u;
    const uint col_warp_base = block_col_base + sg_x * 32u;

    threadgroup half As[TG_M * TG_K];   // 64 × 16 halves = 2 KiB
    threadgroup half Bs[TG_K * TG_N];   // 16 × 64 halves = 2 KiB

    // 16 FP32 accumulators per simdgroup = 4×4 grid of 8×8 sub-tiles spanning
    // 32M × 32N output. Index layout: C[sub_m][sub_n] where sub_m,sub_n in 0..3.
    simdgroup_matrix<float, 8, 8> Cmat[4][4];
    for (uint i = 0u; i < 4u; ++i)
        for (uint j = 0u; j < 4u; ++j)
            Cmat[i][j] = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);

    const uint tid    = sgid * 32u + slid;        // 0..127 linear TID
    const uint K_step = K / TG_K;                 // outer K-loop count

    // Slabs: A=1024 halves, B=1024 halves; 128 threads → 8 halves/thread.
    const uint A_TILE = TG_M * TG_K;
    const uint B_TILE = TG_K * TG_N;

    for (uint kk = 0u; kk < K_step; ++kk) {
        const uint k_base = kk * TG_K;

        // Cooperative load A slab [64 × 16] — 8 halves per thread, stride 128.
        for (uint off = tid; off < A_TILE; off += 128u) {
            const uint r = off / TG_K;
            const uint c_idx = off % TG_K;
            const uint a_row = block_row_base + r;
            const uint a_col = k_base + c_idx;
            As[off] = (a_row < M && a_col < K) ? a[a_row * K + a_col] : half(0.0);
        }
        // Cooperative load B slab [16 × 64].
        for (uint off = tid; off < B_TILE; off += 128u) {
            const uint r = off / TG_N;
            const uint c_idx = off % TG_N;
            const uint b_row = k_base + r;
            const uint b_col = block_col_base + c_idx;
            Bs[off] = (b_row < K && b_col < N) ? b[b_row * N + b_col] : half(0.0);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);

        // Inner K-substep: TG_K / 8 = 2 substeps.
        const uint K8_INNER = TG_K / 8u;
        for (uint kk2 = 0u; kk2 < K8_INNER; ++kk2) {
            // Load 4 A sub-tiles (one per sub_m row of warp's 32M band).
            simdgroup_matrix<half, 8, 8> Amat[4];
            for (uint sub_m = 0u; sub_m < 4u; ++sub_m) {
                simdgroup_load(Amat[sub_m], As, ulong(TG_K),
                               ulong2(ulong(kk2 * 8u),
                                      ulong(sg_y * 32u + sub_m * 8u)),
                               false);
            }
            // Load 4 B sub-tiles (one per sub_n column of warp's 32N band).
            simdgroup_matrix<half, 8, 8> Bmat[4];
            for (uint sub_n = 0u; sub_n < 4u; ++sub_n) {
                simdgroup_load(Bmat[sub_n], Bs, ulong(TG_N),
                               ulong2(ulong(sg_x * 32u + sub_n * 8u),
                                      ulong(kk2 * 8u)),
                               false);
            }
            // 4×4 = 16 simdgroup_multiply_accumulate.
            for (uint sub_m = 0u; sub_m < 4u; ++sub_m) {
                for (uint sub_n = 0u; sub_n < 4u; ++sub_n) {
                    simdgroup_multiply_accumulate(
                        Cmat[sub_m][sub_n],
                        Amat[sub_m], Bmat[sub_n],
                        Cmat[sub_m][sub_n]);
                }
            }
        }

        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    // Store accumulators back to C: 4×4 sub-tile grid spans (sg_y*32 + sub_m*8,
    // sg_x*32 + sub_n*8) at row,col base.
    for (uint sub_m = 0u; sub_m < 4u; ++sub_m) {
        const uint row_base = row_warp_base + sub_m * 8u;
        if (row_base >= M) break;
        for (uint sub_n = 0u; sub_n < 4u; ++sub_n) {
            const uint col_base = col_warp_base + sub_n * 8u;
            if (col_base >= N) continue;
            simdgroup_store(Cmat[sub_m][sub_n], c, ulong(N),
                            ulong2(ulong(col_base), ulong(row_base)),
                            false);
        }
    }
}

// ---------------------------------------------------------------------------
// Kernel: simdgroup_matmul_4sg_64x64_db — double-buffered variant
// ---------------------------------------------------------------------------
// Two slots for A and B in threadgroup memory. Pattern mirrors N133 db variant
// but with 4 simdgroups / 128 threads instead of 32 / 1024.
//
// Threadgroup memory:
//   2 × As (64×16 halves) = 4 KiB
//   2 × Bs (16×64 halves) = 4 KiB
//   total = 8 KiB / 32 KiB → comfortable headroom.
// ---------------------------------------------------------------------------
kernel void simdgroup_matmul_4sg_64x64_db(
    device   const half*   a    [[buffer(0)]],
    device   const half*   b    [[buffer(1)]],
    device         float*  c    [[buffer(2)]],
    constant       uint&   M    [[buffer(3)]],
    constant       uint&   N    [[buffer(4)]],
    constant       uint&   K    [[buffer(5)]],
    uint2  tgid    [[threadgroup_position_in_grid]],
    uint   sgid    [[simdgroup_index_in_threadgroup]],
    uint   slid    [[thread_index_in_simdgroup]])
{
    const uint block_row_base = tgid.y * TG_M;
    const uint block_col_base = tgid.x * TG_N;

    const uint sg_y = sgid >> 1u;
    const uint sg_x = sgid & 1u;
    const uint row_warp_base = block_row_base + sg_y * 32u;
    const uint col_warp_base = block_col_base + sg_x * 32u;

    threadgroup half As[2][TG_M * TG_K];   // 2× 2 KiB
    threadgroup half Bs[2][TG_K * TG_N];   // 2× 2 KiB

    simdgroup_matrix<float, 8, 8> Cmat[4][4];
    for (uint i = 0u; i < 4u; ++i)
        for (uint j = 0u; j < 4u; ++j)
            Cmat[i][j] = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);

    const uint tid    = sgid * 32u + slid;
    const uint K_step = K / TG_K;
    const uint A_TILE = TG_M * TG_K;
    const uint B_TILE = TG_K * TG_N;

    auto load_slot = [&](uint s, uint kk) {
        const uint k_base = kk * TG_K;
        for (uint off = tid; off < A_TILE; off += 128u) {
            const uint r = off / TG_K;
            const uint c_idx = off % TG_K;
            const uint a_row = block_row_base + r;
            const uint a_col = k_base + c_idx;
            As[s][off] = (a_row < M && a_col < K) ? a[a_row * K + a_col] : half(0.0);
        }
        for (uint off = tid; off < B_TILE; off += 128u) {
            const uint r = off / TG_N;
            const uint c_idx = off % TG_N;
            const uint b_row = k_base + r;
            const uint b_col = block_col_base + c_idx;
            Bs[s][off] = (b_row < K && b_col < N) ? b[b_row * N + b_col] : half(0.0);
        }
    };

    // Prologue — load slot 0.
    load_slot(0, 0);
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint kk = 0u; kk < K_step; ++kk) {
        const uint s_use  = kk & 1u;
        const uint s_next = (kk + 1u) & 1u;

        if (kk + 1u < K_step) {
            load_slot(s_next, kk + 1u);
        }

        const uint K8_INNER = TG_K / 8u;
        for (uint kk2 = 0u; kk2 < K8_INNER; ++kk2) {
            simdgroup_matrix<half, 8, 8> Amat[4];
            for (uint sub_m = 0u; sub_m < 4u; ++sub_m) {
                simdgroup_load(Amat[sub_m], As[s_use], ulong(TG_K),
                               ulong2(ulong(kk2 * 8u),
                                      ulong(sg_y * 32u + sub_m * 8u)),
                               false);
            }
            simdgroup_matrix<half, 8, 8> Bmat[4];
            for (uint sub_n = 0u; sub_n < 4u; ++sub_n) {
                simdgroup_load(Bmat[sub_n], Bs[s_use], ulong(TG_N),
                               ulong2(ulong(sg_x * 32u + sub_n * 8u),
                                      ulong(kk2 * 8u)),
                               false);
            }
            for (uint sub_m = 0u; sub_m < 4u; ++sub_m) {
                for (uint sub_n = 0u; sub_n < 4u; ++sub_n) {
                    simdgroup_multiply_accumulate(
                        Cmat[sub_m][sub_n],
                        Amat[sub_m], Bmat[sub_n],
                        Cmat[sub_m][sub_n]);
                }
            }
        }

        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    for (uint sub_m = 0u; sub_m < 4u; ++sub_m) {
        const uint row_base = row_warp_base + sub_m * 8u;
        if (row_base >= M) break;
        for (uint sub_n = 0u; sub_n < 4u; ++sub_n) {
            const uint col_base = col_warp_base + sub_n * 8u;
            if (col_base >= N) continue;
            simdgroup_store(Cmat[sub_m][sub_n], c, ulong(N),
                            ulong2(ulong(col_base), ulong(row_base)),
                            false);
        }
    }
}
