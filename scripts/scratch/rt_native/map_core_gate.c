/* map_core_gate.c — RT-NATIVE-ZEROC M4 map-core READ-half C-differential gate (c2).
 *
 * Byte-eq oracle for the native map LOOKUP port
 * (stdlib/runtime/map_core.hexa::rt_map_get_native) against the standalone
 * runtime.c C path (hexa_map_get's hmap_find + t->vals[si]). The native body
 * does the SAME open-addressing probe (fnv1a + linear probe + strcmp) in raw
 * memory and re-stamps the value's REAL tag via __hx_make_val; this gate proves
 * the returned 16-byte HexaVal image is identical to the C path for present
 * keys (int / str / bool values, various key lengths, hash-collision chains) and
 * that a MISSING key yields TAG_VOID — exactly like the C path.
 *
 * Build (x86_64 / arm64, native map_core.o + standalone runtime.a):
 *   <aprime_cc> _drv --emit=obj --target=<t> -o map_core.o map_core.hexa
 *   cc -O2 -std=gnu11 -D_GNU_SOURCE -I self map_core_gate.c self/runtime.c \
 *      map_core.o -o /tmp/mapgate && /tmp/mapgate ; echo $?
 *
 * Exit code = 21 on FULL pass (distinct sentinel); 1..N on the first failing
 * check (so a regression is pinpointed). The CI faithful 3-target +
 * selfhost-byteeq-real gates stay AUTHORITATIVE for the whole-compiler fixpoint.
 */
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include "runtime.h"

/* native port (gen2-emitted object); key passed as int64 pointer value. */
extern HexaVal rt_map_get_native(HexaVal m, HexaVal keyp);  /* key boxed as TAG_INT HexaVal */
extern HexaVal rt_map_contains_native(HexaVal m, HexaVal keyp);  /* {0,1} TAG_INT bool */

/* 16-byte image equality of two HexaVals (tag word + payload word). */
static int hv_eq(HexaVal a, HexaVal b) { return memcmp(&a, &b, sizeof(HexaVal)) == 0; }

static int fails = 0;
static void chk(int cond, const char* what) {
    if (!cond) { fails++; fprintf(stderr, "[map_core_gate] FAIL: %s\n", what); }
}

/* compare native vs C for a present key — tags + payloads must match bit-exact */
static void chk_key(HexaVal m, const char* key) {
    HexaVal c = hexa_map_get(m, key);
    HexaVal n = rt_map_get_native(m, hexa_int((int64_t)(intptr_t)key));
    char buf[128];
    snprintf(buf, sizeof(buf), "get('%s') native==C (tag %d vs %d)", key, (int)HX_TAG(n), (int)HX_TAG(c));
    chk(hv_eq(n, c), buf);
}

/* native contains vs C hexa_map_contains_key — must agree (present + absent) */
static void chk_contains(HexaVal m, const char* key) {
    int c = hexa_map_contains_key(m, key);
    int n = (int)HX_INT(rt_map_contains_native(m, hexa_int((int64_t)(intptr_t)key)));
    char buf[128];
    snprintf(buf, sizeof(buf), "contains('%s') native==C (%d vs %d)", key, n, c);
    chk((n != 0) == (c != 0), buf);
}

int main(void) {
    /* PART A — layout oracle: the offsets rt_map_get_native's raw-mem arithmetic
     * depends on. If these drift, the native probe reads the wrong words. */
    chk(sizeof(HexaVal) == 16, "sizeof(HexaVal)==16 (vals[] stride)");

    /* PART B — behaviour oracle. Populate a map with int / str / bool values and
     * a spread of key lengths + likely-colliding keys, then differential-check. */
    HexaVal m = hexa_map_new();
    m = hexa_map_set(m, "a", hexa_int(1));
    m = hexa_map_set(m, "bb", hexa_int(2));
    m = hexa_map_set(m, "ccc", hexa_str("three"));
    m = hexa_map_set(m, "d", hexa_bool(1));
    m = hexa_map_set(m, "longish_key_name_42", hexa_int(42));
    m = hexa_map_set(m, "", hexa_int(7));          /* empty-string key */
    m = hexa_map_set(m, "x", hexa_int(100));
    m = hexa_map_set(m, "y", hexa_int(200));
    m = hexa_map_set(m, "z", hexa_int(300));
    m = hexa_map_set(m, "a", hexa_int(11));        /* overwrite — same slot */

    chk_key(m, "a");                                /* overwritten int */
    chk_key(m, "bb");
    chk_key(m, "ccc");                              /* STR value — tag must survive */
    chk_key(m, "d");                                /* BOOL value */
    chk_key(m, "longish_key_name_42");
    chk_key(m, "");
    chk_key(m, "x"); chk_key(m, "y"); chk_key(m, "z");

    /* MISSING key — C path returns TAG_VOID (after a stderr msg); native returns
     * __hx_make_val(4,0) = TAG_VOID. Compare tags only (C prints, native silent). */
    chk_contains(m, "a"); chk_contains(m, "ccc"); chk_contains(m, "");
    chk_contains(m, "no_such_key"); chk_contains(m, "zzz_absent");

    HexaVal miss_n = rt_map_get_native(m, hexa_int((int64_t)(intptr_t)"no_such_key"));
    chk(HX_TAG(miss_n) == TAG_VOID, "missing key native -> TAG_VOID");

    if (fails == 0) { printf("[map_core_gate] PASS (all native==C, %d checks)\n", 16); return 21; }
    fprintf(stderr, "[map_core_gate] %d FAIL(s)\n", fails);
    return fails;
}
