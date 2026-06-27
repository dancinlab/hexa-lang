#!/usr/bin/env bash
# tool/routec_cabi_smoke.sh — RFC061 §M8 Route C ON-PATH emit smoke.
#
# WHAT THIS PROVES (the gap the SELFEMIT live-link smoke does NOT cover)
# ─────────────────────────────────────────────────────────────────────
# The SELFEMIT smoke (nobaseline-gate.yml) exercises the HAND-ASSEMBLED seed
# path (`HEXA_RT_SELFEMIT` → the test/native_build/emit_hxlcl_*_o.hexa fixtures).
# It NEVER runs the Route C codegen path (`HEXA_CABI_HXLCL`). So until now the
# Route C per-fn C-ABI emit of stdlib/runtime/hxlcl_core.hexa had ZERO direct CI
# coverage — its correctness rested on seed-shape-match inference + code review.
#
# This job closes that gap: it builds aprime_cc, emits hxlcl_core.hexa's
# whitelisted symbols WITH `HEXA_CABI_HXLCL=1` (the real Route C path), links the
# emitted .o against a self-contained C harness that (a) supplies the inner-callee
# leaves the composites bl into (hxlcl_malloc / hxlcl_atoll) and (b) CALLS each
# Route-C-emitted symbol as a raw C-ABI function and ASSERTS its behaviour. A
# clean build + all-asserts-pass run is the direct ON-path proof that the Route C
# emit produces correct, linkable, behaviourally-faithful raw-C-ABI objects.
#
# WHY NO SHIM LINK (multidef avoidance): the libc shim
# (self/runtime_core_hxlcl_shim.c) ALSO defines hxlcl_atoi/strdup/calloc/… so
# linking it beside the Route C .o would duplicate-define them. Instead the C
# harness here provides ONLY the inner-callee leaves the Route C bodies reference
# as undefined-externals (hxlcl_malloc, hxlcl_atoll) — exactly the retained-shim
# role, minus the collisions. Every OTHER hxlcl_* symbol the harness uses comes
# from the Route C .o, so the harness is calling the emitted code under test.
#
# darwin-arm64 ONLY: aprime_cc builds Mach-O arm64 (clang -arch arm64); this is
# the single host where the patched compiler builds (the campaign's measured
# constraint). On other hosts the script is a loud no-op (exit 0, SKIP).
#
#   tool/routec_cabi_smoke.sh
#
set -euo pipefail

HX="${HX_ROOT:-$(cd "$(dirname "$0")/.."; pwd)}"
CC="${CC:-clang}"

# ── host gate: aprime_cc is darwin-arm64-only ───────────────────────────────
if [ "$(uname -s)" != "Darwin" ] || [ "$(uname -m)" != "arm64" ]; then
    echo "[routec-smoke] SKIP — aprime_cc builds darwin-arm64 only (host=$(uname -sm))"
    exit 0
fi

APRIME="${APRIME:-$HX/build/aprime_cc}"
if [ ! -x "$APRIME" ]; then
    echo "[routec-smoke] building aprime_cc (tool/build_aprime.sh) …"
    bash "$HX/tool/build_aprime.sh" -o "$APRIME"
fi
[ -x "$APRIME" ] || { echo "[routec-smoke] FATAL: aprime_cc not at $APRIME" >&2; exit 1; }

SRC="$HX/stdlib/runtime/hxlcl_core.hexa"
[ -f "$SRC" ] || { echo "[routec-smoke] FATAL: SSOT missing: $SRC" >&2; exit 1; }

TMP="$(mktemp -d -t routec_smoke.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
printf 'fn _drv_unused() {}\n' > "$TMP/_drv.hexa"

# ── (1) Route C emit: HEXA_CABI_HXLCL=1 activates the _is_cabi whitelist so the
#    whitelisted hxlcl_* fns lower at the single-register C-ABI. Emit ASM then
#    assemble with clang — the proven native-emit path (tool/regen_str_core_*.sh
#    + self/main.hexa:3197 use --emit=asm; the _drv.hexa first arg satisfies the
#    standalone "missing SOURCE" guard, the trailing SRC arg is the real module).
#    HEXA_INLINE_INT_BOX/BOOL_BOX mirror the production native-build wrapper so the
#    emit matches what `hexa build` would produce.
echo "[routec-smoke] (1) emit hxlcl_core.hexa with HEXA_CABI_HXLCL=1 …"
HEXA_CABI_HXLCL=1 HEXA_INLINE_INT_BOX=1 HEXA_INLINE_BOOL_BOX=1 \
    "$APRIME" "$TMP/_drv.hexa" --emit=asm \
    --target=arm64-apple-darwin -o "$TMP/routec.s" "$SRC"
