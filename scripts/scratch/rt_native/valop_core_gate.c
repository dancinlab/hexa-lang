/* valop_core_gate.c — RT-NATIVE-ZEROC M4 valop-core C-differential gate (c2).
 *
 * Byte-eq oracle for the native SCALAR value-op port
 * (stdlib/runtime/valop_core.hexa::rt_truthy_native / rt_sub_native /
 * rt_mul_native / rt_add_native) against the standalone runtime.c C scalar
 * switch arms.
 *
 * Proves, for the int/float/bool/void scalar tags:
 *   - rt_truthy_native(v)  == the C hexa_truthy scalar switch (incl. NaN→true,
 *     ±0.0→false, nonzero-int/float→true, void→false)
 *   - rt_sub_native(a,b)   == the C int-int / int|float subtract (exact int64 &
 *     bit-identical double via memcmp)
 *   - rt_mul_native(a,b)   == the C int-int / int|float multiply
 *   - rt_add_native(a,b)   == the C int-int / int|float add (int64 wrap +
 *     bit-identical double, incl. inf+-inf=NaN)
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
extern HexaVal rt_add_native(HexaVal a, HexaVal b);
extern HexaVal rt_cmp_lt_native(HexaVal a, HexaVal b);
extern HexaVal rt_cmp_gt_native(HexaVal a, HexaVal b);
extern HexaVal rt_cmp_le_native(HexaVal a, HexaVal b);
extern HexaVal rt_cmp_ge_native(HexaVal a, HexaVal b);
extern HexaVal rt_div_native(HexaVal a, HexaVal b);
extern HexaVal rt_mod_native(HexaVal a, HexaVal b);

int hexa_truthy(HexaVal v);
HexaVal hexa_sub(HexaVal a, HexaVal b);
HexaVal hexa_mul(HexaVal a, HexaVal b);
HexaVal hexa_add_slow(HexaVal a, HexaVal b);
HexaVal hexa_cmp_lt(HexaVal a, HexaVal b);
HexaVal hexa_cmp_gt(HexaVal a, HexaVal b);
HexaVal hexa_cmp_le(HexaVal a, HexaVal b);
HexaVal hexa_cmp_ge(HexaVal a, HexaVal b);
HexaVal hexa_div(HexaVal a, HexaVal b);
HexaVal hexa_mod(HexaVal a, HexaVal b);

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

/* C reference scalar add: int-int → int (wraps like C int64); else double. */
static void chk_add(HexaVal a, HexaVal b, const char* what) {
    HexaVal nv = rt_add_native(a, b);
    char buf[160];
    if (HX_IS_INT(a) && HX_IS_INT(b)) {
        int64_t ref = HX_INT(a) + HX_INT(b);
        snprintf(buf, sizeof(buf), "rt_add_native %s native=%lld ref=%lld tag=%d",
                 what, (long long)HX_INT(nv), (long long)ref, (int)HX_TAG(nv));
        chk(HX_TAG(nv) == TAG_INT && HX_INT(nv) == ref, buf);
    } else {
        double da = HX_IS_FLOAT(a) ? HX_FLOAT(a) : (double)HX_INT(a);
        double db = HX_IS_FLOAT(b) ? HX_FLOAT(b) : (double)HX_INT(b);
        double ref = da + db;
        snprintf(buf, sizeof(buf), "rt_add_native %s native=%g ref=%g tag=%d",
                 what, HX_FLOAT(nv), ref, (int)HX_TAG(nv));
        chk(HX_TAG(nv) == TAG_FLOAT && dbits_eq(HX_FLOAT(nv), ref), buf);
    }
}

/* C reference scalar ordered-compare: int-int via int64, else via double
 * (NaN-aware — every comparison false, matching __raw_cmp3's code-3 path and the
 * hardware ucomisd/fcmp the native leaves emit). op: 0 lt · 1 gt · 2 le · 3 ge. */
static int c_cmp_scalar(HexaVal a, HexaVal b, int op) {
    if (HX_IS_INT(a) && HX_IS_INT(b)) {
        int64_t x = HX_INT(a), y = HX_INT(b);
        switch (op) { case 0: return x<y; case 1: return x>y; case 2: return x<=y; default: return x>=y; }
    }
    double x = HX_IS_FLOAT(a) ? HX_FLOAT(a) : (double)HX_INT(a);
    double y = HX_IS_FLOAT(b) ? HX_FLOAT(b) : (double)HX_INT(b);
    switch (op) { case 0: return x<y; case 1: return x>y; case 2: return x<=y; default: return x>=y; }
}

