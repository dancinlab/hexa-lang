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
# Tests the symbols CURRENTLY whitelisted on main (9 pure-arith + composite atoi).
# strdup/calloc asserts are added here when those symbols merge — the standing
# ON-path gate grows with the _is_cabi whitelist.
for s in strlen memcpy memset memcmp strcmp strncmp strcpy strncpy strcat atoi strdup; do
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

/* Inner-callee leaves the composites bl into — the retained-shim role, supplied
 * here (sole provider) so there is no multidef with the libc shim: atoll for
 * atoi, malloc for strdup. (Each composite PR adds its callee here.) */
long long hxlcl_atoll(const char *s) { return s ? atoll(s) : 0; }
void     *hxlcl_malloc(size_t n) { return malloc(n ? n : 1); }

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

    /* composites (inner bl to retained atoll / malloc) */
    CK(hxlcl_atoi("42") == 42, "atoi 42");
    CK(hxlcl_atoi("-7") == -7, "atoi -7");

    char *dup = hxlcl_strdup("hi");
    CK(dup != NULL && strcmp(dup, "hi") == 0, "strdup content");
    if (dup) free(dup);

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
echo "[routec-smoke] GREEN — Route C ON-path emit links + runs correct (11 symbols: 9 pure-arith + atoi + strdup, darwin-arm64)"
