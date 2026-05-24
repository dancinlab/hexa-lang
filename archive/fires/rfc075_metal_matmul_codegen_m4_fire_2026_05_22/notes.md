# RFC 075 P3++ — codegen-emitted Metal matmul silicon fire (Apple M4, mini)

Date: 2026-05-22 · Host: **mini** (Apple M4, 10-core GPU, macOS 26.5 / 25F71,
Apple metal version 32023.883). Plain `ssh mini` (no SIDECAR_NO_POOL).

## Goal

N161 (`3858f188`) wired `_metal_emit_matmul_body` (Apple `simdgroup_matrix` MMA)
into `codegen_emit_metal_msl`. lower_test Case 16 confirmed the emitted MSL
*string* contains `simdgroup_float8x8` / `simdgroup_multiply_accumulate` /
`simdgroup_store` + K-loop. This cycle: take the **codegen-EMITTED MSL** (not a
hand-written kernel) → compile via `xcrun metal` → fire on M4 → numeric-eq vs CPU
FP32 ref. Second-vendor source-to-silicon matmul attempt (Nvidia NVPTX matmul was
codegen+silicon-validated in the GPU.md mega-cycle; Metal is the open vendor).

## Path

Path A (per task preference, N51 precedent): mechanically reconstructed the
verbatim output of `_metal_emit_matmul_body(false,false)` + the preamble +
`_metal_emit_matmul_kernel_signature("matmul_kernel")` from the emit-fn bodies in
`compiler/codegen/metal_target.hexa` (lines 354-357, 808-870). No self-host
compile needed. The reconstruction is `matmul_codegen.metal` (byte-faithful to
what the codegen emits — traced constant-by-constant: METAL_MM_FRAG_TYPE=
`simdgroup_float8x8`, METAL_MM_MAKE_ZERO=`make_filled_simdgroup_matrix`,
METAL_MM_TG_DIM=32, METAL_MM_FRAG_DIM=8, METAL_MM_LOAD/MAD/STORE).

## Result 1 — VERBATIM codegen MSL does NOT compile (codegen bug)

```
matmul_codegen.metal:15:62: error: unexpected type name 'simdgroup_float8x8':
expected expression
    simdgroup_float8x8 c_frag = make_filled_simdgroup_matrix(simdgroup_float8x8, 0.0f);
```

### Codegen bug (precise, à la N122 NVPTX)

`metal_target.hexa:851-852`, inside `_metal_emit_matmul_body`:

```hexa
out = out + "    " + METAL_MM_FRAG_TYPE + " c_frag = "
out = out + METAL_MM_MAKE_ZERO + "(" + METAL_MM_FRAG_TYPE + ", 0.0f);  ..."
```

emits

```cpp
simdgroup_float8x8 c_frag = make_filled_simdgroup_matrix(simdgroup_float8x8, 0.0f);
```

Apple's `make_filled_simdgroup_matrix` takes the matrix element type + dims as
**template parameters**, not a runtime first argument. The fix is one token:

```cpp
simdgroup_float8x8 c_frag = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
```

This is a single-call emit bug: the codegen reuses `METAL_MM_FRAG_TYPE` (the
typedef name `simdgroup_float8x8`) as if it were a value-position fill argument.
`simdgroup_float8x8` IS a valid typedef (pulled in by `metal_stdlib`, no extra
include needed), but a TYPE cannot appear as a function call's first expression.

A correct emit would either spell the template form
`make_filled_simdgroup_matrix<float, 8, 8>(0.0f)` or use the value-only overload
`simdgroup_float8x8(0.0f)`.

### What is NOT a compile bug (verified)

- The codegen preamble omits `#include <metal_simdgroup_matrix>`. NOT needed —
  `metal_stdlib` + `using namespace metal;` already provides the simdgroup MMA
  API on this toolchain. Compile of the patched variant proves this.
- `simdgroup_load(frag, ptr, stride, 0, false)` with scalar `0` origin + `false`
  transpose — COMPILES (Apple has a scalar-origin overload). No bug.
- `simdgroup_store(frag, ptr, stride)` — COMPILES. No bug.
- 6-arg signature (`device const float*` a/b + `device float*` c + 3×
  `constant uint&` + `uint2 tg [[threadgroup_position_in_grid]]`) — COMPILES.

So there is exactly **ONE** codegen compile bug. With the single token patched
(`matmul_codegen_fixed.metal`), the codegen output compiles cleanly →
`matmul_codegen_fixed.air` → `matmul_codegen_fixed.metallib`, and produces a
**valid MTLComputePipelineState** (`VALID_PIPELINE matmul_kernel tew=32 max=1024`).

## Result 2 — F-RFC075-METAL-MATMUL-CODEGEN-M4-NUMERIC-EQ: **PASS**

With the 1-token patch, the codegen MMA math is numerically exact on M4 silicon:

| shape | covered sub-blocks | covered max_rel_err | median_ms |
|-------|--------------------|---------------------|-----------|
| 256³  | 4096 / 4096        | 2.58e-7             | 0.0195    |
| 512³  | 16384 / 16384      | 2.55e-7             | 0.0518    |

