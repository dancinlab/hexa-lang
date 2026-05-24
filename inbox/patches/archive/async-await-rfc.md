# async / await Stage-2+ design RFC

**Status**: rfc-draft-deferred-2026-05-25 — design-only patch (not a fix). Promote via /inbox skill if RFC track wanted.
**Status**: design-level (r14 cycle 7, 2026-05-23)
**Priority**: P3 (큰 작업 — runtime + lang surface; 종합 디자인 필요)
**SSOT**: 본 RFC + `proposals/rfc_022_async_model.md` (Stage 1, Integrated 2026-05-10)
**Precedent**: RFC-022 가 stage-1 (identity-await, single-thread, cooperative-pattern-only) 닫음. 본 RFC 는 stage-2+ (실제 스케줄러 · structured concurrency · I/O event loop) 디자인.

## 현재 상태 (probe 2026-05-23)

| 사이트 | 동작 |
|---|---|
| `async fn f() { ... }` | parser/codegen 모두 처리, `FnDecl` 와 동일 emit (RFC-022 §3.1) |
| `await e` | parser AwaitExpr · codegen `hexa_await_unwrap(inner)` · runtime helper (RFC-022 §4.2-4.3) |
| 의미론 (stage 1) | identity-on-value · Future struct 면 `.value` 1-level unwrap |
| 실제 scheduling | 없음 (모든 async fn 동기 실행) |
| 협력 cancellation | `stdlib/cancel.hexa` Token (RFC-022 §6, G3) |
| IPC | `stdlib/channel.hexa` mkfifo bidirectional (553L, 진짜 동작) |
| pattern lib | `self/async_runtime.hexa` 349L (Rust-port, eval/codegen 미연결) |
| 동시 I/O 우회 | `proc_spawn_with_channels` · `exec_stream_async` (subprocess) |

→ **언어 표면은 완성, 진짜 동시성은 없음.** wilson core 가 stage 1 식별자만으로 진행 중. 본 RFC 는 stage 2+ 통합 디자인.

## 캐노니컬 비교

| 언어 | 모델 | 런타임 | hexa stage 1 매핑 |
|---|---|---|---|
| Rust | `async fn` + `Future` + `.await` + 외부 executor (Tokio) | zero-cost stackless | 신택스 동일, executor 없음 |
| JS | `async function` + `await` | built-in event loop | identity-await ≠ JS |
| Python | `async def` + `await` + asyncio | single-thread eloop | identity-await ≠ asyncio |
| Swift | `async func` + `await` + structured concurrency | Apple GCD | task group 없음 |
| Go | `go fn()` + `chan T` | runtime M:N scheduler | `proc_spawn_with_channels` 만 |

신택스는 Rust/Swift 채택 완료. 잔여 결정 = (a) executor 모델 (b) state machine vs stackful (c) structured concurrency.

## 디자인 결정 (stage 2)

### D1. Executor 모델 — option 4 (hybrid)

- 옵션 1 Rust 명시 executor: 사용자가 `executor.run(main_async())` 호출. zero-cost, 명시적, but ergonomics 나쁨.
- 옵션 2 JS built-in: runtime 가 자동 eloop. 단순, but runtime 비대해짐 + opt-out 불가.
- 옵션 3 Go goroutines: async/await 키워드 불필요. 단순 but RFC-022 가 이미 키워드 land. 폐기.
- 옵션 4 hybrid (**권장**): `fn main()` 이 `async fn main()` 이면 컴파일러가 자동 `executor.run(main())` wrap. 사용자 명시 호출도 허용. ergonomic + 명시 둘 다.

### D2. State machine vs stackful — stackless (Rust 모델)

- stackful (Go-style): heap-coroutine, context switch via setjmp/longjmp. 단순 mental model but 코루틴당 8KB+ 스택, hexa GC 와 root scan 충돌.
- stackless (Rust): `async fn` → state machine struct 로 lower. await point 마다 state 번호. ~수십 바이트.
- **권장**: stackless. hexa GC 와 자연, 메모리 효율, codegen 결정적.

### D3. Future 표현 ABI

- stage 1 `Future { value, resolved, error }` flat record 유지.
- stage 2 추가: `Future { value, resolved, error, state_id, frame_ptr }` — state machine resume 포인터.
- 호환성: stage 1 코드 (`future_resolve(v)`) 는 `state_id = -1` (terminal) 자동 채움. RFC-022 §5 backward-compat 보장 유지.

### D4. Scheduler — single-thread eloop (stage 2), multi-thread deferred (stage 3)

- stage 2: `self/async_runtime.hexa` 의 `Scheduler` 를 진짜 wire. ready queue · pending waiters · I/O readiness map. POSIX kqueue (Mac) / epoll (Linux) FFI.
- stage 3: work-stealing M:N (`self/work_stealing.hexa` 활성화). 별도 RFC. hexa GC thread-safety 선행 결정 필요.

### D5. Structured concurrency

