조사 완료. 배치 플랜입니다.

---

# static-types 남은 rung 배치 플랜 (anchor = `064c4eee3` — main `34e43d251` + HX3005 #4606)

⚠️ **전제**: #4606(HX3005 match-join)은 아직 머지 대기. Rung A는 #4606이 추가한 라인을 직접 수정하므로 **3개 rung 모두 `064c4eee3`에서 분기**(= `feat/static-types-hx3005-join` 위 스택), #4606 머지 후 base를 main으로 retarget. 아래 line 번호는 전부 064c4eee3 기준 실측.

## 1. rung 전수 조사

### (a) faithfulness 갭 — bare `_types_equal` / unit-guard 비대칭 전수

`_types_equal(` 잔여 호출 = 7곳, unit-guard(`ku = "unit"`) 보유 사이트 = 4곳(2709·3466·3484·3642). 전수 대조:

| # | 사이트 | file:line | 현 동작 | 판정 |
|---|---|---|---|---|
| 1 | `_types_equal` 재귀 | types.hexa:2154 | 자기 재귀 | 갭 아님 |
| 2 | `_types_assignable` 첫 줄 | 2216 | superset 관계의 정의 | 갭 아님 |
| 3 | if/while cond=bool | 2687·2729 | bare equal + unit/HexaVal/unknown guard | **갭 아님** — Rust도 int-lit→bool 코어션 없음(E0308). assignable로 바꿔도 lit 암이 bool에 안 걸려 의미 동일(no-op) |
| 4 | binop arith | 3446 | bare equal (unit guard 有) | 갭이지만 **제외** — value-flow 아님, assignable의 expected/actual 방향성이 안 맞음(네 직전 판정 유지, 별도설계) |
| 5 | binop compare | 3474 | bare equal (unit guard 有) | 동상 — 제외 |
| 6 | **match arm-body join** | **3725–3727** | `_types_assignable` ✓지만 **unit-permissive guard 없음**. if-join(2709–2711)·call-arg(3642–3643)엔 있음 | **갭 = Rung A**. unbanded Error(HX3005)라 false-fire=빌드 brick. `match c { 1 -> v(), _ -> 3 }`(v = ret-미주석 fn → call checker 3652가 unit 반환) → first_t=unit → assignable(unit, i64-lit)=false → 오탐 HX3005 |
| 7 | **return 사이트 val_t** | **2783–2785** | frame_ret unit은 관용(2782) but **actual(val_t)=unit 무가드**. fn-tail(5056)·call-arg(3643)는 actual-unit 관용 | **갭 = Rung B-1**. `fn f() -> i64 { return v() }`(v 미주석) → HX3004 오탐(Error). 단 bare `return`(children==0→val_t=unit)은 현재 fire가 **정당**(Rust E0069) — guard에 children>0 조건 필수 |
| 8 | **assign 제네릭 HX3001** | **3023–3025** | default-ON, rhs_t=unit 무가드 | **갭 = Rung B-2**. `g = v()`(g: 모듈-let 타입주석, v 미주석) → HX3001 오탐(Error) |
| 9 | **모듈-let RHS** | **5071–5075** | `len(rhs_t.kind)>0` 게이트만, unit 무가드 | **갭 = Rung B-3**. `let W: i64 = v()` → HX3001 오탐 |
| 10 | fn-tail | 5053–5058 | assignable + body_t unit guard ✓ | 갭 아님 |
| 11 | flag-gated r1~r9 암들(2821·2864·2903·2930·2962·3009·3173) | — | `_types_kind_is_scalar` 게이트가 unit을 배제(scalar("unit")=false) | 갭 아님 |

#7·8·9는 call-arg가 #4457에서 실코퍼스 fire(`_bell(is_leap(yr))` blocked)로 증명한 것과 **동일 클래스**의 잔여 사이트. 셋 다 default-ON Error → 잠재 brick.

### (b) 저리스크 신규 REJECT 후보 (catalog next-free = **HX3025** 확인: HX3001–3024 전부 점유, catalog.hexa 실측)