`rel_err ≈ 2.6e-7` (FP32 round-off level) << TOL 1e-3. The
`simdgroup_load`/`simdgroup_multiply_accumulate`/`simdgroup_store` K-loop the
codegen emits computes correct `c = a·b` on every 8×8 fragment it touches.

## Result 3 — codegen TILING-COVERAGE gap (logic, not compile)

`full_tile_max_rel_err = 1.0`, `nonzero_outside_covered = 0`,
`zero_inside_missing = 0`.

The codegen body has a structural gap independent of the compile bug: it computes
exactly **one 8×8 fragment per threadgroup** at tile origin `(tg.y*32, tg.x*32)`,
with no sub-tile loop and no threadgroup memory. Since `METAL_MM_TG_DIM = 32` but
`METAL_MM_FRAG_DIM = 8`, each 32×32 tile only gets its top-left 8×8 corner filled
— the other **56 of 64** 8×8 sub-tiles are left at zero. The `simdgroup_load`
origin argument is hardcoded `0` (no per-fragment offset), and `kk` only walks the
K axis, never the M/N sub-tile axes.

This is the SAME shape of gap the NVPTX matmul codegen had at its first-tier
emit: a register-level single-fragment body, correct per-fragment math, but no
multi-fragment tiling. To fill a full 32×32 tile the emit would need a 4×4
sub-tile loop over `(sub_m, sub_n)` with `simdgroup_load` origins
`(sub_m*8, kk)` / `(kk, sub_n*8)` and 16 accumulators — i.e. roughly what the
N138 hand-emit does (4×4 sub-tiles per 32×32 band).

We dispatch one 32-thread threadgroup per 32-aligned origin (`groups =
(N/32, M/32)`) and verify the COVERED corners; they are exact. The gap is
reported, not masked.

## GFLOPS — codegen vs hand-emit (honest)

- **N133 baseline** (hand-emit 64×64_tg_db, full-tile): 1858.35 GFLOPS @ 1024³
- **N138 hand-emit** (4-simdgroup 64×64, full-tile): 2109 GFLOPS @ M=1536
- **This codegen** (1 fragment/TG, FP32):
  - `covered_gflops` (only the work it actually does): **108 @ 256³, 324 @ 512³**
  - `full_walltime_gflops` (full-MxN flops / its wall-time, NOT apples-to-apples
    since 56/64 of the tile is skipped): 1721 @ 256³, 5183 @ 512³

The codegen is **NOT** comparable to the hand-emit on real throughput: its
`covered_gflops` (108–324) is the honest figure for useful work, ~6–17× below the
N133/N138 hand-emit. The inflated `full_walltime_gflops` only looks competitive
because the kernel skips 87.5% of the arithmetic. **Codegen quality gap: large**,
driven by the tiling gap (single fragment) + FP32 inputs (hand-emit uses FP16
inputs / FP32 accum for ~2× the MMA throughput). Both gaps are first-tier-emit
expected, mirroring the NVPTX matmul codegen timeline.

## Codegen vs original task spec (FP16)

The task brief said "FP16 a/b + FP32 c". The codegen actually emits
`device const float*` for a and b — i.e. **FP32 inputs**. This fire used FP32
inputs to stay faithful to what the codegen emits (testing the codegen, not a
hand-tuned kernel). An FP16-input matmul emit is a separate codegen feature the
N161 body does not produce today.

## Closure status

**Metal source-to-silicon matmul: NOT yet CLOSED, but very close.**

- Codegen-emitted MSL compiles? **NO** — one precise compile bug
  (`make_filled_simdgroup_matrix(simdgroup_float8x8, 0.0f)` must be
  `<float,8,8>(0.0f)`).
- With that ONE token fixed: compiles cleanly + valid pipeline + numerically
  exact (`rel_err 2.6e-7`) on Apple M4. So the MMA emit is structurally and
  numerically sound — the closure blocker is a 1-line emit fix in
  `metal_target.hexa:852`, NOT a fundamental design problem.
- Secondary gap (not a closure blocker for "compiles+runs+matches", but a quality
  gap): single-fragment tiling fills only 8×8 of each 32×32 tile, and FP32 (not
  FP16) inputs. Codegen perf ~6–17× below hand-emit on useful work.

Two follow-up codegen fixes (both in `metal_target.hexa`, both forbidden to touch
this cycle): (1) the `make_filled_simdgroup_matrix` template-arg fix; (2) the
32×32 sub-tile loop in `_metal_emit_matmul_body`.

## Artifacts

- `matmul_codegen.metal` — VERBATIM codegen output (fails to compile; line 15 bug)
- `matmul_codegen_fixed.metal` — same, 1-token compile-bug patch only
- `matmul_codegen_fixed.air` / `.metallib` — compiled on M4
- `host_matmul.swift` — Swift MTLComputePipelineState driver (FP32, LCG, CPU ref)
- `measure.sh` — compile-verbatim(expect-fail) → compile-patched → build+run host
- `fire.log` — full mini run (DIM 256 + 512)
- `result.json` (last = 512), `result_256.json`, `result_512.json`

## Constraints honored

- Plain `ssh mini`, no SIDECAR_NO_POOL.
- DID NOT touch compiler source (`metal_target.hexa`) or GPU.md. The patched
  `.metal` lives only in this fire dir; the bug is documented for a follow-up
  source fix.
