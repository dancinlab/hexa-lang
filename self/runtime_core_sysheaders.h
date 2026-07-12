/* self/runtime_core_sysheaders.h — RFC061 zero-c #29 sibling-shim TU prelude.
 *
 * WHAT THIS IS
 * ────────────
 * When runtime_core.c is compiled as a STANDALONE TU (the #include-drop path,
 * HEXA_ZEROC_DROP_RTCORE_INCLUDE), it loses the system-header block + the
 * file-local hxlcl_* static helpers that the surrounding FROZEN runtime.c blob
 * supplied by textual concatenation. runtime_core.c is a #include FRAGMENT — it
 * has no header block of its own, so a standalone compile fails on undeclared
 * FILE / stdout / NULL / errno / size_t / struct rusage / SIG_IGN / _IONBF / …
 *
 * This sibling header (NON-FROZEN — never edits the frozen blob) re-supplies
 * ONLY the system-header surface, via the standard libc system headers. It does
 * NOT redefine any HexaVal/HexaArr/Tag type — runtime_core.c self-defines those.
 * (This is the key difference from runtime_core_decls.h, which pulls in
 * runtime.h and therefore collides with runtime_core.c's own type defs.)
 *
 * It is force-included (clang -include) ONLY under the opt-in measurement flag
 * HEXA_ZEROC_RTCORE_SHIM_TU (default OFF). The DEFAULT build never sees it.
 */
#ifndef HEXA_RUNTIME_CORE_SYSHEADERS_H
#define HEXA_RUNTIME_CORE_SYSHEADERS_H

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <time.h>
#include <math.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/resource.h>
#ifdef __APPLE__
/* darwin standalone-TU: runtime_core.c's _hx_self_rss_bytes uses the Mach
 * task_info RSS API (mach_task_self / MACH_TASK_BASIC_INFO /
 * mach_task_basic_info_data_t / mach_msg_type_number_t / task_info_t /
 * KERN_SUCCESS). The single-TU default pulls these via runtime.c's own system
 * headers; the include-drop standalone runtime_core.o relies on this prelude, so
 * supply them here (Apple-only, drop-ON-only → default build byte-identical). */
#include <mach/mach.h>
#endif


/* ── hxlcl_* sibling-shim prototypes ─────────────────────────────────────────
 * runtime_core.c calls these file-local helpers (defined static in the FROZEN
 * runtime.c blob). Under the standalone-TU drop path they are supplied with
 * EXTERNAL linkage by self/runtime_core_hxlcl_shim.c. Declare them here so the
 * standalone compile sees correct return types (no implicit-int / int-to-ptr).
 * Signatures mirror the frozen runtime.c declarations verbatim. */
#ifndef HEXA_RTCORE_HXLCL_PROTOS
#define HEXA_RTCORE_HXLCL_PROTOS
void  *hxlcl_malloc(size_t n);
void   hxlcl_free(void *p);
void  *hxlcl_realloc(void *p, size_t n);
void  *hxlcl_calloc(size_t nmemb, size_t size);
void  *hxlcl_memcpy(void *d, const void *s, size_t n);
void  *hxlcl_memset(void *s, int c, size_t n);
int    hxlcl_memcmp(const void *a, const void *b, size_t n);
size_t hxlcl_strlen(const char *s);
int    hxlcl_strcmp(const char *a, const char *b);
int    hxlcl_strncmp(const char *a, const char *b, size_t n);
char  *hxlcl_strcpy(char *d, const char *s);
char  *hxlcl_strncpy(char *d, const char *s, size_t n);
char  *hxlcl_strcat(char *d, const char *s);
char  *hxlcl_strdup(const char *s);
const char *hxlcl_strchr(const char *s, int c);
const char *hxlcl_strstr(const char *h, const char *n);
long long hxlcl_atoll(const char *s);
int       hxlcl_atoi(const char *s);
double    hxlcl_atof(const char *s);
long long hxlcl_strtoll(const char *p, char **e, int b);
double hxlcl_sin(double x);
double hxlcl_cos(double x);
double hxlcl_exp(double x);
double hxlcl_log(double x);
double hxlcl_fmod(double x, double y);
char *hxlcl_getenv(const char *name);
int   hxlcl_setenv(const char *n, const char *v, int o);
int   hxlcl_atexit(void (*fn)(void));
int   hxlcl_fork(void);
int   hxlcl_execvp(const char *file, char *const argv[]);
int   hxlcl_waitpid(int pid, int *status, int options);
int   hxlcl_dup2(int o, int n);
int   hxlcl_pipe(int fds[2]);
void *hxlcl_signal(int signum, void *handler);
void  *hxlcl_fopen(const char *p, const char *m);
size_t hxlcl_fread(void *b, size_t s, size_t n, void *fp);
long   hxlcl_ftell(void *fp);
int    hxlcl_fseek(void *fp, long off, int whence);
int    hxlcl_open_sys(const char *path, int flags, ...);
long   hxlcl_read(int fd, void *buf, unsigned long n);
int    hxlcl_close(int fd);
long   hxlcl_lseek(int fd, long off, int whence);
int    hxlcl_fcntl(int fd, int cmd, long arg);
int    hxlcl_stat(const char *path, void *buf);
int    hxlcl_mkdir(const char *path, int mode);
int    hxlcl_poll(void *fds, unsigned int nfds, int timeout);
void  *hxlcl_popen(const char *cmd, const char *mode);
int    hxlcl_pclose(void *stream);
int    hxlcl_time(int *t);
int    hxlcl_clock_gettime(int clk, void *ts);
size_t hxlcl_strftime(char *buf, size_t cap, const char *fmt, void *tm);
int    hxlcl_getrusage(int who, void *usage);
int    hxlcl_setjmp(void *buf);
void   hxlcl_longjmp(void *buf, int val);
int    hxlcl_backtrace(void **buf, int sz);
void   hxlcl_backtrace_symbols_fd(void *const *buf, int sz, int fd);
int    hxlcl_task_info(unsigned int target, unsigned int flavor, void *info_out, unsigned int *count);
/* axis-2 print family (exported from runtime.o under HEXA_RT_STDIO_NATIVE via inline #ifdef) */
int    hxlcl_printf(const char *fmt, ...);
int    hxlcl_fprintf(void *fp, const char *fmt, ...);
int    hxlcl_snprintf(char *buf, size_t cap, const char *fmt, ...);
void   hxlcl_perror(const char *s);
#endif /* HEXA_RTCORE_HXLCL_PROTOS */

