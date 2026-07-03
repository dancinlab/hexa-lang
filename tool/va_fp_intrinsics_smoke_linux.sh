#!/usr/bin/env bash
# tool/va_fp_intrinsics_smoke_linux.sh — RFC061 §M8 varargs-ABI (literal-∅ feature B)
# r1 SSE-class ON-PATH smoke (LINUX x86_64).
#
# WHAT THIS PROVES
# ─────────────────────────────────────────────────────────────────────
# A self-emitted SysV AMD64 VARIADIC function that consumes DOUBLE (SSE-class) varargs
# — compiled natively by the hexa codegen (NO frozen runtime.c va_list) under
# HEXA_VA_INTRINSICS=1 — walks its unnamed double arguments value-EXACTLY through BOTH
# the PSABI SSE register path (fp_offset <= 175 → reg_save_area FP half, 16-byte
# stride) and the overflow/stack path (fp_offset > 175 → overflow_arg_area, 8-byte
# stride). Reference-match: GCC 13.3.0 `-O0 -S` of `double f(int n, ...)`
# `va_arg(ap, double)` (the `movaps %xmm0..7` reg-save block + the
# `cmpl $175 / ja / reg_save_area+fp_offset / fp_offset+=16` SSE va_arg sequence) +
# System V AMD64 PSABI §3.5.7 "Variable Argument Lists" fig 3.34.
#
# It emits stdlib/runtime/hxlcl_va_fp_smoke.hexa with `HEXA_VA_INTRINSICS=1
# --target=x86_64-linux`, links the emitted .o against a C harness that calls
# `double hxlcl_va_fp_smoke(long n, ...)`, and asserts the returned sums (EXACT f64
# vs a C oracle). The named INT param `n` is integer-class (consumes a GP slot, NOT an
# XMM slot) so a botched GP/SSE counter separation or fp_offset init would be caught.
# The >8-double cases straddle the XMM-reg → stack boundary.
#
# linux-x86_64 ONLY: aprime_cc's build_aprime.sh graduated path. Loud no-op elsewhere.
#
#   tool/va_fp_intrinsics_smoke_linux.sh
#
set -euo pipefail

HX="${HX_ROOT:-$(cd "$(dirname "$0")/.."; pwd)}"
CC="${CC:-cc}"

if [ "$(uname -s)" != "Linux" ] || [ "$(uname -m)" != "x86_64" ]; then
    echo "[va-fp-smoke-linux] SKIP — r1 SSE va smoke runs on linux-x86_64 only (host=$(uname -sm))"
    exit 0
fi

APRIME="${APRIME:-$HX/build/aprime_cc}"
if [ ! -x "$APRIME" ]; then
    echo "[va-fp-smoke-linux] building aprime_cc (tool/build_aprime.sh) …"
    bash "$HX/tool/build_aprime.sh" -o "$APRIME"
fi
[ -x "$APRIME" ] || { echo "[va-fp-smoke-linux] FATAL: aprime_cc not at $APRIME" >&2; exit 1; }

