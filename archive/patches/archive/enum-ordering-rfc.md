# enum `<`/`>` ordering design RFC

**Status**: rfc-draft-deferred-2026-05-25 — design-only patch (not a fix). PR #617 (probe-r14-tttt enum ordering by decl) implements runtime ordering separately; this RFC = full ordering spec.
**Status**: design-level (PROBE round 3 INBOX line 72, r14 cycle 13, 2026-05-24)
**Priority**: P3 (편의 — enum 을 priority/severity 로 쓸 때 ordering 필요)
**SSOT**: PROBE.log.md round 3 enum entry · r14-F enum codegen-emit (#489)

## 현재 동작 (probe 검증, compiled path)

| 표현 | hexa 동작 |
|---|---|
| `Priority::Low == Priority::Low` | ✅ `true` (r3 canonical) |
| `Priority::Low < Priority::High` | ✅ `true` (tag `0 < 2`) |
| `Priority::High > Priority::Medium` | ✅ `true` (tag `2 > 1`) |
| `Priority::High < Priority::Low` | ✅ `false` (tag `2 < 0`) — 진짜 tag 비교 |
| `Priority::Low < Priority::Low` | ✅ `false` (동일 tag) |
| `[High, Low, Medium].sort()` | ✅ `[0, 1, 2]` — tag-order 정렬 (단 print 는 tag int 노출, r3 to_string INBOX) |
| `Color::Red < Priority::Medium` | ⚠ `true` — cross-enum-type 비교 silent 통과 (type error 없음) |

→ **옵션 A (default tag-order) 가 이미 작동**. enum 이 `hexa_int(tag)` 으로 lower (r14-F finding) 되므로 `<`/`>`/`sort()` 모두 int 비교로 우연-정확하게 동작. 단 (1) cross-type 비교 무검사, (2) payload variant lexicographic 미정의 2개 gap 잔존.

## 캐노니컬

| 언어 | enum ordering | 기본값 |
|---|---|---|
| Rust | `#[derive(PartialOrd, Ord)]` → 선언 순서 | opt-in (derive 필요) |
| Swift | `Comparable` 준수 → 선언 순서 | opt-in |
| Python | `Enum` 순서 없음 · `IntEnum`/`IntFlag` 만 ordered | 기본 unordered |
| Java | `Enum.compareTo` → ordinal (선언 순서) | 기본 ordered |
| Kotlin | `Enum.compareTo` → ordinal | 기본 ordered |

→ 두 진영: opt-in (Rust/Swift) vs default-ordered (Java/Kotlin). hexa enum 이 이미 `hexa_int(tag)` 라 default-ordered 가 자연 (Java 모델). probe 도 이미 이 동작 확인.

## 디자인 결정 (3 옵션)

### 옵션 A: default-ordered by tag (Java/Kotlin) — **현재 동작 (probe 확인)**
- `Priority::Low < Priority::High` ≡ `tag(Low) < tag(High)` ≡ `0 < 2` ≡ true
- enum 이 `hexa_int` 라 자동, `sort()` 도 tag-order
- 장점: zero codegen work (이미 작동)
- 단점: (1) payload variant 는 tag 만 비교, (2) cross-type 비교 무검사 (probe 확인)

### 옵션 B: opt-in `@derive(Ord)` (Rust/Swift)
- 기본 unordered (ordering 시 컴파일 에러)
- `@derive(Ord)` 시만 `<`/`>` 활성
- 장점: 명시적, 실수 방지
- 단점: boilerplate · r14-F enum-emit + `@derive` 인프라 의존 · 이미 작동하는 동작을 *깨야* 함 (regression)

### 옵션 C: default-ordered + payload lexicographic
- unit variant: tag 순서 (옵션 A 와 동일)
- payload variant: `(tag, payload...)` lexicographic (Rust 동일)
- 장점: 완전, Rust-canonical
- 단점: payload 비교 codegen 복잡 (r14-F TAG_ENUM 의존)

→ **옵션 A 채택** (default tag-order, Java/Kotlin 모델, 이미 작동). payload lexicographic 은 r14-F TAG_ENUM land 후 옵션 C 로 확장. 옵션 A → C 는 호환 (unit variant 동작 불변).

## 의미 결정

- unit variant ordering = 선언 순서 (tag 0, 1, 2, ...) — **현재 작동**
- payload variant: v1 은 tag 만 비교 (`Some(1) < None` 은 tag 비교 — payload 무시), v2 (TAG_ENUM 후) lexicographic
- 다른 enum 타입 간 비교 (`Color::Red < Priority::Low`): 현재 silent 통과 → **type error 권장** (probe 확인된 gap)
- `sort()` with enum → tag order (**현재 작동**)

## 영향 surface

| 파일 | 변경 |
|---|---|
| `self/codegen.hexa` (또는 runtime) | enum `<`/`>` → tag int 비교 (옵션 A 면 무변경 — 이미 emit) |
| `self/type_checker.hexa` (선택) | cross-enum-type 비교 금지 진단 |

## 구현 단계

옵션 A core 동작은 **probe 가 작동 확인 → docs-only sealed note** 로 충분.
잔여 polish (선택, 별도 사이클):
1. **TTTT-1**: cross-enum-type 비교 진단 (`Color::Red < Priority::Low` → type error) (~30줄, type_checker 의존)
2. **TTTT-2** (v2): payload variant lexicographic (옵션 C, r14-F TAG_ENUM land 후) (~40줄)

core ordering = 무변경 (sealed). polish = ~70줄 (선택).

## 우회책 (지금)
- 명시 tag 추출 후 비교 (enum → int cast)
- match 로 명시 순서 정의
- (cross-type 비교는 현재 무검사이므로 호출측에서 동일-타입 보장)

## 관계 RFC
- r14-F enum codegen-emit (#489): payload variant ordering (옵션 C) 의존
- r14-J NaN-in-sort (#486): sort comparator — enum sort 시 tag 비교 wire (probe 확인 작동)
- r14-LL tuple (#506): tuple lexicographic ordering 패턴 유사 (옵션 C 와 동형)
- r3 to_string(enum) → tag 노출 INBOX: `sort()` 결과가 `[0,1,2]` 로 print 되는 원인 (별개 lane)
