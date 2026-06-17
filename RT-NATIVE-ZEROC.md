# RT-NATIVE-ZEROC

@goal: ls self/*.c == ∅ (양 타깃 gen3≡gen4 byte-eq 유지) — runtime.c+runtime_core.c 를 native-seed/intrinsic 으로 완전 대체

## milestones
- [ ] M6 runtime.c+runtime_core.c drop + ls self/*.c==∅ + gen3≡gen4 양타깃 검증
- [ ] M5 standalone-build 재설계 (native rt_*.o 링크, #else 제거)
- [ ] M4 ~1190 common core fn 전수 hexa-native 포팅 (다배치, nanbox/syscall/map/array)
  - B1 nanbox-ctor: mechanism DONE (3중 native: _hv_load inline · HEXA_RT_SELFEMIT rt_hexa_* bytes · __hx_* read-intrinsics); C-diff gate b1_nanbox_gate.c 35/35 PASS (aiden x86_64). nanbox.hexa NOT viable (HexaVal struct-literal = self-recursive hexa_int call). #else drop BLOCKED-on-M5 (standalone runtime.a links the C bodies). verdict F-M4-B1-NANBOX.
  - B4 array-core: mechanism-BLOCKED — WALL-1 construct (B1 twin: get/pop/new return a 16B HexaVal element, no (tag,payload)→HexaVal intrinsic; every __hx_* boxes TAG_INT; `arr[idx]`→hexa_index_get circular) + WALL-2 alloc (new/push/reserve/snapshot = calloc/realloc/arena/heapify/stats, not intrinsic-expressible). Layout c2-measured: HexaArr{items@0,len@8,cap@16}/24, HexaVal/16, stride 16, cap<0=arena. C-diff gate b4_array_gate.c 32/32 PASS (summer x86_64) — layout+behaviour oracle locked. array_core.hexa NOT viable (circular). #else drop BLOCKED-on-M5. UNBLOCKING LEVER = __hx_make_val(tag,payload)→HexaVal (the symmetric write-half of __hx_tag; ADD-only; unblocks B4/B5 element-returns + B1 nanbox.hexa). verdict F-M4-B4-ARRAY. NEXT(r2)=__hx_make_val micro-PR.
- [x] M3 @syscall 일반 intrinsic 양타깃 (svc/syscall reg marshalling)
- [x] M2 raw-mem intrinsic 양타깃 완비 (__hx_ptr_load/store map·array)
- [x] M1 x86_64 leaf-intrinsic parity (25/25 __hx_* arm64→x86_64 codegen; GNU-as byte-id 인코딩; emit→as→link→run exit-correct; gen3≡gen4 byteeq 보존; +const_float payload root-fix. 잔여=const_str-assign·unop `!` 미구현 = M2 orthogonal. F-M1-X86-LEAF-PARITY)
- [ ] (first milestone — `harness domain ms <text>`)
