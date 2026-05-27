# RFC-020 — Enum Payload Variants in hexa-lang

- **상태**: **Spec draft** (2026-05-09) — 미구현, 부분 작동 인지
- **작성일**: 2026-05-09
- **선행 RFC**: RFC-018 (native codegen)
- **사용자 결정 (2026-05-09)**: "ENUM 100% first" + "hexa-lang upstream first" — enum 가능한 곳은 모두 enum, 부족한 부분은 hexa-lang 자체에 추가
- **영향 영역**: `self/parser.hexa` (construction syntax), `self/type_checker.hexa` (variant type registry + pattern binding), `self/native/hexa_cc.c` (codegen), `self/ir/types.hexa` (EnumType.variants typing)

---

## 1. 동기 (Why)

`compiler/` 트리 작성 도중, hexa stage0의 enum payload 능력을 점검한 결과 **부분 작동** 상태 발견. 사용자는 **enum 100% 사용**을 원하고, 부족한 부분은 hexa-lang 자체(upstream)에 채우기를 결정. 본 RFC는 그 정확한 범위 + 변경 점.

## 2. 현 상태 — Agent A/B 조사 결과

### 2.1 작동 (Agent B 확인)

- 단순 enum: `enum Color { Red, Green, Blue }` ✅
- 단일 필드 payload **선언**: `enum Shape { Circle(Int), Rect(Int), Unit }` ✅
- match 패턴 **인식**: `match s { Shape::Circle(r) -> r * r * 3, ... }` ✅
- match 7 패턴 (wildcard / literal / binding / variant / struct / tuple / guard) ✅
- 작동 증명: `self/test_enum_variant.hexa`
- breakthrough commit: `87fd69b` "Mk.I+ enum payload + turbofish + self-hosting"
- `match` 예약어, arrow `->` (not `=>`)

### 2.2 미흡 (Agent A 분석, 파일:라인)

| 영역 | 상태 | 위치 |
|---|---|---|
| Parser: variant payload 파싱 | ✅ `node.variants[i].items` 에 저장 | `self/parser.hexa:1896-1935` |
| Parser: match 패턴 payload | ✅ `pat.left` (단일) / `pat.items` (다중) | `self/parser.hexa:2294-2363` |
| Parser: **construction `E::Variant(x)`** | ❌ 빈 EnumPath 만들고 끝 | `self/parser.hexa:3016-3054` |
| TypeChecker: variant 타입 등록 | ❌ 이름만, payload type 무시 | `self/type_checker.hexa:1280-1284` |
| TypeChecker: pattern binding | ❌ `pat.left` / `pat.items` 무시 | `self/type_checker.hexa:1087-1098` |
| TypeChecker: EnumPath inference | ⚠️ enum 이름만, payload 정보 잃음 | `self/type_checker.hexa:1176-1178` |
| Codegen: enum decl C 출력 | ⚠️ tag만, struct/union 없음 | `self/native/hexa_cc.c:18344-18376` |
| Codegen: match dispatch | ⚠️ tag 비교만, payload 추출 없음 | `self/native/hexa_cc.c:18475` |
| Codegen: pattern binding 변수 | ❌ 캡처 변수 emit 안 함 | (동일) |
| 다중 필드 (`A(int, string)`) | ❌ 전혀 없음 | 전 트리 |

**진단**: 단일 필드 payload는 **선언과 match 인식**까지만 작동. **construction**, **type binding**, **codegen extraction** 미흡. 인터프리트 모드에서 동적 처리되어 일부 테스트가 통과한 것으로 추정.

## 3. 디자인 결정

### 3.1 Payload 형태 — **단일 필드 + struct 임베드 우선**

| 후보 | 비유 | 채택? |
|---|---|---|
| **A. 단일 필드 + struct 임베드** | `enum Stmt { Assign(AssignData), BinOp(BinOpData) }` | ✅ |
| B. Rust 다중 (positional) | `enum E { A(int, string) }` | 후순위 |
| C. Swift labeled | `enum E { A(x: int, y: string) }` | 후순위 |
| D. Tuple type | `enum E { A((int, string)) }` | 검토 후 |

**채택 A**. 이유
- 이미 단일 필드는 부분 작동 — 보완만 하면 즉시 사용
- struct 임베드로 모든 ADT 표현 가능 (다중 필드 효과)
- parser / typechecker / codegen 변경 최소
- 다중 필드 (B/C/D) 는 기능 추가형 — 1차 정착 후 별도 RFC

### 3.2 Construction syntax — **`E::Variant(value)` 표준화**

```hexa
let s: Shape = Shape::Circle(42)
let v: Result = Result::Ok(my_struct)
let n: Result = Result::Err("not found")
```

parser `parse_primary()`에서 `E::Variant` 다음 `(` 발견 시 인자 1개 파싱.

### 3.3 Pattern binding — **단일 필드 캡처**

```hexa
match s {
    Shape::Circle(r) -> r * r * 3,
    Shape::Rect(side) -> side * side,
    Shape::Unit -> 0
}
```

`r`, `side` 가 match arm 안 scope에 변수로 도입.

## 4. 변경 점 (구체)

### 4.1 self/parser.hexa

`parse_primary()` (~line 3016) 에서 `EnumPath` 노드 생성 직후

```
if peek() == "lparen" {
    advance()  // (
    let arg = parse_expr()
    expect("rparen")
    node.payload_expr = arg     // 새 필드
}
```

