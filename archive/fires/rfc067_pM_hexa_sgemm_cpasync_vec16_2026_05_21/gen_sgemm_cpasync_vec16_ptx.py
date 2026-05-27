#!/usr/bin/env python3
"""RFC 067 PM -- hexa SGEMM with VECTORISED cp.async size=16 (4 fp32/instr).

PK / N66 (2-stage SW pipeline using cp.async.ca.shared.global size=4) peaked at
13.35 TFLOPS @ M=1536 / ratio 0.406 on RTX 5070 sm_120. N71's instrumented
analysis pinned the remaining gap to MEMORY SUBSYSTEM: per-fp32 (size=4) async
copies issue 4x more instructions than necessary; the largest unfalsified
candidate is to switch to size=16 (16-byte vector) cp.async which packs 4 fp32
per instruction.

Geometry (unchanged from PK/PJ):
  - 16 warps in 4x4 layout -> 64x64 output tile per CTA
  - Each warp owns one 16x16 sub-tile via wmma.m16n16k8.f32.tf32.tf32.f32
  - K-loop: S/8 iterations (TF32 wmma K = 8)
  - 512 threads per block

Shared-mem (DOUBLE-BUFFERED -- unchanged from PK):
  _tg_a[4096] = 2 slabs * (64 rows x 8 K-elem) * 4 B  = 2 * 2048 B
  _tg_b[4096] = 2 slabs * (64 cols x 8 K-elem) * 4 B  = 2 * 2048 B

Cooperative load (NEW -- vectorised size=16):
  Per K-step: A slab = 64 rows * 8 cols = 512 fp32 = 128 vec4 loads.
  B slab similarly = 128 vec4 loads. Total = 256 vec4 loads (vs N66's 1024
  scalar cp.async instructions; 4x reduction).

  Thread mapping:
    tid in [0, 128):    load A  (vec4 = (vec_idx>>1, vec_idx&1) -> (row, col_q))
    tid in [128, 256):  load B  (vec_idx = tid - 128, same row/col_q decode)
    tid in [256, 512):  IDLE during load (still counted by bar.sync)

  Per-thread (for tid in [0, 256)):
    vec_idx = tid & 127     row = vec_idx >> 1     col_q = vec_idx & 1
    col_base = col_q * 4    (in {0, 4})
    For A: g_off = row * S*4 + (k*8 + col_base) * 4 = row * S*4 + k*32 + col_q*16
    For B: g_off identical scalar form

    Alignment proof (S multiple of 64):
      A_cta base offset = ctaid.y * 64*S*4  -- 16-aligned (S*4 multiple of 256)
      row * S*4 -- 16-aligned (S*4 multiple of 256)
      k*32 -- 16-aligned
      col_q*16 -- 16-aligned
      => global src 16-aligned ✓

    Shared-mem dst:
      (row * 8 + col_base) * 4 = row*32 + col_q*16 in {0..2032} step 16
      => shared dst 16-aligned ✓ (and slab is .align 16)

  Per K-step instruction count:
    N66: 512 (A) + 512 (B) = 1024 cp.async.ca size=4
    PM : 128 (A) + 128 (B) =  256 cp.async.cg size=16  (4x fewer)

Honest-scope guards:
  - cp.async.cg.shared.global requires size=16 (this cycle's whole point).
  - 16-byte alignment requires S % 64 == 0 (already the case for all 6 shapes).
  - Threads tid in [256, 512) issue NO cp.async; they're idle until bar.sync.
    Same warps still participate in wmma.{load,mma,store} as before (all warps
    issue wmma -- only the cooperative load is restricted to first half of CTA).
"""

import sys
from pathlib import Path


