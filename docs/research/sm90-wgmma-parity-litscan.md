# sm_90a wgmma own-GEMM → cuBLAS-parity: literature scan

**Type:** research / literature scan — NOT a measured verdict. No perf claim below is
our own measurement; every external claim carries a URL or arXiv id. Where a primary
source (NVIDIA PTX ISA, CUTLASS/CuTe source) contradicts a secondary blog, the primary
is preferred and the blog is labelled secondary.

**Targeting context (our state, for the reader):** we have a bit-exact TF32 `wgmma`+TMA
own-GEMM on native `sm_90a`, frontier W8 ≈ 66.5 TFLOP/s, ~6.44× off cuBLAS-TF32. The
frontier is compute/mainloop-bound. W9 proved a `SWIZZLE_128B` TMA descriptor removes
the per-K-step cooperative permute (SASS-confirmed 28→0 shared stores) but the *naive*
swizzle failed bit-exact (rel-RMS 1.392). The on-pod measured FP32-128B law was
`g_phys = g XOR ((r+1) & 7)`, which must compose with the 8×4 INTER GMMA core-matrix
packing for TF32. W10 composes those two permutations.

---

## Q1 — Hopper SWIZZLE_128B shared-memory layout & GMMA core-matrix composition

### Synthesis

**The canonical CuTe swizzle.** The 128-byte TMA/GMMA swizzle is `Swizzle<3,4,3>` in
CuTe notation (`GMMA::Layout_K_SW128_Atom`). The CuTe `Swizzle<B,M,S>` operator is a pure
bit-permutation on a linear offset, defined in `include/cute/swizzle.hpp` as:

```
bit_msk  = (1 << B) - 1
yyy_msk  = bit_msk << (M + max(0,S))
zzz_msk  = bit_msk << (M - min(0,S))
apply(offset) = offset ^ shiftr(offset & yyy_msk, S)
```

i.e. it extracts `B` "row" bits, shifts them by `S`, and XORs them into a lower
`B`-bit "column-block" field. `M` (MBase) is the count of least-significant bits held
constant (the within-element / within-16B-vector bits). For `Swizzle<3,4,3>`: `B=3`
(an 8-way permutation), `M=4` (keep the low 16 bytes — one 128-bit vector — intact),
`S=3`. Net effect: **three row bits XOR into three column-block bits**, i.e.
`col_block ^= (row & 7)` at 16-byte-vector granularity, with the period repeating every
8 rows. (Sources differ on the exact absolute bit positions — leimao/CuTe-source place
`yyy` at bits `M+S..` and `zzz` at bits `M..`; the simons math blog draws the picture
at bits 8–10 → 5–7 for a specific element width. The *structure* — 3 row bits XOR'd
into the 16B-vector-index field, mod 8 — is consistent across all of them and is the
load-bearing fact.)

**The concrete access form.** Two independent secondary sources reduce the 128B mode to
the same closed XOR form at 16-byte granularity:

- simons CuTeDSL blog: `smem[y][((y+offset)%8) ^ x]` (y = row, x = 16B column index,
  `offset` = initial row offset).
- simons matrix-transpose blog (attributing the formula to an NVIDIA GTC talk by Igor
  Terentyev): `x16 = i16 & 7; y16 = i16 >> 3; x16_swz = y16 ^ x16`.

Both say the 128-byte swizzle XORs the row index (mod 8) into the 16-byte-column index.
This is *structurally identical* to our measured `g_phys = g XOR ((r+1) & 7)` — XOR of a
function of the row into the 16B column block, mod 8 — **except for the `+1` offset on
the row term.** That `+1` is exactly the `offset`/`MatrixBaseOffset` degree of freedom:
the swizzle is anchored relative to the SMEM base, and the wgmma descriptor carries a
**"matrix base offset … used to resolve SMEM alignment problems"** (Colfax). A non-zero
matrix-base-offset (or a row-0 that does not sit at a 128B-aligned SMEM address)
manifests exactly as a constant additive shift on the row term inside the `& 7`. So the
literature **confirms the *form*** of our law and **explains the `+1` as the base-offset
phase**, not as a contradiction.

