#!/usr/bin/env bash
# tool/measure_setjmp_roundtrip.sh
#
# ING #29 literal-∅ setjmp/longjmp @naked wall — measured evidence.
#
# ★ Two independent measurements on linux-x86_64:
#   (1) MUSL-LAYOUT round-trip: the native emit_hxlcl_setjmp_elf_o.hexa pair
#       (43+43 B musl jmp_buf, byte-id to musl src/setjmp/x86_64/{setjmp,longjmp}.S)
#       does setjmp→longjmp correctly when BOTH save+restore go through the
#       native pair (the emit's own test). PASS = the musl bytes are correct.
#   (2) GLIBC-LAYOUT COMPATIBILITY WALL: a glibc-setjmp-populated buffer (200 B,
#       the production try-block path — compiler/codegen/x86_64_linux.hexa:5308
#       `call setjmp`) restored by the musl-layout native longjmp → SEGV.
#       This is the structural wall census #4259 records: the production
#       try-block SAVE is glibc-layout, so a native longjmp DROP cannot read it.
#
# Both measurements are CAPTURED (exit code + stderr) — no LLM self-judge.
set -u
cd "$(dirname "$0")/.."

REPO="$(pwd)"
HEXA="${HEXA:-/Users/mini/.hx/bin/hexa}"
if [ ! -x "$HEXA" ]; then
    # aiden path fallback
    HEXA="${HEXA:-$HOME/.hx/bin/hexa}"
fi
echo "=== setjmp/longjmp @naked wall — measured evidence (linux-x86_64) ==="
echo "repo : $REPO"
echo "hexa : $HEXA ($($HEXA --version 2>&1 | head -1))"
echo "host : $(uname -m) $(uname -sr)"
echo "cc   : $(cc --version 2>&1 | head -1)"
echo

# ── (1) musl-layout round-trip (native pair both sides) ───────────────────
echo "── (1) musl-layout round-trip (native pair save+restore) ──"
OUT1=/tmp/setjmp_measure_musl
rm -f "$OUT1.o" "$OUT1" "$OUT1.log"
# emit the native .o via the hexa emitter (musl 43+43 B pair)
if ! $HEXA run test/native_build/emit_hxlcl_setjmp_elf_o.hexa > "$OUT1.emit.log" 2>&1; then
    echo "FAIL: hexa run emit_hxlcl_setjmp_elf_o.hexa failed"
    cat "$OUT1.emit.log" | tail -20
    exit 20
fi
# locate the emitted .o (emitter writes build/poc/hxlcl_setjmp_elf.o)
EMIT_O="$(ls -t build/poc/hxlcl_setjmp_elf.o hxlcl_setjmp_elf.o ./hxlcl_setjmp_elf.o 2>/dev/null | head -1)"
if [ -z "$EMIT_O" ] || [ ! -s "$EMIT_O" ]; then
    echo "FAIL: emitted .o not found"
    cat "$OUT1.emit.log" | tail -20
    exit 21
fi
echo "emit : $EMIT_O ($(stat -c%s "$EMIT_O") bytes)"
# link the roundtrip driver (no libc setjmp involved — only the native pair)
if cc -O0 test/native_build/hxlcl_setjmp_roundtrip.c "$EMIT_O" -o "$OUT1" > "$OUT1.log" 2>&1; then
    echo "link : OK"
else
    echo "FAIL: link failed"
    cat "$OUT1.log"
    exit 22
fi
"$OUT1" > "$OUT1.run.log" 2>&1
RC1=$?
echo "run  : exit=$RC1"
cat "$OUT1.run.log"
if [ $RC1 -eq 0 ]; then
    echo "M(1) : PASS — musl-layout native pair round-trip correct (val=42, 0→1 coercion)"
else
    echo "M(1) : FAIL — native pair broken (expected PASS)"
fi
echo

# ── (2) glibc-layout compatibility wall ───────────────────────────────────
echo "── (2) glibc-layout compatibility WALL (libc setjmp save → native longjmp restore) ──"
cat > /tmp/setjmp_glibc_wall.c <<'EOF'
#include <stdio.h>
#include <setjmp.h>

/* The native pair (musl 64-B layout) — same externs as the roundtrip test. */
__attribute__((returns_twice)) extern int  hxlcl_setjmp(void *buf);
__attribute__((noreturn))      extern void hxlcl_longjmp(void *buf, int val);

/* glibc setjmp writes a 200-B jmp_buf; the native longjmp reads a 64-B musl
 * layout. Restoring from the glibc-populated buffer with the musl-layout
 * longjmp reads garbage rbx/rbp/r12-r15/rsp/rip → SEGV (or wrong resume).
 * This is census #4259's structural wall, captured. */
int main(void) {
    jmp_buf glibc_buf;
    /* libc SAVE into glibc_buf (production try-block path). */
    int rc = setjmp(glibc_buf);
    if (rc == 0) {
        fprintf(stderr, "glibc setjmp returned 0 (first call)\n");
        fprintf(stderr, "ATTEMPT native (musl-layout) longjmp on glibc buffer...\n");
        /* native longjmp reads musl offsets from a glibc-populated buffer.
         * rsp/rip slots mismatch → SEGV or wild jump. */
        hxlcl_longjmp(glibc_buf, 42);
        fprintf(stderr, "UNEXPECTED: native longjmp returned\n");
        return 30;
    }
    fprintf(stderr, "resumed with rc=%d\n", rc);
    /* If we get here, the layouts happened to overlap enough to resume —
     * measure and report (still: rbx/rbp/r12-r15 almost certainly clobbered). */
    return 0;
}
EOF
OUT2=/tmp/setjmp_measure_glibc_wall
rm -f "$OUT2" "$OUT2.log"
if ! cc -O0 /tmp/setjmp_glibc_wall.c "$EMIT_O" -o "$OUT2" > "$OUT2.log" 2>&1; then
    echo "FAIL: glibc-wall link failed"
    cat "$OUT2.log"
    exit 23
