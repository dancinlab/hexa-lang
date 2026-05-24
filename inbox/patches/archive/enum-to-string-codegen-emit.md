# enum `to_string` 변종-이름 codegen-emit RFC

**Status**: resolved-PR#582+#589-2026-05-25 — enum-to-string codegen stack closed (TAG_ENUM single + all-unit-variant); ae8415ae direct fix
**Status**: design-level (PROBE r14-F STOP follow-up, 2026-05-23)
**Priority**: P2 (silent miscompile cluster — `to_string` 의미 손실)
**SSOT**: PROBE.log.md round 3 enum 엔트리 · `self/test_compact_enum.hexa` (14 FAIL 기록)

## 현재 deviation

| 사이트 | 동작 |
|---|---|
| `Color::Red` codegen (`self/codegen.hexa:6833` `gen2_enum_decl`) | `#define Color_Red hexa_int(0)` |
| 런타임 표현 | `HexaVal { tag = TAG_INT, i = 0 }` (그냥 정수) |
| `to_string(Color::Red)` (`self/runtime_core.c:5722` TAG_INT 분기) | `"0"` (tag 노출, 변종 이름 손실) |
| `Color::Red == 0` | literally `true` (정보 부족으로 분간 불가) |

cycle 2 r14-F surgical fix attempt = **STOP** — 수술이 아니라 아키텍처. 이유: unit variant 가 그저 `hexa_int(N)` 라 런타임에서 enum 타입을 식별할 메타가 전혀 없음. `_enum_names` (`self/codegen.hexa:7667`) 는 build-time 식별자 집합일 뿐 (변종 이름 미보존, 런타임 노출 미연결).

## 캐노니컬 (g1)

- Rust `Debug`: `"Color::Red"`
- Swift: `Color.red` 또는 `"red"`
- Python (`enum.Enum.__str__`): `"Color.RED"`

셋 다 **변종 이름을 유지**. 현재 hexa-lang 만 tag 정수를 노출.

## 진짜 fix 구성 (3-surface)

### (a) 새 `TAG_ENUM` 래퍼 + 메타 포인터

- `HexaVal` 16-byte layout 에 `TAG_ENUM` 추가 (또는 enum 전용 wrapped form: type_id + variant_tag)
- 영향: `hexa_eq(Color::Red, Color_Red)` 빠른 정수 비교 → enum 동등성 prim 필요 (`TAG_ENUM == TAG_ENUM && type_id 일치 && variant 일치`)
- 영향 사이트:
  - `self/codegen.hexa:6959` `gen2_match_cond` — `IntLit` 패턴 비교가 enum 에는 안 맞아져야 함 (또는 enum 패턴 전용 분기)
  - `self/codegen.hexa:6902` `gen2_match_stmt` — payload variant 코드는 이미 array form 사용 중 (RFC-020 A4), unit variant 만 정수로 남음 → 정합 필요

### (b) per-enum tag→name 테이블 emit

```c
static const char* __enum_Color_names[] = { "Red", "Green", "Blue" };
static const int   __enum_Color_count   = 3;
```

- `gen2_enum_decl` (`self/codegen.hexa:6833`) 에 추가 emit
- 등록 함수 `hexa_register_enum_type("Color", names, count)` 런타임 init
  - 또는 `_enum_names_add` (`self/codegen.hexa:7669`) 를 build-time 만이 아닌 **runtime registry** 로 확장 (이름 + 변종 배열)
- 이 표면은 **무위험 (additive)** — TAG_ENUM 도입 전에도 land 가능

### (c) `_hexa_to_string_rec` TAG_ENUM 브랜치

- `self/runtime_core.c:5718` switch 에 새 case 추가
- (type_id, variant_tag) lookup → `"<TypeName>::<VariantName>"`
- fallback `"<TypeName>::?<tag-N>"` (defense, 미등록 enum)

## 포맷 결정 (블로커)

| 후보 | 예 | 출처 | 한 줄 평가 |
|---|---|---|---|
| Bare | `"Red"` | Python `enum.Enum.__str__` 의 `.name` 부분 | 동음이의 변종 (`Color::Red` vs `Severity::Red`) 충돌 |
| Qualified | `"Color::Red"` | Rust `Debug` 기본 + `self/test_compact_enum.hexa` 기존 기대 | 명확 · 기존 테스트와 일치 |
| Dotted | `"Color.Red"` | Swift 풍 | hexa surface (`Color::Red`) 와 불일치 |

→ **Qualified `"Color::Red"`** 권장 (Rust canonical + `self/test_compact_enum.hexa` 14 FAIL 즉시 GREEN).

## 우회책 (지금 사용 가능)

- 직접 변종 매치:

  ```hexa
  fn color_name(c: Color) -> String {
      match c {
          Color::Red => "Red",
          Color::Green => "Green",
          Color::Blue => "Blue",
      }
  }
  ```

- `@derive` to_string impl 가 있다면 명시적 사용 (현재 wiring 부재 시 위 패턴이 표준)

## 예상 PR 크기 — 3-PR 스택 권장

1. **(b) codegen tag→name 테이블 emit** (~80줄, additive · 무위험)
   - `gen2_enum_decl` 에 static array + count + register-call emit
   - 런타임에 `hexa_register_enum_type` 추가 (registry HashMap)
2. **(a) TAG_ENUM 래퍼 + 매치 사이트 마이그레이션** (~150줄, breaking — semver minor)
   - `HexaVal` layout · `gen2_enum_decl` `#define` 을 `hexa_enum(type_id, tag)` 로 교체
   - `gen2_match_cond` enum-pattern 분기 추가
   - `hexa_eq` enum overload
3. **(c) `_hexa_to_string_rec` TAG_ENUM 브랜치** (~30줄, parity closure)
   - switch case + `"<Type>::<Variant>"` 합성
   - `self/test_compact_enum.hexa` 14 FAIL → GREEN

## 참조

- r14-F STOP 리포트 (cycle 2 sub-agent, 2026-05-23)
- PR #347 (round-1 non-exhaustive match inbox — match-side 정합 작업 패턴)
- PR #475 (`to_string(NaN/inf)` Rust canonical casing — 유사한 special-cased `to_string` 패치 패턴)
- `self/test_compact_enum.hexa` (14 FAIL 기록 — 본 RFC 가 닫을 회귀 게이트)
- RFC-020 (`inbox/patches/rfc020-enum-payload-variants.md`) — payload variant 는 이미 array form 으로 우회, 본 RFC 는 unit variant 닫이
