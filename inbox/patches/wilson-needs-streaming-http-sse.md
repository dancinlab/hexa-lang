# incoming patch: wilson-needs-streaming-http-sse

> **id**: `wilson-needs-streaming-http-sse` · **opened**: 2026-05-10 · **status**: `resolved-ssot` (2026-05-20 — dup-race; SSOT already present and exceeds ask)
> **trees**: `stdlib/http_sse.hexa` (646 LoC) + `stdlib/test/test_http_sse.hexa` (246 LoC)
> **priority**: ★★ — closed as no-op; SSOT predated the filing.

---

## Resolution (2026-05-20)

Dup-race precheck found the requested module **already landed** before the
filing's "It does not exist" diagnostic was true. Timeline:

| date       | commit       | scope                                                        |
| ---------- | ------------ | ------------------------------------------------------------ |
| 2026-05-08 | `4761f048`   | `stdlib/http_sse.hexa` v1.0.0 — GET callback + handle API    |
| 2026-05-10 | —            | this filing opened (wilson grep missed canonical stdlib)     |
| 2026-05-11 | `faca4134`   | v1.1 — `http_sse_post` + `http_sse_open_post` (POST + body)  |
| —          | `d8b44ccf`   | v1.1 follow-up — `http_sse_post_buffered` (interp fallback)  |
| —          | `6fdd9847`   | SPEC.yaml HX1042 + honest-C3 #6 refresh                      |

`stdlib/http_sse.hexa` exposes exactly the surface the filing asks for
(@capabilities header, lines 7 / 46-66 / 173-505):

- callback: `http_sse_get(url, headers, on_event, timeout_sec)`
- callback (raw): `http_sse_get_lines(url, headers, on_line, timeout_sec)`
- buffered fallback: `http_sse_get_buffered(...)` + `http_sse_post_buffered(...)`
- handle GET: `http_sse_open / http_sse_next / http_sse_close`
- handle POST: `http_sse_open_post(url, headers, body, timeout_sec)`
- handle generic: `http_sse_open_method(url, headers, method, body, timeout_sec)`
- POST callback: `http_sse_post(url, headers, body, on_event, timeout_sec)`
- pure parser: `http_sse_parse_event / http_sse_feed / http_sse_empty_event`
- introspection: `http_sse_available / http_sse_build_curl_cmd / http_sse_build_curl_method_cmd`

Both scope options the filing punted (a vs b) were taken simultaneously:
the module **is** a thin hexa wrapper over `exec_stream_async/poll/close`
(the b-substrate, already in `self/runtime.c`), with `http_sse_get_buffered`
+ `http_sse_post_buffered` providing interp parity per honest-C3 #1. No
`runtime.c` change required for parity — the buffered path uses plain
`exec(curl --max-time N)`.

Wilson side: re-enable `use "stdlib/http_sse"` in
`plugins/provider-anthropic/plugin.hexa` and call the surface as the
filing's "Ask" paragraph already documents. No upstream change pending.

This patch is closed `resolved-ssot` (no code change in this commit; the
land happened in the four commits above).

---

## Original ask (preserved for archive)

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
