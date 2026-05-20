# gpu — `@gpu` subset specification

> **SSOT** for the `@gpu` kernel-source subset: which hexa constructs are
> legal inside a GPU kernel, the thread-index / sync intrinsics, the
> shared-memory model, the host launch ABI, and the strict-lint
> validation rules.
>
> Status: **SPECIFICATION** — this file defines the contract. The
> *implementation* of the hexa→PTX codegen that consumes this contract is
> **RFC 055** (`compiler/codegen/nvptx_*.hexa`); RFC 055 §6 references
> this file rather than re-specifying it (gpu/design.md Decision 3).
>
> Scope split: `gpu/SPEC.md` = the language-surface spec (this file).
> RFC 055 = the NVPTX codegen target that lowers it. `self/native/
> gpu_codegen_stub.c` = the rt#45 codegen skeleton, superseded by
> RFC 055's `nvptx_target.hexa`.

## 1. What `@gpu` is

A GPU kernel is an ordinary hexa `fn` carrying a `@gpu_kernel` or
`@gpu_device` attribute (gpu/design.md Decision 1 — no `.hxk` extension,
no new keyword). The compiler partitions a source file by attribute: a
`@gpu_*` function is routed to the NVPTX codegen target (RFC 055); every
other function continues to the host CPU target. One file can therefore
hold both host glue and device kernels.

```
   ordinary .hexa file
   ┌─────────────────────────────┐
   │ fn host_setup() { ... }     │ ──▶ CPU target (arm64 / x86_64)
   │                             │
   │ @gpu_kernel                 │
   │ fn vadd(a,b,c: [f64], n) {  │ ──▶ NVPTX target (RFC 055)
   │   ...                       │      → PTX text → ptxas → cubin
   │ }                           │
   └─────────────────────────────┘
       compiler partitions by attribute
```

This mirrors CUDA exactly: a `.cu` file is C++ with `__global__` /
`__device__` annotations, not a separate language — the annotation, not
the file type, flips the compile mode.

## 2. The two attributes

| Attribute | PTX lowering | Returns | Callable from |
|---|---|---|---|
| `@gpu_kernel` | `.visible .entry` | **must be `void`** — a PTX entry cannot return a value; results are written to a `.global` farr the host reads back | host code via `gpu_launch` only |
| `@gpu_device` | `.func` | may return a value | `@gpu_kernel` / `@gpu_device` code only |

`@gpu_kernel` with a non-`void` return type is a strict-lint error
(`GPU01`). A `@gpu_device` function called from CPU code is a strict-lint
error (`GPU02`) — and vice versa, a CPU `fn` called from a `@gpu_*` body
is `GPU03`.

## 3. Type allowlist

Legal inside a `@gpu_*` function — parameters, locals, return type:

| Category | Allowed |
|---|---|
| Scalars | `f64`, `f32`, `i64`, `i32`, `bool` |
| Arrays | fixed `[T; N]`, borrowed slice `[T]` of an allowed scalar `T` |
| — | (the FP64-first slice, §8, exercises `f64` + `[f64]` + `i64` index math) |

**Rejected** (`GPU04`): `String`, `Map`, `Set`, growable `List`, tuples
of non-allowed types, closures / function values, trait objects, any
heap-backed or dynamically-sized type. A GPU kernel has no host heap and
no allocator — every buffer is caller-provided and fixed-extent.

## 4. Statement / expression allowlist

**Allowed:**

- arithmetic (`+ - * /`), comparison, bitwise, logical operators on
  allowed scalar types
- array indexing `a[i]` and indexed assignment `a[i] = v` on `[T]` / `[T; N]`
- `let` / `let mut` bindings of allowed types
- `if` / `else`, `while`, `return`
- `for` over an integer range **with bounds the compiler can see**
  (a thread-indexed loop) — see §8
- calls to allowlisted intrinsics (§5) and to other `@gpu_device` fns

**Rejected** (`GPU05`):

