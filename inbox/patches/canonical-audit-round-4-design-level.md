# canonical-deviation audit round 4 — design-level findings batch

**Status:** 🟠 PARTIAL — 2 module-hygiene items SHIPPED (2026-05-23), rest OPEN

**Shipped this round (module-hygiene PR):**
- ✅ **`pub use "…"` / `pub import "…"` re-export** — `ml_parse_import` /
  `ml_parse_import_alias` now accept an optional `pub ` prefix; the
  `ml_collect_imports_with_alias` fast-path admits `p`-leading lines;
  `ml_strip_and_clean` comments out `pub use`/`pub import` directive lines
  (first-line + interior); and `self/main.hexa`'s build-time loader-trigger
  gate now fires on `pub use`/`pub import` (parallel to the `from` gate fix).
  Result: the re-exported inner module is now actually loaded/flattened and
  its pubs are inlined (verified end-to-end: `pub use "lib.hexa"` →
  `greet()` resolves + binary runs). The parser already accepted the syntax
  (`parse_visibility()` consumes `Pub` before the `use`/`import` dispatch).
  **Re-export VISIBILITY follow-up:** hexa's flat namespace already exposes
  the inlined pubs transitively, so a separate selective re-export table is
  NOT yet implemented — `pub use` currently behaves as a plain inline import.
