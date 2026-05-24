# canonical-deviation audit round 9 — consolidated (4 axes)

> **Status (2026-05-23):** no 🚨 CRITICAL silent-failure this round (r8 `write_file` content-leak was the prior cycle's CRITICAL — fixed by #407, doc-closed by #416). r9 is a **language-surface audit**: module/import · macros/attrs · memory model · generic type bounds. Two FIX-SURGICAL items shipped same cycle (r9-14 where-clause wire #417 · r9-6 MacroCall parse-time fail-loud branch ready, PR pending). Remainder = **design-level** (single-TU monolith intentional, pure-arena v1 intentional, surface-syntax generics intentional, flatten-style modules intentional). Tracked, not silent bugs.

PROBE round 9 결과 (20 probes, 4 axes: module/import · macros/decorators/attributes · memory model · generic type bounds).
FIX-SURGICAL 항목은 별도 PR (#417 + macrocall fail-loud follow-up) — 본 문서는
**design-level** 이탈 클러스터 consolidated 기록.

## TL;DR

| axis | FIX-SURGICAL (이미 ship / 진행) | design-level (본 문서) | CRITICAL |
|---|---|---|---|
| 1. module/import | — | `pub use` re-export · selective `use foo::{a,b}` · wildcard `use foo::*` · `::` fn namespacing · `pub` enforcement | — |
| 2. macros/attrs | `MacroCall` parse-time fail-loud (r9-6, PR pending) | `@derive(Display)` no-op cosmetic (rename or impl) · unknown attribute silent-absorb | — |
| 3. memory model | — | arr/dict alias-by-default (intentional v1) · `move`/`own`/`borrow` no-op · no `&`/`&mut` borrows | — |
| 4. generic bounds | `where T: …` parser wire (r9-14, PR #417) | type-bound erased (no monomorph) · const generics absent · default tparams absent · variance absent | — |

**0 CRITICAL this round.** (Distinct from r8 which had `write_file` stdout content-leak.)

## Axis 1 — Module / import system

| probe | hexa-current | canonical (Rust/Py) | verdict |
|---|---|---|---|
| `use "self/foo"` (flatten path) | ✓ works via module_loader pre-pass | n/a (hexa-specific) | ✅ design-OK |
| `Foo::bar()` fn namespace call | ❌ `::` is enum-variant-only | Rust `mod::fn` / Py `mod.fn` | ⚠ design |
| `pub use foo::bar` (re-export) | ❌ absent | Rust canonical | ❌ design |
| `use foo::{a, b}` (selective) | ❌ absent | Rust canonical | ❌ design |
| `use foo::*` (wildcard) | ❌ absent | Rust canonical | ❌ design |
| `pub fn` visibility enforcement | ⚠ parses, ignored (single-TU monolith) | Rust enforces | ⚠ design |

### 핵심 design 결정

hexa 의 module model = **flatten-style** (`use "self/foo"` = textual concat
into single-TU monolith).  Rust-style `mod` tree + `::` path resolution
+ `pub`/`pub(crate)` enforcement = **multi-TU compile model** 필요 — pivot
가능하나 single-cycle 규모 아님 (parser + resolver + symbol-table + linker
재설계).

**Status quo 권장**: flatten 모델 유지, `pub`/`pub(crate)` 키워드 reserve
+ 문서화 ("parsed but no enforcement, future-reserved").

> **r9-19 VERIFIED-CLOSED 2026-05-23** — `pub(crate)` / `pub(super)` /
> `pub(self)` top-level dispatch was already fixed by **PR #373** (commit
> `858107e4` "widen `pub` parsing — struct fields · impl/trait methods ·
> `pub(crate)`"). `parse_visibility` at `self/parser.hexa:4525` accepts
> the keyword token kinds `Crate` / `Super` / `Self_` / `Mod` via
> `tok.value` alongside `Ident`. Regression test:
> `test/regression/parse_pub_crate_top_level.hexa`. No further surgical
> action — r9-19 dropped from the cycle-5+ list below.

## Axis 2 — Macros / decorators / attributes

| probe | hexa-current | canonical | verdict |
|---|---|---|---|
| `name!(args)` MacroCall invocation | 🔴 codegen crash (dead-on-arrival) | Rust `macro_rules!` / Py decorator expansion | **FIX-SURGICAL** (r9-6, parse-time fail-loud PR pending) |
| `@derive(Display)` on struct | 🟠 emits literal `""` (no-op cosmetic) | Rust `#[derive(Display)]` synthesizes impl | dead feature — design |
| `@unknown_attribute` on item | ⚠ silent absorb (typo-friendly, no warn) | Rust `unknown attribute` error | design |

### 핵심 design 결정

**Macro expander pass 부재** — hexa v1 은 매크로 시스템이 없음.
`MacroCall` AST 노드는 lexer/parser 가 받지만 codegen 단계에서 unhandled →
crash.  Cycle 4 의 r9-6 PR 은 **parse-time fail-loud** 로 신호를 빠르게
주는 가드 (사용자가 매크로 기능을 기대하지 않게).  full expander pass
는 별도 design + multi-cycle 작업 (medium-large 규모, 별도 inbox design
doc 트랙).

**`@derive(Display)` 옵션 2 안**:
- (a) `@derive_meta(Display)` 로 rename — meta-only, 의미 없는 emit 솔직
  표기
- (b) Display impl emitter 구현 — Rust 와 동일 의미.  단, 실제 trait
  dispatch 가 없으므로 사용처 부재.  (a) 가 honest path.

**Unknown attribute silent-absorb**: typo-friendly 이지만 silent failure
class.  Warning 발행 (`HX9xxx attribute-unknown`) 으로 lint-level
보강 가능 — small surgical PR 후보.

## Axis 3 — Memory model

| probe | hexa-current | canonical | verdict |
|---|---|---|---|
| arena allocator | ✓ pure arena (`__hexa_fn_arena_enter/return`, no Rc/Arc/Box) | Rust ownership / Py refcount / Go GC | ✅ intentional v1 |
| `let y = arr; y.push(99)` | ⚠ ALIAS (arrays shared, mutation visible at original) | Rust move-by-default / Py reference / Go slice | ⚠ design (intentional, see below) |
| dict alias | ⚠ same as array | same | ⚠ design |
| `move` / `own` / `borrow` keywords | ⚠ parsed but no-op (v1 spec) | Rust `move`/`own`/`borrow` enforced | reserved-but-unbacked |
| `&` / `&mut` borrows | ❌ absent | Rust canonical | ❌ design |

### 핵심 design 결정

**Pure arena = intentional v1**.  Rc/Arc/Box 부재 = single-TU monolith +
function-scope arena 로 lifetime 단순화.  Alias semantics by default =
**Python-leaning** (`y = arr` → reference share, mutation visible
upstream).  내부적으로 일관 (`if 1 {}` truthy + bool→int 등 다른 Python
canonical 과 동일 결).

**Reserved keywords path**:
- (a) **demote** (`move`/`own`/`borrow` 키워드 lexer 에서 drop) — 정직
  alias 모델
- (b) **wire** (실제 ownership/borrow checker 추가) — multi-month design,
  Rust 와 사실상 별도 언어.

**Recommend**: (a) until 실제 borrow-check demand 발생.  Hexa 를
single-thread, arena-only, alias-by-default 로 명시 (CANONICAL.md
보강 후보).

## Axis 4 — Generic type bounds

| probe | hexa-current | canonical | verdict |
|---|---|---|---|
| `fn foo<T: Display>(x: T)` 기본 bound | ⚠ parses + executes, bound **erased** (no monomorphization) | Rust monomorph | design (surface-only) |
| `fn f<T>(x) -> T where T: Display` | 🔴 r9-14 parse error → **FIXED** (PR #417) | Rust canonical | ✅ FIX-SURGICAL (parser wire) |
| const generics `<const N: usize>` | ❌ absent | Rust canonical | ❌ design |
| default tparams `<T = int>` | ❌ absent | Rust/Swift canonical | ❌ design |
| variance `<+T>` / `<-T>` | ❌ absent | Scala / Kotlin canonical | ❌ design |

### 핵심 design 결정

**Generics = pure surface syntax** (parse + execute, type-erased).
런타임은 dynamic (single union `HexaValue` enum), monomorphization 부재.
Bound 표기 (`T: Display`) 는 **문서 의미** 만 가짐 — 컴파일러가 실제
trait constraint 를 verify 하지 않음.

PR #417 의 `where` clause wire 는 **parser** 단의 missing branch 보완
(이미 helper `parse_where_clauses` 가 L4552 에 존재했고 `parse_fn_decl`
에서 호출만 하면 되는 mechanical wire).  Runtime semantic 변화 없음 —
where bound 도 erased.

**Monomorphization path**: type checker + impl-rule + generic
instantiation cache + codegen specialize → **large 규모, multi-cycle**.
현재 hexa 의 dynamic-only runtime 과 정면 충돌 (Engine A/G 양립
필요).  Cycle 5+ design doc 트랙.

## FIX-SURGICAL shipped this cycle

| 항목 | PR | 규모 | 상태 |
|---|---|---|---|
| r9-14 `where T: …` parser wire | **#417** | small (1-line dispatch fix in `parse_fn_decl` + helper already at L4552) | ✅ MERGED |
| r9-6 `MacroCall` parse-time fail-loud | PR pending (branch `fix/macrocall-parse-time-fail-loud` ready) | small (codegen unhandled-kind 가드와 동일 패턴, prior PR #369 형식) | 🟡 in-flight |

## 우선순위 (cycle 5+ 후보)

| 항목 | 규모 | 영향 |
|---|---|---|
| ~~**r9-19 `pub(crate)` top-level entry dispatch fix**~~ | ~~small~~ | **VERIFIED-CLOSED 2026-05-23** — already fixed by PR #373 (audit doc was stale); regression-guard added in `test/regression/parse_pub_crate_top_level.hexa` |
| **r9-7 `@derive(Display)` audit** (rename `@derive_meta` OR Display impl emitter) | small-medium | dead-feature honest-signal vs full-impl 결정 |
| **unknown attribute warning** (`HX9xxx attribute-unknown` lint) | small | typo-friendly → typo-detect 으로 보강 |
| **macro expander pass** (r9-6 단순 fail-loud 후속) | medium-large | full `macro_rules!` 의 디자인 — 별도 inbox design doc 트랙 |
| **`pub use` re-export + selective `use foo::{a,b}` + wildcard `*`** | medium | single-TU flatten 모델 유지 시 텍스트 alias 로 우회 가능 |
| **`::` fn namespacing** (enum-variant 와 모호성 해결) | medium | parser dispatch + symbol table 필요 |
| **`move`/`own`/`borrow` keyword demote OR wire** | small (demote) / multi-month (wire) | reserved-but-unbacked 정리 |
| **generic monomorphization** | large (multi-cycle) | dynamic runtime 과 양립 design 필요 |
| **const generics + default tparams + variance** | large | monomorph 의존 |

## Structural notes (low-priority design decisions)

- **Memory model = pure arena (intentional v1)** — alias semantics by
  default, no Rc/Arc/Box, function-scope arena enter/return.  Python-leaning,
  내부 일관성 보존.
- **Generics = pure surface syntax** — parse + execute, bound + where 모두
  type-erased.  Runtime = dynamic `HexaValue` union.
- **Modules = flatten-style** (`use "self/foo"`) — re-export / selective /
  wildcard / fn namespacing 모두 부재.  Single-TU monolith 가 의도.
- **Attributes = silent absorb** (unknown attribute lint-warning 부재) —
  typo-friendly 이지만 silent failure class.

## 참고

- PROBE r9 source (4 axes · 20 probes) — anima-side audit log.
- prior round inbox: `inbox/patches/canonical-audit-round-7-consolidated.md` (PR #395)
- prior round inbox: `inbox/patches/canonical-audit-round-8-consolidated.md` (PR #400)
- r9-14 FIX-SURGICAL: PR #417 (`fix/where-clause-parser-wire`)
- r9-6 FIX-SURGICAL: branch `fix/macrocall-parse-time-fail-loud` (PR pending), pattern mirrors PR #369 (unhandled-kind fail-loud)
- r8 CRITICAL closure: PR #407 (write_file leak root cause) + #414/#416 (root-cause + closure docs)
