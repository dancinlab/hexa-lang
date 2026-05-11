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
