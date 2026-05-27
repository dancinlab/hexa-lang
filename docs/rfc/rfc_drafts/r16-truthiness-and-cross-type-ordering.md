# r16 RFC — truthiness 일관성 + cross-type ordering 정책

- **Status**: design-draft (정책 명세 · 별도 surgical PR 가 본 문서의 권고를 구현)
- **Date**: 2026-05-25
- **Severity**: MEDIUM (correctness footgun · 사용자-노출 의미론 · 두 축 모두 silent wrong-result)
- **Source**: PROBE r16 sweep — "truthiness `if []` 가 `if 0`/`if ""` 와 불일치 + cross-type `1 < "a"` 가 의미 없는 silent 결과"
- **선행 surface**: TAG_FLOAT 0.0 falsy fix (`runtime_core.c:6400-6403`, 2026-04-20 silent-fallback audit) · 비-numeric `/` `%` → throw (PROBE r16 `#807` sibling, `runtime_core.c:7635/7655`) · enum-ordering RFC (PROBE r14-TTTT, `_hexa_enum_pair_idx` `runtime_core.c:7692`, 2026-05-24)
- **Lane**: docs-only. 본 문서는 정책 명세이며 컴파일러 소스(`codegen.hexa` / `parser.hexa` / `runtime*.c`)는 **건드리지 않음**. (in-flight codegen PR 와의 충돌 회피)

---

## 1. 배경 — 현 동작 + 측정 evidence

본 RFC 는 서로 무관해 보이지만 같은 root cause(런타임 값의 `default:`/`HX_INT()` fall-through)를 공유하는 **두 축**을 다룬다.

1. **Truthiness** — `if <value>` 에서 어떤 값을 falsy 로 볼 것인가.
2. **Cross-type ordering** — `<` `>` `<=` `>=` 가 서로 비교 불가능한 타입(int vs string 등) 사이에서 무엇을 반환할 것인가.

(참고로 이미 canonical 한 것: `1 == "1"` → `false` (strict, 좋음), `"a" < "b"` → lexical (좋음). 본 RFC 는 이 둘을 **건드리지 않는다**.)

### 1.1 측정 evidence — truthiness (probe 직접 실행)

현 main(`origin/main` @ `3de45d9f`)의 self-hosted transpiler(`self/native/hexa_v2`)로 직접 transpile → `clang -I self ... self/runtime.c` 컴파일 → 실행.

| 표현식 | 측정 결과 | 일관? | canonical 기대(Python) |
|---|---|---|---|
| `if 0` | **falsy** | — | falsy |
| `if 0.0` | **falsy** | ✅ (0 과 일치) | falsy |
| `if ""` | **falsy** | ✅ (0 과 일치) | falsy |
| `if []` (empty array) | **truthy** | ❌ **불일치** | falsy |
| `if #{}` (empty map) | **truthy** | ❌ **불일치** | falsy |
| `if 1` | truthy | ✅ | truthy |
| `if "x"` | truthy | ✅ | truthy |
| `if [1]` | truthy | ✅ | truthy |
| `if #{"a":1}` | truthy | ✅ | truthy |
| `if nil` | **parse error** | (별개) | (해당 없음) |

핵심 deviation: **0/0.0/"" 는 "empty/zero 는 falsy" 규칙을 따르는데, empty collection(`[]`/`#{}`)만 truthy 다.** 같은 "비어있음=falsy" 멘탈모델을 사용자가 적용하면 `if myList` 가 빈 리스트에서도 참이 되어 silent footgun.

`nil`/`null` 은 PROBE r14-A(`parser.hexa:3808-3816`)에서 bare value 로 금지됨 → `if nil` 은 컴파일 안 됨. 따라서 본 RFC 의 truthiness 축에서 `nil` 은 비대상(이미 처리됨).

#### root cause (참고 — 컴파일러는 안 건드림)

```c
// self/runtime_core.c:6396
int hexa_truthy(HexaVal v) {
    switch (HX_TAG(v)) {
        case TAG_BOOL:      return HX_BOOL(v);
        case TAG_INT:       return HX_INT(v) != 0;
        case TAG_FLOAT:     return HX_FLOAT(v) != 0.0;   // 2026-04-20 audit 로 추가됨
        case TAG_STR:       return HX_STR(v) != NULL && HX_STR(v)[0] != 0;
        case TAG_VOID:      return 0;
        case TAG_VALSTRUCT: return HX_VS(v) != NULL;
        default:            return 1;   // ← TAG_ARRAY / TAG_MAP 가 여기로 fall-through → 항상 truthy
    }
}
```

