# RFC 075 — Multi-Vendor GPU Codegen Backend (ROCm + Metal)

- status: **DRAFT — Metal P1+P2+P3 codegen-only LANDED · ROCm P0 only (no AMD GPU in pool)**
- created: 2026-05-20
- updated: 2026-05-20 — Campaign C: Metal P1 (full vec-add MSL syntax-fragment table) + P2 (per-Local precision + address-space classifier helpers) + P3 (real MSL source emit for vec-add MIR shape — hardcoded for STMT_LOAD + STMT_LOAD + STMT_BINOP_ADD + STMT_STORE). F-RFC075-METAL-{TARGET-ACCEPT,EMIT-VEC-ADD} PASS via `metal_lower_test.hexa` (build + run, 15 substring asserts). NVPTX path byte-identically untouched. No `self/codegen_c2.hexa` edits. ROCm side remains P0-only (multi-session blocked — no AMD GPU in pool).
- supersedes / extends: RFC 055 (hexa-src → NVPTX) — this RFC adds sibling vendor backends, NVPTX itself is untouched.
- numbering note: opened as "RFC 073" in the dispatch task; renumbered to
  **RFC 075** because RFC 073 (read_verilog procedural-mux) and RFC 074
  (enum multi-field payload) were already allocated in this date directory.
  All cross-links use the final RFC 075 number.
