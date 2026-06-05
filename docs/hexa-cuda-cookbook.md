# Writing CUDA-style GPU kernels directly in hexa — a cookbook

> Hand-author a GPU kernel in a `.hexa` file with the `@gpu_kernel` attribute,
> and the compiler routes it to the NVPTX target (hexa → PTX → `ptxas` → cubin).
> This is the **"just write CUDA in hexa"** path: you control the thread
> indexing, the shared memory, the barriers — exactly like a CUDA `__global__`.
>
> This cookbook is grounded in the **real** intrinsic and launch surface the
> compiler supports today. Where an intrinsic does not yet exist, or the
> end-to-end build is gated, that is marked honestly — no invented syntax.

**Authoritative sources** (read these if you want the contract, not just the
recipes):

- `gpu/SPEC.md` — the `@gpu` subset SSOT (attributes, type allowlist, intrinsics,
  shared-memory model, host launch ABI, `GPU0N` strict-lint codes).
- `compiler/codegen/nvptx_target.hexa` — the RFC 055 hexa→PTX codegen; the
  op-table there is the ground truth for *which* intrinsics actually lower.
- `stdlib/qforge/nvptx_*_kernel.hexa` — six real hand-authored reference kernels.

---

## 1. When to use this path (vs auto-fusion flame/forge)

hexa has **two** ways to get work onto a GPU. Pick the right one:

| | Hand-authored `@gpu_kernel` (this cookbook) | Auto-fusion (flame / forge) |
|---|---|---|
| **You write** | the kernel body — thread index, shared mem, barriers | a high-level tensor/array program |
| **Who decides the kernel** | you | the fusion compiler (picks tiling, fuses ops, emits the kernel for you) |
| **Control** | total — exact PTX shape, custom data layout, novel algorithm | the fuser's heuristics; you steer with annotations |
| **Best for** | a *specific* kernel you understand better than a generic fuser: a bespoke reduction, a stencil, a matrix-free operator, a custom el-ph BZ sum | standard tensor pipelines (GEMM chains, norm+activation, attention) where the fuser's tiling is already good |
| **Effort** | higher — you own correctness and occupancy | lower — describe the math, let the compiler schedule |
| **Analogy** | writing a `.cu` `__global__` by hand | letting a graph compiler emit kernels |

Rule of thumb: reach for `@gpu_kernel` when you'd otherwise be writing CUDA C by
hand — when the kernel is the point. Reach for flame/forge when the kernel is an
implementation detail of a larger tensor program.

The six kernels in `stdlib/qforge/nvptx_*_kernel.hexa` are real examples of the
hand-authored path: a matrix-free Sternheimer operator, a fused CG update, an
out-of-core tiled matvec, multi-GPU shard reduction — all cases where the author
knows the algorithm's structure better than a generic fuser would.

---

## 2. The shape of a kernel

A GPU kernel is an ordinary hexa `fn` with the `@gpu_kernel` attribute. The
compiler partitions a source file by attribute — `@gpu_*` functions go to the
NVPTX target, everything else to the host CPU target. One file can hold both
(exactly like a CUDA `.cu` mixes `__global__` and host code).

```hexa
@gpu_kernel
fn my_kernel(a: [f64], b: [f64], out: [f64], n: i64) {
    let gid = gpu_block_id_x() * gpu_block_dim_x() + gpu_thread_id_x()
    if to_i64(gid) < n {
        let i = to_i64(gid)
        out[i] = a[i] + b[i]
    }
}
```

Three rules that bite (from `gpu/SPEC.md` §2–§4):

1. **A `@gpu_kernel` must return `void`.** A PTX `.entry` cannot return a value;
   results go to a caller-provided `.global` array the host reads back. A
   non-void `@gpu_kernel` is lint error `GPU01`.
2. **Allowed types only**: `f64`, `f32`, `i64`, `i32`, `bool`, fixed arrays
   `[T; N]`, and borrowed slices `[T]` of those scalars. No `String`, `Map`,
   growable `List`, closures, tuples-of-bad-types (`GPU04`). A kernel has no
   host heap — every buffer is caller-provided and fixed-extent.
