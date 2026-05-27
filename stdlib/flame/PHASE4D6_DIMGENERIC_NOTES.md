# Phase 4-D-6 — dimension-generic A2 primitives

**Goal**: one A2 primitive set that builds for BOTH the d=32·3L byte-eq
baseline AND the d=768·12L GPU-fire target — so the d768 fire is no longer
blocked on hand-translated `T16_d32_nh4_nkv2_h64`-specialized C.

**Status**: LANDED (Mac, $0). d=32·3L byte-eq STRICT PASS. d=768·12L A2
trainer `.c` generated + builds clean (no-CUDA + `-DHEXA_CUDA` syntactic).

---

## 1. Approach picked — A (parameterize), not B (emitter)

The task offered two routes:
- **A — parameterize**: dims become runtime `fn` arguments.
- **B — emitter**: a tool emits a dim-specialized `.c` per config tuple.

**Picked A.** The honest reason emerged on reading the primitives:

The dim *literals* were never the hard part. `flame_proj_matmul_dispatch`
(Phase 4-D-5-2) was **already** runtime-generic — `M, K, N` as args. The
real blocker is **stack buffer sizing**. The 8 d=32 matmul wrappers used
fixed-size *stack* arrays:

```c
double xbt[32*16], Wbuf[32*32], C[32*16];   // d=32 wrapper
```

At d=768 `Wbuf` is `768·768·8 = 4.7 MB` on the stack — a guaranteed
overflow. An emitter (B) still has to solve heap-vs-stack; it would just
emit a different literal. It buys nothing over A and adds a codegen tool +
N specialized `.c` files to maintain. A also vectorizes fine: clang -O2
keeps the `i/k/j` matmul nest tight with runtime dims (the Phase 4-D-5-2
dispatch core already proved this — it is the identical function).

So A is both cleaner and the genuine fix. The genericization is two-fold:
1. dims `const int` → `fn` arguments;
2. oversized stack scratch → heap `farr` allocations.

## 2. What changed

Three new primitive files (the d=32 `flame_phase4b3_*` files are left
intact — additive, no edit to the SHIPPED d=32 path):

| new file | replaces (d=32-baked) | generic surface |
|---|---|---|
| `tool/flame_phase4d6_matmul_primitives.c` | `flame_phase4b3_matmul_primitives.c` (8 wrappers) | `flame_proj_batch_generic_primitive` + `flame_grad_accum_generic_primitive` — `(…, int T, int d_out, int d_in)` |
| `tool/flame_phase4d6_block_fwd_primitive.c` | `flame_phase4b3_block_fwd_primitive.c` | `flame_block_generic_fwd_primitive(…, int T,int d,int nh,int nkv,int h)` |
| `tool/flame_phase4d6_block_bwd_primitive.c` | `flame_phase4b3_block_bwd_primitive.c` | `flame_block_generic_bwd_primitive(…, int T,int d,int nh,int nkv,int h)` |

Plus a dim-agnostic build pipeline `tool/flame_phase4d6_a2_build.sh`.

### 2.1 Offsets — computed, not baked

The d=32 primitives baked every Bp/Bc layout offset as a literal
(`WQ=32 … oR2inv=8720`). The generic primitives compute them from the
`bp_off_*` / `bc_off_*` formulas in `decoder_block_lib.hexa:49-106`. The
formula port was **verified to reproduce the d=32 literals exactly** before
any build (`G1=0 WQ=32 WK=1056 WV=1568 WO=2080 G2=3104 WG=3136 WU=5184
WD=7232`; `oXout=0 … oR2inv=8720`).

### 2.2 Scratch buffers — stack → heap

| buffer | d=32 (stack) | d=768 (would be) | now |
|---|---|---|---|
| matmul `Wbuf` | `32·32` = 8 KB | `768·768` = 4.7 MB | heap `farr` |
| matmul `xbt` / `C` | small | `1024·768` = 6 MB | heap `farr` |
| fwd `q_scratch` | `[8]` | `[64]` | heap `farr` |
| fwd `srow_at` | `[16]` | `[1024]` | heap `farr` |
| bwd `ds/da/db_pos_st` | `[64]`×3 | `[3072]`×3 | heap `farr` |
| bwd `dP_row` | `[16]` | `[1024]` | heap `farr` |

All scratch moved to `hexa_call1(farr_zeros, …)` / `farr_free`. Uniform
across configs — no size-threshold branch (a threshold would be a second
code path to keep byte-eq on; uniform heap is simpler and provably safe).

## 3. Byte-eq preservation (F-RFC047-A2-PATHB-FULL-BYTE-EQ — STRICT)

The d=32·3L `verify_all` battery (26/26) is the strict gate. Three
guarantees, all respecting PHASE4C audit §6 R1 (no reduction reorder):

