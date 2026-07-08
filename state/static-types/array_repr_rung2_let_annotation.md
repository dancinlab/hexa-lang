# array-repr Rung 2 — LET-arm array-annotation lowering

**Status:** implemented, PR-CI-gated (byteeq-neutral + release-integrity census clean).
**Prereq:** Rung 0+1 = #4737 (helper `_types_t_array` + 4 monomorphic builtin array returns:
`split`/`lines`/`chars`→`[string]`, `bytes`→`[i64]`). This rung completes the **LET side**.

## The gap (before)

The LET-arm at `compiler/check/types.hexa` (the `else if _types_is_ident || _types_is_call ||
_types_is_index || _types_is_field` arm) lowered a `let xs: [string]` annotation via
`TypeRef{kind:"named", name:"Array:string"}` → `_types_lower_type_ref` named-branch → the
non-scalar `named:Array:string` **SENTINEL**. Gate ① (`_types_kind_is_scalar(declared.kind)`)
then skipped it, so array-typed LET annotations were **never type-checked**.

## The fix

**(a) Lower `[<elem>]` LET annotations to `kind:"array"`.** Parse the element out of the
`Array:<elem>` typename with `_types_array_elem_kind`; if it is a KNOWN scalar
(`_types_kind_is_scalar`), build a synthetic `TypeRef{kind:"generic", name:"Array",
args:[TypeRef{kind:"named", name:<elem>}]}` and route it through the existing generic array
form in `_types_lower_type_ref` (`tr.kind=="generic" && _types_is_array_name(...) &&
len(args)>=1`). That mints `declared = Type{kind:"array", args:[<canonical elem>]}` where the
element uses the SAME canonical constructors (`_types_t_string()`/`_types_t_i64()` via the
`named` branch) that the Rung 0+1 builtin returns mint — so element Types are **byte-identical**
and `_types_equal` accepts an exact match.

**(b) Loosen gate ①.** Keep the scalar arm; add `else if declared.kind == "array" &&
len(declared.args) >= 1`. In that arm, re-infer the RHS into a scratch sink and only run
`_types_assignable` when the inferred RHS is itself `kind:"array"` (a non-array / unknown RHS
stays conservatively silent).

**`_types_assignable` is UNTOUCHED** — Rung 0+1 proved the method-call element-coercion widening
both WRONG (a `Call` node's children are `[callee, args…]`, not elements) and UNNECESSARY
(`_types_equal`'s `args[0]` recursion already accepts an exact-element array/array match
independent of `src.kind`). The reject side works because a method-call src is not an `ArrayLit`,
so the `_types_is_array_lit(src.kind)`-gated element-coercion arm never fires → `_types_equal`
false → HX3011.

## Behaviour

| binding | declared | actual (RHS infer) | verdict |
|---|---|---|---|
| `let xs:[string] = s.split(",")` | array[string] | array[string] | 0 (equal) |
| `let ys:[i64] = s.bytes()` | array[i64] | array[i64] | 0 (equal) |
| `let bad:[i64] = s.split(",")` | array[i64] | array[string] | 1 HX3011 |
| `let lit:[string] = ["a","b"]` | array[string] | (ArrayLit — arm not entered) | 0 (unchecked) |
| `let mism:[string] = [1,2]` | array[string] | (ArrayLit — arm not entered) | 0 (no-regress) |

## Release-integrity census (live LET check path)

`git grep 'let x:[T] = <RHS>'` across compiler/stdlib/self. Only canonical spellings
(`i8..i64`, `f16..f64`, `bool`, `string`, `char`) promote — abbreviated `str`/`int`/`float`/`any`
are NOT in `_types_kind_is_scalar`, so they stay on the sentinel path (skip). Canonical-spelling
non-ArrayLit RHS sites = **5**: 1 comment (`types.hexa:2571` doc-string), 4 xeno dispatch
`let extras:[string] = if len(a)>4 {…} else {[]}` whose RHS is an **If-expr** (not
ident/call/index/field → arm not entered). Method-fed canonical array LETs
(`= .split/.lines/.bytes/.chars()`) = **0**. **False-reject = 0** — this enables a new-but-empty
surface.

## byteeq / gate

Types erase at MIR → `.text` byte-identical → byteeq-neutral by construction. But this is a
LIVE check path whose correctness depends on canonical-constructor minting, so the authoritative
gate is **PR-CI faithful ×3 + byteeq-real 3-target GREEN** (same class as Rung 0+1), not
gates-summary alone.

## Tests

`compiler/check/types_test.hexa` cases (cj)–(cn), each a self-contained module
(types-test-hexa-1: no union into the main reset). Builders: `_build_case_let_split_string_ok`,
`_build_case_let_bytes_i64_ok`, `_build_case_let_split_i64_bad`,
`_build_case_let_arraylit_string_ok`, `_build_case_let_arraylit_mismatch`.
