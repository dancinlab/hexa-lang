# `farr_free` never reclaims — runtime bump allocator's noop `free` leaks every farr → long-running decode OOMs

**Reported-by:** anima (downstream) · 2026-06-21 · measured on `summer` (Ubuntu, glibc, 30 GB)
**Severity:** blocking for any **long-running** hexa program (decode/inference/serve loops).
A one-shot compile is unaffected (that is the allocator's design point), but a
program that allocates millions of transient `farr` over its lifetime climbs RSS
monotonically to host-OOM. This is the substrate wall blocking anima's
engine-native G6 decode (H_1464: a 303M byte-LM decode RSS 91 → 125 GB, ~2 GB/min,
earlyoom-killed at frag 5-8, 90-fragment run never completes).

## Root cause (code + measurement agree)

The runtime memory family is an **mmap-backed bump allocator that never frees**:

```c
// self/runtime.c
~1000  // Cycle 53 — Tier-A.2 mmap-backed bump allocator. malloc never frees;
       // free is a noop; realloc bump-allocates new region + byte copy.
       // Trade-off: compiler binary leaks memory until exit (a one-shot tool;
       // acceptable).
1060   static void __attribute__((noinline)) hxlcl_free(void *p) { (void)p; }   // NOOP
2124   #define free(p)  hxlcl_free((void *)(p))                                 // file-wide
```

`hexa_farr_zeros` / `hexa_farr_free` therefore allocate via the bump `calloc`
and their `free(e->buf)` expands to the **noop** `hxlcl_free` — so **every farr
buffer is leaked for the lifetime of the process**, even though the handle table
+ freelist are recycled correctly:

```c
6204  HexaVal hexa_farr_zeros(HexaVal n_v) { ...
6210      buf = (double*)calloc((size_t)n, sizeof(double));   // bump alloc
6305  HexaVal hexa_farr_free(HexaVal h_v) { ...
6309      if (e->buf) { free(e->buf); e->buf = NULL; e->len = 0; }   // free == NOOP
```

This is why `HEXA_FARR_TRIM=1` (the mmap-threshold mallopt tuning, runtime_core_emit.hexa)
has **zero effect** on the leak: the buffers are never `free()`d at all, so the
"munmap on free" path never runs.

### Measurement (minimal C, replicates the runtime's two paths exactly)

`__libc_calloc(256*768) + memset` per iteration, 20000 iters (1.5 MB/iter):

| path | RSS trajectory |
|------|----------------|
| **noop free** (current runtime) | 3 MB → 6 → 12 → 18 → 24 → **29.7 GB** (linear, +1.5 MB/iter = exactly the unfreed buffer) |
| **real `__libc_free`** | **flat at 3 MB** through all 20000 iters |

Same result through the real hexa toolchain (constant-size `farr_matmul` + `farr_free`
loop, `mmconst.hexa`, 20000 iters):

| runtime.a | RSS |
|-----------|-----|
| stock (noop free) | climbs to **30.3 GB** |
| patched (farr → libc) | **flat at 5.2 MB** |

(Note: NOT a boxed-scalar blowup — `farr` is already packed f64; a `farr_zeros(100M)`
measured **8.04 bytes/elem** = `calloc(n, sizeof(double))`. The 91 GB in H_1464 is the
**accumulated unfreed transient churn**, not the resident weights (~5 GB packed) nor
per-element boxing.)

## Fix (applied + verified locally; needs graduation into the shipped runtime.a)

Route **only the `farr` bulk allocator** to the real reclaiming libc allocator,
leaving the compiler's bump allocator (everything else) untouched. glibc exposes
`__libc_calloc` / `__libc_free` under distinct names, so the file-wide
`#define calloc/free → hxlcl_*` shims do not rewrite them.

```diff
 // self/runtime.c — just before hexa_farr_zeros
+#if defined(__GLIBC__)
+extern void *__libc_calloc(size_t, size_t);
+extern void  __libc_free(void *);
+#define HXFARR_CALLOC(nm,sz) __libc_calloc((nm),(sz))
+#define HXFARR_FREE(p)       __libc_free((p))
+#else
+#define HXFARR_CALLOC(nm,sz) calloc((nm),(sz))   /* one-shot Darwin dev builds */
+#define HXFARR_FREE(p)       free((p))
+#endif

 HexaVal hexa_farr_zeros(HexaVal n_v) { ...
-      buf = (double*)calloc((size_t)n, sizeof(double));
+      buf = (double*)HXFARR_CALLOC((size_t)n, sizeof(double));

 HexaVal hexa_farr_free(HexaVal h_v) { ...
-      if (e->buf) { free(e->buf); e->buf = NULL; e->len = 0; }
+      if (e->buf) { HXFARR_FREE(e->buf); e->buf = NULL; e->len = 0; }
```

Verified end-to-end on `summer`: recompiled `runtime.o` (`clang -c -O2 -std=gnu11
-D_GNU_SOURCE`), swapped into `~/.hx/bin/build/runtime.a`, fresh link → the new
binary references `libc_calloc` and the constant-size `farr_matmul`+`free` loop
holds **flat at 5.2 MB** (was 30.3 GB).

### Likely graduation locus
`self/runtime.c` is a gitignored graduated build asset, so this report is the
committable channel (no committable C emitter for the farr bodies). A maintainer
with the runtime-graduation pipeline should fold the diff above and re-stage
`runtime.a`. Consider also: a broader `hxlcl_free` that actually reclaims (the
bump allocator could free its top chunk on LIFO frees), or a `farr_zero_n(buf,n)`
in-place primitive so callers can reuse a preallocated buffer (the downstream
anima decode already does preallocate-and-reuse to cut total allocations, but the
residual per-call `farr_matmul` outputs still need a reclaiming free).

## Downstream mitigation already shipped (anima)
`core/bytegpt_decode.hexa` now preallocates the forward scratch ONCE at block-size
and reuses it across the generated bytes (`bg_forward_last_W_s` + constant-block
GEMM), byte-identical (parity maxabs=0). That cuts allocation **count** sharply but
cannot eliminate the leak while `free` is a noop — the real fix is this runtime
change.
