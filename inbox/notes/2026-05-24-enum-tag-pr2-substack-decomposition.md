# PR-2 (TAG_ENUM breaking layer) sub-stack 분해 결정

**Status**: design + first layer landed (2026-05-24)
**SSOT**: inbox/patches/enum-to-string-codegen-emit.md · PR #553 (cycle 3 fail-honest decompose) · PR #555 (PR-1 names emit) · 본 PR (PR-2.0)
**Branch**: `fix/codegen-enum-tag-enum-pr2-2026-05-24`

## 배경

원본 3-PR 스택 권장 (`inbox/patches/enum-to-string-codegen-emit.md`):

1. **PR-1 (b)** 변종 이름 테이블 emit — additive, ~80줄 → PR #555 (실측 21줄, `#ifdef HEXA_ENUM_NAMES_TABLE` 가드)
2. **PR-2 (a)** TAG_ENUM 래퍼 + 매치 사이트 마이그레이션 — breaking, ~150줄
3. **PR-3 (c)** `_hexa_to_string_rec` TAG_ENUM 브랜치 — parity closure, ~30줄

## PR-2 단일-패스 구현이 risky 한 이유 (cycle 5 진단)

`gen2_enum_decl` 한 줄(`#define <Name>_<Variant> hexa_int(N)`) 을 `hexa_enum(type_id, variant_idx)` 형으로 바꾸는 순간 모든 enum 사용처 동시 변경:

| 영향 표면 | 변경 추정 | 위험 |
|---|---|---|
| `self/runtime.h` HexaTag enum + `HexaVal` layout (16-byte invariant) | ~5줄 | layout-shift = 전체 12.8K-LOC runtime.c 객체 호환 |
| `self/runtime_core.c` enum 동기 | ~5줄 | 동일 (3중 SSOT — runtime.h · runtime_core.c standalone · runtime.c include 경로) |
| `gen2_enum_decl` (`self/codegen.hexa:6922`) — `#define` → `hexa_enum(...)` emit | ~10줄 | 모든 enum 사용처 즉시 영향 |
| `gen2_match_cond` (`self/codegen.hexa:7048`) — EnumPath IntLit 패턴 비교 → enum 비교 | ~30줄 | RFC-020 payload variant 분기와 layout 일관성 깨질 위험 |
| `gen2_match_ternary` payload binder (`self/codegen.hexa:7152`) | ~10줄 | array form 가정 검토 |
| `hexa_eq` enum overload (`self/runtime_core.c:6071`) | ~20줄 | TAG_INT 분기로 우회되던 enum 동등성이 깨짐 |
| `_hexa_to_string_rec` TAG_ENUM 분기 (`self/runtime_core.c:5783`) | ~25줄 | PR-3 영역 침범 |

단일 PR 으로 묶으면 ~150줄 + **모든 enum 사용처 동시 회귀**. 격리 worktree 에 self-host 바이너리 없는 환경(`hexa parse` 만 가능, `hexa build` 못 함)에서 surface 검증 불가.

## sub-stack 분해 (실측 land 결정)

- **PR-2.0** (본 PR, **landed**) — defense-only / dead-branch ~57줄
  - `TAG_ENUM` slot 추가 (runtime.h + runtime_core.c, 슬롯 LAST → ABI 보존)
  - `_hexa_to_string_rec` 에 dead `case TAG_ENUM: return hexa_str("<enum>")`
  - `hexa_eq` 에 dead `case TAG_ENUM: return HX_INT eq`
  - `hexa_type_of` 에 `case TAG_ENUM: return _cached_str_enum` ("enum")
  - 어떤 emitter 도 TAG_ENUM 을 produce 안 함 → 진정 dead code → semver patch
  - **회귀 위험 0** · `clang -fsyntax-only` PASS · 기존 모든 enum 사용처 (TAG_INT-기반) 미변경

- **PR-2.1** (next) — 단일 enum (Direction) 만 emit 변경 ~30줄
  - `gen2_enum_decl` 에 `if name == "Direction"` 게이트 → `hexa_enum(type_id_hash, i)` emit
  - `gen2_match_cond` enum 패턴 분기에 TAG_ENUM 인식 추가
  - `hexa_eq` TAG_ENUM 분기를 real (type_id, variant) compare 로 강화
  - test_compact_enum.hexa 의 Direction 관련 FAIL 1-3건 닫음 (예상)

- **PR-2.2** (after) — 모든 unit-variant enum batch migrate ~50줄
  - PR-2.1 의 게이트 제거 → 전체 enum 들 (Color, Season, Weekday) TAG_ENUM 화
  - test_compact_enum.hexa FAIL 잔여 7-10건 닫음 (예상)

- **PR-3** (final) — `_hexa_to_string_rec` TAG_ENUM 분기 real-rendering ~30줄
  - PR-1 의 `__enum_<Name>_names[]` 테이블 활성화 (`#define HEXA_ENUM_NAMES_TABLE`)
  - TAG_ENUM 분기에서 `"<Type>::<Variant>"` 합성
  - test_compact_enum.hexa 14 FAIL 전부 GREEN

## 닫힌 FAIL (PR-2.0)

- **0 건** (defense layer · dead code) — 실 닫기는 PR-2.1 부터 시작

## 회귀 확인

- 변경 표면: `self/runtime.h` (+10/-1), `self/runtime_core.c` (+47/-1) — 총 ~57줄
- `clang -fsyntax-only -Iself self/runtime.c` PASS (warning 만, error 0)
- 기존 모든 TAG_INT/TAG_VALSTRUCT/TAG_MAP/...  분기 무변경
- 신규 TAG_ENUM 슬롯이 enum LAST 위치 → 기존 tag 정수값 보존 → ABI shift 없음

## 참조

- PR #553 (`fix/codegen-enum-to-string-emit-2026-05-24` — cycle 3 fail-honest 분해 inbox note)
- PR #555 (`fix/codegen-enum-names-emit-pr1-2026-05-24` — PR-1 additive names array emit)
- inbox/patches/enum-to-string-codegen-emit.md (원본 3-PR 권장)
- self/test_compact_enum.hexa (14 FAIL 회귀 게이트)
