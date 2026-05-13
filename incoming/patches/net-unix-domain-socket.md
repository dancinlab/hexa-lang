# incoming patch: net-unix-domain-socket — AF_UNIX SOCK_STREAM for local-only IPC

> **id**: `net-unix-domain-socket` · **opened**: 2026-05-13 KST PM · **status**: `spec` (RFC 초안 — 미land)
> **trees**: `self/native/net.c` + `self/std_net.hexa`
> **source**: anima daemon Phase 2 (CHAT.md `~/core/anima/CHAT.md` 의 `--unix /tmp/anima.sock` 옵션) — local-only client (같은 host 의 wilson plugin, Python script, Node process 등) 에 대해 TCP `:7878` 보다 (a) localhost loopback overhead 회피 (b) 인증 단순화 (filesystem permissions) (c) port 충돌 없음.
> **why this matters**: anima daemon 이 local-only mode 로 동작할 때 TCP 는 과한 surface — port allocation, firewall, IPv4 vs IPv6 결정 등 모두 불필요. AF_UNIX SOCK_STREAM 은 동일 process-tree 안에서 가장 단순한 IPC. wilson 도 `provider-anima` plugin 이 같은 머신에서 daemon 호출 시 Unix domain 선호. anima 외에도 모든 local-only hexa-native IPC (nexus / hyperion / hexa hook script ↔ daemon) 가 같은 needs.

---

## 1. 동기

현재 `self/native/net.c::hexa_net_listen` (line 78+):

```c
HexaVal hexa_net_listen(HexaVal addr_val) {
    ...
    int fd = socket(AF_INET, SOCK_STREAM, 0);   // ← AF_INET only
    if (bind(fd, (struct sockaddr*)&sa, sizeof(sa)) < 0) { ... }
    ...
}
```

addr 파싱 (`parse_addr_inet`, line ~60) 도 `"host:port"` 형식 강제. **AF_UNIX 미지원**.

anima daemon Phase 2 spec (CHAT.md `--unix /tmp/anima.sock`):
- local-only client → loopback TCP 보다 4-5× 빠른 IPC
- file permission 으로 access control (예: `chmod 600 /tmp/anima.sock`)
- port 충돌 없음 — `/tmp/anima.sock` 파일 충돌은 `unlink before bind` 패턴
- abstract namespace (Linux only, leading `\\0`) — file 안 만들고 in-kernel 이름공간

## 2. 현 상태

- `self/native/net.c` 의 `parse_addr_inet` 는 `"host:port"` 만 인식 (line 60-75 의 `inet_pton(AF_INET, host, ...)`).
- AF_UNIX 관련 헤더 (`sys/un.h`) 미include.
- `connect / listen / accept` 가 family-agnostic 이므로 (POSIX 보장) — listen/accept 함수 자체는 변경 불요, addr parse + socket() family 만 분기하면 됨.
- `std_net.hexa::net_listen / net_connect` wrapper 도 그대로 사용 가능 (addr string 으로 family 결정).

## 3. 디자인 옵션

| 옵션 | 설명 | 채택? |
|---|---|---|
| **(a) prefix-based dispatch** | `addr` string 이 `unix:<path>` 로 시작하면 AF_UNIX, 그 외는 기존 host:port AF_INET. 단일 builtin 유지. | ✅ **권장** — API surface 추가 0, prefix convention 표준 (rust `tokio::net::UnixListener::bind` 도 유사) |
| **(b) 별도 builtin** | `hexa_net_listen_unix(path)` / `hexa_net_connect_unix(path)` 새 entry. | OK 도 — but API surface 2× |
| **(c) 기존 net_listen 의 addr 가 `/` 로 시작하면 unix** | 암묵적 — `addr.startswith("/")` heuristic. | 깨끗하지 않음 — abstract namespace 처리 어려움 |

**채택 (a) prefix-based**. `unix:/path/to/sock` (filesystem) 또는 `unix:@anima` (abstract namespace, Linux only, `@` → `\\0` mangled internal).

## 4. 제안 패치

### C 변경 (`self/native/net.c`)

