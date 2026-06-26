/* self/runtime_core_hxlcl_shim.c — RFC061 zero-c #29 sibling-shim TU.
 *
 * WHAT THIS IS
 * ────────────
 * When runtime_core.c is compiled as a STANDALONE TU (#include-drop path), it
 * still REFERENCES the hxlcl_* file-local helpers that the surrounding FROZEN
 * runtime.c blob defines `static` (libc/syscall wrappers — hxlcl_malloc,
 * hxlcl_strlen, hxlcl_strcmp, hxlcl_getenv, …). Because those defs are `static`
 * inside the frozen blob, they are NOT externally linkable — so a standalone
 * runtime_core.o has 57 undefined hxlcl_* references.
 *
 * This sibling TU (NON-FROZEN — never edits the frozen blob) DEFINES the
 * hxlcl_* surface with EXTERNAL linkage, delegating to the C standard library /
 * POSIX. runtime_core.o (drop-ON) then links against THIS .o instead of the
 * frozen statics. The frozen blob keeps its own statics for the DEFAULT
 * (non-drop) #else path — entirely untouched.
 *
 * Behavioral note: the frozen hxlcl_* helpers are hand-rolled raw
 * (mmap-allocator, syscall I/O, hand-coded strlen) for the 0-libc-extern floor.
 * This shim re-supplies them as libc delegates — behaviorally equivalent for
 * the compile+link measurement (the standalone-TU compilability question), but
 * NOT byte-identical machine code (a libc delegate, not the raw floor body).
 * It is built + linked ONLY under the opt-in flag HEXA_ZEROC_RTCORE_SHIM_TU
 * (default OFF). The DEFAULT build never sees it; the frozen statics serve.
 *

 * ── M6 BYTE-IDENTICAL EMIT (HEXA_ZEROC_SHIM_BYTEID_EMIT, default OFF) ──────
 * Under this opt-in arm, 20 hxlcl_* carry the VERBATIM frozen runtime.c body
 * (not a libc delegate) — the 0-libc-extern floor machine code. Measured on
 * aiden x86_64-linux (clang 18.1.3), relocation-normalized objdump vs the
 * isolated frozen body: 18/20 BYTE-IDENTICAL (strlen memcmp memcpy memset
 * strcat strchr strcmp strcpy strncmp strncpy strstr strtoll free backtrace
 * calloc getenv atoi backtrace_symbols_fd). 2 (strdup, realloc) are
 * whole-module-context-sensitive: clang lowers their inner copy loop to a
 * `call memcpy` in the full 57-fn TU but auto-vectorizes it (SSE movups) in
 * an isolated TU — byte-identity to the real frozen body is determined by the
 * 14663-line runtime.c TU context (darwin-arm64-only full compile); not a
 * fixable source divergence (identical source, optimizer cost-model differs).
 * All BYTEID arms carry __attribute__((noinline)) matching frozen so callers
 * emit `call` (no cross-inline), matching the frozen co-located codegen.
 *
 * The remaining 37 hxlcl_* are NOT byte-id-emittable in this isolated TU:
 *   • 12 raw-syscall (read/write/close/lseek/fcntl/dup2/mkdir/poll/stat/
 *     waitpid/pipe/open_sys/clock_gettime): frozen body is arm64-Darwin
 *     `svc #0x80` inline-asm (HXLCL_SYS_* Darwin numbers) — a different ISA
 *     than x86_64; byte-id only on darwin-arm64, and only with the frozen
 *     _hxlcl_syscall*_cf helpers (raw-floor, .s seed territory).
 *   • 3 raw-asm (setjmp/longjmp = arm64 naked stp/ldp; fork = arm64 svc):
 *     arch-specific naked asm; won't compile on x86_64.
 *   • 14 rt_*-delegate (cos/sin/exp/log/fmod/atof/atoll/atexit/time/setenv/
 *     signal/getrusage/strftime/task_info): frozen body delegates to the
 *     HI-tier hexa-source stdlib via HX_FLOAT(rt_sin(hexa_float(x))) and friends —
 *     byte-id-to-frozen = the SAME rt_ + HexaVal call (NOT a libc sin), which
 *     needs the HexaVal ABI + rt_* (supplied only in the real drop-ON link,
 *     not this libc-only shim TU). Delegate-by-design — faithful when linked
 *     with the runtime, not as a standalone libc passthrough.
 *   • 8 composite (malloc/fopen/fread/ftell/fseek/popen/pclose/execvp): frozen
 *     body chains other frozen helpers (hxlcl_mmap bump-alloc, _hxlcl_fp_fd,
 *     _hxlcl_popen_remember, hxlcl_execve, hxlcl_fdopen) NOT in the 57 — a
 *     verbatim emit cascades into pulling those frozen statics too (M6 r2).
 *
 * SSOT signatures mirror the frozen runtime.c hxlcl_* declarations (extracted
 * 2026-06-24, file:line cited in the SSOT memory project_hexa_rfc061_ladder).
 */