3. **No recursion, no heap alloc, no `.push`/`.map`/`.filter`, no `println`/IO,
   no syscalls** (`GPU05`). Straight-line + `if`/`while`/`for` + array indexing
   + intrinsics. An unbounded `while` the validator can't prove terminates is
   *warned* (`GPU05W`), not rejected — but it can hang the GPU.

The thread-index intrinsics (`gpu_thread_id_x()` etc.) return `i32`; index math
into a slice wants `i64`, so wrap with `to_i64(...)`. This `to_i64` dance appears
in every real kernel — it is the genuine idiom, not boilerplate you can drop.

---

## 3. Device-intrinsic support matrix (what hexa supports TODAY)

Read straight from the codegen op-table in `compiler/codegen/nvptx_target.hexa`
and the contract in `gpu/SPEC.md`. ✅ = lowers to PTX today. ⚠️ = real intrinsic
but see note. ❌ = does NOT exist as a codegen intrinsic (do not use).

### 3.1 Thread / block / grid indexing — ✅ all real

| hexa intrinsic | PTX special register | returns |
|---|---|---|
| `gpu_thread_id_x()` / `_y()` / `_z()` | `%tid.{x,y,z}` | `i32` |
| `gpu_block_id_x()` / `_y()` / `_z()` | `%ctaid.{x,y,z}` | `i32` |
| `gpu_block_dim_x()` / `_y()` / `_z()` | `%ntid.{x,y,z}` | `i32` |
| `gpu_grid_dim_x()` / `_y()` / `_z()` | `%nctaid.{x,y,z}` | `i32` |
| `gpu_global_thread_id_x()` / `_y()` / `_z()` | fused `ctaid*ntid+tid` | `i32` |

The flat global id is composed in hexa, not magic:

```hexa
let gid = gpu_block_id_x() * gpu_block_dim_x() + gpu_thread_id_x()
```

`gpu_global_thread_id_x()` is the same thing in one call, if you prefer.

### 3.2 Synchronization — ✅ real

| hexa intrinsic | PTX | meaning |
|---|---|---|
| `gpu_barrier()` | `bar.sync 0` | block-wide barrier |

Required between a `@shared` write and another thread reading it. The validator
does **not** prove barrier correctness (undecidable) — a missing barrier is your
bug, not a lint reject.

### 3.3 Atomics — ✅ real (f64, return old value)

| hexa intrinsic | PTX |
|---|---|
| `gpu_atomic_add(addr, v)` | `atom.add` |
| `gpu_atomic_min(addr, v)` | `atom.min` |
| `gpu_atomic_max(addr, v)` | `atom.max` |
| `gpu_atomic_cas(addr, cmp, v)` | `atom.cas` |

### 3.4 Warp shuffle — ✅ real (f64 via two .b32 halves)

| hexa intrinsic | PTX |
|---|---|
| `gpu_warp_shuffle(v, lane)` | `shfl.sync` |
| `gpu_warp_shuffle_down(v, delta)` | `shfl.sync.down` |
| `gpu_warp_shuffle_up(v, delta)` | `shfl.sync.up` |
| `gpu_warp_shuffle_xor(v, mask)` | `shfl.sync.bfly` |

### 3.5 Tensor-core (WMMA) — ✅ real (f16 / bf16 inputs, f32 accumulate)

| hexa intrinsic | PTX |
|---|---|
| `gpu_wmma_load_a` / `gpu_wmma_load_b` | `wmma.load.{a,b}.sync…m16n16k16` |
| `gpu_wmma_mma` | `wmma.mma.sync…` |
| `gpu_wmma_store_c` | `wmma.store.d.sync…` |

These exist but are an advanced surface; the cookbook examples stay in the
portable FP64 subset (gpu/SPEC.md §8 — the first implementable slice).

### 3.6 Shared memory — ✅ real, but via `@shared let` (NOT a function)

```hexa
@shared let tile: [f64; 256]    // → PTX .shared bank
```

`@shared` is a bare marker attribute on a **fixed-extent** (`[T; N]`) local of an
allowed scalar type, only inside a `@gpu_kernel` (else `GPU07`). It is parsed in
`self/parser.hexa` and lowered to the `.shared` address space.

