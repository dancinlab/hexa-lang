# pipe operator `|>` (F#/Elixir) design RFC

**Status**: design-level (r14 cycle 8, 2026-05-23)
**Priority**: P3 (편의 기능 — 데이터 처리 pipeline 가독성)
**SSOT**: 본 RFC · F#/Elixir 캐노니컬

## 현재 동작 (probe 검증)

probe 호스트 = `/Users/ghost/.hx/bin/hexa` (origin/main, r14 시점)

| 표현 | hexa 동작 (측정) |
|---|---|
| `let r = 5 \|> add_one \|> double` | parse error: `unexpected token Gt ('>')` × 2 |
| `let r = [1,2,3] \|> sum` | parse error: `unexpected token Gt ('>')` |
| `let r = 5 \|> add(2, _)` placeholder | parse error: `unexpected token Gt ('>')` |
| `let r = x \| y > 0` (space 구분, bitwise OR + 비교) | OK — 기존 BitOr/Gt 정상 |

→ lexer는 `|>` 를 분해 토큰 `BitOr` + `Gt` 로 산출 (self/lexer.hexa L685-700,
`ch == '|'` 분기에 `>` 페어 없음). parser는 `parse_pipe` 분기와 `"Pipe"` 토큰 분기를
이미 보유하나 (self/parser.hexa L2830-2845 `parse_pipe`, L3575 token-class) —
lexer가 `Pipe` 를 절대 emit 하지 않아 **현재 dead branch**. 즉 backend 절반 구현 +
frontend 미구현 상태.

## 캐노니컬

| 언어 | 신택스 | 의미 | 부분 적용 |
|---|---|---|---|
| F# | `x \|> f` ≡ `f x` | left-to-right 함수 적용 | curry 자연 |
| Elixir | `x \|> f()` ≡ `f(x)` (첫 인자) | left-to-right · 첫 인자 implicit | 추가 인자 명시 |
| OCaml | `x \|> f` ≡ `f x` | F# 동일 | curry |
| Hack | `x \|> f($$)` | `$$` placeholder | 명시 |
| JS proposal | `x \|> f(%)` | `%` placeholder (stage-2 stalled) | 명시 |

→ Elixir 모델 권장 (첫 인자 implicit) — hexa는 curry 없으므로 F#/OCaml
모델은 직접 적용 불가.

## 디자인 결정

### 옵션 A: Elixir-style implicit first-arg
```hexa
data |> filter(pred) |> map(fn) |> reduce(op, init)
// equiv:
reduce(map(filter(data, pred), fn), op, init)
```
- `x |> f(a, b)` → `f(x, a, b)` (x 를 첫 인자에 prepend)
- 장점: 가장 일반적, 사용자 학습 비용 낮음
- 단점: 'first arg' 컨벤션 의존 — 일부 fn 은 last-arg 가 더 자연

### 옵션 B: Hack/JS-style `$$` / `_` placeholder
```hexa
data |> filter($$, pred) |> map(fn, $$)
```
- 명시 위치, 어느 인자 자리도 가능
- 장점: 유연
- 단점: boilerplate (`$$` 매번)

### 옵션 C: hybrid (default first-arg + opt placeholder)
- 기본 implicit first-arg
- `|>` 다음에 명시 `_` 있으면 그 위치
- 장점: 양쪽 최선
- 단점: parser 복잡 (`_` 가 이미 wildcard pattern 으로 사용 중 — 충돌 검토 필요)

→ **옵션 A 권장** (Elixir 정신, 단순 + parse_pipe 기 구현된 트리에 맞음).
`_` placeholder 는 future RFC.

## 우선순위 / 결합 규칙

- `|>` 가장 낮은 binary 우선순위 (assignment 보다 약간 높음 = `parse_pipe`
  현재 위치, parser L2798-L2845 "Level 5.0a" 와 정확히 일치)
- left-associative: `a |> b |> c` ≡ `(a |> b) |> c`
- `|` (BitOr) + `>` (Gt) disambig: lexer 에서 `|` 다음 `>` 이고 그 다음이
  `=` 아닌 경우 `Pipe` 토큰 (`|>=` 는 별도 — 일단 reserve 안 함)
- 기존 `x | y > 0` (bitwise OR + 비교, space 사이) 는 영향 없음 — 토큰화
  단계에서 `|` 다음 char 가 `>` 면서 공백 없을 때만 `Pipe`

## 구현 단계 (stacked PRs)

1. **KKK-1**: lexer `|>` 토큰 인식 (`Pipe` kind, value `"|>"`) — self/lexer.hexa
   L685-700 `ch == '|'` 분기 확장 (~10줄)
2. **KKK-2**: parser pipe-expr AST + dead-code 검증 — 현 `parse_pipe` 은
   BinOp 로 emit, codegen 미인식 → 새 AST `PipeExpr` 또는 BinOp `op:"|>"`
   분기 추가 (~30줄)
3. **KKK-3**: codegen `PipeExpr` → first-arg prepend desugar — call-site 가
   `f(args...)` 면 `f(lhs, args...)` 로 변환 (~50줄)
4. **KKK-4**: regression — 기존 `|` (BitOr) 무변경 확인 + pipe positive
   tests (~20줄 테스트)

총 ~110줄, 4-PR stack.

## 영향 surface

| 파일 | 변경 |
|---|---|
| `self/lexer.hexa` | `|` 분기 — 다음 char `>` 일 때 `Pipe` 토큰 (~10줄) |
| `self/parser.hexa` | `parse_pipe` 본체는 이미 존재 — BinOp 표현 유지 또는 PipeExpr AST 도입 |
| `self/codegen.hexa` (codegen_c2 등) | `PipeExpr` / `op:"|>"` 분기 — first-arg prepend desugar |

## 우회책 (지금)

- 중첩 호출: `reduce(map(filter(data, pred), fn), op, init)` (가독성 낮음)
- 중간 변수: `let a = filter(data, pred); let b = map(a, fn); let r = reduce(b, op, init)`
- 메서드 체인 (object-style): `data.filter(pred).map(fn).reduce(op, init)` (iterator
  alias 지원 시)

## 관계 RFC / PR

- r14-FF try-expr (PR #502): try-block 안에서 pipe 사용 자연
- iterator aliases (#385 / #351): pipe 와 결합 자연 (`xs |> filter(_) |> map(_)`)
- r14-X postfix `?` (PR #494): `op() |> chain |> ?` 결합 결정 필요 (future RFC)
- chained comparison r14-MM (PR #508): 무관 (operator class 다름, BitOr/Gt 충돌
  의 lexer 분기는 별 케이스)
- r14-SS if-let/while-let (PR #513): 무관 (statement-level pattern)
