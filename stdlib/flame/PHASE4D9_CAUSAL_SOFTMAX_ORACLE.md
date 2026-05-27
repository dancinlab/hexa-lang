# flame Phase 4-D-9 — causal-softmax byte-eq oracle (§4 gap #1)

> `PHASE4D9_DEVICE_CHAIN_DESIGN.md` §4 names two real gaps. Gap #1: the
> attention block needs a per-row **causal-prefix** softmax, but the only
> forge softmax kernel (`_hx_cuda_farr_softmax_rows_gpu`) softmaxes the
> **full** row — so the causal mask is a host loop, blocking the
> device-resident fwd chain. This is the verified building block that
> closes gap #1 + its leaf oracle. It is **NOT wired** into the
> trainer/primitives (that is the later dev_view-chain link).

## The new kernel — the 14th (additive)

`self/cuda/runtime_cuda.c`, **purely additive** (the 12 verified kernels
+ the RFC 058 13th transpose-scatter + every existing wrapper are
byte-identical; `git diff --stat` = insertions only):

- `__device__ _hx_dt_exp_dev` — a verbatim port of `flame_g7_dt_exp`
  (`tool/flame_phase4d7_block_fwd_primitive.c:78-85`): range-halve while
  `|xr| > 0.25` (count `r`), 12-term Taylor (`k=1..11`), square back `r`
  times. Same constants, same loop bounds, same order.
- `__global__ _hx_cuda_kern_causal_softmax_rows` — one block per row `i`,
  causal prefix `L = i+1`: `m_max` over `[0,L)` via the deterministic
  `_hx_block_max` tree; `e_j = _hx_dt_exp_dev(X[i*T+j]-m_max)` for `j<L`
  and `0.0` for `j≥L`; prefix sum `tot` via `_hx_block_sum`; **divide**
  `Y[i*T+j] /= tot` (the CPU reference divides — multiply-by-reciprocal
  would add an avoidable ULP gap).
- `int _hx_cuda_farr_causal_softmax_rows_gpu(x_id, R, T, out_id)` — host
  wrapper mirroring `_hx_cuda_farr_softmax_rows_gpu` exactly (validate →
  `_h2d` → `_ensure_dev_alloc_out(R*T)` → launch →
  `cudaDeviceSynchronize`/`cudaGetLastError` → `_d2h_out(R*T)`).

## The byte-eq trap

The flame attention softmax uses `flame_g7_dt_exp` — a deterministic
polynomial exp, **NOT libm exp()**. A kernel using libm/CUDA `exp()`
would differ from the CPU reference by the **exp-algorithm error**, not
just the reduction reorder, so it would NOT be byte-eq. Both the kernel
(`_hx_dt_exp_dev`) and this oracle's CPU reference use the **identical**
`flame_g7_dt_exp`. The residual contract is therefore ONLY the per-row
reduction reorder (deterministic block tree vs sequential scan) — TOL
`1e-12`, the same Phase B reduction band as `rmsnorm_rows` /
`softmax_rows`.

## Files

| file | role |
|---|---|
| `tool/flame_phase4d9_causal_softmax_oracle.c` | harness — farr shim, CPU reference, CUDA bridge, `main()` |
| `tool/flame_phase4d9_causal_softmax_oracle.sh` | build + run (no-CUDA / `--cuda`) |
| `stdlib/flame/PHASE4D9_CAUSAL_SOFTMAX_ORACLE.md` | this doc |

## How to run

### no-CUDA — $0, Mac / CI (harness self-check)

```
bash tool/flame_phase4d9_causal_softmax_oracle.sh
```

`HEXA_CUDA` undefined → the candidate is an independent CPU evaluation of
the same causal-prefix contract; the harness byte-compares it vs the CPU
reference. Must print `max|Δ| = 0.000e+00` / `PASS`. Proves the harness
wiring + the reference.

### `--cuda` on a no-CUDA Mac — syntactic compile-check ($0)

```
bash tool/flame_phase4d9_causal_softmax_oracle.sh --cuda
```

No `nvcc` → the GPU branch is compiled `clang -c -DHEXA_CUDA` only —
proves it builds. `SYNTACTIC-PASS`.

### `--cuda` on a GPU host — the cheap fire

```
bash tool/flame_phase4d9_causal_softmax_oracle.sh --cuda
```

With `nvcc` the `.sh` compiles `oracle.c + self/cuda/runtime_cuda.c
-lcublas` and **runs** it: the real kernel vs the CPU reference. Expect
`max|Δ| ≤ 1e-12` / `PASS`. Sub-second / $-cents — NOT the 600 s d768
fire. A `FAIL` means the kernel does not match the flame causal-softmax
reference — fix it before any d768 fire.

## Scope — honest (g3)

**Fully implemented + verified $0 on Mac:** the kernel + device-exp port
+ wrapper (strictly additive — `git diff` insertion-only), the CPU
reference, the harness, the no-CUDA PASS, the `--cuda` syntactic PASS.
**Needs a GPU (cheap):** the `--cuda` numeric run — handed to the parent.
**NOT done (out of scope, by design):** wiring this kernel into the
attention primitive / trainer — that is the dev_view-chain dataflow
conversion (`PHASE4D9_DEVICE_CHAIN_DESIGN.md` §3). This kernel alone
moves no wall; it is one verified building block of the all-or-nothing
fwd+bwd device chain.
