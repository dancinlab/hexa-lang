# postfix `?` + Result ABI 디자인 RFC

**Status**: rfc-draft-deferred-2026-05-25 — design-only patch (not a fix). Promote via /inbox skill if RFC track wanted.
**Status**: design-level (PROBE round 3 INBOX, r14 cycle 4 carry-over, 2026-05-23)
**Priority**: P1 (블로커: 에러 전파 정준 부재 — 현재 `throw` + `try/catch` 만)
**SSOT**: PROBE.log.md round 3 Option/Result entry (line 30-32) · self/parser.hexa try/catch (line 796)

## 현재 상태

| 메커니즘 | 동작 |
|---|---|
| `throw "msg"` + `try/catch` | 작동 (PROBE.log r3 canonical) |
| `panic("msg")` | catch 안 됨 (panic 채널 별도, 의미론 미결정) |
| `T?` 옵셔널 타입 suffix | parse OK (self/parser.hexa:2139 `Question` token) |
| `??` null-coalesce | canonical |
| `?` postfix error-prop | **parse error** (본 RFC 주제) |
| `Some/None/Ok/Err` prelude | **없음 — 매-파일 hand-roll** (sibling RFC 후보) |

## 캐노니컬 (g1)

- Rust: `Result<T, E>` + `Option<T>` sum type, `?` postfix 양쪽 작동
- Swift: `try?` prefix + `Result<T, E>`
- Go: 명시 `if err != nil { return err }` — 정준 아니지만 다른 모델
- Python: 예외 전파 (try/except)

권장: Rust 모델 채택. `Result[T, E]` sum type + `?` 단축 desugar.

## ABI 결정 (3 선택지)

### 옵션 A: enum 기반 (PROBE.log r3 #1 작동 확인)

```hexa
enum Result[T, E] {
    Ok(T),
    Err(E)
}
```

- 장점: 기존 enum 디스패치 그대로 사용
- 단점: r14-F STOP 보고서가 지적한 enum unit-variant 표현 문제와 얽힘 (Color::Red → hexa_int(0) 정수화)

### 옵션 B: 명시 struct + tag field

```hexa
struct Result[T, E] { ok: bool, val: T, err: E }
```

- 장점: ABI 명확, hexa_eq 단순
- 단점: 항상 T+E 둘 다 영역 할당 (낭비)

### 옵션 C: discriminated union 새 TAG

새 `TAG_RESULT` 런타임 태그 + 16-byte HexaVal 내 `{tag, ok_bit, payload_ptr}` 패킹

- 장점: 0-cost (단일 word), 빠른 분기
- 단점: 런타임 코어 변경 (큰 작업, r14-F enum-emit RFC와 겹침)

→ **옵션 A 권장** (enum + r14-F enum-emit RFC와 함께 closure)

## postfix `?` desugar 사양

```hexa
let x = some_op()?
```

desugars to:

```hexa
let x = match some_op() {
    Ok(v) => v
    Err(e) => return Err(e)
}
```

세부:
- `?` 호출 위치는 항상 `Result`-반환 함수 안이어야 (type-check error otherwise)
- `e.into()` 형 Rust 자동변환은 Phase 2 (당장은 동일 E 타입만)
- panic 변환 `?` 안 (panic 채널 별도)

## 영향 surface

| 파일 | 변경 |
|---|---|
| `self/lexer.hexa` | `Question` token 이미 있음 (line 728/815/843) — 변경 불요 |
| `self/parser.hexa` | postfix expr 위치에서 `Question` 분기 → desugar AST emit |
| `self/codegen.hexa` | desugared match + early-return 일반 codegen 통과 |
| `stdlib/result.hexa` | `Result[T,E]`/`Ok`/`Err` 정준 enum + impl |
| `stdlib/option.hexa` | `Option[T]`/`Some`/`None` 정준 enum (sibling, prelude RFC 후보) |

## 구현 단계 (stacked PRs)

1. **X-1**: stdlib `Result` + `Option` enum 정준 정의 (~50줄)
2. **X-2**: parser postfix-expr 위치 `?` 인식 + desugar (~80줄)
3. **X-3**: type-check: `?` 위치 함수 반환 타입 확인 (~50줄)
4. **X-4**: prelude 자동 import 결정 (`use stdlib::result::*;` auto?)

총 ~200-300줄, 3-4 PR stack.

## panic 채널 관계 (PROBE.log r3 line 31)

- `panic("msg")`는 try/catch도 recover도 못 잡음 — 별도 abort 채널
- `?` 와 `try/catch`는 **recoverable error** (`throw` + `Result::Err`)
- `panic` 은 **unrecoverable** (process death, Go-style)
- 이 분리는 별도 RFC 권장 (panic 채널 의미론) — 본 RFC는 panic 미포함 명시

## 우회책 (지금)

- 명시 match: `match op() { Ok(v) => use(v); Err(e) => return Err(e) }`
- try/throw: `try { let v = op(); ... } catch (e) { return Err(e) }` — try/catch는 작동 (PROBE.log r3 confirmed)

## 참조

- PROBE.log.md round 3 Option/Result entry (line 30-32) + r14 next-list (line 211)
- self/parser.hexa:2139 (`Question` token, 현재 `T?` suffix 만)
- self/lexer.hexa:728/815/843 (`Question` 토큰화 완료)
- sibling: `inbox/patches/enum-to-string-codegen-emit.md` (r14-F STOP RFC, enum unit-variant repr)
- Rust Reference: `expressions/operator-expr.html#the-question-mark-operator`
