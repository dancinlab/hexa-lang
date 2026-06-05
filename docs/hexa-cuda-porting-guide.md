# Porting a CUDA `.cu` / Python GPU kernel to a `.hexa` `@gpu_kernel`

> You have a hand-written CUDA `__global__` (or a PyCUDA / Numba / Triton kernel)
> and you want it as a native `.hexa` `@gpu_kernel` — typed, 8-stage-linted, in
> the single hexa binary, no separate `.cu` / `nvcc` / FFI glue. This guide is the
> migration on-ramp: a **mechanical, line-by-line** translation of the common
> patterns, with the exact intrinsic mapping table.
>
> Companion docs:
> - **`docs/hexa-cuda-cookbook.md`** — the recipes from scratch (start here if you
>   are *writing* a kernel rather than *porting* one).
> - **`gpu/SPEC.md`** — the `@gpu` subset contract (attributes, type allowlist,
>   intrinsics, shared-memory model, launch ABI, `GPU0N` lint codes).
> - **`compiler/codegen/nvptx_target.hexa`** — the op-table that is ground truth
>   for *which* intrinsics actually lower to PTX.
>
> Every `.hexa` snippet below uses **only** intrinsics that lower today (verified
> against the op-table + the six `stdlib/qforge/nvptx_*_kernel.hexa` reference
> kernels). No invented syntax. End-to-end `hexa build --target=nvptx` emit status
> is tracked honestly in the cookbook §5.

---

## 1. The mental model — what maps to what

CUDA and the hexa `@gpu_kernel` path share the same execution model (grid of
blocks of threads, shared memory, barriers). The translation is therefore
**mechanical**, not a redesign. The differences are surface:

| CUDA C++ (`.cu`) | hexa `@gpu_kernel` | note |
|---|---|---|
| `__global__ void k(...)` | `@gpu_kernel fn k(...) { ... }` | kernel **must** return `void` (`GPU01`) |
| `__device__ T f(...)` | `@gpu_device fn f(...) -> T { ... }` | device-only helper, may return a value |
| `float* a` (device ptr) | `a: [f64]` (borrowed slice) | buffers are caller-provided, fixed-extent |
| `double`, `float`, `int`, `long long` | `f64`, `f32`, `i32`, `i64` | the FP64-first slice (gpu/SPEC.md §8) |
| `__shared__ double t[256];` | `@shared let t: [f64; 256]` | a *fixed-extent* local marked `@shared` |
| `k<<<grid, block>>>(args)` | `gpu_launch(k, gx,gy,gz, bx,by,bz, args)` | launch is host-side (gpu/SPEC.md §7) |

---

## 2. Intrinsic mapping table

The single most useful artifact when porting. **Left = the CUDA builtin in your
`.cu`; right = the hexa intrinsic that lowers to the same PTX** (verified against
`compiler/codegen/nvptx_target.hexa` + `gpu/SPEC.md` §5).

### 2.1 Thread / block / grid indexing

| CUDA | hexa intrinsic | PTX sreg | returns |
|---|---|---|---|
| `threadIdx.x` / `.y` / `.z` | `gpu_thread_id_x()` / `_y()` / `_z()` | `%tid.{x,y,z}` | `i32` |
| `blockIdx.x` / `.y` / `.z` | `gpu_block_id_x()` / `_y()` / `_z()` | `%ctaid.{x,y,z}` | `i32` |
| `blockDim.x` / `.y` / `.z` | `gpu_block_dim_x()` / `_y()` / `_z()` | `%ntid.{x,y,z}` | `i32` |
| `gridDim.x` / `.y` / `.z` | `gpu_grid_dim_x()` / `_y()` / `_z()` | `%nctaid.{x,y,z}` | `i32` |
| `blockIdx.x*blockDim.x + threadIdx.x` | `gpu_global_thread_id_x()` | fused | `i32` |

> The thread-index intrinsics return `i32`. Index math into a slice wants `i64`,
> so wrap with `to_i64(...)`. This `to_i64` dance appears in every real kernel —
> it is the genuine idiom, not droppable boilerplate.

### 2.2 Synchronization

| CUDA | hexa | PTX |
|---|---|---|
| `__syncthreads()` | `gpu_barrier()` | `bar.sync 0` |

### 2.3 Atomics (f64, return the old value)

| CUDA | hexa | PTX |
|---|---|---|
| `atomicAdd(addr, v)` | `gpu_atomic_add(addr, v)` | `atom.add` |
| `atomicMin(addr, v)` | `gpu_atomic_min(addr, v)` | `atom.min` |
| `atomicMax(addr, v)` | `gpu_atomic_max(addr, v)` | `atom.max` |
| `atomicCAS(addr, cmp, v)` | `gpu_atomic_cas(addr, cmp, v)` | `atom.cas` |

