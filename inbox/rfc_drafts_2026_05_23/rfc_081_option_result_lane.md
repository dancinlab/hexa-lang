# RFC 081 — Option / Result lane (canonical-audit round-3)

- **Status**: design-draft (decision input phase)
- **Date**: 2026-05-23
- **Severity**: HIGH (type-system gap · 광범위 마이그레이션 동반)
- **Source**: HEXA-LANG.md "Deferred RFC 사이클" 후보 1 · canonical-audit round-3
- **Range**: 타입시스템 (Rust `Option<T>` / `Result<T, E>` · Swift `Optional<T>` 패밀리)
- **Implements**: 본 RFC는 design ONLY — 구현은 별도 사이클 (`rfc_081_impl_*` 시리즈)

## 1. Motivation

canonical-audit round-3에서 design-level gap 3가지가 surfaced:

| 현상 | 위치 | 결과 |
|---|---|---|
| `nil` ident 무성-coerce | parser + type_checker | `let x: int = nil` 같은 nonsense가 silently 통과 |
| `[].pop()` 무성-void | stdlib/collections | empty array에 pop 호출 → 0/null/sentinel — caller가 fail-signal을 구분 못 함 |
| error 채널 부재 | 전체 stdlib | I/O · parse · network 등에서 (성공값, error) 채널 분리 불가 — exception도 없음 |

세 현상의 공통 root cause: **fallible value를 표현하는 표준 lane이 없다.** Rust `Option`/`Result` + `?` operator, Swift `Optional` + `try?` 패밀리가 canonical solution.

## 2. Scope (in / out)

**In v1 (이 RFC):**

- 핵심 enum 2종 — `Option<T>` { Some(T), None }, `Result<T, E>` { Ok(T), Err(E) }
- `?` propagation operator (또는 동등 surface)
- 표준 lowering — typechecker (`?`-desugar) · codegen (enum tag + payload)
- stdlib 핵심 helper — `.is_some()`, `.is_none()`, `.unwrap()`, `.unwrap_or(default)`, `.map(f)`, `.and_then(f)`, `Result` 동등
- pop / get / find / parse 등 **return 채널 일괄 migration** — `[T].pop() -> Option<T>` 등

**Out (follow-up RFC):**

- `Try` trait 일반화 (Rust `std::ops::Try`)
- `anyhow`/`thiserror` 스타일 dyn-error 박싱 — RFC 082 (trait) 이후
- async result chaining (`futures::TryFutureExt`)
- panic-vs-return 정책 통합 (`runtime_panic` 경로와의 관계)

## 3. Surface options (decision matrix)

### D1. 명명 — Rust `Option` vs Swift `Optional`

| option | pros | cons |
|---|---|---|
| **A. Rust `Option<T>` + `Result<T, E>`** | 두 lane 대칭 · Result도 동시 도입 · 코드베이스 Rust 친숙 | `Option`은 nominal enum (sugar 별도) |
| B. Swift `Optional<T>` + `T?` sugar | type-level postfix `?` sugar 자연스러움 · `if let`/`guard` 친숙 | Result-equivalent (`Result<Success, Failure>`) 따로 — 2개 lane 시점 분리 |
| C. 하이브리드 — Rust enum + `T?` postfix sugar 동시 | 두 ergonomics 모두 가져옴 | parser surface 2배 · 명세 분기 |

**🟢 Decided 2026-05-23: A — Rust `Option<T>` + `Result<T, E>`.** 권고 채택. 코드베이스 Rust friendly · canonical ref 단순 · 두 lane 대칭. impl 사이클은 enum surface 확장 → typechecker → stdlib helpers 순서.

### D2. propagation operator — Rust `?` vs Swift `try?` vs 명시 match

| option | 예시 | 의미 |
|---|---|---|
| **A. Rust `?` postfix** | `let x = parse_int(s)?` | `Err`/`None` 즉시 caller로 return, 함수 sig는 `-> Result<...>` 여야 함 |
| B. Swift `try?` prefix | `let x = try? parse_int(s)` | `Err`/`None` 시 expr가 `Option<T>` → `nil`로 evaluate (return 안 함) |
| C. 둘 다 (Rust `?` + Swift `try`) | both | parser 복잡 · 두 semantic 공존 |

**🔵 Decision needed.** 권고: **A**. trait dispatch (RFC 082)와 결합 시 `Try` trait 일반화 경로가 가장 짧음. Swift `try?`는 follow-up.

### D3. `nil` keyword 운명

현재 `nil`은 hexa parser에 reserved word이지만 type-level 의미가 모호 (any type으로 coerce).

| option | 결과 |
|---|---|
| **A. silent-erase (deprecate)** | `nil` keyword 제거 · `None` / `Option::None` 으로 대체 · migration script 동반 |
| B. `None`의 alias로 hard-pin | `nil: Option<T>` 만 허용 · 다른 type으로 coerce 시 type error |
| C. raw nullable pointer로 분리 | `nil`은 C-FFI raw pointer 전용 · hexa-side는 `None` |

**🔵 Decision needed.** 권고: **A**. memory [[feedback_raw_own_no_mention]] 패턴 — silent-erase가 hexa-lang convention. `nil` 잔재 (예: `nil`-check 패턴) corpus-wide grep + 일괄 변환.

### D4. error type generic vs boxed

| option | 형태 | tradeoff |
|---|---|---|
| **A. fully generic `Result<T, E>`** | caller가 매번 `E` 명시 | Rust pattern · stdlib 전체에 `E` 노출 · ergonomics 비용 |
| B. `Result<T>` + `anyhow::Error` 류 boxed default | `Result<T> = Result<T, BoxError>` alias | sugar로 간편 · 성능 박싱 비용 · RFC 082 trait 의존 |
| C. A + B 둘 다 (alias로 B 제공) | both | 두 surface 학습 비용 |

