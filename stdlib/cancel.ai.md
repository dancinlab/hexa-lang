# stdlib/cancel — cooperative cancellation Token

**Status**: preview (since 2026-05-09)
**Module**: `stdlib/cancel.hexa`
**Selftest**: `stdlib/test/test_cancel.hexa` — 23/23 PASS (interp, macOS arm64)
**Driver**: wilson core port G3 prereq (`incoming/PATCHES.yaml#wilson-pi-port-6-gap-prereq`)
**Spec companion**: `proposals/rfc_022_async_model.md` §6

## TL;DR

Hexa stage 1 is single-threaded and has **no preemption** — the scheduler in `self/async_runtime.hexa` is a pattern library, not a live runtime, and `await` is identity (RFC-022 §3). Long-running loops, stream readers, and `await`-in-loop bodies therefore need a **caller-driven** way to be told "stop now". `stdlib/cancel` is that primitive.

A `Token` is a tiny, monotonic, sticky-reason flag. Callers poll it; nothing in the runtime polls it for them. Once flipped, it never un-flips, and the first reason wins.

```hexa
use "stdlib/cancel"

let mut t = token_new()                // fresh, alive
while token_check(t) {                 // false ⇒ canceled
    let chunk = read_chunk()
    if chunk == "" { break }
    consume(chunk)
    if budget_exceeded() {
        t = token_cancel(t, "budget")  // monotonic flip
    }
}
```

## API surface (6 functions, 1 struct)

| Symbol                              | Purpose                                                                              |
|-------------------------------------|--------------------------------------------------------------------------------------|
| `struct Token { canceled, reason }` | the cancellation flag itself — value semantics, immutable per-call                   |
| `token_new() -> Token`              | fresh, alive, reason=""                                                              |
| `token_new_canceled(reason) -> Token`| preset canceled (empty reason normalised to "preset")                               |
| `token_cancel(t, reason) -> Token`  | monotonic flip; first reason wins; empty reason normalised to "canceled"            |
| `token_check(t) -> bool`            | **true while alive**, false after cancel — reads naturally as `while token_check(t)`|
| `token_is_canceled(t) -> bool`      | inverse of `token_check`                                                             |
| `token_reason(t) -> string`         | "" while alive; sticky non-empty after cancel                                        |
| `token_throw_if_canceled(t)`        | `panic("canceled: <reason>")` if set, else no-op                                     |

## Three idioms

### 1. While-guard polling (preferred for loops)

```hexa
let mut t = token_new()
let mut acc = 0
while token_check(t) {
    acc = acc + step()
    if acc > 1000 { t = token_cancel(t, "budget_exceeded") }
}
println("done; reason=" + token_reason(t))
```

### 2. Throw-on-cancel at safe-points (preferred for nested calls)

```hexa
fn deep_walk(t: Token, node: Node) -> int {
    token_throw_if_canceled(t)         // no-op while alive
    let mut sum = 0
    for child in node.children {
        sum = sum + deep_walk(t, child)
    }
    return sum
}
```

Stage 1 panic is hard-exit equivalent (no try/catch). Use this only when unwinding the call stack on cancel is acceptable.

### 3. Pass-through cancel for async fns

```hexa
@async
fn long_pull(t: Token, src: int) -> string {
    let mut acc = ""
    while token_check(t) {
        let chunk = await read_chunk(src)
        if chunk == "" { break }
        acc = acc + chunk
    }
    return acc
}
```

This is the canonical RFC-022 §6 idiom. The scheduler does **not** auto-cancel `long_pull`; the caller passes the same `Token` to every cancellable subtask, and any path may flip it.

## Why monotonic + sticky-reason

- **Monotonic**: a second `token_cancel(t, "different")` is a no-op once already canceled. Prevents reason flapping in race-prone code, and gives every observer a single coherent answer to "why".
- **Sticky reason**: once recorded, `token_reason(t)` returns that string forever. Logs, error messages, and diagnostic dumps see a stable cause.
- **Empty-reason normalisation**: callers that don't care still get a meaningful string (`"canceled"` for `token_cancel`, `"preset"` for `token_new_canceled`).

## Stage-1 vs stage-2 semantics

| Concern                        | Stage 1 (today)                           | Stage 2 (when scheduler ships)                 |
|--------------------------------|-------------------------------------------|------------------------------------------------|
| Threading                      | single-threaded; no race                  | atomic CAS on `canceled` flag                  |
| Cascading parent → child       | not implemented                           | optional `parent_id` field; cascade on cancel  |
| Auto-cancel on timeout         | caller writes the timer + cancel pair     | `Token` may be born with a deadline            |
| panic semantics                | hard exit (no try/catch in language yet)  | structured unwind through async frames         |
| API surface change             | n/a                                       | **none** — additions only                      |

The wire types in this file are deliberately one-byte-equivalent (`bool` + `string`) so that stage-2 atomic upgrade is a backend change, not a source change.

## Common pitfalls

- **Forgetting to poll**: a loop body that never calls `token_check` / `token_throw_if_canceled` will run to completion regardless of cancel. There is no auto-injection.
- **Polarity confusion**: `token_check(t)` returns `true` while *alive*, not while canceled. Idiom: read it as "may continue?". For "is it canceled?" use `token_is_canceled`.
- **Mutating the wrong copy**: `token_cancel` returns a *new* Token; the original variable retains its old state if you don't rebind. Use `let mut t = ...; t = token_cancel(t, ...)`.
- **Empty reason**: passing `""` to `token_cancel` does not "skip" the cancel — it cancels with the default reason `"canceled"`. To "not cancel", just don't call.

## Selftest matrix

`stdlib/test/test_cancel.hexa` (23/23 PASS) covers:

| Group | Cases                                                    |
|-------|----------------------------------------------------------|
| 1     | fresh-token state (alive, not canceled, empty reason)    |
| 2     | cancel flips state and records reason                    |
| 3     | monotonic — second cancel keeps first reason             |
| 4     | empty-reason normalisation                               |
| 5     | preset constructor                                       |
| 6–8   | check / is_canceled / reason polarity                    |
| 9–10  | concurrent-poll loop pattern (cancels on the right tick) |

## See also

- `proposals/rfc_022_async_model.md` — async model RFC (G2). §3 establishes that stage 1 is single-threaded; §6 establishes the Token integration contract.
- `self/async_runtime.hexa` — cooperative scheduler *pattern library*. Not wired to eval today.
- `stdlib/channel.hexa` — mkfifo IPC, the only currently-functional cross-process concurrency primitive. Channels and Tokens compose: a recv loop polls its Token between blocking recvs.
- `incoming/PATCHES.yaml#wilson-pi-port-6-gap-prereq` — wilson core port entry; G3 = this module.
