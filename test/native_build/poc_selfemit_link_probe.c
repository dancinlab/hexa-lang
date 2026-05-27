/* test/native_build/poc_selfemit_link_probe.c
 *
 * F3 ACTIVATION RUNBOOK · Path A — end-to-end guarded-link probe.
 *
 * Compiled together with self/runtime.c under -DHEXA_RT_SELFEMIT and
 * ahead-linked with the hexa-emit hxlcl_memset.o. Under the guard,
 * runtime.c's `hxlcl_memset` is an extern (no body); ld64 binds it to the
 * .o's strong `_hxlcl_memset` (rt_memset's 28 self-emitted bytes).
 *
 * This TU calls hxlcl_memset directly (the same symbol the runtime.c
 * `#define memset hxlcl_memset` macro routes to). If the link resolves and
 * the output is correct, the self-emit→C-deletion path is proven live.
 *
 *   clang -DHEXA_RT_SELFEMIT probe.c runtime.c hxlcl_memset.o -o run
 *   ./run ; echo rc=$?     → rc=0 + "GUARDED SELF-EMIT MEMSET OK"
 *
 * runtime.c provides main()? No — runtime.c has no main; this probe owns it.
 */

#include <stddef.h>
#include <stdio.h>

/* Same declaration runtime.c exposes under the guard. */
extern void *hxlcl_memset(void *s, int c, size_t n);

int main(void) {
    unsigned char buf[48];
    for (int i = 0; i < 48; i++) buf[i] = 0x11;

    void *r = hxlcl_memset(buf, 0xCD, 40);
    if (r != (void *)buf) { fprintf(stderr, "FAIL: return != dst\n"); return 1; }
    for (int i = 0; i < 40; i++) if (buf[i] != 0xCD) { fprintf(stderr, "FAIL: fill\n"); return 2; }
    if (buf[40] != 0x11) { fprintf(stderr, "FAIL: overran\n"); return 3; }

    printf("GUARDED SELF-EMIT MEMSET OK — runtime.c hxlcl_memset bound to hexa-emit .o\n");
    return 0;
}