`TAG_ARRAY`/`TAG_MAP` 가 명시적 case 없이 `default: return 1` 로 떨어진다. 비어있든 말든 무조건 truthy. (2026-04-20 에 `TAG_FLOAT` 가 같은 `default` 함정에 빠져 `if 0.0` 가 truthy 였던 버그를 고친 전례가 바로 이 함수에 주석으로 남아있다 — empty-collection 도 같은 종류의 누락.)

### 1.2 측정 evidence — cross-type ordering

| 표현식 | 측정 결과 | 의미 있는가? | canonical(Go/Rust/Py3) |
|---|---|---|---|
| `1 < "a"` | **TRUE** | ❌ 무의미 (포인터 비교) | type/compile error |
| `"a" < 1` | **FALSE** | ❌ 무의미 (비대칭!) | type/compile error |
| `1 > "a"` | FALSE | ❌ 무의미 | type/compile error |
| `[] < []` | **TRUE** | ❌ 무의미 (heap 포인터 2개 비교) | type error / not-comparable |
| `nil < 1` | **parse error** | (별개 — bare nil 금지) | (해당 없음) |
| `"a" < "b"` | TRUE | ✅ lexical (좋음) | OK (same-type) |
| `1 == "1"` | FALSE | ✅ strict (좋음) | OK (strict eq) |

핵심 deviation: **서로 비교 불가능한 타입 사이의 `<`/`>` 가 에러 없이 무의미한 결과를 반환한다.** `1 < "a"` 가 TRUE 인데 `"a" < 1` 은 FALSE — **비대칭**이라 total-order 도 만족 안 함. `[] < []` 은 같은 두 빈 배열인데 TRUE(strict order 위반).

#### root cause (참고 — 컴파일러는 안 건드림)

```c
// self/runtime_core.c:7704
HexaVal hexa_cmp_lt(HexaVal a, HexaVal b) {
    int64_t ia, ib;
    if (_hexa_enum_pair_idx(a, b, &ia, &ib)) return hexa_bool(ia < ib);   // enum 쌍 (r14-TTTT)
    if (HX_IS_STR(a) && HX_IS_STR(b))
        return hexa_bool(hxlcl_strcmp(HX_STR(a), HX_STR(b)) < 0);          // str/str = lexical (좋음)
    if (HX_IS_FLOAT(a) || HX_IS_FLOAT(b) || HX_IS_VALSTRUCT(a) || HX_IS_VALSTRUCT(b))
        return hexa_bool(__hx_to_double(a) < __hx_to_double(b));           // 숫자류
    return hexa_bool(HX_INT(a) < HX_INT(b));   // ← 그 외 전부: HX_INT() 로 raw 비트 비교
}
```

마지막 `return hexa_bool(HX_INT(a) < HX_INT(b))` 가 함정이다. int/str 같은 mismatched 쌍은 위 3개 분기를 다 빠져나와 여기로 떨어지고, `HX_INT()` 는 string 의 `.s` 포인터(또는 array/map heap 포인터)를 **int64 로 그대로 읽어** 비교한다. 그래서 `1 < "a"` 는 "a" 의 intern 포인터가 1 보다 커서 TRUE, `[] < []` 은 서로 다른 두 heap 할당 주소를 비교한다. `gt`/`le`/`ge` 4개 helper 모두 동일 구조.

> 같은 함수군에 이미 enum cross-type 은 "다른 enum 타입이면 fold 안 하고 legacy fallback(DEFINED-BUT-MEANINGLESS)" 이라는 주석이 명시되어 있다(`runtime_core.c:7688-7691`). 본 RFC 는 그 "meaningless fallback" 을 throw 로 격상하는 것.

---

## 2. Canonical 비교 — 타 언어

### 2.1 Truthiness 표

| 언어 | `if` 가 받는 것 | 0 / 0.0 | `""` | `[]` (empty) | `{}` (empty map) | nil/null |
|---|---|---|---|---|---|---|
| **Python 3** | 임의 객체 (`__bool__`/`__len__`) | falsy | falsy | **falsy** | **falsy** | falsy (`None`) |
| **JavaScript** | 임의 값 (coercion) | falsy(`0`/`NaN`) | falsy | **truthy** ⚠ | **truthy** ⚠ | falsy(`null`/`undefined`) |
| **Go** | **bool 만** (coercion 없음) | compile error | compile error | compile error | compile error | n/a |
| **Rust** | **bool 만** | compile error | compile error | compile error | compile error | n/a |
| **Swift** | **Bool 만** | compile error | compile error | compile error | compile error | n/a |
| **hexa (현재)** | 임의 값 (coercion) | falsy | falsy | **truthy** ❌ | **truthy** ❌ | (parse error) |

