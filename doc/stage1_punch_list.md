# Stage 1 Bootstrap — Discovery & Punch List

> Source: background discovery agent (Task #44) running
> `RESOURCE_LOCAL_HEXA=1 build/hexa_interp compiler/main.hexa --emit=asm \
>  -o /tmp/stage1.s compiler/main.hexa`
>
> Status: **discovery only — no fixes applied**. Captured 2026-05-09.

## TL;DR

The native compiler runs end-to-end through **lex → parse → resolve → bind → types**, then aborts at the `_has_errors` gate (`compiler/main.hexa:413`) with **9 structured diagnostics** (1× HX3001 + 8× HX3004) and `exit(1)`. No `stage1.s` is produced.

**Crucial finding**: `compiler/parse/parser.hexa::parse()` records imports as item names but **never `read_file`s** them. The 19 imports in `compiler/main.hexa:21–40` are stub-only, so the entire stage 1 compile is a **single-file analysis of `main.hexa`**. None of `lex/`, `parse/`, `check/*`, `lower/*`, `codegen/*`, `emit/`, `diag/`, `optimize/`, `link/` contributes any items to the type env.

Stage0 hexa_interp also prints ~5,300 untyped runtime warnings (`map key 'tag'/'bindings'/'sigs'/'kind' not found`) — these are interpreter shape-tolerance, not native-compiler diagnostics.

## Stage 1 Reach Estimate

**Realistic: 6–10 weeks of focused work.** NOT "2 weeks of small fixes."

Two large buckets:
- Single-file → multi-file pivot (Gap 1) — structural; cascades into Module shape, name resolution, diag attribution, namespace renames (Gap 10).
- Codegen breadth on real compiler source (Gap 15) — M0 only proved `fn main() -> i32 { return 0 }`; real source exercises closures, growable arrays, match-on-enum, nested struct construction.

Smaller items (3, 4, 5, 7, 11, 12, 13) total ~1–2 weeks aggregate.

Parser/lexer rewrite **NOT** required — existing parser handles all idioms — but error recovery hardening (Gap 5–6) is on the critical path.

## Biggest Unknown

**Lower → codegen behavior on real compiler/ source.** Everything halted at the check phase, so MIR / LIR / asm coverage gaps are completely invisible from this run. Until Gaps 1–10 land, we have zero data on whether the lowering passes can express:
- closures over mutables
- nested struct construction
- growable arrays
- `match` over user enums

…all of which appear pervasively in `compiler/parse/parser.hexa` and `compiler/check/types.hexa`. That's the hidden iceberg.

## Punch List (ordered by effort to first stage 1 binary)

| # | Site | Issue | Sketch | Effort |
|---|---|---|---|---|
| 1 | `compiler/parse/parser.hexa:1022` `pub fn parse` | Recursive import loader missing | walk imports, `read_file`, lex+parse each, splice items into top `Module` (or `WorldModule`); add file attribution to each item | **L** |
| 2 | `compiler/check/types.hexa:1170` `type_check` | Once world-module exists, `_collect_item_types` must dedupe across files and respect `pub` | namespace by `module.file`, treat non-`pub` as private | **M** |
| 3 | `compiler/check/types.hexa:1199` (let-RHS) | False HX3001 for unannotated lets — empty `name` slips through `_lower_type_ref:657` and maps to `unit` | require `kind=="named"` to imply non-empty name; or audit `parse_let_item` for stale `TypeRef` | **S** |
| 4 | `compiler/check/types.hexa:1192/900` | HX3004 wrongly attributed to `_normalize_argv` for every fn | confirm `CheckCtx` is value-copied per fn (line 1183); `_infer_expr` must not mutate ctx0 transitively | **S** |
| 5 | `compiler/parse/parser.hexa:670` `parse_block_expr` | `eat(LBrace)`/`eat(RBrace)` are NOPs on miss; silently consumes next fn into prior body | replace with `expect`+diag on missing `{`/`}` | **S** (needs diag plumbing) |
| 6 | `compiler/parse/parser.hexa:163`/`146` | `expect`/`eat` fabricate token without advancing on miss; recovery silent | emit HX1xxx parse diag and skip-to-resync (`}` / `;` / top-level kw) | **M** |
| 7 | `compiler/parse/parser.hexa:857` | `eat(KwMut)` accepted unconditionally | split `parse_let_mut_item` | **S** |
| 8 | ~30 sites across `check/{bind,units,types}.hexa` | Stage0 shape-tolerance reliance — `match` over enum produces `map key 'tag' not found` until LHS is real enum value | strict struct-lit completeness lint (already partial) | **M** |
| 9 | `compiler/main.hexa:39` | (Stale gap from earlier note: import diag/builder was claimed missing — ACTUALLY PRESENT) | delete from punch list | — |
| 10 | Cross-tree `_helper_name` collisions | 30+ collisions across check/lower/diag (`_lower_type_ref`, `_emit_hx3001`, `_t_unit`, `_env_define`, `_infer_expr`, `_basename_no_ext`, `_render_one`, `_has_errors`, ...) — surface once imports actually load | systematic prefix per file (`_types_*`, `_bind_*` etc — already partial) | **M** mechanical, large surface |
| 11 | `compiler/atlas/embedded.gen.hexa` | Once self-compiling, `AtlasIndex` data shape must round-trip through `_collect_item_types` | likely already-fully-literal; verify | **S** |
| 12 | `compiler/check/units.hexa:837/1060` | `.sigs` read on possibly-uninit context | ensure `UnitsCtx` defaults `sigs: []` | **S** |
| 13 | `compiler/check/citation.hexa` + `compiler/check/annotations.hexa` | Silent today (main.hexa has no `@cite`); once full compiler/ source loads, HX1042 atlas misses fire | gate citation on `--strict-citations` initially | **S** |
| 14 | `compiler/lower/{ast_to_hir,hir_to_mir}.hexa` | Never reached in this run (aborted at check) | unknown until 1–10 land | unknown, likely **M** |
| 15 | `compiler/codegen/{arm64_darwin,x86_64_linux}.hexa` + `emit/asm.hexa` | Proven on M0 only; real compiler source hits far more MIR/LIR ops | broaden lowering coverage | **L** |

## Diagnostic Capture

The full stderr is at `/tmp/stage1.err` (5,524 lines; structured diags at 5,524–5,551).

```
hexa-compiler: 9 diagnostic(s); aborting before codegen
  HX3001 ×1   (false positive — Gap 3)
  HX3004 ×8   (false positive — Gap 4)
exit 1
```

## Suggested Order of Attack

```
Week 1  →  Gap 3, 4, 5, 7, 11, 12, 13          (S items, free up signal)
Week 2  →  Gap 1 (multi-file)                  (L item — biggest pivot)
Week 3  →  Gap 2 (cross-file dedup) + Gap 8    (M items)
Week 4  →  Gap 6, 10                           (M items, mechanical)
Week 5+ →  Gap 14 (lower) + Gap 15 (codegen)   (L items, the iceberg)
```

Stage 1 fixed-point byte equality (stage 2 == stage 3) is **a separate milestone after stage 1 binary first runs** — likely +2–3 weeks beyond the table above for stabilization.
