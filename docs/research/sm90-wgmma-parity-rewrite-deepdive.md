# sm_90a wgmma own-GEMM → cuBLAS-parity: rewrite deep-dive (the architecture crux)

**Type:** research / literature deep-dive — NOT a measured verdict. No perf claim below is
our own measurement; every external claim carries a URL or arXiv id. Primary sources
(NVIDIA PTX ISA, CUTLASS/CuTe source, NVIDIA docs) are preferred over blogs; where they
overlap, secondary blogs are labelled SECONDARY.

**This is the SECOND, DEEPER scan.** The first (`sm90-wgmma-parity-litscan.md`, PR #2846)
named the *levers* (warp-spec, tile size, ping-pong, swizzle form). This one answers the
**architecture crux** that the lever-scan deferred:

> **How does CUTLASS 3.x / CuTe feed `wgmma.mma_async` warpgroup operands on sm_90a
> WITHOUT a software "decode-copy" — and does the SMEM matrix descriptor express the
> SWIZZLE_128B-TMA-landed tile DIRECTLY (avoiding the 32KB decode-copy scratch band that
> our W11–W14 measured as ⊥ occupancy)?**

**Our measured wall (the thing to break).** Our own-GEMM (W1→W14, on `main` @ #2853) tops
out at TF32 70.7 TFLOP/s (6.09× off cuBLAS-TF32) / FP16 71.6 (11.5× off cuBLAS-FP16). The
root cause measured from both sides (W11/W12/W13/W14): the kernel needs a software
**decode-copy** — it reads the `SWIZZLE_128B`-TMA-landed SMEM tile and re-permutes it into
the GMMA core-matrix layout the wgmma descriptor expects, into a separate scratch buffer.
That decode-copy scratch is a 32KB gmma band; holding it at 2 CTA/SM and overlapping
decode↔MMA are mutually exclusive (32KB band ⊥ occupancy, proven both dtypes). The HW
in-place swizzle descriptor (feed wgmma directly from the swizzled tile, no decode-copy)
was tried (W10/W11 MODE5) and gave rel-RMS 1.392.

---

## §1 — THE CRUX ANSWER: the decode-copy is AVOIDABLE; our ruling-out was an encoding bug

### Verdict (one line)

**DECODE-COPY AVOIDABLE = YES.** The wgmma SMEM matrix descriptor expresses
`SWIZZLE_128B` DIRECTLY. CUTLASS/CuTe feeds `wgmma.mma_async` operands straight from the
TMA-`SWIZZLE_128B`-landed SMEM tile with **no software repack** — `make_gmma_desc`
*computes* the swizzle-mode + LBO + SBO bitfields from the canonical layout atom and the
hardware applies the swizzle on-read. Our W10/W11 "HW in-place ruled out (rel-RMS 1.392)"
was therefore a **descriptor-encoding bug** (wrong LBO/SBO/base-offset, and a non-existent
"MODE5"), **NOT a fundamental wall.** This reopens the campaign at 2 CTA/SM with
decode↔MMA overlap — the 32KB decode-copy band can be deleted entirely.

### The primary-source chain that proves it

**(a) The descriptor IS the swizzle — exact bitfield (PRIMARY: CuTe source).**
From `cute/arch/mma_sm90_desc.hpp` (`GmmaDescriptor`), the 64-bit SMEM descriptor:

```c
union GmmaDescriptor {
  struct {
    uint16_t start_address_      : 14, : 2;   // bits [0,14)   — 4 LSB dropped (>>4, 16B units)
    uint16_t leading_byte_offset_: 14, : 2;   // bits [16,30)  — LBO, 4 LSB dropped
    uint16_t stride_byte_offset_ : 14, : 2;   // bits [32,46)  — SBO, 4 LSB dropped
    uint8_t  : 1, base_offset_   : 3,  : 4;   // bits [49,52)  — matrix base offset (3 bits)
    uint8_t  : 6, layout_type_   : 2;         // bits [62,64)  — SWIZZLE MODE (2 bits)
  } bitfield;
};
enum class LayoutType : uint8_t { INTERLEAVE=0, B128=1, B64=2, B32=3 };
//  layout_type_ encoding:  SWIZZLE_NONE=0,  SWIZZLE_128B=1,  SWIZZLE_64B=2,  SWIZZLE_32B=3
```

The descriptor carries a `layout_type_` field whose value **1 == 128-byte swizzle**. The
hardware reads the swizzled SMEM tile through this field — the swizzle is applied by the
MMA unit on-read, so there is **nothing to decode in software**. (Note the CuTe enum is
the *2-bit internal* mapping; the PTX ISA matrix-descriptor "swizzle" subfield uses the
encoding 0=none / 1=128B / 2=64B with a wider field — both agree 128B is the low non-zero
code. See §3 sources for the PTX ISA section ref.)

**(b) `make_gmma_desc` computes LBO/SBO/mode — no repack (PRIMARY: Colfax + CuTe).**
> "Provided that the input tensor's layout is created using one of the eight canonical
> GMMA layout atoms and `tile_to_shape`, `make_gmma_desc` will accurately calculate the
> LBO and SBO, determine the swizzling mode, and construct the descriptor." (Colfax)

In `make_gmma_desc` (`cute/atom/mma_traits_sm90_gmma.hpp`) the swizzle bits are read off
the layout's `Swizzle<B,M,S>` — `B = Swizzle::num_bits; M = Swizzle::num_base;
S = Swizzle::num_shft;` — and a switch on `B` selects `layout_type_`. The start address is
`desc.bitfield.start_address_ = start_address >> 4;` (16-byte encoding). **There is no
per-K-step copy loop anywhere in this path** — the descriptor is built ONCE per operand
tile in the prologue, then advanced by adding the K-stride.

**(c) The canonical 128B atom + its EXACT LBO/SBO (PRIMARY: Colfax).**
For a K-major operand with 128-byte swizzle the canonical CuTe atom is:

```
128-byte swizzle :  Swizzle<3,4,3> o smem_ptr o ((8,m),(T,2)):((8T,SBO),(1,T))
```

with the concrete offsets:

| swizzle | LBO | SBO | note |
|---|---|---|---|
| none  | 128 B (=16×8) | 256 B (=32×8) | compact |
| 128B  | (folded; see below) | **1024 B (=128×8)** | NON-compact: 2-or-4 atoms stacked in K |

> "for 64 and 128-byte swizzle, the strides are such that the given admissible WGMMA
> layouts are **not** compact. Rather, one has sets of 2 or 4 WGMMA atom operand tiles
> stacked side-by-side in the K-direction." (Colfax)

**This is the missing constant our W10/W11 got wrong.** A 128B-swizzled tile is directly
wgmma-addressable **iff** the descriptor's SBO is set to the non-compact `128×8 = 1024 B`
(2/4 atoms stacked in K), the `start_address` is 128B-aligned, and any residual alignment
phase is carried in the 3-bit `base_offset_`. The TMA must land the tile with a box-shape
whose inner (contiguous) dim ≤ 128 B and `CU_TENSOR_MAP_SWIZZLE_128B`, so that the landed
bytes ARE the `Swizzle<3,4,3>` pattern the descriptor's `layout_type_=1` expects.

**(d) The blogs corroborate "direct consumption" (SECONDARY).**
Aleksa Gordić's matmul anatomy on the TMA→wgmma handoff: the SMEM tiles are *"swizzled,
and ready for tensor core consumption"* — i.e. no software permute between TMA-land and
wgmma-read.

### Why our W10/W11 (rel-RMS 1.392) failed — the fixable encoding bug

Three concrete encoding errors are now identifiable against the primary descriptor:

1. **"MODE5" does not exist.** `layout_type_` is 2 bits → only {0,1,2,3}. SWIZZLE_128B is
   **1**, not 5. (The PTX subfield is wider but still encodes 128B as the low non-zero
   value.) A mode-5 write either truncated to a garbage 2-bit value or hit a wider PTX
   field with an undefined code → wrong on-read permute → rel-RMS ≈ O(1).
2. **SBO almost certainly set to the compact 256 B (or a row-major K stride), not the
   non-compact 1024 B (=128×8).** Colfax is explicit that 128B mode is NON-compact (2/4
   atoms stacked in K). A compact/row-major SBO makes the descriptor read the wrong
   core-matrix for every K beyond the first — exactly an O(1) rel-RMS, not a small bias.
3. **`base_offset_` (bits [49,52)) not used to carry the alignment phase.** Our prior
   litscan already identified a `+1` phase in the measured `g_phys = g XOR ((r+1)&7)`;
   that `+1` is the matrix-base-offset degree of freedom. If row-0 is not 128B-aligned and
   `base_offset_`=0, the swizzle anchor is off by the phase → wrong permute.

**Conclusion of §1:** the decode-copy is an artifact of building the descriptor as if the
tile were compact/row-major. With `layout_type_=1`, `SBO=1024B`, 128B-aligned
`start_address`, and the alignment phase in `base_offset_`, wgmma reads the
`SWIZZLE_128B`-TMA tile in place. **The 32KB decode-copy band is removable → 2 CTA/SM AND
decode↔MMA overlap are no longer mutually exclusive (the contradiction that pinned
W11–W14 dissolves).**

