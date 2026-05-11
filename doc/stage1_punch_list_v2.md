# Stage 1 Bootstrap — Discovery Punch List v2 (Post Gap 1+2+14+15)

> Source: stage 1 first-attempt self-compile after Gaps 1 (multi-file
> splice), 2 (cross-file dedup), 14 (lower diag plumbing), and 15
> (codegen breadth) all landed.
>
> Invocation:
>   `$HOME/.hx/bin/hexa_real run compiler/main.hexa --emit=asm \
>    -o /tmp/stage1_self.s compiler/main.hexa`
>
> Status (original capture): **discovery only — no fixes applied**. Captured 2026-05-10.
>
> **Superseded — see "Update 2026-05-11 (PM)" below**: the closure round
> (2026-05-11) landed A1 + A2 and re-promoted `~/.hx/bin/hexa_real`; the #13
> RSS re-probe (uncapped) shows peak ~782 MB (was 3 510 MB) → **P0 stage-1
> source-side OOM is closed at current scale**. The original TL;DR and "Was:
> 6–10 weeks / Now: 14–22 weeks" estimate below are the 2026-05-10 snapshot;
> the open work toward a full stage-1 binary is now the compiler-driver gaps
> + a fixed-point (stage2 == stage3) re-estimate, no longer host-OOM-bound.

---

## Update 2026-05-10 (post A1 rebuild — host hooks active)

The A1 host-side arena-reset hooks (commit a0f5cd5d) were inadvertently
reverted by commit 9210e024 (RFC-022 G2 wilson gate, runtime.c -105/+38)
on the same day. This update restores them in `self/runtime.c` and
rebuilds `hexa.real` (clang -O3, 6 s) plus `build/hexa_interp.real`
(clang -O2 on `/tmp/hexa_full_regen.c`, 1 min 18 s wall, 27 s user CPU).
The transpile-then-clang pipeline collapses to a clang-only step
because the cached `hexa_full_regen.c` already `#include`s the
restored `self/runtime.c`. No retranspile needed, total rebuild ≈ 90 s.

Stage 1 self-compile probe (post A1 hooks live):

| metric                | pre-A1 (cfc883af) | this rebuild (a0f5cd5d + restore) | target |
|-----------------------|-------------------|------------------------------------|--------|
| wall                  | ~16 m (OOM @ 2 GB cap, exit 77) | 13 m 55 s (835 s, harness SIGTERM) | < 8 m  |
| peak RSS              | 2 048 MB (cap)    | **3 510 MB** (`/usr/bin/time -l`)  | < 1 500 MB |
| observable diags      | 0                 | **14** (parse errors on stdout)    | > 0    |
| arena reset firings   | n/a               | confirmed (RSS sawtooth: 1 415 → 1 024 MB, 3 331 → 2 046 MB) | n/a |

Hooks proven live by direct probe — `env("__HEXA_ARENA_PHASE_RESET__")`
returns `"1"`, `env("__HEXA_ARENA_RSS_MB__")` returns numeric MB,
`env("__HEXA_PHASE_LOG__name")` emits the formatted stderr line.

**Reset works, but it's not enough.** The sawtooth in the RSS log
shows the bump arena IS being rewound on each `phase_reset` call —
yet peak still climbs to 3.27 GB. The reclaimable mass (str/Val
bump-arena scratch) is dwarfed by what A1 explicitly does NOT touch:
`array_store` / `map_store` / `struct_store` from
`_splice_imported_items` (every `out.push(it)` allocates a fresh
`[Item]` and the prior list stays referenced) plus per-fn `_infer_expr`
type-check intermediates that hold across phases. Diagnostic capture
crossed the parse boundary — 14 parse errors emitted (vs 0 pre-A1) —
so we now *can* see the parser's view of the spliced super-module
even though the run still over-runs the budget downstream.

Baseline tests preserved on the new host (binary at `/tmp/hxA1`,
deployed to `hexa.real` + `build/hexa_interp.real`):

- `self/test_enum_payload_full.hexa`: 15/15 PASS
- `stdlib/test/test_cancel.hexa`: 23/23 PASS
- `self/test_async_codegen.hexa`: 4/4 PASS (RFC-022 G2)
- `compiler/check/{bind,types,resolve}_test.hexa`: PASS each
- `compiler/main.hexa --emit=asm tests/m0/hello.hexa`: 377-byte `.s`
  (matches pre-A1 baseline byte-for-byte; 371 in spec is older).

