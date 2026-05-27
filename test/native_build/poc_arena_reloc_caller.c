/* test/native_build/poc_arena_reloc_caller.c
 *
 * F3 CLASS-A RELOC ORACLE · the reloc-BOUND counterpart of
 * poc_hxlcl_leaves_caller.c (which covers the reloc-FREE leaf family).
 *
 * The class-A frontier = runtime primitives that reference an EXTERNAL data
 * symbol via an ARM64 `adrp x9, sym@PAGE` + `add x9, x9, sym@PAGEOFF` pair
 * (PAGE21 / PAGEOFF12 relocation). This oracle exercises the four arena
 * primitives self-emitted by self/codegen/runtime_arm64.hexa::rt_arena_*,
 * each of which does exactly that against the `_arena_state` global. The .o
 * under test is produced by poc_arena_bundle_emit.hexa (10 reloc records,
 * 5 ADRP+ADD pairs → _arena_state) — see otool -rv for the reloc table.
 *
 * What this PROVES that the byte-emit POC (poc_arena_bundle_emit.hexa) does
 * NOT: that the hexa-emitted reloc-bearing Mach-O .o is accepted by ld64,
 * that the PAGE21/PAGEOFF12 immediates are PATCHED to the correct absolute
 * VM address of _arena_state, and that the resolved code runs correctly.
 * If the relocs were wrong, the adrp+add would compute a stale/wrong address
 * and the bump-allocator invariants below would fail (or SIGSEGV).
 *
 * Class-A ABI (megabyte-granular, per rt_arena_init's `lsl x1, x0, #20`):
 *   void *rt_arena_init(long mb);   -- mmap mb*1MB; store base/ptr/end
 *   void *rt_arena_alloc(long n);   -- bump ptr by n bytes; return old ptr
 *                                      (NULL on overflow past end)
 *   void  rt_arena_reset(void);     -- ptr = base (bulk free, keep mapping)
 *   void *rt_arena_release(void);   -- munmap + zero _arena_state
 *
 * Link (the reloc .o ahead-linked — clang is the ld64 oracle ONLY, never in
 * the .o emit path; the bytes come from rt_arena_*()):
 *   clang -arch arm64 poc_arena_reloc_caller.c poc_arena_bundle.o -o run
 * Run:
 *   ./run ; echo "rc=$?"   -> rc=0 on all-pass, nonzero on first failure
 */

#include <stddef.h>
#include <stdio.h>

extern void *rt_arena_init(long mb);
extern void *rt_arena_alloc(long n);
extern void  rt_arena_reset(void);
extern void *rt_arena_release(void);

static int fail(const char *what) { fprintf(stderr, "FAIL: %s\n", what); return 1; }

int main(void) {
    /* ── init: reserve 1 MB; mmap base != NULL proves the adrp+add store
     *    into _arena_state.base/ptr/end resolved to real memory ── */
    void *base = rt_arena_init(1);
    if (base == NULL || base == (void *)-1) return fail("arena_init mmap");

    /* ── alloc: two bumps; the second must be exactly +16 from the first.
     *    This reads state.ptr / state.end via the reloc'd adrp+add — a
     *    wrong reloc would read garbage and break the delta. ── */
    void *a = rt_arena_alloc(16);
    if (a == NULL)                 return fail("arena_alloc #1 NULL");
    void *b = rt_arena_alloc(16);
    if (b == NULL)                 return fail("arena_alloc #2 NULL");
    long delta = (long)((char *)b - (char *)a);
    if (delta != 16)               return fail("arena_alloc bump delta != 16");

    /* ── first alloc == base (state.base/ptr equal after init) ── */
    if ((char *)a != (char *)base) return fail("arena first alloc != base");

    /* ── reset: ptr := base. Next alloc must hand back the SAME first ptr,
     *    proving reset's str-to-state.ptr went through the reloc'd slot ── */
    rt_arena_reset();
    void *c = rt_arena_alloc(16);
    if (c != a)                    return fail("arena_reset realloc != first");

    /* ── overflow: a 2 MB request into a 1 MB arena must return NULL
     *    (the cmp ptr,end branch — end loaded via the reloc'd slot) ── */
    void *big = rt_arena_alloc(2 * 1024 * 1024);
    if (big != NULL)               return fail("arena overflow not NULL");

    /* ── release: munmap + zero. Re-init must succeed afresh ── */
    rt_arena_release();
    void *base2 = rt_arena_init(1);
    if (base2 == NULL || base2 == (void *)-1) return fail("arena re-init after release");
    rt_arena_release();

    printf("ALL CHECKS PASS — 4 hexa-emit reloc-BOUND arena primitives "
           "(adrp+add → _arena_state PAGE21/PAGEOFF12) resolve correctly\n");
    return 0;
}
