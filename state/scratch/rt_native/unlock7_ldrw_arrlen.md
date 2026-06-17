# RT-NATIVE UNLOCK-7 — ldr W-form + __hx_arr_len (struct-field load) (verdict)

## 무엇
- `macho_arm64.hexa`: `LDR Wt,[Xn{,#imm}]`(32비트 load, zero-extend; imm12 **/4 스케일**).
  clang byte-id: ldr w1,[x1,#8]=b9400821 · w0,[x3]=b9400060 · w5,[x6,#12]=b9400cc5.
- `arm64_darwin.hexa`: intrinsic `__hx_arr_len(v)` → 배열 원소수 int HexaVal. ARRAY payload
  (x1)=`HexaArr*`, `ldr w1,[x1,#8]`(len) → int box. 첫 struct-field-load leaf.

## 잡은 버그 (c2 교차검증)
초안은 `ldr x1`(64비트)였음 → `__hx_arr_len([10,20,30])`=34359738371(0x8_00000003).
**근본원인**: runtime_core.c 의 실제 HexaArr = `{HexaVal* items; int len; int cap;}` —
`len`/`cap` 이 **32비트 int**(runtime.h 의 int64_t 선언은 stale·불일치). 64비트 load 가
`(cap<<32)|len` = (8<<32)|3 을 읽었다. 32비트 `ldr w1`(zero-ext)로 수정 → len 만 깨끗이.
런타임 `len()` 교차검증 없었으면 `exit()`(하위8비트 마스킹)이 버그를 가렸을 것.
※ runtime.h:74 HexaArr int64_t 선언이 runtime_core.c int 과 불일치 = 잠재 문서버그(별건).

## 검증
- ASM/OBJ 양경로: `([10,20,30])`=3·`([])`=0·`([1..7])`=7 동일. `__hx_payload_eq(__hx_arr_len(a), len(a))`
  =true(런타임 builtin 과 일치)→exit2. ldr w byte-id · udf(main)=0 · smoke PASS · additive.

## 의의
struct-field-load 패턴 확립(다음 = HexaMap.len·items 등). hexa_len/hexa_truthy 의 array 분기
native 포팅 unblock. 각 dispatch fn 포팅이 다음 needed leaf 를 노출하는 점진 패턴 계속.
