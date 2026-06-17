# RT-NATIVE UNLOCK-12 — x86_64 global operand RIP-relative load fix (verdict)

## 무엇
x86_64_linux.hexa `_x86_op_rm`/`_x86_op_resolve` global 경로(baseline shared==0)가
바 라벨 `g<id>` 를 직접 emit → GNU as "ambiguous operand size" 거부(#3422 root cause).
수정: baseline 도 RIP-relative 값 로드 `mov scratch, [rip+g<id>]` → resolve scratch 반환
(GOT shared 경로와 동일 패턴). arm64 adrp/ldr 값 로드 대응.

## 검증 (c2, 캡처출력)
- 재현 x86_global_repro: 전 `cmp g0, 0`(ambiguous FAIL) → 후 `mov r10, [rip+g0]; cmp r10, 0`
  → clang -target x86_64-linux-gnu -c = OK 1480B (이전 FAIL).
- RUNG2(string-print) cross-assemble 회귀 없음.
- arm64 build OK + smoke exit42 (x86_64_linux.hexa 만 수정 → arm64 leg A #3412 무영향).

## 의의
x86_64 leg A(linux byte-eq) 핵심 블로커(global operand) 수정. typed-int global(single
value) 케이스 확정. 잔여: HexaVal 16B global(페어 load/store)은 single value 로 lo 만
로드 → whole-compiler 의 HexaVal global 비교가 정확한지 summer 실행 재검증 필요(다음).
buggy 였던 #3421 의 cmp 빈값/test g16 도 같은 root → 본 수정으로 라벨-직접 제거.