**Verdict on A1 alone**: P0 partially mitigated. The host hooks are
necessary but not sufficient. Stage 1 still cannot land via in-process
super-module compile. The next blockers are:

- **A2** (`_splice_imported_items` in-place accumulator) — eliminates
  the per-import `[Item]` array growth that dominates `array_store`.
  Without A2 the array store grows monotonically; A1 only frees the
  bump-arena strings, not the array carrier.
- **M4-fix freelist re-enable** — `array_free_list` reclaim is
  currently disabled (`self/hexa_full.hexa` line ~17993). Once A2
  reduces the *churn* the freelist needs to *reclaim* the freed slots
  for the GC effect to surface.
- **A3** (hash-keyed env in types.hexa) — already landed at
  `9dfe7bd0`; should reduce the type-check inner-loop wall component
  but does not affect peak RSS (it was always CPU-bound, not memory).

Estimate: A1 + A2 + freelist together likely bring peak RSS into the
~1.5 GB target band; without all three, the spliced super-module
remains beyond the in-process budget. Option (b) — partial self-compile
mode that emits each leaf module separately and links — remains the
durable escape valve if A2 proves harder than expected.

---

## Update 2026-05-11 (A2 source landed; verification deferred to next host rebuild)

Source-side delta since the 5/10 baseline above:
- A2 landed at `ab2dfcee` (`fix(compiler/parse): A2 — in-place
  _splice_imported_items accumulator`). Per-call `[Item]` allocation
  collapsed to a module-scoped accumulator `p_splice_acc` —
  the array-store growth path the 5/10 sawtooth showed A1 cannot reach.
- Host transpiler rebuilt at `ddb21f21` (`self/native/hexa_v2` +536 B,
  matches the d99be4bd "host alongside source" pattern).
- Cluster work integrated since A2: Types (A4/C4/B2) `bc50db32`,
  C11 parse_only skip `2b67ccb6`, Lower (C5/C9/C10/C16, +HX1101..3 to
  catalog) `f3f63b72`, B1+C19 `4cd39b2a`, P2 (C12..C20, +HX2003)
  `840c8f7d`. #14 drain wiring `18c6a536` makes the new HX1101/1102/1103
  surface in CLI alongside parser/check/units diags. Out-of-band:
  `faca4134` (stdlib/http_sse v1.1 POST+body) and `21e7b518`
  (cmd_build flatten via module_loader + HEXA_LANG/self -I) close the
  wilson upstream gaps. None of those touch the stage1 OOM directly,
  but C11's `@phase("parse_only")` skip on the ~10K AtlasNode literals
  in `compiler/atlas/embedded.gen.hexa` removes a known fan-out cost
  from the type-check inner loop on the spliced super-module.

| metric                | 5/10 baseline (pre-A2)     | 5/11 probe (HEAD=18c6a536, deployed binary = pre-A2) | target |
|-----------------------|----------------------------|------------------------------------------------------|--------|
| binary used           | 5/10 23:39 hexa_real       | **same 5/10 23:39 hexa_real** (pre-A2)               | post-A2 hexa_real |
| memory cap            | 2 048 MB                   | **768 MB** (current default cap)                     | unlimited |
| wall to OOM           | ~14 m                      | 66 s                                                 | N/A |
| RSS at OOM            | 3 510 MB                   | 805 MB (at cap=768 MB)                               | < 1 500 MB peak |
| outcome               | killed at 2 GB cap         | killed at 768 MB cap (exit 77)                       | clean completion |

**Cannot conclude A2 effect from this probe.** The deployed
`~/.hx/bin/hexa_real` is still the 5/10 23:39 G2 build — A2 source
exists but is not in the running binary. PATCHES.yaml id
`wilson-needs-hexa-real-promotion` carries this caveat (re-promote
pending RSS verify). The 5/11 probe re-measures the *pre-A2* baseline
under a tighter 768 MB cap; the lower cap caused an earlier OOM
exit at 66 s vs 14 m — that's a cap effect, not an A2 effect.

**Closure path (separate next step, not in this commit):**

