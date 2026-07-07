# round9 REJECT 배치 — HX3038/3039/3040/3041 (opt-in borrowck · byteeq-neutral)

Branch: `feat/borrowck-round9-hx3038-3041` · 단일 PR (4-rung 상호의존: call-arm + return-arm 영역 공유).
gap-census(rustc 대비) frontier = **LOW-COST-REMAIN** — hook-reuse rung들만 남음. 전원 `HEXA_BORROWCK`
(`_bck_active`) 게이트 + report-only(MIR 무변경) → flag-OFF 경로 diag 스트림 + emit 바이트 불변.

## 배치 스펙 (census synth 원문, origin/main 소스에 grounded)

- **HX3038 = E0508** (cannot move out of type `[T;N]` by indexing): `sink(a[i])`에서 `a`가 같은-fn
  소유-로컬 배열(bare-ident base, non-global)이고 callee param i-1 이 `@own`. call-arm 의 HX3034
  `kind=="field"` 형제로 `kind=="index"` 분기 신설, 소유-배열 base → 신규
  `_bck_emit_move_out_of_array`(HX3034 이미터 클론). report-only(`_bck_note_move` 미호출).
- **HX3039 = E0507** (index-projection borrow-move): `sink(r[i])`에서 `r`가 라이브 ref 로안(E2
  registry `_bck_find_ref`, origin!=""). 같은 index 분기, base로 split: ref-base → 신규
  `_bck_emit_move_out_of_borrow_index`(index-shaped template) · 소유-배열 base → HX3038.
  mutability-blind, report-only.
- **HX3040 = E0505** (non-call move-while-borrowed): `@own` 바인딩의 bare-ident RHS/return 이 라이브
  로안 존재 중 move — 기존 `_bck_ref_find_write_through` 스캔을 let-arm / assign-arm / return 3개
  사이트에 배선(HX3029는 call-arg 사이트에서만 loan-scan). 신규 state 축 없음.
- **HX3041 = E0515** (return-ref-to-temporary): `return &<rvalue>`(inner = call / struct-lit /
  array-lit / binop, named local 아님). return-arm `&/&mut` unop 분기(현 `_bk_inner.kind=="ident"`
  게이트=HX3019)에 형제 arm 추가 → 신규 `_bck_emit_ret_temp`.

## rung notes (구현 확정 사항)

- **앵커 전원 SYMBOL 재확인**(라인 아닌 grep): call-arm `kind=="field"` HX3034 분기(현 hir_to_mir),
  `_bck_emit_move_out_of_borrow`, `_bck_find_ref`/`_bck_ref_find_write_through`, `_bck_own_param`,
  `_mir_lookup_global`, return-arm `_bk_inner.kind=="ident"` 게이트, `_bck_emit_ret_escape`,
  `_bck_active` — 스펙과 불일치 앵커 0.
- **★스펙-vs-하네스 정합(불가피 해석)**: 스펙 문구 "기존 이미터 재사용"(3039/3040/3041)을 그대로 따르면
  기존 코드(HX3034/HX3029/HX3019)를 emit → 그러나 borrowck_test 러너는 `_count_code(d,"HX30xx")`로
  코드별 키잉 + `other==0`(stray) 검사. catalog-parity(81→85, 코드별 hz ×1) 하드 요구와 상충 →
  **코드별 이미터 클론**만이 유일 정합해(코드베이스 관례: HX3034=move_while_borrowed 클론, HX3037=
  move_out_of_borrow 클론과 동일). 스펙의 "재사용"은 로직/스캔 재사용 + 이미터 클론으로 해석.
- **HX3040 @own 게이트 인프라**: `@own`은 param-only 어노테이션 → 로컬 bare-ident이 @own인지 판정 위해
  신규 `_bck_own_pnames`(module-lifetime 병렬 NAME 열, pre-pass 6861에서 push) + `_bck_cur_fn`
  (per-fn setup에서 set) + `_bck_is_own_binding(fn,name)` 헬퍼 추가. 이 게이트가 hexa reference-value
  배열/구조체의 일반 handle-copy(`let b=a`)를 침묵시키는 FP-killer.
- **정직 caveat(catalog explain 박제)**: hexa 배열=reference aggregate → `a[i]`는 handle-copy READ →
  HX3038은 E0508 REJECT surface에 대한 **@own-aliasing hazard**로 충실(문자 그대로의 hole mechanic
  아님). HX3041은 return-borrow를 rustc대로 dangling 분류(hexa arena free-model 대비 미증명) —
  shipped HX3019 동일 stance.
- **catalog parity**: `grep -c 'DiagSpec {'` == `grep -c 'fix_it_kind:'` == 85 (81+4). 각 신규 블록은
  자기 `fix_it_kind: FixItKind::None` + `},` 통째 포함(공통-suffix 공유 회피 = convergence
  catalog-hexa-1 재발방지).

## 테스트 프로브 (borrowck_test.hexa · self-contained · error-band STRICT)

- HX3038: hz=owned-array(`sink(a[0])` @own) ×1 / fp=non-@own arg ×0.
- HX3039: hz=ref-base(`let r=&a; sink(r[0])`) ×1 / fp=global-base(`sink(g[0])`, global-skip) ×0.
- HX3040: hz=let(`let b=a`)·assign(`b=a`)·return(`return a`) 3사이트 각 ×1 / fp=killed-loan(re-let r) ×0.
- HX3041: hz=call(`&make()`)·struct(`&P{x:1}`)·binop(`&(x+1)`) 각 ×1 / fp=`return &g`(global) ×0.
- 3-mode: OFF 전원 ×0(empty stream) · ON 각 hz ×1/fp ×0 · STRICT error-band == 코드 count.

## 검증 (verify-done: evidence)

verify_output → PR 본문/에이전트 리턴 참조 (aiden 3-mode borrowck_test + `hexa run types_test.hexa`
파스회귀無 캡처).

## census frontier verdict — LOW-COST-REMAIN 소진, 잔여 = 5 HIGH-cost 대공사

round9로 hook-reuse(기존 스캔/이미터 클론, 신규 state 축 0~최소) LOW-COST rung은 소진. 잔여 rustc
갭은 전부 **대공사**(신규 flow-analysis / place-projection / 시맨틱 flip / interprocedural / region
inference 인프라 필요):

1. **NLL flow-sensitive liveness (region inference)** — 현 flow-insensitive FP 클래스(use-then-write
   HX3023, use-then-move) 제거. `_bck_nll_check` reach-matrix를 loan-region 계산으로 승격.
2. **Place-projection granularity** — Operand에 field/index place-path 도입, 현 whole-local grouping
   대체 → disjoint-field 동시 차용(E0499 정밀도), 부분-move 추적.
3. **Interprocedural move/borrow summaries** — `@own` 반환·borrow-반환 fn 요약(cross-fn). 현 same-fn
   한정을 넘어서는 요약 계산 + fixpoint.
4. **Move-by-default (A3) 시맨틱 flip** — bare-ident aggregate 복사를 코퍼스 전역 실제 move로 전환 +
   Copy 분류 + 자동 clone 삽입 + byteeq re-baseline(비-neutral, 대규모).
5. **Named lifetime / region 파라미터 + generic lifetime 추론** — E0621/E0623 계열, 전면 region
   추론 엔진.

(즉시 follow-on, 상대적 저비용이나 이번 배치 외: E0515 projection 변종 `return &local.field` /
`&local[i]` — return-arm base-walk to head ident + `_mir_lookup_global<0` 가드로 HX3041에 fold 또는
HX3042. HX3041 explain에 박제됨.)
