# flame Phase 4-D-9 — WHOLE-BLOCK fwd GPU-path byte-eq oracle

> The d7 oracle (`tool/flame_phase4d7_gpu_path_oracle.{c,sh}`) byte-eq
> verifies exactly **one** primitive — `flame_proj_batch_generic_
> primitive`. The Phase 4-D-9 device-chain conversion
> (`PHASE4D9_DEVICE_CHAIN_DESIGN.md`) rewrites the **entire**
> `flame_block_generic_fwd_primitive_gpu` (RMSNorm · RoPE · attention ·
> SwiGLU · residual). Without a cheap **block-level** byte-eq oracle that
> rewrite is verifiable only by the wasteful **600 s / $0.17 d768·12L
> fire** — the trap that burned 15 fires and completed 0 steps. This is
> that cheap gate, at block scope.

## Why a paid d768 fire was the only block-level check

`tool/flame_phase4d7_block_fwd_primitive.c` dim-gates at
`d > FLAME_GPU_RESIDENT_THRESHOLD` (256, line 1016): `d ≤ 256`
takes the byte-eq `_cpu` loop body; `d > 256` takes
`flame_block_generic_fwd_primitive_gpu` — the GPU-resident chain (forge
Phase B kernels + cuBLAS). `tool/flame_phase4b3_verify_all.sh` only
drives `d = 32`, so it **never exercises the `_gpu` block body at all** —
the same structural blind spot the d7 doc identifies for the projection,
now at whole-block scope. The d7 oracle plugged it for one primitive; the
device-chain conversion touches all 9 fwd steps, so the gate must be at
block scope or the conversion is unverifiable below a d768 fire.

## The idea — a mid-size config on the SAME `_gpu` code path

Pick a config that is **small enough** for a CPU reference on a Mac, yet
**large enough** that the block dim-gate AND every cuBLAS gate trigger —
so it runs the **identical** `_gpu` code as d768 (the primitive is
dimension-generic, RFC 047: only loop-bound *values* change between d=384
and d=768, never the code structure).

### Config chosen — `d=384, nh=6, nkv=2, h=512, T=16`

| quantity | value | gate |
|---|---|---|
| block dim-gate `d` | `384` | `> FLAME_GPU_RESIDENT_THRESHOLD (256)` → **`_gpu` chain** |
| Q / O proj `d_out·d_in` | `384·384 = 147 456` | `> FLAME_MATMUL_GPU_THRESHOLD (8192)` → **cuBLAS** |
| K / V proj `d_out·d_in` | `128·384 = 49 152` | `> 8192` → cuBLAS |
| G / U proj `d_out·d_in` | `512·384 = 196 608` | `> 8192` → cuBLAS |
| D proj `d_out·d_in` | `384·512 = 196 608` | `> 8192` → cuBLAS |
| `hd = d/nh` | `64` | integer-clean (no truncation) |
| `half = hd/2` | `32` | integer-clean |
| `n_rep = nh/nkv` | `3` | integer-clean |
| `kvd = nkv·(d/nh)` | `128` | integer-clean |
| largest buffer `Bp` | `≈ 4.1 MB` (983 808 doubles) | trivially cheap on any GPU |

**Why this config and not another:** `d=384` is the smallest multiple of
`nh·2` (so `hd` and `half` stay integer) that clears the 256 block gate
with margin, while keeping `d²` (147 456) far above the 8192 cuBLAS gate
— so EVERY projection takes the same cuBLAS Dgemm path as d768, not just
some. `nh=6, nkv=2` exercises GQA (`n_rep=3`, K/V projected at the
reduced `kvd=128` width — the real d768 GQA shape, not MHA). `h=512 > d`
makes the SwiGLU `WD` projection contract from `h` to `d` (the d768 FFN
shape). `T=16` keeps the per-row causal attention loop (`L=i+1`) and the
forward sub-millisecond on a Mac — contrast the d768 fire: ~10 GB
resident, 600 s. Every offset formula
(`tool/flame_phase4d7_block_fwd_primitive.c` L119-139) is integer-exact
at this config — no silent truncation that would make the reference
diverge from the candidate for a non-numerical reason.

## How the byte-compare works

