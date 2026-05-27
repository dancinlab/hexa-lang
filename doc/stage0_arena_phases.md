# Stage 0 Host Arena Phase Boundaries

> Status: **landed 2026-05-10** — companion to
> `doc/stage1_punch_list_v2.md` A1.
>
> Source-of-truth call sites: `compiler/main.hexa` (driver) +
> `self/runtime.c` (`hexa_env_var` __HEXA_ARENA_*__ side channel).

---

## Why

Stage 0 host (`hexa_real` / `hexa_interp.real`) had **one** bump arena
for the entire process lifetime. Every `hexa_arena_alloc(...)` —
string concatenation, struct-literal `__type__` keys, scratch
strings — accumulated until the runtime's RSS soft cap fired.

On the 25,932-line spliced super-module that Gap 1 (multi-file
load) produces from `compiler/main.hexa`, RSS climbed past 2 GB
before any structured diagnostic surfaced (16 min wall, 0 stdout, 0
stderr → memory cap exit 77; see punch list v2 §TL;DR).

Phase boundaries reclaim the arena at points where:

1. The phase's intermediate scratch is dead (no live Hexa-side
   carrier points into it), AND
2. The phase's hand-off to the next phase is a slim heap-resident
   struct (lives in `array_store` / `map_store` / `struct_store`,
   immune to bump-arena rewind).

## Hand-off shapes

```
              ┌──────────────────┐  carrier  ┌──────────────────┐
              │ phase N          │ ────────► │ phase N+1        │
              │  (arena scratch) │           │  (own scratch)   │
              └──────────────────┘           └──────────────────┘
                       │                              ▲
                       │ phase_reset("post_<N>")      │
                       └──────►(rewind arena)─────────┘
```

`carrier` is one of: `[Token]`, `Module`, `[Diagnostic]`, `HModule`,
`MModule`, `LModule`, `string` (asm_text). All are heap-resident
in stage 0's `*_store` arrays, NOT in the bump arena.

## Phase ids

| id  | name                    | call site (compiler/main.hexa) | hand-off carrier                  | what gets freed                                            |
|-----|-------------------------|--------------------------------|-----------------------------------|------------------------------------------------------------|
| 0   | `pipeline_start`        | before lex                     | (source string only)              | (no-op log)                                                |
| 1   | `post_lex`              | after `lex(source, source_path)` | `[Token]` (in array_store)        | (log only — tokens still alive)                            |
| 2   | `post_parse`            | after `parse(tokens, source_path)` | `Module` (struct_store)           | path concat scratch from `_splice_imported_items`          |
| 3   | `post_check`            | after resolve+bind+types+units+citation | `[Diagnostic]` (array_store)      | diag message fragments, type-printer strings, atlas keys   |
| 4   | `post_lower_ast_to_hir` | after `lower(module, atlas)`   | `HModule` (struct_store)          | AST→HIR helper IDs, label concat scratch                   |
| 5   | `post_lower_hir_to_mir` | after `lower_hir(hmodule)`     | `MModule` (struct_store)          | block label concat, MIR debug strings                      |
| 6   | `post_codegen`          | after `codegen_<target>(mmodule)` | `LModule` (struct_store)          | MIR-side block labels, per-fn lower scratch                |
| 7   | `post_emit_asm`         | after `emit_asm(lmodule)`      | `string` asm_text (heap)          | LIR-side mnemonic concat, comment scratch                  |

Phase 0 / phase 1 are log-only: tokens are still bound to a name in
the driver scope. Resetting the arena after lex would invalidate
any token whose payload was arena-allocated (today the lexer keeps
token slices in heap arrays, so the reset is technically safe but
the budget win is negligible — token text fits well under 16 MB on
realistic inputs).

## Memory budget per phase (target)

Captured pre-A1 (cfc883af baseline) and post-A1 expected. Numbers
in MB. **Pre** column is observed peak resident-set; **post** is
the modeled value after bump-arena reset (assumes phase N's scratch
strings dominate the bump-arena residual).

