/* valop_core_gate.c — RT-NATIVE-ZEROC M4 valop-core C-differential gate (c2).
 *
 * Byte-eq oracle for the native SCALAR value-op port
 * (stdlib/runtime/valop_core.hexa::rt_truthy_native / rt_sub_native /
 * rt_mul_native) against the standalone runtime.c C scalar switch arms.
 *
 * Proves, for the int/float/bool/void scalar tags:
 *   - rt_truthy_native(v)  == the C hexa_truthy scalar switch (incl. NaN→true,
 *     ±0.0→false, nonzero-int/float→true, void→false)
 *   - rt_sub_native(a,b)   == the C int-int / int|float subtract (exact int64 &
 *     bit-identical double via memcmp)
 *   - rt_mul_native(a,b)   == the C int-int / int|float multiply
 * and that the end-to-end wrappers (hexa_truthy / hexa_sub / hexa_mul, compiled
 * -DHEXA_RT_VALOP_NATIVE) agree with the same C reference.
 *
 * NO ALLOC: every body is tag-read + register arith + re-box. The non-scalar
 * arms (string/array/map concat, throw) stay C and are NOT exercised here.
 *
 * Build (x86_64 / arm64, native valop_core.o + standalone runtime.c):
 *   <aprime_cc> _drv --emit=obj --target=<t> -o valop_core.o valop_core.hexa
 *   cc -O2 -std=gnu11 -D_GNU_SOURCE -DHEXA_RT_VALOP_NATIVE=1 -DHEXA_HAS_HEXA_RT_STDLIB \
 *      -I self valop_core_gate.c self/runtime.c valop_core.o <rt_stdlib deps> -o /tmp/vgate
 *   /tmp/vgate ; echo $?
 *
 * NOTE: hexa_sub/hexa_mul under HEXA_HAS_HEXA_RT_STDLIB delegate the non-scalar
 * fallback to rt_sub/rt_mul (numeric.hexa). This gate only drives SCALAR operands,
 * so the fallback is never taken — but the link must still resolve rt_sub/rt_mul
 * (the harness links numeric.o). To keep this gate self-contained when the
 * rt-stdlib deps are NOT linked, build WITHOUT -DHEXA_HAS_HEXA_RT_STDLIB: then
 * hexa_sub/hexa_mul take the pure-C #else body and we compare the native seed fns
 * DIRECTLY against the C oracle (PART B/C), skipping the wrapper round-trip
 * (PART D guarded by the macro).
 *
 * Exit code = 25 on FULL pass (distinct sentinel); 1 on any fail.
 */
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <math.h>
#include "runtime.h"

/* native ports (gen2-emitted object). */
extern HexaVal rt_truthy_native(HexaVal v);
extern HexaVal rt_sub_native(HexaVal a, HexaVal b);
extern HexaVal rt_mul_native(HexaVal a, HexaVal b);

int hexa_truthy(HexaVal v);
HexaVal hexa_sub(HexaVal a, HexaVal b);
HexaVal hexa_mul(HexaVal a, HexaVal b);

static int fails = 0, checks = 0;
static void chk(int cond, const char* what) {
    checks++;
    if (!cond) { fails++; fprintf(stderr, "[valop_core_gate] FAIL: %s\n", what); }
}

/* C reference for the scalar truthy switch (mirrors runtime_core.c arms). */
static int c_truthy_scalar(HexaVal v) {
    switch (HX_TAG(v)) {
        case TAG_BOOL:  return HX_BOOL(v);
        case TAG_INT:   return HX_INT(v) != 0;
        case TAG_FLOAT: return HX_FLOAT(v) != 0.0;
        case TAG_VOID:  return 0;
        default:        return 1;
    }
}

static void chk_truthy(HexaVal v, const char* what) {
    /* native seed returns a TAG_BOOL HexaVal whose payload is 0/1. */
    HexaVal nv = rt_truthy_native(v);
    int nat = HX_BOOL(nv);
    int ref = c_truthy_scalar(v);
    char buf[160];
    snprintf(buf, sizeof(buf), "rt_truthy_native %s native=%d ref=%d (tag=%d)",
             what, nat, ref, (int)HX_TAG(nv));
    chk(nat == ref && HX_TAG(nv) == TAG_BOOL, buf);
}

/* bit-identical double compare (NaN-safe, ±0 distinct from value). */
static int dbits_eq(double a, double b) { return memcmp(&a, &b, sizeof(double)) == 0; }

/* C reference scalar sub: int-int → int; else double. */
static void chk_sub(HexaVal a, HexaVal b, const char* what) {
    HexaVal nv = rt_sub_native(a, b);
    char buf[160];
    if (HX_IS_INT(a) && HX_IS_INT(b)) {
        int64_t ref = HX_INT(a) - HX_INT(b);
        snprintf(buf, sizeof(buf), "rt_sub_native %s native=%lld ref=%lld tag=%d",
                 what, (long long)HX_INT(nv), (long long)ref, (int)HX_TAG(nv));
        chk(HX_TAG(nv) == TAG_INT && HX_INT(nv) == ref, buf);
    } else {
        double da = HX_IS_FLOAT(a) ? HX_FLOAT(a) : (double)HX_INT(a);
        double db = HX_IS_FLOAT(b) ? HX_FLOAT(b) : (double)HX_INT(b);
        double ref = da - db;
        snprintf(buf, sizeof(buf), "rt_sub_native %s native=%g ref=%g tag=%d",
                 what, HX_FLOAT(nv), ref, (int)HX_TAG(nv));
        chk(HX_TAG(nv) == TAG_FLOAT && dbits_eq(HX_FLOAT(nv), ref), buf);
    }
}

