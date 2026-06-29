#!/usr/bin/env bash
# tool/va_intrinsics_smoke_linux.sh — RFC061 §M8 varargs-ABI (literal-∅ feature B)
# RUNG1 ON-PATH smoke (LINUX x86_64).
#
# WHAT THIS PROVES
# ─────────────────────────────────────────────────────────────────────
# A self-emitted SysV AMD64 VARIADIC integer function — compiled natively by the
# hexa codegen (NO frozen runtime.c va_list) under HEXA_VA_INTRINSICS=1 — walks its
# unnamed integer arguments value-EXACTLY through BOTH the PSABI register path
# (gp_offset < 48 → reg_save_area) and the overflow/stack path (gp_offset >= 48 →
# overflow_arg_area). Reference-match: GCC 13.3.0 `-O0 -S` of `int f(int n, ...)`
# (the reg-save block + the cmp $47/ja va_arg sequence) + System V AMD64 PSABI
# §3.5.7 "Variable Argument Lists" fig 3.34.
#
# It emits stdlib/runtime/hxlcl_va_smoke.hexa with `HEXA_VA_INTRINSICS=1
# --target=x86_64-linux`, links the emitted .o against a C harness that calls
# `long hxlcl_va_smoke(long n, ...)`, and asserts the returned sums. A botched
# gp_offset init, a missing prologue spill, or a wrong overflow bump would all be
# caught by the >5-vararg cases (which straddle the reg→stack boundary).
#
# linux-x86_64 ONLY: aprime_cc's build_aprime.sh graduated path. Loud no-op elsewhere.
#
#   tool/va_intrinsics_smoke_linux.sh
#
set -euo pipefail

HX="${HX_ROOT:-$(cd "$(dirname "$0")/.."; pwd)}"
CC="${CC:-cc}"

if [ "$(uname -s)" != "Linux" ] || [ "$(uname -m)" != "x86_64" ]; then
    echo "[va-smoke-linux] SKIP — RUNG1 va smoke runs on linux-x86_64 only (host=$(uname -sm))"
    exit 0
fi

APRIME="${APRIME:-$HX/build/aprime_cc}"
if [ ! -x "$APRIME" ]; then
    echo "[va-smoke-linux] building aprime_cc (tool/build_aprime.sh) …"
    bash "$HX/tool/build_aprime.sh" -o "$APRIME"
fi
[ -x "$APRIME" ] || { echo "[va-smoke-linux] FATAL: aprime_cc not at $APRIME" >&2; exit 1; }

SRC="$HX/stdlib/runtime/hxlcl_va_smoke.hexa"
[ -f "$SRC" ] || { echo "[va-smoke-linux] FATAL: missing $SRC" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
printf 'fn _drv_unused() {}\n' > "$TMP/_drv.hexa"

# ── (1) emit the variadic body with the va intrinsics ENABLED ───────────────
echo "[va-smoke-linux] (1) emit hxlcl_va_smoke.hexa with HEXA_VA_INTRINSICS=1 --target=x86_64-linux …"
HEXA_VA_INTRINSICS=1 HEXA_INLINE_INT_BOX=1 HEXA_INLINE_BOOL_BOX=1 \
    "$APRIME" "$TMP/_drv.hexa" --emit=asm \
    --target=x86_64-linux-gnu -o "$TMP/va.s" "$SRC"
[ -s "$TMP/va.s" ] || { echo "[va-smoke-linux] FATAL: empty va.s" >&2; exit 1; }
"$CC" -c "$TMP/va.s" -o "$TMP/va.o"
[ -s "$TMP/va.o" ] || { echo "[va-smoke-linux] FATAL: empty va.o" >&2; exit 1; }

# ── (2) assert hxlcl_va_smoke is a DEFINED external text symbol ──────────────
echo "[va-smoke-linux] (2) assert hxlcl_va_smoke defined (T) in va.o …"
if ! nm "$TMP/va.o" 2>/dev/null | grep -qE " T hxlcl_va_smoke\$"; then
    echo "[va-smoke-linux] FATAL: hxlcl_va_smoke not emitted as defined text" >&2
    nm "$TMP/va.o" 2>/dev/null | grep -i va || true
    exit 1
fi

# ── (3) C harness: value-exact variadic-sum contract ────────────────────────
cat > "$TMP/harness.c" <<'CEOF'
#include <stdio.h>
#include <stdlib.h>

/* Route-C-emitted variadic symbol under test (raw C-ABI prototype). The body
 * reads each vararg as a 8-byte integer (PSABI integer class), so we pass longs. */
extern long hxlcl_va_smoke(long n, ...);

static int fails = 0;
static void check(const char *name, long got, long want) {
    if (got != want) {
        fprintf(stderr, "[va-smoke-linux] FAIL %s: got %ld want %ld\n", name, got, want);
        fails++;
    } else {
        fprintf(stderr, "[va-smoke-linux]   ok  %s = %ld\n", name, got);
    }
}

int main(void) {
    /* 0 varargs → 0 (loop never enters). */
    check("n0", hxlcl_va_smoke(0L), 0L);
    /* 1 vararg — first register slot (rsi, gp_offset 8). */
    check("n1", hxlcl_va_smoke(1L, 42L), 42L);
    /* 5 varargs — ALL register slots (rsi,rdx,rcx,r8,r9; gp_offset 8..40). */
    check("n5", hxlcl_va_smoke(5L, 10L, 20L, 30L, 40L, 50L), 150L);
    /* 7 varargs — 5 register + 2 OVERFLOW (stack) → exercises gp_offset>=48 path. */
    check("n7", hxlcl_va_smoke(7L, 1L, 2L, 3L, 4L, 5L, 6L, 7L), 28L);
    /* 10 varargs — 5 register + 5 overflow (deeper stack walk). */
    check("n10", hxlcl_va_smoke(10L, 1L, 2L, 3L, 4L, 5L, 6L, 7L, 8L, 9L, 10L), 55L);
    /* negative + large values — confirm full 8-byte signed loads. */
    check("nneg", hxlcl_va_smoke(3L, -100L, 1000000L, -7L), 999893L);

    if (fails) { fprintf(stderr, "[va-smoke-linux] %d FAILURE(s)\n", fails); return 1; }
    fprintf(stderr, "[va-smoke-linux] PASS — variadic reg+overflow value-exact\n");
    return 0;
}
CEOF

echo "[va-smoke-linux] (3) compile harness + link va .o + run …"
"$CC" -c "$TMP/harness.c" -o "$TMP/harness.o"
"$CC" "$TMP/harness.o" "$TMP/va.o" -o "$TMP/va_smoke_linux"
"$TMP/va_smoke_linux"
echo "[va-smoke-linux] DONE"