#define _GNU_SOURCE
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <math.h>
#include <time.h>
#include <setjmp.h>
#include <poll.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <sys/resource.h>
#if defined(__linux__) && defined(__GLIBC__)
#include <execinfo.h>  /* glibc-only extension; musl lacks it (backtrace stubs below) */
#endif

extern char **environ;

/* ── BYTEID-emit floor helpers (only when the byte-identical arm is active) ──
 * The verbatim frozen hxlcl_* bodies (realloc header offset, backtrace_symbols_fd
 * sink) reference the frozen blob's private macros/helpers. Re-declare them here
 * so the BYTEID arm compiles to machine code byte-identical to the frozen body.
 * (Runtime correctness of header-coupled realloc additionally requires the
 * malloc BYTEID arm; the byte-id-EMIT question is per-function compilation.) */
#ifdef HEXA_ZEROC_SHIM_BYTEID_EMIT
#ifndef HXLCL_HDR_BYTES
#define HXLCL_HDR_BYTES 16
#endif
long hxlcl_write(int fd, const void *buf, unsigned long n);
#endif

/* ── mem / alloc ─────────────────────────────────────────────────────────── */
void *__attribute__((noinline)) hxlcl_malloc(size_t n) { return malloc(n ? n : 1); }
#ifdef HEXA_ZEROC_SHIM_BYTEID_EMIT
/* byte-identical to frozen self/runtime.c hxlcl_free (verbatim 0-libc floor body) */
void __attribute__((noinline)) hxlcl_free(void *p) {
    (void)p;
}
#else
void   hxlcl_free(void *p)                            { free(p); }
#endif
#ifdef HEXA_ZEROC_SHIM_BYTEID_EMIT
/* byte-identical to frozen self/runtime.c hxlcl_realloc (verbatim 0-libc floor body) */
void *__attribute__((noinline)) hxlcl_realloc(void *p, size_t n) {
    if (!p) return hxlcl_malloc(n);
    if (n == 0) return (void *)0;
    void *np = hxlcl_malloc(n);
    if (!np) return (void *)0;
    // Header-tracked old size: clamp the memcpy so we never read past
    // the original allocation's end (the pre-fix over-read crashed when
    // n > old_n and old_n's chunk boundary fell inside [p .. p+n)).
    size_t old_n = *(size_t *)((char *)p - HXLCL_HDR_BYTES);
    size_t copy_n = (n < old_n) ? n : old_n;
    unsigned char *d = (unsigned char *)np;
    const unsigned char *s = (const unsigned char *)p;
    for (size_t i = 0; i < copy_n; i++) d[i] = s[i];
    return np;
}
#else
void  *hxlcl_realloc(void *p, size_t n)               { return realloc(p, n); }
#endif
#ifdef HEXA_ZEROC_SHIM_BYTEID_EMIT
/* byte-identical to frozen self/runtime.c hxlcl_calloc (verbatim 0-libc floor body) */
void *__attribute__((noinline)) hxlcl_calloc(size_t nmemb, size_t size) {
    size_t total = nmemb * size;
    void *p = hxlcl_malloc(total);
    if (p) {
        unsigned char *q = (unsigned char *)p;
        for (size_t i = 0; i < total; i++) q[i] = 0;
    }
    return p;
}
#else
void  *hxlcl_calloc(size_t nmemb, size_t size)        { return calloc(nmemb ? nmemb : 1, size ? size : 1); }
#endif
/* SELFEMIT (HEXA_RT_SELFEMIT_MEMCPY, default OFF · RFC061 §M8 family r3):
 * hxlcl_memcpy is supplied by the hexa-NATIVE self-emitted .o
 * (test/native_build/emit_hxlcl_memcpy_o.hexa — verbatim rt_memcpy byte loop, no
 * reloc/errno). DEFAULT (macro undefined) keeps the body below → shim.o
 * byte-identical. */
#ifndef HEXA_RT_SELFEMIT_MEMCPY
#ifdef HEXA_ZEROC_SHIM_BYTEID_EMIT
/* byte-identical to frozen runtime.c:553 (hand-rolled byte loop) */
void *__attribute__((noinline)) hxlcl_memcpy(void *dst, const void *src, size_t n) {
    unsigned char *d = (unsigned char *)dst;
    const unsigned char *s = (const unsigned char *)src;
    for (size_t i = 0; i < n; i++) d[i] = s[i];
    return dst;
}
#else
void  *hxlcl_memcpy(void *d, const void *s, size_t n) { return memcpy(d, s, n); }
#endif
#endif
/* SELFEMIT (HEXA_RT_SELFEMIT_MEMSET, default OFF · RFC061 §M8 family r4):
 * hxlcl_memset is supplied by the hexa-NATIVE self-emitted .o
 * (test/native_build/emit_hxlcl_memset_o.hexa — verbatim rt_memset byte loop, no
 * reloc/errno). DEFAULT (macro undefined) keeps the body below → shim.o
 * byte-identical. */
