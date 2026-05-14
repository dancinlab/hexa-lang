# Struct constructor: function-reference field arg not auto-wrapped to `HexaVal`

**Filed by:** wilson. ROI audit 2026-05-14 (f2 forbidden pattern in `dancinlab/wilson` AGENTS.tape — closure-as-struct-method workaround). Verified 2026-05-14 with reproducer below.

**Date:** 2026-05-14.
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
