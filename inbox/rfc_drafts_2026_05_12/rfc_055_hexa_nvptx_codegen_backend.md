# RFC 055 — hexa-src → NVPTX codegen backend (hexa-native GPU)

## 1. Status

- **Status**: **055-P2 LANDED — naive FP64 GEMM `@gpu_kernel` + full falsifier battery measured PASS on a real GPU (2026-05-20)**.
  The NVPTX codegen target hand-emits both a FP64 vec-add and a naive FP64
  GEMM `.visible .entry` kernel; the RFC 055 §7 falsifier battery is
  **measured PASS** on an NVIDIA RTX 5070 (sm_120 · driver 580.126.09),
  closing 055-P1 (vec-add — the prior cycle left it unfired) and 055-P2
  (GEMM) in one $0 fire on the wilson-pool GPU host. Measured verdicts
  (`state/rfc055_p2_2026_05_20/result.json`): **F-RFC055-PTX-EMIT PASS**
  (both PTX modules `ptxas`-accepted + driver-JIT-loaded), **F-RFC055-
  NUMERIC-EQ PASS** (vec-add `max|Δ|=0`, 0/1024), **F-RFC055-GEMM-FEASIBLE
  PASS** (naive GEMM `max|Δ|=0`, 0/4096 — integer inputs → byte-exact),
  **F-RFC055-LAUNCH-ABI PASS** (host→kernel→host, 1-D + 2-D launch),
  **F-RFC055-NO-LLVM PASS**, **F-RFC055-CPU-CODEGEN-UNTOUCHED PASS** (by
  construction). The GEMM keystone is `emit_ptx_gemm_module(target)` — a
  real PTX contraction loop (`$L_LOOP` back-edge, `setp.lt.s32` guard,
  `fma.rn.f64` accumulate); the vec-add keystone is
  `emit_ptx_vec_add_module(target)`. A 055-P0 latent bug was found + fixed
  by the fire: emitted PTX carried non-ASCII bytes (em-dash · arrow · ×)
  in comments — standalone `ptxas` tolerated them, the driver JIT aborts
  on them; all emitted strings are now ASCII, with a regression guard in
  the dispatch script. **What's still 055-P3 (productization):** the MIR
  partition routing a real `@gpu_*` FnDecl to `codegen_nvptx_sm*` (the
  validator still consumes a synthetic `NvptxValidateInput`, not a FnDecl
  walk); the `gpu_launch(...)` host-side lowering (C-side
  `_hx_cuda_launch_kernel` wrapper is implemented, hexa-side lowering is
  P3); the cubin `.rodata` `LSection` embed; the tiled `@shared` +
  `gpu_barrier()` GEMM variant (055-P2-tiled). 055-P2 is the hand-emit +
  measured fire; 055-P3 wires it into the compile pipeline.
- **Original status**: design-draft (2026-05-17) — DESIGN ONLY, no implementation
- **Date**: 2026-05-17 (draft) · 2026-05-19 (Stage 1 scaffold) · 2026-05-19 (055-P0 PTX emit pass) · 2026-05-19 (055-P1 vec-add emit + validator + launch ABI ready-for-dispatch-wire) · 2026-05-20 (055-P2 naive GEMM emit + full falsifier battery measured PASS)
- **Priority**: P2 (architectural enabler — opens the hexa-native GPU path; not on
  any current critical chain. flame/forge ship today on the C/CUDA substrate;
  RFC 055 is the *future* hexa-native tier, not a blocker for either.)
- **Severity**: MEDIUM (closes the last open seam in the hexa-native-only policy
  — CPU codegen is self-hosted, GPU codegen is not. This is a completeness gap,
  not a correctness bug. Nothing breaks today; the policy is simply not yet
  total.)
- **Domain**: **compiler** (not flame, not forge). The deliverable scope is
  `compiler/codegen/nvptx_*.hexa` — a sibling codegen target to the existing
  `arm64_darwin.hexa` / `x86_64_linux.hexa` / `thumbv7em_eabihf.hexa`. forge and
  flame are *consumers* of this RFC's eventual capability, not its subject.

## 2. Source convergence

Three independent threads converge on the same finding — hexa-lang has no GPU
codegen target.

