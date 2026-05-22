#!/usr/bin/env python3
# RFC 067 N201 -- Multi-stage TMA perf-proxy kernel.
#
# Bandwidth-dominated proxy for the SGEMM cliff regime (M>=4096): each CTA does
# a K-loop of TMA loads + a small fp16 reduce (sum into a single f32 reg) to
# keep ALU active. Output: one f32 per CTA written to C[cta_id], so total
# stores are negligible vs the TMA traffic.
#
# Knobs:
#   STAGES in {1,2,3}  (1 = single-stage like N200; 2/3 = multi-stage pool)
#   K_TILES in {64, 128, 256}  (more K-iters amortizes prologue + exposes pipeline)
#
# Tile sizes mirror N200 SMOKE: TILE_M=64, TILE_N=64, TILE_K=16.
# CTA grid: cta_count = M/TILE_M  (single row of CTAs across M; B-tile fetched
# from the SAME (col=0, row=k_off) coordinates per K-iter, so all CTAs share
# the B descriptor and traffic).
#
# Per-CTA per-K-iter bytes loaded:
#   A: 64 * 16 * 2 = 2048 B
#   B: 16 * 64 * 2 = 2048 B
# Total bytes per CTA = 4096 * K_TILES; total traffic = M/64 * 4096 * K_TILES.
#
# .target sm_120a + .version 8.7. ASCII-only.

import sys

TILE_M = 64
TILE_N = 64
TILE_K = 16

A_TILE_BYTES = 64 * 16 * 2
B_TILE_BYTES = 16 * 64 * 2
TX_PER_STAGE = A_TILE_BYTES + B_TILE_BYTES

if len(sys.argv) < 3:
    sys.stderr.write("usage: gen_sgemm_tma_perf_ptx.py STAGES K_TILES\n")
    sys.exit(2)

STAGES  = int(sys.argv[1])
K_TILES = int(sys.argv[2])
assert STAGES in (1, 2, 3)
assert K_TILES >= 1

A_SLAB_TOTAL = A_TILE_BYTES * STAGES
B_SLAB_TOTAL = B_TILE_BYTES * STAGES
MBAR_TOTAL = 8 * STAGES

ptx = []
def w(s=""):
    ptx.append(s)

w("//")
w(f"// RFC 067 N201 perf-proxy multi-stage TMA  STAGES={STAGES}  K_TILES={K_TILES}")
w("//")
w("// Bandwidth-dominated proxy: per-CTA K-loop of TMA loads + fp16 reduce.")
w("// Grid = (M/64, 1, 1). Output: 1 f32 per CTA in C.")
w("//")
w(f"// shmem: A {A_SLAB_TOTAL} + B {B_SLAB_TOTAL} + mbar {MBAR_TOTAL} = "
  f"{A_SLAB_TOTAL+B_SLAB_TOTAL+MBAR_TOTAL} B")
w("//")
w(".version 8.7")
w(".target sm_120a")
w(".address_size 64")
w("")
w(f".shared .align 16 .b8 smem_a[{A_SLAB_TOTAL}];")
w(f".shared .align 16 .b8 smem_b[{B_SLAB_TOTAL}];")
w(f".shared .align 8  .b8 smem_mbar[{MBAR_TOTAL}];")
w(f".shared .align 4  .b8 smem_reduce[{128 * 4}]; // per-thread f32")
w("")
w(".visible .entry sgemm_tma_perf(")
w("    .param .align 64 .b8 tmap_a_param[128],")
w("    .param .align 64 .b8 tmap_b_param[128],")
w("    .param .u64 c_ptr_param")
w(") {")
w("    .reg .b32 %tx, %cta_id;")
w("    .reg .b32 %k_iter, %k_off, %tx_count;")
w("    .reg .b32 %slot, %slot_a, %slot_b, %slot_mbar;")
w("    .reg .b64 %tmap_a_pp, %tmap_b_pp, %tmap_a_addr, %tmap_b_addr;")
w("    .reg .b64 %c_addr;")
w("    .reg .b32 %smem_a_lo, %smem_b_lo, %smem_mbar_lo, %smem_reduce_lo;")
w("    .reg .b32 %arr_count;")
w("    .reg .b64 %tok;")
w("    .reg .pred %p0, %p_issue, %pdone;")
w("    .reg .b32 %x0, %y0, %x1, %y1;")
for s in range(STAGES):
    w(f"    .reg .b32 %parity{s};")
