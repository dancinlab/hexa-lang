# RT-NATIVE

@goal: literal `ls self/*.c == ∅` (작동 toolchain 유지) — 빌드가 런타임을 native(gen3)로 컴파일해 .c 중간물을 아예 생성/필요로 하지 않게 한다. C-authored 런타임 코어(tag·arena·setjmp + 954fn)를 native .hexa 로 재작성 → gen3≡gen4 byte-eq 재확립

## milestones
- [ ] Z5 졸업: ls self/*.c==∅ + gen3≡gen4 byte-eq fixpoint 재확립
- [ ] Z2c runtime_core_emit.hexa C-text core (954 fn) → native .hexa 재작성 (2→0)
- [x] Z4 setjmp/longjmp try/catch → native unwinding lowering (또는 정직-keep 결정)
- [~] Z2b NaN-boxing tag machine → native value-ops (core fns .hexa 화, HX_* C매크로 제거)
  - codegen-primitive 진행: int-leaf(태그읽기 `__hx_tag` + 비교 6 + 산술 3, #3393/#3400/#3401) + float-leaf(`__hx_payload_fadd/fsub/fmul/fdiv` + `flt/fgt/fle/fge` NaN-correct, #3402) + **FP/cset obj-path 인코딩**(#3402, udf-hole 클래스 닫힘 — asm==obj byte-id, canary 무회귀). 잔여 = 문자열/포인터 leaf(`hxlcl_strcmp` char* deref·byte load = Z3 포인터-codegen 블로커와 동일) + enum/valstruct + `__hx_to_double` 강제변환 → 그 후 dispatch fn(hexa_cmp_*/add/sub/mul) 전체 C-free 포팅 + seed-link.
- [ ] Z3 arena allocator → .hexa (mmap-via-svc, codegen_native enc_svc)
- [x] Z2a-done runtime_hi_gen.c 제거 (3→2): 부트스트랩 순환(2-pass) + runtime.a rt_hi.o ar + emitter ungate + restore_frozen_seeds drop + selfhost_byteeq_gate green
- [x] Z0 벽 반증 + zero-C 실행증명 + Z2a byte-identical 검증 (8 PR #3378-3384)
- [ ] (first milestone — `harness domain ms <text>`)
