# RFC — Drop trait / RAII (opt-in `HEXA_DROP_RAII`)

SSOT for the opt-in Drop/RAII codegen slice. All behavior is gated behind the
`HEXA_DROP_RAII` env var (default-OFF): on the default build, all 3 byteeq
targets (x86_64-linux · arm64-linux · darwin-arm64), and the gen3≡gen4
self-host fixpoint, the env var is never set, so every new code path is
unreachable and the emitted C is byte-for-byte identical to the pre-slice
compiler. polarity-canonical: the flag ENABLES a capability (it is not a
`HEXA_NO_*` that hides native behavior).

reference-match: **The Rust Reference §Destructors** · **cppreference "RAII"** ·
Rust `core::mem::drop`.

## Rules extracted from the reference (Rust Drop)

- **R1** — values are dropped at the end of their enclosing scope in **reverse
  declaration order** (LIFO).
- **R2** — `Drop::drop` is called automatically; a manual call is forbidden in
  Rust (`mem::drop(x)` is the explicit move-and-drop). hexa maps the explicit
  point to the existing `drop x` keyword (slice ①).
- **R3** — a value is dropped **exactly once** (move tracking prevents
  double-drop). hexa does **not** enforce R3 yet (no move/liveness analysis) —
  documented wall (see below).
- **R4** — drop also runs on panic/unwind. hexa's defer-flag scaffold gives the
  same activation semantics (a defer that was never reached stays inactive).
- **R5** — a struct's own `Drop` runs before its fields' drops. hexa drops the
  struct value as a whole (no recursive field-drop) — coarser, documented.

## Slice ① — explicit `drop x` (PR #4065)

The EXISTING `drop x` keyword (no parser change — frozen blob `151c52c8`
untouched) lowers, under the gate, to a **runtime type-dispatched**
`Type__drop(x)` call when some `impl` block defines a method named
`drop(self)` (the Drop convention). Reuses the proven P2-6
`hexa_is_type`+`Type__method` dispatch idiom. This is the explicit-drop
analogue of Rust `core::mem::drop`. Codegen: `self/codegen.hexa` DropStmt
branch (`node.target == ""` path).

## Slice ② — auto scope-exit drop (this RFC's extension)

A `let r = T{…}` binding whose type `T` declares `fn drop(self)` is dropped
**automatically at function exit** in reverse declaration order — no explicit
`drop r` required (R1 + R2). Implementation (all gated):

1. **`_drop_typed_structs`** (module-level, `self/codegen.hexa`) — the set of
   struct type names that declare a `drop` method. Populated ONCE per transpile
   in `codegen_full`, by scanning the (flattened) AST for `ImplBlock` nodes
   whose `methods` contains a method named `drop`. Kept SEPARATE from the
   source-order-sensitive `_method_registry` so the membership test is
   source-order-INDEPENDENT and never perturbs the byteeq-load-bearing registry.
2. **`_gen2_count_defers`** — counts each drop-typed `let r = T{…}` as one defer
   (in addition to `DeferStmt`), so `gen2_fn_decl` pre-declares the matching
   `__defer_N_active` flag at the function top.
3. **LetStmt arm** — for a drop-typed struct binding, allocates a flag id,
   pushes a **synthetic** `DropStmt` node (`name` = the bound var, `target` =
   the static struct type) onto `_gen2_defer_bodies`, and appends
   `__defer_<id>_active = 1;` to the emitted let.
4. **`__fn_exit` LIFO drain** (reused VERBATIM) — walks `_gen2_defer_bodies` in
   reverse registration order, routing each synthetic `DropStmt` back through
   `gen2_stmt`. The DropStmt branch's `node.target != ""` path emits a direct,
   statically-typed `{ HexaVal __dropv = r; T__drop(__dropv); }` (no runtime
   type test, order-independent of `_method_registry`).

### Why byteeq-neutral (default build / 3 targets / fixpoint)

Every new path is guarded by `env("HEXA_DROP_RAII") != ""`. With the var unset:
`_drop_typed_structs` is left empty (population skipped) and read by nobody;
`_gen2_count_defers` skips the new count → identical defer scaffold; the LetStmt
arm appends nothing (`_drop_suffix == ""`) → identical let emission; the
DropStmt branch's `node.target` path is unreachable (no synthetic node ever
registered). Net emit = byte-identical to post-#4065, itself byte-identical to
pre-slice. Pure codegen change — no runtime symbol added (`Type__drop` is
already emitted by the `impl` block via `gen2_impl_block`), so `runtime.c`,
`hxlcl_shim.o`, and the `hexa_cc.c` bootstrap seed are untouched. Same gating
construction proven by #4065, `HEXA_THREADS`, `HEXA_MONOMORPHIZE`,
`HEXA_TYPED_STRUCT`, `HEXA_STACK_ALLOC`. Self-host scripts never export
`HEXA_DROP_RAII`, so gen3≡gen4 is unaffected.

## Walls (documented, not landed)

- **Function-scope, not block-scope (⚠ coarser than Rust).** The synthetic
  defer fires at `__fn_exit`, so a Drop-typed binding declared inside an
  `if`/`while`/`for` block is dropped at function exit, not block exit. True
  block-scope drop needs a per-block defer stack (or a scope-aware drain) keyed
  to the C block — a separate slice.
- **No move / use-after-drop tracking (⚠ R3 not enforced).** An explicit
  `drop r` followed by the auto scope-exit drop of the same binding (or two
  explicit drops) **double-drops** — the user-defined `drop(self)` runs twice.
  Rust forbids this via move analysis; hexa's dynamically-typed gen2 codegen has
  no liveness/move pass. Mitigation guidance: in flag-ON mode, do NOT also write
  an explicit `drop r` for an auto-dropped binding.
- **No recursive field drop (R5 partial).** Only the struct's own `drop(self)`
  runs; fields with their own Drop impls are not auto-dropped.
- These walls ride on the static-generics / local-type-environment +
  monomorphization work; once a typed local + liveness env exists, block-scope
  drop and move tracking become mechanical.

## Verification

mini = git/gh only (local oracle is the stale Jun-1 build; hexat ignores source
edits → no local pass claim). Delegated to Blacksmith / pool CI:

- DEFAULT byteeq 3-target — neutral by construction (gated paths unreachable).
- self-host gen3≡gen4 fixpoint + faithful-nobaseline.
- flag-ON auto-drop dispatch smoke on a build host: `HEXA_DROP_RAII=1`
  compile of `example/test_drop_raii.hexa`, expecting `make_owned(21)` to append
  `"released:21"` to `cleanup_log` at function exit (auto scope-exit drop), and
  the explicit `drop r` + `r2.drop()` paths from slice ① to still record their
  releases. DEFAULT-mode run is green on the shipped compiler (all drops no-op).
