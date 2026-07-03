/* float_dtoa_shortest_gate.c — zero-c float-dtoa R2 verification.
 * @state-ok: sibling of scripts/scratch/rt_native/float_dtoa_core_gate.c (the
 * keystone differential gate); a regenerable C differential oracle kept beside
 * its peers in the rt_native gate dir.
 *
 * Verifies that the HEXA_REPR_NATIVE shortest path (runtime_core_emit.hexa
 * __hexa_format_float_mode, NATIVE arm) is BYTE-IDENTICAL to the default
 * SHORTEST path for every finite/special double.
 *
 *   C-shortest  (SHORTEST mode): smallest p in [1,17] with snprintf("%.*g",p,f)
 *               round-tripping via strtod  — the canonical default.
 *   nat-shortest (NATIVE mode):  smallest p in [1,17] with rt_format_float_native(f,p)
 *               round-tripping via rt_parse_float_native (sentinel→strtod).
 *
 * The two must agree byte-for-byte. This covers the one link the keystone gate
 * (float_dtoa_core_gate.c, sig=17 only) did NOT: that rt_format_float_native is
 * byte-exact to snprintf("%.*g",p,.) for ALL p in [1,17], not just p=17.
 *
 * Build (opt-in; needs the native formatter+parser compiled + the hexa runtime):
 *   aprime_cc _drv.hexa --emit=obj --target=x86_64-linux-gnu \
 *       -o num_float_core.o stdlib/runtime/num_float_core.hexa
 *   clang -O2 -std=gnu11 float_dtoa_shortest_gate.c num_float_core.o \
 *       ~/.hx/bin/build/runtime.a -lm -o g && ./g
 * Exit 26 = full pass (every case byte-identical). 1 = a mismatch.
 */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

typedef enum { TAG_INT=0, TAG_FLOAT, TAG_BOOL, TAG_STR, TAG_VOID } HexaTag;
typedef struct HexaVal_ { HexaTag tag; union { int64_t i; double f; char* s; void* p; }; } HexaVal;
#define HX_STR(v) ((v).s)

extern HexaVal rt_format_float_native(HexaVal v, HexaVal sig);
extern HexaVal rt_parse_float_native(HexaVal s);

static int fails = 0, total = 0;

static HexaVal hxf(double d){ HexaVal v; v.tag=TAG_FLOAT; v.f=d; return v; }
static HexaVal hxi(int64_t n){ HexaVal v; v.tag=TAG_INT; v.i=n; return v; }
static double frombits(uint64_t u){ double d; memcpy(&d,&u,8); return d; }

/* mirror runtime_core_emit.hexa __hexa_format_float_mode SHORTEST arm */
static void cshortest(double f, char* out, size_t cap) {
    unsigned long long fb; memcpy(&fb,&f,8);
    for (int p=1;p<=17;p++){
        snprintf(out, cap, "%.*g", p, f);
        double rp = strtod(out, NULL);
        unsigned long long rb; memcpy(&rb,&rp,8);
        if (fb==rb) return;
    }
    snprintf(out, cap, "%.17g", f);
}

/* mirror runtime_core_emit.hexa __hexa_format_float_mode NATIVE arm (R2) */
static void natshortest(double f, char* out, size_t cap) {
    unsigned long long fb; memcpy(&fb,&f,8);
    for (int p=1;p<=17;p++){
        HexaVal r = rt_format_float_native(hxf(f), hxi(p));
        if (r.tag != TAG_STR || !HX_STR(r)) break;
        HexaVal pv = rt_parse_float_native(r);
        double rp = (pv.tag==TAG_FLOAT) ? pv.f : strtod(HX_STR(r), NULL);
        unsigned long long rb; memcpy(&rb,&rp,8);
        if (fb==rb){ snprintf(out,cap,"%s", HX_STR(r)); return; }
    }
    HexaVal r = rt_format_float_native(hxf(f), hxi(17));
    if (r.tag==TAG_STR && HX_STR(r)){ snprintf(out,cap,"%s", HX_STR(r)); return; }
    snprintf(out,cap,"%.17g", f);
}

static void chk(double d) {
    char cref[64], cnat[64];
    cshortest(d, cref, sizeof cref);
    natshortest(d, cnat, sizeof cnat);
    total++;
    if (strcmp(cref, cnat)) {
        fails++;
        if (fails <= 40) {
            uint64_t u; memcpy(&u,&d,8);
            fprintf(stderr, "[float_dtoa_shortest] MISMATCH bits=0x%016llx native=\"%s\" cshort=\"%s\"\n",
                    (unsigned long long)u, cnat, cref);
        }
    }
}

int main(void) {
    if (sizeof(HexaVal) != 16) { fprintf(stderr,"sizeof(HexaVal)!=16\n"); return 2; }

    double reps[] = {
        0.0, -0.0, 0.5, -0.5, 0.25, 0.125, 2.5, 3.5,
        0.1, 0.2, 0.3, 0.30000000000000004, 1.0/3.0,
        1.0, -1.0, 42.0, 100.0, 3.0, 9999.0,
        1e21, 1e-7, 1e308, 1e-308, 1e22, 1e-22, 1e23, 1e-23,
        1.7976931348623157e308, 2.2250738585072014e-308,
        9007199254740992.0, 9007199254740994.0,
        123.456, -123.456, 12345.6789, 6.022e23, 6.626e-34,
    };
    for (size_t k=0;k<sizeof reps/sizeof reps[0];k++) chk(reps[k]);

    /* extremes / specials */
    chk(frombits(0x7FF0000000000000ULL)); /* +inf  */
    chk(frombits(0xFFF0000000000000ULL)); /* -inf  */
    chk(frombits(0x7FF8000000000000ULL)); /* +nan  */
    chk(frombits(0xFFF8000000000000ULL)); /* -nan  */
    chk(frombits(0x0000000000000001ULL)); /* 5e-324 smallest subnormal */
    chk(frombits(0x000FFFFFFFFFFFFFULL)); /* largest subnormal */
    chk(frombits(0x0010000000000000ULL)); /* smallest normal */
    chk(frombits(0x7FEFFFFFFFFFFFFFULL)); /* DBL_MAX */

    /* deterministic full-bit-space sweep (xorshift64) */
    uint64_t st = 0x243F6A8885A308D3ULL;
    for (long n=0;n<2000000;n++) {
        st ^= st<<13; st ^= st>>7; st ^= st<<17;
        chk(frombits(st));
    }
    /* dense small ints + simple decimals (exercise low-p shortest selection) */
    for (int n=-100000;n<=100000;n++) chk((double)n);
    for (int n=1;n<5000;n++){ chk(n/7.0); chk(n/3.0); chk(n*1.0/1000.0); }

    printf("[float_dtoa_shortest] %s — total=%d fails=%d (NATIVE-shortest vs C-shortest byte-id)\n",
           fails ? "FAIL" : "PASS", total, fails);
    return fails ? 1 : 26;
}
