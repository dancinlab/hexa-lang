#!/usr/bin/env bash
# tool/routec_signal_native_verify.sh — literal-∅ ING#29 wall-falsify harness for
# hxlcl_signal (signal(3) → rt_sigaction Route C native emit).
#
# Verifies the HEXA_RT_NATIVE_SIGNAL wiring — hxlcl_signal LEAVES the libc shim and
# is supplied by the hexa-NATIVE Route C .o emitted from
# stdlib/runtime/hxlcl_core.hexa (HEXA_CABI_HXLCL=1):
#   (A) DEFAULT (HEXA_RT_NATIVE_SIGNAL OFF) shim.o is BYTE-IDENTICAL to the
#       origin/main baseline shim.o (the new `#ifndef HEXA_RT_NATIVE_SIGNAL` guard
#       compiles out → the libc-delegate body is untouched; release-integrity
#       invariant — DEFAULT archive sha unchanged).
#   (B) ON: the Route C codegen emits `hxlcl_signal` as a DEFINED (T) external in
#       the native .o, AND the ON shim.o (-DHEXA_RT_NATIVE_SIGNAL) NO LONGER defines
#       it — the symbol MOVES from the C shim to the native object (literal-∅
#       progress: one shim member dropped).
#   (C) ★BEHAVIORAL MEASURE (the wall falsify attempt): link the isolated native .o
#       against a C harness that uses hxlcl_signal AS libc signal(3): install a
#       SIGUSR1 handler via hxlcl_signal(SIGUSR1, my_handler), raise(SIGUSR1), and
#       confirm the handler FIRES (vs libc signal on a control process). Also
#       capture the returned OLD handler. If the handler fires AND the old-handler
#       return matches libc semantics → wall FALSIFIED (attackable). If the test
#       crashes (SIGSEGV after handler — the x86_64 SA_RESTORER/restorer gap) OR the
#       handler never fires → wall CONFIRMED, and the FAILURE MODE is captured
#       (restorer / struct sigaction ABI / codegen emit).
#   (D) literal-∅ measure: shim hxlcl_* DEFINITION count N (default) → N-1 (ON).
#
# x86_64-linux ONLY — the Route C codegen is x86_64-backend. MEASURE-ONLY.
set -uo pipefail
ROOT="${ROOT:-$PWD}"; OUT="${OUT:-/tmp/routec_signal}"; CC="${CC:-clang}"
mkdir -p "$OUT"; cd "$ROOT" || exit 1
SHIM=self/runtime_core_hxlcl_shim.c
SRC=stdlib/runtime/hxlcl_core.hexa
[ -f "$SHIM" ] || { echo "run at repo root" >&2; exit 1; }
[ -f "$SRC" ]  || { echo "SSOT missing: $SRC" >&2; exit 1; }

# host gate
if [ "$(uname -s)" != "Linux" ] || { [ "$(uname -m)" != "x86_64" ] && [ "$(uname -m)" != "amd64" ]; }; then
    echo "[routec-signal] SKIP — Route C native emit is x86_64-linux-only (host=$(uname -sm))"
    exit 0
fi
echo "════ routec_signal_native_verify ($(uname -srm) · $($CC --version|head -1)) ════"

CFLAGS="-c -O2 -std=gnu11 -D_GNU_SOURCE"

# ── [A] DEFAULT shim.o byte-identity vs origin/main ─────────────────────────
echo "[A] DEFAULT (HEXA_RT_NATIVE_SIGNAL OFF) shim.o byte-identity vs origin/main…"
BN=runtime_core_hxlcl_shim.c
rm -rf "$OUT/base" "$OUT/new"; mkdir -p "$OUT/base" "$OUT/new"
git show "origin/main:$SHIM" > "$OUT/base/$BN" 2>/dev/null || cp "$SHIM" "$OUT/base/$BN"
cp "$SHIM" "$OUT/new/$BN"
( cd "$OUT/base" && $CC $CFLAGS "$BN" -o shim.o 2>err )
( cd "$OUT/new"  && $CC $CFLAGS "$BN" -o shim.o 2>err )
objcopy -O binary --only-section=.text "$OUT/base/shim.o" "$OUT/base.text" 2>/dev/null
objcopy -O binary --only-section=.text "$OUT/new/shim.o"  "$OUT/new.text" 2>/dev/null
TB=$(sha256sum "$OUT/base.text" 2>/dev/null | cut -d' ' -f1)
TN=$(sha256sum "$OUT/new.text"  2>/dev/null | cut -d' ' -f1)
echo "    .text base sha=$TB"
echo "    .text new  sha=$TN"
[ "$TB" = "$TN" ] && echo "DEFAULT_SHIM_TEXT_BYTE_IDENTICAL=YES" || echo "DEFAULT_SHIM_TEXT_BYTE_IDENTICAL=NO"

