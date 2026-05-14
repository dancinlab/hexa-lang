/* self/native/net.c — std::net POSIX TCP socket builtins
 *
 * Ported from src/std_net.rs (hexa-lang@ef92fc6) — pure C, no Rust.
 * Included from self/runtime.c via `#include "native/net.c"`.
 *
 * Symbols exported (6 primitives):
 *   hexa_net_listen(addr)        : string "host:port" → TAG_INT fd / -errno
 *   hexa_net_accept(listen_fd)   : TAG_INT listen_fd → TAG_INT client_fd
 *   hexa_net_close(fd)           : TAG_INT fd        → TAG_INT 0 / -errno
 *   hexa_net_connect(addr)       : string "host:port" → TAG_INT fd / -errno
 *   hexa_net_read(fd)            : TAG_INT fd        → TAG_STR data (len=0 on err)
 *   hexa_net_write(fd, data)     : TAG_INT fd, string → TAG_INT bytes / -errno
 *
 * http_get / http_serve are composed in self/std_net.hexa on top of these
 * primitives — no C-side implementation needed.
 *
 * Error model: negative TAG_INT carries the raw errno. Matches the
 * C-side convention used by hxcuda/hxblas shims. The .hexa wrappers
 * in self/std_net.hexa convert errnos back to structured errors.
 *
 * Historical note: listen/accept/close were originally inlined into
 * self/runtime.c (interp resurrection block, 2026-04-16). Extracted
 * here alongside connect/read/write so the net subsystem lives in
 * a single C file — analogous to tensor_kernels.c for the hot kernel
 * path.
 */

#include <sys/socket.h>
#include <sys/time.h>
#include <sys/select.h>
#include <sys/un.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <stdlib.h>
#include <stddef.h>
#include <sys/uio.h>

/* This file is a partial translation unit: it is #include'd into
 * self/runtime.c (see the `#include "native/net.c"` near the bottom of
 * runtime.c) after the full `struct HexaVal_ { ... }` definition has
 * landed. Standalone IDE linting of net.c will surface "unknown type
 * HexaVal / implicit declaration" noise — those are not real build
 * errors. The real compile path produces a single TU with all types
 * already defined before net.c is expanded. */

/* Parse "host:port" into sockaddr_in. Accepts:
 *   - dotted-quad (127.0.0.1), "localhost" → INADDR_LOOPBACK,
 *   - "0.0.0.0" or "*"                      → INADDR_ANY,
 *   - port range 1..65535.
 * DNS + IPv6 intentionally deferred (interp narrow surface). */
static int _hexa_net_parse_addr(const char* addr, struct sockaddr_in* sa_out) {
    if (!addr || !*addr || !sa_out) return -EINVAL;
    const char* colon = strrchr(addr, ':');
    if (!colon || colon == addr) return -EINVAL;
    char host[256];
    size_t host_len = (size_t)(colon - addr);
    if (host_len >= sizeof(host)) return -EINVAL;
    memcpy(host, addr, host_len);
    host[host_len] = '\0';
    /* Port 0 is a legitimate bind/connect target on POSIX — it means
     * "let the kernel pick an ephemeral port" (see `man 2 bind`). Rejecting
     * it broke `net_listen("127.0.0.1:0")` which tests rely on for
     * collision-free smoke runs. Only reject negatives and out-of-range. */
    int port = atoi(colon + 1);
    if (port < 0 || port > 65535) return -EINVAL;
    memset(sa_out, 0, sizeof(*sa_out));
    sa_out->sin_family = AF_INET;
    sa_out->sin_port = htons((uint16_t)port);
    if (strcmp(host, "localhost") == 0) {
        sa_out->sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    } else if (strcmp(host, "0.0.0.0") == 0 || strcmp(host, "*") == 0) {
        sa_out->sin_addr.s_addr = htonl(INADDR_ANY);
    } else if (inet_pton(AF_INET, host, &sa_out->sin_addr) != 1) {
        return -EINVAL;
    }
    return 0;
}

/* Parse a hexa-side addr string into a sockaddr_storage. Recognizes:
 *   "host:port"       -> AF_INET via _hexa_net_parse_addr
 *   "unix:/path/sock" -> AF_UNIX, filesystem-bound
 *   "unix:@name"      -> AF_UNIX abstract namespace (Linux only; -EAFNOSUPPORT on Mac)
 * Returns the address family (>0) on success, -errno on failure.
 * Populates *salen_out with the right struct length for bind/connect.
 *
 * RFC: incoming/patches/net-unix-domain-socket.md
 */