| phase                     | pre-A1 RSS | post-A1 RSS (target) | budget |
|---------------------------|-----------:|---------------------:|-------:|
| pipeline_start            |        ~50 |                  ~50 |    100 |
| post_lex                  |       ~120 |                 ~120 |    200 |
| post_parse                |       ~700 |                 ~250 |    500 |
| post_check                |     >1 500 |                 ~400 |    750 |
| post_lower_ast_to_hir     |     >1 800 |                 ~500 |    900 |
| post_lower_hir_to_mir     |        OOM |                 ~600 |  1 000 |
| post_codegen              |        OOM |                 ~700 |  1 200 |
| post_emit_asm             |        OOM |                 ~700 |  1 200 |

Target ceiling for stage 1 self-compile: **< 1.5 GB peak**. Wall
time target: **< 8 min** (down from 16 min OOM).

## Runtime hooks (stage 0)

Spelled as `env(__HEXA_ARENA_*__)` for the existing side-channel
discipline. See `self/runtime.c::hexa_env_var`.

| name                       | effect                                                        | returns                          |
|----------------------------|---------------------------------------------------------------|----------------------------------|
| `__HEXA_ARENA_PHASE_RESET__` | rewind bump arena to first block (block.used = 0 for all)     | `"1"`                            |
| `__HEXA_ARENA_RSS_MB__`      | snapshot current resident-set                                 | decimal string of MB             |
| `__HEXA_ARENA_BYTES__`       | total reserved arena bytes (all linked blocks)                | decimal string                   |
| `__HEXA_ARENA_LIVE__`        | currently-used arena bytes (block.used sum)                   | decimal string                   |
| `__HEXA_PHASE_LOG__<name>`   | emit one-line stderr marker `[hexa-runtime/phase] name rss=…` | the emitted line                 |

Hooks added 2026-05-10. Older stage 0 binaries return empty string
on these env reads, so `phase_reset` is a silent no-op on legacy
hosts — the pipeline still runs, just without the reclaim.

## Hand-off audit (one bullet per boundary)

- **post_parse**: `Module` is a `struct_store` entry; its `items`
  field is an `[Item]` in `array_store`; each `Item` is a struct.
  No `Item.*` field is an arena-allocated raw `char*` — every name
  is a Hexa-level string already heapified by `hexa_str_own`.
  **Safe to reset.**
- **post_check**: diagnostics are `Diagnostic` structs in
  `struct_store`; their `message` / `note` / `suggest` / `fixit`
  fields are Hexa-level strings (heap). The check passes' shared
  `env` arrays (`_types_*` / `_resolve_*`) are local to those fns
  and dropped on return. **Safe.**
- **post_lower_ast_to_hir**: `HModule.funcs` is heap; per-fn `body`
  is a tree of `HExpr` structs in struct_store. AST `Module` is
  not consulted by later phases (`lower_hir` walks `HModule`).
  **Safe.**
- **post_lower_hir_to_mir**: `MModule` is heap; block label IDs
  are integers, not arena strings. **Safe.**
- **post_codegen**: `LModule` is heap; instruction ops carry
  Hexa-level string mnemonics (heap). **Safe.**
- **post_emit_asm**: `asm_text` is the rendered assembly (heap
  string). The next operation is a file write — no further arena
  consumers. **Safe.**

## What this does NOT fix

The bump arena reset reclaims **str/Val arena scratch only**. It
does NOT compact `array_store` / `map_store` / `struct_store`
(host-side arrays of arrays / maps / structs) — those grow
monotonically as new Vals are allocated, gated by the freelist
which is currently disabled (M4-fix; see `self/hexa_full.hexa`
line ~17993). A1 is a P0 mitigation; the durable fix needs:

- A2 (`_splice_imported_items` in-place accumulator) — eliminates
  the per-import `[Item]` list churn that drives `array_store`
  growth in the first place.
- Re-enable the `array_free_list` reclaim with proper struct-field
  refcount discipline (M4-fix follow-up).
- Consider a stage 0.5 host (C/Rust) for the spliced compile —
  punch list v2 §TL;DR option (c).

A1 buys headroom; A2 + freelist are needed for the long tail.
