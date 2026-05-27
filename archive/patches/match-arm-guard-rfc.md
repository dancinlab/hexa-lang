# match arm guard `if cond` design RFC

**Status**: probe-verified — partial gap (r14 cycle 9, 2026-05-23)
**Priority**: P2 — PR #379 + #412 base 위 잔여 한 gap (EnumPath payload binder + guard 가 guard에서 scope-out)
**SSOT**: 본 RFC · PR #379 (`41dd039a` guard incorporation) · PR #412 (`0efe62a3` bare-Ident binding) · 캐노니컬 비교

## 현재 동작 (probe 9 cases verify)

PR #379 가 `arm.cond` 를 `&& hexa_truthy(<guard>)` 로 incorporation. PR #412 가
bare-Ident binder 의 guard scope 처리. EnumPath binder 의 guard scope 는 별도.

| 케이스 | 신택스 | 결과 | 비고 |
|---|---|---|---|
| C: literal + guard | `5 if false -> "wrong"` | PASS ("right") | PR #379 메인 falsifier |
| D: wildcard + guard | `_ if v > 100 -> "big"` | PASS | wildcard 단락 `!has_guard` 가드됨 |
| E: bare-Ident binder + guard | `n if n > 100 -> "big"` | PASS | PR #412 binder + guard scope 처리됨 |
| F: compound guard | `n if n > 0 && n < 100 -> ...` | PASS | `&&` `\|\|` 둘 다 |
| G: EnumPath payload binder + guard | `Result::Some(n) if n > 0 ->` | **FAIL** | guard `n` undeclared (codegen.hexa:7106-7111 gap) |
| H: side effect in guard | `n if check(n) ->` | PASS | arm 당 1 회 평가 (Rust 동일) |
| I: 다중 arm 같은 binder 다른 guard | `n if n > 100 / n > 10 / n > 0` | PASS | 순차 시도 정상 |
| J: EnumPath `_` placeholder + guard | `Result::Some(_) if threshold > 0` | PASS | binder 미참조 — scope 무관 |

→ **8/9 PASS, 1/9 FAIL** = EnumPath 페이로드 바인더가 guard 식에서 참조될 때
codegen 이 stmt-expr binding 을 arm value 에는 두지만 guard 에는 두지 않음.

## 캐노니컬

| 언어 | 신택스 | exhaustive 영향 |
|---|---|---|
| Rust | `pattern if expr =>` | guard false 면 다음 arm, exhaustiveness 못 함 |
| Swift | `case let .some(n) where n > 0:` | 동일 |
| Haskell | `\| guard ->` | 동일 |
| Scala | `case Some(n) if n > 0 =>` | 동일 |

→ hexa = Rust 신택스 (`if cond`) 이미 채택, `=>` 대신 `->` 만 다름.

## 의미 결정 (현재 land 상태)

- Guard 가 false → 다음 arm 시도 (Rust 동일)
- Guard 안 binding 참조: 해당 arm pattern binding 가시 (binder 종류에 따라 일부 broken — Gap G)
- Guard side effect: 허용 (per-arm 1 회, probe H 확인)
- Exhaustiveness: guard 가 있으면 non-exhaustive (Rust 동일) — PR #453 warn-path 가 이 케이스 다룸

## Gap G — EnumPath payload binder + guard scope

### Repro

```hexa
enum Result { Some(i64), None }
fn classify(r: Result) -> str {
    return match r {
        Result::Some(n) if n > 0 -> "positive",
        Result::Some(_) -> "non-positive",
        Result::None -> "absent"
    }
}
```

### Diagnostic

clang `error: use of undeclared identifier 'n'` — guard `hexa_cmp_gt(n, 0)`
emitted 위치에 `n` 바인딩 stmt-expr 없음.

### Root cause (`self/codegen.hexa:7102-7140`)

