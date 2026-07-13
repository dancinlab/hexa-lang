main census: in_progress
=== Fable round6 §3 full 재발사 ===
# 2-lane round6 배치 — 4-rung 최종판 (전 앵커 2026-07-07 실코드 재검증 완료)

기준: **origin/main `cc2e19a80`** (= 선행 설계 기준 ef96be5b0 + strtod #4645 1커밋, compiler/ 무접촉 — 아래 라인 전부 오늘 실코드로 재대조·일치 확인). 선행 2패스 상충(E0507 채택 vs 기각)은 재실측으로 판정된 최종판입니다. `state/` 재박제는 이번 세션도 write 미허가로 불가 — **본 메시지가 설계 전문**입니다(구현 첫 커밋에 박제 권장).

## 1. 실측 — 후보별 verdict

| 후보 | verdict | 실코드 근거 |
|---|---|---|
| O-a E0507 | **채택 (R3, HX3033)** | fire-surface-0(@own 0 × `&` 0) 기각논거는 기착지 HX3029도 동일(catalog explain에 "fires on ZERO real source" 명시) → parity-ladder에서 비차별. 기존 후크 전부 재사용 = 비용최저 |
| O-b HX3012 확장 | **채택 (R2)** | `_own_lint_touch`가 `_types_is_ident` 게이트(types.hexa:1434) — field/index **base** READ 완전 미커버 |
| O-c call-arg 차용 스캔 | **round7** | 신규 pairwise 스캔 시맨틱스 + arg-position `&` lowering 미검증 |
| O-c′ E0503 확장 | **불필요** | base ident가 전부 `_lower_hexpr` ident-arm(`_bck_check_use`) 통과 → 구조적 기커버 |
| O-d (E0597/716·E0381·E0504) | **기각 유지** | 신규 상태축(scope-depth/init-tracking/closure) = 대공사 |
| S-a match-join | **DROP** | HX3005 arm join default-ON(`_check_match`·`_types_assignable`·(af)/(ag) 박제) — 갭 없음 |
| S-b assign-arm | **DROP** | r3 rhs_t = `_infer_expr` 무제한(binop/unop 포함)·LHS ident/index/field 완비 |
| S-c return | **DROP** | val_t kind 무제한 + concrete frame_ret 항상 fire |
| S-d 컨테이너 오용 | **string-수신자만 채택 (R1)** | HX3026 조건(:3443) int/float/bool/char만 — string 제외가 유일한 측정된 대칭 갭(HX3025는 :3385에서 string 기포함). map-key=런타임 거동 미측정 → 연기 |
| (신규) wrong-enum `==`/`!=` | **채택 (R4, HX3034)** | EnumPath infer=empty(:3210) → check_binop unknown-조기귀환(:3524-3535)이 compare를 무조건 bool 통과 → `c == Dir::North` **오늘 완전 침묵**(항상-false, HX3030 버그류) |
| (신규) arr[str] | **round7** | bounds-abort 클래스(약한 REJECT 논거) + base 증거 협소 |

## 2. 배치 (정적 2 + own 2 · 라벨 R1=**ar**, R4=**at** — `as`는 cast 키워드 충돌 회피 skip)

R1 HX3026 string-수신자 → R2 HX3012 field/index-base use-check → R3 HX3033 E0507 → R4 HX3034 wrong-enum eq. 전 rung이 types.hexa **let-arm 비접촉 + catalog HX3011 블록(:357-365) 비접촉** = r5-R2 충돌 회피 충족.

## 3. rung별 impl 스펙

**R1 — HX3026 string-수신자 (static, ar)**
- `compiler/check/types.hexa:3443` 조건 1-token: `|| recv_t.kind == "char"` 뒤에 `|| recv_t.kind == "string"`. emit(:3444)·`_types_callee_depth==0`·`!_is_builtin_method` 게이트 기존 유지(string builtin 셀렉터는 ~90-member 집합이 이미 EXEMPT).
- catalog :525-533 HX3026 **explain만** 현행화(+string, HX3025 편입과 동일 계약 문구). corpus regex(:175)는 `2[4-6]`으로 26 **기포함** — 변경 불요, census fire=0 확인 후 머지.
- test (ar): (ap) 클론 — source-path 1 ERROR·fixture WARNING·`s.len` 0-fire 컨트롤.

**R2 — HX3012 field/index-base use-check (own L2-r3)**
- 신규 `fn _own_lint_check_use(use_node, out)`을 `_own_lint_touch` 닫힘 **:1450 뒤**에: **report-only**(state-1 push 안 함) — `_own_lint_find` hit && `states[idx]==1`일 때만 `_emit_hx3012`. same-span **rep-dedup 배열 2개**(`_own_lint_rep_lines/cols`, 2-pass 재-infer 대비) + `_own_lint_reset()`(:1399) 본문에 reset 2줄(:5181 per-FN 경유 자동).
- 후크 2곳, 기존 관용구(`env("HEXA_OWN_LINT")=="1" && _types_is_ident(e.children[0].kind)`) 그대로: **Index arm :3387 뒤**(HX3025 블록 닫힘~:3388 사이), **Field arm :3445 뒤**(HX3026 블록 닫힘~`let recv` :3446 사이). method receiver는 Field-infer 자동 커버(이 후크엔 callee-depth 게이트 없음 — 의도).
- catalog :365-374 HX3012 explain 현행화. 신규 DiagSpec 없음.

**R3 — HX3033 E0507 move-out-of-borrowed-content (own E9)**
- shape: `let r = &v`(또는 `&mut`) live에서 `f(r.field)`, callee param `@own`.
- `compiler/lower/hir_to_mir.hexa` call-arm ident-branch(:2627-2653) **닫힌 직후(:2653/:2654 사이)** sibling 분기: `e.children[i].kind=="field"` && base child ident && `_bck_own_param(callee_text, i-1)` && `_bck_find_ref(base)`(:715) live row → emit. **&/&mut 둘 다 fire**(E0507 mutability-blind). **report-only — `_bck_note_move` 안 함**(move 분류 bare-ident 불변). &mut에서도 HX3033 단독(HX3027 선점 없음 — base read는 ref-binding 자체라 origin-loan 스캔 비적중; HX3029의 shared-loan-primary와 다름, explain에 명시).
- emitter: HX3029 emitter(:968-994) 클론 `_bck_emit_move_out_of_borrow(name, field, origin, borrow_mut, borrow_line, sp)`을 **:994/:1002 사이**에 — 공유 `_bck_e_lines/cols` dedup + `_bck_strict` 재밴드 동일.
- catalog **:619 뒤** append — 완결블록(Warning/S3·template ``cannot move out of `{name}.{field}` …``·fix_it_kind 포함) → parity **77/77**.
- probe: borrowck_test `_run_mvb`(:1171) 클론 `_run_mob` hand-HIR — shared→1·mut→1·no-loan→0·plain-local base→0.

**R4 — HX3034 wrong-enum `==`/`!=` REJECT (static, at)**
- 삽입: check_binop **:3515 직후·:3524 조기귀환 앞**(EnumPath=empty type이라 조기귀환 뒤면 도달 불가).
- 게이트(신규 헬퍼 `_types_binop_enum_evidence`, 전부 HX3030 재료): ① `op=="=="||"!="`(ordered는 E0369 별도류, 제외) ② ≥1측 bare-EnumPath AST → head resolve+`_types_enum_registry_has` ③ 반대측 = EnumPath head / `_types_struct_name_of` / `{}name` env-slot(:3866-3869 관용구), alias resolve+registry ④ 양측 registered && 상이 → `_emit_hx3034`(HX3030 emitter :2100 클론). emit 후 fall-through(:3524가 bool 반환) — diag-only.
- catalog HX3033 뒤 순차 append(Error/S3·fixture carve-out 문구 HX3030 계승) → parity **78/78**. corpus :175 `30`→`3[04]`.
- **census GO/NO-GO**: self-compile census HX3034 fire=0 필수 — >0이면 이 rung **단독 드랍**(최후미 배치 이유).
- test (at): `c == Dir::North`(c: Color) 1 ERROR·같은 enum 0·fixture WARNING·unknown-head 0.

## 4. 머지 전략
- **R1→R2→R3→R4 직렬 rebase**, rung별 독립 PR. 예상 충돌: R1/R2 Field-arm 인접(:3443-3444 vs :3445 뒤) keep-both 1회 · catalog R3/R4 순차 append · CHANGELOG.jsonl line1 전원(매 rebase 재해결).
- parity 체인 76(현행 검증완)→77→78, 매 머지 `grep -c 'DiagSpec {' == grep -c 'fix_it_kind:'`.
- **r5-R2(HX3011 aq pending)와 무순서 독립** — 전 rung hunk 비중첩(유일 근접=catalog :357-365 vs :366-374 인접 블록). 머지/드랍 어느 쪽이든 진행 가능.
- byteeq 중립: R1/R4=S3 diag-only(+census fire=0 전제)·R2=`HEXA_OWN_LINT` opt-in·R3=`_bck_active` OFF 게이트. 각 rung `.hexa` changelog 게이트 + 3-target PR-CI GREEN 후 머지.

## 5. 미검증 / 위험
1. **R4 `c == d` ident-쌍** — HX3001 기발화 **추정, 프로브 미검증**(이번 게이트 밖·round7 확장 전 프로브 필수).
2. **R1** `_is_builtin_method`의 string 셀렉터 완전성 가정 — census fire=0가 최종 심판(regex 26 기포함이라 자동 검출).
3. **R3** fire-surface=0(실소스 무발화) — HX3029와 동일 지위로 채택.
4. **R2** rep-dedup 필요성은 touch-side 유추 — probe 케이스로 박제 필수.
5. round7 이월: arr[str]·call-arg 차용 스캔·R4 ident-쌍·map-key 오용.
