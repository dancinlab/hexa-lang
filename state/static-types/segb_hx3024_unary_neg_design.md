실측 완료 — 설계 결론을 보고합니다.

---

# static-types 세그먼트(b) — REJECT rung 선정 + impl 스펙

**기준 트리 = origin/main `2f5c3a61b`(FLIP-3 flagless, 지시된 기반 커밋과 일치).** 현 체크아웃 브랜치(`fix/install-bare-cuda-pip`)는 FLIP-3 이전이라 `_types_strict_for`가 없어, main 블롭(`types.hexa`=0b384841 · `catalog.hexa`=50cb8da6 · `types_test.hexa`=1e1174de)을 직접 대조했습니다. 아래 types.hexa/catalog 라인번호는 전부 origin/main 기준입니다.

## 1. 실측: 5후보 전원 기커버 (핵심 발견)

후보 리스트가 레거시 S3 체커를 credit하지 않고 작성된 것으로 판정 — **5후보 모두 이미 always-on Error rung이 존재**합니다:

| 후보 | 기존 코드 | 발화 지점 (types.hexa) | 판정 |
|---|---|---|---|
| 1. fn-arg arity | **HX3002** (Error, catalog 294-301) | `_types_check_call` 3584-3586: callee가 fn-type으로 해석되면 무조건 count 비교 | **전부 커버 → 제외** (프롬프트 예상대로) |
| 2. fn-arg type | **HX3003** (Error, 303-311) | 3588-3606: `!_types_equal(want,got)` && got≠unit | 커버 — 단 **coercion-불충실** (아래 §6) |
| 3. binop type | **HX3001** (Error, 285-293) | `_types_check_binop` 3357-3461: 수치 비강제혼합 3413-3414 · 비수치 arith 3433-3436 · compare 3451-3454 | 커버 (string-`+` concat은 런타임 합법이라 의도적 허용 3399-3401) |
| 4. if/else 통일 | **HX3001** | If arm 2671-2679: `_types_assignable` + unit 관용, cond≠bool은 2654-2655 | 커버 (E0308 if-else 그 자체) |
| 5. return vs decl | **HX3004** (Error, 312-320) | Return arm 2749-2752 (`_types_assignable`, unit-decl 관용) + item 트레일링바디 5000-5006 + let-item 5017-5021 | 커버 |

파라미터/반환 레지스트리도 이미 존재: pre-pass `_collect_item_types`(4748~)가 `_types_signature_type`(4647-4669)으로 fn 타입(args=파라미터 주석, ret)을 TypeEnv에 등록. 미주석 파라미터는 empty-kind→`_types_equal`(2122-2124)이 관용.

**따라서 프롬프트의 "이미 있으면 제외/확장 판정" 규칙을 전 후보에 적용**해, 같은 공간에서 **측정된 유일한 제로-커버 표현식 위치**를 새 rung으로 선정했습니다.

## 2. 선정: HX3024 = 단항 `-` 비수치 피연산자 REJECT (Rust **E0600**)

`_infer_expr`의 UnOp arm(**types.hexa:2510-2518**)은 순수 pass-through — 진단 0개 방출(`_types_is_unop` 사용처는 546 정의·2510 단 한 곳, grep 전수확인). 즉 `-s`(string)는 S3를 무사통과합니다.

**근거 4축:**
- **완성도(갭 최대)**: 표현식 포지션 중 유일하게 검사 자체가 전무. 이미 커버된 binop arith rung(3433-3436)의 정확한 단항 거울.
- **표준 최충실**: Rust E0600 "cannot apply unary operator `-` to type X" (rustc_hir_typeck/src/op.rs `lookup_op_method` 실패 → E0600). 
- **가치 = 보장된 런타임 throw의 컴파일타임 전진**: `-x`는 전 타깃에서 `hexa_sub(0,x)`로 낮춰지고(arm64_darwin.hexa 4092-4109 · x86_64_linux.hexa 2131/3769-3795), **양쪽 런타임 디스패처 모두** string/char 피연산자에 throw — stdlib `rt_sub`(numeric.hexa:1506-1508 "cannot subtract non-numeric operand") + C substrate `hexa_sub`(runtime_core.c:7793-7797). 죽은 코드에 숨은 `-string` 버그가 빌드타임에 잡힘.
- **최저리스크**: 신규 인퍼런스/레지스트리/threading 0 — 피연산자 타입은 이미 손에 있는 `inner` 재귀 결과. 단일 arm 삽입.