[ -s "$TMP/routec.s" ] || { echo "[routec-smoke] FATAL: empty routec.s" >&2; exit 1; }
"$CC" -arch arm64 -c "$TMP/routec.s" -o "$TMP/routec.o"
[ -s "$TMP/routec.o" ] || { echo "[routec-smoke] FATAL: empty routec.o" >&2; exit 1; }

# Assert the Route C symbols are DEFINED (T) external text in the emitted .o.
echo "[routec-smoke] (2) assert Route C symbols defined in routec.o …"
syms="$(nm "$TMP/routec.o" 2>/dev/null || true)"
miss=0
# Tests the symbols CURRENTLY whitelisted on main (9 pure-arith + composites).
# Each composite PR adds its symbol here — the standing ON-path gate grows with
# the _is_cabi whitelist.
for s in strlen memcpy memset memcmp strcmp strncmp strcpy strncpy strcat atoi strdup calloc realloc getpid getuid getgid getppid geteuid getegid close read lseek dup2 mkdir stat waitpid; do
    if grep -qE " T _hxlcl_${s}\$" <<<"$syms"; then
        :
    else
        echo "  NOT DEFINED (T): _hxlcl_${s}"; miss=$((miss+1))
    fi
done
[ "$miss" -eq 0 ] || { echo "[routec-smoke] FATAL: $miss Route C symbol(s) not emitted" >&2; exit 1; }

# ── (3) C harness: supplies the inner-callee leaf (atoll) the atoi composite
#    bl's into, and CALLS each Route-C-emitted symbol with raw C-ABI prototypes
#    + behaviour asserts. A wrong ABI (e.g. PAIR-MODEL leak) would crash or
#    mis-compute here, not link clean.
cat > "$TMP/harness.c" <<'CEOF'
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>   /* libc getpid() — the reference oracle for hxlcl_getpid */
#include <fcntl.h>    /* open() / O_RDONLY — for the close() behavior test */

/* Route-C-emitted symbols under test (raw C-ABI prototypes). */
extern size_t hxlcl_strlen(const char *s);
extern void  *hxlcl_memcpy(void *d, const void *s, size_t n);
extern void  *hxlcl_memset(void *s, int c, size_t n);
extern int    hxlcl_memcmp(const void *a, const void *b, size_t n);
extern int    hxlcl_strcmp(const char *a, const char *b);
extern int    hxlcl_strncmp(const char *a, const char *b, size_t n);
extern char  *hxlcl_strcpy(char *d, const char *s);
extern char  *hxlcl_strncpy(char *d, const char *s, size_t n);
extern char  *hxlcl_strcat(char *d, const char *s);
extern int    hxlcl_atoi(const char *s);
extern char  *hxlcl_strdup(const char *s);
extern void  *hxlcl_calloc(size_t nmemb, size_t size);

extern void  *hxlcl_realloc(void *p, size_t n);

/* r11 syscall leaf — errno-free 0-arg. Returns the kernel pid raw (no errno). */
extern int    hxlcl_getpid(void);

/* r2 errno-free 0-arg family (getpid mirror) — each returns the raw kernel id. */
extern int    hxlcl_getuid(void);
extern int    hxlcl_getgid(void);
extern int    hxlcl_getppid(void);
extern int    hxlcl_geteuid(void);
extern int    hxlcl_getegid(void);

/* errno-bearing syscall leaf — close. Returns 0 / -1 (errno SET on the Linux
 * leg). On THIS darwin smoke the errno-store is DCE'd out (target_is_linux()
 * const-false), so only the return value (0 / -1) is asserted here; the errno
 * value-exact (==EBADF) is asserted by the LINUX sibling smoke. */
extern int    hxlcl_close(int fd);

/* errno-bearing chain (close mirror) — read / lseek, uniform 3-arg. Same
 * composition-only assertion on darwin (errno-store DCE'd); the errno value-exact
 * is the LINUX sibling smoke's job. */
extern long   hxlcl_read(int fd, void *buf, unsigned long n);
extern long   hxlcl_lseek(int fd, long off, int whence);