> ⚠️ **Honest gap.** Some `@phase("parse_only")` reference kernels in
> `stdlib/qforge/` (e.g. `nvptx_stern_fused_kernel.hexa`) use
> `gpu_shared_f64(...)` / `gpu_shared_add(...)` / `gpu_shared_get(...)` as
> *function-style* shared-memory helpers. **Those are NOT codegen intrinsics** —
> they do not appear in the `nvptx_target.hexa` op-table and will not lower. They
> are placeholders in parse-only documentation kernels whose real on-device
> measurement was done in companion `.cu` host harnesses. **Use `@shared let`.**

### 3.7 Host launch — ✅ real

| hexa builtin (host side) | lowers to |
|---|---|
| `gpu_launch(kernel, gx,gy,gz, bx,by,bz, args…)` | `_hx_cuda_launch_kernel(...)` (thin cudart wrapper) |

A launch is a host syscall-like operation, not compute; routing it through a thin
cudart binding is deliberate (gpu/SPEC.md §7). The *compute* (kernel body) is
hexa-native PTX; the launch plumbing is a thin C binding.

### 3.8 Known gaps (→ HEXA-CUDA D1)

| gap | status |
|---|---|
| `hexa build --target=nvptx…` end-to-end in the **bootstrap binary** | ✅ UN-GATED (HEXA-CUDA D2) — `_build_nvptx_emit_driver` now runs the inline lex→parse→lower→lower_hir→`codegen_emit_ptx_for_sm` pipeline and writes `<src>.ptx`. The old `[nvptx] GATED RFC071-P3-PathB` fence was stale (the codegen + pipeline modules were already imported into `self/main.hexa`). vec-add + SAXPY emit source-derived PTX (`.visible .entry vec_add`/`saxpy`, `.target sm_90`). ✅ SILICON-VALIDATED on a real H100: a fresh self-host-built `hexa` re-emitted both, `ptxas -arch=sm_90` exit 0 (clean), and a CUDA Driver-API launch matched the CPU reference (maxerr 0.0, 0/2^20 mismatches). Verdict `.verdicts/hexa-cuda/F-HEXACUDA-PTXAS-DEVICE.txt`. See §5. |
| `gpu_shared_f64/_add/_get` | ❌ not codegen intrinsics — use `@shared let` (§3.6) |
| `gpu_tf32_round` (qforge mixprec kernel) | ❌ not a codegen intrinsic — TF32 in that harness is host cuBLAS, not device PTX |
| f64 `exp()` below x≈−745 | ⚠️ underflows to garbage instead of 0 — guard in-kernel (see `nvptx_a2f_kernel.hexa` d6) |

---

## 4. Recipes

Every kernel below uses **only** the ✅ intrinsics from §3. Each comes with the
host launch shape and the build command. Build-verified status is marked per
recipe (all currently **pending** on the D1(a) driver gate — see §5).

### 4.1 Vector add — `out = a + b`

The hello-world. One thread per element; the `if to_i64(gid) < n` guard handles
the ragged last block.

```hexa
// vecadd.hexa
@gpu_kernel
fn vec_add(a: [f64], b: [f64], out: [f64], n: i64) {
    let gid = gpu_block_id_x() * gpu_block_dim_x() + gpu_thread_id_x()
    if to_i64(gid) < n {
        let i = to_i64(gid)
        out[i] = a[i] + b[i]
    }
}
```

**Launch** (host hexa code in the same or another file):

```hexa
// n elements, 256 threads/block, ceil-div blocks
let block = 256
let grid  = (n + block - 1) / block
gpu_launch(vec_add, grid, 1, 1, block, 1, 1, a, b, out, n)
```

**Build:** `hexa build vecadd.hexa --target=nvptx64-nvidia-cuda-sm80`
(`sm90` / `sm120` for Hopper / Blackwell).

**Build-verified:** ✅ SILICON-VALIDATED on H100 (sm_90). Fresh-built `hexa
build … --target=nvptx64-nvidia-cuda-sm90` → source-derived PTX → `ptxas
-arch=sm_90` exit 0 (clean) → CUDA Driver-API launch → maxerr 0.0, 0/2^20
mismatches vs CPU ref. Verdict: `.verdicts/hexa-cuda/F-HEXACUDA-PTXAS-DEVICE.txt`.

### 4.2 SAXPY — `y = α·x + y`

