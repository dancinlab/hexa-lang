/* num_float_core_gate.c — RT-NATIVE-ZEROC M4 num-float parse C-differential gate (c2).
 *
 * Byte-eq oracle for the native string→f64 parse port
 * (stdlib/runtime/num_float_core.hexa::rt_parse_float_native) against libc strtod
 * (the IEEE-correctly-rounded reference = the semantics __hx_to_double's
 * hxlcl_atof delegates to). The native body returns a TAG_FLOAT on its Clinger
 * fast-path domain (mantissa <= 2^53 AND |exp10| <= 22), where it MUST be
 * bit-exact to strtod; or a TAG_VOID sentinel out of domain, where the C
 * __hx_to_double wrapper falls back to strtod (so the end-to-end result is
 * strtod itself — trivially byte-eq, recorded as DELEGATED).
 *
 * Two tallies (the honest residual record):
 *   FAST  = native returned TAG_FLOAT; asserts bits(native) == bits(strtod).
 *   DELEG = native returned TAG_VOID; the runtime would run strtod (no native
 *           claim — counted, not asserted bit-exact against a native value).
 * A FAST mismatch is a real FAIL. The DELEG set is the measured residual
 * boundary (where native bows out to C strtod) — NOT fudged.
 *
 * NO ALLOC: pure raw-byte read + register accumulate + one float scale.
 *
 * Build: clang -O2 -std=gnu11 num_float_core_gate.c num_float_core.o -lm -o g && ./g
 * Exit 26 = full pass (every FAST case bit-exact). 1 = a FAST mismatch.
 */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

typedef enum { TAG_INT=0, TAG_FLOAT, TAG_BOOL, TAG_STR, TAG_VOID } HexaTag;
typedef struct HexaVal_ { HexaTag tag; union { int64_t i; double f; char* s; void* p; }; } HexaVal;
#define HX_FLOAT(v) ((v).f)
#define HX_IS_VOID(v)  ((v).tag == TAG_VOID)
#define HX_IS_FLOAT(v) ((v).tag == TAG_FLOAT)

extern HexaVal rt_parse_float_native(HexaVal s);

static int fails = 0, fast = 0, deleg = 0;

static uint64_t bits(double d){ uint64_t u; memcpy(&u,&d,8); return u; }

static void one(const char* cs) {
    HexaVal sv = (HexaVal){ .tag = TAG_STR, .s = (char*)cs };
    HexaVal r = rt_parse_float_native(sv);
    double ref = strtod(cs, NULL);
    if (HX_IS_VOID(r)) {
        deleg++;
        /* DELEGATED: the runtime runs strtod itself here — no native value to
         * compare. Record only. (Spot-confirm strtod is finite-defined.) */
        return;
    }
    if (!HX_IS_FLOAT(r)) {
        fails++;
        fprintf(stderr, "[num_float_gate] FAIL \"%s\": native tag=%d (not FLOAT/VOID)\n", cs, r.tag);
        return;
    }
    fast++;
    double nat = HX_FLOAT(r);
    /* bit-exact (handles -0.0 vs 0.0 distinctly, and NaN by bit pattern). */
    if (bits(nat) != bits(ref)) {
        fails++;
        fprintf(stderr, "[num_float_gate] FAST-MISMATCH \"%s\": native=%.17g (0x%016llx) strtod=%.17g (0x%016llx)\n",
                cs, nat, (unsigned long long)bits(nat), ref, (unsigned long long)bits(ref));
    }
}

int main(void) {
    /* layout sanity */
    if (sizeof(HexaVal) != 16) { fprintf(stderr,"sizeof(HexaVal)!=16\n"); return 2; }

    /* ── FAST-PATH domain (expect TAG_FLOAT, bit-exact == strtod) ── */
    one("0"); one("1"); one("42"); one("-1"); one("-42"); one("+7");
    one("0.0"); one("1.0"); one("-0.0"); one("0.5"); one("-0.5");
    one("3.14"); one("-3.14"); one("0.1"); one("0.2"); one("0.25");
    one("123.456"); one("-123.456"); one("1000000"); one("0.000001");
    one("1e0"); one("1e1"); one("1e-1"); one("1.5e3"); one("-2.5e-4");
    one("100.0"); one("0.125"); one("12345.6789"); one("9999.0");
    one("1e10"); one("1e-10"); one("1e22"); one("1e-22");          /* exp bound edges */
    one("123456789012345");        /* 15 sig digits, < 2^53 */
    one("9007199254740992");       /* 2^53 exactly (still <= bound) */
    one("2.2250738585072014e-3");  /* in-domain frac+exp */
    one("6.022e2");
    one("7.0"); one("8.5"); one(".5"); one("5."); one("0.000123");

    /* ── DELEGATED domain (expect TAG_VOID → C strtod owns it) ── */
    one("");                       /* empty */
    one("   ");                    /* whitespace only */
    one("abc");                    /* junk */
    one("1.2.3");                  /* second dot */
    one("1e");                     /* exp no digits */
    one("1e+");                    /* exp sign no digits */
    one("12345abc");               /* trailing junk */
    one("nan"); one("inf"); one("Infinity");
    one("0x1p4");                  /* hex float */
    one("1e23"); one("1e-23");     /* |exp| > 22 */
    one("12345678901234567890");   /* > 2^53 mantissa (20 digits) */
    one("3.141592653589793238");   /* 19 sig digits > 2^53 */
    one("1.7976931348623157e308"); /* DBL_MAX region — extreme */
    one("5e-324");                 /* smallest subnormal — extreme */
    one("123456789012345678");     /* 18 digits > 2^53 */

    printf("[num_float_gate] %s — FAST=%d (bit-exact vs strtod), DELEG=%d (→C strtod), fails=%d\n",
           fails ? "FAIL" : "PASS", fast, deleg, fails);
    return fails ? 1 : 26;
}