/* errno-bearing chain r2 (arm64 dup3/mkdirat shape) — dup2 / mkdir, composition
 * only on darwin (errno-store DCE'd; the errno value-exact is the Linux sibling's
 * claim). On darwin both use the plain 2-arg BSD syscall (SYS_DUP2/SYS_MKDIR). */
extern int    hxlcl_dup2(int oldfd, int newfd);
extern int    hxlcl_mkdir(const char *path, int mode);

/* errno-bearing chain r3 (FINAL batch) — stat / waitpid, composition only on
 * darwin (errno-store DCE'd; the errno value-exact is the Linux sibling's claim).
 * On darwin stat uses the plain 2-arg SYS_STAT; waitpid routes to wait4(4-arg,
 * rusage NULL). statbuf is opaque here (we never read it) — a sufficiently large
 * buffer covers any struct stat layout. */
extern int    hxlcl_stat(const char *path, void *statbuf);
extern int    hxlcl_waitpid(int pid, int *status, int opts);

/* Inner-callee leaves the composites bl into — the retained-shim role, supplied
 * here (sole provider) so there is no multidef with the libc shim: atoll for
 * atoi, malloc for strdup + calloc + realloc. (Each composite PR adds its callee.)
 *
 * This hxlcl_malloc writes the SAME 16-byte size header the floor hxlcl_malloc
 * does (store n at offset 0, hand back ptr+16) so hxlcl_realloc's negative-offset
 * header read `*(size_t*)(p - 16)` recovers the real old size. The 16-byte
 * payload prefix keeps the returned pointer 16-byte aligned. (Small leaks are
 * fine — this is a short-lived smoke process; no hxlcl_free here.) */
#define HXLCL_HDR 16
long long hxlcl_atoll(const char *s) { return s ? atoll(s) : 0; }
void     *hxlcl_malloc(size_t n) {
    size_t want = n ? n : 1;
    unsigned char *base = (unsigned char *)malloc(want + HXLCL_HDR);
    if (!base) return 0;
    *(size_t *)base = want;            /* size header at [base .. base+8) */
    return base + HXLCL_HDR;           /* user pointer (header is at p-16) */
}

/* hxlcl_close's errno-store leg references __errno_location, but it is inside a
 * `if (target_is_linux())` branch that const-folds to FALSE on darwin — so the
 * call is UNREACHABLE here, yet the codegen still emits the `bl ___errno_location`
 * (DCE never drops a STMT_CALL, even an unreachable one). This stub satisfies the
 * darwin linker for that dead reference; it is never executed (the branch is
 * runtime-false). The LINUX sibling smoke links libc's real __errno_location and
 * exercises the store for real (errno == EBADF value-exact). On glibc/musl errno
 * is `(*__errno_location())`; macOS's analog is `__error()` — a darwin-native
 * errno round is separate, so this stub stands in only as a link placeholder. */
static int _smoke_errno_cell = 0;
int *__errno_location(void) { return &_smoke_errno_cell; }

static int fails = 0;
#define CK(cond, msg) do { if (!(cond)) { printf("  FAIL: %s\n", msg); fails++; } } while (0)