/* zeroc #29 mem-leaf caller-drop: route runtime_core.c's bare mem*() call sites through the
 * shim's native hxlcl_mem* bodies so `memcpy`/`memset`/`memcmp` leave the runtime.a nm-UND
 * floor. Mirrors runtime.c's own override block (runtime_emit_full.hexa ~2835); the standalone
 * runtime_core TU had NO such block, which is exactly why memcpy survived every prior round.
 * Placed AFTER all #includes above (<string.h> at :28) so its memcpy prototype is already
 * parsed, NOT macro-expanded; runtime_core.c is a #include-FRAGMENT with no further libc
 * includes, so nothing re-parses a mem* prototype after this. Function-like macros do not
 * touch the `hxlcl_memcpy(` tokens. Opt-out to the libc path: -DHEXA_RT_MEM_LIBC. */
#ifndef HEXA_RT_MEM_LIBC
#ifndef memcpy
#define memcpy(d,s,n)  hxlcl_memcpy((void *)(d), (const void *)(s), (size_t)(n))
#endif
#ifndef memset
#define memset(p,c,n)  hxlcl_memset((void *)(p), (int)(c), (size_t)(n))
#endif
#ifndef memcmp
#define memcmp(a,b,n)  hxlcl_memcmp((const void *)(a), (const void *)(b), (size_t)(n))
#endif
/* zeroc #29 str-leaf caller-drop (defensive): runtime_core.c has zero bare strlen today, but
 * memcpy survived every prior round through exactly this gap class — cheap insurance so any
 * future bare strlen() here routes to the shim's native hxlcl_strlen. Opt-out: -DHEXA_RT_MEM_LIBC. */
#ifndef strlen
#define strlen(s)  hxlcl_strlen((const char *)(s))
#endif
#endif /* !HEXA_RT_MEM_LIBC */

/* zeroc #29 realloc F2 (load-bearing fix): under the realloc flip, hxlcl_malloc hands out
 * base+16 family pointers with an 8-byte MAGIC. The standalone runtime_core TU must route the
 * WHOLE malloc-family (malloc/free/realloc/calloc) through the shim's magic-guarded providers —
 * else its bare libc free(hxlcl_strdup'd key) = free(base+16) aborts darwin (the #4614 root
 * cause). Placed after <stdlib.h> (line ~27) so the prototypes are already parsed, not
 * macro-expanded; the foreign-pointer path (magic-miss) degrades to the exact libc call, so
 * arena kdup keys and any direct-libc alloc stay today-equivalent. The linux glibc <malloc.h>
 * re-arm block #undef/redefines the same way — no conflict. OFF path (flag unset) = byte-identical. */
#ifdef HEXA_RT_NATIVE_REALLOC
#undef malloc
#undef free
#undef realloc
#undef calloc
#define malloc(n)     hxlcl_malloc((size_t)(n))
#define free(p)       hxlcl_free((void *)(p))
#define realloc(p,n)  hxlcl_realloc((void *)(p), (size_t)(n))
#define calloc(nm,sz) hxlcl_calloc((size_t)(nm), (size_t)(sz))
#endif /* HEXA_RT_NATIVE_REALLOC */