요약:
- **Python**: "empty/zero 는 전부 falsy" — collection 포함 완전 일관. hexa 현 동작의 0/""/[]/#{} 중 앞 둘만 Python 과 일치.
- **JS**: empty collection 은 truthy(객체라서) — hexa 현 동작과 우연히 일치하나, JS 자체가 악명 높은 함정 표(`[] == false` 는 또 true)로 reference-anti-pattern.
- **Go/Rust/Swift**: 애초에 `if` 에 bool 외 금지 — coercion 자체가 없으니 불일치가 발생할 수 없음.

### 2.2 Cross-type ordering 표

| 언어 | `1 < "a"` | same-type `<` | 철학 |
|---|---|---|---|
| **Python 3** | **`TypeError`** (런타임) | OK | py2 는 허용했으나 py3 가 의도적으로 금지 |
| **Go** | **compile error** | OK | 정적 타입 — 애초에 표현 불가 |
| **Rust** | **compile error** (`PartialOrd` 미구현) | OK | 정적 타입 + trait |
| **Swift** | **compile error** | OK | 정적 타입 |
| **JavaScript** | `1 < "a"` → false (둘 다 NaN coercion 함정) | OK-ish | abstract relational comparison — 또 다른 함정 |
| **hexa (현재)** | **TRUE** (포인터 비교) ❌ | OK (lexical) | silent meaningless |

요약: **단 하나의 진영도 cross-type `<` 를 "의미 있는 silent 결과"로 허용하지 않는다.** 정적 타입 언어는 compile error, Python3 은 런타임 TypeError, JS 조차 (함정이긴 해도) NaN-coercion 으로 명세화되어 있고 포인터를 raw 비교하지 않는다. hexa 의 "포인터를 int64 로 읽어 비교"는 어느 canonical 과도 안 맞는다.

---

## 3. 권고 — 2개 축

### 3.1 축 (a) — Truthiness

#### 옵션

| 옵션 | 정책 | 장점 | 단점 | breaking? |
|---|---|---|---|---|
| **A** | empty collection 도 falsy 로 확장 (`[]`/`#{}` falsy — Python 일관) | `if 0`/`if ""`/`if []` 가 **하나의 규칙**("비어있음=falsy")으로 통일 · 실제 불일치를 직접 해소 · 기존 `if 0`/`if ""` 동작 불변 · `if myList` 패턴이 직관대로 동작 | 비어있을 때 truthy 를 의도한 (희귀) 코드는 의미 변경 — but 그런 코드는 거의 없음(아래 §5) | **거의 없음** (empty-collection-truthy 의존 코드만) |
| **B** | `if` 에 bool 만 허용 (Go/Rust/Swift — coercion 전면 폐지) | 가장 엄격 · 불일치 발생 불가능 · 명시적 | **`if 0`/`if ""` 도 거부** → 기존 정수/문자열 truthiness 호출부 전부 깨짐 · 대규모 migration · hexa 의 현 coercion 정체성과 충돌 | **YES (대규모)** |

#### 권고 — **옵션 A (empty collection 을 falsy 로 확장)**

근거:
1. **실제 불일치를 최소 변경으로 해소**: 문제의 본질은 "`if 0`/`if ""` 는 비어있음=falsy 인데 `if []` 만 아니다" 라는 **규칙 비일관**이다. 옵션 A 는 collection 을 같은 규칙에 편입시켜 비일관을 0 으로 만든다.
2. **least-breaking**: 옵션 B 는 `if 0`/`if ""` 까지 거부해서 멀쩡히 동작하던 모든 truthiness 호출부를 깬다(wipe-guard 급 대규모). 옵션 A 는 "empty collection 이 truthy 임에 의존하는 코드"만 영향받는데, 그런 코드는 안티패턴이고 실측상 거의 존재하지 않는다(§5).
3. **전례와 정합**: 이 정확한 함수(`hexa_truthy`)에서 2026-04-20 에 `TAG_FLOAT` 0.0 을 falsy 로 고친 audit 가 이미 있다 — `default: return 1` 누락을 메우는 동일 패턴. empty-collection 은 그 audit 의 남은 한 칸.
4. **canonical 정합**: Python(완전 일관 falsy)과 일치. JS 와는 갈라지지만 JS 의 truthy-empty-array 는 그 자체로 reference-anti-pattern.

