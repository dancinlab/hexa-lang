#!/usr/bin/env python3
# RFC 067 N201 -- Multi-stage TMA mbarrier pool SGEMM smoke (M=N=K=64, single CTA).
#
# Builds on N200 SMOKE (`c5840f19`, single-stage TMA, parity-tracked mbarrier).
# Hypothesis: 3-stage pipeline lets DMA stay ahead of compute (Hopper-style
# cp.async.bulk pipelining); critical at large M where DRAM bandwidth dominates.
#
# Mbarrier-pool depth = STAGES (configurable: SMOKE 3; sweep 2/3).
#
# Layout per K-iter k:
#   slab_a[k%STAGES] holds the A 64x16 tile for k
#   slab_b[k%STAGES] holds the B 16x64 tile for k
#   mbar[k%STAGES] tracks completion of the TMA pair (A+B) for that K-iter
#   parity[k%STAGES] tracks the per-stage mbarrier parity bit (each arrive flips
#                    parity, so per-stage we count "how many times mbar fired
#                    before this wait" mod 2)
#
# Prologue (thread 0): issue stages 0..min(STAGES,K_TILES)-1 (TMA pair + arrive each)
# Steady (k=0..K_TILES-1):
#   wait mbar[k%STAGES] with current parity[k%STAGES]
#   bar.sync 0
#   <SMOKE op: write slab_a[k%STAGES] to C if k == K_TILES-1>
#   if k+STAGES < K_TILES (thread 0): issue stage k+STAGES into slot k%STAGES
#   flip parity[k%STAGES] (each successful wait moves the parity baseline)
# Epilogue: no explicit drain; loop naturally consumes last STAGES iters' arrivals.
#
# SMOKE verification: same as N200 -- write FINAL slab_a (k_iter=K_TILES-1=3,
# slab index (K_TILES-1)%STAGES) back to C as fp32. Verifies the rotating pool
# correctly identifies the slab carrying the last K-tile.
#
# .target sm_120a + .version 8.7 (N196 finding). ASCII-only.

import sys

# --- shape & tile constants ----------------------------------------------
M = 64
N = 64
K = 64
TILE_M = 64
TILE_N = 64
TILE_K = 16
STAGES = 3  # mbarrier pool depth (try 2 and 3 in sweep)

WARPS = 4
THREADS_PER_WARP = 32
THREADS_PER_CTA = WARPS * THREADS_PER_WARP  # 128

K_TILES = K // TILE_K  # 4

# Per-tile bytes (single A 64x16 fp16 + single B 16x64 fp16)
A_TILE_BYTES = 64 * 16 * 2  # 2048
B_TILE_BYTES = 16 * 64 * 2  # 2048
TX_PER_STAGE = A_TILE_BYTES + B_TILE_BYTES  # 4096

if len(sys.argv) >= 2:
    STAGES = int(sys.argv[1])
assert STAGES in (2, 3), "this generator covers STAGES in {2,3}"

A_SLAB_TOTAL = A_TILE_BYTES * STAGES
B_SLAB_TOTAL = B_TILE_BYTES * STAGES
MBAR_TOTAL = 8 * STAGES  # 8 bytes per mbarrier

ptx = []
def w(s=""):
    ptx.append(s)

w("//")
w(f"// RFC 067 N201 -- Multi-stage TMA (STAGES={STAGES}) SGEMM smoke (M=N=K=64, single CTA)")
w("//")
w("// Builds on N200 SMOKE (single-stage TMA). 3 mbarriers + 3 smem slabs rotate")
w("// per K-iter. Prologue prefetches STAGES K-tiles ahead; steady-state overlaps")
w("// TMA fetch of k+STAGES with compute on k. Each stage owns its own parity bit.")
w("//")
w(f"// shmem footprint: A slabs {A_SLAB_TOTAL} B + B slabs {B_SLAB_TOTAL} B + mbars {MBAR_TOTAL} B")
w(f"//                = {A_SLAB_TOTAL + B_SLAB_TOTAL + MBAR_TOTAL} B (limit 48 KB = 49152 B)")
w("//")
w("// SMOKE verification: write FINAL slab_a (k_iter=K_TILES-1) to C; expected to")
w("// equal a[0..15, 48..63] in row-major (= K-tile 3 of A).")
w("//")
w("// .target sm_120a + .version 8.7. ASCII-only.")
w("//")
w("")
w(".version 8.7")
w(".target sm_120a")
w(".address_size 64")
w("")
w(f".shared .align 16 .b8 smem_a[{A_SLAB_TOTAL}];   // {STAGES} A slabs, each 2048 B")
w(f".shared .align 16 .b8 smem_b[{B_SLAB_TOTAL}];   // {STAGES} B slabs, each 2048 B")
w(f".shared .align 8  .b8 smem_mbar[{MBAR_TOTAL}]; // {STAGES} mbarriers, 8 B each")
w("")
w(".visible .entry sgemm_tma_multistage(")
w("    .param .align 64 .b8 tmap_a_param[128],")
w("    .param .align 64 .b8 tmap_b_param[128],")
w("    .param .u64 c_ptr_param")
w(") {")