# ── [D] shim member count: default vs ON ────────────────────────────────────
echo "[D] shim hxlcl_* DEFINITION count: default vs ON (-DHEXA_RT_NATIVE_SIGNAL)…"
$CC $CFLAGS "$SHIM" -o "$OUT/shim_def.o" 2>/dev/null
$CC $CFLAGS -DHEXA_RT_NATIVE_SIGNAL "$SHIM" -o "$OUT/shim_on.o" 2>"$OUT/shim_on.err"
NDEF=$(nm "$OUT/shim_def.o" 2>/dev/null | grep -E ' T _?hxlcl_' | wc -l | tr -d ' ')
NON=$(nm  "$OUT/shim_on.o"  2>/dev/null | grep -E ' T _?hxlcl_' | wc -l | tr -d ' ')
echo "    shim hxlcl_* defs  default=$NDEF  ON=$NON  (expect ON = default-1)"
SIG_DEF_DEFAULT=$(nm "$OUT/shim_def.o" 2>/dev/null | grep -E ' T _?hxlcl_signal$' | wc -l | tr -d ' ')
SIG_DEF_ON=$(nm     "$OUT/shim_on.o"   2>/dev/null | grep -E ' T _?hxlcl_signal$' | wc -l | tr -d ' ')
echo "    hxlcl_signal defined in shim:  default=$SIG_DEF_DEFAULT  ON=$SIG_DEF_ON  (expect 1 → 0)"
[ "$SIG_DEF_DEFAULT" = "1" ] && [ "$SIG_DEF_ON" = "0" ] && echo "SHIM_SIGNAL_MEMBER_DROPPED=YES" || echo "SHIM_SIGNAL_MEMBER_DROPPED=NO"

# ── Route C native emit (needs the patched compiler) ────────────────────────
BIN="${HEXA_SELFEMIT_BIN:-$(command -v hexat || command -v hexa || true)}"
APRIME="${APRIME:-$ROOT/build/aprime_cc}"
[ -x "$APRIME" ] && BIN="$APRIME"
if [ -z "$BIN" ] || [ ! -x "${BIN}" ]; then
    echo "[B/C] SKIP — no patched compiler binary (set HEXA_SELFEMIT_BIN or build build/aprime_cc); A+D ran."
    exit 0
fi
echo "[B] Route C native emit of hxlcl_signal (HEXA_CABI_HXLCL=1) via $BIN…"
printf 'fn _rnsig_unused() {}\n' > "$OUT/_drv.hexa"
env HEXA_CABI_HXLCL=1 HEXA_INLINE_INT_BOX=1 HEXA_INLINE_BOOL_BOX=1 \
    "$BIN" "$OUT/_drv.hexa" --emit=asm --target=x86_64-linux-gnu -o "$OUT/routec.s" "$SRC" \
    >"$OUT/emit.log" 2>&1 || { echo "EMIT_FAIL"; cat "$OUT/emit.log" >&2; exit 1; }
[ -s "$OUT/routec.s" ] || { echo "EMPTY_ASM"; exit 1; }
$CC -c "$OUT/routec.s" -o "$OUT/routec_full.o" 2>"$OUT/asm.err" || { echo "ASSEMBLE_FAIL"; cat "$OUT/asm.err" >&2; exit 1; }
SIG_T_NATIVE=$(nm "$OUT/routec_full.o" 2>/dev/null | grep -E ' T _?hxlcl_signal$' | wc -l | tr -d ' ')
echo "    hxlcl_signal defined (T) in native routec.o = $SIG_T_NATIVE  (expect 1)"
# isolate signal (keep only that global)
objcopy --keep-global-symbol=hxlcl_signal "$OUT/routec_full.o" "$OUT/signal_only.o" 2>/dev/null \
    || cp "$OUT/routec_full.o" "$OUT/signal_only.o"
# Permitted externals: hxlcl_malloc (heap scratch), __errno_location (libc errno),
# __hx_syscall6 is an intrinsic (inlined, no reloc). Any OTHER reloc = not isolated.
SIG_BAD_RELOC=$(objdump -dr "$OUT/signal_only.o" 2>/dev/null \
    | grep -E 'R_X86_64_(PLT32|REX_)?(GOTPCREL|GOTPCRELX|PLT32)' \
    | grep -vE '\b(hxlcl_malloc|__errno_location)\b' \
    | grep -cE '\b(hxlcl_|__|syscall|signal|sigaction)\b')
echo "    FORBIDDEN non-{malloc,errno} external relocs from isolated hxlcl_signal = $SIG_BAD_RELOC  (expect 0)"

# ── [C] ★BEHAVIORAL MEASURE — native hxlcl_signal vs libc signal ────────────
echo "[C] ★BEHAVIORAL: native hxlcl_signal vs libc signal (SIGUSR1 set→raise→fire + old-handler)…"
cat > "$OUT/acc.c" <<'EOF'
#define _GNU_SOURCE
#include <stdio.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <setjmp.h>

