# round5 R2 — let-RHS BinOp/UnOp + leaves-known 게이트 (HX3011 재사용·Rust E0308)

정적타입 r12. typed-`let`의 BinOp/UnOp RHS가 추론상 KNOWN 스칼라 결과타입을 내고 주석과
불일치하면 REJECT. **핵심 안전장치=leaves-known 트리 게이트**: 트리의 모든 leaf(ident/call/
index/field)가 KNOWN 스칼라여야만 결과타입을 신뢰. unknown leaf 1개라도 있으면 전체 침묵
(`let x: i32 = a_unknown + 1`의 리터럴-폴백 i64 오탐 클래스 구조적 제거). logical `&&`/`||`·
비-마이너스 unop 제외(값반환 truthy 시맨틱스).

## 구현 (compiler/check/types.hexa)
- `_types_rhs_leaves_known(e,env,ctx)` 재귀 헬퍼(_types_kind_is_scalar 뒤).
- let-arm 세 번째 else-if(r2 뒤): declared 스칼라 && leaves-known → scratch 재infer → rhs_t 스칼라 && !assignable → HX3011.
- assign r3/call-arg/return은 이미 binop 결과타입 무제한 소비(round4-R2 #4630 대칭화로 corpus GREEN)·let-arm만 잔여 갭이었음.

## byteeq중립 + census
S3 diag-only·MIR서 소거. 단 **진단스트림 변경**(신규 REJECT) → PROBE-GATED:
corpus census(static-types-corpus.yml·compiler/check/** paths 자동트리거)로 real source 신규 HX3011=0 확인 필수.
>0시: 진성양성→corpus 수정 선행 / 오탐→게이트결함 NO-GO(rung 드랍).

## test (types_test aq)
- a_i64+b_i64→i32 REJECT(1)·c_i32+1 coerce clean(0)·a+u_unknown leaves-known-false silent(0 HX3011).
- fixture carve-out: *_test.hexa→WARNING.
