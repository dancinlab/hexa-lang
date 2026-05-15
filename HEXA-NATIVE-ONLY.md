<!-- @created: 2026-05-13 -->
<!-- @updated: 2026-05-13 (breakthrough-axis exhaustive brainstorm) -->
<!-- @scope: roadmap — eliminate per-RFC C kernels, reach perf parity in pure hexa AOT -->
<!-- @authority: derived from RFC 032/033/034/035 native-kernel pattern -->
---
type: native-only-roadmap
session: 2026-05-13
target: hexa AOT codegen — typed scalar lane for farr + vectorize/blocking/parallel/memory axes
blocks: future RFC 036+ "native C kernel" escalations
---

# HEXA-NATIVE-ONLY.md — drop C kernels, reach parity in pure hexa

> **Question**: Each new ML hot-path lands as a C kernel in `self/runtime.c`
> (RFC 032 matmul / 033 gaussian / 034 pauli / 035 NM-step). Can the same
> performance be reached **without** the C kernel — pure hexa source
> compiled by hexa AOT?

> **Update 2026-05-13** — initial doc covered §2 (typed-farr lane) + §4
> (vectorize for matmul). Brainstorm-to-exhaustion pass expands axes A–H
> below and re-prioritises the plan as a phased capability matrix rather
> than a single P-1…P-5 chain.

---

## §1 Root cause — why every hot path needs a C kernel today

The interpreter and the AOT codegen both lower a farr scalar access into a
HexaVal-boxed function call:

```
self/runtime.c:7625        return hexa_float(e->buf[i]);             // boxing
self/codegen_c2.hexa:4117  "hexa_farr_get(" + arg[0] + ", " + arg[1] + ")"  // AOT lowering
```

Every `farr_get(h, i)` / `farr_set(h, i, x)` allocates a tagged-union
`HexaVal` (~12–88 B per scalar op per `self/runtime.c:8462` comment).

Consequences observed in production:

| RFC | Symptom without C kernel | Arena pressure |
|-----|---------------------------|----------------|
| 032 | pure-hexa matmul 1024² → ~2³⁰ MAC | ~100 GB extrapolated |
| 034 | Pauli loop (UCCSD-4e/4o, 26-dim NM) | 768 MB cap exceeded |
| 035 | NM step (centroid/reflect/blend/sort) | 768 MB cap exceeded |

All four RFCs use the same workaround: write the whole loop in C, route a
single builtin call through `hexa_callN`, return one HexaVal at the end.

This is a **codegen issue, not a language issue.** The hexa surface
syntax can already express every kernel — `for j in 0..n { c[j] = a[j] +
s * (a[j] - b[j]) }` is valid hexa. What is missing is the *lowering* to
raw `double*` arithmetic, and a chain of follow-on optimizations.

---

## §2 Breakthrough axis catalog — exhaustive

vectorize/cache blocking is one axis. There are seven more siblings.
Every axis below is a separate "C kernel can drop after this lands" gate.
Order inside a category is rough cost-of-implementation, ascending.

### A. Unboxing / type lane (foundation — required by everything else)

| # | Axis | What it lowers | C-drop impact |
|---|------|----------------|---------------|
| A1 | Typed scalar lane: `farr_get → f64` direct load | `_hx_farr_table[h].buf[i]` inline | RFC 035 + half of 033/034 |
| A2 | Typed array lane: `farr` handle → typed `double*` local | hoist `buf` once per loop | all elementwise |
| A3 | HexaVal unboxing inference (escape analysis on small locals) | stack-allocate or scalarise | inner-loop temps |
| A4 | Generic monomorphisation (specialize on element type) | per-type emit | conv / quant lanes later |
| A5 | Bounds-check elimination (interval analysis on loop index) | drop `i >= len` per iter | inner-loop branch removal |
| A6 | Type-state: farr-validity proved at entry, no per-iter recheck | drop `if !e->buf` per iter | every farr loop |
| A7 | Pure-function detection → CSE eligibility | reuse expr across iters | reductions / conv |

