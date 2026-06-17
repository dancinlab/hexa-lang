/* b4_array_gate.c — RT-NATIVE-ZEROC M4 batch B4 (array-core) C-differential gate (c2).
 *
 * Goal: establish the BYTE-EQ ORACLE for the array-core family
 *   (hexa_array_new / get / set / push / pop / reserve / len + snapshot_array)
 * against the standalone runtime.c C-path — the exact {ptr,len,cap} descriptor
 * image + 16-byte HexaVal element stride that ANY native raw-mem port MUST
 * reproduce. This gate is the re-runnable byte oracle the native object is
 * measured against once the construct-side intrinsic (see verdict) lands.
 *
 * Two halves:
 *   PART A — LAYOUT oracle. Assert the HexaArr field offsets (items@0, len@8,
 *            cap@16, sizeof@24) and the HexaVal element stride (16) that the
 *            raw-mem port's __hx_ptr_load64/store64 offset arithmetic depends
 *            on. byte-eq of any native port is offset-exact ONLY if these hold.
 *
 *   PART B — BEHAVIOUR oracle. Drive the live C array functions through:
 *            empty array, single element, capacity-doubling growth (8→16→32),
 *            reserve, get/set in-bounds, pop, and assert (a) the post-sequence
 *            descriptor {len,cap} and (b) the raw 16-byte image of every stored
 *            element. This is the behaviour a native array_core.o must match
 *            bit-for-bit. Negative-cap (arena-sentinel) is documented as a
 *            C-path-internal state the heap-only port path must also honor.
 *
 * Build (x86_64 / arm64, standalone runtime.c — the PRIMARY CI/release config):
 *   cc -O2 -std=gnu11 -D_GNU_SOURCE -I self \
 *      scripts/scratch/rt_native/b4_array_gate.c self/runtime.c -o /tmp/b4gate
 *   /tmp/b4gate
 *
 * The CI faithful 3-target + selfhost-byteeq-real gates remain AUTHORITATIVE
 * for the whole-compiler fixpoint; this gate is the per-family byte oracle.
 */
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include "runtime.h"

/* The array-core fns are defined in self/runtime_core.c (#include'd by
 * runtime.c) but not all are prototyped in runtime.h — declare the ones this
 * gate drives so the compiler sees the real HexaVal-returning signatures. */
HexaVal hexa_array_new(void);
HexaVal hexa_array_get(HexaVal arr, int64_t idx);
HexaVal hexa_array_set(HexaVal arr, int64_t idx, HexaVal val);
HexaVal hexa_array_push(HexaVal arr, HexaVal item);
HexaVal hexa_array_pop(HexaVal arr);
HexaVal hexa_array_shift(HexaVal arr);
HexaVal hexa_array_reserve(HexaVal arr, int n);
HexaVal hexa_val_snapshot_array(HexaVal v);

static int fails = 0, checks = 0;

static void ok(const char* what, int cond) {
    checks++;
    if (!cond) { fails++; fprintf(stderr, "FAIL %s\n", what); }
}

static void eq_i(const char* what, long long got, long long exp) {
    checks++;
    if (got != exp) {
        fails++;
        fprintf(stderr, "FAIL %-30s got=%lld exp=%lld\n", what, got, exp);
    }
}

/* Raw 16-byte image of a HexaVal: tag eightbyte + payload eightbyte. */
static void elem_image(HexaVal v, uint64_t* tag, uint64_t* pay) {
    unsigned char img[sizeof(HexaVal)];
    memset(img, 0, sizeof img);
    memcpy(img, &v, sizeof(HexaVal));
    memcpy(tag, img + 0, 8);
    memcpy(pay, img + 8, 8);
}

/* Assert arr[idx] raw image equals a constructed expected HexaVal's image. */
static void elem_eq(const char* what, HexaVal arr, int idx, HexaVal expect) {
    checks++;
    HexaVal got = hexa_array_get(arr, idx);
    uint64_t gt, gp, et, ep;
    elem_image(got, &gt, &gp);
    elem_image(expect, &et, &ep);
    if (gt != et || gp != ep) {
        fails++;
        fprintf(stderr,
            "FAIL %-22s [%d] tag g=%llu e=%llu pay g=0x%016llx e=0x%016llx\n",
            what, idx, (unsigned long long)gt, (unsigned long long)et,
            (unsigned long long)gp, (unsigned long long)ep);
    }
}

/* HexaArr field reads via the public union member (mirrors HX_ARR_* macros). */
typedef struct { void* items; int64_t len; int64_t cap; } ArrView;
static ArrView arr_view(HexaVal v) {
    ArrView a;
    memcpy(&a, (void*)v.arr_ptr, sizeof(ArrView));
    return a;
}

