# round6 rung C — HX3026 string-receiver extension (Rust E0610 field-on-primitive)

## 메커니즘
HX3026 (field READ on a KNOWN non-aggregate primitive receiver, Rust E0610) 은 origin/main
기준 `int`/`float`/`bool`/`char` 만 커버 — `string` 이 유일한 **측정된 대칭 갭**이었다.
HX3025 index arm 은 #4626 에서 이미 `string` 을 포함했으므로(자매 REJECT), field arm 도
정확히 같은 형태로 확장한다. `s.foo` (KNOWN string 위의 사용자 필드 READ) = 보장된 런타임
에러 → REJECT; `s.chars()`/`s.len()` 은 METHOD 이라 callee-position(depth>0) 에서
callee-depth guard 로 침묵 + `_is_builtin_method` 도 면제.

## 변경 (HX3026 재사용 · 신규 코드 없음)
- `compiler/check/types.hexa` r9a Field arm reject 조건에 `|| recv_t.kind == "string"` 추가
  (기존 `_types_callee_depth == 0 && len(e.text)>0 && !_is_builtin_method` 게이트 보존).
  주석 블록을 string 커버리지 명시하도록 갱신.
- `compiler/diag/catalog.hexa` HX3026 explain 을 primitive 목록에 string 포함 + HX3025 #4626
  대칭 언급하도록 갱신 (구조 불변 → 신규 DiagSpec 없음 · union 위험 없음 · DiagSpec 76 ==
  fix_it_kind 76 parity 유지).
- `compiler/check/types_test.hexa` (ar) 케이스 2개 추가:
  - `_build_case_hx3026_string_field` — `fn f(s: string){ let n = s.foo }` → 1 HX3026 error;
    `fn g(s: string){ let cs = s.chars() }` → 0 (method, depth>0)
  - `_build_case_hx3026_string_fixture` — `case_hx3026_string_test.hexa` → 1 warning
    (`_types_strict_for` carve-out)

## 보수적 under-reject 계약
KNOWN primitive (int/float/bool/char/string) 만 REJECT; unknown/unit/HexaVal/named/array/map
수신자는 전부 SILENT. nested receiver (`s.inner.x`) 는 r7+ type-erasure 천장으로 침묵.

## byteeq 중립
S3 진단은 MIR 전에 erase → codegen 바이트 불변. own-lint 경로는 `_bck_active` OFF-gated.
실코퍼스 HX3026 delta = 0 (census).

## 검증
- catalog parity: DiagSpec 76 == fix_it_kind 76
- types_test (ar): pool bare-run (aiden)
- real corpus HX3026 census delta = 0
