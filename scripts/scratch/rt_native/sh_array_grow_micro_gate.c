/* sh_array_grow_micro_gate.c — sh-array-grow (r2) FOCUSED byte-eq oracle.
 *
 * Links ONLY the array_core seed (rt_array_grow_arena_native +
 * rt_array_arena_alloc_items_native) + the alloc seed (hexa_arena_alloc, rt_init,
 * hexa_arena_reset). Sidesteps the full runtime.c link (orthogonal map-seed drift).
 *
 * Proves the native arena GROW path is byte-exact vs a C-equivalent grow: build a
 * HexaArr descriptor whose items live in an arena slab (cap = -OLD, len = N), call
 * rt_array_grow_arena_native(arr, NEW), and assert (a) descriptor rewritten to
 * items=new slab / cap=-NEW, (b) the N live element {tag,payload} images copied
 * byte-identical, (c) the new slab consumed exactly align_up(NEW*16,8) arena bytes
 * — identical to a hand-rolled C grow (arena_alloc(NEW*16)+memcpy) of the same array.
 *
 * Seed entries use the HexaVal 2-register SysV ABI (arg {tag,payload} rdi:rsi,
 * raw-ptr return read from rdx) via __asm__ labels, mirroring runtime_core_emit.hexa.
 */
#include <stdio.h>
#include <stdint.h>
#include <string.h>

typedef struct { int64_t tag; int64_t pay; } HV;
#define HXI(v) ((v).pay)

extern HV rt_init_hv(void)                       __asm__("rt_init");
extern HV hexa_arena_reset_hv(void)              __asm__("hexa_arena_reset");
extern HV hexa_arena_alloc_hv(HV n)              __asm__("hexa_arena_alloc");
extern HV rt_array_arena_alloc_items_hv(HV n)    __asm__("rt_array_arena_alloc_items_native");
/* rt_array_grow_arena_native(arr, new_cap) -> new items ptr (0 = arena off/OOM). */
extern HV rt_array_grow_arena_hv(HV arr, HV new_cap) __asm__("rt_array_grow_arena_native");

static HV mk(int64_t x) { HV v; v.tag = 0; v.pay = x; return v; }

/* Int-op runtime prims the alloc seed references for its `==`/`!=`/`+`/`*`/`/`
 * arithmetic (arena bump math). Integer payload semantics — HexaVal 2-reg ABI. */
HV  hexa_eq(HV a, HV b)     { HV r; r.tag = 0; r.pay = (a.pay == b.pay) ? 1 : 0; return r; }
int hexa_truthy(HV v)       { return v.pay != 0; }
HV  hexa_cmp_lt(HV a, HV b) { HV r; r.tag = 0; r.pay = (a.pay <  b.pay) ? 1 : 0; return r; }
HV  hexa_cmp_gt(HV a, HV b) { HV r; r.tag = 0; r.pay = (a.pay >  b.pay) ? 1 : 0; return r; }
HV  hexa_cmp_le(HV a, HV b) { HV r; r.tag = 0; r.pay = (a.pay <= b.pay) ? 1 : 0; return r; }
HV  hexa_cmp_ge(HV a, HV b) { HV r; r.tag = 0; r.pay = (a.pay >= b.pay) ? 1 : 0; return r; }
HV  hexa_add_slow(HV a, HV b) { HV r; r.tag = 0; r.pay = a.pay + b.pay; return r; }
HV  hexa_sub(HV a, HV b)    { HV r; r.tag = 0; r.pay = a.pay - b.pay; return r; }
HV  hexa_mul(HV a, HV b)    { HV r; r.tag = 0; r.pay = a.pay * b.pay; return r; }
HV  hexa_div(HV a, HV b)    { HV r; r.tag = 0; r.pay = b.pay ? a.pay / b.pay : 0; return r; }
HV  hexa_to_int(HV v)       { HV r; r.tag = 0; r.pay = v.pay; return r; }
/* rt_array_grow_arena_native uses __hx_payload_* intrinsics (inlined) + the
 * rt_array_arena_alloc_items_native call → no extra runtime refs beyond the above. */

/* A HexaArr descriptor mirror: { items@0, len@8, cap@16 }. */
typedef struct { int64_t items; int64_t len; int64_t cap; } Arr;

