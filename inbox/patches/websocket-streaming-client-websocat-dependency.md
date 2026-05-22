# `stdlib/websocket.hexa` — streaming WS client has a hard `websocat` dependency

**Reporter**: anima (`dancinlab/anima` downstream consumer)
**Severity**: medium (HTTP-poll workaround exists for poll-able peers; no workaround for genuine push-only streams)
**Affected**: `stdlib/websocket.hexa` — `ws_connect` / `ws_recv` (streaming client path)

## Symptom

`stdlib/websocket.hexa`'s streaming client (`ws_connect` + `ws_recv`, persistent
connection that holds the socket open and yields frames as they arrive) is
implemented by shelling out to the external `websocat` binary. When `websocat`
is not installed on the host, the only fallback is a `python3` one-shot — which
sends/receives a single frame and exits. A one-shot cannot hold a stream open,
so **a persistent WS *subscriber* (connect once, receive a live event feed) is
impossible on a host without `websocat`**.

## Where it bit anima

anima needed a hexa-native daemon (`HEXAD/CHAT/server/kosmos_emitter.hexa`) to
subscribe to the chat broker's WebSocket feed and emit a `.kosmos` anchor per
live anima emission. The broker pushes `{"type":"msg",...}` frames; a WS
subscriber is the natural transport. Host has no `websocat` → the daemon could
not hold the stream.

**anima-side resolution (not a fix — a transport switch):** the daemon polls the
broker's `GET /history` HTTP endpoint via `stdlib/net/http_client.hexa` and
dedups by the broker-assigned message `id`. This works only because the broker
*happens* to also expose an HTTP history endpoint. A push-only WS server with no
HTTP mirror would have left no path at all.

## Suggested fix (at source)

A self-contained hexa-native WS client — no external-binary dependency — so
`ws_connect`/`ws_recv` work on any host. Options, roughly in order of effort:

1. **Native WS client over `stdlib/net`** — RFC 6455 handshake (HTTP Upgrade +
   `Sec-WebSocket-Key`/`Accept` sha1) + frame codec (FIN/opcode/mask/len parse,
   client-frame masking) on top of the existing `stdlib/net` TCP socket. This is
   the canonical fix — the WS protocol is small and the codec is ~200 lines.
2. **Bundle / auto-install `websocat`** — keep the shell-out but make `hx`
   provision `websocat` so the dependency is never missing. Weaker (still an
   external process per connection).
3. At minimum, **`ws_supports_streaming() -> bool`** so callers can detect the
   degraded state and pick a transport deliberately, instead of discovering
   mid-build that the stream silently can't hold open.

(1) is the real fix and removes the footgun for every downstream WS consumer.

## Cross-link (anima side)

- `dancinlab/anima` PR #117 — `kosmos_emitter.hexa` (the HTTP-poll daemon).
- `dancinlab/anima` `HEXAD/KOSMOS.log.md` — transport-decision entry.

## honest C3

- The HTTP-poll workaround is functionally complete for anima's current need
  (the broker has `/history`); this patch is about removing the gap for the
  general case, not unblocking anima.
- `websocat`-present hosts are unaffected — the streaming client works there.
- Severity is medium, not high: poll-able peers have a path; only true
  push-only WS servers are hard-blocked.
