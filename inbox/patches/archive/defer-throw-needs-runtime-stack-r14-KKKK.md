# PROBE r14-KKKK — `defer` does not fire on `throw` unwind (needs runtime defer stack first)

> **Status: resolved-by-PR#559 + resolved-by-PR#570 (2026-05-25)** — 본 인보 패치는
> "현재 `defer` 모델에서는 surgical fix 불가" blocker finding + Option A/B/C 스케치
> 단계로 회부됐고, 그 자체는 **PR #559** (`490d8069`, 2026-05-23, `inbox(patches):
> defer-throw needs runtime defer stack first (PROBE r14-KKKK)`) 로 main 에 랜딩됨.
>
> 후속 5-PR stacked landing design RFC 는 **PR #570** (`3b408eb4`, 2026-05-23,
> `inbox(patches): runtime defer stack design RFC (PROBE r14-SSSS, KKKK follow-up)`)
> 로 별도 랜딩 — `inbox/patches/runtime-defer-stack-design-rfc.md` 에 5-PR plan
> (closure-conversion → runtime registry → `hexa_throw` wiring → defer emission
> switch → flag-path retire) 이 명시됨.
>
> 실제 runtime defer stack 구현 (`HexaDeferEntry` struct + `hexa_defer_push/pop/
> drain_to_try_frame` + closure-conversion codegen) 은 위 RFC 의 multi-PR cycle 에서
> 별도 진행 예정 — 본 blocker probe 자체는 "design 단계 완료" 로 closed.
>
> 따라서 이 파일은 inbox triage 큐에서 빠지고 archive/ 로 이동. 재발견 시 위 두
> PR + design RFC 를 먼저 확인할 것.
>
> **Original Status**: surgical fix NOT POSSIBLE in current `defer` model

**Date**: 2026-05-24
**PROBE**: r14 cycle 12 (cycle 11 retried after disk-clean)
**Kind**: patches → STOP / blocker — needs prior architectural change
**Status**: resolved-by-PR#559 + resolved-by-PR#570 — 2026-05-25 (archived)

## Probe

```hexa
fn risky() {
    defer { print("cleanup-1") }
    defer { print("cleanup-2") }
    throw "boom"
    print("unreachable")
}

fn main() {
    try {
        risky()
    } catch (e) {
        print("caught:", e)
    }
}
```

### Expected (Go / Swift canonical LIFO defer-on-throw)

```
cleanup-2
cleanup-1
caught: boom
```

### Today

```
caught: boom
```

Defers silently skipped on `throw`.

## Root cause — current `defer` model is C-static, not runtime-tracked

Per FFFF (PR #534) Phase 3 codegen at `self/codegen.hexa:1784-1951` (today: `1790-1948`):

For each fn, codegen counts defers at fn-entry and pre-declares per-fn C locals:

```c
HexaVal __ret_val = hexa_void();
int __defer_0_active = 0;
int __defer_1_active = 0;
```

Each `defer { … }` statement codegens as a single flag flip:

```c
__defer_0_active = 1;
__defer_1_active = 1;
```

Drain is emitted at the synthesized `__fn_exit:` label at the END of the fn:

```c
goto __fn_exit;
__fn_exit:;
    if (__defer_1_active) { /* body */ }
    if (__defer_0_active) { /* body */ }
    return __hexa_fn_arena_return(__ret_val);
```

`ReturnStmt` is rewritten to `__ret_val = …; goto __fn_exit;` so explicit returns also drain.
Implicit tail-return is rewritten the same way.

### Generated C for the probe (verbatim, abridged)

```c
HexaVal __ret_val = hexa_void();
int __defer_0_active = 0;
int __defer_1_active = 0;
__defer_0_active = 1;
__defer_1_active = 1;
hexa_throw(__hexa_sl_0);       /* ← longjmp here, frame dies */
(hexa_print_val(__hexa_sl_1), hexa_void());
goto __fn_exit;
__fn_exit:;
    if (__defer_1_active) { … }
    if (__defer_0_active) { … }
```

`hexa_throw` (`self/runtime_core.c:5445`) calls `longjmp(*__hexa_try_stack[…], 1)`. The `longjmp` unwinds straight to the nearest `setjmp` in the caller's `try` block — `risky`'s stack frame is torn down, the `__defer_N_active` locals die with it, and `__fn_exit:` is **never reached**.

### Confirmed zero runtime defer infrastructure

```
$ grep -n -i 'defer' self/runtime_core.c | head
3324:// hexa_full.hexa edits + interp rebuild, deferred per task description).
3776:// `__builtin_memcpy_inline`. Defer to a cycle that touches the source
```

(Both hits are unrelated comments — "deferred to a cycle"; not the `defer` keyword.)

So a one-line surgical `hexa_defer_drain_to_catch()` call inside `hexa_throw` has nothing to drain — there is no runtime registry of pending defers.

## Why the cycle-12 spec's "surgical" path is closed

The task spec offered two paths:

1. Runtime-stack model already exists → add a helper + wire into `hexa_throw`. **NOT THE CASE.**
2. Static-only → STOP + file inbox.

This is case 2.

## What the fix needs (next cycle's design RFC)

### Option A — runtime defer stack (Go's approach, condensed)

Add a per-thread (or per-fiber) defer registry to `self/runtime_core.c`:

```c
typedef struct HexaDeferEntry {
    void (*body)(void*);         /* closure ptr */
    void* env;                   /* captured locals (boxed) */
    int try_frame_depth;         /* __hexa_try_top at registration */
    int fn_frame_id;             /* monotonic per-fn counter */
    struct HexaDeferEntry* prev;
} HexaDeferEntry;

