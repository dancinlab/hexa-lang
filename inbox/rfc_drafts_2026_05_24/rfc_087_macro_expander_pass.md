# RFC 087 — macro-expander pass (`name!(args)` user-defined macros · hygiene · recursion limit)

- **Status**: proposed (design-draft, decision input phase)
- **Priority**: medium
- **Date**: 2026-05-24
- **Source**:
  - `inbox/patches/macro-expander-pass-design.md` (Phase 1 stub, PR #451 merged)
  - `inbox/patches/macro-expander-pass-design-detailed.md` (Phase 1 detailed, PR #451 merged)
  - `inbox/patches/macro-expander-phase2-rfc.md` (Phase 2 inbox patch, PR #493 open)
  - PROBE r14-W next-list item
- **Range**: parser + 신규 `self/macro_expand.hexa` 활성화 + codegen 통과 보장 (single-cycle Phase 2a 우선 → 후속 Phase 2b-2e 5-PR stack)
- **External-llm scope**: 없음 (compiler core)
- **Cycle origin**: cycle 2 patches triage PENDING #3 promote

## 0. 진행상황 (landed vs proposed)

| 단계 | 상태 | 출처 |
|---|---|---|
| MacroCall parse-time fail-loud | LANDED | PR #419 (`cca2cfda`) — `self/parser.hexa` `parse_postfix` `Not` arm |
| MacroCall codegen guard (`exit(1)`) | LANDED | PR #419 — `self/codegen.hexa` MacroCall arm |
| Phase 1 intrinsics (`println!` · `panic!` · `vec!`) | LANDED | PR #462 (`2a9f8028`) — `self/parser.hexa:3278-3340` parser-level desugar |
| `macro_rules`-style declaration parsing (`parse_macro_def`) | LANDED | `self/parser.hexa:4281` (legacy, currently 인덱싱 안 됨) |
| `@depth(N)` 속성 parsing | LANDED | `self/attrs/depth.hexa` |
| **user-defined macro expander pass** | **PROPOSED — 본 RFC 의 핵심** | — |
| gensym hygiene | PROPOSED (Phase 2d) | — |
| recursion / depth limit | PROPOSED (Phase 2 default) | — |
| `macro_rules!` pattern fragments (`$e:expr`) | DEFERRED (Phase 4) | — |
| procedural / `comptime fn` macros | OUT-OF-SCOPE | RFC TBD |

본 RFC = 위 표의 "PROPOSED" 행만 promote. 이미 LANDED 인 Phase 1 부분은 §5
에서 cross-link 만 한다 (다시 spec 하지 않는다).

## 1. Motivation

PR #419 가 `name!(args)` 를 parse-time 에 명시적으로 fail-loud 시키고, PR #462
가 3개 intrinsic (`println!`/`panic!`/`vec!`) 을 parser-level 에서 desugar
하여 ~80% 실용 표면을 덮었다. 그러나 다음 gap 이 남는다:

1. **사용자가 macro 를 선언할 수 없다**. `macro_rules!`-스타일 declaration
   (`parse_macro_def`) 은 AST 까지만 만들고, 어떤 pass 도 그 정의를 색인하지 않으며
   호출 시 lookup 되지 않는다. PR #462 intrinsic table 외의 모든 `name!(...)` 는
   여전히 parse-error 로 거부된다.
2. **hygiene 가 없다**. 만약 user-defined macro 가 land 하면 가장 흔한 함정
   (`let x = 1; set!(x); println(x)` 가 outer `x` 를 shadow 하는 문제) 이 무방비.
3. **재귀 한계가 없다**. expander 가 infinite recursion (`macro! loop { () => { loop!() } }`)
   에 진입하면 stack overflow / SEGV 가 발생할 수 있다 — diagnostic 으로 차단해야 한다.
4. **intrinsic 확장 비용이 크다**. 새 intrinsic 마다 parser surgery 가 필요한데
   (`self/parser.hexa:3278-3340`), 이는 scaling 이 안 된다. expander pass 가
   landing 되면 intrinsic 도 단일 dispatch table 로 정리 가능 (§3).

본 RFC 는 위 4 gap 을 expander pass 1개로 닫는 design 을 제안한다. Phase 1
은 paper-overing-the-gap (parse-error or hardcoded) 이었고, 본 RFC 는 user-
extensible 경로로 lift 한다.

## 2. Design

### 2.1 AST shape (이미 parser 에 존재)

```
MacroDef  = { kind="MacroDef",  name: string, rules: [MacroRule] }
MacroRule = { kind="MacroRule", params: [token], body: BlockExpr }
MacroCall = { kind="MacroCall", left|name: Name, op: "(" | "[", args: [Expr] }
```

추가 신규 노드 없음. v1 은 `MacroRule.params` 의 flat `[token]` 표현을 그대로
사용 (positional arity 매칭만 — 패턴 fragment 는 Phase 4).

### 2.2 expander pass timing

```
lex → parse → [NEW: index_macros] → [NEW: expand_macros] → typecheck → codegen
```

- `index_macros(ast)`: top-level decl 을 1-pass 순회, `_macro_table[name] = def`
  채움. 중복 정의 = hard error. intrinsic 과 이름 충돌 = hard error
  (`"<name>! is a reserved intrinsic macro"`).
- `expand_macros(ast, depth=0)`: 재귀 walker. `MacroCall` 노드를 만나면
  intrinsic table 우선 dispatch → user `_macro_table` lookup → substitute →
  result 에 재귀 (fixpoint).

신규 모듈 `self/macro_expand.hexa` (이미 ~100줄 legacy stub 존재; rewrite 또는
extend) 에 expander 본체 배치. parser/codegen 은 import 만 한다.

### 2.3 expansion 알고리즘 (v1 — positional, no fragment)

```
expand_macros(node, depth):
  if depth >= MAX_DEPTH (default 32):
      hard_error("macro expansion depth limit (32) exceeded at L:C")

  if node.kind == "MacroCall":
      name = node.name
      if name in _intrinsic_table:
          return _intrinsic_table[name](node.args)        // Phase 1 path
      if name not in _macro_table:
          hard_error("unknown macro '<name>!' at L:C — no MacroDef in scope")
      if _expanding_set[name]:
          hard_error("recursive macro expansion of '<name>!' at L:C")
      _expanding_set[name] = true
      def = _macro_table[name]
      rule = match_rule(def.rules, node.args)             // arity-first
      if rule == None:
          hard_error("no macro rule matches <name>!(<arity> args) at L:C")
      body_clone = ast_clone(rule.body)
      subst(body_clone, rule.params, node.args)           // positional
      result = expand_macros(body_clone, depth+1)         // fixpoint
      _expanding_set[name] = false
      return result

  // else: recurse into child nodes
  for child in children(node):
      child = expand_macros(child, depth)
  return node
```

핵심:
- `ast_clone` = 구조적 deep copy (~30 LoC) — 같은 `MacroDef.body` 가 여러 호출에
  공유되지 않도록.
- `subst` = body clone 의 `Name` 노드 중 이름이 `rule.params[i]` 인 것을
  `node.args[i]` 의 deep clone 으로 치환 (같은 arg 가 body 에 여러 번 나타날
  수 있으므로 매번 clone).
- 두 종류 guard:
  - **cycle guard** `_expanding_set` — 상호재귀 (`a! → b! → a!`) 감지.
  - **depth guard** `MAX_DEPTH=32` — 선형 깊이 재귀 감지 (`a! → a!` chain).

### 2.4 hygiene 전략 (Phase 2d)

v1 = **gensym-first**. 매 expansion 마다 monotone counter `<callid>` 발급,
clone 한 body 내부의 binding 도입 노드를 rewrite:

- `let x = ...` → `let __mac_<macroname>_<callid>_x = ...`
- `fn foo(a, b) { ... }` → `fn __mac_..._foo(__mac_..._a, __mac_..._b) { ... }`
- `match` arm pattern binding — 동일 rewrite.
- body 내부에서 그 binding 을 참조하는 모든 `Name` 도 함께 rewrite (같은
  symbol-table walk 1-pass).

**한계**: gensym 은 macro body → outer scope 방향의 shadow 만 막는다. 반대
방향 (`macro print_x!() { println(x) }` 가 call-site 의 `x` 를 capture 하는
문제) 은 syntax-context tagging 이 필요하며 v2 로 미룬다.

### 2.5 recursion limit · 진단 형식

- `MAX_DEPTH = 32` (구현 시 `@depth(N)` 속성으로 호출별 override 가능,
  `self/attrs/depth.hexa` 기존 parsing 재사용).
- 모든 macro 진단은 PR #444 caret-rendering 포맷 (`Parse error at L:C: msg`
  + source-snippet) 을 따른다.
- depth / cycle 초과 = exit code 1, stack trail 출력 (expand frame 마다 1 line).

## 3. Intrinsics vs user-defined (priority order)

| order | source | examples | landed? |
|---|---|---|---|
| 1 (highest) | `_intrinsic_table` (Phase 1, hardcoded) | `println!` · `panic!` · `vec!` | YES (PR #462) |
| 1+ | `_intrinsic_table` 확장 (본 RFC 권장 후속) | `assert!` · `dbg!` · `format!` · `todo!` · `unimplemented!` | NO |
| 2 | `_macro_table` (user `macro name! { ... }`) | user-defined | **본 RFC 의 핵심** |
| (reject) | user 가 intrinsic 이름과 충돌 | `macro println! { ... }` | hard error at index time |

stdlib prelude 의 일부 macro 도 expander 가 land 한 뒤 점진적으로 intrinsic
table → user-macro (stdlib-shipped) 로 이전 가능 (예: `vec!` 는 stdlib
prelude 에 정의 후 intrinsic table 에서 제거 — backwards compatibility 검사
필요).

intrinsic table 은 다음 4 단계:
1. Phase 1 (LANDED): `println!`/`panic!`/`vec!` — parser-level desugar
2. 본 RFC: intrinsic table 을 `_intrinsic_table` map 으로 분리 (lookup
   uniform). 신규 intrinsic 추가 시 parser surgery 불필요.
3. `assert!` · `dbg!` · `format!` · `todo!` · `unimplemented!` 5개 추가 (§6
   of detailed.md).
4. (장기) stdlib prelude 로 일부 이전 + intrinsic table 축소.

## 4. Falsifiers

본 RFC 의 acceptance gate. 각 5 falsifier 는 `tests/regression/macro_*.hexa`
corpus 로 land.

| ID | name | spec |
|---|---|---|
| F1 | **PARSE-MACRO** | `macro shout! { ($x) => { println(to_string($x).to_upper()) } }` 가 parse-error 없이 AST 로 떨어진다. `index_macros` 후 `_macro_table["shout"]` 가 채워진다. |
| F2 | **EXPAND-INTRINSIC** | `assert!(false)` 가 expander 를 통과해 runtime 에 `panic("assert failed at <file>:<L:C>")` 으로 도달한다. exit code 1. (intrinsic table 확장의 smoke; `println!` 은 이미 PASS.) |
| F3 | **HYGIENE-CAPTURE** | `let x = 1; macro set! { () => { let x = 2 } }; set!(); println(x)` 가 `1` 을 출력한다 (gensym 으로 inner `x` 가 outer `x` 를 shadow 하지 않음). |
| F4 | **RECURSION-LIMIT** | `macro loop! { () => { loop!() } }; loop!()` 가 SEGV 없이 깨끗한 diagnostic (`"macro expansion depth limit (32) exceeded at L:C"`) + exit code 1 로 종료. |
| F5 | **RUNTIME-NOOP-IF-NOT-EXPANDED** | expander pass 가 비활성 상태 (env var `HEXA_MACRO_EXPAND=0` 또는 build flag) 일 때, Phase 1 intrinsics 는 그대로 동작하고 user-macro 는 PR #419 의 fail-loud diagnostic 으로 거부된다 — 즉 expander 가 codegen-side 로 leak 하지 않는다. |

F4 는 진짜 SEGV oracle: `ulimit -c 0; hexa run <fixture>` exit code 가 1 이어야
하며 137 (SIGSEGV) 또는 139 면 FAIL.

F5 는 backward-compat oracle: 본 RFC 가 land 해도 Phase 1 의 동작이 깨지면 안
된다. 동시에 expander 가 disable 됐을 때 user-macro 가 silent-succeed 하면
안 된다 (반드시 fail-loud).

## 5. Cross-link

| reference | 위치 | 본 RFC 와의 관계 |
|---|---|---|
| PR #419 (`cca2cfda`) | `self/parser.hexa` `parse_postfix` Not arm + `self/codegen.hexa` MacroCall arm | parse-time fail-loud baseline — 본 RFC 는 이 gate 를 "정의된 macro 면 통과" 로 lift |
| PR #451 (`fcb265e3`) | `inbox/patches/macro-expander-pass-design{,-detailed}.md` | Phase 1 design doc (97+290줄) — 본 RFC §2 알고리즘의 reference |
| PR #462 (`2a9f8028`) | `self/parser.hexa:3278-3340` | Phase 1 intrinsics 구현 — 본 RFC §3 의 intrinsic table 이 이를 흡수 |
| PR #493 (open) | `inbox/patches/macro-expander-phase2-rfc.md` (`bbe61b7c`) | Phase 2 inbox patch — 본 RFC 가 정식 promote |
| RFC 080 (`hexa loop --dfs`) | `stdlib/loop` · `compiler/atlas` | macro 와 무관 (atlas absorption pipeline). PROBE Phase O 에서 macro 흔적 없음 — cross-check 결과 NEGATIVE (별도 충돌 없음). |
| `self/macro_expand.hexa` | 기존 legacy stub | 본 RFC 가 활성화 대상으로 지정 (rewrite 또는 extend) |
| `self/attrs/depth.hexa` | `@depth(N)` 속성 parser | §2.5 recursion limit override 시 재사용 |
| PR #444 (caret rendering) | parse-error 포맷 | 본 RFC §2.5 진단 형식이 이를 reuse |
| `inbox/patches/macro-expander-pass-design-detailed.md` §8 | 4-phase 로드맵 표 | 본 RFC §6 phasing 의 baseline |

## 6. Phasing (5-PR stack, g4 준수)

본 RFC 본문은 design 만 정의한다. 구현은 5 PR stack 으로 land:

| phase | scope | est. LoC | acceptance |
|---|---|---|---|
| 2a | declaration parsing 활성화 + `_macro_table` 인덱싱 — invocation 은 여전히 fail-loud | ~80 LoC | F1 PASS |
| 2b | positional substitution + arity match + intrinsic table re-organize | ~200 LoC | F2 PASS + Phase 1 regression PASS |
| 2c | recursion / cycle / depth guard (`_expanding_set` + MAX_DEPTH) | ~50 LoC | F4 PASS |
| 2d | gensym hygiene | ~100 LoC | F3 PASS |
| 2e | F5 fall-through gate + env-var disable knob | ~30 LoC | F5 PASS |

각 단계는 `--base` 가 이전 단계 — gh-stack 패턴. Phase 4 (`macro_rules!`
fragment 패턴, repetition `$($x),*`) 는 별도 RFC.

## 7. Out of scope

- 절차적 / `comptime fn` macro (Rust `proc_macro` / Zig `comptime`) — 별도
  RFC TBD.
- `#[cfg(...)]` 조건 컴파일 — 속성 시스템 별도 RFC.
- v2 hygiene (Racket / late-rustc syntax-context tagging) — Phase 3 (gensym)
  가 bite 한 뒤 별도 amendment.
- `derive!` 매크로 — `@derive(...)` 속성으로 이미 별도 path (스캐폴드 중).
- macro 의 export / import (module boundary 가로지르기) — Phase 2f 별도.

## 8. Open questions (decision input)

1. **declaration syntax**: `macro name! { ... }` (hexa-canonical) vs
   `macro_rules! name { ... }` (Rust-canonical). 본 RFC 권고 = 전자 (keyword
   추가 0개, `macro` 는 이미 reserved at `self/lexer.hexa`/`parser.hexa`
   L308·L576·L588).
2. **recursion default**: `MAX_DEPTH = 32` (Rust 는 128). 권고 = 32 (실용
   범위 충분 + diagnostic 빠른 surface).
3. **intrinsic 충돌 정책**: user 가 `macro println! { ... }` 선언 시 silent
   override 허용 vs hard error. 권고 = hard error (Phase 1 intrinsic 의
   안정성 + 외부 사용자 surprise 방지).
4. **stdlib prelude 마이그레이션 시점**: 본 RFC 와 동시에 시작 vs Phase 4
   이후. 권고 = Phase 4 이후 (먼저 expander 안정화 + prelude shipping
   infra 검증).

## 9. References

- PR #419 (`cca2cfda`) — MacroCall parse-time fail-loud
- PR #451 (`fcb265e3`) — Phase 1 detailed design RFC
- PR #462 (`2a9f8028`) — Phase 1 intrinsics
- PR #493 (open) — Phase 2 inbox patch (본 RFC 의 직전 input)
- `inbox/patches/macro-expander-pass-design.md` — Phase 1 stub
- `inbox/patches/macro-expander-pass-design-detailed.md` — Phase 1 detailed
- `inbox/patches/macro-expander-phase2-rfc.md` — Phase 2 inbox patch
- `self/parser.hexa:3248-3340` (intrinsic dispatch), `self/parser.hexa:4281`
  (`parse_macro_def`), `self/codegen.hexa` MacroCall arm
- `self/macro_expand.hexa` (legacy stub, rewrite target)
- `self/attrs/depth.hexa` (`@depth(N)` 속성)
- Rust Reference §3.5 — *Macros By Example* (declarative `macro_rules!`)
- Racket — *Macros and Hygiene* (v2 syntax-context tagging reference)

---

**RFC 087 closes when**: 5 falsifier corpus (F1-F5) PASS on `feat/macro-
expander-phase2-stack` (Phase 2a-2e merged), `inbox/patches/macro-expander-
phase2-rfc.md` deleted in closing PR, `HEXA-LANG.md` D-table 의 macro
expander 항목이 LANDED 로 flip.
