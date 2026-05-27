/* test/native_build/poc_hxlcl_leaves_caller.c
 *
 * F3 ACTIVATION RUNBOOK · Path A · correctness oracle for the batch of
 * hexa-emitted leaf primitives (rt_str_len / rt_memcmp / rt_memcpy /
 * rt_memmove / rt_strcmp / rt_strncmp / rt_strchr / rt_strrchr / rt_strcpy /
 * rt_strncpy / rt_strcat), each produced by its emit_hxlcl_<name>_o.hexa.
 *
 * Declares the runtime's hxlcl_* symbols as external and asserts each behaves
 * identically to libc (used here ONLY as the ground-truth oracle — the symbols
 * under test are the hexa-emitted bytes, NOT libc). Both the returned value AND
 * the written bytes are checked.
 *
 * Link (per-symbol .o ahead-linked):
 *   clang poc_hxlcl_leaves_caller.c hxlcl_*.o -o run
 * Run:
 *   ./run ; echo "rc=$?"     -> rc=0 on all-pass, nonzero on first failure
 */

#include <stddef.h>
#include <stdio.h>
#include <string.h>   /* libc oracle only */

extern size_t      hxlcl_strlen(const char *s);
extern int         hxlcl_memcmp(const void *a, const void *b, size_t n);
extern void       *hxlcl_memcpy(void *dst, const void *src, size_t n);
extern void       *hxlcl_memmove(void *dst, const void *src, size_t n);
extern int         hxlcl_strcmp(const char *a, const char *b);
extern int         hxlcl_strncmp(const char *a, const char *b, size_t n);
extern const char *hxlcl_strchr(const char *s, int c);
extern const char *hxlcl_strrchr(const char *s, int c);
extern char       *hxlcl_strcpy(char *dst, const char *src);
extern char       *hxlcl_strncpy(char *dst, const char *src, size_t n);
extern char       *hxlcl_strcat(char *dst, const char *src);

static int fail(const char *what) { fprintf(stderr, "FAIL: %s\n", what); return 1; }
/* sign-normalize int compares: memcmp/strcmp only need same sign as libc */
static int sgn(int x) { return (x > 0) - (x < 0); }

int main(void) {
    char buf[64], buf2[64];

    /* ── strlen ── */
    if (hxlcl_strlen("") != 0)            return fail("strlen empty");
    if (hxlcl_strlen("hello") != 5)       return fail("strlen hello");
    if (hxlcl_strlen("abcdefghij") != 10) return fail("strlen 10");

    /* ── memcmp (sign-compare to libc) ── */
    if (sgn(hxlcl_memcmp("abc", "abc", 3)) != sgn(memcmp("abc","abc",3))) return fail("memcmp eq");
    if (sgn(hxlcl_memcmp("abc", "abd", 3)) != sgn(memcmp("abc","abd",3))) return fail("memcmp lt");
    if (sgn(hxlcl_memcmp("abd", "abc", 3)) != sgn(memcmp("abd","abc",3))) return fail("memcmp gt");
    if (hxlcl_memcmp("abc", "xyz", 0) != 0) return fail("memcmp zero-len");

    /* ── memcpy ── */
    for (int i = 0; i < 64; i++) buf[i] = 0x11;
    void *r = hxlcl_memcpy(buf, "ABCDEFGH", 8);
    if (r != (void*)buf)              return fail("memcpy ret != dst");
    if (memcmp(buf, "ABCDEFGH", 8))   return fail("memcpy bytes");
    if (buf[8] != 0x11)               return fail("memcpy overran");

    /* ── memmove (overlap: shift right by 2) ── */
    memcpy(buf, "0123456789", 10);
    hxlcl_memmove(buf + 2, buf, 8);   /* -> "010123456789"[..] */
    if (memcmp(buf, "01", 2) || memcmp(buf + 2, "01234567", 8)) return fail("memmove overlap-right");
    /* memmove overlap: shift left by 2 */
    memcpy(buf, "0123456789", 10);
    hxlcl_memmove(buf, buf + 2, 8);   /* -> "234567896789" */
    if (memcmp(buf, "23456789", 8))   return fail("memmove overlap-left");
    /* memmove dst==src (no-op) */
    memcpy(buf, "stable", 7);
    if (hxlcl_memmove(buf, buf, 7) != (void*)buf || memcmp(buf, "stable", 7)) return fail("memmove d==s");

    /* ── strcmp (sign-compare) ── */
    if (sgn(hxlcl_strcmp("foo", "foo"))   != sgn(strcmp("foo","foo")))   return fail("strcmp eq");
    if (sgn(hxlcl_strcmp("foo", "fop"))   != sgn(strcmp("foo","fop")))   return fail("strcmp lt");
    if (sgn(hxlcl_strcmp("foox", "foo"))  != sgn(strcmp("foox","foo")))  return fail("strcmp prefix");

    /* ── strncmp (sign-compare) ── */
    if (sgn(hxlcl_strncmp("foobar","foobaz",5)) != sgn(strncmp("foobar","foobaz",5))) return fail("strncmp bound-eq");
    if (sgn(hxlcl_strncmp("foobar","foobaz",6)) != sgn(strncmp("foobar","foobaz",6))) return fail("strncmp diff");
    if (hxlcl_strncmp("abc","xyz",0) != 0) return fail("strncmp zero");

    /* ── strchr ── */
    const char *s = "hello.world";
    if (hxlcl_strchr(s, '.') != strchr(s, '.')) return fail("strchr found");
    if (hxlcl_strchr(s, 'z') != NULL)           return fail("strchr notfound");
    if (hxlcl_strchr(s, '\0') != s + 11)        return fail("strchr NUL");

    /* ── strrchr ── */
    const char *p = "a/b/c/d";
    if (hxlcl_strrchr(p, '/') != strrchr(p, '/')) return fail("strrchr last");
    if (hxlcl_strrchr(p, 'z') != NULL)            return fail("strrchr notfound");

    /* ── strcpy ── */
    for (int i = 0; i < 64; i++) buf[i] = 0x55;
    char *rc = hxlcl_strcpy(buf, "copied!");
    if (rc != buf || strcmp(buf, "copied!"))  return fail("strcpy");
    if (buf[7] != '\0')                        return fail("strcpy NUL term");

    /* ── strncpy (incl NUL-pad) ── */
    memset(buf, 0x33, 64); memset(buf2, 0x33, 64);
    hxlcl_strncpy(buf, "hi", 6); strncpy(buf2, "hi", 6);
    if (memcmp(buf, buf2, 6)) return fail("strncpy pad");
    memset(buf, 0x33, 64); memset(buf2, 0x33, 64);
    hxlcl_strncpy(buf, "toolongstring", 4); strncpy(buf2, "toolongstring", 4);
    if (memcmp(buf, buf2, 4)) return fail("strncpy truncate");

    /* ── strcat ── */
    strcpy(buf, "foo");
    char *ra = hxlcl_strcat(buf, "bar");
    if (ra != buf || strcmp(buf, "foobar")) return fail("strcat");

    printf("ALL CHECKS PASS — 11 hexa-emit leaf primitives behave as libc\n");
    return 0;
}
