# QFORGE-PERF M35 — GPU accel lever quantification (α²F BZ-sum assembler)

@title: 🧪 M35 — measured GPU speedup of the el-ph α²F BZ-sum hot kernel

Measured on the M27 pod (vast 39481710 · **RTX PRO 6000 Blackwell · sm_120 · 188 SMs**
· CUDA 12.4 · driver 580.95). The kernel is the L3 α²F(ω) double-delta BZ-sum
(`qforge_a2f_from_elph_impl`) — O(ns·ng) Gaussian-δ evaluations. This is the
**el-ph assembler** kernel, DISTINCT from the DFPT `n_iter`-dominant cost model
(#2706); here the cost is a dense per-(sample,bin) histogram, not an iterative solve.

## headline finding — parallelization layout is the whole lever (d6)

The M27 kernel `qforge_a2f_bzsum` parallelizes **bin-per-thread** → only `ng`
threads (64..1024). On a 188-SM Blackwell (~385k-thread capacity) that is
**0.3% occupancy** — the GPU is launch/occupancy-starved, NOT compute-bound.
A 2D **(sample-tile × bin)** kernel `qforge_a2f_bzsum2d` (atomic-add reduction
over sample tiles, ~256 samples/thread) spawns `(ns/256)·ng` threads → fills the
SMs. Same FP64 numerics, parity-checked per size (rel ≤ 1e-5, no PARITY-FAIL).

## measured wall-time (kernel-only, cuEvent; H2D < 0.3 ms, excluded)

```
size (ns×ng)     cpu_ms    gpu1d_ms   gpu2d_ms    sp_1d    sp_2d   gpu2d_GFLOP/s
1024×128          0.532      2.358      0.149      0.2×     3.6×       11.4
4096×256          4.132      9.263      0.150      0.4×    27.5×       90.7
16384×512        33.090     37.677      1.156      0.9×    28.6×       94.3
65536×512       134.666    150.666      3.468      0.9×    38.8×      125.8
131072×1024     524.337    301.282     12.655      1.7×    41.4×      137.9
262144×1024    1052.604    602.582     25.140      1.7×    41.9×      138.8
```
- cpu = single-core FP64 libm loop, -O2, pod CPU (median of 1–3).
- gpu1d/gpu2d = mean of 5–20 launches; 2D includes the per-launch `memset` zero.

## interpretation

- **1D (M27) kernel is a POOR lever**: slower than CPU below ns=131072, peaks at
  **1.7×** — exactly the thread-starvation signature (GFLOP/s rises with ng:
  0.4→5.8 as the only-`ng` threads grow). An honest negative on the naive layout.
- **2D kernel is the real lever**: **27–42× over single-core CPU** once ns ≥ 4096,
  plateauing at ~138 GFLOP/s. The plateau (not the ~80 TFLOP/s FP64 peak) reflects
  this being a **transcendental-bound** kernel — 3 exp() per inner (i,j), each the
  #1215 ~30-flop polynomial — so the roof is the SFU/exp throughput, not FMA peak.
  138 GFLOP/s at 13 flop/inner ⇒ ~10.6 G inner-deposits/s ⇒ ~3.5 G exp/s sustained.
- **Crossover**: even the 2D kernel only wins for ns·ng ≳ 10⁵ (1024×128 = 3.6×);
  below that, launch overhead dominates. For a real per-q DFPT α²F assembly
  (ns = n_k·n_q·n_mode ~ 10⁴–10⁶, ng ~ 10²–10³) the 2D kernel is firmly in the
  40× regime — a worthwhile lever for the L3 assembler step.

## codegen gap surfaced (d8 — filed)

The 2D kernel needs the 3-arg `gpu_atomic_add(base, idx, val)` form, whose NVPTX
lowering emits `%rd_idxs_addr` WITHOUT a `.reg .u64` declaration → ptxas
`Unknown symbol '%rd_idxs_addr'`. Filed to
`inbox/patches/nvptx-atomic-add-3arg-reg-decl.md`. The 2D numbers above were
measured with a 1-line reg-decl PTX patch (measurement workaround, clearly
isolated to `build_m35/k2d_patched.ptx`, NOT a shipped artifact); the kernel
SOURCE is correct and will emit clean once the codegen decl is added.
