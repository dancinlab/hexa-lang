# incoming note: phanes-stdlib-net-server-serve-idle-socket-deadlock — `server_serve` blocks forever on a connected-but-silent socket; one idle socket starves the whole server

> **id**: `phanes-stdlib-net-server-serve-idle-socket-deadlock` · **opened**: 2026-05-19 KST · **status**: `open — downstream worked around with a phanes-local select() accept loop; upstream server_serve still affected`
> **trees**: `stdlib/net/http_server.hexa` (`server_serve` accept-loop + `server_handle_conn` → `socket_read`) · `stdlib/net/socket.hexa` (`socket_select` / `socket_set_nonblock` — the primitives the fix needs, already landed)
> **source**: downstream `phanes` (`~/core/phanes`, private SaaS; HTTP service `service/http_phanes.hexa`).
> **observed**: 2026-05-19 · hexa-lang pin: `de7b84de` (`rfc043-hexa-torch`)
> **severity**: high — this is a correctness/availability bug, not a throughput one. Any client (or browser) that opens a TCP connection and does not immediately send a request hangs the entire server for every other client. Trivial accidental denial-of-service.
> **relation**: distinct from `phanes-stdlib-net-os-thread-concurrency-roadmap-62.md` (that note = multi-thread *throughput* ceiling, resolved-ssot). This note = a *hang* bug in the single-threaded path. Same `server_serve`, different failure mode.

---

## 1. Observed

`stdlib/net/http_server.hexa`, `server_serve()` accept loop calls
`server_handle_conn()`, which on its first line does:

```
pub fn server_handle_conn(s, conn_fd, dispatch_fn) {
    let raw = socket_read(conn_fd)      // <-- BLOCKS until data arrives
    ...
```

`socket_read` (→ `net_read` → blocking `recv()`) blocks indefinitely
when the peer has `connect()`-ed but sent no bytes. The accept loop is
serial, so while it is blocked inside `socket_read` on one connection it
cannot `accept()` any other connection. **One silent socket freezes the
whole server.**

This is not hypothetical. Browsers do exactly this: Chrome opens
speculative "preconnect" sockets on link hover and only sends the GET
when the user actually clicks. The hexa server `accept()`s the
speculative socket, blocks in `socket_read` waiting for a request that
will not arrive until the click — and meanwhile the real navigation
(often a *different* socket) is starved behind it. The user sees an
infinite page-loading spinner.

## 2. Reproduction (measured, phanes pin de7b84de)

Against a stock `server_serve`-based service:

```
# open a socket, send NOTHING (mimics a Chrome speculative preconnect)
idle = socket.create_connection(('localhost', 8787))

# now issue a real HTTP request on a different socket
GET /phanes  ->  FAIL: timed out after 6.004 s

idle.close()
GET /phanes  ->  200 in 0.003 s        # instant recovery the moment
                                       # the idle socket goes away
```

The correlation is exact: while ≥1 idle socket is held, every request
hangs; the instant the idle socket closes, service resumes in ~3 ms.

## 3. Why it matters

- **Availability**: a single idle/half-open socket — speculative
  browser preconnect, slow client, port scanner, flaky NAT — wedges the
  whole server. No malice required; normal Chrome behaviour triggers it.
- **Every `server_serve` consumer is exposed.** phanes hit it; wilson's
  HTTP surfaces and any other downstream using `stdlib/net/http_server`
  will hit it too.
- The `concurrent_serve.hexa` work-stealing path does not help — it sits
  on the same blocking `net_accept`/`net_read`.

## 4. Suggested resolution (upstream's call)

The primitives already exist — `socket_select` and `socket_set_nonblock`
landed in `stdlib/net/socket.hexa` via the roadmap-62 note (option (a)).
`server_serve` just needs to *use* them: `select()` a freshly-accepted
fd (bounded timeout) before handing it to `server_handle_conn`, and/or
run a select() event loop over `listener + pending conns`. A
connection that stays silent past the timeout is closed instead of
blocking the loop.

The socket.hexa docstring for `socket_select` already sketches this as
"server_serve 대체 후보". This note is the concrete measured case that
motivates finishing that follow-up.

## 5. Downstream reference implementation (works today, drop-in shape)

phanes did **not** patch stdlib (downstream-direct-edit rule, `@D g7`/`@F f3`).
It added a phanes-local `phanes_serve()` that mirrors `server_serve` but
inserts the select() guard, using only the public `socket_select` /
`socket_accept` / `socket_close` primitives + the public
`server_handle_conn`. Shape (see `~/core/phanes/service/http_phanes.hexa`):

```
fn phanes_serve(s, dispatch_fn) {
    let listener = s["listener"]
    let mut running = true
    let mut pend = []      // accepted fds awaiting their first byte
    let mut age  = []      // select ticks each pend fd has waited
    while running {
        if file_exists(s["stop_flag_path"]) { running = false }
        else {
            let mut watch = [listener]
            let mut i = 0
            while i < len(pend) { watch = watch + [pend[i]]; i = i + 1 }
            let ready = socket_select(watch, 1000)   // 1 s tick
            // listener ready -> accept, add to pend
            // pend fd ready  -> server_handle_conn (socket_read won't block)
            // pend fd silent 8 ticks (~8 s) -> socket_close (reap)
        }
    }
}
```

Measured after the fix (same host, same pin):

```
1 idle socket held    ->  real request 200 in 0.008 s   (was: 6 s FAIL)
6 idle sockets held   ->  real request 200 in 0.006 s   (Chrome 6-conn worst case)
zero added latency for normal requests; no head-of-line blocking.
```

phanes is unblocked. This note exists so the *upstream* `server_serve`
gets the same guard — otherwise every other `stdlib/net/http_server`
consumer reproduces the hang.

## 6. Scope / honesty (g3)

- This is an observation + a measured reference implementation, **not**
  a request for phanes to patch stdlib. Filing per `@D g7` /
  `@I id002` — downstream surfaces the gap, upstream decides the fix.
- The phanes-local `phanes_serve` is a workaround at the consumer
  layer; it does not change `server_serve` and does not regress any
  stdlib byte-eq. The proper fix is `server_serve` adopting the
  select-guard so the workaround can be retired.
- Severity is rated **high** only for the hang/availability aspect;
  it does not touch the multi-OS-thread throughput question (that is
  the separate roadmap-62 note, already resolved-ssot).

## 7. Cross-refs

- `phanes-stdlib-net-os-thread-concurrency-roadmap-62.md` — sibling note;
  landed `socket_select` + `socket_set_nonblock`, the primitives this
  fix consumes.
- `inbox/patches/net-nonblock-multiplex.md` — related non-blocking
  multiplex patch.
- phanes commit `08d1738` (`dancinlab/phanes`) — `phanes_serve` reference
  implementation + the measured reproduction.