fi
"$OUT2" > "$OUT2.run.log" 2>&1
RC2=$?
echo "run  : exit=$RC2"
cat "$OUT2.run.log"
# 139 = SIGSEGV, 134 = SIGABRT, any nonzero = the wall is real (mismatch)
if [ $RC2 -ne 0 ]; then
    echo "M(2) : WALL CONFIRMED — glibc-layout buffer + musl-layout native longjmp = crash (rc=$RC2)"
    echo "       (production try-block saves glibc-layout → native longjmp DROP infeasible)"
else
    echo "M(2) : SURPRISE — resumed without crash; verify rbx/rbp/r12-r15 integrity separately"
fi
echo

# ── (3) FLAG-ON production mismatch: musl SAVE + glibc RESTORE ─────────────
# This is the EXACT ABI seam HEXA_NATIVE_SETJMP=1 would produce: the codegen
# try-block SAVE becomes native musl `call hxlcl_setjmp`
# (compiler/codegen/x86_64_linux.hexa:5308 gate), but the matching RESTORE stays
# `hexa_throw` -> `static` glibc hxlcl_longjmp baked into the FROZEN runtime
# (self/runtime_emit_full.hexa:2082). So a musl-populated jmp_buf is restored by
# glibc longjmp. glibc longjmp DEMANGLES (PTR_MANGLE XOR-with-TLS-guard) the rsp
# and rip slots that musl setjmp wrote RAW → wild rsp/rip → SEGV. This MEASURES
# that flipping only the reachable (SAVE) side crashes — the wall.
echo "── (3) FLAG-ON production mismatch (native musl SAVE → glibc longjmp RESTORE) ──"
cat > /tmp/setjmp_flagon_mismatch.c <<'EOF'
#include <stdio.h>
#include <setjmp.h>

/* native musl-layout SAVE (the HEXA_NATIVE_SETJMP=1 codegen emits `call hxlcl_setjmp`). */
__attribute__((returns_twice)) extern int hxlcl_setjmp(void *buf);

/* glibc RESTORE — verbatim what the FROZEN runtime's hxlcl_longjmp does on x86_64-linux:
 *   static void hxlcl_longjmp(void *buf, int val){ longjmp(*(jmp_buf*)buf, val?val:1); }
 * (self/runtime_emit_full.hexa:2082). hexa_throw calls THIS, not the native one. */
static void glibc_longjmp_like_runtime(void *buf, int val) {
    longjmp(*(jmp_buf *)buf, val ? val : 1);   /* glibc longjmp, demangles rsp/rip */
}

int main(void) {
    /* a buffer big enough for either layout (codegen reserves 256 B / slot). */
    unsigned char jbuf[256];
    /* musl SAVE — writes rbx/rbp/r12-r15/rsp/rip RAW (no PTR_MANGLE). */
    int rc = hxlcl_setjmp(jbuf);
    if (rc == 0) {
        fprintf(stderr, "musl hxlcl_setjmp saved (rc=0, first call)\n");
        fprintf(stderr, "ATTEMPT glibc longjmp (frozen-runtime hexa_throw path) on musl buffer...\n");
        glibc_longjmp_like_runtime(jbuf, 7);    /* glibc demangles musl-raw rsp/rip → SEGV */
        fprintf(stderr, "UNEXPECTED: glibc longjmp returned\n");
        return 30;
    }
    fprintf(stderr, "resumed rc=%d\n", rc);
    return 0;
}
EOF
OUT3=/tmp/setjmp_measure_flagon
rm -f "$OUT3" "$OUT3.log"
if ! cc -O0 /tmp/setjmp_flagon_mismatch.c "$EMIT_O" -o "$OUT3" > "$OUT3.log" 2>&1; then
    echo "FAIL: flag-on-mismatch link failed"
    cat "$OUT3.log"
    exit 24
fi
"$OUT3" > "$OUT3.run.log" 2>&1
RC3=$?
echo "run  : exit=$RC3"
cat "$OUT3.run.log"
if [ $RC3 -ne 0 ]; then
    echo "M(3) : WALL CONFIRMED — musl SAVE + glibc RESTORE (the flag-ON path) = crash (rc=$RC3)"
    echo "       (HEXA_NATIVE_SETJMP=1 flips SAVE to musl; frozen-runtime RESTORE stays glibc -> SEGV)"
else
    echo "M(3) : SURPRISE — resumed without crash; verify rsp/rip/callee-saved integrity separately"
fi
echo

echo "=== verdict ==="
echo "M(1)=$RC1 (musl round-trip: 0=PASS)  M(2)=$RC2 (glibc-save+musl-restore: nonzero=WALL)  M(3)=$RC3 (musl-save+glibc-restore [FLAG-ON path]: nonzero=WALL)"
exit 0
