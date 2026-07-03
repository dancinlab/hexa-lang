/* intern_core_gate.c — RT-NATIVE-ZEROC M4 intern-core READ-half C-differential gate (c2).
 *
 * Byte-eq oracle for the native string-intern LOOKUP port
 * (stdlib/runtime/intern_core.hexa::rt_intern_find_native) against a C reference
 * that mirrors hexa_intern's lookup loop exactly: an open-addressing walk over a
 * char** bucket array + a parallel uint32_t hash array (the HexaInternTable
 * layout), strcmp on hash-equal, returning the canonical bucket pointer on hit or
 * NULL at the first empty slot. hexa_intern itself is `static` (file-local in
 * runtime.c) so it can't be called from here; instead this gate builds an
 * intern-shaped table by hand, populates it with the SAME insert algorithm the C
 * lookup walks against, and differentially checks the native probe vs the C
 * reference probe for present keys (varied lengths, collision chains) AND misses.
 *
 * The native body takes the table base pointers + a PRECOMPUTED hash (matching
 * hexa_intern, which passes hexa_fnv1a(s, slen)) + the candidate string, each
 * boxed as a TAG_INT HexaVal — and returns the canonical pointer boxed TAG_INT,
 * or 0 on miss. This gate proves payload-bit equality with the C reference.
 *
 * Build (x86_64 / arm64, native intern_core.o + standalone runtime.a):
 *   <aprime_cc> _drv --emit=obj --target=<t> -o intern_core.o intern_core.hexa
 *   cc -O2 -std=gnu11 -D_GNU_SOURCE -I self intern_core_gate.c self/runtime.c \
 *      intern_core.o -o /tmp/interngate && /tmp/interngate ; echo $?
 *
 * Exit code = 23 on FULL pass (distinct sentinel; 21 = map gate, 23 = intern);
 * 1..N on the first failing check. The CI faithful 3-target + selfhost-byteeq-real
 * gates stay AUTHORITATIVE for the whole-compiler fixpoint.
 */
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <stdlib.h>
#include "runtime.h"

/* native port (gen2-emitted object); all args boxed TAG_INT. Returns canonical
 * pointer boxed TAG_INT, or 0 (TAG_INT) on miss. */
extern HexaVal rt_intern_find_native(HexaVal buckets, HexaVal hashes, HexaVal cap,
                                     HexaVal h, HexaVal key);

/* C reference FNV-1a — byte-identical to runtime.c's hexa_fnv1a(s, len). */
static uint32_t ref_fnv1a(const char* s, size_t len) {
    uint32_t h = 2166136261u;
    for (size_t i = 0; i < len; i++) { h ^= (uint8_t)s[i]; h *= 16777619u; }
    return h;
}

/* C reference lookup loop — mirrors hexa_intern's probe (returns canonical or NULL). */
static const char* ref_find(char** buckets, uint32_t* hashes, int cap, uint32_t h, const char* s) {
    uint32_t mask = (uint32_t)(cap - 1);
    uint32_t idx = h & mask;
    while (buckets[idx] != NULL) {
        if (hashes[idx] == h && strcmp(buckets[idx], s) == 0) return buckets[idx];
        idx = (idx + 1) & mask;
    }
    return NULL;
}

static int fails = 0;
static void chk(int cond, const char* what) {
    if (!cond) { fails++; fprintf(stderr, "[intern_core_gate] FAIL: %s\n", what); }
}

/* table + insert mirroring hexa_intern's insert half (so the C lookup has data). */
#define CAP 1024
static char**    g_buckets;
static uint32_t* g_hashes;
static void ins(const char* s) {
    size_t len = strlen(s);
    uint32_t h = ref_fnv1a(s, len);
    uint32_t mask = (uint32_t)(CAP - 1);
    uint32_t idx = h & mask;
    while (g_buckets[idx]) {
        if (g_hashes[idx] == h && strcmp(g_buckets[idx], s) == 0) return; /* already */
        idx = (idx + 1) & mask;
    }
    g_buckets[idx] = strdup(s);
    g_hashes[idx]  = h;
}

static void chk_key(const char* key, int expect_present) {
    size_t len = strlen(key);
    uint32_t h = ref_fnv1a(key, len);
    const char* c = ref_find(g_buckets, g_hashes, CAP, h, key);
    HexaVal nv = rt_intern_find_native(
        hexa_int((int64_t)(intptr_t)g_buckets),
        hexa_int((int64_t)(intptr_t)g_hashes),
        hexa_int((int64_t)CAP),
        hexa_int((int64_t)(uint32_t)h),
        hexa_int((int64_t)(intptr_t)key));
    const char* n = (const char*)(intptr_t)HX_INT(nv);
    char buf[160];
    snprintf(buf, sizeof(buf), "find('%s') native==C ptr (%p vs %p, present=%d)",
             key, (void*)n, (void*)c, expect_present);
    chk(n == c, buf);
    if (expect_present) chk(n != NULL && strcmp(n, key) == 0, "present key -> equal canonical");
    else                chk(n == NULL, "absent key -> NULL");
}

int main(void) {
    chk(sizeof(HexaVal) == 16, "sizeof(HexaVal)==16");

    g_buckets = (char**)calloc(CAP, sizeof(char*));
    g_hashes  = (uint32_t*)calloc(CAP, sizeof(uint32_t));

    const char* keys[] = {
        "a", "bb", "ccc", "if", "while", "return", "ident",
        "longish_keyword_identifier_name", "", "x", "y", "z",
        "fn", "let", "mut", "struct"
    };
    int nk = (int)(sizeof(keys)/sizeof(keys[0]));
    for (int i = 0; i < nk; i++) ins(keys[i]);

    for (int i = 0; i < nk; i++) chk_key(keys[i], 1);     /* present */
    chk_key("no_such_key", 0);
    chk_key("zzz_absent", 0);
    chk_key("aa", 0);                                      /* near-collision miss */
    chk_key("whilf", 0);                                   /* 1-char-off miss */

    if (fails == 0) { printf("[intern_core_gate] PASS (all native==C)\n"); return 23; }
    fprintf(stderr, "[intern_core_gate] %d FAIL(s)\n", fails);
    return fails;
}
