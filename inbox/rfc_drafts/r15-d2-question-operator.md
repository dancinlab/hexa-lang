# r15-D2 RFC — `?` 연산자 (error/optional propagation) desugar + flow-type

- **Status**: design-draft (구현 대상 명세 · 별도 surgical PR 가 본 문서에 대해 구현)
- **Date**: 2026-05-24
- **Severity**: MEDIUM-HIGH (ergonomics gap · Option/Result lane 의 자연스러운 다음 단계)
- **Source**: PROBE r15 cycle-1 sweep — "D2 [RFC] `?` operator unimplemented — desugar + flow type"
- **Implements**: [[rfc_081_option_result_lane]] D2 (🟢 2026-05-23 결정 = **A. Rust `?` postfix**) 의 implementation-design (`rfc_081_impl_b` 에 해당)
- **선행 랜딩**: PR #756 (r15-D3 — `Some/Ok/Err/None` match pattern-bind) · PR #725 (r15-D4 — `.unwrap` / `.unwrap_or` / `.map`)
- **Lane**: docs-only. 본 문서는 명세이며 컴파일러 소스(`parser.hexa` / `codegen.hexa`)는 건드리지 않음.

---

## 1. 배경 — 현 동작 + evidence

hexa 는 r15-D3/D4 에서 Option/Result lane 의 두 축을 이미 확보했다:

| 기능 | PR | 동작 |
|---|---|---|
| `match` 에서 `Some(v)` / `Ok(v)` / `Err(e)` / `None` pattern-bind | #756 (r15-D3) | tagged-array `[tag, payload]` 에서 index 1+ binder 추출 |
| `.unwrap()` / `.unwrap_or(d)` / `.map(f)` | #725 (r15-D4) | `HX_IS_ARRAY` discriminant 으로 Some/None 분기 (closed-form C) |

다음 ergonomic 단계는 **early-return propagation 연산자 `?`** — RFC 081 이 D2=A 로 이미 결정했고 본 문서가 그 detail 명세다.

### 1.1 confirmed 현 동작 (probe evidence)

probe `maybe()?` 를 현 main 의 self-hosted transpiler (`hexa-cc`, `self/native/hexa_v2`) 로 직접 transpile:

```hexa
// /tmp/q_probe.hexa
fn maybe() { return Some(42) }
fn f() {
    let v = maybe()?         // ← 여기
    return Ok(v)
}
```

```
$ ./hxprobe /tmp/q_probe.hexa /tmp/q_probe.c
Parse error at 6:20: unexpected token Question ('?')
    |
  6 |     let v = maybe()?
    |                    ^
```

chained 형태도 동일 — `?.` (QuestionDot) 는 통과하나 trailing `?` 에서 reject:

```
$ ./hxprobe /tmp/q_probe2.hexa /tmp/q_probe2.c   # let v = a()?.b()?
Parse error at 2:21: unexpected token Question ('?')
    |
  2 |     let v = a()?.b()?
    |                     ^
```

대조 — type-annotation suffix `T?` 와 optional-chaining `?.` 는 **이미 동작** (regression 금지 대상):

```
$ ./hxprobe /tmp/q_probe3.hexa ...   # fn g(x: int?) → OK (exit 0)
```

### 1.2 진단 — 왜 reject 되는가

lexer 는 이미 `Question` / `QuestionDot` 토큰을 emit 한다 (`self/lexer.hexa:1176-1198`). `Question` 토큰의 **유일한** consumer 는 두 곳:

| 위치 | 역할 |
|---|---|
| `parser.hexa:2264` (`parse_type_annotation`) | type suffix `T?` — Optional 타입 표기 |
| `parser.hexa:3729` (generic-arg list 판정) | `[T?]` 등 generic 인자 안 |

→ `parse_postfix()` (`parser.hexa:3353`) 의 loop 에는 `LParen` · `Dot` · `QuestionDot` · `LBracket` · `Not` arm 만 있고 **postfix `Question` arm 이 없다**. 따라서 expression position 의 `expr?` 는 postfix loop 가 `cont = false` 로 빠져나간 뒤 dangling `Question` 토큰이 남아 statement 종료 시 "unexpected token" 으로 reject 된다.

---

