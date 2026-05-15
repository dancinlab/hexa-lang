# string `+` in unbounded loop is O(n²) + accumulates arena RSS → 4 GB cap kill

## TL;DR

The same root cause as `tui-input-paste-buf-quadratic.md` (filed earlier) keeps
surfacing in new wilson code paths whenever a hot loop accumulates external
bytes via `out = out + chunk`. This patch request **generalises** the issue
and proposes a language/runtime-level fix so authors stop having to remember
to hand-roll string buffers.

## New reproducer (2026-05-16, wilson)

Sequence:
1. User: launches `ws`, types `test-tui 에 젤상단에 테스트 주석 한줄 추가해줘`.
2. LLM (claude) issues a series of tool-calls: `glob` × 2 → `bash: find ~/core/wilson -iname '*test-tui*' …` → `bash: find ~ -maxdepth 6 -iname '*test-tui*' …`.
3. The last `find ~ -maxdepth 6 …` walks the whole `$HOME` 6 levels deep and emits many thousands of lines.
4. Wilson aborts:
   ```
   [hexa-runtime] memory cap exceeded: rss=4096MB > cap=4096MB
   [hexa-runtime] hint: re-run with --mem-unlimited (or HEXA_MEM_UNLIMITED=1) to disable, or --mem-cap=<MB> to raise.
   ```

## Root cause — wilson `plugins/tool-core/main.hexa:309-348`

```hexa
fn tool_core_invoke_bash_stream(args: any, ctx: any, on_chunk: any) -> ToolResult {
    ...
    let mut out = ""
    let mut done = false
    while done == false {
        ...
        let r = exec_stream_poll(h)
        let d = r[0]
        let line = str(r[1])
        if len(line) > 0 {
            out = out + line + "\n"        // ← O(n²) string concat
            ...
        }
        if d == 1 { done = true }
    }
    ...
    return ToolResult { ok: okrc, content: out, ... }
}
```

For an N-line stream of avg L bytes per line:
- Iteration k allocates a fresh `(k·L)`-byte string in the arena, copies the
  previous accumulator + the new chunk in.
- Total allocation = L·(1 + 2 + … + N) = O(N²·L).
- With `HEXA_STR_ARENA=1` (default since 2026-05), every intermediate goes
  into the bump arena. There is **no rewind point inside the loop** — the
  fn-arena boundary only rewinds when `tool_core_invoke_bash_stream` returns.
- For `find ~ -maxdepth 6` emitting ~80 K lines × ~50 bytes ≈ 4 MB final
  payload, the accumulated transient allocation is ≈ `(80 000)² · 50 / 2` ≈
  **160 GB**. The arena cap (4 GB default) trips before we get there.

## Why this keeps happening (pattern catalogue)

Every place that **accumulates external bytes into one string** in hexa-lang
is structurally the same trap:

| Site | Pattern | Patch |
|---|---|---|
| `self/tui/input.hexa::_decode_in_paste` | per-byte `_paste_buf = _paste_buf + _byte_to_str(b)` | [`tui-input-paste-buf-quadratic.md`](./tui-input-paste-buf-quadratic.md) (earlier) |
| `wilson plugins/tool-core/main.hexa::tool_core_invoke_bash_stream` | per-line `out = out + line + "\n"` | **this report** |
| `wilson plugins/tool-core/main.hexa::tool_core_bash_buffered` | per-line `out = out + str(ln) + "\n"` | same root |
| (likely many user plugins) | any `acc = acc + chunk` in a stream loop | — |

The language **invites** this — `s = s + t` is the most natural way to write
"append to a string." Without a fast string-builder primitive, every author
who writes it sets a quadratic time-bomb that depends on stream length.

## Wilson-side mitigation (landing in parallel)

A surgical wilson-only fix is straightforward: collect lines into an array,
join at the end.

```hexa
let mut chunks: [string] = []
while done == false {
    ...
    if len(line) > 0 {
        chunks.push(line)
        ...
    }
    ...
}
let out = strs_join(chunks, "\n") + (if len(chunks) > 0 { "\n" } else { "" })
```

`strs_join` (stdlib) does a single `O(total_bytes)` allocation. Plus a
sensible output cap (e.g. 1 MB → spill rest to a temp file, summary in
`metadata.spill_path`) addresses the `g16 ToolResult-no-truncation` gap.

That fixes **the symptom for bash output**, but the underlying language
trap is unchanged — the next plugin author who writes `s = s + chunk` in a
loop hits it again.

## Upstream fix sketches (hexa-lang)

### Option A — `strbuf` stdlib primitive (cheapest, most surgical)

Add to `self/stdlib/core/strings.hexa`:

```hexa
type StrBuf  // opaque; runtime owns growth (geometric, like C++ std::string)
fn strbuf_new() -> StrBuf
fn strbuf_push(b: StrBuf, s: string) -> void   // amortised O(|s|)
fn strbuf_finish(b: StrBuf) -> string          // O(total); empties the buf
fn strbuf_len(b: StrBuf) -> int                // for size caps
```

Authors port `acc = acc + chunk` → `strbuf_push(acc, chunk)` and `let out =
strbuf_finish(acc)`. Mechanically obvious. No language change.

### Option B — runtime detection of "monotone tail concat" in arena

In `hexa_str_concat`, when `a` was the result of the *previous*
`hexa_str_concat` and is not aliased elsewhere (refcount == 1 OR a tagged
"builder" flag set), grow `a` in place instead of allocating a new buffer.
This makes the existing `s = s + t` pattern automatically O(amortised |t|).
Bigger runtime change (refcount discipline / new flag bit on string headers),
but it fixes ALL existing call sites at once with no source diff.

### Option C — compile-time lint

Front-end warns on `mut x: string ... x = x + ...` inside a `while`/`for`
loop. Authors get a "use strbuf or array+join" hint. Easiest to ship,
educates the ecosystem, but doesn't help binaries already built (unlike B).

### Recommendation

**A + C** — `strbuf` ships the primitive everyone needs; the lint nudges
existing code to migrate. **B** is the dream but is a non-trivial allocator
change and can be staged later.

## Cross-references

- `tui-input-paste-buf-quadratic.md` — earlier instance, same root cause.
- `wilson plugins/tool-core/main.hexa:332` — new reproducer.
- `self/runtime.c:285` — 4 GB default cap (history: 768 → 2048 → 4096 MB,
  each raise driven by a similar `s = s + t` accumulator hitting the cap).
  This patch series should let us **lower** the default cap again once the
  ecosystem migrates off the quadratic pattern.

## Authority

Wilson governance #7 (`g7 hexa-lang-handoff-protocol`) — wilson is
downstream; structural hexa-lang gaps file here, not fixed in-place.