#ifndef HEXA_RT_SELFEMIT_MEMSET
#ifdef HEXA_ZEROC_SHIM_BYTEID_EMIT
/* byte-identical to frozen self/runtime.c hxlcl_memset (verbatim 0-libc floor body) */
void *__attribute__((noinline)) hxlcl_memset(void *s, int c, size_t n) {
    unsigned char *p = (unsigned char *)s;
    unsigned char v = (unsigned char)c;
    for (size_t i = 0; i < n; i++) p[i] = v;
    return s;
}
#else
void  *hxlcl_memset(void *s, int c, size_t n)         { return memset(s, c, n); }
#endif
#endif
/* SELFEMIT (HEXA_RT_SELFEMIT_MEMCMP, default OFF · RFC061 §M8 family r6):
 * hxlcl_memcmp is supplied by the hexa-NATIVE self-emitted .o
 * (test/native_build/emit_hxlcl_memcmp_o.hexa — verbatim rt_memcmp byte loop, no
 * reloc/errno). DEFAULT (macro undefined) keeps the body below → shim.o
 * byte-identical. */
#ifndef HEXA_RT_SELFEMIT_MEMCMP
#ifdef HEXA_ZEROC_SHIM_BYTEID_EMIT
/* byte-identical to frozen runtime.c:310 (hand-rolled byte loop) */
int __attribute__((noinline)) hxlcl_memcmp(const void *a, const void *b, size_t n) {
    const unsigned char *pa = (const unsigned char *)a;
    const unsigned char *pb = (const unsigned char *)b;
    for (size_t i = 0; i < n; i++) {
        int d = (int)pa[i] - (int)pb[i];
        if (d != 0) return d;
    }
    return 0;
}
#else
int    hxlcl_memcmp(const void *a, const void *b, size_t n) { return memcmp(a, b, n); }
#endif
#endif

/* ── string ──────────────────────────────────────────────────────────────── */
/* SELFEMIT (HEXA_RT_SELFEMIT_STRLEN, default OFF · RFC061 §M8 family r3):
 * hxlcl_strlen is supplied by the hexa-NATIVE self-emitted .o
 * (test/native_build/emit_hxlcl_strlen_o.hexa — verbatim rt_str_len scan, no
 * reloc/errno). The shim's own internal callsite (hxlcl_getenv) then resolves to
 * the native symbol cross-object. DEFAULT (macro undefined) keeps the body below
 * → shim.o byte-identical. */
#ifndef HEXA_RT_SELFEMIT_STRLEN
#ifdef HEXA_ZEROC_SHIM_BYTEID_EMIT
/* byte-identical to frozen runtime.c:299 (hand-rolled volatile scan) */
size_t __attribute__((noinline)) hxlcl_strlen(const char *s) {
    if (!s) return 0;
    size_t n = 0;
    while (((const volatile char *)s)[n]) n++;
    return n;
}
#else
size_t __attribute__((noinline)) hxlcl_strlen(const char *s) { return s ? strlen(s) : 0; }
#endif
#endif
/* SELFEMIT (HEXA_RT_SELFEMIT_STRCMP, default OFF · RFC061 §M8 family r4):
 * hxlcl_strcmp is supplied by the hexa-NATIVE self-emitted .o
 * (test/native_build/emit_hxlcl_strcmp_o.hexa — verbatim rt_strcmp scan, no
 * reloc/errno). The shim's many internal callsites then resolve to the native
 * symbol cross-object. DEFAULT (macro undefined) keeps the body below → shim.o
 * byte-identical. */
#ifndef HEXA_RT_SELFEMIT_STRCMP
#ifdef HEXA_ZEROC_SHIM_BYTEID_EMIT
/* byte-identical to frozen self/runtime.c hxlcl_strcmp (verbatim 0-libc floor body) */
int __attribute__((noinline)) hxlcl_strcmp(const char *a, const char *b) {
    for (size_t i = 0; ; i++) {
        unsigned char ca = (unsigned char)a[i];
        unsigned char cb = (unsigned char)b[i];
        if (ca != cb) return (int)ca - (int)cb;
        if (ca == 0) return 0;
    }
}
#else
int    hxlcl_strcmp(const char *a, const char *b)     { return strcmp(a, b); }
#endif
#endif
/* SELFEMIT (HEXA_RT_SELFEMIT_STRNCMP, default OFF · RFC061 §M8 family r4):
 * hxlcl_strncmp is supplied by the hexa-NATIVE self-emitted .o
 * (test/native_build/emit_hxlcl_strncmp_o.hexa — verbatim rt_strncmp scan, no
 * reloc/errno). DEFAULT (macro undefined) keeps the body below → shim.o
 * byte-identical. */