1. **forge's C/CUDA "only path" finding.** `self/forge/` is C/CUDA, not hexa.
   `FORGE.tape` g_forge_substrate_role makes the directory boundary a *mandate*:
   "forge MUST NOT contain hexa source (that's stdlib/). flame MUST NOT contain
   C/CUDA kernels (that's forge)." The honest reason forge is C/CUDA is **not a
   design preference** — it is that C/CUDA is the *only* path: hexa source
   cannot currently be lowered to anything a GPU executes. The user's question
   ("forge is C/CUDA, not hexa — if we want hexa-native GPU kernels, where does
   it go?") has no answer under the current compiler. RFC 055 is that answer.

2. **The hexa-native-only g5 GPU gap.** `AGENTS.tape` §3 g5 ("hexa-native-only")
   says the compiler emits its own machine code. `HEXA-NATIVE-ONLY.md` is a
   roadmap to *drop C kernels* and reach parity in pure-hexa AOT. But
   `HEXA-NATIVE-ONLY.md` §2 axis E5 lists `GPU offload` as a future axis and
   §4 gate G-9 ("GPU lane refinement") is explicitly *unscheduled* — the doc
   addresses CPU codegen exhaustively (axes A–D, F) and leaves GPU codegen as a
   single unspecified line. The CPU side of hexa-native-only is self-hosted
   today (arm64/x86_64/thumbv7 targets in `compiler/codegen/`). The GPU side is
   not — there is no GPU codegen target at all. `AGENTS.tape` §0 nn_stack
   `not_what` states the position outright: *"hexa-src→PTX GPU codegen 백엔드는
   forge 스코프 밖 (미래 별도 RFC)."* RFC 055 **is** that separate RFC.

3. **forge Phase R: the algorithm is feasible, tuning is the gap.** forge's
   Phase R fired 14 cost-bearing GPU measurements (`self/forge/PARADIGM.md`).
   The relevant data point for RFC 055 is the C Stage 2 Phase 3 fire: a
   *hand-written* WMMA (Tensor Core) GEMM reached **41–43% of Tensor Core
   peak** vs cuBLAS at 77–87% (`state/forge_phaseR_c_v3_2026_05_17/`). The
   honest reading: a hand-written kernel — i.e. exactly what a hexa-emitted
   kernel would be — *does run and does produce correct results*. It is not
   competitive with cuBLAS on raw GEMM throughput, but the *algorithm* (a
   WMMA GEMM written by hand, not by a vendor library) is feasible. The gap is
   tuning effort (CUTLASS-level work, measured in weeks), not a fundamental
   wall. This anchors RFC 055's honesty: a hexa-native NVPTX backend can emit
   *correct* GPU kernels; it should not be expected to *beat cuBLAS*.

## 3. Source evidence (g3 — every claim traces to a real capture)

- `AGENTS.tape` §0 nn_stack `not_what` — "hexa-src→PTX GPU codegen 백엔드는 forge
  스코프 밖 (미래 별도 RFC)." This RFC's existence is pre-registered there.
- `AGENTS.tape` §3 g5 "hexa-native-only" — "hexa-lang is self-hosted. No LLVM,
  no C-transpile, no third-party codegen backend." The policy this RFC extends.
- `AGENTS.tape` §4 f2 "llvm-c-transpile-backend" — "adding LLVM IR backend …
  as a default path" is forbidden. RFC 055's design is constrained by f2 (see
  §6 and falsifier F-RFC055-NO-LLVM).
- `HEXA-NATIVE-ONLY.md` §2 axis E5 — "`@gpu` offload" listed as a future axis;
  §4 gate G-9 unscheduled. RFC 055 supplies the missing specification.
- `compiler/codegen/arm64_darwin.hexa` — existing codegen target. Entry point
  `pub fn codegen_arm64_darwin(module: MModule) -> LModule` at line 1853.
  Lowers MIR (SSA CFG) → LIR (target-specific instructions). The sibling
  pattern RFC 055's `compiler/codegen/nvptx_sm90.hexa` follows.
- `compiler/codegen/x86_64_linux.hexa` — `pub fn codegen_x86_64_linux(module:
  MModule) -> LModule` at line 1203. Confirms the per-target pattern: one file,
  one `codegen_<target>` entry, MIR → LModule.
- `compiler/ir/lir.hexa` — the LIR the codegen lowers to. `LInstr { op, args,
  comment }`, `LFunc { name, target, instrs, frame_size, callee_saved,
  def_line }`, `LModule { file, target, funcs, rodata, bss, globals, floats }`.
  LIR is target-specific machine instructions; per-target opcode tables live in
  `codegen/<target>.hexa`. RFC 055 adds a PTX opcode table.
- `self/forge/PARADIGM.md` §1 row "C Stage 2 Phase 3" + §4.5 — hand-WMMA 41–43%
  Tensor Core peak vs cuBLAS 77–87%; `state/forge_phaseR_c_v3_2026_05_17/`.
- `self/forge/FORGE.tape` g_forge_substrate_role + g_forge_no_relocation — the
  C/CUDA-vs-hexa directory boundary that RFC 055 must respect (it does not move
  any forge code; see §8).
- **`self/native/gpu_codegen_stub.c`** — a pre-existing `@gpu` codegen backend
  **skeleton** ("rt#45-research scaffold", placeholder-only, no real emission;
  it locks a C ABI between `hexa_cc.c` and a future GPU backend). Discovered
  2026-05-19 (`@N native_dir`). RFC 055 was drafted unaware of it. **RFC 055
  must reconcile**: either (a) supersede the rt#45 stub (RFC 055's
  `compiler/codegen/nvptx_*.hexa` is the hexa-native answer, the C stub is the
  abandoned bootstrap-era attempt → tombstone it), or (b) adopt the stub's
  already-fixed C ABI as the bootstrap seam. The stub's companion design
  `docs/rt-45-gpu-design.md` is referenced in its header but is **MISSING** —
  so option (a), supersede, is the likely honest call. This is a pre-existing-
  work overlap the RFC must not silently ignore.

