# channel + spawn (Go-style concurrency) design RFC

**Status**: design-level (r14 cycle 8, 2026-05-23)
**Priority**: P2 (RFC-022 async stage-1 land 후 다음 단계 — Go-style primitive 보강)
**SSOT**: r14-TT async RFC (PR #514) · `proposals/rfc_022_async_model.md` · `stdlib/channel.hexa` (551L IPC mkfifo) · `stdlib/future.hexa` (89L) · `stdlib/cancel.hexa` (154L) · `self/async_runtime.hexa` (349L scheduler + task_group)

## 현재 상태 (probe + grep 검증)

| 사이트 | 동작 |
|---|---|
| `async fn` + `await` | RFC-022 stage-1 landed (per r14-TT PR #514) — parser `parse_async_fn` 존재 |
| `stdlib/channel.hexa` | **mkfifo-IPC 551줄** — 별도 프로세스 간 통신 (in-process 아님, perl IO::Select 헬퍼) |
| `stdlib/future.hexa` | 89L `Future[T]` resolve/poll (RFC-022) |
| `stdlib/cancel.hexa` | 154L cancel token (RFC-022) |
| `self/async_runtime.hexa` | 349L `Scheduler` + `scheduler_spawn_task(sched, name, func_name)` + `TaskGroup` + `task_group_wait_all` |
| `spawn { body }` keyword | **이미 존재** (lexer L43 + parser L1395, L4133 `parse_spawn_stmt`) — 단 **블록-폼만** (`spawn { ... }`), 함수 인자형 `spawn f()` 부재 |
| `chan T` type | **부재** — keyword 없음, type 표현 없음 |
| `select { ... }` Go-style | **부재** — `select` keyword 는 `@select` 메타-DSL (parse-only attribute, `self/parser.hexa` L1130) 으로만 점유, multi-channel 분기 블록 없음 |
| `Channel[T]` in-process API | **부재** — stdlib mpsc 없음 |
| `c <- v` / `<-c` operator | **부재** — channel 화살표 operator 없음 |

(원인: RFC-022 는 async/await + Future 만 stage-1 에서 닫음. Go-style `chan/select`/`spawn f()` 는 design 미진행.)

## 캐노니컬

| 언어 | spawn | channel | select |
|---|---|---|---|
| Go | `go f()` (green thread) | `make(chan T)` · `c <- v` · `<-c` | `select { case v := <-c: ... }` |
| Rust | `tokio::spawn(async { ... })` · `std::thread::spawn` | `tokio::sync::mpsc::channel()` · `tx.send()` · `rx.recv()` | `tokio::select!` macro |
| Swift | `Task { ... }` · `task_group.addTask` | `AsyncStream` | (없음, `async let`) |
| Kotlin | `launch { ... }` · `async { ... }` | `Channel<T>` | `select { ... }` block |

→ Go 모델 + Rust mpsc 모델 hybrid 권장 — `spawn fn()` (green thread) + `chan T` typed + `select` block. 기존 `spawn { body }` 블록-폼은 keep, 함수-폼 추가.

## 디자인 결정 (5 옵션)

### 옵션 A: 풀 Go-style (built-in)
- `spawn f()` 함수-폼 추가 (기존 `spawn { body }` 와 공존)
- `chan T` type keyword (lexer + parser type 부분 신규)
- `c <- v` (send) / `<-c` (recv) operator (lexer 토큰 + parser expr branch)
- `select { case v := <-c: ... }` block (현 `@select` attribute 와 명확히 분리 — bare `select` keyword 가 stmt-position 이면 block-form)
- 장점: ergonomic, Go 사용자 즉시 인지 가능
- 단점: lang surface 크게 추가 (~3 keyword 의미 확장 + 2 operator + 1 block)

### 옵션 B: stdlib 함수 only (no keyword)
- `spawn_fn(f)` 함수 (또는 `task_spawn(f)`)
- `Channel[T]::new()` constructor
- `c.send(v)` / `c.recv()` methods
- `select_chans([c1, c2], handlers)` 함수
- 장점: lang 변경 최소 (stdlib 만)
- 단점: ergonomic 떨어짐, Go 사용자 친화도 낮음

### 옵션 C: Rust async/spawn 통합 (Tokio-스타일)
- `async fn` 만 spawn 가능
- `tokio::spawn` 같은 stdlib spawn (Future 반환)
- 별도 sync spawn 없음
- 장점: async와 통합 깔끔
- 단점: sync 코드도 async 강제, 기존 `spawn { body }` 폐기 필요

### 옵션 D: Swift Task 모델
- `Task { ... }` 블록 표현식 (이미 `spawn { body }` 와 동형)
- `await Task.value` 결과 받기
- 장점: 표현식 중심, 기존 surface 와 자연 통합
- 단점: Go-style 자유 spawn 어색, channel 분리 필요

### 옵션 E: hybrid (A + B)
- `spawn` keyword + stdlib `spawn_fn` helper
- `chan T` type + `Channel[T]` API 둘 다 지원
- 장점: progressive, 사용자 취향
- 단점: 두 API 유지 부담

→ **옵션 A 권장** (canonical Go) — async/await lane 과 별도 lane 으로 명시 구분. RFC-022 wired runtime 위에 lower.

## ABI / runtime

- `spawn f()`: green thread (stackless coroutine) — `scheduler_spawn_task` 으로 lower (이미 존재)
- `chan T`: in-process mpsc (multi-producer single-consumer) — `stdlib/channel.hexa` IPC 와 별도, `stdlib/channel_inproc.hexa` (신규) 로 분리
- `select`: 컴파일 시 case 별 ready-poll loop 로 lower
- 기존 `spawn { body }` blockform → 함수-폼 `spawn f()` 도 같은 `SpawnStmt` AST 노드 재사용 (callee 식별자만 추가 필드)

## 구현 단계 (stacked PRs)

1. **JJJ-1**: lexer `chan` keyword + `<-` operator token (~30줄, `select` 는 메타-DSL/Go-style context-sensitive disambiguation)
2. **JJJ-2**: parser `chan T` type + `spawn f()` 함수-폼 + `select { case ... }` block (~150줄)
3. **JJJ-3**: stdlib in-process `mpsc::Channel[T]` (`stdlib/channel_inproc.hexa`, ~200줄, IPC 와 분리)
4. **JJJ-4**: codegen `spawn f()` → `scheduler_spawn_task`, `c <- v` / `<-c` → method call (~100줄)
5. **JJJ-5**: codegen `select` block → multi-receive ready-poll lower (~150줄)
6. **JJJ-6**: stdlib `task_group` 사용성 보강 (이미 `self/async_runtime.hexa` 안에 있음 — stdlib 로 이전 + sugar, ~80줄)

총 ~710줄, 6-PR stack.

## 영향 surface

| 파일 | 변경 |
|---|---|
| `self/lexer.hexa` | `chan` keyword + `<-` token (`spawn`/`select` 는 이미 존재) |
| `self/parser.hexa` | `parse_spawn_stmt` 함수-폼 분기 + `chan T` type 파싱 + `select`-block (메타-DSL 와 disambiguation) |
| `self/codegen.hexa` | spawn / `<-` / select lower |
| `stdlib/channel_inproc.hexa` (new) | in-process mpsc `Channel[T]` |
| `stdlib/task_group.hexa` (new) | structured concurrency sugar — async_runtime 의 task_group 이전 |
| `self/async_runtime.hexa` | spawn 함수-폼 등록 (RFC-022 wired) |

## 관계 RFC

- **r14-TT async/await stage-2 (PR #514)**: async fn 안에서 `spawn f()` 사용 가능
- **RFC-022 async model**: spawn 은 RFC-022 executor 위에 lower
- **r14-EE panic 채널 (PR #501)**: spawn 된 task 안 panic 전파 정책 — channel 으로 panic 전송 가능 여부 결정
- **r14-X postfix `?` (PR #494)**: channel recv `Result[T]` 에 `?` 적용 가능

## 우회책 (지금)

- `spawn { body }` (블록-폼) 이미 작동 — 함수-폼 없이 inline body
- `scheduler_spawn_task(sched, name, func_name)` — 직접 scheduler API (RFC-022)
- `stdlib/channel.hexa` (mkfifo IPC) — 별도 프로세스 간이면 사용 가능
- `proc_spawn_*` (system process) — heavy, fire-and-forget
- `pool` CLI — host 간 dispatch
- RFC-022 `await` on resolved `Future[T]` — sync result 받기

## g3-honest fencing

- 본 RFC 는 **design-level 만**; 어떤 keyword/operator 도 lexer/parser 에 추가하지 않음
- 기존 `spawn { body }`, `@select` attribute, `stdlib/channel.hexa` IPC, `task_group_*`, `scheduler_spawn_task` 는 변경 없음
- 6-PR stack 라인 추정치 ~710 줄은 sketch — 실제 구현은 별도 사이클
- 옵션 A 권장은 Go 친화도 가중; 옵션 B (stdlib-only) 도 valid trade-off
