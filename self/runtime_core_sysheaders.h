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
#endif /* HEXA_RTCORE_HXLCL_PROTOS */

#endif /* HEXA_RUNTIME_CORE_SYSHEADERS_H */
