/* num_core_gate.c — RT-NATIVE-ZEROC M4 num-core parse C-differential gate (c2).
 *
 * Byte-eq oracle for the native string→int parse port
 * (stdlib/runtime/num_core.hexa::rt_parse_int_native) against the standalone
 * runtime.c C path (hexa_as_num's string-coercion arm, which is
 * `strtoll(cs, NULL, base)` with base auto-detected from a post-sign 0x prefix).
 * The native body does the SAME scan in raw memory (__hx_ptr_load8 byte walk +
 * base-N digit fold + strtoll-faithful overflow clamp); this gate proves the
 * int64 result is IDENTICAL to the C oracle for:
 *   - 0, positive, negative
 *   - leading whitespace + sign
 *   - leading zeros
 *   - 0x / 0X hex (incl negative hex)
 *   - empty / garbage / trailing garbage (strtoll stops at first non-digit)
 *   - INT64_MAX / INT64_MIN exact
 *   - positive overflow (clamp → INT64_MAX) + negative overflow (→ INT64_MIN)
 *   - hex overflow edges
 * and that the end-to-end hexa_as_num wrapper (compiled with
 * -DHEXA_RT_NUM_PARSE_INT_NATIVE) agrees with the reference C strtoll for the
 * same inputs.
 *
 * NO ALLOC: rt_parse_int_native is pure raw-byte read + register accumulate —
 * this is the alloc-free PARSE surface (int→str FORMAT with its strbuf_alloc is
 * the array-write lane class, not exercised here).
 *
 * REFERENCE ORACLE: the EXACT semantics the C `#else` body produces —
 * base = (post-sign "0x"/"0X") ? 16 : 10, then strtoll(cs, NULL, base). libc
 * strtoll shares the C99 clamp-on-overflow semantics the floor's hxlcl_strtoll
 * (and the native port) implement, so it is a faithful stand-in oracle.
 *
 * Build (x86_64 / arm64, native num_core.o + standalone runtime.c):
 *   <aprime_cc> _drv --emit=obj --target=<t> -o num_core.o num_core.hexa
 *   cc -O2 -std=gnu11 -D_GNU_SOURCE -DHEXA_RT_NUM_PARSE_INT_NATIVE=1 -I self \
 *      num_core_gate.c self/runtime.c num_core.o -o /tmp/numgate && /tmp/numgate ; echo $?
 *
 * Exit code = 24 on FULL pass (distinct sentinel, != str gate's 23); 1 on any
 * fail. The CI faithful 3-target + selfhost-byteeq-real gates stay AUTHORITATIVE
 * for the whole-compiler fixpoint; this gate is the per-family byte oracle.
 */
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <stdlib.h>
#include "runtime.h"

/* native port (gen2-emitted object): TAG_STR HexaVal → TAG_INT HexaVal. */
extern HexaVal rt_parse_int_native(HexaVal s);

/* end-to-end C wrapper (string-coercion path delegates to the native body). */
int64_t hexa_as_num(HexaVal v);

static int fails = 0, checks = 0;
static void chk(int cond, const char* what) {
    checks++;
    if (!cond) { fails++; fprintf(stderr, "[num_core_gate] FAIL: %s\n", what); }
}

/* Reference C oracle: the EXACT semantics the C `#else` body produces —
 * post-sign 0x detect → base, then strtoll over the FULL string. */
static int64_t c_oracle_parse(const char* cs) {
    const char* p = cs;
    if (*p == '+' || *p == '-') p++;
    int base = (p[0] == '0' && (p[1] == 'x' || p[1] == 'X')) ? 16 : 10;
    return strtoll(cs, NULL, base);
}

/* Drive the native body (via a non-owning TAG_STR borrow box, exactly as the
 * runtime thunk constructs it) + the reference oracle on a string and assert
 * agreement; also assert the end-to-end hexa_as_num wrapper agrees. */
