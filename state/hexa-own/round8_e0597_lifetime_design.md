# round8 대공사-2: HX3036 / E0597 "borrowed value does not live long enough"

구현 rung 노트 (Fable 설계 `round8_lifetime_design.md` 정답지 기반, reference-match rustc NLL / RFC 2094).
브랜치 `feat/borrowck-e0597-hx3036-dangle` · origin/main(@ #4660 HX3035 착지 후) 분기.

## 0. 판정
E0597 = M4 forward-reachability 패턴의 3번째 인스턴스(E0381이 2번째). region 풀셋/backward liveness
불요 — emit 조건 "scope-death 블록 → use 블록 CFG 도달성"이 `_bck_nll_check` reach-matrix와 동형.
E0716(HX3037)은 이번 라운드 SKIP(temporary loan은 현 표면 비표현 → round9).

## 1. 메커니즘 (LANE 격리)
기존 let-lane `_bck_ref_*`는 한 글자도 안 건드림. 신규 asn-lane 전용 배열:
- 어휘 스코프 로그 `_bck_sc_names/_dead` — 모든 `let`에서 push, scope-exit sweep에서 tail dead.
  append-only+dead 비트 → 인덱스 永久-unique(origin-shadow 정확 매칭).
- asn-lane loan registry `_bck_asn_names/_origins/_lines/_odecl/_done` — assign-arm `r = &x` 전용
  (let-arm loan은 r의 스코프 ⊆ x의 스코프라 구조적 dangle 불가). `odecl`=track 시점 origin의 최신
  scope-log 인덱스(-1=param/global). `done`=sweep 종결(재매칭 차단).
- dangle 이벤트 `_bck_dg_rows/_blocks/_lines/_seqs` — scope-exit sweep 산출: 죽는 스코프 안에서
  origin이 죽는데(odecl≥w) loan 바인딩은 바깥(scope idx<w)일 때.
- asn-lane use 이벤트 `_bck_au_rows/_blocks/_seqs/_spans` — use 시점 newest-live asn row 스냅샷
  (재할당-후-use FP 차단의 핵). `_bck_evseq` 단조 카운터 same-block 순서.
- `_bck_ref_outlives_check`(fn 끝) = `_bck_nll_check` reach-matrix 클론. use 발화 ⇔ 같은 row의
  dangle이 (a) same-block program-order(d.seq<u.seq) 또는 (b) cross-block reach≥1.

## 2. 후킹 (SYMBOL 재앵커 — 설계 line은 r8-e0381 worktree 기준이라 grep으로 재확인)
- S1 상태: `_bcki_e_cols` 선언 뒤 + `_bck_reset_fn` reset 추가.
- S2 scope push: let arm `_bind` 직후 (`_bck_active && len(nm)>0`).
- S3 asn track/kill: assign-arm ident 경로 `return _no_value(ctx2)` 직전 + let arm 재선언 cross-lane kill.
- S4 sweep: `block` arm(순수 어휘 순회) — 진입 `_bk_sc_w`, 종료 전 `_bck_scope_exit` 1회.
- S5 use event: `_bck_check_use` E0503 블록 뒤 · `_bck_find_local` early-return 앞.
- S6 종단: `_lower_fn` 끝 `_bcki_check` 옆 `_bck_ref_outlives_check()`.
- emit `_bck_emit_ref_outlives` = `_bcki_emit_uninit_use` 클론(HX3036 4-arg · Warning · STRICT→Error).

## 3. FP-0 (conservative)
HAZARD: `let mut r=&y; { let x=5; r=&x } use r` → same-block seq.
침묵: 스코프 내 use(seq 역전) · 재할당-후-use(row 스냅샷 상이) · 형제분기(CFG 도달無) · param/global origin.
byteeq: 전 상태 전역배열+`_bck_active` 첫-피연산자 게이트 · MIR 무변조(observe-only) · flag-OFF push 0회.
corpus 예상 0 (assign-arm 재차용 across scope 희소) → flag-ON diff 0.

## 4. companion test (borrowck_test.hexa)
`_run_outlives_probe` + hz_dangle_asn_reborrow(×1 ON) · fp_same_scope(0) · fp_reassign_before_use(0)
· OFF all 0 · STRICT error-band == HX3036 수.

## 5. catalog
HX3036 DiagSpec 완결블록(자체 fix_it_kind:None + `},`) — parity 80/80. HX3037은 round9용으로 비움.

## 6. 검증
aiden 3-mode(OFF/ON/STRICT) borrowck_test + `hexa run compiler/check/types_test.hexa` parse-regression.
(캡처는 PR/CHANGELOG 참조.)
