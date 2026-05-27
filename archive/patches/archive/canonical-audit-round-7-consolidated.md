# canonical-deviation audit round 7 — consolidated (3 axes)

**Status**: audit-report-archived-2026-05-25 — meta audit report (3 design-level axes). FIX-SURGICAL items already shipped; consolidated design clusters need separate RFC track.

PROBE round 7 결과 (numeric coercion · destructuring · operator overload).
FIX-SURGICAL 항목은 별도 PR 로 이미 ship — 본 문서는 **design-level**
이탈 클러스터 consolidated 기록.

## TL;DR

| axis | FIX-SURGICAL (이미 ship) | design-level (본 문서) |
|---|---|---|
| numeric coercion | bool→int (PR #393) | `1 == 1.0` spec · `if 1 {}` spec · `to_float` print fmt |
| destructuring | array/map (PR #394) | tuple `(a,b)` · struct `Point{x,y}` · for-pattern · nested · `_` ignore |
| operator overload | — (없음) | `+` `==` `<` `[]` `()` + trait-driven dispatch (전체 미구현) |

## Axis 1 — Numeric coercion (잔여)

### 1A. `1 == 1.0` → `true`

| lang | behavior |
|---|---|
| Python | true (numeric eq across types) |
| Rust | compile error (type mismatch) |
| Go | compile error |
| Swift | compile error |
| hexa | **true** (Python-leaning) |

**Verdict**: spec decision needed.  hexa already leans Python (`if 1 {}`
truthy, bool→int coercion shipped PR #393).  Status quo (Python-style)
is internally consistent — file as spec confirmation, not bug.

### 1B. `if 1 {}` int-truthy

Same root as 1A — Python-leaning, consistent.  Spec confirmation.

### 1C. `to_float("1.5e3")` prints as `1500` (int form)

이미 round-3 에서 식별 (`println(0.0)` = `0` 동일 root, FIX-SURGICAL
location `runtime_core.c:5222`).  Status quo.

## Axis 2 — Destructuring (잔여)

PR #394 가 `let [a, b] = arr` 와 `let {x, y} = map` 의 codegen 을
완성.  잔여 패턴 모두 **parser-level** 미구현:

### 2A. Tuple destructure `let (a, b) = (1, 2)`

```
parser rejects: expected identifier, got LParen
```

**Cause**: `parse_let` (parser.hexa:1240) 에서 `LParen` branch 부재.
**Pre-req**: hexa 에 tuple value type 자체가 없음.  Tuple = full design
decision (n-ary product type, with-field-access syntax, codegen as
HexaArray fixed-shape, …).

### 2B. Struct pattern `let Point{x, y} = p`

```
parser consumes `Point` as let-name, fails on `{`
```

**Cause**: capitalized-ident lookahead 부재.  Parser 가 `Point` 를 그냥
변수명으로 받음.  Struct pattern 은 `Path + LBrace` 로 dispatch 필요.

### 2C. For-pattern `for [a, b] in pairs`

```
parser rejects pattern; `in` not a binop
```

**Cause**: `parse_for` 가 pattern parser 로 분기 안 함.  추가 bug:
`in` 을 binop fallback 으로 받아서 `[codegen_c2] ERROR: unhandled binary operator: in`
까지 흘러감 (이게 더 시급할 수도).

### 2D. Nested tuple `let ((a, b), c) = (…)`

Same root as 2A.

### 2E. Ignore `_` in tuple

Same root as 2A.

### 2F. Spread destructure `let [h, ...tail]` codegen (이미 ship?)

PR #394 의 DestructLetStmt handler 가 `node.name` (rest_name) 처리:
`rest = hexa_array_drop(__destr_N, len(params))`.  Parser 가 `DotDotDot`
이미 발행 (parser.hexa:1254).  ✅ 완료.

## Axis 3 — Operator overload (전체 미구현)

**현재 상태**: 모든 operator 가 builtin runtime polymorphism only.
struct + struct 는 silent 결과 (잘못된 map merge), struct == struct 는
default false, struct[i] / struct() 는 runtime error.

| operator | hexa-current | Rust/Swift/Py canonical |
|---|---|---|
| `+` `-` `*` `/` `%` | builtin runtime (silent wrong on struct) | trait Add/Sub/… `__add__` |
| `==` `!=` | structural fallback (false) | PartialEq `__eq__` |
| `<` `>` `<=` `>=` | structural fallback | Ord `__lt__` |
| `[]` (index) | runtime error `tag=6` | Index `__getitem__` |
| `()` (call) | returns void | Fn* `__call__` |
| trait Add { … } impl Add for N | parse OK, op-trait → C fn mapping 없음 | full op-trait dispatch |

### 핵심 gap

`gen2_binop` (codegen_c2.hexa:2694) 가 unconditionally `hexa_add(l,r)`
emit.  Type-resolved method lookup 부재.

**Design path** (Rust-style trait-driven 권장):
1. type checker 가 `node.left` 의 static type 식별
2. struct type 이고 matching `fn add(self, …)` impl 존재 시 → direct C
   fn call emit (e.g. `Vec2_add(l, r)`)
3. 미존재 시 → 기존 `hexa_add(l, r)` fallthrough

Pre-req:
- type checker 가 struct 타입 propagate (현재 dynamic-only)
- trait/impl 의 op-trait binding rule (Rust `std::ops::Add`)
- struct-method C 명명 규칙 (`<Struct>_<method>`)

규모: **medium-large** (type 추론 + impl 매칭 + codegen 분기).
Phase 분리 가능:
- Phase 1: `==` only (가장 단순, 결과 항상 bool)
- Phase 2: `<` `>` `<=` `>=` (Ord)
- Phase 3: `+` `-` `*` `/` (Add/Sub/Mul/Div)
- Phase 4: `[]` `()` (Index/Call)

## 우선순위 (다음 cycle 후보)

| 항목 | 규모 | 영향 |
|---|---|---|
| 2C `in` codegen fallthrough fix | small | for-pattern 우선 unblock 가능 |
| 2A tuple type + destructure | large | spec decision 필요 |
| 2B struct pattern parser branch | medium | 단독 가능 (`Point{x,y}` ↔ `obj.x`/`obj.y` 와 sugar) |
| 3 operator overload Phase 1 (`==`) | medium | type-checker 진전 의존 |
| 1A `1 == 1.0` spec confirm | small | 문서화만 |

## 참고

- FIX-SURGICAL clusters → PR #393 (bool coercion) + PR #394 (array/map destructure)
- prior round inbox: `inbox/patches/canonical-audit-round-5-consolidated.md` (round 5, 6-axis)