Same one-thread-per-element shape; the scalar `α` rides in a 1-element `par`
array (the real-kernel convention — see `qforge_stern_axpy`, which is literally
this). Passing scalars through a `[f64]` slot keeps the launch ABI uniform.

```hexa
// saxpy.hexa
@gpu_kernel
fn saxpy(y: [f64], x: [f64], par: [f64], n: i64) {
    let gid = gpu_block_id_x() * gpu_block_dim_x() + gpu_thread_id_x()
    if to_i64(gid) < n {
        let i = to_i64(gid)
        y[i] = par[0] * x[i] + y[i]     // par[0] = alpha
    }
}
```

**Launch:**

```hexa
let block = 256
let grid  = (n + block - 1) / block
// par is a 1-element device buffer holding alpha
gpu_launch(saxpy, grid, 1, 1, block, 1, 1, y, x, par, n)
```

**Build:** `hexa build saxpy.hexa --target=nvptx64-nvidia-cuda-sm80`
**Build-verified:** ✅ SILICON-VALIDATED on H100 (sm_90) — fresh `hexa build`
→ PTX → `ptxas -arch=sm_90` clean → Driver-API launch → maxerr 0.0, 0/2^20
mismatches vs CPU ref. Verdict: `.verdicts/hexa-cuda/F-HEXACUDA-PTXAS-DEVICE.txt`.
This is `qforge_stern_axpy` with `α` instead of
`±α`; that kernel is part of the stack validated on an RTX 5070.

### 4.3 Parallel reduction — `s = Σ a[i]·b[i]` (dot product)

The canonical two-stage reduction, lifted from the **real**
`qforge_dot_partial` + `qforge_reduce_finalize` pattern but rewritten to use the
**real** `@shared let` form (the qforge original used the parse-only
`gpu_shared_*` helpers — see §3.6).

**Stage 1** — each block reduces its grid-stride slice into one partial via a
shared-memory tree reduction:

```hexa
// reduce.hexa
@gpu_kernel
fn dot_partial(a: [f64], b: [f64], partials: [f64], n: i64) {
    @shared let scratch: [f64; 256]      // one slot per thread (block dim = 256)
    let tid = gpu_thread_id_x()
    let gid = gpu_block_id_x() * gpu_block_dim_x() + tid
    let stride = gpu_block_dim_x() * gpu_grid_dim_x()

    // grid-stride accumulate into a private register
    let mut acc: f64 = 0.0
    let mut i = to_i64(gid)
    while i < n {
        acc = acc + a[i] * b[i]
        i = i + to_i64(stride)
    }
    scratch[to_i64(tid)] = acc
    gpu_barrier()

    // in-block tree reduction
    let mut off = gpu_block_dim_x() / 2u32
    while off > 0u32 {
        if tid < off {
            scratch[to_i64(tid)] = scratch[to_i64(tid)] + scratch[to_i64(tid) + to_i64(off)]
        }
        gpu_barrier()
        off = off / 2u32
    }

    // thread 0 writes this block's partial
    if tid == 0u32 {
        partials[to_i64(gpu_block_id_x())] = scratch[0]
    }
}
```

**Stage 2** — a single block sums the per-block partials into `out[0]`:

```hexa
@gpu_kernel
fn reduce_finalize(partials: [f64], out: [f64], nb: i64) {
    if gpu_thread_id_x() == 0u32 {
        let mut s: f64 = 0.0
        let mut k: i64 = 0
        while k < nb {
            s = s + partials[k]
            k = k + 1
        }
        out[0] = s
    }
}
```

**Launch** (two kernels, `nb` = number of stage-1 blocks):

```hexa
let block = 256
let nb    = 64                 // pick #blocks; partials has length nb
gpu_launch(dot_partial,     nb, 1, 1, block, 1, 1, a, b, partials, n)
gpu_launch(reduce_finalize,  1, 1, 1, block, 1, 1, partials, out, nb)
```

**Build:** `hexa build reduce.hexa --target=nvptx64-nvidia-cuda-sm80`
**Build-verified:** pending (§5). The algorithm (grid-stride + shared tree +
two-stage finalize) is the validated `qforge_dot_partial` /
`qforge_reduce_finalize` shape; the **only** change here is `@shared let scratch`
in place of the parse-only `gpu_shared_*` helpers, which is the form the codegen
actually lowers.

