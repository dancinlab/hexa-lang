#!/usr/bin/env bash
# tool/routec_cabi_smoke_linux.sh — RFC061 §M8 Route C ON-PATH errno smoke (LINUX).
#
# WHAT THIS PROVES (the gap the darwin smoke does NOT cover)
# ─────────────────────────────────────────────────────────────────────
# The darwin smoke (tool/routec_cabi_smoke.sh, macos-15) DCE's out the
# errno-store leg of hxlcl_close (its `target_is_linux()` guard is a compile-time
# FALSE const on darwin), so the errno-store machine code is emitted by NO CI.
# Without this Linux sibling, the ② extern-data substrate (errno SET via
# `__errno_location()` + `__hx_ptr_store32`) would have ZERO direct ON-path
# coverage — the same Route C 0-coverage gap the darwin smoke was created to
# close, recurring for the errno leg.
#
# This job closes it on the LINUX target where the errno-store is LIVE: it builds
# aprime_cc, emits hxlcl_core.hexa with `HEXA_CABI_HXLCL=1 --target=x86_64-linux`,
# links the emitted .o against a C harness, and asserts close's errno contract
# VALUE-EXACT: close(valid)==0, close(already-closed)==-1 AND errno==EBADF. The
# EBADF value-exact assertion is the substrate's core claim (a wrong NR, a missing
# errno store, or a botched __errno_location C-ABI call would all fail here).
#
# linux-x86_64 ONLY: aprime_cc's `build_aprime.sh` has a "Linux x86_64" graduated
# path (runtime_hi_x86_64.s ELF). On other hosts this is a loud no-op (exit 0).
#
#   tool/routec_cabi_smoke_linux.sh
#
set -euo pipefail

HX="${HX_ROOT:-$(cd "$(dirname "$0")/.."; pwd)}"
CC="${CC:-cc}"

# ── host gate: this smoke's aprime emit path is graduated on linux-x86_64 ─────
if [ "$(uname -s)" != "Linux" ] || [ "$(uname -m)" != "x86_64" ]; then
    echo "[routec-smoke-linux] SKIP — Route C errno smoke runs on linux-x86_64 only (host=$(uname -sm))"
    exit 0
fi

APRIME="${APRIME:-$HX/build/aprime_cc}"
if [ ! -x "$APRIME" ]; then
    echo "[routec-smoke-linux] building aprime_cc (tool/build_aprime.sh) …"
    bash "$HX/tool/build_aprime.sh" -o "$APRIME"
fi
[ -x "$APRIME" ] || { echo "[routec-smoke-linux] FATAL: aprime_cc not at $APRIME" >&2; exit 1; }

SRC="$HX/stdlib/runtime/hxlcl_core.hexa"
[ -f "$SRC" ] || { echo "[routec-smoke-linux] FATAL: SSOT missing: $SRC" >&2; exit 1; }

TMP="$(mktemp -d -t routec_smoke_linux.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
printf 'fn _drv_unused() {}\n' > "$TMP/_drv.hexa"

# ── (1) Route C emit on the LINUX target — errno-store leg is LIVE here ──────
echo "[routec-smoke-linux] (1) emit hxlcl_core.hexa with HEXA_CABI_HXLCL=1 --target=x86_64-linux …"
HEXA_CABI_HXLCL=1 HEXA_INLINE_INT_BOX=1 HEXA_INLINE_BOOL_BOX=1 \
    "$APRIME" "$TMP/_drv.hexa" --emit=asm \
    --target=x86_64-linux-gnu -o "$TMP/routec.s" "$SRC"
[ -s "$TMP/routec.s" ] || { echo "[routec-smoke-linux] FATAL: empty routec.s" >&2; exit 1; }
"$CC" -c "$TMP/routec.s" -o "$TMP/routec.o"
[ -s "$TMP/routec.o" ] || { echo "[routec-smoke-linux] FATAL: empty routec.o" >&2; exit 1; }

# ── (2) assert the errno-bearing syscall symbols are DEFINED external text
#    (bare ELF names — no leading underscore). ──
echo "[routec-smoke-linux] (2) assert errno-bearing syscall symbols defined in routec.o …"
syms="$(nm "$TMP/routec.o" 2>/dev/null || true)"
miss=0
for s in close read lseek dup2 mkdir stat waitpid write fcntl mmap open_sys getrusage pipe time poll clock_gettime execve fork getenv setenv fopen fclose fread fwrite ftell fseek fdopen; do
    if ! grep -qE " T hxlcl_${s}\$" <<<"$syms"; then
        echo "[routec-smoke-linux] NOT DEFINED (T): hxlcl_${s}" >&2; miss=$((miss+1))
    fi
