// RT-NATIVE leg B Z2c — C-differential gate for the string-search predicate group.
// Links the native rt_hi seed (or runtime.a) and exercises the three bool-returning
// predicates rt_str_starts_with_b / rt_str_ends_with_b / rt_str_contains_b through
// the HexaVal ABI, comparing each result against the expected boolean (which is
// itself the OLD C-body semantics: strncmp prefix / strcmp suffix / strstr).
// PASS == every case matches; the program prints a per-case line + a summary and
// exits non-zero on any mismatch (HARD gate, no tune-to-green).
#include <stdio.h>
typedef struct { long tag; long u; } HexaVal;
extern HexaVal hexa_str(const char*);
extern int hexa_truthy(HexaVal);
extern HexaVal rt_str_starts_with_b(HexaVal, HexaVal);
extern HexaVal rt_str_ends_with_b(HexaVal, HexaVal);
extern HexaVal rt_str_contains_b(HexaVal, HexaVal);

static int g_pass = 0, g_fail = 0;

static void chk(const char* op, int got, int exp, const char* a, const char* b) {
    int ok = (got != 0) == (exp != 0);
    printf("%-12s(%-8s,%-8s) = %d  exp %d  %s\n", op, a, b, got, exp, ok ? "OK" : "MISMATCH");
    if (ok) g_pass++; else g_fail++;
}

#define SW(a,b,e) chk("starts_with", hexa_truthy(rt_str_starts_with_b(hexa_str(a),hexa_str(b))), e, a, b)
#define EW(a,b,e) chk("ends_with",   hexa_truthy(rt_str_ends_with_b(hexa_str(a),hexa_str(b))),   e, a, b)
#define CT(a,b,e) chk("contains",    hexa_truthy(rt_str_contains_b(hexa_str(a),hexa_str(b))),    e, a, b)

int main(void) {
    // starts_with_b: strncmp(s, prefix, plen) == 0
    SW("hello", "he", 1);
    SW("hello", "lo", 0);
    SW("hi",    "hello", 0);   // prefix longer than s
    SW("hello", "", 1);        // empty prefix
    SW("",      "", 1);        // both empty
    SW("hello", "hello", 1);   // exact

    // ends_with_b: tail strcmp
    EW("hello", "lo", 1);
    EW("hello", "he", 0);
    EW("hi",    "hello", 0);   // suffix longer than s
    EW("hello", "", 1);        // empty suffix
    EW("hello", "hello", 1);   // exact

    // contains_b: strstr != NULL semantics
    CT("hello", "ell", 1);
    CT("hello", "xyz", 0);
    CT("hello", "", 1);        // empty needle (strstr returns hay)
    CT("hello", "hello", 1);   // full
    CT("ab",    "abc", 0);     // needle longer than hay
    CT("hello", "he", 1);      // prefix-as-substring
    CT("hello", "lo", 1);      // suffix-as-substring

    printf("===== SEARCH-PREDICATE GATE: %d/%d match, %d mismatch =====\n",
           g_pass, g_pass + g_fail, g_fail);
    return g_fail == 0 ? 0 : 1;
}
