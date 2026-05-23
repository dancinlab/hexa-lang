# RFC 082 — trait operator overload (canonical-audit round-7)

- **Status**: design-draft (decision input phase)
- **Date**: 2026-05-23
- **Severity**: HIGH (type-system gap · silent-wrong builtin fallback)
- **Source**: HEXA-LANG.md "Deferred RFC 사이클" 후보 2 · canonical-audit round-7
- **Range**: 타입시스템 (Rust trait dispatch · Swift protocol · 연산자 ↔ 메서드)
- **Implements**: 본 RFC는 design ONLY — 구현 RFC 별도 (`rfc_082_impl_*`)
- **Blocker for**: [[rfc_081_option_result_lane]] D4 (boxed error needs `dyn Error` trait)

## 1. Motivation

canonical-audit round-7에서 design-level gap:

| 현상 | 결과 |
|---|---|
| `struct + struct` | silent-wrong builtin int add (이상한 주소 산술) 또는 type error |
| `struct == struct` | reference identity (pointer-eq) — field-wise eq 불가 |
| `struct < struct` | undefined — sort/min/max 불가 |
| user-defined numeric type (Decimal, Matrix, Quaternion) | 모든 연산을 method 호출로만 — `m1.add(m2).mul(m3)` ugly |

trait system 도입은 단순 operator overload 를 넘어 **dispatch 모델 자체**를 결정하는 대형 작업. 본 RFC는 trait 의 surface + dispatch 의 결정점만 정리하고, 구현은 별도 사이클.

## 2. Scope (in / out)

**In v1 (이 RFC):**

- `trait` 선언 surface + impl 문법
- 연산자 → method dispatch 룰 (`+` → `Add::add`, `==` → `PartialEq::eq`, ...)
- 핵심 stdlib trait — `Add`, `Sub`, `Mul`, `Div`, `Neg`, `PartialEq`, `Eq`, `PartialOrd`, `Ord`, `Hash`, `Display`, `Debug`
- coherence rule (orphan rule) 결정
- dispatch model (static / dynamic / both) 결정
- 자동 derive 매크로 `@derive(Eq, Ord)` 같은 sugar

**Out (follow-up RFC):**

- `Iterator` trait family (collection 전반)
- `Try` trait (Option/Result 일반화)
- async trait / associated type 일반화
- HKT (higher-kinded types)
- trait object (`dyn Trait`) lifetime 관리 — RFC 082 v1은 static dispatch만 결정하면 follow-up
- specialization (Rust nightly)

## 3. Surface options (decision matrix)

### D1. dispatch model — static · dynamic · both

| option | 메커니즘 | tradeoff |
|---|---|---|
| **A. Static only (monomorphization)** | `fn foo<T: Add>(...)` → 각 `T`마다 별도 함수 생성 | binary 비대화 · 컴파일 시간↑ · runtime 비용 0 · 단순 |
| B. Dynamic only (vtable, like Java/Swift protocol) | 모든 trait 호출이 vtable indirection | binary 작음 · runtime 비용 (1 indirect call) · generics 불필요 |
| C. Both (Rust pattern) — `impl Trait` static + `dyn Trait` dynamic | 사용자가 선택 | surface 2개 · 학습 비용↑ · 가장 표현력 |

**🟢 Decided 2026-05-23: A — Static only (monomorphization) v1, C는 follow-up.** 권고 채택. v1은 generics + trait bound dispatch만 — `dyn Trait` (vtable) 은 RFC 082-follow 분기. 이유:
- hexa-lang은 self-host native compiler — binary 크기는 ubu/Mac 두 host에서 이미 큰 편이지만, monomorphization 비용은 corpus 규모 (현재 ~70k LOC) 에서 감내 가능
- vtable lowering은 `Option<T>` 구현의 dyn-error 박싱과 entangled → RFC 081 D4 의존 사이클 발생
- static-first로 surface 안정화 후 `dyn Trait`은 RFC 082-follow에서 추가

### D2. coherence rule — orphan rule

trait `T`와 type `S` 에 대해 `impl T for S` 가 어디서 정의될 수 있나?