```
// L7106-7111: EnumPath 페이로드 바인더는 arm VALUE 에만 stmt-expr 로 감싸짐
if pat.kind == "EnumPath" && pat.left.kind == "Ident" {
    val = "({ HexaVal n = hexa_index_get(scrutinee, 1); (val); })"
}
// L7132-7139: guard 는 bare-Ident 바인더만 stmt-expr 로 감싸짐 (`_bind_name` 게이트)
if _has_guard {
    let _guard_c = gen2_expr(_guard)
    if len(_bind_name) > 0 {  // ← bare-Ident only
        _guard_c = "({ HexaVal n = scrutinee; (_guard_c); })"
    }
    cond = "(... && hexa_truthy(" + _guard_c + "))"
}
```

EnumPath 바인더 경로가 guard wrapping 에 누락. 대칭 fix = guard wrapping
블록에 EnumPath 케이스 추가.

### 제안 surgical

```
// 추가 block (line ~7138 후):
if pat.kind == "EnumPath" && pat.left.kind == "Ident" && pat.left.name != "_" {
    let _bn = pat.left.name
    _guard_c = "({ HexaVal " + _hexa_mangle_ident(_bn)
             + " = hexa_index_get(" + scrutinee_c + ", hexa_int(1)); ("
             + _guard_c + "); })"
}
```

~6 줄 surgical, codegen.hexa 1 사이트. regen 필요.

## 잔여 미커버 케이스

PR #379 의 silent-miscompile 헤드라인은 닫혔으나 표면 확장에는 잔여:

- 다중 페이로드 바인더 + guard: `Pair(a, b) if a > b ->` — r14-HH match-arm
  multi-arg payload (#516) 와 cross. multi-arg payload 자체가 별도 RFC.
- nested 패턴 + guard: `Some(Point{x, y}) if x > y` — 패턴 grammar gap (round 5
  `let-immutability-and-match-exhaustiveness-unenforced.md` 의 sibling).
- `@`-binding + guard: `name @ Some(n) if n > 0` — `@`-binding 자체 미구현.

본 RFC scope = 단일-바인더 EnumPath payload + guard 만.

## 구현 단계

1. **ZZZ-1**: `self/codegen.hexa:7132-7139` 가드 wrapping 에 EnumPath 케이스
   추가 (~6 줄). regen via `hexa cc --regen` 또는 pool ubu-2 offload.
   probe G 가 falsifier — PASS 시 closed.
2. (선택) **ZZZ-2**: type_check 단계에서 guard 식 bool 확인 — 현재 `hexa_truthy`
   가 런타임 좌강제하므로 클래스-1 silent 없음. priority P4.

총 ~10 줄, 1 PR.

## 영향 surface

| 파일 | 변경 |
|---|---|
| `self/codegen.hexa` | gen2_match_ternary guard wrapping EnumPath 케이스 추가 |
| `self/native/hexa_v2` (regen) | 빌트인 활성화 |

## 우회책 (현재 — fix 전)

- payload 를 `_` 로 받고 별도 변수로 추출:
  ```hexa
  let payload = if r is Result::Some { ... } else { 0 }
  match r {
      Result::Some(_) if payload > 0 -> "positive",
      ...
  }
  ```
- 또는 `if`/`else if` 사슬로 풀어쓰기.

## 관계 RFC / PR

- PR #379 (`41dd039a` match-arm guard incorporation): 본 RFC base
- PR #412 (`0efe62a3` bare-Ident binding-pattern arm): bare-Ident + guard 짝
- PR #380 (OR-pattern + Range pattern): match codegen 기반
- PR #453 (immutable-let warn + non-exhaustive match warn): exhaustiveness path
- r14-HH match-arm multi-arg payload (PR #516): multi-arg payload 자체
- r14-SS if-let (PR #513): pattern + cond 인접 surface
- canonical-audit-round-5-consolidated.md: round 5 헤드라인 silent-miscompile
  3건 닫힘 명시. 본 RFC = 그 후속 표면 gap.

## DUP-PRECHECK

- `ls inbox/patches/ | grep -iE 'match.*guard|arm.*if|where.*clause'` → 0 hit
- `git log origin/main --since=2026-05-23 -- inbox/patches/` → 0 hit
- `git log origin/main --grep='match-arm guard'` → 41dd039a (#379, surgical fix)

중복 없음.