static __thread HexaDeferEntry* g_defer_top = NULL;

void hexa_defer_push(void (*body)(void*), void* env);
void hexa_defer_pop_one(void);                /* normal fn-exit drain */
void hexa_defer_drain_to_try_frame(int saved); /* hexa_throw helper */
```

`hexa_throw`:

```c
void hexa_throw(HexaVal err) {
    __hexa_error_val = err;
    if (__hexa_try_top > 0) {
        int target = __hexa_try_top - 1;
        hexa_defer_drain_to_try_frame(target);  /* NEW */
        __hexa_try_top--;
        longjmp(*__hexa_try_stack[target], 1);
    }
    /* uncaught — drain ALL pending defers before exit(1) */
    hexa_defer_drain_to_try_frame(0);
    /* … existing fprintf + exit … */
}
```

Codegen changes (`self/codegen.hexa`):

- At each `defer { … }` statement, emit `hexa_defer_push(&__defer_thunk_<N>, &__defer_env_<N>);` (no flag flip — the runtime stack tracks activation by physical presence).
- Lift each defer body into a static `void __defer_thunk_<N>(void* env_raw)` adjacent to the host fn.
- Capture locals into a heap-allocated env struct (closure conversion — `self/codegen.hexa` already has the boxed-cell machinery for `_gen2_boxed_cells`; extend to defer-body free-var capture).
- At `__fn_exit:`, pop+fire exactly `_gen2_defer_flag_count` entries (LIFO) — no flag check, the runtime stack IS the activation record.

Scope: ~150-250 LOC across runtime_core.c + codegen.hexa. Closure conversion is the bulk — defer bodies referencing fn locals must heap-promote them.

### Option B — try-frame scoped goto (simpler, doesn't fully match Go semantics)

When `hexa_throw` is called from a fn that has registered defers AND is between a defer-registration and the nearest `try` frame, somehow `goto __fn_exit` instead of `longjmp`. Requires statically proving the `throw` is local-fn (not from a callee like the probe — `throw` is inside `risky`, but if `risky` called `inner()` which throws, the same problem reappears one level deeper). **Rejects the cycle-11 use case** (throw mid-fn AFTER defer registration but BEFORE return) only partially; nested-callee throws still leak. **Not recommended.**

### Option C — setjmp at each defer site

Each `defer` registers its own `setjmp` chain. Cost: O(defer-count × try-depth) longjmp targets. Pathological for hot paths. **Reject.**

## Recommendation

**Option A.** Next probe cycle (suggest r14-KKKK-2 or rfc_NNN_defer_runtime_stack):

1. Land closure-conversion for defer bodies first (codegen.hexa).
2. Land runtime defer registry + `hexa_defer_drain_to_try_frame` (runtime_core.c).
3. Wire into `hexa_throw`.
4. Re-emit defers as `hexa_defer_push(thunk, env)` instead of flag flips.
5. Keep `__defer_N_active` flag emission path behind a feature flag for one release for byte-eq audit, then drop.

Test corpus: probe r14-KKKK above + nested-callee-throw + multi-level try/catch + early-return-without-throw (existing FFFF tests must remain green).

## Out of scope this cycle

- Surgical 1-line `hexa_throw` patch — has nothing to drain in current model.
- Defer infrastructure overhaul — exceeds <200-line g4 budget for a single PR; needs design RFC + multi-PR landing.

## Provenance

- PROBE.md r14 cycle 12 (cycle 11 retried after disk-full at worktree-create)
- Sibling: PR #534 (r14-FFFF defer pattern RFC, defer keyword + parser + Plan B Phase 3 codegen)
- DUP-PRECHECK: `gh pr list --search "defer throw"` → none open · `git log origin/main --since='2026-05-22'` → no defer-throw work landed
- Disk check: 35 GB free (cleared)
- Defer model location: `self/codegen.hexa:1790-1948` · `self/runtime_core.c:5445` (hexa_throw)
- Runtime defer infra: NONE (`grep -i defer self/runtime_core.c` → 2 unrelated hits)

## Files touched (planned in follow-up cycle)

- `self/runtime_core.c` — add HexaDeferEntry struct, push/pop/drain, wire into hexa_throw (~80 LOC)
- `self/codegen.hexa` — emit defer thunks + env struct + push/pop instead of flag flips, defer-body closure conversion (~120 LOC)
- `self/native/hexa_v2` — regen (~10 KB, mechanical)

— probed by sub-agent on `probe-r14-KKKK-defer-throw-needs-runtime-stack-2026-05-24`
