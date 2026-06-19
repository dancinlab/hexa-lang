/* str_core_gate.c — RT-NATIVE-ZEROC M4 str-core scan/compare C-differential gate (c2).
 *
 * Byte-eq oracle for the native public-string scan/compare ports
 * (stdlib/runtime/str_core.hexa::rt_str_eq_native + rt_str_starts_with_native +
 * rt_str_ends_with_native, str r2/r3 sh-str-scan) against the standalone runtime.c
 * C path (hexa_str_eq's hxlcl_strcmp(...)==0 + rt_str_starts_with's
 * hxlcl_strncmp(s,prefix,plen)==0 + rt_str_ends_with's
 * sfxlen<=slen && strcmp(s+slen-sfxlen,suffix)==0). Each native body does the SAME
 * NUL-terminated byte walk in raw memory (__hx_ptr_load8 over each data pointer);
 * this gate proves the bool result is IDENTICAL to the C strcmp/strncmp oracles
 * for: equal strings, prefix/suffix-differ, length-differ, the empty string,
 * embedded-mid-difference, single-char, long strings, and UTF-8 multibyte — and
 * that the end-to-end wrappers (compiled with -DHEXA_RT_STR_EQ_NATIVE +
 * -DHEXA_RT_STR_STARTS_WITH_NATIVE + -DHEXA_RT_STR_ENDS_WITH_NATIVE) agree with the
 * reference C for the same pairs.
 *
 * NO ALLOC: all three prims are pure raw-byte reads — this is the alloc-free
 * scan/compare surface (concat / substring / replace are the alloc lane's WALL,
 * not exercised here).
 *
 * Build (x86_64 / arm64, native str_core.o + standalone runtime.c):
 *   <aprime_cc> _drv --emit=obj --target=<t> -o str_core.o str_core.hexa
 *   cc -O2 -std=gnu11 -D_GNU_SOURCE -DHEXA_RT_STR_EQ_NATIVE=1 \
 *      -DHEXA_RT_STR_STARTS_WITH_NATIVE=1 -DHEXA_RT_STR_ENDS_WITH_NATIVE=1 -I self \
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

/* end-to-end C wrappers (return int 0/1). */
int hexa_str_eq(HexaVal a, HexaVal b);
int rt_str_starts_with(HexaVal s, HexaVal prefix);
int rt_str_ends_with(HexaVal s, HexaVal suffix);

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

    if (fails == 0) printf("[str_core_gate] GATE PASS — %d checks, 0 fails\n", checks);
    else            printf("[str_core_gate] GATE FAIL — %d checks, %d fails\n", checks, fails);
    return fails ? 1 : 23;
}
