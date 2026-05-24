#!/usr/bin/env python3
"""RFC 067 PI -- hand-emit hexa SGEMM PTX (TF32 tensor-core, m16n16k8).

Mirrors the HGEMM template (rfc067_pG/gen_ptx.py) but targets the TF32
WMMA shape so it can be measured against N44's cuBLAS SGEMM
(which dispatches to TF32 tensor cores under CUBLAS_TENSOR_OP_MATH).

Geometry (per thread block):
  - 16 warps in 4x4 layout -> 64x64 output tile
  - Each warp owns one 16x16 sub-tile via wmma.m16n16k8.f32.tf32.tf32.f32
  - K-loop: S/8 iterations (TF32 wmma K = 8)
  - 512 threads per block (16 warps * 32)

Layout (same as HGEMM):
  A row-major [M=S x K=S] f32. Row stride = S elem = 4*S B.
  B col-major [K=S x N=S] f32. Col stride = S elem = 4*S B.
  C row-major [M=S x N=S] f32. Row stride = S elem = 4*S B.

Per-warp base addresses (bytes from base ptr):
  A: ctaid.y * (64 * S * 4) + m_tile * (16 * S * 4)
     = ctaid.y * a_byte + m_tile * am_byte                  [a_byte = 256*S, am_byte = 64*S]
  B: ctaid.x * (64 * S * 4) + n_tile * (16 * S * 4)
     = ctaid.x * a_byte + n_tile * am_byte                  (same as A; FP32 col-major same stride as A row-major)
  C: ctaid.y * (64 * S * 4) + m_tile * (16 * S * 4)
       + ctaid.x * (64 * 4) + n_tile * (16 * 4)
     = ctaid.y * a_byte + m_tile * am_byte + ctaid.x * 256 + n_tile * 64

K-step advances: each WMMA K=8 -> 8 fp32 elems = 32 bytes along K dim.
"""

import sys
from pathlib import Path


