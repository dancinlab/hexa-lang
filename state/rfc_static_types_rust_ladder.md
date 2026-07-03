# RFC — Wall A: static-types Rust-parity REJECT 사다리 (r1~r6)

상태: **측정 종착(MEASURED CEILING)** — r6 = scope-wireable 마지막 rung.
플래그: `HEXA_STATIC_TYPES=1` (default-OFF · byteeq/gen3≡gen4 중립)
진단코드: `HX3011` "mismatched types" (Rust E0308 faithful · S3 · FATAL under flag)
삽입지점: `compiler/check/types.hexa` `_infer_expr` (지역 `let`/assign/struct-literal 경로)
SSOT 셀: `ARCHITECTURE.json` convergence `WALL-A-STATIC-TYPES-REJECT-LADDER`

이 문서는 브랜치 `feat/static-types-rust-r6`(PR #4108)의 CHANGELOG/ARCHITECTURE가
참조하나 커밋되지 않았던 dangling RFC를 브랜치 소스 자체에서 재구성한 것이다.
모든 file:line 앵커는 본 브랜치 트리에서 직접 검증했다.

---

## 1. 동기

hexa는 동적 런타임 타입(박싱 HexaVal 태그-디스패치) 언어다. Wall A는 **일부 지역
스코프**에서 Rust E0308 "mismatched types" REJECT 규칙을 SOUND하게 도입하려는
opt-in 슬라이스다. 전 경로가 `env("HEXA_STATIC_TYPES") == "1"` 게이트의 첫 번째
`&&` 피연산자로 단락(short-circuit)되므로, default 빌드는 진단 스트림이 byte-동일
→ byteeq 3-target·gen3≡gen4 무결성이 보존된다. 플래그-ON에서만 codegen 전에
FATAL로 REJECT한다.

기존 top-level `let`-ITEM RHS 체크가 이미 갖던 E0308 규칙을 지역(in-fn-body)
바인딩·assign·struct-literal 로 계단식으로 확장한다. 각 rung은 독립 land.

---

## 2. Rung 사다리 (file:line 앵커 — 본 브랜치서 검증)

전부 `compiler/check/types.hexa` `_infer_expr` 내부. 각 arm은 KNOWN scalar
primitive끼리만 비교하고(`_types_kind_is_scalar`), int/float 리터럴 coercion은
Rust와 동일하게 유지한다(`_types_assignable`).

| rung | 앵커 | LHS/컨텍스트 | 설명 |
|------|------|--------------|------|
| **r1** | `types.hexa:2119` (env-gate) / `:2129` (arm) | 지역 `let x: T = <literal>` | scalar-literal RHS(int/float/string/bool/char) vs scalar 어노테이션. top-level let-ITEM E0308을 지역 let으로. |
| **r2** | `types.hexa:2140` (`else if`) | 지역 `let x: T = <ident\|call>` | non-literal known-type RHS. 추론-scalar ident/call이 어노테이션과 불일치 시 REJECT. 예: `let a: i32 = 5; let b: string = a;` |
| **r3** | `types.hexa:2199` (env-gate) / `:2200` (ident arm) | decl/init-split assign `x = <expr>` | Ident LHS의 scalar 재대입. `lhs_t`/`rhs_t` 둘 다 known scalar이고 불일치 시 REJECT. 발화 시 generic HX3001을 억제(`r3_rejected`, 한 실수 = 한 에러). |
| **r4** | `types.hexa:2205` (`else if _types_is_index`) | array element-fit `a[i] = <expr>` | Index LHS(children[0]=base, children[1]=index). base가 plain ident이고 Block-case가 기록한 element type 키 `[]<name>` 가 known scalar면 그것을 RHS와 비교(NOT `lhs_t` — Index의 `_infer_expr`는 STUB-v1 unknown). |
| **r5** | `types.hexa:2234` (`else if _types_is_field`) | struct field-type assign `s.field = <expr>` | Field LHS(text=field name, children[0]=receiver). receiver가 KNOWN struct의 ident이고, side registry(env struct Type이 field 이름을 DROP하므로 유일 carrier)에 등록된 field 타입이 known scalar면 RHS와 비교. |
| **r6** | `types.hexa:2398` (`env == "1" && _cg_is_struct_lit`) | struct literal `Point{ x: <e>, y: <e> }` | **마지막 scope-wireable rung.** StructLit(text=struct 이름, children=per-field-init Ident, 각 text=field 이름·children[0]=value expr). r5의 (struct,field)→typename side registry 재사용. 각 field-init의 선언 field 타입과 추론 value 타입이 BOTH known scalar이고 불일치 시 HX3011. 플래그-ON path는 legacy STUB이 도달 못하던 각 value expr을 `_infer_expr`로 추론하므로 inner value 에러도 노출. |

공통 emit 경로: 전부 `_emit_hx3011(expected, actual, span, out)` → 진단 `HX3011`
→ `rustc_hir_typeck` `demand_coerce` → `report_mismatched_types`(E0308)와 1:1 대응.

---

## 3. 플래그 표면

- **환경변수**: `HEXA_STATIC_TYPES=1` — OFF가 default. `env(...)` 호출이 매 arm의
  첫 `&&` 피연산자라 OFF에서는 STUB로 단락 → byte-identical.
- **진단코드**: `HX3011` (`compiler/diag/catalog.hexa`), title "mismatched types",
  severity Error, stage S3, template
  `mismatched types: expected \`{expected}\`, found \`{actual}\``.
- **적용범위**: 지역(in-fn-body) `let`/assign/struct-literal의 KNOWN scalar-primitive
  간 불일치만. int/float 리터럴 coercion(`let x: i32 = 5`, `let y: f64 = 1.5`)은
  Rust처럼 통과. unknown/non-scalar/nominal-field 존재검사는 r6 범위 밖(별도 진단).

---

## 4. 측정 종착(CEILING) 판정 — r7+ 불가 근본벽

r6이 `_infer_expr`의 **scope-local** 스코프로 배선 가능한 마지막 rung이다.
r7+(generic monomorphization·trait static-dispatch·nested receiver `s.inner.x`)는
`_infer_expr`의 강(鋼) 안에서 닿지 않는다. 근본벽 두 갈래(본 브랜치서 검증):

### 4-1. `_types_lower_type_ref` degraded sentinel — `types.hexa:931-939`

```
// generic / fn / tuple / atlas_kind — degrade gracefully
return Type {
    kind: tr.kind + ":" + tr.name,
    def: _types_miss_def_id(),
    args: [],    // ← 타입파라미터 소거
    ret: [],     // ← 타입파라미터 소거
    domain: "",
    unit: ""
}
```

`generic:`/`fn:`/`tuple:` TypeRef를 lower할 때 `args`/`ret`를 **빈 배열로 소거**한다.
즉 `Vec<i32>`·`fn(i32)->bool`·`(i32, f64)`의 concrete 타입 파라미터 `T`가 Type에
실리지 않는다. generic monomorphization·trait static-dispatch는 concrete `T`를
요구하므로, 이 degraded sentinel 위에서는 scalar-scalar REJECT를 세울 수 없다.
이는 dynamic 런타임 type-erasure의 근본벽이라 scope-local arm 추가로는 못 넘고,
dynamic→static 런타임 재설계가 필요하다.

### 4-2. check-side 배열 element type 분기 부재 vs `ast_to_hir.hexa:159-169`

lower 계층 `_hir_lower_type_ref`는 배열 element type을 온전히 세운다:

```
// ast_to_hir.hexa:159
if tr.kind == "generic" && _hir_is_array_name(tr.name) && len(tr.args) >= 1 {
    let mut elem_args: [Type] = []
    elem_args.push(_hir_lower_type_ref(tr.args[0]))
    return Type {
        kind: "array",
        def: _hir_miss_def_id(),
        args: elem_args,   // ← element type 보존
        ret: [],
        domain: "",
        unit: ""
    }
}
```

그러나 check-side `_types_lower_type_ref`(types.hexa:905~939)에는 이에 대응하는
`"generic" && array-name` 분기가 **없다** — 배열 타입은 4-1의 `generic:`
degraded sentinel로 떨어져 element type이 소거된다. r4가 배열 element-fit를
잡을 수 있는 이유는 이 lower가 아니라 Block-case가 기록한 별도 env 키
`[]<name>` 덕분(우회). 일반 nested/parameterized 배열 타입은 check-side에서
element type을 못 얻으므로 r4를 넘는 배열 rung은 두 lower 경로 통합 없이는 불가.

### 판정

- **r6 = scope-wireable 마지막 rung.**
- **r7+(generic/trait static-dispatch·nested receiver) = MEASURED 천장** — dynamic
  런타임 type-erasure 근본벽. scope-local `_infer_expr` arm으로는 도달 불가.
- 넘으려면: check-side `_types_lower_type_ref`에 배열/generic 파라미터-보존 분기를
  추가하고(ast_to_hir 4-2 미러), degraded sentinel(4-1)을 concrete-T-보유 표현으로
  교체 = dynamic→static 런타임 재설계. scope-local 확장이 아님.

---

## 5. 무결성

- 전 rung env-gate 단락 → default 빌드 byte-identical → byteeq 3-target·gen3≡gen4
  중립(플래그-ON path만 추론·REJECT).
- HX3011은 플래그-ON에서만 FATAL. OFF에서는 미emit.
- r3/r4/r5는 발화 시 generic HX3001을 억제(`r3_rejected`)해 한 실수 = 한 에러.