## 2. Canonical 조사표

### 2.1 Rust `?`

```rust
// expr?  desugars to:
match expr {
    Ok(v)  => v,
    Err(e) => return Err(From::from(e)),   // Result lane
}
// Option lane:
match expr {
    Some(v) => v,
    None    => return None,
}
```

- **(a) 적용 컨테이너**: `Result<T,E>` · `Option<T>` (그리고 `Try` trait 일반화).
- **(b) enclosing-fn return-type 요구**: `?` 가 등장하는 함수는 `-> Result<…>` (또는 `-> Option<…>`) 여야 함. mismatch 면 compile error.
- **(c) error-type 변환**: `Err(From::from(e))` — `From` trait 으로 inner error → enclosing 함수의 `E` 로 자동 변환. (Rust 만의 정적 type 기능.)
- **(d) `Result` ↔ `Option` 혼용 금지**: `Option` 에 `?` 쓰는 함수는 `-> Option`, `Result` 면 `-> Result`. (단 `.ok_or(…)` 등으로 lane 전환 가능.)

### 2.2 Swift — 대조군

| 표면 | 의미 | hexa 와의 관계 |
|---|---|---|
| `try?` (prefix) | throwing call 이 throw 하면 expr 가 `nil` 로 evaluate (**return 안 함**) | RFC 081 D2 가 follow-up 으로 분류 — 본 RFC scope 밖 |
| `?.` (optional chaining) | `a?.b` — `a == nil` 이면 전체 chain `nil`, 아니면 unwrap 후 `.b` | hexa 에 **이미 존재** (`OptField`, `codegen.hexa:4957`) — `?` 와 별개 surface |

### 2.3 설계 축 요약 + hexa 입장

| 축 | Rust | Swift | **hexa 제안** |
|---|---|---|---|
| (a) 컨테이너 | Result, Option | Optional | Result(`Ok/Err`) + Option(`Some/None`) |
| (b) fn return 요구 | static type check | — | **dynamic — 명시 type check 없음** (§3.3) |
| (c) error 변환 | `From::from(e)` | — | **불필요 — dynamic typed, re-wrap only** (§3.4) |
| (d) 표현 | nominal enum | NPO | **tagged-array `[tag, payload]`** (기존 codegen 재사용) |

---

## 3. 제안 desugar 설계

### 3.1 핵심 desugar (semantic)

`expr?` 는 다음과 의미적으로 동등:

```hexa
// Result lane (expr 가 [Ok|Err, ...]):
match expr {
    Ok(v)  => v,
    Err(e) => return Err(e),    // ← From 변환 없음 (dynamic)
}
// Option lane (expr 가 [Some, ...] 또는 tag "None"):
match expr {
    Some(v) => v,
    None    => return None,
}
```

`Ok` 와 `Some` 둘 다 "성공" tag 이므로 unwrap → payload, 그 외 tag 는 **있는 그대로 caller 로 re-return**. lane 을 컴파일타임에 구분할 필요가 없다 (런타임 tag 검사로 충분) — Result 의 `Err` 와 Option 의 `None` 은 **둘 다 "not the success arm" → early-return** 라는 동일 동작이기 때문이다.

### 3.2 parser 변경 (postfix `Question` arm)

`parse_postfix()` loop (`parser.hexa:3353`) 에 `QuestionDot` arm 바로 앞/뒤로 신규 arm 추가:

```
} else if k == "Question" {
    // Postfix try-propagation: expr? → Try(expr).
    // 단, lookahead 로 ternary/type-suffix 와 구분 (§3.6).
    p_advance()
    expr = #{ "kind": "Try", "left": expr, ... }   // 신규 AST node "Try"
}
```

신규 AST node 1종: **`Try { left: <expr> }`**. 기존 `OptField` / `Index` 노드와 형제. 별도 lexer 변경 불요 (`Question` 토큰 이미 존재).

### 3.3 enclosing-fn 제약 — hexa 의 looser dynamic 입장

Rust 는 `?` 함수가 `-> Result` 임을 정적 검증한다. hexa 는 dynamically typed → **명시적 return-type 선언 자체가 optional** 이다. 따라서:

