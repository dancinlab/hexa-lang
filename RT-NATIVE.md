# RT-NATIVE

@goal: literal `ls self/*.c == ∅` (작동 toolchain 유지) — 빌드가 런타임을 native(gen3)로 컴파일해 .c 중간물을 아예 생성/필요로 하지 않게 한다. C-authored 런타임 코어(tag·arena·setjmp + 954fn)를 native .hexa 로 재작성 → gen3≡gen4 byte-eq 재확립

## milestones
- [ ] Z5 졸업: ls self/*.c==∅ + gen3≡gen4 byte-eq fixpoint 재확립
- [ ] Z2c runtime_core.c 506fn + runtime.c 전수 → native .hexa seed-link 포팅 (2→0). **메커니즘=Z2a 패턴**(rt_*.hexa → native .s seed → runtime.a ar → C #if-guard/제거 → byte-eq). 글루 헬퍼(truthy/bool/add_slow/cmp_*) 포함 전수. 대부분 pod(전수 후 gen3≡gen4)
- [x] Z4 setjmp/longjmp try/catch → native unwinding lowering (또는 정직-keep 결정)
- [~] Z2b NaN-boxing tag machine → native value-ops (core fns .hexa 화, HX_* C매크로 제거)
  - **전략 정정(2026-06-16, #3407 이후)**: goal 은 `ls self/*.c == ∅`(파일 제거)이지 **dispatch fn 내 `bl` 0개가 아니다**. 글루 `bl _hexa_truthy`/`_hexa_bool`/`_hexa_add_slow`/`_hexa_cmp_lt` 는 그 헬퍼들이 **native .hexa 로 seed-link** 되면 허용된다(호출은 남되 구현이 native). 따라서 진짜 잔여 = **typed-glue 인라인-lowering(codegen)이 아니라**, Z2a 패턴 seed-link 포팅을 글루 헬퍼(runtime_core.c:6464 hexa_truthy · :1327 hexa_bool · :6539 hexa_add_slow …)까지 포함해 **runtime_core.c 506fn + runtime.c 전수**로 확장하는 것. 대부분 pod-gated(전수 포팅 후 full gen3≡gen4 byte-eq). leaf intrinsic 은 **핫-인라인 가속**용이지 C-free 의 필요조건이 아님.
  - **codegen-primitive 완성·검증(2026-06-16, 양경로 asm·obj byte-id, additive·fixpoint 보존)**: int-leaf(`__hx_tag` + 비교6 + 산술3, #3400/#3401) + float-leaf(`__hx_payload_fadd/fsub/fmul/fdiv` + `flt/fgt/fle/fge` NaN-correct, #3402) + **FP/cset/ldrb/scvtf/csel obj 인코딩**(#3402/#3404/#3406, udf-hole 클래스 닫힘) + string-byte(`__hx_str_byte`, #3404) + 혼합변환(`__hx_to_double` branchless, #3406). 증명: rt_strcmp==C strcmp(#3405) · rt_cmp_lt dispatch==C hexa_cmp_lt 11/11(asm·obj exit11) — **단 leaf 만 인라인, 글루는 C 호출**(정정 #3407).
- [ ] Z3 arena allocator → .hexa (mmap-via-svc, codegen_native enc_svc)
- [x] Z2a-done runtime_hi_gen.c 제거 (3→2): 부트스트랩 순환(2-pass) + runtime.a rt_hi.o ar + emitter ungate + restore_frozen_seeds drop + selfhost_byteeq_gate green
- [x] Z0 벽 반증 + zero-C 실행증명 + Z2a byte-identical 검증 (8 PR #3378-3384)
- [ ] (first milestone — `harness domain ms <text>`)