## 4. Scope

**DESIGN draft only.** RFC 055 specifies the *shape* of a hexa-src → NVPTX
codegen backend — the new codegen target file, the IR concepts a GPU target
needs, the hexa surface for marking a GPU kernel, the launch ABI choice, and a
pre-registered falsifier battery. It adds **no** `.hexa` codegen code, **no**
`.cu`, **no** `.ptx`.

Implementation is a **multi-cycle compiler project**. PTX is a large ISA; a
GPU codegen target is comparable in effort to the existing arm64/x86_64 targets
*plus* the GPU-execution-model concepts those targets never needed (thread
hierarchy, address spaces, barriers, warp primitives). This RFC scopes the
*first* implementable slice (FP64 arithmetic subset, no Tensor Core) and leaves
the rest as named sub-phases.

This RFC does **not** modify `self/forge/*` or `compiler/codegen/*`. It
references them; it changes nothing.

## 5. Problem — the hexa compiler has no GPU codegen target

The hexa compiler lowers source through HIR → MIR → LIR and emits machine code
for exactly three target families:

```
compiler/codegen/arm64_darwin.hexa       → AAPCS64    (Apple Silicon)
compiler/codegen/x86_64_linux.hexa       → System V   (Linux x86_64)
compiler/codegen/thumbv7em_eabihf.hexa   → EABI-HF    (Cortex-M4F)
```

Every one of these is a **CPU** target. There is no codegen target that emits
anything a GPU executes. Consequently:

- **GPU kernels must be hand-written in C/CUDA.** This is exactly why
  `self/forge/` is a C/CUDA substrate and `self/cuda/*.cu` holds hand-written
  kernels. It is not a stylistic choice — under the current compiler it is the
  *only* path. A hexa programmer who wants a GPU kernel cannot write it in hexa;
  they must drop to `.cu`.

- **This is the last open seam in hexa-native-only.** `HEXA-NATIVE-ONLY.md`
  drove CPU codegen to genuine self-hosting: hexa source → hexa AOT → machine
  code, no LLVM, no C-transpile-as-architecture. The CPU half of the policy is
  real. The GPU half is not — there is *no* hexa-native GPU codegen. g5 says
  "the compiler emits its own machine code"; for GPU code, it emits nothing.

- **The gap is structural, not incidental.** A GPU target is not just "another
  ABI." It needs IR concepts the CPU targets never modelled: a thread/block/grid
  launch hierarchy, multiple memory address spaces (global / shared / local /
  constant), explicit barriers, warp-level primitives. The MIR/LIR pipeline was
  designed for a flat single-threaded CPU machine model. RFC 055's job is to
  specify the *minimal* extensions that let GPU codegen exist without disturbing
  the CPU targets.