static void chk_cmp(HexaVal a, HexaVal b, const char* what) {
    HexaVal nlt = rt_cmp_lt_native(a, b), ngt = rt_cmp_gt_native(a, b);
    HexaVal nle = rt_cmp_le_native(a, b), nge = rt_cmp_ge_native(a, b);
    char buf[192];
    int ops[4] = { HX_BOOL(nlt), HX_BOOL(ngt), HX_BOOL(nle), HX_BOOL(nge) };
    int tags[4] = { (int)HX_TAG(nlt), (int)HX_TAG(ngt), (int)HX_TAG(nle), (int)HX_TAG(nge) };
    const char* names[4] = { "<", ">", "<=", ">=" };
    for (int op = 0; op < 4; op++) {
        int ref = c_cmp_scalar(a, b, op);
        snprintf(buf, sizeof(buf), "rt_cmp_%s_native %s native=%d ref=%d tag=%d",
                 names[op], what, ops[op], ref, tags[op]);
        chk(tags[op] == TAG_BOOL && ops[op] == ref, buf);
    }
}

/* int-int div/mod native vs C int64 / and % (truncating; sign of % follows
 * dividend). Caller MUST pass b != 0 and avoid INT64_MIN/-1 (both UB the leaf
 * shares with C — the C wrapper guards zero, overflow is unguarded in both). */
