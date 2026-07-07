# HX3043 — Rust E0593 closure-arg-count (IIFE subset) · static-types R6 · lane B

**Status:** IMPLEMENTED → pool-verified → PR (byteeq-real GREEN gate by orchestrator).
**Branch:** `feat/types-e0593-hx3043-closure-iife-arity` (off `origin/main` @ `bdd81399f`).

## What & why

Rust **E0593** = "closure is expected to take N argument(s)". Implemented for the
**IIFE subset only** — an immediately-invoked closure **literal**:

```
(fn(p0..p_{n-1}){ body })(a0..a_{m-1})
```

The callee expression **IS** a closure literal, so the parameter count lives on
the closure node (`children` minus the trailing body block) and the argument
count lives on the enclosing call — **both syntactically present**. No closure
typing / inference / dataflow is needed. This is the **last low-cost REJECT
rung**: a falsify-measurement workflow confirmed it is the ONLY shippable
candidate of the 4 remaining rustc-diag candidates.

### Supersedes the prior "BLOCKED" verdict
The convergence ledger (WALL-A-STATIC-TYPES-REJECT-LADDER) listed
`(a) E0593 = BLOCKED (closures untyped · codegen emits HX1104)`. That verdict
is **stale**: closures now codegen and run (empirically `(fn(a){a})(1,2)`
builds + runs on the shipping binary). The IIFE syntactic subset needs **no**
closure typing — arity is read directly off the literal — and S3 type-check
runs **before** any lowering/codegen, so HX3043 fires regardless. Out of scope
(future rounds, genuinely need new axes): `let f = fn(..)` bound-closure calls,
the fn-type arity path.

## Anchors (verified by symbol, not line number)

| symbol | file | role |
|---|---|---|
| `_types_check_call` | compiler/check/types.hexa | wire site (arg-walk → **HX3043 branch** → generic fn-arity block) |
| `_types_is_closure` / `ExprKind::Closure` | compiler/check/types.hexa:819 | closure-kind probe (used on the SYNTACTIC callee) |
| RFC-C1 closure inference | compiler/check/types.hexa (`_infer_expr` closure arm) | returns `fn{args:[],ret:[]}` → generic block `expected_count=0` |
| `_lower_closure` / `parse_closure_expr` | parser.hexa:1788 | AST shape: `text`=param count, `children=[param_0..,body]`; params non-variadic/no-default/no-spread → arity EXACT |
| generic fn-arity block | types.hexa `_types_check_call` | `_emit_hx3002`; empty-args ⇒ would mis-fire on IIFE → we RETURN before it |
| `_types_strict_for` / `_types_is_fixture_path` | types.hexa:1976 | FLIP-3 band: real=Error, `*_test.hexa`+`compiler/test/`=Warning |
| HX3002 emitter (clone target) | types.hexa `_emit_hx3002` | shape for the new `_emit_hx3043` (FLIP-3 polarity like HX3030) |

### Divergence found & handled (NOT a STOP)
The spec predicted the generic block was "inert" for closures. In fact RFC-C1
infers a closure to `fn{args:[]}` (empty), so the generic arity block **would**
fire HX3002 (`expected=0`) on any IIFE-with-args. Handled by making the HX3043
branch **RETURN `_types_t_unit()`** after emitting — the generic block never
reaches a closure callee, so there is no double-fire and no spurious HX3002 on
a *correct* IIFE. (Empirically confirmed: cases av/aw emit exactly `[0] HX3043`,
no HX3002; ax/ay emit 0.)

## Implementation

1. **types.hexa** — `_emit_hx3043(expected, actual, sp, out)` (FLIP-3 band, cloned
   from `_emit_hx3030`) + guarded branch in `_types_check_call` after the
   arg-walk, before the generic fn-arity block:
   ```
   if _types_is_closure(callee.kind) && len(callee.children) >= 1 {
       let clo_arity = len(callee.children) - 1
       if arg_count != clo_arity { _emit_hx3043(clo_arity, arg_count, e.span, out) }
       return _types_t_unit()
   }
   ```
2. **catalog.hexa** — HX3043 DiagSpec complete block (severity Error, stage S3,
   template `this closure takes {expected} argument(s) but {actual} were supplied`,
   `fix_it_kind: FixItKind::None`). Parity **86 → 87** (`DiagSpec {` == `fix_it_kind:`).
3. **types_test.hexa** — `_closure_expr` helper + 5 self-contained cases (labels
   av–az; no union):
   - `(av)` over `(fn(a){0})(1,2)` → 1 HX3043 **Error**
   - `(aw)` under `(fn(a,b){0})(1)` → 1 HX3043 **Error**
   - `(ax)` ok `(fn(a,b){0})(1,2)` → **0** (FP guard)
   - `(ay)` zero `(fn(){0})()` → **0** (FP guard)
   - `(az)` over in a `*_test.hexa` fixture → 1 HX3043 **Warning** (FLIP-3 carve-out)

## Corpus-0 proof (release-integrity — lane B is always-on, NO gate)

Full-tree scan over **all 6413** `git ls-files '*.hexa'`:
- **Syntactic:** zero real IIFE call expressions. Every `})( ` / `|)( ` match is
  (a) my new test-description strings, (b) my catalog `explain` string, or
  (c) string-literal math notation in stdlib quantum files
  (`(|Phi+>_{01}) (x) |0>_2`, `(1/d^n) Tr[...]`). **No actual closure-call.**
- **Build-based:** `<pool result below>` — the modified compiler over the tree
  produces **0** real-source HX3043 firings.

Therefore HX3043 is **adds-only-true-positives** and **byteeq-real neutral**
(there is no IIFE for it to fire on in the shipping tree). If a real firing
ever appeared it would break the always-on build → this rung would be blocked.

## Verification

- Local (`hexa run compiler/check/types_test.hexa`, stale v0.574.1 interpreting
  origin/main source): **PASS: all type-check cases match contract** — all 5 new
  cases GREEN, no double-fire, no regression.
- Pool (aiden, native hexat build): `<filled after pool run>`.

## Frontier note

This is the **last trilogy-pattern rung** — the byteeq-neutral REJECT frontier is
now **EXHAUSTED**. Remaining rustc-diag candidates are prereq-gated:
`unused_variables` (needs a `_`-prefix language-surface convention — corpus
firing is non-zero), `E0308 array-literal homogeneity` (heterogeneous boxed
HexaVal arrays are by-design → corpus-0 impossible), `E0381 place-projection
partial-init` (near-zero value; runtime already aborts on uninit field-read).
Further REJECT expansion = a separate large campaign (closure typing or the
`_`-prefix convention), not a low-cost rung.
