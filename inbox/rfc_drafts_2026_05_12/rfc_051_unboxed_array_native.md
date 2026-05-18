# RFC 051 — `uarr`: unboxed packed-scalar transient array primitive (boxed-array allocator overhead structural fix)

- **Status**: design-draft (2026-05-17) — DESIGN ONLY, no implementation
- **Date**: 2026-05-17
- **Severity**: HIGH (pure-hexa hexa-cpu LM-scale training의 substrate
  inflation 천장 — boxed-array transient allocator overhead 2.8×
  inflation 으로 d≥96 ladder 가 503 GiB cloud 도 27% 점유. Mac 24 GiB /
  ubu 38 GiB 둘 다 OOM ceiling 위에 직접 책임.)
- **Priority**: P1 for the pure-hexa hexa-cpu LM-scale ceiling (boxed-array
  hot path 가 `d_train5_lib.hexa` 의 transient AdamW + RoPE + attention
  inner loop 의 *구조적* 비효율 — RFC 042 의 control-flow 천장과 직교).
  RFC 040/041/042/043/044 가 GPU/compiler 천장을 닫는 동안, RFC 051 은
  CPU-side allocator-inflation 천장을 닫는다.
- **Source convergence**: anima `docs/hexad_pure_hexa_d96x3_substrate_fix_2026_05_17.md`
  + `state/hexad_pure_hexa_train_d96x3_2026_05_17/blue_substrate_falsifier.py`
  — vast.ai 503 GiB cloud substrate fix 의 carry: **OPERATIONAL substrate
  fix (host capacity ↑) NOT algorithmic** — 본 RFC 가 그 algorithmic
  structural counterpart.
- **Source evidence (g3 — every claim anchored to a capture)**:
  - anima ubu agent `state/hexad_pure_hexa_train_d96x3_2026_05_17/result.json`
    + 위 doc §3 table — d=96·3L pure-hexa AdamW transient peak
    **predicted = 27 GiB** vs **observed = 76 GiB @ step 100 / ≈137 GiB
    @ step 200** on vast.ai Quadro P4000 host (Xeon E5-2690).
    **Inflation ratio ≈ 2.8× (76/27)** at step 100, growing toward
    137/27 ≈ 5.1× near step 200.
  - 같은 doc §6.1: *"the pure-hexa interpreter boxed-array allocator
    overhead still scales nonlinearly with `d` (the structural fix is
    HEXA_NATIVE Phase 4 unboxed arrays …, both separate work threads)"*
    — 즉 OPERATIONAL host fix 가 *아니라* RFC 051 의 algorithmic
    structural fix 가 본 inflation 의 close 경로.
  - anima d=128·4L Mac substrate carry — 동일 trainer 가 step 51 에
    **138 GiB peak alloc** (Mac 24 GiB 위 6× overshoot, OOM-bound).
    동일 boxed-array hot path 의 d-scaling.

## Scope of this RFC — DESIGN DRAFT, honest framing

본 RFC 는 **design document only**. 어떤 self/runtime.c / interp / codegen
edit 도 본 RFC 가 추가하지 않는다. 본 RFC 는 (a) anima Phase 4 transient
boxed-array hot path 의 algorithmic 천장을 명세, (b) 신규 unboxed packed-
scalar primitive `uarr` 의 surface, (c) 검증 falsifier 사전등록만 land.
구현은 hexa-lang side 의 별도 cycle (RFC 051 land 후) 이고 multi-step:
runtime 구조체 + interp built-in dispatch + codegen 매핑.

g3 (verification-anchor-real-limit) + g_blue_closed_mandate 준수:
산출물 inequality + connection-point byte-equality 둘 다 closed-form
anchor (Kolmogorov bytes + IEEE 754 float-bit equality, NO lattice).
g3 정직: 50% memory reduction 추정은 *expected* 표기 — 실측 inflation
2.8× → 1.0× 가 가정한 best-case 이지 가짜 보장 X.