**중요한 언어시맨틱 경계 2개(실측)**:
- `!`/`not`은 **truthiness 기반**(hexa_truthy, 전 태그 수용 — arm64:4111-4120) → **어떤 피연산자도 절대 flag 금지**.
- **bool은 면제**: `_HX_COERCE_BOOL`(runtime_core.c:7770-7773) + rt_sub bool arm(numeric.hexa:1499)이 bool→int 합법화(`-true`==-1). Rust는 `-bool`을 거부하지만 hexa 체커의 계약은 "런타임 정책 정확 일치"(binop string-`+` concat 허용과 동일 계약) → 면제.

## 3. impl 스펙 (file:line 정밀)

### (a) 게이트 삽입 — types.hexa:2510-2518 UnOp arm

기존:
```hexa
    if _types_is_unop(e.kind) {
        if len(e.children) == 0 { return _types_empty_type() }
        let inner = _infer_expr(e.children[0], env, ctx, out)
        // Unary `-` keeps the operand's numeric type; otherwise pass through.
        if e.text == "-" && _types_is_numeric(inner) {
            return inner
        }
        return inner
    }
```
변경(최소 diff — 기존 return 로직 불변, emit 블록만 삽입):
```hexa
    if _types_is_unop(e.kind) {
        if len(e.children) == 0 { return _types_empty_type() }
        let inner = _infer_expr(e.children[0], env, ctx, out)
        // static-types segment(b) — HX3024 REJECT: unary `-` on a KNOWN
        // non-numeric scalar (string/char). `-x` lowers as hexa_sub(0, x) on
        // every target, and BOTH runtime dispatchers (stdlib rt_sub +
        // C-substrate hexa_sub) throw "cannot subtract non-numeric operand"
        // — a guaranteed runtime type error, surfaced at S3 instead (Rust
        // E0600). bool is EXEMPT (_HX_COERCE_BOOL/rt_sub legalize bool→int;
        // the checker matches runtime policy exactly, same contract as the
        // binop string-`+` concat arm). `!`/`~` never flag (`!` = truthiness
        // via hexa_truthy, every tag legal). Unknown/unit/HexaVal/aggregate
        // operands stay conservatively SILENT (under-reject).
        if e.text == "-" {
            if inner.kind == "string" || inner.kind == "char" {
                _emit_hx3024(inner, e.span, out)
            }
        }
        // Unary `-` keeps the operand's numeric type; otherwise pass through.
        if e.text == "-" && _types_is_numeric(inner) {
            return inner
        }
        return inner
    }
```

### (b) emit helper — `_emit_hx3017`(2019-2029) 직후, `_emit_hx3002`(2031) 앞에 삽입

HX3011/HX3016와 동일한 밴드 shape(카탈로그 default=Error·strict 브랜치=`diag_emit`):
```hexa
// HX3024 — unary-minus non-numeric-operand REJECT (always-on since FLIP-3
// flagless), static-types segment(b). Rust E0600-faithful "cannot apply
// unary operator `-`" — fire set + runtime-policy rationale at the UnOp arm
// in _infer_expr. SAME band policy as HX3011/HX3016: catalog-default Error
// for real source (REJECT — main.hexa _has_errors aborts before codegen),
// re-banded to Warning for byte-eq test fixtures via _types_strict_for.
fn _emit_hx3024(actual: Type, sp: Span, out: array) {
    let mut b = diag_new("HX3024")
    b = diag_span(b, sp)
    b = diag_arg(b, "actual", _type_display(actual))
    if _types_strict_for(sp.file) {
        out.push(diag_emit(b))
    } else {
        out.push(diag_emit_sev(b, Severity::Warning))
    }
}
```

### (c) catalog 엔트리 — catalog.hexa, HX3023 블록(470-487) 닫힌 뒤 삽입