1. **`flame_proj_matmul_dispatch_g` is the identical function** — same
   `i/k/j` loop nest, same `C[i*N+j] += aik*B[k*N+j]` accumulation order
   as the d=32 `flame_proj_matmul_dispatch`. Only renamed `_g` to avoid a
   duplicate-symbol clash.
2. **Block-primitive loops are byte-copied** from the d=32 `flame_phase4b3`
   primitives. Only the literal dims (`16,32,4,2,64`) became variables and
   scratch arrays moved stack→heap. Loop *bounds* change value but not
   *structure* — for the d=32 config the executed fp-op sequence is
   identical.
3. **Heap vs stack is invisible to the arithmetic.** The inline matmul and
   every reduction read/write purely by `double*`; double arithmetic is
   bit-identical regardless of storage class.

**One required correctness fix** (not a byte-eq risk): the generic matmul
primitives call `farr_zeros`, which may `realloc()` `_hx_farr_table`,
moving every entry. The d=32 primitives used *stack* matmul buffers, so the
table never moved mid-block and the old code did not re-fetch e.g. `X`
before section 6. The generic primitives re-fetch every dereferenced
pointer by id after each allocation (the use-after-realloc pattern already
documented in `runtime.c` `hexa_farr_matmul` and `flame_proj_gpu_matmul`).
This changes pointer freshness only — zero fp-op change.

**Verdict — d=32·3L:** `flame_phase4d6_a2_build.sh` →
`F-RFC047-A2-PATHB-FULL-BYTE-EQ` PASS, output byte-identical with
`/tmp/baseline.out`. Full `verify_all` 26/26 re-run: see §5.

## 4. d=768·12L

`flame_phase4d6_a2_build.sh stdlib/flame/flame_d768_12L_corpus_test.hexa`
generates `build/artifacts/flame_d768_12L_corpus_test_d6_a2.c` and builds
it clean under clang -O2. The d=768 trainer **must not run on the M-Mac**
(~10 GB resident, per the source header) — it is build-only here; the run
is the pre-approved next-step GPU fire.

The `-DHEXA_CUDA` branch routes large matmul shapes (`d_out·d_in` > 8192)
to `hexa_farr_matmul_gpu` (cuBLAS Dgemm) via `flame_proj_gpu_matmul_g`. On
a no-CUDA Mac the GPU symbols are absent, so `-DHEXA_CUDA` is verified by a
syntactic compile (`clang -c`), not a full link — the link happens on the
GPU host.

## 5. Build pipeline — `flame_phase4d6_a2_build.sh`

Dim-agnostic successor to `flame_phase4b3_a2_build.sh`. The one place the
old pipeline hardcoded d=32 was the call-site sed (step 3.6 of
`flame_phase4b3_build.sh` + step 3.9 of `flame_phase4b3_a2_build.sh`). The
IPCP rewriter already constant-folds the top-level `(T,d,nh,nkv,h)` tuple
into each call site as `hexa_int(<lit>)`, so the generic sed captures the
farr args **and** the 5 dim literals and forwards both — works for any
config with no per-config program.

POSIX-sed gotcha handled: backreferences stop at `\9`, so a 10/13-group
regex would mis-bind `\10`. The dim tail is captured as one group, then a
second pass unwraps `hexa_int(N)` → `N` on the generic-primitive lines.

## 6. Honest caveats

- **d=768 is build-verified, not run-verified** on the Mac — by design
  (memory ceiling). Numerical correctness at d=768 is established only
  once the GPU fire runs. The build proves: dims thread through, offsets
  compute, no stack overflow, clang accepts the generic C.
- **Heap-allocation overhead**: the generic primitives do ~6-9 extra
  `farr_zeros`/`farr_free` pairs per block call vs the d=32 stack version.
  At d=32 this is a measurable (small) regression in the A2 wall-time
  micro-measurement — byte-eq is unaffected, but the d=32 *speed* claim
  from Phase 4-B-3 (2.74×) should be re-measured if d=32 perf is reported
  again. At d=768 the alloc cost is negligible against the matmul cost.
- **No SMEM / cache-farr sizing issue surfaced.** The d768 concern flagged
  in the task (cache farr sizing, SMEM limits) did not bite at the A2
  build tier: `mc_total`/`m_total` are computed in the hexa source and the
  primitives only index into already-allocated `Bc`/`Bp`. SMEM limits are
  a GPU-kernel concern (forge scope), out of scope for these CPU/cuBLAS-
  dispatch A2 primitives.
- **`-DHEXA_CUDA` is syntactic-only on Mac** — the GPU code path's runtime
  behavior is unverified until the GPU fire.

## 7. Next

d=768·12L GPU fire (pre-approved, separate step): build with `--cuda` on
the GPU host, link the CUDA runtime, run the 20-step trainer, capture
`F-RFC046-D768-RUN` + `F-RFC046-EAGER-PYTORCH-MATCH`.