| option | 룰 | 결과 |
|---|---|---|
| **A. Rust strict orphan** — `T` 또는 `S` 둘 중 하나가 정의된 crate(module)에서만 impl 가능 | 안전 · downstream user가 임의 impl 못함 (`impl Display for Vec<i32>` 불가) | 명확한 boundary · 일부 ergonomics 손해 |
| B. Swift extension model — 어디서든 extension 가능 (단, 충돌 시 link error) | 자유 · 충돌 가능 | implicit 동작 · 디버깅 어려움 |
| C. coherence 없음 (impl 자유, 충돌은 last-wins) | C++ style | unsafe · 가장 자유 |

**🔵 Decision needed.** 권고: **A**. atlas-bound · strict-lint 8 stage 철학과 일관. self-host corpus는 단일 module group 이라 orphan rule 영향 미미.

### D3. v1 operator scope — 어떤 operator를 trait dispatch 하나

| group | operator | trait | v1 포함? |
|---|---|---|---|
| arithmetic | `+`, `-`, `*`, `/`, `%`, unary `-` | `Add`, `Sub`, `Mul`, `Div`, `Rem`, `Neg` | **YES** |
| equality | `==`, `!=` | `PartialEq` / `Eq` | **YES** |
| ordering | `<`, `<=`, `>`, `>=` | `PartialOrd` / `Ord` | **YES** |
| bitwise | `&`, `\|`, `^`, `<<`, `>>`, `!` | `BitAnd`, `BitOr`, ... | YES (Rust 패턴 일관) |
| indexing | `a[i]` | `Index` / `IndexMut` | **🔵 결정** |
| function call | `f(x)` | `Fn` / `FnMut` / `FnOnce` | NO (closures = HKT-인접) |
| dereference | `*p` | `Deref` | NO (ownership system 부재로 의미 모호) |
| arithmetic assign | `+=`, `-=`, ... | `AddAssign`, ... | 권고 YES (binary op 와 동시 도입) |

**🔵 Decision needed.** D3a — `Index`/`IndexMut` 포함? 권고: **NO v1** (custom array/map type 등장 시 add). D3b — `*Assign` variant 포함? 권고: **YES**.

### D4. derive sugar — `@derive(Eq, Ord, Hash)`

| option | 형태 | 효과 |
|---|---|---|
| **A. attribute `@derive(Trait1, Trait2)` on struct** | Rust 패턴 · 컴파일러가 trivial impl 자동 생성 | ergonomics ↑ · macro-like expansion |
| B. 키워드 `derives Eq, Ord` after struct body | Swift `protocol conformance` 류 | 문법 자연스러움 · 다른 attribute 와 다른 surface |
| C. derive 없음 — 명시 `impl Eq for S { ... }` 만 | 단순 · ceremony 비용 |

**🔵 Decision needed.** 권고: **A**. self-host corpus의 enum/struct 다수 `Eq`/`Hash` 필요 — manual impl ceremony 비현실적.

### D5. associated type / generic bound 문법

| option | 문법 | 비교 |
|---|---|---|
| **A. Rust `where` clause** — `fn f<T>() where T: Add<Output = T>` | 자세함 · 강력 · 구현 복잡 |
| B. Inline `<T: Add<Output = T>>` only | 간결 · `where`보다 표현력 낮음 |
| C. A + B 둘 다 | Rust 패턴 |

**🔵 Decision needed.** 권고: **C** (둘 다) — Rust 사용자 친화. parser 비용은 적음.

### D6. trait inheritance — `trait Ord: PartialOrd + Eq`

| option | 결과 |
|---|---|
| **A. Supertrait 지원 (Rust)** | trait hierarchy 명확 · `Ord` impl 시 `PartialOrd` 자동 보장 요구 |
| B. 평탄 (no inheritance) — 각 trait 독립 | 단순 · 중복 impl 부담 |

**🔵 Decision needed.** 권고: **A** — `Eq: PartialEq` · `Ord: PartialOrd + Eq` 표준 형태 따라감.

### D7. trait 자체의 lowering — vtable layout · symbol naming

| option | 형태 |
|---|---|
| **A. C++ Itanium-style vtable + mangling** | 표준 · `c++filt` 같은 도구 호환 |
| B. Rust-style monomorphized function pointers | static only 이면 vtable 불필요 |
| C. hexa-native ad-hoc naming (`_hexa_trait_<trait>_<type>_<method>`) | 자체 mangle · debug 친화 |

