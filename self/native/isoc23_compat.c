/* self/native/isoc23_compat.c — glibc>=2.38 __isoc23_* scanf-family portability shim.
 *
 * ROOT CAUSE (captured on a glibc-2.39 build host + glibc-2.35 run host):
 *   glibc's <stdio.h>, when compiled under _GNU_SOURCE on glibc>=2.38, __REDIRECTs
 *   the scanf family (sscanf/fscanf/scanf) to __isoc23_sscanf/… (the C23 numeric
 *   semantics: 0b binary literals, etc). The runtime.a is built with
 *   `-std=gnu11 -D_GNU_SOURCE` (tool/stage_resolve_runtime_a build_runtime_a_from_source),
 *   so a runtime.a compiled on ANY glibc>=2.38 host BAKES IN an undefined reference
 *   to __isoc23_sscanf. The frozen self/runtime.c (immutable blob 151c52c82) calls
 *   sscanf in hexa_utc_iso_parse — so EVERY runtime.a carries this dep.
 *
 *   On a glibc<2.38 host (Ubuntu 22.04 / glibc-2.35 — the typical bare vast/runpod
 *   GPU pod) libc has NO __isoc23_sscanf, only sscanf@@GLIBC_2.2.5 /
 *   __isoc99_sscanf@GLIBC_2.7. Linking a `hexa run` / `hexa build` program against
 *   that runtime.a then fails:
 *       runtime.c:(.text+…): undefined reference to `__isoc23_sscanf'
 *   This breaks BOTH the clang link AND the native --emit=obj + ld cold path
 *   (both link the same runtime.a) — it is the actual blocker that made
 *   `hexa run` impossible on bare glibc-2.35 pods.
 *
 * FIX (portable, release-safe, byte-neutral on modern hosts):
 *   Provide the three __isoc23_* scanf entry points as WEAK definitions that
 *   delegate to the __isoc99_v* variants (present since GLIBC_2.7, on every
 *   supported host). This object is ar'd INTO runtime.a, so:
 *     · glibc<2.38 run host  → our weak def fills the otherwise-undefined symbol
 *                              → link + run succeed (the bug is closed).
 *     · glibc>=2.38 host     → glibc's own strong __isoc23_* still provides the
 *                              symbol; our def is WEAK so it never conflicts, and
 *                              for the only callers in runtime.c (integer-only
 *                              ISO-8601 %d fields) C23 and C99 sscanf are byte-
 *                              identical → behavior unchanged, byte-neutral.
 *   No change to the frozen runtime.c, no drop of _GNU_SOURCE, no clang/CUDA
 *   coupling — purely additive to the runtime archive.
 */
#include <stdio.h>
#include <stdarg.h>

extern int __isoc99_vsscanf(const char *s, const char *fmt, va_list ap);
extern int __isoc99_vfscanf(FILE *stream, const char *fmt, va_list ap);
extern int __isoc99_vscanf(const char *fmt, va_list ap);

__attribute__((weak)) int __isoc23_sscanf(const char *s, const char *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    int r = __isoc99_vsscanf(s, fmt, ap);
    va_end(ap);
    return r;
}

__attribute__((weak)) int __isoc23_fscanf(FILE *stream, const char *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    int r = __isoc99_vfscanf(stream, fmt, ap);
    va_end(ap);
    return r;
}

__attribute__((weak)) int __isoc23_scanf(const char *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    int r = __isoc99_vscanf(fmt, ap);
    va_end(ap);
    return r;
}
