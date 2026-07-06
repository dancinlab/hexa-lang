# round5 R2 (aq) — let-RHS BinOp/UnOp inference + leaves-known gate

## 요약
정적타입 REJECT 사다리 r12 (라운드5 R2). `HEXA_STATIC_TYPES`(FLIP-3 flagless로 real-source
always-on) let-arm이 소비하는 RHS kind의 **마지막 갭** = BinOp/UnOp RHS. assign-arm r3·
call-arg·return은 이미 binop 결과타입을 무제한 소비(R2 #4630 대칭화 이후 corpus GREEN).
let-arm r1(리터럴)/r2(ident/call/index/field)에 세 번째 else-if 팔을 추가한다.

- HX3011 (Rust E0308 재사용, 신규 DiagSpec 없음)
- 삽입점 = `compiler/check/types.hexa` `_infer_expr` let-arm (opt-in `_types_static_on` 게이트 내부)
- 코드젠/severity 무영향 → byteeq-neutral (diag-only, 타입은 MIR에서 소거)

## CRITICAL 리스크 + 해결 (§1.1)
`_types_check_binop`의 unknown-operand 조기귀환(types.hexa:3494-3503)이 `a_unknown + 1`에서
**리터럴/known 쪽 타입(i64)을 반환** → `let x: i32 = a + 1`(a는 실제 i32일 수 있음)이 rhs_t=i64
KNOWN scalar로 통과 → HX3011 **오탐 REJECT** 위험.

해결 = check_binop 자체는 **손대지 않고**, let-arm 로컬에 재귀 `leaves-known` 게이트
(`_types_rhs_leaves_known`, `_types_kind_is_scalar` 뒤 삽입). 모든 leaf operand가 KNOWN scalar일
때만 binop 결과타입을 HX3011 검사에 투입; leaf 하나라도 unknown → RHS를 unknown 취급(침묵,
under-reject). 논리연산자(&&/||/and/or)는 value-returning truthy 시맨틱스라 mixed-operand에서
unsound → 명시 제외; non-`-` unop(`!`)도 제외(§1.3).

## 변경 파일
- `compiler/check/types.hexa` — 헬퍼 `_types_rhs_leaves_known` (~30줄) + let-arm else-if 한 팔
- `compiler/diag/catalog.hexa` — HX3011 explain 커버리지 문장에 r12 clause append (블록 구조 무변경;
  DiagSpec/fix_it_kind 쌍 73/73 유지)
- `compiler/check/types_test.hexa` — companion (aq): `_build_case_static_types_r12` + main 러너

## Test (aq)
`fn f(a: i64, b: i64, u) { let x: i32 = a+b; let y: i64 = a+b; let z: i32 = a+u; let w: i32 = a+1; let m: i32 = -a }`
→ 기대 **HX3011 ×3** (x·w·m Error), y clean, z 침묵(unknown leaf u = 무주석 param → empty sentinel).
비-CI test → **pool bare-run**(aiden/summer).

## PROBE-GATED (머지 전 필수 게이트)
이 rung은 실코퍼스의 sloppy i32/i64 주석에서 **진성 양성** HX3011을 낼 수 있음. 오케스트레이터는
static-types-corpus census(`static-types-corpus.yml`, PR paths에 `compiler/check/**` 포함 → 자동
트리거) + pool full-corpus front-end sweep으로 **신규 HX3011 = 0** 확인 후에만 GO.
>0이면: 진성 양성 → corpus-fix PR 선행(flip-value 증명), 오탐 → 게이트 결함이므로 NO-GO(rung 드랍).

## 앵커 (worktree c92390aa5 재실측, spec afd85ea98 대비 시프트)
- `_types_kind_is_scalar` :2364 (헬퍼 삽입 직후)
- let-arm r1/r2 :2846(`if _types_static_on`)~2969 (else-if 팔 추가)
- `_types_check_binop` unknown-operand 조기귀환 :3494-3503 (오탐 소스, 무수정)
- HX3011 catalog explain :362
