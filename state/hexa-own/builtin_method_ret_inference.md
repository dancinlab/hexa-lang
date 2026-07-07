# static-types ① lane — builtin-method-call RESULT inference

**① lane next-frontier: builtin-method-call results were the last total inference hole.**
Before this rung, every builtin-method-call result (`s.len()`, `xs.count()`, `s.trim()`, …)
inferred to **unknown** (`_types_empty_type()`) — 100% type-opaque. This was the one remaining
position where the S3 checker learned *nothing*, so the already-shipped REJECT rungs
(HX3011 typed let/assign, HX3003 call-arg, HX3004 return) could never fire on a method-call
result. Typing the receiver-independent monomorphic subset closes that hole.

## What landed
- `compiler/check/types.hexa` — new `_types_builtin_method_ret(name) -> Type` adjacent to
  `_is_builtin_method`, returning the closed-form result Type for the monomorphic subset and
  `_types_empty_type()` (unknown) for everything else.
- Consumed at the builtin-method `Field` callee return site in `_types_check_call`
  (`else if _types_static_on { let r = _types_builtin_method_ret(callee.text); if len(r.kind) > 0 { return r } }`
  before the `return _types_empty_type()`), so the KNOWN scalar now flows into the r1–r12 /
  HX3003 / HX3004 rungs. Gated on `_types_static_on` (the FLIP-3 always-on marker), matching
  every sibling rung.
- `compiler/check/types_test.hexa` — three probes (labels ba/bb/bc):
  - **ba** hz_method_ret_typed: `let n: bool = s.len()` → len→i64 ≠ bool → **1 HX3011**.
  - **bb** fp_method_ret_ok: `let n: i64 = s.len()` → **0 HX3011**.
  - **bc** fp_container_unknown: `let x: i64 = xs.map(f)` → map excluded/unknown → **0 HX3011**.

## byteeq-safety — static-types is FLIP-3 flagless (NOT a default-off env gate)
The original task premise ("gate behind `HEXA_STATIC_TYPES` so the default build stays byte-
identical") was **stale**. As of origin/main the `HEXA_STATIC_TYPES` / `_STRICT` / `_ARRAY_LOWER`
env opt-outs were **removed** (FLIP-3 flagless): static-types checking is **unconditional**,
Rust-style, `_types_static_on` is a module const `true` ("always-on marker"). Byteeq-safety
comes from the established mechanism, the same one all shipped HX3001~3018 + HX3043 rely on:
1. **corpus-clean real source** — no new REJECT fires on shipping `.hexa`;
2. **MIR type-erasure** — S3 diagnostics never reach codegen, so gen3≡gen4 stays byte-identical;
3. **`_types_strict_for` fixture Warning-band** — `*_test.hexa` / `compiler/test/` fixtures with
   deliberately type-unstable inputs stay non-fatal Warnings, never breaking a build.

So typing builtin-method results the same way is **standard, not a new contract**.

## Reference-match — mirrored EXACTLY from `self/codegen.hexa::gen2_method_builtin`
(The authoritative runtime dispatch **moved**: it is `self/codegen.hexa` now, NOT the deleted
`self/codegen_c2.hexa` the code comment still cites.) Each selector's return type was traced
through the runtime emitters (`runtime_emit_full.hexa`, `runtime_core_emit.hexa`,
`zeroc_rt_core_prims_emit.hexa`), not guessed.

| Type | Selectors | gen2 provenance |
|------|-----------|-----------------|
| **i64** | `len`, `count`, `index_of`, `rfind`, `last_index_of`, `char_code_at`, `byte_at`, `to_int` | `hexa_int(...)`-wrapped; `count`→`hexa_count_poly` (all 3 arms `str_count_substr`/`map_count`/`array_count` return `hexa_int`); `char_code_at`/`byte_at`→`hexa_str_char_code_at`/`hexa_str_byte_at` `hexa_int` value path; `to_int`→`rt_to_int` int-on-every-path |
| **f64** | `to_float` | `rt_to_float` → `hexa_float(...)` always |
| **bool** | `is_empty`, `contains`, `starts_with`, `ends_with`, `to_bool` | `hexa_bool(...)`-wrapped; `contains`→`hexa_contains_poly` (both arms `hexa_bool`); `is_empty`→`hexa_is_empty` (all arms `hexa_bool`) |
| **string** | `to_string`, `to_upper`, `to_lower`, `to_uppercase`, `to_lowercase`, `trim`, `trim_start`, `trim_end`, `substring`, `substr`, `replace`, `join`, `repeat`, `pad_left`, `pad_right`, `center` | `hexa_to_string` / `str_*` / `rt_str_*` kernels typed `-> string` |

### Census corrections (task census verified, NOT trusted blindly)
- **`find` EXCLUDED (not i64).** gen2 maps `find`→`hexa_array_find`, which returns the **matched
  element** (`hexa_void()` if none) — polymorphic, NOT an index. The census's `find → i64` was a
  mis-type that would emit WRONG diagnostics.
- **`pad_start`/`pad_end` EXCLUDED (no gen2 arm).** They exist in `_is_builtin_method` but have
  **no `gen2_method_builtin` dispatch arm** (would runtime-error). The real string-pad methods
  are `pad_left`/`pad_right`/`center`. Census listed `pad_start`/`pad_end`/`center`.
- **Excluded (conservative-unknown):** `map`, `filter`, `fold`, `get`, `pop`, `slice`, `sum`,
  `product`, `min`, `max`, `first`, `last`, `keys`, `values`, `entries`, `char_at` (ambiguous
  codepoint-string), `mean`, and all other polymorphic / container / element-returning selectors.
  When unsure → exclude (a mis-typed container/element method = wrong diagnostics).

## Corpus scan = 0 real fires
`_types_assignable` does NOT coerce int-width or int→float for a **non-literal** (call) source
(only int-LITERAL/float-LITERAL sources coerce), so e.g. `let x: i32 = s.len()` or
`let x: f64 = s.len()` *would* newly REJECT (i64≠i32/f64). This makes the corpus scan mandatory.

Grep census across **6413** git-tracked `*.hexa` (excluding `*_test.hexa` / `compiler/test/` /
`embedded.gen.hexa` / `_archive/`):
- typed-let with a builtin-method-call RHS + scalar annotation: **0**
- decl-only typed let (`let x: SCALAR`) — r3 precondition: **0**
- call-arg (method-call result passed to a call): **0**
- returns: only 2 real method-call returns (`.trim()`→string in `md5_of_output`/`vec_count`,
  both with **no declared return type** → HX3004 needs a KNOWN expected type → does not fire);
  all other matches are string-literal / comment false positives.
- assigns: all matches are string-literal concatenations / untyped reassigns (no typed sink).

Authoritative compile-smoke: the modified compiler type-checked a real method-heavy standalone
program (`tool/unshadow_knownint_accum_bench.hexa`) with **0 HX30xx** diagnostics (build reached
the clang stage — a downstream environmental link issue on the pool, unrelated to type-checking).

`hexa run compiler/check/types_test.hexa` → **PASS: all type-check cases match contract.**
(all pre-existing cases + ba/bb/bc). **corpus_scan real-source new-fire count = 0.**

Verified on pool host `aiden` (x86_64-linux, hexa v0.577.0). Full byteeq 3-target runs on PR CI.