1. Rebuild `~/.hx/bin/hexa_real` from current sources (A2 + Types +
   C11 + Lower + B1+C19 + P2 + #14 drain). Pipeline: `hexa cc --regen`
   to regenerate `self/native/hexa_cc.c` from the SSOT
   `self/{lexer,parser,type_checker,codegen_c2}.hexa`, then clang →
   new `hexa_v2`, then re-deploy `hexa_real` (same atomic-rename
   pattern as the wilson-needs-hexa-real-promotion 5/10 apply row).
   Total wall ~90 s from the 5/10 record.
2. Re-run probe with the post-A2 binary at cap=2 GB (or
   `HEXA_MEM_UNLIMITED=1`) — same invocation as §"5/10 baseline" above
   so peak RSS is directly comparable.
3. If peak RSS drops below ~1.5 GB → re-enable the M4 freelist
   (`self/hexa_full.hexa` ~line 17993) and re-probe; A1 + A2 +
   freelist together is the predicted-sufficient bundle.
4. If peak RSS stays ≥ 2 GB → A2 alone was insufficient; pursue (b)
   partial self-compile mode per 5/10 verdict.

Step 1 is host I/O + clang only, modest ROI; step 2 is the actual
verification. Both are gated on Mac compute availability — the
synced repo on the Linux side has stale `.git` state that breaks
worktree-isolated agent work, so the rebuild must run mac-local.

---

## Update 2026-05-11 (PM) — post-promote RSS verification: P0 OOM closed at current scale

Closure-path step 1 done: `~/.hx/bin/hexa_real` (and `~/.hx/packages/hexa/hexa.real`,
same binary) re-promoted at commit `774c5d32` — sha256
`ffa91279f47eccb5ac6a8471a54d1fc1f400db8f23bf89ddd9310f1b6c9e7287`, built
`self/native/hexa_v2 self/main.hexa → /tmp/hexa_main_regen.c ; clang -O0
-fno-strict-aliasing -std=c11 -I self → hexa_real ; codesign -s -` from HEAD
`64dc8488` (= #12 cmd_build flatten + A2 splice + Types/C11/Lower/B1+C19/P2
clusters + #14 drain). Backups `*.bak.1778481370`; manifest_log.jsonl promote row.

Step 2 — RSS re-probe with the post-A2 deployed binary, uncapped:

```
RESOURCE_LOCAL_HEXA=1 HEXA_MEM_UNLIMITED=1 HEXA_LANG=$PWD \
  /usr/bin/time -l ~/.hx/bin/hexa_real run compiler/main.hexa \
  --emit=asm -o /tmp/stage1_self.s compiler/main.hexa
```
(`hexa_real run` LB-routes to a remote compute sandbox by default — `RESOURCE_LOCAL_HEXA=1`
forces the local `~/.hx/packages/hexa/build/hexa_interp.real`; `/usr/bin/time -l`'s
`ru_maxrss` on macOS includes the waited-for interp child, so wrapping `hexa_real` captures it.)

| metric                | 5/10 baseline (pre-A2)  | 5/11 PM (post-A2 binary, HEXA_MEM_UNLIMITED) | target            |
|-----------------------|-------------------------|----------------------------------------------|-------------------|
| binary used           | 5/10 23:39 hexa_real    | **774c5d32 hexa_real** (A2 source + A1 hooks) | post-A2 hexa_real |
| memory cap            | 2 048 MB (hit it)       | **unlimited**                                | unlimited         |
| RSS at OOM / peak     | 3 510 MB (killed)       | **~782 MB peak** (781 712 KB on the interp child), then **dropped to ~160 MB** when the A1 phase-arena reset fired (~21 min in) | < 1 500 MB peak |
| outcome               | killed at 2 GB cap      | no cap hit; RSS plateaued (not climbing) — CPU-bound from there, run continues | clean completion |

**Verdict: P0 stage-1 OOM is closed at current scale.** A2 (`p_splice_acc` in-place
accumulator, `ab2dfcee`, source-level so it's exercised inside the flattened
super-module) + A1 (phase-arena reset hooks in the 5/10 `hexa_interp.real`) together
take peak RSS from 3 510 MB → ~782 MB — a ~78 % cut, well under the 1 500 MB
threshold. The mid-run drop to ~160 MB confirms the A1 reset hooks are live in the
deployed interp binary and that the parse-phase arena (which A2 stops bloating) is
the bulk of the high-water mark. C11's `@phase("parse_only")` skip on the ~10 K
`AtlasNode` literals further trims the type-check fan-out on the spliced module.

Caveat: this measures peak RSS, not full self-compile completion — at ~21 min the
interpreted `--emit=asm` codegen was still grinding CPU (~20.5 min UTIME). It's slow
(interpreted whole-compiler codegen) but **not** memory-bound, so it's a wall-clock
nuisance, not an OOM. The `.s` output / exit code is incidental to the OOM verdict.

**Remaining (now optional, belt-and-suspenders — 782 MB << 1.5 GB already):**
- Step 3: re-enable the M4 freelist (`self/hexa_full.hexa` ~line 17993, `array_free_list`
  reclaim) and rebuild `~/.hx/packages/hexa/build/hexa_interp.real` (= `tool/build_interp.hexa`,
  separate from the `hexa_real`=`self/main.hexa` build done above), then re-probe. Predicted
  to shave the ~782 MB peak further but no longer needed to clear the wall.
- A3 (hash-keyed env in `compiler/check/types.hexa`) — already landed (`4ed9966e`); the
  ~782 MB figure already includes it.

---

## TL;DR

The self-compile **never reaches a structured diagnostic**. The stage0
hexa_interp runtime aborts via its own memory cap before parse +
type-check finish on the 25,932-line spliced super-module that Gap 1
now produces from `compiler/main.hexa`'s 19 imports.

Concrete capture:

| run                         | flags             | wall  | result                                |
|-----------------------------|-------------------|-------|---------------------------------------|
| `--emit=asm` self           | default cap 2 GB  | ~16 m | `[hexa-runtime] memory cap exceeded: rss=2048MB > cap=2048MB`, exit 1 |
| `--emit=asm` self           | `HEXA_MEM_UNLIMITED=1`, 25 m budget | aborted by harness | RSS still climbing (1.5 GB → killed) — no diags emitted |
| single-file `tests/m0/hello.hexa` | default          | <1 s  | clean, 371-byte `.s`                  |
| single-file `compiler/check/units.hexa` (1,131 lines, 4 imports) | 60 s timeout | timeout | hits Gap-1 splice, no output |

So the **diagnostic count is unobservable** at this stage. Gap 1 was so
successful at loading the world that the interpreter, rather than the
compiler, became the first wall.

This is itself the headline new finding: **stage 1 cannot land while
stage 0 is the harness for self-compile**. Either (a) stage 0 needs a
fast-path / arena reset / interner so the spliced AST + lower IR fits
in <1 GB, or (b) stage 1 needs a *partial* self-compile mode that
emits each leaf module to `.s`, links them, and skips the in-process
super-module entirely, or (c) we need a stage 0.5 — a host-language
(C / Rust) re-implementation of just enough of the interpreter to
host the compiler. Today, none of (a)/(b)/(c) exists.

---

## Pipeline Reach

`lex` → `parse` (with Gap 1 splice) → ??? . The interpreter ran for
~16 minutes consuming 2 GB before the runtime aborted; the program
emitted **zero stdout, zero stderr** prior to the runtime's own OOM
note. We cannot tell from this run whether it was inside `parse` (the
splice itself), inside `_collect_item_types` (Gap 2 pre-pass — O(n)
linear walk over n≈3,000 spliced items, plus an O(n) lookup in
`_types_pub_owner_file` per item, so O(n²) in n-items ≈ ~9 M
comparisons of stage0 strings), inside `_infer_expr` per fn body, or
inside `lower(module, atlas)`.

Best guess from RSS/CPU profile (RSS climbed monotonically through
the 1.5 GB threshold while CPU stayed ~30–60 %): the interpreter is
holding onto every intermediate `Module.items` snapshot built by
`_splice_imported_items` because each `out.push(it)` allocates a fresh
list and the prior list is still referenced. Stage 0 has no arena
reset between phases.

---

## Diagnostic Capture vs cfc883af baseline

| run | diag count | shape | reach |
|---|---|---|---|
| cfc883af (Gap 1 NOT landed) | 9 | 1× HX3001 + 8× HX3004 | through types (single-file, ~700 LOC) |
| **this run** (post Gap 1+2+14+15) | **0** observable | runtime OOM before any HX-emit | unknown — likely inside parse/splice or types pre-pass |

The shape is fundamentally different: the prior run was bottlenecked by
the type-checker's false-positive pattern on the 700-line single-file
Module. The new run is bottlenecked on the *interpreter's* memory
budget while loading the world. **None of the prior 9 diagnostics
recurred** in observable form; they may still be there waiting behind
the wall, but we cannot say.

---

## New Punch List

Each entry: file:line / phase, description, fix sketch, effort
(S/M/L), priority (P0=blocks stage 1 binary entirely, P1=blocks
correctness, P2=improves but not blocking).

### A. Bootstrap host (the new wall)

| # | Site | Issue | Sketch | Effort | Pri |
|---|------|-------|--------|--------|-----|
| A1 | `hexa_real` (stage0 runtime) | 2 GB hard cap, no arena reset between pipeline phases | add `--phase-arena-reset` so `parse` / `lower` / `codegen` allocations free between calls; current behaviour holds every Module snapshot from `_splice_imported_items`. | **L** | **P0** |
| A2 | `compiler/parse/parser.hexa:1312 _splice_imported_items` | Naive `out.push(...)` over a re-built `[Item]` for every visited file → O(n²) memory growth in items×imports | replace with a single accumulator passed by reference; or build flat list once and mutate in place under a phase arena (depends A1) | **M** | **P0** |
| A3 | `compiler/check/types.hexa:1356 _collect_item_types` | Each `_types_find_binding` / `_types_pub_owner_file` is O(n) in env.entries; total O(n²) over ~3 K spliced items ≈ 9 M scans of stage0 strings | introduce a hash-map binding lookup keyed by `(name, owning_file)` and `name → first pub`; stage0 has no native map but we can use the `intrinsics/intrinsics.hexa` candidate or tabulate via dedicated arrays | **M** | **P0** |
| A4 | `compiler/check/types.hexa:1442 type_check` outer loop | Re-walks every Item in module.items linearly; with ~3 K items and per-fn body O(b) inner traversal, throughput becomes infeasible under stage0 dispatch overhead | profile dispatch first (likely the `match k` over ExprKind tag in `_infer_expr` is the inner loop); consider computing `is_fn_item` once via a side index | **M** | **P1** |

### B. Recurring from v1 — surfaces once we cross the wall

| # | Site | Issue | Sketch | Effort | Pri |
|---|------|-------|--------|--------|-----|
| B1 | (formerly Gap 3) `compiler/check/types.hexa:660` | `kind=="named"` empty-name guard now in place but only for `_types_lower_type_ref`; other consumers (`_hir_lower_type_ref` lines 102–134) lack the same degrade — risk of recurring HX3001 cascades inside the hir lower path once visible | mirror Gap 3 fix into `compiler/lower/ast_to_hir.hexa::_hir_lower_type_ref` | **S** | **P1** |
| B2 | (formerly Gap 4) `_types_check_call`, `_types_check_binop` | Per-fn ctx is value-copied via `_ctx_with_fn` (line 963), but the `out: array` accumulator is shared and mutated; in stage0 a single bad fn could still attribute its HX3004 to the wrong fn name when `_emit_hx3004` reads `ctx.fn_name` from a stale frame | thread `ctx.fn_name` through `_emit_hx3004(...)` arg explicitly rather than via shared mutable | **S** | **P1** |
| B3 | (formerly Gap 5/6) `parser.hexa:163 expect`, `:146 eat` | `expect` fabricates token without advancing on miss → `parse_block_expr` (line 670) silently swallows next fn into prior body when a `}` is missing; HX0011/HX0012 added in Gap 5 cover the brace shape but recovery is still single-token-skip | replace `expect` with `expect_or_diag_and_resync` that skips to next `}` / `;` / top-level keyword | **M** | **P1** |
| B4 | (formerly Gap 7) `parse_let_item:857` | `eat(KwMut)` accepted unconditionally — no diag if `mut` mis-typed as `mu` | split into `parse_let_mut_item` and `parse_let_imm_item` | **S** | **P2** |
| B5 | (formerly Gap 10) cross-tree `_helper_name` collisions | Existing Gap 10 work added `_types_*` / `_hir_*` prefix discipline but new files (`emit/asm.hexa`, `optimize/*.hexa`) regressed: e.g. `_op_reg`, `_op_imm`, `_op_label`, `_instr2` defined in BOTH `codegen/arm64_darwin.hexa` and `codegen/x86_64_linux.hexa` (same module after splice) | rename to `_arm64_op_reg` / `_x86_op_reg` etc.; same for `_emit_*` helpers across diag/render and codegen | **M** | **P0** (will collide once visible) |

### C. New, never seen before (post-Gap 1+2 surface)

| # | Site | Issue | Sketch | Effort | Pri |
|---|------|-------|--------|--------|-----|
| C1 | `compiler/lower/hir_to_mir.hexa:34–40` and `compiler/codegen/arm64_darwin.hexa:41–47` | Both files redeclare `_STMT_ASSIGN` / `_STMT_BR` / etc. as a workaround for "stage0 does not propagate transitive `pub let`" — once Gap 1 splices everything into one Module, these become **duplicate top-level `let` items** at the spliced level. `_collect_item_types` will record each twice, both private — first registration wins, second silently dropped, but stage0 ident resolution may still pick the wrong one. | promote to a single shared file (`compiler/ir/stmt_kinds.hexa`) and import once; OR strip the workaround entirely now that Gap 1 propagation works | **S** | **P0** |
| C2 | `compiler/main.hexa:504` `fn _mmod_stmt_count` defined inline mid-driver, after `let user_argv = ...` initializers | Spliced into the world Module, this fn appears between top-level executable statements. Stage0 hexa runs top-level statements top-to-bottom; the fn definition is hoistable but in stage1 the linear order matters for codegen — block_label collisions possible | extract to `compiler/optimize/_stmt_count.hexa`; remove inline fn entirely | **S** | **P1** |
| C3 | `compiler/parse/parser.hexa:1359 parse()` | Returns `Module { file, items: merged_items, imports: top.imports }` — but `imports` only reflects the entry file. Gap-1 deeper diag-attribution wants per-file `imports` too. Some Gap-2 / Gap-13 diagnostics will mis-attribute `importer` | extend `Module` with `[ModuleSlice { file, imports }]`, OR keep a flat `(file, import)` list | **M** | **P1** |
| C4 | `compiler/check/types.hexa:1183` `_types_check_call` | Callee resolution returns `_types_empty_type()` on miss and silently skips arity / arg-type check. Once Gap 1 surfaces ~80 callable names from spliced files and Gap 2 dedupes them, *every* miss becomes an HX3002/3 floor; without this check a typo in a callee name passes through to lower → MIR with a `?` type, then codegen blows up | emit HX2001 (unknown callee) on miss BEFORE the early return; coordinate with bind/resolve so the check isn't double-fired | **S** | **P1** |
| C5 | `compiler/lower/hir_to_mir.hexa:422 _lower_hexpr` k=="ident" branch | When `_mir_lookup` misses, returns `_const_int_op(0)` — a silent zero. Spliced super-module has many cross-file ident references; any miss now produces zero-coded MIR rather than a diag | propagate the miss as HX1101 (unbound ident in lower); make ident-resolution failures fatal | **S** | **P1** |
| C6 | `compiler/codegen/arm64_darwin.hexa:130 _arm64_reg_for_local` | Naive `id mod 31` with no spilling. The compiler's own fns (e.g. `parse_fn_item`, `_collect_item_types`) declare 50–80 SSA locals each → modulo aliasing over x0..x30 will silently overwrite live values. Stage1 will produce *wrong code* not bad code — no diagnostic emitted | introduce minimal liveness-aware regalloc (linear scan); v0 stage1 may still demand spilling for `compiler/check/types.hexa::_infer_expr` (60+ locals) | **L** | **P0** for correctness |
| C7 | `compiler/codegen/x86_64_linux.hexa:202 _x86_64_arg_reg_seq` and arm64 mirror | Both targets `nop`-comment >6/>8 args and continue. `compiler/parse/parser.hexa::_splice_imported_items(items: [Item], importer: string)` passes 2 args ok, but `_emit_hx3003(name, pos, expected, actual, sp, out)` takes 6 — at boundary; many real hexa fns take 7+ | implement 7th+ arg stack spill (System V on x86_64, AAPCS64 with `[sp, #16]+` on arm64) | **M** | **P0** |
| C8 | `compiler/codegen/arm64_darwin.hexa:196 _arm64_block_label` | Returns `"_L" + fname + "_bb" + ...` — `fname` is the user fn name including possibly `<` or `:` characters from spliced lambdas? Today there are no lambdas, but `compiler/check/units.hexa::_t_unit` and `compiler/check/types.hexa::_t_unit` would now both produce `_L_t_unit_bb0`, colliding | qualify with module hash: `_L<hash8>_<fname>_bb<id>`; adopt now to avoid a debug session later | **S** | **P0** |
| C9 | `compiler/lower/hir_to_mir.hexa:617 if-branch` | `_new_block` then `_set_cur_block(then_id)` then `_lower_hexpr(child)` — but `_lower_hexpr` may itself call `_new_block` (nested if / while), invalidating `then_end_block`. The `_push_stmt_to(then_end_block, br_then)` may target a stale block id | recompute `then_end_block = ctx2.cur_block` AFTER the inner lower returns (already done — line 645) but parallel `else_end_block` path missing the same recompute on the no-else fall-through | **S** | **P1** |
| C10 | `compiler/lower/hir_to_mir.hexa:780 match-arm lowering` | Pattern lowering only handles `wildcard`, `ident`, and `enum_path`. `compiler/parse/parser.hexa::tag_of(k)` matches over 30+ enum variants; if the parser ever emits a struct-pattern or literal-pattern, lower drops it silently | extend pattern match to literal_int/literal_string/struct_pattern; emit HX1102 on truly unknown shapes | **M** | **P1** |
| C11 | `compiler/atlas/embedded.gen.hexa` (existence) | Mentioned in v1 punch list as untouched. Now that splice loads it, it ships with ~10 K AtlasNode literals, each a struct value. Stage0 interp stores them as 10 K live frames during parse → contributes to A1's OOM | mark as `@phase=parse_only` so checker can skip walking; or convert to a lazy `static_atlas()` callback | **M** | **P0** (memory) |
| C12 | `compiler/check/citation.hexa` | Default soft mode (Gap 13) demotes to Warnings, but the citation pass still **walks every Item in the spliced module** building atlas-ref index; this walk is roughly free for 700 items but ~3 K items * each fn body ~30 nodes = ~90 K AtlasRef checks per compile | gate the entire walk on `--strict-citations` instead of per-diag demotion | **S** | **P2** |
| C13 | `compiler/check/units.hexa::unit_check` | Same scaling concern: walks every fn for `@units(...)` annotation. Most compiler/ fns are unannotated, but the early-out check is at line ~870 and runs after token scan | early-out on `len(fn.annotations) == 0` before any unit string parsing | **S** | **P2** |
| C14 | `compiler/main.hexa:417` `let mut diags: array = []` | Untyped `array` here means stage0 boxes every Diagnostic. With ~3 K candidate sites for diags emerging from a real compile, the array could grow large; resizing copies are O(n) | type as `[Diagnostic]`; pre-size hint via `with_capacity()` once that intrinsic lands | **S** | **P2** |
| C15 | `compiler/main.hexa:540` `let mut lmodule = LModule { ... }` then unconditionally overwritten | Wasted alloc — small, but stacks up across recursive calls | replace with `let lmodule = if ... else if ... else { exit(2) }` | **S** | **P2** |
| C16 | `compiler/lower/hir_to_mir.hexa::lower_hir` | No diagnostic plumbing for "unhandled HExpr kind". The `_lower_hexpr` default fall-through (line 1545) silently produces an empty HExpr-shaped output; lower then treats it as ok. Many real source constructs (e.g. Field on a struct lit, growable array methods) take this fall-through path today | add `_lr_diag` accumulator and HX1103 emission on default fall-through; mirror the Gap 14 sink convention | **M** | **P0** for correctness |
| C17 | `compiler/parse/parser.hexa:670 parse_block_expr` | `eat(LBrace)`/`eat(RBrace)` softness reported in v1 (Gap 5) — Gap 5 emitted HX0011/HX0012 but **only for the outer block** (the `parse_fn_item` body). Nested blocks (if/while/for) still call `eat(LBrace)` directly at parser.hexa:683, :701, etc. | refactor every `eat(LBrace)/(RBrace)` into a single `expect_balanced_block` helper that also emits HX0011/HX0012 | **M** | **P1** |
| C18 | `compiler/codegen/arm64_darwin.hexa::_arm64_op_for_operand_st` | `const_str` falls back to `_op_label(o.str_val)` when strtab miss — emits the literal string itself as a label, which `as` will reject. Today the strtab-collect pass is supposed to populate every `const_str` first, but in spliced mode imported files' string literals may produce const_str ops via paths the strtab walk hasn't visited (e.g. lower-emitted internal labels like atlas keys) | emit `.LCstr_unknown_<hash>` as the fallback label and queue it for rodata emission | **S** | **P1** |
| C19 | `compiler/lower/hir_to_mir.hexa::_lower_hexpr "for"` branch (not shown above) | If parser produces ExprKind::For, hir_to_mir lacks an explicit handler — falls to default-recurse which generates wrong MIR (no loop CFG). Stage0 has historically used `while` only, but parser does support `for x in expr {}` | implement `for` desugar in `ast_to_hir` (lower to while + iterator next) BEFORE hir_to_mir sees it | **M** | **P1** |
| C20 | `compiler/check/types.hexa::_types_check_call` ‑- callee_t.kind != "fn" early return | Returns `_types_empty_type()` silently on a non-fn callee (e.g. calling a struct field or local var). After Gap 1 imports many user-named items into the env, `let mut x = 0; x()` returns unit silently | emit HX2003 (not callable) on miss | **S** | **P2** |

---

## Summary by Priority

| Priority | Count | Examples |
|---|---|---|
| **P0** (blocks stage 1 binary) | 9 | A1 (interpreter cap), A2 (splice memory), A3 (env O(n²)), B5 (helper collisions), C1 (STMT_ const dup), C6 (regalloc spill), C7 (>6/>8 args), C8 (label collisions), C11 (atlas embed memory), C16 (lower diag plumb) |
| **P1** (blocks correctness) | 9 | A4, B1, B2, B3, C2, C3, C4, C5, C9, C10, C17, C18, C19 |
| **P2** (improvement, not blocking) | ~6 | B4, C12, C13, C14, C15, C20 |

(Some bullets straddle P0/P1; chosen on first-impact severity.)

---

## Revised Stage 1 Reach Estimate

**Was: 6–10 weeks of focused work.**

**Now: 14–22 weeks**, dominated by category A (host bootstrap).
Breakdown:

| Bucket | Old est. | New est. | Why moved |
|---|---|---|---|
| Gap 1–10 originals (smaller pivots) | 4 weeks | **0 weeks (most landed)** | Done by this run |
| Gap 14 lower diag + Gap 15 codegen breadth | 2–4 weeks | **+2 weeks (C6, C7, C8, C16)** | New gaps surfaced once visible |
| **Stage 0 host** (A1–A4 + C11) | not on map | **+6–10 weeks** | Hidden iceberg; must add interpreter arena reset OR write stage 0.5 host |
| Stage 1 byte-equality fixed point | 2–3 weeks | 4–5 weeks | More moving pieces post-Gap-1 |

So minimum **14 weeks** if we get lucky with stage 0 patches; **22
weeks** if we need a stage 0.5 host. Either path beats writing
stage 1 in C/Rust outright (which would be 26–40 weeks for just
matching the current hexa-side surface), but the gap to the original
6–10 estimate is real.

---

## Biggest Remaining Unknown

**What is the actual diagnostic shape on a *successful* self-compile
trace?** We literally cannot see it. Every probe that crosses the
Gap 1 splice threshold either OOMs or stalls under stage 0. Until
A1+A2+A3 land, Bs and Cs in this list are **inferences from reading
source, not from observing diagnostics**. Confidence:

| signal source | confidence |
|---|---|
| Source-read inferences (B1–B5, C1–C20) | medium-high — these are real code shapes, but their *severity* under real diag traffic is unknown |
| Memory-cap measurement (A1, A2, A3, C11) | high — directly observed runtime crash |
| The 9 prior diagnostics (cfc883af) recurrence | unknown — they may be already-fixed, masked by the OOM, or queued behind it |

The next data-collection step is NOT to fix any of these — it's to
make stage 0 (or a stage 0.5 host) survive the spliced compile so we
can see what comes out the other side. That's the new critical path.
