/* sh_array_arena_byteeq_gate.c — sh-array-write byte-eq oracle.
 *
 * Drives hexa_array_push through capacity-doubling GROWTH while a live fn-arena
 * scope is open (__hexa_val_mark_top > 0), with the push-arena gates enabled, so
 * the grow path actually fires hexa_array_arena_alloc_items — the helper this
 * lane ports to the native arena (rt_array_arena_alloc_items_native). Dumps the
 * post-sequence descriptor {len, |cap|, arena-sentinel sign} + the raw 16-byte
 * {tag,payload} image of every element. Built TWICE — once with the runtime's
 * native arena bridge (-DHEXA_RT_ARRAY_ARENA_NATIVE=1 + array_core_native.o +
 * alloc_syscall_native.o) and once with the C body — the two dumps must be
 * byte-identical (the only delta is WHERE the arena buffer pointer is computed;
 * both route to the same hexa_arena_alloc seed, same n*16 size).
 */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include "runtime.h"

HexaVal hexa_array_new(void);
HexaVal hexa_array_push(HexaVal arr, HexaVal item);
HexaVal hexa_array_get(HexaVal arr, int64_t idx);
void    __hexa_fn_arena_enter(void);
HexaVal __hexa_fn_arena_return(HexaVal v);
extern int __hexa_val_mark_top;

typedef struct { void* items; int64_t len; int64_t cap; } ArrView;
static ArrView arr_view(HexaVal v) { ArrView a; memcpy(&a, (void*)v.arr_ptr, sizeof a); return a; }

int main(void) {
    /* Enable the arena push path the ported helper sits behind. */
    setenv("HEXA_ARRAY_ARENA", "1", 1);
    setenv("HEXA_ARRAY_PUSH_ARENA", "1", 1);

    /* Open a live fn-arena scope so __hexa_val_mark_top > 0 — without this the
     * helper's `if (__hexa_val_mark_top <= 0) return NULL` short-circuits and the
     * arena branch never runs. */
    __hexa_fn_arena_enter();
    printf("mark_top=%d (expect > 0)\n", __hexa_val_mark_top);

    HexaVal a = hexa_array_new();
    for (int i = 0; i < 40; i++) a = hexa_array_push(a, hexa_int(1000 + i));

    ArrView v = arr_view(a);
    int64_t real_cap = v.cap < 0 ? -v.cap : v.cap;
    printf("len=%lld real_cap=%lld arena_sentinel=%d\n",
           (long long)v.len, (long long)real_cap, v.cap < 0 ? 1 : 0);

    /* Raw element image dump — the byte-exact contents any port must reproduce. */
    for (int i = 0; i < (int)v.len; i++) {
        HexaVal e = hexa_array_get(a, i);
        unsigned char img[sizeof(HexaVal)];
        memcpy(img, &e, sizeof e);
        uint64_t tag, pay;
        memcpy(&tag, img + 0, 8);
        memcpy(&pay, img + 8, 8);
        printf("[%02d] tag=%llu pay=0x%016llx\n", i,
               (unsigned long long)tag, (unsigned long long)pay);
    }
    (void)__hexa_fn_arena_return(hexa_int(0));
    printf("GATE DONE\n");
    return 0;
}
