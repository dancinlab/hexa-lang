// matmul.metal — RFC 075 P5 Apple M3 FP32 matmul silicon-fire
//
// Computes C[M,N] = A[M,K] * B[K,N] in row-major FP32. Two kernels:
//
//   * matmul_naive — one thread per output element, K-loop in registers,
//     direct device-memory loads. Equivalent to the "ikj" CPU reference
//     reshaped for GPU grid dispatch. This is the canonical shape that
//     a future codegen_emit_metal_msl matmul recogniser would emit from
//     a flame `ag_linear`'s farr_matmul MIR node — the simplest correct
//     baseline before tiling/simdgroup optimisations.
//
//   * matmul_tiled — 16×16 threadgroup-tiled version using threadgroup
//     memory for A/B blocks. Tile size T=16, fully unrolled inner K-tile.
//     Demonstrates the shape that the codegen would need to emit for
//     compute-bound performance (the optimisation gap, not the correctness
//     gap). Bumps arithmetic intensity from O(1) to O(T) flops/byte.
//
// Both kernels are FP32 (Apple GPUs do not support FP64 in compute —
// this is a critical gap analysis item for flame: farr_matmul today is
// FP64-everywhere on CPU; the Apple/Metal path is FP32-only).
//
// FP add/mul re-association: matmul reassociates the K-sum across the
// triple loop, so we tolerate ~1 ULP per accumulated K element. The
// host's tolerance check uses max|d| / |ref| < 1e-5 (single-prec
// matmul standard; matches torch.allclose default rtol).

#include <metal_stdlib>
using namespace metal;

// ---------------------------------------------------------------------
// Kernel 1: naive triple-loop matmul, one thread per output element.
// ---------------------------------------------------------------------
kernel void matmul_naive(
    device const float* a    [[buffer(0)]],
    device const float* b    [[buffer(1)]],
    device       float* c    [[buffer(2)]],
    constant     uint&  M    [[buffer(3)]],
    constant     uint&  N    [[buffer(4)]],
    constant     uint&  K    [[buffer(5)]],
    uint2 gid [[thread_position_in_grid]])
{
    uint row = gid.y;
    uint col = gid.x;
    if (row >= M || col >= N) { return; }
    float acc = 0.0f;
    for (uint k = 0; k < K; k++) {
        acc += a[row * K + k] * b[k * N + col];
    }
    c[row * N + col] = acc;
}

// ---------------------------------------------------------------------
// Kernel 2: threadgroup-tiled matmul, T=16.
//   - Threadgroup size = 16×16.
//   - Each thread loads one A-tile element + one B-tile element per K-step.
//   - K is processed in T-sized chunks via threadgroup_barrier sync.
//   - For shapes where K is not a multiple of T, the boundary chunk
//     guards the load with a zero-fill mask (correctness over speed).
// ---------------------------------------------------------------------
constant constexpr uint TILE = 16;

kernel void matmul_tiled(
    device const float* a    [[buffer(0)]],
    device const float* b    [[buffer(1)]],
    device       float* c    [[buffer(2)]],
    constant     uint&  M    [[buffer(3)]],
    constant     uint&  N    [[buffer(4)]],
    constant     uint&  K    [[buffer(5)]],
    uint2  gid  [[thread_position_in_grid]],
    uint2  lid  [[thread_position_in_threadgroup]])
{
    threadgroup float As[TILE][TILE];
    threadgroup float Bs[TILE][TILE];

    uint row = gid.y;
    uint col = gid.x;
    float acc = 0.0f;

    uint num_tiles = (K + TILE - 1) / TILE;
    for (uint t = 0; t < num_tiles; t++) {
        uint a_col = t * TILE + lid.x;
        uint b_row = t * TILE + lid.y;

        // Guarded loads — zero-fill out-of-bounds.
        As[lid.y][lid.x] = (row < M && a_col < K) ? a[row * K + a_col] : 0.0f;
        Bs[lid.y][lid.x] = (b_row < K && col < N) ? b[b_row * N + col] : 0.0f;

        threadgroup_barrier(mem_flags::mem_threadgroup);

        // Inner K-loop over this tile.
        for (uint k = 0; k < TILE; k++) {
            acc += As[lid.y][k] * Bs[k][lid.x];
        }

        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (row < M && col < N) {
        c[row * N + col] = acc;
    }
}
