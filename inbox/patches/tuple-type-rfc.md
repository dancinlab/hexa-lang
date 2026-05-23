# tuple type `(T, U)` + literal `(1, "a")` design RFC

**Status**: design-level (r14 cycle 6, 2026-05-23)
**Priority**: P2 (no PROBE.log r3 entry — cycle 5-6 surface audit discovery)
**SSOT**: 본 RFC · 캐노니컬 비교

## 현재 상태 (실측)

문법은 이미 부분 구현. 의미론·타입 정보는 손실.

| 사이트 | 현재 동작 | 위치 |
|---|---|---|
| `let t = (1, "a")` | parse OK → AST `Tuple` | `parser.hexa:3718-3736` |
| `let t: (int, str) = (1, "a")` | parse OK (G35) → `typ = "(int, str)"` 문자열 | `parser.hexa:2122-2134` |
| `fn f() -> (int, str)` | parse OK (`parse_type_annotation` 경유) | `parser.hexa:2122` |
| `t.0` / `t.1` | parse OK → `Index(t, IntLit)` | `parser.hexa:3345-3354` |
| `for (a, b) in pairs { }` | parse OK → `ForDestructStmt` (G43) | `parser.hexa:2425-2455` |
| **`let (a, b) = pair`** | **parse error** (LParen은 `parse_let` 진입점에서 미처리; `[` 와 `{` 만 destructure) | `parser.hexa:1504-1561` |
| **codegen `Tuple`** | **`hexa_array_new()` + push** — heterogeneous **array** 로 desugar | `codegen.hexa:6564-6576` |

결과: 사용자 관점에선 "tuple 작동" 으로 보이지만, 런타임에서는 array 와 동일.
타입 어노테이션 `(T, U)` 는 코드젠 시점에 그냥 문자열로 보존되어 코어
TAG_ARRAY 로 흐른다. arity·요소 타입 검증 없음.

## 캐노니컬 (g1)

| 언어 | 타입 | 리터럴 | 인덱스 | destructure | empty |
|---|---|---|---|---|---|
| Rust | `(T, U)` | `(1, "a")` | `.0`/`.1` | `let (a, b) = t;` | `()` (unit) |
| Swift | `(T, U)` | `(1, "a")` | `t.0`/`t.1` 또는 named | `let (a, b) = t` | `Void`/`()` |
| Python | `tuple[T, U]` | `(1, "a")` | `t[0]`/`t[1]` | `a, b = t` | `()` |
| Haskell | `(T, U)` | `(1, "a")` | `fst`/`snd`/pattern | `let (a, b) = t` | `()` |
| Go | 없음 | — | — | `a, b := f()` (multi-return) | 없음 |

→ Rust 모델 권장. `.0`/`.1` accessor + destructuring. hexa 의 기존 `.N`
parser path (G35) 가 이미 Rust 와 일치.

## 디자인 결정 (3 옵션)

### 옵션 1: 현 상태 유지 (array desugar)
- 장점: 인프라 변경 0
- 단점: 타입 정보 손실, `Tuple<(int, str)>` 와 `Array<any>` 구분 불가,
  arity 미검증, type-checker 가 어떤 보장도 못 줌
- 평가: 사용자가 "tuple 이 있다" 고 믿는데 실제는 array — silent
  semantic gap. canonical 위배

### 옵션 2: built-in `Tuple` 새 TAG
- 새 `TAG_TUPLE` 런타임 + 정식 타입
- 장점: 정식, perf 좋음 (heap layout 결정 가능), 타입 정보 보존
- 단점: 런타임 코어 변경 (r14-F TAG_ENUM 패턴), 모든 폴리모픽 사이트
  업데이트 (println, equality, hashing, serialization, ...)

### 옵션 3: codegen 단계 desugar to internal struct
- 파서가 `(T, U)` 타입을 만나면 internal `__tuple_<arity>_<hash>` struct
  AST 를 생성·캐싱 (같은 시그니처 재사용)
- 리터럴 `(1, "a")` 는 `StructInit { name: "__tuple_2_<h>", ... }`
- `.0`/`.1` 은 internal `_0`/`_1` 필드로 lower
- 장점: runtime 무변경, struct codegen 재활용, equality·match·hashing
  무료 (struct 인프라 그대로), pretty-print 만 추가
- 단점: error message 에 internal name 노출 가능 (완화: type pretty-print
  에서 `__tuple_<...>` 를 `(T, U)` 로 역렌더링)
