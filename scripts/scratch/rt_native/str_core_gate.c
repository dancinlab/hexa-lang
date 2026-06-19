/* str_core_gate.c — RT-NATIVE-ZEROC M4 str-core scan/compare C-differential gate (c2).
 *
 * Byte-eq oracle for the native public-string scan/compare ports
 * (stdlib/runtime/str_core.hexa::rt_str_eq_native + rt_str_starts_with_native +
 * rt_str_ends_with_native + rt_str_index_of_native + rt_str_contains_native, str
 * r2/r3/r4 sh-str-scan) against the standalone runtime.c C path (hexa_str_eq's
 * hxlcl_strcmp(...)==0 + rt_str_starts_with's hxlcl_strncmp(s,prefix,plen)==0 +
 * rt_str_ends_with's sfxlen<=slen && strcmp(s+slen-sfxlen,suffix)==0 +
 * hexa_str_index_of's strstr-offset/-1 + hexa_str_contains's strstr!=NULL). The
 * compare bodies are single NUL-stop byte walks; index_of/contains are a naive
 * O(n*m) substring search. This gate proves the result is IDENTICAL to the C
 * strcmp/strncmp/strstr oracles for: equal strings, prefix/suffix-differ,
 * length-differ, empty string/needle, mid-difference, single-char, long strings,
 * repeated/overlapping/backtrack-requiring patterns, and UTF-8 multibyte — and
 * that the end-to-end wrappers (compiled with -DHEXA_RT_STR_EQ_NATIVE +
 * -DHEXA_RT_STR_STARTS_WITH_NATIVE + -DHEXA_RT_STR_ENDS_WITH_NATIVE +
 * -DHEXA_RT_STR_INDEX_OF_NATIVE + -DHEXA_RT_STR_CONTAINS_NATIVE) agree with the
 * reference C for the same pairs.
 *
 * NO ALLOC: all five prims are pure raw-byte reads — this is the alloc-free
 * scan/compare surface (concat / substring / replace are the alloc lane's WALL,
 * not exercised here).
 *
 * Build (x86_64 / arm64, native str_core.o + standalone runtime.c):
 *   <aprime_cc> _drv --emit=obj --target=<t> -o str_core.o str_core.hexa
 *   cc -O2 -std=gnu11 -D_GNU_SOURCE -DHEXA_RT_STR_EQ_NATIVE=1 \
 *      -DHEXA_RT_STR_STARTS_WITH_NATIVE=1 -DHEXA_RT_STR_ENDS_WITH_NATIVE=1 \
 *      -DHEXA_RT_STR_INDEX_OF_NATIVE=1 -DHEXA_RT_STR_CONTAINS_NATIVE=1 -I self \
 *      str_core_gate.c self/runtime.c str_core.o -o /tmp/strgate && /tmp/strgate ; echo $?
 *
 * Exit code = 23 on FULL pass (distinct sentinel); 1..N on the first failing
 * check (so a regression is pinpointed). The CI faithful 3-target +
 * selfhost-byteeq-real gates stay AUTHORITATIVE for the whole-compiler fixpoint;
 * this gate is the per-family byte oracle.
 */
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include "runtime.h"

/* native ports (gen2-emitted object): two TAG_STR HexaVals → bool HexaVal. */
extern HexaVal rt_str_eq_native(HexaVal a, HexaVal b);
extern HexaVal rt_str_starts_with_native(HexaVal s, HexaVal prefix);
extern HexaVal rt_str_ends_with_native(HexaVal s, HexaVal suffix);
extern HexaVal rt_str_index_of_native(HexaVal s, HexaVal sub);   /* int offset / -1 */
extern HexaVal rt_str_contains_native(HexaVal s, HexaVal sub);   /* bool */