### 2.4 Warp shuffle

| CUDA | hexa | PTX |
|---|---|---|
| `__shfl_sync(m, v, lane)` | `gpu_warp_shuffle(v, lane)` | `shfl.sync` |
| `__shfl_down_sync(m, v, d)` | `gpu_warp_shuffle_down(v, d)` | `shfl.sync.down` |
| `__shfl_up_sync(m, v, d)` | `gpu_warp_shuffle_up(v, d)` | `shfl.sync.up` |
| `__shfl_xor_sync(m, v, mask)` | `gpu_warp_shuffle_xor(v, mask)` | `shfl.sync.bfly` |

> The hexa warp-shuffle intrinsics do not take an explicit active-lane mask
> argument — the codegen emits the full-warp mask. f64 values are shuffled as two
> `.b32` halves by the codegen; you pass a single `f64`.

### 2.5 Tensor-core (WMMA) — advanced

| CUDA (`nvcuda::wmma`) | hexa | PTX |
|---|---|---|
| `wmma::load_matrix_sync(a, ...)` | `gpu_wmma_load_a(...)` | `wmma.load.a.sync…m16n16k16` |
| `wmma::load_matrix_sync(b, ...)` | `gpu_wmma_load_b(...)` | `wmma.load.b.sync…` |
| `wmma::mma_sync(c, a, b, c)` | `gpu_wmma_mma(...)` | `wmma.mma.sync…` |
| `wmma::store_matrix_sync(d, c, ...)` | `gpu_wmma_store_c(...)` | `wmma.store.d.sync…` |

The WMMA family is real but advanced (f16/bf16 inputs, f32 accumulate); the
portable FP64 subset (gpu/SPEC.md §8) is the recommended first port.

### 2.6 Shared memory — a marker, not a function

| CUDA | hexa |
|---|---|
| `__shared__ double t[256];` | `@shared let t: [f64; 256]` |

`@shared` is a bare attribute on a **fixed-extent** (`[T; N]`) local of an allowed
scalar type, only inside a `@gpu_kernel` (else `GPU07`).

> ⚠️ **Do NOT use** `gpu_shared_f64(...)` / `gpu_shared_add(...)` /
> `gpu_shared_get(...)` — these are *not* codegen intrinsics (they appear only in
> some parse-only reference kernels). Use `@shared let`.

### 2.7 Host launch

| CUDA | hexa |
|---|---|
| `k<<<grid, block>>>(args);` | `gpu_launch(k, gx,gy,gz, bx,by,bz, args)` |
| `cudaMalloc` / `cudaMemcpy` | caller-provided device arrays (the launch ABI) |

---

## 3. Pattern 1 — vector add

### CUDA (`vecadd.cu`)

```cuda
__global__ void vec_add(const double* a, const double* b, double* out, long n) {
    long gid = blockIdx.x * blockDim.x + threadIdx.x;
    if (gid < n) {
        out[gid] = a[gid] + b[gid];
    }
}
// launch:
//   int block = 256;
//   int grid  = (n + block - 1) / block;
//   vec_add<<<grid, block>>>(a, b, out, n);
```

### hexa (`vecadd.hexa`)

```hexa
@gpu_kernel
fn vec_add(a: [f64], b: [f64], out: [f64], n: i64) {
    let gid = gpu_block_id_x() * gpu_block_dim_x() + gpu_thread_id_x()
    if to_i64(gid) < n {
        let i = to_i64(gid)
        out[i] = a[i] + b[i]
    }
}
```

```hexa
// launch (host hexa code)
let block = 256
let grid  = (n + block - 1) / block
gpu_launch(vec_add, grid, 1, 1, block, 1, 1, a, b, out, n)
```

**What changed:** `__global__ void` → `@gpu_kernel fn … (returns void)`;
`double*` → `[f64]`; `threadIdx.x` etc. → the `gpu_*` intrinsics; the `gid < n`
guard gains a `to_i64(...)` because the intrinsics return `i32`; `<<<grid,
block>>>` → `gpu_launch`.

You can also scaffold this exact skeleton with **`hexa new gpu-kernel vec_add`**.

---

## 4. Pattern 2 — SAXPY (`y = α·x + y`)

### CUDA (`saxpy.cu`)

```cuda
__global__ void saxpy(double* y, const double* x, double alpha, long n) {
    long gid = blockIdx.x * blockDim.x + threadIdx.x;
    if (gid < n) {
        y[gid] = alpha * x[gid] + y[gid];
    }
}
```

### hexa (`saxpy.hexa`)

A scalar like `alpha` rides in a 1-element `par` array — the real-kernel
convention (`qforge_stern_axpy`). Passing scalars through a `[f64]` slot keeps the
launch ABI uniform.