int main(void) {
    printf("HexaVal sizeof=%zu  HexaArr sizeof=%zu\n",
           sizeof(HexaVal), sizeof(ArrView));

    /* ── PART A: LAYOUT oracle ───────────────────────────────────────── */
    eq_i("sizeof(HexaVal)", (long long)sizeof(HexaVal), 16);
    eq_i("HexaArr.items offset", (long long)offsetof(ArrView, items), 0);
    eq_i("HexaArr.len   offset", (long long)offsetof(ArrView, len), 8);
    eq_i("HexaArr.cap   offset", (long long)offsetof(ArrView, cap), 16);
    eq_i("sizeof(HexaArr)", (long long)sizeof(ArrView), 24);

    /* ── PART B: BEHAVIOUR oracle ────────────────────────────────────── */
    /* empty array: fresh new() => len 0, items NULL, cap 0 */
    HexaVal a = hexa_array_new();
    ok("new() is array", HX_IS_ARRAY(a));
    {
        ArrView v = arr_view(a);
        eq_i("new len", v.len, 0);
        eq_i("new cap", v.cap, 0);
        ok("new items NULL", v.items == NULL);
    }

    /* single element */
    a = hexa_array_push(a, hexa_int(42));
    eq_i("push1 len", arr_view(a).len, 1);
    elem_eq("push1 [0]=42", a, 0, hexa_int(42));

    /* capacity-doubling growth: push up to 40 elements, observe cap 8→16→32→64 */
    for (int i = 1; i < 40; i++) a = hexa_array_push(a, hexa_int(1000 + i));
    eq_i("push40 len", arr_view(a).len, 40);
    {
        int64_t real_cap = arr_view(a).cap < 0 ? -arr_view(a).cap : arr_view(a).cap;
        ok("push40 cap >= 40 (power-of-2 grow)", real_cap >= 40);
        ok("push40 cap is 64 (8,16,32,64 ladder)", real_cap == 64);
    }
    elem_eq("grow [0]=42", a, 0, hexa_int(42));
    elem_eq("grow [1]=1001", a, 1, hexa_int(1001));
    elem_eq("grow [39]=1039", a, 39, hexa_int(1039));

    /* get / set in-bounds: set [5] = -7, read back */
    hexa_array_set(a, 5, hexa_int(-7));
    elem_eq("set [5]=-7", a, 5, hexa_int(-7));
    elem_eq("set neighbour [4] unchanged", a, 4, hexa_int(1004));
    elem_eq("set neighbour [6] unchanged", a, 6, hexa_int(1006));

    /* mixed element tags: push a string + a float, check raw image survives */
    a = hexa_array_push(a, hexa_str("hi"));
    a = hexa_array_push(a, hexa_float(3.5));
    eq_i("push mixed len", arr_view(a).len, 42);
    {
        HexaVal s = hexa_array_get(a, 40);
        HexaVal f = hexa_array_get(a, 41);
        ok("str elem tag", HX_IS_STR(s));
        ok("str elem value", HX_STR(s) && strcmp(HX_STR(s), "hi") == 0);
        ok("float elem tag", HX_IS_FLOAT(f));
        ok("float elem value", HX_FLOAT(f) == 3.5);
    }

    /* pop: returns last, len shrinks */
    {
        HexaVal popped = hexa_array_pop(a);
        ok("pop returns float", HX_IS_FLOAT(popped) && HX_FLOAT(popped) == 3.5);
        eq_i("pop len", arr_view(a).len, 41);
    }

    /* shift: returns first, slides every later elem down one, len shrinks.
     * Exercises rt_array_shift_native's 16-byte slide + tag-faithful first. */
    {
        HexaVal sa = hexa_array_new();
        sa = hexa_array_push(sa, hexa_int(10));
        sa = hexa_array_push(sa, hexa_int(20));
        sa = hexa_array_push(sa, hexa_str("c"));
        HexaVal shf = hexa_array_shift(sa);
        ok("shift returns first int", HX_IS_INT(shf) && HX_INT(shf) == 10);
        eq_i("shift len", arr_view(sa).len, 2);
        elem_eq("shift slid [0] int", sa, 0, hexa_int(20));
        HexaVal s1 = hexa_array_get(sa, 1);
        ok("shift slid [1] str tag+val", HX_IS_STR(s1) && HX_STR(s1) && strcmp(HX_STR(s1), "c") == 0);
    }

    /* reserve: grow cap to 128 without changing len; existing elems intact */
    {
        int64_t len_before = arr_view(a).len;
        a = hexa_array_reserve(a, 128);
        int64_t real_cap = arr_view(a).cap < 0 ? -arr_view(a).cap : arr_view(a).cap;
        eq_i("reserve preserves len", arr_view(a).len, len_before);
        ok("reserve cap >= 128", real_cap >= 128);
        elem_eq("reserve [0] intact", a, 0, hexa_int(42));
        elem_eq("reserve [5] intact", a, 5, hexa_int(-7));
    }

    /* snapshot_array on a heap-backed (cap>=0) array is identity (no arena) */
    {
        HexaVal snap = hexa_val_snapshot_array(a);
        ok("snapshot heap-backed identity (same descriptor)",
           snap.arr_ptr == a.arr_ptr);
    }

    printf("PART A (layout) + PART B (behaviour) ran.\n");
    if (fails == 0) printf("GATE PASS — %d checks, 0 fails\n", checks);
    else            printf("GATE FAIL — %d checks, %d fails\n", checks, fails);
    return fails ? 1 : 0;
}
