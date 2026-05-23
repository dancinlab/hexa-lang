# `@derive_meta` vs real `@derive` trait emitter — surface honesty + Path B sketch

**Filed**: 2026-05-23
**Origin**: PROBE r9 finding #7
**Resolved via**: Path A (this PR) — `fix/derive-meta-surface-honesty`
**Future work**: Path B sketch below (deferred)

## Problem (PROBE r9 evidence)

```hexa
@derive(Display) struct Point { x: int, y: int }
fn main() { let p = Point { x: 1, y: 2 }; println(p) }
```

- `@derive(Display)` parses cleanly via `parse_derive_decl()` (parser.hexa
  L4338) → produces a `DeriveDecl` AST node with `items = [Display]` and
  `name = "Point"`.
- The codegen handler (`codegen.hexa` ~L3270) is literally
  `if k == "DeriveDecl" { return "" }` — a no-op.
- `println(p)` *does* work, but only because the runtime's
  `_hexa_to_string_rec` already walks `TAG_VALSTRUCT` field-by-field. The
  `@derive(Display)` surface contributes ZERO code; it is silently dead.
- No README / SPEC.md / SPEC.yaml line promises `@derive` as a working
  trait-derivation feature — so this is "misleading surface" not "broken
  promise". Still worth fixing because users coming from Rust/Haskell
  reasonably expect derivation.

Accepted trait identifiers (parser side) — any identifier inside the
parens. Real-world callers in this repo use `Display` / `Debug` / `Eq`
(see `example/test_macros.hexa`, `self/test_keyword_audit.hexa`).

## Path A (LANDED in this PR)

Surface the honesty:

1. **Parser**: accept new `@derive_meta(...) for Type` form (same
   `parse_derive_decl()` body, same AST kind). This is the honest name —
   "declarative meta annotation, no codegen".
2. **Parser**: keep `@derive(...)` working for backward compat but emit a
   one-line `println` deprecation hint pointing at `@derive_meta` and at
   this inbox doc.
3. **Codegen**: strengthen the comment block at the `DeriveDecl → ""` site
   so the next reader sees the design intent immediately.

The deprecation hint goes through `println` (not `p_record_error`) so it
does NOT push to `p_errors`, does NOT fail `hexa parse` (which only greps
for the literal `"Parse error"` prefix per `cmd_parse` ~L3821 in
`self/main.hexa`), and does NOT noise tests that pipe to `/dev/null`.

## Path B sketch (deferred — needs >100 LoC across parser + codegen + runtime)

Real trait emission for `@derive(Display) struct S { … }`:

1. **Codegen step 1 — emit per-struct printer**: when codegen sees a
   `StructDecl` followed by a `DeriveDecl` referencing it with
   `Display` ∈ items, emit
   ```c
   static char* S__display(HexaVal self) {
       /* field-walk identical to _hexa_to_string_rec TAG_VALSTRUCT
        * path, but inlined with field names baked in */
   }
   ```
   Mangling: `<TypeName>__<trait_lower>` (e.g. `Point__display`).
2. **Runtime step 1 — tag→fn table**: extend the struct registry
   (currently anonymous-via-fingerprint per `SPEC.yaml::anonymous_auto_id`)
   so each registered tag carries an optional `display_fn` slot.
3. **Codegen step 2 — registration emit**: at module init (alongside the
   existing `_<module>_init`), emit
   `hexa_struct_register_display(TAG_POINT, &Point__display);`
4. **Runtime step 2 — hexa_to_string dispatch**: in `_hexa_to_string_rec`,
   before the generic `TAG_VALSTRUCT` field walk, lookup the tag's
   `display_fn`; if non-null, call it instead.
5. **Repeat for `Debug` / `Clone` / `Eq`**: each with its own slot.
   `Eq` additionally needs `==` operator dispatch (separate runtime hook).

Rough LoC: codegen emitter ~60 + runtime registry extension ~30 +
hexa_to_string dispatch ~10 + tests ~40 = ~140 LoC for Display alone.
Multi-trait (`@derive(Display, Debug, Clone, Eq)`) closer to ~300 LoC.

Trigger for Path B: a real user filing a bug saying "I wrote `@derive
(Debug)` and `println("{:?}", x)` printed garbage" — i.e. a concrete
failure of expectation, not just a cosmetic dead surface.

## Verification (this PR)

- `hexa parse /tmp/probe_derive_pathA.hexa` exercises BOTH `@derive(...)`
  (with deprecation print) AND `@derive_meta(...)` (silent) on the same
  struct — both succeed, both produce a `DeriveDecl` AST node.
- `hexa parse self/parser.hexa` clean.
- `hexa parse self/codegen.hexa` clean.

No runtime tests are added because there is no runtime behavior change —
the AST node still emits `""`. The Path A delta is parser-acceptance +
deprecation channel + honest comments. A future Path B PR would add
runtime tests (struct-print byte-equality vs the generic walk).

## Constraint notes

- Per the dispatching agent's instruction: ZERO `hexa run` in this PR
  (fork-storm guard). Only `hexa parse` was used.
- ZERO other agent spawning.
