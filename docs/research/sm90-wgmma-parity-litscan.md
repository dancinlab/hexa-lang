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

## Q2 — sm_90a warp-specialized persistent TMA GEMM mainloop: the named levers 66.5→parity

### Synthesis

**The canonical CUTLASS 3.x design** (NVIDIA `efficient_gemm` doc + PyTorch ping-pong
deep-dive) is: a persistent thread block split into **1 producer warpgroup + 2 consumer
warpgroups** (128 threads each). The producer does *only* TMA `cp.async.bulk` loads into a
circular SMEM buffer; consumers do *only* `wgmma.mma_async`. Coordination is an
**async mbarrier pipeline** (producer_acquire/commit ↔ consumer_wait/release) deep enough
to hide TMA latency. Key concrete levers:

- **Register reallocation (`setmaxnreg`):** producer warps dropped to **40 registers**,
  consumer warps raised to **232 registers** (PyTorch ping-pong). The producer is
  deliberately register-starved (it only issues TMA) to free registers for the
  math-heavy consumers, raising occupancy and keeping many MMAs in flight.
- **Two consumers / ping-pong epilogue overlap:** "one [consumer] can be using the
  tensor cores for MMA while the other performs the epilogue, and then vice-versa …
  maximizes continuous usage of the tensor cores" (PyTorch). This is what turns a
  tensor-core kernel that stalls during epilogue into one with **zero idle tensor-core
  cycles**.
- **TMA multicast across the thread-block cluster:** TMA multicasts a tile to all SMs of
  a cluster, cutting redundant HBM traffic (PyTorch / NVIDIA doc).
- **Persistent tile scheduler:** one block lives for many output tiles, amortizing the
  launch + prologue (`while(work_tile.is_valid){ mainloop.dma(); scheduler.advance(); }`).
- **"Async everything":** deep software pipelining is *mandatory* for Hopper — "Hopper's
  substantial tensor-core compute requires deep asynchronous software pipelining to
  achieve peak" (PyTorch).

**The ordered lever→TFLOP ladder.** The `cudaforfun` H100 worklog is the single most
directly applicable source: it traces a *working* TF16 `wgmma`+TMA kernel from 317 to 764
TFLOP/s (107% of its cuBLAS 716), naming each lever and its gain. This is the map for our
66.5→parity gap. Reproduced verbatim (their numbers, FP16; our regime is TF32 so absolute
peaks differ, but the **lever ordering and relative jumps transfer**):

| step | lever | TFLOP/s | gain |
|---|---|---|---|
| 1 | naive (Simon's algo) | 32 | — |
| 2 | tensor cores + TMA + CUDA barriers working together | 317 | 10× |
| 3 | larger output tiles 128×128 (`m64n128k16`) | 423 | +34% |
| 4 | **warp specialization** (producer/consumer split) | 498 | +18% |
| 5 | tile 128×256 + **2 consumer warpgroups** | 631 | +27% |
| 6 | SM clustering + L2-aware scheduling | 660 | +5% |
| 7 | faster barriers (raw PTX over CUDA API) | 704 | +7% |
| 8 | thread-block clusters + **TMA multicast** | 734 | +4% |
| 9 | micro-opt (store reorder, cache hints) | 747 | +2% |
| 10 | async stores via TMA to GMEM | 758 | +1.5% |
| 11 | Hilbert-curve spatial scheduling | 764 | +0.8% |

**Reading this for us.** Our 66.5 TF32 sits *after* "tensor cores + TMA work together"
(their step 2) but *before* the big mainloop levers. The literature says the dominant
remaining jumps — in order of payoff — are **larger output tiles** (step 3, +34%),
**warp specialization producer/consumer** (step 4, +18%), and **two consumer warpgroups
with ping-pong epilogue overlap** (step 5, +27%). These three compound to ~2× before the
diminishing-returns cluster/barrier micro-levers. The W9 swizzle work belongs to step 2's
"TMA + tensor cores working together cleanly" — it removes the cooperative-permute stall
that otherwise caps the mainloop, i.e. it is a *precondition* for the step-3/4/5 levers to
pay off (a swizzle stall would otherwise mask their gains).

### Sources
- NVIDIA CUTLASS — "Efficient GEMM in CUDA" (primary doc; producer/consumer warp spec, `setmaxnreg` register de/allocation, persistent cooperative kernel, pipeline stages): https://docs.nvidia.com/cutlass/latest/media/docs/cpp/efficient_gemm.html
- PyTorch blog — "Deep Dive on CUTLASS Ping-Pong GEMM Kernel" (producer 40 reg / consumer 232 reg, 1 producer + 2 consumer, ping-pong epilogue overlap, TMA multicast, persistent scheduler): https://pytorch.org/blog/cutlass-ping-pong-gemm-kernel/
- cudaforfun (substack) — "Outperforming cuBLAS on H100: a Worklog" (ordered lever→TFLOP ladder 317→764, 107% cuBLAS): https://cudaforfun.substack.com/p/outperforming-cublas-on-h100-a-worklog
- Hamza's blog — "Optimising GEMM on H100 for cuBLAS-like Performance (WIP)" (secondary, kernels 1–7 progression up to TMA+WGMMA; advanced levers WIP/not yet written): https://hamzaelshafie.bearblog.dev/worklog-optimising-gemm-on-nvidia-h100-for-cublas-like-performance-wip/
- Colfax Research — "CUTLASS Tutorial: GEMM kernel design with Pipelining" (mbarrier pipeline depth, double buffering): https://research.colfax-intl.com/cutlass-tutorial-design-of-a-gemm-kernel/

---
