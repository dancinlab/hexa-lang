# RFC-022 — async model parity (interpreter ⇄ native codegen)

- **Status**: **Integrated** (2026-05-10, PM) — v1 codegen + interp parity landed; see §10. wilson core gate cleared.
- **Status (history)**: Draft (2026-05-10, AM) — design only.
- **Author date**: 2026-05-10
- **Predecessors**: RFC-018 (native codegen spec), RFC-021 (daemon mode)
- **Companion deliverable**: stdlib/cancel.hexa (G3 — cooperative cancellation Token)
- **Block dependency**: wilson core port (incoming/PATCHES.yaml#wilson-pi-port-6-gap-prereq) — G2 of {G1, G2, G3} prereq triple
- **Style template**: RFC-018 (numbered sections, divergence table, surface-impact bullets)
- **Affected areas (eventual)**: `self/parser.hexa` (AsyncFnDecl already lands), `self/lexer.hexa` (async/await keywords already reserved), `self/codegen_c2.hexa` (currently ignores Await — see §4), `self/hexa_full.hexa` (interpreter — Await is identity, see §3.2), `self/async_runtime.hexa` (cooperative scheduler ground truth), `stdlib/channel.hexa` (FIFO IPC), `stdlib/cancel.hexa` (this RFC §6).

---

## 1. Status / motivation

### 1.1 The wilson trigger

wilson core porting (the upstream consumer of hexa-lang's runtime) cannot proceed until the language commits to a **single, observable async semantic** that the interpreter and the native compiler agree on. Today the surface is split:

- The interpreter (`self/hexa_full.hexa`) has explicit Await handling: lines 8029–8038 — `await` is identity passthrough on resolved values, with a special-case for a `Future` struct shape.
- The native codegen (`self/codegen_c2.hexa`) has **no AwaitExpr / AwaitStmt branch at all** (grep confirms). `AsyncFnDecl` is treated identically to `FnDecl` for the C-emission path (line 6485). `await x` therefore emits as **whatever `x` evaluates to** in C — silently dropping the keyword.

This is not a bug in either component — it is a deliberate stage-1 stub. But wilson cannot sequence its async pipeline against a stub that two backends interpret subtly differently.

### 1.2 Goals

1. Document the **canonical async semantics** for stage 1: cooperative, single-threaded, identity-await.
2. Identify every concrete divergence between interpreter and native codegen and decide which side moves.
3. Define the surface that wilson can program against today, with an explicit upgrade path to a real scheduler in stage 2+.
4. Give G3 (`stdlib/cancel`) a stable integration contract.

### 1.3 Non-goals (this RFC)

- Real preemptive concurrency.
- Multi-thread runtime, work-stealing, or lock-free queues (see `self/work_stealing.hexa` — exploratory, not load-bearing).
- Effect-typed async (`async fn` participating in an effect row).
- Full `select` semantics over channels and timers — only the shape is reserved.

---

## 2. Current async surface (audit, 2026-05-10)

### 2.1 Lexer / parser

- `self/lexer.hexa:28-29` — `async` and `await` are reserved keywords (Lexer emits `Async` / `Await` tokens).
- `self/parser.hexa:3519-3548` — `parse_async_fn()` accepts `async fn name(params) -> ret { body }` and emits a top-level `AsyncFnDecl` AST node. The node carries `params`, `body`, `ret_type`, `annotations`.
- `self/parser.hexa:447` — `Await` is in the reserved-keyword guard for parameter / let-binding names.
- **Gap**: there is **no parser branch** that builds an `AwaitExpr` or `AwaitStmt`. The keyword is reserved, the node kinds (`NK_AWAIT`, `NK_AWAIT_EXPR`) exist in `hexa_full.hexa:5657-5658`, but no production builds them. Today programs say `await foo()` only inside contexts where the interpreter parses it as a unary operator (it falls through to expression-level handling in `hexa_full.hexa:8029-8038` only when the AST shape happens to land there — verified empirically by `self/_smoke_exec_stream_async.hexa`). **Action**: parser must explicitly produce `AwaitExpr` for `await <expr>`. Scoped out of this batch but tracked here.

### 2.2 Interpreter (`self/hexa_full.hexa`)

- `NK_AWAIT = 43`, `NK_AWAIT_EXPR = 44` (lines 5657–5658).
- Eval (lines 8029–8038):
    ```
    if kid == NK_AWAIT || kid == NK_AWAIT_EXPR {
        let v = eval_expr(node.expr)
        if v.tag == TAG_STRUCT && v.struct_name == "Future" {
            ...                       // unwrap Future.value
        }
        return v
    }
    ```
- Translation: in single-threaded interp, every `await x` is **identity on x** — except when x happens to be a `Future` struct, in which case the field `value` is extracted. There is no suspension, no yield, no scheduling.

### 2.3 Native codegen (`self/codegen_c2.hexa`)

- `AsyncFnDecl` → emitted as a regular C function (line 6485).
- **No** `AwaitExpr` branch. Grep `Await` in `codegen_c2.hexa` returns zero hits.
- Effect: `await foo()` → emits `foo()` directly. **This silently agrees with the interpreter for the resolved-value case** but fails for the `Future` struct unwrap branch.

### 2.4 Cooperative runtime (`self/async_runtime.hexa`, 349 LOC)

- A pure-data scheduler model: `Scheduler { ready_queue, futures, n_workers, ... }`, `Task { id, state, func_name, ... }`, `HexaFuture { value, resolved, producer_task }`, `TaskGroup`, `SelectEvent`. All "ports" of an upstream Rust scheduler, but **none of these types are wired into the interpreter eval path or the codegen emit path**. They are a *pattern library*, not a runtime.
- The existing identity-await semantics in §2.2 effectively bypass this entire file. wilson must **not** assume `Scheduler` does anything live in stage 1.

### 2.5 IPC / spawn channel

- `stdlib/channel.hexa` (443 LOC) — mkfifo-backed bidirectional channel, persistent across `exec()` boundaries. Independent of the in-process scheduler. **This is the only currently-functional concurrency primitive.**
- `self/runtime.c` `hexa_exec_stream_async_impl` (line 8897) — `popen()` + non-blocking fcntl. Streams stdout lines with `exec_stream_poll(handle)`. Used by `cli_mvp.hexa`. **This is the only async-shaped runtime call in stage 1, and it is OS-level (subprocess), not language-level.**

### 2.6 `@async` attribute

- `self/attrs/async.hexa` — attribute meta-info (purpose, side-effect, lint rule). The lint rule warns when an `@async fn` body calls a known-blocking builtin (`sleep`, `read_file`, `exec`, …). **This is documentation-only**: no transform runs, no CPS / state-machine emit, despite `cost_rule = "codegen emits CPS/state-machine transform"`.

### 2.7 Summary table — what works in stage 1

| Surface             | Interpreter         | Native codegen        | Notes |
|---------------------|---------------------|-----------------------|-------|
| `async fn`          | parsed, runs sync   | parsed, emits sync C  | identical: `async` is a tag, not behaviour |
| `await x`           | identity (+ Future unwrap) | identity (no special case) | divergence on Future struct |
| `spawn { body }`    | inline block        | inline C block        | same single-thread eval (`codegen_c2.hexa:2156-2169`) |
| `channel` keyword   | reserved, unparsed  | reserved, unparsed    | not a runtime feature; see `stdlib/channel.hexa` for FIFO |
| `select`            | reserved, unparsed  | reserved, unparsed    | no production today |
| `Scheduler` / `Task`| pure-data only      | pure-data only        | `self/async_runtime.hexa` not wired |

---

## 3. Canonical semantics for stage 1

### 3.1 Decision

**Stage 1 async is purely a typing / annotation surface.** Every async fn runs to completion synchronously on the calling task; every `await` is identity. There is no scheduler, no preemption, no concurrent execution at the language level. Concurrency, when needed, is provided by:
- `stdlib/channel.hexa` (mkfifo IPC across `exec()` boundaries),
- `hexa_exec_stream_async_impl` in `runtime.c` (OS-level non-blocking subprocess).

This matches what the interpreter already does and what `self/async_runtime.hexa`'s comments call "single-threaded green-thread model where no thread is actually created".

### 3.2 Canonical rules

1. `async fn f(...) -> T { body }` is callable as `f(...)`. The result is `T`, not `Future<T>`. There is no boxing at the call site.
2. `await x` evaluates `x` and returns its value. If `x` is a `Future` struct (legacy interp shape), the `.value` field is unwrapped; otherwise identity.
3. `spawn { body }` evaluates `body` in a nested block synchronously on the calling task. It does **not** produce a handle. (`SpawnStmt` → C `{ … }` per `codegen_c2.hexa:2158`.)
4. There is no observable concurrency between two `async fn` invocations. Ordering is the same as for two `fn` invocations.
5. Cancellation is **cooperative-poll only**, via the Token type from `stdlib/cancel.hexa` (G3, this RFC §6). The runtime never injects cancellation.
6. Errors propagate through `async fn` and `await` exactly as they do through `fn` and identity expressions. There is no error-wrapping per RFC-019 §6 (diagnostics RFC governs panic semantics; this RFC does not extend them).

### 3.3 Why this is safe for wilson

Wilson's port targets a stage-1 reach window. The semantics above are **trivially provable** because they degenerate to the synchronous baseline. wilson can write `async fn` everywhere it intends to await later, ship today against the synchronous identity, and not change any source line when stage 2 lights up real concurrency.

---

## 4. Divergences and reconciliation

### 4.1 Divergence inventory

| ID  | Surface                  | Interp                           | Codegen (C)                     | Severity | Decision |
|-----|--------------------------|----------------------------------|----------------------------------|----------|----------|
| D1  | `await Future{value:..}` | unwraps `.value`                 | identity (no unwrap)             | **HIGH** | Codegen must add the unwrap. See §4.2. |
| D2  | `await x` general        | identity                         | identity                         | none     | matches |
| D3  | `async fn` body          | runs sync                        | runs sync                        | none     | matches |
| D4  | `spawn { body }`         | runs sync inline                 | emits `{ … }` block              | none     | matches (`codegen_c2.hexa:2156`) |
| D5  | `AwaitExpr` AST shape    | reachable via NK_AWAIT_EXPR (44) | unreachable (no codegen branch)  | medium   | parser does not emit explicit AwaitExpr today; **deferred to stage 2** when explicit Await production lands. Until then, `await` is parsed inside expressions that route through the unary path. |
| D6  | `Scheduler` / `Task`     | data-only, no eval hook          | data-only, no codegen hook       | none     | matches; pattern library status frozen |

The biggest divergence is **D1** — and only D1 is an actual semantic gap. Everything else is matched-by-coincidence (both backends ignore the keyword) or matched-by-design.

### 4.2 Reconciliation strategy

**Fix D1 in codegen, not in interp.** The interpreter is the canonical reference; the native compiler must catch up.

Concrete impact on `self/codegen_c2.hexa`:
1. Add a `gen2_expr` branch for `AwaitExpr` / `Await` node kinds that:
   - emits the inner expression,
   - wraps the result in a runtime call `hexa_await_unwrap(v)` that mirrors interp lines 8029–8038 — checks the `TAG_STRUCT` + `struct_name == "Future"` case and extracts `value`, else identity.
2. Add the runtime helper to `self/runtime.c` with the same shape as the existing `hexa_*` HexaVal helpers.
3. Optional: emit a no-op marker comment `/* await */` for diagnostic readability.

**Why not move interp instead**: the interp's behaviour is older, has callers in `_smoke_exec_stream_async.hexa`, and matches the stage-2 eventual semantics (await unwraps; identity is the "already-resolved" optimisation). Removing the unwrap from interp would silently break programs that currently observe `Future`.

### 4.3 Parser obligation (D5, deferred)

When stage 2 needs real `AwaitExpr` AST nodes, the parser must:
- recognise `await` as a unary prefix (precedence: same as `!`),
- emit `{ "kind": "AwaitExpr", "expr": <inner>, ... }`,
- guard against `await` outside `async fn` (lint warning, not error, in stage 1).

Tracked as an out-of-band parser TODO; not blocking wilson.

### 4.4 Lower / IR (RFC-018 §2 pipeline)

- HIR: introduce an `AwaitOp(value)` node. Lowers to `IdentityOp(value)` in stage 1 (no scheduler).
- MIR: `AwaitOp` is a pseudo-op; SSA passes treat it as identity.
- LIR: `AwaitOp` disappears in lowering.

This keeps the future-stage-2 hook in place without altering generated code today.

---

## 5. wilson surface contract

wilson may rely on:
1. `async fn f(...) -> T` as a callable returning `T`.
2. `await x` returning `x` (or `x.value` if `x` is a stage-1 `Future` struct).
3. Cooperative cancellation through `stdlib/cancel.hexa` (see §6) — the only blessed cancellation surface.
4. mkfifo channels (`stdlib/channel.hexa`) for real cross-process IPC.

wilson must **not** rely on:
- Any observable interleaving between two async fn calls.
- `spawn` producing a handle.
- `select` working as a multi-event wait (the keyword is reserved, no production runs).
- `Scheduler` / `Task` from `self/async_runtime.hexa` having runtime effect.

---

## 6. G3 integration — `stdlib/cancel.hexa`

### 6.1 Type

```
pub struct Token { canceled: bool, reason: string }
```

### 6.2 Surface

| fn | semantic |
|----|----------|
| `token_new()` | fresh, alive, reason="" |
| `token_new_canceled(reason)` | preset canceled (empty reason → "preset") |
| `token_cancel(t, reason)` | monotonic flip; first reason wins; empty → "canceled" |
| `token_check(t)` | true while alive (idiom: `while token_check(t) { ... }`) |
| `token_is_canceled(t)` | inverse of token_check |
| `token_reason(t)` | "" while alive, sticky non-empty after cancel |
| `token_throw_if_canceled(t)` | panic("canceled: <reason>") if set, else no-op |

### 6.3 Idiom for await-in-loop (canonical)

```
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

The scheduler does **not** auto-cancel anything. A task that never polls is never canceled. This matches stage 1's single-threaded eval — preemption is impossible by construction.

### 6.4 Threading note

Stage 1 is single-threaded; there is no race between `token_cancel(t, ...)` from "another task" and `token_check(t)` in the loop, because there is no other task. Cancellation in stage 1 means: the *same* call stack, deeper down, decides to cancel a Token that an outer loop is polling — for example, a budget enforcer, a sigint handler shim, or a parent caller that received an EOF on a channel.

When stage 2 introduces a real scheduler, Token's monotonic-flip semantics generalise to atomic compare-and-swap; the API does not change.

### 6.5 Selftest

`stdlib/test/test_cancel.hexa` — 23 assertions across:
- fresh-token state (3),
- cancel flip (3),
- monotonic / first-reason-wins (2),
- empty-reason normalisation (2),
- preset constructor (3),
- check-polarity (2),
- is_canceled inverse (2),
- reason sticky (2),
- concurrent-poll loop pattern (4).

Run: `$HOME/.hx/bin/hexa_real run stdlib/test/test_cancel.hexa` → `PASS: stdlib/cancel selftest 23/23`.

---

## 7. Open questions (do not block wilson)

- **OQ-1**: Should `async fn` participate in an effect row once effects ship? Tentative: yes, as `Async` effect; deferred.
- **OQ-2**: Should `Token` carry a parent / hierarchy field so a parent's cancel cascades to children? Probably yes in stage 2; intentionally **not** in stage 1 to keep the type one-byte-equivalent.
- **OQ-3**: Should `select` over (channel, timeout, future) become a first-class statement? Reserved keyword today; production deferred to stage 2 alongside real scheduler.

---

## 8. References

- `self/async_runtime.hexa` (cooperative scheduler pattern library, 349 LOC)
- `self/hexa_full.hexa:8029-8038` (interp Await = identity + Future unwrap)
- `self/codegen_c2.hexa:6485` (AsyncFnDecl ≡ FnDecl in C emit)
- `self/codegen_c2.hexa:2156-2169` (SpawnStmt = nested C block)
- `self/runtime.c:8835+` (exec_stream_async — OS-level async via popen)
- `stdlib/channel.hexa` (mkfifo IPC)
- `stdlib/cancel.hexa` (G3 — this RFC §6)
- `proposals/rfc_018_native_codegen_spec.md` (compile pipeline)
- `proposals/rfc_021_daemon_mode.md` (daemon as L3 in fork-storm ladder)
- `incoming/PATCHES.yaml#wilson-pi-port-6-gap-prereq` (downstream consumer entry)

---

## 9. Decision log

- 2026-05-10 — Draft authored. Decision: stage 1 async is annotation-only; canonical semantics are interp's identity-await + Future-unwrap. Native codegen must catch up on the Future-unwrap path (D1) before any stage 2 scheduler work begins. wilson core port unblocks on G1 + G2 + G3 landing — this RFC supplies G2.
- 2026-05-10 (PM) — v1 integration landed. D1 closed in codegen + runtime + interp. D5 parser production added (was deferred). New selftest `self/test_async_codegen.hexa` 4/4 PASS on both backends. wilson core gate (G1+G2+G3) cleared. See §10.

---

## 10. v1 integration (2026-05-10 PM)

This section records the concrete tree changes that lift the RFC from
"design-only" to "integrated".

### 10.1 Tree changes

| File | Change |
|---|---|
| `self/runtime.c` | New helper `hexa_await_unwrap(HexaVal v)` — checks `hexa_is_type(v, "Future")`, extracts `value` via `hexa_map_get`, falls back to identity. Mirrors interp lines 8064-8079 byte-for-byte semantics. |
| `self/codegen_c2.hexa` | New `gen2_expr` branch: `k == "Await" \|\| k == "AwaitExpr"` → `"hexa_await_unwrap(" + gen2_expr(node.expr) + ")"`. AsyncFnDecl program-level routing added (treated identically to FnDecl per §3.1 / §4.1 D3). |
| `self/native/hexa_cc.c` | Hand-mirrored equivalents of the codegen_c2 + parser branches — slot allocations, IC slots, AwaitExpr emit, AsyncFnDecl program-level routing. Required because hexa_cc.c is the deployed transpiler binary's source. |
| `self/parser.hexa`, `self/hexa_full.hexa` | New `parse_unary` branch: when `peek == "Await"`, advance + recurse and emit `{kind: "AwaitExpr", expr: <inner>}`. Closes D5 (was "deferred to stage 2") so the codegen branches actually fire. |
| `self/hexa_full.hexa` (eval) | Await branch hardened to use the same host-level field-map indexing as NK_FIELD eval (line 7714). The pre-existing `map_get(fields, val_str("value"))` form errored on host-level `#{}` maps; the v1 path uses `fields["value"]`. |
| `stdlib/future.hexa` | NEW — canonical `Future` struct shape + `future_resolve / future_pending / future_error` constructors. ~95 LOC. |
| `self/test_async_codegen.hexa` | NEW selftest — 4 cases (pure-sync await, Future-wrap, nested await, non-Future identity). Passes 4/4 on both interp and native AOT. |

### 10.2 Closed divergences

- **D1** (HIGH severity): native codegen now emits `hexa_await_unwrap()` for every AwaitExpr; runtime helper performs the Future-shape check and value extraction. **Closed.**
- **D5** (medium): parser now emits explicit AwaitExpr nodes for `await <expr>`. NK_AWAIT_EXPR eval branch reachable from user source. **Closed (was "deferred to stage 2"; brought forward to stage 1 because the eval branch was effectively dead without it).**

### 10.3 Selftest results (2026-05-10 PM)

| Test | Interp | Native AOT |
|---|---|---|
| `01_pure_sync_await` (`await id_async(42)`) | PASS (42) | PASS (42) |
| `02_future_wrap_await` (Future-wrapped int) | PASS (7) | PASS (7) |
| `03_nested_await` (`await await Future(Future(99))`) | PASS (99) | PASS (99) |
| `04_non_future_identity` (`await 42`) | PASS (42) | PASS (42) |
| `stdlib/test/test_cancel.hexa` (regression) | 23/23 PASS | n/a |
| `self/test_enum_payload_full.hexa` (regression, G1) | 15/15 PASS | n/a |
| `stdlib/test/test_channel.hexa` (regression) | 21/21 PASS | n/a |
| `stdlib/test/test_json.hexa` (regression) | 22/22 PASS | n/a |
| `stdlib/test/test_parse.hexa` (regression) | 24/24 PASS | n/a |
| `stdlib/test/test_yaml.hexa` (regression) | 27/27 PASS | n/a |

### 10.4 Stage-0 rebuild note

The pre-batch deployed `~/.hx/bin/hexa_real` Mach-O binary cannot exercise the new `await` parser production until rebuilt — `await x` parses as a syntax error there. After `tool/build_interp.hexa` runs (or anyone re-compiles `self/native/hexa_cc.c`), the new parser/codegen/eval branches all light up. The verification above used a freshly-built interp + transpiler from the worktree's source tree.

### 10.5 Stage-2 hooks left in place

- HIR/MIR `AwaitOp` lowering (RFC-022 §4.4) — still pending, but the codegen branch is now the natural place to redirect once the IR layer comes online.
- Real `Future` carrying a producer-task handle (vs. stage-1 resolved-value flat record) — `stdlib/future.hexa` API is shape-stable; only the field set may grow.
- `select` / `Scheduler` / `Task` — still pure-data per §2.4. wilson does not depend on these.
