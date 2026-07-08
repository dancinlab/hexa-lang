# unused-local-let HX3050 (rustc unused_variables) — S2 identifier-binding · P1 opt-in default-OFF

다음 altitude ① checker-only capability. 앞선 depletion이 mis-classify했던 tractable NARROW subset — 함수-로컬 `let`이 스코프 어디서도 참조되지 않으면 rustc `unused_variables` (warn-by-default lint). P1 opt-in은 작고, 270-corpus는 P4 flip 비용으로 defer(HX3047/HX3048과 동일 패턴). 인프라 신설 없음 — HX2001 name-resolution choke 재사용.

## WIRE (origin/main서 전부 RE-ANCHOR·survey 정확)
- **파일**: `compiler/check/bind.hexa`(per-MODULE `bind(module)`) + `compiler/diag/catalog.hexa`(HX3050) + `compiler/check/unused_let_test.hexa`.
- **(1) module-globals**(enum-registry reset fn 직후 ~:82): `_unused_let_on`(bool·default false) + `_unused_cand_ids:[i64]` + `_unused_cand_names:[string]` + `_unused_cand_spans:[Span]` + `_unused_used_ids:[i64]`. `_unused_let_reset()`가 `_unused_let_on = env("HEXA_UNUSED_LET")=="1"` latch + 4 배열 clear. `bind()` 진입서 `_bind_enum_registry_reset()` 옆 호출(~:1610). ★`pub let mut`(survey) 대신 plain `let mut` — 같은 파일 enum-registry sibling convention 미러(non-pub·byteeq/style 무해·test는 `pub fn bind()`만 호출).
- **(2) MARK USE** — `_bind_walk_expr` Ident arm, `_bind_lookup` 직후(~:856): `if _unused_let_on && hit.index >= 0 { _unused_used_ids.push(hit.index) }`. **SINGLE value-ref choke**(RE-VERIFIED): assign-LHS(:1082 children-first walk→LHS Ident가 여기로 하강), call-callee, field-receiver 전부 하강. struct-lit head(:876)/enum-path head(:901)는 NOMINAL name resolve(locals 아님)→touch 안 함.
- **(3) ACCUMULATE** — local-`let` define arm, `_define_mut` 직후(~:945·**유일 함수-로컬 let-expr define site** RE-VERIFIED): `if _unused_let_on { nmc=nm.chars(); if len(nmc)>0 && nmc[0]!='_' { push {sc.next_index-1(방금 mint된 dense DefId.index), nm, e.span} to 3 cand arrays }}`. params(:1673)·for-iter(:967)·catch(:988)·match-binder(_bind_pattern)·closure-param(:1014)·top-level let(pre-register :1640/walk-as-item-RHS)는 DIFFERENT site→제외.
- **(4) EMIT** — `pub fn bind()` `return out` 직전(~:1692): `if _unused_let_on` 아래 각 cand id에 대해 `_unused_used_ids` linear absent-scan → 부재면 `_emit_hx3050(name, span, out)`.
- **(5) `_emit_hx3050`**(`_emit_hx2006` 옆 ~:775): `diag_new("HX3050")`+span+`name` arg·`_emit_hx2001` 미러(no strict re-band·no fixit).
- **(6) catalog HX3050**: Severity::**Warning**(rustc unused_variables=warn-by-default)·stage S3·template `unused variable: \`{name}\``·explain rustc-match(`_`-prefix escape hatch 언급)·fix_it_kind None. **parity 94/94**(DiagSpec == fix_it_kind).

## FP=0 by construction (핵심)
opt-in flag default-OFF 위에: marking이 HX2001 name-resolution과 **정확히 co-located**→resolver-complete used-set. assign write(`x=5`)는 assign-arm이 LHS Ident를 choke로 walk→USE로 카운트(conservative assume-used·false NEGATIVE가 safe 방향). closure capture는 up-chain resolve→marked used. `_`-prefix name=rustc escape hatch·accumulate site서 제외. dense DefId.index는 bind() call당 monotonic-unique→cand/use 매칭 정확. env default-OFF → 0 diagnostics → diag stream + .text byte-identical(byteeq-NEUTRAL).

**★shadowing 실측 발견(survey 가정 반증)**: survey는 "shadowed-first-binding-unused matches rustc"(last-wins) 가정했으나 aiden 실측서 반전. `_bind_lookup`(bind.hexa:199)은 frame 내에서 **FIRST match(j=0 forward scan)** 반환. 결과: (a) NESTED-scope shadow(inner block=별도 frame)는 inner-first resolve→clean(fp_shadow_nested=0 실측). (b) SAME-FRAME sequential re-`let`(`let x=1; print(x); let x=2; print(x)` 한 block)은 later `x` 참조가 전부 FIRST binding으로 resolve→SECOND same-frame shadow가 resolution target이 절대 안 됨→flagged(실측 line4 발화). 이건 **S2 resolver 기준 FP=0**(lint는 resolver가 resolve하는 것만 mark)이지만 rustc last-wins와 divergence. 이 same-frame 케이스는 P4 corpus census가 흡수할 항목(default-OFF band라 release-integrity 위험 0). test는 same-frame probe를 nested-scope probe로 교체(honest FP-clean control)하고 doc/catalog에 caveat 박제.

## 검증/게이트 (aiden/summer·home-dir worktree·build_selfhost /tmp 거부)
- test=`compiler/check/unused_let_test.hexa`: lex→parse→`bind(m)` 직접(bind는 array 반환). discriminator hz_unused_let(`fn f(){let x=1}`) ×1 vs fp_used(`let x=1; print(x)`) 0 + FP 컨트롤 fp_underscore(`let _x=1`)·fp_shadowed_used(both used)·fp_assign_write(`let mut x=0; x=5` write=use) 0·OFF-sweep 0-diag·WARN-band. `hexa run compiler/check/unused_let_test.hexa`(OFF) / `HEXA_UNUSED_LET=1 hexa run …`(ON).
- P1 착지 게이트: gates-summary GREEN + byteeq-neutral(OFF·env default-OFF→diag+.text 불변).
- **P4 default-flip = corpus-migration follow-up**(HX3047/HX3048 미러): shipping tree엔 genuinely-unused local이 존재(~270-site 추정)→offline HEXA_UNUSED_LET=1 census → `_`-prefix 마이그레이션 → faithful×3 flag-ON → default-ON flip(never x86-only). census/flip은 별도 round.
- **가치 정직**: P1은 shipping에 real 발화(unused local 존재)하지만 default-OFF라 release-integrity 위험 0. HX3047/HX3048은 shipping x0였으나 HX3050은 corpus-nonzero — 그래서 P4가 corpus-migration 비용을 짐. rung 가치=rustc-parity checker family 확장 + user code용 ready lint.

## 이력
- 오케스트레이터가 origin/main(HEAD ~278 behind→FRESH branch off origin/main)서 anchor 전부 RE-VERIFY 후 구현·test·bookkeeping·커밋. reuse=HX2001 name-resolution choke(:851 Ident arm)·module-level accumulate=enum-registry/`_bck` convention(BindFrame struct·_pop_scope signature 불변).