static int _hexa_net_parse_any(const char* addr,
                               struct sockaddr_storage* sa_out,
                               socklen_t* salen_out) {
    if (!addr || !*addr || !sa_out || !salen_out) return -EINVAL;
    if (strncmp(addr, "unix:", 5) == 0) {
        const char* path = addr + 5;
        if (!*path) return -EINVAL;
        struct sockaddr_un* un = (struct sockaddr_un*)sa_out;
        memset(un, 0, sizeof(*un));
        un->sun_family = AF_UNIX;
        if (path[0] == '@') {
#ifndef __linux__
            return -EAFNOSUPPORT;
#else
            /* abstract namespace: leading '\0' + name */
            size_t name_len = strlen(path + 1);
            if (name_len + 1 > sizeof(un->sun_path)) return -ENAMETOOLONG;
            un->sun_path[0] = '\0';
            memcpy(un->sun_path + 1, path + 1, name_len);
            *salen_out = (socklen_t)(offsetof(struct sockaddr_un, sun_path) + 1 + name_len);
            return AF_UNIX;
#endif
        }
        size_t plen = strlen(path);
        if (plen + 1 > sizeof(un->sun_path)) return -ENAMETOOLONG;
        memcpy(un->sun_path, path, plen);
        un->sun_path[plen] = '\0';
        *salen_out = sizeof(struct sockaddr_un);
        return AF_UNIX;
    }
    /* Existing AF_INET path. */
    int rc = _hexa_net_parse_addr(addr, (struct sockaddr_in*)sa_out);
    if (rc < 0) return rc;
    *salen_out = sizeof(struct sockaddr_in);
    return AF_INET;
}

HexaVal hexa_net_listen(HexaVal addr_val) {
    const char* addr = hexa_to_cstring(addr_val);
    struct sockaddr_storage sa;
    socklen_t salen = 0;
    int family = _hexa_net_parse_any(addr, &sa, &salen);
    if (family < 0) return hexa_int(family);
    int fd = socket(family, SOCK_STREAM, 0);
    if (fd < 0) return hexa_int(-errno);
    if (family == AF_INET) {
        int one = 1;
        /* SO_REUSEADDR mirrors the Rust TcpListener default. Without it,
         * repeat `hexa run` within TIME_WAIT collides. AF_UNIX has no
         * TIME_WAIT — skip. */
        (void)setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));
    } else if (family == AF_UNIX) {
        /* Filesystem-bound sockets: unlink any stale leftover so bind
         * doesn't fail with EADDRINUSE. Ignore ENOENT (no leftover) and
         * any error on the abstract namespace path (sun_path[0] = '\0'
         * means abstract — nothing to unlink). */
        struct sockaddr_un* un = (struct sockaddr_un*)&sa;
        if (un->sun_path[0] != '\0') (void)unlink(un->sun_path);
    }
    if (bind(fd, (struct sockaddr*)&sa, salen) < 0) {
        int e = errno; close(fd); return hexa_int(-e);
    }
    if (listen(fd, 64) < 0) {
        int e = errno; close(fd); return hexa_int(-e);
    }
    return hexa_int(fd);
}

HexaVal hexa_net_accept(HexaVal listen_val) {
    int64_t listen_fd = hexa_as_num(listen_val);
    if (listen_fd < 0) return hexa_int(-EINVAL);
    int client = accept((int)listen_fd, NULL, NULL);
    if (client < 0) return hexa_int(-errno);
    return hexa_int(client);
}

HexaVal hexa_net_close(HexaVal fd_val) {
    int64_t fd = hexa_as_num(fd_val);
    if (fd < 0) return hexa_int(-EINVAL);
    if (close((int)fd) < 0) return hexa_int(-errno);
    return hexa_int(0);
}

/* net_set_nonblock(fd) -> 0 / -errno (RFC net-nonblock-multiplex.md)
 *
 * Sets O_NONBLOCK on the fd. Subsequent net_read / net_accept on the
 * fd returns immediately if no data / no pending connection (with
 * recv() yielding -1 / EAGAIN, mapped to "" by net_read; net_accept
 * yields -1 / EAGAIN, mapped to -errno by hexa_net_accept). Pair with
 * hexa_net_select to wait on N fds without per-fd blocking.
 */