권고 delta(구현 PR 이 할 일):
- `hexa_truthy` 에 `case TAG_ARRAY: return HX_ARR_LEN(v) > 0;` 와 `case TAG_MAP: return <map 비어있지 않음>;` 추가. (정확한 map-empty 술어는 구현 PR 이 map 내부표현으로 결정 — `rt_map_len`/엔트리 카운트.)
- `if 0`/`if 0.0`/`if ""`/`if nil`(parse error 유지) 은 **불변**.
- nullable/Option(`None`) 의 truthiness 는 본 RFC 범위 밖(이미 `None`/Option 경로가 별도) — `nil` bare-value 금지는 그대로.

### 3.2 축 (b) — Cross-type ordering

#### 권고 — **incomparable 타입 간 `<`/`>`/`<=`/`>=` 는 THROW**

`int vs string`, `array vs int`, `map vs string` 처럼 서로 ordering 이 정의되지 않은 타입 쌍에 ordering 연산자를 쓰면 **런타임 type error 를 던진다**(Go/Rust=compile error, Python3=TypeError 의 canonical 에 동일 정신). silent 무의미 포인터 비교를 제거한다.

영향 범위(중요):
- **same-type ordering 은 전혀 영향 없음**: `1 < 2`(int/int), `1.5 < 2.0`(float/float), `1 < 2.0`(mixed numeric promotion — 이미 `__hx_to_double` 경로), `"a" < "b"`(str/str lexical), enum/enum 동일타입(r14-TTTT 경로). 전부 throw 이전 분기에서 처리되어 그대로 통과.
- **eq/neq 는 영향 없음**: `==`/`!=` 는 strict-by-design(`1 == "1"` → false). 본 RFC 는 ordering 연산자(`<`/`>`/`<=`/`>=`)만 다룬다. cross-type eq 는 의미가 명확(=항상 false)하지만 cross-type order 는 의미가 없으므로(total order 불성립) 둘을 다르게 취급하는 것이 일관적이다.
- **THROW vs compile-error**: hexa 의 ordering 은 dynamic value 일 때 런타임 helper(`hexa_cmp_*`)로 내려가므로 정적 거부가 항상 가능하진 않다(타입이 컴파일타임에 안 잡힐 수 있음). 따라서 **런타임 throw**(Python3 모델)가 현실적이다. 단, 정적으로 타입이 잡히는 경우는 codegen 이 `as`/typed-param fast-path 로 이미 직접 emit 하므로(아래 §4 구현 노트) hot loop 는 throw 검사조차 안 거친다.

옵션 trade-off:

| 옵션 | 정책 | 장점 | 단점 |
|---|---|---|---|
| **(b)-1 (권고)** | incomparable 쌍 → runtime throw | silent wrong-result 제거 · 3대 canonical 정신 일치 · `/` `%` 비-numeric throw 전례와 동형 | 런타임 분기 1개 추가(typed fast-path 는 영향 없음) · 기존에 우연히 cross-type compare 하던 코드는 throw |
| **(b)-2** | 정적 거부(컴파일 에러) only | Go/Rust 수준 엄격 | dynamic value 는 정적으로 못 잡음 → 부분적 커버만 가능, 불완전 |
| **(b)-3** | 현 silent 유지 | zero-change | 함정 그대로 |

