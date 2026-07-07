# round8-1 rung note — HX3035 E0381 use-of-possibly-uninitialized

브랜치: `feat/borrowck-e0381-hx3035-uninit` (origin/main 기준 분기)
설계 SSOT: `round8_e0381_uninit_design.md` (Fable, reference-matched)
레퍼런스: `daegongsa_references.md` (#2 rustc_mir_dataflow MaybeUninitializedPlaces)

## 무엇을 했나
`HEXA_BORROWCK` 보로우체커에 forward MaybeUninitialized 데이터플로 rung 추가.
무초기화 `let x` 를 읽는 경로에서 초기화가 보장되지 않으면 **HX3035**(Warning, STRICT→Error).

## 배선 (심볼-앵커, 라인 아님)
- **레지스트리** — `_bck_in_borrow_rhs` decl 뒤 parallel arrays `_bcki_*` +
  `_bck_reset_fn` 리셋.
- **W1 등록** — 레트암 `_bind(ctx2, nm, dst.id)` 직후, `len(e.children)==0` (무초기화)만.
- **W2 use** — `_bck_check_use` 진입부, `!_bcki_in_place_base` 게이트로 USE-event.
- **W3 init** — plain assign `_push_stmt` 뒤, `did_reuse && lhs.kind=="ident"` → INIT-event.
- **W4 place-write** — field_set/index_set BASE lower 만 `_bcki_in_place_base` save/set/restore
  (key·RHS 제외), push 뒤 base tracked면 INIT-event (부분초기화=silent).
- **fixpoint** — `_bcki_check(entry_id)` (`_bck_nll_check()` 옆) : seed IN[entry]=1 · kill=INIT ·
  OR-join preds · cap `nb*4+8` loud bail · emit = `IN[block(u)]==1 && 같은-블록 선행 INIT 부재`.
- **emit** — `_bcki_emit_uninit_use` (`_bck_emit_use_while_mut` 클론, HX3035 전용 dedup).
- **catalog** — HX3035 완결 DiagSpec 블록 (parity 79/79).

## 경계 (FP=0 mandate)
- 필수 CLEAN: `if{x=1}else{x=2};use x` (OR-join dual) · `if c{return}else{x=1};use x`
  (return 분기 join-에지 생략) · `let x; x=1; use x` (블록내 순서) · unreachable(pred無→IN=0).
- silent: 부분초기화(field/index)·초기화된 let·param·match/for 바인딩·클로저.
- conservative-fire(레퍼런스 정합): no-else if 후 use · while 첫 반복 전 use · wildcard 없는 match 후 use.

## byteeq 중립
전 지점 `_bck_active`(기본 false) 게이트 · OBSERVE-ONLY(MIR 무변경) · 코퍼스 무초기화 let 0건 →
flag-ON 조차 diag 변화 0 (gen3≡gen4 이중 안전).

## companion probe (compiler/check/borrowck_test.hexa, `_run_uninit_probe`)
hz_use_before_init ×1 · hz_use_then_init ×1 · hz_loop_first_iter ×1 ·
fp_init_then_use 0 · fp_init_both_branches 0 · fp_return_branch 0 · fp_field_partial 0 · fp_normal_let 0.
OFF 전량 0 · STRICT error-band.

## 검증 (pool)
`hexa run compiler/check/borrowck_test.hexa` (OFF/ON/STRICT 3-mode) + types_test parse regression.
결과는 PR 본문·CHANGELOG 참조.
