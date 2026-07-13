=== B 재검증 상태 ===
RUNNING
=== Fable round7 설계 발사 (harness 캡처) ===
재대조 완료 — 모든 앵커 검증 끝났습니다. 최종 판정을 정리합니다.

---

# round7 배치 판정 (기준: origin/main `0657b2204`, 2026-07-07 06:22)

## 1. 실측 — E0507 앵커 재대조 결과

**round6 §3 R3 스펙은 유효하나 3곳 드리프트** (round6 A가 정확히 계획 삽입점에 선점 삽입됨):

| 앵커 | round6 §3 기재 | 현 origin/main 실측 | 판정 |
|---|---|---|---|
| call-arm ident-branch | :2627-2653 | **:2627-2651** (`if _bck_active && !_bk_is_method && kind=="ident"`) | 유효, 닫힘 -2줄 |
| 삽입점 | :2653/:2654 사이 | **:2651/:2652 사이** — :2652부터 round6 A(call-arg 차용 스캔 unop-분기)가 :2699까지 점유, :2700 `i=i+1` | **충돌 없음** — ident(:2627)/unop(:2671)/field(신규) 3분기가 조건 상호배타 sibling |
| `_bck_own_param` | — | :652 `(fn_name, idx)` ✓ | 유효 |
| `_bck_find_ref` | :715 | :715 그대로, liveness idiom = `_bck_ref_origins[i] != ""` (killed row는 origin="") | 유효 |
| HX3029 emitter | :968-994 | :968-994 그대로, 다음 fn(HX3032) :1002 | 유효 — 신규 emitter는 **:994/:996 사이** |
| catalog append | ":619 뒤" | HX3033(round6 D 선점)이 :621-628, HX4001이 :629 — **:628/:629 사이** | 재넘버 반영 |
| corpus regex | "HX3033→3034 재넘버" | `.github/workflows/static-types-corpus.yml:175` = `HX30(1[167]|2[4-6]|3[03])` — **static 코드 전용, borrowck 코드(3019~3032) 원래 불포함** | **corpus regex 변경 불요** (round6의 regex 항목은 구 static-R4용이었음) |
| probe 클론원 `_run_mvb` | :1171 | **:1216** (빌더 `_build_mvb_module` :1169), 호출부 :1496-1498, 신규 호출 삽입점 = **:1506/:1509 사이** | 드리프트만 |
| HX3034 | next-free | 전 repo grep **0건** ✓ · catalog parity 현행 **77/77** (`DiagSpec {`=77, `fix_it_kind:`=77) | 사용 가능 |

round6 A와의 시맨틱 충돌도 없음: A는 arg kind=="unop"(`&x`/`&mut x`)만, E0507은 kind=="field"만 취급. `callee_text`는 :2594에서 설정되어 루프 내 스코프 유효. field HIR 노드 = `kind:"field", text:field명, children[0]:base` (types.hexa:3485 주석으로 교차확인).

## 2. 잔여 저비용 후보 스캔 → **1개 생존: HX3033 ident-쌍 확장**

round6 §5.5 이월 4건 재평가:

- **R4 ident-쌍 (`c == d` 상이-enum) — 채택(R7-R2)**. 실코드 판정: ① param×param(양측 `named:` known)은 unknown-arm(:3618)에 진입 못 하고 compare-arm(:3728)의 `_types_assignable` 실패 → **기존 HX3001이 이미 REJECT**(구조 확인, :3733-3746). ② **block-local×block-local·param×block-local은 오늘 완전 침묵** — unknown-arm 도달하나 gate ①(:3640)이 "≥1측 EnumPath 리터럴"을 요구. 그런데 `_types_operand_enum_name`(:2119-2128)은 **이미 ident의 `{}slot`/type 복구를 내장** → gate ① 삭제만으로 커버 확장. 신규 HX 코드·catalog 블록·상태축 전부 불요, corpus regex도 `3[03]`에 33 기포함 → **비용 최저 확장**.
- **arr[str] — 연기 유지(round8)**. 결정적 사실 발견: `hexa_array_get`의 C 시그니처가 `(HexaVal arr, int64_t idx)`(runtime_core_emit:2822) — idx는 호출부에서 int64로 강제변환되므로 string 인덱스는 **abort가 아니라 silent 오독**일 개연성. "guaranteed-runtime-error → REJECT"(HX3024/25) 계약이 성립 안 하고, silent-bug(HX3030류) 계약으로 가려면 `arr["k"]` 실거동 측정(pool probe)이 선행 필수. 미측정 → 연기.
- **map-key — 연기 유지**(동일 클래스: 런타임 거동 미측정).
- **match-arm·assign-arm·return DROP분 — DROP 유지**. 근거 구조 무변: assign-arm의 "rhs_t=`_infer_expr` 무제한" 논거는 #4644(let-RHS BinOp) 이후 오히려 강화, match-join은 HX3005 arm-join default-ON 그대로.

