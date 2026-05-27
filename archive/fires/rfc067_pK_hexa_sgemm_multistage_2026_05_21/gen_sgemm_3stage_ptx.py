#!/usr/bin/env python3
"""RFC 067 PK -- 3-stage variant: triple-buffered cp.async pipeline.

Same shape as 2-stage; 3 slabs (3*2048 = 6 KB each for A and B, 12 KB total).
Sits well within RTX 5070 sm_120 48 KB per-block default. Allows 2
prefetches in flight while consuming one slot.

Slot index modulo 3. Round-robin: slot = k mod 3.
Pipeline:
  prologue:
    kick K=0 into slot 0; commit
    if K>=2: kick K=1 into slot 1; commit
  loop k:
    if k+2 < K_TILES: kick K=k+2 into slot ((k+2) mod 3); commit
    wait_group 2 (until consume-slot is the oldest landed group)
    bar.sync
    wmma.load.a/b from slot (k mod 3); mma
    bar.sync

This is an honest-scope follow-up; if 3-stage doesn't beat 2-stage, that's
useful information about Blackwell's async-pipeline tradeoffs.
"""

from pathlib import Path


def gen(S: int) -> str:
    assert S % 64 == 0
    a_byte = 64 * S * 4
    am_byte = 16 * S * 4
    c_byte = a_byte
    cm_byte = am_byte
    ab_row_b = S * 4

    return f"""// RFC 067 PK perf SGEMM hexa-emit + 3-stage cp.async pipeline -- M=N=K={S}.
//
// 3 slabs of A and B in shared. Each K-step's slab index = k mod 3.
// 2 prefetches stay in flight while consuming one slot.

.version 8.0
.target sm_90
.address_size 64

.shared .align 16 .b8 _tg_a[6144];   // 3 slabs * 2048 B
.shared .align 16 .b8 _tg_b[6144];

.visible .entry sgemm_3stage_{S}x{S}_grid (
    .param .u64 a,
    .param .u64 b,
    .param .u64 c,
    .param .u64 k_tiles
)
{{
    .reg .u64 %rd<32>;
    .reg .u32 %r<60>;
    .reg .pred %p1;
    .reg .pred %pmore;
    .reg .pred %pinit2;
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
    shr.u32 %r3, %r2, 2;        // m_tile
    and.b32 %r4, %r2, 3;        // n_tile

    shr.u32 %r12, %r1, 3;       // row_load
    and.b32 %r13, %r1, 7;       // col_load

    // A_cta base
    mul.lo.u32 %r5, %r10, {a_byte};
    cvt.u64.u32 %rd4, %r5;
    add.u64 %rd10, %rd0, %rd4;

    // B_cta base
    mul.lo.u32 %r5, %r11, {a_byte};
    cvt.u64.u32 %rd5, %r5;
    add.u64 %rd11, %rd1, %rd5;

    // Per-thread global A/B load pointer (excludes k_step; advances by 32 B per K).
    mul.lo.u32 %r14, %r12, {ab_row_b};
    mul.lo.u32 %r15, %r13, 4;
    add.u32 %r14, %r14, %r15;
    cvt.u64.u32 %rd14, %r14;
    add.u64 %rd14, %rd10, %rd14;     // A current global ptr
    cvt.u64.u32 %rd15, %r14;
    add.u64 %rd15, %rd11, %rd15;     // B current global ptr

    // Per-thread intra-slab offset.
    shl.b32 %r16, %r12, 5;
    mul.lo.u32 %r17, %r13, 4;
    add.u32 %r16, %r16, %r17;

    mov.u32 %r18, _tg_a;
    mov.u32 %r20, _tg_b;

    // Per-warp within-slab read offsets.
    mul.lo.u32 %r22, %r3, 512;
    mul.lo.u32 %r24, %r4, 512;

    // C base
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

    // Slot rotation: maintain three slot offsets (a, b, c) in [0,2,1] rotation.
    // Simpler: maintain `cur_slot` integer and compute (cur_slot+0,1,2) mod 3.
    mov.u32 %r30, 0;                 // current slot index in {{0,1,2}}

    // ---- PROLOGUE: kick K=0 into slot 0, K=1 into slot 1 (if K>=2) ----
    setp.le.s32 %p1, %r0, 0;
    @%p1 bra $epilogue;

    // K=0 -> slot 0
    add.u32 %r40, %r18, %r16;
    cp.async.ca.shared.global [%r40], [%rd14], 4;
    add.u32 %r41, %r20, %r16;
    cp.async.ca.shared.global [%r41], [%rd15], 4;
    cp.async.commit_group;
    add.u64 %rd14, %rd14, 32;
    add.u64 %rd15, %rd15, 32;

    setp.gt.s32 %pinit2, %r0, 1;
    @!%pinit2 bra $kloop;

    // K=1 -> slot 1 (offset 2048 in slab)
    add.u32 %r40, %r18, %r16;
    add.u32 %r40, %r40, 2048;
    cp.async.ca.shared.global [%r40], [%rd14], 4;
    add.u32 %r41, %r20, %r16;
    add.u32 %r41, %r41, 2048;
    cp.async.ca.shared.global [%r41], [%rd15], 4;
    cp.async.commit_group;
    add.u64 %rd14, %rd14, 32;
    add.u64 %rd15, %rd15, 32;

$kloop:
    setp.le.s32 %p1, %r0, 0;
    @%p1 bra $epilogue;

    // If 3+ iters remain (k+2 < K_TILES <=> remaining > 2): kick next prefetch
    // into slot (cur_slot + 2) mod 3.
    setp.gt.s32 %pmore, %r0, 2;
    @!%pmore bra $no_prefetch;

    // next_slot = (cur_slot + 2) mod 3. Use small table approach via add+cmp.
    add.u32 %r31, %r30, 2;
    setp.ge.u32 %p1, %r31, 3;
    @%p1 sub.u32 %r31, %r31, 3;
    setp.ge.u32 %p1, %r31, 3;
    @%p1 sub.u32 %r31, %r31, 3;

    mul.lo.u32 %r32, %r31, 2048;    // next_slot * 2048

    add.u32 %r40, %r18, %r32;
    add.u32 %r40, %r40, %r16;
    cp.async.ca.shared.global [%r40], [%rd14], 4;
    add.u32 %r41, %r20, %r32;
    add.u32 %r41, %r41, %r16;
    cp.async.ca.shared.global [%r41], [%rd15], 4;
    cp.async.commit_group;

    // Wait until at most 2 groups pending (the consume-slot group has landed).
    cp.async.wait_group 2;
    bra $consume;

$no_prefetch:
    // No new prefetch; just wait for whatever remains.
    cp.async.wait_all;

$consume:
    bar.sync 0;

    // Load A/B from CURRENT slot (cur_slot).
    mul.lo.u32 %r34, %r30, 2048;
    add.u32 %r35, %r18, %r34;
    add.u32 %r35, %r35, %r22;
    add.u32 %r36, %r20, %r34;
    add.u32 %r36, %r36, %r24;

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

    add.u64 %rd14, %rd14, 32;
    add.u64 %rd15, %rd15, 32;

    // cur_slot = (cur_slot + 1) mod 3
    add.u32 %r30, %r30, 1;
    setp.ge.u32 %p1, %r30, 3;
    @%p1 sub.u32 %r30, %r30, 3;

    sub.s32 %r0, %r0, 1;
    bra $kloop;

$epilogue:
    wmma.store.d.sync.aligned.row.m16n16k8.global.f32
        [%rd12], {{%fc0, %fc1, %fc2, %fc3, %fc4, %fc5, %fc6, %fc7}}, {S};
    ret;
}}
"""


SHAPES = [256, 384, 512, 768, 1024, 1536]

if __name__ == "__main__":
    outdir = Path(__file__).resolve().parent
    for S in SHAPES:
        p = outdir / f"sgemm_3stage_{S}x{S}_grid.ptx"
        p.write_text(gen(S))
        print(f"wrote {p.name} ({len(p.read_text())} bytes)")
    print(f"total {len(SHAPES)} shapes")
