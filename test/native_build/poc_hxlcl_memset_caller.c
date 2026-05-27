/* test/native_build/poc_hxlcl_memset_caller.c
 *
 * F3 ACTIVATION RUNBOOK · Path A · correctness oracle for the hexa-emitted
 * `_hxlcl_memset` .o (produced by emit_hxlcl_memset_o.hexa).
 *
 * Declares the runtime's memset symbol as an external function and exercises
 * it across fill / partial / zero-length / large cases, asserting both the
 * written bytes AND the returned pointer (rt_memset never touches x0, so it
 * must return dst — the C `void* memset` contract).
 *
 * Link:
 *   clang poc_hxlcl_memset_caller.c hxlcl_memset.o -o run
 * Run:
 *   ./run ; echo "rc=$?"     → rc=0 on all-pass, nonzero on first failure
 *
 * NO libc memset here — the C side ONLY calls the hexa-emitted bytes.
 */

#include <stddef.h>
#include <stdio.h>

/* Provided by the hexa-emitted hxlcl_memset.o (strong external _hxlcl_memset).
 * Signature matches C `void* memset(void*, int, size_t)`. */
extern void *hxlcl_memset(void *s, int c, size_t n);

static int fail(const char *what) {
    fprintf(stderr, "FAIL: %s\n", what);
    return 1;
}

int main(void) {
    unsigned char buf[64];

    /* Case 1 — full fill 32 bytes with 0xAB, sentinel guard at [32]. */
    for (int i = 0; i < 64; i++) buf[i] = 0x11;
    void *ret = hxlcl_memset(buf, 0xAB, 32);
    if (ret != (void *)buf) return fail("case1 return != dst");
    for (int i = 0; i < 32; i++) if (buf[i] != 0xAB) return fail("case1 fill byte");
    if (buf[32] != 0x11) return fail("case1 overran (wrote past len)");

    /* Case 2 — partial fill in the middle, leaves head/tail intact. */
    for (int i = 0; i < 64; i++) buf[i] = 0x00;
    hxlcl_memset(buf + 8, 0xFF, 16);
    for (int i = 0; i < 8; i++) if (buf[i] != 0x00) return fail("case2 head clobbered");
    for (int i = 8; i < 24; i++) if (buf[i] != 0xFF) return fail("case2 fill byte");
    for (int i = 24; i < 64; i++) if (buf[i] != 0x00) return fail("case2 tail clobbered");

    /* Case 3 — zero length is a no-op (loop never enters), returns dst. */
    buf[0] = 0x5A;
    void *r3 = hxlcl_memset(buf, 0x00, 0);
    if (r3 != (void *)buf) return fail("case3 return != dst");
    if (buf[0] != 0x5A) return fail("case3 zero-len wrote a byte");

    /* Case 4 — only the LOW byte of c is used (0x1234 -> 0x34). */
    for (int i = 0; i < 64; i++) buf[i] = 0x00;
    hxlcl_memset(buf, 0x1234, 4);
    for (int i = 0; i < 4; i++) if (buf[i] != 0x34) return fail("case4 low-byte truncation");

    /* Case 5 — fill the whole 64-byte buffer with 0x7E. */
    hxlcl_memset(buf, 0x7E, 64);
    for (int i = 0; i < 64; i++) if (buf[i] != 0x7E) return fail("case5 large fill");

    printf("ALL CHECKS PASS — hexa-emit hxlcl_memset behaves as C memset\n");
    return 0;
}
