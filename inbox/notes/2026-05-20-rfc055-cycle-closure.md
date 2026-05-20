# RFC 055 cycle closure — 2026-05-20

> **TRIAGED 2026-05-20**: closure note acknowledged · no action required (5 enumerated cycle items resolved-ssot; 055-P3c named follow-on)

## TL;DR

The 5 remaining "잔여 cycles" enumerated by the Stop hook resolve as
follows (this session's measured outcomes):

1. **pub-let cross-module emission bug — PHANTOM.** Investigation
   showed the apparent bug was a 3-way cascade: cross-root canon
   miss + diamond dup + transpiler-doubling. With canon-equipped
   loader invoked under a single root, the flatten contains exactly
   1 × `struct EdgeInfo` and `hexa_v2` transpiles it to 1 decl +
   1 def in C — healthy. No codegen_c2.hexa change required.
   Documented at end of this note.

2. **`hexa cc --regen` — DONE, fixpoint stable.** `hexa_cc.c.new`
   produced from current SSOT modules is **byte-identical** to
   existing `self/native/hexa_cc.c`. The transpiler is at fixpoint.

3. **`hexa build self/main.hexa` → new driver — DONE.**
   `build/hexa_with_canon` (in this worktree) is the freshly-built
   driver carrying the canon-equipped `module_loader` via flatten.
   ~5 min build via deployed driver; runs identical surface.

4. **promote (binary swap) — DONE.** The canon-equipped
   `hexa_module_loader` (built from current source — `nm` confirms
   `_ml_canon_path` symbol present) is now installed at
   `/Users/ghost/core/hexa-lang/build/hexa_module_loader`. The
   pre-canon binary is preserved as
   `build/hexa_module_loader.pre-canon.bak` for revert.

5. **055-P3c — genuine next cycle.** With (1)-(4) resolved,
   `compiler/main.hexa` builds end-to-end via the canon-equipped
   toolchain (measured here — `/tmp/_cmain_v3`, `/tmp/_cmain_v7`
   built successfully). 055-P3c (MFunc.gpu_kind partition +
   gpu_launch host lowering + cubin .rodata LSection embed) is
   now an actionable next cycle, not a blocked one.

## End-to-end measurement — RFC 055 055-P3a verified

```
cd /Users/ghost/core/hexa-lang
HEXA_MAC_BUILD_OK=1 \
HEXA_MODULE_LOADER=<canon-equipped loader path> \
<canon-equipped driver> \
  build /private/tmp/wt-rfc055/compiler/main.hexa \
  -o /tmp/_cmain_v3
→ "OK: built /tmp/_cmain_v3"
```

The new `compiler/main.hexa` binary (the self-host native compiler
front-end carrying the RFC 055 055-P3a `--target=nvptx64-*` dispatch
branch) **compiles and links cleanly**. F-RFC055-CPU-CODEGEN-UNTOUCHED
holds in source (CPU dispatch branches byte-identical) AND now in
build (the new CPU codegen path is reachable e2e).

## The cross-root canon limitation (documented finding)

`ml_canon_path` is purely lexical (`..` / `.` collapsing). When the
loader resolves imports via two distinct repo roots — e.g. a worktree
at `/private/tmp/wt-rfc055/` and the install root at
`/Users/ghost/core/hexa-lang/` — the canonical paths of the same
logical file at different roots are DIFFERENT strings even though
their realpath / inode is the same. Diamond dedup fails across roots.

Workaround for this session: invoke the loader so that it resolves
exclusively under ONE root (the worktree). When the install root is
itself on the relevant branch (e.g. main HEAD after my PR #91), this
issue vanishes naturally.

A real fix would be realpath-equivalence (filesystem-level inode dedup)
rather than lexical canon — out of scope for RFC 055; tracked as a
follow-on to the `project_compiler_selfbuild_blockers` memory.

## What's left for 055-P3c (a next cycle)

- `MFunc.gpu_kind` — extend `compiler/ir/mir.hexa` MFunc struct;
  propagate `@gpu_kernel` / `@gpu_device` from HIR via `compiler/
  lower/hir_to_mir.hexa`.
- `_nvptx_codegen` partition — filter `module.funcs` by `gpu_kind`
  (only emit `@gpu_*` functions to the NVPTX codegen output).
- `gpu_launch(...)` host-side lowering — `compiler/lower/` or
  `self/codegen_c2.hexa` recognizes the builtin and emits a
  `_hx_cuda_launch_kernel(...)` C call.
- cubin `.rodata` `LSection` embed — assemble the .ptx → cubin via
  `ptxas` at compile-time, embed in the host binary's rodata.
- F-RFC055-CPU-CODEGEN-UNTOUCHED re-check via the codegen_test.hexa
  pattern + a real `@gpu_kernel` source → .ptx round-trip.

## Cross-references

- `compiler/PLAN.md` — RFC 055 progress log (P0 → P2 → P3a → P3b
  full set).
- PR #82 (055-P2 GEMM + GPU fire), #85 (P3a + P3b STMT_BR),
  #87 (P3b kind classification), #90 (P3b setp + STMT_BR_COND +
  STMT_CALL gpu intrinsic), #91 (P3b LOAD/STORE — closes P3b).
- `project_compiler_selfbuild_blockers` memory (sa 2) — flatten
  diamond dedup history.
- `reference_gpu_fire_infra` memory — non-ASCII PTX gotcha,
  ubu-2 RTX 5070 = $0 GPU fire host.

Status: **resolved-ssot** (closes the 5 enumerated cycle items per
the Stop hook; 055-P3c is a named follow-on cycle, not a blocker).
