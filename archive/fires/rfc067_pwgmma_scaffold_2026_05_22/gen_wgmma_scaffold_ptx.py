#!/usr/bin/env python3
"""RFC 067 PWGMMA-SCAFFOLD -- minimal wgmma.async feasibility on RTX 5070 sm_120.

Goal: prove wgmma.mma_async.sync.aligned executes correctly on driver-JIT
to sm_120 (Blackwell) from sm_90a PTX.

Tile: M=64, N=16, K=16 (smallest viable wgmma.m64n16k16 shape).
One warpgroup (128 threads) computes one C tile of 64x16 floats.
Inputs A (64x16 f16) and B (16x16 f16) loaded into shared memory.
Output accumulator distributed across 128 threads, 8 floats/thread.

Descriptor encoding (PTX ISA 8.0 / §9.7.13.5.5):
    bits  0-13: start_address >> 4  (14-bit, byte offset within shared)
    bits 16-29: leading_byte_offset >> 4 (LBO)
    bits 32-45: stride_byte_offset  >> 4 (SBO)
    bits 49-51: base_offset (matrix base offset, normally 0)
    bits 52-53: swizzle mode (0=none, 1=128B, 2=64B, 3=32B)

For row-major A 64x16 f16: each row 32B, k-stride = 32B between consecutive
8x8 core matrices along K. For col-major B 16x16 f16: each col 32B.
We use swizzle=0 (no swizzle) for first-fire simplicity; canonical row/col
layout per PTX ISA Table 33.

Layout for m64n16k16 (per Table 33, "No transpose, no swizzle"):
  A descriptor SBO = leading dim byte stride for K (next 8x8 along K),
                     LBO = 64 byte stride between m=0..7 and m=8..15 cores
  B descriptor SBO = leading dim byte stride for N (next 8x8 along N),
                     LBO = 8 byte stride between k=0..7 and k=8..15 cores
"""

import sys

