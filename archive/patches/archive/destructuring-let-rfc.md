# destructuring `let { x, y }` / `let [a, b]` design RFC

**Status**: rfc-draft-deferred-2026-05-25 — design-only patch (not a fix). Promote via /inbox skill if RFC track wanted.
**Status**: design-level (PROBE r14 cycle 7, 2026-05-23)
**Priority**: P2 (편의 + ergonomic — Some/None/tuple/struct과 cross-cutting)
**SSOT**: 본 RFC · r14-LL tuple type RFC (PR #506) · r14-KK Option prelude (PR #505) · r14-SS if-let/while-let (PR #513)

## 현재 상태 (probe + grep 검증, hexa_v2 deployed 2026-05-23)

`self/parser.hexa:1499-1561` 의 `parse_let` 가 **부분 destructure** 를 이미 지원:
- 배열형 `[a, b, ...rest]` → `DestructLetStmt` AST
- map/struct형 `{x, y}` → `MapDestructLetStmt` AST

`self/codegen.hexa:3380-3416` 가 두 kind 에 대해 codegen 발행:
- `DestructLetStmt` → `hexa_array_get(tmp, i)` + 선택적 `hexa_array_drop(tmp, n)`
- `MapDestructLetStmt` → `hexa_map_get(tmp, "key")`

이름 hoisting (`_gen2_collect_lets_stmt`, line 2434-2453) 도 두 kind 처리.

그러나 **deployed `self/native/hexa_v2` 바이너리는 stale** — 모든 probe 가 clang
`use of undeclared identifier` 로 실패. hoisting 이 깨졌거나 codegen 변경이
바이너리에 반영 안 됨 (별도 regen PR 필요, 본 RFC 의 surface 가 아님).

| 표현 | parser | codegen | deployed (현재) |
|---|---|---|---|
| `let [a, b] = [1, 2]` | OK | OK (source) | FAIL — clang `undeclared 'a','b'` |
| `let [a, b, ...rest] = [1,2,3,4]` | OK | OK (source) | FAIL — 동일 |
| `let { x, y } = pt` (map literal) | OK | OK (source) | FAIL — 동일 |
| `let { x, y } = p` (struct value) | OK | OK (source) | FAIL — `hexa_map_get` 가 struct 에 안 맞음 |
| `let (a, b) = pair` | FAIL | n/a | parse error "expected ident, got LParen" |
| `let { x: alias, y } = p` | FAIL | n/a | parse error "expected ident, got Colon" |
| `let [a, _, c] = triple` | OK (literal `_`) | partial | `_` literal, skip semantic 없음 |
| `let { a: { x, y } } = obj` (nested) | FAIL | n/a | parse error (colon, 동일) |
| `match p { {x, y} => ... }` | FAIL | n/a | parse error — match arm 미지원 |
| `for (a, b) in pairs` (참고) | OK | OK | `parser.hexa:2425` 따로 처리 |

## 캐노니컬

| 언어 | array destruct | struct/object destruct | rename | rest | nested |
|---|---|---|---|---|---|
| Rust | `let [a, b, ..] = arr` | `let Point { x, y } = p` | `let Point { x: px } = p` | `..` | OK |
| JS | `let [a, b, ...rest] = arr` | `let {x, y} = p` | `let {x: px, y} = p` | `...rest` | OK |
| Python | `[a, b, *rest] = xs` | (없음 — `**kwargs`) | (없음) | `*rest` | (제한적) |
| Swift | `let (a, b) = pair` | (case let 만) | (제한적) | (제한적) | (제한적) |

→ **Rust + JS hybrid 권장** — Rust 명시성 + JS ergonomic.

## 디자인 결정 (cross-cutting)

이 RFC 가 다루는 3 사이트:

### 1. let-decl destructure

```hexa
let [a, b, c] = arr
let [a, b, ...rest] = arr   // rest = arr[2..]
let { x, y } = pt
let { x: px, y: py } = pt   // rename
let { x, .. } = pt          // 일부만 (rest 무시)
let (a, b) = pair           // tuple (r14-LL 연계)
```

### 2. fn 매개변수 destructure

```hexa
fn f({ x, y }: Point) -> int { x + y }
fn g([a, b, ...rest]: [int]) -> int { a + b + rest.len() }
```
→ ergonomic 하지만 fn 시그니처 가독성 약화. **권장: scope 제외 (별도 RFC)**.

### 3. match-arm destructure

```hexa
match shape {
    Square { width, height } => width * height
    Circle { radius } => 2 * 3.14 * radius
}
```
→ enum payload + struct field 함께. r14-HH (match-arm multi-arg enum bind) 연계.

## 옵션 비교

### 옵션 A: 풀 Rust+JS hybrid (한 번에)
- 위 모든 형식 land
- 장점: 완비
- 단점: 큰 작업 (g4 위반)

### 옵션 B: incremental (1-2 form 씩)
- 1차: `let { x, y } = struct/map` (가장 흔함, 부분구현됨)
- 2차: `let [a, b] = arr` (부분구현됨)
- 3차: rest / rename / nested
- 장점: g4 분리 · stack PR
- 단점: API 일관성 시간차

→ **옵션 B 권장** — incremental stacked PRs

## 구현 단계 (stacked PRs)

1. **UU-0**: `hexa_v2` regen 으로 현재 부분구현 활성화 — 별도 사이클 (codegen drift)
2. **UU-1**: rename `{ x: alias }` parser 확장 (~60줄)
3. **UU-2**: tuple destructure `let (a, b) = t` parser (r14-LL 연계, ~50줄)
4. **UU-3**: tuple destructure codegen (`hexa_array_get` 재사용, ~30줄)
5. **UU-4**: skip pattern `_` 의미부여 (~30줄)
6. **UU-5**: nested patterns `{a: {x, y}}` (~80줄)
7. **UU-6**: rest pattern `...rest` 검증 (이미 parser+codegen 있음, 검증 PR ~30줄)
8. **UU-7**: match-arm destructure 통합 (parser+codegen, ~100줄)
9. **UU-8**: 진단 메시지 — "destructure rhs not array/map" (~40줄)

총 ~420줄 (UU-0 제외), 8-PR stack.

## 영향 surface

| 파일 | 변경 |
|---|---|
| `self/parser.hexa` | `parse_let` 확장 — line 1504-1561 기존 코드 위에 rename/nested/tuple 추가 |
| `self/codegen.hexa` | 기존 `DestructLetStmt`/`MapDestructLetStmt` 분기 (3380, 3405) 확장 |
| `self/native/hexa_v2` | regen 필수 (deployed binary stale) |

## 의미 결정 (sticky)

- destructure 가 fail 하면? (e.g. `let [a, b] = [1]` — too few)
  - Rust: panic
  - JS: `b = undefined` (silent)
  - **권장: 에러** (g1 canonical-first — silent miscompile 회피)
- rest 가 empty 면?
  - `let [a, b, ...rest] = [1, 2]` → `rest = []` (Rust/JS 동일)
- struct field 빠뜨리면?
  - `let { x } = pt` (y 없음) → **권장 OK** (Rust 동일, 일부만 binding)
- `_` 자리에 값이 있으면?
  - **권장: 평가는 하되 무시** (Rust 동일, side-effect 보존)

## 우회책 (지금)

- 명시 field access: `let x = p.x; let y = p.y`
- 명시 index: `let a = arr[0]; let b = arr[1]`
- tuple 은 array materialize 후 index (r14-LL finding)

## 관계 RFC / PR

- **r14-LL** tuple type RFC (PR #506): `let (a, b) = pair` 가 tuple destructure
- **r14-KK** Option prelude (PR #505): `let Some(x) = opt` 와 사촌 (`if let` 도)
- **r14-SS** if-let / while-let (PR #513): pattern bind 의 conditional 형태
- **r14-HH** match-arm bind (cycle 6 in-flight): match arm 안 destructure
- **G8** spread operator: rest `...rest` 와 토큰 공유 (parser.hexa:2727)

## 참고

- `for (a, b) in pairs { ... }` 는 이미 작동 (parser.hexa:2420-2454, G43)
  → tuple destructure 가 let 컨텍스트에 부재한 것은 **표면 비대칭**
- `DestructLetStmt`/`MapDestructLetStmt` 는 PROBE r7 시 land 된 부분구현
  → 본 RFC 는 그 기반 위에 표면을 확장