HexaVal hexa_net_set_nonblock(HexaVal fd_val) {
    if (!HX_IS_INT(fd_val)) return hexa_int((int64_t)-EINVAL);
    int fd = (int)HX_INT(fd_val);
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags < 0) return hexa_int((int64_t)-errno);
    if (fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0) return hexa_int((int64_t)-errno);
    return hexa_int(0);
}

/* net_select(fds, timeout_ms) -> [ready_fds] (RFC net-nonblock-multiplex.md)
 *
 *   timeout_ms < 0  : block indefinitely
 *   timeout_ms == 0 : poll (return immediately)
 *   timeout_ms > 0  : block up to that long
 *
 * Returns: array of fds that are READ-ready. Empty on timeout.
 *          On error, returns a single-element array [-errno] so the
 *          caller can distinguish from "no fds ready". (Empty array
 *          and [-errno] are both length-1 in the error case; check
 *          the first element's sign to disambiguate.)
 *
 * FD_SETSIZE limit (~1024 on Linux/Mac) is enforced via -EBADF.
 */
HexaVal hexa_net_select(HexaVal fds_val, HexaVal timeout_ms_val) {
    HexaVal err_out = hexa_array_new();
    if (!HX_IS_ARRAY(fds_val)) {
        return hexa_array_push(err_out, hexa_int((int64_t)-EINVAL));
    }
    int n = HX_ARR_LEN(fds_val);
    fd_set readfds;
    FD_ZERO(&readfds);
    int maxfd = -1;
    for (int i = 0; i < n; i++) {
        HexaVal v = HX_ARR_ITEMS(fds_val)[i];
        if (!HX_IS_INT(v)) continue;
        int fd = (int)HX_INT(v);
        if (fd < 0 || fd >= FD_SETSIZE) {
            return hexa_array_push(hexa_array_new(), hexa_int((int64_t)-EBADF));
        }
        FD_SET(fd, &readfds);
        if (fd > maxfd) maxfd = fd;
    }
    long long ms = HX_IS_INT(timeout_ms_val) ? (long long)HX_INT(timeout_ms_val) : -1;
    struct timeval tv;
    struct timeval* tvp;
    if (ms < 0) {
        tvp = NULL;
    } else {
        tv.tv_sec = (time_t)(ms / 1000);
        tv.tv_usec = (suseconds_t)((ms % 1000) * 1000);
        tvp = &tv;
    }
    /* select() can be interrupted by signals — caller-handles by reading
     * a single -EINTR back. We don't auto-retry here; downstream code
     * (anima frame loop) needs to interleave signal handling with the
     * select() return path. */
    int rc = select(maxfd + 1, &readfds, NULL, NULL, tvp);
    if (rc < 0) {
        return hexa_array_push(hexa_array_new(), hexa_int((int64_t)-errno));
    }
    /* rc == 0 -> timeout, empty array. rc > 0 -> walk fds again. */
    HexaVal out = hexa_array_new();
    if (rc == 0) return out;
    for (int i = 0; i < n; i++) {
        HexaVal v = HX_ARR_ITEMS(fds_val)[i];
        if (!HX_IS_INT(v)) continue;
        int fd = (int)HX_INT(v);
        if (FD_ISSET(fd, &readfds)) {
            out = hexa_array_push(out, hexa_int((int64_t)fd));
        }
    }
    return out;
}

/* ── SCM_RIGHTS fd-passing over AF_UNIX (RFC P1 signal-ext / fd-passing) ──
 *
 *   net_send_fd(sock_fd, fd_to_send, payload_str)  -> 0 / -errno
 *   net_recv_fd(sock_fd, max_payload_bytes)        -> map { fd, data, error?, errno? }
 *
 * The classic POSIX recipe for handing a kernel fd from one process
 * to another across a connected AF_UNIX socket. Payload bytes are
 * required by some BSD variants (1+ data byte must travel with the
 * cmsg) so net_send_fd sends at least a single 0 byte if the caller
 * passes "".  net_recv_fd allocates a `max_payload`-byte buffer and
 * captures the first received fd (multi-fd cmsg arrays are out of
 * MVP scope -- callers needing multiple fds per message can loop).
 *
 * Cross-platform POSIX (macOS + Linux). Both have sendmsg(2) and
 * SCM_RIGHTS in the kernel ABI.
 */