- `task_group { ... }` 블록: 블록 종료 시 모든 spawn 된 task join 보장 (Swift 모델).
- 취소 전파: `CancellationToken` (stdlib/cancel.hexa 의 Token) 를 task group root 에 묶음. parent 취소 → children 자동 취소.
- 단독 spawn (`spawn fn ()`) 은 task group 외부에서 금지 (Trio 모델). leak 방지.

### D6. I/O primitives — `stdlib/async_io.hexa` 신규

- `async fn tcp_connect(addr: str) -> TcpStream`
- `async fn read(stream: TcpStream, n: i64) -> bytes`
- `async fn sleep_ms(ms: i64) -> void`
- `async fn select(events: [Event]) -> i64`
- 모두 OS readiness 를 eloop 에 등록 후 yield.

## 실행 모델 예시

```hexa
use "stdlib/async_io" as io
use "stdlib/cancel" as cx

async fn fetch(url: str, tok: cx.Token) -> str {
    let conn = await io.tcp_connect(url)   // yield 1
    cx.token_throw_if_canceled(tok)
    let resp = await io.read(conn, 4096)   // yield 2
    return bytes_to_str(resp)
}

async fn main() {
    let tok = cx.token_new()
    task_group {
        let a = spawn fetch("a.com", tok)
        let b = spawn fetch("b.com", tok)
        let ra = await a
        let rb = await b
        print(ra + rb)
    }   // task_group 종료 시 a/b 둘 다 join
}
// 컴파일러: fn main() async → executor.run(main()) 자동 wrap (D1)
```

각 `await` 가 state machine state transition. 컴파일러가 `async fn` 을 익명 struct + `poll() -> Poll<T>` 메서드로 lower (RFC-022 stage-1 의 flat Future 와 호환).

## 구현 단계 (stacked PRs, 본 RFC 결정 후)

| PR | 작업 | 추정 라인 |
|---|---|---|
| TT-1 | state machine lowering (codegen): `async fn` → struct + poll | ~300 |
| TT-2 | `Scheduler` 활성화: `self/async_runtime.hexa` 의 ready queue 를 eval/codegen 에 wire | ~200 |
| TT-3 | OS eloop FFI: kqueue (Mac) / epoll (Linux) C primitive in runtime | ~250 |
| TT-4 | `stdlib/async_io.hexa`: tcp_connect · read · sleep_ms · select | ~200 |
| TT-5 | `task_group { ... }` parser · codegen · join 보장 (structured concurrency) | ~150 |
| TT-6 | `spawn` outside task_group 금지 (lint) · CancellationToken propagation | ~80 |
| TT-7 | `fn main() async` 자동 wrap (D1) | ~50 |

총 ~1230 줄, 7-PR stack. **large** — 본 RFC 합의 없이 시작 불가.

## 영향 surface

| 파일 | 변경 |
|---|---|
| `self/parser.hexa` | `task_group { ... }` · `spawn e` production |
| `self/codegen.hexa` | state machine lowering (TT-1, 큰 작업) · spawn → scheduler.spawn |
| `self/async_runtime.hexa` | eval/codegen 에 wire (현재 미연결 패턴 라이브러리) |
| `self/runtime.c` | kqueue/epoll FFI + 코루틴 frame alloc |
| `stdlib/async_io.hexa` (신규) | OS readiness async I/O |
| `stdlib/cancel.hexa` | task_group propagation API 추가 |
| `proposals/rfc_022_async_model.md` | stage-2 closure (status note) |

## 우려사항

- **GC + 코루틴 root scan**: state machine struct 가 stack frame 대신 heap 상주. GC root tracking 확장 필요. (stage 3 multi-thread 시 더 복잡.)
- **cancellation race**: Token check 와 await yield 사이 race. RFC-022 §6 cooperative 가정 유지하되 task_group 종료 시 강제 fire 정책 결정.
- **stage-1 코드 호환**: 기존 `Future { value, resolved, error }` flat record 사용 코드가 깨지면 안 됨. D3 자동 `state_id = -1` 보장.
- **executor 폴리시**: 자동 wrap (D1) 이 `fn main() async` 만 적용 — sync main 은 unchanged. magic 최소.
- **debug**: state machine lowering 후 stack trace 가 user code 와 분리됨 (`async-trace`?).

## 우회책 (지금, stage 1)

- `proc_spawn_with_channels` + mkfifo IPC (stdlib/channel.hexa)
- `exec_stream_async` + non-blocking poll (subprocess only)
- pool CLI (분산, OS-level)
- thread + mutex (있다면; hexa-lang stage-1 에 보장 없음)

## 관계 RFC / PR / inbox

- **RFC-022 async model parity** (stage 1, Integrated): 본 RFC 의 전제. 신택스 + identity-await + Future flat record + Token 확정.
- r14-EE panic 채널: async 안 panic 처리 — task_group 내 panic 전파 정책 (별도 결정)
- r14-FF try-expr: `try { await x }` block — Result 의 await chain
- r14-X postfix `?` (#494): `await x?` → `Future<Result<T>>` 패턴
- channel/spawn 별도 RFC: Go-style `chan T` 표면 (D5 의 spawn 과 다름)
- `self/work_stealing.hexa`: stage 3 M:N (별도 RFC 후 활성화)
