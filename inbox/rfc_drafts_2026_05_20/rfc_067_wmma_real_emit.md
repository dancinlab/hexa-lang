# RFC 067 — Real WMMA (Warp Matrix Multiply Accumulate) PTX emit

**Status:** DRAFT — Shape-B 1st commit (RFC drafted + RFC-comment-marker
landed; zero behavior change). Multi-cycle phased work. Falsifier
battery defined.

**Author session:** 2026-05-20, off origin/main HEAD `24422976`.

**Successor to:** PR #121 (Tensor Core MMA scaffold v2) — landed the
`NVPTX_RKIND_FRAG` constant, `_nvptx_wmma_mnemonic()` mnemonic table,
and `_nvptx_lower_stmt` STMT_CALL branch recognition. That scaffold
emits an honest-stub `// RFC 055 §12 P4+ WMMA (scaffold, not yet
wired) — <op> -> <mnem>` comment line; this RFC defines the cycles
that replace those stubs with real PTX wmma instructions.

**Predecessor lineage:** RFC 055 (hexa-src → NVPTX codegen backend)
§12 P4+ closure plan. Per the closure note `2026-05-20-rfc055-p4-
followons-v2-closure.md`, real WMMA emit is one of 4 deferred follow-
on items; this RFC carries forward the deferred breakdown verbatim
and turns each gap into a measured cycle.

**Scope discipline:** RFC drafted, NOT implementation complete. Per
`@D g3` (honesty-obligation) the closure of THIS RFC requires four
falsifiers (§7) measuring real-silicon GPU output against reference
implementations — none are fired here.

---

## §1 Background

PR #121 landed the scaffold seam: when `_nvptx_lower_stmt` sees a
`STMT_CALL` with `s.op == "gpu_wmma_*"`, it resolves the canonical
PTX mnemonic via `_nvptx_wmma_mnemonic()` and emits a comment-line
LInstr carrying the mnemonic. The mnemonic table covers the f16×f16
→ f32 family on the canonical m16n16k16 tile geometry:

| `gpu_wmma_*` op | PTX mnemonic |
|---|---|
| `gpu_wmma_load_a` | `wmma.load.a.sync.aligned.row.m16n16k16.f16.shared` |
| `gpu_wmma_load_b` | `wmma.load.b.sync.aligned.col.m16n16k16.f16.shared` |
| `gpu_wmma_mma` | `wmma.mma.sync.aligned.row.col.m16n16k16.f32.f16.f16.f32` |
| `gpu_wmma_store_c` | `wmma.store.d.sync.aligned.row.m16n16k16.f32.shared` |

The scaffold makes each of the following reachable but does NOT
implement them. This RFC is the implementation plan.

## §2 Deferred work (carried verbatim from #121 closure note)

1. **Fragment register-bank allocation** — `PReg.kind = "frag"`
   currently maps to a single `.f16` scalar register placeholder
   (`_nvptx_kind_to_ptx_ty` line). A real fragment is a vector of N
   PTX registers; N depends on element type (`.f16` vs `.f32` vs
   `.bf16`) and on which fragment role (A / B / C / D / accumulator).
2. **`.shared` staging-area declaration** — `wmma.load.{a,b}.shared`
   reads from per-block `.shared` memory; today no `.shared` decl is
   emitted in any kernel header.
3. **Per-fragment dtype tags** — current `_nvptx_kind_to_ptx_ty(FRAG)
   → ".f16"` is a single-type placeholder. Real fragments need per-
   instance tags: A/B operand fragments differ from the C accumulator
   in dtype (`f16` vs `f32` in the canonical f16×f16→f32 family).
4. **Memory layout** — `.row` vs `.col` orientation and tile-strided
   alignment must be carried per-fragment so `wmma.load.{a,b}` and
   `wmma.store.d` use the matching qualifier.
5. **Tile-loop integration** — `wmma.mma` operates on 16×16 tiles;
   the kernel must iterate over the K dimension with explicit
   accumulator-carry across iterations (i.e., the C accumulator
   fragment is read+written once per K-tile, not once per kernel).

## §3 Phasing (3 cycles MIN; falsifier-driven)

