#!/usr/bin/env bash
# seed_abi_contract_smoke.sh — BEHAVIORAL contract gate for the self/native/*.s array seeds.
#
# WHY THIS EXISTS
# ---------------
# Every existing seed gate checks a PROXY, and every proxy lied:
#
#   .globl count      -> "4/4 exported"     ... while the 4 bodies were miscompiled
#   nm U-floor        -> "carrier-only"     ... catches raw-libc egress (class A) but is a NAME
#                                               check, so it is structurally blind to an ABI
#                                               mismatch (class B) and to a wrong struct layout
#                                               (class C). Both shipped as default for months.
#   byteeq / CI green -> "no regression"    ... green only means the broken path was never walked.
#
# Measured 2026-07-13/14: the i64/f64 seeds minted a 16-byte/i32 descriptor while C had long since
# widened HexaArrI64 to 24 bytes/i64. The codegen reads len at +8 as a 64-bit word, so it saw
# len=(cap<<32)|len — a huge value that SAILS THROUGH the bounds check into an out-of-bounds load.
# The reverse direction read cap from +12 (the high half of len) = 0, doubled it to 0, called
# realloc(old,0) — a free — and stored through the freed pointer. Not one gate saw any of it.
#
# So this gate does not inspect the seed. It RUNS it, through the canonical C-ABI entry points,
# linked against the REAL runtime.a, and asserts on the observable contract:
#
#   new(cap)      -> a descriptor with len=0, cap=cap, at the 24-byte offsets C expects
#   push() x N    -> len tracks, and the amortized-doubling grow path actually reallocs
#   box(i)        -> returns element i (this is what an out-of-bounds descriptor cannot do)
#
# The grow path is the sharpest edge: it only survives if the layout (C), the carriers (A) and the
# ABI (B) are ALL correct at once. A wrong cap offset turns realloc into free and the next store
# is a use-after-free.
#
# ⚠️ It must link the REAL runtime.a, never a stub. An isolated driver that stubs the carriers with
# plain malloc PASSES against a seed that routes its descriptor through the arena — measured. The
# arena rewinds under an escaping descriptor and silently overwrites its len/cap.
#
# USAGE
#   bash tool/seed_abi_contract_smoke.sh            # builds runtime.a if absent, then asserts
#   RUNTIME_A=path/to/runtime.a bash tool/...       # or point it at one
#
# EXIT: 0 = contract holds. non-zero = a seed is lying.
#
# DISCRIMINATION PROVEN (not assumed — convergence nobaseline-gate-yml-1 warns that a gate which
# only ever sees a privileged/incomplete env yields a false green). Measured on summer, GitHub
# fresh clone, env -u HEXA_PREBUILT_RUNTIME:
#     origin/main (broken seeds) -> rc=139 SIGSEGV   (the 3-class defect, mechanically exposed)
#     the fix branch             -> rc=0   22/22 PASS (i64 + f64, incl. the realloc grow path)
# A gate that cannot go RED on a known-broken tree is not a gate. This one can.
set -uo pipefail

HX="${HX_ROOT:-$(cd "$(dirname "$0")/.."; pwd)}"
CC="${CC:-cc}"
cd "$HX"

RUNTIME_A="${RUNTIME_A:-build/runtime.a}"
if [ ! -f "$RUNTIME_A" ]; then
    echo "[seed_abi_smoke] building $RUNTIME_A …"
    # A pristine checkout has no generated seeds (self/runtime.c &c are gitignored), and
    # stage_resolve_runtime_a refuses to run without them (EDGE_ASSET guard). Restore them first —
    # this is the same order the release pipeline uses.
    if [ ! -f self/runtime.c ] && [ -x tool/restore_frozen_seeds ]; then
        bash tool/restore_frozen_seeds >/dev/null 2>&1 || true
    fi
    # A stale prebuilt archive is the classic false verdict here (convergence
    # runtime-core-emit-hexa-1): unset it so we measure THIS tree.
    # stage_resolve_runtime_a requires CC/CFLAGS in the env (it refuses to guess).
    env -u HEXA_PREBUILT_RUNTIME \
        CC="$CC" CFLAGS="${CFLAGS:--O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs}" \
        bash tool/stage_resolve_runtime_a >"$HX/build_seed_abi_stage.log" 2>&1 || {
        echo "[seed_abi_smoke] ERROR: stage_resolve_runtime_a failed — cannot build $RUNTIME_A" >&2
        tail -12 "$HX/build_seed_abi_stage.log" >&2
        exit 1
    }
fi
[ -f "$RUNTIME_A" ] || { echo "[seed_abi_smoke] ERROR: no $RUNTIME_A" >&2; exit 1; }

TMP="$(mktemp -d -t seed_abi.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/drv.c" <<'DRV'
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

/* HexaVal is {tag@0, payload@8}: a 16-byte struct, so the SysV/AAPCS64 by-value rule passes and
 * returns it in exactly the (rax:rdx / x0:x1) pair the seeds speak. */
typedef struct { int64_t tag; int64_t payload; } HexaVal;

/* The CANONICAL C-ABI names. Whoever owns them — a C body, or a thunk in front of a *_seed —
 * must honour this signature. That is the whole contract under test. */
extern HexaVal hexa_arr_i64_new (int cap);
extern HexaVal hexa_arr_i64_push(HexaVal v, int64_t x);
extern int     hexa_arr_i64_len (HexaVal v);
extern HexaVal hexa_arr_i64_box (HexaVal v, int64_t i);

extern HexaVal hexa_arr_f64_new (int cap);
extern HexaVal hexa_arr_f64_push(HexaVal v, double x);
extern int     hexa_arr_f64_len (HexaVal v);
extern HexaVal hexa_arr_f64_box (HexaVal v, int64_t i);