def gen(S: int) -> str:
    assert S % 64 == 0, f"S={S} must be divisible by 64"
    a_byte = 64 * S * 4            # ctaid stride
    am_byte = 16 * S * 4           # m_tile / n_tile stride
    c_byte = a_byte
    cm_byte = am_byte
    ab_row_b = S * 4               # one row stride in bytes
    slab_bytes = 2048              # 64 * 8 * 4

    return f"""// RFC 067 PM hexa-emit SGEMM + 2-stage cp.async VECTORISED size=16 -- M=N=K={S}.
//
// Same WMMA shape + tile geometry as PK (gen_sgemm_multistage_ptx.py), but the
// per-K-step cooperative load is switched from cp.async.ca.shared.global size=4
// (per-fp32 scalar, 1024 instructions/K-step) to cp.async.cg.shared.global
// size=16 (4-fp32 vector, 256 instructions/K-step -- 4x fewer).
//
// Thread mapping for cooperative load:
//   tid in [0, 128):    load A   vec_idx = tid           row = tid>>1   col_q = tid&1
//   tid in [128, 256):  load B   vec_idx = tid - 128     row = vid>>1   col_q = vid&1
//   tid in [256, 512):  idle (still hits bar.sync)
//
// Layout (unchanged from PK):
//   A row-major     [M={S} x K={S}] f32. Row stride = {S} elem = {ab_row_b} B.
//   B col-major     [K={S} x N={S}] f32. Col stride = {S} elem = {ab_row_b} B.
//   C row-major out [M={S} x N={S}] f32. Row stride = {S} elem = {ab_row_b} B.

.version 8.0
.target sm_90
.address_size 64

.shared .align 16 .b8 _tg_a[4096];   // 2 slabs * 64 rows * 8 elem * 4 B
.shared .align 16 .b8 _tg_b[4096];

.visible .entry sgemm_cpasync_vec16_{S}x{S}_grid (
    .param .u64 a,
    .param .u64 b,
    .param .u64 c,
    .param .u64 k_tiles
)
{{
    .reg .u64 %rd<32>;
    .reg .u32 %r<64>;
    .reg .pred %p1;
    .reg .pred %pmore;
    .reg .pred %pload_a;
    .reg .pred %pload_b;
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
    shr.u32 %r2, %r1, 5;        // warp id
    shr.u32 %r3, %r2, 2;        // m_tile = warp >> 2
    and.b32 %r4, %r2, 3;        // n_tile = warp & 3

    // Vectorised cooperative-load indexing.
    //   load_a active for tid in [0, 128)
    //   load_b active for tid in [128, 256)
    //   In either case: vec_idx = tid & 127  (0..127)
    //                   row     = vec_idx >> 1   in [0, 64)
    //                   col_q   = vec_idx & 1    in {{0, 1}}
    //                   col_base_elem = col_q * 4   (in {{0, 4}})
    setp.lt.u32 %pload_a, %r1, 128;
    setp.lt.u32 %pload_b, %r1, 256;       // tid < 256
    // pload_b's "and not pload_a" handled below via predication ordering.

    and.b32 %r50, %r1, 127;     // vec_idx
    shr.u32 %r51, %r50, 1;      // row in [0, 64)
    and.b32 %r52, %r50, 1;      // col_q in {{0,1}}
    shl.b32 %r53, %r52, 4;      // col_q * 16 (= col_base_elem * 4 = byte offset within slab-row)

    // A_cta base = a + ctaid.y * {a_byte}
    mul.lo.u32 %r5, %r10, {a_byte};
    cvt.u64.u32 %rd4, %r5;
    add.u64 %rd10, %rd0, %rd4;

    // B_cta base = b + ctaid.x * {a_byte}
    mul.lo.u32 %r5, %r11, {a_byte};
    cvt.u64.u32 %rd5, %r5;
    add.u64 %rd11, %rd1, %rd5;

    // Per-thread A global-load offset (excluding k-step):
    //   row * {ab_row_b} + col_q * 16
    mul.lo.u32 %r54, %r51, {ab_row_b};
    add.u32 %r54, %r54, %r53;
    cvt.u64.u32 %rd14, %r54;
    add.u64 %rd14, %rd10, %rd14;       // %rd14 = A_cta + row*{ab_row_b} + col_q*16

    // Per-thread B global-load offset (excluding k-step): identical scalar form
    cvt.u64.u32 %rd15, %r54;
    add.u64 %rd15, %rd11, %rd15;       // %rd15 = B_cta + row*{ab_row_b} + col_q*16

    // Per-thread shared-mem store offset within ONE slab:
    //   (row * 8 + col_base_elem) * 4 = row*32 + col_q*16
    shl.b32 %r55, %r51, 5;             // row * 32
    add.u32 %r55, %r55, %r53;          // + col_q*16
    // %r55 in {{0..2032}} step 16; intra-slab thread byte offset

    mov.u32 %r18, _tg_a;            // base
    mov.u32 %r20, _tg_b;

    // Per-warp shared-mem READ offsets relative to slab base:
    //   m_tile * 16 * 32 = m_tile * 512
    mul.lo.u32 %r22, %r3, 512;      // warp-A within-slab offset
    mul.lo.u32 %r24, %r4, 512;      // warp-B within-slab offset

    // C base offset (unchanged from PK)
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

    cvt.s32.s64 %r0, %rd3;          // K_TILES remaining

    // Pipeline state:
    //   %r30 = current slot (0/1)
    //   %r0 = remaining iterations
    //   %rd14 / %rd15 = current per-thread global-load pointer (advances by 32 B / K-step)
    mov.u32 %r30, 0;

    // ---- PROLOGUE: issue K=0 prefetch into slot 0 ----
    setp.le.s32 %p1, %r0, 0;
    @%p1 bra $epilogue;

    // A slab dst for slot 0 = _tg_a + 0 + %r55  -- only tid in [0,128) issues
    add.u32 %r40, %r18, %r55;
    @%pload_a cp.async.cg.shared.global [%r40], [%rd14], 16;

    // B slab dst for slot 0 = _tg_b + 0 + %r55  -- only tid in [128,256) issues
    // pload_b is tid<256; combine with !pload_a to get tid in [128,256).
    add.u32 %r41, %r20, %r55;
    @%pload_a bra $skip_b_prologue;
    @%pload_b cp.async.cg.shared.global [%r41], [%rd15], 16;
$skip_b_prologue:
    cp.async.commit_group;

    // Advance global pointers for next prefetch (K=1).  Stride = 8 elem K = 32 B.
    add.u64 %rd14, %rd14, 32;
    add.u64 %rd15, %rd15, 32;

$kloop:
    setp.le.s32 %p1, %r0, 0;
    @%p1 bra $epilogue;

    // If more iterations remain (i.e. %r0 > 1), kick next prefetch into other slot.
    setp.gt.s32 %pmore, %r0, 1;
    @!%pmore bra $no_prefetch;

    // next_slot = current_slot ^ 1
    xor.b32 %r31, %r30, 1;
    shl.b32 %r32, %r31, 11;          // next_slot * 2048

    // A next dst = _tg_a + next_slot*2048 + %r55
    add.u32 %r40, %r18, %r32;
    add.u32 %r40, %r40, %r55;
    @%pload_a cp.async.cg.shared.global [%r40], [%rd14], 16;

    // B next dst = _tg_b + next_slot*2048 + %r55
    add.u32 %r41, %r20, %r32;
    add.u32 %r41, %r41, %r55;
    @%pload_a bra $skip_b_kick;
    @%pload_b cp.async.cg.shared.global [%r41], [%rd15], 16;
$skip_b_kick:

    cp.async.commit_group;
    // Wait for current consume-group to land (1 group still in flight = next prefetch).
    cp.async.wait_group 1;
    bra $consume;

$no_prefetch:
    // Final iter: only the current consume group is in flight.
    cp.async.wait_all;

$consume:
    bar.sync 0;

    // Load A/B from CURRENT slot (= %r30).
    shl.b32 %r34, %r30, 11;          // current_slot * 2048
    add.u32 %r35, %r18, %r34;
    add.u32 %r35, %r35, %r22;        // slab-A base + warp offset
    add.u32 %r36, %r20, %r34;
    add.u32 %r36, %r36, %r24;        // slab-B base + warp offset

    wmma.load.a.sync.aligned.row.m16n16k8.shared.tf32
        {{%ra0, %ra1, %ra2, %ra3}}, [%r35], 8;

    wmma.load.b.sync.aligned.col.m16n16k8.shared.tf32
        {{%rb0, %rb1, %rb2, %rb3}}, [%r36], 8;

    wmma.mma.sync.aligned.row.col.m16n16k8.f32.tf32.tf32.f32
        {{%fc0, %fc1, %fc2, %fc3, %fc4, %fc5, %fc6, %fc7}},
        {{%ra0, %ra1, %ra2, %ra3}},
        {{%rb0, %rb1, %rb2, %rb3}},
        {{%fc0, %fc1, %fc2, %fc3, %fc4, %fc5, %fc6, %fc7}};

    bar.sync 0;

    // Advance global pointers for next prefetch (k+2).
    add.u64 %rd14, %rd14, 32;
    add.u64 %rd15, %rd15, 32;

    xor.b32 %r30, %r30, 1;
    sub.s32 %r0, %r0, 1;
    bra $kloop;

$epilogue:
    wmma.store.d.sync.aligned.row.m16n16k8.global.f32
        [%rd12], {{%fc0, %fc1, %fc2, %fc3, %fc4, %fc5, %fc6, %fc7}}, {S};
    ret;
}}
"""


# Same 6 shapes as PK / PJ / PI for direct comparison.
SHAPES = [256, 384, 512, 768, 1024, 1536]

if __name__ == "__main__":
    outdir = Path(__file__).resolve().parent
    for S in SHAPES:
        p = outdir / f"sgemm_cpasync_vec16_{S}x{S}_grid.ptx"
        p.write_text(gen(S))
        print(f"wrote {p.name} ({len(p.read_text())} bytes)")
    print(f"total {len(SHAPES)} shapes")