**Composition with the GMMA core matrix.** The wgmma SMEM matrix descriptor encodes five
fields (Colfax / PTX ISA): start address, **LBO** (leading-dim byte offset = stride
between adjacent core matrices in K), **SBO** (stride-dim byte offset = stride in M/N),
**swizzle mode** (none/32/64/128B), and **matrix base offset**. A *core matrix* is
8 (strided) × 16 bytes (contiguous). For 64- and 128-byte swizzle the admissible WGMMA
layouts are **not compact** — "one has sets of 2 or 4 WGMMA atom operand tiles stacked
side-by-side in the K-direction" (Colfax). So the 128B mode bundles core matrices into a
8×128B repack unit and the descriptor's LBO/SBO must be set for the *non-compact stacked*
layout, not a naive row-major K tile. **This is the second permutation our W10 must
compose:** the `Swizzle<3,4,3>` XOR is applied on top of the non-compact 8×16B
core-matrix tiling (for TF32 the per-core-matrix element packing is 8×4 elements =
8 rows × (4×4B = 16B)), so the physical SMEM index is
`swizzle( core_matrix_tiling( logical_index ) )`, never `swizzle(row-major)`. Our naive
rel-RMS 1.392 is the expected signature of applying the swizzle to a row-major rather
than core-matrix-tiled index.

**Confirm/refute verdict (research-level):** the textbook `Swizzle<3,4,3>` /
`g_phys = g XOR (f(r) & 7)` form is **CONFIRMED** by primary CuTe source + two secondary
blogs; our specific `(r+1)` matches once the wgmma **matrix-base-offset** phase is folded
in. The remaining work (compose with the non-compact 8×16B core-matrix tiling) is
**confirmed as necessary** by the Colfax "not compact / stacked side-by-side" statement.

### Sources
- NVIDIA/cutlass — `include/cute/swizzle.hpp` (primary; `Swizzle<B,M,S>`, `yyy_msk`/`zzz_msk`, `offset ^ shiftr(offset & yyy_msk, S)`): https://github.com/NVIDIA/cutlass/blob/main/include/cute/swizzle.hpp
- NVIDIA/cutlass — `examples/cute/tutorial/hopper/wgmma_tma_sm90.cu` (primary; `GMMA::Layout_K_SW128_Atom` usage): https://github.com/NVIDIA/cutlass/blob/main/examples/cute/tutorial/hopper/wgmma_tma_sm90.cu
- Colfax Research — "CUTLASS Tutorial: Fast Matrix-Multiplication with WGMMA on Hopper" (descriptor fields, core matrix 8×16B, non-compact 64/128B stacking, matrix base offset): https://research.colfax-intl.com/cutlass-tutorial-wgmma-hopper/
- NVIDIA CUDA Driver API — Tensor Map Object Management (`cuTensorMapEncodeTiled`, `CU_TENSOR_MAP_SWIZZLE_128B`, inner box dim ≤128 constraint): https://docs.nvidia.com/cuda/cuda-driver-api/group__CUDA__TENSOR__MEMORY.html
- simons blog — "Understanding CuTe Swizzling: the math behind 32B/64B/128B" (secondary; `Swizzle<3,4,3>` bit-flip picture): https://veitner.bearblog.dev/understanding-cute-swizzling-the-math-behind-32b-64b-and-128b-patterns/
- simons blog — "Swizzles and their usage in CuTeDSL Kernels" (secondary; `smem[y][((y+offset)%8)^x]`): https://veitner.bearblog.dev/swizzles-and-their-usage-in-cutedsl-kernels/
- simons blog — "Making matrix transpose really fast on Hopper" (secondary; `x16_swz = y16 ^ x16`, attributes to Igor Terentyev GTC talk): https://veitner.bearblog.dev/making-matrix-transpose-really-fast-on-hopper-gpus/
- Lei Mao — "CuTe Swizzle" (secondary; concrete `Swizzle<3,4,3>` masks): https://leimao.github.io/blog/CuTe-Swizzle/

---
