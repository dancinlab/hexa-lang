# incoming patch: net-nonblock-multiplex — non-blocking sockets + select/poll for multi-client servers

> **id**: `net-nonblock-multiplex` · **opened**: 2026-05-13 KST PM · **status**: `spec` (RFC 초안 — 미land)
> **trees**: `self/native/net.c` + `self/std_net.hexa` (+ docs/std_net.md)
> **source**: anima daemon Phase 2 (CHAT.md 5-layer architecture, `~/core/anima/CHAT.md`) — anima 가 "외부 프로젝트 호출/응답 아닌 자연발화 broadcast" daemon 으로 동작하려면 multi-client persistent connection 필요. 현재 `std_net.hexa::http_serve` 는 blocking single-client (accept→read→respond→close, accept 한 fd 가 종료될 때까지 daemon 정지).
> **why this matters**: anima daemon = N humans + M animas group chat broadcast server. multi-client persistent + 자연발화 timer-event interleaved 가 핵심. 현재 `http_serve` blocking 모델로는 (a) 한 client 응답 중 다른 client accept 불가 (b) idle client 가 broadcast 받을 수 없음 (c) 자연발화 timer 가 accept 중 멈춤. wilson `provider-anima` plugin 도 동일 의존. anima-only 아님 — 모든 long-running socket 서버 (wilson harness-rpc daemon, nexus 어떤 IPC 든) 가 같은 gap 위에 막힘.

---

## 1. 동기

hexa stdlib `self/native/net.c` v1 (현 trunk, ported from `src/std_net.rs` `ef92fc6`):

```
hexa_net_listen(addr)       → fd  (blocking)
hexa_net_accept(listen_fd)  → client_fd  (blocking)
hexa_net_read(fd)           → string  (blocking)
hexa_net_write(fd, data)    → bytes
hexa_net_close(fd)          → 0
hexa_net_connect(addr)      → fd  (blocking)
```

`http_serve(addr, handler)` (in `std_net.hexa`):
```hexa
while true {
    let conn = net_accept(listener)        // 1 conn at a time
    let raw = net_read(conn)               // blocks until conn writes
    let response = handler(request)        // handler runs sync
    net_write(conn, http_response)
    net_close(conn)                        // close immediately
}
```

**한계 (concrete blockers for anima daemon)**:
1. **multi-client 불가능** — 1 conn 응답 중 다른 conn accept queue 에 쌓이기만 함. anima 는 N humans subscribe 동시 broadcast 필요.
2. **persistent connection 불가능** — handler 종료 = close. anima 는 client 가 살아있는 동안 broadcast push.
3. **timer/event interleave 불가능** — accept 중 멈춰서 자연발화 trigger fire 못함. anima 의 spontaneous-tick 은 daemon main loop 의 일등 시민이어야 함.
4. **graceful shutdown 어려움** — accept 가 blocking 이라 SIGTERM 받아도 즉시 종료 못함.

## 2. 현 상태 (audit, 2026-05-13)

- `self/native/net.c` — 6 primitives + `inet_pton` 만. `fcntl O_NONBLOCK`, `select(2)`, `poll(2)`, `epoll`, `kqueue` 모두 미사용.
- `self/std_net.hexa` — `net_listen/accept/connect/read/write/close` + `http_get`/`http_serve` wrapper. `http_serve` 는 blocking single-conn loop (line 90-110).
- `self/runtime.c::exec_stream_async` (line 10288) — `fcntl(fd, F_SETFL, flags | O_NONBLOCK)` 패턴이 **이미 존재** (popen pipe 용). 같은 패턴을 net fd 에 노출만 하면 됨.
- `self/async_runtime.hexa` — 있지만 **pure-hexa cooperative scheduler** (future / channel / select-event). POSIX-level fd multiplexing 과 다른 레이어. 결합 가능하나 별도 작업.

## 3. 디자인 옵션

