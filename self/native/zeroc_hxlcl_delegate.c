// self/native/zeroc_hxlcl_delegate.c — ZERO-C leg-B (ING #35, r11).
//
// The 16 hxlcl_* libc/libm wrappers that runtime_core.c calls
// (hxlcl_cos/sin/exp/log/fmod + hxlcl_time/atof/atoll/popen/pclose/atexit/
// signal/execvp/getrusage/gmtime_r/strftime) are `static` in the FROZEN
// runtime.c blob (151c52c8…) and their DEFINITIONS sit AFTER the
// runtime_core.c include boundary — so the drop-ON arena-globals seed TU
// (which compiles runtime_core.c through the runtime.c PRELUDE = head only)
// sees the `static` forward-decls but NOT the bodies → 16 undefined at the
// standalone executable link.
//
// CLASSIFICATION (grep of the frozen blob): NONE of the 16 are truly-frozen
// like hxlcl_strcmp (which has no external rt_* delegate line). Each is the
// #3798 fmod→rt_fmod pattern: the math 5 are 1-line delegates to EXTERNAL
// rt_* cores (frozen runtime.c:2407-2411 `static double hxlcl_cos(double x){
// return HX_FLOAT(rt_cos(hexa_float(x))); }` etc. — rt_cos/sin/exp/log/fmod
// are NON-static `HexaVal rt_*` at :2349-2401); the libc 11 are thin libc
// shims (frozen :2497-3011). We re-supply all 16 as EXTERNAL (non-static)
// definitions in a SEPARATE seed object — routing the math 5 through the same
// external rt_* the frozen statics use (byte-faithful) and the libc 11 to real
// libc. This does NOT touch the immutable frozen blob (delegate = non-frozen
// path), and the DEFAULT build never compiles this file (byte-identical OFF).
//
// Included by a 1-line TU with runtime.h in scope (HexaVal / HX_FLOAT).

#include <stdlib.h>
#include <time.h>
#include <math.h>
#include <signal.h>
#include <unistd.h>
#include <sys/resource.h>
#include <stdio.h>

// ── math 5: delegate to the EXTERNAL rt_* cores (frozen-static pattern) ────
extern HexaVal rt_cos(HexaVal x);
extern HexaVal rt_sin(HexaVal x);
extern HexaVal rt_exp(HexaVal x);
extern HexaVal rt_log(HexaVal x);
extern HexaVal rt_fmod(HexaVal x, HexaVal y);
double hxlcl_cos(double x)  { return HX_FLOAT(rt_cos(hexa_float(x))); }
double hxlcl_sin(double x)  { return HX_FLOAT(rt_sin(hexa_float(x))); }
double hxlcl_exp(double x)  { return HX_FLOAT(rt_exp(hexa_float(x))); }
double hxlcl_log(double x)  { return HX_FLOAT(rt_log(hexa_float(x))); }
double hxlcl_fmod(double x, double y) { return HX_FLOAT(rt_fmod(hexa_float(x), hexa_float(y))); }

// ── libc 11: thin real-libc delegates (post-init path) ────────────────────
long long hxlcl_atoll(const char *s) { return s ? strtoll(s, 0, 10) : 0; }
double    hxlcl_atof(const char *s)  { return s ? strtod(s, 0) : 0.0; }
int       hxlcl_time(int *t)         { time_t now = time(0); if (t) *t = (int)now; return (int)now; }
int       hxlcl_atexit(void (*fn)(void)) { return atexit(fn); }
void     *hxlcl_signal(int signum, void *handler) { return (void*)signal(signum, (void(*)(int))handler); }
int       hxlcl_getrusage(int who, void *usage) { return getrusage(who, (struct rusage*)usage); }
void     *hxlcl_gmtime_r(const void *tp, void *out) { return gmtime_r((const time_t*)tp, (struct tm*)out); }
size_t    hxlcl_strftime(char *s, size_t max, const char *fmt, const void *tm) { return strftime(s, max, fmt, (const struct tm*)tm); }
int       hxlcl_execvp(const char *file, char *const argv[]) { return execvp(file, argv); }
void     *hxlcl_popen(const char *cmd, const char *mode) { return (void*)popen(cmd, mode); }
int       hxlcl_pclose(void *stream) { return pclose((FILE*)stream); }