- recursion (direct or mutual) — a GPU has no growable call stack
- host heap allocation, `new`, growable-collection ops (`.map`,
  `.filter`, `.push`, …)
- `println`, file IO, any syscall, any `@cite`-bearing host-runtime call
- closures / lambda capture, dynamic dispatch / vtable
- a call to any non-`@gpu_*` function other than an allowlisted intrinsic
- unbounded `while` whose termination the validator cannot establish is
  *allowed but warned* (`GPU05W`) — the kernel may hang the GPU; the
  warning is the honest signal, not a hard reject

## 5. Intrinsics — thread index, sync, atomics

These pseudo-functions are pattern-matched at codegen time and never
linked at runtime. They are **only legal inside `@gpu_*` functions**;
used in CPU code they are a strict-lint error (`GPU06`, the GPU/CPU
phase-confusion guard).

| hexa intrinsic | PTX | Metal (informational) | meaning |
|---|---|---|---|
| `gpu_thread_id_x()` / `_y()` / `_z()` | `%tid.{x,y,z}` | `thread_position_in_threadgroup` | thread index within its block |
| `gpu_block_id_x()` / `_y()` / `_z()` | `%ctaid.{x,y,z}` | `threadgroup_position_in_grid` | block index within the grid |
| `gpu_block_dim_x()` / `_y()` / `_z()` | `%ntid.{x,y,z}` | `threads_per_threadgroup` | block dimensions |
| `gpu_grid_dim_x()` / `_y()` / `_z()` | `%nctaid.{x,y,z}` | `threadgroups_per_grid` | grid dimensions |
| `gpu_barrier()` | `bar.sync 0` | `threadgroup_barrier` | block-wide barrier |
| `gpu_atomic_add(addr, v)` | `atom.add` | `atomic_fetch_add_explicit` | atomic add, returns old value |
| `gpu_warp_shuffle(v, lane)` | `shfl.sync` | `simd_shuffle` | warp-lane data exchange |

Each thread-index intrinsic lowers to a single `mov.u32` from the
corresponding PTX special register and returns an `i32`. The per-axis
naming (`_x` / `_y` / `_z`) is explicit and matches the PTX sregs 1:1 —
this **supersedes** RFC 055 §6.4's looser `gpu_thread_idx()` shorthand
and the `self/native/gpu_codegen_stub.c` intrinsic table is the
in-tree reference for the same set.

A global flat thread id is composed in hexa, not magic:

```
let gid = gpu_block_id_x() * gpu_block_dim_x() + gpu_thread_id_x()
```

## 6. Shared memory

A block-shared array is an ordinary fixed local array carrying a
`@shared` annotation:

```
@gpu_kernel
fn tiled_gemm(...) {
    @shared let tile: [f64; 256]   // → PTX .shared .align 8 .b8
    ...
    gpu_barrier()                  // publish writes before cross-thread reads
}
```

`@shared` is legal only on a fixed-extent (`[T; N]`) local of an allowed
scalar type, only inside a `@gpu_kernel` (`GPU07` otherwise). Shared
memory is block-scoped: all threads of a block see the same array; a
`gpu_barrier()` is required between a shared-memory write and another
thread reading it. The validator does **not** prove barrier correctness
(that is undecidable in general) — a missing barrier is a kernel-author
bug, not a lint reject.

## 7. Launch ABI — host launches a kernel

A compiled `@gpu_kernel` produces a `cubin`, embedded in the host binary
as a `.rodata` `LSection` blob and registered at startup. Host hexa code
launches it through the `gpu_launch` builtin:

```
gpu_launch(kernel, grid_x, grid_y, grid_z,
                   block_x, block_y, block_z, args...)
```

The compiler lowers `gpu_launch` to a `hexa_cuda_launch_kernel` runtime
call — a thin cudart wrapper, sibling to the existing `hexa_cuda_alloc /
copy / free / sync` family in `self/cuda/runtime_cuda.c`. That wrapper
resolves the kernel's `cubin`, marshals the argument buffer, and calls
`cuLaunchKernel`.

