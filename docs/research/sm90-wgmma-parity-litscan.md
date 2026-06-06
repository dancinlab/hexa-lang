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

## Q3 — arXiv: Hopper GEMM / attention kernel design principles

### Synthesis

**FlashAttention-3 (arXiv:2407.08608)** is the canonical demonstration that the *same*
three Hopper levers from Q2 apply to a fused kernel: (i) **producer-consumer warp
specialization** — one warpgroup runs TMA, another runs async WGMMA, overlapping without
explicit sync; (ii) **ping-pong interleaving** of the two GEMMs and softmax (block-wise,
so tensor cores never wait on the softmax); (iii) exploiting **TMA + WGMMA asynchrony** to
overlap compute and data movement. Result: 75% H100 FP16 utilization (740 TFLOP/s),
1.5–2.0× over FA2 (which only reached 35%). The headline lesson for us: the jump from
~35% to ~75% of peak came *entirely* from async warp-spec + overlap, **not** from any new
math — exactly the regime our 66.5 (post-tensor-core, pre-warp-spec) sits in.

**ThunderKittens (arXiv:2410.20399)** distills the design into a 3-level abstraction:
warp-level 16×16 tiles, a **block-level template for overlapping async operations across
warps** (the warp-spec scaffold), and grid-level launch/teardown hiding. It claims to
**match cuBLAS on GEMM and FlashAttention-3 on attention**. The takeaway: cuBLAS-parity is
reachable from a small fixed set of abstractions (tile + async-overlap template +
swizzled SMEM layouts), confirming the parity gap is *engineering of the async pipeline*,
not an exotic algorithm.

**"Optimal Software Pipelining and Warp Specialization for Tensor Core GPUs"
(arXiv:2512.18134, "Twill")** treats pipeline depth (SWP stages) and warp specialization
(WS) as a *joint* optimization, and reports rediscovering — and proving optimal — the
exact SWP+WS schedules experts hand-wrote for FlashAttention on Hopper and Blackwell.
Implication: pipeline depth and the producer/consumer split are coupled and have an
*optimal* setting per problem shape — i.e. our "how many mbarrier stages" question is not
a free knob but a solvable trade-off (deeper hides more latency but costs SMEM/occupancy).

(Secondary, noted not deep-read: **Tawa (arXiv:2510.14719)** and **Task-Based Tensor
Computations (arXiv:2504.07004)** both automate warp specialization / task scheduling for
Hopper — corroborating that WS is the dominant lever but not adding a new principle.)

**Design principles applicable to our TF32 own-GEMM:**
1. **Async-everything** — TMA load and WGMMA must run concurrently via mbarrier, never
   serialized; this alone is the 35%→75% lever (FA3).
2. **Warp specialization** producer/consumer with `setmaxnreg` asymmetry (FA3 + Q2).
3. **Overlap the epilogue** with the mainloop via a second consumer (ping-pong) so tensor
   cores never idle (FA3 ping-pong, PyTorch ping-pong in Q2).
4. **Swizzled SMEM layouts feed WGMMA directly** with no bank conflicts (TK, FA3) — this
   is precisely our W9 swizzle work, and the literature treats it as table-stakes for the
   async pipeline to not stall.

### Sources
- FlashAttention-3 — Shah et al., arXiv:2407.08608 (warp-spec, ping-pong GEMM/softmax, async TMA+WGMMA, 75% H100 util / 740 TFLOP/s FP16, 1.5–2.0× over FA2): https://arxiv.org/abs/2407.08608
- ThunderKittens — Spector et al., arXiv:2410.20399 (16×16 tile, block-level async-overlap template, matches cuBLAS GEMM + FA3 attention): https://arxiv.org/abs/2410.20399
- "Optimal Software Pipelining and Warp Specialization for Tensor Core GPUs" (Twill) — arXiv:2512.18134 (joint SWP+WS optimization, rediscovers expert FA schedules on Hopper/Blackwell): https://arxiv.org/abs/2512.18134
- Tawa: Automatic Warp Specialization for Modern GPUs — arXiv:2510.14719 (secondary; WS automation): https://arxiv.org/pdf/2510.14719
- Task-Based Tensor Computations on Modern GPUs — arXiv:2504.07004 (secondary; task scheduling on Hopper): https://arxiv.org/abs/2504.07004