def gen(S: int) -> str:
    assert S % 64 == 0, f"S={S} must be divisible by 64"
    grid = S // 64
    ktiles = S // 8                # TF32 wmma K=8
    a_byte = 64 * S * 4            # ctaid stride: 64 rows/cols * S elem * 4 B
    am_byte = 16 * S * 4           # m_tile / n_tile stride
    c_byte = a_byte                # same: C is also FP32 with S row stride
    cm_byte = am_byte
    ab_row_b = S * 4               # one row/col stride in bytes

    return f"""// RFC 067 PI perf SGEMM hexa-emit -- M=N=K={S} TF32 WMMA GEMM.
//
// Hand-port of the HGEMM template (PR #214 / pG) to the TF32 wmma shape:
//   - {grid}x{grid} grid of thread blocks (each owns 64x64 output sub-block)
//   - 512 threads = 16 warps in 4x4 layout per block
//   - K-loop iterates S/8 = {ktiles} tiles (TF32 wmma K=8)
//   - wmma.m16n16k8.f32.tf32.tf32.f32 (4 a-regs, 4 b-regs, 8 acc-regs)
//
// FP32 inputs are interpreted as TF32 by the wmma instruction (low 13
// mantissa bits are dropped). This matches cuBLAS SGEMM under
// CUBLAS_TENSOR_OP_MATH (N44 baseline).
//
// Layout:
//   A row-major     [M={S} x K={S}] f32. Row stride = {S} elem = {ab_row_b} B.
//   B col-major     [K={S} x N={S}] f32. Col stride = {S} elem = {ab_row_b} B.
//   C row-major out [M={S} x N={S}] f32. Row stride = {S} elem = {ab_row_b} B.
//
// Per-warp base addresses (bytes):
//   A: a + ctaid.y * {a_byte} + m_tile * {am_byte}
//   B: b + ctaid.x * {a_byte} + n_tile * {am_byte}
//   C: c + ctaid.y * {c_byte} + m_tile * {cm_byte} + ctaid.x * 256 + n_tile * 64
//
// K-step advances %rd10, %rd11 by 32 bytes (8 fp32 elems = one TF32 wmma K-tile).

.version 8.0
.target sm_90
.address_size 64

.visible .entry sgemm_{S}x{S}_grid (
    .param .u64 a,
    .param .u64 b,
    .param .u64 c,
    .param .u64 k_tiles
)
{{
    .reg .u64 %rd<24>;
    .reg .u32 %r<20>;
    .reg .pred %p1;
    .reg .b32 %ra<4>;
    .reg .b32 %rb<4>;
    .reg .f32 %fc<8>;

    ld.param.u64 %rd0, [a];
    ld.param.u64 %rd1, [b];
    ld.param.u64 %rd2, [c];
    ld.param.u64 %rd3, [k_tiles];

    mov.u32 %r10, %ctaid.y;
    mov.u32 %r11, %ctaid.x;

    mov.u32 %r1, %tid.x;
    shr.u32 %r2, %r1, 5;
    shr.u32 %r3, %r2, 2;
    and.b32 %r4, %r2, 3;

    // A base offset = ctaid.y * {a_byte} + m_tile * {am_byte} bytes.
    mul.lo.u32 %r5, %r10, {a_byte};
    mul.lo.u32 %r6, %r3, {am_byte};
    add.u32 %r7, %r5, %r6;
    cvt.u64.u32 %rd4, %r7;
    add.u64 %rd10, %rd0, %rd4;

    // B base offset = ctaid.x * {a_byte} + n_tile * {am_byte} bytes.
    mul.lo.u32 %r5, %r11, {a_byte};
    mul.lo.u32 %r6, %r4, {am_byte};
    add.u32 %r7, %r5, %r6;
    cvt.u64.u32 %rd5, %r7;
    add.u64 %rd11, %rd1, %rd5;

    // C base offset = ctaid.y * {c_byte} + m_tile * {cm_byte}
    //               + ctaid.x * 256   + n_tile * 64.
    mul.lo.u32 %r5, %r10, {c_byte};
    mul.lo.u32 %r6, %r3, {cm_byte};
    add.u32 %r7, %r5, %r6;
    mul.lo.u32 %r8, %r11, 256;
    add.u32 %r7, %r7, %r8;
    mul.lo.u32 %r8, %r4, 64;
    add.u32 %r7, %r7, %r8;
    cvt.u64.u32 %rd6, %r7;
    add.u64 %rd12, %rd2, %rd6;

    mov.f32 %fc0, 0f00000000;
    mov.f32 %fc1, 0f00000000;
    mov.f32 %fc2, 0f00000000;
    mov.f32 %fc3, 0f00000000;
    mov.f32 %fc4, 0f00000000;
    mov.f32 %fc5, 0f00000000;
    mov.f32 %fc6, 0f00000000;
    mov.f32 %fc7, 0f00000000;

    cvt.s32.s64 %r0, %rd3;

$kloop:
    setp.le.s32 %p1, %r0, 0;
    @%p1 bra $kloop_done;

    wmma.load.a.sync.aligned.row.m16n16k8.global.tf32
        {{%ra0, %ra1, %ra2, %ra3}}, [%rd10], {S};

    wmma.load.b.sync.aligned.col.m16n16k8.global.tf32
        {{%rb0, %rb1, %rb2, %rb3}}, [%rd11], {S};

    wmma.mma.sync.aligned.row.col.m16n16k8.f32.tf32.tf32.f32
        {{%fc0, %fc1, %fc2, %fc3, %fc4, %fc5, %fc6, %fc7}},
        {{%ra0, %ra1, %ra2, %ra3}},
        {{%rb0, %rb1, %rb2, %rb3}},
        {{%fc0, %fc1, %fc2, %fc3, %fc4, %fc5, %fc6, %fc7}};

    // K-step: advance A row-pointer +8 elem along K = +32 bytes,
    //          advance B col-pointer +8 elem along K = +32 bytes.
    add.u64 %rd10, %rd10, 32;
    add.u64 %rd11, %rd11, 32;
    sub.s32 %r0, %r0, 1;
    bra $kloop;

$kloop_done:
    wmma.store.d.sync.aligned.row.m16n16k8.global.f32
        [%rd12], {{%fc0, %fc1, %fc2, %fc3, %fc4, %fc5, %fc6, %fc7}}, {S};
    ret;
}}
"""


# Subset of pG / pH shapes for the PI cycle. Per task: keep cycle fast.
SHAPES = [256, 384, 512, 768, 1024, 1536]

if __name__ == "__main__":
    outdir = Path(__file__).resolve().parent
    for S in SHAPES:
        p = outdir / f"sgemm_{S}x{S}_grid.ptx"
        p.write_text(gen(S))
        print(f"wrote {p.name} ({len(p.read_text())} bytes)")
    print(f"total {len(SHAPES)} shapes")
