# panic 채널 의미론 design RFC

**Status**: design-level (PROBE round 3 INBOX, r14 cycle 5 carry, 2026-05-23)
**Priority**: P2 (panic 현 동작 = process abort; recoverable error path는 별도 RFC r14-X / PR #494)
**SSOT**: PROBE.log.md round 3 Option/Result entry line 36 · self/codegen.hexa:3335 PanicStmt 핸들러 · self/parser.hexa:4018 parse_panic_stmt · r14-X postfix `?` RFC (PR #494)

## 현재 상태 (코드 검증)

| 메커니즘 | 동작 | 위치 |
|---|---|---|
| `throw "msg"` | recoverable — `try/catch` + `recover` 캐치 | self/codegen.hexa:3055 ThrowStmt → `hexa_throw()` (setjmp/longjmp) |
| `panic("msg")` | **unrecoverable — try/catch 캐치 안 됨, exit(1) 즉시** | self/codegen.hexa:3335 PanicStmt → inline `exit(1)` |
| `assert expr` | false 시 `exit(1)` — panic 메시지와 동일 형태 (별도 채널, 통합 안 됨) | self/codegen.hexa:3051 AssertStmt → `fprintf(stderr, "assertion failed\n"); exit(1);` |

### 코드 인용 (생성된 C 코드)

```c
// panic(msg) → 인라인 abort
{
    hexa_eprint_val(hexa_str("panic: "));
    hexa_eprint_val(<msg>);
    hexa_eprint_val(hexa_str("\n"));
    exit(1);
}

// assert expr → 별도 인라인 abort (panic 채널 미경유)
if (!hexa_truthy(<expr>)) {
    fprintf(stderr, "assertion failed\n");
    exit(1);
}

// throw msg → setjmp/longjmp 기반 unwind
hexa_throw(<msg>);
```

### 핵심 발견

1. **`exit(1)` 직접 호출** — `hexa_throw` 의 setjmp/longjmp 채널을 경유하지 않으므로 `try/catch` · `recover` 모두 패스 불가
2. **assert 메시지 위치 누락** — `assertion failed\n` 만 출력, file:line 없음
3. **codegen.hexa:3106 주석은 incorrect** — "if a throw/panic occurs the recover block is exited" 라고 적혀 있으나 panic 실제 동작은 process exit (recover 도달 불가)

## 캐노니컬 비교

| 언어 | panic 모델 | recover 메커니즘 |
|---|---|---|
| Rust | `panic!()` unwinds stack by default | `std::panic::catch_unwind` (UnwindSafe bound) |
| Go | `panic()` unwinds stack | `recover()` (deferred 함수 안에서만) |
| Python | panic 채널 없음 — `raise` 단일 | `try/except` |
| Swift | `fatalError()` 비복구 abort | 별도 `throws`/`try?`/`try!` 채널 |
| Zig | `@panic` runtime abort | `error union` 일반 채널 (panic은 unrecoverable) |
| Java | `Error` (e.g. OOM) — catchable 이나 권장 안 함 | `Throwable` 단일 계층 |

**관찰**: panic = unrecoverable abort 는 Swift `fatalError`/Zig `@panic` 와 일치. Rust `catch_unwind` 는 FFI 경계용 escape hatch이며 일상 control-flow 가 아님.

## hexa panic 의미론 (3 옵션)

### 옵션 1: 항상 abort (현재 동작 유지 + 정리)
- `panic(msg)` → 즉시 `exit(1)` + stderr 메시지 (현 codegen 그대로)
- `catch_unwind` 없음
- 장점: 단순, deterministic, FFI/runtime invariants 보호
- 단점: production server long-running process 에서 한 fault 로 전체 종료
- 정리 항목:
  - exit code 통일 (1 vs 134 결정)
  - file:line 정보 메시지에 포함 (`panic: <msg>\n  at <file>:<line>\n`)
  - `assert` 를 panic 채널로 라우팅 (`panic("assertion failed: <expr>")`)

### 옵션 2: unwind + catch_unwind (Rust 모델)
- panic 발생 시 stack unwind, RAII/defer 실행
- `catch_unwind { ... }` builtin 으로 recoverable 화 (FFI 경계용)
- 장점: production-friendly, isolation 가능 (HTTP request 단위 격리)
- 단점:
  - unwind 구현 비용 (frame pointer table 또는 DWARF) — 현 codegen 은 C exit 기반
  - hexa_throw 와 채널 통합 시 panic 본래 의미 손실
  - hexa runtime 의 longjmp 채널 재사용 가능하나 panic≠throw 의미 구분 흐려짐

### 옵션 3: panic = throw + 명시적 force-abort
- `panic("msg")` 을 `throw "PANIC: <msg>"` 로 desugar (recoverable)
- 별도 `force_abort("msg")` builtin = `exit(1)` (현 panic 동작)
- 장점: 단일 채널 (throw) 로 통합, r14-X postfix `?` + Result 와 자연 짝
- 단점:
  - panic 본래 "이건 unrecoverable" 의미 손실
  - 모든 panic catch 가능해지면 silent swallow 위험
  - codegen.hexa:3106 주석이 잘못 작성한 의도와 일치하나 채널 분리 이점 상실

→ **옵션 1 권장 (현 동작 명시 + assert 통합 + 메시지 정리)**, 옵션 2 는 future (FFI escape hatch 가 필요할 때, `unwind` build mode)

## 결정 사항 (이 RFC 가 잠그는 것)

1. `panic` 채널 = **process abort**, recoverable 아님 (현 codegen 동작 의도된 것으로 명시)
2. `throw` / `Result::Err` = recoverable, postfix `?` 통해 short-circuit (r14-X / PR #494)
3. `assert expr` → false 시 `panic("assertion failed: <expr-source>")` 로 라우팅 (현재는 별도 `exit(1)` 경로)
4. `unreachable()` builtin 신설 → `panic("unreachable code reached")` 로 라우팅
5. panic 메시지 stderr 형식 통일: `panic: <msg>\n  at <file>:<line>\n`
6. exit code = **1** (현 codegen 확인됨; 134/SIGABRT 채택은 별도 결정 필요)
7. codegen.hexa:3106 주석 정정 — "throw 만 recover 가 캐치, panic 은 process exit"

## 영향 surface

| 파일 | 변경 | 라인 수 추정 |
|---|---|---|
| `self/codegen.hexa::PanicStmt` (3335-3342) | 메시지 포맷 통일 (file:line 인서트) | ~10 |
| `self/codegen.hexa::AssertStmt` (3051-3053) | PanicStmt 로 라우팅 — `assertion failed: <expr>` | ~5 |
| `self/codegen.hexa:3106` | recover 주석 정정 (throw만 캐치) | ~3 |
| `self/parser.hexa::parse_panic_stmt` (4018) | source location 캡처 (file/line) | ~5 |
| `stdlib/runtime/panic.hexa` (new) | builtin 시그니처 + `unreachable()` 추가 | ~30 |

총 변경 추정 ~50-60 라인

## 구현 단계 (stacked PRs, 본 RFC 결정 후)

1. **EE-1**: `PanicStmt` 메시지 포맷 통일 + file:line 캡처 (~25줄)
2. **EE-2**: `AssertStmt` → PanicStmt 라우팅 + `unreachable()` Phase 1 macro (~30줄, #462 패턴)
3. **EE-3**: PROBE.log.md round 3 갱신 (panic 채널 sealed 표시) + codegen 주석 정정 (~15줄)

총 ~70줄, 3 PR stack. g4 (<200 lines / PR) 자연 충족.

## 관계 RFC

- **r14-X postfix `?` + Result ABI** (PR #494, in-flight): recoverable lane SSOT — panic 은 그 lane 의 *반대* 채널
- **r14-F enum to_string codegen-emit RFC** (PR #489, merged): Result enum variant repr (ABI option A 시 의존)
- **r14-AA shadowing scope leak RFC** (PR #496): 별 silent miscompile cluster — 무관
- **#462 macro expander Phase 1**: `panic!` / `println!` intrinsic 이미 desugar — `assert!` / `unreachable!` 동일 패턴 확장 가능

## 우회책 (지금)

- panic 은 abort 전제로 사용 (catch 불가, restart 외 복구 없음)
- recoverable error 는 `throw` + `try/catch` 또는 (r14-X 머지 후) `Result<T,E>` + `?`
- assert 는 디버그 빌드 전용으로 간주 (현재 release 가드 없음 — 별도 follow-up)

## 미해결 질문 (이 RFC 가 다음 라운드로 넘기는 것)

- Q1: exit code 1 유지 vs 134 (SIGABRT) — POSIX convention 채택 여부
- Q2: backtrace 출력 (`HEXA_BACKTRACE=1` env gate 같은 Rust 패턴) — Phase 2 로 분리
- Q3: panic-handler hook (`set_panic_handler`) — option 2 와 묶이는 future feature
- Q4: release 빌드에서 assert 비활성화 정책 (`HEXA_DEBUG_ASSERT` env) — 별도 RFC