w("    .reg .b32 %parity;")
w("    .reg .f32 %acc, %tmp_f;")
w("    .reg .b16 %h_tmp;")
w("    .reg .b32 %slab_a_base, %slab_b_base, %addr_tmp;")
w("    .reg .b32 %row_m, %row_n;")
w("    .reg .b32 %issue_k, %issue_kx16;")
w("    .reg .b64 %c_off, %c_dst;")
w("    .reg .b32 %m_origin;")
w("")
w("    mov.u32 %tx, %tid.x;")
w("    mov.u32 %cta_id, %ctaid.x;")
w("    mul.lo.s32 %m_origin, %cta_id, 64; // each CTA owns 64 rows of A")
w("")
w("    mov.b64 %tmap_a_pp, tmap_a_param;")
w("    cvta.param.u64 %tmap_a_addr, %tmap_a_pp;")
w("    mov.b64 %tmap_b_pp, tmap_b_param;")
w("    cvta.param.u64 %tmap_b_addr, %tmap_b_pp;")
w("    ld.param.u64 %c_addr, [c_ptr_param];")
w("    mov.u32 %smem_a_lo, smem_a;")
w("    mov.u32 %smem_b_lo, smem_b;")
w("    mov.u32 %smem_mbar_lo, smem_mbar;")
w("    mov.u32 %smem_reduce_lo, smem_reduce;")
w("")
w("    // init accumulator")
w("    mov.f32 %acc, 0f00000000;")
w("")
w("    // mbarrier init (thread 0 only)")
w("    setp.eq.s32 %p0, %tx, 0;")
w("    @!%p0 bra L_init_done;")
w("    mov.u32 %arr_count, 1;")
for s in range(STAGES):
    w(f"    mbarrier.init.shared.b64 [%smem_mbar_lo+{8*s}], %arr_count;")
w("    fence.proxy.async.shared::cta;")
w("L_init_done:")
w("    bar.sync 0;")
w("")

# Init parity counters
for s in range(STAGES):
    w(f"    mov.u32 %parity{s}, 0;")
w("")

# Prologue: thread 0 issues min(STAGES, K_TILES) tiles
w("    setp.eq.s32 %p0, %tx, 0;")
w("    @!%p0 bra L_prologue_done;")
preload = min(STAGES, K_TILES)
for s in range(preload):
    k_off = s * TILE_K
    slot_a_off = s * A_TILE_BYTES
    slot_b_off = s * B_TILE_BYTES
    slot_mbar_off = s * 8
    w(f"    // prologue stage {s} (k={s}, k_off={k_off})")
    w(f"    mov.u32 %x0, {k_off};")
    w(f"    mov.u32 %y0, %m_origin;")
    w(f"    cp.async.bulk.tensor.2d.shared::cluster.global.tile.mbarrier::complete_tx::bytes")
    w(f"        [%smem_a_lo+{slot_a_off}], [%tmap_a_addr, {{%x0, %y0}}], [%smem_mbar_lo+{slot_mbar_off}];")
    w(f"    mov.u32 %x1, 0;")
    w(f"    mov.u32 %y1, {k_off};")
    w(f"    cp.async.bulk.tensor.2d.shared::cluster.global.tile.mbarrier::complete_tx::bytes")
    w(f"        [%smem_b_lo+{slot_b_off}], [%tmap_b_addr, {{%x1, %y1}}], [%smem_mbar_lo+{slot_mbar_off}];")
    w(f"    mov.u32 %tx_count, {TX_PER_STAGE};")
    w(f"    mbarrier.arrive.expect_tx.release.cta.shared::cta.b64")
    w(f"        %tok, [%smem_mbar_lo+{slot_mbar_off}], %tx_count;")
w("L_prologue_done:")
w("    bar.sync 0;")
w("")

# K-loop
w("    mov.u32 %k_iter, 0;")
w("L_kloop:")
if STAGES == 1:
    w("    mov.u32 %slot, 0;")
    w("    mov.u32 %slot_a, 0;")
    w("    mov.u32 %slot_b, 0;")
    w("    mov.u32 %slot_mbar, 0;")
else:
    w(f"    rem.s32 %slot, %k_iter, {STAGES};")
    w(f"    mul.lo.s32 %slot_a, %slot, {A_TILE_BYTES};")
    w(f"    mul.lo.s32 %slot_b, %slot, {B_TILE_BYTES};")
    w(f"    mul.lo.s32 %slot_mbar, %slot, 8;")
w("")
w(f"    mov.u32 %parity, %parity0;")
for s in range(1, STAGES):
    w(f"    setp.eq.s32 %p0, %slot, {s};")
    w(f"    @%p0 mov.u32 %parity, %parity{s};")
w("")
w("    .reg .b32 %wait_addr;")
w("    add.s32 %wait_addr, %smem_mbar_lo, %slot_mbar;")
w("L_wait:")
w("    mbarrier.try_wait.parity.shared::cta.b64 %pdone, [%wait_addr], %parity;")
w("    @!%pdone bra L_wait;")
w("    bar.sync 0;")
w("")
for s in range(STAGES):
    w(f"    setp.eq.s32 %p0, %slot, {s};")
    w(f"    @%p0 xor.b32 %parity{s}, %parity{s}, 1;")