/* The C struct the codegen reads directly (24 bytes, all i64). If a seed mints anything else,
 * the field reads below expose it immediately — which is the point. */
typedef struct { int64_t *data; int64_t len; int64_t cap; } ArrDesc;

static int fails = 0;
static void ck(const char *what, long long got, long long want) {
    int ok = (got == want);
    printf("  %-40s got=%-8lld want=%-8lld %s\n", what, got, want, ok ? "PASS" : "FAIL");
    if (!ok) fails++;
}

static void check_i64(void) {
    puts("[i64]");
    HexaVal v = hexa_arr_i64_new(2);            /* cap=2 -> the pushes below force 2 grows */
    if (!v.payload) { puts("  new() returned a NULL descriptor            FAIL"); fails++; return; }
    ck("tag == TAG_ARRAY(5)", v.tag, 5);

    /* Read the descriptor exactly as the codegen does: 24-byte, i64 fields. */
    ArrDesc *d = (ArrDesc *)(intptr_t)v.payload;
    ck("descriptor len @+8  (i64)", d->len, 0);
    ck("descriptor cap @+16 (i64)", d->cap, 2);
    ck("len() after new", hexa_arr_i64_len(v), 0);

    for (int i = 0; i < 5; i++) v = hexa_arr_i64_push(v, 100 + i);
    ck("len() after 5 pushes", hexa_arr_i64_len(v), 5);

    /* The grow path is the sharp edge: cap must have doubled 2 -> 4 -> 8. If cap were read from
     * the wrong offset it would be 0, realloc(old,0) would free the buffer, and the store right
     * after would be a use-after-free. */
    d = (ArrDesc *)(intptr_t)v.payload;
    ck("cap after amortized growth (2->4->8)", d->cap, 8);
    ck("len still coherent after growth", d->len, 5);

    for (int i = 0; i < 5; i++) {
        HexaVal e = hexa_arr_i64_box(v, i);
        char b[48]; snprintf(b, sizeof b, "box(%d) round-trips", i);
        ck(b, e.payload, 100 + i);
    }
}

static void check_f64(void) {
    puts("[f64]");
    HexaVal v = hexa_arr_f64_new(2);
    if (!v.payload) { puts("  new() returned a NULL descriptor            FAIL"); fails++; return; }
    ck("tag == TAG_ARRAY(5)", v.tag, 5);

    ArrDesc *d = (ArrDesc *)(intptr_t)v.payload;
    ck("descriptor len @+8  (i64)", d->len, 0);
    ck("descriptor cap @+16 (i64)", d->cap, 2);

    for (int i = 0; i < 5; i++) v = hexa_arr_f64_push(v, 1.5 + i);
    ck("len() after 5 pushes", hexa_arr_f64_len(v), 5);
    d = (ArrDesc *)(intptr_t)v.payload;
    ck("cap after amortized growth (2->4->8)", d->cap, 8);

    for (int i = 0; i < 5; i++) {
        HexaVal e = hexa_arr_f64_box(v, i);
        union { int64_t i; double d; } u; u.i = e.payload;   /* TAG_FLOAT payload = the raw bits */
        int ok = (u.d == 1.5 + i);
        printf("  box(%d) round-trips                       got=%-8g want=%-8g %s\n",
               i, u.d, 1.5 + i, ok ? "PASS" : "FAIL");
        if (!ok) fails++;
    }
}

int main(void) {
    check_i64();
    check_f64();
    printf("\nVERDICT: %s (%d failed assertions)\n", fails ? "SEED CONTRACT VIOLATED" : "CONTRACT HOLDS", fails);
    return fails ? 1 : 0;
}
DRV

# runtime.a carries its own _start (own-start flip), which collides with crt1.o. The driver only
# needs the array entry points, so let the first definition win rather than fight the CRT.
LDX="-Wl,--allow-multiple-definition"
[ "$(uname -s)" = "Darwin" ] && LDX=""   # ld64 has no such flag; Mach-O does not hit the clash

echo "[seed_abi_smoke] linking the driver against $RUNTIME_A (the REAL archive, not stubs)"
if ! $CC "$TMP/drv.c" "$RUNTIME_A" -o "$TMP/drv" $LDX -lm 2>"$TMP/link.err"; then
    echo "[seed_abi_smoke] ERROR: link failed" >&2
    grep -iE 'undefined|referenced from|symbol\(s\) not found|error' "$TMP/link.err" | head -12 >&2
    exit 1
fi

echo
"$TMP/drv"
rc=$?
echo
if [ "$rc" -ne 0 ]; then
    cat >&2 <<'MSG'
[seed_abi_smoke] FAIL — an array seed does not honour its C-ABI contract.

The three ways a seed lies, and what each looks like above:
  · layout  (class C) — descriptor len/cap read back wrong, or the grow path corrupts them.
                        The C struct is 24 bytes, all i64: { data@0, len@8, cap@16 }.
                        A seed minting 16 bytes with i32 len@8 / cap@12 produces exactly this.
  · ABI     (class B) — new()/len() return garbage because the seed reads a scalar param out of
                        the pair register (or returns in rdx while C reads rax). Fix: give the
                        seed an all-HexaVal signature and let C own the name as a thunk.
  · carrier (class A) — a raw libc extern (malloc/calloc/realloc/write) or hexa_int: aprime lowers
                        the call to a (tag,payload) pair, but the C-ABI body reads rdi as its first
                        scalar and returns in rax alone. Use the hexa_heap_* carriers.
MSG
fi
exit $rc
