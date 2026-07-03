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
for s in strlen memcpy memset memcmp strcmp strncmp strcpy strncpy strcat atoi atoll strdup calloc realloc getpid getuid getgid getppid geteuid getegid close read lseek dup2 mkdir stat waitpid write fcntl mmap open_sys getrusage pipe strchr strstr strrchr memmove bzero strtoll strtoull strndup time poll clock_gettime execve fork getenv setenv fopen fclose fread fwrite ftell fseek fdopen fputs fputc fflush popen pclose isalnum isalpha free inet_pton setvbuf darwin_check_fd_set_overflow; do
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
#include <fcntl.h>    /* open() / O_RDONLY / F_GETFL — close/fcntl behavior tests */
#include <sys/mman.h> /* PROT_/MAP_ flags / MAP_FAILED — for the mmap composition test */
#include <sys/resource.h> /* struct rusage / RUSAGE_SELF — for the getrusage composition test */
#include <poll.h>     /* struct pollfd / POLLIN — for the poll composition test */
#include <time.h>     /* libc time() — the reference oracle for hxlcl_time */
#include <sys/wait.h> /* waitpid / WIFEXITED / WEXITSTATUS — for the fork roundtrip test */
#include <sys/socket.h> /* AF_INET / AF_INET6 — for the inet_pton parse test */

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
/* parse-leaf promotion — atoll is now a real self-emitted Route C leaf (base-10,
 * no-endptr simplification of strtoll); atoi bl's into it intra-object. */
extern long long hxlcl_atoll(const char *s);
/* ctype family — register-only pure-compute (arg is an int value, no mem access). */
extern int    hxlcl_isalnum(int c);
extern int    hxlcl_isalpha(int c);
/* alloc residue — no-op free (bump-arena floor reclaims nothing). */
extern void   hxlcl_free(void *p);
/* pure-compute mirror batch 4 — inet_pton (dotted-quad parse + 4-byte caller write,
 * i64-pack restructure of the frozen b[4]) + setvbuf / darwin_check_fd_set_overflow
 * (register-only no-op leaves, return 0). */
extern int    hxlcl_inet_pton(int af, const char *src, void *dst);
extern int    hxlcl_setvbuf(void *fp, char *buf, int mode, size_t sz);
extern int    hxlcl_darwin_check_fd_set_overflow(int fd, const void *p, int n);
extern char  *hxlcl_strdup(const char *s);
/* dup mirror — strndup. Mirror of the strdup composite (inner malloc + byte loops)
 * with a cap-bounded scan; returns a fresh NUL-terminated copy of ≤cap bytes. */
extern char  *hxlcl_strndup(const char *s, size_t cap);
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

/* errno-bearing chain batch C — write / fcntl / mmap, composition only on
 * darwin (success case; errno-store DCE'd). All uniform across targets (plain
 * syscall, no at-variant). write = read mirror; fcntl = plain 3-arg; mmap = raw
 * 6-arg syscall returning the mapped ADDRESS (not the libc MAP_FAILED-converted
 * value) — success is a positive address word. */
extern long   hxlcl_write(int fd, const void *buf, unsigned long n);
extern int    hxlcl_fcntl(int fd, int cmd, long arg);
extern long   hxlcl_mmap(void *addr, unsigned long len, int prot, int flags, int fd, long off);

/* errno-bearing chain batch D — open_sys / getrusage, composition only on darwin
 * (success case; errno-store DCE'd; the errno value-exact is the Linux sibling's
 * claim). open_sys = arm64 openat(AT_FDCWD,…) / darwin plain SYS_OPEN(3-arg);
 * getrusage = plain uniform 2-arg (out-ptr usage*). */
extern int    hxlcl_open_sys(const char *path, int flags, int mode);
extern int    hxlcl_getrusage(int who, void *usage);
/* batch E — pipe. On darwin BSD pipe is 2nd-return-register (fds in x0/x1); the
 * Route C leg DISSOLVES via __hx_syscall6_out2 (dual-return capture) and runs the
 * full success + write/read roundtrip here, the same claim the Linux pipe2 sibling
 * carries. */
extern int    hxlcl_pipe(int fds[2]);

/* batch F search family — strchr / strstr. Pure byte-scan leaves (no syscall, no
 * errno, no inner call); each returns a raw char* into the input or NULL. Fully
 * exercised here (cross-target-identical compute — the byteeq build proves the
 * emit is bit-equal on all 3 targets; this run proves the BEHAVIOUR). */
extern char  *hxlcl_strchr(const char *s, int c);
extern char  *hxlcl_strstr(const char *h, const char *n);

/* pure-leaf mirror batch — strrchr / memmove / bzero. Byte-faithful mirrors of the
 * already-wired strchr / memcpy / memset leaves (no syscall/errno/float/inner-call);
 * cross-target-identical compute (byteeq proves bit-equal emit, this run proves the
 * behaviour). strrchr returns the LAST match char* (or NULL); memmove returns dst
 * and handles overlap (backward copy when dst>src); bzero zeros n bytes. */
extern char  *hxlcl_strrchr(const char *s, int c);
extern void  *hxlcl_memmove(void *dst, const void *src, size_t n);
extern void   hxlcl_bzero(void *s, size_t n);

/* batch G parse family — strtoll. Pure-compute leaf (no syscall, no errno, no
 * inner call) with a NULL-gated `char** endptr` out-param write. Cross-target-
 * identical compute; this run exercises both the value parse AND the endptr
 * store64 (a non-NULL endptr → *endptr == nptr + consumed-length). */
extern long long hxlcl_strtoll(const char *nptr, char **endptr, int base);

/* parse mirror — strtoull. EXACT unsigned mirror of strtoll (same parse loop + same
 * NULL-gated endptr store64); differs only by no '-' negate + raw unsigned result.
 * Cross-target-identical compute; this run exercises value parse AND the endptr
 * store64 (non-NULL endptr → *endptr == nptr + consumed-length). */
extern unsigned long long hxlcl_strtoull(const char *nptr, char **endptr, int base);

/* batch H — time / poll. On darwin time uses gettimeofday(116) → reads tv_sec from
 * a hxlcl_malloc'd 16-byte scratch buffer (the heap-scratch substrate); poll uses
 * the plain 3-arg BSD poll(230). Both exercised fully here (the darwin smoke host
 * actually runs these legs). */