#ifdef HEXA_RT_STDIO_NATIVE
/* axis-2 MULTIOBJ print-family redirect (default-OFF, byte-neutral OFF). runtime_core.c's
   stdout/stderr writers route through runtime.o's exported hxlcl_* raw write(2), matching the
   single-TU amalgam, so MULTIOBJ print survives own-start raw exit_group with no glibc buffering
   and the printf/fprintf/perror/snprintf UND leave runtime.a. fflush + the FILE* family stay on
   glibc on purpose: fuel_abort's real-fopen'd log (fwrite+fflush(f)) is untouched, so there is no
   partial-redirect landmine (fflush is NOT redirected). Placed after stdio.h at line 26. */
#undef printf
#undef fprintf
#undef perror
#undef snprintf
#define printf(...)        hxlcl_printf(__VA_ARGS__)
#define fprintf(fp,...)    hxlcl_fprintf((void *)(fp), __VA_ARGS__)
#define perror(s)          hxlcl_perror((const char *)(s))
#define snprintf(b,c,...)  hxlcl_snprintf((char *)(b), (size_t)(c), __VA_ARGS__)
#endif /* HEXA_RT_STDIO_NATIVE */

#ifdef HXLCL_STDIO_LINK
/* L3 axis-② FILE* MULTIOBJ swap (default-OFF, byte-neutral OFF). runtime_core.c's
   FILE* call sites route to the shim's fake-fd bodies (FILE* == (void*)(uintptr_t)(fd+1)),
   matching the single-TU amalgam's own unconditional redirect (runtime_emit_full.hexa
   ~:2940) so the MULTIOBJ runtime_core.o carries no libc fopen/fread/fwrite/fclose/ftell/
   fseek UND. Redirected as ONE ATOMIC subset (incl. fflush) so a real-fopen'd log path
   (fopen→fwrite→fflush(f)→fclose) stays entirely on the fake-fd encoding — no partial
   redirect that would hand a fake (void*)(fd+1) to a glibc fwrite/fflush and SIGSEGV.
   fileno decodes the fake FILE* via _hxlcl_fp_fd exactly like fread/fseek. Placed after
   stdio.h so the prototypes are parsed, not macro-expanded. OFF path (flag unset) =
   byte-identical (no redirect emitted). */
/* prototypes for the FILE* subset not already declared above (fopen/fread/ftell/fseek
   are at the top of this header); external linkage from the shim's fake-fd bodies. */
int    hxlcl_fclose(void *fp);
size_t hxlcl_fwrite(const void *b, size_t s, size_t n, void *fp);
void  *hxlcl_fdopen(int fd, const char *m);
int    hxlcl_fflush(void *fp);
int    _hxlcl_fp_fd(void *fp);
int    hxlcl_fputs(const char *s, void *fp);
int    hxlcl_fputc(int c, void *fp);
int    hxlcl_setvbuf(void *fp, char *buf, int mode, size_t sz);
#undef fopen
#undef fclose
#undef fread
#undef fwrite
#undef ftell
#undef fseek
#undef fdopen
#undef fileno
#undef fflush
#undef fputs
#undef fputc
#undef setvbuf
#define fopen(p,m)         ((FILE *)hxlcl_fopen((const char *)(p), (const char *)(m)))
#define fclose(fp)         hxlcl_fclose((void *)(fp))
#define fread(b,s,n,fp)    hxlcl_fread((void *)(b), (size_t)(s), (size_t)(n), (void *)(fp))
#define fwrite(b,s,n,fp)   hxlcl_fwrite((const void *)(b), (size_t)(s), (size_t)(n), (void *)(fp))
#define ftell(fp)          hxlcl_ftell((void *)(fp))
#define fseek(fp,o,w)      hxlcl_fseek((void *)(fp), (long)(o), (int)(w))
#define fdopen(fd,m)       ((FILE *)hxlcl_fdopen((int)(fd), (const char *)(m)))
#define fileno(fp)         _hxlcl_fp_fd((void *)(fp))
#define fflush(fp)         hxlcl_fflush((void *)(fp))
/* writer subset that mirrors the amalgam (stdout/stderr targets; setvbuf noop) —
   redirected so no bare-glibc call receives a fake (void*)(fd+1) handle. */
#define fputs(s,fp)        hxlcl_fputs((const char *)(s), (void *)(fp))
#define fputc(c,fp)        hxlcl_fputc((int)(c), (void *)(fp))
#define setvbuf(fp,b,m,sz) hxlcl_setvbuf((void *)(fp), (char *)(b), (int)(m), (size_t)(sz))
#endif /* HXLCL_STDIO_LINK */

#endif /* HEXA_RUNTIME_CORE_SYSHEADERS_H */