### B. Mid-level / loop optimisation

| # | Axis | What it lowers | C-drop impact |
|---|------|----------------|---------------|
| B1 | Loop-invariant code motion (LICM) | hoist `a[i*K + k]` etc. | matmul-ish |
| B2 | Loop interchange (`ijk → ikj` autodetect) | row-major friendly order | matmul |
| B3 | Loop fusion (adjacent elementwise) | reflect + blend → one pass | NM step |
| B4 | Loop fission (split into vectorizable + scalar) | unblock §C vectorizer | mixed bodies |
| B5 | Loop unrolling (4×, 8× automatic) | clang fma matchup | matmul / Pauli |
| B6 | Unroll-and-jam (outer unroll + inner roll) | register tiling prelude | matmul |
| B7 | Strip-mining (n → outer×inner) | tiling precondition | matmul / batched ops |
| B8 | Reduction recognition (sum/max/min) | parallel-reduction emit | dot, norm, expectation |
| B9 | Strength reduction (mul → add recurrence) | index arith cheap | every loop |
| B10 | Software pipelining | hide latency | high-IPC FMA loops |
| B11 | Polyhedral framework (Pluto-style affine) | auto interchange + tile | matmul / conv |

### C. Vector / SIMD

| # | Axis | What it lowers | C-drop impact |
|---|------|----------------|---------------|
| C1 | Loop auto-vectorizer (innermost) | SSE/AVX/NEON | every elementwise |
| C2 | SLP vectorizer (straight-line) | group adjacent scalars | small kernels |
| C3 | Horizontal reductions (hsum, hmax) | shuffle + add | reductions |
| C4 | FMA emit recognition (`a + s*(b - a)`) | `vfmadd…` | NM blend/reflect, matmul |
| C5 | Mask/predicate lanes (AVX-512, SVE) | tail-loop fold-in | non-multiple-of-VL |
| C6 | Gather/scatter (stride > 1, indirect) | non-unit-stride access | column reads |
| C7 | Multi-versioned dispatch (AVX2 / AVX-512 / NEON / SVE2) | runtime CPUID fan-out | portable hot binaries |
| C8 | Tensor core / AMX / TMUL pattern matching | `vamx_` / `mma.sync` | matmul (Tier-2) |
| C9 | Winograd / im2col conv pattern | per-shape lower | future conv RFCs |
| C10 | BLAS-shape detection → vendor fallback | dgemm / sgemv | matmul opt-out |

### D. Memory / allocator

| # | Axis | What it lowers | C-drop impact |
|---|------|----------------|---------------|
| D1 | farr pool / free-list (reuse handle, no realloc) | malloc churn → 0 | RFC 033 (gaussian temp), NM step temps |
| D2 | Arena / region (lifetime = function) | one bump-pointer | inner-loop allocs |
| D3 | `@align(64)` enforcement | aligned SIMD load | §C unlocks |
| D4 | Cache prefetch emit (`__builtin_prefetch`) | latency hiding | streaming loops |
| D5 | Non-temporal stores (`_mm_stream_pd`) | don't pollute cache | write-once outputs |
| D6 | Cache blocking / tiling (L1, L2 differentiated) | reuse | matmul, conv |
| D7 | Huge pages (2 MB / 1 GB) | TLB pressure | large farr |
| D8 | NUMA-aware first-touch | local node | multi-socket only |
| D9 | False-sharing-aware struct layout | pad to cache line | concurrent reductions |
| D10 | Write-combining buffers | streaming stores | output-heavy kernels |

### E. Parallelism

