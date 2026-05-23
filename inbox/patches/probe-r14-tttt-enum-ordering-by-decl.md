# PROBE r14-TTTT · enum `<`/`>`/`<=`/`>=` 선언순(declaration-order) 비교

- 상태: PR 제출
- 날짜: 2026-05-24
- 영역: `self/runtime_core.c`, `self/runtime.h`, `self/codegen.hexa`
- 선행: PR #582 (PR-2.1 단일 enum TAG_ENUM emit), PR #589 (PR-2.2 모든 unit-variant enum TAG_ENUM 마이그레이션)

## 동기

`Color::Red < Color::Blue` 같은 enum 값 ordering 비교가 **명세 없는 우연한 동작**에 의존하고 있었다.
- PR-2.2 시점부터 unit-variant enum은 `hexa_enum_str("Color::Red")` 형식 → `HexaVal{.tag=TAG_ENUM, .s="Color::Red"}` 으로 emit.
- 그러나 `hexa_cmp_lt/gt/le/ge` 는 TAG_ENUM 분기가 없음 → `HX_IS_STR` 체크(`tag==TAG_STR`)에 안 잡혀 정수 경로(`HX_INT(a) < HX_INT(b)`)로 fall-through.
- 그 정수 = `.s` 포인터 비트(union). 결과적으로 **string literal 메모리 주소 순서**가 (우연히) declaration order와 자주 일치 → 통과처럼 보이지만 부정확.

Rust derives `Ord` by declaration order — `pub enum Color { Red, Green, Blue }` 면 `Red < Green < Blue`. 이 PR도 동일 시맨틱을 채택.

## 설계

### A. Descriptor 도입

`.s` 슬롯에 char* 대신 **HexaEnumDesc 포인터**를 저장하도록 emit 확장.

```c
typedef struct HexaEnumDesc {
    uint32_t    magic;        // = HEXA_ENUM_DESC_MAGIC (0x484E5544U)
    uint32_t    variant_idx;  // 0-based declaration order
    const char* display;      // "<Type>::<Variant>"
    const char* type_name;    // "<Type>" — 같은 enum 게이트
} HexaEnumDesc;
```

코드젠 (`gen2_enum_decl`, unit-variant 경로) emit:

```c
static const struct HexaEnumDesc __enum_desc_Color_Red =
    { HEXA_ENUM_DESC_MAGIC, 0U, "Color::Red", "Color" };
#define Color_Red hexa_enum_str_v(&__enum_desc_Color_Red)
```

### B. legacy `hexa_enum_str(display)` 호환

기존 `hexa_enum_str(const char*)`는 그대로 유지. runtime helper `_hexa_enum_is_desc(v)` 가 `.s` 첫 4바이트를 magic과 비교:
- magic 일치 → 디스크립터, `display` / `variant_idx` / `type_name` 회수 가능.
- 불일치 → bare ASCII display, idx 없음(-1) — ordering은 fall-through.

magic `0x484E5544U` = LE 바이트 `44 55 4E 48` = `"DUNH"`. 어떤 emit display literal도 `"DUNH..."`로 시작하지 않으므로 충돌 없음.

### C. 같은 enum 게이트

```c
static inline int _hexa_enum_pair_idx(HexaVal a, HexaVal b,
                                      int64_t* out_a, int64_t* out_b) {
    if (HX_TAG(a) != TAG_ENUM || HX_TAG(b) != TAG_ENUM) return 0;
    const char* ta = _hexa_enum_type_name(a);
    const char* tb = _hexa_enum_type_name(b);
    if (!ta || !tb) return 0;                          // legacy bare
    if (ta != tb && hxlcl_strcmp(ta, tb) != 0) return 0; // 다른 enum
    *out_a = _hexa_enum_idx(a);
    *out_b = _hexa_enum_idx(b);
    return 1;
}
```

`hexa_cmp_lt/gt/le/ge` 첫 줄에서 `_hexa_enum_pair_idx` 시도, 성공 시 `idx 비교 → bool`. 실패 시 기존 분기 (str/float/int) 그대로.

### D. 호환·롤백 안전성

- `_hexa_to_string_rec` TAG_ENUM 분기: `HX_STR(v)` 직접 사용 → `_hexa_enum_display(v)` 로 라우팅. 디스크립터·bare 양쪽 동일 렌더링.
- `hexa_eq` TAG_ENUM 분기: 포인터-eq fast-path 그대로(같은 `#define`은 같은 디스크립터). cross-form 시 display strcmp.
- ABI: HexaVal 레이아웃 미변. 새 export `hexa_enum_str_v`. 기존 `hexa_enum_str` 호출처 0(코드젠만), 헤더에서 호환 유지.

## 검증

probe (Color/Zoo + sort + min/max + 회귀 시나리오):

```
min(Red,Green)  = Color::Red
max(Blue,Green) = Color::Blue
Red < Green: true     Red < Blue:  true     Green < Blue: true
Green < Red: false    Blue < Red:  false    Blue < Green: false
sorted: Color::Red, Color::Green, Color::Blue
int 5 < 10: true    int 10 > 5: true    int 5 <= 5: true    int 5 >= 6: false
str 'apple' < 'banana': true    str 'banana' > 'apple': true    str 'zoo' <= 'zoo': true
float 1.5 < 2.5: true
Zoo::Bear < Zoo::Ant: true (decl-order, alphabetic 이면 false)
Zoo::Ant  < Zoo::Cat: true
Zoo::Bear < Zoo::Cat: true
Red == Red:   true    Red == Green: false
```

회귀:
- `self/test_compact_enum.hexa` 43/43 PASS (Direction, Color, Season, Weekday + match + arrays)
- `self/test_enum_construct.hexa`, `self/test_enum_path.hexa`, `self/test_enum_variant.hexa`, `self/test_enum_payload_full.hexa` PASS
- compiler self-host: 새 hexa_v2가 자기 자신을 빌드 (cc rebuild OK)

## 후속

- HEXA_ENUM_NAMES_TABLE 마이그레이션 (PR-3, #555): `__enum_<Name>_names[]` 테이블이 이미 추가 metadata로 emit 중. 디스크립터로 통합 가능.
- payload-bearing enum: 여전히 `hexa_int(N)` form (배열 [tag, payload] 시맨틱 유지). ordering 확장은 별도 PR.
- atlas 등록: declaration-order Ord = total order on finite set 정리 추가 가능.
