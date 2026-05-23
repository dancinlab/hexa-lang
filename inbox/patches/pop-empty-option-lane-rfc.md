# `[].pop()` empty → Option lane design RFC

**Status**: design-level (PROBE round 3 INBOX line 63, r14 cycle 13, 2026-05-24)
**Priority**: P2 (silent void = silent miscompile cluster · Option/Some/None prelude 의존)
**SSOT**: PROBE.log.md round 3 Array entry · r14-KK Option prelude (#505) · r14-X postfix ? (#494)

## 현재 동작 (probe 검증)

probe `/tmp/probe_pop_option_r14.hexa` 빌드+실행 결과 (compiled path, exit 0):

| 표현 | hexa 동작 |
|---|---|
| `[1,2,3].pop()` (non-empty) | `3` 반환 (이후 `2`, `1`) — 정상 |
| `[].pop()` (empty) | silent `void` (no error, exit 0) — 🔴 silent miscompile |
| `print([].pop())` 결과 | 리터럴 문자열 `"void"` 출력 |
| `let x = [].pop(); x + 1` (void 산술) | `"void1"` (void → 문자열 concat 강제, crash 없음) — 🔴 garbage |

루트: `self/runtime_core.c:4799` / `:4819` `hexa_array_pop` — empty/non-array 시 `hexa_void()` 반환.

## 캐노니컬

| 언어 | empty pop | non-empty pop |
|---|---|---|
| Rust | `None` (`Option<T>`) | `Some(T)` |
| Python | `IndexError` raise | T |
| JS | `undefined` | T |
| Go | (no pop — slice 직접) | — |
| Swift | `removeLast()` crash · `popLast() -> Optional` | T / Optional |

→ 두 캐노니컬: Rust Option (`pop -> Option[T]`) vs Python exception (`IndexError`). g1 canonical-first + r14-KK Option prelude land 시 → Rust Option 권장.

## 디자인 결정 (3 옵션)

### 옵션 A: `pop() -> Option[T]` (Rust, 권장 — KK 의존)
- non-empty: `Some(T)` · empty: `None`
- 사용: `if let Some(x) = xs.pop() { ... }` (r14-SS if-let 연계)
- 장점: canonical, safe
- 단점: Option prelude (#505) + if-let (#513) 의존, 기존 `let x = xs.pop()` 호출 사이트 마이그레이션 (now Option)

### 옵션 B: `pop()` throw on empty (Python)
- non-empty: T · empty: `throw "pop from empty array"`
- 사용: try/catch
- 장점: Option 의존 없음, 즉시 가능
- 단점: 매 pop 마다 try/catch boilerplate

### 옵션 C: dual API
- `pop() -> T` (throw on empty, Python) + `pop_opt() -> Option[T]` (Rust, KK 후)
- 장점: 둘 다 · 단점: API 중복

→ **옵션 A 권장** (Rust Option) — 단 r14-KK Option prelude land 가 선행 조건. KK 전까지는 옵션 B (throw) 가 stop-gap.

## 마이그레이션 우려

- 기존 `let x = xs.pop()` 코드가 많으면 옵션 A 는 breaking (now Option[T])
- 완화: `pop()` 유지 (throw, 옵션 B) + 새 `pop_opt()` 추가 (옵션 C hybrid) → non-breaking
- 또는 단계적: v1 옵션 B (throw, silent-void 제거) → v2 옵션 A (KK 후)

## 영향 surface

| 파일 | 변경 |
|---|---|
| `self/runtime_core.c:4799/4819` | `hexa_array_pop` empty 시 None/throw |
| `self/codegen.hexa` | pop 결과 타입 (옵션 A 시 Option) |
| `stdlib/option.hexa` (KK) | Option[T] 의존 |

## 구현 단계

stop-gap (옵션 B, 즉시):
1. **UUUU-B1**: `hexa_array_pop` empty → throw "pop from empty array" (~10줄 runtime)

full (옵션 A, KK 후):
2. **UUUU-A1**: `pop() -> Option[T]` (KK Option prelude land 후)
3. **UUUU-A2**: 호출 사이트 마이그레이션 또는 `pop_opt()` 추가

## 우회책 (지금)
- 명시 empty 체크: `if xs.len() > 0 { let x = xs.pop() }`
- silent void 결과 사용 안 함 (`void + 1` → `"void1"` garbage)

## 관계 RFC
- r14-KK Option/Some/None prelude (#505): 옵션 A 선행 조건
- r14-SS if-let/while-let (#513): `if let Some(x) = xs.pop()` 사용 패턴
- r14-X postfix ? (#494): `xs.pop()?` 연계
- r14-F enum codegen-emit (#489): Option 이 enum 이라 의존
