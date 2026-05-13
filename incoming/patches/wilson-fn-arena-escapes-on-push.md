# Codegen: `hexa_fn_arena_return` frees a value that was pushed into the caller's array (use-after-free)

**Filed by:** wilson (`~/core/wilson`). Reproduced from wilson's tool-call multi-turn
flow (`provider-claude-cli` → `agent_loop` → `harness_cli_append_tool_results` →
`harness_cli_persist`'s `transcript_to_jsonl` iteration). Minimal hexa-lang repro
below — 21 lines, no wilson deps.

**Date:** 2026-05-13.
**Severity:** wilson can't do multi-turn tool calls. Segfaults on iterating `[Message]`
right after a function-mediated push, even in print mode (`wilson -p "X"` works only
because it does a single host_run_turn → no second iteration). User-facing crash:
`zsh: segmentation fault  ws` immediately after `[✓ web_search]` chip in the TUI.

## Symptom

The compiled binary (clang from `hexa build`) segfaults when a function-mediated
`array.push(<struct literal>)` is followed by indexed field access on the pushed
entry from the caller. **The interpreter (`hexa run`) is fine** — only the C codegen
path is affected.

## Minimal repro (21 lines)

```hexa
// /tmp/wilson-repro13.hexa
struct ToolCall { id: string, name: string, args_json: string }
struct Message  { role: string, content: string, tool_calls: [ToolCall], tool_call_id: string }

fn push_tool(msgs: [Message]) -> void {
    msgs.push(Message { role: "tool", content: "TR", tool_calls: [], tool_call_id: "" })
}

fn main() -> int {
    let mut msgs: [Message] = []
    msgs.push(Message { role: "user", content: "q", tool_calls: [], tool_call_id: "" })
    msgs.push(Message { role: "assistant", content: "a", tool_calls: [], tool_call_id: "" })
    push_tool(msgs)
    let mut i = 0
    while i < len(msgs) {
        let m = msgs[i]
        println("i=" + str(i) + " role=" + m.role)
        i = i + 1
    }
    return 0
}
```

```sh
$ hexa run  /tmp/wilson-repro13.hexa     # OK — prints all three rows + exit 0
$ hexa build /tmp/wilson-repro13.hexa -o /tmp/r ; /tmp/r
i=0 role=user
i=1 role=assistant
zsh: segmentation fault  /tmp/r
$ echo $?
139
```

Inline equivalent — drop the `push_tool` indirection and push from `main` directly —
**does NOT crash**. Only the function-mediated push triggers it.

## Root cause (generated C)

`hexa build`'s emitted C for the repro:

```c
HexaVal push_tool(HexaVal msgs) {
    __hexa_fn_arena_enter();                                           // (1)
    hexa_array_push(msgs, Message(__hexa_sl_0, __hexa_sl_1,            // (2)
                                  hexa_array_new(), __hexa_sl_2));
    return __hexa_fn_arena_return(hexa_void());                        // (3)
}

HexaVal u_main(void) {
    __hexa_fn_arena_enter();
    HexaVal msgs = hexa_array_new();
    hexa_array_push(msgs, Message(...));   /* inline push 1 — survives */
    hexa_array_push(msgs, Message(...));   /* inline push 2 — survives */
    push_tool(msgs);                       /* fn push — UAF on entry 2 */
    /* iterate msgs ... */
    HexaVal m = hexa_index_get(msgs, i);   /* i=2: dereferences freed map */
    hexa_map_get_ic(m, "role", ...);       /* SEGV */
}
```

Walkthrough:

1. `push_tool` enters its own arena.
2. `Message(...)` is the struct constructor — calls `hexa_struct_pack_map("Message",
   4, _k, _v)` which allocates the field-name array + value array + the map itself.
   **All of these allocate into the current arena (push_tool's arena).**
   `hexa_array_push(msgs, ...)` copies the *handle* into `msgs` (an array that lives
   in `u_main`'s arena), but the underlying map storage stays in `push_tool`'s arena.
3. `__hexa_fn_arena_return(hexa_void())` frees `push_tool`'s arena. The Message map
   at `msgs[2]` is now a dangling pointer.

`u_main` keeps iterating. `hexa_index_get(msgs, 2)` returns the dangling map handle.
`hexa_map_get_ic(m, "role", ...)` dereferences freed memory → SIGSEGV.

The inline pushes (`hexa_array_push` from `u_main` directly) work because both the
array AND the map are allocated in `u_main`'s arena — they share the same lifetime.

## What the fix needs to do

The compiler / runtime needs to detect that a value built inside a fn-arena escaped
into a caller-owned container, and either:

**A. Promote escaping values out of the callee's arena before arena_return.**
On `hexa_array_push(callee_arena_value, ...)` where the target array isn't in the
callee's arena, deep-copy the pushed value into the heap (or the target array's
arena). Tracking "which arena does this HexaVal live in" — every arena-allocated
HexaVal could carry an arena tag in its header.

**B. Detect "value escapes the fn arena" statically and switch its allocator.**
At the codegen layer, when a struct literal is the argument to a call that stores
it into a caller-owned reference (push, map set, struct field assign…), emit
`hexa_struct_pack_map_heap(...)` instead of the arena-bound `hexa_struct_pack_map`.
Cheaper than runtime promotion. Requires the call-graph to know which args escape.

**C. Reference-count + arena retain.**
On `hexa_array_push(arr, v)`, if v is arena-bound and `arr` is heap-bound (or in a
different arena), retain v's arena and defer its free until v is dropped. Simpler
than promotion but leaks arena lifetimes upward.

**D. Conservative: don't use fn-arenas for `void`-returning fns that contain a
`hexa_array_push(arg, …)` or `hexa_map_set(arg, …, …)`.** The codegen pass that
decides to emit `__hexa_fn_arena_enter()` should check if any push/set targets a
parameter, and if so skip the arena. Loses the arena perf win for those fns but
trivial to implement and correct.

Pick D first (one-line change in the codegen pass — see `self/build_c.hexa`'s arena
emission), then iterate to A/B/C for the real perf-recovery work.

## Status — APPLIED (2026-05-13)

Fix landed in `self/runtime.c::hexa_array_push` — option **A (runtime promotion)**:

```c
// FIX 2026-05-13 (wilson-fn-arena-escapes-on-push): when pushing into an
// array whose item buffer lives on the heap (cap >= 0), and we're inside a
// live fn-arena scope (mark_top > 0), the item being pushed may have been
// allocated in the *current* fn's arena and will be freed on
// __hexa_fn_arena_return — leaving a dangling handle in the heap array. Run
// heapify on the item so its underlying storage is promoted to the heap
// before insertion. Arena-resident arrays (cap < 0) share the callee's
// lifetime by construction and don't need this.
if (HX_ARR_CAP(arr) >= 0 && __hexa_val_mark_top > 0) {
    item = hexa_val_heapify(item);
}
```

Plus a forward declaration of `hexa_val_heapify` near the existing arena forward
decls (the real impl was further down the file). Repro13 + wilson's `test --e2e`
both pass; the wilson-side workaround (rejected) was not needed.

Perf note: heapify is per-push but only when both conditions hold (heap-resident
array AND live arena). Cold path for most code; the perf-recovery options B/C
(static escape analysis or refcount+retain) remain on the table if benchmarks
later show the runtime check is hot.

## Related artefacts (in this session)

- Wilson e2e test that reproduces: `~/core/wilson/tests/e2e_tool_call.sh` — spawns
  wilson under tmux, sends a search query, watches `tmux has-session` go to 0 on
  segfault, exits 1.
- Wilson session repro flow (raw-mode TUI): `ws` → "search for KAIST 2026" → claude
  emits `<wilson_call name="web_search">…</wilson_call>` → wilson runs web_search →
  `harness_cli_append_tool_results` pushes role="tool" Message → next paint /
  persist iter on msgs[2] → SEGV.
- Trace evidence (`/tmp/wilson-trace.log`) — agent_loop returns cleanly, persist
  enters, jsonl serialiser reads `msgs[0]` and `msgs[1]` OK, then `let m = msgs[2]
  ; m.role` faults.
- Minimal repro file at top of this doc + variants at `/tmp/wilson-repro{1..13}.hexa`
  showing direct-push works, fn-push fails.

넣었다.
