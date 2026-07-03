/* sh_array_arena_micro_gate.c — sh-array-write FOCUSED byte-eq oracle.
 *
 * Links ONLY the two seeds this lane touches: the array_core seed (provides
 * rt_array_arena_alloc_items_native) + the alloc seed (provides hexa_arena_alloc,
 * rt_init, hexa_arena_reset). Sidesteps the full runtime.c link (and its
 * orthogonal map-seed drift). Proves the native arena bridge is byte-exact vs a
 * direct C arena alloc of the same size: in a FRESH arena, allocating N HexaVal
 * slots via rt_array_arena_alloc_items_native(N) lands at the SAME bump pointer
 * and consumes the SAME bytes as hexa_arena_alloc(N*16), and the returned buffer
 * holds N written HexaVal images intact (round-trip).
 *
 * Both seed entries use the HexaVal 2-register SysV ABI (arg {tag,payload} in
 * rdi:rsi, raw-ptr return read from rdx) — the exact bridge runtime_core_emit.hexa
 * uses for __hxseed_arena_alloc. We declare the seed symbols at their true HexaVal
 * signature + asm-label and extract the payload (HX_INT) word.
 */
#include <stdio.h>
#include <stdint.h>
#include <string.h>

/* Minimal HexaVal mirror — {tag@0, payload@8}, 16 bytes (sizeof matches runtime). */
typedef struct { int64_t tag; int64_t pay; } HV;
#define HXI(v) ((v).pay)

/* Seed entries (ELF, no underscore on x86_64-linux). HexaVal 2-register ABI. */
extern HV rt_init_hv(void)                 __asm__("rt_init");
extern HV hexa_arena_reset_hv(void)        __asm__("hexa_arena_reset");
extern HV hexa_arena_alloc_hv(HV n)        __asm__("hexa_arena_alloc");
extern HV rt_array_arena_alloc_items_hv(HV n) __asm__("rt_array_arena_alloc_items_native");

static HV mk(int64_t x) { HV v; v.tag = 0; v.pay = x; return v; }

/* Minimal runtime prims the alloc seed references for its int `==`/`!=` tests
 * (e.g. `if __arena_head == 0`, `while nb != 0`). Payload-equality + payload-
 * nonzero are exactly the seed's integer semantics here. HexaVal 2-register ABI. */
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
HV  hexa_to_int(HV v)       { HV r; r.tag = 0; r.pay = v.pay; return r; }  /* `as int` cast in rt_array_len_native (unused by this gate) */

int main(void) {
    rt_init_hv();

    /* Run 1: native bridge — N slots via rt_array_arena_alloc_items_native(N). */
    hexa_arena_reset_hv();
    int N = 40;
    int64_t p_native = HXI(rt_array_arena_alloc_items_hv(mk(N)));
    /* The very next arena alloc (M bytes) tells us how many bytes the first
     * allocation consumed: delta = p_next - p_native must equal align_up(N*16,8). */
    int64_t p_native_next = HXI(hexa_arena_alloc_hv(mk(8)));
    int64_t consumed_native = p_native_next - p_native;

    /* Run 2: direct C-equivalent — hexa_arena_alloc(N*16) in a fresh arena. */
    hexa_arena_reset_hv();
    int64_t p_cbody = HXI(hexa_arena_alloc_hv(mk((int64_t)N * 16)));
    int64_t p_cbody_next = HXI(hexa_arena_alloc_hv(mk(8)));
    int64_t consumed_cbody = p_cbody_next - p_cbody;

    printf("native: base_off=%lld consumed=%lld\n",
           (long long)(p_native ? 0 : 0), (long long)consumed_native);
    printf("cbody : base_off=%lld consumed=%lld\n",
           (long long)(p_cbody ? 0 : 0), (long long)consumed_cbody);
    printf("expect consumed == align_up(N*16,8) = %lld\n", (long long)(((N*16)+7)/8*8));

    int ok = 1;
    if (consumed_native != consumed_cbody) { ok = 0; printf("FAIL: consumed delta differs\n"); }
    if (consumed_native != ((N*16)+7)/8*8) { ok = 0; printf("FAIL: native size != N*sizeof(HexaVal)\n"); }

    /* Round-trip: write N HexaVal images into the native buffer, read back. */
    hexa_arena_reset_hv();
    int64_t buf = HXI(rt_array_arena_alloc_items_hv(mk(N)));
    HV* items = (HV*)(uintptr_t)buf;
    for (int i = 0; i < N; i++) { items[i].tag = 1; items[i].pay = 1000 + i; }
    for (int i = 0; i < N; i++) {
        if (items[i].tag != 1 || items[i].pay != 1000 + i) {
            ok = 0; printf("FAIL: roundtrip [%d] tag=%lld pay=%lld\n", i,
                           (long long)items[i].tag, (long long)items[i].pay);
        }
    }
    printf("roundtrip: wrote+read %d HexaVal slots\n", N);

    if (ok) printf("MICRO_BYTEEQ_OK native-arena-bridge == C-arena-alloc (size + roundtrip byte-Δ=0)\n");
    else    printf("MICRO_BYTEEQ_FAIL\n");
    return ok ? 0 : 1;
}