w("")

# Compute: each thread sums one fp16 from slab_a + one from slab_b (small ALU)
w("    add.s32 %slab_a_base, %smem_a_lo, %slot_a;")
w("    add.s32 %slab_b_base, %smem_b_lo, %slot_b;")
w("    // sum one A elem + one B elem from current slab (thread tx reads byte tx*2)")
w("    .reg .b32 %off_b2;")
w("    mul.lo.s32 %off_b2, %tx, 2;")
w("    add.s32 %addr_tmp, %slab_a_base, %off_b2;")
w("    ld.shared.b16 %h_tmp, [%addr_tmp];")
w("    cvt.f32.f16 %tmp_f, %h_tmp;")
w("    add.f32 %acc, %acc, %tmp_f;")
w("    add.s32 %addr_tmp, %slab_b_base, %off_b2;")
w("    ld.shared.b16 %h_tmp, [%addr_tmp];")
w("    cvt.f32.f16 %tmp_f, %h_tmp;")
w("    add.f32 %acc, %acc, %tmp_f;")
w("")

# Issue next stage k+STAGES if within bounds (thread 0)
w(f"    add.s32 %issue_k, %k_iter, {STAGES};")
w(f"    setp.lt.s32 %p_issue, %issue_k, {K_TILES};")
w("    setp.eq.and.s32 %p_issue, %tx, 0, %p_issue;")
w("    @!%p_issue bra L_skip_issue;")
w("    mul.lo.s32 %issue_kx16, %issue_k, 16;")
w("    .reg .b32 %issue_a_addr, %issue_b_addr, %issue_mbar_addr;")
w("    add.s32 %issue_a_addr, %smem_a_lo, %slot_a;")
w("    add.s32 %issue_b_addr, %smem_b_lo, %slot_b;")
w("    add.s32 %issue_mbar_addr, %smem_mbar_lo, %slot_mbar;")
w("    mov.u32 %x0, %issue_kx16;")
w("    mov.u32 %y0, %m_origin;")
w("    cp.async.bulk.tensor.2d.shared::cluster.global.tile.mbarrier::complete_tx::bytes")
w("        [%issue_a_addr], [%tmap_a_addr, {%x0, %y0}], [%issue_mbar_addr];")
w("    mov.u32 %x1, 0;")
w("    mov.u32 %y1, %issue_kx16;")
w("    cp.async.bulk.tensor.2d.shared::cluster.global.tile.mbarrier::complete_tx::bytes")
w("        [%issue_b_addr], [%tmap_b_addr, {%x1, %y1}], [%issue_mbar_addr];")
w(f"    mov.u32 %tx_count, {TX_PER_STAGE};")
w("    mbarrier.arrive.expect_tx.release.cta.shared::cta.b64")
w("        %tok, [%issue_mbar_addr], %tx_count;")
w("L_skip_issue:")
w("")
w("    add.s32 %k_iter, %k_iter, 1;")
w(f"    setp.lt.s32 %p0, %k_iter, {K_TILES};")
w("    @%p0 bra L_kloop;")
w("")

# Block reduce + write 1 f32 per CTA
w("    // per-thread acc -> smem_reduce -> bar.sync -> thread 0 reduce + store")
w("    .reg .b32 %red_off;")
w("    mul.lo.s32 %red_off, %tx, 4;")
w("    add.s32 %red_off, %smem_reduce_lo, %red_off;")
w("    st.shared.f32 [%red_off], %acc;")
w("    bar.sync 0;")
w("    setp.eq.s32 %p0, %tx, 0;")
w("    @!%p0 bra L_done;")
w("    .reg .f32 %sum, %v;")
w("    .reg .b32 %i, %off2;")
w("    mov.f32 %sum, 0f00000000;")
w("    mov.u32 %i, 0;")
w("L_red:")
w("    mul.lo.s32 %off2, %i, 4;")
w("    add.s32 %off2, %smem_reduce_lo, %off2;")
w("    ld.shared.f32 %v, [%off2];")
w("    add.f32 %sum, %sum, %v;")
w("    add.s32 %i, %i, 1;")
w("    setp.lt.s32 %p0, %i, 128;")
w("    @%p0 bra L_red;")
w("    cvt.u64.u32 %c_off, %cta_id;")
w("    mul.lo.u64 %c_off, %c_off, 4;")
w("    add.u64 %c_dst, %c_addr, %c_off;")
w("    st.global.f32 [%c_dst], %sum;")
w("L_done:")
w("    ret;")
w("}")

out = f"sgemm_tma_perf_s{STAGES}_k{K_TILES}.ptx"
with open(out, "w") as f:
    f.write("\n".join(ptx))
    f.write("\n")
print(f"Generated {out}  shmem={A_SLAB_TOTAL+B_SLAB_TOTAL+MBAR_TOTAL+512}B")
