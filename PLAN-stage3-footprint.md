# PLAN — stage-3 footprint: streaming per-function compilation

> Authority: companion to `PLAN-stage3-pathA.md` (the A′ codegen blueprint).
> This file scopes the **memory-footprint** half of the stage-3 verdict:
> the A′ stage-1 self-compile leaks to 10–16 GB RSS (commit 7718c50e),
> which OOM-kills the verdict run on any host without that much headroom.

## Problem (measured)

`compiler/main.hexa` self-compiles a 25,932-line flat-spliced super-module.
The back half of the pipeline materialises **four whole-program carriers**
that are all resident simultaneously at peak:

```
parse → Module(AST) ─lower─→ HModule ─lower_hir─→ MModule ─codegen─→ LModule ─emit─→ asm_text
```

`doc/stage0_arena_phases.md` §"hand-off audit" already proved each carrier
is **dead** once the next phase consumes it (AST after `lower`, HModule
after `lower_hir`, …). But nothing frees them: the Val arena
(`HEXA_VAL_ARENA`) reclaims only *scoped transient* allocations, not these
persistent heap carriers. Confirmed empirically — an `HEXA_VAL_ARENA=1`
self-compile still blows a 4.5 GB cap (interp-host probe, 2026-05-16);
the arena is not the lever.

The envelope fix `f4b597a7` (heapify TAG_STR O(blocks)→O(1)) is a landed
**prerequisite** — it makes a per-iteration arena heapify cheap — but on
its own changes only compile *time*, not RSS.

## Tactic — fuse the four per-function loops into one

All four back-half passes already have a per-item/per-function main loop:

| pass | file | per-item call |
|------|------|---------------|
| `lower`     | `compiler/lower/ast_to_hir.hexa:2070` | `_lower_item(it, def, atlas, module_sc)` → `HItem` |
| `lower_hir` | `compiler/lower/hir_to_mir.hexa:1637` | `_lower_fn(it)` → `MFunc` |
| `codegen`   | `compiler/codegen/arm64_darwin.hexa:1588` | `_arm64_lower_func(mf, st, modhash)` → `LFunc` |
| `emit`      | `compiler/emit/asm.hexa:357` | `_emit_func(target, f)` → `string` |

Today they run as four sequential whole-module loops, each retaining its
full output array. **Streaming** interleaves them into a single loop so
only one function's HIR/MIR/LIR is live at a time:

```
# after lower()'s DefId/scope pre-pass (whole-program — unavoidable):
for each item in module.items:
    arena_scope_push()                       # rt 32-L Val-arena frame
    hitem = _lower_item(it, def, atlas, module_sc)
    if hitem is fn:
        mfunc = _lower_fn(hitem)
        st    = _collect_strs_from_fn(st, mfunc)   # strtab grows incrementally
        lfunc = _arm64_lower_func(mfunc, st, modhash)
        asm_text += _emit_func(target, lfunc)      # the ONLY escaping value
    arena_scope_heapify(asm_text); arena_scope_pop()  # frees hitem/mfunc/lfunc
```

Peak resident drops from `AST + HModule + MModule + LModule` to
`AST + module_sc + one item's HIR/MIR/LIR + asm_text + strtab`. The Val
arena scope pop is what actually reclaims each function — and the `f4b597a7`
envelope fix keeps the per-iteration heapify of the escaping `asm_text`
fragment O(1).

## Caveats (each must be handled in the refactor)

1. **strtab** — `_build_arm_strtab` currently pre-walks the whole MModule.
   Make it incremental: intern each `MFunc`'s string literals into the
   running `ArmStrTab` inside the fused loop, *before* `_arm64_lower_func`
   (which needs `st` for operand resolution). Label assignment is
   insertion-ordered, so incremental interning is byte-deterministic.
   `rodata` is finalised by `_strtab_to_rodata(st)` after the loop.
2. **globals** (`ITEM_LET`) — `lower_hir` collects these into `MModule.globals`.
   Keep a lightweight pre-pass (or accumulate during the fused loop) — they
   are small; no streaming needed.
3. **rodata / bss** — accumulated, emitted after the `.text` loop (matches
   `emit_asm`'s existing structure: `.text` loop then `.rodata`).
4. **front half stays whole-program** — `lex/parse/resolve/bind/types` and
   `lower`'s DefId pre-pass need the whole AST/scope. The AST is therefore
   resident for the whole streaming loop. Streaming reclaims the HIR/MIR/LIR
   layers only; the durable AST cost is bounded and acceptable.
5. **diagnostics** — `_lower_item` / `_lower_fn` emit diags into module-level
   buffers; draining order is unchanged (drain after the loop).

## Phased steps

- **F1** — make `_build_arm_strtab` incremental: expose
  `_arm_strtab_collect_fn(st, mf) -> ArmStrTab`; keep the whole-module
  wrapper for the non-streaming path. Verify: existing codegen byte-identical.
- **F2** — add `codegen_emit_streaming(hmodule, atlas, target) -> string` in
  a new `compiler/codegen/stream.hexa` that runs the fused loop. The legacy
  `lower_hir → codegen → emit_asm` path stays for `--emit obj`/debug.
- **F3** — `compiler/main.hexa`: when `emit_kind == "asm"`, call the streaming
  path; gate behind `--stream` (or `HEXA_STREAM=1`) until byte-diff-verified.
- **F4** — wire the Val-arena scope push/pop around the loop body so the
  reclaim actually fires; confirm `asm_text` is heapified before each pop.
- **F5** — make streaming the default once verified; retire the `--stream` gate.

## Verification (the only honest signal)

Streaming must be a **pure refactor** — same `.s` bytes, less RSS:

1. `emit asm` with and without `--stream` → **byte-identical** `.s`
   (run on `compiler/main.hexa` itself + a sweep of `test/*.hexa`).
2. peak-RSS delta: `__HEXA_ARENA_RSS_MB__` probe at the fused loop's tail
   vs the legacy path — target **< 4 GB** for the stage-1 self-compile
   (down from 10–16 GB), making the verdict runnable without special hosts.
3. Then the stage-3 verdict per `PLAN-stage3-pathA.md` S4: stage-1 →
   stage-2 → byte-diff. Streaming is what unblocks running it at all.

## Status

- ✅ prerequisite `f4b597a7` — heapify TAG_STR O(1) envelope (landed, verified
  15× on the O(n²); byte-identical output).
- ⬜ F1–F5 — not started. F1/F2 are independent of host RAM and byte-diff
  self-verifying, so they are the loop-decomposable units; F3+ need the
  stage-1 build + a measurement host.