Concretely: today a hexa-native GPU kernel — a "hexa cuBLAS alternative" — has
**nowhere to live**. forge cannot hold it (g_forge_substrate_role: forge is
C/CUDA only). flame cannot hold it (flame is hexa stdlib, and the compiler
can't lower hexa source to GPU code). The blocker is the missing codegen
target. RFC 055 unblocks it.

## 6. Proposal — hexa-src → NVPTX codegen backend

### 6.1 New codegen target file

A new file, sibling to the existing CPU targets:

```
compiler/codegen/nvptx_sm90.hexa     → NVPTX, sm_90 (Hopper: H100/H200)
compiler/codegen/nvptx_sm80.hexa     → NVPTX, sm_80 (Ampere: A100)   [variant]
```

Entry point follows the established pattern:

```
pub fn codegen_nvptx_sm90(module: MModule) -> LModule
```

Same signature shape as `codegen_arm64_darwin` and `codegen_x86_64_linux` —
MIR in, `LModule` out. The `LModule.target` field carries a new value,
`"nvptx64-nvidia-cuda-sm90"`. The two `sm_*` variants share lowering logic;
they differ in the PTX `.target` directive and the available instruction set
(Hopper adds `wgmma`, larger shared memory, distributed shared memory). The
sm_80 variant is the conservative baseline; sm_90 is additive.

### 6.2 PTX ISA emission path

```
hexa source
  → HIR → MIR (SSA CFG; unchanged)
  → LIR  (codegen/nvptx_sm90.hexa lowers MIR → PTX-flavored LIR)
  → PTX assembly text  (emit pass; .ptx file — a text artifact)
  → ptxas              (NVIDIA PTX→SASS assembler — external tool, see §8)
  → cubin              (GPU machine code, loadable module)
```

The hexa compiler emits **PTX assembly text directly**. PTX is itself a
virtual ISA (a stable text format, like assembly); the codegen target produces
PTX-flavored `LInstr` records whose `op` field is a PTX mnemonic (`ld.global.f64`,
`mul.f64`, `bar.sync`, `st.shared.f64`, …), exactly as `arm64_darwin.hexa`
produces `LInstr` records with arm64 mnemonics. The existing LIR `LInstr` /
`LFunc` / `LModule` structs are reused as-is for the text-emission stage; PTX's
SSA-with-virtual-registers form is actually a *better* fit for the MIR→LIR
boundary than the CPU targets' physical-register form (PTX virtual registers
need no register allocator pass — `ptxas` does that downstream).

This is the **g5 / f2 boundary**: the hexa compiler emits PTX text. It does
**not** emit LLVM IR and route through LLVM's NVPTX backend. PTX is to the GPU
what assembly is to the CPU — emitting it directly is hexa-native codegen.
`ptxas` is an external *assembler* (see §8 caveat) — the same role `clang`/`as`
plays for the C-fallback portability path, not part of the architecture.

### 6.3 GPU-specific IR concepts

The CPU targets model a flat single-threaded machine. A GPU target needs four
concepts the MIR/LIR pipeline does not currently carry. RFC 055 proposes adding
them as **additive, GPU-only LIR/MIR annotations** — invisible to the CPU
targets (falsifier F-RFC055-CPU-CODEGEN-UNTOUCHED guards this):

| Concept | What it is | Lowering |
|---|---|---|
| **Thread hierarchy** | `thread / block / grid` indices | PTX special registers `%tid`, `%ctaid`, `%ntid`, `%nctaid` — read via `mov.u32` from the named sreg. Surfaced to hexa as builtins (see §6.4). |
| **Address spaces** | `global / shared / local / constant / param` | PTX state-space-qualified ops (`ld.global`, `ld.shared`, `ld.const`). A farr passed to a kernel is `.global`; a `@shared` local is `.shared`. |
| **Barriers** | block-wide synchronization | `bar.sync 0` — emitted at an explicit hexa `gpu_barrier()` builtin call site. |
| **Warp primitives** | `shfl`, warp vote, warp reduce | `shfl.sync.*`, `vote.sync.*` — surfaced as builtins (`warp_shuffle`, `warp_reduce_add`). Optional sub-phase; FP64-arith slice does not need them. |

A function compiled for the NVPTX target additionally carries a **function
kind**: a PTX `.visible .entry` (a kernel — `__global__` in CUDA terms,
launchable from host) vs a PTX `.func` (a device function — `__device__`,
callable only from other GPU code). This is the GPU analogue of the CPU
distinction between an exported symbol and a static helper.

### 6.4 hexa surface + 6.5 launch ABI — specified in `gpu/SPEC.md`

The `@gpu` *language surface* — the `@gpu_kernel` / `@gpu_device`
attributes, the type + statement allowlist / denylist, the thread-index
and sync intrinsics, the `@shared` memory model, and the `gpu_launch`
host launch ABI — is specified in **`gpu/SPEC.md`**, the `@gpu` subset
SSOT (`gpu/design.md` Decision 3). RFC 055 is the *codegen target* that
lowers that surface to NVPTX; it deliberately does **not** re-specify it
(that duplication is what Decision 3 removed).

Summary for this RFC's purpose: a kernel is a normal hexa `fn` carrying
`@gpu_kernel` (→ PTX `.visible .entry`, `void` return — results go to a
`.global` farr the host reads back) or `@gpu_device` (→ PTX `.func`,
device-only helper). The compiler partitions a source file by attribute
— `@gpu_*` functions route to the NVPTX target, every other function
continues to the host CPU target. Thread/block indices are read via
`gpu_*` intrinsics; the launch syscall reuses forge's cudart binding via
a `gpu_launch` builtin lowering to `hexa_cuda_launch_kernel`. See
`gpu/SPEC.md` §2–§9 for the normative detail and the `GPU0N` strict-lint
codes.

