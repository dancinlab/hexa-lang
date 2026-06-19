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
extern HexaVal rt_map_set_inplace_native(HexaVal m, HexaVal keyp, HexaVal val);  /* construct-half: in-place overwrite, returns {0,1} found */

/* 16-byte image equality of two HexaVals (tag word + payload word). */
/* Semantic 16-byte HexaVal equality: tag (low 4 bytes) + payload (8 bytes @ +8).
 * NOT a raw 16-byte memcmp — HexaVal is { HexaTag tag; union{...}; } so there are
 * 4 UNDEFINED padding bytes between the 4-byte enum tag and the 8-aligned union.
 * A function that RETURNS a HexaVal by value (hexa_map_get) leaves those pad bytes
 * nondeterministic in the register-pair return, so a raw memcmp over all 16 bytes
 * spuriously differs on padding even when tag+payload are identical (measured:
 * vals[] storage byte-identical native==C, yet by-value memcmp diffs on pad). The
 * value IS (tag, payload); compare exactly those. */
static int hv_eq(HexaVal a, HexaVal b) { return HX_TAG(a) == HX_TAG(b) && a.i == b.i; }

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

    /* PART C — CONSTRUCT-half in-place write oracle (rt_map_set_inplace_native).
     * Build TWO maps with identical contents, then overwrite the SAME present
     * keys with new values: map mc via the C hexa_map_set (which on a present key
     * does t->vals[si]=val + t->order_vals[order_idx]=val), map mn via the native
     * rt_map_set_inplace_native (same dual writeback in raw mem). The two maps must
     * then be bit-identical on every get() AND on insertion-order value-at — proving
     * the native in-place write reproduces both the hash-indexed slot AND the
     * ROI-24 cached-order-index update. (New-key INSERT stays C — not exercised
     * here; set_inplace returns 0 on absent and writes nothing.) */
    HexaVal mc = hexa_map_new();   /* C-overwrite target  */
    HexaVal mn = hexa_map_new();   /* native-overwrite target */
    const char* ck[] = { "a", "bb", "ccc", "d", "x", "y", "z" };
    int nck = (int)(sizeof(ck)/sizeof(ck[0]));
    for (int i = 0; i < nck; i++) {
        mc = hexa_map_set(mc, ck[i], hexa_int(i));
        mn = hexa_map_set(mn, ck[i], hexa_int(i));
    }
    /* overwrite present keys with distinct new values (int / str / bool mix) */
    HexaVal nv[] = { hexa_int(999), hexa_str("over"), hexa_bool(1), hexa_int(-5), hexa_int(0), hexa_str(""), hexa_int(424242) };
    for (int i = 0; i < nck; i++) {
        mc = hexa_map_set(mc, ck[i], nv[i]);                                   /* C path */
        HexaVal r = rt_map_set_inplace_native(mn, hexa_int((int64_t)(intptr_t)ck[i]), nv[i]); /* native */
        char b[96]; snprintf(b, sizeof(b), "set_inplace('%s') returned found=1", ck[i]);
        chk(HX_INT(r) == 1, b);
    }
    /* every key now reads identically across the two maps (hash-indexed) */
    for (int i = 0; i < nck; i++) {
        HexaVal vc = hexa_map_get(mc, ck[i]);
        HexaVal vn = hexa_map_get(mn, ck[i]);
        char b[96]; snprintf(b, sizeof(b), "post-inplace get('%s') C==native", ck[i]);
        chk(hv_eq(vc, vn), b);
    }
    /* insertion-order values match too (proves order_vals[order_idx] writeback) */
    {
        HexaMapTable* tc = HX_MAP_TBL(mc);
        HexaMapTable* tn = HX_MAP_TBL(mn);
        chk(tc && tn && tc->len == tn->len, "inplace: order len C==native");
        if (tc && tn && tc->len == tn->len) {
            for (int i = 0; i < tc->len; i++) {
                char b[64]; snprintf(b, sizeof(b), "order_vals[%d] C==native", i);
                chk(hv_eq(tc->order_vals[i], tn->order_vals[i]), b);
            }
        }
    }
    /* absent key → native returns 0, writes nothing (insert stays C) */
    {
        HexaVal r = rt_map_set_inplace_native(mn, hexa_int((int64_t)(intptr_t)"absent_key_q"), hexa_int(1));
        chk(HX_INT(r) == 0, "set_inplace absent key -> found=0 (no write)");
    }

    if (fails == 0) { printf("[map_core_gate] PASS (all native==C, read + construct-inplace)\n"); return 21; }
    fprintf(stderr, "[map_core_gate] %d FAIL(s)\n", fails);
    return fails;
}
