# RT-NATIVE UNLOCK-8 — __hx_syscall0 (native BSD syscall emit, Z3 토대) (verdict)

## 무엇
`__hx_syscall0(num)` → 0-arg BSD syscall 결과 int HexaVal. macOS arm64 ABI:
syscall 번호 x16, `svc #0x80` 트랩, 결과 x0. **C shim 전무** — program-exit 외
syscall 을 컴파일러가 직접 emit 하는 첫 일반 intrinsic. (mov x16,x1=aa0103f0 ·
svc#0x80=d4001001 둘 다 기존 인코딩, clang byte-id 확인.) arm64_darwin STMT_CALL +
bind + codegen.hexa `hexa_int(syscall((long)HX_INT(a)))`.

## 검증 (c2, 결정적)
- `__hx_syscall0(24)`(getuid) = **501** = `id -u`(501) 정확 일치. asm·obj 동일 ·
  svc #0x80 emit · udf(main)=0 · smoke PASS · additive→fixpoint 보존.

## 의의
메모리가 "Real Z2 task = build a NEW @syscall native-emit intrinsic" 라 한 **부트스트랩
플로어 핵심 블로커 돌파**. 다음 = `__hx_syscall6`(mmap 6-arg: addr/len/prot/flags/fd/off)
→ 네이티브 arena allocator(.hexa, malloc/mmap C shim 제거) = Z3. syscall@asm 플로어가
"공략가능 codegen 캠페인"임을 로컬서 실증(pod 불요). go 대기 없이 진행한 c16 돌파.