extern void *hxlcl_signal(int signum, void *handler);

static volatile sig_atomic_t g_fired = 0;
static volatile sig_atomic_t g_caught_signo = 0;
static void my_handler(int sig) {
    g_fired = 1;
    g_caught_signo = sig;
}

int main(void) {
    int fail = 0;

    /* TEST 1: install handler via NATIVE hxlcl_signal, raise SIGUSR1, confirm it fires.
     * This is the wall-falsify test: if the x86_64 SA_RESTORER/sa_restorer gap is real,
     * raising the signal and returning from the handler will SIGSEGV (no restorer
     * trampoline → CPU executes garbage after the handler returns). We catch that. */
    printf("[C1] installing SIGUSR1 handler via native hxlcl_signal…\n");
    void *old = hxlcl_signal(SIGUSR1, (void*)my_handler);
    printf("     hxlcl_signal returned old handler = %p (SIG_DFL/SIG_IGN/SIG_ERR are %p/%p/%p)\n",
           old, (void*)SIG_DFL, (void*)SIG_IGN, (void*)SIG_ERR);
    if (old == (void*)SIG_ERR) {
        printf("     NATIVE_SIGNAL_INSTALL_FAILED (returned SIG_ERR) — rt_sigaction syscall failed\n");
        printf("WALL_FALSIFY=NO (install failed)\n");
        return 2;
    }
    printf("[C1] raising SIGUSR1 — if SA_RESTORER gap is real this SIGSEGVs after handler returns…\n");
    fflush(stdout);
    raise(SIGUSR1);
    /* if we reach here, the handler ran AND returned cleanly (restorer worked or not needed) */
    if (g_fired && g_caught_signo == SIGUSR1) {
        printf("     HANDLER_FIRED=YES (signo=%d) — native signal() handler installed + returned cleanly\n",
               (int)g_caught_signo);
        printf("WALL_FALSIFY=YES (behavior matches libc signal: install→raise→fire→clean-return)\n");
    } else {
        printf("     HANDLER_FIRED=NO (g_fired=%d g_caught_signo=%d) — handler did not fire\n",
               (int)g_fired, (int)g_caught_signo);
        printf("WALL_FALSIFY=NO (handler did not fire)\n");
        fail = 1;
    }

    /* TEST 2: old-handler return value sanity (musl returns sa_old.sa_handler).
     * After installing our handler, the disposition for SIGUSR1 is now my_handler.
     * A second hxlcl_signal(SIGUSR1, ...) should return my_handler as the old. */
    void *old2 = hxlcl_signal(SIGUSR1, (void*)SIG_DFL);
    printf("[C2] second install returned old = %p (expect == my_handler %p)\n", old2, (void*)my_handler);
    if (old2 == (void*)my_handler) {
        printf("     OLD_HANDLER_RETURN_CORRECT=YES\n");
    } else {
        printf("     OLD_HANDLER_RETURN_CORRECT=NO (mismatch — sa_old.sa_handler read wrong)\n");
        fail = 1;
    }

    printf(fail ? "BEHAVIORAL_TEST=FAIL\n" : "BEHAVIORAL_TEST=PASS\n");
    return fail ? 1 : 0;
}
EOF
$CC "$OUT/acc.c" "$OUT/signal_only.o" -o "$OUT/acc" 2>"$OUT/link.err" \
    || { echo "    [C] isolated link failed; see link.err"; cat "$OUT/link.err" >&2; echo "LINK_FAIL"; exit 1; }

# Run with a SIGSEGV guard so we can DISTINGUISH the restorer crash (the wall) from
# other failures. A SIGSEGV after raise() = the SA_RESTORER/restorer gap CONFIRMED.
"$OUT/acc" 2>"$OUT/run.err"
RC=$?
if [ $RC -eq 139 ]; then
    echo "    ★ PROCESS CRASHED WITH SIGSEGV (RC=139) — the x86_64 SA_RESTORER/sa_restorer wall CONFIRMED"
    echo "    (handler fired but could not return cleanly without a restorer trampoline)"
    echo "WALL_FALSIFY=NO (SIGSEGV = restorer gap)"
    echo "BEHAVIORAL_TEST=SIGSEGV"
    echo "════ routec_signal_native_verify done (acc SIGSEGV — wall CONFIRMED) ════"
    exit 0
fi
if [ $RC -eq 0 ]; then
    echo "════ routec_signal_native_verify done (acc PASS — wall FALSIFIED) ════"
else
    echo "    acc RC=$RC (non-SIGSEGV failure — see run.err)"; cat "$OUT/run.err" >&2
    echo "════ routec_signal_native_verify done (acc FAIL RC=$RC) ════"
fi
exit 0