```hexa
@gpu_kernel
fn saxpy(y: [f64], x: [f64], par: [f64], n: i64) {
    let gid = gpu_block_id_x() * gpu_block_dim_x() + gpu_thread_id_x()
    if to_i64(gid) < n {
        let i = to_i64(gid)
        y[i] = par[0] * x[i] + y[i]     // par[0] = alpha
    }
}
```

```hexa
let block = 256
let grid  = (n + block - 1) / block
gpu_launch(saxpy, grid, 1, 1, block, 1, 1, y, x, par, n)   // par = [alpha]
```

**What changed (beyond pattern 1):** a bare scalar kernel argument (`double
alpha`) becomes a 1-element array slot (`par: [f64]`, read as `par[0]`). This is
the idiom the qforge stack uses; it keeps every kernel argument a slice and the
launch ABI uniform.

---

## 5. Pattern 3 — parallel reduction (dot product)

The canonical two-stage reduction: stage 1, each block reduces a grid-stride
slice into one partial via a shared-memory tree; stage 2, a single block sums the
partials.

### CUDA (`reduce.cu`)

```cuda
__global__ void dot_partial(const double* a, const double* b,
                            double* partials, long n) {
    __shared__ double scratch[256];
    unsigned tid = threadIdx.x;
    long gid     = blockIdx.x * blockDim.x + tid;
    unsigned stride = blockDim.x * gridDim.x;

    double acc = 0.0;
    for (long i = gid; i < n; i += stride) acc += a[i] * b[i];
    scratch[tid] = acc;
    __syncthreads();

    for (unsigned off = blockDim.x / 2; off > 0; off >>= 1) {
        if (tid < off) scratch[tid] += scratch[tid + off];
        __syncthreads();
    }
    if (tid == 0) partials[blockIdx.x] = scratch[0];
}
```

### hexa (`reduce.hexa`)

Lifted from the **real** `qforge_dot_partial` pattern, rewritten to the **real**
`@shared let` form (the qforge original used the parse-only `gpu_shared_*`
placeholders — see the cookbook §3.6).

