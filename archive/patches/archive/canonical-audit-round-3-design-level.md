# canonical-deviation audit round 3 — design-level findings batch

**Status**: audit-report-archived-2026-05-25 — meta audit report (design-level findings batch). Each item needs separate design RFC; bulk-archive marker.
**Status:** 🟠 FILED / OPEN (2026-05-23)
**Reporter:** anima session — hexa canonical-deviation audit, round 3
**Severity:** mixed — none are silent miscompiles, but each is a place
where hexa diverges from the Rust/Go/Swift/C# canonical model in a way
that requires a design decision (typechecker pass · stdlib addition ·
breaking semantics change) rather than a surgical fix.

Round 3 fanned out 8 parallel probes (Option/Result · string interp ·
unicode · array index · enum · shadowing · range · float). Surgical
fixes shipped as discrete PRs (#350 array_shift decl · #351 .rev alias ·
#352 format! desugar · #353 chr(0) NUL); this patch collects the
**design-level** residue in one place so a maintainer can sequence
the larger semantics work.

## Option / Result / error propagation

| name | repro | standard | hexa | path |
|---|---|---|---|---|
| postfix `?` | `let v = maybe()?` | Rust/Swift early-return | parse error | needs Result ABI + early-return synthesis |
| `?.` optional chaining | `let r = d?.k` | Swift/Kotlin/TS short-circuit | lexer emits `QuestionDot` but parser/codegen missing | wire `QuestionDot` → existing `OptField` AST + codegen handler |
| built-in `Some` / `None` | `let a = Some(5)` | Rust/Swift prelude | undeclared (must hand-roll enum per file) | stdlib prelude policy + Option/Result registry |
| `nil` ident | `let a = nil` | Rust reserved / Swift Option absent | silently coerced to `void` | reserve `nil` keyword OR diagnose unbound ident |
| `null` ident | `let a = null` | JS/Java/TS canonical | undeclared (clang) | alias `null` → `void` OR document/diagnose |
| panic catchability | `try { panic("x") } catch e {}` | Go `recover` / Rust `catch_unwind` | not catchable by either `try`/`catch` OR `recover` | pick channel semantics (Go model recommended) |
| `try`-as-expression | `let x = try { 42 } catch e { 0 }` | Rust/Kotlin/Scala block-expr | parse error (stmt-only) | block-expression value-yielding semantics |
| `finally` clause | `try {} catch {} finally {}` | Java/Python/JS/C# | parse error | adopt `finally` or document `defer`/RAII alternative |

## String interpolation

| name | repro | standard | hexa | path |
|---|---|---|---|---|
| `${name}` JS template | `"hello ${name}"` | JS/Kotlin/Scala | literal retained, no error | lexer split-into-parts + parser concat fold |
| `f"x={x}"` Python | `f"x={x}"` | Python 3.6+ | clang error (drops `f`, parses `f` + string) | lexer prefix branch — error-first, full later |
| `printf` / `sprintf` | `printf("x=%d", x)` | C/Go/Rust `print!` | `u_printf` undeclared | stdlib shim mapping `{}` placeholders, or full `%d`/`%s` parser |
| Swift `\(x)` (silent drop) | `"x=\(x)"` | Swift | drops `\`, keeps `(x)` literal | lexer escape-default-keep should error on unknown escape (fix-surgical · noted for future PR) |

## Unicode / string

| name | repro | standard | hexa | path |
|---|---|---|---|---|
| `.codepoints()` alias | `"안".codepoints()` | Rust naming (current `.chars()` works) | `unknown builtin method` | additive alias |
| `.graphemes()` UAX-29 | `"👨‍👩‍👧".graphemes()` | Rust `unicode-segmentation` / Swift native | missing | stdlib UAX-29 implementation |
| NFC/NFD normalization | `"안" == ⟨decomposed⟩` | Swift `==` canonical eq | byte-eq (Rust-camp) | spec — document Rust-camp choice |
| `rt_str_chars` byte-walks (fallback) | (build-flag specific) | compiled is codepoint | pure-hexa fallback diverges | rewrite `self/rt/string.hexa:32` as codepoint walker (fix-surgical · noted) |

## Array indexing

| name | repro | standard | hexa | path |
|---|---|---|---|---|
| slice negative wrap | `[1,2,3,4,5][-3..-1]` | Python `[3,4]` | `[]` (clamp 0) | adopt Python wrap or document Rust-strict; align `.slice(-n)` and `arr[-a..-b]` |
| `[].pop()` Option | `[].pop()` | Rust `None` / Python IndexError | silent `void` | couples with Option/Result lane above |
| open-range slice | `a[..2]` / `a[1..]` | Python/Rust standard | parse error inside `[]` | parser — emit existing `Slice` node from open-range forms |
| OOB error msg neg-norm | `a[-10]` on `len 3` | mention original `-10` | shows `-7` (post-normalize) | fix-surgical · noted (`runtime_core.c:1996/2021`) |
| string OOB silent `""` | `"hello"[10]` | Python IndexError / Rust panic | `""` silent | fix-surgical · noted (`runtime_core.c:4562`) |
| string index-set wrong msg | `s[0] = "H"` | "strings are immutable" | `container is not an array (tag=3)` | fix-surgical · noted (`runtime_core.c:2017`) |

## enum / sum types

| name | repro | standard | hexa | path |
|---|---|---|---|---|
| `to_string(Color::Red)` tag-leak | | `"Color::Red"` (Rust `Debug`) | `"0"` (numeric tag); `test_compact_enum.hexa` already FAILs 14/43 | runtime tag→name table threaded into `to_string` path |
| non-exhaustive match | `match c { Red->.., Green->.. }` | Rust compile error | silent `void` | typechecker coverage pass (cross-ref [#347]) |
| unknown variant | `Color::Purple` | Rust compile error | clang `undeclared identifier 'Color_Purple'` | typechecker variant-existence check (hexa-level diagnostic) |
| ordering by tag w/o derive | `Color::Red < Color::Blue` | Rust requires `#[derive(PartialOrd)]` | always permitted (int-leak of tag) | spec decision — opaque type vs compact-tag |
| multi-arg payload — surgical | `Shape::Square(3,4)` | (decl LANDED RFC-074 P1) | parse error at construction (only 1 expr) | fix-surgical · noted (`parser.hexa:3173` — comma loop) |

## Shadowing / scope

| name | repro | standard | hexa | path |
|---|---|---|---|---|
| inner-scope `let` leaks | `let x=5; if true { let x=100 }; println(x)` | Rust: `5` (outer restored) | `100` (outer overwritten) | replace `_gen2_collect_lets` flat-hoist with per-block C-block scope; couples with [#347] |
| match-arm `let` leaks | same root | same | same | same |
| bare-block `{ … }` stmt | `{ let x=10; … }` | Rust/Swift/C# new scope | parse error | parser `StmtBlock` production |

## Range types

| name | repro | standard | hexa | path |
|---|---|---|---|---|
| Swift `0...5` inclusive | `for i in 0...5 {}` | Swift | parse error | document `..=` as single canonical inclusive form |
| `.step_by(n)` | `(0..10).step_by(2)` | Rust | `unknown builtin method` | runtime stride helper (sibling to `.rev` aliased in [#351]) |
| `step` keyword form | `for i in 0..10 step 2 {}` | Pascal/Ada-style | lexer never emits `Step` (parser already wired) | fix-surgical · noted (`self/lexer.hexa` keyword table) |
| `r.start` / `r.end` | `let r = 2..7; r.start` | Rust | `void` (range materializes to array, loses bounds metadata) | Range repr — keep bounds or specialize field-access on Range literal |

## Float / IEEE 754

| name | repro | standard | hexa | path |
|---|---|---|---|---|
| `-1.0/0.0` throws | | IEEE: `-inf` | `division by zero` throw | extend FloatLit fold to `UnaryMinus(FloatLit)` OR remove float-zero throw in `hexa_div` |
| mixed int/float div-zero throws | `let a=1; let b=0.0; a/b` | IEEE: `inf` | throw | same site |
| `println(0.0)`=`0` vs `to_string(0.0)`=`"0.0"` | | matching repr | inconsistent (`%g` strips `.0` in println) | unify formatters at `runtime_core.c:5222` |
| hex-float literal `0x1.8p+1` | | C99/Rust/Java/Python | undeclared identifier `p` | lexer hex-float rule |
| `inf` / `nan` keyword constants | `let a = inf` | Rust `f64::INFINITY` / Python `float('inf')` | undeclared | stdlib constants (`f64.INF` / `f64.NAN`) |
| `to_string(nan)` / `to_string(inf)` casing | | Rust `"NaN"`/`"inf"` · Python `"nan"`/`"inf"` · JS `"NaN"`/`"Infinity"` · Go `"NaN"`/`"+Inf"` | `"nan"` / `"inf"` (printf `%g`) | spec — recommend Rust pair |
| NaN-in-sort silent reorder | `[3.0, nan, 1.0].sort()` | Rust panic / Go well-defined | silent unchanged | sort comparator policy |

## Surgical fixes still pending (PR-eligible)

These came up as fix-surgical in the round-3 reports but were not shipped
in this round; they are simple enough to ship as discrete PRs whenever
the maintainer wants:

- Swift `"\(x)"` unknown-escape silent-drop (`self/lexer.hexa:359`)
- `f"…"` Python prefix early-error (`self/lexer.hexa:298`)
- enum multi-arg payload parse (`self/parser.hexa:3173-3186`)
- float div-by-zero IEEE compliance (`self/runtime_core.c:6887` / `self/codegen_c2.hexa:3959`)
- println/to_string float format consistency (`self/runtime_core.c:5222`)
- OOB error message original neg index (`self/runtime_core.c:1996/2021`)
- string OOB → throw (`self/runtime_core.c:4562`)
- string index-set message (`self/runtime_core.c:2017`)
- `.step_by(n)` runtime stride + codegen alias
- `step` keyword wiring in lexer (parser/codegen already wired)
- `rt_str_chars` pure-hexa fallback codepoint rewrite (`self/rt/string.hexa:32`)
- `?.` chaining — wire `QuestionDot` lexer emission + add OptField codegen
- `nil` / `null` ident — reserve / alias / diagnose

## Cross-refs

- Sibling inbox patches: `let-immutability-and-match-exhaustiveness-unenforced.md` [#347]
  · `closure-mut-capture-by-value-snapshot.md` [#349]
- This round's fix PRs: #350 (array_shift decl) · #351 (.rev alias) ·
  #352 (format! desugar) · #353 (chr(0) NUL)
- Audit snapshot / log: `PROBE.md` · `PROBE.log.md`