int main(void) {
    /* mem/str leaves */
    CK(hxlcl_strlen("hello") == 5, "strlen");
    CK(hxlcl_strlen("") == 0, "strlen empty");

    char buf[16];
    hxlcl_memset(buf, 'x', 4); buf[4] = 0;
    CK(memcmp(buf, "xxxx", 5) == 0, "memset");

    hxlcl_memcpy(buf, "abcd", 4); buf[4] = 0;
    CK(memcmp(buf, "abcd", 5) == 0, "memcpy");

    CK(hxlcl_memcmp("abc", "abc", 3) == 0, "memcmp eq");
    CK(hxlcl_memcmp("abc", "abd", 3) < 0, "memcmp lt");

    CK(hxlcl_strcmp("foo", "foo") == 0, "strcmp eq");
    CK(hxlcl_strcmp("foo", "fop") < 0, "strcmp lt");

    CK(hxlcl_strncmp("foobar", "fooXXX", 3) == 0, "strncmp eq3");
    CK(hxlcl_strncmp("foo", "fox", 3) < 0, "strncmp lt");

    char dst[16];
    hxlcl_strcpy(dst, "copy");
    CK(strcmp(dst, "copy") == 0, "strcpy");

    char nbuf[8];
    hxlcl_strncpy(nbuf, "ab", 5);
    CK(memcmp(nbuf, "ab\0\0\0", 5) == 0, "strncpy pad");

    char cat[16]; cat[0] = 0;
    hxlcl_strcpy(cat, "ab");
    hxlcl_strcat(cat, "cd");
    CK(strcmp(cat, "abcd") == 0, "strcat");

    /* composites (inner bl to retained atoll / header-writing malloc).
     * No free() here: the header-writing hxlcl_malloc returns ptr+16, so libc
     * free(ptr) is wrong — and small leaks in a short smoke process are fine. */
    CK(hxlcl_atoi("42") == 42, "atoi 42");
    CK(hxlcl_atoi("-7") == -7, "atoi -7");

    char *dup = hxlcl_strdup("hi");
    CK(dup != NULL && strcmp(dup, "hi") == 0, "strdup content");

    char *z = (char *)hxlcl_calloc(3, 4);  /* 12 bytes, all zero */
    int allzero = (z != NULL);
    if (z) { for (int i = 0; i < 12; i++) if (z[i] != 0) allzero = 0; }
    CK(allzero, "calloc 12B zero-fill");

    /* realloc: the NEGATIVE-offset header read. hxlcl_malloc wrote old_n=4 at
     * p-16; realloc must recover it, alloc the new size, and preserve min(n,4)=4
     * bytes of content. */
    char *rp = (char *)hxlcl_malloc(4);
    rp[0] = 'R'; rp[1] = 'e'; rp[2] = 'a'; rp[3] = 'l';
    char *rq = (char *)hxlcl_realloc(rp, 32);   /* grow 4 → 32, preserve 4 bytes */
    CK(rq != NULL && rq[0] == 'R' && rq[1] == 'e' && rq[2] == 'a' && rq[3] == 'l',
       "realloc preserves content (neg-offset header read)");

    /* r11 syscall leaf — the FIRST Route C body that issues a syscall. getpid is
     * errno-free + 0-arg, so a correct emit returns the SAME pid as libc getpid()
     * (value-exact oracle, not just >0). A PAIR-MODEL ABI leak or a wrong NR would
     * mis-return here. (On the darwin-arm64 smoke host the body uses SYS_GETPID=20
     * via __hx_syscall0's BSD `svc #0x80` trap; the Linux NRs 39/172 are exercised
     * by the byteeq build targets.) */
    pid_t ref_pid = getpid();
    CK(hxlcl_getpid() == (int)ref_pid, "getpid == libc getpid (value-exact)");
    CK(hxlcl_getpid() > 0, "getpid > 0");

    /* r2 errno-free 0-arg family — each value-exact vs its libc oracle (all from
     * <unistd.h>). Same getpid mechanism; confirms the per-symbol NR + C-ABI emit
     * for the whole family. (getppid > 0 always; uid/gid may be 0 for root, so the
     * value-exact equality — not >0 — is the load-bearing check for those.) */
    CK(hxlcl_getuid()  == (int)getuid(),  "getuid == libc getuid (value-exact)");
    CK(hxlcl_getgid()  == (int)getgid(),  "getgid == libc getgid (value-exact)");
    CK(hxlcl_getppid() == (int)getppid(), "getppid == libc getppid (value-exact)");
    CK(hxlcl_geteuid() == (int)geteuid(), "geteuid == libc geteuid (value-exact)");
    CK(hxlcl_getegid() == (int)getegid(), "getegid == libc getegid (value-exact)");

    /* errno-bearing close — COMPOSITION only on darwin: a valid fd closes → 0.
     * The ERROR case (close(already-closed) == -1) is a LINUX-leg claim and is
     * asserted by the Linux sibling smoke (errno == EBADF value-exact), NOT here:
     * darwin's BSD close signals errors via the carry flag with a POSITIVE errno
     * in x0 (e.g. +9), so `__hx_payload_lt(r, 0)` (which assumes the Linux -errno
     * convention) does not see an error → the body returns +9, not -1. A native
     * darwin errno path (carry-flag capture + `__error()`) is a separate round; the
     * Linux-only errno-store leg here is `target_is_linux()`-gated and DCE-dead on
     * darwin, so darwin's close error semantics are intentionally NOT exercised. */
    int cfd = open("/dev/null", O_RDONLY);
    CK(cfd >= 0, "open /dev/null for close test");
    CK(hxlcl_close(cfd) == 0, "close(valid fd) == 0 (composition)");

    /* read / lseek — COMPOSITION on darwin (success case; errno-store DCE'd).
     * read of /dev/null returns 0 (EOF); lseek on a regular file moves the offset.
     * The errno value-exact (bad-fd → EBADF) is the Linux sibling smoke's claim. */
    char rb[8];
    int rfd = open("/dev/null", O_RDONLY);
    CK(rfd >= 0, "open /dev/null for read test");
    CK(hxlcl_read(rfd, rb, sizeof rb) == 0, "read(/dev/null) == 0 (EOF, composition)");
    hxlcl_close(rfd);

    int lfd = open("/dev/zero", O_RDONLY);
    CK(lfd >= 0, "open /dev/zero for lseek test");
    CK(hxlcl_lseek(lfd, 0, SEEK_SET) == 0, "lseek(SEEK_SET, 0) == 0 (composition)");
    hxlcl_close(lfd);

    /* dup2 / mkdir — COMPOSITION on darwin (success case; errno-store DCE'd). The
     * errno value-exact (bad-fd → EBADF, existing-dir → EEXIST) is the Linux
     * sibling smoke's claim. dup2(valid fd) → newfd; mkdir of a fresh temp → 0. */
    int dsrc = open("/dev/null", O_RDONLY);
    CK(dsrc >= 0, "open /dev/null for dup2 test");
    CK(hxlcl_dup2(dsrc, 31) == 31, "dup2(valid, 31) == 31 (composition)");
    hxlcl_close(31);
    hxlcl_close(dsrc);

    char dir[] = "/tmp/routec_mkdir_XXXXXX";
    CK(mkdtemp(dir) != NULL, "mkdtemp for mkdir test");
    if (dir[0]) {
        rmdir(dir);                       /* remove so hxlcl_mkdir re-creates it */
        CK(hxlcl_mkdir(dir, 0755) == 0, "mkdir(fresh dir) == 0 (composition)");
        rmdir(dir);
    }

    /* stat / waitpid — COMPOSITION on darwin (errno-store DCE'd). The errno
     * value-exact (stat nonexistent → ENOENT, waitpid no-child → ECHILD) is the
     * Linux sibling smoke's claim. The statbuf is an opaque byte buffer large
     * enough for any struct stat.
     *
     * stat("/") → 0 is asserted: success is carry-clear on darwin too (the root
     * always exists), so the return value is exact regardless of the deferred
     * carry-flag errno path.
     *
     * waitpid's ERROR case is NOT asserted on darwin (5th-discipline ④,
     * darwin carry-flag deferred): darwin signals waitpid(no-child)'s ECHILD via
     * the CARRY flag + a POSITIVE errno in x0 (not Linux's -errno), so the body's
     * `__hx_payload_lt(r, 0)` Linux-neg-return check cannot see it as an error
     * and the return value is NOT -1. The error-case -1/ECHILD contract is the
     * Linux sibling's value-exact claim (waitpid(-1)→-1 ∧ ECHILD, already GREEN);
     * darwin's success case needs a fork+child and isn't exercised here. We only
     * assert it LINKS + EMITS + RUNS without crashing (composition-only) — the
     * same treatment close gives its darwin error case. The carry-flag-correct
     * darwin path is a separate __error()/csneg round. */
    char sbuf[256];
    CK(hxlcl_stat("/", sbuf) == 0, "stat(\"/\") == 0 (composition)");

    int wst = 0;
    (void)hxlcl_waitpid(-1, &wst, 0);   /* composition only — darwin carry-flag deferred */

    if (fails == 0) { printf("[routec-smoke] all Route C asserts PASS\n"); return 0; }
    printf("[routec-smoke] %d assert(s) FAILED\n", fails);
    return 1;
}
CEOF

echo "[routec-smoke] (3) compile harness + link Route C .o + run …"
"$CC" -arch arm64 -c "$TMP/harness.c" -o "$TMP/harness.o"
"$CC" -arch arm64 "$TMP/harness.o" "$TMP/routec.o" -o "$TMP/routec_smoke"
"$TMP/routec_smoke"
rc=$?
[ "$rc" -eq 0 ] || { echo "[routec-smoke] FATAL: behaviour run rc=$rc" >&2; exit 1; }
echo "[routec-smoke] GREEN — Route C ON-path emit links + runs correct (13 symbols: 9 pure-arith + atoi + strdup + calloc + realloc, darwin-arm64)"