→ **(b)-1 권고.** runtime throw 가 dynamic-value 까지 완전 커버하고, 같은 runtime 의 `/` `%` 비-numeric → throw(PROBE r16 #807 sibling) 와 정확히 같은 패턴이다.

권고 delta(구현 PR 이 할 일):
- `hexa_cmp_lt`/`gt`/`le`/`ge` 4개 helper 의 마지막 `return hexa_bool(HX_INT(a) < HX_INT(b))` fall-through 직전에 **타입 호환성 guard** 추가: 두 피연산자가 (numeric-numeric) 또는 (str-str) 또는 (same-enum) 중 어느 comparable 쌍에도 안 맞으면 `hexa_throw(...)` 로 type error("cannot order <type> with <type>"). 메시지는 `/` `%` guard 의 `(tag %d / tag %d)` 포맷과 동형.
- numeric/str/enum 분기는 **순서·동작 모두 불변** (throw 는 마지막 fallback 만 대체).

---

## 4. 구현 노트 (참고 — 본 RFC 는 코드 미변경)

- **Truthiness 진입점은 단일**: codegen 의 `if`/`while`/`&&`/`||`/`!` 가 전부 `hexa_truthy()` 를 통과한다(`runtime_core.c:6396`). 따라서 축 (a) 는 이 함수 한 곳에 2개 case 만 추가하면 모든 truthiness 컨텍스트에 일괄 적용. arena/byte-identical self-host 빌드에 영향 없음(순수 분기 추가).
- **Ordering throw 는 cold path 만**: codegen 은 두 피연산자가 정적으로 known-int(typed param/let)면 `hexa_cmp_lt` 를 거치지 않고 C `<` 를 직접 emit 한다(`codegen.hexa:4636-4641` typed fast-path, `_gen2_param_type`). 즉 cross-type 무의미 비교는 **오직 dynamic/untyped 값**이 runtime helper 로 내려갈 때만 발생. throw guard 를 helper 에 넣어도 typed int hot loop 는 검사조차 안 거치므로 perf regression 없음.
- **4개 helper 대칭**: `lt`/`gt`/`le`/`ge` 가 동일 구조라 guard 도 동일하게 4곳. `eq`/`neq`(`hexa_eq`)는 별도 함수이고 본 RFC 미대상(strict eq 유지).
- **map-empty 술어**: `TAG_ARRAY` 는 `HX_ARR_LEN` 으로 즉시 판정. `TAG_MAP` 의 "비어있음"은 내부표현(entries/buckets)에 따라 구현 PR 이 `rt_map_len`/카운트로 결정. struct 는 native 에서 `TAG_MAP`(`__type__` carrier)이므로 — **주의**: struct 인스턴스를 `if s` 로 truthy 검사하는 코드가 있다면 "필드 0개 struct" 가 falsy 가 될 수 있다. 구현 PR 은 `__type__` carrier map(=struct)을 truthiness 에서 제외(항상 truthy)할지 결정해야 함 → §7 Q2.

---

## 5. migration 위험

| 축 | 깨지는 패턴 | 위험도 | 완화 |
|---|---|---|---|
| (a) truthiness | "빈 collection 이 truthy" 에 의존한 코드 — 예: `if myList { ... }` 가 빈 리스트에서도 실행되길 기대 | **낮음** — 이는 거의 항상 버그/안티패턴(빈 리스트인데 처리하는 것). 빈-비빈 구분을 의도했다면 `.len() > 0` 이 canonical | `.len() > 0` / `.is_empty()` 로 명시화 권고 · explain note(선택) |
| (a) truthiness | `if structInstance` (필드 0개 struct 가 falsy 화) | **낮음~중간** | §4 + §7 Q2 — `__type__` carrier 는 truthy 유지 권고 |
| (b) ordering | 우연히 cross-type `<` 를 호출하던 코드(대부분 latent 버그) | **낮음** — silent 무의미 결과에 의존하는 정상 코드는 없음. throw 는 latent 버그를 surface 시킬 뿐 | throw 메시지에 두 타입 명시 → 호출부 즉시 식별 |
| (b) ordering | sort/min/max comparator 가 mixed-type 배열을 정렬 | **중간** — mixed-type 배열 sort 는 이미 무의미했음(비대칭 order → 비결정 결과). throw 가 "애초에 안 됨"을 명확히 함 | 동질 타입 배열로 분리하거나 키 함수 사용 권고 |

전체적으로 **두 축 모두 깨지는 것은 대부분 이미 latent 버그**다. 정상적·의도적 코드의 의미를 바꾸는 위험은 낮다. (옵션 B 였다면 `if 0`/`if ""` 가 다 깨져 위험이 컸겠지만, 권고 A 는 그걸 피한다.)

---

## 6. acceptance probe set (falsifiable)

구현 PR 은 아래를 정확히 재현해야 한다. (self-host transpile + `clang -I self ... self/runtime.c` 실행)

### 6.1 Truthiness (축 a)

| # | 표현식 | 기대 | 현재 | falsifier |
|---|---|---|---|---|
| T1 | `if 0` | falsy | falsy | F-T-int0 (regression guard — 불변) |
| T2 | `if 0.0` | falsy | falsy | F-T-flt0 (불변) |
| T3 | `if ""` | falsy | falsy | F-T-str0 (불변) |
| T4 | `if []` | **falsy** | truthy | **F-T-arr0** (현재 FAIL = 구현 미완 증명) |
| T5 | `if #{}` | **falsy** | truthy | **F-T-map0** (현재 FAIL) |
| T6 | `if [1]` | truthy | truthy | F-T-arr1 (불변) |
| T7 | `if #{"a":1}` | truthy | truthy | F-T-map1 (불변) |
| T8 | `if "x"` / `if 1` | truthy | truthy | F-T-nonzero (불변) |

### 6.2 Cross-type ordering (축 b)

| # | 표현식 | 기대 | 현재 | falsifier |
|---|---|---|---|---|
| O1 | `1 < "a"` | **THROW** (type error) | TRUE | **F-O-int-str** (현재 silent TRUE = FAIL) |
| O2 | `"a" < 1` | **THROW** | FALSE | **F-O-str-int** |
| O3 | `1 > "a"` / `1 <= "a"` / `1 >= "a"` | **THROW** | (silent) | F-O-allops (4 연산자) |
| O4 | `[] < []` | **THROW** | TRUE | **F-O-arr** |
| O5 | `1 < 2` | TRUE (int/int) | TRUE | F-O-int-int (불변 — same-type 미영향) |
| O6 | `1.5 < 2.0` / `1 < 2.0` | TRUE | TRUE | F-O-num (불변 — numeric promotion) |
| O7 | `"a" < "b"` | TRUE (lexical) | TRUE | F-O-str-str (불변) |
| O8 | `1 == "1"` | FALSE (strict eq) | FALSE | F-O-eq (불변 — eq 미대상) |

probe 재현 명령(참고):

```
cp self/native/hexa_v2 /tmp/hxcc
/tmp/hxcc /tmp/truth_probe.hexa /tmp/truth_probe.c
clang -O0 -w -I self -o /tmp/truth_probe /tmp/truth_probe.c self/runtime.c -lm
/tmp/truth_probe
```

(THROW probe 는 `try`/process-exit 비정상 종료로 검증 — `/` `%` 비-numeric throw 테스트와 동일 harness.)

---

## 7. open questions

- **Q1**: 축 (b) 의 throw 가 런타임이라 **정적으로 잡히는 cross-type compare 는 codegen 단계에서 더 일찍(compile error) 거부**할지 — typed fast-path 에서 known-int vs known-str 가 잡히면 Go/Rust 수준 정적 거부 가능. 다만 부분 커버라 우선순위는 런타임 throw(완전 커버) 후순위로 둠.
- **Q2**: struct 인스턴스(native `TAG_MAP` + `__type__` carrier)의 truthiness — 필드 0개 struct 를 falsy 로 둘지 truthy(carrier 는 항상 truthy)로 둘지. **truthy 유지 권고**(struct 존재 ≠ empty collection). 구현 PR 이 `__type__` 키 존재 검사로 분기.
- **Q3**: 축 (a) 에서 truthy-empty-collection 에 의존하던 코드를 위한 **lint/explain note**(`if myList` 에 "did you mean `.len() > 0`?") 를 넣을지 — diagnostics-only(codegen 비변경)지만 noise 위험. 별도 검토.
- **Q4**: nullable/Option 의 truthiness — `Some(x)` truthy / `None` falsy 를 명시 surface 로 둘지. 현재 `nil` bare 금지 + Option 경로 별도라 본 RFC 범위 밖. 후속 분리 권고.
- **Q5**: `==`/`!=` 의 cross-type 정책 재확인 — 현재 strict(`1 == "1"` → false)가 canonical 이고 본 RFC 는 유지. ordering 만 throw, eq 는 false 라는 비대칭이 의도적임을 문서에 못박음(eq 는 "다름"이 의미 있고, order 는 의미 없음).

---

*Provenance: PROBE r16 — truthiness 일관성(`if []`/`if #{}` 가 `if 0`/`if ""` 와 불일치) + cross-type ordering(`1 < "a"` 무의미 silent 결과) 2축 정책 RFC. 측정 evidence = `self/native/hexa_v2`(origin/main @ `3de45d9f`) self-host transpile + `clang -I self ... self/runtime.c` 실행. root cause = `hexa_truthy` 의 `default: return 1`(TAG_ARRAY/TAG_MAP fall-through) + `hexa_cmp_*` 의 `HX_INT()` raw-pointer fallback. 전례 = TAG_FLOAT 0.0 falsy audit(2026-04-20) · `/` `%` 비-numeric throw(PROBE r16 #807 sibling) · enum-ordering RFC(PROBE r14-TTTT). docs-only lane(컴파일러 소스 무변경 · in-flight codegen PR 충돌 회피). 2026-05-25.*
