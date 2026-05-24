# Option / Some / None prelude 정책 design RFC

**Status**: design-level (PROBE round 3 INBOX, r14 cycle 6 carry, 2026-05-23)
**Priority**: P1 (r14-X postfix `?` RFC, r14-FF try-expr RFC, `.first/.nth/.pop` 모두 의존)
**SSOT**: PROBE.log.md round 3 Option/Result entry (line 34) · r14-X RFC (PR #494) · r14-F enum repr RFC (PR #489)

## 현재 상태

| 사이트 | 동작 |
|---|---|
| `let x: Option[int] = Some(42)` | 사용자 정의 enum 으로 hand-roll 필요 |
| `Some` / `None` | undeclared (자동 import 없음) |
| `.first()` / `.nth()` (PR #385) | array의 첫/n번째 element, 비어있으면 throw or void |
| `arr.pop()` (PROBE log line 63) | 빈 array → silent void (Rust None / Python IndexError 와 안 맞음) |
| `T?` 타입 suffix (PROBE log line 31) | parse OK, but `Option[T]` 미정의 — 매 파일 redeclare |

## 캐노니컬 (g1)

| 언어 | Option 모델 | prelude |
|---|---|---|
| Rust | `Option<T> { Some(T), None }` | std::prelude (자동 import) |
| Swift | `T?` syntactic sugar for `Optional<T>` | Swift StdLib (자동) |
| Kotlin | `T?` syntactic sugar for nullable type | kotlin.* (자동) |
| Haskell | `Maybe a` = `Just a \| Nothing` | Prelude (자동) |
| Go | `(T, error)` 튜플 또는 nil | 없음 (관용) |

→ Rust 모델 권장 — `Option[T]` enum + `Some(T)`/`None` 변종, 자동 prelude import.

## 디자인 결정 (3 옵션)

### 옵션 1: stdlib `Option`/`Result` + 명시 import (현재 expectation)
- 모든 hexa 소스에 `use stdlib::option::{Option, Some, None}` 명시
- 장점: 명시적, prelude 마법 없음
- 단점: boilerplate, 사용자 경험 나쁨

### 옵션 2: 자동 prelude import (Rust/Swift/Haskell 모델, 권장)
- 컴파일러가 모든 파일에 `use stdlib::option::*` 와 `use stdlib::result::*` 암묵 추가
- 사용자가 의도적 shadow 시 명시 `use my_lib::option::Some` 로 override
- 장점: ergonomic, canonical
- 단점: 마법 항목 ↑ — 학습 비용 약간

### 옵션 3: built-in keyword (Swift `?` 같은 syntactic sugar)
- `T?` = `Option[T]` desugar, `nil` = `None`, prefix `?` = `Some(x)` 인스턴스
- 장점: 가장 ergonomic
- 단점: hexa의 `nil`/`null` 정책 (PROBE log line 35 — `nil` silent void, `null` undeclared) 와 충돌

→ **옵션 2 권장** (자동 prelude). `T?` 신택스(현재 parse OK per PROBE log line 31) 와 결합.

## ABI 결정 의존

r14-F enum-to-string codegen-emit RFC (PR #489 MERGED) 결정 결과에 본 RFC 의존:
- enum tag→name 메타가 land되면 `Some(42).to_string() = "Some(42)"` 자동
- ABI 옵션 A (TAG_ENUM wrapper) 가 land되면 `Some(42) == 42` 같은 함정 사라짐

## 구현 단계 (stacked PRs)

1. **KK-1**: `stdlib/option.hexa` 정식 enum + 기본 method (`map`/`unwrap`/`unwrap_or`/`is_some`/`is_none`) (~80줄)
2. **KK-2**: codegen 자동 prelude (top-of-file injection `use stdlib::option::*; use stdlib::result::*;`) (~30줄)
3. **KK-3**: `.first/.nth/.pop` 시그니처 변경 `T → Option[T]` (~50줄, breaking — 기존 호출 사이트 마이그레이션 필요)
4. **KK-4**: r14-X postfix `?` (PR #494) 와 join — `Result::?` + `Option::?` 둘 다 작동

총 ~200-300줄, 4-PR stack.

## 영향 surface

| 파일 | 변경 |
|---|---|
| `stdlib/option.hexa` (new) | `Option[T]` enum + impl |
| `stdlib/result.hexa` (new or extended) | `Result[T,E]` enum + impl (r14-X와 짝) |
| `self/codegen.hexa` 또는 `self/main.hexa` | top-of-file auto-`use` 주입 |
| `stdlib/collection/array.hexa` | `.first/.nth/.pop` 시그니처 변경 |

## 우회책 (지금)
- 매 파일 hand-roll: `enum Option[T] { Some(T), None }`
- map/filter 등은 array 기반 우회 (Option 없이)

## 관계 RFC
- r14-X postfix `?` + Result ABI (PR #494, OPEN): Option/Result 양쪽 short-circuit
- r14-F enum to_string codegen-emit (PR #489, MERGED): Some(42).to_string() 명도
- r14-FF try-expr/finally (PR #502, OPEN): try-expr block value 가 `Option/Result` 일 때 자연
- PR #385 (MERGED): `.first/.nth/.skip` iterator aliases — KK-3 의 마이그레이션 대상

## DUP-PRECHECK 결과
- `ls inbox/patches/ | grep -iE 'prelude|some|none|option'` → 매치 없음 (clean)
- `stdlib/option.hexa` / `stdlib/result.hexa` 둘 다 부재 → RFC가 신규 파일로 정확히 scope
- 2026-05-23 inbox/patches/ 신규 commits 에 중복 RFC 없음
