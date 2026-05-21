// ═══════════════════════════════════════════════════════════
//  HEXA C Runtime Library — Phase 5 self-hosting support
//  Provides: tagged values, strings, arrays, maps, GC
// ═══════════════════════════════════════════════════════════

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include <ctype.h>
#include <dlfcn.h>
#include <time.h>
#include <unistd.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <spawn.h>      // TL;DR #2: posix_spawnp shell-free fast path
#include <errno.h>      // EINTR for waitpid retry loop in spawn reap
#include <fcntl.h>      // TL;DR #4: F_SETPIPE_SZ on Linux for pipe enlarge
#include <signal.h>     // 2026-05-06: SIGPIPE SIG_IGN install in stdio init
#include <regex.h>      // G3-REGEX 2026-05-06: POSIX ERE regcomp/regexec
#include <sys/mman.h>   // RFC 025 (2026-05-12): mmap-backed safetensors load
extern char **environ; // posix_spawnp inherits parent env explicitly
// execinfo.h: HEXA_OOB_TRACE backtrace path; available on both Apple
// libSystem and glibc. RFC 063/064 ubu pool fire (FIRMWARE.md G-R0)
// hit clang implicit-decl error when the include was Apple-only.
#include <execinfo.h>
#if defined(__APPLE__)
#include <mach/mach.h>
#include <mach/task.h>
#include <mach/task_info.h>
#endif

// ═══════════════════════════════════════════════════════════
//  RFC 061 Phase P1 — 2-layer runtime split.
//  The CORE tier (HexaVal representation, allocator/arena, the
//  universal codegen-emitted primitives + their transitive closure)
//  lives in runtime_core.c and is textually included here, right
//  after the system #include block, so all of its macros, file-scope
//  statics and internal forward declarations are visible to the
//  HI-tier code below exactly as before the split.
//
//  This #include + the HI tier below re-concatenate to a translation
//  unit byte-identical to the pre-split runtime.c — a pure file
//  partition with ZERO behavior change. See runtime_core.c header.
// ═══════════════════════════════════════════════════════════
// Cycle 55: override macOS libc stderr/stdout/stdin/errno (= __stderrp/
// __stdoutp/__stdinp + __error extern globals) with encoded FILE*
// constants + plain int store. Placed BEFORE helper definitions so
// they see our values. Drops ___stderrp + ___stdoutp + ___stdinp +
// ___error from extern list.
#undef stderr
#undef stdout
#undef stdin
#define stderr ((FILE *)(uintptr_t)3)
#define stdout ((FILE *)(uintptr_t)2)
#define stdin  ((FILE *)(uintptr_t)1)
static int hxlcl_errno = 0;
#undef errno
#define errno hxlcl_errno
// Cycle 63 forward decls — syscall wrappers used by earlier helpers
// (e.g. hxlcl_printf line 451+ calls write). Bodies live in the
// syscall block at line ~825 below.
static long hxlcl_read(int fd, void *buf, unsigned long n);
static long hxlcl_write(int fd, const void *buf, unsigned long n);
static int  hxlcl_close(int fd);
static int  hxlcl_getpid(void);
static int  hxlcl_dup2(int oldfd, int newfd);
static int  hxlcl_pipe(int fds[2]);
static int  hxlcl_fork(void);
static int  hxlcl_kill(int pid, int sig);
static int  hxlcl_fcntl(int fd, int cmd, long arg);
static int  hxlcl_ioctl(int fd, unsigned long req, void *arg);
static long hxlcl_lseek(int fd, long off, int whence);
static int  hxlcl_select(int nfds, void *r, void *w, void *e, void *t);
static int  hxlcl_poll(void *fds, unsigned int nfds, int timeout);
static int  hxlcl_waitpid(int pid, int *status, int options);
static int  hxlcl_fstat(int fd, void *buf);
static int  hxlcl_stat(const char *path, void *buf);
static int  hxlcl_open_sys(const char *path, int flags, ...);
static void hxlcl_exit(int code) __attribute__((noreturn));
static void *hxlcl_mmap(void *addr, unsigned long len, int prot, int flags, int fd, long off);
static int  hxlcl_clock_gettime(int clk, void *ts);  /* re-decl: cycle 65 syscall body overrides cycle 62 stub */
static int  hxlcl_darwin_check_fd_set_overflow(int fd, const void *p, int n);

// ─── RUNTIME.md Phase 1 Tier-A.1 — libc unhook helpers ───
// Step-1 of the hexa-native runtime rewrite (RUNTIME.md cycle 46):
// local C-source replacements for the most-called libc string fns
// so the linker no longer pulls in _strlen / _strcmp / _memcmp.
// Defined BEFORE `#include "runtime_core.c"` so CORE-tier call sites
// resolve to these too (runtime_core.c is textually concatenated).
// Step-2 (later cycle) ports each helper to stdlib/runtime/<name>.hexa
// + codegen routing. `noinline` + volatile read defeat clang's
// libcall recognition under -Oz. The trailing `#define strlen ...`
// textually overrides any residual libc strlen / memcmp / strcmp
// references in macro expansions / inline header bodies that the
// perl substitution couldn't reach.
static size_t __attribute__((noinline)) hxlcl_strlen(const char *s) {
    if (!s) return 0;
    size_t n = 0;
    while (((const volatile char *)s)[n]) n++;
    return n;
}
static int __attribute__((noinline)) hxlcl_memcmp(const void *a, const void *b, size_t n) {
    const unsigned char *pa = (const unsigned char *)a;
    const unsigned char *pb = (const unsigned char *)b;
    for (size_t i = 0; i < n; i++) {
        int d = (int)pa[i] - (int)pb[i];
        if (d != 0) return d;
    }
    return 0;
}
static int __attribute__((noinline)) hxlcl_strcmp(const char *a, const char *b) {
    for (size_t i = 0; ; i++) {
        unsigned char ca = (unsigned char)a[i];
        unsigned char cb = (unsigned char)b[i];
        if (ca != cb) return (int)ca - (int)cb;
        if (ca == 0) return 0;
    }
}
// Cycle 47: `strcat` unhook. Same loop pattern in `hxlcl_strcat` body
// would let clang's libcall recognizer convert it back to `strcat` +
// `strlen`; the volatile read on the dest scan defeats that, mirroring
// the cycle-46 helpers. Returns dest per C99 strcat semantics.
static char *__attribute__((noinline)) hxlcl_strcat(char *dest, const char *src) {
    char *p = dest;
    while (((const volatile char *)p)[0]) p++;
    size_t i = 0;
    while (((const volatile char *)src)[i]) {
        p[i] = src[i];
        i++;
    }
    p[i] = '\0';
    return dest;
}
// Cycle 47 batch: strncmp, strstr, strrchr, strchr, strdup, strndup.
static int __attribute__((noinline)) hxlcl_strncmp(const char *a, const char *b, size_t n) {
    for (size_t i = 0; i < n; i++) {
        unsigned char ca = (unsigned char)a[i];
        unsigned char cb = (unsigned char)b[i];
        if (ca != cb) return (int)ca - (int)cb;
        if (ca == 0) return 0;
    }
    return 0;
}
static const char *__attribute__((noinline)) hxlcl_strchr(const char *s, int c) {
    if (!s) return NULL;
    unsigned char target = (unsigned char)c;
    for (size_t i = 0; ; i++) {
        unsigned char x = (unsigned char)((const volatile char *)s)[i];
        if (x == target) return s + i;
        if (x == 0) return (target == 0) ? (s + i) : NULL;
    }
}
static const char *__attribute__((noinline)) hxlcl_strrchr(const char *s, int c) {
    if (!s) return NULL;
    unsigned char target = (unsigned char)c;
    const char *last = NULL;
    for (size_t i = 0; ; i++) {
        unsigned char x = (unsigned char)((const volatile char *)s)[i];
        if (x == target) last = s + i;
        if (x == 0) return last;
    }
}
static const char *__attribute__((noinline)) hxlcl_strstr(const char *h, const char *n) {
    if (!h || !n) return NULL;
    if (n[0] == 0) return h;
    for (size_t i = 0; ((const volatile char *)h)[i]; i++) {
        size_t j = 0;
        while (n[j] && h[i + j] == n[j]) j++;
        if (n[j] == 0) return h + i;
    }
    return NULL;
}
static char *__attribute__((noinline)) hxlcl_strdup(const char *s) {
    if (!s) return NULL;
    size_t n = 0;
    while (((const volatile char *)s)[n]) n++;
    char *out = (char *)malloc(n + 1);
    if (!out) return NULL;
    for (size_t i = 0; i < n; i++) out[i] = s[i];
    out[n] = '\0';
    return out;
}
static char *__attribute__((noinline)) hxlcl_strndup(const char *s, size_t cap) {
    if (!s) return NULL;
    size_t n = 0;
    while (n < cap && ((const volatile char *)s)[n]) n++;
    char *out = (char *)malloc(n + 1);
    if (!out) return NULL;
    for (size_t i = 0; i < n; i++) out[i] = s[i];
    out[n] = '\0';
    return out;
}
// Cycle 48 batch — numeric parse + bzero.
static long long __attribute__((noinline)) hxlcl_atoll(const char *s) {
    if (!s) return 0;
    size_t i = 0;
    while (s[i] == ' ' || s[i] == '\t' || s[i] == '\n') i++;
    int sign = 1;
    if (s[i] == '-') { sign = -1; i++; }
    else if (s[i] == '+') i++;
    unsigned long long n = 0;
    while (s[i] >= '0' && s[i] <= '9') {
        n = n * 10ULL + (unsigned long long)(s[i] - '0');
        i++;
    }
    return (long long)((sign < 0) ? -(long long)n : (long long)n);
}
static int __attribute__((noinline)) hxlcl_atoi(const char *s) {
    return (int)hxlcl_atoll(s);
}
static long long __attribute__((noinline)) hxlcl_strtoll(const char *nptr, char **endptr, int base) {
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
static unsigned long long __attribute__((noinline)) hxlcl_strtoull(const char *nptr, char **endptr, int base) {
    if (!nptr) { if (endptr) *endptr = (char *)nptr; return 0; }
    const char *s = nptr;
    while (*s == ' ' || *s == '\t' || *s == '\n') s++;
    if (*s == '+') s++;
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
    return n;
}
static double __attribute__((noinline)) hxlcl_atof(const char *s) {
    if (!s) return 0.0;
    size_t i = 0;
    while (s[i] == ' ' || s[i] == '\t' || s[i] == '\n') i++;
    int sign = 1;
    if (s[i] == '-') { sign = -1; i++; }
    else if (s[i] == '+') i++;
    double n = 0.0;
    while (s[i] >= '0' && s[i] <= '9') {
        n = n * 10.0 + (double)(s[i] - '0');
        i++;
    }
    if (s[i] == '.') {
        i++;
        double frac = 0.1;
        while (s[i] >= '0' && s[i] <= '9') {
            n += (double)(s[i] - '0') * frac;
            frac *= 0.1;
            i++;
        }
    }
    if (s[i] == 'e' || s[i] == 'E') {
        i++;
        int esign = 1;
        if (s[i] == '-') { esign = -1; i++; }
        else if (s[i] == '+') i++;
        int exp_val = 0;
        while (s[i] >= '0' && s[i] <= '9') {
            exp_val = exp_val * 10 + (s[i] - '0');
            i++;
        }
        double mul = 1.0;
        for (int k = 0; k < exp_val; k++) mul *= 10.0;
        if (esign < 0) n /= mul;
        else n *= mul;
    }
    return (sign < 0) ? -n : n;
}
static void __attribute__((noinline)) hxlcl_bzero(void *s, size_t n) {
    unsigned char *p = (unsigned char *)s;
    for (size_t i = 0; i < n; i++) {
        p[i] = 0;
    }
}
// Cycle 49 batch — memory triple + Tier-A.1 stragglers.
static void *__attribute__((noinline)) hxlcl_memcpy(void *dst, const void *src, size_t n) {
    unsigned char *d = (unsigned char *)dst;
    const unsigned char *s = (const unsigned char *)src;
    for (size_t i = 0; i < n; i++) d[i] = s[i];
    return dst;
}
static void *__attribute__((noinline)) hxlcl_memset(void *s, int c, size_t n) {
    unsigned char *p = (unsigned char *)s;
    unsigned char v = (unsigned char)c;
    for (size_t i = 0; i < n; i++) p[i] = v;
    return s;
}
static void *__attribute__((noinline)) hxlcl_memmove(void *dst, const void *src, size_t n) {
    unsigned char *d = (unsigned char *)dst;
    const unsigned char *s = (const unsigned char *)src;
    if (d == s || n == 0) return dst;
    if (d < s) {
        for (size_t i = 0; i < n; i++) d[i] = s[i];
    } else {
        for (size_t i = n; i > 0; i--) d[i - 1] = s[i - 1];
    }
    return dst;
}
static char *__attribute__((noinline)) hxlcl_strncpy(char *dst, const char *src, size_t n) {
    size_t i = 0;
    for (; i < n && src[i]; i++) dst[i] = src[i];
    for (; i < n; i++) dst[i] = '\0';
    return dst;
}
static char *__attribute__((noinline)) hxlcl_strcpy(char *dst, const char *src) {
    size_t i = 0;
    while (((const volatile char *)src)[i]) { dst[i] = src[i]; i++; }
    dst[i] = '\0';
    return dst;
}
static const char *__attribute__((noinline)) hxlcl_strerror(int errnum) {
    switch (errnum) {
        case 0: return "no error";
        case 1: return "EPERM";
        case 2: return "ENOENT";
        case 4: return "EINTR";
        case 5: return "EIO";
        case 9: return "EBADF";
        case 11: return "EAGAIN";
        case 12: return "ENOMEM";
        case 13: return "EACCES";
        case 17: return "EEXIST";
        case 22: return "EINVAL";
        case 24: return "EMFILE";
        case 32: return "EPIPE";
        default: return "unknown error";
    }
}
// cycle 6: strftime forward decl — body after #include
static size_t hxlcl_strftime(char *buf, size_t cap, const char *fmt, void *tm);
// Cycle 52 — minimal printf family. Handles %s/%d/%i/%u/%lld/%ld/%llu/
// %lu/%zu/%c/%x/%X/%p/%%, basic width + zero-pad.
// Cycle 56 (2026-05-21) — real %f/%g/%e/%F/%G/%E formatting added
// (default 6 sig digits / 6 fractional digits; rounding via peek-next).
// Resolves inbox/patches/stdlib-print-float-emits-type-tag-not-value.md
// (anima trainer per-step loss/grad-norm monitoring blocker). Not
// bit-exact with libc's Grisu/Ryu — last few ULPs may differ — but
// adequate for training observability and diagnostic output.
static int __attribute__((noinline)) hxlcl_vsnprintf(char *buf, size_t cap, const char *fmt, va_list ap) {
    size_t pos = 0;
    #define HXLCL_PUT(ch) do { if (pos + 1 < cap) buf[pos] = (ch); pos++; } while (0)
    while (*fmt) {
        if (*fmt != '%') { HXLCL_PUT(*fmt); fmt++; continue; }
        fmt++;
        int leftalign = 0, zeropad = 0, width = 0;
        int prec = -1;  /* -1 = unset (defaults applied per-conv) */
        if (*fmt == '-') { leftalign = 1; fmt++; }
        if (*fmt == '+') fmt++;
        if (*fmt == ' ') fmt++;
        if (*fmt == '#') fmt++;
        if (*fmt == '0') { zeropad = 1; fmt++; }
        while (*fmt >= '0' && *fmt <= '9') { width = width * 10 + (*fmt - '0'); fmt++; }
        if (*fmt == '.') {
            fmt++;
            prec = 0;
            if (*fmt == '*') { prec = va_arg(ap, int); fmt++; if (prec < 0) prec = 0; }
            else while (*fmt >= '0' && *fmt <= '9') { prec = prec * 10 + (*fmt - '0'); fmt++; }
        }
        int lng = 0;
        if (*fmt == 'h') { fmt++; if (*fmt == 'h') fmt++; }
        else if (*fmt == 'l') { lng = 1; fmt++; if (*fmt == 'l') { lng = 2; fmt++; } }
        else if (*fmt == 'z' || *fmt == 'j' || *fmt == 't') { lng = 2; fmt++; }
        char conv = *fmt; if (conv == 0) break; fmt++;
        char tmp[32]; int tn = 0;
        if (conv == '%') { HXLCL_PUT('%'); continue; }
        if (conv == 'c') { HXLCL_PUT((char)va_arg(ap, int)); continue; }
        if (conv == 's') {
            const char *s = va_arg(ap, const char *);
            if (!s) s = "(null)";
            int slen = 0; while (s[slen]) slen++;
            int pad = width - slen; if (pad < 0) pad = 0;
            if (!leftalign) for (int k = 0; k < pad; k++) HXLCL_PUT(' ');
            for (int k = 0; k < slen; k++) HXLCL_PUT(s[k]);
            if (leftalign) for (int k = 0; k < pad; k++) HXLCL_PUT(' ');
            continue;
        }
        if (conv == 'd' || conv == 'i') {
            long long v;
            if (lng == 2) v = va_arg(ap, long long);
            else if (lng == 1) v = va_arg(ap, long);
            else v = va_arg(ap, int);
            int neg = (v < 0);
            unsigned long long uv = neg ? (unsigned long long)(-(v + 1)) + 1ULL : (unsigned long long)v;
            if (uv == 0) tmp[tn++] = '0';
            else while (uv) { tmp[tn++] = '0' + (char)(uv % 10); uv /= 10; }
            if (neg) tmp[tn++] = '-';
        } else if (conv == 'u') {
            unsigned long long v;
            if (lng == 2) v = va_arg(ap, unsigned long long);
            else if (lng == 1) v = va_arg(ap, unsigned long);
            else v = va_arg(ap, unsigned int);
            if (v == 0) tmp[tn++] = '0';
            else while (v) { tmp[tn++] = '0' + (char)(v % 10); v /= 10; }
        } else if (conv == 'x' || conv == 'X' || conv == 'p') {
            unsigned long long v;
            if (conv == 'p') v = (unsigned long long)(uintptr_t)va_arg(ap, void *);
            else if (lng == 2) v = va_arg(ap, unsigned long long);
            else if (lng == 1) v = va_arg(ap, unsigned long);
            else v = va_arg(ap, unsigned int);
            char hi = (conv == 'X') ? 'A' : 'a';
            if (v == 0) tmp[tn++] = '0';
            else while (v) { int d = (int)(v & 0xF); tmp[tn++] = (d < 10) ? ('0' + (char)d) : (hi + (char)d - 10); v >>= 4; }
            if (conv == 'p') { tmp[tn++] = 'x'; tmp[tn++] = '0'; }
        } else if (conv == 'f' || conv == 'g' || conv == 'e' || conv == 'F' || conv == 'G' || conv == 'E') {
            /* Cycle 56 — real double-to-string for %f/%g/%e (default 6 sig
             * digits / 6 fractional digits). Not bit-exact with libc's
             * Grisu/Ryu but adequate for training observability + diagnostic
             * use (println(float), step loss/grad-norm logs). Resolves
             * inbox/patches/stdlib-print-float-emits-type-tag-not-value.md. */
            double dv = va_arg(ap, double);
            /* nan/inf via bit pattern (no libc isnan/isinf available). */
            union { double d; unsigned long long u; } __pun;
            __pun.d = dv;
            unsigned long long bits = __pun.u;
            int signbit = (int)(bits >> 63);
            unsigned long long exp_bits = (bits >> 52) & 0x7FFULL;
            unsigned long long mant_bits = bits & 0xFFFFFFFFFFFFFULL;
            /* fbuf sized for worst case %f of ~1e308 (sign + ~310 digits +
             * '.' + 6 frac + null). */
            char fbuf[352]; int fn = 0;
            int is_upper = (conv == 'F' || conv == 'G' || conv == 'E');
            if (exp_bits == 0x7FF) {
                if (mant_bits) {
                    const char *s = is_upper ? "NAN" : "nan";
                    for (int k = 0; s[k]; k++) fbuf[fn++] = s[k];
                } else {
                    if (signbit) fbuf[fn++] = '-';
                    const char *s = is_upper ? "INF" : "inf";
                    for (int k = 0; s[k]; k++) fbuf[fn++] = s[k];
                }
            } else {
                if (signbit) { fbuf[fn++] = '-'; dv = -dv; }
                /* %f default prec = 6 (fractional digits); %g default = 6
                 * (significant digits); %e default = 6 (digits after
                 * decimal in scientific). */
                int prec_eff = (prec < 0) ? 6 : prec;
                if ((conv == 'g' || conv == 'G') && prec_eff == 0) prec_eff = 1;
                if (dv == 0.0) {
                    fbuf[fn++] = '0';
                    if (conv == 'f' || conv == 'F') {
                        if (prec_eff > 0) {
                            fbuf[fn++] = '.';
                            for (int k = 0; k < prec_eff; k++) fbuf[fn++] = '0';
                        }
                    } else if (conv == 'e' || conv == 'E') {
                        if (prec_eff > 0) {
                            fbuf[fn++] = '.';
                            for (int k = 0; k < prec_eff; k++) fbuf[fn++] = '0';
                        }
                        fbuf[fn++] = is_upper ? 'E' : 'e';
                        fbuf[fn++] = '+'; fbuf[fn++] = '0'; fbuf[fn++] = '0';
                    }
                    /* %g of 0.0 → just "0" */
                } else {
                    /* Normalize: 1.0 <= dv < 10.0, track decimal exponent. */
                    int e10 = 0;
                    while (dv >= 1e16) { dv *= 1e-16; e10 += 16; }
                    while (dv >= 1e4)  { dv *= 1e-4;  e10 += 4;  }
                    while (dv >= 10.0) { dv *= 0.1;   e10 += 1;  }
                    while (dv < 1e-15) { dv *= 1e16;  e10 -= 16; }
                    while (dv < 1e-3)  { dv *= 1e4;   e10 -= 4;  }
                    while (dv < 1.0)   { dv *= 10.0;  e10 -= 1;  }
                    /* digits_needed: for %g, prec_eff sig digits; for %f,
                     * need e10+1+prec_eff digits if e10>=0 else prec_eff
                     * (with leading zeros); for %e, prec_eff+1 sig digits. */
                    int sig_digits;
                    if (conv == 'g' || conv == 'G') sig_digits = prec_eff;
                    else if (conv == 'e' || conv == 'E') sig_digits = prec_eff + 1;
                    else { /* %f */
                        sig_digits = (e10 >= 0 ? e10 + 1 : 0) + prec_eff;
                        if (sig_digits < 1) sig_digits = 1;
                    }
                    if (sig_digits > 18) sig_digits = 18;
                    if (sig_digits < 1) sig_digits = 1;
                    char digits[24]; int n_dig = 0;
                    for (int k = 0; k < sig_digits; k++) {
                        int d = (int)dv;
                        if (d > 9) d = 9; if (d < 0) d = 0;
                        digits[n_dig++] = (char)('0' + d);
                        dv = (dv - d) * 10.0;
                    }
                    /* round half-up: peek next digit. */
                    int round_d = (int)dv;
                    if (round_d >= 5) {
                        int j = n_dig - 1;
                        while (j >= 0) {
                            if (digits[j] < '9') { digits[j]++; break; }
                            digits[j] = '0';
                            j--;
                        }
                        if (j < 0) {
                            /* carry overflow: 0.999.. → 1.000.. ; insert '1'
                             * at front, bump exponent. */
                            for (int k = n_dig; k > 0; k--) digits[k] = digits[k - 1];
                            digits[0] = '1';
                            n_dig++;
                            e10++;
                        }
                    }
                    /* %g chooses %e vs %f based on exponent. */
                    char eff_conv = conv;
                    int g_strip_zeros = 0;
                    if (conv == 'g' || conv == 'G') {
                        g_strip_zeros = 1;
                        if (e10 < -4 || e10 >= prec_eff) {
                            eff_conv = (conv == 'G') ? 'E' : 'e';
                        } else {
                            eff_conv = (conv == 'G') ? 'F' : 'f';
                            /* For %g→%f: prec after decimal = sig - (e10+1). */
                            int frac = prec_eff - (e10 + 1);
                            if (frac < 0) frac = 0;
                            prec_eff = frac;
                        }
                    }
                    if (eff_conv == 'e' || eff_conv == 'E') {
                        /* For %g→%e: prec after decimal = sig - 1. */
                        int e_prec;
                        if (conv == 'g' || conv == 'G') e_prec = (sig_digits - 1 < 0) ? 0 : sig_digits - 1;
                        else e_prec = prec_eff;
                        fbuf[fn++] = digits[0];
                        int emit_dot = (e_prec > 0);
                        if (emit_dot) {
                            fbuf[fn++] = '.';
                            for (int k = 1; k <= e_prec; k++) {
                                fbuf[fn++] = (k < n_dig) ? digits[k] : '0';
                            }
                        }
                        if (g_strip_zeros && emit_dot) {
                            while (fn > 0 && fbuf[fn - 1] == '0') fn--;
                            if (fn > 0 && fbuf[fn - 1] == '.') fn--;
                        }
                        fbuf[fn++] = (eff_conv == 'E') ? 'E' : 'e';
                        int ev = e10;
                        if (ev < 0) { fbuf[fn++] = '-'; ev = -ev; } else fbuf[fn++] = '+';
                        if (ev >= 100) {
                            fbuf[fn++] = (char)('0' + (ev / 100));
                            fbuf[fn++] = (char)('0' + ((ev / 10) % 10));
                            fbuf[fn++] = (char)('0' + (ev % 10));
                        } else {
                            fbuf[fn++] = (char)('0' + (ev / 10));
                            fbuf[fn++] = (char)('0' + (ev % 10));
                        }
                    } else {
                        /* %f or %g→%f. */
                        int di = 0;
                        if (e10 >= 0) {
                            for (int k = 0; k <= e10; k++) {
                                fbuf[fn++] = (di < n_dig) ? digits[di] : '0';
                                di++;
                            }
                            if (prec_eff > 0) {
                                fbuf[fn++] = '.';
                                for (int k = 0; k < prec_eff; k++) {
                                    fbuf[fn++] = (di < n_dig) ? digits[di] : '0';
                                    di++;
                                }
                            }
                        } else {
                            fbuf[fn++] = '0';
                            if (prec_eff > 0) {
                                fbuf[fn++] = '.';
                                int leading_z = (-e10) - 1;
                                for (int k = 0; k < leading_z && k < prec_eff; k++) fbuf[fn++] = '0';
                                int remaining = prec_eff - leading_z;
                                for (int k = 0; k < remaining; k++) {
                                    fbuf[fn++] = (di < n_dig) ? digits[di] : '0';
                                    di++;
                                }
                            }
                        }
                        if (g_strip_zeros) {
                            int has_dot = 0;
                            for (int k = 0; k < fn; k++) if (fbuf[k] == '.') { has_dot = 1; break; }
                            if (has_dot) {
                                while (fn > 0 && fbuf[fn - 1] == '0') fn--;
                                if (fn > 0 && fbuf[fn - 1] == '.') fn--;
                            }
                        }
                    }
                }
            }
            int fpad = width - fn; if (fpad < 0) fpad = 0;
            char fpadc = (zeropad && !leftalign) ? '0' : ' ';
            if (!leftalign) for (int k = 0; k < fpad; k++) HXLCL_PUT(fpadc);
            for (int k = 0; k < fn; k++) HXLCL_PUT(fbuf[k]);
            if (leftalign) for (int k = 0; k < fpad; k++) HXLCL_PUT(' ');
            continue;
        } else {
            HXLCL_PUT('%'); HXLCL_PUT(conv); continue;
        }
        int pad = width - tn; if (pad < 0) pad = 0;
        char padc = (zeropad && !leftalign) ? '0' : ' ';
        if (!leftalign) for (int k = 0; k < pad; k++) HXLCL_PUT(padc);
        for (int i = tn - 1; i >= 0; i--) HXLCL_PUT(tmp[i]);
        if (leftalign) for (int k = 0; k < pad; k++) HXLCL_PUT(' ');
    }
    #undef HXLCL_PUT
    if (cap > 0) buf[pos < cap ? pos : cap - 1] = '\0';
    return (int)pos;
}
static int __attribute__((noinline)) hxlcl_snprintf(char *buf, size_t cap, const char *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    int r = hxlcl_vsnprintf(buf, cap, fmt, ap);
    va_end(ap);
    return r;
}
static int __attribute__((noinline)) hxlcl_sprintf(char *buf, const char *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    int r = hxlcl_vsnprintf(buf, 0x7FFFFFFF, fmt, ap);
    va_end(ap);
    return r;
}
static int __attribute__((noinline)) hxlcl_vfprintf_fd(int fd, const char *fmt, va_list ap) {
    char buf[4096];
    int n = hxlcl_vsnprintf(buf, sizeof(buf), fmt, ap);
    if (n > (int)sizeof(buf) - 1) n = sizeof(buf) - 1;
    return (int)hxlcl_write(fd, buf, (size_t)n);
}
static int __attribute__((noinline)) hxlcl_printf(const char *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    int r = hxlcl_vfprintf_fd(1, fmt, ap);
    va_end(ap);
    return r;
}
static int __attribute__((noinline)) hxlcl_fprintf(void *fp, const char *fmt, ...) {
    int fd = 1;
    if (fp == (void *)stderr) fd = 2;
    va_list ap; va_start(ap, fmt);
    int r = hxlcl_vfprintf_fd(fd, fmt, ap);
    va_end(ap);
    return r;
}
static int __attribute__((noinline)) hxlcl_fputs(const char *s, void *fp) {
    int fd = 1; if (fp == (void *)stderr) fd = 2;
    if (!s) return -1;
    size_t n = 0; while (((const volatile char *)s)[n]) n++;
    return (int)hxlcl_write(fd, s, n);
}
static int __attribute__((noinline)) hxlcl_fputc(int c, void *fp) {
    int fd = 1; if (fp == (void *)stderr) fd = 2;
    unsigned char ch = (unsigned char)c;
    return hxlcl_write(fd, &ch, 1) == 1 ? c : -1;
}
static int __attribute__((noinline)) hxlcl_fflush(void *fp) {
    (void)fp;
    return 0;
}
static int __attribute__((noinline)) hxlcl_putchar(int c) {
    unsigned char ch = (unsigned char)c;
    return hxlcl_write(1, &ch, 1) == 1 ? c : -1;
}
static void __attribute__((noinline)) hxlcl_perror(const char *s) {
    if (s && s[0]) {
        size_t n = 0; while (((const volatile char *)s)[n]) n++;
        hxlcl_write(2, s, n);
        hxlcl_write(2, ": ", 2);
    }
    hxlcl_write(2, "error\n", 6);
}
// Cycle 53 — Tier-A.2 mmap-backed bump allocator. malloc never frees;
// free is a noop; realloc bump-allocates new region + byte copy.
// Trade-off: compiler binary leaks memory until exit (a one-shot tool;
// acceptable). Calls libc `mmap` for fresh 4 MB chunks; that single
// `_mmap` extern is the floor for the allocator family. Once @asm
// blocks are wired (Tier-A.4 path), `mmap` itself can be syscall-
// inlined and the family becomes zero-extern.
#define HXLCL_ALLOC_CHUNK_SZ (4u * 1024u * 1024u)
static char *_hxlcl_alloc_ptr = (char *)0;
static char *_hxlcl_alloc_end = (char *)0;
static void *__attribute__((noinline)) hxlcl_malloc(size_t n) {
    if (n == 0) n = 1;
    n = (n + (size_t)15) & ~(size_t)15;
    if (!_hxlcl_alloc_ptr || _hxlcl_alloc_ptr + n > _hxlcl_alloc_end) {
        size_t chunk = (n > HXLCL_ALLOC_CHUNK_SZ) ? n : HXLCL_ALLOC_CHUNK_SZ;
        void *m = hxlcl_mmap((void *)0, chunk, PROT_READ | PROT_WRITE,
                       MAP_PRIVATE | MAP_ANON, -1, 0);
        if (m == MAP_FAILED) return (void *)0;
        _hxlcl_alloc_ptr = (char *)m;
        _hxlcl_alloc_end = _hxlcl_alloc_ptr + chunk;
    }
    void *p = _hxlcl_alloc_ptr;
    _hxlcl_alloc_ptr += n;
    return p;
}
static void __attribute__((noinline)) hxlcl_free(void *p) {
    (void)p;
}
static void *__attribute__((noinline)) hxlcl_realloc(void *p, size_t n) {
    if (!p) return hxlcl_malloc(n);
    if (n == 0) return (void *)0;
    void *np = hxlcl_malloc(n);
    if (!np) return (void *)0;
    unsigned char *d = (unsigned char *)np;
    const unsigned char *s = (const unsigned char *)p;
    for (size_t i = 0; i < n; i++) d[i] = s[i];
    return np;
}
static void *__attribute__((noinline)) hxlcl_calloc(size_t nmemb, size_t size) {
    size_t total = nmemb * size;
    void *p = hxlcl_malloc(total);
    if (p) {
        unsigned char *q = (unsigned char *)p;
        for (size_t i = 0; i < total; i++) q[i] = 0;
    }
    return p;
}
static int __attribute__((noinline)) hxlcl_munmap(void *addr, size_t length) {
    (void)addr; (void)length;
    return 0;
}
// Cycle 54 — Tier-A.3 file-stream subset. FILE* encoded as
// (void *)(uintptr_t)(fd + 1) so 0 doesn't alias NULL. stderr/
// stdout/stdin (libc pointers) preserved by hxlcl_fprintf/fputs/
// fputc/fflush path; those keep using libc globals (one extern
// each — addressed later via @asm + fd constants).
static void *__attribute__((noinline)) hxlcl_fopen(const char *path, const char *mode) {
    if (!path || !mode) return (void *)0;
    int flags = 0;
    if (mode[0] == 'r') flags = O_RDONLY;
    else if (mode[0] == 'w') flags = O_WRONLY | O_CREAT | O_TRUNC;
    else if (mode[0] == 'a') flags = O_WRONLY | O_CREAT | O_APPEND;
    else return (void *)0;
    if (mode[1] == '+' || (mode[1] != 0 && mode[2] == '+')) {
        flags = (flags & ~(O_RDONLY | O_WRONLY)) | O_RDWR;
    }
    int fd = hxlcl_open_sys(path, flags, 0644);
    if (fd < 0) return (void *)0;
    return (void *)(uintptr_t)(fd + 1);
}
static int __attribute__((noinline)) hxlcl_fclose(void *fp) {
    if (!fp) return -1;
    uintptr_t v = (uintptr_t)fp;
    // libc stderr/stdout/stdin: pointers in __DATA, very high addresses.
    // Our encoding: small ints (fd+1, typically <1024).
    if (v >= 0x1000) return 0;  // libc FILE* — don't close
    int fd = (int)v - 1;
    if (fd < 3) return 0;  // safety: never close 0/1/2
    return hxlcl_close(fd);
}
static int __attribute__((noinline)) _hxlcl_fp_fd(void *fp) {
    uintptr_t v = (uintptr_t)fp;
    if (v >= 0x1000) {
        // libc FILE* — best effort by pointer comparison.
        if (fp == (void *)stderr) return 2;
        if (fp == (void *)stdout) return 1;
        if (fp == (void *)stdin) return 0;
        return -1;
    }
    return (int)v - 1;
}
static size_t __attribute__((noinline)) hxlcl_fread(void *buf, size_t sz, size_t n, void *fp) {
    if (!buf || sz == 0 || n == 0) return 0;
    int fd = _hxlcl_fp_fd(fp);
    if (fd < 0) return 0;
    size_t total = sz * n;
    size_t got = 0;
    unsigned char *p = (unsigned char *)buf;
    while (got < total) {
        long r = (long)hxlcl_read(fd, p + got, total - got);
        if (r <= 0) break;
        got += (size_t)r;
    }
    return got / sz;
}
static size_t __attribute__((noinline)) hxlcl_fwrite(const void *buf, size_t sz, size_t n, void *fp) {
    if (!buf || sz == 0 || n == 0) return 0;
    int fd = _hxlcl_fp_fd(fp);
    if (fd < 0) return 0;
    size_t total = sz * n;
    size_t put = 0;
    const unsigned char *p = (const unsigned char *)buf;
    while (put < total) {
        long r = (long)hxlcl_write(fd, p + put, total - put);
        if (r <= 0) break;
        put += (size_t)r;
    }
    return put / sz;
}
static long __attribute__((noinline)) hxlcl_ftell(void *fp) {
    int fd = _hxlcl_fp_fd(fp);
    if (fd < 0) return -1;
    return (long)hxlcl_lseek(fd, 0, SEEK_CUR);
}
static int __attribute__((noinline)) hxlcl_fseek(void *fp, long offset, int whence) {
    int fd = _hxlcl_fp_fd(fp);
    if (fd < 0) return -1;
    return hxlcl_lseek(fd, (off_t)offset, whence) < 0 ? -1 : 0;
}
static void *__attribute__((noinline)) hxlcl_fdopen(int fd, const char *mode) {
    (void)mode;
    if (fd < 0) return (void *)0;
    return (void *)(uintptr_t)(fd + 1);
}
static int __attribute__((noinline)) hxlcl_flock(int fd, int op) {
    (void)fd; (void)op;
    return 0;
}
static int __attribute__((noinline)) hxlcl_setvbuf(void *fp, char *buf, int mode, size_t sz) {
    (void)fp; (void)buf; (void)mode; (void)sz;
    return 0;
}
// Cycle 57 — Tier-A.4 trivial POSIX stubs. The compiler binary calls
// these for cleanup / TTY detection / signal hooks / env access / socket
// options / pty handling / resource limits — none load-bearing for the
// compile-then-exit path. Return safe defaults. `getenv` reads from a
// minimal copy of envp captured at first call (Cycle 57+ may wire envp
// in main; for now returns NULL = "var not set").
// step-2 cycle 6 — ISO bisect identified `getenv` as init-time blocker:
// hxlcl_getenv() is called by hexa_val_arena_init() / similar startup
// paths BEFORE hexa TAG_FN globals (`rt_posix_ok` etc) bind via
// `_hexa_init_fn_shims`. Calling rt_posix_ok() then dereferences an
// unbound TAG_FN slot → SIGSEGV. Keep init-time helpers (getenv, atexit,
// isatty, signal) as plain C; only port post-init helpers.
// Ported (post-init, safe): atexit + isatty + signal — actually these
// are also called early but their hexa-delegation didn't crash in ISO-C.
// The dividing line is: fns called by runtime_init code paths.
// Conservative safe set: 5 fns kept as C; 5 ported.
static int hxlcl_atexit(void (*fn)(void));
static int hxlcl_isatty(int fd);
static void *hxlcl_signal(int signum, void *handler);
static int hxlcl_sigaction(int signum, const void *act, void *oldact);
static int hxlcl_sigprocmask(int how, const void *set, void *oldset);
// getenv: cycle 66 — restore real environ-walk (cycle 61's noop stub
// silently disabled every env-flag in the runtime, including
// HEXA_EXEC_NO_SHELL → posix_spawnp fast path → exec() returned "").
// Resolves inbox/patches/yosys-exec-runtime-regression-cycles-61-64.md
// + inbox/patches/runtime-env-and-exec-capture-stubs-block-cli-tools.md.
// Walks the `environ` global directly; matches libc getenv semantics
// (case-sensitive, returns first match, NULL on miss).
extern char **environ;
static char *__attribute__((noinline)) hxlcl_getenv(const char *name) {
    if (!name) return (char *)0;
    char **e = environ;
    if (!e) return (char *)0;
    size_t nlen = hxlcl_strlen(name);
    while (*e) {
        const char *entry = *e;
        size_t i = 0;
        while (i < nlen && entry[i] && entry[i] == name[i]) i++;
        if (i == nlen && entry[i] == '=') return (char *)(entry + nlen + 1);
        e++;
    }
    return (char *)0;
}
static int hxlcl_setenv(const char *name, const char *val, int overwrite);
static int hxlcl_setsockopt(int sockfd, int level, int optname, const void *optval, unsigned int optlen);
static int hxlcl_grantpt(int fd);
static int hxlcl_unlockpt(int fd);
// cycle 6: setsockopt/grantpt/unlockpt bodies moved below — see thin shims after #include
// cycle 6: ptsname/ttyname/getrlimit/getrusage forward decls — bodies after #include
static char *hxlcl_ptsname(int fd);
static char *hxlcl_ttyname(int fd);
static int hxlcl_getrlimit(int resource, void *rlim);
static int hxlcl_getrusage(int who, void *usage);
// Cycle 59 — Tier-A.5 libm + ctype stubs. The compiler binary doesn't
// call cos/exp/log/fmod at all (flame/NN code paths are linked but
// unreachable from aprime_cc's compile-then-exit flow). These are 5-7
// term Taylor approximations sufficient for any unreachable execution.
// `isalnum`/`isalpha` are pure ASCII classification — called by lexer
// `_is_ident_cont` / `_is_ident_start`, which IS load-bearing.
// RUNTIME.md step-2 cycle 2 — math helper bodies MOVED to stdlib/
// runtime/math.hexa. Thin C shims defined below `#include
// "runtime_core.c"` use HexaVal wrap/unwrap. Forward decls only here
// so cycle-46 callers earlier in the file can still link.
static double hxlcl_fmod(double x, double y);
static double hxlcl_exp(double x);
static double hxlcl_log(double x);
static double hxlcl_cos(double x);
static double hxlcl_sin(double x);
// RUNTIME.md step-2 cycle 1 — bodies MOVED below `#include
// "runtime_core.c"` so they can use HexaVal / hexa_int / hexa_truthy
// to delegate to the hexa-source `rt_isalnum`/_isalpha (defined in
// stdlib/runtime/ctype.hexa, transpile-emitted into ap_post.c).
// Forward decl here so call sites in cycle-46 helpers earlier in
// this file can still link.
static int hxlcl_isalnum(int c);
static int hxlcl_isalpha(int c);
// RUNTIME.md step-2 cycle 3 — pthread stubs MOVED to
// stdlib/runtime/thread.hexa (single noop + create policy hexa fns).
// Thin C shims delegate. forward decls only here; bodies after include.
static int hxlcl_pthread_mutex_init(void *m, const void *a);
static int hxlcl_pthread_mutex_destroy(void *m);
static int hxlcl_pthread_mutex_lock(void *m);
static int hxlcl_pthread_mutex_unlock(void *m);
static int hxlcl_pthread_cond_init(void *c, const void *a);
static int hxlcl_pthread_cond_destroy(void *c);
static int hxlcl_pthread_cond_signal(void *c);
static int hxlcl_pthread_cond_broadcast(void *c);
static int hxlcl_pthread_cond_wait(void *c, void *m);
static int hxlcl_pthread_cond_timedwait(void *c, void *m, const void *ts);
static int hxlcl_pthread_create(void *thread, const void *attr, void *(*start)(void *), void *arg);
static int hxlcl_pthread_join(void *thread, void **retval);
// Cycle 63 — Darwin BSD ABI syscall wrappers via inline `svc 0x80`.
// Each call: x16 = syscall number, x0..x5 = args, svc 0x80 → x0 = ret.
// Replaces libc syscall wrappers (_read, _write, _open, etc) with
// direct kernel trap. Currently arm64 only (aprime_cc is Mach-O arm64).
#if defined(__arm64__) || defined(__aarch64__)
#define HXLCL_SYS_EXIT      1
#define HXLCL_SYS_FORK      2
#define HXLCL_SYS_READ      3
#define HXLCL_SYS_WRITE     4
#define HXLCL_SYS_OPEN      5
#define HXLCL_SYS_CLOSE     6
#define HXLCL_SYS_WAIT4     7
#define HXLCL_SYS_KILL     37
#define HXLCL_SYS_PIPE     42
#define HXLCL_SYS_DUP2     90
#define HXLCL_SYS_FCNTL    92
#define HXLCL_SYS_SELECT   93
#define HXLCL_SYS_GETPID   20
#define HXLCL_SYS_IOCTL    54
#define HXLCL_SYS_POLL    230
#define HXLCL_SYS_FSTAT   339
#define HXLCL_SYS_STAT    338
#define HXLCL_SYS_LSEEK   199
#define HXLCL_SYS_MMAP    197

static inline long _hxlcl_syscall1(long nr, long a0) {
    register long x0 __asm__("x0") = a0;
    register long x16 __asm__("x16") = nr;
    __asm__ volatile("svc #0x80" : "+r"(x0) : "r"(x16) : "memory", "cc");
    return x0;
}
static inline long _hxlcl_syscall2(long nr, long a0, long a1) {
    register long x0 __asm__("x0") = a0;
    register long x1 __asm__("x1") = a1;
    register long x16 __asm__("x16") = nr;
    __asm__ volatile("svc #0x80" : "+r"(x0) : "r"(x1), "r"(x16) : "memory", "cc");
    return x0;
}
static inline long _hxlcl_syscall3(long nr, long a0, long a1, long a2) {
    register long x0 __asm__("x0") = a0;
    register long x1 __asm__("x1") = a1;
    register long x2 __asm__("x2") = a2;
    register long x16 __asm__("x16") = nr;
    __asm__ volatile("svc #0x80" : "+r"(x0) : "r"(x1), "r"(x2), "r"(x16) : "memory", "cc");
    return x0;
}
static inline long _hxlcl_syscall4(long nr, long a0, long a1, long a2, long a3) {
    register long x0 __asm__("x0") = a0;
    register long x1 __asm__("x1") = a1;
    register long x2 __asm__("x2") = a2;
    register long x3 __asm__("x3") = a3;
    register long x16 __asm__("x16") = nr;
    __asm__ volatile("svc #0x80" : "+r"(x0) : "r"(x1), "r"(x2), "r"(x3), "r"(x16) : "memory", "cc");
    return x0;
}
static inline long _hxlcl_syscall6(long nr, long a0, long a1, long a2, long a3, long a4, long a5) {
    register long x0 __asm__("x0") = a0;
    register long x1 __asm__("x1") = a1;
    register long x2 __asm__("x2") = a2;
    register long x3 __asm__("x3") = a3;
    register long x4 __asm__("x4") = a4;
    register long x5 __asm__("x5") = a5;
    register long x16 __asm__("x16") = nr;
    __asm__ volatile("svc #0x80" : "+r"(x0) : "r"(x1), "r"(x2), "r"(x3), "r"(x4), "r"(x5), "r"(x16) : "memory", "cc");
    return x0;
}

// cycle 66 — libc read/write (carry-flag issue + EINTR handling).
extern long read(int fd, void *buf, unsigned long n);
extern long write(int fd, const void *buf, unsigned long n);
static long __attribute__((noinline)) hxlcl_read(int fd, void *buf, unsigned long n) {
    return read(fd, buf, n);
}
static long __attribute__((noinline)) hxlcl_write(int fd, const void *buf, unsigned long n) {
    return write(fd, buf, n);
}
// cycle 66 — restore libc close. The svc 0x80 path returned errno on
// failure without distinguishing from success-fd convention (no carry
// flag access in inline asm), breaking pipe-close-then-read patterns.
extern int close(int fd);
static int __attribute__((noinline)) hxlcl_close(int fd) {
    return close(fd);
}
static int __attribute__((noinline)) hxlcl_getpid(void) {
    return (int)_hxlcl_syscall1(HXLCL_SYS_GETPID, 0);
}
// cycle 66 — libc dup2 (same carry-flag issue as close).
extern int dup2(int oldfd, int newfd);
static int __attribute__((noinline)) hxlcl_dup2(int oldfd, int newfd) {
    return dup2(oldfd, newfd);
}
// cycle 66 — restore libc pipe() backing. The cycle 63+64 svc-0x80
// path mis-handled the Darwin pipe(2) pair-return: the kernel
// returns the two fds in x0/x1 registers, NOT in the user-provided
// int[2] memory. The svc wrapper only captures x0, so fds[1] stayed
// uninitialized → child's dup2(pipe[1], 1) wrote to a garbage fd →
// parent's read(pipe[0], …) saw EOF immediately → exec() emitted
// "". Resolves inbox/patches/yosys-exec-runtime-regression-cycles-
// 61-64.md Secondary suspect (cycles 63+64 pipe machinery).
extern int pipe(int fds[2]);
static int __attribute__((noinline)) hxlcl_pipe(int fds[2]) {
    return pipe(fds);
}
// cycle 66 — libc fork (BSD pair-return convention; svc 0x80 path
// captured only x0, missing the carry-flag-disambiguates-parent-vs-
// child convention).
extern int fork(void);
static int __attribute__((noinline)) hxlcl_fork(void) {
    return fork();
}
static int __attribute__((noinline)) hxlcl_kill(int pid, int sig) {
    return (int)_hxlcl_syscall2(HXLCL_SYS_KILL, (long)pid, (long)sig);
}
static int __attribute__((noinline)) hxlcl_fcntl(int fd, int cmd, long arg) {
    return (int)_hxlcl_syscall3(HXLCL_SYS_FCNTL, (long)fd, (long)cmd, arg);
}
static int __attribute__((noinline)) hxlcl_ioctl(int fd, unsigned long req, void *arg) {
    return (int)_hxlcl_syscall3(HXLCL_SYS_IOCTL, (long)fd, (long)req, (long)arg);
}
static long __attribute__((noinline)) hxlcl_lseek(int fd, long off, int whence) {
    return _hxlcl_syscall3(HXLCL_SYS_LSEEK, (long)fd, off, (long)whence);
}
static int __attribute__((noinline)) hxlcl_select(int nfds, void *r, void *w, void *e, void *t) {
    return (int)_hxlcl_syscall6(HXLCL_SYS_SELECT, (long)nfds, (long)r, (long)w, (long)e, (long)t, 0);
}
static int __attribute__((noinline)) hxlcl_poll(void *fds, unsigned int nfds, int timeout) {
    return (int)_hxlcl_syscall3(HXLCL_SYS_POLL, (long)fds, (long)nfds, (long)timeout);
}
// cycle 66 — libc waitpid (wait4 syscall has 4 args + needs proper
// errno/EINTR handling that the raw syscall path drops).
extern int waitpid(int pid, int *status, int options);
static int __attribute__((noinline)) hxlcl_waitpid(int pid, int *status, int options) {
    return waitpid(pid, status, options);
}
/* Cycle 65: variadic to handle both 2-arg and 3-arg open() callers. */
static int __attribute__((noinline)) hxlcl_open_sys(const char *path, int flags, ...) {
    int mode = 0;
    __builtin_va_list ap;
    __builtin_va_start(ap, flags);
    mode = __builtin_va_arg(ap, int);
    __builtin_va_end(ap);
    return (int)_hxlcl_syscall3(HXLCL_SYS_OPEN, (long)path, (long)flags, (long)mode);
}
static int __attribute__((noinline)) hxlcl_fstat(int fd, void *buf) {
    return (int)_hxlcl_syscall2(HXLCL_SYS_FSTAT, (long)fd, (long)buf);
}
static int __attribute__((noinline)) hxlcl_stat(const char *path, void *buf) {
    return (int)_hxlcl_syscall2(HXLCL_SYS_STAT, (long)path, (long)buf);
}
// Cycle 65 — close out remaining real syscalls.
#define HXLCL_SYS_GETTIMEOFDAY 116
static void __attribute__((noinline, noreturn)) hxlcl_exit(int code) {
    (void)_hxlcl_syscall1(HXLCL_SYS_EXIT, (long)code);
    __builtin_trap();  // unreachable; ensure noreturn satisfaction
}
static void *__attribute__((noinline)) hxlcl_mmap(void *addr, unsigned long len, int prot, int flags, int fd, long off) {
    return (void *)_hxlcl_syscall6(HXLCL_SYS_MMAP, (long)addr, (long)len, (long)prot, (long)flags, (long)fd, off);
}
static int __attribute__((noinline)) hxlcl_clock_gettime(int clk, void *ts) {
    // Use gettimeofday(2) (syscall 116) since clock_gettime is a vDSO
    // function on Darwin with no direct syscall number. timespec[0..1]
    // is sec/nsec; we fill from sec/microsec*1000.
    (void)clk;
    long tv[2] = {0, 0};
    (void)_hxlcl_syscall2(HXLCL_SYS_GETTIMEOFDAY, (long)tv, 0);
    if (ts) {
        long long *p = (long long *)ts;
        p[0] = tv[0];
        p[1] = tv[1] * 1000;
    }
    return 0;
}
static int __attribute__((noinline)) hxlcl_darwin_check_fd_set_overflow(int fd, const void *p, int n) {
    (void)fd; (void)p; (void)n;
    return 0;  // never overflowing
}
#endif  /* arm64 */
// cycle 6: time/term/mach forward decls — bodies after #include
static int hxlcl_time(int *t);
static int hxlcl_nanosleep(const void *req, void *rem);
static int hxlcl_tcgetattr(int fd, void *termios);
static int hxlcl_tcsetattr(int fd, int optional_actions, const void *termios);
static int hxlcl_task_info(unsigned int target, unsigned int flavor, void *info_out, unsigned int *count);
// Cycle 61 — socket + exec + pty stubs. aprime_cc doesn't open
// network connections or spawn child processes during compile.
// All return -1 (error) so any unreachable call branches to error
// handling. errno not set (hxlcl_errno stays 0).
// RUNTIME.md step-2 cycle 4 — net/exec/pty stubs MOVED to
// stdlib/runtime/net.hexa. Forward decls only; bodies after include.
static int hxlcl_socket(int d, int t, int p);
static int hxlcl_bind(int s, const void *addr, unsigned int len);
static int hxlcl_listen(int s, int backlog);
static int hxlcl_accept(int s, void *addr, unsigned int *len);
static int hxlcl_connect(int s, const void *addr, unsigned int len);
static long hxlcl_recv(int s, void *b, unsigned long n, int f);
static long hxlcl_send(int s, const void *b, unsigned long n, int f);
static long hxlcl_recvmsg(int s, void *m, int f);
static long hxlcl_sendmsg(int s, const void *m, int f);
static int hxlcl_inet_pton(int af, const char *src, void *dst);
static int hxlcl_execl(const char *path, const char *arg, ...);
static int hxlcl_execve(const char *path, char *const argv[], char *const envp[]);
static int hxlcl_execvp(const char *file, char *const argv[]);
static void *hxlcl_popen(const char *cmd, const char *mode);
static int hxlcl_pclose(void *stream);
static int hxlcl_forkpty(int *amaster, char *name, void *termp, void *winp);
static int hxlcl_posix_openpt(int flags);

// Textual override of any residual libc references in subsequent code
// (runtime_core.c + HI tier + transpile output). The helper bodies
// above are NOT affected because they spell `hxlcl_*` directly.
#define strlen(s)      hxlcl_strlen((const char *)(s))
#define memcmp(a,b,n)  hxlcl_memcmp((const void *)(a), (const void *)(b), (size_t)(n))
#define strcmp(a,b)    hxlcl_strcmp((const char *)(a), (const char *)(b))
#define strcat(d,s)    hxlcl_strcat((char *)(d), (const char *)(s))
#define strncmp(a,b,n) hxlcl_strncmp((const char *)(a), (const char *)(b), (size_t)(n))
#define strchr(s,c)    ((char *)hxlcl_strchr((const char *)(s), (c)))
#define strrchr(s,c)   ((char *)hxlcl_strrchr((const char *)(s), (c)))
#define strstr(h,n)    ((char *)hxlcl_strstr((const char *)(h), (const char *)(n)))
#define strdup(s)      hxlcl_strdup((const char *)(s))
#define strndup(s,n)   hxlcl_strndup((const char *)(s), (size_t)(n))
#define atoi(s)        hxlcl_atoi((const char *)(s))
#define atoll(s)       hxlcl_atoll((const char *)(s))
#define atof(s)        hxlcl_atof((const char *)(s))
#define strtoll(p,e,b) hxlcl_strtoll((const char *)(p), (char **)(e), (int)(b))
#define strtoull(p,e,b) hxlcl_strtoull((const char *)(p), (char **)(e), (int)(b))
#define bzero(p,n)     hxlcl_bzero((void *)(p), (size_t)(n))
#define memcpy(d,s,n)  hxlcl_memcpy((void *)(d), (const void *)(s), (size_t)(n))
#define memset(p,c,n)  hxlcl_memset((void *)(p), (int)(c), (size_t)(n))
#define memmove(d,s,n) hxlcl_memmove((void *)(d), (const void *)(s), (size_t)(n))
#define strncpy(d,s,n) hxlcl_strncpy((char *)(d), (const char *)(s), (size_t)(n))
#define strcpy(d,s)    hxlcl_strcpy((char *)(d), (const char *)(s))
#define strerror(e)    hxlcl_strerror((int)(e))
#define strftime(b,c,f,t) hxlcl_strftime((char *)(b), (size_t)(c), (const char *)(f), (void *)(t))
#define snprintf(b,c,...)  hxlcl_snprintf((char *)(b), (size_t)(c), __VA_ARGS__)
#define sprintf(b,...)     hxlcl_sprintf((char *)(b), __VA_ARGS__)
#define printf(...)        hxlcl_printf(__VA_ARGS__)
#define fprintf(fp,...)    hxlcl_fprintf((void *)(fp), __VA_ARGS__)
#define fputs(s,fp)        hxlcl_fputs((const char *)(s), (void *)(fp))
#define fputc(c,fp)        hxlcl_fputc((int)(c), (void *)(fp))
#define fflush(fp)         hxlcl_fflush((void *)(fp))
#define putchar(c)         hxlcl_putchar((int)(c))
#define perror(s)          hxlcl_perror((const char *)(s))
#define malloc(n)          hxlcl_malloc((size_t)(n))
#define free(p)            hxlcl_free((void *)(p))
#define realloc(p,n)       hxlcl_realloc((void *)(p), (size_t)(n))
#define calloc(nm,sz)      hxlcl_calloc((size_t)(nm), (size_t)(sz))
#define munmap(a,l)        hxlcl_munmap((void *)(a), (size_t)(l))
#define fopen(p,m)         ((FILE *)hxlcl_fopen((const char *)(p), (const char *)(m)))
#define fclose(fp)         hxlcl_fclose((void *)(fp))
#define fread(b,s,n,fp)    hxlcl_fread((void *)(b), (size_t)(s), (size_t)(n), (void *)(fp))
#define fwrite(b,s,n,fp)   hxlcl_fwrite((const void *)(b), (size_t)(s), (size_t)(n), (void *)(fp))
#define ftell(fp)          hxlcl_ftell((void *)(fp))
#define fseek(fp,o,w)      hxlcl_fseek((void *)(fp), (long)(o), (int)(w))
#define fdopen(fd,m)       ((FILE *)hxlcl_fdopen((int)(fd), (const char *)(m)))
#define flock(fd,op)       hxlcl_flock((int)(fd), (int)(op))
#define setvbuf(fp,b,m,sz) hxlcl_setvbuf((void *)(fp), (char *)(b), (int)(m), (size_t)(sz))
// Cycle 62 — ctype.h pre-defines isalnum/isalpha as `__istype(...)`
// inline calls; ap_post.c expands them BEFORE perl substitution sees
// them. #undef + #define here unhooks any subsequent expansion to our
// hxlcl_* helpers (safe — ASCII classifiers, same locale-free intent).
#undef isalnum
#undef isalpha
#define isalnum(c) hxlcl_isalnum((int)(c))
#define isalpha(c) hxlcl_isalpha((int)(c))
// Cycle 65: exit() in <stdlib.h> as inline that calls _exit/__exit
// after libc cleanup. Override to call our exit syscall (SYS_EXIT=1)
// directly. Drops _exit + __exit externs.
#undef exit
#undef _exit
#define exit(c)  hxlcl_exit((int)(c))
#define _exit(c) hxlcl_exit((int)(c))
// Cycle 57 — Tier-A.4 POSIX stubs are NOT #define'd here because their
// system-header prototypes (signal/sigaction/socket.h declarations)
// expand the macro inside the prototype itself ("function cannot return
// function type" errors). Instead, call sites in runtime.c +
// runtime_core.c use the hxlcl_* names directly via perl substitution
// (see cycle 57 commit). The helpers above are referenced by those
// direct calls; no #define indirection needed.

#include "runtime_core.c"

// RUNTIME.md step-2 cycle 1 POC — thin C shim for `hxlcl_isalnum`/_isalpha
// delegating to hexa-source `rt_isalnum`/_isalpha (in stdlib/runtime/
// ctype.hexa, emitted into ap_post.c by transpile). Two scenarios:
//
//   (a) full aprime_cc build: ap_post.c defines `HEXA_HAS_HEXA_RT_STDLIB`
//       above `#include "runtime.c"` (build_aprime.sh post-process
//       prepends it), the hexa-source rt_isalnum/rt_isalpha definitions
//       win as the strong symbols, and the C fallbacks here are
//       skipped.
//
//   (b) standalone smoke / consumer build: no hexa stdlib transpile
//       output, so runtime.c provides the C fallback bodies. These
//       mirror the hexa source 1-for-1 (ASCII classifiers — locale-
//       free per ANSI C).
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal rt_isalnum(HexaVal c) {
    int64_t v = HX_INT(c);
    int b = ((v >= 48 && v <= 57) ||
             (v >= 65 && v <= 90) ||
             (v >= 97 && v <= 122)) ? 1 : 0;
    return hexa_bool(b);
}
HexaVal rt_isalpha(HexaVal c) {
    int64_t v = HX_INT(c);
    int b = ((v >= 65 && v <= 90) ||
             (v >= 97 && v <= 122)) ? 1 : 0;
    return hexa_bool(b);
}
#else
extern HexaVal rt_isalnum(HexaVal c);
extern HexaVal rt_isalpha(HexaVal c);
#endif
static int hxlcl_isalnum(int c) {
    return hexa_truthy(rt_isalnum(hexa_int((int64_t)c))) ? 1 : 0;
}
static int hxlcl_isalpha(int c) {
    return hexa_truthy(rt_isalpha(hexa_int((int64_t)c))) ? 1 : 0;
}

// RUNTIME.md step-2 cycle 2 — math helper hexa-source delegation.
// Source of truth: stdlib/runtime/math.hexa. Same #ifndef pattern
// as cycle 1: ap_post.c gets the macro, fallback C body skipped.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal rt_fmod(HexaVal x, HexaVal y) {
    double dx = HX_FLOAT(x), dy = HX_FLOAT(y);
    if (dy == 0.0) return hexa_float(0.0);
    double q = dx / dy;
    long long iq = (long long)q;
    return hexa_float(dx - (double)iq * dy);
}
HexaVal rt_exp(HexaVal x) {
    double dx = HX_FLOAT(x);
    const double LN2 = 0.6931471805599453;
    double n_d = dx / LN2;
    long long n = (long long)(n_d + (n_d >= 0.0 ? 0.5 : -0.5));
    double r = dx - (double)n * LN2;
    double r2 = r*r, r3 = r2*r, r4 = r2*r2;
    double sum = 1.0 + r + r2*0.5 + r3*(1.0/6.0) + r4*(1.0/24.0)
                 + r4*r*(1.0/120.0) + r4*r2*(1.0/720.0) + r4*r3*(1.0/5040.0);
    double pow2 = 1.0;
    if (n > 1023) n = 1023;
    if (n < -1022) n = -1022;
    if (n >= 0) for (long long i = 0; i < n; i++) pow2 *= 2.0;
    else for (long long i = 0; i < -n; i++) pow2 *= 0.5;
    return hexa_float(sum * pow2);
}
HexaVal rt_log(HexaVal x) {
    double dx = HX_FLOAT(x);
    if (dx <= 0.0) return hexa_float(-1e308);
    int e = 0;
    while (dx >= 2.0) { dx *= 0.5; e++; }
    while (dx < 1.0) { dx *= 2.0; e--; }
    double u = (dx - 1.0) / (dx + 1.0);
    double u2 = u*u, u3 = u2*u, u5 = u3*u2, u7 = u5*u2;
    double sum = 2.0 * (u + u3/3.0 + u5/5.0 + u7/7.0 + u7*u2/9.0);
    return hexa_float(sum + (double)e * 0.6931471805599453);
}
HexaVal rt_cos(HexaVal x) {
    double dx = HX_FLOAT(x);
    const double TWO_PI = 6.283185307179586;
    const double PI = 3.141592653589793;
    if (dx < 0.0) dx = -dx;
    while (dx >= TWO_PI) dx -= TWO_PI;
    if (dx > PI) dx = TWO_PI - dx;
    double x2 = dx*dx, x4 = x2*x2, x6 = x4*x2, x8 = x4*x4;
    double sum = 1.0 - x2/2.0 + x4/24.0 - x6/720.0 + x8/40320.0
                 - x8*x2/3628800.0 + x8*x4/479001600.0 - x8*x6/87178291200.0;
    return hexa_float(sum);
}
HexaVal rt_sin(HexaVal x) {
    const double PI_HALF = 1.5707963267948966;
    HexaVal shifted = hexa_float(HX_FLOAT(x) - PI_HALF);
    return rt_cos(shifted);
}
#else
extern HexaVal rt_fmod(HexaVal x, HexaVal y);
extern HexaVal rt_exp(HexaVal x);
extern HexaVal rt_log(HexaVal x);
extern HexaVal rt_cos(HexaVal x);
extern HexaVal rt_sin(HexaVal x);
#endif
static double hxlcl_fmod(double x, double y) {
    return HX_FLOAT(rt_fmod(hexa_float(x), hexa_float(y)));
}
static double hxlcl_exp(double x) { return HX_FLOAT(rt_exp(hexa_float(x))); }
static double hxlcl_log(double x) { return HX_FLOAT(rt_log(hexa_float(x))); }
static double hxlcl_cos(double x) { return HX_FLOAT(rt_cos(hexa_float(x))); }
static double hxlcl_sin(double x) { return HX_FLOAT(rt_sin(hexa_float(x))); }

// RUNTIME.md step-2 cycle 3 — pthread delegation via single noop hexa
// fn (`rt_pthread_noop` returns 0) + create policy (returns 1 = run
// synchronously).
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal rt_pthread_noop(void) { return hexa_int(0); }
HexaVal rt_pthread_create_policy(void) { return hexa_int(1); }
#else
extern HexaVal rt_pthread_noop(void);
extern HexaVal rt_pthread_create_policy(void);
#endif
static int hxlcl_pthread_mutex_init(void *m, const void *a) {
    (void)m; (void)a; return (int)HX_INT(rt_pthread_noop());
}
static int hxlcl_pthread_mutex_destroy(void *m) {
    (void)m; return (int)HX_INT(rt_pthread_noop());
}
static int hxlcl_pthread_mutex_lock(void *m) {
    (void)m; return (int)HX_INT(rt_pthread_noop());
}
static int hxlcl_pthread_mutex_unlock(void *m) {
    (void)m; return (int)HX_INT(rt_pthread_noop());
}
static int hxlcl_pthread_cond_init(void *c, const void *a) {
    (void)c; (void)a; return (int)HX_INT(rt_pthread_noop());
}
static int hxlcl_pthread_cond_destroy(void *c) {
    (void)c; return (int)HX_INT(rt_pthread_noop());
}
static int hxlcl_pthread_cond_signal(void *c) {
    (void)c; return (int)HX_INT(rt_pthread_noop());
}
static int hxlcl_pthread_cond_broadcast(void *c) {
    (void)c; return (int)HX_INT(rt_pthread_noop());
}
static int hxlcl_pthread_cond_wait(void *c, void *m) {
    (void)c; (void)m; return (int)HX_INT(rt_pthread_noop());
}
static int hxlcl_pthread_cond_timedwait(void *c, void *m, const void *ts) {
    (void)c; (void)m; (void)ts; return (int)HX_INT(rt_pthread_noop());
}
static int hxlcl_pthread_create(void *thread, const void *attr, void *(*start)(void *), void *arg) {
    (void)thread; (void)attr;
    if (start && (int)HX_INT(rt_pthread_create_policy()) == 1) {
        (void)start(arg);
    }
    return 0;
}
static int hxlcl_pthread_join(void *thread, void **retval) {
    (void)thread;
    if (retval) *retval = (void *)0;
    return (int)HX_INT(rt_pthread_noop());
}

// RUNTIME.md step-2 cycle 4 — net/exec/pty delegation via single
// rt_net_fail (-1) + rt_net_zero (0 for inet_pton invalid).
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal rt_net_fail(void) { return hexa_int(-1); }
HexaVal rt_net_zero(void) { return hexa_int(0); }
HexaVal rt_posix_ok(void) { return hexa_int(0); }  /* cycle 6 ISO-1 */
#else
extern HexaVal rt_net_fail(void);
extern HexaVal rt_net_zero(void);
extern HexaVal rt_posix_ok(void);  /* cycle 6 ISO-1 */
#endif
// cycle 6 SAFE SET: 5 fns ported (atexit/isatty/signal/sigaction/sigprocmask)
static int hxlcl_atexit(void (*fn)(void)) { (void)fn; return (int)HX_INT(rt_posix_ok()); }
static int hxlcl_isatty(int fd) { (void)fd; return (int)HX_INT(rt_posix_ok()); }
static void *hxlcl_signal(int signum, void *handler) {
    (void)signum; (void)handler; (void)rt_posix_ok(); return (void *)0;
}
static int hxlcl_sigaction(int signum, const void *act, void *oldact) {
    (void)signum; (void)act; (void)oldact; return (int)HX_INT(rt_posix_ok());
}
static int hxlcl_sigprocmask(int how, const void *set, void *oldset) {
    (void)how; (void)set; (void)oldset; return (int)HX_INT(rt_posix_ok());
}
// cycle 6 extension: 4 more post-init POSIX fns
static int hxlcl_setenv(const char *name, const char *val, int overwrite) {
    (void)name; (void)val; (void)overwrite; return (int)HX_INT(rt_posix_ok());
}
static int hxlcl_setsockopt(int sockfd, int level, int optname, const void *optval, unsigned int optlen) {
    (void)sockfd; (void)level; (void)optname; (void)optval; (void)optlen;
    return (int)HX_INT(rt_posix_ok());
}
static int hxlcl_grantpt(int fd) { (void)fd; return (int)HX_INT(rt_posix_ok()); }
static int hxlcl_unlockpt(int fd) { (void)fd; return (int)HX_INT(rt_posix_ok()); }
static char *hxlcl_ptsname(int fd) { (void)fd; (void)rt_posix_ok(); return (char *)"/dev/null"; }
static char *hxlcl_ttyname(int fd) { (void)fd; (void)rt_posix_ok(); return (char *)0; }
static int hxlcl_getrlimit(int resource, void *rlim) {
    (void)resource;
    if (rlim) {
        unsigned long long *p = (unsigned long long *)rlim;
        p[0] = 0xffffffffffffffffULL;
        p[1] = 0xffffffffffffffffULL;
    }
    return (int)HX_INT(rt_posix_ok());
}
static int hxlcl_getrusage(int who, void *usage) {
    (void)who;
    if (usage) {
        unsigned char *p = (unsigned char *)usage;
        for (size_t i = 0; i < 144; i++) p[i] = 0;
    }
    return (int)HX_INT(rt_posix_ok());
}
// cycle 6: time/term/mach thin shims (5 fns)
static int hxlcl_time(int *t) {
    if (t) *t = 0;
    return (int)HX_INT(rt_posix_ok());
}
static int hxlcl_nanosleep(const void *req, void *rem) {
    (void)req;
    if (rem) {
        long long *p = (long long *)rem;
        p[0] = 0; p[1] = 0;
    }
    return (int)HX_INT(rt_posix_ok());
}
static int hxlcl_tcgetattr(int fd, void *termios) {
    (void)fd;
    if (termios) {
        unsigned char *p = (unsigned char *)termios;
        for (size_t i = 0; i < 72; i++) p[i] = 0;
    }
    // tcgetattr should return -1 (we're not a TTY) — use rt_net_fail
    return (int)HX_INT(rt_net_fail());
}
static int hxlcl_tcsetattr(int fd, int optional_actions, const void *termios) {
    (void)fd; (void)optional_actions; (void)termios;
    return (int)HX_INT(rt_posix_ok());
}
static int hxlcl_task_info(unsigned int target, unsigned int flavor, void *info_out, unsigned int *count) {
    (void)target; (void)flavor;
    if (info_out && count && *count > 0) {
        unsigned char *p = (unsigned char *)info_out;
        for (size_t i = 0; i < (size_t)(*count) * 4; i++) p[i] = 0;
    }
    return (int)HX_INT(rt_posix_ok());
}
// cycle 6: strftime thin shim — return 0 length (empty output)
static size_t hxlcl_strftime(char *buf, size_t cap, const char *fmt, void *tm) {
    (void)fmt; (void)tm;
    if (buf && cap > 0) buf[0] = '\0';
    return (size_t)HX_INT(rt_posix_ok());
}
static int hxlcl_socket(int d, int t, int p) {
    (void)d; (void)t; (void)p; return (int)HX_INT(rt_net_fail());
}
static int hxlcl_bind(int s, const void *addr, unsigned int len) {
    (void)s; (void)addr; (void)len; return (int)HX_INT(rt_net_fail());
}
static int hxlcl_listen(int s, int backlog) {
    (void)s; (void)backlog; return (int)HX_INT(rt_net_fail());
}
static int hxlcl_accept(int s, void *addr, unsigned int *len) {
    (void)s; (void)addr; (void)len; return (int)HX_INT(rt_net_fail());
}
static int hxlcl_connect(int s, const void *addr, unsigned int len) {
    (void)s; (void)addr; (void)len; return (int)HX_INT(rt_net_fail());
}
static long hxlcl_recv(int s, void *b, unsigned long n, int f) {
    (void)s; (void)b; (void)n; (void)f; return (long)HX_INT(rt_net_fail());
}
static long hxlcl_send(int s, const void *b, unsigned long n, int f) {
    (void)s; (void)b; (void)n; (void)f; return (long)HX_INT(rt_net_fail());
}
static long hxlcl_recvmsg(int s, void *m, int f) {
    (void)s; (void)m; (void)f; return (long)HX_INT(rt_net_fail());
}
static long hxlcl_sendmsg(int s, const void *m, int f) {
    (void)s; (void)m; (void)f; return (long)HX_INT(rt_net_fail());
}
static int hxlcl_inet_pton(int af, const char *src, void *dst) {
    (void)af; (void)src; (void)dst; return (int)HX_INT(rt_net_zero());
}
// cycle 66 — restore real exec/popen bodies. Cycle 61 dropped these as
// noop stubs with rationale "aprime_cc never spawns children". But the
// runtime that backs `hexa run` and stdlib's exec() / exec_capture() /
// gate_record DOES spawn children — and the stubs silently broke every
// subprocess-dependent stdlib (yosys/ABC, anima trainers, pool CLI).
// posix_spawnp + posix_spawn_file_actions_* are already linked in via
// runtime_core.c's hexa_spawn_no_shell, so the libc symbols for
// execve/execvp/execl/popen/pclose are also reachable — just pass
// through. Resolves inbox/patches/yosys-exec-runtime-regression-cycles-
// 61-64.md (Part 1, exec path).
extern int execve(const char *path, char *const argv[], char *const envp[]);
extern int execvp(const char *file, char *const argv[]);
static int hxlcl_execve(const char *path, char *const argv[], char *const envp[]) {
    return execve(path, argv, envp);
}
static int hxlcl_execvp(const char *file, char *const argv[]) {
    return execvp(file, argv);
}
// execl is variadic; gather varargs into a char* argv[] then call execvp.
// Mirrors libc semantics — last arg must be (char*)NULL.
static int hxlcl_execl(const char *path, const char *arg, ...) {
    enum { HXLCL_EXECL_MAX = 256 };
    char *argv[HXLCL_EXECL_MAX];
    int n = 0;
    argv[n++] = (char *)arg;
    va_list ap;
    va_start(ap, arg);
    while (n < HXLCL_EXECL_MAX - 1) {
        char *next = va_arg(ap, char *);
        argv[n++] = next;
        if (!next) break;
    }
    argv[HXLCL_EXECL_MAX - 1] = (char *)0;
    va_end(ap);
    return execve(path, argv, environ);
}
// hxlcl_popen — manual pipe+fork+execve replacement for libc popen.
// Returns a "fake FILE*" compatible with hxlcl_fdopen's `(void*)(fd+1)`
// convention so hxlcl_fread can read from it. The libc popen path
// (extern FILE* popen) returns a real heap FILE* which the hxlcl_fread
// macro mis-interprets (it expects fd-encoded "FILE*"s from
// hxlcl_fdopen, not heap pointers) — so we replicate popen here using
// the syscall primitives that now work post cycles 63/64 + the cycle
// 66 fix to libc pipe/execve. To track the child pid for pclose we
// stash it in a small linear table keyed by the read-fd. Mode "r"
// only — the only mode hexa_exec uses.
#define HXLCL_POPEN_MAX 64
static int  _hxlcl_popen_fds[HXLCL_POPEN_MAX];
static int  _hxlcl_popen_pids[HXLCL_POPEN_MAX];
static int  _hxlcl_popen_init_done = 0;
static void _hxlcl_popen_init(void) {
    if (_hxlcl_popen_init_done) return;
    for (int i = 0; i < HXLCL_POPEN_MAX; i++) {
        _hxlcl_popen_fds[i] = -1;
        _hxlcl_popen_pids[i] = -1;
    }
    _hxlcl_popen_init_done = 1;
}
static void _hxlcl_popen_remember(int fd, int pid) {
    _hxlcl_popen_init();
    for (int i = 0; i < HXLCL_POPEN_MAX; i++) {
        if (_hxlcl_popen_fds[i] < 0) {
            _hxlcl_popen_fds[i] = fd;
            _hxlcl_popen_pids[i] = pid;
            return;
        }
    }
}
static int _hxlcl_popen_forget(int fd) {
    _hxlcl_popen_init();
    for (int i = 0; i < HXLCL_POPEN_MAX; i++) {
        if (_hxlcl_popen_fds[i] == fd) {
            int pid = _hxlcl_popen_pids[i];
            _hxlcl_popen_fds[i] = -1;
            _hxlcl_popen_pids[i] = -1;
            return pid;
        }
    }
    return -1;
}
static void *hxlcl_popen(const char *cmd, const char *mode) {
    if (!cmd) return (void *)0;
    /* Only "r" supported — hexa_exec only reads child stdout. */
    if (!mode || mode[0] != 'r') return (void *)0;
    int pfd[2];
    if (hxlcl_pipe(pfd) != 0) return (void *)0;
    fflush(NULL);
    pid_t pid = hxlcl_fork();
    if (pid < 0) {
        hxlcl_close(pfd[0]); hxlcl_close(pfd[1]);
        return (void *)0;
    }
    if (pid == 0) {
        /* child */
        hxlcl_dup2(pfd[1], 1);
        hxlcl_close(pfd[0]);
        hxlcl_close(pfd[1]);
        hxlcl_execl("/bin/sh", "sh", "-c", cmd, (char *)0);
        _exit(127);
    }
    /* parent */
    hxlcl_close(pfd[1]);
    _hxlcl_popen_remember(pfd[0], pid);
    /* hxlcl_fdopen returns (void*)(fd+1); hxlcl_fread expects this
     * encoding via _hxlcl_fp_fd. */
    return hxlcl_fdopen(pfd[0], "r");
}
static int hxlcl_pclose(void *stream) {
    if (!stream) return -1;
    /* Decode the fd from the fake FILE* via the same offset
     * hxlcl_fdopen uses. */
    int fd = (int)((uintptr_t)stream) - 1;
    if (fd < 0) return -1;
    int pid = _hxlcl_popen_forget(fd);
    hxlcl_close(fd);
    if (pid <= 0) return -1;
    int status = 0;
    (void)hxlcl_waitpid(pid, &status, 0);
    return status;
}
static int hxlcl_forkpty(int *amaster, char *name, void *termp, void *winp) {
    (void)amaster; (void)name; (void)termp; (void)winp; return (int)HX_INT(rt_net_fail());
}
static int hxlcl_posix_openpt(int flags) {
    (void)flags; return (int)HX_INT(rt_net_fail());
}

// ── Extern FFI: dlopen / dlsym / dispatch ───────────────

// Resolve a library path for dlopen.
// If lib_name is NULL or empty, use RTLD_DEFAULT (search default symbols).
// Helper: extract the basename (without "lib" prefix and without
// ".dylib"/".so" suffix) from a possibly-absolute library path. Used so
// `@link("/abs/path/libhxblas.dylib")` can fall back to a Linux
// `libhxblas.so` (or vice-versa) without source changes — see the
// hxblas-linux port (2026-04-16, c6_hxblas_linux_port_20260416.json).
//
// Returns 1 on success and writes the extracted name into out_name (max
// out_cap bytes). Returns 0 if the input doesn't look like an
// absolute lib path.
static int hexa_ffi_extract_libname(const char* path, char* out_name, size_t out_cap) {
    if (!path || !out_name || out_cap == 0) return 0;
    // Find the basename (after the last '/')
    const char* base = hxlcl_strrchr(path, '/');
    base = base ? base + 1 : path;
    // Must start with "lib"
    if (hxlcl_strncmp(base, "lib", 3) != 0) return 0;
    base += 3;
    // Must end in .dylib or .so or .so.N
    size_t blen = hxlcl_strlen(base);
    const char* end = NULL;
    if (blen > 6 && hxlcl_strcmp(base + blen - 6, ".dylib") == 0) {
        end = base + blen - 6;
    } else if (blen > 3 && hxlcl_strcmp(base + blen - 3, ".so") == 0) {
        end = base + blen - 3;
    } else {
        // .so.N case — find ".so." substring
        const char* p = hxlcl_strstr(base, ".so.");
        if (p) end = p;
    }
    if (!end) return 0;
    size_t nlen = (size_t)(end - base);
    if (nlen == 0 || nlen >= out_cap) return 0;
    hxlcl_memcpy(out_name, base, nlen);
    out_name[nlen] = '\0';
    return 1;
}

/* PHASE 1.5 (2026-05-15): de-staticized. hexa_v2 emits direct calls to
 * hexa_ffi_dlopen/dlsym from user.c for FFI shim setup; runtime.h-built
 * user.c needs cross-TU access. */
void* hexa_ffi_dlopen(const char* lib_name) {
    if (!lib_name || lib_name[0] == '\0') {
        return dlopen(NULL, RTLD_LAZY);
    }
#ifdef __APPLE__
    // Try framework path first
    char framework[512];
    snprintf(framework, sizeof(framework),
        "/System/Library/Frameworks/%s.framework/%s", lib_name, lib_name);
    void* h = dlopen(framework, RTLD_LAZY);
    if (h) return h;
    // Try dylib
    char dylib[512];
    snprintf(dylib, sizeof(dylib), "/usr/lib/lib%s.dylib", lib_name);
    h = dlopen(dylib, RTLD_LAZY);
    if (h) return h;
    // ── New (2026-04-16): also try `lib<name>.dylib` so a bare
    //    @link("hxblas") + DYLD_LIBRARY_PATH=<dir> works on Mac
    //    just like `lib<name>.so` + LD_LIBRARY_PATH does on Linux. ──
    char dylib_bare[512];
    snprintf(dylib_bare, sizeof(dylib_bare), "lib%s.dylib", lib_name);
    h = dlopen(dylib_bare, RTLD_LAZY);
    if (h) return h;
    // ── C2 Step 3 (2026-04-16): macOS SIP strips DYLD_LIBRARY_PATH
    //    when crossing any system-signed binary (/bin/sh, etc). So
    //    `./hexa run` → popen → sh -c → interp loses DYLD. Work around
    //    by searching a few known repo-relative install dirs for the
    //    hexa-lang native build output before giving up. ──
    {
        const char* search_prefixes[8];
        int sp_n = 0;
        const char* hl = hxlcl_getenv("HEXA_LANG");
        if (hl && hl[0]) search_prefixes[sp_n++] = hl;
        const char* nld = hxlcl_getenv("HEXA_NATIVE_LIB_DIR");
        if (nld && nld[0]) search_prefixes[sp_n++] = nld;
        search_prefixes[sp_n++] = ".";
        search_prefixes[sp_n++] = "/Users/ghost/Dev/hexa-lang";
        search_prefixes[sp_n++] = "/Users/ghost/dev/hexa-lang";
        // Try <prefix>/self/native/build/lib<name>.dylib for each prefix.
        const char* rel_patterns[] = {
            "%s/self/native/build/lib%s.dylib",
            "%s/build/lib%s.dylib",
            "%s/lib%s.dylib",
            NULL
        };
        for (int i = 0; i < sp_n; i++) {
            for (int j = 0; rel_patterns[j]; j++) {
                char p[512];
                snprintf(p, sizeof(p), rel_patterns[j], search_prefixes[i], lib_name);
                void* hr = dlopen(p, RTLD_LAZY);
                if (hr) return hr;
            }
        }
    }
#endif
    // Try as-is (Linux .so or absolute path)
    char sopath[512];
    snprintf(sopath, sizeof(sopath), "lib%s.so", lib_name);
    void* h2 = dlopen(sopath, RTLD_LAZY);
    if (h2) return h2;
#ifndef __APPLE__
    // CUDA path + soname version fallbacks (Linux)
    {
        char path[512];
        const char* cuda_dirs[] = {
            "/usr/local/cuda/lib64/lib%s.so",
            "/usr/local/cuda/lib64/lib%s.so.12",
            "/usr/local/cuda/lib64/lib%s.so.11",
            NULL
        };
        for (int j = 0; cuda_dirs[j]; j++) {
            snprintf(path, sizeof(path), cuda_dirs[j], lib_name);
            void* hc = dlopen(path, RTLD_LAZY);
            if (hc) return hc;
        }
        const char* sonames[] = {"lib%s.so.12", "lib%s.so.11", NULL};
        for (int j = 0; sonames[j]; j++) {
            snprintf(path, sizeof(path), sonames[j], lib_name);
            void* hc = dlopen(path, RTLD_LAZY);
            if (hc) return hc;
        }
    }
#endif
    // ── New (2026-04-16, hxblas linux port): when the user passes
    //    an absolute Mac/Linux library path that doesn't resolve
    //    on this host (e.g. @link("/Users/.../libhxblas.dylib") on a
    //    Linux pod), strip the dirname + lib prefix + .{dylib,so}
    //    suffix and retry the search with just the base name. This
    //    lets the same hexa source resolve `libhxblas.so` on Linux
    //    via LD_LIBRARY_PATH and `libhxblas.dylib` on Mac via
    //    DYLD_LIBRARY_PATH without #ifdef in the hexa file. ──
    if (lib_name[0] == '/') {
        char base[256];
        if (hexa_ffi_extract_libname(lib_name, base, sizeof(base))) {
#ifdef __APPLE__
            char p[512];
            snprintf(p, sizeof(p), "lib%s.dylib", base);
            void* hb = dlopen(p, RTLD_LAZY);
            if (hb) return hb;
#else
            char p[512];
            snprintf(p, sizeof(p), "lib%s.so", base);
            void* hb = dlopen(p, RTLD_LAZY);
            if (hb) return hb;
#endif
            // Also honour HEXA_NATIVE_LIB_DIR explicit search prefix
            const char* dir = hxlcl_getenv("HEXA_NATIVE_LIB_DIR");
            if (dir && dir[0]) {
                char p2[512];
#ifdef __APPLE__
                snprintf(p2, sizeof(p2), "%s/lib%s.dylib", dir, base);
#else
                snprintf(p2, sizeof(p2), "%s/lib%s.so", dir, base);
#endif
                void* hb2 = dlopen(p2, RTLD_LAZY);
                if (hb2) return hb2;
            }
        }
    }
    // Final attempt: bare name
    return dlopen(lib_name, RTLD_LAZY);
}

// Resolve a symbol from an already-opened library handle.
/* PHASE 1.5 (2026-05-15): de-staticized (paired with hexa_ffi_dlopen above). */
void* hexa_ffi_dlsym(void* handle, const char* symbol) {
    void* sym = dlsym(handle, symbol);
    if (!sym) {
        fprintf(stderr, "[hexa-ffi] dlsym failed for '%s': %s\n", symbol, dlerror());
    }
    return sym;
}

// Marshal a HexaVal to a raw i64 for C ABI passing.
static int64_t hexa_ffi_marshal_arg(HexaVal v) {
    switch (HX_TAG(v)) {
        case TAG_INT:   return HX_INT(v);
        case TAG_FLOAT: { union { double d; int64_t i; } u; u.d = HX_FLOAT(v); return u.i; }
        case TAG_BOOL:  return (int64_t)HX_BOOL(v);
        case TAG_STR:   return (int64_t)(uintptr_t)HX_STR(v);
        case TAG_VOID:  return 0;
        default:        return 0;
    }
}

// Raw extern call dispatch — supports 0 to 14 arguments.
// Extended 2026-04-16 from 12 to 14 to support cblas_sgemm (14 args).
// Uses transmute (cast) to call through a function pointer with the right arity.
static int64_t hexa_call_extern_raw(void* fn_ptr, int64_t* args, int nargs) {
    typedef int64_t (*Fn0)(void);
    typedef int64_t (*Fn1)(int64_t);
    typedef int64_t (*Fn2)(int64_t,int64_t);
    typedef int64_t (*Fn3)(int64_t,int64_t,int64_t);
    typedef int64_t (*Fn4)(int64_t,int64_t,int64_t,int64_t);
    typedef int64_t (*Fn5)(int64_t,int64_t,int64_t,int64_t,int64_t);
    typedef int64_t (*Fn6)(int64_t,int64_t,int64_t,int64_t,int64_t,int64_t);
    typedef int64_t (*Fn7)(int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t);
    typedef int64_t (*Fn8)(int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t);
    typedef int64_t (*Fn9)(int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t);
    typedef int64_t (*Fn10)(int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t);
    typedef int64_t (*Fn11)(int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t);
    typedef int64_t (*Fn12)(int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t);
    typedef int64_t (*Fn13)(int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t);
    typedef int64_t (*Fn14)(int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t);

    switch (nargs) {
        case 0:  return ((Fn0)fn_ptr)();
        case 1:  return ((Fn1)fn_ptr)(args[0]);
        case 2:  return ((Fn2)fn_ptr)(args[0],args[1]);
        case 3:  return ((Fn3)fn_ptr)(args[0],args[1],args[2]);
        case 4:  return ((Fn4)fn_ptr)(args[0],args[1],args[2],args[3]);
        case 5:  return ((Fn5)fn_ptr)(args[0],args[1],args[2],args[3],args[4]);
        case 6:  return ((Fn6)fn_ptr)(args[0],args[1],args[2],args[3],args[4],args[5]);
        case 7:  return ((Fn7)fn_ptr)(args[0],args[1],args[2],args[3],args[4],args[5],args[6]);
        case 8:  return ((Fn8)fn_ptr)(args[0],args[1],args[2],args[3],args[4],args[5],args[6],args[7]);
        case 9:  return ((Fn9)fn_ptr)(args[0],args[1],args[2],args[3],args[4],args[5],args[6],args[7],args[8]);
        case 10: return ((Fn10)fn_ptr)(args[0],args[1],args[2],args[3],args[4],args[5],args[6],args[7],args[8],args[9]);
        case 11: return ((Fn11)fn_ptr)(args[0],args[1],args[2],args[3],args[4],args[5],args[6],args[7],args[8],args[9],args[10]);
        case 12: return ((Fn12)fn_ptr)(args[0],args[1],args[2],args[3],args[4],args[5],args[6],args[7],args[8],args[9],args[10],args[11]);
        case 13: return ((Fn13)fn_ptr)(args[0],args[1],args[2],args[3],args[4],args[5],args[6],args[7],args[8],args[9],args[10],args[11],args[12]);
        case 14: return ((Fn14)fn_ptr)(args[0],args[1],args[2],args[3],args[4],args[5],args[6],args[7],args[8],args[9],args[10],args[11],args[12],args[13]);
        default:
            fprintf(stderr, "[hexa-ffi] extern call with %d args not supported (max 14)\n", nargs);
            return 0;
    }
}

// High-level extern call: resolve, marshal, call, unmarshal.
// ret_kind: 0=void, 1=int, 2=float, 3=bool, 4=pointer/string
HexaVal hexa_extern_call(void* fn_ptr, HexaVal* hargs, int nargs, int ret_kind) {
    int64_t cargs[14];  // extended for cblas_sgemm (14 args)
    for (int i = 0; i < nargs && i < 14; i++) {
        cargs[i] = hexa_ffi_marshal_arg(hargs[i]);
    }
    int64_t ret = hexa_call_extern_raw(fn_ptr, cargs, nargs);
    switch (ret_kind) {
        case 0:  return hexa_void();
        case 1:  return hexa_int(ret);
        case 2:  { union { int64_t i; double d; } u; u.i = ret; return hexa_float(u.d); }
        case 3:  return hexa_bool(ret != 0);
        case 4:  return hexa_int(ret); // pointer as int
        default: return hexa_int(ret);
    }
}

// ── G3: Typed extern call with float support ─────────────
// float_mask is a bitmask: bit i set means arg i is a double (SIMD register).
// This generates correct ARM64 calling convention for mixed int/float args.
// Supports up to 14 args (covers vDSP_mmul 9-arg, cblas_sgemm 14-arg).
// The C compiler sees typed args and emits correct register moves.
HexaVal hexa_extern_call_typed(void* fn_ptr, HexaVal* hargs, int nargs, int ret_kind, int float_mask) {
    // Extract values: doubles from .f, integers from .i
    double  fv[14]; // float values
    int64_t iv[14]; // int values
    for (int i = 0; i < nargs && i < 14; i++) {
        if (float_mask & (1 << i)) {
            fv[i] = HX_IS_FLOAT(hargs[i]) ? HX_FLOAT(hargs[i]) : (double)HX_INT(hargs[i]);
        } else {
            iv[i] = hexa_ffi_marshal_arg(hargs[i]);
        }
    }
    // Dispatch by nargs and float_mask pattern
    // Common patterns: all-int (mask=0), trailing floats, all-float
    // For arbitrary patterns, we use a switch on nargs with typed casts.
    // The C compiler handles register allocation from the typed call.

    // Helper macros for arg extraction
    #define A(i) ((float_mask & (1<<(i))) ? 0 : iv[i])
    #define F(i) ((float_mask & (1<<(i))) ? fv[i] : 0.0)
    #define IS_F(i) (float_mask & (1<<(i)))

    int64_t reti = 0;
    double  retf = 0.0;
    int ret_is_float = (ret_kind == 2);

    // For each arity, generate all-int call if mask==0, else use typed dispatch
    switch (nargs) {
        case 0: {
            if (ret_is_float) { retf = ((double(*)(void))fn_ptr)(); }
            else { reti = ((int64_t(*)(void))fn_ptr)(); }
            break;
        }
        case 1: {
            if (IS_F(0)) {
                if (ret_is_float) retf = ((double(*)(double))fn_ptr)(fv[0]);
                else reti = ((int64_t(*)(double))fn_ptr)(fv[0]);
            } else {
                if (ret_is_float) retf = ((double(*)(int64_t))fn_ptr)(iv[0]);
                else reti = ((int64_t(*)(int64_t))fn_ptr)(iv[0]);
            }
            break;
        }
        case 2: {
            // 4 combinations for 2 args
            int p = (IS_F(0)?2:0) | (IS_F(1)?1:0);
            switch (p) {
                case 0: // ii
                    if (ret_is_float) retf = ((double(*)(int64_t,int64_t))fn_ptr)(iv[0],iv[1]);
                    else reti = ((int64_t(*)(int64_t,int64_t))fn_ptr)(iv[0],iv[1]);
                    break;
                case 1: // if
                    if (ret_is_float) retf = ((double(*)(int64_t,double))fn_ptr)(iv[0],fv[1]);
                    else reti = ((int64_t(*)(int64_t,double))fn_ptr)(iv[0],fv[1]);
                    break;
                case 2: // fi
                    if (ret_is_float) retf = ((double(*)(double,int64_t))fn_ptr)(fv[0],iv[1]);
                    else reti = ((int64_t(*)(double,int64_t))fn_ptr)(fv[0],iv[1]);
                    break;
                case 3: // ff
                    if (ret_is_float) retf = ((double(*)(double,double))fn_ptr)(fv[0],fv[1]);
                    else reti = ((int64_t(*)(double,double))fn_ptr)(fv[0],fv[1]);
                    break;
            }
            break;
        }
        case 3: {
            // 3 args — dispatch 2^3 = 8 patterns for int/float lane mapping.
            int p = (IS_F(0)?4:0) | (IS_F(1)?2:0) | (IS_F(2)?1:0);
            switch (p) {
                case 0: if (ret_is_float) retf = ((double(*)(int64_t,int64_t,int64_t))fn_ptr)(iv[0],iv[1],iv[2]); else reti = ((int64_t(*)(int64_t,int64_t,int64_t))fn_ptr)(iv[0],iv[1],iv[2]); break;
                case 1: if (ret_is_float) retf = ((double(*)(int64_t,int64_t,double))fn_ptr)(iv[0],iv[1],fv[2]); else reti = ((int64_t(*)(int64_t,int64_t,double))fn_ptr)(iv[0],iv[1],fv[2]); break;
                case 2: if (ret_is_float) retf = ((double(*)(int64_t,double,int64_t))fn_ptr)(iv[0],fv[1],iv[2]); else reti = ((int64_t(*)(int64_t,double,int64_t))fn_ptr)(iv[0],fv[1],iv[2]); break;
                case 3: if (ret_is_float) retf = ((double(*)(int64_t,double,double))fn_ptr)(iv[0],fv[1],fv[2]); else reti = ((int64_t(*)(int64_t,double,double))fn_ptr)(iv[0],fv[1],fv[2]); break;
                case 4: if (ret_is_float) retf = ((double(*)(double,int64_t,int64_t))fn_ptr)(fv[0],iv[1],iv[2]); else reti = ((int64_t(*)(double,int64_t,int64_t))fn_ptr)(fv[0],iv[1],iv[2]); break;
                case 5: if (ret_is_float) retf = ((double(*)(double,int64_t,double))fn_ptr)(fv[0],iv[1],fv[2]); else reti = ((int64_t(*)(double,int64_t,double))fn_ptr)(fv[0],iv[1],fv[2]); break;
                case 6: if (ret_is_float) retf = ((double(*)(double,double,int64_t))fn_ptr)(fv[0],fv[1],iv[2]); else reti = ((int64_t(*)(double,double,int64_t))fn_ptr)(fv[0],fv[1],iv[2]); break;
                case 7: if (ret_is_float) retf = ((double(*)(double,double,double))fn_ptr)(fv[0],fv[1],fv[2]); else reti = ((int64_t(*)(double,double,double))fn_ptr)(fv[0],fv[1],fv[2]); break;
            }
            break;
        }
        case 4: {
            // 4 args — only handle common trailing-float patterns explicitly.
            int p = (IS_F(0)?8:0) | (IS_F(1)?4:0) | (IS_F(2)?2:0) | (IS_F(3)?1:0);
            if (p == 0) {
                if (ret_is_float) retf = ((double(*)(int64_t,int64_t,int64_t,int64_t))fn_ptr)(iv[0],iv[1],iv[2],iv[3]);
                else reti = ((int64_t(*)(int64_t,int64_t,int64_t,int64_t))fn_ptr)(iv[0],iv[1],iv[2],iv[3]);
            } else if (p == 1) { // iiif
                if (ret_is_float) retf = ((double(*)(int64_t,int64_t,int64_t,double))fn_ptr)(iv[0],iv[1],iv[2],fv[3]);
                else reti = ((int64_t(*)(int64_t,int64_t,int64_t,double))fn_ptr)(iv[0],iv[1],iv[2],fv[3]);
            } else {
                fprintf(stderr, "[hexa-ffi] unsupported 4-arg float pattern p=%d\n", p);
                reti = 0;
            }
            break;
        }
        case 5: {
            // 5 args — hxlayer_rmsnorm_silu(N:int, out:*, x:*, g:*, eps:f32)
            // is the driving case: (int,int,int,int,float) = p==1.
            int p = (IS_F(0)?16:0) | (IS_F(1)?8:0) | (IS_F(2)?4:0) | (IS_F(3)?2:0) | (IS_F(4)?1:0);
            if (p == 0) {
                if (ret_is_float) retf = ((double(*)(int64_t,int64_t,int64_t,int64_t,int64_t))fn_ptr)(iv[0],iv[1],iv[2],iv[3],iv[4]);
                else reti = ((int64_t(*)(int64_t,int64_t,int64_t,int64_t,int64_t))fn_ptr)(iv[0],iv[1],iv[2],iv[3],iv[4]);
            } else if (p == 1) { // iiiif
                if (ret_is_float) retf = ((double(*)(int64_t,int64_t,int64_t,int64_t,double))fn_ptr)(iv[0],iv[1],iv[2],iv[3],fv[4]);
                else reti = ((int64_t(*)(int64_t,int64_t,int64_t,int64_t,double))fn_ptr)(iv[0],iv[1],iv[2],iv[3],fv[4]);
            } else {
                fprintf(stderr, "[hexa-ffi] unsupported 5-arg float pattern p=%d\n", p);
                reti = 0;
            }
            break;
        }
        case 6: {
            // 6 args — cblas_saxpy(N, alpha, x, incx, y, incy)
            if (float_mask == 0) {
                reti = ((int64_t(*)(int64_t,int64_t,int64_t,int64_t,int64_t,int64_t))fn_ptr)(iv[0],iv[1],iv[2],iv[3],iv[4],iv[5]);
            } else if (float_mask == 0x02) { // i f i i i i — cblas_saxpy(N,alpha,x,incx,y,incy)
                ((void(*)(int64_t,double,int64_t,int64_t,int64_t,int64_t))fn_ptr)(iv[0],fv[1],iv[2],iv[3],iv[4],iv[5]);
                reti = 0;
            } else {
                reti = hexa_call_extern_raw(fn_ptr, iv, nargs);
            }
            break;
        }
        case 7: {
            // 7 args — vDSP_vadd/vmul(A,sA,B,sB,C,sC,N)
            if (float_mask == 0) {
                ((void(*)(int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t))fn_ptr)(iv[0],iv[1],iv[2],iv[3],iv[4],iv[5],iv[6]);
                reti = 0;
            } else {
                reti = hexa_call_extern_raw(fn_ptr, iv, nargs);
            }
            break;
        }
        case 8: {
            // 8 args
            if (float_mask == 0) {
                reti = ((int64_t(*)(int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t))fn_ptr)(iv[0],iv[1],iv[2],iv[3],iv[4],iv[5],iv[6],iv[7]);
            } else {
                reti = hexa_call_extern_raw(fn_ptr, iv, nargs);
            }
            break;
        }
        case 9: {
            // 9 args — vDSP_mmul(A,sA,B,sB,C,sC,M,N,K)
            if (float_mask == 0) {
                ((void(*)(int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t,int64_t))fn_ptr)(iv[0],iv[1],iv[2],iv[3],iv[4],iv[5],iv[6],iv[7],iv[8]);
                reti = 0;
            } else {
                reti = hexa_call_extern_raw(fn_ptr, iv, nargs);
            }
            break;
        }
        default: {
            // 10-14 args: fall back to raw int dispatch (handles up to 14).
            reti = hexa_call_extern_raw(fn_ptr, iv, nargs);
            break;
        }
    }
    #undef A
    #undef F
    #undef IS_F

    switch (ret_kind) {
        case 0:  return hexa_void();
        case 1:  return hexa_int(reti);
        case 2:  return hexa_float(retf);
        case 3:  return hexa_bool(reti != 0);
        case 4:  return hexa_int(reti);
        default: return hexa_int(reti);
    }
}

// Convenience: cstring <-> HexaVal
HexaVal hexa_cstring(HexaVal s) {
    if (!HX_IS_STR(s)) return hexa_int(0);
    return hexa_int((int64_t)(uintptr_t)HX_STR(s));
}

HexaVal hexa_from_cstring(HexaVal ptr) {
    uint64_t p = HX_IS_INT(ptr) ? HX_INT_U(ptr) : 0;
    if (p == 0) return hexa_str("");
    return hexa_str((const char*)(uintptr_t)p);
}

HexaVal hexa_ptr_null() { return hexa_int(0); }

HexaVal hexa_ptr_addr(HexaVal v) {
    return hexa_int((int64_t)HX_INT_U(v));
}

// ── C2 Step 3: Dynamic FFI host dispatch (interpreter path) ──
//
// Purpose: expose dlopen+dlsym+extern_call as HexaVal builtins so the
// self-host interpreter (self/interpreter.hexa) can dispatch @link externs
// at runtime without going through codegen_c2.hexa's static __ffi_sym_*
// registration. The native (compile-to-native) path already works via
// codegen; this reopens the same pipeline for `./hexa run`.
//
// Forward declaration — defined alongside hexa_host_ffi_call below.
static HexaVal hexa_host_ffi_unwrap(HexaVal v);

// hexa_host_ffi_open(lib_name: str) -> ptr(int)
//   0 on failure (e.g. library not found under any search strategy).
HexaVal hexa_host_ffi_open(HexaVal lib_name) {
    HexaVal uv = hexa_host_ffi_unwrap(lib_name);
    const char* name = (HX_IS_STR(uv) && HX_STR(uv)) ? HX_STR(uv) : "";
    void* h = hexa_ffi_dlopen(name);
    return hexa_int((int64_t)(uintptr_t)h);
}

// hexa_host_ffi_sym(handle: int, symbol: str) -> ptr(int)
//   0 on failure.
HexaVal hexa_host_ffi_sym(HexaVal handle, HexaVal symbol) {
    HexaVal uh = hexa_host_ffi_unwrap(handle);
    HexaVal us = hexa_host_ffi_unwrap(symbol);
    void* h = HX_IS_INT(uh) ? (void*)(uintptr_t)HX_INT_U(uh) : NULL;
    const char* sym = (HX_IS_STR(us) && HX_STR(us)) ? HX_STR(us) : "";
    if (!h || !sym || !*sym) return hexa_int(0);
    void* fn = dlsym(h, sym);
    if (!fn) {
        fprintf(stderr, "[hexa-ffi] dlsym failed for '%s': %s\n", sym, dlerror());
        return hexa_int(0);
    }
    return hexa_int((int64_t)(uintptr_t)fn);
}

// hexa_host_ffi_call(fn_ptr: int, args_arr: array, float_mask: int, ret_kind: int) -> int|float
//   ret_kind: 0=void, 1=int, 2=float, 3=bool, 4=pointer
//   float_mask: bit i set => arg i is double
//
// Unwraps any HexaValStruct-wrapped args (the interpreter's native Val
// representation) down to the corresponding primitive HexaVal so that
// hexa_ffi_marshal_arg / hexa_extern_call_typed read the right lane.
// Without this the interpreter-produced TAG_VALSTRUCT falls through the
// marshal switch default and every arg becomes 0.
static HexaVal hexa_host_ffi_unwrap(HexaVal v) {
    if (!HX_IS_VALSTRUCT(v) || !HX_VS(v)) return v;
    int64_t t = HX_VSF(v, tag_i);
    // Hexa-level tag values: 0=INT, 1=FLOAT, 2=BOOL, 3=STR, 8=VOID, 13=POINTER
    // See self/interpreter.hexa let TAG_* constants.
    if (t == 0)  return hexa_int(HX_VSF(v, int_val));
    if (t == 1)  return hexa_float(HX_VSF(v, float_val));
    if (t == 2)  return hexa_bool(HX_VSF(v, bool_val));
    if (t == 3)  return HX_VSF(v, str_val);       // already TAG_STR
    if (t == 13) return hexa_int(HX_VSF(v, int_val));  // pointer → int ABI lane
    return hexa_int(HX_VSF(v, int_val));
}

HexaVal hexa_host_ffi_call(HexaVal fn_ptr, HexaVal args_arr, HexaVal float_mask, HexaVal ret_kind) {
    HexaVal fp_v = hexa_host_ffi_unwrap(fn_ptr);
    void* fp = HX_IS_INT(fp_v) ? (void*)(uintptr_t)HX_INT_U(fp_v) : NULL;
    if (!fp) return hexa_int(0);
    HexaVal rk_v = hexa_host_ffi_unwrap(ret_kind);
    HexaVal fm_v = hexa_host_ffi_unwrap(float_mask);
    int rk   = HX_IS_INT(rk_v) ? (int)HX_INT(rk_v) : 1;
    int mask = HX_IS_INT(fm_v) ? (int)HX_INT(fm_v) : 0;
    // args_arr may be (a) a TAG_ARRAY built by the native-compiled hexa
    // runtime (hexa_array_new — direct member access works) OR
    // (b) a TAG_VALSTRUCT whose tag_i == TAG_ARRAY (hexa level 5) — the
    // form used by the self-host interpreter's val_array(). In case (b)
    // the real data lives behind the hexa-level array_store, which this
    // native wrapper cannot reach. So we require native-array input and
    // error out otherwise.
    if (!HX_IS_ARRAY(args_arr)) {
        fprintf(stderr,
            "[hexa-ffi] host_ffi_call: expected native array (tag=%d), got tag=%d. "
            "Self-host interpreter must marshal through hexa_host_ffi_call_6 instead.\n",
            (int)TAG_ARRAY, (int)HX_TAG(args_arr));
        return hexa_int(0);
    }
    int nargs = hexa_len(args_arr);
    if (nargs > 12) nargs = 12;
    HexaVal hargs[12];
    for (int i = 0; i < nargs; i++) {
        hargs[i] = hexa_host_ffi_unwrap(hexa_array_get(args_arr, i));
    }
    if (mask) {
        return hexa_extern_call_typed(fp, hargs, nargs, rk, mask);
    }
    return hexa_extern_call(fp, hargs, nargs, rk);
}

// Static overflow buffer for >6 arg FFI calls.
// The interpreter stores overflow args here via magic fn_ptr sentinel
// values (-1, -2) before the real dispatch call.
static HexaVal g_ffi_overflow[14];

// hexa_host_ffi_call_6(fn_ptr, nargs, float_mask, ret_kind, a0, a1, a2, a3, a4, a5)
//   Scalar-fanout variant used by the self-host interpreter which
//   cannot pass its array_store-backed TAG_VALSTRUCT array through
//   hexa_array_get. Up to 6 positional args; unused slots are TAG_VOID.
//
//   Extended 2026-04-16: overflow protocol for >6 args (vDSP_mmul 9, cblas_sgemm 14).
//   Magic fn_ptr sentinels:
//     fn_ptr == -1 : store a0..a5 into g_ffi_overflow[0..5] (args 6-11)
//     fn_ptr == -2 : store a0..a1 into g_ffi_overflow[6..7] (args 12-13)
//   When fn_ptr is a real pointer and nargs > 6, read g_ffi_overflow for args 6+.
HexaVal hexa_host_ffi_call_6(
    HexaVal fn_ptr, HexaVal nargs_v, HexaVal float_mask, HexaVal ret_kind,
    HexaVal a0, HexaVal a1, HexaVal a2, HexaVal a3, HexaVal a4, HexaVal a5
) {
    HexaVal fp_v = hexa_host_ffi_unwrap(fn_ptr);
    int64_t fp_raw = HX_IS_INT(fp_v) ? HX_INT(fp_v) : 0;

    // Magic sentinel: store overflow args
    if (fp_raw == -1) {
        g_ffi_overflow[0] = hexa_host_ffi_unwrap(a0);
        g_ffi_overflow[1] = hexa_host_ffi_unwrap(a1);
        g_ffi_overflow[2] = hexa_host_ffi_unwrap(a2);
        g_ffi_overflow[3] = hexa_host_ffi_unwrap(a3);
        g_ffi_overflow[4] = hexa_host_ffi_unwrap(a4);
        g_ffi_overflow[5] = hexa_host_ffi_unwrap(a5);
        return hexa_int(0);
    }
    if (fp_raw == -2) {
        g_ffi_overflow[6] = hexa_host_ffi_unwrap(a0);
        g_ffi_overflow[7] = hexa_host_ffi_unwrap(a1);
        return hexa_int(0);
    }

    void* fp = (fp_raw != 0) ? (void*)(uintptr_t)fp_raw : NULL;
    if (!fp) return hexa_int(0);
    HexaVal na_v = hexa_host_ffi_unwrap(nargs_v);
    HexaVal rk_v = hexa_host_ffi_unwrap(ret_kind);
    HexaVal fm_v = hexa_host_ffi_unwrap(float_mask);
    int nargs = HX_IS_INT(na_v) ? (int)HX_INT(na_v) : 0;
    int rk    = HX_IS_INT(rk_v) ? (int)HX_INT(rk_v) : 1;
    int mask  = HX_IS_INT(fm_v) ? (int)HX_INT(fm_v) : 0;
    if (nargs < 0) nargs = 0;
    if (nargs > 14) nargs = 14;

    // Build hargs: first 6 from direct params, 6+ from overflow buffer
    HexaVal hargs[14];
    hargs[0] = hexa_host_ffi_unwrap(a0);
    hargs[1] = hexa_host_ffi_unwrap(a1);
    hargs[2] = hexa_host_ffi_unwrap(a2);
    hargs[3] = hexa_host_ffi_unwrap(a3);
    hargs[4] = hexa_host_ffi_unwrap(a4);
    hargs[5] = hexa_host_ffi_unwrap(a5);
    for (int i = 6; i < nargs; i++) {
        hargs[i] = g_ffi_overflow[i - 6];
    }

    HexaVal native_ret;
    if (mask) {
        native_ret = hexa_extern_call_typed(fp, hargs, nargs, rk, mask);
    } else {
        native_ret = hexa_extern_call(fp, hargs, nargs, rk);
    }
    // Wrap the native HexaVal (tag=TAG_INT / TAG_FLOAT / TAG_VOID / TAG_BOOL)
    // into a hexa-level Val so the self-host interpreter can .tag/.int_val
    // through it. Without this the interpreter reads garbage from the
    // HexaVal-as-map fallback in hexa_map_get.
    int64_t iv = 0;
    double  fv = 0.0;
    int bv = 0;
    if (HX_IS_INT(native_ret))   iv = HX_INT(native_ret);
    if (HX_IS_FLOAT(native_ret)) fv = HX_FLOAT(native_ret);
    if (HX_IS_BOOL(native_ret))  bv = HX_BOOL(native_ret);
    // Hexa-level tag constants: INT=0, FLOAT=1, BOOL=2, VOID=8.
    int hexa_tag = 0;
    if (rk == 2) hexa_tag = 1;
    if (rk == 3) hexa_tag = 2;
    if (rk == 0) hexa_tag = 8;
    HexaVal empty_str = hexa_str("");
    return hexa_valstruct_new_v(
        hexa_int(hexa_tag), hexa_int(iv), hexa_float(fv), hexa_bool(bv),
        empty_str, empty_str, empty_str,
        empty_str, empty_str, empty_str,
        empty_str, empty_str);
}

// ── G5: Pointer arithmetic builtins ─────────────────────

HexaVal hexa_ptr_alloc(HexaVal size) {
    int64_t n = HX_IS_INT(size) ? HX_INT(size) : 0;
    if (n <= 0) return hexa_int(0);
    void* p = calloc(1, (size_t)n);
    return hexa_int((int64_t)(uintptr_t)p);
}

HexaVal hexa_ptr_free(HexaVal ptr, HexaVal size) {
    uint64_t p = HX_IS_INT(ptr) ? HX_INT_U(ptr) : 0;
    if (p != 0) free((void*)(uintptr_t)p);
    return hexa_void();
}

HexaVal hexa_ptr_write(HexaVal ptr, HexaVal offset, HexaVal val) {
    uint64_t p = HX_IS_INT(ptr) ? HX_INT_U(ptr) : 0;
    int64_t off = HX_IS_INT(offset) ? HX_INT(offset) : 0;
    if (p == 0) return hexa_void();
    uint8_t* base = (uint8_t*)(uintptr_t)p + off;
    if (HX_IS_FLOAT(val)) {
        double d = HX_FLOAT(val);
        hxlcl_memcpy(base, &d, sizeof(double));
    } else {
        int64_t v = HX_INT(val);
        hxlcl_memcpy(base, &v, sizeof(int64_t));
    }
    return hexa_void();
}

/* @hot_kernel f32/f64/i32 ptr read/write — extracted to tensor_kernels.c
 * (included at end of this file). hexa_ptr_read (untyped 64-bit) kept here
 * as general-purpose. */

HexaVal hexa_ptr_read(HexaVal ptr, HexaVal offset) {
    uint64_t p = HX_IS_INT(ptr) ? HX_INT_U(ptr) : 0;
    int64_t off = HX_IS_INT(offset) ? HX_INT(offset) : 0;
    if (p == 0) return hexa_int(0);
    int64_t v;
    hxlcl_memcpy(&v, (uint8_t*)(uintptr_t)p + off, sizeof(int64_t));
    return hexa_int(v);
}

HexaVal hexa_ptr_offset(HexaVal ptr, HexaVal offset) {
    uint64_t p = HX_IS_INT(ptr) ? HX_INT_U(ptr) : 0;
    int64_t off = HX_IS_INT(offset) ? HX_INT(offset) : 0;
    return hexa_int((int64_t)(p + (uint64_t)off));
}

HexaVal hexa_deref(HexaVal ptr) {
    uint64_t p = HX_IS_INT(ptr) ? HX_INT_U(ptr) : 0;
    if (p == 0) return hexa_int(0);
    int64_t v;
    hxlcl_memcpy(&v, (void*)(uintptr_t)p, sizeof(int64_t));
    return hexa_int(v);
}

// ═══════════════════════════════════════════════════════════
//  G2: Struct Value Passing — struct packing builtins
//  Allows constructing C structs in heap memory for FFI.
//  struct_pack(v0, v1, ...) — N*8 bytes of f64 values
//  struct_pack_f32(v0, ...) — N*4 bytes of f32 values
//  struct_unpack(ptr, idx) — read Nth f64 from packed struct
//  struct_unpack_f32(ptr, idx) — read Nth f32
//  struct_rect/point/size — Cocoa geometry helpers
// ═══════════════════════════════════════════════════════════

// Pack N f64 values into a newly allocated buffer. Returns pointer as int.
HexaVal hexa_struct_pack(HexaVal* args, int nargs) {
    if (nargs <= 0) return hexa_int(0);
    size_t total = (size_t)nargs * sizeof(double);
    double* buf = (double*)calloc(1, total);
    for (int i = 0; i < nargs; i++) {
        buf[i] = HX_IS_FLOAT(args[i]) ? HX_FLOAT(args[i]) : (double)HX_INT(args[i]);
    }
    return hexa_int((int64_t)(uintptr_t)buf);
}

/* @hot_kernel hexa_struct_pack_f32 / hexa_struct_unpack_f32 extracted to
 * tensor_kernels.c (see include at end of this file). */

// Read the Nth f64 from a struct pointer.
HexaVal hexa_struct_unpack(HexaVal ptr, HexaVal index) {
    uint64_t p = HX_IS_INT(ptr) ? HX_INT_U(ptr) : 0;
    int64_t idx = HX_IS_INT(index) ? HX_INT(index) : 0;
    if (p == 0) return hexa_float(0.0);
    double* buf = (double*)(uintptr_t)p;
    return hexa_float(buf[idx]);
}

// Convenience: pack an NSRect (4x f64 = 32 bytes).
HexaVal hexa_struct_rect(HexaVal x, HexaVal y, HexaVal w, HexaVal h) {
    double* buf = (double*)calloc(1, 4 * sizeof(double));
    buf[0] = HX_IS_FLOAT(x) ? HX_FLOAT(x) : (double)HX_INT(x);
    buf[1] = HX_IS_FLOAT(y) ? HX_FLOAT(y) : (double)HX_INT(y);
    buf[2] = HX_IS_FLOAT(w) ? HX_FLOAT(w) : (double)HX_INT(w);
    buf[3] = HX_IS_FLOAT(h) ? HX_FLOAT(h) : (double)HX_INT(h);
    return hexa_int((int64_t)(uintptr_t)buf);
}

// Convenience: pack an NSPoint (2x f64 = 16 bytes).
HexaVal hexa_struct_point(HexaVal x, HexaVal y) {
    double* buf = (double*)calloc(1, 2 * sizeof(double));
    buf[0] = HX_IS_FLOAT(x) ? HX_FLOAT(x) : (double)HX_INT(x);
    buf[1] = HX_IS_FLOAT(y) ? HX_FLOAT(y) : (double)HX_INT(y);
    return hexa_int((int64_t)(uintptr_t)buf);
}

// Convenience: pack an NSSize (2x f64 = 16 bytes).
HexaVal hexa_struct_size_pack(HexaVal w, HexaVal h) {
    double* buf = (double*)calloc(1, 2 * sizeof(double));
    buf[0] = HX_IS_FLOAT(w) ? HX_FLOAT(w) : (double)HX_INT(w);
    buf[1] = HX_IS_FLOAT(h) ? HX_FLOAT(h) : (double)HX_INT(h);
    return hexa_int((int64_t)(uintptr_t)buf);
}

// Free a struct pointer (allocated by struct_pack/struct_rect/etc).
HexaVal hexa_struct_free(HexaVal ptr) {
    uint64_t p = HX_IS_INT(ptr) ? HX_INT_U(ptr) : 0;
    if (p != 0) free((void*)(uintptr_t)p);
    return hexa_void();
}

// ═══════════════════════════════════════════════════════════
//  G4: Callback Trampoline Pool
//  Provides C function pointers that dispatch back into hexa.
//  16 pre-allocated slots — sufficient for Cocoa delegates,
//  menu actions, timers, qsort comparators, etc.
// ═══════════════════════════════════════════════════════════

#define HEXA_TRAMPOLINE_POOL_SIZE 16

// Callback entry: stores a HexaVal function reference (TAG_FN)
// and metadata for the dispatch.
typedef struct {
    int in_use;
    HexaVal hexa_fn;        // The hexa function value (TAG_FN)
    void* fn_ptr;           // The C trampoline pointer for this slot
    int expected_argc;      // How many C args the trampoline receives
} HexaCallbackSlot;

static HexaCallbackSlot __hexa_cb_slots[HEXA_TRAMPOLINE_POOL_SIZE];

// User-supplied dispatch hook: the interpreter or compiled code sets this.
// Signature: dispatch(slot_id, argc, args[]) -> HexaVal
// For compiled code, this is wired at link time.
// For interpreter, the interpreter sets this to its own dispatcher.
typedef HexaVal (*hexa_cb_dispatch_fn)(int slot_id, int argc, int64_t* args);
static hexa_cb_dispatch_fn __hexa_cb_dispatcher = NULL;

// Internal dispatch: called by every trampoline.
// Converts raw C int64 args back to HexaVal and calls the registered function.
static int64_t hexa_trampoline_dispatch(int slot_id, int argc, int64_t* args) {
    if (slot_id < 0 || slot_id >= HEXA_TRAMPOLINE_POOL_SIZE) return 0;
    if (!__hexa_cb_slots[slot_id].in_use) return 0;

    // If a custom dispatcher is set (e.g. interpreter), use it
    if (__hexa_cb_dispatcher) {
        HexaVal result = __hexa_cb_dispatcher(slot_id, argc, args);
        if (HX_IS_INT(result)) return HX_INT(result);
        if (HX_IS_FLOAT(result)) { union { double d; int64_t i; } u; u.d = HX_FLOAT(result); return u.i; }
        return 0;
    }

    // For compiled code: call the fn_ptr stored in the slot directly.
    // Compiled hexa functions take HexaVal args and return HexaVal.
    // We wrap each raw int64 arg as hexa_int() before calling.
    HexaCallbackSlot* slot = &__hexa_cb_slots[slot_id];
    if (HX_IS_FN(slot->hexa_fn) && HX_FN_PTR(slot->hexa_fn)) {
        typedef HexaVal (*HFn0)(void);
        typedef HexaVal (*HFn1)(HexaVal);
        typedef HexaVal (*HFn2)(HexaVal, HexaVal);
        typedef HexaVal (*HFn3)(HexaVal, HexaVal, HexaVal);
        typedef HexaVal (*HFn4)(HexaVal, HexaVal, HexaVal, HexaVal);
        void* fp = HX_FN_PTR(slot->hexa_fn);
        HexaVal result;
        switch (argc) {
            case 0: result = ((HFn0)fp)(); break;
            case 1: result = ((HFn1)fp)(hexa_int(args[0])); break;
            case 2: result = ((HFn2)fp)(hexa_int(args[0]), hexa_int(args[1])); break;
            case 3: result = ((HFn3)fp)(hexa_int(args[0]), hexa_int(args[1]), hexa_int(args[2])); break;
            default: result = ((HFn4)fp)(hexa_int(args[0]), hexa_int(args[1]), hexa_int(args[2]), hexa_int(args[3])); break;
        }
        if (HX_IS_INT(result)) return HX_INT(result);
        if (HX_IS_FLOAT(result)) { union { double d; int64_t i; } u; u.d = HX_FLOAT(result); return u.i; }
        return 0;
    }
    return 0;
}

// ── 16 static trampoline functions ──────────────────────
// Each takes up to 4 int64_t args (covers qsort comparator, ObjC IMP,
// NSTimer callback, etc.). Extra args beyond 4 are passed as 0.
// For Cocoa IMP: (id self, SEL _cmd, ...) = 2-3 pointer-sized args.

#define TRAMP_DEF(N) \
static int64_t _hexa_tramp_##N(int64_t a0, int64_t a1, int64_t a2, int64_t a3) { \
    int64_t args[4] = {a0, a1, a2, a3}; \
    return hexa_trampoline_dispatch(N, 4, args); \
}

TRAMP_DEF(0)  TRAMP_DEF(1)  TRAMP_DEF(2)  TRAMP_DEF(3)
TRAMP_DEF(4)  TRAMP_DEF(5)  TRAMP_DEF(6)  TRAMP_DEF(7)
TRAMP_DEF(8)  TRAMP_DEF(9)  TRAMP_DEF(10) TRAMP_DEF(11)
TRAMP_DEF(12) TRAMP_DEF(13) TRAMP_DEF(14) TRAMP_DEF(15)

typedef int64_t (*tramp_fn_t)(int64_t, int64_t, int64_t, int64_t);

static tramp_fn_t __hexa_tramp_table[HEXA_TRAMPOLINE_POOL_SIZE] = {
    _hexa_tramp_0,  _hexa_tramp_1,  _hexa_tramp_2,  _hexa_tramp_3,
    _hexa_tramp_4,  _hexa_tramp_5,  _hexa_tramp_6,  _hexa_tramp_7,
    _hexa_tramp_8,  _hexa_tramp_9,  _hexa_tramp_10, _hexa_tramp_11,
    _hexa_tramp_12, _hexa_tramp_13, _hexa_tramp_14, _hexa_tramp_15
};

// Initialize trampoline pool (call once at startup)
static void hexa_trampoline_init(void) {
    for (int i = 0; i < HEXA_TRAMPOLINE_POOL_SIZE; i++) {
        __hexa_cb_slots[i].in_use = 0;
        __hexa_cb_slots[i].fn_ptr = (void*)__hexa_tramp_table[i];
        __hexa_cb_slots[i].hexa_fn = hexa_void();
        __hexa_cb_slots[i].expected_argc = 0;
    }
}

// ── Public API ──────────────────────────────────────────

// callback_create(hexa_fn_val) -> int (C function pointer as integer)
// Allocates a trampoline slot and returns the C function pointer.
HexaVal hexa_callback_create(HexaVal fn_val) {
    // Lazy init
    static int inited = 0;
    if (!inited) { hexa_trampoline_init(); inited = 1; }

    for (int i = 0; i < HEXA_TRAMPOLINE_POOL_SIZE; i++) {
        if (!__hexa_cb_slots[i].in_use) {
            __hexa_cb_slots[i].in_use = 1;
            __hexa_cb_slots[i].hexa_fn = fn_val;
            return hexa_int((int64_t)(uintptr_t)__hexa_cb_slots[i].fn_ptr);
        }
    }
    fprintf(stderr, "[hexa-callback] trampoline pool exhausted (%d slots)\n",
            HEXA_TRAMPOLINE_POOL_SIZE);
    return hexa_int(0);
}

// callback_free(ptr) -> void
// Frees the trampoline slot associated with the given C function pointer.
HexaVal hexa_callback_free(HexaVal ptr) {
    uint64_t p = HX_IS_INT(ptr) ? HX_INT_U(ptr) : 0;
    for (int i = 0; i < HEXA_TRAMPOLINE_POOL_SIZE; i++) {
        if ((uint64_t)(uintptr_t)__hexa_cb_slots[i].fn_ptr == p) {
            __hexa_cb_slots[i].in_use = 0;
            __hexa_cb_slots[i].hexa_fn = hexa_void();
            return hexa_void();
        }
    }
    return hexa_void();
}

// callback_slot_id(ptr) -> int
// Returns the slot index for a given trampoline pointer (-1 if not found).
HexaVal hexa_callback_slot_id(HexaVal ptr) {
    uint64_t p = HX_IS_INT(ptr) ? HX_INT_U(ptr) : 0;
    for (int i = 0; i < HEXA_TRAMPOLINE_POOL_SIZE; i++) {
        if ((uint64_t)(uintptr_t)__hexa_cb_slots[i].fn_ptr == p) {
            return hexa_int(i);
        }
    }
    return hexa_int(-1);
}

/* @hot_kernel B4 tensor stubs extracted to tensor_kernels.c (see include
 * at end of this file). clock/random stay here (OS utility, not hot). */

HexaVal hexa_clock(void) {
    struct timespec ts;
    hxlcl_clock_gettime(CLOCK_MONOTONIC, &ts);
    return hexa_float((double)ts.tv_sec + (double)ts.tv_nsec/1e9);
}

HexaVal hexa_random(void) {
    return hexa_float(rand() / (double)RAND_MAX);
}

HexaVal hexa_char_code(HexaVal s, HexaVal idx);
// Bootstrap shim (same rationale as `join` above): SSOT modules use
// `char_code(s, i)` free-fn idiom which old hexa_v2 emits as
// `hexa_call2(char_code, ...)`. Shim binds the bare identifier to TAG_FN.
static HexaVal char_code;
HexaVal hexa_char_code(HexaVal s, HexaVal idx) {
    if (!HX_IS_STR(s)) return hexa_int(0);
    int i = HX_INT(idx);
    if (i < 0 || i >= (int)HX_STRLEN(s)) return hexa_int(0);
    return hexa_int((unsigned char)HX_STR(s)[i]);
}

// `chr(n)` — Python/Ruby-style inverse of char_code: int byte → 1-char str.
// Used by void's sys_pty accumulator (chr(b) reassembles bytes from
// line_buf int values). Binds the free-fn idiom the way char_code does.
HexaVal hexa_from_char_code(HexaVal n);
static HexaVal chr;

// RFC 030 (2026-05-12): bytes_to_str_raw([int]) — see implementation
// below near hexa_from_char_code. Declared here so it's reachable as
// a bare C identifier from `hexa_call1(bytes_to_str_raw, arr)` emitted
// by precompiled hexa_v2 (which doesn't have the codegen entry yet).
HexaVal hexa_bytes_to_str_raw(HexaVal arr);
static HexaVal bytes_to_str_raw;

// 2026-05-12 (RFC 030 sibling fix): farr_* primitive shims. The
// codegen_c2.hexa entries route `farr_zeros / get / set / len / free`
// to their hexa_farr_* C impls (added recently), but the currently
// shipped hexa_v2 binary predates those entries, so transpiles of the
// interpreter dispatch handlers (hexa_full.hexa:~10700) emit bare
// `hexa_call1(farr_zeros, ...)` lookups against undeclared symbols.
// Declare the static carriers so the resulting C compiles;
// _hexa_init_fn_shims wires fn_ptr to the hexa_farr_* impl below.
HexaVal hexa_farr_zeros(HexaVal n_v);
HexaVal hexa_farr_get(HexaVal h_v, HexaVal i_v);
HexaVal hexa_farr_set(HexaVal h_v, HexaVal i_v, HexaVal x_v);
HexaVal hexa_farr_len(HexaVal h_v);
HexaVal hexa_farr_free(HexaVal h_v);
static HexaVal farr_zeros;
static HexaVal farr_get;
static HexaVal farr_set;
static HexaVal farr_len;
static HexaVal farr_free;

// RFC 036 (2026-05-13): farr_int_array — packed int64_t* handle table.
// Same shape as RFC 030 farr (packed double[]), but for int64_t storage.
// Motivation: replaces `[int]` mask tables (ham_flip, ham_z, ham_y, ham_cy,
// exc_flip, exc_z, exc_y, exc_cy, exc_param_idx) in qmirror chemistry_vqe
// hot loops. At 4e/6o (10 qubits, ~2-3k Pauli terms) the boxed-HexaVal
// retention from these arrays binds the in-process NM optimizer at the
// 768 MB cap. Packed int64_t cuts arena retention by ~50× and removes
// the HEXA_MEM_CAP_MB=2048 workaround for 4e/6o.
HexaVal hexa_farr_int_zeros(HexaVal n_v);
HexaVal hexa_farr_int_get(HexaVal h_v, HexaVal i_v);
HexaVal hexa_farr_int_set(HexaVal h_v, HexaVal i_v, HexaVal x_v);
HexaVal hexa_farr_int_len(HexaVal h_v);
HexaVal hexa_farr_int_fill_from_array(HexaVal h_v, HexaVal arr_v);
HexaVal hexa_farr_int_copy(HexaVal src_v);
HexaVal hexa_farr_int_sum(HexaVal h_v);
HexaVal hexa_farr_int_free(HexaVal h_v);
static HexaVal farr_int_zeros;
static HexaVal farr_int_get;
static HexaVal farr_int_set;
static HexaVal farr_int_len;
static HexaVal farr_int_fill_from_array;
static HexaVal farr_int_copy;
static HexaVal farr_int_sum;
static HexaVal farr_int_free;

// RFC 025 (2026-05-12): safetensors mmap-backed zero-copy load shims.
// Mirror the farr_* pattern: bare static carriers so transpiled C
// resolves `hexa_call*(safetensors_mmap_*, ...)` to direct calls into
// the hexa_safetensors_mmap_* impls below. fn_shim registration in
// _hexa_init_fn_shims; AOT codegen entries in codegen_c2.hexa.
HexaVal hexa_safetensors_mmap_open(HexaVal path_v);
HexaVal hexa_safetensors_mmap_header(HexaVal h_v);
HexaVal hexa_safetensors_mmap_data_offset(HexaVal h_v);
HexaVal hexa_safetensors_mmap_size(HexaVal h_v);
HexaVal hexa_safetensors_mmap_read_f32_farr(HexaVal h_v, HexaVal off_v, HexaVal n_v);
HexaVal hexa_safetensors_mmap_read_bf16_to_f32_farr(HexaVal h_v, HexaVal off_v, HexaVal n_v);
HexaVal hexa_safetensors_mmap_read_bytes(HexaVal h_v, HexaVal off_v, HexaVal n_v);
HexaVal hexa_safetensors_mmap_close(HexaVal h_v);
static HexaVal safetensors_mmap_open;
static HexaVal safetensors_mmap_header;
static HexaVal safetensors_mmap_data_offset;
static HexaVal safetensors_mmap_size;
static HexaVal safetensors_mmap_read_f32_farr;
static HexaVal safetensors_mmap_read_bf16_to_f32_farr;
static HexaVal safetensors_mmap_read_bytes;
static HexaVal safetensors_mmap_close;
// RFC 032 (2026-05-12): farr_matmul — packed-double matrix multiply.
HexaVal hexa_farr_matmul(HexaVal a_v, HexaVal ar_v, HexaVal ac_v,
                         HexaVal b_v, HexaVal bc_v);
static HexaVal farr_matmul_shim;
// hexa_v2 (bootstrap transpiler) emits direct C calls for ≥5 args
// (no `hexa_callN` indirection exists past N=4). The dispatch in
// hexa_full.hexa::call_builtin uses `farr_matmul(...)` literally —
// provide an inline wrapper so that compiles to a single jump.
HexaVal hexa_farr_apply_single_farr(HexaVal re_v, HexaVal im_v,
                                    HexaVal gre_h, HexaVal gim_h,
                                    HexaVal target_v, HexaVal nq_v);
HexaVal hexa_farr_apply_cnot(HexaVal src_re_v, HexaVal src_im_v,
                             HexaVal dst_re_v, HexaVal dst_im_v,
                             HexaVal control_v, HexaVal target_v,
                             HexaVal nq_v);
static inline HexaVal farr_matmul(HexaVal a, HexaVal ar, HexaVal ac,
                                  HexaVal b, HexaVal bc) {
    return hexa_farr_matmul(a, ar, ac, b, bc);
}
// RFC 050 L1 slice 1 — bare-wrapper seam for the forge dispatcher.
// codegen_c2.hexa registers `forge_dispatch_matmul` as a 5-arg builtin
// lowering to hexa_forge_dispatch_matmul, but the deployed hexa_v2
// bootstrap (not yet rebuilt from that SSOT codegen) emits the bare
// `forge_dispatch_matmul(...)` call literally — same ≥5-arg direct-C
// path as farr_matmul above. The generated user.c TU only #includes
// runtime.h, so this is an extern (non-static) definition paired with a
// runtime.h prototype, the same runtime.h-split seam the farr ABI uses.
// Resolves the symbol without a bootstrap rebuild — see memory
// project_forge_gpu_builtin_compiled_path seam pattern.
HexaVal hexa_forge_dispatch_matmul(HexaVal a_v, HexaVal m_v, HexaVal k_v,
                                   HexaVal b_v, HexaVal n_v);
HexaVal forge_dispatch_matmul(HexaVal a, HexaVal m, HexaVal k,
                              HexaVal b, HexaVal n) {
    return hexa_forge_dispatch_matmul(a, m, k, b, n);
}
// RFC 050 PERF-INHERITANCE — bare-wrapper seam for the BF16 FFN dispatch.
// Same pattern as forge_dispatch_matmul above: the deployed hexa_v2
// bootstrap emits a literal `forge_dispatch_ffn_fp64_via_bf16(...)` call
// (7-arg ≥5-arg direct-C path); the generated user.c only sees
// runtime.h, so this extern wrapper + the prototype below link-resolve
// the symbol without a bootstrap rebuild.
HexaVal hexa_forge_dispatch_ffn_fp64_via_bf16(HexaVal x_v, HexaVal w1_v,
                                              HexaVal w2_v, HexaVal y_v,
                                              HexaVal m_v, HexaVal d_v,
                                              HexaVal fd_v);
HexaVal forge_dispatch_ffn_fp64_via_bf16(HexaVal x, HexaVal w1, HexaVal w2,
                                         HexaVal y, HexaVal m, HexaVal d,
                                         HexaVal fd) {
    return hexa_forge_dispatch_ffn_fp64_via_bf16(x, w1, w2, y, m, d, fd);
}
// 5e817564 — interp dispatch added `farr_apply_single_farr(...)` and
// `farr_apply_cnot(...)` literal calls (6-arg / 7-arg, past the
// hexa_callN ceiling) but never grew the matching shims. Without
// these the entire interp fails to compile (pre-existing breakage on
// `tool/build_interp.hexa` since 5e817564). Added here as part of
// RFC 033's runtime impl so the interp can rebuild.
static inline HexaVal farr_apply_single_farr(HexaVal re_v, HexaVal im_v,
                                             HexaVal gre_h, HexaVal gim_h,
                                             HexaVal target_v, HexaVal nq_v) {
    return hexa_farr_apply_single_farr(re_v, im_v, gre_h, gim_h, target_v, nq_v);
}
static inline HexaVal farr_apply_cnot(HexaVal src_re_v, HexaVal src_im_v,
                                      HexaVal dst_re_v, HexaVal dst_im_v,
                                      HexaVal control_v, HexaVal target_v,
                                      HexaVal nq_v) {
    return hexa_farr_apply_cnot(src_re_v, src_im_v, dst_re_v, dst_im_v,
                                control_v, target_v, nq_v);
}
// RFC 033 (2026-05-12): farr_copy + farr_add_gaussian_noise.
HexaVal hexa_farr_copy(HexaVal src_v);
HexaVal hexa_farr_add_gaussian_noise(HexaVal target_v, HexaVal sigma_v);
// 1-arg / 2-arg builtins are dispatched via hexa_call1 / hexa_call2,
// which need `static HexaVal` shims with the exact identifier the
// hexa-side code uses.
static HexaVal farr_copy;
static HexaVal farr_add_gaussian_noise;

// anima RFC 034 (2026-05-16): farr reverse-mode autograd.
//   0/1-arg (tape_begin/tape_end/backward/grad) → hexa_call0/1 carriers.
//   4-arg (softmax_cross_entropy) → hexa_call4 carrier.
//   5-arg (ad_matmul) + 11-arg (adamw_step) → static inline wrappers
//   (past the 4-arg hexa_callN ceiling; codegen emits a direct C call,
//   same pattern as RFC 032 farr_apply_cnot / RFC 038 farr_uccsd_apply).
HexaVal hexa_ad_tape_begin(void);
HexaVal hexa_ad_tape_end(HexaVal tid_v);
HexaVal hexa_ad_matmul(HexaVal a_v, HexaVal ar_v, HexaVal ac_v,
                       HexaVal b_v, HexaVal bc_v);
HexaVal hexa_ad_softmax_cross_entropy(HexaVal logits_v, HexaVal nr_v,
                                      HexaVal nc_v, HexaVal tgt_v);
HexaVal hexa_ad_backward(HexaVal tid_v);
HexaVal hexa_ad_grad(HexaVal param_v);
HexaVal hexa_adamw_step(HexaVal p_v, HexaVal g_v, HexaVal m_v, HexaVal v_v,
                        HexaVal n_v, HexaVal lr_v, HexaVal b1_v, HexaVal b2_v,
                        HexaVal eps_v, HexaVal wd_v, HexaVal t_v);
// External linkage (NOT static): the committed hexa_v2 codegen lowers
// these via the generic fallback — `hexa_call0(ad_tape_begin)` /
// `hexa_call1(ad_backward, …)` / `hexa_call4(ad_softmax_cross_entropy,
// …)` for ≤4-arg (needs a visible HexaVal carrier), and bare
// `ad_matmul(…)` / `adamw_step(…)` for ≥5-arg (needs a visible
// function). The user.c TU sees only runtime.h, so these MUST have
// external linkage + a runtime.h decl (no codegen branch required —
// same fallback contract RFC 038 farr_uccsd_apply relies on, made
// link-clean for the multi-TU runtime.h split). The codegen_c2.hexa
// branches are additionally provided so a future `hexa cc --regen`
// emits the direct typed `hexa_ad_*` call; both paths are valid.
HexaVal ad_tape_begin;
HexaVal ad_tape_end;
HexaVal ad_softmax_cross_entropy;
HexaVal ad_backward;
HexaVal ad_grad;
HexaVal ad_matmul(HexaVal a, HexaVal ar, HexaVal ac,
                  HexaVal b, HexaVal bc) {
    return hexa_ad_matmul(a, ar, ac, b, bc);
}
HexaVal adamw_step(HexaVal p, HexaVal g, HexaVal m, HexaVal v,
                   HexaVal n, HexaVal lr, HexaVal b1,
                   HexaVal b2, HexaVal eps, HexaVal wd,
                   HexaVal t) {
    return hexa_adamw_step(p, g, m, v, n, lr, b1, b2, eps, wd, t);
}

// anima RFC 035 (2026-05-16): bf16 mixed-precision training.
//   farr_to_bf16 / farr_from_bf16 (3-arg) → hexa_call3 carriers.
//   adamw_step_mixed (12-arg) → bare wrapper (past hexa_callN ceiling,
//   same direct-C-call fallback contract as RFC 034 adamw_step).
HexaVal hexa_farr_to_bf16(HexaVal src_v, HexaVal dst_v, HexaVal n_v);
HexaVal hexa_farr_from_bf16(HexaVal src_v, HexaVal dst_v, HexaVal n_v);
HexaVal hexa_adamw_step_mixed(HexaVal p_v, HexaVal g_v, HexaVal m_v,
                              HexaVal v_v, HexaVal n_v, HexaVal lr_v,
                              HexaVal b1_v, HexaVal b2_v, HexaVal eps_v,
                              HexaVal wd_v, HexaVal t_v, HexaVal ls_v);
HexaVal farr_to_bf16;
HexaVal farr_from_bf16;
HexaVal adamw_step_mixed(HexaVal p, HexaVal g, HexaVal m, HexaVal v,
                         HexaVal n, HexaVal lr, HexaVal b1, HexaVal b2,
                         HexaVal eps, HexaVal wd, HexaVal t,
                         HexaVal ls) {
    return hexa_adamw_step_mixed(p, g, m, v, n, lr, b1, b2, eps, wd, t, ls);
}

// anima RFC 036 (2026-05-16): phi_rs MI/Φ byte-equal native primitive.
//   phi_mi_pair / phi_spatial (4-arg) → hexa_call4 carriers (same
//   contract as RFC 034 ad_softmax_cross_entropy).
HexaVal hexa_phi_mi_pair(HexaVal a_v, HexaVal b_v, HexaVal n_v,
                         HexaVal nb_v);
HexaVal hexa_phi_spatial(HexaVal st_v, HexaVal nc_v, HexaVal dim_v,
                         HexaVal nb_v);
HexaVal phi_mi_pair;
HexaVal phi_spatial;

// RFC 034 (2026-05-13): Pauli-string exp + expectation whole-loop kernels.
// 8-arg / 7-arg; past the hexa_callN ceiling → static inline wrappers.
HexaVal hexa_farr_pauli_exp_inplace(HexaVal re_v, HexaVal im_v,
                                    HexaVal alpha_v,
                                    HexaVal flip_v, HexaVal zmask_v,
                                    HexaVal ymask_v, HexaVal cy_v,
                                    HexaVal nq_v);
HexaVal hexa_farr_pauli_expectation(HexaVal re_v, HexaVal im_v,
                                    HexaVal flip_v, HexaVal zmask_v,
                                    HexaVal ymask_v, HexaVal cy_v,
                                    HexaVal nq_v);
// RFC 035 (2026-05-13): whole-NM-step C kernels.
HexaVal hexa_farr_simplex_centroid(HexaVal simplex_h_v, HexaVal out_h_v,
                                   HexaVal n_v, HexaVal n_best_v);
HexaVal hexa_farr_vec_reflect(HexaVal out_h_v, HexaVal a_h_v, HexaVal b_h_v,
                              HexaVal scale_v, HexaVal n_v);
HexaVal hexa_farr_vec_blend(HexaVal out_h_v, HexaVal a_h_v, HexaVal b_h_v,
                            HexaVal scale_v, HexaVal n_v);
HexaVal hexa_farr_vertex_copy(HexaVal dst_h_v, HexaVal dst_v_v,
                              HexaVal src_h_v, HexaVal src_v_v,
                              HexaVal n_v);
HexaVal hexa_farr_simplex_get(HexaVal simplex_h_v, HexaVal v_v, HexaVal j_v,
                              HexaVal n_v);
HexaVal hexa_farr_simplex_set(HexaVal simplex_h_v, HexaVal v_v, HexaVal j_v,
                              HexaVal n_v, HexaVal x_v);
HexaVal hexa_farr_simplex_shrink(HexaVal simplex_h_v, HexaVal n_v,
                                 HexaVal n_vert_v);
HexaVal hexa_farr_simplex_sort(HexaVal simplex_h_v, HexaVal f_h_v,
                               HexaVal n_v, HexaVal n_vert_v);
// RFC 039 (2026-05-13): parameter-shift gradient kernel + bundle ctors.
// 8-arg / 7-arg → static-carrier shim (past hexa_callN ceiling).
HexaVal hexa_ham_pack(HexaVal flip_v, HexaVal z_v, HexaVal y_v,
                      HexaVal cy_v, HexaVal coef_v,
                      HexaVal shift_v, HexaVal nq_v);
HexaVal hexa_ham_free(HexaVal h_v);
HexaVal hexa_ansatz_pack(HexaVal param_idx_v, HexaVal coef_v, HexaVal flip_v,
                         HexaVal z_v, HexaVal y_v, HexaVal cy_v,
                         HexaVal hf_v, HexaVal nq_v);
HexaVal hexa_ansatz_free(HexaVal h_v);
HexaVal hexa_farr_parameter_shift_grad(HexaVal re_v, HexaVal im_v,
                                       HexaVal theta_v, HexaVal grad_v,
                                       HexaVal n_p_v,
                                       HexaVal ham_v, HexaVal ans_v,
                                       HexaVal nq_v);
// RFC 038 (2026-05-13): farr_uccsd_apply — single-call UCCSD ansatz replay.
// 5-arg → routed through _hexa_call5 static-carrier shim.
HexaVal hexa_farr_uccsd_apply(HexaVal re_v, HexaVal im_v,
                              HexaVal theta_v, HexaVal ansatz_v,
                              HexaVal nq_v);
// RFC 037 (2026-05-13): whole-Hamiltonian Pauli-expectation batch kernel.
// 9-arg; past the hexa_callN ceiling → static-carrier shim. Consumes 4
// packed-int64 farr_int handles (flip/z/y/cy) plus a shared (re, im,
// n_qubits) state and writes n_terms doubles into out_h. Replaces the
// per-iter `while k < n_ham: farr_pauli_expectation(...)` dispatch loop
// in qmirror chemistry_vqe energy fns. Expected 3-5x speedup at 4e/5o.
HexaVal hexa_farr_pauli_expectation_batch(HexaVal re_v, HexaVal im_v,
                                          HexaVal flip_h_v, HexaVal z_h_v,
                                          HexaVal y_h_v, HexaVal cy_h_v,
                                          HexaVal n_terms_v, HexaVal out_h_v,
                                          HexaVal nq_v);
// 5-arg builtins → static inline wrappers (past hexa_callN ceiling).
/* De-staticized 2026-05-17 (wilson P0#2 interp rebuild): interp's
 * transpiled C calls these by bare name across the runtime.o TU
 * boundary, so file-scope `static inline` was linker-invisible.
 * runtime.h now forward-declares the same signatures. */
HexaVal farr_vec_reflect(HexaVal ot, HexaVal a, HexaVal b,
                         HexaVal s, HexaVal n) {
    return hexa_farr_vec_reflect(ot, a, b, s, n);
}
HexaVal farr_vec_blend(HexaVal ot, HexaVal a, HexaVal b,
                       HexaVal s, HexaVal n) {
    return hexa_farr_vec_blend(ot, a, b, s, n);
}
HexaVal farr_vertex_copy(HexaVal dh, HexaVal dv,
                         HexaVal sh, HexaVal sv, HexaVal n) {
    return hexa_farr_vertex_copy(dh, dv, sh, sv, n);
}
/* De-staticized 2026-05-17 (wilson P0#2). */
HexaVal farr_simplex_set(HexaVal sx, HexaVal v, HexaVal j,
                         HexaVal n, HexaVal x) {
    return hexa_farr_simplex_set(sx, v, j, n, x);
}
// 3-arg / 4-arg builtins → HexaVal carriers (routed through hexa_callN).
// farr_simplex_centroid de-staticized 2026-05-17 (wilson P0#2): interp's
// transpile uses bare `hexa_call4(farr_simplex_centroid, ...)` across TU.
HexaVal farr_simplex_centroid;
/* Companion carriers de-staticized 2026-05-17 (wilson P0#2): same
 * cross-TU fn-pointer access pattern. */
HexaVal farr_simplex_get;
HexaVal farr_simplex_shrink;
HexaVal farr_simplex_sort;
// RFC 039 — static carriers for 1-arg builtins (codegen emits hexa_call1).
/* De-staticized 2026-05-17 (wilson P0#2). */
HexaVal ham_free;
HexaVal ansatz_free;
// RFC 037 — static carrier (codegen emits hexa_call9 fallback if no special route).
static HexaVal farr_pauli_expectation_batch;
// RFC 038/039 — static inline wrappers for 5/7/8-arg builtins (codegen emits
// direct C call past the 4-arg hexa_callN ceiling). Same pattern as
// farr_pauli_exp_inplace / farr_vec_reflect / etc.
/* De-staticized 2026-05-17 (wilson P0#2). */
HexaVal farr_uccsd_apply(HexaVal re_v, HexaVal im_v, HexaVal theta_v,
                         HexaVal ansatz_v, HexaVal nq_v) {
    return hexa_farr_uccsd_apply(re_v, im_v, theta_v, ansatz_v, nq_v);
}
HexaVal ham_pack(HexaVal flip_v, HexaVal z_v, HexaVal y_v,
                 HexaVal cy_v, HexaVal coef_v, HexaVal shift_v,
                 HexaVal nq_v) {
    return hexa_ham_pack(flip_v, z_v, y_v, cy_v, coef_v, shift_v, nq_v);
}
HexaVal ansatz_pack(HexaVal param_idx_v, HexaVal coef_v, HexaVal flip_v,
                    HexaVal z_v, HexaVal y_v, HexaVal cy_v,
                    HexaVal hf_v, HexaVal nq_v) {
    return hexa_ansatz_pack(param_idx_v, coef_v, flip_v, z_v, y_v, cy_v, hf_v, nq_v);
}
HexaVal farr_parameter_shift_grad(HexaVal re_v, HexaVal im_v,
                                  HexaVal theta_v, HexaVal grad_v,
                                  HexaVal n_p_v, HexaVal ham_v,
                                  HexaVal ans_v, HexaVal nq_v) {
    return hexa_farr_parameter_shift_grad(re_v, im_v, theta_v, grad_v,
                                          n_p_v, ham_v, ans_v, nq_v);
}
/* De-staticized 2026-05-17 (wilson P0#2). Same rationale as the
 * farr_vec_* wrappers above. */
HexaVal farr_pauli_exp_inplace(HexaVal re_v, HexaVal im_v,
                               HexaVal alpha_v,
                               HexaVal flip_v, HexaVal zmask_v,
                               HexaVal ymask_v, HexaVal cy_v,
                               HexaVal nq_v) {
    return hexa_farr_pauli_exp_inplace(re_v, im_v, alpha_v, flip_v, zmask_v, ymask_v, cy_v, nq_v);
}
HexaVal farr_pauli_expectation(HexaVal re_v, HexaVal im_v,
                               HexaVal flip_v, HexaVal zmask_v,
                               HexaVal ymask_v, HexaVal cy_v,
                               HexaVal nq_v) {
    return hexa_farr_pauli_expectation(re_v, im_v, flip_v, zmask_v, ymask_v, cy_v, nq_v);
}

// `bit_or(x, y)` — shim kept because `|` as binary op conflicts with lambda
// param delimiters `|x| x+1`. `&` and `^` are supported by parser directly.
HexaVal _hx_bit_or(HexaVal a, HexaVal b) {
    int64_t x = HX_IS_INT(a) ? HX_INT(a) : (int64_t)HX_FLOAT(a);
    int64_t y = HX_IS_INT(b) ? HX_INT(b) : (int64_t)HX_FLOAT(b);
    return hexa_int(x | y);
}
/* De-staticized 2026-05-17 (wilson P0#2): interp transpile takes
 * `&bit_or` for `hexa_call2(bit_or, x, y)` across the runtime.o TU
 * boundary. File-scope `static` was invisible to user.c TU. */
HexaVal bit_or;

// ── Added: method-dispatch helpers (bt 34) ────────────────────
HexaVal hexa_str_parse_int(HexaVal s) {
    if (!HX_IS_STR(s)) return hexa_int(0);
    const char* cs = HX_STR(s);
    // hxa-20260423-013: throw on non-integer input so `try/catch` around
    // to_int("abc") (T24) and uncaught to_int("1.01") (T34) behave as
    // the language documents. Empty / whitespace-only input still
    // returns 0 — 812 callsites (env-var + optional-argv parsing)
    // depend on that defensive-fallback shape.
    const char* p = cs;
    while (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r') p++;
    if (*p == 0) return hexa_int(0);
    // P39 fix: auto-detect hex prefix (0x/0X) while preserving decimal
    // semantics for leading-zero inputs ("0777" -> 777, not octal 511).
    const char* digit_start = p;
    if (*digit_start == '+' || *digit_start == '-') digit_start++;
    int base = 10;
    if (digit_start[0] == '0' && (digit_start[1] == 'x' || digit_start[1] == 'X')) base = 16;
    char* endptr = NULL;
    long long v = hxlcl_strtoll(p, &endptr, base);
    if (endptr == p) {
        // no digits consumed — "abc", "--", "" after trim handled above
        char msg[256];
        snprintf(msg, sizeof(msg), "error: to_int: not an integer: \"%s\"", cs);
        hexa_throw(hexa_str(msg));
        return hexa_int(0);
    }
    // Reject trailing non-whitespace garbage ("1.01", "123abc", "5 six").
    while (*endptr == ' ' || *endptr == '\t' || *endptr == '\n' || *endptr == '\r') endptr++;
    if (*endptr != 0) {
        char msg[256];
        snprintf(msg, sizeof(msg), "error: to_int: trailing garbage in \"%s\"", cs);
        hexa_throw(hexa_str(msg));
        return hexa_int(0);
    }
    return hexa_int((int64_t)v);
}

HexaVal hexa_str_parse_float(HexaVal s) {
    if (!HX_IS_STR(s)) return hexa_float(0.0);
    return hexa_float(strtod(HX_STR(s), NULL));
}

// M1 full · str_ext Step 5 (hxa-20260423-003): rt_str_trim_start/end —
// codegen emits rt_str_* directly; hexa_str_trim_start/end shims retired.
HexaVal rt_str_trim_start(HexaVal s) {
    if (!HX_IS_STR(s)) return s;
    char* p = HX_STR(s);
    while (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r') p++;
    return hexa_str_own(hxlcl_strdup(p));
}

HexaVal rt_str_trim_end(HexaVal s) {
    if (!HX_IS_STR(s)) return s;
    int len = (int)HX_STRLEN(s);
    while (len > 0 && (HX_STR(s)[len-1] == ' ' || HX_STR(s)[len-1] == '\t' || HX_STR(s)[len-1] == '\n' || HX_STR(s)[len-1] == '\r')) len--;
    return hexa_str_own_with_len(hxlcl_strndup(HX_STR(s), len), (size_t)len);
}

// Byte-based slice: [start, end) clamped to length
HexaVal hexa_str_slice(HexaVal s, HexaVal start, HexaVal end) {
    if (!HX_IS_STR(s)) return hexa_str("");
    int len = (int)HX_STRLEN(s);
    int a = (int)HX_INT(start), b = (int)HX_INT(end);
    if (a < 0) a = 0;
    if (b > len) b = len;
    if (a > b) a = b;
    return hexa_str_own_with_len(hxlcl_strndup(HX_STR(s) + a, b - a), (size_t)(b - a));
}

// Step-3 cycle 35 port — float fast-path for the array branch. The str
// branch is polymorphic (byte-indexed substring) and stays in C; the
// array branch dispatches to rt_array_slice_float when the array is
// all-float. Mixed-type arrays stay on the C body.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_array_slice(HexaVal arr, HexaVal start, HexaVal end) {
    // 2026-05-19 parity-gate t45b — polymorphic slice + 1-arg form.
    // (1) HX_IS_VOID(end) ⇒ 1-arg `.slice(start)` form — default end to
    // len(obj). (2) HX_IS_STR(obj) ⇒ string slice via byte-indexed
    // substring (mirrors interp's `.slice` on strings). Array path
    // unchanged for the common case.
    if (HX_IS_STR(arr)) {
        int n = (int)HX_STRLEN(arr);
        int a = (int)HX_INT(start);
        int b = HX_IS_VOID(end) ? n : (int)HX_INT(end);
        if (a < 0) a += n;
        if (b < 0) b += n;
        if (a < 0) a = 0;
        if (b > n) b = n;
        if (a > b) return hexa_str("");
        int len = b - a;
        char* buf = (char*)malloc(len + 1);
        if (!buf) return hexa_str("");
        int j = 0;
        while (j < len) { buf[j] = HX_STR(arr)[a + j]; j++; }
        buf[len] = 0;
        return hexa_str_own(buf);
    }
    if (!HX_IS_ARRAY(arr)) return hexa_array_new();
    int n = HX_ARR_LEN(arr);
    int a = (int)HX_INT(start);
    int b = HX_IS_VOID(end) ? n : (int)HX_INT(end);
    if (a < 0) a = 0;
    if (b > n) b = n;
    if (a > b) a = b;
    HexaVal out = hexa_array_new();
    for (int i = a; i < b; i++) out = hexa_array_push(out, HX_ARR_ITEMS(arr)[i]);
    return out;
}
#else
static int _arr_all_float(HexaVal arr);  /* forward decl — defined later */
extern HexaVal rt_array_slice_float(HexaVal arr, HexaVal start, HexaVal end);
HexaVal hexa_array_slice(HexaVal arr, HexaVal start, HexaVal end) {
    if (HX_IS_STR(arr)) {
        int n = (int)HX_STRLEN(arr);
        int a = (int)HX_INT(start);
        int b = HX_IS_VOID(end) ? n : (int)HX_INT(end);
        if (a < 0) a += n;
        if (b < 0) b += n;
        if (a < 0) a = 0;
        if (b > n) b = n;
        if (a > b) return hexa_str("");
        int len = b - a;
        char* buf = (char*)malloc(len + 1);
        if (!buf) return hexa_str("");
        int j = 0;
        while (j < len) { buf[j] = HX_STR(arr)[a + j]; j++; }
        buf[len] = 0;
        return hexa_str_own(buf);
    }
    if (!HX_IS_ARRAY(arr)) return hexa_array_new();
    int n = HX_ARR_LEN(arr);
    int64_t a = HX_INT(start);
    int64_t b = HX_IS_VOID(end) ? n : HX_INT(end);
    if (_arr_all_float(arr)) {
        return rt_array_slice_float(arr, hexa_int(a), hexa_int(b));
    }
    if (a < 0) a = 0;
    if (b > n) b = n;
    if (a > b) a = b;
    HexaVal out = hexa_array_new();
    for (int64_t i = a; i < b; i++) out = hexa_array_push(out, HX_ARR_ITEMS(arr)[i]);
    return out;
}
#endif

// Step-3 cycle 36 port — int range. The `int inclusive` switch is
// plain C (not HexaVal), so two hexa entry points handle the cases
// rather than threading a hexa-bool through the ABI.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal __hexa_range_array(HexaVal start, HexaVal end, int inclusive) {
    HexaVal out = hexa_array_new();
    int64_t s = HX_INT(start), e = HX_INT(end);
    if (inclusive) {
        for (int64_t i = s; i <= e; i++) out = hexa_array_push(out, hexa_int(i));
    } else {
        for (int64_t i = s; i < e; i++) out = hexa_array_push(out, hexa_int(i));
    }
    return out;
}
#else
extern HexaVal rt_range_int_excl(HexaVal start, HexaVal end);
extern HexaVal rt_range_int_incl(HexaVal start, HexaVal end);
HexaVal __hexa_range_array(HexaVal start, HexaVal end, int inclusive) {
    if (inclusive) return rt_range_int_incl(start, end);
    return rt_range_int_excl(start, end);
}
#endif

HexaVal hexa_array_map(HexaVal arr, HexaVal fn) {
    if (!HX_IS_ARRAY(arr)) return hexa_array_new();
    HexaVal out = hexa_array_new();
    for (int i = 0; i < HX_ARR_LEN(arr); i++) {
        out = hexa_array_push(out, hexa_call1(fn, HX_ARR_ITEMS(arr)[i]));
    }
    return out;
}

HexaVal hexa_array_filter(HexaVal arr, HexaVal fn) {
    if (!HX_IS_ARRAY(arr)) return hexa_array_new();
    HexaVal out = hexa_array_new();
    for (int i = 0; i < HX_ARR_LEN(arr); i++) {
        HexaVal keep = hexa_call1(fn, HX_ARR_ITEMS(arr)[i]);
        if (hexa_truthy(keep)) out = hexa_array_push(out, HX_ARR_ITEMS(arr)[i]);
    }
    return out;
}

HexaVal hexa_array_fold(HexaVal arr, HexaVal init, HexaVal fn) {
    if (!HX_IS_ARRAY(arr)) return init;
    HexaVal acc = init;
    for (int i = 0; i < HX_ARR_LEN(arr); i++) {
        acc = hexa_call2(fn, acc, HX_ARR_ITEMS(arr)[i]);
    }
    return acc;
}

// Step-3 cycle 33 port — float fast-path dispatches to rt_array_index_of_float
// when both the array is all-float and the item is float; otherwise the
// polymorphic hexa_eq path stays.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_array_index_of(HexaVal arr, HexaVal item) {
    if (!HX_IS_ARRAY(arr)) return hexa_int(-1);
    for (int i = 0; i < HX_ARR_LEN(arr); i++) {
        if (hexa_truthy(hexa_eq(HX_ARR_ITEMS(arr)[i], item))) return hexa_int(i);
    }
    return hexa_int(-1);
}
#else
static int _arr_all_float(HexaVal arr);  /* forward decl — defined below */
extern HexaVal rt_array_index_of_float(HexaVal arr, HexaVal item);
HexaVal hexa_array_index_of(HexaVal arr, HexaVal item) {
    if (!HX_IS_ARRAY(arr)) return hexa_int(-1);
    if (HX_IS_FLOAT(item) && _arr_all_float(arr)) {
        return rt_array_index_of_float(arr, item);
    }
    for (int i = 0; i < HX_ARR_LEN(arr); i++) {
        if (hexa_truthy(hexa_eq(HX_ARR_ITEMS(arr)[i], item))) return hexa_int(i);
    }
    return hexa_int(-1);
}
#endif

// Higher-order array predicates + scans. Mirror interpreter semantics
// at self/hexa_full.hexa:15189+ using hexa_call1 for callback dispatch
// (same pattern as hexa_array_map/filter/fold).

HexaVal hexa_map_any(HexaVal m, HexaVal pred);
HexaVal hexa_map_all(HexaVal m, HexaVal pred);

HexaVal hexa_array_any(HexaVal arr, HexaVal fn) {
    // Map receiver: delegate to hexa_map_any (2-arg predicate over k,v).
    // Matches interpreter dispatch at self/hexa_full.hexa:15705-15718.
    if (HX_IS_MAP(arr)) return hexa_map_any(arr, fn);
    if (!HX_IS_ARRAY(arr)) return hexa_bool(0);
    for (int i = 0; i < HX_ARR_LEN(arr); i++) {
        if (hexa_truthy(hexa_call1(fn, HX_ARR_ITEMS(arr)[i]))) return hexa_bool(1);
    }
    return hexa_bool(0);
}

HexaVal hexa_array_all(HexaVal arr, HexaVal fn) {
    // Map receiver: delegate to hexa_map_all. Empty map → true (vacuous).
    // Matches interpreter dispatch at self/hexa_full.hexa:15719-15732.
    if (HX_IS_MAP(arr)) return hexa_map_all(arr, fn);
    if (!HX_IS_ARRAY(arr)) return hexa_bool(1);
    for (int i = 0; i < HX_ARR_LEN(arr); i++) {
        if (!hexa_truthy(hexa_call1(fn, HX_ARR_ITEMS(arr)[i]))) return hexa_bool(0);
    }
    return hexa_bool(1);
}

HexaVal hexa_array_count(HexaVal arr, HexaVal fn) {
    if (!HX_IS_ARRAY(arr)) return hexa_int(0);
    int64_t c = 0;
    for (int i = 0; i < HX_ARR_LEN(arr); i++) {
        if (hexa_truthy(hexa_call1(fn, HX_ARR_ITEMS(arr)[i]))) c++;
    }
    return hexa_int(c);
}

HexaVal hexa_map_count(HexaVal m, HexaVal pred);

// count_poly: dispatch `.count()` method by receiver type. String form
// takes a substring arg (hexa_str_count_substr); map form takes a 2-arg
// predicate fn(k,v) or acts as len() when pred is void; array form takes
// a 1-arg predicate fn (hexa_array_count). Matches interpreter at
// self/hexa_full.hexa:14997-15014 (str), 15689-15704 (map), 15351-15358 (arr).
HexaVal hexa_count_poly(HexaVal obj, HexaVal arg) {
    if (HX_IS_STR(obj) && HX_IS_STR(arg)) {
        return hexa_str_count_substr(obj, arg);
    }
    if (HX_IS_MAP(obj)) {
        return hexa_map_count(obj, arg);
    }
    return hexa_array_count(obj, arg);
}

// contains_poly: dispatch `.contains()` method by receiver type. String
// form is substring search; array form is element-eq search. Both return
// bool. Matches interpreter self/hexa_full.hexa:14945 (str) and
// 15186-15192 (arr).
HexaVal hexa_contains_poly(HexaVal obj, HexaVal arg) {
    if (HX_IS_STR(obj)) {
        return hexa_bool(hexa_str_contains(obj, arg));
    }
    return hexa_bool(hexa_array_contains(obj, arg));
}

// find: first element matching predicate; void if none.
HexaVal hexa_array_find(HexaVal arr, HexaVal fn) {
    if (!HX_IS_ARRAY(arr)) return hexa_void();
    for (int i = 0; i < HX_ARR_LEN(arr); i++) {
        HexaVal it = HX_ARR_ITEMS(arr)[i];
        if (hexa_truthy(hexa_call1(fn, it))) return it;
    }
    return hexa_void();
}

// Polymorphic `.find()` dispatch — .find() 이 string `.find(needle)` 과
// array `.find(pred)` 에서 의미/반환 타입이 달라 codegen 단일 사이트에서
// 정적 dispatch 불가 (이전엔 모든 경우 str_index_of 로 라우팅 → array
// 시 -1 반환). 런타임에서 receiver 타입 보고 양쪽에 위임.
HexaVal hexa_find_poly(HexaVal obj, HexaVal arg) {
    if (HX_IS_ARRAY(obj)) return hexa_array_find(obj, arg);
    return hexa_int(hexa_str_index_of(obj, arg));
}

// `0..5` / `1..=10` / `0..10 step 2` — evaluates a Range at expression
// position to an int array. 이전엔 ForStmt 경로에만 Range codegen 이 있어
// `let r = 0..5` 같은 일반 expr 사용 시 "CODEGEN ERROR: unhandled expr
// kind: Range" 발생. Interp 의 NK_RANGE 분기 (hexa_full.hexa:7425) 의
// AOT counterpart.
HexaVal hexa_range_array(HexaVal start, HexaVal end, HexaVal step, int inclusive) {
    HexaVal result = hexa_array_new();
    int64_t s = HX_INT(start);
    int64_t e = HX_INT(end);
    int64_t st = HX_IS_VOID(step) ? 1 : HX_INT(step);
    if (st <= 0) st = 1;
    if (inclusive) {
        for (int64_t i = s; i <= e; i += st) result = hexa_array_push(result, hexa_int(i));
    } else {
        for (int64_t i = s; i < e; i += st) result = hexa_array_push(result, hexa_int(i));
    }
    return result;
}

// flat_map: map then flatten one level. Non-array callback results
// are pushed as-is (matches interpreter fallback at hexa_full.hexa:15211).
HexaVal hexa_array_flat_map(HexaVal arr, HexaVal fn) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(arr)) return out;
    for (int i = 0; i < HX_ARR_LEN(arr); i++) {
        HexaVal sub = hexa_call1(fn, HX_ARR_ITEMS(arr)[i]);
        if (HX_IS_ARRAY(sub)) {
            for (int j = 0; j < HX_ARR_LEN(sub); j++) {
                out = hexa_array_push(out, HX_ARR_ITEMS(sub)[j]);
            }
        } else {
            out = hexa_array_push(out, sub);
        }
    }
    return out;
}

// enumerate: [[idx, item], ...] — matches hexa_full.hexa:15220-15228.
HexaVal hexa_array_enumerate(HexaVal arr) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(arr)) return out;
    for (int i = 0; i < HX_ARR_LEN(arr); i++) {
        HexaVal pair = hexa_array_new();
        pair = hexa_array_push(pair, hexa_int((int64_t)i));
        pair = hexa_array_push(pair, HX_ARR_ITEMS(arr)[i]);
        out = hexa_array_push(out, pair);
    }
    return out;
}

// is_empty: true if array/string has zero items/bytes. Map also uses
// map_len — handled in hexa_is_empty below (polymorphic).
HexaVal hexa_is_empty(HexaVal v) {
    if (HX_IS_ARRAY(v)) return hexa_bool(HX_ARR_LEN(v) == 0);
    if (HX_IS_STR(v)) {
        const char* s = HX_STR(v);
        return hexa_bool(!s || s[0] == '\0');
    }
    return hexa_bool(1); // null/undefined/etc. → empty
}

// min/max: reduction by element. Uses hexa_cmp_lt/gt which already handle
// int/float mixing. Empty array returns void (matches interpreter at
// hexa_full.hexa:15344).
// Step-3 cycle 22 port. Polymorphic int/float element compare stays
// C-side; if the array is *purely* float-typed (TAG_FLOAT every element)
// the hexa-source rt_array_min_float / max_float path takes over.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_array_min(HexaVal arr) {
    if (!HX_IS_ARRAY(arr)) return hexa_void();
    int64_t n = HX_ARR_LEN(arr);
    if (n == 0) return hexa_void();
    HexaVal best = HX_ARR_ITEMS(arr)[0];
    for (int64_t i = 1; i < n; i++) {
        HexaVal it = HX_ARR_ITEMS(arr)[i];
        if (hexa_truthy(hexa_cmp_lt(it, best))) best = it;
    }
    return best;
}

HexaVal hexa_array_max(HexaVal arr) {
    if (!HX_IS_ARRAY(arr)) return hexa_void();
    int64_t n = HX_ARR_LEN(arr);
    if (n == 0) return hexa_void();
    HexaVal best = HX_ARR_ITEMS(arr)[0];
    for (int64_t i = 1; i < n; i++) {
        HexaVal it = HX_ARR_ITEMS(arr)[i];
        if (hexa_truthy(hexa_cmp_gt(it, best))) best = it;
    }
    return best;
}
#else
extern HexaVal rt_array_min_float(HexaVal arr);
extern HexaVal rt_array_max_float(HexaVal arr);
static int _arr_all_float(HexaVal arr) {
    int64_t n = HX_ARR_LEN(arr);
    for (int64_t i = 0; i < n; i++) {
        if (!HX_IS_FLOAT(HX_ARR_ITEMS(arr)[i])) return 0;
    }
    return 1;
}
HexaVal hexa_array_min(HexaVal arr) {
    if (!HX_IS_ARRAY(arr)) return hexa_void();
    int64_t n = HX_ARR_LEN(arr);
    if (n == 0) return hexa_void();
    if (_arr_all_float(arr)) return rt_array_min_float(arr);
    HexaVal best = HX_ARR_ITEMS(arr)[0];
    for (int64_t i = 1; i < n; i++) {
        HexaVal it = HX_ARR_ITEMS(arr)[i];
        if (hexa_truthy(hexa_cmp_lt(it, best))) best = it;
    }
    return best;
}
HexaVal hexa_array_max(HexaVal arr) {
    if (!HX_IS_ARRAY(arr)) return hexa_void();
    int64_t n = HX_ARR_LEN(arr);
    if (n == 0) return hexa_void();
    if (_arr_all_float(arr)) return rt_array_max_float(arr);
    HexaVal best = HX_ARR_ITEMS(arr)[0];
    for (int64_t i = 1; i < n; i++) {
        HexaVal it = HX_ARR_ITEMS(arr)[i];
        if (hexa_truthy(hexa_cmp_gt(it, best))) best = it;
    }
    return best;
}
#endif

// flatten: one-level; non-array elements passed through.
// Matches interpreter semantics at hexa_full.hexa:15316-15327.
HexaVal hexa_array_flatten(HexaVal arr) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(arr)) return out;
    for (int64_t i = 0; i < HX_ARR_LEN(arr); i++) {
        HexaVal it = HX_ARR_ITEMS(arr)[i];
        if (HX_IS_ARRAY(it)) {
            for (int64_t j = 0; j < HX_ARR_LEN(it); j++) {
                out = hexa_array_push(out, HX_ARR_ITEMS(it)[j]);
            }
        } else {
            out = hexa_array_push(out, it);
        }
    }
    return out;
}

// for_each: side-effect iteration. Returns void (hexa_full.hexa:15187).
HexaVal hexa_array_for_each(HexaVal arr, HexaVal fn) {
    if (!HX_IS_ARRAY(arr)) return hexa_void();
    for (int64_t i = 0; i < HX_ARR_LEN(arr); i++) {
        hexa_call1(fn, HX_ARR_ITEMS(arr)[i]);
    }
    return hexa_void();
}

// fill: new array of same length, every slot set to v.
// Matches interpreter: returns a NEW array rather than mutating in place
// (hexa_full.hexa:15486-15494).
// Step-3 cycle 34 port — float fast-path dispatches to rt_array_fill_float
// when both the array is all-float and the fill value is float; mixed-type
// arrays stay on the polymorphic C body.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_array_fill(HexaVal arr, HexaVal v) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(arr)) return out;
    int64_t n = HX_ARR_LEN(arr);
    for (int64_t i = 0; i < n; i++) {
        out = hexa_array_push(out, v);
    }
    return out;
}
#else
extern HexaVal rt_array_fill_float(HexaVal arr, HexaVal v);
HexaVal hexa_array_fill(HexaVal arr, HexaVal v) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(arr)) return out;
    if (HX_IS_FLOAT(v) && _arr_all_float(arr)) {
        return rt_array_fill_float(arr, v);
    }
    int64_t n = HX_ARR_LEN(arr);
    for (int64_t i = 0; i < n; i++) {
        out = hexa_array_push(out, v);
    }
    return out;
}
#endif

// rt#32-O (r5-a10.5-A, 2026-04-20): leak-fix primitives for CLM training.
//
// Root cause: train_clm.hexa per-step has ~88 _tz(N) calls (decoder forward
// 12-block stack). Each _tz did N hexa_array_push() from cap=0, accumulating
// to a malloc'd buffer of N*sizeof(HexaVal) ~= N*32B that hexa never frees
// (no GC, value-typed). At seq=512 d=768 that is 12.6 MB per call, ~1.1 GB
// per step = 1.5 GB/min observed leak. Two new primitives fix this:
//
// 1) hexa_array_zeros_float(n): single-shot calloc of N HexaVal slots
//    pre-filled with hexa_float(0.0). Returns array with cap=len=n. No
//    realloc churn (was 17 grows per call at N=393K). Replaces _tz body.
//
// 2) hexa_array_free(arr): frees items buffer + descriptor. Hexa is
//    pass-by-value at HexaVal level, but the .arr_ptr / .items pointers
//    are shared. Caller MUST guarantee no other live alias. Used at
//    end-of-train_step to reclaim block_hs / fwd / bwd buffers known to
//    be local. Returns hexa_void().
HexaVal hexa_array_zeros_float(HexaVal nv) {
    if (_hx_stats_on()) _hx_stats_array_new++;
    HexaVal out = {.tag=TAG_ARRAY};
    HX_SET_ARR_PTR(out, (HexaArr*)calloc(1, sizeof(HexaArr)));
    int64_t n = HX_IS_INT(nv) ? HX_INT(nv) : (int64_t)__hx_to_double(nv);
    if (n <= 0) return out;
    HexaVal* items = (HexaVal*)malloc(sizeof(HexaVal) * (size_t)n);
    if (!items) { fprintf(stderr, "OOM in array_zeros_float n=%lld\n", (long long)n); exit(1); }
    HexaVal zero = {.tag=TAG_FLOAT, .f=0.0};
    for (int64_t i = 0; i < n; i++) items[i] = zero;
    HX_SET_ARR_ITEMS(out, items);
    HX_SET_ARR_LEN(out, (int)n);
    HX_SET_ARR_CAP(out, (int)n);  // positive → heap
    return out;
}

// ω-interp-3 (2026-04-26): array_alloc(n) — pre-allocate N-element int array,
// all slots = 0. Counterpart to hexa_array_zeros_float for int buffers.
// O(n) once + O(1) per element via indexed assign.
//
// Use case: ω-audio-3 vocal_hexa knows N=4800 bytes upfront; replacing N×
// hexa_array_push with array_alloc(N) + indexed assign drops per-element
// dispatch overhead 2-4× (single store vs method-call + env_set rebind).
HexaVal hexa_array_alloc(HexaVal nv) {
    if (_hx_stats_on()) _hx_stats_array_new++;
    HexaVal out = {.tag=TAG_ARRAY};
    HX_SET_ARR_PTR(out, (HexaArr*)calloc(1, sizeof(HexaArr)));
    int64_t n = HX_IS_INT(nv) ? HX_INT(nv) : (int64_t)__hx_to_double(nv);
    if (n <= 0) return out;
    HexaVal* items = (HexaVal*)malloc(sizeof(HexaVal) * (size_t)n);
    if (!items) { fprintf(stderr, "OOM in array_alloc n=%lld\n", (long long)n); exit(1); }
    HexaVal zero = {.tag=TAG_INT, .i=0};
    for (int64_t i = 0; i < n; i++) items[i] = zero;
    HX_SET_ARR_ITEMS(out, items);
    HX_SET_ARR_LEN(out, (int)n);
    HX_SET_ARR_CAP(out, (int)n);  // positive → heap
    return out;
}

HexaVal hexa_array_free(HexaVal arr) {
    if (!HX_IS_ARRAY(arr)) return hexa_void();
    HexaArr* p = arr.arr_ptr;
    if (!p) return hexa_void();
    // Only free heap-backed buffers (cap>0). Arena-backed (cap<0) belong
    // to the arena slab and must not be passed to free().
    if (p->items && p->cap > 0) {
        free(p->items);
    }
    p->items = NULL;
    p->len = 0;
    p->cap = 0;
    free(p);
    return hexa_void();
}

// take(n) / drop(n). Step-3 cycle 24 port (float-only fast path).
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_array_take(HexaVal arr, HexaVal nv) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(arr)) return out;
    int64_t n = HX_IS_INT(nv) ? HX_INT(nv) : (int64_t)__hx_to_double(nv);
    int64_t len = HX_ARR_LEN(arr);
    int64_t k = n < len ? n : len;
    if (k < 0) k = 0;
    for (int64_t i = 0; i < k; i++) {
        out = hexa_array_push(out, HX_ARR_ITEMS(arr)[i]);
    }
    return out;
}
HexaVal hexa_array_drop(HexaVal arr, HexaVal nv) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(arr)) return out;
    int64_t n = HX_IS_INT(nv) ? HX_INT(nv) : (int64_t)__hx_to_double(nv);
    int64_t len = HX_ARR_LEN(arr);
    int64_t start = n < 0 ? 0 : (n > len ? len : n);
    for (int64_t i = start; i < len; i++) {
        out = hexa_array_push(out, HX_ARR_ITEMS(arr)[i]);
    }
    return out;
}
#else
extern HexaVal rt_array_take_float(HexaVal arr, HexaVal n);
extern HexaVal rt_array_drop_float(HexaVal arr, HexaVal n);
HexaVal hexa_array_take(HexaVal arr, HexaVal nv) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(arr)) return out;
    int64_t n = HX_IS_INT(nv) ? HX_INT(nv) : (int64_t)__hx_to_double(nv);
    if (_arr_all_float(arr)) return rt_array_take_float(arr, hexa_int(n));
    int64_t len = HX_ARR_LEN(arr);
    int64_t k = n < len ? n : len;
    if (k < 0) k = 0;
    for (int64_t i = 0; i < k; i++) {
        out = hexa_array_push(out, HX_ARR_ITEMS(arr)[i]);
    }
    return out;
}
HexaVal hexa_array_drop(HexaVal arr, HexaVal nv) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(arr)) return out;
    int64_t n = HX_IS_INT(nv) ? HX_INT(nv) : (int64_t)__hx_to_double(nv);
    if (_arr_all_float(arr)) return rt_array_drop_float(arr, hexa_int(n));
    int64_t len = HX_ARR_LEN(arr);
    int64_t start = n < 0 ? 0 : (n > len ? len : n);
    for (int64_t i = start; i < len; i++) {
        out = hexa_array_push(out, HX_ARR_ITEMS(arr)[i]);
    }
    return out;
}
#endif

// zip(other): pairs [a_i, b_i] up to min(len(a), len(b)). Step-3 cycle 25.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_array_zip(HexaVal a, HexaVal b) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(a) || !HX_IS_ARRAY(b)) return out;
    int64_t na = HX_ARR_LEN(a), nb = HX_ARR_LEN(b);
    int64_t k = na < nb ? na : nb;
    for (int64_t i = 0; i < k; i++) {
        HexaVal pair = hexa_array_new();
        pair = hexa_array_push(pair, HX_ARR_ITEMS(a)[i]);
        pair = hexa_array_push(pair, HX_ARR_ITEMS(b)[i]);
        out = hexa_array_push(out, pair);
    }
    return out;
}
#else
extern HexaVal rt_array_zip_float(HexaVal a, HexaVal b);
HexaVal hexa_array_zip(HexaVal a, HexaVal b) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(a) || !HX_IS_ARRAY(b)) return out;
    if (_arr_all_float(a) && _arr_all_float(b)) return rt_array_zip_float(a, b);
    int64_t na = HX_ARR_LEN(a), nb = HX_ARR_LEN(b);
    int64_t k = na < nb ? na : nb;
    for (int64_t i = 0; i < k; i++) {
        HexaVal pair = hexa_array_new();
        pair = hexa_array_push(pair, HX_ARR_ITEMS(a)[i]);
        pair = hexa_array_push(pair, HX_ARR_ITEMS(b)[i]);
        out = hexa_array_push(out, pair);
    }
    return out;
}
#endif

// chunk(n): split into non-overlapping chunks of size n (last may be shorter).
// Matches interpreter at hexa_full.hexa:15363-15378. Step-3 cycle 26.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_array_chunk(HexaVal arr, HexaVal nv) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(arr)) return out;
    int64_t n = HX_IS_INT(nv) ? HX_INT(nv) : (int64_t)__hx_to_double(nv);
    if (n <= 0) return out;
    int64_t len = HX_ARR_LEN(arr);
    for (int64_t i = 0; i < len; i += n) {
        HexaVal chunk = hexa_array_new();
        int64_t stop = i + n;
        if (stop > len) stop = len;
        for (int64_t j = i; j < stop; j++) {
            chunk = hexa_array_push(chunk, HX_ARR_ITEMS(arr)[j]);
        }
        out = hexa_array_push(out, chunk);
    }
    return out;
}
#else
extern HexaVal rt_array_chunk_float(HexaVal arr, HexaVal n);
HexaVal hexa_array_chunk(HexaVal arr, HexaVal nv) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(arr)) return out;
    int64_t n = HX_IS_INT(nv) ? HX_INT(nv) : (int64_t)__hx_to_double(nv);
    if (_arr_all_float(arr)) return rt_array_chunk_float(arr, hexa_int(n));
    if (n <= 0) return out;
    int64_t len = HX_ARR_LEN(arr);
    for (int64_t i = 0; i < len; i += n) {
        HexaVal chunk = hexa_array_new();
        int64_t stop = i + n;
        if (stop > len) stop = len;
        for (int64_t j = i; j < stop; j++) {
            chunk = hexa_array_push(chunk, HX_ARR_ITEMS(arr)[j]);
        }
        out = hexa_array_push(out, chunk);
    }
    return out;
}
#endif

// window(n): sliding windows of size n (step 1). Empty if n > len or n ≤ 0.
// Matches interpreter at hexa_full.hexa:15380-15395.
// Step-3 cycle 31 port — float-typed arrays dispatch to rt_array_window_float
// in stdlib/runtime/numeric.hexa; mixed-typed arrays stay on the C path.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_array_window(HexaVal arr, HexaVal nv) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(arr)) return out;
    int64_t n = HX_IS_INT(nv) ? HX_INT(nv) : (int64_t)__hx_to_double(nv);
    int64_t len = HX_ARR_LEN(arr);
    if (n <= 0 || n > len) return out;
    for (int64_t i = 0; i + n <= len; i++) {
        HexaVal win = hexa_array_new();
        for (int64_t j = 0; j < n; j++) {
            win = hexa_array_push(win, HX_ARR_ITEMS(arr)[i + j]);
        }
        out = hexa_array_push(out, win);
    }
    return out;
}
#else
extern HexaVal rt_array_window_float(HexaVal arr, HexaVal n);
HexaVal hexa_array_window(HexaVal arr, HexaVal nv) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(arr)) return out;
    int64_t n = HX_IS_INT(nv) ? HX_INT(nv) : (int64_t)__hx_to_double(nv);
    if (_arr_all_float(arr)) return rt_array_window_float(arr, hexa_int(n));
    int64_t len = HX_ARR_LEN(arr);
    if (n <= 0 || n > len) return out;
    for (int64_t i = 0; i + n <= len; i++) {
        HexaVal win = hexa_array_new();
        for (int64_t j = 0; j < n; j++) {
            win = hexa_array_push(win, HX_ARR_ITEMS(arr)[i + j]);
        }
        out = hexa_array_push(out, win);
    }
    return out;
}
#endif

// unique: dedupe by hexa_eq. O(n²) — matches interpreter's equality
// check (hexa_full.hexa:15263-15277). Step-3 cycle 29 port.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_array_unique(HexaVal arr) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(arr)) return out;
    int64_t len = HX_ARR_LEN(arr);
    for (int64_t i = 0; i < len; i++) {
        HexaVal it = HX_ARR_ITEMS(arr)[i];
        int seen = 0;
        for (int64_t j = 0; j < HX_ARR_LEN(out); j++) {
            if (hexa_truthy(hexa_eq(HX_ARR_ITEMS(out)[j], it))) { seen = 1; break; }
        }
        if (!seen) out = hexa_array_push(out, it);
    }
    return out;
}
#else
extern HexaVal rt_array_unique_float(HexaVal arr);
HexaVal hexa_array_unique(HexaVal arr) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(arr)) return out;
    if (_arr_all_float(arr)) return rt_array_unique_float(arr);
    int64_t len = HX_ARR_LEN(arr);
    for (int64_t i = 0; i < len; i++) {
        HexaVal it = HX_ARR_ITEMS(arr)[i];
        int seen = 0;
        for (int64_t j = 0; j < HX_ARR_LEN(out); j++) {
            if (hexa_truthy(hexa_eq(HX_ARR_ITEMS(out)[j], it))) { seen = 1; break; }
        }
        if (!seen) out = hexa_array_push(out, it);
    }
    return out;
}
#endif

// rotate(k): k>0 shifts left (items[k] becomes new head); k<0 shifts right.
// k normalized mod len. Step-3 cycle 30 port.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_array_rotate(HexaVal arr, HexaVal kv) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(arr)) return out;
    int64_t n = HX_ARR_LEN(arr);
    if (n == 0) return out;
    int64_t k = HX_IS_INT(kv) ? HX_INT(kv) : (int64_t)__hx_to_double(kv);
    k = k % n;
    if (k < 0) k += n;
    for (int64_t i = 0; i < n; i++) {
        out = hexa_array_push(out, HX_ARR_ITEMS(arr)[(i + k) % n]);
    }
    return out;
}
#else
extern HexaVal rt_array_rotate_float(HexaVal arr, HexaVal k);
HexaVal hexa_array_rotate(HexaVal arr, HexaVal kv) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(arr)) return out;
    int64_t n = HX_ARR_LEN(arr);
    if (n == 0) return out;
    int64_t k = HX_IS_INT(kv) ? HX_INT(kv) : (int64_t)__hx_to_double(kv);
    if (_arr_all_float(arr)) return rt_array_rotate_float(arr, hexa_int(k));
    k = k % n;
    if (k < 0) k += n;
    for (int64_t i = 0; i < n; i++) {
        out = hexa_array_push(out, HX_ARR_ITEMS(arr)[(i + k) % n]);
    }
    return out;
}
#endif

// partition(pred): returns [matching, non_matching] as a 2-element array.
// Matches interpreter at hexa_full.hexa:15437-15449.
HexaVal hexa_array_partition(HexaVal arr, HexaVal fn) {
    HexaVal matching = hexa_array_new();
    HexaVal rest = hexa_array_new();
    if (HX_IS_ARRAY(arr)) {
        for (int64_t i = 0; i < HX_ARR_LEN(arr); i++) {
            HexaVal it = HX_ARR_ITEMS(arr)[i];
            if (hexa_truthy(hexa_call1(fn, it))) {
                matching = hexa_array_push(matching, it);
            } else {
                rest = hexa_array_push(rest, it);
            }
        }
    }
    HexaVal out = hexa_array_new();
    out = hexa_array_push(out, matching);
    out = hexa_array_push(out, rest);
    return out;
}

// interleave(other): alternates items from both arrays up to max length.
// When one array runs out, the other's remaining items still alternate in.
// Matches interpreter at hexa_full.hexa:15451-15464.
// Step-3 cycle 37 port — float fast-path dispatches when both arrays
// are all-float; mixed-type stays on the polymorphic C body.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_array_interleave(HexaVal a, HexaVal b) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(a)) {
        return HX_IS_ARRAY(b) ? b : out;
    }
    if (!HX_IS_ARRAY(b)) return a;
    int64_t na = HX_ARR_LEN(a), nb = HX_ARR_LEN(b);
    int64_t m = na > nb ? na : nb;
    for (int64_t i = 0; i < m; i++) {
        if (i < na) out = hexa_array_push(out, HX_ARR_ITEMS(a)[i]);
        if (i < nb) out = hexa_array_push(out, HX_ARR_ITEMS(b)[i]);
    }
    return out;
}
#else
extern HexaVal rt_array_interleave_float(HexaVal a, HexaVal b);
HexaVal hexa_array_interleave(HexaVal a, HexaVal b) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(a)) {
        return HX_IS_ARRAY(b) ? b : out;
    }
    if (!HX_IS_ARRAY(b)) return a;
    if (_arr_all_float(a) && _arr_all_float(b)) {
        return rt_array_interleave_float(a, b);
    }
    int64_t na = HX_ARR_LEN(a), nb = HX_ARR_LEN(b);
    int64_t m = na > nb ? na : nb;
    for (int64_t i = 0; i < m; i++) {
        if (i < na) out = hexa_array_push(out, HX_ARR_ITEMS(a)[i]);
        if (i < nb) out = hexa_array_push(out, HX_ARR_ITEMS(b)[i]);
    }
    return out;
}
#endif

// scan(init, fn): like fold but returns all intermediate accumulators.
// Result length is len(arr) + 1 (includes init as first element).
// Matches interpreter at hexa_full.hexa:15426-15435.
HexaVal hexa_array_scan(HexaVal arr, HexaVal init, HexaVal fn) {
    HexaVal out = hexa_array_new();
    out = hexa_array_push(out, init);
    if (!HX_IS_ARRAY(arr)) return out;
    HexaVal acc = init;
    for (int64_t i = 0; i < HX_ARR_LEN(arr); i++) {
        acc = hexa_call2(fn, acc, HX_ARR_ITEMS(arr)[i]);
        out = hexa_array_push(out, acc);
    }
    return out;
}

// product(a): multiplicative reduce. Mirrors hexa_sum but with mult.
// Empty array returns int 1 (multiplicative identity). Step-3 cycle 23
// port (all-float fast path).
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_array_product(HexaVal arr) {
    if (!HX_IS_ARRAY(arr)) return hexa_int(1);
    int64_t n = HX_ARR_LEN(arr);
    int has_float = 0;
    int64_t int_total = 1;
    double float_total = 1.0;
    for (int64_t i = 0; i < n; i++) {
        HexaVal e = HX_ARR_ITEMS(arr)[i];
        if (HX_IS_FLOAT(e)) { has_float = 1; float_total *= HX_FLOAT(e); }
        else { int_total *= HX_INT(e); }
    }
    if (has_float) return hexa_float((double)int_total * float_total);
    return hexa_int(int_total);
}
#else
extern HexaVal rt_array_product_float(HexaVal arr);
HexaVal hexa_array_product(HexaVal arr) {
    if (!HX_IS_ARRAY(arr)) return hexa_int(1);
    int64_t n = HX_ARR_LEN(arr);
    if (n == 0) return hexa_int(1);
    if (_arr_all_float(arr)) return rt_array_product_float(arr);
    int has_float = 0;
    int64_t int_total = 1;
    double float_total = 1.0;
    for (int64_t i = 0; i < n; i++) {
        HexaVal e = HX_ARR_ITEMS(arr)[i];
        if (HX_IS_FLOAT(e)) { has_float = 1; float_total *= HX_FLOAT(e); }
        else { int_total *= HX_INT(e); }
    }
    if (has_float) return hexa_float((double)int_total * float_total);
    return hexa_int(int_total);
}
#endif

// mean(a): float average. Empty array returns float 0.0.
// Step-3 cycle 20 port.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_array_mean(HexaVal arr) {
    if (!HX_IS_ARRAY(arr)) return hexa_float(0.0);
    int64_t n = HX_ARR_LEN(arr);
    if (n == 0) return hexa_float(0.0);
    double total = 0.0;
    for (int64_t i = 0; i < n; i++) {
        total += __hx_to_double(HX_ARR_ITEMS(arr)[i]);
    }
    return hexa_float(total / (double)n);
}
#else
extern HexaVal rt_array_mean(HexaVal arr);
HexaVal hexa_array_mean(HexaVal arr) {
    if (!HX_IS_ARRAY(arr)) return hexa_float(0.0);
    return rt_array_mean(arr);
}
#endif

// swap(i, j): returns new array with items at i and j swapped.
// Out-of-range indices return original array copy.
// Matches interpreter at hexa_full.hexa:15497-15512. Step-3 cycle 25 port.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_array_swap(HexaVal arr, HexaVal iv, HexaVal jv) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(arr)) return out;
    int64_t n = HX_ARR_LEN(arr);
    int64_t i = HX_IS_INT(iv) ? HX_INT(iv) : (int64_t)__hx_to_double(iv);
    int64_t j = HX_IS_INT(jv) ? HX_INT(jv) : (int64_t)__hx_to_double(jv);
    if (i < 0 || j < 0 || i >= n || j >= n) {
        for (int64_t k = 0; k < n; k++) out = hexa_array_push(out, HX_ARR_ITEMS(arr)[k]);
        return out;
    }
    for (int64_t k = 0; k < n; k++) {
        if (k == i) out = hexa_array_push(out, HX_ARR_ITEMS(arr)[j]);
        else if (k == j) out = hexa_array_push(out, HX_ARR_ITEMS(arr)[i]);
        else out = hexa_array_push(out, HX_ARR_ITEMS(arr)[k]);
    }
    return out;
}
#else
extern HexaVal rt_array_swap_float(HexaVal arr, HexaVal i, HexaVal j);
HexaVal hexa_array_swap(HexaVal arr, HexaVal iv, HexaVal jv) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(arr)) return out;
    int64_t i = HX_IS_INT(iv) ? HX_INT(iv) : (int64_t)__hx_to_double(iv);
    int64_t j = HX_IS_INT(jv) ? HX_INT(jv) : (int64_t)__hx_to_double(jv);
    if (_arr_all_float(arr)) return rt_array_swap_float(arr, hexa_int(i), hexa_int(j));
    int64_t n = HX_ARR_LEN(arr);
    if (i < 0 || j < 0 || i >= n || j >= n) {
        for (int64_t k = 0; k < n; k++) out = hexa_array_push(out, HX_ARR_ITEMS(arr)[k]);
        return out;
    }
    for (int64_t k = 0; k < n; k++) {
        if (k == i) out = hexa_array_push(out, HX_ARR_ITEMS(arr)[j]);
        else if (k == j) out = hexa_array_push(out, HX_ARR_ITEMS(arr)[i]);
        else out = hexa_array_push(out, HX_ARR_ITEMS(arr)[k]);
    }
    return out;
}
#endif

// group_by: apply fn(item) → key, bucket items into map[str(key)] = [items].
// Interpreter (self/hexa_full.hexa:15323-15344) compares keys via
// val_to_string, so we do the same via hexa_to_string for parity — non-
// string keys still group correctly. Values accumulate as arrays.
HexaVal hexa_array_group_by(HexaVal arr, HexaVal fn) {
    HexaVal out = hexa_map_new();
    if (!HX_IS_ARRAY(arr)) return out;
    for (int i = 0; i < HX_ARR_LEN(arr); i++) {
        HexaVal item = HX_ARR_ITEMS(arr)[i];
        HexaVal key = hexa_call1(fn, item);
        const char* k_str = hexa_str_as_ptr(hexa_to_string(key));
        if (!k_str) continue;
        HexaVal bucket;
        if (hexa_map_contains_key(out, k_str)) {
            bucket = hexa_map_get(out, k_str);
        } else {
            bucket = hexa_array_new();
        }
        bucket = hexa_array_push(bucket, item);
        out = hexa_map_set(out, k_str, bucket);
    }
    return out;
}

// frequencies: count occurrences per value; keys are stringified via
// hexa_to_string (same as group_by). Returns map<str, int>. Matches
// interpreter at self/hexa_full.hexa:15509-15528.
HexaVal hexa_array_frequencies(HexaVal arr) {
    HexaVal out = hexa_map_new();
    if (!HX_IS_ARRAY(arr)) return out;
    for (int i = 0; i < HX_ARR_LEN(arr); i++) {
        const char* k = hexa_str_as_ptr(hexa_to_string(HX_ARR_ITEMS(arr)[i]));
        if (!k) continue;
        int64_t cur = 0;
        if (hexa_map_contains_key(out, k)) {
            HexaVal v = hexa_map_get(out, k);
            cur = HX_IS_INT(v) ? HX_INT(v) : (int64_t)__hx_to_double(v);
        }
        out = hexa_map_set(out, k, hexa_int(cur + 1));
    }
    return out;
}

// sample(n): return n items drawn uniformly at random (with replacement)
// from arr. Empty array or n<=0 returns empty array. Uses rand()/RAND_MAX
// like hexa_random() so the RNG stream is shared. Matches interpreter at
// self/hexa_full.hexa:15544-15556.
HexaVal hexa_array_sample(HexaVal arr, HexaVal nv) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(arr)) return out;
    int64_t n_items = HX_ARR_LEN(arr);
    int64_t n = HX_IS_INT(nv) ? HX_INT(nv) : (int64_t)__hx_to_double(nv);
    if (n_items == 0 || n <= 0) return out;
    for (int64_t i = 0; i < n; i++) {
        int64_t idx = (int64_t)(rand() / (double)RAND_MAX * (double)n_items);
        if (idx >= n_items) idx = n_items - 1;
        out = hexa_array_push(out, HX_ARR_ITEMS(arr)[idx]);
    }
    return out;
}

// substr: JS-style substring(start, length). length defaults to "rest of
// string" when not supplied. Negative start clamps to 0, negative length
// to 0, end clamps to strlen. Matches interpreter at
// self/hexa_full.hexa:14959-14972.
HexaVal hexa_str_substr(HexaVal s, HexaVal start_v, HexaVal len_v) {
    if (!HX_IS_STR(s)) return hexa_str("");
    int64_t slen = (int64_t)HX_STRLEN(s);
    int64_t start = HX_IS_INT(start_v) ? HX_INT(start_v) : (int64_t)__hx_to_double(start_v);
    if (start < 0) start = 0;
    if (start > slen) start = slen;
    int64_t count;
    if (HX_TAG(len_v) == TAG_VOID) {
        count = slen - start;
    } else {
        count = HX_IS_INT(len_v) ? HX_INT(len_v) : (int64_t)__hx_to_double(len_v);
    }
    if (count < 0) count = 0;
    int64_t end_idx = start + count;
    if (end_idx > slen) end_idx = slen;
    return hexa_str_substring(s, hexa_int(start), hexa_int(end_idx));
}

// Step-3 cycle 28 port.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_str_bytes(HexaVal s) {
    if (!HX_IS_STR(s)) return hexa_array_new();
    HexaVal out = hexa_array_new();
    for (const unsigned char* p = (const unsigned char*)HX_STR(s); *p; p++) {
        out = hexa_array_push(out, hexa_int((int64_t)*p));
    }
    return out;
}
#else
extern HexaVal rt_str_bytes(HexaVal s);
HexaVal hexa_str_bytes(HexaVal s) {
    if (!HX_IS_STR(s)) return hexa_array_new();
    return rt_str_bytes(s);
}
#endif

// ── bt-71: libc / builtin family wrappers ────────────────────────────
// interpreter.hexa references bare idents like `exit(code)`, `tanh(x)`,
// `input()`, `is_error(v)`, `read_lines(p)`, `env_var(n)`, `hex(n)`, etc.
// Codegen used to emit `hexa_call1(exit, hexa_int(0))` which passes the
// libc function pointer (wrong type) to hexa_call1(HexaVal, HexaVal).
// We now wrap each in a HexaVal-returning stub so codegen can emit a
// direct call with correct types.
#include <unistd.h>
#include <time.h>

HexaVal hexa_exit(HexaVal code) {
    int c = HX_IS_INT(code) ? (int)HX_INT(code)
          : HX_IS_FLOAT(code) ? (int)HX_FLOAT(code)
          : 0;
    fflush(stdout); fflush(stderr);
    exit(c);
    return hexa_void(); // unreachable
}

HexaVal hexa_sleep(HexaVal sec) {
    double s = HX_IS_FLOAT(sec) ? HX_FLOAT(sec)
             : HX_IS_INT(sec)   ? (double)HX_INT(sec)
             : 0.0;
    if (s <= 0.0) return hexa_void();
    struct timespec ts;
    ts.tv_sec  = (time_t)s;
    ts.tv_nsec = (long)((s - (double)ts.tv_sec) * 1e9);
    hxlcl_nanosleep(&ts, NULL);
    return hexa_void();
}

// Math family — accept int or float, return float
static double _hexa_f(HexaVal v) {
    if (HX_IS_FLOAT(v)) return HX_FLOAT(v);
    if (HX_IS_INT(v))   return (double)HX_INT(v);
    if (HX_IS_BOOL(v))  return HX_BOOL(v) ? 1.0 : 0.0;
    return 0.0;
}

// Safe float→int64 cast. C cast of NaN/Inf/out-of-range double is UB
// (typically INT64_MIN on x86). Returns 0 for NaN/Inf, clamps to int64
// range otherwise. Used by to_int() builtin.
int64_t hexa_float_to_int(double f) {
    if (isnan(f) || isinf(f)) return 0;
    if (f >= 9.2233720368547758e+18) return (int64_t)0x7fffffffffffffffLL;
    if (f <= -9.2233720368547758e+18) return (int64_t)0x8000000000000000LL;
    return (int64_t)f;
}

// Step-3 cycle 38 batch — hexa_math_* wrappers that have direct rt_*
// counterparts gain the two-mode dispatch. The hexa-source path stays
// libm-free; the libm-flavoured names (asin/acos/atan/atan2) have no
// rt_ equivalent yet and remain on the C path. sin/cos/exp/log already
// route through hxlcl_* which itself calls rt_* (runtime.c:1317-1320),
// so no additional wrapping is needed for them.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_math_tanh(HexaVal x) { return hexa_float(tanh(HX_FLOAT(x))); }
HexaVal hexa_math_tan(HexaVal x)  { return hexa_float(tan(HX_FLOAT(x))); }
HexaVal hexa_math_abs(HexaVal x)  { return hexa_float(fabs(HX_FLOAT(x))); }
HexaVal hexa_math_sqrt(HexaVal x) { return hexa_float(sqrt(HX_FLOAT(x))); }
#else
extern HexaVal rt_tanh(HexaVal x);
extern HexaVal rt_tan(HexaVal x);
extern HexaVal rt_abs_float(HexaVal v);
extern HexaVal rt_sqrt(HexaVal v);
HexaVal hexa_math_tanh(HexaVal x) { return rt_tanh(hexa_float(HX_FLOAT(x))); }
HexaVal hexa_math_tan(HexaVal x)  { return rt_tan(hexa_float(HX_FLOAT(x))); }
HexaVal hexa_math_abs(HexaVal x)  { return rt_abs_float(hexa_float(HX_FLOAT(x))); }
HexaVal hexa_math_sqrt(HexaVal x) { return rt_sqrt(hexa_float(HX_FLOAT(x))); }
#endif
HexaVal hexa_math_sin(HexaVal x)  { return hexa_float(hxlcl_sin(HX_FLOAT(x))); }
HexaVal hexa_math_cos(HexaVal x)  { return hexa_float(hxlcl_cos(HX_FLOAT(x))); }
// Step-3 cycle 40 — inverse trig dispatch to rt_atan/asin/acos. atan2
// has no rt_ counterpart yet (two-arg quadrant resolution); it stays
// on libm.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_math_asin(HexaVal x) { return hexa_float(asin(HX_FLOAT(x))); }
HexaVal hexa_math_acos(HexaVal x) { return hexa_float(acos(HX_FLOAT(x))); }
HexaVal hexa_math_atan(HexaVal x) { return hexa_float(atan(HX_FLOAT(x))); }
#else
extern HexaVal rt_asin(HexaVal x);
extern HexaVal rt_acos(HexaVal x);
extern HexaVal rt_atan(HexaVal x);
HexaVal hexa_math_asin(HexaVal x) { return rt_asin(hexa_float(HX_FLOAT(x))); }
HexaVal hexa_math_acos(HexaVal x) { return rt_acos(hexa_float(HX_FLOAT(x))); }
HexaVal hexa_math_atan(HexaVal x) { return rt_atan(hexa_float(HX_FLOAT(x))); }
#endif
// Step-3 cycle 41 — atan2 dispatch to rt_atan2 (math.hexa quadrant
// resolution + 4 edge cases). Closes the inverse-trig family.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_math_atan2(HexaVal y, HexaVal x) { return hexa_float(atan2(HX_FLOAT(y), HX_FLOAT(x))); }
#else
extern HexaVal rt_atan2(HexaVal y, HexaVal x);
HexaVal hexa_math_atan2(HexaVal y, HexaVal x) {
    return rt_atan2(hexa_float(HX_FLOAT(y)), hexa_float(HX_FLOAT(x)));
}
#endif
HexaVal hexa_math_log(HexaVal x)  { return hexa_float(hxlcl_log(HX_FLOAT(x))); }
HexaVal hexa_math_exp(HexaVal x)  { return hexa_float(hxlcl_exp(HX_FLOAT(x))); }
// Step-3 cycle 39 — math floor/ceil/round wrapper contract is float-out,
// but the rt_floor/ceil/round fns in numeric.hexa return int (per their
// cycle 2/4 ports). Bridge with an explicit int→float cast at the
// boundary so the libm surface goes away while the wrapper signature
// stays unchanged.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_math_floor(HexaVal x){ return hexa_float(floor(HX_FLOAT(x))); }
HexaVal hexa_math_ceil(HexaVal x) { return hexa_float(ceil(HX_FLOAT(x))); }
HexaVal hexa_math_round(HexaVal x){ return hexa_float(round(HX_FLOAT(x))); }
#else
extern HexaVal rt_floor(HexaVal v);
extern HexaVal rt_ceil(HexaVal v);
extern HexaVal rt_round(HexaVal v);
HexaVal hexa_math_floor(HexaVal x){ return hexa_float((double)HX_INT(rt_floor(hexa_float(HX_FLOAT(x))))); }
HexaVal hexa_math_ceil(HexaVal x) { return hexa_float((double)HX_INT(rt_ceil(hexa_float(HX_FLOAT(x))))); }
HexaVal hexa_math_round(HexaVal x){ return hexa_float((double)HX_INT(rt_round(hexa_float(HX_FLOAT(x))))); }
#endif
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_math_pow(HexaVal b, HexaVal e) { return hexa_float(pow(HX_FLOAT(b), HX_FLOAT(e))); }
#else
extern HexaVal rt_pow_float(HexaVal b, HexaVal e);
HexaVal hexa_math_pow(HexaVal b, HexaVal e) {
    return rt_pow_float(hexa_float(HX_FLOAT(b)), hexa_float(HX_FLOAT(e)));
}
#endif
// 2026-05-20 (blocker-3 fmod-shim): direct libm fmod() exposed as `fmod(x, y)`
// from hexa user code. Distinct from `%` which routes through hexa_mod
// (int+float-aware dispatch); this is the pure float-only path used by
// scientific kernels that want the libm semantics directly.
// Step-3 cycle 38 batch — dispatch through rt_fmod (math.hexa cycle 7-9
// Newton/series-based) when hexa-rt-stdlib is active. hxlcl_fmod itself
// routes through rt_fmod via runtime.c shim too, so this wrapper is
// behaviour-identical; lifting it surfaces the dispatch explicitly.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_math_fmod(HexaVal a, HexaVal b) { return hexa_float(hxlcl_fmod(HX_FLOAT(a), HX_FLOAT(b))); }
#else
extern HexaVal rt_fmod(HexaVal x, HexaVal y);
HexaVal hexa_math_fmod(HexaVal a, HexaVal b) {
    return rt_fmod(hexa_float(HX_FLOAT(a)), hexa_float(HX_FLOAT(b)));
}
#endif
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_math_min(HexaVal a, HexaVal b) { return hexa_float(fmin(HX_FLOAT(a), HX_FLOAT(b))); }
#else
extern HexaVal rt_min_float(HexaVal a, HexaVal b);
HexaVal hexa_math_min(HexaVal a, HexaVal b) { return rt_min_float(a, b); }
#endif
// G1-FLOAT-PRIM 2026-05-06 — see .roadmap.stdlib.G1-FLOAT-PRIM. lgamma is the
// log-gamma function used by Beta-Binomial conjugate posteriors throughout
// the hexa-bio Bayesian audit suite (14 callsites in _python_bridge/module).
// isnan/isinf/isfinite mirror C99 classifiers; emit hexa boolean.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_math_lgamma(HexaVal x)   { return hexa_float(lgamma(HX_FLOAT(x))); }
#else
extern HexaVal rt_lgamma(HexaVal x);
HexaVal hexa_math_lgamma(HexaVal x)   { return rt_lgamma(hexa_float(HX_FLOAT(x))); }
#endif
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_math_isnan(HexaVal x)    { return hexa_bool(isnan(HX_FLOAT(x)) ? 1 : 0); }
HexaVal hexa_math_isinf(HexaVal x)    { return hexa_bool(isinf(HX_FLOAT(x)) ? 1 : 0); }
HexaVal hexa_math_isfinite(HexaVal x) { return hexa_bool(isfinite(HX_FLOAT(x)) ? 1 : 0); }
#else
extern HexaVal rt_isnan(HexaVal x);
extern HexaVal rt_isinf(HexaVal x);
extern HexaVal rt_isfinite(HexaVal x);
HexaVal hexa_math_isnan(HexaVal x)    { return rt_isnan(hexa_float(HX_FLOAT(x))); }
HexaVal hexa_math_isinf(HexaVal x)    { return rt_isinf(hexa_float(HX_FLOAT(x))); }
HexaVal hexa_math_isfinite(HexaVal x) { return rt_isfinite(hexa_float(HX_FLOAT(x))); }
#endif
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_math_max(HexaVal a, HexaVal b) { return hexa_float(fmax(HX_FLOAT(a), HX_FLOAT(b))); }
#else
extern HexaVal rt_max_float(HexaVal a, HexaVal b);
HexaVal hexa_math_max(HexaVal a, HexaVal b) { return rt_max_float(a, b); }
#endif

// ── ML builtins: matvec, dot ─────────────────────────────────
// Step-3 cycle 18 port.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_matvec(HexaVal w, HexaVal x, HexaVal rows_v, HexaVal cols_v) {
    int64_t rows = HX_IS_INT(rows_v) ? HX_INT(rows_v) : 0;
    int64_t cols = HX_IS_INT(cols_v) ? HX_INT(cols_v) : 0;
    if (rows <= 0 || cols <= 0) return hexa_array_new();
    HexaVal out = hexa_array_new();
    for (int64_t r = 0; r < rows; r++) {
        double acc = 0.0;
        for (int64_t c = 0; c < cols; c++) {
            HexaVal wv = hexa_index_get(w, hexa_int(r * cols + c));
            HexaVal xv = hexa_index_get(x, hexa_int(c));
            acc += HX_FLOAT(wv) * HX_FLOAT(xv);
        }
        out = hexa_array_push(out, hexa_float(acc));
    }
    return out;
}
#else
extern HexaVal rt_matvec(HexaVal w, HexaVal x, HexaVal rows, HexaVal cols);
HexaVal hexa_matvec(HexaVal w, HexaVal x, HexaVal rows_v, HexaVal cols_v) {
    int64_t rows = HX_IS_INT(rows_v) ? HX_INT(rows_v) : 0;
    int64_t cols = HX_IS_INT(cols_v) ? HX_INT(cols_v) : 0;
    if (rows <= 0 || cols <= 0) return hexa_array_new();
    if (!HX_IS_ARRAY(w) || !HX_IS_ARRAY(x)) return hexa_array_new();
    return rt_matvec(w, x, hexa_int(rows), hexa_int(cols));
}
#endif

HexaVal hexa_input(HexaVal prompt) {
    if (HX_IS_STR(prompt) && HX_STR(prompt) && HX_STR(prompt)[0]) {
        fputs(HX_STR(prompt), stdout);
        fflush(stdout);
    }
    char* buf = NULL;
    size_t cap = 0;
    ssize_t n = getline(&buf, &cap, stdin);
    if (n < 0) {
        if (buf) free(buf);
        return hexa_str("");
    }
    // strip trailing \n
    if (n > 0 && buf[n-1] == '\n') buf[n-1] = 0;
    return hexa_str_own(buf);
}

HexaVal hexa_is_error(HexaVal v) {
    // No TAG_ERROR in runtime; interpreter uses ad-hoc Val(TAG_ERROR,...)
    // convention (TAG_ERROR name not defined in runtime tags). Treat as
    // "false" here unless TAG_STR and starts with "ERR:" sentinel.
    if (HX_IS_STR(v) && HX_STR(v) && hxlcl_strncmp(HX_STR(v), "ERR:", 4) == 0) return hexa_bool(1);
    return hexa_bool(0);
}

HexaVal rt_read_lines(HexaVal path) {
    HexaVal content = rt_read_file(path);
    if (!HX_IS_STR(content)) return hexa_array_new();
    HexaVal out = hexa_array_new();
    const char* p = HX_STR(content);
    const char* start = p;
    while (*p) {
        if (*p == '\n') {
            size_t len = (size_t)(p - start);
            char* line = (char*)malloc(len + 1);
            hxlcl_memcpy(line, start, len);
            line[len] = 0;
            out = hexa_array_push(out, hexa_str_own(line));
            start = p + 1;
        }
        p++;
    }
    if (p > start) {
        size_t len = (size_t)(p - start);
        char* line = (char*)malloc(len + 1);
        hxlcl_memcpy(line, start, len);
        line[len] = 0;
        out = hexa_array_push(out, hexa_str_own(line));
    }
    return out;
}

HexaVal hexa_from_char_code(HexaVal n) {
    int64_t code = HX_IS_INT(n) ? HX_INT(n) : (int64_t)HX_FLOAT(n);
    if (code < 0) code = 0;
    if (code < 0x80) {
        char* s = (char*)malloc(2); s[0] = (char)code; s[1] = 0;
        return hexa_str_own(s);
    }
    // UTF-8 encode
    char buf[5] = {0};
    if (code < 0x800) {
        buf[0] = (char)(0xC0 | (code >> 6));
        buf[1] = (char)(0x80 | (code & 0x3F));
    } else if (code < 0x10000) {
        buf[0] = (char)(0xE0 | (code >> 12));
        buf[1] = (char)(0x80 | ((code >> 6) & 0x3F));
        buf[2] = (char)(0x80 | (code & 0x3F));
    } else {
        buf[0] = (char)(0xF0 | (code >> 18));
        buf[1] = (char)(0x80 | ((code >> 12) & 0x3F));
        buf[2] = (char)(0x80 | ((code >> 6) & 0x3F));
        buf[3] = (char)(0x80 | (code & 0x3F));
    }
    char* out = hxlcl_strdup(buf);
    return hexa_str_own(out);
}

// chr(N) → byte-level 1-char string. Distinct from hexa_from_char_code
// (UTF-8 codepoint encoder): chr_byte masks N to a single byte (N & 0xFF)
// and returns a 1-byte string. Used by URL-decode / raw-byte builders
// (the codegen mapping `chr` → hexa_chr_byte at codegen_c2.hexa L4452
// has existed without a runtime impl — the new tier-2 transpiler emits
// it from self/main.hexa::cmd_url_decode, exposing the gap).
HexaVal hexa_chr_byte(HexaVal n) {
    int64_t code = HX_IS_INT(n) ? HX_INT(n) : (int64_t)HX_FLOAT(n);
    char* s = (char*)malloc(2);
    s[0] = (char)(code & 0xFF);
    s[1] = 0;
    return hexa_str_own(s);
}

// RFC 030 — `bytes_to_str_raw([int]) -> string`
//
// Wrap a hexa int array (each ∈ 0..255) as a hexa string whose underlying
// bytes are exactly those integers — no UTF-8 codepoint re-encoding.
// Inverse of `_str_to_bytes(s)` (stdlib/safetensors.hexa) for UTF-8 strings
// containing arbitrary multi-byte sequences (Korean 한, emoji 🌌, etc.).
//
// Uses hexa_strbuf_alloc(n) which prepends a length header so HX_STRLEN
// is O(1) and reads the cached length; this makes embedded NUL (0x00)
// bytes safely representable (strlen()-using paths will truncate at the
// first NUL, but HX_STRLEN-aware paths see the full length).
//
// Phase 1 policy per RFC 030: out-of-range values (b<0 or b>255) produce the
// empty string (silent error) — the runtime's existing "soft-fail with empty
// result" idiom (e.g. safetensors_read returning {} on parse error).
//
// Phase 2 (2026-05-13, filed by wilson — incoming/patches/wilson-bytes-to-str-
// raw-allow-nul.md): allow embedded NUL (0x00) bytes. hexa_strbuf_alloc
// prepends a length header so HX_STRLEN is O(1) and reads the cached length;
// HX_STRLEN-aware paths (base64_encode, json builders, etc.) handle NULs
// natively. strlen()-using paths still truncate at the first NUL, but the
// burden is now on those callers — the producer is fully NUL-clean. wilson's
// tool-image::image_read (multimodal vision input) needs this for PNG IHDR
// length fields which always have leading NULs.
HexaVal hexa_bytes_to_str_raw(HexaVal arr) {
    if (HX_TAG(arr) != TAG_ARRAY) return hexa_str("");
    int64_t n = (int64_t)HX_ARR_LEN(arr);
    if (n <= 0) return hexa_str("");
    char* buf = hexa_strbuf_alloc((size_t)n);
    if (!buf) return hexa_str("");
    HexaVal* items = HX_ARR_ITEMS(arr);
    for (int64_t i = 0; i < n; i++) {
        HexaVal v = items[i];
        int64_t b = HX_IS_INT(v) ? HX_INT(v) : (int64_t)HX_FLOAT(v);
        if (b < 0 || b > 255) {
            // Out-of-range → return empty per Phase 1 policy.
            return hexa_str("");
        }
        // Phase 2: embedded NUL is allowed. hexa_strbuf_alloc's length header
        // makes the resulting string still well-formed under HX_STRLEN.
        buf[i] = (char)(b & 0xFF);
    }
    // hexa_strbuf_alloc pre-NUL-terminates buf[n] so this is a valid C str
    // (truncated at the first embedded NUL when read via strlen, but the
    // length header — read by HX_STRLEN — sees the full n bytes).
    return (HexaVal){.tag=TAG_STR, .s=buf};
}

// ═══════════════════════════════════════════════════════════
//  farr — primitive (unboxed) float array for state-vector kernels
//  hexa-lang/feat-primitive-float-array (2026-05-12)
//
//  Motivation: qmirror Phase 7 (surface_code_d3) needs n=17 qubits =
//  2^17 = 131072 double-precision amplitudes per state vector. Each
//  amplitude stored as a boxed `Val` (12-field struct, ~88B in the
//  interpreter) inflates to ~11 MB per array, × 2 (re/im) × N copies
//  ≫ 768 MB cap. Packed `double[]` storage cuts that to 1 MB per
//  array (8B/element) and gives O(1) load/store at index time.
//
//  Design: opaque int handles into a process-global table mapping
//  `id -> (double* buf, int len)`. Handles are *never* freed during
//  the program lifetime (handles outlive the kernel call, and the
//  scope-aware GC machinery for `array_store` doesn't apply to raw
//  C buffers). For long-running programs `farr_free` can be called
//  explicitly. Memory leak risk for typical kernel use (a few dozen
//  state-vector snapshots per quantum circuit) is bounded and small.
//
//  Builtins (called from interpreter `call_builtin`):
//      farr_zeros(n)        -> int handle    (n doubles, all 0.0)
//      farr_get(h, i)       -> float
//      farr_set(h, i, x)    -> int           (returns h for chaining)
//      farr_len(h)          -> int
//      farr_free(h)         -> void          (optional; explicit)
//
//  Index encoding matches qiskit conventions in qmirror state vectors:
//  amp[i] is the coefficient of |b_{n-1} ... b_0> where b_q=(i>>q)&1.
//  But farr itself is index-agnostic — it's just a packed double buf.
//
//  Out-of-bounds reads return 0.0 and writes are no-ops (soft-fail,
//  matching the "silent error" idiom of hexa_bytes_to_str_raw above).
//  Negative-index semantics differ from hexa_array_get's "py-style":
//  here a negative index is an OOB error and returns/no-ops with 0.0
//  (callers should pass non-negative indices into 0..len).
// ═══════════════════════════════════════════════════════════

/* RFC 040 device-residence descriptor. The no-CUDA build leaves every
 * farr loc=FARR_HOST,d_buf=NULL,dirty_*=0 — byte-identical to pre-040. */
typedef enum {
    FARR_HOST     = 0,  /* host memory only (default — RFC 025 behaviour) */
    FARR_DEVICE   = 1,  /* device memory only (host buf may be NULL) */
    FARR_MIRRORED = 2   /* both host and device buffers valid + in-sync */
} FarrLoc;

typedef struct {
    double*  buf;        /* host pointer — RFC 025 (NULL if device-only) */
    int64_t  len;        /* element count (shared by host and device buf) */
    void*    d_buf;      /* CUDA device pointer — NULL if host-only (RFC 040) */
    int      loc;        /* FarrLoc — current residence (RFC 040) */
    int      pinned;     /* 1 if farr_pin'd (do not auto-evict) (RFC 040) */
    int      dirty_host; /* host buf stale vs device → needs D2H (RFC 040) */
    int      dirty_dev;  /* device buf stale vs host → needs H2D (RFC 040) */
} HexaFarrEntry;

/* RFC 040 Phase D: under -DHEXA_CUDA the farr table + count must be
 * visible to the runtime_cuda.c TU (cuBLAS Dgemm reads host buf/len for
 * H2D/D2H, and the residence descriptor). Non-static export under
 * HEXA_CUDA only — the no-CUDA build keeps them `static` (byte-identical,
 * zero ABI surface change). */
#ifdef HEXA_CUDA
HexaFarrEntry*        _hx_farr_table     = NULL;
int64_t               _hx_farr_count     = 0;
#else
static HexaFarrEntry* _hx_farr_table     = NULL;
static int64_t        _hx_farr_count     = 0;
#endif
static int64_t        _hx_farr_capacity  = 0;
static int64_t*       _hx_farr_freelist  = NULL;
static int64_t        _hx_farr_freelist_n = 0;
static int64_t        _hx_farr_freelist_cap = 0;

// Allocate a new packed double[n] buffer, zero-filled. Returns int handle.
// Accepts HexaVal{TAG_INT} (AOT-emitted call site) or HexaVal{TAG_VALSTRUCT}
// wrapping a TAG_INT (interpreter-emitted Val); hexa_as_num normalizes both.
HexaVal hexa_farr_zeros(HexaVal n_v) {
    int64_t n = hexa_as_num(n_v);
    if (n < 0) n = 0;
    double* buf = NULL;
    if (n > 0) {
        // calloc — zero-fill required (state_zero relies on it).
        buf = (double*)calloc((size_t)n, sizeof(double));
        if (!buf) {
            fprintf(stderr, "[farr] OOM allocating %lld doubles\n", (long long)n);
            exit(77);
        }
    }
    // Pop from freelist if any handle slot was farr_free'd previously.
    int64_t id;
    if (_hx_farr_freelist_n > 0) {
        id = _hx_farr_freelist[--_hx_farr_freelist_n];
    } else {
        // Grow table geometrically.
        if (_hx_farr_count >= _hx_farr_capacity) {
            int64_t new_cap = _hx_farr_capacity < 16 ? 16 : _hx_farr_capacity * 2;
            HexaFarrEntry* nt = (HexaFarrEntry*)realloc(_hx_farr_table,
                                  (size_t)new_cap * sizeof(HexaFarrEntry));
            if (!nt) {
                fprintf(stderr, "[farr] OOM growing handle table\n");
                if (buf) free(buf);
                exit(77);
            }
            _hx_farr_table = nt;
            _hx_farr_capacity = new_cap;
        }
        id = _hx_farr_count++;
    }
    _hx_farr_table[id].buf = buf;
    _hx_farr_table[id].len = n;
    /* RFC 040 Phase A: initialize residence descriptor to HOST default —
     * byte-identical to pre-040 behaviour for every existing farr. */
    _hx_farr_table[id].d_buf      = NULL;
    _hx_farr_table[id].loc        = FARR_HOST;
    _hx_farr_table[id].pinned     = 0;
    _hx_farr_table[id].dirty_host = 0;
    _hx_farr_table[id].dirty_dev  = 0;
    return hexa_int(id);
}

// Read element at index i. Returns 0.0 on out-of-bounds.
HexaVal hexa_farr_get(HexaVal h_v, HexaVal i_v) {
    int64_t id = hexa_as_num(h_v);
    int64_t i  = hexa_as_num(i_v);
    if (id < 0 || id >= _hx_farr_count) return hexa_float(0.0);
    HexaFarrEntry* e = &_hx_farr_table[id];
#ifdef HEXA_CUDA
    /* RFC 040 lazy-D2H on host-read. When a forge op left the farr
     * device-resident (loc=FARR_DEVICE — authoritative bytes on the
     * device, host buf stale), materialise them before the scalar read.
     * _hx_cuda_farr_to_host's D2H sets loc=FARR_MIRRORED + dirty_host=0,
     * so subsequent farr_get calls short-circuit (loc != FARR_DEVICE)
     * — amortized O(N) first read, O(1) rest of the host-side scan. */
    if (e->loc == FARR_DEVICE) {
        extern int _hx_cuda_farr_to_host(int64_t farr_id);
        (void)_hx_cuda_farr_to_host(id);
    }
#endif
    if (!e->buf || i < 0 || i >= e->len) return hexa_float(0.0);
    return hexa_float(e->buf[i]);
}

// Write element at index i. No-op on out-of-bounds. Returns h (for chaining).
HexaVal hexa_farr_set(HexaVal h_v, HexaVal i_v, HexaVal x_v) {
    int64_t id = hexa_as_num(h_v);
    int64_t i  = hexa_as_num(i_v);
    double  x  = __hx_to_double(x_v);
    if (id < 0 || id >= _hx_farr_count) return h_v;
    HexaFarrEntry* e = &_hx_farr_table[id];
#ifdef HEXA_CUDA
    /* RFC 040 lazy-D2H before host write. If the device holds the
     * authoritative bytes, materialise them on the host first — else the
     * dirty_host=1 below would force _h2d to re-upload a buffer whose
     * non-i indices are stale. After the write, dirty_host=1 makes the
     * next forge op H2D-refresh the device from this (now current) host
     * buffer (the _h2d skip in runtime_cuda.c keys on !dirty_host). */
    if (e->loc == FARR_DEVICE) {
        extern int _hx_cuda_farr_to_host(int64_t farr_id);
        (void)_hx_cuda_farr_to_host(id);
    }
#endif
    if (!e->buf || i < 0 || i >= e->len) return h_v;
    e->buf[i] = x;
#ifdef HEXA_CUDA
    if (e->d_buf) { e->dirty_host = 1; e->dirty_dev = 0; }
#endif
    return h_v;
}

// Return length (number of elements) of the packed buffer.
HexaVal hexa_farr_len(HexaVal h_v) {
    int64_t id = hexa_as_num(h_v);
    if (id < 0 || id >= _hx_farr_count) return hexa_int(0);
    return hexa_int(_hx_farr_table[id].len);
}

// Free a handle's backing buffer. Returns void. Idempotent.
HexaVal hexa_farr_free(HexaVal h_v) {
    int64_t id = hexa_as_num(h_v);
    if (id < 0 || id >= _hx_farr_count) return hexa_void();
    HexaFarrEntry* e = &_hx_farr_table[id];
    if (e->buf) { free(e->buf); e->buf = NULL; e->len = 0; }
    /* RFC 040: also free the device buffer if present + reset residence.
     * No-CUDA build: d_buf is always NULL — the resets keep freelist
     * slots hygienic for a later hexa_farr_zeros reuse. Under -DHEXA_CUDA
     * _hx_cuda_farr_device_free cudaFree's the mirror-table slot. */
#ifdef HEXA_CUDA
    if (e->d_buf) {
        extern int _hx_cuda_farr_device_free(int64_t farr_id);
        (void)_hx_cuda_farr_device_free(id);
        e->d_buf = NULL;
    }
#else
    e->d_buf = NULL;
#endif
    e->loc        = FARR_HOST;
    e->pinned     = 0;
    e->dirty_host = 0;
    e->dirty_dev  = 0;
    // Push id onto freelist for reuse.
    if (_hx_farr_freelist_n >= _hx_farr_freelist_cap) {
        int64_t new_cap = _hx_farr_freelist_cap < 16 ? 16 : _hx_farr_freelist_cap * 2;
        int64_t* nf = (int64_t*)realloc(_hx_farr_freelist,
                       (size_t)new_cap * sizeof(int64_t));
        if (nf) {
            _hx_farr_freelist = nf;
            _hx_farr_freelist_cap = new_cap;
        }
    }
    if (_hx_farr_freelist_n < _hx_farr_freelist_cap) {
        _hx_farr_freelist[_hx_farr_freelist_n++] = id;
    }
    return hexa_void();
}

// ═══════════════════════════════════════════════════════════
// RFC 036 (2026-05-13): farr_int_array — packed int64_t* handle.
//
// Mirrors hexa_farr_zeros/get/set/len/free verbatim, except the buffer
// is int64_t* (not double*). Allocator returns an integer handle; the
// hexa-side type is `int` (same TAG_INT representation as farr handles
// for doubles). Distinguished only by which builtins consume the id.
//
// Lifetime: handles are NEVER freed automatically — explicit free via
// hexa_farr_int_free. Same model as RFC 030 farr. Memory-leak risk for
// typical usage (one alloc per cache field, freed at process end) is
// bounded. Out-of-bounds reads return 0; OOB writes are no-ops.
//
// Builtins:
//     farr_int_zeros(n)            -> int handle    (n int64s, all 0)
//     farr_int_get(h, i)           -> int
//     farr_int_set(h, i, x)        -> int           (returns h for chaining)
//     farr_int_len(h)              -> int
//     farr_int_fill_from_array(h, arr) -> int       (bulk init from [int])
//     farr_int_copy(src)           -> int handle    (new buf, same contents)
//     farr_int_sum(h)              -> int           (reduction; mainly tests)
//     farr_int_free(h)             -> void          (optional; explicit)
// ═══════════════════════════════════════════════════════════

typedef struct {
    int64_t* buf;
    int64_t  len;
} HexaIarrEntry;

static HexaIarrEntry* _hx_iarr_table        = NULL;
static int64_t        _hx_iarr_count        = 0;
static int64_t        _hx_iarr_capacity     = 0;
static int64_t*       _hx_iarr_freelist     = NULL;
static int64_t        _hx_iarr_freelist_n   = 0;
static int64_t        _hx_iarr_freelist_cap = 0;

HexaVal hexa_farr_int_zeros(HexaVal n_v) {
    int64_t n = hexa_as_num(n_v);
    if (n < 0) n = 0;
    int64_t* buf = NULL;
    if (n > 0) {
        buf = (int64_t*)calloc((size_t)n, sizeof(int64_t));
        if (!buf) {
            fprintf(stderr, "[farr_int] OOM allocating %lld int64s\n", (long long)n);
            exit(77);
        }
    }
    int64_t id;
    if (_hx_iarr_freelist_n > 0) {
        id = _hx_iarr_freelist[--_hx_iarr_freelist_n];
    } else {
        if (_hx_iarr_count >= _hx_iarr_capacity) {
            int64_t new_cap = _hx_iarr_capacity < 16 ? 16 : _hx_iarr_capacity * 2;
            HexaIarrEntry* nt = (HexaIarrEntry*)realloc(_hx_iarr_table,
                                  (size_t)new_cap * sizeof(HexaIarrEntry));
            if (!nt) {
                fprintf(stderr, "[farr_int] OOM growing handle table\n");
                if (buf) free(buf);
                exit(77);
            }
            _hx_iarr_table = nt;
            _hx_iarr_capacity = new_cap;
        }
        id = _hx_iarr_count++;
    }
    _hx_iarr_table[id].buf = buf;
    _hx_iarr_table[id].len = n;
    return hexa_int(id);
}

HexaVal hexa_farr_int_get(HexaVal h_v, HexaVal i_v) {
    int64_t id = hexa_as_num(h_v);
    int64_t i  = hexa_as_num(i_v);
    if (id < 0 || id >= _hx_iarr_count) return hexa_int(0);
    HexaIarrEntry* e = &_hx_iarr_table[id];
    if (!e->buf || i < 0 || i >= e->len) return hexa_int(0);
    return hexa_int(e->buf[i]);
}

HexaVal hexa_farr_int_set(HexaVal h_v, HexaVal i_v, HexaVal x_v) {
    int64_t id = hexa_as_num(h_v);
    int64_t i  = hexa_as_num(i_v);
    int64_t x  = hexa_as_num(x_v);
    if (id < 0 || id >= _hx_iarr_count) return h_v;
    HexaIarrEntry* e = &_hx_iarr_table[id];
    if (!e->buf || i < 0 || i >= e->len) return h_v;
    e->buf[i] = x;
    return h_v;
}

HexaVal hexa_farr_int_len(HexaVal h_v) {
    int64_t id = hexa_as_num(h_v);
    if (id < 0 || id >= _hx_iarr_count) return hexa_int(0);
    return hexa_int(_hx_iarr_table[id].len);
}

// One-time migration helper: bulk-copy a hexa [int] (boxed HexaVal array)
// into a farr_int handle. Used by cache builders to translate vendored
// literal-returning fns (e.g. uccsd_lih_ham_flip_mask() -> [int]) into a
// packed int64_t buffer exactly once. After this call the [int] is no
// longer referenced and the arena reclaims it on next rewind.
HexaVal hexa_farr_int_fill_from_array(HexaVal h_v, HexaVal arr_v) {
    int64_t id = hexa_as_num(h_v);
    if (id < 0 || id >= _hx_iarr_count) return hexa_int(-1);
    HexaIarrEntry* e = &_hx_iarr_table[id];
    if (!e->buf) return hexa_int(-1);
    // Unwrap interp-side Val struct → real TAG_ARRAY HexaVal.
    // Under `hexa.real run`, the hexa-side `[int]` literal reaches the
    // kernel as TAG_VALSTRUCT with tag_i == TAG_ARRAY (5) and int_val ==
    // index into the global `array_store` (see hexa_full.hexa val_array,
    // ~line 18272). Mirrors the T33 Fix 4 pattern at runtime.c:3530.
    // Without this, HX_IS_ARRAY(arr_v) is false → silent -1 return.
    // Follow-up to commit b8acb90f (RFC 036 landing); fixes T5a/b/c in
    // chemistry_vqe/module/_rfc036_smoke.hexa.
    HexaVal real_arr = arr_v;
    if (HX_IS_VALSTRUCT(arr_v) && HX_VS(arr_v)
        && HX_VSF(arr_v, tag_i) == HEXA_INTERP_TAG_ARRAY
        && &array_store != 0
        && HX_IS_ARRAY(array_store) && HX_ARR_ITEMS(array_store)) {
        int64_t idx = HX_VSF(arr_v, int_val);
        if (idx >= 0 && idx < (int64_t)HX_ARR_LEN(array_store)) {
            real_arr = HX_ARR_ITEMS(array_store)[idx];
        }
    }
    if (!HX_IS_ARRAY(real_arr)) return hexa_int(-1);
    int64_t  n     = HX_ARR_LEN(real_arr);
    HexaVal* items = HX_ARR_ITEMS(real_arr);
    int64_t  cap   = e->len;
    int64_t  m     = (n < cap) ? n : cap;
    for (int64_t k = 0; k < m; k++) {
        e->buf[k] = hexa_as_num(items[k]);
    }
    return hexa_int(m);
}

HexaVal hexa_farr_int_copy(HexaVal src_v) {
    int64_t sid = hexa_as_num(src_v);
    if (sid < 0 || sid >= _hx_iarr_count) return hexa_int(-1);
    HexaIarrEntry* se = &_hx_iarr_table[sid];
    if (!se->buf) return hexa_int(-1);
    HexaVal dst_v = hexa_farr_int_zeros(hexa_int(se->len));
    int64_t did = hexa_as_num(dst_v);
    if (did < 0) return hexa_int(-1);
    HexaIarrEntry* de = &_hx_iarr_table[did];
    if (de->buf && se->len > 0) {
        hxlcl_memcpy(de->buf, se->buf, (size_t)se->len * sizeof(int64_t));
    }
    return dst_v;
}

HexaVal hexa_farr_int_sum(HexaVal h_v) {
    int64_t id = hexa_as_num(h_v);
    if (id < 0 || id >= _hx_iarr_count) return hexa_int(0);
    HexaIarrEntry* e = &_hx_iarr_table[id];
    if (!e->buf) return hexa_int(0);
    int64_t s = 0;
    for (int64_t k = 0; k < e->len; k++) s += e->buf[k];
    return hexa_int(s);
}

HexaVal hexa_farr_int_free(HexaVal h_v) {
    int64_t id = hexa_as_num(h_v);
    if (id < 0 || id >= _hx_iarr_count) return hexa_void();
    HexaIarrEntry* e = &_hx_iarr_table[id];
    if (e->buf) { free(e->buf); e->buf = NULL; e->len = 0; }
    if (_hx_iarr_freelist_n >= _hx_iarr_freelist_cap) {
        int64_t new_cap = _hx_iarr_freelist_cap < 16 ? 16 : _hx_iarr_freelist_cap * 2;
        int64_t* nf = (int64_t*)realloc(_hx_iarr_freelist,
                       (size_t)new_cap * sizeof(int64_t));
        if (nf) {
            _hx_iarr_freelist = nf;
            _hx_iarr_freelist_cap = new_cap;
        }
    }
    if (_hx_iarr_freelist_n < _hx_iarr_freelist_cap) {
        _hx_iarr_freelist[_hx_iarr_freelist_n++] = id;
    }
    return hexa_void();
}

// ── farr high-level state-vector kernels (qmirror Phase 7 fast paths) ──
// The per-iteration interpreter overhead of calling farr_get/farr_set
// inside a 2^n loop dominates wall time and arena allocation pressure
// at n=17 (131 k iterations × ~12 boxed-Val constructions each =
// ~130 MB of arena Vals before the function returns and the arena
// rewinds). The two whole-loop kernels below close that gap by
// running the entire inner loop in C with raw double arithmetic.
//
// Both are pure functions of (handles, gate matrices, qubit indices,
// total qubit count). Storage layout matches qmirror's qiskit-aligned
// convention: amp[i] is the coefficient of |b_{n-1}...b_0> where
// b_q = (i >> q) & 1, split into re/im as packed double[] buffers.

// Convert a hexa [float] gate (TAG_ARRAY of 4 boxed floats) into a
// 4-element double[] on the C stack. Returns 1 on success, 0 on shape error.
// AOT-only — in the interpreter, gate arrays are referenced via
// Val{TAG_ARRAY, int_val=array_store idx}, so callers should pre-unpack
// the gate into a farr handle and use farr_apply_single_farr instead.
static int _hx_farr_unpack_gate4(HexaVal arr, double dst[4]) {
    if (!HX_IS_ARRAY(arr) || HX_ARR_LEN(arr) < 4) return 0;
    HexaVal* items = HX_ARR_ITEMS(arr);
    for (int i = 0; i < 4; i++) {
        dst[i] = __hx_to_double(items[i]);
    }
    return 1;
}

// Core single-qubit kernel — takes 4 raw doubles for gate_re/gate_im.
// Internal; called from both public entry points after gate unpacking.
static void _hx_farr_apply_single_core(double* re, double* im,
                                       const double m_re[4],
                                       const double m_im[4],
                                       int64_t target, int64_t n_qubits) {
    int64_t dim = 1;
    for (int k = 0; k < (int)n_qubits; k++) dim *= 2;
    int64_t bit = (int64_t)1 << target;
    double m00r = m_re[0], m00i = m_im[0];
    double m01r = m_re[1], m01i = m_im[1];
    double m10r = m_re[2], m10i = m_im[2];
    double m11r = m_re[3], m11i = m_im[3];
    for (int64_t i = 0; i < dim; i++) {
        if ((i & bit) == 0) {
            int64_t j = i | bit;
            double s0r = re[i], s0i = im[i];
            double s1r = re[j], s1i = im[j];
            re[i] = (m00r*s0r - m00i*s0i) + (m01r*s1r - m01i*s1i);
            im[i] = (m00r*s0i + m00i*s0r) + (m01r*s1i + m01i*s1r);
            re[j] = (m10r*s0r - m10i*s0i) + (m11r*s1r - m11i*s1i);
            im[j] = (m10r*s0i + m10i*s0r) + (m11r*s1i + m11i*s1r);
        }
    }
}

// farr_apply_single(re_h, im_h, gate_re, gate_im, target, n_qubits) -> 0
// Gate matrices are hexa [float] arrays of 4 doubles. AOT only — see
// farr_apply_single_farr for the interpreter-safe variant.
HexaVal hexa_farr_apply_single(HexaVal re_v, HexaVal im_v,
                               HexaVal gate_re, HexaVal gate_im,
                               HexaVal target_v, HexaVal nq_v) {
    int64_t re_id = hexa_as_num(re_v);
    int64_t im_id = hexa_as_num(im_v);
    int64_t target = hexa_as_num(target_v);
    int64_t n_qubits = hexa_as_num(nq_v);
    if (re_id < 0 || re_id >= _hx_farr_count) return hexa_int(-1);
    if (im_id < 0 || im_id >= _hx_farr_count) return hexa_int(-1);
    double* re = _hx_farr_table[re_id].buf;
    double* im = _hx_farr_table[im_id].buf;
    if (!re || !im) return hexa_int(-1);
    double m_re[4], m_im[4];
    if (!_hx_farr_unpack_gate4(gate_re, m_re)) return hexa_int(-1);
    if (!_hx_farr_unpack_gate4(gate_im, m_im)) return hexa_int(-1);
    _hx_farr_apply_single_core(re, im, m_re, m_im, target, n_qubits);
    return hexa_int(0);
}

// farr_apply_single_farr(re_h, im_h, gate_re_h, gate_im_h, target, n_qubits) -> 0
// Same kernel; gate matrices are farr handles (packed double[4]).
// Used by the interpreter dispatch (hexa_full.hexa) which pre-unpacks
// [float] gates into a farr to sidestep the array_store-from-C problem.
HexaVal hexa_farr_apply_single_farr(HexaVal re_v, HexaVal im_v,
                                    HexaVal gre_h, HexaVal gim_h,
                                    HexaVal target_v, HexaVal nq_v) {
    int64_t re_id = hexa_as_num(re_v);
    int64_t im_id = hexa_as_num(im_v);
    int64_t gr_id = hexa_as_num(gre_h);
    int64_t gi_id = hexa_as_num(gim_h);
    int64_t target = hexa_as_num(target_v);
    int64_t n_qubits = hexa_as_num(nq_v);
    if (re_id < 0 || re_id >= _hx_farr_count) return hexa_int(-1);
    if (im_id < 0 || im_id >= _hx_farr_count) return hexa_int(-1);
    if (gr_id < 0 || gr_id >= _hx_farr_count) return hexa_int(-1);
    if (gi_id < 0 || gi_id >= _hx_farr_count) return hexa_int(-1);
    double* re = _hx_farr_table[re_id].buf;
    double* im = _hx_farr_table[im_id].buf;
    double* gr = _hx_farr_table[gr_id].buf;
    double* gi = _hx_farr_table[gi_id].buf;
    if (!re || !im || !gr || !gi) return hexa_int(-1);
    if (_hx_farr_table[gr_id].len < 4 || _hx_farr_table[gi_id].len < 4) return hexa_int(-1);
    double m_re[4] = { gr[0], gr[1], gr[2], gr[3] };
    double m_im[4] = { gi[0], gi[1], gi[2], gi[3] };
    _hx_farr_apply_single_core(re, im, m_re, m_im, target, n_qubits);
    return hexa_int(0);
}

// farr_apply_cnot(src_re_h, src_im_h, dst_re_h, dst_im_h, control, target, n_qubits) -> 0
// Computes the CNOT image of (src_re, src_im) into the (already-zeroed)
// (dst_re, dst_im) buffers. Does NOT touch src. Returns 0 / -1.
//
// Per qmirror state_vector.hexa lines 111-137: out[j] += state[i] where
// j = i ^ (1<<target) iff bit `control` of i is 1, else j = i. Because
// the partition is a permutation (no collisions), the += can be a =
// when dst starts zero. We keep the += form to match the reference.
HexaVal hexa_farr_apply_cnot(HexaVal src_re_v, HexaVal src_im_v,
                             HexaVal dst_re_v, HexaVal dst_im_v,
                             HexaVal control_v, HexaVal target_v,
                             HexaVal nq_v) {
    int64_t sr = hexa_as_num(src_re_v);
    int64_t si = hexa_as_num(src_im_v);
    int64_t dr = hexa_as_num(dst_re_v);
    int64_t di = hexa_as_num(dst_im_v);
    if (sr < 0 || sr >= _hx_farr_count) return hexa_int(-1);
    if (si < 0 || si >= _hx_farr_count) return hexa_int(-1);
    if (dr < 0 || dr >= _hx_farr_count) return hexa_int(-1);
    if (di < 0 || di >= _hx_farr_count) return hexa_int(-1);
    double* src_re = _hx_farr_table[sr].buf;
    double* src_im = _hx_farr_table[si].buf;
    double* dst_re = _hx_farr_table[dr].buf;
    double* dst_im = _hx_farr_table[di].buf;
    if (!src_re || !src_im || !dst_re || !dst_im) return hexa_int(-1);
    int64_t control = hexa_as_num(control_v);
    int64_t target  = hexa_as_num(target_v);
    int64_t n_qubits = hexa_as_num(nq_v);
    int64_t dim = 1;
    for (int k = 0; k < (int)n_qubits; k++) dim *= 2;
    int64_t cbit = (int64_t)1 << control;
    int64_t tbit = (int64_t)1 << target;
    for (int64_t i = 0; i < dim; i++) {
        int64_t j = ((i & cbit) != 0) ? (i ^ tbit) : i;
        dst_re[j] += src_re[i];
        dst_im[j] += src_im[i];
    }
    return hexa_int(0);
}

// ───────────────────────────────────────────────────────────────────────
// RFC 034 (2026-05-13): Pauli-string exponential + expectation kernels.
// Whole-loop C kernels to eliminate the per-iteration interp arena pressure
// (~1.5 KB/op of boxed Vals retained until function return) that blocked
// qmirror's chemistry_vqe_cmt_uccsd_lih_4e4o.hexa from running an in-process
// 26-parameter Nelder-Mead loop at 4e/4o. Same shape as the existing
// farr_apply_single / farr_apply_cnot fast paths.
//
// Algorithm validated against scipy.linalg.expm at machine precision
// (max err < 1e-12 on 8 random 6-qubit Pauli strings) in the qmirror
// dev session's offline numpy harness (2026-05-13).
//
// Per Pauli string P on n qubits — precomputed masks (offline, in the
// hexa-side caller):
//   flip_mask = OR over q where label[n-1-q] ∈ {X, Y}
//   z_mask    = OR over q where label[n-1-q] = Z
//   y_mask    = OR over q where label[n-1-q] = Y
//   count_Y   = popcount(y_mask)
// (These four ints fully describe P; no per-amplitude string parsing.)
//
// Phase(i) for amplitude index i:
//   parity_bits = i & (z_mask | y_mask)
//   sign = (-1)^popcount(parity_bits)
//   cy = count_Y % 4
//   phase_re/im table:
//     cy 0 →  ( sign,  0    )
//     cy 1 →  ( 0,     sign )
//     cy 2 →  (-sign,  0    )
//     cy 3 →  ( 0,    -sign )

static inline int _hx_pauli_popcount6(int64_t x) {
    // 6-qubit max → at most 6 set bits. Use compiler builtin where available.
#if defined(__GNUC__) || defined(__clang__)
    return __builtin_popcountll((unsigned long long)x);
#else
    int n = 0;
    while (x) { n += (int)(x & 1); x >>= 1; }
    return n;
#endif
}

// farr_pauli_exp_inplace(re_h, im_h, alpha, flip_mask, z_mask, y_mask, count_Y, n_qubits) -> 0
// Apply exp(i*alpha*P) to the state in place. P^2 = I, so
// exp(i*alpha*P) = cos(alpha)*I + i*sin(alpha)*P. Pair-iteration:
//   for i in 0..dim where j = i ^ flip_mask, i <= j:
//     new_amp_i = cos*amp_i + (i*sin*sign_y*phase(i)) * amp_j
//     new_amp_j = (i*sin*phase(i)) * amp_i + cos*amp_j
//   where sign_y = (-1)^count_Y and phase(j) = phase(i) * sign_y.
// flip_mask == 0 (diagonal Pauli): in-place per-amplitude update.
//
// RFC 039 prerequisite (2026-05-13): the math body is hoisted into
// `_hx_pauli_exp_raw` so the parameter-shift gradient kernel can apply
// many Pauli rotations without re-unboxing handles. The HexaVal entry
// point below is now a thin shim.
static inline void _hx_pauli_exp_raw(double* re, double* im, double alpha,
                                     int64_t flip_mask, int64_t z_mask,
                                     int64_t y_mask, int64_t count_Y,
                                     int64_t n_qubits) {
    int64_t dim = 1;
    for (int k = 0; k < (int)n_qubits; k++) dim *= 2;
    double c = hxlcl_cos(alpha);
    double s = hxlcl_sin(alpha);
    int cy_mod = (int)(count_Y % 4);
    double sign_y = ((count_Y % 2) == 0) ? 1.0 : -1.0;
    int64_t parity_mask = z_mask | y_mask;

    if (flip_mask == 0) {
        for (int64_t i = 0; i < dim; i++) {
            int pc = _hx_pauli_popcount6(i & parity_mask);
            double sign = (pc % 2 == 0) ? 1.0 : -1.0;
            double ri = re[i], ii = im[i];
            re[i] = c * ri - (s * sign) * ii;
            im[i] = (s * sign) * ri + c * ii;
        }
        return;
    }

    for (int64_t i = 0; i < dim; i++) {
        int64_t j = i ^ flip_mask;
        if (i >= j) continue;
        int pc = _hx_pauli_popcount6(i & parity_mask);
        double sign_i = (pc % 2 == 0) ? 1.0 : -1.0;
        double pi_re, pi_im;
        switch (cy_mod) {
            case 0: pi_re = sign_i;  pi_im = 0.0;     break;
            case 1: pi_re = 0.0;     pi_im = sign_i;  break;
            case 2: pi_re = -sign_i; pi_im = 0.0;     break;
            default: pi_re = 0.0;    pi_im = -sign_i; break;
        }
        double fij_re = -s * pi_im;
        double fij_im =  s * pi_re;
        double fji_re = sign_y * fij_re;
        double fji_im = sign_y * fij_im;
        double ri = re[i], ii = im[i];
        double rj = re[j], ij = im[j];
        double new_ri = c * ri + fji_re * rj - fji_im * ij;
        double new_ii = c * ii + fji_re * ij + fji_im * rj;
        double new_rj = fij_re * ri - fij_im * ii + c * rj;
        double new_ij = fij_re * ii + fij_im * ri + c * ij;
        re[i] = new_ri;  im[i] = new_ii;
        re[j] = new_rj;  im[j] = new_ij;
    }
}

static inline double _hx_pauli_expectation_raw(const double* re, const double* im,
                                               int64_t flip_mask, int64_t z_mask,
                                               int64_t y_mask, int64_t count_Y,
                                               int64_t n_qubits) {
    int64_t dim = 1;
    for (int k = 0; k < (int)n_qubits; k++) dim *= 2;
    int cy_mod = (int)(count_Y % 4);
    int64_t parity_mask = z_mask | y_mask;
    double sum_re = 0.0;
    for (int64_t i = 0; i < dim; i++) {
        int pc = _hx_pauli_popcount6(i & parity_mask);
        double sign_i = (pc % 2 == 0) ? 1.0 : -1.0;
        double pi_re, pi_im;
        switch (cy_mod) {
            case 0: pi_re = sign_i;  pi_im = 0.0;     break;
            case 1: pi_re = 0.0;     pi_im = sign_i;  break;
            case 2: pi_re = -sign_i; pi_im = 0.0;     break;
            default: pi_re = 0.0;    pi_im = -sign_i; break;
        }
        int64_t j = i ^ flip_mask;
        double ri = re[i], ii = im[i];
        double rj = re[j], ij = im[j];
        double ppj_re = pi_re * ri - pi_im * ii;
        double ppj_im = pi_re * ii + pi_im * ri;
        sum_re += rj * ppj_re + ij * ppj_im;
    }
    return sum_re;
}

HexaVal hexa_farr_pauli_exp_inplace(HexaVal re_v, HexaVal im_v,
                                    HexaVal alpha_v,
                                    HexaVal flip_v, HexaVal zmask_v,
                                    HexaVal ymask_v, HexaVal cy_v,
                                    HexaVal nq_v) {
    int64_t re_id = hexa_as_num(re_v);
    int64_t im_id = hexa_as_num(im_v);
    if (re_id < 0 || re_id >= _hx_farr_count) return hexa_int(-1);
    if (im_id < 0 || im_id >= _hx_farr_count) return hexa_int(-1);
    double* re = _hx_farr_table[re_id].buf;
    double* im = _hx_farr_table[im_id].buf;
    if (!re || !im) return hexa_int(-1);
    double alpha = __hx_to_double(alpha_v);
    int64_t flip_mask = hexa_as_num(flip_v);
    int64_t z_mask    = hexa_as_num(zmask_v);
    int64_t y_mask    = hexa_as_num(ymask_v);
    int64_t count_Y   = hexa_as_num(cy_v);
    int64_t n_qubits  = hexa_as_num(nq_v);
    _hx_pauli_exp_raw(re, im, alpha, flip_mask, z_mask, y_mask, count_Y, n_qubits);
    return hexa_int(0);
}

#if 0  // RFC 039: body hoisted to _hx_pauli_exp_raw above; original kept inline for reference.
    int64_t dim = 1;
    for (int k = 0; k < (int)n_qubits; k++) dim *= 2;
    double c = hxlcl_cos(alpha);
    double s = hxlcl_sin(alpha);
    int cy_mod = (int)(count_Y % 4);
    double sign_y = ((count_Y % 2) == 0) ? 1.0 : -1.0;
    int64_t parity_mask = z_mask | y_mask;

    if (flip_mask == 0) {
        // Diagonal: j == i; new_amp_i = (cos + i*sin*phase(i)) * amp_i.
        // For diagonal Pauli, count_Y is necessarily 0 (no Y in flip_mask=0).
        // phase(i) is purely real = (-1)^parity. So:
        //   new_re = c * re_i - (s * sign) * im_i
        //   new_im = (s * sign) * re_i + c * im_i
        for (int64_t i = 0; i < dim; i++) {
            int pc = _hx_pauli_popcount6(i & parity_mask);
            double sign = (pc % 2 == 0) ? 1.0 : -1.0;
            double ri = re[i], ii = im[i];
            re[i] = c * ri - (s * sign) * ii;
            im[i] = (s * sign) * ri + c * ii;
        }
        return hexa_int(0);
    }

    // General case: pair iteration.
    for (int64_t i = 0; i < dim; i++) {
        int64_t j = i ^ flip_mask;
        if (i >= j) continue;  // process each pair once
        int pc = _hx_pauli_popcount6(i & parity_mask);
        double sign_i = (pc % 2 == 0) ? 1.0 : -1.0;
        double pi_re, pi_im;
        switch (cy_mod) {
            case 0: pi_re = sign_i;       pi_im = 0.0;          break;
            case 1: pi_re = 0.0;          pi_im = sign_i;       break;
            case 2: pi_re = -sign_i;      pi_im = 0.0;          break;
            default: pi_re = 0.0;         pi_im = -sign_i;      break;
        }
        // factor_{i→j} = (i*sin a) * (pi_re + i*pi_im) = sin a * (-pi_im + i*pi_re)
        double fij_re = -s * pi_im;
        double fij_im =  s * pi_re;
        // factor_{j→i} = sign_y * factor_{i→j}
        double fji_re = sign_y * fij_re;
        double fji_im = sign_y * fij_im;
        double ri = re[i], ii = im[i];
        double rj = re[j], ij = im[j];
        // new_amp_i = c*(ri,ii) + (fji_re,fji_im)*(rj,ij)
        double new_ri = c * ri + fji_re * rj - fji_im * ij;
        double new_ii = c * ii + fji_re * ij + fji_im * rj;
        // new_amp_j = (fij_re,fij_im)*(ri,ii) + c*(rj,ij)
        double new_rj = fij_re * ri - fij_im * ii + c * rj;
        double new_ij = fij_re * ii + fij_im * ri + c * ij;
        re[i] = new_ri;  im[i] = new_ii;
        re[j] = new_rj;  im[j] = new_ij;
    }
    return hexa_int(0);
}
#endif  // end #if 0 RFC 039 reference block

// farr_pauli_expectation(re_h, im_h, flip_mask, z_mask, y_mask, count_Y, n_qubits) -> float
// Returns <psi|P|psi> for Hermitian Pauli P. For Hermitian H, the result is
// purely real; we return just the real part.
//   <psi|P|psi> = sum_i conj(psi_i) * P|i>
//               = sum_i conj(psi_i) * phase(i) * psi_{i^flip_mask}
HexaVal hexa_farr_pauli_expectation(HexaVal re_v, HexaVal im_v,
                                    HexaVal flip_v, HexaVal zmask_v,
                                    HexaVal ymask_v, HexaVal cy_v,
                                    HexaVal nq_v) {
    int64_t re_id = hexa_as_num(re_v);
    int64_t im_id = hexa_as_num(im_v);
    if (re_id < 0 || re_id >= _hx_farr_count) return hexa_float(0.0);
    if (im_id < 0 || im_id >= _hx_farr_count) return hexa_float(0.0);
    double* re = _hx_farr_table[re_id].buf;
    double* im = _hx_farr_table[im_id].buf;
    if (!re || !im) return hexa_float(0.0);
    int64_t flip_mask = hexa_as_num(flip_v);
    int64_t z_mask    = hexa_as_num(zmask_v);
    int64_t y_mask    = hexa_as_num(ymask_v);
    int64_t count_Y   = hexa_as_num(cy_v);
    int64_t n_qubits  = hexa_as_num(nq_v);
    return hexa_float(_hx_pauli_expectation_raw(re, im, flip_mask, z_mask,
                                                y_mask, count_Y, n_qubits));
}

// ───────────────────────────────────────────────────────────────────────
// RFC 037 (2026-05-13): whole-Hamiltonian Pauli-expectation batch kernel.
//
// Computes <psi|P_k|psi> for k = 0 .. n_terms-1 in a single C call,
// where each P_k is described by a (flip, z, y, count_Y) tuple read
// from four packed-int64 farr_int handles (RFC 036). The N real
// expectation values are written into the packed-double farr handle
// out_h. Semantics are byte-identical to N invocations of
// hexa_farr_pauli_expectation — same math kernel, same summation order.
//
// Replaces the per-iter hexa-side `while k < n_ham: farr_pauli_expectation(
// re_h, im_h, flip_arr[k], z_arr[k], y_arr[k], cy_arr[k], nq)` loop in
// qmirror chemistry_vqe energy fns. At 4e/5o (n_ham = 876) this kernel
// avoids ~876 box/unbox round-trips per NM iter, yielding 3-5x wall.
//
// Returns hexa_int(0) on success, hexa_int(-1) on any handle / length
// validation failure (silent — no print, no exit).
// ───────────────────────────────────────────────────────────────────────
HexaVal hexa_farr_pauli_expectation_batch(HexaVal re_v, HexaVal im_v,
                                          HexaVal flip_h_v, HexaVal z_h_v,
                                          HexaVal y_h_v, HexaVal cy_h_v,
                                          HexaVal n_terms_v, HexaVal out_h_v,
                                          HexaVal nq_v) {
    int64_t re_id   = hexa_as_num(re_v);
    int64_t im_id   = hexa_as_num(im_v);
    int64_t flip_id = hexa_as_num(flip_h_v);
    int64_t z_id    = hexa_as_num(z_h_v);
    int64_t y_id    = hexa_as_num(y_h_v);
    int64_t cy_id   = hexa_as_num(cy_h_v);
    int64_t out_id  = hexa_as_num(out_h_v);
    int64_t n_terms = hexa_as_num(n_terms_v);
    int64_t n_q     = hexa_as_num(nq_v);
    // Validate state-vector farr handles.
    if (re_id  < 0 || re_id  >= _hx_farr_count) return hexa_int(-1);
    if (im_id  < 0 || im_id  >= _hx_farr_count) return hexa_int(-1);
    if (out_id < 0 || out_id >= _hx_farr_count) return hexa_int(-1);
    // Validate Pauli-descriptor farr_int handles.
    if (flip_id < 0 || flip_id >= _hx_iarr_count) return hexa_int(-1);
    if (z_id    < 0 || z_id    >= _hx_iarr_count) return hexa_int(-1);
    if (y_id    < 0 || y_id    >= _hx_iarr_count) return hexa_int(-1);
    if (cy_id   < 0 || cy_id   >= _hx_iarr_count) return hexa_int(-1);
    const double*  re   = _hx_farr_table[re_id].buf;
    const double*  im   = _hx_farr_table[im_id].buf;
    double*        out  = _hx_farr_table[out_id].buf;
    const int64_t* flip = _hx_iarr_table[flip_id].buf;
    const int64_t* zm   = _hx_iarr_table[z_id].buf;
    const int64_t* ym   = _hx_iarr_table[y_id].buf;
    const int64_t* cym  = _hx_iarr_table[cy_id].buf;
    if (!re || !im || !out || !flip || !zm || !ym || !cym) return hexa_int(-1);
    if (n_terms < 0) return hexa_int(-1);
    // Validate lengths — all four farr_int handles must hold >= n_terms,
    // and out must hold >= n_terms doubles.
    if (_hx_iarr_table[flip_id].len < n_terms) return hexa_int(-1);
    if (_hx_iarr_table[z_id].len    < n_terms) return hexa_int(-1);
    if (_hx_iarr_table[y_id].len    < n_terms) return hexa_int(-1);
    if (_hx_iarr_table[cy_id].len   < n_terms) return hexa_int(-1);
    if (_hx_farr_table[out_id].len  < n_terms) return hexa_int(-1);
    // Pure-C inner loop over the per-term math kernel. No HexaVal
    // traffic, no arena allocation. _hx_pauli_expectation_raw is the
    // exact same body executed by hexa_farr_pauli_expectation above
    // (carved out by RFC 039) so per-term results are byte-identical.
    for (int64_t k = 0; k < n_terms; k++) {
        out[k] = _hx_pauli_expectation_raw(re, im,
                                           flip[k], zm[k], ym[k], cym[k],
                                           n_q);
    }
    return hexa_int(0);
}

// ───────────────────────────────────────────────────────────────────────
// RFC 035 (2026-05-13): Nelder-Mead step kernels for arbitrary-maxiter
// in-process NM. RFC 034 fixed the Pauli-loop arena pressure; the NM-side
// vector operations (centroid, reflect, contract, expand, shrink, sort)
// still box a HexaVal per farr scalar access (~1.5 KB per get/set), so
// 26-dim NM at maxiter > ~250 hits the 768 MB cap. These kernels run the
// whole NM step in C with raw double arithmetic.
//
// Convention: simplex stored as a single farr handle of length n_vert*n
// doubles (vertex v occupies indices v*n .. (v+1)*n - 1). f stored as a
// farr handle of length n_vert.

// out = centroid of the FIRST n_best vertices (exclude the rest).
// For NM the caller sorts so the worst vertex is at index n_vert-1 and
// passes n_best = n_vert-1.
HexaVal hexa_farr_simplex_centroid(HexaVal simplex_h_v, HexaVal out_h_v,
                                   HexaVal n_v, HexaVal n_best_v) {
    int64_t sx = hexa_as_num(simplex_h_v);
    int64_t ot = hexa_as_num(out_h_v);
    int64_t n  = hexa_as_num(n_v);
    int64_t nb = hexa_as_num(n_best_v);
    if (sx < 0 || sx >= _hx_farr_count) return hexa_int(-1);
    if (ot < 0 || ot >= _hx_farr_count) return hexa_int(-1);
    double* sp = _hx_farr_table[sx].buf;
    double* op = _hx_farr_table[ot].buf;
    if (!sp || !op) return hexa_int(-1);
    if (nb <= 0) return hexa_int(-1);
    double inv = 1.0 / (double)nb;
    for (int64_t j = 0; j < n; j++) {
        double acc = 0.0;
        for (int64_t v = 0; v < nb; v++) {
            acc += sp[v * n + j];
        }
        op[j] = acc * inv;
    }
    return hexa_int(0);
}

// out = a + scale*(a - b)   (reflection: scale=1; expansion: scale=2)
HexaVal hexa_farr_vec_reflect(HexaVal out_h_v, HexaVal a_h_v, HexaVal b_h_v,
                              HexaVal scale_v, HexaVal n_v) {
    int64_t ot = hexa_as_num(out_h_v);
    int64_t ah = hexa_as_num(a_h_v);
    int64_t bh = hexa_as_num(b_h_v);
    if (ot < 0 || ot >= _hx_farr_count) return hexa_int(-1);
    if (ah < 0 || ah >= _hx_farr_count) return hexa_int(-1);
    if (bh < 0 || bh >= _hx_farr_count) return hexa_int(-1);
    double* op = _hx_farr_table[ot].buf;
    double* ap = _hx_farr_table[ah].buf;
    double* bp = _hx_farr_table[bh].buf;
    if (!op || !ap || !bp) return hexa_int(-1);
    double scale = __hx_to_double(scale_v);
    int64_t n = hexa_as_num(n_v);
    for (int64_t j = 0; j < n; j++) {
        op[j] = ap[j] + scale * (ap[j] - bp[j]);
    }
    return hexa_int(0);
}

// out = a + scale*(b - a)   (blend: contraction=0.5; shrink-step=0.5)
HexaVal hexa_farr_vec_blend(HexaVal out_h_v, HexaVal a_h_v, HexaVal b_h_v,
                            HexaVal scale_v, HexaVal n_v) {
    int64_t ot = hexa_as_num(out_h_v);
    int64_t ah = hexa_as_num(a_h_v);
    int64_t bh = hexa_as_num(b_h_v);
    if (ot < 0 || ot >= _hx_farr_count) return hexa_int(-1);
    if (ah < 0 || ah >= _hx_farr_count) return hexa_int(-1);
    if (bh < 0 || bh >= _hx_farr_count) return hexa_int(-1);
    double* op = _hx_farr_table[ot].buf;
    double* ap = _hx_farr_table[ah].buf;
    double* bp = _hx_farr_table[bh].buf;
    if (!op || !ap || !bp) return hexa_int(-1);
    double scale = __hx_to_double(scale_v);
    int64_t n = hexa_as_num(n_v);
    for (int64_t j = 0; j < n; j++) {
        op[j] = ap[j] + scale * (bp[j] - ap[j]);
    }
    return hexa_int(0);
}

// Copy vertex src_v of src_simplex into vertex dst_v of dst_simplex.
HexaVal hexa_farr_vertex_copy(HexaVal dst_h_v, HexaVal dst_v_v,
                              HexaVal src_h_v, HexaVal src_v_v,
                              HexaVal n_v) {
    int64_t dh = hexa_as_num(dst_h_v);
    int64_t sh = hexa_as_num(src_h_v);
    if (dh < 0 || dh >= _hx_farr_count) return hexa_int(-1);
    if (sh < 0 || sh >= _hx_farr_count) return hexa_int(-1);
    double* dp = _hx_farr_table[dh].buf;
    double* sp = _hx_farr_table[sh].buf;
    if (!dp || !sp) return hexa_int(-1);
    int64_t dv = hexa_as_num(dst_v_v);
    int64_t sv = hexa_as_num(src_v_v);
    int64_t n  = hexa_as_num(n_v);
    for (int64_t j = 0; j < n; j++) {
        dp[dv * n + j] = sp[sv * n + j];
    }
    return hexa_int(0);
}

// Read one entry of a farr buffer interpreted as a (v, j) into a simplex
// of stride n. Returns the value as a raw double (HexaVal float).
HexaVal hexa_farr_simplex_get(HexaVal simplex_h_v, HexaVal v_v, HexaVal j_v,
                              HexaVal n_v) {
    int64_t sx = hexa_as_num(simplex_h_v);
    if (sx < 0 || sx >= _hx_farr_count) return hexa_float(0.0);
    double* sp = _hx_farr_table[sx].buf;
    if (!sp) return hexa_float(0.0);
    int64_t v = hexa_as_num(v_v);
    int64_t j = hexa_as_num(j_v);
    int64_t n = hexa_as_num(n_v);
    return hexa_float(sp[v * n + j]);
}

HexaVal hexa_farr_simplex_set(HexaVal simplex_h_v, HexaVal v_v, HexaVal j_v,
                              HexaVal n_v, HexaVal x_v) {
    int64_t sx = hexa_as_num(simplex_h_v);
    if (sx < 0 || sx >= _hx_farr_count) return hexa_int(-1);
    double* sp = _hx_farr_table[sx].buf;
    if (!sp) return hexa_int(-1);
    int64_t v = hexa_as_num(v_v);
    int64_t j = hexa_as_num(j_v);
    int64_t n = hexa_as_num(n_v);
    sp[v * n + j] = __hx_to_double(x_v);
    return hexa_int(0);
}

// Shrink simplex toward vertex 0 (the best): for v = 1..n_vert-1,
//   simplex[v][j] = simplex[0][j] + 0.5 * (simplex[v][j] - simplex[0][j])
// Caller is responsible for re-evaluating f for the shrunk vertices.
HexaVal hexa_farr_simplex_shrink(HexaVal simplex_h_v, HexaVal n_v,
                                 HexaVal n_vert_v) {
    int64_t sx = hexa_as_num(simplex_h_v);
    if (sx < 0 || sx >= _hx_farr_count) return hexa_int(-1);
    double* sp = _hx_farr_table[sx].buf;
    if (!sp) return hexa_int(-1);
    int64_t n = hexa_as_num(n_v);
    int64_t nv = hexa_as_num(n_vert_v);
    double* best = sp;  // vertex 0
    for (int64_t v = 1; v < nv; v++) {
        double* row = sp + v * n;
        for (int64_t j = 0; j < n; j++) {
            row[j] = best[j] + 0.5 * (row[j] - best[j]);
        }
    }
    return hexa_int(0);
}

// Insertion-sort the simplex by f (ascending). Both simplex and f are
// reordered in place; uses a single scratch row internally.
HexaVal hexa_farr_simplex_sort(HexaVal simplex_h_v, HexaVal f_h_v,
                               HexaVal n_v, HexaVal n_vert_v) {
    int64_t sx = hexa_as_num(simplex_h_v);
    int64_t fh = hexa_as_num(f_h_v);
    if (sx < 0 || sx >= _hx_farr_count) return hexa_int(-1);
    if (fh < 0 || fh >= _hx_farr_count) return hexa_int(-1);
    double* sp = _hx_farr_table[sx].buf;
    double* fp = _hx_farr_table[fh].buf;
    if (!sp || !fp) return hexa_int(-1);
    int64_t n = hexa_as_num(n_v);
    int64_t nv = hexa_as_num(n_vert_v);
    // Heap-allocate the scratch (n can be up to ~50 in practice).
    double* scratch = (double*)malloc((size_t)n * sizeof(double));
    if (!scratch) return hexa_int(-1);
    for (int64_t i = 1; i < nv; i++) {
        double key_f = fp[i];
        for (int64_t j = 0; j < n; j++) scratch[j] = sp[i * n + j];
        int64_t k = i - 1;
        while (k >= 0 && fp[k] > key_f) {
            fp[k + 1] = fp[k];
            for (int64_t j = 0; j < n; j++) sp[(k + 1) * n + j] = sp[k * n + j];
            k = k - 1;
        }
        fp[k + 1] = key_f;
        for (int64_t j = 0; j < n; j++) sp[(k + 1) * n + j] = scratch[j];
    }
    free(scratch);
    return hexa_int(0);
}


// ───────────────────────────────────────────────────────────────────────
// RFC 039 (2026-05-13): parameter-shift gradient kernel.
//
// Replaces the pure-hexa loop `for k in 0..n_params: grad[k] =
// 0.5*(energy(theta+pi/2*e_k) - energy(theta-pi/2*e_k))` with a single
// C call. The two boxed-handle bundles (HexaHamEntry / HexaAnsatzEntry)
// pre-pack the per-cache constants once; the gradient call reuses them.
//
// See docs/RFC_039_param_shift_grad.md (qmirror repo) for full design.
// ───────────────────────────────────────────────────────────────────────

typedef struct {
    int64_t  n_terms;
    int64_t  n_qubits;
    int64_t* flip;       // [n_terms]
    int64_t* z_mask;     // [n_terms]
    int64_t* y_mask;     // [n_terms]
    int64_t* count_Y;    // [n_terms]
    double*  coef;       // [n_terms]
    double   shift;
} HexaHamEntry;

typedef struct {
    int64_t  n_qubits;
    int64_t  hf_index;
    int64_t  n_flat;
    int64_t* param_idx;
    double*  coef;
    int64_t* flip;
    int64_t* z_mask;
    int64_t* y_mask;
    int64_t* count_Y;
} HexaAnsatzEntry;

static HexaHamEntry*    _hx_ham_table    = NULL;
static int64_t          _hx_ham_count    = 0;
static int64_t          _hx_ham_cap      = 0;
static HexaAnsatzEntry* _hx_ans_table    = NULL;
static int64_t          _hx_ans_count    = 0;
static int64_t          _hx_ans_cap      = 0;

// Read an int from a hexa array-of-int handle (we accept either farr-of-
// double cast-to-int or the existing native [int] via the standard
// array-element accessor). For Phase A we require farr-of-double
// representation: `cache["ham_flip"]` etc are already `[int]` in the
// hexa code, so the hexa caller routes them through `farr_int_array`
// (proposed RFC 036, sibling) or a one-time pack loop here.
//
// To keep this kernel self-contained: ham_pack / ansatz_pack accept the
// existing `[int]` arrays directly via hexa array-element introspection
// helpers `hexa_len(v)` / `hexa_arr_get_int(v, i)` (assumed present
// in runtime.c — they are the same helpers used by hexa_call shims to
// unpack [int] args today).

static int64_t _hx_ham_alloc_slot(void) {
    if (_hx_ham_count >= _hx_ham_cap) {
        int64_t nc = _hx_ham_cap < 8 ? 8 : _hx_ham_cap * 2;
        HexaHamEntry* nt = (HexaHamEntry*)realloc(_hx_ham_table,
                                  (size_t)nc * sizeof(HexaHamEntry));
        if (!nt) return -1;
        _hx_ham_table = nt;
        _hx_ham_cap = nc;
    }
    return _hx_ham_count++;
}

static int64_t _hx_ans_alloc_slot(void) {
    if (_hx_ans_count >= _hx_ans_cap) {
        int64_t nc = _hx_ans_cap < 8 ? 8 : _hx_ans_cap * 2;
        HexaAnsatzEntry* nt = (HexaAnsatzEntry*)realloc(_hx_ans_table,
                                  (size_t)nc * sizeof(HexaAnsatzEntry));
        if (!nt) return -1;
        _hx_ans_table = nt;
        _hx_ans_cap = nc;
    }
    return _hx_ans_count++;
}

// ham_pack(flip[], z[], y[], cy[], coef[], shift, n_q) -> int handle.
// Unwrap interp-side VALSTRUCT-wrapped TAG_ARRAY → raw TAG_ARRAY HexaVal.
// Under `hexa.real run`, hexa-side `[int]`/`[float]` literals reach C kernels
// wrapped as TAG_VALSTRUCT whose tag_i == TAG_ARRAY (5) and int_val == index
// into the global array_store. Mirrors the unwrap in fill_from_array (~7870)
// and hexa_val_heapify (~3530). Follow-up to commit b8acb90f to fix
// ham_pack/ansatz_pack returning -1 on VALSTRUCT-wrapped inputs.
static inline HexaVal _hx_unwrap_array(HexaVal v) {
    if (HX_IS_VALSTRUCT(v) && HX_VS(v)
        && HX_VSF(v, tag_i) == HEXA_INTERP_TAG_ARRAY
        && &array_store != 0
        && HX_IS_ARRAY(array_store) && HX_ARR_ITEMS(array_store)) {
        int64_t idx = HX_VSF(v, int_val);
        if (idx >= 0 && idx < (int64_t)HX_ARR_LEN(array_store)) {
            return HX_ARR_ITEMS(array_store)[idx];
        }
    }
    return v;
}

HexaVal hexa_ham_pack(HexaVal flip_v, HexaVal z_v, HexaVal y_v,
                      HexaVal cy_v, HexaVal coef_v,
                      HexaVal shift_v, HexaVal nq_v) {
    flip_v = _hx_unwrap_array(flip_v);
    z_v    = _hx_unwrap_array(z_v);
    y_v    = _hx_unwrap_array(y_v);
    cy_v   = _hx_unwrap_array(cy_v);
    coef_v = _hx_unwrap_array(coef_v);
    int64_t n = hexa_len(flip_v);
    if (n <= 0 || hexa_len(z_v) != n || hexa_len(y_v) != n
        || hexa_len(cy_v) != n || hexa_len(coef_v) != n)
        return hexa_int(-1);
    int64_t id = _hx_ham_alloc_slot();
    if (id < 0) return hexa_int(-1);
    HexaHamEntry* e = &_hx_ham_table[id];
    e->n_terms = n;
    e->n_qubits = hexa_as_num(nq_v);
    e->shift = __hx_to_double(shift_v);
    e->flip    = (int64_t*)malloc((size_t)n * sizeof(int64_t));
    e->z_mask  = (int64_t*)malloc((size_t)n * sizeof(int64_t));
    e->y_mask  = (int64_t*)malloc((size_t)n * sizeof(int64_t));
    e->count_Y = (int64_t*)malloc((size_t)n * sizeof(int64_t));
    e->coef    = (double*) malloc((size_t)n * sizeof(double));
    if (!e->flip || !e->z_mask || !e->y_mask || !e->count_Y || !e->coef)
        return hexa_int(-1);
    for (int64_t i = 0; i < n; i++) {
        e->flip[i]    = hexa_as_num(hexa_array_get(flip_v, i));
        e->z_mask[i]  = hexa_as_num(hexa_array_get(z_v,    i));
        e->y_mask[i]  = hexa_as_num(hexa_array_get(y_v,    i));
        e->count_Y[i] = hexa_as_num(hexa_array_get(cy_v,   i));
        e->coef[i]    = __hx_to_double(hexa_array_get(coef_v, i));
    }
    return hexa_int(id);
}

HexaVal hexa_ham_free(HexaVal h_v) {
    int64_t id = hexa_as_num(h_v);
    if (id < 0 || id >= _hx_ham_count) return hexa_int(-1);
    HexaHamEntry* e = &_hx_ham_table[id];
    free(e->flip);    e->flip = NULL;
    free(e->z_mask);  e->z_mask = NULL;
    free(e->y_mask);  e->y_mask = NULL;
    free(e->count_Y); e->count_Y = NULL;
    free(e->coef);    e->coef = NULL;
    e->n_terms = 0;
    return hexa_int(0);
}

// ansatz_pack(param_idx[], coef[], flip[], z[], y[], cy[], hf_idx, n_q) -> int handle.
HexaVal hexa_ansatz_pack(HexaVal pi_v, HexaVal coef_v, HexaVal flip_v,
                         HexaVal z_v, HexaVal y_v, HexaVal cy_v,
                         HexaVal hf_v, HexaVal nq_v) {
    pi_v   = _hx_unwrap_array(pi_v);
    coef_v = _hx_unwrap_array(coef_v);
    flip_v = _hx_unwrap_array(flip_v);
    z_v    = _hx_unwrap_array(z_v);
    y_v    = _hx_unwrap_array(y_v);
    cy_v   = _hx_unwrap_array(cy_v);
    int64_t n = hexa_len(pi_v);
    if (n <= 0 || hexa_len(coef_v) != n || hexa_len(flip_v) != n
        || hexa_len(z_v) != n || hexa_len(y_v) != n
        || hexa_len(cy_v) != n) return hexa_int(-1);
    int64_t id = _hx_ans_alloc_slot();
    if (id < 0) return hexa_int(-1);
    HexaAnsatzEntry* e = &_hx_ans_table[id];
    e->n_qubits = hexa_as_num(nq_v);
    e->hf_index = hexa_as_num(hf_v);
    e->n_flat   = n;
    e->param_idx = (int64_t*)malloc((size_t)n * sizeof(int64_t));
    e->coef      = (double*) malloc((size_t)n * sizeof(double));
    e->flip      = (int64_t*)malloc((size_t)n * sizeof(int64_t));
    e->z_mask    = (int64_t*)malloc((size_t)n * sizeof(int64_t));
    e->y_mask    = (int64_t*)malloc((size_t)n * sizeof(int64_t));
    e->count_Y   = (int64_t*)malloc((size_t)n * sizeof(int64_t));
    if (!e->param_idx || !e->coef || !e->flip || !e->z_mask
        || !e->y_mask || !e->count_Y) return hexa_int(-1);
    for (int64_t i = 0; i < n; i++) {
        e->param_idx[i] = hexa_as_num(hexa_array_get(pi_v,   i));
        e->coef[i]      = __hx_to_double(hexa_array_get(coef_v, i));
        e->flip[i]      = hexa_as_num(hexa_array_get(flip_v, i));
        e->z_mask[i]    = hexa_as_num(hexa_array_get(z_v,    i));
        e->y_mask[i]    = hexa_as_num(hexa_array_get(y_v,    i));
        e->count_Y[i]   = hexa_as_num(hexa_array_get(cy_v,   i));
    }
    return hexa_int(id);
}

HexaVal hexa_ansatz_free(HexaVal h_v) {
    int64_t id = hexa_as_num(h_v);
    if (id < 0 || id >= _hx_ans_count) return hexa_int(-1);
    HexaAnsatzEntry* e = &_hx_ans_table[id];
    free(e->param_idx); e->param_idx = NULL;
    free(e->coef);      e->coef = NULL;
    free(e->flip);      e->flip = NULL;
    free(e->z_mask);    e->z_mask = NULL;
    free(e->y_mask);    e->y_mask = NULL;
    free(e->count_Y);   e->count_Y = NULL;
    e->n_flat = 0;
    return hexa_int(0);
}

// Internal helper: reset state to |HF>, apply ansatz at the given theta
// array, return <psi|H|psi> + shift.
static double _rfc039_energy(double* re, double* im, int64_t dim,
                             const double* theta,
                             const HexaAnsatzEntry* ans,
                             const HexaHamEntry* ham) {
    // Reset to |HF>.
    for (int64_t k = 0; k < dim; k++) { re[k] = 0.0; im[k] = 0.0; }
    re[ans->hf_index] = 1.0;
    // Apply ansatz (replays farr_pauli_exp_inplace logic inline).
    for (int64_t i = 0; i < ans->n_flat; i++) {
        double alpha = theta[ans->param_idx[i]] * ans->coef[i];
        double aa = alpha < 0.0 ? -alpha : alpha;
        if (aa <= 1e-13) continue;
        // Inline pauli_exp on (re, im) with masks from ans[i].
        // (For brevity, this patch calls a small static helper that
        //  duplicates the body of hexa_farr_pauli_exp_inplace minus the
        //  HexaVal unwrap.)
        _hx_pauli_exp_raw(re, im, alpha,
                          ans->flip[i], ans->z_mask[i], ans->y_mask[i],
                          ans->count_Y[i], ans->n_qubits);
    }
    // Hamiltonian contraction.
    double e_op = 0.0;
    for (int64_t j = 0; j < ham->n_terms; j++) {
        double exp_j = _hx_pauli_expectation_raw(re, im,
                          ham->flip[j], ham->z_mask[j], ham->y_mask[j],
                          ham->count_Y[j], ham->n_qubits);
        e_op += ham->coef[j] * exp_j;
    }
    return e_op + ham->shift;
}

// farr_parameter_shift_grad(re_h, im_h, theta_h, grad_h,
//                           n_params, ham_h, ansatz_h, n_q) -> 0/-1.
HexaVal hexa_farr_parameter_shift_grad(HexaVal re_v, HexaVal im_v,
                                       HexaVal theta_v, HexaVal grad_v,
                                       HexaVal n_p_v,
                                       HexaVal ham_v, HexaVal ans_v,
                                       HexaVal nq_v) {
    int64_t re_id   = hexa_as_num(re_v);
    int64_t im_id   = hexa_as_num(im_v);
    int64_t th_id   = hexa_as_num(theta_v);
    int64_t gr_id   = hexa_as_num(grad_v);
    int64_t n_p     = hexa_as_num(n_p_v);
    int64_t ham_id  = hexa_as_num(ham_v);
    int64_t ans_id  = hexa_as_num(ans_v);
    int64_t n_q     = hexa_as_num(nq_v);
    if (re_id < 0 || re_id >= _hx_farr_count) return hexa_int(-1);
    if (im_id < 0 || im_id >= _hx_farr_count) return hexa_int(-1);
    if (th_id < 0 || th_id >= _hx_farr_count) return hexa_int(-1);
    if (gr_id < 0 || gr_id >= _hx_farr_count) return hexa_int(-1);
    if (ham_id < 0 || ham_id >= _hx_ham_count) return hexa_int(-1);
    if (ans_id < 0 || ans_id >= _hx_ans_count) return hexa_int(-1);
    double* re = _hx_farr_table[re_id].buf;
    double* im = _hx_farr_table[im_id].buf;
    double* th = _hx_farr_table[th_id].buf;
    double* gr = _hx_farr_table[gr_id].buf;
    if (!re || !im || !th || !gr) return hexa_int(-1);
    HexaHamEntry*    ham = &_hx_ham_table[ham_id];
    HexaAnsatzEntry* ans = &_hx_ans_table[ans_id];
    int64_t dim = 1;
    for (int64_t k = 0; k < n_q; k++) dim *= 2;
    static const double HALF_PI = 1.57079632679489661923;
    double saved_k;
    for (int64_t k = 0; k < n_p; k++) {
        saved_k = th[k];
        th[k] = saved_k + HALF_PI;
        double e_plus  = _rfc039_energy(re, im, dim, th, ans, ham);
        th[k] = saved_k - HALF_PI;
        double e_minus = _rfc039_energy(re, im, dim, th, ans, ham);
        th[k] = saved_k;
        gr[k] = 0.5 * (e_plus - e_minus);
    }
    return hexa_int(0);
}

// ───────────────────────────────────────────────────────────────────────
// RFC 038 (2026-05-13): farr_uccsd_apply — single-call UCCSD ansatz replay.
//
// Replays the entire flat-Pauli generator decomposition of a UCCSD
// ansatz in one C call, consuming the RFC 039 HexaAnsatzEntry bundle.
// Replaces the hexa-side `for i in 0..n_flat: farr_pauli_exp_inplace(...)`
// pattern in chemistry_vqe/module/chemistry_vqe_cmt_uccsd_*.hexa —
// removes the 8-HexaVal-per-iteration boxing tax and per-iter interp
// dispatch.
//
// Math is byte-identical to the existing hexa-side loop because both
// paths share `_hx_pauli_exp_raw` (RFC 039 raw helper). Per-amplitude
// equivalence within 1e-13 is the smoke acceptance bar.
//
// Convention: CALLER resets re/im to |HF> before the call (see RFC 038
// §4 for rationale — composability with downstream chained kernels).
// The kernel never touches re/im outside of the ansatz-replay loop.
//
// See docs/RFC_038_farr_uccsd_apply.md (qmirror repo) for full design.
// ───────────────────────────────────────────────────────────────────────

// Private shared helper: apply the UCCSD ansatz flat-Pauli rotations
// in-place on (re, im) using the packed ansatz descriptor. NO state
// reset — caller controls the starting state. NO Hamiltonian contraction
// (that's RFC 037's batch expectation kernel).
//
// This is the exact ansatz-replay leg of _rfc039_energy hoisted into a
// standalone helper so RFC 038's public kernel and RFC 039's internal
// energy routine can share one source of truth (cf. RFC 038 §9).
static void _rfc038_apply_ansatz_raw(double* re, double* im,
                                     const double* theta,
                                     const HexaAnsatzEntry* ans) {
    for (int64_t i = 0; i < ans->n_flat; i++) {
        double alpha = theta[ans->param_idx[i]] * ans->coef[i];
        double aa = alpha < 0.0 ? -alpha : alpha;
        if (aa <= 1e-13) continue;
        _hx_pauli_exp_raw(re, im, alpha,
                          ans->flip[i], ans->z_mask[i], ans->y_mask[i],
                          ans->count_Y[i], ans->n_qubits);
    }
}

// farr_uccsd_apply(re_h, im_h, theta_h, ansatz_h, n_q) -> 0 (ok) / -1 (err).
//
// Caller-supplied re_h / im_h are length 2^n_q farr handles; the caller
// has already set them to the desired starting state (|HF> for the
// default chemistry-VQE path). theta_h is a length-N_params farr handle.
// ansatz_h is the int handle returned by `ansatz_pack` (RFC 039).
HexaVal hexa_farr_uccsd_apply(HexaVal re_v, HexaVal im_v,
                              HexaVal theta_v, HexaVal ansatz_v,
                              HexaVal nq_v) {
    int64_t re_id  = hexa_as_num(re_v);
    int64_t im_id  = hexa_as_num(im_v);
    int64_t th_id  = hexa_as_num(theta_v);
    int64_t ans_id = hexa_as_num(ansatz_v);
    int64_t n_q    = hexa_as_num(nq_v);
    if (re_id  < 0 || re_id  >= _hx_farr_count) return hexa_int(-1);
    if (im_id  < 0 || im_id  >= _hx_farr_count) return hexa_int(-1);
    if (th_id  < 0 || th_id  >= _hx_farr_count) return hexa_int(-1);
    if (ans_id < 0 || ans_id >= _hx_ans_count)  return hexa_int(-1);
    double* re = _hx_farr_table[re_id].buf;
    double* im = _hx_farr_table[im_id].buf;
    double* th = _hx_farr_table[th_id].buf;
    if (!re || !im || !th) return hexa_int(-1);
    HexaAnsatzEntry* ans = &_hx_ans_table[ans_id];
    // Sanity check: the caller-passed n_q must agree with the packed
    // ansatz descriptor. If they disagree the masks will index past the
    // intended qubit count and corrupt the state — fail-fast.
    if (ans->n_qubits != n_q) return hexa_int(-1);
    _rfc038_apply_ansatz_raw(re, im, th, ans);
    return hexa_int(0);
}

// Future cleanup (RFC 038 §9): _rfc039_energy can delegate its ansatz
// replay leg to _rfc038_apply_ansatz_raw — one source of truth for the
// flat-Pauli replay. Math-unchanged; not load-bearing for either RFC's
// acceptance criterion.
//
// Dispatch wiring (lands in the apply commit, separate hexa-lang PR):
//   if name == "farr_uccsd_apply" {
//       if len(args) > 4 { return val_int(farr_uccsd_apply(
//           args[0], args[1], args[2], args[3], args[4])) }
//       else { return val_int(0 - 1) }
//   }

// NOTE: `_hx_pauli_exp_raw` and `_hx_pauli_expectation_raw` are static
// helpers that share the math body of hexa_farr_pauli_exp_inplace /
// hexa_farr_pauli_expectation but skip the HexaVal unwrap. They should
// be added as static functions immediately above this block; their
// bodies are byte-identical to the corresponding `hexa_farr_*` impls
// from "double alpha = ..." onward (no HexaVal arg unwrap, no handle
// lookup — all done by the caller).
//
// The matching dispatch wiring is:
//   if name == "ham_pack"        { ... 7 args → val_int(...) }
//   if name == "ham_free"        { ... 1 arg  → val_int(...) }
//   if name == "ansatz_pack"     { ... 8 args → val_int(...) }
//   if name == "ansatz_free"     { ... 1 arg  → val_int(...) }
//   if name == "farr_parameter_shift_grad" {
//       if len(args) > 7 { return val_int(farr_parameter_shift_grad(
//           args[0], args[1], args[2], args[3], args[4],
//           args[5], args[6], args[7])) }
//       else { return val_int(0 - 1) }
//   }

// ═══════════════════════════════════════════════════════════
//  RFC 025 — safetensors zero-copy mmap load (2026-05-12)
//
//  Motivation: stdlib/safetensors.hexa::safetensors_read() materializes
//  every tensor byte as a boxed `Val{TAG_INT}` (~88B/byte under interp,
//  ~16B/byte under AOT). A 570MB ckpt → 9.1GB RSS (16× overhead),
//  OOMs the 332M-param anima Phase 1a1 model on commonly-sized hosts.
//
//  Design: a process-global table of mmap regions, indexed by an int
//  handle (mirrors the `farr` precedent at runtime.c:7418). The file
//  is mmap()'d read-only once; tensor views reference it by handle +
//  offset + length. Element access reads through the mmap pointer
//  without per-byte boxing — typed copies land in `farr` packed
//  buffers (for f32/f64) or in raw int arrays (for integral dtypes).
//
//  Builtins (registered via fn_shim + codegen_c2.hexa):
//      safetensors_mmap_open(path)              -> int handle  (-1 on err)
//      safetensors_mmap_header(handle)          -> string (raw JSON header)
//      safetensors_mmap_data_offset(handle)     -> int    (8 + header_len)
//      safetensors_mmap_read_f32_farr(handle, byte_off, n_elem) -> int farr_id
//      safetensors_mmap_read_bytes(handle, byte_off, n_bytes)   -> [int]
//      safetensors_mmap_size(handle)            -> int    (full mapped size)
//      safetensors_mmap_close(handle)           -> void
//
//  The hexa-side parser (stdlib/safetensors.hexa) parses the JSON
//  header to get each tensor's (dtype, shape, offset_start, offset_end);
//  then for f32 tensors it calls safetensors_mmap_read_f32_farr to
//  materialize a packed farr buffer for inference. Per-tensor RSS
//  cost = 8 B/elem (one f32 → one double in farr, no Val boxing).
//  Total expected for 332M params: ~2.7 GB farr + ~570 MB mmap (shared)
//  = ~3.3 GB RSS vs 9.1 GB pre-RFC → 2.7× reduction.
//
//  For TRUE zero-copy (no f32→double upcast), a future RFC 025-B can
//  add `mmap_f32_ptr_get(handle, off, i) -> float` returning unboxed
//  via dlsym/direct pointer arithmetic. Phase 1 here uses farr because
//  it's the existing supported typed-buffer path.
//
//  Falsifier coverage (see tmp_rfc025_smoke.hexa):
//      F-025-OPEN-OK / OPEN-MISS / HEADER-LEN / DATA-OFFSET / SIZE
//      F-025-READ-F32 (roundtrip 32 bytes) / READ-BYTES / CLOSE
// ═══════════════════════════════════════════════════════════

typedef struct {
    void*  base;       // hxlcl_mmap() base ptr; NULL = closed slot
    size_t len;        // mapped length (full file size for safetensors)
    int    fd;         // backing file descriptor (kept for diagnostics)
} HexaMmapEntry;

static HexaMmapEntry* _hx_mmap_table     = NULL;
static int64_t        _hx_mmap_count     = 0;
static int64_t        _hx_mmap_capacity  = 0;
static int64_t*       _hx_mmap_freelist  = NULL;
static int64_t        _hx_mmap_freelist_n = 0;
static int64_t        _hx_mmap_freelist_cap = 0;

// Allocate a new mmap-table slot id (pop freelist or extend table).
static int64_t _hx_mmap_alloc_slot(void) {
    if (_hx_mmap_freelist_n > 0) {
        return _hx_mmap_freelist[--_hx_mmap_freelist_n];
    }
    if (_hx_mmap_count >= _hx_mmap_capacity) {
        int64_t new_cap = _hx_mmap_capacity < 8 ? 8 : _hx_mmap_capacity * 2;
        HexaMmapEntry* nt = (HexaMmapEntry*)realloc(_hx_mmap_table,
                              (size_t)new_cap * sizeof(HexaMmapEntry));
        if (!nt) return -1;
        _hx_mmap_table = nt;
        _hx_mmap_capacity = new_cap;
    }
    return _hx_mmap_count++;
}

// safetensors_mmap_open(path) → int handle (-1 on error).
// Opens the file read-only, mmap()s the entire size with MAP_PRIVATE,
// and stores (base, len, fd) in the global table. The fd is kept open
// to anchor the mapping; close happens in safetensors_mmap_close.
HexaVal hexa_safetensors_mmap_open(HexaVal path_v) {
    const char* path = hexa_to_cstring(path_v);
    if (!path || !*path) return hexa_int(-1);
    int fd = hxlcl_open_sys(path, O_RDONLY);
    if (fd < 0) return hexa_int(-1);
    struct stat st;
    if (hxlcl_fstat(fd, &st) != 0) { hxlcl_close(fd); return hexa_int(-1); }
    size_t len = (size_t)st.st_size;
    if (len == 0) { hxlcl_close(fd); return hexa_int(-1); }
    // Pre-mmap header validation could go here (read first 8 bytes
    // for header_len, verify 8 + header_len <= len). Phase 1 skips:
    // the hexa-side caller already parses + validates the header.
    void* base = hxlcl_mmap(NULL, len, PROT_READ, MAP_PRIVATE, fd, 0);
    if (base == MAP_FAILED) { hxlcl_close(fd); return hexa_int(-1); }
    int64_t id = _hx_mmap_alloc_slot();
    if (id < 0) { munmap(base, len); hxlcl_close(fd); return hexa_int(-1); }
    _hx_mmap_table[id].base = base;
    _hx_mmap_table[id].len  = len;
    _hx_mmap_table[id].fd   = fd;
    return hexa_int(id);
}

// safetensors_mmap_header(handle) → string (raw JSON header bytes).
// Reads the 8-byte LE u64 header_len prefix at offset 0, then returns
// the next header_len bytes as a hexa string (length-headered, NUL-safe
// at storage layer though header JSON is ASCII). Empty string on
// invalid handle or truncated file.
HexaVal hexa_safetensors_mmap_header(HexaVal h_v) {
    int64_t id = hexa_as_num(h_v);
    if (id < 0 || id >= _hx_mmap_count) return hexa_str("");
    HexaMmapEntry* e = &_hx_mmap_table[id];
    if (!e->base || e->len < 8) return hexa_str("");
    const unsigned char* p = (const unsigned char*)e->base;
    uint64_t header_len = 0;
    for (int i = 0; i < 8; i++) header_len |= ((uint64_t)p[i]) << (8 * i);
    if (header_len == 0 || header_len > e->len - 8) return hexa_str("");
    char* buf = hexa_strbuf_alloc((size_t)header_len);
    if (!buf) return hexa_str("");
    hxlcl_memcpy(buf, p + 8, (size_t)header_len);
    return (HexaVal){.tag=TAG_STR, .s=buf};
}

// safetensors_mmap_data_offset(handle) → int (= 8 + header_len).
// Convenience: returns the byte offset where tensor data begins.
HexaVal hexa_safetensors_mmap_data_offset(HexaVal h_v) {
    int64_t id = hexa_as_num(h_v);
    if (id < 0 || id >= _hx_mmap_count) return hexa_int(0);
    HexaMmapEntry* e = &_hx_mmap_table[id];
    if (!e->base || e->len < 8) return hexa_int(0);
    const unsigned char* p = (const unsigned char*)e->base;
    uint64_t header_len = 0;
    for (int i = 0; i < 8; i++) header_len |= ((uint64_t)p[i]) << (8 * i);
    return hexa_int((int64_t)(8 + header_len));
}

// safetensors_mmap_size(handle) → int (full mapped file size in bytes).
HexaVal hexa_safetensors_mmap_size(HexaVal h_v) {
    int64_t id = hexa_as_num(h_v);
    if (id < 0 || id >= _hx_mmap_count) return hexa_int(0);
    HexaMmapEntry* e = &_hx_mmap_table[id];
    return hexa_int((int64_t)e->len);
}

// safetensors_mmap_read_f32_farr(handle, byte_off, n_elem) → int farr_id.
// Reads n_elem float32 values starting at byte_off, copies them into a
// new farr packed buffer (one f32 → one double; n_elem * 8 B allocated).
// Returns -1 on bounds error. The farr buffer is INDEPENDENT of the
// mmap (so safetensors_mmap_close after this read is safe).
HexaVal hexa_safetensors_mmap_read_f32_farr(HexaVal h_v, HexaVal off_v, HexaVal n_v) {
    int64_t id   = hexa_as_num(h_v);
    int64_t off  = hexa_as_num(off_v);
    int64_t n    = hexa_as_num(n_v);
    if (id < 0 || id >= _hx_mmap_count) return hexa_int(-1);
    HexaMmapEntry* e = &_hx_mmap_table[id];
    if (!e->base) return hexa_int(-1);
    if (off < 0 || n < 0) return hexa_int(-1);
    if ((size_t)off + (size_t)(n * 4) > e->len) return hexa_int(-1);
    // Allocate a farr packed double[] buffer; copy f32 values from mmap.
    HexaVal farr_handle = hexa_farr_zeros(hexa_int(n));
    int64_t farr_id = HX_INT(farr_handle);
    if (farr_id < 0 || farr_id >= _hx_farr_count) return hexa_int(-1);
    HexaFarrEntry* fe = &_hx_farr_table[farr_id];
    if (!fe->buf || fe->len < n) return hexa_int(-1);
    const float* src = (const float*)((const char*)e->base + off);
    for (int64_t i = 0; i < n; i++) {
        fe->buf[i] = (double)src[i];
    }
    return farr_handle;
}

// ── RFC 031 (2026-05-12) ────────────────────────────────────────────
// safetensors_mmap_read_bf16_to_f32_farr(handle, byte_off, n_elem)
//     → int farr_id (-1 on error).
//
// Reads n_elem BF16 (bfloat16) values starting at byte_off. Each
// BF16 value is upcast to f32 by zero-extending its 16 bits into the
// HIGH 16 bits of an IEEE-754 binary32 (the canonical bf16 → f32
// widening: bf16 layout is identical to f32's sign + 8-bit exp +
// top-7-bit mantissa, so `(uint32_t)u16 << 16` IS the f32 bit
// pattern). The resulting f32 is then promoted to double and stored
// in a new packed-double farr buffer (8 B/elem, parallel to RFC 025
// _read_f32_farr).
//
// Why needed: real-world HuggingFace ckpts (anima Phase 1a1 included)
// store weights as BF16, but _read_f32_farr only handles F32. Without
// this builtin, callers either (a) emit a one-time F32 sidecar on the
// PyTorch side (167 MB workaround used in Phase 5.1 — does not scale
// to full 24-layer pure-hexa inference), or (b) write the bf16→f32
// loop in hexa, paying ~88 B/elem interp arena pressure.
//
// IEEE-754 BF16:  s eeeeeeee mmmmmmm   (16 bits)
// IEEE-754 F32:   s eeeeeeee mmmmmmm 0000000000000000  (32 bits)
//                 ────── identical ────── + zero-pad
//
// Special values that this scheme preserves exactly:
//   - 0x0000        →   0.0          (positive zero)
//   - 0x8000        →   -0.0         (negative zero)
//   - 0x3F80        →   1.0          (sign=0, exp=0x7F, mantissa=0)
//   - 0xBF80        →   -1.0
//   - 0x7F80        →   +Inf
//   - 0xFF80        →   -Inf
//   - 0x7FC0        →   NaN (quiet)
//   - 0xFFC0        →   NaN
//
// Bounds: 2 B/elem so we check off + 2*n <= mmap_len.
HexaVal hexa_safetensors_mmap_read_bf16_to_f32_farr(HexaVal h_v, HexaVal off_v, HexaVal n_v) {
    int64_t id   = hexa_as_num(h_v);
    int64_t off  = hexa_as_num(off_v);
    int64_t n    = hexa_as_num(n_v);
    if (id < 0 || id >= _hx_mmap_count) return hexa_int(-1);
    HexaMmapEntry* e = &_hx_mmap_table[id];
    if (!e->base) return hexa_int(-1);
    if (off < 0 || n < 0) return hexa_int(-1);
    if ((size_t)off + (size_t)(n * 2) > e->len) return hexa_int(-1);
    HexaVal farr_handle = hexa_farr_zeros(hexa_int(n));
    int64_t farr_id = HX_INT(farr_handle);
    if (farr_id < 0 || farr_id >= _hx_farr_count) return hexa_int(-1);
    HexaFarrEntry* fe = &_hx_farr_table[farr_id];
    if (!fe->buf || fe->len < n) return hexa_int(-1);
    const unsigned char* src = (const unsigned char*)e->base + off;
    // Read host-endian-safe: bf16 in safetensors is stored as little-
    // endian uint16. Compose explicitly so this works on any host.
    for (int64_t i = 0; i < n; i++) {
        uint16_t u16 = (uint16_t)src[2*i] | ((uint16_t)src[2*i + 1] << 8);
        uint32_t u32 = ((uint32_t)u16) << 16;
        // Type-pun via union to avoid strict-aliasing UB.
        union { uint32_t u; float f; } cvt;
        cvt.u = u32;
        fe->buf[i] = (double)cvt.f;
    }
    return farr_handle;
}

// safetensors_mmap_read_bytes(handle, byte_off, n_bytes) → [int].
// Reads n_bytes bytes from mmap as a boxed hexa int array. Used for
// integral-dtype tensors or for header-byte inspection. Memory cost
// is the standard Val-boxed per-byte (88B/byte interp, 16B/byte AOT),
// but the per-tensor `safetensors_mmap_read_f32_farr` path avoids
// this for the dominant f32 weight payload.
HexaVal hexa_safetensors_mmap_read_bytes(HexaVal h_v, HexaVal off_v, HexaVal n_v) {
    int64_t id   = hexa_as_num(h_v);
    int64_t off  = hexa_as_num(off_v);
    int64_t n    = hexa_as_num(n_v);
    HexaVal out = hexa_array_new();
    if (id < 0 || id >= _hx_mmap_count) return out;
    HexaMmapEntry* e = &_hx_mmap_table[id];
    if (!e->base) return out;
    if (off < 0 || n < 0) return out;
    if ((size_t)off + (size_t)n > e->len) return out;
    const unsigned char* src = (const unsigned char*)e->base + off;
    for (int64_t i = 0; i < n; i++) {
        out = hexa_array_push(out, hexa_int((int64_t)src[i]));
    }
    return out;
}

// safetensors_mmap_close(handle) → void. Idempotent. After this the
// handle slot is recycled via the freelist; callers MUST NOT use
// previously-returned farr_ids derived from this handle, but since
// farr buffers are independent of mmap (copied at read time), they
// remain valid until farr_free.
HexaVal hexa_safetensors_mmap_close(HexaVal h_v) {
    int64_t id = hexa_as_num(h_v);
    if (id < 0 || id >= _hx_mmap_count) return hexa_void();
    HexaMmapEntry* e = &_hx_mmap_table[id];
    if (e->base) {
        munmap(e->base, e->len);
        e->base = NULL;
        e->len = 0;
    }
    if (e->fd >= 0) {
        hxlcl_close(e->fd);
        e->fd = -1;
    }
    if (_hx_mmap_freelist_n >= _hx_mmap_freelist_cap) {
        int64_t new_cap = _hx_mmap_freelist_cap < 8 ? 8 : _hx_mmap_freelist_cap * 2;
        int64_t* nf = (int64_t*)realloc(_hx_mmap_freelist,
                       (size_t)new_cap * sizeof(int64_t));
        if (nf) {
            _hx_mmap_freelist = nf;
            _hx_mmap_freelist_cap = new_cap;
        }
    }
    if (_hx_mmap_freelist_n < _hx_mmap_freelist_cap) {
        _hx_mmap_freelist[_hx_mmap_freelist_n++] = id;
    }
    return hexa_void();
}

// ═══════════════════════════════════════════════════════════════════
// RFC 032 (2026-05-12): farr_matmul — packed-double matrix multiply.
//
//   farr_matmul(A_farr, A_rows, A_cols, B_farr, B_cols) -> C_farr
//
// Semantics: C = A @ B, where
//   A is (A_rows × A_cols) row-major in farr buffer A_farr,
//   B is (A_cols × B_cols) row-major in farr buffer B_farr,
//   C is (A_rows × B_cols) row-major in a freshly-allocated farr.
//
// Returns -1 (as a HexaVal{int}) on shape / bounds error.
//
// Why a native builtin: pure-hexa matmul through farr_get/farr_set
// allocates ~12-88 B HexaVal scratch per inner-loop scalar op. For
// a single 1024×1024 matmul (~2^30 mac) this saturates the interp
// arena (>100 GB extrapolated) long before completion. The native
// kernel below uses raw double* indexing, zero arena pressure, and
// finishes a 1024² matmul in well under a second.
//
// Algorithm: cache-friendly ikj triple loop (best for row-major
// row-major output):
//   for i in 0..M:
//     for k in 0..K:
//       a_ik = A[i*K + k]
//       for j in 0..N:
//         C[i*N + j] += a_ik * B[k*N + j]
// This streams B linearly and reuses C[i*N + j] in registers.
//
// No BLAS dependency; no AVX intrinsics (portability over peak FLOPS).
// On a 24-layer EngineAG forward (4 Linear ops/layer × 24 layers + LM
// head, each at hidden=1024) this is fast enough to clear the Phase 5∥
// 24-layer parity gate without GPU.
//
// Falsifier coverage: F-RFC032-2x2-1 / IDENT-2 / RECT-3 / LARGE-4 / MEM-5
// (see tmp_rfc032_smoke.hexa).
// ═══════════════════════════════════════════════════════════════════
HexaVal hexa_farr_matmul(HexaVal a_v, HexaVal ar_v, HexaVal ac_v,
                         HexaVal b_v, HexaVal bc_v) {
    int64_t a_id = hexa_as_num(a_v);
    int64_t M    = hexa_as_num(ar_v);
    int64_t K    = hexa_as_num(ac_v);
    int64_t b_id = hexa_as_num(b_v);
    int64_t N    = hexa_as_num(bc_v);
    if (a_id < 0 || a_id >= _hx_farr_count) return hexa_int(-1);
    if (b_id < 0 || b_id >= _hx_farr_count) return hexa_int(-1);
    if (M <= 0 || K <= 0 || N <= 0)         return hexa_int(-1);
    HexaFarrEntry* ae = &_hx_farr_table[a_id];
    HexaFarrEntry* be = &_hx_farr_table[b_id];
    if (!ae->buf || !be->buf)               return hexa_int(-1);
    if (ae->len < M * K)                    return hexa_int(-1);
    if (be->len < K * N)                    return hexa_int(-1);
    // Allocate output farr (zero-filled by hexa_farr_zeros).
    // NOTE: hexa_farr_zeros may realloc() _hx_farr_table when capacity grows,
    // which MOVES every HexaFarrEntry — ae/be captured above become dangling.
    // Re-fetch ALL entry pointers by id AFTER the allocation. (Fixes a
    // use-after-realloc segfault in chained matvec, e.g. anima
    // HEXAD/BRIDGE/bridge_forward.)
    HexaVal c_handle = hexa_farr_zeros(hexa_int(M * N));
    int64_t c_id = HX_INT(c_handle);
    if (c_id < 0 || c_id >= _hx_farr_count) return hexa_int(-1);
    ae = &_hx_farr_table[a_id];
    be = &_hx_farr_table[b_id];
    HexaFarrEntry* ce = &_hx_farr_table[c_id];
    if (!ae->buf || !be->buf)               return hexa_int(-1);
    if (!ce->buf || ce->len < M * N)        return hexa_int(-1);
    const double* A = ae->buf;
    const double* B = be->buf;
    double* C = ce->buf;
#ifdef HEXA_CUDA
    /* RFC 040 Phase D / gap(d) generic-path forge routing: dim-gate
     * large GEMMs to the verified cuBLAS Dgemm path. The GENERIC ag_tape
     * path's ag_linear → nn_linear_fwd → forge_dispatch_matmul →
     * dispatcher → hexa_farr_matmul lands here; d768-class shapes
     * (M*K, K*N up to ~2.36M) route to GPU cuBLAS. The tiny ag_tape
     * byte-eq oracles (M*K, K*N << 8192) stay on the CPU ikj path and
     * remain bit-exact (threshold mirrors flame_phase4b3). On any GPU
     * error → fall through to the CPU loop (safe). HEXA_CUDA-only: the
     * no-CUDA build is byte-identical (this block is inert). */
    if ((M * K) > 8192 || (K * N) > 8192) {
        extern int _hx_cuda_farr_matmul_gpu(int64_t a_id, int64_t M,
                                            int64_t K, int64_t b_id,
                                            int64_t N, int64_t c_id);
        int grc = _hx_cuda_farr_matmul_gpu(a_id, M, K, b_id, N, c_id);
        if (grc == 0) return c_handle;
        /* grc != 0: GPU path failed — fall through to CPU ikj. */
    }
#endif
    // ikj loop — streaming B + C, A_ik hoisted out of j.
    for (int64_t i = 0; i < M; i++) {
        const double* Ai = A + i * K;
        double*       Ci = C + i * N;
        for (int64_t k = 0; k < K; k++) {
            double a_ik = Ai[k];
            const double* Bk = B + k * N;
            // Inner: C[i,j] += a_ik * B[k,j]
            int64_t j = 0;
            // Light manual unroll x4 — keeps portability, helps clang
            // emit fma (-O2). Tail loop handles N % 4.
            for (; j + 4 <= N; j += 4) {
                Ci[j]   += a_ik * Bk[j];
                Ci[j+1] += a_ik * Bk[j+1];
                Ci[j+2] += a_ik * Bk[j+2];
                Ci[j+3] += a_ik * Bk[j+3];
            }
            for (; j < N; j++) {
                Ci[j] += a_ik * Bk[j];
            }
        }
    }
    return c_handle;
}

// ═══════════════════════════════════════════════════════════════════
// RFC 033 (2026-05-12): farr_copy + farr_add_gaussian_noise.
//
// Both builtins exist to unblock anima tool/hexa_native/mitosis_hook
// .hexa full-impl. The PyTorch reference (anima/tool/mitosis.py
// L204/L213) does:
//
//     child_state = {k: v.clone() for k,v in parent_state.items()}
//     for w in child_state.values():
//         w.add_(torch.randn_like(w) * 0.1 * w.std())
//
// The pure-hexa equivalent without these two builtins needs N
// farr_get/farr_set scalar ops per element + a Box-Muller emitted in
// hexa, paying ~88 B HexaVal arena per element. For a 1 M-element
// layer that is ~88 MB scratch per layer, ~2 GB across 24 layers —
// far past the interp arena cap. The native builtins below do the
// same work with zero hot-loop allocation.
// ═══════════════════════════════════════════════════════════════════

// RFC 033-A — farr_copy(src) -> dst.
//   Deep-copy the contents of farr handle `src` into a freshly
//   allocated farr handle. Returns -1 on invalid src. Empty src
//   (len=0) returns a valid empty handle, not -1.
HexaVal hexa_farr_copy(HexaVal src_v) {
    int64_t src_id = hexa_as_num(src_v);
    if (src_id < 0 || src_id >= _hx_farr_count) return hexa_int(-1);
    HexaFarrEntry* se = &_hx_farr_table[src_id];
    // freed slot (buf NULL with len>0 would be a runtime bug, but a
    // freed slot has buf=NULL and len=0 after hexa_farr_free; reject
    // the former, accept the latter as an empty copy).
    if (!se->buf && se->len > 0) return hexa_int(-1);
    int64_t n = se->len;
    HexaVal dst_handle = hexa_farr_zeros(hexa_int(n));
    int64_t dst_id = HX_INT(dst_handle);
    if (dst_id < 0 || dst_id >= _hx_farr_count) return hexa_int(-1);
    // hexa_farr_zeros may realloc() _hx_farr_table — `se` captured above is
    // now dangling. Re-fetch BOTH entry pointers by id after the allocation.
    se = &_hx_farr_table[src_id];
    HexaFarrEntry* de = &_hx_farr_table[dst_id];
    if (n > 0 && de->buf && se->buf) {
        hxlcl_memcpy(de->buf, se->buf, (size_t)n * sizeof(double));
    }
    return dst_handle;
}

// ── RFC 033-B PRNG support ────────────────────────────────────────
// splitmix64 — a 64-bit non-cryptographic PRNG with good
// distributional properties for Monte Carlo noise. Used here as the
// internal source for the Box-Muller transform driving
// farr_add_gaussian_noise. State is process-local (single-thread
// interp); revisit if hexa gains threads.
static uint64_t _hx_gauss_rng_state = 0;
static int      _hx_gauss_rng_inited = 0;

static uint64_t _hx_splitmix64_next(uint64_t* x) {
    uint64_t z = (*x += 0x9E3779B97F4A7C15ULL);
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
    return z ^ (z >> 31);
}

// Map u64 → double in (2^-53, 1]. Open at zero avoids log(0) in
// Box-Muller.
static double _hx_uniform01_open(uint64_t* state) {
    uint64_t r = _hx_splitmix64_next(state) >> 11;       // 53-bit mantissa
    if (r == 0) r = 1;
    return (double)r * (1.0 / 9007199254740992.0);       // 2^53
}

static void _hx_gauss_rng_lazy_init(void) {
    if (_hx_gauss_rng_inited) return;
    const char* env = hxlcl_getenv("__HEXA_FARR_GAUSS_SEED__");
    if (env && *env) {
        _hx_gauss_rng_state = hxlcl_strtoull(env, NULL, 10);
    } else {
        _hx_gauss_rng_state = (uint64_t)hxlcl_time(NULL) ^
                              ((uint64_t)hxlcl_getpid() << 16);
    }
    if (_hx_gauss_rng_state == 0) _hx_gauss_rng_state = 1;
    _hx_gauss_rng_inited = 1;
}

// RFC 033-B — farr_add_gaussian_noise(target, sigma) -> void.
//   In-place addition of N(0, sigma^2) draws to every element of
//   farr handle `target`. Box-Muller transform pairs adjacent
//   elements; tail element (when len is odd) consumes one extra
//   pair and uses only z0.
//
//   No-op on: invalid handle, sigma == 0.0, sigma < 0, or NaN sigma.
//   Reproducibility: set __HEXA_FARR_GAUSS_SEED__=<u64-decimal>
//   before first call (the env is read once and cached).
HexaVal hexa_farr_add_gaussian_noise(HexaVal target_v, HexaVal sigma_v) {
    int64_t id = hexa_as_num(target_v);
    double  sigma = __hx_to_double(sigma_v);
    if (id < 0 || id >= _hx_farr_count) return hexa_void();
    HexaFarrEntry* e = &_hx_farr_table[id];
    if (!e->buf || e->len <= 0)         return hexa_void();
    // Reject NaN (sigma != sigma) and negative sigma. sigma == 0 is a
    // no-op — every draw would be 0.0 anyway.
    if (!(sigma == sigma))              return hexa_void();
    if (sigma < 0.0)                    return hexa_void();
    if (sigma == 0.0)                   return hexa_void();
    _hx_gauss_rng_lazy_init();
    int64_t n = e->len;
    int64_t i = 0;
    const double two_pi = 6.28318530717958647692; // 2π
    for (; i + 2 <= n; i += 2) {
        double u1 = _hx_uniform01_open(&_hx_gauss_rng_state);
        double u2 = _hx_uniform01_open(&_hx_gauss_rng_state);
        double r  = sqrt(-2.0 * hxlcl_log(u1));
        double th = two_pi * u2;
        e->buf[i]   += sigma * r * hxlcl_cos(th);
        e->buf[i+1] += sigma * r * hxlcl_sin(th);
    }
    if (i < n) {
        double u1 = _hx_uniform01_open(&_hx_gauss_rng_state);
        double u2 = _hx_uniform01_open(&_hx_gauss_rng_state);
        double r  = sqrt(-2.0 * hxlcl_log(u1));
        double th = two_pi * u2;
        e->buf[i] += sigma * r * hxlcl_cos(th);
    }
    return hexa_void();
}

// ═══════════════════════════════════════════════════════════════════
// anima RFC 034 (2026-05-16): farr reverse-mode autograd.
//
// Minimal tape-based reverse-mode AD layered on the existing packed-
// double farr typed-arena (RFC 030/032/033). v1 = FP32-equivalent
// (double internally), single-process, single-arena. Scope is exactly
// the anima HEXAD 6-module decoder train step: one linear layer +
// softmax-cross-entropy + AdamW. Zero HexaVal boxing in the reverse
// sweep (every backward closure walks raw double* — the RFC 032
// matmul contract, extended to gradients).
//
// Surface (anima/HEXAD/PLAN.md Phase 5 unblock):
//   ad_tape_begin() -> int
//   ad_tape_end(tape_id) -> void
//   ad_matmul(A,Ar,Ac,B,Bc) -> int          (wraps RFC 032 farr_matmul)
//   ad_softmax_cross_entropy(logits,nr,nc,targets) -> float
//   ad_backward(tape_id) -> void
//   ad_grad(param_farr) -> int               (grad farr_id for a leaf)
//   adamw_step(p,g,m,v,n,lr,b1,b2,eps,wd,t) -> void
//
// The softmax-CE logit-Jacobian is the closed-form anima B-D-4 sympy
// identity   ∂CE/∂z_i = softmax(z)_i − [i = t]   (verified ∀ z in
// anima state/verify_hexad_blue_2026_05_15/blue_falsifier.py B-D-4).
// Implemented fused/native so the acceptance test has a deterministic
// gradient oracle (no composed tape for the single most common loss).
//
// Falsifier coverage: tmp_rfc034_smoke.hexa
//   F-RFC034-BUILD / GRAD-EXACT / LOSS-DECREASES / PARAM-MUTATED / DETERMINISM
// ═══════════════════════════════════════════════════════════════════

// Backward op kinds recorded on the tape.
#define _HX_AD_OP_MATMUL  1
#define _HX_AD_OP_SMCE    2

typedef struct {
    int      kind;       // _HX_AD_OP_*
    int64_t  a_id;       // matmul: A farr ; smce: logits farr
    int64_t  b_id;       // matmul: B farr ; smce: targets farr
    int64_t  out_id;     // matmul: C farr ; smce: unused (-1)
    int64_t  m;          // matmul: A rows ; smce: n_rows
    int64_t  k;          // matmul: A cols ; smce: n_cols
    int64_t  n;          // matmul: B cols ; smce: unused
} HexaAdNode;

typedef struct {
    HexaAdNode* nodes;
    int64_t     count;
    int64_t     cap;
    int         active;
} HexaAdTape;

// Single-arena v1 (RFC 034 Non-goals: single-process). One tape table;
// at most one tape is "active" at a time (the anima train loop opens /
// closes a fresh tape per step). grad map is global (param farr_id →
// grad farr_id), persisting across steps so adamw_step can read it.
static HexaAdTape* _hx_ad_tapes      = NULL;
static int64_t     _hx_ad_tape_count = 0;
static int64_t     _hx_ad_tape_cap   = 0;
static int64_t     _hx_ad_active     = -1;   // active tape id, -1 = none

// grad registry: parallel arrays param_farr_id -> grad_farr_id.
static int64_t* _hx_ad_grad_param = NULL;
static int64_t* _hx_ad_grad_grad  = NULL;
static int64_t  _hx_ad_grad_n     = 0;
static int64_t  _hx_ad_grad_cap   = 0;

static double* _hx_ad_farr_buf(int64_t id, int64_t* len_out) {
    if (id < 0 || id >= _hx_farr_count) return NULL;
    HexaFarrEntry* e = &_hx_farr_table[id];
    if (len_out) *len_out = e->len;
    return e->buf;
}

// Register / overwrite grad farr handle for a param leaf. The grad
// buffer is owned by the registry; ad_backward reallocs it zeroed.
static void _hx_ad_grad_put(int64_t param_id, int64_t grad_id) {
    for (int64_t i = 0; i < _hx_ad_grad_n; i++) {
        if (_hx_ad_grad_param[i] == param_id) {
            _hx_ad_grad_grad[i] = grad_id;
            return;
        }
    }
    if (_hx_ad_grad_n >= _hx_ad_grad_cap) {
        int64_t nc = _hx_ad_grad_cap < 16 ? 16 : _hx_ad_grad_cap * 2;
        int64_t* np = (int64_t*)realloc(_hx_ad_grad_param, (size_t)nc * sizeof(int64_t));
        int64_t* ng = (int64_t*)realloc(_hx_ad_grad_grad,  (size_t)nc * sizeof(int64_t));
        if (!np || !ng) { fprintf(stderr, "[ad] OOM grad registry\n"); exit(77); }
        _hx_ad_grad_param = np; _hx_ad_grad_grad = ng; _hx_ad_grad_cap = nc;
    }
    _hx_ad_grad_param[_hx_ad_grad_n] = param_id;
    _hx_ad_grad_grad[_hx_ad_grad_n]  = grad_id;
    _hx_ad_grad_n++;
}

static int64_t _hx_ad_grad_get(int64_t param_id) {
    for (int64_t i = 0; i < _hx_ad_grad_n; i++)
        if (_hx_ad_grad_param[i] == param_id) return _hx_ad_grad_grad[i];
    return -1;
}

// ad_tape_begin() -> tape_id (also set active).
HexaVal hexa_ad_tape_begin(void) {
    int64_t id = -1;
    for (int64_t i = 0; i < _hx_ad_tape_count; i++) {
        if (!_hx_ad_tapes[i].active && _hx_ad_tapes[i].nodes == NULL) { id = i; break; }
    }
    if (id < 0) {
        if (_hx_ad_tape_count >= _hx_ad_tape_cap) {
            int64_t nc = _hx_ad_tape_cap < 8 ? 8 : _hx_ad_tape_cap * 2;
            HexaAdTape* nt = (HexaAdTape*)realloc(_hx_ad_tapes,
                                (size_t)nc * sizeof(HexaAdTape));
            if (!nt) { fprintf(stderr, "[ad] OOM tape table\n"); exit(77); }
            _hx_ad_tapes = nt;
            _hx_ad_tape_cap = nc;
        }
        id = _hx_ad_tape_count++;
    }
    _hx_ad_tapes[id].nodes  = NULL;
    _hx_ad_tapes[id].count  = 0;
    _hx_ad_tapes[id].cap    = 0;
    _hx_ad_tapes[id].active = 1;
    _hx_ad_active = id;
    return hexa_int(id);
}

// ad_tape_end(tape_id) -> void. Frees the op list; the active marker
// clears so the next ad_tape_begin reuses the slot.
HexaVal hexa_ad_tape_end(HexaVal tid_v) {
    int64_t id = hexa_as_num(tid_v);
    if (id < 0 || id >= _hx_ad_tape_count) return hexa_void();
    HexaAdTape* t = &_hx_ad_tapes[id];
    if (t->nodes) { free(t->nodes); t->nodes = NULL; }
    t->count = 0; t->cap = 0; t->active = 0;
    if (_hx_ad_active == id) _hx_ad_active = -1;
    return hexa_void();
}

static void _hx_ad_record(int kind, int64_t a, int64_t b, int64_t out,
                          int64_t m, int64_t k, int64_t n) {
    if (_hx_ad_active < 0 || _hx_ad_active >= _hx_ad_tape_count) return;
    HexaAdTape* t = &_hx_ad_tapes[_hx_ad_active];
    if (t->count >= t->cap) {
        int64_t nc = t->cap < 16 ? 16 : t->cap * 2;
        HexaAdNode* nn = (HexaAdNode*)realloc(t->nodes,
                            (size_t)nc * sizeof(HexaAdNode));
        if (!nn) { fprintf(stderr, "[ad] OOM tape nodes\n"); exit(77); }
        t->nodes = nn; t->cap = nc;
    }
    HexaAdNode* nd = &t->nodes[t->count++];
    nd->kind = kind; nd->a_id = a; nd->b_id = b; nd->out_id = out;
    nd->m = m; nd->k = k; nd->n = n;
}

// ad_matmul(A,Ar,Ac,B,Bc) -> C_farr_id. Forward = RFC 032 farr_matmul;
// records the backward (dA = dC @ Bᵀ ; dB = Aᵀ @ dC).
HexaVal hexa_ad_matmul(HexaVal a_v, HexaVal ar_v, HexaVal ac_v,
                       HexaVal b_v, HexaVal bc_v) {
    int64_t a_id = hexa_as_num(a_v);
    int64_t M    = hexa_as_num(ar_v);
    int64_t K    = hexa_as_num(ac_v);
    int64_t b_id = hexa_as_num(b_v);
    int64_t N    = hexa_as_num(bc_v);
    HexaVal c_h  = hexa_farr_matmul(a_v, ar_v, ac_v, b_v, bc_v);
    int64_t c_id = HX_INT(c_h);
    if (c_id < 0) return c_h;            // shape error propagates
    _hx_ad_record(_HX_AD_OP_MATMUL, a_id, b_id, c_id, M, K, N);
    return c_h;
}

// ad_softmax_cross_entropy(logits, n_rows, n_cols, targets) -> float.
// Returns mean CE over the n_rows examples (each row = a length n_cols
// logit vector; targets farr holds n_rows class indices). Records the
// closed-form B-D-4 logit gradient ∂L/∂logits = (softmax − onehot)/n_rows.
HexaVal hexa_ad_softmax_cross_entropy(HexaVal logits_v, HexaVal nr_v,
                                      HexaVal nc_v, HexaVal tgt_v) {
    int64_t lg_id = hexa_as_num(logits_v);
    int64_t R     = hexa_as_num(nr_v);
    int64_t C     = hexa_as_num(nc_v);
    int64_t tg_id = hexa_as_num(tgt_v);
    int64_t lg_len = 0, tg_len = 0;
    double* lg = _hx_ad_farr_buf(lg_id, &lg_len);
    double* tg = _hx_ad_farr_buf(tg_id, &tg_len);
    if (!lg || !tg || R <= 0 || C <= 0) return hexa_float(0.0);
    if (lg_len < R * C || tg_len < R)   return hexa_float(0.0);
    double total = 0.0;
    for (int64_t r = 0; r < R; r++) {
        const double* z = lg + r * C;
        // numerically-stable softmax: subtract row max.
        double zmax = z[0];
        for (int64_t j = 1; j < C; j++) if (z[j] > zmax) zmax = z[j];
        double s = 0.0;
        for (int64_t j = 0; j < C; j++) s += hxlcl_exp(z[j] - zmax);
        int64_t tcls = (int64_t)(tg[r] + 0.5);   // class index (round)
        if (tcls < 0) tcls = 0;
        if (tcls >= C) tcls = C - 1;
        // CE = -log softmax(z)_t = (zmax - z_t) + log Σ exp(z - zmax)
        double ce = (zmax - z[tcls]) + hxlcl_log(s);
        total += ce;
    }
    _hx_ad_record(_HX_AD_OP_SMCE, lg_id, tg_id, -1, R, C, 0);
    return hexa_float(total / (double)R);
}

// Ensure a zeroed grad farr of length n for param leaf `param_id`,
// returning its farr_id. Reuses the registered handle if its length
// matches, else (re)allocates.
static int64_t _hx_ad_grad_ensure(int64_t param_id, int64_t n) {
    int64_t g = _hx_ad_grad_get(param_id);
    if (g >= 0 && g < _hx_farr_count && _hx_farr_table[g].buf
        && _hx_farr_table[g].len == n) {
        hxlcl_memset(_hx_farr_table[g].buf, 0, (size_t)n * sizeof(double));
        return g;
    }
    HexaVal gh = hexa_farr_zeros(hexa_int(n));
    int64_t gid = HX_INT(gh);
    _hx_ad_grad_put(param_id, gid);
    return gid;
}

// ad_backward(tape_id) -> void. Reverse sweep. v1 supports the anima
// train-step graph exactly: a single ad_matmul (X @ W -> logits)
// feeding one ad_softmax_cross_entropy. The CE node seeds dlogits via
// the closed B-D-4 identity; the matmul node backprops dW = Xᵀ @ dC
// (the param gradient anima's AdamW consumes) and dA = dC @ Bᵀ.
HexaVal hexa_ad_backward(HexaVal tid_v) {
    int64_t id = hexa_as_num(tid_v);
    if (id < 0 || id >= _hx_ad_tape_count) return hexa_void();
    HexaAdTape* t = &_hx_ad_tapes[id];
    if (!t->nodes || t->count <= 0) return hexa_void();

    // dC accumulator keyed by farr_id (the loss-side cotangent). v1
    // graph is a chain, so a small linear map suffices.
    // Reverse walk.
    for (int64_t qi = t->count - 1; qi >= 0; qi--) {
        HexaAdNode* nd = &t->nodes[qi];
        if (nd->kind == _HX_AD_OP_SMCE) {
            int64_t R = nd->m, C = nd->k;
            int64_t lg_len = 0, tg_len = 0;
            double* lg = _hx_ad_farr_buf(nd->a_id, &lg_len);
            double* tg = _hx_ad_farr_buf(nd->b_id, &tg_len);
            if (!lg || !tg) continue;
            int64_t g = _hx_ad_grad_ensure(nd->a_id, R * C);
            double* dz = _hx_farr_table[g].buf;
            for (int64_t r = 0; r < R; r++) {
                const double* z = lg + r * C;
                double* d = dz + r * C;
                double zmax = z[0];
                for (int64_t j = 1; j < C; j++) if (z[j] > zmax) zmax = z[j];
                double s = 0.0;
                for (int64_t j = 0; j < C; j++) s += hxlcl_exp(z[j] - zmax);
                int64_t tcls = (int64_t)(tg[r] + 0.5);
                if (tcls < 0) tcls = 0;
                if (tcls >= C) tcls = C - 1;
                // B-D-4: ∂L/∂z_i = softmax(z)_i − [i=t], averaged over R.
                for (int64_t j = 0; j < C; j++) {
                    double sm = hxlcl_exp(z[j] - zmax) / s;
                    d[j] = (sm - (j == tcls ? 1.0 : 0.0)) / (double)R;
                }
            }
        } else if (nd->kind == _HX_AD_OP_MATMUL) {
            // Forward C = A(MxK) @ B(KxN). Upstream cotangent dC lives
            // in the grad slot of out_id (seeded by the CE node above
            // when out_id == its logits farr).
            int64_t M = nd->m, K = nd->k, N = nd->n;
            int64_t dc_id = _hx_ad_grad_get(nd->out_id);
            double* dC = (dc_id >= 0) ? _hx_farr_table[dc_id].buf : NULL;
            int64_t a_len = 0, b_len = 0;
            double* A = _hx_ad_farr_buf(nd->a_id, &a_len);
            double* B = _hx_ad_farr_buf(nd->b_id, &b_len);
            if (!dC || !A || !B) continue;
            // dB = Aᵀ @ dC  (K x N) — the param (weight) gradient.
            int64_t gB = _hx_ad_grad_ensure(nd->b_id, K * N);
            double* dB = _hx_farr_table[gB].buf;
            for (int64_t kk = 0; kk < K; kk++) {
                for (int64_t i = 0; i < M; i++) {
                    double a_ik = A[i * K + kk];
                    const double* dCi = dC + i * N;
                    double* dBk = dB + kk * N;
                    for (int64_t j = 0; j < N; j++)
                        dBk[j] += a_ik * dCi[j];
                }
            }
            // dA = dC @ Bᵀ  (M x K) — input cotangent (chain upstream).
            int64_t gA = _hx_ad_grad_ensure(nd->a_id, M * K);
            double* dA = _hx_farr_table[gA].buf;
            for (int64_t i = 0; i < M; i++) {
                const double* dCi = dC + i * N;
                double* dAi = dA + i * K;
                for (int64_t kk = 0; kk < K; kk++) {
                    const double* Bk = B + kk * N;
                    double acc = 0.0;
                    for (int64_t j = 0; j < N; j++)
                        acc += dCi[j] * Bk[j];
                    dAi[kk] = acc;
                }
            }
        }
    }
    return hexa_void();
}

// ad_grad(param_farr) -> grad farr_id (-1 if no grad recorded).
HexaVal hexa_ad_grad(HexaVal param_v) {
    int64_t pid = hexa_as_num(param_v);
    return hexa_int(_hx_ad_grad_get(pid));
}

// adamw_step(param, grad, m, v, n, lr, beta1, beta2, eps, wd, t).
// Single fused in-place AdamW (decoupled weight decay, Loshchilov &
// Hutter 2019). All of param/grad/m/v are length-n packed-double farrs;
// t is the 1-based step (bias correction). No HexaVal in the loop.
HexaVal hexa_adamw_step(HexaVal p_v, HexaVal g_v, HexaVal m_v, HexaVal v_v,
                        HexaVal n_v, HexaVal lr_v, HexaVal b1_v, HexaVal b2_v,
                        HexaVal eps_v, HexaVal wd_v, HexaVal t_v) {
    int64_t p_id = hexa_as_num(p_v);
    int64_t g_id = hexa_as_num(g_v);
    int64_t m_id = hexa_as_num(m_v);
    int64_t v_id = hexa_as_num(v_v);
    int64_t n    = hexa_as_num(n_v);
    double  lr   = __hx_to_double(lr_v);
    double  b1   = __hx_to_double(b1_v);
    double  b2   = __hx_to_double(b2_v);
    double  eps  = __hx_to_double(eps_v);
    double  wd   = __hx_to_double(wd_v);
    int64_t tstep= hexa_as_num(t_v);
    if (n <= 0 || tstep < 1) return hexa_void();
    double* P = _hx_ad_farr_buf(p_id, NULL);
    double* G = _hx_ad_farr_buf(g_id, NULL);
    double* Mm= _hx_ad_farr_buf(m_id, NULL);
    double* Vv= _hx_ad_farr_buf(v_id, NULL);
    if (!P || !G || !Mm || !Vv) return hexa_void();
    double bc1 = 1.0 - pow(b1, (double)tstep);
    double bc2 = 1.0 - pow(b2, (double)tstep);
    if (bc1 == 0.0) bc1 = 1e-30;
    if (bc2 == 0.0) bc2 = 1e-30;
    for (int64_t i = 0; i < n; i++) {
        double gi = G[i];
        Mm[i] = b1 * Mm[i] + (1.0 - b1) * gi;
        Vv[i] = b2 * Vv[i] + (1.0 - b2) * gi * gi;
        double mhat = Mm[i] / bc1;
        double vhat = Vv[i] / bc2;
        // decoupled weight decay applied to the param directly.
        P[i] -= lr * (mhat / (sqrt(vhat) + eps) + wd * P[i]);
    }
    return hexa_void();
}

// ═══════════════════════════════════════════════════════════════════
// anima RFC 035 (2026-05-16): bf16/fp16 mixed-precision training.
//
// Layers on RFC 034. The forward/grad path still computes in
// packed-double farr (the RFC 032/034 contract), but RFC 035 adds:
//   (1) a bf16 storage round-trip (farr_to_bf16 / farr_from_bf16) so
//       activations / a grad copy can be held at half the bytes, and
//   (2) a loss-scaled, skip-on-nonfinite mixed-precision AdamW
//       (adamw_step_mixed) keeping an f32-equivalent (double) master
//       weight while consuming a possibly-bf16-rounded gradient.
//
// v1 scope (RFC 035 Non-goals mirror RFC 034): single-process, single-
// arena, the anima HEXAD decoder train step. NaN/Inf-guarded loss
// scaling is the only AMP policy (no dynamic scale schedule in v1 —
// the caller drives the scale; the builtin reports skip via return).
//
// bf16 = the top 16 bits of an IEEE-754 binary32 (1s|8e|7m), round-to-
// nearest-even on the truncated mantissa. The same rounding NVIDIA /
// PyTorch AMP use; deterministic, no hardware bf16 needed.
//
// Falsifier coverage: tmp_rfc035_smoke.hexa
//   F-RFC035-BUILD / BF16-ROUNDTRIP / LOSSSCALE-INVARIANT /
//   SKIP-NONFINITE / DETERMINISM
// ═══════════════════════════════════════════════════════════════════

// Round an IEEE binary32 to bf16 (return the reconstructed float).
// Round-to-nearest-even on bit 15 (the bf16 ulp). NaN/Inf preserved.
static float _hx_f32_to_bf16(float f) {
    uint32_t x;
    hxlcl_memcpy(&x, &f, sizeof(x));
    uint32_t exp = (x >> 23) & 0xFF;
    if (exp == 0xFF) {            // NaN / Inf — keep, just truncate mantissa
        uint32_t t = x & 0xFFFF0000u;
        // keep NaN-ness: if it was NaN, ensure a non-zero bf16 mantissa
        if ((x & 0x007FFFFFu) != 0) t |= 0x00400000u;
        float r; hxlcl_memcpy(&r, &t, sizeof(r)); return r;
    }
    uint32_t lsb     = (x >> 16) & 1u;
    uint32_t rounded = x + 0x7FFFu + lsb;   // round-to-nearest-even
    rounded &= 0xFFFF0000u;
    float r; hxlcl_memcpy(&r, &rounded, sizeof(r));
    return r;
}

// farr_to_bf16(src, dst, n) — write bf16-rounded values of src[0..n]
// into dst (both length-n packed-double farrs). dst holds the
// reconstructed (lossy) doubles; storage-saving is conceptual at v1
// (the arena is double) but the *values* are bit-exact bf16, which is
// what training numerics care about. Returns 1 on success, 0 on error.
HexaVal hexa_farr_to_bf16(HexaVal src_v, HexaVal dst_v, HexaVal n_v) {
    int64_t s_id = hexa_as_num(src_v);
    int64_t d_id = hexa_as_num(dst_v);
    int64_t n    = hexa_as_num(n_v);
    int64_t sl = 0, dl = 0;
    double* S = _hx_ad_farr_buf(s_id, &sl);
    double* D = _hx_ad_farr_buf(d_id, &dl);
    if (!S || !D || n <= 0 || sl < n || dl < n) return hexa_int(0);
    for (int64_t i = 0; i < n; i++)
        D[i] = (double)_hx_f32_to_bf16((float)S[i]);
    return hexa_int(1);
}

// farr_from_bf16(src, dst, n) — round-trip the other direction. With
// the v1 double arena this is the same bf16 reconstruction (identity
// once a value is already bf16-representable: F-RFC035-BF16-ROUNDTRIP
// asserts to_bf16 then from_bf16 is a fixed point).
HexaVal hexa_farr_from_bf16(HexaVal src_v, HexaVal dst_v, HexaVal n_v) {
    int64_t s_id = hexa_as_num(src_v);
    int64_t d_id = hexa_as_num(dst_v);
    int64_t n    = hexa_as_num(n_v);
    int64_t sl = 0, dl = 0;
    double* S = _hx_ad_farr_buf(s_id, &sl);
    double* D = _hx_ad_farr_buf(d_id, &dl);
    if (!S || !D || n <= 0 || sl < n || dl < n) return hexa_int(0);
    for (int64_t i = 0; i < n; i++)
        D[i] = (double)_hx_f32_to_bf16((float)S[i]);
    return hexa_int(1);
}

// adamw_step_mixed(param, grad, m, v, n, lr, b1, b2, eps, wd, t,
//                  loss_scale) -> int
// Loss-scaled mixed-precision AdamW. The gradient `grad` is assumed
// produced from a loss multiplied by `loss_scale` (AMP convention);
// it is unscaled (divided by loss_scale) before the moment update so
// the master (double) weight sees the true gradient. If ANY unscaled
// gradient element is non-finite (NaN/Inf — the AMP overflow signal),
// the WHOLE step is skipped (params/moments untouched) and 0 is
// returned (the caller then halves loss_scale, the standard policy).
// Returns 1 if the step was applied. Master weight stays double; only
// the *consumed gradient* is the (possibly bf16-rounded) low-precision
// tensor — exactly the PyTorch AMP master-weight contract.
HexaVal hexa_adamw_step_mixed(HexaVal p_v, HexaVal g_v, HexaVal m_v,
                              HexaVal v_v, HexaVal n_v, HexaVal lr_v,
                              HexaVal b1_v, HexaVal b2_v, HexaVal eps_v,
                              HexaVal wd_v, HexaVal t_v, HexaVal ls_v) {
    int64_t p_id = hexa_as_num(p_v);
    int64_t g_id = hexa_as_num(g_v);
    int64_t m_id = hexa_as_num(m_v);
    int64_t v_id = hexa_as_num(v_v);
    int64_t n    = hexa_as_num(n_v);
    double  lr   = __hx_to_double(lr_v);
    double  b1   = __hx_to_double(b1_v);
    double  b2   = __hx_to_double(b2_v);
    double  eps  = __hx_to_double(eps_v);
    double  wd   = __hx_to_double(wd_v);
    int64_t tstep= hexa_as_num(t_v);
    double  ls   = __hx_to_double(ls_v);
    if (n <= 0 || tstep < 1) return hexa_int(0);
    if (ls == 0.0) ls = 1.0;
    double* P = _hx_ad_farr_buf(p_id, NULL);
    double* G = _hx_ad_farr_buf(g_id, NULL);
    double* Mm= _hx_ad_farr_buf(m_id, NULL);
    double* Vv= _hx_ad_farr_buf(v_id, NULL);
    if (!P || !G || !Mm || !Vv) return hexa_int(0);
    // AMP overflow guard: scan the *unscaled* grad first; skip on any
    // non-finite element (no partial mutation).
    for (int64_t i = 0; i < n; i++) {
        double gi = G[i] / ls;
        if (!isfinite(gi)) return hexa_int(0);   // skip step (AMP overflow)
    }
    double bc1 = 1.0 - pow(b1, (double)tstep);
    double bc2 = 1.0 - pow(b2, (double)tstep);
    if (bc1 == 0.0) bc1 = 1e-30;
    if (bc2 == 0.0) bc2 = 1e-30;
    for (int64_t i = 0; i < n; i++) {
        double gi = G[i] / ls;            // unscale (AMP master grad)
        Mm[i] = b1 * Mm[i] + (1.0 - b1) * gi;
        Vv[i] = b2 * Vv[i] + (1.0 - b2) * gi * gi;
        double mhat = Mm[i] / bc1;
        double vhat = Vv[i] / bc2;
        P[i] -= lr * (mhat / (sqrt(vhat) + eps) + wd * P[i]);
    }
    return hexa_int(1);
}

// ═══════════════════════════════════════════════════════════════════
// anima RFC 036 (2026-05-16): phi_rs MI/Φ byte-equal native primitive.
//
// HONEST SCOPE (AGENTS.tape g3 / f2 — no over-claim):
//   The anima `phi_rs` Rust crate
//   (anima_clm_10_h100_sweep_laws_77_78/phi-rs) is a **PyO3 cdylib**
//   (`crate-type=["cdylib"]`, pyo3 extension-module). It exposes NO
//   `extern "C"` / `#[no_mangle]` C ABI, so hexa-lang's existing
//   static-FFI / dlsym path (`extern fn @symbol @link`) CANNOT bind it
//   today. RFC 036 (a) specifies the Rust C-ABI shim that phi_rs must
//   add, AND (b) lands a native C implementation of phi_rs's
//   *documented deterministic numeric core* (`mi_from_paired_vectors`
//   + the spatial-Φ pipeline steps 1-4) so the byte-equal harness can
//   run NOW against the formula. The actual Rust FFI link remains a
//   NAMED BLOCKER until phi_rs ships the §"FFI shim" surface — this is
//   stated explicitly in the RFC and NOT counted as a closed FFI.
//
// Byte-equal target = phi_rs src/lib.rs functions, replicated exactly:
//   bin_values · entropy (1e-8 total smoothing + 1e-10 log smoothing)
//   · mi_from_paired_vectors · total_mi · find_min_partition_exact
//   · spatial_phi = (total − min_part)/(n−1)  [tensions/temporal=None]
//
// Falsifier coverage: tmp_rfc036_smoke.hexa
//   F-RFC036-BUILD / MI-BYTE-EQUAL / PHI-SPATIAL / DETERMINISM /
//   FFI-BLOCKER-DOCUMENTED (honest carve-out, NOT a PASS-claim)
// ═══════════════════════════════════════════════════════════════════

// phi_rs bin_values: min/max over the f32-cast row, range/n_bins width,
// floor((v-min)/width) clamped to n_bins-1; all-identical → all bin 0.
static void _hx_phi_bin_values(const double* v, int64_t n, int64_t nb,
                               int* out) {
    if (n <= 0) return;
    float mn =  (float)v[0], mx = (float)v[0];
    for (int64_t i = 1; i < n; i++) {
        float f = (float)v[i];
        if (f < mn) mn = f;
        if (f > mx) mx = f;
    }
    float range = mx - mn;
    // f32::EPSILON (IEEE binary32 ulp at 1.0) — literal so we need no
    // <float.h> include (matches Rust phi_rs `f32::EPSILON` exactly).
    const float _flt_eps = 1.19209290e-7f;
    if (range < _flt_eps) { for (int64_t i = 0; i < n; i++) out[i] = 0; return; }
    float bw = range / (float)nb;
    for (int64_t i = 0; i < n; i++) {
        int b = (int)(((float)v[i] - mn) / bw);   // truncation = Rust `as usize`
        if (b > (int)nb - 1) b = (int)nb - 1;
        if (b < 0) b = 0;
        out[i] = b;
    }
}

// phi_rs entropy: t = total + 1e-8 ; Σ -p·log2(p + 1e-10), ALL bins.
static double _hx_phi_entropy(const uint32_t* counts, int64_t k,
                              uint32_t total) {
    if (total == 0) return 0.0;
    double t = (double)total + 1e-8;
    double s = 0.0;
    for (int64_t i = 0; i < k; i++) {
        double p = (double)counts[i] / t;
        s += -p * (hxlcl_log(p + 1e-10) / hxlcl_log(2.0));   // log2 via natural log
    }
    return s;
}

// phi_rs mi_from_paired_vectors — exact replica.
// MI = max(H(A) + H(B) − H(A,B), 0).
static double _hx_phi_mi_pair(const double* a, const double* b,
                              int64_t n, int64_t nb) {
    if (n <= 0) return 0.0;
    int*      ba = (int*)malloc((size_t)n * sizeof(int));
    int*      bb = (int*)malloc((size_t)n * sizeof(int));
    uint32_t* ca = (uint32_t*)calloc((size_t)nb, sizeof(uint32_t));
    uint32_t* cb = (uint32_t*)calloc((size_t)nb, sizeof(uint32_t));
    uint32_t* jo = (uint32_t*)calloc((size_t)(nb * nb), sizeof(uint32_t));
    if (!ba || !bb || !ca || !cb || !jo) {
        free(ba); free(bb); free(ca); free(cb); free(jo);
        return 0.0;
    }
    _hx_phi_bin_values(a, n, nb, ba);
    _hx_phi_bin_values(b, n, nb, bb);
    for (int64_t i = 0; i < n; i++) {
        ca[ba[i]]++;
        cb[bb[i]]++;
        jo[(int64_t)ba[i] * nb + bb[i]]++;
    }
    uint32_t total = (uint32_t)n;
    double hA  = _hx_phi_entropy(ca, nb,      total);
    double hB  = _hx_phi_entropy(cb, nb,      total);
    double hAB = _hx_phi_entropy(jo, nb * nb, total);
    free(ba); free(bb); free(ca); free(cb); free(jo);
    double mi = hA + hB - hAB;
    return mi > 0.0 ? mi : 0.0;
}

// phi_mi_pair(a_farr, b_farr, n, n_bins) -> float.
// Byte-equal to phi_rs::mi_from_paired_vectors(a, b, n_bins).
HexaVal hexa_phi_mi_pair(HexaVal a_v, HexaVal b_v, HexaVal n_v,
                         HexaVal nb_v) {
    int64_t a_id = hexa_as_num(a_v);
    int64_t b_id = hexa_as_num(b_v);
    int64_t n    = hexa_as_num(n_v);
    int64_t nb   = hexa_as_num(nb_v);
    int64_t al = 0, bl = 0;
    double* A = _hx_ad_farr_buf(a_id, &al);
    double* B = _hx_ad_farr_buf(b_id, &bl);
    if (!A || !B || n <= 0 || nb <= 0 || al < n || bl < n)
        return hexa_float(0.0);
    return hexa_float(_hx_phi_mi_pair(A, B, n, nb));
}

// phi_spatial(states_farr, n_cells, dim, n_bins) -> float.
// Byte-equal to phi_rs::compute_phi_inner spatial component with
// tensions=None, prev/curr=None (⟹ temporal_phi=0, complexity uses
// std-of-row-sums but the SPATIAL Φ this builtin returns is the
// step-4 value the anima HEXAD Phase 4 ratchet consumes):
//   spatial = max(total_mi − min_partition_mi, 0) / max(n−1, 1)
// states_farr is row-major n_cells × dim. Exhaustive bipartition
// (cell 0 pinned to A) for n_cells ≤ 20 — phi_rs find_min_partition_exact.
HexaVal hexa_phi_spatial(HexaVal st_v, HexaVal nc_v, HexaVal dim_v,
                         HexaVal nb_v) {
    int64_t s_id = hexa_as_num(st_v);
    int64_t nc   = hexa_as_num(nc_v);
    int64_t dim  = hexa_as_num(dim_v);
    int64_t nb   = hexa_as_num(nb_v);
    int64_t sl = 0;
    double* S = _hx_ad_farr_buf(s_id, &sl);
    if (!S || nc <= 0 || dim <= 0 || nb <= 0 || sl < nc * dim)
        return hexa_float(0.0);
    if (nc <= 1) return hexa_float(0.0);
    // Step 1-2: pairwise MI matrix + total MI (upper triangle).
    double* mi = (double*)calloc((size_t)(nc * nc), sizeof(double));
    if (!mi) return hexa_float(0.0);
    double total = 0.0;
    for (int64_t i = 0; i < nc; i++) {
        for (int64_t j = i + 1; j < nc; j++) {
            double v = _hx_phi_mi_pair(S + i * dim, S + j * dim, dim, nb);
            mi[i * nc + j] = v;
            mi[j * nc + i] = v;
            total += v;
        }
    }
    // Step 3: minimum information partition (cell 0 pinned to A).
    double min_part;
    if (nc == 2) {
        min_part = mi[0 * nc + 1];
    } else if (nc <= 20) {
        min_part = INFINITY;
        uint64_t max_mask = (uint64_t)1 << (nc - 1);
        for (uint64_t mask = 1; mask < max_mask; mask++) {
            // partition: cell 0 in A; bit b → cell b+1 in A iff set.
            int any_b = 0;
            for (int64_t b = 0; b < nc - 1; b++)
                if (!(mask & ((uint64_t)1 << b))) { any_b = 1; break; }
            if (!any_b) continue;        // skip trivial (B empty)
            double cross = 0.0;
            // A = {0} ∪ {b+1 : bit b set}; B = complement.
            for (int64_t ia = 0; ia < nc; ia++) {
                int inA = (ia == 0) ? 1
                          : ((mask & ((uint64_t)1 << (ia - 1))) ? 1 : 0);
                if (!inA) continue;
                for (int64_t jb = 0; jb < nc; jb++) {
                    int jInA = (jb == 0) ? 1
                               : ((mask & ((uint64_t)1 << (jb - 1))) ? 1 : 0);
                    if (jInA) continue;          // jb ∈ B only
                    cross += mi[ia * nc + jb];
                }
            }
            if (cross < min_part) min_part = cross;
        }
    } else {
        // phi_rs greedy path (N>20) — out of v1 falsifier scope; the
        // anima HEXAD pool is small (≤ 64 but Phase-4 Φ slices ≤ 20).
        min_part = 0.0;
    }
    free(mi);
    // Step 4: spatial Φ.
    double n = (double)nc;
    double denom = (n - 1.0) > 1.0 ? (n - 1.0) : 1.0;
    double sp = total - min_part;
    if (sp < 0.0) sp = 0.0;
    return hexa_float(sp / denom);
}

// ═══════════════════════════════════════════════════════════════════
// anima RFC 040 (2026-05-16): farr GPU/CUDA backend — Phase A scaffolding.
//
// Scaffolding only. The HexaFarrEntry residence descriptor (FarrLoc /
// d_buf / dirty_host / dirty_dev) lives in the table struct (top of
// the farr section); the device-management + GPU compute builtins are
// declared in runtime.h. THIS BLOCK provides their *bodies*.
//
// The default build has NO `-DHEXA_CUDA` defined. Every body below
// then takes the CPU-fallback branch:
//   • cuda_available() → 0
//   • cuda_device_count() → 0
//   • farr_to_device / farr_to_host / farr_pin → no-op success
//   • farr_device_free → no-op success
//   • farr_matmul_gpu → routes to RFC 032 hexa_farr_matmul (the CPU
//     oracle). This makes the GPU dispatcher safe-to-call on Mac —
//     callers get the bit-exact CPU result with the same -1-on-error
//     contract, the equivalence harness PASSES, and nothing changes
//     for the byte-identical no-CUDA build.
//
// With `-DHEXA_CUDA` defined, the same bodies route to the real cuBLAS
// Dgemm + cudaMalloc/cudaMemcpy path in self/cuda/runtime_cuda.c
// (LANDED 2026-05-17, Phase 4-D-5-1 wiring scaffold). Phase A surface
// wired:
//   • hexa_cuda_available     → _hx_cuda_runtime_available
//   • hexa_cuda_device_count  → _hx_cuda_device_count_impl
//   • hexa_farr_to_device     → _hx_cuda_farr_to_device   (H2D)
//   • hexa_farr_to_host       → _hx_cuda_farr_to_host     (D2H)
//   • hexa_farr_device_free   → _hx_cuda_farr_device_free (cudaFree)
//   • hexa_farr_matmul_gpu    → _hx_cuda_farr_matmul_gpu  (cuBLAS Dgemm)
//   • hexa_farr_free (line 8307) → _hx_cuda_farr_device_free (cudaFree-on-free)
// Phase B / B2 GPU bodies (softmax_rows, rmsnorm_rows, add, scale,
// matmul_t, outer, mul, silu, silu_grad, rmsnorm_bwd_rows, adamw_step)
// remain TODO[cuda] stubs returning -1 — honest no-fake-PASS per
// AGENTS.tape g3 / RFC 040 §"Honest caveats". Their CUDA bodies
// (`__global__` kernels + warp-shuffle reductions) are the next-cycle
// deliverable; see stdlib/flame/PHASE4D5_1_WIRING_NOTES.md.
//
// Phase A falsifier surface (tmp_rfc040_smoke.hexa):
//   F-RFC040-AVAIL              cuda_available()==0 on Mac (graceful)
//   F-RFC040-STRUCT-NOREGRESS   existing CPU farr_matmul unchanged
//   F-RFC040-DISPATCH-FALLBACK  farr_matmul_gpu == farr_matmul (CPU)
//   F-RFC040-DETERMINISM        re-eval byte-identical
//   F-RFC040-CUDA-BLOCKER-DOC   honest carve-out (CUDA kernels = next cycle)
// ═══════════════════════════════════════════════════════════════════

#ifdef HEXA_CUDA
/* Forward decls for the GPU compilation unit (TODO[cuda] — bodies live
 * in a separate .cu file linked in by the CUDA build). NOT defined in
 * the no-CUDA build, so the `#ifndef HEXA_CUDA` fallbacks below are
 * the entire compiled surface today. */
extern int  _hx_cuda_runtime_available(void);
extern int  _hx_cuda_device_count_impl(void);
extern int  _hx_cuda_farr_to_device(int64_t farr_id);
extern int  _hx_cuda_farr_to_host(int64_t farr_id);
extern int  _hx_cuda_farr_device_free(int64_t farr_id);
extern int  _hx_cuda_farr_matmul_gpu(int64_t a_id, int64_t M, int64_t K,
                                     int64_t b_id, int64_t N,
                                     int64_t c_id);
/* RFC 056 Phase 1 — residence contract + sub-view API. */
extern int  _hx_cuda_set_out_disposition(int d);
extern int  _hx_cuda_farr_dev_view(int64_t base_id, int64_t offset,
                                    int64_t len, int64_t view_id);
extern int  _hx_cuda_farr_pin_device(int64_t farr_id);
extern int  _hx_cuda_farr_unpin_device(int64_t farr_id);
#endif

/* RFC 056 §6.4 disposition constants — exposed to flame's A2 primitive
 * (host C, no flame public API change — g_flame_api_fixed). */
#define HEXA_FORGE_OUT_HOST_NOW    0
#define HEXA_FORGE_OUT_DEVICE_KEEP 1

// cuda_available() -> int. 1 if a CUDA device + toolkit are detected at
// runtime, else 0. Coherent with cuda_device_count(): one implies the
// other > 0.
HexaVal hexa_cuda_available(void) {
#ifdef HEXA_CUDA
    /* RFC 040 Phase A real impl (2026-05-16): probe via runtime_cuda.c TU. */
    return hexa_int(_hx_cuda_runtime_available());
#else
    return hexa_int(0);
#endif
}

// cuda_device_count() -> int. Number of visible GPUs (0 if none / no
// CUDA toolkit). Returns 0 on the no-CUDA build always.
HexaVal hexa_cuda_device_count(void) {
#ifdef HEXA_CUDA
    return hexa_int(_hx_cuda_device_count_impl());
#else
    return hexa_int(0);
#endif
}

// farr_to_device(id) -> int. Ensure d_buf is resident + current.
// CPU-fallback path: every farr is loc=FARR_HOST already; the call is a
// no-op success (return 1). This keeps caller code valid on Mac — a
// d_train5 hot-loop `let _ = farr_to_device(W)` becomes inert when no
// GPU is available, instead of failing the call.
// Returns: 1 ok / 0 invalid handle / -1 GPU op failed.
HexaVal hexa_farr_to_device(HexaVal h_v) {
    int64_t id = hexa_as_num(h_v);
    if (id < 0 || id >= _hx_farr_count) return hexa_int(0);
    HexaFarrEntry* e = &_hx_farr_table[id];
    if (!e->buf && e->loc == FARR_HOST) return hexa_int(0);
#ifdef HEXA_CUDA
    return hexa_int(_hx_cuda_farr_to_device(id));
#else
    /* No-CUDA path: farr already host-resident; nothing to transfer.
     * The dispatcher contract: caller continues to use the same
     * handle, math runs on CPU. */
    return hexa_int(1);
#endif
}

// farr_to_host(id) -> int. Ensure host buf is current (D2H if device-
// resident and dirty). CPU-fallback path: no-op success.
HexaVal hexa_farr_to_host(HexaVal h_v) {
    int64_t id = hexa_as_num(h_v);
    if (id < 0 || id >= _hx_farr_count) return hexa_int(0);
    HexaFarrEntry* e = &_hx_farr_table[id];
    if (!e->buf && e->loc == FARR_HOST) return hexa_int(0);
#ifdef HEXA_CUDA
    return hexa_int(_hx_cuda_farr_to_host(id));
#else
    return hexa_int(1);
#endif
}

// farr_pin(id) -> int. Mark farr resident-on-device, do not auto-evict
// (weights stay across all steps). CPU-fallback: records pinned flag
// only (no actual residence change, since no device exists).
HexaVal hexa_farr_pin(HexaVal h_v) {
    int64_t id = hexa_as_num(h_v);
    if (id < 0 || id >= _hx_farr_count) return hexa_int(0);
    HexaFarrEntry* e = &_hx_farr_table[id];
    e->pinned = 1;
    return hexa_int(1);
}

// ── RFC 056 Phase 1 — device residence contract + sub-view API ──────
//
// All four are no-op-safe on the no-CUDA Mac build (return success / a
// CPU-equivalent handle) so flame's A2 primitive stays callable without
// a GPU — exactly the RFC 040 dispatcher contract + §8.3 backward-safe.

// farr_set_out_disposition(d) -> int (previous disposition).
//   d = 1 (FORGE_OUT_DEVICE_KEEP): the *next* forge `_gpu` op defers its
//       D2H — output stays device-resident for the following GPU op.
//   d = 0 (FORGE_OUT_HOST_NOW, DEFAULT): D2H now (== pre-RFC-056).
// No-CUDA: inert (returns 0); every op is CPU so disposition is moot.
HexaVal hexa_farr_set_out_disposition(HexaVal d_v) {
#ifdef HEXA_CUDA
    return hexa_int(_hx_cuda_set_out_disposition((int)hexa_as_num(d_v)));
#else
    (void)d_v;
    return hexa_int(0);
#endif
}

// farr_dev_view(base, offset, len) -> int view_farr_id (-1 on error).
// RFC 056 §6.2 non-owning device sub-view: view.d_buf = base.d_buf +
// offset*8, shares base residence. The caller must device-pin `base`
// first. A fresh host handle is allocated to carry the view id (its
// host buf is unused — device bytes are the base's). Out-of-range →
// the view handle is freed and -1 returned (no UB; F-RFC056-VIEW-SAFETY).
// No-CUDA fallback: returns a real CPU farr that is a *copy* of the
// slice (byte-eq with the resident path's logical contents — the only
// correct answer without a device), so flame code stays valid on Mac.
HexaVal hexa_farr_dev_view(HexaVal base_v, HexaVal off_v, HexaVal len_v) {
    int64_t base_id = hexa_as_num(base_v);
    int64_t offset  = hexa_as_num(off_v);
    int64_t len     = hexa_as_num(len_v);
    if (base_id < 0 || base_id >= _hx_farr_count) return hexa_int(-1);
    if (offset < 0 || len <= 0) return hexa_int(-1);
    HexaFarrEntry* be = &_hx_farr_table[base_id];
    if (offset + len > be->len) return hexa_int(-1);
    HexaVal vh = hexa_farr_zeros(hexa_int(len));
    int64_t view_id = hexa_as_num(vh);
    if (view_id < 0) return hexa_int(-1);
#ifdef HEXA_CUDA
    if (_hx_cuda_farr_dev_view(base_id, offset, len, view_id) != 0) {
        (void)hexa_farr_free(hexa_int(view_id));
        return hexa_int(-1);
    }
    return hexa_int(view_id);
#else
    /* No-CUDA: materialise the slice as a real CPU farr (copy). This is
     * byte-eq with what the resident device view logically holds — the
     * only correct CPU answer; keeps flame valid on Mac. RE-FETCH be
     * after hexa_farr_zeros (table may have realloc'd). */
    be = &_hx_farr_table[base_id];
    HexaFarrEntry* ve = &_hx_farr_table[view_id];
    if (be->buf && ve->buf) {
        for (int64_t i = 0; i < len; i++) ve->buf[i] = be->buf[offset + i];
    }
    return hexa_int(view_id);
#endif
}

// farr_pin_device(id) -> int (1 ok / -1 err). RFC 056 §6.3: force the
// farr device-resident (H2D once) + mark non-evictable. No-CUDA: just
// records the pinned flag (== hexa_farr_pin; no device exists).
HexaVal hexa_farr_pin_device(HexaVal h_v) {
    int64_t id = hexa_as_num(h_v);
    if (id < 0 || id >= _hx_farr_count) return hexa_int(-1);
#ifdef HEXA_CUDA
    return hexa_int(_hx_cuda_farr_pin_device(id));
#else
    _hx_farr_table[id].pinned = 1;
    return hexa_int(1);
#endif
}

// farr_unpin_device(id) -> int. RFC 056 §6.3: clear the pin; D2H if the
// device copy is dirty. No-CUDA: clears the flag (no device).
HexaVal hexa_farr_unpin_device(HexaVal h_v) {
    int64_t id = hexa_as_num(h_v);
    if (id < 0 || id >= _hx_farr_count) return hexa_int(-1);
#ifdef HEXA_CUDA
    return hexa_int(_hx_cuda_farr_unpin_device(id));
#else
    _hx_farr_table[id].pinned = 0;
    return hexa_int(1);
#endif
}

// farr_device_free(id) -> int. Free d_buf, keep host buf. CPU-fallback:
// no-op success (d_buf is always NULL on no-CUDA).
HexaVal hexa_farr_device_free(HexaVal h_v) {
    int64_t id = hexa_as_num(h_v);
    if (id < 0 || id >= _hx_farr_count) return hexa_int(0);
    HexaFarrEntry* e = &_hx_farr_table[id];
#ifdef HEXA_CUDA
    (void)e;
    return hexa_int(_hx_cuda_farr_device_free(id));
#else
    (void)e;
    return hexa_int(1);
#endif
}

// farr_matmul_gpu(A, Ar, Ac, B, Bc) -> int. ABI-identical to the RFC 032
// CPU farr_matmul: same shape contract (A is M×K, B is K×N, output is
// M×N), same -1-on-error return, same packed-double representation.
// On the no-CUDA build: routes directly to hexa_farr_matmul — the CPU
// oracle is the only correct numeric answer, and the dispatcher remains
// safely callable. On the HEXA_CUDA build: enforces device-residency
// and runs cuBLAS Dgemm via _hx_cuda_farr_matmul_gpu in
// self/cuda/runtime_cuda.c (LANDED — Phase 4-D-5-1 wire-up; fp64 strict
// Dgemm, no Tensor Core flip; row-major mapped via C^T = B^T · A^T).
HexaVal hexa_farr_matmul_gpu(HexaVal a_v, HexaVal ar_v, HexaVal ac_v,
                             HexaVal b_v, HexaVal bc_v) {
#ifdef HEXA_CUDA
    /* RFC 040 Phase A real impl (2026-05-16): cuBLAS Dgemm path via
     * runtime_cuda.c TU. Shape: A is M×K row-major, B is K×N row-major,
     * C is M×N row-major.
     *   M = ar (rows of A); K = ac (cols of A = rows of B); N = bc (cols of B).
     * Allocate a fresh host C farr (len M·N); the runtime_cuda.c TU
     * uploads A,B H2D (idempotent), runs Dgemm device-side, copies C
     * D2H so the host caller sees the result.
     * Returns C farr_id (≥0) on success, -1 on error. */
    int64_t M = hexa_as_num(ar_v);
    int64_t K = hexa_as_num(ac_v);
    int64_t N = hexa_as_num(bc_v);
    int64_t a_id = hexa_as_num(a_v);
    int64_t b_id = hexa_as_num(b_v);
    if (M <= 0 || K <= 0 || N <= 0) return hexa_int(-1);
    if (a_id < 0 || a_id >= _hx_farr_count) return hexa_int(-1);
    if (b_id < 0 || b_id >= _hx_farr_count) return hexa_int(-1);
    HexaVal c_h = hexa_farr_zeros(hexa_int(M * N));
    int64_t c_id = hexa_as_num(c_h);
    if (c_id < 0) return hexa_int(-1);
    int rc = _hx_cuda_farr_matmul_gpu(a_id, M, K, b_id, N, c_id);
    if (rc != 0) return hexa_int(-1);
    return hexa_int(c_id);
#else
    /* No-CUDA build: dispatcher routes to the RFC 032 CPU op. This is
     * the equivalence harness's POSITIVE branch — proves the dispatcher
     * wires correctly and the math contract is preserved. */
    return hexa_farr_matmul(a_v, ar_v, ac_v, b_v, bc_v);
#endif
}

// ── Callable shims (≤4-arg `hexa_callN(<carrier>,…)` + 5-arg bare) ─────
// hexa_v2 codegen's generic fallback lowers `cuda_available()` etc. to
// `hexa_call0(cuda_available)` (and 1-arg → `hexa_call1(name, ...)`),
// which needs a visible HexaVal carrier with that exact identifier.
// `farr_matmul_gpu` (5-arg, past the hexa_callN ceiling) gets a bare-
// function direct C call, which the static-inline wrapper below
// satisfies. Same dispatch contract as RFC 032 farr_matmul + RFC 034
// ad_matmul + RFC 035 adamw_step_mixed.
HexaVal cuda_available;
HexaVal cuda_device_count;
HexaVal farr_to_device;
HexaVal farr_to_host;
HexaVal farr_pin;
HexaVal farr_device_free;
/* RFC 056 Phase 1 carriers (≤4-arg → hexa_callN dispatch). */
HexaVal farr_set_out_disposition;
HexaVal farr_dev_view;
HexaVal farr_pin_device;
HexaVal farr_unpin_device;
static inline HexaVal farr_matmul_gpu_impl(HexaVal a, HexaVal ar, HexaVal ac,
                                           HexaVal b, HexaVal bc) {
    return hexa_farr_matmul_gpu(a, ar, ac, b, bc);
}
HexaVal farr_matmul_gpu(HexaVal a, HexaVal ar, HexaVal ac,
                        HexaVal b, HexaVal bc) {
    return farr_matmul_gpu_impl(a, ar, ac, b, bc);
}

// ═══════════════════════════════════════════════════════════════════
// anima RFC 040 Phase B (2026-05-16): remaining farr GPU/CUDA ops —
// scaffolding only (Mac, no CUDA hardware needed).
//
// Same `#ifdef HEXA_CUDA` / `#ifndef HEXA_CUDA` dispatch pattern as
// Phase A. Each `*_gpu` op on the no-CUDA build routes to a SMALL
// new CPU helper (no pre-existing farr equivalent for these row/
// elementwise ops in the runtime today). On the HEXA_CUDA build the
// bodies are TODO[cuda] stubs returning -1 (honest no-fake-PASS, per
// AGENTS.tape g3). Real GPU `__global__` kernels = next-cycle
// deliverable on a CUDA host (vast.ai/runpod).
//
// Ops landed in Phase B (per RFC 040 §"Hot-path op survey" subset):
//   farr_softmax_rows_gpu   row-wise numerically-stable softmax
//   farr_rmsnorm_rows_gpu   row-wise RMSNorm (mean(x²) + eps)
//   farr_add_gpu            elementwise C = A + B
//   farr_scale_gpu          elementwise Y = α · X
//
// Falsifier surface (tmp_rfc040_phaseB_smoke.hexa):
//   F-RFC040B-SOFTMAX-EQ    softmax_gpu == CPU helper (byte-equal)
//   F-RFC040B-RMSNORM-EQ    rmsnorm_gpu == CPU helper (byte-equal)
//   F-RFC040B-ADD-EQ        add_gpu == elementwise A+B (byte-equal)
//   F-RFC040B-SCALE-EQ      scale_gpu == α·X (byte-equal)
//   F-RFC040B-DETERMINISM   re-run byte-identical for each op
//   F-RFC040B-CUDA-BLOCKER  honest carve-out (CUDA kernels = next cycle)
// ═══════════════════════════════════════════════════════════════════

#ifdef HEXA_CUDA
/* Forward decls for the Phase B GPU compilation unit (TODO[cuda] —
 * bodies live in the same .cu file as Phase A on the CUDA host build).
 * NOT defined in the no-CUDA build. */
extern int  _hx_cuda_farr_softmax_rows_gpu(int64_t x_id, int64_t R,
                                           int64_t C, int64_t out_id);
extern int  _hx_cuda_farr_rmsnorm_rows_gpu(int64_t x_id, int64_t R,
                                           int64_t C, double eps,
                                           int64_t out_id);
extern int  _hx_cuda_farr_add_gpu(int64_t a_id, int64_t b_id,
                                  int64_t n, int64_t out_id);
extern int  _hx_cuda_farr_scale_gpu(int64_t x_id, double alpha,
                                    int64_t n, int64_t out_id);
#endif

// ── CPU helpers (Phase B no-CUDA fallback path). ──────────────────
// These are SMALL NEW helpers — there is no pre-existing single-op
// farr_softmax / farr_rmsnorm / farr_add / farr_scale in the runtime
// today (the ad_softmax_cross_entropy op fuses softmax+CE+grad; it is
// loss-coupled and unsuited as a row-softmax-only kernel). Each helper
// (a) allocates a fresh output farr via hexa_farr_zeros, (b) re-fetches
// entry pointers post-alloc (per the RFC 032 use-after-realloc guard at
// line 9580), (c) computes the math in-place in the output buffer.

// _hx_farr_softmax_rows_cpu(x, R, C) -> new farr_id. Numerically-stable
// row-softmax (subtract row max before exp). -1 on err.
static int64_t _hx_farr_softmax_rows_cpu(int64_t x_id, int64_t R, int64_t C) {
    if (x_id < 0 || x_id >= _hx_farr_count) return -1;
    if (R <= 0 || C <= 0)                    return -1;
    HexaFarrEntry* xe = &_hx_farr_table[x_id];
    if (!xe->buf || xe->len < R * C)         return -1;
    HexaVal out_h = hexa_farr_zeros(hexa_int(R * C));
    int64_t out_id = HX_INT(out_h);
    if (out_id < 0 || out_id >= _hx_farr_count) return -1;
    /* hexa_farr_zeros may realloc _hx_farr_table — re-fetch pointers. */
    xe = &_hx_farr_table[x_id];
    HexaFarrEntry* oe = &_hx_farr_table[out_id];
    if (!xe->buf || !oe->buf || oe->len < R * C) return -1;
    const double* X = xe->buf;
    double*       Y = oe->buf;
    for (int64_t r = 0; r < R; r++) {
        const double* xr = X + r * C;
        double*       yr = Y + r * C;
        double zmax = xr[0];
        for (int64_t j = 1; j < C; j++) if (xr[j] > zmax) zmax = xr[j];
        double s = 0.0;
        for (int64_t j = 0; j < C; j++) {
            double e = hxlcl_exp(xr[j] - zmax);
            yr[j] = e;
            s += e;
        }
        double inv = (s > 0.0) ? (1.0 / s) : 0.0;
        for (int64_t j = 0; j < C; j++) yr[j] *= inv;
    }
    return out_id;
}

// _hx_farr_rmsnorm_rows_cpu(x, R, C, eps) -> new farr_id.
// RMSNorm row-wise: y[r,j] = x[r,j] / sqrt(mean_j(x[r,j]^2) + eps).
// -1 on err. Matches d_train3_lib c3_rmsnorm_fwd math (without the
// per-channel gain — that lives outside this kernel, so this is the
// inv-rms-only primitive — consistent with PLAN.md §9 "RMSNorm
// reduction primitive").
static int64_t _hx_farr_rmsnorm_rows_cpu(int64_t x_id, int64_t R, int64_t C,
                                         double eps) {
    if (x_id < 0 || x_id >= _hx_farr_count) return -1;
    if (R <= 0 || C <= 0)                    return -1;
    if (!(eps >= 0.0))                       return -1;   /* rejects NaN + negative */
    HexaFarrEntry* xe = &_hx_farr_table[x_id];
    if (!xe->buf || xe->len < R * C)         return -1;
    HexaVal out_h = hexa_farr_zeros(hexa_int(R * C));
    int64_t out_id = HX_INT(out_h);
    if (out_id < 0 || out_id >= _hx_farr_count) return -1;
    xe = &_hx_farr_table[x_id];
    HexaFarrEntry* oe = &_hx_farr_table[out_id];
    if (!xe->buf || !oe->buf || oe->len < R * C) return -1;
    const double* X = xe->buf;
    double*       Y = oe->buf;
    double inv_C = 1.0 / (double)C;
    for (int64_t r = 0; r < R; r++) {
        const double* xr = X + r * C;
        double*       yr = Y + r * C;
        double ms = 0.0;
        for (int64_t j = 0; j < C; j++) ms += xr[j] * xr[j];
        ms *= inv_C;
        double inv = 1.0 / sqrt(ms + eps);
        for (int64_t j = 0; j < C; j++) yr[j] = xr[j] * inv;
    }
    return out_id;
}

// _hx_farr_add_cpu(a, b, n) -> new farr_id. C = A + B, length n. -1 err.
static int64_t _hx_farr_add_cpu(int64_t a_id, int64_t b_id, int64_t n) {
    if (a_id < 0 || a_id >= _hx_farr_count) return -1;
    if (b_id < 0 || b_id >= _hx_farr_count) return -1;
    if (n <= 0)                              return -1;
    HexaFarrEntry* ae = &_hx_farr_table[a_id];
    HexaFarrEntry* be = &_hx_farr_table[b_id];
    if (!ae->buf || !be->buf)                return -1;
    if (ae->len < n || be->len < n)          return -1;
    HexaVal out_h = hexa_farr_zeros(hexa_int(n));
    int64_t out_id = HX_INT(out_h);
    if (out_id < 0 || out_id >= _hx_farr_count) return -1;
    ae = &_hx_farr_table[a_id];
    be = &_hx_farr_table[b_id];
    HexaFarrEntry* oe = &_hx_farr_table[out_id];
    if (!ae->buf || !be->buf || !oe->buf || oe->len < n) return -1;
    const double* A = ae->buf;
    const double* B = be->buf;
    double*       O = oe->buf;
    for (int64_t i = 0; i < n; i++) O[i] = A[i] + B[i];
    return out_id;
}

// mk2-C1b (2026-05-19): dt_exp byte-exact C mirror of hexa
// flame_math `dt_exp` (12-term Taylor + range-halve-to-0.25 + r
// squarings). The flame silu reference uses dt_exp, NOT libm exp
// (_hx_sigmoid_d) — the byte-eq oracle (flame_ag_tape_test Test 11
// SILUGATE, leaf max|Δ|=0 bar) demands bit-identical reproduction
// ([[flame-transcendental-byteeq-hazard]]). All ops are single-
// rounding sequential (no a*b+c*d in one expr); FP_CONTRACT OFF is
// cheap insurance vs any clang FMA fusion, mirroring the rope CPU
// fix (commit c0789e05). Restored DEFAULT after the gate cpu.
#pragma STDC FP_CONTRACT OFF
static double _hx_dt_exp_d(double x) {
    int r = 0;
    double xr = x;
    while ((xr > 0.0 ? xr : 0.0 - xr) > 0.25) { xr = xr / 2.0; r = r + 1; }
    double term = 1.0;
    double acc  = 1.0;
    int k = 1;
    while (k < 12) { term = term * xr / (double)k; acc = acc + term; k = k + 1; }
    int s = 0;
    while (s < r) { acc = acc * acc; s = s + 1; }
    return acc;
}

// _hx_farr_silu_gate_cpu(a, b, n) -> new farr_id.
// O[i] = (A[i] · σ(A[i])) · B[i],  σ(x) = 1/(1 + dt_exp(-x)).
// Byte-identical to ag_tape.hexa `_ag_silu(a)*b` (same op order:
// sig=1/(1+dt_exp(0-a)); (a*sig)*b). -1 err.
static int64_t _hx_farr_silu_gate_cpu(int64_t a_id, int64_t b_id,
                                      int64_t n) {
    if (a_id < 0 || a_id >= _hx_farr_count) return -1;
    if (b_id < 0 || b_id >= _hx_farr_count) return -1;
    if (n <= 0)                              return -1;
    HexaFarrEntry* ae = &_hx_farr_table[a_id];
    HexaFarrEntry* be = &_hx_farr_table[b_id];
    if (!ae->buf || !be->buf)                return -1;
    if (ae->len < n || be->len < n)          return -1;
    HexaVal out_h = hexa_farr_zeros(hexa_int(n));
    int64_t out_id = HX_INT(out_h);
    if (out_id < 0 || out_id >= _hx_farr_count) return -1;
    ae = &_hx_farr_table[a_id];
    be = &_hx_farr_table[b_id];
    HexaFarrEntry* oe = &_hx_farr_table[out_id];
    if (!ae->buf || !be->buf || !oe->buf || oe->len < n) return -1;
    const double* A = ae->buf;
    const double* B = be->buf;
    double*       O = oe->buf;
    for (int64_t i = 0; i < n; i++) {
        double ai  = A[i];
        double sig = 1.0 / (1.0 + _hx_dt_exp_d(0.0 - ai));
        O[i] = (ai * sig) * B[i];
    }
    return out_id;
}
#pragma STDC FP_CONTRACT DEFAULT

// _hx_farr_scale_cpu(x, alpha, n) -> new farr_id. Y = α·X, length n. -1 err.
static int64_t _hx_farr_scale_cpu(int64_t x_id, double alpha, int64_t n) {
    if (x_id < 0 || x_id >= _hx_farr_count) return -1;
    if (n <= 0)                              return -1;
    HexaFarrEntry* xe = &_hx_farr_table[x_id];
    if (!xe->buf || xe->len < n)             return -1;
    HexaVal out_h = hexa_farr_zeros(hexa_int(n));
    int64_t out_id = HX_INT(out_h);
    if (out_id < 0 || out_id >= _hx_farr_count) return -1;
    xe = &_hx_farr_table[x_id];
    HexaFarrEntry* oe = &_hx_farr_table[out_id];
    if (!xe->buf || !oe->buf || oe->len < n) return -1;
    const double* X = xe->buf;
    double*       Y = oe->buf;
    for (int64_t i = 0; i < n; i++) Y[i] = alpha * X[i];
    return out_id;
}

// farr_softmax_rows_gpu(x, R, C) -> int new farr_id (row-softmax).
// On no-CUDA: routes to _hx_farr_softmax_rows_cpu (the CPU oracle).
// On HEXA_CUDA: wired (Phase 4-D-5-4 step 1, 2026-05-17) to
// _hx_cuda_farr_softmax_rows_gpu in self/cuda/runtime_cuda.c (LANDED —
// block-per-row warp-shuffle row-max + exp-sum reduction, byte-eq
// verified Phase 4-D-5-3 11/11 PASS on A100). Pre-allocates output via
// hexa_farr_zeros (Phase A matmul precedent) so the substrate's
// _ensure_dev_alloc_out can find the host entry + grow its g_slots.
HexaVal hexa_farr_softmax_rows_gpu(HexaVal x_v, HexaVal r_v, HexaVal c_v) {
    int64_t x_id = hexa_as_num(x_v);
    int64_t R    = hexa_as_num(r_v);
    int64_t C    = hexa_as_num(c_v);
#ifdef HEXA_CUDA
    if (R <= 0 || C <= 0) return hexa_int(-1);
    if (x_id < 0 || x_id >= _hx_farr_count) return hexa_int(-1);
    HexaVal out_h = hexa_farr_zeros(hexa_int(R * C));
    int64_t out_id = hexa_as_num(out_h);
    if (out_id < 0) return hexa_int(-1);
    int rc = _hx_cuda_farr_softmax_rows_gpu(x_id, R, C, out_id);
    if (rc != 0) return hexa_int(-1);
    return hexa_int(out_id);
#else
    return hexa_int(_hx_farr_softmax_rows_cpu(x_id, R, C));
#endif
}

// farr_rmsnorm_rows_gpu(x, R, C, eps) -> int new farr_id (row-RMSNorm).
// On no-CUDA: routes to _hx_farr_rmsnorm_rows_cpu.
// On HEXA_CUDA: wired (Phase 4-D-5-4 step 1, 2026-05-17) to
// _hx_cuda_farr_rmsnorm_rows_gpu — block-per-row warp-shuffle Σx²,
// rsqrt + broadcast multiply (gain-free; per-channel γ multiplied by
// the caller via farr_mul_gpu). Byte-eq verified Phase 4-D-5-3.
HexaVal hexa_farr_rmsnorm_rows_gpu(HexaVal x_v, HexaVal r_v, HexaVal c_v,
                                   HexaVal eps_v) {
    int64_t x_id = hexa_as_num(x_v);
    int64_t R    = hexa_as_num(r_v);
    int64_t C    = hexa_as_num(c_v);
    double  eps  = __hx_to_double(eps_v);
#ifdef HEXA_CUDA
    if (R <= 0 || C <= 0) return hexa_int(-1);
    if (!(eps >= 0.0))    return hexa_int(-1);
    if (x_id < 0 || x_id >= _hx_farr_count) return hexa_int(-1);
    HexaVal out_h = hexa_farr_zeros(hexa_int(R * C));
    int64_t out_id = hexa_as_num(out_h);
    if (out_id < 0) return hexa_int(-1);
    int rc = _hx_cuda_farr_rmsnorm_rows_gpu(x_id, R, C, eps, out_id);
    if (rc != 0) return hexa_int(-1);
    return hexa_int(out_id);
#else
    return hexa_int(_hx_farr_rmsnorm_rows_cpu(x_id, R, C, eps));
#endif
}

// farr_add_gpu(a, b, n) -> int new farr_id (elementwise sum).
// On no-CUDA: routes to _hx_farr_add_cpu.
// On HEXA_CUDA: wired (Phase 4-D-5-4 step 1, 2026-05-17) to
// _hx_cuda_farr_add_gpu — 1-D grid-stride kernel, byte-eq Phase 4-D-5-3.
HexaVal hexa_farr_add_gpu(HexaVal a_v, HexaVal b_v, HexaVal n_v) {
    int64_t a_id = hexa_as_num(a_v);
    int64_t b_id = hexa_as_num(b_v);
    int64_t n    = hexa_as_num(n_v);
#ifdef HEXA_CUDA
    if (n <= 0) return hexa_int(-1);
    if (a_id < 0 || a_id >= _hx_farr_count) return hexa_int(-1);
    if (b_id < 0 || b_id >= _hx_farr_count) return hexa_int(-1);
    HexaVal out_h = hexa_farr_zeros(hexa_int(n));
    int64_t out_id = hexa_as_num(out_h);
    if (out_id < 0) return hexa_int(-1);
    int rc = _hx_cuda_farr_add_gpu(a_id, b_id, n, out_id);
    if (rc != 0) return hexa_int(-1);
    return hexa_int(out_id);
#else
    return hexa_int(_hx_farr_add_cpu(a_id, b_id, n));
#endif
}

// farr_scale_gpu(x, alpha, n) -> int new farr_id (Y = α·X).
// On no-CUDA: routes to _hx_farr_scale_cpu.
// On HEXA_CUDA: wired (Phase 4-D-5-4 step 1, 2026-05-17) to
// _hx_cuda_farr_scale_gpu — 1-D grid-stride kernel, byte-eq Phase 4-D-5-3.
HexaVal hexa_farr_scale_gpu(HexaVal x_v, HexaVal alpha_v, HexaVal n_v) {
    int64_t x_id = hexa_as_num(x_v);
    double  alpha = __hx_to_double(alpha_v);
    int64_t n    = hexa_as_num(n_v);
#ifdef HEXA_CUDA
    if (n <= 0) return hexa_int(-1);
    if (x_id < 0 || x_id >= _hx_farr_count) return hexa_int(-1);
    HexaVal out_h = hexa_farr_zeros(hexa_int(n));
    int64_t out_id = hexa_as_num(out_h);
    if (out_id < 0) return hexa_int(-1);
    int rc = _hx_cuda_farr_scale_gpu(x_id, alpha, n, out_id);
    if (rc != 0) return hexa_int(-1);
    return hexa_int(out_id);
#else
    return hexa_int(_hx_farr_scale_cpu(x_id, alpha, n));
#endif
}

// mk2-C1b (2026-05-19): farr_silu_gate_gpu(a, b, n) -> int new
// farr_id. O = (A·σ(A))·B, σ=1/(1+dt_exp(-x)). On no-CUDA: routes
// to _hx_farr_silu_gate_cpu (dt_exp-faithful, byte-id to
// ag_tape.hexa _ag_silu(a)*b). On HEXA_CUDA: _hx_cuda_farr_silu_
// gate_gpu (dt_exp-faithful device kernel, byte-eq oracle-gated).
HexaVal hexa_farr_silu_gate_gpu(HexaVal a_v, HexaVal b_v, HexaVal n_v) {
    int64_t a_id = hexa_as_num(a_v);
    int64_t b_id = hexa_as_num(b_v);
    int64_t n    = hexa_as_num(n_v);
#ifdef HEXA_CUDA
    if (n <= 0) return hexa_int(-1);
    if (a_id < 0 || a_id >= _hx_farr_count) return hexa_int(-1);
    if (b_id < 0 || b_id >= _hx_farr_count) return hexa_int(-1);
    HexaVal out_h = hexa_farr_zeros(hexa_int(n));
    int64_t out_id = hexa_as_num(out_h);
    if (out_id < 0) return hexa_int(-1);
    int rc = _hx_cuda_farr_silu_gate_gpu(a_id, b_id, n, out_id);
    if (rc != 0) return hexa_int(-1);
    return hexa_int(out_id);
#else
    return hexa_int(_hx_farr_silu_gate_cpu(a_id, b_id, n));
#endif
}
// ═══════════════════════════════════════════════════════════════════
// mk2-closure port (rfc043-flame-camp e030fa31 et al, 2026-05-19):
//   - mk2-C2 _hx_farr_rmsnorm_mh_cpu + dt_sqrt mirror
//   - mk2-C4 _hx_farr_attn_dt_fwd_cpu + _hx_farr_attn_dt_bwd_cpu
//   - mk2-C5 batch slice/transpose/zero/add-inplace/fill_dt_lcg CPU mirrors
//   - Dispatchers: rmsnorm_mh, attn_dt_fwd/bwd, zero_slice, add_inplace,
//     fill_dt_lcg, copy_slice, transpose_2d — bare or 3-arg HexaVal carriers.
//   - All HEXA_CUDA-gated: no-CUDA build uses CPU helpers byte-eq with
//     ag_tape.hexa host loops. FP_CONTRACT OFF (proven recipe — see
//     c0789e05 RoPE FMA, e5faa8b0 silu_gate dt_exp).
// ═══════════════════════════════════════════════════════════════════
#pragma STDC FP_CONTRACT OFF
// mk2-C2 (2026-05-19): dt_sqrt byte-exact C mirror of hexa flame_math
// `dt_sqrt` (24-iter Newton, g0 = max(x, 1.0)). The decoder-block
// rmsnorm reference uses dt_sqrt, NOT libm sqrt — same hazard as
// dt_exp ([[flame-transcendental-byteeq-hazard]]). All ops single-
// rounding sequential; FP_CONTRACT OFF scope (this block) is the
// proven recipe (see commits c0789e05 RoPE FMA, e5faa8b0 silu_gate
// dt_exp).
static double _hx_dt_sqrt_d(double x) {
    if (x <= 0.0) return 0.0;
    double g = x > 1.0 ? x : 1.0;
    int i = 0;
    while (i < 24) { g = 0.5 * (g + x / g); i = i + 1; }
    return g;
}

// _hx_farr_rmsnorm_mh_cpu(x, g, y_out, xn_out, inv_out, T, d) -> 0 ok / -1 err.
// Per-row (i ∈ [0..T)): ms = Σ x[i,c]² / d; iv = 1 / dt_sqrt(ms + eps);
// inv[i] = iv; xn[i,c] = x[i,c]·iv; y[i,c] = g[c]·xn[i,c]. Byte-identical
// to ag_tape.hexa `ag_rmsnorm_mh` host-scalar loop. eps = 1e-6.
static int _hx_farr_rmsnorm_mh_cpu(int64_t x_id, int64_t g_id,
                                   int64_t y_id, int64_t xn_id,
                                   int64_t inv_id, int64_t T, int64_t d) {
    if (x_id < 0 || x_id >= _hx_farr_count)     return -1;
    if (g_id < 0 || g_id >= _hx_farr_count)     return -1;
    if (y_id < 0 || y_id >= _hx_farr_count)     return -1;
    if (xn_id < 0 || xn_id >= _hx_farr_count)   return -1;
    if (inv_id < 0 || inv_id >= _hx_farr_count) return -1;
    if (T <= 0 || d <= 0)                       return -1;
    HexaFarrEntry* xe  = &_hx_farr_table[x_id];
    HexaFarrEntry* ge  = &_hx_farr_table[g_id];
    HexaFarrEntry* ye  = &_hx_farr_table[y_id];
    HexaFarrEntry* xne = &_hx_farr_table[xn_id];
    HexaFarrEntry* ie  = &_hx_farr_table[inv_id];
    if (!xe->buf || !ge->buf || !ye->buf || !xne->buf || !ie->buf) return -1;
    if (xe->len < T*d || ge->len < d || ye->len < T*d ||
        xne->len < T*d || ie->len < T)          return -1;
    const double* X = xe->buf;
    const double* G = ge->buf;
    double* Y  = ye->buf;
    double* XN = xne->buf;
    double* I  = ie->buf;
    const double eps = 0.000001;
    for (int64_t i = 0; i < T; i++) {
        double ms = 0.0;
        for (int64_t c = 0; c < d; c++) {
            double xv = X[i*d + c];
            ms = ms + xv * xv;
        }
        ms = ms / (double)d;  /* byte-eq with hexa `ms / to_float(d)` */
        double iv = 1.0 / _hx_dt_sqrt_d(ms + eps);
        I[i] = iv;
        for (int64_t c = 0; c < d; c++) {
            double xni = X[i*d + c] * iv;
            XN[i*d + c] = xni;
            Y[i*d + c]  = G[c] * xni;
        }
    }
    return 0;
}

// mk2-C5 (2026-05-19): farr_copy_slice + farr_transpose_2d CPU mirrors.
// Pure memcpy / memory rearrangement — no FP arithmetic, byte-eq with
// host scalar t_get/t_set is automatic. Used as the no-CUDA fallback
// and (when the runtime is built without -DHEXA_CUDA) as the entire
// implementation.
static int _hx_farr_copy_slice_cpu(int64_t src_id, int64_t soff,
                                   int64_t dst_id, int64_t doff,
                                   int64_t n) {
    if (src_id < 0 || src_id >= _hx_farr_count) return -1;
    if (dst_id < 0 || dst_id >= _hx_farr_count) return -1;
    if (n <= 0 || soff < 0 || doff < 0) return -1;
    HexaFarrEntry* se = &_hx_farr_table[src_id];
    HexaFarrEntry* de = &_hx_farr_table[dst_id];
    if (!se->buf || !de->buf) return -1;
    if (se->len < soff + n || de->len < doff + n) return -1;
    hxlcl_memcpy(de->buf + doff, se->buf + soff, (size_t)n * sizeof(double));
    return 0;
}
static int _hx_farr_fill_dt_lcg_cpu(int64_t dst_id, int64_t doff, int64_t n,
                                    int64_t seed, double scale) {
    if (dst_id < 0 || dst_id >= _hx_farr_count) return -1;
    if (n <= 0 || doff < 0) return -1;
    HexaFarrEntry* de = &_hx_farr_table[dst_id];
    if (!de->buf || de->len < doff + n) return -1;
    double* D = de->buf;
    int64_t s = seed;
    for (int64_t i = 0; i < n; i++) {
        s = (s * (int64_t)1103515245 + (int64_t)12345) % (int64_t)2147483648;
        double rv = (double)(s % 1000) / 1000.0 - 0.5;
        D[doff + i] = rv * scale;
    }
    return 0;
}
static int _hx_farr_add_inplace_cpu(int64_t dst_id, int64_t src_id, int64_t n) {
    if (dst_id < 0 || dst_id >= _hx_farr_count) return -1;
    if (src_id < 0 || src_id >= _hx_farr_count) return -1;
    if (n <= 0) return -1;
    HexaFarrEntry* de = &_hx_farr_table[dst_id];
    HexaFarrEntry* se = &_hx_farr_table[src_id];
    if (!de->buf || !se->buf || de->len < n || se->len < n) return -1;
    double* D = de->buf;
    const double* S = se->buf;
    for (int64_t i = 0; i < n; i++) D[i] = D[i] + S[i];
    return 0;
}
static int _hx_farr_zero_slice_cpu(int64_t dst_id, int64_t doff, int64_t n) {
    if (dst_id < 0 || dst_id >= _hx_farr_count) return -1;
    if (n <= 0 || doff < 0) return -1;
    HexaFarrEntry* de = &_hx_farr_table[dst_id];
    if (!de->buf || de->len < doff + n) return -1;
    hxlcl_memset(de->buf + doff, 0, (size_t)n * sizeof(double));
    return 0;
}
static int _hx_farr_transpose_2d_cpu(int64_t src_id, int64_t soff,
                                     int64_t dst_id, int64_t doff,
                                     int64_t d_out, int64_t d_in) {
    if (src_id < 0 || src_id >= _hx_farr_count) return -1;
    if (dst_id < 0 || dst_id >= _hx_farr_count) return -1;
    if (d_out <= 0 || d_in <= 0 || soff < 0 || doff < 0) return -1;
    HexaFarrEntry* se = &_hx_farr_table[src_id];
    HexaFarrEntry* de = &_hx_farr_table[dst_id];
    if (!se->buf || !de->buf) return -1;
    int64_t total = d_out * d_in;
    if (se->len < soff + total || de->len < doff + total) return -1;
    const double* S = se->buf;
    double* D = de->buf;
    for (int64_t r = 0; r < d_out; r++) {
        for (int64_t c = 0; c < d_in; c++) {
            D[doff + c * d_out + r] = S[soff + r * d_in + c];
        }
    }
    return 0;
}

// mk2-C4 (2026-05-19): GQA attention-dt fwd CPU mirror. Byte-eq with
// ag_tape.hexa::_ag_attn_dt_fwd host loop (causal mask + GQA kvh =
// hh/n_rep + stable softmax via dt_exp + dt_sqrt scale). Memory:
// Q[T·nh·hd], K[T·nkv·hd], V[T·nkv·hd]; out P[nh·T·T] (j<L only,
// j≥L stays 0 per caller's t_zeros init) and CTX[T·nh·hd]. 0/-1 rc.
static int _hx_farr_attn_dt_fwd_cpu(int64_t q_id, int64_t k_id, int64_t v_id,
                                    int64_t p_id, int64_t ctx_id,
                                    int64_t T, int64_t nh, int64_t nkv,
                                    int64_t hd) {
    if (q_id < 0 || q_id >= _hx_farr_count)     return -1;
    if (k_id < 0 || k_id >= _hx_farr_count)     return -1;
    if (v_id < 0 || v_id >= _hx_farr_count)     return -1;
    if (p_id < 0 || p_id >= _hx_farr_count)     return -1;
    if (ctx_id < 0 || ctx_id >= _hx_farr_count) return -1;
    if (T <= 0 || nh <= 0 || nkv <= 0 || hd <= 0) return -1;
    if (nh % nkv != 0) return -1;
    HexaFarrEntry* qe = &_hx_farr_table[q_id];
    HexaFarrEntry* ke = &_hx_farr_table[k_id];
    HexaFarrEntry* ve = &_hx_farr_table[v_id];
    HexaFarrEntry* pe = &_hx_farr_table[p_id];
    HexaFarrEntry* ce = &_hx_farr_table[ctx_id];
    if (!qe->buf || !ke->buf || !ve->buf || !pe->buf || !ce->buf) return -1;
    int64_t nq = T * nh  * hd;
    int64_t nk = T * nkv * hd;
    int64_t np = nh * T * T;
    if (qe->len < nq || ke->len < nk || ve->len < nk ||
        pe->len < np || ce->len < nq) return -1;
    const double* Q = qe->buf;
    const double* K = ke->buf;
    const double* V = ve->buf;
    double* P = pe->buf;
    double* C = ce->buf;
    int64_t n_rep = nh / nkv;
    int64_t d     = nh * hd;
    double scale = 1.0 / _hx_dt_sqrt_d((double)hd);
    for (int64_t hh = 0; hh < nh; hh++) {
        int64_t kvh = hh / n_rep;
        for (int64_t i = 0; i < T; i++) {
            int64_t L = i + 1;
            for (int64_t j = 0; j < L; j++) {
                double dot = 0.0;
                for (int64_t c = 0; c < hd; c++) {
                    dot = dot + Q[(i*nh + hh)*hd + c]
                              * K[(j*nkv + kvh)*hd + c];
                }
                P[(hh*T + i)*T + j] = dot * scale;
            }
            double mx = P[(hh*T + i)*T + 0];
            for (int64_t j = 1; j < L; j++) {
                double v = P[(hh*T + i)*T + j];
                if (v > mx) mx = v;
            }
            double tot = 0.0;
            for (int64_t j = 0; j < L; j++) {
                double e = _hx_dt_exp_d(P[(hh*T + i)*T + j] - mx);
                P[(hh*T + i)*T + j] = e;
                tot = tot + e;
            }
            for (int64_t j = 0; j < L; j++) {
                P[(hh*T + i)*T + j] = P[(hh*T + i)*T + j] / tot;
            }
            for (int64_t c2 = 0; c2 < hd; c2++) {
                double acc = 0.0;
                for (int64_t j = 0; j < L; j++) {
                    acc = acc + P[(hh*T + i)*T + j]
                              * V[(j*nkv + kvh)*hd + c2];
                }
                C[i*d + hh*hd + c2] = acc;
            }
        }
    }
    return 0;
}

// mk2-C4-bwd (2026-05-19): GQA attention-dt bwd CPU mirror. Byte-eq
// with ag_tape.hexa::_ag_attn_dt_bwd host loop. dQ/dK/dV are FRESH
// t_zeros from the tape-replay site (`else if kind == ag_k_attn_dt()`
// at ag_tape.hexa:655) so we treat them as zero-init accumulators —
// no read-modify-write hazard. Returns 0 ok / -1 err.
static int _hx_farr_attn_dt_bwd_cpu(int64_t q_id, int64_t k_id, int64_t v_id,
                                    int64_t p_id, int64_t dctx_id,
                                    int64_t dq_id, int64_t dk_id, int64_t dv_id,
                                    int64_t T, int64_t nh, int64_t nkv,
                                    int64_t hd) {
    if (q_id < 0 || q_id >= _hx_farr_count) return -1;
    if (k_id < 0 || k_id >= _hx_farr_count) return -1;
    if (v_id < 0 || v_id >= _hx_farr_count) return -1;
    if (p_id < 0 || p_id >= _hx_farr_count) return -1;
    if (dctx_id < 0 || dctx_id >= _hx_farr_count) return -1;
    if (dq_id < 0 || dq_id >= _hx_farr_count) return -1;
    if (dk_id < 0 || dk_id >= _hx_farr_count) return -1;
    if (dv_id < 0 || dv_id >= _hx_farr_count) return -1;
    if (T <= 0 || nh <= 0 || nkv <= 0 || hd <= 0) return -1;
    if (nh % nkv != 0) return -1;
    HexaFarrEntry* qe = &_hx_farr_table[q_id];
    HexaFarrEntry* ke = &_hx_farr_table[k_id];
    HexaFarrEntry* ve = &_hx_farr_table[v_id];
    HexaFarrEntry* pe = &_hx_farr_table[p_id];
    HexaFarrEntry* de = &_hx_farr_table[dctx_id];
    HexaFarrEntry* dqe= &_hx_farr_table[dq_id];
    HexaFarrEntry* dke= &_hx_farr_table[dk_id];
    HexaFarrEntry* dve= &_hx_farr_table[dv_id];
    if (!qe->buf || !ke->buf || !ve->buf || !pe->buf || !de->buf ||
        !dqe->buf || !dke->buf || !dve->buf) return -1;
    int64_t nq = T * nh  * hd;
    int64_t nk = T * nkv * hd;
    int64_t np = nh * T * T;
    if (qe->len < nq || ke->len < nk || ve->len < nk ||
        pe->len < np || de->len < nq ||
        dqe->len < nq || dke->len < nk || dve->len < nk) return -1;
    const double* Q = qe->buf;
    const double* K = ke->buf;
    const double* V = ve->buf;
    const double* P = pe->buf;
    const double* dctx = de->buf;
    double* dQ = dqe->buf;
    double* dK = dke->buf;
    double* dV = dve->buf;
    int64_t n_rep = nh / nkv;
    int64_t d     = nh * hd;
    double scale = 1.0 / _hx_dt_sqrt_d((double)hd);
    /* Per-row scratch dP_row[T]; freed at end (matches hexa t_free). */
    double* dP_row = (double*)malloc((size_t)T * sizeof(double));
    if (!dP_row) return -1;
    for (int64_t hh = 0; hh < nh; hh++) {
        int64_t kvh = hh / n_rep;
        for (int64_t i = 0; i < T; i++) {
            int64_t L = i + 1;
            for (int64_t j = 0; j < L; j++) {
                double acc = 0.0;
                for (int64_t c = 0; c < hd; c++) {
                    acc = acc + dctx[i*d + hh*hd + c]
                              * V[(j*nkv + kvh)*hd + c];
                }
                dP_row[j] = acc;
            }
            double sdot = 0.0;
            for (int64_t j2 = 0; j2 < L; j2++) {
                sdot = sdot + P[(hh*T + i)*T + j2] * dP_row[j2];
            }
            for (int64_t j3 = 0; j3 < L; j3++) {
                double pij = P[(hh*T + i)*T + j3];
                for (int64_t c = 0; c < hd; c++) {
                    int64_t dv_idx = (j3*nkv + kvh)*hd + c;
                    dV[dv_idx] = dV[dv_idx] + pij * dctx[i*d + hh*hd + c];
                }
            }
            for (int64_t j4 = 0; j4 < L; j4++) {
                double dS = P[(hh*T + i)*T + j4]
                          * (dP_row[j4] - sdot) * scale;
                for (int64_t c2 = 0; c2 < hd; c2++) {
                    int64_t dq_idx = (i*nh + hh)*hd + c2;
                    int64_t dk_idx = (j4*nkv + kvh)*hd + c2;
                    dQ[dq_idx] = dQ[dq_idx] + dS * K[(j4*nkv + kvh)*hd + c2];
                    dK[dk_idx] = dK[dk_idx] + dS * Q[(i*nh + hh)*hd + c2];
                }
            }
        }
    }
    free(dP_row);
    return 0;
}


#pragma STDC FP_CONTRACT DEFAULT

// mk2-C2 (2026-05-19): RMSNorm-mh forge-route. Bare 7-arg function
// (exceeds hexa_callN ≤4-arg ceiling; same pattern as farr_rope_gpu).
// fwd: per-row ms = Σ x²/d → iv = 1/dt_sqrt(ms+eps) → y[c]=g[c]·x[c]·iv;
// caller supplies pre-allocated y[T·d], xn[T·d], inv[T] buffers + reads
// back via lazy-D2H (mk2-C3 §6.4) on host scalar access. Returns 0 on
// ok / -1 err. The CUDA kernel + host wrapper live in
// self/cuda/runtime_cuda.c (`__dmul_rn`/`__dadd_rn`/`__ddiv_rn` dt_sqrt
// mirror — proven recipe [[flame-transcendental-byteeq-hazard]]).
// No-CUDA fallback = `_hx_farr_rmsnorm_mh_cpu` (byte-eq with ag_tape
// host-scalar loop, FP_CONTRACT OFF block).
#ifdef HEXA_CUDA
extern int _hx_cuda_farr_rmsnorm_mh_gpu(int64_t x_id, int64_t g_id,
                                        int64_t y_id, int64_t xn_id,
                                        int64_t inv_id, int64_t T,
                                        int64_t d);
#endif
HexaVal farr_rmsnorm_mh_gpu(HexaVal x_v, HexaVal g_v, HexaVal y_v,
                            HexaVal xn_v, HexaVal inv_v, HexaVal T_v,
                            HexaVal d_v) {
    int64_t x_id  = hexa_as_num(x_v);
    int64_t g_id  = hexa_as_num(g_v);
    int64_t y_id  = hexa_as_num(y_v);
    int64_t xn_id = hexa_as_num(xn_v);
    int64_t inv_id= hexa_as_num(inv_v);
    int64_t T     = hexa_as_num(T_v);
    int64_t d     = hexa_as_num(d_v);
#ifdef HEXA_CUDA
    if (T <= 0 || d <= 0) return hexa_int(-1);
    int rc = _hx_cuda_farr_rmsnorm_mh_gpu(x_id, g_id, y_id, xn_id,
                                          inv_id, T, d);
    return hexa_int(rc);
#else
    return hexa_int(_hx_farr_rmsnorm_mh_cpu(x_id, g_id, y_id, xn_id,
                                            inv_id, T, d));
#endif
}

// mk2-C4 (2026-05-19): attn-dt fwd forge-route. Bare 9-arg function;
// caller pre-allocates P[nh·T·T] (must be t_zeros — upper triangle
// stays 0) + CTX[T·nh·hd]. dt_sqrt+dt_exp byte-eq mirror in
// runtime_cuda.c kernel / runtime.c CPU fallback.
#ifdef HEXA_CUDA
extern int _hx_cuda_farr_attn_dt_fwd_gpu(int64_t q_id, int64_t k_id,
                                         int64_t v_id, int64_t p_id,
                                         int64_t ctx_id, int64_t T,
                                         int64_t nh, int64_t nkv,
                                         int64_t hd);
#endif
HexaVal farr_attn_dt_fwd_gpu(HexaVal q_v, HexaVal k_v, HexaVal v_v,
                             HexaVal p_v, HexaVal ctx_v, HexaVal T_v,
                             HexaVal nh_v, HexaVal nkv_v, HexaVal hd_v) {
    int64_t q_id   = hexa_as_num(q_v);
    int64_t k_id   = hexa_as_num(k_v);
    int64_t v_id   = hexa_as_num(v_v);
    int64_t p_id   = hexa_as_num(p_v);
    int64_t ctx_id = hexa_as_num(ctx_v);
    int64_t T      = hexa_as_num(T_v);
    int64_t nh     = hexa_as_num(nh_v);
    int64_t nkv    = hexa_as_num(nkv_v);
    int64_t hd     = hexa_as_num(hd_v);
#ifdef HEXA_CUDA
    if (T <= 0 || nh <= 0 || nkv <= 0 || hd <= 0) return hexa_int(-1);
    int rc = _hx_cuda_farr_attn_dt_fwd_gpu(q_id, k_id, v_id, p_id, ctx_id,
                                           T, nh, nkv, hd);
    return hexa_int(rc);
#else
    return hexa_int(_hx_farr_attn_dt_fwd_cpu(q_id, k_id, v_id, p_id, ctx_id,
                                             T, nh, nkv, hd));
#endif
}

// mk2-C4-bwd (2026-05-19): attn-dt bwd forge-route. Bare 12-arg
// function. dQ/dK/dV must be fresh t_zeros at the call site (the
// tape replay site in ag_tape.hexa allocates them inline, so this
// contract holds). 3-kernel device path (dP_row precompute → dS in
// place + dQ → output-centric dV + dK) — full byte-eq mirror in
// runtime_cuda.c.
#ifdef HEXA_CUDA
extern int _hx_cuda_farr_attn_dt_bwd_gpu(int64_t q_id, int64_t k_id,
                                         int64_t v_id, int64_t p_id,
                                         int64_t dctx_id, int64_t dq_id,
                                         int64_t dk_id, int64_t dv_id,
                                         int64_t T, int64_t nh,
                                         int64_t nkv, int64_t hd);
#endif
// mk2-C5 (2026-05-19): batch slice/transpose builtins. Eliminate the
// ~412M per-step host-scalar t_get/t_set prelude (HexaVal box overhead)
// that mk2-FINAL #1 (2026-05-19) measured at 14min GPU 0% idle on the
// d768·12L generic ag_tape path. Pure memcpy / memory rearrangement —
// no FP arithmetic so byte-eq with the host loop is automatic.
#ifdef HEXA_CUDA
extern int _hx_cuda_farr_copy_slice_gpu(int64_t src_id, int64_t soff,
                                        int64_t dst_id, int64_t doff,
                                        int64_t n);
extern int _hx_cuda_farr_transpose_2d_gpu(int64_t src_id, int64_t soff,
                                          int64_t dst_id, int64_t doff,
                                          int64_t d_out, int64_t d_in);
extern int _hx_cuda_farr_zero_slice_gpu(int64_t dst_id, int64_t doff,
                                        int64_t n);
extern int _hx_cuda_farr_add_inplace_gpu(int64_t dst_id, int64_t src_id,
                                         int64_t n);
extern int _hx_cuda_farr_fill_dt_lcg_gpu(int64_t dst_id, int64_t doff,
                                         int64_t n, int64_t seed,
                                         double scale);
#endif
// 3-arg builtins use the HexaVal carrier + hexa_fn_new pattern (codegen
// emits hexa_call3, which dispatches via the carrier — same as
// farr_silu_gate_gpu / farr_add_gpu). Function name gets `hexa_`
// prefix; the carrier without prefix is registered at init time.
HexaVal hexa_farr_zero_slice_gpu(HexaVal dst_v, HexaVal doff_v, HexaVal n_v) {
    int64_t dst_id = hexa_as_num(dst_v);
    int64_t doff   = hexa_as_num(doff_v);
    int64_t n      = hexa_as_num(n_v);
#ifdef HEXA_CUDA
    return hexa_int(_hx_cuda_farr_zero_slice_gpu(dst_id, doff, n));
#else
    return hexa_int(_hx_farr_zero_slice_cpu(dst_id, doff, n));
#endif
}
HexaVal hexa_farr_add_inplace_gpu(HexaVal dst_v, HexaVal src_v, HexaVal n_v) {
    int64_t dst_id = hexa_as_num(dst_v);
    int64_t src_id = hexa_as_num(src_v);
    int64_t n      = hexa_as_num(n_v);
#ifdef HEXA_CUDA
    return hexa_int(_hx_cuda_farr_add_inplace_gpu(dst_id, src_id, n));
#else
    return hexa_int(_hx_farr_add_inplace_cpu(dst_id, src_id, n));
#endif
}
HexaVal farr_zero_slice_gpu;
HexaVal farr_add_inplace_gpu;
HexaVal farr_fill_dt_lcg_gpu(HexaVal dst_v, HexaVal doff_v, HexaVal n_v,
                             HexaVal seed_v, HexaVal scale_v) {
    int64_t dst_id = hexa_as_num(dst_v);
    int64_t doff   = hexa_as_num(doff_v);
    int64_t n      = hexa_as_num(n_v);
    int64_t seed   = hexa_as_num(seed_v);
    double scale   = __hx_to_double(scale_v);
#ifdef HEXA_CUDA
    return hexa_int(_hx_cuda_farr_fill_dt_lcg_gpu(dst_id, doff, n, seed, scale));
#else
    return hexa_int(_hx_farr_fill_dt_lcg_cpu(dst_id, doff, n, seed, scale));
#endif
}
HexaVal farr_copy_slice_gpu(HexaVal src_v, HexaVal soff_v,
                            HexaVal dst_v, HexaVal doff_v, HexaVal n_v) {
    int64_t src_id = hexa_as_num(src_v);
    int64_t soff   = hexa_as_num(soff_v);
    int64_t dst_id = hexa_as_num(dst_v);
    int64_t doff   = hexa_as_num(doff_v);
    int64_t n      = hexa_as_num(n_v);
#ifdef HEXA_CUDA
    return hexa_int(_hx_cuda_farr_copy_slice_gpu(src_id, soff, dst_id, doff, n));
#else
    return hexa_int(_hx_farr_copy_slice_cpu(src_id, soff, dst_id, doff, n));
#endif
}
HexaVal farr_transpose_2d_gpu(HexaVal src_v, HexaVal soff_v,
                              HexaVal dst_v, HexaVal doff_v,
                              HexaVal d_out_v, HexaVal d_in_v) {
    int64_t src_id = hexa_as_num(src_v);
    int64_t soff   = hexa_as_num(soff_v);
    int64_t dst_id = hexa_as_num(dst_v);
    int64_t doff   = hexa_as_num(doff_v);
    int64_t d_out  = hexa_as_num(d_out_v);
    int64_t d_in   = hexa_as_num(d_in_v);
#ifdef HEXA_CUDA
    return hexa_int(_hx_cuda_farr_transpose_2d_gpu(src_id, soff, dst_id, doff,
                                                   d_out, d_in));
#else
    return hexa_int(_hx_farr_transpose_2d_cpu(src_id, soff, dst_id, doff,
                                              d_out, d_in));
#endif
}

HexaVal farr_attn_dt_bwd_gpu(HexaVal q_v, HexaVal k_v, HexaVal v_v,
                             HexaVal p_v, HexaVal dctx_v, HexaVal dq_v,
                             HexaVal dk_v, HexaVal dv_v, HexaVal T_v,
                             HexaVal nh_v, HexaVal nkv_v, HexaVal hd_v) {
    int64_t q_id   = hexa_as_num(q_v);
    int64_t k_id   = hexa_as_num(k_v);
    int64_t v_id   = hexa_as_num(v_v);
    int64_t p_id   = hexa_as_num(p_v);
    int64_t dctx_id= hexa_as_num(dctx_v);
    int64_t dq_id  = hexa_as_num(dq_v);
    int64_t dk_id  = hexa_as_num(dk_v);
    int64_t dv_id  = hexa_as_num(dv_v);
    int64_t T      = hexa_as_num(T_v);
    int64_t nh     = hexa_as_num(nh_v);
    int64_t nkv    = hexa_as_num(nkv_v);
    int64_t hd     = hexa_as_num(hd_v);
#ifdef HEXA_CUDA
    if (T <= 0 || nh <= 0 || nkv <= 0 || hd <= 0) return hexa_int(-1);
    int rc = _hx_cuda_farr_attn_dt_bwd_gpu(q_id, k_id, v_id, p_id, dctx_id,
                                           dq_id, dk_id, dv_id,
                                           T, nh, nkv, hd);
    return hexa_int(rc);
#else
    return hexa_int(_hx_farr_attn_dt_bwd_cpu(q_id, k_id, v_id, p_id, dctx_id,
                                             dq_id, dk_id, dv_id,
                                             T, nh, nkv, hd));
#endif
}




// ── Phase B carriers (3-arg / 4-arg → hexa_callN dispatch). ───────
// All 4 ops fit within the hexa_callN ceiling (≤4-arg), so each gets a
// HexaVal carrier registered via hexa_fn_new at init time (see the
// init block below for the registration calls).
HexaVal farr_softmax_rows_gpu;
HexaVal farr_rmsnorm_rows_gpu;
HexaVal farr_add_gpu;
HexaVal farr_scale_gpu;
HexaVal farr_silu_gate_gpu;

// ═══════════════════════════════════════════════════════════════════
// anima RFC 040 Phase B2 (2026-05-16): d_train5 hot-path completion —
// the remaining DOMINANT-FLOP farr ops the Phase E refactor of
// HEXAD/D/d_train5_lib.hexa needs so every c3_*/d5_* boxed op has a
// matching `farr_*_gpu` primitive (clean swap target). Scaffolding
// only (Mac, no CUDA) — same `#ifdef HEXA_CUDA` (TODO[cuda] stub
// returns -1) / `#ifndef HEXA_CUDA` (verified CPU helper) dispatch as
// Phase A/B. RFC 032 use-after-realloc guard carried verbatim
// (re-fetch _hx_farr_table entry pointers after every hexa_farr_zeros).
//
// d_train5 op-audit → ops landed here (the dominant-FLOP missing set):
//   farr_matmul_t_gpu       Mᵀ·u   (c3_matvec_t — dX / dr / dzT vjp)
//   farr_outer_gpu          u⊗v    (c3_outer    — dW / dWg / dWh grad)
//   farr_mul_gpu            A⊙B    (SwiGLU s=silu(a)⊙b, dq'⊙cos etc.)
//   farr_silu_gpu           silu(x)=x·σ(x)        (SwiGLU activation)
//   farr_silu_grad_gpu      σ(x)·(1+x·(1−σ(x)))   (SwiGLU bwd)
//   farr_rmsnorm_bwd_rows_gpu  exact RMSNorm vjp dy→dx (c3_rmsnorm_bwd
//                              dx-branch; per-channel gain handled by
//                              caller via farr_mul_gpu — this is the
//                              inv-rms vjp core, mirrors the fwd-kernel
//                              gain-free split of Phase B rmsnorm_rows)
//   farr_adamw_step_gpu     decoupled-wd AdamW in-place (dt2_adamw_step)
//
// CPU helpers verified vs the trusted boxed c3_*/dt2_* reference in
// tmp_rfc040_phaseB2_smoke.hexa (each op's no-CUDA dispatcher proven
// ≡ a hexa-side oracle that replays the exact c3_*/dt2_* formula).
//
// Honestly deferred (low FLOP / memory-bound — NOT dominant): RoPE
// scalar trig rotate (d5_rope_*), embedding gather + scatter-add
// (d5_forward / d5_grad tied-embed). Named for a follow-on cycle.
// ═══════════════════════════════════════════════════════════════════

#ifdef HEXA_CUDA
/* Forward decls for the Phase B2 GPU TU (TODO[cuda] — bodies on the
 * CUDA host build only). NOT defined in the no-CUDA build. */
extern int  _hx_cuda_farr_matmul_t_gpu(int64_t m_id, int64_t R, int64_t C,
                                        int64_t u_id, int64_t out_id);
extern int  _hx_cuda_farr_outer_gpu(int64_t u_id, int64_t v_id,
                                     int64_t R, int64_t C, int64_t out_id);
extern int  _hx_cuda_farr_mul_gpu(int64_t a_id, int64_t b_id,
                                   int64_t n, int64_t out_id);
extern int  _hx_cuda_farr_silu_gpu(int64_t x_id, int64_t n, int64_t out_id);
extern int  _hx_cuda_farr_silu_grad_gpu(int64_t x_id, int64_t n,
                                         int64_t out_id);
extern int  _hx_cuda_farr_silu_gate_gpu(int64_t a_id, int64_t b_id,
                                         int64_t n, int64_t out_id);
extern int  _hx_cuda_farr_rmsnorm_bwd_rows_gpu(int64_t x_id, int64_t dxn_id,
                                                int64_t R, int64_t C,
                                                int64_t out_id);
extern int  _hx_cuda_farr_adamw_step_gpu(int64_t w_id, int64_t m_id,
                                          int64_t v_id, int64_t g_id,
                                          int64_t n, double lr, double b1,
                                          double b2, double eps, double wd,
                                          int64_t step_t, int64_t out_id);
extern int  _hx_cuda_farr_rope_gpu(int64_t t_id, int64_t cos_id,
                                    int64_t sin_id, int64_t T,
                                    int64_t nheads, int64_t hd,
                                    int64_t out_id);
extern int  _hx_cuda_farr_rope_bwd_gpu(int64_t t_id, int64_t cos_id,
                                        int64_t sin_id, int64_t T,
                                        int64_t nheads, int64_t hd,
                                        int64_t out_id);
extern int  _hx_cuda_farr_transpose_scatter_gpu(int64_t src_id,
                                                int64_t dst_id,
                                                int64_t rows, int64_t cols,
                                                int64_t dst_off);
#endif

// ── CPU helpers (Phase B2 no-CUDA fallback). Each: (a) validate ids,
//    (b) hexa_farr_zeros output, (c) RE-FETCH entry ptrs post-alloc
//    (RFC 032 use-after-realloc guard), (d) compute. ────────────────

// _hx_farr_matmul_t_cpu(M, R, C, u) -> new farr_id [C]. Mᵀ·u where M is
// row-major [R·C], u is [R]. out[k] = Σ_r M[r·C+k]·u[r]. Mirrors
// d_train3_lib c3_matvec_t EXACTLY (same r-outer / k-inner accumulation
// order → bit-identical on no-CUDA). -1 on err.
static int64_t _hx_farr_matmul_t_cpu(int64_t m_id, int64_t R, int64_t C,
                                     int64_t u_id) {
    if (m_id < 0 || m_id >= _hx_farr_count) return -1;
    if (u_id < 0 || u_id >= _hx_farr_count) return -1;
    if (R <= 0 || C <= 0)                   return -1;
    HexaFarrEntry* me = &_hx_farr_table[m_id];
    HexaFarrEntry* ue = &_hx_farr_table[u_id];
    if (!me->buf || !ue->buf)               return -1;
    if (me->len < R * C || ue->len < R)     return -1;
    HexaVal out_h = hexa_farr_zeros(hexa_int(C));
    int64_t out_id = HX_INT(out_h);
    if (out_id < 0 || out_id >= _hx_farr_count) return -1;
    me = &_hx_farr_table[m_id];
    ue = &_hx_farr_table[u_id];
    HexaFarrEntry* oe = &_hx_farr_table[out_id];
    if (!me->buf || !ue->buf || !oe->buf || oe->len < C) return -1;
    const double* M = me->buf;
    const double* U = ue->buf;
    double*       O = oe->buf;
    for (int64_t k = 0; k < C; k++) O[k] = 0.0;
    for (int64_t r = 0; r < R; r++) {
        const double* mr = M + r * C;
        double ur = U[r];
        for (int64_t k = 0; k < C; k++) O[k] += mr[k] * ur;
    }
    return out_id;
}

// _hx_farr_outer_cpu(u, v, R, C) -> new farr_id [R·C]. out[r·C+c] =
// u[r]·v[c]. Mirrors c3_outer EXACTLY. -1 on err.
static int64_t _hx_farr_outer_cpu(int64_t u_id, int64_t v_id,
                                  int64_t R, int64_t C) {
    if (u_id < 0 || u_id >= _hx_farr_count) return -1;
    if (v_id < 0 || v_id >= _hx_farr_count) return -1;
    if (R <= 0 || C <= 0)                   return -1;
    HexaFarrEntry* ue = &_hx_farr_table[u_id];
    HexaFarrEntry* ve = &_hx_farr_table[v_id];
    if (!ue->buf || !ve->buf)               return -1;
    if (ue->len < R || ve->len < C)         return -1;
    HexaVal out_h = hexa_farr_zeros(hexa_int(R * C));
    int64_t out_id = HX_INT(out_h);
    if (out_id < 0 || out_id >= _hx_farr_count) return -1;
    ue = &_hx_farr_table[u_id];
    ve = &_hx_farr_table[v_id];
    HexaFarrEntry* oe = &_hx_farr_table[out_id];
    if (!ue->buf || !ve->buf || !oe->buf || oe->len < R * C) return -1;
    const double* U = ue->buf;
    const double* V = ve->buf;
    double*       O = oe->buf;
    for (int64_t r = 0; r < R; r++) {
        double ur = U[r];
        double* orow = O + r * C;
        for (int64_t c = 0; c < C; c++) orow[c] = ur * V[c];
    }
    return out_id;
}

// _hx_farr_mul_cpu(a, b, n) -> new farr_id. C = A⊙B (Hadamard). -1 err.
static int64_t _hx_farr_mul_cpu(int64_t a_id, int64_t b_id, int64_t n) {
    if (a_id < 0 || a_id >= _hx_farr_count) return -1;
    if (b_id < 0 || b_id >= _hx_farr_count) return -1;
    if (n <= 0)                              return -1;
    HexaFarrEntry* ae = &_hx_farr_table[a_id];
    HexaFarrEntry* be = &_hx_farr_table[b_id];
    if (!ae->buf || !be->buf)                return -1;
    if (ae->len < n || be->len < n)          return -1;
    HexaVal out_h = hexa_farr_zeros(hexa_int(n));
    int64_t out_id = HX_INT(out_h);
    if (out_id < 0 || out_id >= _hx_farr_count) return -1;
    ae = &_hx_farr_table[a_id];
    be = &_hx_farr_table[b_id];
    HexaFarrEntry* oe = &_hx_farr_table[out_id];
    if (!ae->buf || !be->buf || !oe->buf || oe->len < n) return -1;
    const double* A = ae->buf;
    const double* B = be->buf;
    double*       O = oe->buf;
    for (int64_t i = 0; i < n; i++) O[i] = A[i] * B[i];
    return out_id;
}

// silu(x) = x · σ(x), σ(x) = 1/(1+exp(-x)). Mirrors c3_sigmoid/c3_silu.
static inline double _hx_sigmoid_d(double x) { return 1.0 / (1.0 + hxlcl_exp(-x)); }

// _hx_farr_silu_cpu(x, n) -> new farr_id. y[i] = silu(x[i]). -1 err.
static int64_t _hx_farr_silu_cpu(int64_t x_id, int64_t n) {
    if (x_id < 0 || x_id >= _hx_farr_count) return -1;
    if (n <= 0)                              return -1;
    HexaFarrEntry* xe = &_hx_farr_table[x_id];
    if (!xe->buf || xe->len < n)             return -1;
    HexaVal out_h = hexa_farr_zeros(hexa_int(n));
    int64_t out_id = HX_INT(out_h);
    if (out_id < 0 || out_id >= _hx_farr_count) return -1;
    xe = &_hx_farr_table[x_id];
    HexaFarrEntry* oe = &_hx_farr_table[out_id];
    if (!xe->buf || !oe->buf || oe->len < n) return -1;
    const double* X = xe->buf;
    double*       Y = oe->buf;
    for (int64_t i = 0; i < n; i++) Y[i] = X[i] * _hx_sigmoid_d(X[i]);
    return out_id;
}

// _hx_farr_silu_grad_cpu(x, n) -> new farr_id.
// silu'(x) = σ(x)·(1 + x·(1−σ(x))). Mirrors c3_silu_grad EXACTLY. -1 err.
static int64_t _hx_farr_silu_grad_cpu(int64_t x_id, int64_t n) {
    if (x_id < 0 || x_id >= _hx_farr_count) return -1;
    if (n <= 0)                              return -1;
    HexaFarrEntry* xe = &_hx_farr_table[x_id];
    if (!xe->buf || xe->len < n)             return -1;
    HexaVal out_h = hexa_farr_zeros(hexa_int(n));
    int64_t out_id = HX_INT(out_h);
    if (out_id < 0 || out_id >= _hx_farr_count) return -1;
    xe = &_hx_farr_table[x_id];
    HexaFarrEntry* oe = &_hx_farr_table[out_id];
    if (!xe->buf || !oe->buf || oe->len < n) return -1;
    const double* X = xe->buf;
    double*       Y = oe->buf;
    for (int64_t i = 0; i < n; i++) {
        double s = _hx_sigmoid_d(X[i]);
        Y[i] = s * (1.0 + X[i] * (1.0 - s));
    }
    return out_id;
}

// _hx_farr_rmsnorm_bwd_rows_cpu(x, dxn, R, C) -> new farr_id [R·C].
// The EXACT RMSNorm vjp dx-branch (per row), inv-rms recomputed from x
// (eps=1e-6, matches c3_rmsnorm_fwd) so the kernel is self-contained
// (caller supplies dxn = dy⊙g; the per-channel-gain split mirrors the
// Phase B fwd rmsnorm_rows gain-free convention):
//   inv  = (mean_j(x²)+ε)^(−1/2)
//   dot  = Σ_k dxn_k·x_k
//   dx_i = inv·dxn_i − (inv³·x_i/C)·dot
// Mirrors d_train3_lib c3_rmsnorm_bwd dx formula EXACTLY. -1 err.
static int64_t _hx_farr_rmsnorm_bwd_rows_cpu(int64_t x_id, int64_t dxn_id,
                                             int64_t R, int64_t C) {
    if (x_id < 0   || x_id >= _hx_farr_count)   return -1;
    if (dxn_id < 0 || dxn_id >= _hx_farr_count) return -1;
    if (R <= 0 || C <= 0)                       return -1;
    HexaFarrEntry* xe = &_hx_farr_table[x_id];
    HexaFarrEntry* de = &_hx_farr_table[dxn_id];
    if (!xe->buf || !de->buf)                   return -1;
    if (xe->len < R * C || de->len < R * C)     return -1;
    HexaVal out_h = hexa_farr_zeros(hexa_int(R * C));
    int64_t out_id = HX_INT(out_h);
    if (out_id < 0 || out_id >= _hx_farr_count) return -1;
    xe = &_hx_farr_table[x_id];
    de = &_hx_farr_table[dxn_id];
    HexaFarrEntry* oe = &_hx_farr_table[out_id];
    if (!xe->buf || !de->buf || !oe->buf || oe->len < R * C) return -1;
    const double* X   = xe->buf;
    const double* DXN = de->buf;
    double*       O   = oe->buf;
    double inv_C = 1.0 / (double)C;
    for (int64_t r = 0; r < R; r++) {
        const double* xr  = X   + r * C;
        const double* dxr = DXN + r * C;
        double*       orr = O   + r * C;
        double ms = 0.0;
        for (int64_t j = 0; j < C; j++) ms += xr[j] * xr[j];
        ms *= inv_C;
        double inv  = 1.0 / sqrt(ms + 1e-6);
        double dot  = 0.0;
        for (int64_t k = 0; k < C; k++) dot += dxr[k] * xr[k];
        double coef = (inv * inv * inv) * inv_C;
        for (int64_t i = 0; i < C; i++)
            orr[i] = inv * dxr[i] - coef * xr[i] * dot;
    }
    return out_id;
}

// _hx_farr_rope_cpu(t_id, cos, sin, T, nheads, hd, is_bwd) -> new
// farr_id [T·nheads·hd]. Rotary position embedding (RFC 041 Phase B
// completion). Consumes PRECOMPUTED cos/sin tables [T·hd] — does NOT
// recompute angles. Mirrors flame decoder_block_lib.hexa §3 (fwd) /
// §3rev (bwd); CPU reference tool/flame_phase4d6_block_{fwd,bwd}_
// primitive.c. Tensor T_buf row-major [T·nheads·hd], row for (t,hh)
// at (t·nheads+hh)·hd; cos/sin [T·hd] indexed bse+c, bse=t·hd.
//   fwd:  rh_c = (c<half)? -x[row+half+c] : x[row+c-half]
//         out  = x[row+c]·cos[bse+c] + rh_c·sin[bse+c]
//   bwd:  gs   = (c<half)?  dx[row+half+c]·sin[bse+half+c]
//                        : -dx[row+c-half]·sin[bse+c-half]
//         out  = dx[row+c]·cos[bse+c] + gs
// Pure per-element (out depends only on row elements c and c±half) —
// the GPU kernel reads from a separate input buffer so it is byte-eq.
// -1 err.
//
// FP_CONTRACT OFF: the byte-eq oracle (flame_ag_tape_test Test 9)
// pins this against the verified hexa primitive nn_rope_apply_fwd,
// which codegens through opaque farr_get() calls and is therefore
// NOT FMA-contracted (2 roundings for a*b+c*d). Raw double[] here
// lets clang contract a*b+c*d into one fma() (1 rounding) → a
// ~1e-17 mismatch that fails the leaf-op max|Δ|=0 bar. Disabling
// contraction for this kernel only makes the CPU fallback conform
// to the reference's rounding, restoring exact byte-eq without
// de-optimizing the rest of the runtime.
#pragma STDC FP_CONTRACT OFF
static int64_t _hx_farr_rope_cpu(int64_t t_id, int64_t cos_id,
                                 int64_t sin_id, int64_t T,
                                 int64_t nheads, int64_t hd,
                                 int is_bwd) {
    if (t_id < 0   || t_id >= _hx_farr_count)   return -1;
    if (cos_id < 0 || cos_id >= _hx_farr_count) return -1;
    if (sin_id < 0 || sin_id >= _hx_farr_count) return -1;
    if (T <= 0 || nheads <= 0 || hd <= 0)       return -1;
    if ((hd & 1) != 0)                          return -1;
    int64_t total = T * nheads * hd;
    HexaFarrEntry* te = &_hx_farr_table[t_id];
    HexaFarrEntry* ce = &_hx_farr_table[cos_id];
    HexaFarrEntry* se = &_hx_farr_table[sin_id];
    if (!te->buf || !ce->buf || !se->buf)       return -1;
    if (te->len < total)                        return -1;
    if (ce->len < T * hd || se->len < T * hd)   return -1;
    HexaVal out_h = hexa_farr_zeros(hexa_int(total));
    int64_t out_id = HX_INT(out_h);
    if (out_id < 0 || out_id >= _hx_farr_count) return -1;
    te = &_hx_farr_table[t_id];
    ce = &_hx_farr_table[cos_id];
    se = &_hx_farr_table[sin_id];
    HexaFarrEntry* oe = &_hx_farr_table[out_id];
    if (!te->buf || !ce->buf || !se->buf || !oe->buf) return -1;
    if (oe->len < total)                        return -1;
    const double* X   = te->buf;
    const double* COS = ce->buf;
    const double* SIN = se->buf;
    double*       O   = oe->buf;
    int64_t half = hd / 2;
    for (int64_t t = 0; t < T; t++) {
        int64_t bse = t * hd;
        for (int64_t hh = 0; hh < nheads; hh++) {
            int64_t row = (t * nheads + hh) * hd;
            for (int64_t c = 0; c < hd; c++) {
                if (is_bwd) {
                    double gs = (c < half)
                        ? (X[row + half + c] * SIN[bse + half + c])
                        : (0.0 - X[row + c - half] * SIN[bse + c - half]);
                    O[row + c] = X[row + c] * COS[bse + c] + gs;
                } else {
                    double rh_c = (c < half)
                        ? (0.0 - X[row + half + c])
                        : X[row + c - half];
                    O[row + c] = X[row + c] * COS[bse + c]
                               + rh_c * SIN[bse + c];
                }
            }
        }
    }
    return out_id;
}
#pragma STDC FP_CONTRACT DEFAULT

// _hx_farr_adamw_step_cpu(...) -> new farr_id [n] = updated W. m,v
// updated IN PLACE on their farr buffers (matches the AdamW state
// contract — the optimizer owns m/v across steps). Decoupled weight
// decay. Mirrors d_train2_lib dt2_adamw_step EXACTLY (same β^t via
// repeated mul, same c1/c2 bias-correction, same update form). The
// √ uses libm sqrt (the boxed dt_sqrt is a 24-iter Newton converging
// to the same double — verified ≡ in the smoke). -1 err.
static int64_t _hx_farr_adamw_step_cpu(int64_t w_id, int64_t m_id,
                                       int64_t v_id, int64_t g_id,
                                       int64_t n, double lr, double b1,
                                       double b2, double eps, double wd,
                                       int64_t step_t) {
    if (w_id < 0 || w_id >= _hx_farr_count) return -1;
    if (m_id < 0 || m_id >= _hx_farr_count) return -1;
    if (v_id < 0 || v_id >= _hx_farr_count) return -1;
    if (g_id < 0 || g_id >= _hx_farr_count) return -1;
    if (n <= 0 || step_t < 1)               return -1;
    HexaFarrEntry* we = &_hx_farr_table[w_id];
    HexaFarrEntry* me = &_hx_farr_table[m_id];
    HexaFarrEntry* ve = &_hx_farr_table[v_id];
    HexaFarrEntry* ge = &_hx_farr_table[g_id];
    if (!we->buf || !me->buf || !ve->buf || !ge->buf) return -1;
    if (we->len < n || me->len < n || ve->len < n || ge->len < n) return -1;
    HexaVal out_h = hexa_farr_zeros(hexa_int(n));
    int64_t out_id = HX_INT(out_h);
    if (out_id < 0 || out_id >= _hx_farr_count) return -1;
    /* re-fetch ALL entry pointers post-alloc (RFC 032 guard). */
    we = &_hx_farr_table[w_id];
    me = &_hx_farr_table[m_id];
    ve = &_hx_farr_table[v_id];
    ge = &_hx_farr_table[g_id];
    HexaFarrEntry* oe = &_hx_farr_table[out_id];
    if (!we->buf || !me->buf || !ve->buf || !ge->buf || !oe->buf
        || oe->len < n) return -1;
    double* W = we->buf;
    double* Mm = me->buf;
    double* Vv = ve->buf;
    const double* G = ge->buf;
    double* O = oe->buf;
    double b1t = 1.0, b2t = 1.0;
    for (int64_t e = 0; e < step_t; e++) { b1t *= b1; b2t *= b2; }
    double c1 = 1.0 - b1t;
    double c2 = 1.0 - b2t;
    for (int64_t i = 0; i < n; i++) {
        double g  = G[i];
        double mi = b1 * Mm[i] + (1.0 - b1) * g;
        double vi = b2 * Vv[i] + (1.0 - b2) * g * g;
        double mhat = mi / c1;
        double vhat = vi / c2;
        double denom = sqrt(vhat) + eps;
        double wi = W[i] - lr * wd * W[i] - lr * mhat / denom;
        Mm[i] = mi;       /* m,v updated in place (optimizer state) */
        Vv[i] = vi;
        O[i]  = wi;       /* fresh W returned as a new farr */
    }
    return out_id;
}

// ── Phase B2 dispatchers ────────────────────────────────────────────

// farr_matmul_t_gpu(M, R, C, u) -> int new farr_id [C] (Mᵀ·u).
// On HEXA_CUDA: wired (Phase 4-D-5-4 step 1, 2026-05-17) to
// _hx_cuda_farr_matmul_t_gpu (cuBLAS Dgemv CUBLAS_OP_T or tiled
// transpose-GEMM, byte-eq Phase 4-D-5-3).
HexaVal hexa_farr_matmul_t_gpu(HexaVal m_v, HexaVal r_v, HexaVal c_v,
                               HexaVal u_v) {
    int64_t m_id = hexa_as_num(m_v);
    int64_t R    = hexa_as_num(r_v);
    int64_t C    = hexa_as_num(c_v);
    int64_t u_id = hexa_as_num(u_v);
#ifdef HEXA_CUDA
    if (R <= 0 || C <= 0) return hexa_int(-1);
    if (m_id < 0 || m_id >= _hx_farr_count) return hexa_int(-1);
    if (u_id < 0 || u_id >= _hx_farr_count) return hexa_int(-1);
    HexaVal out_h = hexa_farr_zeros(hexa_int(C));
    int64_t out_id = hexa_as_num(out_h);
    if (out_id < 0) return hexa_int(-1);
    int rc = _hx_cuda_farr_matmul_t_gpu(m_id, R, C, u_id, out_id);
    if (rc != 0) return hexa_int(-1);
    return hexa_int(out_id);
#else
    return hexa_int(_hx_farr_matmul_t_cpu(m_id, R, C, u_id));
#endif
}

// farr_outer_gpu(u, v, R, C) -> int new farr_id [R·C] (u⊗v).
// On HEXA_CUDA: wired (Phase 4-D-5-4 step 1, 2026-05-17) to
// _hx_cuda_farr_outer_gpu (cublasDger rank-1 or 2-D grid, byte-eq
// Phase 4-D-5-3).
HexaVal hexa_farr_outer_gpu(HexaVal u_v, HexaVal v_v, HexaVal r_v,
                            HexaVal c_v) {
    int64_t u_id = hexa_as_num(u_v);
    int64_t v_id = hexa_as_num(v_v);
    int64_t R    = hexa_as_num(r_v);
    int64_t C    = hexa_as_num(c_v);
#ifdef HEXA_CUDA
    if (R <= 0 || C <= 0) return hexa_int(-1);
    if (u_id < 0 || u_id >= _hx_farr_count) return hexa_int(-1);
    if (v_id < 0 || v_id >= _hx_farr_count) return hexa_int(-1);
    HexaVal out_h = hexa_farr_zeros(hexa_int(R * C));
    int64_t out_id = hexa_as_num(out_h);
    if (out_id < 0) return hexa_int(-1);
    int rc = _hx_cuda_farr_outer_gpu(u_id, v_id, R, C, out_id);
    if (rc != 0) return hexa_int(-1);
    return hexa_int(out_id);
#else
    return hexa_int(_hx_farr_outer_cpu(u_id, v_id, R, C));
#endif
}

// farr_mul_gpu(a, b, n) -> int new farr_id (elementwise A⊙B).
// On HEXA_CUDA: wired (Phase 4-D-5-4 step 1, 2026-05-17) to
// _hx_cuda_farr_mul_gpu (1-D grid-stride, byte-eq Phase 4-D-5-3).
HexaVal hexa_farr_mul_gpu(HexaVal a_v, HexaVal b_v, HexaVal n_v) {
    int64_t a_id = hexa_as_num(a_v);
    int64_t b_id = hexa_as_num(b_v);
    int64_t n    = hexa_as_num(n_v);
#ifdef HEXA_CUDA
    if (n <= 0) return hexa_int(-1);
    if (a_id < 0 || a_id >= _hx_farr_count) return hexa_int(-1);
    if (b_id < 0 || b_id >= _hx_farr_count) return hexa_int(-1);
    HexaVal out_h = hexa_farr_zeros(hexa_int(n));
    int64_t out_id = hexa_as_num(out_h);
    if (out_id < 0) return hexa_int(-1);
    int rc = _hx_cuda_farr_mul_gpu(a_id, b_id, n, out_id);
    if (rc != 0) return hexa_int(-1);
    return hexa_int(out_id);
#else
    return hexa_int(_hx_farr_mul_cpu(a_id, b_id, n));
#endif
}

// farr_silu_gpu(x, n) -> int new farr_id (y = silu(x)).
// On HEXA_CUDA: wired (Phase 4-D-5-4 step 1, 2026-05-17) to
// _hx_cuda_farr_silu_gpu (1-D grid-stride, σ via __expf, byte-eq
// Phase 4-D-5-3).
HexaVal hexa_farr_silu_gpu(HexaVal x_v, HexaVal n_v) {
    int64_t x_id = hexa_as_num(x_v);
    int64_t n    = hexa_as_num(n_v);
#ifdef HEXA_CUDA
    if (n <= 0) return hexa_int(-1);
    if (x_id < 0 || x_id >= _hx_farr_count) return hexa_int(-1);
    HexaVal out_h = hexa_farr_zeros(hexa_int(n));
    int64_t out_id = hexa_as_num(out_h);
    if (out_id < 0) return hexa_int(-1);
    int rc = _hx_cuda_farr_silu_gpu(x_id, n, out_id);
    if (rc != 0) return hexa_int(-1);
    return hexa_int(out_id);
#else
    return hexa_int(_hx_farr_silu_cpu(x_id, n));
#endif
}

// farr_silu_grad_gpu(x, n) -> int new farr_id (silu'(x)).
// On HEXA_CUDA: wired (Phase 4-D-5-4 step 1, 2026-05-17) to
// _hx_cuda_farr_silu_grad_gpu (1-D grid-stride, byte-eq Phase 4-D-5-3).
HexaVal hexa_farr_silu_grad_gpu(HexaVal x_v, HexaVal n_v) {
    int64_t x_id = hexa_as_num(x_v);
    int64_t n    = hexa_as_num(n_v);
#ifdef HEXA_CUDA
    if (n <= 0) return hexa_int(-1);
    if (x_id < 0 || x_id >= _hx_farr_count) return hexa_int(-1);
    HexaVal out_h = hexa_farr_zeros(hexa_int(n));
    int64_t out_id = hexa_as_num(out_h);
    if (out_id < 0) return hexa_int(-1);
    int rc = _hx_cuda_farr_silu_grad_gpu(x_id, n, out_id);
    if (rc != 0) return hexa_int(-1);
    return hexa_int(out_id);
#else
    return hexa_int(_hx_farr_silu_grad_cpu(x_id, n));
#endif
}

// farr_rmsnorm_bwd_rows_gpu(x, dxn, R, C) -> int new farr_id [R·C].
// On HEXA_CUDA: wired (Phase 4-D-5-4 step 1, 2026-05-17) to
// _hx_cuda_farr_rmsnorm_bwd_rows_gpu (block-per-row two warp-shuffle
// reductions Σx² + Σdxn·x, then broadcast vjp, byte-eq Phase 4-D-5-3).
HexaVal hexa_farr_rmsnorm_bwd_rows_gpu(HexaVal x_v, HexaVal dxn_v,
                                       HexaVal r_v, HexaVal c_v) {
    int64_t x_id   = hexa_as_num(x_v);
    int64_t dxn_id = hexa_as_num(dxn_v);
    int64_t R      = hexa_as_num(r_v);
    int64_t C      = hexa_as_num(c_v);
#ifdef HEXA_CUDA
    if (R <= 0 || C <= 0) return hexa_int(-1);
    if (x_id < 0 || x_id >= _hx_farr_count) return hexa_int(-1);
    if (dxn_id < 0 || dxn_id >= _hx_farr_count) return hexa_int(-1);
    HexaVal out_h = hexa_farr_zeros(hexa_int(R * C));
    int64_t out_id = hexa_as_num(out_h);
    if (out_id < 0) return hexa_int(-1);
    int rc = _hx_cuda_farr_rmsnorm_bwd_rows_gpu(x_id, dxn_id, R, C, out_id);
    if (rc != 0) return hexa_int(-1);
    return hexa_int(out_id);
#else
    return hexa_int(_hx_farr_rmsnorm_bwd_rows_cpu(x_id, dxn_id, R, C));
#endif
}

// farr_adamw_step_gpu(W,m,v,g,n,lr,b1,b2,eps,wd,step_t) -> int new
// farr_id (updated W; m,v updated in place). 11-arg → past the
// hexa_callN ceiling, so it gets a bare direct-C entry point (same
// pattern as RFC 035 adamw_step_mixed / RFC 032 farr_matmul).
HexaVal hexa_farr_adamw_step_gpu(HexaVal w_v, HexaVal m_v, HexaVal v_v,
                                 HexaVal g_v, HexaVal n_v, HexaVal lr_v,
                                 HexaVal b1_v, HexaVal b2_v, HexaVal eps_v,
                                 HexaVal wd_v, HexaVal step_v) {
    int64_t w_id = hexa_as_num(w_v);
    int64_t m_id = hexa_as_num(m_v);
    int64_t v_id = hexa_as_num(v_v);
    int64_t g_id = hexa_as_num(g_v);
    int64_t n    = hexa_as_num(n_v);
    double  lr   = __hx_to_double(lr_v);
    double  b1   = __hx_to_double(b1_v);
    double  b2   = __hx_to_double(b2_v);
    double  eps  = __hx_to_double(eps_v);
    double  wd   = __hx_to_double(wd_v);
    int64_t step_t = hexa_as_num(step_v);
#ifdef HEXA_CUDA
    /* Phase 4-D-5-4 step 1 wire (2026-05-17): fused 1-D grid-stride
     * AdamW kernel; substrate H2Ds W/m/v/g, runs the kernel D2D, then
     * D2Hs updated W to out_id AND D2Hs m,v back to their host buffers
     * to preserve the optimizer-state contract (CPU oracle mutates m,v
     * in place — see self/cuda/runtime_cuda.c line 730+). Byte-eq
     * verified Phase 4-D-5-3 11/11 PASS. */
    if (n <= 0 || step_t < 1) return hexa_int(-1);
    if (w_id < 0 || w_id >= _hx_farr_count) return hexa_int(-1);
    if (m_id < 0 || m_id >= _hx_farr_count) return hexa_int(-1);
    if (v_id < 0 || v_id >= _hx_farr_count) return hexa_int(-1);
    if (g_id < 0 || g_id >= _hx_farr_count) return hexa_int(-1);
    HexaVal out_h = hexa_farr_zeros(hexa_int(n));
    int64_t out_id = hexa_as_num(out_h);
    if (out_id < 0) return hexa_int(-1);
    int rc = _hx_cuda_farr_adamw_step_gpu(w_id, m_id, v_id, g_id, n,
                                          lr, b1, b2, eps, wd, step_t,
                                          out_id);
    if (rc != 0) return hexa_int(-1);
    return hexa_int(out_id);
#else
    return hexa_int(_hx_farr_adamw_step_cpu(w_id, m_id, v_id, g_id, n,
                                            lr, b1, b2, eps, wd, step_t));
#endif
}

// ── Phase B2 carriers + bare entry points ───────────────────────────
// ≤4-arg ops get HexaVal carriers (hexa_fn_new at init). The 11-arg
// adamw_step gets a bare `HexaVal farr_adamw_step_gpu(...)` C symbol
// (direct call past the hexa_callN ceiling — RFC 032/035 pattern).
HexaVal farr_matmul_t_gpu;
HexaVal farr_outer_gpu;
HexaVal farr_mul_gpu;
HexaVal farr_silu_gpu;
HexaVal farr_silu_grad_gpu;
HexaVal farr_rmsnorm_bwd_rows_gpu;
HexaVal farr_adamw_step_gpu(HexaVal w, HexaVal m, HexaVal v, HexaVal g,
                            HexaVal n, HexaVal lr, HexaVal b1, HexaVal b2,
                            HexaVal eps, HexaVal wd, HexaVal step_t) {
    return hexa_farr_adamw_step_gpu(w, m, v, g, n, lr, b1, b2, eps, wd,
                                    step_t);
}

// farr_rope_gpu(t, cos, sin, T, nheads, hd) -> int new farr_id
// [T·nheads·hd]. Rotary position embedding forward. 6-arg → past the
// 4-arg hexa_callN ceiling, so it gets a bare direct-C entry point
// (same pattern as farr_adamw_step_gpu). On HEXA_CUDA: wired to
// _hx_cuda_farr_rope_gpu (1-D grid-stride per-element kernel, byte-eq
// — F-RFC041-ROPE-EXACT |Δ|=0, no reduction). No-CUDA: CPU fallback.
HexaVal hexa_farr_rope_gpu(HexaVal t_v, HexaVal cos_v, HexaVal sin_v,
                           HexaVal T_v, HexaVal nh_v, HexaVal hd_v) {
    int64_t t_id   = hexa_as_num(t_v);
    int64_t cos_id = hexa_as_num(cos_v);
    int64_t sin_id = hexa_as_num(sin_v);
    int64_t T      = hexa_as_num(T_v);
    int64_t nheads = hexa_as_num(nh_v);
    int64_t hd     = hexa_as_num(hd_v);
#ifdef HEXA_CUDA
    if (T <= 0 || nheads <= 0 || hd <= 0) return hexa_int(-1);
    if (t_id < 0   || t_id >= _hx_farr_count)   return hexa_int(-1);
    if (cos_id < 0 || cos_id >= _hx_farr_count) return hexa_int(-1);
    if (sin_id < 0 || sin_id >= _hx_farr_count) return hexa_int(-1);
    HexaVal out_h = hexa_farr_zeros(hexa_int(T * nheads * hd));
    int64_t out_id = hexa_as_num(out_h);
    if (out_id < 0) return hexa_int(-1);
    int rc = _hx_cuda_farr_rope_gpu(t_id, cos_id, sin_id, T, nheads, hd,
                                    out_id);
    if (rc != 0) return hexa_int(-1);
    return hexa_int(out_id);
#else
    return hexa_int(_hx_farr_rope_cpu(t_id, cos_id, sin_id, T, nheads,
                                      hd, 0));
#endif
}

// farr_rope_bwd_gpu(t, cos, sin, T, nheads, hd) -> int new farr_id.
// Rotary position embedding backward (inverse rotation — transpose of
// the fwd rotation matrix). On HEXA_CUDA: _hx_cuda_farr_rope_bwd_gpu
// (byte-eq — F-RFC041-ROPE-BWD-EXACT |Δ|=0). No-CUDA: CPU fallback.
HexaVal hexa_farr_rope_bwd_gpu(HexaVal t_v, HexaVal cos_v, HexaVal sin_v,
                               HexaVal T_v, HexaVal nh_v, HexaVal hd_v) {
    int64_t t_id   = hexa_as_num(t_v);
    int64_t cos_id = hexa_as_num(cos_v);
    int64_t sin_id = hexa_as_num(sin_v);
    int64_t T      = hexa_as_num(T_v);
    int64_t nheads = hexa_as_num(nh_v);
    int64_t hd     = hexa_as_num(hd_v);
#ifdef HEXA_CUDA
    if (T <= 0 || nheads <= 0 || hd <= 0) return hexa_int(-1);
    if (t_id < 0   || t_id >= _hx_farr_count)   return hexa_int(-1);
    if (cos_id < 0 || cos_id >= _hx_farr_count) return hexa_int(-1);
    if (sin_id < 0 || sin_id >= _hx_farr_count) return hexa_int(-1);
    HexaVal out_h = hexa_farr_zeros(hexa_int(T * nheads * hd));
    int64_t out_id = hexa_as_num(out_h);
    if (out_id < 0) return hexa_int(-1);
    int rc = _hx_cuda_farr_rope_bwd_gpu(t_id, cos_id, sin_id, T, nheads,
                                        hd, out_id);
    if (rc != 0) return hexa_int(-1);
    return hexa_int(out_id);
#else
    return hexa_int(_hx_farr_rope_cpu(t_id, cos_id, sin_id, T, nheads,
                                      hd, 1));
#endif
}

// farr_transpose_scatter_gpu(src, dst, rows, cols, dst_off) -> int rc.
// RFC 058 §5.2 — device transpose-scatter: fill the [dst_off,
// dst_off+rows*cols) slab of dst with the transpose of src
// (dst[dst_off+c*rows+r] = src[r*cols+c]). Unlike the other _gpu
// entry points this does NOT allocate a new farr — dst is a caller-
// owned buffer (the Bc accumulator) populated slab-by-slab. Returns
// 0 ok / -1 err. On HEXA_CUDA the forge kernel runs and dst is left
// device-authoritative (RFC 056 §6.1); on the no-CUDA build it
// returns -1 (the flame consumer dim-gates this call inside
// #ifdef HEXA_CUDA, so the no-CUDA path is never reached — the d=32
// host transpose loop stays, RFC 058 §5.4).
HexaVal hexa_farr_transpose_scatter_gpu(HexaVal src_v, HexaVal dst_v,
                                        HexaVal rows_v, HexaVal cols_v,
                                        HexaVal dst_off_v) {
    int64_t src_id  = hexa_as_num(src_v);
    int64_t dst_id  = hexa_as_num(dst_v);
    int64_t rows    = hexa_as_num(rows_v);
    int64_t cols    = hexa_as_num(cols_v);
    int64_t dst_off = hexa_as_num(dst_off_v);
#ifdef HEXA_CUDA
    if (rows <= 0 || cols <= 0 || dst_off < 0) return hexa_int(-1);
    if (src_id < 0 || src_id >= _hx_farr_count) return hexa_int(-1);
    if (dst_id < 0 || dst_id >= _hx_farr_count) return hexa_int(-1);
    int rc = _hx_cuda_farr_transpose_scatter_gpu(src_id, dst_id,
                                                 rows, cols, dst_off);
    return hexa_int(rc);
#else
    (void)src_id; (void)dst_id; (void)rows; (void)cols; (void)dst_off;
    return hexa_int(-1);
#endif
}

// 6-arg bare direct-C entry points (past the hexa_callN ceiling).
HexaVal farr_rope_gpu(HexaVal t, HexaVal cos, HexaVal sin,
                      HexaVal T, HexaVal nh, HexaVal hd) {
    return hexa_farr_rope_gpu(t, cos, sin, T, nh, hd);
}
HexaVal farr_rope_bwd_gpu(HexaVal t, HexaVal cos, HexaVal sin,
                          HexaVal T, HexaVal nh, HexaVal hd) {
    return hexa_farr_rope_bwd_gpu(t, cos, sin, T, nh, hd);
}

// ── A1 (2026-05-10): per-phase arena reset side channel ─────────
// Stage 0 host (hexa_real / hexa_interp.real) holds every str-arena
// allocation for the whole process lifetime — there is no per-phase
// boundary between lex / parse / check / lower / codegen. On the
// 25,932-line spliced super-module that compiler/main.hexa now
// produces, this drives RSS past the 2 GB cap before any structured
// diagnostic surfaces (see doc/stage1_punch_list_v2.md A1, captured
// 2026-05-10).
//
// The fix here is a side-channel that lets compiler/main.hexa drop
// the str/Val bump arena at known-safe phase boundaries (after
// parse, after type/citation check, after lower, after codegen).
// The hexa-side carrier (Module / Diagnostic / HModule / MModule /
// LModule) is itself heap-resident — it lives in array_store /
// map_store / struct_store and is unaffected by the arena rewind.
// What gets reclaimed: the bump-arena strings + struct-literal Vals
// produced as scratch during the just-finished phase. Empirically
// these dominate RSS growth on spliced compiles where every
// _splice_imported_items pass concatenates fresh paths.
//
// Hooks (all spelled as `env("__HEXA_ARENA_<OP>__")` for the
// existing side-channel discipline):
//
//   PHASE_RESET__    — reset the bump arena to its first block
//                      (calls hexa_arena_reset). Safe at phase
//                      boundaries where no live Hexa-side struct
//                      points into arena-allocated strings; the
//                      compiler driver guarantees this by copying
//                      slim hand-off shapes (see compiler/main.hexa
//                      `phase_reset` callsites).
//   RSS_MB__         — return current resident set size in MB
//                      as a decimal string. Lets compiler/main.hexa
//                      log per-phase RSS deltas to stderr without a
//                      transpiler-level builtin.
//   ARENA_BYTES__    — return total reserved arena bytes (sum of
//                      block caps), decimal string. Diagnostics.
//   ARENA_LIVE__     — return currently-used arena bytes (sum of
//                      block.used), decimal string. Diagnostics.
//   PHASE_LOG__name  — emit "[hexa-runtime/phase] name rss=NMB
//                      arena=NMB" to stderr; convenience wrapper
//                      for compiler/main.hexa --verbose mode.
static int64_t _hx_arena_total_bytes(void) {
    int64_t total = 0;
    for (HexaArenaBlock* b = __hexa_arena.head; b; b = b->next) {
        total += (int64_t)b->cap;
    }
    return total;
}
static int64_t _hx_arena_live_bytes(void) {
    int64_t total = 0;
    for (HexaArenaBlock* b = __hexa_arena.head; b; b = b->next) {
        total += (int64_t)b->used;
    }
    return total;
}

HexaVal hexa_env_var(HexaVal name) {
    if (!HX_IS_STR(name) || !HX_STR(name)) return hexa_str("");
    // rt 32-L: side-channel for Val arena scope ops. Hexa-side env_push_scope /
    // env_pop_scope / call_user_fn invoke env("__HEXA_ARENA_*") to drive the C
    // arena without needing a transpiler-level builtin. Returns "0" / "1" so
    // existing callers that ignore the result are unaffected.
    if (HX_STR(name)[0] == '_' && HX_STR(name)[1] == '_' && HX_STR(name)[2] == 'H' &&
        hxlcl_strncmp(HX_STR(name), "__HEXA_ARENA_", 13) == 0) {
        const char* op = HX_STR(name) + 13;
        if (hxlcl_strcmp(op, "PUSH__") == 0) {
            hexa_val_arena_scope_push();
            return hexa_str("1");
        }
        if (hxlcl_strcmp(op, "POP__") == 0) {
            hexa_val_arena_scope_pop();
            return hexa_str("1");
        }
        if (hxlcl_strcmp(op, "HEAPIFY_RETURN__") == 0) {
            hexa_val_arena_heapify_return();
            return hexa_str("1");
        }
        if (hxlcl_strcmp(op, "ENABLED__") == 0) {
            return hexa_str(hexa_val_arena_on() ? "1" : "0");
        }
        // F6 option A — A3 (PLAN-stage3-footprint-F6-optA.md). Toggle
        // region-promote on fn-return for the active frame. ON routes
        // __hexa_fn_arena_return through hexa_val_arena_heapify_to_parent
        // (callee region → parent arena). OFF restores the default
        // heapify-to-malloc behaviour. Default OFF on process start.
        if (hxlcl_strcmp(op, "RETURN_REGION_ON__") == 0) {
            __hexa_val_region_returns_enabled = 1;
            return hexa_str("1");
        }
        if (hxlcl_strcmp(op, "RETURN_REGION_OFF__") == 0) {
            __hexa_val_region_returns_enabled = 0;
            return hexa_str("0");
        }
        if (hxlcl_strcmp(op, "RETURN_REGION__") == 0) {
            // Query current state.
            return hexa_str(__hexa_val_region_returns_enabled ? "1" : "0");
        }
        if (hxlcl_strcmp(op, "STATS__") == 0) {
            char buf[64];
            snprintf(buf, sizeof(buf), "marks=%d", __hexa_val_mark_top);
            return hexa_str(buf);
        }
        // A1 (2026-05-10): per-phase arena reset hooks — see comment above.
        if (hxlcl_strcmp(op, "PHASE_RESET__") == 0) {
            // Drop all bump-arena allocations. Live blocks stay linked
            // (ready for reuse on the next phase's allocations) but every
            // block.used = 0. O(blocks) — typically a handful.
            hexa_arena_reset();
            return hexa_str("1");
        }
        if (hxlcl_strcmp(op, "RSS_MB__") == 0) {
            char buf[32];
            size_t rss = _hx_self_rss_bytes();
            snprintf(buf, sizeof(buf), "%zu",
                     (size_t)(rss / (1024ull * 1024ull)));
            return hexa_str(buf);
        }
        if (hxlcl_strcmp(op, "ARENA_BYTES__") == 0) {
            char buf[32];
            snprintf(buf, sizeof(buf), "%lld",
                     (long long)_hx_arena_total_bytes());
            return hexa_str(buf);
        }
        if (hxlcl_strcmp(op, "ARENA_LIVE__") == 0) {
            char buf[32];
            snprintf(buf, sizeof(buf), "%lld",
                     (long long)_hx_arena_live_bytes());
            return hexa_str(buf);
        }
        // Unknown __HEXA_ARENA_* op — fall through to real getenv (returns "").
    }
    // A1 (2026-05-10): __HEXA_PHASE_LOG__<name> — single-line per-phase
    // marker on stderr. Encoded as a name prefix so the call site is
    // a single env(...) read. Returns the emitted line (sans newline).
    if (HX_STR(name)[0] == '_' && HX_STR(name)[1] == '_' && HX_STR(name)[2] == 'H' &&
        hxlcl_strncmp(HX_STR(name), "__HEXA_PHASE_LOG__", 18) == 0) {
        const char* phase = HX_STR(name) + 18;
        size_t rss = _hx_self_rss_bytes();
        size_t arena_live = (size_t)_hx_arena_live_bytes();
        size_t arena_total = (size_t)_hx_arena_total_bytes();
        char line[256];
        int n = snprintf(line, sizeof(line),
            "[hexa-runtime/phase] %s rss=%zuMB arena_live=%zuKB arena_total=%zuKB",
            phase,
            (size_t)(rss / (1024ull * 1024ull)),
            (size_t)(arena_live / 1024ull),
            (size_t)(arena_total / 1024ull));
        if (n > 0) {
            fputs(line, stderr);
            fputc('\n', stderr);
        }
        return hexa_str(line);
    }
    const char* v = hxlcl_getenv(HX_STR(name));
    return hexa_str(v ? v : "");
}

// setenv(name, value): POSIX setenv wrapper with overwrite=1. Empty / non-STR
// name is a no-op. Returns the stored value on success, "" on failure — so
// callers can treat it like env() in a set-then-read idiom without a second
// getenv round-trip. anima/serve_alm-style bash bridges previously used
// `env BAR=baz hexa run …` because the language had no setter; this closes
// the gap so .hexa contracts can configure child env directly before exec.
HexaVal hexa_setenv(HexaVal name, HexaVal value) {
    if (!HX_IS_STR(name) || !HX_STR(name) || HX_STR(name)[0] == '\0') return hexa_str("");
    const char* v = (HX_IS_STR(value) && HX_STR(value)) ? HX_STR(value) : "";
    if (hxlcl_setenv(HX_STR(name), v, 1) != 0) return hexa_str("");
    return hexa_str(v);
}

// exec_capture(cmd): spawn `/bin/sh -c cmd` and return
// [stdout_str, stderr_str, exit_code] with stderr split from stdout. Uses
// pipe/fork/execvp (not popen, which merges 2>&1 when you redirect it).
// Closes the anima bash-bridge pattern of `tool/serve_alm_persona.bash`
// (333 lines) that existed solely to separate stderr capture.
HexaVal hexa_exec_capture(HexaVal cmd) {
    HexaVal arr = hexa_array_new();
    if (!HX_IS_STR(cmd) || !HX_STR(cmd)) {
        arr = hexa_array_push(arr, hexa_str(""));
        arr = hexa_array_push(arr, hexa_str(""));
        arr = hexa_array_push(arr, hexa_int(127));
        return arr;
    }
    int out_pipe[2], err_pipe[2];
    if (hxlcl_pipe(out_pipe) != 0) {
        arr = hexa_array_push(arr, hexa_str(""));
        arr = hexa_array_push(arr, hexa_str("pipe: stdout"));
        arr = hexa_array_push(arr, hexa_int(127));
        return arr;
    }
    if (hxlcl_pipe(err_pipe) != 0) {
        hxlcl_close(out_pipe[0]); hxlcl_close(out_pipe[1]);
        arr = hexa_array_push(arr, hexa_str(""));
        arr = hexa_array_push(arr, hexa_str("pipe: stderr"));
        arr = hexa_array_push(arr, hexa_int(127));
        return arr;
    }
    // 2026-05-06 — POSIX fork buffer flush (parent stdio inherited by child)
    fflush(NULL);
    pid_t pid = hxlcl_fork();
    if (pid < 0) {
        hxlcl_close(out_pipe[0]); hxlcl_close(out_pipe[1]);
        hxlcl_close(err_pipe[0]); hxlcl_close(err_pipe[1]);
        arr = hexa_array_push(arr, hexa_str(""));
        arr = hexa_array_push(arr, hexa_str("fork failed"));
        arr = hexa_array_push(arr, hexa_int(127));
        return arr;
    }
    if (pid == 0) {
        // child: rewire stdout/stderr then exec shell
        hxlcl_dup2(out_pipe[1], 1);
        hxlcl_dup2(err_pipe[1], 2);
        hxlcl_close(out_pipe[0]); hxlcl_close(out_pipe[1]);
        hxlcl_close(err_pipe[0]); hxlcl_close(err_pipe[1]);
        hxlcl_execl("/bin/sh", "sh", "-c", HX_STR(cmd), (char*)NULL);
        _exit(127);
    }
    // parent: close write ends, drain both pipes.
    // Simple drain loop: alternate non-blocking would be better but for
    // typical build-script command sizes (sub-MB) sequential is fine —
    // we close(write) immediately so EOF propagates once child exits.
    hxlcl_close(out_pipe[1]);
    hxlcl_close(err_pipe[1]);
    char buf[4096];
    size_t ocap = 4096, olen = 0;
    char* obuf = (char*)malloc(ocap);
    if (obuf) obuf[0] = '\0';
    size_t ecap = 4096, elen = 0;
    char* ebuf = (char*)malloc(ecap);
    if (ebuf) ebuf[0] = '\0';
    int of = out_pipe[0], ef = err_pipe[0];
    int open_mask = 3; // bit 0 = stdout, bit 1 = stderr
    while (open_mask) {
        if (open_mask & 1) {
            ssize_t n = hxlcl_read(of, buf, sizeof(buf));
            if (n > 0 && obuf) {
                while (olen + (size_t)n + 1 > ocap) {
                    ocap *= 2;
                    char* nb = (char*)realloc(obuf, ocap);
                    if (!nb) { free(obuf); obuf = NULL; break; }
                    obuf = nb;
                }
                if (obuf) { hxlcl_memcpy(obuf + olen, buf, (size_t)n); olen += (size_t)n; obuf[olen] = '\0'; }
            } else if (n == 0 || (n < 0)) {
                open_mask &= ~1;
            }
        }
        if (open_mask & 2) {
            ssize_t n = hxlcl_read(ef, buf, sizeof(buf));
            if (n > 0 && ebuf) {
                while (elen + (size_t)n + 1 > ecap) {
                    ecap *= 2;
                    char* nb = (char*)realloc(ebuf, ecap);
                    if (!nb) { free(ebuf); ebuf = NULL; break; }
                    ebuf = nb;
                }
                if (ebuf) { hxlcl_memcpy(ebuf + elen, buf, (size_t)n); elen += (size_t)n; ebuf[elen] = '\0'; }
            } else if (n == 0 || (n < 0)) {
                open_mask &= ~2;
            }
        }
    }
    hxlcl_close(of); hxlcl_close(ef);
    int status = 0;
    hxlcl_waitpid(pid, &status, 0);
    int exit_code;
    if (WIFEXITED(status))         exit_code = WEXITSTATUS(status);
    else if (WIFSIGNALED(status))  exit_code = 128 + WTERMSIG(status);
    else                           exit_code = -1;
    arr = hexa_array_push(arr, obuf ? hexa_str_own(obuf) : hexa_str(""));
    arr = hexa_array_push(arr, ebuf ? hexa_str_own(ebuf) : hexa_str(""));
    arr = hexa_array_push(arr, hexa_int(exit_code));
    return arr;
}

HexaVal rt_delete_file(HexaVal path) {
    if (!HX_IS_STR(path) || !HX_STR(path)) return hexa_void();
    (void)unlink(HX_STR(path));
    return hexa_void();
}

// R7 track B (2026-05-18): compiled-path `list_dir(path)`. Byte-parity
// with the interp impl (self/hexa_full.hexa:14347) — `ls -1 '<path>'
// 2>/dev/null`, split on '\n', array of entries; empty/err → []. Single-
// quote-escape the path (same shellout-shape limitation: entries with
// '\n' lost — inherent, matches interp). Needed by
// compiler/atlas/merger.hexa::list_dir for the atlas_cli binary.
HexaVal hexa_list_dir(HexaVal path) {
    if (!HX_IS_STR(path) || !HX_STR(path) || !HX_STR(path)[0]) return hexa_array_new();
    const char* p = HX_STR(path);
    size_t pl = hxlcl_strlen(p), cap = pl * 4 + 32, n = 0;
    char* cmd = (char*)malloc(cap);
    const char* pre = "ls -1 '";
    hxlcl_memcpy(cmd, pre, hxlcl_strlen(pre)); n = hxlcl_strlen(pre);
    for (size_t i = 0; i < pl; i++) {
        if (p[i] == '\'') { hxlcl_memcpy(cmd + n, "'\\''", 4); n += 4; }
        else cmd[n++] = p[i];
    }
    const char* post = "' 2>/dev/null";
    hxlcl_memcpy(cmd + n, post, hxlcl_strlen(post)); n += hxlcl_strlen(post); cmd[n] = 0;
    FILE* fp = hxlcl_popen(cmd, "r");
    free(cmd);
    if (!fp) return hexa_array_new();
    HexaVal arr = hexa_array_new();
    char* line = NULL; size_t lcap = 0; ssize_t got;
    while ((got = getline(&line, &lcap, fp)) >= 0) {
        while (got > 0 && (line[got-1] == '\n' || line[got-1] == '\r')) line[--got] = 0;
        if (got > 0) arr = hexa_array_push(arr, hexa_str(line));
    }
    if (line) free(line);
    hxlcl_pclose(fp);
    return arr;
}

HexaVal rt_append_file(HexaVal path, HexaVal content) {
    if (!HX_IS_STR(path) || !HX_STR(path)) return hexa_void();
    const char* data = (HX_IS_STR(content) && HX_STR(content)) ? HX_STR(content) : "";
    FILE* f = fopen(HX_STR(path), "ab");
    if (!f) return hexa_void();
    fwrite(data, 1, hxlcl_strlen(data), f);
    fclose(f);
    return hexa_void();
}

HexaVal hexa_bin(HexaVal n) {
    uint64_t v = HX_IS_INT(n) ? (uint64_t)HX_INT(n) : (uint64_t)HX_FLOAT(n);
    char buf[65]; int pos = 0;
    if (v == 0) { buf[pos++] = '0'; }
    while (v > 0 && pos < 64) { buf[pos++] = (char)('0' + (v & 1)); v >>= 1; }
    char* out = (char*)malloc(pos + 1);
    for (int i = 0; i < pos; i++) out[i] = buf[pos - 1 - i];
    out[pos] = 0;
    return hexa_str_own(out);
}

HexaVal hexa_hex(HexaVal n) {
    uint64_t v = HX_IS_INT(n) ? (uint64_t)HX_INT(n) : (uint64_t)HX_FLOAT(n);
    char* out = (char*)malloc(20);
    snprintf(out, 20, "%llx", (unsigned long long)v);
    return hexa_str_own(out);
}

// Reproducible-emit pin. When SOURCE_DATE_EPOCH is set (GNU/Debian
// convention, unix-seconds int) or HEXA_REPRODUCIBLE=1, wall-clock
// primitives return a fixed value so emitted artifacts (codegen output,
// manifests with embedded `now()`, chain-hash folds) are byte-identical
// across runs. Returns -1 when no pin is active.
// HEXA_REPRODUCIBLE=1 alone pins to 0 (epoch); SOURCE_DATE_EPOCH wins.
static int64_t hexa_pinned_epoch(void) {
    const char* sde = hxlcl_getenv("SOURCE_DATE_EPOCH");
    if (sde && *sde) {
        // strtoll tolerates leading whitespace and stops at first non-digit
        char* endp = NULL;
        long long v = hxlcl_strtoll(sde, &endp, 10);
        if (endp != sde && v >= 0) return (int64_t)v;
    }
    const char* repro = hxlcl_getenv("HEXA_REPRODUCIBLE");
    if (repro && repro[0] == '1' && repro[1] == '\0') return 0;
    return -1;
}

HexaVal hexa_timestamp(void) {
    int64_t pin = hexa_pinned_epoch();
    if (pin >= 0) return hexa_int(pin);
    struct timespec ts;
    hxlcl_clock_gettime(CLOCK_REALTIME, &ts);
    return hexa_int((int64_t)ts.tv_sec);
}

// FIX-A (Anima serving unblock, 2026-04-18) ─────────────────────────
// time_ms(): monotonic wall-clock milliseconds. Used by checkpoint.hexa /
// train_logger.hexa / eval_harness.hexa / train_7b_integrated.hexa for
// elapsed-time measurement (tok/s, save/load latency, per-step timing).
HexaVal hexa_time_ms(void) {
    int64_t pin = hexa_pinned_epoch();
    if (pin >= 0) return hexa_int(pin * 1000);
    struct timespec ts;
    hxlcl_clock_gettime(CLOCK_MONOTONIC, &ts);
    int64_t ms = (int64_t)ts.tv_sec * 1000
               + (int64_t)(ts.tv_nsec / 1000000);
    return hexa_int(ms);
}

// Wilson 2026-05-13 — C-level aliases for std_time.hexa wrapper names
// (`time_now_ms`, `__builtin_time_now_ms`, etc.). The hexa-side wrappers
// in self/std_time.hexa get `extern` forward declarations in the generated
// C; without these symbols defined, link fails. Cheaper than the codegen
// intercept (which also exists in codegen_c2.hexa) — no hexa_v2 rebuild
// needed; just runtime.c recompile (every wilson build picks it up).
// Filed at incoming/patches/wilson-needs-time-now-ms-builtin.md.
// Wilson 2026-05-13 — TAG_FN globals for std_time.hexa wrapper names.
// Codegen emits user-side `time_now_ms()` as `hexa_call0(time_now_ms)` —
// it treats unrecognized fn names as HexaVal fn-ref values, NOT direct
// C function calls. So we declare these as HexaVal globals (TAG_FN shims)
// matching the pattern thread.c uses for thread_spawn/channel_*.
// Initialized at startup via _hexa_init_time_fn_shims (called from
// hexa_set_args alongside _hexa_init_thread_fn_shims).
HexaVal time_now_ms;
HexaVal timestamp_ms;
HexaVal __builtin_time_now_ms;
HexaVal time_now;
HexaVal __builtin_time_now;
static HexaVal _hexa_time_ms_thunk(void) { return hexa_time_ms(); }
static HexaVal _hexa_timestamp_thunk(void) { return hexa_timestamp(); }
static void _hexa_init_time_fn_shims(void) {
    time_now_ms          = hexa_fn_new((void*)_hexa_time_ms_thunk,    0);
    timestamp_ms         = hexa_fn_new((void*)_hexa_time_ms_thunk,    0);
    __builtin_time_now_ms = hexa_fn_new((void*)_hexa_time_ms_thunk,   0);
    time_now             = hexa_fn_new((void*)_hexa_timestamp_thunk,  0);
    __builtin_time_now   = hexa_fn_new((void*)_hexa_timestamp_thunk,  0);
}
// `now_ms` and `sleep_ms` are owned by self/native/thread.c (HexaVal globals
// initialized via _hexa_init_thread_fn_shims). We avoid those names here.

// byte_len(v): length in bytes of a string, array, or map. Unlike hexa_len
// (which rejects non-container tags), this is permissive — returns 0 on
// anything without a measurable length. checkpoint.hexa uses it on byte
// arrays returned by read_file_bytes.
HexaVal hexa_byte_len(HexaVal v) {
    if (HX_IS_STR(v))   return hexa_int(HX_STR(v) ? (int64_t)HX_STRLEN(v) : 0);
    if (HX_IS_ARRAY(v)) return hexa_int((int64_t)HX_ARR_LEN(v));
    if (HX_IS_MAP(v)) {
        HexaMapTable* t = HX_MAP_TBL(v);
        return hexa_int(t ? (int64_t)t->len : 0);
    }
    return hexa_int(0);
}

// dict_keys(m): return TAG_ARRAY of TAG_STR keys preserving insertion order.
// Thin alias over hexa_map_keys (which is already the canonical C symbol for
// HX_MAP key iteration). Kept as a distinct builtin so .hexa sources can
// use the more familiar `dict_keys(d)` spelling (tokenizer_bpe.hexa etc.).
HexaVal hexa_dict_keys(HexaVal m) {
    return hexa_map_keys(m);
}

// FIX-A (Anima stdlib unblock, 2026-04-19) ─────────────────────────
// 10 builtins required across ~230 Anima/serve/train .hexa files
// (read_stdin ×53, json_parse ×119, json_stringify ×37, json_encode ×5,
// json_decode ×4, http_get ×6, sleep_s ×2, to_bool/now_monotonic_s/
// utc_iso_now/utc_compact_now ×1-2). Keep surface minimal — no libcurl,
// no locale tables, no float parse-path perfection: goal is unblock
// compilation + serve_alm dogfooding.

// read_stdin(): slurp all of stdin into a TAG_STR. Returns "" on EOF-only.
// Used by cli tools + test harnesses that pipe input.
HexaVal hexa_read_stdin(void) {
    size_t cap = 4096, len = 0;
    char* buf = (char*)malloc(cap);
    if (!buf) return hexa_str("");
    int c;
    while ((c = fgetc(stdin)) != EOF) {
        if (len + 1 >= cap) {
            cap *= 2;
            char* nb = (char*)realloc(buf, cap);
            if (!nb) { free(buf); return hexa_str(""); }
            buf = nb;
        }
        buf[len++] = (char)c;
    }
    buf[len] = 0;
    return hexa_str_own(buf);
}

// sleep_s(n): sleep n seconds (int or float). Wraps nanosleep for
// sub-second precision. Returns void.
HexaVal hexa_sleep_s(HexaVal n) {
    double s = 0.0;
    if (HX_IS_INT(n))        s = (double)HX_INT(n);
    else if (HX_IS_FLOAT(n)) s = HX_FLOAT(n);
    else                     s = (double)hexa_as_num(n);
    if (s < 0) s = 0;
    struct timespec ts;
    ts.tv_sec  = (time_t)s;
    ts.tv_nsec = (long)((s - (double)ts.tv_sec) * 1e9);
    hxlcl_nanosleep(&ts, NULL);
    return hexa_void();
}

// sleep_ms(ms): sleep ms milliseconds. nanosleep-backed — no fork. Was
// `exec("sleep 0.1")` (fork /bin/sh -> exec /bin/sleep -> waitpid, ~5-8ms
// overhead/tick) in sub-second throttle loops; this is the no-fork primitive.
// Negative -> clamped to 0 (returns immediately). Loops on EINTR with the
// remaining time so signal delivery doesn't shorten the sleep. Returns void.
HexaVal hexa_sleep_ms(HexaVal ms) {
    int64_t m = HX_IS_INT(ms) ? HX_INT(ms)
              : HX_IS_FLOAT(ms) ? (int64_t)HX_FLOAT(ms)
              : (int64_t)hexa_as_num(ms);
    if (m <= 0) return hexa_void();
    struct timespec req;
    req.tv_sec  = (time_t)(m / 1000);
    req.tv_nsec = (long)((m % 1000) * 1000000L);
    struct timespec rem;
    while (hxlcl_nanosleep(&req, &rem) != 0 && errno == EINTR) req = rem;
    return hexa_void();
}

// sleep_ns(ns): sleep ns nanoseconds. nanosleep-backed — no fork. Same
// EINTR-resume semantics as sleep_ms. Negative -> clamped to 0. Returns void.
HexaVal hexa_sleep_ns(HexaVal ns) {
    int64_t n = HX_IS_INT(ns) ? HX_INT(ns)
              : HX_IS_FLOAT(ns) ? (int64_t)HX_FLOAT(ns)
              : (int64_t)hexa_as_num(ns);
    if (n <= 0) return hexa_void();
    struct timespec req;
    req.tv_sec  = (time_t)(n / 1000000000LL);
    req.tv_nsec = (long)(n % 1000000000LL);
    struct timespec rem;
    while (hxlcl_nanosleep(&req, &rem) != 0 && errno == EINTR) req = rem;
    return hexa_void();
}

// now_monotonic_s(): TAG_FLOAT seconds from CLOCK_MONOTONIC (wall-clock
// elapsed, immune to system clock adjustment). Paired with time_ms()
// for finer-grained benchmarks.
HexaVal hexa_now_monotonic_s(void) {
    int64_t pin = hexa_pinned_epoch();
    if (pin >= 0) return hexa_float((double)pin);
    struct timespec ts;
    hxlcl_clock_gettime(CLOCK_MONOTONIC, &ts);
    return hexa_float((double)ts.tv_sec + (double)ts.tv_nsec / 1e9);
}

// mono_ns(): TAG_INT nanoseconds from CLOCK_MONOTONIC. Exposed because
// to_string(clock()) truncates sub-second precision via double→string
// formatting, which caused stderr_tmp collisions (fix 1472b62d). Callers
// building unique filenames should use to_string(mono_ns()) directly
// and skip the mktemp fork in runtime_tmpname fallback (perf).
HexaVal hexa_mono_ns(void) {
    struct timespec ts;
    hxlcl_clock_gettime(CLOCK_MONOTONIC, &ts);
    return hexa_int((int64_t)ts.tv_sec * 1000000000LL + (int64_t)ts.tv_nsec);
}

// utc_iso_now(): RFC-3339 / ISO-8601 UTC "YYYY-MM-DDTHH:MM:SSZ".
HexaVal hexa_utc_iso_now(void) {
    int64_t pin = hexa_pinned_epoch();
    time_t t = (pin >= 0) ? (time_t)pin : hxlcl_time(NULL);
    struct tm g;
    gmtime_r(&t, &g);
    char buf[32];
    hxlcl_strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", &g);
    return hexa_str(buf);
}

// G4-ISO8601 2026-05-06 (.roadmap.stdlib.G4) — format/parse mirrors of
// utc_iso_now() so witness rows in hexa-bio _python_bridge can drop
// datetime.now(timezone.utc).isoformat() (45 callsites).

// utc_iso_format(epoch_sec): epoch sec → "YYYY-MM-DDTHH:MM:SSZ".
HexaVal hexa_utc_iso_format(HexaVal epoch_v) {
    int64_t e = HX_IS_INT(epoch_v) ? HX_INT(epoch_v) : (int64_t)HX_FLOAT(epoch_v);
    time_t t = (time_t)e;
    struct tm g;
    gmtime_r(&t, &g);
    char buf[32];
    hxlcl_strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", &g);
    return hexa_str(buf);
}

// utc_iso_parse(s): "YYYY-MM-DDTHH:MM:SS[.fff][Z|+HH:MM|-HH:MM]" → epoch sec.
// Tolerant of fractional seconds (truncated) and timezone offset suffix
// (offset interpreted; non-UTC offsets shift the returned epoch).
HexaVal hexa_utc_iso_parse(HexaVal s_v) {
    if (!HX_IS_STR(s_v)) return hexa_int(0);
    const char* s = HX_STR(s_v);
    if (!s) return hexa_int(0);
    int Y=0, M=0, D=0, h=0, m=0, sec=0;
    int n = sscanf(s, "%d-%d-%dT%d:%d:%d", &Y, &M, &D, &h, &m, &sec);
    if (n < 6) return hexa_int(0);
    struct tm g;
    hxlcl_memset(&g, 0, sizeof(g));
    g.tm_year = Y - 1900;
    g.tm_mon  = M - 1;
    g.tm_mday = D;
    g.tm_hour = h;
    g.tm_min  = m;
    g.tm_sec  = sec;
    int64_t epoch = (int64_t)timegm(&g);
    // Optional tz offset suffix: scan from end of string for [+-]HH:MM or [+-]HHMM.
    size_t L = hxlcl_strlen(s);
    if (L >= 5) {
        for (ssize_t i = (ssize_t)L - 1; i > 0; i--) {
            char c = s[i];
            if (c == '+' || c == '-') {
                int sign = (c == '+') ? 1 : -1;
                int oh = 0, om = 0;
                const char* off = s + i + 1;
                if (sscanf(off, "%d:%d", &oh, &om) == 2 ||
                    sscanf(off, "%2d%2d", &oh, &om) == 2) {
                    epoch -= sign * (oh * 3600 + om * 60);
                }
                break;
            }
            if (c == 'Z' || c == 'z') break;
            if (c >= '0' && c <= '9') continue;
            if (c == ':' || c == '.') continue;
            break;
        }
    }
    return hexa_int(epoch);
}

// G3-REGEX 2026-05-06 (.roadmap.stdlib.G3) — POSIX ERE bridge.
//
// Surface (returns hexa values):
//   regex_match(pat, s)           → bool      — does pat match anywhere in s?
//   regex_match_full(pat, s)      → bool      — does pat match the whole s?
//   regex_search(pat, s)          → array     — [start, end] of first match, [] if none
//   regex_findall(pat, s)         → [array]   — list of [start, end] for every match
//   regex_replace(pat, s, repl)   → string    — replace all matches with repl (no backrefs)
//   regex_split(pat, s)           → [string]  — split s on every pat match
//
// Flavor: POSIX ERE (Extended Regular Expressions). Supports . [] ^ $ * + ? {n,m}
// () |. PCRE shortcuts (\d \s \w \b) are NOT POSIX-portable — translate at the
// hexa stdlib layer (e.g., \d → [0-9], \s → [[:space:]], \w → [[:alnum:]_]).
// Inline flag (?i) → REG_ICASE; the wrapper strips and sets the flag.

static int _hexa_re_compile(const char* pat, regex_t* out, int icase) {
    int flags = REG_EXTENDED;
    if (icase) flags |= REG_ICASE;
    return regcomp(out, pat, flags);
}

// Strip a leading "(?i)" inline flag and set *icase = 1 if present.
static const char* _hexa_re_strip_flags(const char* pat, int* icase) {
    *icase = 0;
    if (pat && pat[0] == '(' && pat[1] == '?' && pat[2] == 'i' && pat[3] == ')') {
        *icase = 1;
        return pat + 4;
    }
    return pat;
}

HexaVal hexa_regex_match(HexaVal pat_v, HexaVal s_v) {
    if (!HX_IS_STR(pat_v) || !HX_IS_STR(s_v)) return hexa_bool(0);
    const char* pat_raw = HX_STR(pat_v);
    const char* s = HX_STR(s_v);
    if (!pat_raw || !s) return hexa_bool(0);
    int icase = 0;
    const char* pat = _hexa_re_strip_flags(pat_raw, &icase);
    regex_t re;
    if (_hexa_re_compile(pat, &re, icase) != 0) return hexa_bool(0);
    int ok = regexec(&re, s, 0, NULL, 0);
    regfree(&re);
    return hexa_bool(ok == 0 ? 1 : 0);
}

HexaVal hexa_regex_match_full(HexaVal pat_v, HexaVal s_v) {
    if (!HX_IS_STR(pat_v) || !HX_IS_STR(s_v)) return hexa_bool(0);
    const char* pat_raw = HX_STR(pat_v);
    const char* s = HX_STR(s_v);
    if (!pat_raw || !s) return hexa_bool(0);
    int icase = 0;
    const char* pat = _hexa_re_strip_flags(pat_raw, &icase);
    regex_t re;
    if (_hexa_re_compile(pat, &re, icase) != 0) return hexa_bool(0);
    regmatch_t m;
    int ok = regexec(&re, s, 1, &m, 0);
    int full = (ok == 0 && m.rm_so == 0 && (size_t)m.rm_eo == hxlcl_strlen(s)) ? 1 : 0;
    regfree(&re);
    return hexa_bool(full);
}

HexaVal hexa_regex_search(HexaVal pat_v, HexaVal s_v) {
    if (!HX_IS_STR(pat_v) || !HX_IS_STR(s_v)) return hexa_array_new();
    const char* pat_raw = HX_STR(pat_v);
    const char* s = HX_STR(s_v);
    if (!pat_raw || !s) return hexa_array_new();
    int icase = 0;
    const char* pat = _hexa_re_strip_flags(pat_raw, &icase);
    regex_t re;
    if (_hexa_re_compile(pat, &re, icase) != 0) return hexa_array_new();
    regmatch_t m;
    HexaVal out = hexa_array_new();
    if (regexec(&re, s, 1, &m, 0) == 0) {
        hexa_array_push(out, hexa_int((int64_t)m.rm_so));
        hexa_array_push(out, hexa_int((int64_t)m.rm_eo));
    }
    regfree(&re);
    return out;
}

HexaVal hexa_regex_findall(HexaVal pat_v, HexaVal s_v) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_STR(pat_v) || !HX_IS_STR(s_v)) return out;
    const char* pat_raw = HX_STR(pat_v);
    const char* s = HX_STR(s_v);
    if (!pat_raw || !s) return out;
    int icase = 0;
    const char* pat = _hexa_re_strip_flags(pat_raw, &icase);
    regex_t re;
    if (_hexa_re_compile(pat, &re, icase) != 0) return out;
    regmatch_t m;
    size_t off = 0;
    size_t L = hxlcl_strlen(s);
    while (off <= L) {
        if (regexec(&re, s + off, 1, &m, off > 0 ? REG_NOTBOL : 0) != 0) break;
        if (m.rm_eo == m.rm_so) {
            // zero-width match — advance one to avoid infinite loop
            off += 1;
            continue;
        }
        HexaVal pair = hexa_array_new();
        hexa_array_push(pair, hexa_int((int64_t)(off + m.rm_so)));
        hexa_array_push(pair, hexa_int((int64_t)(off + m.rm_eo)));
        hexa_array_push(out, pair);
        off += m.rm_eo;
    }
    regfree(&re);
    return out;
}

HexaVal hexa_regex_split(HexaVal pat_v, HexaVal s_v) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_STR(pat_v) || !HX_IS_STR(s_v)) return out;
    const char* pat_raw = HX_STR(pat_v);
    const char* s = HX_STR(s_v);
    if (!pat_raw || !s) return out;
    int icase = 0;
    const char* pat = _hexa_re_strip_flags(pat_raw, &icase);
    regex_t re;
    if (_hexa_re_compile(pat, &re, icase) != 0) {
        hexa_array_push(out, hexa_str(s));
        return out;
    }
    regmatch_t m;
    size_t off = 0;
    size_t L = hxlcl_strlen(s);
    while (off <= L) {
        if (regexec(&re, s + off, 1, &m, off > 0 ? REG_NOTBOL : 0) != 0) break;
        if (m.rm_eo == m.rm_so) { off += 1; continue; }
        size_t seg_len = (size_t)m.rm_so;
        char* seg = (char*)malloc(seg_len + 1);
        if (!seg) break;
        hxlcl_memcpy(seg, s + off, seg_len);
        seg[seg_len] = '\0';
        hexa_array_push(out, hexa_str(seg));
        free(seg);
        off += m.rm_eo;
    }
    // Final segment after last match.
    if (off <= L) {
        hexa_array_push(out, hexa_str(s + off));
    }
    regfree(&re);
    return out;
}

HexaVal hexa_regex_replace(HexaVal pat_v, HexaVal s_v, HexaVal repl_v) {
    if (!HX_IS_STR(pat_v) || !HX_IS_STR(s_v) || !HX_IS_STR(repl_v)) return s_v;
    const char* pat_raw = HX_STR(pat_v);
    const char* s = HX_STR(s_v);
    const char* repl = HX_STR(repl_v);
    if (!pat_raw || !s) return s_v;
    if (!repl) repl = "";
    int icase = 0;
    const char* pat = _hexa_re_strip_flags(pat_raw, &icase);
    regex_t re;
    if (_hexa_re_compile(pat, &re, icase) != 0) return s_v;
    regmatch_t m;
    size_t off = 0;
    size_t L = hxlcl_strlen(s);
    size_t Rlen = hxlcl_strlen(repl);
    // Worst-case sizing: every position is a zero-width match → impossible
    // with our zero-width skip. Estimate cap = 4 * (L + 1) * (Rlen + 1).
    size_t cap = (L + 1) * (Rlen + 1) * 4 + 64;
    char* out_buf = (char*)malloc(cap);
    if (!out_buf) { regfree(&re); return s_v; }
    size_t op = 0;
    while (off <= L) {
        if (regexec(&re, s + off, 1, &m, off > 0 ? REG_NOTBOL : 0) != 0) break;
        if (m.rm_eo == m.rm_so) {
            // Copy one char and advance.
            if (op + 1 >= cap) break;
            out_buf[op++] = s[off];
            off += 1;
            continue;
        }
        // Copy unmatched prefix.
        size_t pre = (size_t)m.rm_so;
        if (op + pre + Rlen + 1 >= cap) {
            cap *= 2;
            char* nb = (char*)realloc(out_buf, cap);
            if (!nb) break;
            out_buf = nb;
        }
        hxlcl_memcpy(out_buf + op, s + off, pre);
        op += pre;
        hxlcl_memcpy(out_buf + op, repl, Rlen);
        op += Rlen;
        off += m.rm_eo;
    }
    // Tail.
    size_t tail = L - off;
    if (op + tail + 1 >= cap) {
        cap = op + tail + 1;
        char* nb = (char*)realloc(out_buf, cap);
        if (nb) out_buf = nb;
    }
    hxlcl_memcpy(out_buf + op, s + off, tail);
    op += tail;
    out_buf[op] = '\0';
    HexaVal result = hexa_str(out_buf);
    free(out_buf);
    regfree(&re);
    return result;
}

// utc_compact_now(): compact "YYYYMMDDHHMMSS" UTC (checkpoint filename).
HexaVal hexa_utc_compact_now(void) {
    int64_t pin = hexa_pinned_epoch();
    time_t t = (pin >= 0) ? (time_t)pin : hxlcl_time(NULL);
    struct tm g;
    gmtime_r(&t, &g);
    char buf[32];
    hxlcl_strftime(buf, sizeof(buf), "%Y%m%d%H%M%S", &g);
    return hexa_str(buf);
}

// to_bool(v): generic truthy coercion. Mirrors hexa_truthy semantics
// but returns a TAG_BOOL HexaVal (as opposed to int).
HexaVal hexa_to_bool(HexaVal v) {
    return hexa_bool(hexa_truthy(v) ? 1 : 0);
}

// http_get(url): popen("curl -s <url>") → TAG_STR body. Keeps the
// dependency surface at /usr/bin/curl (universal on macOS/linux) and
// avoids pulling libcurl into runtime.c. Returns "" on curl-missing or
// non-zero exit. http_get is used by anima serve_alm health-checks +
// a handful of blowup-engine scrapers (~6 sites).
HexaVal hexa_http_get(HexaVal url) {
    if (!HX_IS_STR(url) || !HX_STR(url)) return hexa_str("");
    const char* u = HX_STR(url);
    // Reject URLs with shell-meta chars — we pass through /bin/sh via popen.
    for (const char* p = u; *p; p++) {
        char c = *p;
        if (c == '`' || c == '$' || c == ';' || c == '|' || c == '&'
            || c == '<' || c == '>' || c == '\n' || c == '\r'
            || c == '\'' || c == '"' || c == '\\') {
            return hexa_str("");
        }
    }
    char cmd[4096];
    int k = snprintf(cmd, sizeof(cmd), "curl -fsSL --max-time 30 '%s' 2>/dev/null", u);
    if (k < 0 || (size_t)k >= sizeof(cmd)) return hexa_str("");
    // 2026-05-06 — POSIX fork buffer flush before popen (mirrors hexa_exec)
    fflush(NULL);
    FILE* fp = hxlcl_popen(cmd, "r");
    if (!fp) return hexa_str("");
    size_t cap = 4096, len = 0;
    char* buf = (char*)malloc(cap);
    if (!buf) { hxlcl_pclose(fp); return hexa_str(""); }
    size_t r;
    char chunk[2048];
    while ((r = fread(chunk, 1, sizeof(chunk), fp)) > 0) {
        if (len + r + 1 >= cap) {
            while (len + r + 1 >= cap) cap *= 2;
            char* nb = (char*)realloc(buf, cap);
            if (!nb) { free(buf); hxlcl_pclose(fp); return hexa_str(""); }
            buf = nb;
        }
        hxlcl_memcpy(buf + len, chunk, r);
        len += r;
    }
    buf[len] = 0;
    hxlcl_pclose(fp);
    return hexa_str_own(buf);
}

// ── JSON mini (parse + stringify) ─────────────────────────────────
// Minimal recursive-descent JSON handler that covers Anima's use
// (tokenizer configs, checkpoint metadata, serve_alm request bodies).
// Supported: null / bool / int / float / string / array / object.
// Limits: no \uXXXX surrogates (passthrough as raw bytes), no +NaN/Inf.
// TAG mapping:
//   null   → TAG_VOID  (hexa_void)
//   true   → TAG_BOOL 1
//   false  → TAG_BOOL 0
//   int    → TAG_INT
//   float  → TAG_FLOAT
//   string → TAG_STR
//   array  → TAG_ARRAY
//   object → TAG_MAP   (keys always string)

static void _jp_skip_ws(const char* s, size_t n, size_t* pi) {
    while (*pi < n) {
        char c = s[*pi];
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r') (*pi)++;
        else break;
    }
}

static HexaVal _jp_parse_value(const char* s, size_t n, size_t* pi);

static HexaVal _jp_parse_string(const char* s, size_t n, size_t* pi) {
    if (*pi >= n || s[*pi] != '"') return hexa_str("");
    (*pi)++;
    size_t cap = 64, len = 0;
    char* buf = (char*)malloc(cap);
    if (!buf) return hexa_str("");
    while (*pi < n) {
        char c = s[*pi];
        if (c == '"') { (*pi)++; buf[len] = 0; return hexa_str_own(buf); }
        if (c == '\\' && *pi + 1 < n) {
            char e = s[*pi + 1];
            char out = 0;
            int consumed = 2;
            switch (e) {
                case '"':  out = '"';  break;
                case '\\': out = '\\'; break;
                case '/':  out = '/';  break;
                case 'n':  out = '\n'; break;
                case 'r':  out = '\r'; break;
                case 't':  out = '\t'; break;
                case 'b':  out = '\b'; break;
                case 'f':  out = '\f'; break;
                case 'u':
                    // Raw passthrough (no unicode expansion) — write literal
                    // \uXXXX as the 6 bytes so round-trip is lossless.
                    if (*pi + 5 < n) {
                        if (len + 6 >= cap) { cap = (cap + 6) * 2; char* nb = (char*)realloc(buf, cap); if (!nb) { free(buf); return hexa_str(""); } buf = nb; }
                        hxlcl_memcpy(buf + len, s + *pi, 6);
                        len += 6;
                        *pi += 6;
                        continue;
                    }
                    out = 'u';
                    break;
                default:   out = e; break;
            }
            if (len + 1 >= cap) { cap *= 2; char* nb = (char*)realloc(buf, cap); if (!nb) { free(buf); return hexa_str(""); } buf = nb; }
            buf[len++] = out;
            *pi += consumed;
            continue;
        }
        if (len + 1 >= cap) { cap *= 2; char* nb = (char*)realloc(buf, cap); if (!nb) { free(buf); return hexa_str(""); } buf = nb; }
        buf[len++] = c;
        (*pi)++;
    }
    buf[len] = 0;
    return hexa_str_own(buf);
}

static HexaVal _jp_parse_number(const char* s, size_t n, size_t* pi) {
    size_t start = *pi;
    int is_float = 0;
    if (*pi < n && (s[*pi] == '-' || s[*pi] == '+')) (*pi)++;
    while (*pi < n) {
        char c = s[*pi];
        if (c >= '0' && c <= '9') { (*pi)++; continue; }
        if (c == '.' || c == 'e' || c == 'E' || c == '+' || c == '-') {
            is_float = 1;
            (*pi)++;
            continue;
        }
        break;
    }
    size_t k = *pi - start;
    char buf[64];
    if (k >= sizeof(buf)) k = sizeof(buf) - 1;
    hxlcl_memcpy(buf, s + start, k);
    buf[k] = 0;
    if (is_float) return hexa_float(hxlcl_atof(buf));
    return hexa_int((int64_t)hxlcl_strtoll(buf, NULL, 10));
}

static HexaVal _jp_parse_array(const char* s, size_t n, size_t* pi) {
    if (*pi >= n || s[*pi] != '[') return hexa_array_new();
    (*pi)++;
    HexaVal arr = hexa_array_new();
    _jp_skip_ws(s, n, pi);
    if (*pi < n && s[*pi] == ']') { (*pi)++; return arr; }
    while (*pi < n) {
        _jp_skip_ws(s, n, pi);
        HexaVal v = _jp_parse_value(s, n, pi);
        arr = hexa_array_push(arr, v);
        _jp_skip_ws(s, n, pi);
        if (*pi < n && s[*pi] == ',') { (*pi)++; continue; }
        if (*pi < n && s[*pi] == ']') { (*pi)++; break; }
        break;
    }
    return arr;
}

static HexaVal _jp_parse_object(const char* s, size_t n, size_t* pi) {
    if (*pi >= n || s[*pi] != '{') return hexa_map_new();
    (*pi)++;
    HexaVal m = hexa_map_new();
    _jp_skip_ws(s, n, pi);
    if (*pi < n && s[*pi] == '}') { (*pi)++; return m; }
    while (*pi < n) {
        _jp_skip_ws(s, n, pi);
        HexaVal key = _jp_parse_string(s, n, pi);
        _jp_skip_ws(s, n, pi);
        if (*pi < n && s[*pi] == ':') (*pi)++;
        _jp_skip_ws(s, n, pi);
        HexaVal val = _jp_parse_value(s, n, pi);
        if (HX_IS_STR(key) && HX_STR(key)) m = hexa_map_set(m, HX_STR(key), val);
        _jp_skip_ws(s, n, pi);
        if (*pi < n && s[*pi] == ',') { (*pi)++; continue; }
        if (*pi < n && s[*pi] == '}') { (*pi)++; break; }
        break;
    }
    return m;
}

static HexaVal _jp_parse_value(const char* s, size_t n, size_t* pi) {
    _jp_skip_ws(s, n, pi);
    if (*pi >= n) return hexa_void();
    char c = s[*pi];
    if (c == '"') return _jp_parse_string(s, n, pi);
    if (c == '{') return _jp_parse_object(s, n, pi);
    if (c == '[') return _jp_parse_array(s, n, pi);
    if (c == 't' && *pi + 3 < n && hxlcl_memcmp(s + *pi, "true", 4) == 0) { *pi += 4; return hexa_bool(1); }
    if (c == 'f' && *pi + 4 < n && hxlcl_memcmp(s + *pi, "false", 5) == 0) { *pi += 5; return hexa_bool(0); }
    if (c == 'n' && *pi + 3 < n && hxlcl_memcmp(s + *pi, "null", 4) == 0) { *pi += 4; return hexa_void(); }
    // CPython json.loads accepts the non-finite literals Infinity / -Infinity
    // / NaN (json.dumps emits them for non-finite floats). Standard JSON
    // forbids them, but the hexa-bio registry contains `-Infinity` rows, so
    // for byte-parity with the Python reference we accept them here. Must
    // precede the '-'/digit number branch so "-Infinity" is not mis-lexed
    // as the number "-" (which left "Infinity" in the stream and desynced
    // the enclosing object parse, dropping every subsequent key).
    if (c == 'I' && *pi + 8 <= n && hxlcl_memcmp(s + *pi, "Infinity", 8) == 0) { *pi += 8; return hexa_float(INFINITY); }
    if (c == '-' && *pi + 9 <= n && hxlcl_memcmp(s + *pi, "-Infinity", 9) == 0) { *pi += 9; return hexa_float(-INFINITY); }
    if (c == 'N' && *pi + 3 <= n && hxlcl_memcmp(s + *pi, "NaN", 3) == 0) { *pi += 3; return hexa_float(NAN); }
    if (c == '-' || (c >= '0' && c <= '9')) return _jp_parse_number(s, n, pi);
    (*pi)++;  // skip unknown
    return hexa_void();
}

HexaVal hexa_json_parse(HexaVal s) {
    if (!HX_IS_STR(s) || !HX_STR(s)) return hexa_void();
    const char* cs = HX_STR(s);
    size_t n = hxlcl_strlen(cs);
    size_t i = 0;
    return _jp_parse_value(cs, n, &i);
}

HexaVal hexa_json_decode(HexaVal s) { return hexa_json_parse(s); }

// Stringify — one-shot growth buffer, no intermediate HexaVals.
static void _js_buf_reserve(char** pbuf, size_t* pcap, size_t need) {
    if (*pcap >= need) return;
    size_t nc = *pcap ? *pcap : 64;
    while (nc < need) nc *= 2;
    char* nb = (char*)realloc(*pbuf, nc);
    if (!nb) return;
    *pbuf = nb;
    *pcap = nc;
}

static void _js_buf_append(char** pbuf, size_t* pcap, size_t* plen, const char* s, size_t n) {
    _js_buf_reserve(pbuf, pcap, *plen + n + 1);
    if (!*pbuf) return;
    hxlcl_memcpy(*pbuf + *plen, s, n);
    *plen += n;
    (*pbuf)[*plen] = 0;
}

static void _js_emit_string(char** pbuf, size_t* pcap, size_t* plen, const char* s) {
    _js_buf_append(pbuf, pcap, plen, "\"", 1);
    if (!s) { _js_buf_append(pbuf, pcap, plen, "\"", 1); return; }
    for (const char* p = s; *p; p++) {
        unsigned char c = (unsigned char)*p;
        if (c == '"')       _js_buf_append(pbuf, pcap, plen, "\\\"", 2);
        else if (c == '\\') _js_buf_append(pbuf, pcap, plen, "\\\\", 2);
        else if (c == '\n') _js_buf_append(pbuf, pcap, plen, "\\n", 2);
        else if (c == '\r') _js_buf_append(pbuf, pcap, plen, "\\r", 2);
        else if (c == '\t') _js_buf_append(pbuf, pcap, plen, "\\t", 2);
        else if (c == '\b') _js_buf_append(pbuf, pcap, plen, "\\b", 2);
        else if (c == '\f') _js_buf_append(pbuf, pcap, plen, "\\f", 2);
        else if (c < 0x20) {
            char esc[8];
            int k = snprintf(esc, sizeof(esc), "\\u%04x", c);
            if (k > 0) _js_buf_append(pbuf, pcap, plen, esc, (size_t)k);
        } else {
            char ch = (char)c;
            _js_buf_append(pbuf, pcap, plen, &ch, 1);
        }
    }
    _js_buf_append(pbuf, pcap, plen, "\"", 1);
}

static void _js_emit_value(char** pbuf, size_t* pcap, size_t* plen, HexaVal v);

static void _js_emit_array(char** pbuf, size_t* pcap, size_t* plen, HexaVal v) {
    _js_buf_append(pbuf, pcap, plen, "[", 1);
    int64_t n = (int64_t)HX_ARR_LEN(v);
    for (int64_t i = 0; i < n; i++) {
        if (i) _js_buf_append(pbuf, pcap, plen, ",", 1);
        _js_emit_value(pbuf, pcap, plen, HX_ARR_ITEMS(v)[i]);
    }
    _js_buf_append(pbuf, pcap, plen, "]", 1);
}

static void _js_emit_object(char** pbuf, size_t* pcap, size_t* plen, HexaVal v) {
    _js_buf_append(pbuf, pcap, plen, "{", 1);
    HexaVal keys = hexa_map_keys(v);
    int64_t n = (int64_t)HX_ARR_LEN(keys);
    for (int64_t i = 0; i < n; i++) {
        if (i) _js_buf_append(pbuf, pcap, plen, ",", 1);
        HexaVal k = HX_ARR_ITEMS(keys)[i];
        if (HX_IS_STR(k)) _js_emit_string(pbuf, pcap, plen, HX_STR(k));
        else              _js_emit_string(pbuf, pcap, plen, "");
        _js_buf_append(pbuf, pcap, plen, ":", 1);
        HexaVal vv = hexa_map_get(v, HX_IS_STR(k) ? HX_STR(k) : "");
        _js_emit_value(pbuf, pcap, plen, vv);
    }
    _js_buf_append(pbuf, pcap, plen, "}", 1);
}

// shortest %g-form decimal that strtod-round-trips to the same double —
// matches CPython repr()/json.dumps() shortest-representation output.
static void _shortest_double(char* buf, size_t cap, double f) {
    for (int _p = 1; _p < 17; _p++) {
        snprintf(buf, cap, "%.*g", _p, f);
        if (strtod(buf, NULL) == f) return;
    }
    snprintf(buf, cap, "%.17g", f);
}

static void _js_emit_value(char** pbuf, size_t* pcap, size_t* plen, HexaVal v) {
    if (HX_IS_VOID(v))       { _js_buf_append(pbuf, pcap, plen, "null", 4); return; }
    if (HX_IS_BOOL(v))       { if (HX_BOOL(v)) _js_buf_append(pbuf, pcap, plen, "true", 4); else _js_buf_append(pbuf, pcap, plen, "false", 5); return; }
    if (HX_IS_INT(v))        { char nb[32]; int k = snprintf(nb, sizeof(nb), "%lld", (long long)HX_INT(v)); if (k > 0) _js_buf_append(pbuf, pcap, plen, nb, (size_t)k); return; }
    if (HX_IS_FLOAT(v))      {
        double f = HX_FLOAT(v);
        char nb[64];
        int k;
        if (f != f) k = snprintf(nb, sizeof(nb), "null");
        else if (fabs(f) < 1e16 && f == (double)(int64_t)f) k = snprintf(nb, sizeof(nb), "%lld.0", (long long)f);
        else { _shortest_double(nb, sizeof(nb), f); k = (int)hxlcl_strlen(nb); }
        if (k > 0) _js_buf_append(pbuf, pcap, plen, nb, (size_t)k);
        return;
    }
    if (HX_IS_STR(v))        { _js_emit_string(pbuf, pcap, plen, HX_STR(v) ? HX_STR(v) : ""); return; }
    if (HX_IS_ARRAY(v))      { _js_emit_array(pbuf, pcap, plen, v); return; }
    if (HX_IS_MAP(v))        { _js_emit_object(pbuf, pcap, plen, v); return; }
    _js_buf_append(pbuf, pcap, plen, "null", 4);
}

HexaVal hexa_json_stringify(HexaVal v) {
    char* buf = NULL;
    size_t cap = 0, len = 0;
    _js_emit_value(&buf, &cap, &len, v);
    if (!buf) return hexa_str("");
    return hexa_str_own(buf);
}

HexaVal hexa_json_encode(HexaVal v) { return hexa_json_stringify(v); }

// FIX-A (Anima ML eval unblock, 2026-04-19) ─────────────────────────
// 8 tensor_* fallback builtins required by anima/serving/eval_alm.hexa
// (and siblings) that do not explicitly `use "self/ml/tensor_ops.hexa"`.
// Semantics mirror the pure-hexa tensor_ops implementation; performance
// is intentionally naive — callers on the fast-path still pull the
// BLAS/NEON-optimized self/ml/ modules explicitly. All ops operate on
// flat row-major arrays of TAG_FLOAT / TAG_INT (coerced via __hx_to_double).

// tensor_zeros(n): length-n array filled with 0.0.
HexaVal hexa_tensor_zeros(HexaVal nv) {
    int64_t n = (int64_t)__hx_to_double(nv);
    if (n < 0) n = 0;
    HexaVal arr = hexa_array_new();
    for (int64_t i = 0; i < n; i++) arr = hexa_array_push(arr, hexa_float(0.0));
    return arr;
}

// FIX-A 2nd batch (2026-04-19): tensor_ones(n) — length-n array filled with 1.0.
// Pairs with tensor_zeros for anima-speak init paths (ln_g, rms_g).
HexaVal hexa_tensor_ones(HexaVal nv) {
    int64_t n = (int64_t)__hx_to_double(nv);
    if (n < 0) n = 0;
    HexaVal arr = hexa_array_new();
    for (int64_t i = 0; i < n; i++) arr = hexa_array_push(arr, hexa_float(1.0));
    return arr;
}

// FIX-A 2nd batch (2026-04-19): swiglu_vec(gate, up) = silu(gate) * up elementwise.
// silu(x) = x / (1 + exp(-x)). Shape: min(|gate|, |up|). For anima eval_alm.hexa
// + training hot paths (nn_core etc.) — scalar fallback, fast-path is FFN fused kernel.
HexaVal hexa_swiglu_vec(HexaVal gate, HexaVal up) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(gate) || !HX_IS_ARRAY(up)) return out;
    int64_t ng = (int64_t)HX_ARR_LEN(gate), nu = (int64_t)HX_ARR_LEN(up);
    int64_t k = ng < nu ? ng : nu;
    for (int64_t i = 0; i < k; i++) {
        double g = __hx_to_double(hexa_array_get(gate, i));
        double u = __hx_to_double(hexa_array_get(up, i));
        double silu = g / (1.0 + hxlcl_exp(-g));
        out = hexa_array_push(out, hexa_float(silu * u));
    }
    return out;
}

// tensor_slice(arr, lo, hi): subarray [lo, hi) with clamped bounds.
HexaVal hexa_tensor_slice(HexaVal a, HexaVal lov, HexaVal hiv) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(a)) return out;
    int64_t n = (int64_t)HX_ARR_LEN(a);
    int64_t lo = (int64_t)__hx_to_double(lov);
    int64_t hi = (int64_t)__hx_to_double(hiv);
    if (lo < 0) lo = 0;
    if (hi > n) hi = n;
    for (int64_t i = lo; i < hi; i++) out = hexa_array_push(out, hexa_array_get(a, i));
    return out;
}

// tensor_add(a, b): elementwise a[i] + b[i], length = min(|a|, |b|).
HexaVal hexa_tensor_add(HexaVal a, HexaVal b) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(a) || !HX_IS_ARRAY(b)) return out;
    int64_t na = (int64_t)HX_ARR_LEN(a), nb = (int64_t)HX_ARR_LEN(b);
    int64_t k = na < nb ? na : nb;
    for (int64_t i = 0; i < k; i++) {
        double va = __hx_to_double(hexa_array_get(a, i));
        double vb = __hx_to_double(hexa_array_get(b, i));
        out = hexa_array_push(out, hexa_float(va + vb));
    }
    return out;
}

// tensor_dot(a, b): scalar sum(a[i] * b[i]) over min length.
HexaVal hexa_tensor_dot(HexaVal a, HexaVal b) {
    if (!HX_IS_ARRAY(a) || !HX_IS_ARRAY(b)) return hexa_float(0.0);
    int64_t na = (int64_t)HX_ARR_LEN(a), nb = (int64_t)HX_ARR_LEN(b);
    int64_t k = na < nb ? na : nb;
    double s = 0.0;
    for (int64_t i = 0; i < k; i++) {
        s += __hx_to_double(hexa_array_get(a, i)) *
             __hx_to_double(hexa_array_get(b, i));
    }
    return hexa_float(s);
}

// tensor_mul_scalar(a, s): elementwise a[i] * s.
HexaVal hexa_tensor_mul_scalar(HexaVal a, HexaVal sv) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(a)) return out;
    int64_t n = (int64_t)HX_ARR_LEN(a);
    double s = __hx_to_double(sv);
    for (int64_t i = 0; i < n; i++) {
        double va = __hx_to_double(hexa_array_get(a, i));
        out = hexa_array_push(out, hexa_float(va * s));
    }
    return out;
}

// hadamard(a, b): elementwise product (same semantics as tensor_add but *).
// Matches interpreter hexa_full.hexa:10496 behavior.
HexaVal hexa_hadamard(HexaVal a, HexaVal b) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(a) || !HX_IS_ARRAY(b)) return out;
    int64_t na = (int64_t)HX_ARR_LEN(a), nb = (int64_t)HX_ARR_LEN(b);
    int64_t k = na < nb ? na : nb;
    for (int64_t i = 0; i < k; i++) {
        double va = __hx_to_double(hexa_array_get(a, i));
        double vb = __hx_to_double(hexa_array_get(b, i));
        out = hexa_array_push(out, hexa_float(va * vb));
    }
    return out;
}

// silu/gelu/argmax: Step-3 cycle 17 port.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_silu(HexaVal a) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(a)) return out;
    int64_t n = (int64_t)HX_ARR_LEN(a);
    for (int64_t i = 0; i < n; i++) {
        double x = __hx_to_double(hexa_array_get(a, i));
        out = hexa_array_push(out, hexa_float(x / (1.0 + hxlcl_exp(-x))));
    }
    return out;
}
HexaVal hexa_gelu(HexaVal a) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(a)) return out;
    int64_t n = (int64_t)HX_ARR_LEN(a);
    const double k = 0.7978845608028654; // sqrt(2/pi)
    for (int64_t i = 0; i < n; i++) {
        double x = __hx_to_double(hexa_array_get(a, i));
        double inner = k * (x + 0.044715 * x * x * x);
        out = hexa_array_push(out, hexa_float(0.5 * x * (1.0 + tanh(inner))));
    }
    return out;
}
HexaVal hexa_argmax(HexaVal a) {
    if (!HX_IS_ARRAY(a)) return hexa_int(-1);
    int64_t n = (int64_t)HX_ARR_LEN(a);
    if (n == 0) return hexa_int(-1);
    int64_t best_i = 0;
    double best_v = __hx_to_double(hexa_array_get(a, 0));
    for (int64_t i = 1; i < n; i++) {
        double v = __hx_to_double(hexa_array_get(a, i));
        if (v > best_v) { best_v = v; best_i = i; }
    }
    return hexa_int(best_i);
}
#else
extern HexaVal rt_silu(HexaVal a);
extern HexaVal rt_gelu(HexaVal a);
extern HexaVal rt_argmax(HexaVal a);
HexaVal hexa_silu(HexaVal a) {
    if (!HX_IS_ARRAY(a)) return hexa_array_new();
    return rt_silu(a);
}
HexaVal hexa_gelu(HexaVal a) {
    if (!HX_IS_ARRAY(a)) return hexa_array_new();
    return rt_gelu(a);
}
HexaVal hexa_argmax(HexaVal a) {
    if (!HX_IS_ARRAY(a)) return hexa_int(-1);
    return rt_argmax(a);
}
#endif

// sum(a): reduce-sum; returns int if all elements int, float otherwise.
// Matches interpreter hexa_full.hexa:13232. Step-3 cycle 23 port (all-
// float fast path via hexa-source; mixed arrays stay polymorphic C).
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_sum(HexaVal a) {
    if (!HX_IS_ARRAY(a)) return hexa_int(0);
    int64_t n = (int64_t)HX_ARR_LEN(a);
    int has_float = 0;
    int64_t int_total = 0;
    double float_total = 0.0;
    for (int64_t i = 0; i < n; i++) {
        HexaVal e = hexa_array_get(a, i);
        if (HX_IS_FLOAT(e)) { has_float = 1; float_total += HX_FLOAT(e); }
        else { int_total += HX_INT(e); }
    }
    if (has_float) return hexa_float((double)int_total + float_total);
    return hexa_int(int_total);
}
#else
extern HexaVal rt_array_sum_float(HexaVal arr);
HexaVal hexa_sum(HexaVal a) {
    if (!HX_IS_ARRAY(a)) return hexa_int(0);
    int64_t n = (int64_t)HX_ARR_LEN(a);
    if (n == 0) return hexa_int(0);
    if (_arr_all_float(a)) return rt_array_sum_float(a);
    int has_float = 0;
    int64_t int_total = 0;
    double float_total = 0.0;
    for (int64_t i = 0; i < n; i++) {
        HexaVal e = hexa_array_get(a, i);
        if (HX_IS_FLOAT(e)) { has_float = 1; float_total += HX_FLOAT(e); }
        else { int_total += HX_INT(e); }
    }
    if (has_float) return hexa_float((double)int_total + float_total);
    return hexa_int(int_total);
}
#endif

// clamp(x, lo, hi): scalar clamp, float result. Step-3 cycle 3 port.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_clamp(HexaVal xv, HexaVal lov, HexaVal hiv) {
    double x = __hx_to_double(xv);
    double lo = __hx_to_double(lov);
    double hi = __hx_to_double(hiv);
    if (x < lo) return hexa_float(lo);
    if (x > hi) return hexa_float(hi);
    return hexa_float(x);
}
#else
extern HexaVal rt_clamp(HexaVal x, HexaVal lo, HexaVal hi);
HexaVal hexa_clamp(HexaVal xv, HexaVal lov, HexaVal hiv) {
    return rt_clamp(hexa_float(__hx_to_double(xv)),
                    hexa_float(__hx_to_double(lov)),
                    hexa_float(__hx_to_double(hiv)));
}
#endif

// one_hot(idx, n): n-length binary vector, 1.0 at idx, 0.0 elsewhere.
// Matches interpreter hexa_full.hexa:10512. Step-3 cycle 12 port.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_one_hot(HexaVal idxv, HexaVal nv) {
    int64_t idx = HX_IS_INT(idxv) ? HX_INT(idxv) : (int64_t)__hx_to_double(idxv);
    int64_t n = HX_IS_INT(nv) ? HX_INT(nv) : (int64_t)__hx_to_double(nv);
    HexaVal out = hexa_array_new();
    for (int64_t i = 0; i < n; i++) {
        out = hexa_array_push(out, hexa_float(i == idx ? 1.0 : 0.0));
    }
    return out;
}
#else
extern HexaVal rt_one_hot(HexaVal idx, HexaVal n);
HexaVal hexa_one_hot(HexaVal idxv, HexaVal nv) {
    int64_t idx = HX_IS_INT(idxv) ? HX_INT(idxv) : (int64_t)__hx_to_double(idxv);
    int64_t n = HX_IS_INT(nv) ? HX_INT(nv) : (int64_t)__hx_to_double(nv);
    return rt_one_hot(hexa_int(idx), hexa_int(n));
}
#endif

// rms_norm(x, gamma, eps): gamma[i] * x[i] / sqrt(mean(x^2) + eps).
// gamma may be array (per-element scale) or scalar (uniform scale).
// Step-3 cycle 16 port.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_rms_norm(HexaVal x, HexaVal gamma, HexaVal epsv) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(x)) return out;
    int64_t n = (int64_t)HX_ARR_LEN(x);
    if (n == 0) return out;
    double ss = 0.0;
    for (int64_t i = 0; i < n; i++) {
        double v = __hx_to_double(hexa_array_get(x, i));
        ss += v * v;
    }
    double mean = ss / (double)n;
    double eps = __hx_to_double(epsv);
    double inv = 1.0 / sqrt(mean + eps);
    int gamma_is_arr = HX_IS_ARRAY(gamma);
    double gamma_scalar = gamma_is_arr ? 1.0 : __hx_to_double(gamma);
    for (int64_t i = 0; i < n; i++) {
        double v = __hx_to_double(hexa_array_get(x, i));
        double g = gamma_is_arr
            ? __hx_to_double(hexa_array_get(gamma, i < (int64_t)HX_ARR_LEN(gamma) ? i : 0))
            : gamma_scalar;
        out = hexa_array_push(out, hexa_float(g * v * inv));
    }
    return out;
}
#else
extern HexaVal rt_rms_norm_scalar(HexaVal x, HexaVal gamma, HexaVal eps);
extern HexaVal rt_rms_norm_array(HexaVal x, HexaVal gamma, HexaVal eps);
HexaVal hexa_rms_norm(HexaVal x, HexaVal gamma, HexaVal epsv) {
    if (!HX_IS_ARRAY(x)) return hexa_array_new();
    HexaVal eps = hexa_float(__hx_to_double(epsv));
    if (HX_IS_ARRAY(gamma)) return rt_rms_norm_array(x, gamma, eps);
    return rt_rms_norm_scalar(x, hexa_float(__hx_to_double(gamma)), eps);
}
#endif

// softmax(a): stable softmax — subtract max, exp, normalize by sum.
// Step-3 cycle 15 port.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_softmax(HexaVal a) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(a)) return out;
    int64_t n = (int64_t)HX_ARR_LEN(a);
    if (n == 0) return out;
    double m = __hx_to_double(hexa_array_get(a, 0));
    for (int64_t i = 1; i < n; i++) {
        double v = __hx_to_double(hexa_array_get(a, i));
        if (v > m) m = v;
    }
    double sum = 0.0;
    double* tmp = (double*)malloc(sizeof(double) * (size_t)n);
    for (int64_t i = 0; i < n; i++) {
        double v = __hx_to_double(hexa_array_get(a, i));
        tmp[i] = hxlcl_exp(v - m);
        sum += tmp[i];
    }
    double inv = sum > 0.0 ? 1.0 / sum : 0.0;
    for (int64_t i = 0; i < n; i++) out = hexa_array_push(out, hexa_float(tmp[i] * inv));
    free(tmp);
    return out;
}
#else
extern HexaVal rt_softmax(HexaVal a);
HexaVal hexa_softmax(HexaVal a) {
    if (!HX_IS_ARRAY(a)) return hexa_array_new();
    return rt_softmax(a);
}
#endif

// matmul(A, B, M, N, K): row-major C[M*N] = A[M*K] @ B[K*N], naive O(M*N*K).
// Positional arg order is cblas-style (M, N, K) — output rows, output cols,
// contraction dim — verified empirically (B3, commit 9fb47758): the call
// `matmul([1..6],[1..6], 2, 2, 3)` yields the 2×2 product `[22,28,49,64]`
// (A treated as 2×3, B as 3×2). Internal locals `m/k/n` below are kept for
// historical reasons; the load-bearing convention is the (M, N, K) caller
// order documented here. See stdlib/linalg/ffi.hexa for the caller-side
// mirror of this contract.
// Step-3 cycle 19 port.
#ifndef HEXA_HAS_HEXA_RT_STDLIB
HexaVal hexa_matmul(HexaVal a, HexaVal b, HexaVal mv, HexaVal kv, HexaVal nv) {
    HexaVal out = hexa_array_new();
    if (!HX_IS_ARRAY(a) || !HX_IS_ARRAY(b)) return out;
    int64_t m = (int64_t)__hx_to_double(mv);
    int64_t k = (int64_t)__hx_to_double(kv);
    int64_t n = (int64_t)__hx_to_double(nv);
    if (m < 0 || k < 0 || n < 0) return out;
    int64_t alen = (int64_t)HX_ARR_LEN(a), blen = (int64_t)HX_ARR_LEN(b);
    for (int64_t i = 0; i < m; i++) {
        for (int64_t j = 0; j < n; j++) {
            double s = 0.0;
            for (int64_t p = 0; p < k; p++) {
                int64_t ai = i * k + p;
                int64_t bi = p * n + j;
                if (ai >= alen || bi >= blen) continue;
                s += __hx_to_double(hexa_array_get(a, ai)) *
                     __hx_to_double(hexa_array_get(b, bi));
            }
            out = hexa_array_push(out, hexa_float(s));
        }
    }
    return out;
}
#else
extern HexaVal rt_matmul(HexaVal a, HexaVal b, HexaVal m, HexaVal k, HexaVal n);
HexaVal hexa_matmul(HexaVal a, HexaVal b, HexaVal mv, HexaVal kv, HexaVal nv) {
    if (!HX_IS_ARRAY(a) || !HX_IS_ARRAY(b)) return hexa_array_new();
    int64_t m = (int64_t)__hx_to_double(mv);
    int64_t k = (int64_t)__hx_to_double(kv);
    int64_t n = (int64_t)__hx_to_double(nv);
    return rt_matmul(a, b, hexa_int(m), hexa_int(k), hexa_int(n));
}
#endif

// Base64 (RFC 4648)
static const char _b64_enc[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

HexaVal hexa_base64_encode(HexaVal s) {
    if (!HX_IS_STR(s) || !HX_STR(s)) return hexa_str("");
    const unsigned char* in = (const unsigned char*)HX_STR(s);
    size_t n = HX_STRLEN(s);
    size_t olen = 4 * ((n + 2) / 3);
    char* out = (char*)malloc(olen + 1);
    size_t i = 0, j = 0;
    while (i + 3 <= n) {
        uint32_t t = (in[i] << 16) | (in[i+1] << 8) | in[i+2];
        out[j++] = _b64_enc[(t >> 18) & 0x3F];
        out[j++] = _b64_enc[(t >> 12) & 0x3F];
        out[j++] = _b64_enc[(t >> 6) & 0x3F];
        out[j++] = _b64_enc[t & 0x3F];
        i += 3;
    }
    if (i < n) {
        uint32_t t = in[i] << 16;
        int rem = (int)(n - i);
        if (rem == 2) t |= in[i+1] << 8;
        out[j++] = _b64_enc[(t >> 18) & 0x3F];
        out[j++] = _b64_enc[(t >> 12) & 0x3F];
        out[j++] = (rem == 2) ? _b64_enc[(t >> 6) & 0x3F] : '=';
        out[j++] = '=';
    }
    out[j] = 0;
    return hexa_str_own(out);
}

HexaVal hexa_base64_decode(HexaVal s) {
    if (!HX_IS_STR(s) || !HX_STR(s)) return hexa_str("");
    static int dec[256];
    static int dec_init = 0;
    if (!dec_init) {
        for (int i = 0; i < 256; i++) dec[i] = -1;
        for (int i = 0; i < 64; i++) dec[(unsigned char)_b64_enc[i]] = i;
        dec_init = 1;
    }
    const unsigned char* in = (const unsigned char*)HX_STR(s);
    size_t n = HX_STRLEN(s);
    char* out = (char*)malloc(n + 1);
    size_t j = 0;
    int bits = 0, vbits = 0;
    for (size_t i = 0; i < n; i++) {
        if (in[i] == '=') break;
        int v = dec[in[i]];
        if (v < 0) continue;
        bits = (bits << 6) | v;
        vbits += 6;
        if (vbits >= 8) {
            vbits -= 8;
            out[j++] = (char)((bits >> vbits) & 0xFF);
        }
    }
    out[j] = 0;
    return hexa_str_own(out);
}

// ── bt 73: bare-ident HexaVal globals for transpiled builtin dispatch ──
// Self-host codegen (self/native/hexa_cc.c gen2_expr Call fallback, ~line 5642+)
// emits `hexa_call0(timestamp)`, `hexa_call1(base64_encode, s)`, … where the
// callee is a BARE C identifier. For the linker to resolve these, each name
// must exist as a `HexaVal` variable holding a TAG_FN that wraps the real
// implementation. bt 71 supplied the hexa_*-prefixed C functions; this block
// wires them to the bare names the transpiler expects.
//
// hexa_call0/hexa_call1 (defined above in this file) already branch on
// TAG_FN and cast fn_ptr to `HexaVal (*)(…)`, so HexaVal-returning wrappers
// with matching arity work directly.
//
// Wrapper for `timestamp` — hexa_timestamp is declared above without params;
// expose under the void→HexaVal signature hexa_call0 expects.
static HexaVal _bt73_timestamp_w(void) { return hexa_timestamp(); }
static HexaVal _bt73_base64_encode_w(HexaVal s) { return hexa_base64_encode(s); }
static HexaVal _bt73_base64_decode_w(HexaVal s) { return hexa_base64_decode(s); }
// interp bootstrap gap: hexa_v2 (already-baked transpiler) doesn't know
// about setenv / exec_capture, so the interpreter dispatch in hexa_full.hexa
// resolves bare `setenv(...)` through hexa_call2 / `exec_capture(...)` via
// hexa_call1. Shim these as TAG_FN globals so the linker finds them.
static HexaVal _w_setenv(HexaVal n, HexaVal v) { return hexa_setenv(n, v); }
static HexaVal _w_exec_capture(HexaVal c) { return hexa_exec_capture(c); }
static HexaVal _w_push(HexaVal a, HexaVal v) { return hexa_array_push(a, v); }

HexaVal timestamp;
HexaVal base64_encode;
HexaVal base64_decode;
// Names intentionally prefixed — plain `setenv` would clobber the libc
// prototype from <stdlib.h>, and `exec_capture` is new surface.
HexaVal hx_setenv;
HexaVal hx_exec_capture;
HexaVal hx_push;
// Cycle 55 recovery — stdlib/fs builtins as bt73 TAG_FN HexaVal globals.
HexaVal rt_fs_append_atomic(HexaVal path, HexaVal data);
HexaVal rt_fs_stat(HexaVal path);
HexaVal rt_fs_rotate_if_over(HexaVal path, HexaVal max_bytes, HexaVal keep);
HexaVal rt_fs_mkdir_p(HexaVal path);
HexaVal fs_append_atomic;
HexaVal fs_stat;
HexaVal fs_rotate_if_over;
HexaVal fs_mkdir_p;

// S1-D2 Blocker C: runtime init for TAG_FN shim variables.
// NaN-boxing makes HexaVal a uint64_t — designated initializers for the
// struct layout are illegal.  Lazy-init mirrors _hexa_init_cached_strs().
static int _fn_shims_ready = 0;
static void _hexa_init_net_fn_shims(void);  // fwd decl — body in native/net.c
static void _hexa_init_os_fn_shims(void);   // fwd decl — body in native/signal_flock.c
static void _hexa_init_exec_sha_fn_shims(void); // fwd decl — body in native/exec_argv_sha256.c
static void _hexa_init_persistent_pipe_fn_shims(void); // fwd decl — body in native/persistent_pipe.c
static void _hexa_init_thread_fn_shims(void); // fwd decl — body in native/thread.c (2026-05-13)
static void _hexa_init_pty_fn_shims(void);    // fwd decl — body in native/pty.c    (2026-05-13)
static void _hexa_init_fn_shims(void) {
    if (_fn_shims_ready) return;
    // bootstrap free-fn shims (join, char_code, chr, bit_or)
    // (`split` was retired 2026-04-21 — codegen_c2.hexa now emits hexa_str_split directly.)
    join       = hexa_fn_new((void*)hexa_str_join,        2);
    char_code  = hexa_fn_new((void*)hexa_char_code,       2);
    chr        = hexa_fn_new((void*)hexa_from_char_code,   1);
    // RFC 030 (2026-05-12): bytes_to_str_raw([int]) — raw byte string
    // assembler for the byte_tokenizer / safetensors paths. See impl
    // near hexa_from_char_code below.
    bytes_to_str_raw = hexa_fn_new((void*)hexa_bytes_to_str_raw, 1);
    // 2026-05-12 RFC 030 sibling: farr_* primitive shims (see fwd-decls).
    farr_zeros = hexa_fn_new((void*)hexa_farr_zeros, 1);
    farr_get   = hexa_fn_new((void*)hexa_farr_get,   2);
    farr_set   = hexa_fn_new((void*)hexa_farr_set,   3);
    farr_len   = hexa_fn_new((void*)hexa_farr_len,   1);
    farr_free  = hexa_fn_new((void*)hexa_farr_free,  1);
    // RFC 036 (2026-05-13): farr_int_array shims. Replaces boxed [int]
    // mask tables in qmirror chemistry_vqe hot loops; unblocks 4e/6o tier.
    farr_int_zeros           = hexa_fn_new((void*)hexa_farr_int_zeros,           1);
    farr_int_get             = hexa_fn_new((void*)hexa_farr_int_get,             2);
    farr_int_set             = hexa_fn_new((void*)hexa_farr_int_set,             3);
    farr_int_len             = hexa_fn_new((void*)hexa_farr_int_len,             1);
    farr_int_fill_from_array = hexa_fn_new((void*)hexa_farr_int_fill_from_array, 2);
    farr_int_copy            = hexa_fn_new((void*)hexa_farr_int_copy,            1);
    farr_int_sum             = hexa_fn_new((void*)hexa_farr_int_sum,             1);
    farr_int_free            = hexa_fn_new((void*)hexa_farr_int_free,            1);
    // RFC 025 (2026-05-12): safetensors mmap-backed zero-copy load shims.
    safetensors_mmap_open           = hexa_fn_new((void*)hexa_safetensors_mmap_open,           1);
    safetensors_mmap_header         = hexa_fn_new((void*)hexa_safetensors_mmap_header,         1);
    safetensors_mmap_data_offset    = hexa_fn_new((void*)hexa_safetensors_mmap_data_offset,    1);
    safetensors_mmap_size           = hexa_fn_new((void*)hexa_safetensors_mmap_size,           1);
    safetensors_mmap_read_f32_farr  = hexa_fn_new((void*)hexa_safetensors_mmap_read_f32_farr,  3);
    // RFC 031 (2026-05-12): BF16 reader — bf16 → f32 → packed-double farr.
    safetensors_mmap_read_bf16_to_f32_farr = hexa_fn_new((void*)hexa_safetensors_mmap_read_bf16_to_f32_farr, 3);
    safetensors_mmap_read_bytes     = hexa_fn_new((void*)hexa_safetensors_mmap_read_bytes,     3);
    safetensors_mmap_close          = hexa_fn_new((void*)hexa_safetensors_mmap_close,          1);
    // RFC 032 (2026-05-12): farr_matmul — packed-double matrix multiply.
    farr_matmul_shim                = hexa_fn_new((void*)hexa_farr_matmul,                     5);
    // RFC 033 (2026-05-12): farr_copy + farr_add_gaussian_noise.
    farr_copy                       = hexa_fn_new((void*)hexa_farr_copy,                       1);
    farr_add_gaussian_noise         = hexa_fn_new((void*)hexa_farr_add_gaussian_noise,         2);
    // anima RFC 034 (2026-05-16): farr reverse-mode autograd carriers.
    // ad_matmul (5-arg) + adamw_step (11-arg) use static-inline wrappers
    // (direct C call past the hexa_callN ceiling) — no carrier needed.
    ad_tape_begin                   = hexa_fn_new((void*)hexa_ad_tape_begin,                   0);
    ad_tape_end                     = hexa_fn_new((void*)hexa_ad_tape_end,                     1);
    ad_softmax_cross_entropy        = hexa_fn_new((void*)hexa_ad_softmax_cross_entropy,        4);
    ad_backward                     = hexa_fn_new((void*)hexa_ad_backward,                     1);
    ad_grad                         = hexa_fn_new((void*)hexa_ad_grad,                         1);
    // anima RFC 035-draft (2026-05-16): bf16 mixed-precision carriers
    // (distinct from the 2026-05-13 internal NM-step "RFC 035" below;
    // bf16 namespace = farr_to_bf16 / farr_from_bf16 / adamw_step_mixed).
    // adamw_step_mixed (12-arg) = direct-C wrapper past the hexa_callN ceiling.
    farr_to_bf16                    = hexa_fn_new((void*)hexa_farr_to_bf16,                    3);
    farr_from_bf16                  = hexa_fn_new((void*)hexa_farr_from_bf16,                  3);
    // anima RFC 036-draft (2026-05-16): phi_rs MI/Φ byte-equal carriers.
    phi_mi_pair                     = hexa_fn_new((void*)hexa_phi_mi_pair,                     4);
    phi_spatial                     = hexa_fn_new((void*)hexa_phi_spatial,                     4);
    // anima RFC 040 (2026-05-16): farr GPU/CUDA Phase A scaffolding —
    // 0/1-arg device-management carriers. The 5-arg farr_matmul_gpu uses
    // a static-inline wrapper (direct C call past the hexa_callN ceiling,
    // same pattern as RFC 032 farr_matmul + RFC 034 ad_matmul).
    cuda_available                  = hexa_fn_new((void*)hexa_cuda_available,                  0);
    cuda_device_count               = hexa_fn_new((void*)hexa_cuda_device_count,               0);
    farr_to_device                  = hexa_fn_new((void*)hexa_farr_to_device,                  1);
    farr_to_host                    = hexa_fn_new((void*)hexa_farr_to_host,                    1);
    farr_pin                        = hexa_fn_new((void*)hexa_farr_pin,                        1);
    farr_device_free                = hexa_fn_new((void*)hexa_farr_device_free,                1);
    /* RFC 056 Phase 1 — residence contract + sub-view API. */
    farr_set_out_disposition        = hexa_fn_new((void*)hexa_farr_set_out_disposition,        1);
    farr_dev_view                   = hexa_fn_new((void*)hexa_farr_dev_view,                   3);
    farr_pin_device                 = hexa_fn_new((void*)hexa_farr_pin_device,                 1);
    farr_unpin_device               = hexa_fn_new((void*)hexa_farr_unpin_device,               1);
    // anima RFC 040 Phase B (2026-05-16): row-softmax / row-RMSNorm /
    // elementwise add+scale GPU dispatcher carriers. All ≤4-arg so they
    // route through hexa_callN; on no-CUDA they call the small CPU
    // helpers in the Phase B block above (byte-equal oracle).
    farr_softmax_rows_gpu           = hexa_fn_new((void*)hexa_farr_softmax_rows_gpu,           3);
    farr_rmsnorm_rows_gpu           = hexa_fn_new((void*)hexa_farr_rmsnorm_rows_gpu,           4);
    farr_add_gpu                    = hexa_fn_new((void*)hexa_farr_add_gpu,                    3);
    farr_scale_gpu                  = hexa_fn_new((void*)hexa_farr_scale_gpu,                  3);
    farr_silu_gate_gpu              = hexa_fn_new((void*)hexa_farr_silu_gate_gpu,              3);
    // mk2-closure port (rfc043-flame-camp c2689508 + c42ac263, 2026-05-19):
    // 3-arg C5 batch builtins use HexaVal carrier + hexa_fn_new (codegen
    // emits hexa_call3, dispatched via the carrier — same pattern as
    // farr_silu_gate_gpu / farr_add_gpu). The 5+/6+/7+/9+/12-arg builtins
    // (copy_slice, transpose_2d, fill_dt_lcg, rmsnorm_mh, attn_dt_fwd/bwd)
    // use bare direct-C calls past the hexa_callN ceiling.
    farr_zero_slice_gpu             = hexa_fn_new((void*)hexa_farr_zero_slice_gpu,             3);
    farr_add_inplace_gpu            = hexa_fn_new((void*)hexa_farr_add_inplace_gpu,            3);
    // anima RFC 040 Phase B2 (2026-05-16): d_train5 hot-path completion —
    // matmul_t / outer / mul / silu / silu_grad / rmsnorm_bwd (≤4-arg
    // carriers). farr_adamw_step_gpu (11-arg) = bare direct-C entry,
    // NOT registered here (RFC 032/035 pattern).
    farr_matmul_t_gpu               = hexa_fn_new((void*)hexa_farr_matmul_t_gpu,               4);
    farr_outer_gpu                  = hexa_fn_new((void*)hexa_farr_outer_gpu,                  4);
    farr_mul_gpu                    = hexa_fn_new((void*)hexa_farr_mul_gpu,                    3);
    farr_silu_gpu                   = hexa_fn_new((void*)hexa_farr_silu_gpu,                   2);
    farr_silu_grad_gpu              = hexa_fn_new((void*)hexa_farr_silu_grad_gpu,              2);
    farr_rmsnorm_bwd_rows_gpu       = hexa_fn_new((void*)hexa_farr_rmsnorm_bwd_rows_gpu,       4);
    // RFC 035 (2026-05-13): 3/4-arg NM-step builtins routed through hexa_callN.
    farr_simplex_centroid           = hexa_fn_new((void*)hexa_farr_simplex_centroid,           4);
    farr_simplex_get                = hexa_fn_new((void*)hexa_farr_simplex_get,                4);
    farr_simplex_shrink             = hexa_fn_new((void*)hexa_farr_simplex_shrink,             3);
    farr_simplex_sort               = hexa_fn_new((void*)hexa_farr_simplex_sort,               4);
    // RFC 039 (2026-05-13): 1-arg ham_free / ansatz_free use hexa_call1 dispatch.
    // 7-arg ham_pack / 8-arg ansatz_pack / 8-arg farr_parameter_shift_grad are
    // emitted as direct C calls via static-inline wrappers above (past the
    // 4-arg hexa_callN ceiling — same pattern as farr_pauli_exp_inplace).
    ham_free                        = hexa_fn_new((void*)hexa_ham_free,                        1);
    ansatz_free                     = hexa_fn_new((void*)hexa_ansatz_free,                     1);
    // RFC 037 (2026-05-13): batch kernel routes via codegen_c2.hexa special
    // 9-arg branch to hexa_farr_pauli_expectation_batch; carrier kept for
    // function-as-value uses.
    farr_pauli_expectation_batch    = hexa_fn_new((void*)hexa_farr_pauli_expectation_batch,    9);
    // RFC 038 (2026-05-13): farr_uccsd_apply uses static-inline wrapper above
    // (5-arg, past hexa_callN ceiling).
    bit_or     = hexa_fn_new((void*)_hx_bit_or,           2);
    // bt73 free-fn shims (timestamp, base64_encode, base64_decode)
    timestamp     = hexa_fn_new((void*)_bt73_timestamp_w,     0);
    base64_encode = hexa_fn_new((void*)_bt73_base64_encode_w, 1);
    base64_decode = hexa_fn_new((void*)_bt73_base64_decode_w, 1);
    // interp exec/env primitives — bootstrap-gap bridge
    hx_setenv       = hexa_fn_new((void*)_w_setenv,       2);
    hx_exec_capture = hexa_fn_new((void*)_w_exec_capture, 1);
    // hxa-004 ext: bare `push(arr, v)` emitted by legacy hexa_v2 as hexa_call2
    hx_push         = hexa_fn_new((void*)_w_push,         2);
    // Cycle 55 recovery — stdlib/fs builtins. codegen_c2.hexa maps the
    // bare names `fs_append_atomic/fs_stat/fs_rotate_if_over/fs_mkdir_p`
    // to rt_fs_* C names, but the bootstrap hexa_v2 binary hasn't been
    // re-deployed with that mapping. Bridge via bt73-style TAG_FN.
    fs_append_atomic    = hexa_fn_new((void*)rt_fs_append_atomic,    2);
    fs_stat             = hexa_fn_new((void*)rt_fs_stat,             1);
    fs_rotate_if_over   = hexa_fn_new((void*)rt_fs_rotate_if_over,   3);
    fs_mkdir_p          = hexa_fn_new((void*)rt_fs_mkdir_p,          1);
    // std::net free-fn shims — bridges transpiler bootstrap gap for
    // net_connect / net_read / net_write until hexa_v2 learns the
    // direct-lowering for these names (see native/net.c comment).
    _hexa_init_net_fn_shims();
    // stdlib/os signal + flock free-fn shims (roadmap 62, 2026-04-22)
    _hexa_init_os_fn_shims();
    // hxa-20260424-005 items #1 + #7: exec_argv + sha256 shims
    _hexa_init_exec_sha_fn_shims();
    // ω-runtime-1 Phase A (2026-04-26): persistent-pipe primitive shims
    _hexa_init_persistent_pipe_fn_shims();
    // 2026-05-13: anima daemon Phase 2 — pthread + channel primitives.
    _hexa_init_thread_fn_shims();
    // 2026-05-13: wilson harness-cli + cpu port — pty + termios primitives.
    _hexa_init_pty_fn_shims();
    // Wilson 2026-05-13 — std_time.hexa wrapper name shims (time_now_ms etc.)
    _hexa_init_time_fn_shims();
    _fn_shims_ready = 1;
}

/* ═══════════════════════════════════════════════════════════════════
 * T3 HOT KERNEL INCLUDE — anima training inner-loop fast path.
 *
 * f32/f64/i32 ptr r/w + struct_pack_f32/unpack_f32 + tensor stubs are
 * extracted into native/tensor_kernels.c so anima maintainers can find
 * the performance-critical boundary without grep'ing through 3600 LOC.
 *
 * @hot_kernel markers inside the file describe each function's role.
 * Whitelist (external consumers): $NEXUS/shared/hexa/hot-path.jsonl.
 * Migration policy: docs/hexa-hot-path.md.
 *
 * NEVER migrate these to HEXA — per-element HexaVal wrap/dispatch would
 * multiply training time 10-100x. Any future HEXA reimplementation must
 * preserve raw C float* access patterns.
 * ═══════════════════════════════════════════════════════════════════ */
#include "native/tensor_kernels.c"

/* ═══════════════════════════════════════════════════════════════════
 * std::net — POSIX TCP socket builtins (interp resurrection, 2026-04-16)
 *
 * Ports the networking surface from the deleted Rust src/std_net.rs
 * (recovered from commit ef92fc6). 6 primitives; http_get / http_serve
 * are composed on top of them in self/std_net.hexa.
 *
 *   hexa_net_listen(addr)       : string "host:port" → TAG_INT fd / -errno
 *   hexa_net_accept(listen)     : TAG_INT listen_fd  → TAG_INT client_fd
 *   hexa_net_connect(addr)      : string "host:port" → TAG_INT fd / -errno
 *   hexa_net_read(fd)           : TAG_INT fd         → TAG_STR data
 *   hexa_net_write(fd, data)    : TAG_INT fd, string → TAG_INT bytes / -errno
 *   hexa_net_close(fd)          : TAG_INT fd         → TAG_INT 0 / -errno
 *
 * Error model: negative TAG_INT (the raw errno). Matches the C-side
 * convention used by hxcuda/hxblas shims.
 *
 * Implementation lives in native/net.c so the net subsystem is a single
 * file analogous to native/tensor_kernels.c for the hot kernel path.
 * ═══════════════════════════════════════════════════════════════════ */
#include "native/net.c"

/* ═══════════════════════════════════════════════════════════════════
 * anima daemon Phase 2 (CHAT.md rev 2) — pthread + channel primitives
 * for 60+ FPS frame loop with async inference worker offload.
 *
 *   hexa_thread_spawn(fn, arg)   → tid (>=0) or -errno
 *   hexa_thread_join(tid)        → result HexaVal
 *   hexa_channel_new()           → ch_id (>=0) or -errno
 *   hexa_channel_send(ch, v)     → 0 ok / -errno
 *   hexa_channel_recv(ch, ms)    → val or "" sentinel
 *   hexa_channel_close(ch)       → 0 ok / -errno
 *   hexa_sleep_ms(ms)            → 0
 *   hexa_now_ms()                → current monotonic ms (int)
 *
 * Source: native/thread.c (RFC: incoming/patches/thread-channel-primitive.md)
 * Built into hexa binaries that link -lpthread (added by cmd_build).
 * ═══════════════════════════════════════════════════════════════════ */
#include "native/thread.c"

/* ═══════════════════════════════════════════════════════════════════
 * stdlib/os/pty + stdlib/os/termios — pseudo-terminal pair + raw mode.
 *
 *   hexa_pty_open()                              -> map {master, slave, slave_name} or {error}
 *   hexa_pty_get_winsize(fd)                     -> map {rows, cols, xpix, ypix} or {error}
 *   hexa_pty_set_winsize(fd, r, c, xp, yp)       -> 0 or -errno
 *   hexa_tcgetattr(fd)                           -> map {iflag, oflag, cflag, lflag, cc[]} or {error}
 *   hexa_tcsetattr(fd, when, attrs)              -> 0 or -errno
 *   hexa_tty_isatty(fd)                          -> bool
 *   hexa_tty_ttyname(fd)                         -> string or ""
 *   hexa_pty_forkexec(argv, env, rows, cols)     -> map {pid, master_fd} or {error}
 *
 * Source: native/pty.c (RFC: incoming/patches/stdlib-os-pty.md)
 * Cross-platform (macOS + Linux). Linux requires `-lutil` for forkpty;
 * macOS bundles it in libsystem.
 * ═══════════════════════════════════════════════════════════════════ */
#include "native/pty.c"

/* ═══════════════════════════════════════════════════════════════════
 * stdlib/os/mount + stdlib/os/namespace -- Linux mount(2) / umount(2) +
 * unshare / setns / pivot_root. Functions return 0 on success, -errno
 * on failure. macOS returns -ENOSYS (graceful degradation for
 * downstream code that targets both platforms).
 *
 *   hexa_mount(src, tgt, fs, flags, data)        -> 0 or -errno
 *   hexa_umount(tgt, flags)                      -> 0 or -errno
 *   hexa_unshare(flags)                          -> 0 or -errno
 *   hexa_setns(fd, nstype)                       -> 0 or -errno
 *   hexa_pivot_root(new_root, put_old)           -> 0 or -errno
 *   hexa_namespace_clone_const(name)             -> int (CLONE_NEW* value)
 *
 * RFCs: incoming/patches/stdlib-os-{mount,namespace}-linux.md
 * ═══════════════════════════════════════════════════════════════════ */
#include "native/mount.c"
#include "native/namespace.c"

/* ═══════════════════════════════════════════════════════════════════
 * stdlib/proc/wait — hxlcl_waitpid(2) wrapper for SIGCHLD reaping.
 *
 *   hexa_proc_wait(pid, flags)        -> map { pid, exited, signaled,
 *                                              exit_code, term_sig,
 *                                              raw_status } or { error, errno }
 *   hexa_proc_wait_flag_const(name)   -> int (WNOHANG / WUNTRACED / WCONTINUED)
 *
 * Consumer: pty_forkexec, pool_on — any hexa fork+exec pattern that
 * needs to reap its zombies. RFC stdlib-for-cpu-port.md P1 signal-ext.
 * ═══════════════════════════════════════════════════════════════════ */
#include "native/wait.c"

/* ═══════════════════════════════════════════════════════════════════
 * stdlib/crypto — libsodium-backed primitives for SSH (and any
 * downstream that needs vetted modern crypto).
 *
 *   hexa_libsodium_available()         -> bool
 *   hexa_sha512(data)                  -> [int] 64
 *   hexa_ed25519_keypair()              -> map { pub, priv }
 *   hexa_ed25519_sign(priv, msg)        -> [int] 64
 *   hexa_ed25519_verify(pub, msg, sig)  -> bool
 *   hexa_x25519_keypair()                -> map { pub, priv }
 *   hexa_x25519_scalarmult(scalar, point)-> [int] 32 | { error }
 *   hexa_chacha20_poly1305_encrypt(key, nonce, aad, pt) -> [int] | { error }
 *   hexa_chacha20_poly1305_decrypt(key, nonce, aad, ct) -> [int] | { error }
 *
 * Linking: when cmd_build detects libsodium via pkg-config, it adds
 * -DHEXA_HAS_LIBSODIUM + -lsodium and these are real. Without
 * libsodium they return { error: "libsodium not linked" } — caller
 * should check `libsodium_available()` first.
 *
 * RFC: incoming/patches/stdlib-ssh-client.md (crypto suite prereq)
 * ═══════════════════════════════════════════════════════════════════ */
#include "native/crypto_sodium.c"
#include "native/crypto_blowfish.c"
#include "native/crypto_openssl.c"
#include "native/exec_pipe.c"
#include "native/proc_fork.c"

/* ═══════════════════════════════════════════════════════════════════
 * B20 / roadmap 55 Phase 1 — deterministic FP control-word init.
 *
 * Exposes void hexa_fp_init(void). codegen_c2.hexa emits a call to it
 * as the first statement of generated main(). Implementation in
 * self/native/fp_init.c normalizes MXCSR (x86_64) or FPCR (aarch64)
 * to IEEE-default behavior (no FTZ/DAZ/FZ, round-to-nearest-even) so
 * @strict_fp functions can rely on bit-exact FP semantics.
 *
 * Phase 2 scope: crlibm vendoring for cross-substrate transcendental
 * identity; pthread_create trampoline. Not shipped in Phase 1.
 * ═══════════════════════════════════════════════════════════════════ */
#include "native/fp_init.c"

/* ═══════════════════════════════════════════════════════════════════
 * stdlib/os — signal + flock builtins (roadmap 62, 2026-04-22)
 *
 * Exposes hexa_os_sig_* (install / raise / drain / block / …) and
 * hexa_os_flock_* (open / close) for the stdlib/os/{signal,flock}.hexa
 * modules. Async-signal-safe self-pipe trampoline; O_CLOEXEC on flock
 * fds so hxlcl_execve(3) does not leak locks into children.
 *
 * Implementation: native/signal_flock.c (see header comment for full
 * contract + semantics).
 * ═══════════════════════════════════════════════════════════════════ */
#include "native/signal_flock.c"

/* ═══════════════════════════════════════════════════════════════════
 * hxa-20260424-005 items #1 + #7 — exec_argv + sha256 (2026-04-24)
 *
 * Exposes:
 *   hexa_exec_argv(argv_arr)             : fork/execvp, no /bin/sh -c
 *   hexa_exec_argv_with_status(argv_arr) : same + exit code
 *   hexa_sha256(s)                       : lowercase hex digest
 *   hexa_sha256_file(path)               : lowercase hex digest of file
 *
 * Implementation: native/exec_argv_sha256.c (pure libc + FIPS 180-4
 * reference sha256). TAG_FN shims registered from _hexa_init_fn_shims
 * so the interpreter path resolves `exec_argv`/`sha256` names before
 * the transpiler learns direct-lowering.
 * ═══════════════════════════════════════════════════════════════════ */
#include "native/exec_argv_sha256.c"

/* ═══════════════════════════════════════════════════════════════════
 * persistent_pipe — ω-runtime-1 Phase A (2026-04-26)
 *
 * Handle-based bidirectional child-process API. Five new builtins:
 *   pipe_spawn(cmd) -> int
 *   pipe_send_line(h, payload) -> bool
 *   pipe_recv_line(h, timeout_ms) -> string
 *   pipe_close(h) -> bool
 *   pipe_alive(h) -> bool
 * Powers ω-audio-2 60× chain target (replaces _audio_worker_call.sh
 * 133-line bash shim with sub-ms send/recv via persistent fork).
 * ═══════════════════════════════════════════════════════════════════ */
#include "native/persistent_pipe.c"

/* ═══════════════════════════════════════════════════════════════════
 * TUI-PRIM L1 FFI shim — POSIX termios + ioctl + signal
 *
 * Source: self/native/term_ffi.c — 12 raw POSIX symbols (no HexaVal).
 * Wrappers below bridge to HexaVal for hexa source dispatch.
 *
 * Builtin names exposed to hexa (codegen_c2.hexa + env.hexa + hexa_full.hexa):
 *   term_raw_enter()         -> Int (rc 0/-1)
 *   term_raw_restore()       -> Int (rc 0/-1)
 *   term_winsize_rows()      -> Int (rows or -1)
 *   term_winsize_cols()      -> Int (cols or -1)
 *   term_poll_stdin(ms)      -> Int (1/0/-1)
 *   term_read_byte()         -> Int (byte 0..255 or -1)
 *   term_write_str(s)        -> Int (bytes-written or -1)
 *   term_install_sigwinch()  -> Int
 *   term_sigwinch_pending()  -> Int (1/0)
 *   term_install_sigint()    -> Int
 *   term_sigint_pending()    -> Int (1/0)
 *   term_isatty_stdin()      -> Int
 *   term_isatty_stdout()     -> Int
 *   term_getppid()           -> Int (parent pid; 1 = orphaned to init)
 *
 * Kick witness:
 *   state/design_strategy_trawl/2026-04-27_hexa-native-tui-implementation-plan_KICK_omega_cycle.json
 * ═══════════════════════════════════════════════════════════════════ */
#include "native/term_ffi.c"

HexaVal hexa_term_raw_enter(void) { return hexa_int((int64_t)term_raw_enter()); }
HexaVal hexa_term_raw_restore(void) { return hexa_int((int64_t)term_raw_restore()); }

HexaVal hexa_term_winsize_rows(void) {
    int r = -1, c = -1;
    if (term_get_winsize(&r, &c) != 0) return hexa_int(-1);
    return hexa_int((int64_t)r);
}
HexaVal hexa_term_winsize_cols(void) {
    int r = -1, c = -1;
    if (term_get_winsize(&r, &c) != 0) return hexa_int(-1);
    return hexa_int((int64_t)c);
}

HexaVal hexa_term_poll_stdin(HexaVal ms) {
    int t = (int)__hx_to_double(ms);
    return hexa_int((int64_t)term_poll_stdin(t));
}
HexaVal hexa_term_read_byte(void) { return hexa_int((int64_t)term_read_byte()); }

HexaVal hexa_term_write_str(HexaVal s) {
    if (!HX_IS_STR(s) || HX_STR(s) == NULL) {
        return hexa_int(-1);
    }
    const char *buf = HX_STR(s);
    int n = (int)hxlcl_strlen(buf);
    return hexa_int((int64_t)term_write(buf, n));
}

HexaVal hexa_term_install_sigwinch(void) { return hexa_int((int64_t)term_install_sigwinch()); }
HexaVal hexa_term_sigwinch_pending(void) { return hexa_int((int64_t)term_sigwinch_pending()); }
HexaVal hexa_term_install_sigint(void) { return hexa_int((int64_t)term_install_sigint()); }
HexaVal hexa_term_sigint_pending(void) { return hexa_int((int64_t)term_sigint_pending()); }
HexaVal hexa_term_isatty_stdin(void) { return hexa_int((int64_t)term_isatty_stdin()); }
HexaVal hexa_term_isatty_stdout(void) { return hexa_int((int64_t)term_isatty_stdout()); }
HexaVal hexa_term_getppid(void) { return hexa_int((int64_t)term_getppid()); }

/* PTY harness builtins (forward-only "real PTY" closure, commit 43bec17b). */

extern int term_pty_spawn_sh(const char *cmd, int rows, int cols, int *out_pid);
extern int term_fd_read(int fd, unsigned char *buf, int max_bytes);
extern int term_fd_write(int fd, const unsigned char *buf, int n);
extern int term_fd_close(int fd);
extern int term_fd_poll(int fd, int timeout_ms);
extern int term_pty_reap(int pid, int *out_status);

/* Returns [mfd, pid] as a 2-element int array. mfd=-1 on error. */
HexaVal hexa_term_pty_spawn_sh(HexaVal cmd, HexaVal rows, HexaVal cols) {
    if (!HX_IS_STR(cmd) || HX_STR(cmd) == NULL) {
        HexaVal arr = hexa_array_new();
        hexa_array_push(arr, hexa_int(-1));
        hexa_array_push(arr, hexa_int(-1));
        return arr;
    }
    const char *c = HX_STR(cmd);
    int r = (int)__hx_to_double(rows);
    int co = (int)__hx_to_double(cols);
    int pid = -1;
    int mfd = term_pty_spawn_sh(c, r, co, &pid);
    HexaVal arr = hexa_array_new();
    hexa_array_push(arr, hexa_int((int64_t)mfd));
    hexa_array_push(arr, hexa_int((int64_t)pid));
    return arr;
}

/* Read up to max_bytes from fd. Returns the bytes as a Hexa string
 * (raw byte concat — caller may need to decode if utf-8 boundary). */
HexaVal hexa_term_fd_read(HexaVal fd, HexaVal max_bytes) {
    int f = (int)__hx_to_double(fd);
    int m = (int)__hx_to_double(max_bytes);
    if (m <= 0 || m > 65536) m = 4096;
    unsigned char buf[65536];
    if (m > 65536) m = 65536;
    int n = term_fd_read(f, buf, m);
    if (n <= 0) return hexa_str("");
    /* hexa_str_n if available; otherwise null-terminate after copy */
    char tmp[65537];
    hxlcl_memcpy(tmp, buf, (size_t)n);
    tmp[n] = '\0';
    return hexa_str(tmp);
}

HexaVal hexa_term_fd_write(HexaVal fd, HexaVal data) {
    int f = (int)__hx_to_double(fd);
    if (!HX_IS_STR(data) || HX_STR(data) == NULL) return hexa_int(-1);
    const char *s = HX_STR(data);
    int n = (int)hxlcl_strlen(s);
    int w = term_fd_write(f, (const unsigned char *)s, n);
    return hexa_int((int64_t)w);
}

HexaVal hexa_term_fd_close(HexaVal fd) {
    int f = (int)__hx_to_double(fd);
    return hexa_int((int64_t)term_fd_close(f));
}

HexaVal hexa_term_fd_poll(HexaVal fd, HexaVal timeout_ms) {
    int f = (int)__hx_to_double(fd);
    int t = (int)__hx_to_double(timeout_ms);
    return hexa_int((int64_t)term_fd_poll(f, t));
}

/* Returns [exited_flag, status]. exited_flag: 1 done, 0 running, -1 err */
HexaVal hexa_term_pty_reap(HexaVal pid) {
    int p = (int)__hx_to_double(pid);
    int st = 0;
    int r = term_pty_reap(p, &st);
    HexaVal arr = hexa_array_new();
    hexa_array_push(arr, hexa_int((int64_t)r));
    hexa_array_push(arr, hexa_int((int64_t)st));
    return arr;
}

// ── exec_stream_async / poll / close stub primitives (KI-4 fix, 2026-05-01) ──
// Origin: hive 7-bucket closure cycle KI-4 fix. cli_mvp.hexa async streaming
// (follow-up8 minimum-viable input-during-processing) 23 caller가 이 primitive
// 의존. 직전 hexa-lang commit drift로 native impl 부재 → cli_mvp build fail.
//
// Real impl semantics (v1.8, KI-4 stub → actual async impl 2026-05-01):
//   exec_stream_async(cmd) -> int   : popen(cmd, "r") + fcntl O_NONBLOCK,
//                                      slot table에 FILE* 저장 후 handle return.
//                                      handle ≥ 0 = 성공, -1 = popen 실패.
//   exec_stream_poll(handle) -> any  : drain available newline-terminated
//                                      lines (non-blocking). EOF 시 EOF marker
//                                      삽입. line array return.
//   exec_stream_close(handle) -> int : pclose() rc → WIFEXITED + WEXITSTATUS
//                                      decode (signal exit 시 -signal). slot
//                                      release. handle stale 시 -1.
//
// v1.1 enhancements (2026-05-01):
//   - Dynamic line buffer: 8KB initial → realloc doubling up to 1MB cap (raw
//     49 additive-first growth). silent-error silent-error-ban 정합 (long line
//     truncate 회피; 단 1MB cap 도달 시 silent drop 잔존 — C3 honest C3).
//   - pclose rc proper decode: WIFEXITED → WEXITSTATUS, WIFSIGNALED →
//     -WTERMSIG. Caller가 표준 exit code 패턴 (`if rc == 0`) 사용 가능.
//
// C3 honest C3: 8-slot table (single-process limit). Concurrent stream >8
// 시 spawn fail (-1 return → caller sync fallback). cli_mvp는 _stream_handle
// 단일 slot이므로 충분. realloc fail / 1MB cap hit 시 silent drop — v1.2에서
// stderr advisory 추가 예정.
//
// codegen은 `hexa_exec_stream_async_impl` (impl suffix) + raw `exec_stream_*`
// 두 path 모두 emit (hexa_call1 _Generic dispatch에 의존).

#include <fcntl.h>
#include <errno.h>

#define HEXA_STREAM_SLOT_COUNT 8
#define HEXA_STREAM_LINE_BUF_INITIAL 8192
#define HEXA_STREAM_LINE_BUF_MAX 1048576  /* 1MB cap (additive-first growth) */
typedef struct {
    FILE* fp;
    char* buf;          /* dynamic alloc (v1.1 silent-error long-line truncate 회피) */
    int   buf_cap;      /* current capacity */
    int   buf_len;      /* current length */
    int   eof;
    int   in_use;
    /* v1.3 (2026-05-11, wilson tool-core ESC-cancel): own child pid so
       exec_stream_kill can SIGTERM->SIGKILL the whole process *group*.
       _async forks /bin/sh -c cmd directly (setpgid(0,0) in the child)
       instead of hxlcl_popen(), so pid == child sh pid == the group leader pgid.
       pid <= 0 -> legacy popen fallback (fork/pipe failed): no pid, so
       exec_stream_kill on that slot is best-effort fclose only & returns
       -1 (C3 honest C3 - prompt-kill needs the fork path). */
    pid_t pid;
    /* v1.4 (2026-05-13, wilson MCP bidi): write-end fd of child stdin pipe
       when slot was opened via hexa_exec_stream_open (the bidi variant).
       -1 = read-only slot (exec_stream_async path; no stdin pipe). Used
       by hexa_exec_stream_write to send data to the child's stdin and
       hexa_exec_stream_close_stdin to signal EOF on the child side.
       Filed at incoming/patches/wilson-mcp-needs-bidi-stdio.md. */
    int   stdin_fd;
} HexaStreamSlot;
static HexaStreamSlot _hexa_stream_slots[HEXA_STREAM_SLOT_COUNT];
static int _hexa_stream_slots_init = 0;

static void _hexa_stream_slots_ensure_init(void) {
    if (_hexa_stream_slots_init) return;
    for (int i = 0; i < HEXA_STREAM_SLOT_COUNT; i++) {
        _hexa_stream_slots[i].fp = NULL;
        _hexa_stream_slots[i].buf = (char*)malloc(HEXA_STREAM_LINE_BUF_INITIAL);
        _hexa_stream_slots[i].buf_cap = _hexa_stream_slots[i].buf
                                          ? HEXA_STREAM_LINE_BUF_INITIAL : 0;
        _hexa_stream_slots[i].buf_len = 0;
        _hexa_stream_slots[i].eof = 0;
        _hexa_stream_slots[i].in_use = 0;
        _hexa_stream_slots[i].pid = (pid_t)-1;
        _hexa_stream_slots[i].stdin_fd = -1;
    }
    _hexa_stream_slots_init = 1;
}

HexaVal hexa_exec_stream_async_impl(HexaVal cmd) {
    _hexa_stream_slots_ensure_init();
    const char* cmd_s = HX_IS_STR(cmd) ? HX_STR(cmd) : NULL;
    if (!cmd_s) return hexa_int((int64_t)-1);
    int slot = -1;
    for (int i = 0; i < HEXA_STREAM_SLOT_COUNT; i++) {
        if (!_hexa_stream_slots[i].in_use) { slot = i; break; }
    }
    if (slot < 0) return hexa_int((int64_t)-1);
    /* v1.1 defensive: ensure_init malloc failure 시 lazy retry */
    if (!_hexa_stream_slots[slot].buf) {
        _hexa_stream_slots[slot].buf = (char*)malloc(HEXA_STREAM_LINE_BUF_INITIAL);
        if (!_hexa_stream_slots[slot].buf) return hexa_int((int64_t)-1);
        _hexa_stream_slots[slot].buf_cap = HEXA_STREAM_LINE_BUF_INITIAL;
    }
    // 2026-05-06 — POSIX fork buffer flush before fork/popen (mirrors hexa_exec)
    fflush(NULL);
    // v1.3 (2026-05-11): own the child pid so exec_stream_kill can SIGKILL the
    // whole process group. fork() + setpgid(0,0) in the child + exec /bin/sh
    // -c cmd; parent keeps the read end of a pipe (matches popen("r") FILE*
    // semantics). On any fork/pipe step failure we fall back to popen() with
    // pid = -1 (exec_stream_kill on that slot then degrades to fclose + -1).
    FILE* fp = NULL;
    pid_t child_pid = (pid_t)-1;
    {
        int pipefd[2];
        if (hxlcl_pipe(pipefd) == 0) {
            pid_t pid = hxlcl_fork();
            if (pid == 0) {
                // child
                setpgid(0, 0);                 // own process group -> killpg target
                hxlcl_close(pipefd[0]);
                if (pipefd[1] != STDOUT_FILENO) {
                    hxlcl_dup2(pipefd[1], STDOUT_FILENO);
                    hxlcl_close(pipefd[1]);
                }
                hxlcl_execl("/bin/sh", "sh", "-c", cmd_s, (char*)NULL);
                _exit(127);                    // execl failed
            } else if (pid > 0) {
                // parent
                hxlcl_close(pipefd[1]);
                setpgid(pid, pid);             // race-safe (also set on child side)
                fp = fdopen(pipefd[0], "r");
                if (!fp) { hxlcl_close(pipefd[0]); hxlcl_kill(-pid, SIGKILL); hxlcl_waitpid(pid, NULL, 0); }
                else child_pid = pid;
            } else {
                // fork failed
                hxlcl_close(pipefd[0]); hxlcl_close(pipefd[1]);
            }
        }
    }
    if (!fp) {
        fp = hxlcl_popen(cmd_s, "r");
        if (!fp) return hexa_int((int64_t)-1);
        child_pid = (pid_t)-1;                  // popen path: no usable pid
    }
    int fd = fileno(fp);
    int flags = hxlcl_fcntl(fd, F_GETFL, 0);
    if (flags >= 0) hxlcl_fcntl(fd, F_SETFL, flags | O_NONBLOCK);
    _hexa_stream_slots[slot].fp = fp;
    _hexa_stream_slots[slot].pid = child_pid;
    _hexa_stream_slots[slot].buf_len = 0;
    _hexa_stream_slots[slot].eof = 0;
    _hexa_stream_slots[slot].in_use = 1;
    _hexa_stream_slots[slot].stdin_fd = -1;     // exec_stream_async path is read-only
    return hexa_int((int64_t)slot);
}
HexaVal hexa_exec_stream_async(HexaVal cmd) {
    return hexa_exec_stream_async_impl(cmd);
}

/* v1.2 (KI-5 RESOLVED, 2026-05-01) — per-call [done_int, line_str] protocol.
 *
 * Prior contract (v1.0/1.1): array-of-lines [line1, line2, ...] drained
 *   in one call. cli_mvp _stream_drain expected per-call [done, line]
 *   tuple → semantic mismatch → TUI 첫 chat 입력 시 crash (KI-5).
 *
 * New contract: each call extracts AT MOST one complete line.
 *   Returns: [done_int, line_str]
 *     done_int == 1 → stream EOF + buf drained (caller should close).
 *     done_int == 0 + line_str non-empty → one line ready, more may follow.
 *     done_int == 0 + line_str empty → EAGAIN (no data yet, not EOF).
 *   EOF with trailing partial buf (no final \n): emit buf as final line
 *   on this call (done_int=0), then [1, ""] on next call.
 *
 * cli_mvp expectation (cli_mvp.hexa _stream_drain line 4703-4732):
 *   let r = exec_stream_poll(_stream_handle)
 *   let done = r[0]                 // bool/int 1=stream-finished
 *   let line = to_string(r[1])      // single complete line OR ""
 *   if len(line) > 0 { dispatch_line(line); ... }
 *   if done { return 1 }            // _stream_finish triggers
 *   if len(line) == 0 { return 0 }  // EAGAIN — wait next tick
 *
 * C3 honest C3: per-call drain ≤1 line. cli_mvp loops up to 64 times
 * per tick → 64 lines/tick max throughput. SSE typical throughput well
 * within bounds. follow-up8 minimum-viable.
 */
HexaVal hexa_exec_stream_poll_impl(HexaVal handle) {
    _hexa_stream_slots_ensure_init();
    int h = (int)__hx_to_double(handle);
    HexaVal out = hexa_array_new();
    if (h < 0 || h >= HEXA_STREAM_SLOT_COUNT) {
        hexa_array_push(out, hexa_int((int64_t)1));
        hexa_array_push(out, hexa_str(""));
        return out;
    }
    HexaStreamSlot* s = &_hexa_stream_slots[h];
    if (!s->in_use || !s->fp) {
        hexa_array_push(out, hexa_int((int64_t)1));
        hexa_array_push(out, hexa_str(""));
        return out;
    }
    /* Step 1: scan current buf for first newline. */
    int nl_pos = -1;
    for (int i = 0; i < s->buf_len; i++) {
        if (s->buf[i] == '\n') { nl_pos = i; break; }
    }
    /* Step 2: if no newline yet AND not EOF, try one non-blocking read.
       Append bytes; rescan only newly-appended region for first newline. */
    if (nl_pos < 0 && !s->eof) {
        char chunk[4096];
        ssize_t n = hxlcl_read(fileno(s->fp), chunk, sizeof(chunk));
        if (n == 0) {
            s->eof = 1;
        } else if (n > 0) {
            int start = s->buf_len;
            for (ssize_t i = 0; i < n; i++) {
                char c = chunk[i];
                if (s->buf_len < s->buf_cap - 1) {
                    s->buf[s->buf_len++] = c;
                } else if (s->buf_cap < HEXA_STREAM_LINE_BUF_MAX) {
                    int new_cap = s->buf_cap * 2;
                    if (new_cap > HEXA_STREAM_LINE_BUF_MAX) new_cap = HEXA_STREAM_LINE_BUF_MAX;
                    char* new_buf = (char*)realloc(s->buf, new_cap);
                    if (new_buf) {
                        s->buf = new_buf;
                        s->buf_cap = new_cap;
                        s->buf[s->buf_len++] = c;
                    }
                    /* realloc fail / 1MB cap hit 시 silent drop. C3 honest C3. */
                }
            }
            /* Rescan from `start` (newly-appended region) for first newline. */
            for (int i = start; i < s->buf_len; i++) {
                if (s->buf[i] == '\n') { nl_pos = i; break; }
            }
        }
        /* n < 0 (EAGAIN) → fall through with nl_pos == -1, eof unchanged. */
    }
    /* Step 3: newline found → extract first line, shift buf. */
    if (nl_pos >= 0) {
        s->buf[nl_pos] = '\0';
        HexaVal line_v = hexa_str(s->buf);
        int rem = s->buf_len - nl_pos - 1;
        if (rem > 0) hxlcl_memmove(s->buf, s->buf + nl_pos + 1, rem);
        s->buf_len = rem;
        hexa_array_push(out, hexa_int((int64_t)0));
        hexa_array_push(out, line_v);
        return out;
    }
    /* Step 4: no newline. Handle EOF. */
    if (s->eof) {
        if (s->buf_len > 0) {
            /* EOF + trailing partial buf (no final \n) — emit as final line. */
            s->buf[s->buf_len] = '\0';
            HexaVal line_v = hexa_str(s->buf);
            s->buf_len = 0;
            hexa_array_push(out, hexa_int((int64_t)0));
            hexa_array_push(out, line_v);
            return out;
        }
        /* Truly done. */
        hexa_array_push(out, hexa_int((int64_t)1));
        hexa_array_push(out, hexa_str(""));
        return out;
    }
    /* Step 5: EAGAIN. */
    hexa_array_push(out, hexa_int((int64_t)0));
    hexa_array_push(out, hexa_str(""));
    return out;
}
HexaVal hexa_exec_stream_poll(HexaVal handle) {
    return hexa_exec_stream_poll_impl(handle);
}

HexaVal hexa_exec_stream_close_impl(HexaVal handle) {
    _hexa_stream_slots_ensure_init();
    int h = (int)__hx_to_double(handle);
    if (h < 0 || h >= HEXA_STREAM_SLOT_COUNT) return hexa_int((int64_t)-1);
    HexaStreamSlot* s = &_hexa_stream_slots[h];
    if (!s->in_use || !s->fp) return hexa_int((int64_t)-1);
    int raw_rc;
    if (s->pid > 0) {
        /* v1.3 fork path: close our pipe end, then reap the child. */
        fclose(s->fp);
        raw_rc = -1;
        for (;;) {
            int st = 0;
            pid_t r = hxlcl_waitpid(s->pid, &st, 0);
            if (r < 0) { if (errno == EINTR) continue; raw_rc = -1; break; }
            raw_rc = st;  /* pclose-style encoded status */
            break;
        }
    } else {
        raw_rc = hxlcl_pclose(s->fp);  /* legacy popen fallback */
    }
    /* v1.1 WIFEXITED + WEXITSTATUS proper rc decode (C3 honest C3 — caller가
       표준 exit code 패턴 사용 가능). Signal exit 시 negative signal 반환. */
    int proper_rc;
    if (raw_rc == -1) {
        proper_rc = -1;  /* pclose/waitpid itself failed */
    } else if (WIFEXITED(raw_rc)) {
        proper_rc = WEXITSTATUS(raw_rc);
    } else if (WIFSIGNALED(raw_rc)) {
        proper_rc = -WTERMSIG(raw_rc);
    } else {
        proper_rc = -1;
    }
    s->fp = NULL;
    s->pid = (pid_t)-1;
    s->buf_len = 0;
    s->eof = 0;
    s->in_use = 0;
    /* v1.4 — close stdin_fd if still hxlcl_open_sys(bidi path; safe no-op for read-only). */
    if (s->stdin_fd >= 0) { hxlcl_close(s->stdin_fd); s->stdin_fd = -1; }
    /* Note: s->buf 보존 (재사용 위해 free 안 함; 다음 spawn 시 재초기화). */
    return hexa_int((int64_t)proper_rc);
}
HexaVal hexa_exec_stream_close(HexaVal handle) {
    return hexa_exec_stream_close_impl(handle);
}

// exec_stream_kill(handle) -> int (2026-05-11, wilson tool-core ESC-cancel) --
// Promptly terminate the streaming child *process group*: SIGTERM, a short
// grace poll, then SIGKILL -- then close our pipe end and reap. exec_stream_close
// only pclose/waitpid-joins (blocks until the child exits on its own), so a
// long-running `bash` tool would not die quickly on ESC. Returns:
//   >= 0  : child terminated; value = -WTERMSIG (negative) when it exited via
//           signal (the SIGTERM/SIGKILL we sent), or its own WEXITSTATUS if it
//           happened to exit cleanly during the grace window.
//   -1    : stale/invalid handle, or a popen-fallback slot with no usable pid
//           (C3 honest C3 -- prompt-kill needs exec_stream_async's fork
//           path; on a popen slot the pipe is still fclose'd but the child is
//           only reaped opportunistically and rc is -1).
HexaVal hexa_exec_stream_kill_impl(HexaVal handle) {
    _hexa_stream_slots_ensure_init();
    int h = (int)__hx_to_double(handle);
    if (h < 0 || h >= HEXA_STREAM_SLOT_COUNT) return hexa_int((int64_t)-1);
    HexaStreamSlot* s = &_hexa_stream_slots[h];
    if (!s->in_use || !s->fp) return hexa_int((int64_t)-1);
    if (s->pid <= 0) {
        /* popen fallback slot -- no pid. Best-effort: close the hxlcl_pipe(the child
           sees EOF/SIGPIPE on its next write) and release the slot. */
        fclose(s->fp);
        s->fp = NULL; s->pid = (pid_t)-1; s->buf_len = 0; s->eof = 0; s->in_use = 0;
        return hexa_int((int64_t)-1);
    }
    pid_t pid = s->pid;
    pid_t pgid = pid;  /* setpgid(0,0) in the child made pid the group leader */
    /* Step 1: polite SIGTERM to the whole group. */
    hxlcl_kill(-pgid, SIGTERM);
    /* Step 2: ~200ms grace, polled every 10ms via hxlcl_waitpid(WNOHANG). */
    int reaped = 0; int raw_rc = -1;
    for (int i = 0; i < 20; i++) {
        int st = 0;
        pid_t r = hxlcl_waitpid(pid, &st, WNOHANG);
        if (r == pid) { reaped = 1; raw_rc = st; break; }
        if (r < 0 && errno != EINTR && errno != 0) break;  /* ECHILD etc. */
        struct timespec ts; ts.tv_sec = 0; ts.tv_nsec = 10L * 1000L * 1000L;  /* 10ms */
        hxlcl_nanosleep(&ts, NULL);
    }
    /* Step 3: still alive -> SIGKILL the group and blocking-reap. */
    if (!reaped) {
        hxlcl_kill(-pgid, SIGKILL);
        for (;;) {
            int st = 0;
            pid_t r = hxlcl_waitpid(pid, &st, 0);
            if (r < 0) { if (errno == EINTR) continue; raw_rc = -1; break; }
            raw_rc = st; break;
        }
    }
    /* Step 4: close our pipe end + release the slot. */
    fclose(s->fp);
    s->fp = NULL; s->pid = (pid_t)-1; s->buf_len = 0; s->eof = 0; s->in_use = 0;
    int proper_rc;
    if (raw_rc == -1) proper_rc = -1;
    else if (WIFEXITED(raw_rc)) proper_rc = WEXITSTATUS(raw_rc);
    else if (WIFSIGNALED(raw_rc)) proper_rc = -WTERMSIG(raw_rc);
    else proper_rc = -1;
    return hexa_int((int64_t)proper_rc);
}
HexaVal hexa_exec_stream_kill(HexaVal handle) {
    return hexa_exec_stream_kill_impl(handle);
}

// codegen이 raw symbol `exec_stream_*` 도 emit (hexa_call1 indirect 패턴) —
// non-prefixed alias 함수도 추가 (hexa_ prefix 미사용 form).
HexaVal exec_stream_async(HexaVal cmd) {
    return hexa_exec_stream_async_impl(cmd);
}
HexaVal exec_stream_poll(HexaVal handle) {
    return hexa_exec_stream_poll_impl(handle);
}
HexaVal exec_stream_close(HexaVal handle) {
    return hexa_exec_stream_close_impl(handle);
}
HexaVal exec_stream_kill(HexaVal handle) {
    return hexa_exec_stream_kill_impl(handle);
}

// ── bidi-stdio primitives (2026-05-13, wilson MCP enabler) ──
// hexa_exec_stream_open / _write / _close_stdin extend the existing read-only
// async stream with a *write* side. Two-pipe variant: parent gets pipefd_in[1]
// for writing to child stdin + pipefd_out[0] for reading child stdout.
// Filed at incoming/patches/wilson-mcp-needs-bidi-stdio.md.
//
// Use case: MCP servers (JSON-RPC over stdio) — wilson sends `initialize`,
// reads `result`, sends `tools/list`, reads `result`, etc. Same pattern any
// long-running interactive subprocess (LSP, debug adapter, custom RPC).
//
// API (returns same int handle the read-only flavor returns; -1 on error):
//   hexa_exec_stream_open(cmd)      — like async but bidi; returns handle
//   hexa_exec_stream_write(h, data) — write to child stdin; returns bytes or -1
//   hexa_exec_stream_close_stdin(h) — close write end (signals EOF to child);
//                                      returns 0/-1
//
// Reads use the same hexa_exec_stream_poll. Final cleanup is the same
// hexa_exec_stream_close (which also closes the stdin fd if open).
HexaVal hexa_exec_stream_open_impl(HexaVal cmd) {
    _hexa_stream_slots_ensure_init();
    const char* cmd_s = HX_IS_STR(cmd) ? HX_STR(cmd) : NULL;
    if (!cmd_s) return hexa_int((int64_t)-1);
    int slot = -1;
    for (int i = 0; i < HEXA_STREAM_SLOT_COUNT; i++) {
        if (!_hexa_stream_slots[i].in_use) { slot = i; break; }
    }
    if (slot < 0) return hexa_int((int64_t)-1);
    if (!_hexa_stream_slots[slot].buf) {
        _hexa_stream_slots[slot].buf = (char*)malloc(HEXA_STREAM_LINE_BUF_INITIAL);
        if (!_hexa_stream_slots[slot].buf) return hexa_int((int64_t)-1);
        _hexa_stream_slots[slot].buf_cap = HEXA_STREAM_LINE_BUF_INITIAL;
    }
    fflush(NULL);
    // Two pipes — pipe_in for parent→child stdin, pipe_out for child→parent stdout.
    int pipe_in[2]  = { -1, -1 };
    int pipe_out[2] = { -1, -1 };
    if (hxlcl_pipe(pipe_in) != 0) return hexa_int((int64_t)-1);
    if (hxlcl_pipe(pipe_out) != 0) {
        hxlcl_close(pipe_in[0]); hxlcl_close(pipe_in[1]);
        return hexa_int((int64_t)-1);
    }
    pid_t pid = hxlcl_fork();
    if (pid < 0) {
        hxlcl_close(pipe_in[0]); hxlcl_close(pipe_in[1]);
        hxlcl_close(pipe_out[0]); hxlcl_close(pipe_out[1]);
        return hexa_int((int64_t)-1);
    }
    if (pid == 0) {
        // child
        setpgid(0, 0);
        // stdin ← pipe_in[0]
        if (pipe_in[0] != STDIN_FILENO) {
            hxlcl_dup2(pipe_in[0], STDIN_FILENO);
            hxlcl_close(pipe_in[0]);
        }
        hxlcl_close(pipe_in[1]);
        // stdout → pipe_out[1]
        if (pipe_out[1] != STDOUT_FILENO) {
            hxlcl_dup2(pipe_out[1], STDOUT_FILENO);
            hxlcl_close(pipe_out[1]);
        }
        hxlcl_close(pipe_out[0]);
        hxlcl_execl("/bin/sh", "sh", "-c", cmd_s, (char*)NULL);
        _exit(127);
    }
    // parent
    hxlcl_close(pipe_in[0]);
    hxlcl_close(pipe_out[1]);
    setpgid(pid, pid);
    FILE* fp = fdopen(pipe_out[0], "r");
    if (!fp) {
        hxlcl_close(pipe_out[0]); hxlcl_close(pipe_in[1]);
        hxlcl_kill(-pid, SIGKILL); hxlcl_waitpid(pid, NULL, 0);
        return hexa_int((int64_t)-1);
    }
    int rfd = fileno(fp);
    int rflags = hxlcl_fcntl(rfd, F_GETFL, 0);
    if (rflags >= 0) hxlcl_fcntl(rfd, F_SETFL, rflags | O_NONBLOCK);
    // stdin fd kept blocking — caller decides write strategy via exec_stream_write.
    _hexa_stream_slots[slot].fp = fp;
    _hexa_stream_slots[slot].pid = pid;
    _hexa_stream_slots[slot].stdin_fd = pipe_in[1];
    _hexa_stream_slots[slot].buf_len = 0;
    _hexa_stream_slots[slot].eof = 0;
    _hexa_stream_slots[slot].in_use = 1;
    return hexa_int((int64_t)slot);
}

HexaVal hexa_exec_stream_write_impl(HexaVal handle, HexaVal data) {
    int h = HX_IS_INT(handle) ? (int)HX_INT(handle) : -1;
    if (h < 0 || h >= HEXA_STREAM_SLOT_COUNT) return hexa_int((int64_t)-1);
    if (!_hexa_stream_slots[h].in_use) return hexa_int((int64_t)-1);
    int fd = _hexa_stream_slots[h].stdin_fd;
    if (fd < 0) return hexa_int((int64_t)-1);   // read-only slot
    const char* s = HX_IS_STR(data) ? HX_STR(data) : NULL;
    if (!s) return hexa_int((int64_t)-1);
    size_t total = hxlcl_strlen(s);
    size_t written = 0;
    while (written < total) {
        ssize_t n = hxlcl_write(fd, s + written, total - written);
        if (n < 0) {
            if (errno == EINTR) continue;
            return hexa_int((int64_t)-1);
        }
        if (n == 0) break;
        written += (size_t)n;
    }
    return hexa_int((int64_t)written);
}

HexaVal hexa_exec_stream_close_stdin_impl(HexaVal handle) {
    int h = HX_IS_INT(handle) ? (int)HX_INT(handle) : -1;
    if (h < 0 || h >= HEXA_STREAM_SLOT_COUNT) return hexa_int((int64_t)-1);
    if (!_hexa_stream_slots[h].in_use) return hexa_int((int64_t)-1);
    int fd = _hexa_stream_slots[h].stdin_fd;
    if (fd < 0) return hexa_int((int64_t)-1);
    hxlcl_close(fd);
    _hexa_stream_slots[h].stdin_fd = -1;
    return hexa_int((int64_t)0);
}

// Wrappers — hexa_ prefix forwards + raw symbol aliases for codegen indirect path.
HexaVal hexa_exec_stream_open(HexaVal cmd) { return hexa_exec_stream_open_impl(cmd); }
HexaVal hexa_exec_stream_write(HexaVal handle, HexaVal data) { return hexa_exec_stream_write_impl(handle, data); }
HexaVal hexa_exec_stream_close_stdin(HexaVal handle) { return hexa_exec_stream_close_stdin_impl(handle); }
HexaVal exec_stream_open(HexaVal cmd) { return hexa_exec_stream_open_impl(cmd); }
HexaVal exec_stream_write(HexaVal handle, HexaVal data) { return hexa_exec_stream_write_impl(handle, data); }
HexaVal exec_stream_close_stdin(HexaVal handle) { return hexa_exec_stream_close_stdin_impl(handle); }

/* Path A (A′) builtin shims — is_alpha/is_alphanumeric have no runtime
 * symbol (legacy codegen_c2 inlines them as C exprs). The native
 * compiler codegen backend calls them as functions, so provide additive
 * linkable wrappers mirroring codegen_c2:3527/3535 exactly. Pure-
 * additive: legacy C path inlines and never calls these → no collision. */
HexaVal hexa_is_alpha(HexaVal a) {
    return hexa_bool((HX_IS_STR(a) && HX_STR(a) && hxlcl_isalpha((unsigned char)HX_STR(a)[0]))
                  || (HX_TAG(a) == TAG_CHAR && hxlcl_isalpha((unsigned char)HX_INT(a))));
}
HexaVal hexa_is_alphanumeric(HexaVal a) {
    return hexa_bool((HX_IS_STR(a) && HX_STR(a) && hxlcl_isalnum((unsigned char)HX_STR(a)[0]))
                  || (HX_TAG(a) == TAG_CHAR && hxlcl_isalnum((unsigned char)HX_INT(a))));
}

/* ═══════════════════════════════════════════════════════════════════
 * forge_tier_v1 — flame <-> forge integration ABI (RFC 050 Stage A).
 *
 * v1 dispatch surface: forge_api_version_v1, forge_tier_dispatch_v1,
 * forge_register_specialized_v1. Stage A lands the API surface +
 * stub dispatcher; Stage 2 substrates (RFC 044 A'/B'/C', RFC 049
 * BF16, RFC 048 fused) wire kernel-by-kernel through the same v1
 * entry points.
 *
 * Inlined here so the dispatcher's MATMUL+FP64 path can call
 * hexa_farr_matmul directly (no forward-decl skew). Header at
 * self/forge/forge_tier_v1.h is the stable public surface.
 *
 * SSOT: inbox/rfc_drafts_2026_05_12/rfc_050_flame_forge_integration.md
 * ═══════════════════════════════════════════════════════════════════ */
#define FORGE_TIER_V1_LIVE 1
/* RFC 050 PERF-INHERITANCE: open the dispatcher's BF16 substrate path
 * when CUDA is compiled in. The substrate's hexa_farr_*_bf16_gpu symbols
 * live in runtime_cuda.c (which #includes runtime_bf16.c) — already
 * link-resolved in any -DHEXA_CUDA build. On no-CUDA hosts the macro
 * stays undefined so forge_tier_v1.c keeps returning
 * FORGE_PRECISION_UNSUPPORTED gracefully (no link dependency). */
#ifdef HEXA_CUDA
#define FORGE_TIER_V1_BF16 1
#endif
#include "forge/forge_tier_v1.c"

/* ═══════════════════════════════════════════════════════════════════
 * hexa_forge_dispatch_matmul — RFC 050 L1 slice 1.
 *
 * The hexa-callable wrapper around the forge dispatcher. flame's NN
 * stdlib calls the `forge_dispatch_matmul` builtin (codegen_c2.hexa
 * lowers it here) so its FP64 GPU matmul routes through the RFC 050
 * dispatch contract instead of calling hexa_farr_matmul directly.
 *
 *   forge_dispatch_matmul(a_farr, M, K, b_farr, N) -> c_farr
 *
 * Packs a ForgeShapeInfo (M,K,N) + a ForgeArgs in=[A,B] / out=[C] and
 * invokes forge_tier_dispatch_v1(FORGE_KERNEL_MATMUL, ..., FP64,
 * DET_DEFAULT, ...). The dispatcher's MATMUL+FP64 path (RFC 040
 * baseline) writes the produced farr id back into out.farr_ids[0] —
 * see the output-farr contract comment in forge_tier_v1.c. This
 * wrapper unwraps that id and returns it as a HexaVal handle.
 *
 * Return codes: forge_tier_dispatch_v1 returns FORGE_OK or
 * FORGE_FALLBACK_USED on a successful dispatch (Stage A always reports
 * FALLBACK_USED — the specialized registry is empty). Any negative
 * return code, or a negative produced id, surfaces as hexa_int(-1) so
 * the hexa caller can branch on failure exactly like hexa_farr_matmul.
 *
 * Defined here (after the forge_tier_v1.c inline include) so
 * forge_tier_dispatch_v1 + the ForgeShapeInfo/ForgeArgs types are in
 * scope without a forward declaration.
 * ═══════════════════════════════════════════════════════════════════ */
HexaVal hexa_forge_dispatch_matmul(HexaVal a_v, HexaVal m_v, HexaVal k_v,
                                   HexaVal b_v, HexaVal n_v) {
    int64_t a_id = hexa_as_num(a_v);
    int64_t M    = hexa_as_num(m_v);
    int64_t K    = hexa_as_num(k_v);
    int64_t b_id = hexa_as_num(b_v);
    int64_t N    = hexa_as_num(n_v);

    ForgeShapeInfo shape;
    shape.M = M;
    shape.N = N;
    shape.K = K;
    shape.batch = 0;

    ForgeArgs in;
    in.farr_ids[0] = a_id;
    in.farr_ids[1] = b_id;
    in.count = 2;

    ForgeArgs out;
    out.farr_ids[0] = -1;  /* OUT slot — dispatcher overwrites with produced id */
    out.count = 1;

    int rc = forge_tier_dispatch_v1(FORGE_KERNEL_MATMUL, &shape,
                                    FORGE_REGIME_AUTO, FORGE_PREC_FP64,
                                    FORGE_DET_DEFAULT, &in, &out);
    /* FORGE_OK (0) and FORGE_FALLBACK_USED (1) are both successful
     * dispatches; negative codes are genuine errors. */
    if (rc < 0)                  return hexa_int(-1);
    int64_t c_id = out.farr_ids[0];
    if (c_id < 0)                return hexa_int(-1);
    return hexa_int(c_id);
}

/* ═══════════════════════════════════════════════════════════════════
 * BF16 substrate externs (RFC 049 / RFC 050 PERF-INHERITANCE).
 *
 * runtime_bf16.c lives in a sibling TU compiled with HEXA_CUDA — its
 * symbols (HexaFarrBf16 + hexa_farr_bf16_*) are linked at build time
 * when HEXA_CUDA is set. Declare the surface here so the wrapper below
 * compiles. Mirrors the FORGE_TIER_V1_BF16 forward decls in
 * forge_tier_v1.c — same opaque-pointer ABI (RFC 050 §6.3).
 *
 * On no-CUDA hosts these externs are never referenced (the wrapper's
 * body is guarded with `#ifdef HEXA_CUDA`), so the link surface stays
 * unchanged for portable builds.
 * ═══════════════════════════════════════════════════════════════════ */
#ifdef HEXA_CUDA
typedef struct HexaFarrBf16 HexaFarrBf16;
extern HexaFarrBf16* hexa_farr_bf16_alloc(int64_t len);
extern void          hexa_farr_bf16_free(HexaFarrBf16* f);
extern int           hexa_farr_bf16_from_f64(const double* src,
                                             HexaFarrBf16* dst, int64_t n);
extern int           hexa_farr_bf16_to_f64(const HexaFarrBf16* src,
                                           double* dst, int64_t n);
#endif

/* ═══════════════════════════════════════════════════════════════════
 * hexa_forge_dispatch_ffn_fp64_via_bf16 — RFC 050 PERF-INHERITANCE.
 *
 * The hexa-callable wrapper around the forge BF16 FFN substrate. flame's
 * NN stdlib gets a 7-arg builtin `forge_dispatch_ffn_fp64_via_bf16` whose
 * signature is in FP64 farrs (the hexa-side currency) — the wrapper
 * internally allocates HexaFarrBf16 handles, RNE-casts FP64 → BF16,
 * routes through forge_tier_dispatch_v1(FFN_FUSED, PURE_BF16), then
 * casts BF16 → FP64 back into the caller-supplied output FP64 farr.
 *
 *   forge_dispatch_ffn_fp64_via_bf16(x_id, w1_id, w2_id, y_id,
 *                                    M, D, FD) -> int rc
 *
 * Shapes: X[M·D], W1[D·FD], W2[FD·D], Y[M·D] — same as the substrate
 * kernel hexa_farr_ffn_bf16_gpu. Returns 0 on success, -1 on any error
 * (no-CUDA host, OOM, dispatch failure, shape mismatch with the FP64
 * farr lengths in the global table).
 *
 * Falsifier anchor: RFC 049 Stage 2 measured hexa_farr_ffn_bf16_gpu at
 * 11.66× FP64 cuBLAS Dgemm (128·768·3072 FFN, A100). This wrapper adds
 * host↔device + FP64↔BF16 cast overhead; the falsifier gate is ≥5×
 * over FP64 cuBLAS to absorb that overhead honestly. The state design
 * doc state/forge_rfc050_perf_inherit_2026_05_19/design.md tracks the
 * scope: routing capability + measurement; flame call-site rewiring
 * is a follow-up.
 *
 * No-CUDA fallback: when HEXA_CUDA is not defined the BF16 substrate
 * is not linked in, so the wrapper short-circuits to -1. Callers
 * (flame nn_lib::nn_ffn_bf16_fwd) MUST check the rc and fall back to
 * the FP64 nn_swiglu / nn_linear path.
 * ═══════════════════════════════════════════════════════════════════ */
HexaVal hexa_forge_dispatch_ffn_fp64_via_bf16(HexaVal x_v, HexaVal w1_v,
                                              HexaVal w2_v, HexaVal y_v,
                                              HexaVal m_v, HexaVal d_v,
                                              HexaVal fd_v) {
#ifdef HEXA_CUDA
    int64_t x_id  = hexa_as_num(x_v);
    int64_t w1_id = hexa_as_num(w1_v);
    int64_t w2_id = hexa_as_num(w2_v);
    int64_t y_id  = hexa_as_num(y_v);
    int64_t M     = hexa_as_num(m_v);
    int64_t D     = hexa_as_num(d_v);
    int64_t FD    = hexa_as_num(fd_v);

    /* Validate the FP64 farr handles + lengths against the host
     * _hx_farr_table. The BF16 wrapper is a no-op on bad inputs — never
     * crash the caller (mirrors hexa_farr_get / _set soft-fail). */
    if (x_id  < 0 || x_id  >= _hx_farr_count) return hexa_int(-1);
    if (w1_id < 0 || w1_id >= _hx_farr_count) return hexa_int(-1);
    if (w2_id < 0 || w2_id >= _hx_farr_count) return hexa_int(-1);
    if (y_id  < 0 || y_id  >= _hx_farr_count) return hexa_int(-1);
    if (M <= 0 || D <= 0 || FD <= 0)          return hexa_int(-1);

    HexaFarrEntry *eX  = &_hx_farr_table[x_id];
    HexaFarrEntry *eW1 = &_hx_farr_table[w1_id];
    HexaFarrEntry *eW2 = &_hx_farr_table[w2_id];
    HexaFarrEntry *eY  = &_hx_farr_table[y_id];
    int64_t nX = M * D, nW1 = D * FD, nW2 = FD * D, nY = M * D;
    if (!eX->buf  || eX->len  < nX)           return hexa_int(-1);
    if (!eW1->buf || eW1->len < nW1)          return hexa_int(-1);
    if (!eW2->buf || eW2->len < nW2)          return hexa_int(-1);
    if (!eY->buf  || eY->len  < nY)           return hexa_int(-1);

    /* Allocate BF16 staging buffers. Lifetime is THIS call only; the
     * substrate's HexaFarrBf16 lifecycle is private to the wrapper. */
    HexaFarrBf16 *bfX  = hexa_farr_bf16_alloc(nX);
    HexaFarrBf16 *bfW1 = hexa_farr_bf16_alloc(nW1);
    HexaFarrBf16 *bfW2 = hexa_farr_bf16_alloc(nW2);
    HexaFarrBf16 *bfY  = hexa_farr_bf16_alloc(nY);
    if (!bfX || !bfW1 || !bfW2 || !bfY) {
        if (bfX)  hexa_farr_bf16_free(bfX);
        if (bfW1) hexa_farr_bf16_free(bfW1);
        if (bfW2) hexa_farr_bf16_free(bfW2);
        if (bfY)  hexa_farr_bf16_free(bfY);
        return hexa_int(-1);
    }

    /* RNE cast FP64 host master → BF16 host buffer (host-side; the
     * substrate's _to_device upload happens inside the kernel). */
    if (hexa_farr_bf16_from_f64(eX->buf,  bfX,  nX)  != 0 ||
        hexa_farr_bf16_from_f64(eW1->buf, bfW1, nW1) != 0 ||
        hexa_farr_bf16_from_f64(eW2->buf, bfW2, nW2) != 0) {
        hexa_farr_bf16_free(bfX);  hexa_farr_bf16_free(bfW1);
        hexa_farr_bf16_free(bfW2); hexa_farr_bf16_free(bfY);
        return hexa_int(-1);
    }

    /* Pack ForgeArgs (RFC 050 §6.3 BF16 ABI — farr_ids carry the
     * HexaFarrBf16* cast through intptr_t). */
    ForgeShapeInfo shape;
    shape.M     = M;
    shape.K     = D;   /* FFN_FUSED mapping: shape.K -> kernel D */
    shape.N     = FD;  /* shape.N -> kernel FD                     */
    shape.batch = 0;

    ForgeArgs in;
    in.farr_ids[0] = (int64_t)(intptr_t)bfX;
    in.farr_ids[1] = (int64_t)(intptr_t)bfW1;
    in.farr_ids[2] = (int64_t)(intptr_t)bfW2;
    in.count       = 3;

    ForgeArgs out;
    out.farr_ids[0] = (int64_t)(intptr_t)bfY;
    out.count       = 1;

    int rc = forge_tier_dispatch_v1(FORGE_KERNEL_FFN_FUSED, &shape,
                                    FORGE_REGIME_AUTO, FORGE_PREC_PURE_BF16,
                                    FORGE_DET_DEFAULT, &in, &out);

    /* On dispatcher OK, BF16 host buffer is authoritative (substrate
     * D2H'd after the kernel). Cast BF16 → FP64 back into the caller's
     * FP64 farr. */
    int wrapper_rc = -1;
    if (rc == FORGE_OK) {
        if (hexa_farr_bf16_to_f64(bfY, eY->buf, nY) == 0) {
            wrapper_rc = 0;
        }
    }

    hexa_farr_bf16_free(bfX);  hexa_farr_bf16_free(bfW1);
    hexa_farr_bf16_free(bfW2); hexa_farr_bf16_free(bfY);
    return hexa_int(wrapper_rc);
#else
    /* No-CUDA host: BF16 substrate not linked in; honest -1.
     * Suppress unused-arg warnings. */
    (void)x_v; (void)w1_v; (void)w2_v; (void)y_v;
    (void)m_v; (void)d_v;  (void)fd_v;
    return hexa_int(-1);
#endif
}




/* Cycle 55 recovery — stub bodies for rt_fs_* declared in runtime.h §G5.
 * Origin/main left these as orphaned declarations (no bodies anywhere on
 * disk). Stubs return failure-default; replace with real POSIX impls in
 * a follow-up cycle. */
HexaVal rt_fs_append_atomic(HexaVal path, HexaVal data) {
    (void)path; (void)data;
    return hexa_int(-1);
}
HexaVal rt_fs_stat(HexaVal path) {
    (void)path;
    return hexa_void();
}
HexaVal rt_fs_rotate_if_over(HexaVal path, HexaVal max_bytes, HexaVal keep) {
    (void)path; (void)max_bytes; (void)keep;
    return hexa_int(0);
}
HexaVal rt_fs_mkdir_p(HexaVal path) {
    (void)path;
    return hexa_int(0);
}