**🔵 Decision needed.** 권고: **A** v1 · **B**는 RFC 082 (trait) 랜딩 후 alias로 추가. 박싱은 dyn trait 필요 → trait 선행.

### D5. `Option<T>` runtime representation

| option | 형태 | tradeoff |
|---|---|---|
| **A. tagged enum (i64 tag + union payload)** | 모든 `T`에 일관 | pointer-sized `T`에도 8B tag overhead |
| B. null-pointer optimization (NPO) — pointer-sized `T`는 `0`을 `None`으로 | Rust 패턴 | codegen 분기 · `T = i64` 같이 `0`이 valid value인 경우 제외 |
| C. opaque builtin (compiler intrinsic) | 컴파일러가 모든 거 결정 | 사용자 정의 enum과 inconsistent |

**🔵 Decision needed.** 권고: **A** v1, NPO는 perf RFC follow-up. RFC 074 enum-multi-field-payload 와의 lowering 호환 우선.

## 4. Migration scope (corpus impact)

`pop` / `get` / `find` / `parse` / `read` 류의 reun 채널 변경 = **광범위 영향**.

| API | current | proposed | call sites (rough) |
|---|---|---|---|
| `[T].pop()` | returns `T` (empty → 0/null) | `-> Option<T>` | ~200+ |
| `Map[K, V].get(k)` | returns `V` (missing → default) | `-> Option<V>` | ~150+ |
| `string.find(sub)` | returns `int` (-1 sentinel) | `-> Option<int>` | ~80+ |
| `int.parse(s)` | returns `int` (fail → 0) | `-> Result<int, ParseError>` | ~50+ |
| file/IO ops | sentinel/exit | `-> Result<T, IoError>` | ~30+ |

마이그레이션 전략 **D6**:

| option | 방식 |
|---|---|
| **A. 일괄 hard-cut (한 PR로 stdlib 전부 마이그레이션)** | 깔끔 · 큰 PR · g4 stacked PR <200줄 위반 |
| B. dual-API tier — `pop_or(default)` / `pop_opt()` 병존, 점진 deprecate | g4 호환 · 두 surface 일시 공존 |
| C. opt-in by file pragma `@option_lane(strict)` | 점진 · 명시적 · pragma surface 비용 |

**🔵 Decision needed.** 권고: **B** — `_opt` suffix variant 우선 도입, 기존 API는 stage-2에서 deprecate → stage-3에서 제거. g4 stacked PR <200줄 호환.

## 5. Falsifier

- **F-081-1**: `[].pop()` 호출 시 `None` 반환 — empty array에서 silently 0/default 사라짐
- **F-081-2**: `Map[K, V].get(missing_key)` 가 `None` 반환 — sentinel 제거
- **F-081-3**: `parse_int("foo")` 가 `Err(ParseError)` 반환
- **F-081-4**: 함수 sig `-> Result<T, E>` 안에서 `expr?` 가 `Err` 발생 시 immediate return 동작
- **F-081-5**: `let x: int = nil` 같은 형변환은 type error
- **F-081-6**: existing self-host corpus byte-eq — `hexa build self/main.hexa` gen1.s ≡ gen2.s 유지 (migration이 self-host fixpoint 깨지 않음)

## 6. Decision input — 정리표

| ID | 결정 항목 | 권고 |
|---|---|---|
| D1 | Option/Result naming | **A** (Rust naming) |
| D2 | propagation operator | **A** (Rust `?`) |
| D3 | `nil` keyword | **A** (silent-erase) |
| D4 | error type generic vs boxed | **A v1**, B는 RFC 082 후 alias |
| D5 | runtime repr | **A** (tagged enum), NPO follow-up |
| D6 | migration | **B** (`_opt` 변종 → 점진 deprecate, g4 호환) |

> 본 RFC는 6개 결정 후 implementation RFC 분리. 사용자가 D1-D6 중 변경 항목만 지시하면 권고 default로 진행.

## 7. Phase plan (implementation 사이클 — 별도 RFC)

이 RFC는 design ONLY. 구현은 D1-D6 확정 후 별도 RFC로 분기:

- **rfc_081_impl_a** — `Option`/`Result` enum 선언 + codegen + 기본 helper (D5 lowering)
- **rfc_081_impl_b** — `?` operator desugar (D2)
- **rfc_081_impl_c** — `nil` deprecate + corpus migration (D3)
- **rfc_081_impl_d** — stdlib `_opt` variant landing (D6 stage-1)
- **rfc_081_impl_e** — 기존 API deprecate + 제거 (D6 stage-2, 3)

## 8. Non-scope

- `Try` trait 일반화 (RFC 082 후)
- async/await result chaining
- panic 통합 — runtime_panic ↔ `unwrap()` 정책은 별도
- `Cow<T>` 같은 borrow-friendly variant (RFC 082 trait 후)

## 9. References

- HEXA-LANG.md §"RFC 후보 1"
- canonical-audit round-3 log
- Rust `std::option` / `std::result` / RFC 0243 (`?` operator)
- Swift Optional / Result documentation
- [[rfc_082_trait_operator_overload]] — D4 boxed error variant 의 trait 의존
- [[rfc_074_enum_multi_field_payload]] — Result 의 `Err(E)` payload lowering 호환
- [[project_hexa_lang_english_only]] — diagnostics 영어 단일 (이 RFC 결정 후 변경 diagnostic 도 영어)
