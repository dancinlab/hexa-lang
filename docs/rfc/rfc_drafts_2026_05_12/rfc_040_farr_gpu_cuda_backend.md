# RFC 040 — `farr` GPU/CUDA backend (device-farr + kernel dispatch)

- **Status**: design-draft (2026-05-16) — DESIGN ONLY, no implementation
- **Date**: 2026-05-16
- **Severity**: HIGH (blocks real-scale d=768·12L hexa-native language
  training; CPU-only `farr_matmul` is days–weeks-infeasible)
- **Priority**: P1 (anima `HEXAD/PLAN.md` §9 "GPU 기질 (substrate)
  로드맵" entry point — sub-task (1) "hexa-lang CUDA 경로 신설" is the
  named prerequisite for sub-tasks (2)→(4))
- **Source convergence**: anima `HEXAD/PLAN.md` §9 components
  (1) hexa-lang CUDA path, (2) device farr, (3) d_train5 GPU wire,
  (4) vast.ai GPU dispatch — components (1) and (2) are the
  hexa-lang-side scope of this RFC; (3)/(4) are anima-side consumers.
- **Source session**: anima 2026-05-16 — §7 #1 fire honest-C3 named the
  real limit ("pure-hexa = CPU farr 연산, GPU CUDA 텐서커널 없음"),
  user directive "GPU 기질 PLAN 등록 후 진행" → `HEXAD/PLAN.md` §9
  REGISTERED 2026-05-16, this RFC is that §9 entry point.

## Scope of this RFC — DESIGN DRAFT, honest framing

This is a **design document only**. It proposes the architecture of a
CUDA backend for the `farr` family; it lands **zero CUDA code**, does
not modify `self/runtime.c`, and builds nothing. It defines the surface,
the device-farr model, the dispatch design, the verification battery,
and a staged plan with honest per-phase effort estimates. Implementation
is a separate multi-cycle effort gated on this design's acceptance.

The RFC is deliberately conservative: a GPU backend is a large new
subsystem, and AGENTS.tape `g3` (verification-anchor-real-limit) plus
`g_blue_closed_mandate` (§0 — every artifact *and connection point* must
be 🔵 closed-verified) forbid over-claiming. The CPU↔GPU boundary is
itself a connection point that this RFC treats as a first-class
verification target, not an afterthought.

## Problem

anima's HEXAD trainer `HEXAD/D/d_train5_lib.hexa` (the FULL n_layer
ConsciousDecoderV2-equivalent) runs *pure-hexa*: every matrix operation
flows through `farr_matmul` (RFC 032) and the autograd ops (RFC 034
`ad_matmul` / `ad_softmax_cross_entropy` / `ad_backward` / `adamw_step`)
on the CPU. The v1 `farr_matmul` is a single-thread scalar `ikj` triple
loop (RFC 032 §Algorithm) — correct and bit-exact, but ~tens of GFLOP/s.

A real-scale decoder LM at **d=768, 12 layers, ~100M+ parameters** has a
training-step FLOP budget that makes the CPU path days-to-weeks per fire:

- Per token, per layer the forward is ~6 `farr_matmul` calls (QKV proj,
  attention scores, attention·V, output proj, two MLP projections),
  each O(d²) or O(d·seq). The backward (RFC 034 `ad_matmul` records
  `dA = dC@Bᵀ`, `dB = Aᵀ@dC`) roughly doubles that.
- At d=768·12L·seq the per-step MAC count is in the 10⁹–10¹⁰ range; a
  scalar CPU loop at ~10 GFLOP/s yields second-to-minutes *per step*,
  and a real fire is 10³–10⁵ steps.

This is the **g3-named real limit** recorded in `HEXAD/PLAN.md` §7 #1
honest-C3 and §9: not a hexa-lang bug, but the absence of a GPU tensor
path. A CUDA backend that routes the same `farr` ops to GPU device
memory + cuBLAS / custom kernels closes the gap (10²–10³× on matmul),
while preserving the existing CPU path as the verification oracle and
the no-GPU fallback.

### Hot-path op survey (what d_train5 actually calls)