extern int  hxlcl_time(int *t);
extern int  hxlcl_poll(void *fds, unsigned int nfds, int timeout);

/* batch I — clock_gettime / execve. clock_gettime: darwin has no trap → the body
 * synthesizes a timespec from gettimeofday(116) written DIRECTLY into the caller's
 * out-ptr (leak-free); fully exercised here. execve: plain 3-arg; a bad path returns
 * the raw positive errno on darwin (carry-flag not read — the deferred darwin errno
 * path), composition-asserted (the Linux sibling carries the -1 + ENOENT claim). */
extern int  hxlcl_clock_gettime(int clk, void *ts);
extern int  hxlcl_execve(const char *path, char *const argv[], char *const envp[]);

/* batch J — fork. On darwin BSD fork(2) is 2nd-return-register: child pid in x0 for
 * BOTH processes, child disambiguated by x1==1. The Route C leg DISSOLVES via
 * __hx_syscall6_out2 (dual-return capture) and runs the live fork+_exit+waitpid
 * roundtrip here, the same claim the Linux sibling carries. */
extern int  hxlcl_fork(void);

/* Wall 2-b ENV — getenv. The FIRST Route C body to reference an extern DATA symbol:
 * it resolves the libc `environ` global through the GOT (the new __hx_environ_ptr
 * intrinsic) and byte-walks the NUL-terminated char** array. Pure compute after the
 * GOT load (no syscall, no errno, no inner bl). Returns a raw char* INTO the live
 * environ block (or NULL). `environ` itself comes from the C runtime (no harness
 * definition needed — the routec.o's GOT ref to _environ resolves against libSystem). */
extern char *hxlcl_getenv(const char *name);

/* Wall 2-b ENV (sibling) — setenv. The FIRST Route C body to WRITE BACK to the
 * `&environ` global: replace an existing slot in place (`*e = s`) or GROW a fresh
 * (N+2)-slot char** array and store it into environ via __hx_ptr_store64. Returns 0
 * on success, -1 (EINVAL) for NULL/empty name. The grow path mallocs via the same
 * header-writing hxlcl_malloc below; the writeback to environ is proven by reading
 * the new value back through BOTH hxlcl_getenv AND libc getenv (same live global). */
extern int hxlcl_setenv(const char *name, const char *value, int overwrite);

/* Wall 3-a CORE FILE* family — fopen/fclose/fread/fwrite/ftell/fseek/fdopen. The
 * FILE* is the frozen-floor fake pointer `(void*)(uintptr_t)(fd+1)` (NOT a libc
 * stdio struct), so these are a pure composition over the already-Route-C syscall
 * leaves (open_sys/read/write/lseek/close, all from routec.o). fread/fwrite return
 * the ITEM count (got/size), looping partial transfers; ftell/fseek wrap lseek.
 * Exercised here by a full write→close→reopen→read roundtrip with byte-exact +
 * position-exact asserts (the same behavioral claim the Linux sibling carries). */
extern void  *hxlcl_fopen(const char *path, const char *mode);
extern int    hxlcl_fclose(void *fp);
extern size_t hxlcl_fread(void *buf, size_t sz, size_t n, void *fp);
extern size_t hxlcl_fwrite(const void *buf, size_t sz, size_t n, void *fp);
extern long   hxlcl_ftell(void *fp);
extern int    hxlcl_fseek(void *fp, long offset, int whence);
extern void  *hxlcl_fdopen(int fd, const char *mode);

/* Wall 3-b STD-STREAM family — fputs/fputc/fflush. Unlike the CORE FILE* family
 * (fd+1 fake pointers), these take the LIBC GLOBALS stdout/stderr and detect the
 * target fd via __hx_stderr_ptr() (the new named-data GOT intrinsic): default fd=1,
 * fd=2 iff fp==stderr — byte-faithful to the frozen body. Exercised here by writing
 * a known string to a PIPE'd fd (dup2 stdout→pipe), reading it back byte-exact, and
 * asserting stderr-routing via a second pipe (dup2 stderr→pipe). fflush is the
 * trivial no-op (return 0). */
extern int    hxlcl_fputs(const char *s, void *fp);
extern int    hxlcl_fputc(int c, void *fp);
extern int    hxlcl_fflush(void *fp);

/* Wall 3-c POPEN family — popen/pclose. popen("cmd","r") = pipe()+fork()+execve(
 * "/bin/sh","-c",cmd), returning the CORE-family (read_fd+1) fake FILE*; pclose
 * decodes the fd, looks the child pid up in the __hx_static_slot fd→pid table, and
 * close()+waitpid()'s the child → status. THE NEW SUBSTRATE under test is
 * __hx_static_slot: a self-defined zero-init data buffer (the popen table) addressed
 * by a LOCAL `adrp _slot_900@PAGE / add @PAGEOFF` pair (DEFINED here, NOT an extern
 * GOT load — the def-side sibling of __hx_environ_ptr). This darwin run is the
 * self-static Mach-O `.zerofill`/`.zero` symbol emit+assemble+link proof. popen forks
 * /bin/sh via the darwin 2nd-return-register fork (out2); the child execve's; the
 * parent reads the pipe → "hi\n" and pclose waitpid's → 0. */
extern void  *hxlcl_popen(const char *cmd, const char *mode);
extern int    hxlcl_pclose(void *stream);

/* Inner-callee leaves the composites bl into — the retained-shim role, supplied
 * here (sole provider) so there is no multidef with the libc shim: malloc for
 * strdup + strndup + calloc + realloc. (Each composite PR adds its callee.)
 *
 * hxlcl_atoll is NO LONGER supplied here: the PARSE-LEAF PROMOTION batch made it a
 * real self-emitted Route C leaf (in routec.o), so atoi's inner `bl _hxlcl_atoll`
 * binds to that emitted body intra-object — defining it here too would multidef.
 *
 * This hxlcl_malloc writes the SAME 16-byte size header the floor hxlcl_malloc
 * does (store n at offset 0, hand back ptr+16) so hxlcl_realloc's negative-offset
 * header read `*(size_t*)(p - 16)` recovers the real old size. The 16-byte
 * payload prefix keeps the returned pointer 16-byte aligned. (Small leaks are
 * fine — this is a short-lived smoke process; the self-emitted hxlcl_free is a
 * no-op so it reclaims nothing anyway.) */
