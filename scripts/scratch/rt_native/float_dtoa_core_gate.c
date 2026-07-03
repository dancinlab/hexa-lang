/* float_dtoa_core_gate.c — zero-c float-dtoa keystone C-differential gate.
 * @state-ok: sibling of scripts/scratch/rt_native/num_float_core_gate.c (the
 *   established RT-NATIVE C-differential gate home; tooling, not work output).
 *
 * Byte-eq oracle for the native f64->string FORMAT port
 * (stdlib/runtime/num_float_core.hexa::rt_format_float_native) against libc
 * snprintf("%.17g", d) — the IEEE-correctly-rounded shortest-17-sig reference.
 * Mirror of num_float_core_gate.c (the PARSE-half twin).
 *
 * rt_format_float_native is a pure-i64 port of musl fmt_fp (%g): mantissa is
 * extracted via float_to_bits, carried into base-1e9 limbs, shifted by 2^e2 with
 * musl's exact integer mul/div loops, rounded round-half-to-EVEN, %g-selected,
 * trailing-zero-trimmed, and emitted in e/f style. NO float arithmetic in the
 * core => identical across x86_64-linux / arm64-linux / darwin-arm64.
 *
 * The native body MUST equal snprintf("%.17g", d) byte-for-byte for EVERY finite
 * double, plus glibc's lowercase "inf"/"nan" (sign-aware) for the specials.
 *
 * Build (opt-in; needs the native formatter compiled + the hexa runtime):
 *   aprime_cc _drv.hexa --emit=obj --target=x86_64-linux-gnu \
 *       -o num_float_core.o stdlib/runtime/num_float_core.hexa
 *   clang -O2 -std=gnu11 float_dtoa_core_gate.c num_float_core.o \
 *       ~/.hx/bin/build/runtime.a -lm -o g && ./g
 * Exit 26 = full pass (every case byte-exact). 1 = a mismatch.
 */
#include <stdio.h>
#include <stdint.h>
#include <string.h>

typedef enum { TAG_INT=0, TAG_FLOAT, TAG_BOOL, TAG_STR, TAG_VOID } HexaTag;
typedef struct HexaVal_ { HexaTag tag; union { int64_t i; double f; char* s; void* p; }; } HexaVal;
#define HX_STR(v) ((v).s)

extern HexaVal rt_format_float_native(HexaVal v, HexaVal sig);

static int fails = 0, total = 0;

static HexaVal hxf(double d){ HexaVal v; v.tag=TAG_FLOAT; v.f=d; return v; }
static HexaVal hxi(int64_t n){ HexaVal v; v.tag=TAG_INT; v.i=n; return v; }
static double frombits(uint64_t u){ double d; memcpy(&d,&u,8); return d; }

static void chk(double d) {
    char ref[64];
    snprintf(ref, sizeof ref, "%.17g", d);
    HexaVal r = rt_format_float_native(hxf(d), hxi(17));
    total++;
    const char* nat = (r.tag == TAG_STR) ? HX_STR(r) : "<not-str>";
    if (!nat) nat = "<null>";
    if (strcmp(nat, ref)) {
        fails++;
        if (fails <= 40) {
            uint64_t u; memcpy(&u,&d,8);
            fprintf(stderr, "[float_dtoa_gate] MISMATCH bits=0x%016llx native=\"%s\" glibc=\"%s\"\n",
                    (unsigned long long)u, nat, ref);
        }
    }
}

int main(void) {
    if (sizeof(HexaVal) != 16) { fprintf(stderr,"sizeof(HexaVal)!=16\n"); return 2; }

    /* representative doubles (design §5) */
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
    chk(frombits(0x7FF0000000000000ULL)); /* +inf  -> "inf"  */
    chk(frombits(0xFFF0000000000000ULL)); /* -inf  -> "-inf" */
    chk(frombits(0x7FF8000000000000ULL)); /* +nan  -> "nan"  */
    chk(frombits(0xFFF8000000000000ULL)); /* -nan  -> "-nan" */
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
    /* dense small ints + simple decimals */
    for (int n=-100000;n<=100000;n++) chk((double)n);
    for (int n=1;n<5000;n++){ chk(n/7.0); chk(n/3.0); chk(n*1.0/1000.0); }

    printf("[float_dtoa_gate] %s — total=%d fails=%d (byte-exact vs snprintf %%.17g)\n",
           fails ? "FAIL" : "PASS", total, fails);
    return fails ? 1 : 26;
}
