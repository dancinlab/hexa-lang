# r16 RFC — 함수 호출/파라미터 ergonomics + 튜플 타입

- **Status**: design-draft (설계 명세 · 본 문서는 권고이며 후속 surgical PR 가 feature 별로 구현)
- **Date**: 2026-05-25
- **Severity**: MEDIUM-HIGH (ergonomics gap · canonical-lang parity · 모두 parse-level 미구현)
- **Source**: PROBE r16 — function call/param ergonomics + tuple type sweep
- **Lane**: docs-only. 본 문서는 설계 명세이며 컴파일러 소스(`parser.hexa` / `codegen.hexa` / `runtime*.c`)는 **건드리지 않음**. (in-flight codegen PR 와의 충돌 회피)
- **선행 foundation**:
  - struct field `default_expr` 슬롯 — PROBE r14-CCCC, `parser.hexa:2363-2380` (default args 의 직접 선례)
  - `...` spread 토큰 — call-arg `f(...args)` (`parser.hexa:3661`) + array-rest `let [a,...rest]` (`parser.hexa:1584`) + array-pattern rest (`parser.hexa:2884`)
  - array destructure `let [a,b,c] = expr` — PROBE r7 + #810, `parser.hexa:1578` / codegen `DestructLetStmt` (`codegen.hexa:3659`)
  - match arm arrow `=>`/`->` + or-pattern `|` + guard `if` — `parser.hexa:2769`

---

## 1. 배경 — 5개 deviation + 측정 evidence

5개 deviation 은 모두 **함수 호출-부 / 파라미터-리스트 / 튜플 ergonomics** 라는 한 가지 응집된 영역에 속한다. 전부 현 `origin/main` (`3de45d9f`) 의 self-hosted transpiler (`self/native/hexa_v2`) 로 직접 transpile 하여 재현했다.

### 1.1 측정 evidence (probe 직접 실행)

각 probe 를 `hexa_v2 <in.hexa> <out.c>` 로 transpile → stderr 의 parse error verbatim 캡처.

| # | feature | probe 입력 | 측정된 parse error |
|---|---|---|---|
| 1 | default args | `fn f(x, y = 10) { ... }` | `Parse error at 1:11: expected RParen, got Eq ('=')` |
| 2 | named args | `f(y: 5, x: 1)` | `Parse error at 2:22: expected RParen, got Colon (':')` |
| 3 | param varargs | `fn sum(xs...) { ... }` | `Parse error at 1:10: expected RParen, got DotDotDot ('...')` |
| 4 | tuple destructure | `let (a, b) = (1, 2)` | `Parse error at 1:17: expected identifier, got LParen ('(')` |
| 5 | `@` binding | `match n { n @ 1..=5 => 1, ... }` | `Parse error at 1:37: expected FatArrow, got At ('@')` |

### 1.2 foundation 의 실제 상태 (중요 — 일부는 parse-only)

probe 로 직접 확인한 foundation 상태:

- **array destructure `let [a,b,c]=expr`** — parse + codegen 모두 OK (`OK: ...c`). 튜플 lowering 의 재사용 대상.
- **call-arg spread `f(...args)`** — **parse 는 통과하나 codegen 에서 실패**: `[codegen_c2] ERROR: unhandled expression kind: Spread`. 즉 `...` spread 는 *파서 토큰* 으로만 존재하고 codegen-wired 되어있지 **않다**. varargs 제안(§4c) 은 이 미완 plumbing 을 codegen 까지 완성하는 작업도 포함해야 한다.
- **struct field default** — `default_expr` 슬롯이 이미 parse + codegen(StructInit auto-fill) 둘 다 동작. default-arg 의 가장 가까운 선례.

> 함의: 5개 deviation 중 default-args 만이 "양쪽이 살아있는 선례"(struct field)를 가진다. 나머지는 신규 AST 슬롯 또는 신규 codegen 분기가 필요하며, varargs 는 더 나아가 *기존 Spread 미완 codegen* 까지 마저 채워야 한다.

---

## 2. canonical 비교표 (feature × language)

| feature | Python | Swift | Rust | Go |
|---|---|---|---|---|
| **default args** | ✅ `def f(x, y=10)` | ✅ `func f(y: Int = 10)` | ❌ (없음 · builder/`Default`) | ❌ (없음 · variadic/option struct) |
| **named/keyword args** | ✅ `f(y=5, x=1)` | ✅ `f(x: 1, y: 5)` (label 강제) | ❌ | ❌ |
| **param varargs** | ✅ `def f(*args)` | ✅ `func f(_ xs: Int...)` | ❌ (매크로/슬라이스) | ✅ `func f(xs ...int)` |
| **tuple type** | ✅ first-class `(a, b)` | ✅ first-class `(Int, Int)` | ✅ first-class `(i64, i64)` | △ multi-return `(int, int)` (튜플 타입 자체는 없음) |
| **`@` binding** | ❌ (없음 · `:=` walrus 와 무관) | ❌ | ✅ `n @ 1..=5 => ...` | ❌ |