/* end-to-end C wrappers. */
int hexa_str_eq(HexaVal a, HexaVal b);
int rt_str_starts_with(HexaVal s, HexaVal prefix);
int rt_str_ends_with(HexaVal s, HexaVal suffix);
int64_t hexa_str_index_of(HexaVal s, HexaVal sub);
int hexa_str_contains(HexaVal s, HexaVal sub);

static int fails = 0, checks = 0;
static void chk(int cond, const char* what) {
    checks++;
    if (!cond) { fails++; fprintf(stderr, "[str_core_gate] FAIL: %s\n", what); }
}

/* Reference C oracle: the EXACT semantics the C `#else` body produces for the
 * distinct-pointer path — strcmp(...)==0 over the two NUL-terminated buffers. */
static int c_oracle_eq(const char* a, const char* b) { return strcmp(a, b) == 0; }

/* Drive native rt_str_eq_native + the reference oracle on a string pair and
 * assert agreement. Both args are made into distinct heap HexaVals via hexa_str
 * (so the intern fast-path is irrelevant — we are testing the byte walk). */
static void chk_pair(const char* a, const char* b) {
    HexaVal va = hexa_str(a);
    HexaVal vb = hexa_str(b);
    int nat = hexa_truthy(rt_str_eq_native(va, vb)) ? 1 : 0;
    int ref = c_oracle_eq(a, b);
    char buf[160];
    snprintf(buf, sizeof(buf), "rt_str_eq_native(\"%s\",\"%s\") native=%d ref=%d", a, b, nat, ref);
    chk(nat == ref, buf);
    /* end-to-end wrapper agreement (TAG_STR guard + intern fast-path + native body) */
    int wr = hexa_str_eq(va, vb);
    snprintf(buf, sizeof(buf), "hexa_str_eq(\"%s\",\"%s\") wrapper=%d ref=%d", a, b, wr, ref);
    chk(wr == ref, buf);
}

/* Reference C oracle for starts_with: the EXACT semantics the C `#else` body
 * produces — strncmp(s, prefix, strlen(prefix)) == 0. */
static int c_oracle_sw(const char* s, const char* prefix) {
    return strncmp(s, prefix, strlen(prefix)) == 0;
}

/* Drive native rt_str_starts_with_native + the reference oracle on (s, prefix)
 * and assert agreement, then the end-to-end rt_str_starts_with wrapper. Distinct
 * heap HexaVals via hexa_str. */
static void chk_pair_sw(const char* s, const char* prefix) {
    HexaVal vs = hexa_str(s);
    HexaVal vp = hexa_str(prefix);
    int nat = hexa_truthy(rt_str_starts_with_native(vs, vp)) ? 1 : 0;
    int ref = c_oracle_sw(s, prefix);
    char buf[200];
    snprintf(buf, sizeof(buf), "rt_str_starts_with_native(\"%s\",\"%s\") native=%d ref=%d", s, prefix, nat, ref);
    chk(nat == ref, buf);
    int wr = rt_str_starts_with(vs, vp);
    snprintf(buf, sizeof(buf), "rt_str_starts_with(\"%s\",\"%s\") wrapper=%d ref=%d", s, prefix, wr, ref);
    chk(wr == ref, buf);
}

/* Reference C oracle for ends_with: the EXACT semantics the C `#else` body
 * produces — sfxlen <= slen && strcmp(s + slen - sfxlen, suffix) == 0. */
static int c_oracle_ew(const char* s, const char* suffix) {
    size_t slen = strlen(s), sfxlen = strlen(suffix);
    if (sfxlen > slen) return 0;
    return strcmp(s + slen - sfxlen, suffix) == 0;
}

/* Drive native rt_str_ends_with_native + the reference oracle on (s, suffix) and
 * assert agreement, then the end-to-end rt_str_ends_with wrapper. */
