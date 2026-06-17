# RT-NATIVE-ZEROC

@goal: ls self/*.c == ∅ (양 타깃 gen3≡gen4 byte-eq 유지) — runtime.c+runtime_core.c 를 native-seed/intrinsic 으로 완전 대체

## milestones
- [ ] M6 runtime.c+runtime_core.c drop + ls self/*.c==∅ + gen3≡gen4 양타깃 검증
- [ ] M5 standalone-build 재설계 (native rt_*.o 링크, #else 제거)
  - rt_str PILOT: 메커니즘 ALREADY PROVEN+SHIPPED (Z2a #3455/#3457/#3465) — standalone 빌드가 native rt_hi_native.o(14 rt_str_* syms) 링크 + casefold/trim/contains/search-pred `#else` C바디 excise(에미터 body 3→0) + HEXA_ZEROC_RT_HI=1 auto-enable(양 타깃). aiden 실측: runtime_core.c 411120B, nm 잔여 rt_str body = int-return bridge 2개(starts_with/ends_with)뿐, byteeq-real CI GREEN(main). 잔여 bridge 2개 = ABI 어댑터(native body 없음, _b만 시드제공) → codegen/seed micro-unit 으로 defer(Z2a 템플릿 밖, no fake). verdict F-M5-PILOT-RTSTR. → M5 메커니즘 = fake 아님·rt_str 한정 DONE; 진짜 ls==∅ 레버는 M4 common-core port.
- [ ] M4 ~1190 common core fn 전수 hexa-native 포팅 (다배치, nanbox/syscall/map/array)
  - B1 nanbox-ctor: mechanism DONE (3중 native: _hv_load inline · HEXA_RT_SELFEMIT rt_hexa_* bytes · __hx_* read-intrinsics); C-diff gate b1_nanbox_gate.c 35/35 PASS (aiden x86_64). nanbox.hexa NOT viable (HexaVal struct-literal = self-recursive hexa_int call). #else drop BLOCKED-on-M5 (standalone runtime.a links the C bodies). verdict F-M4-B1-NANBOX.
- [x] M3 @syscall 일반 intrinsic 양타깃 (svc/syscall reg marshalling)
- [x] M2 raw-mem intrinsic 양타깃 완비 (__hx_ptr_load/store map·array)
- [x] M1 x86_64 leaf-intrinsic parity (25/25 __hx_* arm64→x86_64 codegen; GNU-as byte-id 인코딩; emit→as→link→run exit-correct; gen3≡gen4 byteeq 보존; +const_float payload root-fix. 잔여=const_str-assign·unop `!` 미구현 = M2 orthogonal. F-M1-X86-LEAF-PARITY)
- [ ] (first milestone — `harness domain ms <text>`)