## 3. 배치 확정: **round7 = R1 HX3034(E0507) + R2 HX3033 ident-쌍 확장** (2-rung)

### R1 — HX3034 E0507 move-out-of-borrowed-content (own L5-E9)

**(a) hir_to_mir.hexa — 검사 분기, :2651/:2652 사이 삽입:**
```
// HEXA-OWN L5-E9 — move-out-of-borrowed-content (Rust E0507). `g(r.f)`
// where `r` is a live `&`/`&mut` ref binding and g's param is @own …
if _bck_active && !_bk_is_method && e.children[i].kind == "field"
    && len(e.children[i].children) > 0
    && e.children[i].children[0].kind == "ident" {
    let _bk_mo_base = e.children[i].children[0].text
    if _bck_own_param(callee_text, i - 1)
        && _mir_lookup_global(ctx_r, _bk_mo_base) < 0 {
        let _bk_mo_ri = _bck_find_ref(_bk_mo_base)
        if _bk_mo_ri >= 0 && len(_bck_ref_origins[_bk_mo_ri]) > 0 {
            _bck_emit_move_out_of_borrow(_bk_mo_base, e.children[i].text,
                _bck_ref_origins[_bk_mo_ri], _bck_ref_mut[_bk_mo_ri],
                _bck_ref_lines[_bk_mo_ri], e.children[i].span)
        }
    }
}
```
- `!_bk_is_method` 필수(§3에 미기재였음 — receiver-first가 `i-1` 인덱스를 깨므로 ident-branch와 동일 게이트). `_mir_lookup_global` 가드는 R6-A 관용구 미러(belt-and-braces).
- **&/&mut 둘 다 fire**(mutability-blind) · **report-only**(`_bck_note_move` 호출 안 함 — move 분류는 bare-ident 불변). HX3027 선점 없음(읽는 것은 ref binding 자체, origin이 아님) → &mut에서도 HX3034 단독.

**(b) emitter — :994/:996 사이,** `_bck_emit_move_while_borrowed`(:968-994) 클론:
```
fn _bck_emit_move_out_of_borrow(name: string, field: string, origin: string,
                                borrow_mut: bool, borrow_line: i64, sp: Span)
```
공유 `_bck_e_lines/_bck_e_cols` same-site dedup + `_bck_strict` Error 재밴드 동일. diag args: `name`·`field`·`origin`·`borrow_kind`(immutable/mutable)·`borrow_line`, `diag_new("HX3034")`.

**(c) catalog.hexa — :628/:629 사이 완결블록 append** (★catalog-hexa-1):
- code HX3034 · title "cannot move out of borrowed content" · **Severity::Warning · stage "S3"** · `fix_it_kind: FixItKind::None`
- template: `` cannot move out of `{name}.{field}` which is behind a {borrow_kind} reference — `{name}` borrows `{origin}` (line {borrow_line}) ``
- explain 필수요소: opt-in `HEXA_BORROWCK=1`/L5-E9 · Rust E0507(rustc_borrowck, "cannot move out of `*r` which is behind a shared reference") · **mutability-blind 근거**(& 뒤 내용물 move는 & /&mut 무관 금지 — E0507은 &mut에서도 fire) · report-only(no move mark) · conservative 경계(single-ident base만·nested `r.a.b` silent·same-fn loan·killed loan silent·global base skip) · corpus adoption 0 → flag-ON에도 fire=0(HX3029와 동일 지위, "fires on ZERO real source" 문구) · STRICT 재밴드 · flag-OFF byte-identical.
- 머지 후 parity **78/78** 확인: `grep -c 'DiagSpec {' == grep -c 'fix_it_kind:'`.
- **corpus regex(.yml:175) 변경 없음** — borrowck 코드는 regex 대상 외.

**(d) companion test — borrowck_test.hexa:** `_build_mvb_module`(:1169)/`_run_mvb`(:1216) 클론 `_build_mob_module(with_loan, mut_loan, ref_base)` + `_run_mob(label, …, want34_on)`, 호출부 **:1506/:1509 사이** 4케이스:
1. `hz_move_out_shared_borrow`: `let a=[1]; let r=&a; g(r.f)` → HX3034 ×1
2. `hz_move_out_mut_borrow`: `let r=&mut a; g(r.f)` → HX3034 ×1 (HX3027 ×0 — 단독성 검증)
3. `fp_move_out_plain_copy`: `let r=a; g(r.f)` → ×0 (non-ref binding)
4. `fp_move_out_owner_base`: `g(a.f)` → ×0 (owner 직접)
각 케이스 stray-diag==0 · OFF sweep 전량 0 · STRICT시 error-band==want · `len(mm.funcs)==2`. hand-HIR field 노드 = `_hx("field","f",[_hx("ident","r",[],4)],4)` (@own은 `_ann1("own","p")`+`_ann1("param_names","p")` 그대로).

