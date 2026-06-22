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
