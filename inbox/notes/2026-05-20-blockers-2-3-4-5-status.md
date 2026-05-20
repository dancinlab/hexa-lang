# Blockers 2/3/4/5 — Track B pilot — status & SSOT fixes

**Reporter**: Track B (solar_kernel pilot, kappa-65)
**Filed**: 2026-05-20
**Companion note**: `2026-05-20-blocker-1-multiline-minus-parser.md`
  (blocker 1 — parser, deferred)

Track B reported 5 blockers from the D80 g_hexa_only solar pilot. This
note tracks the **SSOT-source fixes** landed in this session. Note the
project convention `SSOT; regen deferred` (see commit 58834640) —
`self/codegen_c2.hexa` is the source-of-truth and `self/native/hexa_cc.c`
is a generated artifact updated by `hexa cc --regen` (MVP path). Runtime
changes (`self/runtime.c`, `self/runtime_core.c`) take effect at the
next normal rebuild because `runtime.c` is appended as TU2 at every
build.

## Status summary

| # | Title | Status | SSOT change |
|---|---|---|---|
| 1 | Multi-line `-` parser | OPEN — parser scope deferred | filed (companion note) |
| 2 | No float `%` operator | **SSOT FIXED** (regen deferred) | `self/codegen_c2.hexa` |
| 3 | No `fmod` libm shim | **SSOT FIXED** (regen deferred for codegen routing) | `self/codegen_c2.hexa`, `self/codegen/rt_symbols.hexa`, `self/runtime.c`, `self/runtime_core.c`, `self/runtime.h` |
| 4 | `print` truncates floats | **FIXED + verified** | `self/runtime_core.c` (env opt-in) |
| 5 | `let pi = pi()` shadow | **SSOT FIXED** (regen deferred) | `self/codegen_c2.hexa` |

## Blocker 2 — float `%` codegen

**Root cause**: `self/codegen_c2.hexa` had two BinOp fast-paths that
emitted raw C `%` between doubles:

1. FloatLit + FloatLit constant-fold (line ~3820 pre-fix): emitted
   `hexa_float((7.5) % (2.0))` — clang error
   "invalid operands to binary expression ('double' and 'double')".
2. Known-float + known-float fast-path (line ~3856 pre-fix): emitted
   `hexa_float(HX_FLOAT(l) % HX_FLOAT(r))` — same error.

Note: `hexa_mod` in `self/runtime_core.c:5976` already handles floats
via `fmod(__hx_to_double(a), __hx_to_double(b))` correctly — only the
codegen fast-paths bypassed it.

**Fix**: route `%` through libm `fmod()` directly in both fast-paths.
Constant-fold case: `hexa_float(fmod((lhs), (rhs)))`. Known-float case:
`hexa_float(fmod(HX_FLOAT(l), HX_FLOAT(r)))`. `fmod` is already in
`<math.h>` (included via runtime.h).

**Test added**: `test/t_float_mod_codegen.hexa` — covers FloatLit % FloatLit,
known-float % known-float, negative dividend, and the new `fmod(x, y)`
builtin from blocker 3.

**Acceptance**: SSOT change verified via direct transpile —
`./self/native/hexa_v2 self/codegen_c2.hexa /tmp/_cgv.c` produces
`hexa_str("hexa_float(fmod((")` and `hexa_str("hexa_float(fmod(HX_FLOAT(")`
string literals (lines 2868/2881 of transpiler emit), confirming the
new emit branch. End-to-end test landing requires `hexa cc --regen`.

## Blocker 3 — `fmod` libm shim

Track B reported "fmod missing from `cg_math_sym`". Investigation:

- `hexa_mod` runtime (`%`-operator backend) DOES use `fmod` correctly
  — the Track B-visible symptom was actually blocker 2 (codegen
  bypassing it via fast-path).
- However, calling `fmod(x, y)` *directly* as a builtin from user code
  was indeed missing. `cg_math_sym` had `sqrt/pow/floor/...` but no
  `fmod` entry, so `fmod(a, b)` fell through to `hexa_call2(fmod, …)`
  which linked to libm's `double fmod(double, double)` — argument-type
  mismatch with HexaVal.

