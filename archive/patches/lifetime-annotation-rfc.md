# lifetime `'a` annotation design RFC

**Status**: design-level (PROBE r14 cycle 10, 2026-05-24)
**Priority**: P3 (hexa 는 GC 라 lifetime 의 memory-safety 역할 NONE — 신택스 채택 여부만 결정)
**SSOT**: 본 RFC · Rust Reference Lifetimes · hexa GC 모델

## 현재 동작 (probe 검증, hexa parse)

`/tmp/probe_lifetime_r14.hexa`:

```hexa
fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {
    if x.len() > y.len() { x } else { y }
}

struct Holder<'a> { data: &'a str }

fn main() {
    let s1 = "hello"
    let s2 = "world!"
    let r = longest(s1, s2)
    print(r)
}
```

| 표현 | hexa lex | hexa parse |
|---|---|---|
| `'a` (single-ident) | Label 토큰 (loop label 신택스 재사용) | `Parse error at 1:12: expected identifier, got Label ('a')` |
| `&'a str` | `BitAnd Label Ident` | `expected identifier, got BitAnd ('&')` 후 cascading errors |
| `'static` | Label 토큰 (`static` 7글자) | `expected ':' after label 'static'` (loop label로 오인) |
| `'a: 'b` (outlives) | Label Colon Label | `expected for/while/loop after label 'a'` |
| struct `<'a>` | Label in generic param | `expected identifier, got Label ('a')` |
| `'a'` (char lit) | CharLit 토큰 (`'`+ident+`'` disambig) | OK — 기존 작동 |

→ **현재 `'a` lifetime 신택스는 lexer 차원에서 Label(loop label)과 충돌**. parser 에러 cascade 발생.

## 캐노니컬

| 언어 | 신택스 | 역할 | 메모리 모델 |
|---|---|---|---|
| Rust | `'a` ticked generic | borrow checking, drop ordering | ownership |
| Swift | (없음) | ARC 자동 | ARC |
| Kotlin | (없음) | GC | GC |
| Java | (없음) | GC | GC |
| Go | (없음) | GC | GC |
| C# | (없음) | GC | GC |
| Scala | (없음) | GC | GC |
| OCaml | (없음) | GC | GC |
| Python | (없음) | GC | refcount+GC |

→ GC 언어 (Swift/Kotlin/Java/Go/C#/Scala/OCaml/Python) 는 lifetime 신택스 없음. hexa 는 GC 라 동일 캠프. **canonical = 거부**.

## 디자인 결정

### 옵션 A: 완전 거부 + 명확한 진단 (권장)

- `'a` 신택스 — 현재 Label 토큰 충돌 그대로 두고 parser 에서 type-position 에 Label 등장 시 전용 진단
- 사용자가 Rust 코드 copy-paste 하면 명확한 "lifetime not needed in hexa (GC)" 진단 + suggestion
- 장점: 단순 · GC 정신 일관 · g1(canonical-first) 일치 (GC 진영 전체와 align)
- 단점: Rust 친화 사용자 약간 불편 (수동 strip 필요)

### 옵션 B: Parse OK + ignore (Swift-style migration friendly)

- `'a` 인식, AST 에 저장, type-checker/codegen 에서 무시
- 사용자가 Rust 코드 그대로 copy-paste 가능
- 장점: migration friendly
- 단점: **거짓 안전감** — borrow checker 없는데 신택스만 있으면 사용자가 lifetime 보장된다고 오해 · 신택스 noise · spec drift 위험

### 옵션 C: 일부 채택 (`'static` 만)

- `'static` 만 인식 (compile-time constant 의미)
- `'a` 같은 ad-hoc 은 거부
- 장점: 일부 명시성
- 단점: 부분 채택 함정 · `'static` 의 의미를 따로 정의해야 함 (hexa GC 모델에 없는 개념)

→ **옵션 A 권장** (완전 거부 + 명확한 진단)

## 진단 메시지 (제안)

```
error: lifetime annotation 'a not allowed in hexa
  --> file.hexa:1:12
   |
1  | fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {
   |            ^^ hexa is GC-based; lifetimes are inferred and managed automatically
   |
   = help: remove the lifetime annotation
   = help: rewrite as: fn longest(x: str, y: str) -> str
   = note: hexa references have GC-managed lifetimes by default
```

## Disambiguation: `'a` vs char literal `'a'` vs Label `'outer`

현 lexer (self/lexer.hexa:495-554) 동작:

1. `'` 다음 ident-char 가 오고 더 긴 ident 면 → **Label** (e.g. `'outer`, `'a` 1글자도 closing `'` 없으면 Label)
2. `'` + 1글자 + `'` (closing) → **CharLit**
3. → 즉 hexa 는 이미 `'a` (no closing) 를 **Label** (loop label) 로 lex 함

핵심 통찰: **lexer 변경 NEED 없음**. Label 토큰은 이미 존재 (loop label), parser 단의 type-position 에서 Label 출현 시 lifetime 진단으로 라우팅.

## 구현 단계 (stacked PRs)

| PR | 범위 | 줄수 |
|---|---|---|
| HHHH-1 | parser type-position 에서 Label 토큰 진단 ("lifetime not needed") | ~40 |
| HHHH-2 | parser generic-param `<'a>` 진단 + struct/fn 모두 | ~30 |
| HHHH-3 | docs — Rust user 마이그레이션 가이드 (단순 strip) | ~30 |

총 ~100 줄, 3-PR stack.

## 영향 surface

| 파일 | 변경 |
|---|---|
| `self/lexer.hexa` | **변경 없음** (Label 토큰 이미 존재) |
| `self/parser.hexa` | type-position + generic-param 에서 Label → 전용 진단 |
| docs / 마이그레이션 가이드 | "lifetimes are not used in hexa" 한 줄 |

## 우회책 (지금)

- lifetime annotation 안 씀 (hexa GC default)
- Rust 코드 마이그레이션 시 `'a` / `'static` / `'a: 'b` 모두 strip
- 참조 타입 `&'a T` → 그냥 `T` (GC reference)

## 관계 RFC / PR

- r14-GGGG trait dyn dispatch: `dyn` 의 `&` borrow 도 GC 라 의미 단순화
- r14-LL tuple type (PR #506): tuple type signature 안 lifetime 가능성 — 이 RFC 의 옵션 A 따르면 NONE
- Label 토큰 (loop label `'outer`): 동일 lex 패턴 공유, 이미 작동 중
