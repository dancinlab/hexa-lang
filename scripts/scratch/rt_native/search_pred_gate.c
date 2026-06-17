// RT-NATIVE leg B Z2c — C-differential gate for the string-search predicate
// group (rt_str_starts_with_b / rt_str_ends_with_b / rt_str_contains_b).
//
// These 3 predicates moved from the C runtime (stdlib/runtime/ctype.hexa)
// into the native-seed SSOT (self/runtime_hi.hexa, fn 12-14). This harness
// links the rt_str_*_b symbols (from build/runtime.a, the hexa-source rt_*
// layer compiled via runtime_hi_gen.c) and calls them through the HexaVal
// ABI, asserting each result against the OLD C semantics it replaced.
//
// Build (linux x86_64, on aiden):
//   clang scripts/scratch/rt_native/search_pred_gate.c build/runtime.a -lm \
//     -o /tmp/search_pred_gate && /tmp/search_pred_gate
//
// PASS criterion: every case matches expected; exit 0 iff fail_count == 0.
#include <stdio.h>

// Mirror the runtime HexaVal layout (tag + payload union). bool lives in the
// same 8-byte payload slot as the string pointer; reading `.u` as the bool is
// ABI-safe (TAG_BOOL stores the 0/1 in the union's first 8 bytes).
typedef struct { long tag; long u; } HexaVal;
enum { TAG_INT = 0, TAG_FLOAT, TAG_BOOL, TAG_STR, TAG_VOID };

extern HexaVal hexa_str(const char*);
extern HexaVal hexa_int(long);
extern HexaVal rt_str_starts_with_b(HexaVal, HexaVal);
extern HexaVal rt_str_ends_with_b(HexaVal, HexaVal);
extern HexaVal rt_str_contains_b(HexaVal, HexaVal);

static int fail_count = 0;
static int total = 0;

static int B(HexaVal v) { return (int)v.u; }  // bool payload

static void chk(const char* name, int got, int exp) {
    total++;
    const char* mark = (got == exp) ? "ok  " : "FAIL";
    if (got != exp) fail_count++;
    printf("  [%s] %-44s got=%d exp=%d\n", mark, name, got, exp);
}

int main(void) {
    printf("-- RT-NATIVE Z2c search-predicate C-differential gate --\n");

    // rt_str_starts_with_b
    chk("starts_with(hello,he)",   B(rt_str_starts_with_b(hexa_str("hello"), hexa_str("he"))),    1);
    chk("starts_with(hello,lo)",   B(rt_str_starts_with_b(hexa_str("hello"), hexa_str("lo"))),    0);
    chk("starts_with(hi,hello)",   B(rt_str_starts_with_b(hexa_str("hi"),    hexa_str("hello"))), 0);
    chk("starts_with(empty,empty)",B(rt_str_starts_with_b(hexa_str(""),      hexa_str(""))),      1);
    chk("starts_with(abc,empty)",  B(rt_str_starts_with_b(hexa_str("abc"),   hexa_str(""))),      1);

    // rt_str_ends_with_b
    chk("ends_with(hello,lo)",     B(rt_str_ends_with_b(hexa_str("hello"), hexa_str("lo"))),    1);
    chk("ends_with(hello,he)",     B(rt_str_ends_with_b(hexa_str("hello"), hexa_str("he"))),    0);
    chk("ends_with(hi,hello)",     B(rt_str_ends_with_b(hexa_str("hi"),    hexa_str("hello"))), 0);
    chk("ends_with(abc,empty)",    B(rt_str_ends_with_b(hexa_str("abc"),   hexa_str(""))),      1);

    // rt_str_contains_b
    chk("contains(hello,ell)",     B(rt_str_contains_b(hexa_str("hello"), hexa_str("ell"))),   1);
    chk("contains(hello,xyz)",     B(rt_str_contains_b(hexa_str("hello"), hexa_str("xyz"))),   0);
    chk("contains(hello,empty)",   B(rt_str_contains_b(hexa_str("hello"), hexa_str(""))),      1);
    chk("contains(hello,hello)",   B(rt_str_contains_b(hexa_str("hello"), hexa_str("hello"))), 1);
    chk("contains(ab,abc)",        B(rt_str_contains_b(hexa_str("ab"),    hexa_str("abc"))),   0);

    printf("-------------------------------------------------------\n");
    printf("%s -- %d/%d pass, %d fail\n",
           fail_count == 0 ? "PASS" : "FAIL", total - fail_count, total, fail_count);
    return fail_count == 0 ? 0 : 1;
}