### R2 — HX3033 ident-쌍/known-value 확장 (static, 라벨 **au**)

- **types.hexa :3640** — gate ① 삭제: `if _types_is_enum_path_kind(children[0]) || _types_is_enum_path_kind(children[1])` 외곽 if 제거(내부 ln/rn 복구+`_types_enum_registry_has` 양측+`ln != rn` 게이트는 그대로 = 진짜 안전게이트). EnumPath 아닌 조합(ident×ident·ident×call 등)도 양측 enum명이 복구·등록·상이할 때만 fire. scalar/struct/미등록/cross-module은 `""`/registry 필터로 기존과 동일하게 silent.
- catalog HX3033 explain만 현행화("at least one operand is an Enum::Variant path literal" 문구 → 값-피연산자 쌍 포함으로) — 신규 DiagSpec 없음, parity 불변.
- corpus regex 변경 불요(33 기포함) → **census GO/NO-GO 자동**: self-compile census HX3033 fire=0 필수, >0이면 이 rung 단독 드랍.
- test (au): (as) 클론 — ① block-local 쌍 `let c: Color … let d: Dir … c == d` → 1 ERROR ② same-enum 쌍 → 0 ③ param×block-local 혼합 → 1 ④ fixture → WARNING ⑤ **HX3001 비간섭 컨트롤**: param×param 쌍 → HX3033 ×0 (기존 HX3001 경로, unknown-arm 미도달 — round6 §5.1 "프로브 미검증"을 이 케이스로 박제).

## 4. byteeq 중립 논증
- **R1**: `_bck_active` OFF(기본) 시 분기 자체 미도달·레지스트리 무접촉. ON에서도 report-only(diag push만, MIR 무변형) — HX3029~3032와 동일 계약. OFF sweep probe가 빈 스트림을 박제.
- **R2**: S3 diag-only, 타입은 MIR에서 erase — 심각도만 real-source Error/fixture Warning(`_types_strict_for` carve-out, HX3033 기존 구조 그대로). 발화 증거게이트 완화일 뿐 코드젠 경로 무접촉. census fire=0가 real-source REJECT 무해성 심판.

## 5. 머지 전략
- round6 B(`fix/hexa-own-rungB-hx3012-uam`) 실측: **types.hexa 4-hunk(@1450·@3492·@3553·@3654)+types_test append만** — catalog 무접촉.
- **R1은 B와 파일 완전 비중첩**(hir_to_mir·catalog·borrowck_test) → B 검증과 무관하게 **즉시 선행 가능**. 유일 공유 = CHANGELOG.jsonl line1(매 rebase 재해결).
- **R2는 B 착지 후 rebase 권장**: B의 4번째 hunk(@3654, binop lt/rt 직후 own-lint 후크)가 같은 함수 ~30줄 위 — hunk 비중첩이라 자동머지 예상되나, types_test 꼬리 append는 확실 충돌 → **★types-test-hexa-1: main 리셋+재적용, union merge 금지**. B 드랍 시 R2는 origin/main 라인(:3640) 그대로 착지(B 머지 시 gate 위치 ~:3696으로 +56 드리프트).
- 순서: **R1 → (B 착지 대기) → R2**, rung별 독립 PR·`.hexa` changelog 게이트·3-target PR-CI GREEN. R1 후 parity 78/78 grep.

## 6. 대공사 3개 경계 재확인 — round7 **불포함 확정**
lifetime(E0597/E0716)=loan별 scope-depth 축 신설 · uninit(E0381)=init-lattice+branch-join 축 신설 · closure(E0504)=capture 분석 축 신설. round6 A~D 머지분 어디에도 이 축들의 부분 착지는 없음(전부 기존 E2 loan-registry/env-slot 재사용) → 세 건 모두 신규 상태축 필요 그대로 = round8+ 대공사 유지.

## 미검증 (구현 시 확인 필수)
1. **R1 probe의 field-lowering 무해성** — hand-HIR `g(r.f)`에서 `_lower_hexpr` field-arm이 stray diag 없이 통과하는지는 probe 실행으로만 확정(케이스별 stray==0 체크가 자동 심판).
2. **R2 census fire=0** — self-compile 코퍼스에 cross-enum 값-비교가 실존하면 NO-GO 드랍(기존 워크플로 regex가 자동 검출).
3. **R2 컴파일속도** — `_types_operand_enum_name`이 unknown-side `==`/`!=` 전건에서 env 선형탐색 추가. HX3030이 match에서 동일 비용을 이미 지불 중이라 중립 추정이나 미측정.
4. arr[str]의 `__hx_to_int(string)` 실거동 — round8 진입 전 pool 1-probe(`arr["k"]` 실행)로 abort/silent 판정이 선행조건.
