# canonical-deviation audit round 8 — consolidated (3 axes)

**Status**: audit-report-archived-2026-05-25 — meta audit report. CRITICAL write_file content-leak FIXED via PR #407. Remaining axes (concurrency · effects/error model · IO/FS/process) design-level, separate RFC track.

> **Status update (2026-05-23):** the 🚨 CRITICAL `write_file` content-leak is **FIXED + deployed** (#407). Root cause: `hxlcl_open_sys` issued a raw `svc #0x80` open that ignored the macOS arm64 carry flag, so a failed open returned the positive errno as a fake fd; `fopen`/`rt_write_file` then wrote content to that low descriptor and returned `true`. Routed `hxlcl_open_sys` through libc `open()` (the carry-flag fix cycle 66 applied to read/write/close/dup2 but missed for open). Verified e2e: `write_file("/tmp/<missing>/x","…")` → `false`, no stdout leak. Remaining axes (concurrency model, effects/error model, glob/listdir/tempfile) are **design-level** — tracked, not silent-failure bugs.

PROBE round 8 결과 (concurrency · effects/error model · IO/FS/process).
FIX-SURGICAL 항목은 별도 PR 로 이미 ship — 본 문서는 **design-level**
이탈 + **CRITICAL silent-failure** 클러스터 consolidated 기록.

## TL;DR

| axis | FIX-SURGICAL (이미 ship) | design-level (본 문서) | CRITICAL |
|---|---|---|---|
| concurrency | — (없음) | spawn/async/chan/Mutex/Thread/select 전체 | — |
| effects | — (없음) | defer-on-throw · defer-on-panic · finally · using/with | — |
| IO/FS | stdin alias · cwd() · mkdir bool (PR #399) | read_file silent "" · exec_with_status no stderr · env silent "" · glob/listdir/tempfile 부재 | **write_file content-leak-to-stdout** |
| float fold (r3 carry) | NegFloatLit fold (PR #397) | — | — |
| `in` binop (r7) | (PR #396) | — | — |

## 🚨 CRITICAL — `write_file` content-leak

### Symptom

```hexa
let ok = write_file("/tmp/__nopath__/x.txt", "miss")
```

**Observed**:
- Returns `true` (false success signal)
- Content `"miss"` leaks to **stdout** of the running process

**Expected** (Rust/Go/Py canonical):
- Return `false` / throw / `Result::Err`
- Content NOT printed anywhere

### Severity

- **Silent failure**: caller thinks write succeeded.
- **Data leak**: file content (potentially sensitive) prints to stdout, mixing with normal program output.
- **CI / pipeline corruption**: a write to a bad path during cron/CI would silently inject content into job logs.

### Hypothesis (location)

- Source `rt_write_file` (self/runtime_core.c:6040) looks correct.
- Binary divergence — possibly `_rt_write_file` stub vs hexa-side
  implementation mismatch.
- Or `fopen` ↔ `HX_STR` macro overload corrupting fd resolution.
- Or `fwrite` falling back to default stream (stderr/stdout) on
  fopen failure.

### Action

- Reproducer: 1-line probe `write_file("/tmp/__nopath__/x", "miss")`.
- Need binary disassembly of `hexa_write_file` symbol from
  `self/native/hexa_v2` vs source impl to identify drift.
- Separate investigation cycle (not in this audit doc PR).

## Axis 1 — Concurrency (전체 미구현)

| primitive | hexa-current | canonical |
|---|---|---|
| `spawn { … }` | runs sync (single-thread eval per codegen comment) | Go `go fn()` / Rust `thread::spawn` |
| `async fn` + `await` | parses, runtime hook exists | Rust `Future` polled by executor |
| `chan T` / `<-ch` | parse error `unexpected token Lt` | Go-native; Rust `mpsc` |
| `Mutex` | `unknown builtin method: new` | Go `sync.Mutex` / Rust `Mutex` |
| `atomic let counter = 0` | parses but global codegen drops | Go `atomic.Int64` |
| `select { case … }` | parse error | Go-native |
| `Thread.spawn(fn(){})` | parse error | Rust `std::thread` |

**Status**: 키워드 reserved-but-unbacked.  Two paths:
- (a) **demote keywords** (drop `spawn`/`async`/`atomic` from lexer) — honest single-thread story.
- (b) **wire backend** (pthread / libuv / async-runtime) — multi-month effort.

**Recommend**: (a) until a real demand surfaces.  Document hexa as
single-threaded eval semantics.  `atomic let` codegen drop = bug to
fix even in single-thread mode (PR-candidate).

## Axis 2 — Effects / error model (잔여)

| feature | hexa-current | canonical | priority |
|---|---|---|---|
| `defer { … }` basic | LIFO ✓ | Go/Swift/Py-finally | canonical |
| `defer` on early return | runs ✓ | Go/Swift/Rust-Drop | canonical |
| **`defer` on throw** | does NOT run | Go/Swift do | **design-level fix** |
| **`defer` on panic** | does NOT run | Go `recover()` / Rust Drop | design-level |
| `finally { … }` after `catch` | parse error | Java/Py/JS | round-3 carry |
| `using f = … { }` | parse error | C# `using` | design |
| `Ok`/`Err`/`Result` prelude | undeclared | Rust/Swift stdlib | round-3 carry |
| `Some`/`None` prelude | undeclared | Rust/Swift stdlib | round-3 carry |

### Defer-on-throw 핵심 design 결정

Go/Swift 의 `defer` 가 cleanup 의미를 가지려면 **throw path 도 통과**
해야 함.  현재 hexa 의 throw codegen 은 `goto __fn_exit` 우회 →
defer drain 누락.

**Fix path**: throw codegen 을 `__fn_exit` 경유로 재설계.  단,
panic (abort)은 별도 — process-level cleanup 은 OS 가 처리.

## Axis 3 — IO/FS/process (잔여)

PR #399 가 stdin alias + cwd() + mkdir bool 완료.  잔여:

| feature | hexa-current | canonical |
|---|---|---|
| `read_file("/missing")` | silent `""` (len=0) | Rust `Result<String>` / Py throws / Go `(nil,err)` |
| `exec_with_status(cmd)` | `[stdout, exit]` 2-tuple (stderr 누락) | Rust `Output{stdout,stderr,status}` 3-field |
| `glob("*.hexa")` | undeclared | Py `glob.glob` / Rust `glob` crate / Go `filepath.Glob` |
| `listdir(path)` | undeclared | Py `os.listdir` / Rust `fs::read_dir` / Go `os.ReadDir` |
| `tempfile()` / `tempdir()` | undeclared | Py `tempfile` / Rust `tempfile` / Go `os.CreateTemp` |
| `env(k)` missing var | silent `""` | Go `LookupEnv(k)→(v,ok)` / Rust `env::var → Result` |

**Cluster fix candidate**: `glob` + `listdir` + `tempfile` + `tempdir`
각각 ~10 LoC, 묶음 POSIX-fs PR 가능 (~40 LoC 한 cycle).

## 우선순위 (다음 cycle 후보)

| 항목 | 규모 | 영향 |
|---|---|---|
| **🚨 write_file content-leak 조사** | medium (binary diff) | CRITICAL silent-failure |
| atomic let global codegen drop | small | single-thread atomic semantic 유지 |
| defer-on-throw cleanup | medium | RAII/exception-safe semantic 핵심 |
| POSIX fs cluster (glob/listdir/temp*) | medium | stdlib 친화 ~40 LoC |
| read_file Result 도입 | small-medium | Option lane 결정 의존 |
| exec_with_status stderr 추가 | small | API tuple shape 변경 |
| 키워드 demote (spawn/async/atomic/chan/Mutex/Thread/select) | small (lexer) | 정직 single-thread 모델 |

## 참고

- FIX-SURGICAL clusters → PR #393 (bool) + PR #394 (destructure) + PR #396 (in op) + PR #397 (float fold) + PR #399 (r8 IO wins)
- prior round inbox: `inbox/patches/canonical-audit-round-7-consolidated.md` (PR #395)
- prior round inbox: `inbox/patches/canonical-audit-round-5-consolidated.md` (PR #377)