Surveyed against `HEXAD/D/d_train5_lib.hexa` + RFC 032/033/034/035, the
ops that must have a GPU kernel for a d=768·12L train step to run on
device are:

| Op | Source RFC | Role in d_train5 | GPU kernel |
|---|---|---|---|
| `farr_matmul` | RFC 032 | every linear / QKV / attn / MLP proj | cuBLAS `Dgemm` (primary) |
| `ad_matmul` fwd+bwd | RFC 034 | autograd-recorded matmul (`dA=dC@Bᵀ`, `dB=Aᵀ@dC`) | cuBLAS `Dgemm` ×3 |
| elementwise add / mul | RFC 034 `ad_add`/`ad_mul` | residual sum, gating | custom `__global__` 1-D |
| `ad_relu` / GELU | RFC 034 | MLP nonlinearity | custom `__global__` 1-D |
| softmax (rows) | RFC 034 `ad_softmax_cross_entropy` fwd | attention scores, logits | custom block-reduction kernel |
| row reductions (sum/max) | RMSNorm, softmax denom, CE loss | layer norm + loss | custom block-reduction kernel |
| `ad_softmax_cross_entropy` bwd | RFC 034 | loss grad `(softmax−onehot)/n_rows` | custom 1-D + reuse fwd |
| `adamw_step` / `adamw_step_mixed` | RFC 034 / 035 | optimizer update | custom 1-D fused kernel |
| `farr_add_gaussian_noise` | RFC 033 | mitosis split perturbation | cuRAND or host-noise + H2D |
| `farr_copy` | RFC 033 | ckpt / cell-state copy | `cudaMemcpy` D2D |
| `farr_to_bf16` / `farr_from_bf16` | RFC 035 | mixed-precision carriers | custom 1-D pack/unpack |

`farr_matmul` is the single dominant cost (>90% of step FLOPs); the rest
are memory-bandwidth-bound elementwise/reduction kernels. **Phase A of
this RFC scopes `farr_matmul` alone** — it is both the highest-leverage
op and the cleanest equivalence target (a single closed numeric
contract). The remaining ops are Phase B.

## Proposal

### 1. Device-farr model — extending the RFC 025 handle table

RFC 025 (mmap zero-copy load) established `HexaFarrEntry` slots in
`_hx_farr_table` holding a `double* buf` + `int64_t len` of host memory.
RFC 040 extends each entry with a **residence descriptor** so a farr
handle can name either host memory, device memory, or both:

```c
// proposed extension to HexaFarrEntry (self/runtime.c) — DESIGN ONLY
typedef enum { FARR_HOST = 0, FARR_DEVICE = 1, FARR_MIRRORED = 2 } FarrLoc;

typedef struct {
    double*   buf;        // host pointer (RFC 025) — NULL if device-only
    double*   d_buf;      // CUDA device pointer — NULL if host-only
    int64_t   len;        // element count (shared by both buffers)
    FarrLoc   loc;        // current residence
    int       dirty_host; // host buf stale vs device (needs D2H before host read)
    int       dirty_dev;  // device buf stale vs host (needs H2D before kernel)
} HexaFarrEntry;          // (RFC 025 fields kept; 4 new fields)
```

Design principles:

- **Handle stability** — a farr_id never changes when it moves host⇄
  device. All existing hexa code (`farr_get`, `farr_set`, `farr_matmul`,
  every `ad_*`) keeps working on the same integer handle. The location
  is an *internal* property of the slot, not the ABI.
- **Lazy, tracked transfer** — `dirty_host` / `dirty_dev` flags make
  transfer implicit: a kernel dispatch first ensures `d_buf` is current
  (H2D if `dirty_dev`), a host-side `farr_get` first ensures `buf` is
  current (D2H if `dirty_host`). No silent double-copy: a buffer already
  resident and clean is used in place.
- **Explicit escape hatches** — for hot loops the implicit policy adds
  redundant transfers; the surface (below) exposes `farr_to_device` /
  `farr_to_host` / `farr_pin` so d_train5 can keep weights resident on
  device across all steps and only move the per-step input/loss.