```hexa
    DiagSpec {
        code: "HX3024",
        title: "cannot apply unary operator `-`",
        severity: Severity::Error,
        stage: "S3",
        template: "cannot apply unary operator `-` to type `{actual}`",
        explain: "Static type check (always-on since FLIP-3 flagless — Rust-style, no disable switch), static-types segment(b). A unary negation `-x` whose operand's inferred static type is a KNOWN non-numeric scalar (`string` or `char`) can never succeed: codegen lowers `-x` as `hexa_sub(0, x)` on every target, and both runtime dispatchers (stdlib rt_sub and the C-substrate hexa_sub) throw 'cannot subtract non-numeric operand' at run time. This is the Rust E0600 'cannot apply unary operator' rule (rustc_hir_typeck op.rs lookup_op_method failure → E0600), the unary mirror of the always-on binop arithmetic mismatch (HX3001). Conservative under-reject: it fires ONLY when the operand type is the KNOWN scalar string/char — unknown idents (empty kind), `unit` (unresolved-callee sentinel), HexaVal/any dynamics, aggregates, and generics all stay SILENT. `bool` is deliberately EXEMPT: the runtime legalizes `-true` via bool→int coercion (_HX_COERCE_BOOL / the rt_sub bool arm), and the checker matches runtime policy exactly (the same reason string `+` concatenation is legal at the HX3001 binop site). Logical `!x` is NEVER flagged — it lowers through hexa_truthy, which accepts every tag; `~x` is likewise out of scope. Emitted unconditionally (FLIP-3 flagless) as a build-refusing ERROR for real source (REJECT), while byte-eq TEST FIXTURES (`compiler/test/` corpus + `*_test.hexa`) stay WARNING via the `_types_strict_for` path carve-out. No env opt-out or severity switch. Fix: convert the operand to a number first (e.g. parse the string), or fix the producing expression.",
        fix_it_kind: FixItKind::None
    },
```

### (d) 타입정보 접근경로
**신규 인프라 불요.** 피연산자 타입 = 같은 arm의 `inner`(재귀 `_infer_expr` 결과). KNOWN이 되는 경로는 기존 그대로: 리터럴(2475-2479) · 주석 파라미터(`_types_bind_params` 4843) · fn 반환(콜체커 3609) · r3 주석 let env(2554-2555) · r9a Index/Field read.

## 4. Conservative 경계 (정확한 skip 조건)

- `e.text != "-"` → silent (`!`·`~`. 파서는 토큰 리터럴 텍스트만 방출 — parser.hexa:683-701, `-`/`!`/`~` 세 가지뿐. codegen의 "neg"/"not" 별칭은 AST에 나타나지 않음)
- `len(e.children)==0` → 기존 early return
- `inner.kind == ""`(미해석 ident/미추적 로컬) → silent
- `inner.kind == "unit"`(미모델 callee 센티널) → silent
- `_is_hexaval(inner)`(named:HexaVal/named:any) → silent
- 수치 kind(i8~i64·f16/bf16/f32/f64) → 합법
- **bool → 면제**(런타임 합법)
- aggregate/`named:*`/struct/enum/fn/atlas_* → silent (런타임은 throw하지만 KNOWN-scalar 사다리 계약상 non-scalar는 under-reject)
- **발화 집합은 명시적 열거 `inner.kind == "string" || inner.kind == "char"` 만** — `!_types_is_numeric` 파생식 금지(미래 scalar kind가 자동으로 발화 집합에 합류하는 것 방지)

## 5. Companion test (types_test.hexa)

1. 신규 빌더 — `_ident_expr`(75-99) 미러:
```hexa
fn _unop_expr(op: string, inner: Expr, file: string, line: i64, col: i64) -> Expr {
    let mut kids = []
    kids.push(inner)
    return Expr { kind: ExprKind::UnOp, span: _span(file, line, col, len(op)),
        text: op, annotations: [], children: kids, atlas_ref: _empty_atlas_ref() }
}
```
2. `_build_case_unop_neg()` — real-source 경로 `f="case_unop_neg.hexa"`: `fn u(s: string) { let x = -s   let y = -5   let z = !s }` (`_param("s","string",…)` → ident `s`가 string으로 infer). 기대: **HX3024 ×1 · Error ×1 · Warning 0** — positive는 `-s` 하나뿐, `-5`(수치)·`!s`(truthiness)는 clean control로 무발화 증명. 추가로 HX3001=0 assert(binop 경로 cross-fire 없음).
3. `_build_case_unop_neg_fixture()` — 동일 AST, `f="compiler/test/macho_p0_corpus/case_unop_fixture.hexa"`(FLIP-2 프로브 748 미러). 기대: **HX3024 ×1 · Warning ×1 · Error 0**. env 분기 없는 무조건 계약(FLIP-3 방식)으로 작성 — `_count_code`(1533)/`_count_code_sev`(1549)로 검증, 러너 등록은 기존 케이스 호출 패턴을 따름.

