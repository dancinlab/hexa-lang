/* num_core_micro.c — isolated byte-eq micro-oracle for rt_parse_int_native.
 *
 * Standalone: links ONLY the native num_core.o + libc strtoll (NO runtime.a),
 * so the verdict is unaffected by sibling stale seeds (map/array). Defines the
 * minimal HexaVal layout + a non-owning hexa_str borrow box matching the runtime
 * thunk. Proves rt_parse_int_native == strtoll(cs,NULL,base) (post-sign-0x base
 * detect) over the full edge set incl INT64_MIN/MAX + overflow clamp.
 *
 * Build: clang -O2 -std=gnu11 num_core_micro.c num_core.o -o micro && ./micro; echo $?
 * Exit 24 = full pass.
 */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

/* minimal HexaVal mirror (layout from self/runtime.h: tag then union; .i / .s). */
typedef enum { TAG_INT = 0, TAG_FLOAT, TAG_BOOL, TAG_STR, TAG_VOID } HexaTag;
typedef struct HexaVal_ {
    HexaTag tag;
    union { int64_t i; double f; int b; char* s; void* p; };
} HexaVal;
#define HX_INT(v) ((v).i)

extern HexaVal rt_parse_int_native(HexaVal s);

static int fails = 0, checks = 0;
static void chk(int cond, const char* what) {
    checks++;
    if (!cond) { fails++; fprintf(stderr, "[num_micro] FAIL: %s\n", what); }
}

static int64_t c_oracle(const char* cs) {
    const char* p = cs;
    if (*p == '+' || *p == '-') p++;
    int base = (p[0] == '0' && (p[1] == 'x' || p[1] == 'X')) ? 16 : 10;
    return strtoll(cs, NULL, base);
}

static void one(const char* cs) {
    HexaVal sv = (HexaVal){ .tag = TAG_STR, .s = (char*)cs };
    int64_t nat = HX_INT(rt_parse_int_native(sv));
    int64_t ref = c_oracle(cs);
    char buf[200];
    snprintf(buf, sizeof(buf), "parse(\"%s\") native=%lld ref=%lld", cs,
             (long long)nat, (long long)ref);
    chk(nat == ref, buf);
}

int main(void) {
    chk(sizeof(HexaVal) == 16, "sizeof(HexaVal)==16");
    one("0"); one("1"); one("42"); one("-1"); one("-42"); one("+7");
    one("007"); one("000");
    one("   123"); one("\t\n 99"); one("  -50");
    one("123abc"); one("  +12 34");
    one(""); one("   "); one("abc"); one("-"); one("+"); one("z123");
    one("0x10"); one("0X1F"); one("0xabcdef"); one("0xABCDEF");
    one("-0x10"); one("+0xFF"); one("0x"); one("0xg");
    one("0x7fffffffffffffff"); one("-0x8000000000000000");
    one("9223372036854775807");   /* INT64_MAX */
    one("-9223372036854775808");  /* INT64_MIN */
    one("9223372036854775808");   /* MAX+1 -> clamp MAX */
    one("9999999999999999999");
    one("-9223372036854775809");  /* MIN-1 -> clamp MIN */
    one("-9999999999999999999");
    one("0xFFFFFFFFFFFFFFFF");
    one("99999999999999999999999999");
    one("-99999999999999999999999999");
    if (fails == 0) printf("[num_micro] PASS — %d checks, 0 fails\n", checks);
    else            printf("[num_micro] FAIL — %d checks, %d fails\n", checks, fails);
    return fails ? 1 : 24;
}