```
CPU reference  flame_block_generic_fwd_primitive_cpu — called DIRECTLY at
                 the config (bypassing the dim-gate). This is the
                 verified-good byte-eq algorithm: the d=32·3L
                 F-RFC047-A2-PATHB-FULL-BYTE-EQ body, spliced verbatim
                 from tool/flame_phase4d7_block_fwd_primitive.c, NO loop
                 reordered. Correct-by-construction baseline.
GPU candidate  under -DHEXA_CUDA: flame_block_generic_fwd_primitive_gpu —
                 the GPU-resident chain (forge rmsnorm/softmax/silu/mul/
                 add kernels + cuBLAS Dgemm projections + the RoPE
                 kernel). On a no-CUDA Mac the candidate is the _cpu body
                 (see "no-CUDA mode" below).
compared       the block OUTPUT + the key cache fields over their VALID
                 ranges (Bc offsets, block primitive L124-139):
                   oXout    T·d        block output (step 9 residual)
                   oHstate  T·d        mid-block residual (step 6)
                   oRin     T·d        RMSNorm-1 → γ output (step 1)
                   oQ       T·nh·hd    RoPE-rotated Q (step 3)
                   oP       Σ(i+1) per head — the CAUSAL region only
                            (cells j>i stay 0 both sides; we report the
                            j≤i max explicitly per (head,row))
                   oSwS     T·h        SwiGLU silu⊙ output (step 8)
                 max|Δ| = max over ALL compared elements.
verdict        max|Δ| == 0.0          → STRICT byte-eq            PASS
                 max|Δ| ≤ TOL_BLOCK     → Phase-B+cuBLAS band       PASS
                 max|Δ| >  TOL_BLOCK    → block GPU-path REGRESSION FAIL
                 any NaN/Inf            → the fire #14 -nan sig     FAIL
```

### TOL_BLOCK = 1e-8 — justified from the per-op numerical contract

This is **derived, not chosen for convenience** (g3, anti
fit-to-convenient-number):

- Each forge Phase B **reduction** kernel (rmsnorm_rows / softmax_rows)
  is reduction-reorder bounded at **~1e-12** — the measured Phase B band
  (`PHASE4D7_GPU_PATH_ORACLE.md`, the causal-softmax oracle's TOL, RFC
  040/041 measured; also the d9 causal-softmax oracle uses TOL 1e-12).
- Each **cuBLAS Dgemm** projection sums in a different order than the CPU
  `ikj` loop, measured rel-err up to **~3e-11** at K=512
  (`PHASE4D7_GPU_PATH_ORACLE.md` §5 — the d7 single-projection oracle's
  TOL_OP). This block has 7 projections + per-head Q·Kᵀ + P·V.
- The forward block **chains ~12 such ops** (2 RMSNorm, 7 projections,
  per-head score matmul + softmax + value matmul, 2 residual adds, the
  SwiGLU silu⊙). Errors propagate roughly **additively** through the
  residual stream (each residual `+` carries the prior error forward, it
  is not re-normalised away).