**Honest framing.** A kernel *launch* is a syscall-like host operation,
not compute. Routing it through the cudart binding is the same category
of decision as the C-fallback portability path: the *compute* (the
kernel body) is hexa-native PTX; the *launch plumbing* stays a thin C
binding. A no-CUDA-dependency launch (driver `ioctl` direct) is a
possible later goal, explicitly out of scope — it buys nothing for
kernel correctness. `ptxas` (PTX→SASS) is likewise an external NVIDIA
tool; the hexa→PTX *text* path is LLVM-free (RFC 055 F-RFC055-NO-LLVM,
honors `AGENTS.tape` g5/f2).

## 8. FP64-first scope

The first implementable slice of `@gpu` is deliberately narrow — it
matches forge's existing FP64 `farr` (packed-double) layout so a
hexa-emitted kernel and forge's cuBLAS path share the same data:

- **FP64 scalar / vector arithmetic** — `ld.global.f64`, `st.global.f64`,
  `add.f64`, `mul.f64`, `fma.rn.f64`, `ld.shared.f64`, `bar.sync`, the
  thread-index `mov.u32`s, integer index arithmetic. Enough for a
  vector-add and a naive / tiled FP64 GEMM.
- **No Tensor Core MMA in the first slice.** A `@gpu` `wmma` / `wgmma`
  intrinsic is a named follow-on. forge Phase R measured hand-WMMA at
  41–43% TC peak — feasible but expensive to tune; not first-cut.
- **No control-flow exotica.** Straight-line + simple `for` / `if` over a
  thread-indexed loop. Divergent control flow lowers correctly via PTX
  predication; the optimized form is a later sub-phase.

## 9. strict-lint validation — `GPU0N` error codes

The `@gpu` validation pass (`validate_gpu_subset` in
`gpu_codegen_stub.c`, to be reimplemented in RFC 055's
`nvptx_target.hexa`) walks a `@gpu_*` FnDecl and rejects anything outside
this spec:

| Code | Rejection |
|---|---|
| `GPU01` | `@gpu_kernel` with a non-`void` return type |
| `GPU02` | `@gpu_device` called from CPU code |
| `GPU03` | CPU `fn` called from a `@gpu_*` body |
| `GPU04` | a parameter / local / return of a non-allowlisted type (§3) |
| `GPU05` | recursion · heap alloc · growable-collection op · IO · syscall |
| `GPU05W` | (warning) unbounded loop the validator cannot prove terminates |
| `GPU06` | a `gpu_*` intrinsic used in CPU code |
| `GPU07` | `@shared` outside a `@gpu_kernel`, or on a non-fixed-array local |

A kernel that passes validation is guaranteed lowerable by the NVPTX
target for the FP64 subset (§8); anything richer is a future sub-phase,
not a silent miscompile.

## 10. Cross-references

- `gpu/design.md` — Decision 1 (format) · 2 (dir) · 3 (this file = SSOT)
  · 4 (055-P2 scope)
- `gpu/HANDOFF.md` — next-steps brief + honest performance framing
- **RFC 055** (`inbox/rfc_drafts_2026_05_12/rfc_055_hexa_nvptx_codegen_backend.md`)
  — the NVPTX codegen *implementation* that consumes this spec; §6
  references this file. Phasing: 055-P0 (PTX text emit, landed) →
  055-P1 (vec-add) + 055-P2 (naive FP64 GEMM) — **both LANDED + the
  RFC 055 §7 falsifier battery measured PASS on an NVIDIA RTX 5070,
  2026-05-20** → 055-P3 (MIR partition + `gpu_launch` lowering + cubin
  embed — wire the codegen into the main compile pipeline).
- `self/native/gpu_codegen_stub.c` — rt#45 codegen skeleton; the
  intrinsic table + allowlist/denylist here match it; superseded by
  RFC 055's `compiler/codegen/nvptx_target.hexa`.
- `HEXA-NATIVE-ONLY.md` §2 axis E5 — `@gpu` offload is the listed future
  axis this spec defines.