```hexa
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

```hexa
let block = 256
let nb    = 64                 // #stage-1 blocks; partials has length nb
gpu_launch(dot_partial,     nb, 1, 1, block, 1, 1, a, b, partials, n)
gpu_launch(reduce_finalize,  1, 1, 1, block, 1, 1, partials, out, nb)
```

**What changed:**

- `__shared__ double scratch[256];` → `@shared let scratch: [f64; 256]`.
- CUDA's `for` loops become hexa `while` loops with explicit index types — the
  grid-stride `for (i = gid; i < n; i += stride)` and the tree-reduction
  `for (off = blockDim.x/2; off > 0; off >>= 1)`. (`>>= 1` is written `off =
  off / 2u32`; the `u32` suffix matches the unsigned intrinsic return type.)
- `__syncthreads()` → `gpu_barrier()`.
- comparisons against intrinsic results use the `u32` literal form (`off > 0u32`,
  `tid == 0u32`); slice indexing wraps with `to_i64(...)`.

> **FP note.** A tree reduction changes the FP64 summation order vs a strict
> serial sum, so the result is bit-different (round-off only) — exactly as in
> CUDA. If you need bit-exact parity with a serial CPU reference, finalize the sum
> serially in one thread (as `reduce_finalize` does).

---

## 6. Pattern 4 — tiled FP64 matmul (`C = A · B`)

The classic shared-memory tiled GEMM: 2-D thread/block indexing, two `@shared`
tiles, a `gpu_barrier()` after each tile load and after each tile's MACs.

### CUDA (`matmul.cu`, `TILE = 16`)

```cuda
__global__ void matmul_tiled(const double* A, const double* B, double* C,
                            long M, long N, long K) {
    __shared__ double As[256];   // 16x16
    __shared__ double Bs[256];
    int ty = threadIdx.y, tx = threadIdx.x;
    long row = blockIdx.y * blockDim.y + ty;
    long col = blockIdx.x * blockDim.x + tx;
    double acc = 0.0;
    long ntiles = (K + 15) / 16;
    for (long t = 0; t < ntiles; ++t) {
        long a_col = t*16 + tx, b_row = t*16 + ty;
        int  s_idx = ty*16 + tx;
        As[s_idx] = (row < M && a_col < K) ? A[row*K + a_col] : 0.0;
        Bs[s_idx] = (b_row < K && col < N) ? B[b_row*N + col] : 0.0;
        __syncthreads();
        for (int k = 0; k < 16; ++k) acc += As[ty*16 + k] * Bs[k*16 + tx];
        __syncthreads();
    }
    if (row < M && col < N) C[row*N + col] = acc;
}
```

### hexa (`matmul.hexa`)

```hexa
@gpu_kernel
fn matmul_tiled(A: [f64], B: [f64], C: [f64], M: i64, N: i64, K: i64) {
    @shared let As: [f64; 256]    // 16x16 tile of A
    @shared let Bs: [f64; 256]    // 16x16 tile of B

    let ty = gpu_thread_id_y()
    let tx = gpu_thread_id_x()
    let row = to_i64(gpu_block_id_y() * gpu_block_dim_y() + ty)
    let col = to_i64(gpu_block_id_x() * gpu_block_dim_x() + tx)

    let mut acc: f64 = 0.0
    let ntiles = (K + 15) / 16            // ceil(K / 16)
    let mut t: i64 = 0
    while t < ntiles {
        let a_col = t * 16 + to_i64(tx)
        let b_row = t * 16 + to_i64(ty)
        let s_idx = to_i64(ty) * 16 + to_i64(tx)

        if row < M && a_col < K { As[s_idx] = A[row * K + a_col] }
        else                    { As[s_idx] = 0.0 }
        if b_row < K && col < N { Bs[s_idx] = B[b_row * N + col] }
        else                    { Bs[s_idx] = 0.0 }
        gpu_barrier()                      // tile fully loaded before use

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

```hexa
let tile = 16
let gx   = (N + tile - 1) / tile
let gy   = (M + tile - 1) / tile
gpu_launch(matmul_tiled, gx, gy, 1, tile, tile, 1, A, B, C, M, N, K)
```

**What changed:** two `__shared__ double[256]` → two `@shared let […: f64; 256]`;
the CUDA ternary `(cond) ? x : y` for the boundary load → an `if/else` block;
`__syncthreads()` → `gpu_barrier()`; the two `for` loops → `while` loops with
explicit `i64` indices; 2-D indexing reads from `gpu_thread_id_x/_y` +
`gpu_block_id_x/_y` + `gpu_block_dim_x/_y`.

---

## 7. The translation checklist (apply to any kernel)

1. `__global__ void k(...)` → `@gpu_kernel fn k(...) { }` (no return value).
   A `__device__` helper → `@gpu_device fn h(...) -> T { }`.
2. Every pointer parameter `T* p` → a slice `p: [hexa-T]` (`double*`→`[f64]`,
   `float*`→`[f32]`, `int*`→`[i32]`, `long long*`→`[i64]`).
3. Bare scalar args → a 1-element array slot, read as `par[0]` (the qforge idiom).
4. Replace each CUDA builtin with its hexa intrinsic via the §2 table.
5. Wrap every slice index that comes from a `gpu_*` intrinsic in `to_i64(...)`;
   compare intrinsic results against `u32` literals (`tid == 0u32`).
6. `for (init; cond; step)` → a `while` loop with an explicit `let mut` index of
   the right type (`i64` for slice indices).
7. `__shared__ T s[N];` → `@shared let s: [hexa-T; N]` (fixed extent only).
8. `(cond) ? x : y` → `if cond { x } else { y }`.
9. `k<<<grid, block>>>(args)` → `gpu_launch(k, gx,gy,gz, bx,by,bz, args)`.
10. Re-check against the `GPU0N` lint codes (gpu/SPEC.md §9): no recursion, no
    heap, no growable collections, no IO/syscalls in the kernel body.

---

## 8. Build & verify

```
hexa build mykernel.hexa --target=nvptx64-nvidia-cuda-sm80   // sm90 / sm120 too
```

The hexa→PTX codegen is LLVM-free (RFC 055). `ptxas` (PTX→SASS) is the external
NVIDIA tool, the same one your `.cu` already uses. The **launch** plumbing routes
through a thin cudart binding (gpu/SPEC.md §7) — the *compute* (kernel body) is
hexa-native PTX.

**Honest end-to-end status.** See the cookbook §5.2: the kernel **source syntax**
in this guide is real and validated (it mirrors the six
`stdlib/qforge/nvptx_*_kernel.hexa` reference kernels and the codegen op-table),
and the RFC 055 falsifier battery (vec-add + naive FP64 GEMM, hexa→PTX→ptxas→run)
measured PASS on an NVIDIA RTX 5070. The user-facing `hexa build --target=nvptx`
emit-driver wiring is tracked as HEXA-CUDA D1(a)/D2; until it lands on a fresh
toolchain, re-verify the end-to-end build there (the local `hexa` may be stale).

---

## 9. When NOT to port by hand

If your `.cu` is a standard tensor pipeline (GEMM chains, norm+activation,
attention) where the kernel is an *implementation detail* of a larger array
program, consider the **auto-fusion flame/forge path** instead — it picks the
tiling and emits the kernel for you. Reach for `@gpu_kernel` (this guide) when the
kernel is the point: a bespoke reduction, a stencil, a matrix-free operator, a
custom algorithm you understand better than a generic fuser. See the cookbook §1
for the full decision table.