HexaVal hexa_net_send_fd(HexaVal sock_v, HexaVal fd_v, HexaVal payload_v) {
    if (!HX_IS_INT(sock_v) || !HX_IS_INT(fd_v)) return hexa_int((int64_t)-EINVAL);
    int sock = (int)HX_INT(sock_v);
    int send_fd = (int)HX_INT(fd_v);
    /* Payload: empty string still emits a single 0 byte so BSD/Mac
     * doesn't reject the message (some kernels require >=1 data byte
     * for the cmsg-only case). */
    const char* p = HX_IS_STR(payload_v) ? HX_STR(payload_v) : "";
    size_t plen = strlen(p);
    char fallback = '\0';
    struct iovec iov;
    if (plen == 0) { iov.iov_base = &fallback; iov.iov_len = 1; }
    else           { iov.iov_base = (void*)p;  iov.iov_len = plen; }
    /* cmsg buffer sized for exactly one fd. */
    union {
        char buf[CMSG_SPACE(sizeof(int))];
        struct cmsghdr align;
    } cmsg_buf;
    memset(&cmsg_buf, 0, sizeof(cmsg_buf));
    struct msghdr msg;
    memset(&msg, 0, sizeof(msg));
    msg.msg_iov     = &iov;
    msg.msg_iovlen  = 1;
    msg.msg_control = cmsg_buf.buf;
    msg.msg_controllen = sizeof(cmsg_buf.buf);
    struct cmsghdr* cmsg = CMSG_FIRSTHDR(&msg);
    cmsg->cmsg_level = SOL_SOCKET;
    cmsg->cmsg_type  = SCM_RIGHTS;
    cmsg->cmsg_len   = CMSG_LEN(sizeof(int));
    int* fd_ptr = (int*)CMSG_DATA(cmsg);
    *fd_ptr = send_fd;
    if (sendmsg(sock, &msg, 0) < 0) return hexa_int((int64_t)-errno);
    return hexa_int(0);
}

HexaVal hexa_net_recv_fd(HexaVal sock_v, HexaVal max_payload_v) {
    HexaVal out = hexa_map_new();
    if (!HX_IS_INT(sock_v)) {
        hexa_map_set(out, "error", hexa_str("net_recv_fd: bad sock fd"));
        hexa_map_set(out, "errno", hexa_int((int64_t)EINVAL));
        hexa_map_set(out, "fd",    hexa_int((int64_t)-1));
        return out;
    }
    int sock = (int)HX_INT(sock_v);
    int max_n = HX_IS_INT(max_payload_v) ? (int)HX_INT(max_payload_v) : 4096;
    if (max_n < 1) max_n = 1;
    if (max_n > 65536) max_n = 65536;
    char* buf = (char*)malloc((size_t)max_n + 1);
    if (!buf) {
        hexa_map_set(out, "error", hexa_str("net_recv_fd: malloc failed"));
        hexa_map_set(out, "errno", hexa_int((int64_t)ENOMEM));
        hexa_map_set(out, "fd",    hexa_int((int64_t)-1));
        return out;
    }
    struct iovec iov;
    iov.iov_base = buf;
    iov.iov_len  = (size_t)max_n;
    union {
        char cbuf[CMSG_SPACE(sizeof(int))];
        struct cmsghdr align;
    } cmsg_buf;
    memset(&cmsg_buf, 0, sizeof(cmsg_buf));
    struct msghdr msg;
    memset(&msg, 0, sizeof(msg));
    msg.msg_iov     = &iov;
    msg.msg_iovlen  = 1;
    msg.msg_control = cmsg_buf.cbuf;
    msg.msg_controllen = sizeof(cmsg_buf.cbuf);
    ssize_t n = recvmsg(sock, &msg, 0);
    if (n < 0) {
        int e = errno;
        free(buf);
        hexa_map_set(out, "error", hexa_str(strerror(e)));
        hexa_map_set(out, "errno", hexa_int((int64_t)e));
        hexa_map_set(out, "fd",    hexa_int((int64_t)-1));
        return out;
    }
    int recv_fd = -1;
    struct cmsghdr* cmsg;
    for (cmsg = CMSG_FIRSTHDR(&msg); cmsg != NULL; cmsg = CMSG_NXTHDR(&msg, cmsg)) {
        if (cmsg->cmsg_level == SOL_SOCKET && cmsg->cmsg_type == SCM_RIGHTS) {
            int* fdp = (int*)CMSG_DATA(cmsg);
            recv_fd = *fdp;
            break;
        }
    }
    buf[n] = '\0';
    hexa_map_set(out, "fd",   hexa_int((int64_t)recv_fd));
    hexa_map_set(out, "data", hexa_str(buf));
    hexa_map_set(out, "len",  hexa_int((int64_t)n));
    free(buf);
    return out;
}