// hxlcl_write — frozen-static raw write delegate (runtime.c:1997 `(long)write`).
long hxlcl_write(int fd, const void *buf, unsigned long n) {
    return (long)write(fd, buf, (size_t)n);
}

// ── r23: 7 runtime.c-private mem/str statics (seedprov 0 → 1) ──────────────
// These are `static __attribute__((noinline))` in the frozen runtime.c HEAD
// (pre-`#include "runtime_core.c"` prologue, NOT post-boundary like the math 5),
// so the arena-globals/drop seed TU sees the file-static forward-decls but the
// linker has no exported symbol for them — UNSUPPLIED (seedprov=0). r21 MEASURED
// they WALL 8 HI-tier bodies (hexa_is_error/list_dir/utc_iso_format/utc_iso_parse/
// from_char_code/http_get + rt_append_file/rt_read_lines). We re-supply each as
// an EXTERNAL (non-static) definition here, BYTE-FAITHFUL to the frozen body:
//   * memcpy/memset/strlen/strncmp — verbatim scalar loops (output-identical to
//     the frozen volatile-char loops; the `volatile` qualifier only blocks the
//     compiler from folding to a libc memcpy/strlen, an OPTIMIZATION concern of
//     the freestanding default build, NOT an output-bytes concern of this seed).
//   * strtoll — VERBATIM reimplementation: the frozen hxlcl_strtoll is a custom
//     parser (no LLONG_MAX overflow saturation, whitespace set = space/tab/nl
//     only) that DEVIATES from libc strtoll, so we port the body, NOT route to
//     libc (byte-faithful → reproduce exactly).
//   * getenv — frozen hxlcl_getenv walks `environ` directly and its header comment
//     states it "matches libc getenv semantics (case-sensitive, first match, NULL
//     on miss)"; libc getenv gives output-identical results, so we delegate to it
//     (avoids dragging the runtime.c-private `environ` capture into this TU).
//   * strdup — frozen hxlcl_strdup is malloc(n+1)+byte-copy+NUL; libc strdup is
//     the identical contract → output-identical bytes, delegate to libc.
// This does NOT touch the immutable frozen blob; the DEFAULT build never compiles
// this file (byte-identical OFF).
#include <string.h>

void *hxlcl_memcpy(void *dst, const void *src, size_t n) {
    unsigned char *d = (unsigned char *)dst;
    const unsigned char *s = (const unsigned char *)src;
    for (size_t i = 0; i < n; i++) d[i] = s[i];
    return dst;
}
void *hxlcl_memset(void *s, int c, size_t n) {
    unsigned char *p = (unsigned char *)s;
    unsigned char v = (unsigned char)c;
    for (size_t i = 0; i < n; i++) p[i] = v;
    return s;
}
size_t hxlcl_strlen(const char *s) {
    if (!s) return 0;
    size_t n = 0;
    while (((const volatile char *)s)[n]) n++;
    return n;
}
int hxlcl_strncmp(const char *a, const char *b, size_t n) {
    for (size_t i = 0; i < n; i++) {
        unsigned char ca = (unsigned char)a[i];
        unsigned char cb = (unsigned char)b[i];
        if (ca != cb) return (int)ca - (int)cb;
        if (ca == 0) return 0;
    }
    return 0;
}
long long hxlcl_strtoll(const char *nptr, char **endptr, int base) {
    if (!nptr) { if (endptr) *endptr = (char *)nptr; return 0; }
    const char *s = nptr;
    while (*s == ' ' || *s == '\t' || *s == '\n') s++;
    int sign = 1;
    if (*s == '-') { sign = -1; s++; }
    else if (*s == '+') s++;
    if (base == 0) {
        if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) { base = 16; s += 2; }
        else if (s[0] == '0') { base = 8; s++; }
        else base = 10;
    } else if (base == 16 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) {
        s += 2;
    }
    unsigned long long n = 0;
    for (;;) {
        char c = *s;
        int d;
        if (c >= '0' && c <= '9') d = c - '0';
        else if (c >= 'a' && c <= 'z') d = c - 'a' + 10;
        else if (c >= 'A' && c <= 'Z') d = c - 'A' + 10;
        else break;
        if (d >= base) break;
        n = n * (unsigned long long)base + (unsigned long long)d;
        s++;
    }
    if (endptr) *endptr = (char *)s;
    return (long long)((sign < 0) ? -(long long)n : (long long)n);
}
char *hxlcl_getenv(const char *name) { return getenv(name); }
char *hxlcl_strdup(const char *s)    { return s ? strdup(s) : (char *)0; }

