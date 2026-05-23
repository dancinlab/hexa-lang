# `if let` / `while let` pattern binding design RFC

**Status**: design-level (r14 cycle 7, 2026-05-23)
**Priority**: P2 (`Option`/`Result` 사용 ergonomics에 직결)
**SSOT**: 본 RFC · r14-KK Option prelude (PR #505) · r14-X postfix `?` (PR #494) · r14-F enum codegen-emit (PR #489)

## 현재 동작 (probe 검증)

probe 호스트 = `/Users/ghost/.hx/bin/hexa.real` (origin/main HEAD `2ebdcfa7`)

| 표현 | hexa 동작 (측정) |
|---|---|
| `if let Some(x) = opt { print(x) }` | parse OK · codegen `ERROR: unhandled expression kind: IfLetExpr` |
| `if let Color.Red = c { ... }` (enum variant) | parse OK · codegen 동일 ERROR |
| `while let Some(x) = iter.next() { ... }` | parse error 3건 — `Let` unexpected · `LBrace` 기대 등 |
| `if Some(x) = opt { ... }` (Swift, `let` 없음) | parse error — `=` 가 unexpected |

→ 결론: parser는 `if let PATTERN = EXPR { body } [else { alt }]` G32 분기 보유 (parser.hexa L2535-2573, `IfLetExpr` AST). codegen 미구현 → 실제 사용 시 컴파일 실패. `while let` 은 parser 미지원.

## 캐노니컬

| 언어 | 신택스 | 동작 |
|---|---|---|
| Rust | `if let Pattern = expr { ... } else { ... }` | 매치 시 binding + then-branch, else-branch 있으면 unmatch 시 실행 |
| Rust | `while let Pattern = expr { ... }` | 매치하는 동안 반복 |
| Swift | `if let x = opt { use(x) }` | optional bind 한정 — non-exhaustive 패턴 |
| Swift | `if case .some(let x) = opt { ... }` | 일반 case bind |
| Kotlin | `if (x is Some) { use(x.value) }` | smart-cast, no destructure |

→ Rust 모델 권장 — `if let Pattern = expr` + `while let Pattern = expr` 모두 (general pattern, Some/None 한정 아님). hexa의 기존 `IfLetExpr` AST와 직접 일치.

## 디자인 결정

### Desugar 사양

```hexa
if let Some(x) = opt {
    use(x)
} else {
    handle_none()
}
```
desugars to:
```hexa
match opt {
    Some(x) => { use(x) }
    _ => { handle_none() }
}
```

```hexa
while let Some(x) = iter.next() {
    use(x)
}
```
desugars to:
```hexa
loop {
    match iter.next() {
        Some(x) => { use(x) }
        _ => break
    }
}
```

### 의미 결정

- `if let Pattern = expr` 만 받음 (이미 `if cond { ... }` 있어서 `let` 키워드로 disambig — parser G32 동일 전략)
- pattern은 enum variant + tuple struct + 와일드카드 모두 가능 (match_pattern 재사용)
- else-branch optional (`IfLetExpr.else_body` 빈 배열 허용)
- `if let p = e else { ... }` (no then-block, Swift `guard let` 형식) — 별도 RFC (future)
- nested `if let Some(Inner(x)) = nested_opt` — 패턴 nesting 허용 (match desugar에 위임)

### Disambiguation: 현재 `if` 신택스
- 현재: `if expr { ... }` — expr이 bool
- 추가: `if let Pattern = expr { ... }` — pattern bind (parser 이미 보유)
- Lexer: `if` 다음 `let` 토큰 peek → 새 분기 (parser.hexa L2538 이미 구현)
- 가독성: `let` 키워드가 pattern 모드 signal — 명확

## 구현 단계 (stacked PRs)

| 단계 | 작업 | 추정 |
|---|---|---|
| SS-1 | codegen `IfLetExpr` 분기 추가 — match desugar로 lowering | ~60줄 |
| SS-2 | parser `while let` 인식 + `WhileLetStmt` AST 노드 (또는 `IfLetExpr` 패턴 재사용 + WhileStmt wrap) | ~70줄 |
| SS-3 | codegen `WhileLetStmt` — `loop { match ... { p => body, _ => break } }` lowering | ~70줄 |
| SS-4 | pattern nesting / enum-variant / wildcard 테스트 추가 | ~30줄 |
| SS-5 | type_checker (선택) — pattern type vs scrutinee type 일치 검사 | ~50줄 |

총 ~280줄, 5-PR stack. SS-1 단독으로도 `if let` 가용성 unblock — 우선순위 1.

## 영향 surface

| 파일 | 변경 |
|---|---|
| `self/parser.hexa` | `parse_while_stmt` 에 `Let` peek 분기 추가 (L2500) + `WhileLetStmt` AST 신규 |
| `self/codegen_c2.hexa` | `IfLetExpr` / `WhileLetStmt` codegen 분기 — 기존 match codegen으로 desugar |
| `self/type_checker.hexa` (선택) | pattern type vs scrutinee type 일치 검사 |

## 우회책 (지금)
- `match opt { Some(x) => use(x), _ => () }`
- `if opt.is_some() { let x = opt.unwrap(); use(x) }` (Some/None prelude 의존 — r14-KK)
- chained `opt.map(|x| use(x))` (closure capture 의존)

## 관계 RFC / PR

- r14-KK Option prelude (PR #505): `Some/None` 가 prelude로 풀려야 깔끔
- r14-X postfix `?` (PR #494): 사촌 — error-prop 단축
- r14-F enum codegen-emit (PR #489): pattern bind는 enum variant 패턴 동일 (`Color.Red` 형태)
- r14-FF try-expr (PR #502): block-expression 모델 동일
- r14-AA scope leak (PR #496): `if let` pattern binding scope leak 영향 동일

## 우려사항 (mitigation)

- **side-effect single-eval**: `if let Some(x) = f()` 에서 `f()` 가 side-effect 있을 때 단 한 번만 eval 되어야 — desugar 시 `let __tmp = f()` 보존 필요 (match desugar 표준 패턴)
- **incomplete pattern silent skip**: Option은 Some/None 둘이므로 else 없으면 None case silent skip — Rust 동작과 동일. hexa도 동일 채택 권장. 단 r14-I `HEXA_STRICT_MATCH` 와 일관성 확인 필요 (`if let` 은 본질적으로 non-exhaustive)
- **`while let` 무한루프 위험**: 패턴 항상 매치하면 break 안 됨 — 사용자 책임 (Rust 동일)
- **shadow / scope**: pattern bound 이름이 then-block 안에서만 유효 — r14-AA scope leak fix 와 정합 (block-scoped)