**Fix**: add `fmod` to both `cg_math_sym` (codegen_c2.hexa) and
`rt_math_symbol` / `legacy_math_symbol` (codegen/rt_symbols.hexa).
Add `hexa_math_fmod(HexaVal, HexaVal)` runtime impl in `runtime.c`
(mirrors `hexa_math_pow`'s shape — unwrap → libm → wrap) and the
forward decl in `runtime_core.c` + `runtime.h`.

**Acceptance**: runtime piece compiles clean (`clang -c runtime.c` OK).
Codegen routing landed in SSOT, regen-deferred.

## Blocker 4 — `print` precision

**Root cause**: every float print/println/eprint/eprintln path in
`runtime_core.c` hard-coded `%g` (6 significant digits), so doubles
like `3.141592653589793` printed as `3.14159` — losing 10 sig digits
of precision. Numerical parity tests using `print` output for diffs
were silently lossy.

**Fix**: introduced `__hexa_print_float_fmt()` static helper that
checks `HEXA_FLOAT_REPR` env var at first call (cached). Values:

- unset / unknown → `%g` (existing 6-digit behavior — no regression)
- `g15` → `%.15g` (15 sig digits)
- `g17` → `%.17g` (17 sig digits — IEEE-754 round-trip-safe)

Touched 4 user-facing print entry points (hexa_print_val,
hexa_eprint_val, hexa_eprintln, hexa_eprint). Other `%g` sites in
runtime_core.c (hexa_to_cstring, hexa_to_string, etc.) preserved at 6
digits to avoid regressing every snapshot test that uses the string
representation.

**Acceptance (end-to-end verified)**:

```
$ ./tmp_print_prec    # let x: float = 3.141592653589793; print(x)
3.14159                                # default %g
$ HEXA_FLOAT_REPR=g15 ./tmp_print_prec
3.14159265358979
$ HEXA_FLOAT_REPR=g17 ./tmp_print_prec
3.1415926535897931
```

Runtime change takes effect immediately on next `hexa build` (runtime.c
is rebuilt every time).

## Blocker 5 — `let pi = pi()` self-shadow

**Root cause**: in C, a let-statement's local is in scope inside its
own initializer. Codegen emitted `HexaVal pi = hexa_call0(pi);`. The
`pi` on RHS resolves to the uninitialized local (not to any function
named `pi` — `pi()` doesn't exist as a hexa builtin), so clang silently
accepted the call-through-uninitialized-HexaVal and emitted garbage
(the user's reported `259` is the contents of the uninitialized stack
slot interpreted as a HexaVal int box).

This is two bugs in one — (a) codegen should reject calls to
undefined functions earlier, and (b) the let-init scoping should not
allow the local to be visible in its own RHS. Fix (b) is surgical and
addresses Track B's reported symptom.

**Fix**: in `gen2_stmt` LetStmt branch, detect when the emitted init
text textually references the local name as a C-identifier token. If
so, emit via a temp:

```c
HexaVal __hexa_letinit_pi = hexa_call0(pi);
HexaVal pi = __hexa_letinit_pi;
```

Now the `pi` on the temp-init RHS resolves to the function name (or
errors loudly if none exists — which is the correct behavior — instead
of silently aliasing to the uninitialized local).

Helpers added: `_init_refs_local(init, name)` (textual scan for `name`
as standalone C-ident token in the init string) and `_is_c_ident_char(c)`
(single-char ident-class predicate). Both are codegen-time pure
functions, conservative on false positives.

**Acceptance**: SSOT change verified via direct transpile — the new
string literals `"__hexa_letinit_"` and the `_init_refs_local` /
`_is_c_ident_char` helper bodies appear in `/tmp/_cgv3.c` (transpiled
codegen_c2). End-to-end test landing requires `hexa cc --regen`.

## Why not all end-to-end verified

Three of the four landed fixes touch `self/codegen_c2.hexa` (the
transpiler's SSOT). The transpiler binary `self/native/hexa_v2` is
built from `self/native/hexa_cc.c`, which is a regen artifact of
`self/{lexer,parser,type_checker,codegen_c2}.hexa`. The regen
pipeline (`hexa cc --regen`) is MVP-stage (commit 58834640's "regen
deferred" pattern) and currently produces a `.new` file that doesn't
re-compile cleanly without manual merge. Project convention is to
commit the SSOT change and defer the binary regen to a separate
toolchain-deploy step. Blocker 4 (runtime) is end-to-end verified
because runtime.c is rebuilt at every user-program build.

## Files changed this session

- `self/codegen_c2.hexa` — blockers 2, 3 (codegen routing), 5
- `self/codegen/rt_symbols.hexa` — blocker 3 SSOT mirror
- `self/runtime.c` — blocker 3 runtime impl
- `self/runtime_core.c` — blockers 3 fwd-decl, 4 (print precision)
- `self/runtime.h` — blocker 3 fwd-decl
- `test/t_float_mod_codegen.hexa` — acceptance test (blockers 2, 3)
- `inbox/notes/2026-05-20-blocker-1-multiline-minus-parser.md` — companion
- `inbox/notes/2026-05-20-blockers-2-3-4-5-status.md` — this file
