# RFC 055 055-P3c — remaining sub-slices (deploy-cycle work) — 2026-05-20

> **TRIAGED 2026-05-20**: closure note acknowledged · no action required (P3c.d landed via PR #99 deploy-cycle; P3c.e reclassified UX-polish per rfc055-final-closure note)

## Status

3 of 5 055-P3c sub-slices landed via autonomous PRs this session:

| sub-slice | PR | scope |
|---|---|---|
| P3c.a — MFunc.gpu_kind partition routing | #94 | mir.hexa + hir_to_mir.hexa + nvptx_target.hexa |
| P3c.b — `.visible .entry` kernel wrapping | #96 | nvptx_target.hexa (LFunc.name prefix sentinel) |
| P3c.c — param-bank materialisation | #97 | nvptx_target.hexa (PReg.kind == "param" sidecar) |

Remaining: **P3c.d (gpu_launch host lowering) + P3c.e (cubin embed)**.
These are genuinely **coupled** + **deploy-cycle** work — they belong
in one operator-side bootstrap-regen PR.

## Why they're coupled (and why autonomous-cycle isn't the right scope)

`gpu_launch(...)` is a host-side builtin whose lowering must produce
a `_hx_cuda_launch_kernel(...)` C call. The runtime wrapper takes
13 args including the **kernel's cubin blob + length**. The cubin
doesn't exist until the build pipeline:
1. Routes `@gpu_kernel` MFuncs through the NVPTX codegen (P3c.a ✓).
2. Renders PTX text via `emit_ptx` (P0/P3b ✓).
3. **Invokes `ptxas` on the PTX to produce a cubin** (NOT YET — P3c.e).
4. **Embeds the cubin in `.rodata` as an `LSection`** (NOT YET — P3c.e).
5. The compile-time-registered cubin pointer + length is what
   `gpu_launch` lowering injects as the first 2 args of the C call
   (the rest is gx/gy/gz/bx/by/bz/farr_ids/extra_i64 from the
   hexa-side call args).

Without P3c.e, P3c.d would emit a `_hx_cuda_launch_kernel(NULL, 0, ...)`
call — structurally well-formed but semantically broken (no kernel
to launch). They must land together.

## Scope of the combined deploy-cycle PR

**Files touched:**

1. `compiler/lower/hir_to_mir.hexa` — recognize `gpu_launch(kernel, …)`
   as a special call; emit STMT_CALL with op="_hx_cuda_launch_kernel"
   AFTER materialising the cubin blob/length operands. Or — split into
   a HIR pre-pass that rewrites `gpu_launch` calls into the C wrapper
   shape.
2. `self/codegen_c2.hexa` — gpu_launch builtin recognition (so the
   deployed transpiler `hexa_v2` also handles it). Touches the
   `name == "X" { return "Y" }` table at lines 296+ / 335+. **@D
   g_commit_push_deploy mandates this triggers bootstrap regen.**
3. `self/main.hexa` cmd_build — when `@gpu_kernel` present in source,
   route the MFunc through the NVPTX codegen target, run `ptxas` on
   the resulting `.ptx`, embed the cubin in the host binary's
   `.rodata` LSection, and provide a compile-time pointer the
   `gpu_launch` lowering can reference. **Triggers bootstrap regen.**
4. `compiler/emit/asm_test.hexa` etc. — new tests as needed.

**Bootstrap regen steps (operator-side):**

```bash
# After source edits:
hexa cc --regen                  # regenerate self/native/hexa_cc.c
hexa build self/main.hexa \      # rebuild the driver with new cmd_build
  -o build/hexa_with_launch
# Promote (replace install-root binaries; backup pre-promote):
cp build/hexa_with_launch  /Users/ghost/core/hexa-lang/build/hexa.new
# Operator confirms + atomically swaps. Pre-launch backup:
cp /Users/ghost/.hx/bin/hexa_real  /Users/ghost/.hx/bin/hexa_real.bak
```

## Verification path post-regen

1. Build `compiler/main.hexa` via the new driver — should be unchanged
   (CPU codegen unaffected; F-RFC055-CPU-CODEGEN-UNTOUCHED holds).
2. Build a sample `@gpu_kernel` source file → should produce a host
   binary with embedded cubin + a `gpu_launch` call site.
3. Run the host binary → fires the kernel, F-RFC055-PTX-EMIT /
   -NUMERIC-EQ / -LAUNCH-ABI all re-verified through the
   GENERIC codegen path (not the hand-emit P1/P2 path).

## Why this matters

This closes the loop: with P3c.d + P3c.e landed, `@gpu_kernel` is a
real, host-usable hexa language feature — a real `.hexa` source can
declare a GPU kernel + launch it from host code, and the compiler
+ driver produce a working binary. That's the "productization" the
RFC 055 §1 status calls out.

Until P3c.d/e land, the RFC 055 GPU codegen lives in the new native
pipeline (compiler/) as a complete + tested + e2e-buildable
PARTITION-CAPABLE backend; the FINAL deploy-tier wiring to the
running driver is the operator-authorized step.

## Cross-references

- PR #94 / #96 / #97 — the three P3c sub-slices landed this session.
- PR #92 — cycle-closure note (covers P3a/P3b + the `(a)` bootstrap
  promote status).
- `compiler/PLAN.md` — RFC 055 progress log (full P0-P3c trajectory).
- `project_compiler_selfbuild_blockers` memory — cross-root canon
  limitation + `rt_str_*` CI gap (separate, orthogonal).

Status: **resolved-ssot** — names the genuine remaining cycle as
operator-side deploy work + spells out the exact ordering.