- `PHASE4D9_DEVICE_CHAIN_DESIGN.md` §5 states the measured **end-to-end**
  block bound is **~1e-9** ("forge Phase B kernels are TOL_OP-verified
  ~1e-12, the d=768 numerical contract is TOL_OP ≈ 1e-9").

`TOL_BLOCK = 1e-8` is **one order ABOVE the measured ~1e-9 end-to-end
bound** — tight enough that the historical failures blow straight through
it (fire #13 `gn2` drift ≈ **6e-3**; fire #14 **NaN**), so it cannot mask
a real regression, yet not so tight that the legitimate ~1e-9 Phase-B +
cuBLAS reorder trips a false FAIL. It is NOT inflated to hide error: the
gap between the band ceiling (~1e-9) and the smallest historical failure
(~6e-3) is **six orders of magnitude**, so a 10× headroom over the band
is conservative, not permissive.

## Files

| file | role |
|---|---|
| `tool/flame_phase4d9_block_fwd_oracle.c` | harness — farr-table shim, full forge surface shims, CPU/GPU compare `main()` |
| `tool/flame_phase4d9_block_fwd_oracle.sh` | build + run (no-CUDA / `--cuda`); splices the two real primitives |
| `stdlib/flame/PHASE4D9_BLOCK_FWD_ORACLE.md` | this doc |

The harness **splices the two REAL primitives** (no fork, no copy):
`tool/flame_phase4d6_matmul_primitives.c` then
`tool/flame_phase4d7_block_fwd_primitive.c`, in that order — the SAME
order the trainer's `tool/flame_phase4d7_a2_build.sh:132` concats them
(`cat PRIM_MATMUL PRIM_FWD`), so the block fwd sees
`flame_proj_batch_generic_primitive` in scope. `FLAME_BLOCK_PRIM_
STANDALONE` is **not** defined (matching the trainer build, which concats
after `#include "runtime.c"`), so the `#ifndef FLAME_BLOCK_PRIM_
STANDALONE` region — the `_gpu` body **and** the dim-gated dispatch — is
kept; the trivial `#ifdef FLAME_BLOCK_PRIM_STANDALONE` wrapper compiles
out naturally. The harness supplies the farr-table + the runtime.c forge
surface shims (`hexa_farr_{to_device,to_host,pin_device,unpin_device,
dev_view,set_out_disposition,rmsnorm_rows_gpu,softmax_rows_gpu,silu_gpu,
mul_gpu,add_gpu,matmul_gpu,rope_gpu,transpose_scatter_gpu}`), bodies
byte-for-byte the runtime.c wrapper logic, every `_hx_cuda_*` extern
declared inside `#ifdef __cplusplus extern "C" {` — the C-linkage
contract (a `--cuda` link error already cost exactly this bug 2026-05-18;
the no-CUDA + clang-syntactic checks structurally cannot catch it).

## How to run

### no-CUDA — $0, Mac / CI (harness self-check)

```
tool/flame_phase4d9_block_fwd_oracle.sh
```

`HEXA_CUDA` undefined → the candidate is
`flame_block_generic_fwd_primitive_cpu`, the reference is the same `_cpu`
function → **same function both sides** → `max|Δ| = 0.000e+00` / `PASS`,
STRICT. This proves the harness wiring (splice order, farr-table, offset
math, the compare ranges) + the reference. **Status: PASS (verified, $0).**

> Why the no-CUDA candidate is `_cpu`, not `_gpu`: the forge no-CUDA
> helpers (`runtime.c` `_hx_farr_*_cpu`) use **libm** `exp`/`sqrt`,
> whereas the `_cpu` block body uses the **deterministic flame_g7**
> polynomials (`flame_g7_dt_exp`/`flame_g7_dt_sqrt`/`flame_g7_db_silu`).
> A no-CUDA `_gpu` run would therefore measure the **exp/sqrt-ALGORITHM
> gap**, not the reduction reorder this oracle is built to bound — it
> would never reach `max|Δ|=0.0` for a non-bug reason. So no-CUDA is
> CPU-vs-CPU (exact, the $0 wiring gate) and the `_gpu` numeric compare
> is the `--cuda` GPU run. This is exactly the d7 oracle's contract (its
> no-CUDA candidate is the primitive's own CPU inline path), generalised
> from a `#ifdef HEXA_CUDA` internal gate to a dimensional one.

### `--cuda` on a no-CUDA Mac — syntactic compile-check ($0)

```
tool/flame_phase4d9_block_fwd_oracle.sh --cuda
```

No `nvcc` → the assembled TU is compiled **twice**: `clang -c -DHEXA_CUDA`
(C parse) **and** `clang++ -x c++ -std=c++14 -c -DHEXA_CUDA` (C++ parse).
The C++ parse is the real value: `nvcc -x cu` always parses as C++, so
the C++ compile is the **only $0 check that exercises the `extern "C"`
linkage contract** — a missing guard would emit a mangled `_hx_cuda_*`
call site, which the C parse cannot catch. Both must compile clean.
**Status: SYNTACTIC-PASS (verified, $0 — C and C++/nvcc-front-end).**

### `--cuda` on a GPU host — the CHEAP block-level fire (PARENT's job)

```
tool/flame_phase4d9_block_fwd_oracle.sh --cuda
```

With `nvcc` present the `.sh` compiles `oracle_assembled.c +
self/cuda/runtime_cuda.c -lcublas` and **runs** it. The candidate is the
real `flame_block_generic_fwd_primitive_gpu` (forge Phase B kernels +
cuBLAS). Compute is sub-second — $-cents on any spot GPU, **not** the
600 s / ~10 GB d768 fire. Expect `max|Δ| ≤ 1e-8` / `PASS`. A `FAIL` means
the block GPU path regressed — fix it *before* spending a d768 fire. This
run is the one deliverable that genuinely needs a GPU and is handed to
the parent (the sub-agent has no nvcc).

## Scope — honest (g3)

**Fully implemented + verified at $0 on Mac:** the CPU-reference half
(= the verified-good `_cpu` block body, spliced unmodified), the harness
(farr-table + full forge surface shims + offset math + multi-field
compare), the no-CUDA self-check (CPU-vs-CPU, `max|Δ|=0.0` STRICT), and
the `-DHEXA_CUDA` GPU-candidate code path (compiles clean in both the C
and the C++/nvcc-front-end parses).

**Needs a GPU (cheap, parent's job):** the `--cuda` *numeric* run is the
one step that genuinely requires a GPU — a sub-second / $-cents fire,
**not** the expensive d768 fire; it is the new cheap **block-level** gate
that *replaces* using a d768 fire to verify the fwd device-chain
conversion.

**This is the verification INSTRUMENT only.** It does NOT itself convert
the block to a dev_view chain (that is the next link —
`PHASE4D9_DEVICE_CHAIN_DESIGN.md` §3). Building the instrument before the
change is the campaign's proven methodology (the d7 oracle precedent),
not design-first.