| # | Axis | What it lowers | C-drop impact |
|---|------|----------------|---------------|
| E1 | `@parallel for` → thread pool | data parallel | NM (per-vertex eval), matmul outer |
| E2 | Work-stealing scheduler (Cilk-like) | load imbalance | recursive / nested |
| E3 | Reduction primitives (lock-free `+=`) | parallel sum | dot, norm |
| E4 | Heartbeat / coarsening | fork-join overhead | small inner loops |
| E5 | GPU offload (`@gpu` already partial via hxmetal/hxcuda) | kernel launch | matmul, conv |
| E6 | Tensor parallel (multi-GPU split) | per-rank | large LM |
| E7 | Async copy + compute overlap | latency hide | host↔device |
| E8 | Persistent kernel (no relaunch) | repeated small ops | NM inner loop on GPU |
| E9 | Cooperative-groups / warp reduce | sub-warp sync | reduction on GPU |

### F. Codegen / backend

| # | Axis | What it lowers | C-drop impact |
|---|------|----------------|---------------|
| F1 | Inline expansion (cross-module, cost-model) | call → body | small helper churn |
| F2 | Devirtualization (after type narrowing) | direct call | dispatch overhead |
| F3 | Tail-call optimisation | recursion → loop | functional style |
| F4 | Branch prediction hints (`@likely`/`@unlikely`) | reorder hot path | guarded loops |
| F5 | Cold/hot section split | i-cache | startup / error paths |
| F6 | Register allocator quality (graph colour vs LSRA) | spill reduction | fma-heavy inner |
| F7 | Calling convention tuning (regparm, sysv-only) | arg passing | hot leaf calls |
| F8 | LTO / WPO | inline across files | whole binary |
| F9 | PGO (profile-guided) | layout + inline thresholds | warm binaries |
| F10 | Inline asm escape hatch (`@asm`) | last-resort intrinsics | per-CPU peaks |

### G. Strategic / higher-order

| # | Axis | What it lowers | C-drop impact |
|---|------|----------------|---------------|
| G1 | Operator fusion (kernel-level, XLA-style) | sequence → single pass | training graphs |
| G2 | Algebraic simplification | `a*0`, `x+0`, `x*1` | scalar arith |
| G3 | Pattern-rewrite library (matmul, gemv, dot, norm) | recognise + lower | every named pattern |
| G4 | Cost model / autotuner | which tile size / dispatch | matmul, conv |
| G5 | JIT tier (warm function recompile with PGO) | second-pass opt | long-running ML |
| G6 | Partial evaluation / specialisation on const args | n_qubits=4 burnt-in | RFC 034 |
| G7 | Whole-program devirt + monomorphise | flatten dispatch | bridge code |
| G8 | Domain-specific intrinsics (`@nm_step`, `@pauli_exp`) | macro → tiled body | the RFC pattern reified |

### H. Domain-specific (qmirror / anima / future ML RFCs)

| # | Axis | Pattern | C-drop impact |
|---|------|---------|---------------|
| H1 | Pauli operator-specific lane | flip/z/y mask traversal | RFC 034 |
| H2 | Nelder-Mead step macro | centroid + reflect + blend + sort | RFC 035 |
| H3 | Adam / SGD fused step | gradient + moment update | optimizer loops |
| H4 | Attention pattern (QKV + softmax + matmul) | fused kernel | LM forward |
| H5 | RMSNorm / LayerNorm fused | reduction + scale + bias | LM forward |
| H6 | Quantization lanes (INT8 / FP8 / BF16) | typed lane variant | future RFC |
| H7 | Sparse-matrix patterns (CSR / COO) | indirection lane | future RFC |
| H8 | Gaussian / Box-Muller intrinsic | trig + log fused | RFC 033 |

---

## §3 Per-RFC verdict — which axes each kernel needs to drop C