해석:

- **tuple** — 3개 주류(Py/Swift/Rust)가 first-class. Go 도 multi-return 으로 *경험적으로* 동등 효과. → 가장 보편적 · 가장 높은 가치.
- **default args** — Py/Swift 강세. Rust/Go 는 의도적 부재(대안 패턴 존재). hexa 는 struct field 선례가 있어 비용이 가장 낮음. → 높은 가치.
- **named args** — Py/Swift 만. Swift 는 label 을 강제(call-site 가독성 철학). → 중간 가치, default-args 와 시너지.
- **varargs** — Py/Swift/Go. 셋 다 채택했으나 hexa 는 Spread codegen 미완이라 비용이 큼. → 중간-낮은 가치.
- **`@` binding** — Rust 단독. 강력하지만 niche. → 가장 낮은 가치.

---

## 3. 우선순위 (가치 / 비용)

| 순위 | feature | 가치 | 비용 | 근거 |
|---|---|---|---|---|
| **1** | tuple `(a,b)` + destructure + return | 高 | 中 | 3+ 주류 first-class · array-destructure(#810) 기계 재사용 가능 |
| **2** | default args `fn f(x, y=10)` | 高 | **低** | struct field `default_expr` 양쪽-살아있는 선례 |
| 3 | named args `f(y:5, x:1)` | 中 | 中 | call-site 재정렬 로직 필요 · default-args 와 시너지 |
| 4 | param varargs `fn f(xs...)` | 中 | 高 | Spread codegen 미완 → plumbing 까지 마저 완성 필요 |
| 5 | `@` binding `n @ 1..=5` | 低 | 低 | match-pattern 1-슬롯 추가 · niche |

핵심 권고: **tuple + default args 를 먼저 랜딩**. 둘 다 기존 기계(destructure / struct-field default)에 올라타므로 신규 표면이 작다. varargs 는 Spread codegen 을 먼저 닫아야 해서 마지막 그룹.

---

## 4. feature 별 제안 — 문법 · 구현 locus · phasing

### (a) Default args — `fn f(x, y = 10)`

- **문법**: 파라미터 타입 주석 직후 `= EXPR`. struct field 와 동일한 형태.
- **parser locus**: `parse_params()` (`parser.hexa:2277`). 현재 각 param 은 `name` + optional `: type` 만 읽는다. struct field(`parser.hexa:2368-2372`)와 동형으로, type 직후 `p_peek_kind() == "Eq"` 이면 `p_advance()` + `parse_expr()` 하여 `Param` 노드에 **`default_expr` 슬롯** 을 추가. 첫 param 과 `while Comma` 루프 양쪽에 동일 패치 (parse_params 는 두 곳에서 param 을 만든다).
- **codegen 접근**: 두 전략.
  - **전략 A (call-site fill)** — 호출부에서 인자 개수가 모자라면 함수 선언의 `default_expr` 를 채워 emit. struct `StructInit` auto-fill 의 정확한 함수-버전. AST 에 함수 선언 lookup 필요(이미 codegen 이 함수 테이블 보유).
  - **전략 B (callee prologue)** — C 함수가 가변 인자를 못 받으므로 hexa→C 는 fixed-arity. 따라서 A 가 자연스럽다. C 생성 시 모든 call-site 가 full-arity 로 전개되도록 한다.
- **acceptance probe** → §5-A.

### (b) Named args (call site) — `f(y: 5, x: 1)`

- **문법**: call-arg 가 `IDENT ':' EXPR` 형태일 때 keyword arg. positional 과 혼용 시 positional 먼저(Python 규칙) 권고.
- **parser locus**: `parse_args()` (`parser.hexa:3652`). 각 arg 진입에서 `p_peek().kind == "Ident" && p_peek_ahead(1).kind == "Colon"` lookahead → keyword arg 노드(`name=키`, `left=값`). 단 map-literal `#{...}` 및 struct-init 과의 토큰 충돌 없음(call-arg 컨텍스트 한정).
- **codegen 접근**: call-site 에서 함수 선언의 파라미터 순서를 lookup 하여 keyword arg 를 positional 순서로 **재정렬** 후 emit. default-args(a)와 결합 시: 누락 positional 은 default 로, 명시 keyword 는 제자리에. → (a) 랜딩 후 진행 권고(공유 call-site rewrite 경로).
- **acceptance probe** → §5-B.

### (c) Param varargs — `fn sum(xs...)`

- **문법**: 마지막 파라미터에 `IDENT '...'` (Go 스타일 trailing). 대안 `(...xs)` 는 array-rest 와 시각적 일관(`let [a, ...rest]`)이나 Go 가 trailing 이므로 `xs...` 권고.
- **parser locus**: `parse_params()` (`parser.hexa:2277`). param name 읽은 직후 `p_peek_kind() == "DotDotDot"` 이면 consume + `Param` 노드에 `is_variadic` 플래그. **마지막 파라미터에만 허용** (이후 Comma 금지) — 진단 필요.
- **codegen 접근**: 두 단계 선결 작업.
  1. **Spread codegen 먼저 닫기** — 현재 `f(...args)` 가 `unhandled expression kind: Spread` 로 죽는다(§1.2). varargs callee 와 spread caller 는 짝(`sum(...arr)` ↔ `fn sum(xs...)`)이므로 같이 닫는 것이 정합적.
  2. hexa→C 는 fixed-arity 이므로 variadic 은 **배열 packing** 으로 lower: `sum(1,2,3)` → callee 에 단일 `HexaVal xs = [1,2,3]`. spread `sum(...arr)` → `xs = arr` 직결.
- **acceptance probe** → §5-C.

### (d) Tuple — `(a, b)` 리터럴 + 타입 + destructure + return

가장 응집적이고 가치 높은 작업. 4개 하위-표면:

1. **tuple literal** `(1, 2)` — `parse_primary()` (`parser.hexa:3767`)의 `LParen` 분기. 현재 `(` 는 grouped-expr. `(` 후 첫 expr 파싱 → `Comma` 가 따라오면 tuple, 아니면 기존 grouped-expr (back-compat 핵심: `(x)` 는 그대로 grouped).
2. **tuple destructure** `let (a, b) = expr` — `parse_let()` (`parser.hexa:1528`). 현재 `LBracket`(array) / `LBrace`(map) 분기가 있다. **`LParen` 분기 추가**: array-destructure(`parser.hexa:1578`)와 동형으로 ident 목록 수집 → 기존 `DestructLetStmt` 재사용 가능(아래).
3. **tuple type** `(int, int)` — `parse_type_annotation()`. `LParen` 진입 시 타입 목록. (타입 검사 표면이 얇으면 phase-2 로 미뤄도 됨 — 런타임은 array 와 동형이므로 타입 주석은 문서적.)
4. **tuple return** `fn f() { return (1,2) }` + `let (a,b) = f()` — (1)+(2) 가 닫히면 자동 성립.
- **codegen 접근 (핵심 — array-destructure 재사용)**: tuple 을 **HexaVal array 로 lower** 한다. `(1,2)` → `[1,2]`, `let (a,b)=t` → 기존 `DestructLetStmt` codegen(`codegen.hexa:3659`)이 `hexa_array_get(tmp, i)` 로 이미 정확히 처리. 따라서 tuple destructure 는 parser 에서 `DestructLetStmt` 노드를 그대로 emit 하면 codegen 무수정으로 동작. tuple literal 만 `Array` 노드로 lower 하면 됨.
- **acceptance probe** → §5-D.

### (e) `@` binding (match) — `n @ 1..=5 => ...`

- **문법**: match pattern 에서 `IDENT '@' PATTERN`. 매치되면 전체 스크루티니를 `IDENT` 에 바인딩.
- **parser locus**: `parse_match_pattern()` (`parser.hexa:2840`). pattern 파싱 후 (또는 ident lookahead 시) `p_peek_kind() == "At"` 이면 consume + 하위 pattern 파싱 → **bind-name 슬롯** 추가한 pattern 노드. range pattern `1..=5` 은 이미 `DotDotEq` 로 파싱됨(`parser.hexa:3222`)이므로 sub-pattern 으로 자연 결합.
- **codegen 접근**: match lowering 시 arm guard/body 진입에서 `bind_name = <scrutinee>` 지역 변수 1개 추가 emit. or-pattern/guard 와 독립.
- **acceptance probe** → §5-E.

---

## 5. Acceptance probes (falsifiable)

각 probe 는 transpile→`clang`→실행 결과가 expected 와 일치해야 PASS. 현재는 전부 parse error (FAIL) — falsifier baseline 확보됨.

### §5-A default args
```hexa
fn f(x, y = 10) { return x + y }
fn main() { print(f(1)); print(f(1, 2)) }
```
expected: `11` then `3`.

### §5-B named args
```hexa
fn f(x, y) { return x - y }
fn main() { print(f(y: 5, x: 1)) }
```
expected: `-4` (재정렬 후 x=1, y=5).

### §5-C varargs
```hexa
fn sum(xs...) { let mut s = 0; for x in xs { s = s + x }; return s }
fn main() { print(sum(1, 2, 3)); let a = [4, 5]; print(sum(...a)) }
```
expected: `6` then `9`. (두 번째 줄은 §1.2 Spread codegen 동시 closure 검증.)

### §5-D tuple
```hexa
fn swap(a, b) { return (b, a) }
fn main() {
    let (x, y) = swap(1, 2)
    print(x); print(y)
    let t = (10, 20)
    let (p, q) = t
    print(p + q)
}
```
expected: `2`, `1`, `30`.

### §5-E `@` binding
```hexa
fn classify(n) {
    return match n {
        m @ 1..=5 => m * 10,
        _ => 0
    }
}
fn main() { print(classify(3)); print(classify(9)) }
```
expected: `30` then `0`.

---

## 6. 권고 구현 순서 (landing order)

1. **default args** (§4a) — 비용 최저, struct-field 선례 직재사용. 가장 먼저 랜딩하여 (b) named-args 의 call-site rewrite 경로를 깐다.
2. **tuple** (§4d) — DestructLetStmt 재사용으로 codegen 거의 무료. literal lowering 만 신규. 가치 최고.
3. **named args** (§4b) — (a) 의 call-site rewrite 경로 위에 reorder 로직 추가.
4. **`@` binding** (§4e) — 독립적·소규모. 어느 시점이든 끼워넣기 가능.
5. **varargs** (§4c) — 마지막. 선결로 Spread codegen(§1.2)을 닫아야 하므로 가장 무겁다.

> 그룹화: {1,2} = "저비용 고가치 선두 그룹" · {3,4} = "중간 끼워넣기" · {5} = "Spread closure 동반 후미 그룹".

---

## 7. Open questions

1. **named + positional 혼용 규칙** — Python 식(positional 먼저 강제)인가, 자유 순서 허용인가? Swift 는 label 강제라 혼용 개념이 없음. → Python 규칙 권고하나 결정 필요.
2. **tuple vs grouped-expr 모호성** — `(x)` 는 grouped-expr 로 유지(1-튜플 아님). Python 은 `(x,)` 로 1-튜플 표기. hexa 도 trailing comma `(x,)` 를 1-튜플로 할지? → 초기엔 미지원(2+ 원소만 tuple) 권고.
3. **tuple 타입 주석 깊이** — 런타임은 array 동형이므로 `(int, int)` 주석을 의미론적으로 검사할지, 문서적 통과만 할지. → phase-1 은 문서적 통과(파싱만), 타입 검사는 별도.
4. **varargs declarator 형태** — `xs...`(Go) vs `...xs`(array-rest 일관). → `xs...` 권고하나 array-rest 일관성 주장도 valid.
5. **default_expr 평가 시점** — call-site fill(전략 A) 시 default 표현식이 caller scope 에서 평가되는데, callee scope 의 다른 파라미터를 참조하는 default(`fn f(x, y = x)`)는 금지할지? → 초기엔 상수/순수 표현식만 권고.
6. **`@` binding 과 or-pattern 결합** — `m @ (1 | 2 | 3)` 형태 허용 범위. → phase-1 은 단일 sub-pattern 만.

---

## 8. Provenance

- 측정 환경: `origin/main` `3de45d9f` · `self/native/hexa_v2` (self-hosted transpiler) · 5개 probe 직접 transpile, stderr verbatim.
- foundation 검증: `f(...args)` codegen 실패(`unhandled expression kind: Spread`) 와 `let [a,b,c]` codegen 성공(`OK`)을 직접 측정으로 구분 — varargs 비용 산정의 근거.
- parser locus 인용: `parse_params`(2277) · `parse_args`(3652) · `parse_let`(1528) · `parse_match_pattern`(2840) · `parse_primary`(3767) — 전부 `self/parser.hexa` 현 main.
- codegen 인용: `DestructLetStmt`(`codegen.hexa:3659`) · struct field `default_expr`(`parser.hexa:2363-2380`).
- 본 문서는 docs-only. 구현은 feature 별 후속 surgical PR 가 §6 순서로 수행한다.