### P0 — Fragment register-bank (this RFC's scaffold commit)

**This commit's deliverable**, zero behavior change:
- this RFC file
- comment markers in `nvptx_target.hexa` at each seam where P1+
  will land

P0 lands no working code; it pins the scaffold seams so P1 cycles
have stable insertion points.

### P1 — Fragment-as-tile-vector

**Scope:** `PReg.kind = "frag"` produces N virtual registers per
fragment, named `%fra<id>_0` .. `%fra<id>_{N-1}`. N defaults to 8 for
the f16-element 16×16 A/B fragment (canonical NVIDIA layout: a 16×16
fragment of `.f16` distributes 256 elements across a 32-thread warp
as 8 `.f16x2` packed values per thread, equivalently 8 32-bit registers
per thread). The C/D accumulator fragment in `.f32` is 8 32-bit regs
per thread (a 16×16 f32 fragment = 256 elements / 32 lanes = 8 f32
per thread).

**Files touched:** `compiler/codegen/nvptx_target.hexa` only.

**Falsifier P1:** `F-RFC067-FRAG-WIDTH` — given a synthetic MFunc
with one `gpu_wmma_mma` call and one `gpu_wmma_store_c` call,
emitted PTX must declare exactly 8 `.f16x2` regs per A-frag, 8
`.f16x2` regs per B-frag, 8 `.f32` regs per C/D-frag. Asserted by a
substring + count test in `nvptx_lower_test.hexa` (no GPU fire).

### P2 — `.shared` staging-area declaration

**Scope:** when an MFunc's gpu_kind ∈ {KERNEL, DEVICE} contains any
`gpu_wmma_*` call, emit a `.shared .align 16 .b8 _hexa_wmma_stage_<n>[2048];`
declaration in the function header. 2048 bytes = enough for one
16×16 f16 tile (16×16×2 = 512 B) × 4 staging slots (A, B, ping-pong
double-buffer). Per-MFunc unique counter `<n>` so multiple WMMA
kernels in one PTX module don't collide.

**Files touched:** `compiler/codegen/nvptx_target.hexa` (header-emit
helper).

**Falsifier P2:** `F-RFC067-SHARED-DECL` — emitted PTX for a WMMA-
containing kernel must include exactly one `.shared` decl with the
prefix `_hexa_wmma_stage_` and a multiple-of-16 byte count. Asserted
by substring + size-parse test.

### P3 — Per-fragment dtype tags + memory layout (`.row`/`.col`)

**Scope:** carry per-fragment metadata on `PReg`:
- `frag_role: string` — "a" / "b" / "c" / "d" (matches the wmma
  fragment letter)
- `frag_dtype: string` — ".f16" / ".bf16" / ".f32"
- `frag_layout: string` — ".row" / ".col"

The `_nvptx_kind_to_ptx_ty` placeholder `.f16` for FRAG is replaced
by a lookup on `frag_dtype`. The `_nvptx_wmma_mnemonic()` table is
re-keyed by (op, role, dtype, layout) so non-canonical families
(bf16×bf16→f32, f16×f16→f16, tf32 etc.) become reachable.

**Files touched:** `compiler/codegen/nvptx_target.hexa` (PReg
extension + mnemonic table re-key).

**Falsifier P3:** `F-RFC067-DTYPE-FAMILY` — emit one canonical kernel
+ one bf16 kernel + one f16-acc kernel; assert each uses the correct
mnemonic per the NVIDIA PTX ISA §9.7.13.4 table. Three substring
asserts. No GPU fire (text-shape only).

### P4 — Tile-loop integration

**Scope:** wire the K-dim accumulator-carry. Today's #121 scaffold
only recognizes the call ops; this phase generates the surrounding
MIR shape — STMT_LOOP with the K iterator, accumulator-fragment
register reused across iterations (no spill / no per-iter reload),
and `wmma.store.d` outside the loop.

**Files touched:** `compiler/codegen/nvptx_target.hexa` +
`compiler/lower/hir_to_mir.hexa` (the latter only if a new HIR-side
intrinsic shape is needed; default plan is keep the MIR shape
explicit in the test fixture and have the lowering recognize it
without an HIR change).