- **`MIRRORED` for weights** — checkpoint weights loaded once via RFC
  031 BF16 reader can be `MIRRORED` (valid on both sides) so the CPU
  oracle path and the GPU path read the same bytes for verification.

This is the minimal extension: RFC 025's host path is untouched when
`d_buf == NULL && loc == FARR_HOST` (every existing farr), so the CPU
fallback is the *default* and a no-CUDA build is byte-identical to
today.

### 2. Surface — new builtins (additive, CPU-fallback-safe)

```hexa
// ── device management ─────────────────────────────────────────────
pub fn cuda_available() -> int          // 1 if a CUDA device + toolkit
                                         //   present at runtime, else 0
pub fn cuda_device_count() -> int        // number of visible GPUs (0 = none)
pub fn farr_to_device(id: int) -> int    // ensure d_buf resident+current;
                                         //   1 ok / 0 err / -1 no-cuda
pub fn farr_to_host(id: int) -> int      // ensure host buf current (D2H)
pub fn farr_pin(id: int) -> int          // mark resident-on-device, do
                                         //   not auto-evict (weights)
pub fn farr_device_free(id: int) -> int  // free d_buf, keep host buf

// ── GPU-routed compute (same math contract as the CPU op) ─────────
pub fn farr_matmul_gpu(A: int, Ar: int, Ac: int,
                       B: int, Bc: int) -> int   // C = A@B on device
```

`farr_matmul_gpu` is **ABI-identical** to RFC 032 `farr_matmul`: same
arity, same shape contract (`A` is M×K row-major, `B` is K×N row-major,
output is a freshly-allocated M×N farr), same `-1`-on-shape-error
return. The *only* difference is residence: it ensures `A`/`B` are on
device, runs a GPU kernel, and returns a device-resident output farr
(`loc = FARR_DEVICE`, `dirty_host = 1`).