#ifndef HEXA_RT_SELFEMIT_STRNCMP
#ifdef HEXA_ZEROC_SHIM_BYTEID_EMIT
/* byte-identical to frozen self/runtime.c hxlcl_strncmp (verbatim 0-libc floor body) */
int __attribute__((noinline)) hxlcl_strncmp(const char *a, const char *b, size_t n) {
    for (size_t i = 0; i < n; i++) {
        unsigned char ca = (unsigned char)a[i];
        unsigned char cb = (unsigned char)b[i];
        if (ca != cb) return (int)ca - (int)cb;
        if (ca == 0) return 0;
    }
    return 0;
}
#else
int    hxlcl_strncmp(const char *a, const char *b, size_t n) { return strncmp(a, b, n); }
#endif
#endif
/* SELFEMIT (HEXA_RT_SELFEMIT_STRCPY, default OFF · RFC061 §M8 family r6):
 * hxlcl_strcpy is supplied by the hexa-NATIVE self-emitted .o
 * (test/native_build/emit_hxlcl_strcpy_o.hexa — verbatim rt_strcpy copy, no
 * reloc/errno). DEFAULT (macro undefined) keeps the body below → shim.o
 * byte-identical. */
#ifndef HEXA_RT_SELFEMIT_STRCPY
#ifdef HEXA_ZEROC_SHIM_BYTEID_EMIT
/* byte-identical to frozen self/runtime.c hxlcl_strcpy (verbatim 0-libc floor body) */
char *__attribute__((noinline)) hxlcl_strcpy(char *dst, const char *src) {
    size_t i = 0;
    while (((const volatile char *)src)[i]) { dst[i] = src[i]; i++; }
    dst[i] = '\0';
    return dst;
}
#else
char  *hxlcl_strcpy(char *d, const char *s)           { return strcpy(d, s); }
#endif
#endif
/* SELFEMIT (HEXA_RT_SELFEMIT_STRNCPY, default OFF · RFC061 §M8 family r4):
 * hxlcl_strncpy is supplied by the hexa-NATIVE self-emitted .o
 * (test/native_build/emit_hxlcl_strncpy_o.hexa — verbatim rt_strncpy copy, no
 * reloc/errno). DEFAULT (macro undefined) keeps the body below → shim.o
 * byte-identical. */
#ifndef HEXA_RT_SELFEMIT_STRNCPY
#ifdef HEXA_ZEROC_SHIM_BYTEID_EMIT
/* byte-identical to frozen self/runtime.c hxlcl_strncpy (verbatim 0-libc floor body) */
char *__attribute__((noinline)) hxlcl_strncpy(char *dst, const char *src, size_t n) {
    size_t i = 0;
    for (; i < n && src[i]; i++) dst[i] = src[i];
    for (; i < n; i++) dst[i] = '\0';
    return dst;
}
#else
char  *hxlcl_strncpy(char *d, const char *s, size_t n){ return strncpy(d, s, n); }
#endif
#endif
/* SELFEMIT (HEXA_RT_SELFEMIT_STRCAT, default OFF · RFC061 §M8 family r4):
 * hxlcl_strcat is supplied by the hexa-NATIVE self-emitted .o
 * (test/native_build/emit_hxlcl_strcat_o.hexa — verbatim rt_strcat scan+copy, no
 * reloc/errno). DEFAULT (macro undefined) keeps the body below → shim.o
 * byte-identical. */