static void chk_one(const char* cs) {
    HexaVal sv = (HexaVal){ .tag = TAG_STR, .s = (char*)cs };
    int64_t nat = HX_INT(rt_parse_int_native(sv));
    int64_t ref = c_oracle_parse(cs);
    char buf[200];
    snprintf(buf, sizeof(buf), "rt_parse_int_native(\"%s\") native=%lld ref=%lld",
             cs, (long long)nat, (long long)ref);
    chk(nat == ref, buf);
    /* end-to-end wrapper agreement (TAG_STR guard + native body). */
    HexaVal wv = hexa_str(cs);
    int64_t wr = hexa_as_num(wv);
    snprintf(buf, sizeof(buf), "hexa_as_num(\"%s\") wrapper=%lld ref=%lld",
             cs, (long long)wr, (long long)ref);
    chk(wr == ref, buf);
}

int main(void) {
    /* PART A — layout sanity: the payload word the native body extracts is the
     * data pointer (HX_STR). If sizeof drifts the offset arithmetic is wrong. */
    chk(sizeof(HexaVal) == 16, "sizeof(HexaVal)==16");
    {
        HexaVal s = hexa_str("12345");
        chk(HX_IS_STR(s), "hexa_str yields TAG_STR");
        chk(HX_STR(s) != NULL && strcmp(HX_STR(s), "12345") == 0, "HX_STR roundtrip");
    }

    /* PART B — behaviour oracle: native == reference strtoll across the cases. */
    chk_one("0");
    chk_one("1");
    chk_one("42");
    chk_one("-1");
    chk_one("-42");
    chk_one("+7");
    chk_one("007");                       /* leading zeros — decimal, NOT octal */
    chk_one("000");
    chk_one("   123");                     /* leading whitespace */
    chk_one("\t\n 99");                    /* tab/newline whitespace */
    chk_one("  -50");
    chk_one("123abc");                     /* trailing garbage — strtoll stops at 'a' */
    chk_one("  +12 34");                   /* trailing space + digits */
    chk_one("");                           /* empty → 0 */
    chk_one("   ");                        /* whitespace only → 0 */
    chk_one("abc");                        /* garbage → 0 */
    chk_one("-");                          /* lone sign → 0 */
    chk_one("+");
    chk_one("z123");                       /* non-digit lead → 0 */

    /* hex */
    chk_one("0x10");
    chk_one("0X1F");
    chk_one("0xabcdef");
    chk_one("0xABCDEF");
    chk_one("-0x10");
    chk_one("+0xFF");
    chk_one("0x");                         /* prefix only → 0 (no hex digits) */
    chk_one("0xg");                        /* prefix then non-hex → 0 */
    chk_one("0x7fffffffffffffff");         /* hex INT64_MAX */
    chk_one("-0x8000000000000000");        /* hex INT64_MIN */

    /* exact bounds */
    chk_one("9223372036854775807");        /* INT64_MAX */
    chk_one("-9223372036854775808");       /* INT64_MIN */

    /* overflow (clamp) edges */
    chk_one("9223372036854775808");        /* MAX+1 → clamp INT64_MAX */
    chk_one("9999999999999999999");        /* far over → INT64_MAX */
    chk_one("-9223372036854775809");       /* MIN-1 → clamp INT64_MIN */
    chk_one("-9999999999999999999");       /* far under → INT64_MIN */
    chk_one("0xFFFFFFFFFFFFFFFF");         /* hex over (u64 max) → clamp */
    chk_one("99999999999999999999999999"); /* huge → INT64_MAX */
    chk_one("-99999999999999999999999999");/* huge neg → INT64_MIN */

    if (fails == 0) printf("[num_core_gate] GATE PASS — %d checks, 0 fails\n", checks);
    else            printf("[num_core_gate] GATE FAIL — %d checks, %d fails\n", checks, fails);
    return fails ? 1 : 24;
}