# --- regs ----------------------------------------------------------------
w("    .reg .b32 %tx, %lane, %wid;")
w("    .reg .b32 %k_iter, %k_off, %tx_count;")
w("    .reg .b32 %slot, %slot_a, %slot_b, %slot_mbar;")
w("    .reg .b32 %issue_k, %issue_kx16, %issue_slot, %issue_slot_a, %issue_slot_b, %issue_slot_mbar;")
w("    .reg .b32 %issue_ok;")
w("    .reg .b64 %tmap_a_pp, %tmap_b_pp, %tmap_a_addr, %tmap_b_addr;")
w("    .reg .b64 %c_addr;")
w("    .reg .b32 %smem_a_lo, %smem_b_lo, %smem_mbar_lo;")
w("    .reg .b32 %arr_count;")
w("    .reg .b64 %tok;")
w("    .reg .pred %p0, %p_issue, %pdone, %p_final;")
w("    .reg .b32 %x0, %y0, %x1, %y1;")
# per-stage parity counters
for s in range(STAGES):
    w(f"    .reg .b32 %parity{s};")
w("    .reg .b32 %parity;")
w("    .reg .b32 %i;")
w("    .reg .b32 %off_smem, %off_c;")
w("    .reg .b16 %h0, %h1;")
w("    .reg .f32 %f0, %f1;")
w("    .reg .b64 %c_off, %c_dst;")
w("    .reg .b32 %final_slot_byte;")
w("")

# --- thread id ----------------------------------------------------------
w("    mov.u32 %tx, %tid.x;")
w("    and.b32 %lane, %tx, 31;")
w("    shr.u32 %wid, %tx, 5;")
w("")

# --- addresses ----------------------------------------------------------
w("    mov.b64 %tmap_a_pp, tmap_a_param;")
w("    cvta.param.u64 %tmap_a_addr, %tmap_a_pp;")
w("    mov.b64 %tmap_b_pp, tmap_b_param;")
w("    cvta.param.u64 %tmap_b_addr, %tmap_b_pp;")
w("    ld.param.u64 %c_addr, [c_ptr_param];")
w("    mov.u32 %smem_a_lo, smem_a;")
w("    mov.u32 %smem_b_lo, smem_b;")
w("    mov.u32 %smem_mbar_lo, smem_mbar;")
w("")

# --- mbarrier init (thread 0 only, all STAGES) --------------------------
w("    setp.eq.s32 %p0, %tx, 0;")
w("    @!%p0 bra L_init_done;")
w("    mov.u32 %arr_count, 1;")
for s in range(STAGES):
    w(f"    mbarrier.init.shared.b64 [%smem_mbar_lo+{8*s}], %arr_count;")
w("    fence.proxy.async.shared::cta;")
w("L_init_done:")
w("    bar.sync 0;")
w("")

# --- init per-stage parity counters to 0 -------------------------------
for s in range(STAGES):
    w(f"    mov.u32 %parity{s}, 0;")
w("")

# --- prologue: issue stages 0..min(STAGES,K_TILES)-1 (thread 0) --------
w("    setp.eq.s32 %p0, %tx, 0;")
w("    @!%p0 bra L_prologue_done;")
w(f"    // Prologue issues min(STAGES={STAGES}, K_TILES={K_TILES}) tiles.")
preload = min(STAGES, K_TILES)
for s in range(preload):
    k_off = s * TILE_K
    slot_a_off = s * A_TILE_BYTES
    slot_b_off = s * B_TILE_BYTES
    slot_mbar_off = s * 8
    w(f"    // Prologue stage {s} (k={s}, k_off={k_off})")
    w(f"    mov.u32 %x0, {k_off};")
    w(f"    mov.u32 %y0, 0;")
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

# --- K-loop (steady state) ----------------------------------------------
w("    mov.u32 %k_iter, 0;")
w("L_kloop:")
# slot = k_iter % STAGES (use rem.s32 — supported on all sm)
w(f"    rem.s32 %slot, %k_iter, {STAGES};")
w(f"    mul.lo.s32 %slot_a, %slot, {A_TILE_BYTES};")
w(f"    mul.lo.s32 %slot_b, %slot, {B_TILE_BYTES};")
w(f"    mul.lo.s32 %slot_mbar, %slot, 8;")
w("")
# Select per-stage parity into %parity (chain of conditional moves)
w("    // pick parity for current slot")
w(f"    mov.u32 %parity, %parity0;")
for s in range(1, STAGES):
    w(f"    setp.eq.s32 %p0, %slot, {s};")
    w(f"    @%p0 mov.u32 %parity, %parity{s};")
