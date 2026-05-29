/* test/native_build/classd_behavioral_harness.c
 *
 * F3 FLOOR — REUSABLE class-D BEHAVIORAL JIT-EXEC HARNESS.
 *
 * ── WHAT THIS IS ──────────────────────────────────────────────────────────
 * The class-D self-emit drivers (test/native_build/emit_rt_<name>_classd_o.hexa)
 * EMIT + byte/`as`-validate a Mach-O `.o` exporting `_rt_<name>` whose body is
 * hexa's OWN ARM64 instruction selection (a scalar, branchy form — deliberately
 * NOT clang -O2's auto-vectorized / and-mask-fused / tail-call form). They do
 * NOT execute the code. The BEHAVIORAL JIT-exec — actually CALLING the emitted
 * fn and checking the returned HexaVal (tag + value) against the reference C
 * contract — is a SEPARATE link+run step. Prior waves (PR #1914 / scaleout-3 /
 * batch2) did this with a throwaway /tmp/hexa_classd_test.c rebuilt per wave.
 *
 * THIS file is the COMMITTED, REUSABLE, table-driven replacement so the
 * ~557 remaining class-D HexaVal-returning bodies can be behaviorally gated
 * with zero bespoke C each wave: add one row to the relevant table below,
 * emit the .o, link, run.
 *
 * ── HOW IT LINKS (the load-bearing detail) ───────────────────────────────
 * Each `_rt_<name>.o` declares an UNDEFINED-external ctor callee
 * (`_hexa_bool` / `_hexa_int` / `_hexa_float` / `_hexa_str`) reached by ONE
 * ARM64_RELOC_BRANCH26 `bl`. This harness PROVIDES those ctors as stand-ins
 * whose ABI is byte-exact with self/runtime.c (tag in x0 low half, union in
 * x1) + the HX_* accessors. ld64 binds the .o's BRANCH26 to these symbols.
 * In the LIVE runtime (HEXA_RT_SELFEMIT build) the same `bl` binds to
 * runtime_core.c's real ctors instead — identical ABI, so a PASS here is a
 * faithful proxy for the live-wired symbol path (the gate-(d) re-run).
 *
 *   self-emit .o   :  U _hexa_bool / _hexa_int / ...   (BRANCH26)
 *   this harness   :  T _hexa_bool / _hexa_int / ...   (stand-in, ABI-exact)
 *   live runtime   :  T hexa_bool  / hexa_int  / ...   (runtime_core.c)
 *
 * ── THE GATE ──────────────────────────────────────────────────────────────
 * Behavioral equivalence (NOT byte-identity-vs-clang) per the PR #1911
 * VERIFICATION-MODEL FINDING. A class-D body PASSES iff, for every input in
 * its battery, the returned HexaVal's tag AND value equal the reference C
 * implementation's. Range predicates (isalpha/isalnum) are swept EXHAUSTIVELY
 * over the full ASCII contract domain 0..255 — every edge ('@'/'A'/'Z'/'['
 * '`'/'a'/'z'/'{' boundary bytes, digits, whitespace, high bytes) is covered.
 *
 * ── BUILD / RUN (reproducible; no committed binaries) ─────────────────────
 *   # 1. emit each .o (on-PATH hexa-run; HEXA_VAL_ARENA=0 keeps interp light)
 *   HEXA_RT_ISALPHA_CLASSD_O=/tmp/rt_isalpha_classd.o HEXA_VAL_ARENA=0 \
 *     hexa-run test/native_build/emit_rt_isalpha_classd_o.hexa
 *   HEXA_RT_ISALNUM_CLASSD_O=/tmp/rt_isalnum_classd.o HEXA_VAL_ARENA=0 \
 *     hexa-run test/native_build/emit_rt_isalnum_classd_o.hexa
 *   HEXA_RT_PTHREAD_NOOP_CLASSD_O=/tmp/rt_pthread_noop_classd.o HEXA_VAL_ARENA=0 \
 *     hexa-run test/native_build/emit_rt_pthread_noop_classd_o.hexa
 *   HEXA_RT_PTHREAD_CREATE_POLICY_CLASSD_O=/tmp/rt_pthread_create_policy_classd.o \
 *     HEXA_VAL_ARENA=0 \
 *     hexa-run test/native_build/emit_rt_pthread_create_policy_classd_o.hexa
 *   # 2. link the harness against all emitted .o + run
 *   clang -arch arm64 -O0 test/native_build/classd_behavioral_harness.c \
 *     /tmp/rt_isalpha_classd.o /tmp/rt_isalnum_classd.o \
 *     /tmp/rt_pthread_noop_classd.o /tmp/rt_pthread_create_policy_classd.o \
 *     -o /tmp/classd_harness && /tmp/classd_harness ; echo "rc=$?"
 *   # rc=0 + "ALL BEHAVIORAL CHECKS PASS" → behavioral gate PASS.
 *
 * See test/native_build/CLASSD_HARNESS.md for the full per-body scale-out
 * runbook (how to add the ~557 remaining bodies).
 */