```c
#include <sys/un.h>      // sockaddr_un

/* parse_addr: prefix-aware. Returns family + populated sockaddr_storage. */
static int parse_addr(const char* in,
                      struct sockaddr_storage* sa_out,
                      socklen_t* salen_out) {
    if (strncmp(in, "unix:", 5) == 0) {
        const char* path = in + 5;
        struct sockaddr_un* un = (struct sockaddr_un*)sa_out;
        memset(un, 0, sizeof(*un));
        un->sun_family = AF_UNIX;
        if (path[0] == '@') {
            // abstract namespace (Linux only)
            #ifndef __linux__
            return -EAFNOSUPPORT;
            #endif
            un->sun_path[0] = '\0';
            strncpy(un->sun_path + 1, path + 1, sizeof(un->sun_path) - 2);
            *salen_out = offsetof(struct sockaddr_un, sun_path) + 1 + strlen(path + 1);
        } else {
            strncpy(un->sun_path, path, sizeof(un->sun_path) - 1);
            *salen_out = sizeof(struct sockaddr_un);
        }
        return AF_UNIX;
    }
    // existing AF_INET parse via parse_addr_inet (refactored)
    return parse_addr_inet(in, (struct sockaddr_in*)sa_out, salen_out);
}

/* hexa_net_listen — dispatch on parse_addr result */
HexaVal hexa_net_listen(HexaVal addr_val) {
    if (!HX_IS_STR(addr_val)) return hexa_int(-EINVAL);
    struct sockaddr_storage sa;
    socklen_t salen;
    int family = parse_addr(HX_STR(addr_val), &sa, &salen);
    if (family < 0) return hexa_int(family);
    int fd = socket(family, SOCK_STREAM, 0);
    if (fd < 0) return hexa_int(-errno);
    if (family == AF_UNIX) {
        // unlink existing sock file (best-effort, ignore ENOENT)
        struct sockaddr_un* un = (struct sockaddr_un*)&sa;
        if (un->sun_path[0] != '\0') unlink(un->sun_path);
    }
    if (bind(fd, (struct sockaddr*)&sa, salen) < 0) {
        int e = errno; close(fd); return hexa_int(-e);
    }
    if (listen(fd, 128) < 0) {
        int e = errno; close(fd); return hexa_int(-e);
    }
    return hexa_int(fd);
}

/* hexa_net_connect — same dispatch */
HexaVal hexa_net_connect(HexaVal addr_val) {
    if (!HX_IS_STR(addr_val)) return hexa_int(-EINVAL);
    struct sockaddr_storage sa; socklen_t salen;
    int family = parse_addr(HX_STR(addr_val), &sa, &salen);
    if (family < 0) return hexa_int(family);
    int fd = socket(family, SOCK_STREAM, 0);
    if (fd < 0) return hexa_int(-errno);
    if (connect(fd, (struct sockaddr*)&sa, salen) < 0) {
        int e = errno; close(fd); return hexa_int(-e);
    }
    return hexa_int(fd);
}
```

### hexa wrapper — 변경 없음

`net_listen("unix:/tmp/anima.sock")` / `net_listen("0.0.0.0:7878")` 둘 다 작동. wrapper 코드 unchanged.

### 사용 예 (anima daemon)

```hexa
// CLI: anima daemon --unix /tmp/anima.sock
let path = "unix:/tmp/anima.sock"
let listener = net_listen(path)
if listener < 0 {
    eprintln("listen failed: errno=" + to_string(-listener))
    exit(1)
}
// 그 다음은 TCP 와 byte-identical (accept/read/write/close)
```

## 5. 영향 (downstream)

- ✅ **anima daemon Phase 2** — `--unix` 옵션 즉시 활용
- ✅ **wilson `provider-anima`** — local daemon 호출 시 Unix domain 선호
- ✅ **모든 local-only hexa IPC** — port allocation 없이 IPC 구축 가능
- ✅ **breaking changes 0** — prefix convention 도입, 기존 `"host:port"` 그대로 작동

## 6. honest C3 (≥5)

1. abstract namespace (`@`-prefix) Linux only — Mac 에서는 -EAFNOSUPPORT.
2. SO_PASSCRED / SCM_RIGHTS (fd passing) 미포함 — 별도 patch follow-up.
3. file permission management (`chmod 600`) 은 caller 의 책임 — `net_listen` 은 default mode (umask 적용).
4. `sun_path` 길이 limit (108 chars 보통 — `sizeof(sun_path)` platform-dependent) — long path 거부 시 -ENAMETOOLONG 적절히.
5. unlink before bind 가 race 있음 (cleanup 안 된 stale socket → bind fail) — `unlink(path); bind(...)` 패턴 채택 (well-known unix domain socket recipe).
6. abstract namespace `unix:@name` 의 name 안 `\\0` byte 포함 시 truncate — corner case, 본 patch 는 `\\0`-terminated string 만 지원.

## 7. land 우선순위 + 시간

- C 패치 (~50 LoC, `parse_addr` 추출 refactor + AF_UNIX 분기) + `#include <sys/un.h>` + abstract namespace platform gate
- hexa wrapper 변경 0
- 빌드 후 hexa_real rebuild
- test: `net_listen("unix:/tmp/test.sock")` → `nc -U /tmp/test.sock` 으로 connect → write/read round-trip
- 예상 wall: 1시간 land + 20분 self-test

## 8. land 순서 권장

`net-nonblock-multiplex` (별도 patch) **먼저** land 권장 — Unix domain socket 단독은 blocking 동일 한계 (선언 시점에 multi-client 미지원). Unix domain + non-blocking 조합이 anima daemon Phase 2 의 full unblock.

> 보고 마커: **넣었다**