static void chk_pair_ew(const char* s, const char* suffix) {
    HexaVal vs = hexa_str(s);
    HexaVal vx = hexa_str(suffix);
    int nat = hexa_truthy(rt_str_ends_with_native(vs, vx)) ? 1 : 0;
    int ref = c_oracle_ew(s, suffix);
    char buf[200];
    snprintf(buf, sizeof(buf), "rt_str_ends_with_native(\"%s\",\"%s\") native=%d ref=%d", s, suffix, nat, ref);
    chk(nat == ref, buf);
    int wr = rt_str_ends_with(vs, vx);
    snprintf(buf, sizeof(buf), "rt_str_ends_with(\"%s\",\"%s\") wrapper=%d ref=%d", s, suffix, wr, ref);
    chk(wr == ref, buf);
}

/* Reference C oracle for index_of: the EXACT semantics the C `#else` body
 * produces — p = strstr(s, sub); p ? (int64_t)(p - s) : -1. */
static int64_t c_oracle_io(const char* s, const char* sub) {
    const char* p = strstr(s, sub);
    return p ? (int64_t)(p - s) : -1;
}

/* Drive native rt_str_index_of_native (offset/-1) + reference + the end-to-end
 * hexa_str_index_of wrapper. */
static void chk_pair_io(const char* s, const char* sub) {
    HexaVal vs = hexa_str(s);
    HexaVal vn = hexa_str(sub);
    int64_t nat = HX_INT(rt_str_index_of_native(vs, vn));
    int64_t ref = c_oracle_io(s, sub);
    char buf[220];
    snprintf(buf, sizeof(buf), "rt_str_index_of_native(\"%s\",\"%s\") native=%lld ref=%lld", s, sub, (long long)nat, (long long)ref);
    chk(nat == ref, buf);
    int64_t wr = hexa_str_index_of(vs, vn);
    snprintf(buf, sizeof(buf), "hexa_str_index_of(\"%s\",\"%s\") wrapper=%lld ref=%lld", s, sub, (long long)wr, (long long)ref);
    chk(wr == ref, buf);
    /* contains == (index_of >= 0); native bool + C wrapper agree with strstr!=NULL */
    int cnat = hexa_truthy(rt_str_contains_native(vs, vn)) ? 1 : 0;
    int cref = (strstr(s, sub) != NULL) ? 1 : 0;
    snprintf(buf, sizeof(buf), "rt_str_contains_native(\"%s\",\"%s\") native=%d ref=%d", s, sub, cnat, cref);
    chk(cnat == cref, buf);
    int cwr = hexa_str_contains(vs, vn);
    snprintf(buf, sizeof(buf), "hexa_str_contains(\"%s\",\"%s\") wrapper=%d ref=%d", s, sub, cwr, cref);
    chk(cwr == cref, buf);
}

