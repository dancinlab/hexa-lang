# incoming patch: print-err-builtin-interp-compiled-parity — `print_err` is an interpreter builtin but undeclared in compiled C codegen

> **id**: `print-err-builtin-interp-compiled-parity` · **opened**: 2026-05-18 KST · **status**: `reported (downstream worked around with println)`
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
