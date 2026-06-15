# RT-NATIVE.tape — append-only step log
@V := "RT-NATIVE" :: log
- 2026-06-15 22:22 todo: Z3 arena: malloc-MVP 단일세션·byte-eq 0 / Z2b tag: codegen 이미 native·블로커=boxing ABI / Z4 setjmp: Darwin 이미 naked-asm(zero C)·honest-keep
- 2026-06-15 22:26 todo: Z2a-done 잔여: cross-platform .s seed 3개(arm64-darwin✓ verified · x86_64-linux · arm64-linux) 모두 native 여야 runtime_hi_gen.c rm 가능 → linux 검증 pod 필요. Z2c(954fn) = 진짜 multi-week 벌크. Z4 setjmp Darwin 이미 native(honest-keep).
- 2026-06-15 23:03 todo: Z2a x86_64-linux POD(aiden) 결과: -no-pie 링크 통과하나 aprime_z2a_lin SEGFAULT — x86_64 native codegen 의 rt_str_* rodata/HexaVal-ABI 버그(메모리 RUNG2 연결). runtime_hi_gen.c 제거는 x86_64 codegen 수정 선행 = Z2c-class. arm64-darwin Z2a✓ · arm64-linux 미검증.
- 2026-06-15 23:08 todo: x86_64 ROOT CAUSE(pod gdb): x86_64 codegen 은 모든 값=raw 1-reg int 모델 → hexa_array_new 의 16B HexaVal 반환(rax:rdx)서 payload 버림 → 배열 NULL → push segfault. 고치려면 x86_64 값모델 전면개편(raw→HexaVal 쌍 운반, arm64 x0:x1 동형) = codegen 아키텍처 작업 multi-week. arm64-darwin 은 쌍모델 있어 작동(Z2a✓).
