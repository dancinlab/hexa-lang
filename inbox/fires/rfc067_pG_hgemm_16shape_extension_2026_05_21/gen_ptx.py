#!/usr/bin/env python3
"""RFC 067 PG -- generate shape-port PTX for HGEMM at arbitrary S divisible by 64.

Template = wmma_256x256_grid.ptx (PR #214 baseline) ported to S.
Stride constants S-dependent:
  A/B ctaid stride bytes = 64*S*2 = 128*S
  A/B m/n_tile stride bytes = 16*S*2 = 32*S
  C   ctaid stride bytes = 64*S*4 = 256*S
  C   m/n_tile stride bytes = 16*S*4 = 64*S
  ctaid.x C col stride  = 64*4 = 256 (constant)
  n_tile  C col stride  = 16*4 = 64  (constant)
  wmma.load/store stride operand = S (elements)
"""

import sys
from pathlib import Path

def gen(S: int) -> str:
    assert S % 64 == 0, f"S={S} must be divisible by 64"
    grid = S // 64
    ktiles = S // 16
    a_byte = 128 * S      # ctaid stride
    am_byte = 32 * S      # m_tile stride
    c_byte = 256 * S      # ctaid stride
    cm_byte = 64 * S      # m_tile stride
    ab_row_b = S * 2
    c_row_b = S * 4

    return f"""// RFC 067 PG perf HGEMM hexa-emit -- M=N=K={S} WMMA GEMM.
//
// Shape-port of wmma_256x256_grid.ptx (PR #214) to S={S}:
//   - {grid}x{grid} grid of thread blocks (each block owns 64x64 output sub-block)
//   - Each block runs 512 threads = 16 warps in 4x4 warp grid
//   - K-loop iterates S/16 = {ktiles} tiles
//   - All stride constants scaled where they encode row/col S
//
// Layout:
//   A row-major     [M={S} x K={S}] f16. Row stride = {S} elem = {ab_row_b} B.
//   B col-major     [K={S} x N={S}] f16. Col stride = {S} elem = {ab_row_b} B.
//   C row-major out [M={S} x N={S}] f32. Row stride = {S} elem = {c_row_b} B.
//
// Per-warp base addresses:
//   A: a + ctaid.y * (64 * {S} * 2) + m_tile * (16 * {S} * 2)
//      = a + ctaid.y * {a_byte} + m_tile * {am_byte}
//   B: b + ctaid.x * {a_byte} + n_tile * {am_byte}
//   C: c + ctaid.y * (64 * {S} * 4) + m_tile * (16 * {S} * 4)
//        + ctaid.x * (64 * 4) + n_tile * (16 * 4)
//      = c + ctaid.y * {c_byte} + m_tile * {cm_byte} + ctaid.x * 256 + n_tile * 64

.version 8.0
.target sm_90
.address_size 64

.visible .entry wmma_{S}x{S}_grid (
    .param .u64 a,
    .param .u64 b,
    .param .u64 c,
    .param .u64 k_tiles
)
{{
    .reg .u64 %rd<24>;
    .reg .u32 %r<20>;
    .reg .pred %p1;
    .reg .b32 %ra<8>;
    .reg .b32 %rb<8>;
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
    // {a_byte} = 64 * {S} * 2.  {am_byte} = 16 * {S} * 2.
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
    // {c_byte} = 64 * {S} * 4.  {cm_byte} = 16 * {S} * 4.
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

    wmma.load.a.sync.aligned.row.m16n16k16.global.f16
        {{%ra0, %ra1, %ra2, %ra3, %ra4, %ra5, %ra6, %ra7}}, [%rd10], {S};

    wmma.load.b.sync.aligned.col.m16n16k16.global.f16
        {{%rb0, %rb1, %rb2, %rb3, %rb4, %rb5, %rb6, %rb7}}, [%rd11], {S};

    wmma.mma.sync.aligned.row.col.m16n16k16.f32.f32
        {{%fc0, %fc1, %fc2, %fc3, %fc4, %fc5, %fc6, %fc7}},
        {{%ra0, %ra1, %ra2, %ra3, %ra4, %ra5, %ra6, %ra7}},
        {{%rb0, %rb1, %rb2, %rb3, %rb4, %rb5, %rb6, %rb7}},
        {{%fc0, %fc1, %fc2, %fc3, %fc4, %fc5, %fc6, %fc7}};

    add.u64 %rd10, %rd10, 32;
    add.u64 %rd11, %rd11, 32;
    sub.s32 %r0, %r0, 1;
    bra $kloop;

$kloop_done:
    wmma.store.d.sync.aligned.row.m16n16k16.global.f32
        [%rd12], {{%fc0, %fc1, %fc2, %fc3, %fc4, %fc5, %fc6, %fc7}}, {S};
    ret;
}}
"""

# All N12 shapes (multiples of 64). 1216/1344/1472/1600/1728/1856/1984 fill gaps.
# N12 had: 192,256,320,384,448,512,576,640,704,768,832,896,960,1024,1088,1152,
#         1280,1408,1536,1664,1792,1920,2048.
# pG covers all 23 of those plus 256/384/512/768/1024 re-fired for self-consistency.
SHAPES = [192, 256, 320, 384, 448, 512, 576, 640, 704, 768, 832, 896, 960,
          1024, 1088, 1152, 1280, 1408, 1536, 1664, 1792, 1920, 2048]

outdir = Path(__file__).resolve().parent
for S in SHAPES:
    p = outdir / f"wmma_{S}x{S}_grid.ptx"
    p.write_text(gen(S))
    print(f"wrote {p.name} ({len(p.read_text())} bytes)")
print(f"total {len(SHAPES)} shapes")