## Problem — boxed-array allocator overhead is the LM-scale ceiling on CPU

pure-hexa hexa-cpu d=96·3L fire (2026-05-17, vast.ai 503 GiB host) 에서:

| step | predicted peak | observed RSS | inflation ratio |
|------|----------------|--------------|-----------------|
| init | 1 GiB (small)  | 1.5 GiB      | ~1.5×           |
| 25   | ~12 GiB        | ~18 GiB      | ~1.5×           |
| 50   | ~20 GiB        | ~47 GiB      | ~2.4×           |
| 100  | 27 GiB         | **76 GiB**   | **2.81×**       |
| 200  | 27 GiB         | **~137 GiB** | **~5.1×**       |

The predicted peak (27 GiB) is computed from element counts ×
`sizeof(double) = 8 bytes` over the transient training-step working set
(weight gradients + RoPE tables + KV cache + AdamW moments).
The observed peak is dominated by **boxed-array per-element overhead**
(each element is a heap-allocated box with a tag header + pointer
indirection, ~24-32 bytes/element on a packed-double payload, plus list-
container metadata) **and** GC-residency of intermediate transient lists
across the step (97 distinct `let mut … = []` + `push` allocations in
`d_train5_lib.hexa` alone — every `qr / kr / vr / qh / kh / srow / douti
/ ctxi / dP / dqrow / dkrow / dvrow / xi …` per-token / per-layer hot
path).