---

## Q4 — cooperative-kernel grid-sync reductions: occupancy + numeric reproducibility

### Synthesis

**The mechanism.** A grid-wide barrier inside a persistent kernel uses Cooperative
Groups `cg::this_grid().sync()` (a `grid_group`), which **requires the kernel be launched
with `cudaLaunchCooperativeKernel`** (NVIDIA CUDA Programming Guide). NVIDIA explicitly
lists "a global reduction to a single value" and "looping over rows of a large matrix
sequentially using the entire grid" as the canonical applications — i.e. exactly our
fuse-two-GroupNorm-full-y-reductions case.

**The occupancy / one-wave constraint (the hard limit).** A cooperative launch's grid
"must be no larger than the maximum number of active blocks on the device … exceeding
this results in `CUDA_ERROR_COOPERATIVE_LAUNCH_TOO_LARGE`" (NVIDIA driver API /
Cooperative Groups docs). Grid sync only works if **every block is co-resident in one
wave** — a grid barrier cannot make a block that hasn't been scheduled yet participate.
**Consequence for our megakernel:** the persistent whole-step kernel must size its grid
to `numSMs × maxActiveBlocksPerSM` (via `cudaOccupancyMaxActiveBlocksPerMultiprocessor`),
not to the problem size. This couples the GroupNorm-fusion grid-sync directly to the
GEMM mainloop's register/SMEM footprint: every `setmaxnreg` / pipeline-stage choice from
Q2 that raises per-block resource use *lowers* `maxActiveBlocksPerSM`, shrinking the
maximum cooperative grid — there is a real tension between the deep-pipeline GEMM levers
and the one-wave requirement of the fused grid-sync reduction.

**The numeric-reproducibility risk (the bit-exact threat).** Our own-GEMM is bit-exact;
a grid-wide GroupNorm reduction can *break* that. Floating-point addition is
non-associative, so a parallel/grid-wide combine that uses **`atomicAdd` of partial sums
accumulates in nondeterministic order** and is therefore **not reproducible run-to-run**
(arXiv:2408.05148; the "SPA / simple-pass-with-atomicAdd" pattern is explicitly called
out as nondeterministic). The paper notes the sensitivity of DL pipelines to this can be
"extreme." The deterministic fix is a **fixed-order reduction**: a canonical binary-tree
combine via warp/shared-memory intrinsics with a reduction order identical across runs
(and *no* float atomics), so the rounding path is reproducible. **Implication for our
cooperative GroupNorm:** to keep the megakernel bit-exact against the sequential
two-kernel baseline, the grid-wide combine must be a **deterministic fixed-order tree
across blocks** (e.g. write per-block partials to a scratch array, `grid.sync()`, then one
designated block reduces them in a fixed index order) — **never `atomicAdd`**. A naive
atomic grid-reduce would reproduce, at the GroupNorm boundary, exactly the kind of
non-bit-exact failure our W9 naive-swizzle hit (rel-RMS ≠ 0).

### Sources
- NVIDIA CUDA Programming Guide — "Cooperative Groups" (`this_grid()`, `grid_group.sync()`, requires `cudaLaunchCooperativeKernel`, global-reduction-to-single-value use case): https://docs.nvidia.com/cuda/cuda-programming-guide/04-special-topics/cooperative-groups.html
- NVIDIA Technical Blog — "Cooperative Groups: Flexible CUDA Thread Programming" (grid-group barrier, global reduction example): https://developer.nvidia.com/blog/cooperative-groups/
- NVIDIA CUDA Driver API docs — cooperative launch occupancy limit (grid ≤ max active blocks; `CUDA_ERROR_COOPERATIVE_LAUNCH_TOO_LARGE`; `cudaOccupancyMaxActiveBlocksPerMultiprocessor`): https://docs.nvidia.com/cuda/cuda-c-programming-guide/ (Cooperative Groups / occupancy sections)
- "Impacts of floating-point non-associativity on reproducibility for HPC and deep learning applications" — arXiv:2408.05148 (atomicAdd reductions nondeterministic; fixed-order tree reduction for reproducibility; extreme DL sensitivity): https://arxiv.org/abs/2408.05148
- "Numerical reproducibility for the parallel reduction on multi- and many-core architectures" — Iakymchuk et al., ScienceDirect (secondary; reduction-order determinism): https://www.sciencedirect.com/science/article/abs/pii/S0167819115001155

