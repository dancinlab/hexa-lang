# `hexa build core/main.hexa` (wilson) — post #12-fix + hexa_real re-promote: new C-compile wall

**Date:** 2026-05-11
**Context:** After re-promoting `~/.hx/bin/hexa_real` (commit 774c5d32 — #12 cmd_build
flatten via module_loader + `$HEXA_LANG/self` `-I`, A2 splice accumulator, the
Types/C11/Lower/B1+C19/P2 clusters, #14 drain), re-ran the wilson out-of-tree build.

## Progress — the #12 fix works

`cd ~/core/wilson && HEXA_LANG=$HOME/core/hexa-lang ~/.hx/bin/hexa build core/main.hexa -o build/wilson`
now:
- flattens the full `use`/`import` graph (module_loader.hexa, not the legacy
  top-level-only flatten),
- resolves `clang -I` to `$HEXA_LANG/self` (so `#include "runtime.c"` works
  without the `ln -s ~/core/hexa-lang/self ~/.hx/bin/self` workaround),
- transpiles to `build/artifacts/wilson.c` (~10 K lines, 466 KB) and reaches
  the **clang compile step**.

Previously it died at link time with undefined symbols because `app.c` only had
`main.hexa`'s code. That class of failure is gone. ✅ — `wilson-needs-hexa-build-out-of-tree`
(PATCHES.yaml, applied 21e7b518) is verified.

## New wall — `build/artifacts/wilson.c` doesn't compile

Two distinct codegen gaps surfaced (clang `-ferror-limit` cut it at 20):

### (1) match-arm payload bindings not emitted — RFC-020 A4 gap

```c
} else if (hexa_truthy(hexa_eq(__match_val, AsmEvent_ToolCallEnd))) {
    hexa_array_push(..., ToolCall(hexa_map_get_ic(tc, "id", ...), ...));   // 'tc' undeclared
} else if (hexa_truthy(hexa_eq(__match_val, AsmEvent_Usage))) {
    usage = u;  host_emit(host, ..., u);                                   // 'u' undeclared
} else if (hexa_truthy(hexa_eq(__match_val, AsmEvent_StopReason))) {
    stop_reason = hexa_map_get_ic(s, "s", ...);                            // 's' undeclared
} else if (hexa_truthy(hexa_eq(__match_val, AsmEvent_StreamError))) {
    _fire_error(host, ..., hexa_map_get_ic(e, "s", ...));                  // 'e' undeclared
}
```
The hexa source is a `match ev { AsmEvent.ToolCallEnd(tc) => …, AsmEvent.Usage(u) => …, … }`.
`self/native/hexa_v2` (= transpiled `hexa_cc.c`) lowers the `hexa_eq(__match_val, AsmEvent_X)`
discriminant test but does **not** emit the per-arm `HexaVal tc = <payload extract>;` binding.
This is exactly the documented `rfc020-enum-payload-variants` state: "A4 hexa_cc.c codegen
partial (a85b8a1c) — match-side payload extraction gap remaining" (PATCHES.yaml, owned by
BG task 72). wilson is now a concrete consumer-side reproducer for it.

### (2) stdlib functions referenced-as-value but not flattened/emitted

