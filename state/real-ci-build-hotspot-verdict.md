# REAL CI release-build compile-time hotspot — profiled verdict

**Date:** 2026-06-25 · **Host:** summer (summer-B650M-K, 12c, Linux x86_64, gcc 14 / clang 18)
**Why:** the prior 94.79%-`hexa_val_heapify` number was captured profiling `tool/build_native_linux_x86_64`
(the `cc_native` native-backend path at **-O1**). The ACTUAL CI "Build" step runs `tool/release_build`
(the faithful C-transpile path at **-O2**) — a different codepath. This profiles the RIGHT build.

---

## 1. The exact build the CI "Build" step runs

`.github/workflows/release.yml` — every release/test job's "Build" step is:

> `run: bash tool/release_build`  (release.yml:145 darwin · :281 linux-x86_64 · :342 linux-arm64)
> env: `TARGET` · `CC` (gcc/clang) · `LIBS` · `HEXA_SEED_CONVERGE: "1"` · `HEXA_BUILD_VERSION`

`tool/release_build` (release_build:85-99) composes four stage scripts in order:
1. Stage 0b `tool/stage_resolve_runtime_a` → `build/runtime.a` (gcc -O2 of `self/runtime.c` amalgam)
2. Stage 0a-pre `tool/stage_prebuild_hexat` → `build/hexat` (gcc -O2 of `self/native/hexa_cc.c`, ~2.1 MB C)
   — **plus the `HEXA_SEED_CONVERGE=1` loop** (stage_prebuild_hexat:137-161) which regens the seed via the
   hexa transpiler and **rebuilds hexat 2× to fixpoint**.
3. Stage 0a `tool/stage_regen_hexa_cc` (no-op while seed present)
4. Stage 0/1/2 `tool/stage_build_hexa`:
   - **Stage 0** (stage_build_hexa:143): `gcc -O2 self/native/hexa_cc.c runtime.a -o build/hexa_v2`
   - **Stage 1** (stage_build_hexa:148-162): run `hexa_v2`/`hexa_module_loader` to **transpile**
     `self/main.hexa` → `build/stage1/main.c` (the hexa transpiler doing the heavy single-thread emit)
   - **Stage 2** (stage_build_hexa:165): `gcc -O2 build/stage1/main.c runtime.a -o hexa`

**-O level: -O2** for every C compile (`CFLAGS_COMMON="-O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs"`,
release.yml:58 / release_build:55).

## 2. Reproduce + profile (exact command profiled)

Faithful reproduction in isolated `/tmp/ci-profile-530001` on summer, CPU-only runtime.a (no CUDA),
env identical to the CI linux-x86_64 job:

```
TARGET=linux-x86_64 CC=gcc LIBS="-lm -ldl" HEXA_SEED_CONVERGE=1 HEXA_BUILD_VERSION=test \
HEXA_PREBUILT_RUNTIME=$WORK/build/runtime.a CFLAGS_COMMON="-O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs" \
bash tool/release_build
```

### Whole-build wall + RSS (`/usr/bin/time -v`, no perf)
- **Elapsed wall: 4:42.67 (282.7 s)** · **User: 280.36 s** · **CPU: 99% (single-thread)**
- **Peak RSS: 913,084 kB (~892 MB)** · Exit 0
- (Blacksmith 4-vcpu runner's ~15.2 min is ~3.2× this 12-core box — consistent hardware ratio.)

### Per-stage wall (from per-line timestamps)
| step | wall | what runs |
|---|---|---|
| Stage 0b runtime.a | ~3.6 s | gcc -O2 amalgam |
| Stage 0a-pre seed-converge pass 1 | 48.6 s | gcc -O2 hexat **+ hexa-transpiler regen** |
| seed-converge pass 2 | 27.8 s | gcc -O2 hexat **+ hexa-transpiler regen** |
| Stage 0 compile hexa_v2 | 26.5 s | gcc -O2 `hexa_cc.c` |
| **Stage 1 transpile main → main.c** | **154.6 s** | **hexa transpiler (flatten 44s + `hexa_v2` expanded→main.c ~110s)** |
| Stage 2 compile main.c | 20.3 s | gcc -O2 generated `main.c` |

**The dominant sub-step = Stage 1 hexa-transpiler emit (154.6 s = 55% of the whole build).** Pure gcc -O2
compiles (Stage 0 hexa_v2 26.5 s + Stage 2 main.c 20.3 s = 47 s) are NOT the bottleneck.

### perf-record of the live Stage-1 `hexa_v2` transpiler (99,741 samples, 25 s window)

`perf record -g -p <hexa_v2 expanded→main.c PID> -- sleep 25`

**Top-10 SELF-time (`perf report --no-children`):**
| % self | symbol |
|---|---|
| 42.38% | `__blk_data` |
| 13.60% | `__blk_cap` |
| 12.38% | `__blk_next` |
| 11.04% | `BLOCK_HDR` |
| **9.89%** | **`hexa_val_heapify`** |
| 8.95% | `hexa_add_slow` |
| 0.53% | `hexa_arena_rewind` |
| 0.30% | `rt_truthy_native` |
| 0.24% | `hexa_eq` |
| 0.20% | `__blk_set_used` |

**Inclusive (`--children`):** `hexa_val_heapify` = **85.64%** (self 9.89%); `__blk_data` 63.69%, `__blk_cap`
40.58%, `__blk_next` 37.13%, `BLOCK_HDR` 15.93% — **all are children of `hexa_val_heapify`** (call-graph
confirms `__blk_next → hexa_val_heapify`, `__blk_data → hexa_val_heapify`, etc.).

## 3. Comparison to the -O1 native profile (heapify = 94.79%)

**SAME root cause, different attribution shape.** At -O1 (`cc_native`) gcc inlined the arena block-walk
helpers into `hexa_val_heapify`, so it showed as a single 94.79% self-time symbol. At **-O2 (faithful CI
path)** gcc keeps `__blk_data`/`__blk_cap`/`__blk_next`/`BLOCK_HDR` as separate out-of-line functions, so the
self-time spreads across them — but the **inclusive** profile re-collapses it: **`hexa_val_heapify` is 85.64%
of the Stage-1 transpiler**, and the block-walkers are its callees. The heapify arena deep-copy still
dominates the REAL -O2 CI build.

**Source:** `self/runtime_core_emit.hexa:4930` emits the `hexa_val_heapify(HexaVal v)` body into
`self/runtime_core.c` (the arena value-promotion deep-copy). The `__blk_*`/`BLOCK_HDR` block-walk primitives
are emitted near runtime_core_emit.hexa:1664-1697.

## 4. VERDICT

**The REAL -O2 CI bottleneck is `hexa_val_heapify` (85.64% inclusive of the Stage-1 transpiler, which is 55%
of the 282 s build) — the SAME arena-escape deep-copy the -O1 profile found (94.79% inlined). Escape-analysis
to elide the heapify deep-copy is the justified MAJOR lever; no cheaper different-symbol win is hiding on the
faithful path (gcc -O2 of the amalgams is only ~47 s / 17%). Secondary cheap multiplier: the
`HEXA_SEED_CONVERGE=1` loop runs the heapify-heavy transpiler 2 extra times (76 s) — any heapify win compounds
across it.**
