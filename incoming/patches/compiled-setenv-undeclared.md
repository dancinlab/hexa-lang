# `setenv` builtin: works in interpreter, undeclared in compiled C path

**Reported-by:** wilson (downstream) · 2026-05-16
**Severity:** blocking (any compiled program calling `setenv` fails to link)

## Symptom

`hexa build` of a program that calls the `setenv` builtin emits a C call to
`hexa_setenv(...)` that clang rejects:

```
build/artifacts/<prog>.c:NNNNN:27: error: call to undeclared function 'hexa_setenv';
    ISO C99 and later do not support implicit function declarations [-Wimplicit-function-declaration]
        HexaVal _se = hexa_setenv(__hexa_sl_2412, __hexa_sl_3721);
build/artifacts/<prog>.c:NNNNN:21: error: initializing 'HexaVal' (aka 'struct HexaVal_')
    with an expression of incompatible type 'int'
error: clang compile failed — binary not produced
```

The implicit declaration makes clang assume `int hexa_setenv()`, hence the
second (incompatible-type) error when assigning to `HexaVal`.

## Why it's a real gap (not user error)

- `setenv` is registered as a builtin: `self/ai_native_pass.hexa` returns true
  for `nm == "setenv"` in the builtin-name checks (≈ lines 6539 / 6859 / 20105),
  and the builtin comment list (≈ line 6519) includes
  `setenv/now/time/random/.../exec/spawn/exit/abort`.
- The runtime **does** define it, non-static:
  `self/runtime.c:10474  HexaVal hexa_setenv(HexaVal name, HexaVal value)`
  plus a wrapper `self/runtime.c:11771  static HexaVal _w_setenv(...)`.
- It works fine under the **interpreter** (`hexa run`) — wilson's plugin tests
  (`plugins/governance/test_governance.hexa`, `plugins/inbox/test_inbox.hexa`)
  call `setenv(...)` and pass via `wilson test`.
- It only breaks on the **compiled** path: codegen emits `hexa_setenv(...)` but
  the prototype is not visible in the generated artifact's include/declaration
  set (other builtins like `getenv` resolve fine — so the codegen→runtime
  declaration wiring exists for those but is missing for `setenv`).

## Likely fix locus

The C declaration for `hexa_setenv` isn't reaching generated code. Compare with
a working env builtin (`getenv` / `hexa_env`): wherever its prototype is emitted
into the generated C (runtime header bundled by `tool/flatten_imports` /
`cmd_build`, or the codegen builtin→C-symbol prototype table), add the matching
`HexaVal hexa_setenv(HexaVal, HexaVal);` declaration. I.e. register `setenv`
in the same prototype/extern set the compiled path uses for the other env/proc
builtins, so codegen's `hexa_setenv` call sees a declaration.

## Repro

Minimal:

```hexa
fn main() { let _ = setenv("X", "1") ; println(env("X")) }
```

`hexa run repro.hexa` → prints `1` (OK).
`hexa build repro.hexa -o /tmp/repro` → clang `undeclared function 'hexa_setenv'`.

## Downstream workaround (already applied in wilson)

wilson's `--uncensored` flag avoided `setenv` entirely: it folds the value into
`host.config_map` (`cfg["subagent_endpoint"]`) and the consumer reads it via
`host_config(host, ...)`. No env mutation needed. So this is **not blocking
wilson** anymore — filing for the toolchain so a future `setenv` user (or a
reverted workaround) compiles. Not fixing from wilson (downstream).
