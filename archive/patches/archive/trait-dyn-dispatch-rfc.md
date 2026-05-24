# trait dyn dispatch `&dyn Trait` design RFC

**Status**: design-level (r14 cycle 10, 2026-05-24)
**Priority**: P2 (트레이트 polymorphism — 큰 lang feature)
**SSOT**: 본 RFC · PR #348 (`hexa_is_type` header fix, static dispatch 확인) · PROBE r2

## 현재 동작 (probe + grep 검증)

probe `/tmp/probe_dyn_trait_r14.hexa` — `hexa parse` 결과:

| 표현 | hexa 동작 |
|---|---|
| `trait T { fn m() }` decl | ✅ (PROBE r2, parser.hexa:1343 `parse_trait_decl`) |
| `impl T for S { fn m() {...} }` | ✅ (PROBE r2, parser.hexa:1342 `parse_impl_block`, #348 후) |
| `s.m()` static dispatch (S struct에서) | ✅ |
| `fn f(x: &dyn T)` parameter | ❌ `Parse error: expected identifier, got BitAnd ('&')` + `unexpected token Dyn` |
| `let v: &dyn T = &s` | ❌ 동일 — `&` type position 미인식 |
| `[&dyn T]` collection | ❌ 동일 |
| trait object polymorphism in collection | ❌ DynRef ABI 부재 |

grep 상태:
- `Dyn` 토큰은 lexer.hexa:63 에 이미 keyword 로 등록됨 (`if word == "dyn" { return true }`)
- 하지만 parser/codegen 어디서도 사용하지 않음 (orphan keyword)
- `vtable`/`DynRef`/`dyn_dispatch` 키워드 codegen.hexa·codegen_c.hexa·parser.hexa 전부 0 occurrences
- TraitDecl + ImplBlock AST 만 존재, runtime dispatch 인프라 없음

## 캐노니컬 비교

| 언어 | 신택스 | 메모리 모델 | dispatch |
|---|---|---|---|
| Rust | `&dyn T` · `Box<dyn T>` | fat ptr (ptr + vtable) | runtime vtable |
| Swift | `any Protocol` (existential) | existential box | runtime |
| Java/Kotlin | `Interface` (참조 타입) | obj ref | invokevirtual |
| C# | `interface I` | obj ref | callvirt |
| Go | `interface { ... }` | iface struct (data + type) | runtime type-check |
| C++ | `virtual fn` | vtable in obj header | vtable |

→ Rust 모델 권장 — `&dyn T` fat pointer + vtable. Go 의 implicit interface 도 ergonomic 하지만 hexa 의 명시 `impl T for S` 와 어울리지 않음. lexer 가 이미 `dyn` keyword 를 알고 있어 Rust 친화적.

## 디자인 결정

### ABI

```c
typedef struct {
    void* data;         // 실제 struct ptr
    const Vtable* vt;   // 메서드 ptr 배열
} DynRef;

typedef struct {
    void* (*m0)(void*);
    void* (*m1)(void*);
    // ... trait 메서드 순서대로
} Vtable;
```

`DynRef` 가 `&dyn T` 의 런타임 표현. method call `s.m(args)` → `s.vt->m(s.data, args)`.

### 신택스

```hexa
fn say(s: &dyn Speaker) { ... }
let s: &dyn Speaker = &Dog{}
let v: [&dyn Speaker] = [&Dog{}, &Cat{}]
```

`&dyn T` 가 type position 에서 인식. parser 새 type 종류 (TypeDynRef).

### 옵션 비교

**옵션 A: 풀 Rust 모델**
- `&dyn T` fat ptr
- vtable codegen at trait impl time
- 장점: well-known, lexer 가 이미 `dyn` 알고 있음
- 단점: ownership 모델 없는 hexa 에서 `&` borrow 의미 모호 (GC ref 로 단순 reinterpret)

**옵션 B: Java/Kotlin 모델 (값 자체가 trait ref)**
- `s: T` (`T` 가 trait 이면 자동 dyn)
- 모든 trait 변수가 dyn dispatch
- 장점: 단순, ownership 무
- 단점: static dispatch 명시 어려움 (성능 손실 가능)

**옵션 C: Go 모델 (implicit)**
- 구조체가 trait 메서드 모두 구현하면 자동 trait 구현
- 장점: 매우 ergonomic
- 단점: trait 구현 의도 불명확, 함정 가능

→ **옵션 A 권장** (Rust canonical, hexa 명시 `impl` 정신과 어울림 · lexer 선행등록). 단, `&` 는 borrow semantic 보다 hexa GC 모델의 ref-by-default 으로 단순화.

## 영향 surface

| 파일 | 변경 |
|---|---|
| `self/lexer.hexa` | (이미 `dyn` keyword 등록됨, no-op) |
| `self/parser.hexa` | `&dyn TypeName` type parser (TypeDynRef AST node) |
| `self/codegen.hexa` | TraitImpl 시 vtable 생성 + DynRef 호출 |
| `self/runtime_core.c` | DynRef struct + dispatch helper |
| `self/type_checker.hexa` | dyn trait method 시그니처 verification |

## 구현 단계 (stacked PRs)

1. **GGGG-1**: parser `&dyn T` type (TypeDynRef AST) (~80줄, lexer 이미 토큰 있음)
2. **GGGG-2**: codegen vtable emit per trait impl (~150줄)
3. **GGGG-3**: codegen DynRef call lowering — `s.m()` → `s.vt->m(s.data)` (~80줄)
4. **GGGG-4**: stdlib `DynRef` runtime helper (~50줄)
5. **GGGG-5**: heterogeneous collection `[&dyn T]` (~100줄)

총 ~460줄, 5-PR stack — large multi-cycle feature.

## 우회책 (지금)

- enum sum type — 모든 variant 명시 (closed set):
  ```hexa
  enum Animal { Dog(Dog), Cat(Cat) }
  fn say(a: Animal) {
      match a {
          Dog(d) => print("woof")
          Cat(c) => print("meow")
      }
  }
  ```
- function pointer struct — explicit "vtable" by hand
- generic `fn say<T: Speaker>(s: T)` (monomorphization, static dispatch — open polymorphism 만 불가능)

## 관계 RFC / PR

- PR #348 `hexa_is_type` header fix (static dispatch base)
- r14-F enum codegen-emit (PR #489): TAG_ENUM 패턴 — DynRef 와 메모리 layout 유사 (tag = vtable ptr)
- r14-LL tuple (PR #506): heterogeneous fixed-size — `[&dyn T]` 는 heterogeneous unbounded variant
- r14-X postfix `?` (PR #494): trait method 가 Result 반환 시 결합