**Routing — implicit upgrade of the existing `farr_matmul`.** Rather
than force every caller to choose, RFC 040 proposes `farr_matmul` (the
RFC 032 name) become a *dispatcher*: if `cuda_available()` and both
operands are device-resident-or-large-enough, it routes to the GPU
kernel; otherwise it runs the RFC 032 CPU loop. d_train5 then needs **no
arch change** — it keeps calling `farr_matmul` — and `HEXAD/PLAN.md` §9
sub-task (3) ("코드는 dimension-generic 이라 arch 변경 최소, backend 만
교체") is satisfied by construction. `farr_matmul_gpu` stays as an
explicit-force entry for the verification harness (which must compare
GPU vs CPU on the *same* inputs).

The same implicit-dispatch pattern applies to the `ad_*` ops in Phase B:
`ad_matmul` already wraps `farr_matmul` (RFC 034 §Implementation), so it
inherits GPU routing for free once `farr_matmul` dispatches; the
elementwise/reduction `ad_*` ops get a GPU branch keyed on operand
residence.

### 3. Kernel dispatch design

**matmul — cuBLAS primary.** `farr_matmul_gpu` calls cuBLAS
`cublasDgemm` (f64, matching the packed-double farr representation). The
RFC 032 §Risks note already states the farr path runs f64 accumulation;
`cublasDgemm` is the natural device match — *not* `Sgemm`, which would
lose the precision contract. (A `Sgemm` + bf16 tensor-core variant is a
Phase B perf option, gated behind its own falsifier, not v1.)

**elementwise / reduction — custom `__global__` kernels.** Add/mul/relu/
GELU are 1-D grid-stride kernels. Softmax and RMSNorm reductions use a
block-per-row layout with a warp-shuffle reduction (`__shfl_down_sync`).
AdamW is a single fused 1-D kernel updating `param`, `m`, `v` in place.
These are small, well-understood kernels; the design names them but
defers their code to Phase B.

**Build / link.** A new optional build mode:

- `nvcc` detection at `hexa cc` time: probe `nvcc --version` and
  `CUDA_HOME`/`CUDA_PATH`. If absent → **CUDA path compiled out**
  entirely (`#ifndef HEXA_CUDA`), `cuda_available()` returns 0, every
  `*_gpu` builtin returns `-1`, and `farr_matmul` runs the RFC 032 CPU
  loop. A no-GPU host (e.g. the Mac dev box) builds and behaves exactly
  as today.
- When present, `.cu` kernel files compile via `nvcc` to objects linked
  with `-lcudart -lcublas` (and `-lcurand` if the noise kernel uses it).
  The hexa-lang build (`self/hexa_cc.c` / stage1) gains a `cuda` object
  group, conditionally appended to the link line.
- `HEXA_CUDA=0` environment override forces the CPU path even on a
  GPU box (parity-testing convenience, mirrors RFC 028 local-only-mode
  and RFC 026 dispatcher env-passthrough conventions).

**Determinism.** cuBLAS `Dgemm` with a fixed algorithm and a single
stream is run-to-run deterministic on a given GPU+driver. The kernels
are written to avoid atomics in reductions where order matters (tree
reduction, fixed block size) so they are deterministic too. Determinism
is a falsifier (F-GPU-040-DETERMINISM), not an assumption.

## Verification — §8 / `g_blue_closed_mandate` (the critical section)

`HEXAD/PLAN.md` §9 states it plainly: *"GPU 커널은 CPU farr 와
byte-equal (또는 fp tolerance 내) 여야 — CPU↔GPU 연결고리 = 수치 동치
closed 검증 mandatory."* The CPU↔GPU boundary is a **connection point**;
under AGENTS.tape §0 `g_blue_closed_mandate` a connection point is
verified only when (A) both ends are 🔵 SUPPORTED-FORMAL **and** (B) the
transfer-function / invariant across the connection is itself
closed-form verified.

- **End A (CPU farr)** — already 🔵: RFC 032 `farr_matmul` is a fixed
  deterministic `ikj` loop, bit-exact and reproducible (RFC 032 §Risks).
  It is the **oracle**.
- **End B (GPU farr)** — `farr_matmul_gpu` / the kernels — must be
  verified *against the CPU oracle* on identical packed-double inputs.
- **The connection invariant** — the closed-form property the CPU↔GPU
  link must preserve is **numerical equivalence**: `C_gpu ≈ C_cpu` with
  a *stated, honest* tolerance (see Honest caveats — exact bit-equality
  is NOT claimed for fp-reduction kernels). Equivalence is closed: for
  any input pair the max element-wise `|Δ|` is a single computable
  number checked against a fixed bound.

### Falsifier battery (F-GPU-040-*)

Every falsifier runs the **compiled-native** path (no Python, no interp
— matches anima `HEXAD/build_verify.sh`), and each compares against the
RFC 032 CPU result on the *same* farr inputs.

- **F-GPU-040-AVAIL** — `cuda_available()` returns a coherent value;
  on a no-GPU build it is 0 and every `*_gpu` builtin returns `-1` with
  no crash and no leak; on a GPU build it is 1 and `cuda_device_count()
  ≥ 1`. (The graceful-fallback gate — proves a Mac dev box still works.)
- **F-GPU-040-MATMUL-IDENT** — `I_n @ M ≡ M` on GPU, max `|Δ| = 0`
  exactly (identity matmul has no reduction reordering → must be exact).
- **F-GPU-040-MATMUL-EQ** — for a battery of shapes (`32×64@64×32`,
  `64×128@128×64`, `768×768@768×768`) `farr_matmul_gpu` vs RFC 032
  `farr_matmul` on identical random farr: max `|Δ| < TOL_MATMUL` (the
  stated f64 cuBLAS tolerance — see Honest caveats). This is the
  CPU↔GPU connection-point closed equivalence check.
- **F-GPU-040-ZERO** — `M @ zeros` = `zeros` on GPU, exact.
- **F-GPU-040-SOFTMAX-EQ** — row-softmax GPU kernel vs the CPU softmax
  inside RFC 034 `ad_softmax_cross_entropy`: max `|Δ| < TOL_ELEM`.
- **F-GPU-040-REDUCE-EQ** — row sum/max reductions (RMSNorm denom, CE
  loss) GPU vs CPU: max `|Δ| < TOL_ELEM`.
- **F-GPU-040-ADAMW-EQ** — one `adamw_step` GPU vs CPU on identical
  `param`/`grad`/`m`/`v`: post-update max `|Δ| < TOL_ELEM`.
- **F-GPU-040-TRANSFER-RT** — `farr_to_device` then `farr_to_host`
  round-trip on a random farr: byte-identical (H2D/D2H is a pure copy,
  must be **exact** — `|Δ| = 0`).
- **F-GPU-040-STEP-EQ** — one full d_train5 train step (forward + CE +
  backward + AdamW) GPU vs CPU on a small fixed substrate (d=64, 2L):
  post-step parameter max `|Δ| < TOL_STEP` and loss `|Δ| < TOL_STEP`.
  This is the end-to-end connection-point check — the whole pipeline,
  not just one op.
- **F-GPU-040-DETERMINISM** — the same GPU train step run twice:
  byte-identical output (`|Δ| = 0`). cuBLAS fixed-algorithm + atomic-
  free reductions → run-to-run reproducible.
- **F-GPU-040-MEM** — 100 consecutive `farr_matmul_gpu` + matching
  `farr_device_free` calls: the device allocation does not monotonically
  grow beyond a known bound (no device-memory leak — the GPU analogue
  of RFC 032 F-RFC-032-MEM).
- **F-GPU-040-INVARIANT-PRESERVED** — the HEXAD math/physics invariants
  that the d_train5 step must preserve are still PASS on the GPU path:
  **CE Shannon-floor** (loss ≥ entropy floor) and **Law-70 Ψ-coupling
  bridge clamp** (`HEXAD/PLAN.md` §8 — clamp ∈ [Ψ−α, Ψ+α]). The GPU
  backend is a numeric substrate swap; it must NOT change which
  closed-form invariants hold. (g3 — at least one *real* limit, not a
  lattice tautology: the Shannon entropy floor is the real-limit
  anchor.)

(≥ 3 per AGENTS.tape directive; this RFC specifies 12.)

The acceptance gate: every Phase's falsifier subset PASS on the
compiled-native binary before that Phase is counted LANDED. The
`*-EQ` falsifiers are the `g_blue_closed_mandate` connection-point
checks — they are mandatory and may not be replaced by a structural
"the kernel ran" check.

## Phasing

A staged plan; each phase is its own cycle with its own falsifier
subset and its own LANDED gate. Effort estimates are honest and
deliberately wide — a GPU backend is new subsystem territory.

### Phase A — `farr_matmul` GPU + equivalence harness

- Device-farr table extension (residence descriptor, dirty flags).
- `cuda_available` / `cuda_device_count` / `farr_to_device` /
  `farr_to_host` / `farr_device_free` builtins.
- `farr_matmul_gpu` via `cublasDgemm`; `farr_matmul` becomes the
  dispatcher.
- `nvcc` detection + conditional build; no-CUDA build byte-identical to
  today.
- Falsifiers: F-GPU-040-AVAIL, -MATMUL-IDENT, -MATMUL-EQ, -ZERO,
  -TRANSFER-RT, -DETERMINISM, -MEM.
- **Effort: ~1 large cycle.** Highest-leverage (>90% of step FLOPs),
  cleanest equivalence target. This is the §9 sub-task (1) core.

### Phase B — remaining ops (elementwise / softmax / reduction / AdamW)

- Custom `__global__` kernels for add/mul/relu/GELU, row-softmax,
  row-reductions (sum/max), fused AdamW, bf16 pack/unpack.
- `ad_*` ops gain GPU branches (most inherit via `ad_matmul`→
  `farr_matmul`).
- Falsifiers: F-GPU-040-SOFTMAX-EQ, -REDUCE-EQ, -ADAMW-EQ.
- **Effort: ~1–2 cycles.** Memory-bandwidth-bound kernels, each small;
  the harness pattern is reused from Phase A.

### Phase C — d_train5 full GPU wire

- Wire `HEXAD/D/d_train5_lib.hexa` so weights `farr_pin` to device once
  and stay resident across all steps; only per-step input/loss transfer.
- Verify the full step end-to-end vs the CPU oracle.
- Falsifiers: F-GPU-040-STEP-EQ, -INVARIANT-PRESERVED.
- **Effort: ~1 cycle, anima-side** (`HEXAD/PLAN.md` §9 sub-task (3) —
  "backend 만 교체"). hexa-lang side is minimal once A+B land.

### Phase D — real d=768·12L fire

- vast.ai GPU dispatch (H100/A100), `g_fire_autonomous` autonomous +
  `g_fire_dispatch_robust` (SAVE_POD auto-promote + pull-retry ≥3).
- The actual real-scale train fire — `HEXAD/PLAN.md` §9 sub-task (4).
- **Effort: 1 fire cycle; cost ~$2–30/GPU-hr × train hours** (per §9 —
  the honest cost envelope; a real d=768·12L fire is plausibly $10–100s
  depending on step count).

Phases A→D are strictly sequential: B depends on A's device-farr table,
C depends on A+B's full op coverage, D depends on C's verified wire.

## Honest caveats (AGENTS.tape g3 / f2 — no over-claim)

- **fp non-associativity — exact bit-equality is NOT claimed.** cuBLAS
  `Dgemm` and the CPU `ikj` loop sum the K-dimension reduction in
  *different orders* (and cuBLAS may tile/block internally). Floating-
  point addition is non-associative, so `C_gpu` will generally differ
  from `C_cpu` in the last few ULPs. RFC 040 therefore states a
  **tolerance**, not bit-equality, for reduction kernels:
  - `TOL_MATMUL` — proposed `< 1e-9` relative for f64 `Dgemm` (this is
    a *proposed starting bound*; the implementing cycle must measure the
    actual max `|Δ|` and either confirm or honestly widen it — the bound
    is calibrated by measurement, never asserted by hope).
  - `TOL_ELEM` — `< 1e-12` for elementwise (no reduction → essentially
    exact) and softmax/reduction kernels.
  - `TOL_STEP` — the looser end-to-end bound for F-GPU-040-STEP-EQ,
    accumulating per-op tolerance over a full step; proposed `< 1e-6`,
    measurement-calibrated.
  - Transfers (`F-GPU-040-TRANSFER-RT`) and identity/zero matmul **are**
    bit-exact (`|Δ| = 0`) — those have no reduction reordering — and the
    falsifiers demand exactness there. The honest split: *exact where
    the math permits, tolerance where fp non-associativity forbids it,
    and the tolerance is a measured number, never a fudge.*
- **The connection point is verified at tolerance, and that is honest
  not weak.** `g_blue_closed_mandate`'s `honest_carve_out` already
  recognizes that closed-form 🔵 verification can have a measured-
  empirical residue (the SGD-outcome carve-out). The CPU↔GPU
  equivalence is *stronger* than that: the transfer-function (numerical
  equivalence within a measured fp bound) IS closed-form — for any input
  the max `|Δ|` is a single computable, checkable number. What is NOT
  closed is *bit-equality*, and RFC 040 does not claim it. This is the
  g3-compliant honest framing: the connection is closed-verified at a
  stated tolerance; the tolerance itself is named, not hidden.
- **CUDA toolkit / GPU availability is an environment assumption.** The
  GPU path requires a CUDA-capable device, the CUDA toolkit (`nvcc`,
  cuBLAS, cudart), and a matching driver at *both* build and run time.
  None of these exist on the Mac dev box. The design's no-CUDA fallback
  (`#ifndef HEXA_CUDA`, `cuda_available()→0`, CPU `farr_matmul`) makes a
  no-GPU build a first-class, fully-tested configuration — but the GPU
  path itself can only be built and falsifier-verified on a CUDA host
  (Phase A–C verification runs on a GPU box; vast.ai dispatch in Phase
  D, or a borrowed GPU host).
- **This is a large multi-cycle effort.** `HEXAD/PLAN.md` §9 names it
  "대형 다-사이클 프로젝트". RFC 040 is the *design entry point* only.
  It lands no CUDA code. Phases A–D are separate cycles; the effort
  estimates above are wide-banded on purpose. A GPU backend touches the
  build system, the farr handle table, the link line, and adds a new
  hardware dependency — the RFC does not pretend any of that is small.
- **cuBLAS dependency, not a from-scratch GEMM.** Phase A leans on
  cuBLAS `Dgemm` rather than a hand-written CUDA GEMM. This is a
  deliberate scope choice (a competitive hand-tuned GEMM is itself a
  multi-month effort); it adds `-lcublas` as a dependency. A custom GEMM
  is explicitly a non-goal of v1 and named as a possible future RFC.
- **No lattice-tautology in the verification.** Per AGENTS.tape `f2`,
  none of the F-GPU-040-* falsifiers verify by a lattice identity. The
  real-limit anchor is the **Shannon entropy floor** on the CE loss
  (F-GPU-040-INVARIANT-PRESERVED) and **numerical equivalence to a
  bit-exact reference computation** — both real math, not `σ·φ=24`.

## Non-goals (v1 / this RFC)

- No CUDA code, no `runtime.c` edit, no build — design draft only.
- No hand-written competitive CUDA GEMM (cuBLAS `Dgemm` is the v1 path).
- No tensor-core / bf16 `Sgemm` fast path (a Phase B+ perf option with
  its own falsifier — would relax the precision contract).
- No multi-GPU / distributed training (single-device v1).
- No CUDA-graph capture / stream-overlap optimization (v1 is a single
  default stream for determinism).
- No ROCm / Metal / other accelerator backends (the design's
  device-farr table is backend-agnostic enough to admit them later, but
  v1 is CUDA only).
- No change to the RFC 032 CPU `farr_matmul` algorithm — it stays the
  bit-exact oracle and the no-GPU fallback.

## Cross-RFC dependency

- **RFC 025** (mmap zero-copy farr) — the `HexaFarrEntry` /
  `_hx_farr_table` handle table this RFC extends with a residence
  descriptor.
- **RFC 031** (BF16→f32 farr reader) — checkpoint weights it loads can
  be `MIRRORED` for CPU-oracle / GPU parity.
- **RFC 032** (`farr_matmul` native builtin) — the CPU op that becomes
  the verification oracle and the no-GPU fallback; `farr_matmul` becomes
  the GPU/CPU dispatcher.
- **RFC 033** (`farr_copy` / `farr_add_gaussian_noise`) — copy maps to
  `cudaMemcpy` D2D; noise to cuRAND or host-noise + H2D.
- **RFC 034** (`farr` reverse-mode autograd) — `ad_matmul` /
  `ad_softmax_cross_entropy` / `ad_backward` / `adamw_step` inherit GPU
  routing (most via `ad_matmul`→`farr_matmul` dispatch); Phase B.
- **RFC 035** (bf16 mixed-precision train) — `farr_to_bf16` /
  `farr_from_bf16` / `adamw_step_mixed` get GPU pack/unpack kernels.
- **RFC 026** (dispatcher env-passthrough) / **RFC 028** (local-only
  mode) — the `HEXA_CUDA=0` force-CPU override follows their env-var
  convention.

## Cross-link

- anima `HEXAD/PLAN.md` §9 "GPU 기질 (substrate) 로드맵" — this RFC is
  the §9 entry point; §9 sub-tasks (1)+(2) are this RFC's hexa-lang
  scope, (3)+(4) are the anima-side consumers (Phases C+D).
- anima `HEXAD/PLAN.md` §8 "검증 표준 — 수학·물리 + 연결고리" — the
  CPU↔GPU boundary is the connection point §8 requires be math/physics
  verified, not merely structurally checked.
- anima `AGENTS.tape` §0 `g_blue_closed_mandate` — every artifact AND
  connection point 🔵 closed; the F-GPU-040-*-EQ falsifiers are the
  connection-point closed checks.
- anima `AGENTS.tape` `g3` (verification-anchor-real-limit) / `f2`
  (no lattice-tautology) — the Shannon entropy floor + bit-exact
  reference equivalence are the real-limit anchors.
- anima `HEXAD/D/d_train5_lib.hexa` — the FULL n_layer
  ConsciousDecoderV2-equivalent trainer; Phase C wires it to the GPU
  backend with minimal arch change (dimension-generic code).
- anima `g_fire_autonomous` + `g_fire_dispatch_robust` — Phase D
  vast.ai GPU dispatch governance.
