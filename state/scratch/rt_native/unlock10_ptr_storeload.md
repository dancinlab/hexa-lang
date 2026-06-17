# RT-NATIVE UNLOCK-10 — __hx_ptr_store64/load64 (네이티브 arena 메모리 R/W) (verdict)

## 무엇
- `__hx_ptr_store64(ptr, off, val)` → addr=ptr+off 에 64비트 val 기록(`add; str x,[x]`),
  ptr 반환(chainable). `__hx_ptr_load64(ptr, off)` → addr 의 64비트 읽기(`add; ldr`).
  str/ldr x,[ptr] 인코딩 기존재 재사용. bind + codegen.hexa `*(int64_t*)((char*)ptr+off)`.

## 검증 (c2, 결정적 — arena 전체 사이클)
- mmap(4096)(#197) → store64(p,0,12345)·(p,8,67890)·(p,16,42) → load64 회수
  =12345/67890/42 정확 → exit 3. → munmap(#73). asm·obj 동일 · udf=0 · smoke PASS · additive.
- 데모: scripts/scratch/rt_native/arena_roundtrip_demo.hexa

## 의의
syscall6(mmap/munmap, #3413) + ptr R/W(#본PR) = **메모리 할당+쓰기+읽기 전체 사이클을
C shim(malloc/store/load) 0개로** 확보 = 네이티브 bump-pointer arena 의 완전한 프리미티브 셋.
이제 arena.hexa 작성 가능: mmap 으로 큰 슬랩 → bump 포인터(현재오프셋 변수) → store64 로
객체 기록 → 반환. hexa_arena_alloc C body 대체 → runtime_core.c arena 의존 fn hexa-native.
다음 = bump-pointer arena.hexa 작성 + C arena 와 동작 동치 검증. pod 불요(c16 로컬).
