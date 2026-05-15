# Struct constructor: function-reference field arg not auto-wrapped to `HexaVal`

**Filed by:** wilson. ROI audit 2026-05-14 (f2 forbidden pattern in `dancinlab/wilson` AGENTS.tape — closure-as-struct-method workaround). Verified 2026-05-14 with reproducer below.

**Date:** 2026-05-14.
**Status (2026-05-15):** ✅ **FULLY LANDED**

Two halves of the fix:

1. **Constructor auto-wrap** (`codegen_c2.hexa` StructInit arm, line 3224 area) — passing a bare fn-ref to a field of type `any` correctly wraps as `hexa_fn_new((void*)<mangled>, 0)`. Verified: `type_of(d.handler) == "fn"` post-construct.

2. **Parser arm** (`parser.hexa` `parse_type_annotation`, line 1749) — accepts `handler: fn(T1, T2) -> Tret` as a field type. Multiple struct fields with various sigs (incl. `fn()`, `fn(string,int)->bool`, nested `fn(fn(int)->int,int)->int`) all parse to `type_of == "fn"` at runtime.

### Diagnostic notes on the parser arm

The first attempt (recursive `parse_type_annotation()` calls for every param type) caused an OOM in the regenerated `hexa_v2` — the binary was killed by `HEXA_MEM_CAP_MB=4096` on EVERY input including trivial `fn main() {}`, despite the `hexa cc --regen` clang-compile smoke test passing. Binary search via two intermediate versions identified the failure mode:

| variant | param parsing | return parsing | result |
|---------|---------------|----------------|--------|
| v1 (first attempt) | `parse_type_annotation()` recursive + while-Comma loop | `parse_type_annotation()` recursive | **OOM on every input** |
| v2 (minimal) | LParen/RParen paren-depth skip, no recursion | single Ident consume only | trivial OK, `[string]` return fails |
| v3 (final, landed) | paren-depth skip, no recursion | single `parse_type_annotation()` call | all cases pass ✓ |

Root cause of the v1 OOM is **multi-recursion into `parse_type_annotation` from within itself**: even though each `parse_type_annotation` call should terminate on input, having the recursive call AND the while-Comma loop inside the same arm somehow blew up the regenerated hexa_v2 at runtime on inputs that don't even exercise the new arm. Self-host transpile pipeline does something subtle with that call shape — not yet diagnosed. The v3 form (single recursion site for return type, paren-counting for params) sidesteps the issue and handles arbitrary param/return complexity.

**Severity:** ergonomic + cost-routing. Forces plugin authors to use string-keyed if-chain dispatchers (see `core/dispatch_table.hexa` 28-arm cascade). Cumulative wilson cost: 5-15% turn latency at scale (per ROI a3).

## Reproducer (compiled mode)

```hexa
struct Dispatcher { handler: any, name: string }

fn echo_handler(s: string) -> string { return "echo:" + s }

fn main() {
    let d = Dispatcher { handler: echo_handler, name: "x" }
    let r = d.handler("hi")
    println("result=" + str(r))
}
```

```
$ hexa build /tmp/test_closure_field.hexa -o ./test
build/artifacts/test.c:35:28: error: passing 'HexaVal (HexaVal)' (aka
  'struct HexaVal_ (struct HexaVal_)') to parameter of incompatible type
  'HexaVal' (aka 'struct HexaVal_')
```

Codegen emits the constructor call as `Dispatcher(echo_handler, hexa_str("x"))`. The `echo_handler` identifier resolves to the C function symbol (`HexaVal (HexaVal)`), not a `HexaVal` value. The constructor expects `HexaVal handler`, so clang rejects.

## Also broken: explicit `fn(...)` field type

```hexa
struct Dispatcher { handler: fn(string) -> string, name: string }
```

```
Parse error at 1:30: expected identifier, got Fn ('fn')
```

The parser doesn't accept `fn(...)` as a struct field type at all — must use `any`.

## Fix options

**A. Constructor wraps fn-ref args.** In codegen, when a struct field is typed `any` (or `fn`) and the supplied arg resolves to a known fn-global, wrap as `hexa_fn_new((void*)&handler, arity)`. There's precedent at `codegen_c2.hexa:4561-4563`:
```hexa
if type_of(_ca) != "string" && _ca.kind == "Ident" && _is_known_fn_global(_ca.name) {
    cargs.push("hexa_fn_new((void*)" + _hexa_mangle_ident(_ca.name) + ", 0)")
}
```
That wraps for general calls but doesn't extend to struct constructor args. Mirror the same wrap in `gen2_struct_constructor` (or wherever struct args are gen'd).

**B. Allow `fn(...) -> ...` as field type.** Parser fix: accept the `fn` keyword in struct-field type position. Then route to the same `HexaVal` storage with a typed-getter that auto-unwraps for call-form `obj.handler(arg)`.

**C. Implement `obj.handler(arg)` as method-call dispatch.** Codegen recognizes `obj.field(args)` and if `field` is known to be a fn-typed field, emits `hexa_call1(obj.handler, arg)` instead of trying to call the field directly. This is the "make it just work" option.

Wilson preference: **A** is the minimum viable; **C** is the right long-term fix because plugin authors think of struct-field-fns as methods.

## Downstream effect on wilson

`core/dispatch_table.hexa:63-90` — 28-arm string-comparison if-chain that wouldn't be needed if `host.dispatchers[plugin_id].on(event)` worked. Every `host_plugin_call` pays the linear scan.

## Test that should pass after fix

```hexa
struct Dispatcher { handler: any }
fn h(s: string) -> string { return "wrapped:" + s }

let d = Dispatcher { handler: h }
assert(d.handler("x") == "wrapped:x")    // method-call dispatch
```

## Related

- AGENTS.tape (wilson) f2 — confirmed active 2026-05-14.
- ROI audit a3 — string-keyed dispatch table; gated on this.
- `~/core/wilson/core/dispatch_table.hexa` — generated workaround.