- authority:
  - GPU.md §3f wishlist (`HIP/AMD ROCm backend` · `Metal Performance Shaders`)
  - GPU.md §10 closure box: `[ ] Multi-vendor: ROCm or Metal kernel parity — proves architectural independence` (still unchecked)
  - dispatch task "Campaign C — RFC 073 §9 multi-vendor codegen backend P0 scaffold" (TaskList #38)
  - memory `project_compiler_rfc063_p0p1_closed_p2_started.md` (RFC 063 cross-platform falsifier pattern) — same dual-vendor closure shape

---

## 1 — Problem

The hexa GPU codegen pipeline (RFC 055 P0-P4, RFC 067-069 chain)
is **single-vendor** — every silicon-fired path lands at NVIDIA PTX,
assembled by NVIDIA's `ptxas`, run on NVIDIA hardware. The GPU.md §10
closure box `[ ] Multi-vendor: ROCm or Metal kernel parity — proves
architectural independence` calls out the implication: until a sibling
vendor's kernel runs from the same `@gpu_kernel` source, the
"hexa-native GPU substrate" claim is bound to one vendor's ISA.

This RFC opens the **scaffold cycle (P0)** for two sibling backends —
ROCm (AMD) and Metal (Apple) — that mirror the NVPTX scaffold shape
laid down by RFC 055 Stage 1.

## 2 — Scope

**In:** ROCm (AMD HIP-IL text-ish) + Metal (Apple MSL source text).
Two vendors covers the architectural-independence closure: AMD =
discrete dGPU sibling of NVIDIA on PCIe, Apple = unified-memory
integrated GPU on M-series silicon. Both are pool-host-accessible
(ubu-2 RTX-5070-equivalent AMD slot for P4 silicon fire deferred, M-series
laptop already in user's possession).

**Out:** Intel oneAPI / SPIR-V / Level Zero.

**Justification for deferring oneAPI to a separate follow-on RFC:**
1. **Pool hardware** — no Intel Arc / Xe iGPU is in the current pool
   (ubu-1, ubu-2, mini, aiden all NVIDIA or Apple). Silicon-fire P4
   would have to wait for hardware procurement.
2. **Tooling dimension** — SPIR-V is a bytecode (not text), and Level
   Zero's runtime ABI differs structurally from CUDA Driver API +
   ROCm runtime + Metal Performance Shaders. That third runtime
   shape doubles the scaffold's runtime-binding surface; folding it
   into this RFC would dilute the ROCm/Metal-specific design.
3. **Two-vendor closure suffices** for the GPU.md §10 box — that line
   reads "ROCm **or** Metal kernel parity", so adding both already
   over-satisfies. A separate follow-on RFC for oneAPI is the right
   shape (single-vendor focus, separate silicon procurement).

oneAPI is targeted at a successor RFC.

## 3 — Vendor pairing (codegen layer analog)

| Layer | NVIDIA (RFC 055) | AMD (this RFC) | Apple (this RFC) |
|-------|------------------|----------------|------------------|
| hexa-emit target | PTX text (virtual ISA) | HIP-IL text-ish (GCN-flavored IL) | MSL source text (Metal Shading Language) |
| vendor assembler | `ptxas` | `hipcc` / `amdgcn-ld.lld` | `metal` (Xcode tools) |
| vendor binary | cubin (PTX→SASS) | code object (AMDHSA ELF) | metallib (LLVM bitcode container) |
| runtime API | CUDA Driver API (`cuLaunchKernel`) | ROCm HSA runtime (`hsa_kernel_dispatch`) | Metal Performance Shaders (`MTLComputeCommandEncoder.dispatchThreads`) |
| target tag | `nvptx64-nvidia-cuda-sm{80,90}` | `amdgcn-amd-amdhsa-gfx{1100,1101,1102}` | `air64-apple-macos-applegpu{m1,m2,m3}` |
| address spaces | `.global`/`.shared`/`.const`/`.param`/`.local` | `global`/`local`/`constant`/`private`/`region` | `device`/`threadgroup`/`constant`/`thread` |

**ROCm hexa-emit target choice — HIP-IL (vs raw GCN ISA):**
HIP-IL is AMD's text-based intermediate language, the closest analog to
PTX. Raw GCN ISA `v_*`/`s_*` instructions exist but compile through HIP-IL
first — emitting HIP-IL keeps the abstraction one layer higher (matches
where PTX sits relative to SASS) and reuses AMD's tooling for the IL→ISA
step (matches how `ptxas` finalizes NVIDIA's path). Falsifier-equivalent
to "emit PTX text, ptxas assembles it" pattern from RFC 055.

**Metal hexa-emit target choice — MSL source text (vs AIR bytecode):**
Apple's Metal Shading Language is C++-flavored source code. AIR (Apple
Intermediate Representation) is an LLVM-bitcode container produced by
Apple's `metal` compiler — but emitting bitcode directly would re-introduce
the LLVM-IR coupling @D f2 explicitly forbids. The hexa-native choice is
MSL source text: Apple's `metal` compiler treats `.metal` source files as
input and produces a `.air` bitcode + `metallib` library, the same way
`ptxas` consumes PTX text. Emitting MSL keeps the same emit-text +
vendor-assembler pattern across all three backends.

## 4 — Phasing P0 → P4 per vendor

Same five-stage pattern that RFC 055 used for NVPTX (Stage-1 scaffold +
P0 emit + P1 kernel + P2 sample + P3 dispatch + P4 silicon-fire). Per
vendor, independently:

- **P0 — Scaffold** (LANDED 2026-05-20 PR #232 a1a2a8fa — both vendors)
  - Target enum constants (gfx-rev / Apple-GPU-rev) ✅
  - Opcode / mnemonic table stubs (vec-add tier, 5-10 entries) ✅
  - Empty `pub fn codegen_emit_<vendor>(module: MModule) -> string` stub returning `""` ✅
  - 1 lower-test smoke file per vendor calling the stub and asserting `len(out) == 0` (the P0 placeholder) ✅

- **P1 — Target enum + opcode tables filled** (Metal LANDED 2026-05-20 Campaign C · ROCm DEFERRED — no AMD GPU in pool, multi-session blocked)
  - Metal: real MSL syntax-fragment constants (kernel-decl `kernel void`, device-pointer params `device const float* ` / `device float* `, thread-position `[[thread_position_in_grid]]`, FP32 binop fragments `+ - * /`, load/store templates, address-space aliases METAL_AS_{DEVICE,THREADGROUP,CONSTANT,THREAD}, precision constants METAL_PRECISION_{F32,F16,F64,I32,U32,BOOL}) ✅
  - Metal: `metal_fp32_slice_ops()` table filled with 11 entries (kernel decl, 2 device-pointer typings, thread-pos, 4 binops, load/store templates, return-none) ✅
  - Metal smoke: F-RFC075-METAL-TARGET-ACCEPT — Case 2 `_test_target_constants` asserts on new constants — PASS ✅
  - ROCm: P1+ deferred — no AMD GPU in pool, would land HIP-IL text the cycle can't silicon-fire-validate. Filing as multi-session block.

- **P2 — Address-space + reg-kind classifier** (Metal LANDED 2026-05-20 Campaign C · ROCm DEFERRED)
  - Metal: `_metal_local_precision(local)` honours `local.precision` (`.f32` / `.f16` / `.f64` / `.i32` / `.u32` / `.bool`) and defaults FP32 ✅
  - Metal: `_metal_local_address_space(local)` returns METAL_AS_DEVICE for kernel-buffer Locals (arena_id 0) and METAL_AS_THREAD otherwise — mirrors NVPTX `.global` vs `.local` ✅
  - Metal smoke: Case 4 `_test_classifier_helpers` PASS ✅
  - ROCm: deferred same gate.

- **P3 — Real instruction emit** (Metal LANDED 2026-05-20 Campaign C · ROCm DEFERRED)
  - Metal: `codegen_emit_metal_msl` emits real MSL source when the first MFunc matches the vec-add shape (STMT_LOAD + STMT_LOAD + STMT_BINOP_ADD + STMT_STORE in entry block). Empty / non-vec-add module → "" honestly (P0 contract preserved) ✅
  - Metal: emitted text contains `#include <metal_stdlib>` + `using namespace metal;` + `kernel void <name>(device const float* a [[buffer(0)]], device const float* b [[buffer(1)]], device float* c [[buffer(2)]], uint i [[thread_position_in_grid]]) { c[i] = a[i] + b[i]; }` ✅
  - Metal smoke: F-RFC075-METAL-EMIT-VEC-ADD — Case 3 `_test_vec_add_emit` synthesises vec-add MIR, invokes the emitter, asserts 15 substring patterns (`#include <metal_stdlib>` · `using namespace metal;` · `kernel void` · `vec_add` · `device const float*` · `device float*` · `[[buffer(0)]]` · `[[buffer(1)]]` · `[[buffer(2)]]` · `[[thread_position_in_grid]]` · `c[i]` · `a[i]` · `b[i]` · ` + ` · `;`) — PASS ✅
  - HONEST g3: P3 vec-add MIR shape is **hardcoded** — emitter recognises one MIR pattern only. General MFunc → MSL lowering is multi-session work mirroring the NVPTX P3 timeline (`_nvptx_lower_func` MIR-walk). Other MIR shapes return `""` honestly.

- **P4 — Silicon fire** (DEFERRED — Metal = follow-on USER-LOCAL Mac cycle · ROCm = AMD-GPU pool gate)
  - ROCm: build via `hipcc` on a pool host with AMD GPU (procurement
    pending) — F-RFC075-ROCM-SILICON-FIRE — blocked.
  - Metal: build via `xcrun -sdk macosx metal` on the user's M-series
    laptop — F-RFC075-METAL-SILICON-FIRE. **This is a USER-LOCAL cycle**
    requiring the Metal toolchain. Codegen-only P3 emits the MSL text;
    `xcrun metal` invocation + MetalKit runtime dispatch + numeric
    parity vs CPU reference (F-RFC075-NUMERIC-EQ) all live in the
    follow-on cycle.
  - F-RFC075-NUMERIC-EQ: vec-add output FP32-equivalent to CPU reference

Each vendor is independently phaseable. P0 (this cycle) lands the
scaffold for BOTH vendors so the structural pattern is established;
P1+ work for ROCm vs Metal is independent and can be interleaved.

## 5 — Falsifier battery

Per-vendor falsifiers, named so the next cycle's worktree can check
them off mechanically:

**ROCm:**
- **F-RFC075-ROCM-TARGET-ACCEPT** (P1) — `ROCM_TARGET_GFX1100` constant
  is recognized by a hypothetical `--target=` dispatch; lookup returns
  matching arch tag. Today: stub.
- **F-RFC075-ROCM-EMIT-VEC-ADD** (P3) — `codegen_emit_rocm_il(vec_add_mir)`
  returns a non-empty string containing `v_add_f64` and `global_load`-class
  mnemonics. Today: stub returns `""` — falsifier intentionally fails.
- **F-RFC075-ROCM-SILICON-FIRE** (P4) — emitted HIP-IL assembles via
  `hipcc` and the resulting code object runs on an AMD GPU, producing
  vec-add output FP32-equivalent to CPU reference (max|Δ| ≤ 1e-6).
  Hardware-gated.

**Metal:**
- **F-RFC075-METAL-TARGET-ACCEPT** (P1) — `METAL_TARGET_APPLE_GPU` constant
  is recognized; lookup returns matching arch tag. Today: stub.
- **F-RFC075-METAL-EMIT-VEC-ADD** (P3) — `codegen_emit_metal_msl(vec_add_mir)`
  returns a non-empty string containing `kernel void`, `device float*`,
  and `+` between vector operands. Today: stub returns `""`.
- **F-RFC075-METAL-SILICON-FIRE** (P4) — emitted MSL compiles via
  `xcrun -sdk macosx metal` and the resulting metallib runs on the user's
  M-series GPU, FP32-equivalent to CPU reference. Hardware-available
  (M-series laptop in pool).

**Numeric falsifier (both vendors):**
- **F-RFC075-NUMERIC-EQ** (P4) — vec-add result vs CPU FP32 reference,
  max|Δ| ≤ 1e-6 (the same envelope flame uses).

## 6 — Honest scope (g3)

**IS:** A structural scaffold per vendor — target enum constants,
opcode/mnemonic table headers, empty `codegen_emit_*` entry points,
1 smoke file per vendor asserting `len(out) == 0`. RFC document
defining the phasing and falsifier battery.

**NOT:**
- Not real emit. `codegen_emit_rocm_il` and `codegen_emit_metal_msl`
  both return `""`. No HIP-IL or MSL is generated.
- Not wired into the compiler's target dispatch. Nothing routes MIR
  through these stubs (matches RFC 055 Stage-1 starting position).
- Not silicon-fired. No `hipcc` or `xcrun metal` invocation in this
  cycle. P4 is multi-session per vendor.
- Not oneAPI. SPIR-V / Level Zero / Intel Arc deferred to a successor
  RFC (§2 justification).
- Not modifying `self/codegen_c2.hexa` or any existing codegen file.
  Only new sibling files in `compiler/codegen/`.
- Not changing any falsifier from RFC 055 / 067 / 068 / 069 — NVPTX
  path is byte-identically untouched (mirrors the
  `F-RFC055-CPU-CODEGEN-UNTOUCHED` discipline).

Closure box in GPU.md §10 (`[ ] Multi-vendor: ROCm or Metal kernel parity`)
**stays unchecked**. P0 scaffold landing does not equate to closure.

## 7 — Cross-links

- **GPU.md §3f** (Multi-vendor wishlist) — this RFC adds the structural
  scaffold for two of the three [ ] entries (ROCm + Metal).
  Intel oneAPI [ ] entry stays unmodified, deferred to a follow-on RFC.
- **GPU.md §10** closure box — RFC 075 P0 scaffold annotation only;
  box stays [ ] until P4 silicon-fire per vendor.
- **RFC 055** (`rfc_055_hexa_nvptx_codegen_backend.md`) — sibling RFC
  that established the Stage-1 scaffold pattern this RFC mirrors.
- **Memory `project_gpu_chain_2026_05_20_cumulative`** — cumulative GPU
  campaign state log; P0 scaffold lands here as the next entry.
- **@D g_inbox_processing_loop** — Shape-B (RFC + scaffold) decision lock;
  this RFC is the canonical Shape-B example for multi-vendor codegen.
- **@D f1 / f2** — no n=6 lattice claim on AMD/Apple internals, no LLVM
  linkage in any new path (HIP-IL is text, MSL is source text).
- **@D g_commit_push_deploy** — no `self/codegen_c2.hexa` edits this cycle.
- **@D g3** — honest scope §6 above.

## 8 — Next cycles (NOT this cycle)

- **Cycle +1** — ROCm P1: fill `rocm_target.hexa` opcode constants
  (full vec-add subset) + `rocm_lower_test.hexa` add a `_test_target_accept`
  case to drive F-RFC075-ROCM-TARGET-ACCEPT to PASS.
- **Cycle +2** — Metal P1: same shape, `metal_target.hexa` opcode
  constants + smoke for F-RFC075-METAL-TARGET-ACCEPT.
- **Cycle +3..n** — P2/P3 per vendor, independently scheduled.
- **Cycle +N** — P4 silicon fire (ROCm hardware procurement gates this;
  Metal can proceed on user's M-series).