**Falsifier P4:** `F-RFC067-TILE-LOOP-NUMERIC` — first GPU-fire
falsifier. Build a kernel that computes `C = A · B` for 64×64
`f16` matrices (4 tiles per row × 4 tiles per col × 4 K-tiles = 64
wmma.mma calls). Compare against a hexa-emit naive `.f64` GEMM (the
RFC 055 §6.6 baseline) on the same inputs. Numeric tolerance: the
naive baseline is FP64 and the WMMA path is FP16 with FP32 accum, so
exact equality is NOT achievable; the falsifier asserts max relative
error ≤ 1e-2 over all 4096 output elements (a defensible bound for
f16×f16+f32 fused-multiply-add chains of length 64).

### P5 — Multi-family + bf16 (deferred sub-cycle)

After P4 closes, add bf16×bf16→f32 + f16×f16→f16 as separate
mnemonic-table rows + per-test fixtures. No new compiler-architecture
work — pure mnemonic-table extension.

## §4 Falsifier battery (§7 of RFC 055 grouped)

Each phase commits its own falsifier. The full battery:

| # | id | phase | type | tooling |
|---|---|---|---|---|
| F1 | F-RFC067-FRAG-WIDTH | P1 | substring + count | `nvptx_lower_test.hexa` |
| F2 | F-RFC067-SHARED-DECL | P2 | substring + size-parse | `nvptx_lower_test.hexa` |
| F3 | F-RFC067-DTYPE-FAMILY | P3 | 3× substring | `nvptx_lower_test.hexa` |
| F4 | F-RFC067-TILE-LOOP-NUMERIC | P4 | numeric, real GPU | ubu-2 RTX 5070 ssh fire |
| F5 | F-RFC067-NO-LLVM-NO-CTRANS | (all) | grep | repo-wide search asserts no `llvm` / `LLVMInitNVPTXTarget` / `clang -target nvptx` in any P0-P4 commit |
| F6 | F-RFC067-CPU-CODEGEN-UNTOUCHED | (all) | git stat | `compiler/codegen/{x86_64_linux,arm64_darwin,thumbv7em_eabihf}.hexa` byte-identical pre-vs-post commit |

F5 and F6 are continuous gates (every commit on the RFC 067 series
must pass), not one-shot phase falsifiers.

## §5 Non-goals (out of scope)

- **Texture / surface ops** (RFC 055 §8 — separate sub-phase).
- **`cp.async` for shared-memory staging pipelining** (improves WMMA
  perf but is orthogonal to correctness; deferred to a future RFC).
- **Hopper `wgmma`** (sm_90+) — the canonical mnemonics in §1 are
  the sm_80 family. wgmma is a separate ABI (asynchronous warp-
  group; different fragment layout) and is out of scope.
- **Source-level autovectorize-into-WMMA** — this RFC assumes the
  kernel author writes `gpu_wmma_*` calls explicitly. A higher-layer
  flame-side autotuner that emits these is a future cycle.

## §6 Cross-link

- RFC 055 §12 P4+ closure plan
- PR #121 (MMA scaffold v2) — landed `NVPTX_RKIND_FRAG`,
  `_nvptx_wmma_mnemonic()`, STMT_CALL branch
- `inbox/notes/2026-05-20-rfc055-p4-followons-v2-closure.md`
- `compiler/codegen/nvptx_target.hexa` — scaffold seams
- NVIDIA PTX ISA §9.7.13.4 — WMMA mnemonic table
- `gpu/SPEC.md` §5 — gpu intrinsic op-name allowlist (extend with
  `gpu_wmma_*` once P1 lands)

## §7 Honest-scope tag (`@D g3`)

This RFC drafted ≠ WMMA implemented. The closure of THIS RFC is the
P4 numeric falsifier PASS on real silicon (ubu-2 RTX 5070, sm_120
driver JIT). Until that fires, every WMMA kernel emit remains a
scaffold marker. Sub-cycles MAY ship partial PTX (e.g. P1 lands
fragment-reg-bank decls without lowering bodies) — each such commit
explicitly reports "P<N> scaffold landed, F<N> measured, F<later>
deferred" and never claims "WMMA implemented".