#include <stdio.h>
#include <stdint.h>
#include <string.h>

/* ── HexaVal ABI — byte-exact mirror of self/runtime.h ─────────────────────
 * typedef enum { TAG_INT=0, TAG_FLOAT, TAG_BOOL, TAG_STR, TAG_VOID, ... }
 * struct { HexaTag tag; union { int64_t i; double f; int b; char* s; }; }
 * 16 bytes total (4-B tag + 4-B pad + 8-B union) → returned in x0:x1.        */
typedef enum {
    TAG_INT = 0, TAG_FLOAT, TAG_BOOL, TAG_STR, TAG_VOID,
    TAG_ARRAY, TAG_MAP, TAG_FN, TAG_CHAR, TAG_CLOSURE,
    TAG_VALSTRUCT, TAG_ENUM
} HexaTag;

typedef struct {
    HexaTag tag;
    union {
        int64_t i;
        double  f;
        int     b;
        char*   s;
    };
} HexaVal;

#define HX_TAG(v)   ((v).tag)
#define HX_INT(v)   ((v).i)
#define HX_FLOAT(v) ((v).f)
#define HX_BOOL(v)  ((v).b)
#define HX_STR(v)   ((v).s)

/* ── Ctor stand-ins (BRANCH26 callees) — ABI-exact w/ runtime.c ────────────
 * These are what each self-emit .o's `bl _hexa_<ctor>` binds to here. In the
 * live HEXA_RT_SELFEMIT runtime the same bl binds to runtime_core.c's ctors;
 * both place tag in x0:lo, value in x1 — identical observable ABI.            */
HexaVal hexa_int(int64_t n)  { HexaVal v; v.tag = TAG_INT;   v.i = n; return v; }
HexaVal hexa_bool(int b)     { HexaVal v; v.tag = TAG_BOOL;  v.b = b; return v; }
HexaVal hexa_float(double f) { HexaVal v; v.tag = TAG_FLOAT; v.f = f; return v; }
HexaVal hexa_void(void)      { HexaVal v; v.tag = TAG_VOID;  v.i = 0; return v; }
HexaVal hexa_str(const char* s) { HexaVal v; v.tag = TAG_STR; v.s = (char*)s; return v; }

/* ── self-emitted bodies under test (resolved by the linked .o's) ──────────
 * Add an `extern HexaVal rt_<name>(...);` line here as bodies scale out.      */
extern HexaVal rt_isalpha(HexaVal c);
extern HexaVal rt_isalnum(HexaVal c);
extern HexaVal rt_pthread_noop(void);
extern HexaVal rt_pthread_create_policy(void);

static int g_pass = 0, g_fail = 0;

/* check a HexaVal-returning unary(HexaVal-int) body vs an int reference fn,
 * EXHAUSTIVELY over the ASCII contract domain 0..255 (all edge bytes). */