#ifndef HEXA_RT_SELFEMIT_STRCAT
#ifdef HEXA_ZEROC_SHIM_BYTEID_EMIT
/* byte-identical to frozen self/runtime.c hxlcl_strcat (verbatim 0-libc floor body) */
char *__attribute__((noinline)) hxlcl_strcat(char *dest, const char *src) {
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
#else
char  *hxlcl_strcat(char *d, const char *s)           { return strcat(d, s); }
#endif
#endif
/* SELFEMIT (HEXA_RT_SELFEMIT_STRDUP, default OFF · RFC061 §M8 family r10): hxlcl_strdup is
 * supplied by the hexa-NATIVE self-emitted .o (test/native_build/emit_hxlcl_strdup_o.hexa
 * — verbatim rt_strdup 112-byte body: inline strlen loop + `bl _hxlcl_malloc` BRANCH26,
 * byte-identical to self/codegen/runtime_arm64.hexa::rt_strdup). COMPOSITE: the native .o
 * carries ONE undefined-external `_hxlcl_malloc` callee which the RETAINED shim global
 * `hxlcl_malloc` (above; not swapped) resolves — NO errno, no new provider. DEFAULT (macro
 * undefined) keeps this libc delegate → shim.o byte-identical. */
#ifndef HEXA_RT_SELFEMIT_STRDUP
#ifdef HEXA_ZEROC_SHIM_BYTEID_EMIT
/* byte-identical to frozen self/runtime.c hxlcl_strdup (verbatim 0-libc floor body) */
char *__attribute__((noinline)) hxlcl_strdup(const char *s) {
    if (!s) return NULL;
    size_t n = 0;
    while (((const volatile char *)s)[n]) n++;
    char *out = (char *)hxlcl_malloc(n + 1);
    if (!out) return NULL;
    for (size_t i = 0; i < n; i++) out[i] = s[i];
    out[n] = '\0';
    return out;
}
#else
char  *hxlcl_strdup(const char *s)                    { return s ? strdup(s) : NULL; }
#endif
#endif
/* SELFEMIT (HEXA_RT_SELFEMIT_STRCHR, default OFF · RFC061 §M8 family r4):
 * hxlcl_strchr is supplied by the hexa-NATIVE self-emitted .o
 * (test/native_build/emit_hxlcl_strchr_o.hexa — verbatim rt_strchr scan, no
 * reloc/errno). DEFAULT (macro undefined) keeps the body below → shim.o
 * byte-identical. */
#ifndef HEXA_RT_SELFEMIT_STRCHR
#ifdef HEXA_ZEROC_SHIM_BYTEID_EMIT
/* byte-identical to frozen self/runtime.c hxlcl_strchr (verbatim 0-libc floor body) */
const char *__attribute__((noinline)) hxlcl_strchr(const char *s, int c) {
    if (!s) return NULL;
    unsigned char target = (unsigned char)c;
    for (size_t i = 0; ; i++) {
        unsigned char x = (unsigned char)((const volatile char *)s)[i];
        if (x == target) return s + i;
        if (x == 0) return (target == 0) ? (s + i) : NULL;
    }
}
#else
const char *hxlcl_strchr(const char *s, int c)        { return strchr(s, c); }
#endif
#endif
#ifdef HEXA_ZEROC_SHIM_BYTEID_EMIT
/* byte-identical to frozen self/runtime.c hxlcl_strstr (verbatim 0-libc floor body) */
const char *__attribute__((noinline)) hxlcl_strstr(const char *h, const char *n) {
    if (!h || !n) return NULL;
    if (n[0] == 0) return h;
    for (size_t i = 0; ((const volatile char *)h)[i]; i++) {
        size_t j = 0;
        while (n[j] && h[i + j] == n[j]) j++;
        if (n[j] == 0) return h + i;
    }
    return NULL;
}
#else
const char *hxlcl_strstr(const char *h, const char *n){ return strstr(h, n); }
#endif

/* ── numeric parse ───────────────────────────────────────────────────────── */
long long __attribute__((noinline)) hxlcl_atoll(const char *s) { return s ? atoll(s) : 0; }
/* SELFEMIT (HEXA_RT_SELFEMIT_ATOI, default OFF · RFC061 §M8 family r10): hxlcl_atoi is
 * supplied by the hexa-NATIVE self-emitted .o (test/native_build/emit_hxlcl_atoi_o.hexa
 * — verbatim rt_atoi 20-byte body: frame + `bl _hxlcl_atoll` BRANCH26 + epilogue,
 * byte-identical to self/codegen/runtime_arm64.hexa::rt_atoi). COMPOSITE: the native .o
 * carries ONE undefined-external `_hxlcl_atoll` callee which the RETAINED shim global
 * `hxlcl_atoll` (above; not swapped) resolves — NO errno, no new provider. DEFAULT (macro
 * undefined) keeps this libc delegate → shim.o byte-identical. */
#ifndef HEXA_RT_SELFEMIT_ATOI
#ifdef HEXA_ZEROC_SHIM_BYTEID_EMIT
/* byte-identical to frozen self/runtime.c hxlcl_atoi (verbatim 0-libc floor body) */
int __attribute__((noinline)) hxlcl_atoi(const char *s) { return (int)hxlcl_atoll(s); }
#else
int       hxlcl_atoi(const char *s)                   { return s ? atoi(s) : 0; }
#endif
#endif
double    hxlcl_atof(const char *s)                   { return s ? atof(s) : 0.0; }
#ifdef HEXA_ZEROC_SHIM_BYTEID_EMIT
/* byte-identical to frozen self/runtime.c hxlcl_strtoll (verbatim 0-libc floor body) */
long long __attribute__((noinline)) hxlcl_strtoll(const char *nptr, char **endptr, int base) {
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
#else
long long hxlcl_strtoll(const char *p, char **e, int b){ return strtoll(p, e, b); }
#endif

/* ── math (libm) ─────────────────────────────────────────────────────────── */
double hxlcl_sin(double x)                            { return sin(x); }
double hxlcl_cos(double x)                            { return cos(x); }
double hxlcl_exp(double x)                            { return exp(x); }
double hxlcl_log(double x)                            { return log(x); }
double hxlcl_fmod(double x, double y)                 { return fmod(x, y); }

/* ── env / process ───────────────────────────────────────────────────────── */
#ifdef HEXA_ZEROC_SHIM_BYTEID_EMIT
/* byte-identical to frozen self/runtime.c hxlcl_getenv (verbatim 0-libc floor body) */
char *__attribute__((noinline)) hxlcl_getenv(const char *name) {
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
#else
char *hxlcl_getenv(const char *name)                  { return getenv(name); }
#endif
int   hxlcl_setenv(const char *n, const char *v, int o){ return setenv(n, v, o); }
int   hxlcl_atexit(void (*fn)(void))                  { return atexit(fn); }
int   hxlcl_fork(void)                                { return (int)fork(); }
int   hxlcl_execvp(const char *file, char *const argv[]) { return execvp(file, argv); }
/* SELFEMIT (HEXA_RT_SELFEMIT_WAITPID, default OFF · RFC061 §M8 family r9): hxlcl_waitpid
 * is supplied by the hexa-NATIVE self-emitted .o (test/native_build/emit_hxlcl_waitpid_o.hexa
 * — class-C `svc #0x80` SYS_wait4 trap + carry-flag errno store, byte-identical to
 * self/codegen/runtime_arm64.hexa::rt_waitpid, refs the shared `_hxlcl_errno`). DEFAULT
 * (macro undefined) keeps this libc delegate → shim.o byte-identical. */
#ifndef HEXA_RT_SELFEMIT_WAITPID
int   hxlcl_waitpid(int pid, int *status, int options){ return (int)waitpid((pid_t)pid, status, options); }
#endif
/* SELFEMIT (HEXA_RT_SELFEMIT_DUP2, default OFF · RFC061 §M8 family r9): hxlcl_dup2 is
 * supplied by the hexa-NATIVE self-emitted .o (test/native_build/emit_hxlcl_dup2_o.hexa
 * — class-C `svc #0x80` SYS_dup2 trap + carry-flag errno store, byte-identical to
 * self/codegen/runtime_arm64.hexa::rt_dup2, refs the shared `_hxlcl_errno`). DEFAULT
 * (macro undefined) keeps this libc delegate → shim.o byte-identical. */
#ifndef HEXA_RT_SELFEMIT_DUP2
int   hxlcl_dup2(int o, int n)                        { return dup2(o, n); }
#endif
int   hxlcl_pipe(int fds[2])                          { return pipe(fds); }
void *hxlcl_signal(int signum, void *handler)         { return (void *)signal(signum, (void (*)(int))handler); }

/* ── file / io ───────────────────────────────────────────────────────────── */
void  *hxlcl_fopen(const char *p, const char *m)      { return (void *)fopen(p, m); }
size_t hxlcl_fread(void *b, size_t s, size_t n, void *fp) { return fread(b, s, n, (FILE *)fp); }
long   hxlcl_ftell(void *fp)                          { return ftell((FILE *)fp); }
int    hxlcl_fseek(void *fp, long off, int whence)    { return fseek((FILE *)fp, off, whence); }
int    hxlcl_open_sys(const char *path, int flags, ...) { return open(path, flags, 0644); }
/* SELFEMIT (HEXA_RT_SELFEMIT_READ, default OFF · RFC061 §M8 family r3): like
 * close below, hxlcl_read is supplied by the hexa-NATIVE self-emitted .o
 * (test/native_build/emit_hxlcl_read_o.hexa — raw `svc #0x80` read trap +
 * carry-flag errno store, byte-identical to runtime_arm64.hexa::rt_read, refs
 * the shared `_hxlcl_errno`). DEFAULT (macro undefined) keeps this libc delegate
 * → shim.o byte-identical. */
#ifndef HEXA_RT_SELFEMIT_READ
long   hxlcl_read(int fd, void *buf, unsigned long n) { return (long)read(fd, buf, (size_t)n); }
#endif
/* SELFEMIT (HEXA_RT_SELFEMIT_CLOSE, default OFF · RFC061 §M8): hxlcl_close is
 * supplied by the hexa-NATIVE self-emitted .o (test/native_build/emit_hxlcl_close_o.hexa
 * — a raw `svc #0x80` close trap with carry-flag errno store, byte-identical to
 * self/codegen/runtime_arm64.hexa::rt_close) instead of this libc delegate.
 * stage_resolve_runtime_a's Case-B SELFEMIT arm builds shim.o with this macro
 * (dropping the symbol here) and ar's the native .o + a 1-cell `hxlcl_errno`
 * provider into the archive. DEFAULT (macro undefined) keeps the libc delegate
 * → shim.o byte-identical; the single-TU ship build never compiles this file. */
#ifndef HEXA_RT_SELFEMIT_CLOSE
int    hxlcl_close(int fd)                            { return close(fd); }
#endif
/* SELFEMIT (HEXA_RT_SELFEMIT_LSEEK, default OFF · RFC061 §M8 family r9): hxlcl_lseek is
 * supplied by the hexa-NATIVE self-emitted .o (test/native_build/emit_hxlcl_lseek_o.hexa
 * — class-C `svc #0x80` SYS_lseek trap + carry-flag errno store, byte-identical to
 * self/codegen/runtime_arm64.hexa::rt_lseek, refs the shared `_hxlcl_errno`). DEFAULT
 * (macro undefined) keeps this libc delegate → shim.o byte-identical. */
#ifndef HEXA_RT_SELFEMIT_LSEEK
long   hxlcl_lseek(int fd, long off, int whence)      { return (long)lseek(fd, (off_t)off, whence); }
#endif
/* SELFEMIT (HEXA_RT_SELFEMIT_FCNTL, default OFF · RFC061 §M8 family r10): hxlcl_fcntl is
 * supplied by the hexa-NATIVE self-emitted .o (test/native_build/emit_hxlcl_fcntl_o.hexa
 * — class-C SYS_fcntl `svc #0x80` via plain _hxlcl_syscall3, NON-_cf no-errno: dual-sxtw
 * + svc + ret, NO reloc, byte-identical to self/codegen/runtime_arm64.hexa::rt_fcntl).
 * Self-contained leaf — no external callee, no errno provider. DEFAULT (macro undefined)
 * keeps this libc delegate → shim.o byte-identical. */
#ifndef HEXA_RT_SELFEMIT_FCNTL
int    hxlcl_fcntl(int fd, int cmd, long arg)         { return fcntl(fd, cmd, arg); }
#endif
/* SELFEMIT (HEXA_RT_SELFEMIT_STAT, default OFF · RFC061 §M8 family r9): hxlcl_stat is
 * supplied by the hexa-NATIVE self-emitted .o (test/native_build/emit_hxlcl_stat_o.hexa
 * — class-C `svc #0x80` SYS_stat trap + carry-flag errno store, byte-identical to
 * self/codegen/runtime_arm64.hexa::rt_stat, refs the shared `_hxlcl_errno`). DEFAULT
 * (macro undefined) keeps this libc delegate → shim.o byte-identical. */
#ifndef HEXA_RT_SELFEMIT_STAT
int    hxlcl_stat(const char *path, void *buf)        { return stat(path, (struct stat *)buf); }
#endif
/* SELFEMIT (HEXA_RT_SELFEMIT_MKDIR, default OFF · RFC061 §M8 family r9): hxlcl_mkdir is
 * supplied by the hexa-NATIVE self-emitted .o (test/native_build/emit_hxlcl_mkdir_o.hexa
 * — class-C `svc #0x80` SYS_mkdir trap + carry-flag errno store, byte-identical to
 * self/codegen/runtime_arm64.hexa::rt_mkdir, refs the shared `_hxlcl_errno`). DEFAULT
 * (macro undefined) keeps this libc delegate → shim.o byte-identical. */
#ifndef HEXA_RT_SELFEMIT_MKDIR
int    hxlcl_mkdir(const char *path, int mode)        { return mkdir(path, (mode_t)mode); }
#endif
/* SELFEMIT (HEXA_RT_SELFEMIT_POLL, default OFF · RFC061 §M8 family r10): hxlcl_poll is
 * supplied by the hexa-NATIVE self-emitted .o (test/native_build/emit_hxlcl_poll_o.hexa
 * — class-C SYS_poll `svc #0x80` via plain _hxlcl_syscall3, NON-_cf no-errno: uxtw nfds
 * + sxtw timeout + svc + ret, NO reloc, byte-identical to
 * self/codegen/runtime_arm64.hexa::rt_poll). Self-contained leaf — no external callee,
 * no errno provider. DEFAULT (macro undefined) keeps this libc delegate → shim.o
 * byte-identical. */
#ifndef HEXA_RT_SELFEMIT_POLL
int    hxlcl_poll(void *fds, unsigned int nfds, int timeout) { return poll((struct pollfd *)fds, (nfds_t)nfds, timeout); }
#endif
void  *hxlcl_popen(const char *cmd, const char *mode) { return (void *)popen(cmd, mode); }
int    hxlcl_pclose(void *stream)                     { return pclose((FILE *)stream); }

/* ── time ────────────────────────────────────────────────────────────────── */
int    hxlcl_time(int *t)                             { time_t r = time(NULL); if (t) *t = (int)r; return (int)r; }
int    hxlcl_clock_gettime(int clk, void *ts)         { return clock_gettime((clockid_t)clk, (struct timespec *)ts); }
size_t hxlcl_strftime(char *buf, size_t cap, const char *fmt, void *tm) { return strftime(buf, cap, fmt, (struct tm *)tm); }
int    hxlcl_getrusage(int who, void *usage)          { return getrusage(who, (struct rusage *)usage); }

/* ── exceptions (setjmp/longjmp) ─────────────────────────────────────────── */
/* OWNER POLARITY (RFC061 #29 multi-object flip · darwin multidef fix):
 * On darwin-arm64 the FROZEN runtime.c blob already DEFINES `_hxlcl_setjmp` /
 * `_hxlcl_longjmp` with EXTERNAL linkage — the hand-written naked-asm pair
 * (runtime.c tail, cycle 86) that compiled programs' try-blocks bind via
 * `bl _hxlcl_setjmp` (codegen arm64_darwin.hexa). Under the include-drop
 * multi-object archive that global pair lives in runtime.o, so the sibling
 * shim must NOT re-define it (ld would see 2 duplicate global symbols and the
 * Case-B multidef gate FATALs). On Linux runtime.c uses `#define hxlcl_setjmp`
 * (a libc-setjmp call-site macro) + a `static` hxlcl_longjmp — neither is an
 * externally-linkable symbol in runtime.o — so the shim is the SOLE provider
 * of the global pair the standalone runtime_core.o references. Hence: define
 * the libc-delegate pair here EXCEPT on Apple, where runtime.o owns it. This
 * is the same owner-dedup discipline the gate already relies on for
 * _hexa_init_fn_shims (runtime.o=1T, sibling=U). DEFAULT single-TU build never
 * compiles this shim, so byteeq is unaffected. */
#ifndef __APPLE__
int    hxlcl_setjmp(void *buf)                        { return setjmp(*(jmp_buf *)buf); }
void   hxlcl_longjmp(void *buf, int val)              { longjmp(*(jmp_buf *)buf, val ? val : 1); }
#endif

/* ── backtrace (best-effort; no-op where unavailable) ────────────────────── */
#ifdef __linux__
/* real backtrace()/backtrace_symbols_fd() are glibc-only — gate on __GLIBC__ so
 * musl-linux (static release) takes the stub arm instead of an undefined symbol. */
#if defined(HEXA_ZEROC_SHIM_BYTEID_EMIT) || !defined(__GLIBC__)
/* byte-identical to frozen self/runtime.c hxlcl_backtrace (verbatim 0-libc floor body) */
int __attribute__((noinline)) hxlcl_backtrace(void **buf, int sz) {
    (void)buf; (void)sz;
    return 0;  // 0 frames captured — hexa-native stub, no real unwinder
}
#else
int  hxlcl_backtrace(void **buf, int sz)              { return backtrace(buf, sz); }
#endif
#if defined(HEXA_ZEROC_SHIM_BYTEID_EMIT)
/* byte-identical to frozen self/runtime.c hxlcl_backtrace_symbols_fd (verbatim 0-libc floor body) */
void __attribute__((noinline)) hxlcl_backtrace_symbols_fd(void *const *buf, int sz, int fd) {
    (void)buf; (void)sz;
    static const char msg[] = "(backtrace unavailable — hexa-native stub)\n";
    hxlcl_write(fd, msg, sizeof(msg) - 1);
}
#elif defined(__GLIBC__)
void hxlcl_backtrace_symbols_fd(void *const *buf, int sz, int fd) { backtrace_symbols_fd(buf, sz, fd); }
#else
/* musl: pure no-op — the BYTEID stub's hxlcl_write isn't linked in non-BYTEID musl builds. */
void hxlcl_backtrace_symbols_fd(void *const *buf, int sz, int fd) { (void)buf; (void)sz; (void)fd; }
#endif
#else
int  hxlcl_backtrace(void **buf, int sz)              { (void)buf; (void)sz; return 0; }
void hxlcl_backtrace_symbols_fd(void *const *buf, int sz, int fd) { (void)buf; (void)sz; (void)fd; }
#endif

/* ── darwin mach task_info (no-op on linux; runtime_core.c guards usage) ──── */
int  hxlcl_task_info(unsigned int target, unsigned int flavor, void *info_out, unsigned int *count) {
    (void)target; (void)flavor; (void)info_out; (void)count; return -1;
}