- **v1 (권고)**: enclosing-fn return-type **검증 없음**. `expr?` 는 단지 "성공이면 unwrap, 아니면 현재 함수에서 즉시 return" 으로 lower. 함수가 우연히 Result/Option 이 아닌 값을 return 하더라도 그건 사용자 책임 (dynamic lang convention).
- **lint (follow-up)**: `?` 를 포함한 함수의 다른 return path 가 `Ok/Err/Some/None` 으로 안 끝나면 warn. (정적 type-checker 없이 best-effort.)

이는 r15-D4 `.unwrap()` 이 택한 입장 (런타임 `HX_IS_ARRAY` 분기, 컴파일타임 type 강제 없음) 과 일관된다.

### 3.4 error-type handling — `From` 불필요

hexa 는 dynamic → error 값을 변환 없이 그대로 re-wrap:

```
Err(e) 발견 → return Err(e)      // 원래 [tag="Err", payload] 를 그대로 return
None  발견 → return None         // 원래 tag "None" (hexa_str("None")) 를 그대로 return
```

Rust 의 `From::from(e)` 에 대응하는 단계가 없다. 가장 단순한 방식 — 받은 실패 값을 손대지 않고 통과. 실패 값 자체가 이미 `[tag, payload]` (또는 bare `None` tag) 형태이므로 re-wrap 도 사실상 identity (`return scrutinee` 로 충분, §3.5 참고).

### 3.5 C-codegen sketch (before / after)

타깃 함수 시그니처는 모두 `HexaVal f(void)` 형태 (codegen 의 모든 hexa fn). `?` 는 early-return 을 도입하므로 **statement-level lowering 이 가장 깔끔** — GCC statement-expression `({…})` 안에서는 enclosing C 함수를 `return` 할 수 없기 때문 (stmt-expr 의 `return` 은 enclosing fn 을 빠져나가지 못함; 값만 산출).

#### Case A — statement-position `let x = expr?` (가장 흔함)

**Before** (현 reject):
```hexa
fn f() {
    let v = maybe()?
    return Ok(v)
}
```

**After** (desugar → C, `maybe()` 를 한 번만 평가):
```c
HexaVal f(void) {
    HexaVal __try0 = f_maybe();                       /* receiver 1회 평가 */
    if (!(HX_IS_ARRAY(__try0)
          && hexa_truthy(hexa_eq(
                hexa_index_get(__try0, hexa_int(0)),
                hexa_str("Ok"))                        /* "Ok" 또는 "Some" */
             ))) {
        return __try0;                                 /* 실패 tag 그대로 re-return */
    }
    HexaVal v = hexa_index_get(__try0, hexa_int(1));   /* payload unwrap */
    return f_Ok(v);
}
```

성공 tag 판정은 `"Ok"` 와 `"Some"` 둘 다 허용 (둘 다 success arm). 즉:
```c
HexaVal __t0 = hexa_index_get(__try0, hexa_int(0));
int __ok = HX_IS_ARRAY(__try0)
         && (hexa_truthy(hexa_eq(__t0, hexa_str("Ok")))
          || hexa_truthy(hexa_eq(__t0, hexa_str("Some"))));
if (!__ok) return __try0;
HexaVal v = hexa_index_get(__try0, hexa_int(1));
```

`return __try0;` 가 §3.4 의 "re-wrap = identity" — 실패 값을 그대로 통과시키므로 `Err(e)`/`None` 모두 원형 보존. (defer/arena wrap 활성 함수에서는 `gen2_stmt` 의 ReturnStmt 분기처럼 `__ret_val = __try0; goto __fn_exit;` 로 라우팅.)

#### Case B — expression-position `g(maybe()?)` / `maybe()? + 1`

stmt-expr 가 enclosing fn 을 return 못 하므로, **하위표현식의 `?` 를 statement 앞으로 hoist** (lowering pass 가 임시 변수로 끌어올림):

```hexa
let r = g(maybe()?)
```
↓
```hexa
let __t0 = maybe()?     // ← Case A 규칙으로 lower (early-return 포함)
let r = g(__t0)
```

즉 lowering 은 한 statement 안의 모든 `Try` 노드를, 등장 순서대로 그 statement 앞에 `let __tN = <try>` 로 hoist 한 뒤 원래 위치를 `__tN` 로 치환한다. 이렇게 하면 모든 `?` 가 결국 Case A (statement-position) 로 환원된다.