done
[ "$miss" -eq 0 ] || { echo "[routec-smoke-linux] FATAL: $miss symbol(s) not emitted" >&2; exit 1; }

# ── (3) C harness: the close errno VALUE-EXACT contract. `__errno_location` is
#    provided by libc (the Route C body bl's into it as an undefined-external,
#    resolved at link); no shim needed since close has no other inner callee. ──
cat > "$TMP/harness.c" <<'CEOF'
#include <fcntl.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>     /* strerror — for the mmap diagnostic line */
#include <unistd.h>
#include <sys/stat.h>   /* struct stat — sized buffer for hxlcl_stat */
#include <sys/wait.h>   /* waitpid options — for hxlcl_waitpid */
#include <sys/mman.h>   /* PROT_/MAP_ flags / MAP_FAILED — for hxlcl_mmap */
#include <sys/resource.h> /* struct rusage / RUSAGE_SELF — for hxlcl_getrusage */
#include <poll.h>       /* struct pollfd / POLLIN — for hxlcl_poll */
#include <time.h>       /* time() — the reference oracle for hxlcl_time */

/* Route-C-emitted symbols under test (raw C-ABI prototypes). */
extern int  hxlcl_close(int fd);
extern long hxlcl_read(int fd, void *buf, unsigned long n);
extern long hxlcl_lseek(int fd, long off, int whence);
extern int  hxlcl_dup2(int oldfd, int newfd);   /* arm64 → dup3(old,new,0) */
extern int  hxlcl_mkdir(const char *path, int mode); /* arm64 → mkdirat(AT_FDCWD,…) */
extern int  hxlcl_stat(const char *path, void *statbuf); /* arm64 → fstatat(AT_FDCWD,…) */
extern int  hxlcl_waitpid(int pid, int *status, int opts); /* → wait4(…, rusage=NULL) */
/* batch C — uniform plain syscalls (no at-variant): write / fcntl / mmap. mmap
 * returns the raw mapped ADDRESS on success or -errno on failure (NOT the libc
 * MAP_FAILED sentinel — that conversion is the wrapper layer above this raw .o). */
extern long hxlcl_write(int fd, const void *buf, unsigned long n);
extern int  hxlcl_fcntl(int fd, int cmd, long arg);
extern long hxlcl_mmap(void *addr, unsigned long len, int prot, int flags, int fd, long off);
/* batch D — divergence syscalls: open_sys (arm64 → openat(AT_FDCWD,…)) +
 * getrusage (plain uniform 2-arg, out-ptr usage*). */
extern int  hxlcl_open_sys(const char *path, int flags, int mode); /* arm64 → openat(AT_FDCWD,…) */
extern int  hxlcl_getrusage(int who, void *usage);
/* batch E — pipe: out-ptr int[2] (Linux pipe2, flags=0). Kernel writes both fds. */
extern int  hxlcl_pipe(int fds[2]);
/* batch G — strtoll: pure-compute parse with a NULL-gated `char** endptr` out-param.
 * Exercised here too so the __hx_ptr_store64 endptr write gets x86_64 coverage
 * (the store64 reg allocation differs per backend). Not errno-bearing. */
extern long long hxlcl_strtoll(const char *nptr, char **endptr, int base);
/* batch H — time / poll. time: register-clean on x86_64 (time(201) returns the
 * epoch in the result reg) with a NULL-gated `int* t` out-param. poll: plain 3-arg
 * poll(7) on x86_64 (errno-bearing). */
extern int  hxlcl_time(int *t);
extern int  hxlcl_poll(void *fds, unsigned int nfds, int timeout);
/* batch I — clock_gettime / execve. clock_gettime: out-ptr timespec (getrusage
 * shape), uniform 2-arg, NR x86_64=228 (arm64=113); errno-bearing (bad clk → EINVAL).
 * execve: plain 3-arg, NR x86_64=59 (arm64=221); returns only on failure (bad path →
 * -1 + ENOENT, errno-store value-exact). */
extern int  hxlcl_clock_gettime(int clk, void *ts);
extern int  hxlcl_execve(const char *path, char *const argv[], char *const envp[]);
/* batch J — fork: 0-arg process clone. Single result reg: child pid to parent / 0
 * to child, uniform -errno on failure. NR x86_64=57 (__NR_fork); arm64 has no plain
 * fork → __NR_clone=220 with flags=SIGCHLD=17 (every clone arg past flags is 0 so
 * the CONFIG_CLONE_BACKWARDS order is moot). Live fork+_exit+waitpid roundtrip. */