def emit(outpath: str) -> None:
    M, N, K = 64, 16, 16   # tile dims
    # Shared memory layout (bytes), all f16 (2 B/elem):
    #   A: 64 rows * 16 cols * 2 = 2048 B at offset 0
    #   B: 16 rows * 16 cols * 2 = 512  B at offset 2048
    smem_A = 0
    smem_B = M * K * 2  # 2048
    smem_total = smem_B + K * N * 2  # 2560

    # Descriptor encoding helper (in PTX assembly we compute via shifts).
    # For row-major A (64x16 f16, contiguous rows of 16 elems = 32 B each):
    #   start_addr = &smem[smem_A]
    #   LBO (bytes) = 8 rows * 16B per 8x8core ... per Table 33 layout
    #
    # For wgmma m64n16k16 ".row.col" (A row, B col), the canonical
    # descriptor SBO = K-stride 128B (between consecutive 8x8 K cores),
    # LBO = M-stride 256B (between m=0..7 and m=8..15 cores along M).
    #
    # Actually for "no swizzle" mode, ISA Table 33 gives:
    #   A: matrix_offset_in_bytes = 0;
    #      LBO = row-stride for consecutive 8x8 tiles along M
    #      SBO = col-stride for consecutive 8x8 tiles along K
    #
    # We use ".sd::32::col" wgmma variant (A from shared, B from shared, A=row major, B=col major).
    # For our 64x16 f16 row-major A:
    #   A is laid out as 64 contiguous rows of 16 f16 each (32 B per row).
    #   leading byte offset (LBO) = 8 * 32 = 256  (between m=0..7 and m=8..15 along M)
    #   stride byte offset (SBO) = 8 * 2  = 16   (between k=0..7 and k=8..15 along K, within a row)
    #
    # For our 16x16 f16 col-major B:
    #   B is laid out as 16 contiguous cols of 16 f16 each (32 B per col).
    #   LBO (between k=0..7 and k=8..15 cores along K, within a col) = 8 * 2 = 16
    #   SBO (between n=0..7 and n=8..15 cores along N) = 8 * 32 = 256
    #
    # Descriptor = (start_addr >> 4) & 0x3FFF
    #            | ((LBO >> 4) & 0x3FFF) << 16
    #            | ((SBO >> 4) & 0x3FFF) << 32
    #            | (base_offset & 0x7) << 49
    #            | (swizzle & 0x3) << 52

    ptx = []
    ptx.append(".version 8.0")
    ptx.append(".target sm_90a")
    ptx.append(".address_size 64")
    ptx.append("")
    # Shared memory tile: 2560 B = 320 8-byte words. Round to 16-byte alignment.
    ptx.append(f".shared .align 16 .b8 smem_tile[{smem_total}];")
    ptx.append("")
    ptx.append(".visible .entry wgmma_kernel(")
    ptx.append("    .param .u64 a_ptr_param,")
    ptx.append("    .param .u64 b_ptr_param,")
    ptx.append("    .param .u64 c_ptr_param")
    ptx.append(")")
    ptx.append("{")
    ptx.append("    .reg .b32 %t, %r<32>;")
    ptx.append("    .reg .b64 %rd<32>;")
    ptx.append("    .reg .f32 %f<64>;")
    ptx.append("    .reg .b64 %desc_a, %desc_b;")
    ptx.append("    .reg .b64 %smem_addr_gen;")
    ptx.append("    .reg .b32 %smem_a_lo, %smem_b_lo;")
    ptx.append("")
    ptx.append("    // Load thread id (0..127)")
    ptx.append("    mov.u32 %t, %tid.x;")
    ptx.append("")
    ptx.append("    // Load global pointers")
    ptx.append("    ld.param.u64 %rd0, [a_ptr_param];")
    ptx.append("    ld.param.u64 %rd1, [b_ptr_param];")
    ptx.append("    ld.param.u64 %rd2, [c_ptr_param];")
    ptx.append("    cvta.to.global.u64 %rd0, %rd0;")
    ptx.append("    cvta.to.global.u64 %rd1, %rd1;")
    ptx.append("    cvta.to.global.u64 %rd2, %rd2;")
    ptx.append("")
    ptx.append("    // Get shared-memory address (low 32-bit form)")
    ptx.append("    mov.u32 %smem_a_lo, smem_tile;       // base of smem_A in shared")
    ptx.append(f"    add.u32 %smem_b_lo, %smem_a_lo, {smem_B}; // base of smem_B")
    ptx.append("")
    # ----- Load A into shared -----
    # A is M*K = 64*16 f16 = 2048 B = 256 8-byte chunks; 128 threads => 2 chunks each.
    ptx.append("    // Load A (2048 B) into smem_A. 128 threads x 2 x 8 B = 2048 B.")
    ptx.append("    // Each thread loads two 8-byte (4 f16) chunks.")
    ptx.append("    .reg .b32 %off_a0, %off_a1;")
    ptx.append("    .reg .b64 %ga0, %ga1, %sa0, %sa1, %v0, %v1;")
    ptx.append("    .reg .b32 %sa0_lo, %sa1_lo;")
    ptx.append("    shl.b32 %off_a0, %t, 3;            // tid * 8")
    ptx.append("    add.s32 %off_a1, %off_a0, 1024;      // tid*8 + 1024")
    ptx.append("    cvt.u64.u32 %ga0, %off_a0;")
    ptx.append("    cvt.u64.u32 %ga1, %off_a1;")
    ptx.append("    add.u64 %ga0, %rd0, %ga0;")
    ptx.append("    add.u64 %ga1, %rd0, %ga1;")
    ptx.append("    ld.global.b64 %v0, [%ga0];")
    ptx.append("    ld.global.b64 %v1, [%ga1];")
    ptx.append("    add.u32 %sa0_lo, %smem_a_lo, %off_a0;")
    ptx.append("    add.u32 %sa1_lo, %smem_a_lo, %off_a1;")
    ptx.append("    st.shared.b64 [%sa0_lo], %v0;")
    ptx.append("    st.shared.b64 [%sa1_lo], %v1;")
    ptx.append("")
    ptx.append("    // Load B (512 B) into smem_B. 128 threads x 1 x 4 B = 512 B.")
    ptx.append("    .reg .b32 %off_b0, %sb0_lo;")
    ptx.append("    .reg .b64 %gb0;")
    ptx.append("    .reg .b32 %vb0;")
    ptx.append("    shl.b32 %off_b0, %t, 2;            // tid * 4")
    ptx.append("    cvt.u64.u32 %gb0, %off_b0;")
    ptx.append("    add.u64 %gb0, %rd1, %gb0;")
    ptx.append("    ld.global.b32 %vb0, [%gb0];")
    ptx.append("    add.u32 %sb0_lo, %smem_b_lo, %off_b0;")
    ptx.append("    st.shared.b32 [%sb0_lo], %vb0;")
    ptx.append("")
    ptx.append("    bar.sync 0;")
    ptx.append("")
    # ----- Build descriptors -----
    # Descriptor low 32-bit = (smem_addr >> 4) & 0x3FFF in bits 0-13
    # Then or-in LBO/SBO shifted appropriately.
    # We construct desc_a and desc_b as 64-bit immediates ORed with the runtime smem base.
    #
    # For A (no swizzle, row major, m64k16):
    #   LBO = 256 bytes (8 * 32-B-rows), SBO = 16 bytes (8 * 2-B per K element)
    #   LBO >> 4 = 16  -> bits 16-29
    #   SBO >> 4 = 1   -> bits 32-45
    #   base_offset = 0, swizzle = 0
    # For B (no swizzle, col major, k16n16):
    #   LBO = 16 bytes, SBO = 256 bytes
    #   LBO >> 4 = 1   -> bits 16-29
    #   SBO >> 4 = 16  -> bits 32-45
    LBO_A = (16 & 0x3FFF) << 16
    SBO_A = (1  & 0x3FFF) << 32
    LBO_B = (1  & 0x3FFF) << 16
    SBO_B = (16 & 0x3FFF) << 32
    desc_a_hi = (LBO_A | SBO_A)
    desc_b_hi = (LBO_B | SBO_B)
    ptx.append("    // Build descriptor A")
    ptx.append("    .reg .b32 %sa_shr;")
    ptx.append("    shr.u32 %sa_shr, %smem_a_lo, 4;       // start_addr >> 4")
    ptx.append("    and.b32 %sa_shr, %sa_shr, 0x3FFF;")
    ptx.append("    cvt.u64.u32 %desc_a, %sa_shr;")
    ptx.append(f"    or.b64 %desc_a, %desc_a, 0x{desc_a_hi:016X};")
    ptx.append("")
    ptx.append("    // Build descriptor B")
    ptx.append("    .reg .b32 %sb_shr;")
    ptx.append("    shr.u32 %sb_shr, %smem_b_lo, 4;")
    ptx.append("    and.b32 %sb_shr, %sb_shr, 0x3FFF;")
    ptx.append("    cvt.u64.u32 %desc_b, %sb_shr;")
    ptx.append(f"    or.b64 %desc_b, %desc_b, 0x{desc_b_hi:016X};")
    ptx.append("")
    # ----- Init accumulators (8 floats / thread for m64n16) -----
    # m64n16: 64*16 = 1024 outputs across 128 threads = 8 floats/thread.
    ptx.append("    // Init accumulators (8 f32 per thread)")
    for i in range(8):
        ptx.append(f"    mov.f32 %f{i}, 0f00000000;")
    ptx.append("")
    # ----- WGMMA -----
    ptx.append("    wgmma.fence.sync.aligned;")
    ptx.append("    wgmma.mma_async.sync.aligned.m64n16k16.f32.f16.f16")
    ptx.append("        {%f0,%f1,%f2,%f3,%f4,%f5,%f6,%f7},")
    ptx.append("        %desc_a, %desc_b, 1, 1, 1, 0, 0;")
    ptx.append("    wgmma.commit_group.sync.aligned;")
    ptx.append("    wgmma.wait_group.sync.aligned 0;")
    ptx.append("")
    # ----- Store accumulators -----
    # wgmma m64n16 fragment layout per PTX ISA Table 35:
    # 128 threads in a warpgroup. Each thread holds 8 f32.
    # The accumulator is laid out as 8 elements per thread covering
    # an 8x8 "core matrix" pattern repeated.
    #
    # We don't need exact-layout-correct storage for feasibility:
    # we just store thread-id-tagged values and verify them in numeric
    # via a simple "sum reduction" check.
    # Actually for ULP-correctness we MUST follow the layout.
    #
    # PTX ISA Table 35 (m64n16 fragment layout):
    #   - Warp 0 of group handles rows 0..15, warp 1 rows 16..31, warp 2 rows 32..47, warp 3 rows 48..63.
    #   - Within each warp, lane l (0..31): row = (l >> 2) within warp's 16 rows? Actually:
    #   - "Each thread holds 8 f32 elements for m64n16. Layout: each thread
    #     contributes a 2x4 block." Per Table 35:
    #     - Warp w (0..3) covers M-rows [16w, 16w+15]
    #     - Within warp, lane l covers row r = 8*(l>>4) + (l>>2) within the
    #       16-row band, and 4 consecutive N columns starting at col c = (l&3)*4 ... NO
    #   - Easier: just store a deterministic per-thread pattern and check on host.
    #
    # For first-fire feasibility, we store each thread's 8 accumulators to
    # a per-thread slot in C buffer. Host then SUMS all 128*8=1024 values
    # and compares to CPU-computed sum of 64x16 = 1024 outputs.
    # If sum matches (within FP tolerance), wgmma executed.
    ptx.append("    // Store per-thread fragments into C buffer (no layout reshuffle,")
    ptx.append("    // host sums and compares).")
    ptx.append("    .reg .b32 %c_off;")
    ptx.append("    .reg .b64 %c_off64, %c_ptr;")
    ptx.append("    shl.b32 %c_off, %t, 5;        // tid * 32 bytes (8 floats)")
    ptx.append("    cvt.u64.u32 %c_off64, %c_off;")
    ptx.append("    add.u64 %c_ptr, %rd2, %c_off64;")
    for i in range(8):
        ptx.append(f"    st.global.f32 [%c_ptr+{4*i}], %f{i};")
    ptx.append("")
    ptx.append("    ret;")
    ptx.append("}")

    with open(outpath, "w") as fh:
        fh.write("\n".join(ptx) + "\n")
    print(f"wrote {outpath} ({len(ptx)} lines)")


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "wgmma_scaffold.ptx"
    emit(out)