- 평가: r14-F enum codegen-emit 패턴 (#489) 과 유사. low-risk, 점진

→ **옵션 3 권장**. runtime 표면 무변경 + 정적 타입 안정성 + 작은 코어 변경.

## 영향 surface (옵션 3)

| 파일 | 변경 |
|---|---|
| `self/parser.hexa:1504` | `parse_let` 에 `LParen` 진입점 추가 → `TupleDestructLetStmt` AST |
| `self/parser.hexa:2122` | (이미) tuple 타입 어노테이션 정규화 — internal name 도 같이 emit |
| `self/parser.hexa:3718` | (이미) `Tuple` 리터럴 — codegen 힌트만 추가 |
| `self/codegen.hexa:6564` | `Tuple` → internal `__tuple_N_H` StructInit 로 lower (현재 array desugar 대체) |
| `self/codegen.hexa` (신규) | `__tuple_N_H` struct 정의 자동 생성 + 캐싱 테이블 (arity+요소타입 해시 키) |
| `self/codegen.hexa:3013` | for-in tuple destructuring — 이미 작동, struct field access 로 lower 변경 |
| `self/type_checker.hexa` (선택) | tuple arity·요소 타입 추론 + assignment 검증 |
| `self/parser.hexa:3345` | `t.0` — `Index(t, IntLit)` 유지 또는 `Field(t, "_0")` 로 normalize |
| 진단 pretty-print | `__tuple_N_H` → `(T, U, ...)` 역렌더링 (사용자 오류 메시지) |

## 구현 단계 (stacked PRs · 옵션 3)

| 단계 | 작업 | 라인 추정 |
|---|---|---|
| LL-1 | `let (a, b) = pair` parse → `TupleDestructLetStmt` AST | ~70 |
| LL-2 | codegen: tuple AST → `__tuple_N_H` StructInit + dedup table | ~150 |
| LL-3 | `t.0` codegen path: `Index(IntLit)` → field load (struct shape 알면) | ~50 |
| LL-4 | tuple destructure codegen (let + for-in 양쪽) | ~80 |
| LL-5 | pretty-print: 진단·`to_string` 에서 `__tuple_N_H` → `(T, U)` 역렌더 | ~40 |
| LL-6 | (선택) type-checker: arity·요소 타입 정합성 검증 | ~80 |

총 ~470줄, 6-PR stack (g4 분리 준수)

## Disambiguation: `()` 형

- 빈 `()` = unit type (Rust 모델) — fn return type 없음 표기
- `(x)` = parenthesized expression (현재 작동, parser.hexa:3737)
- `(x,)` = 1-tuple (Python/Rust 모델) — trailing comma 가 disambiguator
  (현재 parser 가 trailing comma 후 `RParen` 처리 검증 필요)
- `(x, y)` = 2-tuple

`(x)` vs `(x,)` 의 trailing comma 가 핵심 disambiguator — Rust 와 동일.
현재 `parser.hexa:3719-3736` 는 1개 요소 후 `,` 만나면 tuple 진입이라
trailing comma 케이스도 자연스럽게 1-tuple 로 처리됨.

## 우회책 (지금)

- 명시 struct: `struct Pair { a: int, b: str }; let p = Pair { a: 1, b: "a" }`
- 현재 tuple (array desugar): `let t = (1, "a"); println(t.0)` — **작동하지만
  타입 안정성 없음**, 어떤 사이트에서도 array 와 구분 불가
- enum payload 우회: `enum Result { Pair(int, str) }` — 정식 합 타입

## 관계 RFC

- **r14-F enum codegen-emit** (PR #489): TAG-새-타입 추가 패턴 (옵션 2 채택 시 참고)
- **r14-KK Option prelude** (sister RFC): `Option[T]` 가 tuple 처럼 small
  fixed-shape sum 타입 — prelude 정책 공유
- **exec_with_status3 3-tuple migration** (`inbox/patches/exec-with-status-3tuple-migration.md`):
  현 3-tuple = array — 본 RFC 옵션 3 채택 시 자연스럽게 internal struct
  로 마이그레이션
- **G9 array/map destructure** (`parser.hexa:1512-1561`): `let [a, b] = arr`
  와 `let {x, y} = obj` 의 LParen 변형이 본 RFC LL-1
- **G35 tuple type annotation** (`parser.hexa:2122`): 이미 land, 본 RFC 의
  타입 표면을 채워줄 의미론 미정착
- **G43 for-in tuple destructure** (`parser.hexa:2425`): 이미 land, 옵션 3
  채택 시 codegen lower path 만 갱신
