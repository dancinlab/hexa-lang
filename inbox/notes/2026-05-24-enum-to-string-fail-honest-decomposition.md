# enum `to_string` codegen-emit P2 — fail-honest 분해 노트

**Date**: 2026-05-24
**Status**: investigation complete · fix DEFERRED (>200줄, 단일 surgical 불가능)
**SSOT**: `inbox/patches/enum-to-string-codegen-emit.md` (P2 RFC, 2026-05-23 filed)
**Trigger**: 사용자 요청 — codegen-only surgical fix 시도 → architecture-level 필요 확정
**Worktree**: agent-abdbdc1f2ec3eac56 (branch `worktree-agent-abdbdc1f2ec3eac56`)

## 결론

`self/test_compact_enum.hexa` 14 FAIL을 닫는 단일 surgical PR은 **불가능**. RFC 가 명시한
3-PR 스택 (a)+(b)+(c) 전부 필요. 결합 크기 ~260줄로 사용자 제약 (>200줄 시 fail-honest 분해) 초과.

## 14 FAIL 트리거 패턴 분석

전부 **변수/배열-element 경유 `to_string(enum)`** — 컴파일 타임 fold 불가능 (모두 위치 indirect):

| 패턴 | 카운트 | 예 |
|---|---|---|
| `let d = Direction::Left; to_string(d)` | 9 | L67-68 · L86-88 · L110-113 · L134-135 |
| `to_string(arr[i])` | 3 | L194-196 (`colors[0..3]`) |
| `same_direction(a, b)` 안에서 `to_string(a)` (fn arg) | 2 | L184-185 (true case는 별개) |

→ codegen이 `to_string(<expr>)` 의 `<expr>` 의 enum 출처를 정적으로 알 길이 없음 (hexa-lang
runtime tag 가 unit-variant 를 `hexa_int(N)` 로만 표현하기 때문).

## 왜 단일 PR 불가능

런타임 enum 식별을 위해서는 **3-surface 전부** 필요:

### (a) `TAG_ENUM` 래퍼 (~150줄)

- `self/runtime_core.c:909` `enum hexa_tag` 에 `TAG_ENUM` 추가
- `HexaVal` 16-byte layout — enum payload (type_id + variant_tag) 새 분기
- `hexa_eq` (L?? — TAG_ENUM × TAG_ENUM overload) 추가
- `self/codegen.hexa:6959` `#define <Name>_<Var> hexa_int(N)` → `hexa_enum(<type_id>, N)` 로 교체
- `self/codegen.hexa:7095` `gen2_match_cond` enum-pattern 분기 (현재 `IntLit` 매치 경로
  로 untyped 정수 비교)

### (b) per-enum tag→name 테이블 emit (~80줄)

- `self/codegen.hexa:6922` `gen2_enum_decl` 에 `static const char* __enum_<Name>_names[]`
  배열 + count emit
- 런타임 registry (`hexa_register_enum_type(const char*, const char**, int)`) 새 함수
- module-init 시 등록 호출 emit

### (c) `_hexa_to_string_rec` TAG_ENUM 브랜치 (~30줄)

- `self/runtime_core.c:5786` switch 에 `case TAG_ENUM:` 추가
- (type_id, variant_tag) → registry lookup → `"<Type>::<Var>"` 합성

## 시도하지 않은 길

### 컴파일 타임 fold (`to_string(Color::Red)` → `hexa_str("Color::Red")`)

- gen2_expr 에서 Call arg=EnumPath 패턴을 매치하면 가능
- **그러나 14 FAIL 중 0건 closure** — 위 표 보다시피 직접 enum literal 인자는 0건, 전부
  변수/배열 경유
- 따라서 ROI 0 — 변경 없이 deferred

### codegen-only path (RFC (a) 미적용, (b)+(c) 만)

- (a) 없으면 런타임이 어떤 `hexa_int(N)` 이 enum 출신인지 알 길이 없음 → registry lookup
  hook 걸 자리가 없음
- (b)+(c) 만 land 하는 옵션은 **dead code** (호출되지 않는 registry · 사용되지 않는 names
  배열) — 가치 음수, 빌드 시간만 증가

## 권장 분해 시퀀스 (future cycle)

3-PR stack, RFC 권장 순서 그대로:

1. **PR-1**: (b) — codegen names emit + runtime registry. additive, 0 회귀. ~80줄.
2. **PR-2**: (a) — `TAG_ENUM` + match 분기 마이그레이션. **semver-minor breaking**. ~150줄.
   1. selftest 회귀 위험 가장 큼 — 모든 enum 매치 사이트 재-검증 필요
3. **PR-3**: (c) — `_hexa_to_string_rec` TAG_ENUM case + 14 FAIL → GREEN. ~30줄.

각 PR `--base` 를 이전 PR 로 stacked. gh-stack 또는 manual `gh pr create --base`.

## 우회책 (현재 hexa-lang 사용자 권장)

```hexa
fn color_name(c: Color) -> String {
    match c {
        Color::Red => "Red",
        Color::Green => "Green",
        Color::Blue => "Blue",
    }
}
```

`test_compact_enum.hexa` 같은 generic 테스트는 14 FAIL 유지. 사용자 코드는 위 명시 매치
패턴 사용.

## 참조

- RFC: `inbox/patches/enum-to-string-codegen-emit.md` (P2, 2026-05-23)
- Test: `self/test_compact_enum.hexa` (14 FAIL 회귀 게이트)
- 관련 closure: `[[project_hexa_lang_enum_payload_works]]` (payload variant 단일-필드 이미 작동)
- Wipe-guard 주의: `runtime_core.c` + `codegen.hexa` 변경은 deploy-regen 사이클이 wipe 가능
  ([[feedback_runtime_c_deploy_regen_wipe]] · `[[reference_runtime_c_shadow_build_self_fix_2026_05_21]]`)