static void sweep_int_unary_bool(const char* name,
                                 HexaVal (*body)(HexaVal),
                                 int (*ref)(int)) {
    int local_fail = 0, edges = 0;
    for (int cp = 0; cp <= 255; cp++) {
        HexaVal in; in.tag = TAG_INT; in.i = cp;
        HexaVal got = body(in);
        int want = ref(cp) ? 1 : 0;
        int tag_ok = (HX_TAG(got) == TAG_BOOL);
        int val_ok = (HX_BOOL(got) == want);
        if (!tag_ok || !val_ok) {
            if (local_fail < 8)
                fprintf(stderr,
                  "  FAIL %s(%d '%c'): tag=%d (want %d) .b=%d (want %d)\n",
                  name, cp, (cp >= 32 && cp < 127) ? cp : '.',
                  HX_TAG(got), TAG_BOOL, HX_BOOL(got), want);
            local_fail++;
        }
        /* count boundary bytes proven for the report */
        if (cp==0x2f||cp==0x30||cp==0x39||cp==0x3a||cp==0x40||cp==0x41||
            cp==0x5a||cp==0x5b||cp==0x60||cp==0x61||cp==0x7a||cp==0x7b||
            cp==' '||cp=='\t'||cp==0x80||cp==0xff) edges++;
    }
    if (local_fail == 0) {
        printf("  PASS %-26s 256/256 codepoints (all %d edge bytes) → tag+val match ref\n",
               name, edges);
        g_pass++;
    } else {
        printf("  FAIL %-26s %d/256 codepoints diverged from ref\n", name, local_fail);
        g_fail++;
    }
}

/* check a 0-arg HexaVal-returning body returns a constant {TAG_INT, want}. */
static void check_int_const(const char* name, HexaVal (*body)(void),
                            int64_t want) {
    int local_fail = 0;
    for (int k = 0; k < 4; k++) {  /* call 4× to catch register-state leak */
        HexaVal got = body();
        if (HX_TAG(got) != TAG_INT || HX_INT(got) != want) {
            fprintf(stderr, "  FAIL %s call#%d: tag=%d (want %d) .i=%lld (want %lld)\n",
                    name, k, HX_TAG(got), TAG_INT, (long long)HX_INT(got),
                    (long long)want);
            local_fail++;
        }
    }
    if (local_fail == 0) {
        printf("  PASS %-26s 4/4 calls → {TAG_INT, %lld} (deterministic, no leak)\n",
               name, (long long)want);
        g_pass++;
    } else { printf("  FAIL %-26s\n", name); g_fail++; }
}

/* ── reference C predicates (the contract these bodies must reproduce) ──────
 * Verbatim from self/runtime.c's class-D C fallback bodies (locale-free,
 * ANSI ASCII). NOT clang's optimized form — the CONTRACT, not the codegen.  */
static int ref_isalpha(int v) {
    return ((v >= 65 && v <= 90) || (v >= 97 && v <= 122)) ? 1 : 0;
}
static int ref_isalnum(int v) {
    return ((v >= 48 && v <= 57) || (v >= 65 && v <= 90) ||
            (v >= 97 && v <= 122)) ? 1 : 0;
}

int main(void) {
    printf("F3 class-D BEHAVIORAL JIT-exec harness "
           "(reusable · table-driven · ASCII-exhaustive)\n");
    printf("gate = behavioral equivalence (tag+value vs reference C), "
           "NOT byte-identity-vs-clang\n\n");

    /* ── TABLE 1: HexaVal-int → HexaVal-bool range predicates ── */
    printf("=== HexaVal(int)->HexaVal(bool) range bodies (ctor callee _hexa_bool) ===\n");
    sweep_int_unary_bool("rt_isalpha", rt_isalpha, ref_isalpha);
    sweep_int_unary_bool("rt_isalnum", rt_isalnum, ref_isalnum);

    /* ── TABLE 2: 0-arg → HexaVal-int constant bodies ── */
    printf("\n=== ()->HexaVal(int) constant bodies (ctor callee _hexa_int) ===\n");
    check_int_const("rt_pthread_noop",           rt_pthread_noop,           0);
    check_int_const("rt_pthread_create_policy",  rt_pthread_create_policy,  1);

    printf("\nSUMMARY: PASS=%d  FAIL=%d\n", g_pass, g_fail);
    if (g_fail == 0) {
        printf("RESULT: ALL BEHAVIORAL CHECKS PASS\n");
        return 0;
    }
    printf("RESULT: BEHAVIORAL FAILURE — do NOT activate the failing body\n");
    return 1;
}
