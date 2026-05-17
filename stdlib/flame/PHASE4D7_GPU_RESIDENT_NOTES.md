# flame Phase 4-D-7 — GPU-resident A2 block primitive (design notes)

> Successor to Phase 4-D-6. The d768·12L GPU fire #5 engaged the GPU
> (435 MiB) but ran 0 steps in 600s — only matmul was GPU-routed; the A2
> block's non-matmul CPU loops dominated. Phase 4-D-7 converts the A2
> block primitive into a GPU-resident kernel sequence.
> Root cause + 4-part plan: `state/flame_phase4d6_gpu_fire_2026_05_17/
> PHASE4D6_GPU_FIRE_ANALYSIS.md` §6.

## 1. What was built

| File | Role |
|---|---|
| `tool/flame_phase4d7_block_fwd_primitive.c` | GPU-resident A2 forward primitive |
| `tool/flame_phase4d7_block_bwd_primitive.c` | GPU-resident A2 backward primitive |
| `tool/flame_phase4d7_a2_build.sh` | build wrapper (fork of `flame_phase4d6_a2_build.sh`) |
| `stdlib/flame/PHASE4D7_GPU_RESIDENT_NOTES.md` | this file |

The matmul/grad-accum primitives (`tool/flame_phase4d6_matmul_primitives.c`)
are **reused unchanged** — they already carry the Layer-2 cuBLAS dispatch.

## 2. Dimension-gated dispatch

Each block primitive is a thin wrapper that gates on the per-row width `d`
against `FLAME_GPU_RESIDENT_THRESHOLD` (default 256):

```
d ≤ threshold  → flame_block_generic_{fwd,bwd}_primitive_cpu   (CPU loop)
d  > threshold → flame_block_generic_{fwd,bwd}_primitive_gpu   (GPU-resident)
```

- **d=32·3L** (`d=32 ≤ 256`) → CPU path. The `_cpu` body is a **verbatim
  copy** of the Phase 4-D-6 primitive — no loop reordered, no literal
  changed. Byte-eq is preserved exactly.
- **d=768·12L** (`d=768 > 256`) → GPU-resident path activates.

This mirrors the matmul primitives' own `FLAME_MATMUL_GPU_THRESHOLD 8192`
small-shape carve-out: small shapes stay CPU, large shapes go to the GPU.

## 3. The 4-part transformation (per analysis §6)

### Part 1 — Persistent device residency

At GPU-path block entry, one `hexa_farr_to_device` per block-scoped farr
(`X`, `Bp` weights, `Bc` cache, `cos`, `sin`). On `HEXA_CUDA` this is a
one-shot H2D upload; the device copy stays authoritative for the rest of
the block (FARR_MIRRORED model in `self/runtime.c`). At block exit one
`hexa_farr_to_host` brings the result back (`Bc` for fwd; `dX_out` + `Bg`
for bwd). This **eliminates the `flame_proj_gpu_matmul_g` per-call
H2D/D2H/free pattern** for the non-matmul ops — they now run as a
device-side kernel sequence on already-resident buffers.

On the no-CUDA Mac build `farr_to_device`/`farr_to_host` are inert
no-op-success — the residency model is a `HEXA_CUDA`-only fast path and
never changes the no-CUDA numerics.

### Part 2 — Non-matmul ops → forge Phase B kernels

| Op | forge kernel |
|---|---|
| RMSNorm fwd (steps 1 & 7) | `hexa_farr_rmsnorm_rows_gpu` + `hexa_farr_mul_gpu` (γ broadcast) |
| RMSNorm bwd vjp (×2) | `hexa_farr_rmsnorm_bwd_rows_gpu` |
| attention softmax | per-row causal softmax (see §4) |
| SwiGLU fwd | `hexa_farr_silu_gpu` + `hexa_farr_mul_gpu` |
| SwiGLU bwd da/db | `hexa_farr_silu_grad_gpu` + `hexa_farr_silu_gpu` + `hexa_farr_mul_gpu` |
| residual add (steps 6 & 9) | `hexa_farr_add_gpu` |

