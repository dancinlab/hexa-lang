# round5 R3 — HX3031 assign-behind-shared-ref (Rust E0594)

HEXA-OWN L5-E7. opt-in `HEXA_BORROWCK=1`(STRICT=Error). `let r = &s; r.f = v`/`r[i] = v`처럼
공유 `&` 로안을 통한 write는 E0594 위반(`&`는 read-only·`&mut`만 write-through 허용).

## 구현 (compiler/lower/hir_to_mir.hexa)
- `_bck_emit_assign_behind_ref` (write_through 헬퍼 클론·HX3031·same-site dedup·STRICT 재밴딩)
- field_set 후크(:3332 `_bck_note_write` 뒤)·index_set 후크(:3359 뒤): base ident가 live shared loan
  (`_bck_find_ref>=0` && `origin!=""` && `!_bck_ref_mut`)이면 emit.
- 신규 상태 0 — E2 loan registry(`_bck_ref_origins/lines/mut`) 그대로 재사용.

## conservative 경계
- ident 재바인딩 `r = v` 미포함(deref-write 아님·hexa `*r` 부재)·nested place `r.a.b`는 기존 게이트 배제.
- KILL row(origin "")는 liveness로 침묵(`let r=&s; r=other; r.x=1` 무발화).
- `&mut` 로안은 write-through 정당 → 무발화.

## byteeq중립
전부 `_bck_active`(기본 OFF) 게이트. `&`/`&mut` 인라인-carrier corpus 채택 ~0 → flag-ON도 real 0.

## catalog / test
- catalog HX3031 완결블록(fix_it_kind 포함·73→74/74). E0594 인용.
- borrowck_test: `_run_assign_behind_ref_probe`(HX3031 키드) + 4 src(hz_assign/hz_index=1·fp_mut/fp_no_borrow=0).