| 옵션 | 설명 | 채택? |
|---|---|---|
| **(a) `net_set_nonblock(fd) + net_select(fds, timeout_ms)` minimal pair** | C 추가: `hexa_net_set_nonblock(fd)` (fcntl wrap, 이미 runtime.c 에 있음 패턴) + `hexa_net_select(fd_array, timeout_ms)` (POSIX `select(2)` wrap, returns array of ready fds). hexa wrapper: `net_set_nonblock(fd) → int`, `net_select(fds: [int], timeout_ms: int) → [int]`. select(2) fd_set ≤ FD_SETSIZE (~1024) — anima daemon 의 N<100 동시 client 에 충분. | ✅ **권장 1차** — 가장 작은 surface, POSIX 보편, 모든 unix 동작 |
| **(b) `net_poll(fds, timeout_ms)` 만 (no nonblock)** | POSIX `poll(2)` wrap. fd 수 unlimited. blocking accept/read 유지하되 poll 로 ready 만 호출하면 blocking 안 일어남 (race-free 보장 안 됨 — accept storm 시 fd-ready 와 실제 syscall 사이 race). | 부분적 — accept storm 미해결, race window |
| **(c) `net_epoll_*` / `net_kqueue_*` 별도 wrap** | Linux-only / Darwin-only platform-specific. 1만+ 동시 client 까지. | 과한 scope, anima MVP (N<100) 에 불필요. follow-up |
| **(d) async_runtime.hexa 통합** | `async_runtime` 의 future/channel 위에 net fd 를 mountable event source 로 추가. 코드량 큼. | 미래 — 본 patch 와 별개 |
| **(e) 그냥 thread / fork** | hexa stdlib 에 thread 없음 (process model). fork 는 `self/rt/proc.hexa` 에 있지만 process-level multi-handling = 메모리/state 공유 어려움. | ❌ scope 다름 |

**채택 (a) 1차**. C 패치 ~50 LoC, hexa wrapper ~20 LoC. (b)/(c) 는 future-tense.

## 4. 제안 API

### C 추가 (`self/native/net.c`)

```c
#include <sys/select.h>
#include <fcntl.h>

/* hexa_net_set_nonblock(fd) → 0 ok / -errno */
HexaVal hexa_net_set_nonblock(HexaVal fd_val) {
    if (!HX_IS_INT(fd_val)) return hexa_int(-EINVAL);
    int fd = (int)HX_INT(fd_val);
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags < 0) return hexa_int(-errno);
    if (fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0) return hexa_int(-errno);
    return hexa_int(0);
}

/* hexa_net_select(fds_array, timeout_ms) → ready_fds_array
 *   timeout_ms < 0: block indefinitely
 *   timeout_ms = 0: poll (return immediately)
 *   timeout_ms > 0: block up to that long
 *   Returns: array of fds that are READ-ready. Empty on timeout.
 *            single-element [-errno] on error.
 */
HexaVal hexa_net_select(HexaVal fds_val, HexaVal timeout_ms_val) {
    if (!HX_IS_ARRAY(fds_val)) return hexa_array_new_with(hexa_int(-EINVAL));
    int n = HX_ARR_LEN(fds_val);
    fd_set readfds; FD_ZERO(&readfds);
    int maxfd = -1;
    for (int i = 0; i < n; i++) {
        HexaVal v = HX_ARR_ITEMS(fds_val)[i];
        if (!HX_IS_INT(v)) continue;
        int fd = (int)HX_INT(v);
        if (fd > FD_SETSIZE) return hexa_array_new_with(hexa_int(-EBADF));
        FD_SET(fd, &readfds);
        if (fd > maxfd) maxfd = fd;
    }
    long long ms = HX_IS_INT(timeout_ms_val) ? (long long)HX_INT(timeout_ms_val) : -1;
    struct timeval tv; struct timeval* tvp;
    if (ms < 0) { tvp = NULL; }
    else { tv.tv_sec = ms / 1000; tv.tv_usec = (ms % 1000) * 1000; tvp = &tv; }
    int rc = select(maxfd + 1, &readfds, NULL, NULL, tvp);
    if (rc < 0) return hexa_array_new_with(hexa_int(-errno));
    HexaVal out = hexa_array_new();
    for (int i = 0; i < n; i++) {
        HexaVal v = HX_ARR_ITEMS(fds_val)[i];
        if (!HX_IS_INT(v)) continue;
        int fd = (int)HX_INT(v);
        if (FD_ISSET(fd, &readfds)) {
            out = hexa_array_push(out, hexa_int(fd));
        }
    }
    return out;
}
```