w("")
# Wait on mbar at slot
w("    .reg .b32 %wait_addr;")
w("    add.s32 %wait_addr, %smem_mbar_lo, %slot_mbar;")
w("L_wait:")
w("    mbarrier.try_wait.parity.shared::cta.b64 %pdone, [%wait_addr], %parity;")
w("    @!%pdone bra L_wait;")
w("    bar.sync 0;")
w("")

# Flip per-stage parity counter for the slot we just consumed
w("    // flip parity for the slot we just waited on (per-stage parity bit)")
for s in range(STAGES):
    w(f"    setp.eq.s32 %p0, %slot, {s};")
    w(f"    @%p0 xor.b32 %parity{s}, %parity{s}, 1;")
w("")

# --- SMOKE op: if k_iter == K_TILES-1, write slab_a[slot] to C ----------
# Only the final K-iter writes (so we verify the slot carrying the last K-tile)
w(f"    // SMOKE op: only write at the FINAL K-iter (k_iter == {K_TILES-1})")
w(f"    setp.eq.s32 %p_final, %k_iter, {K_TILES-1};")
w(f"    @!%p_final bra L_skip_smoke_write;")
# Compute final slab base
w("    .reg .b32 %final_slab_a_lo;")
w("    add.s32 %final_slab_a_lo, %smem_a_lo, %slot_a;")
w("    setp.lt.s32 %p0, %tx, 128;")
w("    @!%p0 bra L_skip_smoke_write;")
w("    mul.lo.s32 %off_smem, %tx, 8;")
w("    add.s32 %off_smem, %final_slab_a_lo, %off_smem;")
w("    ld.shared.b16 %h0, [%off_smem];")
w("    ld.shared.b16 %h1, [%off_smem+2];")
w("    cvt.f32.f16 %f0, %h0;")
w("    cvt.f32.f16 %f1, %h1;")
w("    cvt.u64.u32 %c_off, %tx;")
w("    mul.lo.u64 %c_off, %c_off, 8;")
w("    add.u64 %c_dst, %c_addr, %c_off;")
w("    st.global.f32 [%c_dst], %f0;")
w("    st.global.f32 [%c_dst+4], %f1;")
w("L_skip_smoke_write:")
w("    bar.sync 0;")
w("")

# --- Issue next stage (k+STAGES) into slot if k+STAGES < K_TILES -------
w("    // issue k+STAGES into the slot we just vacated (only thread 0)")
w(f"    add.s32 %issue_k, %k_iter, {STAGES};")
w(f"    setp.lt.s32 %p_issue, %issue_k, {K_TILES};")
w("    setp.eq.and.s32 %p_issue, %tx, 0, %p_issue;")
w("    @!%p_issue bra L_skip_issue;")
w("    mul.lo.s32 %issue_kx16, %issue_k, 16;")
# Same slot as current (since (k+STAGES) % STAGES == k % STAGES)
w("    mov.u32 %issue_slot_a, %slot_a;")
w("    mov.u32 %issue_slot_b, %slot_b;")
w("    mov.u32 %issue_slot_mbar, %slot_mbar;")
w("    .reg .b32 %issue_a_addr, %issue_b_addr, %issue_mbar_addr;")
w("    add.s32 %issue_a_addr, %smem_a_lo, %issue_slot_a;")
w("    add.s32 %issue_b_addr, %smem_b_lo, %issue_slot_b;")
w("    add.s32 %issue_mbar_addr, %smem_mbar_lo, %issue_slot_mbar;")
w("    mov.u32 %x0, %issue_kx16;")
w("    mov.u32 %y0, 0;")
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

# K-loop end
w("    add.s32 %k_iter, %k_iter, 1;")
w(f"    setp.lt.s32 %p0, %k_iter, {K_TILES};")
w("    @%p0 bra L_kloop;")
w("")
w("    ret;")
w("}")

out = f"sgemm_tma_multistage_s{STAGES}.ptx"
with open(out, "w") as f:
    f.write("\n".join(ptx))
    f.write("\n")

print(f"Generated {out}")
print(f"  STAGES={STAGES}, K_TILES={K_TILES}, TILE_K={TILE_K}")
print(f"  shmem: A {A_SLAB_TOTAL} B + B {B_SLAB_TOTAL} B + mbar {MBAR_TOTAL} B = "
      f"{A_SLAB_TOTAL + B_SLAB_TOTAL + MBAR_TOTAL} B")
print(f"  Final SMOKE-write slab idx = ({K_TILES-1}) %% {STAGES} = {(K_TILES-1) % STAGES}")