All 11 forge Phase B/B2 kernels are byte-eq verified on A100 sm_80
(Phase 4-D-5-3, 11/11 PASS — `state/forge_phase4d_5_3_2026_05_17/`).

### Part 3 — Attention Q·Kᵀ / P·V → cuBLAS

Per head, the score Gram `Q·Kᵀ` and the value combine `P·V` are
matmul-shaped and route to `hexa_farr_matmul_gpu` (cuBLAS Dgemm):

- Q-block `[T·hd]`, Kᵀ `[hd·T]` → raw scores `[T·T]` via Dgemm.
- causal mask + scale applied host-side on the result.
- masked `P [T·T]` (zeros above diagonal) · V-block `[T·hd]` → ctx `[T·hd]`
  via Dgemm — the diagonal zeros make the full `T×T·T×hd` product exact.

The grad-accumulator matmuls (`dW = dYᵀ·X`) route through
`flame_grad_accum_generic_primitive`, which dispatches to cuBLAS at large
shapes. The bwd dr/dctx/drin reverse-projections route through
`flame_proj_batch_generic_primitive` (also cuBLAS at scale) by passing the
transposed weight.

### Part 4 — RoPE

**RoPE is GPU-routed** — the parallel RoPE-kernel agent landed
`_hx_cuda_farr_rope_gpu` / `_hx_cuda_farr_rope_bwd_gpu` (commit `9582a395`,
picked up in this worktree's merge). The fwd `hexa_farr_rope_gpu(t, cos,
sin, T, nheads, hd)` and bwd `hexa_farr_rope_bwd_gpu(...)` dispatchers in
`self/runtime.c` produce a `[T·nheads·hd]` farr — exactly the contiguous
Q-block (`[T·nh·hd]` at `oQ`) / K-block (`[T·nkv·hd]` at `oK`) layout the
A2 block uses. The kernel is byte-eq (F-RFC041-ROPE-EXACT |Δ|=0 — pure
per-element, no reduction). Phase 4-D-7 fwd step 3 and bwd step 3rev both
dispatch to it; a CPU fallback covers the dispatch-error path. **No
remaining hot-path CPU op for RoPE.**

## 4. GPU-resident vs remaining CPU — honest ledger

### Forward primitive

| Op | Status |
|---|---|
| RMSNorm fwd ×2 | **GPU** (forge `rmsnorm_rows` + `mul`) |
| Q/K/V/O/G/U/D projections | **GPU** (cuBLAS via matmul primitive) |
| attention Q·Kᵀ | **GPU** (cuBLAS Dgemm) |
| attention P·V | **GPU** (cuBLAS Dgemm) |
| SwiGLU silu⊙ | **GPU** (forge `silu` + `mul`) |
| residual add ×2 | **GPU** (forge `add`) |
| RoPE rotation | **GPU** (forge `rope` kernel — commit `9582a395`) |
| attention softmax | **CPU** — per-row causal-prefix softmax (the
  forge `softmax_rows` kernel softmaxes the full row; the growing-L causal
  mask needs a per-`L`-prefix reduction; this is a cheap `T`-row reduction,
  NOT the `d`-dominated work — the `d`-heavy score matmul above is GPU) |

### Backward primitive

| Op | Status |
|---|---|
| SwiGLU bwd dWd/dWg/dWu (grad_accum) | **GPU** (cuBLAS) |
| silu / silu_grad / da-db Hadamard | **GPU** (forge `silu`/`silu_grad`/`mul`) |
| ds / dr reverse-projections | **GPU** (cuBLAS via proj primitive) |
| RMSNorm bwd vjp ×2 | **GPU** (forge `rmsnorm_bwd_rows`) |
| Wo / Q / K / V proj bwd (grad_accum) | **GPU** (cuBLAS) |
| dctx / drin reverse-projections | **GPU** (cuBLAS via proj primitive) |
| RoPE bwd | **GPU** (forge `rope_bwd` kernel — commit `9582a395`) |
| **attention bwd triangle** | **CPU** — no forge masked attention-bwd
  kernel; the growing-L causal `dQ/dK/dV/dP` dependency forbids a clean
  batched Dgemm. The dominant `dW` grad-accum work IS cuBLAS; the
  score-grad triangle stays CPU. Honest carve-out, named for a follow-on. |
| Wk/Wv `drin` partial (kvd contraction) | **CPU** — small `kvd`, accumulate |

## 5. Numerical contract

- **d=32·3L** — strict byte-eq. The GPU-resident path is NOT taken
  (`d=32 ≤ 256`); the CPU body is the verbatim Phase 4-D-6 primitive.
  `F-RFC047-A2-PATHB-FULL-BYTE-EQ` holds; `verify_all` 26/26 PASS.
- **d=768·12L** — TOL_OP ≈ 1e-9, NOT strict byte-eq. The forge Phase B
  kernels are TOL_OP-verified (~1e-12 to ~1e-9, not bit-exact for
  reduction-bearing ops — PHASE4C audit §6 R1, RFC 040/041 measured
  tolerance). cuBLAS Dgemm uses a different summation order than the CPU
  `ikj` triple loop (measured rel-err up to 3e-11 at K=512). The GPU-
  resident output is `≈` the CPU reference at TOL_OP, not byte-identical.
  The init-epoch `gn2` (≈3.99029 at d768 from fire #5) is the sanity
  anchor for the next fire.

## 6. Build / verification status (this cycle, $0 Mac)

| Gate | Verdict |
|---|---|
| phase4d7 fwd/bwd standalone compile (`-DFLAME_BLOCK_*_STANDALONE`) | PASS |
| d=32·3L phase4d7 A2 build byte-eq vs `/tmp/baseline.out` | **PASS** |
| `flame_phase4b3_verify_all.sh` 26/26 | **PASS** (exit 0) |
| d=768·12L trainer `.c` no-CUDA build (`--build-only`) | **PASS** |
| d=768·12L A2 `.c` CUDA syntactic compile (`clang -c -DHEXA_CUDA`) | **PASS** |

`verify_all` is unaffected by phase4d7 because it drives a different
pipeline (`flame_phase4b3_a2_build.sh` + the Phase 4-B-3 leaf primitives);
phase4d7 only adds new `tool/flame_phase4d7_*` files.

## 7. A build-script gotcha (recorded)

The build script strips `#ifdef FLAME_BLOCK_PRIM_STANDALONE` … `#endif`
blocks via `sed '/^#ifdef .../,/^#endif/d'`. The dimension-gated dispatch
wrapper must therefore **not** use `#ifdef FLAME_BLOCK_PRIM_STANDALONE`
internally — the line-range strip would eat the dispatch body. The fix:
the GPU-path wrapper lives inside the single `#ifndef FLAME_BLOCK_PRIM_
STANDALONE` region (next to the GPU primitive); a separate trivial
CPU-only wrapper sits under `#ifdef FLAME_BLOCK_PRIM_STANDALONE` for the
standalone compile-check. (First d=32 build produced an empty dispatch
body + frozen training before this fix.)

## 8. Next — d768 GPU fire #6 (pre-approved)

Re-fire `build/flame_d768_12L_d7_a2` (built with `--cuda` on the GPU host)
on an A100/H100 — the real F-RFC046 wall measurement. Fire #5 ran 0 steps;
fire #6 measures whether the GPU-resident A2 block clears the wall. The
only remaining hot-path CPU op is the per-row causal attention softmax
(a `T`-row reduction, not `d`-dominated); RoPE is now GPU-routed via the
forge `rope`/`rope_bwd` kernels.
