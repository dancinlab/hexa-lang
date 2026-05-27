# smart pointer `Box`/`Rc`/`Arc` stub design RFC

**Status**: design-level (r14 cycle 10, 2026-05-24)
**Priority**: P4 (hexa GC 라 대부분 no-op — 마이그레이션 친화 신택스 결정만)
**SSOT**: 본 RFC · Rust Reference Box/Rc/Arc · hexa GC 모델

## 현재 동작 (probe 검증)

probe 1 — `/tmp/probe_smart_ptr_r14.hexa` (type annotation 포함):
```hexa
fn main() {
    let b: Box[int] = Box::new(42)
    ...
}
```
→ `hexa parse`: **6 parse error**
- `2:15 expected Eq, got LBracket ('[')` — `Box[int]` type annotation 파싱 실패
- `2:21 unexpected token Eq ('=')` — 후속 cascade

probe 2 — `/tmp/probe_smart_ptr2.hexa` (annotation 없이 `let b = Box::new(42)`):
- `hexa parse`: **OK** — 식별자/`::`/호출 모두 통과
- `hexa build`: **clang error** `call to undeclared function 'Box__new'` + `incompatible type 'int' for HexaVal` — codegen 이 `Box::new` 를 일반 외부 함수로 emit, 선언/구현 없음

probe 3 — `Rc::new(42)` / `Arc::new(42)` (bare):
- parse OK, codegen 같은 undeclared-symbol 경로 (검증 생략, 동일 패턴)

| 표현 | hexa 동작 |
|---|---|
| `Box::new(42)` (bare) | parse OK, codegen `Box__new` undeclared → clang link 실패 |
| `Rc::new(42)` | parse OK, 동일 |
| `Arc::new(42)` | parse OK, 동일 |
| `Box[int]` type annotation | **parse error** — `[` 가 type 위치에서 인식 안 됨 |

grep self/parser.hexa, self/codegen.hexa, stdlib/*.hexa — `Box`/`Rc`/`Arc` 식별자 정의 없음 (codegen 5877 라인 `Box-Muller` 코멘트 무관, dynlink_caps 52 라인 `nanbox` 부분일치). stdlib 미존재 확정.

## 캐노니컬 비교

| 언어 | Box | Rc/Arc | 메모리 모델 |
|---|---|---|---|
| Rust | heap alloc, owned | ref count single/atomic | borrow checked, no GC |
| Swift | (자동, opaque) | (자동) | ARC (compile-time) |
| Kotlin/Java/Go/C# | (자동) | (자동) | GC |
| C++ | `unique_ptr<T>` | `shared_ptr<T>` | manual + RAII |

→ GC 언어 그룹은 Box/Rc/Arc 가 사용자 가시 신택스 없음. hexa 는 GC + simple-tracing 모델이므로 GC 그룹에 속함.

## 디자인 결정 (3 옵션)

### 옵션 A: 완전 거부 (lifetime r14-HHHH 와 동일 정책)
- `Box::new(x)` → parse OK 가능하지만 stdlib 없으므로 undeclared link error
- `Box[T]` type → parse error (현 상태 유지)
- 사용자가 Rust 코드 copy-paste 시 명확 진단
- 장점: GC 정신 일관 + zero surface 비용
- 단점: Rust 친화 사용자 약간 불편

### 옵션 B: stdlib stub (identity wrapper)
- `Box[T] = T` (alias)
- `Box::new(x)` → identity 반환
- `Rc::new(x)` → identity
- `Arc::new(x)` → identity
- 사용자가 Rust 코드 copy-paste 가능
- 장점: migration friendly
- 단점: 거짓 안전감, code size 증가, `Box[T]` type-syntax 위해 parser 도 손대야 함

### 옵션 C: hexa-native opt-in heap-hint
- `Box[T]` = hint to runtime "allocate this in tenured GC region" (perf hint, semantic 동일)
- `Rc/Arc` 거부 (GC 가 처리)
- 장점: 명시적 + perf 잠재 이득
- 단점: hexa GC tuning 의존 — 현재 simple GC 라 hint 효과 미정 + 구현 비용 큼

→ **옵션 B 권장** (stdlib stub, identity wrapper) — Rust migration friendly + zero runtime impact + 단순. 단 `Box[T]` type syntax 는 parser 작업 1단 추가.

## 구현 단계 (stacked PRs)

1. **IIII-1**: `stdlib/smart_ptr.hexa` Box[T]/Rc[T]/Arc[T] 타입 alias + ::new identity (~30줄)
2. **IIII-2**: parser `Box[T]`/`Rc[T]`/`Arc[T]` type generic 위치 인식 (현재 parser 가 `[` type bracket 거부 — 일반 generic 작동 시 별도 케이스 불필요, ~20줄)
3. **IIII-3**: docs / migration 가이드 (~40줄)

총 ~90줄, 3-PR stack — 매우 작음.

## 영향 surface

| 파일 | 변경 |
|---|---|
| `stdlib/smart_ptr.hexa` (new) | Box/Rc/Arc identity wrapper + `::new` |
| `self/parser.hexa` | generic type bracket `T[U]` (probe 1 확인 — 현재 미작동) |
| `inbox/notes/migration-from-rust.md` (옵션) | Rust → hexa 매핑 표 |

## 의미 결정 (sticky)

- `Box::new(x)` mutation: Rust 의 `*b = new_val` 매핑?
  - 권장: `Box::new` 가 그냥 mutable ref (hexa 의 일반 변수) → mutation 명시적 `b = new_val`
- `Rc::clone(&r)` — Rust 의 explicit clone, hexa 는 identity 라 무의미 → `r.clone()` 도 identity 반환
- 다중 owner: hexa GC 처리 → `Rc::strong_count(&r)` 같은 introspection API 는 무의미 → unsupported (compile error)
- `Box<dyn Trait>`: r14-GGGG dyn dispatch RFC 에서 별도 처리 (smart_ptr stub 은 nested generic 만 통과)

## 우회책 (지금)

- 그냥 변수: `let x = 42` (hexa 가 자동 alloc, GC 처리)
- 명시 fn alloc: `fn alloc_heap(x: T) -> T { x }` (no-op helper)
- Rust 포팅 시 `Box::new(x)` / `Rc::new(x)` 모두 단순 `x` 로 변환

## 관계 RFC / PR

- r14-HHHH lifetime (sister): GC 라 lifetime 무필요 — Box/Rc/Arc 도 같은 캠프
- r14-GGGG trait dyn dispatch (sister): `Box<dyn T>` 패턴 — dyn RFC 에서 별도 처리
- r14-KK Option prelude (PR #505): `Box<Option<T>>` 같은 nested 단순화
- r14-YYY struct field defaults (PR #526): 옵션 B 채택 시 `Box[T]` alias 도 default 인자 가능

## 결론

옵션 **B 권장** but **A 도 합리** (GC 일관성 우선 시). 사용자 결정 대기:
- A (거부): 작업 0, surface 0
- B (stub): ~90줄, 3-PR, Rust copy-paste 친화
- C (heap-hint): ~300줄+, GC tuning 의존 — 비권장
