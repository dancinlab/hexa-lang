# RT-NATIVE UNLOCK-9 — __hx_syscall6 (mmap/munmap, 네이티브 arena 토대 Z3) (verdict)

## 무엇
`__hx_syscall6(num, a0..a5)` → 6-arg BSD syscall 결과 int HexaVal. macOS arm64:
args x0..x5, num x16, `svc #0x80`, 결과 x0. 각 인자 INT payload 를 callee-temp
(x9..x14)에 먼저 적재(`_hv_load`가 x0..x3 스크래치 clobber → 직접 x0..x5 적재 시
앞 인자 손상) 후 한 블록으로 x0..x5 정렬. arm64_darwin STMT_CALL + bind +
codegen.hexa `hexa_int(syscall(num,a0..a5))`.

## 검증 (c2, 결정적)
- getuid(#24) via syscall6(나머지 무시) = **501** = id -u.
- mmap(NULL, 4096, PROT_RW=3, MAP_ANON|MAP_PRIVATE=0x1002, -1, 0)(#197) → 양수
  포인터(>0) 반환 = 성공 → exit 0.
- mmap → munmap(#73) 왕복 → exit 0 (할당+해제 성공).
- asm·obj 동일 · svc emit · udf(main)=0 · smoke PASS · additive→fixpoint 보존.

## 의의
네이티브 arena(Z3)의 **메모리 할당/해제 토대를 C malloc shim 없이 확보**. 메모리가
"진짜 floor = ~10 libm/FFI + syscall@asm" 이라 한 syscall 축의 핵심(mmap/munmap)을
로컬 돌파. 다음 = bump-pointer arena .hexa(mmap 으로 큰 슬랩 할당 → 포인터 산술 분배,
이미 __hx_arr_len 의 struct-field 패턴 + ptr 산술 leaf 로 작성 가능) → hexa_arena_alloc
C body 대체 → runtime_core.c arena 의존 fn 들 hexa-native. pod 불요(c16 로컬 돌파).