```c
HexaVal host_cancel_new(void)         { return __hexa_fn_arena_return(hexa_call0(cancel_new)); }       // 'cancel_new' undeclared
... hexa_call1(cancel_cancel, t) ...                                                                   // 'cancel_cancel' undeclared
... hexa_call1(cancel_is_cancelled, t) ...                                                             // 'cancel_is_cancelled' undeclared
HexaVal l = hexa_call0(read_line_stdin);                                                               // 'read_line_stdin' undeclared
return __hexa_fn_arena_return(hexa_call1(split_ws, s));                                                 // 'split_ws' undeclared
```
`hexa_callN(fn, …)` is the codegen form for invoking a function *value* (a bare function
name used as a first-class reference). The referenced C function (`cancel_new`,
`cancel_is_cancelled`, `read_line_stdin`, `split_ws`, …) is never defined in `wilson.c`.
Likely cause: the modules providing these (`stdlib/cancel.hexa` for the `cancel_*` set;
TBD for `read_line_stdin` / `split_ws`) either (a) aren't being pulled in by module_loader's
flatten for this entry, or (b) are interp-only builtins that have no AOT/runtime.c symbol and
so can't be taken by-reference under codegen. Needs a focused dig: confirm whether
`use "stdlib/cancel"` (or wilson's host shim) is in the flattened graph, and whether
`cancel_new` exists as a `fn` in `stdlib/cancel.hexa` or only as a runtime builtin.

## Bottom line for "path A → wilson builds"

Path A (re-promoted compiled `hexa build`) clears the **flatten + link** layer but **not**
the **codegen** layer. wilson `build` still fails until at minimum RFC-020 A4 (match-payload
codegen) lands; the stdlib-by-reference gap (2) is a second, smaller blocker. Per-module
symbol mangling — the original path-A hypothesis — was never the actual blocker.

**Repro:** `cd ~/core/wilson && HEXA_LANG=$HOME/core/hexa-lang ~/.hx/bin/hexa build core/main.hexa -o build/wilson 2>&1 | tail -45`
(transpile succeeds; clang errors in `build/artifacts/wilson.c` around lines 2745, 3476, 5527, 5813).

---

## UPDATE 2026-05-11 (later) — gap (1) [RFC-020 A4] FIXED

Root cause confirmed: the A4 codegen *did* exist, but only as a hand-applied patch to the
GENERATED `self/native/hexa_cc.c` (commit a85b8a1c) — it was never back-ported to its
source-of-truth `self/codegen_c2.hexa`. The May-11 host rebuilds (`ddb21f21`, `64dc8488`,
both `hexa cc --regen`) re-transpiled `self/{lexer,parser,type_checker,codegen_c2}.hexa` into
a fresh `hexa_cc.c`, which wiped the a85b8a1c hand-fix. So today's `hexa_v2` (and the
`hexa build` AOT path) emitted broken C for any `match` arm with an enum-payload binding —
exactly the `tc`/`u`/`s`/`e` undeclared-identifier errors above.

Fix: ported the a85b8a1c logic into the SSOT `self/codegen_c2.hexa`:
- `gen2_expr` EnumPath: `payload_expr` present -> emit `hexa_array_push(hexa_array_push(hexa_array_new(), <tag>), <payload>)`; else bare `<name>_<value>` tag (zero regression).
- `gen2_match_cond` EnumPath: binder pattern (`pat.left` is an Ident node) -> tag-only compare gated on `HX_IS_ARRAY` reading index 0; no-binder -> unchanged whole-value `hexa_eq`.
- `gen2_match_stmt`: emit `HexaVal <bind> = hexa_index_get(__match_val, hexa_int(1));` as the first line in the matching arm's block.
- `gen2_match_ternary`: wrap the arm value in a GCC statement-expression so the binder is visible to the value while the ternary chain stays intact.
- `gen2_enum_decl`: re-add the `// @payload:` comment header when any variant has a payload type.
- `self/parser.hexa`: added a defensive `"payload_expr": ""` to the match-pattern EnumPath node (mirrors what 4ed9966e did to `self/hexa_full.hexa`).

Then `hexa cc --regen` -> swapped in `self/native/hexa_cc.c` + `self/native/hexa_v2` (the regen
recipe; no hand-edits to the generated files), rebuilt `hexa_real` from `self/main.hexa`, and
re-promoted `~/.hx/bin/hexa_real` + `~/.hx/packages/hexa/hexa.real`.

Verification:
- `self/test_enum_payload_full.hexa` — **15/15 PASS** on the codegen/AOT path (`hexa build`)
  AND **15/15 PASS** on the interpreter path (`hexa run`), byte-identical stdout (RFC-020 §7).
- `test_enum_variant.hexa`, `test_enum_construct.hexa`, `test_enum_path.hexa` (26/26),
  `test_7gate_smoke.hexa` (60/60) — green on the codegen path (no plain-enum regression).
- Self-host smoke: `hexa_v2 self/main.hexa -> main.c -> clang -> ./main --version` OK.
- wilson re-build: the `AsmEvent` enum-payload match no longer errors; `build/artifacts/wilson.c`
  now emits `HexaVal tc = hexa_index_get(__match_val, hexa_int(1));` arm bindings + the
  `// @payload:` header. **gap (1) cleared.**

## Remaining: gap (2) only — stdlib-by-ref undeclared

The wilson build still fails on gap (2): `char_at`, `trim`, `popen_lines`,
`popen_lines_with_status` (and earlier `cancel_new` / `cancel_cancel` / `cancel_is_cancelled` /
`read_line_stdin` / `split_ws`) appear as `hexa_callN(<name>, …)` first-class-function-value
references with no defining C symbol — a flatten-coverage or AOT-builtin gap. Separate issue;
not addressed by the A4 fix.