static void chk_div(HexaVal a, HexaVal b, const char* what) {
    HexaVal nv = rt_div_native(a, b);
    int64_t ref = HX_INT(a) / HX_INT(b);
    char buf[160];
    snprintf(buf, sizeof(buf), "rt_div_native %s native=%lld ref=%lld tag=%d",
             what, (long long)HX_INT(nv), (long long)ref, (int)HX_TAG(nv));
    chk(HX_TAG(nv) == TAG_INT && HX_INT(nv) == ref, buf);
}
static void chk_mod(HexaVal a, HexaVal b, const char* what) {
    HexaVal nv = rt_mod_native(a, b);
    int64_t ref = HX_INT(a) % HX_INT(b);
    char buf[160];
    snprintf(buf, sizeof(buf), "rt_mod_native %s native=%lld ref=%lld tag=%d",
             what, (long long)HX_INT(nv), (long long)ref, (int)HX_TAG(nv));
    chk(HX_TAG(nv) == TAG_INT && HX_INT(nv) == ref, buf);
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

    /* PART E — add (same int-int / int|float / float-float shape as sub/mul). */
    chk_add(hexa_int(10), hexa_int(3), "10+3");
    chk_add(hexa_int(-4), hexa_int(7), "-4+7");
    chk_add(hexa_int(0), hexa_int(0), "0+0");
    chk_add(hexa_int(INT64_MAX), hexa_int(1), "MAX+1 wrap");   /* C int64 wrap, native must match */
    chk_add(hexa_int(INT64_MIN), hexa_int(-1), "MIN+-1 wrap");
    chk_add(hexa_float(1.5), hexa_float(0.25), "1.5+0.25");
    chk_add(hexa_int(5), hexa_float(2.0), "5+2.0 mixed");
    chk_add(hexa_float(2.0), hexa_int(5), "2.0+5 mixed");
    chk_add(hexa_float(0.1), hexa_float(0.2), "0.1+0.2 (rounding)");
    chk_add(hexa_float(INFINITY), hexa_float(1.0), "inf+1");
    chk_add(hexa_float(INFINITY), hexa_float(-INFINITY), "inf+-inf=NaN");
    chk_add(hexa_float(NAN), hexa_float(2.0), "NaN+2");

    /* PART F — cmp lt/gt/le/ge: int-int, mixed, float-float, equal, NaN-unordered.
     * chk_cmp drives all 4 ops per pair (4 checks each). */
    chk_cmp(hexa_int(3), hexa_int(7), "3?7");
    chk_cmp(hexa_int(7), hexa_int(3), "7?3");
    chk_cmp(hexa_int(5), hexa_int(5), "5?5 (eq)");
    chk_cmp(hexa_int(-2), hexa_int(2), "-2?2");
    chk_cmp(hexa_int(INT64_MIN), hexa_int(INT64_MAX), "MIN?MAX");
    chk_cmp(hexa_float(1.5), hexa_float(2.5), "1.5?2.5");
    chk_cmp(hexa_float(2.5), hexa_float(2.5), "2.5?2.5 (eq)");
    chk_cmp(hexa_int(3), hexa_float(3.0), "3?3.0 mixed-eq");
    chk_cmp(hexa_int(3), hexa_float(2.9), "3?2.9 mixed");
    chk_cmp(hexa_float(2.9), hexa_int(3), "2.9?3 mixed");
    chk_cmp(hexa_float(0.1), hexa_float(0.2), "0.1?0.2");
    chk_cmp(hexa_float(NAN), hexa_float(1.0), "NaN?1 (all false)");
    chk_cmp(hexa_float(1.0), hexa_float(NAN), "1?NaN (all false)");
    chk_cmp(hexa_float(NAN), hexa_float(NAN), "NaN?NaN (all false)");
    chk_cmp(hexa_float(INFINITY), hexa_float(1.0), "inf?1");
    chk_cmp(hexa_float(-INFINITY), hexa_float(INFINITY), "-inf?inf");

    /* PART G — int div/mod (the new __hx_payload_div/mod leaves). All 4 sign
     * combos + truncation + remainder-sign-follows-dividend. b!=0, no MIN/-1. */
    chk_div(hexa_int(17), hexa_int(5), "17/5");
    chk_div(hexa_int(-17), hexa_int(5), "-17/5 (trunc → -3)");
    chk_div(hexa_int(17), hexa_int(-5), "17/-5 (trunc → -3)");
    chk_div(hexa_int(-17), hexa_int(-5), "-17/-5 (→ 3)");
    chk_div(hexa_int(0), hexa_int(7), "0/7");
    chk_div(hexa_int(20), hexa_int(4), "20/4 exact");
    chk_div(hexa_int(7), hexa_int(1), "7/1");
    chk_div(hexa_int(INT64_MAX), hexa_int(2), "MAX/2");
    chk_div(hexa_int(INT64_MIN), hexa_int(2), "MIN/2");
    chk_mod(hexa_int(17), hexa_int(5), "17%5 (→ 2)");
    chk_mod(hexa_int(-17), hexa_int(5), "-17%5 (→ -2, sign of dividend)");
    chk_mod(hexa_int(17), hexa_int(-5), "17%-5 (→ 2)");
    chk_mod(hexa_int(-17), hexa_int(-5), "-17%-5 (→ -2)");
    chk_mod(hexa_int(20), hexa_int(4), "20%4 (→ 0)");
    chk_mod(hexa_int(7), hexa_int(1), "7%1 (→ 0)");
    chk_mod(hexa_int(INT64_MIN), hexa_int(7), "MIN%7");

#ifdef HEXA_HAS_HEXA_RT_STDLIB
    /* PART D — end-to-end wrapper agreement (only when rt-stdlib deps linked). */
    chk(hexa_truthy(hexa_int(0)) == 0, "wrap truthy int0");
    chk(hexa_truthy(hexa_float(0.0)) == 0, "wrap truthy f0");
    chk(hexa_truthy(hexa_float(NAN)) == 1, "wrap truthy NaN");
    chk(HX_INT(hexa_sub(hexa_int(9), hexa_int(2))) == 7, "wrap sub 9-2");
    chk(HX_INT(hexa_mul(hexa_int(6), hexa_int(7))) == 42, "wrap mul 6*7");
    chk(dbits_eq(HX_FLOAT(hexa_sub(hexa_float(1.5), hexa_float(0.5))), 1.0), "wrap sub f");
    /* hexa_add_slow is the slow-path wrapper that carries the native add arm
     * (the int+int hexa_add MACRO never reaches it). Scalar numeric operands
     * delegate to rt_add_native; verify the wrapper round-trip. */
    chk(HX_INT(hexa_add_slow(hexa_int(40), hexa_int(2))) == 42, "wrap add_slow 40+2");
    chk(dbits_eq(HX_FLOAT(hexa_add_slow(hexa_float(1.5), hexa_float(0.5))), 2.0), "wrap add_slow f");
    chk(dbits_eq(HX_FLOAT(hexa_add_slow(hexa_int(3), hexa_float(0.5))), 3.5), "wrap add_slow mixed");
    /* cmp wrappers (hexa_cmp_* — scalar int/float delegate to rt_cmp_*_native). */
    chk(hexa_truthy(hexa_cmp_lt(hexa_int(3), hexa_int(7))) == 1, "wrap cmp 3<7");
    chk(hexa_truthy(hexa_cmp_gt(hexa_int(3), hexa_int(7))) == 0, "wrap cmp 3>7");
    chk(hexa_truthy(hexa_cmp_le(hexa_int(5), hexa_int(5))) == 1, "wrap cmp 5<=5");
    chk(hexa_truthy(hexa_cmp_ge(hexa_float(2.5), hexa_float(2.5))) == 1, "wrap cmp 2.5>=2.5");
    chk(hexa_truthy(hexa_cmp_lt(hexa_int(3), hexa_float(3.5))) == 1, "wrap cmp 3<3.5 mixed");
    chk(hexa_truthy(hexa_cmp_lt(hexa_float(NAN), hexa_float(1.0))) == 0, "wrap cmp NaN<1 false");
    /* div/mod wrappers (hexa_div/hexa_mod — int/int nonzero delegate to native;
     * zero-div throw + float path stay in rt_div/rt_mod, NOT exercised here to
     * avoid the longjmp). */
    chk(HX_INT(hexa_div(hexa_int(17), hexa_int(5))) == 3, "wrap div 17/5");
    chk(HX_INT(hexa_div(hexa_int(-17), hexa_int(5))) == -3, "wrap div -17/5");
    chk(HX_INT(hexa_mod(hexa_int(17), hexa_int(5))) == 2, "wrap mod 17%5");
    chk(HX_INT(hexa_mod(hexa_int(-17), hexa_int(5))) == -2, "wrap mod -17%5");
    chk(dbits_eq(HX_FLOAT(hexa_div(hexa_float(7.0), hexa_float(2.0))), 3.5), "wrap div f (rt_div path)");
#endif

    if (fails == 0) printf("[valop_core_gate] GATE PASS — %d checks, 0 fails\n", checks);
    else            printf("[valop_core_gate] GATE FAIL — %d checks, %d fails\n", checks, fails);
    return fails ? 1 : 25;
}
