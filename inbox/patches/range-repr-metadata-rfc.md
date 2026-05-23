# Range repr — `.start`/`.end` 메타 보존 design RFC

**Status**: design-level (PROBE round 3 INBOX line 85, r14 cycle 5 carry, 2026-05-23)
**Priority**: P2 (이미 `.contains/.len/.map/.fold/.rev`는 작동, 단 `.start`/`.end` 메타만 손실)
**SSOT**: PROBE.log.md round 3 Range entry · #351 (`.rev()`) · #385 (iterator aliases) · r14-M Swift inclusive (PR #491)

## 현재 상태

| 표현 | 동작 |
|---|---|
| `0..N` exclusive · `0..=N` inclusive · `0...N` (r14-M alias) | ✅ canonical |
| `r.contains(x)` · `r.len()` · `r.map(f)` · `r.fold` · `r.rev()` | ✅ canonical (#351, #385) |
| `.step_by(n)` · `step` 키워드 | ✅ canonical (round 3 fix) |
| **`r.start`** | ❌ undefined — range가 array로 materialize되어 메타 손실 |
| **`r.end`** | ❌ undefined |
| range를 값으로 함수에 전달 | ✅ 작동 (array 전달) |
| range descending (`5..0`) | ✅ empty (PROBE.log r3 confirmed) |

현 구현: `self/codegen.hexa:6602-6607` 에서 `Range` AST 노드를 `hexa_range_array(start, end, step, incl)` 런타임 호출로 lower → 정수 array materialize. `for i in 0..N` ForStmt 패스(`codegen.hexa:2946`)는 array 우회하는 fast path 보유.

## 캐노니컬 (g1)

| 언어 | range repr |
|---|---|
| Rust | `Range<usize> { start, end }` 구조체 · lazy iter |
| Python | `range(0, N, step)` immutable view · O(1) len |
| Kotlin | `IntRange(first, last)` · `.first` `.last` `.step` |
| Swift | `Range<Int>` struct · `.lowerBound` `.upperBound` |
| Go | `for i := range` syntax-built-in — no range value |

→ Rust/Kotlin/Swift 모델 권장: 정식 Range struct 도입, lazy iteration, 메타 필드 노출.

## 재설계 옵션 (3 선택지)

### 옵션 1: 진짜 Range struct + lazy iter
```hexa
struct Range[T] {
    start: T,
    end: T,
    inclusive: bool,
    step: T?,    // default = 1
}
```
- 모든 `0..N` 표현이 array materialize 대신 Range 인스턴스
- `for i in 0..N` 은 Range.iter() 호출
- `.start`/`.end`/`.step`/`.inclusive` 직접 접근
- 장점: O(1) construction, 큰 range도 zero allocation
- 단점: 모든 iter site/codegen 변경 (`for`, `.map`, `.fold`, `.rev`, `.contains` 다 re-route)

### 옵션 2: Range = array + 메타 사이드밴드
- 현 array 표현 유지
- 별도 메타 dict (`hexa_range_meta`) 에 `(array_id) → (start, end, step)` 저장
- `.start`/`.end` accessor가 사이드밴드 lookup
- 장점: 최소 침습
- 단점: array 가 mutate 되면 메타 stale; lookup overhead

### 옵션 3: 첫-원소/마지막-원소 derive
- `.start = r[0]` · `.end = r[r.len()-1] + (inclusive ? 0 : 1)`
- 메타 저장 없이 array 자체에서 유도
- 장점: zero new infra
- 단점: descending range는 derive 불가능 (`5..0` 빈 array); step != 1도 부정확

→ **옵션 1 권장** (정식 Range struct), 옵션 3은 single-cycle stop-gap 가능.

## 영향 surface (옵션 1 기준)

| 파일 | 변경 |
|---|---|
| `stdlib/range.hexa` (new) | Range struct 정의 + iter impl + 메타 accessor |
| `self/codegen.hexa:6602` | `..` `..=` `...` operator 결과를 array가 아닌 Range로 lower |
| `self/codegen.hexa:2946` | `for x in r` Range.iter() 호출 패턴 (현 fast path 흡수) |
| `self/codegen.hexa:3563-3570` | `.map/.fold/.rev/.contains/.len` Range method dispatch |
| `self/codegen.hexa:6435` | `arr[a..b]` slice — Range가 struct가 되어도 동작 보존 |
| 런타임 (`runtime_core.c`) | `hexa_range_iter`/`hexa_range_collect` 신규 |

## 구현 단계 (stacked PRs, 본 RFC 결정 후)

1. **GG-1**: `stdlib/range.hexa` Range struct + 기본 메서드 (~80줄)
2. **GG-2**: codegen `..` `..=` `...` operator → Range 생성 (~50줄)
3. **GG-3**: `for x in r` Range.iter() wire (~50줄)
4. **GG-4**: `.map/.fold/.rev/.contains/.len` Range method dispatch (~100줄)
5. **GG-5**: 기존 array-based 패턴 deprecation 또는 backward-compat shim (~30줄)
6. **GG-6**: PROBE.log.md 갱신 (Range entry sealed) (~10줄)

총 ~320줄, 5-6 PR stack.

## 호환성

- 기존 코드: `for i in 0..N` 는 변함없이 작동 (Range.iter() 가 array iterator 와 동일 의미)
- 새 surface: `let r = 0..N; print(r.start, r.end)` 가 메타 노출
- breaking: array-style index access `r[2]`는 새 Range struct가 `__index__` impl 가지면 보존

## 우회책 (지금)

- range를 양 끝 직접 저장: `let start = 0; let end = N; for i in start..end { ... }`
- range 사본 literal: `let r = 0..N; let r2 = r.map(|x| x)` — 사본은 array

## 관계 PR/RFC

- PR #351 (`.rev()` codegen) · PR #385 (iterator aliases)
- r14-M PR #491 (Swift `0...N` inclusive parser alias)
- r14-AA (scope leak RFC) — 무관
- r14-F PR #489 (enum repr RFC) — sum-type repr 패턴 유사