HexaVal hexa_net_connect(HexaVal addr_val) {
    const char* addr = hexa_to_cstring(addr_val);
    struct sockaddr_storage sa;
    socklen_t salen = 0;
    int family = _hexa_net_parse_any(addr, &sa, &salen);
    if (family < 0) return hexa_int(family);
    int fd = socket(family, SOCK_STREAM, 0);
    if (fd < 0) return hexa_int(-errno);
    if (connect(fd, (struct sockaddr*)&sa, salen) < 0) {
        int e = errno; close(fd); return hexa_int(-e);
    }
    return hexa_int(fd);
}

/* Single-shot read up to 4096 bytes. The caller is expected to loop
 * until they've got what they want (HTTP parsing in .hexa happens on
 * the accumulated string). Mirrors the Rust variant which also did a
 * single read (TcpStream::read with a 4KiB buffer). */
HexaVal hexa_net_read(HexaVal fd_val) {
    int64_t fd = hexa_as_num(fd_val);
    if (fd < 0) return hexa_str("");
    char buf[4096];
    ssize_t n = recv((int)fd, buf, sizeof(buf) - 1, 0);
    if (n <= 0) return hexa_str("");
    buf[n] = '\0';
    /* hexa_str dup + interns the string — safe to hand back the stack buf. */
    return hexa_str(buf);
}

/* Looping read that accumulates up to `n` bytes before returning.
 *
 * Semantics (roadmap 56 / B7 HTTP POST body prereq):
 *   - Calls recv() repeatedly until either (a) we have received exactly
 *     `n` bytes, (b) the peer closed the connection (recv returns 0 —
 *     treated as EOF), or (c) a non-retryable error occurs. Returns a
 *     hexa string whose length is therefore in [0, n].
 *   - EINTR is retried transparently (POSIX-normal during signal arrival).
 *   - EAGAIN / EWOULDBLOCK is treated as EOF rather than retried. The
 *     blocking model for this call assumes the caller has not set any
 *     socket timeout; if they did (see hexa_net_set_timeout), the timeout
 *     also surfaces as EAGAIN/EWOULDBLOCK and we stop here so the caller
 *     can observe a short read — this is the intended "timeout -> partial"
 *     behaviour for HTTP POST bodies that span TCP packets.
 *   - n <= 0 returns "".
 *
 * Memory: uses heap (malloc) when n > 65536, else stack, to avoid large
 * stack frames on deep call chains in the interpreter. */
HexaVal hexa_net_read_n(HexaVal fd_val, HexaVal n_val) {
    int64_t fd = hexa_as_num(fd_val);
    int64_t want = hexa_as_num(n_val);
    if (fd < 0 || want <= 0) return hexa_str("");
    char stackbuf[65536];
    char* buf = (want <= (int64_t)sizeof(stackbuf)) ? stackbuf : (char*)malloc((size_t)want + 1);
    if (!buf) return hexa_str("");
    size_t got = 0;
    while ((int64_t)got < want) {
        ssize_t r = recv((int)fd, buf + got, (size_t)(want - (int64_t)got), 0);
        if (r > 0) { got += (size_t)r; continue; }
        if (r == 0) break;                /* EOF */
        if (errno == EINTR) continue;     /* retry */
        if (errno == EAGAIN || errno == EWOULDBLOCK) break;  /* treat as EOF */
        break;                            /* other error: return what we have */
    }
    buf[got] = '\0';
    /* Note: hexa_str() uses strlen under the hood (like hexa_net_read above),
     * so embedded NULs in the payload are not preserved. This matches the
     * existing net_read contract. HTTP/1.1 bodies are text or chunked-
     * framed binary and do not embed NULs in the headers/body segments
     * that .hexa parses. If a future caller needs raw byte passthrough,
     * extend the runtime with hexa_str_n(buf, len). */
    HexaVal out = hexa_str(buf);
    if (buf != stackbuf) free(buf);
    return out;
}