extern int  hxlcl_fork(void);
/* Wall 2-b ENV — getenv: the FIRST Route C body to reference an extern DATA symbol.
 * It resolves the libc `environ` global through the GOT (new __hx_environ_ptr
 * intrinsic → x86_64 `mov rax,[rip+environ@GOTPCREL]`, R_X86_64_(REX_)GOTPCREL) and
 * byte-walks the char** array. THIS Linux run is the named-DATA reloc's assemble +
 * link + resolve proof on x86_64 (the darwin sibling proves the @GOTPAGE form).
 * Not errno-bearing; returns a raw char* into the live environ block (or NULL).
 * `environ` comes from libc/crt — the routec.o's GOT ref resolves at link, no stub. */
extern char *hxlcl_getenv(const char *name);

/* Wall 2-b ENV (sibling) — setenv: the FIRST environ WRITE-BACK. On x86_64 the grow
 * path stores a fresh char** array back into `environ` via __hx_ptr_store64(&environ,
 * 0, newarr); the named-DATA GOT reloc for `environ` must resolve to glibc's live
 * global so libc getenv observes the new key (the writeback proof). Returns 0 / -1. */
extern int hxlcl_setenv(const char *name, const char *value, int overwrite);

/* Wall 3-a CORE FILE* family — fopen/fclose/fread/fwrite/ftell/fseek/fdopen. The
 * FILE* is the frozen-floor fake pointer `(void*)(uintptr_t)(fd+1)` (NOT a libc
 * stdio struct), composed purely over the Route C syscall leaves (open_sys/read/
 * write/lseek/close). On Linux the O_* fopen-flag values (O_CREAT 0100, O_TRUNC
 * 01000, O_APPEND 02000) differ from darwin's — this run is the linux-flag-value
 * proof. fread/fwrite return the ITEM count (got/size), looping partial transfers;
 * a full write→close→reopen→read roundtrip asserts byte-exact + position-exact. */
extern void  *hxlcl_fopen(const char *path, const char *mode);
extern int    hxlcl_fclose(void *fp);
extern size_t hxlcl_fread(void *buf, size_t sz, size_t n, void *fp);
extern size_t hxlcl_fwrite(const void *buf, size_t sz, size_t n, void *fp);
extern long   hxlcl_ftell(void *fp);
extern int    hxlcl_fseek(void *fp, long offset, int whence);
extern void  *hxlcl_fdopen(int fd, const char *mode);

/* The emit covers ALL whitelisted Route C symbols (the script emits the whole
 * hxlcl_core.hexa), so the routec.o carries the composites' undefined-external
 * inner callees `bl hxlcl_atoll` / `bl hxlcl_malloc`. This Linux harness only
 * EXERCISES hxlcl_close, but the link still needs those leaves resolved — supply
 * them here (sole provider, no shim → no multidef), mirroring the darwin harness.
 * hxlcl_malloc writes the same 16-byte size header the floor does (so a realloc
 * neg-offset header read would be meaningful), keeping the returned ptr aligned. */
#define HXLCL_HDR 16
long long hxlcl_atoll(const char *s) { return s ? atoll(s) : 0; }
void     *hxlcl_malloc(size_t n) {
    size_t want = n ? n : 1;
    unsigned char *base = (unsigned char *)malloc(want + HXLCL_HDR);
    if (!base) return 0;
    *(size_t *)base = want;
    return base + HXLCL_HDR;
}

static int fails = 0;
#define CK(cond, msg) do { if (!(cond)) { printf("  FAIL: %s\n", msg); fails++; } } while (0)

