# RT-NATIVE-ZEROC

@goal: ls self/*.c == ∅ (양 타깃 gen3≡gen4 byte-eq 유지) — runtime.c+runtime_core.c 를 native-seed/intrinsic 으로 완전 대체

## milestones
- [ ] M6 runtime.c+runtime_core.c drop + ls self/*.c==∅ + gen3≡gen4 양타깃 검증
- [ ] M5 standalone-build 재설계 (native rt_*.o 링크, #else 제거)
- [ ] M4 ~1190 common core fn 전수 hexa-native 포팅 (다배치, nanbox/syscall/map/array)
- [ ] M3 @syscall 일반 intrinsic 양타깃 (svc/syscall reg marshalling)
- [ ] M2 raw-mem intrinsic 양타깃 완비 (__hx_ptr_load/store map·array)
- [x] M1 x86_64 leaf-intrinsic parity (25/25 __hx_* arm64→x86_64 codegen; GNU-as byte-id 인코딩; emit→as→link→run exit-correct; gen3≡gen4 byteeq 보존; +const_float payload root-fix. 잔여=const_str-assign·unop `!` 미구현 = M2 orthogonal. F-M1-X86-LEAF-PARITY)
- [ ] (first milestone — `harness domain ms <text>`)