static void chk_mul(HexaVal a, HexaVal b, const char* what) {
    HexaVal nv = rt_mul_native(a, b);
    char buf[160];
    if (HX_IS_INT(a) && HX_IS_INT(b)) {
        int64_t ref = HX_INT(a) * HX_INT(b);
        snprintf(buf, sizeof(buf), "rt_mul_native %s native=%lld ref=%lld tag=%d",
                 what, (long long)HX_INT(nv), (long long)ref, (int)HX_TAG(nv));
        chk(HX_TAG(nv) == TAG_INT && HX_INT(nv) == ref, buf);
    } else {
        double da = HX_IS_FLOAT(a) ? HX_FLOAT(a) : (double)HX_INT(a);
        double db = HX_IS_FLOAT(b) ? HX_FLOAT(b) : (double)HX_INT(b);
        double ref = da * db;
        snprintf(buf, sizeof(buf), "rt_mul_native %s native=%g ref=%g tag=%d",
                 what, HX_FLOAT(nv), ref, (int)HX_TAG(nv));
        chk(HX_TAG(nv) == TAG_FLOAT && dbits_eq(HX_FLOAT(nv), ref), buf);
    }
}

int main(void) {
    chk(sizeof(HexaVal) == 16, "sizeof(HexaVal)==16");

    /* PART A — truthy scalar dispatch. */
    chk_truthy(hexa_bool(0), "bool false");
    chk_truthy(hexa_bool(1), "bool true");
    chk_truthy(hexa_int(0), "int 0");
    chk_truthy(hexa_int(1), "int 1");
    chk_truthy(hexa_int(-5), "int -5");
    chk_truthy(hexa_int(INT64_MAX), "int MAX");
    chk_truthy(hexa_int(INT64_MIN), "int MIN");
    chk_truthy(hexa_float(0.0), "float +0.0");
    chk_truthy(hexa_float(-0.0), "float -0.0");
    chk_truthy(hexa_float(1.5), "float 1.5");
    chk_truthy(hexa_float(-2.25), "float -2.25");
    chk_truthy(hexa_float(NAN), "float NaN");
    chk_truthy(hexa_float(INFINITY), "float +inf");
    chk_truthy(hexa_float(-INFINITY), "float -inf");
    chk_truthy(hexa_void(), "void");

    /* PART B — sub: int-int, int|float, float-float. */
    chk_sub(hexa_int(10), hexa_int(3), "10-3");
    chk_sub(hexa_int(-4), hexa_int(7), "-4-7");
    chk_sub(hexa_int(0), hexa_int(0), "0-0");
    chk_sub(hexa_int(INT64_MIN), hexa_int(1), "MIN-1 wrap");   /* C int64 wrap, native must match */
    chk_sub(hexa_float(1.5), hexa_float(0.25), "1.5-0.25");
    chk_sub(hexa_int(5), hexa_float(2.0), "5-2.0 mixed");
    chk_sub(hexa_float(2.0), hexa_int(5), "2.0-5 mixed");
    chk_sub(hexa_float(0.1), hexa_float(0.2), "0.1-0.2 (rounding)");
    chk_sub(hexa_float(INFINITY), hexa_float(1.0), "inf-1");

    /* PART C — mul. */
    chk_mul(hexa_int(6), hexa_int(7), "6*7");
    chk_mul(hexa_int(-3), hexa_int(4), "-3*4");
    chk_mul(hexa_int(0), hexa_int(99), "0*99");
    chk_mul(hexa_float(1.5), hexa_float(2.0), "1.5*2.0");
    chk_mul(hexa_int(3), hexa_float(0.5), "3*0.5 mixed");
    chk_mul(hexa_float(0.1), hexa_float(0.1), "0.1*0.1 (rounding)");
    chk_mul(hexa_float(NAN), hexa_float(2.0), "NaN*2");

#ifdef HEXA_HAS_HEXA_RT_STDLIB
    /* PART D — end-to-end wrapper agreement (only when rt-stdlib deps linked). */
    chk(hexa_truthy(hexa_int(0)) == 0, "wrap truthy int0");
    chk(hexa_truthy(hexa_float(0.0)) == 0, "wrap truthy f0");
    chk(hexa_truthy(hexa_float(NAN)) == 1, "wrap truthy NaN");
    chk(HX_INT(hexa_sub(hexa_int(9), hexa_int(2))) == 7, "wrap sub 9-2");
    chk(HX_INT(hexa_mul(hexa_int(6), hexa_int(7))) == 42, "wrap mul 6*7");
    chk(dbits_eq(HX_FLOAT(hexa_sub(hexa_float(1.5), hexa_float(0.5))), 1.0), "wrap sub f");
#endif

    if (fails == 0) printf("[valop_core_gate] GATE PASS — %d checks, 0 fails\n", checks);
    else            printf("[valop_core_gate] GATE FAIL — %d checks, %d fails\n", checks, fails);
    return fails ? 1 : 25;
}
