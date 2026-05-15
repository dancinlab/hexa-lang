# incoming patch: wilson-needs-streaming-http-sse

> **id**: `wilson-needs-streaming-http-sse` · **opened**: 2026-05-10 · **status**: `pending_external`
> **trees**: `stdlib/` (new module) — possibly `self/runtime.c` (if a streaming-subprocess primitive is the chosen substrate)
> **priority**: ★★ — not a hard blocker (wilson's `provider-anthropic` works *buffered* today), but it's the difference between "the assistant reply appears all at once after N seconds" and "tokens stream as they arrive" — i.e. the streaming-chat UX. Needed before wilson is a pleasant interactive coding agent.

---

## The situation (found while de-STUBbing wilson's `provider-anthropic` plugin, 2026-05-10)

wilson's `docs/hexa-lang-gap-audit.md` claimed `stdlib/http_sse.hexa` exists (v1.0.0, since 2026-05-08: `http_sse_get(url, headers, on_event, timeout)` callback form + `http_sse_open/next/close` handle API + `http_sse_get_buffered` fallback, "curl --no-buffer streaming GET — SSE parser + raw-line generator", from the anima chat Phase-2 streaming substrate). **It does not exist** — a thorough search of `~/core/hexa-lang/stdlib/`, `self/stdlib/`, `stdlib/net/`, and everything under `~/core` finds no such module. (Maybe it lived in a `.claude/worktrees/agent-*/` copy, or was planned-but-not-landed, or was removed in a refactor — whatever; it's not in canonical hexa-lang now.)

What *does* exist for HTTP:
- `stdlib/http.hexa` — header-aware GET helpers. `popen`-buffers.
- `stdlib/http2.hexa` — `http2_post`/`http2_post_status`/`http2_request` — buffered curl POST.
- `self/stdlib/anthropic_sdk.hexa` — `anthropic_send(api_key, body, betas, base_url) -> [ok, body|err]` — does `curl -fsN --max-time 600 -X POST` via `exec_with_status` which **collects the full stdout then returns**, then `anthropic_parse_sse_lines([line])` parses the SSE frames. So even though the wire format is `text/event-stream`, the reply is buffered end-to-end before any of it is visible.

So wilson's `provider-anthropic.stream_open/stream_next/stream_close` are currently wired as "buffered-then-iterate" — `stream_open` does the full `anthropic_send` + parse, `stream_next` walks the pre-parsed event list. Functionally correct (the AsmEvent mapping is real), but no token-by-token streaming.

## Ask

A streaming HTTP client — one of:

**(a) `stdlib/http_sse.hexa`** as the gap-audit described — `curl --no-buffer -N ...` (or `curl -fsN`), exposing both a callback form (`http_sse_get(url, headers, on_line_or_event, timeout)`) and a handle form (`http_sse_open(url, headers, body?, method?, timeout) -> handle`; `http_sse_next(handle) -> line|event|<eof-sentinel>`; `http_sse_close(handle) -> rc`), with the SSE-frame parser (`event:`/`data:`/blank-line-terminates, multi-line `data:`, comments, `\r`) — i.e. exactly the surface wilson's `provider-anthropic` already pretends to call. POST-with-body is required (Anthropic Messages API is POST; OpenAI/etc. too).

**(b) A general streaming-subprocess primitive in `runtime.c`** that wilson (and stdlib) can build on — like `exec_stream_async(cmd) -> int handle` + `exec_stream_poll(handle) -> [done, line]` + `exec_stream_close(handle) -> rc` (which **already exist** in `self/runtime.c`! — `hexa_exec_stream_async`/`poll`/`close`) — **but they're compiled-path only** (the stage0 interpreter doesn't register them; wilson's `tool-core` confirmed this and falls back to `popen` in interp). If those got interpreter parity (or are deemed AOT-only-is-fine since wilson ships compiled), then `stdlib/http_sse` is just a thin hexa wrapper: `exec_stream_async("curl -fsN -X POST ...")` + a per-line SSE parser over `exec_stream_poll`. **This (b) is probably the cleanest** — the primitive is already there, it just needs (i) a confirmation it's stable on the AOT path under a long-lived curl, and optionally (ii) interp registration, and (iii) a `stdlib/http_sse.hexa` hexa-side wrapper composing it with `anthropic_parse_sse_lines`'s frame logic.

Either way: the consumer (wilson `provider-anthropic`) is **already written against the (a) handle surface** — `stream_open` calls something like `http_sse_open(url, headers, body, "POST", 600)`, `stream_next` reads via `http_sse_next`. When this lands, the wilson side change is tiny: re-enable `use "stdlib/http_sse"` in `plugins/provider-anthropic/plugin.hexa`, swap `stream_open`'s `anthropic_send`+parse for `http_sse_open` + incremental `http_sse_next`-driven `anthropic_parse_sse_lines`. The AsmEvent mapping is unaffected.

## Notes

- Also fix `wilson/docs/hexa-lang-gap-audit.md` (wilson side) to stop claiming `http_sse` exists — done in parallel.
- Related: wilson's `tool-core` found `exec_stream_async` etc. are AOT-only (interp falls back to `popen_lines_with_status`) — if the AOT-only contract is intentional, fine (wilson ships compiled); if interp parity is wanted, that's the same item as (b)(ii).
- Reference: `~/core/wilson/docs/build-fix-checklist.md` §A (http_sse row), `~/core/wilson/plugins/provider-anthropic/main.hexa` ("TRANSPORT REALITY" header documents the buffered substitute + exactly what flips when this lands).
