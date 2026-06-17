# RT-NATIVE UNLOCK-4 — scalar FP + CSET obj-path encoding (verdict)

## 무엇 (what)
self-host 네이티브 obj emitter(`macho_arm64.hexa`)에 scalar double-precision FP
(`fmov`/`fadd`/`fsub`/`fmul`/`fdiv`/`fcmp`) + `cset <cond>` 인코딩을 추가.
이전에는 이 니모닉들이 `_lir_op_uppercase` 통과(미매핑) → `encode_arm64_insn` 0 반환
→ **udf #0 구멍**. 따라서 비교/부동소수 intrinsic이 clang-asm 경로로만 동작했고,
obj(self-host fixpoint) 경로에선 SIGILL.

## 인코딩 (clang `otool` ground-truth 대조, byte-identical)
- fmov d,x = 9e670000 | (Xn<<5) | Dd      ; fmov x,d = 9e660000 | (Dn<<5) | Xd
- fadd 1e602800 | fsub 1e603800 | fmul 1e600800 | fdiv 1e601800  (| Dm<<16 | Dn<<5 | Dd)
- fcmp 1e602000 | (Dm<<16) | (Dn<<5)
- cset Xd,cond = 9a9f07e0 | ((cond_bits ^ 1) << 12) | Rd   (CSINC Xd,XZR,XZR,inv(cond))

## intrinsic (arm64_darwin STMT_CALL, inline)
- `__hx_payload_fadd/fsub/fmul/fdiv` → float HexaVal {TAG_FLOAT, a.f OP b.f}
- `__hx_payload_flt/fgt/fle/fge` → bool. **IEEE NaN 정확**: `<`→MI, `<=`→LS
  (LT/LE는 unordered를 true로 오판; MI/LS는 NaN→false = C 의미 일치). `>`→GT, `>=`→GE.

## 검증 (c2, 캡처출력)
- ASM 경로: println 3.5/7.5/12.0/4.5 + exit 1 ✓
- OBJ 경로: println 3.5/12.0 + exit 1 = ASM와 동일 ✓ · **udf 구멍 0개** (이전 다수)
- asm vs obj FP/cset 바이트 동일 (fadd 1e612800 · fmul 1e610800 · cset mi 9a9f57e0)
- 재-emit 결정성: obj 2회 byte-identical ✓ · 빌드 smoke exit(42) PASS

## 의의 / 정직성 (c9)
컴파일러 소스(`_arm64_cmp_cond`)가 자기 비교를 cset으로 lower → obj 경로의 cset-udf는
메모리상 "CC-NATIVE codegen-udf wall"(gen2 SIGSEGV udf/main 클래스)의 일부였다.
본 변경은 그 udf-hole 클래스(cset + FP)를 **테스트 프로그램 수준에서 닫음**(obj 실행 정상).
단, 전체 gen3≡gen4 fixpoint 재성립·gen2 SIGSEGV 완전해소는 **본 PR에서 미검증**(heavy
self-host 빌드 = pod). 과대주장 금지: "udf 클래스 인코딩 추가 + 테스트 obj 정상"까지가 검증된 범위.
