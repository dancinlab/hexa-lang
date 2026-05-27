/* test/native_build/poc_arena_bundle_caller.c
 *
 * Chunk B/A bridge PoC — C caller for the bundled arena .o emitted by
 * poc_arena_bundle_emit.hexa. Links against /tmp/poc_arena_bundle.o
 * which exports 4 text symbols + 1 data symbol:
 *   _rt_arena_init   (Mach-O _ prefix → rt_arena_init in C)
 *   _rt_arena_alloc  → rt_arena_alloc
 *   _rt_arena_reset  → rt_arena_reset
 *   _rt_arena_release→ rt_arena_release
 *
 * Each fn loads `_arena_state` through ADRP+ADD which the link step
 * resolves to the data symbol's runtime address.
 *
 * Drives the full lifecycle in order:
 *
 *   1.  rt_arena_init(1)             — mmap 1 MiB anonymous region.
 *                                      state.base = mmap region.
 *                                      state.ptr  = state.base.
 *                                      state.end  = state.base + 1 MiB.
 *
 *   2.  void* p1 = rt_arena_alloc(64)
 *                                    — bump ptr by 64. Returns OLD ptr
 *                                      (= former state.base).
 *
 *   3.  void* p2 = rt_arena_alloc(32)
 *                                    — bump ptr by another 32. Returns
 *                                      p1 + 64.
 *
 *   4.  rt_arena_reset()             — state.ptr = state.base again.
 *
 *   5.  void* p3 = rt_arena_alloc(16)
 *                                    — after reset, returns state.base
 *                                      again (= p1).
 *
 *   6.  rt_arena_release()           — munmap region; state cleared.
 *
 * The C side verifies the state machine without poking _arena_state
 * directly (it's a data symbol but treated as opaque from C):
 *
 *   p1 != NULL                            (init + alloc OK)
 *   p2 == p1 + 64                          (bump-ptr OK)
 *   p3 == p1                               (reset OK)
 *
 * On full PASS we exit with 42 (sentinel observed throughout the
 * chunk-B PoC chain).
 *
 * Compile (mac arm64):
 *   clang poc_arena_bundle_caller.c /tmp/poc_arena_bundle.o \
 *     -o /tmp/poc_arena_bundle_run
 * Run:
 *   /tmp/poc_arena_bundle_run ; echo "rc=$?"     → rc=42
 *
 * NO direct exit/_exit syscall here. We use the C return value path —
 * release leaves the process alive (munmap doesn't kill us), so we
 * return 42 from main() and the libc shim does the actual exit.
 *
 * The 4 primitives match the AArch64 calling convention used by the
 * runtime: arg in x0, return in x0. rt_arena_init takes size_mb in x0;
 * rt_arena_alloc takes size_bytes in x0 and returns the old ptr in x0;
 * rt_arena_reset / rt_arena_release take no args.
 */

#include <stdio.h>
#include <stdint.h>

extern void  rt_arena_init(long size_mb);
extern void* rt_arena_alloc(long size_bytes);
extern void  rt_arena_reset(void);
extern void  rt_arena_release(void);

int main(void) {
    rt_arena_init(1);  /* 1 MiB */

    void* p1 = rt_arena_alloc(64);
    if (p1 == NULL) {
        fprintf(stderr, "FAIL: p1 == NULL after init+alloc(64)\n");
        return 1;
    }

    void* p2 = rt_arena_alloc(32);
    if ((uintptr_t)p2 != (uintptr_t)p1 + 64) {
        fprintf(stderr, "FAIL: p2 (%p) != p1+64 (%p)\n",
                p2, (void*)((uintptr_t)p1 + 64));
        return 2;
    }

    rt_arena_reset();

    void* p3 = rt_arena_alloc(16);
    if (p3 != p1) {
        fprintf(stderr, "FAIL: p3 (%p) != p1 (%p) after reset\n", p3, p1);
        return 3;
    }

    rt_arena_release();

    /* If we reached here without crash, all 4 primitives executed and
     * the state machine transitions match. Exit 42. */
    return 42;
}