// ── r25: 3 runtime.c-private syscall statics (seedprov 0 → 1) ──────────────
// hxlcl_clock_gettime / hxlcl_read / hxlcl_nanosleep are `static
// __attribute__((noinline))` in the FROZEN runtime.c (the `#elif
// defined(__linux__)` libc-fallback branch at runtime.c:1996/2025 + the unified
// nanosleep at runtime.c:2574). The arena-globals/drop seed TU sees the
// file-static forward-decls but the linker has no exported symbol for them —
// UNSUPPLIED (seedprov=0). r24 MEASURED they WALL the time/sleep/input family
// (hexa_clock/timestamp/time_ms/now_monotonic_s + hexa_sleep/_s/_ms/_ns +
// hexa_input/read_stdin + read_stdin_n_c). We re-supply each as an EXTERNAL
// (non-static) definition here, BYTE-FAITHFUL to the frozen Linux-branch body:
//   * hxlcl_read / hxlcl_clock_gettime — verbatim 1-line libc shims (the frozen
//     `#elif defined(__linux__)` bodies are exactly `(long)read(...)` and
//     `clock_gettime((clockid_t)clk, (struct timespec*)ts)`).
//   * hxlcl_nanosleep — VERBATIM port of the frozen unified body (runtime.c:2574):
//     a clock_gettime-anchored EINTR-resume loop whose Linux arm (HXLCL_SYS_SELECT
//     undefined off-Apple) sleeps the remaining interval via libc nanosleep(2),
//     recomputing `left` from CLOCK_MONOTONIC so the full duration always elapses.
//     Routes its inner clock reads through THIS file's hxlcl_clock_gettime (same
//     contract as the frozen body's call to the runtime.c-private static).
// pipe/dup2/waitpid are NOT supplied here: the exec_* family they would unlock is
// independently walled by runtime.c-private file-static state (the _hexa_stream_
// slots pool + the _hxa_* argv/sha256 static helpers in native/exec_argv_sha256.c),
// so supplying them would add dead seedprov with no body unlocked (measured r25).
// This does NOT touch the immutable frozen blob; the DEFAULT build never compiles
// this file (byte-identical OFF).
#include <errno.h>

long hxlcl_read(int fd, void *buf, unsigned long n) { return (long)read(fd, buf, (size_t)n); }
int  hxlcl_clock_gettime(int clk, void *ts) { return clock_gettime((clockid_t)clk, (struct timespec *)ts); }
int  hxlcl_nanosleep(const void *req_, void *rem_) {
    const struct timespec *req = (const struct timespec *)req_;
    long long total_ns = (long long)req->tv_sec * 1000000000LL + (long long)req->tv_nsec;
    if (rem_) { ((struct timespec *)rem_)->tv_sec = 0; ((struct timespec *)rem_)->tv_nsec = 0; }
    if (total_ns <= 0) return 0;
    struct timespec start; hxlcl_clock_gettime(CLOCK_MONOTONIC, &start);
    for (;;) {
        struct timespec now; hxlcl_clock_gettime(CLOCK_MONOTONIC, &now);
        long long elapsed = ((long long)now.tv_sec - start.tv_sec) * 1000000000LL
                          + ((long long)now.tv_nsec - start.tv_nsec);
        long long left = total_ns - elapsed;
        if (left <= 0) return 0;
        struct timespec ts;
        ts.tv_sec  = (long)(left / 1000000000LL);
        ts.tv_nsec = (long)(left % 1000000000LL);
        int r = nanosleep(&ts, NULL);
        if (r == 0) return 0;          // full sleep done
        if (errno == EINTR) continue;   // signal: recompute remaining, retry
        return -1;                      // genuine error
    }
}