### 6.6 Honest scoping — FP64 first, Tensor Core later

RFC 055's *first implementable slice* is deliberately narrow:

- **FP64 scalar/vector arithmetic only.** `ld.global.f64`, `st.global.f64`,
  `add.f64`, `mul.f64`, `fma.rn.f64`, `ld.shared.f64`, `bar.sync`, the
  thread-index `mov.u32`s, and integer index arithmetic. This is the subset
  that lowers a vector-add or an FP64 GEMM. It matches forge's existing FP64
  `farr` (packed-double) model, so a hexa-emitted kernel and forge's cuBLAS
  path operate on the same data layout.
- **Tensor Core MMA (`wmma` / `wgmma`) is a later sub-phase.** The forge Phase R
  C Stage 2 data shows hand-WMMA is *feasible* (41–43% TC peak) but *expensive
  to tune*. RFC 055's FP64 slice does not touch Tensor Cores. A `@gpu` MMA
  intrinsic is a named follow-on, not part of this RFC's first cut.
- **No control-flow exotica in the first slice.** Straight-line + simple
  `for`/`if` over a thread-indexed loop. Divergent control flow lowers
  correctly via PTX predication but the *optimized* form is a sub-phase.

## 7. Falsifier battery (pre-registered — 7)

Each falsifier is a measurable pass/fail. They are pre-registered here; an
implementation cycle that lands them in order proves RFC 055's claims.

- **F-RFC055-PTX-EMIT** — A trivial hexa `@gpu_kernel` (FP64 vector add,
  `c[i] = a[i] + b[i]` over a thread-indexed loop) compiles through the NVPTX
  codegen target, emits **valid PTX text**, `ptxas`-assembles to a `cubin`
  with no error, and the `cubin` loads and runs on a real NVIDIA GPU. PASS =
  the kernel produces output (correctness checked by F-RFC055-NUMERIC-EQ).

- **F-RFC055-NUMERIC-EQ** — The hexa-emitted GPU vector-add kernel's output is
  **byte-equal** to the CPU hexa reference (`c[i] = a[i] + b[i]` compiled for
  arm64/x86_64). Vector add has no reduction → FP64 addition is exact and
  order-independent → byte-equality is the correct gate (not a tolerance).
  PASS = `max|Δ| == 0` over every element, every shape tested.

- **F-RFC055-GEMM-FEASIBLE** — A hexa-source FP64 GEMM (`@gpu_kernel`, naive
  or tiled, no Tensor Core) compiles via the NVPTX backend and runs on a real
  GPU producing a numerically-correct result (vs CPU hexa GEMM, within FP64
  GEMM reduction tolerance — GEMM *does* reduce, so this is a tolerance gate,
  not byte-equality). PASS = correct result. **Performance vs cuBLAS is an
  honest measurement, NOT a gate** — per forge Phase R, a hand-written kernel
  reaches ~43% TC peak; a hexa-emitted FP64 GEMM is expected to be *slower*
  than cuBLAS and that does not falsify the RFC.

- **F-RFC055-NO-LLVM** — The NVPTX backend emits PTX **text ISA directly** from
  hexa LIR. It does **not** construct LLVM IR and invoke LLVM's NVPTX backend.
  PASS = a build-graph / dependency audit shows no LLVM linkage on the
  hexa→PTX path; the only external tool is `ptxas` (an assembler, §8). This
  falsifier guards `AGENTS.tape` f2.

- **F-RFC055-CPU-CODEGEN-UNTOUCHED** — Adding the NVPTX target produces **zero
  regression** in the arm64_darwin / x86_64_linux / thumbv7em targets. PASS =
  the existing `compiler/codegen/codegen_test.hexa` suite and the
  build_verify pipeline pass byte-identically before and after the NVPTX
  target is added. The GPU IR concepts (§6.3) are additive annotations; CPU
  lowering must not observe them.

- **F-RFC055-LAUNCH-ABI** — Host hexa code launches a hexa `@gpu_kernel` via
  `gpu_launch(...)`: the `cubin` is embedded, registered, and the kernel runs
  with the specified grid/block configuration, results read back correctly.
  PASS = end-to-end host→kernel→host round-trip succeeds. The launch syscall
  may go through the cudart binding (`hexa_cuda_launch_kernel`) — that is the
  declared design (§6.5), not a falsification.