#define HXLCL_HDR 16
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

    /* composites (inner bl to self-emitted atoll / header-writing malloc).
     * No free() here: the header-writing hxlcl_malloc returns ptr+16, so libc
     * free(ptr) is wrong — and small leaks in a short smoke process are fine. */
    CK(hxlcl_atoi("42") == 42, "atoi 42");
    CK(hxlcl_atoi("-7") == -7, "atoi -7");

    /* parse-leaf promotion: atoll as a real self-emitted leaf — base-10 lenient
     * decimal (ws skip + sign + digit accumulation), no endptr. Exercised directly
     * (atoi above already bl's into it). */
    CK(hxlcl_atoll("42") == 42LL, "atoll(\"42\") == 42");
    CK(hxlcl_atoll("-7") == -7LL, "atoll(\"-7\") == -7 (sign)");
    CK(hxlcl_atoll("+99") == 99LL, "atoll(\"+99\") == 99 (plus sign)");
    CK(hxlcl_atoll("  123abc") == 123LL, "atoll leading-ws + trailing-garbage stop");
    CK(hxlcl_atoll("0") == 0LL, "atoll(\"0\") == 0");
    CK(hxlcl_atoll("") == 0LL, "atoll(\"\") == 0 (empty)");
    CK(hxlcl_atoll(NULL) == 0LL, "atoll(NULL) == 0 (NULL guard)");

    /* ctype: register-only pure-compute classification (arg is an int value). */
    CK(hxlcl_isalnum('A') == 1, "isalnum('A') == 1");
    CK(hxlcl_isalnum('z') == 1, "isalnum('z') == 1");
    CK(hxlcl_isalnum('5') == 1, "isalnum('5') == 1");
    CK(hxlcl_isalnum('_') == 0, "isalnum('_') == 0");
    CK(hxlcl_isalnum(' ') == 0, "isalnum(' ') == 0");
    CK(hxlcl_isalpha('A') == 1, "isalpha('A') == 1");
    CK(hxlcl_isalpha('q') == 1, "isalpha('q') == 1");
    CK(hxlcl_isalpha('5') == 0, "isalpha('5') == 0 (digit excluded)");
    CK(hxlcl_isalpha('_') == 0, "isalpha('_') == 0");

    /* alloc residue: no-op free must accept any pointer (incl. NULL) without crash. */
    hxlcl_free(NULL);
    { char *fp = (char *)malloc(8); hxlcl_free(fp); free(fp); }
    CK(1, "free no-op accepts NULL + heap ptr (no crash)");

    /* pure-compute mirror batch 4 — inet_pton dotted-quad parse + caller-write. */
    { unsigned char ip[4] = {9,9,9,9};
      CK(hxlcl_inet_pton(AF_INET, "1.2.3.4", ip) == 1, "inet_pton valid returns 1");
      CK(ip[0]==1 && ip[1]==2 && ip[2]==3 && ip[3]==4, "inet_pton writes 1.2.3.4"); }
    { unsigned char ip[4] = {9,9,9,9};
      CK(hxlcl_inet_pton(AF_INET, "255.0.128.17", ip) == 1, "inet_pton 255.0.128.17 ok");
      CK(ip[0]==255 && ip[1]==0 && ip[2]==128 && ip[3]==17, "inet_pton boundary octets"); }
    { unsigned char ip[4] = {7,7,7,7};
      CK(hxlcl_inet_pton(AF_INET, "256.0.0.1", ip) == 0, "inet_pton octet>255 -> 0");
      CK(ip[0]==7 && ip[1]==7 && ip[2]==7 && ip[3]==7, "inet_pton malformed leaves dst untouched"); }
    CK(hxlcl_inet_pton(AF_INET, "1.2.3", (unsigned char[4]){0}) == 0, "inet_pton too few octets -> 0");
    CK(hxlcl_inet_pton(AF_INET, "1.2.3.4.5", (unsigned char[4]){0}) == 0, "inet_pton too many octets -> 0");
    CK(hxlcl_inet_pton(AF_INET, "1.2.x.4", (unsigned char[4]){0}) == 0, "inet_pton stray char -> 0");
    CK(hxlcl_inet_pton(AF_INET, "1..3.4", (unsigned char[4]){0}) == 0, "inet_pton empty octet -> 0");
    CK(hxlcl_inet_pton(AF_INET6, "1.2.3.4", (unsigned char[4]){0}) == -1, "inet_pton non-AF_INET -> -1");

    /* pure-compute mirror batch 4 — no-op leaves return 0. */
    CK(hxlcl_setvbuf(NULL, NULL, 0, 0) == 0, "setvbuf no-op returns 0");
    CK(hxlcl_darwin_check_fd_set_overflow(3, NULL, 0) == 0, "darwin_check_fd_set_overflow returns 0");

    char *sdup = hxlcl_strdup("hi");
    CK(sdup != NULL && strcmp(sdup, "hi") == 0, "strdup content");

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

    /* batch C: write / fcntl / mmap — COMPOSITION on darwin (success case;
     * errno-store DCE'd). The errno value-exact (bad-fd → EBADF) is the Linux
     * sibling smoke's claim. write(1, "x", 1) → 1 byte; fcntl(0, F_GETFL) → the
     * stdin flags (>= 0); mmap of one page → a valid address (NOT MAP_FAILED). */
    CK(hxlcl_write(1, "", 0) == 0, "write(1, \"\", 0) == 0 (composition, no output)");
    {
        int wfd = open("/dev/null", O_WRONLY);
        CK(wfd >= 0, "open /dev/null for write test");
        CK(hxlcl_write(wfd, "x", 1) == 1, "write(/dev/null, \"x\", 1) == 1 (composition)");
        hxlcl_close(wfd);
    }

    /* fcntl(0, F_GETFL) returns the current stdin flags — always >= 0 for a
     * valid fd. Confirms the plain 3-arg trap composes (NO at-variant). */
    CK(hxlcl_fcntl(0, F_GETFL, 0) >= 0, "fcntl(0, F_GETFL) >= 0 (composition)");

    /* mmap one anonymous page → a valid mapped ADDRESS (the raw syscall returns
     * the address, NOT MAP_FAILED). MAP_FAILED == (void*)-1, so the body's
     * `__hx_payload_lt(r, 0)` success path returns the positive address word. */
    {
        long pg = (long)sysconf(_SC_PAGESIZE);
        if (pg <= 0) pg = 4096;
        long m = hxlcl_mmap(0, (unsigned long)pg, PROT_READ | PROT_WRITE,
                            MAP_ANON | MAP_PRIVATE, -1, 0);
        CK(m != (long)MAP_FAILED && m != -1 && m != 0,
           "mmap(anon page) → valid address (not MAP_FAILED, composition)");
        if (m != (long)MAP_FAILED && m != -1 && m != 0) {
            ((char *)m)[0] = 'q';                /* page is writable */
            CK(((char *)m)[0] == 'q', "mmap'd page is writable (composition)");
            munmap((void *)m, (size_t)pg);
        }
    }

    /* batch D: open_sys / getrusage — COMPOSITION on darwin (success case;
     * errno-store DCE'd; the errno value-exact is the Linux sibling's claim).
     * open_sys(/dev/null, O_RDONLY) → a valid fd (>= 0); on darwin this uses the
     * plain 3-arg SYS_OPEN (no AT_FDCWD), confirming the 3-arg trap composes.
     * getrusage(RUSAGE_SELF, &ru) → 0 (success; the out-ptr usage* reaches the
     * kernel and the plain 2-arg trap composes). */
    {
        int ofd = hxlcl_open_sys("/dev/null", O_RDONLY, 0);
        CK(ofd >= 0, "open_sys(/dev/null, O_RDONLY) >= 0 (composition)");
        if (ofd >= 0) hxlcl_close(ofd);
    }
    {
        struct rusage ru;
        CK(hxlcl_getrusage(RUSAGE_SELF, &ru) == 0, "getrusage(RUSAGE_SELF) == 0 (composition, out-ptr)");
    }

    /* batch E: pipe — DARWIN 2nd-return-register DISSOLVE (via __hx_syscall6_out2).
     * BSD pipe(42) returns the two fds in x0/x1; the dual-return intrinsic captures
     * both regs into a heap scratch and the darwin leg copies them into the int[2].
     * Full success + write→read roundtrip (the same claim the Linux pipe2 sibling
     * carries) — proving both fds are valid and usable, i.e. fds[1] is no longer
     * lost. */
    {
        int pfd[2] = { -1, -1 };
        CK(hxlcl_pipe(pfd) == 0, "pipe() == 0 on darwin (2nd-return-reg dual capture)");
        CK(pfd[0] >= 0 && pfd[1] >= 0, "pipe() fills fds[0],fds[1] from x0/x1 (value-exact)");
        if (pfd[0] >= 0 && pfd[1] >= 0) {
            char wb = 'Z', rb = 0;
            CK(write(pfd[1], &wb, 1) == 1, "darwin pipe write end usable");
            CK(read(pfd[0], &rb, 1) == 1 && rb == 'Z', "darwin pipe read end roundtrip == 'Z'");
            hxlcl_close(pfd[0]);
            hxlcl_close(pfd[1]);
        }
    }

    /* batch F: strchr / strstr — pure byte-scan leaves (cross-target-identical,
     * fully exercised here). strchr returns a pointer INTO the input at the match
     * (or NULL); the c==0 case must return the terminator pointer (folded match
     * ordering). strstr returns a pointer to the first substring occurrence (or
     * NULL); empty needle → haystack head. The returned pointers are checked by
     * identity (== s + offset) AND by content, so a PAIR-MODEL ABI leak (boxed
     * pointer) or an off-by-one would be caught. */
    {
        const char *abc = "abcXYZabc";
        CK(hxlcl_strchr(abc, 'X') == abc + 3, "strchr finds first 'X' at &abc[3]");
        CK(hxlcl_strchr(abc, 'a') == abc + 0, "strchr finds first 'a' at &abc[0]");
        CK(hxlcl_strchr(abc, 'z') == NULL,    "strchr('z') → NULL (absent)");
        CK(hxlcl_strchr(abc, 0) == abc + 9,   "strchr(0) → terminator pointer");
    }
    {
        const char *hay = "hello world";
        CK(hxlcl_strstr(hay, "ll")    == hay + 2, "strstr 'll' → &hay[2]");
        CK(hxlcl_strstr(hay, "world") == hay + 6, "strstr 'world' → &hay[6]");
        CK(hxlcl_strstr(hay, "hello") == hay + 0, "strstr 'hello' → &hay[0]");
        CK(hxlcl_strstr(hay, "")      == hay + 0, "strstr empty needle → &hay[0]");
        CK(hxlcl_strstr(hay, "xyz")   == NULL,    "strstr 'xyz' → NULL (absent)");
        CK(hxlcl_strstr(hay, "worlds") == NULL,   "strstr needle past haystack end → NULL");
        CK(hxlcl_strstr("aaa", "aab") == NULL,    "strstr partial-then-mismatch → NULL");
    }

    /* pure-leaf mirror batch: strrchr / memmove / bzero — pure byte ops mirroring
     * strchr / memcpy / memset. Pointers checked by identity AND content, so a
     * PAIR-MODEL ABI leak (boxed pointer) or off-by-one would be caught. */
    {
        const char *abc = "abcXYZabc";
        CK(hxlcl_strrchr(abc, 'a') == abc + 6, "strrchr finds LAST 'a' at &abc[6]");
        CK(hxlcl_strrchr(abc, 'X') == abc + 3, "strrchr finds 'X' at &abc[3]");
        CK(hxlcl_strrchr(abc, 'z') == NULL,    "strrchr('z') → NULL (absent)");
        CK(hxlcl_strrchr(abc, 0) == abc + 9,   "strrchr(0) → terminator pointer");
    }
    {
        char b1[16]; memcpy(b1, "ABCDEFGH", 9);
        CK(hxlcl_memmove(b1, b1 + 2, 6) == b1, "memmove returns dst");
        CK(memcmp(b1, "CDEFGH", 6) == 0, "memmove forward (dst<src overlap) shifts left");
    }
    {
        char b2[16]; memcpy(b2, "ABCDEFGH", 9);
        hxlcl_memmove(b2 + 2, b2, 6);          /* dst>src overlap → backward copy */
        CK(memcmp(b2, "ABABCDEF", 8) == 0, "memmove backward (dst>src overlap) shifts right");
    }
    {
        char b3[8]; memset(b3, 0x55, 8);
        hxlcl_bzero(b3 + 1, 4);
        CK(b3[0] == 0x55 && b3[1] == 0 && b3[2] == 0 && b3[3] == 0 &&
           b3[4] == 0 && b3[5] == 0x55, "bzero zeros bytes [1..5), leaves neighbours");
    }

    /* batch G: strtoll — value parse + endptr store64 (the OUT-PARAM write under
     * test). endptr==NULL exercises the NULL-gate (no store); endptr!=NULL
     * exercises the __hx_ptr_store64 → *endptr == nptr + consumed-length. */
    {
        CK(hxlcl_strtoll("42", NULL, 10) == 42, "strtoll(\"42\",NULL,10) == 42 (endptr NULL-gate)");
        CK(hxlcl_strtoll("-7", NULL, 10) == -7, "strtoll(\"-7\",NULL,10) == -7 (sign)");
        CK(hxlcl_strtoll("+99", NULL, 10) == 99, "strtoll(\"+99\",NULL,10) == 99 (plus sign)");
        CK(hxlcl_strtoll("  123abc", NULL, 10) == 123, "strtoll leading-ws + trailing-garbage stop");
        CK(hxlcl_strtoll("0", NULL, 10) == 0, "strtoll(\"0\") == 0");
        CK(hxlcl_strtoll("ff", NULL, 16) == 255, "strtoll(\"ff\",16) == 255 (lowercase hex)");
        CK(hxlcl_strtoll("0755", NULL, 0) == 493, "strtoll(\"0755\",0) == 0755 octal (493)");
        CK(hxlcl_strtoll("10", NULL, 0) == 10, "strtoll(\"10\",0) == 10 (decimal auto)");
        const char *hx = "0xFF";
        char *endp = NULL;
        long long v = hxlcl_strtoll(hx, &endp, 16);
        CK(v == 255, "strtoll(\"0xFF\",&end,16) == 255 (0x prefix skip)");
        CK(endp == hx + 4, "strtoll endptr == nptr+4 (store64 out-param write)");
        const char *mix = "12x";
        char *endp2 = NULL;
        CK(hxlcl_strtoll(mix, &endp2, 10) == 12, "strtoll(\"12x\",&end,10) == 12");
        CK(endp2 == mix + 2, "strtoll endptr stops at first non-digit (mix+2)");
        /* NULL nptr → 0, endptr (if given) set to nptr(NULL). */
        char *endp3 = (char *)0x1;
        CK(hxlcl_strtoll(NULL, &endp3, 10) == 0, "strtoll(NULL,&end,10) == 0");
        CK(endp3 == NULL, "strtoll(NULL) sets *endptr = NULL");
    }

    /* parse mirror: strtoull — unsigned mirror of strtoll. Same parse + endptr
     * store64 out-param; differs only by no '-' negate + raw unsigned result. */
    {
        CK(hxlcl_strtoull("42", NULL, 10) == 42ULL, "strtoull(\"42\",NULL,10) == 42 (endptr NULL-gate)");
        CK(hxlcl_strtoull("+99", NULL, 10) == 99ULL, "strtoull(\"+99\",NULL,10) == 99 (plus sign)");
        CK(hxlcl_strtoull("  123abc", NULL, 10) == 123ULL, "strtoull leading-ws + trailing-garbage stop");
        CK(hxlcl_strtoull("0", NULL, 10) == 0ULL, "strtoull(\"0\") == 0");
        CK(hxlcl_strtoull("ff", NULL, 16) == 255ULL, "strtoull(\"ff\",16) == 255 (lowercase hex)");
        CK(hxlcl_strtoull("0755", NULL, 0) == 493ULL, "strtoull(\"0755\",0) == 0755 octal (493)");
        CK(hxlcl_strtoull("10", NULL, 0) == 10ULL, "strtoull(\"10\",0) == 10 (decimal auto)");
        /* large unsigned value that overflows signed long long → exercises the
         * unsigned path (strtoll would wrap negative; strtoull returns it raw). */
        CK(hxlcl_strtoull("18446744073709551615", NULL, 10) == 18446744073709551615ULL,
           "strtoull(ULLONG_MAX) == 0xFFFFFFFFFFFFFFFF (unsigned, no negate)");
        const char *uhx = "0xFF";
        char *uendp = NULL;
        unsigned long long uv = hxlcl_strtoull(uhx, &uendp, 16);
        CK(uv == 255ULL, "strtoull(\"0xFF\",&end,16) == 255 (0x prefix skip)");
        CK(uendp == uhx + 4, "strtoull endptr == nptr+4 (store64 out-param write)");
        const char *umix = "12x";
        char *uendp2 = NULL;
        CK(hxlcl_strtoull(umix, &uendp2, 10) == 12ULL, "strtoull(\"12x\",&end,10) == 12");
        CK(uendp2 == umix + 2, "strtoull endptr stops at first non-digit (mix+2)");
        char *uendp3 = (char *)0x1;
        CK(hxlcl_strtoull(NULL, &uendp3, 10) == 0ULL, "strtoull(NULL,&end,10) == 0");
        CK(uendp3 == NULL, "strtoull(NULL) sets *endptr = NULL");
    }

    /* dup mirror: strndup — strdup composite + cap-bounded scan. Checks the cap
     * truncation (no-NUL-within-cap), the NUL-before-cap short copy, cap==0, and
     * NULL passthrough — the strndup behaviour battery from the SELFEMIT seed. */
    {
        char *d1 = hxlcl_strndup("hello", 3);   /* cap < strlen → truncated copy */
        CK(d1 != NULL && strcmp(d1, "hel") == 0, "strndup(\"hello\",3) == \"hel\" (cap truncates)");
        char *d2 = hxlcl_strndup("hi", 10);     /* cap > strlen → full copy (NUL-before-cap) */
        CK(d2 != NULL && strcmp(d2, "hi") == 0, "strndup(\"hi\",10) == \"hi\" (NUL before cap)");
        char *d3 = hxlcl_strndup("abc", 0);     /* cap == 0 → empty string */
        CK(d3 != NULL && d3[0] == '\0', "strndup(\"abc\",0) == \"\" (cap==0)");
        char *d4 = hxlcl_strndup("xyz", 3);     /* cap == strlen → full copy */
        CK(d4 != NULL && strcmp(d4, "xyz") == 0, "strndup(\"xyz\",3) == \"xyz\" (cap==len)");
        CK(hxlcl_strndup(NULL, 5) == NULL, "strndup(NULL,5) == NULL (NULL passthrough)");
    }

    /* batch H — time / poll. FULLY EXERCISED on this darwin host (both legs run).
     * time: darwin has no BSD `time` trap, so the body uses gettimeofday(116) into a
     * hxlcl_malloc'd 16-byte scratch (the heap-scratch substrate) and reads tv_sec —
     * assert it is post-2023 AND within ±2s of libc time(NULL), plus the NULL-gated
     * out-param (*t == return). poll: plain 3-arg BSD poll(230) — assert poll(no fds,
     * 0ms) == 0 and a real pollfd on a pipe (empty → 0, data-ready → 1). */
    {
        long ref = (long)time(NULL);
        int t1 = hxlcl_time(NULL);
        CK(t1 > 1700000000, "time(NULL) > 2023-11 epoch (darwin gettimeofday tv_sec via heap scratch)");
        CK((long)t1 - ref <= 2 && ref - (long)t1 <= 2, "time(NULL) ~= libc time(NULL) (within 2s)");
        int tt = -1;
        int t2 = hxlcl_time(&tt);
        CK(tt == t2, "time(&t) writes *t == return (NULL-gated out-param store32)");
        CK(t2 > 1700000000, "time(&t) return > 2023-11 epoch");

        CK(hxlcl_poll(NULL, 0, 0) == 0, "poll(NULL, 0, 0ms) == 0 (no fds, immediate)");
        int ph[2];
        if (pipe(ph) == 0) {
            struct pollfd pf;
            pf.fd = ph[0]; pf.events = POLLIN; pf.revents = 0;
            CK(hxlcl_poll(&pf, 1, 0) == 0, "poll(pipe read end, empty, 0ms) == 0");
            if (write(ph[1], "z", 1) == 1) {
                pf.revents = 0;
                CK(hxlcl_poll(&pf, 1, 100) == 1, "poll(pipe read end, data ready, 100ms) == 1 (POLLIN)");
            }
            close(ph[0]); close(ph[1]);
        }
    }

    /* batch I — clock_gettime / execve. FULLY exercised on this darwin host.
     * clock_gettime: darwin has no trap, so the body uses gettimeofday(116) written
     * directly into the caller's timespec out-ptr and converts tv_usec→tv_nsec*1000
     * in place — assert it returns 0, tv_sec is post-2023, and tv_nsec is a valid
     * [0,1e9) sub-second (the usec*1000 conversion + the trailing-garbage overwrite).
     * execve: a bad path can never succeed (success replaces the process); on darwin
     * the carry flag is not read, so the body returns the raw POSITIVE errno (> 0) —
     * composition-assert it returns a positive failure code and the process survives
     * (the Linux sibling carries the -1 + ENOENT value-exact claim). Asserting > 0
     * locks the documented darwin carry-flag-deferred gap (a future darwin errno fix
     * would flip it to -1 and force a smoke update, same discipline as pipe == -1). */
    {
        struct timespec ts;
        ts.tv_sec = 0; ts.tv_nsec = -1;
        CK(hxlcl_clock_gettime(CLOCK_REALTIME, &ts) == 0, "clock_gettime(CLOCK_REALTIME) == 0 (darwin gettimeofday synth)");
        CK(ts.tv_sec > 1700000000, "clock_gettime tv_sec > 2023-11 epoch (out-ptr written)");
        CK(ts.tv_nsec >= 0 && ts.tv_nsec < 1000000000, "clock_gettime tv_nsec in [0,1e9) (usec*1000, garbage overwritten)");

        char *eargv[] = { (char *)"x", NULL };
        char *eenvp[] = { NULL };
        CK(hxlcl_execve("/nonexistent_xyz_exec_zzz", eargv, eenvp) > 0, "execve(bad path) > 0 (darwin raw +errno, carry deferred; process intact)");
    }

    /* batch J — fork. DARWIN 2nd-return-register DISSOLVE (via __hx_syscall6_out2).
     * BSD fork(2) returns the child pid in x0 for BOTH parent and child and
     * disambiguates the child by x1==1; the dual-return intrinsic captures x0/x1 so
     * the darwin leg returns 0 in the child and the child pid in the parent (mirror
     * of the floor raw-asm dual-reg shim). Live fork+_exit+waitpid roundtrip — the
     * same behavioral claim the Linux sibling carries. */
    {
        int pid = hxlcl_fork();
        if (pid == 0) { _exit(42); }   /* child: distinguish via the 2nd return reg */
        CK(pid > 0, "fork() > 0 in parent (child pid via x0; child took x1==1 path)");
        if (pid > 0) {
            int st = 0;
            int w = (int)waitpid(pid, &st, 0);
            CK(w == pid && WIFEXITED(st) && WEXITSTATUS(st) == 42,
               "darwin fork+_exit(42)+waitpid roundtrip (dual-return disambiguation)");
        }
    }

    /* Wall 2-b — getenv via the __hx_environ_ptr named-data GOT intrinsic + byte-walk.
     * FULLY exercised here (the GOT load + array walk is host-runnable on darwin).
     * Value-exact vs libc getenv() AND content-exact for a set var; an absent key →
     * NULL; a prefix of a real key → NULL (the break-free early-stop must not match a
     * longer entry, nor over-read a shorter one). The returned pointer is INTO the same
     * live environ block libc walks, so identity (== libc getenv) holds — a wrong GOT
     * deref depth, a PAIR-MODEL ABI leak, or an over-read would crash/mis-return. */
    {
        CK(hxlcl_getenv("__HX_NONEXISTENT_KEY_ZZZ__") == NULL, "getenv(absent key) → NULL");
        char *hp = hxlcl_getenv("PATH");
        char *lp = getenv("PATH");
        CK(hp != NULL, "getenv(\"PATH\") != NULL");
        CK(hp != NULL && hp[0] != 0, "getenv(\"PATH\") non-empty");
        CK(hp == lp, "getenv(\"PATH\") == libc getenv (same environ-block pointer, value-exact)");
        setenv("HX_SMOKE_ENVVAR", "route-c-wall2b", 1);
        char *sv = hxlcl_getenv("HX_SMOKE_ENVVAR");
        CK(sv != NULL && strcmp(sv, "route-c-wall2b") == 0, "getenv(set var) == value (content-exact)");
        setenv("HX_SMOKE_LONGKEY", "L", 1);
        CK(hxlcl_getenv("HX_SMOKE_LONG") == NULL, "getenv(prefix of a real key) → NULL (early-stop, no over-read)");
        /* A longer query than any matching entry must also miss (entry NUL before
         * nlen → the `entry[i]==0` early-stop fires, no over-read past the entry). */
        CK(hxlcl_getenv("HX_SMOKE_ENVVAR_EXTRA") == NULL, "getenv(query longer than a real key) → NULL (short-entry stop)");
    }

    /* Wall 2-b (sibling) — setenv: the environ WRITE-BACK. Reference-match POSIX
     * setenv(3): GROW for a fresh key (writeback must reach the live global so BOTH
     * hxlcl_getenv AND libc getenv see it), in-place slot REPLACE on overwrite!=0,
     * NO-OP preserve on overwrite==0, repeated GROW (second fresh key) keeping the
     * first, and EINVAL (-1) for NULL/empty name. Value-exact throughout. A writeback
     * that landed in a COPY instead of &environ would make libc getenv miss the new
     * key — the strongest proof the store reached the global. */
    {
        /* (1) GROW — fresh key; writeback reaches the live global (libc getenv sees it). */
        CK(hxlcl_setenv("HX_RC_NEW", "v1", 1) == 0, "setenv(fresh key) → 0");
        char *g1 = hxlcl_getenv("HX_RC_NEW");
        CK(g1 != NULL && strcmp(g1, "v1") == 0, "setenv(fresh): hxlcl_getenv == \"v1\" (content-exact)");
        char *l1 = getenv("HX_RC_NEW");
        CK(l1 != NULL && strcmp(l1, "v1") == 0, "setenv(fresh): libc getenv == \"v1\" (writeback reached &environ)");
        /* (2) REPLACE — overwrite!=0 swaps the slot in place. */
        CK(hxlcl_setenv("HX_RC_NEW", "v2", 1) == 0, "setenv(overwrite=1) → 0");
        char *g2 = hxlcl_getenv("HX_RC_NEW");
        CK(g2 != NULL && strcmp(g2, "v2") == 0, "setenv(overwrite): value replaced → \"v2\"");
        /* (3) NO-OP — overwrite==0 must preserve the existing value. */
        CK(hxlcl_setenv("HX_RC_NEW", "v3", 0) == 0, "setenv(overwrite=0, exists) → 0");
        char *g3 = hxlcl_getenv("HX_RC_NEW");
        CK(g3 != NULL && strcmp(g3, "v2") == 0, "setenv(overwrite=0): value preserved → \"v2\"");
        /* (4) repeated GROW — a second fresh key; the prior key must survive the regrow. */
        CK(hxlcl_setenv("HX_RC_NEW2", "w1", 1) == 0, "setenv(second fresh key) → 0");
        char *g4 = hxlcl_getenv("HX_RC_NEW2");
        CK(g4 != NULL && strcmp(g4, "w1") == 0, "setenv(regrow): new key == \"w1\"");
        char *g5 = hxlcl_getenv("HX_RC_NEW");
        CK(g5 != NULL && strcmp(g5, "v2") == 0, "setenv(regrow): prior key HX_RC_NEW survives == \"v2\"");
        /* (5) EINVAL — NULL and empty name → -1. */
        CK(hxlcl_setenv(NULL, "x", 1) == -1, "setenv(NULL name) → -1 (EINVAL)");
        CK(hxlcl_setenv("", "x", 1) == -1, "setenv(empty name) → -1 (EINVAL)");
    }

    /* Wall 3-a — CORE FILE* family roundtrip. fopen("w") → fwrite known bytes →
     * fclose → fopen("r") → fread → byte-exact match + ftell/fseek position-exact.
     * The fake FILE* is fd+1 (the floor encoding), so this exercises the full
     * compose-over-syscalls path (open_sys/write/close/read/lseek). FULLY run on
     * darwin (real file I/O). */
    {
        char tmpl[] = "/tmp/routec_file_XXXXXX";
        int tfd = mkstemp(tmpl);
        CK(tfd >= 0, "mkstemp for FILE* roundtrip");
        if (tfd >= 0) close(tfd);   /* close; reopen through hxlcl_fopen */

        const char payload[] = "RouteC-FILE-roundtrip-0123456789";  /* 32 bytes */
        size_t plen = sizeof(payload) - 1;

        void *fw = hxlcl_fopen(tmpl, "w");
        CK(fw != NULL, "fopen(w) != NULL (fd+1 fake FILE*)");
        CK(hxlcl_fwrite(payload, 1, plen, fw) == plen, "fwrite(size=1) item count == 32");
        CK(hxlcl_fclose(fw) == 0, "fclose(w) == 0");

        void *fr = hxlcl_fopen(tmpl, "r");
        CK(fr != NULL, "fopen(r) != NULL");
        char rbuf[64]; memset(rbuf, 0, sizeof rbuf);
        CK(hxlcl_fread(rbuf, 1, plen, fr) == plen, "fread(size=1) item count == 32");
        CK(memcmp(rbuf, payload, plen) == 0, "fread bytes == fwrite bytes (value-exact)");
        CK(hxlcl_ftell(fr) == (long)plen, "ftell after reading 32 == 32 (position-exact)");

        CK(hxlcl_fseek(fr, 0, SEEK_SET) == 0, "fseek(SET, 0) == 0");
        CK(hxlcl_ftell(fr) == 0, "ftell after rewind == 0");
        char ib[8]; memset(ib, 0, sizeof ib);
        CK(hxlcl_fread(ib, 4, 1, fr) == 1, "fread(size=4, n=1) → 1 item (item-count math)");
        CK(memcmp(ib, payload, 4) == 0, "fread item content matches first 4 bytes");
        CK(hxlcl_ftell(fr) == 4, "ftell after a 4-byte item == 4");
        CK(hxlcl_fseek(fr, 10, SEEK_SET) == 0, "fseek(SET, 10) == 0");
        CK(hxlcl_ftell(fr) == 10, "ftell after seek(10) == 10 (position-exact)");
        CK(hxlcl_fclose(fr) == 0, "fclose(r) == 0");

        /* fdopen: wrap a raw fd and read through the fake FILE*. */
        int rawfd = open(tmpl, O_RDONLY);
        CK(rawfd >= 0, "open raw fd for fdopen test");
        void *fd_fp = hxlcl_fdopen(rawfd, "r");
        CK(fd_fp != NULL, "fdopen(rawfd) != NULL (fd+1 wrap)");
        char db[8]; memset(db, 0, sizeof db);
        CK(hxlcl_fread(db, 1, 4, fd_fp) == 4, "fread via fdopen'd fd → 4");
        CK(memcmp(db, payload, 4) == 0, "fdopen fread content matches");
        CK(hxlcl_fclose(fd_fp) == 0, "fclose(fdopen) == 0");

        unlink(tmpl);
    }

    /* Wall 3-b — STD-STREAM family fputs/fputc/fflush. fflush is a definitional
     * no-op; fputs/fputc detect the target fd from the libc stdout/stderr globals
     * (default fd=1, fd=2 iff fp==stderr — via __hx_stderr_ptr). Exercised by
     * redirecting fd 1 and fd 2 to pipes (dup2), writing through hxlcl_fputs/fputc
     * with the REAL libc stdout/stderr pointers, then reading each pipe back byte-
     * exact — proving the stderr-vs-default routing is value-correct (a wrong
     * __hx_stderr_ptr GOT load, or a missing pointer-compare, would misroute the
     * stderr write to fd 1 and the stdout pipe would carry the wrong bytes). */
    {
        CK(hxlcl_fflush(stdout) == 0, "fflush(stdout) == 0 (no-op leaf)");
        CK(hxlcl_fflush(stderr) == 0, "fflush(stderr) == 0 (no-op leaf)");
        CK(hxlcl_fflush(NULL)   == 0, "fflush(NULL) == 0 (no-op leaf)");

        int op1[2], op2[2];
        if (pipe(op1) == 0 && pipe(op2) == 0) {
            int save1 = dup(1), save2 = dup(2);
            /* route fd 1 → op1 write-end, fd 2 → op2 write-end */
            dup2(op1[1], 1);
            dup2(op2[1], 2);
            /* stdout path: default fd=1 (fp != stderr) */
            int wo = hxlcl_fputs("OUT", stdout);
            int wc = hxlcl_fputc('!', stdout);
            /* stderr path: fp == stderr → fd=2 */
            int we = hxlcl_fputs("ERR", stderr);
            /* restore real stdout/stderr BEFORE any printf in CK */
            dup2(save1, 1); dup2(save2, 2);
            close(save1); close(save2);
            close(op1[1]); close(op2[1]);

            char b1[16]; char b2[16];
            ssize_t r1 = read(op1[0], b1, sizeof(b1)); if (r1 < 0) r1 = 0; b1[r1] = 0;
            ssize_t r2 = read(op2[0], b2, sizeof(b2)); if (r2 < 0) r2 = 0; b2[r2] = 0;
            close(op1[0]); close(op2[0]);

            CK(wo == 3, "fputs(\"OUT\", stdout) → 3 bytes");
            CK(wc == '!', "fputc('!', stdout) → '!' (success returns the char)");
            CK(we == 3, "fputs(\"ERR\", stderr) → 3 bytes");
            CK(strcmp(b1, "OUT!") == 0, "stdout pipe got \"OUT!\" (default fd=1, byte-exact)");
            CK(strcmp(b2, "ERR") == 0, "stderr pipe got \"ERR\" (fp==stderr → fd=2, routing-exact)");
        } else {
            CK(0, "pipe() setup for std-stream routing test");
        }
    }

    /* Wall 3-c — popen/pclose roundtrip over the __hx_static_slot fd→pid table.
     * popen("echo hi","r") forks /bin/sh -c "echo hi" (darwin 2nd-return-reg fork via
     * out2); its stdout (the pipe) yields "hi\n"; pclose waitpid's the child → 0. The
     * self-static popen table is the new __hx_static_slot Mach-O .data buffer — this
     * is its emit+assemble+link+address proof. Locals named to AVOID any libc shadow
     * (no `popen`/`read`/`status` local overriding a libc name — the dup()-shadow
     * lesson). Value-exact: content == "hi\n" AND pclose status == 0. */
    {
        void *phandle = hxlcl_popen("echo hi", "r");
        CK(phandle != (void *)0, "popen(\"echo hi\",\"r\") != NULL");
        if (phandle != (void *)0) {
            char rdbuf[32];
            memset(rdbuf, 0, sizeof(rdbuf));
            size_t got = hxlcl_fread(rdbuf, 1, sizeof(rdbuf) - 1, phandle);
            rdbuf[got] = 0;
            CK(strcmp(rdbuf, "hi\n") == 0, "popen child stdout == \"hi\\n\" (byte-exact)");
            int pcst = hxlcl_pclose(phandle);
            CK(pcst == 0, "pclose(child exit 0) == 0 (status-exact)");
        }
    }

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
echo "[routec-smoke] GREEN — Route C ON-path emit links + runs correct (pure-arith + composite + syscall families + batch F search strchr/strstr + pure-leaf mirror strrchr/memmove/bzero + parse/dup mirror strtoull/strndup + parse-leaf promotion atoll + ctype isalnum/isalpha + alloc-residue free + pure-compute mirror batch4 inet_pton/setvbuf/darwin_check_fd_set_overflow + Wall 3-a CORE FILE* fopen/fread/fwrite/fseek/ftell/fclose/fdopen + Wall 3-b STD-STREAM fputs/fputc/fflush, darwin-arm64)"
