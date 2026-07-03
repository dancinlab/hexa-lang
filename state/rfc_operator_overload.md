# RFC — operator overloading (opt-in, default-OFF)

Status: **slice grown** (arithmetic + comparison + index-read wired). Default-OFF
behind `HEXA_OP_OVERLOAD`. Native-backend parity is the gate for any future
default-ON graduation.

## Surface

Declare an ordinary method named after the operator inside an `impl T { … }`
block — **NO new keyword, NO new `@attr`** (the names are plain identifiers the
frozen `151c52c8` parser already accepts, exactly like the many `_`-prefixed
identifiers across `self/`). Under `HEXA_OP_OVERLOAD=1` the C-transpile codegen
(`self/codegen.hexa`) lowers the matching operator to `T__<method>(lhs, rhs)`
when the LHS is a runtime instance of a struct type `T` whose impl declares that
method. Every non-struct operand (int / float / string / array) falls through to
the existing runtime helper unchanged.

Dispatch is **runtime** via the already-shipping `hexa_is_type` substrate symbol
(reuses the P2-6 method-call mechanism) — no static type inference, no
`runtime.c` edit.

## op → method table (reference-matched to Rust)

| operator | method     | reference                                              |
|----------|------------|--------------------------------------------------------|
| `+`      | `__add`    | `std::ops::Add::add`  (library/core/src/ops/arith.rs)  |
| `-`      | `__sub`    | `std::ops::Sub::sub`  (library/core/src/ops/arith.rs)  |
| `*`      | `__mul`    | `std::ops::Mul::mul`  (library/core/src/ops/arith.rs)  |
| `/`      | `__div`    | `std::ops::Div::div`  (library/core/src/ops/arith.rs)  |
| `%`      | `__rem`    | `std::ops::Rem::rem`  (library/core/src/ops/arith.rs)  |
| `==`     | `__eq`     | `std::cmp::PartialEq::eq` (library/core/src/cmp.rs)     |
| `<`      | `__lt`     | `std::cmp::PartialOrd::lt` (library/core/src/cmp.rs)    |
| `a[i]`   | `__index`  | `std::ops::Index::index` (library/core/src/ops/index.rs)|

Receiver = LHS operand, second param = RHS, mirroring Rust's `add(self, rhs)`.
For `__index` the second param is the index expression. LHS-type drives dispatch
(matches the `hexa_is_type(__ovl, …)` check on the left operand inside
`_op_overload_emit`).

## Wired call sites (`self/codegen.hexa`)

- `gen2_expr` BinOp arms — `+` (PR slice), now also `-` / `*` / `/` / `%` (5642-…),
  `==` and `<`. Each inserts the PR's guard block *before* the verbatim
  runtime-helper `return`:
  `if _op_overload_enabled() { let _ov = _op_overload_emit(_op_overload_method(op), l, r, "<fb>"); if _ov != "" { return _ov } }`.
- Index read — the `Index` node is handled outside the BinaryOp block, so the
  dispatch is wired right before the final `return "hexa_index_get(…)"`, calling
  `_op_overload_emit("__index", …, "hexa_index_get")` with the literal method
  name. Placed AFTER every native-array proven-read arm so struct receivers fall
  through (native int/float arrays keep their fast `hexa_arr_i64_box` path).
- `_op_overload_method(op)` extended with `==`→`__eq` and `<`→`__lt`
  (arithmetic entries already present).

## Symbol parity (no code change)

`_op_overload_emit` builds `_t + "__" + method`; for method `__sub`/`__eq`/
`__index` and type `Vec2` this yields `Vec2____sub` / `Vec2____eq` /
`Vec2____index` — exactly what `gen2_impl_block` emits as `type_n + "__" + m.name`.

## byteeq argument (default-OFF → byte-identical)

`_op_overload_enabled()` = `env("HEXA_OP_OVERLOAD") != ""`. With the env var
unset (the DEFAULT for all release / self-host / byteeq builds) every guard is
false, `_op_overload_emit` is never invoked, and each arm falls through to its
ORIGINAL verbatim return string (`hexa_sub(…)`, `hexa_eq(…)`,
`hexa_index_get(…)`, …) — so the generated C is byte-for-byte identical and
`shim.o` plus every emitted object is unchanged on x86_64-linux / arm64-linux /
darwin-arm64. `_op_overload_prescan` is likewise an immediate no-op when the
flag is OFF. The self-host `gen3 ≡ gen4` fixpoint is unaffected: the compiler
source never sets `HEXA_OP_OVERLOAD` and never declares any
`__sub`/`__eq`/`__index` impl methods, so the default-emit byte stream the
fixpoint compares is invariant.

## Test

`self/test_operator_overload_dispatch.hexa` — a `Vec2` with `__add` / `__sub` /
`__mul` / `__eq` / `__lt` / `__index` impl methods; documents expected stdout
under `HEXA_OP_OVERLOAD=1`. The explicit `.method()` call form is kept as the
interpreter-runnable parser/AST anchor.

## Deferred (honest next rounds)

- `!=` / `>` / `<=` / `>=` (ordered-cmp completion — `!=` could derive from
  `__eq`, ordered ops from `__lt`, or take their own `__ne`/`__gt`/`__le`/`__ge`).
- compound-assign (`+=`, `-=`, …).
- Index *write* (`a[i] = v` → `IndexMut`/`__index_set`).
- **native-backend parity** — the slice wires the C-transpile codegen only; the
  native backend (`compiler/codegen/x86_64_linux.hexa`) must reach the same
  dispatch before any default-ON graduation can be considered.

## Verification gate (mini = git/gh only)

DEFAULT 3-target byteeq + selfhost-byteeq + faithful-nobaseline + shipping smoke
on aiden / summer / github-hosted PR-CI before any merge. Keep default-OFF.
