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
#ifdef __linux__
#include <execinfo.h>
#endif

extern char **environ;

/* ── mem / alloc ─────────────────────────────────────────────────────────── */
void  *hxlcl_malloc(size_t n)                         { return malloc(n ? n : 1); }
void   hxlcl_free(void *p)                            { free(p); }
void  *hxlcl_realloc(void *p, size_t n)               { return realloc(p, n); }
void  *hxlcl_calloc(size_t nmemb, size_t size)        { return calloc(nmemb ? nmemb : 1, size ? size : 1); }
void  *hxlcl_memcpy(void *d, const void *s, size_t n) { return memcpy(d, s, n); }
void  *hxlcl_memset(void *s, int c, size_t n)         { return memset(s, c, n); }
int    hxlcl_memcmp(const void *a, const void *b, size_t n) { return memcmp(a, b, n); }

/* ── string ──────────────────────────────────────────────────────────────── */
size_t hxlcl_strlen(const char *s)                    { return s ? strlen(s) : 0; }
int    hxlcl_strcmp(const char *a, const char *b)     { return strcmp(a, b); }
int    hxlcl_strncmp(const char *a, const char *b, size_t n) { return strncmp(a, b, n); }
char  *hxlcl_strcpy(char *d, const char *s)           { return strcpy(d, s); }
char  *hxlcl_strncpy(char *d, const char *s, size_t n){ return strncpy(d, s, n); }
char  *hxlcl_strcat(char *d, const char *s)           { return strcat(d, s); }
char  *hxlcl_strdup(const char *s)                    { return s ? strdup(s) : NULL; }
const char *hxlcl_strchr(const char *s, int c)        { return strchr(s, c); }
const char *hxlcl_strstr(const char *h, const char *n){ return strstr(h, n); }

/* ── numeric parse ───────────────────────────────────────────────────────── */
long long hxlcl_atoll(const char *s)                  { return s ? atoll(s) : 0; }
int       hxlcl_atoi(const char *s)                   { return s ? atoi(s) : 0; }
double    hxlcl_atof(const char *s)                   { return s ? atof(s) : 0.0; }
long long hxlcl_strtoll(const char *p, char **e, int b){ return strtoll(p, e, b); }

/* ── math (libm) ─────────────────────────────────────────────────────────── */
double hxlcl_sin(double x)                            { return sin(x); }
double hxlcl_cos(double x)                            { return cos(x); }
double hxlcl_exp(double x)                            { return exp(x); }
double hxlcl_log(double x)                            { return log(x); }
double hxlcl_fmod(double x, double y)                 { return fmod(x, y); }

/* ── env / process ───────────────────────────────────────────────────────── */
char *hxlcl_getenv(const char *name)                  { return getenv(name); }
int   hxlcl_setenv(const char *n, const char *v, int o){ return setenv(n, v, o); }
int   hxlcl_atexit(void (*fn)(void))                  { return atexit(fn); }
int   hxlcl_fork(void)                                { return (int)fork(); }
int   hxlcl_execvp(const char *file, char *const argv[]) { return execvp(file, argv); }
int   hxlcl_waitpid(int pid, int *status, int options){ return (int)waitpid((pid_t)pid, status, options); }
int   hxlcl_dup2(int o, int n)                        { return dup2(o, n); }
int   hxlcl_pipe(int fds[2])                          { return pipe(fds); }
void *hxlcl_signal(int signum, void *handler)         { return (void *)signal(signum, (void (*)(int))handler); }

/* ── file / io ───────────────────────────────────────────────────────────── */
void  *hxlcl_fopen(const char *p, const char *m)      { return (void *)fopen(p, m); }
size_t hxlcl_fread(void *b, size_t s, size_t n, void *fp) { return fread(b, s, n, (FILE *)fp); }
long   hxlcl_ftell(void *fp)                          { return ftell((FILE *)fp); }
int    hxlcl_fseek(void *fp, long off, int whence)    { return fseek((FILE *)fp, off, whence); }
int    hxlcl_open_sys(const char *path, int flags, ...) { return open(path, flags, 0644); }
long   hxlcl_read(int fd, void *buf, unsigned long n) { return (long)read(fd, buf, (size_t)n); }
int    hxlcl_close(int fd)                            { return close(fd); }
long   hxlcl_lseek(int fd, long off, int whence)      { return (long)lseek(fd, (off_t)off, whence); }
int    hxlcl_fcntl(int fd, int cmd, long arg)         { return fcntl(fd, cmd, arg); }
int    hxlcl_stat(const char *path, void *buf)        { return stat(path, (struct stat *)buf); }
int    hxlcl_mkdir(const char *path, int mode)        { return mkdir(path, (mode_t)mode); }
int    hxlcl_poll(void *fds, unsigned int nfds, int timeout) { return poll((struct pollfd *)fds, (nfds_t)nfds, timeout); }
void  *hxlcl_popen(const char *cmd, const char *mode) { return (void *)popen(cmd, mode); }
int    hxlcl_pclose(void *stream)                     { return pclose((FILE *)stream); }

/* ── time ────────────────────────────────────────────────────────────────── */
int    hxlcl_time(int *t)                             { time_t r = time(NULL); if (t) *t = (int)r; return (int)r; }
int    hxlcl_clock_gettime(int clk, void *ts)         { return clock_gettime((clockid_t)clk, (struct timespec *)ts); }
size_t hxlcl_strftime(char *buf, size_t cap, const char *fmt, void *tm) { return strftime(buf, cap, fmt, (struct tm *)tm); }
int    hxlcl_getrusage(int who, void *usage)          { return getrusage(who, (struct rusage *)usage); }

/* ── exceptions (setjmp/longjmp) ─────────────────────────────────────────── */
int    hxlcl_setjmp(void *buf)                        { return setjmp(*(jmp_buf *)buf); }
void   hxlcl_longjmp(void *buf, int val)              { longjmp(*(jmp_buf *)buf, val ? val : 1); }

/* ── backtrace (best-effort; no-op where unavailable) ────────────────────── */
#ifdef __linux__
int  hxlcl_backtrace(void **buf, int sz)              { return backtrace(buf, sz); }
void hxlcl_backtrace_symbols_fd(void *const *buf, int sz, int fd) { backtrace_symbols_fd(buf, sz, fd); }
#else
int  hxlcl_backtrace(void **buf, int sz)              { (void)buf; (void)sz; return 0; }
void hxlcl_backtrace_symbols_fd(void *const *buf, int sz, int fd) { (void)buf; (void)sz; (void)fd; }
#endif

/* ── darwin mach task_info (no-op on linux; runtime_core.c guards usage) ──── */
int  hxlcl_task_info(unsigned int target, unsigned int flavor, void *info_out, unsigned int *count) {
    (void)target; (void)flavor; (void)info_out; (void)count; return -1;
}