| 후보 | Rust E | 판정 |
|---|---|---|
| **index-on-scalar** `n[0]`, n: KNOWN int/float/bool/char | E0608 | **채택 = Rung C**. 런타임 보증 실측: C-substrate `hexa_array_get` 가드가 비-array에 abort (runtime_core_emit.hexa:3388–3398 "container is not an array (tag=N)"), 네이티브 `rt_array_get_native`는 in-bounds body만이고 가드는 C wrapper 단일점(array_core.hexa:113–115) → HX3024 계약("guaranteed runtime error를 S3로 전진") 충족. string은 v1 제외(아래 §5) |
| non-callable callee `x()` | E0618 | **이미 커버** — HX2003 Stage1 C20 (types.hexa:3578–3589). 제외 |
| unary `!` non-bool | E0600 | **부적격** — `!`는 hexa_truthy로 lower, 전 tag 수용(런타임 throw 없음). HX3024 catalog가 명시적으로 exempt 문서화(catalog.hexa:494). 제외 |
| field-on-primitive `n.foo` | E0610 | 유효하나 **배치 밖** — builtin-method 31종(`_is_builtin_method`)·UFCS·call-callee Field infer와의 double-report(one mistake=one error 원칙, types.hexa:2899) 상호작용 설계 필요. 다음 후보로 |
| bare-return-in-typed-fn | E0069 | 이미 HX3004 경로로 fire 중(#7에서 보존됨). 전용코드 분리는 filler — 제외 |

## 2. 배치 선정 — 3 rung (과욕 금지)

| Rung | 내용 | 방향 | byteeq |
|---|---|---|---|
| **A** | HX3005 match-join unit-permissive guard | loosening-only | Error 삭제 방향뿐 — self-compile에 HX3005가 있었으면 이미 RED였으므로 diag stream 불변 (#4606과 동일 논증) |
| **B** | actual-unit permissive guard 3사이트 일괄 (return 2783 · assign 3023 · 모듈-let 5072) | loosening-only | 동일 논증 (HX3004/HX3001 Error 삭제 방향뿐) |
| **C** | **HX3025** index-on-scalar REJECT (E0608) | conservative under-reject | 신규 Error는 corpus에 scalar-index가 0건일 때만 stream 불변 — census는 PR CI byteeq 3-target + selfhost gates가 빌드로 증명(RED면 fire-set 축소) |
| 제외 | binop operand literal-aware | — | 방향성 별도설계(사용자 기판정) |
| 제외 | 미주석-로컬 추론 | — | 대공사(기판정 유지) |
| 제외 | E0610 field-on-primitive | — | double-report 설계 필요 → 다음 배치 |

**독립성**: A=match-join(3725) · B=return/assign/모듈-let(2783/3023/5072) · C=Index 암(3288)+emit 헬퍼(2046)+catalog — types.hexa 편집 라인대역이 **전부 260줄 이상 이격, 상호 겹침 0** (실측). 의미상으로도 상호작용 없음(`n[0] = 5`는 C가 LHS-infer에서 1회 fire, B의 assign guard는 lhs_t=empty로 원래 관용).

## 3. rung별 impl 스펙

### Rung A — `fix/st-hx3005-unit-guard` · 테스트 라벨 **(ag)**
- **diff** (types.hexa:3725–3727): if-join 2709–2711과 동일 idiom.
  ```
  if !_types_assignable(first_t, bt, e.children[i + 1]) {
      let ku = "unit"                                   // if-join(2709) parity
      if first_t.kind != ku && bt.kind != ku {
          _emit_hx3005(arm_idx, first_t, bt, e.children[i + 1].span, out)
      }
  }
  ```
- **test (ag)**: `_build_case_hx3005_join_coerce`(types_test:1305) 클론 — 모듈에 ret-미주석 `fn v()` 등록 + `match c { 1 -> v(), _ -> 3 }`. 기대 **0 HX3005**(pre-fix 1). 기존 (af)는 unit 암이 없어 불변(회귀 컨트롤).
- byteeq 논증: loosening-only + HX3005는 unbanded Error → 통과 중인 self-compile엔 존재 불가 → stream 불변.

### Rung B — `fix/st-actual-unit-guard-3sites` · 라벨 **(ah)**
- **diff 1** (2783–2785): bare-return 보존이 핵심.
  ```
  if !_types_assignable(frame_ret, val_t, val_src) {
      // actual-unit permissive는 `return <expr>`만 (call-arg 3643 parity);
      // bare `return`은 계속 fire (Rust E0069).
      if !(len(e.children) > 0 && val_t.kind == "unit") {
          _emit_hx3004(frame_name, frame_ret, val_t, e.span, out)
      }
  }
  ```
- **diff 2** (3023–3025): emit을 `if rhs_t.kind != "unit"`로 wrap (call-arg 3642 idiom).
- **diff 3** (5072–5074): 동일 wrap.
- **test (ah)**: 1케이스 3어서션 — `fn v() {}` 등록 + ① `fn f() -> i64 { return v() }` ② 모듈-let `g: i64` + fn 내 `g = v()` ③ `let W: i64 = v()` → 기대 **0 HX3004 + 0 HX3001**(pre-fix 각 1). 양성 컨트롤 = 기존 (e)(`pick()->Int returns string` 1 HX3004) 불변.
- 실측: 현 types_test에 unit-actual fire를 기대하는 케이스 없음(grep 'unit' = enum variant 헬퍼뿐) → 기존 기대치 조정 불필요.

### Rung C — `feat/st-hx3025-index-on-scalar` · 라벨 **(ai)**
- **diff 1** (types.hexa Index 암, 3295 while 직후 / 3296 array 조기반환 앞):
  ```
  // segment(b) HX3025 REJECT (Rust E0608): KNOWN 비컨테이너 스칼라 인덱싱.
  // hexa_array_get C-wrapper가 런타임 abort 보증(runtime_core_emit:3398);
  // string 제외 v1(런타임은 abort하나 corpus census 미완) · unknown/unit/
  // HexaVal/array/map/named 침묵(under-reject). 명시적 열거 — HX3024 계약.
  if _is_integer_kind(base_t) || _is_float_kind(base_t) || base_t.kind == "bool" || base_t.kind == "char" {
      _emit_hx3025(base_t, e.span, out)
  }
  ```
- **diff 2** emit 헬퍼(2046 뒤): `_emit_hx3024`(2037–2046) 1:1 미러 — `diag_new("HX3025")` + `_types_strict_for(sp.file)` 분기(real source=Error, fixture=`diag_emit_sev(b, Severity::Warning)`). **carve-out 필수** — 없으면 byte-eq 픽스처 corpus가 brick.
- **diff 3** catalog.hexa:497(HX3024 DiagSpec 직후) 신규 DiagSpec: code "HX3025" · severity Error · stage "S3" · template `"cannot index into a value of type `{actual}`"` · explain은 HX3024(489–495) 서식 준수(E0608 인용 + 런타임 보증 + under-reject 열거 + carve-out).
- **test (ai)**: ① `fn f(n: i64) -> i64 { let x = n[0] ... }` → 1 HX3025 error ② `xs: [i64]` param `xs[0]` → 0 ③ unknown-ident base → 0 ④ (ad) 패턴 클론: 동일 AST를 `*_test.hexa` 파일명으로 → severity warning (`_count_code_sev`).
- byteeq: fire-set이 corpus에 0건이면 stream 불변 — **census = PR CI 자체**(byteeq 3-target + selfhost-gates가 RED로 알려줌). 사전 census로 pool에서 full types_test + stage-2 self-compile 1회.

공통: 각 PR = CHANGELOG.jsonl 1줄 + `state/static-types/<rung>_design.md`(#4606 파일세트 패턴). ARCHITECTURE.json 불변.

## 4. ★공유파일 머지전략 — **(a) 독립 브랜치·PR + 직렬 rebase** 채택

- **types.hexa**: 편집대역 A@3725 / B@2783·3023·5072 / C@2046·3295 — 실측 전부 이격 → **git 3-way 자동머지, 충돌 0**. 병렬 안전.
- **types_test.hexa** (충돌 확실 지점 2곳):
  - **등록부**: 3개 모두 summary 블록(2267 `println("")` 직전) 삽입 → 확실 충돌. 대응 = **라벨 사전배정 (ag)=A·(ah)=B·(ai)=C + 머지순서 고정 A→B→C**. 뒤 PR이 rebase 시 충돌은 pure-add union — 라벨 순서대로 이어붙이면 끝(기계적).
  - **builder fn**: 분산 배치로 충돌 자체를 회피 — A는 `_build_case_hx3005_join_coerce` 끝(≈1332) 뒤, B는 그보다 앞 HX3004 계열 builder 근처(예: `_build_case_e` 뒤), C는 `fn _run_case`(1649) 직전. 앵커가 다르면 자동머지.
- **catalog.hexa**: C 단독 → 충돌 없음.
- **CHANGELOG.jsonl**: 각 PR tail-append 1줄 → rebase 시 trivial 충돌(둘 다 유지).
- **wall_a_endgame.md census**: **C(최종 머지)만 갱신** — A·B는 건드리지 않기로 고정(3중 충돌 예방).
- **머지 순서 A→B→C 근거**: A=최소 diff+사용자 1순위+Error-band 오탐 제거, B=동일 guard 계열, C=파일 최다(types+catalog+test)라 마지막에 rebase 1회로 흡수 + census 갱신을 배치 종결로. types.hexa는 순서 무관(무충돌)이므로 등록부 라벨 순서가 곧 머지 순서.
- 실행: 격리 worktree 3개(`.worktrees/` 신규, `git -C` 절대경로), base=`064c4eee3`, PR은 `gh api`로 열기(auto-squash hook 회피), #4606 머지 후 retarget → 각 PR CI(3-target byteeq + selfhost-gates-summary) 개별 fix → 직렬 머지.

## 5. 위험 · 함정 · 미검증 지점

1. **#4606 의존**: A는 #4606이 만든 라인 수정 — #4606이 reject되면 A는 사장, B·C는 무관(독립 라인). 스택 base 관리 주의.
2. **B bare-return 보존**: `len(e.children) > 0` 조건 누락 시 E0069 클래스가 통째로 침묵 — 스펙의 핵심 함정. (ah)에 bare-return 양성 컨트롤 추가 권장(`fn f() -> i64 { return }` → 1 HX3004 유지).
3. **B의 실손실**: `x: i64 = v()`에서 v가 **진짜** unit을 반환해도 침묵 — call-arg(#4603)가 이미 수용한 동일 tradeoff(추론기가 미주석-fn과 진짜-unit을 구분 못 함). 미주석-로컬 추론이 들어와야 회수 가능.
4. **C string 제외 근거**: 런타임은 `s[i]`도 abort("use .chars()")하므로 원리상 fire 가능하나, dead-code 포함 corpus 전수에서 `s[i]`(GET) 0건 보장 못 함 → v1 제외, census 후 확장(다음 후보). int/float/bool/char는 corpus fire 시 CI RED로 검출.
5. **C 미검증 2점**: ① param-typed base(`fn f(n: i64)`)에서 base_t가 실제 i64로 추론되는지(HX3024의 `fn u(s: string)` 패턴상 참이나 케이스로 확인) ② `n[0] = 5` LHS-place에서 HEXA_STATIC_TYPES=1 시 r4 암과 double-report 없는지(elem_t `[]n` 미기록 → 침묵 예상, flag-ON 케이스로 확인).
6. **loosening의 byteeq 논증 한계**: "Error는 self-compile에 존재 불가" 논증은 **unbanded** Error에만 성립. HX3004/3001/3005 모두 unbanded 확인됨. carve-out 있는 코드(HX3024류)였다면 fixture-Warning이 stream에 존재 가능하므로 논증 불성립 — C의 신규코드에는 해당 없음(추가 방향이므로 census로 증명).
7. **남는 다음 후보(배치 밖)**: binop operand 재설계(방향성) · E0610 field-on-primitive(HX3026, double-report 설계) · HX3025 string-arm 확장(census 후) · 미주석-로컬 추론(대공사).

플랜 완료 — 이대로 3개 격리 worktree 병렬 구현 → PR → byteeq+aiden 검증 → A→B→C 직렬 머지하면 됩니다.