int main(void) {
    /* PART A — layout sanity: the payload word the native body extracts is the
     * data pointer (HX_STR). If sizeof drifts the offset arithmetic is wrong. */
    chk(sizeof(HexaVal) == 16, "sizeof(HexaVal)==16");
    {
        HexaVal s = hexa_str("layout");
        chk(HX_IS_STR(s), "hexa_str yields TAG_STR");
        chk(HX_STR(s) != NULL && strcmp(HX_STR(s), "layout") == 0, "HX_STR roundtrip");
    }

    /* PART B — behaviour oracle: native == reference strcmp across the cases. */
    chk_pair("", "");                       /* both empty → equal */
    chk_pair("a", "");                       /* one empty (length differ) */
    chk_pair("", "a");
    chk_pair("a", "a");                      /* single char equal */
    chk_pair("a", "b");                      /* single char differ */
    chk_pair("hello", "hello");              /* multi equal */
    chk_pair("hello", "hellp");              /* last-byte differ */
    chk_pair("hello", "hell");               /* prefix (length differ) */
    chk_pair("hell", "hello");               /* reverse prefix */
    chk_pair("hexa", "hexb");                /* mid differ */
    chk_pair("HEXA", "hexa");                /* case differ (byte-exact, not folded) */
    chk_pair("abcdefghijklmnopqrstuvwxyz", "abcdefghijklmnopqrstuvwxyz");  /* long equal */
    chk_pair("abcdefghijklmnopqrstuvwxyz", "abcdefghijklmnopqrstuvwxyZ");  /* long last-differ */
    /* embedded-NUL is NOT representable in a hexa_str C-literal, so the C strcmp
     * oracle and the native NUL-stop walk share the same termination semantics —
     * no divergence to test there (both stop at the first 0x00). */
    {
        /* UTF-8 multibyte bytes survive the raw byte walk (compared as raw u8). */
        const char* u1 = "caf\xC3\xA9";   /* café */
        const char* u2 = "caf\xC3\xA9";
        const char* u3 = "caf\xC3\xA8";   /* cafè — last byte differs */
        chk_pair(u1, u2);
        chk_pair(u1, u3);
    }

    /* PART C — starts_with oracle: native == reference strncmp across the cases.
     * Covers empty prefix (always true), empty haystack, prefix==haystack,
     * proper prefix, NON-prefix (first/mid/last byte differs), prefix LONGER than
     * haystack (haystack NUL must abort the walk → false), and UTF-8 bytes. */
    chk_pair_sw("", "");                     /* empty prefix of empty → true */
    chk_pair_sw("hello", "");                /* empty prefix → true */
    chk_pair_sw("", "h");                    /* non-empty prefix of empty → false */
    chk_pair_sw("hello", "hello");           /* whole-string prefix → true */
    chk_pair_sw("hello", "hell");            /* proper prefix → true */
    chk_pair_sw("hello", "he");              /* short proper prefix → true */
    chk_pair_sw("hello", "h");               /* single-char prefix → true */
    chk_pair_sw("hello", "x");               /* first byte differs → false */
    chk_pair_sw("hello", "hxllo");           /* mid byte differs → false */
    chk_pair_sw("hello", "hellp");           /* last prefix byte differs → false */
    chk_pair_sw("hell", "hello");            /* prefix LONGER than haystack → false */
    chk_pair_sw("hello", "hellox");          /* prefix one byte too long → false */
    chk_pair_sw("a", "a");                   /* single equal → true */
    chk_pair_sw("a", "b");                   /* single differ → false */
    chk_pair_sw("abcdefghijklmnopqrstuvwxyz", "abcdefghijklm");  /* long proper prefix → true */
    chk_pair_sw("abcdefghijklmnopqrstuvwxyz", "abcdefghijklM");  /* long prefix last-differ → false */
    {
        const char* hay = "caf\xC3\xA9 latte";   /* "café latte" */
        chk_pair_sw(hay, "caf\xC3\xA9");          /* UTF-8 multibyte prefix → true */
        chk_pair_sw(hay, "caf\xC3\xA8");          /* UTF-8 last-byte differs → false */
        chk_pair_sw(hay, "caf");                  /* ASCII-only prefix → true */
    }

    /* PART D — ends_with oracle: native == reference (sfxlen<=slen && strcmp at
     * tail offset). Covers empty suffix (always true), empty haystack, whole-string
     * suffix, proper suffix, NON-suffix (first/mid/last tail byte differs), suffix
     * LONGER than haystack (length guard → false), and UTF-8 multibyte tail. */
    chk_pair_ew("", "");                     /* empty suffix of empty → true */
    chk_pair_ew("hello", "");                /* empty suffix → true */
    chk_pair_ew("", "o");                    /* non-empty suffix of empty → false */
    chk_pair_ew("hello", "hello");           /* whole-string suffix → true */
    chk_pair_ew("hello", "llo");             /* proper suffix → true */
    chk_pair_ew("hello", "lo");              /* short proper suffix → true */
    chk_pair_ew("hello", "o");               /* single-char suffix → true */
    chk_pair_ew("hello", "x");               /* last byte differs → false */
    chk_pair_ew("hello", "xlo");             /* tail mid byte differs → false */
    chk_pair_ew("hello", "allo");            /* tail first byte differs → false */
    chk_pair_ew("hello", "hhello");          /* suffix LONGER than haystack → false */
    chk_pair_ew("llo", "hello");             /* suffix longer (2nd form) → false */
    chk_pair_ew("a", "a");                   /* single equal → true */
    chk_pair_ew("a", "b");                   /* single differ → false */
    chk_pair_ew("ababab", "abab");           /* repeated-pattern proper suffix → true */
    chk_pair_ew("ababab", "babab");          /* off-by-one repeated pattern → true */
    chk_pair_ew("abcdefghijklmnopqrstuvwxyz", "nopqrstuvwxyz");  /* long proper suffix → true */
    chk_pair_ew("abcdefghijklmnopqrstuvwxyz", "Nopqrstuvwxyz");  /* long suffix first-tail-differ → false */
    {
        const char* hay = "latte caf\xC3\xA9";   /* "latte café" */
        chk_pair_ew(hay, "caf\xC3\xA9");          /* UTF-8 multibyte suffix → true */
        chk_pair_ew(hay, "caf\xC3\xA8");          /* UTF-8 last-byte differs → false */
        chk_pair_ew(hay, "\xC3\xA9");             /* UTF-8 continuation-byte tail → true */
    }

    /* PART E — index_of / contains oracle: native == reference strstr offset (-1
     * if absent) + contains == (strstr != NULL). Covers empty needle (offset 0),
     * empty haystack, match at start/mid/end, absent, needle-longer-than-haystack,
     * first occurrence among repeats (overlap), single char, full-string, and
     * UTF-8 multibyte needle. */
    chk_pair_io("", "");                     /* empty needle in empty → 0 */
    chk_pair_io("hello", "");                /* empty needle → 0 */
    chk_pair_io("", "h");                    /* needle in empty haystack → -1 */
    chk_pair_io("hello", "h");               /* match at start → 0 */
    chk_pair_io("hello", "hello");           /* full-string match → 0 */
    chk_pair_io("hello", "ll");              /* match mid → 2 */
    chk_pair_io("hello", "o");               /* match at end → 4 */
    chk_pair_io("hello", "lo");              /* two-byte tail match → 3 */
    chk_pair_io("hello", "z");               /* absent single → -1 */
    chk_pair_io("hello", "xyz");             /* absent multi → -1 */
    chk_pair_io("hi", "hello");              /* needle LONGER than haystack → -1 */
    chk_pair_io("ababab", "ab");             /* first of repeated → 0 */
    chk_pair_io("ababab", "ba");             /* first ba → 1 */
    chk_pair_io("aaaa", "aa");               /* overlapping repeat, first → 0 */
    chk_pair_io("abcabcabd", "abcabd");      /* backtrack-requiring naive match → 3 */
    chk_pair_io("mississippi", "issip");     /* classic near-miss before match → 4 */
    chk_pair_io("mississippi", "issis");     /* match at 1 (the only one) → 1 */
    chk_pair_io("a", "a");                   /* single equal → 0 */
    chk_pair_io("a", "b");                   /* single differ → -1 */
    chk_pair_io("abcdefghijklmnopqrstuvwxyz", "mno");  /* long haystack mid → 12 */
    {
        const char* hay = "caf\xC3\xA9 latte";   /* "café latte" */
        chk_pair_io(hay, "\xC3\xA9");             /* UTF-8 continuation byte → offset 3 */
        chk_pair_io(hay, "latte");                /* ASCII needle after UTF-8 → 5 */
        chk_pair_io(hay, "\xC3\xA8");             /* absent UTF-8 byte → -1 */
    }

    if (fails == 0) printf("[str_core_gate] GATE PASS — %d checks, 0 fails\n", checks);
    else            printf("[str_core_gate] GATE FAIL — %d checks, %d fails\n", checks, fails);
    return fails ? 1 : 23;
}