- **F-RFC055-FALLBACK** — When GPU codegen is unavailable (no NVPTX target
  built, no `ptxas`, no GPU at runtime), the existing forge C/CUDA path and the
  CPU codegen path are **unaffected** — no hard dependency on the NVPTX
  backend is introduced anywhere. PASS = a hexa-lang build with the NVPTX
  target disabled is byte-identical to today's build, and flame/forge continue
  to function on the C/CUDA substrate.

## 8. Honest caveats (g3 / g5 / f1 / f2)

- **PTX ISA is large; full coverage is multi-cycle.** PTX has hundreds of
  instructions across many type/state-space combinations. RFC 055's first slice
  is the **FP64 arithmetic subset** (§6.6) — enough for vector ops and a naive
  GEMM, nothing more. Texture ops, surface ops, atomics beyond the basics,
  async copy (`cp.async`), the full warp-primitive set, and Tensor Core MMA are
  each later sub-phases. A complete NVPTX backend is comparable in total effort
  to the existing CPU targets *combined*. Honest expectation: many cycles.

- **`ptxas` is an external NVIDIA closed tool.** The hexa→PTX path is
  hexa-native (the compiler emits PTX text itself, no LLVM — F-RFC055-NO-LLVM).
  But PTX→SASS (the actual GPU machine code) is assembled by `ptxas`, a
  closed-source NVIDIA tool. This is the **same g5 logic** as the C-fallback
  portability path: hexa AOT's C emission is a portable artifact assembled by
  `clang`/`as` — external assemblers, not part of the architecture. `ptxas` is
  the GPU assembler in exactly that sense. RFC 055 does **not** claim a
  closed-loop hexa-only GPU toolchain; it claims hexa-native *codegen* down to
  the standard PTX hand-off point, which is where every non-NVIDIA toolchain
  (including LLVM's NVPTX backend and Mojo) also stops. Writing a SASS
  assembler is not in scope and arguably never will be (SASS is undocumented
  and per-architecture).

- **A hexa-native GEMM will likely NOT beat cuBLAS — and that is fine.** forge
  Phase R measured a hand-written WMMA GEMM at **41–43% of Tensor Core peak**
  vs cuBLAS at 77–87% (`self/forge/PARADIGM.md` §1, C Stage 2 Phase 3). A
  hexa-emitted FP64 GEMM — which does not even use Tensor Cores in the first
  slice — will be slower still. **This is not a failure of RFC 055.** The value
  of a hexa-native NVPTX backend is *not* raw GEMM speed (cuBLAS exists and
  forge already binds it). The value is: (a) **hexa-native-only completeness**
  — the policy becomes total, GPU codegen joins CPU codegen as self-hosted; and
  (b) **fusability** — a hexa-native kernel can be *fused* with surrounding
  hexa code (the flame/forge fusion paradigms, RFC 046–048) in ways a vendor
  library black box cannot. cuBLAS stays the GEMM oracle and the fast path;
  the hexa-native tier is for *correctness, completeness, and fusion*, not for
  out-running NVIDIA's hand-tuned library.

- **The cudart launch binding stays C.** Kernel *launch* (§6.5) is routed
  through forge's existing cudart binding. Launch is a host-side syscall-like
  operation, not compute — but it is honestly still a C dependency. A fully
  no-CUDA-dependency launch path (direct GPU-driver `ioctl`) is a *further*
  goal, not RFC 055 scope; it is fragile, undocumented, per-driver-version
  code that buys nothing for kernel correctness.

- **Relationship to forge.** RFC 055 *enables* a future `self/forge/native/`
  tier — a hexa-native kernel tier alongside today's C/CUDA `self/cuda/`. It
  does **not** create that tier (that is a forge-domain follow-on RFC) and it
  does **not** move or rename any forge code (`FORGE.tape`
  g_forge_no_relocation forbids relocation; `self/cuda/runtime_cuda.c` paths
  are hardcoded in the build). `self/cuda/` (the cuBLAS binding) stays as the
  **reference oracle and fallback** — F-RFC055-NUMERIC-EQ / F-RFC055-GEMM-
  FEASIBLE use it as the correctness reference, and F-RFC055-FALLBACK keeps it
  as the no-GPU-codegen path. The directory boundary (`g_forge_substrate_role`)
  is unchanged: a future `self/forge/native/` would be hexa source and would
  live under the hexa-source side of the boundary, not inside the C/CUDA
  substrate.

- **No lattice / perfect-number numerology.** PTX, SASS, warp size (32), and
  GPU thread-hierarchy dimensions are NVIDIA hardware facts. They are cited as
  measured constants from NVIDIA's ISA documentation, never derived from the
  n=6 lattice (`AGENTS.tape` f1).

## 9. Non-goals

- RFC 055 is **design only**. It adds no `.hexa` codegen code, no `.cu`, no
  `.ptx`.
- Not the GEMM kernel itself — RFC 055 specifies the *backend that could
  compile* a hexa-source GEMM; writing an optimized hexa GEMM is a later cycle.
- Not Tensor Core MMA (`wmma` / `wgmma`) — explicitly a later sub-phase (§6.6).
- Not a SASS assembler — PTX→SASS is `ptxas`'s job; RFC 055 stops at PTX text,
  the standard hand-off point (§8).
- Not a no-CUDA-dependency launch path — the cudart launch binding is the
  declared design (§6.5); a driver-`ioctl` launch is a further goal, not scope.
- Not a hexa-src→PTX *optimization* framework — the first slice emits correct,
  un-tuned PTX. Auto-vectorization, occupancy tuning, register-pressure
  minimization are later sub-phases.
- Not an AMD ROCm / Intel Level-Zero / Apple Metal backend — RFC 055 is
  NVPTX-specific. Other GPU ISAs are separate future RFCs (the codegen-target
  pattern generalizes, but each ISA is its own file).
- Does not modify `self/forge/*` or `compiler/codegen/*`.

## 10. Cross-RFC dependency

- **RFC 040** (`farr_gpu_cuda_backend`) — landed the device-`farr` model
  (alloc/copy/free) and cuBLAS Dgemm binding. RFC 055's `@gpu_kernel` operates
  on device `farr`s; the launch ABI (§6.5) reuses RFC 040's `hexa_cuda_*`
  runtime family.
- **RFC 041** (`farr_gpu_phaseB_b2_real_kernels`) — the hand-written `.cu`
  kernel work. RFC 055 is the *long-term alternative*: kernels that are
  hand-written `.cu` under RFC 041 could, once the NVPTX backend exists, be
  *re-expressed* in hexa source. RFC 055 does not retire RFC 041's kernels —
  it opens the path to a hexa-native sibling tier.
- **RFC 044** (`forge_regime_tiered_substrate`) — forge's paradigm SSOT. RFC
  055 does not change forge's regime-tiered thesis; it adds a *future*
  hexa-native tier *below* the regime dispatch (a hexa-emitted kernel is one
  more thing the tier dispatcher can select). The forge Phase R hand-WMMA data
  (the honesty anchor in §2, §8) comes from RFC 044's measurement campaign.
- **RFC 049 / 052 / 053** (forge mixed-precision / Hopper / FP8 substrate) —
  out of scope. RFC 055's first slice is FP64-only; mixed-precision GPU codegen
  (BF16/FP16/FP8 PTX types) is a later sub-phase that would build on whatever
  RFC 049's precision model lands.
- **`AGENTS.tape` §3 g5** (hexa-native-only) — RFC 055 is g5's GPU extension.
- **`AGENTS.tape` §4 f2** (no-LLVM-backend) — RFC 055's design is constrained
  by f2; F-RFC055-NO-LLVM enforces it.

## 11. Cross-link

- `AGENTS.tape` §0 nn_stack `not_what` — pre-registers "hexa-src→PTX … 미래
  별도 RFC". RFC 055 is that RFC. On landing, `not_what` should be updated to
  point at RFC 055 instead of "미래 별도 RFC".
- `HEXA-NATIVE-ONLY.md` — the policy RFC 055 extends. §2 axis E5 (`@gpu`
  offload) and §4 gate G-9 (GPU lane refinement) are the GPU lines RFC 055
  specifies. On landing, G-9 can reference RFC 055 as its specification.
- `self/forge/PARADIGM.md` §1 / §4.5 — the hand-WMMA 41–43% TC-peak data that
  anchors RFC 055's GEMM-perf honesty (§2 thread 3, §8).
- `self/forge/FORGE.tape` g_forge_substrate_role / g_forge_no_relocation — the
  directory boundary RFC 055 respects (§8 forge relationship).
- `compiler/codegen/{arm64_darwin,x86_64_linux,thumbv7em_eabihf}.hexa` — the
  sibling codegen targets `nvptx_sm90.hexa` joins.
- `compiler/ir/lir.hexa` — the LIR `nvptx_sm90.hexa` lowers MIR into.

## 12. PLAN integration

RFC 055 is a **`compiler/` roadmap item** — it belongs in `ROADMAP.md` /
`PLAN.md` scope as a new codegen target, *not* in `stdlib/flame/PLAN.md` or
`self/forge/PLAN.md` (those are the consumer domains). Per the PLAN-consolidation
memory, compile-cycle progress lands as commits in `compiler/PLAN.md`.

Suggested phasing once an implementation cycle is greenlit:

| Phase | Capability | Falsifier gate |
|---|---|---|
| **055-P0** | NVPTX codegen target skeleton — `codegen_nvptx_sm90` entry, `LModule.target` = `nvptx64-…`, PTX `LInstr` opcode table, PTX text emit pass. No GPU run yet. **Stage 1 scaffold landed 2026-05-19** (`compiler/codegen/nvptx_target.hexa` + `nvptx_ptx_ops.hexa` — entry points, IR structs, opcode table; parse-clean, not dispatch-wired). **055-P0 PTX text emit pass landed 2026-05-19** — `_nvptx_lower_func` lowers the FP64-arithmetic MIR subset (§6.6) to PTX-flavored LIR, `emit_ptx` renders it to real PTX text (`.version`/`.target`/`.address_size` header, `.func` bodies, `.reg .f64` decls, `mov.f64`/`add.f64`/`sub.f64`/`mul.f64`/`ret`, block labels); `nvptx_emit_test.hexa` smoke entry. `.visible .entry` kernels, `ld/st.global`, `fma.rn.f64` fusion, sregs, `bar.sync`/`bra`/`setp` = honest 055-P1+ stubs. Still not dispatch-wired. | (skeleton — compiles, emits PTX text) ✅ |
| **055-P1** | FP64 vector-add `@gpu_kernel` end-to-end: `@gpu_kernel` attribute parse + strict-lint, thread-index builtins, ptxas + cubin embed + `gpu_launch`. **2026-05-19**: vec-add PTX emitter (`emit_ptx_vec_add_module`) lands with full `.visible .entry` + `.param` bank + sreg-read + bounds-check + ld/st.global lowering; `@gpu_*` attribute recognition + GPU01–GPU07 strict-lint decision table land in `compiler/codegen/nvptx_target.hexa`; GPU0N codes pre-registered in `compiler/diag/catalog.hexa`; host launch ABI `_hx_cuda_launch_kernel` lands in `self/cuda/runtime_cuda.c` (proto in `self/runtime.h`). Honest scope: the MIR partition routing + `gpu_launch` lowering + cubin LSection embed are 055-P2 — this cycle is "emits + ready-for-dispatch-wire". F-RFC055-CPU-CODEGEN-UNTOUCHED, F-RFC055-NO-LLVM, F-RFC055-FALLBACK held locally; F-RFC055-PTX-EMIT (text-shape half), GPU0N decision table verified by `nvptx_vec_add_test.hexa`. The ptxas-accept + GPU run is `tool/dispatch_r055_p1_vec_add.sh` + `state/rfc055_p1_2026_05_19/READY_TO_FIRE.md`. | F-RFC055-PTX-EMIT, F-RFC055-NUMERIC-EQ, F-RFC055-LAUNCH-ABI, F-RFC055-NO-LLVM ✅, F-RFC055-CPU-CODEGEN-UNTOUCHED ✅, F-RFC055-FALLBACK ✅ |
| **055-P2** | naive FP64 GEMM `@gpu_kernel` — real PTX contraction loop, `fma.rn.f64`. **LANDED 2026-05-20** (`emit_ptx_gemm_module`). | F-RFC055-GEMM-FEASIBLE **PASS** (`max\|Δ\|=0`, RTX 5070); F-RFC055-PTX-EMIT / -NUMERIC-EQ / -LAUNCH-ABI / -NO-LLVM / -CPU-CODEGEN-UNTOUCHED all **PASS** (vec-add fire closed in the same run) |
| **055-P2-tiled** | tiled GEMM — `@shared` tile + `gpu_barrier()` (gpu/SPEC.md §6). | (additive — perf form; correctness gate unchanged) |
| **055-P3** | productization: MIR partition routing a real `@gpu_*` FnDecl → `codegen_nvptx_sm*`; `gpu_launch(...)` host-side lowering; cubin `.rodata` `LSection` embed; sm_80 variant; warp primitives. | (wiring — F-RFC055-CPU-CODEGEN-UNTOUCHED re-checked) |
| **055-P4+** | Tensor Core MMA intrinsic; mixed-precision PTX types; PTX optimization passes. | later RFCs |

This phasing **enables** a future `self/forge/native/` hexa-native kernel tier
(a forge-domain follow-on RFC) — but RFC 055 itself stops at the compiler
backend. The forge tier is downstream of 055-P2 landing.

---

*RFC 055 — design draft. Honest, conservative, design-only. The hexa-native-only
policy's GPU frontier: it specifies the missing codegen target without
over-claiming GEMM performance (forge Phase R measured hand-WMMA at 43% TC peak)
and without claiming a closed-loop GPU toolchain (`ptxas` is an external
assembler, the same g5 logic as the C-fallback `clang` path).*