### hexa wrapper (`self/std_net.hexa`)

```hexa
fn net_set_nonblock(fd: int) -> int {
    return hexa_net_set_nonblock(fd)
}

fn net_select(fds, timeout_ms: int) {
    return hexa_net_select(fds, timeout_ms)
}
```

### 사용 패턴 (anima daemon Phase 2 MVP)

```hexa
let listener = net_listen("0.0.0.0:7878")
let _ = net_set_nonblock(listener)
let mut clients = []
while !shutdown_requested() {
    let all_fds = [listener]
    let mut ci = 0
    while ci < len(clients) { all_fds.push(clients[ci]); ci = ci + 1 }
    let ready = net_select(all_fds, 100)  // 100ms timeout = also spontaneous-tick window
    let mut ri = 0
    while ri < len(ready) {
        let fd = ready[ri]
        if fd == listener {
            let conn = net_accept(listener)
            let _ = net_set_nonblock(conn)
            clients.push(conn)
        } else {
            let line = net_read(fd)   // non-blocking after set_nonblock
            if len(line) == 0 {
                // EOF or would-block; check errno via separate getter (TODO)
                net_close(fd)
                clients = remove_fd(clients, fd)
            } else {
                handle_jsonl_frame(fd, line)
            }
        }
        ri = ri + 1
    }
    spontaneous_tick(animas, room, now_ms())   // 자연발화 fire 자유
}
```

## 5. 영향 (downstream)

- ✅ **anima daemon Phase 2** — multi-client + 자연발화 interleave 가능해짐
- ✅ **wilson `harness-rpc` daemon mode** — 동일 패턴으로 multi-client RPC 가능
- ✅ **nexus / hyperion / 어떤 hexa-native IPC 서버든** — 표준 select-loop 가능
- ❌ **breaking changes 없음** — 기존 `net_listen/accept/read/write/close` 그대로

## 6. honest C3 (≥5)

1. `select(2)` 는 FD_SETSIZE (~1024) limit — N<100 client 에 충분, 1만+ 가면 epoll/kqueue 필요. → (c) 옵션 follow-up.
2. POSIX `select(2)` 는 timeout struct 가 portable 하지 않음 일부 BSD — Linux/macOS 양쪽 검증 필요 (Mac arm64 + Linux x86_64 minimum).
3. errno 받는 방식 — 본 API 는 `net_read` 등이 `""` 반환 시 EOF / wouldblock 구분 불가. follow-up: `net_last_errno()` getter 또는 `net_read_ex(fd) → (bytes, errno)` tuple return.
4. fd_set vs fds-array marshal 비용 — N client 마다 fd_set 재구축. N<100 에 negligible.
5. accept 후 set_nonblock 까지의 race window — accept return 직후 짧은 blocking window. anima MVP 에 무시 가능.
6. `select_ex` (write-ready, exception fd) 미포함 — read-only ready. write back-pressure 미해결 (anima broadcast 큰 메시지 시 partial write 가능). follow-up.

## 7. land 우선순위 + 시간 예상

- C 패치 (50 LoC) + hexa wrap (20 LoC) = ~70 LoC
- 빌드 후 hexa_real rebuild
- test: anima daemon Phase 2 MVP (CHAT.md Phase 2 명세) 가 실 multi-client broadcast 동작하면 PASS
- 예상 wall: 1-2시간 land + 30분 self-test

## 8. 후속 (별도 patch)

- `net-poll-wrap` — `poll(2)` 도 추가 (FD_SETSIZE 무관)
- `net-epoll-linux` / `net-kqueue-darwin` — high-N event multiplexer
- `net-unix-domain-socket` — Unix domain socket family (별도 patch file 동시 file)
- `net-tls` — TLS termination (rustls/openssl wrap)

> 보고 마커: **넣었다**
