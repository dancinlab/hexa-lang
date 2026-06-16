# RT-NATIVE UNLOCK-6 — scvtf + csel obj 인코딩 + __hx_to_double (verdict)

## 무엇
- `macho_arm64.hexa`: `SCVTF Dd,Xn`(signed i64→double) + `CSEL Xd,Xn,Xm,cond`(branchless select)
  인코딩. clang byte-id: scvtf d0,x1=9e620020 · csel x1,x1,x2,eq=9a820021 · x5,x6,x7,ne=9a8710c5.
  CSEL cond는 **직접**(cset과 달리 비반전). `_lir_op_uppercase` scvtf→SCVTF(csel 기존).
- `arm64_darwin.hexa`: `__hx_to_double(v)` intrinsic — int-or-float → double float HexaVal,
  **BRANCHLESS**(csel, intra-sequence label 불요): scvtf d0,x1; fmov x2,d0; cmp x0,#1;
  csel x1,x1,x2,eq(float→bits 유지, int→변환); movz x0,#1. `_arm64_instr4` 헬퍼 추가.
  bind 허용 + codegen.hexa C-transpile `hexa_float(HX_IS_FLOAT(a)?HX_FLOAT(a):(double)HX_INT(a))`.

## 검증 (c2)
- ASM/OBJ 양경로: `__hx_to_double(5)`=5.0 · `(2.5)`=2.5 · 혼합비교 `flt(td(3),td(3.5))`=true ·
  `flt(td(4.5),td(4))`=false → exit 2 동일. scvtf/csel byte-id · udf(main)=0 · smoke PASS · additive.

## 의의
hexa_cmp_lt 의 **모든 분기 leaf 완비**: int(✓) · str(rt_strcmp ✓ #3405) · 혼합 int/float
(`__hx_to_double`+`__hx_payload_flt` ✓) · tag읽기(`__hx_tag` ✓). 잔여 = enum-pair-idx +
valstruct(`HexaValStruct*` 필드 deref) + dispatch skeleton(tag별 분기 = 정상-.hexa if/else)
+ seed-link 통합(Z2c). enum/valstruct 제외한 (int/str/float) rt_cmp_lt 는 지금 정상-.hexa 로 작성 가능.
