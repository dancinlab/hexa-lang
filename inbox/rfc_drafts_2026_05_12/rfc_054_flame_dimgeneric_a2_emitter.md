# RFC 054 — flame dimension-generic A2 emitter

- **Status**: design-draft (2026-05-17) — DESIGN ONLY, no implementation
- **Date**: 2026-05-17
- **Priority**: P1 — the A2 build pipeline's `T16_d32_nh4_nkv2_h64` hardcode is the
  single blocker between the verified GPU substrate and a measurable d=768·12L
  wall number (F-RFC046-EAGER-PYTORCH-MATCH).
- **Severity**: HIGHEST-IMPACT-BLOCKER — Phase 4-D-5-4 honestly proved the GPU
  substrate links and runs, but the d=768·12L A2 trainer that would exercise it
  **does not exist**: every A2 primitive is shape-baked to d=32. Until the A2
  emitter is dimension-generic, no d=768 GPU fire is physically buildable.
- **Builds on**: RFC 047 (Phase 4-B per-block IR pass — the A2 specialization
  this RFC generalizes), RFC 048 (Phase 4-C fwd+bwd fusion — same emit-pattern
  family), RFC 040/041 (forge GPU substrate the d=768 path will route to).
- **RFC number**: 054 confirmed free — 053 = forge FP8 substrate (taken), 052 =
  forge Hopper bf16+DSM (taken), 051 = unboxed-array-native (taken). 054 is the
  next free flame slot.

---

## 1. Status / Date / Priority / Severity

| Field | Value |
|---|---|
| Status | design-draft — DESIGN ONLY |
| Date | 2026-05-17 |
| Priority | P1 (blocks F-RFC046 wall measurement) |
| Severity | HIGHEST-IMPACT-BLOCKER |
| Scope | DESIGN — implementation is Phase 4-D-6 parallel work |
| Implementation owner | Phase 4-D-6 sub-agent (parallel; this RFC is its DESIGN SSOT) |
| Cost | $0 (design only; no vast.ai fire) |

This RFC is the **architecture decision record + verification contract** for the
dimension-generic A2 emitter. A Phase 4-D-6 sub-agent is implementing the
generic primitives in parallel; RFC 054 documents **why** dimension-generic is
the right architecture and **what** the pre-registered falsifier battery is, so
the implementation lands against a fixed contract rather than an evolving target.

---

## 2. Source convergence — Phase 4-D-5-4 honest FAIL → d768 trainer doesn't exist

Phase 4-D-5-4 ran four cost-bearing A100 fires (~$5.5 total) to verify the forge
GPU substrate against a d=768·12L flame trainer. The honest verdict (PHASE4D_5_4
_ANALYSIS.md §7b): **F-RFC046-EAGER-PYTORCH-MATCH = FAIL**, 600s timeout, ZERO
training steps, GPU 0% utilization the entire run.

The root cause is not a substrate defect. The Phase 4-D-5-2 Layer 2 dim-aware
dispatch (`flame_proj_matmul_dispatch`) and the Phase 4-D-5-1/5-3 substrate
(`runtime_cuda.c` + `_hx_farr_*_gpu` wiring) are real, byte-eq-verified
(11/11 PASS), and link clean into a 587K CUDA-enabled binary. The gap is
**upstream of the substrate**:

> The trainer `.c` artifact that ran was built from the **d=32·3L** source
> (`flame_d32_corpus_test.hexa`), NOT the real d=768·12L source. Its matmul
> primitives carry d=32 shapes — `M·K ∈ {512, 1024, 2048}` — every one of which
> sits **below** the `FLAME_MATMUL_GPU_THRESHOLD` (8192), so even with
> `-DHEXA_CUDA` the dim-aware dispatch correctly keeps them on the CPU path.
> The GPU is never touched because **no d=768-shaped matmul exists in the
> binary to route**.
> — LAYER2_TRAINER_REGEN_NOTES.md §"IMPORTANT — artifact / filename mismatch"

