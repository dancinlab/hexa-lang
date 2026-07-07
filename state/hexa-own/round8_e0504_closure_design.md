# round8-3 (LAST 대공사) — HX3037 closure capture-move (Rust E0507) — 착지 노트

라벨: E0504 (원장 연속성) · rustc 메시지 = **E0507** "cannot move out of `X`, a
captured variable in an `FnMut` closure". catalog explain에 매핑 명시.
브랜치: `feat/borrowck-e0504-hx3037-closure-move` (origin/main 53ee90270 기준).

## Fable 판정 재확인 — 대공사 아님 (저리스크)
1. capture 모델 = `_collect_free` 이미 존재(enclosing-local free-var, ordered+dedup).
2. hexa의 move 소스 = `@own` call-arg 단 1종 → 검출이 **읽기 전용 HIR 워크**로 환원.
   MIR/local-id/dataflow 불요 → `_bck_active` suspend(fresh id 공간) 근본원인 완전 우회.
3. FnOnce 미구분이 문제 안 됨 — hexa closure는 전부 `hexa_callN` 다회 호출 →
   "캡처 move-out = 항상 위험"이 정확. 게다가 env-array by-value의 aggregate slot이
   enclosing binding과 힙 객체 alias → 1회 호출로도 양쪽 UAF(rustc보다 강한 근거).

## 구현 (심볼 기준 재앵커 — 라인은 드리프트했으므로 grep으로 확정)
- **scanner** `_bck_closure_capture_move_scan` — `_collect_free` 직후 배치.
  재귀 HExpr 워커: `k=="call"` && children[0]=ident callee → arg i(ident)가
  `_strip_mut_prefix` 후 `!bound ∧ free 멤버 ∧ _bck_own_param(callee, i-1)` → emit.
  `let`/nested `closure`는 bound2 확장 후 계속 하강. report-only(`_bck_note_move` 미호출).
- **emitter** `_bck_emit_capture_move` — `_bck_emit_move_out_of_borrow` 클론.
  same-site dedup(`_bck_e_lines/_bck_e_cols` 공유) → `diag_new("HX3037")` +
  args name/callee/closure_line → STRICT re-band(`diag_with_severity`) → `_lr_diag.push`.
- **hook** `_lower_closure` `let nfree = len(free)` 직후, suspend(`_bck_active=false`) 이전:
  `if _bck_active && nfree > 0 && nc >= 1 { scan(body, pnames, free, e.span.line) }`.
  enclosing `_bck_active` 게이트 → flag-OFF zero work.
- **catalog** `compiler/diag/catalog.hexa` HX3037 완결블록(HX4001 앞 삽입, 공통-suffix 공유 회피).
  DiagSpec 80→81 / fix_it_kind 80→81 (catalog-hexa-1 정합). explain에 E0507 매핑 명시.
- **test** `compiler/check/borrowck_test.hexa` — `_run_capture_move_probe`(HX3037 키) +
  6 probe. inline `@own` 파서 캐리어가 main 실동작 → 소스 프로브(hand-built HIR 불요).

## probe matrix (OFF 전량 0 / ON hz×1·fp×0 / STRICT error-band)
| probe | 기대 |
|---|---|
| hz_clo_capture_move | ×1 |
| hz_clo_nested_capture_move | ×1 (하강 증명) |
| fp_clo_param_not_own | 0 |
| fp_clo_own_arg_is_param | 0 |
| fp_clo_shadow_let | 0 (free 제외) |
| fp_clo_enclosing_direct | 0 (Rule 2 소관·이 rung 무관) |

## byteeq-neutral 논증
스캔·emit 전부 `_bck_active` 게이트(기본 false, HEXA_BORROWCK opt-in) · flag-ON도
HExpr 읽기전용 + diag push뿐(MIR/codegen 무변경) · suspend 상태기계 미접촉(save 이전 완료).
corpus `@own` 채택 0 → flag-ON diff 0.

## 문서화 FN
field/index-arg(`sink(s.f)`) 캡처-move 미검출(bare-ident only) · 간접호출/캡처된
fn-value 미검출 · 내부 lambda 자체 local 캡처 미검사 · use-before-shadow silent(free over-approx).

## 검증
aiden(summer 대체) 3-mode + `hexa run compiler/check/types_test.hexa` — PR 하단/커밋 참조.
