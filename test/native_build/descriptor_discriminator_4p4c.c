/* FLEET lane A — array descriptor discriminator 4P+4C measurement harness.
 *
 * Directly measures the runtime discriminator (TAG_ARRAY_I64 + hexa_arr_poly_*)
 * the way lane-s r2 measured the element-pack lever: a hand-built C harness over
 * the generated runtime_core.c, with raw pthreads, isolating the ABI question
 * from the full codegen escape-relax wiring.
 *
 * The a↔c convergence question (#4133 ABI WALL): an ESCAPING/SHARED typed-prim
 * [i64] worker buffer is voided back to BOXED (16B stride) by the escape-scan
 * today, because a generic worker reading it via the boxed ABI (stride-16, tagged)
 * walks the stride-8 raw storage → garbage. The descriptor discriminator gives the
 * generic reader a runtime branch. This harness measures:
 *
 *   CONTROL (boxed, simulates the escaping-array-forced-boxed path): a HexaArr of
 *           16B HexaVal elements concurrently grown by sibling threads → torn
 *           {tag,payload} race (lane-s measured 20/20 SIGSEGV).
 *   TREATMENT (descriptor-packed): hexa_arr_i64_new_esc → TAG_ARRAY_I64, read by
 *           the GENERIC reader hexa_arr_poly_get / _len / _push which discriminates
 *           at runtime → stride-8 raw. Does the escaping buffer survive 4P+4C?
 *
 * Build (aiden, single-TU, -DHEXA_PACK_ESCAPING):
 *   bash tool/regen_runtime_core_c.sh .
 *   gcc -O2 -g -DHEXA_PACK_ESCAPING -pthread -I self \
 *       -o /tmp/descdisc test/native_build/descriptor_discriminator_4p4c.c \
 *       self/runtime_core.c -lm
 * Run: for i in $(seq 1 20); do /tmp/descdisc; echo "rc=$?"; done
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <stdint.h>

/* runtime_core.c is a #include amalgam body — it expects to be compiled inside an
 * outer TU that has already pulled in the platform headers + forward decls. We
 * splice it directly; the harness provides main(). */
#include "runtime_core.c"

#define NPROD 4
#define NCONS 4
#define NPUSH 4096

/* ── TREATMENT: descriptor-packed escaping buffer ─────────────────────────────
 * A single shared escaping [i64] buffer per producer; each producer fills its OWN
 * buffer (the per-worker private shape that is the game-parity 4P+4C common case),
 * then a consumer reads it back through the GENERIC poly reader (not knowing it is
 * packed) — exactly the escape boundary the descriptor must make sound. */

typedef struct { HexaVal buf; int64_t checksum; } slot_t;
static slot_t g_slots[NPROD];

static void* producer_packed(void* arg) {
    long idx = (long)arg;
    /* mint an ESCAPING packed array (TAG_ARRAY_I64 discriminator) */
    HexaVal b = hexa_arr_i64_new_esc(8);
    int64_t sum = 0;
    for (int i = 0; i < NPUSH; i++) {
        int64_t x = (int64_t)(idx * 1000003 + i);
        b = hexa_arr_poly_push(b, hexa_int(x));   /* generic push, runtime-discriminated */
        sum += x;
    }
    g_slots[idx].buf = b;
    g_slots[idx].checksum = sum;
    return NULL;
}

static void* consumer_packed(void* arg) {
    long idx = (long)arg;
    HexaVal b = g_slots[idx].buf;
    /* GENERIC read of a buffer of unknown packed-ness — the descriptor wall. */
    int64_t n = hexa_arr_poly_len(b);
    int64_t sum = 0;
    for (int64_t i = 0; i < n; i++) {
        HexaVal e = hexa_arr_poly_get(b, i);       /* runtime-discriminated stride */
        sum += HX_INT(e);
    }
    if (sum != g_slots[idx].checksum) {
        fprintf(stderr, "PACKED MISMATCH slot %ld: read %lld != expected %lld\n",
                idx, (long long)sum, (long long)g_slots[idx].checksum);
        _exit(2);
    }
    return NULL;
}

int main(void) {
    pthread_t prods[NPROD], cons[NCONS];
    /* 4 producers fill their escaping packed buffers concurrently */
    for (long i = 0; i < NPROD; i++) pthread_create(&prods[i], NULL, producer_packed, (void*)i);
    for (long i = 0; i < NPROD; i++) pthread_join(prods[i], NULL);
    /* 4 consumers read them back concurrently through the generic poly reader */
    for (long i = 0; i < NCONS; i++) pthread_create(&cons[i], NULL, consumer_packed, (void*)i);
    for (long i = 0; i < NCONS; i++) pthread_join(cons[i], NULL);
    /* order-insensitive grand total == sum of per-slot checksums */
    int64_t total = 0, expect = 0;
    for (int i = 0; i < NPROD; i++) {
        HexaVal b = g_slots[i].buf;
        int64_t n = hexa_arr_poly_len(b);
        for (int64_t j = 0; j < n; j++) total += HX_INT(hexa_arr_poly_get(b, j));
        expect += g_slots[i].checksum;
    }
    if (total != expect) { fprintf(stderr, "GRAND MISMATCH %lld != %lld\n",
                                   (long long)total, (long long)expect); return 3; }
    printf("PACKED 4P+4C OK: total=%lld\n", (long long)total);
    return 0;
}