int main(void) {
    rt_init_hv();
    int N = 8, NEW = 16;     /* grow 8 → 16 (the cap-double ladder) */
    int ok = 1;

    /* ---- Native grow ---- */
    hexa_arena_reset_hv();
    /* old slab: N arena slots, fill with sentinel images. */
    int64_t old = HXI(rt_array_arena_alloc_items_hv(mk(N)));
    HV* oldp = (HV*)(uintptr_t)old;
    for (int i = 0; i < N; i++) { oldp[i].tag = 2; oldp[i].pay = 7000 + i; }
    /* Build an arena-backed descriptor (cap = -N, len = N). The descriptor itself
     * lives in the arena too (we just need a HexaArr the payload word points at). */
    int64_t desc = HXI(hexa_arena_alloc_hv(mk(24)));
    Arr* a = (Arr*)(uintptr_t)desc;
    a->items = old; a->len = N; a->cap = -(int64_t)N;
    /* Pack a TAG_ARRAY HexaVal whose payload word = desc (arr_ptr union slot). */
    HV arrv; arrv.tag = 3 /*TAG_ARRAY (any non-zero; native body only reads payload)*/; arrv.pay = desc;
    int64_t newbuf = HXI(rt_array_grow_arena_hv(arrv, mk(NEW)));
    int64_t after = HXI(hexa_arena_alloc_hv(mk(8)));   /* next bump → measure consumed */
    int64_t consumed_native = after - newbuf;
    /* Assertions: descriptor rewritten + elements copied. */
    if (a->items != newbuf) { ok = 0; printf("FAIL: descriptor items not rewritten (%lld != %lld)\n",(long long)a->items,(long long)newbuf); }
    if (a->cap != -(int64_t)NEW) { ok = 0; printf("FAIL: descriptor cap != -NEW (%lld)\n",(long long)a->cap); }
    HV* np = (HV*)(uintptr_t)newbuf;
    for (int i = 0; i < N; i++) {
        if (np[i].tag != 2 || np[i].pay != 7000 + i) { ok = 0; printf("FAIL: copied [%d] tag=%lld pay=%lld\n",i,(long long)np[i].tag,(long long)np[i].pay); }
    }
    printf("native: new_cap=%d consumed=%lld copied=%d\n", NEW, (long long)consumed_native, N);

    /* ---- C-equivalent grow (hand-rolled: arena_alloc(NEW*16)+memcpy) ---- */
    hexa_arena_reset_hv();
    int64_t cold = HXI(rt_array_arena_alloc_items_hv(mk(N)));
    HV* coldp = (HV*)(uintptr_t)cold;
    for (int i = 0; i < N; i++) { coldp[i].tag = 2; coldp[i].pay = 7000 + i; }
    int64_t cdesc = HXI(hexa_arena_alloc_hv(mk(24)));
    Arr* ca = (Arr*)(uintptr_t)cdesc; ca->items = cold; ca->len = N; ca->cap = -(int64_t)N;
    /* C body: arena_alloc(NEW*16), memcpy N*16, set items + cap=-NEW. */
    int64_t cnew = HXI(hexa_arena_alloc_hv(mk((int64_t)NEW * 16)));
    memcpy((void*)(uintptr_t)cnew, (void*)(uintptr_t)cold, (size_t)N * 16);
    ca->items = cnew; ca->cap = -(int64_t)NEW;
    int64_t cafter = HXI(hexa_arena_alloc_hv(mk(8)));
    int64_t consumed_cbody = cafter - cnew;
    printf("cbody : new_cap=%d consumed=%lld\n", NEW, (long long)consumed_cbody);

    if (consumed_native != consumed_cbody) { ok = 0; printf("FAIL: consumed delta differs (%lld vs %lld)\n",(long long)consumed_native,(long long)consumed_cbody); }
    if (consumed_native != ((int64_t)NEW*16+7)/8*8) { ok = 0; printf("FAIL: native grow size != NEW*sizeof(HexaVal)\n"); }
    /* Element images byte-identical between native-grown and C-grown buffers. */
    HV* cnp = (HV*)(uintptr_t)cnew;
    for (int i = 0; i < N; i++) {
        if (np[i].tag != cnp[i].tag || np[i].pay != cnp[i].pay) { ok = 0; printf("FAIL: native vs C elem [%d] differ\n", i); }
    }

    printf("expect consumed == align_up(NEW*16,8) = %lld\n", (long long)(((int64_t)NEW*16+7)/8*8));
    if (ok) printf("MICRO_BYTEEQ_OK native-grow == C-grow (descriptor + copied elements + size byte-Δ=0)\n");
    else    printf("MICRO_BYTEEQ_FAIL\n");
    return ok ? 0 : 1;
}