- ✅ **alias collision / duplicate-import DIAGNOSTIC (warn-first)** —
  `ml_warn_import_collisions` scans each parent file's import list and emits
  a stderr WARN on (a) the same non-empty alias bound to two different module
  paths (`use "a" as x; use "b" as x` → Rust E0252) and (b) the same module
  path imported twice. WARN-only by design to protect the self-host build;
  promotion to a hard error is gated on a clean self/* + stdlib audit.

**Deferred (larger surgery, documented):**
- 🟠 **symbol collision silent shadow** (two modules both define `greet`,
  first wins) — needs a cross-module symbol-table dedup pass over the
  flattened output, not a per-line scan. Bigger than this round.
- 🟠 **multiple imports per line** (`use "a"; use "b"` → only first kept) —
  needs the line-based directive parser to split on `;` and loop; touches
  `ml_parse_import` return contract (single path → list). Deferred.

**Original filing below.**

**Status:** 🟠 FILED / OPEN (2026-05-23)
**Reporter:** anima session — hexa canonical-deviation audit, round 4
**Severity:** mixed — none silent miscompiles in the codegen sense
(modulo one soundness bug noted), but each is a divergence from the
canonical model. Surgical-but-not-shipped items batched at tail.

Round 4 fanned out 6 parallel probes — modules/imports · visibility ·
destructuring · struct-impl · numeric-type · async/concurrency.
This round's surgical shipments: **#350** array_shift decl · **#355**
index error messages · **#356** await_unwrap decl · **#357** decl-debt
class. Design-level residue collected here.

## Modules / imports

| name | repro | standard | hexa actual | path |
|---|---|---|---|---|
| non-`pub` leaks to importer | `use "mod"; private_helper()` works | Rust E0603 / Go lowercase invisible | flat namespace, `pub` only an alias prefix marker | module-system symbol-table + diagnostic pass |
| brace-group `"…"::{a,b}` non-restrictive | imports unlisted items too | Rust selective | trailing `::{…}` ignored, full module loaded | extend `ml_parse_import` to filter |
| `from "X" import a, b` non-selective | binds last-loaded sibling | Python filter | walker treats as plain `use` | same surface |
| ✅ `pub use "…"` re-export missing | (SHIPPED) inner module now loaded | Rust `pub use` | `ml_parse_import` + fast-path + stripper + main.hexa gate accept `pub ` prefix | RESOLVED — visibility-table follow-up noted |
| symbol collision silent shadow | two modules define `greet`; first wins | Rust E0252 | flat concat, first wins | DEFERRED — cross-module symbol-table dedup pass |
| ✅ alias collision silent first-wins | (SHIPPED) WARN diagnostic | `use "a" as x; use "b" as x` | Rust E0252 | RESOLVED — `ml_warn_import_collisions` warn-first |
| multiple imports per line | `use "a"; use "b"` | each evaluated | only first kept | DEFERRED — directive `;`-split + list return |
| circular import silent | A↔B no diag | Go cycle error / Rust tolerates | DFS cycle-skip silently | warning policy choice |
| local-scope `use` silent | inside-fn `use` no effect | Rust local `use` works | scan top-level only | (fix-surgical, noted) |
| env-var in path not expanded | `$HEXA_LANG/…` literal | shell convention | not substituted | design — env vs `HEXA_PATH` |
| import-time top-level side-effects | `println` at module top runs on import | Python yes · Rust no | runs | document or gate behind pragma |
| `from "X" import …` loader trigger missed | `from` directive bypasses loader | (any selective form) | gate at `self/main.hexa:2071` only checks `use`/`import` | (fix-surgical: 1-line gate, noted) |

## Visibility — `pub` / private

| name | repro | standard | hexa actual | path |
|---|---|---|---|---|
| `pub` no-op token | swallowed silently, no AST trace | Rust/Swift carry Vis on every decl | `parse_visibility()` return discarded (parser.hexa:680, 1059) | wire `vis` field on FnDecl/StructDecl/EnumDecl/LetStmt |
| `pub struct { pub x: i64 }` parse error | per-field `pub` rejected | Rust per-field | `parse_struct_fields` doesn't call `parse_visibility()` | (fix-surgical, noted) |
| `pub fn` inside `impl` parse error | per-method `pub` rejected | Rust `pub fn` on inherent impl | impl-body parser doesn't absorb `pub` | (fix-surgical, noted) |
| `pub(crate)` / `pub(super)` cascade-crash | `crate`/`super` tokens not Ident | Rust scope-restrict | `parse_visibility()` uses `p_expect_ident()` | (fix-surgical, noted) |
| `static S = 99` undeclared | global never emitted | Rust global static | `static` consumed, no global codegen | separate audit |

## Destructuring

| name | repro | standard | hexa actual | path |
|---|---|---|---|---|
| no tuple type | `(1,2)` prints `[1,2]` | Rust/Swift/Python distinct | coerces to array (lossy) | tuple as distinct value-kind |
| `(1,)` ≠ `(1)` lost | both become same | Rust/Python 1-tuple distinct | same coercion | tied to above |
| `()` unit literal | parse error | Rust/Swift unit | unexpected RParen | define `()` |
| `let (a,b) = (1,2)` parse error | tuple destructure absent | Rust/Swift/Python | parser has zero tuple-pattern branch | (fix-surgical, noted — parse_let LParen branch) |
| `let [a,b]=[10,20]` codegen drop | parser builds DestructLetStmt, codegen runtime-trap | JS/Swift bind | unhandled-stmt-kind trap | (fix-surgical, noted — add DestructLetStmt codegen) |
| `let [head,...tail]` rest pattern | parser builds, codegen drops | JS/Rust rest binds tail | same root | same fix |
| `let Point{x,y} = p` struct pattern parse error | absent | Rust idiomatic | no `Ident LBrace` branch in parse_let | (fix-surgical, noted) |
| `let {x,y}=obj` map-destructure codegen drop | parser builds MapDestructLetStmt, codegen drops | JS canonical | unhandled-stmt-kind trap | (fix-surgical, noted) |
| `fn f((a,b): (int,int))` param destructure | parse error | Rust/Swift | parse_params accepts ident only | param node needs pattern field |
| `for [x,y] in pairs` array destructure | parse error | JS `for (const [x,y] of …)` | parse_for_stmt has LParen but no LBracket | (fix-surgical, noted) |
| `match (1,b) =>` tuple pattern miscompile | clang `undeclared identifier 'b'` | Rust pattern-binds | parser accepts (paren-expr fall-through), `gen2_match_cond` has no Tuple case | (fix-surgical, noted — gen2_match_cond Tuple case) |
| `let _ = 42` binds visible `_` | discard-binder | Rust `_` is discard | binds normal name `_` | unify with match Wildcard |
| unhandled-destr fall-through | runtime trap OR clang undeclared identifier | clean transpile-error | no clear failure mode | (fix-surgical, noted — upgrade `unhandled stmt kind` to hard transpile fail with kind+line) |

## Struct inherent impl (RFC 348 unblocked trait dispatch — these are inherent-impl gaps)

| name | repro | standard | hexa actual | path |
|---|---|---|---|---|
| `Self` ctor literal codegen miss | `Self{x:x,y:y}` → C `Self(x,y)` undeclared | Rust Self = enclosing-impl-type | codegen emits `Self(...)` literally | (fix-surgical, noted — codegen Self-resolve to impl-type) |
| `&self` / `&mut self` parser reject | parse error `expected ident, got BitAnd` | Rust borrow recv | receiver only accepts `self` | (fix-surgical, noted) |
| `fn scale(self, k) { self.x = … }` mutates caller | by-value self mutates outer `p` | Rust by-value `self` no caller mutation · Swift `mutating` opt-in | implicit ref-mut on by-value self | semantics call — pick lane |
| `Point::new(3, 4)` multi-arg parse error | `::`-path call accepts 0/1 arg | Rust N-ary | comma error | (fix-surgical, noted — same shape as enum multi-arg in round 3) |
| `Point::id(7)` single-vs-double-underscore mangling | codegen emits `Point_id`, impl-fn mangled `Point__id` | Rust namespace mangling | mismatched mangle | (fix-surgical, noted — `::`-path mangle to `Type__name`) |
| `Point.id(7)` dot-call dispatch broken | codegen treats `Point` as receiver, passes type-token as self | Swift static via `.` / Rust `::` | no static/instance disambiguation | (fix-surgical, noted — sig-look-up; or design call forbidding dot-call for static) |

## Numeric type narrowing

| name | repro | standard | hexa actual | path |
|---|---|---|---|---|
| 🚨 **fn-param narrow-type soundness UB** | `fn f(x:i32)->i32 { x+1 } f("hi")` → returns non-deterministic ~4-billion int | Rust/Go compile error · Python runtime TypeError | reads pointer/tag as int — **non-deterministic across runs** | **HIGH-PRIORITY** typechecker pass · enforce param type · or drop narrow keywords |
| narrow types decorative | `u8: 300` stored unchanged · `u32: -5` stored | Rust compile error / wrap | annotation accepted, no enforcement | RFC — implement vs drop narrow keywords |
| `5i32` / `5_i32` literal suffix | `5i32` → clang `undeclared identifier 'i32'` | Rust canonical | lexer treats suffix as ident, emits to C | (fix-surgical: lexer reject with HX diag) |
| `0o17` / `0b1010` literals | clang `undeclared identifier 'o17'` | Rust/Go/Python all support | hex `0x` works, octal/binary leak through lexer | (fix-surgical: lexer 0o/0b rules or reject) |
| arbitrary type annotation accepted | `let x: NotARealType = 5` runs | Rust unknown-type error | annotation silently swallowed | (fix-surgical: validate against builtin∪user-declared set) |
| wrong-type init accepted | `let x: i32 = "string"` runs, x is string | Rust/Go type mismatch | annotation ignored at init | (fix-surgical: typecheck init against annotation) |
| array element type ignored | `let mixed: [i32] = [1,"two",3.14]` runs heterogeneous | Rust homogeneous | element type unchecked | (fix-surgical) |
| `to_string(0.0/0.0)` clang void error | overload selects void | should return `"nan"` | resolution miss on 0.0/0.0 | (fix-surgical) |

## Async / concurrency

| name | repro | standard | hexa actual | path |
|---|---|---|---|---|
| ✅ `hexa_await_unwrap` decl missing | (shipped #356) | (defined-but-undeclared class) | (resolved) | — |
| `async fn` returning void type-mismatch | `let r = produce()` (produce returns void) | Rust `Future<Output=()>` | clang param-type mismatch on hexa_call0 | codegen wrap void-return to TAG_VOID |
| `spawn { body }` synchronous + Bus error | mutates outer `let mut` (works); complex bodies SIGBUS | Go goroutine / Rust thread::spawn / Swift Task | codegen emits `{ ... }` C block ("matches interp") | rename `spawn`→`do` OR implement real fork/pthread |
| `spawn` returns no handle | `let h = spawn { ... }` stmt-only | Rust JoinHandle · Swift Task · .NET Task.Run | parse_spawn_stmt is stmt-only | design — JoinHandle or `wait`/`join_all` separate |
| `await` outside `async fn` silent | parser comment "lint deferred" | Rust/Swift/Python compile error | passes parser, breaks at link | (fix-surgical lint, noted) |
| `select { … }` reserved but no parser | lexes to ident `u_select` undeclared | Go `select` full statement | parser.hexa header lists it; no production | implement OR remove from header |
| `atomic let` sham primitive | `.load()` unknown method · `c = c+1` non-atomic | Rust AtomicI64 · Interlocked | parser keyword only; backing `atomic_ops.hexa` unwired | wire surface OR drop keyword |
| Mutex / RwLock / Channel primitives absent | no keyword · no stdlib · no runtime | Rust/Go/Swift | only `stdlib/channel.hexa` via mkfifo+perl IPC | design lock+channel surface |
| `stdlib/channel.send` drops messages without reader | docstring acknowledges | Go blocks · Rust mpsc enqueues | backgrounded `(…)&` writer | make `_sync` default; rename `_async` |
| `self/async_runtime.hexa` 200+ LoC dead | aspirational scheduler unwired | n/a | misleading reader | wire OR delete |

## Surgical fixes batched-but-not-shipped (PR-eligible, this round)

These came up as fix-surgical but were too many to ship as discrete PRs in one session. Each is independently small.

- **modules**: `from "X" import` loader-trigger 1-line gate (`self/main.hexa:2071`) · bare-segment import diagnostic · `pub use`/`pub import` prefix arm · alias collision warning · multiple-imports-per-line error · local-scope `use` error · dotted-path-import better error
- **visibility**: `pub` on struct fields · `pub` on impl methods · `pub(crate)` keyword acceptance in `parse_visibility()` · thread `vis` value into AST nodes (wiring prereq)
- **destructuring**: tuple LParen-pattern in `parse_let` · `DestructLetStmt` / `MapDestructLetStmt` codegen · struct-pattern `Ident LBrace` in `parse_let` · `for [x,y]` LBracket branch · `gen2_match_cond` Tuple case · upgrade unhandled-stmt-kind from runtime trap to transpile fail
- **struct impl**: `Self` ctor codegen · `&self` / `&mut self` receiver parser · `::`-path mangle to `Type__name` (double underscore) · `::`-path multi-arg parser · dot-call sig-lookup
- **numeric**: lexer reject `5i32` / `5_i32` / `0o…` / `0b…` with HX diag · type-name validation in annotation · init-type checking
- **enum** (round 3 carry): multi-arg payload parser comma loop

## Cross-refs

- Round-3 sibling inbox: [#354] (round-3 design batch · `let` immutability · closure mut-capture #347/#349)
- Round-4 surgical PRs shipped: [#350] array_shift decl · [#355] index error msgs · [#356] await_unwrap decl · [#357] decl-debt class
- Audit snapshot: `PROBE.md` · `PROBE.log.md`