| RFC | Kernel | Required axes | C-drop class |
|-----|--------|---------------|--------------|
| 032 | farr_matmul | A1 + A2 + A5 + B1 + B2 + B5 + B6 + B7 + C1 + C4 + D3 + D6 (+ G3/G4 for autotune) | **Tier-2** (vectorize + tiling + pattern recognition) |
| 033 | farr_copy | A1 + A2 + A5 + C1 | **Tier-0** (typed lane + clang -O2 alone) |
| 033 | farr_add_gaussian_noise | A1 + A2 + C1 + (H8 optional for trig fuse) | **Tier-1** (typed lane + small trig fuse) |
| 034 | farr_pauli_exp_inplace / expectation | A1 + A2 + A6 + B8 + C1 + C4 + (G6 const-spec on n_qubits) | **Tier-1** |
| 035 | farr_simplex_centroid | A1 + A2 + B8 + C1 + C3 | **Tier-0** |
| 035 | farr_vec_reflect / vec_blend | A1 + A2 + C1 + C4 | **Tier-0** |
| 035 | farr_vertex_copy / simplex_get / simplex_set | A1 + A2 | **Tier-0** |
| 035 | farr_simplex_shrink | A1 + A2 + C1 + C4 | **Tier-0** |
| 035 | farr_simplex_sort (insertion) | A1 + A2 + F4 | **Tier-0** |

**Tier-0** = `A1` + `A2` alone (+ trust clang `-O2`). The first kernel to
drop. RFC 035 is almost entirely Tier-0.

**Tier-1** = Tier-0 + at least one axis from §B/§C (FMA pattern, reduction,
trig fuse, const-specialisation). Most of RFC 033/034.

**Tier-2** = Tier-1 + tiling/pattern recognition (matmul). RFC 032 only.

---

## §4 Phased plan — capability gates, not a linear chain

Each gate ships one capability and immediately retires one or more C
kernels behind a bench fixture in `self/bench/`.

| Gate | Capability shipped | Axes | RFCs retired |
|------|--------------------|------|--------------|
| **G-0** | Typed-farr lane on inner loops | A1 + A2 | RFC 035 trivial half (vertex_copy / simplex_get/set) |
| **G-1** | Hoist + LICM + bounds-elim for typed loops | A5 + A6 + B1 | RFC 035 elementwise (centroid / reflect / blend / shrink / sort) |
| **G-2** | Pattern-match FMA + reduction shape | B8 + C4 + C3 | RFC 034 (Pauli exp + expectation) |
| **G-3** | Alignment + auto-vectorize gate | D3 + C1 | confirms G-1/G-2 hit SIMD; locks elementwise win |
| **G-4** | Const-specialisation on n_qubits / n / VL | G6 | RFC 034 final tail |
| **G-5** | farr pool + arena lifetimes | D1 + D2 | RFC 033 gaussian-noise temps |
| **G-6** | Cache blocking + unroll-and-jam | B6 + B7 + D6 | RFC 032 matmul Tier-2 entry |
| **G-7** | BLAS-shape pattern lib + autotuner | G3 + G4 + (G3-vendor optional) | RFC 032 matmul Tier-2 exit |
| **G-8** | `@parallel` thread pool | E1 + E3 + E4 | NM per-vertex parallel eval |
| **G-9** | GPU lane refinement (`@gpu` complete) | E5 + E7 + E8 | matmul + future conv RFCs |
| **G-10** | LTO + PGO + cold/hot split | F4 + F5 + F8 + F9 | binary-wide win, no per-RFC retire |
| **G-11** | Domain macros (`@nm_step`, `@pauli_exp`) | G8 + H1 + H2 | future RFC 036+ pre-empt |

Critical-path summary:

```
G-0 → G-1 → (G-2 ∥ G-5) → G-3 → G-4   ← retires RFC 033/034/035
G-1 → G-6 → G-7                       ← retires RFC 032
G-3 → G-8/G-9                         ← parallel/GPU
G-1 → G-10                            ← whole-binary perf
G-1 → G-11                            ← pre-empts the next "RFC = C kernel" cycle
```