This inflation **scales nonlinearly with `d`**:
- d=64·3L Mac (Agent #2a): ≈ 12 GiB peak (within 24 GiB Mac), OK
- d=96·3L vast.ai: 76 GiB step 100 (2.81×), 137 GiB step 200 (5.1×)
- d=128·4L Mac (Agent #2a PARTIAL): 138 GiB peak step 51 (Mac OOM)

The pattern is the same: the **transient list allocation per step**
grows as `d × n_layer × T` (per-token, per-head, per-layer slicing),
each into a boxed-element list, and the GC arena retains them until
step boundary. The result.json `substrate_bound_finding` ("the
pure-hexa interpreter boxed-array AdamW transient memory footprint
still scales nonlinearly with d") is the measured ground truth.

### Why farr does not already solve this

`farr` (RFC 025 / 031 / 032 / 033 / 034) is the packed-double tensor
primitive: mmap-backed, GC-stable, fp64 native. It IS unboxed in the
*data* dimension. **What `farr` does NOT cover** is the **per-iteration
transient list** in interpreter-level scalar loops:

```hexa
let mut qr = []
let mut c = 0
while c < d { qr.push(Qb[ti * d + c]); c = c + 1 }
```

`qr` is a boxed `list[float]` (each element a heap-boxed value).
`farr` would require a `farr_zeros(d) + farr_set` + `farr_free` triple
per slice, which on the hot per-token / per-head inner loop is its own
overhead (mmap page-fault + handle alloc + handle-free × N_token × N_head).
The need is for a **transient stack-fast or arena-allocated packed-
scalar buffer** with NO per-element box overhead and NO mmap roundtrip.

This is structurally different from `farr` (mmap, cross-call-stable,
autograd-tape-eligible) and from boxed lists (general-purpose, growable,
GC-tracked).

## Proposal — surface API, codegen, semantics

A new native primitive **`uarr`** — *unboxed packed-scalar transient
array*. Stack-arena or malloc-arena allocated, packed (no per-element
header), bounded lifetime (no GC handle), explicit `uarr_free` (or
scope-exit auto-free in v2).

### Surface API (5 built-ins)

| built-in                              | type                                | purpose |
|---------------------------------------|-------------------------------------|---------|
| `uarr_alloc(n: int, kind: int) -> int` | `(size, dtype-tag) → handle`        | Allocate n-element packed-scalar buffer of kind `KIND_F64=0 / KIND_F32=1 / KIND_I64=2`. Returns opaque `uarr_handle` int. |
| `uarr_set(h: int, i: int, v: float) -> int` | `(handle, idx, value) → 0`     | Set element i to v (kind-dispatched store). Returns 0 on success, -1 on bounds-violation. |
| `uarr_get(h: int, i: int) -> float`   | `(handle, idx) → value`             | Get element i (kind-dispatched load, promoted to f64 for arithmetic). |
| `uarr_free(h: int) -> int`            | `(handle) → 0`                      | Free buffer. Returns 0 on success, -1 on double-free. |
| `uarr_len(h: int) -> int`             | `(handle) → n`                      | Return allocated element count. |

The 5-fn surface mirrors `farr_zeros/farr_set/farr_get/farr_free/farr_len`
deliberately so the migration of `d_train5_lib.hexa` hot loops is
mechanical (textual substitution of `let mut x = []` + push-loop into
`let x = uarr_alloc(n, 0)` + set-loop, with `uarr_free(x)` at scope
exit).

### Semantics

1. **No GC tracking** — `uarr_handle` is NOT a managed object. The
   programmer's responsibility is to call `uarr_free` (or rely on
   compiler-inserted scope-exit free in v2).
2. **No mmap** — allocation is `malloc`-backed (or arena slab if the
   compiler can prove single-step lifetime). No safetensors integration,
   no on-disk persistence.
3. **No autograd tape** — `uarr` is for *transient* compute buffers
   (per-step intermediates). Tape recording is the `farr` responsibility.
   Crossing the boundary (`uarr` ↔ `farr`) requires explicit
   `farr_from_uarr(h) → farr_handle` / `uarr_from_farr(h) → uarr_handle`
   copy ops (v1: copy; v2: zero-copy when dtypes align).
4. **Packed payload** — element stride = `sizeof(kind)` exactly. No
   per-element tag, no pointer indirection. Cache-friendly.
5. **Bounds-checked accessor** in debug builds, optional skip in
   release. Both modes are kind-dispatched (one branch on alloc,
   none in get/set hot loops in release).

### Codegen path (no implementation in this RFC)

The runtime addition (v1):

```c
// self/runtime.c additions (v1 sketch — NOT in this RFC, design only)
typedef struct {
    int    kind;     // 0=f64, 1=f32, 2=i64
    int    n;        // element count
    void  *data;     // malloc'd, packed
} uarr_t;

static uarr_t *_uarr_pool[UARR_MAX_HANDLES];  // handle table
static int _uarr_next = 0;

int _hx_uarr_alloc(int n, int kind) { /* malloc + slot */ }
int _hx_uarr_set(int h, int i, double v) { /* kind dispatch + store */ }
double _hx_uarr_get(int h, int i) { /* kind dispatch + load + promote */ }
int _hx_uarr_free(int h) { /* free + slot release */ }
int _hx_uarr_len(int h) { /* return n */ }
```

The interpreter `hexa_interp` dispatch table gains 5 entries. The AOT
codegen (`hexa_v2` C-codegen) emits direct `_hx_uarr_*` calls (same
pattern as RFC 032 `farr_matmul`).

## Acceptance falsifiers (F-RFC051-*) — pre-registered

Each falsifier is closed-form or evidence-anchored:

- **F-RFC051-SHAPE-CLOSED** — `uarr_alloc(n, kind) → h; uarr_len(h) = n`
  ∀ `n ≥ 0`, ∀ `kind ∈ {0,1,2}`. Closed integer identity.
- **F-RFC051-BIT-EQUAL-VS-FARR** — for a fixed input vector `v[0..n]`,
  `uarr_get(uarr_alloc + uarr_set loop, i) == farr_get(farr_zeros +
  farr_set loop, i)` for all i. **IEEE 754 bit-equality** (real-limit
  anchor: same fp64 representation, no rounding, no precision loss
  across primitives). This is the `g_blue_closed_mandate` connection
  point closed check.
- **F-RFC051-BOUNDED-ARENA** — peak resident bytes for an n-element
  uarr = `n × sizeof(kind) + O(1)` overhead (constant header,
  independent of n). Closed inequality: ∀ n, peak ≤ `n × sizeof(kind)
  + 64 bytes`. Real-limit anchor: Kolmogorov integer-byte counting.
- **F-RFC051-FREE-RECLAIMS** — after `uarr_free(h)`, the buffer is
  reclaimable (next `uarr_alloc(n, kind)` of equal-or-smaller size
  reuses the slot with no peak-RSS regression). Empirical witness
  (allocator-dependent, NOT counted as closed — B-D-NOTE umbrella
  pattern).
- **F-RFC051-MEMORY-REDUCTION-EXPECTED** — for the anima
  `d_train5_lib.hexa` d=96·3L step-100 hot path, migrating ALL 97
  `let mut … = []` boxed-list call sites to `uarr` is **expected** to
  reduce peak RSS from observed 76 GiB toward the predicted 27 GiB
  band (≥ 50% reduction, target ≥ 60%). This is an **expected
  outcome, NOT a guaranteed closed result** (B-D-NOTE pattern — the
  *property* "uarr eliminates per-element box overhead" is closed
  (per-byte arithmetic), the *empirical fraction* of inflation
  attributable specifically to per-element boxing vs to GC arena
  residency vs to refcount metadata is allocator/runtime-dependent
  and stays empirical).

## Downstream impact (anima Phase 4 migration target)

anima `HEXAD/D/d_train5_lib.hexa` (942 LoC) has **97 boxed-list call
sites** (`let mut … = []` + push) on the per-step hot path. Highest-
priority migration targets (by frequency × inflation contribution,
per d=96·3L trace):

1. **`d5_attn_fwd` `qr / kr / vr / qh / kh / srow`** (lines 395-445) —
   per-token (T loop) × per-head (nh loop) slice extraction. At T=8,
   nh=4, this is 8 × 4 × 6 ≈ 192 transient boxed lists *per layer per
   forward pass* — and 80-step AdamW × 3-layer × 80-step = ~46 080
   transient lists *per fire*. Dominant boxed-allocator pressure.

2. **`d5_attn_bwd` `douti / ctxi / dP / dqrow / dkrow / dvrow / xi`**
   (lines 487-595) — backward analogue, same multiplicity. Equal
   contributor.

3. **`d5_rope_apply` `o` / `d5_rotate_half` / `d5_rotate_half_t`**
   (lines 332-346, 354-369) — per-RoPE-call inner buffers, T × nh
   times per forward. High frequency, small per-instance size.

4. **`d5_block_fwd` `rm1inv` + `xr`** (lines 624-635) — RMSNorm
   per-token slice extraction. T × n_layer per forward.

5. **`d5_swiglu_bwd_g` `da / db / dr`** (lines 241-256) — per-element
   gradient accumulators. T × n_layer × ff_d per backward.

Stages (anima-side roadmap, **gated on RFC 051 land**):
- **Phase 4a (smallest scope)** — migrate `d5_rope_apply` (one fn,
  3-call sites). F-D5-UARR-MIGRATE-1 byte-equal vs boxed path. Cost
  ≈ 0.5 hr design + verify; <100 LoC change.
- **Phase 4b** — migrate `d5_attn_fwd` (hot path 1). F-D5-UARR-MIGRATE-2
  byte-equal vs boxed path on d=64·3L reference.
- **Phase 4c** — migrate `d5_attn_bwd` (hot path 2). F-D5-UARR-MIGRATE-3.
- **Phase 4d** — migrate remaining `d5_block_*` + `d5_swiglu_bwd_g`.
  F-D5-UARR-MIGRATE-4..5.
- **Phase 4e** — re-fire d=96·3L on vast.ai (or back-port to ubu after
  Phase 4 land if peak RSS < 38 GiB). Measure observed peak vs
  predicted. F-RFC051-MEMORY-REDUCTION-EXPECTED verdict (cost
  $0.03-$0.10 — same dispatch pattern as the 2026-05-17 fire).

## Backward-compat

- `farr` API surface **unchanged**. RFC 025/031/032/033/034 functionality
  identical.
- Boxed lists (`let mut … = []` + push) **unchanged** — `uarr` is an
  additional primitive, not a replacement. Code that does not migrate
  retains the current allocator overhead.
- `hexa build` AOT codegen — unchanged for non-`uarr` programs; gains 5
  built-in mappings for `uarr_*` calls.
- `hexa_interp` bytecode — unchanged opcode space; gains 5 built-in
  entries in the dispatch table (same pattern as `farr_matmul` add).

## Tradeoffs (honest)

- **uarr v1 has NO autograd tape integration**. Crossing to `farr` for
  gradient accumulation requires explicit `farr_from_uarr` copy. For
  pure-hexa autograd training (RFC 034 land), uarr is appropriate for
  *transient* buffers (RMSNorm slices, RoPE rotations, attention QKV
  slice extraction) but NOT for trainable parameter buffers (those
  stay `farr`).
- **uarr v1 has NO mmap / cross-call persistence**. uarr handles are
  process-local, single-fire only. Use `farr_zeros + farr_set` if the
  buffer must survive a hexa-process boundary (rare in the hot loop).
- **Manual `uarr_free`** in v1. Compiler-inserted scope-exit free is
  a v2 design — out of scope here. Programmer discipline required;
  F-RFC051-FREE-RECLAIMS verifies the runtime side.
- **kind dispatch overhead** — one branch per alloc (cold). get/set
  in release builds: zero (compile-time monomorphization). Debug:
  one branch per call (~5% slowdown for tight loops, acceptable for
  debug).

## Honest caveats (g3 / f2 — no over-claim)

- **The inflation is MEASURED, not hypothesized.** anima ubu agent's
  d=96·3L fire on vast.ai 503 GiB host (2026-05-17, `state/
  hexad_pure_hexa_train_d96x3_2026_05_17/train_d96.log` + result.json)
  is the source-of-truth: predicted 27 GiB, observed 76 GiB (step 100,
  2.81×) and 137 GiB (step 200, 5.1×). This is not a speculative
  problem.
- **50% memory reduction is EXPECTED, not guaranteed.** The
  property "uarr eliminates per-element box overhead" is closed
  (arithmetic on bytes). The *empirical* fraction that overhead
  contributes to the 2.8-5× inflation vs other contributors (GC arena
  residency, list-container metadata, doubled buffers from `push`-
  growth) is allocator-dependent and remains empirical (B-D-NOTE
  umbrella pattern). F-RFC051-MEMORY-REDUCTION-EXPECTED is explicitly
  *not counted toward 🔵 closed* — it is an expected post-impl
  outcome.
- **Does NOT subsume RFC 040/041/042/043/044.** RFC 051 closes the
  CPU-side allocator-inflation ceiling. RFC 040/041 close the GPU-
  substrate ceiling. RFC 042/043 close the control-flow execution
  ceiling. RFC 044 closes the paradigm-tier dispatch ceiling. All
  four ceilings are independent and all four must close for
  pure-hexa LM-scale training-to-convergence. RFC 051 is the
  *measured* fourth ceiling.
- **Possible future absorption by RFC 043 hexa-torch.** RFC 043's
  compiler-only stdlib could subsume `uarr` as an internal compiler
  primitive (no surface API) once `hexa-torch` lands. Then the
  surface API in RFC 051 becomes the *interim* path while
  `hexa-torch` is multi-cycle in flight. Honest: RFC 051 is the
  bridge, RFC 043 is the destination — but RFC 043 is multi-cycle
  (per its own design draft), and RFC 051 closes the present
  measured wall today.
- **No lattice-tautology (f2).** Real-limit anchors are Kolmogorov
  integer bytes (F-RFC051-SHAPE-CLOSED / F-RFC051-BOUNDED-ARENA) +
  IEEE 754 fp64 bit-equality (F-RFC051-BIT-EQUAL-VS-FARR). No
  σ/τ/φ/J₂ — same standard as RFC 040/042/043.
- **Cost of design only: $0.** Cost of implementation (hexa-lang
  side, future cycle): runtime.c addition (~150 LoC) + interp
  dispatch (~30 LoC) + codegen mapping (~30 LoC) + falsifier battery
  (~200 LoC). Bounded scope, single-cycle on hexa-lang side; not
  multi-cycle like RFC 042/043.
- **Cost of anima Phase 4 migration: $0 design + $0.03-0.10 verify
  fire** (re-run d=96·3L vast.ai, same instance pattern as
  2026-05-17). No new architectural change to the trainer; mechanical
  textual substitution of 97 call sites + free-insertion.

## Non-goals (this RFC)

- No implementation — no `self/runtime.c` edit, no interp dispatch
  add, no codegen mapping. Design draft only.
- No autograd tape integration (`uarr` is transient by design;
  trainable buffers stay `farr`).
- No mmap or cross-process persistence.
- No compiler-inserted scope-exit free (v1 is manual `uarr_free`;
  v2 design is a separate cycle).
- No subsumption of RFC 040/041/042/043/044 — they close orthogonal
  ceilings.
- No general-purpose container replacement — boxed lists remain for
  growable, heterogeneous, GC-tracked use cases.

## Cross-RFC dependency

- **None mandatory upstream**. RFC 051 can land standalone (the 5
  built-ins + runtime.c additions are independent).
- **Complements RFC 034** (`farr` reverse-mode autograd) — `uarr` is
  the *transient* counterpart to `farr` (tape-eligible / persistent),
  with the explicit `farr_from_uarr` / `uarr_from_farr` boundary.
- **Possible future absorption by RFC 043** (hexa-torch stdlib) — see
  honest caveat above.
- **Required by anima Phase 4** (boxed-array transient migration in
  `d_train5_lib.hexa`) — this is the anima-side downstream which
  is design-only-gated on RFC 051 land.

## Cross-link (campaign evidence — g3)

- anima `state/hexad_pure_hexa_train_d96x3_2026_05_17/result.json` +
  `train_d96.log` — measured peak RSS trajectory, predicted vs observed
  inflation 2.81×@step100 / 5.1×@step200.
- anima `state/hexad_pure_hexa_train_d96x3_2026_05_17/blue_substrate_falsifier.py`
  — substrate-capacity sympy battery (B-SUBSTRATE-1..3) + B-SUBSTRATE-
  NOTE honest carve-out (allocator overhead empirical) carrying the
  *operational* fix; RFC 051 is the *algorithmic* counterpart.
- anima `docs/hexad_pure_hexa_d96x3_substrate_fix_2026_05_17.md` §6.1
  C3-2 — *"OPERATIONAL substrate fix … NOT algorithmic improvement.
  The pure-hexa interpreter boxed-array allocator overhead is
  structurally addressed by separate threads: HEXA_NATIVE Phase 4
  unboxed arrays + RFC 040 GPU dispatcher."*
- anima `HEXAD/D/d_train5_lib.hexa` — 97 boxed-list call sites; the
  migration target for anima Phase 4.
- anima `docs/hexad_phase_4_unboxed_array_design_2026_05_17.md` (this
  RFC's anima-side companion design doc, landed concurrently).
- anima `AGENTS.tape` §0 `g3` (Kolmogorov-byte real-limit anchor +
  IEEE 754 bit-equality connection-point) + `f1`/`f2` (no lattice
  derivation) + `g_blue_closed_mandate` (산출물 + 연결부위 둘 다 🔵
  — 산출물 = `uarr` 5-fn surface API closed; 연결부위 = `uarr ↔ farr`
  bit-equal copy).
- anima `HEXAD/PLAN.md` §9 (GPU 기질 substrate roadmap) — RFC 051 is
  the §9 CPU-side counterpart entry (substrate inflation 천장
  closure, dual-track to GPU substrate).