SRC="$HX/stdlib/runtime/hxlcl_va_fp_smoke.hexa"
[ -f "$SRC" ] || { echo "[va-fp-smoke-linux] FATAL: missing $SRC" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
printf 'fn _drv_unused() {}\n' > "$TMP/_drv.hexa"

# ── (1) emit the variadic FP body with the va intrinsics ENABLED ────────────
echo "[va-fp-smoke-linux] (1) emit hxlcl_va_fp_smoke.hexa with HEXA_VA_INTRINSICS=1 --target=x86_64-linux …"
HEXA_VA_INTRINSICS=1 HEXA_INLINE_INT_BOX=1 HEXA_INLINE_BOOL_BOX=1 \
    "$APRIME" "$TMP/_drv.hexa" --emit=asm \
    --target=x86_64-linux-gnu -o "$TMP/vafp.s" "$SRC"
[ -s "$TMP/vafp.s" ] || { echo "[va-fp-smoke-linux] FATAL: empty vafp.s" >&2; exit 1; }
"$CC" -c "$TMP/vafp.s" -o "$TMP/vafp.o"
[ -s "$TMP/vafp.o" ] || { echo "[va-fp-smoke-linux] FATAL: empty vafp.o" >&2; exit 1; }

# ── (2) assert hxlcl_va_fp_smoke is a DEFINED external text symbol ───────────
echo "[va-fp-smoke-linux] (2) assert hxlcl_va_fp_smoke defined (T) in vafp.o …"
if ! nm "$TMP/vafp.o" 2>/dev/null | grep -qE " T hxlcl_va_fp_smoke\$"; then
    echo "[va-fp-smoke-linux] FATAL: hxlcl_va_fp_smoke not emitted as defined text" >&2
    nm "$TMP/vafp.o" 2>/dev/null | grep -i va || true
    exit 1
fi

# ── (3) C harness: value-exact variadic-double-sum contract ─────────────────
cat > "$TMP/harness.c" <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Route-C-emitted variadic symbol under test (raw C-ABI prototype). The body reads
 * each vararg as an SSE-class double (PSABI §3.5.7), so we pass doubles. */
extern double hxlcl_va_fp_smoke(long n, ...);

static int fails = 0;
/* EXACT f64 compare via bit pattern — these sums are all exactly representable
 * (small integers / clean fractions) so no epsilon fuzz is needed. */
static void check(const char *name, double got, double want) {
    unsigned long long gb, wb;
    memcpy(&gb, &got, 8); memcpy(&wb, &want, 8);
    if (gb != wb) {
        fprintf(stderr, "[va-fp-smoke-linux] FAIL %s: got %.17g want %.17g\n", name, got, want);
        fails++;
    } else {
        fprintf(stderr, "[va-fp-smoke-linux]   ok  %s = %.17g\n", name, got);
    }
}

int main(void) {
    /* 0 varargs → 0.0 (loop never enters). */
    check("n0", hxlcl_va_fp_smoke(0L), 0.0);
    /* 1 double — first XMM slot (xmm0, fp_offset 48). */
    check("n1", hxlcl_va_fp_smoke(1L, 1.5), 1.5);
    /* 4 doubles — XMM register slots (xmm0..xmm3, fp_offset 48..96). */
    check("n4", hxlcl_va_fp_smoke(4L, 1.0, 2.0, 3.0, 4.0), 10.0);
    /* 8 doubles — ALL XMM register slots (xmm0..xmm7, fp_offset 48..160). */
    check("n8", hxlcl_va_fp_smoke(8L, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5), 4.0);
    /* 9 doubles — 8 register + 1 OVERFLOW (stack) → exercises fp_offset>175 path. */
    check("n9", hxlcl_va_fp_smoke(9L, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0), 45.0);
    /* 12 doubles — 8 register + 4 overflow (deeper stack walk). */
    check("n12", hxlcl_va_fp_smoke(12L,
            1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0), 78.0);
    /* negative + fractional values — confirm full 8-byte IEEE-754 loads. */
    check("nneg", hxlcl_va_fp_smoke(3L, -100.25, 1000.5, -0.25), 900.0);

    if (fails) { fprintf(stderr, "[va-fp-smoke-linux] %d FAILURE(s)\n", fails); return 1; }
    fprintf(stderr, "[va-fp-smoke-linux] PASS — variadic double reg+overflow value-exact\n");
    return 0;
}
CEOF

echo "[va-fp-smoke-linux] (3) compile harness + link vafp .o + run …"
"$CC" -c "$TMP/harness.c" -o "$TMP/harness.o"
"$CC" "$TMP/harness.o" "$TMP/vafp.o" -o "$TMP/va_fp_smoke_linux" -lm
"$TMP/va_fp_smoke_linux"
echo "[va-fp-smoke-linux] DONE"
