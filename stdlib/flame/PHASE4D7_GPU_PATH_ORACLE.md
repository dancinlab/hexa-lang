# flame Phase 4-D-7 — d768 GPU-path byte-eq oracle

> The d=32 config has a byte-eq oracle (`tool/flame_phase4b3_verify_all.sh`).
> The **d768 GPU-resident path had none** — RFC 057 §6.1 and the RFC 058
> transpose-scatter kernel went in unverified, and the regression was caught
> only at the **13th paid d768 GPU fire** (`gn2` 3.99026 → 3.98438 → -nan).
> This oracle is the cheap byte-eq gate that fills that gap.

## Why a paid d768 fire was the only check

The d768·12L trainer runs the GPU-resident A2 block on a forge substrate.
The projection primitive `flame_proj_batch_generic_primitive`
(`tool/flame_phase4d6_matmul_primitives.c`) dim-gates: when
`M·K = d_out·d_in > FLAME_MATMUL_GPU_THRESHOLD` (8192) it takes the GPU
branch — cuBLAS Dgemm + (RFC 058) the transpose-scatter kernel. At d768
every projection (`d_out·d_in = 768·768 = 589 824`) crosses the gate; at
d=32 (`32·32 = 1024 < 8192`) none do. So `verify_all`, which only drives
d=32, **never exercises the GPU branch at all** — a structural blind spot.

## The idea — a mid-size config on the SAME code path

Pick a config that is

- **small enough** to compute a CPU reference on a Mac / in CI, and
- **large enough** that the GPU dim-gate triggers — so it runs the
  **identical** GPU-path code as d768.

`flame_proj_batch_generic_primitive` is dimension-generic (RFC 047): the
only thing that changes between d=96 and d=768 is loop-bound *values*, not
code structure. So a d=96 GPU run exercises byte-for-byte the same
`flame_proj_gpu_matmul_g_ex` → cuBLAS Dgemm → transpose-scatter path.

### Config chosen — `d_out = d_in = 96`, `T = 16`

| quantity | value | note |
|---|---|---|
| matmul dispatch shape `M·K` | `96·96 = 9216` | `> 8192` → **GPU gate fires** |
| W buffer | `96·96·8 B = 73 KiB` | trivially cheap on any GPU |
| CPU reference cost | a `96·96·16` triple loop | sub-millisecond on a Mac |

9216 is the smallest round `d²` above the 8192 threshold — minimal GPU work
while still on the GPU path. Contrast the d768 fire: ~10 GB resident, 600 s.

## How the byte-compare works

```
CPU reference  oracle_proj_ref()  — flame_proj_inline_matmul_g's ikj triple
                 loop + host transpose scatter. This is the verified-good
                 algorithm AND, post-rfc058-rollback, exactly what the d768
                 path now runs. Correct-by-construction baseline.
GPU candidate  flame_proj_batch_generic_primitive() built -DHEXA_CUDA —
                 cuBLAS Dgemm (+ the transpose-scatter kernel once revived).
verdict        max|Δ| over every Y element:
                 == 0.0           → STRICT byte-eq          PASS
                 ≤ TOL_OP 3e-11   → cuBLAS reorder band     PASS
                 >  TOL_OP        → GPU-path REGRESSION      FAIL  (fire #13)
                 any NaN/Inf      → -nan signature          FAIL  (fire #14)
```

`TOL_OP = 3e-11` is the `PHASE4D7_GPU_RESIDENT_NOTES.md` §5 numerical
contract: cuBLAS Dgemm sums in a different order than the CPU `ikj` loop
(measured rel-err up to 3e-11 at K=512), so the GPU projection is `≈` the
reference, not bit-identical. The fire #13 regression (`gn2` 3.98438, a
~6e-3 drift) and the fire #14 NaN both blow past this band immediately —
the oracle would have caught both **before** the paid fire.

## Files

| file | role |
|---|---|
| `tool/flame_phase4d7_gpu_path_oracle.c` | harness — farr shim, CUDA bridge shims, CPU reference, `main()` |
| `tool/flame_phase4d7_gpu_path_oracle.sh` | build + run (no-CUDA / `--cuda`) |
| `stdlib/flame/PHASE4D7_GPU_PATH_ORACLE.md` | this doc |

The harness **splices the real** `tool/flame_phase4d6_matmul_primitives.c`
(the code the d768 trainer compiles) at a marker line — no fork, no copy.
It tests the genuine primitive.

## How to run

### no-CUDA — $0, Mac / CI (harness self-check)

```
tool/flame_phase4d7_gpu_path_oracle.sh
```

`HEXA_CUDA` is undefined → `flame_proj_batch_generic_primitive` runs its
CPU inline path; the harness byte-compares CPU-primitive vs CPU-reference.
Must print `max|Δ| = 0.000e+00` / `PASS F-RFC058-GPU-PATH-ORACLE`. This
proves the harness wiring + the reference. **Status: PASS (verified, $0).**

### `--cuda` on a no-CUDA Mac — syntactic compile-check ($0)

```
tool/flame_phase4d7_gpu_path_oracle.sh --cuda
```

No `nvcc` → the GPU branch is compiled `clang -c -DHEXA_CUDA` only —
proves it builds. **Status: SYNTACTIC-PASS (verified, $0).**

### `--cuda` on a GPU host — the CHEAP fire (the d768-fire replacement)

```
tool/flame_phase4d7_gpu_path_oracle.sh --cuda
```

With `nvcc` present the `.sh` compiles
`oracle_assembled.c + self/cuda/runtime_cuda.c -lcublas` and **runs** it.
This is the byte-eq gate for GPU-path changes. Compute is sub-second —
$-cents on any spot GPU, **not** the 600 s / ~10 GB d768 fire. Expect
`max|Δ| ≤ 3e-11` / `PASS`. A `FAIL` means a GPU-path regression — fix it
*before* spending a d768 fire.

## Scope — honest (g3)

**Fully implemented:** the CPU-reference half, the harness, the no-CUDA
self-check, and the `--cuda` GPU-compare code path — all verified to
build/run at $0 on Mac (no-CUDA PASS + `--cuda` syntactic PASS).

**Needs a GPU (cheap):** the `--cuda` *numeric* run is the one step that
genuinely requires a GPU. That run is a sub-second / $-cents fire — handed
to the parent. It is NOT the expensive d768 fire; it is the new cheap gate
that *replaces* using a d768 fire as the verification mechanism.

## Reviving the transpose-scatter kernel

The RFC 058 transpose-scatter kernel call is currently rolled back
(`tool/flame_phase4d6_matmul_primitives.c`, `did_dev_scatter` forced 0 →
host loop always runs; kernel/wrapper/dispatcher kept as dead code). Once
this oracle's `--cuda` numeric run is green, the kernel can be revived by
re-enabling the `if (mm_c_id >= 0)` scatter block — and the oracle will
byte-eq-verify the revival **cheaply, before any d768 fire.**