Exit criterion per gate: bench fixture under `self/bench/` showing
pure-hexa kernel within ±10 % of the C kernel on the RFC's reference
workload, then `git rm` of the kernel body (keep declaration as
historical comment only).

---

## §5 Anti-patterns — what NOT to do

- **Do not add RFC 036+ "yet another whole-loop C kernel" without
  checking G-0/G-1 first.** If a future kernel is elementwise and G-1 is
  shipped, the C kernel is dead weight on day one.
- **Do not block elementwise wins on Tier-2 work.** G-0 + G-1 retire 75 %
  of the existing C-kernel inventory; matmul (Tier-2) can stay until G-7.
- **Do not generalise the typed lane to all `HexaVal` types before
  shipping G-0.** Scope creep kills the change. `farr_get → f64` and
  `farr_set(*, *, f64)` is enough for the first cut.
- **Do not skip the bench fixture.** Without a measured ±10 % parity gate,
  C-kernel retirement is a vibe, not a verdict.
- **Do not bundle G-7 (BLAS-shape) and G-9 (GPU).** Matmul has two
  separate ceilings (CPU SIMD vs GPU); conflating them blocks shipping
  either.
- **Do not let `@gpu` skew the elementwise priority.** GPU is great for
  matmul / conv but adds copy-in/copy-out overhead that kills small NM /
  Pauli step kernels.

---

## §6 Verification anchors (LATTICE_POLICY.md §1.2 alignment)

This roadmap is bounded by real limits, not lattice fit:

- **Memory bandwidth** (DDR4-3200 ≈ 25.6 GB/s per channel) — elementwise
  axes are bandwidth-bound; §C alone caps the win at 1× memory speed.
- **Cache reuse** (L1 ≈ 32 KB, L2 ≈ 256 KB–1 MB) — §D6 tiling is the
  only path past bandwidth wall for compute-bound (matmul ≥ N²·N).
- **SIMD width** (AVX-512 = 8× fp64, NEON/SVE = 2–4× fp64) — §C1 ceiling
  is VL; FMA (§C4) doubles it.
- **Thread / core count** (Apple M-series 8–12 perf cores) — §E1 ceiling.
- **GPU FLOPS / HBM bandwidth** — §E5 / §G3 ceiling; not a hexa
  invariant, must be cited per device.

Per LATTICE_POLICY.md §1.2, every claim above can be falsified by a
bench that fails to reach within an order-of-magnitude of these limits.

---

## §7 References

- RFC 032 — `farr_matmul` native builtin (`inbox/rfc_drafts_2026_05_12/rfc_032_farr_matmul_native_builtin.md`)
- RFC 033 — `farr_copy` + Gaussian noise (`inbox/rfc_drafts_2026_05_12/rfc_033_farr_copy_and_gaussian.md`)
- RFC 034 — Pauli kernels (in-source, `self/runtime.c:7814`; no markdown draft yet)
- RFC 035 — NM-step kernels (in-source, `self/runtime.c:7987`; no markdown draft yet)
- Codegen surface — `self/codegen_c2.hexa:4117` (farr_get) / `:4138` (farr_set)
- Native registration — `self/runtime.c:10103` (farr_get) / `:10122` (RFC 035 cluster)
- AOT-level annotation work — `self/ai_native/ai_native.json` (`@prefetch`, `@align` `done` markers — verify scope before duplicating §D3/D4 work)
- GPU lane partial — `self/native/hxmetal_macos.m`, `self/native/hxcuda_*.cu`, `self/native/hxccl_linux.c`
- Bytecode VM (alternative perf path, lower priority) — `self/bc_emitter.hexa`, `self/bc_vm.hexa`
- Limit policy — [`LATTICE_POLICY.md`](LATTICE_POLICY.md) §1.2 (real-limits taxonomy)
- Project limits audit — [`LIMIT_BREAKTHROUGH.md`](LIMIT_BREAKTHROUGH.md) (parsing class, type expressiveness, target reach)