/* Apply a recv() timeout on the socket via SO_RCVTIMEO. Returns 0 on
 * success, -errno on failure. ms <= 0 disables the timeout. Follow-on
 * hexa_net_read / hexa_net_read_n calls that would block beyond the
 * timeout surface EAGAIN/EWOULDBLOCK (read_n treats as EOF). */
HexaVal hexa_net_set_timeout(HexaVal fd_val, HexaVal ms_val) {
    int64_t fd = hexa_as_num(fd_val);
    int64_t ms = hexa_as_num(ms_val);
    if (fd < 0) return hexa_int(-EINVAL);
    struct timeval tv;
    if (ms <= 0) { tv.tv_sec = 0; tv.tv_usec = 0; }
    else { tv.tv_sec = (time_t)(ms / 1000); tv.tv_usec = (suseconds_t)((ms % 1000) * 1000); }
    if (setsockopt((int)fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv)) < 0) {
        return hexa_int(-errno);
    }
    return hexa_int(0);
}

/* net_set_nonblock + net_select are defined earlier in this file
 * (anima daemon Phase 2 prereq — RFC net-nonblock-multiplex.md). This
 * comment marks the historical insertion point a previous draft used
 * before the canonical definitions moved next to hexa_net_close. */

HexaVal hexa_net_write(HexaVal fd_val, HexaVal data_val) {
    int64_t fd = hexa_as_num(fd_val);
    if (fd < 0) return hexa_int(-EINVAL);
    const char* data = hexa_to_cstring(data_val);
    if (!data) return hexa_int(-EINVAL);
    size_t total = strlen(data);
    size_t sent = 0;
    while (sent < total) {
        ssize_t n = send((int)fd, data + sent, total - sent, 0);
        if (n < 0) {
            if (errno == EINTR) continue;
            return hexa_int(-errno);
        }
        if (n == 0) break;
        sent += (size_t)n;
    }
    return hexa_int((int64_t)sent);
}

/* ── TAG_FN shim globals (bootstrap bridge, 2026-04-16) ──────────────────
 * The current self/native/hexa_v2 transpiler only recognises net_listen /
 * net_accept / net_close as direct-lowered builtins. Fresh names like
 * net_connect / net_read / net_write are emitted as `hexa_call1(name, …)`
 * — i.e. the transpiler treats them as free-function identifiers backed by
 * a HexaVal fn pointer. Providing TAG_FN shims keeps the interpreter path
 * working until the next codegen_c2 → hexa_cc → hexa_v2 bootstrap cycle
 * teaches the transpiler the direct-lowering. After that, these shims are
 * harmless — codegen will emit `hexa_net_connect(...)` directly and the
 * globals simply remain unused. */
HexaVal net_listen;
HexaVal net_accept;
HexaVal net_close;
HexaVal net_connect;
HexaVal net_read;
HexaVal net_read_n;
HexaVal net_set_timeout;
HexaVal net_write;
/* 2026-05-13: anima daemon Phase 2 — non-blocking + select multiplex */
HexaVal net_set_nonblock;
HexaVal net_select;
/* 2026-05-14: SCM_RIGHTS fd-passing (P1 signal-ext / fd-handoff) */
HexaVal net_send_fd;
HexaVal net_recv_fd;

static void _hexa_init_net_fn_shims(void) {
    net_listen        = hexa_fn_new((void*)hexa_net_listen,        1);
    net_accept        = hexa_fn_new((void*)hexa_net_accept,        1);
    net_close         = hexa_fn_new((void*)hexa_net_close,         1);
    net_connect       = hexa_fn_new((void*)hexa_net_connect,       1);
    net_read          = hexa_fn_new((void*)hexa_net_read,          1);
    net_read_n        = hexa_fn_new((void*)hexa_net_read_n,        2);
    net_set_timeout   = hexa_fn_new((void*)hexa_net_set_timeout,   2);
    net_write         = hexa_fn_new((void*)hexa_net_write,         2);
    net_set_nonblock  = hexa_fn_new((void*)hexa_net_set_nonblock,  1);
    net_select        = hexa_fn_new((void*)hexa_net_select,        2);
    net_send_fd       = hexa_fn_new((void*)hexa_net_send_fd,       3);
    net_recv_fd       = hexa_fn_new((void*)hexa_net_recv_fd,       2);
}
