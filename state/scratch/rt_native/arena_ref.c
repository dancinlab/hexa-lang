// RT-NATIVE Z3 — C reference of the bump arena allocator.
//
// Extracted verbatim (logic-identical, stats/envelope stripped — those don't
// affect observable arena state) from self/runtime_core.c:
//   HexaArenaBlock{next,cap,used,data[]}  (3528)
//   hexa_arena_new_block                  (3571)
//   hexa_arena_alloc                      (3595)
//   hexa_arena_mark                       (3644)
//   hexa_arena_rewind                     (3654)
//   hexa_arena_reset                      (3669)
//
// malloc backend (byte-eq risk ZERO, tag-independent — Z3 MVP).
// Block size shrunk from 4MB to 256B so the test sequence actually spans
// multiple blocks and exercises the chain-walk / tail-reuse paths.

#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <stdint.h>

#define HEXA_ARENA_BLOCK_SIZE (256)   // small so the harness spans blocks

typedef struct HexaArenaBlock {
    struct HexaArenaBlock* next;
    size_t cap;
    size_t used;
    char   data[];
} HexaArenaBlock;

typedef struct {
    HexaArenaBlock* head;
    HexaArenaBlock* cur;
} HexaArena;

typedef struct {
    HexaArenaBlock* block;
    size_t used;
} HexaArenaMark;

static HexaArena __hexa_arena = {NULL, NULL};

static HexaArenaBlock* hexa_arena_new_block(size_t min_cap) {
    size_t cap = min_cap > HEXA_ARENA_BLOCK_SIZE ? min_cap : HEXA_ARENA_BLOCK_SIZE;
    HexaArenaBlock* b = (HexaArenaBlock*)malloc(sizeof(HexaArenaBlock) + cap);
    if (!b) return NULL;
    b->next = NULL;
    b->cap = cap;
    b->used = 0;
    return b;
}

void* hexa_arena_alloc(size_t n) {
    n = (n + 7u) & ~(size_t)7u;
    if (n == 0) n = 8;
    if (!__hexa_arena.head) {
        __hexa_arena.head = hexa_arena_new_block(n);
        __hexa_arena.cur = __hexa_arena.head;
        if (!__hexa_arena.head) return NULL;
    }
    HexaArenaBlock* b = __hexa_arena.cur;
    if (b->used + n > b->cap) {
        HexaArenaBlock* nb = b->next;
        while (nb && nb->cap < n) nb = nb->next;
        if (!nb) {
            nb = hexa_arena_new_block(n);
            if (!nb) return NULL;
            HexaArenaBlock* tail = __hexa_arena.cur;
            while (tail->next) { tail = tail->next; }
            tail->next = nb;
        }
        nb->used = 0;
        __hexa_arena.cur = nb;
        b = nb;
    }
    void* p = (void*)(b->data + b->used);
    b->used += n;
    return p;
}

HexaArenaMark hexa_arena_mark(void) {
    HexaArenaMark m;
    m.block = __hexa_arena.cur;
    m.used = __hexa_arena.cur ? __hexa_arena.cur->used : 0;
    return m;
}

void hexa_arena_rewind(HexaArenaMark m) {
    if (!m.block) {
        if (__hexa_arena.head) {
            __hexa_arena.head->used = 0;
            __hexa_arena.cur = __hexa_arena.head;
        }
        return;
    }
    m.block->used = m.used;
    for (HexaArenaBlock* b = m.block->next; b; b = b->next) b->used = 0;
    __hexa_arena.cur = m.block;
}

void hexa_arena_reset(void) {
    if (!__hexa_arena.head) return;
    for (HexaArenaBlock* b = __hexa_arena.head; b; b = b->next) b->used = 0;
    __hexa_arena.cur = __hexa_arena.head;
}

// ── observable-state dump ────────────────────────────────────
// Returns the index of `cur` in the head chain (0-based), or -1.
static long cur_index(void) {
    long i = 0;
    for (HexaArenaBlock* b = __hexa_arena.head; b; b = b->next, i++)
        if (b == __hexa_arena.cur) return i;
    return -1;
}

static long g_total = 0;   // cumulative requested bytes (post-align)

static void state_line(const char* op) {
    long nblocks = 0, sum_used = 0;
    for (HexaArenaBlock* b = __hexa_arena.head; b; b = b->next) {
        nblocks++;
        sum_used += (long)b->used;
    }
    printf("%-10s blocks=%ld cur=%ld sum_used=%ld total=%ld | used=[",
           op, nblocks, cur_index(), sum_used, g_total);
    int first = 1;
    for (HexaArenaBlock* b = __hexa_arena.head; b; b = b->next) {
        if (!first) printf(",");
        printf("%ld", (long)b->used);
        first = 0;
    }
    printf("] cap=[");
    first = 1;
    for (HexaArenaBlock* b = __hexa_arena.head; b; b = b->next) {
        if (!first) printf(",");
        printf("%ld", (long)b->cap);
        first = 0;
    }
    printf("]\n");
}

static void do_alloc(long n) {
    long an = (n + 7) & ~7L; if (an == 0) an = 8;
    g_total += an;
    hexa_arena_alloc((size_t)n);
}

int main(void) {
    // Deterministic mark stack (mirror the .hexa side).
    HexaArenaMark mstack[64];
    int msp = 0;

    // Repeating pattern: alloc(16),alloc(100),mark,alloc(50),rewind,alloc(8)
    // run for several dozen iterations so blocks fill, chain, rewind & reuse.
    int R = 40;
    for (int r = 0; r < R; r++) {
        do_alloc(16);
        do_alloc(100);
        mstack[msp++] = hexa_arena_mark();
        do_alloc(50);
        hexa_arena_rewind(mstack[--msp]);
        do_alloc(8);
    }
    state_line("post-loop");

    // A few large allocs that force min_cap > block size (oversized blocks).
    do_alloc(300);
    do_alloc(1000);
    state_line("post-large");

    // Nested marks + rewind to the outer.
    HexaArenaMark mA = hexa_arena_mark(); (void)mA;
    do_alloc(40);
    HexaArenaMark mB = hexa_arena_mark(); (void)mB;
    do_alloc(40);
    do_alloc(40);
    hexa_arena_rewind(mB);
    do_alloc(24);
    hexa_arena_rewind(mA);
    state_line("post-nested");

    // Refill after rewind exercises the tail-block reuse path (no new block).
    do_alloc(200);
    do_alloc(200);
    state_line("post-refill");

    // Full reset.
    hexa_arena_reset();
    state_line("post-reset");

    // mark when arena empty-of-frontier then rewind(NULL-block) semantics:
    // rewind a mark captured at head with used=0.
    HexaArenaMark m0 = hexa_arena_mark();
    do_alloc(64);
    hexa_arena_rewind(m0);
    state_line("post-m0");

    return 0;
}