---

## Implications for W10 / parity / megakernel

**(A) W10 swizzle — does the literature confirm `g_phys = g XOR ((r+1)&7)`?**
**YES, the *form* is confirmed; the `+1` is explained, not refuted.** The canonical CuTe
`Swizzle<3,4,3>` (primary: `cute/swizzle.hpp`) is exactly "3 row bits XOR'd into the
16B-column-block field, mod 8," and two secondary blogs reduce 128B mode to
`col ^= (row + offset) mod 8`. Our `(r+1)` is the `offset`/wgmma **matrix-base-offset**
phase (a constant additive shift inside the `& 7`), a documented descriptor field, not an
anomaly. The remaining W10 task — composing the XOR with the **non-compact 8×16B
core-matrix tiling** (TF32 core matrix = 8 rows × 4 elems × 4B = 8×16B) — is *confirmed
necessary* by Colfax's "for 64/128B swizzle the layouts are not compact … 2 or 4 atoms
stacked side-by-side in K." Compose as `phys = Swizzle<3,4,3>( core_matrix_tile(logical) )`,
not `Swizzle(row-major)`; our naive rel-RMS 1.392 is the row-major-vs-tiled signature.

**(B) Top-3 named levers 66.5 → parity** (from the `cudaforfun` ladder + FA3 + PyTorch
ping-pong; relative jumps transfer to TF32 even though absolute peaks differ):
1. **Larger output tiles** (e.g. 128×128 → 128×256) — biggest single jump in the worklog
   (+34% then enabling +27%); more accumulator reuse per TMA load.
2. **Warp specialization** (1 producer + 2 consumer warpgroups, `setmaxnreg` 40/232
   asymmetry) — the 35%→75%-of-peak lever in FA3; producer does only TMA, consumers only
   WGMMA, fully overlapped via mbarrier (+18% in the ladder, larger in FA3 regime).
3. **Ping-pong epilogue overlap + TMA multicast** — two consumers alternate MMA/epilogue
   so tensor cores never idle (+27% ladder), plus cluster TMA multicast (+4%). W9's
   swizzle is the *precondition* (table-stakes) for these to not stall on bank conflicts.

The literature's verdict: the 6.44× is **engineering of the async warp-specialized
pipeline**, not a missing algorithm — ThunderKittens reaches cuBLAS-parity from a small
fixed abstraction set; FA3 got 35%→75% purely from async+warp-spec+overlap.

**(C) Cooperative-GroupNorm numeric finding.** The grid-sync fusion has **two coupled
risks**: (1) the **one-wave occupancy cap** — cooperative grid ≤ `numSMs ×
maxActiveBlocksPerSM`, which *fights* the deep-pipeline GEMM levers in (B) (more
registers/stages → fewer resident blocks → smaller legal grid); size the grid via
`cudaOccupancyMaxActiveBlocksPerMultiprocessor`. (2) **bit-exactness** — a grid-wide
combine via `atomicAdd` is **nondeterministic** (FP non-associativity, arXiv:2408.05148)
and *will* break our bit-exact property at the GroupNorm boundary. Mandate a
**deterministic fixed-order cross-block tree reduction** (per-block partials → scratch →
`grid.sync()` → fixed-index final combine, no float atomics) to preserve byte-equality
against the sequential two-kernel baseline.

---

*Compiled as a literature scan (research, not a measured verdict). Primary sources
(PTX ISA / CuTe source / NVIDIA docs) preferred over blogs where they overlap; secondary
sources are labelled. No performance number in this note is our own measurement.*
