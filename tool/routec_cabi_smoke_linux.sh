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
for s in close read lseek dup2 mkdir; do
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
#include <unistd.h>

/* Route-C-emitted symbols under test (raw C-ABI prototypes). */
extern int  hxlcl_close(int fd);
extern long hxlcl_read(int fd, void *buf, unsigned long n);
extern long hxlcl_lseek(int fd, long off, int whence);
extern int  hxlcl_dup2(int oldfd, int newfd);   /* arm64 → dup3(old,new,0) */
extern int  hxlcl_mkdir(const char *path, int mode); /* arm64 → mkdirat(AT_FDCWD,…) */

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

    if (fails == 0) { printf("[routec-smoke-linux] all Route C errno asserts PASS\n"); return 0; }
    printf("[routec-smoke-linux] %d assert(s) FAILED\n", fails);
    return 1;
}
CEOF

echo "[routec-smoke-linux] (3) compile harness + link Route C .o + run …"
"$CC" -c "$TMP/harness.c" -o "$TMP/harness.o"
"$CC" "$TMP/harness.o" "$TMP/routec.o" -o "$TMP/routec_smoke_linux"
"$TMP/routec_smoke_linux"