#### Case C — chained `a()?.b()?`

`a()?.b()?` 는 두 `Try` 노드 (`Try(a())` 와 `Try((Try(a())).b())`). hoist 순서 = inner→outer:

```hexa
let __t0 = a()?              // a() 성공 unwrap, 실패 시 early-return
let __t1 = __t0.b()?         // __t0.b() 성공 unwrap, 실패 시 early-return
// 원래 자리 = __t1
```

`?.` (QuestionDot/OptField) 와 `?` (Try) 는 별개 surface 라 공존 가능 — `a?.b()?` 도 동일 규칙으로 inner `?.` 먼저 OptField, 그 결과에 outer `?` Try 적용.

### 3.6 disambiguation — `T?` / `?.` / ternary 와의 충돌 방지

| 표면 | 토큰 | 처리 | 본 RFC 영향 |
|---|---|---|---|
| `T?` (type suffix) | `Question` in `parse_type_annotation` | **그대로** (별도 parse 경로) | 무영향 |
| `a?.b` (optional chain) | `QuestionDot` (lexer 가 별도 토큰화) | 기존 OptField arm | 무영향 (다른 토큰) |
| `c ? x : y` (ternary) | — | hexa 는 **ternary 없음** (`if`-expr 사용) | 충돌 없음 |
| `expr?` (try) | `Question` in `parse_postfix` | **신규 Try arm** | 본 RFC |

핵심 안전성: hexa 에 C-style ternary `?:` 가 **없으므로** expression position 의 `Question` 은 try 로 모호성 없이 해석 가능 (§1.1 probe 가 ternary 부재 확인). 단 lexer 가 `?.` 를 이미 `QuestionDot` 로 묶으므로 `parse_postfix` 의 새 `Question` arm 이 optional-chaining 을 가로채지 않는다.

---

## 4. 구현 phasing + acceptance probe set

### 4.1 phase plan

| phase | 변경 | 파일 | 검증 |
|---|---|---|---|
| **P1 parser** | `parse_postfix` 에 postfix `Question` → `Try{left}` arm | `self/parser.hexa` | `hexa parse` 가 §1.1 probe 를 reject 안 함 (parse OK) |
| **P2 lowering hoist** | statement 내 `Try` 노드를 `let __tN = …` 로 앞당겨 hoist (Case B/C → Case A 환원) | lowering pass (codegen 전단) | expression-position `?` 가 stmt-position 으로 환원 |
| **P3 codegen** | `Try` stmt → success-tag 분기 + early-return (§3.5 C sketch) | `self/codegen.hexa` (`gen2_stmt`) | transpile → clang → 실행 출력 일치 |
| **P4 tests** | acceptance probe set (§4.2) 를 self-host 회귀에 등록 | `inbox/tests/` | 6/6 probe PASS |
| **P5 (follow-up)** | enclosing-fn lint (§3.3) | 별도 PR | warn-only |

P1-P4 는 한 surgical PR 로 묶을 수 있음 (parser+lowering+codegen+test, codegen.hexa in-flight PR 머지 후). P5 는 분리.

### 4.2 acceptance probe set (falsifiable — canonical expected output)

각 probe = hexa source + 기대 stdout. 후속 PR 은 이 표에 대해 구현하면 됨.

| ID | probe | expected stdout | 검증 대상 |
|---|---|---|---|
| **F-D2-1** | `fn f(){let v=Ok(7)?; return Ok(v)} fn main(){println(f())}` | `[Ok, 7]` (또는 repr) | Ok unwrap + 성공 path |
| **F-D2-2** | `fn f(){let v=Err("boom")?; return Ok(v)} fn main(){println(f())}` | `[Err, boom]` | Err early-return (re-wrap identity) |
| **F-D2-3** | `fn f(){let v=Some(9)?; return Some(v)} fn main(){println(f())}` | `[Some, 9]` | Some unwrap |
| **F-D2-4** | `fn f(){let v=None?; return Some(0)} fn main(){println(f())}` | `None` | None early-return |
| **F-D2-5** | `fn f(){let v=Ok(Ok(3))?? ...}` 또는 `let r=g(Ok(5)?)` | g 결과 | expression-position hoist (Case B) |
| **F-D2-6** | self-host corpus `hexa build self/main.hexa` gen1.s ≡ gen2.s | byte-eq | fixpoint 유지 (regression 금지) |

