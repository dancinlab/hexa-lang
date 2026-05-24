# struct field default values design RFC

**Status**: design-level (PROBE r14-YYY · 2026-05-23)
**Priority**: P2 (편의 + dataclass-style ergonomic)
**SSOT**: 본 RFC

## 1. 현재 동작 (probe + grep 측정)

probe 4종, `hexa parse` + `hexa build` 측정:

| 표현 | hexa 동작 |
|---|---|
| `struct P { x: int = 0 }` decl | parse error 2:12 `expected identifier, got Eq ('=')` |
| `let p = P {}` (no fields) | parse OK · build OK · run 시 `map key 'x' not found` (런타임 결손) |
| `let p = P { x: 5 }` (partial) | parse OK · `clang compile failed` (codegen Point() 시그너처 미스매치) |
| `let p = P { x: 5, y: 10 }` (full) | parse OK · build OK · run OK (`5 10`) |

→ 결론: field-level default 신택스 **미지원** (`=` 토큰 거부). 빈/부분 struct literal 은 parse 단을 통과하나 codegen/runtime 단에서 결손 — 명시적 에러 없이 silent corruption. RFC `r2` 기준 full-form 만 안정.

grep state — `self/parser.hexa:2213 parse_struct_decl`:

```hexa
let fname = p_expect_ident()
if p_peek_kind() == "Colon" {
    p_advance()
    ftype = parse_type_annotation()
}
// ← 여기서 바로 Comma/RBrace. `Eq` 케이스 없음.
fields.push(#{ "kind": "StructField", "name": fname, "value": ftype, ... })
```

→ `StructField` AST 노드에 `default_expr` 슬롯 부재. 신택스+AST 모두 확장 필요.

## 2. 캐노니컬 비교

| 언어 | 신택스 | 부분 생성자 |
|---|---|---|
| C++ | `struct P { int x = 0; };` | `P{}` works |
| Rust | 없음 (stable 미제공, `#[derive(Default)]` 우회) | `P::default()` |
| Kotlin | `data class P(val x: Int = 0)` | `P()` works |
| Swift | `struct P { var x: Int = 0 }` + memberwise init | `P()` works |
| Python | `@dataclass class P: x: int = 0` | `P()` works |
| Go | (없음 — zero value) | `P{}` (zero) |
| TypeScript | `class P { x: number = 0 }` | `new P()` |

→ Kotlin/Swift 모델 권장 — field-level default + auto-memberwise constructor.

## 3. 디자인 결정 (3 옵션)

### 옵션 A: field-level default (Kotlin/Swift)

```hexa
struct Point {
    x: int = 0,
    y: int = 0,
}

let p = Point {}              // default both → (0, 0)
let p = Point { x: 5 }        // y default → (5, 0)
let p = Point { x: 5, y: 10 } // explicit both
```

- 장점: ergonomic · canonical
- 단점: parser + codegen 동시 변경

### 옵션 B: derive Default macro (Rust 모델)

```hexa
@derive(Default)
struct Point { x: int, y: int }

let p = Point::default()
```

- 장점: 명시적 · 기존 @derive 인프라(r10-P1 PR #436) 재사용
- 단점: boilerplate · per-field 다른 default 표현 어려움

### 옵션 C: 함수 wrapper

```hexa
fn new_point(x: int = 0, y: int = 0) -> Point { Point { x: x, y: y } }
```

- 장점: lang 변경 무 (단, fn default-arg 가 선행 land 되어야)
- 단점: 사용자가 매 struct마다 helper 작성

→ **옵션 A 권장** (Kotlin/Swift 모델 · ergonomic · 자연스러운 default merge).

## 4. 의미 결정

- **Const-expr 제약**: default expr 은 컴파일타임 평가 가능해야 함
  - hexa: literal · 단순 산술 · enum variant 허용 (간단)
  - 함수 호출 default 는 Phase 2 (Python `default_factory` 패턴 호환)
- **Eval 순서**: struct 생성 시 매번 eval (Python dataclass `default_factory` 호환)
  - 한 번 eval 후 캐싱은 mutable 공유 버그 유발 → 매번 eval 권장
- **Mutable default 함정**:
  - `struct P { x: [int] = [] }` — 모든 P 인스턴스 list 공유? 또는 새 list?
  - 권장: 새 list 매번 (deep-clone semantics · Python `default_factory` 동일)

## 5. 구현 단계 (stacked PRs)

| PR | 변경 | LOC |
|---|---|---|
| YYY-1 | parser: `field: T = default_expr` 신택스 + `StructField.default_expr` AST 슬롯 | ~60 |
| YYY-2 | codegen: struct literal 의 missing field 자동 default 채우기 | ~100 |
| YYY-3 | type-check: default expr type vs field type 일치 검증 | ~50 |
| YYY-4 | 의미 분쟁: 매번 eval / deep-clone 확정 + 테스트 | ~40 |

총 ~250 LOC · 4-PR stack · g4 통과.

## 6. 영향 surface

| 파일 | 변경 |
|---|---|
| `self/parser.hexa::parse_struct_decl` (L2213) | `Eq` 토큰 확장 + `default_expr` field 추가 |
| `self/codegen.hexa::StructDecl` 경로 (L976·L1130) | struct literal 생성 시 missing field default 호출 |
| `self/type_checker.hexa` (선택) | default expr type 검증 |

## 7. 우회책 (지금)

- 명시 fn 헬퍼: `fn point() -> Point { Point { x: 0, y: 0 } }`
- `Default` trait impl (옵션 B 미리 land 시)

## 8. 관계 RFC / PR

- r14-LL tuple type (PR #506) — 동시 구성 패턴 (positional vs named)
- r14-UU destructuring (PR #515) — field-level 의미 결정 일관
- r14-KK Option prelude (PR #505) — `Option[T] = None` 자연 default
- @derive r10-P1 (PR #436) — 옵션 B 의존
- r2 struct literal 안정성 — full-form 만 측정 PASS
