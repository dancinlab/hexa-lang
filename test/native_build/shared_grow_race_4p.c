/* FLEET #6 — thread-safe GROWABLE allocator measurement harness.
 *
 * The orthogonal grow race lane-A #4140 explicitly deferred: per-worker-PRIVATE
 * buffers were proven 4P+4C-safe (each producer fills its OWN HexaArrI64). This
 * harness measures the SHARED case: >=2 threads concurrently PUSH to the SAME
 * shared HexaArrI64, forcing concurrent realloc-grow.
 *
 * THE RACE (self/runtime_core_emit.hexa hexa_arr_i64_push, default body):
 *     if (a->len >= a->cap) { a->cap *= 2;
 *                             a->data = realloc(a->data, ...); }   // (1)
 *     a->data[a->len++] = x;                                       // (2)
 *   Two threads interleaving (1): both read the SAME old a->data, both realloc
 *   it -> one realloc frees the block the other just reallocated, and one
 *   a->data store clobbers the other -> dangling/freed pointer -> SIGSEGV / heap
 *   corruption. Even without grow, the non-atomic `a->len++` loses writes.
 *
 * CONTROL  (DEFAULT build, no -DHEXA_THREADS): push has NO lock -> race.
 *          EXPECT: crash (SIGSEGV/SIGABRT) or a checksum/len mismatch.
 * TREATMENT(-DHEXA_THREADS): push grow+append guarded by a striped pthread_mutex
 *          (reference: Rust Mutex<Vec>, jemalloc arena bin locks).
 *          EXPECT: 0 crash, exact len == NPROD*NPUSH, exact checksum.
 *
 * Build (aiden, single-TU over the standalone runtime_core path):
 *   bash tool/regen_runtime_core_c.sh .
 *   # CONTROL (race):
 *   gcc -O2 -g -DHEXA_PACK_ESCAPING -pthread -I self \
 *       -o /tmp/grow_ctl test/native_build/shared_grow_race_4p.c \
 *       self/runtime_core.c -lm
 *   # TREATMENT (locked):
 *   gcc -O2 -g -DHEXA_PACK_ESCAPING -DHEXA_THREADS -pthread -I self \
 *       -o /tmp/grow_trt test/native_build/shared_grow_race_4p.c \
 *       self/runtime_core.c -lm
 * Run: for i in $(seq 1 20); do /tmp/grow_xxx; echo "rc=$?"; done
 *
 * HEXA_PACK_ESCAPING is required so hexa_arr_i64_new_esc / hexa_arr_poly_push
 * (the discriminated path #4140 added) are present; the grow primitive
 * hexa_arr_i64_push (the function this harness stresses) is unconditional, but
 * we route through the polymorphic push to mirror the real escaping-buffer flow.
 */
#include <pthread.h>

#include "runtime_core_sysheaders.h"
#include "runtime_core_hxlcl_shim.c"
#include "runtime_core.c"

#define NPROD 4
#define NPUSH 50000

/* ONE shared escaping packed buffer grown concurrently by all producers. */
static HexaVal g_shared;
static pthread_barrier_t g_start;

static void* grower(void* arg) {
    long idx = (long)arg;
    /* All producers race to push into the SAME g_shared descriptor. The push
     * grows the underlying int64_t[] in place (realloc) when len>=cap — the
     * exact concurrent-realloc race. We sync the start so the threads overlap. */
    pthread_barrier_wait(&g_start);
    for (int i = 0; i < NPUSH; i++) {
        int64_t x = (int64_t)(idx * 1000003 + i);
        g_shared = hexa_arr_poly_push(g_shared, hexa_int(x));
    }
    return NULL;
}

int main(void) {
    pthread_t th[NPROD];
    pthread_barrier_init(&g_start, NULL, NPROD);

    /* mint a tiny escaping packed buffer (cap=8) so it MUST grow many times */
    g_shared = hexa_arr_i64_new_esc(8);

    for (long i = 0; i < NPROD; i++) pthread_create(&th[i], NULL, grower, (void*)i);
    for (long i = 0; i < NPROD; i++) pthread_join(th[i], NULL);

    /* survival check: len must equal the total pushes, and the multiset of
     * values must match (order-insensitive sum). Under the race, len is short
     * (lost a->len++ writes) or the program has already crashed. */
    int64_t got_len = hexa_arr_poly_len(g_shared);
    int64_t want_len = (int64_t)NPROD * NPUSH;

    int64_t got_sum = 0;
    for (int64_t i = 0; i < got_len; i++) {
        HexaVal e = hexa_arr_poly_get(g_shared, i);
        got_sum += HX_INT(e);
    }
    int64_t want_sum = 0;
    for (long idx = 0; idx < NPROD; idx++)
        for (int i = 0; i < NPUSH; i++)
            want_sum += (int64_t)(idx * 1000003 + i);

    if (got_len != want_len) {
        fprintf(stderr, "LEN MISMATCH: got %lld want %lld (lost concurrent writes)\n",
                (long long)got_len, (long long)want_len);
        return 2;
    }
    if (got_sum != want_sum) {
        fprintf(stderr, "SUM MISMATCH: got %lld want %lld (corrupted buffer)\n",
                (long long)got_sum, (long long)want_sum);
        return 3;
    }
    printf("SHARED-GROW 4P OK: len=%lld sum=%lld\n",
           (long long)got_len, (long long)got_sum);
    return 0;
}
