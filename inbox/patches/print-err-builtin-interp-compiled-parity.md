# incoming patch: print-err-builtin-interp-compiled-parity — `print_err` is an interpreter builtin but undeclared in compiled C codegen

> **VERIFIED-CLOSED 2026-05-20** — `self/codegen_c2.hexa` L1535 enumerates `print_err` in the void-builtin set alongside `eprintln`. Close-only marker.

> **id**: `print-err-builtin-interp-compiled-parity` · **opened**: 2026-05-18 KST · **status**: `resolved-ssot 2026-05-19 — codegen_c2.hexa print_err=eprintln-alias landed (resolution (a)); parse-gate clean; binary promote = standard separate deploy step per the 22c27a05 pattern`
> **trees**: `self/env.hexa` (builtin list — `print_err` registered) · compiled codegen path (`hexa build` → C emission — does NOT declare/emit `print_err`)
> **source**: downstream `wisp` (`~/core/wisp`, new dancinlab consumer — WebKit shell + hexa-native core). `hexa build core/main.hexa -o wisp-core` on Mac Darwin-arm64.
> **observed**: 2026-05-18 · hexa-lang pin at build: `2abe76c4e307e49b1b5ad58b6bc5c0a79ae01904`
> **severity**: low — single-symbol parity gap; clean `println` workaround exists. Flagging because it is exactly the interp-vs-compiled divergence class the project GOAL warns about (compiled path is SSOT), and a downstream silently relying on `print_err` would only discover this at `hexa build` time, not `hexa parse`.

---

## 1. Failure (verbatim, from `wisp-core` build on Mac)

```
build/artifacts/wisp-core.c:132:20: error: use of undeclared identifier 'print_err'
  132 |         hexa_call1(print_err, hexa_add(__hexa_sl_12, sockpath));
      |                    ^~~~~~~~~
build/artifacts/wisp-core.c:141:20: error: use of undeclared identifier 'print_err'
error: clang compile failed — binary not produced
```

## 2. Why it is surprising

- `print_err` IS in the `self/env.hexa` builtin name list (alongside
  `print`, `println`, `print_err`, ...), so `hexa parse` accepts it
  and the symbol reads as a first-class builtin.
- The interpreter resolves `print_err` fine.
- The compiled path (`hexa build` → C) never declares/emits a
  `print_err` shim, so clang fails at the C stage only.

Net: a symbol that parses clean and runs under the (deprecated)
interpreter hard-fails the compiled path — the SSOT path per
`@D g_interp_deprecated`.

## 3. Suggested resolution (upstream's call)

Either:
- **(a)** emit a `print_err` C shim in the compiled codegen
  (stderr-writing analogue of `println`), making the builtin list
  honest for the SSOT path; or
- **(b)** remove `print_err` from the `self/env.hexa` builtin list
  if it is interp-only by design, so `hexa parse` / strict-lint
  rejects it early instead of failing at clang.

(a) is preferred — stderr separation is a reasonable builtin and
downstream tools will want it. Tracking either way so the
interp/compiled builtin sets converge (GOAL ② direction).

## 4. Downstream workaround in place

`wisp` replaced both `print_err(...)` calls with
`println("... ERROR ...")`. No upstream change required for wisp to
proceed; this note is the parity-gap handoff, not a blocker.

## 5. Resolution — 2026-05-19 (resolution (a), SSOT landed)

Resolution **(a)** taken. `print_err` is an *exact alias* of `eprintln`
in the interpreter (`self/hexa_full.hexa`: `print_err` →
`eprintln(concat args)`), so the compiled path is made to share the
**existing, production** `eprintln` emission branch rather than adding
a new C shim — zero runtime.c / runtime.h change, zero new behavior to
verify (it reuses `hexa_eprint_val` + `fprintf(stderr,"\n")`, already
compiled and shipping for `eprintln`).

Three surgical edits in `self/codegen_c2.hexa` (the C-emitter SSOT):

1. **variadic emission** (`gen2_expr` Call) — `if name == "eprintln"`
   → `if name == "eprintln" || name == "print_err"`. `print_err` now
   emits the identical chained-`hexa_eprint_val` + trailing-`\n`
   stderr form as `eprintln`.
2. **tail-return void-builtin skip-list** — added `print_err` so
   `return print_err(...)` emits as a statement (it returns void,
   like `eprintln`).
3. **`_is_builtin_name()`** — added `print_err` → `true` so it is
   resolved at codegen, never captured as a free identifier.

**Verified**: `hexa_real parse self/codegen_c2.hexa` → parses cleanly
(local OOM-free edit-gate). Correct **by construction** — `print_err`
routes to the byte-identical `eprintln` branch, and `eprintln` is a
known-good production compiled builtin (2026-04-20 FIX). Byte-parity
with the interpreter alias is structural, not coincidental.

**Promote**: this is the codegen *SSOT* fix. Per the established
project pattern (commit `22c27a05` — "codegen_c2.hexa fixes were
committed but could not reach the running transpiler" because
`hexa cc --regen` is preview-only), the running-`hexa_v2` promote is
a deliberate **separate deploy step**, not part of this SSOT commit.
Until that deploy, `hexa build` consumers still hit the old binary;
the `println` workaround in §4 remains valid in the interim. GOAL ②
interp/compiled builtin-set convergence: this gap **closed at the
SSOT**, promote-pending at the binary.