int main(void) {
    int fd = open("/dev/null", O_RDONLY);
    CK(fd >= 0, "open /dev/null");

    /* valid close → 0 (errno untouched) */
    errno = 0;
    CK(hxlcl_close(fd) == 0, "close(valid fd) == 0");

    /* closing the now-closed fd → -1, and errno SET to EBADF (the substrate's
     * core claim: the errno-store leg ran *errno_location() = -(-EBADF) = EBADF). */
    errno = 0;
    int r = hxlcl_close(fd);
    CK(r == -1, "close(already-closed fd) == -1");
    CK(errno == EBADF, "close(already-closed fd) sets errno == EBADF (value-exact)");

    /* a clearly-invalid fd → -1 + EBADF as well */
    errno = 0;
    CK(hxlcl_close(999999) == -1, "close(999999) == -1");
    CK(errno == EBADF, "close(999999) sets errno == EBADF (value-exact)");

    /* read on a bad fd → -1, errno == EBADF (errno-store value-exact). */
    errno = 0;
    CK(hxlcl_read(999999, (char[8]){0}, 8) == -1, "read(bad fd) == -1");
    CK(errno == EBADF, "read(bad fd) sets errno == EBADF (value-exact)");

    /* lseek on a bad fd → -1, errno == EBADF. (Also confirms the 3-arg trap +
     * negative-return → errno-store path for a non-close errno-bearing syscall.) */
    errno = 0;
    CK(hxlcl_lseek(999999, 0, SEEK_SET) == -1, "lseek(bad fd) == -1");
    CK(errno == EBADF, "lseek(bad fd) sets errno == EBADF (value-exact)");

    /* read success path: read /dev/zero into a buffer → returns the byte count. */
    int zfd = open("/dev/zero", O_RDONLY);
    char zb[4] = {1, 1, 1, 1};
    CK(zfd >= 0 && hxlcl_read(zfd, zb, 4) == 4, "read(/dev/zero, 4) == 4 (success)");
    if (zfd >= 0) hxlcl_close(zfd);

    /* dup2 — arm64 dup3(old,new,0) / x86_64 dup2. bad-fd → -1 + EBADF (errno-store
     * value-exact); success: dup2(valid, target) returns the target fd. */
    errno = 0;
    CK(hxlcl_dup2(999999, 30) == -1, "dup2(bad fd) == -1");
    CK(errno == EBADF, "dup2(bad fd) sets errno == EBADF (value-exact)");
    int dvfd = open("/dev/null", O_RDONLY);
    CK(dvfd >= 0 && hxlcl_dup2(dvfd, 30) == 30, "dup2(valid, 30) == 30 (success)");
    if (dvfd >= 0) { hxlcl_close(30); hxlcl_close(dvfd); }

    /* mkdir — arm64 mkdirat(AT_FDCWD,path,mode) / x86_64 mkdir. mkdir of an EXISTING
     * dir → -1 + EEXIST (the per-arch arg-shape errno path; AT_FDCWD prepend on
     * arm64 must land path/mode in the right slots or this would mis-route). */
    errno = 0;
    CK(hxlcl_mkdir("/", 0755) == -1, "mkdir(existing /) == -1");
    CK(errno == EEXIST, "mkdir(existing /) sets errno == EEXIST (value-exact)");
    /* mkdir success: a fresh temp dir → 0. */
    char md[] = "/tmp/routec_lmkdir_XXXXXX";
    if (mkdtemp(md) != NULL) {
        rmdir(md);
        errno = 0;
        CK(hxlcl_mkdir(md, 0755) == 0, "mkdir(fresh dir) == 0 (success, AT_FDCWD path slot)");
        rmdir(md);
    }

    /* stat — arm64 fstatat(AT_FDCWD,path,buf,0) / x86_64 stat(path,buf). A
     * NONEXISTENT path → -1 + ENOENT (errno-store value-exact; on arm64 this also
     * proves the AT_FDCWD prepend lands path/buf in the right slots — a botched
     * arg shape would fault or mis-route rather than return ENOENT). Then a stat
     * of "/" → 0 (success path; the root always exists). */
    char sbuf[256];
    errno = 0;
    CK(hxlcl_stat("/nonexistent_xyz", sbuf) == -1, "stat(nonexistent) == -1");
    CK(errno == ENOENT, "stat(nonexistent) sets errno == ENOENT (value-exact)");
    errno = 0;
    CK(hxlcl_stat("/", sbuf) == 0, "stat(\"/\") == 0 (success)");

    /* waitpid — wait4(pid,status,opts,rusage=NULL), uniform 4-arg on every target.
     * With NO child process, waitpid(-1, …, 0) → -1 + ECHILD (errno-store
     * value-exact; confirms the 4-arg trap + negative-return → errno-store path). */
    int wst = 0;
    errno = 0;
    CK(hxlcl_waitpid(-1, &wst, 0) == -1, "waitpid(no child) == -1");
    CK(errno == ECHILD, "waitpid(no child) sets errno == ECHILD (value-exact)");

    /* batch C — write / fcntl / mmap. ────────────────────────────────────────
     * write — the read mirror. bad-fd → -1 + EBADF (errno-store value-exact);
     * success: write to /dev/null returns the byte count. */
    errno = 0;
    CK(hxlcl_write(999999, "x", 1) == -1, "write(bad fd) == -1");
    CK(errno == EBADF, "write(bad fd) sets errno == EBADF (value-exact)");
    int wfd = open("/dev/null", O_WRONLY);
    CK(wfd >= 0 && hxlcl_write(wfd, "abcd", 4) == 4, "write(/dev/null, 4) == 4 (success)");
    if (wfd >= 0) hxlcl_close(wfd);

    /* fcntl — plain 3-arg. bad-fd F_GETFL → -1 + EBADF (errno value-exact);
     * success: fcntl(valid, F_GETFL) returns the fd flags (>= 0). */
    errno = 0;
    CK(hxlcl_fcntl(999999, F_GETFL, 0) == -1, "fcntl(bad fd, F_GETFL) == -1");
    CK(errno == EBADF, "fcntl(bad fd) sets errno == EBADF (value-exact)");
    int ffd = open("/dev/null", O_RDONLY);
    CK(ffd >= 0 && hxlcl_fcntl(ffd, F_GETFL, 0) >= 0, "fcntl(valid, F_GETFL) >= 0 (success)");
    if (ffd >= 0) hxlcl_close(ffd);

    /* mmap — the ROOT-CAUSE assert. The error request uses length == 0, the
     * man-page-verbatim, fd-INDEPENDENT EINVAL trigger (mmap(2): "EINVAL ...
     * length was 0"). The earlier MAP_PRIVATE|MAP_SHARED combo was a HARNESS
     * BUG: it also passed fd=-1 WITHOUT MAP_ANONYMOUS, so the kernel hit the
     * EBADF fd-check ("fd is not a valid file descriptor (and MAP_ANONYMOUS was
     * not set)") and returned EBADF, NOT EINVAL — the substrate was correct, the
     * assert expected the wrong errno. length==0 is unconditional EINVAL with no
     * fd dependency, so it isolates the errno-store value-exactness cleanly.
     *
     * This assert proves the 6-arg arg-passing AND the errno store: the raw
     * syscall returns -EINVAL, our body's `__hx_payload_lt(r,0)` sees it negative
     * → stores -r (=EINVAL) into *errno and returns -1. (long)MAP_FAILED == -1,
     * so the C caller reading the return as a pointer sees MAP_FAILED. The valid
     * anon-page assert below independently confirms args 4/5/6 (flags/fd/off)
     * reach the kernel — a botched 6-arg lowering would fail the anon mmap. */
    long pg = sysconf(_SC_PAGESIZE);
    if (pg <= 0) pg = 4096;
    errno = 0;
    long bad = hxlcl_mmap(0, 0 /* length==0 → EINVAL */, PROT_READ,
                          MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    /* diagnostic (captured in the CI log regardless of pass/fail): the exact
     * return word + errno, so any future arg-passing regression is legible. */
    printf("  [diag] mmap(len=0) → ret=%ld errno=%d (%s)\n", bad, errno, strerror(errno));
    CK(bad == -1, "mmap(len=0) == -1 (raw -errno → -1, == (long)MAP_FAILED)");
    CK(errno == EINVAL, "mmap(len=0) sets errno == EINVAL (value-exact)");
    errno = 0;
    long ok = hxlcl_mmap(0, (unsigned long)pg, PROT_READ | PROT_WRITE,
                         MAP_ANONYMOUS | MAP_PRIVATE, -1, 0);
    CK(ok != -1 && ok != (long)MAP_FAILED && ok != 0,
       "mmap(anon page) → valid address (raw address, not MAP_FAILED) (success)");
    if (ok != -1 && ok != (long)MAP_FAILED && ok != 0) {
        ((char *)ok)[0] = 'q';                  /* page is writable */
        CK(((char *)ok)[0] == 'q', "mmap'd page writable (success)");
        munmap((void *)ok, (size_t)pg);
    }

    /* batch D — open_sys / getrusage. ─────────────────────────────────────────
     * open_sys — arm64 openat(AT_FDCWD,path,flags,mode) / x86_64 open(path,flags,
     * mode). A NONEXISTENT path with O_RDONLY → -1 + ENOENT (errno-store value-
     * exact; on arm64 this proves the AT_FDCWD prepend lands path/flags/mode in
     * the right slots — a botched arg shape would fault or mis-route). Then a
     * successful open of /dev/null → a valid fd (>= 0). */
    errno = 0;
    CK(hxlcl_open_sys("/nonexistent_xyz_open", O_RDONLY, 0) == -1, "open_sys(nonexistent) == -1");
    CK(errno == ENOENT, "open_sys(nonexistent) sets errno == ENOENT (value-exact)");
    errno = 0;
    int ofd = hxlcl_open_sys("/dev/null", O_RDONLY, 0);
    CK(ofd >= 0, "open_sys(/dev/null, O_RDONLY) >= 0 (success, AT_FDCWD path slot)");
    if (ofd >= 0) hxlcl_close(ofd);

    /* getrusage — plain uniform 2-arg (who, usage*). A successful RUSAGE_SELF
     * fills the out-ptr and returns 0; the success path confirms the out-ptr
     * (usage*) reaches the kernel and the return value is 0. An invalid `who`
     * (a bogus large value) → -1 + EINVAL (errno-store value-exact). */
    struct rusage ru;
    errno = 0;
    CK(hxlcl_getrusage(RUSAGE_SELF, &ru) == 0, "getrusage(RUSAGE_SELF) == 0 (success, out-ptr)");
    errno = 0;
    CK(hxlcl_getrusage(424242, &ru) == -1, "getrusage(invalid who) == -1");
    CK(errno == EINVAL, "getrusage(invalid who) sets errno == EINVAL (value-exact)");

    /* batch E — pipe: out-ptr int[2] (Linux pipe2, flags=0). The kernel WRITES
     * both fds into the caller's buffer and returns 0 — proving pipe is an
     * out-ptr (getrusage/stat shape), NOT a 2nd-return-register on Linux (that
     * is darwin-only). A write→read roundtrip through the pair confirms the
     * out-ptr reached the kernel and both fds are valid + usable. */
    int pfd[2] = { -1, -1 };
    errno = 0;
    CK(hxlcl_pipe(pfd) == 0, "pipe() == 0 (success, out-ptr writes both fds)");
    CK(pfd[0] >= 0 && pfd[1] >= 0, "pipe() fills fds[0],fds[1] (out-ptr, value-exact)");
    if (pfd[0] >= 0 && pfd[1] >= 0) {
        char wb = 'Z', rb = 0;
        CK(write(pfd[1], &wb, 1) == 1, "pipe write end usable");
        CK(read(pfd[0], &rb, 1) == 1 && rb == 'Z', "pipe read end roundtrip == 'Z'");
        hxlcl_close(pfd[0]);
        hxlcl_close(pfd[1]);
    }

    /* batch G — strtoll: x86_64 coverage of the value parse + endptr store64
     * out-param write (not errno-bearing — pure compute). */
    {
        CK(hxlcl_strtoll("42", NULL, 10) == 42, "strtoll(\"42\",NULL,10) == 42 (endptr NULL-gate)");
        CK(hxlcl_strtoll("-7", NULL, 10) == -7, "strtoll(\"-7\",NULL,10) == -7 (sign)");
        CK(hxlcl_strtoll("ff", NULL, 16) == 255, "strtoll(\"ff\",16) == 255 (lowercase hex)");
        CK(hxlcl_strtoll("0755", NULL, 0) == 493, "strtoll(\"0755\",0) == 493 (octal auto)");
        const char *hx = "0xFF";
        char *endp = NULL;
        CK(hxlcl_strtoll(hx, &endp, 16) == 255, "strtoll(\"0xFF\",&end,16) == 255 (0x skip)");
        CK(endp == hx + 4, "strtoll endptr == nptr+4 (store64 out-param write, x86_64)");
        const char *mix = "12x";
        char *endp2 = NULL;
        CK(hxlcl_strtoll(mix, &endp2, 10) == 12, "strtoll(\"12x\",&end,10) == 12");
        CK(endp2 == mix + 2, "strtoll endptr stops at first non-digit (mix+2)");
    }

    /* batch H — time / poll. ──────────────────────────────────────────────────
     * time: x86_64 uses the register-clean time(201) syscall (no buffer) — the
     * epoch returns in the result reg; assert it is post-2023 AND within ±2s of
     * libc time(NULL), plus the NULL-gated out-param write (*t == return). poll:
     * x86_64 uses the plain 3-arg poll(7); assert poll(no fds, 0ms) == 0 and a
     * real pollfd on a pipe (empty → 0, data-ready → 1). */
    {
        long ref = (long)time(NULL);
        int t1 = hxlcl_time(NULL);
        CK(t1 > 1700000000, "time(NULL) > 2023-11 epoch (register-clean x86_64 time)");
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

    /* batch I — clock_gettime / execve. ───────────────────────────────────────
     * clock_gettime: uniform 2-arg out-ptr (timespec*); CLOCK_REALTIME → 0 + the
     * kernel writes tv_sec/tv_nsec (assert post-2023 epoch + valid sub-second). A
     * bogus clk_id → -1 + EINVAL (errno-store value-exact). execve: plain 3-arg; a
     * NONEXISTENT path → -1 + ENOENT (the errno-store value-exact claim; success
     * would replace the process so only the failure path is observable). */
    {
        struct timespec ts;
        ts.tv_sec = 0; ts.tv_nsec = -1;
        errno = 0;
        CK(hxlcl_clock_gettime(CLOCK_REALTIME, &ts) == 0, "clock_gettime(CLOCK_REALTIME) == 0 (success, out-ptr)");
        CK(ts.tv_sec > 1700000000, "clock_gettime tv_sec > 2023-11 epoch (out-ptr written)");
        CK(ts.tv_nsec >= 0 && ts.tv_nsec < 1000000000, "clock_gettime tv_nsec in [0,1e9)");
        errno = 0;
        CK(hxlcl_clock_gettime(424242, &ts) == -1, "clock_gettime(invalid clk) == -1");
        CK(errno == EINVAL, "clock_gettime(invalid clk) sets errno == EINVAL (value-exact)");

        char *eargv[] = { (char *)"x", NULL };
        char *eenvp[] = { NULL };
        errno = 0;
        CK(hxlcl_execve("/nonexistent_xyz_exec_zzz", eargv, eenvp) == -1, "execve(nonexistent) == -1");
        CK(errno == ENOENT, "execve(nonexistent) sets errno == ENOENT (value-exact)");
    }

    /* batch J — fork. The LAST clean syscall-family leaf: a LIVE fork+_exit+waitpid
     * roundtrip (vs the composition tests above). fork() returns the child pid (>0)
     * to the parent and 0 to the child in a single result register (x86_64
     * __NR_fork=57; arm64 __NR_clone=220 flags=SIGCHLD=17 — every clone arg past
     * flags is 0 so the CONFIG_CLONE_BACKWARDS order is moot). The child branch is
     * taken FIRST and _exit(0)s immediately — it must NEVER re-enter the harness/CK
     * (a separate process: its `fails` is its own copy and it exits before any
     * summary). The parent then waitpid()s the EXACT child pid and asserts a clean
     * exit, proving fork produced a real live child and the single-reg pid split is
     * correct. A fork failure (-1) skips the child branch and trips fork()>0. */
    {
        int cpid = hxlcl_fork();
        if (cpid == 0) {
            _exit(0);   /* child: exit cleanly, never touch harness state */
        }
        CK(cpid > 0, "fork() > 0 in parent (single-reg child pid; child got 0)");
        if (cpid > 0) {
            int wst = 0;
            int got = (int)waitpid((pid_t)cpid, &wst, 0);
            CK(got == cpid, "waitpid reaps the exact child pid (live fork)");
            CK(WIFEXITED(wst) && WEXITSTATUS(wst) == 0, "child _exit(0) reaped clean (fork roundtrip)");
        }
    }

    /* Wall 2-b — getenv via the __hx_environ_ptr named-data GOT intrinsic + byte-walk.
     * This is the x86_64 R_X86_64_GOTPCREL-on-`environ` proof: a clean link means the
     * named-data reloc assembled and the linker bound it to libc's environ. Value-exact
     * vs libc getenv() AND content-exact for a set var; absent key → NULL; a prefix of a
     * real key → NULL (break-free early-stop must not match a longer entry nor over-read
     * a shorter one). The returned pointer is INTO the same live environ block libc walks
     * → pointer identity holds (a wrong GOT deref depth or ABI leak would crash here). */
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
    }

    /* Wall 2-b (sibling) — setenv WRITE-BACK, x86_64 named-DATA GOT store proof.
     * POSIX setenv(3): GROW (fresh key reaches the live glibc global — both hxlcl_getenv
     * AND libc getenv see it), in-place slot REPLACE (overwrite!=0), NO-OP preserve
     * (overwrite==0), repeated GROW keeping the first key, EINVAL (-1) for NULL/empty.
     * All libc setenv calls above ran FIRST, so glibc never re-manages our fresh array. */
    {
        CK(hxlcl_setenv("HX_RC_NEW", "v1", 1) == 0, "setenv(fresh key) → 0");
        char *g1 = hxlcl_getenv("HX_RC_NEW");
        CK(g1 != NULL && strcmp(g1, "v1") == 0, "setenv(fresh): hxlcl_getenv == \"v1\"");
        char *l1 = getenv("HX_RC_NEW");
        CK(l1 != NULL && strcmp(l1, "v1") == 0, "setenv(fresh): libc getenv == \"v1\" (writeback reached &environ)");
        CK(hxlcl_setenv("HX_RC_NEW", "v2", 1) == 0, "setenv(overwrite=1) → 0");
        char *g2 = hxlcl_getenv("HX_RC_NEW");
        CK(g2 != NULL && strcmp(g2, "v2") == 0, "setenv(overwrite): value replaced → \"v2\"");
        CK(hxlcl_setenv("HX_RC_NEW", "v3", 0) == 0, "setenv(overwrite=0, exists) → 0");
        char *g3 = hxlcl_getenv("HX_RC_NEW");
        CK(g3 != NULL && strcmp(g3, "v2") == 0, "setenv(overwrite=0): value preserved → \"v2\"");
        CK(hxlcl_setenv("HX_RC_NEW2", "w1", 1) == 0, "setenv(second fresh key) → 0");
        char *g4 = hxlcl_getenv("HX_RC_NEW2");
        CK(g4 != NULL && strcmp(g4, "w1") == 0, "setenv(regrow): new key == \"w1\"");
        char *g5 = hxlcl_getenv("HX_RC_NEW");
        CK(g5 != NULL && strcmp(g5, "v2") == 0, "setenv(regrow): prior key survives == \"v2\"");
        CK(hxlcl_setenv(NULL, "x", 1) == -1, "setenv(NULL name) → -1 (EINVAL)");
        CK(hxlcl_setenv("", "x", 1) == -1, "setenv(empty name) → -1 (EINVAL)");
    }

    /* Wall 3-a — CORE FILE* family roundtrip (linux O_* flag values). fopen("w") →
     * fwrite known bytes → fclose → fopen("r") → fread → byte-exact + ftell/fseek
     * position-exact. The "w"/"r" mode strings map to the LINUX O_WRONLY|O_CREAT|
     * O_TRUNC / O_RDONLY flag values inside hxlcl_fopen (the per-target const leg),
     * so a wrong Linux flag value would fail to create/truncate here. */
    {
        char tmpl[] = "/tmp/routec_lfile_XXXXXX";
        int tfd = mkstemp(tmpl);
        CK(tfd >= 0, "mkstemp for FILE* roundtrip");
        if (tfd >= 0) close(tfd);   /* close; reopen through hxlcl_fopen */

        const char payload[] = "RouteC-FILE-roundtrip-0123456789";  /* 32 bytes */
        size_t plen = sizeof(payload) - 1;

        void *fw = hxlcl_fopen(tmpl, "w");
        CK(fw != NULL, "fopen(w) != NULL (fd+1 fake FILE*, linux O_WRONLY|O_CREAT|O_TRUNC)");
        CK(hxlcl_fwrite(payload, 1, plen, fw) == plen, "fwrite(size=1) item count == 32");
        CK(hxlcl_fclose(fw) == 0, "fclose(w) == 0");

        void *fr = hxlcl_fopen(tmpl, "r");
        CK(fr != NULL, "fopen(r) != NULL (linux O_RDONLY)");
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

        /* "a" append mode: O_WRONLY|O_CREAT|O_APPEND (linux 02000). Appending must
         * land at EOF, growing the file from 32 to 36 bytes. */
        void *fa = hxlcl_fopen(tmpl, "a");
        CK(fa != NULL, "fopen(a) != NULL (linux O_APPEND)");
        CK(hxlcl_fwrite("TAIL", 1, 4, fa) == 4, "fwrite append 4 bytes");
        CK(hxlcl_fclose(fa) == 0, "fclose(a) == 0");
        void *fr2 = hxlcl_fopen(tmpl, "r");
        CK(fr2 != NULL, "fopen(r) after append != NULL");
        CK(hxlcl_fseek(fr2, 0, SEEK_END) == 0, "fseek(END,0) == 0");
        CK(hxlcl_ftell(fr2) == (long)(plen + 4), "file grew to 36 bytes after append (O_APPEND at EOF)");
        hxlcl_fclose(fr2);

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

    if (fails == 0) { printf("[routec-smoke-linux] all Route C errno asserts PASS\n"); return 0; }
    printf("[routec-smoke-linux] %d assert(s) FAILED\n", fails);
    return 1;
}
CEOF

echo "[routec-smoke-linux] (3) compile harness + link Route C .o + run …"
"$CC" -c "$TMP/harness.c" -o "$TMP/harness.o"
"$CC" "$TMP/harness.o" "$TMP/routec.o" -o "$TMP/routec_smoke_linux"
"$TMP/routec_smoke_linux"