> Note: a tree reduction changes the FP summation order vs a strict left-to-right
> serial sum, so the result is bit-different (FP64 round-off only). If you need
> bit-exact parity with a serial CPU reference, do the final sum serially in one
> thread (as `reduce_finalize` does) — that is why the qforge stack keeps a serial
> reference anchor (see `nvptx_stern_fused_kernel.hexa` HONEST d6 note).

### 4.4 Tiled FP64 matmul — `C = A · B`

The classic shared-memory tiled GEMM. 2-D thread/block indexing, two `@shared`
tiles, a `gpu_barrier()` after each tile load and after each tile's MACs. This is
the FP64 subset gpu/SPEC.md §8 calls out as the target ("enough for a vector-add
and a naive / tiled FP64 GEMM"); the codegen has a dedicated 2-D tiled-GEMM emit
path (`nvptx_target.hexa` §`_nvptx_p2_*`).

```hexa
// matmul.hexa — C[M×N] = A[M×K] · B[K×N], row-major, TILE = 16
@gpu_kernel
fn matmul_tiled(A: [f64], B: [f64], C: [f64], M: i64, N: i64, K: i64) {
    @shared let As: [f64; 256]    // 16×16 tile of A
    @shared let Bs: [f64; 256]    // 16×16 tile of B

    let ty = gpu_thread_id_y()
    let tx = gpu_thread_id_x()
    let row = to_i64(gpu_block_id_y() * gpu_block_dim_y() + ty)
    let col = to_i64(gpu_block_id_x() * gpu_block_dim_x() + tx)

    let mut acc: f64 = 0.0
    let ntiles = (K + 15) / 16            // ceil(K / 16)
    let mut t: i64 = 0
    while t < ntiles {
        // cooperatively load one 16×16 tile of A and of B into shared mem
        let a_col = t * 16 + to_i64(tx)
        let b_row = t * 16 + to_i64(ty)
        let s_idx = to_i64(ty) * 16 + to_i64(tx)

        if row < M && a_col < K { As[s_idx] = A[row * K + a_col] }
        else                    { As[s_idx] = 0.0 }
        if b_row < K && col < N { Bs[s_idx] = B[b_row * N + col] }
        else                    { Bs[s_idx] = 0.0 }
        gpu_barrier()                      // tile fully loaded before use

        // multiply the two tiles
        let mut k: i64 = 0
        while k < 16 {
            acc = acc + As[to_i64(ty) * 16 + k] * Bs[k * 16 + to_i64(tx)]
            k = k + 1
        }
        gpu_barrier()                      // done reading before next load
        t = t + 1
    }

    if row < M && col < N {
        C[row * N + col] = acc
    }
}
```

**Launch** (2-D grid of 16×16 blocks):

```hexa
let tile = 16
let gx   = (N + tile - 1) / tile
let gy   = (M + tile - 1) / tile
gpu_launch(matmul_tiled, gx, gy, 1, tile, tile, 1, A, B, C, M, N, K)
```

**Build:** `hexa build matmul.hexa --target=nvptx64-nvidia-cuda-sm80`
**Build-verified:** pending (§5). Uses only ✅ intrinsics (2-D index, `@shared`,
`gpu_barrier`). The 2-D tiled-GEMM shape is exactly what the RFC 055 codegen's
`_nvptx_p2_*` tiled emit path targets and what gpu/SPEC.md §8 names as in-scope.

---

## 5. Building and launching — and the honest build-status caveat

### 5.1 The intended flow

```
.hexa with @gpu_kernel
        │  hexa build foo.hexa --target=nvptx64-nvidia-cuda-sm80
        ▼
     PTX text   (hexa-native codegen, LLVM-free — RFC 055)
        │  ptxas -arch=sm_80   (external NVIDIA tool)
        ▼
     cubin   → embedded in the host binary as a .rodata blob, registered at startup
        │  host: gpu_launch(kernel, grid…, block…, args…)
        ▼  → _hx_cuda_launch_kernel → cuLaunchKernel
     runs on the GPU
```

Target strings recognised by `hexa build --target=…`:
`nvptx64-nvidia-cuda-sm80` (Ampere), `…-sm90` (Hopper), `…-sm120` (Blackwell).

### 5.2 The honest caveat — the driver is GATED in the bootstrap binary

**Right now, in the bootstrapped `hexa` binary, the end-to-end build does not
emit PTX.** `hexa build … --target=nvptx64-nvidia-cuda-sm80` reaches
`_build_nvptx_emit_driver` (in `self/main.hexa`), which prints

```
[nvptx] GATED RFC071-P3-PathB src=foo.hexa sm=sm_80
```

and returns 1. The real codegen — `codegen_emit_ptx_for_sm` in
`compiler/codegen/nvptx_target.hexa` — is **not linked into the Stage-1
bootstrap** (it lives in the `compiler/` tree, which the bootstrap doesn't pull
in). This is RFC 071 P3 "Path B" wiring, tracked as **HEXA-CUDA D1(a)**.

What this means for you:

- The kernel **source syntax** in this cookbook is real and validated — it
  matches the six `stdlib/qforge/nvptx_*_kernel.hexa` reference kernels, the
  `gpu/SPEC.md` contract, and the `nvptx_target.hexa` op-table.
- The **codegen** is real: the RFC 055 §7 falsifier battery (hexa→PTX→ptxas→run
  for vector-add and naive FP64 GEMM) was measured **PASS on an NVIDIA RTX 5070**
  (gpu/SPEC.md §10).
- The **missing link** is only the user-facing `hexa build` driver wiring that
  feeds your `.hexa` through that codegen. Until D1(a) lands, you cannot produce
  PTX from `hexa build` locally.

So every recipe here is marked **build-verified: pending**. The honest status is:
*syntax-real and codegen-validated, end-to-end-`hexa build` pending.*

> Also note (memory `project_local_hexa_stale_oracle`): a locally-installed
> `hexa` may be a stale build. Even once D1(a) lands, re-verify the end-to-end
> path on a fresh toolchain (tracked as **HEXA-CUDA D2**) before trusting a local
> build result.

### 5.3 What you CAN do today

- Author and **lint** kernels — the `@gpu_kernel` partition + the `GPU0N`
  validation rules (gpu/SPEC.md §9) run in the parse/check path.
- Study the six `stdlib/qforge/nvptx_*_kernel.hexa` kernels as a reference corpus.
- Mirror a kernel into a CUDA `.cu` host harness for on-device measurement (the
  qforge kernels each ship a companion `nvptx_*_host.cu`) while the native
  end-to-end driver is gated.

---

## 6. Quick reference card

```hexa
// --- kernel skeleton ---
@gpu_kernel                       // → NVPTX .entry; MUST return void
fn k(a: [f64], out: [f64], n: i64) {
    @shared let s: [f64; 256]                       // block-shared, fixed extent
    let gid = gpu_block_id_x() * gpu_block_dim_x()  // grid-stride global id
            + gpu_thread_id_x()
    if to_i64(gid) < n {                            // ragged-tail guard
        // ... compute, index with to_i64(...) ...
    }
    gpu_barrier()                                   // publish @shared writes
}

// --- index intrinsics (i32; compose flat id yourself) ---
gpu_thread_id_{x,y,z}()   gpu_block_id_{x,y,z}()
gpu_block_dim_{x,y,z}()   gpu_grid_dim_{x,y,z}()
gpu_global_thread_id_{x,y,z}()                      // = ctaid*ntid+tid

// --- sync / atomics / warp ---
gpu_barrier()
gpu_atomic_add/min/max(addr, v)   gpu_atomic_cas(addr, cmp, v)
gpu_warp_shuffle(v, lane)   _down/_up/_xor(...)

// --- host launch ---
gpu_launch(kernel, gx, gy, gz, bx, by, bz, args...)

// --- build ---
hexa build k.hexa --target=nvptx64-nvidia-cuda-sm80   // sm90 / sm120 too
//   (end-to-end emit currently GATED — HEXA-CUDA D1(a); syntax + codegen real)
```

**Do NOT use** (not codegen intrinsics): `gpu_shared_f64/_add/_get`,
`gpu_tf32_round`. Use `@shared let` for shared memory; TF32/tensor-core via the
`gpu_wmma_*` family.
