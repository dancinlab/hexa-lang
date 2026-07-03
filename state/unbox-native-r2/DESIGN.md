# r2b — 배열 인덱싱 native 언박싱 · index-provenance threading (HEXA_UNBOX_ARRAY_NATIVE · default-OFF)

> ## VERDICT (r2b) — PENDING MEASURE (aiden, branch perf/codegen-unbox-array-r2b)
> measure_r2b.sh detached on aiden (load<6 wait). Filled on harvest of
> `~/r2b_RESULT.txt`. See bottom for the live verdict block.

## 배경 (r2-pre #4034 NEGATIVE → r2b)
r2-pre 측정: `HEXA_UNBOX_ARRAY_NATIVE` flag 머신러리는 바이너리에 존재하나 codegen
index-emit 게이트가 끝내 true 안 됨 — patched asm OFF==ON byte-identical. 근본원인은
codegen-guard 버그가 아니라 **HIR/MIR type-lowering substrate gap**: native `_STMT`
index emitter 가 (provably-typed-prim-array 컨테이너 ∧ provably-int 인덱스) 결합신호를
콜사이트서 못 봄 → 박싱 firewall 안 열림. r2-pre 가 배열 MIR type_id 101 경로를 활성화
했으나 그것만으론 부족(필요조건). r2b = 그 threading 을 codegen 콜사이트까지 잇고 native
element load/store 를 emit.

## 변경 (codegen-only, gated · byteeq-neutral OFF)
`compiler/codegen/x86_64_linux.hexa`:
1. **gate + probe**: `_unbox_array_enabled()`(env `HEXA_UNBOX_ARRAY_NATIVE`),
   `_arru_debug_enabled()`(env `HEXA_ARRU_DEBUG` — index/index_set 마다 cont.type_id +
   idx.provint stderr 덤프, LIR 무영향).
2. **provenance 판정**: `_x86_operand_typed_prim_array(o,rm)` = container 가 `local`이고
   `_x86_local_type` ∈ {101,102,103,104}(typed-prim array). `_x86_index_unbox_ok(s,rm)` =
   gate ON ∧ container typed-prim-array ∧ args[1] provably-int(`_x86_operand_provably_int`
   재사용 = const_int OR local type_id==1). 불확실(map·untyped array·비-int idx·global)이면
   박싱 유지(R1 soundness firewall 동형).
3. **native emit** (`_x86_emit_arru_get`/`_x86_emit_arru_set`): HexaArr LAYOUT
   (array_core.hexa:17 — payload=HexaArr*; items*@0 len@8 cap@16; element stride
   sizeof(HexaVal)=16, tag@+0 payload@+8):
   - get: `r10=arr_payload; rax=idx; r11=[r10+8](len); cmp rax,r11; jae .Larru_slowN`
     (unsigned ≥ catches neg idx) `; r11=[r10+0](items); imul rax,rax,16; add r11,rax;
     mov dst,[r11+8]; store dst tag = elem prim tag; jmp .Larru_doneN; .Larru_slowN: <기존
     boxed call hexa_index_get>; .Larru_doneN:`
   - set: 같은 walk + `mov [r11+0],r9(value tag); mov [r11+8],r8(value payload)`; OOB→
     기존 boxed call hexa_index_set (auto-grow/bounds-error canonical).
   - **bounds-check 유지**(call→inline cmp+jae). OOB 는 runtime 으로 폴백 → out-of-bounds
     semantics byte-동등. bounds-elision 은 별도 라운드(loop-invariant 분석 필요).
4. **OFF byteeq**: gate unset → `_x86_index_unbox_ok` false → 기존 boxed emit 만, `.Larru`
   라벨·`_x86_arru_lbl` 카운터 never materialize → byte-identical by construction.

## 스크래치 레지스터 안전성
실제 alloc pool = callee-saved rbx/r12-r15 (codegen.hexa:2774). rax/r8/r9/r10/r11 은
backend free scratch (home reg 아님) → `mov rax,<home∈rbx/r12-r15>` 클로버 없음. 기존
boxed 경로(`_x86_hv_box_arg` 3-operand 적재)와 동일 패턴.

## 게이트
1 OFF byteeq gen3≡gen4 same-cwd(DWARF cwd 회피) · 2 lever: k3_arrmap asm
`hexa_index_get/set` count ON≪OFF + 커플 spill 동반↓ + parity(int bit-exact) +
ratio median-5 taskset · 3 smoke. 판정 = 레버발화 + ratio<1.0 + byteeq PASS + parity
→ go. 미발화/ratio≥1.0 → 어느 threading 지점이 끊겼는지 정직 잔차(tune-to-green 금지).

## 알려진 잠재 break point (측정으로 확정)
정적 분석상 가장 의심: `let mut xs: [i64] = []` 의 MIR Local type_id 가 **RHS `[]` 의
type(unclassified array → `_type_id_of`=0)** 로 설정됨(hir_to_mir.hexa:1604 `rhs_t =
e.children[0].typ`). 선언 annotation `[i64]`(→101)은 let-encode 시 `Array`(elem 손실,
parser.hexa:412 bare array name="Array")로만 살아남아 codegen 도달 못 함. PROBE 가
cont.type_id=0 로 나오면 이 지점 — MIR let-lowering 이 typed-prim 선언 array 일 때 elem
type_id 를 운반하도록 gated(byteeq-safe) 보강 필요(r2b-2). cont.type_id=101 로 나오면
threading 완결 → 게이트 측정만 남음.

---

## LIVE VERDICT (harvest 시 갱신)
(measure_r2b.sh → ~/r2b_RESULT.txt 캡처 후 PROBE/Gate1-5/ratio 기입)