The three Phase 4-D-5 work products converge on one conclusion:

1. **Layer 1 substrate** (RFC 040/041) — DONE, verified, linkable.
2. **Layer 2 dim-aware dispatch** (`flame_proj_matmul_dispatch`) — DONE,
   threshold 8192, GPU branch under `#ifdef HEXA_CUDA`.
3. **A2 build pipeline** (`tool/flame_phase4b3_a2_build.sh`) — **shape-locked to
   `T16_d32_nh4_nkv2_h64`**. This is the actual blocker.

The dim-aware dispatch is *ready* for d=768 shapes (`M·K = 589824 > 8192` would
route to cuBLAS). It has nothing to dispatch because the A2 emitter cannot
produce a d=768-shaped trainer. **Dimension-generic A2 primitives are the
missing piece.**

---

## 3. Source evidence (g3)

All evidence is referenced, not reproduced (g3 drift-avoidance — the artifacts
are the SSOT):

- **PHASE4D_5_4_ANALYSIS.md §7b** — 4th fire on a reliability>0.97 A100-SXM4 pod
  (host did NOT die, so this is a clean measurement): `TRAINER DONE: rc=124`
  (600s WALL_BUDGET timeout), `nvidia_smi during run: 0 % / 0 MiB ENTIRE 10
  minutes`. The §7b "Layer table" is explicit: Layer 1 + 1b DONE, **Layer 2 NOT
  DONE at the trainer-source level** — "nothing routes the trainer's matmul
  calls to it."
- **LAYER2_TRAINER_REGEN_NOTES.md §"IMPORTANT — artifact / filename mismatch"**
  — Agent #35's honest caveat: the `flame_d768_12L_corpus_test_a2_layer2.c`
  artifact *despite its filename* was built from the **d=32·3L** source. The
  matmul primitives are `d32x32` / `d16x32` / `d64x32` / `d32x64`. The note
  states verbatim: *"a genuine d=768 GPU-util fire requires a real d768 A2
  trainer build whose primitives carry d=768 shapes … That is a separate
  artifact-regen task gated on the A2 build pipeline supporting the d768 config
  — the A2 build script (`flame_phase4b3_a2_build.sh`) is currently hard-coded
  to the `d32_nh4_nkv2_h64` block."*
- **`tool/flame_phase4b3_a2_build.sh:25`** — the build header itself declares
  the limitation: *"Currently hard-coded for (T=16, d=32, nh=4, nkv=2, h=64)
  d=32·3L config."* Step 3.9's sed-redirect (`flame_phase4b3_a2_build.sh:69-72`)
  matches the literal symbol `flame_block_T16_d32_nh4_nkv2_h64_fwd((int)` — a
  d=768 trainer would have no such symbol.
- **`tool/flame_phase4b3_block_fwd_primitive.c:103-128`** — the primitive baked
  shape: `flame_block_T16_d32_nh4_nkv2_h64_fwd_primitive`, with `const int T=16,
  d=32, nh=4, nkv=2, h=64;` and **34 literal-baked layout offsets** (`G1=0,
  WQ=32, WK=1056, ...`, `oXout=0, oHstate=512, ...`). Every offset is a
  compile-time constant derived from d=32.
- **`tool/flame_phase4b3_matmul_primitives.c:126-242`** — 4 fwd + 4 bwd matmul
  primitives, each with a baked stack-buffer declaration (`double xbt[32*16],
  Wbuf[32*32], C[32*16];`). The buffer sizes are d=32 literals; a d=768 shape
  would overflow these by ~576×.

---

## 4. Scope — DESIGN; implementation is Phase 4-D-6 parallel work

This RFC lands **zero implementation**:

- No new `tool/flame_*` files (those are the Phase 4-D-6 sub-agent's deliverable).
- No edits to `self/forge/*` (forge is a sibling substrate; out of scope —
  g_forge_substrate_role).
- No build, no codegen edits, no `.c` emission.
- No lattice numerology.

It **does** specify: the dimension-generic emitter architecture (two options +
chosen tradeoff), the byte-equivalence contract, the 7-falsifier pre-registered
battery, honest caveats, non-goals, and the cross-RFC dependency map.

The Phase 4-D-6 sub-agent implements the generic primitives against this
contract. If the implementation deviates from the byte-eq contract (§6) or fails
a §7 falsifier, this RFC is the authority that says the deviation is a defect.

---

## 5. Problem — A2 build pipeline `T16_d32_nh4_nkv2_h64` hardcoded

The A2 build pipeline (`tool/flame_phase4b3_a2_build.sh` + the three primitive
`.c` files it concatenates) is the only path that produces a hand-translated,
boxing-eliminated flame trainer fast enough to consider for a GPU fire. It is
**structurally locked to d=32** in four independent places:

### 5.1 The block primitives are shape-baked

`flame_phase4b3_block_fwd_primitive.c` and `_bwd_primitive.c` define
`flame_block_T16_d32_nh4_nkv2_h64_{fwd,bwd}_primitive` with:

- The function **name** contains the dims (`T16_d32_nh4_nkv2_h64`).
- `const int T=16, d=32, nh=4, nkv=2, h=64;` — dims as compile-time literals.
- **34 literal-baked layout offsets** (`fwd_primitive.c:120-128`): `WQ=32`,
  `WK=1056`, `WV=1568`, ... `oSwS=7680`, `oR2inv=8720`. Every value is the
  arithmetic result of a d=32 layout-offset formula evaluated at build time.
- Stack scratch sized to d=32: `double q_scratch[8]` (= hd = d/nh = 8),
  `double srow_at[16]` (= T = 16).

A d=768·12L block has hd = 64, T = 1024, ~150× the cache footprint, and entirely
different offsets. None of the baked values survive.

### 5.2 The matmul primitives carry d=32 stack buffers

`flame_phase4b3_matmul_primitives.c` declares 8 primitives, each with a
fixed-size stack buffer triple, e.g. `flame_proj_batch_T16_d32x32_primitive`:

```c
double xbt[32*16], Wbuf[32*32], C[32*16];   // 512 + 1024 + 512 doubles
```

At d=768 these become `xbt[768*1024]`, `Wbuf[768*768]`, `C[768*1024]` —
~1.5M + 0.6M + 1.5M doubles = ~28 MB on the **stack**, which overflows on every
platform. d=768 matmul buffers MUST be heap (farr) allocated.

### 5.3 The build script sed-redirects literal symbols

`flame_phase4b3_a2_build.sh:69-72` rewrites caller sites by exact-string match:

```bash
sed -e 's|flame_block_T16_d32_nh4_nkv2_h64_fwd((int)|..._fwd_primitive((int)|g'
```

A d=768 trainer emits `flame_block_T1024_d768_nh12_nkv4_h3072_fwd(...)` (or
similar) — the sed pattern matches nothing, and the redirect silently no-ops.

### 5.4 Consequence — the d=768·12L GPU fire is physically impossible

The dim-aware dispatch (`flame_proj_matmul_dispatch`, threshold 8192) is the one
piece that is **already** d=768-ready: a d=768 shape (`M·K = 768·768 = 589824 >
8192`) would route to `flame_proj_gpu_matmul` → `hexa_farr_matmul_gpu` → cuBLAS
Dgemm. But the dispatch can only route what the emitter produces. As long as the
emitter produces only d=32 primitives, the GPU branch is dead code in any flame
trainer. **The wall gate cannot be measured until the emitter is
dimension-generic.**

---

## 6. Proposal — dimension-generic A2 emitter

Replace the shape-baked A2 primitives with a single dimension-generic primitive
family. Two implementation options are on the table; this RFC records the
tradeoff and the recommended choice, leaving the final pick to the Phase 4-D-6
sub-agent's step-by-step decision gate.

### 6.1 Option A — runtime-parameter primitives

The primitive functions take dims as **runtime arguments** instead of baking
them as literals:

```c
// generic — dims are fn args; offsets computed at fn entry
static void flame_block_fwd_primitive(
    int X_id, int Bp_id, int Bc_id, int cos_id, int sin_id,
    int T, int d, int nh, int nkv, int h
) {
    const int hd = d / nh;
    const int half = hd / 2;
    const int n_rep = nh / nkv;
    // layout offsets COMPUTED from dims (was: 34 literal constants)
    const int G1 = 0, WQ = d, WK = WQ + d*d, WV = WK + (d/nh*nkv)*d, ... ;
    ...
}
```

- **One** `flame_block_fwd_primitive` / `_bwd_primitive` covers every config.
- The 4+4 matmul primitives collapse to **one** `flame_proj_batch_primitive` /
  `flame_grad_accum_primitive` taking `(d_out, d_in, T)` as args.
- Stack scratch (`q_scratch`, `srow_at`) and the d=32 matmul stack buffers
  become heap (farr) allocations sized at runtime — required for d=768 anyway
  (§5.2).
- clang `-O2` still vectorizes the inner loops: the reduction loops are
  `for (int k=0; k<K; k++)` with `K` a function parameter. clang's loop
  vectorizer handles runtime trip counts (it emits a vectorized body + a scalar
  remainder); the SLP/loop vectorizer does not require literal bounds. The
  *only* literal-baked optimization lost is full loop unrolling at tiny d=32
  trip counts — see honest caveat §8.

**Pros**: one primitive family, dramatically less code, no per-config emission
step, trivially extends to any future config. **Cons**: clang cannot fully
unroll d=32 loops (minor; §8); the offset arithmetic runs once per call (also
minor — it is O(1) integer math, dwarfed by the O(T·d²) matmul).

### 6.2 Option B — emitter-templated specialization

A template-expansion step in the build pipeline takes the config tuple
`(T, d, nh, nkv, h)` and emits a **specialized `.c`** with that config's
literals baked in — exactly today's d=32 file, but generated per config:

```
config tuple (T,d,nh,nkv,h)
   ↓ flame_a2_emit_primitives.hexa   (NEW — template expander)
   ↓ flame_block_T<T>_d<d>_..._fwd_primitive.c   (generated, literals baked)
   ↓ flame_phase4b3_a2_build.sh                  (generalized: dims from tuple)
```

- Preserves the literal-baked optimization (full unroll, constant-folded
  offsets) at every config.
- Each emitted `.c` is config-specific; the build pipeline picks the right one.

**Pros**: preserves today's d=32 performance characteristics exactly; the d=32
output is byte-identical *by construction* (same literals → same C → same
binary). **Cons**: a new emitter component (template language or hexa-side
string emission), more moving parts in the build pipeline, a generation step
per config, larger artifact surface.

### 6.3 Tradeoff + recommendation

| Axis | Option A (runtime-param) | Option B (emitter-templated) |
|---|---|---|
| Code volume | 1 primitive family — minimal | N generated files |
| Maintainability | high (one source of truth) | medium (template + generator) |
| d=32 byte-eq | requires verification (F-RFC054-D32-BYTEEQ) | by construction (same literals) |
| d=32 perf | ~equal − full-unroll loss (caveat §8) | identical to today |
| d=768 perf | dominated by cuBLAS Dgemm (matmul on GPU — primitive is just the bridge) | same |
| New build component | none | template expander |
| Extends to new config | free (pass new args) | re-run generator |

**Recommendation: Option A.** Reasoning:

1. At the **target** config (d=768·12L), the matmul work is on the GPU — the
   primitive is just a buffer-marshalling bridge. The literal-baked unroll
   advantage Option B preserves is a CPU-path optimization that is irrelevant
   where it matters most. The honest perf cost of Option A is confined to the
   d=32 CPU path (§8), where it is small.
2. Option A is the simpler, lower-surface-area architecture (andrej-karpathy
   simplicity-first). One primitive family vs. a generator + N artifacts.
3. The d=32 byte-eq risk Option A introduces is **precisely** what
   F-RFC054-D32-BYTEEQ pre-registers and gates. A verified-zero-Δ contract
   neutralizes the only real Option A downside.

The Phase 4-D-6 sub-agent retains the final decision (step-by-step gate). If
F-RFC054-D32-BYTEEQ cannot be made to pass under Option A (e.g., clang reorders
a reduction differently for runtime vs. literal bounds — see §6.4 and the Path C
revert lesson F-RFC054-NO-REORDER), Option B is the documented fallback because
it eliminates the byte-eq risk by construction.

### 6.4 Byte-equivalence contract

**The d=32·3L config is the SHIPPED reference. It MUST stay byte-identical.**

Concretely:

1. The d=32·3L A2 trainer built with the new dimension-generic emitter MUST
   produce **byte-identical stdout** to the current d=32-baked A2 trainer
   (`F-RFC054-D32-BYTEEQ`, `max|Δ| = 0`).
2. `tool/flame_phase4b3_verify_all.sh` MUST remain **26/26 PASS** unchanged
   (`F-RFC054-VERIFY-ALL-PRESERVED`).
3. **No reduction loop may be reordered.** The matmul/accumulator inner loops
   (`for k`, then `for j` accumulating into `C[i*N+j]`) MUST keep the exact
   statement order of `flame_proj_inline_matmul`
   (`flame_phase4b3_matmul_primitives.c:35-45`). This is the Path C revert
   lesson (RFC 048 §6 R1, commit `23705dc5`): routing a reduction through a
   different helper produced `1.66e-16` last-ulp drift and a strict-byte-eq
   FAIL. Generalizing dims must NOT touch reduction order — only the loop
   *bounds* become variables, never the loop *structure* (`F-RFC054-NO-REORDER`).

The contract is enforceable because the transformation is **dims-to-variables
only**: the body statements (the actual floating-point operations and their
order) are copied verbatim from the existing primitives; only `const int d=32`
becomes `int d` (a parameter) and `WQ=32` becomes `int WQ = d`. Under that
discipline the only way byte-eq fails is a clang codegen difference between
literal and runtime trip counts — which F-RFC054-D32-BYTEEQ detects, and which
forces the Option B fallback if it occurs.

---

## 7. Falsifier battery (7 pre-registered)

All falsifiers are pre-registered before implementation. They are the contract
the Phase 4-D-6 implementation lands against.

### F-RFC054-D32-BYTEEQ
The d=32·3L config compiled with the dimension-generic primitives produces
stdout **byte-identical** to the current d=32-baked A2 trainer.
**Gate: `max|Δ| = 0`** (strict — NOT fp-tolerance). This is the
SHIPPED-state regression gate. Run BEFORE any d=768 work.

### F-RFC054-D768-BUILDS
A d=768·12L A2 trainer (config `T=1024, d=768, nh=12, nkv=4, h=3072,
n_layer=12`) emitted by the dimension-generic emitter **compiles and links
clean** — `clang -O2` (Mac no-CUDA) and `clang -DHEXA_CUDA` (CUDA host) both
produce a binary with no errors. (Today: impossible — §5.4.)

### F-RFC054-NO-REORDER
**No reduction loop is reordered** relative to the d=32-baked primitives. The
matmul and grad-accumulator inner-loop statement order is byte-identical at the
source level (verified by diff of the reduction blocks) — only loop bounds
change from literals to variables. Path C revert lesson (RFC 048 §6 R1): a
reordered reduction caused `1.66e-16` drift and a strict byte-eq FAIL.

### F-RFC054-D768-GPU-DISPATCH
At d=768, the matmul shapes (`M·K = d_out·d_in = 768·768 = 589824` for the
square projections; `≥ 768·1024` for others) **route to the cuBLAS GPU path**
in a `-DHEXA_CUDA` build — i.e. `flame_proj_matmul_dispatch` takes the
`M·K > FLAME_MATMUL_GPU_THRESHOLD` (8192) branch. Verified by instrumenting the
dispatch (or by `nvidia-smi` showing non-zero GPU utilization during the matmul
phase). 589824 / 8192 ≈ 72× over threshold — the routing is unambiguous.

### F-RFC054-D768-WALL
A d=768·12L GPU fire produces a wall time **≤ 437.9s** — the
F-RFC046-EAGER-PYTORCH-MATCH gate (eager-PyTorch reference). This is the
ultimate target the entire RFC 054 → Phase 4-D-6 chain exists to make
measurable. (Phase 4-D-5-4's four fires could never reach this falsifier
because no d=768 trainer existed to fire.)

### F-RFC054-CACHE-FARR-FIT
The d=768·12L block cache farr (~2.6 GB — PHASE4D_5_4_ANALYSIS.md §7b measured
`cache size: 346842881 doubles ≈ 2.6 GB`) plus the model farr (~830 MB) **fits
within an A100 40GB device** (and the CPU host RAM). 2.6 GB + 0.83 GB ≈ 3.4 GB
is comfortably under 40 GB, but the GPU matmul temporaries (`flame_proj_gpu
_matmul` allocates A, B, C device farrs per call) add transient pressure that
must be bounded and freed (the `hexa_farr_free` discipline in
`flame_phase4b3_matmul_primitives.c:105-108`).

### F-RFC054-VERIFY-ALL-PRESERVED
`tool/flame_phase4b3_verify_all.sh` remains **26/26 PASS** after the
dimension-generic emitter lands — no leaf/integration test regresses.

---

## 8. Honest caveats (g3)

- **clang -O2 with runtime dims may be slightly slower than literal-baked on the
  d=32 CPU path.** With dims as function parameters, clang cannot fully unroll
  the small d=32 reduction loops (trip counts 16/32/64) and cannot constant-fold
  the 34 layout offsets at compile time. The loop vectorizer still applies
  (runtime trip counts are handled with a vectorized-body + scalar-remainder
  split), so the slowdown is the lost *unroll*, not lost *vectorization* —
  expected single-digit-percent on the d=32 CPU path. **This is irrelevant at
  the d=768 target** where matmul work is on the GPU and the primitive is a
  marshalling bridge. If d=32 CPU perf regresses measurably, Option B (§6.2) is
  the documented fallback.
- **d=768 block cache is ~2.6 GB.** This is large but fits A100 40GB with the
  ~830 MB model (§7 F-RFC054-CACHE-FARR-FIT). The GPU matmul temporaries
  (`flame_proj_gpu_matmul` per-call A/B/C device farrs) add transient pressure;
  the `hexa_farr_free` discipline must be strict to avoid device-memory leak
  across 12 layers × 20 steps. The use-after-realloc hazard
  (`flame_phase4b3_matmul_primitives.c:54-56` — `hexa_farr_zeros` may move
  `_hx_farr_table`) applies and must be honored.
- **Reduction-order strict preservation is non-negotiable.** §6.4 + the
  F-RFC054-NO-REORDER falsifier exist because the Path C revert (commit
  `23705dc5`, RFC 048 §6 R1) proved a reordered reduction produces last-ulp
  drift and a strict byte-eq FAIL. The dims-to-variables-only discipline is what
  makes byte-eq achievable; any temptation to "clean up" the reduction loops
  while generalizing dims is forbidden.
- **F-RFC054-D768-WALL is a target, not a guarantee.** The d=768·12L step has
  ~10¹¹ FLOPs of matmul; Phase D measured ~51 TFLOPS FP64 on H100 → sub-second
  per matmul on GPU. The arithmetic *predicts* the 437.9s gate is clearable. But
  the prediction assumes the non-matmul primitive sections (RMSNorm, RoPE,
  attention softmax — still CPU in this emitter) do not dominate. If they do,
  the falsifier honestly FAILs and the next RFC addresses non-matmul GPU
  offload. RFC 054 does not promise the wall; it makes the wall **measurable**.
- **A genuine d=768 GPU-util measurement requires a real d=768 fire** ($1-5 on
  a reliability>0.95 vast.ai pod). RFC 054 is design-only, $0. The fire is
  Phase 4-D-6's cost-bearing step, gated on F-RFC054-D32-BYTEEQ + D768-BUILDS
  passing on the Mac first.

---

## 9. Non-goals

- **No non-matmul GPU offload.** RMSNorm, RoPE, attention softmax, SwiGLU
  silu+Hadamard stay on the CPU in the dimension-generic primitive. Only the
  matmul/grad-accumulator calls route through `flame_proj_matmul_dispatch` to
  the GPU. Full-block GPU offload is a future RFC.
- **No new GPU substrate work.** RFC 054 consumes the RFC 040/041 forge
  substrate as-is. No `self/forge/*` edits, no new kernels.
- **No autograd / IR-level change.** The dimension-generic emitter operates on
  the same A2 hand-translation pattern as today; it does not touch the RFC 047
  Phase 4-B IR pass or the RFC 048 Phase 4-C fusion pass. (If those land, the
  generic primitives slot into their emit step — see §10 — but that integration
  is out of scope here.)
- **No multi-config-in-one-binary.** The emitter produces one trainer per config
  invocation. A single binary that dispatches across configs at runtime is not a
  goal.
- **No lattice numerology.** Dims are real ML hyperparameters (d=768, nh=12 are
  GPT-2-class values); they are NOT derived from the n=6 lattice.
- **No interp-path change.** The A2 emitter is a compiled-path build tool; the
  interpreter is unaffected (g_inbox_dual_track does not apply — this is a
  build-tool change, not a language-level semantic).

---

## 10. Cross-RFC dependency

- **RFC 043** (flame design SSOT) — RFC 054 is a flame Phase 4-D sub-RFC; the
  dimension-generic emitter is the build-pipeline generalization RFC 043's
  phasing implies once d>32 configs become targets. **Consumed.**
- **RFC 047** (Phase 4-B per-block IR pass) — RFC 047 designs the *compiler*
  pass that emits specialized fwd primitives; RFC 054 generalizes the *A2
  hand-translation* the IR pass currently mirrors at d=32. If/when the RFC 047
  IR pass lands, it should emit dimension-generic primitives directly — RFC 054
  is the contract for what that emission must satisfy. **Sibling — same emit
  pattern family.**
- **RFC 048** (Phase 4-C fwd+bwd fusion) — RFC 048 §6 R1 (Path C revert lesson)
  is the direct source of F-RFC054-NO-REORDER. The fused-primitive emit pattern
  RFC 048 designs has the same dimension-generalization need; RFC 054's byte-eq
  contract (§6.4) applies to it. **Builds on — shared reduction-order
  discipline.**
- **RFC 040** (farr GPU CUDA backend) — provides `hexa_farr_matmul_gpu` / cuBLAS
  Dgemm that the d=768 matmul shapes route to. **Consumed.**
- **RFC 041** (farr GPU Phase B/B2 real kernels) — the 11 verified kernels in the
  forge substrate; the d=768 fire links against them. **Consumed.**
- **RFC 050** (flame ↔ forge integration) — F-RFC054-D768-BUILDS extends the
  F-FORGE-RFC050-COMPILE-EQ class (forge↔flame ABI link-clean). **Sibling.**

---

## 11. Cross-link

- `stdlib/flame/PHASE4C_IMPLEMENTATION_AUDIT.md` §6 R1 — Path C revert lesson
  (reduction-order preservation), the source of F-RFC054-NO-REORDER.
- `state/flame_phase4d_5_4_2026_05_17/PHASE4D_5_4_ANALYSIS.md` §7b — the 4th-fire
  honest FAIL (600s timeout, GPU 0%), the Layer table, the d768-trainer-doesn't
  -exist root cause.
- `state/flame_phase4d_5_4_2026_05_17/LAYER2_TRAINER_REGEN_NOTES.md`
  §"IMPORTANT — artifact / filename mismatch" — Agent #35's caveat that the
  `d768` artifact was d=32-built, and that a real d768 fire needs the A2 build
  pipeline generalized.
- `tool/flame_phase4b3_a2_build.sh` — the A2 build pipeline (`:25` declares the
  d=32 hardcode; `:69-72` the literal-symbol sed-redirect).
- `tool/flame_phase4b3_block_fwd_primitive.c` + `_bwd_primitive.c` — the
  shape-baked block primitives (34 literal offsets).
- `tool/flame_phase4b3_matmul_primitives.c` — the 8 matmul/grad-accum primitives
  with d=32 stack buffers + the existing `flame_proj_matmul_dispatch` (threshold
  8192, already d=768-ready).
- RFC 046 §"F-RFC046-EAGER-PYTORCH-MATCH" — the 437.9s wall gate that
  F-RFC054-D768-WALL feeds.

---

## 12. PLAN integration — flame Phase 4-D-6

Per the PLAN-consolidation governance (AGENTS.tape §3 `g_plan_consolidation`),
flame progress lands in `stdlib/flame/PLAN.md`. RFC 054 slots in as:

- **Phase 4-D-6 — dimension-generic A2 emitter** (this RFC's implementation,
  parallel sub-agent). Sub-steps:
  - **4-D-6-1** — generalize the matmul/grad-accum primitives to
    `(d_out, d_in, T)` runtime args + heap (farr) buffers. Gate:
    F-RFC054-D32-BYTEEQ + F-RFC054-NO-REORDER + F-RFC054-VERIFY-ALL-PRESERVED.
  - **4-D-6-2** — generalize the block fwd/bwd primitives to
    `(T, d, nh, nkv, h)` runtime args + computed layout offsets. Gate:
    F-RFC054-D32-BYTEEQ (full block).
  - **4-D-6-3** — generalize `flame_phase4b3_a2_build.sh` (dims from a config
    tuple; symbol-name redirect parameterized). Gate: F-RFC054-D768-BUILDS
    (Mac no-CUDA + `-DHEXA_CUDA` syntax-check).
  - **4-D-6-4** — d=768·12L A2 trainer regen + Mac build verification +
    F-RFC054-CACHE-FARR-FIT arithmetic check. Gate: F-RFC054-D768-BUILDS clean.
  - **4-D-6-5** — cost-bearing d=768·12L GPU fire ($1-5, reliability>0.95 pod).
    Gate: F-RFC054-D768-GPU-DISPATCH + F-RFC054-D768-WALL. This is the step that
    finally produces the F-RFC046 wall number Phase 4-D-5-4 could not.
- **Decision gate**: 4-D-6-1's first commit picks Option A vs. Option B (§6.3
  recommends A). Record `결정 1: <picked> · <rationale>` per
  step-by-step-decision-gate.
- **Cross-link in PLAN.md**: this RFC (`inbox/rfc_drafts_2026_05_12/
  rfc_054_flame_dimgeneric_a2_emitter.md`) is the Phase 4-D-6 design SSOT.

---

*RFC 054 — flame dimension-generic A2 emitter. Design draft, 2026-05-17.
DESIGN ONLY — implementation is Phase 4-D-6 parallel work.*