**🔵 Decision needed.** D1=A (static only) 채택 시 — vtable 자체가 v1에 없으므로 **D7 deferred** (RFC 082-follow에서 결정).

## 4. Falsifier

- **F-082-1**: `struct Point { x: int, y: int }` + `impl Add for Point` 후 `p1 + p2` 는 method 호출로 lower → 결과 `Point { x: p1.x+p2.x, y: p1.y+p2.y }`
- **F-082-2**: `@derive(Eq)` 적용 struct 의 `==` 는 field-wise eq (pointer-eq 아님)
- **F-082-3**: `impl Display for ExternType` (둘 다 외부) 는 type error (orphan rule)
- **F-082-4**: `fn min<T: Ord>(a: T, b: T) -> T` generic 정의 가능 · 각 instantiation 별 monomorphized 코드 생성
- **F-082-5**: existing self-host corpus byte-eq — `hexa build self/main.hexa` gen1.s ≡ gen2.s 유지 (struct에 implicit `Eq` impl 가 silently 추가되지 않음)
- **F-082-6**: trait method 호출이 zero-cost (static dispatch — abstraction 없는 manual call 과 동일 instruction sequence)

## 5. Decision input — 정리표

| ID | 결정 항목 | 권고 |
|---|---|---|
| D1 | dispatch model | **A** (static only v1, dyn은 follow-up) |
| D2 | coherence (orphan rule) | **A** (Rust strict) |
| D3 | v1 operator scope | arithmetic + eq + ord + bitwise + `*Assign` · D3a Index NO · D3b `*Assign` YES |
| D4 | derive sugar | **A** (`@derive(Trait, ...)`) |
| D5 | generic bound 문법 | **C** (both — `<T: Bound>` + `where` clause) |
| D6 | trait inheritance | **A** (supertrait 지원) |
| D7 | trait vtable lowering | **deferred** (D1=A이므로 v1에 vtable 없음) |

## 6. Phase plan (implementation — 별도 RFC)

이 RFC 는 design ONLY. D1-D6 확정 후 별도:

- **rfc_082_impl_a** — `trait` / `impl` surface + parser
- **rfc_082_impl_b** — coherence checker (orphan rule)
- **rfc_082_impl_c** — operator desugar (`a + b` → `Add::add(a, b)`)
- **rfc_082_impl_d** — monomorphization pass (D1=A 채택 시)
- **rfc_082_impl_e** — `@derive` sugar
- **rfc_082_impl_f** — stdlib core trait 정의 (Add/Sub/.../Eq/Ord/Hash/Display/Debug)
- **rfc_082_impl_g** — corpus migration (struct `==` 의 silent pointer-eq → field-wise) — `_opt_in_pointer_eq` 잔재 검사 필요

## 7. Non-scope (follow-up RFC)

- `dyn Trait` (dynamic dispatch) — RFC 082-follow
- `Iterator` trait family — collection RFC
- `Try` trait (Option/Result 일반화) — RFC 081 사후
- HKT, associated type 일반화, GAT, specialization
- async trait

## 8. Interaction with other RFCs

- **RFC 081 (Option/Result)**: D4 "boxed error" 변종은 본 RFC 의 `dyn Error` trait 객체 필요 → 본 RFC v1 (static only) 에서는 미제공, follow-up
- **RFC 074 (enum multi-field payload)**: trait impl 안의 enum match 패턴이 multi-field payload 동작 가정
- **RFC 062 (argv0 dedup / args contract)**: 무관
- self-host fixpoint ([[project_compiler_native_self_host_fixpoint]]) — trait impl 도입이 gen1.s ≡ gen2.s 깨면 안 됨 (F-082-5)

## 9. References

- HEXA-LANG.md §"RFC 후보 2"
- canonical-audit round-7 log
- Rust `std::ops::*` traits · Rust RFC 0195 (associated items) · RFC 0387 (specialization)
- Swift `AdditiveArithmetic` / `Comparable` / `Hashable` protocol family
- C++ concepts (Concepts TS) — non-canonical 참고
- [[rfc_081_option_result_lane]] D4 boxed error 의존
- [[rfc_074_enum_multi_field_payload]] — payload lowering 정합
