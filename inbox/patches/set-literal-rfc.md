# set 리터럴 design RFC

**Status**: design-level (r14 cycle 8, 2026-05-23)
**Priority**: P3 (편의 — Python 사용자 expectation)
**SSOT**: 본 RFC · 캐노니컬 비교

## 현재 동작 (probe 검증)

| 표현 | hexa 동작 |
|---|---|
| `let s = {1, 2, 3}` | parse error `unexpected token LBrace ('{')` (block expr 위치 mismatch) |
| `let s = #{1, 2, 3}` | parse error `expected Colon, got Comma` (`#{` 는 map-only · `key:value` 강제) |
| `let s = HashSet([1, 2, 3])` | parse OK (단순 Ident call 로 해석) — 그러나 stdlib 에 `HashSet` 정의 없음 → codegen/link 시 unresolved |
| `let s = Set([1, 2, 3])` | parse OK (위와 동일) — stdlib `Set` 정의도 없음 |

부수 확인:
- `self/lexer.hexa:850` `HashLBrace` 토큰 = `#{`
- `self/parser.hexa:3839` `if k == "HashLBrace"` 분기 안 `p_expect("Colon")` 무조건 호출 → key-only entry 거부
- `stdlib/` 안 `Set` / `HashSet` / `hexa_set_*` 정의 0건
- empty `{}` 는 expression position 에서 empty map literal 로 이미 special-case (parser.hexa:3826)

## 캐노니컬

| 언어 | set literal | empty | constructor |
|---|---|---|---|
| Python | `{1, 2, 3}` | `set()` (empty `{}` 는 dict) | `set(iterable)` |
| Rust | 없음 | `HashSet::new()` | `HashSet::from([1,2,3])` |
| JS | 없음 | `new Set()` | `new Set([1,2,3])` |
| Swift | `Set([1,2,3])` | `[]` (type 추론) | `Set([1,2,3])` |
| Kotlin | `setOf(1,2,3)` (fn) | `emptySet()` | `setOf(...)` |

→ Python set literal 이 가장 ergonomic — hexa 는 `#{}` 가 map 이므로 set 은 다른 sigil 또는 같은 sigil overload 필요.

## 디자인 결정 (4 옵션)

### 옵션 A: `#{}` 안에 `:` 없으면 set
```hexa
let m = #{ "a": 1, "b": 2 }    // map (현재 동작)
let s = #{ 1, 2, 3 }            // set (새 동작)
let empty = #{}                 // 모호 — type annotation 으로 disambig
```
- 장점: 동일 sigil, parser 가 first item `:` 유무로 분기 · 새 sigil 도입 무
- 단점: empty `#{}` 모호 (현재는 empty map default) · `:` lookahead 가 nested expression 가로지를 가능

### 옵션 B: 별도 `${}` sigil
```hexa
let m = #{ "a": 1 }   // map
let s = ${ 1, 2, 3 }  // set
```
- 장점: 명시적
- 단점: 새 sigil 도입 · `$` 는 PROBE r14-A `${name}` JS-style 템플릿 진단(#478)/r3 INBOX 와 충돌 가능

### 옵션 C: `set!{ ... }` macro
```hexa
let s = set!{ 1, 2, 3 }
```
- 장점: macro 인프라 재사용 (Phase 1 #462)
- 단점: macro 의존 (Phase 2 미land) · syntactic noise

### 옵션 D: stdlib constructor only (no literal)
```hexa
let s = Set::from([1, 2, 3])
```
- 장점: lang 변경 무 (stdlib 추가만)
- 단점: ergonomic 떨어짐 · 캐노니컬 Python `{}` 와 멀어짐

→ **옵션 A 권장** — `#{}` 통합, empty 는 type annotation 또는 default(empty map) 유지

## 동작 (옵션 A)

| 표현 | 의미 |
|---|---|
| `#{ "a": 1, "b": 2 }` | `Map[str, int]` |
| `#{ 1, 2, 3 }` | `Set[int]` |
| `#{} : Map[str, int]` | empty map (annotation 명시) |
| `#{} : Set[int]` | empty set (annotation 명시) |
| `#{}` (annotation 없음) | empty map (back-compat · 현 parser.hexa:3826 동작 유지) |

분기 규칙 (parser):
- `#{` 소비 후 첫 expression parse
- 다음 토큰이 `Colon` → 기존 MapLit 경로 (각 entry `:` 강제)
- 다음 토큰이 `Comma` 또는 `RBrace` → 새 SetLit 경로 (각 entry 단일 expression, `:` 거부)

## 구현 단계 (stacked PRs)

1. **LLL-1**: parser `#{ ... }` 안 첫 item 의 `Colon` lookahead 로 Map/Set fork + `SetLit` AST kind (~60줄)
2. **LLL-2**: codegen `SetLit` → `hexa_set_new()` + 각 item `hexa_set_add()` 시퀀스 (~50줄)
3. **LLL-3**: stdlib `Set[T]` 정식 type + 메서드 (`.add` · `.contains` · `.remove` · `.len` · `.union` · `.intersect` · `.iter`) 와 `runtime_core.c` `hexa_set_*` builtin (~150줄)
4. **LLL-4**: empty `#{}` 정책 결정 (back-compat 유지 vs annotation 강제) + 진단 메시지 (~30줄)

총 ~290줄, 4-PR stack.

## 영향 surface

| 파일 | 변경 |
|---|---|
| `self/parser.hexa` | `HashLBrace` 분기 안 first-item `:` 유무로 MapLit/SetLit 결정 |
| `self/codegen.hexa` (또는 `codegen_c2.hexa`) | `SetLit` AST → set ctor + add 호출 시퀀스 |
| `self/runtime.c` 또는 `runtime_core.c` | `hexa_set_new` / `hexa_set_add` / `hexa_set_contains` / `hexa_set_remove` / `hexa_set_len` 빌트인 |
| `stdlib/set.hexa` (new) | `Set[T]` type + 메서드 |
| `runtime.h` | 신규 `hexa_set_*` decl |

## 우회책 (지금)

- array + dedup 매뉴얼: `let a = [1,2,3,1,2]; /* 직접 dedup loop */`
- map 으로 흉내: `let s = #{ 1: true, 2: true, 3: true }`; key 조회로 contains
- array contains: 작은 set 은 `[1,2,3].contains(x)` 로 충분

## 관계 RFC

- r14-W macro Phase 2 (PR #493 회랑): 옵션 C `set!{}` 대안 — Phase 2 land 시 옵션 A 와 병행 가능
- r14-LL tuple type (PR #506 회랑): collection literal 디자인 패턴 (map/tuple/set 일관성)
- r14-KK Option prelude (PR #505 회랑): `set.get(k) -> Option[T]` 시그니처 (KK 머지 후) — 단 set 은 `get` 보다 `contains` 가 자연 · `.iter().next()` lane
- PROBE r14-A `${...}` 진단 (PR #478): 옵션 B `${}` sigil 도입 시 충돌 surface