## 6. byteeq중립 논증 + 위험/함정

**중립 논증**: 변경은 S3 diag-only — codegen/lower/emit 파일 무접촉, 타입은 HIR→MIR 전에 소거되어 방출 바이트에 흔적이 없고, 위반 0인 트리에서는 진단 스트림조차 불변이므로 gen3≡gen4 byte-identity에 영향 없음. 유일한 행동 변화는 "오늘 컴파일되고 실행 시 throw하는(또는 dead code에 묻힌) 소스"가 빌드 거부되는 것 — 이것이 rung의 목적. 최종 증명은 FLIP-3 전례(#4594)와 동일하게 PR의 byteeq-real 3-target GREEN.

**위험/함정**:
1. **오탐 방향 = dead code**: 실행 안 되는 `-string` 코드는 오늘 빌드 통과 → rung 후 하드 Error. 머지 전 **census 필수** — `static-types-corpus.yml` workflow_dispatch(FLIP-1 3813-file census 전례), 0 확인 후 머지. >0이면 TP(소스 수정)/FP(스펙 결함) 분류.
2. **census 워크플로 lockstep**: `.github/workflows/static-types-corpus.yml:175`의 grep 패턴 `HX301[167]` → `HX30(1[167]|24)`로 확장 + 6/10/83/122행 타이틀 문자열 — 같은 PR(CI-only·byteeq중립).
3. `~`(BitNot)는 **flag 금지**: arm64 codegen이 unknown-unop pass-through 처리(arm64_darwin.hexa:4122-4126, 사실상 no-op) — 시맨틱 미확정이라 codegen 정리가 선행돼야 할 별개 이슈.
4. 문서 lockstep: ARCHITECTURE.json WALL-A convergence 노드에 segment(b) rung 기록(+선택적으로 HX3011 explain의 rung 목록 언급). CLI 변화 없음 → `hexa --help` lockstep 불요.
5. 레지스트리 부재 threading 이슈: **없음**(§3d).

**부수 발견(별도 follow-on 후보, 이번 rung 아님)**:
- **HX3003 coercion-불충실**: 3592가 `_types_assignable`(2198) 아닌 `_types_equal`(2122)을 사용 → 리터럴 coercion 부재(`f(0)`을 `p: i32`에 넘기면 Rust는 통과, hexa는 REJECT)·HexaVal 와일드카드 관용 부재. 완화(loosening) 수정이라 REJECT rung은 아니고 별도 faithfulness-fix PR감.
- **미주석 로컬 인퍼런스 부재**가 진짜 커버리지 승수이지만, 밴드 분리 없는 레거시 always-on Error emitter(HX3001/3003/3004)에 직결되어 fixture RED 리스크 → 자체 설계 필요(r4 `[]name`/r5 `{}name`식 collision-free key 사이드 레지스트리 idiom).

## 7. 미검증 지점

- types.hexa/catalog/types_test 라인번호는 origin/main 블롭에서 검증. **runtime/codegen/parser 참조(runtime_core.c 7770-7800 · numeric.hexa 1489-1517 · arm64_darwin.hexa 4092-4127 · x86_64_linux.hexa 2131/3769-3795 · parser.hexa 683-701)는 현 브랜치 체크아웃(4efa2f89b)에서 읽음** — 안정 파일이지만 구현 시 main에서 재확인 권장.
- **corpus census 미실행**(mini 빌드 불가·pool 필요) — "real source 위반 0"은 전제조건이지 측정치 아님.
- UnOp 무검사 주장은 types.hexa(S3) 전수 grep 기준 — S2 bind/S4 domain의 UnOp 개입 전무는 미전수감사(S4 HX4001은 binop `/` 전용 확인).
- thumbv7em/nvptx의 unop lowering 미확인(3-target 중 arm64/x86만 hexa_sub 경유 실측).
- rt_sub(stdlib 경로)와 C hexa_sub 양쪽 모두 throw 확인했으므로 어느 쪽이 shipping default든 시맨틱 주장은 성립.