추가 regression gate (반드시 통과):

| ID | probe | expected |
|---|---|---|
| **F-D2-R1** | `fn g(x: int?){return x}` | parse OK — `T?` type suffix 무영향 |
| **F-D2-R2** | `let y = a?.b` | parse OK — `?.` optional chain 무영향 |

#### F-D2-2 의 핵심 의미 (가장 load-bearing)

```hexa
fn f() {
    let v = Err("boom")?    // ← Err → f() 가 즉시 [Err, "boom"] return
    return Ok(v)            // ← 도달 안 함
}
```
기대: `f()` 가 `Ok(...)` 가 아니라 `[Err, boom]` 을 return. 이게 깨지면 (= `Ok(...)` 가 나오면) early-return desugar 실패로 **falsify**.

---

## 5. Open questions

| # | 질문 | 잠정 입장 |
|---|---|---|
| Q1 | `Ok`/`Some` 둘 다 success tag 로 묶을지, lane 을 컴파일타임에 구분할지 | **둘 다 success** (§3.1) — dynamic 이라 구분 불요. lane mixing 은 사용자 책임. |
| Q2 | enclosing-fn 이 `void`/non-Result 함수에서 `?` 사용 시 | v1 = 허용 (dynamic). P5 lint 가 warn. |
| Q3 | `?` payload 가 array 자체일 때 (`Ok([1,2,3])`) `HX_IS_ARRAY(__try0)` 가 inner array 와 헷갈리지 않나 | NO — `__try0` 는 항상 outer `[tag, payload]` array (2-elem). tag(index0) 가 `"Ok"`/`"Some"` 인지로 판정하므로 payload 의 타입과 무관. |
| Q4 | `From` 류 error 변환을 나중에 도입할지 | RFC 082 (trait) 랜딩 후 follow-up. v1 은 identity re-wrap. |
| Q5 | `try?` (Swift, return 대신 nil-eval) surface 추가 | RFC 081 D2 가 follow-up 으로 분류 — 본 RFC scope 밖. |
| Q6 | top-level (`main` 밖) expression 의 `?` | parse 는 허용하되 codegen 에서 "no enclosing fn to return from" diagnostic (g11 fail-loud). |

---

## 6. References

- [[rfc_081_option_result_lane]] — D2=A (Rust `?` postfix) 결정. 본 RFC 는 그 impl-design (`rfc_081_impl_b`).
- [[rfc_074_enum_multi_field_payload]] — `[tag, payload]` lowering 호환.
- PR #756 (r15-D3) — `Some/Ok/Err/None` match pattern-bind. codegen 참조: `self/codegen.hexa:7634` (Call-shape arm binding) · `7724` (gen2_match_cond tag test).
- PR #725 (r15-D4) — `.unwrap`/`.unwrap_or`/`.map`. codegen 참조: `self/codegen.hexa:4108` (`HX_IS_ARRAY` discriminant 패턴 — `?` 가 그대로 재사용).
- Rust `std::ops::Try` / RFC 0243 (`?` operator) / RFC 1859 (`?` for Option).
- Swift `try?` / optional chaining `?.`.
- lexer 토큰: `self/lexer.hexa:1176-1198` (`Question` / `QuestionDot` 이미 emit).
- parser 충돌점: `self/parser.hexa:2264` (`T?` type suffix) · `3353` (`parse_postfix`) · `3521` (`QuestionDot`/OptField).
- [[project_hexa_lang_english_only]] — 구현 후 diagnostic 은 영어 단일.

---

> Provenance: PROBE r15-D2 · authored 2026-05-24 by Claude Opus 4.7 (1M context). evidence = current main `self/native/hexa_v2` (hexa-cc) 직접 transpile (`/tmp/q_probe*.hexa`). docs-only — 컴파일러 소스 무수정. 구현은 본 명세 §4.2 acceptance probe 에 대해 별도 surgical PR.
