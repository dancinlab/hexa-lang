# RFC — Function Overloading (opt-in `HEXA_FN_OVERLOAD`)

Design SSOT for the opt-in function-overloading slices in `self/codegen.hexa`.
Status: **§1 ARITY LANDED (PR#4066)** · **§2 same-arity TAG-dispatch LANDED**.

## Problem

hexa historically forbids same-name functions: the C-transpile codegen's
first-wins dedup loops keep the first `fn <name>` and drop later definitions
with `[warn] … overloading unsupported, later definition ignored`. There is no
overload resolution. The value model is **dynamic** (every value is a boxed
`HexaVal {tag, payload}`), so there is no static type available at the call
site for C++/Rust-style compile-time resolution.

## Reference (answer keys)

- **C++ (Itanium ABI)** — overload sets disambiguated by mangling the parameter
  signature into the symbol; resolution is fully static.
- **Swift** — arity is the first discriminator, then argument labels/types.
- **Julia** — *multiple dispatch*: methods live in a method table keyed by the
  runtime types of all arguments; the most applicable method is chosen at call
  time. This is the closest match to hexa's dynamic value model and is the
  reference for §2.

## §1 — arity-based mangling (LANDED, PR#4066)

Under `HEXA_FN_OVERLOAD=1`, a top-level fn name declared with **≥2 DISTINCT
arities** is mangled per-arity:

- decl `add(a,b)` → C symbol `add_hxov2`; `add(a,b,c)` → `add_hxov3`.
- a positional call routes to the suffix matching `len(node.args)` (statically
  known — no type inference).
- `_gen2_build_overload_set` collects `name@@arity` pairs; a name with ≥2
  distinct arities is added to `_gen2_overload_names`. `_gen2_overload_name`
  (call), `_gen2_fn_cname` (decl) and `_gen2_dedup_key` (first-wins loops) all
  fall through to `_hexa_mangle_ident` for non-overloaded names.

## §2 — same-arity TYPE(tag)-based runtime dispatch (LANDED)

Extends §1 to **same-name / same-arity** overloads distinguished by parameter
**tag** (Julia-style multiple dispatch on the runtime `HexaVal` tag):

- `_gen2_param_tag_sig(node)` maps each param's type annotation (`node.params[i].value`)
  to a tag-letter (`f`/`i`/`s`/`b`/`a`/`m`, untyped→`x` wildcard), reusing the
  FFI type→tag map (`gen2_ffi_c_type`/`gen2_ffi_marshal_arg`).
- `_gen2_build_overload_set` second pass groups `name@@arity` decls; a key with
  **≥2 DISTINCT sigs** is recorded in the parallel globals
  `_gen2_tagov_keys` / `_gen2_tagov_names` / `_gen2_tagov_arity` /
  `_gen2_tagov_sigs` (distinct sigs in declaration order; sig0 = default), and
  the name is added to `_gen2_overload_names`.
- each member is emitted under a tag-suffixed symbol via `_gen2_fn_cname`
  (`show(x:int)`→`show_hxov1_i`, `show(x:str)`→`show_hxov1_s`);
  `_gen2_dedup_key` folds the sig in so distinct-tag members survive the
  first-wins loops (true same-arity SAME-sig redefinition still collapses).
- `_gen2_emit_overload_dispatchers(fwd_parts, fn_parts)` emits a runtime
  trampoline `show_hxov1(HexaVal a0)` that tests each non-default member's
  annotated params with the frozen `HX_IS_INT`/`HX_IS_FLOAT`/`HX_IS_STR`/…
  inspectors (`self/runtime.h`), `&&`-joined, and forwards to the first match,
  defaulting to the first-declared member. Wired before the four `.join("")`
  sites in `codegen()` and `codegen_full()`.
- the call site is unchanged: `_gen2_overload_name(name, len(args))` already
  returns the arity-only `show_hxov1`, which now resolves to the dispatcher.

## Byteeq safety (both slices)

All overload globals are populated **only after** the `env("HEXA_FN_OVERLOAD")
== ""` early return in `_gen2_build_overload_set`. On the default build (the
flag is exported by **none** of the self-host gen2/3/4 builds or the 3 byteeq
build scripts) every set is empty → `_gen2_is_overloaded` /
`_gen2_is_tag_overloaded` are false, all symbol helpers reduce to the bare
`_hexa_mangle_ident`, `_gen2_dedup_key` returns the bare name, and
`_gen2_emit_overload_dispatchers` pushes nothing before the joins. The byte
stream is therefore character-for-character the pre-slice output → `gen3≡gen4`
fixpoint and all 3 targets (x86_64-linux · arm64-linux · darwin-arm64) stay
byte-identical. The dispatcher emits only string-concatenated C over
already-frozen `runtime.h` macros, so `runtime.a` / `shim.o` are untouched. No
new keyword/builtin/`@attr` (frozen blob `151c52c8` unchanged).

## Limitations / Roadmap

- **Tag granularity (§2)** — discrimination is on the runtime `HexaVal` tag
  (int/float/str/bool/array/map), NOT on declared nominal types. Two overloads
  whose params box to the SAME tag (e.g. two distinct struct types, both
  `TAG_VALSTRUCT`) are indistinguishable and collapse to first-wins. Untyped
  params are wildcards. **Open.**
- **Native `--emit` backend** — §2 dispatch is implemented in the C-transpile
  codegen only; the native (x86_64/arm64) backend needs the same tag-test
  ladder lowered to machine code. **Open.**
- **Default-arg / variadic / fn-ref combinations** — not combined with
  overloading in these slices. **Open.**
- **Resolution precedence** — the dispatcher uses first-declared as the
  fallthrough default and tests members in declaration order (vs Julia's
  most-specific-method ordering). Adequate for disjoint tag sets; ambiguous
  overlapping sets are not diagnosed. **Open.**

## Test oracle

`self/test_fn_overload.hexa` (GATED — flag-ON only, NOT in the default byteeq
corpus): exercises §1 arity (`add/2`, `add/3`) + §2 tag dispatch
(`show(int)`, `show(str)`). Build: `HEXA_FN_OVERLOAD=1 hexa build
self/test_fn_overload.hexa && ./a.out`.
