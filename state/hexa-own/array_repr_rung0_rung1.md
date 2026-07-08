# array-repr default-ON — Rung 0 + Rung 1 (builtin array returns)

Branch: `feat/types-array-repr-builtin-returns` (off origin/main @9e514f545)
File: `compiler/check/types.hexa` + `compiler/check/types_test.hexa`

## What landed

The FIRST next-altitude ① rung after the low-cost REJECT/inference frontier
exhausted (post-HX3046). Types the 4 empty monomorphic builtin array returns.

- **Rung 0** (helper, byte-neutral): `fn _types_t_array(elem: Type) -> Type` —
  mirrors the `kind:"array"` struct literal at `_types_lower_type_ref` generic
  branch (@963) EXACTLY. grep `_types_t_array` = 0 before; pure addition → `.text`
  identical.
- **Rung 1** (4 builtin return arms in `_types_builtin_method_ret`, before the
  `_ -> _types_empty_type()` fallthrough), element-repr-EXACT:
  - `split -> _types_t_array(_types_t_string())`
  - `lines -> _types_t_array(_types_t_string())`
  - `bytes -> _types_t_array(_types_t_i64())`  — hexa has no u8 → boxed i64
    (runtime_emit hexa_int)
  - `chars -> _types_t_array(_types_t_string())`  — NOT `[char]`: codegen.hexa:6989
    `hexa_str_chars` returns single-codepoint STRINGS; a `[char]` element would
    false-reject a valid `[string]` chars() sink.

## FP=0 mechanism

Elements are minted with the canonical `_types_t_string()` / `_types_t_i64()` —
the SAME `_prim` constructors the annotation lowering (@926 / @919) uses. So a
builtin-minted element is byte-identical to the `[T]` annotation's element →
`_types_equal` (@2345 recurses `args[0]` independent of `src.kind`) accepts the
exact-element return sink at `_types_assignable`:2546. A genuine element
mismatch (`-> [i64] { return s.split() }`) still REJECTs HX3004.

`_types_assignable` (@2545) is **UNTOUCHED** — the design proved widening the
@2549 arm is WRONG (a Call's `src.children` are `[callee, args…]`, not elements)
and UNNECESSARY (`_types_equal` already accepts exact-element arrays).

## Corpus census (release-integrity — live-check-path)

- Same-line typed array sinks `let x:[T] = recv.split/lines/bytes/chars()`: **0**.
- Real return sinks (gen/archive rodata excluded): **37**, all `.split`
  (0 chars/bytes/lines return sinks). Every array-typed return fn (`-> [T]`) is
  `-> [string]` / `-> [str]` (str → `_types_t_string()` @926, same repr):
  `list_dir` (intrinsics:289, flatten_intrinsic_shims:20 — both pub), firmware
  `_split_pipe -> [str]`, hexa_repl / migrate_fn_attr / stdlib_cli / numerics_sim.
- **Mismatch sites** (`-> [i32]/[f64]/[char]/[bool]` fn returning split/chars/
  bytes/lines): **0**. No legitimate new HX3004 → no shipping-tree break.

## Scope

Arms the always-on no-scalar-gate RETURN arm (@3158) only. The typed-LET
initializer path (array-typed `let`) is scalar-gated and stays untouched →
**Rung 2 (LET-arm) is the follow-up** (`Array:<elem>` annotation kind:"array"
lowering + gate ① loosen).

## Gate

byteeq-real 3-target + selfhost/faithful (github-hosted cloud) GREEN required
BEFORE merge — a false HX3004 on `list_dir` (pub stdlib) would break the
selfhost/faithful jobs. NOT gates-summary-alone.

## types_test (ce–ci)

- (ce) split→[string] ACCEPT → 0 HX3004
- (cf) bytes→[i64] ACCEPT → 0 HX3004
- (cg) chars→[string] ACCEPT → 0 HX3004
- (ch) split→[i64] MISMATCH → 1 HX3004 (array[i64] vs array[string])
- (ci) chars→[char] MISMATCH → 1 HX3004 (proves chars=[string], not [char])
