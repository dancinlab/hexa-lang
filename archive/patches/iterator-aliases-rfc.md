# iterator aliases `.take`/`.skip`/`.collect`/`.sum`/`.filter`/`.enumerate`/`.zip`/`.chain` RFC

**Status**: design-level + part-surgical (r14 cycle 10, 2026-05-24)
**Priority**: P2 (PR #385 후속, Rust canonical iterator API 완성)
**SSOT**: 본 RFC · PR #385 (iterator aliases first/nth/skip) · `self/codegen.hexa::gen2_method_builtin`

## 현재 동작 (probe 검증, 2026-05-24)

probe: `/Users/ghost/.cache/probe_r14_eeee/probe_*.hexa` (16 메서드).

| 메서드 | 호출 형태 | hexa 동작 | 비고 |
|---|---|---|---|
| `.take(n)` | paren | OK `[1,2,3]` | 이미 land |
| `.skip(n)` | paren | OK `[3,4,5]` | PR #385 |
| `.drop(n)` | paren | PARSE ERROR | `drop` 예약어 (소유권 의미) |
| `.filter(p)` | paren | OK `[3,4,5]` | 이미 land |
| `.sum()` | paren | OK `15` | 이미 land |
| `.product()` | paren | OK `120` | 이미 land |
| `.mean()` | paren | OK `3.0` | 이미 land |
| `.count()` | paren-no-args | BUG `not callable: tag=4 (arity=1)` | runtime 갭 (아래 §버그) |
| `.count(p)` | paren-pred | OK `3` | 이미 land |
| `.collect()` | paren | CODEGEN ERROR `unknown builtin method: collect` | 미land |
| `.enumerate()` | paren | OK (튜플 destructure 작동) | 이미 land |
| `.zip(b)` | paren | OK `[[1,a],[2,b],[3,c]]` | 이미 land |
| `.chain(b)` | paren | CODEGEN ERROR `unknown builtin method: chain` | 미land |
| `.find(p)` | paren | OK `3` | 이미 land |
| `.any(p)` | paren | OK `true` | 이미 land |
| `.all(p)` | paren | OK `true` | 이미 land |
| `.first` | field | RUNTIME `map key 'first' not found` | paren-form OK |
| `.first()` | paren | OK `1` | 이미 land |
| `.nth(n)` | paren | OK `3` | 이미 land |
| `.last()` | paren | OK `5` | 이미 land |
| `.len` | field | RUNTIME `map key 'len' not found` | paren-form OK |
| `.len()` | paren | OK `5` | 이미 land |

→ **놀라움**: PR #385 이후 16개 중 13개 paren-form 이미 작동. 진짜 갭 = 3개.

## 진짜 갭 (probe로 확인)

### 갭 1: `.collect()` 미land
- codegen `gen2_method_builtin` 에 `collect` arm 없음
- 의도: `Iterator.collect()` 가 hexa eager 모델에서는 **identity** (Vec → Vec) — `.map().collect()` 패턴의 trailing no-op
- 1-line 추가: `if method == "collect" { return obj_expr }`

### 갭 2: `.chain(b)` 미land
- codegen arm 없음
- 의도: 두 array 이어붙임 `[T]` → `[T]`
- runtime 새 fn `hexa_array_chain(a, b)` 또는 stdlib alias `concat`

### 갭 3: `.count()` no-args runtime 버그
- codegen: `hexa_count_poly(obj, hexa_void())` (line 3614-3616, 의도는 OK)
- runtime: `hexa_array_count(arr, fn)` 가 `HX_IS_VOID(fn)` 분기 없이 `hexa_call1(void, ...)` 시도 → "not callable tag=4"
- 1-line 가드: `if (HX_IS_VOID(fn)) return hexa_int(HX_ARR_LEN(arr));`

### 갭 4 (보너스): `.first`/`.len` field-form
- `xs.first` (paren 없음) → 런타임 map-lookup 시도 → "map key 'first' not found"
- 의도 모호: Rust `.first()`는 paren, JS `.length`는 field, Python `len(x)`는 free-fn
- 권고: paren-form만 canonical. field-form은 의도적 deprecation (`xs.len` 모호 — int 길이? array? map?). 별도 정리.

### 갭 5: `.drop(n)` 예약어 충돌
- `drop` 은 hexa 소유권 빌트인 (RAII move) — 메서드명으로 못 씀
- canonical = `.skip(n)` (Rust). PR #385 가 이미 alias 함. `.drop()` 영구 보류 OK.

## 캐노니컬 (Rust Iterator trait)

| 메서드 | Rust 시그니처 | hexa 매핑 |
|---|---|---|
| `.take(n)` | `&self, n -> [T]` | `hexa_array_take` |
| `.skip(n)` | `&self, n -> [T]` | `hexa_array_drop` (alias) |
| `.filter(p)` | `&self, p -> [T]` | `hexa_array_filter` |
| `.map(f)` | `&self, f -> [U]` | `hexa_array_map` |
| `.fold(i,f)` | `&self, i, f -> acc` | `hexa_array_fold` |
| `.collect()` | `&self -> Vec<T>` | **identity** (eager 모델, 이번 RFC) |
| `.sum()` | `&self -> T` | `hexa_sum` |
| `.count()` | `&self -> usize` | `hexa_count_poly(., void())` (버그 수정 필요) |
| `.enumerate()` | `&self -> [(i,T)]` | `hexa_array_enumerate` |
| `.zip(b)` | `&self, b -> [(T,U)]` | `hexa_array_zip` |
| `.chain(b)` | `&self, b -> [T]` | **새 fn** `hexa_array_chain` (이번 RFC) |
| `.find(p)` | `&self, p -> Opt[T]` | `hexa_array_find` |
| `.any(p)` | `&self, p -> bool` | `hexa_array_any` |
| `.all(p)` | `&self, p -> bool` | `hexa_array_all` |

## 디자인 결정

### 옵션 A: eager codegen-alias (PR #385 패턴) — **권고**
- `gen2_method_builtin` 에 3 arm 추가 (`collect` identity · `chain` runtime fn)
- `runtime.c::hexa_array_count` 에 void-fn 가드 추가
- 새 runtime: `hexa_array_chain(a, b)` (~15줄)
- 장점: 가벼움, PR #385 패턴, lang 무변경
- 단점: lazy 아님 — `.iter().filter().map().collect()` 가 매 단계 full materialize. perf는 동등 (이미 그렇게 동작)

### 옵션 B: Iterator trait + impl (대공사)
- 정식 `Iterator[T]` trait + `Vec[T]` impl
- lazy chain (`.iter()` 가 IterState 반환, `.collect()` 가 materialize)
- 장점: Rust canonical, lazy perf
- 단점: trait 시스템 신뢰성 의존, ~1000줄 작업, MM tier deferred RFC와 동급
- 보류: r15+ 또는 RFC 별도 작성

→ **옵션 A 채택** — 진짜 갭 3개만 닫음.

## 영향 surface

| 파일 | 변경 | 줄수 |
|---|---|---|
| `self/codegen.hexa` | `collect` arm (identity) + `chain` arm | ~6 |
| `self/runtime.c` | `hexa_array_count` void-fn 가드 + `hexa_array_chain` 신규 | ~25 |
| (선택) `stdlib/iter.hexa` | helper / 문서 | optional |

## 구현 단계 (stacked PRs)

1. **EEEE-1**: `.count()` no-args runtime 가드 (1-line + test). PR #385 보강.
2. **EEEE-2**: `.collect()` identity codegen arm (1-line + map-after-chain test).
3. **EEEE-3**: `.chain(b)` codegen + runtime (`hexa_array_chain`, ~20줄).
4. **EEEE-4** (선택): `.first`/`.len` field-form 명시 diagnostic — "use `.first()`/`.len()`".

총 ~30줄 코드 변경, 4-PR stack (마지막은 선택).

## 우회책 (지금)

- `.count()` → `.len()` (paren) 또는 `.count(|_| true)` (1-arg pred)
- `.collect()` 제거 → `xs.map(f)` 가 이미 array 반환
- `.chain(b)` → 명시 concat: `let r = a + b` (operator+) 또는 `xs.flatten()` (`[xs, ys].flatten()`)
- `.drop(n)` → `.skip(n)`
- `.first`/`.len` → 항상 paren 추가

## 관계 RFC / PR

- PR #351 `.rev()` codegen
- PR #385 iterator aliases `.first/.nth/.skip` (base, paren-form)
- r14-KK Option prelude (PR #505): `.find` 의 미래 `Option[T]` 반환 정합성
- r14-LL tuple (PR #506): `.enumerate()` 가 이미 `[i,v]` 짝 (튜플 land 시 `(i,v)`로 자연 승격)
- r14-MM chained cmp (PR #508): `xs.all(|x| 0 < x < 10)` 자연 결합

## 검증 명령

```
mkdir -p ~/.cache/probe_r14_eeee
hexa build /Users/ghost/.cache/probe_r14_eeee/probe_collect_only.hexa \
  -o /Users/ghost/.cache/probe_r14_eeee/probe_collect_only.bin
/Users/ghost/.cache/probe_r14_eeee/probe_collect_only.bin
# expect: [1, 2, 3]
```

(아래 4개 EEEE-1~4 PR 각각 별도 probe 추가.)