### 4.2 self/type_checker.hexa

a) variant payload 타입 등록 (~line 1280)

```
if vnode.items.len() > 0 {
    let payload_type = resolve_type(vnode.items[0])
    enum_variant_payload_types.push(payload_type)
} else {
    enum_variant_payload_types.push(none)
}
```

b) pattern binding (~line 1087)

```
if pat.kind == "EnumPath" && pat.left != "" {
    let payload_type = lookup_variant_payload(pat.name, pat.variant)
    tc_define(pat.left, payload_type)   // r, side, val 등 scope 도입
}
```

c) construction type check (~line 1176, EnumPath inference)

```
if node.payload_expr != none {
    let arg_type = infer(node.payload_expr)
    let expected = lookup_variant_payload(node.name, node.variant)
    assert_compatible(arg_type, expected)
}
return enum_type(node.name)
```

### 4.3 self/native/hexa_cc.c

a) `gen2_enum_decl()` (~line 18344) — payload 있는 variant 위해 union/struct 생성

```c
// Generated for enum Shape { Circle(Int), Rect(Int), Unit }
typedef struct {
    int tag;
    union {
        int Circle_payload;
        int Rect_payload;
        // Unit: no payload
    } data;
} Shape;
```

b) `gen2_match_cond()` (~line 18475) — payload 추출 + 변수 binding emit

```c
if (s.tag == Shape_Circle) {
    int r = s.data.Circle_payload;     // ← new
    /* arm body using r */
}
```

c) construction emit — `E::Variant(x)` →

```c
((Shape){ .tag = Shape_Circle, .data.Circle_payload = 42 })
```

### 4.4 self/ir/types.hexa

`EnumType.variants` 의 `IrType|none` 약속이 실제로 채워짐. self/ir/instr.hexa 의 Operand workaround 주석은 다중 필드 부재만 가리키는 것으로 의미 좁힘.

## 5. 마이그레이션 (struct + kind → enum payload)

### compiler/ 트리

| 파일 | 현 상태 (after Agent C) | 마이그레이션 |
|---|---|---|
| `compiler/lex/tokens.hexa` | TokenKind enum (payload 없음) | 변경 없음 |
| `compiler/parse/ast.hexa` | ItemKind/ExprKind enum + struct(kind/children) | enum payload 적용 후 sum type으로: `enum Expr { LiteralInt(IntLit), Call(CallData), ... }` |
| `compiler/diag/catalog.hexa` | Severity/FixItKind enum | 변경 없음 |
| `compiler/ir/hir.hexa` | struct + string kind | sum type 마이그레이션 (payload 보완 후) |
| `compiler/ir/mir.hexa` | 동일 | 동일 |
| `compiler/ir/lir.hexa` | 동일 | 동일 |

### self/ir/ 트리

`Operand` (instr.hexa:57) struct + kind discriminator → sum type으로:

```hexa
enum Operand {
    Value(ValueId),
    ImmI64(IntData),
    ImmF64(FloatData),
    Block(BlockId),
    Func(FuncId),
    String(StringRef),
    Phi(PhiData),
    Switch(SwitchCase),
    Cmp(CmpData),
    Param(ParamIndex)
}
```

→ 코드 가독성·타입 안전성 ↑.

## 6. 단계적 로드맵

| Phase | 산출물 | 전제 |
|---|---|---|
| RFC020-A1 | parser construction syntax (`E::V(x)` 받기) | parser 변경 |
| RFC020-A2 | typechecker variant payload type 테이블 | A1 후 |
| RFC020-A3 | typechecker pattern binding | A2 후 |
| RFC020-A4 | hexa_cc.c codegen — struct/union + match 추출 | A3 후 |
| RFC020-A5 | 회귀 테스트: `self/test_enum_variant.hexa` 인터프리트 + native 양쪽 PASS | A4 후 |
| RFC020-B1 | `self/ir/Operand` sum type 마이그레이션 | A5 후 |
| RFC020-B2 | `compiler/ir/*` sum type 마이그레이션 | B1 후 |
| RFC020-C1 | (옵션) 다중 필드 variant — Rust positional `(int, string)` | B 정착 후 별도 RFC |

## 7. 미해결

1. **인터프리터 vs native 동작 차이** — `hexa run` vs `hexa cc` 결과 정확히 어떤 케이스가 다른지 회귀 테스트로 확인 필요
2. **다중 필드 디자인** — Rust positional vs Swift labeled vs tuple — 1차 정착 후 결정
3. **Generic enum** — `enum Option<T> { Some(T), None }` 지원 시점
4. **struct 임베드의 reflection** — atlas L 노드 인용 시 payload struct도 atlas-aware인가
5. **Marshal/serialize** — payload struct가 hash 가능해야 fingerprint dedup (Decision 5d) 가능

## 8. 한 줄 결론

hexa stage0 enum은 **단일 필드 payload 의 선언/match가 부분 작동**, **construction·typing·codegen 보완 필요**. 보완 후 **단일 필드 + struct 임베드** 패턴이 모든 ADT를 표현하므로 다중 필드는 후순위. parser·typechecker·hexa_cc.c 5개 hook 지점만 손대면 완전 작동. 끝나면 `self/ir/Operand` 와 `compiler/ir/*` 의 string `kind` discriminator 패턴이 sum type 으로 치환됨.
