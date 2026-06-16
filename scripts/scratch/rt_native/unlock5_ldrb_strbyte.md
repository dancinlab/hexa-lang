# RT-NATIVE UNLOCK-5 — ldrb obj 인코딩 + __hx_str_byte (verdict)

## 무엇
- `macho_arm64.hexa`: `LDRB Wt,[Xn{,#imm}]` 인코딩 추가 (byte form = **UNSCALED** imm12).
  clang 대조 byte-id: ldrb w0,[x1]=39400020 · [x1,#1]=39400420 · w2,[x3,#15]=39403c62.
  base 0x39400000 | (imm<<10) | (Rn<<5) | Rt. `_lir_op_uppercase` ldrb→LDRB 매핑.
- `arm64_darwin.hexa`: intrinsic `__hx_str_byte(s, i)` → s[i] 부호없는 바이트의 int HexaVal.
  STR payload(x1)=`char*`(HexaVal union `.s`), INT payload(x3)=index → add x1,x1,x3;
  ldrb w0,[x1](W-write zero-ext); int box {TAG_INT, byte}. bind 허용 + codegen.hexa
  C-transpile `hexa_int((int64_t)(uint8_t)HX_STR(a)[HX_INT(b)])`.

## 검증 (c2)
- ASM 경로: __hx_str_byte("ABC",0/1/2)=65/66/67 + exit("Z",0)=90 ✓
- OBJ 경로: 동일 65/66/67/90 · ldrb=39400020 (clang byte-id) · udf(main)=0 ✓
- 빌드 smoke exit(42) PASS · additive→fixpoint 보존.

## 의의
첫 **byte-level string leaf**. dispatch core 의 string 경로(`hxlcl_strcmp`)는 이제
inline-loop intrinsic 불요 — 정상 `.hexa` 함수 `rt_strcmp`(while + `__hx_str_byte` +
`__hx_payload_lt`)로 작성 가능 → seed-link 으로 hexa_cmp_lt string branch C-free 포팅 길 열림.
잔여: 길이/NUL 종결 처리 + enum/valstruct + `__hx_to_double` + seed-link 통합(Z2c).
